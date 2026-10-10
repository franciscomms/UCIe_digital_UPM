// UCIe MBTRAIN.DATAVREF.
//
// This mandatory low-rate state optimizes every active local Data receiver Vref
// using receiver-initiated D2C point tests.  The containing LTSM is responsible
// for running the state at 4 GT/s and with the forwarded clock at the best-known
// center.
`default_nettype none

module MBTrainDataVrefFSM #(
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
    LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES
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

  output      logic flagToAnalog_dataVrefApplyRxVref,
  output      logic [dataLaneCount*dataVrefCodeWidth-1:0]
                     flagToAnalog_dataVrefRxVrefCodes,
  input  wire logic flagFromAnalog_dataVrefRxVrefApplied,
  output      logic flagToAnalog_dataVrefConfigureRxInitD2CPointTest,
  output      logic [15:0]
                     flagToAnalog_dataVrefMaximumComparisonErrorThreshold,
  output      logic flagToAnalog_dataVrefComparisonMode,
  output      logic [15:0] flagToAnalog_dataVrefIterationCountSettings,
  output      logic [15:0] flagToAnalog_dataVrefIdleCountSettings,
  output      logic [15:0] flagToAnalog_dataVrefBurstCountSettings,
  output      logic flagToAnalog_dataVrefPatternMode,
  output      logic [3:0] flagToAnalog_dataVrefClockPhaseControl,
  output      logic [2:0] flagToAnalog_dataVrefValidPattern,
  output      logic [2:0] flagToAnalog_dataVrefDataPattern,
  output      logic flagToAnalog_dataVrefClearComparisonErrors,
  input  wire logic [dataLaneCount-1:0]
                     flagFromAnalog_dataVrefDetectedDataPattern,

  output      logic flagToAnalog_dataVrefSendPattern,
  input  wire logic flagFromAnalog_dataVrefFinishedPattern,
  output      logic flagToAnalog_dataVrefResetLocalTxScrambler,

  output      logic [11:0] substate,
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

  // Retain the original configuration parameters in the wrapper interface even
  // though packet identity is supplied by SidebandMsgGenerator_pkg.
  logic unusedConfiguration;
  assign unusedConfiguration = sbFeatureExtension ^ ucieA ^ moduleID[0] ^
                               clkPhase ^ clkMode ^ voltageSwing[0] ^
                               maxLinkSpeed[0] ^ (VREF_RANGE_MILLIVOLTS == 0);

  MBTrain_DataVrefStateCore #(
    .IS_DATATRAIN_VREF(1'b0),
    .PERFORM_LOCAL_TRAINING(1'b1),
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
    .flagToAnalog_applyRxVref(flagToAnalog_dataVrefApplyRxVref),
    .flagToAnalog_rxVrefCodes(flagToAnalog_dataVrefRxVrefCodes),
    .flagFromAnalog_rxVrefApplied(flagFromAnalog_dataVrefRxVrefApplied),
    .flagToAnalog_configureRxInitD2CPointTest(
      flagToAnalog_dataVrefConfigureRxInitD2CPointTest
    ),
    .flagToAnalog_maximumComparisonErrorThreshold(
      flagToAnalog_dataVrefMaximumComparisonErrorThreshold
    ),
    .flagToAnalog_comparisonMode(flagToAnalog_dataVrefComparisonMode),
    .flagToAnalog_iterationCountSettings(
      flagToAnalog_dataVrefIterationCountSettings
    ),
    .flagToAnalog_idleCountSettings(flagToAnalog_dataVrefIdleCountSettings),
    .flagToAnalog_burstCountSettings(flagToAnalog_dataVrefBurstCountSettings),
    .flagToAnalog_patternMode(flagToAnalog_dataVrefPatternMode),
    .flagToAnalog_clockPhaseControl(flagToAnalog_dataVrefClockPhaseControl),
    .flagToAnalog_validPattern(flagToAnalog_dataVrefValidPattern),
    .flagToAnalog_dataPattern(flagToAnalog_dataVrefDataPattern),
    .flagToAnalog_clearComparisonErrors(
      flagToAnalog_dataVrefClearComparisonErrors
    ),
    .flagFromAnalog_detectedDataPattern(
      flagFromAnalog_dataVrefDetectedDataPattern
    ),
    .flagToAnalog_sendLfsrPattern(flagToAnalog_dataVrefSendPattern),
    .flagFromAnalog_lfsrPatternSent(flagFromAnalog_dataVrefFinishedPattern),
    .flagToAnalog_resetLocalTxScrambler(
      flagToAnalog_dataVrefResetLocalTxScrambler
    ),
    .substate(substate),
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
