// Parameterized linear receiver lane-deskew sweep for UCIe MBTRAIN.RXDESKEW.
//
// One receiver-initiated D2C point test is performed at each RX deskew code.
// All active Data receiver lanes are swept in parallel with the same code.
// Every lane independently selects the lower midpoint of its longest linear,
// non-wrapping passing interval.  The selected per-lane vector is then applied
// and verified with one final point test.
`default_nettype none

module MBTrain_RxDeskewSweepEngine #(
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned RX_DESKEW_VALUE_COUNT = 16,
  parameter int unsigned RX_DESKEW_CODE_WIDTH =
    (RX_DESKEW_VALUE_COUNT <= 1) ? 1 : $clog2(RX_DESKEW_VALUE_COUNT),
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output      logic busy,
  output      logic done,
  output      logic trainError,

  // During the linear sweep every active lane receives the same delay code.
  // During final application, each lane receives its independently selected
  // delay code.  Code polarity/range are PHY implementation details.
  output      logic apply_rx_lane_deskew,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    rx_lane_deskew_codes,
  input  wire logic rx_lane_deskew_applied,

  output      logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [DATA_LANE_COUNT-1:0] point_test_pass,

  output      logic [3:0] state,
  output      logic [15:0] lastFailedLaneCount,
  output      logic [15:0] retryCount,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    finalRxDeskewCodes,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    validWindowLeftCodes,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    validWindowRightCodes
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
  // Track one accepted sample per cycle instead of rescanning the complete
  // bitmap combinationally.  The extra length bit represents an all-pass sweep.
  localparam int unsigned WINDOW_LENGTH_WIDTH = $clog2(RX_DESKEW_VALUE_COUNT + 1);
  typedef logic [RX_DESKEW_CODE_WIDTH-1:0] code_t;
  typedef logic [WINDOW_LENGTH_WIDTH-1:0] window_length_t;
  code_t runStartReg [0:DATA_LANE_COUNT-1];
  code_t bestStartReg [0:DATA_LANE_COUNT-1];
  window_length_t runLengthReg [0:DATA_LANE_COUNT-1];
  window_length_t bestLengthReg [0:DATA_LANE_COUNT-1];
  window_length_t nextRunLength [0:DATA_LANE_COUNT-1];
  (* keep = "true" *) logic [RX_DESKEW_CODE_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    finalCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    leftCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    rightCodeVectorReg;
  (* keep = "true" *) logic [15:0] failedLaneCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  logic [DATA_LANE_COUNT-1:0] laneHasWindow;
  wire allActiveLanesHaveWindow = &laneHasWindow;
  wire allActiveLanesPassFinal =
    ((point_test_pass & ACTIVE_DATA_LANE_MASK) == ACTIVE_DATA_LANE_MASK);

  for (genvar lane = 0; lane < DATA_LANE_COUNT; lane++) begin : windowStatus
    assign nextRunLength[lane] = runLengthReg[lane] + window_length_t'(1);
    assign laneHasWindow[lane] = !ACTIVE_DATA_LANE_MASK[lane] ||
      (bestLengthReg[lane] >= window_length_t'(MIN_PASSING_WINDOW_VALUES));
  end

  // A balanced reduction avoids a lane-by-lane chain of 16-bit additions.
  localparam int unsigned COUNT_LEAVES = 1 << $clog2(DATA_LANE_COUNT);
  localparam int unsigned FAIL_COUNT_WIDTH = $clog2(DATA_LANE_COUNT + 1);
  wire [FAIL_COUNT_WIDTH-1:0] failedCountTree [1:2*COUNT_LEAVES-1];
  for (genvar leaf = 0; leaf < COUNT_LEAVES; leaf++) begin : failedCountLeaves
    if (leaf < DATA_LANE_COUNT) begin : activeLeaf
      assign failedCountTree[COUNT_LEAVES+leaf] =
        FAIL_COUNT_WIDTH'(ACTIVE_DATA_LANE_MASK[leaf] && !point_test_pass[leaf]);
    end else begin : paddingLeaf
      assign failedCountTree[COUNT_LEAVES+leaf] = '0;
    end
  end
  for (genvar node = 1; node < COUNT_LEAVES; node++) begin : failedCountBranches
    assign failedCountTree[node] = failedCountTree[2*node] + failedCountTree[2*node+1];
  end

  always_comb begin
    busy       = (stateReg != SweepState_idle) &&
                 (stateReg != SweepState_done) &&
                 (stateReg != SweepState_error);
    done       = (stateReg == SweepState_done);
    trainError = (stateReg == SweepState_error);

    state                 = stateReg;
    lastFailedLaneCount   = failedLaneCountReg;
    retryCount            = retryCountReg;
    finalRxDeskewCodes    = finalCodeVectorReg;
    validWindowLeftCodes  = leftCodeVectorReg;
    validWindowRightCodes = rightCodeVectorReg;

    apply_rx_lane_deskew = (stateReg == SweepState_applySweepCode) ||
                           (stateReg == SweepState_applyFinalCodes);
    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);

    rx_lane_deskew_codes = '0;
    if ((stateReg == SweepState_applyFinalCodes) ||
        (stateReg == SweepState_startFinalPoint) ||
        (stateReg == SweepState_waitFinalPoint) ||
        (stateReg == SweepState_done)) begin
      rx_lane_deskew_codes = finalCodeVectorReg;
    end else begin
      for (int unsigned output_lane = 0;
           output_lane < DATA_LANE_COUNT;
           output_lane = output_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[output_lane])
          rx_lane_deskew_codes[
            output_lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH
          ] = currentCodeReg;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg           <= SweepState_idle;
      currentCodeReg     <= '0;
      finalCodeVectorReg <= '0;
      leftCodeVectorReg  <= '0;
      rightCodeVectorReg <= '0;
      failedLaneCountReg <= 16'd0;
      retryCountReg      <= 16'd0;
      for (int unsigned reset_lane = 0;
           reset_lane < DATA_LANE_COUNT;
           reset_lane = reset_lane + 1) begin
        runStartReg[reset_lane] <= '0;
        bestStartReg[reset_lane] <= '0;
        runLengthReg[reset_lane] <= '0;
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
          bestStartReg[start_lane] <= '0;
          runLengthReg[start_lane] <= '0;
          bestLengthReg[start_lane] <= '0;
        end
      end else begin
        unique case (stateReg)
          SweepState_idle: ;

          SweepState_applySweepCode: begin
            if (rx_lane_deskew_applied)
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
                    runLengthReg[capture_lane] <= nextRunLength[capture_lane];
                    // Strict > keeps the first (lowest-code) window on ties.
                    if (nextRunLength[capture_lane] > bestLengthReg[capture_lane]) begin
                      bestLengthReg[capture_lane] <= nextRunLength[capture_lane];
                      bestStartReg[capture_lane] <=
                        (runLengthReg[capture_lane] == '0) ?
                        currentCodeReg : runStartReg[capture_lane];
                    end
                  end else begin
                    runLengthReg[capture_lane] <= '0;
                  end
                end
              end
              failedLaneCountReg <= failedLaneCountReg +
                                    16'(failedCountTree[1]);

              if (currentCodeReg == (RX_DESKEW_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          // The final sample has updated the window registers before this
          // state selects endpoints and the lower midpoint.
          SweepState_analyze: begin
            if (allActiveLanesHaveWindow) begin
              for (int unsigned select_lane = 0;
                   select_lane < DATA_LANE_COUNT;
                   select_lane = select_lane + 1) begin
                if (ACTIVE_DATA_LANE_MASK[select_lane]) begin
                  finalCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartReg[select_lane] +
                       code_t'((bestLengthReg[select_lane] - window_length_t'(1)) >> 1);
                  leftCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartReg[select_lane];
                  rightCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartReg[select_lane] +
                       code_t'(bestLengthReg[select_lane] - window_length_t'(1));
                end else begin
                  finalCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                  leftCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                  rightCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                end
              end
              stateReg <= SweepState_applyFinalCodes;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg      <= retryCountReg + 16'd1;
              currentCodeReg     <= '0;
              failedLaneCountReg <= 16'd0;
              for (int unsigned retry_lane = 0;
                   retry_lane < DATA_LANE_COUNT;
                   retry_lane = retry_lane + 1) begin
                runStartReg[retry_lane] <= '0;
                bestStartReg[retry_lane] <= '0;
                runLengthReg[retry_lane] <= '0;
                bestLengthReg[retry_lane] <= '0;
              end
              stateReg <= SweepState_applySweepCode;
            end else begin
              stateReg <= SweepState_error;
            end
          end

          SweepState_applyFinalCodes: begin
            if (rx_lane_deskew_applied)
              stateReg <= SweepState_startFinalPoint;
          end

          SweepState_startFinalPoint:
            stateReg <= SweepState_waitFinalPoint;

          SweepState_waitFinalPoint: begin
            if (point_test_done) begin
              if (allActiveLanesPassFinal) begin
                stateReg <= SweepState_done;
              end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
                retryCountReg      <= retryCountReg + 16'd1;
                currentCodeReg     <= '0;
                failedLaneCountReg <= 16'd0;
                for (int unsigned verify_retry_lane = 0;
                     verify_retry_lane < DATA_LANE_COUNT;
                     verify_retry_lane = verify_retry_lane + 1) begin
                  runStartReg[verify_retry_lane] <= '0;
                  bestStartReg[verify_retry_lane] <= '0;
                  runLengthReg[verify_retry_lane] <= '0;
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
    if (RX_DESKEW_VALUE_COUNT < 2)
      $error("RX_DESKEW_VALUE_COUNT must be at least 2");
    if (RX_DESKEW_VALUE_COUNT > (1 << RX_DESKEW_CODE_WIDTH))
      $error("RX_DESKEW_CODE_WIDTH cannot represent every deskew value");
    if ((MIN_PASSING_WINDOW_VALUES < 1) ||
        (MIN_PASSING_WINDOW_VALUES > RX_DESKEW_VALUE_COUNT))
      $error("MIN_PASSING_WINDOW_VALUES is outside the RX deskew sweep range");
  end
`endif
endmodule

`default_nettype wire
