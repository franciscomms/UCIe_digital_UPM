`default_nettype none
// =============================================================================
// PhyPatternData2g - 2 GHz data-lane Lane ID pattern control for the PHY
// =============================================================================
//
// Synchronous slave of PhyTxSequencer. While id_en is high the PHY sends the
// Lane ID pattern; PhyTxSequencer owns the burst length (64 clock_tx500
// cycles = 256 clock_tx2g cycles = 128 iterations x 16 UI).
//
// Inputs:
//   id_en         from PhyTxSequencer (clock_tx500 launched, related clock)
//   lane_id_i     4-bit Lane ID, passed straight through to the PHY
// Outputs to PHY:
//   digControl    1 = PHY sends the Lane ID pattern          (registered)
//   laneID_index  0 = send Lane ID LSB byte, 1 = MSB byte    (registered)
//   lane_id_o     = lane_id_i (pass-through, no logic). The value must be
//                 stable before id_en rises and while the pattern is sent.
//
// One clock_tx2g cycle = 8 UI, so one iteration (LSB then MSB) = 2 cycles.
// The first cycle of every burst is LSB; laneID_index is 0 when digControl is 0.
// The burst is an even number of cycles (multiple of 4), so it ends on MSB.
//
//   clock_tx2g    _/~\_/~\_/~\_/~\_ ... _/~\_/~\_/~\_
//   digControl    __/~~~~~~~~~~~~~~ ... ~~~~~~~\_____
//   laneID_index  ______/~~~\___/~~ ... \___/~~\_____
//                   LSB MSB LSB MSB      LSB MSB
//
// In ACTIVE id_en = 0, so digControl = 0 (functional data path).
//
// Timing: id_en is captured on the FIRST clock_tx2g edge after the launching
// clock_tx500 edge (single-cycle synchronous related-clock path). Latency
// from the sequencer edge to digControl:
//   1 clock_tx2g cycle = 8 UI.
//
// Clock: clock_tx2g (2 GHz). Reset: reset_n, asynchronous assert, release
// synchronized locally. Reset value = idle (digControl = 0, laneID_index = 0).
// =============================================================================
module PhyPatternData2g #(
  parameter integer SYNC_STAGES = 3   // reset-release synchronizer depth (>= 2)
) (
  input  wire  clock_tx2g,
  input  wire  reset_n,
  // From PhyTxSequencer
  input  wire  id_en,
  input  wire  [3:0] lane_id_i,
  // To PHY
  output logic digControl,
  output logic laneID_index,
  output wire  [3:0] lane_id_o
);
  // Lane ID value: pass-through from digital to PHY (quasi-static, no sync).
  assign lane_id_o = lane_id_i;

  wire rst_n;
  Data2gResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(rst_n));

  // digControl follows id_en. laneID_index: 0 on the first enabled cycle,
  // then alternates every cycle; forced to 0 when disabled.
  always_ff @(posedge clock_tx2g or negedge rst_n) begin
    if (!rst_n) begin
      digControl   <= 1'b0;
      laneID_index <= 1'b0;
    end else begin
      digControl   <= id_en;
      laneID_index <= id_en && digControl && !laneID_index;
    end
  end

`ifndef SYNTHESIS
  assert property (@(posedge clock_tx2g) disable iff (!rst_n) laneID_index |-> digControl)
    else $error("DATA: laneID_index high without digControl");
`endif
endmodule

// -----------------------------------------------------------------------------
// Reset synchronizer: asynchronous assert, synchronous release.
// -----------------------------------------------------------------------------
module Data2gResetSync #(parameter integer STAGES = 3) (
  input  wire clk_i,
  input  wire arst_ni,
  output wire rst_no
);
  (* async_reg = "true", dont_touch = "true" *) logic [STAGES-1:0] release_q;
  always_ff @(posedge clk_i or negedge arst_ni)
    if (!arst_ni) release_q <= '0;
    else          release_q <= {release_q[STAGES-2:0], 1'b1};
  assign rst_no = release_q[STAGES-1];
`ifndef SYNTHESIS
  initial assert (STAGES >= 2) else $fatal(1, "DATA reset synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
