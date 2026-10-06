// Testbench endpoint: complete messages are driven through the production
// SidebandTx and decoded independently from the one-bit pins.  The packet
// ports belong only to the stimulus/scoreboard, never to a DUT connection.
`timescale 1ns/1ps
`default_nettype none
module D2DAdapterLinkMgmtTbSerialBfm #(
  parameter int unsigned QUEUE_DEPTH = 256
) (
  input wire logic clock, reset_n,
  input wire logic send_valid,
  input wire logic [127:0] send_msg,
  output wire logic send_ready,
  output wire logic tx_data, tx_clock,
  input wire logic rx_data, rx_clock,
  output wire logic received_valid,
  output wire logic [127:0] received_msg,
  input wire logic received_ready,
  output wire logic idle
);
  logic [127:0] received_queue [0:QUEUE_DEPTH-1];
  integer unsigned write_count, read_count;
  integer unsigned bit_index;
  logic [63:0] word, saved_header;
  logic waiting_payload;

  SidebandTx tx (
    .clock(clock), .reset_n(reset_n),
    .din(send_msg), .valid(send_valid), .ready(send_ready),
    .dout(tx_data), .clk_out(tx_clock),
    .dbg_state(), .dbg_shiftReg(), .dbg_payloadReg(),
    .dbg_bitsLeft(), .dbg_gapCount(), .dbg_payloadPending()
  );

  assign received_valid = (write_count != read_count);
  assign received_msg = received_valid ? received_queue[read_count % QUEUE_DEPTH] : 128'b0;
  assign idle = send_ready && !received_valid && (bit_index == 0) && !waiting_payload;

  always @(posedge clock or negedge reset_n) begin
    if (!reset_n) read_count <= 0;
    else if (received_valid && received_ready) read_count <= read_count + 1;
  end

  // Sample the source-synchronous data at the falling edge, after the
  // serializer has launched it on the rising edge.  Decode LSB first.
  always @(negedge rx_clock or negedge reset_n) begin
    if (!reset_n) begin
      write_count = 0;
      bit_index = 0;
      word = 0;
      saved_header = 0;
      waiting_payload = 0;
    end else begin
      if ($isunknown(rx_data)) $fatal(1, "Serial BFM received X/Z data");
      word[bit_index] = rx_data;
      if (bit_index == 63) begin
        bit_index = 0;
        if (!waiting_payload && word[4:0] == 5'h1b) begin
          saved_header = word;
          waiting_payload = 1;
        end else begin
          if (write_count - read_count >= QUEUE_DEPTH)
            $fatal(1, "Serial BFM receive queue overflow");
          received_queue[write_count % QUEUE_DEPTH] = waiting_payload
            ? {word, saved_header} : {64'b0, word};
          write_count = write_count + 1;
          waiting_payload = 0;
        end
        word = 0;
      end else bit_index = bit_index + 1;
    end
  end
endmodule
`default_nettype wire
