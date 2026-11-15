`default_nettype none
// ============================================================================
// PhyPatternValid500m -- VALID-lane LFSR training bit (500 MHz domain)
// ============================================================================
// Synchronous slave of PhyTxSequencer (same clock_tx500 domain).
//
// Analog interface: one registered, glitch-free level bit, phyTrainLfsr.
// The analog front end transmits the valid-lane pattern of the LFSR burst
// in the 500 MHz domain while phyTrainLfsr is 1. The pattern is generated in
// the analog block. The VALTRAIN and lane-ID valid bits stay in the 2 GHz
// domain (PhyPatternValid2g).
//
// phyTrainLfsr <= lfsr_en (one output flop). There is no synchronizer,
// counter, cancel or acknowledgment: PhyTxSequencer owns all timing. It raises
// lfsr_en only in the BODY of the LFSR command (op 3), on the same edge as the
// Tx500 LFSR mode.
//
// Latency from the sequencer edge to the output:
//   1 clock_tx500 cycle = 32 UI, the same as PhyPatternTx500, so phyTrainLfsr
// and enable_LFSR switch on the same clock_tx500 edge.
//
// Reset: common asynchronous assert, local synchronized release.
// Reset value = idle (0).
// ============================================================================
module PhyPatternValid500m #(
  parameter integer SYNC_STAGES = 3   // reset-release synchronizer depth (>= 2)
) (
  // ---- Local 500 MHz domain -----------------------------------------------
  input  wire clock_tx500,           // local control clock
  input  wire reset_n,               // async reset (assert anywhere, release synced)
  output wire reset_valid500m_n,     // locally synchronized reset (for neighbours)

  // ---- From PhyTxSequencer (same clock_tx500 domain) ----------------------
  input  wire lfsr_en,               // LFSR BODY

  // ---- Analog front end ---------------------------------------------------
  output wire phyTrainLfsr           // valid pattern for LFSR training
);
  Valid500mResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx500), .arst_ni(reset_n), .rst_no(reset_valid500m_n));

  logic train_q;  // registered phyTrainLfsr to analog
  always_ff @(posedge clock_tx500 or negedge reset_valid500m_n)
    if (!reset_valid500m_n) train_q <= 1'b0;
    else                    train_q <= lfsr_en;
  assign phyTrainLfsr = train_q;

endmodule

// Reset synchronizer: asserts asynchronously with arst_ni, releases
// synchronously to clk_i after STAGES clock edges.
module Valid500mResetSync #(
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
  initial assert (STAGES >= 2) else $fatal(1, "VALID500M reset synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
