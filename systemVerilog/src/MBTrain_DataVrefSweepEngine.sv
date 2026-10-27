// Parameterized linear receiver-Vref sweep for the UCIe Data lanes.
//
// Each active lane uses a 20-bit one-hot code: bit 0 selects the lowest tap
// and bit 19 the highest. Inactive lane slices remain zero. Internal sweep and
// window arithmetic operates on binary tap indices.
// One receiver-initiated point test is performed at each Vref tap.  The
// per-lane longest interval is tracked as results arrive.  Every active lane
// selects the lower midpoint of its longest non-wrapping passing interval.
// All selected per-lane codes are then applied together and verified by one
// final point test.
`default_nettype none

module MBTrain_DataVrefSweepEngine #(
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned VREF_VALUE_COUNT = 20,
  parameter int unsigned VREF_CODE_WIDTH = 20,
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
  // Keep a bounded running summary instead of rescanning a full pass bitmap.
  // This replaces VREF_VALUE_COUNT serial compare/mux stages with one narrow
  // increment/compare per accepted result.  COUNT+1 represents an all-pass run.
  localparam int unsigned WINDOW_LENGTH_WIDTH = $clog2(VREF_VALUE_COUNT + 1);
  localparam int unsigned FAILED_COUNT_WIDTH =
    (DATA_LANE_COUNT < 2) ? 1 : $clog2(DATA_LANE_COUNT + 1);
  localparam int unsigned COUNT_TREE_LEAVES = 1 << $clog2(DATA_LANE_COUNT);
  localparam int unsigned VREF_INDEX_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT);
  logic [VREF_INDEX_WIDTH-1:0] runStartReg [0:DATA_LANE_COUNT-1];
  logic [VREF_INDEX_WIDTH-1:0] bestStartReg [0:DATA_LANE_COUNT-1];
  logic [WINDOW_LENGTH_WIDTH-1:0] runLengthReg [0:DATA_LANE_COUNT-1];
  logic [WINDOW_LENGTH_WIDTH-1:0] bestLengthReg [0:DATA_LANE_COUNT-1];
  wire [WINDOW_LENGTH_WIDTH-1:0] extendedRunLength [0:DATA_LANE_COUNT-1];
  wire [WINDOW_LENGTH_WIDTH-1:0] bestSpan [0:DATA_LANE_COUNT-1];
  wire [DATA_LANE_COUNT-1:0] laneHasWindow;
  wire [FAILED_COUNT_WIDTH-1:0] failedCountTree [1:2*COUNT_TREE_LEAVES-1];
  (* keep = "true" *) logic [VREF_INDEX_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    finalCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    leftCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    rightCodeVectorReg;
  (* keep = "true" *) logic [15:0] failedLaneCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  function automatic logic [VREF_CODE_WIDTH-1:0] encodeVrefIndex(
    input logic [VREF_INDEX_WIDTH-1:0] tapIndex
  );
    logic [VREF_CODE_WIDTH-1:0] code;
    begin
      code = '0;
      if (int'(tapIndex) < VREF_VALUE_COUNT)
        code[tapIndex] = 1'b1;
      return code;
    end
  endfunction

  wire allActiveLanesHaveWindow = &laneHasWindow;
  wire allActiveLanesPassFinal =
    ((point_test_pass & ACTIVE_DATA_LANE_MASK) == ACTIVE_DATA_LANE_MASK);

  for (genvar lane = 0; lane < DATA_LANE_COUNT; lane = lane + 1) begin : g_window
    assign extendedRunLength[lane] = runLengthReg[lane] + 1'b1;
    assign bestSpan[lane] = bestLengthReg[lane] - 1'b1;
    assign laneHasWindow[lane] = !ACTIVE_DATA_LANE_MASK[lane] ||
      (bestLengthReg[lane] >= WINDOW_LENGTH_WIDTH'(MIN_PASSING_WINDOW_VALUES));
  end

  // Balanced population count: logarithmic lane depth, rather than a serial
  // chain of 16-bit increments through every active lane.
  for (genvar leaf = 0; leaf < COUNT_TREE_LEAVES; leaf = leaf + 1) begin : g_count_leaf
    if (leaf < DATA_LANE_COUNT) begin : g_lane
      assign failedCountTree[COUNT_TREE_LEAVES + leaf] =
        FAILED_COUNT_WIDTH'(ACTIVE_DATA_LANE_MASK[leaf] && !point_test_pass[leaf]);
    end else begin : g_padding
      assign failedCountTree[COUNT_TREE_LEAVES + leaf] = '0;
    end
  end
  for (genvar node = 1; node < COUNT_TREE_LEAVES; node = node + 1) begin : g_count_node
    assign failedCountTree[node] = failedCountTree[2*node] + failedCountTree[2*node+1];
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
            encodeVrefIndex(currentCodeReg);
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
           reset_lane = reset_lane + 1) begin
        runStartReg[reset_lane] <= '0;
        runLengthReg[reset_lane] <= '0;
        bestStartReg[reset_lane] <= '0;
        bestLengthReg[reset_lane] <= '0;
      end
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
             start_lane = start_lane + 1) begin
          runStartReg[start_lane] <= '0;
          runLengthReg[start_lane] <= '0;
          bestStartReg[start_lane] <= '0;
          bestLengthReg[start_lane] <= '0;
        end
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
                if (ACTIVE_DATA_LANE_MASK[capture_lane]) begin
                  if (point_test_pass[capture_lane]) begin
                    if (runLengthReg[capture_lane] == '0)
                      runStartReg[capture_lane] <= currentCodeReg;
                    runLengthReg[capture_lane] <= extendedRunLength[capture_lane];
                    // Strict comparison preserves the lower interval on ties.
                    if (extendedRunLength[capture_lane] > bestLengthReg[capture_lane]) begin
                      bestLengthReg[capture_lane] <= extendedRunLength[capture_lane];
                      bestStartReg[capture_lane] <= (runLengthReg[capture_lane] == '0) ?
                                                   currentCodeReg : runStartReg[capture_lane];
                    end
                  end else begin
                    runLengthReg[capture_lane] <= '0;
                  end
                end
              end
              failedLaneCountReg <= failedLaneCountReg +
                                    16'(failedCountTree[1]);

              if (currentCodeReg == VREF_INDEX_WIDTH'(VREF_VALUE_COUNT - 1)) begin
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
                  ] <= encodeVrefIndex(bestStartReg[select_lane] +
                       VREF_INDEX_WIDTH'(bestSpan[select_lane] >> 1));
                  leftCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= encodeVrefIndex(bestStartReg[select_lane]);
                  rightCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= encodeVrefIndex(bestStartReg[select_lane] +
                       VREF_INDEX_WIDTH'(bestSpan[select_lane]));
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
                   retry_lane = retry_lane + 1) begin
                runStartReg[retry_lane] <= '0;
                runLengthReg[retry_lane] <= '0;
                bestStartReg[retry_lane] <= '0;
                bestLengthReg[retry_lane] <= '0;
              end
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
                     verify_retry_lane = verify_retry_lane + 1) begin
                  runStartReg[verify_retry_lane] <= '0;
                  runLengthReg[verify_retry_lane] <= '0;
                  bestStartReg[verify_retry_lane] <= '0;
                  bestLengthReg[verify_retry_lane] <= '0;
                end
                stateReg <= SweepState_applySweepCode;
              end else begin
                failedLaneCountReg <= failedLaneCountReg +
                                      16'(failedCountTree[1]);
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
    if ((VREF_VALUE_COUNT < 1) || (VREF_VALUE_COUNT > 20))
      $error("VREF_VALUE_COUNT must be between 1 and 20");
    if (VREF_CODE_WIDTH != 20)
      $error("VREF_CODE_WIDTH must be 20 for the one-hot analog interface");
    if ((MIN_PASSING_WINDOW_VALUES < 1) ||
        (MIN_PASSING_WINDOW_VALUES > VREF_VALUE_COUNT))
      $error("MIN_PASSING_WINDOW_VALUES is outside the Vref sweep range");
  end
`endif
endmodule

`default_nettype wire
