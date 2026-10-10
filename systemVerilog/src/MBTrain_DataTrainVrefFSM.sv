// UCIe MBTRAIN.DATATRAINVREF.
//
// This state optionally repeats Data receiver Vref optimization at the agreed
// operating rate.  Even when local optimization is disabled, the state still
// performs the outer Start/End handshake and serves the partner die's
// receiver-initiated point tests.
`default_nettype none

module MBTrainDataTrainVrefFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned dataLaneCount = 16,
  parameter logic [dataLaneCount-1:0] activeDataLaneMask =
    {dataLaneCount{1'b1}},
  parameter int unsigned dataVrefValueCount =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  parameter int unsigned dataVrefCodeWidth =
    (dataVrefValueCount <= 1) ? 1 : $clog2(dataVrefValueCount),
  parameter int unsigned dataVrefMinimumMillivolts =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS,
  parameter int unsigned dataVrefMaximumMillivolts =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS,
  parameter logic [15:0] dataVrefMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned dataVrefMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned dataVrefMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES,
  parameter bit performVrefTraining = 1'b1
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,
  output      logic busy,
  output      logic done,
  output      logic trainError,

  input  wire logic sb_tx_ready,
  output      logic sb_tx_valid,
  output      logic [127:0] sb_tx_din,
  input  wire logic sb_rx_valid,
  input  wire logic [127:0] sb_rx_dout,

  output      logic flagToAnalog_dataTrainVrefApplyRxVref,
  output      logic [dataLaneCount*dataVrefCodeWidth-1:0]
                     flagToAnalog_dataTrainVrefRxVrefCodes,
  input  wire logic flagFromAnalog_dataTrainVrefRxVrefApplied,
  output      logic flagToAnalog_dataTrainVrefConfigureRxInitD2CPointTest,
  output      logic [15:0]
                     flagToAnalog_dataTrainVrefMaximumComparisonErrorThreshold,
  output      logic flagToAnalog_dataTrainVrefComparisonMode,
  output      logic [15:0] flagToAnalog_dataTrainVrefIterationCountSettings,
  output      logic [15:0] flagToAnalog_dataTrainVrefIdleCountSettings,
  output      logic [15:0] flagToAnalog_dataTrainVrefBurstCountSettings,
  output      logic flagToAnalog_dataTrainVrefPatternMode,
  output      logic [3:0] flagToAnalog_dataTrainVrefClockPhaseControl,
  output      logic [2:0] flagToAnalog_dataTrainVrefValidPattern,
  output      logic [2:0] flagToAnalog_dataTrainVrefDataPattern,
  output      logic flagToAnalog_dataTrainVrefClearComparisonErrors,
  input  wire logic [dataLaneCount-1:0]
                     flagFromAnalog_dataTrainVrefDetectedDataPattern,

  output      logic flagToAnalog_dataTrainVrefSendPattern,
  input  wire logic flagFromAnalog_dataTrainVrefFinishedPattern,
  output      logic flagToAnalog_dataTrainVrefResetLocalTxScrambler,

  output      logic [3:0]  dbg_localState,
  output      logic [2:0]  dbg_remoteState,
  output      logic [3:0]  dbg_sweepState,
  output      logic [3:0]  dbg_pointInitiatorState,
  output      logic [3:0]  dbg_pointResponderState,
  output      logic [15:0] lastErrorCount,
  output      logic [15:0] retryCount,
  output      logic [dataLaneCount*dataVrefCodeWidth-1:0]
                     selectedVrefCodes,
  output      logic [dataLaneCount*dataVrefCodeWidth-1:0]
                     validWindowLeftCodes,
  output      logic [dataLaneCount*dataVrefCodeWidth-1:0]
                     validWindowRightCodes
);
  localparam int unsigned VREF_RANGE_MILLIVOLTS =
    dataVrefMaximumMillivolts - dataVrefMinimumMillivolts;

  logic unusedConfiguration;
  assign unusedConfiguration = sbFeatureExtension ^ ucieA ^ moduleID[0] ^
                               clkPhase ^ clkMode ^ voltageSwing[0] ^
                               maxLinkSpeed[0] ^ (VREF_RANGE_MILLIVOLTS == 0);

  MBTrain_DataVrefStateCore #(
    .IS_DATATRAIN_VREF(1'b1),
    .PERFORM_LOCAL_TRAINING(performVrefTraining),
    .DATA_LANE_COUNT(dataLaneCount),
    .ACTIVE_DATA_LANE_MASK(activeDataLaneMask),
    .VREF_VALUE_COUNT(dataVrefValueCount),
    .VREF_CODE_WIDTH(dataVrefCodeWidth),
    .MAXIMUM_COMPARISON_ERROR_THRESHOLD(
      dataVrefMaximumComparisonErrorThreshold
    ),
    .MIN_PASSING_WINDOW_VALUES(dataVrefMinPassingWindowValues),
    .MAX_TRAINING_RETRIES(dataVrefMaxTrainingRetries)
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
    .flagToAnalog_applyRxVref(flagToAnalog_dataTrainVrefApplyRxVref),
    .flagToAnalog_rxVrefCodes(flagToAnalog_dataTrainVrefRxVrefCodes),
    .flagFromAnalog_rxVrefApplied(flagFromAnalog_dataTrainVrefRxVrefApplied),
    .flagToAnalog_configureRxInitD2CPointTest(
      flagToAnalog_dataTrainVrefConfigureRxInitD2CPointTest
    ),
    .flagToAnalog_maximumComparisonErrorThreshold(
      flagToAnalog_dataTrainVrefMaximumComparisonErrorThreshold
    ),
    .flagToAnalog_comparisonMode(flagToAnalog_dataTrainVrefComparisonMode),
    .flagToAnalog_iterationCountSettings(
      flagToAnalog_dataTrainVrefIterationCountSettings
    ),
    .flagToAnalog_idleCountSettings(
      flagToAnalog_dataTrainVrefIdleCountSettings
    ),
    .flagToAnalog_burstCountSettings(
      flagToAnalog_dataTrainVrefBurstCountSettings
    ),
    .flagToAnalog_patternMode(flagToAnalog_dataTrainVrefPatternMode),
    .flagToAnalog_clockPhaseControl(
      flagToAnalog_dataTrainVrefClockPhaseControl
    ),
    .flagToAnalog_validPattern(flagToAnalog_dataTrainVrefValidPattern),
    .flagToAnalog_dataPattern(flagToAnalog_dataTrainVrefDataPattern),
    .flagToAnalog_clearComparisonErrors(
      flagToAnalog_dataTrainVrefClearComparisonErrors
    ),
    .flagFromAnalog_detectedDataPattern(
      flagFromAnalog_dataTrainVrefDetectedDataPattern
    ),
    .flagToAnalog_sendLfsrPattern(flagToAnalog_dataTrainVrefSendPattern),
    .flagFromAnalog_lfsrPatternSent(
      flagFromAnalog_dataTrainVrefFinishedPattern
    ),
    .flagToAnalog_resetLocalTxScrambler(
      flagToAnalog_dataTrainVrefResetLocalTxScrambler
    ),
    .dbg_localState(dbg_localState),
    .dbg_remoteState(dbg_remoteState),
    .dbg_sweepState(dbg_sweepState),
    .dbg_pointInitiatorState(dbg_pointInitiatorState),
    .dbg_pointResponderState(dbg_pointResponderState),
    .lastErrorCount(lastErrorCount),
    .retryCount(retryCount),
    .selectedVrefCodes(selectedVrefCodes),
    .validWindowLeftCodes(validWindowLeftCodes),
    .validWindowRightCodes(validWindowRightCodes)
  );

`ifndef SYNTHESIS
  initial begin
    if (dataVrefMaximumMillivolts <= dataVrefMinimumMillivolts)
      $error("Data Vref maximum voltage must be above the minimum voltage");
  end
`endif
endmodule

`default_nettype wire
