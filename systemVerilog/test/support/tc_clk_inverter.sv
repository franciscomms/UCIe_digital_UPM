// SIMULATION ONLY replacement for the technology-specific clock inverter.
module tc_clk_inverter(input logic clk_i, output logic clk_o);
  assign clk_o = ~clk_i;
endmodule
