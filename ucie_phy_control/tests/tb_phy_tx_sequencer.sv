`timescale 1ps/1ps
`default_nettype none
// =============================================================================
// tb_phy_tx_sequencer
// =============================================================================
// An 800 MHz bus-functional source (random phase, +SEED=<n>) drives the seq_*
// link of THREE PhyTxControlTop configurations in parallel:
//   c0 "default"   : PRE 4,  POST 4, CLK_LEN 96
//   c1 "shortpost" : PRE 4,  POST 1, CLK_LEN 32 (minimum clock trail after
//                    the 500 MHz LFSR valid/data: 32 - 24 = 8 UI)
//   c2 "longpre"   : PRE 12, POST 6, CLK_LEN 32
// Clocks: 2 GHz and 500 MHz phase aligned (4:1), 800 MHz asynchronous.
//
// Checks (inside every seq_case, every cycle):
//   - the sequencer outputs always form one legal row of the endpoint table;
//   - per command, the run-length trace of rows equals the expected envelope:
//     exact BODY length, PRE before / POST after, or a legal drained abort;
//   - every endpoint output reproduces its sequencer input with a fixed,
//     deterministic latency (each edge, each value, each lane);
//   - Data2g LSB-first alternation; RESEED one cycle without clock; ACTIVE
//     outputs; valid/data/LFSR never without the clock.
// Scenarios (top): every op, stop with req / in PRE / in BODY / in ACTIVE,
// back-to-back random commands, reset in the middle of a command, and a
// standalone Tx500 mode check including the test-only RAW row.
// =============================================================================
package tb_seq_pkg;
  localparam int R_IDLE=0, R_CLK=1, R_VAL=2, R_ID=3, R_LFSR=4, R_SEED=5, R_ACT=6, R_BAD=7;
  localparam logic [2:0] OP_CLK=3'd0, OP_VAL=3'd1, OP_ID=3'd2, OP_LFSR=3'd3,
                         OP_RESEED=3'd4, OP_ACTIVE=3'd5;
  localparam logic [3:0] W_OFF=4'b0101, W_SEED=4'b0110, W_LFSR=4'b1100,
                         W_ACTIVE=4'b0000, W_RAW=4'b0001;
  function automatic logic [3:0] tx_word(input logic [2:0] mode, input logic lane_en);
    if (!lane_en) return W_OFF;
    case (mode)
      3'd1: return W_SEED;
      3'd2: return W_LFSR;
      3'd3: return W_ACTIVE;
      3'd4: return W_RAW;
      default: return W_OFF;
    endcase
  endfunction
  function automatic int body_row(input logic [2:0] op);
    case (op)
      OP_CLK: return R_CLK;
      OP_VAL: return R_VAL;
      OP_ID: return R_ID;
      OP_LFSR: return R_LFSR;
      OP_RESEED: return R_SEED;
      default: return R_ACT;
    endcase
  endfunction
  function automatic string row_name(input int r);
    case (r)
      R_IDLE: return "IDLE"; R_CLK: return "CLK"; R_VAL: return "VAL";
      R_ID: return "ID"; R_LFSR: return "LFSR"; R_SEED: return "SEED";
      R_ACT: return "ACTIVE"; default: return "BAD";
    endcase
  endfunction
endpackage

