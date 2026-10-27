// Dual-die integration harness for UcieDigitalCore.
// link_*_enable is a simulation-only serializer admission stall; it never
// gates a forwarded clock or bypasses the integrated sideband PHY.
//
// The analog models are derived from the supplied full LinkTrainingFSM
// sideband tests.  They acknowledge every new PHY-control handshake, model
// passing Vref/RX-deskew windows, and return cross-die Tx Init D2C point-test
// results through the real sideband path. No internal FSM state is forced.

`timescale 1ns/1ps
`default_nettype none

// Each die instantiates the production top with its integrated SideBandModule
// and RX mailbox. Only one data bit and its forwarded clock cross each link.

// Behavioral decoders use the physical pin weights and mux adjacency, not
// the production encoders. Invalid control words cannot pass an eye window.
package D2DAdapterLinkMgmtTbAnalogDecode_pkg;
  function automatic integer phase_index(input logic [37:0] code);
    logic [1:0] upper_sel, lower_sel;
    logic [16:0] upper_bank, lower_bank, later_bank;
    integer sector, step, coarse;
    begin
      phase_index = -1;
      upper_sel = code[1:0];
      lower_sel = code[3:2];
      upper_bank = code[20:4];
      lower_bank = code[37:21];
      sector = -1;
      if (upper_sel == lower_sel)
        sector = 2 * int'(lower_sel);
      else if (upper_sel == (lower_sel + 2'd1))
        sector = 2 * int'(lower_sel) + 1;
      later_bank = sector[0] ? upper_bank : lower_bank;
      coarse = $countones(later_bank[16:1]);
      step = 2 * coarse + int'(later_bank[0]);
      if (!$isunknown(code) && (sector >= 0) && (lower_bank === ~upper_bank) &&
          (later_bank[16:1] === (16'hffff >> (16-coarse))))
        phase_index = (33 * sector + step) % 264;
    end
  endfunction

  function automatic integer deskew_steps(input logic [19:0] code);
    integer first_coarse, second_coarse;
    begin
      first_coarse = $countones(code[9:1]);
      second_coarse = $countones(code[19:11]);
      deskew_steps = -1;
      if (!$isunknown(code) && (code[9:1] === (9'h1ff >> (9-first_coarse))) &&
          (code[19:11] === (9'h1ff >> (9-second_coarse))) &&
          ((code[19:10] == 0) || (code[9:0] == 10'h3ff)))
        deskew_steps = 2*(first_coarse + second_coarse) +
                       int'(code[0]) + int'(code[10]);
    end
  endfunction
endpackage

// Valid-lane phase-eye model used by VALTRAINCENTER.
module D2DAdapterLinkMgmtTbValTrainResultModel #(
  parameter int unsigned PI_CODE_WIDTH = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned WINDOW_LEFT   = 2,
  parameter int unsigned WINDOW_RIGHT  = 7
) (
  input  wire logic [PI_CODE_WIDTH-1:0] remote_tx_phase,
  output      logic [15:0]              local_result_info,
  output      logic [63:0]              local_result_payload
);
  localparam int unsigned PHASE_COUNT = LtsmParameters_pkg::D2C_PI_PHASE_COUNT;
  integer phase_int;
  logic valid_pass;

  always_comb begin
    phase_int = D2DAdapterLinkMgmtTbAnalogDecode_pkg::phase_index(remote_tx_phase);
    valid_pass =
      (WINDOW_LEFT <= WINDOW_RIGHT) &&
      (WINDOW_RIGHT < PHASE_COUNT) &&
      (phase_int >= 0) &&
      (phase_int >= WINDOW_LEFT) &&
      (phase_int <= WINDOW_RIGHT);

    local_result_info       = '0;
    local_result_info[5]    = valid_pass;
    local_result_info[4]    = !valid_pass;
    local_result_payload    = valid_pass ? 64'b0 : 64'hFFFF_FFFF_FFFF_FFFF;
  end
endmodule

// Per-lane phase/deskew eye model used by DATATRAINCENTER1.
module D2DAdapterLinkMgmtTbDataTrainCenter1ResultModel #(
  parameter bit          UCIE_A                         = 1'b0,
  parameter int unsigned PI_CODE_WIDTH                  = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned TX_DESKEW_CODE_WIDTH           = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned DESKEW_STEPS_PER_PI            = 1,
  parameter bit          DESKEW_ADDED_DELAY_MOVES_UP    = 1'b1,
  parameter int unsigned BASE_CENTER                    = 6,
  parameter int unsigned HALF_EYE_WIDTH                 = 2
) (
  input  wire logic [PI_CODE_WIDTH-1:0] remote_tx_phase,
  input  wire logic [64*TX_DESKEW_CODE_WIDTH-1:0] remote_tx_deskew_codes,
  output      logic [15:0] local_result_info,
  output      logic [63:0] local_result_payload
);
  localparam int unsigned PHASE_COUNT = LtsmParameters_pkg::D2C_PI_PHASE_COUNT;
  localparam logic [63:0] ACTIVE_LANE_MASK =
    UCIE_A ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;

  integer lane;
  integer phase_int;
  integer base_center_int;
  integer deskew_code_int;
  integer deskew_phase_steps_int;
  integer shifted_center_int;
  integer lower_edge_int;
  integer upper_edge_int;
  logic lane_pass;
  logic all_active_lanes_pass;

  always_comb begin
    local_result_info     = '0;
    local_result_payload  = '0;
    all_active_lanes_pass = 1'b1;
    phase_int             = D2DAdapterLinkMgmtTbAnalogDecode_pkg::phase_index(remote_tx_phase);
    base_center_int       = 0;
    deskew_code_int       = 0;
    deskew_phase_steps_int = 0;
    shifted_center_int    = 0;
    lower_edge_int        = 0;
    upper_edge_int        = 0;
    lane_pass             = 1'b0;

    for (lane = 0; lane < 64; lane = lane + 1) begin
      if (ACTIVE_LANE_MASK[lane]) begin
        base_center_int = BASE_CENTER + (lane % 4);
        deskew_code_int = D2DAdapterLinkMgmtTbAnalogDecode_pkg::deskew_steps(
          remote_tx_deskew_codes[lane*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH]);
        deskew_phase_steps_int = deskew_code_int / DESKEW_STEPS_PER_PI;

        if (DESKEW_ADDED_DELAY_MOVES_UP)
          shifted_center_int = base_center_int + deskew_phase_steps_int;
        else
          shifted_center_int = base_center_int - deskew_phase_steps_int;

        lower_edge_int = shifted_center_int - HALF_EYE_WIDTH;
        upper_edge_int = shifted_center_int + HALF_EYE_WIDTH;
        lane_pass =
          (phase_int >= 0) && (deskew_code_int >= 0) &&
          (shifted_center_int >= 0) &&
          (shifted_center_int < PHASE_COUNT) &&
          (phase_int >= lower_edge_int) &&
          (phase_int <= upper_edge_int);

        local_result_payload[lane] = lane_pass;
        if (!lane_pass)
          all_active_lanes_pass = 1'b0;
      end
    end

    local_result_info[5] = 1'b1;
    local_result_info[4] = all_active_lanes_pass;
  end
endmodule

// Aggregate post-Vref/post-RX-deskew phase-eye model for DATATRAINCENTER2.
module D2DAdapterLinkMgmtTbDataTrainCenter2ResultModel #(
  parameter bit          UCIE_A        = 1'b0,
  parameter int unsigned PI_CODE_WIDTH = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned WINDOW_LEFT   = 4,
  parameter int unsigned WINDOW_RIGHT  = 7
) (
  input  wire logic [PI_CODE_WIDTH-1:0] remote_tx_phase,
  output      logic [15:0]              local_result_info,
  output      logic [63:0]              local_result_payload
);
  localparam int unsigned PHASE_COUNT = LtsmParameters_pkg::D2C_PI_PHASE_COUNT;
  localparam logic [63:0] ACTIVE_LANE_MASK =
    UCIE_A ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;
  integer phase_int;
  logic aggregate_pass;

  always_comb begin
    phase_int = D2DAdapterLinkMgmtTbAnalogDecode_pkg::phase_index(remote_tx_phase);
    aggregate_pass =
      (WINDOW_LEFT <= WINDOW_RIGHT) &&
      (WINDOW_RIGHT < PHASE_COUNT) &&
      (phase_int >= 0) &&
      (phase_int >= WINDOW_LEFT) &&
      (phase_int <= WINDOW_RIGHT);

    local_result_info       = '0;
    local_result_info[5]    = 1'b1;
    local_result_info[4]    = aggregate_pass;
    local_result_payload    = aggregate_pass ? ACTIVE_LANE_MASK : 64'b0;
  end
endmodule
module D2DAdapterLinkMgmtLtsmSerialDieModel #(
  // FDI, RDI, and sideband widths are not part of this PHY-training model's
  // interface.  The integrated DUT therefore uses its own package defaults.
  parameter bit          UCIE_A                           = 1'b0,
  parameter int unsigned PI_CODE_WIDTH                    = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned TX_DESKEW_CODE_WIDTH             = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned DESKEW_STEPS_PER_PI              = 1,
  parameter bit          DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1,
  parameter int unsigned MIN_LANE_WINDOW_STEPS            = 3,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS          = 3,
  parameter int unsigned MAX_TRAINING_RETRIES             = 1,
  parameter int unsigned VREF_VALUE_COUNT                 =
    LtsmParameters_pkg::DEFAULT_VALID_VREF_VALUE_COUNT,
  parameter int unsigned VREF_CODE_WIDTH =
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH,
  parameter int unsigned DATA_LANE_COUNT                  = 16,
  parameter int unsigned RX_DESKEW_VALUE_COUNT            =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
  parameter int unsigned RX_DESKEW_CODE_WIDTH =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH,
  parameter int unsigned VAL_VREF_LEFT                    = 2,
  parameter int unsigned VAL_VREF_RIGHT                   = 7,
  parameter int unsigned VALTRAIN_VREF_LEFT               = 4,
  parameter int unsigned VALTRAIN_VREF_RIGHT              = 9,
  parameter int unsigned DATA_VREF_LEFT_BASE              = 0,
  parameter int unsigned DATA_VREF_LANE_PERIOD            = 4,
  parameter int unsigned DATA_VREF_WINDOW_VALUES          = 5,
  parameter int unsigned DATATRAIN_VREF_LEFT_BASE         = 2,
  parameter int unsigned DATATRAIN_VREF_LANE_PERIOD       = 5,
  parameter int unsigned DATATRAIN_VREF_WINDOW_VALUES     = 6,
  parameter int unsigned RX_DESKEW_LEFT_BASE              = 1,
  parameter int unsigned RX_DESKEW_LANE_PERIOD            = 5,
  parameter int unsigned RX_DESKEW_WINDOW_VALUES          = 6,
  // Fail one receiver lane at the highest rate, or every rate when enabled.
  // The peer observes this result through the real serialized D2C exchange.
  parameter bit          LINK_SPEED_FAIL_TOP_RATE         = 1'b0,
  parameter bit          LINK_SPEED_FAIL_ALL_RATES        = 1'b0,
  // 1: the DUT is UcieDigitalTop in testModeDigital, driven only via jtag_*.
  parameter bit          TEST_MODE_DIGITAL                = 1'b0
) (
  input wire logic clock,
  input wire logic reset_n,
  input wire logic ltsm_start,
  input wire logic ltsm_stable_clk,
  input wire logic ltsm_pll_locked,
  input wire logic ltsm_stable_supply,
  input wire logic protocol_request_active,
  // Set external_fdi_control for directed link-management tests.  When it is
  // clear, the original bring-up behavior automatically requests Active and
  // acknowledges the FDI RX-active, clock, and stall handshakes.
  input wire logic external_fdi_control,
  input wire UcieUPM_interfaces_pkg::PhyStateReq_t external_fdi_lp_state_req,
  input wire logic external_fdi_lp_linkerror,
  input wire logic external_fdi_lp_rx_active_sts,
  input wire logic external_fdi_lp_wake_req,
  input wire logic external_fdi_lp_clk_ack,
  input wire logic external_fdi_lp_stall_ack,
  input wire logic [31:0] cycles_1us,
  // Physical sideband interface: one data bit and forwarded clock each way.
  // Packet-level monitors live outside this die model and read hierarchy only.
  input  wire logic sb_tx_enable,
  output wire logic sb_tx_dout,
  output wire logic sb_tx_clk,
  input  wire logic sb_rx_din,
  input  wire logic sb_rx_clk,
  output wire logic sb_tx_idle,
  output wire logic sb_rx_overflow,
  input wire logic [15:0] ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo,
  input wire logic [63:0] ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload,
  input wire logic [15:0] ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo,
  input wire logic [63:0] ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload,
  input wire logic [15:0] ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo,
  input wire logic [63:0] ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload,
  output wire logic [PI_CODE_WIDTH-1:0] ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode,
  output wire logic [PI_CODE_WIDTH-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode,
  output wire logic [64*TX_DESKEW_CODE_WIDTH-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes,
  output wire logic [PI_CODE_WIDTH-1:0] ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode,
  output wire logic [3:0] ltsm_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts,
  output wire logic fdi_pl_rx_active_req,
  output wire logic fdi_pl_inband_pres,
  output wire logic fdi_pl_wake_ack,
  output wire logic fdi_pl_clk_req,
  output wire logic fdi_pl_stall_req,
  output wire UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t debug_rdi_state,
  output wire logic [2:0] ltsm_dbg_mbinitSubstate,
  output wire logic [3:0] ltsm_dbg_mbtrainState,
  output wire logic [11:0] ltsm_dbg_mbtrainActiveSubstate,
  output wire logic ltsm_dbg_flagTrainError,
  output wire logic debug_arb_grant_ltsm,
  output wire logic debug_arb_grant_fdi,
  output wire logic debug_arb_grant_rdi,
  output wire logic debug_arb_tx_locked,
  output wire logic debug_arb_tx_fire,
  output wire logic debug_rx_drop_unknown,
  output wire logic debug_rx_fire
);
  import UcieUPM_interfaces_pkg::*;

  // Signals for every remaining DUT port.  Declaring and explicitly
  // connecting all ports makes interface drift visible at compile time.
  UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req;
  logic fdi_lp_linkerror;
  logic fdi_lp_rx_active_sts;
  logic auto_fdi_lp_rx_active_sts;
  logic fdi_lp_wake_req;
  logic fdi_lp_clk_ack;
  logic fdi_lp_stall_ack;
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
  wire logic ltsm_flagToAnalog_RepairClkState;
  wire logic ltsm_flagToAnalog_SendClkPatterns;
  wire logic ltsm_flagToAnalog_RepairValState;
  wire logic ltsm_flagToAnalog_SendValTrainPattern;
  wire logic ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
  wire logic ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
  wire logic ltsm_flagToAnalog_RepairMbSetReceiver;
  wire logic ltsm_flagToAnalog_LaneReversalApplied;
  wire logic ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
  wire logic ltsm_dbg_flagSbinitFirstClkPatternSeen;
  wire logic ltsm_dbg_rxValidRisingEdge;
  wire logic [2:0] ltsm_dbg_sbinitSendCount;
  wire logic ltsm_dbg_sbTxValid;
  wire logic [127:0] ltsm_dbg_sbTxDin;
  wire logic [4:0] ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
  wire logic ltsm_flagToAnalog_valVref_sendPattern;
  logic ltsm_flagFromAnalog_valVref_detectedValPattern;
  logic ltsm_flagFromAnalog_valVref_finishedPattern;
  wire logic ltsm_flagToAnalog_valVref_applyRxVref;
  wire logic [VREF_CODE_WIDTH-1:0] ltsm_flagToAnalog_valVref_rxVrefCode;
  logic ltsm_flagFromAnalog_valVref_rxVrefApplied;
  wire logic ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_valVref_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_valVref_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_valVref_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_valVref_burstCountSettings;
  wire logic ltsm_flagToAnalog_valVref_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_valVref_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_valVref_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_valVref_dataPattern;
  wire logic ltsm_flagToAnalog_valVref_clearComparisonErrors;
  wire logic ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
  wire logic ltsm_flagToAnalog_dataVref_sendPattern;
  logic [DATA_LANE_COUNT-1:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern;
  logic ltsm_flagFromAnalog_dataVref_finishedPattern;
  wire logic ltsm_flagToAnalog_dataVref_applyRxVref;
  wire logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] ltsm_flagToAnalog_dataVref_rxVrefCodes;
  logic ltsm_flagFromAnalog_dataVref_rxVrefApplied;
  wire logic ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_dataVref_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_dataVref_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_dataVref_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_dataVref_burstCountSettings;
  wire logic ltsm_flagToAnalog_dataVref_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_dataVref_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_dataVref_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_dataVref_dataPattern;
  wire logic ltsm_flagToAnalog_dataVref_clearComparisonErrors;
  wire logic ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
  wire logic ltsm_flagToAnalog_rxClkCal_doCalibration;
  logic ltsm_flagFromAnalog_rxClkCal_done;
  wire logic ltsm_flagToAnalog_rxClkCal_sendClockTrack;
  wire logic ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
  logic ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent;
  wire logic ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler;
  wire logic ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
  logic ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied;
  wire logic ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings;
  wire logic ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern;
  wire logic ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler;
  wire logic ltsm_flagToAnalog_valTrainVref_sendPattern;
  logic ltsm_flagFromAnalog_valTrainVref_detectedValPattern;
  logic ltsm_flagFromAnalog_valTrainVref_finishedPattern;
  wire logic ltsm_flagToAnalog_valTrainVref_applyRxVref;
  wire logic [VREF_CODE_WIDTH-1:0] ltsm_flagToAnalog_valTrainVref_rxVrefCode;
  logic ltsm_flagFromAnalog_valTrainVref_rxVrefApplied;
  wire logic ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_valTrainVref_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_valTrainVref_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_valTrainVref_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_valTrainVref_burstCountSettings;
  wire logic ltsm_flagToAnalog_valTrainVref_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_valTrainVref_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_valTrainVref_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_valTrainVref_dataPattern;
  wire logic ltsm_flagToAnalog_valTrainVref_clearComparisonErrors;
  wire logic ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
  logic ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
  logic ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
  logic ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler;
  wire logic ltsm_flagToAnalog_dataTrainVref_sendPattern;
  logic [DATA_LANE_COUNT-1:0] ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern;
  logic ltsm_flagFromAnalog_dataTrainVref_finishedPattern;
  wire logic ltsm_flagToAnalog_dataTrainVref_applyRxVref;
  wire logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] ltsm_flagToAnalog_dataTrainVref_rxVrefCodes;
  logic ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied;
  wire logic ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_dataTrainVref_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_dataTrainVref_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_dataTrainVref_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_dataTrainVref_burstCountSettings;
  wire logic ltsm_flagToAnalog_dataTrainVref_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_dataTrainVref_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_dataTrainVref_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_dataTrainVref_dataPattern;
  wire logic ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors;
  wire logic ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler;
  wire logic ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
  logic ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
  wire logic ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
  wire logic ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
  wire logic [DATA_LANE_COUNT*RX_DESKEW_CODE_WIDTH-1:0] ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
  logic ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
  wire logic ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_rxDeskew_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_rxDeskew_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_rxDeskew_burstCountSettings;
  wire logic ltsm_flagToAnalog_rxDeskew_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_rxDeskew_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_rxDeskew_dataPattern;
  wire logic ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
  logic [DATA_LANE_COUNT-1:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
  logic ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler;
  wire logic ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
  logic ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern;
  wire logic ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler;
  // The analog speed-code request defaults to code 3 (8 GHz / 16 GT/s).
  wire logic [1:0] ltsm_flagToAnalog_linkSpeed_speedCode;
  wire logic ltsm_flagToAnalog_linkSpeed_applySpeed;
  wire logic ltsm_flagToAnalog_linkSpeed_electricalIdle;
  logic ltsm_flagFromAnalog_linkSpeed_speedApplied;
  logic linkSpeedApplyPending;
  logic [1:0] linkSpeedHeldCode;
  logic [1:0] linkSpeedApplyDelay;
  wire logic ltsm_flagToLtsm_linkSpeed_phyInRetrain;
  wire logic ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern;
  logic ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent;
  wire logic ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler;
  wire logic ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold;
  wire logic ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings;
  wire logic [15:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings;
  wire logic ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode;
  wire logic [3:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern;
  wire logic [2:0] ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern;
  wire logic ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler;
  logic [15:0] ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful;
  wire logic [15:0] ltsm_dbg_mbtrainLastErrorCount;
  wire logic [15:0] ltsm_dbg_mbtrainRetryCount;
  wire logic [3:0] debug_ltsm_state;
  wire logic debug_ltsm_inband_pres;
  wire UcieUPM_interfaces_pkg::PhyStateReq_t debug_fdi_to_rdi_state_req;
  wire logic debug_rx_route_ltsm;
  wire logic debug_rx_route_fdi;
  wire logic debug_rx_route_rdi;

  // PHY controls are one-hot switch words; passing windows use tap indices.
  // Exact comparison rejects zero, multi-hot, X/Z, and unconfigured tap bits.
  // An invalid word decodes above every physical tap and cannot pass a window.
  function automatic int unsigned vref_tap_index(
    input logic [VREF_CODE_WIDTH-1:0] code
  );
    vref_tap_index = '1;
    for (int unsigned tap = 0; tap < VREF_VALUE_COUNT; tap = tap + 1)
      if (code === (VREF_CODE_WIDTH'(1) << tap))
        vref_tap_index = tap;
  endfunction

  function automatic int unsigned data_vref_left(input int unsigned lane);
    data_vref_left = DATA_VREF_LEFT_BASE + (lane % DATA_VREF_LANE_PERIOD);
  endfunction

  function automatic int unsigned datatrain_vref_left(input int unsigned lane);
    datatrain_vref_left =
      DATATRAIN_VREF_LEFT_BASE + (lane % DATATRAIN_VREF_LANE_PERIOD);
  endfunction

  function automatic int unsigned rx_deskew_left(input int unsigned lane);
    rx_deskew_left = RX_DESKEW_LEFT_BASE + (lane % RX_DESKEW_LANE_PERIOD);
  endfunction

  assign fdi_lp_state_req = external_fdi_control
    ? external_fdi_lp_state_req
    : (protocol_request_active ? PhyStateReq_active : PhyStateReq_nop);
  assign fdi_lp_linkerror = external_fdi_control
    ? external_fdi_lp_linkerror : 1'b0;
  assign fdi_lp_rx_active_sts = external_fdi_control
    ? external_fdi_lp_rx_active_sts : auto_fdi_lp_rx_active_sts;
  assign fdi_lp_wake_req = external_fdi_control
    ? external_fdi_lp_wake_req : 1'b0;
  assign fdi_lp_clk_ack = external_fdi_control
    ? external_fdi_lp_clk_ack : fdi_pl_clk_req;
  assign fdi_lp_stall_ack = external_fdi_control
    ? external_fdi_lp_stall_ack : fdi_pl_stall_req;

  assign ltsm_flagFromAnalog_FinishedClkPatterns = 1'b1;
  assign ltsm_flagFromAnalog_FinishedValTrainPattern = 1'b1;
  assign ltsm_flagFromAnalog_ReadyToExchangeClkPatterns = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = 1'b1;
  assign ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = 1'b1;
  assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = 1'b1;
  assign ltsm_flagFromAnalog_ValTrainPatternReceived = 1'b1;
  assign ltsm_flagFromAnalog_clkPatternReceivedRCKN_L = 1'b1;
  assign ltsm_flagFromAnalog_clkPatternReceivedRCKP_L = 1'b1;
  assign ltsm_flagFromAnalog_clkPatternReceivedRTRK_L = 1'b1;

  assign ltsm_flagFromAnalog_rxClkCal_done = 1'b1;
  assign ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent = 1'b1;
  assign ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful =
    (LINK_SPEED_FAIL_TOP_RATE && (LINK_SPEED_FAIL_ALL_RATES ||
     (ltsm_flagToAnalog_linkSpeed_speedCode == 2'd3))) ? 16'hFFFE : 16'hFFFF;

  // Delay speed acknowledgement by three complete core cycles after the
  // first observed request. Check that the DUT holds its request, code and
  // electrical-idle indication until that delayed response can be consumed.
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      ltsm_flagFromAnalog_linkSpeed_speedApplied <= 1'b0;
      linkSpeedApplyPending <= 1'b0;
      linkSpeedHeldCode <= '0;
      linkSpeedApplyDelay <= '0;
    end else if (ltsm_flagToAnalog_linkSpeed_applySpeed) begin
      if (ltsm_flagToAnalog_linkSpeed_electricalIdle !== 1'b1)
        $fatal(1, "%m: speed apply must remain in electrical idle");
      if (!linkSpeedApplyPending) begin
        if ($isunknown(ltsm_flagToAnalog_linkSpeed_speedCode))
          $fatal(1, "%m: speed apply carried an unknown speed code");
        linkSpeedApplyPending <= 1'b1;
        linkSpeedHeldCode <= ltsm_flagToAnalog_linkSpeed_speedCode;
        linkSpeedApplyDelay <= '0;
        ltsm_flagFromAnalog_linkSpeed_speedApplied <= 1'b0;
      end else begin
        if (ltsm_flagToAnalog_linkSpeed_speedCode !== linkSpeedHeldCode)
          $fatal(1, "%m: speed code changed during delayed apply acknowledgement");
        if (linkSpeedApplyDelay == 2'd2)
          ltsm_flagFromAnalog_linkSpeed_speedApplied <= 1'b1;
        else
          linkSpeedApplyDelay <= linkSpeedApplyDelay + 1'b1;
      end
    end else begin
      if (linkSpeedApplyPending && !ltsm_flagFromAnalog_linkSpeed_speedApplied)
        $fatal(1, "%m: speed apply withdrawn before acknowledgement");
      ltsm_flagFromAnalog_linkSpeed_speedApplied <= 1'b0;
      linkSpeedApplyPending <= 1'b0;
      linkSpeedApplyDelay <= '0;
    end
  end

  // Registered one-cycle analog/protocol acknowledgements.  Holding the
  // request until the corresponding acknowledgement is therefore exercised.
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      auto_fdi_lp_rx_active_sts <= 1'b0;
      ltsm_flagFromAnalog_valVref_finishedPattern <= 1'b0;
      ltsm_flagFromAnalog_valVref_rxVrefApplied <= 1'b0;
      ltsm_flagFromAnalog_dataVref_finishedPattern <= 1'b0;
      ltsm_flagFromAnalog_dataVref_rxVrefApplied <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied <= 1'b0;
      ltsm_flagFromAnalog_valTrainVref_finishedPattern <= 1'b0;
      ltsm_flagFromAnalog_valTrainVref_rxVrefApplied <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied <= 1'b0;
      ltsm_flagFromAnalog_dataTrainVref_finishedPattern <= 1'b0;
      ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied <= 1'b0;
      ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent <= 1'b0;
      ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent <= 1'b0;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied <= 1'b0;
    end else begin
      auto_fdi_lp_rx_active_sts <= fdi_pl_rx_active_req;
      ltsm_flagFromAnalog_valVref_finishedPattern <=
        ltsm_flagToAnalog_valVref_sendPattern;
      ltsm_flagFromAnalog_valVref_rxVrefApplied <=
        ltsm_flagToAnalog_valVref_applyRxVref;
      ltsm_flagFromAnalog_dataVref_finishedPattern <=
        ltsm_flagToAnalog_dataVref_sendPattern;
      ltsm_flagFromAnalog_dataVref_rxVrefApplied <=
        ltsm_flagToAnalog_dataVref_applyRxVref;
      ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent <=
        ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern;
      ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied <=
        ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase;
      ltsm_flagFromAnalog_valTrainVref_finishedPattern <=
        ltsm_flagToAnalog_valTrainVref_sendPattern;
      ltsm_flagFromAnalog_valTrainVref_rxVrefApplied <=
        ltsm_flagToAnalog_valTrainVref_applyRxVref;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent <=
        ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied <=
        ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied <=
        ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew;
      ltsm_flagFromAnalog_dataTrainVref_finishedPattern <=
        ltsm_flagToAnalog_dataTrainVref_sendPattern;
      ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied <=
        ltsm_flagToAnalog_dataTrainVref_applyRxVref;
      ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent <=
        ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
      ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied <=
        ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent <=
        ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern;
      ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied <=
        ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase;
    end
  end

  // PHY-side passing windows for all newly exposed receiver controls.
  always_comb begin
    ltsm_flagFromAnalog_valVref_detectedValPattern =
      (vref_tap_index(ltsm_flagToAnalog_valVref_rxVrefCode) >= VAL_VREF_LEFT) &&
      (vref_tap_index(ltsm_flagToAnalog_valVref_rxVrefCode) <= VAL_VREF_RIGHT);
    ltsm_flagFromAnalog_valTrainVref_detectedValPattern =
      (vref_tap_index(ltsm_flagToAnalog_valTrainVref_rxVrefCode) >= VALTRAIN_VREF_LEFT) &&
      (vref_tap_index(ltsm_flagToAnalog_valTrainVref_rxVrefCode) <= VALTRAIN_VREF_RIGHT);

    ltsm_flagFromAnalog_dataVref_detectedDataPattern = '0;
    ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern = '0;
    ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = '0;

    for (int unsigned lane = 0; lane < DATA_LANE_COUNT; lane = lane + 1) begin
      ltsm_flagFromAnalog_dataVref_detectedDataPattern[lane] =
        (vref_tap_index(ltsm_flagToAnalog_dataVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH]) >= data_vref_left(lane)) &&
        (vref_tap_index(ltsm_flagToAnalog_dataVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH]) <
           (data_vref_left(lane) + DATA_VREF_WINDOW_VALUES));

      ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern[lane] =
        (vref_tap_index(ltsm_flagToAnalog_dataTrainVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH]) >= datatrain_vref_left(lane)) &&
        (vref_tap_index(ltsm_flagToAnalog_dataTrainVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH]) <
           (datatrain_vref_left(lane) + DATATRAIN_VREF_WINDOW_VALUES));

      ltsm_flagFromAnalog_rxDeskew_detectedDataPattern[lane] =
        (D2DAdapterLinkMgmtTbAnalogDecode_pkg::deskew_steps(
           ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes[
             lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH]) >=
           rx_deskew_left(lane)) &&
        (D2DAdapterLinkMgmtTbAnalogDecode_pkg::deskew_steps(
           ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes[
             lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH]) <
           (rx_deskew_left(lane) + RX_DESKEW_WINDOW_VALUES));
    end
  end

  // Scalar status for the integrated serial transmitter (sb_tx_idle) and the
  // sb_tx_enable override are assigned in the g_dut block at the end.
  //
  // The physical pins provide no packet ready input. Directed tests can
  // pause only the integrated FIFO's admission handshake. Forcing the FIFO's
  // ready output also stalls the arbiter, so neither side counts an enqueue.
  // Already accepted packets keep draining through the unmodified serial PHY.
  // Normal bring-up keeps sb_tx_enable high and applies no override.

  // --------------------------------------------------------------------------
  // Shared MBTRAIN analog-port adapter
  // MBTrainFSM drives one shared set of valVref/dataVref and D2C sender/receiver
  // ports for all MBTRAIN substates and zeroes them outside the owning state.
  // The per-substate analog models in this file are kept unchanged: the DUT
  // MBTRAIN state (ltsm_dbg_mbtrainState) demuxes the shared requests to the
  // model of the active substate and muxes that model's responses back.
  // TX phase and TX lane-deskew codes are latched on their apply request, as
  // the PHY retains applied values; the peer die eye models see those codes.
  // --------------------------------------------------------------------------
  localparam logic [3:0] MBTRAIN_VALVREF = 4'd1;
  localparam logic [3:0] MBTRAIN_DATAVREF = 4'd2;
  localparam logic [3:0] MBTRAIN_VALTRAINCENTER = 4'd6;
  localparam logic [3:0] MBTRAIN_VALTRAINVREF = 4'd7;
  localparam logic [3:0] MBTRAIN_DATATRAINCENTER1 = 4'd8;
  localparam logic [3:0] MBTRAIN_DATATRAINVREF = 4'd9;
  localparam logic [3:0] MBTRAIN_DATATRAINCENTER2 = 4'd11;
  localparam logic [3:0] MBTRAIN_LINKSPEED = 4'd12;

  wire logic fdi_active;
  wire logic phy_flagToAnalog_valVref_sendPattern;
  logic phy_flagFromAnalog_valVref_detectedValPattern;
  logic phy_flagFromAnalog_valVref_finishedPattern;
  wire logic phy_flagToAnalog_valVref_applyRxVref;
  wire logic [VREF_CODE_WIDTH-1:0] phy_flagToAnalog_valVref_rxVrefCode;
  logic phy_flagFromAnalog_valVref_rxVrefApplied;
  wire logic phy_flagToAnalog_valVref_configureRxInitD2CPointTest;
  wire logic [15:0] phy_flagToAnalog_valVref_maximumComparisonErrorThreshold;
  wire logic phy_flagToAnalog_valVref_comparisonMode;
  wire logic [15:0] phy_flagToAnalog_valVref_iterationCountSettings;
  wire logic [15:0] phy_flagToAnalog_valVref_idleCountSettings;
  wire logic [15:0] phy_flagToAnalog_valVref_burstCountSettings;
  wire logic phy_flagToAnalog_valVref_patternMode;
  wire logic [3:0] phy_flagToAnalog_valVref_clockPhaseControl;
  wire logic [2:0] phy_flagToAnalog_valVref_validPattern;
  wire logic [2:0] phy_flagToAnalog_valVref_dataPattern;
  wire logic phy_flagToAnalog_valVref_clearComparisonErrors;
  wire logic phy_flagToAnalog_valVref_resetLocalTxScrambler;
  wire logic phy_flagToAnalog_dataVref_sendPattern;
  logic [DATA_LANE_COUNT-1:0] phy_flagFromAnalog_dataVref_detectedDataPattern;
  logic phy_flagFromAnalog_dataVref_finishedPattern;
  wire logic phy_flagToAnalog_dataVref_applyRxVref;
  wire logic [DATA_LANE_COUNT*VREF_CODE_WIDTH-1:0] phy_flagToAnalog_dataVref_rxVrefCodes;
  logic phy_flagFromAnalog_dataVref_rxVrefApplied;
  wire logic phy_flagToAnalog_dataVref_configureRxInitD2CPointTest;
  wire logic [15:0] phy_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
  wire logic phy_flagToAnalog_dataVref_comparisonMode;
  wire logic [15:0] phy_flagToAnalog_dataVref_iterationCountSettings;
  wire logic [15:0] phy_flagToAnalog_dataVref_idleCountSettings;
  wire logic [15:0] phy_flagToAnalog_dataVref_burstCountSettings;
  wire logic phy_flagToAnalog_dataVref_patternMode;
  wire logic [3:0] phy_flagToAnalog_dataVref_clockPhaseControl;
  wire logic [2:0] phy_flagToAnalog_dataVref_validPattern;
  wire logic [2:0] phy_flagToAnalog_dataVref_dataPattern;
  wire logic phy_flagToAnalog_dataVref_clearComparisonErrors;
  wire logic phy_flagToAnalog_dataVref_resetLocalTxScrambler;
  wire logic phy_flagToAnalog_d2cSender_sendValTrainPattern;
  logic phy_flagFromAnalog_d2cSender_valTrainPatternSent;
  wire logic phy_flagToAnalog_d2cSender_resetLocalScrambler;
  wire logic phy_flagToAnalog_d2cSender_applyTxClockPhase;
  wire logic [PI_CODE_WIDTH-1:0] phy_flagToAnalog_d2cSender_txClockPhaseCode;
  logic phy_flagFromAnalog_d2cSender_txClockPhaseApplied;
  wire logic phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
  wire logic [15:0] phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
  wire logic phy_flagToAnalog_d2cReceiver_comparisonMode;
  wire logic [15:0] phy_flagToAnalog_d2cReceiver_iterationCountSettings;
  wire logic [15:0] phy_flagToAnalog_d2cReceiver_idleCountSettings;
  wire logic [15:0] phy_flagToAnalog_d2cReceiver_burstCountSettings;
  wire logic phy_flagToAnalog_d2cReceiver_patternMode;
  wire logic [3:0] phy_flagToAnalog_d2cReceiver_clockPhaseControl;
  wire logic [2:0] phy_flagToAnalog_d2cReceiver_validPattern;
  wire logic [2:0] phy_flagToAnalog_d2cReceiver_dataPattern;
  wire logic phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
  logic [15:0] phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
  logic [63:0] phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
  wire logic phy_flagToAnalog_d2cSender_sendLfsrPattern;
  logic phy_flagFromAnalog_d2cSender_lfsrPatternSent;
  wire logic phy_flagToAnalog_d2cSender_applyTxLaneDeskew;
  wire logic [64*TX_DESKEW_CODE_WIDTH-1:0] phy_flagToAnalog_d2cSender_txLaneDeskewCodes;
  logic phy_flagFromAnalog_d2cSender_txLaneDeskewApplied;
  logic [15:0] phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;

  logic [PI_CODE_WIDTH-1:0]          phy_txClockPhaseLatched;
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] phy_txLaneDeskewLatched;
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      phy_txClockPhaseLatched <= {17'h00000, 17'h1ffff, 4'b0000};
      phy_txLaneDeskewLatched <= '0;
    end else begin
      if (phy_flagToAnalog_d2cSender_applyTxClockPhase)
        phy_txClockPhaseLatched <= phy_flagToAnalog_d2cSender_txClockPhaseCode;
      if (phy_flagToAnalog_d2cSender_applyTxLaneDeskew)
        phy_txLaneDeskewLatched <= phy_flagToAnalog_d2cSender_txLaneDeskewCodes;
    end
  end

  // Requests/configuration: shared DUT outputs -> per-substate model signals.
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode = phy_txClockPhaseLatched;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode = phy_txClockPhaseLatched;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes = phy_txLaneDeskewLatched;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode = phy_txClockPhaseLatched;
  assign ltsm_flagToAnalog_valVref_sendPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_sendPattern : '0;
  assign ltsm_flagToAnalog_valVref_applyRxVref =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_valVref_rxVrefCode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_rxVrefCode : '0;
  assign ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_valVref_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_valVref_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_valVref_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_patternMode : '0;
  assign ltsm_flagToAnalog_valVref_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_valVref_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_validPattern : '0;
  assign ltsm_flagToAnalog_valVref_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_dataPattern : '0;
  assign ltsm_flagToAnalog_valVref_clearComparisonErrors =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_valVref_resetLocalTxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALVREF) ? phy_flagToAnalog_valVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_dataVref_sendPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_sendPattern : '0;
  assign ltsm_flagToAnalog_dataVref_applyRxVref =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_dataVref_rxVrefCodes =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_rxVrefCodes : '0;
  assign ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_dataVref_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_dataVref_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_dataVref_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_patternMode : '0;
  assign ltsm_flagToAnalog_dataVref_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_dataVref_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_validPattern : '0;
  assign ltsm_flagToAnalog_dataVref_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_dataPattern : '0;
  assign ltsm_flagToAnalog_dataVref_clearComparisonErrors =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_dataVref_resetLocalTxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATAVREF) ? phy_flagToAnalog_dataVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cSender_sendValTrainPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cSender_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINCENTER) ? phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_valTrainVref_sendPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_sendPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_applyRxVref =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_valTrainVref_rxVrefCode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_rxVrefCode : '0;
  assign ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_valTrainVref_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_valTrainVref_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_valTrainVref_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_patternMode : '0;
  assign ltsm_flagToAnalog_valTrainVref_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_valTrainVref_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_validPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_dataPattern : '0;
  assign ltsm_flagToAnalog_valTrainVref_clearComparisonErrors =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_VALTRAINVREF) ? phy_flagToAnalog_valVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cSender_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cSender_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cSender_applyTxLaneDeskew : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER1) ? phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_dataTrainVref_sendPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_sendPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_applyRxVref =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_applyRxVref : '0;
  assign ltsm_flagToAnalog_dataTrainVref_rxVrefCodes =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_rxVrefCodes : '0;
  assign ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_configureRxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_dataTrainVref_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_comparisonMode : '0;
  assign ltsm_flagToAnalog_dataTrainVref_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_idleCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_burstCountSettings : '0;
  assign ltsm_flagToAnalog_dataTrainVref_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_patternMode : '0;
  assign ltsm_flagToAnalog_dataTrainVref_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_dataTrainVref_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_validPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_dataPattern : '0;
  assign ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_clearComparisonErrors : '0;
  assign ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINVREF) ? phy_flagToAnalog_dataVref_resetLocalTxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cSender_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cSender_applyTxClockPhase : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_DATATRAINCENTER2) ? phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;
  assign ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cSender_sendLfsrPattern : '0;
  assign ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cSender_resetLocalScrambler : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_comparisonMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_iterationCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_idleCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_burstCountSettings : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_patternMode : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_clockPhaseControl : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_validPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_dataPattern : '0;
  assign ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler =
    (ltsm_dbg_mbtrainState == MBTRAIN_LINKSPEED) ? phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler : '0;

  // Responses: per-substate model signals -> shared DUT inputs.
  always_comb begin
    phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = '0;
    phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = '0;
    phy_flagFromAnalog_valVref_detectedValPattern = '0;
    phy_flagFromAnalog_valVref_finishedPattern = '0;
    phy_flagFromAnalog_valVref_rxVrefApplied = '0;
    phy_flagFromAnalog_dataVref_detectedDataPattern = '0;
    phy_flagFromAnalog_dataVref_finishedPattern = '0;
    phy_flagFromAnalog_dataVref_rxVrefApplied = '0;
    phy_flagFromAnalog_d2cSender_valTrainPatternSent = '0;
    phy_flagFromAnalog_d2cSender_txClockPhaseApplied = '0;
    phy_flagFromAnalog_d2cSender_lfsrPatternSent = '0;
    phy_flagFromAnalog_d2cSender_txLaneDeskewApplied = '0;
    phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = '0;
    case (ltsm_dbg_mbtrainState)
      MBTRAIN_VALVREF: begin
        phy_flagFromAnalog_valVref_detectedValPattern = ltsm_flagFromAnalog_valVref_detectedValPattern;
        phy_flagFromAnalog_valVref_finishedPattern = ltsm_flagFromAnalog_valVref_finishedPattern;
        phy_flagFromAnalog_valVref_rxVrefApplied = ltsm_flagFromAnalog_valVref_rxVrefApplied;
      end
      MBTRAIN_DATAVREF: begin
        phy_flagFromAnalog_dataVref_detectedDataPattern = ltsm_flagFromAnalog_dataVref_detectedDataPattern;
        phy_flagFromAnalog_dataVref_finishedPattern = ltsm_flagFromAnalog_dataVref_finishedPattern;
        phy_flagFromAnalog_dataVref_rxVrefApplied = ltsm_flagFromAnalog_dataVref_rxVrefApplied;
      end
      MBTRAIN_VALTRAINCENTER: begin
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo;
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload;
        phy_flagFromAnalog_d2cSender_valTrainPatternSent = ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent;
        phy_flagFromAnalog_d2cSender_txClockPhaseApplied = ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied;
      end
      MBTRAIN_VALTRAINVREF: begin
        phy_flagFromAnalog_valVref_detectedValPattern = ltsm_flagFromAnalog_valTrainVref_detectedValPattern;
        phy_flagFromAnalog_valVref_finishedPattern = ltsm_flagFromAnalog_valTrainVref_finishedPattern;
        phy_flagFromAnalog_valVref_rxVrefApplied = ltsm_flagFromAnalog_valTrainVref_rxVrefApplied;
      end
      MBTRAIN_DATATRAINCENTER1: begin
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo;
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload;
        phy_flagFromAnalog_d2cSender_txClockPhaseApplied = ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied;
        phy_flagFromAnalog_d2cSender_lfsrPatternSent = ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent;
        phy_flagFromAnalog_d2cSender_txLaneDeskewApplied = ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied;
      end
      MBTRAIN_DATATRAINVREF: begin
        phy_flagFromAnalog_dataVref_detectedDataPattern = ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern;
        phy_flagFromAnalog_dataVref_finishedPattern = ltsm_flagFromAnalog_dataTrainVref_finishedPattern;
        phy_flagFromAnalog_dataVref_rxVrefApplied = ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied;
      end
      MBTRAIN_DATATRAINCENTER2: begin
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo;
        phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload;
        phy_flagFromAnalog_d2cSender_txClockPhaseApplied = ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied;
        phy_flagFromAnalog_d2cSender_lfsrPatternSent = ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent;
      end
      MBTRAIN_LINKSPEED: begin
        phy_flagFromAnalog_d2cSender_lfsrPatternSent = ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent;
        phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful;
      end
      default: ;
    endcase
  end

  // --------------------------------------------------------------------------
  // DUT
  // TEST_MODE_DIGITAL = 0: UcieDigitalCore, driven directly.
  // TEST_MODE_DIGITAL = 1: UcieDigitalTop with testModeDigital = 1. The model
  // drives and observes only the jtag_* pins, with the same connections as
  // the core. Functional pins carry junk (clocks stopped, reset asserted,
  // other inputs inverted) and every functional output must stay 0.
  // Both branches share the g_dut name; the sideband monitor nets below give
  // the harnesses one hierarchy-independent view of the DUT.
  // --------------------------------------------------------------------------
  logic         sb_mon_tx_valid;
  logic [127:0] sb_mon_tx_msg;
  logic         sb_mon_tx_ready;
  logic         sb_mon_rx_valid;
  logic [127:0] sb_mon_rx_msg;
  logic         sb_mon_rx_ready;

  if (!TEST_MODE_DIGITAL) begin : g_dut
    UcieDigitalCore #(
      // The link-management widths are intentionally left at the DUT defaults;
      // this testbench only drives link-management control and sideband traffic.
      .sbFeatureExtension                       (1'b0),
      .ucieA                                    (UCIE_A),
      .moduleID                                 (2'd0),
      .clkPhase                                 (1'b0),
      .clkMode                                  (1'b0),
      .voltageSwing                             (5'd7),
      .maxLinkSpeed                             (4'd3),
      .d2cPiCodeWidth                           (PI_CODE_WIDTH),
      .d2cTxDeskewCodeWidth                     (TX_DESKEW_CODE_WIDTH),
      .d2cDeskewStepsPerPi                      (DESKEW_STEPS_PER_PI),
      .d2cDeskewAddDelayIncreasesPhase          (DESKEW_ADD_DELAY_INCREASES_PHASE),
      .d2cMaximumComparisonErrorThreshold       (16'd0),
      .d2cMinLaneWindowSteps                    (MIN_LANE_WINDOW_STEPS),
      .d2cMinCommonWindowSteps                  (MIN_COMMON_WINDOW_STEPS),
      .d2cMaxTrainingRetries                    (MAX_TRAINING_RETRIES),
      .validVrefValueCount                      (VREF_VALUE_COUNT),
      .validVrefCodeWidth                       (VREF_CODE_WIDTH),
      .validVrefMinimumMillivolts               (250),
      .validVrefMaximumMillivolts               (550),
      .validVrefMaximumComparisonErrorThreshold (16'd0),
      .validVrefMinPassingWindowValues          (1),
      .validVrefMaxTrainingRetries              (MAX_TRAINING_RETRIES),
      .valTrainVrefEnable                       (1'b1),
      .dataLaneCount                            (DATA_LANE_COUNT),
      .activeDataLaneMask                       ({DATA_LANE_COUNT{1'b1}}),
      .dataVrefValueCount                       (VREF_VALUE_COUNT),
      .dataVrefCodeWidth                        (VREF_CODE_WIDTH),
      .dataVrefMinimumMillivolts                (250),
      .dataVrefMaximumMillivolts                (550),
      .dataVrefMaximumComparisonErrorThreshold  (16'd0),
      .dataVrefMinPassingWindowValues           (1),
      .dataVrefMaxTrainingRetries               (MAX_TRAINING_RETRIES),
      .dataTrainVrefEnable                      (1'b1),
      .rxDeskewEnable                           (1'b1),
      .rxDeskewValueCount                       (RX_DESKEW_VALUE_COUNT),
      .rxDeskewCodeWidth                        (RX_DESKEW_CODE_WIDTH),
      .rxDeskewMaximumComparisonErrorThreshold  (16'd0),
      .rxDeskewMinPassingWindowValues           (1),
      .rxDeskewMaxTrainingRetries               (MAX_TRAINING_RETRIES)
    ) dut (
      .clock                                                                          (clock),
      .reset_n                                                                        (reset_n),
      .fdi_lp_state_req                                                               (fdi_lp_state_req),
      .fdi_lp_linkerror                                                               (fdi_lp_linkerror),
      .fdi_lp_rx_active_sts                                                           (fdi_lp_rx_active_sts),
      .fdi_lp_wake_req                                                                (fdi_lp_wake_req),
      .fdi_lp_clk_ack                                                                 (fdi_lp_clk_ack),
      .fdi_lp_stall_ack                                                               (fdi_lp_stall_ack),
      .fdi_pl_state_sts                                                               (fdi_pl_state_sts),
      .fdi_pl_rx_active_req                                                           (fdi_pl_rx_active_req),
      .fdi_pl_inband_pres                                                             (fdi_pl_inband_pres),
      .fdi_pl_wake_ack                                                                (fdi_pl_wake_ack),
      .fdi_pl_clk_req                                                                 (fdi_pl_clk_req),
      .fdi_pl_stall_req                                                               (fdi_pl_stall_req),
      .fdi_active                                                                     (fdi_active),
      .sb_tx_dout                                                                     (sb_tx_dout),
      .sb_tx_clk                                                                      (sb_tx_clk),
      .sb_rx_din                                                                      (sb_rx_din),
      .sb_rx_clk                                                                      (sb_rx_clk),
      .debug_sb_rx_overflow                                                           (sb_rx_overflow),
      .timeout_disable                                                                (1'b0),
      .cycles_1us                                                                     (cycles_1us),
      .ltsm_start                                                                     (ltsm_start),
      .ltsm_stable_clk                                                                (ltsm_stable_clk),
      .ltsm_pll_locked                                                                (ltsm_pll_locked),
      .ltsm_stable_supply                                                             (ltsm_stable_supply),
      .ltsm_flagFromAnalog_ReadyToExchangeClkPatterns                                 (ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
      .ltsm_flagFromAnalog_FinishedClkPatterns                                        (ltsm_flagFromAnalog_FinishedClkPatterns),
      .ltsm_flagFromAnalog_FinishedValTrainPattern                                    (ltsm_flagFromAnalog_FinishedValTrainPattern),
      .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                            (ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
      .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                              (ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
      .ltsm_flagFromAnalog_clkPatternReceivedRTRK_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
      .ltsm_flagFromAnalog_clkPatternReceivedRCKN_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
      .ltsm_flagFromAnalog_clkPatternReceivedRCKP_L                                   (ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
      .ltsm_flagFromAnalog_ValTrainPatternReceived                                    (ltsm_flagFromAnalog_ValTrainPatternReceived),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9                            (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15                           (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                             (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                            (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
      .ltsm_flagToAnalog_RepairClkState                                               (ltsm_flagToAnalog_RepairClkState),
      .ltsm_flagToAnalog_SendClkPatterns                                              (ltsm_flagToAnalog_SendClkPatterns),
      .ltsm_flagToAnalog_RepairValState                                               (ltsm_flagToAnalog_RepairValState),
      .ltsm_flagToAnalog_SendValTrainPattern                                          (ltsm_flagToAnalog_SendValTrainPattern),
      .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern                                  (ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
      .ltsm_flagToAnalog_RepairMbSendLaneIDPattern                                    (ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
      .ltsm_flagToAnalog_RepairMbSetReceiver                                          (ltsm_flagToAnalog_RepairMbSetReceiver),
      .ltsm_flagToAnalog_LaneReversalApplied                                          (ltsm_flagToAnalog_LaneReversalApplied),
      .ltsm_flagToAnalog_linkInit_resetLfsrScrambler                                  (ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
      .ltsm_state                                                                     (ltsm_state),
      .ltsm_dbg_flagSbinitFirstClkPatternSeen                                         (ltsm_dbg_flagSbinitFirstClkPatternSeen),
      .ltsm_dbg_rxValidRisingEdge                                                     (ltsm_dbg_rxValidRisingEdge),
      .ltsm_dbg_sbinitSendCount                                                       (ltsm_dbg_sbinitSendCount),
      .ltsm_dbg_sbTxValid                                                             (ltsm_dbg_sbTxValid),
      .ltsm_dbg_sbTxDin                                                               (ltsm_dbg_sbTxDin),
      .ltsm_dbg_flagTrainError                                                        (ltsm_dbg_flagTrainError),
      .ltsm_dbg_mbinitSubstate                                                        (ltsm_dbg_mbinitSubstate),
      .ltsm_dbg_mbinitReversalMbReceivedSuccessCount                                  (ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
      .ltsm_flagToAnalog_valVref_sendPattern                                          (phy_flagToAnalog_valVref_sendPattern),
      .ltsm_flagFromAnalog_valVref_detectedValPattern                                 (phy_flagFromAnalog_valVref_detectedValPattern),
      .ltsm_flagFromAnalog_valVref_finishedPattern                                    (phy_flagFromAnalog_valVref_finishedPattern),
      .ltsm_flagToAnalog_valVref_applyRxVref                                          (phy_flagToAnalog_valVref_applyRxVref),
      .ltsm_flagToAnalog_valVref_rxVrefCode                                           (phy_flagToAnalog_valVref_rxVrefCode),
      .ltsm_flagFromAnalog_valVref_rxVrefApplied                                      (phy_flagFromAnalog_valVref_rxVrefApplied),
      .ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest                          (phy_flagToAnalog_valVref_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                      (phy_flagToAnalog_valVref_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_valVref_comparisonMode                                       (phy_flagToAnalog_valVref_comparisonMode),
      .ltsm_flagToAnalog_valVref_iterationCountSettings                               (phy_flagToAnalog_valVref_iterationCountSettings),
      .ltsm_flagToAnalog_valVref_idleCountSettings                                    (phy_flagToAnalog_valVref_idleCountSettings),
      .ltsm_flagToAnalog_valVref_burstCountSettings                                   (phy_flagToAnalog_valVref_burstCountSettings),
      .ltsm_flagToAnalog_valVref_patternMode                                          (phy_flagToAnalog_valVref_patternMode),
      .ltsm_flagToAnalog_valVref_clockPhaseControl                                    (phy_flagToAnalog_valVref_clockPhaseControl),
      .ltsm_flagToAnalog_valVref_validPattern                                         (phy_flagToAnalog_valVref_validPattern),
      .ltsm_flagToAnalog_valVref_dataPattern                                          (phy_flagToAnalog_valVref_dataPattern),
      .ltsm_flagToAnalog_valVref_clearComparisonErrors                                (phy_flagToAnalog_valVref_clearComparisonErrors),
      .ltsm_flagToAnalog_valVref_resetLocalTxScrambler                                (phy_flagToAnalog_valVref_resetLocalTxScrambler),
      .ltsm_flagToAnalog_dataVref_sendPattern                                         (phy_flagToAnalog_dataVref_sendPattern),
      .ltsm_flagFromAnalog_dataVref_detectedDataPattern                               (phy_flagFromAnalog_dataVref_detectedDataPattern),
      .ltsm_flagFromAnalog_dataVref_finishedPattern                                   (phy_flagFromAnalog_dataVref_finishedPattern),
      .ltsm_flagToAnalog_dataVref_applyRxVref                                         (phy_flagToAnalog_dataVref_applyRxVref),
      .ltsm_flagToAnalog_dataVref_rxVrefCodes                                         (phy_flagToAnalog_dataVref_rxVrefCodes),
      .ltsm_flagFromAnalog_dataVref_rxVrefApplied                                     (phy_flagFromAnalog_dataVref_rxVrefApplied),
      .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                         (phy_flagToAnalog_dataVref_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (phy_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_dataVref_comparisonMode                                      (phy_flagToAnalog_dataVref_comparisonMode),
      .ltsm_flagToAnalog_dataVref_iterationCountSettings                              (phy_flagToAnalog_dataVref_iterationCountSettings),
      .ltsm_flagToAnalog_dataVref_idleCountSettings                                   (phy_flagToAnalog_dataVref_idleCountSettings),
      .ltsm_flagToAnalog_dataVref_burstCountSettings                                  (phy_flagToAnalog_dataVref_burstCountSettings),
      .ltsm_flagToAnalog_dataVref_patternMode                                         (phy_flagToAnalog_dataVref_patternMode),
      .ltsm_flagToAnalog_dataVref_clockPhaseControl                                   (phy_flagToAnalog_dataVref_clockPhaseControl),
      .ltsm_flagToAnalog_dataVref_validPattern                                        (phy_flagToAnalog_dataVref_validPattern),
      .ltsm_flagToAnalog_dataVref_dataPattern                                         (phy_flagToAnalog_dataVref_dataPattern),
      .ltsm_flagToAnalog_dataVref_clearComparisonErrors                               (phy_flagToAnalog_dataVref_clearComparisonErrors),
      .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler                               (phy_flagToAnalog_dataVref_resetLocalTxScrambler),
      .ltsm_flagToAnalog_rxClkCal_doCalibration                                       (ltsm_flagToAnalog_rxClkCal_doCalibration),
      .ltsm_flagFromAnalog_rxClkCal_done                                              (ltsm_flagFromAnalog_rxClkCal_done),
      .ltsm_flagToAnalog_rxClkCal_sendClockTrack                                      (ltsm_flagToAnalog_rxClkCal_sendClockTrack),
      .ltsm_flagToAnalog_d2cSender_sendValTrainPattern                                (phy_flagToAnalog_d2cSender_sendValTrainPattern),
      .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent                              (phy_flagFromAnalog_d2cSender_valTrainPatternSent),
      .ltsm_flagToAnalog_d2cSender_resetLocalScrambler                                (phy_flagToAnalog_d2cSender_resetLocalScrambler),
      .ltsm_flagToAnalog_d2cSender_applyTxClockPhase                                  (phy_flagToAnalog_d2cSender_applyTxClockPhase),
      .ltsm_flagToAnalog_d2cSender_txClockPhaseCode                                   (phy_flagToAnalog_d2cSender_txClockPhaseCode),
      .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied                              (phy_flagFromAnalog_d2cSender_txClockPhaseApplied),
      .ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                      (phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
      .ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold                  (phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_d2cReceiver_comparisonMode                                   (phy_flagToAnalog_d2cReceiver_comparisonMode),
      .ltsm_flagToAnalog_d2cReceiver_iterationCountSettings                           (phy_flagToAnalog_d2cReceiver_iterationCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_idleCountSettings                                (phy_flagToAnalog_d2cReceiver_idleCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_burstCountSettings                               (phy_flagToAnalog_d2cReceiver_burstCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_patternMode                                      (phy_flagToAnalog_d2cReceiver_patternMode),
      .ltsm_flagToAnalog_d2cReceiver_clockPhaseControl                                (phy_flagToAnalog_d2cReceiver_clockPhaseControl),
      .ltsm_flagToAnalog_d2cReceiver_validPattern                                     (phy_flagToAnalog_d2cReceiver_validPattern),
      .ltsm_flagToAnalog_d2cReceiver_dataPattern                                      (phy_flagToAnalog_d2cReceiver_dataPattern),
      .ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                            (phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
      .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                        (phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
      .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                        (phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
      .ltsm_flagToAnalog_d2cSender_sendLfsrPattern                                    (phy_flagToAnalog_d2cSender_sendLfsrPattern),
      .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent                                  (phy_flagFromAnalog_d2cSender_lfsrPatternSent),
      .ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew                                  (phy_flagToAnalog_d2cSender_applyTxLaneDeskew),
      .ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes                                  (phy_flagToAnalog_d2cSender_txLaneDeskewCodes),
      .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                              (phy_flagFromAnalog_d2cSender_txLaneDeskewApplied),
      .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern                                     (ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
      .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                   (ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
      .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                               (ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
      .ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                   (ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
      .ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                   (ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
      .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                               (ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
      .ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                         (ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                     (ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_rxDeskew_comparisonMode                                      (ltsm_flagToAnalog_rxDeskew_comparisonMode),
      .ltsm_flagToAnalog_rxDeskew_iterationCountSettings                              (ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
      .ltsm_flagToAnalog_rxDeskew_idleCountSettings                                   (ltsm_flagToAnalog_rxDeskew_idleCountSettings),
      .ltsm_flagToAnalog_rxDeskew_burstCountSettings                                  (ltsm_flagToAnalog_rxDeskew_burstCountSettings),
      .ltsm_flagToAnalog_rxDeskew_patternMode                                         (ltsm_flagToAnalog_rxDeskew_patternMode),
      .ltsm_flagToAnalog_rxDeskew_clockPhaseControl                                   (ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
      .ltsm_flagToAnalog_rxDeskew_validPattern                                        (ltsm_flagToAnalog_rxDeskew_validPattern),
      .ltsm_flagToAnalog_rxDeskew_dataPattern                                         (ltsm_flagToAnalog_rxDeskew_dataPattern),
      .ltsm_flagToAnalog_rxDeskew_clearComparisonErrors                               (ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
      .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern                               (ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
      .ltsm_linkSpeed_requestedSpeed                                                   (2'd3),
      .ltsm_flagToAnalog_linkSpeed_speedCode                                           (ltsm_flagToAnalog_linkSpeed_speedCode),
      .ltsm_flagToAnalog_linkSpeed_applySpeed                                          (ltsm_flagToAnalog_linkSpeed_applySpeed),
      .ltsm_flagToAnalog_linkSpeed_electricalIdle                                      (ltsm_flagToAnalog_linkSpeed_electricalIdle),
      .ltsm_flagFromAnalog_linkSpeed_speedApplied                                      (ltsm_flagFromAnalog_linkSpeed_speedApplied),
      .ltsm_flagToLtsm_linkSpeed_phyInRetrain                                         (ltsm_flagToLtsm_linkSpeed_phyInRetrain),
      .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                       (phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
      .ltsm_dbg_mbtrainState                                                          (ltsm_dbg_mbtrainState),
      .ltsm_dbg_mbtrainActiveSubstate                                                 (ltsm_dbg_mbtrainActiveSubstate),
      .ltsm_dbg_mbtrainLastErrorCount                                                 (ltsm_dbg_mbtrainLastErrorCount),
      .ltsm_dbg_mbtrainRetryCount                                                     (ltsm_dbg_mbtrainRetryCount),
      .debug_ltsm_state                                                               (debug_ltsm_state),
      .debug_ltsm_inband_pres                                                         (debug_ltsm_inband_pres),
      .debug_fdi_link_init_state                                                      (debug_fdi_link_init_state),
      .debug_rdi_state                                                                (debug_rdi_state),
      .debug_fdi_to_rdi_state_req                                                     (debug_fdi_to_rdi_state_req),
      .debug_arb_grant_ltsm                                                           (debug_arb_grant_ltsm),
      .debug_arb_grant_fdi                                                            (debug_arb_grant_fdi),
      .debug_arb_grant_rdi                                                            (debug_arb_grant_rdi),
      .debug_arb_tx_locked                                                            (debug_arb_tx_locked),
      .debug_arb_tx_fire                                                              (debug_arb_tx_fire),
      .debug_rx_route_ltsm                                                            (debug_rx_route_ltsm),
      .debug_rx_route_fdi                                                             (debug_rx_route_fdi),
      .debug_rx_route_rdi                                                             (debug_rx_route_rdi),
      .debug_rx_drop_unknown                                                          (debug_rx_drop_unknown),
      .debug_rx_fire                                                                  (debug_rx_fire),

      // FDI isolation test mode is not exercised here: tied off.
      .testModeFdi                                                                    (1'b0),
      .jtagFdi_reset_n                                                                (1'b0),
      .jtagFdi_cycles_1us                                                             (32'd0),
      .jtagFdi_timeout_disable                                                        (1'b0),
      .jtagFdi_fdi_lp_state_req                                                       (UcieUPM_interfaces_pkg::PhyStateReq_nop),
      .jtagFdi_fdi_lp_linkerror                                                       (1'b0),
      .jtagFdi_fdi_lp_rx_active_sts                                                   (1'b0),
      .jtagFdi_fdi_lp_wake_req                                                        (1'b0),
      .jtagFdi_fdi_lp_clk_ack                                                         (1'b0),
      .jtagFdi_fdi_lp_stall_ack                                                       (1'b0),
      .jtagFdi_fdi_pl_state_sts                                                       (),
      .jtagFdi_fdi_pl_rx_active_req                                                   (),
      .jtagFdi_fdi_pl_inband_pres                                                     (),
      .jtagFdi_fdi_pl_wake_ack                                                        (),
      .jtagFdi_fdi_pl_clk_req                                                         (),
      .jtagFdi_fdi_pl_stall_req                                                       (),
      .jtagFdi_fdi_active                                                             (),
      .jtagFdi_debug_link_init_state                                                  (),
      .jtagFdi_rdi_lp_linkerror                                                       (),
      .jtagFdi_rdi_lp_state_req                                                       (),
      .jtagFdi_rdi_pl_state_sts                                                       (UcieUPM_interfaces_pkg::PhyState_t'('0)),
      .jtagFdi_rdi_pl_inband_pres                                                     (1'b0),
      .jtagFdi_fdiNeedsRdiAwake                                                       (),
      .jtagFdi_rdiAwake                                                               (1'b0),
      .jtagFdi_rdiNeedsFdiAwake                                                       (1'b0),
      .jtagFdi_fdiAwake                                                               (),
      .jtagFdi_rdi_pl_stall_req                                                       (1'b0),
      .jtagFdi_rdi_lp_stall_ack                                                       (),
      .jtagFdi_sb_snd_valid                                                           (),
      .jtagFdi_sb_snd_msg                                                             (),
      .jtagFdi_sb_snd_ready                                                           (1'b0),
      .jtagFdi_sb_rcv_valid                                                           (1'b0),
      .jtagFdi_sb_rcv_msg                                                             (128'd0),
      .jtagFdi_sb_rcv_ready                                                           (),
      .testModeRdi                                                                     (1'b0),
      .jtagRdi_reset_n                                                                 ('0),
      .jtagRdi_ltsm_lp_wake_req                                                        ('0),
      .jtagRdi_ltsm_pl_wake_ack                                                        (),
      .jtagRdi_ltsm_pl_clk_req                                                         (),
      .jtagRdi_ltsm_lp_clk_ack                                                         ('0),
      .jtagRdi_lp_state_req                                                            (UcieUPM_interfaces_pkg::PhyStateReq_t'('0)),
      .jtagRdi_pl_state_sts                                                            (),
      .jtagRdi_pl_stallreq                                                             (),
      .jtagRdi_lp_stallack                                                             ('0),
      .jtagRdi_rdi_pl_inband_pres                                                      (),
      .jtagRdi_ltsm_pl_inband_pres                                                     ('0),
      .jtagRdi_fdiNeedsRdiAwake                                                        ('0),
      .jtagRdi_rdiAwake                                                                (),
      .jtagRdi_rdiNeedsFdiAwake                                                        (),
      .jtagRdi_fdiAwake                                                                ('0),
      .jtagRdi_sb_snd_valid                                                            (),
      .jtagRdi_sb_snd_msg                                                              (),
      .jtagRdi_sb_snd_ready                                                            ('0),
      .jtagRdi_sb_rcv_valid                                                            ('0),
      .jtagRdi_sb_rcv_msg                                                              ('0),
      .jtagRdi_sb_rcv_ready                                                            (),
      .jtagRdi_lp_linkerror                                                            ('0),
      .jtagRdi_pl_phyinrecenter                                                        (),
      .jtagRdi_timeout_disable                                                         ('0),
      .jtagRdi_cycles_1us                                                              ('0),
      .testModeLtsm                                                                    (1'b0),
      .jtagLtsm_reset_n                                                                ('0),
      .jtagLtsm_sb_tx_din                                                              (),
      .jtagLtsm_sb_tx_valid                                                            (),
      .jtagLtsm_sb_tx_ready                                                            ('0),
      .jtagLtsm_sb_rx_dout                                                             ('0),
      .jtagLtsm_sb_rx_valid                                                            ('0),
      .jtagLtsm_start                                                                  ('0),
      .jtagLtsm_stable_clk                                                             ('0),
      .jtagLtsm_pll_locked                                                             ('0),
      .jtagLtsm_stable_supply                                                          ('0),
      .jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns                              ('0),
      .jtagLtsm_flagFromAnalog_FinishedClkPatterns                                     ('0),
      .jtagLtsm_flagFromAnalog_FinishedValTrainPattern                                 ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                           ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L                                ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L                                ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L                                ('0),
      .jtagLtsm_flagFromAnalog_ValTrainPatternReceived                                 ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15                        ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                         ('0),
      .jtagLtsm_flagToAnalog_RepairClkState                                            (),
      .jtagLtsm_flagToAnalog_SendClkPatterns                                           (),
      .jtagLtsm_flagToAnalog_RepairValState                                            (),
      .jtagLtsm_flagToAnalog_SendValTrainPattern                                       (),
      .jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern                               (),
      .jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern                                 (),
      .jtagLtsm_flagToAnalog_RepairMbSetReceiver                                       (),
      .jtagLtsm_flagToAnalog_LaneReversalApplied                                       (),
      .jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler                               (),
      .jtagLtsm_state                                                                  (),
      .jtagLtsm_dbg_flagSbinitFirstClkPatternSeen                                      (),
      .jtagLtsm_dbg_rxValidRisingEdge                                                  (),
      .jtagLtsm_dbg_sbinitSendCount                                                    (),
      .jtagLtsm_dbg_sbTxValid                                                          (),
      .jtagLtsm_dbg_sbTxDin                                                            (),
      .jtagLtsm_dbg_flagTrainError                                                     (),
      .jtagLtsm_dbg_mbinitSubstate                                                     (),
      .jtagLtsm_dbg_mbinitParamSenderState                                             (),
      .jtagLtsm_dbg_mbinitParamReceiverState                                           (),
      .jtagLtsm_dbg_mbinitCalSenderState                                               (),
      .jtagLtsm_dbg_mbinitCalReceiverState                                             (),
      .jtagLtsm_dbg_mbinitRepairClkSenderState                                         (),
      .jtagLtsm_dbg_mbinitRepairClkReceiverState                                       (),
      .jtagLtsm_dbg_mbinitRepairValSenderState                                         (),
      .jtagLtsm_dbg_mbinitRepairValReceiverState                                       (),
      .jtagLtsm_dbg_mbinitReversalMbSenderState                                        (),
      .jtagLtsm_dbg_mbinitReversalMbReceiverState                                      (),
      .jtagLtsm_dbg_mbinitRepairMbSenderState                                          (),
      .jtagLtsm_dbg_mbinitRepairMbReceiverState                                        (),
      .jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount                               (),
      .jtagLtsm_flagToAnalog_valVref_sendPattern                                       (),
      .jtagLtsm_flagFromAnalog_valVref_detectedValPattern                              ('0),
      .jtagLtsm_flagFromAnalog_valVref_finishedPattern                                 ('0),
      .jtagLtsm_flagToAnalog_valVref_applyRxVref                                       (),
      .jtagLtsm_flagToAnalog_valVref_rxVrefCode                                        (),
      .jtagLtsm_flagFromAnalog_valVref_rxVrefApplied                                   ('0),
      .jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest                       (),
      .jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                   (),
      .jtagLtsm_flagToAnalog_valVref_comparisonMode                                    (),
      .jtagLtsm_flagToAnalog_valVref_iterationCountSettings                            (),
      .jtagLtsm_flagToAnalog_valVref_idleCountSettings                                 (),
      .jtagLtsm_flagToAnalog_valVref_burstCountSettings                                (),
      .jtagLtsm_flagToAnalog_valVref_patternMode                                       (),
      .jtagLtsm_flagToAnalog_valVref_clockPhaseControl                                 (),
      .jtagLtsm_flagToAnalog_valVref_validPattern                                      (),
      .jtagLtsm_flagToAnalog_valVref_dataPattern                                       (),
      .jtagLtsm_flagToAnalog_valVref_clearComparisonErrors                             (),
      .jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler                             (),
      .jtagLtsm_flagToAnalog_dataVref_sendPattern                                      (),
      .jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern                            ('0),
      .jtagLtsm_flagFromAnalog_dataVref_finishedPattern                                ('0),
      .jtagLtsm_flagToAnalog_dataVref_applyRxVref                                      (),
      .jtagLtsm_flagToAnalog_dataVref_rxVrefCodes                                      (),
      .jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied                                  ('0),
      .jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                      (),
      .jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                  (),
      .jtagLtsm_flagToAnalog_dataVref_comparisonMode                                   (),
      .jtagLtsm_flagToAnalog_dataVref_iterationCountSettings                           (),
      .jtagLtsm_flagToAnalog_dataVref_idleCountSettings                                (),
      .jtagLtsm_flagToAnalog_dataVref_burstCountSettings                               (),
      .jtagLtsm_flagToAnalog_dataVref_patternMode                                      (),
      .jtagLtsm_flagToAnalog_dataVref_clockPhaseControl                                (),
      .jtagLtsm_flagToAnalog_dataVref_validPattern                                     (),
      .jtagLtsm_flagToAnalog_dataVref_dataPattern                                      (),
      .jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors                            (),
      .jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler                            (),
      .jtagLtsm_flagToAnalog_rxClkCal_doCalibration                                    (),
      .jtagLtsm_flagFromAnalog_rxClkCal_done                                           ('0),
      .jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack                                   (),
      .jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern                             (),
      .jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent                           ('0),
      .jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler                             (),
      .jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase                               (),
      .jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode                                (),
      .jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied                           ('0),
      .jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold               (),
      .jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode                                (),
      .jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings                        (),
      .jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings                             (),
      .jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings                            (),
      .jtagLtsm_flagToAnalog_d2cReceiver_patternMode                                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl                             (),
      .jtagLtsm_flagToAnalog_d2cReceiver_validPattern                                  (),
      .jtagLtsm_flagToAnalog_d2cReceiver_dataPattern                                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                         (),
      .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                     ('0),
      .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                     ('0),
      .jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern                                 (),
      .jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent                               ('0),
      .jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew                               (),
      .jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes                               (),
      .jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                           ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern                                  (),
      .jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                            (),
      .jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                (),
      .jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                            ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                  (),
      .jtagLtsm_flagToAnalog_rxDeskew_comparisonMode                                   (),
      .jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings                           (),
      .jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings                               (),
      .jtagLtsm_flagToAnalog_rxDeskew_patternMode                                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_validPattern                                     (),
      .jtagLtsm_flagToAnalog_rxDeskew_dataPattern                                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors                            (),
      .jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern                            ('0),
      .jtagLtsm_linkSpeed_requestedSpeed                                               (2'd0),
      .jtagLtsm_flagToAnalog_linkSpeed_speedCode                                       (),
      .jtagLtsm_flagToAnalog_linkSpeed_applySpeed                                      (),
      .jtagLtsm_flagToAnalog_linkSpeed_electricalIdle                                  (),
      .jtagLtsm_flagFromAnalog_linkSpeed_speedApplied                                  (1'b0),
      .jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain                                      (),
      .jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                    ('0),
      .jtagLtsm_dbg_mbtrainState                                                       (),
      .jtagLtsm_dbg_mbtrainActiveSubstate                                              (),
      .jtagLtsm_dbg_mbtrainValVrefLocalState                                           (),
      .jtagLtsm_dbg_mbtrainValVrefRemoteState                                          (),
      .jtagLtsm_dbg_mbtrainValVrefSweepState                                           (),
      .jtagLtsm_dbg_mbtrainValVrefPointInitiatorState                                  (),
      .jtagLtsm_dbg_mbtrainValVrefPointResponderState                                  (),
      .jtagLtsm_dbg_mbtrainDataVrefLocalState                                          (),
      .jtagLtsm_dbg_mbtrainDataVrefRemoteState                                         (),
      .jtagLtsm_dbg_mbtrainDataVrefSweepState                                          (),
      .jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState                                 (),
      .jtagLtsm_dbg_mbtrainDataVrefPointResponderState                                 (),
      .jtagLtsm_dbg_mbtrainSpeedIdleSenderState                                        (),
      .jtagLtsm_dbg_mbtrainSpeedIdleReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainTxSelfCalSenderState                                        (),
      .jtagLtsm_dbg_mbtrainTxSelfCalReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainRxClkCalSenderState                                         (),
      .jtagLtsm_dbg_mbtrainRxClkCalReceiverState                                       (),
      .jtagLtsm_dbg_mbtrainValTrainCenterSenderState                                   (),
      .jtagLtsm_dbg_mbtrainValTrainCenterReceiverState                                 (),
      .jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState                                (),
      .jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState                              (),
      .jtagLtsm_dbg_mbtrainValTrainCenterSweepState                                    (),
      .jtagLtsm_dbg_mbtrainValTrainVrefLocalState                                      (),
      .jtagLtsm_dbg_mbtrainValTrainVrefRemoteState                                     (),
      .jtagLtsm_dbg_mbtrainValTrainVrefSweepState                                      (),
      .jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState                             (),
      .jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState                             (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState                               (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState                              (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState                                  (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefLocalState                                     (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState                                    (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefSweepState                                     (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState                            (),
      .jtagLtsm_dbg_mbtrainRxDeskewLocalState                                          (),
      .jtagLtsm_dbg_mbtrainRxDeskewRemoteState                                         (),
      .jtagLtsm_dbg_mbtrainRxDeskewSweepState                                          (),
      .jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState                                 (),
      .jtagLtsm_dbg_mbtrainRxDeskewPointResponderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState                               (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState                              (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState                                  (),
      .jtagLtsm_dbg_mbtrainLinkSpeedSenderState                                        (),
      .jtagLtsm_dbg_mbtrainLinkSpeedReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState                                     (),
      .jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState                                   (),
      .jtagLtsm_dbg_mbtrainLastErrorCount                                              (),
      .jtagLtsm_dbg_mbtrainRetryCount                                                  ()
    );

    assign sb_tx_idle      = (dut.u_sideband.u_sideband_phy.txCount == 0) &&
                             dut.u_sideband.u_sideband_phy.txInternalReady;
    assign sb_mon_tx_valid  = dut.u_sideband.sb_msg_tx_valid;
    assign sb_mon_tx_msg    = dut.u_sideband.sb_msg_tx_msg;
    assign sb_mon_tx_ready  = dut.u_sideband.sb_msg_tx_ready;
    assign sb_mon_rx_valid  = dut.u_sideband.sb_msg_rx_valid;
    assign sb_mon_rx_msg    = dut.u_sideband.sb_msg_rx_msg;
    assign sb_mon_rx_ready  = dut.u_sideband.sb_msg_rx_ready;

    // See sb_tx_enable above: pauses only the FIFO admission handshake.
    always @(sb_tx_enable) begin
      if (!sb_tx_enable)
        force dut.u_sideband.u_sideband_phy.tx_ready = 1'b0;
      else
        release dut.u_sideband.u_sideband_phy.tx_ready;
    end
  end else begin : g_dut
    // Core parameter names, so port types below match UcieDigitalCore.
    localparam sbFeatureExtension = 1'b0;
    localparam ucieA = UCIE_A;
    localparam moduleID = 2'd0;
    localparam clkPhase = 1'b0;
    localparam clkMode = 1'b0;
    localparam voltageSwing = 5'd7;
    localparam maxLinkSpeed = 4'd3;
    localparam d2cPiCodeWidth = PI_CODE_WIDTH;
    localparam d2cTxDeskewCodeWidth = TX_DESKEW_CODE_WIDTH;
    localparam d2cDeskewStepsPerPi = DESKEW_STEPS_PER_PI;
    localparam d2cDeskewAddDelayIncreasesPhase = DESKEW_ADD_DELAY_INCREASES_PHASE;
    localparam d2cMaximumComparisonErrorThreshold = 16'd0;
    localparam d2cMinLaneWindowSteps = MIN_LANE_WINDOW_STEPS;
    localparam d2cMinCommonWindowSteps = MIN_COMMON_WINDOW_STEPS;
    localparam d2cMaxTrainingRetries = MAX_TRAINING_RETRIES;
    localparam validVrefValueCount = VREF_VALUE_COUNT;
    localparam validVrefCodeWidth = VREF_CODE_WIDTH;
    localparam validVrefMinimumMillivolts = 250;
    localparam validVrefMaximumMillivolts = 550;
    localparam validVrefMaximumComparisonErrorThreshold = 16'd0;
    localparam validVrefMinPassingWindowValues = 1;
    localparam validVrefMaxTrainingRetries = MAX_TRAINING_RETRIES;
    localparam valTrainVrefEnable = 1'b1;
    localparam dataLaneCount = DATA_LANE_COUNT;
    localparam activeDataLaneMask = {DATA_LANE_COUNT{1'b1}};
    localparam dataVrefValueCount = VREF_VALUE_COUNT;
    localparam dataVrefCodeWidth = VREF_CODE_WIDTH;
    localparam dataVrefMinimumMillivolts = 250;
    localparam dataVrefMaximumMillivolts = 550;
    localparam dataVrefMaximumComparisonErrorThreshold = 16'd0;
    localparam dataVrefMinPassingWindowValues = 1;
    localparam dataVrefMaxTrainingRetries = MAX_TRAINING_RETRIES;
    localparam dataTrainVrefEnable = 1'b1;
    localparam rxDeskewEnable = 1'b1;
    localparam rxDeskewValueCount = RX_DESKEW_VALUE_COUNT;
    localparam rxDeskewCodeWidth = RX_DESKEW_CODE_WIDTH;
    localparam rxDeskewMaximumComparisonErrorThreshold = 16'd0;
    localparam rxDeskewMinPassingWindowValues = 1;
    localparam rxDeskewMaxTrainingRetries = MAX_TRAINING_RETRIES;

    // Functional pins of UcieDigitalTop (unused in testModeDigital).
    logic func_clock;
    logic func_reset_n;
    UcieUPM_interfaces_pkg::PhyStateReq_t func_fdi_lp_state_req;
    logic func_fdi_lp_linkerror;
    logic func_fdi_lp_rx_active_sts;
    logic func_fdi_lp_wake_req;
    logic func_fdi_lp_clk_ack;
    logic func_fdi_lp_stall_ack;
    UcieUPM_interfaces_pkg::PhyState_t func_fdi_pl_state_sts;
    logic func_fdi_pl_rx_active_req;
    logic func_fdi_pl_inband_pres;
    logic func_fdi_pl_wake_ack;
    logic func_fdi_pl_clk_req;
    logic func_fdi_pl_stall_req;
    logic func_fdi_active;
    logic func_sb_tx_dout;
    logic func_sb_tx_clk;
    logic func_sb_rx_din;
    logic func_sb_rx_clk;
    logic func_debug_sb_rx_overflow;
    logic func_timeout_disable;
    logic [31:0] func_cycles_1us;
    logic func_ltsm_start;
    logic func_ltsm_stable_clk;
    logic func_ltsm_pll_locked;
    logic func_ltsm_stable_supply;
    logic func_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns;
    logic func_ltsm_flagFromAnalog_FinishedClkPatterns;
    logic func_ltsm_flagFromAnalog_FinishedValTrainPattern;
    logic func_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern;
    logic func_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern;
    logic func_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L;
    logic func_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L;
    logic func_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L;
    logic func_ltsm_flagFromAnalog_ValTrainPatternReceived;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14;
    logic func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14;
    logic func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15;
    logic func_ltsm_flagToAnalog_RepairClkState;
    logic func_ltsm_flagToAnalog_SendClkPatterns;
    logic func_ltsm_flagToAnalog_RepairValState;
    logic func_ltsm_flagToAnalog_SendValTrainPattern;
    logic func_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern;
    logic func_ltsm_flagToAnalog_RepairMbSendLaneIDPattern;
    logic func_ltsm_flagToAnalog_RepairMbSetReceiver;
    logic func_ltsm_flagToAnalog_LaneReversalApplied;
    logic func_ltsm_flagToAnalog_linkInit_resetLfsrScrambler;
    logic [3:0] func_ltsm_state;
    logic func_ltsm_dbg_flagSbinitFirstClkPatternSeen;
    logic func_ltsm_dbg_rxValidRisingEdge;
    logic [2:0] func_ltsm_dbg_sbinitSendCount;
    logic func_ltsm_dbg_sbTxValid;
    logic [127:0] func_ltsm_dbg_sbTxDin;
    logic func_ltsm_dbg_flagTrainError;
    logic [2:0] func_ltsm_dbg_mbinitSubstate;
    logic [4:0] func_ltsm_dbg_mbinitReversalMbReceivedSuccessCount;
    logic func_ltsm_flagToAnalog_valVref_sendPattern;
    logic func_ltsm_flagFromAnalog_valVref_detectedValPattern;
    logic func_ltsm_flagFromAnalog_valVref_finishedPattern;
    logic func_ltsm_flagToAnalog_valVref_applyRxVref;
    logic [validVrefCodeWidth-1:0] func_ltsm_flagToAnalog_valVref_rxVrefCode;
    logic func_ltsm_flagFromAnalog_valVref_rxVrefApplied;
    logic func_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest;
    logic [15:0] func_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold;
    logic func_ltsm_flagToAnalog_valVref_comparisonMode;
    logic [15:0] func_ltsm_flagToAnalog_valVref_iterationCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_valVref_idleCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_valVref_burstCountSettings;
    logic func_ltsm_flagToAnalog_valVref_patternMode;
    logic [3:0] func_ltsm_flagToAnalog_valVref_clockPhaseControl;
    logic [2:0] func_ltsm_flagToAnalog_valVref_validPattern;
    logic [2:0] func_ltsm_flagToAnalog_valVref_dataPattern;
    logic func_ltsm_flagToAnalog_valVref_clearComparisonErrors;
    logic func_ltsm_flagToAnalog_valVref_resetLocalTxScrambler;
    logic func_ltsm_flagToAnalog_dataVref_sendPattern;
    logic [dataLaneCount-1:0] func_ltsm_flagFromAnalog_dataVref_detectedDataPattern;
    logic func_ltsm_flagFromAnalog_dataVref_finishedPattern;
    logic func_ltsm_flagToAnalog_dataVref_applyRxVref;
    logic [dataLaneCount*dataVrefCodeWidth-1:0] func_ltsm_flagToAnalog_dataVref_rxVrefCodes;
    logic func_ltsm_flagFromAnalog_dataVref_rxVrefApplied;
    logic func_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest;
    logic [15:0] func_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold;
    logic func_ltsm_flagToAnalog_dataVref_comparisonMode;
    logic [15:0] func_ltsm_flagToAnalog_dataVref_iterationCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_dataVref_idleCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_dataVref_burstCountSettings;
    logic func_ltsm_flagToAnalog_dataVref_patternMode;
    logic [3:0] func_ltsm_flagToAnalog_dataVref_clockPhaseControl;
    logic [2:0] func_ltsm_flagToAnalog_dataVref_validPattern;
    logic [2:0] func_ltsm_flagToAnalog_dataVref_dataPattern;
    logic func_ltsm_flagToAnalog_dataVref_clearComparisonErrors;
    logic func_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler;
    logic func_ltsm_flagToAnalog_rxClkCal_doCalibration;
    logic func_ltsm_flagFromAnalog_rxClkCal_done;
    logic func_ltsm_flagToAnalog_rxClkCal_sendClockTrack;
    logic func_ltsm_flagToAnalog_d2cSender_sendValTrainPattern;
    logic func_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent;
    logic func_ltsm_flagToAnalog_d2cSender_resetLocalScrambler;
    logic func_ltsm_flagToAnalog_d2cSender_applyTxClockPhase;
    logic [d2cPiCodeWidth-1:0] func_ltsm_flagToAnalog_d2cSender_txClockPhaseCode;
    logic func_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied;
    logic func_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest;
    logic [15:0] func_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold;
    logic func_ltsm_flagToAnalog_d2cReceiver_comparisonMode;
    logic [15:0] func_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_d2cReceiver_idleCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_d2cReceiver_burstCountSettings;
    logic func_ltsm_flagToAnalog_d2cReceiver_patternMode;
    logic [3:0] func_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl;
    logic [2:0] func_ltsm_flagToAnalog_d2cReceiver_validPattern;
    logic [2:0] func_ltsm_flagToAnalog_d2cReceiver_dataPattern;
    logic func_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    logic [15:0] func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
    logic [63:0] func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
    logic func_ltsm_flagToAnalog_d2cSender_sendLfsrPattern;
    logic func_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent;
    logic func_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew;
    logic [64*d2cTxDeskewCodeWidth-1:0] func_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes;
    logic func_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied;
    logic func_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern;
    logic func_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent;
    logic func_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler;
    logic func_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew;
    logic [dataLaneCount*rxDeskewCodeWidth-1:0] func_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes;
    logic func_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied;
    logic func_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest;
    logic [15:0] func_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold;
    logic func_ltsm_flagToAnalog_rxDeskew_comparisonMode;
    logic [15:0] func_ltsm_flagToAnalog_rxDeskew_iterationCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_rxDeskew_idleCountSettings;
    logic [15:0] func_ltsm_flagToAnalog_rxDeskew_burstCountSettings;
    logic func_ltsm_flagToAnalog_rxDeskew_patternMode;
    logic [3:0] func_ltsm_flagToAnalog_rxDeskew_clockPhaseControl;
    logic [2:0] func_ltsm_flagToAnalog_rxDeskew_validPattern;
    logic [2:0] func_ltsm_flagToAnalog_rxDeskew_dataPattern;
    logic func_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors;
    logic [dataLaneCount-1:0] func_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern;
    logic [1:0] func_ltsm_flagToAnalog_linkSpeed_speedCode;
    logic func_ltsm_flagToAnalog_linkSpeed_applySpeed;
    logic func_ltsm_flagToAnalog_linkSpeed_electricalIdle;
    logic func_ltsm_flagToLtsm_linkSpeed_phyInRetrain;
    logic [15:0] func_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
    logic [3:0] func_ltsm_dbg_mbtrainState;
    logic [11:0] func_ltsm_dbg_mbtrainActiveSubstate;
    logic [15:0] func_ltsm_dbg_mbtrainLastErrorCount;
    logic [15:0] func_ltsm_dbg_mbtrainRetryCount;
    logic [3:0] func_debug_ltsm_state;
    logic func_debug_ltsm_inband_pres;
    UcieUPM_d2dadapter_pkg::LinkInitState_t func_debug_fdi_link_init_state;
    UcieUPM_interfaces_pkg::PhyState_t func_debug_rdi_state;
    UcieUPM_interfaces_pkg::PhyStateReq_t func_debug_fdi_to_rdi_state_req;
    logic func_debug_arb_grant_ltsm;
    logic func_debug_arb_grant_fdi;
    logic func_debug_arb_grant_rdi;
    logic func_debug_arb_tx_locked;
    logic func_debug_arb_tx_fire;
    logic func_debug_rx_route_ltsm;
    logic func_debug_rx_route_fdi;
    logic func_debug_rx_route_rdi;
    logic func_debug_rx_drop_unknown;
    logic func_debug_rx_fire;
    logic func_debug_arb_rr_last_granted_rdi;
    logic [1:0] func_debug_arb_rr_last_source;

    assign func_clock = 1'b0;
    assign func_reset_n = 1'b0;
    assign func_fdi_lp_state_req = UcieUPM_interfaces_pkg::PhyStateReq_t'(~(fdi_lp_state_req));
    assign func_fdi_lp_linkerror = ~(fdi_lp_linkerror);
    assign func_fdi_lp_rx_active_sts = ~(fdi_lp_rx_active_sts);
    assign func_fdi_lp_wake_req = ~(fdi_lp_wake_req);
    assign func_fdi_lp_clk_ack = ~(fdi_lp_clk_ack);
    assign func_fdi_lp_stall_ack = ~(fdi_lp_stall_ack);
    assign func_sb_rx_din = ~(sb_rx_din);
    assign func_sb_rx_clk = 1'b0;
    assign func_timeout_disable = ~(1'b0);
    assign func_cycles_1us = ~(cycles_1us);
    assign func_ltsm_start = ~(ltsm_start);
    assign func_ltsm_stable_clk = ~(ltsm_stable_clk);
    assign func_ltsm_pll_locked = ~(ltsm_pll_locked);
    assign func_ltsm_stable_supply = ~(ltsm_stable_supply);
    assign func_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns = ~(ltsm_flagFromAnalog_ReadyToExchangeClkPatterns);
    assign func_ltsm_flagFromAnalog_FinishedClkPatterns = ~(ltsm_flagFromAnalog_FinishedClkPatterns);
    assign func_ltsm_flagFromAnalog_FinishedValTrainPattern = ~(ltsm_flagFromAnalog_FinishedValTrainPattern);
    assign func_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern = ~(ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern);
    assign func_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern = ~(ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern);
    assign func_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L = ~(ltsm_flagFromAnalog_clkPatternReceivedRTRK_L);
    assign func_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L = ~(ltsm_flagFromAnalog_clkPatternReceivedRCKN_L);
    assign func_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L = ~(ltsm_flagFromAnalog_clkPatternReceivedRCKP_L);
    assign func_ltsm_flagFromAnalog_ValTrainPatternReceived = ~(ltsm_flagFromAnalog_ValTrainPatternReceived);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14);
    assign func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = ~(ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14);
    assign func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = ~(ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15);
    assign func_ltsm_flagFromAnalog_valVref_detectedValPattern = ~(phy_flagFromAnalog_valVref_detectedValPattern);
    assign func_ltsm_flagFromAnalog_valVref_finishedPattern = ~(phy_flagFromAnalog_valVref_finishedPattern);
    assign func_ltsm_flagFromAnalog_valVref_rxVrefApplied = ~(phy_flagFromAnalog_valVref_rxVrefApplied);
    assign func_ltsm_flagFromAnalog_dataVref_detectedDataPattern = ~(phy_flagFromAnalog_dataVref_detectedDataPattern);
    assign func_ltsm_flagFromAnalog_dataVref_finishedPattern = ~(phy_flagFromAnalog_dataVref_finishedPattern);
    assign func_ltsm_flagFromAnalog_dataVref_rxVrefApplied = ~(phy_flagFromAnalog_dataVref_rxVrefApplied);
    assign func_ltsm_flagFromAnalog_rxClkCal_done = ~(ltsm_flagFromAnalog_rxClkCal_done);
    assign func_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent = ~(phy_flagFromAnalog_d2cSender_valTrainPatternSent);
    assign func_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied = ~(phy_flagFromAnalog_d2cSender_txClockPhaseApplied);
    assign func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo = ~(phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo);
    assign func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload = ~(phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload);
    assign func_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent = ~(phy_flagFromAnalog_d2cSender_lfsrPatternSent);
    assign func_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied = ~(phy_flagFromAnalog_d2cSender_txLaneDeskewApplied);
    assign func_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent = ~(ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent);
    assign func_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied = ~(ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied);
    assign func_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = ~(ltsm_flagFromAnalog_rxDeskew_detectedDataPattern);
    assign func_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = ~(phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful);

    // Every functional output must be held at 0 in testModeDigital.
    wire logic func_outputs_nonzero = |{
      func_fdi_pl_state_sts,
      func_fdi_pl_rx_active_req,
      func_fdi_pl_inband_pres,
      func_fdi_pl_wake_ack,
      func_fdi_pl_clk_req,
      func_fdi_pl_stall_req,
      func_fdi_active,
      func_sb_tx_dout,
      func_sb_tx_clk,
      func_debug_sb_rx_overflow,
      func_ltsm_flagToAnalog_RepairClkState,
      func_ltsm_flagToAnalog_SendClkPatterns,
      func_ltsm_flagToAnalog_RepairValState,
      func_ltsm_flagToAnalog_SendValTrainPattern,
      func_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
      func_ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
      func_ltsm_flagToAnalog_RepairMbSetReceiver,
      func_ltsm_flagToAnalog_LaneReversalApplied,
      func_ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
      func_ltsm_state,
      func_ltsm_dbg_flagSbinitFirstClkPatternSeen,
      func_ltsm_dbg_rxValidRisingEdge,
      func_ltsm_dbg_sbinitSendCount,
      func_ltsm_dbg_sbTxValid,
      func_ltsm_dbg_sbTxDin,
      func_ltsm_dbg_flagTrainError,
      func_ltsm_dbg_mbinitSubstate,
      func_ltsm_dbg_mbinitReversalMbReceivedSuccessCount,
      func_ltsm_flagToAnalog_valVref_sendPattern,
      func_ltsm_flagToAnalog_valVref_applyRxVref,
      func_ltsm_flagToAnalog_valVref_rxVrefCode,
      func_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest,
      func_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold,
      func_ltsm_flagToAnalog_valVref_comparisonMode,
      func_ltsm_flagToAnalog_valVref_iterationCountSettings,
      func_ltsm_flagToAnalog_valVref_idleCountSettings,
      func_ltsm_flagToAnalog_valVref_burstCountSettings,
      func_ltsm_flagToAnalog_valVref_patternMode,
      func_ltsm_flagToAnalog_valVref_clockPhaseControl,
      func_ltsm_flagToAnalog_valVref_validPattern,
      func_ltsm_flagToAnalog_valVref_dataPattern,
      func_ltsm_flagToAnalog_valVref_clearComparisonErrors,
      func_ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
      func_ltsm_flagToAnalog_dataVref_sendPattern,
      func_ltsm_flagToAnalog_dataVref_applyRxVref,
      func_ltsm_flagToAnalog_dataVref_rxVrefCodes,
      func_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
      func_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold,
      func_ltsm_flagToAnalog_dataVref_comparisonMode,
      func_ltsm_flagToAnalog_dataVref_iterationCountSettings,
      func_ltsm_flagToAnalog_dataVref_idleCountSettings,
      func_ltsm_flagToAnalog_dataVref_burstCountSettings,
      func_ltsm_flagToAnalog_dataVref_patternMode,
      func_ltsm_flagToAnalog_dataVref_clockPhaseControl,
      func_ltsm_flagToAnalog_dataVref_validPattern,
      func_ltsm_flagToAnalog_dataVref_dataPattern,
      func_ltsm_flagToAnalog_dataVref_clearComparisonErrors,
      func_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
      func_ltsm_flagToAnalog_rxClkCal_doCalibration,
      func_ltsm_flagToAnalog_rxClkCal_sendClockTrack,
      func_ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
      func_ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
      func_ltsm_flagToAnalog_d2cSender_applyTxClockPhase,
      func_ltsm_flagToAnalog_d2cSender_txClockPhaseCode,
      func_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
      func_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
      func_ltsm_flagToAnalog_d2cReceiver_comparisonMode,
      func_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings,
      func_ltsm_flagToAnalog_d2cReceiver_idleCountSettings,
      func_ltsm_flagToAnalog_d2cReceiver_burstCountSettings,
      func_ltsm_flagToAnalog_d2cReceiver_patternMode,
      func_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl,
      func_ltsm_flagToAnalog_d2cReceiver_validPattern,
      func_ltsm_flagToAnalog_d2cReceiver_dataPattern,
      func_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
      func_ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
      func_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew,
      func_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes,
      func_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
      func_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
      func_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew,
      func_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes,
      func_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
      func_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold,
      func_ltsm_flagToAnalog_rxDeskew_comparisonMode,
      func_ltsm_flagToAnalog_rxDeskew_iterationCountSettings,
      func_ltsm_flagToAnalog_rxDeskew_idleCountSettings,
      func_ltsm_flagToAnalog_rxDeskew_burstCountSettings,
      func_ltsm_flagToAnalog_rxDeskew_patternMode,
      func_ltsm_flagToAnalog_rxDeskew_clockPhaseControl,
      func_ltsm_flagToAnalog_rxDeskew_validPattern,
      func_ltsm_flagToAnalog_rxDeskew_dataPattern,
      func_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
      func_ltsm_flagToAnalog_linkSpeed_speedCode,
      func_ltsm_flagToAnalog_linkSpeed_applySpeed,
      func_ltsm_flagToAnalog_linkSpeed_electricalIdle,
      func_ltsm_flagToLtsm_linkSpeed_phyInRetrain,
      func_ltsm_dbg_mbtrainState,
      func_ltsm_dbg_mbtrainActiveSubstate,
      func_ltsm_dbg_mbtrainLastErrorCount,
      func_ltsm_dbg_mbtrainRetryCount,
      func_debug_ltsm_state,
      func_debug_ltsm_inband_pres,
      func_debug_fdi_link_init_state,
      func_debug_rdi_state,
      func_debug_fdi_to_rdi_state_req,
      func_debug_arb_grant_ltsm,
      func_debug_arb_grant_fdi,
      func_debug_arb_grant_rdi,
      func_debug_arb_tx_locked,
      func_debug_arb_tx_fire,
      func_debug_rx_route_ltsm,
      func_debug_rx_route_fdi,
      func_debug_rx_route_rdi,
      func_debug_rx_drop_unknown,
      func_debug_rx_fire,
      func_debug_arb_rr_last_granted_rdi,
      func_debug_arb_rr_last_source
    };
    always @(posedge clock)
      if (func_outputs_nonzero !== 1'b0)
        $fatal(1, "UcieDigitalTop functional output not held at 0 in testModeDigital: time=%0t", $time);

    UcieDigitalTop #(
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
    ) dut (
      .testModeDigital                                                                   (1'b1),
      .clock                                                                             (func_clock),
      .reset_n                                                                           (func_reset_n),
      .fdi_lp_state_req                                                                  (func_fdi_lp_state_req),
      .fdi_lp_linkerror                                                                  (func_fdi_lp_linkerror),
      .fdi_lp_rx_active_sts                                                              (func_fdi_lp_rx_active_sts),
      .fdi_lp_wake_req                                                                   (func_fdi_lp_wake_req),
      .fdi_lp_clk_ack                                                                    (func_fdi_lp_clk_ack),
      .fdi_lp_stall_ack                                                                  (func_fdi_lp_stall_ack),
      .fdi_pl_state_sts                                                                  (func_fdi_pl_state_sts),
      .fdi_pl_rx_active_req                                                              (func_fdi_pl_rx_active_req),
      .fdi_pl_inband_pres                                                                (func_fdi_pl_inband_pres),
      .fdi_pl_wake_ack                                                                   (func_fdi_pl_wake_ack),
      .fdi_pl_clk_req                                                                    (func_fdi_pl_clk_req),
      .fdi_pl_stall_req                                                                  (func_fdi_pl_stall_req),
      .fdi_active                                                                        (func_fdi_active),
      .sb_tx_dout                                                                        (func_sb_tx_dout),
      .sb_tx_clk                                                                         (func_sb_tx_clk),
      .sb_rx_din                                                                         (func_sb_rx_din),
      .sb_rx_clk                                                                         (func_sb_rx_clk),
      .debug_sb_rx_overflow                                                              (func_debug_sb_rx_overflow),
      .timeout_disable                                                                   (func_timeout_disable),
      .cycles_1us                                                                        (func_cycles_1us),
      .ltsm_start                                                                        (func_ltsm_start),
      .ltsm_stable_clk                                                                   (func_ltsm_stable_clk),
      .ltsm_pll_locked                                                                   (func_ltsm_pll_locked),
      .ltsm_stable_supply                                                                (func_ltsm_stable_supply),
      .ltsm_flagFromAnalog_ReadyToExchangeClkPatterns                                    (func_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
      .ltsm_flagFromAnalog_FinishedClkPatterns                                           (func_ltsm_flagFromAnalog_FinishedClkPatterns),
      .ltsm_flagFromAnalog_FinishedValTrainPattern                                       (func_ltsm_flagFromAnalog_FinishedValTrainPattern),
      .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                               (func_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
      .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                                 (func_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
      .ltsm_flagFromAnalog_clkPatternReceivedRTRK_L                                      (func_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
      .ltsm_flagFromAnalog_clkPatternReceivedRCKN_L                                      (func_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
      .ltsm_flagFromAnalog_clkPatternReceivedRCKP_L                                      (func_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
      .ltsm_flagFromAnalog_ValTrainPatternReceived                                       (func_ltsm_flagFromAnalog_ValTrainPatternReceived),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9                               (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
      .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15                              (func_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                                (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
      .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                               (func_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
      .ltsm_flagToAnalog_RepairClkState                                                  (func_ltsm_flagToAnalog_RepairClkState),
      .ltsm_flagToAnalog_SendClkPatterns                                                 (func_ltsm_flagToAnalog_SendClkPatterns),
      .ltsm_flagToAnalog_RepairValState                                                  (func_ltsm_flagToAnalog_RepairValState),
      .ltsm_flagToAnalog_SendValTrainPattern                                             (func_ltsm_flagToAnalog_SendValTrainPattern),
      .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern                                     (func_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
      .ltsm_flagToAnalog_RepairMbSendLaneIDPattern                                       (func_ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
      .ltsm_flagToAnalog_RepairMbSetReceiver                                             (func_ltsm_flagToAnalog_RepairMbSetReceiver),
      .ltsm_flagToAnalog_LaneReversalApplied                                             (func_ltsm_flagToAnalog_LaneReversalApplied),
      .ltsm_flagToAnalog_linkInit_resetLfsrScrambler                                     (func_ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
      .ltsm_state                                                                        (func_ltsm_state),
      .ltsm_dbg_flagSbinitFirstClkPatternSeen                                            (func_ltsm_dbg_flagSbinitFirstClkPatternSeen),
      .ltsm_dbg_rxValidRisingEdge                                                        (func_ltsm_dbg_rxValidRisingEdge),
      .ltsm_dbg_sbinitSendCount                                                          (func_ltsm_dbg_sbinitSendCount),
      .ltsm_dbg_sbTxValid                                                                (func_ltsm_dbg_sbTxValid),
      .ltsm_dbg_sbTxDin                                                                  (func_ltsm_dbg_sbTxDin),
      .ltsm_dbg_flagTrainError                                                           (func_ltsm_dbg_flagTrainError),
      .ltsm_dbg_mbinitSubstate                                                           (func_ltsm_dbg_mbinitSubstate),
      .ltsm_dbg_mbinitReversalMbReceivedSuccessCount                                     (func_ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
      .ltsm_flagToAnalog_valVref_sendPattern                                             (func_ltsm_flagToAnalog_valVref_sendPattern),
      .ltsm_flagFromAnalog_valVref_detectedValPattern                                    (func_ltsm_flagFromAnalog_valVref_detectedValPattern),
      .ltsm_flagFromAnalog_valVref_finishedPattern                                       (func_ltsm_flagFromAnalog_valVref_finishedPattern),
      .ltsm_flagToAnalog_valVref_applyRxVref                                             (func_ltsm_flagToAnalog_valVref_applyRxVref),
      .ltsm_flagToAnalog_valVref_rxVrefCode                                              (func_ltsm_flagToAnalog_valVref_rxVrefCode),
      .ltsm_flagFromAnalog_valVref_rxVrefApplied                                         (func_ltsm_flagFromAnalog_valVref_rxVrefApplied),
      .ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest                             (func_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                         (func_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_valVref_comparisonMode                                          (func_ltsm_flagToAnalog_valVref_comparisonMode),
      .ltsm_flagToAnalog_valVref_iterationCountSettings                                  (func_ltsm_flagToAnalog_valVref_iterationCountSettings),
      .ltsm_flagToAnalog_valVref_idleCountSettings                                       (func_ltsm_flagToAnalog_valVref_idleCountSettings),
      .ltsm_flagToAnalog_valVref_burstCountSettings                                      (func_ltsm_flagToAnalog_valVref_burstCountSettings),
      .ltsm_flagToAnalog_valVref_patternMode                                             (func_ltsm_flagToAnalog_valVref_patternMode),
      .ltsm_flagToAnalog_valVref_clockPhaseControl                                       (func_ltsm_flagToAnalog_valVref_clockPhaseControl),
      .ltsm_flagToAnalog_valVref_validPattern                                            (func_ltsm_flagToAnalog_valVref_validPattern),
      .ltsm_flagToAnalog_valVref_dataPattern                                             (func_ltsm_flagToAnalog_valVref_dataPattern),
      .ltsm_flagToAnalog_valVref_clearComparisonErrors                                   (func_ltsm_flagToAnalog_valVref_clearComparisonErrors),
      .ltsm_flagToAnalog_valVref_resetLocalTxScrambler                                   (func_ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
      .ltsm_flagToAnalog_dataVref_sendPattern                                            (func_ltsm_flagToAnalog_dataVref_sendPattern),
      .ltsm_flagFromAnalog_dataVref_detectedDataPattern                                  (func_ltsm_flagFromAnalog_dataVref_detectedDataPattern),
      .ltsm_flagFromAnalog_dataVref_finishedPattern                                      (func_ltsm_flagFromAnalog_dataVref_finishedPattern),
      .ltsm_flagToAnalog_dataVref_applyRxVref                                            (func_ltsm_flagToAnalog_dataVref_applyRxVref),
      .ltsm_flagToAnalog_dataVref_rxVrefCodes                                            (func_ltsm_flagToAnalog_dataVref_rxVrefCodes),
      .ltsm_flagFromAnalog_dataVref_rxVrefApplied                                        (func_ltsm_flagFromAnalog_dataVref_rxVrefApplied),
      .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                            (func_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                        (func_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_dataVref_comparisonMode                                         (func_ltsm_flagToAnalog_dataVref_comparisonMode),
      .ltsm_flagToAnalog_dataVref_iterationCountSettings                                 (func_ltsm_flagToAnalog_dataVref_iterationCountSettings),
      .ltsm_flagToAnalog_dataVref_idleCountSettings                                      (func_ltsm_flagToAnalog_dataVref_idleCountSettings),
      .ltsm_flagToAnalog_dataVref_burstCountSettings                                     (func_ltsm_flagToAnalog_dataVref_burstCountSettings),
      .ltsm_flagToAnalog_dataVref_patternMode                                            (func_ltsm_flagToAnalog_dataVref_patternMode),
      .ltsm_flagToAnalog_dataVref_clockPhaseControl                                      (func_ltsm_flagToAnalog_dataVref_clockPhaseControl),
      .ltsm_flagToAnalog_dataVref_validPattern                                           (func_ltsm_flagToAnalog_dataVref_validPattern),
      .ltsm_flagToAnalog_dataVref_dataPattern                                            (func_ltsm_flagToAnalog_dataVref_dataPattern),
      .ltsm_flagToAnalog_dataVref_clearComparisonErrors                                  (func_ltsm_flagToAnalog_dataVref_clearComparisonErrors),
      .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler                                  (func_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
      .ltsm_flagToAnalog_rxClkCal_doCalibration                                          (func_ltsm_flagToAnalog_rxClkCal_doCalibration),
      .ltsm_flagFromAnalog_rxClkCal_done                                                 (func_ltsm_flagFromAnalog_rxClkCal_done),
      .ltsm_flagToAnalog_rxClkCal_sendClockTrack                                         (func_ltsm_flagToAnalog_rxClkCal_sendClockTrack),
      .ltsm_flagToAnalog_d2cSender_sendValTrainPattern                                   (func_ltsm_flagToAnalog_d2cSender_sendValTrainPattern),
      .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent                                 (func_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent),
      .ltsm_flagToAnalog_d2cSender_resetLocalScrambler                                   (func_ltsm_flagToAnalog_d2cSender_resetLocalScrambler),
      .ltsm_flagToAnalog_d2cSender_applyTxClockPhase                                     (func_ltsm_flagToAnalog_d2cSender_applyTxClockPhase),
      .ltsm_flagToAnalog_d2cSender_txClockPhaseCode                                      (func_ltsm_flagToAnalog_d2cSender_txClockPhaseCode),
      .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied                                 (func_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied),
      .ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                         (func_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
      .ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold                     (func_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_d2cReceiver_comparisonMode                                      (func_ltsm_flagToAnalog_d2cReceiver_comparisonMode),
      .ltsm_flagToAnalog_d2cReceiver_iterationCountSettings                              (func_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_idleCountSettings                                   (func_ltsm_flagToAnalog_d2cReceiver_idleCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_burstCountSettings                                  (func_ltsm_flagToAnalog_d2cReceiver_burstCountSettings),
      .ltsm_flagToAnalog_d2cReceiver_patternMode                                         (func_ltsm_flagToAnalog_d2cReceiver_patternMode),
      .ltsm_flagToAnalog_d2cReceiver_clockPhaseControl                                   (func_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl),
      .ltsm_flagToAnalog_d2cReceiver_validPattern                                        (func_ltsm_flagToAnalog_d2cReceiver_validPattern),
      .ltsm_flagToAnalog_d2cReceiver_dataPattern                                         (func_ltsm_flagToAnalog_d2cReceiver_dataPattern),
      .ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                               (func_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
      .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                           (func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
      .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                           (func_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
      .ltsm_flagToAnalog_d2cSender_sendLfsrPattern                                       (func_ltsm_flagToAnalog_d2cSender_sendLfsrPattern),
      .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent                                     (func_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent),
      .ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew                                     (func_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew),
      .ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes                                     (func_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes),
      .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                                 (func_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied),
      .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern                                        (func_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
      .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                      (func_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
      .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                                  (func_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
      .ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                      (func_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
      .ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                      (func_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
      .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                                  (func_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
      .ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                            (func_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
      .ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                        (func_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
      .ltsm_flagToAnalog_rxDeskew_comparisonMode                                         (func_ltsm_flagToAnalog_rxDeskew_comparisonMode),
      .ltsm_flagToAnalog_rxDeskew_iterationCountSettings                                 (func_ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
      .ltsm_flagToAnalog_rxDeskew_idleCountSettings                                      (func_ltsm_flagToAnalog_rxDeskew_idleCountSettings),
      .ltsm_flagToAnalog_rxDeskew_burstCountSettings                                     (func_ltsm_flagToAnalog_rxDeskew_burstCountSettings),
      .ltsm_flagToAnalog_rxDeskew_patternMode                                            (func_ltsm_flagToAnalog_rxDeskew_patternMode),
      .ltsm_flagToAnalog_rxDeskew_clockPhaseControl                                      (func_ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
      .ltsm_flagToAnalog_rxDeskew_validPattern                                           (func_ltsm_flagToAnalog_rxDeskew_validPattern),
      .ltsm_flagToAnalog_rxDeskew_dataPattern                                            (func_ltsm_flagToAnalog_rxDeskew_dataPattern),
      .ltsm_flagToAnalog_rxDeskew_clearComparisonErrors                                  (func_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
      .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern                                  (func_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
      .ltsm_linkSpeed_requestedSpeed                                                   (2'd0),
      .ltsm_flagToAnalog_linkSpeed_speedCode                                           (func_ltsm_flagToAnalog_linkSpeed_speedCode),
      .ltsm_flagToAnalog_linkSpeed_applySpeed                                          (func_ltsm_flagToAnalog_linkSpeed_applySpeed),
      .ltsm_flagToAnalog_linkSpeed_electricalIdle                                      (func_ltsm_flagToAnalog_linkSpeed_electricalIdle),
      .ltsm_flagFromAnalog_linkSpeed_speedApplied                                      (1'b1),
      .ltsm_flagToLtsm_linkSpeed_phyInRetrain                                            (func_ltsm_flagToLtsm_linkSpeed_phyInRetrain),
      .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                          (func_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
      .ltsm_dbg_mbtrainState                                                             (func_ltsm_dbg_mbtrainState),
      .ltsm_dbg_mbtrainActiveSubstate                                                    (func_ltsm_dbg_mbtrainActiveSubstate),
      .ltsm_dbg_mbtrainLastErrorCount                                                    (func_ltsm_dbg_mbtrainLastErrorCount),
      .ltsm_dbg_mbtrainRetryCount                                                        (func_ltsm_dbg_mbtrainRetryCount),
      .debug_ltsm_state                                                                  (func_debug_ltsm_state),
      .debug_ltsm_inband_pres                                                            (func_debug_ltsm_inband_pres),
      .debug_fdi_link_init_state                                                         (func_debug_fdi_link_init_state),
      .debug_rdi_state                                                                   (func_debug_rdi_state),
      .debug_fdi_to_rdi_state_req                                                        (func_debug_fdi_to_rdi_state_req),
      .debug_arb_grant_ltsm                                                              (func_debug_arb_grant_ltsm),
      .debug_arb_grant_fdi                                                               (func_debug_arb_grant_fdi),
      .debug_arb_grant_rdi                                                               (func_debug_arb_grant_rdi),
      .debug_arb_tx_locked                                                               (func_debug_arb_tx_locked),
      .debug_arb_tx_fire                                                                 (func_debug_arb_tx_fire),
      .debug_rx_route_ltsm                                                               (func_debug_rx_route_ltsm),
      .debug_rx_route_fdi                                                                (func_debug_rx_route_fdi),
      .debug_rx_route_rdi                                                                (func_debug_rx_route_rdi),
      .debug_rx_drop_unknown                                                             (func_debug_rx_drop_unknown),
      .debug_rx_fire                                                                     (func_debug_rx_fire),
      .debug_arb_rr_last_granted_rdi                                                     (func_debug_arb_rr_last_granted_rdi),
      .debug_arb_rr_last_source                                                          (func_debug_arb_rr_last_source),
      .jtag_clock                                                                        (clock),
      .jtag_reset_n                                                                      (reset_n),
      .jtag_fdi_lp_state_req                                                             (fdi_lp_state_req),
      .jtag_fdi_lp_linkerror                                                             (fdi_lp_linkerror),
      .jtag_fdi_lp_rx_active_sts                                                         (fdi_lp_rx_active_sts),
      .jtag_fdi_lp_wake_req                                                              (fdi_lp_wake_req),
      .jtag_fdi_lp_clk_ack                                                               (fdi_lp_clk_ack),
      .jtag_fdi_lp_stall_ack                                                             (fdi_lp_stall_ack),
      .jtag_fdi_pl_state_sts                                                             (fdi_pl_state_sts),
      .jtag_fdi_pl_rx_active_req                                                         (fdi_pl_rx_active_req),
      .jtag_fdi_pl_inband_pres                                                           (fdi_pl_inband_pres),
      .jtag_fdi_pl_wake_ack                                                              (fdi_pl_wake_ack),
      .jtag_fdi_pl_clk_req                                                               (fdi_pl_clk_req),
      .jtag_fdi_pl_stall_req                                                             (fdi_pl_stall_req),
      .jtag_fdi_active                                                                   (fdi_active),
      .jtag_sb_tx_dout                                                                   (sb_tx_dout),
      .jtag_sb_tx_clk                                                                    (sb_tx_clk),
      .jtag_sb_rx_din                                                                    (sb_rx_din),
      .jtag_sb_rx_clk                                                                    (sb_rx_clk),
      .jtag_debug_sb_rx_overflow                                                         (sb_rx_overflow),
      .jtag_timeout_disable                                                              (1'b0),
      .jtag_cycles_1us                                                                   (cycles_1us),
      .jtag_ltsm_start                                                                   (ltsm_start),
      .jtag_ltsm_stable_clk                                                              (ltsm_stable_clk),
      .jtag_ltsm_pll_locked                                                              (ltsm_pll_locked),
      .jtag_ltsm_stable_supply                                                           (ltsm_stable_supply),
      .jtag_ltsm_flagFromAnalog_ReadyToExchangeClkPatterns                               (ltsm_flagFromAnalog_ReadyToExchangeClkPatterns),
      .jtag_ltsm_flagFromAnalog_FinishedClkPatterns                                      (ltsm_flagFromAnalog_FinishedClkPatterns),
      .jtag_ltsm_flagFromAnalog_FinishedValTrainPattern                                  (ltsm_flagFromAnalog_FinishedValTrainPattern),
      .jtag_ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                          (ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern),
      .jtag_ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                            (ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern),
      .jtag_ltsm_flagFromAnalog_clkPatternReceivedRTRK_L                                 (ltsm_flagFromAnalog_clkPatternReceivedRTRK_L),
      .jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKN_L                                 (ltsm_flagFromAnalog_clkPatternReceivedRCKN_L),
      .jtag_ltsm_flagFromAnalog_clkPatternReceivedRCKP_L                                 (ltsm_flagFromAnalog_clkPatternReceivedRCKP_L),
      .jtag_ltsm_flagFromAnalog_ValTrainPatternReceived                                  (ltsm_flagFromAnalog_ValTrainPatternReceived),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9                          (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14),
      .jtag_ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15                         (ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                           (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14),
      .jtag_ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                          (ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15),
      .jtag_ltsm_flagToAnalog_RepairClkState                                             (ltsm_flagToAnalog_RepairClkState),
      .jtag_ltsm_flagToAnalog_SendClkPatterns                                            (ltsm_flagToAnalog_SendClkPatterns),
      .jtag_ltsm_flagToAnalog_RepairValState                                             (ltsm_flagToAnalog_RepairValState),
      .jtag_ltsm_flagToAnalog_SendValTrainPattern                                        (ltsm_flagToAnalog_SendValTrainPattern),
      .jtag_ltsm_flagToAnalog_ReversalMbSendLaneIDPattern                                (ltsm_flagToAnalog_ReversalMbSendLaneIDPattern),
      .jtag_ltsm_flagToAnalog_RepairMbSendLaneIDPattern                                  (ltsm_flagToAnalog_RepairMbSendLaneIDPattern),
      .jtag_ltsm_flagToAnalog_RepairMbSetReceiver                                        (ltsm_flagToAnalog_RepairMbSetReceiver),
      .jtag_ltsm_flagToAnalog_LaneReversalApplied                                        (ltsm_flagToAnalog_LaneReversalApplied),
      .jtag_ltsm_flagToAnalog_linkInit_resetLfsrScrambler                                (ltsm_flagToAnalog_linkInit_resetLfsrScrambler),
      .jtag_ltsm_state                                                                   (ltsm_state),
      .jtag_ltsm_dbg_flagSbinitFirstClkPatternSeen                                       (ltsm_dbg_flagSbinitFirstClkPatternSeen),
      .jtag_ltsm_dbg_rxValidRisingEdge                                                   (ltsm_dbg_rxValidRisingEdge),
      .jtag_ltsm_dbg_sbinitSendCount                                                     (ltsm_dbg_sbinitSendCount),
      .jtag_ltsm_dbg_sbTxValid                                                           (ltsm_dbg_sbTxValid),
      .jtag_ltsm_dbg_sbTxDin                                                             (ltsm_dbg_sbTxDin),
      .jtag_ltsm_dbg_flagTrainError                                                      (ltsm_dbg_flagTrainError),
      .jtag_ltsm_dbg_mbinitSubstate                                                      (ltsm_dbg_mbinitSubstate),
      .jtag_ltsm_dbg_mbinitReversalMbReceivedSuccessCount                                (ltsm_dbg_mbinitReversalMbReceivedSuccessCount),
      .jtag_ltsm_flagToAnalog_valVref_sendPattern                                        (phy_flagToAnalog_valVref_sendPattern),
      .jtag_ltsm_flagFromAnalog_valVref_detectedValPattern                               (phy_flagFromAnalog_valVref_detectedValPattern),
      .jtag_ltsm_flagFromAnalog_valVref_finishedPattern                                  (phy_flagFromAnalog_valVref_finishedPattern),
      .jtag_ltsm_flagToAnalog_valVref_applyRxVref                                        (phy_flagToAnalog_valVref_applyRxVref),
      .jtag_ltsm_flagToAnalog_valVref_rxVrefCode                                         (phy_flagToAnalog_valVref_rxVrefCode),
      .jtag_ltsm_flagFromAnalog_valVref_rxVrefApplied                                    (phy_flagFromAnalog_valVref_rxVrefApplied),
      .jtag_ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest                        (phy_flagToAnalog_valVref_configureRxInitD2CPointTest),
      .jtag_ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                    (phy_flagToAnalog_valVref_maximumComparisonErrorThreshold),
      .jtag_ltsm_flagToAnalog_valVref_comparisonMode                                     (phy_flagToAnalog_valVref_comparisonMode),
      .jtag_ltsm_flagToAnalog_valVref_iterationCountSettings                             (phy_flagToAnalog_valVref_iterationCountSettings),
      .jtag_ltsm_flagToAnalog_valVref_idleCountSettings                                  (phy_flagToAnalog_valVref_idleCountSettings),
      .jtag_ltsm_flagToAnalog_valVref_burstCountSettings                                 (phy_flagToAnalog_valVref_burstCountSettings),
      .jtag_ltsm_flagToAnalog_valVref_patternMode                                        (phy_flagToAnalog_valVref_patternMode),
      .jtag_ltsm_flagToAnalog_valVref_clockPhaseControl                                  (phy_flagToAnalog_valVref_clockPhaseControl),
      .jtag_ltsm_flagToAnalog_valVref_validPattern                                       (phy_flagToAnalog_valVref_validPattern),
      .jtag_ltsm_flagToAnalog_valVref_dataPattern                                        (phy_flagToAnalog_valVref_dataPattern),
      .jtag_ltsm_flagToAnalog_valVref_clearComparisonErrors                              (phy_flagToAnalog_valVref_clearComparisonErrors),
      .jtag_ltsm_flagToAnalog_valVref_resetLocalTxScrambler                              (phy_flagToAnalog_valVref_resetLocalTxScrambler),
      .jtag_ltsm_flagToAnalog_dataVref_sendPattern                                       (phy_flagToAnalog_dataVref_sendPattern),
      .jtag_ltsm_flagFromAnalog_dataVref_detectedDataPattern                             (phy_flagFromAnalog_dataVref_detectedDataPattern),
      .jtag_ltsm_flagFromAnalog_dataVref_finishedPattern                                 (phy_flagFromAnalog_dataVref_finishedPattern),
      .jtag_ltsm_flagToAnalog_dataVref_applyRxVref                                       (phy_flagToAnalog_dataVref_applyRxVref),
      .jtag_ltsm_flagToAnalog_dataVref_rxVrefCodes                                       (phy_flagToAnalog_dataVref_rxVrefCodes),
      .jtag_ltsm_flagFromAnalog_dataVref_rxVrefApplied                                   (phy_flagFromAnalog_dataVref_rxVrefApplied),
      .jtag_ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                       (phy_flagToAnalog_dataVref_configureRxInitD2CPointTest),
      .jtag_ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                   (phy_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
      .jtag_ltsm_flagToAnalog_dataVref_comparisonMode                                    (phy_flagToAnalog_dataVref_comparisonMode),
      .jtag_ltsm_flagToAnalog_dataVref_iterationCountSettings                            (phy_flagToAnalog_dataVref_iterationCountSettings),
      .jtag_ltsm_flagToAnalog_dataVref_idleCountSettings                                 (phy_flagToAnalog_dataVref_idleCountSettings),
      .jtag_ltsm_flagToAnalog_dataVref_burstCountSettings                                (phy_flagToAnalog_dataVref_burstCountSettings),
      .jtag_ltsm_flagToAnalog_dataVref_patternMode                                       (phy_flagToAnalog_dataVref_patternMode),
      .jtag_ltsm_flagToAnalog_dataVref_clockPhaseControl                                 (phy_flagToAnalog_dataVref_clockPhaseControl),
      .jtag_ltsm_flagToAnalog_dataVref_validPattern                                      (phy_flagToAnalog_dataVref_validPattern),
      .jtag_ltsm_flagToAnalog_dataVref_dataPattern                                       (phy_flagToAnalog_dataVref_dataPattern),
      .jtag_ltsm_flagToAnalog_dataVref_clearComparisonErrors                             (phy_flagToAnalog_dataVref_clearComparisonErrors),
      .jtag_ltsm_flagToAnalog_dataVref_resetLocalTxScrambler                             (phy_flagToAnalog_dataVref_resetLocalTxScrambler),
      .jtag_ltsm_flagToAnalog_rxClkCal_doCalibration                                     (ltsm_flagToAnalog_rxClkCal_doCalibration),
      .jtag_ltsm_flagFromAnalog_rxClkCal_done                                            (ltsm_flagFromAnalog_rxClkCal_done),
      .jtag_ltsm_flagToAnalog_rxClkCal_sendClockTrack                                    (ltsm_flagToAnalog_rxClkCal_sendClockTrack),
      .jtag_ltsm_flagToAnalog_d2cSender_sendValTrainPattern                              (phy_flagToAnalog_d2cSender_sendValTrainPattern),
      .jtag_ltsm_flagFromAnalog_d2cSender_valTrainPatternSent                            (phy_flagFromAnalog_d2cSender_valTrainPatternSent),
      .jtag_ltsm_flagToAnalog_d2cSender_resetLocalScrambler                              (phy_flagToAnalog_d2cSender_resetLocalScrambler),
      .jtag_ltsm_flagToAnalog_d2cSender_applyTxClockPhase                                (phy_flagToAnalog_d2cSender_applyTxClockPhase),
      .jtag_ltsm_flagToAnalog_d2cSender_txClockPhaseCode                                 (phy_flagToAnalog_d2cSender_txClockPhaseCode),
      .jtag_ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied                            (phy_flagFromAnalog_d2cSender_txClockPhaseApplied),
      .jtag_ltsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                    (phy_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest),
      .jtag_ltsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold                (phy_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold),
      .jtag_ltsm_flagToAnalog_d2cReceiver_comparisonMode                                 (phy_flagToAnalog_d2cReceiver_comparisonMode),
      .jtag_ltsm_flagToAnalog_d2cReceiver_iterationCountSettings                         (phy_flagToAnalog_d2cReceiver_iterationCountSettings),
      .jtag_ltsm_flagToAnalog_d2cReceiver_idleCountSettings                              (phy_flagToAnalog_d2cReceiver_idleCountSettings),
      .jtag_ltsm_flagToAnalog_d2cReceiver_burstCountSettings                             (phy_flagToAnalog_d2cReceiver_burstCountSettings),
      .jtag_ltsm_flagToAnalog_d2cReceiver_patternMode                                    (phy_flagToAnalog_d2cReceiver_patternMode),
      .jtag_ltsm_flagToAnalog_d2cReceiver_clockPhaseControl                              (phy_flagToAnalog_d2cReceiver_clockPhaseControl),
      .jtag_ltsm_flagToAnalog_d2cReceiver_validPattern                                   (phy_flagToAnalog_d2cReceiver_validPattern),
      .jtag_ltsm_flagToAnalog_d2cReceiver_dataPattern                                    (phy_flagToAnalog_d2cReceiver_dataPattern),
      .jtag_ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                          (phy_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
      .jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                      (phy_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo),
      .jtag_ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                      (phy_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload),
      .jtag_ltsm_flagToAnalog_d2cSender_sendLfsrPattern                                  (phy_flagToAnalog_d2cSender_sendLfsrPattern),
      .jtag_ltsm_flagFromAnalog_d2cSender_lfsrPatternSent                                (phy_flagFromAnalog_d2cSender_lfsrPatternSent),
      .jtag_ltsm_flagToAnalog_d2cSender_applyTxLaneDeskew                                (phy_flagToAnalog_d2cSender_applyTxLaneDeskew),
      .jtag_ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes                                (phy_flagToAnalog_d2cSender_txLaneDeskewCodes),
      .jtag_ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                            (phy_flagFromAnalog_d2cSender_txLaneDeskewApplied),
      .jtag_ltsm_flagToAnalog_rxDeskew_sendLfsrPattern                                   (ltsm_flagToAnalog_rxDeskew_sendLfsrPattern),
      .jtag_ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                 (ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent),
      .jtag_ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                             (ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler),
      .jtag_ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                 (ltsm_flagToAnalog_rxDeskew_applyRxLaneDeskew),
      .jtag_ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                 (ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes),
      .jtag_ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                             (ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied),
      .jtag_ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                       (ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
      .jtag_ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                   (ltsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold),
      .jtag_ltsm_flagToAnalog_rxDeskew_comparisonMode                                    (ltsm_flagToAnalog_rxDeskew_comparisonMode),
      .jtag_ltsm_flagToAnalog_rxDeskew_iterationCountSettings                            (ltsm_flagToAnalog_rxDeskew_iterationCountSettings),
      .jtag_ltsm_flagToAnalog_rxDeskew_idleCountSettings                                 (ltsm_flagToAnalog_rxDeskew_idleCountSettings),
      .jtag_ltsm_flagToAnalog_rxDeskew_burstCountSettings                                (ltsm_flagToAnalog_rxDeskew_burstCountSettings),
      .jtag_ltsm_flagToAnalog_rxDeskew_patternMode                                       (ltsm_flagToAnalog_rxDeskew_patternMode),
      .jtag_ltsm_flagToAnalog_rxDeskew_clockPhaseControl                                 (ltsm_flagToAnalog_rxDeskew_clockPhaseControl),
      .jtag_ltsm_flagToAnalog_rxDeskew_validPattern                                      (ltsm_flagToAnalog_rxDeskew_validPattern),
      .jtag_ltsm_flagToAnalog_rxDeskew_dataPattern                                       (ltsm_flagToAnalog_rxDeskew_dataPattern),
      .jtag_ltsm_flagToAnalog_rxDeskew_clearComparisonErrors                             (ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
      .jtag_ltsm_flagFromAnalog_rxDeskew_detectedDataPattern                             (ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
      .jtag_ltsm_linkSpeed_requestedSpeed                                              (2'd3),
      .jtag_ltsm_flagToAnalog_linkSpeed_speedCode                                      (ltsm_flagToAnalog_linkSpeed_speedCode),
      .jtag_ltsm_flagToAnalog_linkSpeed_applySpeed                                     (ltsm_flagToAnalog_linkSpeed_applySpeed),
      .jtag_ltsm_flagToAnalog_linkSpeed_electricalIdle                                 (ltsm_flagToAnalog_linkSpeed_electricalIdle),
      .jtag_ltsm_flagFromAnalog_linkSpeed_speedApplied                                 (ltsm_flagFromAnalog_linkSpeed_speedApplied),
      .jtag_ltsm_flagToLtsm_linkSpeed_phyInRetrain                                       (ltsm_flagToLtsm_linkSpeed_phyInRetrain),
      .jtag_ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                     (phy_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
      .jtag_ltsm_dbg_mbtrainState                                                        (ltsm_dbg_mbtrainState),
      .jtag_ltsm_dbg_mbtrainActiveSubstate                                               (ltsm_dbg_mbtrainActiveSubstate),
      .jtag_ltsm_dbg_mbtrainLastErrorCount                                               (ltsm_dbg_mbtrainLastErrorCount),
      .jtag_ltsm_dbg_mbtrainRetryCount                                                   (ltsm_dbg_mbtrainRetryCount),
      .jtag_debug_ltsm_state                                                             (debug_ltsm_state),
      .jtag_debug_ltsm_inband_pres                                                       (debug_ltsm_inband_pres),
      .jtag_debug_fdi_link_init_state                                                    (debug_fdi_link_init_state),
      .jtag_debug_rdi_state                                                              (debug_rdi_state),
      .jtag_debug_fdi_to_rdi_state_req                                                   (debug_fdi_to_rdi_state_req),
      .jtag_debug_arb_grant_ltsm                                                         (debug_arb_grant_ltsm),
      .jtag_debug_arb_grant_fdi                                                          (debug_arb_grant_fdi),
      .jtag_debug_arb_grant_rdi                                                          (debug_arb_grant_rdi),
      .jtag_debug_arb_tx_locked                                                          (debug_arb_tx_locked),
      .jtag_debug_arb_tx_fire                                                            (debug_arb_tx_fire),
      .jtag_debug_rx_route_ltsm                                                          (debug_rx_route_ltsm),
      .jtag_debug_rx_route_fdi                                                           (debug_rx_route_fdi),
      .jtag_debug_rx_route_rdi                                                           (debug_rx_route_rdi),
      .jtag_debug_rx_drop_unknown                                                        (debug_rx_drop_unknown),
      .jtag_debug_rx_fire                                                                (debug_rx_fire),
      .jtag_debug_arb_rr_last_granted_rdi                                                (),
      .jtag_debug_arb_rr_last_source                                                     (),
      .testModeFdi                                                                       (1'b0),
      .jtagFdi_clock                                                                     (1'b0),
      .jtagFdi_reset_n                                                                   (1'b0),
      .jtagFdi_cycles_1us                                                                (32'd0),
      .jtagFdi_timeout_disable                                                           (1'b0),
      .jtagFdi_fdi_lp_state_req                                                          (UcieUPM_interfaces_pkg::PhyStateReq_nop),
      .jtagFdi_fdi_lp_linkerror                                                          (1'b0),
      .jtagFdi_fdi_lp_rx_active_sts                                                      (1'b0),
      .jtagFdi_fdi_lp_wake_req                                                           (1'b0),
      .jtagFdi_fdi_lp_clk_ack                                                            (1'b0),
      .jtagFdi_fdi_lp_stall_ack                                                          (1'b0),
      .jtagFdi_fdi_pl_state_sts                                                          (),
      .jtagFdi_fdi_pl_rx_active_req                                                      (),
      .jtagFdi_fdi_pl_inband_pres                                                        (),
      .jtagFdi_fdi_pl_wake_ack                                                           (),
      .jtagFdi_fdi_pl_clk_req                                                            (),
      .jtagFdi_fdi_pl_stall_req                                                          (),
      .jtagFdi_fdi_active                                                                (),
      .jtagFdi_debug_link_init_state                                                     (),
      .jtagFdi_rdi_lp_linkerror                                                          (),
      .jtagFdi_rdi_lp_state_req                                                          (),
      .jtagFdi_rdi_pl_state_sts                                                          (UcieUPM_interfaces_pkg::PhyState_t'('0)),
      .jtagFdi_rdi_pl_inband_pres                                                        (1'b0),
      .jtagFdi_fdiNeedsRdiAwake                                                          (),
      .jtagFdi_rdiAwake                                                                  (1'b0),
      .jtagFdi_rdiNeedsFdiAwake                                                          (1'b0),
      .jtagFdi_fdiAwake                                                                  (),
      .jtagFdi_rdi_pl_stall_req                                                          (1'b0),
      .jtagFdi_rdi_lp_stall_ack                                                          (),
      .jtagFdi_sb_snd_valid                                                              (),
      .jtagFdi_sb_snd_msg                                                                (),
      .jtagFdi_sb_snd_ready                                                              (1'b0),
      .jtagFdi_sb_rcv_valid                                                              (1'b0),
      .jtagFdi_sb_rcv_msg                                                                (128'd0),
      .jtagFdi_sb_rcv_ready                                                              (),
      .testModeRdi                                                                     (1'b0),
      .jtagRdi_clock                                                                   (1'b0),
      .jtagRdi_reset_n                                                                 ('0),
      .jtagRdi_ltsm_lp_wake_req                                                        ('0),
      .jtagRdi_ltsm_pl_wake_ack                                                        (),
      .jtagRdi_ltsm_pl_clk_req                                                         (),
      .jtagRdi_ltsm_lp_clk_ack                                                         ('0),
      .jtagRdi_lp_state_req                                                            (UcieUPM_interfaces_pkg::PhyStateReq_t'('0)),
      .jtagRdi_pl_state_sts                                                            (),
      .jtagRdi_pl_stallreq                                                             (),
      .jtagRdi_lp_stallack                                                             ('0),
      .jtagRdi_rdi_pl_inband_pres                                                      (),
      .jtagRdi_ltsm_pl_inband_pres                                                     ('0),
      .jtagRdi_fdiNeedsRdiAwake                                                        ('0),
      .jtagRdi_rdiAwake                                                                (),
      .jtagRdi_rdiNeedsFdiAwake                                                        (),
      .jtagRdi_fdiAwake                                                                ('0),
      .jtagRdi_sb_snd_valid                                                            (),
      .jtagRdi_sb_snd_msg                                                              (),
      .jtagRdi_sb_snd_ready                                                            ('0),
      .jtagRdi_sb_rcv_valid                                                            ('0),
      .jtagRdi_sb_rcv_msg                                                              ('0),
      .jtagRdi_sb_rcv_ready                                                            (),
      .jtagRdi_lp_linkerror                                                            ('0),
      .jtagRdi_pl_phyinrecenter                                                        (),
      .jtagRdi_timeout_disable                                                         ('0),
      .jtagRdi_cycles_1us                                                              ('0),
      .testModeLtsm                                                                    (1'b0),
      .jtagLtsm_clock                                                                  (1'b0),
      .jtagLtsm_reset_n                                                                ('0),
      .jtagLtsm_sb_tx_din                                                              (),
      .jtagLtsm_sb_tx_valid                                                            (),
      .jtagLtsm_sb_tx_ready                                                            ('0),
      .jtagLtsm_sb_rx_dout                                                             ('0),
      .jtagLtsm_sb_rx_valid                                                            ('0),
      .jtagLtsm_start                                                                  ('0),
      .jtagLtsm_stable_clk                                                             ('0),
      .jtagLtsm_pll_locked                                                             ('0),
      .jtagLtsm_stable_supply                                                          ('0),
      .jtagLtsm_flagFromAnalog_ReadyToExchangeClkPatterns                              ('0),
      .jtagLtsm_flagFromAnalog_FinishedClkPatterns                                     ('0),
      .jtagLtsm_flagFromAnalog_FinishedValTrainPattern                                 ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbFinishedLaneIDPattern                           ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRTRK_L                                ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKN_L                                ('0),
      .jtagLtsm_flagFromAnalog_clkPatternReceivedRCKP_L                                ('0),
      .jtagLtsm_flagFromAnalog_ValTrainPatternReceived                                 ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived0                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived1                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived2                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived3                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived4                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived5                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived6                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived7                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived8                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived9                         ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived10                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived11                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived12                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived13                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived14                        ('0),
      .jtagLtsm_flagFromAnalog_ReversalMbTrainPatternReceived15                        ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9                          ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14                         ('0),
      .jtagLtsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15                         ('0),
      .jtagLtsm_flagToAnalog_RepairClkState                                            (),
      .jtagLtsm_flagToAnalog_SendClkPatterns                                           (),
      .jtagLtsm_flagToAnalog_RepairValState                                            (),
      .jtagLtsm_flagToAnalog_SendValTrainPattern                                       (),
      .jtagLtsm_flagToAnalog_ReversalMbSendLaneIDPattern                               (),
      .jtagLtsm_flagToAnalog_RepairMbSendLaneIDPattern                                 (),
      .jtagLtsm_flagToAnalog_RepairMbSetReceiver                                       (),
      .jtagLtsm_flagToAnalog_LaneReversalApplied                                       (),
      .jtagLtsm_flagToAnalog_linkInit_resetLfsrScrambler                               (),
      .jtagLtsm_state                                                                  (),
      .jtagLtsm_dbg_flagSbinitFirstClkPatternSeen                                      (),
      .jtagLtsm_dbg_rxValidRisingEdge                                                  (),
      .jtagLtsm_dbg_sbinitSendCount                                                    (),
      .jtagLtsm_dbg_sbTxValid                                                          (),
      .jtagLtsm_dbg_sbTxDin                                                            (),
      .jtagLtsm_dbg_flagTrainError                                                     (),
      .jtagLtsm_dbg_mbinitSubstate                                                     (),
      .jtagLtsm_dbg_mbinitParamSenderState                                             (),
      .jtagLtsm_dbg_mbinitParamReceiverState                                           (),
      .jtagLtsm_dbg_mbinitCalSenderState                                               (),
      .jtagLtsm_dbg_mbinitCalReceiverState                                             (),
      .jtagLtsm_dbg_mbinitRepairClkSenderState                                         (),
      .jtagLtsm_dbg_mbinitRepairClkReceiverState                                       (),
      .jtagLtsm_dbg_mbinitRepairValSenderState                                         (),
      .jtagLtsm_dbg_mbinitRepairValReceiverState                                       (),
      .jtagLtsm_dbg_mbinitReversalMbSenderState                                        (),
      .jtagLtsm_dbg_mbinitReversalMbReceiverState                                      (),
      .jtagLtsm_dbg_mbinitRepairMbSenderState                                          (),
      .jtagLtsm_dbg_mbinitRepairMbReceiverState                                        (),
      .jtagLtsm_dbg_mbinitReversalMbReceivedSuccessCount                               (),
      .jtagLtsm_flagToAnalog_valVref_sendPattern                                       (),
      .jtagLtsm_flagFromAnalog_valVref_detectedValPattern                              ('0),
      .jtagLtsm_flagFromAnalog_valVref_finishedPattern                                 ('0),
      .jtagLtsm_flagToAnalog_valVref_applyRxVref                                       (),
      .jtagLtsm_flagToAnalog_valVref_rxVrefCode                                        (),
      .jtagLtsm_flagFromAnalog_valVref_rxVrefApplied                                   ('0),
      .jtagLtsm_flagToAnalog_valVref_configureRxInitD2CPointTest                       (),
      .jtagLtsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                   (),
      .jtagLtsm_flagToAnalog_valVref_comparisonMode                                    (),
      .jtagLtsm_flagToAnalog_valVref_iterationCountSettings                            (),
      .jtagLtsm_flagToAnalog_valVref_idleCountSettings                                 (),
      .jtagLtsm_flagToAnalog_valVref_burstCountSettings                                (),
      .jtagLtsm_flagToAnalog_valVref_patternMode                                       (),
      .jtagLtsm_flagToAnalog_valVref_clockPhaseControl                                 (),
      .jtagLtsm_flagToAnalog_valVref_validPattern                                      (),
      .jtagLtsm_flagToAnalog_valVref_dataPattern                                       (),
      .jtagLtsm_flagToAnalog_valVref_clearComparisonErrors                             (),
      .jtagLtsm_flagToAnalog_valVref_resetLocalTxScrambler                             (),
      .jtagLtsm_flagToAnalog_dataVref_sendPattern                                      (),
      .jtagLtsm_flagFromAnalog_dataVref_detectedDataPattern                            ('0),
      .jtagLtsm_flagFromAnalog_dataVref_finishedPattern                                ('0),
      .jtagLtsm_flagToAnalog_dataVref_applyRxVref                                      (),
      .jtagLtsm_flagToAnalog_dataVref_rxVrefCodes                                      (),
      .jtagLtsm_flagFromAnalog_dataVref_rxVrefApplied                                  ('0),
      .jtagLtsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                      (),
      .jtagLtsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                  (),
      .jtagLtsm_flagToAnalog_dataVref_comparisonMode                                   (),
      .jtagLtsm_flagToAnalog_dataVref_iterationCountSettings                           (),
      .jtagLtsm_flagToAnalog_dataVref_idleCountSettings                                (),
      .jtagLtsm_flagToAnalog_dataVref_burstCountSettings                               (),
      .jtagLtsm_flagToAnalog_dataVref_patternMode                                      (),
      .jtagLtsm_flagToAnalog_dataVref_clockPhaseControl                                (),
      .jtagLtsm_flagToAnalog_dataVref_validPattern                                     (),
      .jtagLtsm_flagToAnalog_dataVref_dataPattern                                      (),
      .jtagLtsm_flagToAnalog_dataVref_clearComparisonErrors                            (),
      .jtagLtsm_flagToAnalog_dataVref_resetLocalTxScrambler                            (),
      .jtagLtsm_flagToAnalog_rxClkCal_doCalibration                                    (),
      .jtagLtsm_flagFromAnalog_rxClkCal_done                                           ('0),
      .jtagLtsm_flagToAnalog_rxClkCal_sendClockTrack                                   (),
      .jtagLtsm_flagToAnalog_d2cSender_sendValTrainPattern                             (),
      .jtagLtsm_flagFromAnalog_d2cSender_valTrainPatternSent                           ('0),
      .jtagLtsm_flagToAnalog_d2cSender_resetLocalScrambler                             (),
      .jtagLtsm_flagToAnalog_d2cSender_applyTxClockPhase                               (),
      .jtagLtsm_flagToAnalog_d2cSender_txClockPhaseCode                                (),
      .jtagLtsm_flagFromAnalog_d2cSender_txClockPhaseApplied                           ('0),
      .jtagLtsm_flagToAnalog_d2cReceiver_configureTxInitD2CPointTest                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold               (),
      .jtagLtsm_flagToAnalog_d2cReceiver_comparisonMode                                (),
      .jtagLtsm_flagToAnalog_d2cReceiver_iterationCountSettings                        (),
      .jtagLtsm_flagToAnalog_d2cReceiver_idleCountSettings                             (),
      .jtagLtsm_flagToAnalog_d2cReceiver_burstCountSettings                            (),
      .jtagLtsm_flagToAnalog_d2cReceiver_patternMode                                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_clockPhaseControl                             (),
      .jtagLtsm_flagToAnalog_d2cReceiver_validPattern                                  (),
      .jtagLtsm_flagToAnalog_d2cReceiver_dataPattern                                   (),
      .jtagLtsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler                         (),
      .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo                     ('0),
      .jtagLtsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload                     ('0),
      .jtagLtsm_flagToAnalog_d2cSender_sendLfsrPattern                                 (),
      .jtagLtsm_flagFromAnalog_d2cSender_lfsrPatternSent                               ('0),
      .jtagLtsm_flagToAnalog_d2cSender_applyTxLaneDeskew                               (),
      .jtagLtsm_flagToAnalog_d2cSender_txLaneDeskewCodes                               (),
      .jtagLtsm_flagFromAnalog_d2cSender_txLaneDeskewApplied                           ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_sendLfsrPattern                                  (),
      .jtagLtsm_flagFromAnalog_rxDeskew_lfsrPatternSent                                ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_resetLocalTxScrambler                            (),
      .jtagLtsm_flagToAnalog_rxDeskew_applyRxLaneDeskew                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes                                (),
      .jtagLtsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied                            ('0),
      .jtagLtsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_maximumComparisonErrorThreshold                  (),
      .jtagLtsm_flagToAnalog_rxDeskew_comparisonMode                                   (),
      .jtagLtsm_flagToAnalog_rxDeskew_iterationCountSettings                           (),
      .jtagLtsm_flagToAnalog_rxDeskew_idleCountSettings                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_burstCountSettings                               (),
      .jtagLtsm_flagToAnalog_rxDeskew_patternMode                                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_clockPhaseControl                                (),
      .jtagLtsm_flagToAnalog_rxDeskew_validPattern                                     (),
      .jtagLtsm_flagToAnalog_rxDeskew_dataPattern                                      (),
      .jtagLtsm_flagToAnalog_rxDeskew_clearComparisonErrors                            (),
      .jtagLtsm_flagFromAnalog_rxDeskew_detectedDataPattern                            ('0),
      .jtagLtsm_linkSpeed_requestedSpeed                                               (2'd0),
      .jtagLtsm_flagToAnalog_linkSpeed_speedCode                                       (),
      .jtagLtsm_flagToAnalog_linkSpeed_applySpeed                                      (),
      .jtagLtsm_flagToAnalog_linkSpeed_electricalIdle                                  (),
      .jtagLtsm_flagFromAnalog_linkSpeed_speedApplied                                  (1'b0),
      .jtagLtsm_flagToLtsm_linkSpeed_phyInRetrain                                      (),
      .jtagLtsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful                    ('0),
      .jtagLtsm_dbg_mbtrainState                                                       (),
      .jtagLtsm_dbg_mbtrainActiveSubstate                                              (),
      .jtagLtsm_dbg_mbtrainValVrefLocalState                                           (),
      .jtagLtsm_dbg_mbtrainValVrefRemoteState                                          (),
      .jtagLtsm_dbg_mbtrainValVrefSweepState                                           (),
      .jtagLtsm_dbg_mbtrainValVrefPointInitiatorState                                  (),
      .jtagLtsm_dbg_mbtrainValVrefPointResponderState                                  (),
      .jtagLtsm_dbg_mbtrainDataVrefLocalState                                          (),
      .jtagLtsm_dbg_mbtrainDataVrefRemoteState                                         (),
      .jtagLtsm_dbg_mbtrainDataVrefSweepState                                          (),
      .jtagLtsm_dbg_mbtrainDataVrefPointInitiatorState                                 (),
      .jtagLtsm_dbg_mbtrainDataVrefPointResponderState                                 (),
      .jtagLtsm_dbg_mbtrainSpeedIdleSenderState                                        (),
      .jtagLtsm_dbg_mbtrainSpeedIdleReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainTxSelfCalSenderState                                        (),
      .jtagLtsm_dbg_mbtrainTxSelfCalReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainRxClkCalSenderState                                         (),
      .jtagLtsm_dbg_mbtrainRxClkCalReceiverState                                       (),
      .jtagLtsm_dbg_mbtrainValTrainCenterSenderState                                   (),
      .jtagLtsm_dbg_mbtrainValTrainCenterReceiverState                                 (),
      .jtagLtsm_dbg_mbtrainValTrainCenterD2cSenderState                                (),
      .jtagLtsm_dbg_mbtrainValTrainCenterD2cReceiverState                              (),
      .jtagLtsm_dbg_mbtrainValTrainCenterSweepState                                    (),
      .jtagLtsm_dbg_mbtrainValTrainVrefLocalState                                      (),
      .jtagLtsm_dbg_mbtrainValTrainVrefRemoteState                                     (),
      .jtagLtsm_dbg_mbtrainValTrainVrefSweepState                                      (),
      .jtagLtsm_dbg_mbtrainValTrainVrefPointInitiatorState                             (),
      .jtagLtsm_dbg_mbtrainValTrainVrefPointResponderState                             (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1SenderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1ReceiverState                               (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cSenderState                              (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1D2cReceiverState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter1SweepState                                  (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefLocalState                                     (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefRemoteState                                    (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefSweepState                                     (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefPointInitiatorState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainVrefPointResponderState                            (),
      .jtagLtsm_dbg_mbtrainRxDeskewLocalState                                          (),
      .jtagLtsm_dbg_mbtrainRxDeskewRemoteState                                         (),
      .jtagLtsm_dbg_mbtrainRxDeskewSweepState                                          (),
      .jtagLtsm_dbg_mbtrainRxDeskewPointInitiatorState                                 (),
      .jtagLtsm_dbg_mbtrainRxDeskewPointResponderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2SenderState                                 (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2ReceiverState                               (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cSenderState                              (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2D2cReceiverState                            (),
      .jtagLtsm_dbg_mbtrainDataTrainCenter2SweepState                                  (),
      .jtagLtsm_dbg_mbtrainLinkSpeedSenderState                                        (),
      .jtagLtsm_dbg_mbtrainLinkSpeedReceiverState                                      (),
      .jtagLtsm_dbg_mbtrainLinkSpeedD2cSenderState                                     (),
      .jtagLtsm_dbg_mbtrainLinkSpeedD2cReceiverState                                   (),
      .jtagLtsm_dbg_mbtrainLastErrorCount                                              (),
      .jtagLtsm_dbg_mbtrainRetryCount                                                  ()
    );

    assign sb_tx_idle      = (dut.u_core.u_sideband.u_sideband_phy.txCount == 0) &&
                             dut.u_core.u_sideband.u_sideband_phy.txInternalReady;
    assign sb_mon_tx_valid  = dut.u_core.u_sideband.sb_msg_tx_valid;
    assign sb_mon_tx_msg    = dut.u_core.u_sideband.sb_msg_tx_msg;
    assign sb_mon_tx_ready  = dut.u_core.u_sideband.sb_msg_tx_ready;
    assign sb_mon_rx_valid  = dut.u_core.u_sideband.sb_msg_rx_valid;
    assign sb_mon_rx_msg    = dut.u_core.u_sideband.sb_msg_rx_msg;
    assign sb_mon_rx_ready  = dut.u_core.u_sideband.sb_msg_rx_ready;

    // See sb_tx_enable above: pauses only the FIFO admission handshake.
    always @(sb_tx_enable) begin
      if (!sb_tx_enable)
        force dut.u_core.u_sideband.u_sideband_phy.tx_ready = 1'b0;
      else
        release dut.u_core.u_sideband.u_sideband_phy.tx_ready;
    end
  end
endmodule

module D2DAdapterLinkMgmtLtsmDualDieHarness #(
  // Bit N injects a failing RX comparison on die N only at speed code 3.
  parameter logic [1:0] LINK_SPEED_FAIL_TOP_RATE_MASK = 2'b00,
  // Extend the selected receiver fault through the minimum rate.
  parameter bit LINK_SPEED_FAIL_ALL_RATES = 1'b0,
  // 1: each die is UcieDigitalTop in testModeDigital, driven only via jtag_*.
  parameter bit TEST_MODE_DIGITAL = 1'b0
) (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic start,
  input  wire logic stable_clk,
  input  wire logic pll_locked,
  input  wire logic stable_supply,
  input  wire logic [31:0] cycles_1us,
  input  wire logic protocol_request_active,
  input  wire logic link_0_to_1_enable,
  input  wire logic link_1_to_0_enable,

  output wire logic [3:0] die0_ltsm_state,
  output wire logic [3:0] die1_ltsm_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t die0_rdi_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t die1_rdi_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t die0_fdi_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t die1_fdi_state,
  output wire UcieUPM_d2dadapter_pkg::LinkInitState_t die0_fdi_init_state,
  output wire UcieUPM_d2dadapter_pkg::LinkInitState_t die1_fdi_init_state,
  output wire logic [2:0] die0_mbinit_substate,
  output wire logic [2:0] die1_mbinit_substate,
  output wire logic [3:0] die0_mbtrain_state,
  output wire logic [3:0] die1_mbtrain_state,
  output wire logic [11:0] die0_mbtrain_active_substate,
  output wire logic [11:0] die1_mbtrain_active_substate,
  output wire logic die0_ltsm_train_error,
  output wire logic die1_ltsm_train_error,
  output wire logic die0_grant_ltsm,
  output wire logic die0_grant_rdi,
  output wire logic die0_grant_fdi,
  output wire logic die1_grant_ltsm,
  output wire logic die1_grant_rdi,
  output wire logic die1_grant_fdi,
  output wire logic die0_tx_fire,
  output wire logic die1_tx_fire,
  output wire logic die0_rx_fire,
  output wire logic die1_rx_fire,
  output wire logic die0_tx_locked,
  output wire logic die1_tx_locked,
  output wire logic die0_rx_drop_unknown,
  output wire logic die1_rx_drop_unknown,
  output wire logic [127:0] progress_signature,
  output wire logic [5:0] grant_mask,
  output wire logic both_ltsm_active,
  output wire logic both_fdi_wait_protocol,
  output wire logic any_internal_transfer,
  output wire logic any_train_error,
  output wire logic any_unknown_drop,
  output wire logic all_active,
  output wire logic sb_0_to_1_data,
  output wire logic sb_0_to_1_clk,
  output wire logic sb_1_to_0_data,
  output wire logic sb_1_to_0_clk,
  output wire logic serial_wire_activity,
  output wire logic serial_idle,
  output wire logic serial_error,
  output wire logic any_sb_rx_overflow,
  output wire logic [31:0] wire_completed_0_to_1,
  output wire logic [31:0] wire_completed_1_to_0
);
  localparam bit          UCIE_A                           = 1'b0;
  localparam int unsigned PI_CODE_WIDTH                    = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH;
  localparam int unsigned TX_DESKEW_CODE_WIDTH             = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH;
  localparam int unsigned DESKEW_STEPS_PER_PI              = 1;
  localparam bit          DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1;
  localparam int unsigned DATA_LANE_COUNT                  = 16;
  localparam int unsigned VREF_CODE_WIDTH                  =
    LtsmParameters_pkg::DEFAULT_VREF_CODE_WIDTH;
  localparam int unsigned RX_DESKEW_CODE_WIDTH             = LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH;

  // Read-only verification taps. These are local to the harness; the die
  // instances below expose only scalar serial pins for sideband traffic.
  wire logic         mon_die0_tx_valid;
  wire logic [127:0] mon_die0_tx_msg;
  wire logic         mon_die0_tx_ready;
  wire logic         mon_die0_rx_valid;
  wire logic [127:0] mon_die0_rx_msg;
  wire logic         mon_die0_rx_ready;
  wire logic         mon_die1_tx_valid;
  wire logic [127:0] mon_die1_tx_msg;
  wire logic         mon_die1_tx_ready;
  wire logic         mon_die1_rx_valid;
  wire logic [127:0] mon_die1_rx_msg;
  wire logic         mon_die1_rx_ready;

  assign mon_die0_tx_valid = die0.sb_mon_tx_valid;
  assign mon_die0_tx_msg = die0.sb_mon_tx_msg;
  assign mon_die0_tx_ready = die0.sb_mon_tx_ready;
  assign mon_die0_rx_valid = die0.sb_mon_rx_valid;
  assign mon_die0_rx_msg = die0.sb_mon_rx_msg;
  assign mon_die0_rx_ready = die0.sb_mon_rx_ready;
  assign mon_die1_tx_valid = die1.sb_mon_tx_valid;
  assign mon_die1_tx_msg = die1.sb_mon_tx_msg;
  assign mon_die1_tx_ready = die1.sb_mon_tx_ready;
  assign mon_die1_rx_valid = die1.sb_mon_rx_valid;
  assign mon_die1_rx_msg = die1.sb_mon_rx_msg;
  assign mon_die1_rx_ready = die1.sb_mon_rx_ready;

  logic [PI_CODE_WIDTH-1:0] die0_valtrain_phase;
  logic [PI_CODE_WIDTH-1:0] die1_valtrain_phase;
  logic [PI_CODE_WIDTH-1:0] die0_train1_phase;
  logic [PI_CODE_WIDTH-1:0] die1_train1_phase;
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] die0_train1_deskew;
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] die1_train1_deskew;
  logic [PI_CODE_WIDTH-1:0] die0_train2_phase;
  logic [PI_CODE_WIDTH-1:0] die1_train2_phase;

  logic [15:0] die0_valtrain_result_info;
  logic [63:0] die0_valtrain_result_payload;
  logic [15:0] die1_valtrain_result_info;
  logic [63:0] die1_valtrain_result_payload;
  logic [15:0] die0_train1_result_info;
  logic [63:0] die0_train1_result_payload;
  logic [15:0] die1_train1_result_info;
  logic [63:0] die1_train1_result_payload;
  logic [15:0] die0_train2_result_info;
  logic [63:0] die0_train2_result_payload;
  logic [15:0] die1_train2_result_info;
  logic [63:0] die1_train2_result_payload;

  logic die0_serial_idle, die1_serial_idle;
  logic die0_sb_rx_overflow, die1_sb_rx_overflow;
  logic check01_idle, check10_idle, check01_error, check10_error;
  assign serial_wire_activity = sb_0_to_1_clk || sb_1_to_0_clk;
  assign serial_idle = die0_serial_idle && die1_serial_idle &&
                       check01_idle && check10_idle;
  assign any_sb_rx_overflow = die0_sb_rx_overflow || die1_sb_rx_overflow;
  assign serial_error = check01_error || check10_error || any_sb_rx_overflow;

  // These are passive checks. They neither drive nor repair received packets.
  D2DAdapterLinkMgmtTbSerialLinkChecker check_0_to_1 (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(mon_die0_tx_valid), .tx_msg(mon_die0_tx_msg), .tx_ready(mon_die0_tx_ready),
    .serial_data(sb_0_to_1_data), .serial_clock(sb_0_to_1_clk),
    .rx_valid(mon_die1_rx_valid), .rx_msg(mon_die1_rx_msg), .rx_ready(mon_die1_rx_ready),
    .wire_completed(wire_completed_0_to_1),
    .idle(check01_idle), .error(check01_error)
  );
  D2DAdapterLinkMgmtTbSerialLinkChecker check_1_to_0 (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(mon_die1_tx_valid), .tx_msg(mon_die1_tx_msg), .tx_ready(mon_die1_tx_ready),
    .serial_data(sb_1_to_0_data), .serial_clock(sb_1_to_0_clk),
    .rx_valid(mon_die0_rx_valid), .rx_msg(mon_die0_rx_msg), .rx_ready(mon_die0_rx_ready),
    .wire_completed(wire_completed_1_to_0),
    .idle(check10_idle), .error(check10_error)
  );

  // Local die1 receiver measures die0 transmitter.
  D2DAdapterLinkMgmtTbValTrainResultModel #(
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (2),
    .WINDOW_RIGHT  (7)
  ) die1_rx_for_die0_valtrain (
    .remote_tx_phase      (die0_valtrain_phase),
    .local_result_info    (die1_valtrain_result_info),
    .local_result_payload (die1_valtrain_result_payload)
  );

  // Local die0 receiver measures die1 transmitter.
  D2DAdapterLinkMgmtTbValTrainResultModel #(
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (9),
    .WINDOW_RIGHT  (13)
  ) die0_rx_for_die1_valtrain (
    .remote_tx_phase      (die1_valtrain_phase),
    .local_result_info    (die0_valtrain_result_info),
    .local_result_payload (die0_valtrain_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter1ResultModel #(
    .UCIE_A                         (UCIE_A),
    .PI_CODE_WIDTH                  (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH           (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI            (DESKEW_STEPS_PER_PI),
    .DESKEW_ADDED_DELAY_MOVES_UP    (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .BASE_CENTER                    (6),
    .HALF_EYE_WIDTH                 (2)
  ) die1_rx_for_die0_train1 (
    .remote_tx_phase        (die0_train1_phase),
    .remote_tx_deskew_codes (die0_train1_deskew),
    .local_result_info      (die1_train1_result_info),
    .local_result_payload   (die1_train1_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter1ResultModel #(
    .UCIE_A                         (UCIE_A),
    .PI_CODE_WIDTH                  (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH           (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI            (DESKEW_STEPS_PER_PI),
    .DESKEW_ADDED_DELAY_MOVES_UP    (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .BASE_CENTER                    (5),
    .HALF_EYE_WIDTH                 (2)
  ) die0_rx_for_die1_train1 (
    .remote_tx_phase        (die1_train1_phase),
    .remote_tx_deskew_codes (die1_train1_deskew),
    .local_result_info      (die0_train1_result_info),
    .local_result_payload   (die0_train1_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter2ResultModel #(
    .UCIE_A        (UCIE_A),
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (10),
    .WINDOW_RIGHT  (13)
  ) die1_rx_for_die0_train2 (
    .remote_tx_phase      (die0_train2_phase),
    .local_result_info    (die1_train2_result_info),
    .local_result_payload (die1_train2_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter2ResultModel #(
    .UCIE_A        (UCIE_A),
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (4),
    .WINDOW_RIGHT  (7)
  ) die0_rx_for_die1_train2 (
    .remote_tx_phase      (die1_train2_phase),
    .local_result_info    (die0_train2_result_info),
    .local_result_payload (die0_train2_result_payload)
  );

  D2DAdapterLinkMgmtLtsmSerialDieModel #(
    .LINK_SPEED_FAIL_TOP_RATE         (LINK_SPEED_FAIL_TOP_RATE_MASK[0]),
    .LINK_SPEED_FAIL_ALL_RATES        (LINK_SPEED_FAIL_ALL_RATES),
    .TEST_MODE_DIGITAL                (TEST_MODE_DIGITAL),
    .UCIE_A                           (UCIE_A),
    .PI_CODE_WIDTH                    (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH             (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI              (DESKEW_STEPS_PER_PI),
    .DESKEW_ADD_DELAY_INCREASES_PHASE (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .VAL_VREF_LEFT                    (2),
    .VAL_VREF_RIGHT                   (7),
    .VALTRAIN_VREF_LEFT               (4),
    .VALTRAIN_VREF_RIGHT              (9),
    .DATA_VREF_LEFT_BASE              (0),
    .DATA_VREF_LANE_PERIOD            (4),
    .DATA_VREF_WINDOW_VALUES          (5),
    .DATATRAIN_VREF_LEFT_BASE         (2),
    .DATATRAIN_VREF_LANE_PERIOD       (5),
    .DATATRAIN_VREF_WINDOW_VALUES     (6),
    .RX_DESKEW_LEFT_BASE              (1),
    .RX_DESKEW_LANE_PERIOD            (5),
    .RX_DESKEW_WINDOW_VALUES          (6)
  ) die0 (
    .clock                    (clock),
    .reset_n                  (reset_n),
    .ltsm_start               (start),
    .ltsm_stable_clk          (stable_clk),
    .ltsm_pll_locked          (pll_locked),
    .ltsm_stable_supply       (stable_supply),
    .protocol_request_active  (protocol_request_active),
    .external_fdi_control      (1'b0),
    .external_fdi_lp_state_req (UcieUPM_interfaces_pkg::PhyStateReq_nop),
    .external_fdi_lp_linkerror (1'b0),
    .external_fdi_lp_rx_active_sts(1'b0),
    .external_fdi_lp_wake_req  (1'b0),
    .external_fdi_lp_clk_ack   (1'b0),
    .external_fdi_lp_stall_ack (1'b0),
    .cycles_1us               (cycles_1us),
    .sb_tx_enable             (link_0_to_1_enable),
    .sb_tx_dout               (sb_0_to_1_data),
    .sb_tx_clk                (sb_0_to_1_clk),
    .sb_rx_din                (sb_1_to_0_data),
    .sb_rx_clk                (sb_1_to_0_clk),
    .sb_tx_idle               (die0_serial_idle),
    .sb_rx_overflow           (die0_sb_rx_overflow),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo
                              (die0_valtrain_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload
                              (die0_valtrain_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo
                              (die0_train1_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload
                              (die0_train1_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo
                              (die0_train2_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload
                              (die0_train2_result_payload),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode
                              (die0_valtrain_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode
                              (die0_train1_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes
                              (die0_train1_deskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode
                              (die0_train2_phase),
    .ltsm_state               (die0_ltsm_state),
    .fdi_pl_state_sts         (die0_fdi_state),
    .fdi_pl_rx_active_req     (),
    .fdi_pl_inband_pres       (),
    .fdi_pl_wake_ack          (),
    .fdi_pl_clk_req           (),
    .fdi_pl_stall_req         (),
    .debug_fdi_link_init_state(die0_fdi_init_state),
    .debug_rdi_state          (die0_rdi_state),
    .ltsm_dbg_mbinitSubstate  (die0_mbinit_substate),
    .ltsm_dbg_mbtrainState    (die0_mbtrain_state),
    .ltsm_dbg_mbtrainActiveSubstate(die0_mbtrain_active_substate),
    .ltsm_dbg_flagTrainError  (die0_ltsm_train_error),
    .debug_arb_grant_ltsm     (die0_grant_ltsm),
    .debug_arb_grant_fdi      (die0_grant_fdi),
    .debug_arb_grant_rdi      (die0_grant_rdi),
    .debug_arb_tx_locked      (die0_tx_locked),
    .debug_arb_tx_fire        (die0_tx_fire),
    .debug_rx_drop_unknown    (die0_rx_drop_unknown),
    .debug_rx_fire            (die0_rx_fire)
  );

  D2DAdapterLinkMgmtLtsmSerialDieModel #(
    .LINK_SPEED_FAIL_TOP_RATE         (LINK_SPEED_FAIL_TOP_RATE_MASK[1]),
    .LINK_SPEED_FAIL_ALL_RATES        (LINK_SPEED_FAIL_ALL_RATES),
    .TEST_MODE_DIGITAL                (TEST_MODE_DIGITAL),
    .UCIE_A                           (UCIE_A),
    .PI_CODE_WIDTH                    (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH             (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI              (DESKEW_STEPS_PER_PI),
    .DESKEW_ADD_DELAY_INCREASES_PHASE (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .VAL_VREF_LEFT                    (9),
    .VAL_VREF_RIGHT                   (14),
    .VALTRAIN_VREF_LEFT               (10),
    .VALTRAIN_VREF_RIGHT              (15),
    .DATA_VREF_LEFT_BASE              (5),
    .DATA_VREF_LANE_PERIOD            (4),
    .DATA_VREF_WINDOW_VALUES          (5),
    .DATATRAIN_VREF_LEFT_BASE         (7),
    .DATATRAIN_VREF_LANE_PERIOD       (4),
    .DATATRAIN_VREF_WINDOW_VALUES     (5),
    .RX_DESKEW_LEFT_BASE              (7),
    .RX_DESKEW_LANE_PERIOD            (4),
    .RX_DESKEW_WINDOW_VALUES          (5)
  ) die1 (
    .clock                    (clock),
    .reset_n                  (reset_n),
    .ltsm_start               (start),
    .ltsm_stable_clk          (stable_clk),
    .ltsm_pll_locked          (pll_locked),
    .ltsm_stable_supply       (stable_supply),
    .protocol_request_active  (protocol_request_active),
    .external_fdi_control      (1'b0),
    .external_fdi_lp_state_req (UcieUPM_interfaces_pkg::PhyStateReq_nop),
    .external_fdi_lp_linkerror (1'b0),
    .external_fdi_lp_rx_active_sts(1'b0),
    .external_fdi_lp_wake_req  (1'b0),
    .external_fdi_lp_clk_ack   (1'b0),
    .external_fdi_lp_stall_ack (1'b0),
    .cycles_1us               (cycles_1us),
    .sb_tx_enable             (link_1_to_0_enable),
    .sb_tx_dout               (sb_1_to_0_data),
    .sb_tx_clk                (sb_1_to_0_clk),
    .sb_rx_din                (sb_0_to_1_data),
    .sb_rx_clk                (sb_0_to_1_clk),
    .sb_tx_idle               (die1_serial_idle),
    .sb_rx_overflow           (die1_sb_rx_overflow),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo
                              (die1_valtrain_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload
                              (die1_valtrain_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo
                              (die1_train1_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload
                              (die1_train1_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo
                              (die1_train2_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload
                              (die1_train2_result_payload),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode
                              (die1_valtrain_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode
                              (die1_train1_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes
                              (die1_train1_deskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode
                              (die1_train2_phase),
    .ltsm_state               (die1_ltsm_state),
    .fdi_pl_state_sts         (die1_fdi_state),
    .fdi_pl_rx_active_req     (),
    .fdi_pl_inband_pres       (),
    .fdi_pl_wake_ack          (),
    .fdi_pl_clk_req           (),
    .fdi_pl_stall_req         (),
    .debug_fdi_link_init_state(die1_fdi_init_state),
    .debug_rdi_state          (die1_rdi_state),
    .ltsm_dbg_mbinitSubstate  (die1_mbinit_substate),
    .ltsm_dbg_mbtrainState    (die1_mbtrain_state),
    .ltsm_dbg_mbtrainActiveSubstate(die1_mbtrain_active_substate),
    .ltsm_dbg_flagTrainError  (die1_ltsm_train_error),
    .debug_arb_grant_ltsm     (die1_grant_ltsm),
    .debug_arb_grant_fdi      (die1_grant_fdi),
    .debug_arb_grant_rdi      (die1_grant_rdi),
    .debug_arb_tx_locked      (die1_tx_locked),
    .debug_arb_tx_fire        (die1_tx_fire),
    .debug_rx_drop_unknown    (die1_rx_drop_unknown),
    .debug_rx_fire            (die1_rx_fire)
  );

  assign progress_signature = {
    4'b0,
    mon_die1_tx_msg[27:0], mon_die0_tx_msg[27:0],
    die1_mbtrain_active_substate, die0_mbtrain_active_substate,
    die1_mbtrain_state, die0_mbtrain_state,
    die1_mbinit_substate, die0_mbinit_substate,
    die1_fdi_init_state, die0_fdi_init_state,
    die1_fdi_state, die0_fdi_state,
    die1_rdi_state, die0_rdi_state,
    die1_ltsm_state, die0_ltsm_state
  };

  assign grant_mask = {
    die1_grant_fdi, die1_grant_rdi, die1_grant_ltsm,
    die0_grant_fdi, die0_grant_rdi, die0_grant_ltsm
  };

  assign both_ltsm_active =
    (die0_ltsm_state == 4'd8) && (die1_ltsm_state == 4'd8);
  assign both_fdi_wait_protocol =
    (die0_fdi_init_state ==
      UcieUPM_d2dadapter_pkg::LinkInitState_FDI_WAIT_LP_REQ_ACTIVE) &&
    (die1_fdi_init_state ==
      UcieUPM_d2dadapter_pkg::LinkInitState_FDI_WAIT_LP_REQ_ACTIVE);
  assign any_internal_transfer =
    die0_tx_fire || die1_tx_fire || die0_rx_fire || die1_rx_fire;
  assign any_train_error = die0_ltsm_train_error || die1_ltsm_train_error;
  assign any_unknown_drop = die0_rx_drop_unknown || die1_rx_drop_unknown;
  assign all_active =
    both_ltsm_active &&
    (die0_rdi_state == UcieUPM_interfaces_pkg::PhyState_active) &&
    (die1_rdi_state == UcieUPM_interfaces_pkg::PhyState_active) &&
    (die0_fdi_state == UcieUPM_interfaces_pkg::PhyState_active) &&
    (die1_fdi_state == UcieUPM_interfaces_pkg::PhyState_active);
endmodule

`default_nettype wire
