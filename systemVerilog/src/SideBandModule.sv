`default_nettype none
module SideBandModule #(
  parameter int unsigned TX_FIFO_ENTRIES = 4
) (
  input  wire logic         clock,
  input  wire logic         reset_n,
  input  wire logic [127:0] tx_din,
  input  wire logic         tx_valid,
  output var  logic         tx_ready,
  output var  logic         tx_dout,
  output var  logic         tx_clk,
  output var  logic [127:0] rx_dout,
  output var  logic         rx_valid,
  input  wire logic         rxReset,
  input  wire logic         rx_din,
  input  wire logic         rx_clk
);
  localparam int unsigned PTR_W = (TX_FIFO_ENTRIES <= 2) ? 1 : $clog2(TX_FIFO_ENTRIES);
  localparam int unsigned CNT_W = $clog2(TX_FIFO_ENTRIES + 1);

  logic [127:0] txFifo [0:TX_FIFO_ENTRIES-1];
  logic [PTR_W-1:0] txWritePtr;
  logic [PTR_W-1:0] txReadPtr;
  logic [CNT_W-1:0] txCount;
  logic txEnqueue;
  logic txDequeue;
  logic txInternalReady;
  logic [127:0] txFifoDout;

  logic [127:0] rxDoutAsync;
  logic         rxValidAsync;
  logic         rxCompletionToggle;
  wire logic    rxCdcReset = rxReset || !reset_n;

  (* ASYNC_REG = "TRUE" *) logic rxEventSync1;
  (* ASYNC_REG = "TRUE" *) logic rxEventSync2;
  (* ASYNC_REG = "TRUE" *) logic rxEventSync3;
  logic rxEventSeen;

  assign tx_ready       = (txCount < TX_FIFO_ENTRIES);
  assign txFifoDout     = txFifo[txReadPtr];
  assign txEnqueue      = tx_valid && tx_ready;
  assign txDequeue      = (txCount != 0) && txInternalReady;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      txWritePtr <= '0;
      txReadPtr  <= '0;
      txCount    <= '0;
    end else begin
      if (txEnqueue) begin
        txFifo[txWritePtr] <= tx_din;
        txWritePtr <= (txWritePtr == TX_FIFO_ENTRIES-1) ? '0 : txWritePtr + 1'b1;
      end
      if (txDequeue)
        txReadPtr <= (txReadPtr == TX_FIFO_ENTRIES-1) ? '0 : txReadPtr + 1'b1;

      case ({txEnqueue, txDequeue})
        2'b10: txCount <= txCount + 1'b1;
        2'b01: txCount <= txCount - 1'b1;
        default: txCount <= txCount;
      endcase
    end
  end

  SidebandTx tx (
    .clock              (clock),
    .reset_n            (reset_n),
    .din                (txFifoDout),
    .valid              (txCount != 0),
    .ready              (txInternalReady),
    .dout               (tx_dout),
    .clk_out            (tx_clk),
    .dbg_state          (),
    .dbg_shiftReg       (),
    .dbg_payloadReg     (),
    .dbg_bitsLeft       (),
    .dbg_gapCount       (),
    .dbg_payloadPending ()
  );

  // The receiver samples the falling edge of the forwarded clock. Its data
  // register and completion toggle update together on the final bit, before
  // the forwarded clock stops. Do not re-register its valid in this domain:
  // doing so would require a sampling edge from the next packet.
  SidebandRx rx (
    .clock            (~rx_clk),
    .reset            (rxCdcReset),
    .din              (rx_din),
    .dout             (rxDoutAsync),
    .valid            (rxValidAsync),
    .dbg_shiftReg     (),
    .dbg_bitCount     (),
    .dbg_prevBitCount (),
    .completion_toggle(rxCompletionToggle)
  );

  // Bundled-data CDC: the receiver holds rxDoutAsync until the next complete
  // message. Only the event passes through synchronizer flops. The controller
  // captures the held bus after three stages, then emits exactly one pulse.
  // Contract: consecutive message completions must be at least six controller
  // clock periods apart, and the controller clock must keep running. Serial
  // words and gaps alone do not guarantee this for arbitrary clock ratios.
  // Constrain the held-data path to settle before the event is consumed.
  // The existing receive interface has no ready input: its consumer must be
  // able to accept the rx_valid pulse.
  //
  // Either reset flushes the partial frame, held message and event history in
  // both domains, avoiding replay/spurious events after a one-sided reset.
  // Release reset before the first serial edge, meeting recovery/removal;
  // do not consume initial packet bits to clock a receive reset synchronizer.
  always_ff @(posedge clock or posedge rxCdcReset) begin
    if (rxCdcReset) begin
      rxEventSync1 <= 1'b0;
      rxEventSync2 <= 1'b0;
      rxEventSync3 <= 1'b0;
      rxEventSeen  <= 1'b0;
      rx_dout      <= 128'b0;
      rx_valid     <= 1'b0;
    end else begin
      rxEventSync1 <= rxCompletionToggle;
      rxEventSync2 <= rxEventSync1;
      rxEventSync3 <= rxEventSync2;
      rxEventSeen  <= rxEventSync3;
      rx_valid    <= 1'b0;
      if (rxEventSync3 != rxEventSeen) begin
        rx_dout  <= rxDoutAsync;
        rx_valid <= 1'b1;
      end
    end
  end
endmodule
`default_nettype wire
