// Parameterized linear receiver-Vref sweep for the UCIe Data lanes.
//
// One receiver-initiated point test is performed at each Vref code.  The
// per-lane result vector is retained, and every active lane independently
// selects the lower midpoint of its longest non-wrapping passing interval.
// All selected per-lane codes are then applied together and verified by one
// final point test.
`default_nettype none

module MBTrain_DataVrefSweepEngine #(
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output      logic busy,
  output      logic done,
  output      logic trainError,

  // During the linear sweep every active lane receives the same code.  During
  // final application, each lane receives its independently selected code.
  output      logic apply_rx_vref,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] rx_vref_codes,
  input  wire logic rx_vref_applied,

  output      logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [DATA_LANE_COUNT-1:0] point_test_pass,

  output      logic [3:0] state,
  output      logic [15:0] lastFailedLaneCount,
  output      logic [15:0] retryCount,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] finalVrefCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validLeftCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validRightCodes
);
  typedef enum logic [3:0] {
    SweepState_idle             = 4'h0,
    SweepState_applySweepCode   = 4'h1,
    SweepState_startSweepPoint  = 4'h2,
    SweepState_waitSweepPoint   = 4'h3,
    SweepState_analyze          = 4'h4,
    SweepState_applyFinalCodes  = 4'h5,
    SweepState_startFinalPoint  = 4'h6,
    SweepState_waitFinalPoint   = 4'h7,
    SweepState_done             = 4'h8,
    SweepState_error            = 4'h9
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic [VREF_VALUE_COUNT-1:0]
    passBitmapReg [0:DATA_LANE_COUNT-1];
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    finalCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    leftCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    rightCodeVectorReg;
  (* keep = "true" *) logic [15:0] failedLaneCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  // These combinational analysis arrays are assigned by one process only.
  integer runStartInt [0:DATA_LANE_COUNT-1];
  integer runLengthInt [0:DATA_LANE_COUNT-1];
  integer bestStartInt [0:DATA_LANE_COUNT-1];
  integer bestLengthInt [0:DATA_LANE_COUNT-1];
  integer scanLane;
  integer scanCode;
  logic allActiveLanesHaveWindow;
  logic allActiveLanesPassFinal;

  function automatic logic [15:0] count_failed_active_lanes(
    input logic [DATA_LANE_COUNT-1:0] pass_vector
  );
    integer count_lane;
    begin
      count_failed_active_lanes = 16'd0;
      for (count_lane = 0; count_lane < DATA_LANE_COUNT;
           count_lane = count_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[count_lane] && !pass_vector[count_lane])
          count_failed_active_lanes = count_failed_active_lanes + 16'd1;
      end
    end
  endfunction

  // Find each active lane's longest linear passing interval.  Strictly-greater
  // replacement preserves the lower-code interval when two windows tie and
  // deliberately does not join the first and last Vref codes.
  always_comb begin
    allActiveLanesHaveWindow = 1'b1;

    for (scanLane = 0; scanLane < DATA_LANE_COUNT;
         scanLane = scanLane + 1) begin
      runStartInt[scanLane]   = 0;
      runLengthInt[scanLane]  = 0;
      bestStartInt[scanLane]  = 0;
      bestLengthInt[scanLane] = 0;

      for (scanCode = 0; scanCode < VREF_VALUE_COUNT;
           scanCode = scanCode + 1) begin
        if (passBitmapReg[scanLane][scanCode]) begin
          if (runLengthInt[scanLane] == 0)
            runStartInt[scanLane] = scanCode;
          runLengthInt[scanLane] = runLengthInt[scanLane] + 1;
          if (runLengthInt[scanLane] > bestLengthInt[scanLane]) begin
            bestLengthInt[scanLane] = runLengthInt[scanLane];
            bestStartInt[scanLane]  = runStartInt[scanLane];
          end
        end else begin
          runLengthInt[scanLane] = 0;
        end
      end

      if (ACTIVE_DATA_LANE_MASK[scanLane] &&
          (bestLengthInt[scanLane] < MIN_PASSING_WINDOW_VALUES))
        allActiveLanesHaveWindow = 1'b0;
    end

    allActiveLanesPassFinal =
      ((point_test_pass & ACTIVE_DATA_LANE_MASK) == ACTIVE_DATA_LANE_MASK);
  end

  always_comb begin
    busy       = (stateReg != SweepState_idle) &&
                 (stateReg != SweepState_done) &&
                 (stateReg != SweepState_error);
    done       = (stateReg == SweepState_done);
    trainError = (stateReg == SweepState_error);

    state               = stateReg;
    lastFailedLaneCount = failedLaneCountReg;
    retryCount          = retryCountReg;
    finalVrefCodes      = finalCodeVectorReg;
    validLeftCodes      = leftCodeVectorReg;
    validRightCodes     = rightCodeVectorReg;

    apply_rx_vref = (stateReg == SweepState_applySweepCode) ||
                    (stateReg == SweepState_applyFinalCodes);
    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);

    rx_vref_codes = '0;
    if ((stateReg == SweepState_applyFinalCodes) ||
        (stateReg == SweepState_startFinalPoint) ||
        (stateReg == SweepState_waitFinalPoint) ||
        (stateReg == SweepState_done)) begin
      rx_vref_codes = finalCodeVectorReg;
    end else begin
      for (int unsigned output_lane = 0;
           output_lane < DATA_LANE_COUNT;
           output_lane = output_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[output_lane])
          rx_vref_codes[output_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] =
            currentCodeReg;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg            <= SweepState_idle;
      currentCodeReg      <= '0;
      finalCodeVectorReg  <= '0;
      leftCodeVectorReg   <= '0;
      rightCodeVectorReg  <= '0;
      failedLaneCountReg  <= 16'd0;
      retryCountReg       <= 16'd0;
      for (int unsigned reset_lane = 0;
           reset_lane < DATA_LANE_COUNT;
           reset_lane = reset_lane + 1)
        passBitmapReg[reset_lane] <= '0;
    end else begin
      if (start && ((stateReg == SweepState_idle) ||
                    (stateReg == SweepState_done) ||
                    (stateReg == SweepState_error))) begin
        stateReg           <= SweepState_applySweepCode;
        currentCodeReg     <= '0;
        finalCodeVectorReg <= '0;
        leftCodeVectorReg  <= '0;
        rightCodeVectorReg <= '0;
        failedLaneCountReg <= 16'd0;
        retryCountReg      <= 16'd0;
        for (int unsigned start_lane = 0;
             start_lane < DATA_LANE_COUNT;
             start_lane = start_lane + 1)
          passBitmapReg[start_lane] <= '0;
      end else begin
        unique case (stateReg)
          SweepState_idle: ;

          SweepState_applySweepCode: begin
            if (rx_vref_applied)
              stateReg <= SweepState_startSweepPoint;
          end

          SweepState_startSweepPoint:
            stateReg <= SweepState_waitSweepPoint;

          SweepState_waitSweepPoint: begin
            if (point_test_done) begin
              for (int unsigned capture_lane = 0;
                   capture_lane < DATA_LANE_COUNT;
                   capture_lane = capture_lane + 1) begin
                passBitmapReg[capture_lane][currentCodeReg] <=
                  point_test_pass[capture_lane];
              end
              failedLaneCountReg <= failedLaneCountReg +
                                    count_failed_active_lanes(point_test_pass);

              if (currentCodeReg == (VREF_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          SweepState_analyze: begin
            if (allActiveLanesHaveWindow) begin
              for (int unsigned select_lane = 0;
                   select_lane < DATA_LANE_COUNT;
                   select_lane = select_lane + 1) begin
                if (ACTIVE_DATA_LANE_MASK[select_lane]) begin
                  finalCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       ((bestLengthInt[select_lane] - 1) / 2);
                  leftCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane];
                  rightCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       bestLengthInt[select_lane] - 1;
                end else begin
                  finalCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                  leftCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                  rightCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                end
              end
              stateReg <= SweepState_applyFinalCodes;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg       <= retryCountReg + 16'd1;
              currentCodeReg      <= '0;
              failedLaneCountReg  <= 16'd0;
              for (int unsigned retry_lane = 0;
                   retry_lane < DATA_LANE_COUNT;
                   retry_lane = retry_lane + 1)
                passBitmapReg[retry_lane] <= '0;
              stateReg <= SweepState_applySweepCode;
            end else begin
              stateReg <= SweepState_error;
            end
          end

          SweepState_applyFinalCodes: begin
            if (rx_vref_applied)
              stateReg <= SweepState_startFinalPoint;
          end

          SweepState_startFinalPoint:
            stateReg <= SweepState_waitFinalPoint;

          SweepState_waitFinalPoint: begin
            if (point_test_done) begin
              if (allActiveLanesPassFinal) begin
                stateReg <= SweepState_done;
              end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
                retryCountReg       <= retryCountReg + 16'd1;
                currentCodeReg      <= '0;
                failedLaneCountReg  <= 16'd0;
                for (int unsigned verify_retry_lane = 0;
                     verify_retry_lane < DATA_LANE_COUNT;
                     verify_retry_lane = verify_retry_lane + 1)
                  passBitmapReg[verify_retry_lane] <= '0;
                stateReg <= SweepState_applySweepCode;
              end else begin
                failedLaneCountReg <= failedLaneCountReg +
                                      count_failed_active_lanes(point_test_pass);
                stateReg <= SweepState_error;
              end
            end
          end

          SweepState_done: ;
          SweepState_error: ;
          default: stateReg <= SweepState_idle;
        endcase
      end
    end
  end

`ifndef SYNTHESIS
  initial begin
    if (DATA_LANE_COUNT < 1)
      $error("DATA_LANE_COUNT must be at least 1");
    if (ACTIVE_DATA_LANE_MASK == '0)
      $error("ACTIVE_DATA_LANE_MASK must enable at least one lane");
    if (VREF_VALUE_COUNT < 2)
      $error("VREF_VALUE_COUNT must be at least 2");
    if (VREF_VALUE_COUNT > (1 << VREF_CODE_WIDTH))
      $error("VREF_CODE_WIDTH cannot represent every Vref value");
    if ((MIN_PASSING_WINDOW_VALUES < 1) ||
        (MIN_PASSING_WINDOW_VALUES > VREF_VALUE_COUNT))
      $error("MIN_PASSING_WINDOW_VALUES is outside the Vref sweep range");
  end
`endif
endmodule

`default_nettype wire
