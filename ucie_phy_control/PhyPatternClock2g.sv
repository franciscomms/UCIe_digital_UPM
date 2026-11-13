`default_nettype none
// ============================================================================
// PhyPatternClock2g -- forwarded-clock control endpoint (2 GHz domain)
// ============================================================================
// Synchronous slave of PhyTxSequencer. The clock pattern itself is generated
// in the analog block; this module only drives one registered, glitch-free
// level bit:
//   phyDigControl = 1 -> the analog front end transmits the forwarded clock.
//   phyDigControl = 0 -> the analog front end sends zeros (no clock).
//
// phyDigControl <= clk_en (one output flop). No synchronizer, counter,
// acknowledgment or priority logic: PhyTxSequencer owns all timing.
//
// Timing: clk_en is launched by a clock_tx500 flop. clock_tx500 and
// clock_tx2g are related (same source, 4:1, phase aligned). The path is a
// normal single-cycle synchronous path: clk_en is captured on the FIRST
// clock_tx2g edge after the launching clock_tx500 edge (0.5 ns budget).
// Latency from the sequencer edge to phyDigControl:
//   1 clock_tx2g cycle = 8 UI.
//
// Reset: common asynchronous assert, local synchronized release.
// Reset value = idle (phyDigControl = 0).
// ============================================================================
module PhyPatternClock2g #(
  parameter integer SYNC_STAGES = 3   // reset-release synchronizer depth (>= 2)
) (
  input  wire  clock_tx2g,          // local control clock
  input  wire  reset_n,             // async reset (assert anywhere, release synced)
  output wire  reset_clock2g_n,     // locally synchronized reset (for neighbours)

  // ---- From PhyTxSequencer (clock_tx500 launched, related clock) ----------
  input  wire  clk_en,              // 1 = forwarded clock on

  // ---- Analog front end ---------------------------------------------------
  output logic phyDigControl        // 1 = send forwarded clock, 0 = send zeros
);
  PhyClock2gCtrlResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(reset_clock2g_n));

  always_ff @(posedge clock_tx2g or negedge reset_clock2g_n)
    if (!reset_clock2g_n) phyDigControl <= 1'b0;
    else                  phyDigControl <= clk_en;

endmodule

// Reset synchronizer: asserts asynchronously with arst_ni, releases
// synchronously to clk_i after STAGES clock edges.
module PhyClock2gCtrlResetSync #(
  parameter integer STAGES = 3
) (
  input  wire clk_i,
  input  wire arst_ni,
  output wire rst_no
);
  (* async_reg = "true", dont_touch = "true" *) logic [STAGES-1:0] release_q;
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) release_q <= '0;
    else release_q <= {release_q[STAGES-2:0], 1'b1};
  end
  assign rst_no = release_q[STAGES-1];
`ifndef SYNTHESIS
  initial assert (STAGES >= 2) else $fatal(1, "CLOCK reset synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
