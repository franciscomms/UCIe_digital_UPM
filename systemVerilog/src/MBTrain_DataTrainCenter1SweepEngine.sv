// DATATRAINCENTER1 local transmitter linear sweep/deskew controller.
//
// The sideband protocol is intentionally kept outside this module.  A caller
// starts one UCIe Tx-initiated D2C point test for every asserted
// point_test_start and returns the partner's comparison bitmap through the
// point_test_* inputs when point_test_done is asserted.
//
// Lane deskew convention:
//   lane 0 code is tx_lane_deskew_codes[TX_DESKEW_CODE_WIDTH-1:0]
//   lane N code is tx_lane_deskew_codes[N*TX_DESKEW_CODE_WIDTH +:
//                                      TX_DESKEW_CODE_WIDTH]
// Each lane exports 20 physical controls: cell 1 [9:0], cell 2 [19:10].
// Within each cell, bit 0 is the 0.5 ps LSB; bits 1..9 are the 1 ps
// thermometer switches sw-4..sw4. Cell 1 fills to 9.5 ps before cell 2.
// Inactive UCIe-S lanes [63:16] are held at zero. Numeric delay calculations
// use half-ps steps separately from this PHY control-word width.
//
// PI phase convention:
//   The internal index 0..263 sweeps eight 33-interval sectors once.
//   Physical controls are {lower_en[16:0], upper_en[16:0], s3,s2,s1,s0}.
//   Sector endpoints are not duplicated. Window selection keeps the existing
//   linear search cut: passing runs across the 263/0 wrap are not merged.
`default_nettype none

module MBTrain_DataTrainCenter1SweepEngine #(
  parameter bit          ucieA                         = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter int unsigned PI_CODE_WIDTH                 = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned TX_DESKEW_CODE_WIDTH          = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned DESKEW_STEPS_PER_PI            = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI,
  parameter bit          DESKEW_ADD_DELAY_INCREASES_PHASE = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE,
  parameter int unsigned MIN_LANE_WINDOW_STEPS          = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS        = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned MAX_TRAINING_RETRIES           = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output var  logic busy,
  output var  logic done,
  output var  logic trainError,

  // Local forwarded-clock PI interface.  apply_tx_clock_phase remains asserted
  // with a stable code until tx_clock_phase_applied is observed.
  output var  logic                     apply_tx_clock_phase,
  output var  logic [PI_CODE_WIDTH-1:0] tx_clock_phase_code,
  input  wire logic                     tx_clock_phase_applied,

  // Local per-data-lane TX deskew interface. apply_tx_lane_deskew remains
  // asserted with stable two-cell switch words until acknowledged.
  output var  logic                                      apply_tx_lane_deskew,
  output var  logic [64*TX_DESKEW_CODE_WIDTH-1:0]        tx_lane_deskew_codes,
  input  wire logic                                      tx_lane_deskew_applied,

  // One-cycle request to run a complete Tx-initiated D2C point test at the
  // currently applied local clock phase.
  output var  logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [63:0] point_test_lane_pass,
  input  wire logic        point_test_valid_pass,
  input  wire logic        point_test_cumulative_pass,

  output var  logic [4:0]  state,
  output var  logic [15:0] lastFailedComparisons,
  output var  logic [15:0] retryCount,
  // Phase readback uses the same physical encoding as tx_clock_phase_code.
  output var  logic [PI_CODE_WIDTH-1:0] finalClockPhase
);
  localparam int unsigned MAX_DATA_LANES   = 64;
  localparam int unsigned ACTIVE_DATA_LANES = ucieA ? 64 : 16;
  // Split the target reduction evenly at a register boundary: 4 groups of
  // 4 lanes (two compare/select levels per cycle), or 8 groups of 8 lanes
  // (three levels per cycle). No inactive-lane sentinel branches are needed.
  localparam int unsigned CENTER_GROUP_LANES = ucieA ? 8 : 4;
  localparam int unsigned CENTER_GROUP_COUNT = ACTIVE_DATA_LANES / CENTER_GROUP_LANES;
  localparam int unsigned PHASE_COUNT = LtsmParameters_pkg::D2C_PI_PHASE_COUNT;
  localparam int unsigned PHASE_INDEX_WIDTH = LtsmParameters_pkg::D2C_PI_INDEX_WIDTH;
  // Length must represent all 264 samples in an all-pass sweep.
  localparam int unsigned WINDOW_LENGTH_WIDTH = $clog2(PHASE_COUNT + 1);
  localparam int unsigned DESKEW_STEP_WIDTH =
    (DESKEW_STEPS_PER_PI < 2) ? 1 :
    $clog2({1'b0, DESKEW_STEPS_PER_PI} + 33'd1);
  localparam int unsigned DESKEW_PRODUCT_WIDTH =
    PHASE_INDEX_WIDTH + DESKEW_STEP_WIDTH;

  localparam logic [63:0] ACTIVE_LANE_MASK =
    ucieA ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;

  typedef enum logic [4:0] {
    SweepState_IDLE                  = 5'd0,
    SweepState_APPLY_ZERO_DESKEW     = 5'd1,
    SweepState_APPLY_INITIAL_PHASE   = 5'd2,
    SweepState_START_INITIAL_TEST    = 5'd3,
    SweepState_WAIT_INITIAL_TEST     = 5'd4,
    SweepState_STORE_INITIAL_RESULT  = 5'd5,
    SweepState_CALCULATE_DESKEW      = 5'd6,
    SweepState_APPLY_DESKEW          = 5'd7,
    SweepState_CLEAR_VERIFY_RESULTS  = 5'd8,
    SweepState_APPLY_VERIFY_PHASE    = 5'd9,
    SweepState_START_VERIFY_TEST     = 5'd10,
    SweepState_WAIT_VERIFY_TEST      = 5'd11,
    SweepState_STORE_VERIFY_RESULT   = 5'd12,
    SweepState_CALCULATE_GLOBAL      = 5'd13,
    SweepState_APPLY_GLOBAL_PHASE    = 5'd14,
    SweepState_START_FINAL_TEST      = 5'd15,
    SweepState_WAIT_FINAL_TEST       = 5'd16,
    SweepState_CHECK_FINAL_TEST      = 5'd17,
    SweepState_DONE                  = 5'd18,
    SweepState_ERROR                 = 5'd19,
    SweepState_SELECT_TARGET         = 5'd20,
    SweepState_CALCULATE_DELTA       = 5'd21,
    SweepState_SCALE_DESKEW          = 5'd22,
    SweepState_CHECK_DESKEW          = 5'd23,
    SweepState_ENCODE_DESKEW         = 5'd24,
    SweepState_REDUCE_CENTER_GROUPS  = 5'd25
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic errorReg;
  (* keep = "true" *) logic [15:0] lastFailedComparisonsReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] phaseIndexReg;
  (* keep = "true" *) logic [PHASE_INDEX_WIDTH-1:0] finalClockPhaseReg;
  (* keep = "true" *) logic [64*TX_DESKEW_CODE_WIDTH-1:0] deskewCodesReg;

  // Update the longest passing interval as each result arrives. A hardware
  // loop over the entire stored sweep would unroll into PHASE_COUNT serial
  // increment/compare/mux stages. These registers reduce that path to one
  // narrow increment and comparison, independent of the sweep length.
  logic [PHASE_INDEX_WIDTH-1:0] laneRunStartReg [0:MAX_DATA_LANES-1];
  logic [WINDOW_LENGTH_WIDTH-1:0] laneRunLengthReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] laneBestStartReg [0:MAX_DATA_LANES-1];
  logic [WINDOW_LENGTH_WIDTH-1:0] laneBestLengthReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] globalRunStartReg;
  logic [WINDOW_LENGTH_WIDTH-1:0] globalRunLengthReg;
  logic [PHASE_INDEX_WIDTH-1:0] globalBestStartReg;
  logic [WINDOW_LENGTH_WIDTH-1:0] globalBestLengthReg;

  // Register the arithmetic stages between finding lane centers and applying
  // deskew: center -> group extrema -> target -> delta -> scale -> range
  // -> physical switch encoding. The encoder is fed only a 6-bit checked value.
  logic [PHASE_INDEX_WIDTH-1:0] laneLeftPhaseReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] laneRightPhaseReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] laneCenterPhaseReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] groupCenterPhaseReg [0:CENTER_GROUP_COUNT-1];
  logic [PHASE_INDEX_WIDTH-1:0] targetLaneCenterReg;
  logic [PHASE_INDEX_WIDTH-1:0] deskewDeltaReg [0:MAX_DATA_LANES-1];
  logic [DESKEW_PRODUCT_WIDTH-1:0] deskewProductReg [0:MAX_DATA_LANES-1];
  logic [LtsmParameters_pkg::TX_DESKEW_HALF_STEP_WIDTH-1:0]
    selectedDeskewStepsReg [0:MAX_DATA_LANES-1];
  logic [PHASE_INDEX_WIDTH-1:0] globalLeftPhaseReg;
  logic [PHASE_INDEX_WIDTH-1:0] globalRightPhaseReg;

  wire allActiveDataLanesPass = &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  // Explicit balanced reductions avoid serial lane-to-lane dependencies.
  // Failure counts need only seven bits for 64 data lanes plus Valid.
  wire [6:0] failedLaneTree [1:2*MAX_DATA_LANES-1];
  wire [6:0] failedComparisonsCalc =
    failedLaneTree[1] + {6'b0, !point_test_valid_pass};
  wire [PHASE_INDEX_WIDTH-1:0] groupCenterResult [0:CENTER_GROUP_COUNT-1];
  wire [PHASE_INDEX_WIDTH-1:0] targetCenterTree [1:2*CENTER_GROUP_COUNT-1];
  wire [MAX_DATA_LANES-1:0] laneWindowValid;
  wire [MAX_DATA_LANES-1:0] deskewCodeFits;
  wire initialWindowsValidCalc = &laneWindowValid;
  wire allDeskewCodesFit = &deskewCodeFits;

  for (genvar lane = 0; lane < MAX_DATA_LANES; lane++) begin : gen_lane_reductions
    assign failedLaneTree[MAX_DATA_LANES+lane] =
      {6'b0, ACTIVE_LANE_MASK[lane] && !point_test_lane_pass[lane]};
    assign laneWindowValid[lane] = !ACTIVE_LANE_MASK[lane] ||
      (laneBestLengthReg[lane] >= WINDOW_LENGTH_WIDTH'(MIN_LANE_WINDOW_STEPS));
    // Twenty control pins provide 39 legal settings, not 2**20 delays.
    // Narrow products below six bits always fit; larger products must be
    // checked before narrowing so out-of-range delays cannot wrap or saturate.
    if (DESKEW_PRODUCT_WIDTH >= LtsmParameters_pkg::TX_DESKEW_HALF_STEP_WIDTH) begin : gen_check_range
      assign deskewCodeFits[lane] = !ACTIVE_LANE_MASK[lane] ||
        (deskewProductReg[lane] <= DESKEW_PRODUCT_WIDTH'(LtsmParameters_pkg::TX_DESKEW_MAX_HALF_STEPS));
    end else begin : gen_all_codes_fit
      assign deskewCodeFits[lane] = 1'b1;
    end
  end
  for (genvar node = 1; node < MAX_DATA_LANES; node++) begin : gen_balanced_reductions
    assign failedLaneTree[node] = failedLaneTree[2*node] + failedLaneTree[2*node+1];
  end

  // Stage 1 reduces only active lanes, in parallel groups. The polarity is
  // an elaboration-time constant, so each node implements either max or min.
  for (genvar group = 0; group < CENTER_GROUP_COUNT; group++) begin : gen_center_groups
    wire [PHASE_INDEX_WIDTH-1:0] centerTree [1:2*CENTER_GROUP_LANES-1];
    for (genvar lane = 0; lane < CENTER_GROUP_LANES; lane++) begin : gen_leaves
      assign centerTree[CENTER_GROUP_LANES+lane] =
        laneCenterPhaseReg[group*CENTER_GROUP_LANES+lane];
    end
    for (genvar node = 1; node < CENTER_GROUP_LANES; node++) begin : gen_nodes
      assign centerTree[node] =
        (DESKEW_ADD_DELAY_INCREASES_PHASE ?
          (centerTree[2*node] > centerTree[2*node+1]) :
          (centerTree[2*node] < centerTree[2*node+1])) ?
        centerTree[2*node] : centerTree[2*node+1];
    end
    assign groupCenterResult[group] = centerTree[1];
    // Stage 2 starts at the group registers, not at stage 1's combinational
    // roots. This cuts the complete lane-to-target reduction across two clocks.
    assign targetCenterTree[CENTER_GROUP_COUNT+group] = groupCenterPhaseReg[group];
  end
  for (genvar node = 1; node < CENTER_GROUP_COUNT; node++) begin : gen_target_reduction
    assign targetCenterTree[node] =
      (DESKEW_ADD_DELAY_INCREASES_PHASE ?
        (targetCenterTree[2*node] > targetCenterTree[2*node+1]) :
        (targetCenterTree[2*node] < targetCenterTree[2*node+1])) ?
      targetCenterTree[2*node] : targetCenterTree[2*node+1];
  end

  wire globalWindowValidCalc =
    globalBestLengthReg >= WINDOW_LENGTH_WIDTH'(MIN_COMMON_WINDOW_STEPS);
  wire [PHASE_INDEX_WIDTH-1:0] globalLeftPhaseCalc = globalBestStartReg;
  wire [PHASE_INDEX_WIDTH-1:0] globalRightPhaseCalc =
    globalBestStartReg + PHASE_INDEX_WIDTH'(globalBestLengthReg - 1'b1);
  wire [PHASE_INDEX_WIDTH-1:0] globalCenterPhaseCalc =
    globalBestStartReg + PHASE_INDEX_WIDTH'((globalBestLengthReg - 1'b1) >> 1);

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

  always_comb begin
    busy = (stateReg != SweepState_IDLE) &&
           (stateReg != SweepState_DONE) &&
           (stateReg != SweepState_ERROR);
    done = doneReg;
    trainError = errorReg;
    state = stateReg;
    lastFailedComparisons = lastFailedComparisonsReg;
    retryCount = retryCountReg;

    tx_lane_deskew_codes = deskewCodesReg;

    apply_tx_clock_phase = phaseCodeReady &&
      ((stateReg == SweepState_APPLY_INITIAL_PHASE) ||
       (stateReg == SweepState_APPLY_VERIFY_PHASE) ||
       ((stateReg == SweepState_APPLY_GLOBAL_PHASE) && finalPhaseCodeReady));

    apply_tx_lane_deskew =
      (stateReg == SweepState_APPLY_ZERO_DESKEW) ||
      (stateReg == SweepState_APPLY_DESKEW);

    point_test_start =
      (stateReg == SweepState_START_INITIAL_TEST) ||
      (stateReg == SweepState_START_VERIFY_TEST) ||
      (stateReg == SweepState_START_FINAL_TEST);
  end

  int unsigned clearLaneIdx;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg <= SweepState_IDLE;
      doneReg <= 1'b0;
      errorReg <= 1'b0;
      lastFailedComparisonsReg <= 16'b0;
      retryCountReg <= 16'b0;
      phaseIndexReg <= '0;
      finalClockPhaseReg <= '0;
      deskewCodesReg <= '0;
      globalLeftPhaseReg <= '0;
      globalRightPhaseReg <= '0;
      globalRunStartReg <= '0;
      globalRunLengthReg <= '0;
      globalBestStartReg <= '0;
      globalBestLengthReg <= '0;
      targetLaneCenterReg <= '0;
      for (clearLaneIdx = 0; clearLaneIdx < CENTER_GROUP_COUNT;
           clearLaneIdx = clearLaneIdx + 1) begin
        groupCenterPhaseReg[clearLaneIdx] <= '0;
      end
      for (clearLaneIdx = 0;
           clearLaneIdx < MAX_DATA_LANES;
           clearLaneIdx = clearLaneIdx + 1) begin
        laneRunStartReg[clearLaneIdx] <= '0;
        laneRunLengthReg[clearLaneIdx] <= '0;
        laneBestStartReg[clearLaneIdx] <= '0;
        laneBestLengthReg[clearLaneIdx] <= '0;
        deskewDeltaReg[clearLaneIdx] <= '0;
        deskewProductReg[clearLaneIdx] <= '0;
        selectedDeskewStepsReg[clearLaneIdx] <= '0;
        laneLeftPhaseReg[clearLaneIdx] <= '0;
        laneRightPhaseReg[clearLaneIdx] <= '0;
        laneCenterPhaseReg[clearLaneIdx] <= '0;
      end
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
        deskewCodesReg <= '0;
        globalLeftPhaseReg <= '0;
        globalRightPhaseReg <= '0;
        // Streaming window trackers are cleared when zero deskew is accepted;
        // the same path initializes both a new training run and every retry.
        for (clearLaneIdx = 0;
             clearLaneIdx < MAX_DATA_LANES;
             clearLaneIdx = clearLaneIdx + 1) begin
          laneLeftPhaseReg[clearLaneIdx] <= '0;
          laneRightPhaseReg[clearLaneIdx] <= '0;
          laneCenterPhaseReg[clearLaneIdx] <= '0;
        end
        stateReg <= SweepState_APPLY_ZERO_DESKEW;
      end else begin
        unique case (stateReg)
          SweepState_IDLE: ;

          SweepState_APPLY_ZERO_DESKEW: begin
            if (tx_lane_deskew_applied) begin
              phaseIndexReg <= '0;
              for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                   clearLaneIdx = clearLaneIdx + 1) begin
                laneRunStartReg[clearLaneIdx] <= '0;
                laneRunLengthReg[clearLaneIdx] <= '0;
                laneBestStartReg[clearLaneIdx] <= '0;
                laneBestLengthReg[clearLaneIdx] <= '0;
              end
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_APPLY_INITIAL_PHASE: begin
            if (apply_tx_clock_phase && tx_clock_phase_applied)
              stateReg <= SweepState_START_INITIAL_TEST;
          end

          SweepState_START_INITIAL_TEST: begin
            stateReg <= SweepState_WAIT_INITIAL_TEST;
          end

          SweepState_WAIT_INITIAL_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_STORE_INITIAL_RESULT;
          end

          SweepState_STORE_INITIAL_RESULT: begin
            for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                 clearLaneIdx = clearLaneIdx + 1) begin
              if (ACTIVE_LANE_MASK[clearLaneIdx]) begin
                if (point_test_lane_pass[clearLaneIdx]) begin
                  if (laneRunLengthReg[clearLaneIdx] == 0)
                    laneRunStartReg[clearLaneIdx] <= phaseIndexReg;
                  laneRunLengthReg[clearLaneIdx] <= laneRunLengthReg[clearLaneIdx] + 1'b1;
                  // Strictly longer retains the lower interval on ties.
                  if ((laneRunLengthReg[clearLaneIdx] + 1'b1) > laneBestLengthReg[clearLaneIdx]) begin
                    laneBestLengthReg[clearLaneIdx] <= laneRunLengthReg[clearLaneIdx] + 1'b1;
                    laneBestStartReg[clearLaneIdx] <=
                      (laneRunLengthReg[clearLaneIdx] == 0) ?
                        phaseIndexReg : laneRunStartReg[clearLaneIdx];
                  end
                end else begin
                  laneRunLengthReg[clearLaneIdx] <= '0;
                end
              end
            end
            lastFailedComparisonsReg <= {9'b0, failedComparisonsCalc};
            if (phaseIndexReg == PHASE_INDEX_WIDTH'(PHASE_COUNT - 1)) begin
              stateReg <= SweepState_CALCULATE_DESKEW;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_CALCULATE_DESKEW: begin
            if (initialWindowsValidCalc) begin
              for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                   clearLaneIdx = clearLaneIdx + 1) begin
                if (ACTIVE_LANE_MASK[clearLaneIdx]) begin
                  laneLeftPhaseReg[clearLaneIdx] <= laneBestStartReg[clearLaneIdx];
                  laneRightPhaseReg[clearLaneIdx] <= laneBestStartReg[clearLaneIdx] +
                    PHASE_INDEX_WIDTH'(laneBestLengthReg[clearLaneIdx] - 1'b1);
                  laneCenterPhaseReg[clearLaneIdx] <= laneBestStartReg[clearLaneIdx] +
                    PHASE_INDEX_WIDTH'((laneBestLengthReg[clearLaneIdx] - 1'b1) >> 1);
                end
              end
              stateReg <= SweepState_REDUCE_CENTER_GROUPS;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_REDUCE_CENTER_GROUPS: begin
            for (clearLaneIdx = 0; clearLaneIdx < CENTER_GROUP_COUNT;
                 clearLaneIdx = clearLaneIdx + 1) begin
              groupCenterPhaseReg[clearLaneIdx] <= groupCenterResult[clearLaneIdx];
            end
            stateReg <= SweepState_SELECT_TARGET;
          end

          SweepState_SELECT_TARGET: begin
            targetLaneCenterReg <= targetCenterTree[1];
            stateReg <= SweepState_CALCULATE_DELTA;
          end

          SweepState_CALCULATE_DELTA: begin
            for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                 clearLaneIdx = clearLaneIdx + 1) begin
              if (ACTIVE_LANE_MASK[clearLaneIdx])
                deskewDeltaReg[clearLaneIdx] <= DESKEW_ADD_DELAY_INCREASES_PHASE ?
                  targetLaneCenterReg - laneCenterPhaseReg[clearLaneIdx] :
                  laneCenterPhaseReg[clearLaneIdx] - targetLaneCenterReg;
            end
            stateReg <= SweepState_SCALE_DESKEW;
          end

          SweepState_SCALE_DESKEW: begin
            for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                 clearLaneIdx = clearLaneIdx + 1) begin
              if (ACTIVE_LANE_MASK[clearLaneIdx])
                deskewProductReg[clearLaneIdx] <=
                  DESKEW_PRODUCT_WIDTH'(deskewDeltaReg[clearLaneIdx]) *
                  DESKEW_PRODUCT_WIDTH'(DESKEW_STEPS_PER_PI);
            end
            stateReg <= SweepState_CHECK_DESKEW;
          end

          SweepState_CHECK_DESKEW: begin
            if (allDeskewCodesFit) begin
              for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                   clearLaneIdx = clearLaneIdx + 1) begin
                selectedDeskewStepsReg[clearLaneIdx] <= ACTIVE_LANE_MASK[clearLaneIdx] ?
                  LtsmParameters_pkg::TX_DESKEW_HALF_STEP_WIDTH'(deskewProductReg[clearLaneIdx]) :
                  {LtsmParameters_pkg::TX_DESKEW_HALF_STEP_WIDTH{1'b0}};
              end
              stateReg <= SweepState_ENCODE_DESKEW;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_ENCODE_DESKEW: begin
            for (clearLaneIdx = 0; clearLaneIdx < MAX_DATA_LANES;
                 clearLaneIdx = clearLaneIdx + 1) begin
              deskewCodesReg[clearLaneIdx*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH] <=
                LtsmParameters_pkg::encode_tx_deskew(selectedDeskewStepsReg[clearLaneIdx]);
            end
            stateReg <= SweepState_APPLY_DESKEW;
          end

          SweepState_APPLY_DESKEW: begin
            if (tx_lane_deskew_applied)
              stateReg <= SweepState_CLEAR_VERIFY_RESULTS;
          end

          SweepState_CLEAR_VERIFY_RESULTS: begin
            globalRunStartReg <= '0;
            globalRunLengthReg <= '0;
            globalBestStartReg <= '0;
            globalBestLengthReg <= '0;
            phaseIndexReg <= '0;
            stateReg <= SweepState_APPLY_VERIFY_PHASE;
          end

          SweepState_APPLY_VERIFY_PHASE: begin
            if (apply_tx_clock_phase && tx_clock_phase_applied)
              stateReg <= SweepState_START_VERIFY_TEST;
          end

          SweepState_START_VERIFY_TEST: begin
            stateReg <= SweepState_WAIT_VERIFY_TEST;
          end

          SweepState_WAIT_VERIFY_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_STORE_VERIFY_RESULT;
          end

          SweepState_STORE_VERIFY_RESULT: begin
            if (pointTestAllPass) begin
              if (globalRunLengthReg == 0)
                globalRunStartReg <= phaseIndexReg;
              globalRunLengthReg <= globalRunLengthReg + 1'b1;
              if ((globalRunLengthReg + 1'b1) > globalBestLengthReg) begin
                globalBestLengthReg <= globalRunLengthReg + 1'b1;
                globalBestStartReg <= (globalRunLengthReg == 0) ?
                  phaseIndexReg : globalRunStartReg;
              end
            end else begin
              globalRunLengthReg <= '0;
            end
            lastFailedComparisonsReg <= {9'b0, failedComparisonsCalc};
            if (phaseIndexReg == PHASE_INDEX_WIDTH'(PHASE_COUNT - 1)) begin
              stateReg <= SweepState_CALCULATE_GLOBAL;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_VERIFY_PHASE;
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
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
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
            lastFailedComparisonsReg <= {9'b0, failedComparisonsCalc};
            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
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
    if (TX_DESKEW_CODE_WIDTH != LtsmParameters_pkg::TX_DESKEW_CONTROL_WIDTH)
      $error("TX_DESKEW_CODE_WIDTH must be 20 for the two-cell TX deskew controls");
    if (DESKEW_STEPS_PER_PI < 1)
      $error("DESKEW_STEPS_PER_PI must be at least 1");
    if ((MIN_LANE_WINDOW_STEPS < 1) ||
        (MIN_LANE_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_LANE_WINDOW_STEPS is outside the PI sweep range");
    if ((MIN_COMMON_WINDOW_STEPS < 1) ||
        (MIN_COMMON_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_COMMON_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire
