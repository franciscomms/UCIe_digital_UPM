// SystemVerilog translation of LinkTrainingFSM.scala.
// Every state element uses an asynchronous, active-low reset_n.
`default_nettype none

module LinkTrainingFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned d2cTxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned d2cDeskewStepsPerPi = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI,
  parameter bit d2cDeskewAddDelayIncreasesPhase = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE,
  parameter logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned d2cMinLaneWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS,
  parameter int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES,
  parameter int unsigned validVrefValueCount = LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  parameter int unsigned validVrefCodeWidth =
    (validVrefValueCount <= 1) ? 1 : $clog2(validVrefValueCount),
  parameter int unsigned validVrefMinimumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS,
  parameter int unsigned validVrefMaximumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS,
  parameter logic [15:0] validVrefMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned validVrefMinPassingWindowValues = LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned validVrefMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES,
  parameter bit valTrainVrefEnable = LtsmParameters_pkg::DEFAULT_VALTRAIN_VREF_ENABLE,
  parameter int unsigned dataLaneCount = 16,
  parameter logic [dataLaneCount-1:0] activeDataLaneMask = {dataLaneCount{1'b1}},
  parameter int unsigned dataVrefValueCount = LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  parameter int unsigned dataVrefCodeWidth =
    (dataVrefValueCount <= 1) ? 1 : $clog2(dataVrefValueCount),
  parameter int unsigned dataVrefMinimumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS,
  parameter int unsigned dataVrefMaximumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS,
  parameter logic [15:0] dataVrefMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned dataVrefMinPassingWindowValues = LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned dataVrefMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES,
  parameter bit dataTrainVrefEnable = 1'b1,
  parameter bit rxDeskewEnable = LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE,
  parameter int unsigned rxDeskewValueCount = LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
  parameter int unsigned rxDeskewCodeWidth =
    (rxDeskewValueCount <= 1) ? 1 : $clog2(rxDeskewValueCount),
  parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES
) (
  input wire logic clock,
  input wire logic reset_n,
  output var logic [127:0]   sb_tx_din,
  output var logic           sb_tx_valid,
  input wire logic           sb_tx_ready,
  input wire logic [127:0]   sb_rx_dout,
  input wire logic           sb_rx_valid,
  input wire logic           start,
  input wire logic           stable_clk,
  input wire logic           pll_locked,
  input wire logic           stable_supply,
  input wire logic           flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic           flagFromAnalog_FinishedClkPatterns,
  input wire logic           flagFromAnalog_FinishedValTrainPattern,
  input wire logic           flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  input wire logic           flagFromAnalog_RepairMbFinishedLaneIDPattern,
  input wire logic           flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic           flagFromAnalog_ValTrainPatternReceived,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived0,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived1,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived2,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived3,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived4,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived5,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived6,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived7,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived8,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived9,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived10,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived11,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived12,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived13,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived14,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived15,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern0,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern1,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern2,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern3,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern4,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern5,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern6,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern7,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern8,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern9,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern10,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern11,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern12,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern13,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern14,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern15,
  output var logic           flagToAnalog_RepairClkState,
  output var logic           flagToAnalog_SendClkPatterns,
  output var logic           flagToAnalog_RepairValState,
  output var logic           flagToAnalog_SendValTrainPattern,
  output var logic           flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic           flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic           flagToAnalog_RepairMbSetReceiver,
  output var logic           flagToAnalog_LaneReversalApplied,
  output var logic           flagToAnalog_linkInit_resetLfsrScrambler,
  output var logic [3:0]     state,
  output var logic           dbg_flagSbinitFirstClkPatternSeen,
  output var logic           dbg_rxValidRisingEdge,
  output var logic [2:0]     dbg_sbinitSendCount,
  output var logic           dbg_sbTxValid,
  output var logic [127:0]   dbg_sbTxDin,
  output var logic           dbg_flagTrainError,
  output var logic [2:0]     dbg_mbinitSubstate,
  output var logic [4:0]     dbg_mbinitReversalMbReceivedSuccessCount,
  output var logic           flagToAnalog_valVref_sendPattern,
  input wire logic           flagFromAnalog_valVref_detectedValPattern,
  input wire logic           flagFromAnalog_valVref_finishedPattern,
  output var logic           flagToAnalog_valVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] flagToAnalog_valVref_rxVrefCode,
  input wire logic           flagFromAnalog_valVref_rxVrefApplied,
  output var logic           flagToAnalog_valVref_configureRxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_valVref_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_valVref_comparisonMode,
  output var logic [15:0]    flagToAnalog_valVref_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_valVref_idleCountSettings,
  output var logic [15:0]    flagToAnalog_valVref_burstCountSettings,
  output var logic           flagToAnalog_valVref_patternMode,
  output var logic [3:0]     flagToAnalog_valVref_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_valVref_validPattern,
  output var logic [2:0]     flagToAnalog_valVref_dataPattern,
  output var logic           flagToAnalog_valVref_clearComparisonErrors,
  output var logic           flagToAnalog_valVref_resetLocalTxScrambler,
  output var logic           flagToAnalog_dataVref_sendPattern,
  input wire logic [dataLaneCount-1:0] flagFromAnalog_dataVref_detectedDataPattern,
  input wire logic           flagFromAnalog_dataVref_finishedPattern,
  output var logic           flagToAnalog_dataVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] flagToAnalog_dataVref_rxVrefCodes,
  input wire logic           flagFromAnalog_dataVref_rxVrefApplied,
  output var logic           flagToAnalog_dataVref_configureRxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_dataVref_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_dataVref_comparisonMode,
  output var logic [15:0]    flagToAnalog_dataVref_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_dataVref_idleCountSettings,
  output var logic [15:0]    flagToAnalog_dataVref_burstCountSettings,
  output var logic           flagToAnalog_dataVref_patternMode,
  output var logic [3:0]     flagToAnalog_dataVref_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_dataVref_validPattern,
  output var logic [2:0]     flagToAnalog_dataVref_dataPattern,
  output var logic           flagToAnalog_dataVref_clearComparisonErrors,
  output var logic           flagToAnalog_dataVref_resetLocalTxScrambler,
  output var logic           flagToAnalog_rxClkCal_doCalibration,
  input wire logic           flagFromAnalog_rxClkCal_done,
  output var logic           flagToAnalog_rxClkCal_sendClockTrack,
  output var logic           flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern,
  input wire logic           flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent,
  output var logic           flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler,
  output var logic           flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode,
  input wire logic            flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied,
  output var logic           flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode,
  output var logic [15:0]    flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings,
  output var logic           flagToAnalog_d2cReceiver_valTrainCenter_patternMode,
  output var logic [3:0]     flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_d2cReceiver_valTrainCenter_validPattern,
  output var logic [2:0]     flagToAnalog_d2cReceiver_valTrainCenter_dataPattern,
  output var logic           flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload,
  output var logic           flagToAnalog_valTrainVref_sendPattern,
  input wire logic           flagFromAnalog_valTrainVref_detectedValPattern,
  input wire logic           flagFromAnalog_valTrainVref_finishedPattern,
  output var logic           flagToAnalog_valTrainVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] flagToAnalog_valTrainVref_rxVrefCode,
  input wire logic           flagFromAnalog_valTrainVref_rxVrefApplied,
  output var logic           flagToAnalog_valTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_valTrainVref_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_valTrainVref_comparisonMode,
  output var logic [15:0]    flagToAnalog_valTrainVref_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_valTrainVref_idleCountSettings,
  output var logic [15:0]    flagToAnalog_valTrainVref_burstCountSettings,
  output var logic           flagToAnalog_valTrainVref_patternMode,
  output var logic [3:0]     flagToAnalog_valTrainVref_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_valTrainVref_validPattern,
  output var logic [2:0]     flagToAnalog_valTrainVref_dataPattern,
  output var logic           flagToAnalog_valTrainVref_clearComparisonErrors,
  output var logic           flagToAnalog_valTrainVref_resetLocalTxScrambler,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern,
  input wire logic           flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode,
  input wire logic           flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes,
  input wire logic           flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode,
  output var logic [3:0]     flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern,
  output var logic [2:0]     flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload,
  output var logic           flagToAnalog_dataTrainVref_sendPattern,
  input wire logic [dataLaneCount-1:0] flagFromAnalog_dataTrainVref_detectedDataPattern,
  input wire logic           flagFromAnalog_dataTrainVref_finishedPattern,
  output var logic           flagToAnalog_dataTrainVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] flagToAnalog_dataTrainVref_rxVrefCodes,
  input wire logic           flagFromAnalog_dataTrainVref_rxVrefApplied,
  output var logic           flagToAnalog_dataTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_dataTrainVref_comparisonMode,
  output var logic [15:0]    flagToAnalog_dataTrainVref_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_dataTrainVref_idleCountSettings,
  output var logic [15:0]    flagToAnalog_dataTrainVref_burstCountSettings,
  output var logic           flagToAnalog_dataTrainVref_patternMode,
  output var logic [3:0]     flagToAnalog_dataTrainVref_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_dataTrainVref_validPattern,
  output var logic [2:0]     flagToAnalog_dataTrainVref_dataPattern,
  output var logic           flagToAnalog_dataTrainVref_clearComparisonErrors,
  output var logic           flagToAnalog_dataTrainVref_resetLocalTxScrambler,
  output var logic           flagToAnalog_rxDeskew_sendLfsrPattern,
  input wire logic           flagFromAnalog_rxDeskew_lfsrPatternSent,
  output var logic           flagToAnalog_rxDeskew_resetLocalTxScrambler,
  output var logic           flagToAnalog_rxDeskew_applyRxLaneDeskew,
  output var logic [dataLaneCount*rxDeskewCodeWidth-1:0] flagToAnalog_rxDeskew_rxLaneDeskewCodes,
  input wire logic           flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
  output var logic           flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_rxDeskew_comparisonMode,
  output var logic [15:0]    flagToAnalog_rxDeskew_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_rxDeskew_idleCountSettings,
  output var logic [15:0]    flagToAnalog_rxDeskew_burstCountSettings,
  output var logic           flagToAnalog_rxDeskew_patternMode,
  output var logic [3:0]     flagToAnalog_rxDeskew_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_rxDeskew_validPattern,
  output var logic [2:0]     flagToAnalog_rxDeskew_dataPattern,
  output var logic           flagToAnalog_rxDeskew_clearComparisonErrors,
  input wire logic [dataLaneCount-1:0] flagFromAnalog_rxDeskew_detectedDataPattern,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern,
  input wire logic           flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler,
  output var logic           flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode,
  input wire logic            flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode,
  output var logic [3:0]     flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern,
  output var logic [2:0]     flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern,
  output var logic           flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload,
  output var logic           flagToLtsm_linkSpeed_phyInRetrain,
  output var logic           flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern,
  input wire logic           flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent,
  output var logic           flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler,
  output var logic           flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_d2cReceiver_linkSpeed_comparisonMode,
  output var logic [15:0]    flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings,
  output var logic           flagToAnalog_d2cReceiver_linkSpeed_patternMode,
  output var logic [3:0]     flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_d2cReceiver_linkSpeed_validPattern,
  output var logic [2:0]     flagToAnalog_d2cReceiver_linkSpeed_dataPattern,
  output var logic           flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful,
  output var logic [3:0]     dbg_mbtrainState,
  output var logic [11:0]    dbg_mbtrainActiveSubstate,
  output var logic [15:0]    dbg_mbtrainLastErrorCount,
  output var logic [15:0]    dbg_mbtrainRetryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LTState_RESET           = 4'd0,
    LTState_SBINIT_pattern  = 4'd1,
    LTState_SBINIT_sendFour = 4'd2,
    LTState_SBINIT_OORmsg   = 4'd3,
    LTState_SBINIT_DONEmsg  = 4'd4,
    LTState_MBINIT_SUPER    = 4'd5,
    LTState_MBTRAIN         = 4'd6,
    LTState_LINKINIT        = 4'd7,
    LTState_ACTIVE          = 4'd8,
    LTState_TRAIN_ERROR     = 4'd9
  } LTState_t;

  localparam logic [22:0] RESET_CYCLES = 23'd10;

  (* keep = "true" *) LTState_t stateReg;
  (* keep = "true" *) logic [22:0] resetCnt;
  (* keep = "true" *) logic sbinitTxValid;
  (* keep = "true" *) logic [127:0] sbinitTxDin;
  (* keep = "true" *) logic prevRxValid;
  (* keep = "true" *) logic flagSbinitFirstClkPatternSeen;
  (* keep = "true" *) logic flagSbinitSecondClkPatternSeen;
  (* keep = "true" *) logic flagSbinitOorSeen;
  (* keep = "true" *) logic flagSbinitReceivedDoneReq;
  (* keep = "true" *) logic flagSbinitReceivedDoneResp;
  (* keep = "true" *) logic flagSbinitSentDoneReq;
  (* keep = "true" *) logic flagSbinitSentDoneResp;
  (* keep = "true" *) logic [2:0] sbinitSendCount;
  (* keep = "true" *) logic parentTrainError;

  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire mbInitActive = (stateReg == LTState_MBINIT_SUPER);
  wire mbTrainActive = (stateReg == LTState_MBTRAIN);

  wire [127:0] SBINIT_CLK_PATTERN = {64'b0, 64'h5555555555555555};
  wire [127:0] SBINIT_OOR_SUCCESS = msgSbinitOutOfReset(1'b1, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] SBINIT_DONE_REQ = msgSbinitDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] SBINIT_DONE_RESP = msgSbinitDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  logic mbInitFsm_busy;
  logic mbInitFsm_done;
  logic mbInitFsm_trainError;
  logic [127:0] mbInitFsm_sb_tx_din;
  logic mbInitFsm_sb_tx_valid;
  logic mbInitFsm_flagToAnalog_RepairClkState;
  logic mbInitFsm_flagToAnalog_SendClkPatterns;
  logic mbInitFsm_flagToAnalog_RepairValState;
  logic mbInitFsm_flagToAnalog_SendValTrainPattern;
  logic mbInitFsm_flagToAnalog_RepairMbSendLaneIDPattern;
  logic mbInitFsm_flagToAnalog_RepairMbSetReceiver;
  logic mbInitFsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  logic mbInitFsm_flagToAnalog_LaneReversalApplied;
  logic [2:0] mbInitFsm_substate;
  logic [2:0] mbInitFsm_dbg_mbinitRepairClkSenderState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairClkReceiverState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairValSenderState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairValReceiverState;
  logic [4:0] mbInitFsm_dbg_mbinitReversalMbReceivedSuccessCount;
  logic mbTrainFsm_busy;
  logic mbTrainFsm_done;
  logic mbTrainFsm_trainError;
  logic mbTrainFsm_sb_tx_valid;
  logic [127:0] mbTrainFsm_sb_tx_din;
  logic mbTrainFsm_flagToAnalog_valVref_sendPattern;
  logic mbTrainFsm_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] mbTrainFsm_flagToAnalog_valVref_rxVrefCode;
  logic mbTrainFsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_valVref_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_valVref_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_valVref_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_valVref_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_valVref_dataPattern;
  logic mbTrainFsm_flagToAnalog_valVref_clearComparisonErrors;
  logic mbTrainFsm_flagToAnalog_valVref_resetLocalTxScrambler;
  logic mbTrainFsm_flagToAnalog_dataVref_sendPattern;
  logic mbTrainFsm_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] mbTrainFsm_flagToAnalog_dataVref_rxVrefCodes;
  logic mbTrainFsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_dataVref_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_dataVref_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_dataVref_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_dataVref_dataPattern;
  logic mbTrainFsm_flagToAnalog_dataVref_clearComparisonErrors;
  logic mbTrainFsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic mbTrainFsm_flagToAnalog_rxClkCal_doCalibration;
  logic mbTrainFsm_flagToAnalog_rxClkCal_sendClockTrack;
  logic mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
  logic mbTrainFsm_flagToAnalog_valTrainVref_sendPattern;
  logic mbTrainFsm_flagToAnalog_valTrainVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] mbTrainFsm_flagToAnalog_valTrainVref_rxVrefCode;
  logic mbTrainFsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_valTrainVref_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_valTrainVref_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_valTrainVref_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_valTrainVref_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_valTrainVref_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_valTrainVref_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_valTrainVref_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_valTrainVref_dataPattern;
  logic mbTrainFsm_flagToAnalog_valTrainVref_clearComparisonErrors;
  logic mbTrainFsm_flagToAnalog_valTrainVref_resetLocalTxScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_sendPattern;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] mbTrainFsm_flagToAnalog_dataTrainVref_rxVrefCodes;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_dataTrainVref_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_dataTrainVref_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_dataTrainVref_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_dataTrainVref_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_dataTrainVref_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_dataTrainVref_dataPattern;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_clearComparisonErrors;
  logic mbTrainFsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
  logic mbTrainFsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic mbTrainFsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic mbTrainFsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0]
    mbTrainFsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic mbTrainFsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_rxDeskew_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_rxDeskew_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_rxDeskew_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_rxDeskew_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_rxDeskew_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_rxDeskew_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_rxDeskew_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_rxDeskew_dataPattern;
  logic mbTrainFsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
  logic mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  logic [3:0] mbTrainFsm_state;
  logic [11:0] mbTrainFsm_activeSubstate;
  logic [15:0] mbTrainFsm_lastErrorCount;
  logic [15:0] mbTrainFsm_retryCount;

  MBInitFSM #(
    .sbFeatureExtension (sbFeatureExtension),
    .ucieA               (ucieA),
    .moduleID            (moduleID),
    .clkPhase            (clkPhase),
    .clkMode             (clkMode),
    .voltageSwing        (voltageSwing),
    .maxLinkSpeed        (maxLinkSpeed)
  ) mbInitFsm (
    .clock                                                                    (clock),
    .reset_n                                                                  (reset_n),
    .start                                                                    (mbInitActive),
    .busy                                                                     (mbInitFsm_busy),
    .done                                                                     (mbInitFsm_done),
    .trainError                                                               (mbInitFsm_trainError),
    .sb_tx_din                                                                (mbInitFsm_sb_tx_din),
    .sb_tx_valid                                                              (mbInitFsm_sb_tx_valid),
    .sb_tx_ready                                                              (sb_tx_ready && mbInitActive),
    .sb_rx_dout                                                               (sb_rx_dout),
    .sb_rx_valid                                                              (sb_rx_valid && mbInitActive),
    .flagFromAnalog_ReadyToExchangeClkPatterns                                (flagFromAnalog_ReadyToExchangeClkPatterns),
    .flagFromAnalog_FinishedClkPatterns                                       (flagFromAnalog_FinishedClkPatterns),
    .flagFromAnalog_FinishedValTrainPattern                                   (flagFromAnalog_FinishedValTrainPattern),
    .flagFromAnalog_clkPatternReceivedRTRK_L                                  (flagFromAnalog_clkPatternReceivedRTRK_L),
    .flagFromAnalog_clkPatternReceivedRCKN_L                                  (flagFromAnalog_clkPatternReceivedRCKN_L),
    .flagFromAnalog_clkPatternReceivedRCKP_L                                  (flagFromAnalog_clkPatternReceivedRCKP_L),
    .flagFromAnalog_ValTrainPatternReceived                                   (flagFromAnalog_ValTrainPatternReceived),
    .flagFromAnalog_ReversalMbFinishedLaneIDPattern                           (flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .flagFromAnalog_ReversalMbTrainPatternReceived0                           (flagFromAnalog_ReversalMbTrainPatternReceived0),
    .flagFromAnalog_ReversalMbTrainPatternReceived1                           (flagFromAnalog_ReversalMbTrainPatternReceived1),
    .flagFromAnalog_ReversalMbTrainPatternReceived2                           (flagFromAnalog_ReversalMbTrainPatternReceived2),
    .flagFromAnalog_ReversalMbTrainPatternReceived3                           (flagFromAnalog_ReversalMbTrainPatternReceived3),
    .flagFromAnalog_ReversalMbTrainPatternReceived4                           (flagFromAnalog_ReversalMbTrainPatternReceived4),
    .flagFromAnalog_ReversalMbTrainPatternReceived5                           (flagFromAnalog_ReversalMbTrainPatternReceived5),
    .flagFromAnalog_ReversalMbTrainPatternReceived6                           (flagFromAnalog_ReversalMbTrainPatternReceived6),
    .flagFromAnalog_ReversalMbTrainPatternReceived7                           (flagFromAnalog_ReversalMbTrainPatternReceived7),
    .flagFromAnalog_ReversalMbTrainPatternReceived8                           (flagFromAnalog_ReversalMbTrainPatternReceived8),
    .flagFromAnalog_ReversalMbTrainPatternReceived9                           (flagFromAnalog_ReversalMbTrainPatternReceived9),
    .flagFromAnalog_ReversalMbTrainPatternReceived10                          (flagFromAnalog_ReversalMbTrainPatternReceived10),
    .flagFromAnalog_ReversalMbTrainPatternReceived11                          (flagFromAnalog_ReversalMbTrainPatternReceived11),
    .flagFromAnalog_ReversalMbTrainPatternReceived12                          (flagFromAnalog_ReversalMbTrainPatternReceived12),
    .flagFromAnalog_ReversalMbTrainPatternReceived13                          (flagFromAnalog_ReversalMbTrainPatternReceived13),
    .flagFromAnalog_ReversalMbTrainPatternReceived14                          (flagFromAnalog_ReversalMbTrainPatternReceived14),
    .flagFromAnalog_ReversalMbTrainPatternReceived15                          (flagFromAnalog_ReversalMbTrainPatternReceived15),
    .flagFromAnalog_RepairMbFinishedLaneIDPattern                             (flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern0                            (flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern1                            (flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern2                            (flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern3                            (flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern4                            (flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern5                            (flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern6                            (flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern7                            (flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern8                            (flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern9                            (flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern10                           (flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern11                           (flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern12                           (flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern13                           (flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern14                           (flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern15                           (flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .flagToAnalog_RepairClkState                                              (mbInitFsm_flagToAnalog_RepairClkState),
    .flagToAnalog_SendClkPatterns                                             (mbInitFsm_flagToAnalog_SendClkPatterns),
    .flagToAnalog_RepairValState                                              (mbInitFsm_flagToAnalog_RepairValState),
    .flagToAnalog_SendValTrainPattern                                         (mbInitFsm_flagToAnalog_SendValTrainPattern),
    .flagToAnalog_RepairMbSendLaneIDPattern                                   (mbInitFsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .flagToAnalog_RepairMbSetReceiver                                         (mbInitFsm_flagToAnalog_RepairMbSetReceiver),
    .flagToAnalog_ReversalMbSendLaneIDPattern                                 (mbInitFsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .flagToAnalog_LaneReversalApplied                                         (mbInitFsm_flagToAnalog_LaneReversalApplied),
    .substate                                                                 (mbInitFsm_substate),
    .dbg_mbinitRepairClkSenderState                                           (mbInitFsm_dbg_mbinitRepairClkSenderState),
    .dbg_mbinitRepairClkReceiverState                                         (mbInitFsm_dbg_mbinitRepairClkReceiverState),
    .dbg_mbinitRepairValSenderState                                           (mbInitFsm_dbg_mbinitRepairValSenderState),
    .dbg_mbinitRepairValReceiverState                                         (mbInitFsm_dbg_mbinitRepairValReceiverState),
    .dbg_mbinitReversalMbReceivedSuccessCount                                 (mbInitFsm_dbg_mbinitReversalMbReceivedSuccessCount)
  );

  MBTrainFSM #(
    .sbFeatureExtension (sbFeatureExtension),
    .ucieA               (ucieA),
    .moduleID            (moduleID),
    .clkPhase            (clkPhase),
    .clkMode             (clkMode),
    .voltageSwing        (voltageSwing),
    .maxLinkSpeed        (maxLinkSpeed),
    .d2cPiCodeWidth      (d2cPiCodeWidth),
    .d2cTxDeskewCodeWidth(d2cTxDeskewCodeWidth),
    .d2cDeskewStepsPerPi (d2cDeskewStepsPerPi),
    .d2cDeskewAddDelayIncreasesPhase(d2cDeskewAddDelayIncreasesPhase),
    .d2cMaximumComparisonErrorThreshold(d2cMaximumComparisonErrorThreshold),
    .d2cMinLaneWindowSteps(d2cMinLaneWindowSteps),
    .d2cMinCommonWindowSteps(d2cMinCommonWindowSteps),
    .d2cMaxTrainingRetries(d2cMaxTrainingRetries),
    .validVrefValueCount(validVrefValueCount),
    .validVrefCodeWidth(validVrefCodeWidth),
    .validVrefMinimumMillivolts(validVrefMinimumMillivolts),
    .validVrefMaximumMillivolts(validVrefMaximumMillivolts),
    .validVrefMaximumComparisonErrorThreshold(validVrefMaximumComparisonErrorThreshold),
    .validVrefMinPassingWindowValues(validVrefMinPassingWindowValues),
    .validVrefMaxTrainingRetries(validVrefMaxTrainingRetries),
    .valTrainVrefEnable(valTrainVrefEnable),
    .dataLaneCount(dataLaneCount),
    .activeDataLaneMask(activeDataLaneMask),
    .dataVrefValueCount(dataVrefValueCount),
    .dataVrefCodeWidth(dataVrefCodeWidth),
    .dataVrefMinimumMillivolts(dataVrefMinimumMillivolts),
    .dataVrefMaximumMillivolts(dataVrefMaximumMillivolts),
    .dataVrefMaximumComparisonErrorThreshold(dataVrefMaximumComparisonErrorThreshold),
    .dataVrefMinPassingWindowValues(dataVrefMinPassingWindowValues),
    .dataVrefMaxTrainingRetries(dataVrefMaxTrainingRetries),
    .dataTrainVrefEnable(dataTrainVrefEnable),
    .rxDeskewEnable(rxDeskewEnable),
    .rxDeskewValueCount(rxDeskewValueCount),
    .rxDeskewCodeWidth(rxDeskewCodeWidth),
    .rxDeskewMaximumComparisonErrorThreshold(
      rxDeskewMaximumComparisonErrorThreshold),
    .rxDeskewMinPassingWindowValues(rxDeskewMinPassingWindowValues),
    .rxDeskewMaxTrainingRetries(rxDeskewMaxTrainingRetries)
  ) mbTrainFsm (
    .clock                                                                    (clock),
    .reset_n                                                                  (reset_n),
    .start                                                                    (mbTrainActive),
    .busy                                                                     (mbTrainFsm_busy),
    .done                                                                     (mbTrainFsm_done),
    .trainError                                                               (mbTrainFsm_trainError),
    .sb_tx_ready                                                              (sb_tx_ready && mbTrainActive),
    .sb_tx_valid                                                              (mbTrainFsm_sb_tx_valid),
    .sb_tx_din                                                                (mbTrainFsm_sb_tx_din),
    .sb_rx_valid                                                              (sb_rx_valid && mbTrainActive),
    .sb_rx_dout                                                               (sb_rx_dout),
    .flagToAnalog_valVref_sendPattern                                         (mbTrainFsm_flagToAnalog_valVref_sendPattern),
    .flagFromAnalog_valVref_detectedValPattern                                (flagFromAnalog_valVref_detectedValPattern),
    .flagFromAnalog_valVref_finishedPattern                                   (flagFromAnalog_valVref_finishedPattern),
    .flagToAnalog_valVref_applyRxVref                                         (mbTrainFsm_flagToAnalog_valVref_applyRxVref),
    .flagToAnalog_valVref_rxVrefCode                                          (mbTrainFsm_flagToAnalog_valVref_rxVrefCode),
    .flagFromAnalog_valVref_rxVrefApplied                                     (flagFromAnalog_valVref_rxVrefApplied),
    .flagToAnalog_valVref_configureRxInitD2CPointTest                         (mbTrainFsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .flagToAnalog_valVref_maximumComparisonErrorThreshold                     (mbTrainFsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valVref_comparisonMode                                      (mbTrainFsm_flagToAnalog_valVref_comparisonMode),
    .flagToAnalog_valVref_iterationCountSettings                              (mbTrainFsm_flagToAnalog_valVref_iterationCountSettings),
    .flagToAnalog_valVref_idleCountSettings                                   (mbTrainFsm_flagToAnalog_valVref_idleCountSettings),
    .flagToAnalog_valVref_burstCountSettings                                  (mbTrainFsm_flagToAnalog_valVref_burstCountSettings),
    .flagToAnalog_valVref_patternMode                                         (mbTrainFsm_flagToAnalog_valVref_patternMode),
    .flagToAnalog_valVref_clockPhaseControl                                   (mbTrainFsm_flagToAnalog_valVref_clockPhaseControl),
    .flagToAnalog_valVref_validPattern                                        (mbTrainFsm_flagToAnalog_valVref_validPattern),
    .flagToAnalog_valVref_dataPattern                                         (mbTrainFsm_flagToAnalog_valVref_dataPattern),
    .flagToAnalog_valVref_clearComparisonErrors                               (mbTrainFsm_flagToAnalog_valVref_clearComparisonErrors),
    .flagToAnalog_valVref_resetLocalTxScrambler                               (mbTrainFsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .flagToAnalog_dataVref_sendPattern                                        (mbTrainFsm_flagToAnalog_dataVref_sendPattern),
    .flagFromAnalog_dataVref_detectedDataPattern                              (flagFromAnalog_dataVref_detectedDataPattern),
    .flagFromAnalog_dataVref_finishedPattern                                  (flagFromAnalog_dataVref_finishedPattern),
    .flagToAnalog_dataVref_applyRxVref                                         (mbTrainFsm_flagToAnalog_dataVref_applyRxVref),
    .flagToAnalog_dataVref_rxVrefCodes                                         (mbTrainFsm_flagToAnalog_dataVref_rxVrefCodes),
    .flagFromAnalog_dataVref_rxVrefApplied                                     (flagFromAnalog_dataVref_rxVrefApplied),
    .flagToAnalog_dataVref_configureRxInitD2CPointTest                         (mbTrainFsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (mbTrainFsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .flagToAnalog_dataVref_comparisonMode                                      (mbTrainFsm_flagToAnalog_dataVref_comparisonMode),
    .flagToAnalog_dataVref_iterationCountSettings                              (mbTrainFsm_flagToAnalog_dataVref_iterationCountSettings),
    .flagToAnalog_dataVref_idleCountSettings                                   (mbTrainFsm_flagToAnalog_dataVref_idleCountSettings),
    .flagToAnalog_dataVref_burstCountSettings                                  (mbTrainFsm_flagToAnalog_dataVref_burstCountSettings),
    .flagToAnalog_dataVref_patternMode                                         (mbTrainFsm_flagToAnalog_dataVref_patternMode),
    .flagToAnalog_dataVref_clockPhaseControl                                   (mbTrainFsm_flagToAnalog_dataVref_clockPhaseControl),
    .flagToAnalog_dataVref_validPattern                                        (mbTrainFsm_flagToAnalog_dataVref_validPattern),
    .flagToAnalog_dataVref_dataPattern                                         (mbTrainFsm_flagToAnalog_dataVref_dataPattern),
    .flagToAnalog_dataVref_clearComparisonErrors                               (mbTrainFsm_flagToAnalog_dataVref_clearComparisonErrors),
    .flagToAnalog_dataVref_resetLocalTxScrambler                               (mbTrainFsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .flagToAnalog_rxClkCal_doCalibration                                      (mbTrainFsm_flagToAnalog_rxClkCal_doCalibration),
    .flagFromAnalog_rxClkCal_done                                             (flagFromAnalog_rxClkCal_done),
    .flagToAnalog_rxClkCal_sendClockTrack                                     (mbTrainFsm_flagToAnalog_rxClkCal_sendClockTrack),
    .flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern                (mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent              (flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler                (mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase                  (mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode                   (mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied              (flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest      (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold  (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode                   (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings           (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings                (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings               (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_patternMode                      (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl                (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .flagToAnalog_d2cReceiver_valTrainCenter_validPattern                     (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .flagToAnalog_d2cReceiver_valTrainCenter_dataPattern                      (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler            (mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo        (flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload        (flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .flagToAnalog_valTrainVref_sendPattern                                     (mbTrainFsm_flagToAnalog_valTrainVref_sendPattern),
    .flagFromAnalog_valTrainVref_detectedValPattern                            (flagFromAnalog_valTrainVref_detectedValPattern),
    .flagFromAnalog_valTrainVref_finishedPattern                               (flagFromAnalog_valTrainVref_finishedPattern),
    .flagToAnalog_valTrainVref_applyRxVref                                     (mbTrainFsm_flagToAnalog_valTrainVref_applyRxVref),
    .flagToAnalog_valTrainVref_rxVrefCode                                      (mbTrainFsm_flagToAnalog_valTrainVref_rxVrefCode),
    .flagFromAnalog_valTrainVref_rxVrefApplied                                 (flagFromAnalog_valTrainVref_rxVrefApplied),
    .flagToAnalog_valTrainVref_configureRxInitD2CPointTest                     (mbTrainFsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_valTrainVref_maximumComparisonErrorThreshold                 (mbTrainFsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valTrainVref_comparisonMode                                  (mbTrainFsm_flagToAnalog_valTrainVref_comparisonMode),
    .flagToAnalog_valTrainVref_iterationCountSettings                          (mbTrainFsm_flagToAnalog_valTrainVref_iterationCountSettings),
    .flagToAnalog_valTrainVref_idleCountSettings                               (mbTrainFsm_flagToAnalog_valTrainVref_idleCountSettings),
    .flagToAnalog_valTrainVref_burstCountSettings                              (mbTrainFsm_flagToAnalog_valTrainVref_burstCountSettings),
    .flagToAnalog_valTrainVref_patternMode                                     (mbTrainFsm_flagToAnalog_valTrainVref_patternMode),
    .flagToAnalog_valTrainVref_clockPhaseControl                               (mbTrainFsm_flagToAnalog_valTrainVref_clockPhaseControl),
    .flagToAnalog_valTrainVref_validPattern                                    (mbTrainFsm_flagToAnalog_valTrainVref_validPattern),
    .flagToAnalog_valTrainVref_dataPattern                                     (mbTrainFsm_flagToAnalog_valTrainVref_dataPattern),
    .flagToAnalog_valTrainVref_clearComparisonErrors                           (mbTrainFsm_flagToAnalog_valTrainVref_clearComparisonErrors),
    .flagToAnalog_valTrainVref_resetLocalTxScrambler                           (mbTrainFsm_flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern                  (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent                (flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler              (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase                (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode                 (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied            (flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew                 (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes                (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied             (flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode                 (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings         (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings              (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings             (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode                    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl              (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern                   (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern                    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler          (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo      (flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload      (flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .flagToAnalog_dataTrainVref_sendPattern                                    (mbTrainFsm_flagToAnalog_dataTrainVref_sendPattern),
    .flagFromAnalog_dataTrainVref_detectedDataPattern                          (flagFromAnalog_dataTrainVref_detectedDataPattern),
    .flagFromAnalog_dataTrainVref_finishedPattern                              (flagFromAnalog_dataTrainVref_finishedPattern),
    .flagToAnalog_dataTrainVref_applyRxVref                                    (mbTrainFsm_flagToAnalog_dataTrainVref_applyRxVref),
    .flagToAnalog_dataTrainVref_rxVrefCodes                                    (mbTrainFsm_flagToAnalog_dataTrainVref_rxVrefCodes),
    .flagFromAnalog_dataTrainVref_rxVrefApplied                                (flagFromAnalog_dataTrainVref_rxVrefApplied),
    .flagToAnalog_dataTrainVref_configureRxInitD2CPointTest                    (mbTrainFsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold                (mbTrainFsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_dataTrainVref_comparisonMode                                 (mbTrainFsm_flagToAnalog_dataTrainVref_comparisonMode),
    .flagToAnalog_dataTrainVref_iterationCountSettings                         (mbTrainFsm_flagToAnalog_dataTrainVref_iterationCountSettings),
    .flagToAnalog_dataTrainVref_idleCountSettings                              (mbTrainFsm_flagToAnalog_dataTrainVref_idleCountSettings),
    .flagToAnalog_dataTrainVref_burstCountSettings                             (mbTrainFsm_flagToAnalog_dataTrainVref_burstCountSettings),
    .flagToAnalog_dataTrainVref_patternMode                                    (mbTrainFsm_flagToAnalog_dataTrainVref_patternMode),
    .flagToAnalog_dataTrainVref_clockPhaseControl                              (mbTrainFsm_flagToAnalog_dataTrainVref_clockPhaseControl),
    .flagToAnalog_dataTrainVref_validPattern                                   (mbTrainFsm_flagToAnalog_dataTrainVref_validPattern),
    .flagToAnalog_dataTrainVref_dataPattern                                    (mbTrainFsm_flagToAnalog_dataTrainVref_dataPattern),
    .flagToAnalog_dataTrainVref_clearComparisonErrors                          (mbTrainFsm_flagToAnalog_dataTrainVref_clearComparisonErrors),
    .flagToAnalog_dataTrainVref_resetLocalTxScrambler                          (mbTrainFsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler),
    .flagToAnalog_rxDeskew_sendLfsrPattern                                      (mbTrainFsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .flagFromAnalog_rxDeskew_lfsrPatternSent                                    (flagFromAnalog_rxDeskew_lfsrPatternSent),
    .flagToAnalog_rxDeskew_resetLocalTxScrambler                                (mbTrainFsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .flagToAnalog_rxDeskew_applyRxLaneDeskew                                    (mbTrainFsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .flagToAnalog_rxDeskew_rxLaneDeskewCodes                                    (mbTrainFsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .flagFromAnalog_rxDeskew_rxLaneDeskewApplied                                (flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .flagToAnalog_rxDeskew_configureRxInitD2CPointTest                          (mbTrainFsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                      (mbTrainFsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .flagToAnalog_rxDeskew_comparisonMode                                       (mbTrainFsm_flagToAnalog_rxDeskew_comparisonMode),
    .flagToAnalog_rxDeskew_iterationCountSettings                               (mbTrainFsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .flagToAnalog_rxDeskew_idleCountSettings                                    (mbTrainFsm_flagToAnalog_rxDeskew_idleCountSettings),
    .flagToAnalog_rxDeskew_burstCountSettings                                   (mbTrainFsm_flagToAnalog_rxDeskew_burstCountSettings),
    .flagToAnalog_rxDeskew_patternMode                                          (mbTrainFsm_flagToAnalog_rxDeskew_patternMode),
    .flagToAnalog_rxDeskew_clockPhaseControl                                    (mbTrainFsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .flagToAnalog_rxDeskew_validPattern                                         (mbTrainFsm_flagToAnalog_rxDeskew_validPattern),
    .flagToAnalog_rxDeskew_dataPattern                                          (mbTrainFsm_flagToAnalog_rxDeskew_dataPattern),
    .flagToAnalog_rxDeskew_clearComparisonErrors                                (mbTrainFsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .flagFromAnalog_rxDeskew_detectedDataPattern                                (flagFromAnalog_rxDeskew_detectedDataPattern),
    .flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern                  (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent                (flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler              (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase                (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode                 (mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied            (flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode                 (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings         (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings              (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings             (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode                    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl              (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern                   (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern                    (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler          (mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo      (flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload      (flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .flagToLtsm_linkSpeed_phyInRetrain                                        (mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain),
    .flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern                         (mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent                       (flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler                     (mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest           (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold       (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_linkSpeed_comparisonMode                        (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings                (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings                     (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings                    (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_patternMode                           (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl                     (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .flagToAnalog_d2cReceiver_linkSpeed_validPattern                          (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .flagToAnalog_d2cReceiver_linkSpeed_dataPattern                           (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler                 (mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful            (flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
    .state                                                                    (mbTrainFsm_state),
    .activeSubstate                                                           (mbTrainFsm_activeSubstate),
    .lastErrorCount                                                           (mbTrainFsm_lastErrorCount),
    .retryCount                                                               (mbTrainFsm_retryCount)
  );

  always_comb begin
    state = stateReg;
    flagToAnalog_linkInit_resetLfsrScrambler = (stateReg == LTState_LINKINIT);
    sb_tx_valid = 1'b0;
    sb_tx_din = 128'b0;
    if (mbInitActive) begin
      sb_tx_valid = mbInitFsm_sb_tx_valid;
      sb_tx_din = mbInitFsm_sb_tx_din;
    end else if (mbTrainActive) begin
      sb_tx_valid = mbTrainFsm_sb_tx_valid;
      sb_tx_din = mbTrainFsm_sb_tx_din;
    end else if ((stateReg == LTState_SBINIT_pattern) ||
                 (stateReg == LTState_SBINIT_sendFour) ||
                 (stateReg == LTState_SBINIT_OORmsg) ||
                 (stateReg == LTState_SBINIT_DONEmsg)) begin
      sb_tx_valid = sbinitTxValid;
      sb_tx_din = sbinitTxDin;
    end

    dbg_flagSbinitFirstClkPatternSeen = flagSbinitFirstClkPatternSeen;
    dbg_rxValidRisingEdge = rxValidRisingEdge;
    dbg_sbinitSendCount = sbinitSendCount;
    dbg_sbTxValid = sb_tx_valid;
    dbg_sbTxDin = sb_tx_din;
    dbg_flagTrainError = parentTrainError || mbInitFsm_trainError || mbTrainFsm_trainError;
    dbg_mbinitSubstate = mbInitFsm_substate;
    dbg_mbinitReversalMbReceivedSuccessCount = mbInitFsm_dbg_mbinitReversalMbReceivedSuccessCount;
    dbg_mbtrainState = mbTrainFsm_state;
    dbg_mbtrainActiveSubstate = mbTrainFsm_activeSubstate;
    dbg_mbtrainLastErrorCount = mbTrainFsm_lastErrorCount;
    dbg_mbtrainRetryCount = mbTrainFsm_retryCount;
    flagToAnalog_RepairClkState = mbInitFsm_flagToAnalog_RepairClkState;
    flagToAnalog_SendClkPatterns = mbInitFsm_flagToAnalog_SendClkPatterns;
    flagToAnalog_RepairValState = mbInitFsm_flagToAnalog_RepairValState;
    flagToAnalog_SendValTrainPattern = mbInitFsm_flagToAnalog_SendValTrainPattern;
    flagToAnalog_ReversalMbSendLaneIDPattern = mbInitFsm_flagToAnalog_ReversalMbSendLaneIDPattern;
    flagToAnalog_RepairMbSendLaneIDPattern = mbInitFsm_flagToAnalog_RepairMbSendLaneIDPattern;
    flagToAnalog_RepairMbSetReceiver = mbInitFsm_flagToAnalog_RepairMbSetReceiver;
    flagToAnalog_LaneReversalApplied = mbInitFsm_flagToAnalog_LaneReversalApplied;
    flagToAnalog_valVref_sendPattern = mbTrainFsm_flagToAnalog_valVref_sendPattern;
    flagToAnalog_valVref_applyRxVref = mbTrainFsm_flagToAnalog_valVref_applyRxVref;
    flagToAnalog_valVref_rxVrefCode = mbTrainFsm_flagToAnalog_valVref_rxVrefCode;
    flagToAnalog_valVref_configureRxInitD2CPointTest = mbTrainFsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
    flagToAnalog_valVref_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
    flagToAnalog_valVref_comparisonMode = mbTrainFsm_flagToAnalog_valVref_comparisonMode;
    flagToAnalog_valVref_iterationCountSettings = mbTrainFsm_flagToAnalog_valVref_iterationCountSettings;
    flagToAnalog_valVref_idleCountSettings = mbTrainFsm_flagToAnalog_valVref_idleCountSettings;
    flagToAnalog_valVref_burstCountSettings = mbTrainFsm_flagToAnalog_valVref_burstCountSettings;
    flagToAnalog_valVref_patternMode = mbTrainFsm_flagToAnalog_valVref_patternMode;
    flagToAnalog_valVref_clockPhaseControl = mbTrainFsm_flagToAnalog_valVref_clockPhaseControl;
    flagToAnalog_valVref_validPattern = mbTrainFsm_flagToAnalog_valVref_validPattern;
    flagToAnalog_valVref_dataPattern = mbTrainFsm_flagToAnalog_valVref_dataPattern;
    flagToAnalog_valVref_clearComparisonErrors = mbTrainFsm_flagToAnalog_valVref_clearComparisonErrors;
    flagToAnalog_valVref_resetLocalTxScrambler = mbTrainFsm_flagToAnalog_valVref_resetLocalTxScrambler;
    flagToAnalog_dataVref_sendPattern = mbTrainFsm_flagToAnalog_dataVref_sendPattern;
    flagToAnalog_dataVref_applyRxVref = mbTrainFsm_flagToAnalog_dataVref_applyRxVref;
    flagToAnalog_dataVref_rxVrefCodes = mbTrainFsm_flagToAnalog_dataVref_rxVrefCodes;
    flagToAnalog_dataVref_configureRxInitD2CPointTest = mbTrainFsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
    flagToAnalog_dataVref_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
    flagToAnalog_dataVref_comparisonMode = mbTrainFsm_flagToAnalog_dataVref_comparisonMode;
    flagToAnalog_dataVref_iterationCountSettings = mbTrainFsm_flagToAnalog_dataVref_iterationCountSettings;
    flagToAnalog_dataVref_idleCountSettings = mbTrainFsm_flagToAnalog_dataVref_idleCountSettings;
    flagToAnalog_dataVref_burstCountSettings = mbTrainFsm_flagToAnalog_dataVref_burstCountSettings;
    flagToAnalog_dataVref_patternMode = mbTrainFsm_flagToAnalog_dataVref_patternMode;
    flagToAnalog_dataVref_clockPhaseControl = mbTrainFsm_flagToAnalog_dataVref_clockPhaseControl;
    flagToAnalog_dataVref_validPattern = mbTrainFsm_flagToAnalog_dataVref_validPattern;
    flagToAnalog_dataVref_dataPattern = mbTrainFsm_flagToAnalog_dataVref_dataPattern;
    flagToAnalog_dataVref_clearComparisonErrors = mbTrainFsm_flagToAnalog_dataVref_clearComparisonErrors;
    flagToAnalog_dataVref_resetLocalTxScrambler = mbTrainFsm_flagToAnalog_dataVref_resetLocalTxScrambler;
    flagToAnalog_rxClkCal_doCalibration = mbTrainFsm_flagToAnalog_rxClkCal_doCalibration;
    flagToAnalog_rxClkCal_sendClockTrack = mbTrainFsm_flagToAnalog_rxClkCal_sendClockTrack;
    flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern = mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
    flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler = mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
    flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase = mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
    flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode = mbTrainFsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
    flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
    flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
    flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
    flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
    flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
    flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
    flagToAnalog_d2cReceiver_valTrainCenter_patternMode = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
    flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
    flagToAnalog_d2cReceiver_valTrainCenter_validPattern = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
    flagToAnalog_d2cReceiver_valTrainCenter_dataPattern = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
    flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler = mbTrainFsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
    flagToAnalog_valTrainVref_sendPattern = mbTrainFsm_flagToAnalog_valTrainVref_sendPattern;
    flagToAnalog_valTrainVref_applyRxVref = mbTrainFsm_flagToAnalog_valTrainVref_applyRxVref;
    flagToAnalog_valTrainVref_rxVrefCode = mbTrainFsm_flagToAnalog_valTrainVref_rxVrefCode;
    flagToAnalog_valTrainVref_configureRxInitD2CPointTest = mbTrainFsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
    flagToAnalog_valTrainVref_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
    flagToAnalog_valTrainVref_comparisonMode = mbTrainFsm_flagToAnalog_valTrainVref_comparisonMode;
    flagToAnalog_valTrainVref_iterationCountSettings = mbTrainFsm_flagToAnalog_valTrainVref_iterationCountSettings;
    flagToAnalog_valTrainVref_idleCountSettings = mbTrainFsm_flagToAnalog_valTrainVref_idleCountSettings;
    flagToAnalog_valTrainVref_burstCountSettings = mbTrainFsm_flagToAnalog_valTrainVref_burstCountSettings;
    flagToAnalog_valTrainVref_patternMode = mbTrainFsm_flagToAnalog_valTrainVref_patternMode;
    flagToAnalog_valTrainVref_clockPhaseControl = mbTrainFsm_flagToAnalog_valTrainVref_clockPhaseControl;
    flagToAnalog_valTrainVref_validPattern = mbTrainFsm_flagToAnalog_valTrainVref_validPattern;
    flagToAnalog_valTrainVref_dataPattern = mbTrainFsm_flagToAnalog_valTrainVref_dataPattern;
    flagToAnalog_valTrainVref_clearComparisonErrors = mbTrainFsm_flagToAnalog_valTrainVref_clearComparisonErrors;
    flagToAnalog_valTrainVref_resetLocalTxScrambler = mbTrainFsm_flagToAnalog_valTrainVref_resetLocalTxScrambler;
    flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
    flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
    flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
    flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
    flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
    flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
    flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
    flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
    flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
    flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
    flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
    flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
    flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
    flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
    flagToAnalog_dataTrainVref_sendPattern = mbTrainFsm_flagToAnalog_dataTrainVref_sendPattern;
    flagToAnalog_dataTrainVref_applyRxVref = mbTrainFsm_flagToAnalog_dataTrainVref_applyRxVref;
    flagToAnalog_dataTrainVref_rxVrefCodes = mbTrainFsm_flagToAnalog_dataTrainVref_rxVrefCodes;
    flagToAnalog_dataTrainVref_configureRxInitD2CPointTest = mbTrainFsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
    flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
    flagToAnalog_dataTrainVref_comparisonMode = mbTrainFsm_flagToAnalog_dataTrainVref_comparisonMode;
    flagToAnalog_dataTrainVref_iterationCountSettings = mbTrainFsm_flagToAnalog_dataTrainVref_iterationCountSettings;
    flagToAnalog_dataTrainVref_idleCountSettings = mbTrainFsm_flagToAnalog_dataTrainVref_idleCountSettings;
    flagToAnalog_dataTrainVref_burstCountSettings = mbTrainFsm_flagToAnalog_dataTrainVref_burstCountSettings;
    flagToAnalog_dataTrainVref_patternMode = mbTrainFsm_flagToAnalog_dataTrainVref_patternMode;
    flagToAnalog_dataTrainVref_clockPhaseControl = mbTrainFsm_flagToAnalog_dataTrainVref_clockPhaseControl;
    flagToAnalog_dataTrainVref_validPattern = mbTrainFsm_flagToAnalog_dataTrainVref_validPattern;
    flagToAnalog_dataTrainVref_dataPattern = mbTrainFsm_flagToAnalog_dataTrainVref_dataPattern;
    flagToAnalog_dataTrainVref_clearComparisonErrors = mbTrainFsm_flagToAnalog_dataTrainVref_clearComparisonErrors;
    flagToAnalog_dataTrainVref_resetLocalTxScrambler = mbTrainFsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
    flagToAnalog_rxDeskew_sendLfsrPattern = mbTrainFsm_flagToAnalog_rxDeskew_sendLfsrPattern;
    flagToAnalog_rxDeskew_resetLocalTxScrambler = mbTrainFsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
    flagToAnalog_rxDeskew_applyRxLaneDeskew = mbTrainFsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
    flagToAnalog_rxDeskew_rxLaneDeskewCodes = mbTrainFsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
    flagToAnalog_rxDeskew_configureRxInitD2CPointTest = mbTrainFsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
    flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
    flagToAnalog_rxDeskew_comparisonMode = mbTrainFsm_flagToAnalog_rxDeskew_comparisonMode;
    flagToAnalog_rxDeskew_iterationCountSettings = mbTrainFsm_flagToAnalog_rxDeskew_iterationCountSettings;
    flagToAnalog_rxDeskew_idleCountSettings = mbTrainFsm_flagToAnalog_rxDeskew_idleCountSettings;
    flagToAnalog_rxDeskew_burstCountSettings = mbTrainFsm_flagToAnalog_rxDeskew_burstCountSettings;
    flagToAnalog_rxDeskew_patternMode = mbTrainFsm_flagToAnalog_rxDeskew_patternMode;
    flagToAnalog_rxDeskew_clockPhaseControl = mbTrainFsm_flagToAnalog_rxDeskew_clockPhaseControl;
    flagToAnalog_rxDeskew_validPattern = mbTrainFsm_flagToAnalog_rxDeskew_validPattern;
    flagToAnalog_rxDeskew_dataPattern = mbTrainFsm_flagToAnalog_rxDeskew_dataPattern;
    flagToAnalog_rxDeskew_clearComparisonErrors = mbTrainFsm_flagToAnalog_rxDeskew_clearComparisonErrors;
    flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
    flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
    flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
    flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode = mbTrainFsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
    flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
    flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
    flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
    flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
    flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
    flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
    flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
    flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
    flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler = mbTrainFsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
    flagToLtsm_linkSpeed_phyInRetrain = mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain;
    flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern = mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
    flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler = mbTrainFsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
    flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
    flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
    flagToAnalog_d2cReceiver_linkSpeed_comparisonMode = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
    flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
    flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
    flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
    flagToAnalog_d2cReceiver_linkSpeed_patternMode = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
    flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
    flagToAnalog_d2cReceiver_linkSpeed_validPattern = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
    flagToAnalog_d2cReceiver_linkSpeed_dataPattern = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
    flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler = mbTrainFsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg <= LTState_RESET;
      resetCnt <= 23'b0;
      sbinitTxValid <= 1'b0;
      sbinitTxDin <= 128'b0;
      prevRxValid <= 1'b0;
      flagSbinitFirstClkPatternSeen <= 1'b0;
      flagSbinitSecondClkPatternSeen <= 1'b0;
      flagSbinitOorSeen <= 1'b0;
      flagSbinitReceivedDoneReq <= 1'b0;
      flagSbinitReceivedDoneResp <= 1'b0;
      flagSbinitSentDoneReq <= 1'b0;
      flagSbinitSentDoneResp <= 1'b0;
      sbinitSendCount <= 3'b0;
      parentTrainError <= 1'b0;
    end else begin
      // RegNext and WireDefault semantics from the Chisel source.
      prevRxValid <= sb_rx_valid;
      sbinitTxValid <= 1'b0;
      sbinitTxDin <= 128'b0;

      // Parent-owned SBINIT RX decoder. The source qualifies this decoder by state.
      if (rxValidRisingEdge &&
          ((stateReg == LTState_SBINIT_pattern) ||
           (stateReg == LTState_SBINIT_sendFour) ||
           (stateReg == LTState_SBINIT_OORmsg) ||
           (stateReg == LTState_SBINIT_DONEmsg))) begin
        if (sb_rx_dout == SBINIT_CLK_PATTERN) begin
          if (flagSbinitFirstClkPatternSeen)
            flagSbinitSecondClkPatternSeen <= 1'b1;
          else
            flagSbinitFirstClkPatternSeen <= 1'b1;
        end else begin
          flagSbinitFirstClkPatternSeen <= 1'b0;
        end

        // check for OOR msgcode and msgsubcode only
        if ((sb_rx_dout[21:14] == SBINIT_OOR_SUCCESS[21:14]) &&
          (sb_rx_dout[39:32] == SBINIT_OOR_SUCCESS[39:32]))
          flagSbinitOorSeen <= 1'b1;
        if (sb_rx_dout == SBINIT_DONE_REQ)
          flagSbinitReceivedDoneReq <= 1'b1;
        if (sb_rx_dout == SBINIT_DONE_RESP)
          flagSbinitReceivedDoneResp <= 1'b1;
      end

      unique case (stateReg)
        LTState_RESET: begin
          flagSbinitFirstClkPatternSeen <= 1'b0;
          flagSbinitSecondClkPatternSeen <= 1'b0;
          flagSbinitOorSeen <= 1'b0;
          flagSbinitReceivedDoneReq <= 1'b0;
          flagSbinitReceivedDoneResp <= 1'b0;
          flagSbinitSentDoneReq <= 1'b0;
          flagSbinitSentDoneResp <= 1'b0;
          sbinitSendCount <= 3'b0;
          parentTrainError <= 1'b0;

          if (resetCnt < RESET_CYCLES)
            resetCnt <= resetCnt + 23'd1;
          else if (start && stable_clk && pll_locked && stable_supply)
            stateReg <= LTState_SBINIT_pattern;
        end

        LTState_SBINIT_pattern: begin
          if (sb_tx_ready && !sbinitTxValid) begin
            sbinitTxDin <= SBINIT_CLK_PATTERN;
            sbinitTxValid <= 1'b1;
          end
          if (flagSbinitSecondClkPatternSeen) begin
            stateReg <= LTState_SBINIT_sendFour;
            sbinitSendCount <= 3'b0;
          end
        end

        LTState_SBINIT_sendFour: begin
          if (sb_tx_ready && !sbinitTxValid && (sbinitSendCount < 3'd4)) begin
            sbinitTxDin <= SBINIT_CLK_PATTERN;
            sbinitTxValid <= 1'b1;
            sbinitSendCount <= sbinitSendCount + 3'd1;
          end
          if (sbinitSendCount == 3'd4)
            stateReg <= LTState_SBINIT_OORmsg;
        end

        LTState_SBINIT_OORmsg: begin
          if (sb_tx_ready && !sbinitTxValid) begin
            sbinitTxDin <= SBINIT_OOR_SUCCESS;
            sbinitTxValid <= 1'b1;
          end
          if (flagSbinitOorSeen)
            stateReg <= LTState_SBINIT_DONEmsg;
        end

        LTState_SBINIT_DONEmsg: begin
          if (sb_tx_ready && !sbinitTxValid) begin
            if (flagSbinitReceivedDoneReq && !flagSbinitSentDoneResp) begin
              sbinitTxDin <= SBINIT_DONE_RESP;
              sbinitTxValid <= 1'b1;
              flagSbinitSentDoneResp <= 1'b1;
            end else if (!flagSbinitSentDoneReq) begin
              sbinitTxDin <= SBINIT_DONE_REQ;
              sbinitTxValid <= 1'b1;
              flagSbinitSentDoneReq <= 1'b1;
            end
          end
          if (flagSbinitReceivedDoneReq && flagSbinitReceivedDoneResp &&
              flagSbinitSentDoneReq && flagSbinitSentDoneResp)
            stateReg <= LTState_MBINIT_SUPER;
        end

        LTState_MBINIT_SUPER: begin
          if (mbInitFsm_done)
            stateReg <= LTState_MBTRAIN;
        end

        LTState_MBTRAIN: begin
          if (mbTrainFsm_done)
            stateReg <= LTState_LINKINIT;
        end

        LTState_LINKINIT: stateReg <= LTState_ACTIVE;
        LTState_ACTIVE: stateReg <= LTState_ACTIVE;
        LTState_TRAIN_ERROR: stateReg <= LTState_TRAIN_ERROR;
        default: stateReg <= LTState_RESET;
      endcase

      // Source-order terminal error overrides.
      if (mbInitActive && mbInitFsm_trainError) begin
        parentTrainError <= 1'b1;
        stateReg <= LTState_TRAIN_ERROR;
      end
      if (mbTrainActive && mbTrainFsm_trainError) begin
        parentTrainError <= 1'b1;
        stateReg <= LTState_TRAIN_ERROR;
      end
    end
  end
endmodule

`default_nettype wire
