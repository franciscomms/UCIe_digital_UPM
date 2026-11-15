`timescale 1ps/1ps
`default_nettype none

// Active-low asynchronous assertion, destination-edge synchronous release.
// Share one output among interacting registers in a clock/reset domain.
// Reset asserts without a clock; release requires STAGES selected edges.
// STAGES is an implementation choice, not an MTBF guarantee. Preserve this
// chain, use appropriate cells, and constrain reset recovery/removal in STA.
module ucie_reset_sync #(
  parameter integer STAGES = 3,
  parameter bit FALLING_EDGE = 1'b0
) (
  input  wire clk_i,
  input  wire arst_ni,
  output wire rst_no
);
  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [STAGES-1:0] release_q;
  if (FALLING_EDGE) begin : g_falling
    always_ff @(negedge clk_i or negedge arst_ni) begin
      if (!arst_ni) release_q <= '0;
      else release_q <= (release_q << 1) | {{(STAGES-1){1'b0}}, 1'b1};
    end
  end else begin : g_rising
    always_ff @(posedge clk_i or negedge arst_ni) begin
      if (!arst_ni) release_q <= '0;
      else release_q <= (release_q << 1) | {{(STAGES-1){1'b0}}, 1'b1};
    end
  end
  assign rst_no = release_q[STAGES-1];
  // synthesis translate_off
  initial if (STAGES < 2) $fatal(1, "Reset synchronizer needs at least two stages");
  // synthesis translate_on
endmodule

`default_nettype wire
