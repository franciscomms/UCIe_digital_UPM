// UCIe MBTRAIN.VALVREF.
//
// This mandatory low-rate state optimizes the local Valid receiver Vref using
// repeated receiver-initiated D2C point tests.  The containing LTSM is
// responsible for entering this state while the mainband is at 4 GT/s.
`default_nettype none

module MBTrainValVrefFSM #(
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
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES
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

  output      logic                         flagToAnalog_valRefApplyRxVref,
  output      logic [validVrefCodeWidth-1:0] flagToAnalog_valRefRxVrefCode,
  input  wire logic                         flagFromAnalog_valRefRxVrefApplied,
  output      logic                         flagToAnalog_valRefConfigureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_valRefMaximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_valRefComparisonMode,
  output      logic [15:0]                  flagToAnalog_valRefIterationCountSettings,
  output      logic [15:0]                  flagToAnalog_valRefIdleCountSettings,
  output      logic [15:0]                  flagToAnalog_valRefBurstCountSettings,
  output      logic                         flagToAnalog_valRefPatternMode,
  output      logic [3:0]                   flagToAnalog_valRefClockPhaseControl,
  output      logic [2:0]                   flagToAnalog_valRefValidPattern,
  output      logic [2:0]                   flagToAnalog_valRefDataPattern,
  output      logic                         flagToAnalog_valRefClearComparisonErrors,
  input  wire logic                         flagFromAnalog_valRefDetectedValPattern,

  output      logic                         flagToAnalog_valRefSendPattern,
  input  wire logic                         flagFromAnalog_valRefFinishedPattern,
  output      logic                         flagToAnalog_valRefResetLocalTxScrambler,

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
  // These parameters document the external DAC mapping.  No real-valued
  // arithmetic is required in synthesizable training control.
  localparam int unsigned VREF_RANGE_MILLIVOLTS =
    validVrefMaximumMillivolts - validVrefMinimumMillivolts;
  logic unusedVrefRange;
  assign unusedVrefRange = (VREF_RANGE_MILLIVOLTS == 0);

  MBTrain_ValidVrefStateCore #(
    .IS_VALTRAIN_VREF(1'b0),
    .PERFORM_LOCAL_TRAINING(1'b1),
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
    .flagToAnalog_applyRxVref(flagToAnalog_valRefApplyRxVref),
    .flagToAnalog_rxVrefCode(flagToAnalog_valRefRxVrefCode),
    .flagFromAnalog_rxVrefApplied(flagFromAnalog_valRefRxVrefApplied),
    .flagToAnalog_configureRxInitD2CPointTest(flagToAnalog_valRefConfigureRxInitD2CPointTest),
    .flagToAnalog_maximumComparisonErrorThreshold(flagToAnalog_valRefMaximumComparisonErrorThreshold),
    .flagToAnalog_comparisonMode(flagToAnalog_valRefComparisonMode),
    .flagToAnalog_iterationCountSettings(flagToAnalog_valRefIterationCountSettings),
    .flagToAnalog_idleCountSettings(flagToAnalog_valRefIdleCountSettings),
    .flagToAnalog_burstCountSettings(flagToAnalog_valRefBurstCountSettings),
    .flagToAnalog_patternMode(flagToAnalog_valRefPatternMode),
    .flagToAnalog_clockPhaseControl(flagToAnalog_valRefClockPhaseControl),
    .flagToAnalog_validPattern(flagToAnalog_valRefValidPattern),
    .flagToAnalog_dataPattern(flagToAnalog_valRefDataPattern),
    .flagToAnalog_clearComparisonErrors(flagToAnalog_valRefClearComparisonErrors),
    .flagFromAnalog_detectedValPattern(flagFromAnalog_valRefDetectedValPattern),
    .flagToAnalog_sendValTrainPattern(flagToAnalog_valRefSendPattern),
    .flagFromAnalog_valTrainPatternSent(flagFromAnalog_valRefFinishedPattern),
    .flagToAnalog_resetLocalTxScrambler(flagToAnalog_valRefResetLocalTxScrambler),
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
