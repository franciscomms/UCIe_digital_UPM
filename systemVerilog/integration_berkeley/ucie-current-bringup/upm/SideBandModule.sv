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

  // SidebandRx remains entirely in the incoming-clock domain.
  // ~rx_clk means serial data is sampled on the falling edge of rx_clk.
  SidebandRx rx (
    .clock            (~rx_clk),
    .reset            (rxReset),
    .din              (rx_din),
    .dout             (rxDoutAsync),
    .valid            (rxValidAsync),
    .dbg_shiftReg     (),
    .dbg_bitCount     (),
    .dbg_prevBitCount ()
  );

  // The CDC is centralized here. Every module connected to SideBandModule's
  // rx_dout/rx_valid ports sees signals synchronous to the main clock.
  SidebandRxCdc #(
    .DATA_WIDTH (128)
  ) rx_cdc (
    .src_clock  (~rx_clk),
    .src_reset  (rxReset),
    .src_data   (rxDoutAsync),
    .src_valid  (rxValidAsync),
    .dst_clock  (clock),
    .dst_reset_n(reset_n),
    .dst_data   (rx_dout),
    .dst_valid  (rx_valid)
  );

endmodule
