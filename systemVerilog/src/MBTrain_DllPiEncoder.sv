// Two-stage physical DLL/PI encoder. The first register separates constant
// sector compare/subtract logic from the bank thermometer and DLL mux decoder;
// the second register drives the complete physical control word. No runtime
// division or remainder is used. Throughput is one index per clock, latency
// is two rising edges from sampling phase_index to valid output.
//
// phase_index_out travels beside the word. A sweep controller must qualify
// apply with valid && phase_index_out == its requested phase index, and must
// not consume an analog acknowledge before that qualified apply is asserted.
`default_nettype none

module MBTrain_DllPiEncoder (
  input  wire logic clock,
  input  wire logic reset_n,
  input  wire logic [LtsmParameters_pkg::D2C_PI_INDEX_WIDTH-1:0] phase_index,
  output var logic [LtsmParameters_pkg::D2C_PI_CONTROL_WIDTH-1:0] phase_code,
  output var logic [LtsmParameters_pkg::D2C_PI_INDEX_WIDTH-1:0] phase_index_out,
  output var logic valid
);
  logic [8:0] phasePartsReg;
  logic [LtsmParameters_pkg::D2C_PI_INDEX_WIDTH-1:0] phaseIndexDecodeReg;
  logic decodeValidReg;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      phasePartsReg <= '0;
      phaseIndexDecodeReg <= '0;
      decodeValidReg <= 1'b0;
      phase_code <= LtsmParameters_pkg::encode_d2c_parts(9'd0);
      phase_index_out <= '0;
      valid <= 1'b0;
    end else begin
      phasePartsReg <= LtsmParameters_pkg::decompose_d2c_phase(phase_index);
      phaseIndexDecodeReg <= phase_index;
      decodeValidReg <= 1'b1;
      phase_code <= LtsmParameters_pkg::encode_d2c_parts(phasePartsReg);
      phase_index_out <= phaseIndexDecodeReg;
      valid <= decodeValidReg;
    end
  end
endmodule

`default_nettype wire
