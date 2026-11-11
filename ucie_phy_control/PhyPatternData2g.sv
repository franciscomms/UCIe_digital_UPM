`default_nettype none
// =============================================================================
// PhyPatternData2g - 2 GHz data-lane Lane ID pattern control for the PHY
// =============================================================================
//
// Simple PHY control: when Ctrl800 raises lane_id_ena, this module makes the
// PHY send the Lane ID pattern ITERATIONS times, then acknowledges.
// Ctrl800 handles sequencing and error prevention.
//
// Inputs from digital:
//   lane_id_ena   1 = send the Lane ID pattern (4-phase handshake;
//                 asynchronous, synchronized locally)
//   lane_id_i     4-bit Lane ID, passed straight through to the PHY
// Output to Ctrl800:
//   cmd_ack_o     1 = all iterations sent; held until lane_id_ena = 0
// Outputs to PHY:
//   digControl    1 = PHY sends the Lane ID pattern          (registered)
//   laneID_index  0 = send Lane ID LSB byte, 1 = MSB byte    (registered)
//   lane_id_o     = lane_id_i (pass-through, no logic). The value must be
//                 stable before lane_id_ena rises and while the pattern is sent.
//
// One clock_tx2g cycle = 8 UI, so one iteration (LSB then MSB) = 2 cycles:
//
//   clock_tx2g    _/~\_/~\_/~\_/~\_ ... _/~\_/~\_/~\_
//   digControl    __/~~~~~~~~~~~~~~ ... ~~~~~~~\_____
//   laneID_index  ______/~~~\___/~~ ... \___/~~\_____
//                   LSB MSB LSB MSB      LSB MSB
//   cmd_ack_o     ________________ ... _______/~~~~~  (until lane_id_ena = 0)
//
// ITERATIONS = 130 -> 130 x 16 UI = 2080 UI = 260 cycles.
//
// Sequence:
//   lane_id_ena = 0 -> digControl = 0, laneID_index = 0, cmd_ack_o = 0
//   lane_id_ena = 1 -> SEND: 130 iterations, then
//                      ACK: digControl = 0, laneID_index = 0, cmd_ack_o = 1
//   lane_id_ena drops during SEND -> stop immediately, outputs low, NO ack.
//
// Clock: clock_tx2g (2 GHz). Reset: reset_n, asynchronous assert, release
// synchronized locally.
// =============================================================================
module PhyPatternData2g #(
  parameter integer ITERATIONS  = 130, // Lane ID pattern repetitions (16 UI each)
  parameter integer SYNC_STAGES = 3    // CDC synchronizer depth
) (
  input  wire  clock_tx2g,
  input  wire  reset_n,
  // From/to Ctrl800
  input  wire  lane_id_ena,
  input  wire  [3:0] lane_id_i,
  output logic cmd_ack_o,
  // To PHY
  output logic digControl,
  output logic laneID_index,
  output wire  [3:0] lane_id_o
);
  // Lane ID value: pass-through from digital to PHY (quasi-static, no sync).
  assign lane_id_o = lane_id_i;

  // ---------------------------------------------------------------------------
  // Reset release and input synchronizer (Ctrl800 runs on another clock)
  // ---------------------------------------------------------------------------
  wire rst_n;
  wire ena_s;

  Data2gResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(rst_n));
  Data2gSyncBit #(.STAGES(SYNC_STAGES)) u_ena_sync (
    .clk_i(clock_tx2g), .rst_ni(rst_n), .async_i(lane_id_ena), .sync_o(ena_s));

  // ---------------------------------------------------------------------------
  // State machine: IDLE -> SEND (130 iterations) -> ACK (until ena low)
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {IDLE, SEND, ACK} state_t;
  state_t state_q, state_d;

  localparam integer CNT_W = (ITERATIONS > 1) ? $clog2(ITERATIONS) : 1;
  logic [CNT_W-1:0] iter_q;   // iterations completed
  logic             msb_q;    // 0 = LSB half, 1 = MSB half of the iteration
  wire last_cycle = msb_q && (iter_q == CNT_W'(ITERATIONS - 1));

  always_comb begin
    state_d = state_q;
    case (state_q)
      IDLE: if (ena_s) state_d = SEND;
      // lane_id_ena dropped before the end: abort, no ack is sent.
      SEND: if (!ena_s) state_d = IDLE; else if (last_cycle) state_d = ACK;
      ACK:  if (!ena_s) state_d = IDLE;    // hold ack until ena goes low
      default: state_d = IDLE;
    endcase
  end

  always_ff @(posedge clock_tx2g or negedge rst_n) begin
    if (!rst_n) begin
      state_q      <= IDLE;
      iter_q       <= '0;
      msb_q        <= 1'b0;
      cmd_ack_o    <= 1'b0;
      digControl   <= 1'b0;
      laneID_index <= 1'b0;
    end else begin
      state_q <= state_d;

      // Pattern counters: alternate LSB/MSB each cycle, count after the MSB.
      // Cleared outside SEND so every burst starts with iteration 0, LSB.
      if (state_q == SEND && state_d == SEND) begin
        msb_q <= ~msb_q;
        if (msb_q) iter_q <= iter_q + 1'b1;
      end else begin
        msb_q  <= 1'b0;
        iter_q <= '0;
      end

      // Outputs for the next cycle, aligned with state_d and the next half.
      cmd_ack_o    <= (state_d == ACK);
      digControl   <= (state_d == SEND);
      laneID_index <= (state_d == SEND) && (state_q == SEND) && !msb_q;
    end
  end
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
endmodule

// -----------------------------------------------------------------------------
// Single-bit CDC synchronizer (flip-flop chain).
// -----------------------------------------------------------------------------
module Data2gSyncBit #(parameter integer STAGES = 3) (
  input  wire clk_i,
  input  wire rst_ni,
  input  wire async_i,
  output wire sync_o
);
  (* async_reg = "true", dont_touch = "true" *) logic [STAGES-1:0] sync_q;
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) sync_q <= '0;
    else         sync_q <= {sync_q[STAGES-2:0], async_i};
  assign sync_o = sync_q[STAGES-1];
endmodule

`default_nettype wire
