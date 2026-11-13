`default_nettype none
// =============================================================================
// PhyPatternTx500 - 500 MHz data-lane mode control for the PHY (one per lane)
// =============================================================================
//
// Synchronous slave of PhyTxSequencer (same clock_tx500 domain). It turns the
// sequencer's mode and per-lane enable into four registered level controls
// for the PHY. No synchronizer, counter or acknowledgment: the sequencer owns
// all timing (LFSR burst length, seed pulse, ACTIVE entry/exit).
//
// Inputs (from PhyTxSequencer, registered there):
//   mode[2:0]  OFF=0, SEED=1, LFSR=2, ACTIVE=3, RAW=4 (RAW: test only, never
//              issued by the sequencer). Other codes behave as OFF.
//   lane_en    0 forces OFF for every mode. The sequencer enables all lanes
//              for SEED and ACTIVE and the lane mask for LFSR.
// Outputs to PHY (registered):
//   enable_LFSR, zero_ena, load_seed, load_zero
//
//   Mode        | enable_LFSR zero_ena load_seed load_zero
//   ------------+------------------------------------------
//   OFF / idle  |      0          1        0         1
//   SEED        |      0          1        1         0     exactly 1 cycle,then OFF
//   LFSR        |      1          1        0         0
//   ACTIVE      |      0          0        0         0
//   RAW (test)  |      0          0        0         1
//
// SEED is edge-qualified: if mode stays SEED for more than one cycle only the
// first cycle pulses load_seed; the rest are OFF.
//
// Latency: (1 + START_DELAY) clock_tx500 cycles from the sequencer edge
// (32 UI with START_DELAY = 0). All lanes see the same sequencer flops, so all
// lanes switch on the same clock_tx500 edge.
//
// Clock: clock_tx500 (500 MHz), one 32-bit word (32 UI) per cycle.
// Reset: reset_n, asynchronous assert, release synchronized locally.
// Reset value = OFF (0101).
// =============================================================================
module PhyPatternTx500 #(
  parameter integer SYNC_STAGES = 3,  // reset-release synchronizer depth (>= 2)
  parameter integer START_DELAY = 0   // extra clock_tx500 cycles of fixed latency
) (
  input  wire       clock_tx500,
  input  wire       reset_n,
  // From PhyTxSequencer
  input  wire [2:0] mode,
  input  wire       lane_en,
  // To PHY
  output logic      enable_LFSR,
  output logic      zero_ena,
  output logic      load_seed,
  output logic      load_zero
);
  localparam logic [2:0] M_OFF=3'd0, M_SEED=3'd1, M_LFSR=3'd2, M_ACTIVE=3'd3, M_RAW=3'd4;
  localparam logic [3:0] O_OFF=4'b0101, O_SEED=4'b0110, O_LFSR=4'b1100,
                         O_ACTIVE=4'b0000, O_RAW=4'b0001;

  wire rst_n;
  Phy500CtrlResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx500), .arst_ni(reset_n), .rst_no(rst_n));

  // Fixed latency-trim pipeline (START_DELAY flops) on {mode, lane_en}.
  wire [3:0] cmd_in = {mode, lane_en};
  wire [3:0] cmd_d;
  generate
    if (START_DELAY == 0) begin : g_no_delay
      assign cmd_d = cmd_in;
    end else begin : g_delay
      logic [3:0] dly_q [START_DELAY];
      always_ff @(posedge clock_tx500 or negedge rst_n) begin
        if (!rst_n) begin
          for (int i = 0; i < START_DELAY; i++) dly_q[i] <= {M_OFF, 1'b0};
        end else begin
          dly_q[0] <= cmd_in;
          for (int i = 1; i < START_DELAY; i++) dly_q[i] <= dly_q[i-1];
        end
      end
      assign cmd_d = dly_q[START_DELAY-1];
    end
  endgenerate
  wire [2:0] mode_d = cmd_d[3:1];
  wire lane_en_d = cmd_d[0];

  logic seed_prev_q;  // effective SEED seen on the previous cycle
  wire seed_now = lane_en_d && (mode_d == M_SEED);

  always_ff @(posedge clock_tx500 or negedge rst_n) begin
    if (!rst_n) begin
      seed_prev_q <= 1'b0;
      {enable_LFSR, zero_ena, load_seed, load_zero} <= O_OFF;
    end else begin
      seed_prev_q <= seed_now;
      if (!lane_en_d) {enable_LFSR, zero_ena, load_seed, load_zero} <= O_OFF;
      else case (mode_d)
        M_SEED:   {enable_LFSR, zero_ena, load_seed, load_zero} <= seed_prev_q ? O_OFF : O_SEED;
        M_LFSR:   {enable_LFSR, zero_ena, load_seed, load_zero} <= O_LFSR;
        M_ACTIVE: {enable_LFSR, zero_ena, load_seed, load_zero} <= O_ACTIVE;
        M_RAW:    {enable_LFSR, zero_ena, load_seed, load_zero} <= O_RAW;
        default:  {enable_LFSR, zero_ena, load_seed, load_zero} <= O_OFF;
      endcase
    end
  end

`ifndef SYNTHESIS
  initial assert (START_DELAY >= 0) else $fatal(1, "TX500 START_DELAY must be >= 0");
  assert property (@(posedge clock_tx500) disable iff (!rst_n) load_seed |=> !load_seed)
    else $error("TX500: load_seed wider than one cycle");
`endif
endmodule

// -----------------------------------------------------------------------------
// Reset synchronizer: asynchronous assert, synchronous release.
// -----------------------------------------------------------------------------
module Phy500CtrlResetSync #(parameter integer STAGES = 3) (
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
  initial assert (STAGES >= 2) else $fatal(1, "TX500 reset synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
