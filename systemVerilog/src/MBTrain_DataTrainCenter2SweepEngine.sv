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
// PI codes are treated as one linear ordered search interval. Code zero and
// code PHASE_COUNT-1 are not adjacent and passing runs at the two boundaries
// are never merged.
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
  output var logic [PI_CODE_WIDTH-1:0] finalClockPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalLeftPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalRightPhase
);
  localparam int unsigned MAX_DATA_LANES = 64;
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);

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
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] phaseIndexReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] finalClockPhaseReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] globalLeftPhaseReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] globalRightPhaseReg;

  logic passByPhase [0:PHASE_COUNT-1];

  wire allActiveDataLanesPass =
    &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  function automatic [15:0] countFailedComparisons(
    input logic [63:0] lanePass,
    input logic        validPass,
    input logic        cumulativePass
  );
    integer lane;
    integer count;
    begin
      count = 0;
      for (lane = 0; lane < MAX_DATA_LANES; lane = lane + 1) begin
        if (ACTIVE_LANE_MASK[lane] && !lanePass[lane])
          count = count + 1;
      end
      if (!validPass)
        count = count + 1;
      if (!cumulativePass && (count == 0))
        count = 1;
      countFailedComparisons = count;
    end
  endfunction

  integer phaseIdx;
  integer runLength;
  integer bestLength;
  integer runStart;
  integer bestStart;

  logic globalWindowValidCalc;
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalCenterPhaseCalc;

  always_comb begin
    runLength = 0;
    bestLength = 0;
    runStart = 0;
    bestStart = 0;

    for (phaseIdx = 0; phaseIdx < PHASE_COUNT; phaseIdx = phaseIdx + 1) begin
      if (passByPhase[phaseIdx]) begin
        if (runLength == 0)
          runStart = phaseIdx;
        runLength = runLength + 1;
        if (runLength > bestLength) begin
          bestLength = runLength;
          bestStart = runStart;
        end
      end else begin
        runLength = 0;
      end
    end

    globalWindowValidCalc = (bestLength >= MIN_COMMON_WINDOW_STEPS);

    if (bestLength == 0) begin
      globalLeftPhaseCalc = '0;
      globalRightPhaseCalc = '0;
      globalCenterPhaseCalc = '0;
    end else begin
      globalLeftPhaseCalc = bestStart;
      globalRightPhaseCalc = bestStart + bestLength - 1;
      globalCenterPhaseCalc = bestStart + ((bestLength - 1) >> 1);
    end
  end

  always_comb begin
    busy = (stateReg != SweepState_IDLE) &&
           (stateReg != SweepState_DONE) &&
           (stateReg != SweepState_ERROR);
    done = doneReg;
    trainError = errorReg;

    state = stateReg;
    lastFailedComparisons = lastFailedComparisonsReg;
    retryCount = retryCountReg;
    finalClockPhase = finalClockPhaseReg;
    globalLeftPhase = globalLeftPhaseReg;
    globalRightPhase = globalRightPhaseReg;

    tx_clock_phase_code = phaseIndexReg;
    apply_tx_clock_phase =
      (stateReg == SweepState_APPLY_SWEEP_PHASE) ||
      (stateReg == SweepState_APPLY_GLOBAL_PHASE);

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
        finalClockPhaseReg <= '0;
        globalLeftPhaseReg <= '0;
        globalRightPhaseReg <= '0;
        stateReg <= SweepState_APPLY_SWEEP_PHASE;
      end else begin
        unique case (stateReg)
          SweepState_IDLE: ;

          SweepState_APPLY_SWEEP_PHASE: begin
            if (tx_clock_phase_applied)
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
            passByPhase[phaseIndexReg] <= pointTestAllPass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass,
              point_test_valid_pass,
              point_test_cumulative_pass
            );

            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
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
            if (tx_clock_phase_applied)
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
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass,
              point_test_valid_pass,
              point_test_cumulative_pass
            );

            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
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
  initial begin
    if ((PI_CODE_WIDTH < 2) || (PI_CODE_WIDTH > 10))
      $error("PI_CODE_WIDTH must be in the range 2..10");
    if ((MIN_COMMON_WINDOW_STEPS < 1) ||
        (MIN_COMMON_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_COMMON_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire
