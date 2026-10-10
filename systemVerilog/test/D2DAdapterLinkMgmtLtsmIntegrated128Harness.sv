// Directed single-DUT scenarios with real one-bit sideband at both dies.
// Training uses an external store-and-forward serial BFM: complete LTSM wire
// frames are decoded and reserialized to the other die; local management
// frames are retained for directed stimulus, and peer management is drained.
// This relay is specific to directed tests.  The dual-die bring-up and
// backpressure harnesses connect the two physical serial interfaces directly.
// No controller packet input is driven by this harness.

`timescale 1ns/1ps
`default_nettype none

module D2DAdapterLinkMgmtLtsmIntegrated128Harness (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic ltsm_start,
  input  wire logic ltsm_stable_clk,
  input  wire logic ltsm_pll_locked,
  input  wire logic ltsm_stable_supply,
  input  wire logic manual_sideband_mode,

  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input  wire logic                                  fdi_lp_linkerror,
  input  wire logic                                  fdi_lp_rx_active_sts,
  input  wire logic                                  fdi_lp_wake_req,
  input  wire logic                                  fdi_lp_clk_ack,
  input  wire logic                                  fdi_lp_stall_ack,
  output wire UcieUPM_interfaces_pkg::PhyState_t    fdi_pl_state_sts,
  output wire logic                                  fdi_pl_rx_active_req,
  output wire logic                                  fdi_pl_inband_pres,
  output wire logic                                  fdi_pl_wake_ack,
  output wire logic                                  fdi_pl_clk_req,
  output wire logic                                  fdi_pl_stall_req,

  output wire logic         sb_tx_valid,
  output wire logic [127:0] sb_tx_msg,
  input  wire logic         sb_tx_ready,
  input  wire logic         sb_rx_valid,
  input  wire logic [127:0] sb_rx_msg,
  output wire logic         sb_rx_ready,
  input  wire logic [31:0]  cycles_1us,

  output wire logic [3:0] local_ltsm_state,
  output wire logic [3:0] peer_ltsm_state,
  output wire logic [2:0] local_mbinit_substate,
  output wire logic [2:0] peer_mbinit_substate,
  output wire logic [3:0] local_mbtrain_state,
  output wire logic [3:0] peer_mbtrain_state,
  output wire logic [11:0] local_mbtrain_active_substate,
  output wire logic [11:0] peer_mbtrain_active_substate,
  output wire logic local_ltsm_train_error,
  output wire logic peer_ltsm_train_error,
  output wire logic training_complete,
  output logic training_sideband_transfer,
  output logic training_unknown_drop,
  output wire logic serial_error,
  output wire logic serial_idle,

  output wire UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state,
  output wire UcieUPM_interfaces_pkg::PhyState_t      debug_rdi_state,
  output wire logic debug_arb_grant_ltsm,
  output wire logic debug_arb_grant_fdi,
  output wire logic debug_arb_grant_rdi,
  output wire logic debug_arb_tx_locked,
  output wire logic debug_arb_tx_fire,
  output wire logic debug_rx_drop_unknown,
  output wire logic debug_rx_fire
);
  import SidebandMsgGenerator_pkg::*;

  localparam bit          UCIE_A                           = 1'b0;
  localparam int unsigned PI_CODE_WIDTH                    = 4;
  localparam int unsigned TX_DESKEW_CODE_WIDTH             = 4;
  localparam int unsigned DESKEW_STEPS_PER_PI              = 1;
  localparam bit          DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1;

  logic local_raw_tx_valid;
  logic [127:0] local_raw_tx_msg;
  logic local_raw_tx_ready;
  logic local_raw_rx_valid;
  logic [127:0] local_raw_rx_msg;
  logic local_raw_rx_ready;

  logic peer_raw_tx_valid;
  logic [127:0] peer_raw_tx_msg;
  logic peer_raw_tx_ready;
  logic peer_raw_rx_valid;
  logic [127:0] peer_raw_rx_msg;
  logic peer_raw_rx_ready;

  logic local_serial_data, local_serial_clock, local_serial_idle;
  logic peer_serial_data, peer_serial_clock, peer_serial_idle;
  logic local_in_data, local_in_clock, peer_in_data, peer_in_clock;
  logic local_bfm_send_valid, local_bfm_send_ready, local_bfm_idle;
  logic peer_bfm_send_valid, peer_bfm_send_ready, peer_bfm_idle;
  logic [127:0] local_bfm_send_msg, peer_bfm_send_msg;
  logic local_dec_valid, local_dec_ready, peer_dec_valid, peer_dec_ready;
  logic [127:0] local_dec_msg, peer_dec_msg;
  logic local_dec_ltsm, peer_dec_ltsm;
  logic local_out_check_idle, peer_out_check_idle;
  logic local_in_check_idle, peer_in_check_idle;
  logic local_out_error, peer_out_error, local_in_error, peer_in_error;
  logic [31:0] local_out_completed, peer_out_completed;
  logic [31:0] local_in_completed, peer_in_completed;
  logic physical_training_complete;

  logic local_grant_ltsm;
  logic local_grant_fdi;
  logic local_grant_rdi;
  logic peer_grant_ltsm;
  logic peer_grant_fdi;
  logic peer_grant_rdi;
  logic local_tx_fire;
  logic peer_tx_fire;
  logic local_rx_fire;
  logic peer_rx_fire;
  logic local_unknown_drop;
  logic peer_unknown_drop;

  // Observe complete serialized packets continuously, including the first
  // local RDI Req.Active emitted before the directed test starts consuming.
  localparam int unsigned MANUAL_QUEUE_DEPTH = 256;
  logic [127:0] manual_queue [0:MANUAL_QUEUE_DEPTH-1];
  integer unsigned manual_write_count, manual_read_count;
  logic capture_manual_tx, consume_manual_tx;
  logic manual_mode_delayed;
  UcieUPM_interfaces_pkg::PhyState_t trace_previous_fdi, trace_previous_rdi;

  logic [PI_CODE_WIDTH-1:0] local_valtrain_phase;
  logic [PI_CODE_WIDTH-1:0] peer_valtrain_phase;
  logic [PI_CODE_WIDTH-1:0] local_train1_phase;
  logic [PI_CODE_WIDTH-1:0] peer_train1_phase;
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] local_train1_deskew;
  logic [64*TX_DESKEW_CODE_WIDTH-1:0] peer_train1_deskew;
  logic [PI_CODE_WIDTH-1:0] local_train2_phase;
  logic [PI_CODE_WIDTH-1:0] peer_train2_phase;

  logic [15:0] local_valtrain_result_info;
  logic [63:0] local_valtrain_result_payload;
  logic [15:0] peer_valtrain_result_info;
  logic [63:0] peer_valtrain_result_payload;
  logic [15:0] local_train1_result_info;
  logic [63:0] local_train1_result_payload;
  logic [15:0] peer_train1_result_info;
  logic [63:0] peer_train1_result_payload;
  logic [15:0] local_train2_result_info;
  logic [63:0] local_train2_result_payload;
  logic [15:0] peer_train2_result_info;
  logic [63:0] peer_train2_result_payload;

  UcieUPM_interfaces_pkg::PhyState_t peer_fdi_state;
  UcieUPM_interfaces_pkg::PhyState_t peer_rdi_state;
  UcieUPM_d2dadapter_pkg::LinkInitState_t peer_fdi_init_state;
  logic peer_fdi_rx_active_req;
  logic peer_fdi_inband_pres;
  logic peer_fdi_wake_ack;
  logic peer_fdi_clk_req;
  logic peer_fdi_stall_req;
  logic peer_tx_locked;

  assign physical_training_complete =
    (local_ltsm_state == 4'd8) && (peer_ltsm_state == 4'd8);
  // Both physical FSMs being Active is insufficient: last frames can still
  // be in serializer FIFOs, in flight, or queued in the serial relay.
  assign serial_idle = local_serial_idle && peer_serial_idle &&
    local_bfm_idle && peer_bfm_idle &&
    local_out_check_idle && peer_out_check_idle &&
    local_in_check_idle && peer_in_check_idle;
  assign training_complete = physical_training_complete && serial_idle;

  assign local_dec_ltsm = UCIe2_isLtsmMessage(local_dec_msg);
  assign peer_dec_ltsm = UCIe2_isLtsmMessage(peer_dec_msg);

  // Only complete decoded training frames cross the relay.  The production
  // SidebandTx sends every relayed/injected message through the DUT RX pins.
  assign local_bfm_send_valid = manual_sideband_mode ? sb_rx_valid
    : (peer_dec_valid && peer_dec_ltsm);
  assign local_bfm_send_msg = manual_sideband_mode ? sb_rx_msg : peer_dec_msg;
  assign peer_bfm_send_valid = !manual_sideband_mode && local_dec_valid && local_dec_ltsm;
  assign peer_bfm_send_msg = local_dec_msg;
  assign peer_dec_ready = manual_sideband_mode || !peer_dec_ltsm || local_bfm_send_ready;
  assign local_dec_ready = (!manual_sideband_mode && local_dec_ltsm)
    ? peer_bfm_send_ready : (manual_write_count - manual_read_count < MANUAL_QUEUE_DEPTH);

  assign capture_manual_tx = local_dec_valid && local_dec_ready &&
    (manual_sideband_mode || !local_dec_ltsm);
  assign consume_manual_tx = sb_tx_valid && sb_tx_ready;
  assign sb_tx_valid = manual_sideband_mode && (manual_write_count != manual_read_count);
  assign sb_tx_msg = (manual_write_count != manual_read_count)
    ? manual_queue[manual_read_count % MANUAL_QUEUE_DEPTH] : 128'b0;
  assign sb_rx_ready = manual_sideband_mode && local_bfm_send_ready;

  always @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      manual_write_count <= 0;
      manual_read_count <= 0;
      manual_mode_delayed <= 1'b0;
    end else begin
      manual_mode_delayed <= manual_sideband_mode;
      if (manual_sideband_mode && !manual_mode_delayed && physical_training_complete &&
          !training_complete)
        $fatal(1, "Manual sideband handoff requested before serial traffic drained");
      if (capture_manual_tx) begin
        manual_queue[manual_write_count % MANUAL_QUEUE_DEPTH] <= local_dec_msg;
        manual_write_count <= manual_write_count + 1;
      end
      if (consume_manual_tx) manual_read_count <= manual_read_count + 1;
      if (local_dec_valid && (manual_sideband_mode || !local_dec_ltsm) && !local_dec_ready)
        $fatal(1, "Integrated serial manual observation queue overflow");
    end
  end

  // The stimulus samples after the clock edge.  Register the transfer event
  // before the receive FIFO advances so that every accepted frame is visible.
  always @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      training_sideband_transfer <= 1'b0;
      training_unknown_drop <= 1'b0;
    end else begin
      training_sideband_transfer <= !manual_sideband_mode &&
        ((local_dec_valid && local_dec_ready && local_dec_ltsm) ||
         (peer_dec_valid && peer_dec_ready && peer_dec_ltsm));
      if (!manual_sideband_mode && (local_unknown_drop || peer_unknown_drop))
        training_unknown_drop <= 1'b1;
    end
  end
  assign serial_error = local_out_error || peer_out_error || local_in_error || peer_in_error;

  // Optional transaction/state log for diagnosing directed controller tests.
  // These observations have no influence on the wire or controller inputs.
  always @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      trace_previous_fdi <= UcieUPM_interfaces_pkg::PhyState_reset;
      trace_previous_rdi <= UcieUPM_interfaces_pkg::PhyState_reset;
    end else begin
      if ($test$plusargs("SERIAL_TRACE") && manual_sideband_mode) begin
        if (local_raw_tx_valid && local_raw_tx_ready)
          $display("[SERIAL TRACE] t=%0t TX enqueue header=%016h FDI=%0h RDI=%0h LP.req=%0h",
            $time, local_raw_tx_msg[63:0], fdi_pl_state_sts, debug_rdi_state, fdi_lp_state_req);
        if (fdi_pl_state_sts != trace_previous_fdi || debug_rdi_state != trace_previous_rdi)
          $display("[SERIAL TRACE] t=%0t state FDI=%0h RDI=%0h LP.req=%0h",
            $time, fdi_pl_state_sts, debug_rdi_state, fdi_lp_state_req);
      end
      trace_previous_fdi <= fdi_pl_state_sts;
      trace_previous_rdi <= debug_rdi_state;
    end
  end

  assign debug_arb_grant_ltsm = local_grant_ltsm;
  assign debug_arb_grant_fdi  = local_grant_fdi;
  assign debug_arb_grant_rdi  = local_grant_rdi;
  assign debug_arb_tx_fire    = local_tx_fire;
  assign debug_rx_drop_unknown = local_unknown_drop;
  assign debug_rx_fire         = local_rx_fire;

  D2DAdapterLinkMgmtTbSerialBfm local_endpoint (
    .clock(clock), .reset_n(reset_n),
    .send_valid(local_bfm_send_valid), .send_msg(local_bfm_send_msg),
    .send_ready(local_bfm_send_ready), .tx_data(local_in_data), .tx_clock(local_in_clock),
    .rx_data(local_serial_data), .rx_clock(local_serial_clock),
    .received_valid(local_dec_valid), .received_msg(local_dec_msg),
    .received_ready(local_dec_ready), .idle(local_bfm_idle)
  );
  D2DAdapterLinkMgmtTbSerialBfm peer_endpoint (
    .clock(clock), .reset_n(reset_n),
    .send_valid(peer_bfm_send_valid), .send_msg(peer_bfm_send_msg),
    .send_ready(peer_bfm_send_ready), .tx_data(peer_in_data), .tx_clock(peer_in_clock),
    .rx_data(peer_serial_data), .rx_clock(peer_serial_clock),
    .received_valid(peer_dec_valid), .received_msg(peer_dec_msg),
    .received_ready(peer_dec_ready), .idle(peer_bfm_idle)
  );

  // Check complete wire frames against their enqueue transaction and check
  // each DUT's unmodified raw RX acceptance exactly once.  BFM observations
  // never qualify or repair the valid signal delivered to the controller.
  D2DAdapterLinkMgmtTbSerialLinkChecker #(.CHECK_RX_ACCEPT(0)) local_output_check (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(local_raw_tx_valid), .tx_msg(local_raw_tx_msg), .tx_ready(local_raw_tx_ready),
    .serial_data(local_serial_data), .serial_clock(local_serial_clock),
    .rx_valid(1'b0), .rx_msg(128'b0), .rx_ready(1'b0),
    .wire_completed(local_out_completed), .idle(local_out_check_idle), .error(local_out_error)
  );
  D2DAdapterLinkMgmtTbSerialLinkChecker #(.CHECK_RX_ACCEPT(0)) peer_output_check (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(peer_raw_tx_valid), .tx_msg(peer_raw_tx_msg), .tx_ready(peer_raw_tx_ready),
    .serial_data(peer_serial_data), .serial_clock(peer_serial_clock),
    .rx_valid(1'b0), .rx_msg(128'b0), .rx_ready(1'b0),
    .wire_completed(peer_out_completed), .idle(peer_out_check_idle), .error(peer_out_error)
  );
  D2DAdapterLinkMgmtTbSerialLinkChecker local_input_check (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(local_bfm_send_valid), .tx_msg(local_bfm_send_msg), .tx_ready(local_bfm_send_ready),
    .serial_data(local_in_data), .serial_clock(local_in_clock),
    .rx_valid(local_raw_rx_valid), .rx_msg(local_raw_rx_msg), .rx_ready(local_raw_rx_ready),
    .wire_completed(local_in_completed), .idle(local_in_check_idle), .error(local_in_error)
  );
  D2DAdapterLinkMgmtTbSerialLinkChecker peer_input_check (
    .clock(clock), .reset_n(reset_n),
    .tx_valid(peer_bfm_send_valid), .tx_msg(peer_bfm_send_msg), .tx_ready(peer_bfm_send_ready),
    .serial_data(peer_in_data), .serial_clock(peer_in_clock),
    .rx_valid(peer_raw_rx_valid), .rx_msg(peer_raw_rx_msg), .rx_ready(peer_raw_rx_ready),
    .wire_completed(peer_in_completed), .idle(peer_in_check_idle), .error(peer_in_error)
  );

  // The peer receiver measures the local transmitter.
  D2DAdapterLinkMgmtTbValTrainResultModel #(
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (2),
    .WINDOW_RIGHT  (7)
  ) peer_rx_for_local_valtrain (
    .remote_tx_phase      (local_valtrain_phase),
    .local_result_info    (peer_valtrain_result_info),
    .local_result_payload (peer_valtrain_result_payload)
  );

  // The local receiver measures the peer transmitter.
  D2DAdapterLinkMgmtTbValTrainResultModel #(
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (9),
    .WINDOW_RIGHT  (13)
  ) local_rx_for_peer_valtrain (
    .remote_tx_phase      (peer_valtrain_phase),
    .local_result_info    (local_valtrain_result_info),
    .local_result_payload (local_valtrain_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter1ResultModel #(
    .UCIE_A                      (UCIE_A),
    .PI_CODE_WIDTH               (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH        (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI         (DESKEW_STEPS_PER_PI),
    .DESKEW_ADDED_DELAY_MOVES_UP (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .BASE_CENTER                 (6),
    .HALF_EYE_WIDTH              (2)
  ) peer_rx_for_local_train1 (
    .remote_tx_phase        (local_train1_phase),
    .remote_tx_deskew_codes (local_train1_deskew),
    .local_result_info      (peer_train1_result_info),
    .local_result_payload   (peer_train1_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter1ResultModel #(
    .UCIE_A                      (UCIE_A),
    .PI_CODE_WIDTH               (PI_CODE_WIDTH),
    .TX_DESKEW_CODE_WIDTH        (TX_DESKEW_CODE_WIDTH),
    .DESKEW_STEPS_PER_PI         (DESKEW_STEPS_PER_PI),
    .DESKEW_ADDED_DELAY_MOVES_UP (DESKEW_ADD_DELAY_INCREASES_PHASE),
    .BASE_CENTER                 (5),
    .HALF_EYE_WIDTH              (2)
  ) local_rx_for_peer_train1 (
    .remote_tx_phase        (peer_train1_phase),
    .remote_tx_deskew_codes (peer_train1_deskew),
    .local_result_info      (local_train1_result_info),
    .local_result_payload   (local_train1_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter2ResultModel #(
    .UCIE_A        (UCIE_A),
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (10),
    .WINDOW_RIGHT  (13)
  ) peer_rx_for_local_train2 (
    .remote_tx_phase      (local_train2_phase),
    .local_result_info    (peer_train2_result_info),
    .local_result_payload (peer_train2_result_payload)
  );

  D2DAdapterLinkMgmtTbDataTrainCenter2ResultModel #(
    .UCIE_A        (UCIE_A),
    .PI_CODE_WIDTH (PI_CODE_WIDTH),
    .WINDOW_LEFT   (4),
    .WINDOW_RIGHT  (7)
  ) local_rx_for_peer_train2 (
    .remote_tx_phase      (peer_train2_phase),
    .local_result_info    (local_train2_result_info),
    .local_result_payload (local_train2_result_payload)
  );

  D2DAdapterLinkMgmtLtsmDieBringUpModel #(
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
  ) local_die (
    .clock                    (clock),
    .reset_n                  (reset_n),
    .ltsm_start               (ltsm_start),
    .ltsm_stable_clk          (ltsm_stable_clk),
    .ltsm_pll_locked          (ltsm_pll_locked),
    .ltsm_stable_supply       (ltsm_stable_supply),
    .protocol_request_active  (1'b0),
    .external_fdi_control     (1'b1),
    .external_fdi_lp_state_req(fdi_lp_state_req),
    .external_fdi_lp_linkerror(fdi_lp_linkerror),
    .external_fdi_lp_rx_active_sts(fdi_lp_rx_active_sts),
    .external_fdi_lp_wake_req (fdi_lp_wake_req),
    .external_fdi_lp_clk_ack  (fdi_lp_clk_ack),
    .external_fdi_lp_stall_ack(fdi_lp_stall_ack),
    .cycles_1us               (cycles_1us),
    .sb_tx_enable             (1'b1),
    .sb_tx_dout               (local_serial_data),
    .sb_tx_clk                (local_serial_clock),
    .sb_tx_idle               (local_serial_idle),
    .sb_rx_din                (local_in_data),
    .sb_rx_clk                (local_in_clock),
    .sb_tx_valid              (local_raw_tx_valid),
    .sb_tx_msg                (local_raw_tx_msg),
    .sb_tx_ready              (local_raw_tx_ready),
    .sb_rx_valid              (local_raw_rx_valid),
    .sb_rx_msg                (local_raw_rx_msg),
    .sb_rx_ready              (local_raw_rx_ready),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo(local_valtrain_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload(local_valtrain_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo(local_train1_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload(local_train1_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo(local_train2_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload(local_train2_result_payload),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode(local_valtrain_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode(local_train1_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes(local_train1_deskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode(local_train2_phase),
    .ltsm_state               (local_ltsm_state),
    .fdi_pl_state_sts         (fdi_pl_state_sts),
    .fdi_pl_rx_active_req     (fdi_pl_rx_active_req),
    .fdi_pl_inband_pres       (fdi_pl_inband_pres),
    .fdi_pl_wake_ack          (fdi_pl_wake_ack),
    .fdi_pl_clk_req           (fdi_pl_clk_req),
    .fdi_pl_stall_req         (fdi_pl_stall_req),
    .debug_fdi_link_init_state(debug_fdi_link_init_state),
    .debug_rdi_state          (debug_rdi_state),
    .ltsm_dbg_mbinitSubstate  (local_mbinit_substate),
    .ltsm_dbg_mbtrainState    (local_mbtrain_state),
    .ltsm_dbg_mbtrainActiveSubstate(local_mbtrain_active_substate),
    .ltsm_dbg_flagTrainError  (local_ltsm_train_error),
    .debug_arb_grant_ltsm     (local_grant_ltsm),
    .debug_arb_grant_fdi      (local_grant_fdi),
    .debug_arb_grant_rdi      (local_grant_rdi),
    .debug_arb_tx_locked      (debug_arb_tx_locked),
    .debug_arb_tx_fire        (local_tx_fire),
    .debug_rx_drop_unknown    (local_unknown_drop),
    .debug_rx_fire            (local_rx_fire)
  );

  D2DAdapterLinkMgmtLtsmDieBringUpModel #(
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
  ) peer_die (
    .clock                    (clock),
    .reset_n                  (reset_n),
    .ltsm_start               (ltsm_start),
    .ltsm_stable_clk          (ltsm_stable_clk),
    .ltsm_pll_locked          (ltsm_pll_locked),
    .ltsm_stable_supply       (ltsm_stable_supply),
    .protocol_request_active  (1'b0),
    .external_fdi_control     (1'b0),
    .external_fdi_lp_state_req(UcieUPM_interfaces_pkg::PhyStateReq_nop),
    .external_fdi_lp_linkerror(1'b0),
    .external_fdi_lp_rx_active_sts(1'b0),
    .external_fdi_lp_wake_req (1'b0),
    .external_fdi_lp_clk_ack  (1'b0),
    .external_fdi_lp_stall_ack(1'b0),
    .cycles_1us               (cycles_1us),
    .sb_tx_enable             (1'b1),
    .sb_tx_dout               (peer_serial_data),
    .sb_tx_clk                (peer_serial_clock),
    .sb_tx_idle               (peer_serial_idle),
    .sb_rx_din                (peer_in_data),
    .sb_rx_clk                (peer_in_clock),
    .sb_tx_valid              (peer_raw_tx_valid),
    .sb_tx_msg                (peer_raw_tx_msg),
    .sb_tx_ready              (peer_raw_tx_ready),
    .sb_rx_valid              (peer_raw_rx_valid),
    .sb_rx_msg                (peer_raw_rx_msg),
    .sb_rx_ready              (peer_raw_rx_ready),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo(peer_valtrain_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload(peer_valtrain_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo(peer_train1_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload(peer_train1_result_payload),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo(peer_train2_result_info),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload(peer_train2_result_payload),
    .ltsm_flagToAnalog_d2cSender_valTrainCenter_txClockPhaseCode(peer_valtrain_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txClockPhaseCode(peer_train1_phase),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter1_txLaneDeskewCodes(peer_train1_deskew),
    .ltsm_flagToAnalog_d2cSender_dataTrainCenter2_txClockPhaseCode(peer_train2_phase),
    .ltsm_state               (peer_ltsm_state),
    .fdi_pl_state_sts         (peer_fdi_state),
    .fdi_pl_rx_active_req     (peer_fdi_rx_active_req),
    .fdi_pl_inband_pres       (peer_fdi_inband_pres),
    .fdi_pl_wake_ack          (peer_fdi_wake_ack),
    .fdi_pl_clk_req           (peer_fdi_clk_req),
    .fdi_pl_stall_req         (peer_fdi_stall_req),
    .debug_fdi_link_init_state(peer_fdi_init_state),
    .debug_rdi_state          (peer_rdi_state),
    .ltsm_dbg_mbinitSubstate  (peer_mbinit_substate),
    .ltsm_dbg_mbtrainState    (peer_mbtrain_state),
    .ltsm_dbg_mbtrainActiveSubstate(peer_mbtrain_active_substate),
    .ltsm_dbg_flagTrainError  (peer_ltsm_train_error),
    .debug_arb_grant_ltsm     (peer_grant_ltsm),
    .debug_arb_grant_fdi      (peer_grant_fdi),
    .debug_arb_grant_rdi      (peer_grant_rdi),
    .debug_arb_tx_locked      (peer_tx_locked),
    .debug_arb_tx_fire        (peer_tx_fire),
    .debug_rx_drop_unknown    (peer_unknown_drop),
    .debug_rx_fire            (peer_rx_fire)
  );
endmodule

`default_nettype wire
