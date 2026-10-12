`default_nettype none

// ============================================================================
// D2DAdapterLinkMgmtLtsmSbJtagTop
// JTAG test wrapper around D2DAdapterLinkMgmtLtsmSBTop. Every IO of the core top
// can be routed either to its functional pin or to a JTAG Test Data Register
// (TDR), selected by testModeDigital.
//
// Port naming:
//   <name>       Functional pin. Same name, type and direction as in D2DAdapterLinkMgmtLtsmSBTop.
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
// Parameters are identical to D2DAdapterLinkMgmtLtsmSBTop and passed straight through.
// ============================================================================

module D2DAdapterLinkMgmtLtsmSbJtagTop #(
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
  // TEST MODE SELECT
  // 0: functional pins drive/observe the core. 1: jtag_* (TDR) pins do.
  // ==========================================================================
  input wire logic testModeDigital,

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

  // LTSM MBTRAIN.VALTRAINCENTER interface.
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode,
  input wire logic            jtag_ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload,

  // LTSM MBTRAIN.VALTRAINVREF interface.
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_sendPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_valTrainVref_detectedValPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_valTrainVref_finishedPattern,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_applyRxVref,
  output var logic [validVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_valTrainVref_rxVrefCode,
  input wire logic           jtag_ltsm_flagFromAnalog_valTrainVref_rxVrefApplied,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valTrainVref_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valTrainVref_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_valTrainVref_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_valTrainVref_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_valTrainVref_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_valTrainVref_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors,
  output var logic           jtag_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler,

  // LTSM MBTRAIN.DATATRAINCENTER1 interface.
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload,

  // LTSM MBTRAIN.DATATRAINVREF interface.
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_sendPattern,
  input wire logic [dataLaneCount-1:0] jtag_ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_dataTrainVref_finishedPattern,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_applyRxVref,
  output var logic [dataLaneCount*dataVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes,
  input wire logic           jtag_ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataTrainVref_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_dataTrainVref_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_dataTrainVref_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_dataTrainVref_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors,
  output var logic           jtag_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler,

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

  // LTSM MBTRAIN.DATATRAINCENTER2 interface.
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode,
  input wire logic            jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo,
  input wire logic [63:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload,

  // LTSM MBTRAIN.LINKSPEED interface.
  output var logic           jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern,
  input wire logic           jtag_ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent,
  output var logic           jtag_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings,
  output var logic [15:0]    jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode,
  output var logic [3:0]     jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern,
  output var logic [2:0]     jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern,
  output var logic           jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler,
  input wire logic [15:0]    jtag_ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful,
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
  output var logic jtag_debug_rx_fire
);

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
  logic core_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
  logic core_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
  logic core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied;
  logic core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
  logic core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
  logic core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo;
  logic [63:0] core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload;
  logic core_ltsm_flagToAnalog_valTrainVref_sendPattern;
  logic core_ltsm_flagFromAnalog_valTrainVref_detectedValPattern;
  logic core_ltsm_flagFromAnalog_valTrainVref_finishedPattern;
  logic core_ltsm_flagToAnalog_valTrainVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] core_ltsm_flagToAnalog_valTrainVref_rxVrefCode;
  logic core_ltsm_flagFromAnalog_valTrainVref_rxVrefApplied;
  logic core_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_valTrainVref_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_valTrainVref_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_valTrainVref_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_valTrainVref_burstCountSettings;
  logic core_ltsm_flagToAnalog_valTrainVref_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_valTrainVref_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_valTrainVref_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_valTrainVref_dataPattern;
  logic core_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors;
  logic core_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
  logic core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
  logic core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo;
  logic [63:0] core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload;
  logic core_ltsm_flagToAnalog_dataTrainVref_sendPattern;
  logic [dataLaneCount-1:0] core_ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern;
  logic core_ltsm_flagFromAnalog_dataTrainVref_finishedPattern;
  logic core_ltsm_flagToAnalog_dataTrainVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] core_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes;
  logic core_ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied;
  logic core_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_dataTrainVref_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_dataTrainVref_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_dataTrainVref_burstCountSettings;
  logic core_ltsm_flagToAnalog_dataTrainVref_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_dataTrainVref_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_dataTrainVref_dataPattern;
  logic core_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors;
  logic core_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
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
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
  logic core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
  logic core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
  logic core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo;
  logic [63:0] core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload;
  logic core_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic core_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
  logic core_ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent;
  logic core_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
  logic core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
  logic core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
  logic [15:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
  logic core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
  logic [3:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
  logic [2:0] core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
  logic core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  logic [15:0] core_ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful;
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
  assign core_clock = testModeDigital ? jtag_clock : clock;
  assign core_reset_n = testModeDigital ? jtag_reset_n : reset_n;
  assign core_fdi_lp_state_req = testModeDigital ? jtag_fdi_lp_state_req : fdi_lp_state_req;
  assign core_fdi_lp_linkerror = testModeDigital ? jtag_fdi_lp_linkerror : fdi_lp_linkerror;
  assign core_fdi_lp_rx_active_sts = testModeDigital ? jtag_fdi_lp_rx_active_sts : fdi_lp_rx_active_sts;
  assign core_fdi_lp_wake_req = testModeDigital ? jtag_fdi_lp_wake_req : fdi_lp_wake_req;
  assign core_fdi_lp_clk_ack = testModeDigital ? jtag_fdi_lp_clk_ack : fdi_lp_clk_ack;
  assign core_fdi_lp_stall_ack = testModeDigital ? jtag_fdi_lp_stall_ack : fdi_lp_stall_ack;
  assign core_cycles_1us = testModeDigital ? jtag_cycles_1us : cycles_1us;
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
  assign core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent : ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent;
  assign core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied : ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied;
  assign core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo : ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo;
  assign core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload : ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload;
  assign core_ltsm_flagFromAnalog_valTrainVref_detectedValPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_valTrainVref_detectedValPattern : ltsm_flagFromAnalog_valTrainVref_detectedValPattern;
  assign core_ltsm_flagFromAnalog_valTrainVref_finishedPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_valTrainVref_finishedPattern : ltsm_flagFromAnalog_valTrainVref_finishedPattern;
  assign core_ltsm_flagFromAnalog_valTrainVref_rxVrefApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_valTrainVref_rxVrefApplied : ltsm_flagFromAnalog_valTrainVref_rxVrefApplied;
  assign core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent : ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied : ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied;
  assign core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied : ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied;
  assign core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo : ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo;
  assign core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload : ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload;
  assign core_ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern : ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern;
  assign core_ltsm_flagFromAnalog_dataTrainVref_finishedPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_dataTrainVref_finishedPattern : ltsm_flagFromAnalog_dataTrainVref_finishedPattern;
  assign core_ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied : ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied;
  assign core_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent : ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied : ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  assign core_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = testModeDigital ? jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern : ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  assign core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent : ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied : ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied;
  assign core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo : ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo;
  assign core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload : ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload;
  assign core_ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent : ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent;
  assign core_ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful = testModeDigital ? jtag_ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful : ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful;
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
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
  assign jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
  assign jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode;
  assign jtag_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_valTrainVref_sendPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_sendPattern;
  assign jtag_ltsm_flagToAnalog_valTrainVref_sendPattern = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_sendPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_applyRxVref = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_applyRxVref;
  assign jtag_ltsm_flagToAnalog_valTrainVref_applyRxVref = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_valTrainVref_rxVrefCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_rxVrefCode;
  assign jtag_ltsm_flagToAnalog_valTrainVref_rxVrefCode = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_rxVrefCode : '0;
  assign ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_valTrainVref_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_comparisonMode;
  assign jtag_ltsm_flagToAnalog_valTrainVref_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_valTrainVref_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_valTrainVref_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_valTrainVref_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_valTrainVref_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_patternMode;
  assign jtag_ltsm_flagToAnalog_valTrainVref_patternMode = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_patternMode : '0;
  assign ltsm_flagToAnalog_valTrainVref_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_valTrainVref_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_valTrainVref_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_validPattern;
  assign jtag_ltsm_flagToAnalog_valTrainVref_validPattern = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_validPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_dataPattern;
  assign jtag_ltsm_flagToAnalog_valTrainVref_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_dataPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_clearComparisonErrors = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors;
  assign jtag_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler;
  assign jtag_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler = testModeDigital ? core_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_dataTrainVref_sendPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_sendPattern;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_sendPattern = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_sendPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_applyRxVref = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_applyRxVref;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_applyRxVref = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_dataTrainVref_rxVrefCodes = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes : '0;
  assign ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_dataTrainVref_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_comparisonMode;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_dataTrainVref_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_patternMode;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_patternMode = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_patternMode : '0;
  assign ltsm_flagToAnalog_dataTrainVref_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_dataTrainVref_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_validPattern;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_validPattern = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_validPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_dataPattern;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_dataPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
  assign jtag_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler = testModeDigital ? core_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler : '0;
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
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode;
  assign jtag_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler : '0;
  assign ltsm_flagToLtsm_linkSpeed_phyInRetrain = testModeDigital ? '0 : core_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  assign jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain = testModeDigital ? core_ltsm_flagToLtsm_linkSpeed_phyInRetrain : '0;
  assign ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
  assign jtag_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
  assign jtag_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler = testModeDigital ? '0 : core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  assign jtag_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler = testModeDigital ? core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler : '0;
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
  D2DAdapterLinkMgmtLtsmSBTop #(
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
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern                 (core_ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent               (core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler                 (core_ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase                   (core_ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode                    (core_ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied               (core_ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest       (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold   (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode                    (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings            (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings                 (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings                (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode                       (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl                 (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern                      (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern                       (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler             (core_ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo         (core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload         (core_ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_valTrainVref_sendPattern                                     (core_ltsm_flagToAnalog_valTrainVref_sendPattern),
    .ltsm_flagFromAnalog_valTrainVref_detectedValPattern                            (core_ltsm_flagFromAnalog_valTrainVref_detectedValPattern),
    .ltsm_flagFromAnalog_valTrainVref_finishedPattern                               (core_ltsm_flagFromAnalog_valTrainVref_finishedPattern),
    .ltsm_flagToAnalog_valTrainVref_applyRxVref                                     (core_ltsm_flagToAnalog_valTrainVref_applyRxVref),
    .ltsm_flagToAnalog_valTrainVref_rxVrefCode                                      (core_ltsm_flagToAnalog_valTrainVref_rxVrefCode),
    .ltsm_flagFromAnalog_valTrainVref_rxVrefApplied                                 (core_ltsm_flagFromAnalog_valTrainVref_rxVrefApplied),
    .ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest                     (core_ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold                 (core_ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_valTrainVref_comparisonMode                                  (core_ltsm_flagToAnalog_valTrainVref_comparisonMode),
    .ltsm_flagToAnalog_valTrainVref_iterationCountSettings                          (core_ltsm_flagToAnalog_valTrainVref_iterationCountSettings),
    .ltsm_flagToAnalog_valTrainVref_idleCountSettings                               (core_ltsm_flagToAnalog_valTrainVref_idleCountSettings),
    .ltsm_flagToAnalog_valTrainVref_burstCountSettings                              (core_ltsm_flagToAnalog_valTrainVref_burstCountSettings),
    .ltsm_flagToAnalog_valTrainVref_patternMode                                     (core_ltsm_flagToAnalog_valTrainVref_patternMode),
    .ltsm_flagToAnalog_valTrainVref_clockPhaseControl                               (core_ltsm_flagToAnalog_valTrainVref_clockPhaseControl),
    .ltsm_flagToAnalog_valTrainVref_validPattern                                    (core_ltsm_flagToAnalog_valTrainVref_validPattern),
    .ltsm_flagToAnalog_valTrainVref_dataPattern                                     (core_ltsm_flagToAnalog_valTrainVref_dataPattern),
    .ltsm_flagToAnalog_valTrainVref_clearComparisonErrors                           (core_ltsm_flagToAnalog_valTrainVref_clearComparisonErrors),
    .ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler                           (core_ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern                   (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent                 (core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler               (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase                 (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode                  (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied             (core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew                 (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes                 (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied             (core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode                  (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings          (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings               (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings              (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode                     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl               (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern                    (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern                     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler           (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo       (core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload       (core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_dataTrainVref_sendPattern                                    (core_ltsm_flagToAnalog_dataTrainVref_sendPattern),
    .ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern                          (core_ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataTrainVref_finishedPattern                              (core_ltsm_flagFromAnalog_dataTrainVref_finishedPattern),
    .ltsm_flagToAnalog_dataTrainVref_applyRxVref                                    (core_ltsm_flagToAnalog_dataTrainVref_applyRxVref),
    .ltsm_flagToAnalog_dataTrainVref_rxVrefCodes                                    (core_ltsm_flagToAnalog_dataTrainVref_rxVrefCodes),
    .ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied                                (core_ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied),
    .ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest                    (core_ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold                (core_ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_dataTrainVref_comparisonMode                                 (core_ltsm_flagToAnalog_dataTrainVref_comparisonMode),
    .ltsm_flagToAnalog_dataTrainVref_iterationCountSettings                         (core_ltsm_flagToAnalog_dataTrainVref_iterationCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_idleCountSettings                              (core_ltsm_flagToAnalog_dataTrainVref_idleCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_burstCountSettings                             (core_ltsm_flagToAnalog_dataTrainVref_burstCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_patternMode                                    (core_ltsm_flagToAnalog_dataTrainVref_patternMode),
    .ltsm_flagToAnalog_dataTrainVref_clockPhaseControl                              (core_ltsm_flagToAnalog_dataTrainVref_clockPhaseControl),
    .ltsm_flagToAnalog_dataTrainVref_validPattern                                   (core_ltsm_flagToAnalog_dataTrainVref_validPattern),
    .ltsm_flagToAnalog_dataTrainVref_dataPattern                                    (core_ltsm_flagToAnalog_dataTrainVref_dataPattern),
    .ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors                          (core_ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors),
    .ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler                          (core_ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler),
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
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern                   (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent                 (core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler               (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase                 (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode                  (core_ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied             (core_ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode                  (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings          (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings               (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings              (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode                     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl               (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern                    (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern                     (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler           (core_ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo       (core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload       (core_ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .ltsm_flagToLtsm_linkSpeed_phyInRetrain                                         (core_ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern                          (core_ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent                        (core_ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler                      (core_ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest            (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold        (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode                         (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings                 (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings                      (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings                     (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode                            (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl                      (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern                           (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern                            (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler                  (core_ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful             (core_ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
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
    .debug_rx_fire                                                                  (core_debug_rx_fire)
  );

endmodule

`default_nettype wire
