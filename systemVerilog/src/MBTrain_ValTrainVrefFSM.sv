// UCIe MBTRAIN.VALTRAINVREF.
//
// This optional state repeats Valid receiver Vref optimization at the
// negotiated operating data rate.  Its point-test and sweep behavior is shared
// with VALVREF; only the outer sideband messages and placement in MBTRAIN differ.
`default_nettype none

module MBTrainValTrainVrefFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned validVrefValueCount =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  parameter int unsigned validVrefCodeWidth =
    (validVrefValueCount <= 1) ? 1 : $clog2(validVrefValueCount),
  parameter int unsigned validVrefMinimumMillivolts =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS,
  parameter int unsigned validVrefMaximumMillivolts =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS,
  parameter logic [15:0] validVrefMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned validVrefMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned validVrefMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES,
  parameter bit performVrefTraining =
    LtsmParameters_pkg::DEFAULT_VALTRAIN_VREF_ENABLE
) (
  input  wire logic                         clock,
  input  wire logic                         reset_n,
  input  wire logic                         start,
  output      logic                         busy,
  output      logic                         done,
  output      logic                         trainError,
  input  wire logic                         sb_tx_ready,
  output      logic                         sb_tx_valid,
  output      logic [127:0]                 sb_tx_din,
  input  wire logic                         sb_rx_valid,
  input  wire logic [127:0]                 sb_rx_dout,

  output      logic                         flagToAnalog_valTrainVrefApplyRxVref,
  output      logic [validVrefCodeWidth-1:0] flagToAnalog_valTrainVrefRxVrefCode,
  input  wire logic                         flagFromAnalog_valTrainVrefRxVrefApplied,
  output      logic                         flagToAnalog_valTrainVrefConfigureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_valTrainVrefMaximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_valTrainVrefComparisonMode,
  output      logic [15:0]                  flagToAnalog_valTrainVrefIterationCountSettings,
  output      logic [15:0]                  flagToAnalog_valTrainVrefIdleCountSettings,
  output      logic [15:0]                  flagToAnalog_valTrainVrefBurstCountSettings,
  output      logic                         flagToAnalog_valTrainVrefPatternMode,
  output      logic [3:0]                   flagToAnalog_valTrainVrefClockPhaseControl,
  output      logic [2:0]                   flagToAnalog_valTrainVrefValidPattern,
  output      logic [2:0]                   flagToAnalog_valTrainVrefDataPattern,
  output      logic                         flagToAnalog_valTrainVrefClearComparisonErrors,
  input  wire logic                         flagFromAnalog_valTrainVrefDetectedValPattern,

  output      logic                         flagToAnalog_valTrainVrefSendPattern,
  input  wire logic                         flagFromAnalog_valTrainVrefFinishedPattern,
  output      logic                         flagToAnalog_valTrainVrefResetLocalTxScrambler,

  output      logic [3:0]                   dbg_localState,
  output      logic [2:0]                   dbg_remoteState,
  output      logic [3:0]                   dbg_sweepState,
  output      logic [3:0]                   dbg_pointInitiatorState,
  output      logic [3:0]                   dbg_pointResponderState,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [validVrefCodeWidth-1:0] selectedVrefCode,
  output      logic [validVrefCodeWidth-1:0] validWindowLeftCode,
  output      logic [validVrefCodeWidth-1:0] validWindowRightCode
);
  localparam int unsigned VREF_RANGE_MILLIVOLTS =
    validVrefMaximumMillivolts - validVrefMinimumMillivolts;
  logic unusedVrefRange;
  assign unusedVrefRange = (VREF_RANGE_MILLIVOLTS == 0);

  MBTrain_ValidVrefStateCore #(
    .IS_VALTRAIN_VREF(1'b1),
    .PERFORM_LOCAL_TRAINING(performVrefTraining),
    .VREF_VALUE_COUNT(validVrefValueCount),
    .VREF_CODE_WIDTH(validVrefCodeWidth),
    .MAXIMUM_COMPARISON_ERROR_THRESHOLD(validVrefMaximumComparisonErrorThreshold),
    .MIN_PASSING_WINDOW_VALUES(validVrefMinPassingWindowValues),
    .MAX_TRAINING_RETRIES(validVrefMaxTrainingRetries)
  ) core (
    .clock(clock),
    .reset_n(reset_n),
    .start(start),
    .busy(busy),
    .done(done),
    .trainError(trainError),
    .sb_tx_ready(sb_tx_ready),
    .sb_tx_valid(sb_tx_valid),
    .sb_tx_din(sb_tx_din),
    .sb_rx_valid(sb_rx_valid),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_applyRxVref(flagToAnalog_valTrainVrefApplyRxVref),
    .flagToAnalog_rxVrefCode(flagToAnalog_valTrainVrefRxVrefCode),
    .flagFromAnalog_rxVrefApplied(flagFromAnalog_valTrainVrefRxVrefApplied),
    .flagToAnalog_configureRxInitD2CPointTest(flagToAnalog_valTrainVrefConfigureRxInitD2CPointTest),
    .flagToAnalog_maximumComparisonErrorThreshold(flagToAnalog_valTrainVrefMaximumComparisonErrorThreshold),
    .flagToAnalog_comparisonMode(flagToAnalog_valTrainVrefComparisonMode),
    .flagToAnalog_iterationCountSettings(flagToAnalog_valTrainVrefIterationCountSettings),
    .flagToAnalog_idleCountSettings(flagToAnalog_valTrainVrefIdleCountSettings),
    .flagToAnalog_burstCountSettings(flagToAnalog_valTrainVrefBurstCountSettings),
    .flagToAnalog_patternMode(flagToAnalog_valTrainVrefPatternMode),
    .flagToAnalog_clockPhaseControl(flagToAnalog_valTrainVrefClockPhaseControl),
    .flagToAnalog_validPattern(flagToAnalog_valTrainVrefValidPattern),
    .flagToAnalog_dataPattern(flagToAnalog_valTrainVrefDataPattern),
    .flagToAnalog_clearComparisonErrors(flagToAnalog_valTrainVrefClearComparisonErrors),
    .flagFromAnalog_detectedValPattern(flagFromAnalog_valTrainVrefDetectedValPattern),
    .flagToAnalog_sendValTrainPattern(flagToAnalog_valTrainVrefSendPattern),
    .flagFromAnalog_valTrainPatternSent(flagFromAnalog_valTrainVrefFinishedPattern),
    .flagToAnalog_resetLocalTxScrambler(flagToAnalog_valTrainVrefResetLocalTxScrambler),
    .dbg_localState(dbg_localState),
    .dbg_remoteState(dbg_remoteState),
    .dbg_sweepState(dbg_sweepState),
    .dbg_pointInitiatorState(dbg_pointInitiatorState),
    .dbg_pointResponderState(dbg_pointResponderState),
    .lastErrorCount(lastErrorCount),
    .retryCount(retryCount),
    .selectedVrefCode(selectedVrefCode),
    .validWindowLeftCode(validWindowLeftCode),
    .validWindowRightCode(validWindowRightCode)
  );

`ifndef SYNTHESIS
  initial begin
    if (validVrefMaximumMillivolts <= validVrefMinimumMillivolts)
      $error("Valid Vref maximum voltage must be above the minimum voltage");
  end
`endif
endmodule

`default_nettype wire
