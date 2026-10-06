// Dual-die integration harness for UPMSerialControllerConnection.
//
// The analog models are derived from the supplied full LinkTrainingFSM
// sideband tests.  They acknowledge every new PHY-control handshake, model
// passing Vref/RX-deskew windows, and return cross-die Tx Init D2C point-test
// results through the real sideband path.  No internal DUT state is forced.

`timescale 1ns/1ps
`default_nettype none

// The shared message queue is defined in TbSidebandOneWay.sv.

// Valid-lane phase-eye model used by VALTRAINCENTER.
module D2DAdapterLinkMgmtTbValTrainResultModel #(
  parameter int unsigned PI_CODE_WIDTH = 4,
  parameter int unsigned WINDOW_LEFT   = 2,
  parameter int unsigned WINDOW_RIGHT  = 7
) (
  input  wire logic [PI_CODE_WIDTH-1:0] remote_tx_phase,
  output      logic [15:0]              local_result_info,
  output      logic [63:0]              local_result_payload
);
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
  integer phase_int;
  logic valid_pass;

  always_comb begin
    phase_int = remote_tx_phase;
    valid_pass =
      (WINDOW_LEFT <= WINDOW_RIGHT) &&
      (WINDOW_RIGHT < PHASE_COUNT) &&
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
  parameter int unsigned PI_CODE_WIDTH                  = 4,
  parameter int unsigned TX_DESKEW_CODE_WIDTH           = 4,
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
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
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
    phase_int             = remote_tx_phase;
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
        deskew_code_int = remote_tx_deskew_codes[
          lane*TX_DESKEW_CODE_WIDTH +: TX_DESKEW_CODE_WIDTH
        ];
        deskew_phase_steps_int = deskew_code_int / DESKEW_STEPS_PER_PI;

        if (DESKEW_ADDED_DELAY_MOVES_UP)
          shifted_center_int = base_center_int + deskew_phase_steps_int;
        else
          shifted_center_int = base_center_int - deskew_phase_steps_int;

        lower_edge_int = shifted_center_int - HALF_EYE_WIDTH;
        upper_edge_int = shifted_center_int + HALF_EYE_WIDTH;
        lane_pass =
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
  parameter int unsigned PI_CODE_WIDTH = 4,
  parameter int unsigned WINDOW_LEFT   = 4,
  parameter int unsigned WINDOW_RIGHT  = 7
) (
  input  wire logic [PI_CODE_WIDTH-1:0] remote_tx_phase,
  output      logic [15:0]              local_result_info,
  output      logic [63:0]              local_result_payload
);
  localparam int unsigned PHASE_COUNT = (1 << PI_CODE_WIDTH);
  localparam logic [63:0] ACTIVE_LANE_MASK =
    UCIE_A ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0000_0000_0000_FFFF;
  integer phase_int;
  logic aggregate_pass;

  always_comb begin
    phase_int = remote_tx_phase;
    aggregate_pass =
      (WINDOW_LEFT <= WINDOW_RIGHT) &&
      (WINDOW_RIGHT < PHASE_COUNT) &&
      (phase_int >= WINDOW_LEFT) &&
      (phase_int <= WINDOW_RIGHT);

    local_result_info       = '0;
    local_result_info[5]    = 1'b1;
    local_result_info[4]    = aggregate_pass;
    local_result_payload    = aggregate_pass ? ACTIVE_LANE_MASK : 64'b0;
  end
