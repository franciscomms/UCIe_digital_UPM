`default_nettype none

// ============================================================================
// UcieDigitalTop
// JTAG test wrapper around UcieDigitalCore. Every IO of the core top
// can be routed either to its functional pin or to a JTAG Test Data Register
// (TDR), selected by testModeDigital.
//
// Port naming:
//   <name>       Functional pin. Same name, type and direction as in UcieDigitalCore.
//   jtag_<name>  Test pin toward the TDR. Same type and direction as <name>.
//
// Muxing, per core port:
//                     testModeDigital = 0           testModeDigital = 1
//   core input        driven by <name>              driven by jtag_<name>
//                     (jtag_<name> ignored)         (<name> ignored)
//   core output       drives <name>                 drives jtag_<name>
//                     (jtag_<name> held at 0)       (<name> held at 0)
//
// clock, reset_n and sb_rx_clk are muxed like any other input, so in test mode
// the TDR drives the core clock and reset. The clock muxes are plain
// combinational muxes: change testModeDigital only while both clock sources
// are quiet (or with reset_n asserted) to avoid glitches on the core clock.
// For synthesis these should be replaced by glitch-free clock-mux cells.
//
// Block isolation tests, one TDR each, separate from the one above:
//   jtagFdi_<port>   FDI  (LinkManagementController),    testModeFdi
//   jtagRdi_<port>   RDI  (RdiLinkManagementController), testModeRdi
//   jtagLtsm_<port>  LTSM (LinkTrainingFSM),             testModeLtsm
//   One pin per port of that block inside the core, passed straight through
//   to u_core (jtag<Blk>_clock goes to the core clock mux here). The muxing
//   is done in UcieDigitalCore; see its header. In a block test the rest of
//   the core is held in reset and the block's functional pins read 0.
//
//   At most one testMode* may be set (UcieDigitalTopJtag drives them one-hot
//   from its control register). There is no priority logic: setting more than
//   one is not supported and is reported as an error in simulation.
//
//   Digital  Fdi  Rdi  Ltsm   mode
//      0      0    0    0     functional
//      1      0    0    0     digital test (jtag_*)
//      0      1    0    0     FDI isolation test (jtagFdi_*)
//      0      0    1    0     RDI isolation test (jtagRdi_*)
//      0      0    0    1     LTSM isolation test (jtagLtsm_*)
//
// Parameters are identical to UcieDigitalCore and passed straight through.
// ============================================================================

module UcieDigitalTop #(
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
  // Physical DLL/PI control word: 38 bits; the binary sweep index is internal.
  parameter int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned d2cTxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned d2cDeskewStepsPerPi = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI,
  parameter bit d2cDeskewAddDelayIncreasesPhase = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE,
  parameter logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned d2cMinLaneWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS,
  parameter int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES,
  parameter int unsigned validVrefValueCount = LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  // Physical Vref controls are 20-bit one-hot words, independent of sweep count.
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
  // Physical RX deskew uses two 10-bit cells per lane, not a binary delay index.
  parameter int unsigned rxDeskewCodeWidth =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH,
  parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES,
  parameter int unsigned SB_TX_FIFO_ENTRIES = 4
) (
  // ==========================================================================
  // TEST MODE SELECT
  // testModeDigital = 1: jtag_* (TDR) pins drive/observe the core.
  // testModeFdi / testModeRdi / testModeLtsm = 1:
  // jtagFdi_* / jtagRdi_* / jtagLtsm_* pins drive/observe only that block.
  // All 0: functional pins drive/observe the core. At most one may be set.
  // ==========================================================================
  input wire logic testModeDigital,
  input wire logic testModeFdi,
  input wire logic testModeRdi,
  input wire logic testModeLtsm,

  // ##########################################################################
  // FUNCTIONAL PINS (testModeDigital = 0)
  // ##########################################################################

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
  output var logic [1:0]           ltsm_flagToAnalog_linkSpeed_speedCode,
  output var logic           ltsm_flagToAnalog_linkSpeed_applySpeed,
  output var logic           ltsm_flagToAnalog_linkSpeed_electricalIdle,
  input wire logic [15:0]    ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  input wire logic [1:0]    ltsm_linkSpeed_requestedSpeed,
  input wire logic     ltsm_flagFromAnalog_linkSpeed_speedApplied,
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

  // ##########################################################################
  // JTAG TDR PINS (testModeDigital = 1)
  // Same order and grouping as the functional pins, prefixed with jtag_.
  // ##########################################################################

  // ==========================================================================
  // COMMON CLOCK AND RESET
  // ==========================================================================
  input wire logic jtag_clock,
  input wire logic jtag_reset_n,

  // ==========================================================================
  // FDI INTERFACE
  // Protocol layer <-> D2D adapter link-management interface.
  // ==========================================================================
  input wire UcieUPM_interfaces_pkg::PhyStateReq_t jtag_fdi_lp_state_req,
  input wire logic                                  jtag_fdi_lp_linkerror,
  input wire logic                                  jtag_fdi_lp_rx_active_sts,
  input wire logic                                  jtag_fdi_lp_wake_req,
  input wire logic                                  jtag_fdi_lp_clk_ack,
  input wire logic                                  jtag_fdi_lp_stall_ack,
  output var UcieUPM_interfaces_pkg::PhyState_t jtag_fdi_pl_state_sts,
  output var logic                               jtag_fdi_pl_rx_active_req,
  output var logic                               jtag_fdi_pl_inband_pres,
  output var logic                               jtag_fdi_pl_wake_ack,
  output var logic                               jtag_fdi_pl_clk_req,
  output var logic                               jtag_fdi_pl_stall_req,
  output var logic                               jtag_fdi_active,
  input wire logic jtag_timeout_disable,

  // ==========================================================================
  // LINK-MANAGEMENT TIMING REFERENCE
  // Used by the FDI and RDI link-management timeout counters.
  // ==========================================================================
  input wire logic [31:0] jtag_cycles_1us,

  // ==========================================================================
  // LTSM INTERFACE
  // Flattened LinkTrainingFSM interface toward the analog/PHY control logic.
  // ==========================================================================

  // LTSM startup and analog readiness inputs.
  input wire logic           jtag_ltsm_start,
  input wire logic           jtag_ltsm_stable_clk,
  input wire logic           jtag_ltsm_pll_locked,
  input wire logic           jtag_ltsm_stable_supply,
  input wire logic           jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic           jtag_ltsm_flagFromAnalog_FinishedClkPatterns,
  input wire logic           jtag_ltsm_flagFromAnalog_FinishedValTrainPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic           jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic           jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic           jtag_ltsm_flagFromAnalog_ValTrainPatternReceived,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
  input wire logic           jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
  input wire logic           jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
  output var logic           jtag_ltsm_flagToAnalog_RepairClkState,
  output var logic           jtag_ltsm_flagToAnalog_SendClkPatterns,
  output var logic           jtag_ltsm_flagToAnalog_RepairValState,
  output var logic           jtag_ltsm_flagToAnalog_SendValTrainPattern,
  output var logic           jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic           jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic           jtag_ltsm_flagToAnalog_RepairMbSetReceiver,
  output var logic           jtag_ltsm_flagToAnalog_LaneReversalApplied,
  output var logic           jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
  output var logic [3:0]     jtag_ltsm_state,
  output var logic           jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen,
  output var logic           jtag_ltsm_dbg_rxValidRisingEdge,
  output var logic [2:0]     jtag_ltsm_dbg_sbinitSendCount,
  output var logic           jtag_ltsm_dbg_sbTxValid,
  output var logic [127:0]   jtag_ltsm_dbg_sbTxDin,
  output var logic           jtag_ltsm_dbg_flagTrainError,
  output var logic [2:0]     jtag_ltsm_dbg_mbinitSubstate,
  output var logic [4:0]     jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount,

  // LTSM MBTRAIN.VALVREF interface.
  output var logic           jtag_ltsm_flagToAnalog_valVref_sendPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_valVref_detectedValPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_valVref_finishedPattern,
  output var logic           jtag_ltsm_flagToAnalog_valVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_valVref_rxVrefCode,
  input wire logic           jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied,
  output var logic           jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_valVref_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valVref_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valVref_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valVref_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_valVref_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_valVref_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_valVref_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_valVref_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors,
  output var logic           jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler,

  // LTSM MBTRAIN.DATAVREF interface.
  output var logic           jtag_ltsm_flagToAnalog_dataVref_sendPattern,
  input wire logic [dataLaneCount-1:0] jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_dataVref_finishedPattern,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes,
  input wire logic           jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataVref_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataVref_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_dataVref_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_dataVref_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors,
  output var logic           jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,

  // LTSM MBTRAIN.RXCLKCAL interface.
  output var logic           jtag_ltsm_flagToAnalog_rxClkCal_doCalibration,
  input wire logic           jtag_ltsm_flagFromAnalog_rxClkCal_done,
  output var logic           jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack,

  // LTSM MBTRAIN shared D2C sender/receiver and TX-deskew interface
  // (muxed inside MBTrainFSM between VALTRAINCENTER, DATATRAINCENTER1/2 and LINKSPEED).
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic            jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,

  // LTSM MBTRAIN.RXDESKEW interface.
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
  output var logic [dataLaneCount*rxDeskewCodeWidth-1:0] jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
  input wire logic           jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_rxDeskew_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_rxDeskew_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
  input wire logic [dataLaneCount-1:0] jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,

  // LTSM MBTRAIN.LINKSPEED interface.
  output var logic           jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain,
  output var logic [1:0]           jtag_ltsm_flagToAnalog_linkSpeed_speedCode,
  output var logic           jtag_ltsm_flagToAnalog_linkSpeed_applySpeed,
  output var logic           jtag_ltsm_flagToAnalog_linkSpeed_electricalIdle,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  input wire logic [1:0]    jtag_ltsm_linkSpeed_requestedSpeed,
  input wire logic     jtag_ltsm_flagFromAnalog_linkSpeed_speedApplied,
  output var logic [3:0]     jtag_ltsm_dbg_mbtrainState,
  output var logic [11:0]    jtag_ltsm_dbg_mbtrainActiveSubstate,
  output var logic [15:0]    jtag_ltsm_dbg_mbtrainLastErrorCount,
  output var logic [15:0]    jtag_ltsm_dbg_mbtrainRetryCount,

  // ==========================================================================
  // SIDEBAND PHY INTERFACE
  // Serialized pins connected to the remote die.
  // ==========================================================================
  output var logic jtag_sb_tx_dout,
  output var logic jtag_sb_tx_clk,
  input wire logic jtag_sb_rx_din,
  input wire logic jtag_sb_rx_clk,

  // Sideband receive-buffer status. Sticky until reset.
  output var logic jtag_debug_sb_rx_overflow,

  // ==========================================================================
  // FDI / RDI / LTSM / SIDEBAND INTEGRATION DEBUG
  // RDI is internal to this top, so its externally visible
  // signals are debug/status outputs rather than a separate functional port.
  // ==========================================================================
  output var logic [3:0] jtag_debug_ltsm_state,
  output var logic       jtag_debug_ltsm_inband_pres,
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t jtag_debug_fdi_link_init_state,
  output var UcieUPM_interfaces_pkg::PhyState_t      jtag_debug_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t   jtag_debug_fdi_to_rdi_state_req,
  output var logic jtag_debug_arb_grant_ltsm,
  output var logic jtag_debug_arb_grant_fdi,
  output var logic jtag_debug_arb_grant_rdi,
  output var logic jtag_debug_arb_tx_locked,
  output var logic [1:0] jtag_debug_arb_rr_last_source,
  output var logic jtag_debug_arb_rr_last_granted_rdi,
  output var logic jtag_debug_arb_tx_fire,
  output var logic jtag_debug_rx_route_ltsm,
  output var logic jtag_debug_rx_route_fdi,
  output var logic jtag_debug_rx_route_rdi,
  output var logic jtag_debug_rx_drop_unknown,
  output var logic jtag_debug_rx_fire,

  // ##########################################################################
  // JTAG FDI TDR PINS (testModeFdi = 1, all other test modes 0)
  // One pin per FDI (LinkManagementController) port, prefixed with jtagFdi_.
  // Inputs are ignored and outputs held at 0 outside FDI test.
  // ##########################################################################

  // Common clock, reset and timing.
  input wire logic        jtagFdi_clock,
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

  // RDI side (normally connected to the internal rdi).
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

  // Sideband client side (normally connected to the internal sideband).
  output var logic         jtagFdi_sb_snd_valid,
  output var logic [127:0] jtagFdi_sb_snd_msg,
  input wire logic         jtagFdi_sb_snd_ready,
  input wire logic         jtagFdi_sb_rcv_valid,
  input wire logic [127:0] jtagFdi_sb_rcv_msg,
  output var logic         jtagFdi_sb_rcv_ready,

  // ##########################################################################
  // JTAG RDI TDR PINS (testModeRdi = 1, all other test modes 0)
  // One pin per RdiLinkManagementController port, prefixed with jtagRdi_.
  // Inputs are ignored and outputs held at 0 outside this test mode.
  // ##########################################################################

  input wire logic jtagRdi_clock,
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

  // ##########################################################################
  // JTAG LTSM TDR PINS (testModeLtsm = 1, all other test modes 0)
  // One pin per LinkTrainingFSM port, prefixed with jtagLtsm_.
  // Inputs are ignored and outputs held at 0 outside this test mode.
  // ##########################################################################

  input wire logic jtagLtsm_clock,
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
  output var logic [1:0] jtagLtsm_flagToAnalog_linkSpeed_speedCode,
  output var logic jtagLtsm_flagToAnalog_linkSpeed_applySpeed,
  output var logic jtagLtsm_flagToAnalog_linkSpeed_electricalIdle,
  input wire logic [15:0] jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  input wire logic [1:0] jtagLtsm_linkSpeed_requestedSpeed,
  input wire logic  jtagLtsm_flagFromAnalog_linkSpeed_speedApplied,
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

  // --------------------------------------------------------------------------
  // Test mode select: at most one testMode* may be set (no priority logic).
  // --------------------------------------------------------------------------
`ifndef SYNTHESIS
  always @(testModeDigital or testModeFdi or testModeRdi or testModeLtsm)
    if ($countones({testModeDigital, testModeFdi, testModeRdi, testModeLtsm}) > 1)
      $error("UcieDigitalTop: several test modes set (digital=%b fdi=%b rdi=%b ltsm=%b); at most one is supported",
             testModeDigital, testModeFdi, testModeRdi, testModeLtsm);
