`default_nettype none

// ============================================================================
// SidebandWrapper
// Complete sideband path of the UCIe D2D adapter: the three sideband clients
// (ltsm, fdi, rdi) on one side, the serial sideband pins on the other.
//
// What was done:
//   The sideband modules and glue logic that used to sit directly in
//   UcieDigitalCore were moved here unchanged, so the top only
//   instantiates the clients and this wrapper. Moved pieces:
//     ltsmTxCapture  LtsmSidebandTxCapture          Queue: ltsm pulse TX -> arb.
//     ltsmRxPulse    LtsmSidebandRxPulseAdapter     arb valid/ready RX -> ltsm pulse RX.
//     arb            LinkMgmtSidebandPacketArbiter  Merges ltsm/fdi/rdi TX messages into
//                                                   one stream; routes RX messages back.
//     (always_ff)    RX holding register            u_sideband_phy pulse RX -> arb
//                                                   valid/ready; sticky debug_sb_rx_overflow.
//     u_sideband_phy SideBandModule                 128-bit messages <-> serial sb_* pins.
//   Behaviour is identical to the previous in-top version. The only
//   additions are the LTSM_TX_CAPTURE_ENTRIES parameter (was hardcoded to 4)
//   and the arbiter round-robin debug outputs, now exposed as ports.
//
// Sideband message path:
//   TX: ltsm_tx_* -> ltsmTxCapture -+
//       fdi_tx_*  ------------------+-> arb -> u_sideband_phy -> sb_tx_dout / sb_tx_clk
//       rdi_tx_*  ------------------+
//   RX: sb_rx_din / sb_rx_clk -> u_sideband_phy -> RX holding reg -> arb
//       arb -> ltsmRxPulse -> ltsm_rx_*,  arb -> fdi_rx_*,  arb -> rdi_rx_*
//
// Ports (grouped by the module they connect to outside the wrapper, and the
// internal module that drives or consumes them):
//   Clock and reset
//     clock, reset_n            To every internal module. reset_n is also
//                               inverted into SideBandModule.rxReset.
//   LTSM client  (LinkTrainingFSM, pulse interface, no RX ready)
//     ltsm_tx_valid/msg/ready   <-> LinkTrainingFSM.sb_tx_valid/din/ready;
//                               internally ltsmTxCapture.raw_*.
//     ltsm_rx_valid/msg         --> LinkTrainingFSM.sb_rx_valid/dout;
//                               internally ltsmRxPulse.out_*.
//   FDI client   (LinkManagementController, valid/ready)
//     fdi_tx_valid/msg/ready    <-> LinkManagementController.sb_snd_*;
//                               internally arb.fdi_tx_*.
//     fdi_rx_valid/msg/ready    <-> LinkManagementController.sb_rcv_*;
//                               internally arb.fdi_rx_*.
//   RDI client   (RdiLinkManagementController, valid/ready)
//     rdi_tx_valid/msg/ready    <-> RdiLinkManagementController.sb_snd_*;
//                               internally arb.rdi_tx_*.
//     rdi_rx_valid/msg/ready    <-> RdiLinkManagementController.sb_rcv_*;
//                               internally arb.rdi_rx_*.
//   Serial sideband pins  (remote die)
//     sb_tx_dout, sb_tx_clk     From u_sideband_phy.tx_dout/tx_clk.
//     sb_rx_din, sb_rx_clk      To u_sideband_phy.rx_din/rx_clk.
//   Debug
//     debug_arb_grant_ltsm/fdi/rdi, debug_arb_tx_locked,
//     debug_arb_rr_last_source, debug_arb_rr_last_granted_rdi,
//     debug_arb_tx_fire         From arb TX-side status (grant_*, tx_locked,
//                               rr_last_source, rr_last_granted_rdi, tx_fire).
//     debug_rx_route_ltsm/fdi/rdi, debug_rx_drop_unknown,
//     debug_rx_fire             From arb RX-side status (rx_route_*,
//                               rx_drop_unknown, rx_fire).
//     debug_sb_rx_overflow      From the RX holding register. Sticky until
//                               reset: a PHY message arrived while the
//                               holding register was still full.
// ============================================================================

module SidebandWrapper #(
  parameter int unsigned SB_TX_FIFO_ENTRIES      = 4,
  parameter int unsigned LTSM_TX_CAPTURE_ENTRIES = 4
) (
  // ==========================================================================
  // CLOCK AND RESET
  // ==========================================================================
  input  wire logic         clock,
  input  wire logic         reset_n,

  // ==========================================================================
  // LTSM CLIENT (LinkTrainingFSM pulse interface)
  // ==========================================================================
  input  wire logic         ltsm_tx_valid,
  input  wire logic [127:0] ltsm_tx_msg,
  output var  logic         ltsm_tx_ready,
  output var  logic         ltsm_rx_valid,
  output var  logic [127:0] ltsm_rx_msg,

  // ==========================================================================
  // FDI CLIENT (LinkManagementController valid/ready)
  // ==========================================================================
  input  wire logic         fdi_tx_valid,
  input  wire logic [127:0] fdi_tx_msg,
  output var  logic         fdi_tx_ready,
  output var  logic         fdi_rx_valid,
  output var  logic [127:0] fdi_rx_msg,
  input  wire logic         fdi_rx_ready,

  // ==========================================================================
  // RDI CLIENT (RdiLinkManagementController valid/ready)
  // ==========================================================================
  input  wire logic         rdi_tx_valid,
  input  wire logic [127:0] rdi_tx_msg,
  output var  logic         rdi_tx_ready,
  output var  logic         rdi_rx_valid,
  output var  logic [127:0] rdi_rx_msg,
  input  wire logic         rdi_rx_ready,

  // ==========================================================================
  // SERIAL SIDEBAND PINS (remote die)
  // ==========================================================================
  output var  logic         sb_tx_dout,
  output var  logic         sb_tx_clk,
  input  wire logic         sb_rx_din,
  input  wire logic         sb_rx_clk,

  // ==========================================================================
  // DEBUG
  // ==========================================================================
  output var  logic         debug_arb_grant_ltsm,
  output var  logic         debug_arb_grant_fdi,
  output var  logic         debug_arb_grant_rdi,
  output var  logic         debug_arb_tx_locked,
  output var  logic [1:0]   debug_arb_rr_last_source,
  output var  logic         debug_arb_rr_last_granted_rdi,
  output var  logic         debug_arb_tx_fire,
  output var  logic         debug_rx_route_ltsm,
  output var  logic         debug_rx_route_fdi,
  output var  logic         debug_rx_route_rdi,
  output var  logic         debug_rx_drop_unknown,
  output var  logic         debug_rx_fire,
  // Sideband receive-buffer status. Sticky until reset.
  output var  logic         debug_sb_rx_overflow
);

  // --------------------------------------------------------------------------
  // Internal nets
  // --------------------------------------------------------------------------
  // ltsmTxCapture -> arb.
  wire logic         ltsm_queue_tx_valid;
  wire logic [127:0] ltsm_queue_tx_msg;
  wire logic         ltsm_queue_tx_ready;

  // arb -> ltsmRxPulse.
  wire logic         ltsm_stream_rx_valid;
  wire logic [127:0] ltsm_stream_rx_msg;
  wire logic         ltsm_stream_rx_ready;

  // Arbiter <-> sideband PHY (message level).
  logic         sb_msg_tx_valid;
  logic [127:0] sb_msg_tx_msg;
  logic         sb_msg_tx_ready;
  logic         sb_phy_rx_valid;
  logic [127:0] sb_phy_rx_msg;
  logic         sb_msg_rx_valid;
  logic [127:0] sb_msg_rx_msg;
  logic         sb_msg_rx_ready;

  // --------------------------------------------------------------------------
  // LTSM sideband adapters
  // --------------------------------------------------------------------------
  LtsmSidebandTxCapture #(
    .ENTRIES (LTSM_TX_CAPTURE_ENTRIES)
  ) ltsmTxCapture (
    .clock     (clock),
    .reset_n   (reset_n),
    .raw_valid (ltsm_tx_valid),
    .raw_msg   (ltsm_tx_msg),
    .raw_ready (ltsm_tx_ready),
    .out_valid (ltsm_queue_tx_valid),
    .out_msg   (ltsm_queue_tx_msg),
    .out_ready (ltsm_queue_tx_ready)
  );

  LtsmSidebandRxPulseAdapter ltsmRxPulse (
    .clock     (clock),
    .reset_n   (reset_n),
    .in_valid  (ltsm_stream_rx_valid),
    .in_msg    (ltsm_stream_rx_msg),
    .in_ready  (ltsm_stream_rx_ready),
    .out_valid (ltsm_rx_valid),
    .out_msg   (ltsm_rx_msg)
  );

  // --------------------------------------------------------------------------
  // Sideband packet arbiter (ltsm / fdi / rdi <-> one message stream)
  // --------------------------------------------------------------------------
  LinkMgmtSidebandPacketArbiter arb (
    .clock                 (clock),
    .reset_n               (reset_n),

    .ltsm_tx_valid         (ltsm_queue_tx_valid),
    .ltsm_tx_msg           (ltsm_queue_tx_msg),
    .ltsm_tx_ready         (ltsm_queue_tx_ready),

    .fdi_tx_valid          (fdi_tx_valid),
    .fdi_tx_msg            (fdi_tx_msg),
    .fdi_tx_ready          (fdi_tx_ready),

    .rdi_tx_valid          (rdi_tx_valid),
    .rdi_tx_msg            (rdi_tx_msg),
    .rdi_tx_ready          (rdi_tx_ready),

    .tx_out_valid          (sb_msg_tx_valid),
    .tx_out_msg            (sb_msg_tx_msg),
    .tx_out_ready          (sb_msg_tx_ready),

    .rx_in_valid           (sb_msg_rx_valid),
    .rx_in_msg             (sb_msg_rx_msg),
    .rx_in_ready           (sb_msg_rx_ready),

    .ltsm_rx_valid         (ltsm_stream_rx_valid),
    .ltsm_rx_msg           (ltsm_stream_rx_msg),
    .ltsm_rx_ready         (ltsm_stream_rx_ready),

    .fdi_rx_valid          (fdi_rx_valid),
    .fdi_rx_msg            (fdi_rx_msg),
    .fdi_rx_ready          (fdi_rx_ready),

    .rdi_rx_valid          (rdi_rx_valid),
    .rdi_rx_msg            (rdi_rx_msg),
    .rdi_rx_ready          (rdi_rx_ready),

    .grant_ltsm            (debug_arb_grant_ltsm),
    .grant_fdi             (debug_arb_grant_fdi),
    .grant_rdi             (debug_arb_grant_rdi),
    .tx_locked             (debug_arb_tx_locked),
    .rr_last_source        (debug_arb_rr_last_source),
    .rr_last_granted_rdi   (debug_arb_rr_last_granted_rdi),
    .tx_fire               (debug_arb_tx_fire),

    .rx_route_ltsm         (debug_rx_route_ltsm),
    .rx_route_fdi          (debug_rx_route_fdi),
    .rx_route_rdi          (debug_rx_route_rdi),
    .rx_drop_unknown       (debug_rx_drop_unknown),
    .rx_fire               (debug_rx_fire)
  );

  // --------------------------------------------------------------------------
  // Sideband PHY
  // --------------------------------------------------------------------------
  // One-entry holding register converts the pulse-only PHY RX interface into
  // a valid/ready interface. This prevents loss when the integrated top stalls.
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sb_msg_rx_valid      <= 1'b0;
      sb_msg_rx_msg        <= 128'b0;
      debug_sb_rx_overflow <= 1'b0;
    end else begin
      if (sb_phy_rx_valid) begin
        if (!sb_msg_rx_valid || sb_msg_rx_ready) begin
          sb_msg_rx_msg   <= sb_phy_rx_msg;
          sb_msg_rx_valid <= 1'b1;
        end else begin
          debug_sb_rx_overflow <= 1'b1;
        end
      end else if (sb_msg_rx_valid && sb_msg_rx_ready) begin
        sb_msg_rx_valid <= 1'b0;
      end
    end
  end

  SideBandModule #(
    .TX_FIFO_ENTRIES (SB_TX_FIFO_ENTRIES)
  ) u_sideband_phy (
    .clock    (clock),
    .reset_n  (reset_n),
    .tx_din   (sb_msg_tx_msg),
    .tx_valid (sb_msg_tx_valid),
    .tx_ready (sb_msg_tx_ready),
    .tx_dout  (sb_tx_dout),
    .tx_clk   (sb_tx_clk),
    .rx_dout  (sb_phy_rx_msg),
    .rx_valid (sb_phy_rx_valid),
    .rxReset  (!reset_n),
    .rx_din   (sb_rx_din),
    .rx_clk   (sb_rx_clk)
  );

endmodule

`default_nettype wire
