# SystemVerilog Project Merge

Total files: **49**

## File Index

1. #D2DAdapterConstants-sv
2. #D2DAdapterLinkMgmtLtsmTop_corrected-sv
3. #D2DAdapterLinkMgmtTop-sv
4. #Fdi-sv
5. #LinkManagementController-sv
6. #LinkMgmtSidebandPacketArbiter-sv
7. #LinkTrainingFSM-sv
8. #LtsmSidebandRxPulseAdapter-sv
9. #LtsmSidebandTxCapture-sv
10. #MBInitFSM-sv
11. #MBTrain_DataTrainCenter1-sv
12. #MBTrain_DataTrainCenter1SweepEngine-sv
13. #MBTrain_DataTrainCenter2-sv
14. #MBTrain_DataTrainCenter2SweepEngine-sv
15. #MBTrain_DataTrainVrefFSM-sv
16. #MBTrain_DataVrefFSM-sv
17. #MBTrain_DataVrefStateCore-sv
18. #MBTrain_DataVrefSweepEngine-sv
19. #MBTrain_LinkSpeed-sv
20. #MBTrain_RxClkCalFSM-sv
21. #MBTrain_RxDeskewFSM-sv
22. #MBTrain_RxDeskewSweepEngine-sv
23. #MBTrain_SpeedIdleFSM-sv
24. #MBTrain_TxSelfCalFSM-sv
25. #MBTrain_ValidVrefStateCore-sv
26. #MBTrain_ValidVrefSweepEngine-sv
27. #MBTrain_ValTrainCenterFSM-sv
28. #MBTrain_ValTrainCenterSweepEngine-sv
29. #MBTrain_ValTrainVrefFSM-sv
30. #MBTrain_ValVrefFSM-sv
31. #MBTrainFSM-sv
32. #Parameters-sv
33. #Rdi-sv
34. #RdiLinkManagementConstants-sv
35. #RdiLinkManagementController-sv
36. #RdiTimeoutController-sv
37. #RxInitD2CPointTestReceiverFSM-sv
38. #RxInitD2CPointTestSenderFSM-sv
39. #SideBandModule-sv
40. #SidebandMsgGenerator_corregido-sv
41. #sidebandNode-sv
42. #SidebandRx-sv
43. #SidebandTx-sv
44. #StallController-sv
45. #States-sv
46. #TxInitD2CPointTestReceiverFSM-sv
47. #TxInitD2CPointTestSenderFSM-sv
48. #Types-sv
49. #UCIePhyRegisterBlock-sv

---

<a id="D2DAdapterConstants-sv"></a>

## [1] D2DAdapterConstants.sv

```systemverilog
// FILE_INDEX: 1
// FILE_PATH : D2DAdapterConstants.sv

// Hand-translated synthesizable SystemVerilog.
// Source: D2DAdapterConstants(4).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_d2dadapter_pkg;
  // FDI initialization substates used by LinkManagementController.
  typedef enum logic [2:0] {
    LinkInitState_FDI_INIT_START         = 3'h0,
    LinkInitState_FDI_WAIT_RDI_ACTIVE    = 3'h1,
    LinkInitState_FDI_PARAM_EXCH         = 3'h2,
    LinkInitState_FDI_WAIT_LP_REQ_ACTIVE = 3'h3,
    LinkInitState_FDI_ACTIVE_HANDSHAKE   = 3'h4,
    LinkInitState_FDI_ACTIVE_ENTRY_DONE  = 3'h5
  } LinkInitState_t;

  parameter int unsigned D2Dlinkerrcnt_SIZE  = 64;
  parameter int unsigned D2Dparamexchcnt_SIZE = 64;
endpackage

`default_nettype wire

```

<a id="D2DAdapterLinkMgmtLtsmTop_corrected-sv"></a>

## [2] D2DAdapterLinkMgmtLtsmTop_corrected.sv

```systemverilog
// FILE_INDEX: 2
// FILE_PATH : D2DAdapterLinkMgmtLtsmTop_corrected.sv

// Synthesizable SystemVerilog translation.
// Integrated D2D adapter link-management and LinkTrainingFSM wrapper.
// LtsmExternalIO is flattened with the ltsm_ prefix while preserving every field name.
// Reset convention: asynchronous active-low reset_n is passed to every state-holding child.
// UCIe PHY-state names and encodings are taken from UcieUPM_interfaces_pkg
// in Types.sv; this wrapper does not depend on a separate LTSM-state package.

`default_nettype none

module D2DAdapterLinkMgmtLtsmTop #(
  parameter int unsigned FDI_WIDTH         = UcieUPM_fdi_params_pkg::FDI_WIDTH,
  parameter int unsigned FDI_DLLP_WIDTH    = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH,
  parameter int unsigned FDI_SB_WIDTH      = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH,
  parameter int unsigned RDI_WIDTH         = UcieUPM_rdi_params_pkg::RDI_WIDTH,
  parameter int unsigned RDI_SB_WIDTH      = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH,
  parameter int unsigned SB_NODE_MSG_WIDTH = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH,
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

  // Protocol-facing FDI interface.
  input wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input wire logic                                  fdi_lp_linkerror,
  input wire logic                                  fdi_lp_rx_active_sts,
  input wire logic                                  fdi_lp_wake_req,
  input wire logic                                  fdi_lp_clk_ack,
  input wire logic                                  fdi_lp_stall_ack,

  output var UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts,
  output var logic                               fdi_pl_rx_active_req,
  output var logic                               fdi_pl_inband_pres,
  output var logic                               fdi_pl_wake_ack,
  output var logic                               fdi_pl_clk_req,
  output var logic                               fdi_pl_stall_req,

  // Complete-message sideband transport to the remote die.
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_msg,
  input wire logic         sb_tx_ready,

  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_msg,
  output var logic         sb_rx_ready,

  input wire logic [31:0] cycles_1us,

  // Flattened initial-LTSM analog/training interface.
  input wire logic           ltsm_start,
  input wire logic           ltsm_stable_clk,
  input wire logic           ltsm_pll_locked,
  input wire logic           ltsm_stable_supply,
  input wire logic           ltsm_flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic           ltsm_flagFromAnalog_FinishedClkPatterns,
  input wire logic           ltsm_flagFromAnalog_FinishedValTrainPattern,
  input wire logic           ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  input wire logic           ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
  input wire logic           ltsm_flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic           ltsm_flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic           ltsm_flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic           ltsm_flagFromAnalog_ValTrainPatternReceived,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
  input wire logic           ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
  input wire logic           ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
  output var logic           ltsm_flagToAnalog_RepairClkState,
  output var logic           ltsm_flagToAnalog_SendClkPatterns,
  output var logic           ltsm_flagToAnalog_RepairValState,
  output var logic           ltsm_flagToAnalog_SendValTrainPattern,
  output var logic           ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic           ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic           ltsm_flagToAnalog_RepairMbSetReceiver,
  output var logic           ltsm_flagToAnalog_LaneReversalApplied,
  output var logic           ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
  output var logic [3:0]     ltsm_state,
  output var logic           ltsm_dbg_flagSbinitFirstClkPatternSeen,
  output var logic           ltsm_dbg_rxValidRisingEdge,
  output var logic [2:0]     ltsm_dbg_sbinitSendCount,
  output var logic           ltsm_dbg_sbTxValid,
  output var logic [127:0]   ltsm_dbg_sbTxDin,
  output var logic           ltsm_dbg_flagTrainError,
  output var logic [2:0]     ltsm_dbg_mbinitSubstate,
  output var logic [4:0]     ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
  output var logic           ltsm_flagToAnalog_valVref_sendPattern,
  input wire logic           ltsm_flagFromAnalog_valVref_detectedValPattern,
  input wire logic           ltsm_flagFromAnalog_valVref_finishedPattern,
  output var logic           ltsm_flagToAnalog_valVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] ltsm_flagToAnalog_valVref_rxVrefCode,
  input wire logic           ltsm_flagFromAnalog_valVref_rxVrefApplied,
  output var logic           ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_valVref_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_valVref_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_valVref_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_valVref_burstCountSettings,
  output var logic           ltsm_flagToAnalog_valVref_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_valVref_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_valVref_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_valVref_dataPattern,
  output var logic           ltsm_flagToAnalog_valVref_clearComparisonErrors,
  output var logic           ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
  output var logic           ltsm_flagToAnalog_dataVref_sendPattern,
  input wire logic [dataLaneCount-1:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern,
  input wire logic           ltsm_flagFromAnalog_dataVref_finishedPattern,
  output var logic           ltsm_flagToAnalog_dataVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] ltsm_flagToAnalog_dataVref_rxVrefCodes,
  input wire logic           ltsm_flagFromAnalog_dataVref_rxVrefApplied,
  output var logic           ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_dataVref_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_dataVref_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_dataVref_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_dataVref_burstCountSettings,
  output var logic           ltsm_flagToAnalog_dataVref_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_dataVref_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_dataVref_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_dataVref_dataPattern,
  output var logic           ltsm_flagToAnalog_dataVref_clearComparisonErrors,
  output var logic           ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
  output var logic           ltsm_flagToAnalog_rxClkCal_doCalibration,
  input wire logic           ltsm_flagFromAnalog_rxClkCal_done,
  output var logic           ltsm_flagToAnalog_rxClkCal_sendClockTrack,
  output var logic           ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler,
  output var logic           ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode,
  input wire logic            ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied,
  output var logic           ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings,
  output var logic           ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern,
  output var logic           ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload,
  output var logic           ltsm_flagToAnalog_valTrainVref_sendPattern,
  input wire logic           ltsm_flagFromAnalog_valTrainVref_detectedValPattern,
  input wire logic           ltsm_flagFromAnalog_valTrainVref_finishedPattern,
  output var logic           ltsm_flagToAnalog_valTrainVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] ltsm_flagToAnalog_valTrainVref_rxVrefCode,
  input wire logic           ltsm_flagFromAnalog_valTrainVref_rxVrefApplied,
  output var logic           ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_valTrainVref_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_valTrainVref_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_valTrainVref_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_valTrainVref_burstCountSettings,
  output var logic           ltsm_flagToAnalog_valTrainVref_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_valTrainVref_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_valTrainVref_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_valTrainVref_dataPattern,
  output var logic           ltsm_flagToAnalog_valTrainVref_clearComparisonErrors,
  output var logic           ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode,
  input wire logic           ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes,
  input wire logic           ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload,
  output var logic           ltsm_flagToAnalog_dataTrainVref_sendPattern,
  input wire logic [dataLaneCount-1:0] ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern,
  input wire logic           ltsm_flagFromAnalog_dataTrainVref_finishedPattern,
  output var logic           ltsm_flagToAnalog_dataTrainVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] ltsm_flagToAnalog_dataTrainVref_rxVrefCodes,
  input wire logic           ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied,
  output var logic           ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_dataTrainVref_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_dataTrainVref_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_dataTrainVref_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_dataTrainVref_burstCountSettings,
  output var logic           ltsm_flagToAnalog_dataTrainVref_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_dataTrainVref_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_dataTrainVref_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_dataTrainVref_dataPattern,
  output var logic           ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors,
  output var logic           ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler,
  output var logic           ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
  input wire logic           ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
  output var logic           ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
  output var logic           ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
  output var logic [dataLaneCount*rxDeskewCodeWidth-1:0] ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
  input wire logic           ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
  output var logic           ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_rxDeskew_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_rxDeskew_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_rxDeskew_burstCountSettings,
  output var logic           ltsm_flagToAnalog_rxDeskew_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_rxDeskew_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_rxDeskew_dataPattern,
  output var logic           ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
  input wire logic [dataLaneCount-1:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler,
  output var logic           ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode,
  input wire logic            ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern,
  output var logic           ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload,
  output var logic           ltsm_flagToLtsm_linkSpeed_phyInRetrain,
  output var logic           ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler,
  output var logic           ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings,
  output var logic           ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern,
  output var logic           ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful,
  output var logic [3:0]     ltsm_dbg_mbtrainState,
  output var logic [11:0]    ltsm_dbg_mbtrainActiveSubstate,
  output var logic [15:0]    ltsm_dbg_mbtrainLastErrorCount,
  output var logic [15:0]    ltsm_dbg_mbtrainRetryCount,

  // Integration-level state/debug visibility.
  output var logic [3:0] debug_ltsm_state,
  output var logic       debug_ltsm_inband_pres,
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state,
  output var UcieUPM_interfaces_pkg::PhyState_t      debug_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t   debug_fdi_to_rdi_state_req,

  output var logic debug_arb_grant_ltsm,
  output var logic debug_arb_grant_fdi,
  output var logic debug_arb_grant_rdi,
  output var logic debug_arb_tx_locked,
  output var logic debug_arb_tx_fire,

  output var logic debug_rx_route_ltsm,
  output var logic debug_rx_route_fdi,
  output var logic debug_rx_route_rdi,
  output var logic debug_rx_drop_unknown,
  output var logic debug_rx_fire
);
  wire logic [3:0] ltsm_state_int;
  UcieUPM_interfaces_pkg::PhyState_t ltsmPhyState;
  wire logic       ltsmInbandPresent;

  wire logic         ltsm_raw_tx_valid;
  wire logic [127:0] ltsm_raw_tx_msg;
  wire logic         ltsm_raw_tx_ready;
  wire logic         ltsm_queue_tx_valid;
  wire logic [127:0] ltsm_queue_tx_msg;
  wire logic         ltsm_queue_tx_ready;

  wire logic         ltsm_stream_rx_valid;
  wire logic [127:0] ltsm_stream_rx_msg;
  wire logic         ltsm_stream_rx_ready;
  wire logic         ltsm_pulse_rx_valid;
  wire logic [127:0] ltsm_pulse_rx_msg;

  // The initial LTSM has no wake/clock handshake pins. Keep the RDI-side
  // compatibility handshake awake, matching the Chisel wrapper tie-offs.
  D2DAdapterLinkMgmtTop #(
    .FDI_WIDTH         (FDI_WIDTH),
    .FDI_DLLP_WIDTH    (FDI_DLLP_WIDTH),
    .FDI_SB_WIDTH      (FDI_SB_WIDTH),
    .RDI_WIDTH         (RDI_WIDTH),
    .RDI_SB_WIDTH      (RDI_SB_WIDTH),
    .SB_NODE_MSG_WIDTH (SB_NODE_MSG_WIDTH)
  ) linkMgmt (
    .clock                         (clock),
    .reset_n                       (reset_n),
    .fdi_lp_state_req              (fdi_lp_state_req),
    .fdi_lp_linkerror              (fdi_lp_linkerror),
    .fdi_lp_rx_active_sts          (fdi_lp_rx_active_sts),
    .fdi_lp_wake_req               (fdi_lp_wake_req),
    .fdi_lp_clk_ack                (fdi_lp_clk_ack),
    .fdi_lp_stall_ack              (fdi_lp_stall_ack),
    .fdi_pl_state_sts              (fdi_pl_state_sts),
    .fdi_pl_rx_active_req          (fdi_pl_rx_active_req),
    .fdi_pl_inband_pres            (fdi_pl_inband_pres),
    .fdi_pl_wake_ack               (fdi_pl_wake_ack),
    .fdi_pl_clk_req                (fdi_pl_clk_req),
    .fdi_pl_stall_req              (fdi_pl_stall_req),
    .ltsm_lp_wake_req              (1'b0),
    .ltsm_pl_wake_ack              (),
    .ltsm_lp_clk_ack               (1'b1),
    .ltsm_pl_clk_req               (),
    .ltsm_pl_inband_pres           (ltsmInbandPresent),
    .ltsm_sb_tx_valid              (ltsm_queue_tx_valid),
    .ltsm_sb_tx_msg                (ltsm_queue_tx_msg),
    .ltsm_sb_tx_ready              (ltsm_queue_tx_ready),
    .ltsm_sb_rx_valid              (ltsm_stream_rx_valid),
    .ltsm_sb_rx_msg                (ltsm_stream_rx_msg),
    .ltsm_sb_rx_ready              (ltsm_stream_rx_ready),
    .sb_tx_valid                   (sb_tx_valid),
    .sb_tx_msg                     (sb_tx_msg),
    .sb_tx_ready                   (sb_tx_ready),
    .sb_rx_valid                   (sb_rx_valid),
    .sb_rx_msg                     (sb_rx_msg),
    .sb_rx_ready                   (sb_rx_ready),
    .cycles_1us                    (cycles_1us),
    .debug_fdi_link_init_state     (debug_fdi_link_init_state),
    .debug_rdi_state               (debug_rdi_state),
    .debug_fdi_to_rdi_state_req    (debug_fdi_to_rdi_state_req),
    .debug_arb_grant_ltsm          (debug_arb_grant_ltsm),
    .debug_arb_grant_fdi           (debug_arb_grant_fdi),
    .debug_arb_grant_rdi           (debug_arb_grant_rdi),
    .debug_arb_tx_locked           (debug_arb_tx_locked),
    .debug_arb_rr_last_source      (),
    .debug_arb_rr_last_rdi         (),
    .debug_arb_tx_fire             (debug_arb_tx_fire),
    .debug_rx_route_ltsm           (debug_rx_route_ltsm),
    .debug_rx_route_fdi            (debug_rx_route_fdi),
    .debug_rx_route_rdi            (debug_rx_route_rdi),
    .debug_rx_drop_unknown         (debug_rx_drop_unknown),
    .debug_rx_fire                 (debug_rx_fire)
  );

  LtsmSidebandTxCapture #(
    .ENTRIES (4)
  ) ltsmTxCapture (
    .clock     (clock),
    .reset_n   (reset_n),
    .raw_valid (ltsm_raw_tx_valid),
    .raw_msg   (ltsm_raw_tx_msg),
    .raw_ready (ltsm_raw_tx_ready),
    .out_valid (ltsm_queue_tx_valid),
    .out_msg   (ltsm_queue_tx_msg),
    .out_ready (ltsm_queue_tx_ready)
  );

  LtsmSidebandRxPulseAdapter ltsmRxPulse (
    .clock     (clock),
    .reset_n   (reset_n),
    .in_valid  (ltsm_stream_rx_valid),
    .in_msg    (ltsm_stream_rx_msg),
    .in_ready  (ltsm_stream_rx_ready),
    .out_valid (ltsm_pulse_rx_valid),
    .out_msg   (ltsm_pulse_rx_msg)
  );

  // LinkTrainingFSM implementation is supplied separately. The direct port names
  // below intentionally preserve the names used by the Chisel instance.
  LinkTrainingFSM #(
    .sbFeatureExtension                       (sbFeatureExtension),
    .ucieA                                    (ucieA),
    .moduleID                                 (moduleID),
    .clkPhase                                 (clkPhase),
    .clkMode                                  (clkMode),
    .voltageSwing                             (voltageSwing),
    .maxLinkSpeed                             (maxLinkSpeed),
    .d2cPiCodeWidth                           (d2cPiCodeWidth),
    .d2cTxDeskewCodeWidth                     (d2cTxDeskewCodeWidth),
    .d2cDeskewStepsPerPi                      (d2cDeskewStepsPerPi),
    .d2cDeskewAddDelayIncreasesPhase          (d2cDeskewAddDelayIncreasesPhase),
    .d2cMaximumComparisonErrorThreshold       (d2cMaximumComparisonErrorThreshold),
    .d2cMinLaneWindowSteps                    (d2cMinLaneWindowSteps),
    .d2cMinCommonWindowSteps                  (d2cMinCommonWindowSteps),
    .d2cMaxTrainingRetries                    (d2cMaxTrainingRetries),
    .validVrefValueCount                      (validVrefValueCount),
    .validVrefCodeWidth                       (validVrefCodeWidth),
    .validVrefMinimumMillivolts               (validVrefMinimumMillivolts),
    .validVrefMaximumMillivolts               (validVrefMaximumMillivolts),
    .validVrefMaximumComparisonErrorThreshold (validVrefMaximumComparisonErrorThreshold),
    .validVrefMinPassingWindowValues          (validVrefMinPassingWindowValues),
    .validVrefMaxTrainingRetries              (validVrefMaxTrainingRetries),
    .valTrainVrefEnable                       (valTrainVrefEnable),
    .dataLaneCount                            (dataLaneCount),
    .activeDataLaneMask                       (activeDataLaneMask),
    .dataVrefValueCount                       (dataVrefValueCount),
    .dataVrefCodeWidth                        (dataVrefCodeWidth),
    .dataVrefMinimumMillivolts                (dataVrefMinimumMillivolts),
    .dataVrefMaximumMillivolts                (dataVrefMaximumMillivolts),
    .dataVrefMaximumComparisonErrorThreshold  (dataVrefMaximumComparisonErrorThreshold),
    .dataVrefMinPassingWindowValues           (dataVrefMinPassingWindowValues),
    .dataVrefMaxTrainingRetries               (dataVrefMaxTrainingRetries),
    .dataTrainVrefEnable                      (dataTrainVrefEnable),
    .rxDeskewEnable                           (rxDeskewEnable),
    .rxDeskewValueCount                       (rxDeskewValueCount),
    .rxDeskewCodeWidth                        (rxDeskewCodeWidth),
    .rxDeskewMaximumComparisonErrorThreshold  (rxDeskewMaximumComparisonErrorThreshold),
    .rxDeskewMinPassingWindowValues           (rxDeskewMinPassingWindowValues),
    .rxDeskewMaxTrainingRetries               (rxDeskewMaxTrainingRetries)
  ) ltsm (
    .clock                                                                     (clock),
    .reset_n                                                                   (reset_n),
    .sb_tx_din                                                                 (ltsm_raw_tx_msg),
    .sb_tx_valid                                                               (ltsm_raw_tx_valid),
    .sb_tx_ready                                                               (ltsm_raw_tx_ready),
    .sb_rx_dout                                                                (ltsm_pulse_rx_msg),
    .sb_rx_valid                                                               (ltsm_pulse_rx_valid),
    .start                                                                     (ltsm_start),
    .stable_clk                                                                (ltsm_stable_clk),
    .pll_locked                                                                (ltsm_pll_locked),
    .stable_supply                                                             (ltsm_stable_supply),
    .flagFromAnalog_ReadyToExchangeClkPatterns                                 (ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
    .flagFromAnalog_FinishedClkPatterns                                        (ltsm_flagFromAnalog_FinishedClkPatterns),
    .flagFromAnalog_FinishedValTrainPattern                                    (ltsm_flagFromAnalog_FinishedValTrainPattern),
    .flagFromAnalog_ReversalMbFinishedLaneIDPattern                            (ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .flagFromAnalog_RepairMbFinishedLaneIDPattern                              (ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .flagFromAnalog_clkPatternReceivedRTRK_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
    .flagFromAnalog_clkPatternReceivedRCKN_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
    .flagFromAnalog_clkPatternReceivedRCKP_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
    .flagFromAnalog_ValTrainPatternReceived                                    (ltsm_flagFromAnalog_ValTrainPatternReceived),
    .flagFromAnalog_ReversalMbTrainPatternReceived0                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .flagFromAnalog_ReversalMbTrainPatternReceived1                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .flagFromAnalog_ReversalMbTrainPatternReceived2                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .flagFromAnalog_ReversalMbTrainPatternReceived3                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .flagFromAnalog_ReversalMbTrainPatternReceived4                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .flagFromAnalog_ReversalMbTrainPatternReceived5                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .flagFromAnalog_ReversalMbTrainPatternReceived6                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .flagFromAnalog_ReversalMbTrainPatternReceived7                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .flagFromAnalog_ReversalMbTrainPatternReceived8                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .flagFromAnalog_ReversalMbTrainPatternReceived9                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .flagFromAnalog_ReversalMbTrainPatternReceived10                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .flagFromAnalog_ReversalMbTrainPatternReceived11                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .flagFromAnalog_ReversalMbTrainPatternReceived12                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .flagFromAnalog_ReversalMbTrainPatternReceived13                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .flagFromAnalog_ReversalMbTrainPatternReceived14                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .flagFromAnalog_ReversalMbTrainPatternReceived15                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern0                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern1                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern2                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern3                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern4                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern5                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern6                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern7                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern8                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern9                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern10                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern11                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern12                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern13                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern14                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern15                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .flagToAnalog_RepairClkState                                               (ltsm_flagToAnalog_RepairClkState),
    .flagToAnalog_SendClkPatterns                                              (ltsm_flagToAnalog_SendClkPatterns),
    .flagToAnalog_RepairValState                                               (ltsm_flagToAnalog_RepairValState),
    .flagToAnalog_SendValTrainPattern                                          (ltsm_flagToAnalog_SendValTrainPattern),
    .flagToAnalog_ReversalMbSendLaneIDPattern                                  (ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .flagToAnalog_RepairMbSendLaneIDPattern                                    (ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .flagToAnalog_RepairMbSetReceiver                                          (ltsm_flagToAnalog_RepairMbSetReceiver),
    .flagToAnalog_LaneReversalApplied                                          (ltsm_flagToAnalog_LaneReversalApplied),
    .flagToAnalog_linkInit_resetLfsrScrambler                                  (ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .state                                                                     (ltsm_state_int),
    .dbg_flagSbinitFirstClkPatternSeen                                         (ltsm_dbg_flagSbinitFirstClkPatternSeen),
    .dbg_rxValidRisingEdge                                                     (ltsm_dbg_rxValidRisingEdge),
    .dbg_sbinitSendCount                                                       (ltsm_dbg_sbinitSendCount),
    .dbg_sbTxValid                                                             (ltsm_dbg_sbTxValid),
    .dbg_sbTxDin                                                               (ltsm_dbg_sbTxDin),
    .dbg_flagTrainError                                                        (ltsm_dbg_flagTrainError),
    .dbg_mbinitSubstate                                                        (ltsm_dbg_mbinitSubstate),
    .dbg_mbinitReversalMbReceivedSuccessCount                                  (ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
    .flagToAnalog_valVref_sendPattern                                          (ltsm_flagToAnalog_valVref_sendPattern),
    .flagFromAnalog_valVref_detectedValPattern                                 (ltsm_flagFromAnalog_valVref_detectedValPattern),
    .flagFromAnalog_valVref_finishedPattern                                    (ltsm_flagFromAnalog_valVref_finishedPattern),
    .flagToAnalog_valVref_applyRxVref                                          (ltsm_flagToAnalog_valVref_applyRxVref),
    .flagToAnalog_valVref_rxVrefCode                                           (ltsm_flagToAnalog_valVref_rxVrefCode),
    .flagFromAnalog_valVref_rxVrefApplied                                      (ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .flagToAnalog_valVref_configureRxInitD2CPointTest                          (ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .flagToAnalog_valVref_maximumComparisonErrorThreshold                      (ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valVref_comparisonMode                                       (ltsm_flagToAnalog_valVref_comparisonMode),
    .flagToAnalog_valVref_iterationCountSettings                               (ltsm_flagToAnalog_valVref_iterationCountSettings),
    .flagToAnalog_valVref_idleCountSettings                                    (ltsm_flagToAnalog_valVref_idleCountSettings),
    .flagToAnalog_valVref_burstCountSettings                                   (ltsm_flagToAnalog_valVref_burstCountSettings),
    .flagToAnalog_valVref_patternMode                                          (ltsm_flagToAnalog_valVref_patternMode),
    .flagToAnalog_valVref_clockPhaseControl                                    (ltsm_flagToAnalog_valVref_clockPhaseControl),
    .flagToAnalog_valVref_validPattern                                         (ltsm_flagToAnalog_valVref_validPattern),
    .flagToAnalog_valVref_dataPattern                                          (ltsm_flagToAnalog_valVref_dataPattern),
    .flagToAnalog_valVref_clearComparisonErrors                                (ltsm_flagToAnalog_valVref_clearComparisonErrors),
    .flagToAnalog_valVref_resetLocalTxScrambler                                (ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .flagToAnalog_dataVref_sendPattern                                         (ltsm_flagToAnalog_dataVref_sendPattern),
    .flagFromAnalog_dataVref_detectedDataPattern                               (ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .flagFromAnalog_dataVref_finishedPattern                                   (ltsm_flagFromAnalog_dataVref_finishedPattern),
    .flagToAnalog_dataVref_applyRxVref                                         (ltsm_flagToAnalog_dataVref_applyRxVref),
    .flagToAnalog_dataVref_rxVrefCodes                                         (ltsm_flagToAnalog_dataVref_rxVrefCodes),
    .flagFromAnalog_dataVref_rxVrefApplied                                     (ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .flagToAnalog_dataVref_configureRxInitD2CPointTest                         (ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .flagToAnalog_dataVref_comparisonMode                                      (ltsm_flagToAnalog_dataVref_comparisonMode),
    .flagToAnalog_dataVref_iterationCountSettings                              (ltsm_flagToAnalog_dataVref_iterationCountSettings),
    .flagToAnalog_dataVref_idleCountSettings                                   (ltsm_flagToAnalog_dataVref_idleCountSettings),
    .flagToAnalog_dataVref_burstCountSettings                                  (ltsm_flagToAnalog_dataVref_burstCountSettings),
    .flagToAnalog_dataVref_patternMode                                         (ltsm_flagToAnalog_dataVref_patternMode),
    .flagToAnalog_dataVref_clockPhaseControl                                   (ltsm_flagToAnalog_dataVref_clockPhaseControl),
    .flagToAnalog_dataVref_validPattern                                        (ltsm_flagToAnalog_dataVref_validPattern),
    .flagToAnalog_dataVref_dataPattern                                         (ltsm_flagToAnalog_dataVref_dataPattern),
    .flagToAnalog_dataVref_clearComparisonErrors                               (ltsm_flagToAnalog_dataVref_clearComparisonErrors),
    .flagToAnalog_dataVref_resetLocalTxScrambler                               (ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .flagToAnalog_rxClkCal_doCalibration                                       (ltsm_flagToAnalog_rxClkCal_doCalibration),
    .flagFromAnalog_rxClkCal_done                                              (ltsm_flagFromAnalog_rxClkCal_done),
    .flagToAnalog_rxClkCal_sendClockTrack                                      (ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern                 (ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent               (ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler                 (ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase                   (ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode                    (ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied               (ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold   (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode                    (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings            (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings                 (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings                (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .flagToAnalog_d2cReceiver_valTrainCenter_patternMode                       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl                 (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .flagToAnalog_d2cReceiver_valTrainCenter_validPattern                      (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .flagToAnalog_d2cReceiver_valTrainCenter_dataPattern                       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler             (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo         (ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload         (ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .flagToAnalog_valTrainVref_sendPattern                                     (ltsm_flagToAnalog_valTrainVref_sendPattern),
    .flagFromAnalog_valTrainVref_detectedValPattern                            (ltsm_flagFromAnalog_valTrainVref_detectedValPattern),
    .flagFromAnalog_valTrainVref_finishedPattern                               (ltsm_flagFromAnalog_valTrainVref_finishedPattern),
    .flagToAnalog_valTrainVref_applyRxVref                                     (ltsm_flagToAnalog_valTrainVref_applyRxVref),
    .flagToAnalog_valTrainVref_rxVrefCode                                      (ltsm_flagToAnalog_valTrainVref_rxVrefCode),
    .flagFromAnalog_valTrainVref_rxVrefApplied                                 (ltsm_flagFromAnalog_valTrainVref_rxVrefApplied),
    .flagToAnalog_valTrainVref_configureRxInitD2CPointTest                     (ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_valTrainVref_maximumComparisonErrorThreshold                 (ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valTrainVref_comparisonMode                                  (ltsm_flagToAnalog_valTrainVref_comparisonMode),
    .flagToAnalog_valTrainVref_iterationCountSettings                          (ltsm_flagToAnalog_valTrainVref_iterationCountSettings),
    .flagToAnalog_valTrainVref_idleCountSettings                               (ltsm_flagToAnalog_valTrainVref_idleCountSettings),
    .flagToAnalog_valTrainVref_burstCountSettings                              (ltsm_flagToAnalog_valTrainVref_burstCountSettings),
    .flagToAnalog_valTrainVref_patternMode                                     (ltsm_flagToAnalog_valTrainVref_patternMode),
    .flagToAnalog_valTrainVref_clockPhaseControl                               (ltsm_flagToAnalog_valTrainVref_clockPhaseControl),
    .flagToAnalog_valTrainVref_validPattern                                    (ltsm_flagToAnalog_valTrainVref_validPattern),
    .flagToAnalog_valTrainVref_dataPattern                                     (ltsm_flagToAnalog_valTrainVref_dataPattern),
    .flagToAnalog_valTrainVref_clearComparisonErrors                           (ltsm_flagToAnalog_valTrainVref_clearComparisonErrors),
    .flagToAnalog_valTrainVref_resetLocalTxScrambler                           (ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern                   (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent                 (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler               (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode                  (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode                  (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings          (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings              (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern                    (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler           (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .flagToAnalog_dataTrainVref_sendPattern                                    (ltsm_flagToAnalog_dataTrainVref_sendPattern),
    .flagFromAnalog_dataTrainVref_detectedDataPattern                          (ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern),
    .flagFromAnalog_dataTrainVref_finishedPattern                              (ltsm_flagFromAnalog_dataTrainVref_finishedPattern),
    .flagToAnalog_dataTrainVref_applyRxVref                                    (ltsm_flagToAnalog_dataTrainVref_applyRxVref),
    .flagToAnalog_dataTrainVref_rxVrefCodes                                    (ltsm_flagToAnalog_dataTrainVref_rxVrefCodes),
    .flagFromAnalog_dataTrainVref_rxVrefApplied                                (ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied),
    .flagToAnalog_dataTrainVref_configureRxInitD2CPointTest                    (ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold                (ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_dataTrainVref_comparisonMode                                 (ltsm_flagToAnalog_dataTrainVref_comparisonMode),
    .flagToAnalog_dataTrainVref_iterationCountSettings                         (ltsm_flagToAnalog_dataTrainVref_iterationCountSettings),
    .flagToAnalog_dataTrainVref_idleCountSettings                              (ltsm_flagToAnalog_dataTrainVref_idleCountSettings),
    .flagToAnalog_dataTrainVref_burstCountSettings                             (ltsm_flagToAnalog_dataTrainVref_burstCountSettings),
    .flagToAnalog_dataTrainVref_patternMode                                    (ltsm_flagToAnalog_dataTrainVref_patternMode),
    .flagToAnalog_dataTrainVref_clockPhaseControl                              (ltsm_flagToAnalog_dataTrainVref_clockPhaseControl),
    .flagToAnalog_dataTrainVref_validPattern                                   (ltsm_flagToAnalog_dataTrainVref_validPattern),
    .flagToAnalog_dataTrainVref_dataPattern                                    (ltsm_flagToAnalog_dataTrainVref_dataPattern),
    .flagToAnalog_dataTrainVref_clearComparisonErrors                          (ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors),
    .flagToAnalog_dataTrainVref_resetLocalTxScrambler                          (ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler),
    .flagToAnalog_rxDeskew_sendLfsrPattern                                     (ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .flagFromAnalog_rxDeskew_lfsrPatternSent                                   (ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .flagToAnalog_rxDeskew_resetLocalTxScrambler                               (ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .flagToAnalog_rxDeskew_applyRxLaneDeskew                                   (ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .flagToAnalog_rxDeskew_rxLaneDeskewCodes                                   (ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .flagFromAnalog_rxDeskew_rxLaneDeskewApplied                               (ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .flagToAnalog_rxDeskew_configureRxInitD2CPointTest                         (ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                     (ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .flagToAnalog_rxDeskew_comparisonMode                                      (ltsm_flagToAnalog_rxDeskew_comparisonMode),
    .flagToAnalog_rxDeskew_iterationCountSettings                              (ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .flagToAnalog_rxDeskew_idleCountSettings                                   (ltsm_flagToAnalog_rxDeskew_idleCountSettings),
    .flagToAnalog_rxDeskew_burstCountSettings                                  (ltsm_flagToAnalog_rxDeskew_burstCountSettings),
    .flagToAnalog_rxDeskew_patternMode                                         (ltsm_flagToAnalog_rxDeskew_patternMode),
    .flagToAnalog_rxDeskew_clockPhaseControl                                   (ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .flagToAnalog_rxDeskew_validPattern                                        (ltsm_flagToAnalog_rxDeskew_validPattern),
    .flagToAnalog_rxDeskew_dataPattern                                         (ltsm_flagToAnalog_rxDeskew_dataPattern),
    .flagToAnalog_rxDeskew_clearComparisonErrors                               (ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .flagFromAnalog_rxDeskew_detectedDataPattern                               (ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern                   (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent                 (ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler               (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode                  (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode                  (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings          (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings              (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern                    (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler           (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .flagToLtsm_linkSpeed_phyInRetrain                                         (ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern                          (ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent                        (ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler                      (ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold        (ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_linkSpeed_comparisonMode                         (ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings                 (ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings                      (ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings                     (ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .flagToAnalog_d2cReceiver_linkSpeed_patternMode                            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl                      (ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .flagToAnalog_d2cReceiver_linkSpeed_validPattern                           (ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .flagToAnalog_d2cReceiver_linkSpeed_dataPattern                            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler                  (ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful             (ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
    .dbg_mbtrainState                                                          (ltsm_dbg_mbtrainState),
    .dbg_mbtrainActiveSubstate                                                 (ltsm_dbg_mbtrainActiveSubstate),
    .dbg_mbtrainLastErrorCount                                                 (ltsm_dbg_mbtrainLastErrorCount),
    .dbg_mbtrainRetryCount                                                     (ltsm_dbg_mbtrainRetryCount)
  );

  // LinkTrainingFSM.state uses a private ten-state encoding. Convert it to
  // the shared PHY-state type from Types.sv for adapter integration. All
  // pre-ACTIVE training phases remain in PHY Reset; training failure reports
  // PHY LinkError.
  always_comb begin
    case (ltsm_state_int)
      4'd0, 4'd1, 4'd2, 4'd3,
      4'd4, 4'd5, 4'd6, 4'd7:
        ltsmPhyState = UcieUPM_interfaces_pkg::PhyState_reset;
      4'd8:
        ltsmPhyState = UcieUPM_interfaces_pkg::PhyState_active;
      4'd9:
        ltsmPhyState = UcieUPM_interfaces_pkg::PhyState_linkError;
      default:
        ltsmPhyState = UcieUPM_interfaces_pkg::PhyState_linkError;
    endcase
  end

  assign ltsmInbandPresent =
    (ltsmPhyState == UcieUPM_interfaces_pkg::PhyState_active);

  always_comb begin
    ltsm_state                 = ltsm_state_int;
    debug_ltsm_state           = ltsm_state_int;
    debug_ltsm_inband_pres     = ltsmInbandPresent;
  end
endmodule

`default_nettype wire

```

<a id="D2DAdapterLinkMgmtTop-sv"></a>

## [3] D2DAdapterLinkMgmtTop.sv

```systemverilog
// FILE_INDEX: 3
// FILE_PATH : D2DAdapterLinkMgmtTop.sv

// Hand-translated synthesizable SystemVerilog.
// Source: D2DAdapterLinkMgmtTop(7).scala
// This is the integrated FDI + RDI + three-client sideband-arbiter wrapper.
// Reset convention: asynchronous active-low reset_n is passed to every child module.

`default_nettype none

module D2DAdapterLinkMgmtTop #(
  parameter int unsigned FDI_WIDTH         = UcieUPM_fdi_params_pkg::FDI_WIDTH,
  parameter int unsigned FDI_DLLP_WIDTH    = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH,
  parameter int unsigned FDI_SB_WIDTH      = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH,
  parameter int unsigned RDI_WIDTH         = UcieUPM_rdi_params_pkg::RDI_WIDTH,
  parameter int unsigned RDI_SB_WIDTH      = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH,
  parameter int unsigned SB_NODE_MSG_WIDTH = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH
) (
  input wire logic clock,
  input wire logic reset_n,

  // Protocol-facing FDI side.
  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input  wire logic                                  fdi_lp_linkerror,
  input  wire logic                                  fdi_lp_rx_active_sts,
  input  wire logic                                  fdi_lp_wake_req,
  input  wire logic                                  fdi_lp_clk_ack,
  input  wire logic                                  fdi_lp_stall_ack,

  output var UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts,
  output var logic                               fdi_pl_rx_active_req,
  output var logic                               fdi_pl_inband_pres,
  output var logic                               fdi_pl_wake_ack,
  output var logic                               fdi_pl_clk_req,
  output var logic                               fdi_pl_stall_req,

  // LTSM / PHY-facing control side from RDI.
  input  wire logic ltsm_lp_wake_req,
  output var logic ltsm_pl_wake_ack,
  input  wire logic ltsm_lp_clk_ack,
  output var logic ltsm_pl_clk_req,
  input  wire logic ltsm_pl_inband_pres,

  // External LTSM sideband-message producer and sink.
  input  wire logic         ltsm_sb_tx_valid,
  input  wire logic [127:0] ltsm_sb_tx_msg,
  output var logic         ltsm_sb_tx_ready,

  output var logic         ltsm_sb_rx_valid,
  output var logic [127:0] ltsm_sb_rx_msg,
  input  wire logic         ltsm_sb_rx_ready,

  // Shared abstract 128-bit sideband-message transport.
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_msg,
  input  wire logic         sb_tx_ready,

  input  wire logic         sb_rx_valid,
  input  wire logic [127:0] sb_rx_msg,
  output var logic         sb_rx_ready,

  input  wire logic [31:0] cycles_1us,

  // Debug / waveform visibility.
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state,
  output var UcieUPM_interfaces_pkg::PhyState_t      debug_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t   debug_fdi_to_rdi_state_req,

  output var logic       debug_arb_grant_ltsm,
  output var logic       debug_arb_grant_fdi,
  output var logic       debug_arb_grant_rdi,
  output var logic       debug_arb_tx_locked,
  output var logic [1:0] debug_arb_rr_last_source,
  output var logic       debug_arb_rr_last_rdi,
  output var logic       debug_arb_tx_fire,

  output var logic debug_rx_route_ltsm,
  output var logic debug_rx_route_fdi,
  output var logic debug_rx_route_rdi,
  output var logic debug_rx_drop_unknown,
  output var logic debug_rx_fire
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  // FDI <-> RDI bridge signals.
  logic         fdi_rdi_lp_linkerror;
  PhyStateReq_t fdi_rdi_lp_state_req;
  PhyState_t    rdi_pl_state_sts_int;
  logic         rdi_pl_inband_pres_int;
  logic         rdi_pl_stall_req_int;
  logic         fdi_rdi_lp_stall_ack;
  logic         rdiAwake_int;
  logic         rdiNeedsFdiAwake_int;
  logic         fdiAwake_int;
  logic         fdiNeedsRdiAwake_int;

  // FDI sideband client.
  logic         fdi_sb_snd_valid;
  logic [127:0] fdi_sb_snd_msg;
  logic         fdi_sb_snd_ready;
  logic         fdi_sb_rcv_valid;
  logic [127:0] fdi_sb_rcv_msg;
  logic         fdi_sb_rcv_ready;

  // RDI sideband client.
  logic         rdi_sb_snd_valid;
  logic [127:0] rdi_sb_snd_msg;
  logic         rdi_sb_snd_ready;
  logic         rdi_sb_rcv_valid;
  logic [127:0] rdi_sb_rcv_msg;
  logic         rdi_sb_rcv_ready;

  LinkManagementController #(
    .FDI_WIDTH         (FDI_WIDTH),
    .FDI_DLLP_WIDTH    (FDI_DLLP_WIDTH),
    .FDI_SB_WIDTH      (FDI_SB_WIDTH),
    .RDI_WIDTH         (RDI_WIDTH),
    .RDI_SB_WIDTH      (RDI_SB_WIDTH),
    .SB_NODE_MSG_WIDTH (SB_NODE_MSG_WIDTH)
  ) fdi (
    .clock                (clock),
    .reset_n              (reset_n),

    .fdi_lp_state_req     (fdi_lp_state_req),
    .fdi_lp_linkerror     (fdi_lp_linkerror),
    .fdi_lp_rx_active_sts (fdi_lp_rx_active_sts),
    .fdi_pl_state_sts     (fdi_pl_state_sts),
    .fdi_pl_rx_active_req (fdi_pl_rx_active_req),
    .fdi_pl_inband_pres   (fdi_pl_inband_pres),
    .fdi_pl_wake_ack      (fdi_pl_wake_ack),
    .fdi_lp_wake_req      (fdi_lp_wake_req),
    .fdi_pl_clk_req       (fdi_pl_clk_req),
    .fdi_lp_clk_ack       (fdi_lp_clk_ack),
    .fdi_pl_stall_req     (fdi_pl_stall_req),
    .fdi_lp_stall_ack     (fdi_lp_stall_ack),

    .debug_link_init_state(debug_fdi_link_init_state),

    .rdi_lp_linkerror     (fdi_rdi_lp_linkerror),
    .rdi_lp_state_req     (fdi_rdi_lp_state_req),
    .rdi_pl_state_sts     (rdi_pl_state_sts_int),
    .rdi_pl_inband_pres   (rdi_pl_inband_pres_int),

    .fdiNeedsRdiAwake     (fdiNeedsRdiAwake_int),
    .rdiAwake             (rdiAwake_int),
    .rdiNeedsFdiAwake     (rdiNeedsFdiAwake_int),
    .fdiAwake             (fdiAwake_int),

    .rdi_pl_stall_req     (rdi_pl_stall_req_int),
    .rdi_lp_stall_ack     (fdi_rdi_lp_stall_ack),

    .sb_snd_valid         (fdi_sb_snd_valid),
    .sb_snd_msg           (fdi_sb_snd_msg),
    .sb_snd_ready         (fdi_sb_snd_ready),
    .sb_rcv_valid         (fdi_sb_rcv_valid),
    .sb_rcv_msg           (fdi_sb_rcv_msg),
    .sb_rcv_ready         (fdi_sb_rcv_ready),
    .cycles_1us           (cycles_1us)
  );

  RdiLinkManagementController rdi (
    .clock                (clock),
    .reset_n              (reset_n),

    .ltsm_lp_wake_req     (ltsm_lp_wake_req),
    .ltsm_pl_wake_ack     (ltsm_pl_wake_ack),
    .ltsm_pl_clk_req      (ltsm_pl_clk_req),
    .ltsm_lp_clk_ack      (ltsm_lp_clk_ack),

    .lp_state_req         (fdi_rdi_lp_state_req),
    .pl_state_sts         (rdi_pl_state_sts_int),
    .pl_stallreq          (rdi_pl_stall_req_int),
    .lp_stallack          (fdi_rdi_lp_stall_ack),
    .rdi_pl_inband_pres   (rdi_pl_inband_pres_int),
    .ltsm_pl_inband_pres  (ltsm_pl_inband_pres),

    .fdiNeedsRdiAwake     (fdiNeedsRdiAwake_int),
    .rdiAwake             (rdiAwake_int),
    .rdiNeedsFdiAwake     (rdiNeedsFdiAwake_int),
    .fdiAwake             (fdiAwake_int),

    .sb_snd_valid         (rdi_sb_snd_valid),
    .sb_snd_msg           (rdi_sb_snd_msg),
    .sb_snd_ready         (rdi_sb_snd_ready),
    .sb_rcv_valid         (rdi_sb_rcv_valid),
    .sb_rcv_msg           (rdi_sb_rcv_msg),
    .sb_rcv_ready         (rdi_sb_rcv_ready),

    .lp_linkerror         (fdi_rdi_lp_linkerror),
    .pl_phyinrecenter     (),
    .cycles_1us           (cycles_1us)
  );

  LinkMgmtSidebandPacketArbiter arb (
    .clock                 (clock),
    .reset_n               (reset_n),

    .ltsm_tx_valid         (ltsm_sb_tx_valid),
    .ltsm_tx_msg           (ltsm_sb_tx_msg),
    .ltsm_tx_ready         (ltsm_sb_tx_ready),

    .fdi_tx_valid          (fdi_sb_snd_valid),
    .fdi_tx_msg            (fdi_sb_snd_msg),
    .fdi_tx_ready          (fdi_sb_snd_ready),

    .rdi_tx_valid          (rdi_sb_snd_valid),
    .rdi_tx_msg            (rdi_sb_snd_msg),
    .rdi_tx_ready          (rdi_sb_snd_ready),

    .tx_out_valid          (sb_tx_valid),
    .tx_out_msg            (sb_tx_msg),
    .tx_out_ready          (sb_tx_ready),

    .rx_in_valid           (sb_rx_valid),
    .rx_in_msg             (sb_rx_msg),
    .rx_in_ready           (sb_rx_ready),

    .ltsm_rx_valid         (ltsm_sb_rx_valid),
    .ltsm_rx_msg           (ltsm_sb_rx_msg),
    .ltsm_rx_ready         (ltsm_sb_rx_ready),

    .fdi_rx_valid          (fdi_sb_rcv_valid),
    .fdi_rx_msg            (fdi_sb_rcv_msg),
    .fdi_rx_ready          (fdi_sb_rcv_ready),

    .rdi_rx_valid          (rdi_sb_rcv_valid),
    .rdi_rx_msg            (rdi_sb_rcv_msg),
    .rdi_rx_ready          (rdi_sb_rcv_ready),

    .grant_ltsm            (debug_arb_grant_ltsm),
    .grant_fdi             (debug_arb_grant_fdi),
    .grant_rdi             (debug_arb_grant_rdi),
    .tx_locked             (debug_arb_tx_locked),
    .rr_last_source        (debug_arb_rr_last_source),
    .rr_last_granted_rdi   (debug_arb_rr_last_rdi),
    .tx_fire               (debug_arb_tx_fire),

    .rx_route_ltsm         (debug_rx_route_ltsm),
    .rx_route_fdi          (debug_rx_route_fdi),
    .rx_route_rdi          (debug_rx_route_rdi),
    .rx_drop_unknown       (debug_rx_drop_unknown),
    .rx_fire               (debug_rx_fire)
  );

  assign debug_rdi_state            = rdi_pl_state_sts_int;
  assign debug_fdi_to_rdi_state_req = fdi_rdi_lp_state_req;
endmodule

`default_nettype wire

```

<a id="Fdi-sv"></a>

## [4] Fdi.sv

```systemverilog
// FILE_INDEX: 4
// FILE_PATH : Fdi.sv

// Hand-translated synthesizable SystemVerilog.
// Source: Fdi(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_fdi_params_pkg;
  // SystemVerilog equivalent of the Scala elaboration-time FdiParams defaults.
  parameter int unsigned FDI_WIDTH      = 64;
  parameter int unsigned FDI_DLLP_WIDTH = 128;
  parameter int unsigned FDI_SB_WIDTH   = 128;
endpackage

`default_nettype wire

```

<a id="LinkManagementController-sv"></a>

## [5] LinkManagementController.sv

```systemverilog
// FILE_INDEX: 5
// FILE_PATH : LinkManagementController.sv

// Hand-translated synthesizable SystemVerilog.
// Source: LinkManagementController(1).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module LinkManagementController #(
  parameter int unsigned FDI_WIDTH          = UcieUPM_fdi_params_pkg::FDI_WIDTH,
  parameter int unsigned FDI_DLLP_WIDTH     = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH,
  parameter int unsigned FDI_SB_WIDTH       = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH,
  parameter int unsigned RDI_WIDTH          = UcieUPM_rdi_params_pkg::RDI_WIDTH,
  parameter int unsigned RDI_SB_WIDTH       = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH,
  parameter int unsigned SB_NODE_MSG_WIDTH  = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH
) (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input  wire logic                                  fdi_lp_linkerror,
  input  wire logic                                  fdi_lp_rx_active_sts,
  output var UcieUPM_interfaces_pkg::PhyState_t    fdi_pl_state_sts,
  output var logic                                  fdi_pl_rx_active_req,
  output var logic                                  fdi_pl_inband_pres,
  output var logic                                  fdi_pl_wake_ack,
  input  wire logic                                  fdi_lp_wake_req,
  output var logic                                  fdi_pl_clk_req,
  input  wire logic                                  fdi_lp_clk_ack,
  output var logic                                  fdi_pl_stall_req,
  input  wire logic                                  fdi_lp_stall_ack,

  output var UcieUPM_d2dadapter_pkg::LinkInitState_t debug_link_init_state,

  output var logic                                  rdi_lp_linkerror,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t rdi_lp_state_req,
  input  wire UcieUPM_interfaces_pkg::PhyState_t    rdi_pl_state_sts,
  input  wire logic                                  rdi_pl_inband_pres,

  output var logic fdiNeedsRdiAwake,
  input  wire logic rdiAwake,
  input  wire logic rdiNeedsFdiAwake,
  output var logic fdiAwake,

  input  wire logic rdi_pl_stall_req,
  output var logic rdi_lp_stall_ack,

  output var logic         sb_snd_valid,
  output var logic [127:0] sb_snd_msg,
  input  wire logic         sb_snd_ready,

  input  wire logic         sb_rcv_valid,
  input  wire logic [127:0] sb_rcv_msg,
  output var logic         sb_rcv_ready,

  input  wire logic [31:0] cycles_1us
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;
  import SidebandMsgGenerator_pkg::*;

  function automatic logic [127:0] zeroMessage();
    zeroMessage = 128'b0;
  endfunction

  // Sideband registered producer.
  (* keep = "true" *) logic [127:0] sb_snd_msg_reg;
  (* keep = "true" *) logic         sb_snd_vld_reg;
  logic [127:0] sb_snd_msg_reg_next;
  logic         sb_snd_vld_reg_next;
  logic [127:0] sb_snd_msg_next;
  logic         sb_snd_vld_next;

  assign sb_snd_msg   = sb_snd_msg_reg;
  assign sb_snd_valid = sb_snd_vld_reg;
  assign sb_rcv_ready = 1'b1;

  logic txFire;
  logic rxFire;
  assign txFire = sb_snd_valid && sb_snd_ready;
  assign rxFire = sb_rcv_valid && sb_rcv_ready;

  // Explicit sideband decode signals are retained for readable waves.
  (* keep = "true" *) logic [127:0] tx_message;
  (* keep = "true" *) logic [63:0]  tx_header;
  (* keep = "true" *) logic [63:0]  tx_payload;
  (* keep = "true" *) logic         tx_hasPayload;
  (* keep = "true" *) logic [127:0] rx_message;
  (* keep = "true" *) logic [63:0]  rx_header;
  (* keep = "true" *) logic [63:0]  rx_payload;
  (* keep = "true" *) logic         rx_hasPayload;
  (* keep = "true" *) logic [7:0]   tx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgCode;
  (* keep = "true" *) logic [15:0]  rx_msgInfo;

  logic tx_is_adapter_req;
  logic tx_is_adapter_rsp;
  logic rx_is_adapter_req;
  logic rx_is_adapter_rsp;
  (* keep = "true" *) logic rx_is_param_exchange;
  (* keep = "true" *) logic rx_is_param_exchange_stall;
  (* keep = "true" *) logic rx_is_adv_cap_adapter;
  (* keep = "true" *) logic rx_is_adv_cap_adapter_stall;
  (* keep = "true" *) logic rx_is_adv_cap_adapter_nonstall;

  assign tx_message    = sb_snd_msg_reg;
  assign tx_header     = headerOf(tx_message);
  assign tx_payload    = payloadOf(tx_message);
  assign tx_hasPayload = hasPayload(tx_message);
  assign rx_message    = sb_rcv_msg;
  assign rx_header     = headerOf(rx_message);
  assign rx_payload    = payloadOf(rx_message);
  assign rx_hasPayload = hasPayload(rx_message);

  assign tx_msgSub  = UCIe2_Field_msgSub({64'b0, tx_header});
  assign rx_msgSub  = UCIe2_Field_msgSub({64'b0, rx_header});
  assign rx_msgCode = UCIe2_Field_msgCode({64'b0, rx_header});
  assign rx_msgInfo = UCIe2_Field_msgInfo({64'b0, rx_header});

  assign tx_is_adapter_req = UCIe2_isAdapterLinkMgmtReq({64'b0, tx_header});
  assign tx_is_adapter_rsp = UCIe2_isAdapterLinkMgmtRsp({64'b0, tx_header});
  assign rx_is_adapter_req = rxFire && UCIe2_isAdapterLinkMgmtReq({64'b0, rx_header});
  assign rx_is_adapter_rsp = rxFire && UCIe2_isAdapterLinkMgmtRsp({64'b0, rx_header});

  assign rx_is_param_exchange       = rxFire && UCIe2_isParamExchange(rx_message);
  assign rx_is_param_exchange_stall = rxFire && UCIe2_isParamExchangeStall(rx_message);
  assign rx_is_adv_cap_adapter = rx_is_param_exchange &&
                                 (rx_msgCode == UCIe2_ParamExch_ADV_CAP_MSGCODE) &&
                                 (rx_msgSub == UCIe2_ParamExch_SUB_ADAPTER);
  assign rx_is_adv_cap_adapter_stall = rx_is_adv_cap_adapter &&
                                       (rx_msgInfo == UCIe2_MsgInfo_STALL);
  assign rx_is_adv_cap_adapter_nonstall = rx_is_adv_cap_adapter &&
                                          !rx_is_adv_cap_adapter_stall;

  function automatic logic txIsAdapterReq(input logic [7:0] sub);
    txIsAdapterReq = tx_is_adapter_req && (tx_msgSub == sub);
  endfunction
  function automatic logic txIsAdapterRsp(input logic [7:0] sub);
    txIsAdapterRsp = tx_is_adapter_rsp && (tx_msgSub == sub);
  endfunction
  function automatic logic rxIsAdapterReq(input logic [7:0] sub);
    rxIsAdapterReq = rx_is_adapter_req && (rx_msgSub == sub);
  endfunction
  function automatic logic rxIsAdapterRsp(input logic [7:0] sub);
    rxIsAdapterRsp = rx_is_adapter_rsp && (rx_msgSub == sub);
  endfunction

  localparam logic [63:0] rawStreamingAdvCapPayload = 64'h0000_0000_0000_0091;

  function automatic logic advCapRawFormat(input logic [63:0] p);
    advCapRawFormat = p[0];
  endfunction
  function automatic logic advCapStreaming(input logic [63:0] p);
    advCapStreaming = p[4];
  endfunction
  function automatic logic advCapStack0Enabled(input logic [63:0] p);
    advCapStack0Enabled = p[7];
  endfunction
  function automatic logic advCapRawStreamingCompatible(input logic [63:0] p);
    advCapRawStreamingCompatible = advCapRawFormat(p) && advCapStreaming(p) &&
                                     advCapStack0Enabled(p);
  endfunction

  logic paramExchStallReceived;
  (* keep = "true" *) logic rx_advcap_raw_streaming_compatible;
  assign paramExchStallReceived = rx_is_param_exchange_stall;
  assign rx_advcap_raw_streaming_compatible = advCapRawStreamingCompatible(rx_payload);

  // Output and state registers.
  (* keep = "true" *) logic rdi_lp_linkerror_reg;
  (* keep = "true" *) PhyStateReq_t rdi_lp_state_req_reg;
  PhyStateReq_t rdi_lp_state_req_reg_next;
  (* keep = "true" *) PhyStateReq_t linkinit_rdi_lp_state_req;
  PhyStateReq_t linkinit_rdi_lp_state_req_next;

  (* keep = "true" *) logic fdi_pl_rxactive_req_reg;
  logic fdi_pl_rxactive_req_reg_next;
  (* keep = "true" *) logic fdi_pl_inband_pres_reg;

  logic fdiAwake_reg;
  logic fdi_pl_wake_ack_reg;

  (* keep = "true" *) PhyState_t link_state_reg;
  (* keep = "true" *) PhyState_t link_state_prev_reg;
  (* keep = "true" *) LinkInitState_t linkinit_state_reg;
  LinkInitState_t linkinit_state_reg_next;
  PhyState_t next_state;

  (* keep = "true" *) PhyStateReq_t fdi_lp_state_req_prev_reg;
  (* keep = "true" *) logic retrain_to_active_initiated;
  logic retrain_to_active_initiated_next;

  (* keep = "true" *) logic nopToActive;
  (* keep = "true" *) logic nopToDisabled;
  (* keep = "true" *) logic nopToLinkreset;

  (* keep = "true" *) logic pendingDisabledFromReset;
  (* keep = "true" *) logic pendingLinkresetFromReset;
  logic pendingDisabledFromReset_next;
  logic pendingLinkresetFromReset_next;

  assign rdi_lp_linkerror      = rdi_lp_linkerror_reg;
  assign rdi_lp_state_req      = rdi_lp_state_req_reg;
  assign fdi_pl_state_sts      = link_state_reg;
  assign fdi_pl_rx_active_req  = fdi_pl_rxactive_req_reg;
  assign fdi_pl_inband_pres    = fdi_pl_inband_pres_reg;
  assign debug_link_init_state = linkinit_state_reg;
  assign fdiNeedsRdiAwake      = 1'b1;
  assign fdiAwake              = fdiAwake_reg;
  assign fdi_pl_wake_ack       = fdi_pl_wake_ack_reg;
  assign fdi_pl_clk_req        = 1'b1;

  // FDI stall controller.
  (* keep = "true" *) logic linkmgmt_stallreq_reg;
  logic linkmgmt_stallreq_reg_next;
  logic stall_req;
  (* keep = "true" *) logic stallhandler_handshake_done;
  (* keep = "true" *) logic stall_4phaseshandshake_done;
  logic stall_busy;

  StallCtrl stall_module (
    .clock   (clock),
    .reset_n   (reset_n),
    .start   (linkmgmt_stallreq_reg && !stall_busy),
    .release_i (link_state_reg != PhyState_active),
    .ack     (fdi_lp_stall_ack),
    .req     (stall_req),
    .aligned (stallhandler_handshake_done),
    .done    (stall_4phaseshandshake_done),
    .busy    (stall_busy)
  );
  assign fdi_pl_stall_req = stall_req;

  (* keep = "true" *) logic rdi_lp_stall_ack_reg;
  logic rdi_lp_stall_ack_reg_next;
  assign rdi_lp_stall_ack = rdi_lp_stall_ack_reg;

  // Placeholder internal causes retained as registers, as in the source revision.
  (* keep = "true" *) logic linkerror_internal;
  (* keep = "true" *) logic linkreset_internal;
  (* keep = "true" *) logic disabled_internal;

  logic linkerror_phy_sts;
  logic linkreset_rdiphy_sts;
  logic disabled_rdiphy_sts;
  logic retrain_rdiphy_sts;
  logic active_rdiphy_sts;
  assign linkerror_phy_sts     = (rdi_pl_state_sts == PhyState_linkError);
  assign linkreset_rdiphy_sts  = (rdi_pl_state_sts == PhyState_linkReset);
  assign disabled_rdiphy_sts   = (rdi_pl_state_sts == PhyState_disabled);
  assign retrain_rdiphy_sts    = (rdi_pl_state_sts == PhyState_retrain);
  assign active_rdiphy_sts     = (rdi_pl_state_sts == PhyState_active);

  (* keep = "true" *) logic active_entry;
  logic rx_deactive;
  logic rx_active;
  assign rx_deactive = !fdi_lp_rx_active_sts && !fdi_pl_rxactive_req_reg;
  assign rx_active   =  fdi_lp_rx_active_sts &&  fdi_pl_rxactive_req_reg;

  (* keep = "true" *) logic [63:0] linkerrorCounter;
  logic [63:0] maxCount_linkerr;
  logic linkerrorResidencyDone;
  assign maxCount_linkerr = {32'b0, cycles_1us} * 64'd16000;
  assign linkerrorResidencyDone = (linkerrorCounter == maxCount_linkerr);

  wire timeout_done = 1'b0;
  (* keep = "true" *) logic [63:0] paramexchCounter;
  logic [63:0] maxCount_paramexch;
  logic paramexchTimesUp;
  assign maxCount_paramexch = {32'b0, cycles_1us} * 64'd8000;
  assign paramexchTimesUp = (paramexchCounter == maxCount_paramexch);

  logic disabled_entry;
  logic linkreset_entry;
  logic disabled_entry_rst;
  logic linkreset_entry_rst;
  logic disabled_handshake_done;
  logic linkreset_handshake_done;

  (* keep = "true" *) logic disabled_cleanup_done;
  (* keep = "true" *) logic linkreset_cleanup_done;

  // Sideband transaction flags.
  (* keep = "true" *) logic active_sbmsg_loc_req_flag;
  (* keep = "true" *) logic active_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic active_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic active_sbmsg_rem_req_flag;
  logic active_sbmsg_loc_req_flag_next;
  logic active_sbmsg_loc_rsp_flag_next;
  logic active_sbmsg_rem_rsp_flag_next;
  logic active_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic disabled_sbmsg_loc_req_flag;
  (* keep = "true" *) logic disabled_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic disabled_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic disabled_sbmsg_rem_req_flag;
  logic disabled_sbmsg_loc_req_flag_next;
  logic disabled_sbmsg_loc_rsp_flag_next;
  logic disabled_sbmsg_rem_rsp_flag_next;
  logic disabled_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic linkreset_sbmsg_loc_req_flag;
  (* keep = "true" *) logic linkreset_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic linkreset_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic linkreset_sbmsg_rem_req_flag;
  logic linkreset_sbmsg_loc_req_flag_next;
  logic linkreset_sbmsg_loc_rsp_flag_next;
  logic linkreset_sbmsg_rem_rsp_flag_next;
  logic linkreset_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic adv_cap_local_sent_flag;
  (* keep = "true" *) logic adv_cap_remote_rcv_flag;
  (* keep = "true" *) logic param_exch_incompatible_reg;
  logic adv_cap_local_sent_flag_next;
  logic adv_cap_remote_rcv_flag_next;
  logic param_exch_incompatible_reg_next;

  logic param_exch_done;
  logic disabled_req;
  logic linkreset_req;
  logic retrain_req;

  assign disabled_req = (fdi_lp_state_req == PhyStateReq_disabled) ||
                        disabled_sbmsg_rem_req_flag || disabled_internal;
  assign linkreset_req = (fdi_lp_state_req == PhyStateReq_linkReset) ||
                         linkreset_sbmsg_rem_req_flag || linkreset_internal;
  assign retrain_req = (fdi_lp_state_req == PhyStateReq_retrain);

  assign disabled_entry_rst = pendingDisabledFromReset || nopToDisabled ||
                              disabled_sbmsg_rem_req_flag || disabled_rdiphy_sts ||
                              disabled_internal;
  assign linkreset_entry_rst = pendingLinkresetFromReset || nopToLinkreset ||
                               linkreset_sbmsg_rem_req_flag || linkreset_rdiphy_sts ||
                               linkreset_internal;
  assign disabled_entry = disabled_req || disabled_rdiphy_sts;
  assign linkreset_entry = linkreset_req || linkreset_rdiphy_sts;
  assign disabled_handshake_done =
    (disabled_sbmsg_rem_req_flag && disabled_sbmsg_rem_rsp_flag) ||
    (disabled_sbmsg_loc_req_flag && disabled_sbmsg_loc_rsp_flag);
  assign linkreset_handshake_done =
    (linkreset_sbmsg_rem_req_flag && linkreset_sbmsg_rem_rsp_flag) ||
    (linkreset_sbmsg_loc_req_flag && linkreset_sbmsg_loc_rsp_flag);
  assign param_exch_done = adv_cap_local_sent_flag && adv_cap_remote_rcv_flag;

  logic inbandShouldBeHigh;
  assign inbandShouldBeHigh =
    (link_state_reg == PhyState_active) ||
    (link_state_reg == PhyState_retrain) ||
    ((link_state_reg == PhyState_reset) &&
     ((linkinit_state_reg == LinkInitState_FDI_WAIT_LP_REQ_ACTIVE) ||
      (linkinit_state_reg == LinkInitState_FDI_ACTIVE_HANDSHAKE) ||
      (linkinit_state_reg == LinkInitState_FDI_ACTIVE_ENTRY_DONE)));

  // Main next-state and sideband logic.
  always_comb begin
    sb_snd_msg_reg_next = sb_snd_msg_reg;
    sb_snd_vld_reg_next = sb_snd_vld_reg;
    sb_snd_msg_next = zeroMessage();
    sb_snd_vld_next = 1'b0;

    rdi_lp_state_req_reg_next = rdi_lp_state_req_reg;
    linkinit_rdi_lp_state_req_next = linkinit_rdi_lp_state_req;
    fdi_pl_rxactive_req_reg_next = fdi_pl_rxactive_req_reg;
    linkinit_state_reg_next = linkinit_state_reg;
    next_state = PhyState_reset;
    retrain_to_active_initiated_next = retrain_to_active_initiated;
    linkmgmt_stallreq_reg_next = linkmgmt_stallreq_reg;
    rdi_lp_stall_ack_reg_next = rdi_lp_stall_ack_reg;
    pendingDisabledFromReset_next = pendingDisabledFromReset;
    pendingLinkresetFromReset_next = pendingLinkresetFromReset;
    active_entry = 1'b0;

    active_sbmsg_loc_req_flag_next = active_sbmsg_loc_req_flag;
    active_sbmsg_loc_rsp_flag_next = active_sbmsg_loc_rsp_flag;
    active_sbmsg_rem_rsp_flag_next = active_sbmsg_rem_rsp_flag;
    active_sbmsg_rem_req_flag_next = active_sbmsg_rem_req_flag;
    disabled_sbmsg_loc_req_flag_next = disabled_sbmsg_loc_req_flag;
    disabled_sbmsg_loc_rsp_flag_next = disabled_sbmsg_loc_rsp_flag;
    disabled_sbmsg_rem_rsp_flag_next = disabled_sbmsg_rem_rsp_flag;
    disabled_sbmsg_rem_req_flag_next = disabled_sbmsg_rem_req_flag;
    linkreset_sbmsg_loc_req_flag_next = linkreset_sbmsg_loc_req_flag;
    linkreset_sbmsg_loc_rsp_flag_next = linkreset_sbmsg_loc_rsp_flag;
    linkreset_sbmsg_rem_rsp_flag_next = linkreset_sbmsg_rem_rsp_flag;
    linkreset_sbmsg_rem_req_flag_next = linkreset_sbmsg_rem_req_flag;
    adv_cap_local_sent_flag_next = adv_cap_local_sent_flag;
    adv_cap_remote_rcv_flag_next = adv_cap_remote_rcv_flag;
    param_exch_incompatible_reg_next = param_exch_incompatible_reg;

    // Latch Reset-exit requests from the registered NOP-transition indicators.
    if (link_state_reg != PhyState_reset) begin
      pendingDisabledFromReset_next = 1'b0;
      pendingLinkresetFromReset_next = 1'b0;
    end else begin
      if (nopToDisabled)
        pendingDisabledFromReset_next = 1'b1;
      if (nopToLinkreset)
        pendingLinkresetFromReset_next = 1'b1;
    end

    // Acknowledge a PHY-originated stall only after the local stall controller is aligned.
    if (!rdi_pl_stall_req)
      rdi_lp_stall_ack_reg_next = 1'b0;
    else if (stallhandler_handshake_done)
      rdi_lp_stall_ack_reg_next = 1'b1;

    // Parameter exchange flags.
    if (txFire && UCIe2_isParamExchange(sb_snd_msg_reg) &&
        (UCIe2_Field_msgCode({64'b0, tx_header}) == UCIe2_ParamExch_ADV_CAP_MSGCODE) &&
        (UCIe2_Field_msgSub({64'b0, tx_header}) == UCIe2_ParamExch_SUB_ADAPTER)) begin
      adv_cap_local_sent_flag_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      adv_cap_local_sent_flag_next = 1'b0;
    end

    if (rx_is_adv_cap_adapter_nonstall && rx_advcap_raw_streaming_compatible) begin
      adv_cap_remote_rcv_flag_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      adv_cap_remote_rcv_flag_next = 1'b0;
    end

    if (rx_is_adv_cap_adapter_nonstall && !rx_advcap_raw_streaming_compatible) begin
      param_exch_incompatible_reg_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      param_exch_incompatible_reg_next = 1'b0;
    end

    // Active sideband flags.
    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_loc_req_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_loc_rsp_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_loc_rsp_flag_next = 1'b0;

    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_rem_req_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_rem_rsp_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_rem_rsp_flag_next = 1'b0;

    // Disabled sideband flags.
    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_rem_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_rem_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_rem_rsp_flag_next = 1'b0;

    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_loc_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_loc_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_loc_rsp_flag_next = 1'b0;

    // LinkReset sideband flags.
    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_rem_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_rem_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_rem_rsp_flag_next = 1'b0;

    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_loc_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_loc_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_loc_rsp_flag_next = 1'b0;

    // FDI state machine. next_state is computed before the link-init FSM below,
    // because the link-init ACTIVE_ENTRY_DONE condition reads the final next_state wire.
    case (link_state_reg)
      PhyState_reset: begin
        rdi_lp_state_req_reg_next = linkinit_rdi_lp_state_req;
        linkmgmt_stallreq_reg_next = 1'b0;
        sb_snd_msg_next = zeroMessage();
        next_state = PhyState_reset;
        retrain_to_active_initiated_next = 1'b0;

        if (linkinit_state_reg == LinkInitState_FDI_INIT_START) begin
          sb_snd_msg_next = zeroMessage();
          fdi_pl_rxactive_req_reg_next = 1'b0;
        end else if (linkinit_state_reg == LinkInitState_FDI_PARAM_EXCH) begin
          if (!adv_cap_local_sent_flag) begin
            sb_snd_msg_next = UCIe2_ParamExchange_advCapAdapter(
              rawStreamingAdvCapPayload, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D,
              UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else begin
            sb_snd_msg_next = zeroMessage();
          end
        end else if (linkinit_state_reg == LinkInitState_FDI_ACTIVE_HANDSHAKE) begin
          fdi_pl_rxactive_req_reg_next = 1'b1;
          if (!active_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqActive(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (active_sbmsg_rem_req_flag && rx_active &&
                       !active_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspActive(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else begin
            sb_snd_msg_next = zeroMessage();
          end
        end

        if (linkerror_phy_sts) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          next_state = PhyState_linkError;
        end else if (disabled_entry_rst) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done)
            next_state = PhyState_disabled;
        end else if (linkreset_entry_rst) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done)
            next_state = PhyState_linkReset;
        end else if (linkinit_state_reg == LinkInitState_FDI_ACTIVE_ENTRY_DONE) begin
          next_state = PhyState_active;
        end
      end

      PhyState_active: begin
        sb_snd_msg_next = zeroMessage();
        linkmgmt_stallreq_reg_next = linkreset_req || disabled_req || retrain_req ||
                                     rdi_pl_stall_req;
        next_state = PhyState_active;

        if (linkerror_phy_sts) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          next_state = PhyState_linkError;
        end else if (disabled_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done)
            next_state = PhyState_disabled;
        end else if (linkreset_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done)
            next_state = PhyState_linkReset;
        end else if (retrain_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_retrain;
          if (retrain_rdiphy_sts) begin
            if (rx_active)
              fdi_pl_rxactive_req_reg_next = 1'b0;
            if (rx_deactive) begin
              rdi_lp_state_req_reg_next = PhyStateReq_retrain;
              next_state = PhyState_retrain;
            end
          end
        end else if (retrain_rdiphy_sts && stallhandler_handshake_done) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive) begin
            rdi_lp_state_req_reg_next = PhyStateReq_retrain;
            next_state = PhyState_retrain;
          end
        end else if (disabled_rdiphy_sts && !disabled_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_disabled;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else if (linkreset_rdiphy_sts && !linkreset_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_linkReset;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else if (retrain_rdiphy_sts && !retrain_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_retrain;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_retrain: begin
        sb_snd_msg_next = zeroMessage();
        linkmgmt_stallreq_reg_next = 1'b0;
        rdi_lp_state_req_reg_next = PhyStateReq_nop;
        next_state = PhyState_retrain;

        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (disabled_entry) begin
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done) begin
            next_state = PhyState_disabled;
            if (!disabled_rdiphy_sts)
              rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          end
        end else if (linkreset_entry) begin
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done) begin
            next_state = PhyState_linkReset;
            if (!linkreset_rdiphy_sts)
              rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          end
        end else if (nopToActive) begin
          fdi_pl_rxactive_req_reg_next = 1'b1;
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          retrain_to_active_initiated_next = 1'b1;
        end else if (retrain_to_active_initiated) begin
          if (active_rdiphy_sts) begin
            if (!active_sbmsg_loc_req_flag) begin
              sb_snd_msg_next = UCIe2_Adapter_reqActive(
                0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
              sb_snd_vld_next = 1'b1;
            end else if (active_sbmsg_rem_req_flag && rx_active &&
                         !active_sbmsg_rem_rsp_flag) begin
              sb_snd_msg_next = UCIe2_Adapter_rspActive(
                0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
              sb_snd_vld_next = 1'b1;
            end else begin
              sb_snd_msg_next = zeroMessage();
            end
            if (active_sbmsg_loc_rsp_flag && active_sbmsg_rem_rsp_flag) begin
              retrain_to_active_initiated_next = 1'b0;
              next_state = PhyState_active;
            end
          end
        end
      end

      PhyState_linkError: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_linkError;
        if ((fdi_lp_state_req == PhyStateReq_active) && !linkerror_internal &&
            linkerrorResidencyDone && rx_deactive && !fdi_lp_linkerror) begin
          if (rdi_pl_state_sts == PhyState_reset) begin
            rdi_lp_state_req_reg_next = PhyStateReq_nop;
            next_state = PhyState_reset;
          end else begin
            rdi_lp_state_req_reg_next = PhyStateReq_active;
          end
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_disabled: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_disabled;
        sb_snd_msg_next = zeroMessage();
        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (rdi_pl_state_sts != PhyState_disabled) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
        end else if ((fdi_lp_state_req == PhyStateReq_active) && disabled_cleanup_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          next_state = PhyState_reset;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_linkReset: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_linkReset;
        sb_snd_msg_next = zeroMessage();
        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (disabled_entry) begin
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          next_state = PhyState_disabled;
        end else if (rdi_pl_state_sts != PhyState_linkReset) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
        end else if ((fdi_lp_state_req == PhyStateReq_active) && linkreset_cleanup_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          next_state = PhyState_reset;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      default: begin
        next_state = PhyState_reset;
      end
    endcase

    // Link-initialization FSM. It consumes the final next_state value above.
    case (linkinit_state_reg)
      LinkInitState_FDI_INIT_START: begin
        active_entry = 1'b0;
        linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
        if (rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_active;
          linkinit_state_reg_next = LinkInitState_FDI_WAIT_RDI_ACTIVE;
        end
      end

      LinkInitState_FDI_WAIT_RDI_ACTIVE: begin
        if (!rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
        end else if (rdi_pl_state_sts == PhyState_active) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_PARAM_EXCH;
        end
      end

      LinkInitState_FDI_PARAM_EXCH: begin
        if (param_exch_done)
          linkinit_state_reg_next = LinkInitState_FDI_WAIT_LP_REQ_ACTIVE;
      end

      LinkInitState_FDI_WAIT_LP_REQ_ACTIVE: begin
        if (nopToActive)
          linkinit_state_reg_next = LinkInitState_FDI_ACTIVE_HANDSHAKE;
      end

      LinkInitState_FDI_ACTIVE_HANDSHAKE: begin
        if (!rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
        end else if (active_sbmsg_loc_rsp_flag && active_sbmsg_rem_rsp_flag) begin
          linkinit_state_reg_next = LinkInitState_FDI_ACTIVE_ENTRY_DONE;
        end
      end

      LinkInitState_FDI_ACTIVE_ENTRY_DONE: begin
        if (!rdi_pl_inband_pres ||
            ((link_state_reg != PhyState_reset) && (next_state == PhyState_reset))) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
          active_entry = 1'b0;
        end else if (fdi_lp_state_req == PhyStateReq_active) begin
          active_entry = 1'b1;
        end
      end

      default: linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
    endcase

    // Decoupled TX register commit.
    if (sb_snd_vld_reg) begin
      if (txFire) begin
        sb_snd_msg_reg_next = zeroMessage();
        sb_snd_vld_reg_next = 1'b0;
      end
    end else begin
      sb_snd_msg_reg_next = sb_snd_msg_next;
      sb_snd_vld_reg_next = sb_snd_vld_next;
    end
  end

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      linkmgmt_stallreq_reg <= 1'b0;
      sb_snd_msg_reg <= 128'b0;
      sb_snd_vld_reg <= 1'b0;
      rdi_lp_linkerror_reg <= 1'b0;
      rdi_lp_state_req_reg <= PhyStateReq_nop;
      linkinit_rdi_lp_state_req <= PhyStateReq_nop;
      fdi_pl_rxactive_req_reg <= 1'b0;
      fdi_pl_inband_pres_reg <= 1'b0;
      fdiAwake_reg <= 1'b0;
      fdi_pl_wake_ack_reg <= 1'b0;
      link_state_reg <= PhyState_reset;
      link_state_prev_reg <= PhyState_reset;
      linkinit_state_reg <= LinkInitState_FDI_INIT_START;
      fdi_lp_state_req_prev_reg <= PhyStateReq_nop;
      retrain_to_active_initiated <= 1'b0;
      nopToActive <= 1'b0;
      nopToDisabled <= 1'b0;
      nopToLinkreset <= 1'b0;
      pendingDisabledFromReset <= 1'b0;
      pendingLinkresetFromReset <= 1'b0;
      rdi_lp_stall_ack_reg <= 1'b0;
      linkerror_internal <= 1'b0;
      linkreset_internal <= 1'b0;
      disabled_internal <= 1'b0;
      linkerrorCounter <= 64'd0;
      paramexchCounter <= 64'd0;
      disabled_cleanup_done <= 1'b1;
      linkreset_cleanup_done <= 1'b1;
      active_sbmsg_loc_req_flag <= 1'b0;
      active_sbmsg_loc_rsp_flag <= 1'b0;
      active_sbmsg_rem_rsp_flag <= 1'b0;
      active_sbmsg_rem_req_flag <= 1'b0;
      disabled_sbmsg_loc_req_flag <= 1'b0;
      disabled_sbmsg_loc_rsp_flag <= 1'b0;
      disabled_sbmsg_rem_rsp_flag <= 1'b0;
      disabled_sbmsg_rem_req_flag <= 1'b0;
      linkreset_sbmsg_loc_req_flag <= 1'b0;
      linkreset_sbmsg_loc_rsp_flag <= 1'b0;
      linkreset_sbmsg_rem_rsp_flag <= 1'b0;
      linkreset_sbmsg_rem_req_flag <= 1'b0;
      adv_cap_local_sent_flag <= 1'b0;
      adv_cap_remote_rcv_flag <= 1'b0;
      param_exch_incompatible_reg <= 1'b0;
    end else begin
      linkmgmt_stallreq_reg <= linkmgmt_stallreq_reg_next;
      sb_snd_msg_reg <= sb_snd_msg_reg_next;
      sb_snd_vld_reg <= sb_snd_vld_reg_next;
      rdi_lp_linkerror_reg <= fdi_lp_linkerror || linkerror_internal || timeout_done ||
                              paramexchTimesUp || param_exch_incompatible_reg;
      rdi_lp_state_req_reg <= rdi_lp_state_req_reg_next;
      linkinit_rdi_lp_state_req <= linkinit_rdi_lp_state_req_next;
      fdi_pl_rxactive_req_reg <= fdi_pl_rxactive_req_reg_next;
      fdi_pl_inband_pres_reg <= inbandShouldBeHigh;
      fdiAwake_reg <= rdiNeedsFdiAwake;
      fdi_pl_wake_ack_reg <= fdi_lp_wake_req;
      link_state_prev_reg <= link_state_reg;
      link_state_reg <= next_state;
      linkinit_state_reg <= linkinit_state_reg_next;
      fdi_lp_state_req_prev_reg <= fdi_lp_state_req;
      retrain_to_active_initiated <= retrain_to_active_initiated_next;
      nopToActive <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (fdi_lp_state_req == PhyStateReq_active);
      nopToDisabled <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                       (fdi_lp_state_req == PhyStateReq_disabled);
      nopToLinkreset <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                        (fdi_lp_state_req == PhyStateReq_linkReset);
      pendingDisabledFromReset <= pendingDisabledFromReset_next;
      pendingLinkresetFromReset <= pendingLinkresetFromReset_next;
      rdi_lp_stall_ack_reg <= rdi_lp_stall_ack_reg_next;

      // Source placeholder registers intentionally retain their reset values.

      if (link_state_reg == PhyState_linkError) begin
        if (!linkerrorResidencyDone)
          linkerrorCounter <= linkerrorCounter + 64'd1;
      end else begin
        linkerrorCounter <= 64'd0;
      end

      if ((linkinit_state_reg == LinkInitState_FDI_PARAM_EXCH) &&
          (rdi_pl_state_sts == PhyState_active)) begin
        if (paramExchStallReceived)
          paramexchCounter <= 64'd0;
        else if (!paramexchTimesUp)
          paramexchCounter <= paramexchCounter + 64'd1;
      end else begin
        paramexchCounter <= 64'd0;
      end

      active_sbmsg_loc_req_flag <= active_sbmsg_loc_req_flag_next;
      active_sbmsg_loc_rsp_flag <= active_sbmsg_loc_rsp_flag_next;
      active_sbmsg_rem_rsp_flag <= active_sbmsg_rem_rsp_flag_next;
      active_sbmsg_rem_req_flag <= active_sbmsg_rem_req_flag_next;
      disabled_sbmsg_loc_req_flag <= disabled_sbmsg_loc_req_flag_next;
      disabled_sbmsg_loc_rsp_flag <= disabled_sbmsg_loc_rsp_flag_next;
      disabled_sbmsg_rem_rsp_flag <= disabled_sbmsg_rem_rsp_flag_next;
      disabled_sbmsg_rem_req_flag <= disabled_sbmsg_rem_req_flag_next;
      linkreset_sbmsg_loc_req_flag <= linkreset_sbmsg_loc_req_flag_next;
      linkreset_sbmsg_loc_rsp_flag <= linkreset_sbmsg_loc_rsp_flag_next;
      linkreset_sbmsg_rem_rsp_flag <= linkreset_sbmsg_rem_rsp_flag_next;
      linkreset_sbmsg_rem_req_flag <= linkreset_sbmsg_rem_req_flag_next;
      adv_cap_local_sent_flag <= adv_cap_local_sent_flag_next;
      adv_cap_remote_rcv_flag <= adv_cap_remote_rcv_flag_next;
      param_exch_incompatible_reg <= param_exch_incompatible_reg_next;
    end
  end

  // Parameters and inputs retained for source/integration compatibility.
  wire _unused_ok = &{1'b0, fdi_lp_clk_ack, rdiAwake, link_state_prev_reg[0],
                      stall_4phaseshandshake_done, active_entry};
endmodule

`default_nettype wire

```

<a id="LinkMgmtSidebandPacketArbiter-sv"></a>

## [6] LinkMgmtSidebandPacketArbiter.sv

```systemverilog
// FILE_INDEX: 6
// FILE_PATH : LinkMgmtSidebandPacketArbiter.sv

// Hand-translated synthesizable SystemVerilog.
// Source: LinkMgmtSidebandPacketArbiter(7).scala
// Original Chisel signal/register names are retained wherever
// SystemVerilog scoping permits.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LinkMgmtSidebandPacketArbiter (
  input wire logic         clock,
  input wire logic         reset_n,

  // LTSM TX producer -> arbiter.
  input wire logic         ltsm_tx_valid,
  input wire logic [127:0] ltsm_tx_msg,
  output var logic         ltsm_tx_ready,

  // FDI TX producer -> arbiter.
  input wire logic         fdi_tx_valid,
  input wire logic [127:0] fdi_tx_msg,
  output var logic         fdi_tx_ready,

  // RDI TX producer -> arbiter.
  input wire logic         rdi_tx_valid,
  input wire logic [127:0] rdi_tx_msg,
  output var logic         rdi_tx_ready,

  // Arbiter TX output -> shared sideband transport.
  output var logic         tx_out_valid,
  output var logic [127:0] tx_out_msg,
  input wire logic         tx_out_ready,

  // Shared sideband transport -> arbiter RX input.
  input wire logic         rx_in_valid,
  input wire logic [127:0] rx_in_msg,
  output var logic         rx_in_ready,

  // Arbiter -> LTSM RX sink.
  output var logic         ltsm_rx_valid,
  output var logic [127:0] ltsm_rx_msg,
  input wire logic         ltsm_rx_ready,

  // Arbiter -> FDI RX sink.
  output var logic         fdi_rx_valid,
  output var logic [127:0] fdi_rx_msg,
  input wire logic         fdi_rx_ready,

  // Arbiter -> RDI RX sink.
  output var logic         rdi_rx_valid,
  output var logic [127:0] rdi_rx_msg,
  input wire logic         rdi_rx_ready,

  // Debug / waveform visibility.
  output var logic         grant_ltsm,
  output var logic         grant_fdi,
  output var logic         grant_rdi,
  output var logic         tx_locked,
  output var logic [1:0]   rr_last_source,
  output var logic         rr_last_granted_rdi,
  output var logic         tx_fire,

  output var logic         rx_route_ltsm,
  output var logic         rx_route_fdi,
  output var logic         rx_route_rdi,
  output var logic         rx_drop_unknown,
  output var logic         rx_fire
);

  import SidebandMsgGenerator_pkg::*;

  localparam logic [1:0] SourceLtsm = 2'd0;
  localparam logic [1:0] SourceFdi  = 2'd1;
  localparam logic [1:0] SourceRdi  = 2'd2;

  // --------------------------------------------------------------------------
  // TX arbitration
  // --------------------------------------------------------------------------

  (* keep = "true" *) logic [1:0] rrLastSource;
  (* keep = "true" *) logic       txGrantLocked;
  (* keep = "true" *) logic [1:0] txLockedSource;

  logic [7:0] rdiTxMsgSub;
  logic       rdiTxIsLinkError;

  logic newGrantLtsm;
  logic newGrantFdi;
  logic newGrantRdi;

  logic grantLtsm;
  logic grantFdi;
  logic grantRdi;
  logic txFire;

  assign rdiTxMsgSub = UCIe2_Field_msgSub(rdi_tx_msg);

  assign rdiTxIsLinkError =
    rdi_tx_valid &&
    UCIe2_isRdiLinkMgmt(rdi_tx_msg) &&
    (rdiTxMsgSub == UCIe2_LinkMgmtSubCode_LINKERROR);

  always_comb begin
    newGrantLtsm = 1'b0;
    newGrantFdi  = 1'b0;
    newGrantRdi  = 1'b0;

    if (rdiTxIsLinkError) begin
      // Link-error traffic has priority over normal arbitration.
      newGrantRdi = 1'b1;
    end else begin
      // Start with the source after the most recently completed grant.
      case (rrLastSource)
        SourceLtsm: begin
          if (fdi_tx_valid)
            newGrantFdi = 1'b1;
          else if (rdi_tx_valid)
            newGrantRdi = 1'b1;
          else if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
        end

        SourceFdi: begin
          if (rdi_tx_valid)
            newGrantRdi = 1'b1;
          else if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
          else if (fdi_tx_valid)
            newGrantFdi = 1'b1;
        end

        SourceRdi: begin
          if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
          else if (fdi_tx_valid)
            newGrantFdi = 1'b1;
          else if (rdi_tx_valid)
            newGrantRdi = 1'b1;
        end

        default: begin
          // Unreachable for legal state values.
          // Retain the all-zero defaults.
        end
      endcase
    end
  end

  always_comb begin
    grantLtsm = txGrantLocked ? (txLockedSource == SourceLtsm) : newGrantLtsm;
    grantFdi  = txGrantLocked ? (txLockedSource == SourceFdi)  : newGrantFdi;
    grantRdi  = txGrantLocked ? (txLockedSource == SourceRdi)  : newGrantRdi;

    tx_out_valid = (grantLtsm && ltsm_tx_valid) ||
      (grantFdi  && fdi_tx_valid)  ||
      (grantRdi  && rdi_tx_valid);

    tx_out_msg = 128'b0;

    if (grantLtsm)
      tx_out_msg = ltsm_tx_msg;
    else if (grantFdi)
      tx_out_msg = fdi_tx_msg;
    else if (grantRdi)
      tx_out_msg = rdi_tx_msg;
  end

  assign ltsm_tx_ready = tx_out_ready && grantLtsm;
  assign fdi_tx_ready  = tx_out_ready && grantFdi;
  assign rdi_tx_ready  = tx_out_ready && grantRdi;

  assign txFire = tx_out_valid && tx_out_ready;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      rrLastSource   <= SourceRdi;
      txGrantLocked  <= 1'b0;
      txLockedSource <= SourceLtsm;
    end else begin
      if (!txGrantLocked && tx_out_valid && !tx_out_ready) begin
        // Hold the selected producer while the output is stalled.
        txGrantLocked <= 1'b1;

        if (grantLtsm)
          txLockedSource <= SourceLtsm;
        else if (grantFdi)
          txLockedSource <= SourceFdi;
        else
          txLockedSource <= SourceRdi;
      end else if (txGrantLocked && txFire) begin
        // Release the lock after the transaction is accepted.
        txGrantLocked <= 1'b0;
      end else if (txGrantLocked && !tx_out_valid) begin
        // Defensive recovery if a producer violates valid-hold semantics.
        txGrantLocked <= 1'b0;
      end

      if (txFire) begin
        if (grantLtsm)
          rrLastSource <= SourceLtsm;
        else if (grantFdi)
          rrLastSource <= SourceFdi;
        else if (grantRdi)
          rrLastSource <= SourceRdi;
      end
    end
  end

  assign grant_ltsm          = grantLtsm && ltsm_tx_valid;
  assign grant_fdi           = grantFdi  && fdi_tx_valid;
  assign grant_rdi           = grantRdi  && rdi_tx_valid;
  assign tx_locked           = txGrantLocked;
  assign rr_last_source      = rrLastSource;
  assign rr_last_granted_rdi = (rrLastSource == SourceRdi);
assign tx_fire             = txFire;

  // --------------------------------------------------------------------------
  // RX rising-edge detection
  //
  // The physical RX may keep rx_in_valid high for multiple controller-clock
  // cycles. Convert each sampled low-to-high transition into a one-cycle pulse.
  //
  // Assumptions:
  //   1. rx_in_valid returns low before the next received message.
  //   2. rx_in_msg is stable when rxValidPulse is asserted.
  //   3. The selected RX consumer is ready during that pulse.
  // --------------------------------------------------------------------------

  (* keep = "true" *) logic rxInValidDelayed;
  (* keep = "true" *) logic rxValidPulse;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n)
      rxInValidDelayed <= 1'b0;
    else
      rxInValidDelayed <= rx_in_valid;
  end

  assign rxValidPulse =
    rx_in_valid && !rxInValidDelayed;

  // --------------------------------------------------------------------------
  // RX routing
  // --------------------------------------------------------------------------

  UCIe2_Route_t rxRoute;

  logic routeToLtsm;
  logic routeToFdi;
  logic routeToRdi;
  logic dropUnknown;
  logic selectedSinkReady;

  assign rxRoute =
    UCIe2_route(rx_in_msg);

  assign routeToLtsm =
    (rxRoute == UCIe2_Route_LTSM);

  assign routeToFdi =
    (rxRoute == UCIe2_Route_ADAPTER0) ||
    (rxRoute == UCIe2_Route_ADAPTER1) ||
    (rxRoute == UCIe2_Route_D2D_COMMON);

  assign routeToRdi =
    (rxRoute == UCIe2_Route_RDI);

  // Route to the LTSM for one controller-clock cycle.
  assign ltsm_rx_valid =
    rxValidPulse && routeToLtsm;

  assign ltsm_rx_msg =
    rx_in_msg;

  // Route to the FDI controller for one controller-clock cycle.
  assign fdi_rx_valid =
    rxValidPulse && routeToFdi;

  assign fdi_rx_msg =
    rx_in_msg;

  // Route to the RDI controller for one controller-clock cycle.
  assign rdi_rx_valid =
    rxValidPulse && routeToRdi;

  assign rdi_rx_msg =
    rx_in_msg;

  // Unknown messages are reported and consumed only once.
  assign dropUnknown =
    rxValidPulse &&
    !routeToLtsm &&
    !routeToFdi &&
    !routeToRdi;

  // Ready condition for the selected destination.
  assign selectedSinkReady =
    (routeToLtsm && ltsm_rx_ready) ||
    (routeToFdi  && fdi_rx_ready)  ||
    (routeToRdi  && rdi_rx_ready)  ||
    dropUnknown;

  // Advertise ready while the physical source is idle.
  //
  // On the rising-edge cycle, ready follows the selected destination.
  // After that cycle, ready remains low while rx_in_valid remains high.
  // This prevents one held valid level from being counted repeatedly.
  assign rx_in_ready =
    !rx_in_valid ||
    (rxValidPulse && selectedSinkReady);

  // Debug routing outputs indicate actual one-cycle route events.
  assign rx_route_ltsm =
    rxValidPulse && routeToLtsm;

  assign rx_route_fdi =
    rxValidPulse && routeToFdi;

  assign rx_route_rdi =
    rxValidPulse && routeToRdi;

  assign rx_drop_unknown =
    dropUnknown;

  // A transaction occurs only once per rising edge and only if the selected
  // destination accepts it.
  assign rx_fire =
    rxValidPulse && selectedSinkReady;

endmodule

`default_nettype wire
```

<a id="LinkTrainingFSM-sv"></a>

## [7] LinkTrainingFSM.sv

```systemverilog
// FILE_INDEX: 7
// FILE_PATH : LinkTrainingFSM.sv

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

```

<a id="LtsmSidebandRxPulseAdapter-sv"></a>

## [8] LtsmSidebandRxPulseAdapter.sv

```systemverilog
// FILE_INDEX: 8
// FILE_PATH : LtsmSidebandRxPulseAdapter.sv

// Synthesizable compatibility adapter from valid/ready RX to a one-cycle LTSM pulse.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LtsmSidebandRxPulseAdapter (
  input  wire logic         clock,
  input  wire logic         reset_n,

  input  wire logic         in_valid,
  input  wire logic [127:0] in_msg,
  output var  logic         in_ready,

  output var  logic         out_valid,
  output var  logic [127:0] out_msg
);
  typedef enum logic [1:0] {
    RxState_Idle  = 2'd0,
    RxState_Pulse = 2'd1,
    RxState_Gap   = 2'd2
  } RxState_t;

  (* keep = "true" *) RxState_t     state;
  (* keep = "true" *) logic [127:0] msgReg;

  always_comb begin
    in_ready = (state == RxState_Idle);
    out_valid = (state == RxState_Pulse);
    out_msg = msgReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      state  <= RxState_Idle;
      msgReg <= 128'b0;
    end else begin
      case (state)
        RxState_Idle: begin
          if (in_valid && in_ready) begin
            msgReg <= in_msg;
            state  <= RxState_Pulse;
          end
        end

        RxState_Pulse: begin
          state <= RxState_Gap;
        end

        RxState_Gap: begin
          state <= RxState_Idle;
        end

        default: begin
          state  <= RxState_Idle;
          msgReg <= 128'b0;
        end
      endcase
    end
  end
endmodule

`default_nettype wire

```

<a id="LtsmSidebandTxCapture-sv"></a>

## [9] LtsmSidebandTxCapture.sv

```systemverilog
// FILE_INDEX: 9
// FILE_PATH : LtsmSidebandTxCapture.sv

// Synthesizable compatibility adapter for the LinkTrainingFSM TX pulse interface.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LtsmSidebandTxCapture #(
  parameter int unsigned ENTRIES = 4
) (
  input  wire logic         clock,
  input  wire logic         reset_n,

  input  wire logic         raw_valid,
  input  wire logic [127:0] raw_msg,
  output var  logic         raw_ready,

  output var  logic         out_valid,
  output var  logic [127:0] out_msg,
  input  wire logic         out_ready
);
  localparam int unsigned PTR_WIDTH   = (ENTRIES <= 2) ? 1 : $clog2(ENTRIES);
  localparam int unsigned COUNT_WIDTH = (ENTRIES < 2) ? 1 : $clog2(ENTRIES + 1);

  logic [127:0] queue_mem [0:ENTRIES-1];
  (* keep = "true" *) logic [PTR_WIDTH-1:0]   enq_ptr;
  (* keep = "true" *) logic [PTR_WIDTH-1:0]   deq_ptr;
  (* keep = "true" *) logic [COUNT_WIDTH-1:0] count;

  logic queue_enq_ready;
  logic enq_fire;
  logic deq_fire;

  function automatic logic [PTR_WIDTH-1:0] increment_ptr(
    input logic [PTR_WIDTH-1:0] ptr
  );
    if (ptr == ENTRIES - 1)
      increment_ptr = '0;
    else
      increment_ptr = ptr + 1'b1;
  endfunction

  // Reserve one entry for a pulse that the LTSM may generate on the cycle
  // after it sampled raw_ready high.
  always_comb begin
    raw_ready       = (count <= (ENTRIES - 2));
    queue_enq_ready = (count < ENTRIES);
    out_valid       = (count != 0);
    out_msg         = queue_mem[deq_ptr];
    enq_fire        = raw_valid && queue_enq_ready;
    deq_fire        = out_valid && out_ready;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      enq_ptr <= '0;
      deq_ptr <= '0;
      count   <= '0;
    end else begin
      if (enq_fire) begin
        queue_mem[enq_ptr] <= raw_msg;
        enq_ptr            <= increment_ptr(enq_ptr);
      end

      if (deq_fire)
        deq_ptr <= increment_ptr(deq_ptr);

      case ({enq_fire, deq_fire})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

`ifndef SYNTHESIS
  initial begin
    if (ENTRIES < 2)
      $fatal(1, "LtsmSidebandTxCapture ENTRIES must be at least 2");
  end

  always @(posedge clock) begin
    if (reset_n && raw_valid && !queue_enq_ready)
      $error("LTSM TX pulse arrived while the compatibility queue was full");
  end
`endif
endmodule

`default_nettype wire

```

<a id="MBInitFSM-sv"></a>

## [10] MBInitFSM.sv

```systemverilog
// FILE_INDEX: 10
// FILE_PATH : MBInitFSM.sv

// SystemVerilog translation of MBInitFSM.scala.
`default_nettype none

module MBInitFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic clock,
  input wire logic reset_n,
  input wire logic           start,
  output var logic           busy,
  output var logic           done,
  output var logic           trainError,
  output var logic [127:0]   sb_tx_din,
  output var logic           sb_tx_valid,
  input wire logic           sb_tx_ready,
  input wire logic [127:0]   sb_rx_dout,
  input wire logic           sb_rx_valid,
  input wire logic           flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic           flagFromAnalog_FinishedClkPatterns,
  input wire logic           flagFromAnalog_FinishedValTrainPattern,
  input wire logic           flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic           flagFromAnalog_ValTrainPatternReceived,
  input wire logic           flagFromAnalog_ReversalMbFinishedLaneIDPattern,
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
  input wire logic           flagFromAnalog_RepairMbFinishedLaneIDPattern,
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
  output var logic           flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic           flagToAnalog_RepairMbSetReceiver,
  output var logic           flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic           flagToAnalog_LaneReversalApplied,
  output var logic [2:0]     substate,
  output var logic [2:0]     dbg_mbinitRepairClkSenderState,
  output var logic [2:0]     dbg_mbinitRepairClkReceiverState,
  output var logic [2:0]     dbg_mbinitRepairValSenderState,
  output var logic [2:0]     dbg_mbinitRepairValReceiverState,
  output var logic [4:0]     dbg_mbinitReversalMbReceivedSuccessCount
);
  import SidebandMsgGenerator_pkg::*;

  // Portable synthesizable replacement for SystemVerilog $countones.
  function automatic logic [4:0] countOnes16(input logic [15:0] value);
    integer bit_index;
    begin
      countOnes16 = 5'd0;
      for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
        countOnes16 = countOnes16 + value[bit_index];
    end
  endfunction

  typedef enum logic [2:0] {
    MBInitState_PARAM = 3'd0,
    MBInitState_CAL = 3'd1,
    MBInitState_REPAIRCLK = 3'd2,
    MBInitState_REPAIRVAL = 3'd3,
    MBInitState_REVERSALMB = 3'd4,
    MBInitState_REPAIRMB = 3'd5,
    MBInitState_DONE = 3'd6
  } MBInitState_t;

  typedef enum logic [1:0] {
    ParamSenderState_sendReqHeader = 2'd0,
    ParamSenderState_waitResp = 2'd1,
    ParamSenderState_finish = 2'd2
  } ParamSenderState_t;

  typedef enum logic [1:0] {
    ParamReceiverState_waitReq = 2'd0,
    ParamReceiverState_validateReqPayload = 2'd1,
    ParamReceiverState_sendRespHeader = 2'd2,
    ParamReceiverState_finish = 2'd3
  } ParamReceiverState_t;

  typedef enum logic [1:0] {
    CalSenderState_sendDoneReq = 2'd0,
    CalSenderState_waitDoneResp = 2'd1,
    CalSenderState_finish = 2'd2
  } CalSenderState_t;

  typedef enum logic [1:0] {
    CalReceiverState_waitDoneReq = 2'd0,
    CalReceiverState_sendDoneResp = 2'd1,
    CalReceiverState_finish = 2'd2
  } CalReceiverState_t;

  typedef enum logic [2:0] {
    RepairClkSenderState_initReq = 3'd0,
    RepairClkSenderState_sendClkPatternsExchange = 3'd1,
    RepairClkSenderState_waitingPatternsExchangeFinish = 3'd2,
    RepairClkSenderState_sendResultReq = 3'd3,
    RepairClkSenderState_receiveResultResp = 3'd4,
    RepairClkSenderState_sendDoneReq = 3'd5,
    RepairClkSenderState_receiveDoneResp = 3'd6,
    RepairClkSenderState_finish = 3'd7
  } RepairClkSenderState_t;

  typedef enum logic [2:0] {
    RepairClkReceiverState_sendInitResp = 3'd0,
    RepairClkReceiverState_waitingPatternsExchangeFinish = 3'd1,
    RepairClkReceiverState_sendResultResp = 3'd2,
    RepairClkReceiverState_receiveDoneReq = 3'd3,
    RepairClkReceiverState_sendDoneResp = 3'd4,
    RepairClkReceiverState_finish = 3'd5
  } RepairClkReceiverState_t;

  typedef enum logic [2:0] {
    RepairValSenderState_initReq = 3'd0,
    RepairValSenderState_sendValTrainPattern = 3'd1,
    RepairValSenderState_waitingValTrainPatternFinish = 3'd2,
    RepairValSenderState_sendResultReq = 3'd3,
    RepairValSenderState_receiveResultResp = 3'd4,
    RepairValSenderState_sendDoneReq = 3'd5,
    RepairValSenderState_receiveDoneResp = 3'd6,
    RepairValSenderState_finish = 3'd7
  } RepairValSenderState_t;

  typedef enum logic [2:0] {
    RepairValReceiverState_sendInitResp = 3'd0,
    RepairValReceiverState_waitingValTrainPatternFinish = 3'd1,
    RepairValReceiverState_sendResultResp = 3'd2,
    RepairValReceiverState_receiveDoneReq = 3'd3,
    RepairValReceiverState_sendDoneResp = 3'd4,
    RepairValReceiverState_finish = 3'd5
  } RepairValReceiverState_t;

  typedef enum logic [3:0] {
    ReversalMbSenderState_initReq = 4'd0,
    ReversalMbSenderState_waitInitResp = 4'd1,
    ReversalMbSenderState_sendClearErrorReq = 4'd2,
    ReversalMbSenderState_waitClearErrorResp = 4'd3,
    ReversalMbSenderState_sendLaneIDPattern = 4'd4,
    ReversalMbSenderState_waitingLaneIDPatternFinish = 4'd5,
    ReversalMbSenderState_sendResultReq = 4'd6,
    ReversalMbSenderState_waitResultResp = 4'd7,
    ReversalMbSenderState_sendDoneReq = 4'd8,
    ReversalMbSenderState_waitDoneResp = 4'd9,
    ReversalMbSenderState_finish = 4'd10
  } ReversalMbSenderState_t;

  typedef enum logic [2:0] {
    ReversalMbReceiverState_sendInitResp = 3'd0,
    ReversalMbReceiverState_waitClearErrorReq = 3'd1,
    ReversalMbReceiverState_sendClearErrorResp = 3'd2,
    ReversalMbReceiverState_waitResultReq = 3'd3,
    ReversalMbReceiverState_sendResultResp = 3'd4,
    ReversalMbReceiverState_waitDoneReqOrClearErrorReq = 3'd5,
    ReversalMbReceiverState_sendDoneResp = 3'd6,
    ReversalMbReceiverState_finish = 3'd7
  } ReversalMbReceiverState_t;

  typedef enum logic [4:0] {
    RepairMbSenderState_sendStartReq = 5'd0,
    RepairMbSenderState_waitStartResp = 5'd1,
    RepairMbSenderState_d2cPointTestSendReq = 5'd2,
    RepairMbSenderState_d2cPointTestWaitResp = 5'd3,
    RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq = 5'd4,
    RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp = 5'd5,
    RepairMbSenderState_sendLaneIDPattern = 5'd6,
    RepairMbSenderState_waitingLaneIDPatternFinish = 5'd7,
    RepairMbSenderState_txInitD2CResultsSendReq = 5'd8,
    RepairMbSenderState_txInitD2CResultsWaitResp = 5'd9,
    RepairMbSenderState_endTxInitD2CPointTestSendReq = 5'd10,
    RepairMbSenderState_endTxInitD2CPointTestWaitResp = 5'd11,
    RepairMbSenderState_analyzeWidthDegradation = 5'd12,
    RepairMbSenderState_sendApplyDegradeReq = 5'd13,
    RepairMbSenderState_waitApplyDegradeResp = 5'd14,
    RepairMbSenderState_sendEndReq = 5'd15,
    RepairMbSenderState_waitEndResp = 5'd16,
    RepairMbSenderState_finish = 5'd17
  } RepairMbSenderState_t;

  typedef enum logic [3:0] {
    RepairMbReceiverState_waitStartReq = 4'd0,
    RepairMbReceiverState_sendStartResp = 4'd1,
    RepairMbReceiverState_waitD2CPointTestReq = 4'd2,
    RepairMbReceiverState_setReceiver = 4'd3,
    RepairMbReceiverState_sendD2CPointTestResp = 4'd4,
    RepairMbReceiverState_waitLfsrClearErrorReq = 4'd5,
    RepairMbReceiverState_sendLfsrClearErrorResp = 4'd6,
    RepairMbReceiverState_waitTxInitD2CResultsReq = 4'd7,
    RepairMbReceiverState_sendTxInitD2CResultsResp = 4'd8,
    RepairMbReceiverState_waitEndTxInitD2CPointTestReq = 4'd9,
    RepairMbReceiverState_sendEndTxInitD2CPointTestResp = 4'd10,
    RepairMbReceiverState_waitApplyDegradeReq = 4'd11,
    RepairMbReceiverState_sendApplyDegradeResp = 4'd12,
    RepairMbReceiverState_waitEndReq = 4'd13,
    RepairMbReceiverState_sendEndResp = 4'd14,
    RepairMbReceiverState_finish = 4'd15
  } RepairMbReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) MBInitState_t stateReg;
  (* keep = "true" *) logic flagMbinitParam_ReceivedReqHeader;
  (* keep = "true" *) logic flagMbinitParam_ReceivedReqPayload;
  (* keep = "true" *) logic flagMbinitParam_SentReq;
  (* keep = "true" *) logic flagMbinitParam_ReceivedRespHeader;
  (* keep = "true" *) logic flagMbinitParam_ReceivedRespPayload;
  (* keep = "true" *) logic flagMbinitParam_SentResp;
  (* keep = "true" *) logic flagMbinitParam_SendReq;
  (* keep = "true" *) logic flagMbinitParam_SendResp;
  (* keep = "true" *) logic flagMbinitParam_ReceivedCorrectReq;
  (* keep = "true" *) ParamSenderState_t paramSenderStateReg;
  (* keep = "true" *) ParamReceiverState_t paramReceiverStateReg;
  (* keep = "true" *) logic flagMbinitCal_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitCal_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitCal_SentDoneReq;
  (* keep = "true" *) logic flagMbinitCal_SentDoneResp;
  (* keep = "true" *) logic flagMbinitCal_SendDoneReq;
  (* keep = "true" *) logic flagMbinitCal_SendDoneResp;
  (* keep = "true" *) CalSenderState_t calSenderStateReg;
  (* keep = "true" *) CalReceiverState_t calReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SentResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SentDoneResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendDoneResp;
  (* keep = "true" *) logic [2:0] mbinitRepairClk_ReceivedResultBits;
  (* keep = "true" *) RepairClkSenderState_t repairClkSenderStateReg;
  (* keep = "true" *) RepairClkReceiverState_t repairClkReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairVal_SentInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SentResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SentDoneResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SendResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SendDoneResp;
  (* keep = "true" *) logic mbinitRepairVal_ReceivedResultBit;
  (* keep = "true" *) logic mbinitRepairVal_logValTrainPatternReceived;
  (* keep = "true" *) RepairValSenderState_t repairValSenderStateReg;
  (* keep = "true" *) RepairValReceiverState_t repairValReceiverStateReg;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultRespHeader;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultRespPayload;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendResultResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendDoneResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentResultResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentDoneResp;
  (* keep = "true" *) ReversalMbSenderState_t reversalMbSenderStateReg;
  (* keep = "true" *) ReversalMbReceiverState_t reversalMbReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestReqHeader;
  (* keep = "true" *) logic flagMbinitRepairMb_D2CPointTestReqWaitingPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestReqPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedApplyDegradeReq;
  (* keep = "true" *) logic [2:0] mbinitRepairMb_ReceivedApplyDegradeReqLaneMap;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ApplyWidthDegradation;
  (* keep = "true" *) logic [15:0] mbinitRepairMb_TxInitD2CResultsRespMsgInfo;
  (* keep = "true" *) logic [63:0] mbinitRepairMb_TxInitD2CResultsRespPayload;
  (* keep = "true" *) logic [15:0] mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits;
  (* keep = "true" *) logic flagMbinitRepairMb_SendStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendApplyDegradeReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendTxInitD2CResultsResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentApplyDegradeReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentTxInitD2CResultsResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndResp;
  (* keep = "true" *) RepairMbSenderState_t repairMbSenderStateReg;
  (* keep = "true" *) RepairMbReceiverState_t repairMbReceiverStateReg;
  (* keep = "true" *) logic [15:0] repairMb_DetectedLaneIDPatternLog;
  (* keep = "true" *) logic [15:0] reversalMbLaneStatusLog;
  (* keep = "true" *) logic reversalMb_LaneReversalApplied;
  (* keep = "true" *) logic [4:0] reversalMb_ReceivedSuccessCount;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRTRK_L;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRCKN_L;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRCKP_L;
  (* keep = "true" *) logic [63:0] remoteParamReqPayload;
  (* keep = "true" *) logic [63:0] remoteParamRespPayload;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBINIT_PARAM_REQ = msgMbinitParamConfigReq(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, sbFeatureExtension, ucieA, moduleID,
    clkPhase, clkMode, voltageSwing, maxLinkSpeed);
  wire [127:0] MBINIT_PARAM_RESP = msgMbinitParamConfigResp(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, clkPhase, clkMode, maxLinkSpeed);
  wire [127:0] MBINIT_CAL_DONE_REQ = msgMbinitCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_CAL_DONE_RESP = msgMbinitCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRCLK_INIT_REQ = msgMbinitRepairClkInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_INIT_RESP = msgMbinitRepairClkInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_RESULT_REQ = msgMbinitRepairClkResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_RESULT_RESP = msgMbinitRepairClkResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 1'b0, 1'b0, 1'b0);
  wire [127:0] MBINIT_REPAIRCLK_DONE_REQ = msgMbinitRepairClkDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_DONE_RESP = msgMbinitRepairClkDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRVAL_INIT_REQ = msgMbinitRepairValInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_INIT_RESP = msgMbinitRepairValInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_RESULT_REQ = msgMbinitRepairValResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_RESULT_RESP = msgMbinitRepairValResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 1'b0);
  wire [127:0] MBINIT_REPAIRVAL_DONE_REQ = msgMbinitRepairValDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_DONE_RESP = msgMbinitRepairValDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REVERSALMB_INIT_REQ = msgMbinitReversalMbInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_INIT_RESP = msgMbinitReversalMbInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_CLEAR_ERROR_REQ = msgMbinitReversalMbClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_CLEAR_ERROR_RESP = msgMbinitReversalMbClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_RESULT_REQ = msgMbinitReversalMbResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_RESULT_RESP = msgMbinitReversalMbResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0);
  wire [127:0] MBINIT_REVERSALMB_DONE_REQ = msgMbinitReversalMbDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_DONE_RESP = msgMbinitReversalMbDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRMB_START_REQ = msgMbinitRepairMbStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_START_RESP = msgMbinitRepairMbStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_D2C_POINT_TEST_REQ = msgMbinitRepairMbStartTxInitD2CPointTestReq(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0, 1'b0, 16'h0080, 16'b0,
    16'b0, 1'b0, 4'b0, 3'b0, 3'b001);
  wire [127:0] MBINIT_REPAIRMB_D2C_POINT_TEST_RESP = msgMbinitRepairMbStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ = msgMbinitRepairMbLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP = msgMbinitRepairMbLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ = msgMbinitRepairMbTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP = msgMbinitRepairMbTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0, 64'b0);
  wire [127:0] MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ = msgMbinitRepairMbEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP = msgMbinitRepairMbEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_APPLY_DEGRADE_REQ_TEMPLATE = msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b000);
  wire [127:0] MBINIT_REPAIRMB_APPLY_DEGRADE_RESP = msgMbinitRepairMbApplyDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_REQ = msgMbinitRepairMbEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_RESP = msgMbinitRepairMbEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    trainError = trainErrorReg;
    done = running && (stateReg == MBInitState_DONE);
    busy = running && (stateReg != MBInitState_DONE);

    flagToAnalog_RepairClkState = running && (stateReg == MBInitState_REPAIRCLK);
    flagToAnalog_SendClkPatterns = running &&
      (stateReg == MBInitState_REPAIRCLK) &&
      (repairClkSenderStateReg == RepairClkSenderState_sendClkPatternsExchange) &&
      flagMbinitRepairClk_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns;
    flagToAnalog_RepairValState = running && (stateReg == MBInitState_REPAIRVAL);
    flagToAnalog_SendValTrainPattern = running &&
      (stateReg == MBInitState_REPAIRVAL) &&
      (repairValSenderStateReg == RepairValSenderState_sendValTrainPattern) &&
      flagMbinitRepairVal_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns;
    flagToAnalog_ReversalMbSendLaneIDPattern = running &&
      (stateReg == MBInitState_REVERSALMB) &&
      (reversalMbSenderStateReg == ReversalMbSenderState_sendLaneIDPattern);
    flagToAnalog_RepairMbSendLaneIDPattern = running &&
      (stateReg == MBInitState_REPAIRMB) &&
      (repairMbSenderStateReg == RepairMbSenderState_sendLaneIDPattern);
    flagToAnalog_RepairMbSetReceiver = running &&
      (stateReg == MBInitState_REPAIRMB) &&
      (repairMbReceiverStateReg == RepairMbReceiverState_setReceiver);
    flagToAnalog_LaneReversalApplied = reversalMb_LaneReversalApplied;

    substate = stateReg;
    dbg_mbinitRepairClkSenderState = repairClkSenderStateReg;
    dbg_mbinitRepairClkReceiverState = repairClkReceiverStateReg;
    dbg_mbinitRepairValSenderState = repairValSenderStateReg;
    dbg_mbinitRepairValReceiverState = repairValReceiverStateReg;
    dbg_mbinitReversalMbReceivedSuccessCount = reversalMb_ReceivedSuccessCount;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
      trainErrorReg <= 1'b0;
      running <= 1'b0;
      stateReg <= MBInitState_PARAM;
      flagMbinitParam_ReceivedReqHeader <= 1'b0;
      flagMbinitParam_ReceivedReqPayload <= 1'b0;
      flagMbinitParam_SentReq <= 1'b0;
      flagMbinitParam_ReceivedRespHeader <= 1'b0;
      flagMbinitParam_ReceivedRespPayload <= 1'b0;
      flagMbinitParam_SentResp <= 1'b0;
      flagMbinitParam_SendReq <= 1'b0;
      flagMbinitParam_SendResp <= 1'b0;
      flagMbinitParam_ReceivedCorrectReq <= 1'b0;
      paramSenderStateReg <= ParamSenderState_sendReqHeader;
      paramReceiverStateReg <= ParamReceiverState_waitReq;
      flagMbinitCal_ReceivedDoneReq <= 1'b0;
      flagMbinitCal_ReceivedDoneResp <= 1'b0;
      flagMbinitCal_SentDoneReq <= 1'b0;
      flagMbinitCal_SentDoneResp <= 1'b0;
      flagMbinitCal_SendDoneReq <= 1'b0;
      flagMbinitCal_SendDoneResp <= 1'b0;
      calSenderStateReg <= CalSenderState_sendDoneReq;
      calReceiverStateReg <= CalReceiverState_waitDoneReq;
      flagMbinitRepairClk_ReceivedInitResp <= 1'b0;
      flagMbinitRepairClk_ReceivedInitReq <= 1'b0;
      flagMbinitRepairClk_ReceivedResultResp <= 1'b0;
      flagMbinitRepairClk_ReceivedResultReq <= 1'b0;
      flagMbinitRepairClk_ReceivedDoneResp <= 1'b0;
      flagMbinitRepairClk_ReceivedDoneReq <= 1'b0;
      flagMbinitRepairClk_SentInitReq <= 1'b0;
      flagMbinitRepairClk_SentResultReq <= 1'b0;
      flagMbinitRepairClk_SentDoneReq <= 1'b0;
      flagMbinitRepairClk_SentInitResp <= 1'b0;
      flagMbinitRepairClk_SentResultResp <= 1'b0;
      flagMbinitRepairClk_SentDoneResp <= 1'b0;
      flagMbinitRepairClk_SendInitReq <= 1'b0;
      flagMbinitRepairClk_SendResultReq <= 1'b0;
      flagMbinitRepairClk_SendDoneReq <= 1'b0;
      flagMbinitRepairClk_SendInitResp <= 1'b0;
      flagMbinitRepairClk_SendResultResp <= 1'b0;
      flagMbinitRepairClk_SendDoneResp <= 1'b0;
      mbinitRepairClk_ReceivedResultBits <= 3'b0;
      repairClkSenderStateReg <= RepairClkSenderState_initReq;
      repairClkReceiverStateReg <= RepairClkReceiverState_sendInitResp;
      flagMbinitRepairVal_SentInitReq <= 1'b0;
      flagMbinitRepairVal_SentResultReq <= 1'b0;
      flagMbinitRepairVal_SentDoneReq <= 1'b0;
      flagMbinitRepairVal_SentInitResp <= 1'b0;
      flagMbinitRepairVal_SentResultResp <= 1'b0;
      flagMbinitRepairVal_SentDoneResp <= 1'b0;
      flagMbinitRepairVal_ReceivedInitResp <= 1'b0;
      flagMbinitRepairVal_ReceivedInitReq <= 1'b0;
      flagMbinitRepairVal_ReceivedResultResp <= 1'b0;
      flagMbinitRepairVal_ReceivedResultReq <= 1'b0;
      flagMbinitRepairVal_ReceivedDoneResp <= 1'b0;
      flagMbinitRepairVal_ReceivedDoneReq <= 1'b0;
      flagMbinitRepairVal_SendInitReq <= 1'b0;
      flagMbinitRepairVal_SendResultReq <= 1'b0;
      flagMbinitRepairVal_SendDoneReq <= 1'b0;
      flagMbinitRepairVal_SendInitResp <= 1'b0;
      flagMbinitRepairVal_SendResultResp <= 1'b0;
      flagMbinitRepairVal_SendDoneResp <= 1'b0;
      mbinitRepairVal_ReceivedResultBit <= 1'b0;
      mbinitRepairVal_logValTrainPatternReceived <= 1'b0;
      repairValSenderStateReg <= RepairValSenderState_initReq;
      repairValReceiverStateReg <= RepairValReceiverState_sendInitResp;
      flagMbinitReversalMb_ReceivedInitReq <= 1'b0;
      flagMbinitReversalMb_ReceivedInitResp <= 1'b0;
      flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
      flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
      flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
      flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
      flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
      flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
      flagMbinitReversalMb_ReceivedDoneResp <= 1'b0;
      flagMbinitReversalMb_SendInitReq <= 1'b0;
      flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
      flagMbinitReversalMb_SendResultReq <= 1'b0;
      flagMbinitReversalMb_SendDoneReq <= 1'b0;
      flagMbinitReversalMb_SendInitResp <= 1'b0;
      flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
      flagMbinitReversalMb_SendResultResp <= 1'b0;
      flagMbinitReversalMb_SendDoneResp <= 1'b0;
      flagMbinitReversalMb_SentInitReq <= 1'b0;
      flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
      flagMbinitReversalMb_SentResultReq <= 1'b0;
      flagMbinitReversalMb_SentDoneReq <= 1'b0;
      flagMbinitReversalMb_SentInitResp <= 1'b0;
      flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
      flagMbinitReversalMb_SentResultResp <= 1'b0;
      flagMbinitReversalMb_SentDoneResp <= 1'b0;
      reversalMbSenderStateReg <= ReversalMbSenderState_initReq;
      reversalMbReceiverStateReg <= ReversalMbReceiverState_sendInitResp;
      flagMbinitRepairMb_ReceivedStartReq <= 1'b0;
      flagMbinitRepairMb_ReceivedStartResp <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b0;
      flagMbinitRepairMb_D2CPointTestReqWaitingPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b0;
      mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= 3'b0;
      flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
      flagMbinitRepairMb_ReceivedEndResp <= 1'b0;
      flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
      mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= 16'b0;
      mbinitRepairMb_TxInitD2CResultsRespPayload <= 64'b0;
      mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= 16'b0;
      flagMbinitRepairMb_SendStartReq <= 1'b0;
      flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
      flagMbinitRepairMb_SendEndReq <= 1'b0;
      flagMbinitRepairMb_SendStartResp <= 1'b0;
      flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
      flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_SendEndResp <= 1'b0;
      flagMbinitRepairMb_SentStartReq <= 1'b0;
      flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
      flagMbinitRepairMb_SentEndReq <= 1'b0;
      flagMbinitRepairMb_SentStartResp <= 1'b0;
      flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
      flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_SentEndResp <= 1'b0;
      repairMbSenderStateReg <= RepairMbSenderState_sendStartReq;
      repairMbReceiverStateReg <= RepairMbReceiverState_waitStartReq;
      repairMb_DetectedLaneIDPatternLog <= 16'b0;
      reversalMbLaneStatusLog <= 16'b0;
      reversalMb_LaneReversalApplied <= 1'b0;
      reversalMb_ReceivedSuccessCount <= 5'b0;
      mbinitRepairClk_logClkPatternReceivedRTRK_L <= 1'b0;
      mbinitRepairClk_logClkPatternReceivedRCKN_L <= 1'b0;
      mbinitRepairClk_logClkPatternReceivedRCKP_L <= 1'b0;
      remoteParamReqPayload <= 64'b0;
      remoteParamRespPayload <= 64'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
    end else begin
      // RegNext semantics and the source's defaulted pulse-style TX registers.
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;

      if (startPulse) begin
        running <= 1'b1;
        stateReg <= MBInitState_PARAM;
        trainErrorReg <= 1'b0;
        flagMbinitParam_ReceivedReqHeader <= 1'b0;
        flagMbinitParam_ReceivedReqPayload <= 1'b0;
        flagMbinitParam_SentReq <= 1'b0;
        flagMbinitParam_ReceivedRespHeader <= 1'b0;
        flagMbinitParam_ReceivedRespPayload <= 1'b0;
        flagMbinitParam_SentResp <= 1'b0;
        flagMbinitParam_SendReq <= 1'b0;
        flagMbinitParam_SendResp <= 1'b0;
        flagMbinitParam_ReceivedCorrectReq <= 1'b0;
        paramSenderStateReg <= ParamSenderState_sendReqHeader;
        paramReceiverStateReg <= ParamReceiverState_waitReq;
        flagMbinitCal_ReceivedDoneReq <= 1'b0;
        flagMbinitCal_ReceivedDoneResp <= 1'b0;
        flagMbinitCal_SentDoneReq <= 1'b0;
        flagMbinitCal_SentDoneResp <= 1'b0;
        flagMbinitCal_SendDoneReq <= 1'b0;
        flagMbinitCal_SendDoneResp <= 1'b0;
        calSenderStateReg <= CalSenderState_sendDoneReq;
        calReceiverStateReg <= CalReceiverState_waitDoneReq;
        flagMbinitRepairClk_ReceivedInitResp <= 1'b0;
        flagMbinitRepairClk_ReceivedInitReq <= 1'b0;
        flagMbinitRepairClk_ReceivedResultResp <= 1'b0;
        flagMbinitRepairClk_ReceivedResultReq <= 1'b0;
        flagMbinitRepairClk_ReceivedDoneResp <= 1'b0;
        flagMbinitRepairClk_ReceivedDoneReq <= 1'b0;
        flagMbinitRepairClk_SentInitReq <= 1'b0;
        flagMbinitRepairClk_SentResultReq <= 1'b0;
        flagMbinitRepairClk_SentDoneReq <= 1'b0;
        flagMbinitRepairClk_SentInitResp <= 1'b0;
        flagMbinitRepairClk_SentResultResp <= 1'b0;
        flagMbinitRepairClk_SentDoneResp <= 1'b0;
        flagMbinitRepairClk_SendInitReq <= 1'b0;
        flagMbinitRepairClk_SendResultReq <= 1'b0;
        flagMbinitRepairClk_SendDoneReq <= 1'b0;
        flagMbinitRepairClk_SendInitResp <= 1'b0;
        flagMbinitRepairClk_SendResultResp <= 1'b0;
        flagMbinitRepairClk_SendDoneResp <= 1'b0;
        mbinitRepairClk_ReceivedResultBits <= 0;
        repairClkSenderStateReg <= RepairClkSenderState_initReq;
        repairClkReceiverStateReg <= RepairClkReceiverState_sendInitResp;
        flagMbinitRepairVal_SentInitReq <= 1'b0;
        flagMbinitRepairVal_SentResultReq <= 1'b0;
        flagMbinitRepairVal_SentDoneReq <= 1'b0;
        flagMbinitRepairVal_SentInitResp <= 1'b0;
        flagMbinitRepairVal_SentResultResp <= 1'b0;
        flagMbinitRepairVal_SentDoneResp <= 1'b0;
        flagMbinitRepairVal_ReceivedInitResp <= 1'b0;
        flagMbinitRepairVal_ReceivedInitReq <= 1'b0;
        flagMbinitRepairVal_ReceivedResultResp <= 1'b0;
        flagMbinitRepairVal_ReceivedResultReq <= 1'b0;
        flagMbinitRepairVal_ReceivedDoneResp <= 1'b0;
        flagMbinitRepairVal_ReceivedDoneReq <= 1'b0;
        flagMbinitRepairVal_SendInitReq <= 1'b0;
        flagMbinitRepairVal_SendResultReq <= 1'b0;
        flagMbinitRepairVal_SendDoneReq <= 1'b0;
        flagMbinitRepairVal_SendInitResp <= 1'b0;
        flagMbinitRepairVal_SendResultResp <= 1'b0;
        flagMbinitRepairVal_SendDoneResp <= 1'b0;
        mbinitRepairVal_ReceivedResultBit <= 1'b0;
        mbinitRepairVal_logValTrainPatternReceived <= 1'b0;
        repairValSenderStateReg <= RepairValSenderState_initReq;
        repairValReceiverStateReg <= RepairValReceiverState_sendInitResp;
        flagMbinitReversalMb_ReceivedInitReq <= 1'b0;
        flagMbinitReversalMb_ReceivedInitResp <= 1'b0;
        flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
        flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
        flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
        flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
        flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
        flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
        flagMbinitReversalMb_ReceivedDoneResp <= 1'b0;
        flagMbinitReversalMb_SendInitReq <= 1'b0;
        flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
        flagMbinitReversalMb_SendResultReq <= 1'b0;
        flagMbinitReversalMb_SendDoneReq <= 1'b0;
        flagMbinitReversalMb_SendInitResp <= 1'b0;
        flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
        flagMbinitReversalMb_SendResultResp <= 1'b0;
        flagMbinitReversalMb_SendDoneResp <= 1'b0;
        flagMbinitReversalMb_SentInitReq <= 1'b0;
        flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
        flagMbinitReversalMb_SentResultReq <= 1'b0;
        flagMbinitReversalMb_SentDoneReq <= 1'b0;
        flagMbinitReversalMb_SentInitResp <= 1'b0;
        flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
        flagMbinitReversalMb_SentResultResp <= 1'b0;
        flagMbinitReversalMb_SentDoneResp <= 1'b0;
        reversalMbSenderStateReg <= ReversalMbSenderState_initReq;
        reversalMbReceiverStateReg <= ReversalMbReceiverState_sendInitResp;
        flagMbinitRepairMb_ReceivedStartReq <= 1'b0;
        flagMbinitRepairMb_ReceivedStartResp <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b0;
        flagMbinitRepairMb_D2CPointTestReqWaitingPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b0;
        mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= 0;
        flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
        flagMbinitRepairMb_ReceivedEndResp <= 1'b0;
        flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
        mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= 0;
        mbinitRepairMb_TxInitD2CResultsRespPayload <= 0;
        mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= 0;
        flagMbinitRepairMb_SendStartReq <= 1'b0;
        flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
        flagMbinitRepairMb_SendEndReq <= 1'b0;
        flagMbinitRepairMb_SendStartResp <= 1'b0;
        flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
        flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_SendEndResp <= 1'b0;
        flagMbinitRepairMb_SentStartReq <= 1'b0;
        flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
        flagMbinitRepairMb_SentEndReq <= 1'b0;
        flagMbinitRepairMb_SentStartResp <= 1'b0;
        flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
        flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_SentEndResp <= 1'b0;
        repairMbSenderStateReg <= RepairMbSenderState_sendStartReq;
        repairMbReceiverStateReg <= RepairMbReceiverState_waitStartReq;
        repairMb_DetectedLaneIDPatternLog <= 0;
        reversalMbLaneStatusLog <= 0;
        reversalMb_LaneReversalApplied <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRTRK_L <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRCKN_L <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRCKP_L <= 1'b0;
        remoteParamReqPayload <= 0;
        remoteParamRespPayload <= 0;
      end
      if (!start && stateReg == MBInitState_DONE) begin
        running <= 1'b0;
      end
      if (rxValidRisingEdge) begin
        if (sb_rx_dout == MBINIT_PARAM_REQ) begin
          flagMbinitParam_ReceivedReqHeader <= 1'b1;
          flagMbinitParam_ReceivedReqPayload <= 1'b1;
          remoteParamReqPayload <= sb_rx_dout[127:64];
        end
        if (sb_rx_dout == MBINIT_PARAM_RESP) begin
          flagMbinitParam_ReceivedRespHeader <= 1'b1;
          flagMbinitParam_ReceivedRespPayload <= 1'b1;
          remoteParamRespPayload <= sb_rx_dout[127:64];
        end
        if (sb_rx_dout == MBINIT_CAL_DONE_REQ) begin
          flagMbinitCal_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_CAL_DONE_RESP) begin
          flagMbinitCal_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_INIT_REQ) begin
          flagMbinitRepairClk_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_INIT_RESP) begin
          flagMbinitRepairClk_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_RESULT_REQ) begin
          flagMbinitRepairClk_ReceivedResultReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFF8FFFFFFFFFF}) == (MBINIT_REPAIRCLK_RESULT_RESP & {64'd0, 64'hBFFFF8FFFFFFFFFF})) begin
          flagMbinitRepairClk_ReceivedResultResp <= 1'b1;
          mbinitRepairClk_ReceivedResultBits <= sb_rx_dout[42:40];
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_DONE_REQ) begin
          flagMbinitRepairClk_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_DONE_RESP) begin
          flagMbinitRepairClk_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_INIT_REQ) begin
          flagMbinitRepairVal_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_INIT_RESP) begin
          flagMbinitRepairVal_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_RESULT_REQ) begin
          flagMbinitRepairVal_ReceivedResultReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFFEFFFFFFFFFF}) == (MBINIT_REPAIRVAL_RESULT_RESP & {64'd0, 64'hBFFFFEFFFFFFFFFF})) begin
          flagMbinitRepairVal_ReceivedResultResp <= 1'b1;
          mbinitRepairVal_ReceivedResultBit <= sb_rx_dout[40];
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_DONE_REQ) begin
          flagMbinitRepairVal_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_DONE_RESP) begin
          flagMbinitRepairVal_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_INIT_REQ) begin
          flagMbinitReversalMb_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_INIT_RESP) begin
          flagMbinitReversalMb_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_CLEAR_ERROR_REQ) begin
          flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_CLEAR_ERROR_RESP) begin
          flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_RESULT_REQ) begin
          flagMbinitReversalMb_ReceivedResultReq <= 1'b1;
        end
        if (sb_rx_dout[63:0] == MBINIT_REVERSALMB_RESULT_RESP[63:0]) begin
          flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b1;
          flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b1;
          reversalMb_ReceivedSuccessCount <= countOnes16(sb_rx_dout[79:64]);
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_DONE_REQ) begin
          flagMbinitReversalMb_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_DONE_RESP) begin
          flagMbinitReversalMb_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_START_REQ) begin
          flagMbinitRepairMb_ReceivedStartReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_START_RESP) begin
          flagMbinitRepairMb_ReceivedStartResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_D2C_POINT_TEST_REQ) begin
          flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b1;
          flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_D2C_POINT_TEST_RESP) begin
          flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ) begin
          flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP) begin
          flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ) begin
          flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'h3F0000FFFFFFFFFF}) == (MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP & {64'd0, 64'h3F0000FFFFFFFFFF})) begin
          flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b1;
          flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b1;
          mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= sb_rx_dout[55:40];
          mbinitRepairMb_TxInitD2CResultsRespPayload <= sb_rx_dout[127:64];
          mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= sb_rx_dout[79:64];
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ) begin
          flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP) begin
          flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFF8FFFFFFFFFF}) == (MBINIT_REPAIRMB_APPLY_DEGRADE_REQ_TEMPLATE & {64'd0, 64'hBFFFF8FFFFFFFFFF})) begin
          flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b1;
          mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= sb_rx_dout[42:40];
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_APPLY_DEGRADE_RESP) begin
          flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_REQ) begin
          flagMbinitRepairMb_ReceivedEndReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_RESP) begin
          flagMbinitRepairMb_ReceivedEndResp <= 1'b1;
        end
      end
      if (running) begin
        unique case (stateReg)
          MBInitState_PARAM: begin
            unique case (paramSenderStateReg)
              ParamSenderState_sendReqHeader: begin
                if (flagMbinitParam_SentReq) begin
                  flagMbinitParam_SendReq <= 1'b0;
                  paramSenderStateReg <= ParamSenderState_waitResp;
                end
                else begin
                  flagMbinitParam_SendReq <= 1'b1;
                end
              end
              ParamSenderState_waitResp: begin
                if (flagMbinitParam_ReceivedRespHeader && flagMbinitParam_ReceivedRespPayload) begin
                  paramSenderStateReg <= ParamSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (paramReceiverStateReg)
              ParamReceiverState_waitReq: begin
                if (flagMbinitParam_ReceivedReqHeader && flagMbinitParam_ReceivedReqPayload) begin
                  paramReceiverStateReg <= ParamReceiverState_validateReqPayload;
                end
              end
              ParamReceiverState_validateReqPayload: begin
                if (remoteParamReqPayload == MBINIT_PARAM_REQ[127:64]) begin
                  flagMbinitParam_ReceivedCorrectReq <= 1'b1;
                  paramReceiverStateReg <= ParamReceiverState_sendRespHeader;
                end
                else begin
                  trainErrorReg <= 1'b1;
                end
              end
              ParamReceiverState_sendRespHeader: begin
                if (flagMbinitParam_SentResp) begin
                  flagMbinitParam_SendResp <= 1'b0;
                  paramReceiverStateReg <= ParamReceiverState_finish;
                end
                else begin
                  flagMbinitParam_SendResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitParam_SendResp) begin
                sbTxDin <= MBINIT_PARAM_RESP;
                sbTxValid <= 1'b1;
                flagMbinitParam_SentResp <= 1'b1;
              end
              else if (flagMbinitParam_SendReq) begin
                sbTxDin <= MBINIT_PARAM_REQ;
                sbTxValid <= 1'b1;
                flagMbinitParam_SentReq <= 1'b1;
              end
            end
            if (paramSenderStateReg == ParamSenderState_finish && paramReceiverStateReg == ParamReceiverState_finish) begin
              flagMbinitParam_SendReq <= 1'b0;
              flagMbinitParam_SendResp <= 1'b0;
              flagMbinitParam_SentReq <= 1'b0;
              flagMbinitParam_SentResp <= 1'b0;
              stateReg <= MBInitState_CAL;
            end
          end
          MBInitState_CAL: begin
            unique case (calSenderStateReg)
              CalSenderState_sendDoneReq: begin
                if (flagMbinitCal_SentDoneReq) begin
                  flagMbinitCal_SendDoneReq <= 1'b0;
                  calSenderStateReg <= CalSenderState_waitDoneResp;
                end
                else begin
                  flagMbinitCal_SendDoneReq <= 1'b1;
                end
              end
              CalSenderState_waitDoneResp: begin
                if (flagMbinitCal_ReceivedDoneResp) begin
                  calSenderStateReg <= CalSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (calReceiverStateReg)
              CalReceiverState_waitDoneReq: begin
                if (flagMbinitCal_ReceivedDoneReq) begin
                  calReceiverStateReg <= CalReceiverState_sendDoneResp;
                end
              end
              CalReceiverState_sendDoneResp: begin
                if (flagMbinitCal_SentDoneResp) begin
                  flagMbinitCal_SendDoneResp <= 1'b0;
                  calReceiverStateReg <= CalReceiverState_finish;
                end
                else begin
                  flagMbinitCal_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitCal_SendDoneResp) begin
                sbTxDin <= MBINIT_CAL_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitCal_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitCal_SendDoneReq) begin
                sbTxDin <= MBINIT_CAL_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitCal_SentDoneReq <= 1'b1;
              end
            end
            if (calSenderStateReg == CalSenderState_finish && calReceiverStateReg == CalReceiverState_finish) begin
              flagMbinitCal_SendDoneReq <= 1'b0;
              flagMbinitCal_SendDoneResp <= 1'b0;
              flagMbinitCal_SentDoneReq <= 1'b0;
              flagMbinitCal_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRCLK;
            end
          end
          MBInitState_REPAIRCLK: begin
            unique case (repairClkSenderStateReg)
              RepairClkSenderState_initReq: begin
                if (flagMbinitRepairClk_SentInitReq) begin
                  flagMbinitRepairClk_SendInitReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_sendClkPatternsExchange;
                end
                else begin
                  flagMbinitRepairClk_SendInitReq <= 1'b1;
                end
              end
              RepairClkSenderState_sendClkPatternsExchange: begin
                if (flagMbinitRepairClk_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  repairClkSenderStateReg <= RepairClkSenderState_waitingPatternsExchangeFinish;
                end
              end
              RepairClkSenderState_waitingPatternsExchangeFinish: begin
                if (flagFromAnalog_FinishedClkPatterns) begin
                  repairClkSenderStateReg <= RepairClkSenderState_sendResultReq;
                end
              end
              RepairClkSenderState_sendResultReq: begin
                if (flagMbinitRepairClk_SentResultReq) begin
                  flagMbinitRepairClk_SendResultReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_receiveResultResp;
                end
                else begin
                  flagMbinitRepairClk_SendResultReq <= 1'b1;
                end
              end
              RepairClkSenderState_receiveResultResp: begin
                if (flagMbinitRepairClk_ReceivedResultResp) begin
                  if (mbinitRepairClk_ReceivedResultBits == 3'b111) begin
                    repairClkSenderStateReg <= RepairClkSenderState_sendDoneReq;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairClkSenderState_sendDoneReq: begin
                if (flagMbinitRepairClk_SentDoneReq) begin
                  flagMbinitRepairClk_SendDoneReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_receiveDoneResp;
                end
                else begin
                  flagMbinitRepairClk_SendDoneReq <= 1'b1;
                end
              end
              RepairClkSenderState_receiveDoneResp: begin
                if (flagMbinitRepairClk_ReceivedDoneResp) begin
                  repairClkSenderStateReg <= RepairClkSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (repairClkReceiverStateReg)
              RepairClkReceiverState_sendInitResp: begin
                if (flagMbinitRepairClk_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitRepairClk_SentInitResp) begin
                    flagMbinitRepairClk_SendInitResp <= 1'b0;
                    repairClkReceiverStateReg <= RepairClkReceiverState_waitingPatternsExchangeFinish;
                  end
                  else begin
                    flagMbinitRepairClk_SendInitResp <= 1'b1;
                  end
                end
              end
              RepairClkReceiverState_waitingPatternsExchangeFinish: begin
                if (flagMbinitRepairClk_ReceivedResultReq) begin
                  mbinitRepairClk_logClkPatternReceivedRTRK_L <= flagFromAnalog_clkPatternReceivedRTRK_L;
                  mbinitRepairClk_logClkPatternReceivedRCKN_L <= flagFromAnalog_clkPatternReceivedRCKN_L;
                  mbinitRepairClk_logClkPatternReceivedRCKP_L <= flagFromAnalog_clkPatternReceivedRCKP_L;
                  if (flagFromAnalog_clkPatternReceivedRTRK_L && flagFromAnalog_clkPatternReceivedRCKN_L && flagFromAnalog_clkPatternReceivedRCKP_L) begin
                    repairClkReceiverStateReg <= RepairClkReceiverState_sendResultResp;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairClkReceiverState_sendResultResp: begin
                if (flagMbinitRepairClk_SentResultResp) begin
                  flagMbinitRepairClk_SendResultResp <= 1'b0;
                  repairClkReceiverStateReg <= RepairClkReceiverState_receiveDoneReq;
                end
                else begin
                  flagMbinitRepairClk_SendResultResp <= 1'b1;
                end
              end
              RepairClkReceiverState_receiveDoneReq: begin
                if (flagMbinitRepairClk_ReceivedDoneReq) begin
                  repairClkReceiverStateReg <= RepairClkReceiverState_sendDoneResp;
                end
              end
              RepairClkReceiverState_sendDoneResp: begin
                if (flagMbinitRepairClk_SentDoneResp) begin
                  flagMbinitRepairClk_SendDoneResp <= 1'b0;
                  repairClkReceiverStateReg <= RepairClkReceiverState_finish;
                end
                else begin
                  flagMbinitRepairClk_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairClk_SendInitResp) begin
                sbTxDin <= MBINIT_REPAIRCLK_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentInitResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendResultResp) begin
                sbTxDin <= msgMbinitRepairClkResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, mbinitRepairClk_logClkPatternReceivedRTRK_L, mbinitRepairClk_logClkPatternReceivedRCKN_L, mbinitRepairClk_logClkPatternReceivedRCKP_L );
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentResultResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendDoneResp) begin
                sbTxDin <= MBINIT_REPAIRCLK_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendInitReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentInitReq <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendResultReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentResultReq <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendDoneReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentDoneReq <= 1'b1;
              end
            end
            if (repairClkReceiverStateReg == RepairClkReceiverState_finish && repairClkSenderStateReg == RepairClkSenderState_finish) begin
              flagMbinitRepairClk_SendInitReq <= 1'b0;
              flagMbinitRepairClk_SendResultReq <= 1'b0;
              flagMbinitRepairClk_SendDoneReq <= 1'b0;
              flagMbinitRepairClk_SendInitResp <= 1'b0;
              flagMbinitRepairClk_SendResultResp <= 1'b0;
              flagMbinitRepairClk_SendDoneResp <= 1'b0;
              flagMbinitRepairClk_SentInitReq <= 1'b0;
              flagMbinitRepairClk_SentResultReq <= 1'b0;
              flagMbinitRepairClk_SentDoneReq <= 1'b0;
              flagMbinitRepairClk_SentInitResp <= 1'b0;
              flagMbinitRepairClk_SentResultResp <= 1'b0;
              flagMbinitRepairClk_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRVAL;
            end
          end
          MBInitState_REPAIRVAL: begin
            unique case (repairValSenderStateReg)
              RepairValSenderState_initReq: begin
                if (flagMbinitRepairVal_SentInitReq) begin
                  flagMbinitRepairVal_SendInitReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_sendValTrainPattern;
                end
                else begin
                  flagMbinitRepairVal_SendInitReq <= 1'b1;
                end
              end
              RepairValSenderState_sendValTrainPattern: begin
                if (flagMbinitRepairVal_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  repairValSenderStateReg <= RepairValSenderState_waitingValTrainPatternFinish;
                end
              end
              RepairValSenderState_waitingValTrainPatternFinish: begin
                if (flagFromAnalog_FinishedValTrainPattern) begin
                  repairValSenderStateReg <= RepairValSenderState_sendResultReq;
                end
              end
              RepairValSenderState_sendResultReq: begin
                if (flagMbinitRepairVal_SentResultReq) begin
                  flagMbinitRepairVal_SendResultReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_receiveResultResp;
                end
                else begin
                  flagMbinitRepairVal_SendResultReq <= 1'b1;
                end
              end
              RepairValSenderState_receiveResultResp: begin
                if (flagMbinitRepairVal_ReceivedResultResp) begin
                  if (mbinitRepairVal_ReceivedResultBit) begin
                    repairValSenderStateReg <= RepairValSenderState_sendDoneReq;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairValSenderState_sendDoneReq: begin
                if (flagMbinitRepairVal_SentDoneReq) begin
                  flagMbinitRepairVal_SendDoneReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_receiveDoneResp;
                end
                else begin
                  flagMbinitRepairVal_SendDoneReq <= 1'b1;
                end
              end
              RepairValSenderState_receiveDoneResp: begin
                if (flagMbinitRepairVal_ReceivedDoneResp) begin
                  repairValSenderStateReg <= RepairValSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (repairValReceiverStateReg)
              RepairValReceiverState_sendInitResp: begin
                if (flagMbinitRepairVal_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitRepairVal_SentInitResp) begin
                    flagMbinitRepairVal_SendInitResp <= 1'b0;
                    repairValReceiverStateReg <= RepairValReceiverState_waitingValTrainPatternFinish;
                  end
                  else begin
                    flagMbinitRepairVal_SendInitResp <= 1'b1;
                  end
                end
              end
              RepairValReceiverState_waitingValTrainPatternFinish: begin
                if (flagMbinitRepairVal_ReceivedResultReq) begin
                  mbinitRepairVal_logValTrainPatternReceived <= flagFromAnalog_ValTrainPatternReceived;
                  repairValReceiverStateReg <= RepairValReceiverState_sendResultResp;
                end
              end
              RepairValReceiverState_sendResultResp: begin
                if (flagMbinitRepairVal_SentResultResp) begin
                  flagMbinitRepairVal_SendResultResp <= 1'b0;
                  repairValReceiverStateReg <= RepairValReceiverState_receiveDoneReq;
                end
                else begin
                  flagMbinitRepairVal_SendResultResp <= 1'b1;
                end
              end
              RepairValReceiverState_receiveDoneReq: begin
                if (flagMbinitRepairVal_ReceivedDoneReq) begin
                  repairValReceiverStateReg <= RepairValReceiverState_sendDoneResp;
                end
              end
              RepairValReceiverState_sendDoneResp: begin
                if (flagMbinitRepairVal_SentDoneResp) begin
                  flagMbinitRepairVal_SendDoneResp <= 1'b0;
                  repairValReceiverStateReg <= RepairValReceiverState_finish;
                end
                else begin
                  flagMbinitRepairVal_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairVal_SendInitResp) begin
                sbTxDin <= MBINIT_REPAIRVAL_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendInitResp <= 1'b0;
                flagMbinitRepairVal_SentInitResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendResultResp) begin
                sbTxDin <= msgMbinitRepairValResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, mbinitRepairVal_logValTrainPatternReceived );
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendResultResp <= 1'b0;
                flagMbinitRepairVal_SentResultResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendDoneResp) begin
                sbTxDin <= MBINIT_REPAIRVAL_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendDoneResp <= 1'b0;
                flagMbinitRepairVal_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendInitReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendInitReq <= 1'b0;
                flagMbinitRepairVal_SentInitReq <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendResultReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendResultReq <= 1'b0;
                flagMbinitRepairVal_SentResultReq <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendDoneReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendDoneReq <= 1'b0;
                flagMbinitRepairVal_SentDoneReq <= 1'b1;
              end
            end
            if (repairValReceiverStateReg == RepairValReceiverState_finish && repairValSenderStateReg == RepairValSenderState_finish) begin
              stateReg <= MBInitState_REVERSALMB;
            end
          end
          MBInitState_REVERSALMB: begin
            unique case (reversalMbSenderStateReg)
              ReversalMbSenderState_initReq: begin
                if (flagMbinitReversalMb_SentInitReq) begin
                  flagMbinitReversalMb_SendInitReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitInitResp;
                end
                else begin
                  flagMbinitReversalMb_SendInitReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitInitResp: begin
                if (flagMbinitReversalMb_ReceivedInitResp) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendClearErrorReq;
                end
              end
              ReversalMbSenderState_sendClearErrorReq: begin
                if (flagMbinitReversalMb_SentClearErrorReq) begin
                  flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitClearErrorResp;
                end
                else begin
                  flagMbinitReversalMb_SendClearErrorReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitClearErrorResp: begin
                if (flagMbinitReversalMb_ReceivedClearErrorResp) begin
                  flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendLaneIDPattern;
                end
              end
              ReversalMbSenderState_sendLaneIDPattern: begin
                reversalMbSenderStateReg <= ReversalMbSenderState_waitingLaneIDPatternFinish;
              end
              ReversalMbSenderState_waitingLaneIDPatternFinish: begin
                if (flagFromAnalog_ReversalMbFinishedLaneIDPattern) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendResultReq;
                end
              end
              ReversalMbSenderState_sendResultReq: begin
                if (flagMbinitReversalMb_SentResultReq) begin
                  flagMbinitReversalMb_SendResultReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitResultResp;
                end
                else begin
                  flagMbinitReversalMb_SendResultReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitResultResp: begin
                if (flagMbinitReversalMb_ReceivedResultRespPayload) begin
                  flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
                  flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
                  if (reversalMb_ReceivedSuccessCount > 8) begin
                    reversalMbSenderStateReg <= ReversalMbSenderState_sendDoneReq;
                  end
                  else begin
                    if (reversalMb_LaneReversalApplied) begin
                      trainErrorReg <= 1'b1;
                    end
                    else begin
                      reversalMb_LaneReversalApplied <= 1'b1;
                      reversalMbSenderStateReg <= ReversalMbSenderState_sendClearErrorReq;
                    end
                  end
                end
              end
              ReversalMbSenderState_sendDoneReq: begin
                if (flagMbinitReversalMb_SentDoneReq) begin
                  flagMbinitReversalMb_SendDoneReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitDoneResp;
                end
                else begin
                  flagMbinitReversalMb_SendDoneReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitDoneResp: begin
                if (flagMbinitReversalMb_ReceivedDoneResp) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (reversalMbReceiverStateReg)
              ReversalMbReceiverState_sendInitResp: begin
                if (flagMbinitReversalMb_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitReversalMb_SentInitResp) begin
                    flagMbinitReversalMb_SendInitResp <= 1'b0;
                    reversalMbReceiverStateReg <= ReversalMbReceiverState_waitClearErrorReq;
                  end
                  else begin
                    flagMbinitReversalMb_SendInitResp <= 1'b1;
                  end
                end
              end
              ReversalMbReceiverState_waitClearErrorReq: begin
                if (flagMbinitReversalMb_ReceivedClearErrorReq) begin
                  flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
                  reversalMbLaneStatusLog <= 0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendClearErrorResp;
                end
              end
              ReversalMbReceiverState_sendClearErrorResp: begin
                if (flagMbinitReversalMb_SentClearErrorResp) begin
                  flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitResultReq;
                end
                else begin
                  flagMbinitReversalMb_SendClearErrorResp <= 1'b1;
                end
              end
              ReversalMbReceiverState_waitResultReq: begin
                if (flagMbinitReversalMb_ReceivedResultReq) begin
                  flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
                  reversalMbLaneStatusLog <= {flagFromAnalog_ReversalMbTrainPatternReceived15, flagFromAnalog_ReversalMbTrainPatternReceived14, flagFromAnalog_ReversalMbTrainPatternReceived13, flagFromAnalog_ReversalMbTrainPatternReceived12, flagFromAnalog_ReversalMbTrainPatternReceived11, flagFromAnalog_ReversalMbTrainPatternReceived10, flagFromAnalog_ReversalMbTrainPatternReceived9, flagFromAnalog_ReversalMbTrainPatternReceived8, flagFromAnalog_ReversalMbTrainPatternReceived7, flagFromAnalog_ReversalMbTrainPatternReceived6, flagFromAnalog_ReversalMbTrainPatternReceived5, flagFromAnalog_ReversalMbTrainPatternReceived4, flagFromAnalog_ReversalMbTrainPatternReceived3, flagFromAnalog_ReversalMbTrainPatternReceived2, flagFromAnalog_ReversalMbTrainPatternReceived1, flagFromAnalog_ReversalMbTrainPatternReceived0};
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendResultResp;
                end
              end
              ReversalMbReceiverState_sendResultResp: begin
                if (flagMbinitReversalMb_SentResultResp) begin
                  flagMbinitReversalMb_SendResultResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitDoneReqOrClearErrorReq;
                end
                else begin
                  flagMbinitReversalMb_SendResultResp <= 1'b1;
                end
              end
              ReversalMbReceiverState_waitDoneReqOrClearErrorReq: begin
                if (flagMbinitReversalMb_ReceivedClearErrorReq) begin
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitClearErrorReq;
                end
                else if (flagMbinitReversalMb_ReceivedDoneReq) begin
                  flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendDoneResp;
                end
              end
              ReversalMbReceiverState_sendDoneResp: begin
                if (flagMbinitReversalMb_SentDoneResp) begin
                  flagMbinitReversalMb_SendDoneResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_finish;
                end
                else begin
                  flagMbinitReversalMb_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitReversalMb_SendInitResp) begin
                sbTxDin <= MBINIT_REVERSALMB_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentInitResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendClearErrorResp) begin
                sbTxDin <= MBINIT_REVERSALMB_CLEAR_ERROR_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentClearErrorResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendResultResp) begin
                sbTxDin <= msgMbinitReversalMbResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, reversalMbLaneStatusLog );
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentResultResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendDoneResp) begin
                sbTxDin <= MBINIT_REVERSALMB_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendInitReq) begin
                sbTxDin <= MBINIT_REVERSALMB_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentInitReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendClearErrorReq) begin
                sbTxDin <= MBINIT_REVERSALMB_CLEAR_ERROR_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentClearErrorReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendResultReq) begin
                sbTxDin <= MBINIT_REVERSALMB_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentResultReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendDoneReq) begin
                sbTxDin <= MBINIT_REVERSALMB_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentDoneReq <= 1'b1;
              end
            end
            if (reversalMbReceiverStateReg == ReversalMbReceiverState_finish && reversalMbSenderStateReg == ReversalMbSenderState_finish) begin
              flagMbinitReversalMb_SendInitReq <= 1'b0;
              flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
              flagMbinitReversalMb_SendResultReq <= 1'b0;
              flagMbinitReversalMb_SendDoneReq <= 1'b0;
              flagMbinitReversalMb_SendInitResp <= 1'b0;
              flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
              flagMbinitReversalMb_SendResultResp <= 1'b0;
              flagMbinitReversalMb_SendDoneResp <= 1'b0;
              flagMbinitReversalMb_SentInitReq <= 1'b0;
              flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
              flagMbinitReversalMb_SentResultReq <= 1'b0;
              flagMbinitReversalMb_SentDoneReq <= 1'b0;
              flagMbinitReversalMb_SentInitResp <= 1'b0;
              flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
              flagMbinitReversalMb_SentResultResp <= 1'b0;
              flagMbinitReversalMb_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRMB;
            end
          end
          MBInitState_REPAIRMB: begin
            unique case (repairMbSenderStateReg)
              RepairMbSenderState_sendStartReq: begin
                if (flagMbinitRepairMb_SentStartReq) begin
                  flagMbinitRepairMb_SendStartReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitStartResp;
                end
                else begin
                  flagMbinitRepairMb_SendStartReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitStartResp: begin
                if (flagMbinitRepairMb_ReceivedStartResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestSendReq;
                end
              end
              RepairMbSenderState_d2cPointTestSendReq: begin
                if (flagMbinitRepairMb_SentD2CPointTestReq) begin
                  flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendD2CPointTestReq <= 1'b1;
                end
              end
              RepairMbSenderState_d2cPointTestWaitResp: begin
                if (flagMbinitRepairMb_ReceivedD2CPointTestResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq;
                end
              end
              RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq: begin
                if (flagMbinitRepairMb_SentLfsrClearErrorReq) begin
                  flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b1;
                end
              end
              RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp: begin
                if (flagMbinitRepairMb_ReceivedLfsrClearErrorResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_sendLaneIDPattern;
                end
              end
              RepairMbSenderState_sendLaneIDPattern: begin
                repairMbSenderStateReg <= RepairMbSenderState_waitingLaneIDPatternFinish;
              end
              RepairMbSenderState_waitingLaneIDPatternFinish: begin
                if (flagFromAnalog_RepairMbFinishedLaneIDPattern) begin
                  repairMbSenderStateReg <= RepairMbSenderState_txInitD2CResultsSendReq;
                end
              end
              RepairMbSenderState_txInitD2CResultsSendReq: begin
                if (flagMbinitRepairMb_SentTxInitD2CResultsReq) begin
                  flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_txInitD2CResultsWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b1;
                end
              end
              RepairMbSenderState_txInitD2CResultsWaitResp: begin
                if (flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload) begin
                  repairMbSenderStateReg <= RepairMbSenderState_endTxInitD2CPointTestSendReq;
                end
              end
              RepairMbSenderState_endTxInitD2CPointTestSendReq: begin
                if (flagMbinitRepairMb_SentEndTxInitD2CPointTestReq) begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_endTxInitD2CPointTestWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b1;
                end
              end
              RepairMbSenderState_endTxInitD2CPointTestWaitResp: begin
                if (flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_analyzeWidthDegradation;
                end
              end
              RepairMbSenderState_analyzeWidthDegradation: begin
                if (mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits == 16'hFFFF) begin
                  flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_sendApplyDegradeReq;
                end
                else begin
                  flagMbinitRepairMb_ApplyWidthDegradation <= 1'b1;
                  repairMbSenderStateReg <= RepairMbSenderState_sendApplyDegradeReq;
                end
              end
              RepairMbSenderState_sendApplyDegradeReq: begin
                if (flagMbinitRepairMb_SentApplyDegradeReq) begin
                  flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitApplyDegradeResp;
                end
                else begin
                  flagMbinitRepairMb_SendApplyDegradeReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitApplyDegradeResp: begin
                if (flagMbinitRepairMb_ReceivedApplyDegradeResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_sendEndReq;
                end
              end
              RepairMbSenderState_sendEndReq: begin
                if (flagMbinitRepairMb_SentEndReq) begin
                  flagMbinitRepairMb_SendEndReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitEndResp;
                end
                else begin
                  flagMbinitRepairMb_SendEndReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitEndResp: begin
                if (flagMbinitRepairMb_ReceivedEndResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_finish;
                end
              end
              RepairMbSenderState_finish: begin
                repairMbSenderStateReg <= RepairMbSenderState_finish;
              end
              default: ;
            endcase
            unique case (repairMbReceiverStateReg)
              RepairMbReceiverState_waitStartReq: begin
                if (flagMbinitRepairMb_ReceivedStartReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendStartResp;
                end
              end
              RepairMbReceiverState_sendStartResp: begin
                if (flagMbinitRepairMb_SentStartResp) begin
                  flagMbinitRepairMb_SendStartResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitD2CPointTestReq;
                end
                else begin
                  flagMbinitRepairMb_SendStartResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitD2CPointTestReq: begin
                if (flagMbinitRepairMb_ReceivedD2CPointTestReqHeader && flagMbinitRepairMb_ReceivedD2CPointTestReqPayload) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_setReceiver;
                end
              end
              RepairMbReceiverState_setReceiver: begin
                repairMbReceiverStateReg <= RepairMbReceiverState_sendD2CPointTestResp;
              end
              RepairMbReceiverState_sendD2CPointTestResp: begin
                if (flagMbinitRepairMb_SentD2CPointTestResp) begin
                  flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitLfsrClearErrorReq;
                end
                else begin
                  flagMbinitRepairMb_SendD2CPointTestResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitLfsrClearErrorReq: begin
                if (flagMbinitRepairMb_ReceivedLfsrClearErrorReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendLfsrClearErrorResp;
                end
              end
              RepairMbReceiverState_sendLfsrClearErrorResp: begin
                if (flagMbinitRepairMb_SentLfsrClearErrorResp) begin
                  flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitTxInitD2CResultsReq;
                end
                else begin
                  flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitTxInitD2CResultsReq: begin
                if (flagMbinitRepairMb_ReceivedTxInitD2CResultsReq) begin
                  repairMb_DetectedLaneIDPatternLog <= {flagFromAnalog_RepairMbDetectedLaneIDPattern15, flagFromAnalog_RepairMbDetectedLaneIDPattern14, flagFromAnalog_RepairMbDetectedLaneIDPattern13, flagFromAnalog_RepairMbDetectedLaneIDPattern12, flagFromAnalog_RepairMbDetectedLaneIDPattern11, flagFromAnalog_RepairMbDetectedLaneIDPattern10, flagFromAnalog_RepairMbDetectedLaneIDPattern9, flagFromAnalog_RepairMbDetectedLaneIDPattern8, flagFromAnalog_RepairMbDetectedLaneIDPattern7, flagFromAnalog_RepairMbDetectedLaneIDPattern6, flagFromAnalog_RepairMbDetectedLaneIDPattern5, flagFromAnalog_RepairMbDetectedLaneIDPattern4, flagFromAnalog_RepairMbDetectedLaneIDPattern3, flagFromAnalog_RepairMbDetectedLaneIDPattern2, flagFromAnalog_RepairMbDetectedLaneIDPattern1, flagFromAnalog_RepairMbDetectedLaneIDPattern0};
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendTxInitD2CResultsResp;
                end
              end
              RepairMbReceiverState_sendTxInitD2CResultsResp: begin
                if (flagMbinitRepairMb_SentTxInitD2CResultsResp) begin
                  flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitEndTxInitD2CPointTestReq;
                end
                else begin
                  flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitEndTxInitD2CPointTestReq: begin
                if (flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendEndTxInitD2CPointTestResp;
                end
              end
              RepairMbReceiverState_sendEndTxInitD2CPointTestResp: begin
                if (flagMbinitRepairMb_SentEndTxInitD2CPointTestResp) begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitApplyDegradeReq;
                end
                else begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitApplyDegradeReq: begin
                if (flagMbinitRepairMb_ReceivedApplyDegradeReq) begin
                  if (mbinitRepairMb_ReceivedApplyDegradeReqLaneMap == 3'b011) begin
                    repairMbReceiverStateReg <= RepairMbReceiverState_sendApplyDegradeResp;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairMbReceiverState_sendApplyDegradeResp: begin
                if (flagMbinitRepairMb_SentApplyDegradeResp) begin
                  flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitEndReq;
                end
                else begin
                  flagMbinitRepairMb_SendApplyDegradeResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitEndReq: begin
                if (flagMbinitRepairMb_ReceivedEndReq) begin
                  flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendEndResp;
                end
              end
              RepairMbReceiverState_sendEndResp: begin
                if (flagMbinitRepairMb_SentEndResp) begin
                  flagMbinitRepairMb_SendEndResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_finish;
                end
                else begin
                  flagMbinitRepairMb_SendEndResp <= 1'b1;
                end
              end
              RepairMbReceiverState_finish: begin
                repairMbReceiverStateReg <= RepairMbReceiverState_finish;
              end
              default: ;
            endcase
            if (repairMbReceiverStateReg == RepairMbReceiverState_finish && repairMbSenderStateReg == RepairMbSenderState_finish) begin
              flagMbinitRepairMb_SendStartReq <= 1'b0;
              flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
              flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
              flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
              flagMbinitRepairMb_SendEndReq <= 1'b0;
              flagMbinitRepairMb_SendStartResp <= 1'b0;
              flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
              flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
              flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
              flagMbinitRepairMb_SendEndResp <= 1'b0;
              flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
              flagMbinitRepairMb_SentStartReq <= 1'b0;
              flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
              flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
              flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
              flagMbinitRepairMb_SentEndReq <= 1'b0;
              flagMbinitRepairMb_SentStartResp <= 1'b0;
              flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
              flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
              flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
              flagMbinitRepairMb_SentEndResp <= 1'b0;
              stateReg <= MBInitState_DONE;
            end
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairMb_SendStartResp) begin
                sbTxDin <= MBINIT_REPAIRMB_START_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentStartResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendD2CPointTestResp) begin
                sbTxDin <= MBINIT_REPAIRMB_D2C_POINT_TEST_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentD2CPointTestResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendLfsrClearErrorResp) begin
                sbTxDin <= MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendTxInitD2CResultsResp) begin
                sbTxDin <= msgMbinitRepairMbTxInitD2CResultsResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, {48'd0, repairMb_DetectedLaneIDPatternLog} );
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndTxInitD2CPointTestResp) begin
                sbTxDin <= MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendApplyDegradeResp) begin
                sbTxDin <= MBINIT_REPAIRMB_APPLY_DEGRADE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentApplyDegradeResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndResp) begin
                sbTxDin <= MBINIT_REPAIRMB_END_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendStartReq) begin
                sbTxDin <= MBINIT_REPAIRMB_START_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentStartReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendD2CPointTestReq) begin
                sbTxDin <= MBINIT_REPAIRMB_D2C_POINT_TEST_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentD2CPointTestReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendLfsrClearErrorReq) begin
                sbTxDin <= MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendTxInitD2CResultsReq) begin
                sbTxDin <= MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndTxInitD2CPointTestReq) begin
                sbTxDin <= MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendApplyDegradeReq) begin
                sbTxDin <= (flagMbinitRepairMb_ApplyWidthDegradation ? msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b000) : msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b011));
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentApplyDegradeReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndReq) begin
                sbTxDin <= MBINIT_REPAIRMB_END_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndReq <= 1'b1;
              end
            end
          end
          MBInitState_DONE: begin
            stateReg <= MBInitState_DONE;
          end
          default: ;
        endcase
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_DataTrainCenter1-sv"></a>

## [11] MBTrain_DataTrainCenter1.sv

```systemverilog
// FILE_INDEX: 11
// FILE_PATH : MBTrain_DataTrainCenter1.sv

// SystemVerilog translation of MBTrain_DataTrainCenter1.scala.
`default_nettype none

module MBTrain_DataTrainCenter1 #(
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
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic         flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic         flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic         flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic         flagToAnalog_d2cSender_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic         flagFromAnalog_d2cSender_txLaneDeskewApplied,
  output var logic         flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]  flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic         flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]  flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic         flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]   flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]   flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]   flagToAnalog_d2cReceiver_dataPattern,
  output var logic         flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic [11:0]  substate,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    DataTrainCenter1SenderState_idle = 4'h0,
    DataTrainCenter1SenderState_sendStartReq = 4'h1,
    DataTrainCenter1SenderState_waitStartResp = 4'h2,
    DataTrainCenter1SenderState_startPointTest = 4'h3,
    DataTrainCenter1SenderState_waitPointTest = 4'h4,
    DataTrainCenter1SenderState_checkErrorLog = 4'h5,
    DataTrainCenter1SenderState_sendDoneReq = 4'h6,
    DataTrainCenter1SenderState_waitDoneResp = 4'h7,
    DataTrainCenter1SenderState_finish = 4'h8
  } DataTrainCenter1SenderState_t;

  typedef enum logic [2:0] {
    DataTrainCenter1ReceiverState_idle = 3'h0,
    DataTrainCenter1ReceiverState_waitStartReq = 3'h1,
    DataTrainCenter1ReceiverState_sendStartResp = 3'h2,
    DataTrainCenter1ReceiverState_runPointTest = 3'h3,
    DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    DataTrainCenter1ReceiverState_sendDoneResp = 3'h5,
    DataTrainCenter1ReceiverState_finish = 3'h6
  } DataTrainCenter1ReceiverState_t;

  (* keep = "true" *) DataTrainCenter1SenderState_t senderStateReg;
  (* keep = "true" *) DataTrainCenter1ReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedStartResp;
  (* keep = "true" *) logic flagReceivedDoneResp;
  (* keep = "true" *) logic flagReceivedStartReq;
  (* keep = "true" *) logic flagReceivedDoneReq;

  (* keep = "true" *) logic d2cSender_receivedPointTestStartResp;
  (* keep = "true" *) logic d2cSender_receivedLfsrClearResp;
  (* keep = "true" *) logic d2cSender_receivedResultsResp;
  (* keep = "true" *) logic d2cSender_receivedEndPointTestResp;

  (* keep = "true" *) logic d2cReceiver_receivedPointTestStartReq;
  (* keep = "true" *) logic d2cReceiver_receivedLfsrClearReq;
  (* keep = "true" *) logic d2cReceiver_receivedResultsReq;
  (* keep = "true" *) logic d2cReceiver_receivedEndPointTestReq;

  (* keep = "true" *) logic flagSentStartReq;
  (* keep = "true" *) logic flagSentDoneReq;
  (* keep = "true" *) logic flagSentStartResp;
  (* keep = "true" *) logic flagSentDoneResp;

  (* keep = "true" *) logic d2cSender_sentPointTestStartReq;
  (* keep = "true" *) logic d2cSender_sentLfsrClearReq;
  (* keep = "true" *) logic d2cSender_sentResultsReq;
  (* keep = "true" *) logic d2cSender_sentEndPointTestReq;

  (* keep = "true" *) logic d2cReceiver_sentPointTestStartResp;
  (* keep = "true" *) logic d2cReceiver_sentLfsrClearResp;
  (* keep = "true" *) logic d2cReceiver_sentResultsResp;
  (* keep = "true" *) logic d2cReceiver_sentEndPointTestResp;

  (* keep = "true" *) logic [15:0] logErrorCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [15:0] d2cReceiver_loggedResultsMsgInfo;
  (* keep = "true" *) logic [63:0] d2cReceiver_loggedResultsPayload;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;

  // The tested linear sweep engine controls the local forwarded-clock PI and
  // local TX lane deskew.  The existing point-test sender/receiver FSMs and
  // sideband message generation remain in this wrapper.
  logic sweepEngine_start;
  logic sweepEngine_busy;
  logic sweepEngine_done;
  logic sweepEngine_trainError;
  logic sweepEngine_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_txClockPhaseCode;
  logic sweepEngine_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] sweepEngine_txLaneDeskewCodes;
  logic sweepEngine_pointTestStart;
  logic [4:0] sweepEngine_state;
  logic [15:0] sweepEngine_lastFailedComparisons;
  logic [15:0] sweepEngine_retryCount;
  logic [d2cPiCodeWidth-1:0] sweepEngine_finalClockPhase;

  logic [63:0] d2cSender_resultsLanePassReg;
  logic d2cSender_resultsValidPassReg;
  logic d2cSender_resultsCumulativePassReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  logic d2cSender_start;
  logic d2cReceiver_start;
  logic senderSentStartPulse;
  logic senderSentLfsrPulse;
  logic senderSentResultsPulse;
  logic senderSentEndPulse;
  logic flagToAnalog_d2cReceiver_configureAnalogPulse;

  logic selectSentDoneResp;
  logic selectReceiverEndResp;
  logic selectReceiverResultsResp;
  logic selectReceiverLfsrResp;
  logic selectReceiverStartResp;
  logic selectSentStartResp;
  logic selectSentDoneReq;
  logic selectSenderEndReq;
  logic selectSenderResultsReq;
  logic selectSenderLfsrReq;
  logic selectSenderStartReq;
  logic selectSentStartReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_DATATRAINCENTER1_START_REQ =
    msgMbtrainDataTrainCenter1StartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_START_RESP =
    msgMbtrainDataTrainCenter1StartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_DONE_REQ =
    msgMbtrainDataTrainCenter1EndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_DONE_RESP =
    msgMbtrainDataTrainCenter1EndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      d2cMaximumComparisonErrorThreshold,
      1'b1, 16'd1, 16'd0, 16'd4096,
      1'b0, 4'd0, 3'd0, 3'd0
    );
  wire [127:0] START_POINT_TEST_RESP =
    msgMbtrainStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_REQ =
    msgMbtrainTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_RESP_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);
  wire [127:0] END_POINT_TEST_REQ =
    msgMbtrainEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_TEST_RESP =
    msgMbtrainEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire isStartPointTestReq =
    ((sb_rx_dout[63:0] & 64'h000000FFFFFFFFFF) ==
     (START_POINT_TEST_REQ[63:0] & 64'h000000FFFFFFFFFF));

  // A results response contains variable MsgInfo, payload, and parity bits.
  // Compare only the fixed header fields (including endpoint IDs, code,
  // subcode, and opcode), otherwise a valid pass/fail response is missed.
  wire isTxInitResultsResp =
    (sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
    (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]);

  logic d2cSender_sendStartTxInitD2CPointTestReq;
  logic d2cSender_sendLfsrClearErrorReq;
  logic d2cSender_sendTxInitD2CResultsReq;
  logic d2cSender_sendEndTxInitD2CPointTestReq;
  logic d2cSender_sendDefinedPattern;
  logic d2cSender_resetLocalScrambler;
  logic d2cSender_busy;
  logic d2cSender_done;
  logic [3:0] d2cSender_state;

  logic d2cReceiver_sendStartTxInitD2CPointTestResp;
  logic d2cReceiver_sendLfsrClearErrorResp;
  logic d2cReceiver_sendTxInitD2CResultsResp;
  logic d2cReceiver_sendEndTxInitD2CPointTestResp;
  logic d2cReceiver_resetLocalRxScrambler;
  logic d2cReceiver_busy;
  logic d2cReceiver_done;
  logic [3:0] d2cReceiver_state;

  TxInitD2CPointTestSenderFSM d2cSender (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cSender_start),
    .receivedStartTxInitD2CPointTestResp(d2cSender_receivedPointTestStartResp),
    .receivedLfsrClearErrorResp(d2cSender_receivedLfsrClearResp),
    .receivedTxInitD2CResultsResp(d2cSender_receivedResultsResp),
    .receivedEndTxInitD2CPointTestResp(d2cSender_receivedEndPointTestResp),
    .sentStartTxInitD2CPointTestReq(senderSentStartPulse),
    .sentLfsrClearErrorReq(senderSentLfsrPulse),
    .sentTxInitD2CResultsReq(senderSentResultsPulse),
    .sentEndTxInitD2CPointTestReq(senderSentEndPulse),
    .sentDefinedPattern(flagFromAnalog_d2cSender_lfsrPatternSent),
    .sendStartTxInitD2CPointTestReq(d2cSender_sendStartTxInitD2CPointTestReq),
    .sendLfsrClearErrorReq(d2cSender_sendLfsrClearErrorReq),
    .sendTxInitD2CResultsReq(d2cSender_sendTxInitD2CResultsReq),
    .sendEndTxInitD2CPointTestReq(d2cSender_sendEndTxInitD2CPointTestReq),
    .sendDefinedPattern(d2cSender_sendDefinedPattern),
    .resetLocalScrambler(d2cSender_resetLocalScrambler),
    .busy(d2cSender_busy),
    .done(d2cSender_done),
    .state(d2cSender_state)
  );

  TxInitD2CPointTestReceiverFSM d2cReceiver (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cReceiver_start),
    .receivedStartTxInitD2CPointTestReq(d2cReceiver_receivedPointTestStartReq),
    .receivedLfsrClearErrorReq(d2cReceiver_receivedLfsrClearReq),
    .receivedTxInitD2CResultsReq(d2cReceiver_receivedResultsReq),
    .receivedEndTxInitD2CPointTestReq(d2cReceiver_receivedEndPointTestReq),
    .sentStartTxInitD2CPointTestResp(d2cReceiver_sentPointTestStartResp),
    .sentLfsrClearErrorResp(d2cReceiver_sentLfsrClearResp),
    .sentTxInitD2CResultsResp(d2cReceiver_sentResultsResp),
    .sentEndTxInitD2CPointTestResp(d2cReceiver_sentEndPointTestResp),
    .sendStartTxInitD2CPointTestResp(d2cReceiver_sendStartTxInitD2CPointTestResp),
    .sendLfsrClearErrorResp(d2cReceiver_sendLfsrClearErrorResp),
    .sendTxInitD2CResultsResp(d2cReceiver_sendTxInitD2CResultsResp),
    .sendEndTxInitD2CPointTestResp(d2cReceiver_sendEndTxInitD2CPointTestResp),
    .resetLocalRxScrambler(d2cReceiver_resetLocalRxScrambler),
    .busy(d2cReceiver_busy),
    .done(d2cReceiver_done),
    .state(d2cReceiver_state)
  );

  MBTrain_DataTrainCenter1SweepEngine #(
    .ucieA(ucieA),
    .PI_CODE_WIDTH(d2cPiCodeWidth),
    .TX_DESKEW_CODE_WIDTH(d2cTxDeskewCodeWidth),
    .DESKEW_STEPS_PER_PI(d2cDeskewStepsPerPi),
    .DESKEW_ADD_DELAY_INCREASES_PHASE(d2cDeskewAddDelayIncreasesPhase),
    .MIN_LANE_WINDOW_STEPS(d2cMinLaneWindowSteps),
    .MIN_COMMON_WINDOW_STEPS(d2cMinCommonWindowSteps),
    .MAX_TRAINING_RETRIES(d2cMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepEngine_start),
    .busy(sweepEngine_busy),
    .done(sweepEngine_done),
    .trainError(sweepEngine_trainError),
    .apply_tx_clock_phase(sweepEngine_applyTxClockPhase),
    .tx_clock_phase_code(sweepEngine_txClockPhaseCode),
    .tx_clock_phase_applied(flagFromAnalog_d2cSender_txClockPhaseApplied),
    .apply_tx_lane_deskew(sweepEngine_applyTxLaneDeskew),
    .tx_lane_deskew_codes(sweepEngine_txLaneDeskewCodes),
    .tx_lane_deskew_applied(flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .point_test_start(sweepEngine_pointTestStart),
    .point_test_done(d2cSender_done),
    .point_test_lane_pass(d2cSender_resultsLanePassReg),
    .point_test_valid_pass(d2cSender_resultsValidPassReg),
    .point_test_cumulative_pass(d2cSender_resultsCumulativePassReg),
    .state(sweepEngine_state),
    .lastFailedComparisons(sweepEngine_lastFailedComparisons),
    .retryCount(sweepEngine_retryCount),
    .finalClockPhase(sweepEngine_finalClockPhase)
  );

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg || sweepEngine_trainError;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    substate = {senderStateReg[3:0], d2cSender_state, d2cReceiver_state};
    lastErrorCount = sweepEngine_lastFailedComparisons;
    retryCount = sweepEngine_retryCount;

    flagToAnalog_d2cSender_sendLfsrPattern = running && d2cSender_sendDefinedPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
    flagToAnalog_d2cSender_applyTxClockPhase = running && sweepEngine_applyTxClockPhase;
    flagToAnalog_d2cSender_txClockPhaseCode = sweepEngine_txClockPhaseCode;
    flagToAnalog_d2cSender_applyTxLaneDeskew = running && sweepEngine_applyTxLaneDeskew;
    flagToAnalog_d2cSender_txLaneDeskewCodes = sweepEngine_txLaneDeskewCodes;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = flagToAnalog_d2cReceiver_configureAnalogPulse;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = d2c_maximumComparisonErrorThresholdReg;
    flagToAnalog_d2cReceiver_comparisonMode = d2c_comparisonModeReg;
    flagToAnalog_d2cReceiver_iterationCountSettings = d2c_iterationCountSettingsReg;
    flagToAnalog_d2cReceiver_idleCountSettings = d2c_idleCountSettingsReg;
    flagToAnalog_d2cReceiver_burstCountSettings = d2c_burstCountSettingsReg;
    flagToAnalog_d2cReceiver_patternMode = d2c_patternModeReg;
    flagToAnalog_d2cReceiver_clockPhaseControl = d2c_clockPhaseControlReg;
    flagToAnalog_d2cReceiver_validPattern = d2c_validPatternReg;
    flagToAnalog_d2cReceiver_dataPattern = d2c_dataPatternReg;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = running && d2cReceiver_resetLocalRxScrambler;
  end

  // Combinational local pulses and the source's pulse-style registered TX selector.
  always_comb begin
    sweepEngine_start = running && !startPulse &&
                        (senderStateReg == DataTrainCenter1SenderState_startPointTest);
    d2cSender_start = running && !startPulse &&
                      (senderStateReg == DataTrainCenter1SenderState_waitPointTest) &&
                      sweepEngine_pointTestStart;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    flagToAnalog_d2cReceiver_configureAnalogPulse = running && rxValidRisingEdge && isStartPointTestReq;

    nextSbTxValid = 1'b0;
    nextSbTxDin = 128'b0;
    selectSentDoneResp = 1'b0;
    selectReceiverEndResp = 1'b0;
    selectReceiverResultsResp = 1'b0;
    selectReceiverLfsrResp = 1'b0;
    selectReceiverStartResp = 1'b0;
    selectSentStartResp = 1'b0;
    selectSentDoneReq = 1'b0;
    selectSenderEndReq = 1'b0;
    selectSenderResultsReq = 1'b0;
    selectSenderLfsrReq = 1'b0;
    selectSenderStartReq = 1'b0;
    selectSentStartReq = 1'b0;

    if (!startPulse) begin
      unique case (receiverStateReg)
        DataTrainCenter1ReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == DataTrainCenter1ReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_DONE_RESP;
        nextSbTxValid = 1'b1;
        selectSentDoneResp = 1'b1;
      end
      else if (d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverEndResp = 1'b1;
      end
      else if (d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          d2cReceiver_loggedResultsMsgInfo,
          d2cReceiver_loggedResultsPayload
        );
        nextSbTxValid = 1'b1;
        selectReceiverResultsResp = 1'b1;
      end
      else if (d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverLfsrResp = 1'b1;
      end
      else if (d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverStartResp = 1'b1;
      end
      else if ((receiverStateReg == DataTrainCenter1ReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end

      else if ((senderStateReg == DataTrainCenter1SenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= DataTrainCenter1SenderState_idle;
      receiverStateReg <= DataTrainCenter1ReceiverState_idle;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedStartResp <= 1'b0;
      flagReceivedDoneResp <= 1'b0;
      flagReceivedStartReq <= 1'b0;
      flagReceivedDoneReq <= 1'b0;
      d2cSender_receivedPointTestStartResp <= 1'b0;
      d2cSender_receivedLfsrClearResp <= 1'b0;
      d2cSender_receivedResultsResp <= 1'b0;
      d2cSender_receivedEndPointTestResp <= 1'b0;
      d2cReceiver_receivedPointTestStartReq <= 1'b0;
      d2cReceiver_receivedLfsrClearReq <= 1'b0;
      d2cReceiver_receivedResultsReq <= 1'b0;
      d2cReceiver_receivedEndPointTestReq <= 1'b0;
      flagSentStartReq <= 1'b0;
      flagSentDoneReq <= 1'b0;
      flagSentStartResp <= 1'b0;
      flagSentDoneResp <= 1'b0;
      d2cSender_sentPointTestStartReq <= 1'b0;
      d2cSender_sentLfsrClearReq <= 1'b0;
      d2cSender_sentResultsReq <= 1'b0;
      d2cSender_sentEndPointTestReq <= 1'b0;
      d2cReceiver_sentPointTestStartResp <= 1'b0;
      d2cReceiver_sentLfsrClearResp <= 1'b0;
      d2cReceiver_sentResultsResp <= 1'b0;
      d2cReceiver_sentEndPointTestResp <= 1'b0;
      logErrorCountReg <= 16'b0;
      retryCountReg <= 16'b0;
      d2cReceiver_loggedResultsMsgInfo <= 16'b0;
      d2cReceiver_loggedResultsPayload <= 64'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;
      d2cSender_resultsLanePassReg <= 64'b0;
      d2cSender_resultsValidPassReg <= 1'b0;
      d2cSender_resultsCumulativePassReg <= 1'b0;

      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        senderStateReg <= DataTrainCenter1SenderState_sendStartReq;
        receiverStateReg <= DataTrainCenter1ReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cReceiver_receivedPointTestStartReq <= 1'b0;
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        flagSentStartReq <= 1'b0;
        flagSentDoneReq <= 1'b0;
        flagSentStartResp <= 1'b0;
        flagSentDoneResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
        logErrorCountReg <= 16'b0;
        retryCountReg <= 16'b0;
        d2cReceiver_loggedResultsMsgInfo <= 16'b0;
        d2cReceiver_loggedResultsPayload <= 64'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
        else if (isStartPointTestReq) begin
          d2c_maximumComparisonErrorThresholdReg <= sb_rx_dout[55:40];
          d2c_comparisonModeReg <= sb_rx_dout[123];
          d2c_iterationCountSettingsReg <= sb_rx_dout[122:107];
          d2c_idleCountSettingsReg <= sb_rx_dout[106:91];
          d2c_burstCountSettingsReg <= sb_rx_dout[90:75];
          d2c_patternModeReg <= sb_rx_dout[74];
          d2c_clockPhaseControlReg <= sb_rx_dout[73:70];
          d2c_validPatternReg <= sb_rx_dout[69:67];
          d2c_dataPatternReg <= sb_rx_dout[66:64];
          d2cReceiver_receivedPointTestStartReq <= 1'b1;
        end
        else if (sb_rx_dout == START_POINT_TEST_RESP)
          d2cSender_receivedPointTestStartResp <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_REQ)
          d2cReceiver_receivedLfsrClearReq <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_RESP)
          d2cSender_receivedLfsrClearResp <= 1'b1;
        else if (sb_rx_dout == TX_INIT_RESULTS_REQ) begin
        d2cReceiver_loggedResultsMsgInfo <= flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
        d2cReceiver_loggedResultsPayload <= flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
        d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (isTxInitResultsResp) begin
          d2cSender_receivedResultsResp <= 1'b1;
          d2cSender_resultsLanePassReg <= sb_rx_dout[127:64];
          d2cSender_resultsValidPassReg <= sb_rx_dout[45];
          d2cSender_resultsCumulativePassReg <= sb_rx_dout[44];
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (d2cSender_start) begin
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        logErrorCountReg <= 16'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      // Clear the received Start request only when this wrapper schedules the
      // matching Start response.  d2cReceiver_sentPointTestStartResp is sticky
      // for the rest of the point test; using it here would erase the next
      // phase's newly received Start request before the receiver FSM can restart.
      if (selectReceiverStartResp)
        d2cReceiver_receivedPointTestStartReq <= 1'b0;

      if (d2cReceiver_start) begin
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
      end

      if (selectSentDoneResp)
        flagSentDoneResp <= 1'b1;
      if (selectReceiverEndResp)
        d2cReceiver_sentEndPointTestResp <= 1'b1;
      if (selectReceiverResultsResp)
        d2cReceiver_sentResultsResp <= 1'b1;
      if (selectReceiverLfsrResp)
        d2cReceiver_sentLfsrClearResp <= 1'b1;
      if (selectReceiverStartResp)
        d2cReceiver_sentPointTestStartResp <= 1'b1;
      if (selectSentStartResp)
        flagSentStartResp <= 1'b1;
      if (selectSentDoneReq)
        flagSentDoneReq <= 1'b1;
      if (selectSenderEndReq)
        d2cSender_sentEndPointTestReq <= 1'b1;
      if (selectSenderResultsReq)
        d2cSender_sentResultsReq <= 1'b1;
      if (selectSenderLfsrReq)
        d2cSender_sentLfsrClearReq <= 1'b1;
      if (selectSenderStartReq)
        d2cSender_sentPointTestStartReq <= 1'b1;
      if (selectSentStartReq)
        flagSentStartReq <= 1'b1;

      if (!startPulse) begin
        unique case (senderStateReg)
          DataTrainCenter1SenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= DataTrainCenter1SenderState_waitStartResp;
          end
          DataTrainCenter1SenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= DataTrainCenter1SenderState_startPointTest;
          end
          DataTrainCenter1SenderState_startPointTest:
            senderStateReg <= DataTrainCenter1SenderState_waitPointTest;
          DataTrainCenter1SenderState_waitPointTest: begin
            if (sweepEngine_trainError) begin
              trainErrorReg <= 1'b1;
              running <= 1'b0;
              senderStateReg <= DataTrainCenter1SenderState_idle;
              receiverStateReg <= DataTrainCenter1ReceiverState_idle;
            end else if (sweepEngine_done) begin
              senderStateReg <= DataTrainCenter1SenderState_sendDoneReq;
            end
          end
          DataTrainCenter1SenderState_checkErrorLog: begin
            // Retained for state-number compatibility with the original RTL.
            // Retries and error checking now occur inside sweepEngine.
            senderStateReg <= DataTrainCenter1SenderState_waitPointTest;
          end
          DataTrainCenter1SenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= DataTrainCenter1SenderState_waitDoneResp;
          end
          DataTrainCenter1SenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= DataTrainCenter1SenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          DataTrainCenter1ReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_sendStartResp;
          end
          DataTrainCenter1ReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= DataTrainCenter1ReceiverState_runPointTest;
          end
          DataTrainCenter1ReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq;
          end
          DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq: begin
            if (flagReceivedDoneReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_runPointTest;
          end
          DataTrainCenter1ReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= DataTrainCenter1ReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == DataTrainCenter1SenderState_finish) &&
            (receiverStateReg == DataTrainCenter1ReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_DataTrainCenter1SweepEngine-sv"></a>

## [12] MBTrain_DataTrainCenter1SweepEngine.sv

```systemverilog
// FILE_INDEX: 12
// FILE_PATH : MBTrain_DataTrainCenter1SweepEngine.sv

// DATATRAINCENTER1 local transmitter linear sweep/deskew controller.
//
// The sideband protocol is intentionally kept outside this module.  A caller
// starts one UCIe Tx-initiated D2C point test for every asserted
// point_test_start and returns the partner's comparison bitmap through the
// point_test_* inputs when point_test_done is asserted.
//
// Lane deskew convention:
//   lane 0 code is tx_lane_deskew_codes[TX_DESKEW_CODE_WIDTH-1:0]
//   lane N code is tx_lane_deskew_codes[N*TX_DESKEW_CODE_WIDTH +:
//                                      TX_DESKEW_CODE_WIDTH]
// Codes are absolute values.  Inactive UCIe-S lanes [63:16] are held at zero.
//
// PI phase convention:
//   0, 1, ... PHASE_COUNT-1 is one linear ordered search range.
//   Phase 0 and phase PHASE_COUNT-1 are not adjacent and are never merged.
`default_nettype none

module MBTrain_DataTrainCenter1SweepEngine #(
  parameter bit          ucieA                         = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter int unsigned PI_CODE_WIDTH                 = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned TX_DESKEW_CODE_WIDTH          = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned DESKEW_STEPS_PER_PI            = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI,
  parameter bit          DESKEW_ADD_DELAY_INCREASES_PHASE = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE,
  parameter int unsigned MIN_LANE_WINDOW_STEPS          = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS        = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned MAX_TRAINING_RETRIES           = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output var  logic busy,
  output var  logic done,
  output var  logic trainError,

  // Local forwarded-clock PI interface.  apply_tx_clock_phase remains asserted
  // with a stable code until tx_clock_phase_applied is observed.
  output var  logic                     apply_tx_clock_phase,
  output var  logic [PI_CODE_WIDTH-1:0] tx_clock_phase_code,
  input  wire logic                     tx_clock_phase_applied,

  // Local per-data-lane TX deskew interface.  apply_tx_lane_deskew remains
  // asserted with stable absolute codes until tx_lane_deskew_applied is seen.
  output var  logic                                      apply_tx_lane_deskew,
  output var  logic [64*TX_DESKEW_CODE_WIDTH-1:0]        tx_lane_deskew_codes,
  input  wire logic                                      tx_lane_deskew_applied,

  // One-cycle request to run a complete Tx-initiated D2C point test at the
  // currently applied local clock phase.
  output var  logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [63:0] point_test_lane_pass,
  input  wire logic        point_test_valid_pass,
  input  wire logic        point_test_cumulative_pass,

  output var  logic [4:0]  state,
  output var  logic [15:0] lastFailedComparisons,
  output var  logic [15:0] retryCount,
  output var  logic [PI_CODE_WIDTH-1:0] finalClockPhase
);
  localparam int unsigned MAX_DATA_LANES   = 64;
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
  localparam int unsigned MAX_DESKEW_CODE_INT =
    (1 << TX_DESKEW_CODE_WIDTH) - 1;

  localparam logic [63:0] ACTIVE_LANE_MASK =
    ucieA ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;

  typedef enum logic [4:0] {
    SweepState_IDLE                  = 5'd0,
    SweepState_APPLY_ZERO_DESKEW     = 5'd1,
    SweepState_APPLY_INITIAL_PHASE   = 5'd2,
    SweepState_START_INITIAL_TEST    = 5'd3,
    SweepState_WAIT_INITIAL_TEST     = 5'd4,
    SweepState_STORE_INITIAL_RESULT  = 5'd5,
    SweepState_CALCULATE_DESKEW      = 5'd6,
    SweepState_APPLY_DESKEW          = 5'd7,
    SweepState_CLEAR_VERIFY_RESULTS  = 5'd8,
    SweepState_APPLY_VERIFY_PHASE    = 5'd9,
    SweepState_START_VERIFY_TEST     = 5'd10,
    SweepState_WAIT_VERIFY_TEST      = 5'd11,
    SweepState_STORE_VERIFY_RESULT   = 5'd12,
    SweepState_CALCULATE_GLOBAL      = 5'd13,
    SweepState_APPLY_GLOBAL_PHASE    = 5'd14,
    SweepState_START_FINAL_TEST      = 5'd15,
    SweepState_WAIT_FINAL_TEST       = 5'd16,
    SweepState_CHECK_FINAL_TEST      = 5'd17,
    SweepState_DONE                  = 5'd18,
    SweepState_ERROR                 = 5'd19
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic errorReg;
  (* keep = "true" *) logic [15:0] lastFailedComparisonsReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] phaseIndexReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] finalClockPhaseReg;
  (* keep = "true" *) logic [64*TX_DESKEW_CODE_WIDTH-1:0] deskewCodesReg;

  // Pass bitmap captured at every PI code before TX deskew.
  logic [63:0] initialPassByPhase [0:PHASE_COUNT-1];

  // Aggregate pass/fail captured at every PI code after TX deskew.
  logic verifyPassByPhase [0:PHASE_COUNT-1];

  // Registered results are useful for waveform/debug inspection.
  logic [PI_CODE_WIDTH-1:0] laneLeftPhaseReg   [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneRightPhaseReg  [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneCenterPhaseReg [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseReg;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseReg;

  logic [PI_CODE_WIDTH-1:0] laneLeftPhaseCalc   [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneRightPhaseCalc  [0:MAX_DATA_LANES-1];
  logic [PI_CODE_WIDTH-1:0] laneCenterPhaseCalc [0:MAX_DATA_LANES-1];
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] deskewCodesCalc;
  logic initialWindowsValidCalc;

  logic globalWindowValidCalc;
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalCenterPhaseCalc;

  wire allActiveDataLanesPass = &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  function automatic [15:0] countFailedComparisons(
    input logic [63:0] lanePass,
    input logic        validPass
  );
    integer lane;
    integer count;
    begin
      count = 0;
      for (lane = 0; lane < MAX_DATA_LANES; lane = lane + 1) begin
        if (ACTIVE_LANE_MASK[lane] && !lanePass[lane])
          count = count + 1;
      end
      if (!validPass)
        count = count + 1;
      countFailedComparisons = count;
    end
  endfunction

  // Search each active lane over the implemented PI range exactly once.
  // Phase code PHASE_COUNT-1 is not adjacent to phase code 0: the two ends
  // may belong to different UIs and are therefore never merged.
  integer laneIdx;
  integer phaseIdx;
  integer runLength;
  integer bestLength;
  integer runStart;
  integer bestStart;
  integer laneCenterInt;
  integer minLaneCenterInt;
  integer maxLaneCenterInt;
  integer targetLaneCenterInt;
  integer deskewDeltaInt;
  integer deskewCodeInt;

  always_comb begin
    initialWindowsValidCalc = 1'b1;
    deskewCodesCalc = '0;

    // Defaults for combinational temporaries.
    phaseIdx = 0;
    runLength = 0;
    bestLength = 0;
    runStart = 0;
    bestStart = 0;
    laneCenterInt = 0;
    minLaneCenterInt = PHASE_COUNT - 1;
    maxLaneCenterInt = 0;
    targetLaneCenterInt = 0;
    deskewDeltaInt = 0;
    deskewCodeInt = 0;

    // First find the longest linear passing interval and its center for every
    // active lane. If two intervals have the same length, the lower-phase
    // interval is retained because bestLength is updated only on a longer run.
    for (laneIdx = 0; laneIdx < MAX_DATA_LANES; laneIdx = laneIdx + 1) begin
      laneLeftPhaseCalc[laneIdx] = '0;
      laneRightPhaseCalc[laneIdx] = '0;
      laneCenterPhaseCalc[laneIdx] = '0;

      if (ACTIVE_LANE_MASK[laneIdx]) begin
        runLength = 0;
        bestLength = 0;
        runStart = 0;
        bestStart = 0;

        for (phaseIdx = 0; phaseIdx < PHASE_COUNT; phaseIdx = phaseIdx + 1) begin
          if (initialPassByPhase[phaseIdx][laneIdx]) begin
            if (runLength == 0)
              runStart = phaseIdx;

            runLength = runLength + 1;
            if (runLength > bestLength) begin
              bestLength = runLength;
              bestStart = runStart;
            end
          end else begin
            runLength = 0;
          end
        end

        if (bestLength < MIN_LANE_WINDOW_STEPS) begin
          initialWindowsValidCalc = 1'b0;
        end else begin
          laneCenterInt = bestStart + ((bestLength - 1) >> 1);
          laneLeftPhaseCalc[laneIdx] = bestStart;
          laneRightPhaseCalc[laneIdx] = bestStart + bestLength - 1;
          laneCenterPhaseCalc[laneIdx] = laneCenterInt;

          if (laneCenterInt < minLaneCenterInt)
            minLaneCenterInt = laneCenterInt;
          if (laneCenterInt > maxLaneCenterInt)
            maxLaneCenterInt = laneCenterInt;
        end
      end
    end

    // The local TX deskew can only add delay. Select the latest measured lane
    // center when added delay moves the eye toward larger PI codes; select the
    // earliest center for the opposite PHY polarity.
    if (DESKEW_ADD_DELAY_INCREASES_PHASE)
      targetLaneCenterInt = maxLaneCenterInt;
    else
      targetLaneCenterInt = minLaneCenterInt;

    for (laneIdx = 0; laneIdx < MAX_DATA_LANES; laneIdx = laneIdx + 1) begin
      if (ACTIVE_LANE_MASK[laneIdx]) begin
        laneCenterInt = laneCenterPhaseCalc[laneIdx];

        if (DESKEW_ADD_DELAY_INCREASES_PHASE)
          deskewDeltaInt = targetLaneCenterInt - laneCenterInt;
        else
          deskewDeltaInt = laneCenterInt - targetLaneCenterInt;

        deskewCodeInt = deskewDeltaInt * DESKEW_STEPS_PER_PI;
        if ((deskewCodeInt < 0) ||
            (deskewCodeInt > MAX_DESKEW_CODE_INT)) begin
          initialWindowsValidCalc = 1'b0;
          deskewCodesCalc[
            laneIdx*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH
          ] = '0;
        end else begin
          deskewCodesCalc[
            laneIdx*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH
          ] = deskewCodeInt;
        end
      end
    end
  end

  // Find the longest linear interval in which all active data lanes, Valid,
  // and the partner's cumulative comparison result pass after TX deskew.
  integer globalPhaseIdx;
  integer globalRunLength;
  integer globalBestLength;
  integer globalRunStart;
  integer globalBestStart;

  always_comb begin
    globalRunLength = 0;
    globalBestLength = 0;
    globalRunStart = 0;
    globalBestStart = 0;

    for (globalPhaseIdx = 0;
         globalPhaseIdx < PHASE_COUNT;
         globalPhaseIdx = globalPhaseIdx + 1) begin
      if (verifyPassByPhase[globalPhaseIdx]) begin
        if (globalRunLength == 0)
          globalRunStart = globalPhaseIdx;

        globalRunLength = globalRunLength + 1;
        if (globalRunLength > globalBestLength) begin
          globalBestLength = globalRunLength;
          globalBestStart = globalRunStart;
        end
      end else begin
        globalRunLength = 0;
      end
    end

    globalWindowValidCalc =
      (globalBestLength >= MIN_COMMON_WINDOW_STEPS);

    if (globalBestLength == 0) begin
      globalLeftPhaseCalc = '0;
      globalRightPhaseCalc = '0;
      globalCenterPhaseCalc = '0;
    end else begin
      globalLeftPhaseCalc = globalBestStart;
      globalRightPhaseCalc = globalBestStart + globalBestLength - 1;
      globalCenterPhaseCalc =
        globalBestStart + ((globalBestLength - 1) >> 1);
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

    tx_clock_phase_code = phaseIndexReg;
    tx_lane_deskew_codes = deskewCodesReg;

    apply_tx_clock_phase =
      (stateReg == SweepState_APPLY_INITIAL_PHASE) ||
      (stateReg == SweepState_APPLY_VERIFY_PHASE) ||
      (stateReg == SweepState_APPLY_GLOBAL_PHASE);

    apply_tx_lane_deskew =
      (stateReg == SweepState_APPLY_ZERO_DESKEW) ||
      (stateReg == SweepState_APPLY_DESKEW);

    point_test_start =
      (stateReg == SweepState_START_INITIAL_TEST) ||
      (stateReg == SweepState_START_VERIFY_TEST) ||
      (stateReg == SweepState_START_FINAL_TEST);
  end

  integer clearLaneIdx;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg <= SweepState_IDLE;
      doneReg <= 1'b0;
      errorReg <= 1'b0;
      lastFailedComparisonsReg <= 16'b0;
      retryCountReg <= 16'b0;
      phaseIndexReg <= '0;
      finalClockPhaseReg <= '0;
      deskewCodesReg <= '0;
      globalLeftPhaseReg <= '0;
      globalRightPhaseReg <= '0;
      for (clearLaneIdx = 0;
           clearLaneIdx < MAX_DATA_LANES;
           clearLaneIdx = clearLaneIdx + 1) begin
        laneLeftPhaseReg[clearLaneIdx] <= '0;
        laneRightPhaseReg[clearLaneIdx] <= '0;
        laneCenterPhaseReg[clearLaneIdx] <= '0;
      end
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
        finalClockPhaseReg <= '0;
        deskewCodesReg <= '0;
        globalLeftPhaseReg <= '0;
        globalRightPhaseReg <= '0;
        // Both sweep memories are completely overwritten before they are read;
        // avoiding a bulk clear keeps the implementation from inferring a very
        // large one-cycle reset/clear network.
        for (clearLaneIdx = 0;
             clearLaneIdx < MAX_DATA_LANES;
             clearLaneIdx = clearLaneIdx + 1) begin
          laneLeftPhaseReg[clearLaneIdx] <= '0;
          laneRightPhaseReg[clearLaneIdx] <= '0;
          laneCenterPhaseReg[clearLaneIdx] <= '0;
        end
        stateReg <= SweepState_APPLY_ZERO_DESKEW;
      end else begin
        unique case (stateReg)
          SweepState_IDLE: ;

          SweepState_APPLY_ZERO_DESKEW: begin
            if (tx_lane_deskew_applied) begin
              phaseIndexReg <= '0;
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_APPLY_INITIAL_PHASE: begin
            if (tx_clock_phase_applied)
              stateReg <= SweepState_START_INITIAL_TEST;
          end

          SweepState_START_INITIAL_TEST: begin
            stateReg <= SweepState_WAIT_INITIAL_TEST;
          end

          SweepState_WAIT_INITIAL_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_STORE_INITIAL_RESULT;
          end

          SweepState_STORE_INITIAL_RESULT: begin
            initialPassByPhase[phaseIndexReg] <= point_test_lane_pass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass, point_test_valid_pass
            );
            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
              stateReg <= SweepState_CALCULATE_DESKEW;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_INITIAL_PHASE;
            end
          end

          SweepState_CALCULATE_DESKEW: begin
            if (initialWindowsValidCalc) begin
              deskewCodesReg <= deskewCodesCalc;
              for (clearLaneIdx = 0;
                   clearLaneIdx < MAX_DATA_LANES;
                   clearLaneIdx = clearLaneIdx + 1) begin
                laneLeftPhaseReg[clearLaneIdx] <= laneLeftPhaseCalc[clearLaneIdx];
                laneRightPhaseReg[clearLaneIdx] <= laneRightPhaseCalc[clearLaneIdx];
                laneCenterPhaseReg[clearLaneIdx] <= laneCenterPhaseCalc[clearLaneIdx];
              end
              stateReg <= SweepState_APPLY_DESKEW;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              // A retry overwrites every phase entry before recalculation.
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_DESKEW: begin
            if (tx_lane_deskew_applied)
              stateReg <= SweepState_CLEAR_VERIFY_RESULTS;
          end

          SweepState_CLEAR_VERIFY_RESULTS: begin
            // The following sweep writes every entry in verifyPassByPhase.
            phaseIndexReg <= '0;
            stateReg <= SweepState_APPLY_VERIFY_PHASE;
          end

          SweepState_APPLY_VERIFY_PHASE: begin
            if (tx_clock_phase_applied)
              stateReg <= SweepState_START_VERIFY_TEST;
          end

          SweepState_START_VERIFY_TEST: begin
            stateReg <= SweepState_WAIT_VERIFY_TEST;
          end

          SweepState_WAIT_VERIFY_TEST: begin
            if (point_test_done)
              stateReg <= SweepState_STORE_VERIFY_RESULT;
          end

          SweepState_STORE_VERIFY_RESULT: begin
            verifyPassByPhase[phaseIndexReg] <= pointTestAllPass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass, point_test_valid_pass
            );
            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
              stateReg <= SweepState_CALCULATE_GLOBAL;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_VERIFY_PHASE;
            end
          end

          SweepState_CALCULATE_GLOBAL: begin
            if (globalWindowValidCalc) begin
              globalLeftPhaseReg <= globalLeftPhaseCalc;
              globalRightPhaseReg <= globalRightPhaseCalc;
              finalClockPhaseReg <= globalCenterPhaseCalc;
              phaseIndexReg <= globalCenterPhaseCalc;
              stateReg <= SweepState_APPLY_GLOBAL_PHASE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              // A retry overwrites every phase entry before recalculation.
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_GLOBAL_PHASE: begin
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
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass, point_test_valid_pass
            );
            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              deskewCodesReg <= '0;
              phaseIndexReg <= '0;
              // A retry overwrites every phase entry before recalculation.
              stateReg <= SweepState_APPLY_ZERO_DESKEW;
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
    if ((TX_DESKEW_CODE_WIDTH < 1) || (TX_DESKEW_CODE_WIDTH > 16))
      $error("TX_DESKEW_CODE_WIDTH must be in the range 1..16");
    if (DESKEW_STEPS_PER_PI < 1)
      $error("DESKEW_STEPS_PER_PI must be at least 1");
    if ((MIN_LANE_WINDOW_STEPS < 1) ||
        (MIN_LANE_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_LANE_WINDOW_STEPS is outside the PI sweep range");
    if ((MIN_COMMON_WINDOW_STEPS < 1) ||
        (MIN_COMMON_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_COMMON_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire

```

<a id="MBTrain_DataTrainCenter2-sv"></a>

## [13] MBTrain_DataTrainCenter2.sv

```systemverilog
// FILE_INDEX: 13
// FILE_PATH : MBTrain_DataTrainCenter2.sv

// UCIe MBTRAIN.DATATRAINCENTER2 wrapper with linear aggregate clock centering.
// TX lane deskew is intentionally not modified in this state.
`default_nettype none

module MBTrain_DataTrainCenter2 #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic         flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic         flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic         flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic         flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]  flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic         flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]  flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic         flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]   flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]   flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]   flagToAnalog_d2cReceiver_dataPattern,
  output var logic         flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic [11:0]  substate,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    DataTrainCenter2SenderState_idle = 4'h0,
    DataTrainCenter2SenderState_sendStartReq = 4'h1,
    DataTrainCenter2SenderState_waitStartResp = 4'h2,
    DataTrainCenter2SenderState_startPointTest = 4'h3,
    DataTrainCenter2SenderState_waitPointTest = 4'h4,
    DataTrainCenter2SenderState_checkErrorLog = 4'h5,
    DataTrainCenter2SenderState_sendDoneReq = 4'h6,
    DataTrainCenter2SenderState_waitDoneResp = 4'h7,
    DataTrainCenter2SenderState_finish = 4'h8
  } DataTrainCenter2SenderState_t;

  typedef enum logic [2:0] {
    DataTrainCenter2ReceiverState_idle = 3'h0,
    DataTrainCenter2ReceiverState_waitStartReq = 3'h1,
    DataTrainCenter2ReceiverState_sendStartResp = 3'h2,
    DataTrainCenter2ReceiverState_runPointTest = 3'h3,
    DataTrainCenter2ReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    DataTrainCenter2ReceiverState_sendDoneResp = 3'h5,
    DataTrainCenter2ReceiverState_finish = 3'h6
  } DataTrainCenter2ReceiverState_t;

  (* keep = "true" *) DataTrainCenter2SenderState_t senderStateReg;
  (* keep = "true" *) DataTrainCenter2ReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedStartResp;
  (* keep = "true" *) logic flagReceivedDoneResp;
  (* keep = "true" *) logic flagReceivedStartReq;
  (* keep = "true" *) logic flagReceivedDoneReq;

  (* keep = "true" *) logic d2cSender_receivedPointTestStartResp;
  (* keep = "true" *) logic d2cSender_receivedLfsrClearResp;
  (* keep = "true" *) logic d2cSender_receivedResultsResp;
  (* keep = "true" *) logic d2cSender_receivedEndPointTestResp;

  (* keep = "true" *) logic d2cReceiver_receivedPointTestStartReq;
  (* keep = "true" *) logic d2cReceiver_receivedLfsrClearReq;
  (* keep = "true" *) logic d2cReceiver_receivedResultsReq;
  (* keep = "true" *) logic d2cReceiver_receivedEndPointTestReq;

  (* keep = "true" *) logic flagSentStartReq;
  (* keep = "true" *) logic flagSentDoneReq;
  (* keep = "true" *) logic flagSentStartResp;
  (* keep = "true" *) logic flagSentDoneResp;

  (* keep = "true" *) logic d2cSender_sentPointTestStartReq;
  (* keep = "true" *) logic d2cSender_sentLfsrClearReq;
  (* keep = "true" *) logic d2cSender_sentResultsReq;
  (* keep = "true" *) logic d2cSender_sentEndPointTestReq;

  (* keep = "true" *) logic d2cReceiver_sentPointTestStartResp;
  (* keep = "true" *) logic d2cReceiver_sentLfsrClearResp;
  (* keep = "true" *) logic d2cReceiver_sentResultsResp;
  (* keep = "true" *) logic d2cReceiver_sentEndPointTestResp;

  (* keep = "true" *) logic [15:0] d2cReceiver_loggedResultsMsgInfo;
  (* keep = "true" *) logic [63:0] d2cReceiver_loggedResultsPayload;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;


  // DATATRAINCENTER2 repeats only the aggregate clock-centering sweep.
  // Receiver Vref and optional RX deskew are already complete, and the TX
  // lane-deskew settings produced by DATATRAINCENTER1 remain untouched.
  logic sweepEngine_start;
  logic sweepEngine_busy;
  logic sweepEngine_done;
  logic sweepEngine_trainError;
  logic sweepEngine_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_txClockPhaseCode;
  logic sweepEngine_pointTestStart;
  logic [3:0] sweepEngine_state;
  logic [15:0] sweepEngine_lastFailedComparisons;
  logic [15:0] sweepEngine_retryCount;
  logic [d2cPiCodeWidth-1:0] sweepEngine_finalClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_globalLeftPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_globalRightPhase;

  logic [63:0] d2cSender_resultsLanePassReg;
  logic d2cSender_resultsValidPassReg;
  logic d2cSender_resultsCumulativePassReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  logic d2cSender_start;
  logic d2cReceiver_start;
  logic senderSentStartPulse;
  logic senderSentLfsrPulse;
  logic senderSentResultsPulse;
  logic senderSentEndPulse;
  logic flagToAnalog_d2cReceiver_configureAnalogPulse;

  logic selectSentDoneResp;
  logic selectReceiverEndResp;
  logic selectReceiverResultsResp;
  logic selectReceiverLfsrResp;
  logic selectReceiverStartResp;
  logic selectSentStartResp;
  logic selectSentDoneReq;
  logic selectSenderEndReq;
  logic selectSenderResultsReq;
  logic selectSenderLfsrReq;
  logic selectSenderStartReq;
  logic selectSentStartReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_DATATRAINCENTER2_START_REQ =
    msgMbtrainDataTrainCenter2StartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER2_START_RESP =
    msgMbtrainDataTrainCenter2StartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER2_DONE_REQ =
    msgMbtrainDataTrainCenter2EndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER2_DONE_RESP =
    msgMbtrainDataTrainCenter2EndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      d2cMaximumComparisonErrorThreshold,
      1'b1, 16'd1, 16'd0, 16'd4096,
      1'b0, 4'd0, 3'd0, 3'd0
    );
  wire [127:0] START_POINT_TEST_RESP =
    msgMbtrainStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_REQ =
    msgMbtrainTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_RESP_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);
  wire [127:0] END_POINT_TEST_REQ =
    msgMbtrainEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_TEST_RESP =
    msgMbtrainEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire isStartPointTestReq =
    ((sb_rx_dout[63:0] & 64'h000000FFFFFFFFFF) ==
     (START_POINT_TEST_REQ[63:0] & 64'h000000FFFFFFFFFF));

  // A Results response contains variable MsgInfo, payload, and parity bits.
  // Match only the fixed header fields so both pass and fail responses are
  // recognized.
  wire isTxInitResultsResp =
    (sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
    (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]);

  logic d2cSender_sendStartTxInitD2CPointTestReq;
  logic d2cSender_sendLfsrClearErrorReq;
  logic d2cSender_sendTxInitD2CResultsReq;
  logic d2cSender_sendEndTxInitD2CPointTestReq;
  logic d2cSender_sendDefinedPattern;
  logic d2cSender_resetLocalScrambler;
  logic d2cSender_busy;
  logic d2cSender_done;
  logic [3:0] d2cSender_state;

  logic d2cReceiver_sendStartTxInitD2CPointTestResp;
  logic d2cReceiver_sendLfsrClearErrorResp;
  logic d2cReceiver_sendTxInitD2CResultsResp;
  logic d2cReceiver_sendEndTxInitD2CPointTestResp;
  logic d2cReceiver_resetLocalRxScrambler;
  logic d2cReceiver_busy;
  logic d2cReceiver_done;
  logic [3:0] d2cReceiver_state;

  TxInitD2CPointTestSenderFSM d2cSender (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cSender_start),
    .receivedStartTxInitD2CPointTestResp(d2cSender_receivedPointTestStartResp),
    .receivedLfsrClearErrorResp(d2cSender_receivedLfsrClearResp),
    .receivedTxInitD2CResultsResp(d2cSender_receivedResultsResp),
    .receivedEndTxInitD2CPointTestResp(d2cSender_receivedEndPointTestResp),
    .sentStartTxInitD2CPointTestReq(senderSentStartPulse),
    .sentLfsrClearErrorReq(senderSentLfsrPulse),
    .sentTxInitD2CResultsReq(senderSentResultsPulse),
    .sentEndTxInitD2CPointTestReq(senderSentEndPulse),
    .sentDefinedPattern(flagFromAnalog_d2cSender_lfsrPatternSent),
    .sendStartTxInitD2CPointTestReq(d2cSender_sendStartTxInitD2CPointTestReq),
    .sendLfsrClearErrorReq(d2cSender_sendLfsrClearErrorReq),
    .sendTxInitD2CResultsReq(d2cSender_sendTxInitD2CResultsReq),
    .sendEndTxInitD2CPointTestReq(d2cSender_sendEndTxInitD2CPointTestReq),
    .sendDefinedPattern(d2cSender_sendDefinedPattern),
    .resetLocalScrambler(d2cSender_resetLocalScrambler),
    .busy(d2cSender_busy),
    .done(d2cSender_done),
    .state(d2cSender_state)
  );

  TxInitD2CPointTestReceiverFSM d2cReceiver (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cReceiver_start),
    .receivedStartTxInitD2CPointTestReq(d2cReceiver_receivedPointTestStartReq),
    .receivedLfsrClearErrorReq(d2cReceiver_receivedLfsrClearReq),
    .receivedTxInitD2CResultsReq(d2cReceiver_receivedResultsReq),
    .receivedEndTxInitD2CPointTestReq(d2cReceiver_receivedEndPointTestReq),
    .sentStartTxInitD2CPointTestResp(d2cReceiver_sentPointTestStartResp),
    .sentLfsrClearErrorResp(d2cReceiver_sentLfsrClearResp),
    .sentTxInitD2CResultsResp(d2cReceiver_sentResultsResp),
    .sentEndTxInitD2CPointTestResp(d2cReceiver_sentEndPointTestResp),
    .sendStartTxInitD2CPointTestResp(d2cReceiver_sendStartTxInitD2CPointTestResp),
    .sendLfsrClearErrorResp(d2cReceiver_sendLfsrClearErrorResp),
    .sendTxInitD2CResultsResp(d2cReceiver_sendTxInitD2CResultsResp),
    .sendEndTxInitD2CPointTestResp(d2cReceiver_sendEndTxInitD2CPointTestResp),
    .resetLocalRxScrambler(d2cReceiver_resetLocalRxScrambler),
    .busy(d2cReceiver_busy),
    .done(d2cReceiver_done),
    .state(d2cReceiver_state)
  );

  MBTrain_DataTrainCenter2SweepEngine #(
    .ucieA(ucieA),
    .PI_CODE_WIDTH(d2cPiCodeWidth),
    .MIN_COMMON_WINDOW_STEPS(d2cMinCommonWindowSteps),
    .MAX_TRAINING_RETRIES(d2cMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepEngine_start),
    .busy(sweepEngine_busy),
    .done(sweepEngine_done),
    .trainError(sweepEngine_trainError),
    .apply_tx_clock_phase(sweepEngine_applyTxClockPhase),
    .tx_clock_phase_code(sweepEngine_txClockPhaseCode),
    .tx_clock_phase_applied(flagFromAnalog_d2cSender_txClockPhaseApplied),
    .point_test_start(sweepEngine_pointTestStart),
    .point_test_done(d2cSender_done),
    .point_test_lane_pass(d2cSender_resultsLanePassReg),
    .point_test_valid_pass(d2cSender_resultsValidPassReg),
    .point_test_cumulative_pass(d2cSender_resultsCumulativePassReg),
    .state(sweepEngine_state),
    .lastFailedComparisons(sweepEngine_lastFailedComparisons),
    .retryCount(sweepEngine_retryCount),
    .finalClockPhase(sweepEngine_finalClockPhase),
    .globalLeftPhase(sweepEngine_globalLeftPhase),
    .globalRightPhase(sweepEngine_globalRightPhase)
  );

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg || sweepEngine_trainError;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    substate = {senderStateReg[3:0], d2cSender_state, d2cReceiver_state};
    lastErrorCount = sweepEngine_lastFailedComparisons;
    retryCount = sweepEngine_retryCount;

    flagToAnalog_d2cSender_sendLfsrPattern = running && d2cSender_sendDefinedPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
    flagToAnalog_d2cSender_applyTxClockPhase = running && sweepEngine_applyTxClockPhase;
    flagToAnalog_d2cSender_txClockPhaseCode = sweepEngine_txClockPhaseCode;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = flagToAnalog_d2cReceiver_configureAnalogPulse;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = d2c_maximumComparisonErrorThresholdReg;
    flagToAnalog_d2cReceiver_comparisonMode = d2c_comparisonModeReg;
    flagToAnalog_d2cReceiver_iterationCountSettings = d2c_iterationCountSettingsReg;
    flagToAnalog_d2cReceiver_idleCountSettings = d2c_idleCountSettingsReg;
    flagToAnalog_d2cReceiver_burstCountSettings = d2c_burstCountSettingsReg;
    flagToAnalog_d2cReceiver_patternMode = d2c_patternModeReg;
    flagToAnalog_d2cReceiver_clockPhaseControl = d2c_clockPhaseControlReg;
    flagToAnalog_d2cReceiver_validPattern = d2c_validPatternReg;
    flagToAnalog_d2cReceiver_dataPattern = d2c_dataPatternReg;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = running && d2cReceiver_resetLocalRxScrambler;
  end

  // Combinational local pulses and the source's pulse-style registered TX selector.
  always_comb begin
    sweepEngine_start = running && !startPulse &&
                        (senderStateReg == DataTrainCenter2SenderState_startPointTest);
    d2cSender_start = running && !startPulse &&
                      (senderStateReg == DataTrainCenter2SenderState_waitPointTest) &&
                      sweepEngine_pointTestStart;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    flagToAnalog_d2cReceiver_configureAnalogPulse = running && rxValidRisingEdge && isStartPointTestReq;

    nextSbTxValid = 1'b0;
    nextSbTxDin = 128'b0;
    selectSentDoneResp = 1'b0;
    selectReceiverEndResp = 1'b0;
    selectReceiverResultsResp = 1'b0;
    selectReceiverLfsrResp = 1'b0;
    selectReceiverStartResp = 1'b0;
    selectSentStartResp = 1'b0;
    selectSentDoneReq = 1'b0;
    selectSenderEndReq = 1'b0;
    selectSenderResultsReq = 1'b0;
    selectSenderLfsrReq = 1'b0;
    selectSenderStartReq = 1'b0;
    selectSentStartReq = 1'b0;

    if (!startPulse) begin
      unique case (receiverStateReg)
        DataTrainCenter2ReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        DataTrainCenter2ReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == DataTrainCenter2ReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER2_DONE_RESP;
        nextSbTxValid = 1'b1;
        selectSentDoneResp = 1'b1;
      end
      else if (d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverEndResp = 1'b1;
      end
      else if (d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          d2cReceiver_loggedResultsMsgInfo,
          d2cReceiver_loggedResultsPayload
        );
        nextSbTxValid = 1'b1;
        selectReceiverResultsResp = 1'b1;
      end
      else if (d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverLfsrResp = 1'b1;
      end
      else if (d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverStartResp = 1'b1;
      end
      else if ((receiverStateReg == DataTrainCenter2ReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER2_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end

      else if ((senderStateReg == DataTrainCenter2SenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER2_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter2SenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter2SenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter2SenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter2SenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter2SenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER2_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= DataTrainCenter2SenderState_idle;
      receiverStateReg <= DataTrainCenter2ReceiverState_idle;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedStartResp <= 1'b0;
      flagReceivedDoneResp <= 1'b0;
      flagReceivedStartReq <= 1'b0;
      flagReceivedDoneReq <= 1'b0;
      d2cSender_receivedPointTestStartResp <= 1'b0;
      d2cSender_receivedLfsrClearResp <= 1'b0;
      d2cSender_receivedResultsResp <= 1'b0;
      d2cSender_receivedEndPointTestResp <= 1'b0;
      d2cReceiver_receivedPointTestStartReq <= 1'b0;
      d2cReceiver_receivedLfsrClearReq <= 1'b0;
      d2cReceiver_receivedResultsReq <= 1'b0;
      d2cReceiver_receivedEndPointTestReq <= 1'b0;
      flagSentStartReq <= 1'b0;
      flagSentDoneReq <= 1'b0;
      flagSentStartResp <= 1'b0;
      flagSentDoneResp <= 1'b0;
      d2cSender_sentPointTestStartReq <= 1'b0;
      d2cSender_sentLfsrClearReq <= 1'b0;
      d2cSender_sentResultsReq <= 1'b0;
      d2cSender_sentEndPointTestReq <= 1'b0;
      d2cReceiver_sentPointTestStartResp <= 1'b0;
      d2cReceiver_sentLfsrClearResp <= 1'b0;
      d2cReceiver_sentResultsResp <= 1'b0;
      d2cReceiver_sentEndPointTestResp <= 1'b0;
      d2cReceiver_loggedResultsMsgInfo <= 16'b0;
      d2cReceiver_loggedResultsPayload <= 64'b0;
      d2cSender_resultsLanePassReg <= 64'b0;
      d2cSender_resultsValidPassReg <= 1'b0;
      d2cSender_resultsCumulativePassReg <= 1'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;

      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        senderStateReg <= DataTrainCenter2SenderState_sendStartReq;
        receiverStateReg <= DataTrainCenter2ReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cReceiver_receivedPointTestStartReq <= 1'b0;
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        flagSentStartReq <= 1'b0;
        flagSentDoneReq <= 1'b0;
        flagSentStartResp <= 1'b0;
        flagSentDoneResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
        d2cReceiver_loggedResultsMsgInfo <= 16'b0;
        d2cReceiver_loggedResultsPayload <= 64'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_DATATRAINCENTER2_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER2_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER2_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER2_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
        else if (isStartPointTestReq) begin
          d2c_maximumComparisonErrorThresholdReg <= sb_rx_dout[55:40];
          d2c_comparisonModeReg <= sb_rx_dout[123];
          d2c_iterationCountSettingsReg <= sb_rx_dout[122:107];
          d2c_idleCountSettingsReg <= sb_rx_dout[106:91];
          d2c_burstCountSettingsReg <= sb_rx_dout[90:75];
          d2c_patternModeReg <= sb_rx_dout[74];
          d2c_clockPhaseControlReg <= sb_rx_dout[73:70];
          d2c_validPatternReg <= sb_rx_dout[69:67];
          d2c_dataPatternReg <= sb_rx_dout[66:64];
          d2cReceiver_receivedPointTestStartReq <= 1'b1;
        end
        else if (sb_rx_dout == START_POINT_TEST_RESP)
          d2cSender_receivedPointTestStartResp <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_REQ)
          d2cReceiver_receivedLfsrClearReq <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_RESP)
          d2cSender_receivedLfsrClearResp <= 1'b1;
        else if (sb_rx_dout == TX_INIT_RESULTS_REQ) begin
          d2cReceiver_loggedResultsMsgInfo <= flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
          d2cReceiver_loggedResultsPayload <= flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
          d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (isTxInitResultsResp) begin
          d2cSender_receivedResultsResp <= 1'b1;
          d2cSender_resultsLanePassReg <= sb_rx_dout[127:64];
          d2cSender_resultsValidPassReg <= sb_rx_dout[45];
          d2cSender_resultsCumulativePassReg <= sb_rx_dout[44];
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (d2cSender_start) begin
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      // Clear a Start request only when the matching response is scheduled.
      // The sent flag is sticky until the receiver point-test FSM restarts.
      if (selectReceiverStartResp)
        d2cReceiver_receivedPointTestStartReq <= 1'b0;

      if (d2cReceiver_start) begin
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
      end

      if (selectSentDoneResp)
        flagSentDoneResp <= 1'b1;
      if (selectReceiverEndResp)
        d2cReceiver_sentEndPointTestResp <= 1'b1;
      if (selectReceiverResultsResp)
        d2cReceiver_sentResultsResp <= 1'b1;
      if (selectReceiverLfsrResp)
        d2cReceiver_sentLfsrClearResp <= 1'b1;
      if (selectReceiverStartResp)
        d2cReceiver_sentPointTestStartResp <= 1'b1;
      if (selectSentStartResp)
        flagSentStartResp <= 1'b1;
      if (selectSentDoneReq)
        flagSentDoneReq <= 1'b1;
      if (selectSenderEndReq)
        d2cSender_sentEndPointTestReq <= 1'b1;
      if (selectSenderResultsReq)
        d2cSender_sentResultsReq <= 1'b1;
      if (selectSenderLfsrReq)
        d2cSender_sentLfsrClearReq <= 1'b1;
      if (selectSenderStartReq)
        d2cSender_sentPointTestStartReq <= 1'b1;
      if (selectSentStartReq)
        flagSentStartReq <= 1'b1;

      if (!startPulse) begin
        unique case (senderStateReg)
          DataTrainCenter2SenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= DataTrainCenter2SenderState_waitStartResp;
          end
          DataTrainCenter2SenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= DataTrainCenter2SenderState_startPointTest;
          end
          DataTrainCenter2SenderState_startPointTest:
            senderStateReg <= DataTrainCenter2SenderState_waitPointTest;
          DataTrainCenter2SenderState_waitPointTest: begin
            if (sweepEngine_trainError) begin
              trainErrorReg <= 1'b1;
              running <= 1'b0;
              senderStateReg <= DataTrainCenter2SenderState_idle;
              receiverStateReg <= DataTrainCenter2ReceiverState_idle;
            end else if (sweepEngine_done) begin
              senderStateReg <= DataTrainCenter2SenderState_sendDoneReq;
            end
          end
          DataTrainCenter2SenderState_checkErrorLog: begin
            // Retained for state-number compatibility with the original.
            senderStateReg <= DataTrainCenter2SenderState_waitPointTest;
          end
          DataTrainCenter2SenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= DataTrainCenter2SenderState_waitDoneResp;
          end
          DataTrainCenter2SenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= DataTrainCenter2SenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          DataTrainCenter2ReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= DataTrainCenter2ReceiverState_sendStartResp;
          end
          DataTrainCenter2ReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= DataTrainCenter2ReceiverState_runPointTest;
          end
          DataTrainCenter2ReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= DataTrainCenter2ReceiverState_waitDoneReqOrPointTestReq;
          end
          DataTrainCenter2ReceiverState_waitDoneReqOrPointTestReq: begin
            if (flagReceivedDoneReq)
              receiverStateReg <= DataTrainCenter2ReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= DataTrainCenter2ReceiverState_runPointTest;
          end
          DataTrainCenter2ReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= DataTrainCenter2ReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == DataTrainCenter2SenderState_finish) &&
            (receiverStateReg == DataTrainCenter2ReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_DataTrainCenter2SweepEngine-sv"></a>

## [14] MBTrain_DataTrainCenter2SweepEngine.sv

```systemverilog
// FILE_INDEX: 14
// FILE_PATH : MBTrain_DataTrainCenter2SweepEngine.sv

// MBTRAIN.DATATRAINCENTER2 local transmitter clock-centering controller.
//
// DATATRAINCENTER2 executes after receiver Vref training and optional receiver
// per-lane deskew. It therefore repeats only the aggregate D2C clock-phase
// search. The transmitter lane-deskew values selected in DATATRAINCENTER1 are
// deliberately not touched here.
//
// The sideband point-test protocol remains outside this module. For every
// one-cycle point_test_start pulse, the caller runs one complete Tx-initiated
// D2C point test and returns its result with point_test_done.
//
// PI codes are treated as one linear ordered search interval. Code zero and
// code PHASE_COUNT-1 are not adjacent and passing runs at the two boundaries
// are never merged.
`default_nettype none

module MBTrain_DataTrainCenter2SweepEngine #(
  parameter bit          ucieA                   = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter int unsigned PI_CODE_WIDTH           = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned MAX_TRAINING_RETRIES    = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
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

  output var logic        point_test_start,
  input  wire logic        point_test_done,
  input  wire logic [63:0] point_test_lane_pass,
  input  wire logic        point_test_valid_pass,
  input  wire logic        point_test_cumulative_pass,

  output var logic [3:0]  state,
  output var logic [15:0] lastFailedComparisons,
  output var logic [15:0] retryCount,
  output var logic [PI_CODE_WIDTH-1:0] finalClockPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalLeftPhase,
  output var logic [PI_CODE_WIDTH-1:0] globalRightPhase
);
  localparam int unsigned MAX_DATA_LANES = 64;
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);

  localparam logic [63:0] ACTIVE_LANE_MASK =
    ucieA ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;

  typedef enum logic [3:0] {
    SweepState_IDLE               = 4'd0,
    SweepState_APPLY_SWEEP_PHASE  = 4'd1,
    SweepState_START_SWEEP_TEST   = 4'd2,
    SweepState_WAIT_SWEEP_TEST    = 4'd3,
    SweepState_STORE_SWEEP_RESULT = 4'd4,
    SweepState_CALCULATE_GLOBAL   = 4'd5,
    SweepState_APPLY_GLOBAL_PHASE = 4'd6,
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
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] globalLeftPhaseReg;
  (* keep = "true" *) logic [PI_CODE_WIDTH-1:0] globalRightPhaseReg;

  logic passByPhase [0:PHASE_COUNT-1];

  wire allActiveDataLanesPass =
    &(point_test_lane_pass | ~ACTIVE_LANE_MASK);
  wire pointTestAllPass = point_test_valid_pass &&
                          point_test_cumulative_pass &&
                          allActiveDataLanesPass;

  function automatic [15:0] countFailedComparisons(
    input logic [63:0] lanePass,
    input logic        validPass,
    input logic        cumulativePass
  );
    integer lane;
    integer count;
    begin
      count = 0;
      for (lane = 0; lane < MAX_DATA_LANES; lane = lane + 1) begin
        if (ACTIVE_LANE_MASK[lane] && !lanePass[lane])
          count = count + 1;
      end
      if (!validPass)
        count = count + 1;
      if (!cumulativePass && (count == 0))
        count = 1;
      countFailedComparisons = count;
    end
  endfunction

  integer phaseIdx;
  integer runLength;
  integer bestLength;
  integer runStart;
  integer bestStart;

  logic globalWindowValidCalc;
  logic [PI_CODE_WIDTH-1:0] globalLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] globalCenterPhaseCalc;

  always_comb begin
    runLength = 0;
    bestLength = 0;
    runStart = 0;
    bestStart = 0;

    for (phaseIdx = 0; phaseIdx < PHASE_COUNT; phaseIdx = phaseIdx + 1) begin
      if (passByPhase[phaseIdx]) begin
        if (runLength == 0)
          runStart = phaseIdx;
        runLength = runLength + 1;
        if (runLength > bestLength) begin
          bestLength = runLength;
          bestStart = runStart;
        end
      end else begin
        runLength = 0;
      end
    end

    globalWindowValidCalc = (bestLength >= MIN_COMMON_WINDOW_STEPS);

    if (bestLength == 0) begin
      globalLeftPhaseCalc = '0;
      globalRightPhaseCalc = '0;
      globalCenterPhaseCalc = '0;
    end else begin
      globalLeftPhaseCalc = bestStart;
      globalRightPhaseCalc = bestStart + bestLength - 1;
      globalCenterPhaseCalc = bestStart + ((bestLength - 1) >> 1);
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
    globalLeftPhase = globalLeftPhaseReg;
    globalRightPhase = globalRightPhaseReg;

    tx_clock_phase_code = phaseIndexReg;
    apply_tx_clock_phase =
      (stateReg == SweepState_APPLY_SWEEP_PHASE) ||
      (stateReg == SweepState_APPLY_GLOBAL_PHASE);

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
      finalClockPhaseReg <= '0;
      globalLeftPhaseReg <= '0;
      globalRightPhaseReg <= '0;
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
        finalClockPhaseReg <= '0;
        globalLeftPhaseReg <= '0;
        globalRightPhaseReg <= '0;
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
            passByPhase[phaseIndexReg] <= pointTestAllPass;
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass,
              point_test_valid_pass,
              point_test_cumulative_pass
            );

            if (phaseIndexReg == {PI_CODE_WIDTH{1'b1}}) begin
              stateReg <= SweepState_CALCULATE_GLOBAL;
            end else begin
              phaseIndexReg <= phaseIndexReg + 1'b1;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end
          end

          SweepState_CALCULATE_GLOBAL: begin
            if (globalWindowValidCalc) begin
              globalLeftPhaseReg <= globalLeftPhaseCalc;
              globalRightPhaseReg <= globalRightPhaseCalc;
              finalClockPhaseReg <= globalCenterPhaseCalc;
              phaseIndexReg <= globalCenterPhaseCalc;
              stateReg <= SweepState_APPLY_GLOBAL_PHASE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
              finalClockPhaseReg <= '0;
              globalLeftPhaseReg <= '0;
              globalRightPhaseReg <= '0;
              stateReg <= SweepState_APPLY_SWEEP_PHASE;
            end else begin
              errorReg <= 1'b1;
              stateReg <= SweepState_ERROR;
            end
          end

          SweepState_APPLY_GLOBAL_PHASE: begin
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
            lastFailedComparisonsReg <= countFailedComparisons(
              point_test_lane_pass,
              point_test_valid_pass,
              point_test_cumulative_pass
            );

            if (pointTestAllPass) begin
              doneReg <= 1'b1;
              stateReg <= SweepState_DONE;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg <= retryCountReg + 16'd1;
              phaseIndexReg <= '0;
              finalClockPhaseReg <= '0;
              globalLeftPhaseReg <= '0;
              globalRightPhaseReg <= '0;
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
    if ((MIN_COMMON_WINDOW_STEPS < 1) ||
        (MIN_COMMON_WINDOW_STEPS > PHASE_COUNT))
      $error("MIN_COMMON_WINDOW_STEPS is outside the PI sweep range");
  end
`endif
endmodule

`default_nettype wire

```

<a id="MBTrain_DataTrainVrefFSM-sv"></a>

## [15] MBTrain_DataTrainVrefFSM.sv

```systemverilog
// FILE_INDEX: 15
// FILE_PATH : MBTrain_DataTrainVrefFSM.sv

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

```

<a id="MBTrain_DataVrefFSM-sv"></a>

## [16] MBTrain_DataVrefFSM.sv

```systemverilog
// FILE_INDEX: 16
// FILE_PATH : MBTrain_DataVrefFSM.sv

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

```

<a id="MBTrain_DataVrefStateCore-sv"></a>

## [17] MBTrain_DataVrefStateCore.sv

```systemverilog
// FILE_INDEX: 17
// FILE_PATH : MBTrain_DataVrefStateCore.sv

// Shared implementation for UCIe MBTRAIN.DATAVREF and MBTRAIN.DATATRAINVREF.
//
// Each die has two concurrent roles:
//   1. Receiver initiator: sweep the local Data receiver Vrefs in parallel and initiate one
//      Rx Init D2C point test for every code.
//   2. Transmitter responder: serve the opposite die's Rx Init D2C point tests
//      by transmitting the 4096-UI continuous LFSR sequence with functional Valid framing.
//
// IS_DATATRAIN_VREF selects only the outer MBTRAIN Start/End(Done) messages.  The
// receiver-initiated point-test protocol and Vref search are otherwise shared.
//
// SidebandMsgGenerator_pkg supplies the packet encodings.  The generic
// RxInitD2CPointTestReceiverFSM and RxInitD2CPointTestSenderFSM modules supply
// the sequencing.  The project-owned TxInitD2CPointTest* modules remain in the
// build for transmitter-initiated states but cannot replace these Rx-init roles.
`default_nettype none

module MBTrain_DataVrefStateCore #(
  parameter bit IS_DATATRAIN_VREF = 1'b0,
  parameter bit PERFORM_LOCAL_TRAINING = 1'b1,
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter logic [15:0] MAXIMUM_COMPARISON_ERROR_THRESHOLD = 16'd0,
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
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

  // Local receiver controls: this is the Vref being optimized.
  output      logic                         flagToAnalog_applyRxVref,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] flagToAnalog_rxVrefCodes,
  input  wire logic                         flagFromAnalog_rxVrefApplied,
  output      logic                         flagToAnalog_configureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_maximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_comparisonMode,
  output      logic [15:0]                  flagToAnalog_iterationCountSettings,
  output      logic [15:0]                  flagToAnalog_idleCountSettings,
  output      logic [15:0]                  flagToAnalog_burstCountSettings,
  output      logic                         flagToAnalog_patternMode,
  output      logic [3:0]                   flagToAnalog_clockPhaseControl,
  output      logic [2:0]                   flagToAnalog_validPattern,
  output      logic [2:0]                   flagToAnalog_dataPattern,
  output      logic                         flagToAnalog_clearComparisonErrors,
  input  wire logic [DATA_LANE_COUNT-1:0] flagFromAnalog_detectedDataPattern,

  // Local transmitter controls used while serving the opposite receiver.
  output      logic                         flagToAnalog_sendLfsrPattern,
  input  wire logic                         flagFromAnalog_lfsrPatternSent,
  output      logic                         flagToAnalog_resetLocalTxScrambler,

  output      logic [11:0]                  substate,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] selectedVrefCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validWindowLeftCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validWindowRightCodes
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LocalState_idle          = 4'h0,
    LocalState_sendStartReq  = 4'h1,
    LocalState_waitStartResp = 4'h2,
    LocalState_startSweep    = 4'h3,
    LocalState_waitSweep     = 4'h4,
    LocalState_sendEndReq    = 4'h5,
    LocalState_waitEndResp   = 4'h6,
    LocalState_finish        = 4'h7,
    LocalState_error         = 4'h8
  } LocalState_t;

  typedef enum logic [2:0] {
    RemoteState_idle          = 3'h0,
    RemoteState_waitStartReq  = 3'h1,
    RemoteState_sendStartResp = 3'h2,
    RemoteState_active        = 3'h3,
    RemoteState_sendEndResp   = 3'h4,
    RemoteState_finish        = 3'h5
  } RemoteState_t;

  typedef enum logic [4:0] {
    TxSource_none                    = 5'd0,
    TxSource_remoteOuterEndResp      = 5'd1,
    TxSource_pointResponderEndResp   = 5'd2,
    TxSource_pointInitiatorCountResp = 5'd3,
    TxSource_pointResponderCountReq  = 5'd4,
    TxSource_pointInitiatorClearResp = 5'd5,
    TxSource_pointResponderClearReq  = 5'd6,
    TxSource_pointResponderStartResp = 5'd7,
    TxSource_remoteOuterStartResp    = 5'd8,
    TxSource_pointInitiatorEndReq    = 5'd9,
    TxSource_pointInitiatorStartReq  = 5'd10,
    TxSource_localOuterEndReq        = 5'd11,
    TxSource_localOuterStartReq      = 5'd12
  } TxSource_t;

  (* keep = "true" *) LocalState_t localStateReg;
  (* keep = "true" *) RemoteState_t remoteStateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  // Latch the peer's outer End/Done request when it arrives while the local
  // transmitter responder is still completing its final point test.  Without
  // this latch, an asymmetric optional DATATRAINVREF configuration can lose the
  // one-cycle sideband request and deadlock.
  (* keep = "true" *) logic remoteOuterEndPendingReg;

  (* keep = "true" *) logic sbTxValidReg;
  (* keep = "true" *) logic [127:0] sbTxDinReg;
  (* keep = "true" *) TxSource_t sbTxSourceReg;
  logic txLoadValid;
  logic [127:0] txLoadDin;
  TxSource_t txLoadSource;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire txTransfer = sbTxValidReg && sb_tx_ready;

  wire [127:0] OUTER_START_REQ = IS_DATATRAIN_VREF ?
    msgMbtrainDataTrainVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainDataVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_START_RESP = IS_DATATRAIN_VREF ?
    msgMbtrainDataTrainVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainDataVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_REQ = IS_DATATRAIN_VREF ?
    msgMbtrainDataTrainVrefEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainDataVrefEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_RESP = IS_DATATRAIN_VREF ?
    msgMbtrainDataTrainVrefEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainDataVrefEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // Continuous Data-lane LFSR training: 4096 UI accompanied by the
  // functional Valid framing.  Track remains low while this state is active.
  wire [127:0] RXINIT_START_REQ =
    msgMbtrainDataVrefStartRxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      MAXIMUM_COMPARISON_ERROR_THRESHOLD,
      1'b0,       // per-lane comparison
      16'd1,      // continuous-mode convention
      16'd0,      // no idle UI
      16'd4096,   // 4K UI continuous LFSR burst
      1'b0,       // continuous pattern mode
      4'd0,       // forwarded-clock phase is not changed here
      3'd0,       // functional Valid framing
      3'd0        // Data-lane LFSR
    );
  wire [127:0] RXINIT_START_RESP =
    msgMbtrainDataVrefStartRxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_REQ =
    msgMbtrainRxInitD2CTxCountDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_RESP =
    msgMbtrainRxInitD2CTxCountDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_REQ =
    msgMbtrainRxInitD2CEndPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_RESP =
    msgMbtrainRxInitD2CEndPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // The Start Rx Init request contains variable MsgInfo/payload/parity.  Match
  // its fixed message-code/subcode/source/opcode fields in the low 40 bits.
  wire isRxInitStartReq =
    (sb_rx_dout[39:0] == RXINIT_START_REQ[39:0]);

  wire receivedOuterStartReq = rxValidRisingEdge &&
                               (sb_rx_dout == OUTER_START_REQ);
  wire receivedOuterStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == OUTER_START_RESP);
  wire receivedOuterEndReq = rxValidRisingEdge &&
                             (sb_rx_dout == OUTER_END_REQ);
  wire receivedOuterEndResp = rxValidRisingEdge &&
                              (sb_rx_dout == OUTER_END_RESP);

  wire receivedPointStartReq = rxValidRisingEdge && isRxInitStartReq;
  wire receivedPointStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == RXINIT_START_RESP);
  wire receivedClearErrorReq = rxValidRisingEdge &&
                               (sb_rx_dout == CLEAR_ERROR_REQ);
  wire receivedClearErrorResp = rxValidRisingEdge &&
                                (sb_rx_dout == CLEAR_ERROR_RESP);
  wire receivedTxCountDoneReq = rxValidRisingEdge &&
                                (sb_rx_dout == TX_COUNT_DONE_REQ);
  wire receivedTxCountDoneResp = rxValidRisingEdge &&
                                 (sb_rx_dout == TX_COUNT_DONE_RESP);
  wire receivedEndPointReq = rxValidRisingEdge &&
                             (sb_rx_dout == END_POINT_REQ);
  wire receivedEndPointResp = rxValidRisingEdge &&
                              (sb_rx_dout == END_POINT_RESP);

  wire localOuterStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterStartReq);
  wire localOuterEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterEndReq);
  wire remoteOuterStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterStartResp);
  wire remoteOuterEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterEndResp);

  wire initiatorStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorStartReq);
  wire initiatorClearRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorClearResp);
  wire initiatorCountRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorCountResp);
  wire initiatorEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorEndReq);

  wire responderStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderStartResp);
  wire responderClearReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderClearReq);
  wire responderCountReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderCountReq);
  wire responderEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderEndResp);

  logic sweepStart;
  logic sweepBusy;
  logic sweepDone;
  logic sweepTrainError;
  logic sweepApplyVref;
  logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] sweepVrefCodes;
  logic sweepPointStart;
  logic [3:0] sweepState;
  logic [15:0] sweepFailedLaneCount;
  logic [15:0] sweepRetryCount;
  logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] sweepFinalCodes;
  logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] sweepLeftCodes;
  logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] sweepRightCodes;

  logic initiatorSendStartReq;
  logic initiatorSendClearResp;
  logic initiatorSendCountResp;
  logic initiatorSendEndReq;
  logic initiatorConfigureReceiver;
  logic initiatorClearErrors;
  logic initiatorBusy;
  logic initiatorDone;
  logic [DATA_LANE_COUNT-1:0] initiatorPointPassVector;
  logic [3:0] initiatorState;

  logic responderSendStartResp;
  logic responderSendClearReq;
  logic responderSendCountReq;
  logic responderSendEndResp;
  logic responderSendPattern;
  logic responderResetTxScrambler;
  logic responderBusy;
  logic responderDone;
  logic [3:0] responderState;

  wire responderStart = runningReg &&
                        (remoteStateReg == RemoteState_active) &&
                        receivedPointStartReq;

  assign sweepStart = runningReg &&
                      (localStateReg == LocalState_startSweep);

  MBTrain_DataVrefSweepEngine #(
    .DATA_LANE_COUNT(DATA_LANE_COUNT),
    .ACTIVE_DATA_LANE_MASK(ACTIVE_DATA_LANE_MASK),
    .VREF_VALUE_COUNT(VREF_VALUE_COUNT),
    .VREF_CODE_WIDTH(VREF_CODE_WIDTH),
    .MIN_PASSING_WINDOW_VALUES(MIN_PASSING_WINDOW_VALUES),
    .MAX_TRAINING_RETRIES(MAX_TRAINING_RETRIES)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepStart),
    .busy(sweepBusy),
    .done(sweepDone),
    .trainError(sweepTrainError),
    .apply_rx_vref(sweepApplyVref),
    .rx_vref_codes(sweepVrefCodes),
    .rx_vref_applied(flagFromAnalog_rxVrefApplied),
    .point_test_start(sweepPointStart),
    .point_test_done(initiatorDone),
    .point_test_pass(initiatorPointPassVector),
    .state(sweepState),
    .lastFailedLaneCount(sweepFailedLaneCount),
    .retryCount(sweepRetryCount),
    .finalVrefCodes(sweepFinalCodes),
    .validLeftCodes(sweepLeftCodes),
    .validRightCodes(sweepRightCodes)
  );

  RxInitD2CPointTestReceiverFSM #(
    .RESULT_WIDTH(DATA_LANE_COUNT)
  ) pointInitiator (
    .clock(clock),
    .reset_n(reset_n),
    .start(runningReg && sweepPointStart),
    .configureReceiver(initiatorConfigureReceiver),
    .sendStartRxInitD2CPointTestReq(initiatorSendStartReq),
    .sentStartRxInitD2CPointTestReq(initiatorStartReqSent),
    .receivedStartRxInitD2CPointTestResp(receivedPointStartResp),
    .receivedLfsrClearErrorReq(receivedClearErrorReq),
    .clearComparisonErrors(initiatorClearErrors),
    .sendLfsrClearErrorResp(initiatorSendClearResp),
    .sentLfsrClearErrorResp(initiatorClearRespSent),
    .receivedRxInitD2CTxCountDoneReq(receivedTxCountDoneReq),
    .detectedValidPattern(flagFromAnalog_detectedDataPattern),
    .sendRxInitD2CTxCountDoneResp(initiatorSendCountResp),
    .sentRxInitD2CTxCountDoneResp(initiatorCountRespSent),
    .sendEndRxInitD2CPointTestReq(initiatorSendEndReq),
    .sentEndRxInitD2CPointTestReq(initiatorEndReqSent),
    .receivedEndRxInitD2CPointTestResp(receivedEndPointResp),
    .busy(initiatorBusy),
    .done(initiatorDone),
    .pointTestPass(initiatorPointPassVector),
    .state(initiatorState)
  );

  RxInitD2CPointTestSenderFSM pointResponder (
    .clock(clock),
    .reset_n(reset_n),
    .start(responderStart),
    .sendStartRxInitD2CPointTestResp(responderSendStartResp),
    .sentStartRxInitD2CPointTestResp(responderStartRespSent),
    .resetLocalScrambler(responderResetTxScrambler),
    .sendLfsrClearErrorReq(responderSendClearReq),
    .sentLfsrClearErrorReq(responderClearReqSent),
    .receivedLfsrClearErrorResp(receivedClearErrorResp),
    .sendDefinedPattern(responderSendPattern),
    .sentDefinedPattern(flagFromAnalog_lfsrPatternSent),
    .sendRxInitD2CTxCountDoneReq(responderSendCountReq),
    .sentRxInitD2CTxCountDoneReq(responderCountReqSent),
    .receivedRxInitD2CTxCountDoneResp(receivedTxCountDoneResp),
    .receivedEndRxInitD2CPointTestReq(receivedEndPointReq),
    .sendEndRxInitD2CPointTestResp(responderSendEndResp),
    .sentEndRxInitD2CPointTestResp(responderEndRespSent),
    .busy(responderBusy),
    .done(responderDone),
    .state(responderState)
  );

  always_comb begin
    busy       = runningReg && !doneReg;
    done       = doneReg;
    trainError = trainErrorReg || sweepTrainError;
    sb_tx_valid = sbTxValidReg;
    sb_tx_din   = sbTxDinReg;

    flagToAnalog_applyRxVref = runningReg && PERFORM_LOCAL_TRAINING &&
                               sweepApplyVref;
    flagToAnalog_rxVrefCodes = sweepVrefCodes;
    flagToAnalog_configureRxInitD2CPointTest = runningReg &&
                                               initiatorConfigureReceiver;
    flagToAnalog_maximumComparisonErrorThreshold =
      MAXIMUM_COMPARISON_ERROR_THRESHOLD;
    flagToAnalog_comparisonMode = 1'b0;
    flagToAnalog_iterationCountSettings = 16'd1;
    flagToAnalog_idleCountSettings = 16'd0;
    flagToAnalog_burstCountSettings = 16'd4096;
    flagToAnalog_patternMode = 1'b0;
    flagToAnalog_clockPhaseControl = 4'd0;
    flagToAnalog_validPattern = 3'd0;
    flagToAnalog_dataPattern = 3'd0;
    flagToAnalog_clearComparisonErrors = runningReg && initiatorClearErrors;

    flagToAnalog_sendLfsrPattern = runningReg && responderSendPattern;
    flagToAnalog_resetLocalTxScrambler = runningReg &&
                                         responderResetTxScrambler;

    substate = {localStateReg, initiatorState, responderState};
    lastErrorCount = sweepFailedLaneCount;
    retryCount = sweepRetryCount;
    selectedVrefCodes = sweepFinalCodes;
    validWindowLeftCodes = sweepLeftCodes;
    validWindowRightCodes = sweepRightCodes;
  end

  // One-deep sideband TX buffer.  Protocol responses and the remote
  // transmitter role take priority, preventing a local sweep from starving the
  // opposite die's receiver-initiated point test.
  always_comb begin
    txLoadValid  = 1'b0;
    txLoadDin    = 128'd0;
    txLoadSource = TxSource_none;

    if (runningReg && !sbTxValidReg) begin
      if (remoteStateReg == RemoteState_sendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_RESP;
        txLoadSource = TxSource_remoteOuterEndResp;
      end else if (responderSendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_RESP;
        txLoadSource = TxSource_pointResponderEndResp;
      end else if (initiatorSendCountResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_RESP;
        txLoadSource = TxSource_pointInitiatorCountResp;
      end else if (responderSendCountReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_REQ;
        txLoadSource = TxSource_pointResponderCountReq;
      end else if (initiatorSendClearResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_RESP;
        txLoadSource = TxSource_pointInitiatorClearResp;
      end else if (responderSendClearReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_REQ;
        txLoadSource = TxSource_pointResponderClearReq;
      end else if (responderSendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_RESP;
        txLoadSource = TxSource_pointResponderStartResp;
      end else if (remoteStateReg == RemoteState_sendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_RESP;
        txLoadSource = TxSource_remoteOuterStartResp;
      end else if (initiatorSendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_REQ;
        txLoadSource = TxSource_pointInitiatorEndReq;
      end else if (initiatorSendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_REQ;
        txLoadSource = TxSource_pointInitiatorStartReq;
      end else if (localStateReg == LocalState_sendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_REQ;
        txLoadSource = TxSource_localOuterEndReq;
      end else if (localStateReg == LocalState_sendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_REQ;
        txLoadSource = TxSource_localOuterStartReq;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else if (!runningReg) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else begin
      if (txTransfer) begin
        sbTxValidReg  <= 1'b0;
        sbTxSourceReg <= TxSource_none;
      end
      if (!sbTxValidReg && txLoadValid) begin
        sbTxValidReg  <= 1'b1;
        sbTxDinReg    <= txLoadDin;
        sbTxSourceReg <= txLoadSource;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      localStateReg  <= LocalState_idle;
      remoteStateReg <= RemoteState_idle;
      runningReg     <= 1'b0;
      doneReg        <= 1'b0;
      trainErrorReg  <= 1'b0;
      prevStart      <= 1'b0;
      prevRxValid    <= 1'b0;
      remoteOuterEndPendingReg <= 1'b0;
    end else begin
      prevStart   <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        localStateReg  <= LocalState_sendStartReq;
        remoteStateReg <= RemoteState_waitStartReq;
        runningReg     <= 1'b1;
        doneReg        <= 1'b0;
        trainErrorReg  <= 1'b0;
        remoteOuterEndPendingReg <= 1'b0;
      end else if (runningReg) begin
        // End/Done may be received before the last remotely initiated point
        // test has completely retired.  Preserve it until the responder is
        // idle, then issue the outer response.
        if (receivedOuterEndReq)
          remoteOuterEndPendingReg <= 1'b1;

        unique case (localStateReg)
          LocalState_sendStartReq: begin
            if (localOuterStartReqSent)
              localStateReg <= LocalState_waitStartResp;
          end
          LocalState_waitStartResp: begin
            if (receivedOuterStartResp) begin
              if (PERFORM_LOCAL_TRAINING)
                localStateReg <= LocalState_startSweep;
              else
                localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_startSweep:
            localStateReg <= LocalState_waitSweep;
          LocalState_waitSweep: begin
            if (sweepTrainError) begin
              localStateReg <= LocalState_error;
              trainErrorReg <= 1'b1;
              runningReg    <= 1'b0;
            end else if (sweepDone) begin
              localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_sendEndReq: begin
            if (localOuterEndReqSent)
              localStateReg <= LocalState_waitEndResp;
          end
          LocalState_waitEndResp: begin
            if (receivedOuterEndResp)
              localStateReg <= LocalState_finish;
          end
          LocalState_finish: ;
          LocalState_error: ;
          default: localStateReg <= LocalState_idle;
        endcase

        unique case (remoteStateReg)
          RemoteState_waitStartReq: begin
            if (receivedOuterStartReq)
              remoteStateReg <= RemoteState_sendStartResp;
          end
          RemoteState_sendStartResp: begin
            if (remoteOuterStartRespSent)
              remoteStateReg <= RemoteState_active;
          end
          RemoteState_active: begin
            if ((receivedOuterEndReq || remoteOuterEndPendingReg) &&
                !responderBusy) begin
              remoteStateReg <= RemoteState_sendEndResp;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_sendEndResp: begin
            if (remoteOuterEndRespSent) begin
              remoteStateReg <= RemoteState_finish;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_finish: ;
          default: remoteStateReg <= RemoteState_idle;
        endcase

        if ((localStateReg == LocalState_finish) &&
            (remoteStateReg == RemoteState_finish)) begin
          runningReg <= 1'b0;
          doneReg    <= 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_DataVrefSweepEngine-sv"></a>

## [18] MBTrain_DataVrefSweepEngine.sv

```systemverilog
// FILE_INDEX: 18
// FILE_PATH : MBTrain_DataVrefSweepEngine.sv

// Parameterized linear receiver-Vref sweep for the UCIe Data lanes.
//
// One receiver-initiated point test is performed at each Vref code.  The
// per-lane result vector is retained, and every active lane independently
// selects the lower midpoint of its longest non-wrapping passing interval.
// All selected per-lane codes are then applied together and verified by one
// final point test.
`default_nettype none

module MBTrain_DataVrefSweepEngine #(
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output      logic busy,
  output      logic done,
  output      logic trainError,

  // During the linear sweep every active lane receives the same code.  During
  // final application, each lane receives its independently selected code.
  output      logic apply_rx_vref,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] rx_vref_codes,
  input  wire logic rx_vref_applied,

  output      logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [DATA_LANE_COUNT-1:0] point_test_pass,

  output      logic [3:0] state,
  output      logic [15:0] lastFailedLaneCount,
  output      logic [15:0] retryCount,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] finalVrefCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validLeftCodes,
  output      logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] validRightCodes
);
  typedef enum logic [3:0] {
    SweepState_idle             = 4'h0,
    SweepState_applySweepCode   = 4'h1,
    SweepState_startSweepPoint  = 4'h2,
    SweepState_waitSweepPoint   = 4'h3,
    SweepState_analyze          = 4'h4,
    SweepState_applyFinalCodes  = 4'h5,
    SweepState_startFinalPoint  = 4'h6,
    SweepState_waitFinalPoint   = 4'h7,
    SweepState_done             = 4'h8,
    SweepState_error            = 4'h9
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic [VREF_VALUE_COUNT-1:0]
    passBitmapReg [0:DATA_LANE_COUNT-1];
  (* keep = "true" *) logic [VREF_CODE_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    finalCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    leftCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0]
    rightCodeVectorReg;
  (* keep = "true" *) logic [15:0] failedLaneCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  // These combinational analysis arrays are assigned by one process only.
  integer runStartInt [0:DATA_LANE_COUNT-1];
  integer runLengthInt [0:DATA_LANE_COUNT-1];
  integer bestStartInt [0:DATA_LANE_COUNT-1];
  integer bestLengthInt [0:DATA_LANE_COUNT-1];
  integer scanLane;
  integer scanCode;
  logic allActiveLanesHaveWindow;
  logic allActiveLanesPassFinal;

  function automatic logic [15:0] count_failed_active_lanes(
    input logic [DATA_LANE_COUNT-1:0] pass_vector
  );
    integer count_lane;
    begin
      count_failed_active_lanes = 16'd0;
      for (count_lane = 0; count_lane < DATA_LANE_COUNT;
           count_lane = count_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[count_lane] && !pass_vector[count_lane])
          count_failed_active_lanes = count_failed_active_lanes + 16'd1;
      end
    end
  endfunction

  // Find each active lane's longest linear passing interval.  Strictly-greater
  // replacement preserves the lower-code interval when two windows tie and
  // deliberately does not join the first and last Vref codes.
  always_comb begin
    allActiveLanesHaveWindow = 1'b1;

    for (scanLane = 0; scanLane < DATA_LANE_COUNT;
         scanLane = scanLane + 1) begin
      runStartInt[scanLane]   = 0;
      runLengthInt[scanLane]  = 0;
      bestStartInt[scanLane]  = 0;
      bestLengthInt[scanLane] = 0;

      for (scanCode = 0; scanCode < VREF_VALUE_COUNT;
           scanCode = scanCode + 1) begin
        if (passBitmapReg[scanLane][scanCode]) begin
          if (runLengthInt[scanLane] == 0)
            runStartInt[scanLane] = scanCode;
          runLengthInt[scanLane] = runLengthInt[scanLane] + 1;
          if (runLengthInt[scanLane] > bestLengthInt[scanLane]) begin
            bestLengthInt[scanLane] = runLengthInt[scanLane];
            bestStartInt[scanLane]  = runStartInt[scanLane];
          end
        end else begin
          runLengthInt[scanLane] = 0;
        end
      end

      if (ACTIVE_DATA_LANE_MASK[scanLane] &&
          (bestLengthInt[scanLane] < MIN_PASSING_WINDOW_VALUES))
        allActiveLanesHaveWindow = 1'b0;
    end

    allActiveLanesPassFinal =
      ((point_test_pass & ACTIVE_DATA_LANE_MASK) == ACTIVE_DATA_LANE_MASK);
  end

  always_comb begin
    busy       = (stateReg != SweepState_idle) &&
                 (stateReg != SweepState_done) &&
                 (stateReg != SweepState_error);
    done       = (stateReg == SweepState_done);
    trainError = (stateReg == SweepState_error);

    state               = stateReg;
    lastFailedLaneCount = failedLaneCountReg;
    retryCount          = retryCountReg;
    finalVrefCodes      = finalCodeVectorReg;
    validLeftCodes      = leftCodeVectorReg;
    validRightCodes     = rightCodeVectorReg;

    apply_rx_vref = (stateReg == SweepState_applySweepCode) ||
                    (stateReg == SweepState_applyFinalCodes);
    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);

    rx_vref_codes = '0;
    if ((stateReg == SweepState_applyFinalCodes) ||
        (stateReg == SweepState_startFinalPoint) ||
        (stateReg == SweepState_waitFinalPoint) ||
        (stateReg == SweepState_done)) begin
      rx_vref_codes = finalCodeVectorReg;
    end else begin
      for (int unsigned output_lane = 0;
           output_lane < DATA_LANE_COUNT;
           output_lane = output_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[output_lane])
          rx_vref_codes[output_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] =
            currentCodeReg;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg            <= SweepState_idle;
      currentCodeReg      <= '0;
      finalCodeVectorReg  <= '0;
      leftCodeVectorReg   <= '0;
      rightCodeVectorReg  <= '0;
      failedLaneCountReg  <= 16'd0;
      retryCountReg       <= 16'd0;
      for (int unsigned reset_lane = 0;
           reset_lane < DATA_LANE_COUNT;
           reset_lane = reset_lane + 1)
        passBitmapReg[reset_lane] <= '0;
    end else begin
      if (start && ((stateReg == SweepState_idle) ||
                    (stateReg == SweepState_done) ||
                    (stateReg == SweepState_error))) begin
        stateReg           <= SweepState_applySweepCode;
        currentCodeReg     <= '0;
        finalCodeVectorReg <= '0;
        leftCodeVectorReg  <= '0;
        rightCodeVectorReg <= '0;
        failedLaneCountReg <= 16'd0;
        retryCountReg      <= 16'd0;
        for (int unsigned start_lane = 0;
             start_lane < DATA_LANE_COUNT;
             start_lane = start_lane + 1)
          passBitmapReg[start_lane] <= '0;
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
              for (int unsigned capture_lane = 0;
                   capture_lane < DATA_LANE_COUNT;
                   capture_lane = capture_lane + 1) begin
                passBitmapReg[capture_lane][currentCodeReg] <=
                  point_test_pass[capture_lane];
              end
              failedLaneCountReg <= failedLaneCountReg +
                                    count_failed_active_lanes(point_test_pass);

              if (currentCodeReg == (VREF_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          SweepState_analyze: begin
            if (allActiveLanesHaveWindow) begin
              for (int unsigned select_lane = 0;
                   select_lane < DATA_LANE_COUNT;
                   select_lane = select_lane + 1) begin
                if (ACTIVE_DATA_LANE_MASK[select_lane]) begin
                  finalCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       ((bestLengthInt[select_lane] - 1) / 2);
                  leftCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane];
                  rightCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       bestLengthInt[select_lane] - 1;
                end else begin
                  finalCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                  leftCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                  rightCodeVectorReg[
                    select_lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH
                  ] <= '0;
                end
              end
              stateReg <= SweepState_applyFinalCodes;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg       <= retryCountReg + 16'd1;
              currentCodeReg      <= '0;
              failedLaneCountReg  <= 16'd0;
              for (int unsigned retry_lane = 0;
                   retry_lane < DATA_LANE_COUNT;
                   retry_lane = retry_lane + 1)
                passBitmapReg[retry_lane] <= '0;
              stateReg <= SweepState_applySweepCode;
            end else begin
              stateReg <= SweepState_error;
            end
          end

          SweepState_applyFinalCodes: begin
            if (rx_vref_applied)
              stateReg <= SweepState_startFinalPoint;
          end

          SweepState_startFinalPoint:
            stateReg <= SweepState_waitFinalPoint;

          SweepState_waitFinalPoint: begin
            if (point_test_done) begin
              if (allActiveLanesPassFinal) begin
                stateReg <= SweepState_done;
              end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
                retryCountReg       <= retryCountReg + 16'd1;
                currentCodeReg      <= '0;
                failedLaneCountReg  <= 16'd0;
                for (int unsigned verify_retry_lane = 0;
                     verify_retry_lane < DATA_LANE_COUNT;
                     verify_retry_lane = verify_retry_lane + 1)
                  passBitmapReg[verify_retry_lane] <= '0;
                stateReg <= SweepState_applySweepCode;
              end else begin
                failedLaneCountReg <= failedLaneCountReg +
                                      count_failed_active_lanes(point_test_pass);
                stateReg <= SweepState_error;
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
    if (DATA_LANE_COUNT < 1)
      $error("DATA_LANE_COUNT must be at least 1");
    if (ACTIVE_DATA_LANE_MASK == '0)
      $error("ACTIVE_DATA_LANE_MASK must enable at least one lane");
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

```

<a id="MBTrain_LinkSpeed-sv"></a>

## [19] MBTrain_LinkSpeed.sv

```systemverilog
// FILE_INDEX: 19
// FILE_PATH : MBTrain_LinkSpeed.sv

// SystemVerilog translation of MBTrain_LinkSpeed.scala.
`default_nettype none

module MBTrain_LinkSpeed #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  output var logic         flagToLtsm_phyInRetrain,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic         flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic         flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]  flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic         flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]  flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic         flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]   flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]   flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]   flagToAnalog_d2cReceiver_dataPattern,
  output var logic         flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  output var logic [11:0]  substate,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LinkSpeedSenderState_idle = 4'h0,
    LinkSpeedSenderState_sendStartReq = 4'h1,
    LinkSpeedSenderState_waitStartResp = 4'h2,
    LinkSpeedSenderState_startPointTest = 4'h3,
    LinkSpeedSenderState_waitPointTest = 4'h4,
    LinkSpeedSenderState_checkErrorLog = 4'h5,
    LinkSpeedSenderState_sendErrorReq = 4'h6,
    LinkSpeedSenderState_sendDoneReq = 4'h7,
    LinkSpeedSenderState_waitDoneResp = 4'h8,
    LinkSpeedSenderState_finish = 4'h9
  } LinkSpeedSenderState_t;

  typedef enum logic [2:0] {
    LinkSpeedReceiverState_idle = 3'h0,
    LinkSpeedReceiverState_waitStartReq = 3'h1,
    LinkSpeedReceiverState_sendStartResp = 3'h2,
    LinkSpeedReceiverState_runPointTest = 3'h3,
    LinkSpeedReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    LinkSpeedReceiverState_sendDoneResp = 3'h5,
    LinkSpeedReceiverState_finish = 3'h6
  } LinkSpeedReceiverState_t;

  (* keep = "true" *) LinkSpeedSenderState_t senderStateReg;
  (* keep = "true" *) LinkSpeedReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedStartResp;
  (* keep = "true" *) logic flagReceivedDoneResp;
  (* keep = "true" *) logic flagReceivedStartReq;
  (* keep = "true" *) logic flagReceivedDoneReq;

  (* keep = "true" *) logic d2cSender_receivedPointTestStartResp;
  (* keep = "true" *) logic d2cSender_receivedLfsrClearResp;
  (* keep = "true" *) logic d2cSender_receivedResultsResp;
  (* keep = "true" *) logic d2cSender_receivedEndPointTestResp;

  (* keep = "true" *) logic d2cReceiver_receivedPointTestStartReq;
  (* keep = "true" *) logic d2cReceiver_receivedLfsrClearReq;
  (* keep = "true" *) logic d2cReceiver_receivedResultsReq;
  (* keep = "true" *) logic d2cReceiver_receivedEndPointTestReq;

  (* keep = "true" *) logic flagSentStartReq;
  (* keep = "true" *) logic flagSentDoneReq;
  (* keep = "true" *) logic flagSentStartResp;
  (* keep = "true" *) logic flagSentDoneResp;

  (* keep = "true" *) logic d2cSender_sentPointTestStartReq;
  (* keep = "true" *) logic d2cSender_sentLfsrClearReq;
  (* keep = "true" *) logic d2cSender_sentResultsReq;
  (* keep = "true" *) logic d2cSender_sentEndPointTestReq;

  (* keep = "true" *) logic d2cReceiver_sentPointTestStartResp;
  (* keep = "true" *) logic d2cReceiver_sentLfsrClearResp;
  (* keep = "true" *) logic d2cReceiver_sentResultsResp;
  (* keep = "true" *) logic d2cReceiver_sentEndPointTestResp;

  (* keep = "true" *) logic [15:0] logErrorCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [15:0] d2cReceiver_loggedLaneComparisonSuccessful;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;

  (* keep = "true" *) logic flagReceivedErrorReq;
  (* keep = "true" *) logic flagSentErrorReq;
  (* keep = "true" *) logic phyInRetrainReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  logic d2cSender_start;
  logic d2cReceiver_start;
  logic senderSentStartPulse;
  logic senderSentLfsrPulse;
  logic senderSentResultsPulse;
  logic senderSentEndPulse;
  logic flagToAnalog_d2cReceiver_configureAnalogPulse;

  logic selectSentDoneResp;
  logic selectReceiverEndResp;
  logic selectReceiverResultsResp;
  logic selectReceiverLfsrResp;
  logic selectReceiverStartResp;
  logic selectSentStartResp;
  logic selectSentDoneReq;
  logic selectSenderEndReq;
  logic selectSenderResultsReq;
  logic selectSenderLfsrReq;
  logic selectSenderStartReq;
  logic selectSentStartReq;
  logic selectSentErrorReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_LINKSPEED_START_REQ =
    msgMbtrainLinkSpeedStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_START_RESP =
    msgMbtrainLinkSpeedStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DONE_REQ =
    msgMbtrainLinkSpeedDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DONE_RESP =
    msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_ERROR_REQ =
    msgMbtrainLinkSpeedErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      16'd0, 1'b1, 16'd1, 16'd0, 16'd4096,
      1'b0, 4'd0, 3'd0, 3'd0
    );
  wire [127:0] START_POINT_TEST_RESP =
    msgMbtrainStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_REQ =
    msgMbtrainTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_RESP_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);
  wire [127:0] END_POINT_TEST_REQ =
    msgMbtrainEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_TEST_RESP =
    msgMbtrainEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire isStartPointTestReq =
    ((sb_rx_dout[63:0] & 64'h000000FFFFFFFFFF) ==
     (START_POINT_TEST_REQ[63:0] & 64'h000000FFFFFFFFFF));

  // Named combinational values retained from the Chisel source.
  wire laneComparisonValid = sb_rx_dout[45];
  wire cumulativeLanePass  = sb_rx_dout[44];
  wire [15:0] txInitD2CResultsMsgInfo = {
    10'b0,
    1'b1,
    (&d2cReceiver_loggedLaneComparisonSuccessful),
    4'b0
  };
  wire [63:0] txInitD2CResultsPayload = {
    48'b0,
    d2cReceiver_loggedLaneComparisonSuccessful
  };

  logic d2cSender_sendStartTxInitD2CPointTestReq;
  logic d2cSender_sendLfsrClearErrorReq;
  logic d2cSender_sendTxInitD2CResultsReq;
  logic d2cSender_sendEndTxInitD2CPointTestReq;
  logic d2cSender_sendDefinedPattern;
  logic d2cSender_resetLocalScrambler;
  logic d2cSender_busy;
  logic d2cSender_done;
  logic [3:0] d2cSender_state;

  logic d2cReceiver_sendStartTxInitD2CPointTestResp;
  logic d2cReceiver_sendLfsrClearErrorResp;
  logic d2cReceiver_sendTxInitD2CResultsResp;
  logic d2cReceiver_sendEndTxInitD2CPointTestResp;
  logic d2cReceiver_resetLocalRxScrambler;
  logic d2cReceiver_busy;
  logic d2cReceiver_done;
  logic [3:0] d2cReceiver_state;

  TxInitD2CPointTestSenderFSM d2cSender (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cSender_start),
    .receivedStartTxInitD2CPointTestResp(d2cSender_receivedPointTestStartResp),
    .receivedLfsrClearErrorResp(d2cSender_receivedLfsrClearResp),
    .receivedTxInitD2CResultsResp(d2cSender_receivedResultsResp),
    .receivedEndTxInitD2CPointTestResp(d2cSender_receivedEndPointTestResp),
    .sentStartTxInitD2CPointTestReq(senderSentStartPulse),
    .sentLfsrClearErrorReq(senderSentLfsrPulse),
    .sentTxInitD2CResultsReq(senderSentResultsPulse),
    .sentEndTxInitD2CPointTestReq(senderSentEndPulse),
    .sentDefinedPattern(flagFromAnalog_d2cSender_lfsrPatternSent),
    .sendStartTxInitD2CPointTestReq(d2cSender_sendStartTxInitD2CPointTestReq),
    .sendLfsrClearErrorReq(d2cSender_sendLfsrClearErrorReq),
    .sendTxInitD2CResultsReq(d2cSender_sendTxInitD2CResultsReq),
    .sendEndTxInitD2CPointTestReq(d2cSender_sendEndTxInitD2CPointTestReq),
    .sendDefinedPattern(d2cSender_sendDefinedPattern),
    .resetLocalScrambler(d2cSender_resetLocalScrambler),
    .busy(d2cSender_busy),
    .done(d2cSender_done),
    .state(d2cSender_state)
  );

  TxInitD2CPointTestReceiverFSM d2cReceiver (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cReceiver_start),
    .receivedStartTxInitD2CPointTestReq(d2cReceiver_receivedPointTestStartReq),
    .receivedLfsrClearErrorReq(d2cReceiver_receivedLfsrClearReq),
    .receivedTxInitD2CResultsReq(d2cReceiver_receivedResultsReq),
    .receivedEndTxInitD2CPointTestReq(d2cReceiver_receivedEndPointTestReq),
    .sentStartTxInitD2CPointTestResp(d2cReceiver_sentPointTestStartResp),
    .sentLfsrClearErrorResp(d2cReceiver_sentLfsrClearResp),
    .sentTxInitD2CResultsResp(d2cReceiver_sentResultsResp),
    .sentEndTxInitD2CPointTestResp(d2cReceiver_sentEndPointTestResp),
    .sendStartTxInitD2CPointTestResp(d2cReceiver_sendStartTxInitD2CPointTestResp),
    .sendLfsrClearErrorResp(d2cReceiver_sendLfsrClearErrorResp),
    .sendTxInitD2CResultsResp(d2cReceiver_sendTxInitD2CResultsResp),
    .sendEndTxInitD2CPointTestResp(d2cReceiver_sendEndTxInitD2CPointTestResp),
    .resetLocalRxScrambler(d2cReceiver_resetLocalRxScrambler),
    .busy(d2cReceiver_busy),
    .done(d2cReceiver_done),
    .state(d2cReceiver_state)
  );

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    substate = {senderStateReg[3:0], d2cSender_state, d2cReceiver_state};
    lastErrorCount = logErrorCountReg;
    retryCount = retryCountReg;
    flagToLtsm_phyInRetrain = phyInRetrainReg;

    flagToAnalog_d2cSender_sendLfsrPattern = running && d2cSender_sendDefinedPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = flagToAnalog_d2cReceiver_configureAnalogPulse;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = d2c_maximumComparisonErrorThresholdReg;
    flagToAnalog_d2cReceiver_comparisonMode = d2c_comparisonModeReg;
    flagToAnalog_d2cReceiver_iterationCountSettings = d2c_iterationCountSettingsReg;
    flagToAnalog_d2cReceiver_idleCountSettings = d2c_idleCountSettingsReg;
    flagToAnalog_d2cReceiver_burstCountSettings = d2c_burstCountSettingsReg;
    flagToAnalog_d2cReceiver_patternMode = d2c_patternModeReg;
    flagToAnalog_d2cReceiver_clockPhaseControl = d2c_clockPhaseControlReg;
    flagToAnalog_d2cReceiver_validPattern = d2c_validPatternReg;
    flagToAnalog_d2cReceiver_dataPattern = d2c_dataPatternReg;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = running && d2cReceiver_resetLocalRxScrambler;
  end

  // Combinational local pulses and the source's pulse-style registered TX selector.
  always_comb begin
    d2cSender_start = 1'b0;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    flagToAnalog_d2cReceiver_configureAnalogPulse = running && rxValidRisingEdge && isStartPointTestReq;

    nextSbTxValid = 1'b0;
    nextSbTxDin = 128'b0;
    selectSentDoneResp = 1'b0;
    selectReceiverEndResp = 1'b0;
    selectReceiverResultsResp = 1'b0;
    selectReceiverLfsrResp = 1'b0;
    selectReceiverStartResp = 1'b0;
    selectSentStartResp = 1'b0;
    selectSentDoneReq = 1'b0;
    selectSenderEndReq = 1'b0;
    selectSenderResultsReq = 1'b0;
    selectSenderLfsrReq = 1'b0;
    selectSenderStartReq = 1'b0;
    selectSentStartReq = 1'b0;
    selectSentErrorReq = 1'b0;

    if (!startPulse) begin
      unique case (senderStateReg)
        LinkSpeedSenderState_startPointTest: d2cSender_start = 1'b1;
        default: ;
      endcase
      unique case (receiverStateReg)
        LinkSpeedReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        LinkSpeedReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == LinkSpeedReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_RESP;
        nextSbTxValid = 1'b1;
        selectSentDoneResp = 1'b1;
      end
      else if (d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverEndResp = 1'b1;
      end
      else if (d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          txInitD2CResultsMsgInfo,
          txInitD2CResultsPayload
        );
        nextSbTxValid = 1'b1;
        selectReceiverResultsResp = 1'b1;
      end
      else if (d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverLfsrResp = 1'b1;
      end
      else if (d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverStartResp = 1'b1;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end
    else if ((senderStateReg == LinkSpeedSenderState_sendErrorReq) && !flagSentErrorReq) begin
      nextSbTxDin = MBTRAIN_LINKSPEED_ERROR_REQ;
      nextSbTxValid = 1'b1;
      selectSentErrorReq = 1'b1;
    end
      else if ((senderStateReg == LinkSpeedSenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= LinkSpeedSenderState_idle;
      receiverStateReg <= LinkSpeedReceiverState_idle;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedStartResp <= 1'b0;
      flagReceivedDoneResp <= 1'b0;
      flagReceivedStartReq <= 1'b0;
      flagReceivedDoneReq <= 1'b0;
      d2cSender_receivedPointTestStartResp <= 1'b0;
      d2cSender_receivedLfsrClearResp <= 1'b0;
      d2cSender_receivedResultsResp <= 1'b0;
      d2cSender_receivedEndPointTestResp <= 1'b0;
      d2cReceiver_receivedPointTestStartReq <= 1'b0;
      d2cReceiver_receivedLfsrClearReq <= 1'b0;
      d2cReceiver_receivedResultsReq <= 1'b0;
      d2cReceiver_receivedEndPointTestReq <= 1'b0;
      flagSentStartReq <= 1'b0;
      flagSentDoneReq <= 1'b0;
      flagSentStartResp <= 1'b0;
      flagSentDoneResp <= 1'b0;
      d2cSender_sentPointTestStartReq <= 1'b0;
      d2cSender_sentLfsrClearReq <= 1'b0;
      d2cSender_sentResultsReq <= 1'b0;
      d2cSender_sentEndPointTestReq <= 1'b0;
      d2cReceiver_sentPointTestStartResp <= 1'b0;
      d2cReceiver_sentLfsrClearResp <= 1'b0;
      d2cReceiver_sentResultsResp <= 1'b0;
      d2cReceiver_sentEndPointTestResp <= 1'b0;
      logErrorCountReg <= 16'b0;
      retryCountReg <= 16'b0;
      d2cReceiver_loggedLaneComparisonSuccessful <= 16'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;
      flagReceivedErrorReq <= 1'b0;
      flagSentErrorReq <= 1'b0;
      phyInRetrainReg <= 1'b0;
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        senderStateReg <= LinkSpeedSenderState_sendStartReq;
        receiverStateReg <= LinkSpeedReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
      flagReceivedErrorReq <= 1'b0;
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cReceiver_receivedPointTestStartReq <= 1'b0;
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        flagSentStartReq <= 1'b0;
        flagSentDoneReq <= 1'b0;
        flagSentStartResp <= 1'b0;
        flagSentDoneResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
        logErrorCountReg <= 16'b0;
        retryCountReg <= 16'b0;
      d2cReceiver_loggedLaneComparisonSuccessful <= 16'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_LINKSPEED_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
      else if (sb_rx_dout == MBTRAIN_LINKSPEED_ERROR_REQ) begin
        flagReceivedErrorReq <= 1'b1;
      end
        else if (isStartPointTestReq) begin
          d2c_maximumComparisonErrorThresholdReg <= sb_rx_dout[55:40];
          d2c_comparisonModeReg <= sb_rx_dout[123];
          d2c_iterationCountSettingsReg <= sb_rx_dout[122:107];
          d2c_idleCountSettingsReg <= sb_rx_dout[106:91];
          d2c_burstCountSettingsReg <= sb_rx_dout[90:75];
          d2c_patternModeReg <= sb_rx_dout[74];
          d2c_clockPhaseControlReg <= sb_rx_dout[73:70];
          d2c_validPatternReg <= sb_rx_dout[69:67];
          d2c_dataPatternReg <= sb_rx_dout[66:64];
          d2cReceiver_receivedPointTestStartReq <= 1'b1;
        end
        else if (sb_rx_dout == START_POINT_TEST_RESP)
          d2cSender_receivedPointTestStartResp <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_REQ)
          d2cReceiver_receivedLfsrClearReq <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_RESP)
          d2cSender_receivedLfsrClearResp <= 1'b1;
        else if (sb_rx_dout == TX_INIT_RESULTS_REQ) begin
        d2cReceiver_loggedLaneComparisonSuccessful <= flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
        d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (((sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
         (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]))) begin
        d2cSender_receivedResultsResp <= 1'b1;
        logErrorCountReg <= (laneComparisonValid && cumulativeLanePass) ? 16'd0 : 16'd1;
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (d2cSender_start) begin
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        logErrorCountReg <= 16'b0;
      end

      if (d2cReceiver_sentPointTestStartResp)
        d2cReceiver_receivedPointTestStartReq <= 1'b0;

      if (d2cReceiver_start) begin
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
      end

      if (selectSentDoneResp)
        flagSentDoneResp <= 1'b1;
      if (selectReceiverEndResp)
        d2cReceiver_sentEndPointTestResp <= 1'b1;
      if (selectReceiverResultsResp)
        d2cReceiver_sentResultsResp <= 1'b1;
      if (selectReceiverLfsrResp)
        d2cReceiver_sentLfsrClearResp <= 1'b1;
      if (selectReceiverStartResp)
        d2cReceiver_sentPointTestStartResp <= 1'b1;
      if (selectSentStartResp)
        flagSentStartResp <= 1'b1;
      if (selectSentErrorReq)
        flagSentErrorReq <= 1'b1;
      if (selectSentDoneReq)
        flagSentDoneReq <= 1'b1;
      if (selectSenderEndReq)
        d2cSender_sentEndPointTestReq <= 1'b1;
      if (selectSenderResultsReq)
        d2cSender_sentResultsReq <= 1'b1;
      if (selectSenderLfsrReq)
        d2cSender_sentLfsrClearReq <= 1'b1;
      if (selectSenderStartReq)
        d2cSender_sentPointTestStartReq <= 1'b1;
      if (selectSentStartReq)
        flagSentStartReq <= 1'b1;

      if (!startPulse) begin
        unique case (senderStateReg)
          LinkSpeedSenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= LinkSpeedSenderState_waitStartResp;
          end
          LinkSpeedSenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= LinkSpeedSenderState_startPointTest;
          end
          LinkSpeedSenderState_startPointTest:
            senderStateReg <= LinkSpeedSenderState_waitPointTest;
          LinkSpeedSenderState_waitPointTest: begin
            if (d2cSender_done)
              senderStateReg <= LinkSpeedSenderState_checkErrorLog;
          end
          LinkSpeedSenderState_checkErrorLog: begin
            // Source currently forces numberOfErrors to zero until PHY result wiring is completed.
            logErrorCountReg <= 16'd0;
            if (16'd0 > 16'd0) begin
              phyInRetrainReg <= 1'b1;
              senderStateReg <= LinkSpeedSenderState_sendErrorReq;
            end else begin
              senderStateReg <= LinkSpeedSenderState_sendDoneReq;
            end
          end
          LinkSpeedSenderState_sendErrorReq: begin
            if (flagSentErrorReq)
              senderStateReg <= LinkSpeedSenderState_finish;
          end
          LinkSpeedSenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= LinkSpeedSenderState_waitDoneResp;
          end
          LinkSpeedSenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= LinkSpeedSenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          LinkSpeedReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= LinkSpeedReceiverState_sendStartResp;
          end
          LinkSpeedReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= LinkSpeedReceiverState_runPointTest;
          end
          LinkSpeedReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= LinkSpeedReceiverState_waitDoneReqOrPointTestReq;
          end
          LinkSpeedReceiverState_waitDoneReqOrPointTestReq: begin
                        if (flagReceivedErrorReq) begin
              // Source TODO: receiver-side LINKSPEED error-resolution flow is not yet implemented.
              receiverStateReg <= receiverStateReg;
            end else if (flagReceivedDoneReq)
              receiverStateReg <= LinkSpeedReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= LinkSpeedReceiverState_runPointTest;
          end
          LinkSpeedReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= LinkSpeedReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == LinkSpeedSenderState_finish) &&
            (receiverStateReg == LinkSpeedReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_RxClkCalFSM-sv"></a>

## [20] MBTrain_RxClkCalFSM.sv

```systemverilog
// FILE_INDEX: 20
// FILE_PATH : MBTrain_RxClkCalFSM.sv

// SystemVerilog translation of MBTrain_RxClkCalFSM.scala.
`default_nettype none

module MBTrainRxClkCalFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_rxClkCalDoCalibration,
  input wire logic         flagFromAnalog_rxClkCalDone,
  output var logic         flagToAnalog_rxClkCalSendClockTrack,
  output var logic [7:0]   substate
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [2:0] {
    RxClkCalSenderState_sendStartReq      = 3'd0,
    RxClkCalSenderState_waitStartResp     = 3'd1,
    RxClkCalSenderState_startAnalogCal    = 3'd2,
    RxClkCalSenderState_waitAnalogCalDone = 3'd3,
    RxClkCalSenderState_sendDoneReq       = 3'd4,
    RxClkCalSenderState_waitDoneResp      = 3'd5,
    RxClkCalSenderState_finish            = 3'd6
  } RxClkCalSenderState_t;

  typedef enum logic [2:0] {
    RxClkCalReceiverState_waitStartReq    = 3'd0,
    RxClkCalReceiverState_startClockTrack = 3'd1,
    RxClkCalReceiverState_sendStartResp   = 3'd2,
    RxClkCalReceiverState_waitDoneReq     = 3'd3,
    RxClkCalReceiverState_sendDoneResp    = 3'd4,
    RxClkCalReceiverState_finish          = 3'd5
  } RxClkCalReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedRxClkCalStartReq;
  (* keep = "true" *) logic flagReceivedRxClkCalStartResp;
  (* keep = "true" *) logic flagReceivedRxClkCalDoneReq;
  (* keep = "true" *) logic flagReceivedRxClkCalDoneResp;
  (* keep = "true" *) logic flagSentRxClkCalStartReq;
  (* keep = "true" *) logic flagSentRxClkCalStartResp;
  (* keep = "true" *) logic flagSentRxClkCalDoneReq;
  (* keep = "true" *) logic flagSentRxClkCalDoneResp;

  (* keep = "true" *) RxClkCalSenderState_t rxClkCalSenderStateReg;
  (* keep = "true" *) RxClkCalReceiverState_t rxClkCalReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_RXCLKCAL_START_REQ  = msgMbtrainRxClkCalStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_START_RESP = msgMbtrainRxClkCalStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_DONE_REQ   = msgMbtrainRxClkCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_DONE_RESP  = msgMbtrainRxClkCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp) && !flagSentRxClkCalDoneResp) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendDoneReq) && !flagSentRxClkCalDoneReq) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_DONE_REQ;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) && !flagSentRxClkCalStartResp) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_START_RESP;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendStartReq) && !flagSentRxClkCalStartReq) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_START_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;

    // Chisel assigned a 10-bit Cat into an 8-bit output. Preserve the low 8 bits.
    substate = {2'b0, rxClkCalReceiverStateReg, rxClkCalSenderStateReg};

    flagToAnalog_rxClkCalDoCalibration = running &&
      ((rxClkCalSenderStateReg == RxClkCalSenderState_startAnalogCal) ||
       (rxClkCalSenderStateReg == RxClkCalSenderState_waitAnalogCalDone));

    flagToAnalog_rxClkCalSendClockTrack = running &&
      ((rxClkCalReceiverStateReg == RxClkCalReceiverState_startClockTrack) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_waitDoneReq) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp));
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedRxClkCalStartReq <= 1'b0;
      flagReceivedRxClkCalStartResp <= 1'b0;
      flagReceivedRxClkCalDoneReq <= 1'b0;
      flagReceivedRxClkCalDoneResp <= 1'b0;
      flagSentRxClkCalStartReq <= 1'b0;
      flagSentRxClkCalStartResp <= 1'b0;
      flagSentRxClkCalDoneReq <= 1'b0;
      flagSentRxClkCalDoneResp <= 1'b0;
      rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
      rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedRxClkCalStartReq <= 1'b0;
        flagReceivedRxClkCalStartResp <= 1'b0;
        flagReceivedRxClkCalDoneReq <= 1'b0;
        flagReceivedRxClkCalDoneResp <= 1'b0;
        flagSentRxClkCalStartReq <= 1'b0;
        flagSentRxClkCalStartResp <= 1'b0;
        flagSentRxClkCalDoneReq <= 1'b0;
        flagSentRxClkCalDoneResp <= 1'b0;
        rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
        rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_START_REQ)
          flagReceivedRxClkCalStartReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_START_RESP)
          flagReceivedRxClkCalStartResp <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_DONE_REQ)
          flagReceivedRxClkCalDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_DONE_RESP)
          flagReceivedRxClkCalDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp) && !flagSentRxClkCalDoneResp)
          flagSentRxClkCalDoneResp <= 1'b1;
        else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendDoneReq) && !flagSentRxClkCalDoneReq)
          flagSentRxClkCalDoneReq <= 1'b1;
        else if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) && !flagSentRxClkCalStartResp)
          flagSentRxClkCalStartResp <= 1'b1;
        else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendStartReq) && !flagSentRxClkCalStartReq)
          flagSentRxClkCalStartReq <= 1'b1;
      end

      unique case (rxClkCalSenderStateReg)
        RxClkCalSenderState_sendStartReq:
          if (flagSentRxClkCalStartReq) rxClkCalSenderStateReg <= RxClkCalSenderState_waitStartResp;
        RxClkCalSenderState_waitStartResp:
          if (flagReceivedRxClkCalStartResp) rxClkCalSenderStateReg <= RxClkCalSenderState_startAnalogCal;
        RxClkCalSenderState_startAnalogCal:
          rxClkCalSenderStateReg <= RxClkCalSenderState_waitAnalogCalDone;
        RxClkCalSenderState_waitAnalogCalDone:
          if (flagFromAnalog_rxClkCalDone) rxClkCalSenderStateReg <= RxClkCalSenderState_sendDoneReq;
        RxClkCalSenderState_sendDoneReq:
          if (flagSentRxClkCalDoneReq) rxClkCalSenderStateReg <= RxClkCalSenderState_waitDoneResp;
        RxClkCalSenderState_waitDoneResp:
          if (flagReceivedRxClkCalDoneResp) rxClkCalSenderStateReg <= RxClkCalSenderState_finish;
        RxClkCalSenderState_finish:
          rxClkCalSenderStateReg <= RxClkCalSenderState_finish;
        default: rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
      endcase

      unique case (rxClkCalReceiverStateReg)
        RxClkCalReceiverState_waitStartReq:
          if (flagReceivedRxClkCalStartReq) rxClkCalReceiverStateReg <= RxClkCalReceiverState_startClockTrack;
        RxClkCalReceiverState_startClockTrack:
          rxClkCalReceiverStateReg <= RxClkCalReceiverState_sendStartResp;
        RxClkCalReceiverState_sendStartResp:
          if (flagSentRxClkCalStartResp) rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitDoneReq;
        RxClkCalReceiverState_waitDoneReq:
          if (flagReceivedRxClkCalDoneReq) rxClkCalReceiverStateReg <= RxClkCalReceiverState_sendDoneResp;
        RxClkCalReceiverState_sendDoneResp:
          if (flagSentRxClkCalDoneResp) rxClkCalReceiverStateReg <= RxClkCalReceiverState_finish;
        RxClkCalReceiverState_finish:
          rxClkCalReceiverStateReg <= RxClkCalReceiverState_finish;
        default: rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
      endcase

      if (running &&
          (rxClkCalSenderStateReg == RxClkCalSenderState_finish) &&
          (rxClkCalReceiverStateReg == RxClkCalReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_RxDeskewFSM-sv"></a>

## [21] MBTrain_RxDeskewFSM.sv

```systemverilog
// FILE_INDEX: 21
// FILE_PATH : MBTrain_RxDeskewFSM.sv

// UCIe 2.0 MBTRAIN.RXDESKEW implementation.
//
// Each die concurrently performs two roles:
//   1. Receiver initiator: optionally sweep local per-lane RX deskew codes and
//      run one receiver-initiated D2C point test at every code.
//   2. Transmitter responder: serve the partner receiver's point tests by
//      transmitting the 4096-UI continuous LFSR pattern with functional Valid
//      framing.
//
// The RX delay-control vector intentionally mirrors the project's TX deskew
// control convention: one unsigned implementation-defined code per Data lane,
// an apply request, and an applied acknowledgement.
`default_nettype none

module MBTrainRxDeskewFSM #(
  parameter bit sbFeatureExtension =
    LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing =
    LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed =
    LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter bit performRxDeskew =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE,
  parameter int unsigned dataLaneCount = 16,
  parameter logic [dataLaneCount-1:0] activeDataLaneMask =
    {dataLaneCount{1'b1}},
  parameter int unsigned rxDeskewCodeWidth =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH,
  parameter int unsigned rxDeskewValueCount =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
  parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES
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

  // Local receiver controls: these are the RX lane delays being optimized.
  output      logic                         flagToAnalog_rxDeskewApplyRxLaneDeskew,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] flagToAnalog_rxDeskewRxLaneDeskewCodes,
  input  wire logic                         flagFromAnalog_rxDeskewRxLaneDeskewApplied,
  output      logic                         flagToAnalog_rxDeskewConfigureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_rxDeskewMaximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_rxDeskewComparisonMode,
  output      logic [15:0]                  flagToAnalog_rxDeskewIterationCountSettings,
  output      logic [15:0]                  flagToAnalog_rxDeskewIdleCountSettings,
  output      logic [15:0]                  flagToAnalog_rxDeskewBurstCountSettings,
  output      logic                         flagToAnalog_rxDeskewPatternMode,
  output      logic [3:0]                   flagToAnalog_rxDeskewClockPhaseControl,
  output      logic [2:0]                   flagToAnalog_rxDeskewValidPattern,
  output      logic [2:0]                   flagToAnalog_rxDeskewDataPattern,
  output      logic                         flagToAnalog_rxDeskewClearComparisonErrors,
  input  wire logic [dataLaneCount-1:0] flagFromAnalog_rxDeskewDetectedDataPattern,

  // Local transmitter controls used while serving the opposite receiver.
  output      logic                         flagToAnalog_rxDeskewSendLfsrPattern,
  input  wire logic                         flagFromAnalog_rxDeskewLfsrPatternSent,
  output      logic                         flagToAnalog_rxDeskewResetLocalTxScrambler,

  output      logic [11:0]                  substate,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] selectedRxDeskewCodes,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] validWindowLeftCodes,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] validWindowRightCodes
);
  import SidebandMsgGenerator_pkg::*;

  logic unusedConfiguration;
  assign unusedConfiguration = sbFeatureExtension ^ ucieA ^ moduleID[0] ^
                               clkPhase ^ clkMode ^ voltageSwing[0] ^
                               maxLinkSpeed[0];

  typedef enum logic [3:0] {
    LocalState_idle          = 4'h0,
    LocalState_sendStartReq  = 4'h1,
    LocalState_waitStartResp = 4'h2,
    LocalState_startSweep    = 4'h3,
    LocalState_waitSweep     = 4'h4,
    LocalState_sendEndReq    = 4'h5,
    LocalState_waitEndResp   = 4'h6,
    LocalState_finish        = 4'h7,
    LocalState_error         = 4'h8
  } LocalState_t;

  typedef enum logic [2:0] {
    RemoteState_idle          = 3'h0,
    RemoteState_waitStartReq  = 3'h1,
    RemoteState_sendStartResp = 3'h2,
    RemoteState_active        = 3'h3,
    RemoteState_sendEndResp   = 3'h4,
    RemoteState_finish        = 3'h5
  } RemoteState_t;

  typedef enum logic [4:0] {
    TxSource_none                    = 5'd0,
    TxSource_remoteOuterEndResp      = 5'd1,
    TxSource_pointResponderEndResp   = 5'd2,
    TxSource_pointInitiatorCountResp = 5'd3,
    TxSource_pointResponderCountReq  = 5'd4,
    TxSource_pointInitiatorClearResp = 5'd5,
    TxSource_pointResponderClearReq  = 5'd6,
    TxSource_pointResponderStartResp = 5'd7,
    TxSource_remoteOuterStartResp    = 5'd8,
    TxSource_pointInitiatorEndReq    = 5'd9,
    TxSource_pointInitiatorStartReq  = 5'd10,
    TxSource_localOuterEndReq        = 5'd11,
    TxSource_localOuterStartReq      = 5'd12
  } TxSource_t;

  (* keep = "true" *) LocalState_t localStateReg;
  (* keep = "true" *) RemoteState_t remoteStateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  // Latch the peer's outer End/Done request when it arrives while the local
  // transmitter responder is still completing its final point test.  Without
  // this latch, an asymmetric optional RXDESKEW configuration can lose the
  // one-cycle sideband request and deadlock.
  (* keep = "true" *) logic remoteOuterEndPendingReg;

  (* keep = "true" *) logic sbTxValidReg;
  (* keep = "true" *) logic [127:0] sbTxDinReg;
  (* keep = "true" *) TxSource_t sbTxSourceReg;
  logic txLoadValid;
  logic [127:0] txLoadDin;
  TxSource_t txLoadSource;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire txTransfer = sbTxValidReg && sb_tx_ready;

  wire [127:0] OUTER_START_REQ =
    msgMbtrainRxDeskewStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_START_RESP =
    msgMbtrainRxDeskewStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_REQ =
    msgMbtrainRxDeskewEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_RESP =
    msgMbtrainRxDeskewEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // Continuous Data-lane LFSR training: 4096 UI accompanied by the
  // functional Valid framing.  Track remains low while this state is active.
  wire [127:0] RXINIT_START_REQ =
    msgMbtrainDataVrefStartRxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      rxDeskewMaximumComparisonErrorThreshold,
      1'b0,       // per-lane comparison
      16'd1,      // continuous-mode convention
      16'd0,      // no idle UI
      16'd4096,   // 4K UI continuous LFSR burst
      1'b0,       // continuous pattern mode
      4'd0,       // forwarded-clock phase is not changed here
      3'd0,       // functional Valid framing
      3'd0        // Data-lane LFSR
    );
  wire [127:0] RXINIT_START_RESP =
    msgMbtrainDataVrefStartRxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_REQ =
    msgMbtrainRxInitD2CTxCountDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_RESP =
    msgMbtrainRxInitD2CTxCountDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_REQ =
    msgMbtrainRxInitD2CEndPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_RESP =
    msgMbtrainRxInitD2CEndPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // The Start Rx Init request contains variable MsgInfo/payload/parity.  Match
  // its fixed message-code/subcode/source/opcode fields in the low 40 bits.
  wire isRxInitStartReq =
    (sb_rx_dout[39:0] == RXINIT_START_REQ[39:0]);

  wire receivedOuterStartReq = rxValidRisingEdge &&
                               (sb_rx_dout == OUTER_START_REQ);
  wire receivedOuterStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == OUTER_START_RESP);
  wire receivedOuterEndReq = rxValidRisingEdge &&
                             (sb_rx_dout == OUTER_END_REQ);
  wire receivedOuterEndResp = rxValidRisingEdge &&
                              (sb_rx_dout == OUTER_END_RESP);

  wire receivedPointStartReq = rxValidRisingEdge && isRxInitStartReq;
  wire receivedPointStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == RXINIT_START_RESP);
  wire receivedClearErrorReq = rxValidRisingEdge &&
                               (sb_rx_dout == CLEAR_ERROR_REQ);
  wire receivedClearErrorResp = rxValidRisingEdge &&
                                (sb_rx_dout == CLEAR_ERROR_RESP);
  wire receivedTxCountDoneReq = rxValidRisingEdge &&
                                (sb_rx_dout == TX_COUNT_DONE_REQ);
  wire receivedTxCountDoneResp = rxValidRisingEdge &&
                                 (sb_rx_dout == TX_COUNT_DONE_RESP);
  wire receivedEndPointReq = rxValidRisingEdge &&
                             (sb_rx_dout == END_POINT_REQ);
  wire receivedEndPointResp = rxValidRisingEdge &&
                              (sb_rx_dout == END_POINT_RESP);

  wire localOuterStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterStartReq);
  wire localOuterEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterEndReq);
  wire remoteOuterStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterStartResp);
  wire remoteOuterEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterEndResp);

  wire initiatorStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorStartReq);
  wire initiatorClearRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorClearResp);
  wire initiatorCountRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorCountResp);
  wire initiatorEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorEndReq);

  wire responderStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderStartResp);
  wire responderClearReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderClearReq);
  wire responderCountReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderCountReq);
  wire responderEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderEndResp);

  logic sweepStart;
  logic sweepBusy;
  logic sweepDone;
  logic sweepTrainError;
  logic sweepApplyDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepDeskewCodes;
  logic sweepPointStart;
  logic [3:0] sweepState;
  logic [15:0] sweepFailedLaneCount;
  logic [15:0] sweepRetryCount;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepFinalDeskewCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepLeftCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepRightCodes;

  logic initiatorSendStartReq;
  logic initiatorSendClearResp;
  logic initiatorSendCountResp;
  logic initiatorSendEndReq;
  logic initiatorConfigureReceiver;
  logic initiatorClearErrors;
  logic initiatorBusy;
  logic initiatorDone;
  logic [dataLaneCount-1:0] initiatorPointPassVector;
  logic [3:0] initiatorState;

  logic responderSendStartResp;
  logic responderSendClearReq;
  logic responderSendCountReq;
  logic responderSendEndResp;
  logic responderSendPattern;
  logic responderResetTxScrambler;
  logic responderBusy;
  logic responderDone;
  logic [3:0] responderState;

  wire responderStart = runningReg &&
                        (remoteStateReg == RemoteState_active) &&
                        receivedPointStartReq;

  assign sweepStart = runningReg &&
                      (localStateReg == LocalState_startSweep);

  MBTrain_RxDeskewSweepEngine #(
    .DATA_LANE_COUNT(dataLaneCount),
    .ACTIVE_DATA_LANE_MASK(activeDataLaneMask),
    .RX_DESKEW_VALUE_COUNT(rxDeskewValueCount),
    .RX_DESKEW_CODE_WIDTH(rxDeskewCodeWidth),
    .MIN_PASSING_WINDOW_VALUES(rxDeskewMinPassingWindowValues),
    .MAX_TRAINING_RETRIES(rxDeskewMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepStart),
    .busy(sweepBusy),
    .done(sweepDone),
    .trainError(sweepTrainError),
    .apply_rx_lane_deskew(sweepApplyDeskew),
    .rx_lane_deskew_codes(sweepDeskewCodes),
    .rx_lane_deskew_applied(flagFromAnalog_rxDeskewRxLaneDeskewApplied),
    .point_test_start(sweepPointStart),
    .point_test_done(initiatorDone),
    .point_test_pass(initiatorPointPassVector),
    .state(sweepState),
    .lastFailedLaneCount(sweepFailedLaneCount),
    .retryCount(sweepRetryCount),
    .finalRxDeskewCodes(sweepFinalDeskewCodes),
    .validWindowLeftCodes(sweepLeftCodes),
    .validWindowRightCodes(sweepRightCodes)
  );

  RxInitD2CPointTestReceiverFSM #(
    .RESULT_WIDTH(dataLaneCount)
  ) pointInitiator (
    .clock(clock),
    .reset_n(reset_n),
    .start(runningReg && sweepPointStart),
    .configureReceiver(initiatorConfigureReceiver),
    .sendStartRxInitD2CPointTestReq(initiatorSendStartReq),
    .sentStartRxInitD2CPointTestReq(initiatorStartReqSent),
    .receivedStartRxInitD2CPointTestResp(receivedPointStartResp),
    .receivedLfsrClearErrorReq(receivedClearErrorReq),
    .clearComparisonErrors(initiatorClearErrors),
    .sendLfsrClearErrorResp(initiatorSendClearResp),
    .sentLfsrClearErrorResp(initiatorClearRespSent),
    .receivedRxInitD2CTxCountDoneReq(receivedTxCountDoneReq),
    .detectedValidPattern(flagFromAnalog_rxDeskewDetectedDataPattern),
    .sendRxInitD2CTxCountDoneResp(initiatorSendCountResp),
    .sentRxInitD2CTxCountDoneResp(initiatorCountRespSent),
    .sendEndRxInitD2CPointTestReq(initiatorSendEndReq),
    .sentEndRxInitD2CPointTestReq(initiatorEndReqSent),
    .receivedEndRxInitD2CPointTestResp(receivedEndPointResp),
    .busy(initiatorBusy),
    .done(initiatorDone),
    .pointTestPass(initiatorPointPassVector),
    .state(initiatorState)
  );

  RxInitD2CPointTestSenderFSM pointResponder (
    .clock(clock),
    .reset_n(reset_n),
    .start(responderStart),
    .sendStartRxInitD2CPointTestResp(responderSendStartResp),
    .sentStartRxInitD2CPointTestResp(responderStartRespSent),
    .resetLocalScrambler(responderResetTxScrambler),
    .sendLfsrClearErrorReq(responderSendClearReq),
    .sentLfsrClearErrorReq(responderClearReqSent),
    .receivedLfsrClearErrorResp(receivedClearErrorResp),
    .sendDefinedPattern(responderSendPattern),
    .sentDefinedPattern(flagFromAnalog_rxDeskewLfsrPatternSent),
    .sendRxInitD2CTxCountDoneReq(responderSendCountReq),
    .sentRxInitD2CTxCountDoneReq(responderCountReqSent),
    .receivedRxInitD2CTxCountDoneResp(receivedTxCountDoneResp),
    .receivedEndRxInitD2CPointTestReq(receivedEndPointReq),
    .sendEndRxInitD2CPointTestResp(responderSendEndResp),
    .sentEndRxInitD2CPointTestResp(responderEndRespSent),
    .busy(responderBusy),
    .done(responderDone),
    .state(responderState)
  );

  always_comb begin
    busy       = runningReg && !doneReg;
    done       = doneReg;
    trainError = trainErrorReg || sweepTrainError;
    sb_tx_valid = sbTxValidReg;
    sb_tx_din   = sbTxDinReg;

    flagToAnalog_rxDeskewApplyRxLaneDeskew = runningReg && performRxDeskew &&
                               sweepApplyDeskew;
    flagToAnalog_rxDeskewRxLaneDeskewCodes = sweepDeskewCodes;
    flagToAnalog_rxDeskewConfigureRxInitD2CPointTest = runningReg &&
                                               initiatorConfigureReceiver;
    flagToAnalog_rxDeskewMaximumComparisonErrorThreshold =
      rxDeskewMaximumComparisonErrorThreshold;
    flagToAnalog_rxDeskewComparisonMode = 1'b0;
    flagToAnalog_rxDeskewIterationCountSettings = 16'd1;
    flagToAnalog_rxDeskewIdleCountSettings = 16'd0;
    flagToAnalog_rxDeskewBurstCountSettings = 16'd4096;
    flagToAnalog_rxDeskewPatternMode = 1'b0;
    flagToAnalog_rxDeskewClockPhaseControl = 4'd0;
    flagToAnalog_rxDeskewValidPattern = 3'd0;
    flagToAnalog_rxDeskewDataPattern = 3'd0;
    flagToAnalog_rxDeskewClearComparisonErrors = runningReg && initiatorClearErrors;

    flagToAnalog_rxDeskewSendLfsrPattern = runningReg && responderSendPattern;
    flagToAnalog_rxDeskewResetLocalTxScrambler = runningReg &&
                                         responderResetTxScrambler;

    substate = {localStateReg, initiatorState, responderState};
    lastErrorCount = sweepFailedLaneCount;
    retryCount = sweepRetryCount;
    selectedRxDeskewCodes = sweepFinalDeskewCodes;
    validWindowLeftCodes = sweepLeftCodes;
    validWindowRightCodes = sweepRightCodes;
  end

  // One-deep sideband TX buffer.  Protocol responses and the remote
  // transmitter role take priority, preventing a local sweep from starving the
  // opposite die's receiver-initiated point test.
  always_comb begin
    txLoadValid  = 1'b0;
    txLoadDin    = 128'd0;
    txLoadSource = TxSource_none;

    if (runningReg && !sbTxValidReg) begin
      if (remoteStateReg == RemoteState_sendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_RESP;
        txLoadSource = TxSource_remoteOuterEndResp;
      end else if (responderSendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_RESP;
        txLoadSource = TxSource_pointResponderEndResp;
      end else if (initiatorSendCountResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_RESP;
        txLoadSource = TxSource_pointInitiatorCountResp;
      end else if (responderSendCountReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_REQ;
        txLoadSource = TxSource_pointResponderCountReq;
      end else if (initiatorSendClearResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_RESP;
        txLoadSource = TxSource_pointInitiatorClearResp;
      end else if (responderSendClearReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_REQ;
        txLoadSource = TxSource_pointResponderClearReq;
      end else if (responderSendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_RESP;
        txLoadSource = TxSource_pointResponderStartResp;
      end else if (remoteStateReg == RemoteState_sendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_RESP;
        txLoadSource = TxSource_remoteOuterStartResp;
      end else if (initiatorSendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_REQ;
        txLoadSource = TxSource_pointInitiatorEndReq;
      end else if (initiatorSendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_REQ;
        txLoadSource = TxSource_pointInitiatorStartReq;
      end else if (localStateReg == LocalState_sendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_REQ;
        txLoadSource = TxSource_localOuterEndReq;
      end else if (localStateReg == LocalState_sendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_REQ;
        txLoadSource = TxSource_localOuterStartReq;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else if (!runningReg) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else begin
      if (txTransfer) begin
        sbTxValidReg  <= 1'b0;
        sbTxSourceReg <= TxSource_none;
      end
      if (!sbTxValidReg && txLoadValid) begin
        sbTxValidReg  <= 1'b1;
        sbTxDinReg    <= txLoadDin;
        sbTxSourceReg <= txLoadSource;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      localStateReg  <= LocalState_idle;
      remoteStateReg <= RemoteState_idle;
      runningReg     <= 1'b0;
      doneReg        <= 1'b0;
      trainErrorReg  <= 1'b0;
      prevStart      <= 1'b0;
      prevRxValid    <= 1'b0;
      remoteOuterEndPendingReg <= 1'b0;
    end else begin
      prevStart   <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        localStateReg  <= LocalState_sendStartReq;
        remoteStateReg <= RemoteState_waitStartReq;
        runningReg     <= 1'b1;
        doneReg        <= 1'b0;
        trainErrorReg  <= 1'b0;
        remoteOuterEndPendingReg <= 1'b0;
      end else if (runningReg) begin
        // End/Done may be received before the last remotely initiated point
        // test has completely retired.  Preserve it until the responder is
        // idle, then issue the outer response.
        if (receivedOuterEndReq)
          remoteOuterEndPendingReg <= 1'b1;

        unique case (localStateReg)
          LocalState_sendStartReq: begin
            if (localOuterStartReqSent)
              localStateReg <= LocalState_waitStartResp;
          end
          LocalState_waitStartResp: begin
            if (receivedOuterStartResp) begin
              if (performRxDeskew)
                localStateReg <= LocalState_startSweep;
              else
                localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_startSweep:
            localStateReg <= LocalState_waitSweep;
          LocalState_waitSweep: begin
            if (sweepTrainError) begin
              localStateReg <= LocalState_error;
              trainErrorReg <= 1'b1;
              runningReg    <= 1'b0;
            end else if (sweepDone) begin
              localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_sendEndReq: begin
            if (localOuterEndReqSent)
              localStateReg <= LocalState_waitEndResp;
          end
          LocalState_waitEndResp: begin
            if (receivedOuterEndResp)
              localStateReg <= LocalState_finish;
          end
          LocalState_finish: ;
          LocalState_error: ;
          default: localStateReg <= LocalState_idle;
        endcase

        unique case (remoteStateReg)
          RemoteState_waitStartReq: begin
            if (receivedOuterStartReq)
              remoteStateReg <= RemoteState_sendStartResp;
          end
          RemoteState_sendStartResp: begin
            if (remoteOuterStartRespSent)
              remoteStateReg <= RemoteState_active;
          end
          RemoteState_active: begin
            if ((receivedOuterEndReq || remoteOuterEndPendingReg) &&
                !responderBusy) begin
              remoteStateReg <= RemoteState_sendEndResp;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_sendEndResp: begin
            if (remoteOuterEndRespSent) begin
              remoteStateReg <= RemoteState_finish;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_finish: ;
          default: remoteStateReg <= RemoteState_idle;
        endcase

        if ((localStateReg == LocalState_finish) &&
            (remoteStateReg == RemoteState_finish)) begin
          runningReg <= 1'b0;
          doneReg    <= 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_RxDeskewSweepEngine-sv"></a>

## [22] MBTrain_RxDeskewSweepEngine.sv

```systemverilog
// FILE_INDEX: 22
// FILE_PATH : MBTrain_RxDeskewSweepEngine.sv

// Parameterized linear receiver lane-deskew sweep for UCIe MBTRAIN.RXDESKEW.
//
// One receiver-initiated D2C point test is performed at each RX deskew code.
// All active Data receiver lanes are swept in parallel with the same code.
// Every lane independently selects the lower midpoint of its longest linear,
// non-wrapping passing interval.  The selected per-lane vector is then applied
// and verified with one final point test.
`default_nettype none

module MBTrain_RxDeskewSweepEngine #(
  parameter int unsigned DATA_LANE_COUNT = 16,
  parameter logic [DATA_LANE_COUNT-1:0] ACTIVE_DATA_LANE_MASK =
    {DATA_LANE_COUNT{1'b1}},
  parameter int unsigned RX_DESKEW_VALUE_COUNT = 16,
  parameter int unsigned RX_DESKEW_CODE_WIDTH =
    (RX_DESKEW_VALUE_COUNT <= 1) ? 1 : $clog2(RX_DESKEW_VALUE_COUNT),
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,

  output      logic busy,
  output      logic done,
  output      logic trainError,

  // During the linear sweep every active lane receives the same delay code.
  // During final application, each lane receives its independently selected
  // delay code.  Code polarity/range are PHY implementation details.
  output      logic apply_rx_lane_deskew,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    rx_lane_deskew_codes,
  input  wire logic rx_lane_deskew_applied,

  output      logic point_test_start,
  input  wire logic point_test_done,
  input  wire logic [DATA_LANE_COUNT-1:0] point_test_pass,

  output      logic [3:0] state,
  output      logic [15:0] lastFailedLaneCount,
  output      logic [15:0] retryCount,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    finalRxDeskewCodes,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    validWindowLeftCodes,
  output      logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
                    validWindowRightCodes
);
  typedef enum logic [3:0] {
    SweepState_idle             = 4'h0,
    SweepState_applySweepCode   = 4'h1,
    SweepState_startSweepPoint  = 4'h2,
    SweepState_waitSweepPoint   = 4'h3,
    SweepState_analyze          = 4'h4,
    SweepState_applyFinalCodes  = 4'h5,
    SweepState_startFinalPoint  = 4'h6,
    SweepState_waitFinalPoint   = 4'h7,
    SweepState_done             = 4'h8,
    SweepState_error            = 4'h9
  } SweepState_t;

  (* keep = "true" *) SweepState_t stateReg;
  (* keep = "true" *) logic [RX_DESKEW_VALUE_COUNT-1:0]
    passBitmapReg [0:DATA_LANE_COUNT-1];
  (* keep = "true" *) logic [RX_DESKEW_CODE_WIDTH-1:0] currentCodeReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    finalCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    leftCodeVectorReg;
  (* keep = "true" *) logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0]
    rightCodeVectorReg;
  (* keep = "true" *) logic [15:0] failedLaneCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;

  // Combinational longest-window analysis.  These variables are owned only by
  // this always_comb process, avoiding procedural multi-driver issues.
  integer runStartInt [0:DATA_LANE_COUNT-1];
  integer runLengthInt [0:DATA_LANE_COUNT-1];
  integer bestStartInt [0:DATA_LANE_COUNT-1];
  integer bestLengthInt [0:DATA_LANE_COUNT-1];
  integer scanLane;
  integer scanCode;
  logic allActiveLanesHaveWindow;
  logic allActiveLanesPassFinal;

  function automatic logic [15:0] count_failed_active_lanes(
    input logic [DATA_LANE_COUNT-1:0] pass_vector
  );
    integer count_lane;
    begin
      count_failed_active_lanes = 16'd0;
      for (count_lane = 0; count_lane < DATA_LANE_COUNT;
           count_lane = count_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[count_lane] && !pass_vector[count_lane])
          count_failed_active_lanes = count_failed_active_lanes + 16'd1;
      end
    end
  endfunction

  // Strictly-greater replacement keeps the lower-code interval when equal
  // windows tie.  Code zero and the highest code are not treated as adjacent.
  always_comb begin
    allActiveLanesHaveWindow = 1'b1;

    for (scanLane = 0; scanLane < DATA_LANE_COUNT;
         scanLane = scanLane + 1) begin
      runStartInt[scanLane]   = 0;
      runLengthInt[scanLane]  = 0;
      bestStartInt[scanLane]  = 0;
      bestLengthInt[scanLane] = 0;

      for (scanCode = 0; scanCode < RX_DESKEW_VALUE_COUNT;
           scanCode = scanCode + 1) begin
        if (passBitmapReg[scanLane][scanCode]) begin
          if (runLengthInt[scanLane] == 0)
            runStartInt[scanLane] = scanCode;
          runLengthInt[scanLane] = runLengthInt[scanLane] + 1;
          if (runLengthInt[scanLane] > bestLengthInt[scanLane]) begin
            bestLengthInt[scanLane] = runLengthInt[scanLane];
            bestStartInt[scanLane]  = runStartInt[scanLane];
          end
        end else begin
          runLengthInt[scanLane] = 0;
        end
      end

      if (ACTIVE_DATA_LANE_MASK[scanLane] &&
          (bestLengthInt[scanLane] < MIN_PASSING_WINDOW_VALUES))
        allActiveLanesHaveWindow = 1'b0;
    end

    allActiveLanesPassFinal =
      ((point_test_pass & ACTIVE_DATA_LANE_MASK) == ACTIVE_DATA_LANE_MASK);
  end

  always_comb begin
    busy       = (stateReg != SweepState_idle) &&
                 (stateReg != SweepState_done) &&
                 (stateReg != SweepState_error);
    done       = (stateReg == SweepState_done);
    trainError = (stateReg == SweepState_error);

    state                 = stateReg;
    lastFailedLaneCount   = failedLaneCountReg;
    retryCount            = retryCountReg;
    finalRxDeskewCodes    = finalCodeVectorReg;
    validWindowLeftCodes  = leftCodeVectorReg;
    validWindowRightCodes = rightCodeVectorReg;

    apply_rx_lane_deskew = (stateReg == SweepState_applySweepCode) ||
                           (stateReg == SweepState_applyFinalCodes);
    point_test_start = (stateReg == SweepState_startSweepPoint) ||
                       (stateReg == SweepState_startFinalPoint);

    rx_lane_deskew_codes = '0;
    if ((stateReg == SweepState_applyFinalCodes) ||
        (stateReg == SweepState_startFinalPoint) ||
        (stateReg == SweepState_waitFinalPoint) ||
        (stateReg == SweepState_done)) begin
      rx_lane_deskew_codes = finalCodeVectorReg;
    end else begin
      for (int unsigned output_lane = 0;
           output_lane < DATA_LANE_COUNT;
           output_lane = output_lane + 1) begin
        if (ACTIVE_DATA_LANE_MASK[output_lane])
          rx_lane_deskew_codes[
            output_lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH
          ] = currentCodeReg;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg           <= SweepState_idle;
      currentCodeReg     <= '0;
      finalCodeVectorReg <= '0;
      leftCodeVectorReg  <= '0;
      rightCodeVectorReg <= '0;
      failedLaneCountReg <= 16'd0;
      retryCountReg      <= 16'd0;
      for (int unsigned reset_lane = 0;
           reset_lane < DATA_LANE_COUNT;
           reset_lane = reset_lane + 1)
        passBitmapReg[reset_lane] <= '0;
    end else begin
      if (start && ((stateReg == SweepState_idle) ||
                    (stateReg == SweepState_done) ||
                    (stateReg == SweepState_error))) begin
        stateReg           <= SweepState_applySweepCode;
        currentCodeReg     <= '0;
        finalCodeVectorReg <= '0;
        leftCodeVectorReg  <= '0;
        rightCodeVectorReg <= '0;
        failedLaneCountReg <= 16'd0;
        retryCountReg      <= 16'd0;
        for (int unsigned start_lane = 0;
             start_lane < DATA_LANE_COUNT;
             start_lane = start_lane + 1)
          passBitmapReg[start_lane] <= '0;
      end else begin
        unique case (stateReg)
          SweepState_idle: ;

          SweepState_applySweepCode: begin
            if (rx_lane_deskew_applied)
              stateReg <= SweepState_startSweepPoint;
          end

          SweepState_startSweepPoint:
            stateReg <= SweepState_waitSweepPoint;

          SweepState_waitSweepPoint: begin
            if (point_test_done) begin
              for (int unsigned capture_lane = 0;
                   capture_lane < DATA_LANE_COUNT;
                   capture_lane = capture_lane + 1) begin
                passBitmapReg[capture_lane][currentCodeReg] <=
                  point_test_pass[capture_lane];
              end
              failedLaneCountReg <= failedLaneCountReg +
                                    count_failed_active_lanes(point_test_pass);

              if (currentCodeReg == (RX_DESKEW_VALUE_COUNT - 1)) begin
                stateReg <= SweepState_analyze;
              end else begin
                currentCodeReg <= currentCodeReg + 1'b1;
                stateReg       <= SweepState_applySweepCode;
              end
            end
          end

          SweepState_analyze: begin
            if (allActiveLanesHaveWindow) begin
              for (int unsigned select_lane = 0;
                   select_lane < DATA_LANE_COUNT;
                   select_lane = select_lane + 1) begin
                if (ACTIVE_DATA_LANE_MASK[select_lane]) begin
                  finalCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       ((bestLengthInt[select_lane] - 1) / 2);
                  leftCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartInt[select_lane];
                  rightCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= bestStartInt[select_lane] +
                       bestLengthInt[select_lane] - 1;
                end else begin
                  finalCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                  leftCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                  rightCodeVectorReg[
                    select_lane*RX_DESKEW_CODE_WIDTH +:
                    RX_DESKEW_CODE_WIDTH
                  ] <= '0;
                end
              end
              stateReg <= SweepState_applyFinalCodes;
            end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
              retryCountReg      <= retryCountReg + 16'd1;
              currentCodeReg     <= '0;
              failedLaneCountReg <= 16'd0;
              for (int unsigned retry_lane = 0;
                   retry_lane < DATA_LANE_COUNT;
                   retry_lane = retry_lane + 1)
                passBitmapReg[retry_lane] <= '0;
              stateReg <= SweepState_applySweepCode;
            end else begin
              stateReg <= SweepState_error;
            end
          end

          SweepState_applyFinalCodes: begin
            if (rx_lane_deskew_applied)
              stateReg <= SweepState_startFinalPoint;
          end

          SweepState_startFinalPoint:
            stateReg <= SweepState_waitFinalPoint;

          SweepState_waitFinalPoint: begin
            if (point_test_done) begin
              if (allActiveLanesPassFinal) begin
                stateReg <= SweepState_done;
              end else if (retryCountReg < MAX_TRAINING_RETRIES) begin
                retryCountReg      <= retryCountReg + 16'd1;
                currentCodeReg     <= '0;
                failedLaneCountReg <= 16'd0;
                for (int unsigned verify_retry_lane = 0;
                     verify_retry_lane < DATA_LANE_COUNT;
                     verify_retry_lane = verify_retry_lane + 1)
                  passBitmapReg[verify_retry_lane] <= '0;
                stateReg <= SweepState_applySweepCode;
              end else begin
                failedLaneCountReg <= failedLaneCountReg +
                                      count_failed_active_lanes(point_test_pass);
                stateReg <= SweepState_error;
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
    if (DATA_LANE_COUNT < 1)
      $error("DATA_LANE_COUNT must be at least 1");
    if (ACTIVE_DATA_LANE_MASK == '0)
      $error("ACTIVE_DATA_LANE_MASK must enable at least one lane");
    if (RX_DESKEW_VALUE_COUNT < 2)
      $error("RX_DESKEW_VALUE_COUNT must be at least 2");
    if (RX_DESKEW_VALUE_COUNT > (1 << RX_DESKEW_CODE_WIDTH))
      $error("RX_DESKEW_CODE_WIDTH cannot represent every deskew value");
    if ((MIN_PASSING_WINDOW_VALUES < 1) ||
        (MIN_PASSING_WINDOW_VALUES > RX_DESKEW_VALUE_COUNT))
      $error("MIN_PASSING_WINDOW_VALUES is outside the RX deskew sweep range");
  end
`endif
endmodule

`default_nettype wire

```

<a id="MBTrain_SpeedIdleFSM-sv"></a>

## [23] MBTrain_SpeedIdleFSM.sv

```systemverilog
// FILE_INDEX: 23
// FILE_PATH : MBTrain_SpeedIdleFSM.sv

// SystemVerilog translation of MBTrain_SpeedIdleFSM.scala.
`default_nettype none

module MBTrainSpeedIdleFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic [7:0]   substate
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [1:0] {
    SpeedIdleSenderState_selectLinkSpeed     = 2'd0,
    SpeedIdleSenderState_sendDoneReq = 2'd1,
    SpeedIdleSenderState_waitDoneResp = 2'd2,
    SpeedIdleSenderState_finish      = 2'd3
  } SpeedIdleSenderState_t;

  typedef enum logic [1:0] {
    SpeedIdleReceiverState_waitDoneReq = 2'd0,
    SpeedIdleReceiverState_sendDoneResp = 2'd1,
    SpeedIdleReceiverState_finish      = 2'd2
  } SpeedIdleReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  (* keep = "true" *) logic flagReceivedSpeedIdleDoneReq;
  (* keep = "true" *) logic flagReceivedSpeedIdleDoneResp;
  (* keep = "true" *) logic flagSentSpeedIdleDoneReq;
  (* keep = "true" *) logic flagSentSpeedIdleDoneResp;
  (* keep = "true" *) SpeedIdleSenderState_t speedIdleSenderStateReg;
  (* keep = "true" *) SpeedIdleReceiverState_t speedIdleReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire [127:0] MBTRAIN_SPEEDIDLE_DONE_REQ  = msgMbtrainSpeedIdleDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_SPEEDIDLE_DONE_RESP = msgMbtrainSpeedIdleDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((speedIdleReceiverStateReg == SpeedIdleReceiverState_sendDoneResp) && !flagSentSpeedIdleDoneResp) begin
        nextSbTxDin   = MBTRAIN_SPEEDIDLE_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((speedIdleSenderStateReg == SpeedIdleSenderState_sendDoneReq) && !flagSentSpeedIdleDoneReq) begin
        nextSbTxDin   = MBTRAIN_SPEEDIDLE_DONE_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;
    substate    = {4'b0, speedIdleReceiverStateReg, speedIdleSenderStateReg};
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin   <= 128'b0;
      running   <= 1'b0;
      doneReg   <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedSpeedIdleDoneReq <= 1'b0;
      flagReceivedSpeedIdleDoneResp <= 1'b0;
      flagSentSpeedIdleDoneReq <= 1'b0;
      flagSentSpeedIdleDoneResp <= 1'b0;
      speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
      speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin   <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedSpeedIdleDoneReq <= 1'b0;
        flagReceivedSpeedIdleDoneResp <= 1'b0;
        flagSentSpeedIdleDoneReq <= 1'b0;
        flagSentSpeedIdleDoneResp <= 1'b0;
        speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
        speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_SPEEDIDLE_DONE_REQ)
          flagReceivedSpeedIdleDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_SPEEDIDLE_DONE_RESP)
          flagReceivedSpeedIdleDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((speedIdleReceiverStateReg == SpeedIdleReceiverState_sendDoneResp) && !flagSentSpeedIdleDoneResp)
          flagSentSpeedIdleDoneResp <= 1'b1;
        else if ((speedIdleSenderStateReg == SpeedIdleSenderState_sendDoneReq) && !flagSentSpeedIdleDoneReq)
          flagSentSpeedIdleDoneReq <= 1'b1;
      end

      unique case (speedIdleSenderStateReg)
        SpeedIdleSenderState_selectLinkSpeed: if (running) speedIdleSenderStateReg <= SpeedIdleSenderState_sendDoneReq;
        SpeedIdleSenderState_sendDoneReq: if (flagSentSpeedIdleDoneReq) speedIdleSenderStateReg <= SpeedIdleSenderState_waitDoneResp;
        SpeedIdleSenderState_waitDoneResp: if (flagReceivedSpeedIdleDoneResp) speedIdleSenderStateReg <= SpeedIdleSenderState_finish;
        SpeedIdleSenderState_finish: speedIdleSenderStateReg <= SpeedIdleSenderState_finish;
        default: speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
      endcase

      unique case (speedIdleReceiverStateReg)
        SpeedIdleReceiverState_waitDoneReq: if (flagReceivedSpeedIdleDoneReq) speedIdleReceiverStateReg <= SpeedIdleReceiverState_sendDoneResp;
        SpeedIdleReceiverState_sendDoneResp: if (flagSentSpeedIdleDoneResp) speedIdleReceiverStateReg <= SpeedIdleReceiverState_finish;
        SpeedIdleReceiverState_finish: speedIdleReceiverStateReg <= SpeedIdleReceiverState_finish;
        default: speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
      endcase

      if (running && (speedIdleSenderStateReg == SpeedIdleSenderState_finish) &&
          (speedIdleReceiverStateReg == SpeedIdleReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_TxSelfCalFSM-sv"></a>

## [24] MBTrain_TxSelfCalFSM.sv

```systemverilog
// FILE_INDEX: 24
// FILE_PATH : MBTrain_TxSelfCalFSM.sv

// SystemVerilog translation of MBTrain_TxSelfCalFSM.scala.
`default_nettype none

module MBTrainTxSelfCalFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic [7:0]   substate
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [1:0] {
    TxSelfCalSenderState_doTxSelfCal     = 2'd0,
    TxSelfCalSenderState_sendDoneReq = 2'd1,
    TxSelfCalSenderState_waitDoneResp = 2'd2,
    TxSelfCalSenderState_finish      = 2'd3
  } TxSelfCalSenderState_t;

  typedef enum logic [1:0] {
    TxSelfCalReceiverState_waitDoneReq = 2'd0,
    TxSelfCalReceiverState_sendDoneResp = 2'd1,
    TxSelfCalReceiverState_finish      = 2'd2
  } TxSelfCalReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  (* keep = "true" *) logic flagReceivedTxSelfCalDoneReq;
  (* keep = "true" *) logic flagReceivedTxSelfCalDoneResp;
  (* keep = "true" *) logic flagSentTxSelfCalDoneReq;
  (* keep = "true" *) logic flagSentTxSelfCalDoneResp;
  (* keep = "true" *) TxSelfCalSenderState_t txSelfCalSenderStateReg;
  (* keep = "true" *) TxSelfCalReceiverState_t txSelfCalReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire [127:0] MBTRAIN_TXSELFCAL_DONE_REQ  = msgMbtrainTxSelfCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_TXSELFCAL_DONE_RESP = msgMbtrainTxSelfCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((txSelfCalReceiverStateReg == TxSelfCalReceiverState_sendDoneResp) && !flagSentTxSelfCalDoneResp) begin
        nextSbTxDin   = MBTRAIN_TXSELFCAL_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((txSelfCalSenderStateReg == TxSelfCalSenderState_sendDoneReq) && !flagSentTxSelfCalDoneReq) begin
        nextSbTxDin   = MBTRAIN_TXSELFCAL_DONE_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;
    substate    = {4'b0, txSelfCalReceiverStateReg, txSelfCalSenderStateReg};
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin   <= 128'b0;
      running   <= 1'b0;
      doneReg   <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedTxSelfCalDoneReq <= 1'b0;
      flagReceivedTxSelfCalDoneResp <= 1'b0;
      flagSentTxSelfCalDoneReq <= 1'b0;
      flagSentTxSelfCalDoneResp <= 1'b0;
      txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
      txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin   <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedTxSelfCalDoneReq <= 1'b0;
        flagReceivedTxSelfCalDoneResp <= 1'b0;
        flagSentTxSelfCalDoneReq <= 1'b0;
        flagSentTxSelfCalDoneResp <= 1'b0;
        txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
        txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_TXSELFCAL_DONE_REQ)
          flagReceivedTxSelfCalDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_TXSELFCAL_DONE_RESP)
          flagReceivedTxSelfCalDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((txSelfCalReceiverStateReg == TxSelfCalReceiverState_sendDoneResp) && !flagSentTxSelfCalDoneResp)
          flagSentTxSelfCalDoneResp <= 1'b1;
        else if ((txSelfCalSenderStateReg == TxSelfCalSenderState_sendDoneReq) && !flagSentTxSelfCalDoneReq)
          flagSentTxSelfCalDoneReq <= 1'b1;
      end

      unique case (txSelfCalSenderStateReg)
        TxSelfCalSenderState_doTxSelfCal: if (running) txSelfCalSenderStateReg <= TxSelfCalSenderState_sendDoneReq;
        TxSelfCalSenderState_sendDoneReq: if (flagSentTxSelfCalDoneReq) txSelfCalSenderStateReg <= TxSelfCalSenderState_waitDoneResp;
        TxSelfCalSenderState_waitDoneResp: if (flagReceivedTxSelfCalDoneResp) txSelfCalSenderStateReg <= TxSelfCalSenderState_finish;
        TxSelfCalSenderState_finish: txSelfCalSenderStateReg <= TxSelfCalSenderState_finish;
        default: txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
      endcase

      unique case (txSelfCalReceiverStateReg)
        TxSelfCalReceiverState_waitDoneReq: if (flagReceivedTxSelfCalDoneReq) txSelfCalReceiverStateReg <= TxSelfCalReceiverState_sendDoneResp;
        TxSelfCalReceiverState_sendDoneResp: if (flagSentTxSelfCalDoneResp) txSelfCalReceiverStateReg <= TxSelfCalReceiverState_finish;
        TxSelfCalReceiverState_finish: txSelfCalReceiverStateReg <= TxSelfCalReceiverState_finish;
        default: txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
      endcase

      if (running && (txSelfCalSenderStateReg == TxSelfCalSenderState_finish) &&
          (txSelfCalReceiverStateReg == TxSelfCalReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_ValidVrefStateCore-sv"></a>

## [25] MBTrain_ValidVrefStateCore.sv

```systemverilog
// FILE_INDEX: 25
// FILE_PATH : MBTrain_ValidVrefStateCore.sv

// Shared implementation for UCIe MBTRAIN.VALVREF and MBTRAIN.VALTRAINVREF.
//
// Each die has two concurrent roles:
//   1. Receiver initiator: sweep the local Valid receiver Vref and initiate one
//      Rx Init D2C point test for every code.
//   2. Transmitter responder: serve the opposite die's Rx Init D2C point tests
//      by transmitting the fixed, unscrambled 1024-UI VALTRAIN sequence.
//
// IS_VALTRAIN_VREF selects only the outer MBTRAIN Start/End(Done) messages.  The
// receiver-initiated point-test protocol and Vref search are otherwise shared.
//
// SidebandMsgGenerator_pkg supplies the packet encodings.  The generic
// RxInitD2CPointTestReceiverFSM and RxInitD2CPointTestSenderFSM modules supply
// the sequencing.  The project-owned TxInitD2CPointTest* modules remain in the
// build for transmitter-initiated states but cannot replace these Rx-init roles.
`default_nettype none

module MBTrain_ValidVrefStateCore #(
  parameter bit IS_VALTRAIN_VREF = 1'b0,
  parameter bit PERFORM_LOCAL_TRAINING = 1'b1,
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter logic [15:0] MAXIMUM_COMPARISON_ERROR_THRESHOLD = 16'd0,
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
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

  // Local receiver controls: this is the Vref being optimized.
  output      logic                         flagToAnalog_applyRxVref,
  output      logic [VREF_CODE_WIDTH-1:0]   flagToAnalog_rxVrefCode,
  input  wire logic                         flagFromAnalog_rxVrefApplied,
  output      logic                         flagToAnalog_configureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_maximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_comparisonMode,
  output      logic [15:0]                  flagToAnalog_iterationCountSettings,
  output      logic [15:0]                  flagToAnalog_idleCountSettings,
  output      logic [15:0]                  flagToAnalog_burstCountSettings,
  output      logic                         flagToAnalog_patternMode,
  output      logic [3:0]                   flagToAnalog_clockPhaseControl,
  output      logic [2:0]                   flagToAnalog_validPattern,
  output      logic [2:0]                   flagToAnalog_dataPattern,
  output      logic                         flagToAnalog_clearComparisonErrors,
  input  wire logic                         flagFromAnalog_detectedValPattern,

  // Local transmitter controls used while serving the opposite receiver.
  output      logic                         flagToAnalog_sendValTrainPattern,
  input  wire logic                         flagFromAnalog_valTrainPatternSent,
  output      logic                         flagToAnalog_resetLocalTxScrambler,

  output      logic [11:0]                  substate,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [VREF_CODE_WIDTH-1:0]   selectedVrefCode,
  output      logic [VREF_CODE_WIDTH-1:0]   validWindowLeftCode,
  output      logic [VREF_CODE_WIDTH-1:0]   validWindowRightCode
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LocalState_idle          = 4'h0,
    LocalState_sendStartReq  = 4'h1,
    LocalState_waitStartResp = 4'h2,
    LocalState_startSweep    = 4'h3,
    LocalState_waitSweep     = 4'h4,
    LocalState_sendEndReq    = 4'h5,
    LocalState_waitEndResp   = 4'h6,
    LocalState_finish        = 4'h7,
    LocalState_error         = 4'h8
  } LocalState_t;

  typedef enum logic [2:0] {
    RemoteState_idle          = 3'h0,
    RemoteState_waitStartReq  = 3'h1,
    RemoteState_sendStartResp = 3'h2,
    RemoteState_active        = 3'h3,
    RemoteState_sendEndResp   = 3'h4,
    RemoteState_finish        = 3'h5
  } RemoteState_t;

  typedef enum logic [4:0] {
    TxSource_none                    = 5'd0,
    TxSource_remoteOuterEndResp      = 5'd1,
    TxSource_pointResponderEndResp   = 5'd2,
    TxSource_pointInitiatorCountResp = 5'd3,
    TxSource_pointResponderCountReq  = 5'd4,
    TxSource_pointInitiatorClearResp = 5'd5,
    TxSource_pointResponderClearReq  = 5'd6,
    TxSource_pointResponderStartResp = 5'd7,
    TxSource_remoteOuterStartResp    = 5'd8,
    TxSource_pointInitiatorEndReq    = 5'd9,
    TxSource_pointInitiatorStartReq  = 5'd10,
    TxSource_localOuterEndReq        = 5'd11,
    TxSource_localOuterStartReq      = 5'd12
  } TxSource_t;

  (* keep = "true" *) LocalState_t localStateReg;
  (* keep = "true" *) RemoteState_t remoteStateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  // Latch the peer's outer End/Done request when it arrives while the local
  // transmitter responder is still completing its final point test.  Without
  // this latch, an asymmetric optional VALTRAINVREF configuration can lose the
  // one-cycle sideband request and deadlock.
  (* keep = "true" *) logic remoteOuterEndPendingReg;

  (* keep = "true" *) logic sbTxValidReg;
  (* keep = "true" *) logic [127:0] sbTxDinReg;
  (* keep = "true" *) TxSource_t sbTxSourceReg;
  logic txLoadValid;
  logic [127:0] txLoadDin;
  TxSource_t txLoadSource;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire txTransfer = sbTxValidReg && sb_tx_ready;

  wire [127:0] OUTER_START_REQ = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_START_RESP = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_REQ = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_RESP = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // Continuous functional VALTRAIN: 128 repetitions of 11110000 = 1024 UI.
  // The ValidPattern encoding 0 selects the functional Valid pattern; Data and
  // Track remain low in the PHY while this state is active.
  wire [127:0] RXINIT_START_REQ =
    msgMbtrainValVrefStartRxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      MAXIMUM_COMPARISON_ERROR_THRESHOLD,
      1'b0,       // per-lane comparison
      16'd1,      // continuous-mode convention
      16'd0,      // no idle UI
      16'd1024,   // 1024 UI VALTRAIN burst
      1'b0,       // continuous pattern mode
      4'd0,       // forwarded-clock phase is not changed here
      3'd0,       // functional Valid pattern
      3'd0        // no Data pattern
    );
  wire [127:0] RXINIT_START_RESP =
    msgMbtrainValVrefStartRxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_REQ =
    msgMbtrainRxInitD2CTxCountDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_RESP =
    msgMbtrainRxInitD2CTxCountDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_REQ =
    msgMbtrainRxInitD2CEndPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_RESP =
    msgMbtrainRxInitD2CEndPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // The Start Rx Init request contains variable MsgInfo/payload/parity.  Match
  // its fixed message-code/subcode/source/opcode fields in the low 40 bits.
  wire isRxInitStartReq =
    (sb_rx_dout[39:0] == RXINIT_START_REQ[39:0]);

  wire receivedOuterStartReq = rxValidRisingEdge &&
                               (sb_rx_dout == OUTER_START_REQ);
  wire receivedOuterStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == OUTER_START_RESP);
  wire receivedOuterEndReq = rxValidRisingEdge &&
                             (sb_rx_dout == OUTER_END_REQ);
  wire receivedOuterEndResp = rxValidRisingEdge &&
                              (sb_rx_dout == OUTER_END_RESP);

  wire receivedPointStartReq = rxValidRisingEdge && isRxInitStartReq;
  wire receivedPointStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == RXINIT_START_RESP);
  wire receivedClearErrorReq = rxValidRisingEdge &&
                               (sb_rx_dout == CLEAR_ERROR_REQ);
  wire receivedClearErrorResp = rxValidRisingEdge &&
                                (sb_rx_dout == CLEAR_ERROR_RESP);
  wire receivedTxCountDoneReq = rxValidRisingEdge &&
                                (sb_rx_dout == TX_COUNT_DONE_REQ);
  wire receivedTxCountDoneResp = rxValidRisingEdge &&
                                 (sb_rx_dout == TX_COUNT_DONE_RESP);
  wire receivedEndPointReq = rxValidRisingEdge &&
                             (sb_rx_dout == END_POINT_REQ);
  wire receivedEndPointResp = rxValidRisingEdge &&
                              (sb_rx_dout == END_POINT_RESP);

  wire localOuterStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterStartReq);
  wire localOuterEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterEndReq);
  wire remoteOuterStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterStartResp);
  wire remoteOuterEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterEndResp);

  wire initiatorStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorStartReq);
  wire initiatorClearRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorClearResp);
  wire initiatorCountRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorCountResp);
  wire initiatorEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorEndReq);

  wire responderStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderStartResp);
  wire responderClearReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderClearReq);
  wire responderCountReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderCountReq);
  wire responderEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderEndResp);

  logic sweepStart;
  logic sweepBusy;
  logic sweepDone;
  logic sweepTrainError;
  logic sweepApplyVref;
  logic [VREF_CODE_WIDTH-1:0] sweepVrefCode;
  logic sweepPointStart;
  logic [3:0] sweepState;
  logic [15:0] sweepFailedPointCount;
  logic [15:0] sweepRetryCount;
  logic [VREF_CODE_WIDTH-1:0] sweepFinalCode;
  logic [VREF_CODE_WIDTH-1:0] sweepLeftCode;
  logic [VREF_CODE_WIDTH-1:0] sweepRightCode;

  logic initiatorSendStartReq;
  logic initiatorSendClearResp;
  logic initiatorSendCountResp;
  logic initiatorSendEndReq;
  logic initiatorConfigureReceiver;
  logic initiatorClearErrors;
  logic initiatorBusy;
  logic initiatorDone;
  logic initiatorPointPass;
  logic [3:0] initiatorState;

  logic responderSendStartResp;
  logic responderSendClearReq;
  logic responderSendCountReq;
  logic responderSendEndResp;
  logic responderSendPattern;
  logic responderResetTxScrambler;
  logic responderBusy;
  logic responderDone;
  logic [3:0] responderState;

  wire responderStart = runningReg &&
                        (remoteStateReg == RemoteState_active) &&
                        receivedPointStartReq;

  assign sweepStart = runningReg &&
                      (localStateReg == LocalState_startSweep);

  MBTrain_ValidVrefSweepEngine #(
    .VREF_VALUE_COUNT(VREF_VALUE_COUNT),
    .VREF_CODE_WIDTH(VREF_CODE_WIDTH),
    .MIN_PASSING_WINDOW_VALUES(MIN_PASSING_WINDOW_VALUES),
    .MAX_TRAINING_RETRIES(MAX_TRAINING_RETRIES)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepStart),
    .busy(sweepBusy),
    .done(sweepDone),
    .trainError(sweepTrainError),
    .apply_rx_vref(sweepApplyVref),
    .rx_vref_code(sweepVrefCode),
    .rx_vref_applied(flagFromAnalog_rxVrefApplied),
    .point_test_start(sweepPointStart),
    .point_test_done(initiatorDone),
    .point_test_pass(initiatorPointPass),
    .state(sweepState),
    .lastFailedPointCount(sweepFailedPointCount),
    .retryCount(sweepRetryCount),
    .finalVrefCode(sweepFinalCode),
    .validLeftCode(sweepLeftCode),
    .validRightCode(sweepRightCode)
  );

  RxInitD2CPointTestReceiverFSM pointInitiator (
    .clock(clock),
    .reset_n(reset_n),
    .start(runningReg && sweepPointStart),
    .configureReceiver(initiatorConfigureReceiver),
    .sendStartRxInitD2CPointTestReq(initiatorSendStartReq),
    .sentStartRxInitD2CPointTestReq(initiatorStartReqSent),
    .receivedStartRxInitD2CPointTestResp(receivedPointStartResp),
    .receivedLfsrClearErrorReq(receivedClearErrorReq),
    .clearComparisonErrors(initiatorClearErrors),
    .sendLfsrClearErrorResp(initiatorSendClearResp),
    .sentLfsrClearErrorResp(initiatorClearRespSent),
    .receivedRxInitD2CTxCountDoneReq(receivedTxCountDoneReq),
    .detectedValidPattern(flagFromAnalog_detectedValPattern),
    .sendRxInitD2CTxCountDoneResp(initiatorSendCountResp),
    .sentRxInitD2CTxCountDoneResp(initiatorCountRespSent),
    .sendEndRxInitD2CPointTestReq(initiatorSendEndReq),
    .sentEndRxInitD2CPointTestReq(initiatorEndReqSent),
    .receivedEndRxInitD2CPointTestResp(receivedEndPointResp),
    .busy(initiatorBusy),
    .done(initiatorDone),
    .pointTestPass(initiatorPointPass),
    .state(initiatorState)
  );

  RxInitD2CPointTestSenderFSM pointResponder (
    .clock(clock),
    .reset_n(reset_n),
    .start(responderStart),
    .sendStartRxInitD2CPointTestResp(responderSendStartResp),
    .sentStartRxInitD2CPointTestResp(responderStartRespSent),
    .resetLocalScrambler(responderResetTxScrambler),
    .sendLfsrClearErrorReq(responderSendClearReq),
    .sentLfsrClearErrorReq(responderClearReqSent),
    .receivedLfsrClearErrorResp(receivedClearErrorResp),
    .sendDefinedPattern(responderSendPattern),
    .sentDefinedPattern(flagFromAnalog_valTrainPatternSent),
    .sendRxInitD2CTxCountDoneReq(responderSendCountReq),
    .sentRxInitD2CTxCountDoneReq(responderCountReqSent),
    .receivedRxInitD2CTxCountDoneResp(receivedTxCountDoneResp),
    .receivedEndRxInitD2CPointTestReq(receivedEndPointReq),
    .sendEndRxInitD2CPointTestResp(responderSendEndResp),
    .sentEndRxInitD2CPointTestResp(responderEndRespSent),
    .busy(responderBusy),
    .done(responderDone),
    .state(responderState)
  );

  always_comb begin
    busy       = runningReg && !doneReg;
    done       = doneReg;
    trainError = trainErrorReg || sweepTrainError;
    sb_tx_valid = sbTxValidReg;
    sb_tx_din   = sbTxDinReg;

    flagToAnalog_applyRxVref = runningReg && PERFORM_LOCAL_TRAINING &&
                               sweepApplyVref;
    flagToAnalog_rxVrefCode = sweepVrefCode;
    flagToAnalog_configureRxInitD2CPointTest = runningReg &&
                                               initiatorConfigureReceiver;
    flagToAnalog_maximumComparisonErrorThreshold =
      MAXIMUM_COMPARISON_ERROR_THRESHOLD;
    flagToAnalog_comparisonMode = 1'b0;
    flagToAnalog_iterationCountSettings = 16'd1;
    flagToAnalog_idleCountSettings = 16'd0;
    flagToAnalog_burstCountSettings = 16'd1024;
    flagToAnalog_patternMode = 1'b0;
    flagToAnalog_clockPhaseControl = 4'd0;
    flagToAnalog_validPattern = 3'd0;
    flagToAnalog_dataPattern = 3'd0;
    flagToAnalog_clearComparisonErrors = runningReg && initiatorClearErrors;

    flagToAnalog_sendValTrainPattern = runningReg && responderSendPattern;
    flagToAnalog_resetLocalTxScrambler = runningReg &&
                                         responderResetTxScrambler;

    substate = {localStateReg, initiatorState, responderState};
    lastErrorCount = sweepFailedPointCount;
    retryCount = sweepRetryCount;
    selectedVrefCode = sweepFinalCode;
    validWindowLeftCode = sweepLeftCode;
    validWindowRightCode = sweepRightCode;
  end

  // One-deep sideband TX buffer.  Protocol responses and the remote
  // transmitter role take priority, preventing a local sweep from starving the
  // opposite die's receiver-initiated point test.
  always_comb begin
    txLoadValid  = 1'b0;
    txLoadDin    = 128'd0;
    txLoadSource = TxSource_none;

    if (runningReg && !sbTxValidReg) begin
      if (remoteStateReg == RemoteState_sendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_RESP;
        txLoadSource = TxSource_remoteOuterEndResp;
      end else if (responderSendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_RESP;
        txLoadSource = TxSource_pointResponderEndResp;
      end else if (initiatorSendCountResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_RESP;
        txLoadSource = TxSource_pointInitiatorCountResp;
      end else if (responderSendCountReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_REQ;
        txLoadSource = TxSource_pointResponderCountReq;
      end else if (initiatorSendClearResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_RESP;
        txLoadSource = TxSource_pointInitiatorClearResp;
      end else if (responderSendClearReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_REQ;
        txLoadSource = TxSource_pointResponderClearReq;
      end else if (responderSendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_RESP;
        txLoadSource = TxSource_pointResponderStartResp;
      end else if (remoteStateReg == RemoteState_sendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_RESP;
        txLoadSource = TxSource_remoteOuterStartResp;
      end else if (initiatorSendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_REQ;
        txLoadSource = TxSource_pointInitiatorEndReq;
      end else if (initiatorSendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_REQ;
        txLoadSource = TxSource_pointInitiatorStartReq;
      end else if (localStateReg == LocalState_sendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_REQ;
        txLoadSource = TxSource_localOuterEndReq;
      end else if (localStateReg == LocalState_sendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_REQ;
        txLoadSource = TxSource_localOuterStartReq;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else if (!runningReg) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else begin
      if (txTransfer) begin
        sbTxValidReg  <= 1'b0;
        sbTxSourceReg <= TxSource_none;
      end
      if (!sbTxValidReg && txLoadValid) begin
        sbTxValidReg  <= 1'b1;
        sbTxDinReg    <= txLoadDin;
        sbTxSourceReg <= txLoadSource;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      localStateReg  <= LocalState_idle;
      remoteStateReg <= RemoteState_idle;
      runningReg     <= 1'b0;
      doneReg        <= 1'b0;
      trainErrorReg  <= 1'b0;
      prevStart      <= 1'b0;
      prevRxValid    <= 1'b0;
      remoteOuterEndPendingReg <= 1'b0;
    end else begin
      prevStart   <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        localStateReg  <= LocalState_sendStartReq;
        remoteStateReg <= RemoteState_waitStartReq;
        runningReg     <= 1'b1;
        doneReg        <= 1'b0;
        trainErrorReg  <= 1'b0;
        remoteOuterEndPendingReg <= 1'b0;
      end else if (runningReg) begin
        // End/Done may be received before the last remotely initiated point
        // test has completely retired.  Preserve it until the responder is
        // idle, then issue the outer response.
        if (receivedOuterEndReq)
          remoteOuterEndPendingReg <= 1'b1;

        unique case (localStateReg)
          LocalState_sendStartReq: begin
            if (localOuterStartReqSent)
              localStateReg <= LocalState_waitStartResp;
          end
          LocalState_waitStartResp: begin
            if (receivedOuterStartResp) begin
              if (PERFORM_LOCAL_TRAINING)
                localStateReg <= LocalState_startSweep;
              else
                localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_startSweep:
            localStateReg <= LocalState_waitSweep;
          LocalState_waitSweep: begin
            if (sweepTrainError) begin
              localStateReg <= LocalState_error;
              trainErrorReg <= 1'b1;
              runningReg    <= 1'b0;
            end else if (sweepDone) begin
              localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_sendEndReq: begin
            if (localOuterEndReqSent)
              localStateReg <= LocalState_waitEndResp;
          end
          LocalState_waitEndResp: begin
            if (receivedOuterEndResp)
              localStateReg <= LocalState_finish;
          end
          LocalState_finish: ;
          LocalState_error: ;
          default: localStateReg <= LocalState_idle;
        endcase

        unique case (remoteStateReg)
          RemoteState_waitStartReq: begin
            if (receivedOuterStartReq)
              remoteStateReg <= RemoteState_sendStartResp;
          end
          RemoteState_sendStartResp: begin
            if (remoteOuterStartRespSent)
              remoteStateReg <= RemoteState_active;
          end
          RemoteState_active: begin
            if ((receivedOuterEndReq || remoteOuterEndPendingReg) &&
                !responderBusy) begin
              remoteStateReg <= RemoteState_sendEndResp;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_sendEndResp: begin
            if (remoteOuterEndRespSent) begin
              remoteStateReg <= RemoteState_finish;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_finish: ;
          default: remoteStateReg <= RemoteState_idle;
        endcase

        if ((localStateReg == LocalState_finish) &&
            (remoteStateReg == RemoteState_finish)) begin
          runningReg <= 1'b0;
          doneReg    <= 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_ValidVrefSweepEngine-sv"></a>

## [26] MBTrain_ValidVrefSweepEngine.sv

```systemverilog
// FILE_INDEX: 26
// FILE_PATH : MBTrain_ValidVrefSweepEngine.sv

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

```

<a id="MBTrain_ValTrainCenterFSM-sv"></a>

## [27] MBTrain_ValTrainCenterFSM.sv

```systemverilog
// FILE_INDEX: 27
// FILE_PATH : MBTrain_ValTrainCenterFSM.sv

// UCIe MBTRAIN.VALTRAINCENTER wrapper with linear Valid-to-clock centering.
// Only the Valid lane is evaluated. Data and Track transmitters are expected
// to remain low, and no per-data-lane transmitter deskew is performed.
`default_nettype none

module MBTrain_ValTrainCenter #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic         flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic         flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic         flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic         flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]  flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic         flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]  flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic         flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]   flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]   flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]   flagToAnalog_d2cReceiver_dataPattern,
  output var logic         flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic [11:0]  substate,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    ValTrainCenterSenderState_idle = 4'h0,
    ValTrainCenterSenderState_sendStartReq = 4'h1,
    ValTrainCenterSenderState_waitStartResp = 4'h2,
    ValTrainCenterSenderState_startPointTest = 4'h3,
    ValTrainCenterSenderState_waitPointTest = 4'h4,
    ValTrainCenterSenderState_checkErrorLog = 4'h5,
    ValTrainCenterSenderState_sendDoneReq = 4'h6,
    ValTrainCenterSenderState_waitDoneResp = 4'h7,
    ValTrainCenterSenderState_finish = 4'h8
  } ValTrainCenterSenderState_t;

  typedef enum logic [2:0] {
    ValTrainCenterReceiverState_idle = 3'h0,
    ValTrainCenterReceiverState_waitStartReq = 3'h1,
    ValTrainCenterReceiverState_sendStartResp = 3'h2,
    ValTrainCenterReceiverState_runPointTest = 3'h3,
    ValTrainCenterReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    ValTrainCenterReceiverState_sendDoneResp = 3'h5,
    ValTrainCenterReceiverState_finish = 3'h6
  } ValTrainCenterReceiverState_t;

  (* keep = "true" *) ValTrainCenterSenderState_t senderStateReg;
  (* keep = "true" *) ValTrainCenterReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedStartResp;
  (* keep = "true" *) logic flagReceivedDoneResp;
  (* keep = "true" *) logic flagReceivedStartReq;
  (* keep = "true" *) logic flagReceivedDoneReq;

  (* keep = "true" *) logic d2cSender_receivedPointTestStartResp;
  (* keep = "true" *) logic d2cSender_receivedLfsrClearResp;
  (* keep = "true" *) logic d2cSender_receivedResultsResp;
  (* keep = "true" *) logic d2cSender_receivedEndPointTestResp;

  (* keep = "true" *) logic d2cReceiver_receivedPointTestStartReq;
  (* keep = "true" *) logic d2cReceiver_receivedLfsrClearReq;
  (* keep = "true" *) logic d2cReceiver_receivedResultsReq;
  (* keep = "true" *) logic d2cReceiver_receivedEndPointTestReq;

  (* keep = "true" *) logic flagSentStartReq;
  (* keep = "true" *) logic flagSentDoneReq;
  (* keep = "true" *) logic flagSentStartResp;
  (* keep = "true" *) logic flagSentDoneResp;

  (* keep = "true" *) logic d2cSender_sentPointTestStartReq;
  (* keep = "true" *) logic d2cSender_sentLfsrClearReq;
  (* keep = "true" *) logic d2cSender_sentResultsReq;
  (* keep = "true" *) logic d2cSender_sentEndPointTestReq;

  (* keep = "true" *) logic d2cReceiver_sentPointTestStartResp;
  (* keep = "true" *) logic d2cReceiver_sentLfsrClearResp;
  (* keep = "true" *) logic d2cReceiver_sentResultsResp;
  (* keep = "true" *) logic d2cReceiver_sentEndPointTestResp;

  (* keep = "true" *) logic [15:0] d2cReceiver_loggedResultsMsgInfo;
  (* keep = "true" *) logic [63:0] d2cReceiver_loggedResultsPayload;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;


  // VALTRAINCENTER trains only the Valid lane.  The state performs a
  // transmitter-initiated phase search using repeated point tests, then
  // applies the center of the longest linear passing interval.  No data-lane
  // result is consumed and no transmitter per-lane deskew is requested.
  logic sweepEngine_start;
  logic sweepEngine_busy;
  logic sweepEngine_done;
  logic sweepEngine_trainError;
  logic sweepEngine_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_txClockPhaseCode;
  logic sweepEngine_pointTestStart;
  logic [3:0] sweepEngine_state;
  logic [15:0] sweepEngine_lastFailedComparisons;
  logic [15:0] sweepEngine_retryCount;
  logic [d2cPiCodeWidth-1:0] sweepEngine_finalClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_globalLeftPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_globalRightPhase;

  // Tx Init D2C Results MsgInfo[5] is the dedicated Valid-lane result.
  // Data-lane payload bits and MsgInfo[4] are intentionally not part of the
  // VALTRAINCENTER pass criterion.
  logic d2cSender_resultsValidPassReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  logic d2cSender_start;
  logic d2cReceiver_start;
  logic senderSentStartPulse;
  logic senderSentLfsrPulse;
  logic senderSentResultsPulse;
  logic senderSentEndPulse;
  logic flagToAnalog_d2cReceiver_configureAnalogPulse;

  logic selectSentDoneResp;
  logic selectReceiverEndResp;
  logic selectReceiverResultsResp;
  logic selectReceiverLfsrResp;
  logic selectReceiverStartResp;
  logic selectSentStartResp;
  logic selectSentDoneReq;
  logic selectSenderEndReq;
  logic selectSenderResultsReq;
  logic selectSenderLfsrReq;
  logic selectSenderStartReq;
  logic selectSentStartReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_VALTRAINCENTER_START_REQ =
    msgMbtrainValTrainCenterStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_VALTRAINCENTER_START_RESP =
    msgMbtrainValTrainCenterStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_VALTRAINCENTER_DONE_REQ =
    msgMbtrainValTrainCenterDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_VALTRAINCENTER_DONE_RESP =
    msgMbtrainValTrainCenterDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      d2cMaximumComparisonErrorThreshold,
      1'b0, 16'd1, 16'd0, 16'd1024,
      1'b0, 4'd0, 3'd0, 3'd0
    );
  wire [127:0] START_POINT_TEST_RESP =
    msgMbtrainStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_REQ =
    msgMbtrainTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_RESP_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);
  wire [127:0] END_POINT_TEST_REQ =
    msgMbtrainEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_TEST_RESP =
    msgMbtrainEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire isStartPointTestReq =
    ((sb_rx_dout[63:0] & 64'h000000FFFFFFFFFF) ==
     (START_POINT_TEST_REQ[63:0] & 64'h000000FFFFFFFFFF));

  // A Results response contains variable MsgInfo, payload, and parity bits.
  // Match only the fixed header fields so both pass and fail responses are
  // recognized.
  wire isTxInitResultsResp =
    (sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
    (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]);

  logic d2cSender_sendStartTxInitD2CPointTestReq;
  logic d2cSender_sendLfsrClearErrorReq;
  logic d2cSender_sendTxInitD2CResultsReq;
  logic d2cSender_sendEndTxInitD2CPointTestReq;
  logic d2cSender_sendDefinedPattern;
  logic d2cSender_resetLocalScrambler;
  logic d2cSender_busy;
  logic d2cSender_done;
  logic [3:0] d2cSender_state;

  logic d2cReceiver_sendStartTxInitD2CPointTestResp;
  logic d2cReceiver_sendLfsrClearErrorResp;
  logic d2cReceiver_sendTxInitD2CResultsResp;
  logic d2cReceiver_sendEndTxInitD2CPointTestResp;
  logic d2cReceiver_resetLocalRxScrambler;
  logic d2cReceiver_busy;
  logic d2cReceiver_done;
  logic [3:0] d2cReceiver_state;

  TxInitD2CPointTestSenderFSM d2cSender (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cSender_start),
    .receivedStartTxInitD2CPointTestResp(d2cSender_receivedPointTestStartResp),
    .receivedLfsrClearErrorResp(d2cSender_receivedLfsrClearResp),
    .receivedTxInitD2CResultsResp(d2cSender_receivedResultsResp),
    .receivedEndTxInitD2CPointTestResp(d2cSender_receivedEndPointTestResp),
    .sentStartTxInitD2CPointTestReq(senderSentStartPulse),
    .sentLfsrClearErrorReq(senderSentLfsrPulse),
    .sentTxInitD2CResultsReq(senderSentResultsPulse),
    .sentEndTxInitD2CPointTestReq(senderSentEndPulse),
    .sentDefinedPattern(flagFromAnalog_d2cSender_valTrainPatternSent),
    .sendStartTxInitD2CPointTestReq(d2cSender_sendStartTxInitD2CPointTestReq),
    .sendLfsrClearErrorReq(d2cSender_sendLfsrClearErrorReq),
    .sendTxInitD2CResultsReq(d2cSender_sendTxInitD2CResultsReq),
    .sendEndTxInitD2CPointTestReq(d2cSender_sendEndTxInitD2CPointTestReq),
    .sendDefinedPattern(d2cSender_sendDefinedPattern),
    .resetLocalScrambler(d2cSender_resetLocalScrambler),
    .busy(d2cSender_busy),
    .done(d2cSender_done),
    .state(d2cSender_state)
  );

  TxInitD2CPointTestReceiverFSM d2cReceiver (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cReceiver_start),
    .receivedStartTxInitD2CPointTestReq(d2cReceiver_receivedPointTestStartReq),
    .receivedLfsrClearErrorReq(d2cReceiver_receivedLfsrClearReq),
    .receivedTxInitD2CResultsReq(d2cReceiver_receivedResultsReq),
    .receivedEndTxInitD2CPointTestReq(d2cReceiver_receivedEndPointTestReq),
    .sentStartTxInitD2CPointTestResp(d2cReceiver_sentPointTestStartResp),
    .sentLfsrClearErrorResp(d2cReceiver_sentLfsrClearResp),
    .sentTxInitD2CResultsResp(d2cReceiver_sentResultsResp),
    .sentEndTxInitD2CPointTestResp(d2cReceiver_sentEndPointTestResp),
    .sendStartTxInitD2CPointTestResp(d2cReceiver_sendStartTxInitD2CPointTestResp),
    .sendLfsrClearErrorResp(d2cReceiver_sendLfsrClearErrorResp),
    .sendTxInitD2CResultsResp(d2cReceiver_sendTxInitD2CResultsResp),
    .sendEndTxInitD2CPointTestResp(d2cReceiver_sendEndTxInitD2CPointTestResp),
    .resetLocalRxScrambler(d2cReceiver_resetLocalRxScrambler),
    .busy(d2cReceiver_busy),
    .done(d2cReceiver_done),
    .state(d2cReceiver_state)
  );

  MBTrain_ValTrainCenterSweepEngine #(
    .PI_CODE_WIDTH(d2cPiCodeWidth),
    .MIN_VALID_WINDOW_STEPS(d2cMinCommonWindowSteps),
    .MAX_TRAINING_RETRIES(d2cMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepEngine_start),
    .busy(sweepEngine_busy),
    .done(sweepEngine_done),
    .trainError(sweepEngine_trainError),
    .apply_tx_clock_phase(sweepEngine_applyTxClockPhase),
    .tx_clock_phase_code(sweepEngine_txClockPhaseCode),
    .tx_clock_phase_applied(flagFromAnalog_d2cSender_txClockPhaseApplied),
    .point_test_start(sweepEngine_pointTestStart),
    .point_test_done(d2cSender_done),
    .point_test_valid_pass(d2cSender_resultsValidPassReg),
    .state(sweepEngine_state),
    .lastFailedComparisons(sweepEngine_lastFailedComparisons),
    .retryCount(sweepEngine_retryCount),
    .finalClockPhase(sweepEngine_finalClockPhase),
    .validLeftPhase(sweepEngine_globalLeftPhase),
    .validRightPhase(sweepEngine_globalRightPhase)
  );

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg || sweepEngine_trainError;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    substate = {senderStateReg[3:0], d2cSender_state, d2cReceiver_state};
    lastErrorCount = sweepEngine_lastFailedComparisons;
    retryCount = sweepEngine_retryCount;

    flagToAnalog_d2cSender_sendValTrainPattern = running && d2cSender_sendDefinedPattern;
    // The generic point-test handshake still exchanges LFSR-clear messages.
    // VALTRAIN itself is not scrambled, so these analog reset indications are
    // compatibility/no-op controls for this state.
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
    flagToAnalog_d2cSender_applyTxClockPhase = running && sweepEngine_applyTxClockPhase;
    flagToAnalog_d2cSender_txClockPhaseCode = sweepEngine_txClockPhaseCode;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = flagToAnalog_d2cReceiver_configureAnalogPulse;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = d2c_maximumComparisonErrorThresholdReg;
    flagToAnalog_d2cReceiver_comparisonMode = d2c_comparisonModeReg;
    flagToAnalog_d2cReceiver_iterationCountSettings = d2c_iterationCountSettingsReg;
    flagToAnalog_d2cReceiver_idleCountSettings = d2c_idleCountSettingsReg;
    flagToAnalog_d2cReceiver_burstCountSettings = d2c_burstCountSettingsReg;
    flagToAnalog_d2cReceiver_patternMode = d2c_patternModeReg;
    flagToAnalog_d2cReceiver_clockPhaseControl = d2c_clockPhaseControlReg;
    flagToAnalog_d2cReceiver_validPattern = d2c_validPatternReg;
    flagToAnalog_d2cReceiver_dataPattern = d2c_dataPatternReg;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = running && d2cReceiver_resetLocalRxScrambler;
  end

  // Combinational local pulses and the source's pulse-style registered TX selector.
  always_comb begin
    sweepEngine_start = running && !startPulse &&
                        (senderStateReg == ValTrainCenterSenderState_startPointTest);
    d2cSender_start = running && !startPulse &&
                      (senderStateReg == ValTrainCenterSenderState_waitPointTest) &&
                      sweepEngine_pointTestStart;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    nextSbTxValid = 1'b0;
    nextSbTxDin = 128'b0;
    selectSentDoneResp = 1'b0;
    selectReceiverEndResp = 1'b0;
    selectReceiverResultsResp = 1'b0;
    selectReceiverLfsrResp = 1'b0;
    selectReceiverStartResp = 1'b0;
    selectSentStartResp = 1'b0;
    selectSentDoneReq = 1'b0;
    selectSenderEndReq = 1'b0;
    selectSenderResultsReq = 1'b0;
    selectSenderLfsrReq = 1'b0;
    selectSenderStartReq = 1'b0;
    selectSentStartReq = 1'b0;

    if (!startPulse) begin
      unique case (receiverStateReg)
        ValTrainCenterReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        ValTrainCenterReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == ValTrainCenterReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_VALTRAINCENTER_DONE_RESP;
        nextSbTxValid = 1'b1;
        selectSentDoneResp = 1'b1;
      end
      else if (d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverEndResp = 1'b1;
      end
      else if (d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          d2cReceiver_loggedResultsMsgInfo,
          d2cReceiver_loggedResultsPayload
        );
        nextSbTxValid = 1'b1;
        selectReceiverResultsResp = 1'b1;
      end
      else if (d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverLfsrResp = 1'b1;
      end
      else if (d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverStartResp = 1'b1;
      end
      else if ((receiverStateReg == ValTrainCenterReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_VALTRAINCENTER_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end

      else if ((senderStateReg == ValTrainCenterSenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_VALTRAINCENTER_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == ValTrainCenterSenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == ValTrainCenterSenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == ValTrainCenterSenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == ValTrainCenterSenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == ValTrainCenterSenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_VALTRAINCENTER_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= ValTrainCenterSenderState_idle;
      receiverStateReg <= ValTrainCenterReceiverState_idle;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedStartResp <= 1'b0;
      flagReceivedDoneResp <= 1'b0;
      flagReceivedStartReq <= 1'b0;
      flagReceivedDoneReq <= 1'b0;
      d2cSender_receivedPointTestStartResp <= 1'b0;
      d2cSender_receivedLfsrClearResp <= 1'b0;
      d2cSender_receivedResultsResp <= 1'b0;
      d2cSender_receivedEndPointTestResp <= 1'b0;
      d2cReceiver_receivedPointTestStartReq <= 1'b0;
      d2cReceiver_receivedLfsrClearReq <= 1'b0;
      d2cReceiver_receivedResultsReq <= 1'b0;
      d2cReceiver_receivedEndPointTestReq <= 1'b0;
      flagSentStartReq <= 1'b0;
      flagSentDoneReq <= 1'b0;
      flagSentStartResp <= 1'b0;
      flagSentDoneResp <= 1'b0;
      d2cSender_sentPointTestStartReq <= 1'b0;
      d2cSender_sentLfsrClearReq <= 1'b0;
      d2cSender_sentResultsReq <= 1'b0;
      d2cSender_sentEndPointTestReq <= 1'b0;
      d2cReceiver_sentPointTestStartResp <= 1'b0;
      d2cReceiver_sentLfsrClearResp <= 1'b0;
      d2cReceiver_sentResultsResp <= 1'b0;
      d2cReceiver_sentEndPointTestResp <= 1'b0;
      d2cReceiver_loggedResultsMsgInfo <= 16'b0;
      d2cReceiver_loggedResultsPayload <= 64'b0;
      d2cSender_resultsValidPassReg <= 1'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;
      flagToAnalog_d2cReceiver_configureAnalogPulse <= 1'b0;

      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      flagToAnalog_d2cReceiver_configureAnalogPulse <= 1'b0;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        senderStateReg <= ValTrainCenterSenderState_sendStartReq;
        receiverStateReg <= ValTrainCenterReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cReceiver_receivedPointTestStartReq <= 1'b0;
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        flagSentStartReq <= 1'b0;
        flagSentDoneReq <= 1'b0;
        flagSentStartResp <= 1'b0;
        flagSentDoneResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
        d2cReceiver_loggedResultsMsgInfo <= 16'b0;
        d2cReceiver_loggedResultsPayload <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_VALTRAINCENTER_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_VALTRAINCENTER_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_VALTRAINCENTER_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_VALTRAINCENTER_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
        else if (isStartPointTestReq) begin
          d2c_maximumComparisonErrorThresholdReg <= sb_rx_dout[55:40];
          d2c_comparisonModeReg <= sb_rx_dout[123];
          d2c_iterationCountSettingsReg <= sb_rx_dout[122:107];
          d2c_idleCountSettingsReg <= sb_rx_dout[106:91];
          d2c_burstCountSettingsReg <= sb_rx_dout[90:75];
          d2c_patternModeReg <= sb_rx_dout[74];
          d2c_clockPhaseControlReg <= sb_rx_dout[73:70];
          d2c_validPatternReg <= sb_rx_dout[69:67];
          d2c_dataPatternReg <= sb_rx_dout[66:64];
          flagToAnalog_d2cReceiver_configureAnalogPulse <= 1'b1;
          d2cReceiver_receivedPointTestStartReq <= 1'b1;
        end
        else if (sb_rx_dout == START_POINT_TEST_RESP)
          d2cSender_receivedPointTestStartResp <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_REQ)
          d2cReceiver_receivedLfsrClearReq <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_RESP)
          d2cSender_receivedLfsrClearResp <= 1'b1;
        else if (sb_rx_dout == TX_INIT_RESULTS_REQ) begin
          d2cReceiver_loggedResultsMsgInfo <= flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
          d2cReceiver_loggedResultsPayload <= flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
          d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (isTxInitResultsResp) begin
          d2cSender_receivedResultsResp <= 1'b1;
          // MsgInfo occupies message bits [55:40], so MsgInfo[5] is bit 45.
          d2cSender_resultsValidPassReg <= sb_rx_dout[45];
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (d2cSender_start) begin
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
      end

      // Clear a Start request only when the matching response is scheduled.
      // The sent flag is sticky until the receiver point-test FSM restarts.
      if (selectReceiverStartResp)
        d2cReceiver_receivedPointTestStartReq <= 1'b0;

      if (d2cReceiver_start) begin
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
      end

      if (selectSentDoneResp)
        flagSentDoneResp <= 1'b1;
      if (selectReceiverEndResp)
        d2cReceiver_sentEndPointTestResp <= 1'b1;
      if (selectReceiverResultsResp)
        d2cReceiver_sentResultsResp <= 1'b1;
      if (selectReceiverLfsrResp)
        d2cReceiver_sentLfsrClearResp <= 1'b1;
      if (selectReceiverStartResp)
        d2cReceiver_sentPointTestStartResp <= 1'b1;
      if (selectSentStartResp)
        flagSentStartResp <= 1'b1;
      if (selectSentDoneReq)
        flagSentDoneReq <= 1'b1;
      if (selectSenderEndReq)
        d2cSender_sentEndPointTestReq <= 1'b1;
      if (selectSenderResultsReq)
        d2cSender_sentResultsReq <= 1'b1;
      if (selectSenderLfsrReq)
        d2cSender_sentLfsrClearReq <= 1'b1;
      if (selectSenderStartReq)
        d2cSender_sentPointTestStartReq <= 1'b1;
      if (selectSentStartReq)
        flagSentStartReq <= 1'b1;

      if (!startPulse) begin
        unique case (senderStateReg)
          ValTrainCenterSenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= ValTrainCenterSenderState_waitStartResp;
          end
          ValTrainCenterSenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= ValTrainCenterSenderState_startPointTest;
          end
          ValTrainCenterSenderState_startPointTest:
            senderStateReg <= ValTrainCenterSenderState_waitPointTest;
          ValTrainCenterSenderState_waitPointTest: begin
            if (sweepEngine_trainError) begin
              trainErrorReg <= 1'b1;
              running <= 1'b0;
              senderStateReg <= ValTrainCenterSenderState_idle;
              receiverStateReg <= ValTrainCenterReceiverState_idle;
            end else if (sweepEngine_done) begin
              senderStateReg <= ValTrainCenterSenderState_sendDoneReq;
            end
          end
          ValTrainCenterSenderState_checkErrorLog: begin
            // Retained for state-number compatibility with the original.
            senderStateReg <= ValTrainCenterSenderState_waitPointTest;
          end
          ValTrainCenterSenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= ValTrainCenterSenderState_waitDoneResp;
          end
          ValTrainCenterSenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= ValTrainCenterSenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          ValTrainCenterReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= ValTrainCenterReceiverState_sendStartResp;
          end
          ValTrainCenterReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= ValTrainCenterReceiverState_runPointTest;
          end
          ValTrainCenterReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= ValTrainCenterReceiverState_waitDoneReqOrPointTestReq;
          end
          ValTrainCenterReceiverState_waitDoneReqOrPointTestReq: begin
            if (flagReceivedDoneReq)
              receiverStateReg <= ValTrainCenterReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= ValTrainCenterReceiverState_runPointTest;
          end
          ValTrainCenterReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= ValTrainCenterReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == ValTrainCenterSenderState_finish) &&
            (receiverStateReg == ValTrainCenterReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="MBTrain_ValTrainCenterSweepEngine-sv"></a>

## [28] MBTrain_ValTrainCenterSweepEngine.sv

```systemverilog
// FILE_INDEX: 28
// FILE_PATH : MBTrain_ValTrainCenterSweepEngine.sv

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

  logic passByPhase [0:PHASE_COUNT-1];

  integer phaseIdx;
  integer runLength;
  integer bestLength;
  integer runStart;
  integer bestStart;

  logic validWindowFoundCalc;
  logic [PI_CODE_WIDTH-1:0] validLeftPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] validRightPhaseCalc;
  logic [PI_CODE_WIDTH-1:0] validCenterPhaseCalc;

  // Find the longest non-wrapping run of passing Valid samples. For an even
  // number of codes, select the lower of the two center codes.
  always_comb begin
    runLength = 0;
    bestLength = 0;
    runStart = 0;
    bestStart = 0;

    for (phaseIdx = 0; phaseIdx < PHASE_COUNT; phaseIdx = phaseIdx + 1) begin
      if (passByPhase[phaseIdx]) begin
        if (runLength == 0)
          runStart = phaseIdx;
        runLength = runLength + 1;
        if (runLength > bestLength) begin
          bestLength = runLength;
          bestStart = runStart;
        end
      end else begin
        runLength = 0;
      end
    end

    validWindowFoundCalc = (bestLength >= MIN_VALID_WINDOW_STEPS);

    if (bestLength == 0) begin
      validLeftPhaseCalc = '0;
      validRightPhaseCalc = '0;
      validCenterPhaseCalc = '0;
    end else begin
      validLeftPhaseCalc = bestStart;
      validRightPhaseCalc = bestStart + bestLength - 1;
      validCenterPhaseCalc = bestStart + ((bestLength - 1) >> 1);
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
            passByPhase[phaseIndexReg] <= point_test_valid_pass;
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

```

<a id="MBTrain_ValTrainVrefFSM-sv"></a>

## [29] MBTrain_ValTrainVrefFSM.sv

```systemverilog
// FILE_INDEX: 29
// FILE_PATH : MBTrain_ValTrainVrefFSM.sv

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

  output      logic [11:0]                  substate,
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
    .substate(substate),
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

```

<a id="MBTrain_ValVrefFSM-sv"></a>

## [30] MBTrain_ValVrefFSM.sv

```systemverilog
// FILE_INDEX: 30
// FILE_PATH : MBTrain_ValVrefFSM.sv

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

  output      logic [11:0]                  substate,
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
    .substate(substate),
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

```

<a id="MBTrainFSM-sv"></a>

## [31] MBTrainFSM.sv

```systemverilog
// FILE_INDEX: 31
// FILE_PATH : MBTrainFSM.sv

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
  output var logic [3:0]     state,
  output var logic [11:0]    activeSubstate,
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

  logic valVref_busy;
  logic valVref_done;
  logic valVref_trainError;
  logic valVref_sb_tx_valid;
  logic [127:0] valVref_sb_tx_din;
  logic [11:0] valVref_substate;
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
  logic [11:0] dataVref_substate;
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
  logic [7:0] speedIdle_substate;
  logic txSelfCal_busy;
  logic txSelfCal_done;
  logic txSelfCal_trainError;
  logic txSelfCal_sb_tx_valid;
  logic [127:0] txSelfCal_sb_tx_din;
  logic [7:0] txSelfCal_substate;
  logic rxClkCal_busy;
  logic rxClkCal_done;
  logic rxClkCal_trainError;
  logic rxClkCal_sb_tx_valid;
  logic [127:0] rxClkCal_sb_tx_din;
  logic [7:0] rxClkCal_substate;
  logic valTrainCenter_busy;
  logic valTrainCenter_done;
  logic valTrainCenter_trainError;
  logic valTrainCenter_sb_tx_valid;
  logic [127:0] valTrainCenter_sb_tx_din;
  logic [11:0] valTrainCenter_substate;
  logic [15:0] valTrainCenter_lastErrorCount;
  logic [15:0] valTrainCenter_retryCount;
  logic valTrainVref_busy;
  logic valTrainVref_done;
  logic valTrainVref_trainError;
  logic valTrainVref_sb_tx_valid;
  logic [127:0] valTrainVref_sb_tx_din;
  logic [11:0] valTrainVref_substate;
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
  logic [11:0] dataTrainCenter1_substate;
  logic [15:0] dataTrainCenter1_lastErrorCount;
  logic [15:0] dataTrainCenter1_retryCount;
  logic dataTrainVref_busy;
  logic dataTrainVref_done;
  logic dataTrainVref_trainError;
  logic dataTrainVref_sb_tx_valid;
  logic [127:0] dataTrainVref_sb_tx_din;
  logic [11:0] dataTrainVref_substate;
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
  logic [11:0] rxDeskew_substate;
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
  logic [11:0] dataTrainCenter2_substate;
  logic [15:0] dataTrainCenter2_lastErrorCount;
  logic [15:0] dataTrainCenter2_retryCount;
  logic linkSpeed_busy;
  logic linkSpeed_done;
  logic linkSpeed_trainError;
  logic linkSpeed_sb_tx_valid;
  logic [127:0] linkSpeed_sb_tx_din;
  logic [11:0] linkSpeed_substate;
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
    .flagToAnalog_valRefApplyRxVref(flagToAnalog_valVref_applyRxVref),
    .flagToAnalog_valRefRxVrefCode(flagToAnalog_valVref_rxVrefCode),
    .flagFromAnalog_valRefRxVrefApplied(flagFromAnalog_valVref_rxVrefApplied),
    .flagToAnalog_valRefConfigureRxInitD2CPointTest(flagToAnalog_valVref_configureRxInitD2CPointTest),
    .flagToAnalog_valRefMaximumComparisonErrorThreshold(flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valRefComparisonMode(flagToAnalog_valVref_comparisonMode),
    .flagToAnalog_valRefIterationCountSettings(flagToAnalog_valVref_iterationCountSettings),
    .flagToAnalog_valRefIdleCountSettings(flagToAnalog_valVref_idleCountSettings),
    .flagToAnalog_valRefBurstCountSettings(flagToAnalog_valVref_burstCountSettings),
    .flagToAnalog_valRefPatternMode(flagToAnalog_valVref_patternMode),
    .flagToAnalog_valRefClockPhaseControl(flagToAnalog_valVref_clockPhaseControl),
    .flagToAnalog_valRefValidPattern(flagToAnalog_valVref_validPattern),
    .flagToAnalog_valRefDataPattern(flagToAnalog_valVref_dataPattern),
    .flagToAnalog_valRefClearComparisonErrors(flagToAnalog_valVref_clearComparisonErrors),
    .flagFromAnalog_valRefDetectedValPattern(flagFromAnalog_valVref_detectedValPattern),
    .flagToAnalog_valRefSendPattern(flagToAnalog_valVref_sendPattern),
    .flagFromAnalog_valRefFinishedPattern(flagFromAnalog_valVref_finishedPattern),
    .flagToAnalog_valRefResetLocalTxScrambler(flagToAnalog_valVref_resetLocalTxScrambler),
    .substate(valVref_substate),
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
    .flagToAnalog_dataVrefApplyRxVref(flagToAnalog_dataVref_applyRxVref),
    .flagToAnalog_dataVrefRxVrefCodes(flagToAnalog_dataVref_rxVrefCodes),
    .flagFromAnalog_dataVrefRxVrefApplied(flagFromAnalog_dataVref_rxVrefApplied),
    .flagToAnalog_dataVrefConfigureRxInitD2CPointTest(
      flagToAnalog_dataVref_configureRxInitD2CPointTest
    ),
    .flagToAnalog_dataVrefMaximumComparisonErrorThreshold(
      flagToAnalog_dataVref_maximumComparisonErrorThreshold
    ),
    .flagToAnalog_dataVrefComparisonMode(flagToAnalog_dataVref_comparisonMode),
    .flagToAnalog_dataVrefIterationCountSettings(
      flagToAnalog_dataVref_iterationCountSettings
    ),
    .flagToAnalog_dataVrefIdleCountSettings(
      flagToAnalog_dataVref_idleCountSettings
    ),
    .flagToAnalog_dataVrefBurstCountSettings(
      flagToAnalog_dataVref_burstCountSettings
    ),
    .flagToAnalog_dataVrefPatternMode(flagToAnalog_dataVref_patternMode),
    .flagToAnalog_dataVrefClockPhaseControl(
      flagToAnalog_dataVref_clockPhaseControl
    ),
    .flagToAnalog_dataVrefValidPattern(flagToAnalog_dataVref_validPattern),
    .flagToAnalog_dataVrefDataPattern(flagToAnalog_dataVref_dataPattern),
    .flagToAnalog_dataVrefClearComparisonErrors(
      flagToAnalog_dataVref_clearComparisonErrors
    ),
    .flagFromAnalog_dataVrefDetectedDataPattern(
      flagFromAnalog_dataVref_detectedDataPattern
    ),
    .flagToAnalog_dataVrefSendPattern(flagToAnalog_dataVref_sendPattern),
    .flagFromAnalog_dataVrefFinishedPattern(
      flagFromAnalog_dataVref_finishedPattern
    ),
    .flagToAnalog_dataVrefResetLocalTxScrambler(
      flagToAnalog_dataVref_resetLocalTxScrambler
    ),
    .substate(dataVref_substate),
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
    .substate(speedIdle_substate)
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
    .substate(txSelfCal_substate)
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
    .substate(rxClkCal_substate)
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
    .flagToAnalog_d2cSender_sendValTrainPattern(flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainPatternSent(flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .substate(valTrainCenter_substate),
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
    .flagToAnalog_valTrainVrefApplyRxVref(flagToAnalog_valTrainVref_applyRxVref),
    .flagToAnalog_valTrainVrefRxVrefCode(flagToAnalog_valTrainVref_rxVrefCode),
    .flagFromAnalog_valTrainVrefRxVrefApplied(flagFromAnalog_valTrainVref_rxVrefApplied),
    .flagToAnalog_valTrainVrefConfigureRxInitD2CPointTest(flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .flagToAnalog_valTrainVrefMaximumComparisonErrorThreshold(flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valTrainVrefComparisonMode(flagToAnalog_valTrainVref_comparisonMode),
    .flagToAnalog_valTrainVrefIterationCountSettings(flagToAnalog_valTrainVref_iterationCountSettings),
    .flagToAnalog_valTrainVrefIdleCountSettings(flagToAnalog_valTrainVref_idleCountSettings),
    .flagToAnalog_valTrainVrefBurstCountSettings(flagToAnalog_valTrainVref_burstCountSettings),
    .flagToAnalog_valTrainVrefPatternMode(flagToAnalog_valTrainVref_patternMode),
    .flagToAnalog_valTrainVrefClockPhaseControl(flagToAnalog_valTrainVref_clockPhaseControl),
    .flagToAnalog_valTrainVrefValidPattern(flagToAnalog_valTrainVref_validPattern),
    .flagToAnalog_valTrainVrefDataPattern(flagToAnalog_valTrainVref_dataPattern),
    .flagToAnalog_valTrainVrefClearComparisonErrors(flagToAnalog_valTrainVref_clearComparisonErrors),
    .flagFromAnalog_valTrainVrefDetectedValPattern(flagFromAnalog_valTrainVref_detectedValPattern),
    .flagToAnalog_valTrainVrefSendPattern(flagToAnalog_valTrainVref_sendPattern),
    .flagFromAnalog_valTrainVrefFinishedPattern(flagFromAnalog_valTrainVref_finishedPattern),
    .flagToAnalog_valTrainVrefResetLocalTxScrambler(flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .substate(valTrainVref_substate),
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
    .flagToAnalog_d2cSender_sendLfsrPattern(flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .flagToAnalog_d2cSender_applyTxLaneDeskew(flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_txLaneDeskewCodes(flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_txLaneDeskewApplied(flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .substate(dataTrainCenter1_substate),
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
      flagToAnalog_dataTrainVref_applyRxVref
    ),
    .flagToAnalog_dataTrainVrefRxVrefCodes(
      flagToAnalog_dataTrainVref_rxVrefCodes
    ),
    .flagFromAnalog_dataTrainVrefRxVrefApplied(
      flagFromAnalog_dataTrainVref_rxVrefApplied
    ),
    .flagToAnalog_dataTrainVrefConfigureRxInitD2CPointTest(
      flagToAnalog_dataTrainVref_configureRxInitD2CPointTest
    ),
    .flagToAnalog_dataTrainVrefMaximumComparisonErrorThreshold(
      flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold
    ),
    .flagToAnalog_dataTrainVrefComparisonMode(
      flagToAnalog_dataTrainVref_comparisonMode
    ),
    .flagToAnalog_dataTrainVrefIterationCountSettings(
      flagToAnalog_dataTrainVref_iterationCountSettings
    ),
    .flagToAnalog_dataTrainVrefIdleCountSettings(
      flagToAnalog_dataTrainVref_idleCountSettings
    ),
    .flagToAnalog_dataTrainVrefBurstCountSettings(
      flagToAnalog_dataTrainVref_burstCountSettings
    ),
    .flagToAnalog_dataTrainVrefPatternMode(
      flagToAnalog_dataTrainVref_patternMode
    ),
    .flagToAnalog_dataTrainVrefClockPhaseControl(
      flagToAnalog_dataTrainVref_clockPhaseControl
    ),
    .flagToAnalog_dataTrainVrefValidPattern(
      flagToAnalog_dataTrainVref_validPattern
    ),
    .flagToAnalog_dataTrainVrefDataPattern(
      flagToAnalog_dataTrainVref_dataPattern
    ),
    .flagToAnalog_dataTrainVrefClearComparisonErrors(
      flagToAnalog_dataTrainVref_clearComparisonErrors
    ),
    .flagFromAnalog_dataTrainVrefDetectedDataPattern(
      flagFromAnalog_dataTrainVref_detectedDataPattern
    ),
    .flagToAnalog_dataTrainVrefSendPattern(
      flagToAnalog_dataTrainVref_sendPattern
    ),
    .flagFromAnalog_dataTrainVrefFinishedPattern(
      flagFromAnalog_dataTrainVref_finishedPattern
    ),
    .flagToAnalog_dataTrainVrefResetLocalTxScrambler(
      flagToAnalog_dataTrainVref_resetLocalTxScrambler
    ),
    .substate(dataTrainVref_substate),
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
    .substate(rxDeskew_substate),
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
    .flagToAnalog_d2cSender_sendLfsrPattern(flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase(flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode(flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied(flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .substate(dataTrainCenter2_substate),
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
    .flagToAnalog_d2cSender_sendLfsrPattern(flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent(flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler(flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode(flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings(flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings(flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings(flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode(flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl(flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern(flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern(flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler(flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_laneComparisonSuccessful(flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
    .substate(linkSpeed_substate),
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
    busy = (stateReg != State_IDLE) &&
           (stateReg != State_COMPLETE) &&
           (stateReg != State_ERROR);
    done = (stateReg == State_COMPLETE);
    trainError = errorReg || (stateReg == State_ERROR);

    activeSubstate = 12'b0;
    lastErrorCount = 16'b0;
    retryCount = 16'b0;
    unique case (stateReg)
      State_VALVREF: begin
        activeSubstate = valVref_substate;
        lastErrorCount = valVref_lastErrorCount;
        retryCount = valVref_retryCount;
      end
      State_DATAVREF: begin
        activeSubstate = dataVref_substate;
        lastErrorCount = dataVref_lastErrorCount;
        retryCount = dataVref_retryCount;
      end
      State_SPEEDIDLE: begin
        activeSubstate = {4'b0, speedIdle_substate};
      end
      State_TXSELFCAL: begin
        activeSubstate = {4'b0, txSelfCal_substate};
      end
      State_RXCLKCAL: begin
        activeSubstate = {4'b0, rxClkCal_substate};
      end
      State_VALTRAINCENTER: begin
        activeSubstate = valTrainCenter_substate;
        lastErrorCount = valTrainCenter_lastErrorCount;
        retryCount = valTrainCenter_retryCount;
      end
      State_VALTRAINVREF: begin
        activeSubstate = valTrainVref_substate;
        lastErrorCount = valTrainVref_lastErrorCount;
        retryCount = valTrainVref_retryCount;
      end
      State_DATATRAINCENTER1: begin
        activeSubstate = dataTrainCenter1_substate;
        lastErrorCount = dataTrainCenter1_lastErrorCount;
        retryCount = dataTrainCenter1_retryCount;
      end
      State_DATATRAINVREF: begin
        activeSubstate = dataTrainVref_substate;
        lastErrorCount = dataTrainVref_lastErrorCount;
        retryCount = dataTrainVref_retryCount;
      end
      State_RXDESKEW: begin
        activeSubstate = rxDeskew_substate;
        lastErrorCount = rxDeskew_lastErrorCount;
        retryCount = rxDeskew_retryCount;
      end
      State_DATATRAINCENTER2: begin
        activeSubstate = dataTrainCenter2_substate;
        lastErrorCount = dataTrainCenter2_lastErrorCount;
        retryCount = dataTrainCenter2_retryCount;
      end
      State_LINKSPEED: begin
        activeSubstate = linkSpeed_substate;
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

```

<a id="Parameters-sv"></a>

## [32] Parameters.sv

```systemverilog
// FILE_INDEX: 32
// FILE_PATH : Parameters.sv

// Synthesizable SystemVerilog representation of Parameters.scala.
// The Chisel case class is elaboration-time configuration, so it becomes module parameters.
`default_nettype none

package LtsmParameters_pkg;
  parameter bit         DEFAULT_SB_FEATURE_EXTENSION = 1'b0;
  parameter bit         DEFAULT_UCIE_A               = 1'b0;
  parameter logic [1:0] DEFAULT_MODULE_ID            = 2'd0;
  parameter bit         DEFAULT_CLK_PHASE            = 1'b0;
  parameter bit         DEFAULT_CLK_MODE             = 1'b0;
  parameter logic [4:0] DEFAULT_VOLTAGE_SWING        = 5'd7;
  parameter logic [3:0] DEFAULT_MAX_LINK_SPEED       = 4'd3;

  // DATATRAINCENTER1 local transmitter sweep/deskew defaults.
  // The PI and deskew resolutions are implementation parameters rather than
  // UCIe protocol encodings.
  parameter int unsigned DEFAULT_D2C_PI_CODE_WIDTH = 6;
  parameter int unsigned DEFAULT_D2C_TX_DESKEW_CODE_WIDTH = 6;
  parameter int unsigned DEFAULT_D2C_DESKEW_STEPS_PER_PI = 1;
  parameter bit DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1;
  parameter logic [15:0] DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD = 16'd0;
  parameter int unsigned DEFAULT_D2C_MIN_LANE_WINDOW_STEPS = 1;
  parameter int unsigned DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS = 1;
  parameter int unsigned DEFAULT_D2C_MAX_TRAINING_RETRIES = 1;

  // Valid-receiver Vref sweep defaults shared by MBTRAIN.VALVREF and
  // MBTRAIN.VALTRAINVREF.  The voltage endpoints are PHY/DAC mapping
  // metadata; the digital state machines operate only on Vref codes.
  parameter int unsigned DEFAULT_VALID_VREF_VALUE_COUNT = 16;
  parameter int unsigned DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS = 250;
  parameter int unsigned DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS = 550;
  parameter logic [15:0] DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD = 16'd0;
  parameter int unsigned DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES = 1;
  // UCIe makes the operating-rate VALTRAINVREF optimization optional.
  parameter bit DEFAULT_VALTRAIN_VREF_ENABLE = 1'b1;

  // MBTRAIN.RXDESKEW defaults.  The RX delay control intentionally uses the
  // same unsigned per-lane code convention and default resolution as TX
  // deskew.  Code-to-time mapping remains an analog PHY responsibility.
  parameter int unsigned DEFAULT_RX_DESKEW_CODE_WIDTH =
    DEFAULT_D2C_TX_DESKEW_CODE_WIDTH;
  parameter int unsigned DEFAULT_RX_DESKEW_VALUE_COUNT =
    (1 << DEFAULT_RX_DESKEW_CODE_WIDTH);
  parameter logic [15:0] DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD =
    DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD;
  parameter int unsigned DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES =
    DEFAULT_D2C_MAX_TRAINING_RETRIES;
  parameter bit DEFAULT_RX_DESKEW_ENABLE = 1'b1;
endpackage

`default_nettype wire

```

<a id="Rdi-sv"></a>

## [33] Rdi.sv

```systemverilog
// FILE_INDEX: 33
// FILE_PATH : Rdi.sv

// Hand-translated synthesizable SystemVerilog.
// Source: Rdi(2).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_rdi_params_pkg;
  // SystemVerilog equivalent of the Scala elaboration-time RdiParams defaults.
  parameter int unsigned RDI_WIDTH    = 64;
  parameter int unsigned RDI_SB_WIDTH = 32;
endpackage

`default_nettype wire

```

<a id="RdiLinkManagementConstants-sv"></a>

## [34] RdiLinkManagementConstants.sv

```systemverilog
// FILE_INDEX: 34
// FILE_PATH : RdiLinkManagementConstants.sv

// Hand-translated synthesizable SystemVerilog.
// Source: RdiLinkManagementConstants(5).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_rdi_link_management_pkg;
  // Internal RDI Reset/Retrain-to-Active bring-up sub-state.
  typedef enum logic [2:0] {
    RDIBringUpState_IDLE                   = 3'h0,
    RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE = 3'h1,
    RDIBringUpState_BRINGUP_DONE           = 3'h2
  } RDIBringUpState_t;
endpackage

`default_nettype wire

```

<a id="RdiLinkManagementController-sv"></a>

## [35] RdiLinkManagementController.sv

```systemverilog
// FILE_INDEX: 35
// FILE_PATH : RdiLinkManagementController.sv

// Hand-translated synthesizable SystemVerilog.
// Source: RdiLinkManagementController(20260805-195425).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module RdiLinkManagementController (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic ltsm_lp_wake_req,
  output var logic ltsm_pl_wake_ack,

  output var logic ltsm_pl_clk_req,
  input  wire logic ltsm_lp_clk_ack,

  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t lp_state_req,
  output var UcieUPM_interfaces_pkg::PhyState_t    pl_state_sts,

  output var logic pl_stallreq,
  input  wire logic lp_stallack,

  output var logic rdi_pl_inband_pres,
  input  wire logic ltsm_pl_inband_pres,

  input  wire logic fdiNeedsRdiAwake,
  output var logic rdiAwake,
  output var logic rdiNeedsFdiAwake,
  input  wire logic fdiAwake,

  output var logic         sb_snd_valid,
  output var logic [127:0] sb_snd_msg,
  input  wire logic         sb_snd_ready,

  input  wire logic         sb_rcv_valid,
  input  wire logic [127:0] sb_rcv_msg,
  output var logic         sb_rcv_ready,

  input  wire logic lp_linkerror,

  output var logic        pl_phyinrecenter,
  input  wire logic [31:0] cycles_1us
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_rdi_link_management_pkg::*;
  import SidebandMsgGenerator_pkg::*;

  function automatic logic [127:0] zeroMessage();
    zeroMessage = 128'b0;
  endfunction

  // Registered sideband producer.
  (* keep = "true" *) logic [127:0] sb_snd_msg_reg;
  (* keep = "true" *) logic         sb_snd_vld_reg;
  logic [127:0] sb_snd_msg_reg_next;
  logic         sb_snd_vld_reg_next;

  logic [127:0] sb_snd_msg_next;
  logic         sb_snd_vld_next;
  logic [127:0] bringup_sb_snd;
  logic         bringup_sb_snd_vld;
  logic [127:0] global_sb_snd;
  logic         global_sb_snd_vld;

  assign sb_snd_msg   = sb_snd_msg_reg;
  assign sb_snd_valid = sb_snd_vld_reg;
  assign sb_rcv_ready = 1'b1;

  logic txFire;
  logic rxFire;
  assign txFire = sb_snd_valid && sb_snd_ready;
  assign rxFire = sb_rcv_valid && sb_rcv_ready;

  // Sideband decode signals retain their Chisel names for waveform readability.
  (* keep = "true" *) logic [127:0] tx_message;
  (* keep = "true" *) logic [127:0] rx_message;
  (* keep = "true" *) logic [63:0]  tx_header;
  (* keep = "true" *) logic [63:0]  rx_header;
  (* keep = "true" *) logic [7:0]   tx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgSub;
  (* keep = "true" *) logic [7:0]   tx_msgCode;
  (* keep = "true" *) logic [7:0]   rx_msgCode;
  (* keep = "true" *) logic [15:0]  rx_msgInfo;

  logic tx_is_rdi_req;
  logic tx_is_rdi_rsp;
  logic rx_is_rdi_req;
  logic rx_is_rdi_rsp;
  logic rx_is_rdi_rsp_stall;

  assign tx_message = sb_snd_msg_reg;
  assign rx_message = sb_rcv_msg;
  assign tx_header  = headerOf(tx_message);
  assign rx_header  = headerOf(rx_message);
  assign tx_msgSub  = UCIe2_Field_msgSub({64'b0, tx_header});
  assign rx_msgSub  = UCIe2_Field_msgSub({64'b0, rx_header});
  assign tx_msgCode = UCIe2_Field_msgCode({64'b0, tx_header});
  assign rx_msgCode = UCIe2_Field_msgCode({64'b0, rx_header});
  assign rx_msgInfo = UCIe2_Field_msgInfo({64'b0, rx_header});

  assign tx_is_rdi_req = UCIe2_isRdiLinkMgmtReq({64'b0, tx_header});
  assign tx_is_rdi_rsp = UCIe2_isRdiLinkMgmtRsp({64'b0, tx_header});
  assign rx_is_rdi_req = rxFire && UCIe2_isRdiLinkMgmtReq({64'b0, rx_header});
  assign rx_is_rdi_rsp = rxFire && UCIe2_isRdiLinkMgmtRsp({64'b0, rx_header});
  assign rx_is_rdi_rsp_stall = rx_is_rdi_rsp && (rx_msgInfo == UCIe2_MsgInfo_STALL);

  function automatic logic txIsRdiReq(input logic [7:0] sub);
    txIsRdiReq = txFire && tx_is_rdi_req && (tx_msgSub == sub);
  endfunction
  function automatic logic txIsRdiRsp(input logic [7:0] sub);
    txIsRdiRsp = txFire && tx_is_rdi_rsp && (tx_msgSub == sub);
  endfunction
  function automatic logic rxIsRdiReq(input logic [7:0] sub);
    rxIsRdiReq = rx_is_rdi_req && (rx_msgSub == sub);
  endfunction
  function automatic logic rxIsRdiRsp(input logic [7:0] sub);
    rxIsRdiRsp = rx_is_rdi_rsp && (rx_msgSub == sub);
  endfunction

  (* keep = "true" *) RDIBringUpState_t bringup_state_reg;
  RDIBringUpState_t bringup_state_reg_next;
  (* keep = "true" *) PhyState_t global_state_reg;
  PhyState_t global_state_reg_next;

  assign pl_state_sts       = global_state_reg;
  assign pl_phyinrecenter   = 1'b0;
  assign rdiNeedsFdiAwake   = 1'b1;
  assign ltsm_pl_clk_req    = 1'b1;

  logic rdiAwake_reg;
  logic ltsm_pl_wake_ack_reg;
  assign rdiAwake          = rdiAwake_reg;
  assign ltsm_pl_wake_ack  = ltsm_pl_wake_ack_reg;

  logic link_down_state;
  logic remote_notify_required;
  assign link_down_state = (global_state_reg == PhyState_linkError) ||
                           (global_state_reg == PhyState_disabled) ||
                           (global_state_reg == PhyState_linkReset);
  assign remote_notify_required = !(link_down_state && !pl_phyinrecenter);

  // Stall controller.
  logic stall_start;
  logic stall_release;
  logic stall_req;
  (* keep = "true" *) logic stallhandler_handshake_done;
  (* keep = "true" *) logic stall_4phase_done;
  (* keep = "true" *) logic stall_busy;

  StallCtrl stall_module (
    .clock   (clock),
    .reset_n   (reset_n),
    .start   (stall_start),
    .release_i (stall_release),
    .ack     (lp_stallack),
    .req     (stall_req),
    .aligned (stallhandler_handshake_done),
    .done    (stall_4phase_done),
    .busy    (stall_busy)
  );
  assign pl_stallreq = stall_req;

  (* keep = "true" *) logic retrain_to_active_initiated;
  logic retrain_to_active_initiated_next;
  wire retrain_internal = 1'b0;

  (* keep = "true" *) PhyStateReq_t lp_state_req_prev_reg;
  wire reset_internal = !reset_n;

  (* keep = "true" *) logic [7:0] pending_req_sub_reg;
  (* keep = "true" *) logic       waiting_rsp_reg;
  logic [7:0] pending_req_sub_reg_next;
  logic       waiting_rsp_reg_next;

  logic local_req_sent;
  logic sideband_stall_received;
  logic expected_remote_rsp_received;
  assign local_req_sent = txFire && tx_is_rdi_req;
  assign sideband_stall_received = waiting_rsp_reg && rx_is_rdi_rsp_stall &&
                                   (rx_msgSub == pending_req_sub_reg);
  assign expected_remote_rsp_received = waiting_rsp_reg && rx_is_rdi_rsp &&
                                        !rx_is_rdi_rsp_stall &&
                                        (rx_msgSub == pending_req_sub_reg);

  logic rdi_timeout_sidebandReqTimerBusy;
  logic rdi_timeout_sidebandReqTimeoutFlag;
  logic rdi_timeout_stallRefreshDue;
  logic rdi_timeout_linkErrorResidencyDone;

  RdiTimeoutController rdi_timeout (
    .clock                     (clock),
    .reset_n                   (reset_n),
    .cycles1us                 (cycles_1us),
    .startSidebandReqTimer     (local_req_sent),
    .sidebandRspReceived       (expected_remote_rsp_received),
    .sidebandStallReceived     (sideband_stall_received),
    .clearSidebandReqTimer     (!reset_n || (global_state_reg == PhyState_linkError)),
    .sidebandReqTimerBusy      (rdi_timeout_sidebandReqTimerBusy),
    .sidebandReqTimeoutFlag    (rdi_timeout_sidebandReqTimeoutFlag),
    .clearTimeoutFlag          (!reset_n || (global_state_reg == PhyState_linkError)),
    .stallResponseActive       (1'b0),
    .stallSent                 (1'b0),
    .stallRefreshDue           (rdi_timeout_stallRefreshDue),
    .inLinkError               (global_state_reg == PhyState_linkError),
    .linkErrorResidencyDone    (rdi_timeout_linkErrorResidencyDone)
  );

  wire linkerror_internal = rdi_timeout_sidebandReqTimeoutFlag;

  (* keep = "true" *) logic disabled_procedure_done;
  (* keep = "true" *) logic linkreset_procedure_done;
  (* keep = "true" *) logic retrain_procedure_done;
  (* keep = "true" *) logic linkerror_procedure_done;
  logic disabled_procedure_done_next;
  logic linkreset_procedure_done_next;
  logic retrain_procedure_done_next;
  logic linkerror_procedure_done_next;

  wire linkreset_internal = 1'b0;

  (* keep = "true" *) logic reset_to_active_inialitated;
  logic reset_to_active_inialitated_next;
  (* keep = "true" *) logic bringup_start;
  logic bringup_start_next;
  (* keep = "true" *) logic bringup_done;
  logic bringup_done_next;

  (* keep = "true" *) logic remote_linkerror_req_flag;
  (* keep = "true" *) logic remote_linkerror_rsp_flag;
  (* keep = "true" *) logic local_linkerror_req_flag;
  (* keep = "true" *) logic local_linkerror_rsp_flag;
  logic remote_linkerror_req_flag_next;
  logic remote_linkerror_rsp_flag_next;
  logic local_linkerror_req_flag_next;
  logic local_linkerror_rsp_flag_next;

  (* keep = "true" *) logic remote_disabled_req_flag;
  (* keep = "true" *) logic remote_disabled_rsp_flag;
  (* keep = "true" *) logic local_disabled_req_flag;
  (* keep = "true" *) logic local_disabled_rsp_flag;
  logic remote_disabled_req_flag_next;
  logic remote_disabled_rsp_flag_next;
  logic local_disabled_req_flag_next;
  logic local_disabled_rsp_flag_next;

  (* keep = "true" *) logic remote_linkreset_req_flag;
  (* keep = "true" *) logic remote_linkreset_rsp_flag;
  (* keep = "true" *) logic local_linkreset_req_flag;
  (* keep = "true" *) logic local_linkreset_rsp_flag;
  logic remote_linkreset_req_flag_next;
  logic remote_linkreset_rsp_flag_next;
  logic local_linkreset_req_flag_next;
  logic local_linkreset_rsp_flag_next;

  (* keep = "true" *) logic remote_retrain_req_flag;
  (* keep = "true" *) logic remote_retrain_rsp_flag;
  (* keep = "true" *) logic local_retrain_req_flag;
  (* keep = "true" *) logic local_retrain_rsp_flag;
  logic remote_retrain_req_flag_next;
  logic remote_retrain_rsp_flag_next;
  logic local_retrain_req_flag_next;
  logic local_retrain_rsp_flag_next;

  (* keep = "true" *) logic remote_active_entry_req_flag;
  (* keep = "true" *) logic remote_active_entry_rsp_flag;
  (* keep = "true" *) logic local_active_entry_req_flag;
  (* keep = "true" *) logic local_active_entry_rsp_flag;
  logic remote_active_entry_req_flag_next;
  logic remote_active_entry_rsp_flag_next;
  logic local_active_entry_req_flag_next;
  logic local_active_entry_rsp_flag_next;

  logic linkreset_handshake_done;
  logic disabled_handshake_done;
  logic linkerror_handshake_done;
  logic retrain_handshake_done;
  assign linkreset_handshake_done =
    (local_linkreset_req_flag && remote_linkreset_rsp_flag) ||
    (remote_linkreset_req_flag && local_linkreset_rsp_flag);
  assign disabled_handshake_done =
    (local_disabled_req_flag && remote_disabled_rsp_flag) ||
    (remote_disabled_req_flag && local_disabled_rsp_flag);
  assign linkerror_handshake_done =
    (local_linkerror_req_flag && remote_linkerror_rsp_flag) ||
    (remote_linkerror_req_flag && local_linkerror_rsp_flag);
  assign retrain_handshake_done =
    (local_retrain_req_flag && remote_retrain_rsp_flag) ||
    (remote_retrain_req_flag && local_retrain_rsp_flag);

  logic linkerror_asserted;
  wire disabled_internal = 1'b0;
  logic disabled_req;
  logic retrain_req;
  logic linkreset_req;
  assign linkerror_asserted = lp_linkerror || linkerror_internal || remote_linkerror_req_flag;
  assign disabled_req = (lp_state_req == PhyStateReq_disabled) || disabled_internal || remote_disabled_req_flag;
  assign retrain_req  = (lp_state_req == PhyStateReq_retrain) || retrain_internal || remote_retrain_req_flag;
  assign linkreset_req = (lp_state_req == PhyStateReq_linkReset) || linkreset_internal || remote_linkreset_req_flag;

  (* keep = "true" *) logic nopToActive;
  (* keep = "true" *) logic nopToDisabled;
  (* keep = "true" *) logic nopToLinkreset;

  (* keep = "true" *) logic pendingDisabledFromReset;
  (* keep = "true" *) logic pendingLinkresetFromReset;
  logic pendingDisabledFromReset_next;
  logic pendingLinkresetFromReset_next;

  logic disabled_entry_rst;
  logic linkreset_entry_rst;
  assign disabled_entry_rst = pendingDisabledFromReset || nopToDisabled ||
                              disabled_internal || remote_disabled_req_flag;
  assign linkreset_entry_rst = pendingLinkresetFromReset || nopToLinkreset ||
                               linkreset_internal || remote_linkreset_req_flag;

  logic active_exit_needs_stall;
  assign active_exit_needs_stall = (global_state_reg == PhyState_active) &&
                                   !linkerror_asserted &&
                                   (disabled_req || linkreset_req || retrain_req);
  assign stall_start   = active_exit_needs_stall && !stall_busy;
  assign stall_release = (global_state_reg != PhyState_active);

  logic rdiStateAllowsInband;
  logic rdiPlInbandPresNext;
  (* keep = "true" *) logic rdiPlInbandPresReg;
  assign rdiStateAllowsInband = (global_state_reg == PhyState_reset) ||
                                (global_state_reg == PhyState_active) ||
                                (global_state_reg == PhyState_retrain);
  assign rdiPlInbandPresNext = ltsm_pl_inband_pres && rdiStateAllowsInband &&
                               !linkerror_asserted;
  assign rdi_pl_inband_pres = rdiPlInbandPresReg;

  // Combinational next-state logic. Register expressions use current register values,
  // matching Chisel's synchronous Reg semantics and source-order connection priority.
  always_comb begin
    sb_snd_msg_reg_next = sb_snd_msg_reg;
    sb_snd_vld_reg_next = sb_snd_vld_reg;

    bringup_state_reg_next = bringup_state_reg;
    global_state_reg_next  = global_state_reg;
    retrain_to_active_initiated_next = retrain_to_active_initiated;
    pending_req_sub_reg_next = pending_req_sub_reg;
    waiting_rsp_reg_next     = waiting_rsp_reg;

    disabled_procedure_done_next = disabled_procedure_done;
    linkreset_procedure_done_next = linkreset_procedure_done;
    retrain_procedure_done_next   = retrain_procedure_done;
    linkerror_procedure_done_next = linkerror_procedure_done;

    reset_to_active_inialitated_next = reset_to_active_inialitated;
    bringup_start_next = bringup_start;
    bringup_done_next  = bringup_done;

    remote_linkerror_req_flag_next = remote_linkerror_req_flag;
    remote_linkerror_rsp_flag_next = remote_linkerror_rsp_flag;
    local_linkerror_req_flag_next  = local_linkerror_req_flag;
    local_linkerror_rsp_flag_next  = local_linkerror_rsp_flag;

    remote_disabled_req_flag_next = remote_disabled_req_flag;
    remote_disabled_rsp_flag_next = remote_disabled_rsp_flag;
    local_disabled_req_flag_next  = local_disabled_req_flag;
    local_disabled_rsp_flag_next  = local_disabled_rsp_flag;

    remote_linkreset_req_flag_next = remote_linkreset_req_flag;
    remote_linkreset_rsp_flag_next = remote_linkreset_rsp_flag;
    local_linkreset_req_flag_next  = local_linkreset_req_flag;
    local_linkreset_rsp_flag_next  = local_linkreset_rsp_flag;

    remote_retrain_req_flag_next = remote_retrain_req_flag;
    remote_retrain_rsp_flag_next = remote_retrain_rsp_flag;
    local_retrain_req_flag_next  = local_retrain_req_flag;
    local_retrain_rsp_flag_next  = local_retrain_rsp_flag;

    remote_active_entry_req_flag_next = remote_active_entry_req_flag;
    remote_active_entry_rsp_flag_next = remote_active_entry_rsp_flag;
    local_active_entry_req_flag_next  = local_active_entry_req_flag;
    local_active_entry_rsp_flag_next  = local_active_entry_rsp_flag;

    pendingDisabledFromReset_next  = pendingDisabledFromReset;
    pendingLinkresetFromReset_next = pendingLinkresetFromReset;

    bringup_sb_snd     = zeroMessage();
    bringup_sb_snd_vld = 1'b0;
    global_sb_snd      = zeroMessage();
    global_sb_snd_vld  = 1'b0;
    sb_snd_msg_next    = zeroMessage();
    sb_snd_vld_next    = 1'b0;

    // Outstanding request tracking.
    if (global_state_reg == PhyState_linkError) begin
      pending_req_sub_reg_next = 8'd0;
      waiting_rsp_reg_next     = 1'b0;
    end else if (local_req_sent) begin
      pending_req_sub_reg_next = tx_msgSub;
      waiting_rsp_reg_next     = 1'b1;
    end else if (expected_remote_rsp_received) begin
      waiting_rsp_reg_next = 1'b0;
    end

    // Sideband transaction flags.
    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_LINKERROR))
      remote_linkerror_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      remote_linkerror_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKERROR))
      remote_linkerror_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      remote_linkerror_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_LINKERROR))
      local_linkerror_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      local_linkerror_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKERROR))
      local_linkerror_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      local_linkerror_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_DISABLE))
      remote_disabled_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      remote_disabled_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      remote_disabled_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      remote_disabled_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_DISABLE))
      local_disabled_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      local_disabled_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      local_disabled_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      local_disabled_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      remote_linkreset_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      remote_linkreset_req_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      local_linkreset_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      local_linkreset_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      remote_linkreset_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      remote_linkreset_rsp_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      local_linkreset_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      local_linkreset_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_RETRAIN))
      remote_retrain_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      remote_retrain_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_RETRAIN))
      remote_retrain_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      remote_retrain_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_RETRAIN))
      local_retrain_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      local_retrain_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_RETRAIN))
      local_retrain_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      local_retrain_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      remote_active_entry_req_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      remote_active_entry_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      remote_active_entry_rsp_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      remote_active_entry_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      local_active_entry_req_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      local_active_entry_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      local_active_entry_rsp_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      local_active_entry_rsp_flag_next = 1'b0;

    // Latch Reset-exit requests using the registered NOP transition indicators.
    if (global_state_reg != PhyState_reset) begin
      pendingDisabledFromReset_next  = 1'b0;
      pendingLinkresetFromReset_next = 1'b0;
    end else begin
      if (nopToDisabled)
        pendingDisabledFromReset_next = 1'b1;
      if (nopToLinkreset)
        pendingLinkresetFromReset_next = 1'b1;
    end

    // RDI bring-up sub-FSM.
    case (bringup_state_reg)
      RDIBringUpState_IDLE: begin
        if (bringup_start)
          bringup_state_reg_next = RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE;
      end

      RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE: begin
        if (!local_active_entry_req_flag) begin
          bringup_sb_snd = UCIe2_RDI_reqActive(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
          bringup_sb_snd_vld = 1'b1;
        end else if (remote_active_entry_req_flag && !local_active_entry_rsp_flag) begin
          bringup_sb_snd = UCIe2_RDI_rspActive(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                               UCIe2_MsgInfo_REGULAR);
          bringup_sb_snd_vld = 1'b1;
        end else if (remote_active_entry_rsp_flag) begin
          bringup_state_reg_next = RDIBringUpState_BRINGUP_DONE;
        end
      end

      RDIBringUpState_BRINGUP_DONE: begin
        bringup_done_next = 1'b1;
        if (global_state_reg == PhyState_active) begin
          bringup_state_reg_next = RDIBringUpState_IDLE;
          bringup_done_next = 1'b0;
        end
      end

      default: bringup_state_reg_next = RDIBringUpState_IDLE;
    endcase

    // Global RDI state machine.
    case (global_state_reg)
      PhyState_reset: begin
        if (reset_to_active_inialitated) begin
          global_sb_snd     = zeroMessage();
          global_sb_snd_vld = 1'b0;
        end

        if (linkerror_asserted) begin
          if (remote_linkerror_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end
          linkerror_procedure_done_next = 1'b0;
          global_state_reg_next = PhyState_linkError;
        end else if ((lp_state_req == PhyStateReq_nop) && !reset_to_active_inialitated) begin
          global_state_reg_next = PhyState_reset;
        end else if (disabled_entry_rst && !reset_to_active_inialitated) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) begin
            global_state_reg_next = PhyState_disabled;
            disabled_procedure_done_next = 1'b0;
          end else if (!remote_disabled_req_flag && !remote_notify_required) begin
            global_state_reg_next = PhyState_disabled;
            disabled_procedure_done_next = 1'b0;
          end
        end else if (linkreset_entry_rst && !reset_to_active_inialitated) begin
          if (remote_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end else if (!remote_linkreset_req_flag && !remote_notify_required) begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end
        end else if (((lp_state_req == PhyStateReq_active) &&
                      (lp_state_req_prev_reg == PhyStateReq_nop)) ||
                     reset_to_active_inialitated) begin
          if (!reset_to_active_inialitated) begin
            bringup_start_next = 1'b1;
            reset_to_active_inialitated_next = 1'b1;
          end
          if (bringup_done && reset_to_active_inialitated) begin
            global_state_reg_next = PhyState_active;
            reset_to_active_inialitated_next = 1'b0;
            bringup_start_next = 1'b0;
          end
        end
      end

      PhyState_active: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (linkerror_asserted) begin
          if (remote_linkerror_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end
          linkerror_procedure_done_next = 1'b0;
          global_state_reg_next = PhyState_linkError;
        end else if (disabled_req && stallhandler_handshake_done) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end else if (!(remote_disabled_req_flag || remote_notify_required)) begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end
        end else if (linkreset_req && stallhandler_handshake_done) begin
          if (remote_linkreset_req_flag && !local_linkreset_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) begin
            linkreset_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_linkReset;
          end else if (!(remote_linkreset_req_flag || remote_notify_required)) begin
            linkreset_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_linkReset;
          end
        end else if (retrain_req && stallhandler_handshake_done) begin
          if (remote_retrain_req_flag && !local_retrain_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspRetrain(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_retrain_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqRetrain(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_retrain_req_flag || remote_notify_required) && retrain_handshake_done) begin
            retrain_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_retrain;
          end else if (!remote_retrain_req_flag && !remote_notify_required) begin
            retrain_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_retrain;
          end
        end
      end

      PhyState_retrain: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (linkerror_asserted) begin
          global_state_reg_next = PhyState_linkError;
        end else if (!retrain_to_active_initiated &&
                     ((lp_state_req == PhyStateReq_disabled) || remote_disabled_req_flag)) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if (remote_disabled_req_flag || remote_notify_required) begin
            if (disabled_handshake_done) begin
              disabled_procedure_done_next = 1'b0;
              global_state_reg_next = PhyState_disabled;
            end
          end else begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end
        end else if (!retrain_to_active_initiated &&
                     ((lp_state_req == PhyStateReq_linkReset) || remote_linkreset_req_flag)) begin
          if (remote_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if (remote_linkreset_req_flag || remote_notify_required) begin
            if (linkreset_handshake_done) begin
              global_state_reg_next = PhyState_linkReset;
              linkreset_procedure_done_next = 1'b0;
            end
          end else begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end
        end else if ((lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (lp_state_req == PhyStateReq_active) &&
                     !retrain_to_active_initiated) begin
          retrain_to_active_initiated_next = 1'b1;
          bringup_start_next = 1'b1;
        end else if (retrain_to_active_initiated) begin
          if (bringup_done) begin
            global_state_reg_next = PhyState_active;
            retrain_to_active_initiated_next = 1'b0;
            bringup_start_next = 1'b0;
          end
        end
      end

      PhyState_linkReset: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (lp_linkerror || linkerror_internal) begin
          global_state_reg_next = PhyState_linkError;
        end else if (disabled_internal || (lp_state_req == PhyStateReq_disabled)) begin
          global_state_reg_next = PhyState_disabled;
        end else if (((lp_state_req == PhyStateReq_active) || reset_internal) &&
                     linkreset_procedure_done) begin
          global_state_reg_next = PhyState_reset;
        end else if (!linkreset_procedure_done) begin
          // Source TODO completion condition is currently true.B.
          linkreset_procedure_done_next = 1'b1;
        end
      end

      PhyState_disabled: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (lp_linkerror || linkerror_internal) begin
          global_state_reg_next = PhyState_linkError;
        end else if (((lp_state_req == PhyStateReq_active) || reset_internal) &&
                     disabled_procedure_done) begin
          global_state_reg_next = PhyState_reset;
        end else if (!disabled_procedure_done) begin
          // Source TODO completion condition is currently true.B.
          disabled_procedure_done_next = 1'b1;
        end
      end

      PhyState_linkError: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (!linkerror_procedure_done)
          linkerror_procedure_done_next = 1'b1;

        if (lp_linkerror || linkerror_internal || remote_linkerror_req_flag) begin
          global_state_reg_next = PhyState_linkError;
          linkerror_procedure_done_next = 1'b0;
        end else if (reset_internal ||
                     ((lp_state_req == PhyStateReq_active) && !lp_linkerror &&
                      rdi_timeout_linkErrorResidencyDone)) begin
          global_state_reg_next = PhyState_reset;
        end
      end

      default: global_state_reg_next = PhyState_reset;
    endcase

    // Sideband source arbitration: bring-up has priority over global transitions.
    if (bringup_sb_snd_vld) begin
      sb_snd_msg_next = bringup_sb_snd;
      sb_snd_vld_next = 1'b1;
    end else if (global_sb_snd_vld) begin
      sb_snd_msg_next = global_sb_snd;
      sb_snd_vld_next = 1'b1;
    end

    // Hold a pending valid message until accepted. A firing cycle clears the
    // register and does not simultaneously load another candidate, matching Chisel.
    if (sb_snd_vld_reg) begin
      if (txFire) begin
        sb_snd_msg_reg_next = zeroMessage();
        sb_snd_vld_reg_next = 1'b0;
      end
    end else begin
      sb_snd_msg_reg_next = sb_snd_msg_next;
      sb_snd_vld_reg_next = sb_snd_vld_next;
    end
  end

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      sb_snd_msg_reg <= 128'b0;
      sb_snd_vld_reg <= 1'b0;
      bringup_state_reg <= RDIBringUpState_IDLE;
      global_state_reg  <= PhyState_reset;
      rdiAwake_reg <= 1'b0;
      ltsm_pl_wake_ack_reg <= 1'b0;
      retrain_to_active_initiated <= 1'b0;
      lp_state_req_prev_reg <= PhyStateReq_nop;
      pending_req_sub_reg <= 8'd0;
      waiting_rsp_reg <= 1'b0;
      disabled_procedure_done <= 1'b1;
      linkreset_procedure_done <= 1'b1;
      retrain_procedure_done <= 1'b1;
      linkerror_procedure_done <= 1'b1;
      reset_to_active_inialitated <= 1'b0;
      bringup_start <= 1'b0;
      bringup_done <= 1'b0;
      remote_linkerror_req_flag <= 1'b0;
      remote_linkerror_rsp_flag <= 1'b0;
      local_linkerror_req_flag <= 1'b0;
      local_linkerror_rsp_flag <= 1'b0;
      remote_disabled_req_flag <= 1'b0;
      remote_disabled_rsp_flag <= 1'b0;
      local_disabled_req_flag <= 1'b0;
      local_disabled_rsp_flag <= 1'b0;
      remote_linkreset_req_flag <= 1'b0;
      remote_linkreset_rsp_flag <= 1'b0;
      local_linkreset_req_flag <= 1'b0;
      local_linkreset_rsp_flag <= 1'b0;
      remote_retrain_req_flag <= 1'b0;
      remote_retrain_rsp_flag <= 1'b0;
      local_retrain_req_flag <= 1'b0;
      local_retrain_rsp_flag <= 1'b0;
      remote_active_entry_req_flag <= 1'b0;
      remote_active_entry_rsp_flag <= 1'b0;
      local_active_entry_req_flag <= 1'b0;
      local_active_entry_rsp_flag <= 1'b0;
      nopToActive <= 1'b0;
      nopToDisabled <= 1'b0;
      nopToLinkreset <= 1'b0;
      pendingDisabledFromReset <= 1'b0;
      pendingLinkresetFromReset <= 1'b0;
      rdiPlInbandPresReg <= 1'b0;
    end else begin
      sb_snd_msg_reg <= sb_snd_msg_reg_next;
      sb_snd_vld_reg <= sb_snd_vld_reg_next;
      bringup_state_reg <= bringup_state_reg_next;
      global_state_reg  <= global_state_reg_next;
      rdiAwake_reg <= fdiNeedsRdiAwake;
      ltsm_pl_wake_ack_reg <= ltsm_lp_wake_req;
      retrain_to_active_initiated <= retrain_to_active_initiated_next;
      lp_state_req_prev_reg <= lp_state_req;
      pending_req_sub_reg <= pending_req_sub_reg_next;
      waiting_rsp_reg <= waiting_rsp_reg_next;
      disabled_procedure_done <= disabled_procedure_done_next;
      linkreset_procedure_done <= linkreset_procedure_done_next;
      retrain_procedure_done <= retrain_procedure_done_next;
      linkerror_procedure_done <= linkerror_procedure_done_next;
      reset_to_active_inialitated <= reset_to_active_inialitated_next;
      bringup_start <= bringup_start_next;
      bringup_done <= bringup_done_next;
      remote_linkerror_req_flag <= remote_linkerror_req_flag_next;
      remote_linkerror_rsp_flag <= remote_linkerror_rsp_flag_next;
      local_linkerror_req_flag <= local_linkerror_req_flag_next;
      local_linkerror_rsp_flag <= local_linkerror_rsp_flag_next;
      remote_disabled_req_flag <= remote_disabled_req_flag_next;
      remote_disabled_rsp_flag <= remote_disabled_rsp_flag_next;
      local_disabled_req_flag <= local_disabled_req_flag_next;
      local_disabled_rsp_flag <= local_disabled_rsp_flag_next;
      remote_linkreset_req_flag <= remote_linkreset_req_flag_next;
      remote_linkreset_rsp_flag <= remote_linkreset_rsp_flag_next;
      local_linkreset_req_flag <= local_linkreset_req_flag_next;
      local_linkreset_rsp_flag <= local_linkreset_rsp_flag_next;
      remote_retrain_req_flag <= remote_retrain_req_flag_next;
      remote_retrain_rsp_flag <= remote_retrain_rsp_flag_next;
      local_retrain_req_flag <= local_retrain_req_flag_next;
      local_retrain_rsp_flag <= local_retrain_rsp_flag_next;
      remote_active_entry_req_flag <= remote_active_entry_req_flag_next;
      remote_active_entry_rsp_flag <= remote_active_entry_rsp_flag_next;
      local_active_entry_req_flag <= local_active_entry_req_flag_next;
      local_active_entry_rsp_flag <= local_active_entry_rsp_flag_next;
      nopToActive <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (lp_state_req == PhyStateReq_active);
      nopToDisabled <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                       (lp_state_req == PhyStateReq_disabled);
      nopToLinkreset <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                        (lp_state_req == PhyStateReq_linkReset);
      pendingDisabledFromReset <= pendingDisabledFromReset_next;
      pendingLinkresetFromReset <= pendingLinkresetFromReset_next;
      rdiPlInbandPresReg <= rdiPlInbandPresNext;
    end
  end

  // Deliberately unused in the source revision; retained as named signals/ports.
  wire _unused_ok = &{1'b0, ltsm_lp_clk_ack, fdiAwake,
                      rdi_timeout_sidebandReqTimerBusy,
                      rdi_timeout_stallRefreshDue,
                      linkerror_handshake_done,
                      stall_4phase_done};
endmodule

`default_nettype wire

```

<a id="RdiTimeoutController-sv"></a>

## [36] RdiTimeoutController.sv

```systemverilog
// FILE_INDEX: 36
// FILE_PATH : RdiTimeoutController.sv

// Hand-translated synthesizable SystemVerilog.
// Source: RdiTimeoutController(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module RdiTimeoutController (
  input  wire logic        clock,
  input  wire logic        reset_n,

  input  wire logic [31:0] cycles1us,

  input  wire logic startSidebandReqTimer,
  input  wire logic sidebandRspReceived,
  input  wire logic sidebandStallReceived,
  input  wire logic clearSidebandReqTimer,

  output var logic sidebandReqTimerBusy,
  output var logic sidebandReqTimeoutFlag,
  input  wire logic clearTimeoutFlag,

  input  wire logic stallResponseActive,
  input  wire logic stallSent,
  output var logic stallRefreshDue,

  input  wire logic inLinkError,
  output var logic linkErrorResidencyDone
);
  logic [63:0] timeout4ms;
  logic [63:0] timeout8ms;
  logic [63:0] timeout16ms;

  assign timeout4ms  = {32'b0, cycles1us} * 64'd4000;
  assign timeout8ms  = {32'b0, cycles1us} * 64'd8000;
  assign timeout16ms = {32'b0, cycles1us} * 64'd16000;

  function automatic logic [63:0] lastCycle(input logic [63:0] limit);
    lastCycle = (limit == 64'd0) ? 64'd0 : (limit - 64'd1);
  endfunction

  (* keep = "true" *) logic        sbBusy;
  (* keep = "true" *) logic [63:0] sbCounter;
  (* keep = "true" *) logic        sbTimeoutFlag;

  (* keep = "true" *) logic [63:0] stallCounter;
  (* keep = "true" *) logic        stallDue;

  (* keep = "true" *) logic [63:0] linkErrorCounter;
  (* keep = "true" *) logic        linkErrorDone;

  assign sidebandReqTimerBusy   = sbBusy;
  assign sidebandReqTimeoutFlag = sbTimeoutFlag;
  assign stallRefreshDue        = stallDue;
  assign linkErrorResidencyDone = linkErrorDone;

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      sbBusy          <= 1'b0;
      sbCounter       <= 64'd0;
      sbTimeoutFlag   <= 1'b0;
      stallCounter    <= 64'd0;
      stallDue        <= 1'b0;
      linkErrorCounter <= 64'd0;
      linkErrorDone   <= 1'b0;
    end else begin
      // This separate clear precedes the timer logic, matching the Chisel
      // connection priority: a timeout set below wins if both occur together.
      if (clearTimeoutFlag)
        sbTimeoutFlag <= 1'b0;

      if (clearSidebandReqTimer || sidebandRspReceived) begin
        sbBusy    <= 1'b0;
        sbCounter <= 64'd0;
      end else if (startSidebandReqTimer) begin
        sbBusy    <= 1'b1;
        sbCounter <= 64'd0;
      end else if (sbBusy && sidebandStallReceived) begin
        sbCounter <= 64'd0;
      end else if (sbBusy) begin
        if (sbCounter >= lastCycle(timeout8ms)) begin
          sbTimeoutFlag <= 1'b1;
          sbBusy        <= 1'b0;
          sbCounter     <= 64'd0;
        end else begin
          sbCounter <= sbCounter + 64'd1;
        end
      end

      if (!stallResponseActive) begin
        stallCounter <= 64'd0;
        stallDue     <= 1'b0;
      end else if (stallSent) begin
        stallCounter <= 64'd0;
        stallDue     <= 1'b0;
      end else if (!stallDue) begin
        if (stallCounter >= lastCycle(timeout4ms)) begin
          stallDue <= 1'b1;
        end else begin
          stallCounter <= stallCounter + 64'd1;
        end
      end

      if (!inLinkError) begin
        linkErrorCounter <= 64'd0;
        linkErrorDone    <= 1'b0;
      end else if (!linkErrorDone) begin
        if (linkErrorCounter >= lastCycle(timeout16ms)) begin
          linkErrorDone <= 1'b1;
        end else begin
          linkErrorCounter <= linkErrorCounter + 64'd1;
        end
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="RxInitD2CPointTestReceiverFSM-sv"></a>

## [37] RxInitD2CPointTestReceiverFSM.sv

```systemverilog
// FILE_INDEX: 37
// FILE_PATH : RxInitD2CPointTestReceiverFSM.sv

// Receiver-side controller for a UCIe receiver-initiated D2C point test.
//
// This FSM is the initiator of the transaction because the local receiver is
// the component being optimized.  It is intentionally separate from
// TxInitD2CPointTestReceiverFSM: in a Tx-initiated test the receiver is the
// responder and returns results over sideband, while in an Rx-initiated test
// the receiver sends Start/End requests and captures the local comparison
// result when the remote transmitter reports Tx Count Done.
`default_nettype none

module RxInitD2CPointTestReceiverFSM #(
    parameter integer RESULT_WIDTH = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  output      logic busy,
  output      logic done,
  output      logic [3:0] state,

  output      logic configureReceiver,

  output      logic sendStartRxInitD2CPointTestReq,
  input  wire logic sentStartRxInitD2CPointTestReq,
  input  wire logic receivedStartRxInitD2CPointTestResp,

  input  wire logic receivedLfsrClearErrorReq,
  output      logic clearComparisonErrors,
  output      logic sendLfsrClearErrorResp,
  input  wire logic sentLfsrClearErrorResp,

  input  wire logic receivedRxInitD2CTxCountDoneReq,
  input  wire logic [RESULT_WIDTH-1:0] detectedValidPattern,
  output      logic sendRxInitD2CTxCountDoneResp,
  input  wire logic sentRxInitD2CTxCountDoneResp,

  output      logic sendEndRxInitD2CPointTestReq,
  input  wire logic sentEndRxInitD2CPointTestReq,
  input  wire logic receivedEndRxInitD2CPointTestResp,

  output      logic [RESULT_WIDTH-1:0] pointTestPass
);
  typedef enum logic [3:0] {
    RxInitReceiverState_idle              = 4'h0,
    RxInitReceiverState_configure         = 4'h1,
    RxInitReceiverState_sendStartReq      = 4'h2,
    RxInitReceiverState_waitStartResp     = 4'h3,
    RxInitReceiverState_waitClearReq      = 4'h4,
    RxInitReceiverState_clearErrors       = 4'h5,
    RxInitReceiverState_sendClearResp     = 4'h6,
    RxInitReceiverState_waitCountDoneReq  = 4'h7,
    RxInitReceiverState_sendCountDoneResp = 4'h8,
    RxInitReceiverState_sendEndReq        = 4'h9,
    RxInitReceiverState_waitEndResp       = 4'hA,
    RxInitReceiverState_finish            = 4'hB
  } RxInitReceiverState_t;

  (* keep = "true" *) RxInitReceiverState_t stateReg;
  (* keep = "true" *) logic [RESULT_WIDTH-1:0] pointTestPassReg;
  (* keep = "true" *) logic previousStart;

  wire startPulse = start && !previousStart;

  always_comb begin
    busy = (stateReg != RxInitReceiverState_idle) &&
           (stateReg != RxInitReceiverState_finish);
    done = (stateReg == RxInitReceiverState_finish);
    state = stateReg;

    configureReceiver = (stateReg == RxInitReceiverState_configure);
    sendStartRxInitD2CPointTestReq =
      (stateReg == RxInitReceiverState_sendStartReq);
    clearComparisonErrors = (stateReg == RxInitReceiverState_clearErrors);
    sendLfsrClearErrorResp = (stateReg == RxInitReceiverState_sendClearResp);
    sendRxInitD2CTxCountDoneResp =
      (stateReg == RxInitReceiverState_sendCountDoneResp);
    sendEndRxInitD2CPointTestReq =
      (stateReg == RxInitReceiverState_sendEndReq);
    pointTestPass = pointTestPassReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg         <= RxInitReceiverState_idle;
      pointTestPassReg <= 1'b0;
      previousStart    <= 1'b0;
    end else begin
      previousStart <= start;

      // A new point-test pulse restarts the controller from either idle or the
      // sticky finish state.  The containing Vref sweep emits one start pulse
      // for each tested Vref code and one for final verification.
      if (startPulse) begin
        stateReg         <= RxInitReceiverState_configure;
        pointTestPassReg <= 1'b0;
      end else begin
        unique case (stateReg)
          RxInitReceiverState_idle: ;

          RxInitReceiverState_configure:
            stateReg <= RxInitReceiverState_sendStartReq;

          RxInitReceiverState_sendStartReq: begin
            if (sentStartRxInitD2CPointTestReq)
              stateReg <= RxInitReceiverState_waitStartResp;
          end

          RxInitReceiverState_waitStartResp: begin
            if (receivedStartRxInitD2CPointTestResp)
              stateReg <= RxInitReceiverState_waitClearReq;
          end

          RxInitReceiverState_waitClearReq: begin
            if (receivedLfsrClearErrorReq)
              stateReg <= RxInitReceiverState_clearErrors;
          end

          RxInitReceiverState_clearErrors:
            stateReg <= RxInitReceiverState_sendClearResp;

          RxInitReceiverState_sendClearResp: begin
            if (sentLfsrClearErrorResp)
              stateReg <= RxInitReceiverState_waitCountDoneReq;
          end

          RxInitReceiverState_waitCountDoneReq: begin
            if (receivedRxInitD2CTxCountDoneReq) begin
              pointTestPassReg <= detectedValidPattern;
              stateReg <= RxInitReceiverState_sendCountDoneResp;
            end
          end

          RxInitReceiverState_sendCountDoneResp: begin
            if (sentRxInitD2CTxCountDoneResp)
              stateReg <= RxInitReceiverState_sendEndReq;
          end

          RxInitReceiverState_sendEndReq: begin
            if (sentEndRxInitD2CPointTestReq)
              stateReg <= RxInitReceiverState_waitEndResp;
          end

          RxInitReceiverState_waitEndResp: begin
            if (receivedEndRxInitD2CPointTestResp)
              stateReg <= RxInitReceiverState_finish;
          end

          RxInitReceiverState_finish: ;

          default: stateReg <= RxInitReceiverState_idle;
        endcase
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="RxInitD2CPointTestSenderFSM-sv"></a>

## [38] RxInitD2CPointTestSenderFSM.sv

```systemverilog
// FILE_INDEX: 38
// FILE_PATH : RxInitD2CPointTestSenderFSM.sv

// Transmitter-side responder for a UCIe receiver-initiated D2C point test.
//
// This FSM begins after a Start Rx Init D2C Point Test request has been
// received.  It acknowledges Start, performs the clear-error handshake,
// transmits the requested pattern, reports Tx Count Done, and responds to the
// receiver's End request.  It is not interchangeable with
// TxInitD2CPointTestSenderFSM, where the local transmitter initiates the test.
`default_nettype none

module RxInitD2CPointTestSenderFSM (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  output      logic busy,
  output      logic done,
  output      logic [3:0] state,

  output      logic sendStartRxInitD2CPointTestResp,
  input  wire logic sentStartRxInitD2CPointTestResp,

  output      logic resetLocalScrambler,
  output      logic sendLfsrClearErrorReq,
  input  wire logic sentLfsrClearErrorReq,
  input  wire logic receivedLfsrClearErrorResp,

  output      logic sendDefinedPattern,
  input  wire logic sentDefinedPattern,

  output      logic sendRxInitD2CTxCountDoneReq,
  input  wire logic sentRxInitD2CTxCountDoneReq,
  input  wire logic receivedRxInitD2CTxCountDoneResp,

  input  wire logic receivedEndRxInitD2CPointTestReq,
  output      logic sendEndRxInitD2CPointTestResp,
  input  wire logic sentEndRxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    RxInitSenderState_idle              = 4'h0,
    RxInitSenderState_sendStartResp     = 4'h1,
    RxInitSenderState_sendClearReq      = 4'h2,
    RxInitSenderState_waitClearResp     = 4'h3,
    RxInitSenderState_resetScrambler    = 4'h4,
    RxInitSenderState_sendPattern       = 4'h5,
    RxInitSenderState_sendCountDoneReq  = 4'h6,
    RxInitSenderState_waitCountDoneResp = 4'h7,
    RxInitSenderState_waitEndReq        = 4'h8,
    RxInitSenderState_sendEndResp       = 4'h9,
    RxInitSenderState_finish            = 4'hA
  } RxInitSenderState_t;

  (* keep = "true" *) RxInitSenderState_t stateReg;
  (* keep = "true" *) logic previousStart;

  wire startPulse = start && !previousStart;

  always_comb begin
    busy = (stateReg != RxInitSenderState_idle) &&
           (stateReg != RxInitSenderState_finish);
    done = (stateReg == RxInitSenderState_finish);
    state = stateReg;

    sendStartRxInitD2CPointTestResp =
      (stateReg == RxInitSenderState_sendStartResp);
    sendLfsrClearErrorReq = (stateReg == RxInitSenderState_sendClearReq);
    resetLocalScrambler = (stateReg == RxInitSenderState_resetScrambler);
    sendDefinedPattern = (stateReg == RxInitSenderState_sendPattern);
    sendRxInitD2CTxCountDoneReq =
      (stateReg == RxInitSenderState_sendCountDoneReq);
    sendEndRxInitD2CPointTestResp =
      (stateReg == RxInitSenderState_sendEndResp);
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg      <= RxInitSenderState_idle;
      previousStart <= 1'b0;
    end else begin
      previousStart <= start;

      if (startPulse) begin
        stateReg <= RxInitSenderState_sendStartResp;
      end else begin
        unique case (stateReg)
          RxInitSenderState_idle: ;

          RxInitSenderState_sendStartResp: begin
            if (sentStartRxInitD2CPointTestResp)
              stateReg <= RxInitSenderState_sendClearReq;
          end

          RxInitSenderState_sendClearReq: begin
            if (sentLfsrClearErrorReq)
              stateReg <= RxInitSenderState_waitClearResp;
          end

          RxInitSenderState_waitClearResp: begin
            if (receivedLfsrClearErrorResp)
              stateReg <= RxInitSenderState_resetScrambler;
          end

          RxInitSenderState_resetScrambler:
            stateReg <= RxInitSenderState_sendPattern;

          RxInitSenderState_sendPattern: begin
            if (sentDefinedPattern)
              stateReg <= RxInitSenderState_sendCountDoneReq;
          end

          RxInitSenderState_sendCountDoneReq: begin
            if (sentRxInitD2CTxCountDoneReq)
              stateReg <= RxInitSenderState_waitCountDoneResp;
          end

          RxInitSenderState_waitCountDoneResp: begin
            if (receivedRxInitD2CTxCountDoneResp)
              stateReg <= RxInitSenderState_waitEndReq;
          end

          RxInitSenderState_waitEndReq: begin
            if (receivedEndRxInitD2CPointTestReq)
              stateReg <= RxInitSenderState_sendEndResp;
          end

          RxInitSenderState_sendEndResp: begin
            if (sentEndRxInitD2CPointTestResp)
              stateReg <= RxInitSenderState_finish;
          end

          RxInitSenderState_finish: ;

          default: stateReg <= RxInitSenderState_idle;
        endcase
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="SideBandModule-sv"></a>

## [39] SideBandModule.sv

```systemverilog
// FILE_INDEX: 39
// FILE_PATH : SideBandModule.sv

`default_nettype none
module SideBandModule #(
  parameter int unsigned TX_FIFO_ENTRIES = 4
) (
  input  wire logic         clock,
  input  wire logic         reset_n,
  input  wire logic [127:0] tx_din,
  input  wire logic         tx_valid,
  output var  logic         tx_ready,
  output var  logic         tx_dout,
  output var  logic         tx_clk,
  output var  logic [127:0] rx_dout,
  output var  logic         rx_valid,
  input  wire logic         rxReset,
  input  wire logic         rx_din,
  input  wire logic         rx_clk
);
  localparam int unsigned PTR_W = (TX_FIFO_ENTRIES <= 2) ? 1 : $clog2(TX_FIFO_ENTRIES);
  localparam int unsigned CNT_W = $clog2(TX_FIFO_ENTRIES + 1);

  logic [127:0] txFifo [0:TX_FIFO_ENTRIES-1];
  logic [PTR_W-1:0] txWritePtr;
  logic [PTR_W-1:0] txReadPtr;
  logic [CNT_W-1:0] txCount;
  logic txEnqueue;
  logic txDequeue;
  logic txInternalReady;
  logic [127:0] txFifoDout;

  logic [127:0] rxDoutAsync;
  logic         rxValidAsync;
  logic         rxCompletionToggle;
  wire logic    rxCdcReset = rxReset || !reset_n;

  (* ASYNC_REG = "TRUE" *) logic rxEventSync1;
  (* ASYNC_REG = "TRUE" *) logic rxEventSync2;
  (* ASYNC_REG = "TRUE" *) logic rxEventSync3;
  logic rxEventSeen;

  assign tx_ready       = (txCount < TX_FIFO_ENTRIES);
  assign txFifoDout     = txFifo[txReadPtr];
  assign txEnqueue      = tx_valid && tx_ready;
  assign txDequeue      = (txCount != 0) && txInternalReady;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      txWritePtr <= '0;
      txReadPtr  <= '0;
      txCount    <= '0;
    end else begin
      if (txEnqueue) begin
        txFifo[txWritePtr] <= tx_din;
        txWritePtr <= (txWritePtr == TX_FIFO_ENTRIES-1) ? '0 : txWritePtr + 1'b1;
      end
      if (txDequeue)
        txReadPtr <= (txReadPtr == TX_FIFO_ENTRIES-1) ? '0 : txReadPtr + 1'b1;

      case ({txEnqueue, txDequeue})
        2'b10: txCount <= txCount + 1'b1;
        2'b01: txCount <= txCount - 1'b1;
        default: txCount <= txCount;
      endcase
    end
  end

  SidebandTx tx (
    .clock              (clock),
    .reset_n            (reset_n),
    .din                (txFifoDout),
    .valid              (txCount != 0),
    .ready              (txInternalReady),
    .dout               (tx_dout),
    .clk_out            (tx_clk),
    .dbg_state          (),
    .dbg_shiftReg       (),
    .dbg_payloadReg     (),
    .dbg_bitsLeft       (),
    .dbg_gapCount       (),
    .dbg_payloadPending ()
  );

  // The receiver samples the falling edge of the forwarded clock. Its data
  // register and completion toggle update together on the final bit, before
  // the forwarded clock stops. Do not re-register its valid in this domain:
  // doing so would require a sampling edge from the next packet.
  SidebandRx rx (
    .clock            (~rx_clk),
    .reset            (rxCdcReset),
    .din              (rx_din),
    .dout             (rxDoutAsync),
    .valid            (rxValidAsync),
    .dbg_shiftReg     (),
    .dbg_bitCount     (),
    .dbg_prevBitCount (),
    .completion_toggle(rxCompletionToggle)
  );

  // Bundled-data CDC: the receiver holds rxDoutAsync until the next complete
  // message. Only the event passes through synchronizer flops. The controller
  // captures the held bus after three stages, then emits exactly one pulse.
  // Contract: consecutive message completions must be at least six controller
  // clock periods apart, and the controller clock must keep running. Serial
  // words and gaps alone do not guarantee this for arbitrary clock ratios.
  // Constrain the held-data path to settle before the event is consumed.
  // The existing receive interface has no ready input: its consumer must be
  // able to accept the rx_valid pulse.
  //
  // Either reset flushes the partial frame, held message and event history in
  // both domains, avoiding replay/spurious events after a one-sided reset.
  // Release reset before the first serial edge, meeting recovery/removal;
  // do not consume initial packet bits to clock a receive reset synchronizer.
  always_ff @(posedge clock or posedge rxCdcReset) begin
    if (rxCdcReset) begin
      rxEventSync1 <= 1'b0;
      rxEventSync2 <= 1'b0;
      rxEventSync3 <= 1'b0;
      rxEventSeen  <= 1'b0;
      rx_dout      <= 128'b0;
      rx_valid     <= 1'b0;
    end else begin
      rxEventSync1 <= rxCompletionToggle;
      rxEventSync2 <= rxEventSync1;
      rxEventSync3 <= rxEventSync2;
      rxEventSeen  <= rxEventSync3;
      rx_valid    <= 1'b0;
      if (rxEventSync3 != rxEventSeen) begin
        rx_dout  <= rxDoutAsync;
        rx_valid <= 1'b1;
      end
    end
  end
endmodule
`default_nettype wire

```

<a id="SidebandMsgGenerator_corregido-sv"></a>

## [40] SidebandMsgGenerator_corregido.sv

```systemverilog
// FILE_INDEX: 40
// FILE_PATH : SidebandMsgGenerator_corregido.sv

// Hand-translated synthesizable SystemVerilog.
// Source: SidebandMsgGenerator(4).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package SidebandMsgGenerator_pkg;
  parameter int unsigned MESSAGE_WIDTH = 128;
  parameter int unsigned HEADER_WIDTH  = 64;
  parameter int unsigned PAYLOAD_WIDTH = 64;

  // UCIe 2.0 packet opcodes used by the source.
  localparam logic [4:0] OPCODE_MSG_WITHOUT_DATA = 5'b10010;
  localparam logic [4:0] OPCODE_MSG_WITH_DATA    = 5'b11011;

  // Synthesizable replacements for the Scala string-to-endpoint mapping.
  localparam logic [2:0] ENDPOINT_STACK0     = 3'b000;
  localparam logic [2:0] ENDPOINT_D2D        = 3'b001;
  localparam logic [2:0] ENDPOINT_PHY        = 3'b010;
  localparam logic [2:0] ENDPOINT_MPG        = 3'b011;
  localparam logic [2:0] ENDPOINT_STACK1     = 3'b100;
  localparam logic [2:0] ENDPOINT_REMOTE_D2D = 3'b101;
  localparam logic [2:0] ENDPOINT_REMOTE_PHY = 3'b110;
  localparam logic [2:0] ENDPOINT_REMOTE_MPG = 3'b111;

  // Build the common 64-bit sideband header.
  function automatic logic [63:0] buildHeader(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id,
    input logic [4:0]  opcode,
    input logic        dp
  );
    logic [61:0] tail;
    logic        cp;
    tail = {
      3'b000,
      dst_id,
      msgInfo,
      msgSub,
      src_id,
      2'b00,
      5'b00000,
      msgCode,
      9'b000000000,
      opcode
    };
    cp = ^tail;
    buildHeader = {dp, cp, tail};
  endfunction

  function automatic logic [127:0] msgWithoutPayloadBase(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id
  );
    logic [63:0] header;
    header = buildHeader(msgInfo, msgCode, msgSub, src_id, dst_id,
                         OPCODE_MSG_WITHOUT_DATA, 1'b0);
    msgWithoutPayloadBase = {64'b0, header};
  endfunction

  function automatic logic [127:0] msgWithPayloadBase(
    input logic [15:0] msgInfo,
    input logic [7:0]  msgCode,
    input logic [7:0]  msgSub,
    input logic [63:0] payload,
    input logic [2:0]  src_id,
    input logic [2:0]  dst_id
  );
    logic        dp;
    logic [63:0] header;
    dp = ^payload;
    header = buildHeader(msgInfo, msgCode, msgSub, src_id, dst_id,
                         OPCODE_MSG_WITH_DATA, dp);
    msgWithPayloadBase = {payload, header};
  endfunction

  function automatic logic [63:0] headerOf(input logic [127:0] message);
    headerOf = message[63:0];
  endfunction

  function automatic logic [63:0] payloadOf(input logic [127:0] message);
    payloadOf = message[127:64];
  endfunction

  function automatic logic hasPayload(input logic [127:0] message);
    hasPayload = (message[4:0] == OPCODE_MSG_WITH_DATA);
  endfunction

  // Message wrappers translated from the Scala object. String src/dst arguments
  // are represented by the 3-bit endpoint IDs above so every function remains RTL-synthesizable.
  // -------------------------------------------------------------------------------------------------------
  // SBINIT messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgSbinitOutOfResetSuccess(//mirar, pasar bit de success como parametro
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitOutOfResetSuccess = msgWithoutPayloadBase(16'b0000000000000001, 8'h91, 8'h00, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitOutOfResetFailure(//mirar, pasar bit de success como parametro
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitOutOfResetFailure = msgWithoutPayloadBase(16'b0000000000000000, 8'h91, 8'h00, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitDoneReq = msgWithoutPayloadBase(16'd0, 8'h95, 8'h01, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgSbinitDoneResp = msgWithoutPayloadBase(16'd0, 8'h9A, 8'h01, src_id, dst_id);
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.PARAM and MBINIT.CAL messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitParamConfigReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic sbFeatureExtension,
    input logic ucieA,
    input logic [1:0] moduleID,
    input logic clkPhase,
    input logic clkMode,
    input logic [4:0] voltageSwing,
    input logic [3:0] maxLinkSpeed
  );
    logic [63:0] payload;
    payload = {49'd0, sbFeatureExtension, ucieA, moduleID[1:0], clkPhase, clkMode, voltageSwing[4:0], maxLinkSpeed[3:0]};
    msgMbinitParamConfigReq = msgWithPayloadBase( 16'b0000000000000000, 8'hA5, 8'h00, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitParamConfigResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic clkPhase,
    input logic clkMode,
    input logic [3:0] maxLinkSpeed
  );
    logic [63:0] payload;
    payload = {53'd0, clkPhase, clkMode, 5'd0, maxLinkSpeed[3:0]};
    msgMbinitParamConfigResp = msgWithPayloadBase( 16'b0000000000000000, 8'hAA, 8'h00, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h02, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRCLK messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairClkInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [0:0] RTRK_L,
    input logic [0:0] RCKN_L,
    input logic [0:0] RCKP_L
  );
    msgMbinitRepairClkResultResp = msgWithoutPayloadBase( {13'd0, RTRK_L[0], RCKN_L[0], RCKP_L[0]}, 8'hAA, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairClkDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairClkDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h08, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRVAL messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairValInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0A, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [0:0] RVLD_L
  );
    msgMbinitRepairValResultResp = msgWithoutPayloadBase( {15'd0, RVLD_L[0]}, 8'hAA, 8'h0A, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairValDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairValDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0C, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REVERSALMB messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitReversalMbInitReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbInitReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbInitResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbInitResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0E, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0E, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbResultReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbResultReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h0F, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbResultResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] RD_L_15to0
  );
    msgMbinitReversalMbResultResp = msgWithPayloadBase( 16'b0000000000000000, 8'hAA, 8'h0F, {48'd0, RD_L_15to0[15:0]}, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h10, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitReversalMbDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitReversalMbDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h10, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBINIT.REPAIRMB messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbinitRepairMbStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartTxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbinitRepairMbStartTxInitD2CPointTestReq = msgWithPayloadBase( msgInfo[15:0], 8'h85, 8'h01, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbStartTxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbStartTxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbLfsrClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbLfsrClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbLfsrClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbLfsrClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbTxInitD2CResultsReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbTxInitD2CResultsReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbTxInitD2CResultsResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [63:0] payload
  );
    msgMbinitRepairMbTxInitD2CResultsResp = msgWithPayloadBase( msgInfo[15:0], 8'h8A, 8'h03, payload[63:0], src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndTxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndTxInitD2CPointTestReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndTxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndTxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbApplyDegradeReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [2:0] laneMap
  );
    msgMbinitRepairMbApplyDegradeReq = msgWithoutPayloadBase( {13'd0, laneMap[2:0]}, 8'hA5, 8'h14, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbApplyDegradeResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbApplyDegradeResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h14, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hA5, 8'h13, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbinitRepairMbEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbinitRepairMbEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hAA, 8'h13, src_id, dst_id );
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // MBTRAIN messages.
  // -------------------------------------------------------------------------------------------------------
  function automatic logic [127:0] msgMbtrainValVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h00, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h00, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h01, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartRxInitD2CPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbtrainValVrefStartRxInitD2CPointTestReq = msgWithPayloadBase( msgInfo[15:0], 8'h85, 8'h07, payload, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainValVrefStartRxInitD2CPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValVrefStartRxInitD2CPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h07, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainLfsrClearErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLfsrClearErrorReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainLfsrClearErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLfsrClearErrorResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h02, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CTxCountDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CTxCountDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CTxCountDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CTxCountDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h08, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CEndPointTestReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CEndPointTestReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'h85, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxInitD2CEndPointTestResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxInitD2CEndPointTestResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'h8A, 8'h09, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartRxInitD2CPointTestReq(//Mirar, es el mismo codigo del msgMbtrainValVrefStartRxInitD2CPointTestReq, se puede usar el mismo mensaje
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    msgMbtrainDataVrefStartRxInitD2CPointTestReq = msgMbtrainValVrefStartRxInitD2CPointTestReq( src_id, dst_id, msgInfo, comparisonMode, iterationCountSettings, idleCountSettings, burstCountSettings, patternMode, clockPhaseControl, validPattern, dataPattern );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefStartRxInitD2CPointTestResp(//Mirar, es el mismo codigo del msgMbtrainValVrefStartRxInitD2CPointTestResp, se puede usar el mismo mensaje
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefStartRxInitD2CPointTestResp = msgMbtrainValVrefStartRxInitD2CPointTestResp(src_id, dst_id);
  endfunction


  function automatic logic [127:0] msgMbtrainDataVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefEndReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h03, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataVrefEndResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h03, src_id, dst_id );
  endfunction

  
  function automatic logic [127:0] msgMbtrainSpeedIdleDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainSpeedIdleDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainSpeedIdleDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainSpeedIdleDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h04, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainTxSelfCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxSelfCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h05, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainTxSelfCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxSelfCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h05, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalStartReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h06, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalStartResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h06, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalDoneReq = msgWithoutPayloadBase( 16'b0000000000000000, 8'hB5, 8'h07, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxClkCalDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxClkCalDoneResp = msgWithoutPayloadBase( 16'b0000000000000000, 8'hBA, 8'h07, src_id, dst_id );
  endfunction

    function automatic logic [127:0] msgMbtrainValTrainCenterStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h08, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h08, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h09, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainCenterDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainCenterDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h09, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0A, src_id, dst_id);
  endfunction
  
  function automatic logic [127:0] msgMbtrainValTrainVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0A, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0B, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainValTrainVrefDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainValTrainVrefDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0B, src_id, dst_id);
  endfunction


  function automatic logic [127:0] msgMbtrainDataTrainCenter1StartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1StartReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1StartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1StartResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h0C, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1EndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1EndReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h0D, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter1EndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter1EndResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h0D, src_id, dst_id );
  endfunction
  
  function automatic logic [127:0] msgMbtrainDataTrainVrefStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h0E, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h0E, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefEndReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h10, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainVrefEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainVrefEndResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h10, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewStartReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewStartResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h11, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewEndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewEndReq = msgWithoutPayloadBase( 16'd0, 8'hB5, 8'h12, src_id, dst_id );
  endfunction

  function automatic logic [127:0] msgMbtrainRxDeskewEndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainRxDeskewEndResp = msgWithoutPayloadBase( 16'd0, 8'hBA, 8'h12, src_id, dst_id );
  endfunction


  function automatic logic [127:0] msgMbtrainDataTrainCenter2StartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2StartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h13, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2StartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2StartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h13, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2EndReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2EndReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h14, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainDataTrainCenter2EndResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainDataTrainCenter2EndResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h14, src_id, dst_id);
  endfunction



  function automatic logic [127:0] msgMbtrainStartTxInitD2CPointTestReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [0:0] comparisonMode,
    input logic [15:0] iterationCountSettings,
    input logic [15:0] idleCountSettings,
    input logic [15:0] burstCountSettings,
    input logic [0:0] patternMode,
    input logic [3:0] clockPhaseControl,
    input logic [2:0] validPattern,
    input logic [2:0] dataPattern
  );
    logic [63:0] payload;
    payload = {4'd0, comparisonMode[0], iterationCountSettings[15:0], idleCountSettings[15:0], burstCountSettings[15:0], patternMode[0], clockPhaseControl[3:0], validPattern[2:0], dataPattern[2:0]};
    msgMbtrainStartTxInitD2CPointTestReq = msgWithPayloadBase(msgInfo[15:0], 8'h85, 8'h01, payload, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainStartTxInitD2CPointTestResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainStartTxInitD2CPointTestResp = msgWithoutPayloadBase(16'd0, 8'h8A, 8'h01, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainTxInitD2CResultsReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainTxInitD2CResultsReq = msgWithoutPayloadBase(16'd0, 8'h85, 8'h03, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainTxInitD2CResultsResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] msgInfo,
    input logic [63:0] payload
  );
    msgMbtrainTxInitD2CResultsResp = msgWithPayloadBase(msgInfo[15:0], 8'h8A, 8'h03, payload[63:0], src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainEndTxInitD2CPointTestReq(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainEndTxInitD2CPointTestReq = msgWithoutPayloadBase(16'd0, 8'h85, 8'h04, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainEndTxInitD2CPointTestResp(
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainEndTxInitD2CPointTestResp = msgWithoutPayloadBase(16'd0, 8'h8A, 8'h04, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgSbinitClkPattern();
    msgSbinitClkPattern = {64'd0, 64'h5555555555555555};
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedStartReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedStartReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h15, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedStartResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedStartResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h15, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedErrorReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedErrorReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h16, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedErrorResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedErrorResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h16, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedDoneReq(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedDoneReq = msgWithoutPayloadBase(16'd0, 8'hB5, 8'h19, src_id, dst_id);
  endfunction

  function automatic logic [127:0] msgMbtrainLinkSpeedDoneResp(//correto
    input logic [2:0] src_id,
    input logic [2:0] dst_id
  );
    msgMbtrainLinkSpeedDoneResp = msgWithoutPayloadBase(16'd0, 8'hBA, 8'h19, src_id, dst_id);
  endfunction

  // -------------------------------------------------------------------------------------------------------
  // UCIe2 constants and helpers (flat SystemVerilog names mirror the Scala object hierarchy).
  // -------------------------------------------------------------------------------------------------------
  localparam logic [4:0] UCIe2_PacketOpcode_MSG_WITHOUT_DATA = OPCODE_MSG_WITHOUT_DATA;
  localparam logic [4:0] UCIe2_PacketOpcode_MSG_WITH_64B_DATA = OPCODE_MSG_WITH_DATA;

  localparam logic [15:0] UCIe2_MsgInfo_REGULAR                    = 16'h0000;
  localparam logic [15:0] UCIe2_MsgInfo_STALL                      = 16'hFFFF;
  localparam logic [15:0] UCIe2_MsgInfo_STACK0_OR_POST_NEGOTIATION = 16'h0000;
  localparam logic [15:0] UCIe2_MsgInfo_STACK1_POST_NEGOTIATION    = 16'h0001;

  function automatic logic UCIe2_MsgInfo_isStall(input logic [15:0] info);
    UCIe2_MsgInfo_isStall = (info == UCIe2_MsgInfo_STALL);
  endfunction

  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_RDI_REQ       = 8'h01;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_RDI_RSP       = 8'h02;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ  = 8'h03;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP  = 8'h04;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ  = 8'h05;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP  = 8'h06;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ     = 8'h07;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK = 8'h08;
  localparam logic [7:0] UCIe2_LinkMgmtMsgCode_ERR_MSG                = 8'h09;

  localparam logic [7:0] UCIe2_LinkMgmtSubCode_ACTIVE    = 8'h01;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_PMNAK     = 8'h02;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_L1        = 8'h04;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_L2        = 8'h08;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_LINKRESET = 8'h09;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_LINKERROR = 8'h0A;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_RETRAIN   = 8'h0B;
  localparam logic [7:0] UCIe2_LinkMgmtSubCode_DISABLE   = 8'h0C;

  localparam logic [7:0] UCIe2_ParamExch_ADV_CAP_MSGCODE = 8'h01;
  localparam logic [7:0] UCIe2_ParamExch_FIN_CAP_MSGCODE = 8'h02;
  localparam logic [7:0] UCIe2_ParamExch_SUB_ADAPTER     = 8'h00;
  localparam logic [7:0] UCIe2_ParamExch_SUB_CXL         = 8'h01;
  localparam logic [7:0] UCIe2_ParamExch_SUB_MULTIPROT   = 8'h02;

  localparam logic [7:0] UCIe2_ParityFeature_SUB_REQ_ACK = 8'h00;
  localparam logic [7:0] UCIe2_ParityFeature_SUB_NAK     = 8'h01;

  localparam logic [7:0] UCIe2_ErrMsg_CORRECTABLE = 8'h00;
  localparam logic [7:0] UCIe2_ErrMsg_NON_FATAL   = 8'h01;
  localparam logic [7:0] UCIe2_ErrMsg_FATAL       = 8'h02;

  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_OUT_OF_RESET = 8'h91;
  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_DONE_REQ     = 8'h95;
  localparam logic [7:0] UCIe2_LtsmMsgCode_SBINIT_DONE_RSP     = 8'h9A;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBINIT_REQ           = 8'hA5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBINIT_RSP           = 8'hAA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBTRAIN_REQ          = 8'hB5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_MBTRAIN_RSP          = 8'hBA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINING_DATA_REQ    = 8'h85;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINING_DATA_RSP    = 8'h8A;
  localparam logic [7:0] UCIe2_LtsmMsgCode_PHYRETRAIN_REQ       = 8'hC5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_PHYRETRAIN_RSP       = 8'hCA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_RECAL_REQ            = 8'hD5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_RECAL_RSP            = 8'hDA;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINERROR_REQ       = 8'hE5;
  localparam logic [7:0] UCIe2_LtsmMsgCode_TRAINERROR_RSP       = 8'hEA;

  function automatic logic [63:0] UCIe2_Field_header(input logic [127:0] message);
    UCIe2_Field_header = message[63:0];
  endfunction
  function automatic logic [63:0] UCIe2_Field_payload(input logic [127:0] message);
    UCIe2_Field_payload = message[127:64];
  endfunction
  function automatic logic [4:0] UCIe2_Field_opcode(input logic [127:0] message);
    UCIe2_Field_opcode = message[4:0];
  endfunction
  function automatic logic [7:0] UCIe2_Field_msgCode(input logic [127:0] message);
    UCIe2_Field_msgCode = message[21:14];
  endfunction
  function automatic logic [2:0] UCIe2_Field_srcId(input logic [127:0] message);
    UCIe2_Field_srcId = message[31:29];
  endfunction
  function automatic logic [7:0] UCIe2_Field_msgSub(input logic [127:0] message);
    UCIe2_Field_msgSub = message[39:32];
  endfunction
  function automatic logic [15:0] UCIe2_Field_msgInfo(input logic [127:0] message);
    UCIe2_Field_msgInfo = message[55:40];
  endfunction
  function automatic logic [2:0] UCIe2_Field_dstId(input logic [127:0] message);
    UCIe2_Field_dstId = message[58:56];
  endfunction
  function automatic logic UCIe2_Field_controlParity(input logic [127:0] message);
    UCIe2_Field_controlParity = message[62];
  endfunction
  function automatic logic UCIe2_Field_dataParity(input logic [127:0] message);
    UCIe2_Field_dataParity = message[63];
  endfunction

  typedef enum logic [3:0] {
    UCIe2_Route_NONE       = 4'd0,
    UCIe2_Route_LTSM       = 4'd1,
    UCIe2_Route_RDI        = 4'd2,
    UCIe2_Route_ADAPTER0   = 4'd3,
    UCIe2_Route_ADAPTER1   = 4'd4,
    UCIe2_Route_D2D_COMMON = 4'd5,
    UCIe2_Route_MPG        = 4'd6,
    UCIe2_Route_VENDOR     = 4'd7,
    UCIe2_Route_UNKNOWN    = 4'd8
  } UCIe2_Route_t;

  function automatic logic [127:0] UCIe2_RDI_req(
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_RDI_req = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_RDI_REQ,
                                          sub, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_RDI_rsp(
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_RDI_rsp = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_RDI_RSP,
                                          sub, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_RDI_reqActive(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqActive = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspActive(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspActive = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspPMNAK(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspPMNAK = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_PMNAK, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqL1(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqL1 = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspL1(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspL1 = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqL2(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqL2 = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspL2(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_rspL2 = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqLinkReset(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqLinkReset = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspLinkReset(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspLinkReset = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqLinkError(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqLinkError = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_LINKERROR, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspLinkError(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspLinkError = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_LINKERROR, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqRetrain(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqRetrain = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_RETRAIN, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspRetrain(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspRetrain = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_RETRAIN, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_reqDisable(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_RDI_reqDisable = UCIe2_RDI_req(UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_RDI_rspDisable(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_RDI_rspDisable = UCIe2_RDI_rsp(UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, info);
  endfunction

  function automatic logic [7:0] UCIe2_Adapter_reqMsgCode(input int unsigned stack);
    UCIe2_Adapter_reqMsgCode = (stack == 0) ? UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ
                                            : UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ;
  endfunction
  function automatic logic [7:0] UCIe2_Adapter_rspMsgCode(input int unsigned stack);
    UCIe2_Adapter_rspMsgCode = (stack == 0) ? UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP
                                            : UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP;
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_req(
    input int unsigned stack,
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_Adapter_req = msgWithoutPayloadBase(info, UCIe2_Adapter_reqMsgCode(stack), sub, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rsp(
    input int unsigned stack,
    input logic [7:0] sub,
    input logic [2:0] src_id,
    input logic [2:0] dst_id,
    input logic [15:0] info
  );
    UCIe2_Adapter_rsp = msgWithoutPayloadBase(info, UCIe2_Adapter_rspMsgCode(stack), sub, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqActive(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_reqActive = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspActive(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspActive = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_ACTIVE, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspPMNAK(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspPMNAK = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_PMNAK, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqL1(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqL1 = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspL1(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspL1 = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_L1, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqL2(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqL2 = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspL2(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_rspL2 = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_L2, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqLinkReset(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqLinkReset = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspLinkReset(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspLinkReset = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_LINKRESET, src_id, dst_id, info);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_reqDisable(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Adapter_reqDisable = UCIe2_Adapter_req(stack, UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, UCIe2_MsgInfo_REGULAR);
  endfunction
  function automatic logic [127:0] UCIe2_Adapter_rspDisable(input int unsigned stack, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Adapter_rspDisable = UCIe2_Adapter_rsp(stack, UCIe2_LinkMgmtSubCode_DISABLE, src_id, dst_id, info);
  endfunction

  function automatic logic [127:0] UCIe2_Common_parityFeatureReq(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_parityFeatureReq = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ, UCIe2_ParityFeature_SUB_REQ_ACK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_parityFeatureAck(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Common_parityFeatureAck = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK, UCIe2_ParityFeature_SUB_REQ_ACK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_parityFeatureNak(input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_Common_parityFeatureNak = msgWithoutPayloadBase(info, UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK, UCIe2_ParityFeature_SUB_NAK, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errCorrectable(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errCorrectable = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_CORRECTABLE, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errNonFatal(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errNonFatal = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_NON_FATAL, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_Common_errFatal(input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_Common_errFatal = msgWithoutPayloadBase(UCIe2_MsgInfo_REGULAR, UCIe2_LinkMgmtMsgCode_ERR_MSG, UCIe2_ErrMsg_FATAL, src_id, dst_id);
  endfunction

  function automatic logic [127:0] UCIe2_ParamExchange_advCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_advCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_ADAPTER, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_finCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_ADAPTER, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_advCapCxl(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_advCapCxl = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_CXL, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapCxl(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_finCapCxl = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_CXL, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_multiProtAdvCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_multiProtAdvCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_ADV_CAP_MSGCODE, UCIe2_ParamExch_SUB_MULTIPROT, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_multiProtFinCapAdapter(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id, input logic [15:0] info);
    UCIe2_ParamExchange_multiProtFinCapAdapter = msgWithPayloadBase(info, UCIe2_ParamExch_FIN_CAP_MSGCODE, UCIe2_ParamExch_SUB_MULTIPROT, payload, src_id, dst_id);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_advCapAdapterStall(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_ParamExchange_advCapAdapterStall = UCIe2_ParamExchange_advCapAdapter(payload, src_id, dst_id, UCIe2_MsgInfo_STALL);
  endfunction
  function automatic logic [127:0] UCIe2_ParamExchange_finCapAdapterStall(input logic [63:0] payload, input logic [2:0] src_id, input logic [2:0] dst_id);
    UCIe2_ParamExchange_finCapAdapterStall = UCIe2_ParamExchange_finCapAdapter(payload, src_id, dst_id, UCIe2_MsgInfo_STALL);
  endfunction

  function automatic logic UCIe2_isMsgWithoutData(input logic [127:0] message);
    UCIe2_isMsgWithoutData = (UCIe2_Field_opcode(message) == UCIe2_PacketOpcode_MSG_WITHOUT_DATA);
  endfunction
  function automatic logic UCIe2_isMsgWith64bData(input logic [127:0] message);
    UCIe2_isMsgWith64bData = (UCIe2_Field_opcode(message) == UCIe2_PacketOpcode_MSG_WITH_64B_DATA);
  endfunction
  function automatic logic UCIe2_hasPayload(input logic [127:0] message);
    UCIe2_hasPayload = UCIe2_isMsgWith64bData(message);
  endfunction
  function automatic logic UCIe2_controlParityOk(input logic [127:0] message);
    logic [63:0] header;
    header = UCIe2_Field_header(message);
    UCIe2_controlParityOk = (UCIe2_Field_controlParity(message) == (^header[61:0]));
  endfunction
  function automatic logic UCIe2_dataParityOk(input logic [127:0] message);
    UCIe2_dataParityOk = UCIe2_hasPayload(message)
      ? (UCIe2_Field_dataParity(message) == (^UCIe2_Field_payload(message)))
      : (UCIe2_Field_dataParity(message) == 1'b0);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmtReq(input logic [127:0] message);
    UCIe2_isRdiLinkMgmtReq = UCIe2_isMsgWithoutData(message) &&
      (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_RDI_REQ);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmtRsp(input logic [127:0] message);
    UCIe2_isRdiLinkMgmtRsp = UCIe2_isMsgWithoutData(message) &&
      (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_RDI_RSP);
  endfunction
  function automatic logic UCIe2_isRdiLinkMgmt(input logic [127:0] message);
    UCIe2_isRdiLinkMgmt = UCIe2_isRdiLinkMgmtReq(message) || UCIe2_isRdiLinkMgmtRsp(message);
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmtReq(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isAdapterLinkMgmtReq = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ) ||
       (code == UCIe2_LinkMgmtMsgCode_ADAPTER1_REQ));
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmtRsp(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isAdapterLinkMgmtRsp = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP) ||
       (code == UCIe2_LinkMgmtMsgCode_ADAPTER1_RSP));
  endfunction
  function automatic logic UCIe2_isAdapterLinkMgmt(input logic [127:0] message);
    UCIe2_isAdapterLinkMgmt = UCIe2_isAdapterLinkMgmtReq(message) || UCIe2_isAdapterLinkMgmtRsp(message);
  endfunction
  function automatic logic UCIe2_isD2DCommonNoData(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_isD2DCommonNoData = UCIe2_isMsgWithoutData(message) &&
      ((code == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ) ||
       (code == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_ACK_NAK) ||
       (code == UCIe2_LinkMgmtMsgCode_ERR_MSG));
  endfunction
  function automatic logic UCIe2_isParamExchange(input logic [127:0] message);
    logic [7:0] code;
    logic [7:0] sub;
    code = UCIe2_Field_msgCode(message);
    sub  = UCIe2_Field_msgSub(message);
    UCIe2_isParamExchange = UCIe2_isMsgWith64bData(message) &&
      ((code == UCIe2_ParamExch_ADV_CAP_MSGCODE) ||
       (code == UCIe2_ParamExch_FIN_CAP_MSGCODE)) &&
      ((sub == UCIe2_ParamExch_SUB_ADAPTER) ||
       (sub == UCIe2_ParamExch_SUB_CXL) ||
       (sub == UCIe2_ParamExch_SUB_MULTIPROT));
  endfunction
  function automatic logic UCIe2_isParamExchangeStall(input logic [127:0] message);
    UCIe2_isParamExchangeStall = UCIe2_isParamExchange(message) &&
      (UCIe2_Field_msgInfo(message) == UCIe2_MsgInfo_STALL);
  endfunction
  function automatic logic UCIe2_isSbinitClockPattern(input logic [127:0] message);
    UCIe2_isSbinitClockPattern = (UCIe2_Field_payload(message) == 64'b0) &&
                                 (UCIe2_Field_header(message) == 64'h5555555555555555);
  endfunction
  function automatic logic UCIe2_isLtsmMessage(input logic [127:0] message);
    logic [7:0] code;
    logic codeMatch;
    code = UCIe2_Field_msgCode(message);
    codeMatch =
      (code == UCIe2_LtsmMsgCode_SBINIT_OUT_OF_RESET) ||
      (code == UCIe2_LtsmMsgCode_SBINIT_DONE_REQ) ||
      (code == UCIe2_LtsmMsgCode_SBINIT_DONE_RSP) ||
      (code == UCIe2_LtsmMsgCode_MBINIT_REQ) ||
      (code == UCIe2_LtsmMsgCode_MBINIT_RSP) ||
      (code == UCIe2_LtsmMsgCode_MBTRAIN_REQ) ||
      (code == UCIe2_LtsmMsgCode_MBTRAIN_RSP) ||
      (code == UCIe2_LtsmMsgCode_TRAINING_DATA_REQ) ||
      (code == UCIe2_LtsmMsgCode_TRAINING_DATA_RSP) ||
      (code == UCIe2_LtsmMsgCode_PHYRETRAIN_REQ) ||
      (code == UCIe2_LtsmMsgCode_PHYRETRAIN_RSP) ||
      (code == UCIe2_LtsmMsgCode_RECAL_REQ) ||
      (code == UCIe2_LtsmMsgCode_RECAL_RSP) ||
      (code == UCIe2_LtsmMsgCode_TRAINERROR_REQ) ||
      (code == UCIe2_LtsmMsgCode_TRAINERROR_RSP);
    UCIe2_isLtsmMessage = UCIe2_isSbinitClockPattern(message) ||
      ((UCIe2_isMsgWithoutData(message) || UCIe2_isMsgWith64bData(message)) && codeMatch);
  endfunction
  function automatic UCIe2_Route_t UCIe2_route(input logic [127:0] message);
    logic [7:0] code;
    code = UCIe2_Field_msgCode(message);
    UCIe2_route = UCIe2_Route_UNKNOWN;
    if (UCIe2_isLtsmMessage(message)) begin
      UCIe2_route = UCIe2_Route_LTSM;
    end else if (UCIe2_isRdiLinkMgmt(message)) begin
      UCIe2_route = UCIe2_Route_RDI;
    end else if (UCIe2_isAdapterLinkMgmt(message)) begin
      if ((code == UCIe2_LinkMgmtMsgCode_ADAPTER0_REQ) ||
          (code == UCIe2_LinkMgmtMsgCode_ADAPTER0_RSP))
        UCIe2_route = UCIe2_Route_ADAPTER0;
      else
        UCIe2_route = UCIe2_Route_ADAPTER1;
    end else if (UCIe2_isD2DCommonNoData(message) || UCIe2_isParamExchange(message)) begin
      UCIe2_route = UCIe2_Route_D2D_COMMON;
    end
  endfunction
  function automatic logic UCIe2_expectsResponse(input logic [127:0] message);
    UCIe2_expectsResponse = UCIe2_isRdiLinkMgmtReq(message) ||
                            UCIe2_isAdapterLinkMgmtReq(message) ||
                            (UCIe2_isMsgWithoutData(message) &&
                             (UCIe2_Field_msgCode(message) == UCIe2_LinkMgmtMsgCode_PARITY_FEATURE_REQ));
  endfunction

  localparam int unsigned UCIe2_Legacy6_WIDTH = 6;
  localparam logic [5:0] UCIe2_Legacy6_NOP           = 6'h00;
  localparam logic [5:0] UCIe2_Legacy6_REQ_ACTIVE    = 6'h01;
  localparam logic [5:0] UCIe2_Legacy6_REQ_L1        = 6'h04;
  localparam logic [5:0] UCIe2_Legacy6_REQ_L2        = 6'h08;
  localparam logic [5:0] UCIe2_Legacy6_REQ_LINKRESET = 6'h09;
  localparam logic [5:0] UCIe2_Legacy6_REQ_LINKERROR = 6'h0A;
  localparam logic [5:0] UCIe2_Legacy6_REQ_RETRAIN   = 6'h0B;
  localparam logic [5:0] UCIe2_Legacy6_REQ_DISABLE   = 6'h0C;
  localparam logic [5:0] UCIe2_Legacy6_RSP_ACTIVE    = 6'h11;
  localparam logic [5:0] UCIe2_Legacy6_RSP_PMNAK     = 6'h12;
  localparam logic [5:0] UCIe2_Legacy6_RSP_L1        = 6'h14;
  localparam logic [5:0] UCIe2_Legacy6_RSP_L2        = 6'h18;
  localparam logic [5:0] UCIe2_Legacy6_RSP_LINKRESET = 6'h19;
  localparam logic [5:0] UCIe2_Legacy6_RSP_LINKERROR = 6'h1A;
  localparam logic [5:0] UCIe2_Legacy6_RSP_RETRAIN   = 6'h1B;
  localparam logic [5:0] UCIe2_Legacy6_RSP_DISABLE   = 6'h1C;

endpackage

`default_nettype wire

```

<a id="sidebandNode-sv"></a>

## [41] sidebandNode.sv

```systemverilog
// FILE_INDEX: 41
// FILE_PATH : sidebandNode.sv

// Hand-translated synthesizable SystemVerilog.
// Source: sidebandNode(2).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_sideband_params_pkg;
  // All integrated LTSM/FDI/RDI sideband messages are fixed-width 128-bit values.
  parameter int unsigned SIDEBAND_NODE_MSG_WIDTH = 128;
endpackage

`default_nettype wire

```

<a id="SidebandRx-sv"></a>

## [42] SidebandRx.sv

```systemverilog
// FILE_INDEX: 42
// FILE_PATH : SidebandRx.sv

`default_nettype none
module SidebandRx (
  input  wire logic         clock,
  input  wire logic         reset,
  input  wire logic         din,
  output var  logic [127:0] dout,
  output var  logic         valid,
  output var  logic [127:0] dbg_shiftReg,
  output var  logic [7:0]   dbg_bitCount,
  output var  logic [7:0]   dbg_prevBitCount,
  // Changes on the same sampling edge that publishes a complete message.
  // A consumer can synchronize it without another incoming clock edge.
  output var  logic         completion_toggle
);
  localparam logic [4:0] OPCODE_MSG_WITH_DATA = 5'b11011;

  logic [63:0] serialPacketReg;
  logic [63:0] headerReg;
  logic [127:0] outputReg;
  logic [7:0] bitCount;
  logic [7:0] prevBitCount;
  logic waitingPayload;
  logic validReg;
  logic [63:0] shiftedPacket;
  logic [63:0] receivedWord;

  function automatic logic [63:0] reverse64(input logic [63:0] value);
    integer i;
    begin
      for (i = 0; i < 64; i = i + 1)
        reverse64[i] = value[63-i];
    end
  endfunction

  always_comb begin
    shiftedPacket = {serialPacketReg[62:0], din};
    receivedWord  = reverse64(shiftedPacket);
    dout             = outputReg;
    valid            = validReg;
    dbg_shiftReg      = {64'b0, serialPacketReg};
    dbg_bitCount      = bitCount;
    dbg_prevBitCount  = prevBitCount;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      serialPacketReg <= 64'b0;
      headerReg       <= 64'b0;
      outputReg       <= 128'b0;
      bitCount        <= 8'b0;
      prevBitCount    <= 8'b0;
      waitingPayload  <= 1'b0;
      validReg        <= 1'b0;
      completion_toggle <= 1'b0;
    end else begin
      prevBitCount    <= bitCount;
      validReg        <= 1'b0;
      serialPacketReg <= shiftedPacket;

      if (bitCount == 8'd63) begin
        bitCount        <= 8'b0;
        serialPacketReg <= 64'b0;
        if (waitingPayload) begin
          outputReg      <= {receivedWord, headerReg};
          validReg       <= 1'b1;
          completion_toggle <= ~completion_toggle;
          waitingPayload <= 1'b0;
        end else if (receivedWord[4:0] == OPCODE_MSG_WITH_DATA) begin
          headerReg       <= receivedWord;
          waitingPayload  <= 1'b1;
        end else begin
          outputReg <= {64'b0, receivedWord};
          validReg  <= 1'b1;
          completion_toggle <= ~completion_toggle;
        end
      end else begin
        bitCount <= bitCount + 8'd1;
      end
    end
  end
endmodule
`default_nettype wire

```

<a id="SidebandTx-sv"></a>

## [43] SidebandTx.sv

```systemverilog
// FILE_INDEX: 43
// FILE_PATH : SidebandTx.sv

`default_nettype none

module SidebandTx (
  input  wire logic         clock,
  input  wire logic         reset_n,
  input  wire logic [127:0] din,
  input  wire logic         valid,

  output var  logic         ready,
  output var  logic         dout,
  output var  logic         clk_out,

  output var  logic [2:0]   dbg_state,
  output var  logic [63:0]  dbg_shiftReg,
  output var  logic [63:0]  dbg_payloadReg,
  output var  logic [6:0]   dbg_bitsLeft,
  output var  logic [4:0]   dbg_gapCount,
  output var  logic         dbg_payloadPending
);

  typedef enum logic [2:0] {
    State_IDLE         = 3'd0,
    State_SEND_HEADER  = 3'd1,
    State_PAYLOAD_GAP  = 3'd2,
    State_SEND_PAYLOAD = 3'd3,
    State_FINAL_GAP    = 3'd4
  } State_t;

  localparam logic [4:0] OPCODE_MSG_WITH_DATA = 5'b11011;

  State_t state;

  logic [63:0] shiftReg;
  logic [63:0] payloadReg;
  logic [6:0]  bitsLeft;
  logic [4:0]  gapCount;
  logic        payloadPending;

  logic doutReg;

  /*
   * Clock-enable request generated by the positive-edge FSM.
   */
  logic txClockEnableRequest;

  /*
   * Actual clock enable captured while clock is low.
   */
  logic txClockEnable;

  /*
   * Combinational output assignments.
   */
  always_comb begin
    ready = (state == State_IDLE);

    /*
     * The output clock retains the same phase as clock.
     * txClockEnable changes only on falling edges.
     */
    clk_out = clock & txClockEnable;

    /*
     * doutReg changes on rising edges.
     */
    dout = doutReg;

    dbg_state          = state;
    dbg_shiftReg       = shiftReg;
    dbg_payloadReg     = payloadReg;
    dbg_bitsLeft       = bitsLeft;
    dbg_gapCount       = gapCount;
    dbg_payloadPending = payloadPending;
  end

  /*
   * Glitch-free clock-enable capture.
   *
   * The gated clock is enabled and disabled only while clock is low.
   */
  always_ff @(negedge clock or negedge reset_n) begin
    if (!reset_n)
      txClockEnable <= 1'b0;
    else
      txClockEnable <= txClockEnableRequest;
  end

  /*
   * Rising-edge serializer.
   *
   * doutReg changes at the same source-clock edge that produces the
   * corresponding clk_out rising edge.
   */
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      state                <= State_IDLE;
      shiftReg             <= 64'b0;
      payloadReg           <= 64'b0;
      bitsLeft             <= 7'b0;
      gapCount             <= 5'b0;
      payloadPending       <= 1'b0;
      doutReg              <= 1'b0;
      txClockEnableRequest <= 1'b0;
    end else begin
      case (state)

        State_IDLE: begin
          doutReg              <= 1'b0;
          txClockEnableRequest <= 1'b0;

          if (valid && ready) begin
            /*
             * Capture the input transaction.
             *
             * doutReg is not loaded here because txClockEnable cannot
             * become active until the following falling edge.
             */
            shiftReg       <= din[63:0];
            payloadReg     <= din[127:64];
            bitsLeft       <= 7'd64;
            payloadPending <=
                (din[4:0] == OPCODE_MSG_WITH_DATA);

            /*
             * Request clock activation. txClockEnable will capture
             * this request at the next falling edge.
             */
            txClockEnableRequest <= 1'b1;
            state                <= State_SEND_HEADER;
          end
        end

        State_SEND_HEADER: begin
          /*
           * Launch the current serialized bit on the rising edge.
           */
          doutReg <= shiftReg[0];

          if (bitsLeft == 7'd1) begin
            /*
             * The last header bit is launched here.
             *
             * Request clock disable. The actual clock enable is
             * cleared on the following falling edge, preserving the
             * complete final high pulse.
             */
            bitsLeft             <= 7'd0;
            gapCount             <= 5'd31;
            txClockEnableRequest <= 1'b0;

            if (payloadPending)
              state <= State_PAYLOAD_GAP;
            else
              state <= State_FINAL_GAP;
          end else begin
            shiftReg <= {1'b0, shiftReg[63:1]};
            bitsLeft <= bitsLeft - 7'd1;
          end
        end

        State_PAYLOAD_GAP: begin
          doutReg              <= 1'b0;
          txClockEnableRequest <= 1'b0;

          if (gapCount == 5'd0) begin
            /*
             * Load the payload.
             *
             * Its first bit will be launched on the next rising edge
             * after txClockEnable becomes active.
             */
            shiftReg <= payloadReg;
            bitsLeft <= 7'd64;

            txClockEnableRequest <= 1'b1;
            state                <= State_SEND_PAYLOAD;
          end else begin
            gapCount <= gapCount - 5'd1;
          end
        end

        State_SEND_PAYLOAD: begin
          /*
           * Launch the current payload bit.
           */
          doutReg <= shiftReg[0];

          if (bitsLeft == 7'd1) begin
            bitsLeft             <= 7'd0;
            payloadPending       <= 1'b0;
            gapCount             <= 5'd31;
            txClockEnableRequest <= 1'b0;
            state                <= State_FINAL_GAP;
          end else begin
            shiftReg <= {1'b0, shiftReg[63:1]};
            bitsLeft <= bitsLeft - 7'd1;
          end
        end

        State_FINAL_GAP: begin
          doutReg              <= 1'b0;
          txClockEnableRequest <= 1'b0;

          if (gapCount == 5'd0) begin
            state <= State_IDLE;
          end else begin
            gapCount <= gapCount - 5'd1;
          end
        end

        default: begin
          state                <= State_IDLE;
          shiftReg             <= 64'b0;
          payloadReg           <= 64'b0;
          bitsLeft             <= 7'b0;
          gapCount             <= 5'b0;
          payloadPending       <= 1'b0;
          doutReg              <= 1'b0;
          txClockEnableRequest <= 1'b0;
        end

      endcase
    end
  end

endmodule

`default_nettype wire


```

<a id="StallController-sv"></a>

## [44] StallController.sv

```systemverilog
// FILE_INDEX: 44
// FILE_PATH : StallController.sv

// Hand-translated synthesizable SystemVerilog.
// Source: StallController(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module StallCtrl (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  input  wire logic release_i,
  input  wire logic ack,

  output var logic req,
  output var logic aligned,
  output var logic done,
  output var logic busy
);
  typedef enum logic [1:0] {
    StallState_Idle        = 2'd0,
    StallState_WaitAckRise = 2'd1,
    StallState_StalledHold = 2'd2,
    StallState_WaitAckFall = 2'd3
  } StallState_t;

  (* keep = "true" *) StallState_t st;
  StallState_t st_next;

  always_comb begin
    st_next = st;
    req     = 1'b0;
    aligned = 1'b0;
    done    = 1'b0;
    busy    = (st != StallState_Idle);

    case (st)
      StallState_Idle: begin
        if (start && !ack)
          st_next = StallState_WaitAckRise;
      end

      StallState_WaitAckRise: begin
        req = 1'b1;
        if (ack)
          st_next = StallState_StalledHold;
      end

      StallState_StalledHold: begin
        req     = 1'b1;
        aligned = 1'b1;
        if (release_i && ack)
          st_next = StallState_WaitAckFall;
      end

      StallState_WaitAckFall: begin
        if (!ack) begin
          done    = 1'b1;
          st_next = StallState_Idle;
        end
      end

      default: st_next = StallState_Idle;
    endcase
  end

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      st <= StallState_Idle;
    end else begin
      st <= st_next;
    end
  end
endmodule

`default_nettype wire

```

<a id="States-sv"></a>

## [45] States.sv

```systemverilog
// FILE_INDEX: 45
// FILE_PATH : States.sv

// SystemVerilog translation of States.scala.
`default_nettype none

package LinkTrainingState_pkg;
  typedef enum logic [2:0] {
    LinkTrainingState_reset     = 3'd0,
    LinkTrainingState_sbInit    = 3'd1,
    LinkTrainingState_mbInit    = 3'd2,
    LinkTrainingState_mbTrain   = 3'd3,
    LinkTrainingState_linkInit  = 3'd4,
    LinkTrainingState_active    = 3'd5,
    LinkTrainingState_linkError = 3'd6,
    LinkTrainingState_retrain   = 3'd7
  } LinkTrainingState_t;
endpackage

`default_nettype wire

```

<a id="TxInitD2CPointTestReceiverFSM-sv"></a>

## [46] TxInitD2CPointTestReceiverFSM.sv

```systemverilog
// FILE_INDEX: 46
// FILE_PATH : TxInitD2CPointTestReceiverFSM.sv

// SystemVerilog translation of TxInitD2CPointTestReceiverFSM.scala.
// All state-holding elements use the project-wide active-low asynchronous reset_n.
`default_nettype none

module TxInitD2CPointTestReceiverFSM (
  input wire logic clock,
  input wire logic reset_n,

  input wire logic start,
  output var logic busy,
  output var logic done,
  output var logic [3:0] state,

  input wire logic receivedStartTxInitD2CPointTestReq,
  output var logic sendStartTxInitD2CPointTestResp,
  input wire logic sentStartTxInitD2CPointTestResp,

  input wire logic receivedLfsrClearErrorReq,
  output var logic resetLocalRxScrambler,
  output var logic sendLfsrClearErrorResp,
  input wire logic sentLfsrClearErrorResp,

  input wire logic receivedTxInitD2CResultsReq,
  output var logic sendTxInitD2CResultsResp,
  input wire logic sentTxInitD2CResultsResp,

  input wire logic receivedEndTxInitD2CPointTestReq,
  output var logic sendEndTxInitD2CPointTestResp,
  input wire logic sentEndTxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    TxInitD2CPointTestReceiverState_idle                   = 4'h0,
    TxInitD2CPointTestReceiverState_waitStartReq           = 4'h1,
    TxInitD2CPointTestReceiverState_sendStartResp          = 4'h2,
    TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq  = 4'h3,
    TxInitD2CPointTestReceiverState_resetRxScrambler       = 4'h4,
    TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp = 4'h5,
    TxInitD2CPointTestReceiverState_waitResultsReq         = 4'h6,
    TxInitD2CPointTestReceiverState_sendResultsResp        = 4'h7,
    TxInitD2CPointTestReceiverState_waitEndReq             = 4'h8,
    TxInitD2CPointTestReceiverState_sendEndResp            = 4'h9,
    TxInitD2CPointTestReceiverState_finish                 = 4'hA
  } TxInitD2CPointTestReceiverState_t;

  (* keep = "true" *) TxInitD2CPointTestReceiverState_t stateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;

  // Sticky action registers. They clear only on reset or a new start pulse.
  (* keep = "true" *) logic sendStartTxInitD2CPointTestRespReg;
  (* keep = "true" *) logic resetLocalRxScramblerReg;
  (* keep = "true" *) logic sendLfsrClearErrorRespReg;
  (* keep = "true" *) logic sendTxInitD2CResultsRespReg;
  (* keep = "true" *) logic sendEndTxInitD2CPointTestRespReg;

  (* keep = "true" *) logic previousStart;
  wire startPulse = start && !previousStart;

  always_comb begin
    busy  = runningReg && !doneReg;
    done  = doneReg;
    state = stateReg;

    sendStartTxInitD2CPointTestResp = sendStartTxInitD2CPointTestRespReg;
    resetLocalRxScrambler           = resetLocalRxScramblerReg;
    sendLfsrClearErrorResp          = sendLfsrClearErrorRespReg;
    sendTxInitD2CResultsResp        = sendTxInitD2CResultsRespReg;
    sendEndTxInitD2CPointTestResp   = sendEndTxInitD2CPointTestRespReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg                              <= TxInitD2CPointTestReceiverState_idle;
      runningReg                            <= 1'b0;
      doneReg                               <= 1'b0;
      sendStartTxInitD2CPointTestRespReg    <= 1'b0;
      resetLocalRxScramblerReg              <= 1'b0;
      sendLfsrClearErrorRespReg             <= 1'b0;
      sendTxInitD2CResultsRespReg           <= 1'b0;
      sendEndTxInitD2CPointTestRespReg      <= 1'b0;
      previousStart                         <= 1'b0;
    end else begin
      previousStart <= start;

      // startPulse has priority over the normal receiver sequence and permits a
      // restart from any current state.
      if (startPulse) begin
        runningReg                         <= 1'b1;
        doneReg                            <= 1'b0;
        stateReg                           <= TxInitD2CPointTestReceiverState_waitStartReq;
        sendStartTxInitD2CPointTestRespReg <= 1'b0;
        resetLocalRxScramblerReg           <= 1'b0;
        sendLfsrClearErrorRespReg          <= 1'b0;
        sendTxInitD2CResultsRespReg        <= 1'b0;
        sendEndTxInitD2CPointTestRespReg   <= 1'b0;
      end else if (runningReg) begin
        case (stateReg)
          TxInitD2CPointTestReceiverState_idle: begin
            stateReg <= TxInitD2CPointTestReceiverState_waitStartReq;
          end

          TxInitD2CPointTestReceiverState_waitStartReq: begin
            if (receivedStartTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendStartResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendStartResp: begin
            sendStartTxInitD2CPointTestRespReg <= 1'b1;
            if (sentStartTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq: begin
            if (receivedLfsrClearErrorReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_resetRxScrambler;
            end
          end

          TxInitD2CPointTestReceiverState_resetRxScrambler: begin
            resetLocalRxScramblerReg <= 1'b1;
            stateReg <= TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp;
          end

          TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp: begin
            sendLfsrClearErrorRespReg <= 1'b1;
            if (sentLfsrClearErrorResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitResultsReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitResultsReq: begin
            if (receivedTxInitD2CResultsReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendResultsResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendResultsResp: begin
            sendTxInitD2CResultsRespReg <= 1'b1;
            if (sentTxInitD2CResultsResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitEndReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitEndReq: begin
            if (receivedEndTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendEndResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendEndResp: begin
            sendEndTxInitD2CPointTestRespReg <= 1'b1;
            if (sentEndTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_finish;
            end
          end

          TxInitD2CPointTestReceiverState_finish: begin
            doneReg <= 1'b1;
          end

          default: begin
            // Preserve Chisel switch semantics: no implicit illegal-state repair.
          end
        endcase
      end

      // This is a separate, later Chisel when block. Its assignments therefore
      // override earlier state/running assignments in the same cycle. doneReg is
      // deliberately not cleared here and stays sticky until the next startPulse.
      if (!start && doneReg && !startPulse) begin
        runningReg <= 1'b0;
        stateReg   <= TxInitD2CPointTestReceiverState_idle;
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="TxInitD2CPointTestSenderFSM-sv"></a>

## [47] TxInitD2CPointTestSenderFSM.sv

```systemverilog
// FILE_INDEX: 47
// FILE_PATH : TxInitD2CPointTestSenderFSM.sv

// SystemVerilog translation of TxInitD2CPointTestSenderFSM.scala.
// All state-holding elements use the project-wide active-low asynchronous reset_n.
`default_nettype none

module TxInitD2CPointTestSenderFSM (
  input wire logic clock,
  input wire logic reset_n,

  input wire logic start,
  output var logic busy,
  output var logic done,
  output var logic [3:0] state,

  output var logic sendStartTxInitD2CPointTestReq,
  input wire logic sentStartTxInitD2CPointTestReq,
  input wire logic receivedStartTxInitD2CPointTestResp,

  output var logic resetLocalScrambler,

  output var logic sendLfsrClearErrorReq,
  input wire logic sentLfsrClearErrorReq,
  input wire logic receivedLfsrClearErrorResp,

  output var logic sendDefinedPattern,
  input wire logic sentDefinedPattern,

  output var logic sendTxInitD2CResultsReq,
  input wire logic sentTxInitD2CResultsReq,
  input wire logic receivedTxInitD2CResultsResp,

  output var logic sendEndTxInitD2CPointTestReq,
  input wire logic sentEndTxInitD2CPointTestReq,
  input wire logic receivedEndTxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    TxInitD2CPointTestSenderState_idle                   = 4'h0,
    TxInitD2CPointTestSenderState_sendStartReq           = 4'h1,
    TxInitD2CPointTestSenderState_waitStartResp          = 4'h2,
    TxInitD2CPointTestSenderState_resetScrambler         = 4'h3,
    TxInitD2CPointTestSenderState_sendLfsrClearErrorReq  = 4'h4,
    TxInitD2CPointTestSenderState_waitLfsrClearErrorResp = 4'h5,
    TxInitD2CPointTestSenderState_requestPatternSend     = 4'h6,
    TxInitD2CPointTestSenderState_waitPatternSent        = 4'h7,
    TxInitD2CPointTestSenderState_sendResultsReq         = 4'h8,
    TxInitD2CPointTestSenderState_waitResultsResp        = 4'h9,
    TxInitD2CPointTestSenderState_sendEndReq             = 4'hA,
    TxInitD2CPointTestSenderState_waitEndResp            = 4'hB,
    TxInitD2CPointTestSenderState_finish                 = 4'hC
  } TxInitD2CPointTestSenderState_t;

  (* keep = "true" *) TxInitD2CPointTestSenderState_t stateReg;
  (* keep = "true" *) logic prevStart;

  // Sticky action registers. They clear only on reset or a new start rising edge.
  (* keep = "true" *) logic sendStartReqReg;
  (* keep = "true" *) logic resetScramblerReg;
  (* keep = "true" *) logic sendLfsrReqReg;
  (* keep = "true" *) logic sendPatternReg;
  (* keep = "true" *) logic sendResultsReqReg;
  (* keep = "true" *) logic sendEndReqReg;

  wire startPulse = start && !prevStart;

  always_comb begin
    state = stateReg;

    busy = (stateReg != TxInitD2CPointTestSenderState_idle) &&
           (stateReg != TxInitD2CPointTestSenderState_finish);
    done = (stateReg == TxInitD2CPointTestSenderState_finish);

    sendStartTxInitD2CPointTestReq = sendStartReqReg;
    resetLocalScrambler            = resetScramblerReg;
    sendLfsrClearErrorReq          = sendLfsrReqReg;
    sendDefinedPattern             = sendPatternReg;
    sendTxInitD2CResultsReq        = sendResultsReqReg;
    sendEndTxInitD2CPointTestReq   = sendEndReqReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg          <= TxInitD2CPointTestSenderState_idle;
      prevStart         <= 1'b0;
      sendStartReqReg   <= 1'b0;
      resetScramblerReg <= 1'b0;
      sendLfsrReqReg    <= 1'b0;
      sendPatternReg    <= 1'b0;
      sendResultsReqReg <= 1'b0;
      sendEndReqReg     <= 1'b0;
    end else begin
      prevStart <= start;

      // A rising edge of start restarts the sequence from any state and clears
      // every sticky action register, matching the Chisel priority.
      if (startPulse) begin
        stateReg          <= TxInitD2CPointTestSenderState_sendStartReq;
        sendStartReqReg   <= 1'b0;
        resetScramblerReg <= 1'b0;
        sendLfsrReqReg    <= 1'b0;
        sendPatternReg    <= 1'b0;
        sendResultsReqReg <= 1'b0;
        sendEndReqReg     <= 1'b0;
      end else begin
        case (stateReg)
          TxInitD2CPointTestSenderState_idle: begin
            stateReg <= TxInitD2CPointTestSenderState_idle;
          end

          TxInitD2CPointTestSenderState_sendStartReq: begin
            sendStartReqReg <= 1'b1;
            if (sentStartTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitStartResp;
            end
          end

          TxInitD2CPointTestSenderState_waitStartResp: begin
            if (receivedStartTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestSenderState_resetScrambler;
            end
          end

          TxInitD2CPointTestSenderState_resetScrambler: begin
            resetScramblerReg <= 1'b1;
            stateReg <= TxInitD2CPointTestSenderState_sendLfsrClearErrorReq;
          end

          TxInitD2CPointTestSenderState_sendLfsrClearErrorReq: begin
            sendLfsrReqReg <= 1'b1;
            if (sentLfsrClearErrorReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitLfsrClearErrorResp;
            end
          end

          TxInitD2CPointTestSenderState_waitLfsrClearErrorResp: begin
            if (receivedLfsrClearErrorResp) begin
              stateReg <= TxInitD2CPointTestSenderState_requestPatternSend;
            end
          end

          TxInitD2CPointTestSenderState_requestPatternSend: begin
            sendPatternReg <= 1'b1;
            stateReg <= TxInitD2CPointTestSenderState_waitPatternSent;
          end

          TxInitD2CPointTestSenderState_waitPatternSent: begin
            if (sentDefinedPattern) begin
              stateReg <= TxInitD2CPointTestSenderState_sendResultsReq;
            end
          end

          TxInitD2CPointTestSenderState_sendResultsReq: begin
            sendResultsReqReg <= 1'b1;
            if (sentTxInitD2CResultsReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitResultsResp;
            end
          end

          TxInitD2CPointTestSenderState_waitResultsResp: begin
            if (receivedTxInitD2CResultsResp) begin
              stateReg <= TxInitD2CPointTestSenderState_sendEndReq;
            end
          end

          TxInitD2CPointTestSenderState_sendEndReq: begin
            sendEndReqReg <= 1'b1;
            if (sentEndTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitEndResp;
            end
          end

          TxInitD2CPointTestSenderState_waitEndResp: begin
            if (receivedEndTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestSenderState_finish;
            end
          end

          TxInitD2CPointTestSenderState_finish: begin
            stateReg <= TxInitD2CPointTestSenderState_finish;
          end

          default: begin
            // Chisel's switch has no default assignment; retain all registers
            // if an illegal state is observed rather than inventing recovery.
          end
        endcase
      end
    end
  end
endmodule

`default_nettype wire

```

<a id="Types-sv"></a>

## [48] Types.sv

```systemverilog
// FILE_INDEX: 48
// FILE_PATH : Types.sv

// Hand-translated synthesizable SystemVerilog.
// Source: Types(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_interfaces_pkg;
  // UCIe logical-link state encoding shared by the FDI and RDI controllers.
  typedef enum logic [3:0] {
    PhyState_reset       = 4'h0,
    PhyState_active      = 4'h1,
    PhyState_activePmNak = 4'h3,
    PhyState_l1          = 4'h4,
    PhyState_l2          = 4'h8,
    PhyState_linkReset   = 4'h9,
    PhyState_linkError   = 4'hA,
    PhyState_retrain     = 4'hB,
    PhyState_disabled    = 4'hC
  } PhyState_t;

  // UCIe upper-layer state request encoding shared by FDI and RDI.
  typedef enum logic [3:0] {
    PhyStateReq_nop       = 4'h0,
    PhyStateReq_active    = 4'h1,
    PhyStateReq_l1        = 4'h4,
    PhyStateReq_l2        = 4'h8,
    PhyStateReq_linkReset = 4'h9,
    PhyStateReq_retrain   = 4'hB,
    PhyStateReq_disabled  = 4'hC
  } PhyStateReq_t;
endpackage

`default_nettype wire

```

<a id="UCIePhyRegisterBlock-sv"></a>

## [49] UCIePhyRegisterBlock.sv

```systemverilog
// FILE_INDEX: 49
// FILE_PATH : UCIePhyRegisterBlock.sv

// Twelve writable 32-bit registers and two 64-bit registers, using UCIe layouts.
// This simple bank does not enforce RO, reserved-bit, W1C or capability rules:
// software and local hardware are responsible for the values they write.
// Link DVSEC uses 0x00C/0x010/0x014; PHY uses full addresses from 0x1000.
// Reads are combinational; writes occur on rising edges, with local priority.
module UCIePhyRegisterBlock (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Local port: write one 32-bit word when we=1.
    input  logic        local_we_i,
    input  logic [31:0] local_addr_i,
    input  logic [31:0] local_wdata_i,
    output logic [31:0] local_rdata_o,

    // SB port: keep we/address/data/BE stable until an edge with waccepted=1.
    input  logic        sb_we_i,
    input  logic [31:0] sb_addr_i,
    input  logic [31:0] sb_wdata_i,
    input  logic [3:0]  sb_be_i,
    output logic [31:0] sb_rdata_o,
    output logic        sb_waccepted_o,
    output logic [31:0] phy_control_o
);
    // UCIe Link Capability, address 0x00C (9.5.1.4, Table 9-8).
    // Advertises Link and Adapter capabilities to software. Writable here like the
    // existing registers; RO, HWInit and reserved-field rules are not enforced.
    // [0] Raw Format; [3:1] max width: 0=x16, 1=x32, 2=x64, 3=x128, 4=x256, 7=x8;
    // [7:4] max speed: 0=4, 1=8, 2=12, 3=16, 4=24, 5=32 GT/s; [8] Retimer;
    // [9] multi-protocol; [10] Advanced Package; [15:11] Streaming Flit Formats;
    // [16] enhanced multi-protocol; [17] PCIe standard start header;
    // [18] PCIe latency-optimized optional bytes; [19] parity error signaling;
    // [20] Advanced module width: 1=x32, 0=x64; [21] x32 support in x64 module;
    // [22] Standard module width: 1=x8, 0=x16; [23] sideband PMO; [31:24] reserved.
    logic [31:0] ucie_link_capability_q;

    // UCIe Link Control, address 0x010 (9.5.1.5, Table 9-9).
    // Stores requested settings. This bank does not start training, automatically
    // clear command bits, or constrain values against Link Capability.
    // [0] Raw enable; [1] multi-protocol; [5:2] target width; [9:6] target speed;
    // [10] start training; [11] retrain; [12] unused; [17:13] Streaming formats;
    // [18] enhanced multi-protocol; [19] PCIe standard start header;
    // [20] PCIe latency-optimized optional bytes; [21] sideband PMO; [31:22] reserved.
    logic [31:0] ucie_link_control_q;

    // UCIe Link Status, address 0x014 (9.5.1.6, Table 9-10).
    // Stores observed Link results. This bank does not implement RO, RW1C/RW1CS,
    // mirroring, or automatic event/status updates.
    // [0] Raw enabled; [1] multi-protocol; [2] enhanced multi-protocol;
    // [3] x32 Advanced module; [6:4] reserved; [10:7] active width;
    // [14:11] active speed; [15] Link up; [16] training; [17] status changed;
    // [18] bandwidth changed; [19] correctable error; [20] non-fatal error;
    // [21] fatal error; [25:22] Flit Format; [26] sideband PMO; [31:27] reserved.
    logic [31:0] ucie_link_status_q;

    // PHY Capability, address 0x1000 (UCIe Table 9-47).
    // Describes the PHY's supported features. Initialize it to match the hardware;
    // consumers read it before choosing settings. Writable here like any register.
    // [2:0] reserved; [3] RX termination support; [4] TX equalization support;
    // [9:5] TX swing code: 1=0.40 V, 2=0.45 V, ... 16=1.15 V;
    // [10] reserved; [12:11] RX clock: 00=strobe/free-running, 10=free-running only;
    // [14:13] phase: 00=differential, 01/10=quadrature at 24/32 GT/s and
    // differential up to 16 GT/s; [15] package: 1=Standard, 0=Advanced;
    // [16] TCM support; [31:17] reserved. Other field encodings are reserved.
    logic [31:0] phy_capability_q;

    // PHY Control, address 0x1004 (UCIe Table 9-48).
    // Stores requested settings. The PHY controller reads phy_control_o and
    // applies them; writing Control does not automatically change Status.
    // [2:0] reserved; [3] RX termination enable; [4] TX equalization enable;
    // [5] RX clock: 0=strobe, 1=free-running; [6] phase: 0=differential only,
    // 1=quadrature at 24/32 GT/s and differential up to 16 GT/s;
    // [7] force x32 in Advanced x64 (not applicable to Standard Package);
    // [8] force x8 in Standard x16 for debug, only without lane reversal;
    // [31:9] reserved. The caller must select supported settings.
    logic [31:0] phy_control_q;

    // PHY Status, address 0x1008 (UCIe Table 9-49).
    // Stores observed results provided by PHY hardware, for external monitoring.
    // Both ports can overwrite it; callers must avoid replacing real status with
    // requested settings. Clock fields describe the REMOTE partner, not Control.
    // [2:0] reserved; [3] actual local RX termination; [4] actual local TX EQ;
    // [5] remote RX clock mode: 0=strobe, 1=free-running;
    // [6] remote phase: 0=differential, 1=quadrature at 24/32 GT/s;
    // [7] lane reversal within the module; [31:8] reserved.
    logic [31:0] phy_status_q;

    // PHY Initialization and Debug, address 0x100C (9.5.3.25, Table 9-50).
    // NOT USED IN THE CURRENT VERSION: storage only; no LTSM pause/resume logic.
    // Software can select a training pause point for future debug integration.
    // [2:0] initialization control: 000=normal training to ACTIVE;
    // 001=pause after MBINIT.PARAM step 2; 010=after MBTRAIN.VALVREF step 1;
    // 011=after MBTRAIN.RXDESKEW step 1; 100=after MBTRAIN.DATATRAINCENTER2
    // step 1 (the last two apply to initial training and retraining).
    // Other codes reserved. [4:3] reserved; [5] Resume Training: a 0->1
    // transition requests continuation; [31:6] reserved. Reset: zero.
    // Future LTSM integration must disable the relevant timeouts while paused;
    // a corresponding remote sideband message can also allow training to resume.
    // This register does not automatically start training or clear Resume Training.
    logic [31:0] phy_init_debug_q;

    // Training Setup 1, module 0, address 0x1010 (9.5.3.26, Table 9-51).
    // Configuration for the pattern generator/training controller, not results.
    // Software/FW may program it via SB before a test; local PHY may configure it
    // if the integration assigns ownership to hardware. No automatic updates here.
    // [2:0] data pattern: 000=per-lane LFSR, 001=per-lane ID;
    // PHY-Compliance only: 010=AA clock, 011=all zeros, 100=all ones,
    // 101=inverted clock. Other codes reserved.
    // [5:3] valid pattern: 000=functional 1111 0000 (LSB first); others reserved.
    // [9:6] clock phase: 0=TX-found clock PI center, 1=left training edge,
    // 2=right training edge; others reserved. [10] mode: 0=continuous, 1=burst.
    // [26:11] burst duration in UI (not bank clock cycles), default 4.
    // [31:27] reserved. Other fields default zero: reset word = 0x00002000.
    logic [31:0] training_setup1_q;

    // Training Setup 2, module 0, address 0x1020 (9.5.3.27, Table 9-52).
    // Complements Setup 1: the pattern controller executes burst/idle iterations.
    // [15:0] idle count: low duration after a burst in UI, default 4.
    // [31:16] iterations of burst followed by idle, default 4.
    // Reset = 0x00040004. RW configuration; counters live outside this bank.
    logic [31:0] training_setup2_q;

    // Training Setup 3, module 0, addresses 0x1030/0x1034 (9.5.3.28, Table 9-53).
    // RX comparison lane mask: bit n=1 excludes lane n from comparison;
    // bit n=0 does not mask it. It does not turn lanes off or mark them failed.
    // [63:0] lane mask, reset zero (none masked). The RX comparator consumes it.
    // 0x1030 accesses [31:0]; 0x1034 accesses [63:32]. Writes preserve the other
    // half; two accesses are not atomic. Program while idle or coordinate use.
    logic [63:0] training_setup3_q;

    // Training Setup 4, module 0, address 0x1050 (9.5.3.29, Table 9-54).
    // RX comparison configuration, not an error counter. Reset: zero.
    // [3:0] redundant repair-lane mask: bit 0 masks RD0, bit 1 masks RD1, etc.
    // [15:4] per-lane comparison error threshold for counting to start.
    // [31:16] aggregate comparison error threshold for counting to start.
    // Threshold zero counts all errors. Repair-lane applicability depends on PHY.
    // Thresholds are carried in the corresponding TX/RX-initiated Data-to-Clock
    // point-test and eye-sweep SB messages: remote uses them for TX-initiated
    // tests; RX uses them locally and informs the remote for RX-initiated tests.
    // Caller controls settings; comparison and message generation are external.
    logic [31:0] training_setup4_q;

    // Current Lane Map Module 0, addresses 0x1060/0x1064 (UCIe 9.5.3.30,
    // Table 9-55, D2D/PHY offset 0x1060). Reset: all zero.
    // Bit n indicates physical RX lane n is operational. PHY training logic
    // supplies the map; writing it does not activate or repair physical lanes.
    // Standard Package uses [15:0]; [63:16] do not apply and callers should keep
    // them zero. This simple RW bank does not enforce that restriction.
    // 0x1060 accesses [31:0]; 0x1064 accesses [63:32]. Each write preserves the
    // other half. Two accesses are not atomic; coordinate snapshots externally.
    logic [63:0] current_lane_map_module0_q;

    // Error Log 0, address 0x1080 (UCIe Table 9-59, module 0).
    // Training history for diagnosis. The LTSM builds and writes this word;
    // this bank does not shift states or detect training failures automatically.
    // [7:0] latest state N; [8] lane reversal; [9] width degradation (Standard);
    // [15:10] reserved; [23:16] state N-1; [31:24] state N-2.
    // State encodings (hex), also used by N-3 in Log 1:
    // 00 RESET, 01 SBINIT, 02 MBINIT.PARAM, 03 MBINIT.CAL, 04 MBINIT.REPAIRCLK,
    // 05 MBINIT.REPAIRVAL, 06 MBINIT.REVERSALMB, 07 MBINIT.REPAIRMB,
    // 08 MBTRAIN.VALVREF, 09 MBTRAIN.DATAVREF, 0A MBTRAIN.SPEEDIDLE,
    // 0B MBTRAIN.TXSELFCAL, 0C MBTRAIN.RXSELFCAL, 0D MBTRAIN.VALTRAINCENTER,
    // 0E MBTRAIN.VALTRAINVREF, 0F MBTRAIN.DATATRAINCENTER1,
    // 10 MBTRAIN.DATATRAINVREF, 11 MBTRAIN.RXDESKEW, 12 MBTRAIN.DATATRAINCENTER2,
    // 13 MBTRAIN.LINKSPEED, 14 MBTRAIN.REPAIR, 15 PHYRETRAIN, 16 LINKINIT,
    // 17 ACTIVE, 18 TRAINERROR, 19 L1/L2; other encodings reserved.
    logic [31:0] error_log0_q;

    // Error Log 1, address 0x1090 (UCIe Table 9-60, module 0).
    // Additional history and PHY error flags, supplied explicitly by the caller.
    // [7:0] state N-3; [8] training timeout escalated to fatal;
    // [9] sideband handshake timeout, excluding training messages;
    // [10] remote LinkError request over RDI sideband; [11] internal PHY error;
    // [31:12] reserved. All bits are ordinary RW in this simplified bank:
    // writing 1 stores 1, writing 0 stores 0. No automatic events or W1C/W1S.
    // Callers coordinate updates and preserve any history/errors they want to keep.
    logic [31:0] error_log1_q;

    // Two independent combinational read ports; unknown addresses return zero.
    always_comb begin
        case (local_addr_i)
            32'h00C: local_rdata_o = ucie_link_capability_q;
            32'h010: local_rdata_o = ucie_link_control_q;
            32'h014: local_rdata_o = ucie_link_status_q;
            32'h1000: local_rdata_o = phy_capability_q;
            32'h1004: local_rdata_o = phy_control_q;
            32'h1008: local_rdata_o = phy_status_q;
            32'h100C: local_rdata_o = phy_init_debug_q;
            32'h1010: local_rdata_o = training_setup1_q;
            32'h1020: local_rdata_o = training_setup2_q;
            32'h1030: local_rdata_o = training_setup3_q[31:0];
            32'h1034: local_rdata_o = training_setup3_q[63:32];
            32'h1050: local_rdata_o = training_setup4_q;
            32'h1060: local_rdata_o = current_lane_map_module0_q[31:0];
            32'h1064: local_rdata_o = current_lane_map_module0_q[63:32];
            32'h1080: local_rdata_o = error_log0_q;
            32'h1090: local_rdata_o = error_log1_q;
            default: local_rdata_o = 32'b0;
        endcase
        case (sb_addr_i)
            32'h00C: sb_rdata_o = ucie_link_capability_q;
            32'h010: sb_rdata_o = ucie_link_control_q;
            32'h014: sb_rdata_o = ucie_link_status_q;
            32'h1000: sb_rdata_o = phy_capability_q;
            32'h1004: sb_rdata_o = phy_control_q;
            32'h1008: sb_rdata_o = phy_status_q;
            32'h100C: sb_rdata_o = phy_init_debug_q;
            32'h1010: sb_rdata_o = training_setup1_q;
            32'h1020: sb_rdata_o = training_setup2_q;
            32'h1030: sb_rdata_o = training_setup3_q[31:0];
            32'h1034: sb_rdata_o = training_setup3_q[63:32];
            32'h1050: sb_rdata_o = training_setup4_q;
            32'h1060: sb_rdata_o = current_lane_map_module0_q[31:0];
            32'h1064: sb_rdata_o = current_lane_map_module0_q[63:32];
            32'h1080: sb_rdata_o = error_log0_q;
            32'h1090: sb_rdata_o = error_log1_q;
            default: sb_rdata_o = 32'b0;
        endcase
    end

    assign phy_control_o = phy_control_q;
    // Combinational acceptance at the clock edge, not a delayed completion pulse.
    // Continuous local writes defer SB. Unmapped SB writes are acknowledged no-ops.
    assign sb_waccepted_o = rst_ni && sb_we_i && !local_we_i;

    // Register updates. Keep the previous example reset values explicitly.
    // Domain Reset clears history; Link Down alone must not assert this reset.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ucie_link_capability_q <= 32'h0000_0001;
            ucie_link_control_q    <= 32'h0000_0000;
            ucie_link_status_q     <= 32'h0000_0000;
            phy_capability_q <= 32'h0000_8028;
            phy_control_q    <= 32'h0000_0008;
            phy_status_q     <= 32'h0000_0008;
            phy_init_debug_q <= 32'h0000_0000;
            training_setup1_q <= 32'h0000_2000;
            training_setup2_q <= 32'h0004_0004;
            training_setup3_q <= 64'h0000_0000_0000_0000;
            training_setup4_q <= 32'h0000_0000;
            current_lane_map_module0_q <= 64'h0000_0000_0000_0000;
            error_log0_q     <= 32'h0000_0000;
            error_log1_q     <= 32'h0000_0000;
        end else if (local_we_i) begin
            case (local_addr_i)
                32'h00C: ucie_link_capability_q <= local_wdata_i;
                32'h010: ucie_link_control_q    <= local_wdata_i;
                32'h014: ucie_link_status_q     <= local_wdata_i;
                32'h1000: phy_capability_q <= local_wdata_i;
                32'h1004: phy_control_q    <= local_wdata_i;
                32'h1008: phy_status_q     <= local_wdata_i;
                32'h100C: phy_init_debug_q <= local_wdata_i;
                32'h1010: training_setup1_q <= local_wdata_i;
                32'h1020: training_setup2_q <= local_wdata_i;
                32'h1030: training_setup3_q[31:0] <= local_wdata_i;
                32'h1034: training_setup3_q[63:32] <= local_wdata_i;
                32'h1050: training_setup4_q <= local_wdata_i;
                32'h1060: current_lane_map_module0_q[31:0]  <= local_wdata_i;
                32'h1064: current_lane_map_module0_q[63:32] <= local_wdata_i;
                32'h1080: error_log0_q     <= local_wdata_i;
                32'h1090: error_log1_q     <= local_wdata_i;
                default: begin end
            endcase
        end else if (sb_waccepted_o) begin
            // BE selects bytes only
            for (int b = 0; b < 4; b++) begin
                if (sb_be_i[b]) begin
                    case (sb_addr_i)
                        32'h00C: ucie_link_capability_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h010: ucie_link_control_q[b*8 +: 8]    <= sb_wdata_i[b*8 +: 8];
                        32'h014: ucie_link_status_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h1000: phy_capability_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1004: phy_control_q[b*8 +: 8]    <= sb_wdata_i[b*8 +: 8];
                        32'h1008: phy_status_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h100C: phy_init_debug_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1010: training_setup1_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1020: training_setup2_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1030: training_setup3_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1034: training_setup3_q[32+b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1050: training_setup4_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1060: current_lane_map_module0_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1064: current_lane_map_module0_q[32+b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1080: error_log0_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h1090: error_log1_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        default: begin end
                    endcase
                end
            end
        end
    end
endmodule

```

