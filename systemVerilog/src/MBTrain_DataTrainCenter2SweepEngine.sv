// MBTRAIN.DATATRAINCENTER2 local transmitter clock-centering controller.
//
// DATATRAINCENTER2 executes after receiver Vref training and optional receiver
// per-lane deskew. It therefore repeats only the aggregate D2C clock-phase
// search. The transmitter lane-deskew values selected in DATATRAINCENTER1 are
// deliberately not touched here.
//
// The sideband point-test protocol remains outside this module. For every
// one-cycle point_test_start pulse, the caller runs one complete Tx-initiated
// D2C point test and returns its result with point_test_done.
//
// The internal phase index 0..263 sweeps eight 33-interval sectors once.
// Physical controls are {lower_en[16:0], upper_en[16:0], s3,s2,s1,s0}.
// Sector endpoints are not duplicated. Window selection keeps the existing
// linear search cut: passing runs across the 263/0 wrap are not merged.
`default_nettype none

module MBTrain_DataTrainCenter2SweepEngine #(
  parameter bit          ucieA                   = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter int unsigned PI_CODE_WIDTH           = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned MAX_TRAINING_RETRIES    = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output var logic busy,
  output var logic done,
  output var logic trainError,

  output var logic                     apply_tx_clock_phase,
  output var logic [PI_CODE_WIDTH-1:0] tx_clock_phase_code,
  input  wire logic                     tx_clock_phase_applied,

  output var logic        point_test_start,
  input  wire logic        point_test_done,
  input  wire logic [63:0] point_test_lane_pass,
  input  wire logic        point_test_valid_pass,
  input  wire logic        point_test_cumulative_pass,

  output var logic [3:0]  state,
  output var logic [15:0] lastFailedComparisons,
  output var logic [15:0] retryCount,
  // Phase readbacks use the same physical encoding as tx_clock_phase_code.
  output var logic [PI_CODE_WIDTH-1:0] finalClockPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalLeftPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalRightPhase
);
  localparam int unsigned MAX_DATA_LANES = 64;
  localparam int unsigned PHASE_COUNT = LtsmParameters_pkg::D2C_PI_PHASE_COUNT;
  localparam int unsigned PHASE_INDEX_WIDTH = LtsmParameters_pkg::D2C_PI_INDEX_WIDTH;
  // Length must represent all 264 samples in an all-pass sweep.
  localparam int unsigned WINDOW_LENGTH_WIDTH = $clog2(PHASE_COUNT + 1);

  localparam logic [63:0] ACTIVE_LANE_MASK =
    ucieA ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;

  typedef enum logic [3:0] {
    SweepState_IDLE               = 4'd0,
    SweepState_APPLY_SWEEP_PHASE  = 4'd1,
    SweepState_START_SWEEP_TEST   = 4'd2,
    SweepState_WAIT_SWEEP_TEST    = 4'd3,
    SweepState_STORE_SWEEP_RESULT = 4'd4,
    SweepState_CALCULATE_GLOBAL   = 4'd5,
    SweepState_APPLY_GLOBAL_PHASE = 4'd6,
    SweepState_START_FINAL_TEST   = 4'd7,
    SweepState_WAIT_FINAL_TEST    = 4'd8,
    SweepState_CHECK_FINAL_TEST   = 4'd9,
    SweepState_DONE               = 4'd10,
    SweepState_ERROR              = 4'd11
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic errorReg;
  (* keep = "true" *) logic [15:0] lastFailedComparisonsReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] phaseIndexReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] finalClockPhaseReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] globalLeftPhaseReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] globalRightPhaseReg;

  // Accumulate the longest interval as samples arrive. The old bitmap scan
  // unrolled PHASE_COUNT dependent add/compare/mux steps into one clock path.
  // These registers limit each sample update to one narrow increment/compare.
  logic [WINDOW_LENGTH_WIDTH-1:0] runLengthReg, bestLengthReg;
  logic [PHASE_INDEX_WIDTH-1:0] runStartReg, bestStartReg;
  wire [WINDOW_LENGTH_WIDTH-1:0] extendedRunLength = runLengthReg + 1'b1;

  wire allActiveDataLanesPass =
    &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  // Balanced population count: six adder levels for 64 lanes, with only
  // enough bits at each level for its partial count. Inactive lanes are zero.
  for (genvar level = 0; level <= 6; level = level + 1) begin : genFailureCount
    wire [level:0] count [0:(MAX_DATA_LANES >> level)-1];
    for (genvar node = 0; node < (MAX_DATA_LANES >> level); node = node + 1) begin : genNode
      if (level == 0) begin : genLeaf
        assign count[node] = ACTIVE_LANE_MASK[node] && !point_test_lane_pass[node];
      end else begin : genSum
        assign count[node] =
          {1'b0, genFailureCount[level-1].count[2*node]} +
          {1'b0, genFailureCount[level-1].count[2*node+1]};
      end
    end
  end
  wire [6:0] failedLaneAndValidCount =
    genFailureCount[6].count[0] + {6'b0, !point_test_valid_pass};
  wire [15:0] failedComparisons =
    (!point_test_cumulative_pass && (failedLaneAndValidCount == 0)) ?
    16'd1 : {9'b0, failedLaneAndValidCount};

  logic globalWindowValidCalc;
  logic [PHASE_INDEX_WIDTH-1:0] globalLeftPhaseCalc;
  logic [PHASE_INDEX_WIDTH-1:0] globalRightPhaseCalc;
  logic [PHASE_INDEX_WIDTH-1:0] globalCenterPhaseCalc;

  // Strictly-longer updates below retain the first (lowest-code) equal run.
  // Subtract before narrowing so the full-range passing window is preserved.
  always_comb begin
    globalWindowValidCalc =
      (bestLengthReg >= WINDOW_LENGTH_WIDTH'(MIN_COMMON_WINDOW_STEPS));
    if (bestLengthReg == 0) begin
      globalLeftPhaseCalc = '0;
      globalRightPhaseCalc = '0;
      globalCenterPhaseCalc = '0;
    end else begin
      globalLeftPhaseCalc = bestStartReg;
      globalRightPhaseCalc = bestStartReg + PHASE_INDEX_WIDTH'(bestLengthReg - 1'b1);
      globalCenterPhaseCalc =
        bestStartReg + PHASE_INDEX_WIDTH'((bestLengthReg - 1'b1) >> 1);
    end
  end

  // Keep requested binary phase, registered decomposition, and physical word
  // on separate clock boundaries. APPLY states also serve as decode waits;
  // an early/stale analog acknowledge cannot advance the state machine.
  logic [PHASE_INDEX_WIDTH-1:0] encodedPhaseIndex;
  logic phaseCodeValid;
  wire phaseCodeReady = phaseCodeValid && (encodedPhaseIndex == phaseIndexReg);
  logic [PHASE_INDEX_WIDTH-1:0] encodedFinalPhaseIndex;
  logic finalPhaseCodeValid;
  wire finalPhaseCodeReady = finalPhaseCodeValid &&
    (encodedFinalPhaseIndex == finalClockPhaseReg);
  MBTrain_DllPiEncoder u_phase_encoder (
    .clock(clock), .reset_n(reset_n), .phase_index(phaseIndexReg),
    .phase_code(tx_clock_phase_code),
    .phase_index_out(encodedPhaseIndex), .valid(phaseCodeValid)
  );

  // Debug/readback words use the same registered physical encoder. They settle
  // two clocks after their index changes, before final point-test completion.
  MBTrain_DllPiEncoder u_finalClockPhase_encoder (
    .clock(clock), .reset_n(reset_n), .phase_index(finalClockPhaseReg),
    .phase_code(finalClockPhase),
    .phase_index_out(encodedFinalPhaseIndex), .valid(finalPhaseCodeValid)
  );
  MBTrain_DllPiEncoder u_globalLeftPhase_encoder (
    .clock(clock), .reset_n(reset_n), .phase_index(globalLeftPhaseReg),
    .phase_code(globalLeftPhase), .phase_index_out(), .valid()
  );
  MBTrain_DllPiEncoder u_globalRightPhase_encoder (
    .clock(clock), .reset_n(reset_n), .phase_index(globalRightPhaseReg),
    .phase_code(globalRightPhase), .phase_index_out(), .valid()
  );

  always_comb begin
    busy = (stateReg != SweepState_IDLE) &&
           (stateReg != SweepState_DONE) &&
           (stateReg != SweepState_ERROR);
    done = doneReg;
    trainError = errorReg;

    state = stateReg;
    lastFailedComparisons = lastFailedComparisonsReg;
    retryCount = retryCountReg;

    apply_tx_clock_phase = phaseCodeReady &&
      ((stateReg == SweepState_APPLY_SWEEP_PHASE) ||
       ((stateReg == SweepState_APPLY_GLOBAL_PHASE) && finalPhaseCodeReady));

    point_test_start =
      (stateReg == SweepState_START_SWEEP_TEST) ||
      (stateReg == SweepState_START_FINAL_TEST);
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg <= SweepState_IDLE;
      doneReg <= 1'b0;
      errorReg <= 1'b0;
      lastFailedComparisonsReg <= 16'b0;
      retryCountReg <= 16'b0;
      phaseIndexReg <= '0;
      runLengthReg <= '0;
      bestLengthReg <= '0;
      runStartReg <= '0;
      bestStartReg <= '0;
      finalClockPhaseReg <= '0;
      globalLeftPhaseReg <= '0;
      globalRightPhaseReg <= '0;
    end else begin
      if (start &&
          ((stateReg == SweepState_IDLE) ||
           (stateReg == SweepState_DONE) ||
           (stateReg == SweepState_ERROR))) begin
        doneReg <= 1'b0;
        errorReg <= 1'b0;
        lastFailedComparisonsReg <= 16'b0;
        retryCountReg <= 16'b0;
        phaseIndexReg <= '0;
        runLengthReg <= '0;
        bestLengthReg <= '0;
        runStartReg <= '0;
        bestStartReg <= '0;
        finalClockPhaseReg <= '0;
        globalLeftPhaseReg <= '0;
        globalRightPhaseReg <= '0;
        stateReg <= SweepState_APPLY_SWEEP_PHASE;
      end else begin
        unique case (stateReg)
          SweepState_IDLE: ;

          SweepState_APPLY_SWEEP_PHASE: begin
            if (apply_tx_clock_phase && tx_clock_phase_applied)
              stateReg <= SweepState_START_SWEEP_TEST;
          end

          SweepState_START_SWEEP_TEST: begin
            stateReg <= SweepState_WAIT_SWEEP_TEST;
          end

          SweepState_WAIT_SWEEP_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_STORE_SWEEP_RESULT;
          end

          SweepState_STORE_SWEEP_RESULT: begin
            if (pointTestAllPass) begin
              if (runLengthReg == 0)
                runStartReg <= phaseIndexReg;
              runLengthReg <= extendedRunLength;
              if (extendedRunLength > bestLengthReg) begin
                bestLengthReg <= extendedRunLength;
                bestStartReg <= (runLengthReg == 0) ? phaseIndexReg : runStartReg;
              end
            end else begin
              runLengthReg <= '0;
            end
            lastFailedComparisonsReg <= failedComparisons;

            if (phaseIndexReg == PHASE_INDEX_WIDTH'(PHASE_COUNT - 1)) begin
              stateReg <= SweepState_CALCULATE_GLOBAL;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end
          end

          SweepState_CALCULATE_GLOBAL: begin
            if (globalWindowValidCalc) begin
              globalLeftPhaseReg <= globalLeftPhaseCalc;
              globalRightPhaseReg <= globalRightPhaseCalc;
              finalClockPhaseReg <= globalCenterPhaseCalc;
              phaseIndexReg <= globalCenterPhaseCalc;
              stateReg <= SweepState_APPLY_GLOBAL_PHASE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
              runLengthReg <= '0;
              bestLengthReg <= '0;
              runStartReg <= '0;
              bestStartReg <= '0;
              finalClockPhaseReg <= '0;
              globalLeftPhaseReg <= '0;
              globalRightPhaseReg <= '0;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_GLOBAL_PHASE: begin
            if (apply_tx_clock_phase && tx_clock_phase_applied)
              stateReg <= SweepState_START_FINAL_TEST;
          end

          SweepState_START_FINAL_TEST: begin
            stateReg <= SweepState_WAIT_FINAL_TEST;
          end

          SweepState_WAIT_FINAL_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_CHECK_FINAL_TEST;
          end

          SweepState_CHECK_FINAL_TEST: begin
            lastFailedComparisonsReg <= failedComparisons;

            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
              runLengthReg <= '0;
              bestLengthReg <= '0;
              runStartReg <= '0;
              bestStartReg <= '0;
              finalClockPhaseReg <= '0;
              globalLeftPhaseReg <= '0;
              globalRightPhaseReg <= '0;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_DONE: ;
          SweepState_ERROR: ;
          default: stateReg <= SweepState_IDLE;
        endcase
      end
    end
  end

`ifndef SYNTHESIS
  // The analog side samples a bundled control word and acknowledges only
  // after its safe-update and settling policy has completed.
  a_phase_request_stable: assert property (@(posedge clock) disable iff (!reset_n)
    (apply_tx_clock_phase && !tx_clock_phase_applied) |=>
      (apply_tx_clock_phase && $stable(tx_clock_phase_code)));
  a_phase_index_in_range: assert property (@(posedge clock) disable iff (!reset_n)
    phaseIndexReg < PHASE_COUNT);
  a_phase_decode_matches_request: assert property (@(posedge clock) disable iff (!reset_n)
    apply_tx_clock_phase |->
      (tx_clock_phase_code == LtsmParameters_pkg::encode_d2c_phase(phaseIndexReg)));
  initial begin
    if (PI_CODE_WIDTH != LtsmParameters_pkg::D2C_PI_CONTROL_WIDTH)
      $error("PI_CODE_WIDTH must be 38 for the DLL mux and complementary PI bank controls");
    if ((MIN_COMMON_WINDOW_STEPS < 1) ||
        (MIN_COMMON_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_COMMON_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire
