`default_nettype none
// =============================================================================
// PhyTxSequencer - single owner of TX pattern timing (500 MHz domain)
// =============================================================================
//
// The 800 MHz LtsmPhyPatternCtrl800 talks to this block over ONE CDC
// handshake. This block is the ONLY clock-domain crossing of the TX pattern
// control and the ONLY place that counts cycles. It drives synchronous level
// enables to four endpoints (PhyPatternClock2g, PhyPatternValid2g,
// PhyPatternData2g, LANES x PhyPatternTx500) that contain no synchronizers,
// no counters and no acknowledgments.
//
// Clocks: clock_tx500 (this block, Tx500) and clock_tx2g (2 GHz endpoints) come
// from the same source and are phase aligned 4:1. 800 MHz is asynchronous.
// One 500 MHz cycle = 32 UI, one 2 GHz cycle = 8 UI.
//
// ---- Link protocol (Ctrl800 <-> sequencer) ---------------------------------
//   seq_req_i   level, synchronized here (u_req_sync).
//   seq_stop_i  level, synchronized here (u_stop_sync).
//   seq_op_i, seq_mask_i  bundled data: stable from before req rises until
//               ack has fallen. Captured ONCE, on the first cycle the
//               synchronized request is seen in IDLE. Never synchronized
//               bit by bit (constrain with a bundled max-delay).
//   seq_ack_o   rises only after the whole envelope has finished (clock off),
//               held until synchronized req AND stop are both low.
//   seq_aborted_o  bundled with ack: valid and stable while ack is high.
//               1 = the command was ended early by stop.
//   Source rules: req stays high until ack is seen. stop is raised to end a
//   command early and held until ack. On stop the sequencer drains: valid
//   bits, Data2g and the Tx500 mode go off at once, clk_en stays on for
//   POST_CYC cycles, then clk_en goes off and ack rises with aborted = 1.
//
// ---- Command set (op) -------------------------------------------------------
//   op | name      | envelope              | BODY outputs                 | BODY len
//   ---+-----------+-----------------------+------------------------------+---------
//   0  | CLK_TRAIN | BODY only             | clk_en                       | CLK_LEN
//   1  | VAL_TRAIN | PRE + BODY + POST     | clk_en, val_sel=valid        | 32
//   2  | LANEID    | PRE + BODY + POST     | clk_en, val_sel=laneid, id_en| 64
//   3  | LFSR      | PRE + BODY + POST     | clk_en, val_sel=lfsr,        | 128
//      |           |                       | tx500 LFSR on mask lanes     |
//   4  | RESEED    | BODY only, no clock   | tx500 SEED on all lanes      | 1
//   5  | ACTIVE    | PRE + BODY + POST     | clk_en, tx500 ACTIVE on all  | until stop
//      |           |                       | lanes, active_ready          |
//   PRE and POST drive clk_en only (val_sel/id_en 0, Tx500 OFF).
//   Lengths: 128 iterations each: VALTRAIN 128 x 8 UI, lane ID 128 x 16 UI,
//   LFSR 128 x 32 UI; all divided by 32 UI per 500 MHz cycle.
//   CLK_LEN default 96 = 128 x 24 UI / 32 (UCIe clock pattern iteration:
//   16 UI toggling + 8 UI low). Use 32 if the analog clock iteration is 8 UI.
//
// ---- FSM ----------------------------------------------------------------------
//   IDLE -> PRE -> BODY -> POST -> DONE (ack held) -> IDLE
//   CLK_TRAIN and RESEED: IDLE -> BODY -> DONE.
//   ACTIVE: BODY never ends by itself; only stop ends it (-> POST).
//   Stop in PRE or BODY -> POST (CLK_TRAIN/RESEED: -> DONE). Stop in POST is
//   already draining and changes nothing. A request that is already stopped
//   when first seen goes straight to DONE, aborted, with nothing sent.
//
// All outputs are flops decoded from the NEXT state, so every enable of one
// command changes on the same clock_tx500 edge.
// Reset: reset_n asserts asynchronously (common with Ctrl800 and endpoints);
// release is synchronized locally. Reset values = Idle row (all off).
// =============================================================================
module PhyTxSequencer #(
  parameter integer LANES       = 16,
  parameter integer SYNC_STAGES = 3,   // req/stop synchronizer depth (>= 2)
  parameter integer PRE_CYC     = 4,   // clock lead before BODY, 500 MHz cycles (>= 1)
  parameter integer POST_CYC    = 2,   // clock trail after BODY, 500 MHz cycles (>= 1)
  parameter integer CLK_LEN     = 96   // CLK_TRAIN BODY, 500 MHz cycles (see header)
) (
  input  wire              clock_tx500,
  input  wire              reset_n,          // async assert, local synchronized release
  output wire              reset_seq_n,      // locally synchronized reset (for neighbours)

  // ---- Link from Ctrl800 (asynchronous) -------------------------------------
  input  wire              seq_req_i,
  input  wire              seq_stop_i,
  input  wire [2:0]        seq_op_i,         // bundled with req
  input  wire [LANES-1:0]  seq_mask_i,       // bundled with req (LFSR lanes)
  output logic             seq_ack_o,
  output logic             seq_aborted_o,    // bundled with ack

  // ---- Synchronous enables to the endpoints (registered) --------------------
  output logic             clk_en_o,         // -> PhyPatternClock2g
  output logic [2:0]       val_sel_o,        // {lfsr, valid, laneid} -> PhyPatternValid2g
  output logic             id_en_o,          // -> PhyPatternData2g
  output logic [2:0]       tx500_mode_o,     // -> every PhyPatternTx500
  output logic [LANES-1:0] tx500_lane_en_o,  // per-lane enable for Tx500
  output logic             active_ready_o    // ACTIVE, PRE done: functional TX allowed
);
  // ---------------------------------------------------------------------------
  // Command and Tx500 mode encodings (shared with Ctrl800 / PhyPatternTx500).
  // ---------------------------------------------------------------------------
  localparam logic [2:0] OP_CLK_TRAIN=3'd0, OP_VAL_TRAIN=3'd1, OP_LANEID=3'd2,
                         OP_LFSR=3'd3, OP_RESEED=3'd4, OP_ACTIVE=3'd5;
  localparam logic [2:0] M_OFF=3'd0, M_SEED=3'd1, M_LFSR=3'd2, M_ACTIVE=3'd3;
  // M_RAW=3'd4 is reserved for test; this sequencer never issues it.
  localparam logic [2:0] SEL_LFSR=3'b100, SEL_VALID=3'b010, SEL_LANEID=3'b001;

  // Fixed BODY lengths (128 iterations each), in 500 MHz cycles.
  localparam integer ITERATIONS = 128;
  localparam integer VAL_LEN    = ITERATIONS * 8  / 32;  // 32
  localparam integer ID_LEN     = ITERATIONS * 16 / 32;  // 64
  localparam integer LFSR_LEN   = ITERATIONS * 32 / 32;  // 128
  localparam integer RESEED_LEN = 1;
  localparam integer MAX_LEN = (CLK_LEN > LFSR_LEN) ? CLK_LEN : LFSR_LEN;
  localparam integer MAX_CNT = (MAX_LEN > PRE_CYC) ?
                               ((MAX_LEN > POST_CYC) ? MAX_LEN : POST_CYC) :
                               ((PRE_CYC > POST_CYC) ? PRE_CYC : POST_CYC);
  localparam integer CW = (MAX_CNT > 1) ? $clog2(MAX_CNT) : 1;

  // BODY length minus one, used to load the down counter.
  function automatic logic [CW-1:0] body_last(input logic [2:0] op);
    case (op)
      OP_CLK_TRAIN: body_last = CW'(CLK_LEN - 1);
      OP_VAL_TRAIN: body_last = CW'(VAL_LEN - 1);
      OP_LANEID:    body_last = CW'(ID_LEN - 1);
      OP_LFSR:      body_last = CW'(LFSR_LEN - 1);
      default:      body_last = CW'(RESEED_LEN - 1);  // RESEED; ACTIVE ignores it
    endcase
  endfunction
  // Commands without a PRE/POST clock envelope.
  function automatic logic no_envelope(input logic [2:0] op);
    no_envelope = (op == OP_CLK_TRAIN) || (op == OP_RESEED);
  endfunction
  function automatic logic op_legal(input logic [2:0] op);
    op_legal = (op <= OP_ACTIVE);
  endfunction

  // ---------------------------------------------------------------------------
  // Reset release and the only two request synchronizers of the TX control.
  // ---------------------------------------------------------------------------
  wire req_s, stop_s;
  PhySeqResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx500), .arst_ni(reset_n), .rst_no(reset_seq_n));
  PhySeqSyncBit #(.STAGES(SYNC_STAGES)) u_req_sync (
    .clk_i(clock_tx500), .rst_ni(reset_seq_n), .async_i(seq_req_i), .sync_o(req_s));
  PhySeqSyncBit #(.STAGES(SYNC_STAGES)) u_stop_sync (
    .clk_i(clock_tx500), .rst_ni(reset_seq_n), .async_i(seq_stop_i), .sync_o(stop_s));

  typedef enum logic [2:0] {S_IDLE, S_PRE, S_BODY, S_POST, S_DONE} state_t;
  state_t state_q, state_d;
  logic [CW-1:0] cnt_q, cnt_d;          // cycles left in the current phase, minus one
  logic [2:0] op_q, op_d;               // captured command
  logic [LANES-1:0] mask_q, mask_d;     // captured LFSR lane mask
  logic aborted_d, ack_d;

  // ---------------------------------------------------------------------------
  // Next-state logic.
  // ---------------------------------------------------------------------------
  always_comb begin
    state_d   = state_q;
    cnt_d     = cnt_q;
    op_d      = op_q;
    mask_d    = mask_q;
    aborted_d = seq_aborted_o;
    ack_d     = seq_ack_o;
    case (state_q)
      // Capture the bundled payload once, after request synchronization.
      S_IDLE: if (req_s) begin
        op_d      = seq_op_i;
        mask_d    = seq_mask_i;
        aborted_d = 1'b0;
        if (stop_s || !op_legal(seq_op_i)) begin
          // Already stopped (or unknown op): complete at once, send nothing.
          aborted_d = 1'b1;
          ack_d     = 1'b1;
          state_d   = S_DONE;
        end else if (no_envelope(seq_op_i)) begin
          cnt_d   = body_last(seq_op_i);
          state_d = S_BODY;
        end else begin
          cnt_d   = CW'(PRE_CYC - 1);
          state_d = S_PRE;
        end
      end

      // Clock leads valid/data by PRE_CYC cycles.
      S_PRE: begin
        if (stop_s) begin
          aborted_d = 1'b1;
          cnt_d     = CW'(POST_CYC - 1);
          state_d   = S_POST;
        end else if (cnt_q == '0) begin
          cnt_d   = body_last(op_q);
          state_d = S_BODY;
        end else begin
          cnt_d = cnt_q - 1'b1;
        end
      end

      // Pattern body. ACTIVE never ends on its own.
      S_BODY: begin
        if (stop_s || (op_q != OP_ACTIVE && cnt_q == '0)) begin
          if (stop_s) aborted_d = 1'b1;
          if (no_envelope(op_q)) begin
            ack_d   = 1'b1;
            state_d = S_DONE;
          end else begin
            cnt_d   = CW'(POST_CYC - 1);
            state_d = S_POST;
          end
        end else if (op_q != OP_ACTIVE) begin
          cnt_d = cnt_q - 1'b1;
        end
      end

      // Clock trails valid/data by POST_CYC cycles; stop is ignored here.
      S_POST: begin
        if (cnt_q == '0) begin
          ack_d   = 1'b1;
          state_d = S_DONE;
        end else begin
          cnt_d = cnt_q - 1'b1;
        end
      end

      // Envelope finished, clock off. Hold ack until req and stop are low.
      S_DONE: if (!req_s && !stop_s) begin
        ack_d   = 1'b0;
        state_d = S_IDLE;
      end

      default: begin
        ack_d   = 1'b0;
        state_d = S_IDLE;
      end
    endcase
  end

  // ---------------------------------------------------------------------------
  // State, payload and registered outputs. Outputs are decoded from the next
  // state so all enables for one command switch on the same edge.
  // ---------------------------------------------------------------------------
  always_ff @(posedge clock_tx500 or negedge reset_seq_n) begin
    if (!reset_seq_n) begin
      state_q <= S_IDLE;
      cnt_q <= '0;
      op_q <= OP_CLK_TRAIN;
      mask_q <= '0;
      seq_ack_o <= 1'b0;
      seq_aborted_o <= 1'b0;
      clk_en_o <= 1'b0;
      val_sel_o <= 3'b000;
      id_en_o <= 1'b0;
      tx500_mode_o <= M_OFF;
      tx500_lane_en_o <= '0;
      active_ready_o <= 1'b0;
    end else begin
      state_q <= state_d;
      cnt_q <= cnt_d;
      op_q <= op_d;
      mask_q <= mask_d;
      seq_ack_o <= ack_d;
      seq_aborted_o <= aborted_d;

      // Defaults: Idle row.
      clk_en_o <= 1'b0;
      val_sel_o <= 3'b000;
      id_en_o <= 1'b0;
      tx500_mode_o <= M_OFF;
      tx500_lane_en_o <= '0;
      active_ready_o <= 1'b0;
      case (state_d)
        S_PRE, S_POST: clk_en_o <= 1'b1;   // clock only; Tx500 OFF, valid 0
        S_BODY: case (op_d)
          OP_CLK_TRAIN: clk_en_o <= 1'b1;
          OP_VAL_TRAIN: begin clk_en_o <= 1'b1; val_sel_o <= SEL_VALID; end
          OP_LANEID: begin
            clk_en_o <= 1'b1; val_sel_o <= SEL_LANEID; id_en_o <= 1'b1;
          end
          OP_LFSR: begin
            clk_en_o <= 1'b1; val_sel_o <= SEL_LFSR;
            tx500_mode_o <= M_LFSR; tx500_lane_en_o <= mask_d;
          end
          OP_RESEED: begin
            // No clock. Every lane reloads its seed.
            tx500_mode_o <= M_SEED; tx500_lane_en_o <= '1;
          end
          OP_ACTIVE: begin
            // Only the clock is driven here; valid/data use the functional
            // path. Tx500 ACTIVE on all lanes.
            clk_en_o <= 1'b1; active_ready_o <= 1'b1;
            tx500_mode_o <= M_ACTIVE; tx500_lane_en_o <= '1;
          end
          default: begin end
        endcase
        default: begin end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Simulation-only checks.
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
  initial begin
    assert (LANES >= 1) else $fatal(1, "LANES must be positive");
    assert (PRE_CYC >= 1 && POST_CYC >= 1) else $fatal(1, "PRE_CYC/POST_CYC must be >= 1");
    assert (CLK_LEN >= 1) else $fatal(1, "CLK_LEN must be >= 1");
  end
  // Valid bits and lane-ID enable only under the clock, never in ACTIVE.
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    (val_sel_o != 3'b000 || id_en_o) |-> clk_en_o)
    else $error("SEQ: valid/lane-ID enabled without clock");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    active_ready_o |-> (val_sel_o == 3'b000 && !id_en_o))
    else $error("SEQ: valid/lane-ID enabled in ACTIVE");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    (tx500_mode_o == M_LFSR) |-> clk_en_o)
    else $error("SEQ: Tx500 LFSR without clock");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    $onehot0(val_sel_o))
    else $error("SEQ: more than one valid training bit");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    !(tx500_mode_o > M_ACTIVE))
    else $error("SEQ: reserved Tx500 mode issued");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    (tx500_mode_o == M_SEED) |-> !clk_en_o)
    else $error("SEQ: RESEED with clock");
  // Payload is bundled: stable while the synchronized request is held.
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    (state_q != S_IDLE && req_s) |-> (seq_op_i == op_q && seq_mask_i == mask_q))
    else $error("SEQ: op/mask changed while request held");
  assert property (@(posedge clock_tx500) disable iff (!reset_seq_n)
    seq_ack_o && $past(seq_ack_o) |-> $stable(seq_aborted_o))
    else $error("SEQ: aborted changed while ack held");
  // Exact BODY length for every completed (not aborted) training command.
  integer body_len_q;
  always_ff @(posedge clock_tx500 or negedge reset_seq_n) begin
    if (!reset_seq_n) body_len_q <= 0;
    else if (state_q == S_BODY) begin
      body_len_q <= body_len_q + 1;
      if (state_d != S_BODY && !aborted_d && op_q != OP_ACTIVE)
        assert (body_len_q + 1 == int'(body_last(op_q)) + 1)
          else $error("SEQ: op %0d BODY length %0d, expected %0d",
                      op_q, body_len_q + 1, int'(body_last(op_q)) + 1);
    end else body_len_q <= 0;
  end
`endif
endmodule

// Reset synchronizer: asynchronous assert, synchronous release.
module PhySeqResetSync #(parameter integer STAGES = 3) (
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
  initial assert (STAGES >= 2) else $fatal(1, "SEQ reset synchronizer needs >=2 stages");
`endif
endmodule

// Single-bit level synchronizer for req/stop.
module PhySeqSyncBit #(parameter integer STAGES = 3) (
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
`ifndef SYNTHESIS
  initial assert (STAGES >= 2) else $fatal(1, "SEQ CDC synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
