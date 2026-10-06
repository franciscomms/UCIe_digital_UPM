`timescale 1ns/1ps
`default_nettype none
module BerkeleySidebandPins (
  input wire b_half_clk,
  input wire b_d0, b_d1, b_fw_d0, b_fw_d1,
  output wire peer_rx_data, peer_rx_clock
);
  sb_driver data_driver (
    .clk(b_half_clk), .d0(b_d0), .d1(b_d1),
    .pu_ctl({40{1'b1}}), .pd_ctlb(40'b0), .en(1'b1), .en_b(1'b0),
    .out(peer_rx_data));
  sb_driver clock_driver (
    .clk(b_half_clk), .d0(b_fw_d0), .d1(b_fw_d1),
    .pu_ctl({40{1'b1}}), .pd_ctlb(40'b0), .en(1'b1), .en_b(1'b0),
    .out(peer_rx_clock));
endmodule
`default_nettype wire
