`default_nettype none

// ============================================================================
// SidebandRx
// Serial-to-parallel receiver for the sideband link, clocked by the clock
// forwarded from the partner die (SideBandModule connects clock = ~sb_rx_clk,
// so din is sampled on the falling edge of sb_rx_clk, half a period after the
// partner's SidebandTx changes it on the rising edge).
//
// Operation:
//   - The forwarded clock only toggles while the partner sends: exactly 64
//     clean pulses per 64-bit word (SidebandTx gates it glitch-free), and it
//     stays low in the gaps between words.
//   - Words are framed purely by counting edges: bitCount runs 0..63 and wraps
//     to 0. There are no sync/start bits. The first bit received is bit 0.
//   - If a word's opcode is MSG_WITH_DATA it is held as the header and the next
//     word is its payload: dout = {payload, header}. Otherwise dout =
//     {64'b0, word}. valid pulses and completion_toggle flips on the edge that
//     publishes a complete message.
//
// Reset:
//   - reset is asynchronous, so it clears bitCount and all state without any
//     sb_rx_clk edge. That matters because no edges arrive until the partner
//     transmits.
//   - The asynchronous release is safe because sb_rx_clk is idle when reset
//     releases (the partner's first packet comes microseconds later), so no
//     edge lands in the recovery/removal window. Do not add a reset
//     synchronizer on this clock: it would use up the first packet's edges.
//   - After reset, bitCount = 0 lines up with bit 0 of the first word. Because
//     every word is exactly 64 edges, alignment carries over to every later
//     word.
//
// What breaks alignment (there is no automatic realignment, since the receiver
// cannot see the gaps while its clock is stopped; any extra or missing edge
// shifts every following word):
//   - A spurious edge on sb_rx_clk between reset release and the first packet
//     (partner power-up, floating pad, TX driver enable). The pad must idle
//     low.
//   - Reset released while the partner is mid-packet (e.g. a local-only reset
//     during traffic): framing restarts mid-word and recovery/removal can be
//     violated.
//   Recovery would need a core-clock watchdog that pulses reset when a word is
//   left partially received (bitCount != 0) for longer than a packet.
// ============================================================================
module SidebandRx (
  input  wire logic         clock,
  input  wire logic         reset,
  input  wire logic         din,
  output var  logic [127:0] dout,
  output var  logic         valid,
  output var  logic [127:0] dbg_shiftReg,
  output var  logic [7:0]   dbg_bitCount,
  output var  logic [7:0]   dbg_prevBitCount,
  // Changes on the same sampling edge that publishes a complete message.
  // A consumer can synchronize it without another incoming clock edge.
  output var  logic         completion_toggle
);
  localparam logic [4:0] OPCODE_MSG_WITH_DATA = 5'b11011;

  logic [63:0] serialPacketReg;
  logic [63:0] headerReg;
  logic [127:0] outputReg;
  logic [7:0] bitCount;
  logic [7:0] prevBitCount;
  logic waitingPayload;
  logic validReg;
  logic [63:0] shiftedPacket;
  logic [63:0] receivedWord;

  function automatic logic [63:0] reverse64(input logic [63:0] value);
    integer i;
    begin
      for (i = 0; i < 64; i = i + 1)
        reverse64[i] = value[63-i];
    end
  endfunction

  always_comb begin
    shiftedPacket = {serialPacketReg[62:0], din};
    receivedWord  = reverse64(shiftedPacket);
    dout             = outputReg;
    valid            = validReg;
    dbg_shiftReg      = {64'b0, serialPacketReg};
    dbg_bitCount      = bitCount;
    dbg_prevBitCount  = prevBitCount;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      serialPacketReg <= 64'b0;
      headerReg       <= 64'b0;
      outputReg       <= 128'b0;
      bitCount        <= 8'b0;
      prevBitCount    <= 8'b0;
      waitingPayload  <= 1'b0;
      validReg        <= 1'b0;
      completion_toggle <= 1'b0;
    end else begin
      prevBitCount    <= bitCount;
      validReg        <= 1'b0;
      serialPacketReg <= shiftedPacket;

      if (bitCount == 8'd63) begin
        bitCount        <= 8'b0;
        serialPacketReg <= 64'b0;
        if (waitingPayload) begin
          outputReg      <= {receivedWord, headerReg};
          validReg       <= 1'b1;
          completion_toggle <= ~completion_toggle;
          waitingPayload <= 1'b0;
        end else if (receivedWord[4:0] == OPCODE_MSG_WITH_DATA) begin
          headerReg       <= receivedWord;
          waitingPayload  <= 1'b1;
        end else begin
          outputReg <= {64'b0, receivedWord};
          validReg  <= 1'b1;
          completion_toggle <= ~completion_toggle;
        end
      end else begin
        bitCount <= bitCount + 8'd1;
      end
    end
  end
endmodule
`default_nettype wire