`endif

  // --------------------------------------------------------------------------
  // Core-side nets (ports of u_core)
  // --------------------------------------------------------------------------
  logic core_clock;
  logic core_reset_n;
  UcieUPM_interfaces_pkg::PhyStateReq_t core_fdi_lp_state_req;
  logic core_fdi_lp_linkerror;
  logic core_fdi_lp_rx_active_sts;
  logic core_fdi_lp_wake_req;
  logic core_fdi_lp_clk_ack;
  logic core_fdi_lp_stall_ack;
  UcieUPM_interfaces_pkg::PhyState_t core_fdi_pl_state_sts;
  logic core_fdi_pl_rx_active_req;
  logic core_fdi_pl_inband_pres;
  logic core_fdi_pl_wake_ack;
  logic core_fdi_pl_clk_req;
  logic core_fdi_pl_stall_req;
  logic core_fdi_active;
  logic core_timeout_disable;
  logic [31:0] core_cycles_1us;
  logic core_ltsm_start;
  logic core_ltsm_stable_clk;
  logic core_ltsm_pll_locked;
  logic core_ltsm_stable_supply;
  logic core_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  logic core_ltsm_flagFromAnalog_FinishedClkPatterns;
  logic core_ltsm_flagFromAnalog_FinishedValTrainPattern;
  logic core_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  logic core_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  logic core_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  logic core_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  logic core_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  logic core_ltsm_flagFromAnalog_ValTrainPatternReceived;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  logic core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  logic core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  logic core_ltsm_flagToAnalog_RepairClkState;
  logic core_ltsm_flagToAnalog_SendClkPatterns;
  logic core_ltsm_flagToAnalog_RepairValState;
  logic core_ltsm_flagToAnalog_SendValTrainPattern;
  logic core_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  logic core_ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  logic core_ltsm_flagToAnalog_RepairMbSetReceiver;
  logic core_ltsm_flagToAnalog_LaneReversalApplied;
  logic core_ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
  logic [3:0] core_ltsm_state;
  logic core_ltsm_dbg_flagSbinitFirstClkPatternSeen;
  logic core_ltsm_dbg_rxValidRisingEdge;
  logic [2:0] core_ltsm_dbg_sbinitSendCount;
  logic core_ltsm_dbg_sbTxValid;
  logic [127:0] core_ltsm_dbg_sbTxDin;
  logic core_ltsm_dbg_flagTrainError;
  logic [2:0] core_ltsm_dbg_mbinitSubstate;
  logic [4:0] core_ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
  logic core_ltsm_flagToAnalog_valVref_sendPattern;
  logic core_ltsm_flagFromAnalog_valVref_detectedValPattern;
  logic core_ltsm_flagFromAnalog_valVref_finishedPattern;
  logic core_ltsm_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] core_ltsm_flagToAnalog_valVref_rxVrefCode;
  logic core_ltsm_flagFromAnalog_valVref_rxVrefApplied;
  logic core_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_valVref_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_valVref_burstCountSettings;
  logic core_ltsm_flagToAnalog_valVref_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_valVref_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_valVref_dataPattern;
  logic core_ltsm_flagToAnalog_valVref_clearComparisonErrors;
  logic core_ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
  logic core_ltsm_flagToAnalog_dataVref_sendPattern;
  logic [dataLaneCount-1:0] core_ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic core_ltsm_flagFromAnalog_dataVref_finishedPattern;
  logic core_ltsm_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] core_ltsm_flagToAnalog_dataVref_rxVrefCodes;
  logic core_ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  logic core_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_dataVref_burstCountSettings;
  logic core_ltsm_flagToAnalog_dataVref_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_dataVref_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_dataVref_dataPattern;
  logic core_ltsm_flagToAnalog_dataVref_clearComparisonErrors;
  logic core_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic core_ltsm_flagToAnalog_rxClkCal_doCalibration;
  logic core_ltsm_flagFromAnalog_rxClkCal_done;
  logic core_ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  logic core_ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
  logic core_ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
  logic core_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  logic core_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_d2cReceiver_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
  logic core_ltsm_flagToAnalog_d2cReceiver_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_dataPattern;
  logic core_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic core_ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic core_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic core_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic core_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic core_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic core_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] core_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic core_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  logic core_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_rxDeskew_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_rxDeskew_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_rxDeskew_burstCountSettings;
  logic core_ltsm_flagToAnalog_rxDeskew_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_rxDeskew_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_rxDeskew_dataPattern;
  logic core_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic [dataLaneCount-1:0] core_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic core_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic [1:0] core_ltsm_flagToAnalog_linkSpeed_speedCode;
  logic core_ltsm_flagToAnalog_linkSpeed_applySpeed;
  logic core_ltsm_flagToAnalog_linkSpeed_electricalIdle;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic [1:0] core_ltsm_linkSpeed_requestedSpeed;
  logic  core_ltsm_flagFromAnalog_linkSpeed_speedApplied;
  logic [3:0] core_ltsm_dbg_mbtrainState;
  logic [11:0] core_ltsm_dbg_mbtrainActiveSubstate;
  logic [15:0] core_ltsm_dbg_mbtrainLastErrorCount;
  logic [15:0] core_ltsm_dbg_mbtrainRetryCount;
  logic core_sb_tx_dout;
  logic core_sb_tx_clk;
  logic core_sb_rx_din;
  logic core_sb_rx_clk;
  logic core_debug_sb_rx_overflow;
  logic [3:0] core_debug_ltsm_state;
  logic core_debug_ltsm_inband_pres;
  UcieUPM_d2dadapter_pkg::LinkInitState_t core_debug_fdi_link_init_state;
  UcieUPM_interfaces_pkg::PhyState_t core_debug_rdi_state;
  UcieUPM_interfaces_pkg::PhyStateReq_t core_debug_fdi_to_rdi_state_req;
  logic core_debug_arb_grant_ltsm;
  logic core_debug_arb_grant_fdi;
  logic core_debug_arb_grant_rdi;
  logic core_debug_arb_tx_locked;
  logic [1:0] core_debug_arb_rr_last_source;
  logic core_debug_arb_rr_last_granted_rdi;
  logic core_debug_arb_tx_fire;
  logic core_debug_rx_route_ltsm;
  logic core_debug_rx_route_fdi;
  logic core_debug_rx_route_rdi;
  logic core_debug_rx_drop_unknown;
  logic core_debug_rx_fire;

  // --------------------------------------------------------------------------
  // Input muxes: functional pin or TDR pin -> core
  // --------------------------------------------------------------------------
  // One clock mux for the whole core (no skew between its children): in a
  // block isolation test the core clock is that block's jtag*_clock; the rest
  // of the core is held in reset.
  assign core_clock = testModeDigital ? jtag_clock     :
                      testModeFdi     ? jtagFdi_clock  :
                      testModeRdi     ? jtagRdi_clock  :
                      testModeLtsm    ? jtagLtsm_clock : clock;
  assign core_reset_n = testModeDigital ? jtag_reset_n : reset_n;
  assign core_fdi_lp_state_req = testModeDigital ? jtag_fdi_lp_state_req : fdi_lp_state_req;
  assign core_fdi_lp_linkerror = testModeDigital ? jtag_fdi_lp_linkerror : fdi_lp_linkerror;
  assign core_fdi_lp_rx_active_sts = testModeDigital ? jtag_fdi_lp_rx_active_sts : fdi_lp_rx_active_sts;
  assign core_fdi_lp_wake_req = testModeDigital ? jtag_fdi_lp_wake_req : fdi_lp_wake_req;
  assign core_fdi_lp_clk_ack = testModeDigital ? jtag_fdi_lp_clk_ack : fdi_lp_clk_ack;
  assign core_fdi_lp_stall_ack = testModeDigital ? jtag_fdi_lp_stall_ack : fdi_lp_stall_ack;
  assign core_cycles_1us = testModeDigital ? jtag_cycles_1us : cycles_1us;
  assign core_timeout_disable = testModeDigital ? jtag_timeout_disable : timeout_disable;
  assign core_ltsm_start = testModeDigital ? jtag_ltsm_start : ltsm_start;
  assign core_ltsm_stable_clk = testModeDigital ? jtag_ltsm_stable_clk : ltsm_stable_clk;
  assign core_ltsm_pll_locked = testModeDigital ? jtag_ltsm_pll_locked : ltsm_pll_locked;
  assign core_ltsm_stable_supply = testModeDigital ? jtag_ltsm_stable_supply : ltsm_stable_supply;
  assign core_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns = testModeDigital ? jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns : ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  assign core_ltsm_flagFromAnalog_FinishedClkPatterns = testModeDigital ? jtag_ltsm_flagFromAnalog_FinishedClkPatterns : ltsm_flagFromAnalog_FinishedClkPatterns;
  assign core_ltsm_flagFromAnalog_FinishedValTrainPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_FinishedValTrainPattern : ltsm_flagFromAnalog_FinishedValTrainPattern;
  assign core_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern : ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  assign core_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern : ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  assign core_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L = testModeDigital ? jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L : ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  assign core_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L = testModeDigital ? jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L : ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  assign core_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L = testModeDigital ? jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L : ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  assign core_ltsm_flagFromAnalog_ValTrainPatternReceived = testModeDigital ? jtag_ltsm_flagFromAnalog_ValTrainPatternReceived : ltsm_flagFromAnalog_ValTrainPatternReceived;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  assign core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = testModeDigital ? jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 : ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  assign core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = testModeDigital ? jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 : ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  assign core_ltsm_flagFromAnalog_valVref_detectedValPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_valVref_detectedValPattern : ltsm_flagFromAnalog_valVref_detectedValPattern;
  assign core_ltsm_flagFromAnalog_valVref_finishedPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_valVref_finishedPattern : ltsm_flagFromAnalog_valVref_finishedPattern;
  assign core_ltsm_flagFromAnalog_valVref_rxVrefApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied : ltsm_flagFromAnalog_valVref_rxVrefApplied;
  assign core_ltsm_flagFromAnalog_dataVref_detectedDataPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern : ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  assign core_ltsm_flagFromAnalog_dataVref_finishedPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_dataVref_finishedPattern : ltsm_flagFromAnalog_dataVref_finishedPattern;
  assign core_ltsm_flagFromAnalog_dataVref_rxVrefApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied : ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  assign core_ltsm_flagFromAnalog_rxClkCal_done = testModeDigital ? jtag_ltsm_flagFromAnalog_rxClkCal_done : ltsm_flagFromAnalog_rxClkCal_done;
  assign core_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent : ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  assign core_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied : ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  assign core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo : ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  assign core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload : ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  assign core_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent : ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied : ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  assign core_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent : ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied : ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  assign core_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern : ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  assign core_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful : ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  assign core_ltsm_linkSpeed_requestedSpeed = testModeDigital ? jtag_ltsm_linkSpeed_requestedSpeed : ltsm_linkSpeed_requestedSpeed;
  assign core_ltsm_flagFromAnalog_linkSpeed_speedApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_linkSpeed_speedApplied : ltsm_flagFromAnalog_linkSpeed_speedApplied;
  assign core_sb_rx_din = testModeDigital ? jtag_sb_rx_din : sb_rx_din;
  assign core_sb_rx_clk = testModeDigital ? jtag_sb_rx_clk : sb_rx_clk;

  // --------------------------------------------------------------------------
  // Output muxes: core -> functional pin or TDR pin (the unselected side is 0)
  // --------------------------------------------------------------------------
  assign fdi_pl_state_sts = testModeDigital ? UcieUPM_interfaces_pkg::PhyState_t'('0) : core_fdi_pl_state_sts;
  assign jtag_fdi_pl_state_sts = testModeDigital ? core_fdi_pl_state_sts : UcieUPM_interfaces_pkg::PhyState_t'('0);
  assign fdi_pl_rx_active_req = testModeDigital ? '0 : core_fdi_pl_rx_active_req;
  assign jtag_fdi_pl_rx_active_req = testModeDigital ? core_fdi_pl_rx_active_req : '0;
  assign fdi_pl_inband_pres = testModeDigital ? '0 : core_fdi_pl_inband_pres;
  assign jtag_fdi_pl_inband_pres = testModeDigital ? core_fdi_pl_inband_pres : '0;
  assign fdi_pl_wake_ack = testModeDigital ? '0 : core_fdi_pl_wake_ack;
  assign jtag_fdi_pl_wake_ack = testModeDigital ? core_fdi_pl_wake_ack : '0;
  assign fdi_pl_clk_req = testModeDigital ? '0 : core_fdi_pl_clk_req;
  assign jtag_fdi_pl_clk_req = testModeDigital ? core_fdi_pl_clk_req : '0;
  assign fdi_pl_stall_req = testModeDigital ? '0 : core_fdi_pl_stall_req;
  assign jtag_fdi_pl_stall_req = testModeDigital ? core_fdi_pl_stall_req : '0;
  assign fdi_active = testModeDigital ? '0 : core_fdi_active;
  assign jtag_fdi_active = testModeDigital ? core_fdi_active : '0;
  assign ltsm_flagToAnalog_RepairClkState = testModeDigital ? '0 : core_ltsm_flagToAnalog_RepairClkState;
  assign jtag_ltsm_flagToAnalog_RepairClkState = testModeDigital ? core_ltsm_flagToAnalog_RepairClkState : '0;
  assign ltsm_flagToAnalog_SendClkPatterns = testModeDigital ? '0 : core_ltsm_flagToAnalog_SendClkPatterns;
  assign jtag_ltsm_flagToAnalog_SendClkPatterns = testModeDigital ? core_ltsm_flagToAnalog_SendClkPatterns : '0;
  assign ltsm_flagToAnalog_RepairValState = testModeDigital ? '0 : core_ltsm_flagToAnalog_RepairValState;
  assign jtag_ltsm_flagToAnalog_RepairValState = testModeDigital ? core_ltsm_flagToAnalog_RepairValState : '0;
  assign ltsm_flagToAnalog_SendValTrainPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_SendValTrainPattern;
  assign jtag_ltsm_flagToAnalog_SendValTrainPattern = testModeDigital ? core_ltsm_flagToAnalog_SendValTrainPattern : '0;
  assign ltsm_flagToAnalog_ReversalMbSendLaneIDPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  assign jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern = testModeDigital ? core_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern : '0;
  assign ltsm_flagToAnalog_RepairMbSendLaneIDPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  assign jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern = testModeDigital ? core_ltsm_flagToAnalog_RepairMbSendLaneIDPattern : '0;
  assign ltsm_flagToAnalog_RepairMbSetReceiver = testModeDigital ? '0 : core_ltsm_flagToAnalog_RepairMbSetReceiver;
  assign jtag_ltsm_flagToAnalog_RepairMbSetReceiver = testModeDigital ? core_ltsm_flagToAnalog_RepairMbSetReceiver : '0;
  assign ltsm_flagToAnalog_LaneReversalApplied = testModeDigital ? '0 : core_ltsm_flagToAnalog_LaneReversalApplied;
  assign jtag_ltsm_flagToAnalog_LaneReversalApplied = testModeDigital ? core_ltsm_flagToAnalog_LaneReversalApplied : '0;
  assign ltsm_flagToAnalog_linkInit_resetLfsrScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
  assign jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler = testModeDigital ? core_ltsm_flagToAnalog_linkInit_resetLfsrScrambler : '0;
  assign ltsm_state = testModeDigital ? '0 : core_ltsm_state;
  assign jtag_ltsm_state = testModeDigital ? core_ltsm_state : '0;
  assign ltsm_dbg_flagSbinitFirstClkPatternSeen = testModeDigital ? '0 : core_ltsm_dbg_flagSbinitFirstClkPatternSeen;
  assign jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen = testModeDigital ? core_ltsm_dbg_flagSbinitFirstClkPatternSeen : '0;
  assign ltsm_dbg_rxValidRisingEdge = testModeDigital ? '0 : core_ltsm_dbg_rxValidRisingEdge;
  assign jtag_ltsm_dbg_rxValidRisingEdge = testModeDigital ? core_ltsm_dbg_rxValidRisingEdge : '0;
  assign ltsm_dbg_sbinitSendCount = testModeDigital ? '0 : core_ltsm_dbg_sbinitSendCount;
  assign jtag_ltsm_dbg_sbinitSendCount = testModeDigital ? core_ltsm_dbg_sbinitSendCount : '0;
  assign ltsm_dbg_sbTxValid = testModeDigital ? '0 : core_ltsm_dbg_sbTxValid;
  assign jtag_ltsm_dbg_sbTxValid = testModeDigital ? core_ltsm_dbg_sbTxValid : '0;
  assign ltsm_dbg_sbTxDin = testModeDigital ? '0 : core_ltsm_dbg_sbTxDin;
  assign jtag_ltsm_dbg_sbTxDin = testModeDigital ? core_ltsm_dbg_sbTxDin : '0;
  assign ltsm_dbg_flagTrainError = testModeDigital ? '0 : core_ltsm_dbg_flagTrainError;
  assign jtag_ltsm_dbg_flagTrainError = testModeDigital ? core_ltsm_dbg_flagTrainError : '0;
  assign ltsm_dbg_mbinitSubstate = testModeDigital ? '0 : core_ltsm_dbg_mbinitSubstate;
  assign jtag_ltsm_dbg_mbinitSubstate = testModeDigital ? core_ltsm_dbg_mbinitSubstate : '0;
  assign ltsm_dbg_mbinitReversalMbReceivedSuccessCount = testModeDigital ? '0 : core_ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
  assign jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount = testModeDigital ? core_ltsm_dbg_mbinitReversalMbReceivedSuccessCount : '0;
  assign ltsm_flagToAnalog_valVref_sendPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_sendPattern;
  assign jtag_ltsm_flagToAnalog_valVref_sendPattern = testModeDigital ? core_ltsm_flagToAnalog_valVref_sendPattern : '0;
  assign ltsm_flagToAnalog_valVref_applyRxVref = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_applyRxVref;
  assign jtag_ltsm_flagToAnalog_valVref_applyRxVref = testModeDigital ? core_ltsm_flagToAnalog_valVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_valVref_rxVrefCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_rxVrefCode;
  assign jtag_ltsm_flagToAnalog_valVref_rxVrefCode = testModeDigital ? core_ltsm_flagToAnalog_valVref_rxVrefCode : '0;
  assign ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_valVref_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_comparisonMode;
  assign jtag_ltsm_flagToAnalog_valVref_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_valVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_valVref_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_valVref_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_valVref_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_valVref_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_patternMode;
  assign jtag_ltsm_flagToAnalog_valVref_patternMode = testModeDigital ? core_ltsm_flagToAnalog_valVref_patternMode : '0;
  assign ltsm_flagToAnalog_valVref_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_valVref_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_valVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_valVref_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_validPattern;
  assign jtag_ltsm_flagToAnalog_valVref_validPattern = testModeDigital ? core_ltsm_flagToAnalog_valVref_validPattern : '0;
  assign ltsm_flagToAnalog_valVref_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_dataPattern;
  assign jtag_ltsm_flagToAnalog_valVref_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_valVref_dataPattern : '0;
  assign ltsm_flagToAnalog_valVref_clearComparisonErrors = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_clearComparisonErrors;
  assign jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors = testModeDigital ? core_ltsm_flagToAnalog_valVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_valVref_resetLocalTxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
  assign jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler = testModeDigital ? core_ltsm_flagToAnalog_valVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_dataVref_sendPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_sendPattern;
  assign jtag_ltsm_flagToAnalog_dataVref_sendPattern = testModeDigital ? core_ltsm_flagToAnalog_dataVref_sendPattern : '0;
  assign ltsm_flagToAnalog_dataVref_applyRxVref = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_applyRxVref;
  assign jtag_ltsm_flagToAnalog_dataVref_applyRxVref = testModeDigital ? core_ltsm_flagToAnalog_dataVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_dataVref_rxVrefCodes = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_rxVrefCodes;
  assign jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes = testModeDigital ? core_ltsm_flagToAnalog_dataVref_rxVrefCodes : '0;
  assign ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_dataVref_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_comparisonMode;
  assign jtag_ltsm_flagToAnalog_dataVref_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_dataVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_dataVref_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_dataVref_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_dataVref_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_patternMode;
  assign jtag_ltsm_flagToAnalog_dataVref_patternMode = testModeDigital ? core_ltsm_flagToAnalog_dataVref_patternMode : '0;
  assign ltsm_flagToAnalog_dataVref_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_dataVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_dataVref_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_validPattern;
  assign jtag_ltsm_flagToAnalog_dataVref_validPattern = testModeDigital ? core_ltsm_flagToAnalog_dataVref_validPattern : '0;
  assign ltsm_flagToAnalog_dataVref_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_dataPattern;
  assign jtag_ltsm_flagToAnalog_dataVref_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_dataVref_dataPattern : '0;
  assign ltsm_flagToAnalog_dataVref_clearComparisonErrors = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_clearComparisonErrors;
  assign jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors = testModeDigital ? core_ltsm_flagToAnalog_dataVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_dataVref_resetLocalTxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  assign jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler = testModeDigital ? core_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_rxClkCal_doCalibration = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxClkCal_doCalibration;
  assign jtag_ltsm_flagToAnalog_rxClkCal_doCalibration = testModeDigital ? core_ltsm_flagToAnalog_rxClkCal_doCalibration : '0;
  assign ltsm_flagToAnalog_rxClkCal_sendClockTrack = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  assign jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack = testModeDigital ? core_ltsm_flagToAnalog_rxClkCal_sendClockTrack : '0;
  assign ltsm_flagToAnalog_d2cSender_sendValTrainPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_sendValTrainPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_resetLocalScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
  assign jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_applyTxClockPhase = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
  assign jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_txClockPhaseCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
  assign jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_txClockPhaseCode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_comparisonMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_patternMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_patternMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_validPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_validPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_sendLfsrPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  assign jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew : '0;
  assign ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  assign jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes : '0;
  assign ltsm_flagToAnalog_rxDeskew_sendLfsrPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  assign jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  assign jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  assign jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew : '0;
  assign ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  assign jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes : '0;
  assign ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_rxDeskew_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_comparisonMode;
  assign jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_comparisonMode : '0;
  assign ltsm_flagToAnalog_rxDeskew_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_idleCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_burstCountSettings : '0;
  assign ltsm_flagToAnalog_rxDeskew_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_patternMode;
  assign jtag_ltsm_flagToAnalog_rxDeskew_patternMode = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_patternMode : '0;
  assign ltsm_flagToAnalog_rxDeskew_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_rxDeskew_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_validPattern;
  assign jtag_ltsm_flagToAnalog_rxDeskew_validPattern = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_validPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_dataPattern;
  assign jtag_ltsm_flagToAnalog_rxDeskew_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_dataPattern : '0;
  assign ltsm_flagToAnalog_rxDeskew_clearComparisonErrors = testModeDigital ? '0 : core_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  assign jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors = testModeDigital ? core_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors : '0;
  assign ltsm_flagToLtsm_linkSpeed_phyInRetrain = testModeDigital ? '0 : core_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  assign ltsm_flagToAnalog_linkSpeed_speedCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_linkSpeed_speedCode;
  assign ltsm_flagToAnalog_linkSpeed_applySpeed = testModeDigital ? '0 : core_ltsm_flagToAnalog_linkSpeed_applySpeed;
  assign ltsm_flagToAnalog_linkSpeed_electricalIdle = testModeDigital ? '0 : core_ltsm_flagToAnalog_linkSpeed_electricalIdle;
  assign jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain = testModeDigital ? core_ltsm_flagToLtsm_linkSpeed_phyInRetrain : '0;
  assign jtag_ltsm_flagToAnalog_linkSpeed_speedCode = testModeDigital ? core_ltsm_flagToAnalog_linkSpeed_speedCode : '0;
  assign jtag_ltsm_flagToAnalog_linkSpeed_applySpeed = testModeDigital ? core_ltsm_flagToAnalog_linkSpeed_applySpeed : '0;
  assign jtag_ltsm_flagToAnalog_linkSpeed_electricalIdle = testModeDigital ? core_ltsm_flagToAnalog_linkSpeed_electricalIdle : '0;
  assign ltsm_dbg_mbtrainState = testModeDigital ? '0 : core_ltsm_dbg_mbtrainState;
  assign jtag_ltsm_dbg_mbtrainState = testModeDigital ? core_ltsm_dbg_mbtrainState : '0;
  assign ltsm_dbg_mbtrainActiveSubstate = testModeDigital ? '0 : core_ltsm_dbg_mbtrainActiveSubstate;
  assign jtag_ltsm_dbg_mbtrainActiveSubstate = testModeDigital ? core_ltsm_dbg_mbtrainActiveSubstate : '0;
  assign ltsm_dbg_mbtrainLastErrorCount = testModeDigital ? '0 : core_ltsm_dbg_mbtrainLastErrorCount;
  assign jtag_ltsm_dbg_mbtrainLastErrorCount = testModeDigital ? core_ltsm_dbg_mbtrainLastErrorCount : '0;
  assign ltsm_dbg_mbtrainRetryCount = testModeDigital ? '0 : core_ltsm_dbg_mbtrainRetryCount;
  assign jtag_ltsm_dbg_mbtrainRetryCount = testModeDigital ? core_ltsm_dbg_mbtrainRetryCount : '0;
  assign sb_tx_dout = testModeDigital ? '0 : core_sb_tx_dout;
  assign jtag_sb_tx_dout = testModeDigital ? core_sb_tx_dout : '0;
  assign sb_tx_clk = testModeDigital ? '0 : core_sb_tx_clk;
  assign jtag_sb_tx_clk = testModeDigital ? core_sb_tx_clk : '0;
  assign debug_sb_rx_overflow = testModeDigital ? '0 : core_debug_sb_rx_overflow;
  assign jtag_debug_sb_rx_overflow = testModeDigital ? core_debug_sb_rx_overflow : '0;
  assign debug_ltsm_state = testModeDigital ? '0 : core_debug_ltsm_state;
  assign jtag_debug_ltsm_state = testModeDigital ? core_debug_ltsm_state : '0;
  assign debug_ltsm_inband_pres = testModeDigital ? '0 : core_debug_ltsm_inband_pres;
  assign jtag_debug_ltsm_inband_pres = testModeDigital ? core_debug_ltsm_inband_pres : '0;
  assign debug_fdi_link_init_state = testModeDigital ? UcieUPM_d2dadapter_pkg::LinkInitState_t'('0) : core_debug_fdi_link_init_state;
  assign jtag_debug_fdi_link_init_state = testModeDigital ? core_debug_fdi_link_init_state : UcieUPM_d2dadapter_pkg::LinkInitState_t'('0);
  assign debug_rdi_state = testModeDigital ? UcieUPM_interfaces_pkg::PhyState_t'('0) : core_debug_rdi_state;
  assign jtag_debug_rdi_state = testModeDigital ? core_debug_rdi_state : UcieUPM_interfaces_pkg::PhyState_t'('0);
  assign debug_fdi_to_rdi_state_req = testModeDigital ? UcieUPM_interfaces_pkg::PhyStateReq_t'('0) : core_debug_fdi_to_rdi_state_req;
  assign jtag_debug_fdi_to_rdi_state_req = testModeDigital ? core_debug_fdi_to_rdi_state_req : UcieUPM_interfaces_pkg::PhyStateReq_t'('0);
  assign debug_arb_grant_ltsm = testModeDigital ? '0 : core_debug_arb_grant_ltsm;
  assign jtag_debug_arb_grant_ltsm = testModeDigital ? core_debug_arb_grant_ltsm : '0;
  assign debug_arb_grant_fdi = testModeDigital ? '0 : core_debug_arb_grant_fdi;
  assign jtag_debug_arb_grant_fdi = testModeDigital ? core_debug_arb_grant_fdi : '0;
  assign debug_arb_grant_rdi = testModeDigital ? '0 : core_debug_arb_grant_rdi;
  assign jtag_debug_arb_grant_rdi = testModeDigital ? core_debug_arb_grant_rdi : '0;
  assign debug_arb_tx_locked = testModeDigital ? '0 : core_debug_arb_tx_locked;
  assign jtag_debug_arb_tx_locked = testModeDigital ? core_debug_arb_tx_locked : '0;
  assign debug_arb_rr_last_source = testModeDigital ? '0 : core_debug_arb_rr_last_source;
  assign jtag_debug_arb_rr_last_source = testModeDigital ? core_debug_arb_rr_last_source : '0;
  assign debug_arb_rr_last_granted_rdi = testModeDigital ? '0 : core_debug_arb_rr_last_granted_rdi;
  assign jtag_debug_arb_rr_last_granted_rdi = testModeDigital ? core_debug_arb_rr_last_granted_rdi : '0;
  assign debug_arb_tx_fire = testModeDigital ? '0 : core_debug_arb_tx_fire;
  assign jtag_debug_arb_tx_fire = testModeDigital ? core_debug_arb_tx_fire : '0;
  assign debug_rx_route_ltsm = testModeDigital ? '0 : core_debug_rx_route_ltsm;
  assign jtag_debug_rx_route_ltsm = testModeDigital ? core_debug_rx_route_ltsm : '0;
  assign debug_rx_route_fdi = testModeDigital ? '0 : core_debug_rx_route_fdi;
  assign jtag_debug_rx_route_fdi = testModeDigital ? core_debug_rx_route_fdi : '0;
  assign debug_rx_route_rdi = testModeDigital ? '0 : core_debug_rx_route_rdi;
  assign jtag_debug_rx_route_rdi = testModeDigital ? core_debug_rx_route_rdi : '0;
  assign debug_rx_drop_unknown = testModeDigital ? '0 : core_debug_rx_drop_unknown;
  assign jtag_debug_rx_drop_unknown = testModeDigital ? core_debug_rx_drop_unknown : '0;
  assign debug_rx_fire = testModeDigital ? '0 : core_debug_rx_fire;
  assign jtag_debug_rx_fire = testModeDigital ? core_debug_rx_fire : '0;

  // --------------------------------------------------------------------------
  // Core top
  // --------------------------------------------------------------------------
  UcieDigitalCore #(
    .FDI_WIDTH                                (FDI_WIDTH),
    .FDI_DLLP_WIDTH                           (FDI_DLLP_WIDTH),
    .FDI_SB_WIDTH                             (FDI_SB_WIDTH),
    .RDI_WIDTH                                (RDI_WIDTH),
    .RDI_SB_WIDTH                             (RDI_SB_WIDTH),
    .SB_NODE_MSG_WIDTH                        (SB_NODE_MSG_WIDTH),
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
    .rxDeskewMaxTrainingRetries               (rxDeskewMaxTrainingRetries),
    .SB_TX_FIFO_ENTRIES                       (SB_TX_FIFO_ENTRIES)
  ) u_core (
    .clock                                                                          (core_clock),
    .reset_n                                                                        (core_reset_n),
    .fdi_lp_state_req                                                               (core_fdi_lp_state_req),
    .fdi_lp_linkerror                                                               (core_fdi_lp_linkerror),
    .fdi_lp_rx_active_sts                                                           (core_fdi_lp_rx_active_sts),
    .fdi_lp_wake_req                                                                (core_fdi_lp_wake_req),
    .fdi_lp_clk_ack                                                                 (core_fdi_lp_clk_ack),
    .fdi_lp_stall_ack                                                               (core_fdi_lp_stall_ack),
    .fdi_pl_state_sts                                                               (core_fdi_pl_state_sts),
    .fdi_pl_rx_active_req                                                           (core_fdi_pl_rx_active_req),
    .fdi_pl_inband_pres                                                             (core_fdi_pl_inband_pres),
    .fdi_pl_wake_ack                                                                (core_fdi_pl_wake_ack),
    .fdi_pl_clk_req                                                                 (core_fdi_pl_clk_req),
    .fdi_pl_stall_req                                                               (core_fdi_pl_stall_req),
    .fdi_active                                                                     (core_fdi_active),
    .timeout_disable                                                                (core_timeout_disable),
    .cycles_1us                                                                     (core_cycles_1us),
    .ltsm_start                                                                     (core_ltsm_start),
    .ltsm_stable_clk                                                                (core_ltsm_stable_clk),
    .ltsm_pll_locked                                                                (core_ltsm_pll_locked),
    .ltsm_stable_supply                                                             (core_ltsm_stable_supply),
    .ltsm_flagFromAnalog_ReadyToExchangeClkPatterns                                 (core_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
    .ltsm_flagFromAnalog_FinishedClkPatterns                                        (core_ltsm_flagFromAnalog_FinishedClkPatterns),
    .ltsm_flagFromAnalog_FinishedValTrainPattern                                    (core_ltsm_flagFromAnalog_FinishedValTrainPattern),
    .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                            (core_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                              (core_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .ltsm_flagFromAnalog_clkPatternReceivedRTRK_L                                   (core_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKN_L                                   (core_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKP_L                                   (core_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
    .ltsm_flagFromAnalog_ValTrainPatternReceived                                    (core_ltsm_flagFromAnalog_ValTrainPatternReceived),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9                            (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15                           (core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                             (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                            (core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .ltsm_flagToAnalog_RepairClkState                                               (core_ltsm_flagToAnalog_RepairClkState),
    .ltsm_flagToAnalog_SendClkPatterns                                              (core_ltsm_flagToAnalog_SendClkPatterns),
    .ltsm_flagToAnalog_RepairValState                                               (core_ltsm_flagToAnalog_RepairValState),
    .ltsm_flagToAnalog_SendValTrainPattern                                          (core_ltsm_flagToAnalog_SendValTrainPattern),
    .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern                                  (core_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSendLaneIDPattern                                    (core_ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSetReceiver                                          (core_ltsm_flagToAnalog_RepairMbSetReceiver),
    .ltsm_flagToAnalog_LaneReversalApplied                                          (core_ltsm_flagToAnalog_LaneReversalApplied),
    .ltsm_flagToAnalog_linkInit_resetLfsrScrambler                                  (core_ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .ltsm_state                                                                     (core_ltsm_state),
    .ltsm_dbg_flagSbinitFirstClkPatternSeen                                         (core_ltsm_dbg_flagSbinitFirstClkPatternSeen),
    .ltsm_dbg_rxValidRisingEdge                                                     (core_ltsm_dbg_rxValidRisingEdge),
    .ltsm_dbg_sbinitSendCount                                                       (core_ltsm_dbg_sbinitSendCount),
    .ltsm_dbg_sbTxValid                                                             (core_ltsm_dbg_sbTxValid),
    .ltsm_dbg_sbTxDin                                                               (core_ltsm_dbg_sbTxDin),
    .ltsm_dbg_flagTrainError                                                        (core_ltsm_dbg_flagTrainError),
    .ltsm_dbg_mbinitSubstate                                                        (core_ltsm_dbg_mbinitSubstate),
    .ltsm_dbg_mbinitReversalMbReceivedSuccessCount                                  (core_ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
    .ltsm_flagToAnalog_valVref_sendPattern                                          (core_ltsm_flagToAnalog_valVref_sendPattern),
    .ltsm_flagFromAnalog_valVref_detectedValPattern                                 (core_ltsm_flagFromAnalog_valVref_detectedValPattern),
    .ltsm_flagFromAnalog_valVref_finishedPattern                                    (core_ltsm_flagFromAnalog_valVref_finishedPattern),
    .ltsm_flagToAnalog_valVref_applyRxVref                                          (core_ltsm_flagToAnalog_valVref_applyRxVref),
    .ltsm_flagToAnalog_valVref_rxVrefCode                                           (core_ltsm_flagToAnalog_valVref_rxVrefCode),
    .ltsm_flagFromAnalog_valVref_rxVrefApplied                                      (core_ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest                          (core_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                      (core_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_valVref_comparisonMode                                       (core_ltsm_flagToAnalog_valVref_comparisonMode),
    .ltsm_flagToAnalog_valVref_iterationCountSettings                               (core_ltsm_flagToAnalog_valVref_iterationCountSettings),
    .ltsm_flagToAnalog_valVref_idleCountSettings                                    (core_ltsm_flagToAnalog_valVref_idleCountSettings),
    .ltsm_flagToAnalog_valVref_burstCountSettings                                   (core_ltsm_flagToAnalog_valVref_burstCountSettings),
    .ltsm_flagToAnalog_valVref_patternMode                                          (core_ltsm_flagToAnalog_valVref_patternMode),
    .ltsm_flagToAnalog_valVref_clockPhaseControl                                    (core_ltsm_flagToAnalog_valVref_clockPhaseControl),
    .ltsm_flagToAnalog_valVref_validPattern                                         (core_ltsm_flagToAnalog_valVref_validPattern),
    .ltsm_flagToAnalog_valVref_dataPattern                                          (core_ltsm_flagToAnalog_valVref_dataPattern),
    .ltsm_flagToAnalog_valVref_clearComparisonErrors                                (core_ltsm_flagToAnalog_valVref_clearComparisonErrors),
    .ltsm_flagToAnalog_valVref_resetLocalTxScrambler                                (core_ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_dataVref_sendPattern                                         (core_ltsm_flagToAnalog_dataVref_sendPattern),
    .ltsm_flagFromAnalog_dataVref_detectedDataPattern                               (core_ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataVref_finishedPattern                                   (core_ltsm_flagFromAnalog_dataVref_finishedPattern),
    .ltsm_flagToAnalog_dataVref_applyRxVref                                         (core_ltsm_flagToAnalog_dataVref_applyRxVref),
    .ltsm_flagToAnalog_dataVref_rxVrefCodes                                         (core_ltsm_flagToAnalog_dataVref_rxVrefCodes),
    .ltsm_flagFromAnalog_dataVref_rxVrefApplied                                     (core_ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                         (core_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (core_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_dataVref_comparisonMode                                      (core_ltsm_flagToAnalog_dataVref_comparisonMode),
    .ltsm_flagToAnalog_dataVref_iterationCountSettings                              (core_ltsm_flagToAnalog_dataVref_iterationCountSettings),
    .ltsm_flagToAnalog_dataVref_idleCountSettings                                   (core_ltsm_flagToAnalog_dataVref_idleCountSettings),
    .ltsm_flagToAnalog_dataVref_burstCountSettings                                  (core_ltsm_flagToAnalog_dataVref_burstCountSettings),
    .ltsm_flagToAnalog_dataVref_patternMode                                         (core_ltsm_flagToAnalog_dataVref_patternMode),
    .ltsm_flagToAnalog_dataVref_clockPhaseControl                                   (core_ltsm_flagToAnalog_dataVref_clockPhaseControl),
    .ltsm_flagToAnalog_dataVref_validPattern                                        (core_ltsm_flagToAnalog_dataVref_validPattern),
    .ltsm_flagToAnalog_dataVref_dataPattern                                         (core_ltsm_flagToAnalog_dataVref_dataPattern),
    .ltsm_flagToAnalog_dataVref_clearComparisonErrors                               (core_ltsm_flagToAnalog_dataVref_clearComparisonErrors),
    .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler                               (core_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxClkCal_doCalibration                                       (core_ltsm_flagToAnalog_rxClkCal_doCalibration),
    .ltsm_flagFromAnalog_rxClkCal_done                                              (core_ltsm_flagFromAnalog_rxClkCal_done),
    .ltsm_flagToAnalog_rxClkCal_sendClockTrack                                      (core_ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .ltsm_flagToAnalog_d2cSender_sendValTrainPattern                                (core_ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent                              (core_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .ltsm_flagToAnalog_d2cSender_resetLocalScrambler                                (core_ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_applyTxClockPhase                                  (core_ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_txClockPhaseCode                                   (core_ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied                              (core_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                      (core_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold                  (core_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_comparisonMode                                   (core_ltsm_flagToAnalog_d2cReceiver_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_iterationCountSettings                           (core_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_idleCountSettings                                (core_ltsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_burstCountSettings                               (core_ltsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_patternMode                                      (core_ltsm_flagToAnalog_d2cReceiver_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_clockPhaseControl                                (core_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_validPattern                                     (core_ltsm_flagToAnalog_d2cReceiver_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataPattern                                      (core_ltsm_flagToAnalog_d2cReceiver_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                            (core_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                        (core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                        (core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_d2cSender_sendLfsrPattern                                    (core_ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent                                  (core_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew                                  (core_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes                                  (core_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                              (core_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern                                     (core_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                   (core_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                               (core_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                   (core_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                   (core_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                               (core_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                         (core_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                     (core_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_rxDeskew_comparisonMode                                      (core_ltsm_flagToAnalog_rxDeskew_comparisonMode),
    .ltsm_flagToAnalog_rxDeskew_iterationCountSettings                              (core_ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .ltsm_flagToAnalog_rxDeskew_idleCountSettings                                   (core_ltsm_flagToAnalog_rxDeskew_idleCountSettings),
    .ltsm_flagToAnalog_rxDeskew_burstCountSettings                                  (core_ltsm_flagToAnalog_rxDeskew_burstCountSettings),
    .ltsm_flagToAnalog_rxDeskew_patternMode                                         (core_ltsm_flagToAnalog_rxDeskew_patternMode),
    .ltsm_flagToAnalog_rxDeskew_clockPhaseControl                                   (core_ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .ltsm_flagToAnalog_rxDeskew_validPattern                                        (core_ltsm_flagToAnalog_rxDeskew_validPattern),
    .ltsm_flagToAnalog_rxDeskew_dataPattern                                         (core_ltsm_flagToAnalog_rxDeskew_dataPattern),
    .ltsm_flagToAnalog_rxDeskew_clearComparisonErrors                               (core_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern                               (core_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .ltsm_flagToLtsm_linkSpeed_phyInRetrain                                         (core_ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .ltsm_flagToAnalog_linkSpeed_speedCode                                         (core_ltsm_flagToAnalog_linkSpeed_speedCode),
    .ltsm_flagToAnalog_linkSpeed_applySpeed                                         (core_ltsm_flagToAnalog_linkSpeed_applySpeed),
    .ltsm_flagToAnalog_linkSpeed_electricalIdle                                         (core_ltsm_flagToAnalog_linkSpeed_electricalIdle),
    .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                       (core_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .ltsm_linkSpeed_requestedSpeed                       (core_ltsm_linkSpeed_requestedSpeed),
    .ltsm_flagFromAnalog_linkSpeed_speedApplied                       (core_ltsm_flagFromAnalog_linkSpeed_speedApplied),
    .ltsm_dbg_mbtrainState                                                          (core_ltsm_dbg_mbtrainState),
    .ltsm_dbg_mbtrainActiveSubstate                                                 (core_ltsm_dbg_mbtrainActiveSubstate),
    .ltsm_dbg_mbtrainLastErrorCount                                                 (core_ltsm_dbg_mbtrainLastErrorCount),
    .ltsm_dbg_mbtrainRetryCount                                                     (core_ltsm_dbg_mbtrainRetryCount),
    .sb_tx_dout                                                                     (core_sb_tx_dout),
    .sb_tx_clk                                                                      (core_sb_tx_clk),
    .sb_rx_din                                                                      (core_sb_rx_din),
    .sb_rx_clk                                                                      (core_sb_rx_clk),
    .debug_sb_rx_overflow                                                           (core_debug_sb_rx_overflow),
    .debug_ltsm_state                                                               (core_debug_ltsm_state),
    .debug_ltsm_inband_pres                                                         (core_debug_ltsm_inband_pres),
    .debug_fdi_link_init_state                                                      (core_debug_fdi_link_init_state),
    .debug_rdi_state                                                                (core_debug_rdi_state),
    .debug_fdi_to_rdi_state_req                                                     (core_debug_fdi_to_rdi_state_req),
    .debug_arb_grant_ltsm                                                           (core_debug_arb_grant_ltsm),
    .debug_arb_grant_fdi                                                            (core_debug_arb_grant_fdi),
    .debug_arb_grant_rdi                                                            (core_debug_arb_grant_rdi),
    .debug_arb_tx_locked                                                            (core_debug_arb_tx_locked),
    .debug_arb_rr_last_source                                                       (core_debug_arb_rr_last_source),
    .debug_arb_rr_last_granted_rdi                                                  (core_debug_arb_rr_last_granted_rdi),
    .debug_arb_tx_fire                                                              (core_debug_arb_tx_fire),
    .debug_rx_route_ltsm                                                            (core_debug_rx_route_ltsm),
    .debug_rx_route_fdi                                                             (core_debug_rx_route_fdi),
    .debug_rx_route_rdi                                                             (core_debug_rx_route_rdi),
    .debug_rx_drop_unknown                                                          (core_debug_rx_drop_unknown),
    .debug_rx_fire                                                                  (core_debug_rx_fire),

    // FDI isolation test: straight through, muxed inside the core.
    .testModeFdi                                                                    (testModeFdi),
    .jtagFdi_reset_n                                                                (jtagFdi_reset_n),
    .jtagFdi_cycles_1us                                                             (jtagFdi_cycles_1us),
    .jtagFdi_timeout_disable                                                        (jtagFdi_timeout_disable),
    .jtagFdi_fdi_lp_state_req                                                       (jtagFdi_fdi_lp_state_req),
    .jtagFdi_fdi_lp_linkerror                                                       (jtagFdi_fdi_lp_linkerror),
    .jtagFdi_fdi_lp_rx_active_sts                                                   (jtagFdi_fdi_lp_rx_active_sts),
    .jtagFdi_fdi_lp_wake_req                                                        (jtagFdi_fdi_lp_wake_req),
    .jtagFdi_fdi_lp_clk_ack                                                         (jtagFdi_fdi_lp_clk_ack),
    .jtagFdi_fdi_lp_stall_ack                                                       (jtagFdi_fdi_lp_stall_ack),
    .jtagFdi_fdi_pl_state_sts                                                       (jtagFdi_fdi_pl_state_sts),
    .jtagFdi_fdi_pl_rx_active_req                                                   (jtagFdi_fdi_pl_rx_active_req),
    .jtagFdi_fdi_pl_inband_pres                                                     (jtagFdi_fdi_pl_inband_pres),
    .jtagFdi_fdi_pl_wake_ack                                                        (jtagFdi_fdi_pl_wake_ack),
    .jtagFdi_fdi_pl_clk_req                                                         (jtagFdi_fdi_pl_clk_req),
    .jtagFdi_fdi_pl_stall_req                                                       (jtagFdi_fdi_pl_stall_req),
    .jtagFdi_fdi_active                                                             (jtagFdi_fdi_active),
    .jtagFdi_debug_link_init_state                                                  (jtagFdi_debug_link_init_state),
    .jtagFdi_rdi_lp_linkerror                                                       (jtagFdi_rdi_lp_linkerror),
    .jtagFdi_rdi_lp_state_req                                                       (jtagFdi_rdi_lp_state_req),
    .jtagFdi_rdi_pl_state_sts                                                       (jtagFdi_rdi_pl_state_sts),
    .jtagFdi_rdi_pl_inband_pres                                                     (jtagFdi_rdi_pl_inband_pres),
    .jtagFdi_fdiNeedsRdiAwake                                                       (jtagFdi_fdiNeedsRdiAwake),
    .jtagFdi_rdiAwake                                                               (jtagFdi_rdiAwake),
    .jtagFdi_rdiNeedsFdiAwake                                                       (jtagFdi_rdiNeedsFdiAwake),
    .jtagFdi_fdiAwake                                                               (jtagFdi_fdiAwake),
    .jtagFdi_rdi_pl_stall_req                                                       (jtagFdi_rdi_pl_stall_req),
    .jtagFdi_rdi_lp_stall_ack                                                       (jtagFdi_rdi_lp_stall_ack),
    .jtagFdi_sb_snd_valid                                                           (jtagFdi_sb_snd_valid),
    .jtagFdi_sb_snd_msg                                                             (jtagFdi_sb_snd_msg),
    .jtagFdi_sb_snd_ready                                                           (jtagFdi_sb_snd_ready),
    .jtagFdi_sb_rcv_valid                                                           (jtagFdi_sb_rcv_valid),
    .jtagFdi_sb_rcv_msg                                                             (jtagFdi_sb_rcv_msg),
    .jtagFdi_sb_rcv_ready                                                           (jtagFdi_sb_rcv_ready),

    // RDI isolation test: straight through, muxed inside the core.
    .testModeRdi                                                                     (testModeRdi),
    .jtagRdi_reset_n                                                                 (jtagRdi_reset_n),
    .jtagRdi_ltsm_lp_wake_req                                                        (jtagRdi_ltsm_lp_wake_req),
    .jtagRdi_ltsm_pl_wake_ack                                                        (jtagRdi_ltsm_pl_wake_ack),
    .jtagRdi_ltsm_pl_clk_req                                                         (jtagRdi_ltsm_pl_clk_req),
    .jtagRdi_ltsm_lp_clk_ack                                                         (jtagRdi_ltsm_lp_clk_ack),
    .jtagRdi_lp_state_req                                                            (jtagRdi_lp_state_req),
    .jtagRdi_pl_state_sts                                                            (jtagRdi_pl_state_sts),
    .jtagRdi_pl_stallreq                                                             (jtagRdi_pl_stallreq),
    .jtagRdi_lp_stallack                                                             (jtagRdi_lp_stallack),
    .jtagRdi_rdi_pl_inband_pres                                                      (jtagRdi_rdi_pl_inband_pres),
    .jtagRdi_ltsm_pl_inband_pres                                                     (jtagRdi_ltsm_pl_inband_pres),
    .jtagRdi_fdiNeedsRdiAwake                                                        (jtagRdi_fdiNeedsRdiAwake),
    .jtagRdi_rdiAwake                                                                (jtagRdi_rdiAwake),
    .jtagRdi_rdiNeedsFdiAwake                                                        (jtagRdi_rdiNeedsFdiAwake),
    .jtagRdi_fdiAwake                                                                (jtagRdi_fdiAwake),
    .jtagRdi_sb_snd_valid                                                            (jtagRdi_sb_snd_valid),
    .jtagRdi_sb_snd_msg                                                              (jtagRdi_sb_snd_msg),
    .jtagRdi_sb_snd_ready                                                            (jtagRdi_sb_snd_ready),
    .jtagRdi_sb_rcv_valid                                                            (jtagRdi_sb_rcv_valid),
    .jtagRdi_sb_rcv_msg                                                              (jtagRdi_sb_rcv_msg),
    .jtagRdi_sb_rcv_ready                                                            (jtagRdi_sb_rcv_ready),
    .jtagRdi_lp_linkerror                                                            (jtagRdi_lp_linkerror),
    .jtagRdi_pl_phyinrecenter                                                        (jtagRdi_pl_phyinrecenter),
    .jtagRdi_timeout_disable                                                         (jtagRdi_timeout_disable),
    .jtagRdi_cycles_1us                                                              (jtagRdi_cycles_1us),

    // LTSM isolation test: straight through, muxed inside the core.
    .testModeLtsm                                                                    (testModeLtsm),
    .jtagLtsm_reset_n                                                                (jtagLtsm_reset_n),
    .jtagLtsm_sb_tx_din                                                              (jtagLtsm_sb_tx_din),
    .jtagLtsm_sb_tx_valid                                                            (jtagLtsm_sb_tx_valid),
    .jtagLtsm_sb_tx_ready                                                            (jtagLtsm_sb_tx_ready),
    .jtagLtsm_sb_rx_dout                                                             (jtagLtsm_sb_rx_dout),
    .jtagLtsm_sb_rx_valid                                                            (jtagLtsm_sb_rx_valid),
    .jtagLtsm_start                                                                  (jtagLtsm_start),
    .jtagLtsm_stable_clk                                                             (jtagLtsm_stable_clk),
    .jtagLtsm_pll_locked                                                             (jtagLtsm_pll_locked),
    .jtagLtsm_stable_supply                                                          (jtagLtsm_stable_supply),
    .jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns                              (jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns),
    .jtagLtsm_flagFromAnalog_FinishedClkPatterns                                     (jtagLtsm_flagFromAnalog_FinishedClkPatterns),
    .jtagLtsm_flagFromAnalog_FinishedValTrainPattern                                 (jtagLtsm_flagFromAnalog_FinishedValTrainPattern),
    .jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                         (jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                           (jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L                                (jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L                                (jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L                                (jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L),
    .jtagLtsm_flagFromAnalog_ValTrainPatternReceived                                 (jtagLtsm_flagFromAnalog_ValTrainPatternReceived),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9                         (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15                        (jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                          (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                         (jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .jtagLtsm_flagToAnalog_RepairClkState                                            (jtagLtsm_flagToAnalog_RepairClkState),
    .jtagLtsm_flagToAnalog_SendClkPatterns                                           (jtagLtsm_flagToAnalog_SendClkPatterns),
    .jtagLtsm_flagToAnalog_RepairValState                                            (jtagLtsm_flagToAnalog_RepairValState),
    .jtagLtsm_flagToAnalog_SendValTrainPattern                                       (jtagLtsm_flagToAnalog_SendValTrainPattern),
    .jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern                               (jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern                                 (jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .jtagLtsm_flagToAnalog_RepairMbSetReceiver                                       (jtagLtsm_flagToAnalog_RepairMbSetReceiver),
    .jtagLtsm_flagToAnalog_LaneReversalApplied                                       (jtagLtsm_flagToAnalog_LaneReversalApplied),
    .jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler                               (jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .jtagLtsm_state                                                                  (jtagLtsm_state),
    .jtagLtsm_dbg_flagSbinitFirstClkPatternSeen                                      (jtagLtsm_dbg_flagSbinitFirstClkPatternSeen),
    .jtagLtsm_dbg_rxValidRisingEdge                                                  (jtagLtsm_dbg_rxValidRisingEdge),
    .jtagLtsm_dbg_sbinitSendCount                                                    (jtagLtsm_dbg_sbinitSendCount),
    .jtagLtsm_dbg_sbTxValid                                                          (jtagLtsm_dbg_sbTxValid),
    .jtagLtsm_dbg_sbTxDin                                                            (jtagLtsm_dbg_sbTxDin),
    .jtagLtsm_dbg_flagTrainError                                                     (jtagLtsm_dbg_flagTrainError),
    .jtagLtsm_dbg_mbinitSubstate                                                     (jtagLtsm_dbg_mbinitSubstate),
    .jtagLtsm_dbg_mbinitParamSenderState                                             (jtagLtsm_dbg_mbinitParamSenderState),
    .jtagLtsm_dbg_mbinitParamReceiverState                                           (jtagLtsm_dbg_mbinitParamReceiverState),
    .jtagLtsm_dbg_mbinitCalSenderState                                               (jtagLtsm_dbg_mbinitCalSenderState),
    .jtagLtsm_dbg_mbinitCalReceiverState                                             (jtagLtsm_dbg_mbinitCalReceiverState),
    .jtagLtsm_dbg_mbinitRepairClkSenderState                                         (jtagLtsm_dbg_mbinitRepairClkSenderState),
    .jtagLtsm_dbg_mbinitRepairClkReceiverState                                       (jtagLtsm_dbg_mbinitRepairClkReceiverState),
    .jtagLtsm_dbg_mbinitRepairValSenderState                                         (jtagLtsm_dbg_mbinitRepairValSenderState),
    .jtagLtsm_dbg_mbinitRepairValReceiverState                                       (jtagLtsm_dbg_mbinitRepairValReceiverState),
    .jtagLtsm_dbg_mbinitReversalMbSenderState                                        (jtagLtsm_dbg_mbinitReversalMbSenderState),
    .jtagLtsm_dbg_mbinitReversalMbReceiverState                                      (jtagLtsm_dbg_mbinitReversalMbReceiverState),
    .jtagLtsm_dbg_mbinitRepairMbSenderState                                          (jtagLtsm_dbg_mbinitRepairMbSenderState),
    .jtagLtsm_dbg_mbinitRepairMbReceiverState                                        (jtagLtsm_dbg_mbinitRepairMbReceiverState),
    .jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount                               (jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount),
    .jtagLtsm_flagToAnalog_valVref_sendPattern                                       (jtagLtsm_flagToAnalog_valVref_sendPattern),
    .jtagLtsm_flagFromAnalog_valVref_detectedValPattern                              (jtagLtsm_flagFromAnalog_valVref_detectedValPattern),
    .jtagLtsm_flagFromAnalog_valVref_finishedPattern                                 (jtagLtsm_flagFromAnalog_valVref_finishedPattern),
    .jtagLtsm_flagToAnalog_valVref_applyRxVref                                       (jtagLtsm_flagToAnalog_valVref_applyRxVref),
    .jtagLtsm_flagToAnalog_valVref_rxVrefCode                                        (jtagLtsm_flagToAnalog_valVref_rxVrefCode),
    .jtagLtsm_flagFromAnalog_valVref_rxVrefApplied                                   (jtagLtsm_flagFromAnalog_valVref_rxVrefApplied),
    .jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest                       (jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                   (jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_valVref_comparisonMode                                    (jtagLtsm_flagToAnalog_valVref_comparisonMode),
    .jtagLtsm_flagToAnalog_valVref_iterationCountSettings                            (jtagLtsm_flagToAnalog_valVref_iterationCountSettings),
    .jtagLtsm_flagToAnalog_valVref_idleCountSettings                                 (jtagLtsm_flagToAnalog_valVref_idleCountSettings),
    .jtagLtsm_flagToAnalog_valVref_burstCountSettings                                (jtagLtsm_flagToAnalog_valVref_burstCountSettings),
    .jtagLtsm_flagToAnalog_valVref_patternMode                                       (jtagLtsm_flagToAnalog_valVref_patternMode),
    .jtagLtsm_flagToAnalog_valVref_clockPhaseControl                                 (jtagLtsm_flagToAnalog_valVref_clockPhaseControl),
    .jtagLtsm_flagToAnalog_valVref_validPattern                                      (jtagLtsm_flagToAnalog_valVref_validPattern),
    .jtagLtsm_flagToAnalog_valVref_dataPattern                                       (jtagLtsm_flagToAnalog_valVref_dataPattern),
    .jtagLtsm_flagToAnalog_valVref_clearComparisonErrors                             (jtagLtsm_flagToAnalog_valVref_clearComparisonErrors),
    .jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler                             (jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_dataVref_sendPattern                                      (jtagLtsm_flagToAnalog_dataVref_sendPattern),
    .jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern                            (jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern),
    .jtagLtsm_flagFromAnalog_dataVref_finishedPattern                                (jtagLtsm_flagFromAnalog_dataVref_finishedPattern),
    .jtagLtsm_flagToAnalog_dataVref_applyRxVref                                      (jtagLtsm_flagToAnalog_dataVref_applyRxVref),
    .jtagLtsm_flagToAnalog_dataVref_rxVrefCodes                                      (jtagLtsm_flagToAnalog_dataVref_rxVrefCodes),
    .jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied                                  (jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied),
    .jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                      (jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                  (jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_dataVref_comparisonMode                                   (jtagLtsm_flagToAnalog_dataVref_comparisonMode),
    .jtagLtsm_flagToAnalog_dataVref_iterationCountSettings                           (jtagLtsm_flagToAnalog_dataVref_iterationCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_idleCountSettings                                (jtagLtsm_flagToAnalog_dataVref_idleCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_burstCountSettings                               (jtagLtsm_flagToAnalog_dataVref_burstCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_patternMode                                      (jtagLtsm_flagToAnalog_dataVref_patternMode),
    .jtagLtsm_flagToAnalog_dataVref_clockPhaseControl                                (jtagLtsm_flagToAnalog_dataVref_clockPhaseControl),
    .jtagLtsm_flagToAnalog_dataVref_validPattern                                     (jtagLtsm_flagToAnalog_dataVref_validPattern),
    .jtagLtsm_flagToAnalog_dataVref_dataPattern                                      (jtagLtsm_flagToAnalog_dataVref_dataPattern),
    .jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors                            (jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors),
    .jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler                            (jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_rxClkCal_doCalibration                                    (jtagLtsm_flagToAnalog_rxClkCal_doCalibration),
    .jtagLtsm_flagFromAnalog_rxClkCal_done                                           (jtagLtsm_flagFromAnalog_rxClkCal_done),
    .jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack                                   (jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack),
    .jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern                             (jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent                           (jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler                             (jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase                               (jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode                                (jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied                           (jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                   (jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold               (jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode                                (jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode),
    .jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings                        (jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings                             (jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings                            (jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_patternMode                                   (jtagLtsm_flagToAnalog_d2cReceiver_patternMode),
    .jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl                             (jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .jtagLtsm_flagToAnalog_d2cReceiver_validPattern                                  (jtagLtsm_flagToAnalog_d2cReceiver_validPattern),
    .jtagLtsm_flagToAnalog_d2cReceiver_dataPattern                                   (jtagLtsm_flagToAnalog_d2cReceiver_dataPattern),
    .jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                         (jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                     (jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                     (jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern                                 (jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent                               (jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew                               (jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes                               (jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                           (jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern                                  (jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                (jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                            (jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                (jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                (jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                            (jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                      (jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                  (jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_rxDeskew_comparisonMode                                   (jtagLtsm_flagToAnalog_rxDeskew_comparisonMode),
    .jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings                           (jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings                                (jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings                               (jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_patternMode                                      (jtagLtsm_flagToAnalog_rxDeskew_patternMode),
    .jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl                                (jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .jtagLtsm_flagToAnalog_rxDeskew_validPattern                                     (jtagLtsm_flagToAnalog_rxDeskew_validPattern),
    .jtagLtsm_flagToAnalog_rxDeskew_dataPattern                                      (jtagLtsm_flagToAnalog_rxDeskew_dataPattern),
    .jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors                            (jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern                            (jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain                                      (jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain),
    .jtagLtsm_flagToAnalog_linkSpeed_speedCode                                      (jtagLtsm_flagToAnalog_linkSpeed_speedCode),
    .jtagLtsm_flagToAnalog_linkSpeed_applySpeed                                      (jtagLtsm_flagToAnalog_linkSpeed_applySpeed),
    .jtagLtsm_flagToAnalog_linkSpeed_electricalIdle                                      (jtagLtsm_flagToAnalog_linkSpeed_electricalIdle),
    .jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                    (jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .jtagLtsm_linkSpeed_requestedSpeed                    (jtagLtsm_linkSpeed_requestedSpeed),
    .jtagLtsm_flagFromAnalog_linkSpeed_speedApplied                    (jtagLtsm_flagFromAnalog_linkSpeed_speedApplied),
    .jtagLtsm_dbg_mbtrainState                                                       (jtagLtsm_dbg_mbtrainState),
    .jtagLtsm_dbg_mbtrainActiveSubstate                                              (jtagLtsm_dbg_mbtrainActiveSubstate),
    .jtagLtsm_dbg_mbtrainValVrefLocalState                                           (jtagLtsm_dbg_mbtrainValVrefLocalState),
    .jtagLtsm_dbg_mbtrainValVrefRemoteState                                          (jtagLtsm_dbg_mbtrainValVrefRemoteState),
    .jtagLtsm_dbg_mbtrainValVrefSweepState                                           (jtagLtsm_dbg_mbtrainValVrefSweepState),
    .jtagLtsm_dbg_mbtrainValVrefPointInitiatorState                                  (jtagLtsm_dbg_mbtrainValVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainValVrefPointResponderState                                  (jtagLtsm_dbg_mbtrainValVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainDataVrefLocalState                                          (jtagLtsm_dbg_mbtrainDataVrefLocalState),
    .jtagLtsm_dbg_mbtrainDataVrefRemoteState                                         (jtagLtsm_dbg_mbtrainDataVrefRemoteState),
    .jtagLtsm_dbg_mbtrainDataVrefSweepState                                          (jtagLtsm_dbg_mbtrainDataVrefSweepState),
    .jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState                                 (jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainDataVrefPointResponderState                                 (jtagLtsm_dbg_mbtrainDataVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainSpeedIdleSenderState                                        (jtagLtsm_dbg_mbtrainSpeedIdleSenderState),
    .jtagLtsm_dbg_mbtrainSpeedIdleReceiverState                                      (jtagLtsm_dbg_mbtrainSpeedIdleReceiverState),
    .jtagLtsm_dbg_mbtrainTxSelfCalSenderState                                        (jtagLtsm_dbg_mbtrainTxSelfCalSenderState),
    .jtagLtsm_dbg_mbtrainTxSelfCalReceiverState                                      (jtagLtsm_dbg_mbtrainTxSelfCalReceiverState),
    .jtagLtsm_dbg_mbtrainRxClkCalSenderState                                         (jtagLtsm_dbg_mbtrainRxClkCalSenderState),
    .jtagLtsm_dbg_mbtrainRxClkCalReceiverState                                       (jtagLtsm_dbg_mbtrainRxClkCalReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterSenderState                                   (jtagLtsm_dbg_mbtrainValTrainCenterSenderState),
    .jtagLtsm_dbg_mbtrainValTrainCenterReceiverState                                 (jtagLtsm_dbg_mbtrainValTrainCenterReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState                                (jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState),
    .jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState                              (jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterSweepState                                    (jtagLtsm_dbg_mbtrainValTrainCenterSweepState),
    .jtagLtsm_dbg_mbtrainValTrainVrefLocalState                                      (jtagLtsm_dbg_mbtrainValTrainVrefLocalState),
    .jtagLtsm_dbg_mbtrainValTrainVrefRemoteState                                     (jtagLtsm_dbg_mbtrainValTrainVrefRemoteState),
    .jtagLtsm_dbg_mbtrainValTrainVrefSweepState                                      (jtagLtsm_dbg_mbtrainValTrainVrefSweepState),
    .jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState                             (jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState                             (jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState                                 (jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState                               (jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState                              (jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState                            (jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState                                  (jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefLocalState                                     (jtagLtsm_dbg_mbtrainDataTrainVrefLocalState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState                                    (jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefSweepState                                     (jtagLtsm_dbg_mbtrainDataTrainVrefSweepState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState                            (jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState                            (jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainRxDeskewLocalState                                          (jtagLtsm_dbg_mbtrainRxDeskewLocalState),
    .jtagLtsm_dbg_mbtrainRxDeskewRemoteState                                         (jtagLtsm_dbg_mbtrainRxDeskewRemoteState),
    .jtagLtsm_dbg_mbtrainRxDeskewSweepState                                          (jtagLtsm_dbg_mbtrainRxDeskewSweepState),
    .jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState                                 (jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState),
    .jtagLtsm_dbg_mbtrainRxDeskewPointResponderState                                 (jtagLtsm_dbg_mbtrainRxDeskewPointResponderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState                                 (jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState                               (jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState                              (jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState                            (jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState                                  (jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState),
    .jtagLtsm_dbg_mbtrainLinkSpeedSenderState                                        (jtagLtsm_dbg_mbtrainLinkSpeedSenderState),
    .jtagLtsm_dbg_mbtrainLinkSpeedReceiverState                                      (jtagLtsm_dbg_mbtrainLinkSpeedReceiverState),
    .jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState                                     (jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState),
    .jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState                                   (jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState),
    .jtagLtsm_dbg_mbtrainLastErrorCount                                              (jtagLtsm_dbg_mbtrainLastErrorCount),
    .jtagLtsm_dbg_mbtrainRetryCount                                                  (jtagLtsm_dbg_mbtrainRetryCount)
  );

endmodule

`default_nettype wire
