// Hand-translated synthesizable SystemVerilog.
// Source: D2DAdapterLinkMgmtTop(7).scala
// This is the integrated FDI + RDI + three-client sideband-arbiter wrapper.
// Reset convention: asynchronous active-low reset_n is passed to every child module.

`default_nettype none

module D2DAdapterLinkMgmtTop #(
  parameter int unsigned FDI_WIDTH         = UcieUPM_fdi_params_pkg::FDI_WIDTH,
  parameter int unsigned FDI_DLLP_WIDTH    = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH,
  parameter int unsigned FDI_SB_WIDTH      = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH,
  parameter int unsigned RDI_WIDTH         = UcieUPM_rdi_params_pkg::RDI_WIDTH,
  parameter int unsigned RDI_SB_WIDTH      = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH,
  parameter int unsigned SB_NODE_MSG_WIDTH = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH
) (
  input wire logic clock,
  input wire logic reset_n,

  // Protocol-facing FDI side.
  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input  wire logic                                  fdi_lp_linkerror,
  input  wire logic                                  fdi_lp_rx_active_sts,
  input  wire logic                                  fdi_lp_wake_req,
  input  wire logic                                  fdi_lp_clk_ack,
  input  wire logic                                  fdi_lp_stall_ack,

  output var UcieUPM_interfaces_pkg::PhyState_t fdi_pl_state_sts,
  output var logic                               fdi_pl_rx_active_req,
  output var logic                               fdi_pl_inband_pres,
  output var logic                               fdi_pl_wake_ack,
  output var logic                               fdi_pl_clk_req,
  output var logic                               fdi_pl_stall_req,

  // LTSM / PHY-facing control side from RDI.
  input  wire logic ltsm_lp_wake_req,
  output var logic ltsm_pl_wake_ack,
  input  wire logic ltsm_lp_clk_ack,
  output var logic ltsm_pl_clk_req,
  input  wire logic ltsm_pl_inband_pres,

  // External LTSM sideband-message producer and sink.
  input  wire logic         ltsm_sb_tx_valid,
  input  wire logic [127:0] ltsm_sb_tx_msg,
  output var logic         ltsm_sb_tx_ready,

  output var logic         ltsm_sb_rx_valid,
  output var logic [127:0] ltsm_sb_rx_msg,
  input  wire logic         ltsm_sb_rx_ready,

  // Shared abstract 128-bit sideband-message transport.
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_msg,
  input  wire logic         sb_tx_ready,

  input  wire logic         sb_rx_valid,
  input  wire logic [127:0] sb_rx_msg,
  output var logic         sb_rx_ready,

  input  wire logic [31:0] cycles_1us,

  // Debug / waveform visibility.
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t debug_fdi_link_init_state,
  output var UcieUPM_interfaces_pkg::PhyState_t      debug_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t   debug_fdi_to_rdi_state_req,

  output var logic       debug_arb_grant_ltsm,
  output var logic       debug_arb_grant_fdi,
  output var logic       debug_arb_grant_rdi,
  output var logic       debug_arb_tx_locked,
  output var logic [1:0] debug_arb_rr_last_source,
  output var logic       debug_arb_rr_last_rdi,
  output var logic       debug_arb_tx_fire,

  output var logic debug_rx_route_ltsm,
  output var logic debug_rx_route_fdi,
  output var logic debug_rx_route_rdi,
  output var logic debug_rx_drop_unknown,
  output var logic debug_rx_fire
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

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
    .cycles_1us           (cycles_1us)
  );

  RdiLinkManagementController rdi (
    .clock                (clock),
    .reset_n              (reset_n),

    .ltsm_lp_wake_req     (ltsm_lp_wake_req),
    .ltsm_pl_wake_ack     (ltsm_pl_wake_ack),
    .ltsm_pl_clk_req      (ltsm_pl_clk_req),
    .ltsm_lp_clk_ack      (ltsm_lp_clk_ack),

    .lp_state_req         (fdi_rdi_lp_state_req),
    .pl_state_sts         (rdi_pl_state_sts_int),
    .pl_stallreq          (rdi_pl_stall_req_int),
    .lp_stallack          (fdi_rdi_lp_stall_ack),
    .rdi_pl_inband_pres   (rdi_pl_inband_pres_int),
    .ltsm_pl_inband_pres  (ltsm_pl_inband_pres),

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
    .cycles_1us           (cycles_1us)
  );

  LinkMgmtSidebandPacketArbiter arb (
    .clock                 (clock),
    .reset_n               (reset_n),

    .ltsm_tx_valid         (ltsm_sb_tx_valid),
    .ltsm_tx_msg           (ltsm_sb_tx_msg),
    .ltsm_tx_ready         (ltsm_sb_tx_ready),

    .fdi_tx_valid          (fdi_sb_snd_valid),
    .fdi_tx_msg            (fdi_sb_snd_msg),
    .fdi_tx_ready          (fdi_sb_snd_ready),

    .rdi_tx_valid          (rdi_sb_snd_valid),
    .rdi_tx_msg            (rdi_sb_snd_msg),
    .rdi_tx_ready          (rdi_sb_snd_ready),

    .tx_out_valid          (sb_tx_valid),
    .tx_out_msg            (sb_tx_msg),
    .tx_out_ready          (sb_tx_ready),

    .rx_in_valid           (sb_rx_valid),
    .rx_in_msg             (sb_rx_msg),
    .rx_in_ready           (sb_rx_ready),

    .ltsm_rx_valid         (ltsm_sb_rx_valid),
    .ltsm_rx_msg           (ltsm_sb_rx_msg),
    .ltsm_rx_ready         (ltsm_sb_rx_ready),

    .fdi_rx_valid          (fdi_sb_rcv_valid),
    .fdi_rx_msg            (fdi_sb_rcv_msg),
    .fdi_rx_ready          (fdi_sb_rcv_ready),

    .rdi_rx_valid          (rdi_sb_rcv_valid),
    .rdi_rx_msg            (rdi_sb_rcv_msg),
    .rdi_rx_ready          (rdi_sb_rcv_ready),

    .grant_ltsm            (debug_arb_grant_ltsm),
    .grant_fdi             (debug_arb_grant_fdi),
    .grant_rdi             (debug_arb_grant_rdi),
    .tx_locked             (debug_arb_tx_locked),
    .rr_last_source        (debug_arb_rr_last_source),
    .rr_last_granted_rdi   (debug_arb_rr_last_rdi),
    .tx_fire               (debug_arb_tx_fire),

    .rx_route_ltsm         (debug_rx_route_ltsm),
    .rx_route_fdi          (debug_rx_route_fdi),
    .rx_route_rdi          (debug_rx_route_rdi),
    .rx_drop_unknown       (debug_rx_drop_unknown),
    .rx_fire               (debug_rx_fire)
  );

  assign debug_rdi_state            = rdi_pl_state_sts_int;
  assign debug_fdi_to_rdi_state_req = fdi_rdi_lp_state_req;
endmodule

`default_nettype wire
