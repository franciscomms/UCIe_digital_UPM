// MBTRAIN.VALTRAINCENTER local transmitter Valid-to-clock centering engine.
//
// The UCIe sideband point-test protocol is handled by the wrapper. For every
// one-cycle point_test_start pulse, the wrapper runs one complete Tx-initiated
// D2C point test and returns the remote receiver's Valid-lane result with
// point_test_done.
//
// PI codes are treated as a linear ordered interval. Code zero and code
// PHASE_COUNT-1 are not adjacent; passing runs at the two boundaries are never
// merged. If two passing runs have equal length, the lower-code run wins.
`default_nettype none

module MBTrain_ValTrainCenterSweepEngine #(
  parameter int unsigned PI_CODE_WIDTH =
    LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned MIN_VALID_WINDOW_STEPS =
    LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned MAX_TRAINING_RETRIES =
    LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
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

  output var logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic point_test_valid_pass,

  output var logic [3:0]  state,
  output var logic [15:0] lastFailedComparisons,
  output var logic [15:0] retryCount,
  output var logic [PI_CODE_WIDTH-1:0] finalClockPhase,
  output var logic [PI_CODE_WIDTH-1:0] validLeftPhase,
  output var logic [PI_CODE_WIDTH-1:0] validRightPhase
);
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
  // A passing run can contain every code, so its length needs one extra bit.
  localparam int unsigned WINDOW_LENGTH_WIDTH = PI_CODE_WIDTH + 1;

  typedef enum logic [3:0] {
    SweepState_IDLE               = 4'd0,
    SweepState_APPLY_SWEEP_PHASE  = 4'd1,
    SweepState_START_SWEEP_TEST   = 4'd2,
    SweepState_WAIT_SWEEP_TEST    = 4'd3,
    SweepState_STORE_SWEEP_RESULT = 4'd4,
    SweepState_CALCULATE_CENTER   = 4'd5,
    SweepState_APPLY_FINAL_PHASE  = 4'd6,
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
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] validLeftPhaseReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] validRightPhaseReg;

  // Accumulate the longest interval as samples arrive. The old bitmap scan
  // unrolled PHASE_COUNT dependent add/compare/mux steps into one clock path.
  // These registers limit each sample update to one narrow increment/compare.
  logic [WINDOW_LENGTH_WIDTH-1:0] runLengthReg, bestLengthReg;
  logic [PI_CODE_WIDTH-1:0] runStartReg, bestStartReg;
  wire [WINDOW_LENGTH_WIDTH-1:0] extendedRunLength = runLengthReg + 1'b1;

  logic validWindowFoundCalc;
  logic [PI_CODE_WIDTH-1:0] validLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] validRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] validCenterPhaseCalc;

  // Strictly-longer updates below retain the first (lowest-code) equal run.
  // Subtract before narrowing so the full-range passing window is preserved.
  always_comb begin
    validWindowFoundCalc =
      (bestLengthReg >= WINDOW_LENGTH_WIDTH'(MIN_VALID_WINDOW_STEPS));
    if (bestLengthReg == 0) begin
      validLeftPhaseCalc = '0;
      validRightPhaseCalc = '0;
      validCenterPhaseCalc = '0;
    end else begin
      validLeftPhaseCalc = bestStartReg;
      validRightPhaseCalc = bestStartReg + PI_CODE_WIDTH'(bestLengthReg - 1'b1);
      validCenterPhaseCalc =
        bestStartReg + PI_CODE_WIDTH'((bestLengthReg - 1'b1) >> 1);
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
    validLeftPhase = validLeftPhaseReg;
    validRightPhase = validRightPhaseReg;

    tx_clock_phase_code = phaseIndexReg;
    apply_tx_clock_phase =
      (stateReg == SweepState_APPLY_SWEEP_PHASE) ||
      (stateReg == SweepState_APPLY_FINAL_PHASE);

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
      validLeftPhaseReg <= '0;
      validRightPhaseReg <= '0;
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
        validLeftPhaseReg <= '0;
        validRightPhaseReg <= '0;
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
            if (point_test_valid_pass) begin
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
            lastFailedComparisonsReg <=
              point_test_valid_pass ? 16'd0 : 16'd1;

            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
              stateReg <= SweepState_CALCULATE_CENTER;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end
          end

          SweepState_CALCULATE_CENTER: begin
            if (validWindowFoundCalc) begin
              validLeftPhaseReg <= validLeftPhaseCalc;
              validRightPhaseReg <= validRightPhaseCalc;
              finalClockPhaseReg <= validCenterPhaseCalc;
              phaseIndexReg <= validCenterPhaseCalc;
              stateReg <= SweepState_APPLY_FINAL_PHASE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              lastFailedComparisonsReg <= 16'd1;
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
              runLengthReg <= '0;
              bestLengthReg <= '0;
              runStartReg <= '0;
              bestStartReg <= '0;
              finalClockPhaseReg <= '0;
              validLeftPhaseReg <= '0;
              validRightPhaseReg <= '0;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end else begin
              lastFailedComparisonsReg <= 16'd1;
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_FINAL_PHASE: begin
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
            lastFailedComparisonsReg <=
              point_test_valid_pass ? 16'd0 : 16'd1;

            if (point_test_valid_pass) begin
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
              validLeftPhaseReg <= '0;
              validRightPhaseReg <= '0;
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
    if ((MIN_VALID_WINDOW_STEPS < 1) ||
        (MIN_VALID_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_VALID_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire
