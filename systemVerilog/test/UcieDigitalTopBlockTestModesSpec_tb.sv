// Smoke test of the UcieDigitalTop block isolation test modes
// (testModeFdi, testModeRdi, testModeLtsm).
// GENERATED from the UcieDigitalTop port list; regenerate if the ports change.
//
// For each mode the test:
//   - sets only that mode, runs only that block's jtag<Blk>_clock, keeps the
//     functional clock stopped and the functional reset_n asserted;
//   - resets the block through jtag<Blk>_reset_n and drives a stimulus that
//     makes it react (state request to Active, LTSM start);
//   - checks that the block's jtag<Blk>_* outputs change, i.e. it runs on the
//     TDR clock/reset and is observable;
//   - checks that every functional output and every jtag_* (digital TDR)
//     output stays frozen, and that the other blocks' jtag<Blk>_* outputs stay
//     0, so the rest of the core is quiet.
// The functional reset_n is released and the functional inputs would start
// the LTSM and FDI, so the other blocks are quiet only because the core holds
// them in reset.

`timescale 1ns/1ps
`default_nettype none

module UcieDigitalTopBlockTestModesSpec_tb;
  import UcieUPM_interfaces_pkg::*;

  localparam int unsigned REACT_CYCLES = 4000;

  localparam int unsigned FDI_WIDTH         = UcieUPM_fdi_params_pkg::FDI_WIDTH;
  localparam int unsigned FDI_DLLP_WIDTH    = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH;
  localparam int unsigned FDI_SB_WIDTH      = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH;
  localparam int unsigned RDI_WIDTH         = UcieUPM_rdi_params_pkg::RDI_WIDTH;
  localparam int unsigned RDI_SB_WIDTH      = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH;
  localparam int unsigned SB_NODE_MSG_WIDTH = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH;
  localparam bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION;
  localparam bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A;
  localparam logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID;
  localparam bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE;
  localparam bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE;
  localparam logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING;
  localparam logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED;
  localparam int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH;
  localparam int unsigned d2cTxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH;
  localparam int unsigned d2cDeskewStepsPerPi = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI;
  localparam bit d2cDeskewAddDelayIncreasesPhase = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE;
  localparam logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD;
  localparam int unsigned d2cMinLaneWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS;
  localparam int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS;
  localparam int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES;
  localparam int unsigned validVrefValueCount = LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT;
  localparam int unsigned validVrefCodeWidth =
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH;
  localparam int unsigned validVrefMinimumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS;
  localparam int unsigned validVrefMaximumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS;
  localparam logic [15:0] validVrefMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD;
  localparam int unsigned validVrefMinPassingWindowValues = LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES;
  localparam int unsigned validVrefMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES;
  localparam bit valTrainVrefEnable = LtsmParameters_pkg::DEFAULT_VALTRAIN_VREF_ENABLE;
  localparam int unsigned dataLaneCount = 16;
  localparam logic [dataLaneCount-1:0] activeDataLaneMask = {dataLaneCount{1'b1}};
  localparam int unsigned dataVrefValueCount = LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT;
  localparam int unsigned dataVrefCodeWidth =
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH;
  localparam int unsigned dataVrefMinimumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS;
  localparam int unsigned dataVrefMaximumMillivolts = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS;
  localparam logic [15:0] dataVrefMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD;
  localparam int unsigned dataVrefMinPassingWindowValues = LtsmParameters_pkg::DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES;
  localparam int unsigned dataVrefMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES;
  localparam bit dataTrainVrefEnable = 1'b1;
  localparam bit rxDeskewEnable = LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE;
  localparam int unsigned rxDeskewValueCount = LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT;
  localparam int unsigned rxDeskewCodeWidth =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH;
  localparam logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD;
  localparam int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES;
  localparam int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES;
  localparam int unsigned SB_TX_FIFO_ENTRIES = 4;

  // Every UcieDigitalTop port, connected by name (.*).
  logic testModeDigital;
  logic testModeFdi;
  logic testModeRdi;
  logic testModeLtsm;
  logic testModePhy;
  logic clock;
  logic reset_n;
  UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req;
  logic fdi_lp_linkerror;
  logic fdi_lp_rx_active_sts;
  logic fdi_lp_wake_req;
  logic fdi_lp_clk_ack;
  logic fdi_lp_stall_ack;
  UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts;
  logic fdi_pl_rx_active_req;
  logic fdi_pl_inband_pres;
  logic fdi_pl_wake_ack;
  logic fdi_pl_clk_req;
  logic fdi_pl_stall_req;
  logic fdi_active;
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
  logic ltsm_flagFromAnalog_valVref_detectedValPattern;
  logic ltsm_flagFromAnalog_valVref_finishedPattern;
  logic ltsm_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] ltsm_flagToAnalog_valVref_rxVrefCode;
  logic ltsm_flagFromAnalog_valVref_rxVrefApplied;
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
  logic [dataLaneCount-1:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic ltsm_flagFromAnalog_dataVref_finishedPattern;
  logic ltsm_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] ltsm_flagToAnalog_dataVref_rxVrefCodes;
  logic ltsm_flagFromAnalog_dataVref_rxVrefApplied;
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
  logic ltsm_flagFromAnalog_rxClkCal_done;
  logic ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  logic ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  logic ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
  logic ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
  logic ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
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
  logic [15:0] ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  logic ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
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
  logic [dataLaneCount-1:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic [15:0] ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic [3:0] ltsm_dbg_mbtrainState;
  logic [11:0] ltsm_dbg_mbtrainActiveSubstate;
  logic [15:0] ltsm_dbg_mbtrainLastErrorCount;
  logic [15:0] ltsm_dbg_mbtrainRetryCount;
  logic sb_tx_dout;
  logic sb_tx_clk;
  logic sb_rx_din;
  logic sb_rx_clk;
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
  logic jtag_clock;
  logic jtag_reset_n;
  UcieUPM_interfaces_pkg::PhyStateReq_t jtag_fdi_lp_state_req;
  logic jtag_fdi_lp_linkerror;
  logic jtag_fdi_lp_rx_active_sts;
  logic jtag_fdi_lp_wake_req;
  logic jtag_fdi_lp_clk_ack;
  logic jtag_fdi_lp_stall_ack;
  UcieUPM_interfaces_pkg::PhyState_t jtag_fdi_pl_state_sts;
  logic jtag_fdi_pl_rx_active_req;
  logic jtag_fdi_pl_inband_pres;
  logic jtag_fdi_pl_wake_ack;
  logic jtag_fdi_pl_clk_req;
  logic jtag_fdi_pl_stall_req;
  logic jtag_fdi_active;
  logic jtag_timeout_disable;
  logic [31:0] jtag_cycles_1us;
  logic jtag_ltsm_start;
  logic jtag_ltsm_stable_clk;
  logic jtag_ltsm_pll_locked;
  logic jtag_ltsm_stable_supply;
  logic jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  logic jtag_ltsm_flagFromAnalog_FinishedClkPatterns;
  logic jtag_ltsm_flagFromAnalog_FinishedValTrainPattern;
  logic jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  logic jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  logic jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  logic jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  logic jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  logic jtag_ltsm_flagFromAnalog_ValTrainPatternReceived;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  logic jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  logic jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  logic jtag_ltsm_flagToAnalog_RepairClkState;
  logic jtag_ltsm_flagToAnalog_SendClkPatterns;
  logic jtag_ltsm_flagToAnalog_RepairValState;
  logic jtag_ltsm_flagToAnalog_SendValTrainPattern;
  logic jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  logic jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  logic jtag_ltsm_flagToAnalog_RepairMbSetReceiver;
  logic jtag_ltsm_flagToAnalog_LaneReversalApplied;
  logic jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
  logic [3:0] jtag_ltsm_state;
  logic jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen;
  logic jtag_ltsm_dbg_rxValidRisingEdge;
  logic [2:0] jtag_ltsm_dbg_sbinitSendCount;
  logic jtag_ltsm_dbg_sbTxValid;
  logic [127:0] jtag_ltsm_dbg_sbTxDin;
  logic jtag_ltsm_dbg_flagTrainError;
  logic [2:0] jtag_ltsm_dbg_mbinitSubstate;
  logic [4:0] jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
  logic jtag_ltsm_flagToAnalog_valVref_sendPattern;
  logic jtag_ltsm_flagFromAnalog_valVref_detectedValPattern;
  logic jtag_ltsm_flagFromAnalog_valVref_finishedPattern;
  logic jtag_ltsm_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_valVref_rxVrefCode;
  logic jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied;
  logic jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic jtag_ltsm_flagToAnalog_valVref_comparisonMode;
  logic [15:0] jtag_ltsm_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_valVref_burstCountSettings;
  logic jtag_ltsm_flagToAnalog_valVref_patternMode;
  logic [3:0] jtag_ltsm_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] jtag_ltsm_flagToAnalog_valVref_validPattern;
  logic [2:0] jtag_ltsm_flagToAnalog_valVref_dataPattern;
  logic jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors;
  logic jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
  logic jtag_ltsm_flagToAnalog_dataVref_sendPattern;
  logic [dataLaneCount-1:0] jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic jtag_ltsm_flagFromAnalog_dataVref_finishedPattern;
  logic jtag_ltsm_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes;
  logic jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  logic jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic jtag_ltsm_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_dataVref_burstCountSettings;
  logic jtag_ltsm_flagToAnalog_dataVref_patternMode;
  logic [3:0] jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] jtag_ltsm_flagToAnalog_dataVref_validPattern;
  logic [2:0] jtag_ltsm_flagToAnalog_dataVref_dataPattern;
  logic jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors;
  logic jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic jtag_ltsm_flagToAnalog_rxClkCal_doCalibration;
  logic jtag_ltsm_flagFromAnalog_rxClkCal_done;
  logic jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  logic jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  logic jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
  logic jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
  logic jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  logic jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  logic [15:0] jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  logic jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode;
  logic [15:0] jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
  logic jtag_ltsm_flagToAnalog_d2cReceiver_patternMode;
  logic [3:0] jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  logic [2:0] jtag_ltsm_flagToAnalog_d2cReceiver_validPattern;
  logic [2:0] jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern;
  logic jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic [15:0] jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  logic jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  logic jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  logic [15:0] jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  logic jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode;
  logic [15:0] jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings;
  logic [15:0] jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings;
  logic jtag_ltsm_flagToAnalog_rxDeskew_patternMode;
  logic [3:0] jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
  logic [2:0] jtag_ltsm_flagToAnalog_rxDeskew_validPattern;
  logic [2:0] jtag_ltsm_flagToAnalog_rxDeskew_dataPattern;
  logic jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic [dataLaneCount-1:0] jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic [15:0] jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic [3:0] jtag_ltsm_dbg_mbtrainState;
  logic [11:0] jtag_ltsm_dbg_mbtrainActiveSubstate;
  logic [15:0] jtag_ltsm_dbg_mbtrainLastErrorCount;
  logic [15:0] jtag_ltsm_dbg_mbtrainRetryCount;
  logic jtag_sb_tx_dout;
  logic jtag_sb_tx_clk;
  logic jtag_sb_rx_din;
  logic jtag_sb_rx_clk;
  logic jtag_debug_sb_rx_overflow;
  logic [3:0] jtag_debug_ltsm_state;
  logic jtag_debug_ltsm_inband_pres;
  UcieUPM_d2dadapter_pkg::LinkInitState_t jtag_debug_fdi_link_init_state;
  UcieUPM_interfaces_pkg::PhyState_t jtag_debug_rdi_state;
  UcieUPM_interfaces_pkg::PhyStateReq_t jtag_debug_fdi_to_rdi_state_req;
  logic jtag_debug_arb_grant_ltsm;
  logic jtag_debug_arb_grant_fdi;
  logic jtag_debug_arb_grant_rdi;
  logic jtag_debug_arb_tx_locked;
  logic [1:0] jtag_debug_arb_rr_last_source;
  logic jtag_debug_arb_rr_last_granted_rdi;
  logic jtag_debug_arb_tx_fire;
  logic jtag_debug_rx_route_ltsm;
  logic jtag_debug_rx_route_fdi;
  logic jtag_debug_rx_route_rdi;
  logic jtag_debug_rx_drop_unknown;
  logic jtag_debug_rx_fire;
  logic jtagFdi_clock;
  logic jtagFdi_reset_n;
  logic [31:0] jtagFdi_cycles_1us;
  logic jtagFdi_timeout_disable;
  UcieUPM_interfaces_pkg::PhyStateReq_t jtagFdi_fdi_lp_state_req;
  logic jtagFdi_fdi_lp_linkerror;
  logic jtagFdi_fdi_lp_rx_active_sts;
  logic jtagFdi_fdi_lp_wake_req;
  logic jtagFdi_fdi_lp_clk_ack;
  logic jtagFdi_fdi_lp_stall_ack;
  UcieUPM_interfaces_pkg::PhyState_t jtagFdi_fdi_pl_state_sts;
  logic jtagFdi_fdi_pl_rx_active_req;
  logic jtagFdi_fdi_pl_inband_pres;
  logic jtagFdi_fdi_pl_wake_ack;
  logic jtagFdi_fdi_pl_clk_req;
  logic jtagFdi_fdi_pl_stall_req;
  logic jtagFdi_fdi_active;
  UcieUPM_d2dadapter_pkg::LinkInitState_t jtagFdi_debug_link_init_state;
  logic jtagFdi_rdi_lp_linkerror;
  UcieUPM_interfaces_pkg::PhyStateReq_t jtagFdi_rdi_lp_state_req;
  UcieUPM_interfaces_pkg::PhyState_t jtagFdi_rdi_pl_state_sts;
  logic jtagFdi_rdi_pl_inband_pres;
  logic jtagFdi_fdiNeedsRdiAwake;
  logic jtagFdi_rdiAwake;
  logic jtagFdi_rdiNeedsFdiAwake;
  logic jtagFdi_fdiAwake;
  logic jtagFdi_rdi_pl_stall_req;
  logic jtagFdi_rdi_lp_stall_ack;
  logic jtagFdi_sb_snd_valid;
  logic [127:0] jtagFdi_sb_snd_msg;
  logic jtagFdi_sb_snd_ready;
  logic jtagFdi_sb_rcv_valid;
  logic [127:0] jtagFdi_sb_rcv_msg;
  logic jtagFdi_sb_rcv_ready;
  logic jtagRdi_clock;
  logic jtagRdi_reset_n;
  logic jtagRdi_ltsm_lp_wake_req;
  logic jtagRdi_ltsm_pl_wake_ack;
  logic jtagRdi_ltsm_pl_clk_req;
  logic jtagRdi_ltsm_lp_clk_ack;
  UcieUPM_interfaces_pkg::PhyStateReq_t jtagRdi_lp_state_req;
  UcieUPM_interfaces_pkg::PhyState_t jtagRdi_pl_state_sts;
  logic jtagRdi_pl_stallreq;
  logic jtagRdi_lp_stallack;
  logic jtagRdi_rdi_pl_inband_pres;
  logic jtagRdi_ltsm_pl_inband_pres;
  logic jtagRdi_fdiNeedsRdiAwake;
  logic jtagRdi_rdiAwake;
  logic jtagRdi_rdiNeedsFdiAwake;
  logic jtagRdi_fdiAwake;
  logic jtagRdi_sb_snd_valid;
  logic [127:0] jtagRdi_sb_snd_msg;
  logic jtagRdi_sb_snd_ready;
  logic jtagRdi_sb_rcv_valid;
  logic [127:0] jtagRdi_sb_rcv_msg;
  logic jtagRdi_sb_rcv_ready;
  logic jtagRdi_lp_linkerror;
  logic jtagRdi_pl_phyinrecenter;
  logic jtagRdi_timeout_disable;
  logic [31:0] jtagRdi_cycles_1us;
  logic jtagLtsm_clock;
  logic jtagLtsm_reset_n;
  logic [127:0] jtagLtsm_sb_tx_din;
  logic jtagLtsm_sb_tx_valid;
  logic jtagLtsm_sb_tx_ready;
  logic [127:0] jtagLtsm_sb_rx_dout;
  logic jtagLtsm_sb_rx_valid;
  logic jtagLtsm_start;
  logic jtagLtsm_stable_clk;
  logic jtagLtsm_pll_locked;
  logic jtagLtsm_stable_supply;
  logic jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  logic jtagLtsm_flagFromAnalog_FinishedClkPatterns;
  logic jtagLtsm_flagFromAnalog_FinishedValTrainPattern;
  logic jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  logic jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  logic jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  logic jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  logic jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  logic jtagLtsm_flagFromAnalog_ValTrainPatternReceived;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  logic jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  logic jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  logic jtagLtsm_flagToAnalog_RepairClkState;
  logic jtagLtsm_flagToAnalog_SendClkPatterns;
  logic jtagLtsm_flagToAnalog_RepairValState;
  logic jtagLtsm_flagToAnalog_SendValTrainPattern;
  logic jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  logic jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern;
  logic jtagLtsm_flagToAnalog_RepairMbSetReceiver;
  logic jtagLtsm_flagToAnalog_LaneReversalApplied;
  logic jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler;
  logic [3:0] jtagLtsm_state;
  logic jtagLtsm_dbg_flagSbinitFirstClkPatternSeen;
  logic jtagLtsm_dbg_rxValidRisingEdge;
  logic [2:0] jtagLtsm_dbg_sbinitSendCount;
  logic jtagLtsm_dbg_sbTxValid;
  logic [127:0] jtagLtsm_dbg_sbTxDin;
  logic jtagLtsm_dbg_flagTrainError;
  logic [2:0] jtagLtsm_dbg_mbinitSubstate;
  logic [1:0] jtagLtsm_dbg_mbinitParamSenderState;
  logic [1:0] jtagLtsm_dbg_mbinitParamReceiverState;
  logic [1:0] jtagLtsm_dbg_mbinitCalSenderState;
  logic [1:0] jtagLtsm_dbg_mbinitCalReceiverState;
  logic [2:0] jtagLtsm_dbg_mbinitRepairClkSenderState;
  logic [2:0] jtagLtsm_dbg_mbinitRepairClkReceiverState;
  logic [2:0] jtagLtsm_dbg_mbinitRepairValSenderState;
  logic [2:0] jtagLtsm_dbg_mbinitRepairValReceiverState;
  logic [3:0] jtagLtsm_dbg_mbinitReversalMbSenderState;
  logic [2:0] jtagLtsm_dbg_mbinitReversalMbReceiverState;
  logic [4:0] jtagLtsm_dbg_mbinitRepairMbSenderState;
  logic [3:0] jtagLtsm_dbg_mbinitRepairMbReceiverState;
  logic [4:0] jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount;
  logic jtagLtsm_flagToAnalog_valVref_sendPattern;
  logic jtagLtsm_flagFromAnalog_valVref_detectedValPattern;
  logic jtagLtsm_flagFromAnalog_valVref_finishedPattern;
  logic jtagLtsm_flagToAnalog_valVref_applyRxVref;
  logic [validVrefCodeWidth-1:0] jtagLtsm_flagToAnalog_valVref_rxVrefCode;
  logic jtagLtsm_flagFromAnalog_valVref_rxVrefApplied;
  logic jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  logic [15:0] jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  logic jtagLtsm_flagToAnalog_valVref_comparisonMode;
  logic [15:0] jtagLtsm_flagToAnalog_valVref_iterationCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_valVref_idleCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_valVref_burstCountSettings;
  logic jtagLtsm_flagToAnalog_valVref_patternMode;
  logic [3:0] jtagLtsm_flagToAnalog_valVref_clockPhaseControl;
  logic [2:0] jtagLtsm_flagToAnalog_valVref_validPattern;
  logic [2:0] jtagLtsm_flagToAnalog_valVref_dataPattern;
  logic jtagLtsm_flagToAnalog_valVref_clearComparisonErrors;
  logic jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler;
  logic jtagLtsm_flagToAnalog_dataVref_sendPattern;
  logic [dataLaneCount-1:0] jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic jtagLtsm_flagFromAnalog_dataVref_finishedPattern;
  logic jtagLtsm_flagToAnalog_dataVref_applyRxVref;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] jtagLtsm_flagToAnalog_dataVref_rxVrefCodes;
  logic jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied;
  logic jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  logic [15:0] jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  logic jtagLtsm_flagToAnalog_dataVref_comparisonMode;
  logic [15:0] jtagLtsm_flagToAnalog_dataVref_iterationCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_dataVref_idleCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_dataVref_burstCountSettings;
  logic jtagLtsm_flagToAnalog_dataVref_patternMode;
  logic [3:0] jtagLtsm_flagToAnalog_dataVref_clockPhaseControl;
  logic [2:0] jtagLtsm_flagToAnalog_dataVref_validPattern;
  logic [2:0] jtagLtsm_flagToAnalog_dataVref_dataPattern;
  logic jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors;
  logic jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  logic jtagLtsm_flagToAnalog_rxClkCal_doCalibration;
  logic jtagLtsm_flagFromAnalog_rxClkCal_done;
  logic jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack;
  logic jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern;
  logic jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler;
  logic jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode;
  logic jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  logic jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  logic jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode;
  logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings;
  logic jtagLtsm_flagToAnalog_d2cReceiver_patternMode;
  logic [3:0] jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  logic [2:0] jtagLtsm_flagToAnalog_d2cReceiver_validPattern;
  logic [2:0] jtagLtsm_flagToAnalog_d2cReceiver_dataPattern;
  logic jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic [15:0] jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern;
  logic jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  logic jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  logic jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  logic jtagLtsm_flagToAnalog_rxDeskew_comparisonMode;
  logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings;
  logic [15:0] jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings;
  logic jtagLtsm_flagToAnalog_rxDeskew_patternMode;
  logic [3:0] jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl;
  logic [2:0] jtagLtsm_flagToAnalog_rxDeskew_validPattern;
  logic [2:0] jtagLtsm_flagToAnalog_rxDeskew_dataPattern;
  logic jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic [dataLaneCount-1:0] jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain;
  logic [15:0] jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic [3:0] jtagLtsm_dbg_mbtrainState;
  logic [11:0] jtagLtsm_dbg_mbtrainActiveSubstate;
  logic [3:0] jtagLtsm_dbg_mbtrainValVrefLocalState;
  logic [2:0] jtagLtsm_dbg_mbtrainValVrefRemoteState;
  logic [3:0] jtagLtsm_dbg_mbtrainValVrefSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainValVrefPointInitiatorState;
  logic [3:0] jtagLtsm_dbg_mbtrainValVrefPointResponderState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataVrefLocalState;
  logic [2:0] jtagLtsm_dbg_mbtrainDataVrefRemoteState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataVrefSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataVrefPointResponderState;
  logic [1:0] jtagLtsm_dbg_mbtrainSpeedIdleSenderState;
  logic [1:0] jtagLtsm_dbg_mbtrainSpeedIdleReceiverState;
  logic [1:0] jtagLtsm_dbg_mbtrainTxSelfCalSenderState;
  logic [1:0] jtagLtsm_dbg_mbtrainTxSelfCalReceiverState;
  logic [2:0] jtagLtsm_dbg_mbtrainRxClkCalSenderState;
  logic [2:0] jtagLtsm_dbg_mbtrainRxClkCalReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterSenderState;
  logic [2:0] jtagLtsm_dbg_mbtrainValTrainCenterReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainCenterSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefLocalState;
  logic [2:0] jtagLtsm_dbg_mbtrainValTrainVrefRemoteState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState;
  logic [3:0] jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState;
  logic [2:0] jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState;
  logic [4:0] jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefLocalState;
  logic [2:0] jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState;
  logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewLocalState;
  logic [2:0] jtagLtsm_dbg_mbtrainRxDeskewRemoteState;
  logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewSweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState;
  logic [3:0] jtagLtsm_dbg_mbtrainRxDeskewPointResponderState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState;
  logic [2:0] jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState;
  logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedSenderState;
  logic [2:0] jtagLtsm_dbg_mbtrainLinkSpeedReceiverState;
  logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState;
  logic [3:0] jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState;
  logic [15:0] jtagLtsm_dbg_mbtrainLastErrorCount;
  logic [15:0] jtagLtsm_dbg_mbtrainRetryCount;
  // LINKSPEED rate-control pins (inputs held at 0 in this bench).
  logic [1:0] ltsm_linkSpeed_requestedSpeed = '0;
  logic ltsm_flagFromAnalog_linkSpeed_speedApplied = '0;
  logic [1:0] ltsm_flagToAnalog_linkSpeed_speedCode;
  logic ltsm_flagToAnalog_linkSpeed_applySpeed;
  logic ltsm_flagToAnalog_linkSpeed_electricalIdle;
  logic [1:0] jtag_ltsm_linkSpeed_requestedSpeed = '0;
  logic jtag_ltsm_flagFromAnalog_linkSpeed_speedApplied = '0;
  logic [1:0] jtag_ltsm_flagToAnalog_linkSpeed_speedCode;
  logic jtag_ltsm_flagToAnalog_linkSpeed_applySpeed;
  logic jtag_ltsm_flagToAnalog_linkSpeed_electricalIdle;
  logic [1:0] jtagLtsm_linkSpeed_requestedSpeed = '0;
  logic jtagLtsm_flagFromAnalog_linkSpeed_speedApplied = '0;
  logic [1:0] jtagLtsm_flagToAnalog_linkSpeed_speedCode;
  logic jtagLtsm_flagToAnalog_linkSpeed_applySpeed;
  logic jtagLtsm_flagToAnalog_linkSpeed_electricalIdle;
  // PHY TDR pins (testModePhy stays 0 in this bench).
  logic jtagPhy_ltsm_stable_clk;
  logic jtagPhy_ltsm_pll_locked;
  logic jtagPhy_ltsm_stable_supply;
  logic jtagPhy_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
  logic jtagPhy_ltsm_flagFromAnalog_FinishedClkPatterns;
  logic jtagPhy_ltsm_flagFromAnalog_FinishedValTrainPattern;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
  logic jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
  logic jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
  logic jtagPhy_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
  logic jtagPhy_ltsm_flagFromAnalog_ValTrainPatternReceived;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
  logic jtagPhy_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
  logic jtagPhy_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
  logic jtagPhy_ltsm_flagToAnalog_RepairClkState = '0;
  logic jtagPhy_ltsm_flagToAnalog_SendClkPatterns = '0;
  logic jtagPhy_ltsm_flagToAnalog_RepairValState = '0;
  logic jtagPhy_ltsm_flagToAnalog_SendValTrainPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_RepairMbSendLaneIDPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_RepairMbSetReceiver = '0;
  logic jtagPhy_ltsm_flagToAnalog_LaneReversalApplied = '0;
  logic jtagPhy_ltsm_flagToAnalog_linkInit_resetLfsrScrambler = '0;
  logic jtagPhy_ltsm_flagToAnalog_valVref_sendPattern = '0;
  logic jtagPhy_ltsm_flagFromAnalog_valVref_detectedValPattern;
  logic jtagPhy_ltsm_flagFromAnalog_valVref_finishedPattern;
  logic jtagPhy_ltsm_flagToAnalog_valVref_applyRxVref = '0;
  logic [validVrefCodeWidth-1:0] jtagPhy_ltsm_flagToAnalog_valVref_rxVrefCode = '0;
  logic jtagPhy_ltsm_flagFromAnalog_valVref_rxVrefApplied;
  logic jtagPhy_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold = '0;
  logic jtagPhy_ltsm_flagToAnalog_valVref_comparisonMode = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_valVref_iterationCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_valVref_idleCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_valVref_burstCountSettings = '0;
  logic jtagPhy_ltsm_flagToAnalog_valVref_patternMode = '0;
  logic [3:0] jtagPhy_ltsm_flagToAnalog_valVref_clockPhaseControl = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_valVref_validPattern = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_valVref_dataPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_valVref_clearComparisonErrors = '0;
  logic jtagPhy_ltsm_flagToAnalog_valVref_resetLocalTxScrambler = '0;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_sendPattern = '0;
  logic [dataLaneCount-1:0] jtagPhy_ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic jtagPhy_ltsm_flagFromAnalog_dataVref_finishedPattern;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_applyRxVref = '0;
  logic [dataLaneCount*dataVrefCodeWidth-1:0] jtagPhy_ltsm_flagToAnalog_dataVref_rxVrefCodes = '0;
  logic jtagPhy_ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold = '0;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_comparisonMode = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_dataVref_iterationCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_dataVref_idleCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_dataVref_burstCountSettings = '0;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_patternMode = '0;
  logic [3:0] jtagPhy_ltsm_flagToAnalog_dataVref_clockPhaseControl = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_dataVref_validPattern = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_dataVref_dataPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_clearComparisonErrors = '0;
  logic jtagPhy_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler = '0;
  logic jtagPhy_ltsm_flagToAnalog_rxClkCal_doCalibration = '0;
  logic jtagPhy_ltsm_flagFromAnalog_rxClkCal_done;
  logic jtagPhy_ltsm_flagToAnalog_rxClkCal_sendClockTrack = '0;
  logic jtagPhy_ltsm_flagToAnalog_d2cSender_sendValTrainPattern = '0;
  logic jtagPhy_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
  logic jtagPhy_ltsm_flagToAnalog_d2cSender_resetLocalScrambler = '0;
  logic jtagPhy_ltsm_flagToAnalog_d2cSender_applyTxClockPhase = '0;
  logic [d2cPiCodeWidth-1:0] jtagPhy_ltsm_flagToAnalog_d2cSender_txClockPhaseCode = '0;
  logic jtagPhy_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
  logic jtagPhy_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = '0;
  logic jtagPhy_ltsm_flagToAnalog_d2cReceiver_comparisonMode = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_idleCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_burstCountSettings = '0;
  logic jtagPhy_ltsm_flagToAnalog_d2cReceiver_patternMode = '0;
  logic [3:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_validPattern = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_d2cReceiver_dataPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler = '0;
  logic [15:0] jtagPhy_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] jtagPhy_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  logic jtagPhy_ltsm_flagToAnalog_d2cSender_sendLfsrPattern = '0;
  logic jtagPhy_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
  logic jtagPhy_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew = '0;
  logic [64*d2cTxDeskewCodeWidth-1:0] jtagPhy_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes = '0;
  logic jtagPhy_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern = '0;
  logic jtagPhy_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler = '0;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew = '0;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes = '0;
  logic jtagPhy_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold = '0;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_comparisonMode = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_iterationCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_idleCountSettings = '0;
  logic [15:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_burstCountSettings = '0;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_patternMode = '0;
  logic [3:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_clockPhaseControl = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_validPattern = '0;
  logic [2:0] jtagPhy_ltsm_flagToAnalog_rxDeskew_dataPattern = '0;
  logic jtagPhy_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors = '0;
  logic [dataLaneCount-1:0] jtagPhy_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  logic [1:0] jtagPhy_ltsm_flagToAnalog_linkSpeed_speedCode = '0;
  logic jtagPhy_ltsm_flagToAnalog_linkSpeed_applySpeed = '0;
  logic jtagPhy_ltsm_flagToAnalog_linkSpeed_electricalIdle = '0;
  logic [15:0] jtagPhy_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
  logic jtagPhy_ltsm_flagFromAnalog_linkSpeed_speedApplied;

  UcieDigitalTop dut (.*);

  // Output groups.
  localparam int unsigned func_outs_W = $bits({
    fdi_pl_state_sts,
    fdi_pl_rx_active_req,
    fdi_pl_inband_pres,
    fdi_pl_wake_ack,
    fdi_pl_clk_req,
    fdi_pl_stall_req,
    fdi_active,
    ltsm_flagToAnalog_RepairClkState,
    ltsm_flagToAnalog_SendClkPatterns,
    ltsm_flagToAnalog_RepairValState,
    ltsm_flagToAnalog_SendValTrainPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSetReceiver,
    ltsm_flagToAnalog_LaneReversalApplied,
    ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    ltsm_state,
    ltsm_dbg_flagSbinitFirstClkPatternSeen,
    ltsm_dbg_rxValidRisingEdge,
    ltsm_dbg_sbinitSendCount,
    ltsm_dbg_sbTxValid,
    ltsm_dbg_sbTxDin,
    ltsm_dbg_flagTrainError,
    ltsm_dbg_mbinitSubstate,
    ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
    ltsm_flagToAnalog_valVref_sendPattern,
    ltsm_flagToAnalog_valVref_applyRxVref,
    ltsm_flagToAnalog_valVref_rxVrefCode,
    ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_valVref_comparisonMode,
    ltsm_flagToAnalog_valVref_iterationCountSettings,
    ltsm_flagToAnalog_valVref_idleCountSettings,
    ltsm_flagToAnalog_valVref_burstCountSettings,
    ltsm_flagToAnalog_valVref_patternMode,
    ltsm_flagToAnalog_valVref_clockPhaseControl,
    ltsm_flagToAnalog_valVref_validPattern,
    ltsm_flagToAnalog_valVref_dataPattern,
    ltsm_flagToAnalog_valVref_clearComparisonErrors,
    ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
    ltsm_flagToAnalog_dataVref_sendPattern,
    ltsm_flagToAnalog_dataVref_applyRxVref,
    ltsm_flagToAnalog_dataVref_rxVrefCodes,
    ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_dataVref_comparisonMode,
    ltsm_flagToAnalog_dataVref_iterationCountSettings,
    ltsm_flagToAnalog_dataVref_idleCountSettings,
    ltsm_flagToAnalog_dataVref_burstCountSettings,
    ltsm_flagToAnalog_dataVref_patternMode,
    ltsm_flagToAnalog_dataVref_clockPhaseControl,
    ltsm_flagToAnalog_dataVref_validPattern,
    ltsm_flagToAnalog_dataVref_dataPattern,
    ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    ltsm_flagToAnalog_rxClkCal_doCalibration,
    ltsm_flagToAnalog_rxClkCal_sendClockTrack,
    ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
    ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
    ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_d2cReceiver_comparisonMode,
    ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
    ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
    ltsm_flagToAnalog_d2cReceiver_patternMode,
    ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    ltsm_flagToAnalog_d2cReceiver_validPattern,
    ltsm_flagToAnalog_d2cReceiver_dataPattern,
    ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_rxDeskew_comparisonMode,
    ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
    ltsm_flagToAnalog_rxDeskew_idleCountSettings,
    ltsm_flagToAnalog_rxDeskew_burstCountSettings,
    ltsm_flagToAnalog_rxDeskew_patternMode,
    ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
    ltsm_flagToAnalog_rxDeskew_validPattern,
    ltsm_flagToAnalog_rxDeskew_dataPattern,
    ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    ltsm_flagToLtsm_linkSpeed_phyInRetrain,
    ltsm_dbg_mbtrainState,
    ltsm_dbg_mbtrainActiveSubstate,
    ltsm_dbg_mbtrainLastErrorCount,
    ltsm_dbg_mbtrainRetryCount,
    sb_tx_dout,
    sb_tx_clk,
    debug_sb_rx_overflow,
    debug_ltsm_state,
    debug_ltsm_inband_pres,
    debug_fdi_link_init_state,
    debug_rdi_state,
    debug_fdi_to_rdi_state_req,
    debug_arb_grant_ltsm,
    debug_arb_grant_fdi,
    debug_arb_grant_rdi,
    debug_arb_tx_locked,
    debug_arb_rr_last_source,
    debug_arb_rr_last_granted_rdi,
    debug_arb_tx_fire,
    debug_rx_route_ltsm,
    debug_rx_route_fdi,
    debug_rx_route_rdi,
    debug_rx_drop_unknown,
    debug_rx_fire
  });
  wire logic [func_outs_W-1:0] func_outs = {
    fdi_pl_state_sts,
    fdi_pl_rx_active_req,
    fdi_pl_inband_pres,
    fdi_pl_wake_ack,
    fdi_pl_clk_req,
    fdi_pl_stall_req,
    fdi_active,
    ltsm_flagToAnalog_RepairClkState,
    ltsm_flagToAnalog_SendClkPatterns,
    ltsm_flagToAnalog_RepairValState,
    ltsm_flagToAnalog_SendValTrainPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSetReceiver,
    ltsm_flagToAnalog_LaneReversalApplied,
    ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    ltsm_state,
    ltsm_dbg_flagSbinitFirstClkPatternSeen,
    ltsm_dbg_rxValidRisingEdge,
    ltsm_dbg_sbinitSendCount,
    ltsm_dbg_sbTxValid,
    ltsm_dbg_sbTxDin,
    ltsm_dbg_flagTrainError,
    ltsm_dbg_mbinitSubstate,
    ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
    ltsm_flagToAnalog_valVref_sendPattern,
    ltsm_flagToAnalog_valVref_applyRxVref,
    ltsm_flagToAnalog_valVref_rxVrefCode,
    ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_valVref_comparisonMode,
    ltsm_flagToAnalog_valVref_iterationCountSettings,
    ltsm_flagToAnalog_valVref_idleCountSettings,
    ltsm_flagToAnalog_valVref_burstCountSettings,
    ltsm_flagToAnalog_valVref_patternMode,
    ltsm_flagToAnalog_valVref_clockPhaseControl,
    ltsm_flagToAnalog_valVref_validPattern,
    ltsm_flagToAnalog_valVref_dataPattern,
    ltsm_flagToAnalog_valVref_clearComparisonErrors,
    ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
    ltsm_flagToAnalog_dataVref_sendPattern,
    ltsm_flagToAnalog_dataVref_applyRxVref,
    ltsm_flagToAnalog_dataVref_rxVrefCodes,
    ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_dataVref_comparisonMode,
    ltsm_flagToAnalog_dataVref_iterationCountSettings,
    ltsm_flagToAnalog_dataVref_idleCountSettings,
    ltsm_flagToAnalog_dataVref_burstCountSettings,
    ltsm_flagToAnalog_dataVref_patternMode,
    ltsm_flagToAnalog_dataVref_clockPhaseControl,
    ltsm_flagToAnalog_dataVref_validPattern,
    ltsm_flagToAnalog_dataVref_dataPattern,
    ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    ltsm_flagToAnalog_rxClkCal_doCalibration,
    ltsm_flagToAnalog_rxClkCal_sendClockTrack,
    ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
    ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
    ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_d2cReceiver_comparisonMode,
    ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
    ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
    ltsm_flagToAnalog_d2cReceiver_patternMode,
    ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    ltsm_flagToAnalog_d2cReceiver_validPattern,
    ltsm_flagToAnalog_d2cReceiver_dataPattern,
    ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    ltsm_flagToAnalog_rxDeskew_comparisonMode,
    ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
    ltsm_flagToAnalog_rxDeskew_idleCountSettings,
    ltsm_flagToAnalog_rxDeskew_burstCountSettings,
    ltsm_flagToAnalog_rxDeskew_patternMode,
    ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
    ltsm_flagToAnalog_rxDeskew_validPattern,
    ltsm_flagToAnalog_rxDeskew_dataPattern,
    ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    ltsm_flagToLtsm_linkSpeed_phyInRetrain,
    ltsm_dbg_mbtrainState,
    ltsm_dbg_mbtrainActiveSubstate,
    ltsm_dbg_mbtrainLastErrorCount,
    ltsm_dbg_mbtrainRetryCount,
    sb_tx_dout,
    sb_tx_clk,
    debug_sb_rx_overflow,
    debug_ltsm_state,
    debug_ltsm_inband_pres,
    debug_fdi_link_init_state,
    debug_rdi_state,
    debug_fdi_to_rdi_state_req,
    debug_arb_grant_ltsm,
    debug_arb_grant_fdi,
    debug_arb_grant_rdi,
    debug_arb_tx_locked,
    debug_arb_rr_last_source,
    debug_arb_rr_last_granted_rdi,
    debug_arb_tx_fire,
    debug_rx_route_ltsm,
    debug_rx_route_fdi,
    debug_rx_route_rdi,
    debug_rx_drop_unknown,
    debug_rx_fire
  };
  localparam int unsigned dig_outs_W = $bits({
    jtag_fdi_pl_state_sts,
    jtag_fdi_pl_rx_active_req,
    jtag_fdi_pl_inband_pres,
    jtag_fdi_pl_wake_ack,
    jtag_fdi_pl_clk_req,
    jtag_fdi_pl_stall_req,
    jtag_fdi_active,
    jtag_ltsm_flagToAnalog_RepairClkState,
    jtag_ltsm_flagToAnalog_SendClkPatterns,
    jtag_ltsm_flagToAnalog_RepairValState,
    jtag_ltsm_flagToAnalog_SendValTrainPattern,
    jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    jtag_ltsm_flagToAnalog_RepairMbSetReceiver,
    jtag_ltsm_flagToAnalog_LaneReversalApplied,
    jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    jtag_ltsm_state,
    jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen,
    jtag_ltsm_dbg_rxValidRisingEdge,
    jtag_ltsm_dbg_sbinitSendCount,
    jtag_ltsm_dbg_sbTxValid,
    jtag_ltsm_dbg_sbTxDin,
    jtag_ltsm_dbg_flagTrainError,
    jtag_ltsm_dbg_mbinitSubstate,
    jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
    jtag_ltsm_flagToAnalog_valVref_sendPattern,
    jtag_ltsm_flagToAnalog_valVref_applyRxVref,
    jtag_ltsm_flagToAnalog_valVref_rxVrefCode,
    jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_valVref_comparisonMode,
    jtag_ltsm_flagToAnalog_valVref_iterationCountSettings,
    jtag_ltsm_flagToAnalog_valVref_idleCountSettings,
    jtag_ltsm_flagToAnalog_valVref_burstCountSettings,
    jtag_ltsm_flagToAnalog_valVref_patternMode,
    jtag_ltsm_flagToAnalog_valVref_clockPhaseControl,
    jtag_ltsm_flagToAnalog_valVref_validPattern,
    jtag_ltsm_flagToAnalog_valVref_dataPattern,
    jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors,
    jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_dataVref_sendPattern,
    jtag_ltsm_flagToAnalog_dataVref_applyRxVref,
    jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes,
    jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_dataVref_comparisonMode,
    jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_idleCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_burstCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_patternMode,
    jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl,
    jtag_ltsm_flagToAnalog_dataVref_validPattern,
    jtag_ltsm_flagToAnalog_dataVref_dataPattern,
    jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_rxClkCal_doCalibration,
    jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack,
    jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
    jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
    jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode,
    jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_patternMode,
    jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    jtag_ltsm_flagToAnalog_d2cReceiver_validPattern,
    jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern,
    jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode,
    jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_patternMode,
    jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
    jtag_ltsm_flagToAnalog_rxDeskew_validPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_dataPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain,
    jtag_ltsm_dbg_mbtrainState,
    jtag_ltsm_dbg_mbtrainActiveSubstate,
    jtag_ltsm_dbg_mbtrainLastErrorCount,
    jtag_ltsm_dbg_mbtrainRetryCount,
    jtag_sb_tx_dout,
    jtag_sb_tx_clk,
    jtag_debug_sb_rx_overflow,
    jtag_debug_ltsm_state,
    jtag_debug_ltsm_inband_pres,
    jtag_debug_fdi_link_init_state,
    jtag_debug_rdi_state,
    jtag_debug_fdi_to_rdi_state_req,
    jtag_debug_arb_grant_ltsm,
    jtag_debug_arb_grant_fdi,
    jtag_debug_arb_grant_rdi,
    jtag_debug_arb_tx_locked,
    jtag_debug_arb_rr_last_source,
    jtag_debug_arb_rr_last_granted_rdi,
    jtag_debug_arb_tx_fire,
    jtag_debug_rx_route_ltsm,
    jtag_debug_rx_route_fdi,
    jtag_debug_rx_route_rdi,
    jtag_debug_rx_drop_unknown,
    jtag_debug_rx_fire
  });
  wire logic [dig_outs_W-1:0] dig_outs = {
    jtag_fdi_pl_state_sts,
    jtag_fdi_pl_rx_active_req,
    jtag_fdi_pl_inband_pres,
    jtag_fdi_pl_wake_ack,
    jtag_fdi_pl_clk_req,
    jtag_fdi_pl_stall_req,
    jtag_fdi_active,
    jtag_ltsm_flagToAnalog_RepairClkState,
    jtag_ltsm_flagToAnalog_SendClkPatterns,
    jtag_ltsm_flagToAnalog_RepairValState,
    jtag_ltsm_flagToAnalog_SendValTrainPattern,
    jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    jtag_ltsm_flagToAnalog_RepairMbSetReceiver,
    jtag_ltsm_flagToAnalog_LaneReversalApplied,
    jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    jtag_ltsm_state,
    jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen,
    jtag_ltsm_dbg_rxValidRisingEdge,
    jtag_ltsm_dbg_sbinitSendCount,
    jtag_ltsm_dbg_sbTxValid,
    jtag_ltsm_dbg_sbTxDin,
    jtag_ltsm_dbg_flagTrainError,
    jtag_ltsm_dbg_mbinitSubstate,
    jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
    jtag_ltsm_flagToAnalog_valVref_sendPattern,
    jtag_ltsm_flagToAnalog_valVref_applyRxVref,
    jtag_ltsm_flagToAnalog_valVref_rxVrefCode,
    jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_valVref_comparisonMode,
    jtag_ltsm_flagToAnalog_valVref_iterationCountSettings,
    jtag_ltsm_flagToAnalog_valVref_idleCountSettings,
    jtag_ltsm_flagToAnalog_valVref_burstCountSettings,
    jtag_ltsm_flagToAnalog_valVref_patternMode,
    jtag_ltsm_flagToAnalog_valVref_clockPhaseControl,
    jtag_ltsm_flagToAnalog_valVref_validPattern,
    jtag_ltsm_flagToAnalog_valVref_dataPattern,
    jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors,
    jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_dataVref_sendPattern,
    jtag_ltsm_flagToAnalog_dataVref_applyRxVref,
    jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes,
    jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_dataVref_comparisonMode,
    jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_idleCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_burstCountSettings,
    jtag_ltsm_flagToAnalog_dataVref_patternMode,
    jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl,
    jtag_ltsm_flagToAnalog_dataVref_validPattern,
    jtag_ltsm_flagToAnalog_dataVref_dataPattern,
    jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_rxClkCal_doCalibration,
    jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack,
    jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
    jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
    jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode,
    jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
    jtag_ltsm_flagToAnalog_d2cReceiver_patternMode,
    jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    jtag_ltsm_flagToAnalog_d2cReceiver_validPattern,
    jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern,
    jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode,
    jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings,
    jtag_ltsm_flagToAnalog_rxDeskew_patternMode,
    jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
    jtag_ltsm_flagToAnalog_rxDeskew_validPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_dataPattern,
    jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain,
    jtag_ltsm_dbg_mbtrainState,
    jtag_ltsm_dbg_mbtrainActiveSubstate,
    jtag_ltsm_dbg_mbtrainLastErrorCount,
    jtag_ltsm_dbg_mbtrainRetryCount,
    jtag_sb_tx_dout,
    jtag_sb_tx_clk,
    jtag_debug_sb_rx_overflow,
    jtag_debug_ltsm_state,
    jtag_debug_ltsm_inband_pres,
    jtag_debug_fdi_link_init_state,
    jtag_debug_rdi_state,
    jtag_debug_fdi_to_rdi_state_req,
    jtag_debug_arb_grant_ltsm,
    jtag_debug_arb_grant_fdi,
    jtag_debug_arb_grant_rdi,
    jtag_debug_arb_tx_locked,
    jtag_debug_arb_rr_last_source,
    jtag_debug_arb_rr_last_granted_rdi,
    jtag_debug_arb_tx_fire,
    jtag_debug_rx_route_ltsm,
    jtag_debug_rx_route_fdi,
    jtag_debug_rx_route_rdi,
    jtag_debug_rx_drop_unknown,
    jtag_debug_rx_fire
  };
  localparam int unsigned fdi_outs_W = $bits({
    jtagFdi_fdi_pl_state_sts,
    jtagFdi_fdi_pl_rx_active_req,
    jtagFdi_fdi_pl_inband_pres,
    jtagFdi_fdi_pl_wake_ack,
    jtagFdi_fdi_pl_clk_req,
    jtagFdi_fdi_pl_stall_req,
    jtagFdi_fdi_active,
    jtagFdi_debug_link_init_state,
    jtagFdi_rdi_lp_linkerror,
    jtagFdi_rdi_lp_state_req,
    jtagFdi_fdiNeedsRdiAwake,
    jtagFdi_fdiAwake,
    jtagFdi_rdi_lp_stall_ack,
    jtagFdi_sb_snd_valid,
    jtagFdi_sb_snd_msg,
    jtagFdi_sb_rcv_ready
  });
  wire logic [fdi_outs_W-1:0] fdi_outs = {
    jtagFdi_fdi_pl_state_sts,
    jtagFdi_fdi_pl_rx_active_req,
    jtagFdi_fdi_pl_inband_pres,
    jtagFdi_fdi_pl_wake_ack,
    jtagFdi_fdi_pl_clk_req,
    jtagFdi_fdi_pl_stall_req,
    jtagFdi_fdi_active,
    jtagFdi_debug_link_init_state,
    jtagFdi_rdi_lp_linkerror,
    jtagFdi_rdi_lp_state_req,
    jtagFdi_fdiNeedsRdiAwake,
    jtagFdi_fdiAwake,
    jtagFdi_rdi_lp_stall_ack,
    jtagFdi_sb_snd_valid,
    jtagFdi_sb_snd_msg,
    jtagFdi_sb_rcv_ready
  };
  localparam int unsigned rdi_outs_W = $bits({
    jtagRdi_ltsm_pl_wake_ack,
    jtagRdi_ltsm_pl_clk_req,
    jtagRdi_pl_state_sts,
    jtagRdi_pl_stallreq,
    jtagRdi_rdi_pl_inband_pres,
    jtagRdi_rdiAwake,
    jtagRdi_rdiNeedsFdiAwake,
    jtagRdi_sb_snd_valid,
    jtagRdi_sb_snd_msg,
    jtagRdi_sb_rcv_ready,
    jtagRdi_pl_phyinrecenter
  });
  wire logic [rdi_outs_W-1:0] rdi_outs = {
    jtagRdi_ltsm_pl_wake_ack,
    jtagRdi_ltsm_pl_clk_req,
    jtagRdi_pl_state_sts,
    jtagRdi_pl_stallreq,
    jtagRdi_rdi_pl_inband_pres,
    jtagRdi_rdiAwake,
    jtagRdi_rdiNeedsFdiAwake,
    jtagRdi_sb_snd_valid,
    jtagRdi_sb_snd_msg,
    jtagRdi_sb_rcv_ready,
    jtagRdi_pl_phyinrecenter
  };
  localparam int unsigned ltsm_outs_W = $bits({
    jtagLtsm_sb_tx_din,
    jtagLtsm_sb_tx_valid,
    jtagLtsm_flagToAnalog_RepairClkState,
    jtagLtsm_flagToAnalog_SendClkPatterns,
    jtagLtsm_flagToAnalog_RepairValState,
    jtagLtsm_flagToAnalog_SendValTrainPattern,
    jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern,
    jtagLtsm_flagToAnalog_RepairMbSetReceiver,
    jtagLtsm_flagToAnalog_LaneReversalApplied,
    jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler,
    jtagLtsm_state,
    jtagLtsm_dbg_flagSbinitFirstClkPatternSeen,
    jtagLtsm_dbg_rxValidRisingEdge,
    jtagLtsm_dbg_sbinitSendCount,
    jtagLtsm_dbg_sbTxValid,
    jtagLtsm_dbg_sbTxDin,
    jtagLtsm_dbg_flagTrainError,
    jtagLtsm_dbg_mbinitSubstate,
    jtagLtsm_dbg_mbinitParamSenderState,
    jtagLtsm_dbg_mbinitParamReceiverState,
    jtagLtsm_dbg_mbinitCalSenderState,
    jtagLtsm_dbg_mbinitCalReceiverState,
    jtagLtsm_dbg_mbinitRepairClkSenderState,
    jtagLtsm_dbg_mbinitRepairClkReceiverState,
    jtagLtsm_dbg_mbinitRepairValSenderState,
    jtagLtsm_dbg_mbinitRepairValReceiverState,
    jtagLtsm_dbg_mbinitReversalMbSenderState,
    jtagLtsm_dbg_mbinitReversalMbReceiverState,
    jtagLtsm_dbg_mbinitRepairMbSenderState,
    jtagLtsm_dbg_mbinitRepairMbReceiverState,
    jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount,
    jtagLtsm_flagToAnalog_valVref_sendPattern,
    jtagLtsm_flagToAnalog_valVref_applyRxVref,
    jtagLtsm_flagToAnalog_valVref_rxVrefCode,
    jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_valVref_comparisonMode,
    jtagLtsm_flagToAnalog_valVref_iterationCountSettings,
    jtagLtsm_flagToAnalog_valVref_idleCountSettings,
    jtagLtsm_flagToAnalog_valVref_burstCountSettings,
    jtagLtsm_flagToAnalog_valVref_patternMode,
    jtagLtsm_flagToAnalog_valVref_clockPhaseControl,
    jtagLtsm_flagToAnalog_valVref_validPattern,
    jtagLtsm_flagToAnalog_valVref_dataPattern,
    jtagLtsm_flagToAnalog_valVref_clearComparisonErrors,
    jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_dataVref_sendPattern,
    jtagLtsm_flagToAnalog_dataVref_applyRxVref,
    jtagLtsm_flagToAnalog_dataVref_rxVrefCodes,
    jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_dataVref_comparisonMode,
    jtagLtsm_flagToAnalog_dataVref_iterationCountSettings,
    jtagLtsm_flagToAnalog_dataVref_idleCountSettings,
    jtagLtsm_flagToAnalog_dataVref_burstCountSettings,
    jtagLtsm_flagToAnalog_dataVref_patternMode,
    jtagLtsm_flagToAnalog_dataVref_clockPhaseControl,
    jtagLtsm_flagToAnalog_dataVref_validPattern,
    jtagLtsm_flagToAnalog_dataVref_dataPattern,
    jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors,
    jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_rxClkCal_doCalibration,
    jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack,
    jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern,
    jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler,
    jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase,
    jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode,
    jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode,
    jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_patternMode,
    jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    jtagLtsm_flagToAnalog_d2cReceiver_validPattern,
    jtagLtsm_flagToAnalog_d2cReceiver_dataPattern,
    jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern,
    jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_rxDeskew_comparisonMode,
    jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_patternMode,
    jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl,
    jtagLtsm_flagToAnalog_rxDeskew_validPattern,
    jtagLtsm_flagToAnalog_rxDeskew_dataPattern,
    jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain,
    jtagLtsm_dbg_mbtrainState,
    jtagLtsm_dbg_mbtrainActiveSubstate,
    jtagLtsm_dbg_mbtrainValVrefLocalState,
    jtagLtsm_dbg_mbtrainValVrefRemoteState,
    jtagLtsm_dbg_mbtrainValVrefSweepState,
    jtagLtsm_dbg_mbtrainValVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainValVrefPointResponderState,
    jtagLtsm_dbg_mbtrainDataVrefLocalState,
    jtagLtsm_dbg_mbtrainDataVrefRemoteState,
    jtagLtsm_dbg_mbtrainDataVrefSweepState,
    jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainDataVrefPointResponderState,
    jtagLtsm_dbg_mbtrainSpeedIdleSenderState,
    jtagLtsm_dbg_mbtrainSpeedIdleReceiverState,
    jtagLtsm_dbg_mbtrainTxSelfCalSenderState,
    jtagLtsm_dbg_mbtrainTxSelfCalReceiverState,
    jtagLtsm_dbg_mbtrainRxClkCalSenderState,
    jtagLtsm_dbg_mbtrainRxClkCalReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterSenderState,
    jtagLtsm_dbg_mbtrainValTrainCenterReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState,
    jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterSweepState,
    jtagLtsm_dbg_mbtrainValTrainVrefLocalState,
    jtagLtsm_dbg_mbtrainValTrainVrefRemoteState,
    jtagLtsm_dbg_mbtrainValTrainVrefSweepState,
    jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState,
    jtagLtsm_dbg_mbtrainDataTrainVrefLocalState,
    jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState,
    jtagLtsm_dbg_mbtrainDataTrainVrefSweepState,
    jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState,
    jtagLtsm_dbg_mbtrainRxDeskewLocalState,
    jtagLtsm_dbg_mbtrainRxDeskewRemoteState,
    jtagLtsm_dbg_mbtrainRxDeskewSweepState,
    jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState,
    jtagLtsm_dbg_mbtrainRxDeskewPointResponderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState,
    jtagLtsm_dbg_mbtrainLinkSpeedSenderState,
    jtagLtsm_dbg_mbtrainLinkSpeedReceiverState,
    jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState,
    jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState,
    jtagLtsm_dbg_mbtrainLastErrorCount,
    jtagLtsm_dbg_mbtrainRetryCount
  });
  wire logic [ltsm_outs_W-1:0] ltsm_outs = {
    jtagLtsm_sb_tx_din,
    jtagLtsm_sb_tx_valid,
    jtagLtsm_flagToAnalog_RepairClkState,
    jtagLtsm_flagToAnalog_SendClkPatterns,
    jtagLtsm_flagToAnalog_RepairValState,
    jtagLtsm_flagToAnalog_SendValTrainPattern,
    jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern,
    jtagLtsm_flagToAnalog_RepairMbSetReceiver,
    jtagLtsm_flagToAnalog_LaneReversalApplied,
    jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler,
    jtagLtsm_state,
    jtagLtsm_dbg_flagSbinitFirstClkPatternSeen,
    jtagLtsm_dbg_rxValidRisingEdge,
    jtagLtsm_dbg_sbinitSendCount,
    jtagLtsm_dbg_sbTxValid,
    jtagLtsm_dbg_sbTxDin,
    jtagLtsm_dbg_flagTrainError,
    jtagLtsm_dbg_mbinitSubstate,
    jtagLtsm_dbg_mbinitParamSenderState,
    jtagLtsm_dbg_mbinitParamReceiverState,
    jtagLtsm_dbg_mbinitCalSenderState,
    jtagLtsm_dbg_mbinitCalReceiverState,
    jtagLtsm_dbg_mbinitRepairClkSenderState,
    jtagLtsm_dbg_mbinitRepairClkReceiverState,
    jtagLtsm_dbg_mbinitRepairValSenderState,
    jtagLtsm_dbg_mbinitRepairValReceiverState,
    jtagLtsm_dbg_mbinitReversalMbSenderState,
    jtagLtsm_dbg_mbinitReversalMbReceiverState,
    jtagLtsm_dbg_mbinitRepairMbSenderState,
    jtagLtsm_dbg_mbinitRepairMbReceiverState,
    jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount,
    jtagLtsm_flagToAnalog_valVref_sendPattern,
    jtagLtsm_flagToAnalog_valVref_applyRxVref,
    jtagLtsm_flagToAnalog_valVref_rxVrefCode,
    jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_valVref_comparisonMode,
    jtagLtsm_flagToAnalog_valVref_iterationCountSettings,
    jtagLtsm_flagToAnalog_valVref_idleCountSettings,
    jtagLtsm_flagToAnalog_valVref_burstCountSettings,
    jtagLtsm_flagToAnalog_valVref_patternMode,
    jtagLtsm_flagToAnalog_valVref_clockPhaseControl,
    jtagLtsm_flagToAnalog_valVref_validPattern,
    jtagLtsm_flagToAnalog_valVref_dataPattern,
    jtagLtsm_flagToAnalog_valVref_clearComparisonErrors,
    jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_dataVref_sendPattern,
    jtagLtsm_flagToAnalog_dataVref_applyRxVref,
    jtagLtsm_flagToAnalog_dataVref_rxVrefCodes,
    jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_dataVref_comparisonMode,
    jtagLtsm_flagToAnalog_dataVref_iterationCountSettings,
    jtagLtsm_flagToAnalog_dataVref_idleCountSettings,
    jtagLtsm_flagToAnalog_dataVref_burstCountSettings,
    jtagLtsm_flagToAnalog_dataVref_patternMode,
    jtagLtsm_flagToAnalog_dataVref_clockPhaseControl,
    jtagLtsm_flagToAnalog_dataVref_validPattern,
    jtagLtsm_flagToAnalog_dataVref_dataPattern,
    jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors,
    jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_rxClkCal_doCalibration,
    jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack,
    jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern,
    jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler,
    jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase,
    jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode,
    jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode,
    jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings,
    jtagLtsm_flagToAnalog_d2cReceiver_patternMode,
    jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    jtagLtsm_flagToAnalog_d2cReceiver_validPattern,
    jtagLtsm_flagToAnalog_d2cReceiver_dataPattern,
    jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern,
    jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    jtagLtsm_flagToAnalog_rxDeskew_comparisonMode,
    jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings,
    jtagLtsm_flagToAnalog_rxDeskew_patternMode,
    jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl,
    jtagLtsm_flagToAnalog_rxDeskew_validPattern,
    jtagLtsm_flagToAnalog_rxDeskew_dataPattern,
    jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain,
    jtagLtsm_dbg_mbtrainState,
    jtagLtsm_dbg_mbtrainActiveSubstate,
    jtagLtsm_dbg_mbtrainValVrefLocalState,
    jtagLtsm_dbg_mbtrainValVrefRemoteState,
    jtagLtsm_dbg_mbtrainValVrefSweepState,
    jtagLtsm_dbg_mbtrainValVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainValVrefPointResponderState,
    jtagLtsm_dbg_mbtrainDataVrefLocalState,
    jtagLtsm_dbg_mbtrainDataVrefRemoteState,
    jtagLtsm_dbg_mbtrainDataVrefSweepState,
    jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainDataVrefPointResponderState,
    jtagLtsm_dbg_mbtrainSpeedIdleSenderState,
    jtagLtsm_dbg_mbtrainSpeedIdleReceiverState,
    jtagLtsm_dbg_mbtrainTxSelfCalSenderState,
    jtagLtsm_dbg_mbtrainTxSelfCalReceiverState,
    jtagLtsm_dbg_mbtrainRxClkCalSenderState,
    jtagLtsm_dbg_mbtrainRxClkCalReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterSenderState,
    jtagLtsm_dbg_mbtrainValTrainCenterReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState,
    jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState,
    jtagLtsm_dbg_mbtrainValTrainCenterSweepState,
    jtagLtsm_dbg_mbtrainValTrainVrefLocalState,
    jtagLtsm_dbg_mbtrainValTrainVrefRemoteState,
    jtagLtsm_dbg_mbtrainValTrainVrefSweepState,
    jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState,
    jtagLtsm_dbg_mbtrainDataTrainVrefLocalState,
    jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState,
    jtagLtsm_dbg_mbtrainDataTrainVrefSweepState,
    jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState,
    jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState,
    jtagLtsm_dbg_mbtrainRxDeskewLocalState,
    jtagLtsm_dbg_mbtrainRxDeskewRemoteState,
    jtagLtsm_dbg_mbtrainRxDeskewSweepState,
    jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState,
    jtagLtsm_dbg_mbtrainRxDeskewPointResponderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState,
    jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState,
    jtagLtsm_dbg_mbtrainLinkSpeedSenderState,
    jtagLtsm_dbg_mbtrainLinkSpeedReceiverState,
    jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState,
    jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState,
    jtagLtsm_dbg_mbtrainLastErrorCount,
    jtagLtsm_dbg_mbtrainRetryCount
  };

  // Only the clock of the block under test toggles.
  logic tb_clk = 1'b0;
  always #5ns tb_clk = ~tb_clk;
  typedef enum int {MODE_NONE, MODE_FDI, MODE_RDI, MODE_LTSM} mode_t;
  mode_t mode = MODE_NONE;
  assign jtagFdi_clock  = (mode == MODE_FDI)  & tb_clk;
  assign jtagRdi_clock  = (mode == MODE_RDI)  & tb_clk;
  assign jtagLtsm_clock = (mode == MODE_LTSM) & tb_clk;

  task automatic step(input int unsigned cycles);
    repeat (cycles) @(posedge tb_clk);
    #1ps;
  endtask

  // Run one block mode; quiet_* are the groups that must stay frozen.
  task automatic run_mode(input mode_t m, input string name);
    logic [func_outs_W-1:0] func0;
    logic [dig_outs_W-1:0]  dig0;
    logic [fdi_outs_W-1:0]  fdi0;
    logic [rdi_outs_W-1:0]  rdi0;
    logic [ltsm_outs_W-1:0] ltsm0;
    bit reacted = 0;
    mode = m;
    testModeFdi  = (m == MODE_FDI);
    testModeRdi  = (m == MODE_RDI);
    testModeLtsm = (m == MODE_LTSM);
    jtagFdi_reset_n  = 1'b0;
    jtagRdi_reset_n  = 1'b0;
    jtagLtsm_reset_n = 1'b0;
    // Snapshot after the (asynchronous) resets settle, before any clock edge.
    #1ps;
    func0 = func_outs; dig0 = dig_outs;
    fdi0 = fdi_outs; rdi0 = rdi_outs; ltsm0 = ltsm_outs;
    for (int unsigned c = 0; c < REACT_CYCLES; c++) begin
      if (c == 10) begin
        // Release the block under test after 10 clock cycles in reset.
        case (m)
          MODE_FDI:  jtagFdi_reset_n  = 1'b1;
          MODE_RDI:  jtagRdi_reset_n  = 1'b1;
          MODE_LTSM: jtagLtsm_reset_n = 1'b1;
          default: ;
        endcase
        #1ps;
        fdi0 = fdi_outs; rdi0 = rdi_outs; ltsm0 = ltsm_outs;
      end
      step(1);
      if (func_outs !== func0)
        $fatal(1, "[%s] functional output changed at cycle %0d", name, c);
      if (dig_outs !== dig0 || dig_outs !== '0)
        $fatal(1, "[%s] jtag_* (digital TDR) output not 0 at cycle %0d", name, c);
      if (m != MODE_FDI && fdi_outs !== '0)
        $fatal(1, "[%s] jtagFdi_* output not 0 at cycle %0d", name, c);
      if (m != MODE_RDI && rdi_outs !== '0)
        $fatal(1, "[%s] jtagRdi_* output not 0 at cycle %0d", name, c);
      if (m != MODE_LTSM && ltsm_outs !== '0)
        $fatal(1, "[%s] jtagLtsm_* output not 0 at cycle %0d", name, c);
      case (m)
        MODE_FDI:  reacted |= (fdi_outs  !== fdi0);
        MODE_RDI:  reacted |= (rdi_outs  !== rdi0);
        MODE_LTSM: reacted |= (ltsm_outs !== ltsm0);
        default: ;
      endcase
    end
    if (!reacted)
      $fatal(1, "[%s] block outputs never changed: block not running on its TDR clock/reset", name);
    $display("PASS: %s isolation: block reacts on jtag pins, rest of the top frozen", name);
    testModeFdi = 1'b0; testModeRdi = 1'b0; testModeLtsm = 1'b0;
    mode = MODE_NONE;
    step(2);
  endtask

  initial begin : run_test
    // Everything idle: all inputs 0, functional clock stopped, functional
    // reset_n asserted. The digital TDR clock is stopped too.
    testModeDigital = 1'b0;
    testModeFdi     = 1'b0;
    testModeRdi     = 1'b0;
    testModeLtsm    = 1'b0;
    testModePhy     = 1'b0;
    clock = '0;
    reset_n = '0;
    fdi_lp_linkerror = '0;
    fdi_lp_rx_active_sts = '0;
    fdi_lp_wake_req = '0;
    fdi_lp_clk_ack = '0;
    fdi_lp_stall_ack = '0;
    timeout_disable = '0;
    cycles_1us = '0;
    ltsm_start = '0;
    ltsm_stable_clk = '0;
    ltsm_pll_locked = '0;
    ltsm_stable_supply = '0;
    ltsm_flagFromAnalog_ReadyToExchangeClkPatterns = '0;
    ltsm_flagFromAnalog_FinishedClkPatterns = '0;
    ltsm_flagFromAnalog_FinishedValTrainPattern = '0;
    ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = '0;
    ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = '0;
    ltsm_flagFromAnalog_clkPatternReceivedRTRK_L = '0;
    ltsm_flagFromAnalog_clkPatternReceivedRCKN_L = '0;
    ltsm_flagFromAnalog_clkPatternReceivedRCKP_L = '0;
    ltsm_flagFromAnalog_ValTrainPatternReceived = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = '0;
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = '0;
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = '0;
    ltsm_flagFromAnalog_valVref_detectedValPattern = '0;
    ltsm_flagFromAnalog_valVref_finishedPattern = '0;
    ltsm_flagFromAnalog_valVref_rxVrefApplied = '0;
    ltsm_flagFromAnalog_dataVref_detectedDataPattern = '0;
    ltsm_flagFromAnalog_dataVref_finishedPattern = '0;
    ltsm_flagFromAnalog_dataVref_rxVrefApplied = '0;
    ltsm_flagFromAnalog_rxClkCal_done = '0;
    ltsm_flagFromAnalog_d2cSender_valTrainPatternSent = '0;
    ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied = '0;
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = '0;
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = '0;
    ltsm_flagFromAnalog_d2cSender_lfsrPatternSent = '0;
    ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied = '0;
    ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = '0;
    ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = '0;
    ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = '0;
    ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = '0;
    sb_rx_din = '0;
    sb_rx_clk = '0;
    jtag_clock = '0;
    jtag_reset_n = '0;
    jtag_fdi_lp_linkerror = '0;
    jtag_fdi_lp_rx_active_sts = '0;
    jtag_fdi_lp_wake_req = '0;
    jtag_fdi_lp_clk_ack = '0;
    jtag_fdi_lp_stall_ack = '0;
    jtag_timeout_disable = '0;
    jtag_cycles_1us = '0;
    jtag_ltsm_start = '0;
    jtag_ltsm_stable_clk = '0;
    jtag_ltsm_pll_locked = '0;
    jtag_ltsm_stable_supply = '0;
    jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns = '0;
    jtag_ltsm_flagFromAnalog_FinishedClkPatterns = '0;
    jtag_ltsm_flagFromAnalog_FinishedValTrainPattern = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = '0;
    jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = '0;
    jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L = '0;
    jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L = '0;
    jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L = '0;
    jtag_ltsm_flagFromAnalog_ValTrainPatternReceived = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = '0;
    jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = '0;
    jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = '0;
    jtag_ltsm_flagFromAnalog_valVref_detectedValPattern = '0;
    jtag_ltsm_flagFromAnalog_valVref_finishedPattern = '0;
    jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied = '0;
    jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern = '0;
    jtag_ltsm_flagFromAnalog_dataVref_finishedPattern = '0;
    jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied = '0;
    jtag_ltsm_flagFromAnalog_rxClkCal_done = '0;
    jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent = '0;
    jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied = '0;
    jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = '0;
    jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = '0;
    jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent = '0;
    jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied = '0;
    jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = '0;
    jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = '0;
    jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = '0;
    jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = '0;
    jtag_sb_rx_din = '0;
    jtag_sb_rx_clk = '0;
    jtagFdi_reset_n = '0;
    jtagFdi_cycles_1us = '0;
    jtagFdi_timeout_disable = '0;
    jtagFdi_fdi_lp_linkerror = '0;
    jtagFdi_fdi_lp_rx_active_sts = '0;
    jtagFdi_fdi_lp_wake_req = '0;
    jtagFdi_fdi_lp_clk_ack = '0;
    jtagFdi_fdi_lp_stall_ack = '0;
    jtagFdi_rdi_pl_inband_pres = '0;
    jtagFdi_rdiAwake = '0;
    jtagFdi_rdiNeedsFdiAwake = '0;
    jtagFdi_rdi_pl_stall_req = '0;
    jtagFdi_sb_snd_ready = '0;
    jtagFdi_sb_rcv_valid = '0;
    jtagFdi_sb_rcv_msg = '0;
    jtagRdi_reset_n = '0;
    jtagRdi_ltsm_lp_wake_req = '0;
    jtagRdi_ltsm_lp_clk_ack = '0;
    jtagRdi_lp_stallack = '0;
    jtagRdi_ltsm_pl_inband_pres = '0;
    jtagRdi_fdiNeedsRdiAwake = '0;
    jtagRdi_fdiAwake = '0;
    jtagRdi_sb_snd_ready = '0;
    jtagRdi_sb_rcv_valid = '0;
    jtagRdi_sb_rcv_msg = '0;
    jtagRdi_lp_linkerror = '0;
    jtagRdi_timeout_disable = '0;
    jtagRdi_cycles_1us = '0;
    jtagLtsm_reset_n = '0;
    jtagLtsm_sb_tx_ready = '0;
    jtagLtsm_sb_rx_dout = '0;
    jtagLtsm_sb_rx_valid = '0;
    jtagLtsm_start = '0;
    jtagLtsm_stable_clk = '0;
    jtagLtsm_pll_locked = '0;
    jtagLtsm_stable_supply = '0;
    jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns = '0;
    jtagLtsm_flagFromAnalog_FinishedClkPatterns = '0;
    jtagLtsm_flagFromAnalog_FinishedValTrainPattern = '0;
    jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = '0;
    jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = '0;
    jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L = '0;
    jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L = '0;
    jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L = '0;
    jtagLtsm_flagFromAnalog_ValTrainPatternReceived = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = '0;
    jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = '0;
    jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = '0;
    jtagLtsm_flagFromAnalog_valVref_detectedValPattern = '0;
    jtagLtsm_flagFromAnalog_valVref_finishedPattern = '0;
    jtagLtsm_flagFromAnalog_valVref_rxVrefApplied = '0;
    jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern = '0;
    jtagLtsm_flagFromAnalog_dataVref_finishedPattern = '0;
    jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied = '0;
    jtagLtsm_flagFromAnalog_rxClkCal_done = '0;
    jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent = '0;
    jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied = '0;
    jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = '0;
    jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = '0;
    jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent = '0;
    jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied = '0;
    jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent = '0;
    jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = '0;
    jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern = '0;
    jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = '0;
    fdi_lp_state_req = UcieUPM_interfaces_pkg::PhyStateReq_t'('0);
    jtag_fdi_lp_state_req = UcieUPM_interfaces_pkg::PhyStateReq_t'('0);
    jtagFdi_fdi_lp_state_req = UcieUPM_interfaces_pkg::PhyStateReq_t'('0);
    jtagFdi_rdi_pl_state_sts = UcieUPM_interfaces_pkg::PhyState_t'('0);
    jtagRdi_lp_state_req = UcieUPM_interfaces_pkg::PhyStateReq_t'('0);

    // Functional pins: reset released and a stimulus that would start the
    // LTSM and the FDI. Blocks that are not under test must stay quiet only
    // because the core holds them in reset, not because of these pins.
    reset_n            = 1'b1;
    cycles_1us         = 32'd10;
    fdi_lp_state_req   = PhyStateReq_active;
    fdi_lp_clk_ack     = 1'b1;
    ltsm_start         = 1'b1;
    ltsm_stable_clk    = 1'b1;
    ltsm_pll_locked    = 1'b1;
    ltsm_stable_supply = 1'b1;

    // FDI: protocol layer asks for Active, emulated RDI reports Active.
    jtagFdi_cycles_1us        = 32'd10;
    jtagFdi_fdi_lp_state_req  = PhyStateReq_active;
    jtagFdi_fdi_lp_clk_ack    = 1'b1;
    jtagFdi_rdi_pl_state_sts  = PhyState_active;
    jtagFdi_rdi_pl_inband_pres = 1'b1;
    jtagFdi_rdiAwake          = 1'b1;
    jtagFdi_sb_snd_ready      = 1'b1;
    // RDI: emulated FDI asks for Active, emulated LTSM reports link up.
    jtagRdi_cycles_1us        = 32'd10;
    jtagRdi_lp_state_req      = PhyStateReq_active;
    jtagRdi_ltsm_lp_clk_ack   = 1'b1;
    jtagRdi_ltsm_pl_inband_pres = 1'b1;
    jtagRdi_fdiNeedsRdiAwake  = 1'b1;
    jtagRdi_fdiAwake          = 1'b1;
    jtagRdi_sb_snd_ready      = 1'b1;
    // LTSM: start training with stable clock/supply.
    jtagLtsm_start            = 1'b1;
    jtagLtsm_stable_clk       = 1'b1;
    jtagLtsm_pll_locked       = 1'b1;
    jtagLtsm_stable_supply    = 1'b1;
    jtagLtsm_sb_tx_ready      = 1'b1;
    step(5);

    run_mode(MODE_FDI,  "testModeFdi");
    run_mode(MODE_RDI,  "testModeRdi");
    run_mode(MODE_LTSM, "testModeLtsm");
    $finish;
  end
endmodule

`default_nettype wire
