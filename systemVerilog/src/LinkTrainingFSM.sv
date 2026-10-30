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
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH,
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
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH,
  parameter int unsigned dataVrefMinimumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS,
  parameter int unsigned dataVrefMaximumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS,
  parameter logic [15:0] dataVrefMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned dataVrefMinPassingWindowValues = LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned dataVrefMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES,
  parameter bit dataTrainVrefEnable = 1'b1,
  parameter bit rxDeskewEnable = LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE,
  parameter int unsigned rxDeskewValueCount = LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
  parameter int unsigned rxDeskewCodeWidth =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH,
  parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES
) (
  input wire logic clock,
  input wire logic [31:0] cycles_1us,
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
  // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
  output var logic [2:0]     dbg_mbinitSubstate,
  output var logic [1:0]     dbg_mbinitParamSenderState,
  output var logic [1:0]     dbg_mbinitParamReceiverState,
  output var logic [1:0]     dbg_mbinitCalSenderState,
  output var logic [1:0]     dbg_mbinitCalReceiverState,
  output var logic [2:0]     dbg_mbinitRepairClkSenderState,
  output var logic [2:0]     dbg_mbinitRepairClkReceiverState,
  output var logic [2:0]     dbg_mbinitRepairValSenderState,
  output var logic [2:0]     dbg_mbinitRepairValReceiverState,
  output var logic [3:0]     dbg_mbinitReversalMbSenderState,
  output var logic [2:0]     dbg_mbinitReversalMbReceiverState,
  output var logic [4:0]     dbg_mbinitRepairMbSenderState,
  output var logic [3:0]     dbg_mbinitRepairMbReceiverState,
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
  output var logic           flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic           flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic           flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic           flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic            flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic           flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic           flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]    flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]    flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic           flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]     flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]     flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]     flagToAnalog_d2cReceiver_dataPattern,
  output var logic           flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic           flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic           flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic           flagToAnalog_d2cSender_applyTxLaneDeskew,
  // TX deskew: 20 bits/lane, cell 1 [9:0], cell 2 [19:10]; LSB + 9 thermometer bits/cell.
  output var logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic           flagFromAnalog_d2cSender_txLaneDeskewApplied,
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
  output var logic           flagToLtsm_linkSpeed_phyInRetrain,
  output var logic [1:0]           flagToAnalog_linkSpeed_speedCode,
  output var logic           flagToAnalog_linkSpeed_applySpeed,
  output var logic           flagToAnalog_linkSpeed_electricalIdle,
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  input wire logic [1:0]    linkSpeed_requestedSpeed,
  input wire logic     flagFromAnalog_linkSpeed_speedApplied,
  output var logic [3:0]     dbg_mbtrainState,
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  output var logic [11:0]    dbg_mbtrainActiveSubstate,
  output var logic [3:0]     dbg_mbtrainValVrefLocalState,
  output var logic [2:0]     dbg_mbtrainValVrefRemoteState,
  output var logic [3:0]     dbg_mbtrainValVrefSweepState,
  output var logic [3:0]     dbg_mbtrainValVrefPointInitiatorState,
  output var logic [3:0]     dbg_mbtrainValVrefPointResponderState,
  output var logic [3:0]     dbg_mbtrainDataVrefLocalState,
  output var logic [2:0]     dbg_mbtrainDataVrefRemoteState,
  output var logic [3:0]     dbg_mbtrainDataVrefSweepState,
  output var logic [3:0]     dbg_mbtrainDataVrefPointInitiatorState,
  output var logic [3:0]     dbg_mbtrainDataVrefPointResponderState,
  output var logic [1:0]     dbg_mbtrainSpeedIdleSenderState,
  output var logic [1:0]     dbg_mbtrainSpeedIdleReceiverState,
  output var logic [1:0]     dbg_mbtrainTxSelfCalSenderState,
  output var logic [1:0]     dbg_mbtrainTxSelfCalReceiverState,
  output var logic [2:0]     dbg_mbtrainRxClkCalSenderState,
  output var logic [2:0]     dbg_mbtrainRxClkCalReceiverState,
  output var logic [3:0]     dbg_mbtrainValTrainCenterSenderState,
  output var logic [2:0]     dbg_mbtrainValTrainCenterReceiverState,
  output var logic [3:0]     dbg_mbtrainValTrainCenterD2cSenderState,
  output var logic [3:0]     dbg_mbtrainValTrainCenterD2cReceiverState,
  output var logic [3:0]     dbg_mbtrainValTrainCenterSweepState,
  output var logic [3:0]     dbg_mbtrainValTrainVrefLocalState,
  output var logic [2:0]     dbg_mbtrainValTrainVrefRemoteState,
  output var logic [3:0]     dbg_mbtrainValTrainVrefSweepState,
  output var logic [3:0]     dbg_mbtrainValTrainVrefPointInitiatorState,
  output var logic [3:0]     dbg_mbtrainValTrainVrefPointResponderState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter1SenderState,
  output var logic [2:0]     dbg_mbtrainDataTrainCenter1ReceiverState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter1D2cSenderState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter1D2cReceiverState,
  output var logic [4:0]     dbg_mbtrainDataTrainCenter1SweepState,
  output var logic [3:0]     dbg_mbtrainDataTrainVrefLocalState,
  output var logic [2:0]     dbg_mbtrainDataTrainVrefRemoteState,
  output var logic [3:0]     dbg_mbtrainDataTrainVrefSweepState,
  output var logic [3:0]     dbg_mbtrainDataTrainVrefPointInitiatorState,
  output var logic [3:0]     dbg_mbtrainDataTrainVrefPointResponderState,
  output var logic [3:0]     dbg_mbtrainRxDeskewLocalState,
  output var logic [2:0]     dbg_mbtrainRxDeskewRemoteState,
  output var logic [3:0]     dbg_mbtrainRxDeskewSweepState,
  output var logic [3:0]     dbg_mbtrainRxDeskewPointInitiatorState,
  output var logic [3:0]     dbg_mbtrainRxDeskewPointResponderState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter2SenderState,
  output var logic [2:0]     dbg_mbtrainDataTrainCenter2ReceiverState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter2D2cSenderState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter2D2cReceiverState,
  output var logic [3:0]     dbg_mbtrainDataTrainCenter2SweepState,
  output var logic [3:0]     dbg_mbtrainLinkSpeedSenderState,
  output var logic [2:0]     dbg_mbtrainLinkSpeedReceiverState,
  output var logic [3:0]     dbg_mbtrainLinkSpeedD2cSenderState,
  output var logic [3:0]     dbg_mbtrainLinkSpeedD2cReceiverState,
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
  (* keep = "true" *) logic flagSbinitOorSuccessSeen;
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
  wire [127:0] SBINIT_OOR_SUCCESS = msgSbinitOutOfResetSuccess(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
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
  // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
  logic [2:0] mbInitFsm_substate;
  logic [1:0] mbInitFsm_dbg_mbinitParamSenderState;
  logic [1:0] mbInitFsm_dbg_mbinitParamReceiverState;
  logic [1:0] mbInitFsm_dbg_mbinitCalSenderState;
  logic [1:0] mbInitFsm_dbg_mbinitCalReceiverState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairClkSenderState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairClkReceiverState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairValSenderState;
  logic [2:0] mbInitFsm_dbg_mbinitRepairValReceiverState;
  logic [3:0] mbInitFsm_dbg_mbinitReversalMbSenderState;
  logic [2:0] mbInitFsm_dbg_mbinitReversalMbReceiverState;
  logic [4:0] mbInitFsm_dbg_mbinitRepairMbSenderState;
  logic [3:0] mbInitFsm_dbg_mbinitRepairMbReceiverState;
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
  logic mbTrainFsm_flagToAnalog_d2cSender_sendValTrainPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_resetLocalScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_txClockPhaseCode;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_comparisonMode;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_idleCountSettings;
  logic [15:0] mbTrainFsm_flagToAnalog_d2cReceiver_burstCountSettings;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_patternMode;
  logic [3:0] mbTrainFsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_validPattern;
  logic [2:0] mbTrainFsm_flagToAnalog_d2cReceiver_dataPattern;
  logic mbTrainFsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic mbTrainFsm_flagToAnalog_d2cSender_sendLfsrPattern;
  logic mbTrainFsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] mbTrainFsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
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
  logic [1:0] mbInitFsm_negotiatedSpeed;
  logic mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic [1:0] mbTrainFsm_flagToAnalog_linkSpeed_speedCode;
  logic mbTrainFsm_flagToAnalog_linkSpeed_applySpeed;
  logic mbTrainFsm_flagToAnalog_linkSpeed_electricalIdle;
  logic [3:0] mbTrainFsm_state;
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  logic [11:0] mbTrainFsm_activeSubstate;
  logic [3:0] mbTrainFsm_dbg_mbtrainValVrefLocalState;
  logic [2:0] mbTrainFsm_dbg_mbtrainValVrefRemoteState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValVrefSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValVrefPointInitiatorState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValVrefPointResponderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataVrefLocalState;
  logic [2:0] mbTrainFsm_dbg_mbtrainDataVrefRemoteState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataVrefSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataVrefPointInitiatorState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataVrefPointResponderState;
  logic [1:0] mbTrainFsm_dbg_mbtrainSpeedIdleSenderState;
  logic [1:0] mbTrainFsm_dbg_mbtrainSpeedIdleReceiverState;
  logic [1:0] mbTrainFsm_dbg_mbtrainTxSelfCalSenderState;
  logic [1:0] mbTrainFsm_dbg_mbtrainTxSelfCalReceiverState;
  logic [2:0] mbTrainFsm_dbg_mbtrainRxClkCalSenderState;
  logic [2:0] mbTrainFsm_dbg_mbtrainRxClkCalReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainCenterSenderState;
  logic [2:0] mbTrainFsm_dbg_mbtrainValTrainCenterReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainCenterD2cSenderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainCenterD2cReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainCenterSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainVrefLocalState;
  logic [2:0] mbTrainFsm_dbg_mbtrainValTrainVrefRemoteState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainVrefSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainVrefPointInitiatorState;
  logic [3:0] mbTrainFsm_dbg_mbtrainValTrainVrefPointResponderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter1SenderState;
  logic [2:0] mbTrainFsm_dbg_mbtrainDataTrainCenter1ReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cSenderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cReceiverState;
  logic [4:0] mbTrainFsm_dbg_mbtrainDataTrainCenter1SweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainVrefLocalState;
  logic [2:0] mbTrainFsm_dbg_mbtrainDataTrainVrefRemoteState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainVrefSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainVrefPointInitiatorState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainVrefPointResponderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainRxDeskewLocalState;
  logic [2:0] mbTrainFsm_dbg_mbtrainRxDeskewRemoteState;
  logic [3:0] mbTrainFsm_dbg_mbtrainRxDeskewSweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainRxDeskewPointInitiatorState;
  logic [3:0] mbTrainFsm_dbg_mbtrainRxDeskewPointResponderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter2SenderState;
  logic [2:0] mbTrainFsm_dbg_mbtrainDataTrainCenter2ReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cSenderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainDataTrainCenter2SweepState;
  logic [3:0] mbTrainFsm_dbg_mbtrainLinkSpeedSenderState;
  logic [2:0] mbTrainFsm_dbg_mbtrainLinkSpeedReceiverState;
  logic [3:0] mbTrainFsm_dbg_mbtrainLinkSpeedD2cSenderState;
  logic [3:0] mbTrainFsm_dbg_mbtrainLinkSpeedD2cReceiverState;
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
    .requestedSpeed(linkSpeed_requestedSpeed),
    .negotiatedSpeed(mbInitFsm_negotiatedSpeed),
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
    // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
    .substate                                                                 (mbInitFsm_substate),
    .dbg_mbinitParamSenderState                                               (mbInitFsm_dbg_mbinitParamSenderState),
    .dbg_mbinitParamReceiverState                                             (mbInitFsm_dbg_mbinitParamReceiverState),
    .dbg_mbinitCalSenderState                                                 (mbInitFsm_dbg_mbinitCalSenderState),
    .dbg_mbinitCalReceiverState                                               (mbInitFsm_dbg_mbinitCalReceiverState),
    .dbg_mbinitRepairClkSenderState                                           (mbInitFsm_dbg_mbinitRepairClkSenderState),
    .dbg_mbinitRepairClkReceiverState                                         (mbInitFsm_dbg_mbinitRepairClkReceiverState),
    .dbg_mbinitRepairValSenderState                                           (mbInitFsm_dbg_mbinitRepairValSenderState),
    .dbg_mbinitRepairValReceiverState                                         (mbInitFsm_dbg_mbinitRepairValReceiverState),
    .dbg_mbinitReversalMbSenderState                                          (mbInitFsm_dbg_mbinitReversalMbSenderState),
    .dbg_mbinitReversalMbReceiverState                                        (mbInitFsm_dbg_mbinitReversalMbReceiverState),
    .dbg_mbinitRepairMbSenderState                                            (mbInitFsm_dbg_mbinitRepairMbSenderState),
    .dbg_mbinitRepairMbReceiverState                                          (mbInitFsm_dbg_mbinitRepairMbReceiverState),
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
    .cycles_1us(cycles_1us),
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
    .flagToAnalog_d2cSender_sendValTrainPattern                (mbTrainFsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainPatternSent              (flagFromAnalog_d2cSender_valTrainPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler                (mbTrainFsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase                  (mbTrainFsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode                   (mbTrainFsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied              (flagFromAnalog_d2cSender_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest      (mbTrainFsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold  (mbTrainFsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode                   (mbTrainFsm_flagToAnalog_d2cReceiver_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings           (mbTrainFsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings                (mbTrainFsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings               (mbTrainFsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode                      (mbTrainFsm_flagToAnalog_d2cReceiver_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl                (mbTrainFsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern                     (mbTrainFsm_flagToAnalog_d2cReceiver_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern                      (mbTrainFsm_flagToAnalog_d2cReceiver_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler            (mbTrainFsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo        (flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload        (flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .flagToAnalog_d2cSender_sendLfsrPattern                  (mbTrainFsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent                (flagFromAnalog_d2cSender_lfsrPatternSent),
    .flagToAnalog_d2cSender_applyTxLaneDeskew                 (mbTrainFsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_txLaneDeskewCodes                (mbTrainFsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_txLaneDeskewApplied             (flagFromAnalog_d2cSender_txLaneDeskewApplied),
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
    .flagToLtsm_linkSpeed_phyInRetrain                                        (mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain),
    .flagToAnalog_linkSpeed_speedCode                                        (mbTrainFsm_flagToAnalog_linkSpeed_speedCode),
    .flagToAnalog_linkSpeed_applySpeed                                        (mbTrainFsm_flagToAnalog_linkSpeed_applySpeed),
    .flagToAnalog_linkSpeed_electricalIdle                                        (mbTrainFsm_flagToAnalog_linkSpeed_electricalIdle),
    .flagFromAnalog_d2cReceiver_laneComparisonSuccessful            (flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .initialSpeed(mbInitFsm_negotiatedSpeed),
    .flagFromAnalog_linkSpeed_speedApplied            (flagFromAnalog_linkSpeed_speedApplied),
    .state                                                                    (mbTrainFsm_state),
    // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
    .activeSubstate                                                           (mbTrainFsm_activeSubstate),
    .dbg_mbtrainValVrefLocalState                                             (mbTrainFsm_dbg_mbtrainValVrefLocalState),
    .dbg_mbtrainValVrefRemoteState                                            (mbTrainFsm_dbg_mbtrainValVrefRemoteState),
    .dbg_mbtrainValVrefSweepState                                             (mbTrainFsm_dbg_mbtrainValVrefSweepState),
    .dbg_mbtrainValVrefPointInitiatorState                                    (mbTrainFsm_dbg_mbtrainValVrefPointInitiatorState),
    .dbg_mbtrainValVrefPointResponderState                                    (mbTrainFsm_dbg_mbtrainValVrefPointResponderState),
    .dbg_mbtrainDataVrefLocalState                                            (mbTrainFsm_dbg_mbtrainDataVrefLocalState),
    .dbg_mbtrainDataVrefRemoteState                                           (mbTrainFsm_dbg_mbtrainDataVrefRemoteState),
    .dbg_mbtrainDataVrefSweepState                                            (mbTrainFsm_dbg_mbtrainDataVrefSweepState),
    .dbg_mbtrainDataVrefPointInitiatorState                                   (mbTrainFsm_dbg_mbtrainDataVrefPointInitiatorState),
    .dbg_mbtrainDataVrefPointResponderState                                   (mbTrainFsm_dbg_mbtrainDataVrefPointResponderState),
    .dbg_mbtrainSpeedIdleSenderState                                          (mbTrainFsm_dbg_mbtrainSpeedIdleSenderState),
    .dbg_mbtrainSpeedIdleReceiverState                                        (mbTrainFsm_dbg_mbtrainSpeedIdleReceiverState),
    .dbg_mbtrainTxSelfCalSenderState                                          (mbTrainFsm_dbg_mbtrainTxSelfCalSenderState),
    .dbg_mbtrainTxSelfCalReceiverState                                        (mbTrainFsm_dbg_mbtrainTxSelfCalReceiverState),
    .dbg_mbtrainRxClkCalSenderState                                           (mbTrainFsm_dbg_mbtrainRxClkCalSenderState),
    .dbg_mbtrainRxClkCalReceiverState                                         (mbTrainFsm_dbg_mbtrainRxClkCalReceiverState),
    .dbg_mbtrainValTrainCenterSenderState                                     (mbTrainFsm_dbg_mbtrainValTrainCenterSenderState),
    .dbg_mbtrainValTrainCenterReceiverState                                   (mbTrainFsm_dbg_mbtrainValTrainCenterReceiverState),
    .dbg_mbtrainValTrainCenterD2cSenderState                                  (mbTrainFsm_dbg_mbtrainValTrainCenterD2cSenderState),
    .dbg_mbtrainValTrainCenterD2cReceiverState                                (mbTrainFsm_dbg_mbtrainValTrainCenterD2cReceiverState),
    .dbg_mbtrainValTrainCenterSweepState                                      (mbTrainFsm_dbg_mbtrainValTrainCenterSweepState),
    .dbg_mbtrainValTrainVrefLocalState                                        (mbTrainFsm_dbg_mbtrainValTrainVrefLocalState),
    .dbg_mbtrainValTrainVrefRemoteState                                       (mbTrainFsm_dbg_mbtrainValTrainVrefRemoteState),
    .dbg_mbtrainValTrainVrefSweepState                                        (mbTrainFsm_dbg_mbtrainValTrainVrefSweepState),
    .dbg_mbtrainValTrainVrefPointInitiatorState                               (mbTrainFsm_dbg_mbtrainValTrainVrefPointInitiatorState),
    .dbg_mbtrainValTrainVrefPointResponderState                               (mbTrainFsm_dbg_mbtrainValTrainVrefPointResponderState),
    .dbg_mbtrainDataTrainCenter1SenderState                                   (mbTrainFsm_dbg_mbtrainDataTrainCenter1SenderState),
    .dbg_mbtrainDataTrainCenter1ReceiverState                                 (mbTrainFsm_dbg_mbtrainDataTrainCenter1ReceiverState),
    .dbg_mbtrainDataTrainCenter1D2cSenderState                                (mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cSenderState),
    .dbg_mbtrainDataTrainCenter1D2cReceiverState                              (mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cReceiverState),
    .dbg_mbtrainDataTrainCenter1SweepState                                    (mbTrainFsm_dbg_mbtrainDataTrainCenter1SweepState),
    .dbg_mbtrainDataTrainVrefLocalState                                       (mbTrainFsm_dbg_mbtrainDataTrainVrefLocalState),
    .dbg_mbtrainDataTrainVrefRemoteState                                      (mbTrainFsm_dbg_mbtrainDataTrainVrefRemoteState),
    .dbg_mbtrainDataTrainVrefSweepState                                       (mbTrainFsm_dbg_mbtrainDataTrainVrefSweepState),
    .dbg_mbtrainDataTrainVrefPointInitiatorState                              (mbTrainFsm_dbg_mbtrainDataTrainVrefPointInitiatorState),
    .dbg_mbtrainDataTrainVrefPointResponderState                              (mbTrainFsm_dbg_mbtrainDataTrainVrefPointResponderState),
    .dbg_mbtrainRxDeskewLocalState                                            (mbTrainFsm_dbg_mbtrainRxDeskewLocalState),
    .dbg_mbtrainRxDeskewRemoteState                                           (mbTrainFsm_dbg_mbtrainRxDeskewRemoteState),
    .dbg_mbtrainRxDeskewSweepState                                            (mbTrainFsm_dbg_mbtrainRxDeskewSweepState),
    .dbg_mbtrainRxDeskewPointInitiatorState                                   (mbTrainFsm_dbg_mbtrainRxDeskewPointInitiatorState),
    .dbg_mbtrainRxDeskewPointResponderState                                   (mbTrainFsm_dbg_mbtrainRxDeskewPointResponderState),
    .dbg_mbtrainDataTrainCenter2SenderState                                   (mbTrainFsm_dbg_mbtrainDataTrainCenter2SenderState),
    .dbg_mbtrainDataTrainCenter2ReceiverState                                 (mbTrainFsm_dbg_mbtrainDataTrainCenter2ReceiverState),
    .dbg_mbtrainDataTrainCenter2D2cSenderState                                (mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cSenderState),
    .dbg_mbtrainDataTrainCenter2D2cReceiverState                              (mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cReceiverState),
    .dbg_mbtrainDataTrainCenter2SweepState                                    (mbTrainFsm_dbg_mbtrainDataTrainCenter2SweepState),
    .dbg_mbtrainLinkSpeedSenderState                                          (mbTrainFsm_dbg_mbtrainLinkSpeedSenderState),
    .dbg_mbtrainLinkSpeedReceiverState                                        (mbTrainFsm_dbg_mbtrainLinkSpeedReceiverState),
    .dbg_mbtrainLinkSpeedD2cSenderState                                       (mbTrainFsm_dbg_mbtrainLinkSpeedD2cSenderState),
    .dbg_mbtrainLinkSpeedD2cReceiverState                                     (mbTrainFsm_dbg_mbtrainLinkSpeedD2cReceiverState),
    .lastErrorCount                                                           (mbTrainFsm_lastErrorCount),
    .retryCount                                                               (mbTrainFsm_retryCount)
  );

  always_comb begin
    state = stateReg;
    flagToAnalog_linkInit_resetLfsrScrambler = (stateReg == LTState_LINKINIT);
    sb_tx_valid = 1'b0;
    sb_tx_din = 128'b0;
    if (mbInitActive) begin
      sb_tx_valid = mbInitFsm_sb_tx_valid &&
                    ((mbInitFsm_substate != 3'd0) || sb_tx_ready);
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
    // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
    dbg_mbinitSubstate = mbInitFsm_substate;
    dbg_mbinitParamSenderState = mbInitFsm_dbg_mbinitParamSenderState;
    dbg_mbinitParamReceiverState = mbInitFsm_dbg_mbinitParamReceiverState;
    dbg_mbinitCalSenderState = mbInitFsm_dbg_mbinitCalSenderState;
    dbg_mbinitCalReceiverState = mbInitFsm_dbg_mbinitCalReceiverState;
    dbg_mbinitRepairClkSenderState = mbInitFsm_dbg_mbinitRepairClkSenderState;
    dbg_mbinitRepairClkReceiverState = mbInitFsm_dbg_mbinitRepairClkReceiverState;
    dbg_mbinitRepairValSenderState = mbInitFsm_dbg_mbinitRepairValSenderState;
    dbg_mbinitRepairValReceiverState = mbInitFsm_dbg_mbinitRepairValReceiverState;
    dbg_mbinitReversalMbSenderState = mbInitFsm_dbg_mbinitReversalMbSenderState;
    dbg_mbinitReversalMbReceiverState = mbInitFsm_dbg_mbinitReversalMbReceiverState;
    dbg_mbinitRepairMbSenderState = mbInitFsm_dbg_mbinitRepairMbSenderState;
    dbg_mbinitRepairMbReceiverState = mbInitFsm_dbg_mbinitRepairMbReceiverState;
    dbg_mbinitReversalMbReceivedSuccessCount = mbInitFsm_dbg_mbinitReversalMbReceivedSuccessCount;
    dbg_mbtrainState = mbTrainFsm_state;
    // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
    dbg_mbtrainActiveSubstate = mbTrainFsm_activeSubstate;
    dbg_mbtrainValVrefLocalState = mbTrainFsm_dbg_mbtrainValVrefLocalState;
    dbg_mbtrainValVrefRemoteState = mbTrainFsm_dbg_mbtrainValVrefRemoteState;
    dbg_mbtrainValVrefSweepState = mbTrainFsm_dbg_mbtrainValVrefSweepState;
    dbg_mbtrainValVrefPointInitiatorState = mbTrainFsm_dbg_mbtrainValVrefPointInitiatorState;
    dbg_mbtrainValVrefPointResponderState = mbTrainFsm_dbg_mbtrainValVrefPointResponderState;
    dbg_mbtrainDataVrefLocalState = mbTrainFsm_dbg_mbtrainDataVrefLocalState;
    dbg_mbtrainDataVrefRemoteState = mbTrainFsm_dbg_mbtrainDataVrefRemoteState;
    dbg_mbtrainDataVrefSweepState = mbTrainFsm_dbg_mbtrainDataVrefSweepState;
    dbg_mbtrainDataVrefPointInitiatorState = mbTrainFsm_dbg_mbtrainDataVrefPointInitiatorState;
    dbg_mbtrainDataVrefPointResponderState = mbTrainFsm_dbg_mbtrainDataVrefPointResponderState;
    dbg_mbtrainSpeedIdleSenderState = mbTrainFsm_dbg_mbtrainSpeedIdleSenderState;
    dbg_mbtrainSpeedIdleReceiverState = mbTrainFsm_dbg_mbtrainSpeedIdleReceiverState;
    dbg_mbtrainTxSelfCalSenderState = mbTrainFsm_dbg_mbtrainTxSelfCalSenderState;
    dbg_mbtrainTxSelfCalReceiverState = mbTrainFsm_dbg_mbtrainTxSelfCalReceiverState;
    dbg_mbtrainRxClkCalSenderState = mbTrainFsm_dbg_mbtrainRxClkCalSenderState;
    dbg_mbtrainRxClkCalReceiverState = mbTrainFsm_dbg_mbtrainRxClkCalReceiverState;
    dbg_mbtrainValTrainCenterSenderState = mbTrainFsm_dbg_mbtrainValTrainCenterSenderState;
    dbg_mbtrainValTrainCenterReceiverState = mbTrainFsm_dbg_mbtrainValTrainCenterReceiverState;
    dbg_mbtrainValTrainCenterD2cSenderState = mbTrainFsm_dbg_mbtrainValTrainCenterD2cSenderState;
    dbg_mbtrainValTrainCenterD2cReceiverState = mbTrainFsm_dbg_mbtrainValTrainCenterD2cReceiverState;
    dbg_mbtrainValTrainCenterSweepState = mbTrainFsm_dbg_mbtrainValTrainCenterSweepState;
    dbg_mbtrainValTrainVrefLocalState = mbTrainFsm_dbg_mbtrainValTrainVrefLocalState;
    dbg_mbtrainValTrainVrefRemoteState = mbTrainFsm_dbg_mbtrainValTrainVrefRemoteState;
    dbg_mbtrainValTrainVrefSweepState = mbTrainFsm_dbg_mbtrainValTrainVrefSweepState;
    dbg_mbtrainValTrainVrefPointInitiatorState = mbTrainFsm_dbg_mbtrainValTrainVrefPointInitiatorState;
    dbg_mbtrainValTrainVrefPointResponderState = mbTrainFsm_dbg_mbtrainValTrainVrefPointResponderState;
    dbg_mbtrainDataTrainCenter1SenderState = mbTrainFsm_dbg_mbtrainDataTrainCenter1SenderState;
    dbg_mbtrainDataTrainCenter1ReceiverState = mbTrainFsm_dbg_mbtrainDataTrainCenter1ReceiverState;
    dbg_mbtrainDataTrainCenter1D2cSenderState = mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cSenderState;
    dbg_mbtrainDataTrainCenter1D2cReceiverState = mbTrainFsm_dbg_mbtrainDataTrainCenter1D2cReceiverState;
    dbg_mbtrainDataTrainCenter1SweepState = mbTrainFsm_dbg_mbtrainDataTrainCenter1SweepState;
    dbg_mbtrainDataTrainVrefLocalState = mbTrainFsm_dbg_mbtrainDataTrainVrefLocalState;
    dbg_mbtrainDataTrainVrefRemoteState = mbTrainFsm_dbg_mbtrainDataTrainVrefRemoteState;
    dbg_mbtrainDataTrainVrefSweepState = mbTrainFsm_dbg_mbtrainDataTrainVrefSweepState;
    dbg_mbtrainDataTrainVrefPointInitiatorState = mbTrainFsm_dbg_mbtrainDataTrainVrefPointInitiatorState;
    dbg_mbtrainDataTrainVrefPointResponderState = mbTrainFsm_dbg_mbtrainDataTrainVrefPointResponderState;
    dbg_mbtrainRxDeskewLocalState = mbTrainFsm_dbg_mbtrainRxDeskewLocalState;
    dbg_mbtrainRxDeskewRemoteState = mbTrainFsm_dbg_mbtrainRxDeskewRemoteState;
    dbg_mbtrainRxDeskewSweepState = mbTrainFsm_dbg_mbtrainRxDeskewSweepState;
    dbg_mbtrainRxDeskewPointInitiatorState = mbTrainFsm_dbg_mbtrainRxDeskewPointInitiatorState;
    dbg_mbtrainRxDeskewPointResponderState = mbTrainFsm_dbg_mbtrainRxDeskewPointResponderState;
    dbg_mbtrainDataTrainCenter2SenderState = mbTrainFsm_dbg_mbtrainDataTrainCenter2SenderState;
    dbg_mbtrainDataTrainCenter2ReceiverState = mbTrainFsm_dbg_mbtrainDataTrainCenter2ReceiverState;
    dbg_mbtrainDataTrainCenter2D2cSenderState = mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cSenderState;
    dbg_mbtrainDataTrainCenter2D2cReceiverState = mbTrainFsm_dbg_mbtrainDataTrainCenter2D2cReceiverState;
    dbg_mbtrainDataTrainCenter2SweepState = mbTrainFsm_dbg_mbtrainDataTrainCenter2SweepState;
    dbg_mbtrainLinkSpeedSenderState = mbTrainFsm_dbg_mbtrainLinkSpeedSenderState;
    dbg_mbtrainLinkSpeedReceiverState = mbTrainFsm_dbg_mbtrainLinkSpeedReceiverState;
    dbg_mbtrainLinkSpeedD2cSenderState = mbTrainFsm_dbg_mbtrainLinkSpeedD2cSenderState;
    dbg_mbtrainLinkSpeedD2cReceiverState = mbTrainFsm_dbg_mbtrainLinkSpeedD2cReceiverState;
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
    flagToAnalog_d2cSender_sendValTrainPattern = mbTrainFsm_flagToAnalog_d2cSender_sendValTrainPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = mbTrainFsm_flagToAnalog_d2cSender_resetLocalScrambler;
    flagToAnalog_d2cSender_applyTxClockPhase = mbTrainFsm_flagToAnalog_d2cSender_applyTxClockPhase;
    flagToAnalog_d2cSender_txClockPhaseCode = mbTrainFsm_flagToAnalog_d2cSender_txClockPhaseCode;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = mbTrainFsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = mbTrainFsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
    flagToAnalog_d2cReceiver_comparisonMode = mbTrainFsm_flagToAnalog_d2cReceiver_comparisonMode;
    flagToAnalog_d2cReceiver_iterationCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_iterationCountSettings;
    flagToAnalog_d2cReceiver_idleCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_idleCountSettings;
    flagToAnalog_d2cReceiver_burstCountSettings = mbTrainFsm_flagToAnalog_d2cReceiver_burstCountSettings;
    flagToAnalog_d2cReceiver_patternMode = mbTrainFsm_flagToAnalog_d2cReceiver_patternMode;
    flagToAnalog_d2cReceiver_clockPhaseControl = mbTrainFsm_flagToAnalog_d2cReceiver_clockPhaseControl;
    flagToAnalog_d2cReceiver_validPattern = mbTrainFsm_flagToAnalog_d2cReceiver_validPattern;
    flagToAnalog_d2cReceiver_dataPattern = mbTrainFsm_flagToAnalog_d2cReceiver_dataPattern;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = mbTrainFsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    flagToAnalog_d2cSender_sendLfsrPattern = mbTrainFsm_flagToAnalog_d2cSender_sendLfsrPattern;
    flagToAnalog_d2cSender_applyTxLaneDeskew = mbTrainFsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
    flagToAnalog_d2cSender_txLaneDeskewCodes = mbTrainFsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
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
    flagToLtsm_linkSpeed_phyInRetrain = mbTrainFsm_flagToLtsm_linkSpeed_phyInRetrain;
    flagToAnalog_linkSpeed_speedCode = mbTrainFsm_flagToAnalog_linkSpeed_speedCode;
    flagToAnalog_linkSpeed_applySpeed = mbTrainFsm_flagToAnalog_linkSpeed_applySpeed;
    flagToAnalog_linkSpeed_electricalIdle = (stateReg == LTState_TRAIN_ERROR) ||
      mbTrainFsm_flagToAnalog_linkSpeed_electricalIdle;
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
      flagSbinitOorSuccessSeen <= 1'b0;
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

        if (sb_rx_dout == SBINIT_OOR_SUCCESS)
          flagSbinitOorSuccessSeen <= 1'b1;
        if (sb_rx_dout == SBINIT_DONE_REQ)
          flagSbinitReceivedDoneReq <= 1'b1;
        if (sb_rx_dout == SBINIT_DONE_RESP)
          flagSbinitReceivedDoneResp <= 1'b1;
      end

      unique case (stateReg)
        LTState_RESET: begin
          flagSbinitFirstClkPatternSeen <= 1'b0;
          flagSbinitSecondClkPatternSeen <= 1'b0;
          flagSbinitOorSuccessSeen <= 1'b0;
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
          if (flagSbinitOorSuccessSeen)
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