endmodule
module UPMSerialDieBringUpModel #(
  // FDI, RDI, and sideband widths are not part of this PHY-training model's
  // interface.  The integrated DUT therefore uses its own package defaults.
  parameter bit          UCIE_A                           = 1'b0,
  parameter int unsigned PI_CODE_WIDTH                    = 4,
  parameter int unsigned TX_DESKEW_CODE_WIDTH             = 4,
  parameter int unsigned DESKEW_STEPS_PER_PI              = 1,
  parameter bit          DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1,
  parameter int unsigned MIN_LANE_WINDOW_STEPS            = 3,
  parameter int unsigned MIN_COMMON_WINDOW_STEPS          = 3,
  parameter int unsigned MAX_TRAINING_RETRIES             = 1,
  parameter int unsigned VREF_VALUE_COUNT                 = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter int unsigned DATA_LANE_COUNT                  = 16,
  parameter int unsigned RX_DESKEW_VALUE_COUNT            = 16,
  parameter int unsigned RX_DESKEW_CODE_WIDTH =
    (RX_DESKEW_VALUE_COUNT <= 1) ? 1 : $clog2(RX_DESKEW_VALUE_COUNT),
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
  parameter int unsigned RX_DESKEW_WINDOW_VALUES          = 6
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
  output wire logic sb_tx_dout, sb_tx_clk,
  input wire logic sb_rx_din, sb_rx_clk,
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
    16'hFFFF;

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
      (ltsm_flagToAnalog_valVref_rxVrefCode >= VAL_VREF_LEFT) &&
      (ltsm_flagToAnalog_valVref_rxVrefCode <= VAL_VREF_RIGHT);
    ltsm_flagFromAnalog_valTrainVref_detectedValPattern =
      (ltsm_flagToAnalog_valTrainVref_rxVrefCode >= VALTRAIN_VREF_LEFT) &&
      (ltsm_flagToAnalog_valTrainVref_rxVrefCode <= VALTRAIN_VREF_RIGHT);

    ltsm_flagFromAnalog_dataVref_detectedDataPattern = '0;
    ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern = '0;
    ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = '0;

    for (int unsigned lane = 0; lane < DATA_LANE_COUNT; lane = lane + 1) begin
      ltsm_flagFromAnalog_dataVref_detectedDataPattern[lane] =
        (ltsm_flagToAnalog_dataVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] >= data_vref_left(lane)) &&
        (ltsm_flagToAnalog_dataVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] <
           (data_vref_left(lane) + DATA_VREF_WINDOW_VALUES));

      ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern[lane] =
        (ltsm_flagToAnalog_dataTrainVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] >= datatrain_vref_left(lane)) &&
        (ltsm_flagToAnalog_dataTrainVref_rxVrefCodes[
           lane*VREF_CODE_WIDTH +: VREF_CODE_WIDTH] <
           (datatrain_vref_left(lane) + DATATRAIN_VREF_WINDOW_VALUES));

      ltsm_flagFromAnalog_rxDeskew_detectedDataPattern[lane] =
        (ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes[
           lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH] >=
           rx_deskew_left(lane)) &&
        (ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes[
           lane*RX_DESKEW_CODE_WIDTH +: RX_DESKEW_CODE_WIDTH] <
           (rx_deskew_left(lane) + RX_DESKEW_WINDOW_VALUES));
    end
  end

  UPMSerialControllerConnection #(
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
    .sb_tx_dout(sb_tx_dout), .sb_tx_clk(sb_tx_clk),
    .sb_rx_din(sb_rx_din), .sb_rx_clk(sb_rx_clk),
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
    .ltsm_flagToAnalog_valVref_sendPattern                                          (ltsm_flagToAnalog_valVref_sendPattern),
    .ltsm_flagFromAnalog_valVref_detectedValPattern                                 (ltsm_flagFromAnalog_valVref_detectedValPattern),
    .ltsm_flagFromAnalog_valVref_finishedPattern                                    (ltsm_flagFromAnalog_valVref_finishedPattern),
    .ltsm_flagToAnalog_valVref_applyRxVref                                          (ltsm_flagToAnalog_valVref_applyRxVref),
    .ltsm_flagToAnalog_valVref_rxVrefCode                                           (ltsm_flagToAnalog_valVref_rxVrefCode),
    .ltsm_flagFromAnalog_valVref_rxVrefApplied                                      (ltsm_flagFromAnalog_valVref_rxVrefApplied),
    .ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest                          (ltsm_flagToAnalog_valVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold                      (ltsm_flagToAnalog_valVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_valVref_comparisonMode                                       (ltsm_flagToAnalog_valVref_comparisonMode),
    .ltsm_flagToAnalog_valVref_iterationCountSettings                               (ltsm_flagToAnalog_valVref_iterationCountSettings),
    .ltsm_flagToAnalog_valVref_idleCountSettings                                    (ltsm_flagToAnalog_valVref_idleCountSettings),
    .ltsm_flagToAnalog_valVref_burstCountSettings                                   (ltsm_flagToAnalog_valVref_burstCountSettings),
    .ltsm_flagToAnalog_valVref_patternMode                                          (ltsm_flagToAnalog_valVref_patternMode),
    .ltsm_flagToAnalog_valVref_clockPhaseControl                                    (ltsm_flagToAnalog_valVref_clockPhaseControl),
    .ltsm_flagToAnalog_valVref_validPattern                                         (ltsm_flagToAnalog_valVref_validPattern),
    .ltsm_flagToAnalog_valVref_dataPattern                                          (ltsm_flagToAnalog_valVref_dataPattern),
    .ltsm_flagToAnalog_valVref_clearComparisonErrors                                (ltsm_flagToAnalog_valVref_clearComparisonErrors),
    .ltsm_flagToAnalog_valVref_resetLocalTxScrambler                                (ltsm_flagToAnalog_valVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_dataVref_sendPattern                                         (ltsm_flagToAnalog_dataVref_sendPattern),
    .ltsm_flagFromAnalog_dataVref_detectedDataPattern                               (ltsm_flagFromAnalog_dataVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataVref_finishedPattern                                   (ltsm_flagFromAnalog_dataVref_finishedPattern),
    .ltsm_flagToAnalog_dataVref_applyRxVref                                         (ltsm_flagToAnalog_dataVref_applyRxVref),
    .ltsm_flagToAnalog_dataVref_rxVrefCodes                                         (ltsm_flagToAnalog_dataVref_rxVrefCodes),
    .ltsm_flagFromAnalog_dataVref_rxVrefApplied                                     (ltsm_flagFromAnalog_dataVref_rxVrefApplied),
    .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest                         (ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold                     (ltsm_flagToAnalog_dataVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_dataVref_comparisonMode                                      (ltsm_flagToAnalog_dataVref_comparisonMode),
    .ltsm_flagToAnalog_dataVref_iterationCountSettings                              (ltsm_flagToAnalog_dataVref_iterationCountSettings),
    .ltsm_flagToAnalog_dataVref_idleCountSettings                                   (ltsm_flagToAnalog_dataVref_idleCountSettings),
    .ltsm_flagToAnalog_dataVref_burstCountSettings                                  (ltsm_flagToAnalog_dataVref_burstCountSettings),
    .ltsm_flagToAnalog_dataVref_patternMode                                         (ltsm_flagToAnalog_dataVref_patternMode),
    .ltsm_flagToAnalog_dataVref_clockPhaseControl                                   (ltsm_flagToAnalog_dataVref_clockPhaseControl),
    .ltsm_flagToAnalog_dataVref_validPattern                                        (ltsm_flagToAnalog_dataVref_validPattern),
    .ltsm_flagToAnalog_dataVref_dataPattern                                         (ltsm_flagToAnalog_dataVref_dataPattern),
    .ltsm_flagToAnalog_dataVref_clearComparisonErrors                               (ltsm_flagToAnalog_dataVref_clearComparisonErrors),
    .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler                               (ltsm_flagToAnalog_dataVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_rxClkCal_doCalibration                                       (ltsm_flagToAnalog_rxClkCal_doCalibration),
    .ltsm_flagFromAnalog_rxClkCal_done                                              (ltsm_flagFromAnalog_rxClkCal_done),
    .ltsm_flagToAnalog_rxClkCal_sendClockTrack                                      (ltsm_flagToAnalog_rxClkCal_sendClockTrack),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern                 (ltsm_flagToAnalog_d2cSender_valTrainCenter_sendValTrainPattern),
    .ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent               (ltsm_flagFromAnalog_d2cSender_valTrainCenter_valTrainPatternSent),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler                 (ltsm_flagToAnalog_d2cSender_valTrainCenter_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase                   (ltsm_flagToAnalog_d2cSender_valTrainCenter_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode                    (ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied               (ltsm_flagFromAnalog_d2cSender_valTrainCenter_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold   (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode                    (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings            (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings                 (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings                (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode                       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl                 (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern                      (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern                       (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler             (ltsm_flagToAnalog_d2cReceiver_valTrainCenter_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo         (ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload         (ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_valTrainVref_sendPattern                                     (ltsm_flagToAnalog_valTrainVref_sendPattern),
    .ltsm_flagFromAnalog_valTrainVref_detectedValPattern                            (ltsm_flagFromAnalog_valTrainVref_detectedValPattern),
    .ltsm_flagFromAnalog_valTrainVref_finishedPattern                               (ltsm_flagFromAnalog_valTrainVref_finishedPattern),
    .ltsm_flagToAnalog_valTrainVref_applyRxVref                                     (ltsm_flagToAnalog_valTrainVref_applyRxVref),
    .ltsm_flagToAnalog_valTrainVref_rxVrefCode                                      (ltsm_flagToAnalog_valTrainVref_rxVrefCode),
    .ltsm_flagFromAnalog_valTrainVref_rxVrefApplied                                 (ltsm_flagFromAnalog_valTrainVref_rxVrefApplied),
    .ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest                     (ltsm_flagToAnalog_valTrainVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold                 (ltsm_flagToAnalog_valTrainVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_valTrainVref_comparisonMode                                  (ltsm_flagToAnalog_valTrainVref_comparisonMode),
    .ltsm_flagToAnalog_valTrainVref_iterationCountSettings                          (ltsm_flagToAnalog_valTrainVref_iterationCountSettings),
    .ltsm_flagToAnalog_valTrainVref_idleCountSettings                               (ltsm_flagToAnalog_valTrainVref_idleCountSettings),
    .ltsm_flagToAnalog_valTrainVref_burstCountSettings                              (ltsm_flagToAnalog_valTrainVref_burstCountSettings),
    .ltsm_flagToAnalog_valTrainVref_patternMode                                     (ltsm_flagToAnalog_valTrainVref_patternMode),
    .ltsm_flagToAnalog_valTrainVref_clockPhaseControl                               (ltsm_flagToAnalog_valTrainVref_clockPhaseControl),
    .ltsm_flagToAnalog_valTrainVref_validPattern                                    (ltsm_flagToAnalog_valTrainVref_validPattern),
    .ltsm_flagToAnalog_valTrainVref_dataPattern                                     (ltsm_flagToAnalog_valTrainVref_dataPattern),
    .ltsm_flagToAnalog_valTrainVref_clearComparisonErrors                           (ltsm_flagToAnalog_valTrainVref_clearComparisonErrors),
    .ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler                           (ltsm_flagToAnalog_valTrainVref_resetLocalTxScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern                   (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent                 (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler               (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode                  (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_applyTxLaneDeskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter1_txLaneDeskewApplied),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode                  (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings          (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings              (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern                    (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler           (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter1_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload),
    .ltsm_flagToAnalog_dataTrainVref_sendPattern                                    (ltsm_flagToAnalog_dataTrainVref_sendPattern),
    .ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern                          (ltsm_flagFromAnalog_dataTrainVref_detectedDataPattern),
    .ltsm_flagFromAnalog_dataTrainVref_finishedPattern                              (ltsm_flagFromAnalog_dataTrainVref_finishedPattern),
    .ltsm_flagToAnalog_dataTrainVref_applyRxVref                                    (ltsm_flagToAnalog_dataTrainVref_applyRxVref),
    .ltsm_flagToAnalog_dataTrainVref_rxVrefCodes                                    (ltsm_flagToAnalog_dataTrainVref_rxVrefCodes),
    .ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied                                (ltsm_flagFromAnalog_dataTrainVref_rxVrefApplied),
    .ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest                    (ltsm_flagToAnalog_dataTrainVref_configureRxInitD2CPointTest),
    .ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold                (ltsm_flagToAnalog_dataTrainVref_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_dataTrainVref_comparisonMode                                 (ltsm_flagToAnalog_dataTrainVref_comparisonMode),
    .ltsm_flagToAnalog_dataTrainVref_iterationCountSettings                         (ltsm_flagToAnalog_dataTrainVref_iterationCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_idleCountSettings                              (ltsm_flagToAnalog_dataTrainVref_idleCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_burstCountSettings                             (ltsm_flagToAnalog_dataTrainVref_burstCountSettings),
    .ltsm_flagToAnalog_dataTrainVref_patternMode                                    (ltsm_flagToAnalog_dataTrainVref_patternMode),
    .ltsm_flagToAnalog_dataTrainVref_clockPhaseControl                              (ltsm_flagToAnalog_dataTrainVref_clockPhaseControl),
    .ltsm_flagToAnalog_dataTrainVref_validPattern                                   (ltsm_flagToAnalog_dataTrainVref_validPattern),
    .ltsm_flagToAnalog_dataTrainVref_dataPattern                                    (ltsm_flagToAnalog_dataTrainVref_dataPattern),
    .ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors                          (ltsm_flagToAnalog_dataTrainVref_clearComparisonErrors),
    .ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler                          (ltsm_flagToAnalog_dataTrainVref_resetLocalTxScrambler),
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
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern                   (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent                 (ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler               (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase                 (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_applyTxClockPhase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode                  (ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode),
    .ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied             (ltsm_flagFromAnalog_d2cSender_dataTrainCenter2_txClockPhaseApplied),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode                  (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings          (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings              (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl               (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern                    (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern                     (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler           (ltsm_flagToAnalog_d2cReceiver_dataTrainCenter2_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload       (ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload),
    .ltsm_flagToLtsm_linkSpeed_phyInRetrain                                         (ltsm_flagToLtsm_linkSpeed_phyInRetrain),
    .ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern                          (ltsm_flagToAnalog_d2cSender_linkSpeed_sendLfsrPattern),
    .ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent                        (ltsm_flagFromAnalog_d2cSender_linkSpeed_lfsrPatternSent),
    .ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler                      (ltsm_flagToAnalog_d2cSender_linkSpeed_resetLocalScrambler),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_configureTxInitD2CPointTest),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold        (ltsm_flagToAnalog_d2cReceiver_linkSpeed_maximumComparisonErrorThreshold),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode                         (ltsm_flagToAnalog_d2cReceiver_linkSpeed_comparisonMode),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings                 (ltsm_flagToAnalog_d2cReceiver_linkSpeed_iterationCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings                      (ltsm_flagToAnalog_d2cReceiver_linkSpeed_idleCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings                     (ltsm_flagToAnalog_d2cReceiver_linkSpeed_burstCountSettings),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode                            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_patternMode),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl                      (ltsm_flagToAnalog_d2cReceiver_linkSpeed_clockPhaseControl),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern                           (ltsm_flagToAnalog_d2cReceiver_linkSpeed_validPattern),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern                            (ltsm_flagToAnalog_d2cReceiver_linkSpeed_dataPattern),
    .ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler                  (ltsm_flagToAnalog_d2cReceiver_linkSpeed_resetLocalRxScrambler),
    .ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful             (ltsm_flagFromAnalog_d2cReceiver_linkSpeed_laneComparisonSuccessful),
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
    .debug_rx_fire                                                                  (debug_rx_fire)
  );
endmodule


`default_nettype wire
