// Hand-translated synthesizable SystemVerilog.
// Source: LinkMgmtSidebandPacketArbiter(7).scala
// Original Chisel signal/register names are retained wherever
// SystemVerilog scoping permits.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LinkMgmtSidebandPacketArbiter (
  input wire logic         clock,
  input wire logic         reset_n,

  // LTSM TX producer -> arbiter.
  input wire logic         ltsm_tx_valid,
  input wire logic [127:0] ltsm_tx_msg,
  output var logic         ltsm_tx_ready,

  // FDI TX producer -> arbiter.
  input wire logic         fdi_tx_valid,
  input wire logic [127:0] fdi_tx_msg,
  output var logic         fdi_tx_ready,

  // RDI TX producer -> arbiter.
  input wire logic         rdi_tx_valid,
  input wire logic [127:0] rdi_tx_msg,
  output var logic         rdi_tx_ready,

  // Arbiter TX output -> shared sideband transport.
  output var logic         tx_out_valid,
  output var logic [127:0] tx_out_msg,
  input wire logic         tx_out_ready,

  // Shared sideband transport -> arbiter RX input.
  input wire logic         rx_in_valid,
  input wire logic [127:0] rx_in_msg,
  output var logic         rx_in_ready,

  // Arbiter -> LTSM RX sink.
  output var logic         ltsm_rx_valid,
  output var logic [127:0] ltsm_rx_msg,
  input wire logic         ltsm_rx_ready,

  // Arbiter -> FDI RX sink.
  output var logic         fdi_rx_valid,
  output var logic [127:0] fdi_rx_msg,
  input wire logic         fdi_rx_ready,

  // Arbiter -> RDI RX sink.
  output var logic         rdi_rx_valid,
  output var logic [127:0] rdi_rx_msg,
  input wire logic         rdi_rx_ready,

  // Debug / waveform visibility.
  output var logic         grant_ltsm,
  output var logic         grant_fdi,
  output var logic         grant_rdi,
  output var logic         tx_locked,
  output var logic [1:0]   rr_last_source,
  output var logic         rr_last_granted_rdi,
  output var logic         tx_fire,

  output var logic         rx_route_ltsm,
  output var logic         rx_route_fdi,
  output var logic         rx_route_rdi,
  output var logic         rx_drop_unknown,
  output var logic         rx_fire
);

  import SidebandMsgGenerator_pkg::*;

  localparam logic [1:0] SourceLtsm = 2'd0;
  localparam logic [1:0] SourceFdi  = 2'd1;
  localparam logic [1:0] SourceRdi  = 2'd2;

  // --------------------------------------------------------------------------
  // TX arbitration
  // --------------------------------------------------------------------------

  (* keep = "true" *) logic [1:0] rrLastSource;
  (* keep = "true" *) logic       txGrantLocked;
  (* keep = "true" *) logic [1:0] txLockedSource;

  logic [7:0] rdiTxMsgSub;
  logic       rdiTxIsLinkError;

  logic newGrantLtsm;
  logic newGrantFdi;
  logic newGrantRdi;

  logic grantLtsm;
  logic grantFdi;
  logic grantRdi;
  logic txFire;

  assign rdiTxMsgSub = UCIe2_Field_msgSub(rdi_tx_msg);

  assign rdiTxIsLinkError =
    rdi_tx_valid &&
    UCIe2_isRdiLinkMgmt(rdi_tx_msg) &&
    (rdiTxMsgSub == UCIe2_LinkMgmtSubCode_LINKERROR);

  always_comb begin
    newGrantLtsm = 1'b0;
    newGrantFdi  = 1'b0;
    newGrantRdi  = 1'b0;

    if (rdiTxIsLinkError) begin
      // Link-error traffic has priority over normal arbitration.
      newGrantRdi = 1'b1;
    end else begin
      // Start with the source after the most recently completed grant.
      case (rrLastSource)
        SourceLtsm: begin
          if (fdi_tx_valid)
            newGrantFdi = 1'b1;
          else if (rdi_tx_valid)
            newGrantRdi = 1'b1;
          else if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
        end

        SourceFdi: begin
          if (rdi_tx_valid)
            newGrantRdi = 1'b1;
          else if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
          else if (fdi_tx_valid)
            newGrantFdi = 1'b1;
        end

        SourceRdi: begin
          if (ltsm_tx_valid)
            newGrantLtsm = 1'b1;
          else if (fdi_tx_valid)
            newGrantFdi = 1'b1;
          else if (rdi_tx_valid)
            newGrantRdi = 1'b1;
        end

        default: begin
          // Unreachable for legal state values.
          // Retain the all-zero defaults.
        end
      endcase
    end
  end

  always_comb begin
    grantLtsm = txGrantLocked ? (txLockedSource == SourceLtsm) : newGrantLtsm;
    grantFdi  = txGrantLocked ? (txLockedSource == SourceFdi)  : newGrantFdi;
    grantRdi  = txGrantLocked ? (txLockedSource == SourceRdi)  : newGrantRdi;

    tx_out_valid = (grantLtsm && ltsm_tx_valid) ||
      (grantFdi  && fdi_tx_valid)  ||
      (grantRdi  && rdi_tx_valid);

    tx_out_msg = 128'b0;

    if (grantLtsm)
      tx_out_msg = ltsm_tx_msg;
    else if (grantFdi)
      tx_out_msg = fdi_tx_msg;
    else if (grantRdi)
      tx_out_msg = rdi_tx_msg;
  end

  assign ltsm_tx_ready = tx_out_ready && grantLtsm;
  assign fdi_tx_ready  = tx_out_ready && grantFdi;
  assign rdi_tx_ready  = tx_out_ready && grantRdi;

  assign txFire = tx_out_valid && tx_out_ready;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      rrLastSource   <= SourceRdi;
      txGrantLocked  <= 1'b0;
      txLockedSource <= SourceLtsm;
    end else begin
      if (!txGrantLocked && tx_out_valid && !tx_out_ready) begin
        // Hold the selected producer while the output is stalled.
        txGrantLocked <= 1'b1;

        if (grantLtsm)
          txLockedSource <= SourceLtsm;
        else if (grantFdi)
          txLockedSource <= SourceFdi;
        else
          txLockedSource <= SourceRdi;
      end else if (txGrantLocked && txFire) begin
        // Release the lock after the transaction is accepted.
        txGrantLocked <= 1'b0;
      end else if (txGrantLocked && !tx_out_valid) begin
        // Defensive recovery if a producer violates valid-hold semantics.
        txGrantLocked <= 1'b0;
      end

      if (txFire) begin
        if (grantLtsm)
          rrLastSource <= SourceLtsm;
        else if (grantFdi)
          rrLastSource <= SourceFdi;
        else if (grantRdi)
          rrLastSource <= SourceRdi;
      end
    end
  end

  assign grant_ltsm          = grantLtsm && ltsm_tx_valid;
  assign grant_fdi           = grantFdi  && fdi_tx_valid;
  assign grant_rdi           = grantRdi  && rdi_tx_valid;
  assign tx_locked           = txGrantLocked;
  assign rr_last_source      = rrLastSource;
  assign rr_last_granted_rdi = (rrLastSource == SourceRdi);
