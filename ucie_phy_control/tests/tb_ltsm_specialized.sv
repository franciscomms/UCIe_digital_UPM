`timescale 1ps/1ps
`default_nettype none
// =============================================================================
// tb_ltsm_specialized: LtsmPhyPatternCtrl800 (800 MHz) + PhyTxControlTop
// (500 MHz sequencer, 2 GHz endpoints, LANES x Tx500) over the single seq_*
// CDC link with unequal inter-region delays.
// Checks:
//   - every LTSM flag (13 legal state/substate routes) issues the right op on
//     the link, drives the right PHY outputs and returns exactly one Finished
//     pulse on its own flag;
//   - custom JTAG burst: LFSR op with the programmed mask, no Finished flag;
//   - illegal state -> error[1]; queue overflow -> error[2];
//   - LINKINIT reseed is sent before ACTIVE; ACTIVE raises ltsm_active_ready
//     and exits (aborted, no Finished) when the state leaves 8;
//   - TRAIN_ERROR entry stops a running training without Finished, discards a
//     queued one, and sets no error bit.
// =============================================================================
module tb_ltsm_specialized;
  localparam int LANES = 2;
  localparam logic [2:0] OP_CLK=0, OP_VAL=1, OP_ID=2, OP_LFSR=3, OP_RESEED=4, OP_ACTIVE=5;

  logic clock = 0, clock_tx500 = 0, clock_tx2g = 0, reset_n = 0;
  always #625 clock = ~clock;
  initial begin #87; forever #250 clock_tx2g = ~clock_tx2g; end
  initial begin #87; #250; forever begin clock_tx500 = 1; #1000; clock_tx500 = 0; #1000; end end

  logic [3:0] ltsm_state = 0, ltsm_dbg_mbtrainState = 0;
  logic [2:0] ltsm_dbg_mbinitSubstate = 0;
  logic [LANES-1:0] ltsm_data_lane_mask = '1;
  logic custom_train_jtag = 0;
  logic [8:0] req = 0;
  logic [4:0] rst_flags = 0;  // {linkInit, rxDeskew, d2cSender, dataVref, valVref}
  wire [8:0] done;
  wire busy, reset_ltsm_n, ltsm_active_ready;
  wire [2:0] errors;

  // ---- Link with unequal inter-region delays ---------------------------------
  wire req_src, stop_src, ack_dst, ready_dst;
  wire [2:0] op_src;
  wire [LANES-1:0] mask_src;
  wire req_dst, stop_dst, ack_src, ready_src;
  wire [2:0] op_dst;
  wire [LANES-1:0] mask_dst;
  assign #170 req_dst = req_src;
  assign #390 stop_dst = stop_src;
  assign #430 op_dst = op_src;
  assign #430 mask_dst = mask_src;
  assign #220 ack_src = ack_dst;
  assign #300 ready_src = ready_dst;

  LtsmPhyPatternCtrl800 #(.LANES(LANES)) u_ctrl (
    .clock(clock), .reset_n(reset_n),
    .ltsm_state(ltsm_state),
    .ltsm_dbg_mbinitSubstate(ltsm_dbg_mbinitSubstate),
    .ltsm_dbg_mbtrainState(ltsm_dbg_mbtrainState),
    .ltsm_data_lane_mask(ltsm_data_lane_mask),
    .custom_train_jtag(custom_train_jtag),
    .ltsm_flagToAnalog_linkInit_resetLfsrScrambler(rst_flags[4]),
    .ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler(rst_flags[3]),
    .ltsm_flagToAnalog_d2cSender_resetLocalScrambler(rst_flags[2]),
    .ltsm_flagToAnalog_dataVref_resetLocalTxScrambler(rst_flags[1]),
    .ltsm_flagToAnalog_valVref_resetLocalTxScrambler(rst_flags[0]),
    .ltsm_flagToAnalog_SendClkPatterns(req[0]),
    .ltsm_flagToAnalog_SendValTrainPattern(req[1]),
    .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(req[2]),
    .ltsm_flagToAnalog_RepairMbSendLaneIDPattern(req[3]),
    .ltsm_flagToAnalog_valVref_sendPattern(req[4]),
    .ltsm_flagToAnalog_dataVref_sendPattern(req[5]),
    .ltsm_flagToAnalog_d2cSender_sendValTrainPattern(req[6]),
    .ltsm_flagToAnalog_d2cSender_sendLfsrPattern(req[7]),
    .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(req[8]),
    .ltsm_flagFromAnalog_FinishedClkPatterns(done[0]),
    .ltsm_flagFromAnalog_FinishedValTrainPattern(done[1]),
    .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(done[2]),
    .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(done[3]),
    .ltsm_flagFromAnalog_valVref_finishedPattern(done[4]),
    .ltsm_flagFromAnalog_dataVref_finishedPattern(done[5]),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(done[6]),
    .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(done[7]),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(done[8]),
    .ltsm_pattern_busy(busy),
    .ltsm_pattern_error(errors),
    .reset_ltsm_n(reset_ltsm_n),
    .ltsm_active_ready(ltsm_active_ready),
    .seq_req_o(req_src), .seq_stop_o(stop_src),
    .seq_op_o(op_src), .seq_mask_o(mask_src),
    .seq_ack_i(ack_src),
    .seq_active_ready_i(ready_src));

  wire phyDigControl, phyTrainLfsr, phyTrainValid, phyTrainLaneid, digControl, laneID_index;
  wire [3:0] lane_id_o;
  wire [LANES-1:0] enable_LFSR, zero_ena, load_seed, load_zero;
  PhyTxControlTop #(.LANES(LANES)) u_phy (
    .clock_tx500(clock_tx500), .clock_tx2g(clock_tx2g), .reset_n(reset_n),
    .seq_req_i(req_dst), .seq_stop_i(stop_dst), .seq_op_i(op_dst), .seq_mask_i(mask_dst),
    .seq_ack_o(ack_dst), .active_ready_o(ready_dst),
    .lane_id_i(4'h5),
    .phyDigControl(phyDigControl), .phyTrainLfsr(phyTrainLfsr),
    .phyTrainValid(phyTrainValid), .phyTrainLaneid(phyTrainLaneid),
    .digControl(digControl), .laneID_index(laneID_index), .lane_id_o(lane_id_o),
    .enable_LFSR(enable_LFSR), .zero_ena(zero_ena), .load_seed(load_seed),
    .load_zero(load_zero));

  // ---- Monitors -----------------------------------------------------------------
  logic [2:0] ops_seen[$];
  logic [LANES-1:0] masks_seen[$];
  int finish_count = 0, seed_pulses = 0, abort_count = 0;
  logic [8:0] last_done = 0;
  bit saw_clk = 0, saw_val = 0, saw_lfsrv = 0, saw_laneid = 0, saw_data = 0, saw_lfsr = 0,
      saw_active = 0;
  time t_seed = 0, t_active = 0;
  always @(posedge req_src) begin ops_seen.push_back(op_src); masks_seen.push_back(mask_src); end
  always @(posedge clock) if (reset_ltsm_n) begin
    if (|done) begin finish_count++; last_done = done; end
    if (u_ctrl.src_done && u_ctrl.src_aborted) abort_count++;
  end
  always @(negedge clock_tx2g) if (reset_n) begin
    saw_clk |= phyDigControl; saw_val |= phyTrainValid; saw_lfsrv |= phyTrainLfsr;
    saw_laneid |= phyTrainLaneid; saw_data |= digControl;
    if ((phyTrainLfsr || phyTrainValid || phyTrainLaneid || digControl) && !phyDigControl)
      $fatal(1, "valid/data without forwarded clock");
  end
  always @(posedge clock_tx500) if (reset_n) begin
    if (|enable_LFSR) saw_lfsr = 1;
    if (load_seed !== '0) begin
      if (load_seed !== '1) $fatal(1, "RESEED not on all lanes");
      seed_pulses++; t_seed = $time;
    end
    if (enable_LFSR === '0 && zero_ena === '0 && load_seed === '0 && load_zero === '0) begin
      if (!saw_active) t_active = $time;
      saw_active = 1;
    end
  end

  task automatic clear_scores;
    ops_seen.delete(); masks_seen.delete();
    finish_count = 0; seed_pulses = 0; abort_count = 0; last_done = 0;
    saw_clk = 0; saw_val = 0; saw_lfsrv = 0; saw_laneid = 0; saw_data = 0; saw_lfsr = 0;
    saw_active = 0;
  endtask

  task automatic reset_all;
    @(negedge clock); reset_n = 0; req = 0; rst_flags = 0; custom_train_jtag = 0;
    ltsm_state = 0; ltsm_dbg_mbinitSubstate = 0; ltsm_dbg_mbtrainState = 0;
    repeat (5) @(negedge clock);
    reset_n = 1;
    repeat (12) @(negedge clock);
    clear_scores();
    if (errors != 0 || busy || (|done)) $fatal(1, "Reset left stale transaction");
  endtask

  // One LTSM route: owner flag, LTSM state/substates, expected op.
  task automatic run_route(input int owner, input int initstate, input int trainstate,
                           input logic [2:0] exp_op);
    wait (!busy);
    @(negedge clock); clear_scores();
    ltsm_state = 4'(owner < 4 ? 5 : 6); ltsm_dbg_mbinitSubstate = 3'(initstate);
    ltsm_dbg_mbtrainState = 4'(trainstate);
    @(negedge clock); req = 9'b1 << owner;
    if (owner < 4) begin @(negedge clock); req = 0; end   // MBINIT flags: 1-cycle pulse
    wait (finish_count == 1);
    wait (!busy);
    repeat (20) @(negedge clock);   // a held request must NOT retrigger
    if (finish_count != 1 || last_done != (9'b1 << owner) || errors != 0)
      $fatal(1, "owner %0d: Finished %b x%0d errors %b", owner, last_done, finish_count, errors);
    if (ops_seen.size() != 1 || ops_seen[0] != exp_op || masks_seen[0] != '1)
      $fatal(1, "owner %0d: wrong link command", owner);
    case (exp_op)
      OP_CLK: if (!saw_clk || saw_val || saw_lfsrv || saw_laneid || saw_data || saw_lfsr)
        $fatal(1, "CLK_TRAIN PHY outputs wrong");
      OP_VAL: if (!saw_clk || !saw_val || saw_lfsrv || saw_laneid || saw_data || saw_lfsr)
        $fatal(1, "VAL_TRAIN PHY outputs wrong");
      OP_ID: if (!saw_clk || saw_val || saw_lfsrv || !saw_laneid || !saw_data || saw_lfsr)
        $fatal(1, "LANEID PHY outputs wrong");
      OP_LFSR: if (!saw_clk || saw_val || !saw_lfsrv || saw_laneid || saw_data || !saw_lfsr)
        $fatal(1, "LFSR PHY outputs wrong");
      default: $fatal(1, "bad expected op");
    endcase
    req = 0;
    repeat (3) @(negedge clock);
    $display("PASS LTSM owner %0d init %0d train %0d -> op %0d, Finished once",
             owner, initstate, trainstate, exp_op);
  endtask

  initial begin
    reset_all();
    run_route(0, 2, 0, OP_CLK);
    run_route(1, 3, 0, OP_VAL);
    run_route(2, 4, 0, OP_ID);
    run_route(3, 5, 0, OP_ID);
    run_route(4, 0, 1, OP_VAL);
    run_route(5, 0, 2, OP_LFSR);
    run_route(6, 0, 6, OP_VAL);
    run_route(4, 0, 7, OP_VAL);
    run_route(7, 0, 8, OP_LFSR);
    run_route(5, 0, 9, OP_LFSR);
    run_route(8, 0, 10, OP_LFSR);
    run_route(7, 0, 11, OP_LFSR);
    run_route(7, 0, 12, OP_LFSR);

    // -- Reset-scrambler flag -> RESEED, no Finished ------------------------------
    @(negedge clock); clear_scores(); ltsm_state = 6; ltsm_dbg_mbtrainState = 2;
    rst_flags = 5'b00010;
    wait (busy); wait (!busy);
    repeat (10) @(negedge clock);
    if (ops_seen.size() != 1 || ops_seen[0] != OP_RESEED || seed_pulses != 1 ||
        finish_count != 0 || saw_clk || errors != 0)
      $fatal(1, "reseed flag did not produce exactly one RESEED");
    rst_flags = 0;
    $display("PASS reset-scrambler flag -> RESEED");

    // -- Custom JTAG burst --------------------------------------------------------
    @(negedge clock); clear_scores(); ltsm_state = 0; ltsm_data_lane_mask = 2'b10;
    custom_train_jtag = 1;
    wait (busy); wait (!busy);
    repeat (10) @(negedge clock);
    if (ops_seen.size() != 1 || ops_seen[0] != OP_LFSR || masks_seen[0] != 2'b10 ||
        finish_count != 0 || errors != 0 || !saw_lfsr)
      $fatal(1, "custom JTAG burst wrong");
    custom_train_jtag = 0; ltsm_data_lane_mask = '1;
    repeat (6) @(negedge clock);
    $display("PASS custom JTAG LFSR burst");

    // -- LINKINIT reseed before ACTIVE; ACTIVE exit when state leaves 8 ----------
    @(negedge clock); clear_scores();
    ltsm_state = 7; rst_flags = 5'b10000;          // LINKINIT holds its flag
    @(negedge clock); ltsm_state = 8;              // immediately enter ACTIVE
    wait (ltsm_active_ready);
    repeat (20) @(negedge clock);
    if (ops_seen.size() != 2 || ops_seen[0] != OP_RESEED || ops_seen[1] != OP_ACTIVE)
      $fatal(1, "LINKINIT reseed not ordered before ACTIVE");
    if (seed_pulses != 1 || !saw_active || t_seed >= t_active)
      $fatal(1, "PHY did not reseed before ACTIVE");
    if (!phyDigControl || phyTrainValid || phyTrainLfsr || phyTrainLaneid || digControl ||
        enable_LFSR !== '0 || zero_ena !== '0 || load_zero !== '0)
      $fatal(1, "ACTIVE PHY outputs wrong");
    if (!busy) $fatal(1, "controller must stay busy in ACTIVE");
    @(negedge clock); ltsm_state = 5; rst_flags = 0;  // leave ACTIVE (e.g. retrain)
    wait (!busy);
    repeat (10) @(negedge clock);
    if (ltsm_active_ready || phyDigControl || finish_count != 0 || abort_count != 1 || errors != 0)
      $fatal(1, "ACTIVE exit wrong");
    if (enable_LFSR !== '0 || zero_ena !== '1 || load_zero !== '1)
      $fatal(1, "Tx500 not OFF after ACTIVE");
    $display("PASS LINKINIT reseed -> ACTIVE -> exit on state change");

    // -- Re-entering ACTIVE launches it again ----------------------------------------
    @(negedge clock); clear_scores(); ltsm_state = 8;
    wait (ltsm_active_ready);
    @(negedge clock); ltsm_state = 9;               // TRAIN_ERROR also leaves ACTIVE
    wait (!busy);
    repeat (6) @(negedge clock);
    if (ops_seen.size() != 1 || ops_seen[0] != OP_ACTIVE || abort_count != 1 || errors != 0)
      $fatal(1, "ACTIVE re-entry wrong");
    $display("PASS ACTIVE launched once per entry");

    // -- TRAIN_ERROR aborts a running training, discards the queued one ---------
    reset_all();
    @(negedge clock); clear_scores(); ltsm_state = 6; ltsm_dbg_mbtrainState = 8;
    req = 9'b1 << 7;                                 // d2cSender LFSR, held
    wait (|enable_LFSR);
    @(negedge clock); ltsm_dbg_mbtrainState = 2; req = (9'b1 << 7) | (9'b1 << 5);  // queue dataVref
    @(negedge clock);
    if (!u_ctrl.pending_valid) $fatal(1, "second training was not queued");
    repeat (4) @(negedge clock); ltsm_state = 9;
    wait (!busy);
    repeat (20) @(negedge clock);
    if (finish_count != 0 || abort_count != 1 || errors != 0 || ops_seen.size() != 1 || phyDigControl)
      $fatal(1, "TRAIN_ERROR abort wrong: fin %0d abort %0d err %b ops %0d",
             finish_count, abort_count, errors, ops_seen.size());
    req = 0;
    $display("PASS TRAIN_ERROR stops the training without Finished, drops the queue");

    // -- Illegal state -> error[1] ----------------------------------------------------
    reset_all();
    @(negedge clock); ltsm_state = 6; ltsm_dbg_mbinitSubstate = 2;
    @(negedge clock); req = 9'b1; @(negedge clock); req = 0;
    repeat (20) @(negedge clock);
    if (errors != 3'b010 || busy || ops_seen.size() != 0 || finish_count != 0)
      $fatal(1, "illegal state not rejected");
    $display("PASS illegal state -> error[1]");

    // -- Queue overflow -> error[2] -------------------------------------------------
    reset_all();
    @(negedge clock); ltsm_state = 5; ltsm_dbg_mbinitSubstate = 4;
    @(negedge clock); req = 9'b100; @(negedge clock); req = 0;  // runs
    wait (digControl);
    @(negedge clock); req = 9'b100; @(negedge clock); req = 0;  // queued
    @(negedge clock); req = 9'b100; @(negedge clock); req = 0;  // overflow
    repeat (4) @(negedge clock);
    if (errors != 3'b100) $fatal(1, "queue overflow not reported: %b", errors);
    wait (!busy);
    if (finish_count != 2) $fatal(1, "queued lane-ID run lost (%0d)", finish_count);
    $display("PASS queue overflow -> error[2]");

    $display("LTSM_SPECIALIZED_REGRESSION_PASS");
    $finish;
  end
  initial begin #200000000; $fatal(1, "tb_ltsm_specialized timeout"); end
endmodule
`default_nettype wire
