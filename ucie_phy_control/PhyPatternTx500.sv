`default_nettype none
// =============================================================================
// PhyPatternTx500 - 500 MHz data-lane mode control for the PHY
// =============================================================================
//
// Simple PHY control: Ctrl800 selects how the data lanes transmit, and this
// module turns that into four level controls for the PHY. Ctrl800 handles
// sequencing and error prevention (e.g. never two requests at once), so only
// minimal protection is done here.
//
// Inputs from Ctrl800 (asynchronous, synchronized locally):
//   lane_mask      0 = lanes off, 1 = lanes in use
//   req_seed_load  reseed request  (4-phase handshake with cmd_ack_o)
//   req_train_lfsr LFSR training   (4-phase handshake with cmd_ack_o)
//   raw_data       level: send data without LFSR
//   active_mode    level: send data + LFSR
// Output to Ctrl800:
//   cmd_ack_o      1 = seed/train done; held until the request goes low
// Outputs to PHY (registered):
//   enable_LFSR, zero_ena, load_seed, load_zero
//
// Priority (highest first):
//   1. lane_mask = 0      -> OFF. Aborts a running seed/train command and
//                            clears cmd_ack_o; that command is never acked.
//   2. req_seed_load = 1  -> load_seed pulse (1 cycle), then ack until req = 0
//   3. req_train_lfsr = 1 -> LFSR for 128 words x 32 UI = 4096 UI (128 cycles),
//                            then OFF with ack until req = 0
//   4. raw_data = 1       -> RAW
//   5. active_mode = 1    -> ACTIVE
//   6. otherwise          -> OFF
// A running seed or train command finishes its handshake before any other
// request or mode is taken.
//
//   Mode        | enable_LFSR zero_ena load_seed load_zero | cmd_ack_o
//   ------------+------------------------------------------+----------
//   OFF         |      0          1        0         1     |    0
//   SEED pulse  |      0          1        1         0     |    0
//   SEED ack    |      0          1        0         0     |    1
//   TRAIN       |      1          1        0         0     |    0
//   TRAIN ack   |      0          1        0         1     |    1
//   RAW         |      0          0        0         1     |    0
//   ACTIVE      |      1          0        0         0     |    0
//
// Clock: clock_tx500 (500 MHz), one 32-bit word (32 UI) per cycle.
// Reset: reset_n, asynchronous assert, release synchronized locally.
// =============================================================================
module PhyPatternTx500 #(
  parameter integer TRAIN_WORDS = 128, // training length in 32-UI words
  parameter integer SYNC_STAGES = 3    // CDC synchronizer depth
) (
  input  wire  clock_tx500,
  input  wire  reset_n,
  // From/to Ctrl800
  input  wire  req_train_lfsr,
  input  wire  req_seed_load,
  input  wire  lane_mask,
  input  wire  active_mode,
  input  wire  raw_data,
  output logic cmd_ack_o,
  // To PHY
  output logic enable_LFSR,
  output logic zero_ena,
  output logic load_seed,
  output logic load_zero
);
  // ---------------------------------------------------------------------------
  // Reset release and input synchronizers (Ctrl800 runs on another clock)
  // ---------------------------------------------------------------------------
  wire rst_n;
  wire train_s, seed_s, mask_s, active_s, raw_s;

  Phy500CtrlResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx500), .arst_ni(reset_n), .rst_no(rst_n));
  Phy500CtrlSyncBit #(.STAGES(SYNC_STAGES)) u_train_sync (
    .clk_i(clock_tx500), .rst_ni(rst_n), .async_i(req_train_lfsr), .sync_o(train_s));
  Phy500CtrlSyncBit #(.STAGES(SYNC_STAGES)) u_seed_sync (
    .clk_i(clock_tx500), .rst_ni(rst_n), .async_i(req_seed_load), .sync_o(seed_s));
  Phy500CtrlSyncBit #(.STAGES(SYNC_STAGES)) u_mask_sync (
    .clk_i(clock_tx500), .rst_ni(rst_n), .async_i(lane_mask), .sync_o(mask_s));
  Phy500CtrlSyncBit #(.STAGES(SYNC_STAGES)) u_active_sync (
    .clk_i(clock_tx500), .rst_ni(rst_n), .async_i(active_mode), .sync_o(active_s));
  Phy500CtrlSyncBit #(.STAGES(SYNC_STAGES)) u_raw_sync (
    .clk_i(clock_tx500), .rst_ni(rst_n), .async_i(raw_data), .sync_o(raw_s));

  // ---------------------------------------------------------------------------
  // Command state: IDLE follows the level modes (OFF/RAW/ACTIVE); the other
  // states run the seed and train handshakes.
  // ---------------------------------------------------------------------------
  typedef enum logic [2:0] {IDLE, SEED, SEED_ACK, TRAIN, TRAIN_ACK} state_t;
  state_t state_q, state_d;

  localparam integer CNT_W = (TRAIN_WORDS > 1) ? $clog2(TRAIN_WORDS) : 1;
  logic [CNT_W-1:0] word_cnt_q;   // words sent in the current training burst

  always_comb begin
    state_d = state_q;
    if (!mask_s) state_d = IDLE;  // lanes off: drop any command (no ack sent)
    else case (state_q)
      IDLE:      if (seed_s) state_d = SEED; else if (train_s) state_d = TRAIN;
      SEED:      state_d = SEED_ACK;                          // 1-cycle pulse
      SEED_ACK:  if (!seed_s) state_d = IDLE;                 // wait req low
      TRAIN:     if (word_cnt_q == CNT_W'(TRAIN_WORDS - 1)) state_d = TRAIN_ACK;
      TRAIN_ACK: if (!train_s) state_d = IDLE;                // wait req low
      default:   state_d = IDLE;
    endcase
  end

  // State, training counter and registered PHY outputs.
  always_ff @(posedge clock_tx500 or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= IDLE;
      word_cnt_q <= '0;
      {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_0101; // OFF
    end else begin
      state_q <= state_d;

      // Count one word per TRAIN cycle; cleared outside TRAIN.
      word_cnt_q <= (state_d == TRAIN && state_q == TRAIN) ? word_cnt_q + 1'b1 : '0;

      // Outputs for the next state: {ack, enable_LFSR, zero_ena, load_seed, load_zero}
      case (state_d)
        SEED:      {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_0110;
        SEED_ACK:  {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b1_0100;
        TRAIN:     {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_1100;
        TRAIN_ACK: {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b1_0101;
        default: begin // IDLE: level modes
          if      (mask_s && raw_s)    {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_0001; // RAW
          else if (mask_s && active_s) {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_1000; // ACTIVE
          else                         {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero} <= 5'b0_0101; // OFF
        end
      endcase
    end
  end

`ifndef SYNTHESIS
  // Ctrl800 should never select both level modes; raw_data wins if it does.
  always_ff @(posedge clock_tx500)
    if (rst_n && raw_s && active_s)
      $warning("raw_data and active_mode both high; raw_data takes priority");
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
endmodule

// -----------------------------------------------------------------------------
// Single-bit CDC synchronizer (flip-flop chain).
// -----------------------------------------------------------------------------
module Phy500CtrlSyncBit #(parameter integer STAGES = 3) (
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
