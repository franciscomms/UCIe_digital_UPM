// SystemVerilog translation of MBTrainFSM.scala.
`default_nettype none

module MBTrainFSM #(
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
  parameter bit dataTrainVrefEnable = 1'b1,
  parameter bit rxDeskewEnable =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE,
  parameter int unsigned rxDeskewValueCount =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
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
  input wire logic           start,
  output var logic           busy,
  output var logic           done,
  output var logic           trainError,
  input wire logic           sb_tx_ready,
  output var logic           sb_tx_valid,
  output var logic [127:0]   sb_tx_din,
  input wire logic           sb_rx_valid,
  input wire logic [127:0]   sb_rx_dout,
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
  input wire logic [15:0]    flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  output var logic [3:0]     state,
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  output var logic [11:0]    activeSubstate,
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
  output var logic [15:0]    lastErrorCount,
  output var logic [15:0]    retryCount
);
  typedef enum logic [3:0] {
    State_IDLE = 4'h0,
    State_VALVREF = 4'h1,
    State_DATAVREF = 4'h2,
    State_SPEEDIDLE = 4'h3,
    State_TXSELFCAL = 4'h4,
    State_RXCLKCAL = 4'h5,
    State_VALTRAINCENTER = 4'h6,
    State_VALTRAINVREF = 4'h7,
    State_DATATRAINCENTER1 = 4'h8,
    State_DATATRAINVREF = 4'h9,
    State_RXDESKEW = 4'hA,
    State_DATATRAINCENTER2 = 4'hB,
    State_LINKSPEED = 4'hC,
    State_REPAIR = 4'hD,
    State_COMPLETE = 4'hE,
    State_ERROR = 4'hF
  } State_t;

  (* keep = "true" *) State_t stateReg;
  (* keep = "true" *) logic errorReg;

  // Private sub-FSM interfaces: only the selected state owns the PHY ports.
  logic stage_flagToAnalog_valVref_sendPattern;
  logic stage_flagFromAnalog_valVref_detectedValPattern;
  logic stage_flagFromAnalog_valVref_finishedPattern;
  logic stage_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] stage_flagToAnalog_valVref_rxVrefCode;
  logic stage_flagFromAnalog_valVref_rxVrefApplied;
  logic stage_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_valVref_comparisonMode;
  logic [15:0] stage_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] stage_flagToAnalog_valVref_burstCountSettings;
  logic stage_flagToAnalog_valVref_patternMode;
  logic [3:0] stage_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_valVref_validPattern;
  logic [2:0] stage_flagToAnalog_valVref_dataPattern;
  logic stage_flagToAnalog_valVref_clearComparisonErrors;
  logic stage_flagToAnalog_valVref_resetLocalTxScrambler;
  logic stage_flagToAnalog_dataVref_sendPattern;
  logic [dataLaneCount-1:0] stage_flagFromAnalog_dataVref_detectedDataPattern;
  logic stage_flagFromAnalog_dataVref_finishedPattern;
  logic stage_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] stage_flagToAnalog_dataVref_rxVrefCodes;
  logic stage_flagFromAnalog_dataVref_rxVrefApplied;
  logic stage_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] stage_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] stage_flagToAnalog_dataVref_burstCountSettings;
  logic stage_flagToAnalog_dataVref_patternMode;
  logic [3:0] stage_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_dataVref_validPattern;
  logic [2:0] stage_flagToAnalog_dataVref_dataPattern;
  logic stage_flagToAnalog_dataVref_clearComparisonErrors;
  logic stage_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic stage_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
  logic stage_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent;
  logic stage_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
  logic stage_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] stage_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
  logic stage_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied;
  logic stage_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
  logic [15:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
  logic stage_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
  logic [3:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
  logic [2:0] stage_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
  logic stage_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
  logic [15:0] stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo;
  logic [63:0] stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload;
  logic stage_flagToAnalog_valTrainVref_sendPattern;
  logic stage_flagFromAnalog_valTrainVref_detectedValPattern;
  logic stage_flagFromAnalog_valTrainVref_finishedPattern;
  logic stage_flagToAnalog_valTrainVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] stage_flagToAnalog_valTrainVref_rxVrefCode;
  logic stage_flagFromAnalog_valTrainVref_rxVrefApplied;
  logic stage_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_valTrainVref_comparisonMode;
  logic [15:0] stage_flagToAnalog_valTrainVref_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_valTrainVref_idleCountSettings;
  logic [15:0] stage_flagToAnalog_valTrainVref_burstCountSettings;
  logic stage_flagToAnalog_valTrainVref_patternMode;
  logic [3:0] stage_flagToAnalog_valTrainVref_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_valTrainVref_validPattern;
  logic [2:0] stage_flagToAnalog_valTrainVref_dataPattern;
  logic stage_flagToAnalog_valTrainVref_clearComparisonErrors;
  logic stage_flagToAnalog_valTrainVref_resetLocalTxScrambler;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
  logic stage_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] stage_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
  logic stage_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] stage_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
  logic stage_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
  logic [3:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
  logic [2:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
  logic [15:0] stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo;
  logic [63:0] stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload;
  logic stage_flagToAnalog_dataTrainVref_sendPattern;
  logic [dataLaneCount-1:0] stage_flagFromAnalog_dataTrainVref_detectedDataPattern;
  logic stage_flagFromAnalog_dataTrainVref_finishedPattern;
  logic stage_flagToAnalog_dataTrainVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] stage_flagToAnalog_dataTrainVref_rxVrefCodes;
  logic stage_flagFromAnalog_dataTrainVref_rxVrefApplied;
  logic stage_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_dataTrainVref_comparisonMode;
  logic [15:0] stage_flagToAnalog_dataTrainVref_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_dataTrainVref_idleCountSettings;
  logic [15:0] stage_flagToAnalog_dataTrainVref_burstCountSettings;
  logic stage_flagToAnalog_dataTrainVref_patternMode;
  logic [3:0] stage_flagToAnalog_dataTrainVref_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_dataTrainVref_validPattern;
  logic [2:0] stage_flagToAnalog_dataTrainVref_dataPattern;
  logic stage_flagToAnalog_dataTrainVref_clearComparisonErrors;
  logic stage_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
  logic stage_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
  logic stage_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] stage_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
  logic stage_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
  logic [3:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
  logic [2:0] stage_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
  logic stage_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
  logic [15:0] stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo;
  logic [63:0] stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload;
  logic stage_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
  logic stage_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent;
  logic stage_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
  logic stage_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
  logic [15:0] stage_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
  logic stage_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
  logic [15:0] stage_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
  logic [15:0] stage_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
  logic stage_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
  logic [3:0] stage_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
  logic [2:0] stage_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
  logic [2:0] stage_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
  logic stage_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  logic [15:0] stage_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful;
  assign stage_flagFromAnalog_valVref_detectedValPattern =
    (reset_n && (stateReg == State_VALVREF)) ? flagFromAnalog_valVref_detectedValPattern : '0;
  assign stage_flagFromAnalog_valVref_finishedPattern =
    (reset_n && (stateReg == State_VALVREF)) ? flagFromAnalog_valVref_finishedPattern : '0;
  assign stage_flagFromAnalog_valVref_rxVrefApplied =
    (reset_n && (stateReg == State_VALVREF)) ? flagFromAnalog_valVref_rxVrefApplied : '0;
  assign stage_flagFromAnalog_dataVref_detectedDataPattern =
    (reset_n && (stateReg == State_DATAVREF)) ? flagFromAnalog_dataVref_detectedDataPattern : '0;
  assign stage_flagFromAnalog_dataVref_finishedPattern =
    (reset_n && (stateReg == State_DATAVREF)) ? flagFromAnalog_dataVref_finishedPattern : '0;
  assign stage_flagFromAnalog_dataVref_rxVrefApplied =
    (reset_n && (stateReg == State_DATAVREF)) ? flagFromAnalog_dataVref_rxVrefApplied : '0;
  assign stage_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent =
    (reset_n && (stateReg == State_VALTRAINCENTER)) ? flagFromAnalog_d2cSender_valTrainPatternSent : '0;
  assign stage_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied =
    (reset_n && (stateReg == State_VALTRAINCENTER)) ? flagFromAnalog_d2cSender_txClockPhaseApplied : '0;
  assign stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo =
    (reset_n && (stateReg == State_VALTRAINCENTER)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo : '0;
  assign stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload =
    (reset_n && (stateReg == State_VALTRAINCENTER)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsPayload : '0;
  assign stage_flagFromAnalog_valTrainVref_detectedValPattern =
    (reset_n && (stateReg == State_VALTRAINVREF)) ? flagFromAnalog_valVref_detectedValPattern : '0;
  assign stage_flagFromAnalog_valTrainVref_finishedPattern =
    (reset_n && (stateReg == State_VALTRAINVREF)) ? flagFromAnalog_valVref_finishedPattern : '0;
  assign stage_flagFromAnalog_valTrainVref_rxVrefApplied =
    (reset_n && (stateReg == State_VALTRAINVREF)) ? flagFromAnalog_valVref_rxVrefApplied : '0;
  assign stage_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent =
    (reset_n && (stateReg == State_DATATRAINCENTER1)) ? flagFromAnalog_d2cSender_lfsrPatternSent : '0;
  assign stage_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied =
    (reset_n && (stateReg == State_DATATRAINCENTER1)) ? flagFromAnalog_d2cSender_txClockPhaseApplied : '0;
  assign stage_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied =
    (reset_n && (stateReg == State_DATATRAINCENTER1)) ? flagFromAnalog_d2cSender_txLaneDeskewApplied : '0;
  assign stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo =
    (reset_n && (stateReg == State_DATATRAINCENTER1)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo : '0;
  assign stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload =
    (reset_n && (stateReg == State_DATATRAINCENTER1)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsPayload : '0;
  assign stage_flagFromAnalog_dataTrainVref_detectedDataPattern =
    (reset_n && (stateReg == State_DATATRAINVREF)) ? flagFromAnalog_dataVref_detectedDataPattern : '0;
  assign stage_flagFromAnalog_dataTrainVref_finishedPattern =
    (reset_n && (stateReg == State_DATATRAINVREF)) ? flagFromAnalog_dataVref_finishedPattern : '0;
  assign stage_flagFromAnalog_dataTrainVref_rxVrefApplied =
    (reset_n && (stateReg == State_DATATRAINVREF)) ? flagFromAnalog_dataVref_rxVrefApplied : '0;
  assign stage_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent =
    (reset_n && (stateReg == State_DATATRAINCENTER2)) ? flagFromAnalog_d2cSender_lfsrPatternSent : '0;
  assign stage_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied =
    (reset_n && (stateReg == State_DATATRAINCENTER2)) ? flagFromAnalog_d2cSender_txClockPhaseApplied : '0;
  assign stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo =
    (reset_n && (stateReg == State_DATATRAINCENTER2)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo : '0;
  assign stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload =
    (reset_n && (stateReg == State_DATATRAINCENTER2)) ? flagFromAnalog_d2cReceiver_txInitD2CResultsPayload : '0;
  assign stage_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent =
    (reset_n && (stateReg == State_LINKSPEED)) ? flagFromAnalog_d2cSender_lfsrPatternSent : '0;
  assign stage_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful =
    (reset_n && (stateReg == State_LINKSPEED)) ? flagFromAnalog_d2cReceiver_laneComparisonSuccessful : '0;

  // Shared analog controls. Data/configuration buses are valid with their
  // corresponding apply/configure/send request; the PHY retains applied values.
  // No command is issued in unrelated states or during reset. Center2 has no
  // TX lane-deskew engine: Center1 alone owns applyTxLaneDeskew.
  always_comb begin
    flagToAnalog_valVref_sendPattern = '0;
    flagToAnalog_valVref_applyRxVref = '0;
    flagToAnalog_valVref_rxVrefCode = '0;
    flagToAnalog_valVref_configureRxInitD2CPointTest = '0;
    flagToAnalog_valVref_maximumComparisonErrorThreshold = '0;
    flagToAnalog_valVref_comparisonMode = '0;
    flagToAnalog_valVref_iterationCountSettings = '0;
    flagToAnalog_valVref_idleCountSettings = '0;
    flagToAnalog_valVref_burstCountSettings = '0;
    flagToAnalog_valVref_patternMode = '0;
    flagToAnalog_valVref_clockPhaseControl = '0;
    flagToAnalog_valVref_validPattern = '0;
    flagToAnalog_valVref_dataPattern = '0;
    flagToAnalog_valVref_clearComparisonErrors = '0;
    flagToAnalog_valVref_resetLocalTxScrambler = '0;
    flagToAnalog_dataVref_sendPattern = '0;
    flagToAnalog_dataVref_applyRxVref = '0;
    flagToAnalog_dataVref_rxVrefCodes = '0;
    flagToAnalog_dataVref_configureRxInitD2CPointTest = '0;
    flagToAnalog_dataVref_maximumComparisonErrorThreshold = '0;
    flagToAnalog_dataVref_comparisonMode = '0;
    flagToAnalog_dataVref_iterationCountSettings = '0;
    flagToAnalog_dataVref_idleCountSettings = '0;
    flagToAnalog_dataVref_burstCountSettings = '0;
    flagToAnalog_dataVref_patternMode = '0;
    flagToAnalog_dataVref_clockPhaseControl = '0;
    flagToAnalog_dataVref_validPattern = '0;
    flagToAnalog_dataVref_dataPattern = '0;
    flagToAnalog_dataVref_clearComparisonErrors = '0;
    flagToAnalog_dataVref_resetLocalTxScrambler = '0;
    flagToAnalog_d2cSender_sendValTrainPattern = '0;
    flagToAnalog_d2cSender_resetLocalScrambler = '0;
    flagToAnalog_d2cSender_applyTxClockPhase = '0;
    flagToAnalog_d2cSender_txClockPhaseCode = '0;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = '0;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = '0;
    flagToAnalog_d2cReceiver_comparisonMode = '0;
    flagToAnalog_d2cReceiver_iterationCountSettings = '0;
    flagToAnalog_d2cReceiver_idleCountSettings = '0;
    flagToAnalog_d2cReceiver_burstCountSettings = '0;
    flagToAnalog_d2cReceiver_patternMode = '0;
    flagToAnalog_d2cReceiver_clockPhaseControl = '0;
    flagToAnalog_d2cReceiver_validPattern = '0;
    flagToAnalog_d2cReceiver_dataPattern = '0;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = '0;
    flagToAnalog_d2cSender_sendLfsrPattern = '0;
    flagToAnalog_d2cSender_applyTxLaneDeskew = '0;
    flagToAnalog_d2cSender_txLaneDeskewCodes = '0;
    if (reset_n) begin
      case (stateReg)
        State_VALVREF: begin
          flagToAnalog_valVref_sendPattern = stage_flagToAnalog_valVref_sendPattern;
          flagToAnalog_valVref_applyRxVref = stage_flagToAnalog_valVref_applyRxVref;
          flagToAnalog_valVref_rxVrefCode = stage_flagToAnalog_valVref_rxVrefCode;
          flagToAnalog_valVref_configureRxInitD2CPointTest = stage_flagToAnalog_valVref_configureRxInitD2CPointTest;
          flagToAnalog_valVref_maximumComparisonErrorThreshold = stage_flagToAnalog_valVref_maximumComparisonErrorThreshold;
          flagToAnalog_valVref_comparisonMode = stage_flagToAnalog_valVref_comparisonMode;
          flagToAnalog_valVref_iterationCountSettings = stage_flagToAnalog_valVref_iterationCountSettings;
          flagToAnalog_valVref_idleCountSettings = stage_flagToAnalog_valVref_idleCountSettings;
          flagToAnalog_valVref_burstCountSettings = stage_flagToAnalog_valVref_burstCountSettings;
          flagToAnalog_valVref_patternMode = stage_flagToAnalog_valVref_patternMode;
          flagToAnalog_valVref_clockPhaseControl = stage_flagToAnalog_valVref_clockPhaseControl;
          flagToAnalog_valVref_validPattern = stage_flagToAnalog_valVref_validPattern;
          flagToAnalog_valVref_dataPattern = stage_flagToAnalog_valVref_dataPattern;
          flagToAnalog_valVref_clearComparisonErrors = stage_flagToAnalog_valVref_clearComparisonErrors;
          flagToAnalog_valVref_resetLocalTxScrambler = stage_flagToAnalog_valVref_resetLocalTxScrambler;
        end
        State_VALTRAINVREF: begin
          flagToAnalog_valVref_sendPattern = stage_flagToAnalog_valTrainVref_sendPattern;
          flagToAnalog_valVref_applyRxVref = stage_flagToAnalog_valTrainVref_applyRxVref;
          flagToAnalog_valVref_rxVrefCode = stage_flagToAnalog_valTrainVref_rxVrefCode;
          flagToAnalog_valVref_configureRxInitD2CPointTest = stage_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
          flagToAnalog_valVref_maximumComparisonErrorThreshold = stage_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
          flagToAnalog_valVref_comparisonMode = stage_flagToAnalog_valTrainVref_comparisonMode;
          flagToAnalog_valVref_iterationCountSettings = stage_flagToAnalog_valTrainVref_iterationCountSettings;
          flagToAnalog_valVref_idleCountSettings = stage_flagToAnalog_valTrainVref_idleCountSettings;
          flagToAnalog_valVref_burstCountSettings = stage_flagToAnalog_valTrainVref_burstCountSettings;
          flagToAnalog_valVref_patternMode = stage_flagToAnalog_valTrainVref_patternMode;
          flagToAnalog_valVref_clockPhaseControl = stage_flagToAnalog_valTrainVref_clockPhaseControl;
          flagToAnalog_valVref_validPattern = stage_flagToAnalog_valTrainVref_validPattern;
          flagToAnalog_valVref_dataPattern = stage_flagToAnalog_valTrainVref_dataPattern;
          flagToAnalog_valVref_clearComparisonErrors = stage_flagToAnalog_valTrainVref_clearComparisonErrors;
          flagToAnalog_valVref_resetLocalTxScrambler = stage_flagToAnalog_valTrainVref_resetLocalTxScrambler;
        end
        State_DATAVREF: begin
          flagToAnalog_dataVref_sendPattern = stage_flagToAnalog_dataVref_sendPattern;
          flagToAnalog_dataVref_applyRxVref = stage_flagToAnalog_dataVref_applyRxVref;
          flagToAnalog_dataVref_rxVrefCodes = stage_flagToAnalog_dataVref_rxVrefCodes;
          flagToAnalog_dataVref_configureRxInitD2CPointTest = stage_flagToAnalog_dataVref_configureRxInitD2CPointTest;
          flagToAnalog_dataVref_maximumComparisonErrorThreshold = stage_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
          flagToAnalog_dataVref_comparisonMode = stage_flagToAnalog_dataVref_comparisonMode;
          flagToAnalog_dataVref_iterationCountSettings = stage_flagToAnalog_dataVref_iterationCountSettings;
          flagToAnalog_dataVref_idleCountSettings = stage_flagToAnalog_dataVref_idleCountSettings;
          flagToAnalog_dataVref_burstCountSettings = stage_flagToAnalog_dataVref_burstCountSettings;
          flagToAnalog_dataVref_patternMode = stage_flagToAnalog_dataVref_patternMode;
          flagToAnalog_dataVref_clockPhaseControl = stage_flagToAnalog_dataVref_clockPhaseControl;
          flagToAnalog_dataVref_validPattern = stage_flagToAnalog_dataVref_validPattern;
          flagToAnalog_dataVref_dataPattern = stage_flagToAnalog_dataVref_dataPattern;
          flagToAnalog_dataVref_clearComparisonErrors = stage_flagToAnalog_dataVref_clearComparisonErrors;
          flagToAnalog_dataVref_resetLocalTxScrambler = stage_flagToAnalog_dataVref_resetLocalTxScrambler;
        end
        State_DATATRAINVREF: begin
          flagToAnalog_dataVref_sendPattern = stage_flagToAnalog_dataTrainVref_sendPattern;
          flagToAnalog_dataVref_applyRxVref = stage_flagToAnalog_dataTrainVref_applyRxVref;
          flagToAnalog_dataVref_rxVrefCodes = stage_flagToAnalog_dataTrainVref_rxVrefCodes;
          flagToAnalog_dataVref_configureRxInitD2CPointTest = stage_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
          flagToAnalog_dataVref_maximumComparisonErrorThreshold = stage_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
          flagToAnalog_dataVref_comparisonMode = stage_flagToAnalog_dataTrainVref_comparisonMode;
          flagToAnalog_dataVref_iterationCountSettings = stage_flagToAnalog_dataTrainVref_iterationCountSettings;
          flagToAnalog_dataVref_idleCountSettings = stage_flagToAnalog_dataTrainVref_idleCountSettings;
          flagToAnalog_dataVref_burstCountSettings = stage_flagToAnalog_dataTrainVref_burstCountSettings;
          flagToAnalog_dataVref_patternMode = stage_flagToAnalog_dataTrainVref_patternMode;
          flagToAnalog_dataVref_clockPhaseControl = stage_flagToAnalog_dataTrainVref_clockPhaseControl;
          flagToAnalog_dataVref_validPattern = stage_flagToAnalog_dataTrainVref_validPattern;
          flagToAnalog_dataVref_dataPattern = stage_flagToAnalog_dataTrainVref_dataPattern;
          flagToAnalog_dataVref_clearComparisonErrors = stage_flagToAnalog_dataTrainVref_clearComparisonErrors;
          flagToAnalog_dataVref_resetLocalTxScrambler = stage_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
        end
        State_VALTRAINCENTER: begin
          flagToAnalog_d2cSender_sendValTrainPattern = stage_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
          flagToAnalog_d2cSender_resetLocalScrambler = stage_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
          flagToAnalog_d2cSender_applyTxClockPhase = stage_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
          flagToAnalog_d2cSender_txClockPhaseCode = stage_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
          flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = stage_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
          flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = stage_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
          flagToAnalog_d2cReceiver_comparisonMode = stage_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
          flagToAnalog_d2cReceiver_iterationCountSettings = stage_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
          flagToAnalog_d2cReceiver_idleCountSettings = stage_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
          flagToAnalog_d2cReceiver_burstCountSettings = stage_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
          flagToAnalog_d2cReceiver_patternMode = stage_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
          flagToAnalog_d2cReceiver_clockPhaseControl = stage_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
          flagToAnalog_d2cReceiver_validPattern = stage_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
          flagToAnalog_d2cReceiver_dataPattern = stage_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
          flagToAnalog_d2cReceiver_resetLocalRxScrambler = stage_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
        end
        State_DATATRAINCENTER1: begin
          flagToAnalog_d2cSender_sendLfsrPattern = stage_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
          flagToAnalog_d2cSender_resetLocalScrambler = stage_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
          flagToAnalog_d2cSender_applyTxClockPhase = stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
          flagToAnalog_d2cSender_txClockPhaseCode = stage_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
          flagToAnalog_d2cSender_applyTxLaneDeskew = stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
          flagToAnalog_d2cSender_txLaneDeskewCodes = stage_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
          flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
          flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
          flagToAnalog_d2cReceiver_comparisonMode = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
          flagToAnalog_d2cReceiver_iterationCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
          flagToAnalog_d2cReceiver_idleCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
          flagToAnalog_d2cReceiver_burstCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
          flagToAnalog_d2cReceiver_patternMode = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
          flagToAnalog_d2cReceiver_clockPhaseControl = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
          flagToAnalog_d2cReceiver_validPattern = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
          flagToAnalog_d2cReceiver_dataPattern = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
          flagToAnalog_d2cReceiver_resetLocalRxScrambler = stage_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
        end
        State_DATATRAINCENTER2: begin
          flagToAnalog_d2cSender_sendLfsrPattern = stage_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
          flagToAnalog_d2cSender_resetLocalScrambler = stage_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
          flagToAnalog_d2cSender_applyTxClockPhase = stage_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
          flagToAnalog_d2cSender_txClockPhaseCode = stage_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
          flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
          flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
          flagToAnalog_d2cReceiver_comparisonMode = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
          flagToAnalog_d2cReceiver_iterationCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
          flagToAnalog_d2cReceiver_idleCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
          flagToAnalog_d2cReceiver_burstCountSettings = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
          flagToAnalog_d2cReceiver_patternMode = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
          flagToAnalog_d2cReceiver_clockPhaseControl = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
          flagToAnalog_d2cReceiver_validPattern = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
          flagToAnalog_d2cReceiver_dataPattern = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
          flagToAnalog_d2cReceiver_resetLocalRxScrambler = stage_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
        end
        State_LINKSPEED: begin
          flagToAnalog_d2cSender_sendLfsrPattern = stage_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
          flagToAnalog_d2cSender_resetLocalScrambler = stage_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
          flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = stage_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
          flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = stage_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
          flagToAnalog_d2cReceiver_comparisonMode = stage_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
          flagToAnalog_d2cReceiver_iterationCountSettings = stage_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
          flagToAnalog_d2cReceiver_idleCountSettings = stage_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
          flagToAnalog_d2cReceiver_burstCountSettings = stage_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
          flagToAnalog_d2cReceiver_patternMode = stage_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
          flagToAnalog_d2cReceiver_clockPhaseControl = stage_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
          flagToAnalog_d2cReceiver_validPattern = stage_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
          flagToAnalog_d2cReceiver_dataPattern = stage_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
          flagToAnalog_d2cReceiver_resetLocalRxScrambler = stage_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
        end
        default: begin end
      endcase
    end
  end


  logic valVref_busy;
  logic valVref_done;
  logic valVref_trainError;
  logic valVref_sb_tx_valid;
  logic [127:0] valVref_sb_tx_din;
  logic [3:0] valVref_dbg_localState;
  logic [2:0] valVref_dbg_remoteState;
  logic [3:0] valVref_dbg_sweepState;
  logic [3:0] valVref_dbg_pointInitiatorState;
  logic [3:0] valVref_dbg_pointResponderState;
  logic [15:0] valVref_lastErrorCount;
  logic [15:0] valVref_retryCount;
  logic [validVrefCodeWidth-1:0] valVref_selectedCode;
  logic [validVrefCodeWidth-1:0] valVref_leftCode;
  logic [validVrefCodeWidth-1:0] valVref_rightCode;
  logic dataVref_busy;
  logic dataVref_done;
  logic dataVref_trainError;
  logic dataVref_sb_tx_valid;
  logic [127:0] dataVref_sb_tx_din;
  logic [3:0] dataVref_dbg_localState;
  logic [2:0] dataVref_dbg_remoteState;
  logic [3:0] dataVref_dbg_sweepState;
  logic [3:0] dataVref_dbg_pointInitiatorState;
  logic [3:0] dataVref_dbg_pointResponderState;
  logic [15:0] dataVref_lastErrorCount;
  logic [15:0] dataVref_retryCount;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataVref_selectedCodes;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataVref_leftCodes;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataVref_rightCodes;
  logic speedIdle_busy;
  logic speedIdle_done;
  logic speedIdle_trainError;
  logic speedIdle_sb_tx_valid;
  logic [127:0] speedIdle_sb_tx_din;
  logic [1:0] speedIdle_dbg_senderState;
  logic [1:0] speedIdle_dbg_receiverState;
  logic txSelfCal_busy;
  logic txSelfCal_done;
  logic txSelfCal_trainError;
  logic txSelfCal_sb_tx_valid;
  logic [127:0] txSelfCal_sb_tx_din;
  logic [1:0] txSelfCal_dbg_senderState;
  logic [1:0] txSelfCal_dbg_receiverState;
  logic rxClkCal_busy;
  logic rxClkCal_done;
  logic rxClkCal_trainError;
  logic rxClkCal_sb_tx_valid;
  logic [127:0] rxClkCal_sb_tx_din;
  logic [2:0] rxClkCal_dbg_senderState;
  logic [2:0] rxClkCal_dbg_receiverState;
  logic valTrainCenter_busy;
  logic valTrainCenter_done;
  logic valTrainCenter_trainError;
  logic valTrainCenter_sb_tx_valid;
  logic [127:0] valTrainCenter_sb_tx_din;
  logic [3:0] valTrainCenter_dbg_senderState;
  logic [2:0] valTrainCenter_dbg_receiverState;
  logic [3:0] valTrainCenter_dbg_d2cSenderState;
  logic [3:0] valTrainCenter_dbg_d2cReceiverState;
  logic [3:0] valTrainCenter_dbg_sweepState;
  logic [15:0] valTrainCenter_lastErrorCount;
  logic [15:0] valTrainCenter_retryCount;
  logic valTrainVref_busy;
  logic valTrainVref_done;
  logic valTrainVref_trainError;
  logic valTrainVref_sb_tx_valid;
  logic [127:0] valTrainVref_sb_tx_din;
  logic [3:0] valTrainVref_dbg_localState;
  logic [2:0] valTrainVref_dbg_remoteState;
  logic [3:0] valTrainVref_dbg_sweepState;
  logic [3:0] valTrainVref_dbg_pointInitiatorState;
  logic [3:0] valTrainVref_dbg_pointResponderState;
  logic [15:0] valTrainVref_lastErrorCount;
  logic [15:0] valTrainVref_retryCount;
  logic [validVrefCodeWidth-1:0] valTrainVref_selectedCode;
  logic [validVrefCodeWidth-1:0] valTrainVref_leftCode;
  logic [validVrefCodeWidth-1:0] valTrainVref_rightCode;
  logic dataTrainCenter1_busy;
  logic dataTrainCenter1_done;
  logic dataTrainCenter1_trainError;
  logic dataTrainCenter1_sb_tx_valid;
  logic [127:0] dataTrainCenter1_sb_tx_din;
  logic [3:0] dataTrainCenter1_dbg_senderState;
  logic [2:0] dataTrainCenter1_dbg_receiverState;
  logic [3:0] dataTrainCenter1_dbg_d2cSenderState;
  logic [3:0] dataTrainCenter1_dbg_d2cReceiverState;
  logic [4:0] dataTrainCenter1_dbg_sweepState;
  logic [15:0] dataTrainCenter1_lastErrorCount;
  logic [15:0] dataTrainCenter1_retryCount;
  logic dataTrainVref_busy;
  logic dataTrainVref_done;
  logic dataTrainVref_trainError;
  logic dataTrainVref_sb_tx_valid;
  logic [127:0] dataTrainVref_sb_tx_din;
  logic [3:0] dataTrainVref_dbg_localState;
  logic [2:0] dataTrainVref_dbg_remoteState;
  logic [3:0] dataTrainVref_dbg_sweepState;
  logic [3:0] dataTrainVref_dbg_pointInitiatorState;
  logic [3:0] dataTrainVref_dbg_pointResponderState;
  logic [15:0] dataTrainVref_lastErrorCount;
  logic [15:0] dataTrainVref_retryCount;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataTrainVref_selectedCodes;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataTrainVref_leftCodes;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] dataTrainVref_rightCodes;
  logic rxDeskew_busy;
  logic rxDeskew_done;
  logic rxDeskew_trainError;
  logic rxDeskew_sb_tx_valid;
  logic [127:0] rxDeskew_sb_tx_din;
  logic [3:0] rxDeskew_dbg_localState;
  logic [2:0] rxDeskew_dbg_remoteState;
  logic [3:0] rxDeskew_dbg_sweepState;
  logic [3:0] rxDeskew_dbg_pointInitiatorState;
  logic [3:0] rxDeskew_dbg_pointResponderState;
  logic [15:0] rxDeskew_lastErrorCount;
  logic [15:0] rxDeskew_retryCount;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] rxDeskew_selectedCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] rxDeskew_leftCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] rxDeskew_rightCodes;
  logic dataTrainCenter2_busy;
  logic dataTrainCenter2_done;
  logic dataTrainCenter2_trainError;
  logic dataTrainCenter2_sb_tx_valid;
  logic [127:0] dataTrainCenter2_sb_tx_din;
  logic [3:0] dataTrainCenter2_dbg_senderState;
  logic [2:0] dataTrainCenter2_dbg_receiverState;
  logic [3:0] dataTrainCenter2_dbg_d2cSenderState;
  logic [3:0] dataTrainCenter2_dbg_d2cReceiverState;
  logic [3:0] dataTrainCenter2_dbg_sweepState;
  logic [15:0] dataTrainCenter2_lastErrorCount;
  logic [15:0] dataTrainCenter2_retryCount;
  logic linkSpeed_busy;
  logic linkSpeed_done;
  logic linkSpeed_trainError;
  logic linkSpeed_sb_tx_valid;
  logic [127:0] linkSpeed_sb_tx_din;
  logic [3:0] linkSpeed_dbg_senderState;
  logic [2:0] linkSpeed_dbg_receiverState;
  logic [3:0] linkSpeed_dbg_d2cSenderState;
  logic [3:0] linkSpeed_dbg_d2cReceiverState;
  logic [15:0] linkSpeed_lastErrorCount;
  logic [15:0] linkSpeed_retryCount;

  MBTrainValVrefFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .validVrefValueCount(validVrefValueCount),
    .validVrefCodeWidth(validVrefCodeWidth),
    .validVrefMinimumMillivolts(validVrefMinimumMillivolts),
    .validVrefMaximumMillivolts(validVrefMaximumMillivolts),
    .validVrefMaximumComparisonErrorThreshold(validVrefMaximumComparisonErrorThreshold),
    .validVrefMinPassingWindowValues(validVrefMinPassingWindowValues),
    .validVrefMaxTrainingRetries(validVrefMaxTrainingRetries)
  ) valVref (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_VALVREF),
    .busy(valVref_busy),
    .done(valVref_done),
    .trainError(valVref_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_VALVREF)),
    .sb_tx_valid(valVref_sb_tx_valid),
    .sb_tx_din(valVref_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_VALVREF)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_valRefApplyRxVref(stage_flagToAnalog_valVref_applyRxVref),
    .flagToAnalog_valRefRxVrefCode(stage_flagToAnalog_valVref_rxVrefCode),
    .flagFromAnalog_valRefRxVrefApplied(stage_flagFromAnalog_valVref_rxVrefApplied),
    .flagToAnalog_valRefConfigureRxInitD2CPointTest(stage_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .flagToAnalog_valRefMaximumComparisonErrorThreshold(stage_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valRefComparisonMode(stage_flagToAnalog_valVref_comparisonMode),
    .flagToAnalog_valRefIterationCountSettings(stage_flagToAnalog_valVref_iterationCountSettings),
    .flagToAnalog_valRefIdleCountSettings(stage_flagToAnalog_valVref_idleCountSettings),
    .flagToAnalog_valRefBurstCountSettings(stage_flagToAnalog_valVref_burstCountSettings),
    .flagToAnalog_valRefPatternMode(stage_flagToAnalog_valVref_patternMode),
    .flagToAnalog_valRefClockPhaseControl(stage_flagToAnalog_valVref_clockPhaseControl),
    .flagToAnalog_valRefValidPattern(stage_flagToAnalog_valVref_validPattern),
    .flagToAnalog_valRefDataPattern(stage_flagToAnalog_valVref_dataPattern),
    .flagToAnalog_valRefClearComparisonErrors(stage_flagToAnalog_valVref_clearComparisonErrors),
    .flagFromAnalog_valRefDetectedValPattern(stage_flagFromAnalog_valVref_detectedValPattern),
    .flagToAnalog_valRefSendPattern(stage_flagToAnalog_valVref_sendPattern),
    .flagFromAnalog_valRefFinishedPattern(stage_flagFromAnalog_valVref_finishedPattern),
    .flagToAnalog_valRefResetLocalTxScrambler(stage_flagToAnalog_valVref_resetLocalTxScrambler),
    .dbg_localState(valVref_dbg_localState),
    .dbg_remoteState(valVref_dbg_remoteState),
    .dbg_sweepState(valVref_dbg_sweepState),
    .dbg_pointInitiatorState(valVref_dbg_pointInitiatorState),
    .dbg_pointResponderState(valVref_dbg_pointResponderState),
    .lastErrorCount(valVref_lastErrorCount),
    .retryCount(valVref_retryCount),
    .selectedVrefCode(valVref_selectedCode),
    .validWindowLeftCode(valVref_leftCode),
    .validWindowRightCode(valVref_rightCode)
  );
  MBTrainDataVrefFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .dataLaneCount(dataLaneCount),
    .activeDataLaneMask(activeDataLaneMask),
    .dataVrefValueCount(dataVrefValueCount),
    .dataVrefCodeWidth(dataVrefCodeWidth),
    .dataVrefMinimumMillivolts(dataVrefMinimumMillivolts),
    .dataVrefMaximumMillivolts(dataVrefMaximumMillivolts),
    .dataVrefMaximumComparisonErrorThreshold(
      dataVrefMaximumComparisonErrorThreshold
    ),
    .dataVrefMinPassingWindowValues(dataVrefMinPassingWindowValues),
    .dataVrefMaxTrainingRetries(dataVrefMaxTrainingRetries)
  ) dataVref (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_DATAVREF),
    .busy(dataVref_busy),
    .done(dataVref_done),
    .trainError(dataVref_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_DATAVREF)),
    .sb_tx_valid(dataVref_sb_tx_valid),
    .sb_tx_din(dataVref_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_DATAVREF)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_dataVrefApplyRxVref(stage_flagToAnalog_dataVref_applyRxVref),
    .flagToAnalog_dataVrefRxVrefCodes(stage_flagToAnalog_dataVref_rxVrefCodes),
    .flagFromAnalog_dataVrefRxVrefApplied(stage_flagFromAnalog_dataVref_rxVrefApplied),
    .flagToAnalog_dataVrefConfigureRxInitD2CPointTest(
      stage_flagToAnalog_dataVref_configureRxInitD2CPointTest
    ),
    .flagToAnalog_dataVrefMaximumComparisonErrorThreshold(
      stage_flagToAnalog_dataVref_maximumComparisonErrorThreshold
    ),
    .flagToAnalog_dataVrefComparisonMode(stage_flagToAnalog_dataVref_comparisonMode),
    .flagToAnalog_dataVrefIterationCountSettings(
      stage_flagToAnalog_dataVref_iterationCountSettings
    ),
    .flagToAnalog_dataVrefIdleCountSettings(
      stage_flagToAnalog_dataVref_idleCountSettings
    ),
    .flagToAnalog_dataVrefBurstCountSettings(
      stage_flagToAnalog_dataVref_burstCountSettings
    ),
    .flagToAnalog_dataVrefPatternMode(stage_flagToAnalog_dataVref_patternMode),
    .flagToAnalog_dataVrefClockPhaseControl(
      stage_flagToAnalog_dataVref_clockPhaseControl
    ),
    .flagToAnalog_dataVrefValidPattern(stage_flagToAnalog_dataVref_validPattern),
    .flagToAnalog_dataVrefDataPattern(stage_flagToAnalog_dataVref_dataPattern),
    .flagToAnalog_dataVrefClearComparisonErrors(
      stage_flagToAnalog_dataVref_clearComparisonErrors
    ),
    .flagFromAnalog_dataVrefDetectedDataPattern(
      stage_flagFromAnalog_dataVref_detectedDataPattern
    ),
    .flagToAnalog_dataVrefSendPattern(stage_flagToAnalog_dataVref_sendPattern),
    .flagFromAnalog_dataVrefFinishedPattern(
      stage_flagFromAnalog_dataVref_finishedPattern
    ),
    .flagToAnalog_dataVrefResetLocalTxScrambler(
      stage_flagToAnalog_dataVref_resetLocalTxScrambler
    ),
    .dbg_localState(dataVref_dbg_localState),
    .dbg_remoteState(dataVref_dbg_remoteState),
    .dbg_sweepState(dataVref_dbg_sweepState),
    .dbg_pointInitiatorState(dataVref_dbg_pointInitiatorState),
    .dbg_pointResponderState(dataVref_dbg_pointResponderState),
    .lastErrorCount(dataVref_lastErrorCount),
    .retryCount(dataVref_retryCount),
    .selectedVrefCodes(dataVref_selectedCodes),
    .validWindowLeftCodes(dataVref_leftCodes),
    .validWindowRightCodes(dataVref_rightCodes)
  );
  MBTrainSpeedIdleFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed)
  ) speedIdle (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_SPEEDIDLE),
    .busy(speedIdle_busy),
    .done(speedIdle_done),
    .trainError(speedIdle_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_SPEEDIDLE)),
    .sb_tx_valid(speedIdle_sb_tx_valid),
    .sb_tx_din(speedIdle_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_SPEEDIDLE)),
    .sb_rx_dout(sb_rx_dout),
    .dbg_senderState(speedIdle_dbg_senderState),
    .dbg_receiverState(speedIdle_dbg_receiverState)
  );
  MBTrainTxSelfCalFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed)
  ) txSelfCal (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_TXSELFCAL),
    .busy(txSelfCal_busy),
    .done(txSelfCal_done),
    .trainError(txSelfCal_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_TXSELFCAL)),
    .sb_tx_valid(txSelfCal_sb_tx_valid),
    .sb_tx_din(txSelfCal_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_TXSELFCAL)),
    .sb_rx_dout(sb_rx_dout),
    .dbg_senderState(txSelfCal_dbg_senderState),
    .dbg_receiverState(txSelfCal_dbg_receiverState)
  );
  MBTrainRxClkCalFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed)
  ) rxClkCal (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_RXCLKCAL),
    .busy(rxClkCal_busy),
    .done(rxClkCal_done),
    .trainError(rxClkCal_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_RXCLKCAL)),
    .sb_tx_valid(rxClkCal_sb_tx_valid),
    .sb_tx_din(rxClkCal_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_RXCLKCAL)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_rxClkCalDoCalibration(flagToAnalog_rxClkCal_doCalibration),
    .flagFromAnalog_rxClkCalDone(flagFromAnalog_rxClkCal_done),
    .flagToAnalog_rxClkCalSendClockTrack(flagToAnalog_rxClkCal_sendClockTrack),
    .dbg_senderState(rxClkCal_dbg_senderState),
    .dbg_receiverState(rxClkCal_dbg_receiverState)
  );
  MBTrain_ValTrainCenter #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .d2cPiCodeWidth(d2cPiCodeWidth),
    .d2cMaximumComparisonErrorThreshold(d2cMaximumComparisonErrorThreshold),
    .d2cMinCommonWindowSteps(d2cMinCommonWindowSteps),
    .d2cMaxTrainingRetries(d2cMaxTrainingRetries)
  ) valTrainCenter (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_VALTRAINCENTER),
    .busy(valTrainCenter_busy),
    .done(valTrainCenter_done),
    .trainError(valTrainCenter_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_VALTRAINCENTER)),
    .sb_tx_valid(valTrainCenter_sb_tx_valid),
    .sb_tx_din(valTrainCenter_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_VALTRAINCENTER)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_d2cSender_sendValTrainPattern(stage_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainPatternSent(stage_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(stage_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(stage_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(stage_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(stage_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(stage_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(stage_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(stage_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(stage_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(stage_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(stage_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(stage_flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(stage_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(stage_flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(stage_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(stage_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(stage_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .dbg_senderState(valTrainCenter_dbg_senderState),
    .dbg_receiverState(valTrainCenter_dbg_receiverState),
    .dbg_d2cSenderState(valTrainCenter_dbg_d2cSenderState),
    .dbg_d2cReceiverState(valTrainCenter_dbg_d2cReceiverState),
    .dbg_sweepState(valTrainCenter_dbg_sweepState),
    .lastErrorCount(valTrainCenter_lastErrorCount),
    .retryCount(valTrainCenter_retryCount)
  );
  MBTrainValTrainVrefFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .validVrefValueCount(validVrefValueCount),
    .validVrefCodeWidth(validVrefCodeWidth),
    .validVrefMinimumMillivolts(validVrefMinimumMillivolts),
    .validVrefMaximumMillivolts(validVrefMaximumMillivolts),
    .validVrefMaximumComparisonErrorThreshold(validVrefMaximumComparisonErrorThreshold),
    .validVrefMinPassingWindowValues(validVrefMinPassingWindowValues),
    .validVrefMaxTrainingRetries(validVrefMaxTrainingRetries),
    .performVrefTraining(valTrainVrefEnable)
  ) valTrainVref (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_VALTRAINVREF),
    .busy(valTrainVref_busy),
    .done(valTrainVref_done),
    .trainError(valTrainVref_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_VALTRAINVREF)),
    .sb_tx_valid(valTrainVref_sb_tx_valid),
    .sb_tx_din(valTrainVref_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_VALTRAINVREF)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_valTrainVrefApplyRxVref(stage_flagToAnalog_valTrainVref_applyRxVref),
    .flagToAnalog_valTrainVrefRxVrefCode(stage_flagToAnalog_valTrainVref_rxVrefCode),
    .flagFromAnalog_valTrainVrefRxVrefApplied(stage_flagFromAnalog_valTrainVref_rxVrefApplied),
    .flagToAnalog_valTrainVrefConfigureRxInitD2CPointTest(stage_flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_valTrainVrefMaximumComparisonErrorThreshold(stage_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valTrainVrefComparisonMode(stage_flagToAnalog_valTrainVref_comparisonMode),
    .flagToAnalog_valTrainVrefIterationCountSettings(stage_flagToAnalog_valTrainVref_iterationCountSettings),
    .flagToAnalog_valTrainVrefIdleCountSettings(stage_flagToAnalog_valTrainVref_idleCountSettings),
    .flagToAnalog_valTrainVrefBurstCountSettings(stage_flagToAnalog_valTrainVref_burstCountSettings),
    .flagToAnalog_valTrainVrefPatternMode(stage_flagToAnalog_valTrainVref_patternMode),
    .flagToAnalog_valTrainVrefClockPhaseControl(stage_flagToAnalog_valTrainVref_clockPhaseControl),
    .flagToAnalog_valTrainVrefValidPattern(stage_flagToAnalog_valTrainVref_validPattern),
    .flagToAnalog_valTrainVrefDataPattern(stage_flagToAnalog_valTrainVref_dataPattern),
    .flagToAnalog_valTrainVrefClearComparisonErrors(stage_flagToAnalog_valTrainVref_clearComparisonErrors),
    .flagFromAnalog_valTrainVrefDetectedValPattern(stage_flagFromAnalog_valTrainVref_detectedValPattern),
    .flagToAnalog_valTrainVrefSendPattern(stage_flagToAnalog_valTrainVref_sendPattern),
    .flagFromAnalog_valTrainVrefFinishedPattern(stage_flagFromAnalog_valTrainVref_finishedPattern),
    .flagToAnalog_valTrainVrefResetLocalTxScrambler(stage_flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .dbg_localState(valTrainVref_dbg_localState),
    .dbg_remoteState(valTrainVref_dbg_remoteState),
    .dbg_sweepState(valTrainVref_dbg_sweepState),
    .dbg_pointInitiatorState(valTrainVref_dbg_pointInitiatorState),
    .dbg_pointResponderState(valTrainVref_dbg_pointResponderState),
    .lastErrorCount(valTrainVref_lastErrorCount),
    .retryCount(valTrainVref_retryCount),
    .selectedVrefCode(valTrainVref_selectedCode),
    .validWindowLeftCode(valTrainVref_leftCode),
    .validWindowRightCode(valTrainVref_rightCode)
  );
  MBTrain_DataTrainCenter1 #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .d2cPiCodeWidth(d2cPiCodeWidth),
    .d2cTxDeskewCodeWidth(d2cTxDeskewCodeWidth),
    .d2cDeskewStepsPerPi(d2cDeskewStepsPerPi),
    .d2cDeskewAddDelayIncreasesPhase(d2cDeskewAddDelayIncreasesPhase),
    .d2cMaximumComparisonErrorThreshold(d2cMaximumComparisonErrorThreshold),
    .d2cMinLaneWindowSteps(d2cMinLaneWindowSteps),
    .d2cMinCommonWindowSteps(d2cMinCommonWindowSteps),
    .d2cMaxTrainingRetries(d2cMaxTrainingRetries)
  ) dataTrainCenter1 (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_DATATRAINCENTER1),
    .busy(dataTrainCenter1_busy),
    .done(dataTrainCenter1_done),
    .trainError(dataTrainCenter1_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_DATATRAINCENTER1)),
    .sb_tx_valid(dataTrainCenter1_sb_tx_valid),
    .sb_tx_din(dataTrainCenter1_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_DATATRAINCENTER1)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_d2cSender_sendLfsrPattern(stage_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(stage_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(stage_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(stage_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(stage_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .flagToAnalog_d2cSender_applyTxLaneDeskew(stage_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_txLaneDeskewCodes(stage_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_txLaneDeskewApplied(stage_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(stage_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(stage_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .dbg_senderState(dataTrainCenter1_dbg_senderState),
    .dbg_receiverState(dataTrainCenter1_dbg_receiverState),
    .dbg_d2cSenderState(dataTrainCenter1_dbg_d2cSenderState),
    .dbg_d2cReceiverState(dataTrainCenter1_dbg_d2cReceiverState),
    .dbg_sweepState(dataTrainCenter1_dbg_sweepState),
    .lastErrorCount(dataTrainCenter1_lastErrorCount),
    .retryCount(dataTrainCenter1_retryCount)
  );
  MBTrainDataTrainVrefFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .dataLaneCount(dataLaneCount),
    .activeDataLaneMask(activeDataLaneMask),
    .dataVrefValueCount(dataVrefValueCount),
    .dataVrefCodeWidth(dataVrefCodeWidth),
    .dataVrefMinimumMillivolts(dataVrefMinimumMillivolts),
    .dataVrefMaximumMillivolts(dataVrefMaximumMillivolts),
    .dataVrefMaximumComparisonErrorThreshold(
      dataVrefMaximumComparisonErrorThreshold
    ),
    .dataVrefMinPassingWindowValues(dataVrefMinPassingWindowValues),
    .dataVrefMaxTrainingRetries(dataVrefMaxTrainingRetries),
    .performVrefTraining(dataTrainVrefEnable)
  ) dataTrainVref (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_DATATRAINVREF),
    .busy(dataTrainVref_busy),
    .done(dataTrainVref_done),
    .trainError(dataTrainVref_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_DATATRAINVREF)),
    .sb_tx_valid(dataTrainVref_sb_tx_valid),
    .sb_tx_din(dataTrainVref_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_DATATRAINVREF)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_dataTrainVrefApplyRxVref(
      stage_flagToAnalog_dataTrainVref_applyRxVref
    ),
    .flagToAnalog_dataTrainVrefRxVrefCodes(
      stage_flagToAnalog_dataTrainVref_rxVrefCodes
    ),
    .flagFromAnalog_dataTrainVrefRxVrefApplied(
      stage_flagFromAnalog_dataTrainVref_rxVrefApplied
    ),
    .flagToAnalog_dataTrainVrefConfigureRxInitD2CPointTest(
      stage_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest
    ),
    .flagToAnalog_dataTrainVrefMaximumComparisonErrorThreshold(
      stage_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold
    ),
    .flagToAnalog_dataTrainVrefComparisonMode(
      stage_flagToAnalog_dataTrainVref_comparisonMode
    ),
    .flagToAnalog_dataTrainVrefIterationCountSettings(
      stage_flagToAnalog_dataTrainVref_iterationCountSettings
    ),
    .flagToAnalog_dataTrainVrefIdleCountSettings(
      stage_flagToAnalog_dataTrainVref_idleCountSettings
    ),
    .flagToAnalog_dataTrainVrefBurstCountSettings(
      stage_flagToAnalog_dataTrainVref_burstCountSettings
    ),
    .flagToAnalog_dataTrainVrefPatternMode(
      stage_flagToAnalog_dataTrainVref_patternMode
    ),
    .flagToAnalog_dataTrainVrefClockPhaseControl(
      stage_flagToAnalog_dataTrainVref_clockPhaseControl
    ),
    .flagToAnalog_dataTrainVrefValidPattern(
      stage_flagToAnalog_dataTrainVref_validPattern
    ),
    .flagToAnalog_dataTrainVrefDataPattern(
      stage_flagToAnalog_dataTrainVref_dataPattern
    ),
    .flagToAnalog_dataTrainVrefClearComparisonErrors(
      stage_flagToAnalog_dataTrainVref_clearComparisonErrors
    ),
    .flagFromAnalog_dataTrainVrefDetectedDataPattern(
      stage_flagFromAnalog_dataTrainVref_detectedDataPattern
    ),
    .flagToAnalog_dataTrainVrefSendPattern(
      stage_flagToAnalog_dataTrainVref_sendPattern
    ),
    .flagFromAnalog_dataTrainVrefFinishedPattern(
      stage_flagFromAnalog_dataTrainVref_finishedPattern
    ),
    .flagToAnalog_dataTrainVrefResetLocalTxScrambler(
      stage_flagToAnalog_dataTrainVref_resetLocalTxScrambler
    ),
    .dbg_localState(dataTrainVref_dbg_localState),
    .dbg_remoteState(dataTrainVref_dbg_remoteState),
    .dbg_sweepState(dataTrainVref_dbg_sweepState),
    .dbg_pointInitiatorState(dataTrainVref_dbg_pointInitiatorState),
    .dbg_pointResponderState(dataTrainVref_dbg_pointResponderState),
    .lastErrorCount(dataTrainVref_lastErrorCount),
    .retryCount(dataTrainVref_retryCount),
    .selectedVrefCodes(dataTrainVref_selectedCodes),
    .validWindowLeftCodes(dataTrainVref_leftCodes),
    .validWindowRightCodes(dataTrainVref_rightCodes)
  );
  MBTrainRxDeskewFSM #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .performRxDeskew(rxDeskewEnable),
    .dataLaneCount(dataLaneCount),
    .activeDataLaneMask(activeDataLaneMask),
    .rxDeskewCodeWidth(rxDeskewCodeWidth),
    .rxDeskewValueCount(rxDeskewValueCount),
    .rxDeskewMaximumComparisonErrorThreshold(
      rxDeskewMaximumComparisonErrorThreshold),
    .rxDeskewMinPassingWindowValues(rxDeskewMinPassingWindowValues),
    .rxDeskewMaxTrainingRetries(rxDeskewMaxTrainingRetries)
  ) rxDeskew (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_RXDESKEW),
    .busy(rxDeskew_busy),
    .done(rxDeskew_done),
    .trainError(rxDeskew_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_RXDESKEW)),
    .sb_tx_valid(rxDeskew_sb_tx_valid),
    .sb_tx_din(rxDeskew_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_RXDESKEW)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_rxDeskewApplyRxLaneDeskew(
      flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .flagToAnalog_rxDeskewRxLaneDeskewCodes(
      flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .flagFromAnalog_rxDeskewRxLaneDeskewApplied(
      flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .flagToAnalog_rxDeskewConfigureRxInitD2CPointTest(
      flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .flagToAnalog_rxDeskewMaximumComparisonErrorThreshold(
      flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .flagToAnalog_rxDeskewComparisonMode(
      flagToAnalog_rxDeskew_comparisonMode),
    .flagToAnalog_rxDeskewIterationCountSettings(
      flagToAnalog_rxDeskew_iterationCountSettings),
    .flagToAnalog_rxDeskewIdleCountSettings(
      flagToAnalog_rxDeskew_idleCountSettings),
    .flagToAnalog_rxDeskewBurstCountSettings(
      flagToAnalog_rxDeskew_burstCountSettings),
    .flagToAnalog_rxDeskewPatternMode(
      flagToAnalog_rxDeskew_patternMode),
    .flagToAnalog_rxDeskewClockPhaseControl(
      flagToAnalog_rxDeskew_clockPhaseControl),
    .flagToAnalog_rxDeskewValidPattern(
      flagToAnalog_rxDeskew_validPattern),
    .flagToAnalog_rxDeskewDataPattern(
      flagToAnalog_rxDeskew_dataPattern),
    .flagToAnalog_rxDeskewClearComparisonErrors(
      flagToAnalog_rxDeskew_clearComparisonErrors),
    .flagFromAnalog_rxDeskewDetectedDataPattern(
      flagFromAnalog_rxDeskew_detectedDataPattern),
    .flagToAnalog_rxDeskewSendLfsrPattern(
      flagToAnalog_rxDeskew_sendLfsrPattern),
    .flagFromAnalog_rxDeskewLfsrPatternSent(
      flagFromAnalog_rxDeskew_lfsrPatternSent),
    .flagToAnalog_rxDeskewResetLocalTxScrambler(
      flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .dbg_localState(rxDeskew_dbg_localState),
    .dbg_remoteState(rxDeskew_dbg_remoteState),
    .dbg_sweepState(rxDeskew_dbg_sweepState),
    .dbg_pointInitiatorState(rxDeskew_dbg_pointInitiatorState),
    .dbg_pointResponderState(rxDeskew_dbg_pointResponderState),
    .lastErrorCount(rxDeskew_lastErrorCount),
    .retryCount(rxDeskew_retryCount),
    .selectedRxDeskewCodes(rxDeskew_selectedCodes),
    .validWindowLeftCodes(rxDeskew_leftCodes),
    .validWindowRightCodes(rxDeskew_rightCodes)
  );
  MBTrain_DataTrainCenter2 #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed),
    .d2cPiCodeWidth(d2cPiCodeWidth),
    .d2cMaximumComparisonErrorThreshold(d2cMaximumComparisonErrorThreshold),
    .d2cMinCommonWindowSteps(d2cMinCommonWindowSteps),
    .d2cMaxTrainingRetries(d2cMaxTrainingRetries)
  ) dataTrainCenter2 (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_DATATRAINCENTER2),
    .busy(dataTrainCenter2_busy),
    .done(dataTrainCenter2_done),
    .trainError(dataTrainCenter2_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_DATATRAINCENTER2)),
    .sb_tx_valid(dataTrainCenter2_sb_tx_valid),
    .sb_tx_din(dataTrainCenter2_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_DATATRAINCENTER2)),
    .sb_rx_dout(sb_rx_dout),
    .flagToAnalog_d2cSender_sendLfsrPattern(stage_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(stage_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(stage_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(stage_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(stage_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(stage_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(stage_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(stage_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .dbg_senderState(dataTrainCenter2_dbg_senderState),
    .dbg_receiverState(dataTrainCenter2_dbg_receiverState),
    .dbg_d2cSenderState(dataTrainCenter2_dbg_d2cSenderState),
    .dbg_d2cReceiverState(dataTrainCenter2_dbg_d2cReceiverState),
    .dbg_sweepState(dataTrainCenter2_dbg_sweepState),
    .lastErrorCount(dataTrainCenter2_lastErrorCount),
    .retryCount(dataTrainCenter2_retryCount)
  );
  MBTrain_LinkSpeed #(
    .sbFeatureExtension(sbFeatureExtension),
    .ucieA(ucieA),
    .moduleID(moduleID),
    .clkPhase(clkPhase),
    .clkMode(clkMode),
    .voltageSwing(voltageSwing),
    .maxLinkSpeed(maxLinkSpeed)
  ) linkSpeed (
    .clock(clock),
    .reset_n(reset_n),
    .start(stateReg == State_LINKSPEED),
    .busy(linkSpeed_busy),
    .done(linkSpeed_done),
    .trainError(linkSpeed_trainError),
    .sb_tx_ready(sb_tx_ready && (stateReg == State_LINKSPEED)),
    .sb_tx_valid(linkSpeed_sb_tx_valid),
    .sb_tx_din(linkSpeed_sb_tx_din),
    .sb_rx_valid(sb_rx_valid && (stateReg == State_LINKSPEED)),
    .sb_rx_dout(sb_rx_dout),
    .flagToLtsm_phyInRetrain(flagToLtsm_linkSpeed_phyInRetrain),
    .flagToAnalog_d2cSender_sendLfsrPattern(stage_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(stage_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(stage_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(stage_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(stage_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(stage_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(stage_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(stage_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(stage_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(stage_flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(stage_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(stage_flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(stage_flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(stage_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_laneComparisonSuccessful(stage_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
    .dbg_senderState(linkSpeed_dbg_senderState),
    .dbg_receiverState(linkSpeed_dbg_receiverState),
    .dbg_d2cSenderState(linkSpeed_dbg_d2cSenderState),
    .dbg_d2cReceiverState(linkSpeed_dbg_d2cReceiverState),
    .lastErrorCount(linkSpeed_lastErrorCount),
    .retryCount(linkSpeed_retryCount)
  );

  wire activeChildError =
    valVref_trainError || dataVref_trainError || speedIdle_trainError ||
    txSelfCal_trainError || rxClkCal_trainError || valTrainCenter_trainError ||
    valTrainVref_trainError || dataTrainCenter1_trainError ||
    dataTrainVref_trainError || rxDeskew_trainError ||
    dataTrainCenter2_trainError || linkSpeed_trainError;

  always_comb begin
    sb_tx_valid = 1'b0;
    sb_tx_din = 128'b0;
    unique case (stateReg)
      State_VALVREF: begin
        sb_tx_valid = valVref_sb_tx_valid;
        sb_tx_din = valVref_sb_tx_din;
      end
      State_DATAVREF: begin
        sb_tx_valid = dataVref_sb_tx_valid;
        sb_tx_din = dataVref_sb_tx_din;
      end
      State_SPEEDIDLE: begin
        sb_tx_valid = speedIdle_sb_tx_valid;
        sb_tx_din = speedIdle_sb_tx_din;
      end
      State_TXSELFCAL: begin
        sb_tx_valid = txSelfCal_sb_tx_valid;
        sb_tx_din = txSelfCal_sb_tx_din;
      end
      State_RXCLKCAL: begin
        sb_tx_valid = rxClkCal_sb_tx_valid;
        sb_tx_din = rxClkCal_sb_tx_din;
      end
      State_VALTRAINCENTER: begin
        sb_tx_valid = valTrainCenter_sb_tx_valid;
        sb_tx_din = valTrainCenter_sb_tx_din;
      end
      State_VALTRAINVREF: begin
        sb_tx_valid = valTrainVref_sb_tx_valid;
        sb_tx_din = valTrainVref_sb_tx_din;
      end
      State_DATATRAINCENTER1: begin
        sb_tx_valid = dataTrainCenter1_sb_tx_valid;
        sb_tx_din = dataTrainCenter1_sb_tx_din;
      end
      State_DATATRAINVREF: begin
        sb_tx_valid = dataTrainVref_sb_tx_valid;
        sb_tx_din = dataTrainVref_sb_tx_din;
      end
      State_RXDESKEW: begin
        sb_tx_valid = rxDeskew_sb_tx_valid;
        sb_tx_din = rxDeskew_sb_tx_din;
      end
      State_DATATRAINCENTER2: begin
        sb_tx_valid = dataTrainCenter2_sb_tx_valid;
        sb_tx_din = dataTrainCenter2_sb_tx_din;
      end
      State_LINKSPEED: begin
        sb_tx_valid = linkSpeed_sb_tx_valid;
        sb_tx_din = linkSpeed_sb_tx_din;
      end
      default: ;
    endcase
  end

  always_comb begin
    state = stateReg;
    dbg_mbtrainValVrefLocalState = valVref_dbg_localState;
    dbg_mbtrainValVrefRemoteState = valVref_dbg_remoteState;
    dbg_mbtrainValVrefSweepState = valVref_dbg_sweepState;
    dbg_mbtrainValVrefPointInitiatorState = valVref_dbg_pointInitiatorState;
    dbg_mbtrainValVrefPointResponderState = valVref_dbg_pointResponderState;
    dbg_mbtrainDataVrefLocalState = dataVref_dbg_localState;
    dbg_mbtrainDataVrefRemoteState = dataVref_dbg_remoteState;
    dbg_mbtrainDataVrefSweepState = dataVref_dbg_sweepState;
    dbg_mbtrainDataVrefPointInitiatorState = dataVref_dbg_pointInitiatorState;
    dbg_mbtrainDataVrefPointResponderState = dataVref_dbg_pointResponderState;
    dbg_mbtrainSpeedIdleSenderState = speedIdle_dbg_senderState;
    dbg_mbtrainSpeedIdleReceiverState = speedIdle_dbg_receiverState;
    dbg_mbtrainTxSelfCalSenderState = txSelfCal_dbg_senderState;
    dbg_mbtrainTxSelfCalReceiverState = txSelfCal_dbg_receiverState;
    dbg_mbtrainRxClkCalSenderState = rxClkCal_dbg_senderState;
    dbg_mbtrainRxClkCalReceiverState = rxClkCal_dbg_receiverState;
    dbg_mbtrainValTrainCenterSenderState = valTrainCenter_dbg_senderState;
    dbg_mbtrainValTrainCenterReceiverState = valTrainCenter_dbg_receiverState;
    dbg_mbtrainValTrainCenterD2cSenderState = valTrainCenter_dbg_d2cSenderState;
    dbg_mbtrainValTrainCenterD2cReceiverState = valTrainCenter_dbg_d2cReceiverState;
    dbg_mbtrainValTrainCenterSweepState = valTrainCenter_dbg_sweepState;
    dbg_mbtrainValTrainVrefLocalState = valTrainVref_dbg_localState;
    dbg_mbtrainValTrainVrefRemoteState = valTrainVref_dbg_remoteState;
    dbg_mbtrainValTrainVrefSweepState = valTrainVref_dbg_sweepState;
    dbg_mbtrainValTrainVrefPointInitiatorState = valTrainVref_dbg_pointInitiatorState;
    dbg_mbtrainValTrainVrefPointResponderState = valTrainVref_dbg_pointResponderState;
    dbg_mbtrainDataTrainCenter1SenderState = dataTrainCenter1_dbg_senderState;
    dbg_mbtrainDataTrainCenter1ReceiverState = dataTrainCenter1_dbg_receiverState;
    dbg_mbtrainDataTrainCenter1D2cSenderState = dataTrainCenter1_dbg_d2cSenderState;
    dbg_mbtrainDataTrainCenter1D2cReceiverState = dataTrainCenter1_dbg_d2cReceiverState;
    dbg_mbtrainDataTrainCenter1SweepState = dataTrainCenter1_dbg_sweepState;
    dbg_mbtrainDataTrainVrefLocalState = dataTrainVref_dbg_localState;
    dbg_mbtrainDataTrainVrefRemoteState = dataTrainVref_dbg_remoteState;
    dbg_mbtrainDataTrainVrefSweepState = dataTrainVref_dbg_sweepState;
    dbg_mbtrainDataTrainVrefPointInitiatorState = dataTrainVref_dbg_pointInitiatorState;
    dbg_mbtrainDataTrainVrefPointResponderState = dataTrainVref_dbg_pointResponderState;
    dbg_mbtrainRxDeskewLocalState = rxDeskew_dbg_localState;
    dbg_mbtrainRxDeskewRemoteState = rxDeskew_dbg_remoteState;
    dbg_mbtrainRxDeskewSweepState = rxDeskew_dbg_sweepState;
    dbg_mbtrainRxDeskewPointInitiatorState = rxDeskew_dbg_pointInitiatorState;
    dbg_mbtrainRxDeskewPointResponderState = rxDeskew_dbg_pointResponderState;
    dbg_mbtrainDataTrainCenter2SenderState = dataTrainCenter2_dbg_senderState;
    dbg_mbtrainDataTrainCenter2ReceiverState = dataTrainCenter2_dbg_receiverState;
    dbg_mbtrainDataTrainCenter2D2cSenderState = dataTrainCenter2_dbg_d2cSenderState;
    dbg_mbtrainDataTrainCenter2D2cReceiverState = dataTrainCenter2_dbg_d2cReceiverState;
    dbg_mbtrainDataTrainCenter2SweepState = dataTrainCenter2_dbg_sweepState;
    dbg_mbtrainLinkSpeedSenderState = linkSpeed_dbg_senderState;
    dbg_mbtrainLinkSpeedReceiverState = linkSpeed_dbg_receiverState;
    dbg_mbtrainLinkSpeedD2cSenderState = linkSpeed_dbg_d2cSenderState;
    dbg_mbtrainLinkSpeedD2cReceiverState = linkSpeed_dbg_d2cReceiverState;
    busy = (stateReg != State_IDLE) &&
           (stateReg != State_COMPLETE) &&
           (stateReg != State_ERROR);
    done = (stateReg == State_COMPLETE);
    trainError = errorReg || (stateReg == State_ERROR);

    // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
    activeSubstate = 12'b0;
    lastErrorCount = 16'b0;
    retryCount = 16'b0;
    unique case (stateReg)
      State_VALVREF: begin
        activeSubstate = {valVref_dbg_localState, valVref_dbg_pointInitiatorState, valVref_dbg_pointResponderState};
        lastErrorCount = valVref_lastErrorCount;
        retryCount = valVref_retryCount;
      end
      State_DATAVREF: begin
        activeSubstate = {dataVref_dbg_localState, dataVref_dbg_pointInitiatorState, dataVref_dbg_pointResponderState};
        lastErrorCount = dataVref_lastErrorCount;
        retryCount = dataVref_retryCount;
      end
      State_SPEEDIDLE: begin
        activeSubstate = {8'b0, speedIdle_dbg_receiverState, speedIdle_dbg_senderState};
      end
      State_TXSELFCAL: begin
        activeSubstate = {8'b0, txSelfCal_dbg_receiverState, txSelfCal_dbg_senderState};
      end
      State_RXCLKCAL: begin
        activeSubstate = {6'b0, rxClkCal_dbg_receiverState, rxClkCal_dbg_senderState};
      end
      State_VALTRAINCENTER: begin
        activeSubstate = {valTrainCenter_dbg_senderState, valTrainCenter_dbg_d2cSenderState, valTrainCenter_dbg_d2cReceiverState};
        lastErrorCount = valTrainCenter_lastErrorCount;
        retryCount = valTrainCenter_retryCount;
      end
      State_VALTRAINVREF: begin
        activeSubstate = {valTrainVref_dbg_localState, valTrainVref_dbg_pointInitiatorState, valTrainVref_dbg_pointResponderState};
        lastErrorCount = valTrainVref_lastErrorCount;
        retryCount = valTrainVref_retryCount;
      end
      State_DATATRAINCENTER1: begin
        activeSubstate = {dataTrainCenter1_dbg_senderState, dataTrainCenter1_dbg_d2cSenderState, dataTrainCenter1_dbg_d2cReceiverState};
        lastErrorCount = dataTrainCenter1_lastErrorCount;
        retryCount = dataTrainCenter1_retryCount;
      end
      State_DATATRAINVREF: begin
        activeSubstate = {dataTrainVref_dbg_localState, dataTrainVref_dbg_pointInitiatorState, dataTrainVref_dbg_pointResponderState};
        lastErrorCount = dataTrainVref_lastErrorCount;
        retryCount = dataTrainVref_retryCount;
      end
      State_RXDESKEW: begin
        activeSubstate = {rxDeskew_dbg_localState, rxDeskew_dbg_pointInitiatorState, rxDeskew_dbg_pointResponderState};
        lastErrorCount = rxDeskew_lastErrorCount;
        retryCount = rxDeskew_retryCount;
      end
      State_DATATRAINCENTER2: begin
        activeSubstate = {dataTrainCenter2_dbg_senderState, dataTrainCenter2_dbg_d2cSenderState, dataTrainCenter2_dbg_d2cReceiverState};
        lastErrorCount = dataTrainCenter2_lastErrorCount;
        retryCount = dataTrainCenter2_retryCount;
      end
      State_LINKSPEED: begin
        activeSubstate = {linkSpeed_dbg_senderState, linkSpeed_dbg_d2cSenderState, linkSpeed_dbg_d2cReceiverState};
        lastErrorCount = linkSpeed_lastErrorCount;
        retryCount = linkSpeed_retryCount;
      end
      default: ;
    endcase
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg <= State_IDLE;
      errorReg <= 1'b0;
    end else begin
      if ((stateReg == State_IDLE) && start) begin
        stateReg <= State_VALVREF;
        errorReg <= 1'b0;
      end else if (activeChildError) begin
        stateReg <= State_ERROR;
        errorReg <= 1'b1;
      end else begin
        unique case (stateReg)
          State_IDLE: ;
          State_VALVREF: begin
            if (valVref_done)
              stateReg <= State_DATAVREF;
          end
          State_DATAVREF: begin
            if (dataVref_done)
              stateReg <= State_SPEEDIDLE;
          end
          State_SPEEDIDLE: begin
            if (speedIdle_done)
              stateReg <= State_TXSELFCAL;
          end
          State_TXSELFCAL: begin
            if (txSelfCal_done)
              stateReg <= State_RXCLKCAL;
          end
          State_RXCLKCAL: begin
            if (rxClkCal_done)
              stateReg <= State_VALTRAINCENTER;
          end
          State_VALTRAINCENTER: begin
            if (valTrainCenter_done)
              stateReg <= State_VALTRAINVREF;
          end
          State_VALTRAINVREF: begin
            if (valTrainVref_done)
              stateReg <= State_DATATRAINCENTER1;
          end
          State_DATATRAINCENTER1: begin
            if (dataTrainCenter1_done)
              stateReg <= State_DATATRAINVREF;
          end
          State_DATATRAINVREF: begin
            if (dataTrainVref_done)
              stateReg <= State_RXDESKEW;
          end
          State_RXDESKEW: begin
            if (rxDeskew_done)
              stateReg <= State_DATATRAINCENTER2;
          end
          State_DATATRAINCENTER2: begin
            if (dataTrainCenter2_done)
              stateReg <= State_LINKSPEED;
          end
          State_LINKSPEED: begin
            if (linkSpeed_done)
              stateReg <= State_COMPLETE;
          end
          State_REPAIR: begin
            // Source TODO: MBTRAIN.REPAIR has no submodule or exit path yet.
            stateReg <= State_REPAIR;
          end
          State_COMPLETE: begin
            if (!start)
              stateReg <= State_IDLE;
          end
          State_ERROR: begin
            if (!start)
              stateReg <= State_IDLE;
          end
          default: stateReg <= State_IDLE;
        endcase
      end
    end
  end
endmodule

`default_nettype wire
