`default_nettype none

// ============================================================================
// UcieDigitalCore
// Single top for the UCIe D2D adapter: FDI/RDI link management, link training
// (LTSM) and the serial sideband PHY. Merges the former D2DAdapterLinkMgmtTop,
// D2DAdapterLinkMgmtLtsmTop and UcieDigitalCore wrappers.
// Reset convention: asynchronous active-low reset_n goes to every child
// (held asserted for every block not under isolation test, muxed with
// jtag<Blk>_reset_n for the block under test; see block isolation test
// modes below).
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
//
// Block isolation test modes (testModeFdi, testModeRdi, testModeLtsm):
//   Block <Blk> = fdi (jtagFdi_*), rdi (jtagRdi_*) or ltsm (jtagLtsm_*).
//   Every port of the block instance (except clock) can be routed either to
//   its normal source/sink (core port, constant tie-off or net to another
//   block) or to the jtag<Blk>_<port> TDR pins.
//                     testMode<Blk> = 0             testMode<Blk> = 1
//   block input       normal source                 jtag<Blk>_<port>
//   block output      drives normal sink            drives jtag<Blk>_<port>
//                     (jtag<Blk>_<port> held at 0)  (normal sink held idle/0)
//   While any of these modes is set, every other block (and u_sideband) is
//   held in reset, and the nets from the block under test to the others are
//   forced idle (0: no request, no packet), so the rest of the core stays
//   quiet. At most one mode may be set; UcieDigitalTop enforces it. There is
//   no clock mux here: the core clock (from UcieDigitalTop) is
//   jtag<Blk>_clock during a block test.
// ============================================================================

module UcieDigitalCore #(
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
  output var logic debug_rx_fire,

  // ==========================================================================
  // FDI ISOLATION TEST (testModeFdi = 1)
  // One jtagFdi_<port> pin per LinkManagementController port (except clock),
  // same type and direction. Inputs are ignored and outputs held at 0 while
  // testModeFdi = 0.
  // ==========================================================================
  input wire logic testModeFdi,

  // Reset and timing. The fdi clock is the core clock: UcieDigitalTop selects
  // jtagFdi_clock on its single core clock mux, so all children stay aligned.
  input wire logic        jtagFdi_reset_n,
  input wire logic [31:0] jtagFdi_cycles_1us,
  input wire logic        jtagFdi_timeout_disable,

  // Protocol-layer side.
  input wire UcieUPM_interfaces_pkg::PhyStateReq_t jtagFdi_fdi_lp_state_req,
  input wire logic                                  jtagFdi_fdi_lp_linkerror,
  input wire logic                                  jtagFdi_fdi_lp_rx_active_sts,
  input wire logic                                  jtagFdi_fdi_lp_wake_req,
  input wire logic                                  jtagFdi_fdi_lp_clk_ack,
  input wire logic                                  jtagFdi_fdi_lp_stall_ack,
  output var UcieUPM_interfaces_pkg::PhyState_t jtagFdi_fdi_pl_state_sts,
  output var logic                               jtagFdi_fdi_pl_rx_active_req,
  output var logic                               jtagFdi_fdi_pl_inband_pres,
  output var logic                               jtagFdi_fdi_pl_wake_ack,
  output var logic                               jtagFdi_fdi_pl_clk_req,
  output var logic                               jtagFdi_fdi_pl_stall_req,
  output var logic                               jtagFdi_fdi_active,
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t jtagFdi_debug_link_init_state,

  // RDI side (normally connected to rdi).
  output var logic                                  jtagFdi_rdi_lp_linkerror,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t jtagFdi_rdi_lp_state_req,
  input wire UcieUPM_interfaces_pkg::PhyState_t    jtagFdi_rdi_pl_state_sts,
  input wire logic                                  jtagFdi_rdi_pl_inband_pres,
  output var logic                                  jtagFdi_fdiNeedsRdiAwake,
  input wire logic                                  jtagFdi_rdiAwake,
  input wire logic                                  jtagFdi_rdiNeedsFdiAwake,
  output var logic                                  jtagFdi_fdiAwake,
  input wire logic                                  jtagFdi_rdi_pl_stall_req,
  output var logic                                  jtagFdi_rdi_lp_stall_ack,

  // Sideband client side (normally connected to u_sideband).
  output var logic         jtagFdi_sb_snd_valid,
  output var logic [127:0] jtagFdi_sb_snd_msg,
  input wire logic         jtagFdi_sb_snd_ready,
  input wire logic         jtagFdi_sb_rcv_valid,
  input wire logic [127:0] jtagFdi_sb_rcv_msg,
  output var logic         jtagFdi_sb_rcv_ready,

  // ==========================================================================
  // RDI ISOLATION TEST
  // ==========================================================================
  input wire logic testModeRdi,

  // RDI ISOLATION TEST (testModeRdi = 1): one jtagRdi_<port> pin per
  // RdiLinkManagementController port (except clock), same type and direction.
  // Inputs are ignored and outputs held at 0 while testModeRdi = 0.
  input wire logic jtagRdi_reset_n,
  input wire logic jtagRdi_ltsm_lp_wake_req,
  output var logic jtagRdi_ltsm_pl_wake_ack,
  output var logic jtagRdi_ltsm_pl_clk_req,
  input wire logic jtagRdi_ltsm_lp_clk_ack,
  input wire UcieUPM_interfaces_pkg::PhyStateReq_t jtagRdi_lp_state_req,
  output var UcieUPM_interfaces_pkg::PhyState_t jtagRdi_pl_state_sts,
  output var logic jtagRdi_pl_stallreq,
  input wire logic jtagRdi_lp_stallack,
  output var logic jtagRdi_rdi_pl_inband_pres,
  input wire logic jtagRdi_ltsm_pl_inband_pres,
  input wire logic jtagRdi_fdiNeedsRdiAwake,
  output var logic jtagRdi_rdiAwake,
  output var logic jtagRdi_rdiNeedsFdiAwake,
  input wire logic jtagRdi_fdiAwake,
  output var logic jtagRdi_sb_snd_valid,
  output var logic [127:0] jtagRdi_sb_snd_msg,
  input wire logic jtagRdi_sb_snd_ready,
  input wire logic jtagRdi_sb_rcv_valid,
  input wire logic [127:0] jtagRdi_sb_rcv_msg,
  output var logic jtagRdi_sb_rcv_ready,
  input wire logic jtagRdi_lp_linkerror,
  output var logic jtagRdi_pl_phyinrecenter,
  input wire logic jtagRdi_timeout_disable,
  input wire logic [31:0] jtagRdi_cycles_1us,

  // ==========================================================================
  // LTSM ISOLATION TEST
  // ==========================================================================
  input wire logic testModeLtsm,

  // LTSM ISOLATION TEST (testModeLtsm = 1): one jtagLtsm_<port> pin per
  // LinkTrainingFSM port (except clock), same type and direction.
  // Inputs are ignored and outputs held at 0 while testModeLtsm = 0.
  input wire logic jtagLtsm_reset_n,
  output var logic [127:0] jtagLtsm_sb_tx_din,
  output var logic jtagLtsm_sb_tx_valid,
  input wire logic jtagLtsm_sb_tx_ready,
  input wire logic [127:0] jtagLtsm_sb_rx_dout,
  input wire logic jtagLtsm_sb_rx_valid,
  input wire logic jtagLtsm_start,
  input wire logic jtagLtsm_stable_clk,
  input wire logic jtagLtsm_pll_locked,
  input wire logic jtagLtsm_stable_supply,
  input wire logic jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic jtagLtsm_flagFromAnalog_FinishedClkPatterns,
  input wire logic jtagLtsm_flagFromAnalog_FinishedValTrainPattern,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
  input wire logic jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic jtagLtsm_flagFromAnalog_ValTrainPatternReceived,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
  input wire logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
  input wire logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
  output var logic jtagLtsm_flagToAnalog_RepairClkState,
  output var logic jtagLtsm_flagToAnalog_SendClkPatterns,
  output var logic jtagLtsm_flagToAnalog_RepairValState,
  output var logic jtagLtsm_flagToAnalog_SendValTrainPattern,
  output var logic jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic jtagLtsm_flagToAnalog_RepairMbSetReceiver,
  output var logic jtagLtsm_flagToAnalog_LaneReversalApplied,
  output var logic jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler,
  output var logic [3:0] jtagLtsm_state,
  output var logic jtagLtsm_dbg_flagSbinitFirstClkPatternSeen,
  output var logic jtagLtsm_dbg_rxValidRisingEdge,
  output var logic [2:0] jtagLtsm_dbg_sbinitSendCount,
  output var logic jtagLtsm_dbg_sbTxValid,
  output var logic [127:0] jtagLtsm_dbg_sbTxDin,
  output var logic jtagLtsm_dbg_flagTrainError,
  output var logic [2:0] jtagLtsm_dbg_mbinitSubstate,
  output var logic [1:0] jtagLtsm_dbg_mbinitParamSenderState,
  output var logic [1:0] jtagLtsm_dbg_mbinitParamReceiverState,
  output var logic [1:0] jtagLtsm_dbg_mbinitCalSenderState,
  output var logic [1:0] jtagLtsm_dbg_mbinitCalReceiverState,
  output var logic [2:0] jtagLtsm_dbg_mbinitRepairClkSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbinitRepairClkReceiverState,
  output var logic [2:0] jtagLtsm_dbg_mbinitRepairValSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbinitRepairValReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbinitReversalMbSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbinitReversalMbReceiverState,
  output var logic [4:0] jtagLtsm_dbg_mbinitRepairMbSenderState,
  output var logic [3:0] jtagLtsm_dbg_mbinitRepairMbReceiverState,
  output var logic [4:0] jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount,
  output var logic jtagLtsm_flagToAnalog_valVref_sendPattern,
  input wire logic jtagLtsm_flagFromAnalog_valVref_detectedValPattern,
  input wire logic jtagLtsm_flagFromAnalog_valVref_finishedPattern,
  output var logic jtagLtsm_flagToAnalog_valVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] jtagLtsm_flagToAnalog_valVref_rxVrefCode,
  input wire logic jtagLtsm_flagFromAnalog_valVref_rxVrefApplied,
  output var logic jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
  output var logic [15:0] jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
  output var logic jtagLtsm_flagToAnalog_valVref_comparisonMode,
  output var logic [15:0] jtagLtsm_flagToAnalog_valVref_iterationCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_valVref_idleCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_valVref_burstCountSettings,
  output var logic jtagLtsm_flagToAnalog_valVref_patternMode,
  output var logic [3:0] jtagLtsm_flagToAnalog_valVref_clockPhaseControl,
  output var logic [2:0] jtagLtsm_flagToAnalog_valVref_validPattern,
  output var logic [2:0] jtagLtsm_flagToAnalog_valVref_dataPattern,
  output var logic jtagLtsm_flagToAnalog_valVref_clearComparisonErrors,
  output var logic jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler,
  output var logic jtagLtsm_flagToAnalog_dataVref_sendPattern,
  input wire logic [dataLaneCount-1:0] jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern,
  input wire logic jtagLtsm_flagFromAnalog_dataVref_finishedPattern,
  output var logic jtagLtsm_flagToAnalog_dataVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] jtagLtsm_flagToAnalog_dataVref_rxVrefCodes,
  input wire logic jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied,
  output var logic jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
  output var logic [15:0] jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
  output var logic jtagLtsm_flagToAnalog_dataVref_comparisonMode,
  output var logic [15:0] jtagLtsm_flagToAnalog_dataVref_iterationCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_dataVref_idleCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_dataVref_burstCountSettings,
  output var logic jtagLtsm_flagToAnalog_dataVref_patternMode,
  output var logic [3:0] jtagLtsm_flagToAnalog_dataVref_clockPhaseControl,
  output var logic [2:0] jtagLtsm_flagToAnalog_dataVref_validPattern,
  output var logic [2:0] jtagLtsm_flagToAnalog_dataVref_dataPattern,
  output var logic jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors,
  output var logic jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler,
  output var logic jtagLtsm_flagToAnalog_rxClkCal_doCalibration,
  input wire logic jtagLtsm_flagFromAnalog_rxClkCal_done,
  output var logic jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack,
  output var logic jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic jtagLtsm_flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0] jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0] jtagLtsm_flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0] jtagLtsm_flagToAnalog_d2cReceiver_dataPattern,
  output var logic jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0] jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0] jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern,
  input wire logic jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
  output var logic [dataLaneCount*rxDeskewCodeWidth-1:0] jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
  input wire logic jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
  output var logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_comparisonMode,
  output var logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings,
  output var logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_patternMode,
  output var logic [3:0] jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl,
  output var logic [2:0] jtagLtsm_flagToAnalog_rxDeskew_validPattern,
  output var logic [2:0] jtagLtsm_flagToAnalog_rxDeskew_dataPattern,
  output var logic jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors,
  input wire logic [dataLaneCount-1:0] jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern,
  output var logic jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain,
  input wire logic [15:0] jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  output var logic [3:0] jtagLtsm_dbg_mbtrainState,
  output var logic [11:0] jtagLtsm_dbg_mbtrainActiveSubstate,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValVrefLocalState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainValVrefRemoteState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValVrefSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValVrefPointInitiatorState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValVrefPointResponderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataVrefLocalState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainDataVrefRemoteState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataVrefSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataVrefPointResponderState,
  output var logic [1:0] jtagLtsm_dbg_mbtrainSpeedIdleSenderState,
  output var logic [1:0] jtagLtsm_dbg_mbtrainSpeedIdleReceiverState,
  output var logic [1:0] jtagLtsm_dbg_mbtrainTxSelfCalSenderState,
  output var logic [1:0] jtagLtsm_dbg_mbtrainTxSelfCalReceiverState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainRxClkCalSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainRxClkCalReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainValTrainCenterReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefLocalState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainValTrainVrefRemoteState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState,
  output var logic [4:0] jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefLocalState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewLocalState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainRxDeskewRemoteState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewSweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewPointResponderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedSenderState,
  output var logic [2:0] jtagLtsm_dbg_mbtrainLinkSpeedReceiverState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState,
  output var logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState,
  output var logic [15:0] jtagLtsm_dbg_mbtrainLastErrorCount,
  output var logic [15:0] jtagLtsm_dbg_mbtrainRetryCount
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

  // Reset for every block that is not under isolation test: held asserted
  // while any of testModeFdi / testModeRdi / testModeLtsm is set.
  logic restCore_reset_n;

  // fdi instance port nets (after the testModeFdi mux).
  logic         fdiCore_reset_n;
  logic [31:0]  fdiCore_cycles_1us;
  logic         fdiCore_timeout_disable;
  PhyStateReq_t fdiCore_fdi_lp_state_req;
  logic         fdiCore_fdi_lp_linkerror;
  logic         fdiCore_fdi_lp_rx_active_sts;
  logic         fdiCore_fdi_lp_wake_req;
  logic         fdiCore_fdi_lp_clk_ack;
  logic         fdiCore_fdi_lp_stall_ack;
  PhyState_t    fdiCore_fdi_pl_state_sts;
  logic         fdiCore_fdi_pl_rx_active_req;
  logic         fdiCore_fdi_pl_inband_pres;
  logic         fdiCore_fdi_pl_wake_ack;
  logic         fdiCore_fdi_pl_clk_req;
  logic         fdiCore_fdi_pl_stall_req;
  logic         fdiCore_fdi_active;
  LinkInitState_t fdiCore_debug_link_init_state;
  logic         fdiCore_rdi_lp_linkerror;
  PhyStateReq_t fdiCore_rdi_lp_state_req;
  PhyState_t    fdiCore_rdi_pl_state_sts;
  logic         fdiCore_rdi_pl_inband_pres;
  logic         fdiCore_fdiNeedsRdiAwake;
  logic         fdiCore_rdiAwake;
  logic         fdiCore_rdiNeedsFdiAwake;
  logic         fdiCore_fdiAwake;
  logic         fdiCore_rdi_pl_stall_req;
  logic         fdiCore_rdi_lp_stall_ack;
  logic         fdiCore_sb_snd_valid;
  logic [127:0] fdiCore_sb_snd_msg;
  logic         fdiCore_sb_snd_ready;
  logic         fdiCore_sb_rcv_valid;
  logic [127:0] fdiCore_sb_rcv_msg;
  logic         fdiCore_sb_rcv_ready;

  // --------------------------------------------------------------------------
  // FDI isolation test muxes
  // --------------------------------------------------------------------------
  assign restCore_reset_n = reset_n & ~(testModeFdi | testModeRdi | testModeLtsm);

  // Inputs to fdi: normal source or TDR pin.
  assign fdiCore_reset_n              = testModeFdi ? jtagFdi_reset_n              : restCore_reset_n;
  assign fdiCore_cycles_1us           = testModeFdi ? jtagFdi_cycles_1us           : cycles_1us;
  assign fdiCore_timeout_disable      = testModeFdi ? jtagFdi_timeout_disable      : timeout_disable;
  assign fdiCore_fdi_lp_state_req     = testModeFdi ? jtagFdi_fdi_lp_state_req     : fdi_lp_state_req;
  assign fdiCore_fdi_lp_linkerror     = testModeFdi ? jtagFdi_fdi_lp_linkerror     : fdi_lp_linkerror;
  assign fdiCore_fdi_lp_rx_active_sts = testModeFdi ? jtagFdi_fdi_lp_rx_active_sts : fdi_lp_rx_active_sts;
  assign fdiCore_fdi_lp_wake_req      = testModeFdi ? jtagFdi_fdi_lp_wake_req      : fdi_lp_wake_req;
  assign fdiCore_fdi_lp_clk_ack       = testModeFdi ? jtagFdi_fdi_lp_clk_ack       : fdi_lp_clk_ack;
  assign fdiCore_fdi_lp_stall_ack     = testModeFdi ? jtagFdi_fdi_lp_stall_ack     : fdi_lp_stall_ack;
  assign fdiCore_rdi_pl_state_sts     = testModeFdi ? jtagFdi_rdi_pl_state_sts     : rdi_pl_state_sts_int;
  assign fdiCore_rdi_pl_inband_pres   = testModeFdi ? jtagFdi_rdi_pl_inband_pres   : rdi_pl_inband_pres_int;
  assign fdiCore_rdiAwake             = testModeFdi ? jtagFdi_rdiAwake             : rdiAwake_int;
  assign fdiCore_rdiNeedsFdiAwake     = testModeFdi ? jtagFdi_rdiNeedsFdiAwake     : rdiNeedsFdiAwake_int;
  assign fdiCore_rdi_pl_stall_req     = testModeFdi ? jtagFdi_rdi_pl_stall_req     : rdi_pl_stall_req_int;
  assign fdiCore_sb_snd_ready         = testModeFdi ? jtagFdi_sb_snd_ready         : fdi_sb_snd_ready;
  assign fdiCore_sb_rcv_valid         = testModeFdi ? jtagFdi_sb_rcv_valid         : fdi_sb_rcv_valid;
  assign fdiCore_sb_rcv_msg           = testModeFdi ? jtagFdi_sb_rcv_msg           : fdi_sb_rcv_msg;

  // Outputs of fdi toward core ports: core port or TDR pin (other side is 0).
  assign fdi_pl_state_sts              = testModeFdi ? PhyState_t'('0) : fdiCore_fdi_pl_state_sts;
  assign jtagFdi_fdi_pl_state_sts      = testModeFdi ? fdiCore_fdi_pl_state_sts : PhyState_t'('0);
  assign fdi_pl_rx_active_req          = testModeFdi ? 1'b0 : fdiCore_fdi_pl_rx_active_req;
  assign jtagFdi_fdi_pl_rx_active_req  = testModeFdi ? fdiCore_fdi_pl_rx_active_req : 1'b0;
  assign fdi_pl_inband_pres            = testModeFdi ? 1'b0 : fdiCore_fdi_pl_inband_pres;
  assign jtagFdi_fdi_pl_inband_pres    = testModeFdi ? fdiCore_fdi_pl_inband_pres : 1'b0;
  assign fdi_pl_wake_ack               = testModeFdi ? 1'b0 : fdiCore_fdi_pl_wake_ack;
  assign jtagFdi_fdi_pl_wake_ack       = testModeFdi ? fdiCore_fdi_pl_wake_ack : 1'b0;
  assign fdi_pl_clk_req                = testModeFdi ? 1'b0 : fdiCore_fdi_pl_clk_req;
  assign jtagFdi_fdi_pl_clk_req        = testModeFdi ? fdiCore_fdi_pl_clk_req : 1'b0;
  assign fdi_pl_stall_req              = testModeFdi ? 1'b0 : fdiCore_fdi_pl_stall_req;
  assign jtagFdi_fdi_pl_stall_req      = testModeFdi ? fdiCore_fdi_pl_stall_req : 1'b0;
  assign fdi_active                    = testModeFdi ? 1'b0 : fdiCore_fdi_active;
  assign jtagFdi_fdi_active            = testModeFdi ? fdiCore_fdi_active : 1'b0;
  assign debug_fdi_link_init_state     = testModeFdi ? LinkInitState_t'('0) : fdiCore_debug_link_init_state;
  assign jtagFdi_debug_link_init_state = testModeFdi ? fdiCore_debug_link_init_state : LinkInitState_t'('0);

  // Outputs of fdi toward rdi / u_sideband: neighbour or TDR pin. In test
  // mode the neighbour sees an idle FDI (NOP request, no packet, no ack).
  assign fdi_rdi_lp_linkerror      = testModeFdi ? 1'b0 : fdiCore_rdi_lp_linkerror;
  assign jtagFdi_rdi_lp_linkerror  = testModeFdi ? fdiCore_rdi_lp_linkerror : 1'b0;
  assign fdi_rdi_lp_state_req      = testModeFdi ? PhyStateReq_nop : fdiCore_rdi_lp_state_req;
  assign jtagFdi_rdi_lp_state_req  = testModeFdi ? fdiCore_rdi_lp_state_req : PhyStateReq_nop;
  assign fdiNeedsRdiAwake_int      = testModeFdi ? 1'b0 : fdiCore_fdiNeedsRdiAwake;
  assign jtagFdi_fdiNeedsRdiAwake  = testModeFdi ? fdiCore_fdiNeedsRdiAwake : 1'b0;
  assign fdiAwake_int              = testModeFdi ? 1'b0 : fdiCore_fdiAwake;
  assign jtagFdi_fdiAwake          = testModeFdi ? fdiCore_fdiAwake : 1'b0;
  assign fdi_rdi_lp_stall_ack      = testModeFdi ? 1'b0 : fdiCore_rdi_lp_stall_ack;
  assign jtagFdi_rdi_lp_stall_ack  = testModeFdi ? fdiCore_rdi_lp_stall_ack : 1'b0;
  assign fdi_sb_snd_valid          = testModeFdi ? 1'b0 : fdiCore_sb_snd_valid;
  assign jtagFdi_sb_snd_valid      = testModeFdi ? fdiCore_sb_snd_valid : 1'b0;
  assign fdi_sb_snd_msg            = testModeFdi ? 128'd0 : fdiCore_sb_snd_msg;
  assign jtagFdi_sb_snd_msg        = testModeFdi ? fdiCore_sb_snd_msg : 128'd0;
  assign fdi_sb_rcv_ready          = testModeFdi ? 1'b0 : fdiCore_sb_rcv_ready;
  assign jtagFdi_sb_rcv_ready      = testModeFdi ? fdiCore_sb_rcv_ready : 1'b0;

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
    .reset_n              (fdiCore_reset_n),

    .fdi_lp_state_req     (fdiCore_fdi_lp_state_req),
    .fdi_lp_linkerror     (fdiCore_fdi_lp_linkerror),
    .fdi_lp_rx_active_sts (fdiCore_fdi_lp_rx_active_sts),
    .fdi_pl_state_sts     (fdiCore_fdi_pl_state_sts),
    .fdi_pl_rx_active_req (fdiCore_fdi_pl_rx_active_req),
    .fdi_pl_inband_pres   (fdiCore_fdi_pl_inband_pres),
    .fdi_pl_wake_ack      (fdiCore_fdi_pl_wake_ack),
    .fdi_lp_wake_req      (fdiCore_fdi_lp_wake_req),
    .fdi_pl_clk_req       (fdiCore_fdi_pl_clk_req),
    .fdi_lp_clk_ack       (fdiCore_fdi_lp_clk_ack),
    .fdi_pl_stall_req     (fdiCore_fdi_pl_stall_req),
    .fdi_lp_stall_ack     (fdiCore_fdi_lp_stall_ack),
    .fdi_active           (fdiCore_fdi_active),

    .debug_link_init_state(fdiCore_debug_link_init_state),

    .rdi_lp_linkerror     (fdiCore_rdi_lp_linkerror),
    .rdi_lp_state_req     (fdiCore_rdi_lp_state_req),
    .rdi_pl_state_sts     (fdiCore_rdi_pl_state_sts),
    .rdi_pl_inband_pres   (fdiCore_rdi_pl_inband_pres),

    .fdiNeedsRdiAwake     (fdiCore_fdiNeedsRdiAwake),
    .rdiAwake             (fdiCore_rdiAwake),
    .rdiNeedsFdiAwake     (fdiCore_rdiNeedsFdiAwake),
    .fdiAwake             (fdiCore_fdiAwake),

    .rdi_pl_stall_req     (fdiCore_rdi_pl_stall_req),
    .rdi_lp_stall_ack     (fdiCore_rdi_lp_stall_ack),

    .sb_snd_valid         (fdiCore_sb_snd_valid),
    .sb_snd_msg           (fdiCore_sb_snd_msg),
    .sb_snd_ready         (fdiCore_sb_snd_ready),
    .sb_rcv_valid         (fdiCore_sb_rcv_valid),
    .sb_rcv_msg           (fdiCore_sb_rcv_msg),
    .sb_rcv_ready         (fdiCore_sb_rcv_ready),
    .timeout_disable      (fdiCore_timeout_disable),
    .cycles_1us           (fdiCore_cycles_1us)
  );

  // --------------------------------------------------------------------------
  // RDI isolation test muxes
  // --------------------------------------------------------------------------
  // rdi instance port nets (after the testModeRdi mux).
  logic rdiCore_reset_n;
  logic rdiCore_ltsm_lp_wake_req;
  logic rdiCore_ltsm_pl_wake_ack;
  logic rdiCore_ltsm_pl_clk_req;
  logic rdiCore_ltsm_lp_clk_ack;
  UcieUPM_interfaces_pkg::PhyStateReq_t rdiCore_lp_state_req;
  UcieUPM_interfaces_pkg::PhyState_t rdiCore_pl_state_sts;
  logic rdiCore_pl_stallreq;
  logic rdiCore_lp_stallack;
  logic rdiCore_rdi_pl_inband_pres;
  logic rdiCore_ltsm_pl_inband_pres;
  logic rdiCore_fdiNeedsRdiAwake;
  logic rdiCore_rdiAwake;
  logic rdiCore_rdiNeedsFdiAwake;
  logic rdiCore_fdiAwake;
  logic rdiCore_sb_snd_valid;
  logic [127:0] rdiCore_sb_snd_msg;
  logic rdiCore_sb_snd_ready;
  logic rdiCore_sb_rcv_valid;
  logic [127:0] rdiCore_sb_rcv_msg;
  logic rdiCore_sb_rcv_ready;
  logic rdiCore_lp_linkerror;
  logic rdiCore_pl_phyinrecenter;
  logic rdiCore_timeout_disable;
  logic [31:0] rdiCore_cycles_1us;

  // Inputs to rdi: normal source or TDR pin.
  assign rdiCore_reset_n = testModeRdi ? jtagRdi_reset_n : restCore_reset_n;
  assign rdiCore_ltsm_lp_wake_req = testModeRdi ? jtagRdi_ltsm_lp_wake_req : 1'b0;
  assign rdiCore_ltsm_lp_clk_ack = testModeRdi ? jtagRdi_ltsm_lp_clk_ack : 1'b1;
  assign rdiCore_lp_state_req = testModeRdi ? jtagRdi_lp_state_req : fdi_rdi_lp_state_req;
  assign rdiCore_lp_stallack = testModeRdi ? jtagRdi_lp_stallack : fdi_rdi_lp_stall_ack;
  assign rdiCore_ltsm_pl_inband_pres = testModeRdi ? jtagRdi_ltsm_pl_inband_pres : ltsmInbandPresent;
  assign rdiCore_fdiNeedsRdiAwake = testModeRdi ? jtagRdi_fdiNeedsRdiAwake : fdiNeedsRdiAwake_int;
  assign rdiCore_fdiAwake = testModeRdi ? jtagRdi_fdiAwake : fdiAwake_int;
  assign rdiCore_sb_snd_ready = testModeRdi ? jtagRdi_sb_snd_ready : rdi_sb_snd_ready;
  assign rdiCore_sb_rcv_valid = testModeRdi ? jtagRdi_sb_rcv_valid : rdi_sb_rcv_valid;
  assign rdiCore_sb_rcv_msg = testModeRdi ? jtagRdi_sb_rcv_msg : rdi_sb_rcv_msg;
  assign rdiCore_lp_linkerror = testModeRdi ? jtagRdi_lp_linkerror : fdi_rdi_lp_linkerror;
  assign rdiCore_timeout_disable = testModeRdi ? jtagRdi_timeout_disable : timeout_disable;
  assign rdiCore_cycles_1us = testModeRdi ? jtagRdi_cycles_1us : cycles_1us;

  // Outputs of rdi: normal sink or TDR pin (the other side is 0, so the
  // rest of the core sees an idle block in test mode).
  assign jtagRdi_ltsm_pl_wake_ack = testModeRdi ? rdiCore_ltsm_pl_wake_ack : '0;
  assign jtagRdi_ltsm_pl_clk_req = testModeRdi ? rdiCore_ltsm_pl_clk_req : '0;
  assign jtagRdi_pl_state_sts = testModeRdi ? rdiCore_pl_state_sts : UcieUPM_interfaces_pkg::PhyState_t'('0);
  assign rdi_pl_state_sts_int = testModeRdi ? UcieUPM_interfaces_pkg::PhyState_t'('0) : rdiCore_pl_state_sts;
  assign jtagRdi_pl_stallreq = testModeRdi ? rdiCore_pl_stallreq : '0;
  assign rdi_pl_stall_req_int = testModeRdi ? '0 : rdiCore_pl_stallreq;
  assign jtagRdi_rdi_pl_inband_pres = testModeRdi ? rdiCore_rdi_pl_inband_pres : '0;
  assign rdi_pl_inband_pres_int = testModeRdi ? '0 : rdiCore_rdi_pl_inband_pres;
  assign jtagRdi_rdiAwake = testModeRdi ? rdiCore_rdiAwake : '0;
  assign rdiAwake_int = testModeRdi ? '0 : rdiCore_rdiAwake;
  assign jtagRdi_rdiNeedsFdiAwake = testModeRdi ? rdiCore_rdiNeedsFdiAwake : '0;
  assign rdiNeedsFdiAwake_int = testModeRdi ? '0 : rdiCore_rdiNeedsFdiAwake;
  assign jtagRdi_sb_snd_valid = testModeRdi ? rdiCore_sb_snd_valid : '0;
  assign rdi_sb_snd_valid = testModeRdi ? '0 : rdiCore_sb_snd_valid;
  assign jtagRdi_sb_snd_msg = testModeRdi ? rdiCore_sb_snd_msg : '0;
  assign rdi_sb_snd_msg = testModeRdi ? '0 : rdiCore_sb_snd_msg;
  assign jtagRdi_sb_rcv_ready = testModeRdi ? rdiCore_sb_rcv_ready : '0;
  assign rdi_sb_rcv_ready = testModeRdi ? '0 : rdiCore_sb_rcv_ready;
  assign jtagRdi_pl_phyinrecenter = testModeRdi ? rdiCore_pl_phyinrecenter : '0;

  // --------------------------------------------------------------------------
  // RDI link management
  // The LTSM has no wake/clock handshake pins, so the RDI-side handshake is
  // kept awake (wake_req = 0, clk_ack = 1), matching the Chisel tie-offs.
  // --------------------------------------------------------------------------
  RdiLinkManagementController rdi (
    .clock                (clock),
    .reset_n              (rdiCore_reset_n),

    .ltsm_lp_wake_req     (rdiCore_ltsm_lp_wake_req),
    .ltsm_pl_wake_ack     (rdiCore_ltsm_pl_wake_ack),
    .ltsm_pl_clk_req      (rdiCore_ltsm_pl_clk_req),
    .ltsm_lp_clk_ack      (rdiCore_ltsm_lp_clk_ack),

    .lp_state_req         (rdiCore_lp_state_req),
    .pl_state_sts         (rdiCore_pl_state_sts),
    .pl_stallreq          (rdiCore_pl_stallreq),
    .lp_stallack          (rdiCore_lp_stallack),
    .rdi_pl_inband_pres   (rdiCore_rdi_pl_inband_pres),
    .ltsm_pl_inband_pres  (rdiCore_ltsm_pl_inband_pres),

    .fdiNeedsRdiAwake     (rdiCore_fdiNeedsRdiAwake),
    .rdiAwake             (rdiCore_rdiAwake),
    .rdiNeedsFdiAwake     (rdiCore_rdiNeedsFdiAwake),
    .fdiAwake             (rdiCore_fdiAwake),

    .sb_snd_valid         (rdiCore_sb_snd_valid),
    .sb_snd_msg           (rdiCore_sb_snd_msg),
    .sb_snd_ready         (rdiCore_sb_snd_ready),
    .sb_rcv_valid         (rdiCore_sb_rcv_valid),
    .sb_rcv_msg           (rdiCore_sb_rcv_msg),
    .sb_rcv_ready         (rdiCore_sb_rcv_ready),

    .lp_linkerror         (rdiCore_lp_linkerror),
    .pl_phyinrecenter     (rdiCore_pl_phyinrecenter),
    .timeout_disable      (rdiCore_timeout_disable),
    .cycles_1us           (rdiCore_cycles_1us)
  );

  // --------------------------------------------------------------------------
  // Sideband path (ltsm / fdi / rdi <-> serial sideband pins)
  // --------------------------------------------------------------------------
  SidebandWrapper #(
    .SB_TX_FIFO_ENTRIES      (SB_TX_FIFO_ENTRIES),
    .LTSM_TX_CAPTURE_ENTRIES (4)
  ) u_sideband (
    .clock                         (clock),
    .reset_n                       (restCore_reset_n),

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
  // LTSM isolation test muxes
  // --------------------------------------------------------------------------
  // ltsm instance port nets (after the testModeLtsm mux).
  logic ltsmCore_reset_n;
  logic [127:0] ltsmCore_sb_tx_din;
  logic ltsmCore_sb_tx_valid;
  logic ltsmCore_sb_tx_ready;
  logic [127:0] ltsmCore_sb_rx_dout;
  logic ltsmCore_sb_rx_valid;
  logic ltsmCore_start;
  logic ltsmCore_stable_clk;
  logic ltsmCore_pll_locked;
  logic ltsmCore_stable_supply;
  logic ltsmCore_flagFromAnalog_ReadyToExchangeClkPatterns;
  logic ltsmCore_flagFromAnalog_FinishedClkPatterns;
  logic ltsmCore_flagFromAnalog_FinishedValTrainPattern;
  logic ltsmCore_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  logic ltsmCore_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  logic ltsmCore_flagFromAnalog_clkPatternReceivedRTRK_L;
  logic ltsmCore_flagFromAnalog_clkPatternReceivedRCKN_L;
  logic ltsmCore_flagFromAnalog_clkPatternReceivedRCKP_L;
  logic ltsmCore_flagFromAnalog_ValTrainPatternReceived;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived0;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived1;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived2;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived3;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived4;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived5;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived6;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived7;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived8;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived9;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived10;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived11;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived12;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived13;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived14;
  logic ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived15;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  logic ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  logic ltsmCore_flagToAnalog_RepairClkState;
  logic ltsmCore_flagToAnalog_SendClkPatterns;
  logic ltsmCore_flagToAnalog_RepairValState;
  logic ltsmCore_flagToAnalog_SendValTrainPattern;
  logic ltsmCore_flagToAnalog_ReversalMbSendLaneIDPattern;
  logic ltsmCore_flagToAnalog_RepairMbSendLaneIDPattern;
  logic ltsmCore_flagToAnalog_RepairMbSetReceiver;
  logic ltsmCore_flagToAnalog_LaneReversalApplied;
  logic ltsmCore_flagToAnalog_linkInit_resetLfsrScrambler;
  logic [3:0] ltsmCore_state;
  logic ltsmCore_dbg_flagSbinitFirstClkPatternSeen;
  logic ltsmCore_dbg_rxValidRisingEdge;
  logic [2:0] ltsmCore_dbg_sbinitSendCount;
  logic ltsmCore_dbg_sbTxValid;
  logic [127:0] ltsmCore_dbg_sbTxDin;
  logic ltsmCore_dbg_flagTrainError;
  logic [2:0] ltsmCore_dbg_mbinitSubstate;
  logic [1:0] ltsmCore_dbg_mbinitParamSenderState;
  logic [1:0] ltsmCore_dbg_mbinitParamReceiverState;
  logic [1:0] ltsmCore_dbg_mbinitCalSenderState;
  logic [1:0] ltsmCore_dbg_mbinitCalReceiverState;
  logic [2:0] ltsmCore_dbg_mbinitRepairClkSenderState;
  logic [2:0] ltsmCore_dbg_mbinitRepairClkReceiverState;
  logic [2:0] ltsmCore_dbg_mbinitRepairValSenderState;
  logic [2:0] ltsmCore_dbg_mbinitRepairValReceiverState;
  logic [3:0] ltsmCore_dbg_mbinitReversalMbSenderState;
  logic [2:0] ltsmCore_dbg_mbinitReversalMbReceiverState;
  logic [4:0] ltsmCore_dbg_mbinitRepairMbSenderState;
  logic [3:0] ltsmCore_dbg_mbinitRepairMbReceiverState;
  logic [4:0] ltsmCore_dbg_mbinitReversalMbReceivedSuccessCount;
  logic ltsmCore_flagToAnalog_valVref_sendPattern;
  logic ltsmCore_flagFromAnalog_valVref_detectedValPattern;
  logic ltsmCore_flagFromAnalog_valVref_finishedPattern;
  logic ltsmCore_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] ltsmCore_flagToAnalog_valVref_rxVrefCode;
  logic ltsmCore_flagFromAnalog_valVref_rxVrefApplied;
  logic ltsmCore_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] ltsmCore_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic ltsmCore_flagToAnalog_valVref_comparisonMode;
  logic [15:0] ltsmCore_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_valVref_burstCountSettings;
  logic ltsmCore_flagToAnalog_valVref_patternMode;
  logic [3:0] ltsmCore_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] ltsmCore_flagToAnalog_valVref_validPattern;
  logic [2:0] ltsmCore_flagToAnalog_valVref_dataPattern;
  logic ltsmCore_flagToAnalog_valVref_clearComparisonErrors;
  logic ltsmCore_flagToAnalog_valVref_resetLocalTxScrambler;
  logic ltsmCore_flagToAnalog_dataVref_sendPattern;
  logic [dataLaneCount-1:0] ltsmCore_flagFromAnalog_dataVref_detectedDataPattern;
  logic ltsmCore_flagFromAnalog_dataVref_finishedPattern;
  logic ltsmCore_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] ltsmCore_flagToAnalog_dataVref_rxVrefCodes;
  logic ltsmCore_flagFromAnalog_dataVref_rxVrefApplied;
  logic ltsmCore_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] ltsmCore_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic ltsmCore_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] ltsmCore_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_dataVref_burstCountSettings;
  logic ltsmCore_flagToAnalog_dataVref_patternMode;
  logic [3:0] ltsmCore_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] ltsmCore_flagToAnalog_dataVref_validPattern;
  logic [2:0] ltsmCore_flagToAnalog_dataVref_dataPattern;
  logic ltsmCore_flagToAnalog_dataVref_clearComparisonErrors;
  logic ltsmCore_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic ltsmCore_flagToAnalog_rxClkCal_doCalibration;
  logic ltsmCore_flagFromAnalog_rxClkCal_done;
  logic ltsmCore_flagToAnalog_rxClkCal_sendClockTrack;
  logic ltsmCore_flagToAnalog_d2cSender_sendValTrainPattern;
  logic ltsmCore_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic ltsmCore_flagToAnalog_d2cSender_resetLocalScrambler;
  logic ltsmCore_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] ltsmCore_flagToAnalog_d2cSender_txClockPhaseCode;
  logic ltsmCore_flagFromAnalog_d2cSender_txClockPhaseApplied;
  logic ltsmCore_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  logic [15:0] ltsmCore_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  logic ltsmCore_flagToAnalog_d2cReceiver_comparisonMode;
  logic [15:0] ltsmCore_flagToAnalog_d2cReceiver_iterationCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_d2cReceiver_idleCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_d2cReceiver_burstCountSettings;
  logic ltsmCore_flagToAnalog_d2cReceiver_patternMode;
  logic [3:0] ltsmCore_flagToAnalog_d2cReceiver_clockPhaseControl;
  logic [2:0] ltsmCore_flagToAnalog_d2cReceiver_validPattern;
  logic [2:0] ltsmCore_flagToAnalog_d2cReceiver_dataPattern;
  logic ltsmCore_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic [15:0] ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic ltsmCore_flagToAnalog_d2cSender_sendLfsrPattern;
  logic ltsmCore_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic ltsmCore_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] ltsmCore_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic ltsmCore_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic ltsmCore_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic ltsmCore_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic ltsmCore_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic ltsmCore_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] ltsmCore_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic ltsmCore_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  logic ltsmCore_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  logic [15:0] ltsmCore_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  logic ltsmCore_flagToAnalog_rxDeskew_comparisonMode;
  logic [15:0] ltsmCore_flagToAnalog_rxDeskew_iterationCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_rxDeskew_idleCountSettings;
  logic [15:0] ltsmCore_flagToAnalog_rxDeskew_burstCountSettings;
  logic ltsmCore_flagToAnalog_rxDeskew_patternMode;
  logic [3:0] ltsmCore_flagToAnalog_rxDeskew_clockPhaseControl;
  logic [2:0] ltsmCore_flagToAnalog_rxDeskew_validPattern;
  logic [2:0] ltsmCore_flagToAnalog_rxDeskew_dataPattern;
  logic ltsmCore_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic [dataLaneCount-1:0] ltsmCore_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic ltsmCore_flagToLtsm_linkSpeed_phyInRetrain;
  logic [15:0] ltsmCore_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic [3:0] ltsmCore_dbg_mbtrainState;
  logic [11:0] ltsmCore_dbg_mbtrainActiveSubstate;
  logic [3:0] ltsmCore_dbg_mbtrainValVrefLocalState;
  logic [2:0] ltsmCore_dbg_mbtrainValVrefRemoteState;
  logic [3:0] ltsmCore_dbg_mbtrainValVrefSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainValVrefPointInitiatorState;
  logic [3:0] ltsmCore_dbg_mbtrainValVrefPointResponderState;
  logic [3:0] ltsmCore_dbg_mbtrainDataVrefLocalState;
  logic [2:0] ltsmCore_dbg_mbtrainDataVrefRemoteState;
  logic [3:0] ltsmCore_dbg_mbtrainDataVrefSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainDataVrefPointInitiatorState;
  logic [3:0] ltsmCore_dbg_mbtrainDataVrefPointResponderState;
  logic [1:0] ltsmCore_dbg_mbtrainSpeedIdleSenderState;
  logic [1:0] ltsmCore_dbg_mbtrainSpeedIdleReceiverState;
  logic [1:0] ltsmCore_dbg_mbtrainTxSelfCalSenderState;
  logic [1:0] ltsmCore_dbg_mbtrainTxSelfCalReceiverState;
  logic [2:0] ltsmCore_dbg_mbtrainRxClkCalSenderState;
  logic [2:0] ltsmCore_dbg_mbtrainRxClkCalReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainCenterSenderState;
  logic [2:0] ltsmCore_dbg_mbtrainValTrainCenterReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainCenterD2cSenderState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainCenterD2cReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainCenterSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainVrefLocalState;
  logic [2:0] ltsmCore_dbg_mbtrainValTrainVrefRemoteState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainVrefSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainVrefPointInitiatorState;
  logic [3:0] ltsmCore_dbg_mbtrainValTrainVrefPointResponderState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter1SenderState;
  logic [2:0] ltsmCore_dbg_mbtrainDataTrainCenter1ReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter1D2cSenderState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter1D2cReceiverState;
  logic [4:0] ltsmCore_dbg_mbtrainDataTrainCenter1SweepState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainVrefLocalState;
  logic [2:0] ltsmCore_dbg_mbtrainDataTrainVrefRemoteState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainVrefSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainVrefPointInitiatorState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainVrefPointResponderState;
  logic [3:0] ltsmCore_dbg_mbtrainRxDeskewLocalState;
  logic [2:0] ltsmCore_dbg_mbtrainRxDeskewRemoteState;
  logic [3:0] ltsmCore_dbg_mbtrainRxDeskewSweepState;
  logic [3:0] ltsmCore_dbg_mbtrainRxDeskewPointInitiatorState;
  logic [3:0] ltsmCore_dbg_mbtrainRxDeskewPointResponderState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter2SenderState;
  logic [2:0] ltsmCore_dbg_mbtrainDataTrainCenter2ReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter2D2cSenderState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter2D2cReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainDataTrainCenter2SweepState;
  logic [3:0] ltsmCore_dbg_mbtrainLinkSpeedSenderState;
  logic [2:0] ltsmCore_dbg_mbtrainLinkSpeedReceiverState;
  logic [3:0] ltsmCore_dbg_mbtrainLinkSpeedD2cSenderState;
  logic [3:0] ltsmCore_dbg_mbtrainLinkSpeedD2cReceiverState;
  logic [15:0] ltsmCore_dbg_mbtrainLastErrorCount;
  logic [15:0] ltsmCore_dbg_mbtrainRetryCount;

  // Inputs to ltsm: normal source or TDR pin.
  assign ltsmCore_reset_n = testModeLtsm ? jtagLtsm_reset_n : restCore_reset_n;
  assign ltsmCore_sb_tx_ready = testModeLtsm ? jtagLtsm_sb_tx_ready : ltsm_raw_tx_ready;
  assign ltsmCore_sb_rx_dout = testModeLtsm ? jtagLtsm_sb_rx_dout : ltsm_pulse_rx_msg;
  assign ltsmCore_sb_rx_valid = testModeLtsm ? jtagLtsm_sb_rx_valid : ltsm_pulse_rx_valid;
  assign ltsmCore_start = testModeLtsm ? jtagLtsm_start : ltsm_start;
  assign ltsmCore_stable_clk = testModeLtsm ? jtagLtsm_stable_clk : ltsm_stable_clk;
  assign ltsmCore_pll_locked = testModeLtsm ? jtagLtsm_pll_locked : ltsm_pll_locked;
  assign ltsmCore_stable_supply = testModeLtsm ? jtagLtsm_stable_supply : ltsm_stable_supply;
  assign ltsmCore_flagFromAnalog_ReadyToExchangeClkPatterns = testModeLtsm ? jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns : ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  assign ltsmCore_flagFromAnalog_FinishedClkPatterns = testModeLtsm ? jtagLtsm_flagFromAnalog_FinishedClkPatterns : ltsm_flagFromAnalog_FinishedClkPatterns;
  assign ltsmCore_flagFromAnalog_FinishedValTrainPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_FinishedValTrainPattern : ltsm_flagFromAnalog_FinishedValTrainPattern;
  assign ltsmCore_flagFromAnalog_ReversalMbFinishedLaneIDPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern : ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  assign ltsmCore_flagFromAnalog_RepairMbFinishedLaneIDPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern : ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  assign ltsmCore_flagFromAnalog_clkPatternReceivedRTRK_L = testModeLtsm ? jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L : ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  assign ltsmCore_flagFromAnalog_clkPatternReceivedRCKN_L = testModeLtsm ? jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L : ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  assign ltsmCore_flagFromAnalog_clkPatternReceivedRCKP_L = testModeLtsm ? jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L : ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  assign ltsmCore_flagFromAnalog_ValTrainPatternReceived = testModeLtsm ? jtagLtsm_flagFromAnalog_ValTrainPatternReceived : ltsm_flagFromAnalog_ValTrainPatternReceived;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived0 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived1 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived2 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived3 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived4 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived5 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived6 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived7 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived8 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived9 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived10 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived11 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived12 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived13 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived14 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  assign ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived15 = testModeLtsm ? jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  assign ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = testModeLtsm ? jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  assign ltsmCore_flagFromAnalog_valVref_detectedValPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_valVref_detectedValPattern : ltsm_flagFromAnalog_valVref_detectedValPattern;
  assign ltsmCore_flagFromAnalog_valVref_finishedPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_valVref_finishedPattern : ltsm_flagFromAnalog_valVref_finishedPattern;
  assign ltsmCore_flagFromAnalog_valVref_rxVrefApplied = testModeLtsm ? jtagLtsm_flagFromAnalog_valVref_rxVrefApplied : ltsm_flagFromAnalog_valVref_rxVrefApplied;
  assign ltsmCore_flagFromAnalog_dataVref_detectedDataPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern : ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  assign ltsmCore_flagFromAnalog_dataVref_finishedPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_dataVref_finishedPattern : ltsm_flagFromAnalog_dataVref_finishedPattern;
  assign ltsmCore_flagFromAnalog_dataVref_rxVrefApplied = testModeLtsm ? jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied : ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  assign ltsmCore_flagFromAnalog_rxClkCal_done = testModeLtsm ? jtagLtsm_flagFromAnalog_rxClkCal_done : ltsm_flagFromAnalog_rxClkCal_done;
  assign ltsmCore_flagFromAnalog_d2cSender_valTrainPatternSent = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent : ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  assign ltsmCore_flagFromAnalog_d2cSender_txClockPhaseApplied = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied : ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  assign ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo : ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  assign ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload : ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  assign ltsmCore_flagFromAnalog_d2cSender_lfsrPatternSent = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent : ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  assign ltsmCore_flagFromAnalog_d2cSender_txLaneDeskewApplied = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied : ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  assign ltsmCore_flagFromAnalog_rxDeskew_lfsrPatternSent = testModeLtsm ? jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent : ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  assign ltsmCore_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = testModeLtsm ? jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied : ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  assign ltsmCore_flagFromAnalog_rxDeskew_detectedDataPattern = testModeLtsm ? jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern : ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  assign ltsmCore_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = testModeLtsm ? jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful : ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;

  // Outputs of ltsm: normal sink or TDR pin (the other side is 0, so the
  // rest of the core sees an idle block in test mode).
  assign jtagLtsm_sb_tx_din = testModeLtsm ? ltsmCore_sb_tx_din : '0;
  assign ltsm_raw_tx_msg = testModeLtsm ? '0 : ltsmCore_sb_tx_din;
  assign jtagLtsm_sb_tx_valid = testModeLtsm ? ltsmCore_sb_tx_valid : '0;
  assign ltsm_raw_tx_valid = testModeLtsm ? '0 : ltsmCore_sb_tx_valid;
  assign jtagLtsm_flagToAnalog_RepairClkState = testModeLtsm ? ltsmCore_flagToAnalog_RepairClkState : '0;
  assign ltsm_flagToAnalog_RepairClkState = testModeLtsm ? '0 : ltsmCore_flagToAnalog_RepairClkState;
  assign jtagLtsm_flagToAnalog_SendClkPatterns = testModeLtsm ? ltsmCore_flagToAnalog_SendClkPatterns : '0;
  assign ltsm_flagToAnalog_SendClkPatterns = testModeLtsm ? '0 : ltsmCore_flagToAnalog_SendClkPatterns;
  assign jtagLtsm_flagToAnalog_RepairValState = testModeLtsm ? ltsmCore_flagToAnalog_RepairValState : '0;
  assign ltsm_flagToAnalog_RepairValState = testModeLtsm ? '0 : ltsmCore_flagToAnalog_RepairValState;
  assign jtagLtsm_flagToAnalog_SendValTrainPattern = testModeLtsm ? ltsmCore_flagToAnalog_SendValTrainPattern : '0;
  assign ltsm_flagToAnalog_SendValTrainPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_SendValTrainPattern;
  assign jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern = testModeLtsm ? ltsmCore_flagToAnalog_ReversalMbSendLaneIDPattern : '0;
  assign ltsm_flagToAnalog_ReversalMbSendLaneIDPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_ReversalMbSendLaneIDPattern;
  assign jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern = testModeLtsm ? ltsmCore_flagToAnalog_RepairMbSendLaneIDPattern : '0;
  assign ltsm_flagToAnalog_RepairMbSendLaneIDPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_RepairMbSendLaneIDPattern;
  assign jtagLtsm_flagToAnalog_RepairMbSetReceiver = testModeLtsm ? ltsmCore_flagToAnalog_RepairMbSetReceiver : '0;
  assign ltsm_flagToAnalog_RepairMbSetReceiver = testModeLtsm ? '0 : ltsmCore_flagToAnalog_RepairMbSetReceiver;
  assign jtagLtsm_flagToAnalog_LaneReversalApplied = testModeLtsm ? ltsmCore_flagToAnalog_LaneReversalApplied : '0;
  assign ltsm_flagToAnalog_LaneReversalApplied = testModeLtsm ? '0 : ltsmCore_flagToAnalog_LaneReversalApplied;
  assign jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler = testModeLtsm ? ltsmCore_flagToAnalog_linkInit_resetLfsrScrambler : '0;
  assign ltsm_flagToAnalog_linkInit_resetLfsrScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_linkInit_resetLfsrScrambler;
  assign jtagLtsm_state = testModeLtsm ? ltsmCore_state : '0;
  assign ltsm_state_int = testModeLtsm ? '0 : ltsmCore_state;
  assign jtagLtsm_dbg_flagSbinitFirstClkPatternSeen = testModeLtsm ? ltsmCore_dbg_flagSbinitFirstClkPatternSeen : '0;
  assign ltsm_dbg_flagSbinitFirstClkPatternSeen = testModeLtsm ? '0 : ltsmCore_dbg_flagSbinitFirstClkPatternSeen;
  assign jtagLtsm_dbg_rxValidRisingEdge = testModeLtsm ? ltsmCore_dbg_rxValidRisingEdge : '0;
  assign ltsm_dbg_rxValidRisingEdge = testModeLtsm ? '0 : ltsmCore_dbg_rxValidRisingEdge;
  assign jtagLtsm_dbg_sbinitSendCount = testModeLtsm ? ltsmCore_dbg_sbinitSendCount : '0;
  assign ltsm_dbg_sbinitSendCount = testModeLtsm ? '0 : ltsmCore_dbg_sbinitSendCount;
  assign jtagLtsm_dbg_sbTxValid = testModeLtsm ? ltsmCore_dbg_sbTxValid : '0;
  assign ltsm_dbg_sbTxValid = testModeLtsm ? '0 : ltsmCore_dbg_sbTxValid;
  assign jtagLtsm_dbg_sbTxDin = testModeLtsm ? ltsmCore_dbg_sbTxDin : '0;
  assign ltsm_dbg_sbTxDin = testModeLtsm ? '0 : ltsmCore_dbg_sbTxDin;
  assign jtagLtsm_dbg_flagTrainError = testModeLtsm ? ltsmCore_dbg_flagTrainError : '0;
  assign ltsm_dbg_flagTrainError = testModeLtsm ? '0 : ltsmCore_dbg_flagTrainError;
  assign jtagLtsm_dbg_mbinitSubstate = testModeLtsm ? ltsmCore_dbg_mbinitSubstate : '0;
  assign ltsm_dbg_mbinitSubstate = testModeLtsm ? '0 : ltsmCore_dbg_mbinitSubstate;
  assign jtagLtsm_dbg_mbinitParamSenderState = testModeLtsm ? ltsmCore_dbg_mbinitParamSenderState : '0;
  assign jtagLtsm_dbg_mbinitParamReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitParamReceiverState : '0;
  assign jtagLtsm_dbg_mbinitCalSenderState = testModeLtsm ? ltsmCore_dbg_mbinitCalSenderState : '0;
  assign jtagLtsm_dbg_mbinitCalReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitCalReceiverState : '0;
  assign jtagLtsm_dbg_mbinitRepairClkSenderState = testModeLtsm ? ltsmCore_dbg_mbinitRepairClkSenderState : '0;
  assign jtagLtsm_dbg_mbinitRepairClkReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitRepairClkReceiverState : '0;
  assign jtagLtsm_dbg_mbinitRepairValSenderState = testModeLtsm ? ltsmCore_dbg_mbinitRepairValSenderState : '0;
  assign jtagLtsm_dbg_mbinitRepairValReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitRepairValReceiverState : '0;
  assign jtagLtsm_dbg_mbinitReversalMbSenderState = testModeLtsm ? ltsmCore_dbg_mbinitReversalMbSenderState : '0;
  assign jtagLtsm_dbg_mbinitReversalMbReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitReversalMbReceiverState : '0;
  assign jtagLtsm_dbg_mbinitRepairMbSenderState = testModeLtsm ? ltsmCore_dbg_mbinitRepairMbSenderState : '0;
  assign jtagLtsm_dbg_mbinitRepairMbReceiverState = testModeLtsm ? ltsmCore_dbg_mbinitRepairMbReceiverState : '0;
  assign jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount = testModeLtsm ? ltsmCore_dbg_mbinitReversalMbReceivedSuccessCount : '0;
  assign ltsm_dbg_mbinitReversalMbReceivedSuccessCount = testModeLtsm ? '0 : ltsmCore_dbg_mbinitReversalMbReceivedSuccessCount;
  assign jtagLtsm_flagToAnalog_valVref_sendPattern = testModeLtsm ? ltsmCore_flagToAnalog_valVref_sendPattern : '0;
  assign ltsm_flagToAnalog_valVref_sendPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_sendPattern;
  assign jtagLtsm_flagToAnalog_valVref_applyRxVref = testModeLtsm ? ltsmCore_flagToAnalog_valVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_valVref_applyRxVref = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_applyRxVref;
  assign jtagLtsm_flagToAnalog_valVref_rxVrefCode = testModeLtsm ? ltsmCore_flagToAnalog_valVref_rxVrefCode : '0;
  assign ltsm_flagToAnalog_valVref_rxVrefCode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_rxVrefCode;
  assign jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest = testModeLtsm ? ltsmCore_flagToAnalog_valVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_configureRxInitD2CPointTest;
  assign jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold = testModeLtsm ? ltsmCore_flagToAnalog_valVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  assign jtagLtsm_flagToAnalog_valVref_comparisonMode = testModeLtsm ? ltsmCore_flagToAnalog_valVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_valVref_comparisonMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_comparisonMode;
  assign jtagLtsm_flagToAnalog_valVref_iterationCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_valVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_iterationCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_iterationCountSettings;
  assign jtagLtsm_flagToAnalog_valVref_idleCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_valVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_idleCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_idleCountSettings;
  assign jtagLtsm_flagToAnalog_valVref_burstCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_valVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_burstCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_burstCountSettings;
  assign jtagLtsm_flagToAnalog_valVref_patternMode = testModeLtsm ? ltsmCore_flagToAnalog_valVref_patternMode : '0;
  assign ltsm_flagToAnalog_valVref_patternMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_patternMode;
  assign jtagLtsm_flagToAnalog_valVref_clockPhaseControl = testModeLtsm ? ltsmCore_flagToAnalog_valVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_valVref_clockPhaseControl = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_clockPhaseControl;
  assign jtagLtsm_flagToAnalog_valVref_validPattern = testModeLtsm ? ltsmCore_flagToAnalog_valVref_validPattern : '0;
  assign ltsm_flagToAnalog_valVref_validPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_validPattern;
  assign jtagLtsm_flagToAnalog_valVref_dataPattern = testModeLtsm ? ltsmCore_flagToAnalog_valVref_dataPattern : '0;
  assign ltsm_flagToAnalog_valVref_dataPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_dataPattern;
  assign jtagLtsm_flagToAnalog_valVref_clearComparisonErrors = testModeLtsm ? ltsmCore_flagToAnalog_valVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_valVref_clearComparisonErrors = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_clearComparisonErrors;
  assign jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler = testModeLtsm ? ltsmCore_flagToAnalog_valVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_valVref_resetLocalTxScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_valVref_resetLocalTxScrambler;
  assign jtagLtsm_flagToAnalog_dataVref_sendPattern = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_sendPattern : '0;
  assign ltsm_flagToAnalog_dataVref_sendPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_sendPattern;
  assign jtagLtsm_flagToAnalog_dataVref_applyRxVref = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_dataVref_applyRxVref = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_applyRxVref;
  assign jtagLtsm_flagToAnalog_dataVref_rxVrefCodes = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_rxVrefCodes : '0;
  assign ltsm_flagToAnalog_dataVref_rxVrefCodes = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_rxVrefCodes;
  assign jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  assign jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  assign jtagLtsm_flagToAnalog_dataVref_comparisonMode = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_dataVref_comparisonMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_comparisonMode;
  assign jtagLtsm_flagToAnalog_dataVref_iterationCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_iterationCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_iterationCountSettings;
  assign jtagLtsm_flagToAnalog_dataVref_idleCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_idleCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_idleCountSettings;
  assign jtagLtsm_flagToAnalog_dataVref_burstCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_burstCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_burstCountSettings;
  assign jtagLtsm_flagToAnalog_dataVref_patternMode = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_patternMode : '0;
  assign ltsm_flagToAnalog_dataVref_patternMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_patternMode;
  assign jtagLtsm_flagToAnalog_dataVref_clockPhaseControl = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_dataVref_clockPhaseControl = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_clockPhaseControl;
  assign jtagLtsm_flagToAnalog_dataVref_validPattern = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_validPattern : '0;
  assign ltsm_flagToAnalog_dataVref_validPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_validPattern;
  assign jtagLtsm_flagToAnalog_dataVref_dataPattern = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_dataPattern : '0;
  assign ltsm_flagToAnalog_dataVref_dataPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_dataPattern;
  assign jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_dataVref_clearComparisonErrors = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_clearComparisonErrors;
  assign jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler = testModeLtsm ? ltsmCore_flagToAnalog_dataVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_dataVref_resetLocalTxScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_dataVref_resetLocalTxScrambler;
  assign jtagLtsm_flagToAnalog_rxClkCal_doCalibration = testModeLtsm ? ltsmCore_flagToAnalog_rxClkCal_doCalibration : '0;
  assign ltsm_flagToAnalog_rxClkCal_doCalibration = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxClkCal_doCalibration;
  assign jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack = testModeLtsm ? ltsmCore_flagToAnalog_rxClkCal_sendClockTrack : '0;
  assign ltsm_flagToAnalog_rxClkCal_sendClockTrack = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxClkCal_sendClockTrack;
  assign jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_sendValTrainPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_sendValTrainPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_sendValTrainPattern;
  assign jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_resetLocalScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_resetLocalScrambler;
  assign jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_applyTxClockPhase = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_applyTxClockPhase;
  assign jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_txClockPhaseCode : '0;
  assign ltsm_flagToAnalog_d2cSender_txClockPhaseCode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_txClockPhaseCode;
  assign jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  assign jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  assign jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_comparisonMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_comparisonMode;
  assign jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_iterationCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_iterationCountSettings;
  assign jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_idleCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_idleCountSettings;
  assign jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_burstCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_burstCountSettings;
  assign jtagLtsm_flagToAnalog_d2cReceiver_patternMode = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_patternMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_patternMode;
  assign jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_clockPhaseControl = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_clockPhaseControl;
  assign jtagLtsm_flagToAnalog_d2cReceiver_validPattern = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_validPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_validPattern;
  assign jtagLtsm_flagToAnalog_d2cReceiver_dataPattern = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_dataPattern;
  assign jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler = testModeLtsm ? ltsmCore_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  assign jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_sendLfsrPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_sendLfsrPattern;
  assign jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_applyTxLaneDeskew : '0;
  assign ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_applyTxLaneDeskew;
  assign jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes = testModeLtsm ? ltsmCore_flagToAnalog_d2cSender_txLaneDeskewCodes : '0;
  assign ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes = testModeLtsm ? '0 : ltsmCore_flagToAnalog_d2cSender_txLaneDeskewCodes;
  assign jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_sendLfsrPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_sendLfsrPattern;
  assign jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  assign jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_applyRxLaneDeskew : '0;
  assign ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  assign jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_rxLaneDeskewCodes : '0;
  assign ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  assign jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  assign jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  assign jtagLtsm_flagToAnalog_rxDeskew_comparisonMode = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_comparisonMode : '0;
  assign ltsm_flagToAnalog_rxDeskew_comparisonMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_comparisonMode;
  assign jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_iterationCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_iterationCountSettings;
  assign jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_idleCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_idleCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_idleCountSettings;
  assign jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_burstCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_burstCountSettings = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_burstCountSettings;
  assign jtagLtsm_flagToAnalog_rxDeskew_patternMode = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_patternMode : '0;
  assign ltsm_flagToAnalog_rxDeskew_patternMode = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_patternMode;
  assign jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_rxDeskew_clockPhaseControl = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_clockPhaseControl;
  assign jtagLtsm_flagToAnalog_rxDeskew_validPattern = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_validPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_validPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_validPattern;
  assign jtagLtsm_flagToAnalog_rxDeskew_dataPattern = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_dataPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_dataPattern = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_dataPattern;
  assign jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors = testModeLtsm ? ltsmCore_flagToAnalog_rxDeskew_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_rxDeskew_clearComparisonErrors = testModeLtsm ? '0 : ltsmCore_flagToAnalog_rxDeskew_clearComparisonErrors;
  assign jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain = testModeLtsm ? ltsmCore_flagToLtsm_linkSpeed_phyInRetrain : '0;
  assign ltsm_flagToLtsm_linkSpeed_phyInRetrain = testModeLtsm ? '0 : ltsmCore_flagToLtsm_linkSpeed_phyInRetrain;
  assign jtagLtsm_dbg_mbtrainState = testModeLtsm ? ltsmCore_dbg_mbtrainState : '0;
  assign ltsm_dbg_mbtrainState = testModeLtsm ? '0 : ltsmCore_dbg_mbtrainState;
  assign jtagLtsm_dbg_mbtrainActiveSubstate = testModeLtsm ? ltsmCore_dbg_mbtrainActiveSubstate : '0;
  assign ltsm_dbg_mbtrainActiveSubstate = testModeLtsm ? '0 : ltsmCore_dbg_mbtrainActiveSubstate;
  assign jtagLtsm_dbg_mbtrainValVrefLocalState = testModeLtsm ? ltsmCore_dbg_mbtrainValVrefLocalState : '0;
  assign jtagLtsm_dbg_mbtrainValVrefRemoteState = testModeLtsm ? ltsmCore_dbg_mbtrainValVrefRemoteState : '0;
  assign jtagLtsm_dbg_mbtrainValVrefSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainValVrefSweepState : '0;
  assign jtagLtsm_dbg_mbtrainValVrefPointInitiatorState = testModeLtsm ? ltsmCore_dbg_mbtrainValVrefPointInitiatorState : '0;
  assign jtagLtsm_dbg_mbtrainValVrefPointResponderState = testModeLtsm ? ltsmCore_dbg_mbtrainValVrefPointResponderState : '0;
  assign jtagLtsm_dbg_mbtrainDataVrefLocalState = testModeLtsm ? ltsmCore_dbg_mbtrainDataVrefLocalState : '0;
  assign jtagLtsm_dbg_mbtrainDataVrefRemoteState = testModeLtsm ? ltsmCore_dbg_mbtrainDataVrefRemoteState : '0;
  assign jtagLtsm_dbg_mbtrainDataVrefSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainDataVrefSweepState : '0;
  assign jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState = testModeLtsm ? ltsmCore_dbg_mbtrainDataVrefPointInitiatorState : '0;
  assign jtagLtsm_dbg_mbtrainDataVrefPointResponderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataVrefPointResponderState : '0;
  assign jtagLtsm_dbg_mbtrainSpeedIdleSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainSpeedIdleSenderState : '0;
  assign jtagLtsm_dbg_mbtrainSpeedIdleReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainSpeedIdleReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainTxSelfCalSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainTxSelfCalSenderState : '0;
  assign jtagLtsm_dbg_mbtrainTxSelfCalReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainTxSelfCalReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainRxClkCalSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainRxClkCalSenderState : '0;
  assign jtagLtsm_dbg_mbtrainRxClkCalReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainRxClkCalReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainCenterSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainCenterSenderState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainCenterReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainCenterReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainCenterD2cSenderState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainCenterD2cReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainCenterSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainCenterSweepState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainVrefLocalState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainVrefLocalState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainVrefRemoteState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainVrefRemoteState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainVrefSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainVrefSweepState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainVrefPointInitiatorState : '0;
  assign jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState = testModeLtsm ? ltsmCore_dbg_mbtrainValTrainVrefPointResponderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter1SenderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter1ReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter1D2cSenderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter1D2cReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter1SweepState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainVrefLocalState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainVrefLocalState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainVrefRemoteState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainVrefSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainVrefSweepState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainVrefPointInitiatorState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainVrefPointResponderState : '0;
  assign jtagLtsm_dbg_mbtrainRxDeskewLocalState = testModeLtsm ? ltsmCore_dbg_mbtrainRxDeskewLocalState : '0;
  assign jtagLtsm_dbg_mbtrainRxDeskewRemoteState = testModeLtsm ? ltsmCore_dbg_mbtrainRxDeskewRemoteState : '0;
  assign jtagLtsm_dbg_mbtrainRxDeskewSweepState = testModeLtsm ? ltsmCore_dbg_mbtrainRxDeskewSweepState : '0;
  assign jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState = testModeLtsm ? ltsmCore_dbg_mbtrainRxDeskewPointInitiatorState : '0;
  assign jtagLtsm_dbg_mbtrainRxDeskewPointResponderState = testModeLtsm ? ltsmCore_dbg_mbtrainRxDeskewPointResponderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter2SenderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter2ReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter2D2cSenderState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter2D2cReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState = testModeLtsm ? ltsmCore_dbg_mbtrainDataTrainCenter2SweepState : '0;
  assign jtagLtsm_dbg_mbtrainLinkSpeedSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainLinkSpeedSenderState : '0;
  assign jtagLtsm_dbg_mbtrainLinkSpeedReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainLinkSpeedReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState = testModeLtsm ? ltsmCore_dbg_mbtrainLinkSpeedD2cSenderState : '0;
  assign jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState = testModeLtsm ? ltsmCore_dbg_mbtrainLinkSpeedD2cReceiverState : '0;
  assign jtagLtsm_dbg_mbtrainLastErrorCount = testModeLtsm ? ltsmCore_dbg_mbtrainLastErrorCount : '0;
  assign ltsm_dbg_mbtrainLastErrorCount = testModeLtsm ? '0 : ltsmCore_dbg_mbtrainLastErrorCount;
  assign jtagLtsm_dbg_mbtrainRetryCount = testModeLtsm ? ltsmCore_dbg_mbtrainRetryCount : '0;
  assign ltsm_dbg_mbtrainRetryCount = testModeLtsm ? '0 : ltsmCore_dbg_mbtrainRetryCount;

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
    .reset_n                                                                   (ltsmCore_reset_n),
    .sb_tx_din                                                                 (ltsmCore_sb_tx_din),
    .sb_tx_valid                                                               (ltsmCore_sb_tx_valid),
    .sb_tx_ready                                                               (ltsmCore_sb_tx_ready),
    .sb_rx_dout                                                                (ltsmCore_sb_rx_dout),
    .sb_rx_valid                                                               (ltsmCore_sb_rx_valid),
    .start                                                                     (ltsmCore_start),
    .stable_clk                                                                (ltsmCore_stable_clk),
    .pll_locked                                                                (ltsmCore_pll_locked),
    .stable_supply                                                             (ltsmCore_stable_supply),
    .flagFromAnalog_ReadyToExchangeClkPatterns                                 (ltsmCore_flagFromAnalog_ReadyToExchangeClkPatterns),
    .flagFromAnalog_FinishedClkPatterns                                        (ltsmCore_flagFromAnalog_FinishedClkPatterns),
    .flagFromAnalog_FinishedValTrainPattern                                    (ltsmCore_flagFromAnalog_FinishedValTrainPattern),
    .flagFromAnalog_ReversalMbFinishedLaneIDPattern                            (ltsmCore_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .flagFromAnalog_RepairMbFinishedLaneIDPattern                              (ltsmCore_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .flagFromAnalog_clkPatternReceivedRTRK_L                                   (ltsmCore_flagFromAnalog_clkPatternReceivedRTRK_L),
    .flagFromAnalog_clkPatternReceivedRCKN_L                                   (ltsmCore_flagFromAnalog_clkPatternReceivedRCKN_L),
    .flagFromAnalog_clkPatternReceivedRCKP_L                                   (ltsmCore_flagFromAnalog_clkPatternReceivedRCKP_L),
    .flagFromAnalog_ValTrainPatternReceived                                    (ltsmCore_flagFromAnalog_ValTrainPatternReceived),
    .flagFromAnalog_ReversalMbTrainPatternReceived0                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .flagFromAnalog_ReversalMbTrainPatternReceived1                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .flagFromAnalog_ReversalMbTrainPatternReceived2                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .flagFromAnalog_ReversalMbTrainPatternReceived3                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .flagFromAnalog_ReversalMbTrainPatternReceived4                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .flagFromAnalog_ReversalMbTrainPatternReceived5                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .flagFromAnalog_ReversalMbTrainPatternReceived6                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .flagFromAnalog_ReversalMbTrainPatternReceived7                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .flagFromAnalog_ReversalMbTrainPatternReceived8                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .flagFromAnalog_ReversalMbTrainPatternReceived9                            (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .flagFromAnalog_ReversalMbTrainPatternReceived10                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .flagFromAnalog_ReversalMbTrainPatternReceived11                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .flagFromAnalog_ReversalMbTrainPatternReceived12                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .flagFromAnalog_ReversalMbTrainPatternReceived13                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .flagFromAnalog_ReversalMbTrainPatternReceived14                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .flagFromAnalog_ReversalMbTrainPatternReceived15                           (ltsmCore_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern0                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern1                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern2                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern3                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern4                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern5                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern6                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern7                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern8                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern9                             (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern10                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern11                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern12                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern13                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern14                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .flagFromAnalog_RepairMbDetectedLaneIDPattern15                            (ltsmCore_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .flagToAnalog_RepairClkState                                               (ltsmCore_flagToAnalog_RepairClkState),
    .flagToAnalog_SendClkPatterns                                              (ltsmCore_flagToAnalog_SendClkPatterns),
    .flagToAnalog_RepairValState                                               (ltsmCore_flagToAnalog_RepairValState),
    .flagToAnalog_SendValTrainPattern                                          (ltsmCore_flagToAnalog_SendValTrainPattern),
    .flagToAnalog_ReversalMbSendLaneIDPattern                                  (ltsmCore_flagToAnalog_ReversalMbSendLaneIDPattern),
    .flagToAnalog_RepairMbSendLaneIDPattern                                    (ltsmCore_flagToAnalog_RepairMbSendLaneIDPattern),
    .flagToAnalog_RepairMbSetReceiver                                          (ltsmCore_flagToAnalog_RepairMbSetReceiver),
    .flagToAnalog_LaneReversalApplied                                          (ltsmCore_flagToAnalog_LaneReversalApplied),
    .flagToAnalog_linkInit_resetLfsrScrambler                                  (ltsmCore_flagToAnalog_linkInit_resetLfsrScrambler),
    .state                                                                     (ltsmCore_state),
    .dbg_flagSbinitFirstClkPatternSeen                                         (ltsmCore_dbg_flagSbinitFirstClkPatternSeen),
    .dbg_rxValidRisingEdge                                                     (ltsmCore_dbg_rxValidRisingEdge),
    .dbg_sbinitSendCount                                                       (ltsmCore_dbg_sbinitSendCount),
    .dbg_sbTxValid                                                             (ltsmCore_dbg_sbTxValid),
    .dbg_sbTxDin                                                               (ltsmCore_dbg_sbTxDin),
    .dbg_flagTrainError                                                        (ltsmCore_dbg_flagTrainError),
    // TODO(debug-review): MBInitFSM.substate (MBINIT main state) kept during the debug-pin cleanup; review naming/need vs the dbg_mbinit*State pins.
    .dbg_mbinitSubstate                                                        (ltsmCore_dbg_mbinitSubstate),
    .dbg_mbinitReversalMbReceivedSuccessCount                                  (ltsmCore_dbg_mbinitReversalMbReceivedSuccessCount),
    .flagToAnalog_valVref_sendPattern                                          (ltsmCore_flagToAnalog_valVref_sendPattern),
    .flagFromAnalog_valVref_detectedValPattern                                 (ltsmCore_flagFromAnalog_valVref_detectedValPattern),
    .flagFromAnalog_valVref_finishedPattern                                    (ltsmCore_flagFromAnalog_valVref_finishedPattern),
    .flagToAnalog_valVref_applyRxVref                                          (ltsmCore_flagToAnalog_valVref_applyRxVref),
    .flagToAnalog_valVref_rxVrefCode                                           (ltsmCore_flagToAnalog_valVref_rxVrefCode),
    .flagFromAnalog_valVref_rxVrefApplied                                      (ltsmCore_flagFromAnalog_valVref_rxVrefApplied),
    .flagToAnalog_valVref_configureRxInitD2CPointTest                          (ltsmCore_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .flagToAnalog_valVref_maximumComparisonErrorThreshold                      (ltsmCore_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .flagToAnalog_valVref_comparisonMode                                       (ltsmCore_flagToAnalog_valVref_comparisonMode),
    .flagToAnalog_valVref_iterationCountSettings                               (ltsmCore_flagToAnalog_valVref_iterationCountSettings),
    .flagToAnalog_valVref_idleCountSettings                                    (ltsmCore_flagToAnalog_valVref_idleCountSettings),
    .flagToAnalog_valVref_burstCountSettings                                   (ltsmCore_flagToAnalog_valVref_burstCountSettings),
    .flagToAnalog_valVref_patternMode                                          (ltsmCore_flagToAnalog_valVref_patternMode),
    .flagToAnalog_valVref_clockPhaseControl                                    (ltsmCore_flagToAnalog_valVref_clockPhaseControl),
    .flagToAnalog_valVref_validPattern                                         (ltsmCore_flagToAnalog_valVref_validPattern),
    .flagToAnalog_valVref_dataPattern                                          (ltsmCore_flagToAnalog_valVref_dataPattern),
    .flagToAnalog_valVref_clearComparisonErrors                                (ltsmCore_flagToAnalog_valVref_clearComparisonErrors),
    .flagToAnalog_valVref_resetLocalTxScrambler                                (ltsmCore_flagToAnalog_valVref_resetLocalTxScrambler),
    .flagToAnalog_dataVref_sendPattern                                         (ltsmCore_flagToAnalog_dataVref_sendPattern),
    .flagFromAnalog_dataVref_detectedDataPattern                               (ltsmCore_flagFromAnalog_dataVref_detectedDataPattern),
    .flagFromAnalog_dataVref_finishedPattern                                   (ltsmCore_flagFromAnalog_dataVref_finishedPattern),
    .flagToAnalog_dataVref_applyRxVref                                         (ltsmCore_flagToAnalog_dataVref_applyRxVref),
    .flagToAnalog_dataVref_rxVrefCodes                                         (ltsmCore_flagToAnalog_dataVref_rxVrefCodes),
    .flagFromAnalog_dataVref_rxVrefApplied                                     (ltsmCore_flagFromAnalog_dataVref_rxVrefApplied),
    .flagToAnalog_dataVref_configureRxInitD2CPointTest                         (ltsmCore_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (ltsmCore_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .flagToAnalog_dataVref_comparisonMode                                      (ltsmCore_flagToAnalog_dataVref_comparisonMode),
    .flagToAnalog_dataVref_iterationCountSettings                              (ltsmCore_flagToAnalog_dataVref_iterationCountSettings),
    .flagToAnalog_dataVref_idleCountSettings                                   (ltsmCore_flagToAnalog_dataVref_idleCountSettings),
    .flagToAnalog_dataVref_burstCountSettings                                  (ltsmCore_flagToAnalog_dataVref_burstCountSettings),
    .flagToAnalog_dataVref_patternMode                                         (ltsmCore_flagToAnalog_dataVref_patternMode),
    .flagToAnalog_dataVref_clockPhaseControl                                   (ltsmCore_flagToAnalog_dataVref_clockPhaseControl),
    .flagToAnalog_dataVref_validPattern                                        (ltsmCore_flagToAnalog_dataVref_validPattern),
    .flagToAnalog_dataVref_dataPattern                                         (ltsmCore_flagToAnalog_dataVref_dataPattern),
    .flagToAnalog_dataVref_clearComparisonErrors                               (ltsmCore_flagToAnalog_dataVref_clearComparisonErrors),
    .flagToAnalog_dataVref_resetLocalTxScrambler                               (ltsmCore_flagToAnalog_dataVref_resetLocalTxScrambler),
    .flagToAnalog_rxClkCal_doCalibration                                       (ltsmCore_flagToAnalog_rxClkCal_doCalibration),
    .flagFromAnalog_rxClkCal_done                                              (ltsmCore_flagFromAnalog_rxClkCal_done),
    .flagToAnalog_rxClkCal_sendClockTrack                                      (ltsmCore_flagToAnalog_rxClkCal_sendClockTrack),
    .flagToAnalog_d2cSender_sendValTrainPattern                 (ltsmCore_flagToAnalog_d2cSender_sendValTrainPattern),
    .flagFromAnalog_d2cSender_valTrainPatternSent               (ltsmCore_flagFromAnalog_d2cSender_valTrainPatternSent),
    .flagToAnalog_d2cSender_resetLocalScrambler                 (ltsmCore_flagToAnalog_d2cSender_resetLocalScrambler),
    .flagToAnalog_d2cSender_applyTxClockPhase                   (ltsmCore_flagToAnalog_d2cSender_applyTxClockPhase),
    .flagToAnalog_d2cSender_txClockPhaseCode                    (ltsmCore_flagToAnalog_d2cSender_txClockPhaseCode),
    .flagFromAnalog_d2cSender_txClockPhaseApplied               (ltsmCore_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .flagToAnalog_d2cReceiver_configureTxInitD2CPointTest       (ltsmCore_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold   (ltsmCore_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .flagToAnalog_d2cReceiver_comparisonMode                    (ltsmCore_flagToAnalog_d2cReceiver_comparisonMode),
    .flagToAnalog_d2cReceiver_iterationCountSettings            (ltsmCore_flagToAnalog_d2cReceiver_iterationCountSettings),
    .flagToAnalog_d2cReceiver_idleCountSettings                 (ltsmCore_flagToAnalog_d2cReceiver_idleCountSettings),
    .flagToAnalog_d2cReceiver_burstCountSettings                (ltsmCore_flagToAnalog_d2cReceiver_burstCountSettings),
    .flagToAnalog_d2cReceiver_patternMode                       (ltsmCore_flagToAnalog_d2cReceiver_patternMode),
    .flagToAnalog_d2cReceiver_clockPhaseControl                 (ltsmCore_flagToAnalog_d2cReceiver_clockPhaseControl),
    .flagToAnalog_d2cReceiver_validPattern                      (ltsmCore_flagToAnalog_d2cReceiver_validPattern),
    .flagToAnalog_d2cReceiver_dataPattern                       (ltsmCore_flagToAnalog_d2cReceiver_dataPattern),
    .flagToAnalog_d2cReceiver_resetLocalRxScrambler             (ltsmCore_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo         (ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload         (ltsmCore_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .flagToAnalog_d2cSender_sendLfsrPattern                   (ltsmCore_flagToAnalog_d2cSender_sendLfsrPattern),
    .flagFromAnalog_d2cSender_lfsrPatternSent                 (ltsmCore_flagFromAnalog_d2cSender_lfsrPatternSent),
    .flagToAnalog_d2cSender_applyTxLaneDeskew                 (ltsmCore_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .flagToAnalog_d2cSender_txLaneDeskewCodes                 (ltsmCore_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .flagFromAnalog_d2cSender_txLaneDeskewApplied             (ltsmCore_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .flagToAnalog_rxDeskew_sendLfsrPattern                                     (ltsmCore_flagToAnalog_rxDeskew_sendLfsrPattern),
    .flagFromAnalog_rxDeskew_lfsrPatternSent                                   (ltsmCore_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .flagToAnalog_rxDeskew_resetLocalTxScrambler                               (ltsmCore_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .flagToAnalog_rxDeskew_applyRxLaneDeskew                                   (ltsmCore_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .flagToAnalog_rxDeskew_rxLaneDeskewCodes                                   (ltsmCore_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .flagFromAnalog_rxDeskew_rxLaneDeskewApplied                               (ltsmCore_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .flagToAnalog_rxDeskew_configureRxInitD2CPointTest                         (ltsmCore_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                     (ltsmCore_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .flagToAnalog_rxDeskew_comparisonMode                                      (ltsmCore_flagToAnalog_rxDeskew_comparisonMode),
    .flagToAnalog_rxDeskew_iterationCountSettings                              (ltsmCore_flagToAnalog_rxDeskew_iterationCountSettings),
    .flagToAnalog_rxDeskew_idleCountSettings                                   (ltsmCore_flagToAnalog_rxDeskew_idleCountSettings),
    .flagToAnalog_rxDeskew_burstCountSettings                                  (ltsmCore_flagToAnalog_rxDeskew_burstCountSettings),
    .flagToAnalog_rxDeskew_patternMode                                         (ltsmCore_flagToAnalog_rxDeskew_patternMode),
    .flagToAnalog_rxDeskew_clockPhaseControl                                   (ltsmCore_flagToAnalog_rxDeskew_clockPhaseControl),
    .flagToAnalog_rxDeskew_validPattern                                        (ltsmCore_flagToAnalog_rxDeskew_validPattern),
    .flagToAnalog_rxDeskew_dataPattern                                         (ltsmCore_flagToAnalog_rxDeskew_dataPattern),
    .flagToAnalog_rxDeskew_clearComparisonErrors                               (ltsmCore_flagToAnalog_rxDeskew_clearComparisonErrors),
    .flagFromAnalog_rxDeskew_detectedDataPattern                               (ltsmCore_flagFromAnalog_rxDeskew_detectedDataPattern),
    .flagToLtsm_linkSpeed_phyInRetrain                                         (ltsmCore_flagToLtsm_linkSpeed_phyInRetrain),
    .flagFromAnalog_d2cReceiver_laneComparisonSuccessful             (ltsmCore_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .dbg_mbtrainState                                                          (ltsmCore_dbg_mbtrainState),
    // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
    .dbg_mbtrainActiveSubstate                                                 (ltsmCore_dbg_mbtrainActiveSubstate),
    .dbg_mbtrainLastErrorCount                                                 (ltsmCore_dbg_mbtrainLastErrorCount),
    .dbg_mbtrainRetryCount                                                     (ltsmCore_dbg_mbtrainRetryCount),
    // Not used by the core; observable only in testModeLtsm.
    .dbg_mbinitParamSenderState                                                (ltsmCore_dbg_mbinitParamSenderState),
    .dbg_mbinitParamReceiverState                                              (ltsmCore_dbg_mbinitParamReceiverState),
    .dbg_mbinitCalSenderState                                                  (ltsmCore_dbg_mbinitCalSenderState),
    .dbg_mbinitCalReceiverState                                                (ltsmCore_dbg_mbinitCalReceiverState),
    .dbg_mbinitRepairClkSenderState                                            (ltsmCore_dbg_mbinitRepairClkSenderState),
    .dbg_mbinitRepairClkReceiverState                                          (ltsmCore_dbg_mbinitRepairClkReceiverState),
    .dbg_mbinitRepairValSenderState                                            (ltsmCore_dbg_mbinitRepairValSenderState),
    .dbg_mbinitRepairValReceiverState                                          (ltsmCore_dbg_mbinitRepairValReceiverState),
    .dbg_mbinitReversalMbSenderState                                           (ltsmCore_dbg_mbinitReversalMbSenderState),
    .dbg_mbinitReversalMbReceiverState                                         (ltsmCore_dbg_mbinitReversalMbReceiverState),
    .dbg_mbinitRepairMbSenderState                                             (ltsmCore_dbg_mbinitRepairMbSenderState),
    .dbg_mbinitRepairMbReceiverState                                           (ltsmCore_dbg_mbinitRepairMbReceiverState),
    .dbg_mbtrainValVrefLocalState                                              (ltsmCore_dbg_mbtrainValVrefLocalState),
    .dbg_mbtrainValVrefRemoteState                                             (ltsmCore_dbg_mbtrainValVrefRemoteState),
    .dbg_mbtrainValVrefSweepState                                              (ltsmCore_dbg_mbtrainValVrefSweepState),
    .dbg_mbtrainValVrefPointInitiatorState                                     (ltsmCore_dbg_mbtrainValVrefPointInitiatorState),
    .dbg_mbtrainValVrefPointResponderState                                     (ltsmCore_dbg_mbtrainValVrefPointResponderState),
    .dbg_mbtrainDataVrefLocalState                                             (ltsmCore_dbg_mbtrainDataVrefLocalState),
    .dbg_mbtrainDataVrefRemoteState                                            (ltsmCore_dbg_mbtrainDataVrefRemoteState),
    .dbg_mbtrainDataVrefSweepState                                             (ltsmCore_dbg_mbtrainDataVrefSweepState),
    .dbg_mbtrainDataVrefPointInitiatorState                                    (ltsmCore_dbg_mbtrainDataVrefPointInitiatorState),
    .dbg_mbtrainDataVrefPointResponderState                                    (ltsmCore_dbg_mbtrainDataVrefPointResponderState),
    .dbg_mbtrainSpeedIdleSenderState                                           (ltsmCore_dbg_mbtrainSpeedIdleSenderState),
    .dbg_mbtrainSpeedIdleReceiverState                                         (ltsmCore_dbg_mbtrainSpeedIdleReceiverState),
    .dbg_mbtrainTxSelfCalSenderState                                           (ltsmCore_dbg_mbtrainTxSelfCalSenderState),
    .dbg_mbtrainTxSelfCalReceiverState                                         (ltsmCore_dbg_mbtrainTxSelfCalReceiverState),
    .dbg_mbtrainRxClkCalSenderState                                            (ltsmCore_dbg_mbtrainRxClkCalSenderState),
    .dbg_mbtrainRxClkCalReceiverState                                          (ltsmCore_dbg_mbtrainRxClkCalReceiverState),
    .dbg_mbtrainValTrainCenterSenderState                                      (ltsmCore_dbg_mbtrainValTrainCenterSenderState),
    .dbg_mbtrainValTrainCenterReceiverState                                    (ltsmCore_dbg_mbtrainValTrainCenterReceiverState),
    .dbg_mbtrainValTrainCenterD2cSenderState                                   (ltsmCore_dbg_mbtrainValTrainCenterD2cSenderState),
    .dbg_mbtrainValTrainCenterD2cReceiverState                                 (ltsmCore_dbg_mbtrainValTrainCenterD2cReceiverState),
    .dbg_mbtrainValTrainCenterSweepState                                       (ltsmCore_dbg_mbtrainValTrainCenterSweepState),
    .dbg_mbtrainValTrainVrefLocalState                                         (ltsmCore_dbg_mbtrainValTrainVrefLocalState),
    .dbg_mbtrainValTrainVrefRemoteState                                        (ltsmCore_dbg_mbtrainValTrainVrefRemoteState),
    .dbg_mbtrainValTrainVrefSweepState                                         (ltsmCore_dbg_mbtrainValTrainVrefSweepState),
    .dbg_mbtrainValTrainVrefPointInitiatorState                                (ltsmCore_dbg_mbtrainValTrainVrefPointInitiatorState),
    .dbg_mbtrainValTrainVrefPointResponderState                                (ltsmCore_dbg_mbtrainValTrainVrefPointResponderState),
    .dbg_mbtrainDataTrainCenter1SenderState                                    (ltsmCore_dbg_mbtrainDataTrainCenter1SenderState),
    .dbg_mbtrainDataTrainCenter1ReceiverState                                  (ltsmCore_dbg_mbtrainDataTrainCenter1ReceiverState),
    .dbg_mbtrainDataTrainCenter1D2cSenderState                                 (ltsmCore_dbg_mbtrainDataTrainCenter1D2cSenderState),
    .dbg_mbtrainDataTrainCenter1D2cReceiverState                               (ltsmCore_dbg_mbtrainDataTrainCenter1D2cReceiverState),
    .dbg_mbtrainDataTrainCenter1SweepState                                     (ltsmCore_dbg_mbtrainDataTrainCenter1SweepState),
    .dbg_mbtrainDataTrainVrefLocalState                                        (ltsmCore_dbg_mbtrainDataTrainVrefLocalState),
    .dbg_mbtrainDataTrainVrefRemoteState                                       (ltsmCore_dbg_mbtrainDataTrainVrefRemoteState),
    .dbg_mbtrainDataTrainVrefSweepState                                        (ltsmCore_dbg_mbtrainDataTrainVrefSweepState),
    .dbg_mbtrainDataTrainVrefPointInitiatorState                               (ltsmCore_dbg_mbtrainDataTrainVrefPointInitiatorState),
    .dbg_mbtrainDataTrainVrefPointResponderState                               (ltsmCore_dbg_mbtrainDataTrainVrefPointResponderState),
    .dbg_mbtrainRxDeskewLocalState                                             (ltsmCore_dbg_mbtrainRxDeskewLocalState),
    .dbg_mbtrainRxDeskewRemoteState                                            (ltsmCore_dbg_mbtrainRxDeskewRemoteState),
    .dbg_mbtrainRxDeskewSweepState                                             (ltsmCore_dbg_mbtrainRxDeskewSweepState),
    .dbg_mbtrainRxDeskewPointInitiatorState                                    (ltsmCore_dbg_mbtrainRxDeskewPointInitiatorState),
    .dbg_mbtrainRxDeskewPointResponderState                                    (ltsmCore_dbg_mbtrainRxDeskewPointResponderState),
    .dbg_mbtrainDataTrainCenter2SenderState                                    (ltsmCore_dbg_mbtrainDataTrainCenter2SenderState),
    .dbg_mbtrainDataTrainCenter2ReceiverState                                  (ltsmCore_dbg_mbtrainDataTrainCenter2ReceiverState),
    .dbg_mbtrainDataTrainCenter2D2cSenderState                                 (ltsmCore_dbg_mbtrainDataTrainCenter2D2cSenderState),
    .dbg_mbtrainDataTrainCenter2D2cReceiverState                               (ltsmCore_dbg_mbtrainDataTrainCenter2D2cReceiverState),
    .dbg_mbtrainDataTrainCenter2SweepState                                     (ltsmCore_dbg_mbtrainDataTrainCenter2SweepState),
    .dbg_mbtrainLinkSpeedSenderState                                           (ltsmCore_dbg_mbtrainLinkSpeedSenderState),
    .dbg_mbtrainLinkSpeedReceiverState                                         (ltsmCore_dbg_mbtrainLinkSpeedReceiverState),
    .dbg_mbtrainLinkSpeedD2cSenderState                                        (ltsmCore_dbg_mbtrainLinkSpeedD2cSenderState),
    .dbg_mbtrainLinkSpeedD2cReceiverState                                      (ltsmCore_dbg_mbtrainLinkSpeedD2cReceiverState)
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
