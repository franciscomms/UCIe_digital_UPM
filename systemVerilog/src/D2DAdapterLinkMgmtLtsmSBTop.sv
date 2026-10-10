`default_nettype none

// ============================================================================
// D2DAdapterLinkMgmtLtsmSBTop
// Single top for the UCIe D2D adapter: FDI/RDI link management, link training
// (LTSM) and the serial sideband PHY. Merges the former D2DAdapterLinkMgmtTop,
// D2DAdapterLinkMgmtLtsmTop and D2DAdapterLinkMgmtLtsmSBTop wrappers.
// Reset convention: asynchronous active-low reset_n goes to every child.
//
// Modules and connections:
//   fdi            LinkManagementController       FDI state machine. Talks to the
//                                                 protocol layer on the fdi_* ports and
//                                                 drives/monitors rdi state requests.
//   rdi            RdiLinkManagementController    RDI state machine. Follows fdi requests
//                                                 and the LTSM link-up status
//                                                 (ltsmInbandPresent). Wake/clock
//                                                 handshake toward the LTSM is tied off.
//   ltsm           LinkTrainingFSM                Link training. Analog/training flags on
//                                                 the ltsm_* ports; its state is mapped
//                                                 to a PHY state that feeds rdi.
//   ltsmTxCapture  LtsmSidebandTxCapture          4-entry queue: ltsm pulse TX -> arb.
//   ltsmRxPulse    LtsmSidebandRxPulseAdapter     arb valid/ready RX -> ltsm pulse RX.
//   arb            LinkMgmtSidebandPacketArbiter  Merges ltsm/fdi/rdi TX messages into
//                                                 one stream; routes RX messages back.
//   (always_ff)    RX holding register            u_sideband_phy pulse RX -> arb
//                                                 valid/ready; sticky debug_sb_rx_overflow.
//   u_sideband_phy SideBandModule                 128-bit messages <-> serial sb_* pins.
//
// Sideband message path:
//   TX: ltsm -> ltsmTxCapture -+
//       fdi -------------------+-> arb -> u_sideband_phy -> sb_tx_dout / sb_tx_clk
//       rdi -------------------+
//   RX: sb_rx_din / sb_rx_clk -> u_sideband_phy -> RX holding reg -> arb
//       arb -> ltsmRxPulse -> ltsm,  arb -> fdi,  arb -> rdi
// ============================================================================

module D2DAdapterLinkMgmtLtsmSBTop #(
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
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES,
  parameter int unsigned SB_TX_FIFO_ENTRIES = 4
) (
  // ==========================================================================
  // COMMON CLOCK AND RESET
  // ==========================================================================
  input wire logic clock,
  input wire logic reset_n,

  // ==========================================================================
  // FDI INTERFACE
  // Protocol layer <-> D2D adapter link-management interface.
  // ==========================================================================
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

  // ==========================================================================
  // LINK-MANAGEMENT TIMING REFERENCE
  // Used by the FDI and RDI link-management timeout counters.
  // ==========================================================================
  input wire logic [31:0] cycles_1us,

  // ==========================================================================
  // LTSM INTERFACE
  // Flattened LinkTrainingFSM interface toward the analog/PHY control logic.
  // ==========================================================================

  // LTSM startup and analog readiness inputs.
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
  // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
  output var logic [2:0]     ltsm_dbg_mbinitSubstate,
  output var logic [4:0]     ltsm_dbg_mbinitReversalMbReceivedSuccessCount,

  // LTSM MBTRAIN.VALVREF interface.
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

  // LTSM MBTRAIN.DATAVREF interface.
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

  // LTSM MBTRAIN.RXCLKCAL interface.
  output var logic           ltsm_flagToAnalog_rxClkCal_doCalibration,
  input wire logic           ltsm_flagFromAnalog_rxClkCal_done,
  output var logic           ltsm_flagToAnalog_rxClkCal_sendClockTrack,

  // LTSM MBTRAIN.VALTRAINCENTER interface.
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

  // LTSM MBTRAIN.VALTRAINVREF interface.
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

  // LTSM MBTRAIN.DATATRAINCENTER1 interface.
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

  // LTSM MBTRAIN.DATATRAINVREF interface.
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

  // LTSM MBTRAIN.RXDESKEW interface.
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

  // LTSM MBTRAIN.DATATRAINCENTER2 interface.
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

  // LTSM MBTRAIN.LINKSPEED interface.
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
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  output var logic [11:0]    ltsm_dbg_mbtrainActiveSubstate,
  output var logic [15:0]    ltsm_dbg_mbtrainLastErrorCount,
  output var logic [15:0]    ltsm_dbg_mbtrainRetryCount,

  // ==========================================================================
  // SIDEBAND PHY INTERFACE
  // Serialized pins connected to the remote die.
  // ==========================================================================
  output var logic sb_tx_dout,
  output var logic sb_tx_clk,
  input wire logic sb_rx_din,
  input wire logic sb_rx_clk,

  // Sideband receive-buffer status. Sticky until reset.
  output var logic debug_sb_rx_overflow,

  // ==========================================================================
  // FDI / RDI / LTSM / SIDEBAND INTEGRATION DEBUG
  // RDI is internal to this top, so its externally visible
  // signals are debug/status outputs rather than a separate functional port.
  // ==========================================================================
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
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  // --------------------------------------------------------------------------
  // Internal nets
  // --------------------------------------------------------------------------
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

  // LTSM state and sideband adapters.
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

  // Arbiter <-> sideband PHY (message level).
  logic         sb_msg_tx_valid;
  logic [127:0] sb_msg_tx_msg;
  logic         sb_msg_tx_ready;
  logic         sb_phy_rx_valid;
  logic [127:0] sb_phy_rx_msg;
  logic         sb_msg_rx_valid;
  logic [127:0] sb_msg_rx_msg;
  logic         sb_msg_rx_ready;

  // --------------------------------------------------------------------------
  // FDI link management
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // RDI link management
  // The LTSM has no wake/clock handshake pins, so the RDI-side handshake is
  // kept awake (wake_req = 0, clk_ack = 1), matching the Chisel tie-offs.
  // --------------------------------------------------------------------------
  RdiLinkManagementController rdi (
    .clock                (clock),
    .reset_n              (reset_n),

    .ltsm_lp_wake_req     (1'b0),
    .ltsm_pl_wake_ack     (),
    .ltsm_pl_clk_req      (),
    .ltsm_lp_clk_ack      (1'b1),

    .lp_state_req         (fdi_rdi_lp_state_req),
    .pl_state_sts         (rdi_pl_state_sts_int),
    .pl_stallreq          (rdi_pl_stall_req_int),
    .lp_stallack          (fdi_rdi_lp_stall_ack),
    .rdi_pl_inband_pres   (rdi_pl_inband_pres_int),
    .ltsm_pl_inband_pres  (ltsmInbandPresent),

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

  // --------------------------------------------------------------------------
  // Sideband packet arbiter (ltsm / fdi / rdi <-> one message stream)
  // --------------------------------------------------------------------------
  LinkMgmtSidebandPacketArbiter arb (
    .clock                 (clock),
    .reset_n               (reset_n),

    .ltsm_tx_valid         (ltsm_queue_tx_valid),
    .ltsm_tx_msg           (ltsm_queue_tx_msg),
    .ltsm_tx_ready         (ltsm_queue_tx_ready),

    .fdi_tx_valid          (fdi_sb_snd_valid),
    .fdi_tx_msg            (fdi_sb_snd_msg),
    .fdi_tx_ready          (fdi_sb_snd_ready),

    .rdi_tx_valid          (rdi_sb_snd_valid),
    .rdi_tx_msg            (rdi_sb_snd_msg),
    .rdi_tx_ready          (rdi_sb_snd_ready),

    .tx_out_valid          (sb_msg_tx_valid),
    .tx_out_msg            (sb_msg_tx_msg),
    .tx_out_ready          (sb_msg_tx_ready),

    .rx_in_valid           (sb_msg_rx_valid),
    .rx_in_msg             (sb_msg_rx_msg),
    .rx_in_ready           (sb_msg_rx_ready),

    .ltsm_rx_valid         (ltsm_stream_rx_valid),
    .ltsm_rx_msg           (ltsm_stream_rx_msg),
    .ltsm_rx_ready         (ltsm_stream_rx_ready),

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
    .rr_last_source        (),
    .rr_last_granted_rdi   (),
    .tx_fire               (debug_arb_tx_fire),

    .rx_route_ltsm         (debug_rx_route_ltsm),
    .rx_route_fdi          (debug_rx_route_fdi),
    .rx_route_rdi          (debug_rx_route_rdi),
    .rx_drop_unknown       (debug_rx_drop_unknown),
    .rx_fire               (debug_rx_fire)
  );

  // --------------------------------------------------------------------------
  // Link training (LTSM) and its sideband adapters
  // --------------------------------------------------------------------------
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

  // Port names below preserve the names used by the Chisel instance.
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
    // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
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
    // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
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

  assign debug_rdi_state            = rdi_pl_state_sts_int;
  assign debug_fdi_to_rdi_state_req = fdi_rdi_lp_state_req;

  // --------------------------------------------------------------------------
  // Sideband PHY
  // --------------------------------------------------------------------------
  // One-entry holding register converts the pulse-only PHY RX interface into
  // a valid/ready interface. This prevents loss when the integrated top stalls.
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sb_msg_rx_valid      <= 1'b0;
      sb_msg_rx_msg        <= 128'b0;
      debug_sb_rx_overflow <= 1'b0;
    end else begin
      if (sb_phy_rx_valid) begin
        if (!sb_msg_rx_valid || sb_msg_rx_ready) begin
          sb_msg_rx_msg   <= sb_phy_rx_msg;
          sb_msg_rx_valid <= 1'b1;
        end else begin
          debug_sb_rx_overflow <= 1'b1;
        end
      end else if (sb_msg_rx_valid && sb_msg_rx_ready) begin
        sb_msg_rx_valid <= 1'b0;
      end
    end
  end

  SideBandModule #(
    .TX_FIFO_ENTRIES (SB_TX_FIFO_ENTRIES)
  ) u_sideband_phy (
    .clock    (clock),
    .reset_n  (reset_n),
    .tx_din   (sb_msg_tx_msg),
    .tx_valid (sb_msg_tx_valid),
    .tx_ready (sb_msg_tx_ready),
    .tx_dout  (sb_tx_dout),
    .tx_clk   (sb_tx_clk),
    .rx_dout  (sb_phy_rx_msg),
    .rx_valid (sb_phy_rx_valid),
    .rxReset  (!reset_n),
    .rx_din   (sb_rx_din),
    .rx_clk   (sb_rx_clk)
  );

endmodule

`default_nettype wire
