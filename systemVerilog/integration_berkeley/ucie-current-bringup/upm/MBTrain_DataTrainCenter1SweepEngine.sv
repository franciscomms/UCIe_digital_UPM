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
// Codes are absolute values.  Inactive UCIe-S lanes [63:16] are held at zero.
//
// PI phase convention:
//   0, 1, ... PHASE_COUNT-1 is one linear ordered search range.
//   Phase 0 and phase PHASE_COUNT-1 are not adjacent and are never merged.
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

  // Local per-data-lane TX deskew interface.  apply_tx_lane_deskew remains
  // asserted with stable absolute codes until tx_lane_deskew_applied is seen.
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
  output var  logic [PI_CODE_WIDTH-1:0] finalClockPhase
);
  localparam int unsigned MAX_DATA_LANES   = 64;
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
  localparam int unsigned MAX_DESKEW_CODE_INT =
    (1 << TX_DESKEW_CODE_WIDTH) - 1;

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
    SweepState_ERROR                 = 5'd19
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic errorReg;
  (* keep = "true" *) logic [15:0] lastFailedComparisonsReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] phaseIndexReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] finalClockPhaseReg;
  (* keep = "true" *) logic [64*TX_DESKEW_CODE_WIDTH-1:0] deskewCodesReg;

  // Pass bitmap captured at every PI code before TX deskew.
  logic [63:0] initialPassByPhase [0:PHASE_COUNT-1];

  // Aggregate pass/fail captured at every PI code after TX deskew.
  logic verifyPassByPhase [0:PHASE_COUNT-1];

  // Registered results are useful for waveform/debug inspection.
  logic [PI_CODE_WIDTH-1:0] laneLeftPhaseReg   [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneRightPhaseReg  [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneCenterPhaseReg [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseReg;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseReg;

  logic [PI_CODE_WIDTH-1:0] laneLeftPhaseCalc   [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneRightPhaseCalc  [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneCenterPhaseCalc [0:MAX_DATA_LANES-1];
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] deskewCodesCalc;
  logic initialWindowsValidCalc;

  logic globalWindowValidCalc;
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalCenterPhaseCalc;

  wire allActiveDataLanesPass = &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  function automatic [15:0] countFailedComparisons(
    input logic [63:0] lanePass,
    input logic        validPass
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
      countFailedComparisons = count;
    end
  endfunction

  // Search each active lane over the implemented PI range exactly once.
  // Phase code PHASE_COUNT-1 is not adjacent to phase code 0: the two ends
  // may belong to different UIs and are therefore never merged.
  integer laneIdx;
  integer phaseIdx;
  integer runLength;
  integer bestLength;
  integer runStart;
  integer bestStart;
  integer laneCenterInt;
  integer minLaneCenterInt;
  integer maxLaneCenterInt;
  integer targetLaneCenterInt;
  integer deskewDeltaInt;
  integer deskewCodeInt;

  always_comb begin
    initialWindowsValidCalc = 1'b1;
    deskewCodesCalc = '0;

    // Defaults for combinational temporaries.
    phaseIdx = 0;
    runLength = 0;
    bestLength = 0;
    runStart = 0;
    bestStart = 0;
    laneCenterInt = 0;
    minLaneCenterInt = PHASE_COUNT - 1;
    maxLaneCenterInt = 0;
    targetLaneCenterInt = 0;
    deskewDeltaInt = 0;
    deskewCodeInt = 0;

    // First find the longest linear passing interval and its center for every
    // active lane. If two intervals have the same length, the lower-phase
    // interval is retained because bestLength is updated only on a longer run.
    for (laneIdx = 0; laneIdx < MAX_DATA_LANES; laneIdx = laneIdx + 1) begin
      laneLeftPhaseCalc[laneIdx] = '0;
      laneRightPhaseCalc[laneIdx] = '0;
      laneCenterPhaseCalc[laneIdx] = '0;

      if (ACTIVE_LANE_MASK[laneIdx]) begin
        runLength = 0;
        bestLength = 0;
        runStart = 0;
        bestStart = 0;

        for (phaseIdx = 0; phaseIdx < PHASE_COUNT; phaseIdx = phaseIdx + 1) begin
          if (initialPassByPhase[phaseIdx][laneIdx]) begin
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

        if (bestLength < MIN_LANE_WINDOW_STEPS) begin
          initialWindowsValidCalc = 1'b0;
        end else begin
          laneCenterInt = bestStart + ((bestLength - 1) >> 1);
          laneLeftPhaseCalc[laneIdx] = bestStart;
          laneRightPhaseCalc[laneIdx] = bestStart + bestLength - 1;
          laneCenterPhaseCalc[laneIdx] = laneCenterInt;

          if (laneCenterInt < minLaneCenterInt)
            minLaneCenterInt = laneCenterInt;
          if (laneCenterInt > maxLaneCenterInt)
            maxLaneCenterInt = laneCenterInt;
        end
      end
    end

    // The local TX deskew can only add delay. Select the latest measured lane
    // center when added delay moves the eye toward larger PI codes; select the
    // earliest center for the opposite PHY polarity.
    if (DESKEW_ADD_DELAY_INCREASES_PHASE)
      targetLaneCenterInt = maxLaneCenterInt;
    else
      targetLaneCenterInt = minLaneCenterInt;

    for (laneIdx = 0; laneIdx < MAX_DATA_LANES; laneIdx = laneIdx + 1) begin
      if (ACTIVE_LANE_MASK[laneIdx]) begin
        laneCenterInt = laneCenterPhaseCalc[laneIdx];

        if (DESKEW_ADD_DELAY_INCREASES_PHASE)
          deskewDeltaInt = targetLaneCenterInt - laneCenterInt;
        else
          deskewDeltaInt = laneCenterInt - targetLaneCenterInt;

        deskewCodeInt = deskewDeltaInt * DESKEW_STEPS_PER_PI;
        if ((deskewCodeInt < 0) ||
            (deskewCodeInt > MAX_DESKEW_CODE_INT)) begin
          initialWindowsValidCalc = 1'b0;
          deskewCodesCalc[
            laneIdx*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH
          ] = '0;
        end else begin
          deskewCodesCalc[
            laneIdx*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH
          ] = deskewCodeInt;
        end
      end
    end
  end

  // Find the longest linear interval in which all active data lanes, Valid,
  // and the partner's cumulative comparison result pass after TX deskew.
  integer globalPhaseIdx;
  integer globalRunLength;
  integer globalBestLength;
  integer globalRunStart;
  integer globalBestStart;

  always_comb begin
    globalRunLength = 0;
    globalBestLength = 0;
    globalRunStart = 0;
    globalBestStart = 0;

    for (globalPhaseIdx = 0;
         globalPhaseIdx < PHASE_COUNT;
         globalPhaseIdx = globalPhaseIdx + 1) begin
      if (verifyPassByPhase[globalPhaseIdx]) begin
        if (globalRunLength == 0)
          globalRunStart = globalPhaseIdx;

        globalRunLength = globalRunLength + 1;
        if (globalRunLength > globalBestLength) begin
          globalBestLength = globalRunLength;
          globalBestStart = globalRunStart;
        end
      end else begin
        globalRunLength = 0;
      end
    end

    globalWindowValidCalc =
      (globalBestLength >= MIN_COMMON_WINDOW_STEPS);

    if (globalBestLength == 0) begin
      globalLeftPhaseCalc = '0;
      globalRightPhaseCalc = '0;
      globalCenterPhaseCalc = '0;
    end else begin
      globalLeftPhaseCalc = globalBestStart;
      globalRightPhaseCalc = globalBestStart + globalBestLength - 1;
      globalCenterPhaseCalc =
        globalBestStart + ((globalBestLength - 1) >> 1);
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

    tx_clock_phase_code = phaseIndexReg;
    tx_lane_deskew_codes = deskewCodesReg;

    apply_tx_clock_phase =
      (stateReg == SweepState_APPLY_INITIAL_PHASE) ||
      (stateReg == SweepState_APPLY_VERIFY_PHASE) ||
      (stateReg == SweepState_APPLY_GLOBAL_PHASE);

    apply_tx_lane_deskew =
      (stateReg == SweepState_APPLY_ZERO_DESKEW) ||
      (stateReg == SweepState_APPLY_DESKEW);

    point_test_start =
      (stateReg == SweepState_START_INITIAL_TEST) ||
      (stateReg == SweepState_START_VERIFY_TEST) ||
      (stateReg == SweepState_START_FINAL_TEST);
  end

  integer clearLaneIdx;

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
      for (clearLaneIdx = 0;
           clearLaneIdx < MAX_DATA_LANES;
           clearLaneIdx = clearLaneIdx + 1) begin
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
        // Both sweep memories are completely overwritten before they are read;
        // avoiding a bulk clear keeps the implementation from inferring a very
        // large one-cycle reset/clear network.
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
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_APPLY_INITIAL_PHASE: begin
            if (tx_clock_phase_applied)
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
            initialPassByPhase[phaseIndexReg] <= point_test_lane_pass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass, point_test_valid_pass
            );
            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
              stateReg <= SweepState_CALCULATE_DESKEW;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_CALCULATE_DESKEW: begin
            if (initialWindowsValidCalc) begin
              deskewCodesReg <= deskewCodesCalc;
              for (clearLaneIdx = 0;
                   clearLaneIdx < MAX_DATA_LANES;
                   clearLaneIdx = clearLaneIdx + 1) begin
                laneLeftPhaseReg[clearLaneIdx] <= laneLeftPhaseCalc[clearLaneIdx];
                laneRightPhaseReg[clearLaneIdx] <= laneRightPhaseCalc[clearLaneIdx];
                laneCenterPhaseReg[clearLaneIdx] <= laneCenterPhaseCalc[clearLaneIdx];
              end
              stateReg <= SweepState_APPLY_DESKEW;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              // A retry overwrites every phase entry before recalculation.
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_DESKEW: begin
            if (tx_lane_deskew_applied)
              stateReg <= SweepState_CLEAR_VERIFY_RESULTS;
          end

          SweepState_CLEAR_VERIFY_RESULTS: begin
            // The following sweep writes every entry in verifyPassByPhase.
            phaseIndexReg <= '0;
            stateReg <= SweepState_APPLY_VERIFY_PHASE;
          end

          SweepState_APPLY_VERIFY_PHASE: begin
            if (tx_clock_phase_applied)
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
            verifyPassByPhase[phaseIndexReg] <= pointTestAllPass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass, point_test_valid_pass
            );
            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
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
              // A retry overwrites every phase entry before recalculation.
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
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
              point_test_lane_pass, point_test_valid_pass
            );
            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              // A retry overwrites every phase entry before recalculation.
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
  initial begin
    if ((PI_CODE_WIDTH < 2) || (PI_CODE_WIDTH > 10))
      $error("PI_CODE_WIDTH must be in the range 2..10");
    if ((TX_DESKEW_CODE_WIDTH < 1) || (TX_DESKEW_CODE_WIDTH > 16))
      $error("TX_DESKEW_CODE_WIDTH must be in the range 1..16");
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