// -----------------------------------------------------------------------------
// Fixed-latency edge checker. src changes only at src_clk rising edges and
// dst only at dst_clk rising edges; both are sampled at falling edges, so the
// rising-edge time is reconstructed exactly. Every dst change must equal the
// oldest outstanding src change, exactly LAT ps later. Flushed by reset.
// -----------------------------------------------------------------------------
module tb_lat_chk #(
  parameter int W = 1,
  parameter longint LAT = 500,
  parameter longint SRC_HALF = 1000,
  parameter longint DST_HALF = 250,
  parameter string NAME = "sig",
  parameter bit REPORT = 1
) (
  input wire src_clk, dst_clk, rst_n,
  input wire [W-1:0] src,
  input wire [W-1:0] dst
);
  longint tq[$];
  logic [W-1:0] vq[$];
  logic [W-1:0] src_last = '0, dst_last = '0;
  bit reported = 0;
  int edges = 0;
  always @(negedge src_clk) begin
    if (!rst_n) begin tq.delete(); vq.delete(); src_last = src; end
    else if (src !== src_last) begin
      tq.push_back(longint'($time) - SRC_HALF); vq.push_back(src); src_last = src;
    end
  end
  always @(negedge dst_clk) begin
    if (!rst_n) dst_last = dst;
    else if (dst !== dst_last) begin
      longint t_src, t_dst;
      logic [W-1:0] v;
      t_dst = longint'($time) - DST_HALF;
      if (tq.size() == 0) $fatal(1, "%s: output changed to %b with no input change", NAME, dst);
      t_src = tq.pop_front(); v = vq.pop_front();
      if (t_dst - t_src != LAT || dst !== v)
        $fatal(1, "%s: output %b after %0d ps, expected %b after %0d ps", NAME, dst,
               t_dst - t_src, v, LAT);
      edges++;
      if (!reported && REPORT) begin
        reported = 1;
        $display("LATENCY %-24s %5d ps = %3d UI (deterministic, checked on every edge)",
                 NAME, LAT, LAT * 2 / 125);
      end
      dst_last = dst;
    end
  end
endmodule

// -----------------------------------------------------------------------------
// One PhyTxControlTop configuration plus its self-checks.
// -----------------------------------------------------------------------------
module tb_seq_case #(
  parameter int LANES = 4,
  parameter int PRE = 4,
  parameter int POST = 4,
  parameter int CLKLEN = 96,
  parameter string NAME = "case"
) (
  input wire clk500, clk2g, reset_n,
  input wire req, stop,
  input wire [2:0] op,
  input wire [LANES-1:0] mask,
  output wire ack, aborted
);
  import tb_seq_pkg::*;
  localparam longint LAT2G = 500;   // 1 clock_tx2g cycle
  localparam longint LATTX = 2000;  // 1 clock_tx500 cycle
  wire active_ready;
  wire phyDigControl, phyTrainLfsr, phyTrainValid, phyTrainLaneid;
  wire digControl, laneID_index;
  wire [3:0] lane_id_o;
  wire [LANES-1:0] enable_LFSR, zero_ena, load_seed, load_zero;
  PhyTxControlTop #(
    .LANES(LANES), .PRE_CYC(PRE), .POST_CYC(POST), .CLK_LEN(CLKLEN)
  ) u_dut (
    .clock_tx500(clk500), .clock_tx2g(clk2g), .reset_n(reset_n),
    .seq_req_i(req), .seq_stop_i(stop), .seq_op_i(op), .seq_mask_i(mask),
    .seq_ack_o(ack), .seq_aborted_o(aborted), .active_ready_o(active_ready),
    .lane_id_i(4'hA),
    .phyDigControl(phyDigControl), .phyTrainLfsr(phyTrainLfsr),
    .phyTrainValid(phyTrainValid), .phyTrainLaneid(phyTrainLaneid),
    .digControl(digControl), .laneID_index(laneID_index), .lane_id_o(lane_id_o),
    .enable_LFSR(enable_LFSR), .zero_ena(zero_ena), .load_seed(load_seed),
    .load_zero(load_zero));

  // Sequencer outputs (inside the wrapper).
  wire s_clk = u_dut.clk_en;
  wire [2:0] s_val = {u_dut.lfsr_val_en, u_dut.val_sel};  // {lfsr, valid, laneid}
  wire s_id = u_dut.id_en;
  wire [2:0] s_mode = u_dut.tx500_mode;
  wire [LANES-1:0] s_len = u_dut.tx500_lane_en;
  wire [LANES-1:0] all_lanes = {LANES{1'b1}};

  function automatic int classify();
    if (!s_clk && s_val==3'b000 && !s_id && s_mode==3'd0 && s_len=='0 && !active_ready) return R_IDLE;
    if ( s_clk && s_val==3'b000 && !s_id && s_mode==3'd0 && s_len=='0 && !active_ready) return R_CLK;
    if ( s_clk && s_val==3'b010 && !s_id && s_mode==3'd0 && s_len=='0 && !active_ready) return R_VAL;
    if ( s_clk && s_val==3'b001 &&  s_id && s_mode==3'd0 && s_len=='0 && !active_ready) return R_ID;
    if ( s_clk && s_val==3'b100 && !s_id && s_mode==3'd2 && s_len==mask && !active_ready) return R_LFSR;
    if (!s_clk && s_val==3'b000 && !s_id && s_mode==3'd1 && s_len==all_lanes && !active_ready) return R_SEED;
    if ( s_clk && s_val==3'b000 && !s_id && s_mode==3'd3 && s_len==all_lanes && active_ready) return R_ACT;
    return R_BAD;
  endfunction

  // ---- Row trace per command -------------------------------------------------
  int row = R_IDLE;
  int seg_row[$], seg_len[$];
  bit gap = 0, prev_ack = 0;
  int ncmd = 0, last_shape = 0, last_body = 0, pre_stops = 0;
  always @(negedge clk500) begin
    if (!reset_n) begin
      seg_row.delete(); seg_len.delete(); gap = 0; prev_ack = 0; row = R_IDLE;
    end else begin
      row = classify();
      if (row == R_BAD)
        $fatal(1, "%s: illegal sequencer row clk=%b val=%b id=%b mode=%0d lanes=%b ready=%b",
               NAME, s_clk, s_val, s_id, s_mode, s_len, active_ready);
      if (row != R_IDLE) begin
        if (gap) $fatal(1, "%s: idle gap inside one command", NAME);
        if (seg_row.size() > 0 && seg_row[$] == row) seg_len[$] = seg_len[$] + 1;
        else begin seg_row.push_back(row); seg_len.push_back(1); end
      end else if (seg_row.size() > 0) gap = 1;
      if (ack && !prev_ack) begin
        if (s_clk) $fatal(1, "%s: ack raised with clock still enabled", NAME);
        check_command(op, aborted);
        seg_row.delete(); seg_len.delete(); gap = 0; ncmd++;
      end
      prev_ack = ack;
    end
  end

  task automatic check_command(input logic [2:0] cop, input logic ab);
    int n = seg_row.size();
    int br = body_row(cop);
    int bl;
    bit ok;
    string trace = "";
    case (cop)
      OP_CLK: bl = CLKLEN;
      OP_VAL: bl = 32;
      OP_ID: bl = 64;
      OP_LFSR: bl = 128;
      OP_RESEED: bl = 1;
      default: bl = -1;  // ACTIVE: until stop
    endcase
    for (int i = 0; i < n; i++) trace = {trace, $sformatf(" %s x%0d", row_name(seg_row[i]), seg_len[i])};
    ok = 0;
    last_body = 0;
    if (!ab) begin
      if (cop == OP_CLK || cop == OP_RESEED) begin
        ok = (n == 1 && seg_row[0] == br && seg_len[0] == bl);
        last_shape = 2; if (ok) last_body = seg_len[0];
      end else if (cop != OP_ACTIVE) begin
        ok = (n == 3 && seg_row[0] == R_CLK && seg_len[0] == PRE && seg_row[1] == br &&
              seg_len[1] == bl && seg_row[2] == R_CLK && seg_len[2] == POST);
        last_shape = 3; if (ok) last_body = seg_len[1];
      end
    end else begin
      if (n == 0) begin ok = 1; last_shape = 0; end              // stopped before start
      else if (cop == OP_CLK || cop == OP_RESEED) begin
        ok = (n == 1 && seg_row[0] == br && seg_len[0] <= bl);
        last_shape = 2; last_body = seg_len[0];
      end else if (n == 1) begin                                 // stopped in PRE
        ok = (seg_row[0] == R_CLK && seg_len[0] >= POST + 1 && seg_len[0] <= PRE + POST);
        last_shape = 1; pre_stops++;
      end else begin                                             // stopped in BODY
        ok = (n == 3 && seg_row[0] == R_CLK && seg_len[0] == PRE && seg_row[1] == br &&
              seg_len[1] >= 1 && (bl < 0 || seg_len[1] <= bl) &&
              seg_row[2] == R_CLK && seg_len[2] == POST);
        last_shape = 3; last_body = seg_len[1];
      end
    end
    if (!ok) $fatal(1, "%s: op %0d aborted=%b wrong envelope:%s", NAME, cop, ab, trace);
    $display("[%s] op %0d aborted=%b trace:%s%s", NAME, cop, ab, trace,
             (last_body > 0) ? $sformatf("  (BODY %0d UI)", last_body * 32) : "");
  endtask

  // ---- Fixed-latency checks: every endpoint output vs its sequencer input ----
  tb_lat_chk #(.W(1), .LAT(LAT2G), .NAME({NAME, ".Clock2g"})) u_lat_clk (
    .src_clk(clk500), .dst_clk(clk2g), .rst_n(reset_n), .src(s_clk), .dst(phyDigControl));
  tb_lat_chk #(.W(2), .LAT(LAT2G), .NAME({NAME, ".Valid2g"})) u_lat_val (
    .src_clk(clk500), .dst_clk(clk2g), .rst_n(reset_n), .src(s_val[1:0]),
    .dst({phyTrainValid, phyTrainLaneid}));
  tb_lat_chk #(.W(1), .LAT(LATTX), .DST_HALF(1000), .NAME({NAME, ".Valid500m"})) u_lat_lfsrv (
    .src_clk(clk500), .dst_clk(clk500), .rst_n(reset_n), .src(s_val[2]),
    .dst(phyTrainLfsr));
  tb_lat_chk #(.W(1), .LAT(LAT2G), .NAME({NAME, ".Data2g"})) u_lat_id (
    .src_clk(clk500), .dst_clk(clk2g), .rst_n(reset_n), .src(s_id), .dst(digControl));
  for (genvar lane = 0; lane < LANES; lane++) begin : g_lane
    wire [3:0] exp_word = tx_word(s_mode, s_len[lane]);
    wire [3:0] got_word = {enable_LFSR[lane], zero_ena[lane], load_seed[lane], load_zero[lane]};
    tb_lat_chk #(.W(4), .LAT(LATTX), .DST_HALF(1000), .NAME({NAME, ".Tx500"}),
                 .REPORT(lane == 0)) u_lat_tx (
      .src_clk(clk500), .dst_clk(clk500), .rst_n(reset_n), .src(exp_word), .dst(got_word));
  end

  // ---- Endpoint-level cross checks (2 GHz granularity) ------------------------
  bit prev_dig = 0, prev_idx = 0;
  int id_run = 0, last_id_run = 0;
  int seed_pulses[LANES];
  initial foreach (seed_pulses[i]) seed_pulses[i] = 0;
  always @(negedge clk2g) begin
    if (!reset_n) begin prev_dig = 0; prev_idx = 0; id_run = 0; end
    else begin
      // Data2g: LSB first, then alternate; index 0 when disabled; end on MSB.
      if (digControl) begin
        if (!prev_dig) begin
          if (laneID_index) $fatal(1, "%s: lane-ID burst does not start with LSB", NAME);
          id_run = 1;
        end else begin
          if (laneID_index == prev_idx) $fatal(1, "%s: laneID_index did not alternate", NAME);
          id_run++;
        end
      end else begin
        if (laneID_index) $fatal(1, "%s: laneID_index high while disabled", NAME);
        if (prev_dig) begin
          if (!prev_idx) $fatal(1, "%s: lane-ID burst ended on LSB", NAME);
          last_id_run = id_run;
        end
      end
      prev_dig = digControl; prev_idx = laneID_index;
      if (lane_id_o !== 4'hA) $fatal(1, "%s: lane_id pass-through broken", NAME);
      // Valid/data/LFSR only under the forwarded clock.
      if ((phyTrainLfsr || phyTrainValid || phyTrainLaneid || digControl) && !phyDigControl)
        $fatal(1, "%s: valid/data active without clock", NAME);
      if (!$onehot0({phyTrainLfsr, phyTrainValid, phyTrainLaneid}))
        $fatal(1, "%s: more than one valid training bit", NAME);
      for (int l = 0; l < LANES; l++) begin
        logic [3:0] w;
        w = {enable_LFSR[l], zero_ena[l], load_seed[l], load_zero[l]};
        if (w == W_LFSR && !phyDigControl) $fatal(1, "%s: LFSR lane %0d without clock", NAME, l);
        if (w == W_SEED && phyDigControl) $fatal(1, "%s: RESEED with clock", NAME);
        if (w == W_ACTIVE && !(phyDigControl && !phyTrainLfsr && !phyTrainValid &&
                               !phyTrainLaneid && !digControl))
          $fatal(1, "%s: ACTIVE outputs wrong (need clock 1, valid 000, data 0)", NAME);
        if (w != W_OFF && w != W_SEED && w != W_LFSR && w != W_ACTIVE)
          $fatal(1, "%s: lane %0d illegal word %b", NAME, l, w);
      end
    end
  end
  bit prev_seed[LANES];
  always @(negedge clk500) begin
    for (int l = 0; l < LANES; l++) begin
      if (!reset_n) prev_seed[l] = 0;
      else begin
        if (load_seed[l] && prev_seed[l]) $fatal(1, "%s: seed pulse wider than one cycle", NAME);
        if (load_seed[l] && !prev_seed[l]) seed_pulses[l]++;
        prev_seed[l] = load_seed[l];
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// Top: 800 MHz source BFM and scenarios.
// -----------------------------------------------------------------------------
module tb_phy_tx_sequencer;
  import tb_seq_pkg::*;
  localparam int LANES = 4;
  localparam int STOP_NONE = 0, STOP_WITH_REQ = 1, STOP_PRE = 2, STOP_BODY = 3, STOP_ACTIVE = 4;

  logic clk800 = 0, clk500 = 0, clk2g = 0, reset_n = 0;
  int unsigned seed = 1, rng = 1;
  int phase800 = 0;
  bit seeded = 0;
  function automatic int unsigned rnd();
    rng = rng * 32'd1664525 + 32'd1013904223;
    return rng >> 8;
  endfunction

  // 2 GHz and 500 MHz rise together (related, 4:1). 800 MHz: random phase.
  initial forever #250 clk2g = ~clk2g;
  initial begin #250; forever begin clk500 = 1; #1000; clk500 = 0; #1000; end end
  initial begin wait (seeded); #(phase800); forever #625 clk800 = ~clk800; end

  // ---- Link with unequal inter-region delays -----------------------------------
  logic req_src = 0, stop_src = 0;
  logic [2:0] op_src = 0;
  logic [LANES-1:0] mask_src = 0;
  wire req_dst, stop_dst;
  wire [2:0] op_dst;
  wire [LANES-1:0] mask_dst;
  assign #170 req_dst = req_src;
  assign #390 stop_dst = stop_src;
  assign #430 op_dst = op_src;
  assign #430 mask_dst = mask_src;
  wire [2:0] ack_c, ab_c;
  wire ack_all_d, ack_any_d;
  assign #220 ack_all_d = &ack_c;
  assign #220 ack_any_d = |ack_c;

  tb_seq_case #(.LANES(LANES), .PRE(4),  .POST(4), .CLKLEN(96), .NAME("c0.default")) c0 (
    .clk500(clk500), .clk2g(clk2g), .reset_n(reset_n), .req(req_dst), .stop(stop_dst),
    .op(op_dst), .mask(mask_dst), .ack(ack_c[0]), .aborted(ab_c[0]));
  tb_seq_case #(.LANES(LANES), .PRE(4),  .POST(1), .CLKLEN(32), .NAME("c1.shortpost")) c1 (
    .clk500(clk500), .clk2g(clk2g), .reset_n(reset_n), .req(req_dst), .stop(stop_dst),
    .op(op_dst), .mask(mask_dst), .ack(ack_c[1]), .aborted(ab_c[1]));
  tb_seq_case #(.LANES(LANES), .PRE(12), .POST(6), .CLKLEN(32), .NAME("c2.longpre")) c2 (
    .clk500(clk500), .clk2g(clk2g), .reset_n(reset_n), .req(req_dst), .stop(stop_dst),
    .op(op_dst), .mask(mask_dst), .ack(ack_c[2]), .aborted(ab_c[2]));

  // Source-side ack synchronizers (3 stages, as in Ctrl800).
  logic [2:0] ack_all_q = 0, ack_any_q = 0;
  always @(posedge clk800 or negedge reset_n)
    if (!reset_n) begin ack_all_q <= 0; ack_any_q <= 0; end
    else begin ack_all_q <= {ack_all_q[1:0], ack_all_d}; ack_any_q <= {ack_any_q[1:0], ack_any_d}; end
  wire ack_all_s = ack_all_q[2];
  wire ack_any_s = ack_any_q[2];

  int commands = 0;

  task automatic run_cmd(input logic [2:0] op, input logic [LANES-1:0] mask,
                         input int stop_mode, input int stop_wait);
    int n0 = c0.ncmd, n1 = c1.ncmd, n2 = c2.ncmd;
    int seeds0 = c0.seed_pulses[0];
    @(negedge clk800); op_src = op; mask_src = mask;  // payload before req
    @(negedge clk800); req_src = 1;
    case (stop_mode)
      STOP_WITH_REQ: stop_src = 1;
      STOP_PRE: begin repeat (3) @(negedge clk800); stop_src = 1; end
      STOP_BODY: begin
        wait (c0.row == body_row(op));
        repeat (stop_wait) @(negedge clk800);
        stop_src = 1;
      end
      STOP_ACTIVE: begin
        wait (c0.row == R_ACT);
        repeat (3) @(negedge clk500);
        // ACTIVE endpoint outputs: Tx500 0000, Valid 000, Data2g 0, Clock 1.
        if (c0.enable_LFSR !== '0 || c0.zero_ena !== '0 || c0.load_seed !== '0 ||
            c0.load_zero !== '0 || c0.phyDigControl !== 1'b1 || c0.digControl !== 1'b0 ||
            {c0.phyTrainLfsr, c0.phyTrainValid, c0.phyTrainLaneid} !== 3'b000 ||
            c1.enable_LFSR !== '0 || c1.zero_ena !== '0 || c1.load_zero !== '0 ||
            c1.phyDigControl !== 1'b1 || c1.digControl !== 1'b0 ||
            {c1.phyTrainLfsr, c1.phyTrainValid, c1.phyTrainLaneid} !== 3'b000)
          $fatal(1, "ACTIVE endpoint outputs wrong");
        if (!c0.active_ready || !c1.active_ready) $fatal(1, "active_ready low in ACTIVE");
        repeat (stop_wait) @(negedge clk800);
        stop_src = 1;
      end
      default: begin end
    endcase
    wait (ack_all_s);
    @(negedge clk800);
    // Ack is seen only after every envelope has finished: all clocks off.
    if (c0.phyDigControl || c1.phyDigControl || c2.phyDigControl)
      $fatal(1, "ack seen while a forwarded clock is still on");
    if (stop_mode == STOP_NONE) begin
      if (ab_c !== 3'b000) $fatal(1, "unexpected aborted=%b", ab_c);
    end else if (ab_c !== 3'b111) $fatal(1, "stopped command not aborted: %b", ab_c);
    if (c0.ncmd != n0 + 1 || c1.ncmd != n1 + 1 || c2.ncmd != n2 + 1)
      $fatal(1, "command trace not checked exactly once");
    // Scenario-specific shape checks.
    case (stop_mode)
      STOP_NONE: begin
        if (op == OP_ID && (c0.last_id_run != 256 || c1.last_id_run != 256 || c2.last_id_run != 256))
          $fatal(1, "lane-ID burst not 256 x 8 UI (got %0d)", c0.last_id_run);
        if (op == OP_RESEED) begin
          for (int l = 0; l < LANES; l++)
            if (c0.seed_pulses[l] != seeds0 + 1 || c1.seed_pulses[l] != seeds0 + 1)
              $fatal(1, "RESEED not exactly one pulse on lane %0d", l);
        end
      end
      STOP_PRE: if (c0.last_shape != 1 || c1.last_shape != 1 || c2.last_shape != 1)
        $fatal(1, "stop was not taken in PRE (shapes %0d %0d %0d)",
               c0.last_shape, c1.last_shape, c2.last_shape);
      STOP_BODY, STOP_ACTIVE:
        if ((op != OP_CLK && (c0.last_shape != 3 || c1.last_shape != 3)) || c0.last_body == 0)
          $fatal(1, "stop was not taken in BODY");
      default: begin end
    endcase
    req_src = 0; stop_src = 0;
    wait (!ack_any_s);  // payload held until ack has fallen
    @(negedge clk800);
    commands++;
  endtask

  function automatic logic [LANES-1:0] rand_mask();
    logic [LANES-1:0] m;
    do m = LANES'(rnd()); while (m == '0);
    return m;
  endfunction

  // Standalone Tx500 decode check, including the test-only RAW row.
  logic [2:0] sa_mode = 0;
  logic sa_en = 0;
  wire [3:0] sa_word;
  PhyPatternTx500 u_tx_standalone (
    .clock_tx500(clk500), .reset_n(reset_n), .mode(sa_mode), .lane_en(sa_en),
    .enable_LFSR(sa_word[3]), .zero_ena(sa_word[2]), .load_seed(sa_word[1]), .load_zero(sa_word[0]));
  task automatic sa_expect(input logic [2:0] m, input logic en, input logic [3:0] w, input string what);
    @(negedge clk500); sa_mode = m; sa_en = en;
    @(negedge clk500);
    if (sa_word !== w) $fatal(1, "Tx500 %s: got %b expected %b", what, sa_word, w);
  endtask

  initial begin
    if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    rng = seed;
    phase800 = int'(rnd() % 1250);
    seeded = 1;
    $display("tb_phy_tx_sequencer seed=%0d clk800 phase=%0d ps", seed, phase800);
    #(20000 + rnd() % 3000);
    reset_n = 1;
    repeat (10) @(negedge clk800);

    // -- Standalone endpoint table (Tx500) --------------------------------------
    if (sa_word !== W_OFF) $fatal(1, "Tx500 reset value not OFF");
    sa_expect(3'd2, 1, W_LFSR, "LFSR");
    sa_expect(3'd3, 1, W_ACTIVE, "ACTIVE");
    sa_expect(3'd4, 1, W_RAW, "RAW");
    sa_expect(3'd2, 0, W_OFF, "masked LFSR");
    sa_expect(3'd3, 0, W_OFF, "masked ACTIVE");
    sa_expect(3'd1, 1, W_SEED, "SEED");
    @(negedge clk500);
    if (sa_word !== W_OFF) $fatal(1, "Tx500 held SEED did not return to OFF");
    sa_expect(3'd0, 1, W_OFF, "OFF");
    sa_expect(3'd7, 1, W_OFF, "unknown mode");
    $display("PASS standalone Tx500 rows OFF/SEED/LFSR/ACTIVE/RAW/masked");

    // -- Every op, normal completion -------------------------------------------
    run_cmd(OP_CLK, '0, STOP_NONE, 0);
    run_cmd(OP_VAL, '0, STOP_NONE, 0);
    run_cmd(OP_ID, '0, STOP_NONE, 0);
    run_cmd(OP_LFSR, 4'b1111, STOP_NONE, 0);
    run_cmd(OP_LFSR, 4'b1010, STOP_NONE, 0);  // masked lanes stay OFF
    run_cmd(OP_RESEED, '0, STOP_NONE, 0);
    $display("PASS every op: exact BODY lengths and envelopes");

    // -- ACTIVE (LINKINIT order: reseed, then ACTIVE) ---------------------------
    run_cmd(OP_RESEED, '0, STOP_NONE, 0);
    run_cmd(OP_ACTIVE, '0, STOP_ACTIVE, 10 + int'(rnd() % 40));
    $display("PASS ACTIVE entry/exit");

    // -- Stops ------------------------------------------------------------------
    run_cmd(OP_VAL, '0, STOP_PRE, 0);
    run_cmd(OP_ID, '0, STOP_PRE, 0);
    run_cmd(OP_LFSR, rand_mask(), STOP_PRE, 0);
    run_cmd(OP_ACTIVE, '0, STOP_PRE, 0);
    $display("PASS stop during PRE");
    run_cmd(OP_CLK, '0, STOP_BODY, int'(rnd() % 20));
    run_cmd(OP_VAL, '0, STOP_BODY, int'(rnd() % 20));
    run_cmd(OP_ID, '0, STOP_BODY, int'(rnd() % 20));
    run_cmd(OP_LFSR, rand_mask(), STOP_BODY, int'(rnd() % 20));
    $display("PASS stop during BODY");
    run_cmd(OP_LFSR, rand_mask(), STOP_WITH_REQ, 0);
    run_cmd(OP_CLK, '0, STOP_WITH_REQ, 0);
    $display("PASS stop together with request");

    // -- Back-to-back random commands -------------------------------------------
    for (int i = 0; i < 16; i++) begin
      logic [2:0] op;
      op = 3'(rnd() % 6);
      if (op == OP_ACTIVE) run_cmd(op, '0, STOP_ACTIVE, int'(rnd() % 30));
      else run_cmd(op, rand_mask(), STOP_NONE, 0);
    end
    $display("PASS back-to-back random commands");

    // -- Reset in the middle of an LFSR burst -----------------------------------
    @(negedge clk800); op_src = OP_LFSR; mask_src = 4'b1111;
    @(negedge clk800); req_src = 1;
    wait (c0.row == R_LFSR);
    repeat (5 + rnd() % 20) @(negedge clk800);
    reset_n = 0;
    #1;
    if (c0.phyDigControl || c1.phyDigControl || c2.phyDigControl ||
        c0.digControl || c0.laneID_index || c0.phyTrainLfsr || c1.phyTrainLfsr ||
        c0.enable_LFSR !== '0 || c0.zero_ena !== '1 || c0.load_seed !== '0 || c0.load_zero !== '1 ||
        c2.enable_LFSR !== '0 || c2.load_zero !== '1 || ack_c !== 3'b000)
      $fatal(1, "reset did not return every endpoint to the Idle row");
    req_src = 0; stop_src = 0;
    repeat (8) @(negedge clk800);
    reset_n = 1;
    repeat (10) @(negedge clk800);
    run_cmd(OP_LFSR, rand_mask(), STOP_NONE, 0);
    run_cmd(OP_ACTIVE, '0, STOP_ACTIVE, 5);
    $display("PASS reset in the middle of a command, then recovery");

    if (c1.pre_stops == 0 || c2.pre_stops == 0) $fatal(1, "PRE-stop coverage missing");
    $display("TB_PHY_TX_SEQUENCER_PASS seed=%0d commands=%0d", seed, commands);
    $finish;
  end
  initial begin #200000000; $fatal(1, "tb_phy_tx_sequencer timeout"); end
endmodule
`default_nettype wire
