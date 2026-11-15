`timescale 1ps/1ps
`default_nettype none

// Generate the DATA lane's publish enable from the actual 500 MHz phase.
// Global reset may assert or deassert at any clock phase. After local reset
// release, first observe clk_500_i LOW, then use its next observed rising edge.
//
// Clock contract inherited from rx_ucie_controlled_lane:
//   clk_i is 2 GHz.
//   clk_500_i is a related divide-by-four clock.
//   Slow transitions nominally occur on rising clk_i edges, leaving 250 ps
//   to the falling-edge sampling registers below. Standard 50% duty meets
//   this contract, as do divide-by-four clocks HIGH for one or three cycles.
//
// After a slow rising edge at time T:
//   T + 250 ps: falling-edge logic detects the rise.
//   T + 500 ps: publish_o becomes HIGH after the fast rising edge.
//   T + 1000 ps: the DATA lane samples publish_o HIGH on its rising edge.
//                This module clears publish_o after that same edge.
//
// Thus publication occurs halfway between consecutive slow rising edges.
// publish_o is a 500 ps clock enable, recurring every 2 ns after acquisition.
// Connect it to rx_ucie_controlled_lane.publish_i and time both the slow-clock
// input to fast-falling-edge paths and the internal half-cycle paths.
// Reset release changes acquisition latency while the acquired phase always
// comes from clk_500_i. This block requires no reset-to-slow-clock alignment.
module rx_ucie_publish_gen #(
  parameter integer RESET_SYNC_STAGES = 3
) (
  input  wire  clk_i,
  input  wire  clk_500_i,
  input  wire  rst_ni,
  output logic publish_o
);
  // Separate edge domains: no falling-edge reset release on a posedge FF.
  wire local_rst_n, rise_rst_n;
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES), .FALLING_EDGE(1'b1)) reset_fall
    (.clk_i(clk_i), .arst_ni(rst_ni), .rst_no(local_rst_n));
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_rise
    (.clk_i(clk_i), .arst_ni(rst_ni), .rst_no(rise_rst_n));

  logic slow_level_q;
  logic seen_low_q;
  logic slow_rise_q;
  always_ff @(negedge clk_i or negedge local_rst_n) begin
    if (!local_rst_n) begin
      slow_level_q <= 1'b0;
      seen_low_q   <= 1'b0;
      slow_rise_q  <= 1'b0;
    end else begin
      slow_level_q <= clk_500_i;
      seen_low_q   <= seen_low_q || !clk_500_i;
      // Waiting for a sampled LOW prevents an initial HIGH after reset
      // from being interpreted as a new slow-clock rising edge.
      slow_rise_q <= seen_low_q && clk_500_i && !slow_level_q;
    end
  end

  always_ff @(posedge clk_i or negedge rise_rst_n) begin
    if (!rise_rst_n) publish_o <= 1'b0;
    else              publish_o <= slow_rise_q;
  end
endmodule

`default_nettype wire