assign tx_fire             = txFire;

  // RX uses valid/ready transactions. A held word remains visible to its
  // destination until the destination accepts it; a source may present another
  // word immediately after a handshake without dropping valid.
  UCIe2_Route_t rxRoute;
  logic routeToLtsm;
  logic routeToFdi;
  logic routeToRdi;
  logic dropUnknown;
  logic selectedSinkReady;

  assign rxRoute = UCIe2_route(rx_in_msg);
  assign routeToLtsm = (rxRoute == UCIe2_Route_LTSM);
  assign routeToFdi = (rxRoute == UCIe2_Route_ADAPTER0) ||
                     (rxRoute == UCIe2_Route_ADAPTER1) ||
                     (rxRoute == UCIe2_Route_D2D_COMMON);
  assign routeToRdi = (rxRoute == UCIe2_Route_RDI);
  assign dropUnknown = !routeToLtsm && !routeToFdi && !routeToRdi;

  assign ltsm_rx_valid = rx_in_valid && routeToLtsm;
  assign ltsm_rx_msg = rx_in_msg;
  assign fdi_rx_valid = rx_in_valid && routeToFdi;
  assign fdi_rx_msg = rx_in_msg;
  assign rdi_rx_valid = rx_in_valid && routeToRdi;
  assign rdi_rx_msg = rx_in_msg;

  assign selectedSinkReady = (routeToLtsm && ltsm_rx_ready) ||
                             (routeToFdi && fdi_rx_ready) ||
                             (routeToRdi && rdi_rx_ready) || dropUnknown;
  assign rx_in_ready = !rx_in_valid || selectedSinkReady;
  assign rx_fire = rx_in_valid && rx_in_ready;
  assign rx_route_ltsm = rx_fire && routeToLtsm;
  assign rx_route_fdi = rx_fire && routeToFdi;
  assign rx_route_rdi = rx_fire && routeToRdi;
  assign rx_drop_unknown = rx_fire && dropUnknown;
endmodule

`default_nettype wire
