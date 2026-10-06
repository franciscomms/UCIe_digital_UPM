// Linear receiver-Vref sweep used by MBTRAIN.VALVREF and
// MBTRAIN.VALTRAINVREF.
//
// The engine treats Vref codes as a linear, non-wrapping range.  It tests every
// code, selects the lower midpoint of the longest contiguous passing interval,
// applies that code, and performs one final verification point test.  Ties are
// resolved in favor of the lower-code interval.  The analog PHY is responsible
// for mapping codes onto the requested voltage range (for example 0.25 V to
// 0.55 V); the digital training protocol only operates on codes.
`default_nettype none

module MBTrain_ValidVrefSweepEngine #(
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
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
  (* keep = "true" *) logic [VREF_VALUE_COUNT-1:0] passBitmapReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] finalCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] leftCodeReg;
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] rightCodeReg;
  (* keep = "true" *) logic [15:0] failedPointCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  integer scanIndex;
  integer runStartInt;
  integer runLengthInt;
  integer bestStartInt;
  integer bestLengthInt;

  // Longest linear passing interval.  The strict greater-than comparison gives
  // deterministic lower-code tie breaking and intentionally does not join the
  // first and last Vref codes.
  always_comb begin
    runStartInt   = 0;
    runLengthInt  = 0;
    bestStartInt  = 0;
    bestLengthInt = 0;

    for (scanIndex = 0; scanIndex < VREF_VALUE_COUNT; scanIndex = scanIndex + 1) begin
      if (passBitmapReg[scanIndex]) begin
        if (runLengthInt == 0)
          runStartInt = scanIndex;
        runLengthInt = runLengthInt + 1;
        if (runLengthInt > bestLengthInt) begin
          bestLengthInt = runLengthInt;
          bestStartInt  = runStartInt;
        end
      end else begin
        runLengthInt = 0;
      end
    end
  end

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
      rx_vref_code = currentCodeReg;

    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg             <= SweepState_idle;
      passBitmapReg        <= '0;
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
        passBitmapReg       <= '0;
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
              passBitmapReg[currentCodeReg] <= point_test_pass;
              if (!point_test_pass)
                failedPointCountReg <= failedPointCountReg + 16'd1;

              if (currentCodeReg == (VREF_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          SweepState_analyze: begin
            if (bestLengthInt >= MIN_PASSING_WINDOW_VALUES) begin
              // Lower midpoint for an even-width window.
              finalCodeReg <= bestStartInt + ((bestLengthInt - 1) / 2);
              leftCodeReg  <= bestStartInt;
              rightCodeReg <= bestStartInt + bestLengthInt - 1;
              stateReg     <= SweepState_applyFinalCode;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg        <= retryCountReg + 16'd1;
              passBitmapReg        <= '0;
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
                passBitmapReg        <= '0;
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
