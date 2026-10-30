`default_nettype none

// ============================================================================
// UcieDigitalTopJtag
// The <reg>_in_t / <reg>_out_t structs and the u_top connections follow the
// jtag*_* port list of UcieDigitalTop; update them if those ports change.
//
// UcieDigitalTop with its test pins (testMode*, jtag*_*) connected to six
// jtag_tdr_snapshot Test Data Registers. The TAP is external: it drives the
// shared TDR bus (tdr_*) and one sel_<reg> per register, and muxes tdo_<reg>.
//
//   register  DATA_W                    function
//   ctrl      8                         test mode select and core reset
//   dig       max(in, out) of jtag_*    testModeDigital pins
//   fdi       max(in, out) of jtagFdi_* testModeFdi pins
//   rdi       max(in, out) of jtagRdi_* testModeRdi pins
//   ltsm      max(in, out) of jtagLtsm_* testModeLtsm pins
//   phy       max(in, out) of jtagPhy_* testModePhy pins
//
// Every register uses the jtag_tdr_snapshot protocol (see that file):
//   DR bit 0      we (TDI) / busy (TDO)
//   DR bits [N:1] data_out (TDI, written when we=1) / snapshot of data_in (TDO)
//
// Control register (ctrl, data_out; data_in reads data_out back):
//   [2:0]  mode     0 = functional, 1 = digital, 2 = fdi, 3 = rdi, 4 = ltsm,
//                   5 = phy (6..7 = functional). At most one testMode* is driven.
//   [3]    sys_rst  1 = core held in reset while in a test mode
//                   (drives every jtag<Blk>_reset_n). Reset value 1.
//                   No effect in phy mode: the core is always held in reset.
//   [7:4]  unused
//   Recommended sequence: write {sys_rst=1, mode=X}, then {sys_rst=0, mode=X}.
//   Change mode only with sys_rst=1.
//
// I/O registers (dig, fdi, rdi, ltsm, phy):
//   data_out = <reg>_in  packed struct of the block inputs  (jtag<Blk>_* inputs)
//   data_in  = <reg>_out packed struct of the block outputs (jtag<Blk>_* outputs)
//   Both are zero-extended to DATA_W. The first port of the group is the MSB
//   field of the struct; DR bit = data bit + 1.
//   For phy, phy_in is what the TDR drives toward the PHY (flagToAnalog_*)
//   and phy_out is what the PHY reports (flagFromAnalog_*, stable_clk,
//   pll_locked, stable_supply). Field names drop the ltsm_ pin prefix.
//   jtag<Blk>_clock and jtag<Blk>_reset_n are not in the registers: the clock
//   is the wrapper clock and the reset comes from ctrl.sys_rst.
//   Inputs change together, one clock cycle after the Update-DR is
//   synchronized. jtag_sb_rx_clk is a register bit like any other input:
//   write sb_rx_din first and toggle sb_rx_clk in a later write.
//
// Clocks and resets:
//   clock    core clock (internal or external, selected outside this wrapper).
//            Also the IP-side clock of the six TDRs and every jtag<Blk>_clock,
//            so the clock muxes in UcieDigitalTop never switch between
//            different sources.
//   reset_n  functional reset of the core and IP-side reset of the TDRs.
//            Asserting it returns ctrl to functional mode.
//   jtag_nRst  clears both mailbox domains; committed controls are retained.
//   tdr_rst    clears serial shift state; accepted transactions finish once.
//
// Speed controls (functional pins and DIG/LTSM packed registers):
//   linkSpeed_requestedSpeed: 00=2GHz, 01=4GHz, 10=6GHz, 11=8GHz.
//   Sampled at MBINIT start and capped to the highest common advertised rate.
//   flagToAnalog_linkSpeed_speedCode: selected rate, held through ACTIVE.
//   applySpeed: hold PHY rate request until speedApplied acknowledges it.
//   electricalIdle: PHY must hold clock/data/valid/track transmitters low.
//   The digital clock remains at its fixed rate; these bits control the PHY.
//   cycles_1us is the shared core timing reference (800 for an 800MHz core),
//   including LTSM isolation mode. It is not a generated analog clock.
// ============================================================================

module UcieDigitalTopJtag #(
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
  // JTAG TDR BUS (from the external TAP, tdr_tck domain)
  // ==========================================================================
  input  wire logic jtag_nRst,
  input  wire logic tdr_rst,
  input  wire logic tdr_tck,
  input  wire logic tdr_tdi,
  input  wire logic tdr_capture,
  input  wire logic tdr_shift,
  input  wire logic tdr_update,
  input  wire logic sel_ctrl,
  input  wire logic sel_dig,
  input  wire logic sel_fdi,
  input  wire logic sel_rdi,
  input  wire logic sel_ltsm,
  input  wire logic sel_phy,
  output var  logic tdo_ctrl,
  output var  logic tdo_dig,
  output var  logic tdo_fdi,
  output var  logic tdo_rdi,
  output var  logic tdo_ltsm,
  output var  logic tdo_phy,

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
  output var logic debug_rx_fire

);

  // --------------------------------------------------------------------------
  // CONTROL REGISTER
  // --------------------------------------------------------------------------
  localparam int unsigned CTRL_W = 8;
  localparam logic [2:0] MODE_FUNCTIONAL = 3'd0;
  localparam logic [2:0] MODE_DIG = 3'd1;
  localparam logic [2:0] MODE_FDI = 3'd2;
  localparam logic [2:0] MODE_RDI = 3'd3;
  localparam logic [2:0] MODE_LTSM = 3'd4;
  localparam logic [2:0] MODE_PHY = 3'd5;

  logic [CTRL_W-1:0] ctrl_q;
  logic [2:0]        ctrl_mode;
  logic              ctrl_sys_rst;
  logic              test_reset_n;

  assign ctrl_mode    = ctrl_q[2:0];
  assign ctrl_sys_rst = ctrl_q[3];
  assign test_reset_n = reset_n & ~ctrl_sys_rst;

  jtag_tdr_snapshot #(
    .DATA_W      (CTRL_W),
    .RESET_VALUE (CTRL_W'(8'h08))
  ) u_tdr_ctrl (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_ctrl),
    .tdo           (tdo_ctrl),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (ctrl_q),
    .data_out      (ctrl_q),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // DIG TDR (jtag_* pins, testModeDigital)
  // --------------------------------------------------------------------------
  typedef struct packed {
    UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req;
    logic fdi_lp_linkerror;
    logic fdi_lp_rx_active_sts;
    logic fdi_lp_wake_req;
    logic fdi_lp_clk_ack;
    logic fdi_lp_stall_ack;
    logic timeout_disable;
    logic [31:0] cycles_1us;
    logic ltsm_start;
    logic ltsm_stable_clk;
    logic ltsm_pll_locked;
    logic ltsm_stable_supply;
    logic ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
    logic ltsm_flagFromAnalog_FinishedClkPatterns;
    logic ltsm_flagFromAnalog_FinishedValTrainPattern;
    logic ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
    logic ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
    logic ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
    logic ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
    logic ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
    logic ltsm_flagFromAnalog_ValTrainPatternReceived;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
    logic ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
    logic ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
    logic ltsm_flagFromAnalog_valVref_detectedValPattern;
    logic ltsm_flagFromAnalog_valVref_finishedPattern;
    logic ltsm_flagFromAnalog_valVref_rxVrefApplied;
    logic [dataLaneCount-1:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern;
    logic ltsm_flagFromAnalog_dataVref_finishedPattern;
    logic ltsm_flagFromAnalog_dataVref_rxVrefApplied;
    logic ltsm_flagFromAnalog_rxClkCal_done;
    logic ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
    logic ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
    logic [15:0] ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
    logic [63:0] ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
    logic ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
    logic ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
    logic ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
    logic ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
    logic [dataLaneCount-1:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
    logic [15:0] ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
    logic [1:0] ltsm_linkSpeed_requestedSpeed;
    logic  ltsm_flagFromAnalog_linkSpeed_speedApplied;
    logic sb_rx_din;
    logic sb_rx_clk;
  } dig_in_t;

  typedef struct packed {
    UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts;
    logic fdi_pl_rx_active_req;
    logic fdi_pl_inband_pres;
    logic fdi_pl_wake_ack;
    logic fdi_pl_clk_req;
    logic fdi_pl_stall_req;
    logic fdi_active;
    logic ltsm_flagToAnalog_RepairClkState;
    logic ltsm_flagToAnalog_SendClkPatterns;
    logic ltsm_flagToAnalog_RepairValState;
    logic ltsm_flagToAnalog_SendValTrainPattern;
    logic ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
    logic ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
    logic ltsm_flagToAnalog_RepairMbSetReceiver;
    logic ltsm_flagToAnalog_LaneReversalApplied;
    logic ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
    logic [3:0] ltsm_state;
    logic ltsm_dbg_flagSbinitFirstClkPatternSeen;
    logic ltsm_dbg_rxValidRisingEdge;
    logic [2:0] ltsm_dbg_sbinitSendCount;
    logic ltsm_dbg_sbTxValid;
    logic [127:0] ltsm_dbg_sbTxDin;
    logic ltsm_dbg_flagTrainError;
    logic [2:0] ltsm_dbg_mbinitSubstate;
    logic [4:0] ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
    logic ltsm_flagToAnalog_valVref_sendPattern;
    logic ltsm_flagToAnalog_valVref_applyRxVref;
    logic [validVrefCodeWidth-1:0] ltsm_flagToAnalog_valVref_rxVrefCode;
    logic ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
    logic [15:0] ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
    logic ltsm_flagToAnalog_valVref_comparisonMode;
    logic [15:0] ltsm_flagToAnalog_valVref_iterationCountSettings;
    logic [15:0] ltsm_flagToAnalog_valVref_idleCountSettings;
    logic [15:0] ltsm_flagToAnalog_valVref_burstCountSettings;
    logic ltsm_flagToAnalog_valVref_patternMode;
    logic [3:0] ltsm_flagToAnalog_valVref_clockPhaseControl;
    logic [2:0] ltsm_flagToAnalog_valVref_validPattern;
    logic [2:0] ltsm_flagToAnalog_valVref_dataPattern;
    logic ltsm_flagToAnalog_valVref_clearComparisonErrors;
    logic ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
    logic ltsm_flagToAnalog_dataVref_sendPattern;
    logic ltsm_flagToAnalog_dataVref_applyRxVref;
    logic [dataLaneCount*dataVrefCodeWidth-1:0] ltsm_flagToAnalog_dataVref_rxVrefCodes;
    logic ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
    logic [15:0] ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
    logic ltsm_flagToAnalog_dataVref_comparisonMode;
    logic [15:0] ltsm_flagToAnalog_dataVref_iterationCountSettings;
    logic [15:0] ltsm_flagToAnalog_dataVref_idleCountSettings;
    logic [15:0] ltsm_flagToAnalog_dataVref_burstCountSettings;
    logic ltsm_flagToAnalog_dataVref_patternMode;
    logic [3:0] ltsm_flagToAnalog_dataVref_clockPhaseControl;
    logic [2:0] ltsm_flagToAnalog_dataVref_validPattern;
    logic [2:0] ltsm_flagToAnalog_dataVref_dataPattern;
    logic ltsm_flagToAnalog_dataVref_clearComparisonErrors;
    logic ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
    logic ltsm_flagToAnalog_rxClkCal_doCalibration;
    logic ltsm_flagToAnalog_rxClkCal_sendClockTrack;
    logic ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
    logic ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
    logic ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
    logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
    logic ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
    logic [15:0] ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
    logic ltsm_flagToAnalog_d2cReceiver_comparisonMode;
    logic [15:0] ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
    logic [15:0] ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
    logic [15:0] ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
    logic ltsm_flagToAnalog_d2cReceiver_patternMode;
    logic [3:0] ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
    logic [2:0] ltsm_flagToAnalog_d2cReceiver_validPattern;
    logic [2:0] ltsm_flagToAnalog_d2cReceiver_dataPattern;
    logic ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    logic ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
    logic ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
    logic [64*d2cTxDeskewCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
    logic ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
    logic ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
    logic ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
    logic [dataLaneCount*rxDeskewCodeWidth-1:0] ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
    logic ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
    logic [15:0] ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
    logic ltsm_flagToAnalog_rxDeskew_comparisonMode;
    logic [15:0] ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
    logic [15:0] ltsm_flagToAnalog_rxDeskew_idleCountSettings;
    logic [15:0] ltsm_flagToAnalog_rxDeskew_burstCountSettings;
    logic ltsm_flagToAnalog_rxDeskew_patternMode;
    logic [3:0] ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
    logic [2:0] ltsm_flagToAnalog_rxDeskew_validPattern;
    logic [2:0] ltsm_flagToAnalog_rxDeskew_dataPattern;
    logic ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
    logic ltsm_flagToLtsm_linkSpeed_phyInRetrain;
    logic [1:0] ltsm_flagToAnalog_linkSpeed_speedCode;
    logic ltsm_flagToAnalog_linkSpeed_applySpeed;
    logic ltsm_flagToAnalog_linkSpeed_electricalIdle;
    logic [3:0] ltsm_dbg_mbtrainState;
    logic [11:0] ltsm_dbg_mbtrainActiveSubstate;
    logic [15:0] ltsm_dbg_mbtrainLastErrorCount;
    logic [15:0] ltsm_dbg_mbtrainRetryCount;
    logic sb_tx_dout;
    logic sb_tx_clk;
    logic debug_sb_rx_overflow;
    logic [3:0] debug_ltsm_state;
    logic debug_ltsm_inband_pres;
    UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state;
    UcieUPM_interfaces_pkg::PhyState_t debug_rdi_state;
    UcieUPM_interfaces_pkg::PhyStateReq_t debug_fdi_to_rdi_state_req;
    logic debug_arb_grant_ltsm;
    logic debug_arb_grant_fdi;
    logic debug_arb_grant_rdi;
    logic debug_arb_tx_locked;
    logic [1:0] debug_arb_rr_last_source;
    logic debug_arb_rr_last_granted_rdi;
    logic debug_arb_tx_fire;
    logic debug_rx_route_ltsm;
    logic debug_rx_route_fdi;
    logic debug_rx_route_rdi;
    logic debug_rx_drop_unknown;
    logic debug_rx_fire;
  } dig_out_t;

  localparam int unsigned DIG_IN_W  = $bits(dig_in_t);
  localparam int unsigned DIG_OUT_W = $bits(dig_out_t);
  localparam int unsigned DIG_W     = (DIG_IN_W > DIG_OUT_W) ? DIG_IN_W : DIG_OUT_W;

  dig_in_t        dig_in;
  dig_out_t       dig_out;
  logic [DIG_W-1:0] dig_data_out;
  logic [DIG_W-1:0] dig_data_in;

  assign dig_in      = dig_data_out[DIG_IN_W-1:0];
  assign dig_data_in = DIG_W'(dig_out);

  jtag_tdr_snapshot #(
    .DATA_W (DIG_W)
  ) u_tdr_dig (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_dig),
    .tdo           (tdo_dig),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (dig_data_in),
    .data_out      (dig_data_out),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // FDI TDR (jtagFdi_* pins, testModeFdi)
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic [31:0] cycles_1us;
    logic timeout_disable;
    UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req;
    logic fdi_lp_linkerror;
    logic fdi_lp_rx_active_sts;
    logic fdi_lp_wake_req;
    logic fdi_lp_clk_ack;
    logic fdi_lp_stall_ack;
    UcieUPM_interfaces_pkg::PhyState_t rdi_pl_state_sts;
    logic rdi_pl_inband_pres;
    logic rdiAwake;
    logic rdiNeedsFdiAwake;
    logic rdi_pl_stall_req;
    logic sb_snd_ready;
    logic sb_rcv_valid;
    logic [127:0] sb_rcv_msg;
  } fdi_in_t;

  typedef struct packed {
    UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts;
    logic fdi_pl_rx_active_req;
    logic fdi_pl_inband_pres;
    logic fdi_pl_wake_ack;
    logic fdi_pl_clk_req;
    logic fdi_pl_stall_req;
    logic fdi_active;
    UcieUPM_d2dadapter_pkg::LinkInitState_t debug_link_init_state;
    logic rdi_lp_linkerror;
    UcieUPM_interfaces_pkg::PhyStateReq_t rdi_lp_state_req;
    logic fdiNeedsRdiAwake;
    logic fdiAwake;
    logic rdi_lp_stall_ack;
    logic sb_snd_valid;
    logic [127:0] sb_snd_msg;
    logic sb_rcv_ready;
  } fdi_out_t;

  localparam int unsigned FDI_IN_W  = $bits(fdi_in_t);
  localparam int unsigned FDI_OUT_W = $bits(fdi_out_t);
  localparam int unsigned FDI_W     = (FDI_IN_W > FDI_OUT_W) ? FDI_IN_W : FDI_OUT_W;

  fdi_in_t        fdi_in;
  fdi_out_t       fdi_out;
  logic [FDI_W-1:0] fdi_data_out;
  logic [FDI_W-1:0] fdi_data_in;

  assign fdi_in      = fdi_data_out[FDI_IN_W-1:0];
  assign fdi_data_in = FDI_W'(fdi_out);

  jtag_tdr_snapshot #(
    .DATA_W (FDI_W)
  ) u_tdr_fdi (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_fdi),
    .tdo           (tdo_fdi),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (fdi_data_in),
    .data_out      (fdi_data_out),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // RDI TDR (jtagRdi_* pins, testModeRdi)
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic ltsm_lp_wake_req;
    logic ltsm_lp_clk_ack;
    UcieUPM_interfaces_pkg::PhyStateReq_t lp_state_req;
    logic lp_stallack;
    logic ltsm_pl_inband_pres;
    logic fdiNeedsRdiAwake;
    logic fdiAwake;
    logic sb_snd_ready;
    logic sb_rcv_valid;
    logic [127:0] sb_rcv_msg;
    logic lp_linkerror;
    logic timeout_disable;
    logic [31:0] cycles_1us;
  } rdi_in_t;

  typedef struct packed {
    logic ltsm_pl_wake_ack;
    logic ltsm_pl_clk_req;
    UcieUPM_interfaces_pkg::PhyState_t pl_state_sts;
    logic pl_stallreq;
    logic rdi_pl_inband_pres;
    logic rdiAwake;
    logic rdiNeedsFdiAwake;
    logic sb_snd_valid;
    logic [127:0] sb_snd_msg;
    logic sb_rcv_ready;
    logic pl_phyinrecenter;
  } rdi_out_t;

  localparam int unsigned RDI_IN_W  = $bits(rdi_in_t);
  localparam int unsigned RDI_OUT_W = $bits(rdi_out_t);
  localparam int unsigned RDI_W     = (RDI_IN_W > RDI_OUT_W) ? RDI_IN_W : RDI_OUT_W;

  rdi_in_t        rdi_in;
  rdi_out_t       rdi_out;
  logic [RDI_W-1:0] rdi_data_out;
  logic [RDI_W-1:0] rdi_data_in;

  assign rdi_in      = rdi_data_out[RDI_IN_W-1:0];
  assign rdi_data_in = RDI_W'(rdi_out);

  jtag_tdr_snapshot #(
    .DATA_W (RDI_W)
  ) u_tdr_rdi (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_rdi),
    .tdo           (tdo_rdi),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (rdi_data_in),
    .data_out      (rdi_data_out),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // LTSM TDR (jtagLtsm_* pins, testModeLtsm)
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic sb_tx_ready;
    logic [127:0] sb_rx_dout;
    logic sb_rx_valid;
    logic jtagLtsm_start;
    logic stable_clk;
    logic pll_locked;
    logic stable_supply;
    logic flagFromAnalog_ReadyToExchangeClkPatterns;
    logic flagFromAnalog_FinishedClkPatterns;
    logic flagFromAnalog_FinishedValTrainPattern;
    logic flagFromAnalog_ReversalMbFinishedLaneIDPattern;
    logic flagFromAnalog_RepairMbFinishedLaneIDPattern;
    logic flagFromAnalog_clkPatternReceivedRTRK_L;
    logic flagFromAnalog_clkPatternReceivedRCKN_L;
    logic flagFromAnalog_clkPatternReceivedRCKP_L;
    logic flagFromAnalog_ValTrainPatternReceived;
    logic flagFromAnalog_ReversalMbTrainPatternReceived0;
    logic flagFromAnalog_ReversalMbTrainPatternReceived1;
    logic flagFromAnalog_ReversalMbTrainPatternReceived2;
    logic flagFromAnalog_ReversalMbTrainPatternReceived3;
    logic flagFromAnalog_ReversalMbTrainPatternReceived4;
    logic flagFromAnalog_ReversalMbTrainPatternReceived5;
    logic flagFromAnalog_ReversalMbTrainPatternReceived6;
    logic flagFromAnalog_ReversalMbTrainPatternReceived7;
    logic flagFromAnalog_ReversalMbTrainPatternReceived8;
    logic flagFromAnalog_ReversalMbTrainPatternReceived9;
    logic flagFromAnalog_ReversalMbTrainPatternReceived10;
    logic flagFromAnalog_ReversalMbTrainPatternReceived11;
    logic flagFromAnalog_ReversalMbTrainPatternReceived12;
    logic flagFromAnalog_ReversalMbTrainPatternReceived13;
    logic flagFromAnalog_ReversalMbTrainPatternReceived14;
    logic flagFromAnalog_ReversalMbTrainPatternReceived15;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern0;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern1;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern2;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern3;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern4;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern5;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern6;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern7;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern8;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern9;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern10;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern11;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern12;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern13;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern14;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern15;
    logic flagFromAnalog_valVref_detectedValPattern;
    logic flagFromAnalog_valVref_finishedPattern;
    logic flagFromAnalog_valVref_rxVrefApplied;
    logic [dataLaneCount-1:0] flagFromAnalog_dataVref_detectedDataPattern;
    logic flagFromAnalog_dataVref_finishedPattern;
    logic flagFromAnalog_dataVref_rxVrefApplied;
    logic flagFromAnalog_rxClkCal_done;
    logic flagFromAnalog_d2cSender_valTrainPatternSent;
    logic flagFromAnalog_d2cSender_txClockPhaseApplied;
    logic [15:0] flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
    logic [63:0] flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
    logic flagFromAnalog_d2cSender_lfsrPatternSent;
    logic flagFromAnalog_d2cSender_txLaneDeskewApplied;
    logic flagFromAnalog_rxDeskew_lfsrPatternSent;
    logic flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
    logic [dataLaneCount-1:0] flagFromAnalog_rxDeskew_detectedDataPattern;
    logic [15:0] flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
    logic [1:0] linkSpeed_requestedSpeed;
    logic  flagFromAnalog_linkSpeed_speedApplied;
  } ltsm_in_t;

  typedef struct packed {
    logic [127:0] sb_tx_din;
    logic sb_tx_valid;
    logic flagToAnalog_RepairClkState;
    logic flagToAnalog_SendClkPatterns;
    logic flagToAnalog_RepairValState;
    logic flagToAnalog_SendValTrainPattern;
    logic flagToAnalog_ReversalMbSendLaneIDPattern;
    logic flagToAnalog_RepairMbSendLaneIDPattern;
    logic flagToAnalog_RepairMbSetReceiver;
    logic flagToAnalog_LaneReversalApplied;
    logic flagToAnalog_linkInit_resetLfsrScrambler;
    logic [3:0] jtagLtsm_state;
    logic dbg_flagSbinitFirstClkPatternSeen;
    logic dbg_rxValidRisingEdge;
    logic [2:0] dbg_sbinitSendCount;
    logic dbg_sbTxValid;
    logic [127:0] dbg_sbTxDin;
    logic dbg_flagTrainError;
    logic [2:0] dbg_mbinitSubstate;
    logic [1:0] dbg_mbinitParamSenderState;
    logic [1:0] dbg_mbinitParamReceiverState;
    logic [1:0] dbg_mbinitCalSenderState;
    logic [1:0] dbg_mbinitCalReceiverState;
    logic [2:0] dbg_mbinitRepairClkSenderState;
    logic [2:0] dbg_mbinitRepairClkReceiverState;
    logic [2:0] dbg_mbinitRepairValSenderState;
    logic [2:0] dbg_mbinitRepairValReceiverState;
    logic [3:0] dbg_mbinitReversalMbSenderState;
    logic [2:0] dbg_mbinitReversalMbReceiverState;
    logic [4:0] dbg_mbinitRepairMbSenderState;
    logic [3:0] dbg_mbinitRepairMbReceiverState;
    logic [4:0] dbg_mbinitReversalMbReceivedSuccessCount;
    logic flagToAnalog_valVref_sendPattern;
    logic flagToAnalog_valVref_applyRxVref;
    logic [validVrefCodeWidth-1:0] flagToAnalog_valVref_rxVrefCode;
    logic flagToAnalog_valVref_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_valVref_maximumComparisonErrorThreshold;
    logic flagToAnalog_valVref_comparisonMode;
    logic [15:0] flagToAnalog_valVref_iterationCountSettings;
    logic [15:0] flagToAnalog_valVref_idleCountSettings;
    logic [15:0] flagToAnalog_valVref_burstCountSettings;
    logic flagToAnalog_valVref_patternMode;
    logic [3:0] flagToAnalog_valVref_clockPhaseControl;
    logic [2:0] flagToAnalog_valVref_validPattern;
    logic [2:0] flagToAnalog_valVref_dataPattern;
    logic flagToAnalog_valVref_clearComparisonErrors;
    logic flagToAnalog_valVref_resetLocalTxScrambler;
    logic flagToAnalog_dataVref_sendPattern;
    logic flagToAnalog_dataVref_applyRxVref;
    logic [dataLaneCount*dataVrefCodeWidth-1:0] flagToAnalog_dataVref_rxVrefCodes;
    logic flagToAnalog_dataVref_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_dataVref_maximumComparisonErrorThreshold;
    logic flagToAnalog_dataVref_comparisonMode;
    logic [15:0] flagToAnalog_dataVref_iterationCountSettings;
    logic [15:0] flagToAnalog_dataVref_idleCountSettings;
    logic [15:0] flagToAnalog_dataVref_burstCountSettings;
    logic flagToAnalog_dataVref_patternMode;
    logic [3:0] flagToAnalog_dataVref_clockPhaseControl;
    logic [2:0] flagToAnalog_dataVref_validPattern;
    logic [2:0] flagToAnalog_dataVref_dataPattern;
    logic flagToAnalog_dataVref_clearComparisonErrors;
    logic flagToAnalog_dataVref_resetLocalTxScrambler;
    logic flagToAnalog_rxClkCal_doCalibration;
    logic flagToAnalog_rxClkCal_sendClockTrack;
    logic flagToAnalog_d2cSender_sendValTrainPattern;
    logic flagToAnalog_d2cSender_resetLocalScrambler;
    logic flagToAnalog_d2cSender_applyTxClockPhase;
    logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode;
    logic flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
    logic [15:0] flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
    logic flagToAnalog_d2cReceiver_comparisonMode;
    logic [15:0] flagToAnalog_d2cReceiver_iterationCountSettings;
    logic [15:0] flagToAnalog_d2cReceiver_idleCountSettings;
    logic [15:0] flagToAnalog_d2cReceiver_burstCountSettings;
    logic flagToAnalog_d2cReceiver_patternMode;
    logic [3:0] flagToAnalog_d2cReceiver_clockPhaseControl;
    logic [2:0] flagToAnalog_d2cReceiver_validPattern;
    logic [2:0] flagToAnalog_d2cReceiver_dataPattern;
    logic flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    logic flagToAnalog_d2cSender_sendLfsrPattern;
    logic flagToAnalog_d2cSender_applyTxLaneDeskew;
    logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_txLaneDeskewCodes;
    logic flagToAnalog_rxDeskew_sendLfsrPattern;
    logic flagToAnalog_rxDeskew_resetLocalTxScrambler;
    logic flagToAnalog_rxDeskew_applyRxLaneDeskew;
    logic [dataLaneCount*rxDeskewCodeWidth-1:0] flagToAnalog_rxDeskew_rxLaneDeskewCodes;
    logic flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
    logic flagToAnalog_rxDeskew_comparisonMode;
    logic [15:0] flagToAnalog_rxDeskew_iterationCountSettings;
    logic [15:0] flagToAnalog_rxDeskew_idleCountSettings;
    logic [15:0] flagToAnalog_rxDeskew_burstCountSettings;
    logic flagToAnalog_rxDeskew_patternMode;
    logic [3:0] flagToAnalog_rxDeskew_clockPhaseControl;
    logic [2:0] flagToAnalog_rxDeskew_validPattern;
    logic [2:0] flagToAnalog_rxDeskew_dataPattern;
    logic flagToAnalog_rxDeskew_clearComparisonErrors;
    logic flagToLtsm_linkSpeed_phyInRetrain;
    logic [1:0] flagToAnalog_linkSpeed_speedCode;
    logic flagToAnalog_linkSpeed_applySpeed;
    logic flagToAnalog_linkSpeed_electricalIdle;
    logic [3:0] dbg_mbtrainState;
    logic [11:0] dbg_mbtrainActiveSubstate;
    logic [3:0] dbg_mbtrainValVrefLocalState;
    logic [2:0] dbg_mbtrainValVrefRemoteState;
    logic [3:0] dbg_mbtrainValVrefSweepState;
    logic [3:0] dbg_mbtrainValVrefPointInitiatorState;
    logic [3:0] dbg_mbtrainValVrefPointResponderState;
    logic [3:0] dbg_mbtrainDataVrefLocalState;
    logic [2:0] dbg_mbtrainDataVrefRemoteState;
    logic [3:0] dbg_mbtrainDataVrefSweepState;
    logic [3:0] dbg_mbtrainDataVrefPointInitiatorState;
    logic [3:0] dbg_mbtrainDataVrefPointResponderState;
    logic [1:0] dbg_mbtrainSpeedIdleSenderState;
    logic [1:0] dbg_mbtrainSpeedIdleReceiverState;
    logic [1:0] dbg_mbtrainTxSelfCalSenderState;
    logic [1:0] dbg_mbtrainTxSelfCalReceiverState;
    logic [2:0] dbg_mbtrainRxClkCalSenderState;
    logic [2:0] dbg_mbtrainRxClkCalReceiverState;
    logic [3:0] dbg_mbtrainValTrainCenterSenderState;
    logic [2:0] dbg_mbtrainValTrainCenterReceiverState;
    logic [3:0] dbg_mbtrainValTrainCenterD2cSenderState;
    logic [3:0] dbg_mbtrainValTrainCenterD2cReceiverState;
    logic [3:0] dbg_mbtrainValTrainCenterSweepState;
    logic [3:0] dbg_mbtrainValTrainVrefLocalState;
    logic [2:0] dbg_mbtrainValTrainVrefRemoteState;
    logic [3:0] dbg_mbtrainValTrainVrefSweepState;
    logic [3:0] dbg_mbtrainValTrainVrefPointInitiatorState;
    logic [3:0] dbg_mbtrainValTrainVrefPointResponderState;
    logic [3:0] dbg_mbtrainDataTrainCenter1SenderState;
    logic [2:0] dbg_mbtrainDataTrainCenter1ReceiverState;
    logic [3:0] dbg_mbtrainDataTrainCenter1D2cSenderState;
    logic [3:0] dbg_mbtrainDataTrainCenter1D2cReceiverState;
    logic [4:0] dbg_mbtrainDataTrainCenter1SweepState;
    logic [3:0] dbg_mbtrainDataTrainVrefLocalState;
    logic [2:0] dbg_mbtrainDataTrainVrefRemoteState;
    logic [3:0] dbg_mbtrainDataTrainVrefSweepState;
    logic [3:0] dbg_mbtrainDataTrainVrefPointInitiatorState;
    logic [3:0] dbg_mbtrainDataTrainVrefPointResponderState;
    logic [3:0] dbg_mbtrainRxDeskewLocalState;
    logic [2:0] dbg_mbtrainRxDeskewRemoteState;
    logic [3:0] dbg_mbtrainRxDeskewSweepState;
    logic [3:0] dbg_mbtrainRxDeskewPointInitiatorState;
    logic [3:0] dbg_mbtrainRxDeskewPointResponderState;
    logic [3:0] dbg_mbtrainDataTrainCenter2SenderState;
    logic [2:0] dbg_mbtrainDataTrainCenter2ReceiverState;
    logic [3:0] dbg_mbtrainDataTrainCenter2D2cSenderState;
    logic [3:0] dbg_mbtrainDataTrainCenter2D2cReceiverState;
    logic [3:0] dbg_mbtrainDataTrainCenter2SweepState;
    logic [3:0] dbg_mbtrainLinkSpeedSenderState;
    logic [2:0] dbg_mbtrainLinkSpeedReceiverState;
    logic [3:0] dbg_mbtrainLinkSpeedD2cSenderState;
    logic [3:0] dbg_mbtrainLinkSpeedD2cReceiverState;
    logic [15:0] dbg_mbtrainLastErrorCount;
    logic [15:0] dbg_mbtrainRetryCount;
  } ltsm_out_t;

  localparam int unsigned LTSM_IN_W  = $bits(ltsm_in_t);
  localparam int unsigned LTSM_OUT_W = $bits(ltsm_out_t);
  localparam int unsigned LTSM_W     = (LTSM_IN_W > LTSM_OUT_W) ? LTSM_IN_W : LTSM_OUT_W;

  ltsm_in_t        ltsm_in;
  ltsm_out_t       ltsm_out;
  logic [LTSM_W-1:0] ltsm_data_out;
  logic [LTSM_W-1:0] ltsm_data_in;

  assign ltsm_in      = ltsm_data_out[LTSM_IN_W-1:0];
  assign ltsm_data_in = LTSM_W'(ltsm_out);

  jtag_tdr_snapshot #(
    .DATA_W (LTSM_W)
  ) u_tdr_ltsm (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_ltsm),
    .tdo           (tdo_ltsm),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (ltsm_data_in),
    .data_out      (ltsm_data_out),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // PHY TDR (jtagPhy_* pins, testModePhy)
  // --------------------------------------------------------------------------
  typedef struct packed {
    logic flagToAnalog_RepairClkState;
    logic flagToAnalog_SendClkPatterns;
    logic flagToAnalog_RepairValState;
    logic flagToAnalog_SendValTrainPattern;
    logic flagToAnalog_ReversalMbSendLaneIDPattern;
    logic flagToAnalog_RepairMbSendLaneIDPattern;
    logic flagToAnalog_RepairMbSetReceiver;
    logic flagToAnalog_LaneReversalApplied;
    logic flagToAnalog_linkInit_resetLfsrScrambler;
    logic flagToAnalog_valVref_sendPattern;
    logic flagToAnalog_valVref_applyRxVref;
    logic [validVrefCodeWidth-1:0] flagToAnalog_valVref_rxVrefCode;
    logic flagToAnalog_valVref_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_valVref_maximumComparisonErrorThreshold;
    logic flagToAnalog_valVref_comparisonMode;
    logic [15:0] flagToAnalog_valVref_iterationCountSettings;
    logic [15:0] flagToAnalog_valVref_idleCountSettings;
    logic [15:0] flagToAnalog_valVref_burstCountSettings;
    logic flagToAnalog_valVref_patternMode;
    logic [3:0] flagToAnalog_valVref_clockPhaseControl;
    logic [2:0] flagToAnalog_valVref_validPattern;
    logic [2:0] flagToAnalog_valVref_dataPattern;
    logic flagToAnalog_valVref_clearComparisonErrors;
    logic flagToAnalog_valVref_resetLocalTxScrambler;
    logic flagToAnalog_dataVref_sendPattern;
    logic flagToAnalog_dataVref_applyRxVref;
    logic [dataLaneCount*dataVrefCodeWidth-1:0] flagToAnalog_dataVref_rxVrefCodes;
    logic flagToAnalog_dataVref_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_dataVref_maximumComparisonErrorThreshold;
    logic flagToAnalog_dataVref_comparisonMode;
    logic [15:0] flagToAnalog_dataVref_iterationCountSettings;
    logic [15:0] flagToAnalog_dataVref_idleCountSettings;
    logic [15:0] flagToAnalog_dataVref_burstCountSettings;
    logic flagToAnalog_dataVref_patternMode;
    logic [3:0] flagToAnalog_dataVref_clockPhaseControl;
    logic [2:0] flagToAnalog_dataVref_validPattern;
    logic [2:0] flagToAnalog_dataVref_dataPattern;
    logic flagToAnalog_dataVref_clearComparisonErrors;
    logic flagToAnalog_dataVref_resetLocalTxScrambler;
    logic flagToAnalog_rxClkCal_doCalibration;
    logic flagToAnalog_rxClkCal_sendClockTrack;
    logic flagToAnalog_d2cSender_sendValTrainPattern;
    logic flagToAnalog_d2cSender_resetLocalScrambler;
    logic flagToAnalog_d2cSender_applyTxClockPhase;
    logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode;
    logic flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
    logic [15:0] flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
    logic flagToAnalog_d2cReceiver_comparisonMode;
    logic [15:0] flagToAnalog_d2cReceiver_iterationCountSettings;
    logic [15:0] flagToAnalog_d2cReceiver_idleCountSettings;
    logic [15:0] flagToAnalog_d2cReceiver_burstCountSettings;
    logic flagToAnalog_d2cReceiver_patternMode;
    logic [3:0] flagToAnalog_d2cReceiver_clockPhaseControl;
    logic [2:0] flagToAnalog_d2cReceiver_validPattern;
    logic [2:0] flagToAnalog_d2cReceiver_dataPattern;
    logic flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    logic flagToAnalog_d2cSender_sendLfsrPattern;
    logic flagToAnalog_d2cSender_applyTxLaneDeskew;
    logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_txLaneDeskewCodes;
    logic flagToAnalog_rxDeskew_sendLfsrPattern;
    logic flagToAnalog_rxDeskew_resetLocalTxScrambler;
    logic flagToAnalog_rxDeskew_applyRxLaneDeskew;
    logic [dataLaneCount*rxDeskewCodeWidth-1:0] flagToAnalog_rxDeskew_rxLaneDeskewCodes;
    logic flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
    logic [15:0] flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
    logic flagToAnalog_rxDeskew_comparisonMode;
    logic [15:0] flagToAnalog_rxDeskew_iterationCountSettings;
    logic [15:0] flagToAnalog_rxDeskew_idleCountSettings;
    logic [15:0] flagToAnalog_rxDeskew_burstCountSettings;
    logic flagToAnalog_rxDeskew_patternMode;
    logic [3:0] flagToAnalog_rxDeskew_clockPhaseControl;
    logic [2:0] flagToAnalog_rxDeskew_validPattern;
    logic [2:0] flagToAnalog_rxDeskew_dataPattern;
    logic flagToAnalog_rxDeskew_clearComparisonErrors;
    logic [1:0] flagToAnalog_linkSpeed_speedCode;
    logic flagToAnalog_linkSpeed_applySpeed;
    logic flagToAnalog_linkSpeed_electricalIdle;
  } phy_in_t;

  typedef struct packed {
    logic stable_clk;
    logic pll_locked;
    logic stable_supply;
    logic flagFromAnalog_ReadyToExchangeClkPatterns;
    logic flagFromAnalog_FinishedClkPatterns;
    logic flagFromAnalog_FinishedValTrainPattern;
    logic flagFromAnalog_ReversalMbFinishedLaneIDPattern;
    logic flagFromAnalog_RepairMbFinishedLaneIDPattern;
    logic flagFromAnalog_clkPatternReceivedRTRK_L;
    logic flagFromAnalog_clkPatternReceivedRCKN_L;
    logic flagFromAnalog_clkPatternReceivedRCKP_L;
    logic flagFromAnalog_ValTrainPatternReceived;
    logic flagFromAnalog_ReversalMbTrainPatternReceived0;
    logic flagFromAnalog_ReversalMbTrainPatternReceived1;
    logic flagFromAnalog_ReversalMbTrainPatternReceived2;
    logic flagFromAnalog_ReversalMbTrainPatternReceived3;
    logic flagFromAnalog_ReversalMbTrainPatternReceived4;
    logic flagFromAnalog_ReversalMbTrainPatternReceived5;
    logic flagFromAnalog_ReversalMbTrainPatternReceived6;
    logic flagFromAnalog_ReversalMbTrainPatternReceived7;
    logic flagFromAnalog_ReversalMbTrainPatternReceived8;
    logic flagFromAnalog_ReversalMbTrainPatternReceived9;
    logic flagFromAnalog_ReversalMbTrainPatternReceived10;
    logic flagFromAnalog_ReversalMbTrainPatternReceived11;
    logic flagFromAnalog_ReversalMbTrainPatternReceived12;
    logic flagFromAnalog_ReversalMbTrainPatternReceived13;
    logic flagFromAnalog_ReversalMbTrainPatternReceived14;
    logic flagFromAnalog_ReversalMbTrainPatternReceived15;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern0;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern1;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern2;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern3;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern4;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern5;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern6;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern7;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern8;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern9;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern10;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern11;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern12;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern13;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern14;
    logic flagFromAnalog_RepairMbDetectedLaneIDPattern15;
    logic flagFromAnalog_valVref_detectedValPattern;
    logic flagFromAnalog_valVref_finishedPattern;
    logic flagFromAnalog_valVref_rxVrefApplied;
    logic [dataLaneCount-1:0] flagFromAnalog_dataVref_detectedDataPattern;
    logic flagFromAnalog_dataVref_finishedPattern;
    logic flagFromAnalog_dataVref_rxVrefApplied;
    logic flagFromAnalog_rxClkCal_done;
    logic flagFromAnalog_d2cSender_valTrainPatternSent;
    logic flagFromAnalog_d2cSender_txClockPhaseApplied;
    logic [15:0] flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
    logic [63:0] flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
    logic flagFromAnalog_d2cSender_lfsrPatternSent;
    logic flagFromAnalog_d2cSender_txLaneDeskewApplied;
    logic flagFromAnalog_rxDeskew_lfsrPatternSent;
    logic flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
    logic [dataLaneCount-1:0] flagFromAnalog_rxDeskew_detectedDataPattern;
    logic [15:0] flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
    logic flagFromAnalog_linkSpeed_speedApplied;
  } phy_out_t;

  localparam int unsigned PHY_IN_W  = $bits(phy_in_t);
  localparam int unsigned PHY_OUT_W = $bits(phy_out_t);
  localparam int unsigned PHY_W     = (PHY_IN_W > PHY_OUT_W) ? PHY_IN_W : PHY_OUT_W;

  phy_in_t        phy_in;
  phy_out_t       phy_out;
  logic [PHY_W-1:0] phy_data_out;
  logic [PHY_W-1:0] phy_data_in;

  assign phy_in      = phy_data_out[PHY_IN_W-1:0];
  assign phy_data_in = PHY_W'(phy_out);

  jtag_tdr_snapshot #(
    .DATA_W (PHY_W)
  ) u_tdr_phy (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel_phy),
    .tdo           (tdo_phy),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (phy_data_in),
    .data_out      (phy_data_out),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // UcieDigitalTop
  // --------------------------------------------------------------------------
  UcieDigitalTop #(
    .FDI_WIDTH(FDI_WIDTH),
    .FDI_DLLP_WIDTH(FDI_DLLP_WIDTH),
    .FDI_SB_WIDTH(FDI_SB_WIDTH),
    .RDI_WIDTH(RDI_WIDTH),
    .RDI_SB_WIDTH(RDI_SB_WIDTH),
    .SB_NODE_MSG_WIDTH(SB_NODE_MSG_WIDTH),
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
    .rxDeskewMaximumComparisonErrorThreshold(rxDeskewMaximumComparisonErrorThreshold),
    .rxDeskewMinPassingWindowValues(rxDeskewMinPassingWindowValues),
    .rxDeskewMaxTrainingRetries(rxDeskewMaxTrainingRetries),
    .SB_TX_FIFO_ENTRIES(SB_TX_FIFO_ENTRIES)
  ) u_top (
    .testModeDigital((ctrl_mode == MODE_DIG)),
    .testModeFdi((ctrl_mode == MODE_FDI)),
    .testModeRdi((ctrl_mode == MODE_RDI)),
    .testModeLtsm((ctrl_mode == MODE_LTSM)),
    .testModePhy((ctrl_mode == MODE_PHY)),
    .clock(clock),
    .reset_n(reset_n),
    .fdi_lp_state_req(fdi_lp_state_req),
    .fdi_lp_linkerror(fdi_lp_linkerror),
    .fdi_lp_rx_active_sts(fdi_lp_rx_active_sts),
    .fdi_lp_wake_req(fdi_lp_wake_req),
    .fdi_lp_clk_ack(fdi_lp_clk_ack),
    .fdi_lp_stall_ack(fdi_lp_stall_ack),
    .fdi_pl_state_sts(fdi_pl_state_sts),
    .fdi_pl_rx_active_req(fdi_pl_rx_active_req),
    .fdi_pl_inband_pres(fdi_pl_inband_pres),
    .fdi_pl_wake_ack(fdi_pl_wake_ack),
    .fdi_pl_clk_req(fdi_pl_clk_req),
    .fdi_pl_stall_req(fdi_pl_stall_req),
    .fdi_active(fdi_active),
    .timeout_disable(timeout_disable),
    .cycles_1us(cycles_1us),
    .ltsm_start(ltsm_start),
    .ltsm_stable_clk(ltsm_stable_clk),
    .ltsm_pll_locked(ltsm_pll_locked),
    .ltsm_stable_supply(ltsm_stable_supply),
    .ltsm_flagFromAnalog_ReadyToExchangeClkPatterns(ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
    .ltsm_flagFromAnalog_FinishedClkPatterns(ltsm_flagFromAnalog_FinishedClkPatterns),
    .ltsm_flagFromAnalog_FinishedValTrainPattern(ltsm_flagFromAnalog_FinishedValTrainPattern),
    .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .ltsm_flagFromAnalog_clkPatternReceivedRTRK_L(ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKN_L(ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKP_L(ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
    .ltsm_flagFromAnalog_ValTrainPatternReceived(ltsm_flagFromAnalog_ValTrainPatternReceived),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .ltsm_flagToAnalog_RepairClkState(ltsm_flagToAnalog_RepairClkState),
    .ltsm_flagToAnalog_SendClkPatterns(ltsm_flagToAnalog_SendClkPatterns),
    .ltsm_flagToAnalog_RepairValState(ltsm_flagToAnalog_RepairValState),
    .ltsm_flagToAnalog_SendValTrainPattern(ltsm_flagToAnalog_SendValTrainPattern),
    .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSendLaneIDPattern(ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSetReceiver(ltsm_flagToAnalog_RepairMbSetReceiver),
    .ltsm_flagToAnalog_LaneReversalApplied(ltsm_flagToAnalog_LaneReversalApplied),
    .ltsm_flagToAnalog_linkInit_resetLfsrScrambler(ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .ltsm_state(ltsm_state),
    .ltsm_dbg_flagSbinitFirstClkPatternSeen(ltsm_dbg_flagSbinitFirstClkPatternSeen),
    .ltsm_dbg_rxValidRisingEdge(ltsm_dbg_rxValidRisingEdge),
    .ltsm_dbg_sbinitSendCount(ltsm_dbg_sbinitSendCount),
    .ltsm_dbg_sbTxValid(ltsm_dbg_sbTxValid),
    .ltsm_dbg_sbTxDin(ltsm_dbg_sbTxDin),
    .ltsm_dbg_flagTrainError(ltsm_dbg_flagTrainError),
    .ltsm_dbg_mbinitSubstate(ltsm_dbg_mbinitSubstate),
    .ltsm_dbg_mbinitReversalMbReceivedSuccessCount(ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
    .ltsm_flagToAnalog_valVref_sendPattern(ltsm_flagToAnalog_valVref_sendPattern),
    .ltsm_flagFromAnalog_valVref_detectedValPattern(ltsm_flagFromAnalog_valVref_detectedValPattern),
    .ltsm_flagFromAnalog_valVref_finishedPattern(ltsm_flagFromAnalog_valVref_finishedPattern),
    .ltsm_flagToAnalog_valVref_applyRxVref(ltsm_flagToAnalog_valVref_applyRxVref),
    .ltsm_flagToAnalog_valVref_rxVrefCode(ltsm_flagToAnalog_valVref_rxVrefCode),
    .ltsm_flagFromAnalog_valVref_rxVrefApplied(ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest(ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold(ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_valVref_comparisonMode(ltsm_flagToAnalog_valVref_comparisonMode),
    .ltsm_flagToAnalog_valVref_iterationCountSettings(ltsm_flagToAnalog_valVref_iterationCountSettings),
    .ltsm_flagToAnalog_valVref_idleCountSettings(ltsm_flagToAnalog_valVref_idleCountSettings),
    .ltsm_flagToAnalog_valVref_burstCountSettings(ltsm_flagToAnalog_valVref_burstCountSettings),
    .ltsm_flagToAnalog_valVref_patternMode(ltsm_flagToAnalog_valVref_patternMode),
    .ltsm_flagToAnalog_valVref_clockPhaseControl(ltsm_flagToAnalog_valVref_clockPhaseControl),
    .ltsm_flagToAnalog_valVref_validPattern(ltsm_flagToAnalog_valVref_validPattern),
    .ltsm_flagToAnalog_valVref_dataPattern(ltsm_flagToAnalog_valVref_dataPattern),
    .ltsm_flagToAnalog_valVref_clearComparisonErrors(ltsm_flagToAnalog_valVref_clearComparisonErrors),
    .ltsm_flagToAnalog_valVref_resetLocalTxScrambler(ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_dataVref_sendPattern(ltsm_flagToAnalog_dataVref_sendPattern),
    .ltsm_flagFromAnalog_dataVref_detectedDataPattern(ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataVref_finishedPattern(ltsm_flagFromAnalog_dataVref_finishedPattern),
    .ltsm_flagToAnalog_dataVref_applyRxVref(ltsm_flagToAnalog_dataVref_applyRxVref),
    .ltsm_flagToAnalog_dataVref_rxVrefCodes(ltsm_flagToAnalog_dataVref_rxVrefCodes),
    .ltsm_flagFromAnalog_dataVref_rxVrefApplied(ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest(ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold(ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_dataVref_comparisonMode(ltsm_flagToAnalog_dataVref_comparisonMode),
    .ltsm_flagToAnalog_dataVref_iterationCountSettings(ltsm_flagToAnalog_dataVref_iterationCountSettings),
    .ltsm_flagToAnalog_dataVref_idleCountSettings(ltsm_flagToAnalog_dataVref_idleCountSettings),
    .ltsm_flagToAnalog_dataVref_burstCountSettings(ltsm_flagToAnalog_dataVref_burstCountSettings),
    .ltsm_flagToAnalog_dataVref_patternMode(ltsm_flagToAnalog_dataVref_patternMode),
    .ltsm_flagToAnalog_dataVref_clockPhaseControl(ltsm_flagToAnalog_dataVref_clockPhaseControl),
    .ltsm_flagToAnalog_dataVref_validPattern(ltsm_flagToAnalog_dataVref_validPattern),
    .ltsm_flagToAnalog_dataVref_dataPattern(ltsm_flagToAnalog_dataVref_dataPattern),
    .ltsm_flagToAnalog_dataVref_clearComparisonErrors(ltsm_flagToAnalog_dataVref_clearComparisonErrors),
    .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler(ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxClkCal_doCalibration(ltsm_flagToAnalog_rxClkCal_doCalibration),
    .ltsm_flagFromAnalog_rxClkCal_done(ltsm_flagFromAnalog_rxClkCal_done),
    .ltsm_flagToAnalog_rxClkCal_sendClockTrack(ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .ltsm_flagToAnalog_d2cSender_sendValTrainPattern(ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .ltsm_flagToAnalog_d2cSender_resetLocalScrambler(ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_applyTxClockPhase(ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_txClockPhaseCode(ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied(ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_comparisonMode(ltsm_flagToAnalog_d2cReceiver_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_iterationCountSettings(ltsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_idleCountSettings(ltsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_burstCountSettings(ltsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_patternMode(ltsm_flagToAnalog_d2cReceiver_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_clockPhaseControl(ltsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_validPattern(ltsm_flagToAnalog_d2cReceiver_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataPattern(ltsm_flagToAnalog_d2cReceiver_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler(ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_d2cSender_sendLfsrPattern(ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew(ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes(ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied(ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew(ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes(ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied(ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest(ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold(ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_rxDeskew_comparisonMode(ltsm_flagToAnalog_rxDeskew_comparisonMode),
    .ltsm_flagToAnalog_rxDeskew_iterationCountSettings(ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .ltsm_flagToAnalog_rxDeskew_idleCountSettings(ltsm_flagToAnalog_rxDeskew_idleCountSettings),
    .ltsm_flagToAnalog_rxDeskew_burstCountSettings(ltsm_flagToAnalog_rxDeskew_burstCountSettings),
    .ltsm_flagToAnalog_rxDeskew_patternMode(ltsm_flagToAnalog_rxDeskew_patternMode),
    .ltsm_flagToAnalog_rxDeskew_clockPhaseControl(ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .ltsm_flagToAnalog_rxDeskew_validPattern(ltsm_flagToAnalog_rxDeskew_validPattern),
    .ltsm_flagToAnalog_rxDeskew_dataPattern(ltsm_flagToAnalog_rxDeskew_dataPattern),
    .ltsm_flagToAnalog_rxDeskew_clearComparisonErrors(ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern(ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .ltsm_flagToLtsm_linkSpeed_phyInRetrain(ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .ltsm_flagToAnalog_linkSpeed_speedCode(ltsm_flagToAnalog_linkSpeed_speedCode),
    .ltsm_flagToAnalog_linkSpeed_applySpeed(ltsm_flagToAnalog_linkSpeed_applySpeed),
    .ltsm_flagToAnalog_linkSpeed_electricalIdle(ltsm_flagToAnalog_linkSpeed_electricalIdle),
    .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .ltsm_linkSpeed_requestedSpeed(ltsm_linkSpeed_requestedSpeed),
    .ltsm_flagFromAnalog_linkSpeed_speedApplied(ltsm_flagFromAnalog_linkSpeed_speedApplied),
    .ltsm_dbg_mbtrainState(ltsm_dbg_mbtrainState),
    .ltsm_dbg_mbtrainActiveSubstate(ltsm_dbg_mbtrainActiveSubstate),
    .ltsm_dbg_mbtrainLastErrorCount(ltsm_dbg_mbtrainLastErrorCount),
    .ltsm_dbg_mbtrainRetryCount(ltsm_dbg_mbtrainRetryCount),
    .sb_tx_dout(sb_tx_dout),
    .sb_tx_clk(sb_tx_clk),
    .sb_rx_din(sb_rx_din),
    .sb_rx_clk(sb_rx_clk),
    .debug_sb_rx_overflow(debug_sb_rx_overflow),
    .debug_ltsm_state(debug_ltsm_state),
    .debug_ltsm_inband_pres(debug_ltsm_inband_pres),
    .debug_fdi_link_init_state(debug_fdi_link_init_state),
    .debug_rdi_state(debug_rdi_state),
    .debug_fdi_to_rdi_state_req(debug_fdi_to_rdi_state_req),
    .debug_arb_grant_ltsm(debug_arb_grant_ltsm),
    .debug_arb_grant_fdi(debug_arb_grant_fdi),
    .debug_arb_grant_rdi(debug_arb_grant_rdi),
    .debug_arb_tx_locked(debug_arb_tx_locked),
    .debug_arb_rr_last_source(debug_arb_rr_last_source),
    .debug_arb_rr_last_granted_rdi(debug_arb_rr_last_granted_rdi),
    .debug_arb_tx_fire(debug_arb_tx_fire),
    .debug_rx_route_ltsm(debug_rx_route_ltsm),
    .debug_rx_route_fdi(debug_rx_route_fdi),
    .debug_rx_route_rdi(debug_rx_route_rdi),
    .debug_rx_drop_unknown(debug_rx_drop_unknown),
    .debug_rx_fire(debug_rx_fire),
    .jtag_clock(clock),
    .jtag_reset_n(test_reset_n),
    .jtag_fdi_lp_state_req(dig_in.fdi_lp_state_req),
    .jtag_fdi_lp_linkerror(dig_in.fdi_lp_linkerror),
    .jtag_fdi_lp_rx_active_sts(dig_in.fdi_lp_rx_active_sts),
    .jtag_fdi_lp_wake_req(dig_in.fdi_lp_wake_req),
    .jtag_fdi_lp_clk_ack(dig_in.fdi_lp_clk_ack),
    .jtag_fdi_lp_stall_ack(dig_in.fdi_lp_stall_ack),
    .jtag_fdi_pl_state_sts(dig_out.fdi_pl_state_sts),
    .jtag_fdi_pl_rx_active_req(dig_out.fdi_pl_rx_active_req),
    .jtag_fdi_pl_inband_pres(dig_out.fdi_pl_inband_pres),
    .jtag_fdi_pl_wake_ack(dig_out.fdi_pl_wake_ack),
    .jtag_fdi_pl_clk_req(dig_out.fdi_pl_clk_req),
    .jtag_fdi_pl_stall_req(dig_out.fdi_pl_stall_req),
    .jtag_fdi_active(dig_out.fdi_active),
    .jtag_timeout_disable(dig_in.timeout_disable),
    .jtag_cycles_1us(dig_in.cycles_1us),
    .jtag_ltsm_start(dig_in.ltsm_start),
    .jtag_ltsm_stable_clk(dig_in.ltsm_stable_clk),
    .jtag_ltsm_pll_locked(dig_in.ltsm_pll_locked),
    .jtag_ltsm_stable_supply(dig_in.ltsm_stable_supply),
    .jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns(dig_in.ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
    .jtag_ltsm_flagFromAnalog_FinishedClkPatterns(dig_in.ltsm_flagFromAnalog_FinishedClkPatterns),
    .jtag_ltsm_flagFromAnalog_FinishedValTrainPattern(dig_in.ltsm_flagFromAnalog_FinishedValTrainPattern),
    .jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(dig_in.ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(dig_in.ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L(dig_in.ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
    .jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L(dig_in.ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
    .jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L(dig_in.ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
    .jtag_ltsm_flagFromAnalog_ValTrainPatternReceived(dig_in.ltsm_flagFromAnalog_ValTrainPatternReceived),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
    .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15(dig_in.ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15(dig_in.ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .jtag_ltsm_flagToAnalog_RepairClkState(dig_out.ltsm_flagToAnalog_RepairClkState),
    .jtag_ltsm_flagToAnalog_SendClkPatterns(dig_out.ltsm_flagToAnalog_SendClkPatterns),
    .jtag_ltsm_flagToAnalog_RepairValState(dig_out.ltsm_flagToAnalog_RepairValState),
    .jtag_ltsm_flagToAnalog_SendValTrainPattern(dig_out.ltsm_flagToAnalog_SendValTrainPattern),
    .jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(dig_out.ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern(dig_out.ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .jtag_ltsm_flagToAnalog_RepairMbSetReceiver(dig_out.ltsm_flagToAnalog_RepairMbSetReceiver),
    .jtag_ltsm_flagToAnalog_LaneReversalApplied(dig_out.ltsm_flagToAnalog_LaneReversalApplied),
    .jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler(dig_out.ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .jtag_ltsm_state(dig_out.ltsm_state),
    .jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen(dig_out.ltsm_dbg_flagSbinitFirstClkPatternSeen),
    .jtag_ltsm_dbg_rxValidRisingEdge(dig_out.ltsm_dbg_rxValidRisingEdge),
    .jtag_ltsm_dbg_sbinitSendCount(dig_out.ltsm_dbg_sbinitSendCount),
    .jtag_ltsm_dbg_sbTxValid(dig_out.ltsm_dbg_sbTxValid),
    .jtag_ltsm_dbg_sbTxDin(dig_out.ltsm_dbg_sbTxDin),
    .jtag_ltsm_dbg_flagTrainError(dig_out.ltsm_dbg_flagTrainError),
    .jtag_ltsm_dbg_mbinitSubstate(dig_out.ltsm_dbg_mbinitSubstate),
    .jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount(dig_out.ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
    .jtag_ltsm_flagToAnalog_valVref_sendPattern(dig_out.ltsm_flagToAnalog_valVref_sendPattern),
    .jtag_ltsm_flagFromAnalog_valVref_detectedValPattern(dig_in.ltsm_flagFromAnalog_valVref_detectedValPattern),
    .jtag_ltsm_flagFromAnalog_valVref_finishedPattern(dig_in.ltsm_flagFromAnalog_valVref_finishedPattern),
    .jtag_ltsm_flagToAnalog_valVref_applyRxVref(dig_out.ltsm_flagToAnalog_valVref_applyRxVref),
    .jtag_ltsm_flagToAnalog_valVref_rxVrefCode(dig_out.ltsm_flagToAnalog_valVref_rxVrefCode),
    .jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied(dig_in.ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest(dig_out.ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold(dig_out.ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .jtag_ltsm_flagToAnalog_valVref_comparisonMode(dig_out.ltsm_flagToAnalog_valVref_comparisonMode),
    .jtag_ltsm_flagToAnalog_valVref_iterationCountSettings(dig_out.ltsm_flagToAnalog_valVref_iterationCountSettings),
    .jtag_ltsm_flagToAnalog_valVref_idleCountSettings(dig_out.ltsm_flagToAnalog_valVref_idleCountSettings),
    .jtag_ltsm_flagToAnalog_valVref_burstCountSettings(dig_out.ltsm_flagToAnalog_valVref_burstCountSettings),
    .jtag_ltsm_flagToAnalog_valVref_patternMode(dig_out.ltsm_flagToAnalog_valVref_patternMode),
    .jtag_ltsm_flagToAnalog_valVref_clockPhaseControl(dig_out.ltsm_flagToAnalog_valVref_clockPhaseControl),
    .jtag_ltsm_flagToAnalog_valVref_validPattern(dig_out.ltsm_flagToAnalog_valVref_validPattern),
    .jtag_ltsm_flagToAnalog_valVref_dataPattern(dig_out.ltsm_flagToAnalog_valVref_dataPattern),
    .jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors(dig_out.ltsm_flagToAnalog_valVref_clearComparisonErrors),
    .jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler(dig_out.ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .jtag_ltsm_flagToAnalog_dataVref_sendPattern(dig_out.ltsm_flagToAnalog_dataVref_sendPattern),
    .jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern(dig_in.ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .jtag_ltsm_flagFromAnalog_dataVref_finishedPattern(dig_in.ltsm_flagFromAnalog_dataVref_finishedPattern),
    .jtag_ltsm_flagToAnalog_dataVref_applyRxVref(dig_out.ltsm_flagToAnalog_dataVref_applyRxVref),
    .jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes(dig_out.ltsm_flagToAnalog_dataVref_rxVrefCodes),
    .jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied(dig_in.ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest(dig_out.ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold(dig_out.ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .jtag_ltsm_flagToAnalog_dataVref_comparisonMode(dig_out.ltsm_flagToAnalog_dataVref_comparisonMode),
    .jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings(dig_out.ltsm_flagToAnalog_dataVref_iterationCountSettings),
    .jtag_ltsm_flagToAnalog_dataVref_idleCountSettings(dig_out.ltsm_flagToAnalog_dataVref_idleCountSettings),
    .jtag_ltsm_flagToAnalog_dataVref_burstCountSettings(dig_out.ltsm_flagToAnalog_dataVref_burstCountSettings),
    .jtag_ltsm_flagToAnalog_dataVref_patternMode(dig_out.ltsm_flagToAnalog_dataVref_patternMode),
    .jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl(dig_out.ltsm_flagToAnalog_dataVref_clockPhaseControl),
    .jtag_ltsm_flagToAnalog_dataVref_validPattern(dig_out.ltsm_flagToAnalog_dataVref_validPattern),
    .jtag_ltsm_flagToAnalog_dataVref_dataPattern(dig_out.ltsm_flagToAnalog_dataVref_dataPattern),
    .jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors(dig_out.ltsm_flagToAnalog_dataVref_clearComparisonErrors),
    .jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler(dig_out.ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .jtag_ltsm_flagToAnalog_rxClkCal_doCalibration(dig_out.ltsm_flagToAnalog_rxClkCal_doCalibration),
    .jtag_ltsm_flagFromAnalog_rxClkCal_done(dig_in.ltsm_flagFromAnalog_rxClkCal_done),
    .jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack(dig_out.ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern(dig_out.ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(dig_in.ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler(dig_out.ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase(dig_out.ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode(dig_out.ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
    .jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied(dig_in.ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(dig_out.ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(dig_out.ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode(dig_out.ltsm_flagToAnalog_d2cReceiver_comparisonMode),
    .jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings(dig_out.ltsm_flagToAnalog_d2cReceiver_iterationCountSettings),
    .jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings(dig_out.ltsm_flagToAnalog_d2cReceiver_idleCountSettings),
    .jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings(dig_out.ltsm_flagToAnalog_d2cReceiver_burstCountSettings),
    .jtag_ltsm_flagToAnalog_d2cReceiver_patternMode(dig_out.ltsm_flagToAnalog_d2cReceiver_patternMode),
    .jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl(dig_out.ltsm_flagToAnalog_d2cReceiver_clockPhaseControl),
    .jtag_ltsm_flagToAnalog_d2cReceiver_validPattern(dig_out.ltsm_flagToAnalog_d2cReceiver_validPattern),
    .jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern(dig_out.ltsm_flagToAnalog_d2cReceiver_dataPattern),
    .jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler(dig_out.ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(dig_in.ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(dig_in.ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern(dig_out.ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(dig_in.ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew(dig_out.ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes(dig_out.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied(dig_in.ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(dig_out.ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(dig_in.ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(dig_out.ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew(dig_out.ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes(dig_out.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied(dig_in.ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest(dig_out.ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold(dig_out.ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode(dig_out.ltsm_flagToAnalog_rxDeskew_comparisonMode),
    .jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings(dig_out.ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
    .jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings(dig_out.ltsm_flagToAnalog_rxDeskew_idleCountSettings),
    .jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings(dig_out.ltsm_flagToAnalog_rxDeskew_burstCountSettings),
    .jtag_ltsm_flagToAnalog_rxDeskew_patternMode(dig_out.ltsm_flagToAnalog_rxDeskew_patternMode),
    .jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl(dig_out.ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
    .jtag_ltsm_flagToAnalog_rxDeskew_validPattern(dig_out.ltsm_flagToAnalog_rxDeskew_validPattern),
    .jtag_ltsm_flagToAnalog_rxDeskew_dataPattern(dig_out.ltsm_flagToAnalog_rxDeskew_dataPattern),
    .jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors(dig_out.ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
    .jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern(dig_in.ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain(dig_out.ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .jtag_ltsm_flagToAnalog_linkSpeed_speedCode(dig_out.ltsm_flagToAnalog_linkSpeed_speedCode),
    .jtag_ltsm_flagToAnalog_linkSpeed_applySpeed(dig_out.ltsm_flagToAnalog_linkSpeed_applySpeed),
    .jtag_ltsm_flagToAnalog_linkSpeed_electricalIdle(dig_out.ltsm_flagToAnalog_linkSpeed_electricalIdle),
    .jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(dig_in.ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .jtag_ltsm_linkSpeed_requestedSpeed(dig_in.ltsm_linkSpeed_requestedSpeed),
    .jtag_ltsm_flagFromAnalog_linkSpeed_speedApplied(dig_in.ltsm_flagFromAnalog_linkSpeed_speedApplied),
    .jtag_ltsm_dbg_mbtrainState(dig_out.ltsm_dbg_mbtrainState),
    .jtag_ltsm_dbg_mbtrainActiveSubstate(dig_out.ltsm_dbg_mbtrainActiveSubstate),
    .jtag_ltsm_dbg_mbtrainLastErrorCount(dig_out.ltsm_dbg_mbtrainLastErrorCount),
    .jtag_ltsm_dbg_mbtrainRetryCount(dig_out.ltsm_dbg_mbtrainRetryCount),
    .jtag_sb_tx_dout(dig_out.sb_tx_dout),
    .jtag_sb_tx_clk(dig_out.sb_tx_clk),
    .jtag_sb_rx_din(dig_in.sb_rx_din),
    .jtag_sb_rx_clk(dig_in.sb_rx_clk),
    .jtag_debug_sb_rx_overflow(dig_out.debug_sb_rx_overflow),
    .jtag_debug_ltsm_state(dig_out.debug_ltsm_state),
    .jtag_debug_ltsm_inband_pres(dig_out.debug_ltsm_inband_pres),
    .jtag_debug_fdi_link_init_state(dig_out.debug_fdi_link_init_state),
    .jtag_debug_rdi_state(dig_out.debug_rdi_state),
    .jtag_debug_fdi_to_rdi_state_req(dig_out.debug_fdi_to_rdi_state_req),
    .jtag_debug_arb_grant_ltsm(dig_out.debug_arb_grant_ltsm),
    .jtag_debug_arb_grant_fdi(dig_out.debug_arb_grant_fdi),
    .jtag_debug_arb_grant_rdi(dig_out.debug_arb_grant_rdi),
    .jtag_debug_arb_tx_locked(dig_out.debug_arb_tx_locked),
    .jtag_debug_arb_rr_last_source(dig_out.debug_arb_rr_last_source),
    .jtag_debug_arb_rr_last_granted_rdi(dig_out.debug_arb_rr_last_granted_rdi),
    .jtag_debug_arb_tx_fire(dig_out.debug_arb_tx_fire),
    .jtag_debug_rx_route_ltsm(dig_out.debug_rx_route_ltsm),
    .jtag_debug_rx_route_fdi(dig_out.debug_rx_route_fdi),
    .jtag_debug_rx_route_rdi(dig_out.debug_rx_route_rdi),
    .jtag_debug_rx_drop_unknown(dig_out.debug_rx_drop_unknown),
    .jtag_debug_rx_fire(dig_out.debug_rx_fire),
    .jtagFdi_clock(clock),
    .jtagFdi_reset_n(test_reset_n),
    .jtagFdi_cycles_1us(fdi_in.cycles_1us),
    .jtagFdi_timeout_disable(fdi_in.timeout_disable),
    .jtagFdi_fdi_lp_state_req(fdi_in.fdi_lp_state_req),
    .jtagFdi_fdi_lp_linkerror(fdi_in.fdi_lp_linkerror),
    .jtagFdi_fdi_lp_rx_active_sts(fdi_in.fdi_lp_rx_active_sts),
    .jtagFdi_fdi_lp_wake_req(fdi_in.fdi_lp_wake_req),
    .jtagFdi_fdi_lp_clk_ack(fdi_in.fdi_lp_clk_ack),
    .jtagFdi_fdi_lp_stall_ack(fdi_in.fdi_lp_stall_ack),
    .jtagFdi_fdi_pl_state_sts(fdi_out.fdi_pl_state_sts),
    .jtagFdi_fdi_pl_rx_active_req(fdi_out.fdi_pl_rx_active_req),
    .jtagFdi_fdi_pl_inband_pres(fdi_out.fdi_pl_inband_pres),
    .jtagFdi_fdi_pl_wake_ack(fdi_out.fdi_pl_wake_ack),
    .jtagFdi_fdi_pl_clk_req(fdi_out.fdi_pl_clk_req),
    .jtagFdi_fdi_pl_stall_req(fdi_out.fdi_pl_stall_req),
    .jtagFdi_fdi_active(fdi_out.fdi_active),
    .jtagFdi_debug_link_init_state(fdi_out.debug_link_init_state),
    .jtagFdi_rdi_lp_linkerror(fdi_out.rdi_lp_linkerror),
    .jtagFdi_rdi_lp_state_req(fdi_out.rdi_lp_state_req),
    .jtagFdi_rdi_pl_state_sts(fdi_in.rdi_pl_state_sts),
    .jtagFdi_rdi_pl_inband_pres(fdi_in.rdi_pl_inband_pres),
    .jtagFdi_fdiNeedsRdiAwake(fdi_out.fdiNeedsRdiAwake),
    .jtagFdi_rdiAwake(fdi_in.rdiAwake),
    .jtagFdi_rdiNeedsFdiAwake(fdi_in.rdiNeedsFdiAwake),
    .jtagFdi_fdiAwake(fdi_out.fdiAwake),
    .jtagFdi_rdi_pl_stall_req(fdi_in.rdi_pl_stall_req),
    .jtagFdi_rdi_lp_stall_ack(fdi_out.rdi_lp_stall_ack),
    .jtagFdi_sb_snd_valid(fdi_out.sb_snd_valid),
    .jtagFdi_sb_snd_msg(fdi_out.sb_snd_msg),
    .jtagFdi_sb_snd_ready(fdi_in.sb_snd_ready),
    .jtagFdi_sb_rcv_valid(fdi_in.sb_rcv_valid),
    .jtagFdi_sb_rcv_msg(fdi_in.sb_rcv_msg),
    .jtagFdi_sb_rcv_ready(fdi_out.sb_rcv_ready),
    .jtagRdi_clock(clock),
    .jtagRdi_reset_n(test_reset_n),
    .jtagRdi_ltsm_lp_wake_req(rdi_in.ltsm_lp_wake_req),
    .jtagRdi_ltsm_pl_wake_ack(rdi_out.ltsm_pl_wake_ack),
    .jtagRdi_ltsm_pl_clk_req(rdi_out.ltsm_pl_clk_req),
    .jtagRdi_ltsm_lp_clk_ack(rdi_in.ltsm_lp_clk_ack),
    .jtagRdi_lp_state_req(rdi_in.lp_state_req),
    .jtagRdi_pl_state_sts(rdi_out.pl_state_sts),
    .jtagRdi_pl_stallreq(rdi_out.pl_stallreq),
    .jtagRdi_lp_stallack(rdi_in.lp_stallack),
    .jtagRdi_rdi_pl_inband_pres(rdi_out.rdi_pl_inband_pres),
    .jtagRdi_ltsm_pl_inband_pres(rdi_in.ltsm_pl_inband_pres),
    .jtagRdi_fdiNeedsRdiAwake(rdi_in.fdiNeedsRdiAwake),
    .jtagRdi_rdiAwake(rdi_out.rdiAwake),
    .jtagRdi_rdiNeedsFdiAwake(rdi_out.rdiNeedsFdiAwake),
    .jtagRdi_fdiAwake(rdi_in.fdiAwake),
    .jtagRdi_sb_snd_valid(rdi_out.sb_snd_valid),
    .jtagRdi_sb_snd_msg(rdi_out.sb_snd_msg),
    .jtagRdi_sb_snd_ready(rdi_in.sb_snd_ready),
    .jtagRdi_sb_rcv_valid(rdi_in.sb_rcv_valid),
    .jtagRdi_sb_rcv_msg(rdi_in.sb_rcv_msg),
    .jtagRdi_sb_rcv_ready(rdi_out.sb_rcv_ready),
    .jtagRdi_lp_linkerror(rdi_in.lp_linkerror),
    .jtagRdi_pl_phyinrecenter(rdi_out.pl_phyinrecenter),
    .jtagRdi_timeout_disable(rdi_in.timeout_disable),
    .jtagRdi_cycles_1us(rdi_in.cycles_1us),
    .jtagLtsm_clock(clock),
    .jtagLtsm_reset_n(test_reset_n),
    .jtagLtsm_sb_tx_din(ltsm_out.sb_tx_din),
    .jtagLtsm_sb_tx_valid(ltsm_out.sb_tx_valid),
    .jtagLtsm_sb_tx_ready(ltsm_in.sb_tx_ready),
    .jtagLtsm_sb_rx_dout(ltsm_in.sb_rx_dout),
    .jtagLtsm_sb_rx_valid(ltsm_in.sb_rx_valid),
    .jtagLtsm_start(ltsm_in.jtagLtsm_start),
    .jtagLtsm_stable_clk(ltsm_in.stable_clk),
    .jtagLtsm_pll_locked(ltsm_in.pll_locked),
    .jtagLtsm_stable_supply(ltsm_in.stable_supply),
    .jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns(ltsm_in.flagFromAnalog_ReadyToExchangeClkPatterns),
    .jtagLtsm_flagFromAnalog_FinishedClkPatterns(ltsm_in.flagFromAnalog_FinishedClkPatterns),
    .jtagLtsm_flagFromAnalog_FinishedValTrainPattern(ltsm_in.flagFromAnalog_FinishedValTrainPattern),
    .jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(ltsm_in.flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(ltsm_in.flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L(ltsm_in.flagFromAnalog_clkPatternReceivedRTRK_L),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L(ltsm_in.flagFromAnalog_clkPatternReceivedRCKN_L),
    .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L(ltsm_in.flagFromAnalog_clkPatternReceivedRCKP_L),
    .jtagLtsm_flagFromAnalog_ValTrainPatternReceived(ltsm_in.flagFromAnalog_ValTrainPatternReceived),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived0),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived1),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived2),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived3),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived4),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived5),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived6),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived7),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived8),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived9),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived10),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived11),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived12),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived13),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived14),
    .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15(ltsm_in.flagFromAnalog_ReversalMbTrainPatternReceived15),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15(ltsm_in.flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .jtagLtsm_flagToAnalog_RepairClkState(ltsm_out.flagToAnalog_RepairClkState),
    .jtagLtsm_flagToAnalog_SendClkPatterns(ltsm_out.flagToAnalog_SendClkPatterns),
    .jtagLtsm_flagToAnalog_RepairValState(ltsm_out.flagToAnalog_RepairValState),
    .jtagLtsm_flagToAnalog_SendValTrainPattern(ltsm_out.flagToAnalog_SendValTrainPattern),
    .jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern(ltsm_out.flagToAnalog_ReversalMbSendLaneIDPattern),
    .jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern(ltsm_out.flagToAnalog_RepairMbSendLaneIDPattern),
    .jtagLtsm_flagToAnalog_RepairMbSetReceiver(ltsm_out.flagToAnalog_RepairMbSetReceiver),
    .jtagLtsm_flagToAnalog_LaneReversalApplied(ltsm_out.flagToAnalog_LaneReversalApplied),
    .jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler(ltsm_out.flagToAnalog_linkInit_resetLfsrScrambler),
    .jtagLtsm_state(ltsm_out.jtagLtsm_state),
    .jtagLtsm_dbg_flagSbinitFirstClkPatternSeen(ltsm_out.dbg_flagSbinitFirstClkPatternSeen),
    .jtagLtsm_dbg_rxValidRisingEdge(ltsm_out.dbg_rxValidRisingEdge),
    .jtagLtsm_dbg_sbinitSendCount(ltsm_out.dbg_sbinitSendCount),
    .jtagLtsm_dbg_sbTxValid(ltsm_out.dbg_sbTxValid),
    .jtagLtsm_dbg_sbTxDin(ltsm_out.dbg_sbTxDin),
    .jtagLtsm_dbg_flagTrainError(ltsm_out.dbg_flagTrainError),
    .jtagLtsm_dbg_mbinitSubstate(ltsm_out.dbg_mbinitSubstate),
    .jtagLtsm_dbg_mbinitParamSenderState(ltsm_out.dbg_mbinitParamSenderState),
    .jtagLtsm_dbg_mbinitParamReceiverState(ltsm_out.dbg_mbinitParamReceiverState),
    .jtagLtsm_dbg_mbinitCalSenderState(ltsm_out.dbg_mbinitCalSenderState),
    .jtagLtsm_dbg_mbinitCalReceiverState(ltsm_out.dbg_mbinitCalReceiverState),
    .jtagLtsm_dbg_mbinitRepairClkSenderState(ltsm_out.dbg_mbinitRepairClkSenderState),
    .jtagLtsm_dbg_mbinitRepairClkReceiverState(ltsm_out.dbg_mbinitRepairClkReceiverState),
    .jtagLtsm_dbg_mbinitRepairValSenderState(ltsm_out.dbg_mbinitRepairValSenderState),
    .jtagLtsm_dbg_mbinitRepairValReceiverState(ltsm_out.dbg_mbinitRepairValReceiverState),
    .jtagLtsm_dbg_mbinitReversalMbSenderState(ltsm_out.dbg_mbinitReversalMbSenderState),
    .jtagLtsm_dbg_mbinitReversalMbReceiverState(ltsm_out.dbg_mbinitReversalMbReceiverState),
    .jtagLtsm_dbg_mbinitRepairMbSenderState(ltsm_out.dbg_mbinitRepairMbSenderState),
    .jtagLtsm_dbg_mbinitRepairMbReceiverState(ltsm_out.dbg_mbinitRepairMbReceiverState),
    .jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount(ltsm_out.dbg_mbinitReversalMbReceivedSuccessCount),
    .jtagLtsm_flagToAnalog_valVref_sendPattern(ltsm_out.flagToAnalog_valVref_sendPattern),
    .jtagLtsm_flagFromAnalog_valVref_detectedValPattern(ltsm_in.flagFromAnalog_valVref_detectedValPattern),
    .jtagLtsm_flagFromAnalog_valVref_finishedPattern(ltsm_in.flagFromAnalog_valVref_finishedPattern),
    .jtagLtsm_flagToAnalog_valVref_applyRxVref(ltsm_out.flagToAnalog_valVref_applyRxVref),
    .jtagLtsm_flagToAnalog_valVref_rxVrefCode(ltsm_out.flagToAnalog_valVref_rxVrefCode),
    .jtagLtsm_flagFromAnalog_valVref_rxVrefApplied(ltsm_in.flagFromAnalog_valVref_rxVrefApplied),
    .jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest(ltsm_out.flagToAnalog_valVref_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold(ltsm_out.flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_valVref_comparisonMode(ltsm_out.flagToAnalog_valVref_comparisonMode),
    .jtagLtsm_flagToAnalog_valVref_iterationCountSettings(ltsm_out.flagToAnalog_valVref_iterationCountSettings),
    .jtagLtsm_flagToAnalog_valVref_idleCountSettings(ltsm_out.flagToAnalog_valVref_idleCountSettings),
    .jtagLtsm_flagToAnalog_valVref_burstCountSettings(ltsm_out.flagToAnalog_valVref_burstCountSettings),
    .jtagLtsm_flagToAnalog_valVref_patternMode(ltsm_out.flagToAnalog_valVref_patternMode),
    .jtagLtsm_flagToAnalog_valVref_clockPhaseControl(ltsm_out.flagToAnalog_valVref_clockPhaseControl),
    .jtagLtsm_flagToAnalog_valVref_validPattern(ltsm_out.flagToAnalog_valVref_validPattern),
    .jtagLtsm_flagToAnalog_valVref_dataPattern(ltsm_out.flagToAnalog_valVref_dataPattern),
    .jtagLtsm_flagToAnalog_valVref_clearComparisonErrors(ltsm_out.flagToAnalog_valVref_clearComparisonErrors),
    .jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler(ltsm_out.flagToAnalog_valVref_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_dataVref_sendPattern(ltsm_out.flagToAnalog_dataVref_sendPattern),
    .jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern(ltsm_in.flagFromAnalog_dataVref_detectedDataPattern),
    .jtagLtsm_flagFromAnalog_dataVref_finishedPattern(ltsm_in.flagFromAnalog_dataVref_finishedPattern),
    .jtagLtsm_flagToAnalog_dataVref_applyRxVref(ltsm_out.flagToAnalog_dataVref_applyRxVref),
    .jtagLtsm_flagToAnalog_dataVref_rxVrefCodes(ltsm_out.flagToAnalog_dataVref_rxVrefCodes),
    .jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied(ltsm_in.flagFromAnalog_dataVref_rxVrefApplied),
    .jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest(ltsm_out.flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold(ltsm_out.flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_dataVref_comparisonMode(ltsm_out.flagToAnalog_dataVref_comparisonMode),
    .jtagLtsm_flagToAnalog_dataVref_iterationCountSettings(ltsm_out.flagToAnalog_dataVref_iterationCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_idleCountSettings(ltsm_out.flagToAnalog_dataVref_idleCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_burstCountSettings(ltsm_out.flagToAnalog_dataVref_burstCountSettings),
    .jtagLtsm_flagToAnalog_dataVref_patternMode(ltsm_out.flagToAnalog_dataVref_patternMode),
    .jtagLtsm_flagToAnalog_dataVref_clockPhaseControl(ltsm_out.flagToAnalog_dataVref_clockPhaseControl),
    .jtagLtsm_flagToAnalog_dataVref_validPattern(ltsm_out.flagToAnalog_dataVref_validPattern),
    .jtagLtsm_flagToAnalog_dataVref_dataPattern(ltsm_out.flagToAnalog_dataVref_dataPattern),
    .jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors(ltsm_out.flagToAnalog_dataVref_clearComparisonErrors),
    .jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler(ltsm_out.flagToAnalog_dataVref_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_rxClkCal_doCalibration(ltsm_out.flagToAnalog_rxClkCal_doCalibration),
    .jtagLtsm_flagFromAnalog_rxClkCal_done(ltsm_in.flagFromAnalog_rxClkCal_done),
    .jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack(ltsm_out.flagToAnalog_rxClkCal_sendClockTrack),
    .jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern(ltsm_out.flagToAnalog_d2cSender_sendValTrainPattern),
    .jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent(ltsm_in.flagFromAnalog_d2cSender_valTrainPatternSent),
    .jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler(ltsm_out.flagToAnalog_d2cSender_resetLocalScrambler),
    .jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase(ltsm_out.flagToAnalog_d2cSender_applyTxClockPhase),
    .jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode(ltsm_out.flagToAnalog_d2cSender_txClockPhaseCode),
    .jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied(ltsm_in.flagFromAnalog_d2cSender_txClockPhaseApplied),
    .jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(ltsm_out.flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(ltsm_out.flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode(ltsm_out.flagToAnalog_d2cReceiver_comparisonMode),
    .jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings(ltsm_out.flagToAnalog_d2cReceiver_iterationCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings(ltsm_out.flagToAnalog_d2cReceiver_idleCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings(ltsm_out.flagToAnalog_d2cReceiver_burstCountSettings),
    .jtagLtsm_flagToAnalog_d2cReceiver_patternMode(ltsm_out.flagToAnalog_d2cReceiver_patternMode),
    .jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl(ltsm_out.flagToAnalog_d2cReceiver_clockPhaseControl),
    .jtagLtsm_flagToAnalog_d2cReceiver_validPattern(ltsm_out.flagToAnalog_d2cReceiver_validPattern),
    .jtagLtsm_flagToAnalog_d2cReceiver_dataPattern(ltsm_out.flagToAnalog_d2cReceiver_dataPattern),
    .jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler(ltsm_out.flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(ltsm_in.flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(ltsm_in.flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern(ltsm_out.flagToAnalog_d2cSender_sendLfsrPattern),
    .jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent(ltsm_in.flagFromAnalog_d2cSender_lfsrPatternSent),
    .jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew(ltsm_out.flagToAnalog_d2cSender_applyTxLaneDeskew),
    .jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes(ltsm_out.flagToAnalog_d2cSender_txLaneDeskewCodes),
    .jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied(ltsm_in.flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern(ltsm_out.flagToAnalog_rxDeskew_sendLfsrPattern),
    .jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent(ltsm_in.flagFromAnalog_rxDeskew_lfsrPatternSent),
    .jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(ltsm_out.flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew(ltsm_out.flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes(ltsm_out.flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied(ltsm_in.flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest(ltsm_out.flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold(ltsm_out.flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .jtagLtsm_flagToAnalog_rxDeskew_comparisonMode(ltsm_out.flagToAnalog_rxDeskew_comparisonMode),
    .jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings(ltsm_out.flagToAnalog_rxDeskew_iterationCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings(ltsm_out.flagToAnalog_rxDeskew_idleCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings(ltsm_out.flagToAnalog_rxDeskew_burstCountSettings),
    .jtagLtsm_flagToAnalog_rxDeskew_patternMode(ltsm_out.flagToAnalog_rxDeskew_patternMode),
    .jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl(ltsm_out.flagToAnalog_rxDeskew_clockPhaseControl),
    .jtagLtsm_flagToAnalog_rxDeskew_validPattern(ltsm_out.flagToAnalog_rxDeskew_validPattern),
    .jtagLtsm_flagToAnalog_rxDeskew_dataPattern(ltsm_out.flagToAnalog_rxDeskew_dataPattern),
    .jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors(ltsm_out.flagToAnalog_rxDeskew_clearComparisonErrors),
    .jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern(ltsm_in.flagFromAnalog_rxDeskew_detectedDataPattern),
    .jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain(ltsm_out.flagToLtsm_linkSpeed_phyInRetrain),
    .jtagLtsm_flagToAnalog_linkSpeed_speedCode(ltsm_out.flagToAnalog_linkSpeed_speedCode),
    .jtagLtsm_flagToAnalog_linkSpeed_applySpeed(ltsm_out.flagToAnalog_linkSpeed_applySpeed),
    .jtagLtsm_flagToAnalog_linkSpeed_electricalIdle(ltsm_out.flagToAnalog_linkSpeed_electricalIdle),
    .jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(ltsm_in.flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .jtagLtsm_linkSpeed_requestedSpeed(ltsm_in.linkSpeed_requestedSpeed),
    .jtagLtsm_flagFromAnalog_linkSpeed_speedApplied(ltsm_in.flagFromAnalog_linkSpeed_speedApplied),
    .jtagLtsm_dbg_mbtrainState(ltsm_out.dbg_mbtrainState),
    .jtagLtsm_dbg_mbtrainActiveSubstate(ltsm_out.dbg_mbtrainActiveSubstate),
    .jtagLtsm_dbg_mbtrainValVrefLocalState(ltsm_out.dbg_mbtrainValVrefLocalState),
    .jtagLtsm_dbg_mbtrainValVrefRemoteState(ltsm_out.dbg_mbtrainValVrefRemoteState),
    .jtagLtsm_dbg_mbtrainValVrefSweepState(ltsm_out.dbg_mbtrainValVrefSweepState),
    .jtagLtsm_dbg_mbtrainValVrefPointInitiatorState(ltsm_out.dbg_mbtrainValVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainValVrefPointResponderState(ltsm_out.dbg_mbtrainValVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainDataVrefLocalState(ltsm_out.dbg_mbtrainDataVrefLocalState),
    .jtagLtsm_dbg_mbtrainDataVrefRemoteState(ltsm_out.dbg_mbtrainDataVrefRemoteState),
    .jtagLtsm_dbg_mbtrainDataVrefSweepState(ltsm_out.dbg_mbtrainDataVrefSweepState),
    .jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState(ltsm_out.dbg_mbtrainDataVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainDataVrefPointResponderState(ltsm_out.dbg_mbtrainDataVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainSpeedIdleSenderState(ltsm_out.dbg_mbtrainSpeedIdleSenderState),
    .jtagLtsm_dbg_mbtrainSpeedIdleReceiverState(ltsm_out.dbg_mbtrainSpeedIdleReceiverState),
    .jtagLtsm_dbg_mbtrainTxSelfCalSenderState(ltsm_out.dbg_mbtrainTxSelfCalSenderState),
    .jtagLtsm_dbg_mbtrainTxSelfCalReceiverState(ltsm_out.dbg_mbtrainTxSelfCalReceiverState),
    .jtagLtsm_dbg_mbtrainRxClkCalSenderState(ltsm_out.dbg_mbtrainRxClkCalSenderState),
    .jtagLtsm_dbg_mbtrainRxClkCalReceiverState(ltsm_out.dbg_mbtrainRxClkCalReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterSenderState(ltsm_out.dbg_mbtrainValTrainCenterSenderState),
    .jtagLtsm_dbg_mbtrainValTrainCenterReceiverState(ltsm_out.dbg_mbtrainValTrainCenterReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState(ltsm_out.dbg_mbtrainValTrainCenterD2cSenderState),
    .jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState(ltsm_out.dbg_mbtrainValTrainCenterD2cReceiverState),
    .jtagLtsm_dbg_mbtrainValTrainCenterSweepState(ltsm_out.dbg_mbtrainValTrainCenterSweepState),
    .jtagLtsm_dbg_mbtrainValTrainVrefLocalState(ltsm_out.dbg_mbtrainValTrainVrefLocalState),
    .jtagLtsm_dbg_mbtrainValTrainVrefRemoteState(ltsm_out.dbg_mbtrainValTrainVrefRemoteState),
    .jtagLtsm_dbg_mbtrainValTrainVrefSweepState(ltsm_out.dbg_mbtrainValTrainVrefSweepState),
    .jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState(ltsm_out.dbg_mbtrainValTrainVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState(ltsm_out.dbg_mbtrainValTrainVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState(ltsm_out.dbg_mbtrainDataTrainCenter1SenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState(ltsm_out.dbg_mbtrainDataTrainCenter1ReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState(ltsm_out.dbg_mbtrainDataTrainCenter1D2cSenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState(ltsm_out.dbg_mbtrainDataTrainCenter1D2cReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState(ltsm_out.dbg_mbtrainDataTrainCenter1SweepState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefLocalState(ltsm_out.dbg_mbtrainDataTrainVrefLocalState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState(ltsm_out.dbg_mbtrainDataTrainVrefRemoteState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefSweepState(ltsm_out.dbg_mbtrainDataTrainVrefSweepState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState(ltsm_out.dbg_mbtrainDataTrainVrefPointInitiatorState),
    .jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState(ltsm_out.dbg_mbtrainDataTrainVrefPointResponderState),
    .jtagLtsm_dbg_mbtrainRxDeskewLocalState(ltsm_out.dbg_mbtrainRxDeskewLocalState),
    .jtagLtsm_dbg_mbtrainRxDeskewRemoteState(ltsm_out.dbg_mbtrainRxDeskewRemoteState),
    .jtagLtsm_dbg_mbtrainRxDeskewSweepState(ltsm_out.dbg_mbtrainRxDeskewSweepState),
    .jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState(ltsm_out.dbg_mbtrainRxDeskewPointInitiatorState),
    .jtagLtsm_dbg_mbtrainRxDeskewPointResponderState(ltsm_out.dbg_mbtrainRxDeskewPointResponderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState(ltsm_out.dbg_mbtrainDataTrainCenter2SenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState(ltsm_out.dbg_mbtrainDataTrainCenter2ReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState(ltsm_out.dbg_mbtrainDataTrainCenter2D2cSenderState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState(ltsm_out.dbg_mbtrainDataTrainCenter2D2cReceiverState),
    .jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState(ltsm_out.dbg_mbtrainDataTrainCenter2SweepState),
    .jtagLtsm_dbg_mbtrainLinkSpeedSenderState(ltsm_out.dbg_mbtrainLinkSpeedSenderState),
    .jtagLtsm_dbg_mbtrainLinkSpeedReceiverState(ltsm_out.dbg_mbtrainLinkSpeedReceiverState),
    .jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState(ltsm_out.dbg_mbtrainLinkSpeedD2cSenderState),
    .jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState(ltsm_out.dbg_mbtrainLinkSpeedD2cReceiverState),
    .jtagLtsm_dbg_mbtrainLastErrorCount(ltsm_out.dbg_mbtrainLastErrorCount),
    .jtagLtsm_dbg_mbtrainRetryCount(ltsm_out.dbg_mbtrainRetryCount),
    .jtagPhy_ltsm_flagToAnalog_RepairClkState(phy_in.flagToAnalog_RepairClkState),
    .jtagPhy_ltsm_flagToAnalog_SendClkPatterns(phy_in.flagToAnalog_SendClkPatterns),
    .jtagPhy_ltsm_flagToAnalog_RepairValState(phy_in.flagToAnalog_RepairValState),
    .jtagPhy_ltsm_flagToAnalog_SendValTrainPattern(phy_in.flagToAnalog_SendValTrainPattern),
    .jtagPhy_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(phy_in.flagToAnalog_ReversalMbSendLaneIDPattern),
    .jtagPhy_ltsm_flagToAnalog_RepairMbSendLaneIDPattern(phy_in.flagToAnalog_RepairMbSendLaneIDPattern),
    .jtagPhy_ltsm_flagToAnalog_RepairMbSetReceiver(phy_in.flagToAnalog_RepairMbSetReceiver),
    .jtagPhy_ltsm_flagToAnalog_LaneReversalApplied(phy_in.flagToAnalog_LaneReversalApplied),
    .jtagPhy_ltsm_flagToAnalog_linkInit_resetLfsrScrambler(phy_in.flagToAnalog_linkInit_resetLfsrScrambler),
    .jtagPhy_ltsm_flagToAnalog_valVref_sendPattern(phy_in.flagToAnalog_valVref_sendPattern),
    .jtagPhy_ltsm_flagToAnalog_valVref_applyRxVref(phy_in.flagToAnalog_valVref_applyRxVref),
    .jtagPhy_ltsm_flagToAnalog_valVref_rxVrefCode(phy_in.flagToAnalog_valVref_rxVrefCode),
    .jtagPhy_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest(phy_in.flagToAnalog_valVref_configureRxInitD2CPointTest),
    .jtagPhy_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold(phy_in.flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .jtagPhy_ltsm_flagToAnalog_valVref_comparisonMode(phy_in.flagToAnalog_valVref_comparisonMode),
    .jtagPhy_ltsm_flagToAnalog_valVref_iterationCountSettings(phy_in.flagToAnalog_valVref_iterationCountSettings),
    .jtagPhy_ltsm_flagToAnalog_valVref_idleCountSettings(phy_in.flagToAnalog_valVref_idleCountSettings),
    .jtagPhy_ltsm_flagToAnalog_valVref_burstCountSettings(phy_in.flagToAnalog_valVref_burstCountSettings),
    .jtagPhy_ltsm_flagToAnalog_valVref_patternMode(phy_in.flagToAnalog_valVref_patternMode),
    .jtagPhy_ltsm_flagToAnalog_valVref_clockPhaseControl(phy_in.flagToAnalog_valVref_clockPhaseControl),
    .jtagPhy_ltsm_flagToAnalog_valVref_validPattern(phy_in.flagToAnalog_valVref_validPattern),
    .jtagPhy_ltsm_flagToAnalog_valVref_dataPattern(phy_in.flagToAnalog_valVref_dataPattern),
    .jtagPhy_ltsm_flagToAnalog_valVref_clearComparisonErrors(phy_in.flagToAnalog_valVref_clearComparisonErrors),
    .jtagPhy_ltsm_flagToAnalog_valVref_resetLocalTxScrambler(phy_in.flagToAnalog_valVref_resetLocalTxScrambler),
    .jtagPhy_ltsm_flagToAnalog_dataVref_sendPattern(phy_in.flagToAnalog_dataVref_sendPattern),
    .jtagPhy_ltsm_flagToAnalog_dataVref_applyRxVref(phy_in.flagToAnalog_dataVref_applyRxVref),
    .jtagPhy_ltsm_flagToAnalog_dataVref_rxVrefCodes(phy_in.flagToAnalog_dataVref_rxVrefCodes),
    .jtagPhy_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest(phy_in.flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .jtagPhy_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold(phy_in.flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .jtagPhy_ltsm_flagToAnalog_dataVref_comparisonMode(phy_in.flagToAnalog_dataVref_comparisonMode),
    .jtagPhy_ltsm_flagToAnalog_dataVref_iterationCountSettings(phy_in.flagToAnalog_dataVref_iterationCountSettings),
    .jtagPhy_ltsm_flagToAnalog_dataVref_idleCountSettings(phy_in.flagToAnalog_dataVref_idleCountSettings),
    .jtagPhy_ltsm_flagToAnalog_dataVref_burstCountSettings(phy_in.flagToAnalog_dataVref_burstCountSettings),
    .jtagPhy_ltsm_flagToAnalog_dataVref_patternMode(phy_in.flagToAnalog_dataVref_patternMode),
    .jtagPhy_ltsm_flagToAnalog_dataVref_clockPhaseControl(phy_in.flagToAnalog_dataVref_clockPhaseControl),
    .jtagPhy_ltsm_flagToAnalog_dataVref_validPattern(phy_in.flagToAnalog_dataVref_validPattern),
    .jtagPhy_ltsm_flagToAnalog_dataVref_dataPattern(phy_in.flagToAnalog_dataVref_dataPattern),
    .jtagPhy_ltsm_flagToAnalog_dataVref_clearComparisonErrors(phy_in.flagToAnalog_dataVref_clearComparisonErrors),
    .jtagPhy_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler(phy_in.flagToAnalog_dataVref_resetLocalTxScrambler),
    .jtagPhy_ltsm_flagToAnalog_rxClkCal_doCalibration(phy_in.flagToAnalog_rxClkCal_doCalibration),
    .jtagPhy_ltsm_flagToAnalog_rxClkCal_sendClockTrack(phy_in.flagToAnalog_rxClkCal_sendClockTrack),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_sendValTrainPattern(phy_in.flagToAnalog_d2cSender_sendValTrainPattern),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_resetLocalScrambler(phy_in.flagToAnalog_d2cSender_resetLocalScrambler),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_applyTxClockPhase(phy_in.flagToAnalog_d2cSender_applyTxClockPhase),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_txClockPhaseCode(phy_in.flagToAnalog_d2cSender_txClockPhaseCode),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest(phy_in.flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold(phy_in.flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_comparisonMode(phy_in.flagToAnalog_d2cReceiver_comparisonMode),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings(phy_in.flagToAnalog_d2cReceiver_iterationCountSettings),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_idleCountSettings(phy_in.flagToAnalog_d2cReceiver_idleCountSettings),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_burstCountSettings(phy_in.flagToAnalog_d2cReceiver_burstCountSettings),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_patternMode(phy_in.flagToAnalog_d2cReceiver_patternMode),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl(phy_in.flagToAnalog_d2cReceiver_clockPhaseControl),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_validPattern(phy_in.flagToAnalog_d2cReceiver_validPattern),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_dataPattern(phy_in.flagToAnalog_d2cReceiver_dataPattern),
    .jtagPhy_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler(phy_in.flagToAnalog_d2cReceiver_resetLocalRxScrambler),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_sendLfsrPattern(phy_in.flagToAnalog_d2cSender_sendLfsrPattern),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew(phy_in.flagToAnalog_d2cSender_applyTxLaneDeskew),
    .jtagPhy_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes(phy_in.flagToAnalog_d2cSender_txLaneDeskewCodes),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(phy_in.flagToAnalog_rxDeskew_sendLfsrPattern),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(phy_in.flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew(phy_in.flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes(phy_in.flagToAnalog_rxDeskew_rxLaneDeskewCodes),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest(phy_in.flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold(phy_in.flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_comparisonMode(phy_in.flagToAnalog_rxDeskew_comparisonMode),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_iterationCountSettings(phy_in.flagToAnalog_rxDeskew_iterationCountSettings),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_idleCountSettings(phy_in.flagToAnalog_rxDeskew_idleCountSettings),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_burstCountSettings(phy_in.flagToAnalog_rxDeskew_burstCountSettings),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_patternMode(phy_in.flagToAnalog_rxDeskew_patternMode),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_clockPhaseControl(phy_in.flagToAnalog_rxDeskew_clockPhaseControl),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_validPattern(phy_in.flagToAnalog_rxDeskew_validPattern),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_dataPattern(phy_in.flagToAnalog_rxDeskew_dataPattern),
    .jtagPhy_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors(phy_in.flagToAnalog_rxDeskew_clearComparisonErrors),
    .jtagPhy_ltsm_flagToAnalog_linkSpeed_speedCode(phy_in.flagToAnalog_linkSpeed_speedCode),
    .jtagPhy_ltsm_flagToAnalog_linkSpeed_applySpeed(phy_in.flagToAnalog_linkSpeed_applySpeed),
    .jtagPhy_ltsm_flagToAnalog_linkSpeed_electricalIdle(phy_in.flagToAnalog_linkSpeed_electricalIdle),
    .jtagPhy_ltsm_stable_clk(phy_out.stable_clk),
    .jtagPhy_ltsm_pll_locked(phy_out.pll_locked),
    .jtagPhy_ltsm_stable_supply(phy_out.stable_supply),
    .jtagPhy_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns(phy_out.flagFromAnalog_ReadyToExchangeClkPatterns),
    .jtagPhy_ltsm_flagFromAnalog_FinishedClkPatterns(phy_out.flagFromAnalog_FinishedClkPatterns),
    .jtagPhy_ltsm_flagFromAnalog_FinishedValTrainPattern(phy_out.flagFromAnalog_FinishedValTrainPattern),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(phy_out.flagFromAnalog_ReversalMbFinishedLaneIDPattern),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(phy_out.flagFromAnalog_RepairMbFinishedLaneIDPattern),
    .jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L(phy_out.flagFromAnalog_clkPatternReceivedRTRK_L),
    .jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L(phy_out.flagFromAnalog_clkPatternReceivedRCKN_L),
    .jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L(phy_out.flagFromAnalog_clkPatternReceivedRCKP_L),
    .jtagPhy_ltsm_flagFromAnalog_ValTrainPatternReceived(phy_out.flagFromAnalog_ValTrainPatternReceived),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived0),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived1),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived2),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived3),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived4),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived5),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived6),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived7),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived8),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived9),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived10),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived11),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived12),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived13),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived14),
    .jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15(phy_out.flagFromAnalog_ReversalMbTrainPatternReceived15),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern0),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern1),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern2),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern3),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern4),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern5),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern6),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern7),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern8),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern9),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern10),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern11),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern12),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern13),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern14),
    .jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15(phy_out.flagFromAnalog_RepairMbDetectedLaneIDPattern15),
    .jtagPhy_ltsm_flagFromAnalog_valVref_detectedValPattern(phy_out.flagFromAnalog_valVref_detectedValPattern),
    .jtagPhy_ltsm_flagFromAnalog_valVref_finishedPattern(phy_out.flagFromAnalog_valVref_finishedPattern),
    .jtagPhy_ltsm_flagFromAnalog_valVref_rxVrefApplied(phy_out.flagFromAnalog_valVref_rxVrefApplied),
    .jtagPhy_ltsm_flagFromAnalog_dataVref_detectedDataPattern(phy_out.flagFromAnalog_dataVref_detectedDataPattern),
    .jtagPhy_ltsm_flagFromAnalog_dataVref_finishedPattern(phy_out.flagFromAnalog_dataVref_finishedPattern),
    .jtagPhy_ltsm_flagFromAnalog_dataVref_rxVrefApplied(phy_out.flagFromAnalog_dataVref_rxVrefApplied),
    .jtagPhy_ltsm_flagFromAnalog_rxClkCal_done(phy_out.flagFromAnalog_rxClkCal_done),
    .jtagPhy_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(phy_out.flagFromAnalog_d2cSender_valTrainPatternSent),
    .jtagPhy_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied(phy_out.flagFromAnalog_d2cSender_txClockPhaseApplied),
    .jtagPhy_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(phy_out.flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .jtagPhy_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(phy_out.flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .jtagPhy_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(phy_out.flagFromAnalog_d2cSender_lfsrPatternSent),
    .jtagPhy_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied(phy_out.flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .jtagPhy_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(phy_out.flagFromAnalog_rxDeskew_lfsrPatternSent),
    .jtagPhy_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied(phy_out.flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .jtagPhy_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern(phy_out.flagFromAnalog_rxDeskew_detectedDataPattern),
    .jtagPhy_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(phy_out.flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .jtagPhy_ltsm_flagFromAnalog_linkSpeed_speedApplied(phy_out.flagFromAnalog_linkSpeed_speedApplied)
  );

endmodule

`default_nettype wire
