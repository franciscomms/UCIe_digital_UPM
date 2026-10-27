`timescale 1ns/1ps
`default_nettype none

// PHY isolation test (testModePhy) of UcieDigitalTopJtag through its TDR bus.
// GENERATED from the analog-facing ltsm_* pin list of UcieDigitalTop;
// regenerate if those pins change.
//
// Checks, with the real ctrl and phy jtag_tdr_snapshot registers:
//   - ctrl mode 5 selects testModePhy only, and holds the core in reset;
//   - in functional mode the PHY pins follow the core and the PHY TDR reads 0;
//   - in PHY mode every ltsm_flagToAnalog_* bit follows the PHY TDR write,
//     every PHY status bit is returned by the PHY TDR snapshot (both values
//     at every bit), and the core sees 0 on those inputs;
//   - jtag_nRst keeps the committed PHY word; reset_n returns to functional.
module UcieDigitalTopJtagPhyModeSpec_tb;
  localparam int unsigned validVrefCodeWidth = LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH;
  localparam int unsigned dataVrefCodeWidth = LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH;
  localparam int unsigned rxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH;
  localparam int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH;
  localparam int unsigned d2cTxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH;
  localparam int unsigned dataLaneCount = 16;

  logic clock = 1'b0, reset_n = 1'b0, jtag_nRst = 1'b0;
  logic tdr_rst = 1'b0, tdr_tck = 1'b0, tdr_tdi = 1'b0;
  logic tdr_capture = 1'b0, tdr_shift = 1'b0, tdr_update = 1'b0;
  logic sel_ctrl = 1'b0, sel_dig = 1'b0, sel_fdi = 1'b0;
  logic sel_rdi = 1'b0, sel_ltsm = 1'b0, sel_phy = 1'b0;
  wire tdo_ctrl, tdo_dig, tdo_fdi, tdo_rdi, tdo_ltsm, tdo_phy;
  always #2 clock = ~clock;

  // PHY-side pins of the DUT.
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
  logic ltsm_flagFromAnalog_linkSpeed_speedApplied;
  wire ltsm_flagToAnalog_RepairClkState;
  wire ltsm_flagToAnalog_SendClkPatterns;
  wire ltsm_flagToAnalog_RepairValState;
  wire ltsm_flagToAnalog_SendValTrainPattern;
  wire ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  wire ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  wire ltsm_flagToAnalog_RepairMbSetReceiver;
  wire ltsm_flagToAnalog_LaneReversalApplied;
  wire ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
  wire ltsm_flagToAnalog_valVref_sendPattern;
  wire ltsm_flagToAnalog_valVref_applyRxVref;
  wire [validVrefCodeWidth-1:0] ltsm_flagToAnalog_valVref_rxVrefCode;
  wire ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  wire [15:0] ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  wire ltsm_flagToAnalog_valVref_comparisonMode;
  wire [15:0] ltsm_flagToAnalog_valVref_iterationCountSettings;
  wire [15:0] ltsm_flagToAnalog_valVref_idleCountSettings;
  wire [15:0] ltsm_flagToAnalog_valVref_burstCountSettings;
  wire ltsm_flagToAnalog_valVref_patternMode;
  wire [3:0] ltsm_flagToAnalog_valVref_clockPhaseControl;
  wire [2:0] ltsm_flagToAnalog_valVref_validPattern;
  wire [2:0] ltsm_flagToAnalog_valVref_dataPattern;
  wire ltsm_flagToAnalog_valVref_clearComparisonErrors;
  wire ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
  wire ltsm_flagToAnalog_dataVref_sendPattern;
  wire ltsm_flagToAnalog_dataVref_applyRxVref;
  wire [dataLaneCount*dataVrefCodeWidth-1:0] ltsm_flagToAnalog_dataVref_rxVrefCodes;
  wire ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  wire [15:0] ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  wire ltsm_flagToAnalog_dataVref_comparisonMode;
  wire [15:0] ltsm_flagToAnalog_dataVref_iterationCountSettings;
  wire [15:0] ltsm_flagToAnalog_dataVref_idleCountSettings;
  wire [15:0] ltsm_flagToAnalog_dataVref_burstCountSettings;
  wire ltsm_flagToAnalog_dataVref_patternMode;
  wire [3:0] ltsm_flagToAnalog_dataVref_clockPhaseControl;
  wire [2:0] ltsm_flagToAnalog_dataVref_validPattern;
  wire [2:0] ltsm_flagToAnalog_dataVref_dataPattern;
  wire ltsm_flagToAnalog_dataVref_clearComparisonErrors;
  wire ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  wire ltsm_flagToAnalog_rxClkCal_doCalibration;
  wire ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  wire ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
  wire ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
  wire ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
  wire [d2cPiCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
  wire ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  wire [15:0] ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  wire ltsm_flagToAnalog_d2cReceiver_comparisonMode;
  wire [15:0] ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
  wire [15:0] ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
  wire [15:0] ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
  wire ltsm_flagToAnalog_d2cReceiver_patternMode;
  wire [3:0] ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
  wire [2:0] ltsm_flagToAnalog_d2cReceiver_validPattern;
  wire [2:0] ltsm_flagToAnalog_d2cReceiver_dataPattern;
  wire ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  wire ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
  wire ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
  wire [64*d2cTxDeskewCodeWidth-1:0] ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
  wire ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  wire ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  wire ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  wire [dataLaneCount*rxDeskewCodeWidth-1:0] ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  wire ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  wire [15:0] ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  wire ltsm_flagToAnalog_rxDeskew_comparisonMode;
  wire [15:0] ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
  wire [15:0] ltsm_flagToAnalog_rxDeskew_idleCountSettings;
  wire [15:0] ltsm_flagToAnalog_rxDeskew_burstCountSettings;
  wire ltsm_flagToAnalog_rxDeskew_patternMode;
  wire [3:0] ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
  wire [2:0] ltsm_flagToAnalog_rxDeskew_validPattern;
  wire [2:0] ltsm_flagToAnalog_rxDeskew_dataPattern;
  wire ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  wire [1:0] ltsm_flagToAnalog_linkSpeed_speedCode;
  wire ltsm_flagToAnalog_linkSpeed_applySpeed;
  wire ltsm_flagToAnalog_linkSpeed_electricalIdle;

  // Pin groups in phy_in_t / phy_out_t field order (first field = MSB).
  wire [$bits({
    ltsm_flagToAnalog_RepairClkState,
    ltsm_flagToAnalog_SendClkPatterns,
    ltsm_flagToAnalog_RepairValState,
    ltsm_flagToAnalog_SendValTrainPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSetReceiver,
    ltsm_flagToAnalog_LaneReversalApplied,
    ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
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
    ltsm_flagToAnalog_linkSpeed_speedCode,
    ltsm_flagToAnalog_linkSpeed_applySpeed,
    ltsm_flagToAnalog_linkSpeed_electricalIdle})-1:0] to_pins = {
    ltsm_flagToAnalog_RepairClkState,
    ltsm_flagToAnalog_SendClkPatterns,
    ltsm_flagToAnalog_RepairValState,
    ltsm_flagToAnalog_SendValTrainPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_RepairMbSetReceiver,
    ltsm_flagToAnalog_LaneReversalApplied,
    ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
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
    ltsm_flagToAnalog_linkSpeed_speedCode,
    ltsm_flagToAnalog_linkSpeed_applySpeed,
    ltsm_flagToAnalog_linkSpeed_electricalIdle};
  localparam int unsigned TO_W = $bits(to_pins);
  localparam int unsigned FROM_W = $bits({
    ltsm_stable_clk,
    ltsm_pll_locked,
    ltsm_stable_supply,
    ltsm_flagFromAnalog_ReadyToExchangeClkPatterns,
    ltsm_flagFromAnalog_FinishedClkPatterns,
    ltsm_flagFromAnalog_FinishedValTrainPattern,
    ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_clkPatternReceivedRTRK_L,
    ltsm_flagFromAnalog_clkPatternReceivedRCKN_L,
    ltsm_flagFromAnalog_clkPatternReceivedRCKP_L,
    ltsm_flagFromAnalog_ValTrainPatternReceived,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
    ltsm_flagFromAnalog_valVref_detectedValPattern,
    ltsm_flagFromAnalog_valVref_finishedPattern,
    ltsm_flagFromAnalog_valVref_rxVrefApplied,
    ltsm_flagFromAnalog_dataVref_detectedDataPattern,
    ltsm_flagFromAnalog_dataVref_finishedPattern,
    ltsm_flagFromAnalog_dataVref_rxVrefApplied,
    ltsm_flagFromAnalog_rxClkCal_done,
    ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
    ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
    ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
    ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,
    ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
    ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
    ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
    ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
    ltsm_flagFromAnalog_linkSpeed_speedApplied});
  logic [FROM_W-1:0] from_value = '0;
  assign {
    ltsm_stable_clk,
    ltsm_pll_locked,
    ltsm_stable_supply,
    ltsm_flagFromAnalog_ReadyToExchangeClkPatterns,
    ltsm_flagFromAnalog_FinishedClkPatterns,
    ltsm_flagFromAnalog_FinishedValTrainPattern,
    ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_clkPatternReceivedRTRK_L,
    ltsm_flagFromAnalog_clkPatternReceivedRCKN_L,
    ltsm_flagFromAnalog_clkPatternReceivedRCKP_L,
    ltsm_flagFromAnalog_ValTrainPatternReceived,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
    ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
    ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
    ltsm_flagFromAnalog_valVref_detectedValPattern,
    ltsm_flagFromAnalog_valVref_finishedPattern,
    ltsm_flagFromAnalog_valVref_rxVrefApplied,
    ltsm_flagFromAnalog_dataVref_detectedDataPattern,
    ltsm_flagFromAnalog_dataVref_finishedPattern,
    ltsm_flagFromAnalog_dataVref_rxVrefApplied,
    ltsm_flagFromAnalog_rxClkCal_done,
    ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
    ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
    ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
    ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
    ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,
    ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
    ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
    ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
    ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
    ltsm_flagFromAnalog_linkSpeed_speedApplied} = from_value;
  // What the core sees on the same PHY status inputs.
  wire [FROM_W-1:0] core_from = {
    dut.u_top.core_ltsm_stable_clk,
    dut.u_top.core_ltsm_pll_locked,
    dut.u_top.core_ltsm_stable_supply,
    dut.u_top.core_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns,
    dut.u_top.core_ltsm_flagFromAnalog_FinishedClkPatterns,
    dut.u_top.core_ltsm_flagFromAnalog_FinishedValTrainPattern,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
    dut.u_top.core_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L,
    dut.u_top.core_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L,
    dut.u_top.core_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L,
    dut.u_top.core_ltsm_flagFromAnalog_ValTrainPatternReceived,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
    dut.u_top.core_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
    dut.u_top.core_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
    dut.u_top.core_ltsm_flagFromAnalog_valVref_detectedValPattern,
    dut.u_top.core_ltsm_flagFromAnalog_valVref_finishedPattern,
    dut.u_top.core_ltsm_flagFromAnalog_valVref_rxVrefApplied,
    dut.u_top.core_ltsm_flagFromAnalog_dataVref_detectedDataPattern,
    dut.u_top.core_ltsm_flagFromAnalog_dataVref_finishedPattern,
    dut.u_top.core_ltsm_flagFromAnalog_dataVref_rxVrefApplied,
    dut.u_top.core_ltsm_flagFromAnalog_rxClkCal_done,
    dut.u_top.core_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
    dut.u_top.core_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied,
    dut.u_top.core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
    dut.u_top.core_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
    dut.u_top.core_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
    dut.u_top.core_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied,
    dut.u_top.core_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
    dut.u_top.core_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied,
    dut.u_top.core_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
    dut.u_top.core_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
    dut.u_top.core_ltsm_flagFromAnalog_linkSpeed_speedApplied};
  wire [TO_W-1:0] core_to = {
    dut.u_top.core_ltsm_flagToAnalog_RepairClkState,
    dut.u_top.core_ltsm_flagToAnalog_SendClkPatterns,
    dut.u_top.core_ltsm_flagToAnalog_RepairValState,
    dut.u_top.core_ltsm_flagToAnalog_SendValTrainPattern,
    dut.u_top.core_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    dut.u_top.core_ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    dut.u_top.core_ltsm_flagToAnalog_RepairMbSetReceiver,
    dut.u_top.core_ltsm_flagToAnalog_LaneReversalApplied,
    dut.u_top.core_ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    dut.u_top.core_ltsm_flagToAnalog_valVref_sendPattern,
    dut.u_top.core_ltsm_flagToAnalog_valVref_applyRxVref,
    dut.u_top.core_ltsm_flagToAnalog_valVref_rxVrefCode,
    dut.u_top.core_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
    dut.u_top.core_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
    dut.u_top.core_ltsm_flagToAnalog_valVref_comparisonMode,
    dut.u_top.core_ltsm_flagToAnalog_valVref_iterationCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_valVref_idleCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_valVref_burstCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_valVref_patternMode,
    dut.u_top.core_ltsm_flagToAnalog_valVref_clockPhaseControl,
    dut.u_top.core_ltsm_flagToAnalog_valVref_validPattern,
    dut.u_top.core_ltsm_flagToAnalog_valVref_dataPattern,
    dut.u_top.core_ltsm_flagToAnalog_valVref_clearComparisonErrors,
    dut.u_top.core_ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_sendPattern,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_applyRxVref,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_rxVrefCodes,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_comparisonMode,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_iterationCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_idleCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_burstCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_patternMode,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_clockPhaseControl,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_validPattern,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_dataPattern,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    dut.u_top.core_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    dut.u_top.core_ltsm_flagToAnalog_rxClkCal_doCalibration,
    dut.u_top.core_ltsm_flagToAnalog_rxClkCal_sendClockTrack,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_comparisonMode,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_patternMode,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_validPattern,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_dataPattern,
    dut.u_top.core_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
    dut.u_top.core_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_comparisonMode,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_idleCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_burstCountSettings,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_patternMode,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_validPattern,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_dataPattern,
    dut.u_top.core_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    dut.u_top.core_ltsm_flagToAnalog_linkSpeed_speedCode,
    dut.u_top.core_ltsm_flagToAnalog_linkSpeed_applySpeed,
    dut.u_top.core_ltsm_flagToAnalog_linkSpeed_electricalIdle};

  UcieDigitalTopJtag dut (
    .jtag_nRst(jtag_nRst),
    .tdr_rst(tdr_rst),
    .tdr_tck(tdr_tck),
    .tdr_tdi(tdr_tdi),
    .tdr_capture(tdr_capture),
    .tdr_shift(tdr_shift),
    .tdr_update(tdr_update),
    .sel_ctrl(sel_ctrl),
    .sel_dig(sel_dig),
    .sel_fdi(sel_fdi),
    .sel_rdi(sel_rdi),
    .sel_ltsm(sel_ltsm),
    .sel_phy(sel_phy),
    .clock(clock),
    .reset_n(reset_n),
    .fdi_lp_state_req('0),
    .fdi_lp_linkerror('0),
    .fdi_lp_rx_active_sts('0),
    .fdi_lp_wake_req('0),
    .fdi_lp_clk_ack('0),
    .fdi_lp_stall_ack('0),
    .timeout_disable('0),
    .cycles_1us('0),
    .ltsm_start('0),
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
    .ltsm_flagFromAnalog_valVref_detectedValPattern(ltsm_flagFromAnalog_valVref_detectedValPattern),
    .ltsm_flagFromAnalog_valVref_finishedPattern(ltsm_flagFromAnalog_valVref_finishedPattern),
    .ltsm_flagFromAnalog_valVref_rxVrefApplied(ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .ltsm_flagFromAnalog_dataVref_detectedDataPattern(ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataVref_finishedPattern(ltsm_flagFromAnalog_dataVref_finishedPattern),
    .ltsm_flagFromAnalog_dataVref_rxVrefApplied(ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .ltsm_flagFromAnalog_rxClkCal_done(ltsm_flagFromAnalog_rxClkCal_done),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
    .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied(ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
    .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
    .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied(ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
    .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied(ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
    .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern(ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
    .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
    .ltsm_linkSpeed_requestedSpeed('0),
    .ltsm_flagFromAnalog_linkSpeed_speedApplied(ltsm_flagFromAnalog_linkSpeed_speedApplied),
    .sb_rx_din('0),
    .sb_rx_clk('0),
    .ltsm_flagToAnalog_RepairClkState(ltsm_flagToAnalog_RepairClkState),
    .ltsm_flagToAnalog_SendClkPatterns(ltsm_flagToAnalog_SendClkPatterns),
    .ltsm_flagToAnalog_RepairValState(ltsm_flagToAnalog_RepairValState),
    .ltsm_flagToAnalog_SendValTrainPattern(ltsm_flagToAnalog_SendValTrainPattern),
    .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSendLaneIDPattern(ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
    .ltsm_flagToAnalog_RepairMbSetReceiver(ltsm_flagToAnalog_RepairMbSetReceiver),
    .ltsm_flagToAnalog_LaneReversalApplied(ltsm_flagToAnalog_LaneReversalApplied),
    .ltsm_flagToAnalog_linkInit_resetLfsrScrambler(ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
    .ltsm_flagToAnalog_valVref_sendPattern(ltsm_flagToAnalog_valVref_sendPattern),
    .ltsm_flagToAnalog_valVref_applyRxVref(ltsm_flagToAnalog_valVref_applyRxVref),
    .ltsm_flagToAnalog_valVref_rxVrefCode(ltsm_flagToAnalog_valVref_rxVrefCode),
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
    .ltsm_flagToAnalog_dataVref_applyRxVref(ltsm_flagToAnalog_dataVref_applyRxVref),
    .ltsm_flagToAnalog_dataVref_rxVrefCodes(ltsm_flagToAnalog_dataVref_rxVrefCodes),
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
    .ltsm_flagToAnalog_rxClkCal_sendClockTrack(ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .ltsm_flagToAnalog_d2cSender_sendValTrainPattern(ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
    .ltsm_flagToAnalog_d2cSender_resetLocalScrambler(ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_applyTxClockPhase(ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_txClockPhaseCode(ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
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
    .ltsm_flagToAnalog_d2cSender_sendLfsrPattern(ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
    .ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew(ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
    .ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes(ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
    .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
    .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew(ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
    .ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes(ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
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
    .ltsm_flagToAnalog_linkSpeed_speedCode(ltsm_flagToAnalog_linkSpeed_speedCode),
    .ltsm_flagToAnalog_linkSpeed_applySpeed(ltsm_flagToAnalog_linkSpeed_applySpeed),
    .ltsm_flagToAnalog_linkSpeed_electricalIdle(ltsm_flagToAnalog_linkSpeed_electricalIdle),
    .tdo_ctrl(tdo_ctrl),
    .tdo_dig(tdo_dig),
    .tdo_fdi(tdo_fdi),
    .tdo_rdi(tdo_rdi),
    .tdo_ltsm(tdo_ltsm),
    .tdo_phy(tdo_phy)
  );

  localparam int unsigned PHY_DR_W = ((TO_W > FROM_W) ? TO_W : FROM_W) + 1;
  int checks = 0;

  // TDR bus driven directly, as the external TAP would (one TCK per state).
  task automatic tck_cycle();
    #5 tdr_tck = 1'b1;
    #5 tdr_tck = 1'b0;
  endtask

  // One scan: Capture-DR, PHY_DR_W/9 x Shift-DR (LSB first), Update-DR.
  task automatic scan(input int unsigned bank, input int unsigned width,
                      input logic [PHY_DR_W-1:0] in_bits,
                      output logic [PHY_DR_W-1:0] out_bits);
    sel_ctrl = (bank == 0);
    sel_phy  = (bank == 5);
    out_bits = '0;
    tdr_capture = 1'b1; tck_cycle(); tdr_capture = 1'b0;
    tdr_shift = 1'b1;
    for (int unsigned i = 0; i < width; i++) begin
      tdr_tdi = in_bits[i];
      #1 out_bits[i] = (bank == 0) ? tdo_ctrl : tdo_phy;
      tck_cycle();
    end
    tdr_shift = 1'b0;
    tdr_update = 1'b1; tck_cycle(); tdr_update = 1'b0;
    sel_ctrl = 1'b0; sel_phy = 1'b0;
    repeat (12) tck_cycle(); // let the mailbox handshake complete
  endtask

  task automatic ctrl_write(input logic [7:0] value);
    logic [PHY_DR_W-1:0] tx, rx;
    tx = '0; tx[8:0] = {value, 1'b1};
    scan(0, 9, tx, rx);
    if (dut.ctrl_q !== value) $fatal(1, "ctrl write %h failed (ctrl_q=%h)", value, dut.ctrl_q);
  endtask

  task automatic phy_write(input logic [TO_W-1:0] value);
    logic [PHY_DR_W-1:0] tx, rx;
    tx = '0; tx[TO_W:1] = value; tx[0] = 1'b1;
    scan(5, PHY_DR_W, tx, rx);
  endtask

  // A read is two scans: the first launches the snapshot, the second shifts it out.
  task automatic phy_read(output logic [FROM_W-1:0] value);
    logic [PHY_DR_W-1:0] rx;
    scan(5, PHY_DR_W, '0, rx);
    scan(5, PHY_DR_W, '0, rx);
    if (rx[0] !== 1'b0) $fatal(1, "PHY TDR still busy after read");
    value = rx[FROM_W:1];
  endtask

  function automatic logic [PHY_DR_W-1:0] pattern(input int seed);
    logic [31:0] lfsr;
    lfsr = 32'h1d87_2b41 ^ (32'h0019_3a6d * 32'(seed));
    for (int i = 0; i < PHY_DR_W; i++) begin
      pattern[i] = lfsr[0];
      lfsr = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
    end
  endfunction

  task automatic check_functional(input string where);
    logic [FROM_W-1:0] got;
    if (dut.u_top.testModePhy !== 1'b0) $fatal(1, "[%s] testModePhy set", where);
    if (to_pins !== core_to) $fatal(1, "[%s] PHY outputs do not follow the core", where);
    if (core_from !== from_value) $fatal(1, "[%s] core does not see PHY inputs", where);
    phy_read(got);
    if (got !== '0) $fatal(1, "[%s] PHY TDR snapshot not 0 outside PHY mode", where);
    checks++;
  endtask

  task automatic check_phy_write(input logic [TO_W-1:0] value);
    phy_write(value);
    if (to_pins !== value)
      for (int i = 0; i < TO_W; i++)
        if (to_pins[i] !== value[i]) $fatal(1, "flagToAnalog bit %0d != PHY TDR", i);
    checks++;
  endtask

  task automatic check_phy_read(input logic [FROM_W-1:0] value);
    logic [FROM_W-1:0] got;
    from_value = value;
    phy_read(got);
    for (int i = 0; i < FROM_W; i++)
      if (got[i] !== value[i]) $fatal(1, "PHY status bit %0d not in PHY TDR snapshot", i);
    if (core_from !== '0) $fatal(1, "core sees PHY inputs during PHY test");
    checks++;
  endtask

  logic [PHY_DR_W-1:0] p;
  initial begin
    $display("PHY TDR: %0d bits toward PHY, %0d bits from PHY, DR length %0d",
             TO_W, FROM_W, PHY_DR_W);
    if (dut.PHY_W + 1 != PHY_DR_W) $fatal(1, "PHY_W does not match the pin list");
    #20 reset_n = 1'b1; jtag_nRst = 1'b1;
    repeat (4) tck_cycle();

    // Functional mode (ctrl reset value 0x08).
    p = pattern(1);
    from_value = p[FROM_W-1:0];
    check_functional("functional after reset");

    // Every ctrl mode decodes one-hot; mode 5 is PHY and holds the core in reset.
    for (int mode = 0; mode <= 7; mode++) begin
      ctrl_write(8'h08 | 8'(mode));
      if ({dut.u_top.testModePhy, dut.u_top.testModeLtsm, dut.u_top.testModeRdi,
           dut.u_top.testModeFdi, dut.u_top.testModeDigital} !==
          ((mode >= 1 && mode <= 5) ? (5'b1 << (mode - 1)) : 5'b0))
        $fatal(1, "mode %0d decode", mode);
    end
    checks++;

    // PHY mode. sys_rst does not matter here: the core is held in reset.
    ctrl_write(8'h05);
    if (dut.u_top.testModePhy !== 1'b1 || dut.u_top.core_reset_n !== 1'b0)
      $fatal(1, "PHY mode did not hold the core in reset");
    for (int s = 0; s < 3; s++) begin
      p = pattern(10 + s);
      check_phy_write(p[TO_W-1:0]);
      check_phy_write(~p[TO_W-1:0]);
      p = pattern(20 + s);
      check_phy_read(p[FROM_W-1:0]);
      check_phy_read(~p[FROM_W-1:0]);
    end
    // Writes and reads are independent: a read leaves the PHY word in place.
    p = pattern(30);
    check_phy_write(p[TO_W-1:0]);
    begin
      logic [PHY_DR_W-1:0] q;
      q = pattern(32);
      check_phy_read(q[FROM_W-1:0]);
    end
    if (to_pins !== p[TO_W-1:0]) $fatal(1, "PHY read changed the driven PHY word");

    // JTAG reset aborts the mailbox but keeps committed controls (ctrl and PHY).
    jtag_nRst = 1'b0; #20 jtag_nRst = 1'b1;
    repeat (4) tck_cycle();
    if (dut.u_top.testModePhy !== 1'b1 || to_pins !== p[TO_W-1:0])
      $fatal(1, "jtag_nRst changed committed PHY controls");
    checks++;

    // Back to functional through the ctrl register.
    ctrl_write(8'h08);
    check_functional("functional after PHY mode");

    // Functional reset returns ctrl (and so the PHY) to the normal path.
    ctrl_write(8'h05);
    reset_n = 1'b0; #20 reset_n = 1'b1;
    repeat (4) tck_cycle();
    check_functional("functional after reset_n");

    $display("PASS UcieDigitalTopJtagPhyModeSpec_tb checks=%0d", checks);
    $finish;
  end

  initial begin
    #50ms;
    $fatal(1, "watchdog");
  end
endmodule

`default_nettype wire
