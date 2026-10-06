// Passive scoreboard for the actual one-bit sideband link.
// Compares accepted serializer inputs to independently decoded wire packets,
// then checks that the receiving controller accepts each packet exactly once.
// No monitor output feeds the DUT. This is a simulation-only checker.
`timescale 1ns/1ps
`default_nettype none
module D2DAdapterLinkMgmtTbSerialLinkChecker #(
  parameter bit CHECK_RX_ACCEPT = 1'b1,
  parameter int unsigned QUEUE_DEPTH = 1024
) (
  input wire logic clock,
  input wire logic reset_n,
  input wire logic tx_valid,
  input wire logic [127:0] tx_msg,
  input wire logic tx_ready,
  input wire logic serial_data,
  input wire logic serial_clock,
  input wire logic rx_valid,
  input wire logic [127:0] rx_msg,
  input wire logic rx_ready,
  output logic [31:0] wire_completed,
  output wire logic idle,
  output wire logic error
);
  logic [127:0] tx_expected [0:QUEUE_DEPTH-1];
  logic [127:0] rx_expected [0:QUEUE_DEPTH-1];
  int unsigned tx_accepted, rx_accepted;
  int unsigned bit_count;
  logic [63:0] word_bits, header_bits;
  logic payload_pending;
  logic tx_error, rx_error, wire_error;
  logic holding_tx;
  logic [127:0] held_tx;
  bit diagnostic;

  // Diagnostic mode continues collecting evidence, but leaves error asserted
  // so a test cannot report PASS. The normal run stops at the first error.
  initial begin
    diagnostic = $test$plusargs("SERIAL_DIAGNOSTIC");
    if (QUEUE_DEPTH < 2) $fatal(1, "Serial checker queue too small");
  end

  function automatic logic [127:0] wire_form(input logic [127:0] msg);
    return (msg[4:0] == 5'h1b) ? msg : {64'b0, msg[63:0]};
  endfunction

  task automatic report_error(input string reason);
    if (diagnostic)
      $display("[SERIAL ERROR] %m at %0t: %s", $time, reason);
    else
      $fatal(1, "[SERIAL ERROR] %m at %0t: %s", $time, reason);
  endtask

  assign error = tx_error || rx_error || wire_error;
  assign idle = (tx_accepted == wire_completed) &&
                (!CHECK_RX_ACCEPT || (rx_accepted == wire_completed)) &&
                (bit_count == 0) && !payload_pending;

  // Sender and receiver packet interfaces are sampled on the local clock.
  // The supplied dual-die tests use a common clock. The serial data itself is
  // decoded exclusively at falling edges of the forwarded clock below.
  always @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      tx_accepted <= 0;
      rx_accepted <= 0;
      tx_error <= 1'b0;
      rx_error <= 1'b0;
      holding_tx <= 1'b0;
      held_tx <= '0;
    end else begin
      if (holding_tx && ((tx_valid !== 1'b1) || (tx_msg !== held_tx))) begin
        tx_error <= 1'b1;
        if (!tx_error) report_error("source changed or withdrew a stalled packet");
      end
      holding_tx <= tx_valid && !tx_ready;
      if (tx_valid && !tx_ready) held_tx <= tx_msg;

      if (tx_valid && tx_ready) begin
        if ((tx_accepted - wire_completed) >= QUEUE_DEPTH) begin
          tx_error <= 1'b1;
          if (!tx_error) report_error("TX expectation queue overflow");
        end else begin
          tx_expected[tx_accepted % QUEUE_DEPTH] <= wire_form(tx_msg);
          tx_accepted <= tx_accepted + 1;
        end
      end

      if (CHECK_RX_ACCEPT && rx_valid && rx_ready) begin
        if (rx_accepted >= wire_completed) begin
          rx_error <= 1'b1;
          if (!rx_error) report_error($sformatf(
            "receiver accepted a duplicate or premature packet: accepted=%0d wire_completed=%0d msg=%032h; check held serial RX valid",
            rx_accepted, wire_completed, rx_msg));
        end else begin
          if (rx_msg !== rx_expected[rx_accepted % QUEUE_DEPTH]) begin
            rx_error <= 1'b1;
            if (!rx_error) report_error($sformatf(
              "receiver packet mismatch: expected=%032h actual=%032h",
              rx_expected[rx_accepted % QUEUE_DEPTH], rx_msg));
          end
          rx_accepted <= rx_accepted + 1;
        end
      end
    end
  end

  // Header and optional payload are each 64 bits, least-significant bit
  // first. No receive-valid signal or serializer internals are used to decode.
  always @(negedge serial_clock or negedge reset_n) begin : decode_wire
    logic [127:0] completed_msg;
    if (!reset_n) begin
      wire_completed = 0;
      bit_count = 0;
      word_bits = '0;
      header_bits = '0;
      payload_pending = 1'b0;
      wire_error = 1'b0;
    end else begin
      if ($isunknown(serial_data)) begin
        if (!wire_error) report_error("unknown data bit on physical sideband");
        wire_error = 1'b1;
      end
      word_bits[bit_count] = serial_data;
      if (bit_count == 63) begin
        bit_count = 0;
        if (!payload_pending && (word_bits[4:0] == 5'h1b)) begin
          header_bits = word_bits;
          payload_pending = 1'b1;
        end else begin
          completed_msg = payload_pending ? {word_bits, header_bits} :
                                            {64'b0, word_bits};
          payload_pending = 1'b0;
          if (wire_completed >= tx_accepted) begin
            if (!wire_error) report_error("wire packet has no accepted TX input");
            wire_error = 1'b1;
          end else if (completed_msg !== tx_expected[wire_completed % QUEUE_DEPTH]) begin
            if (!wire_error) report_error($sformatf(
              "serialized packet mismatch: expected=%032h actual=%032h",
              tx_expected[wire_completed % QUEUE_DEPTH], completed_msg));
            wire_error = 1'b1;
          end
          if (CHECK_RX_ACCEPT &&
              ((wire_completed - rx_accepted) >= QUEUE_DEPTH)) begin
            if (!wire_error) report_error("RX expectation queue overflow");
            wire_error = 1'b1;
          end
          rx_expected[wire_completed % QUEUE_DEPTH] = completed_msg;
          wire_completed = wire_completed + 1;
        end
        word_bits = '0;
      end else bit_count = bit_count + 1;
    end
  end
endmodule
`default_nettype wire
