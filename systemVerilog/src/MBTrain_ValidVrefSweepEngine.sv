// Linear receiver-Vref sweep used by MBTRAIN.VALVREF and
// MBTRAIN.VALTRAINVREF.
//
// The 20-bit Vref interface uses one-hot codes: bit 0 selects the lowest
// voltage tap and bit 19 the highest. Sweep arithmetic uses binary tap indices.
// The engine treats Vref taps as a linear, non-wrapping range.  It tests every
// code, selects the lower midpoint of the longest contiguous passing interval,
// applies that code, and performs one final verification point test.  Ties are
// resolved in favor of the lower-code interval.  The analog PHY is responsible
// for mapping codes onto the requested voltage range (for example 0.25 V to
// 0.55 V); the digital training protocol only operates on codes.
`default_nettype none

module MBTrain_ValidVrefSweepEngine #(
  parameter int unsigned VREF_VALUE_COUNT = 20,
  parameter int unsigned VREF_CODE_WIDTH = 20,
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic                          clock,
  input  wire logic                          reset_n,
  input  wire logic                          start,

  output      logic                          busy,
  output      logic                          done,
  output      logic                          trainError,

  output      logic                          apply_rx_vref,
  output      logic [VREF_CODE_WIDTH-1:0]    rx_vref_code,
  input  wire logic                          rx_vref_applied,

  output      logic                          point_test_start,
  input  wire logic                          point_test_done,
  input  wire logic                          point_test_pass,

  output      logic [3:0]                    state,
  output      logic [15:0]                   lastFailedPointCount,
  output      logic [15:0]                   retryCount,
  output      logic [VREF_CODE_WIDTH-1:0]    finalVrefCode,
  output      logic [VREF_CODE_WIDTH-1:0]    validLeftCode,
  output      logic [VREF_CODE_WIDTH-1:0]    validRightCode
);
  typedef enum logic [3:0] {
    SweepState_idle             = 4'h0,
    SweepState_applySweepCode   = 4'h1,
    SweepState_startSweepPoint  = 4'h2,
    SweepState_waitSweepPoint   = 4'h3,
    SweepState_analyze          = 4'h4,
    SweepState_applyFinalCode   = 4'h5,
    SweepState_startFinalPoint  = 4'h6,
    SweepState_waitFinalPoint   = 4'h7,
    SweepState_done             = 4'h8,
    SweepState_error            = 4'h9
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  // Track each window as its test results arrive.  A combinational scan of a
  // complete bitmap unrolls into VREF_VALUE_COUNT dependent compare/mux stages.
  // The length needs one extra value for an all-passing, full-range window.
  localparam int unsigned WINDOW_LENGTH_WIDTH = $clog2(VREF_VALUE_COUNT + 1);
  localparam int unsigned VREF_INDEX_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT);
  logic [VREF_INDEX_WIDTH-1:0] runStartReg, bestStartReg;
  logic [WINDOW_LENGTH_WIDTH-1:0] runLengthReg, bestLengthReg;
  wire [WINDOW_LENGTH_WIDTH-1:0] extendedRunLength = runLengthReg + 1'b1;
  wire [WINDOW_LENGTH_WIDTH-1:0] bestSpan = bestLengthReg - 1'b1;
  (* keep = "true" *) logic [VREF_INDEX_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] finalCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] leftCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] rightCodeReg;
  (* keep = "true" *) logic [15:0] failedPointCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  // Selected/window code outputs are zero until a valid window is selected.
  // During a sweep/apply, the analog control always selects exactly one tap.
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

  always_comb begin
    busy                 = (stateReg != SweepState_idle) &&
                           (stateReg != SweepState_done) &&
                           (stateReg != SweepState_error);
    done                 = (stateReg == SweepState_done);
    trainError           = (stateReg == SweepState_error);
    state                = stateReg;
    lastFailedPointCount = failedPointCountReg;
    retryCount           = retryCountReg;
    finalVrefCode        = finalCodeReg;
    validLeftCode        = leftCodeReg;
    validRightCode       = rightCodeReg;

    apply_rx_vref = (stateReg == SweepState_applySweepCode) ||
                    (stateReg == SweepState_applyFinalCode);
    if ((stateReg == SweepState_applyFinalCode) ||
        (stateReg == SweepState_startFinalPoint) ||
        (stateReg == SweepState_waitFinalPoint) ||
        (stateReg == SweepState_done))
      rx_vref_code = finalCodeReg;
    else
      rx_vref_code = encodeVrefIndex(currentCodeReg);

    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg             <= SweepState_idle;
      runStartReg         <= '0;
      runLengthReg        <= '0;
      bestStartReg        <= '0;
      bestLengthReg       <= '0;
      currentCodeReg       <= '0;
      finalCodeReg         <= '0;
      leftCodeReg          <= '0;
      rightCodeReg         <= '0;
      failedPointCountReg  <= 16'd0;
      retryCountReg        <= 16'd0;
    end else begin
      if (start && ((stateReg == SweepState_idle) ||
                    (stateReg == SweepState_done) ||
                    (stateReg == SweepState_error))) begin
        stateReg            <= SweepState_applySweepCode;
        runStartReg         <= '0;
        runLengthReg        <= '0;
        bestStartReg        <= '0;
        bestLengthReg       <= '0;
        currentCodeReg      <= '0;
        finalCodeReg        <= '0;
        leftCodeReg         <= '0;
        rightCodeReg        <= '0;
        failedPointCountReg <= 16'd0;
        retryCountReg       <= 16'd0;
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
              // Strictly greater replacement keeps the first (lowest-code)
              // interval on a tie.  A failure ends the run; endpoints do not wrap.
              if (point_test_pass) begin
                if (runLengthReg == '0)
                  runStartReg         <= currentCodeReg;
                runLengthReg        <= extendedRunLength;
                if (extendedRunLength > bestLengthReg) begin
                  bestLengthReg       <= extendedRunLength;
                  bestStartReg        <= (runLengthReg == '0) ?
                                  currentCodeReg : runStartReg;
                end
              end else begin
                runLengthReg        <= '0;
              end
              if (!point_test_pass)
                failedPointCountReg <= failedPointCountReg + 16'd1;

              if (currentCodeReg == VREF_INDEX_WIDTH'(VREF_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          SweepState_analyze: begin
            if (bestLengthReg >= WINDOW_LENGTH_WIDTH'(MIN_PASSING_WINDOW_VALUES)) begin
              // Lower midpoint for an even-width window.
              finalCodeReg <= encodeVrefIndex(
                bestStartReg + VREF_INDEX_WIDTH'(bestSpan >> 1));
              leftCodeReg  <= encodeVrefIndex(bestStartReg);
              rightCodeReg <= encodeVrefIndex(
                bestStartReg + VREF_INDEX_WIDTH'(bestSpan));
              stateReg     <= SweepState_applyFinalCode;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg        <= retryCountReg + 16'd1;
              runStartReg         <= '0;
              runLengthReg        <= '0;
              bestStartReg        <= '0;
              bestLengthReg       <= '0;
              currentCodeReg       <= '0;
              failedPointCountReg  <= 16'd0;
              stateReg             <= SweepState_applySweepCode;
            end else begin
              stateReg <= SweepState_error;
            end
          end

          SweepState_applyFinalCode: begin
            if (rx_vref_applied)
              stateReg <= SweepState_startFinalPoint;
          end

          SweepState_startFinalPoint:
            stateReg <= SweepState_waitFinalPoint;

          SweepState_waitFinalPoint: begin
            if (point_test_done) begin
              if (point_test_pass) begin
                stateReg <= SweepState_done;
              end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
                retryCountReg        <= retryCountReg + 16'd1;
                runStartReg         <= '0;
                runLengthReg        <= '0;
                bestStartReg        <= '0;
                bestLengthReg       <= '0;
                currentCodeReg       <= '0;
                failedPointCountReg  <= 16'd0;
                stateReg             <= SweepState_applySweepCode;
              end else begin
                failedPointCountReg <= failedPointCountReg + 16'd1;
                stateReg            <= SweepState_error;
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
