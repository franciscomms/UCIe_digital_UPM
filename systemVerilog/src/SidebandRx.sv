`default_nettype none
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
