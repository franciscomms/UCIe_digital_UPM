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
//   u_sideband     SidebandWrapper                Whole sideband path: LTSM TX/RX
//                                                 adapters, packet arbiter, RX holding
//                                                 register and SideBandModule PHY.
//                                                 See SidebandWrapper.sv for details.
//
// Glue logic kept in this top (intentionally, end of file): the ltsm state ->
// PHY state decode that drives ltsmInbandPresent into rdi, and the debug/state
// output assigns.
//
// Sideband message path:
//   ltsm / fdi / rdi <-> u_sideband <-> sb_tx_dout / sb_tx_clk, sb_rx_din / sb_rx_clk
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
  output var logic                               fdi_active,
  // Suppress RDI request/FDI parameter timeout errors; retain recovery timers.
  input wire logic timeout_disable,

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

  // LTSM MBTRAIN shared D2C sender/receiver and TX-deskew interface
  // (muxed inside MBTrainFSM between VALTRAINCENTER, DATATRAINCENTER1/2 and LINKSPEED).
  output var logic           ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic           ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic            ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic           ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic           ltsm_flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]    ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic           ltsm_flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]     ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]     ltsm_flagToAnalog_d2cReceiver_dataPattern,
  output var logic           ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic           ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic           ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic           ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
  // TX deskew: 20 bits/lane, cell 1 [9:0], cell 2 [19:10]; LSB + 9 thermometer bits/cell.
  output var logic [64*d2cTxDeskewCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic           ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,

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

  // LTSM MBTRAIN.LINKSPEED interface.
  output var logic           ltsm_flagToLtsm_linkSpeed_phyInRetrain,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
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
  output var logic [1:0] debug_arb_rr_last_source,
  output var logic debug_arb_rr_last_granted_rdi,
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

  // LTSM state.
  wire logic [3:0] ltsm_state_int;
  UcieUPM_interfaces_pkg::PhyState_t ltsmPhyState;
  wire logic       ltsmInbandPresent;

  // LTSM sideband client (pulse interface).
  wire logic         ltsm_raw_tx_valid;
  wire logic [127:0] ltsm_raw_tx_msg;
  wire logic         ltsm_raw_tx_ready;
  wire logic         ltsm_pulse_rx_valid;
  wire logic [127:0] ltsm_pulse_rx_msg;

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
    .fdi_active           (fdi_active),

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
    .timeout_disable      (timeout_disable),
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
    .timeout_disable      (timeout_disable),
    .cycles_1us           (cycles_1us)
  );

  // --------------------------------------------------------------------------
  // Sideband path (ltsm / fdi / rdi <-> serial sideband pins)
  // --------------------------------------------------------------------------
  SidebandWrapper #(
    .SB_TX_FIFO_ENTRIES      (SB_TX_FIFO_ENTRIES),
    .LTSM_TX_CAPTURE_ENTRIES (4)
  ) u_sideband (
    .clock                         (clock),
    .reset_n                       (reset_n),

    .ltsm_tx_valid                 (ltsm_raw_tx_valid),
    .ltsm_tx_msg                   (ltsm_raw_tx_msg),
    .ltsm_tx_ready                 (ltsm_raw_tx_ready),
    .ltsm_rx_valid                 (ltsm_pulse_rx_valid),
    .ltsm_rx_msg                   (ltsm_pulse_rx_msg),

    .fdi_tx_valid                  (fdi_sb_snd_valid),
    .fdi_tx_msg                    (fdi_sb_snd_msg),
    .fdi_tx_ready                  (fdi_sb_snd_ready),
    .fdi_rx_valid                  (fdi_sb_rcv_valid),
    .fdi_rx_msg                    (fdi_sb_rcv_msg),
    .fdi_rx_ready                  (fdi_sb_rcv_ready),

    .rdi_tx_valid                  (rdi_sb_snd_valid),
    .rdi_tx_msg                    (rdi_sb_snd_msg),
    .rdi_tx_ready                  (rdi_sb_snd_ready),
    .rdi_rx_valid                  (rdi_sb_rcv_valid),
    .rdi_rx_msg                    (rdi_sb_rcv_msg),
    .rdi_rx_ready                  (rdi_sb_rcv_ready),

    .sb_tx_dout                    (sb_tx_dout),
    .sb_tx_clk                     (sb_tx_clk),
    .sb_rx_din                     (sb_rx_din),
    .sb_rx_clk                     (sb_rx_clk),

    .debug_arb_grant_ltsm          (debug_arb_grant_ltsm),
    .debug_arb_grant_fdi           (debug_arb_grant_fdi),
    .debug_arb_grant_rdi           (debug_arb_grant_rdi),
    .debug_arb_tx_locked           (debug_arb_tx_locked),
    .debug_arb_rr_last_source      (debug_arb_rr_last_source),
    .debug_arb_rr_last_granted_rdi (debug_arb_rr_last_granted_rdi),
    .debug_arb_tx_fire             (debug_arb_tx_fire),
    .debug_rx_route_ltsm           (debug_rx_route_ltsm),
    .debug_rx_route_fdi            (debug_rx_route_fdi),
    .debug_rx_route_rdi            (debug_rx_route_rdi),
    .debug_rx_drop_unknown         (debug_rx_drop_unknown),
    .debug_rx_fire                 (debug_rx_fire),
    .debug_sb_rx_overflow          (debug_sb_rx_overflow)
  );

  // --------------------------------------------------------------------------
  // Link training (LTSM)
  // --------------------------------------------------------------------------
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
    .flagToAnalog_d2cSender_sendValTrainPattern                 (ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainPatternSent               (ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler                 (ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase                   (ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode                    (ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied               (ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest       (ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold   (ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode                    (ltsm_flagToAnalog_d2cReceiver_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings            (ltsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings                 (ltsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings                (ltsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode                       (ltsm_flagToAnalog_d2cReceiver_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl                 (ltsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern                      (ltsm_flagToAnalog_d2cReceiver_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern                       (ltsm_flagToAnalog_d2cReceiver_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler             (ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo         (ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload         (ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .flagToAnalog_d2cSender_sendLfsrPattern                   (ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent                 (ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .flagToAnalog_d2cSender_applyTxLaneDeskew                 (ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_txLaneDeskewCodes                 (ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_txLaneDeskewApplied             (ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
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
    .flagToLtsm_linkSpeed_phyInRetrain                                         (ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .flagFromAnalog_d2cReceiver_laneComparisonSuccessful             (ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
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

endmodule

`default_nettype wire
