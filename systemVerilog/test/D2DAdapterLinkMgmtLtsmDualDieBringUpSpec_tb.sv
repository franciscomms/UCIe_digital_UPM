// Two-die Reset-to-Active integration test through production SideBandModules.
// The dies exchange only one-bit sideband data and forwarded clocks. Parallel
// packet signals below are local observation points, never a die-to-die bypass.
// Reset convention: asynchronous active-low reset_n; there is no reset signal.

`timescale 1ns/1ps
`default_nettype none

module D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb #(
  // Include serialization of all training and adapter-management packets.
  parameter int unsigned MAX_LTSM_BRINGUP_CYCLES = 12_000_000,
  parameter int unsigned MAX_LINKMGMT_CYCLES = 250_000,
  parameter int unsigned SERIAL_DRAIN_CYCLES = 32
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  localparam logic [3:0] LTSM_RESET  = 4'd0;
  localparam logic [3:0] LTSM_ACTIVE = 4'd8;

  // New MBTRAIN sequence in the revised LinkTrainingFSM.  Every executable
  // stage (1 through C) and the COMPLETE state (E) must be visited.  State D
  // is the unimplemented repair state and state F is the error state.
  localparam logic [15:0] REQUIRED_MBTRAIN_STATE_MASK = 16'h5FFE;

  logic clock = 1'b0;
  logic reset_n = 1'b1;

  logic start;
  logic stable_clk;
  logic pll_locked;
  logic stable_supply;
  logic [31:0] cycles_1us;
  logic protocol_request_active;
  logic link_0_to_1_enable;
  logic link_1_to_0_enable;

  logic [3:0] die0_ltsm_state;
  logic [3:0] die1_ltsm_state;
  PhyState_t die0_rdi_state;
  PhyState_t die1_rdi_state;
  PhyState_t die0_fdi_state;
  PhyState_t die1_fdi_state;
  LinkInitState_t die0_fdi_init_state;
  LinkInitState_t die1_fdi_init_state;
  logic [2:0] die0_mbinit_substate;
  logic [2:0] die1_mbinit_substate;
  logic [3:0] die0_mbtrain_state;
  logic [3:0] die1_mbtrain_state;
  logic [11:0] die0_mbtrain_active_substate;
  logic [11:0] die1_mbtrain_active_substate;
  logic die0_ltsm_train_error;
  logic die1_ltsm_train_error;
  logic die0_grant_ltsm;
  logic die0_grant_rdi;
  logic die0_grant_fdi;
  logic die1_grant_ltsm;
  logic die1_grant_rdi;
  logic die1_grant_fdi;
  logic die0_tx_valid;
  logic [127:0] die0_tx_msg;
  logic die0_tx_ready;
  logic die1_tx_valid;
  logic [127:0] die1_tx_msg;
  logic die1_tx_ready;
  logic die0_tx_fire;
  logic die1_tx_fire;
  logic die0_rx_fire;
  logic die1_rx_fire;
  logic die0_tx_locked;
  logic die1_tx_locked;
  logic die0_rx_drop_unknown;
  logic die1_rx_drop_unknown;
  logic [127:0] progress_signature;
  logic [5:0] grant_mask;
  logic both_ltsm_active;
  logic both_fdi_wait_protocol;
  logic any_internal_transfer;
  logic any_train_error;
  logic any_unknown_drop;
  logic all_active;
  logic serial_idle;
  logic serial_error;
  logic serial_wire_activity;
  logic [31:0] wire_completed_0_to_1;
  logic [31:0] wire_completed_1_to_0;

  always #5ns clock = ~clock;

  task automatic step(input int unsigned cycles);
    repeat (cycles) begin
      @(posedge clock);
      #1ps;
    end
  endtask

  D2DAdapterLinkMgmtLtsmDualDieHarness dut (
    .clock(clock),
    .reset_n(reset_n),
    .start(start),
    .stable_clk(stable_clk),
    .pll_locked(pll_locked),
    .stable_supply(stable_supply),
    .cycles_1us(cycles_1us),
    .protocol_request_active(protocol_request_active),
    .link_0_to_1_enable(link_0_to_1_enable),
    .link_1_to_0_enable(link_1_to_0_enable),
    .die0_ltsm_state(die0_ltsm_state),
    .die1_ltsm_state(die1_ltsm_state),
    .die0_rdi_state(die0_rdi_state),
    .die1_rdi_state(die1_rdi_state),
    .die0_fdi_state(die0_fdi_state),
    .die1_fdi_state(die1_fdi_state),
    .die0_fdi_init_state(die0_fdi_init_state),
    .die1_fdi_init_state(die1_fdi_init_state),
    .die0_mbinit_substate(die0_mbinit_substate),
    .die1_mbinit_substate(die1_mbinit_substate),
    .die0_mbtrain_state(die0_mbtrain_state),
    .die1_mbtrain_state(die1_mbtrain_state),
    .die0_mbtrain_active_substate(die0_mbtrain_active_substate),
    .die1_mbtrain_active_substate(die1_mbtrain_active_substate),
    .die0_ltsm_train_error(die0_ltsm_train_error),
    .die1_ltsm_train_error(die1_ltsm_train_error),
    .die0_grant_ltsm(die0_grant_ltsm),
    .die0_grant_rdi(die0_grant_rdi),
    .die0_grant_fdi(die0_grant_fdi),
    .die1_grant_ltsm(die1_grant_ltsm),
    .die1_grant_rdi(die1_grant_rdi),
    .die1_grant_fdi(die1_grant_fdi),
    .die0_tx_valid(die0_tx_valid),
    .die0_tx_msg(die0_tx_msg),
    .die0_tx_ready(die0_tx_ready),
    .die1_tx_valid(die1_tx_valid),
    .die1_tx_msg(die1_tx_msg),
    .die1_tx_ready(die1_tx_ready),
    .die0_tx_fire(die0_tx_fire),
    .die1_tx_fire(die1_tx_fire),
    .die0_rx_fire(die0_rx_fire),
    .die1_rx_fire(die1_rx_fire),
    .die0_tx_locked(die0_tx_locked),
    .die1_tx_locked(die1_tx_locked),
    .die0_rx_drop_unknown(die0_rx_drop_unknown),
    .die1_rx_drop_unknown(die1_rx_drop_unknown),
    .progress_signature(progress_signature),
    .grant_mask(grant_mask),
    .both_ltsm_active(both_ltsm_active),
    .both_fdi_wait_protocol(both_fdi_wait_protocol),
    .any_internal_transfer(any_internal_transfer),
    .any_train_error(any_train_error),
    .any_unknown_drop(any_unknown_drop),
    .all_active(all_active),
    .serial_wire_activity(serial_wire_activity),
    .serial_idle(serial_idle),
    .serial_error(serial_error),
    .wire_completed_0_to_1(wire_completed_0_to_1),
    .wire_completed_1_to_0(wire_completed_1_to_0)
  );

  // Keep the error checks running during all phases, including final drain.
  always @(posedge clock) begin
    if (reset_n) begin
      if (serial_error)
        $fatal(1, "Serial packet scoreboard failed: completed 0->1=%0d 1->0=%0d",
               wire_completed_0_to_1, wire_completed_1_to_0);
      if (any_train_error)
        $fatal(1, "Training error: LTSM=(%0d,%0d) MBTRAIN=(%0h,%0h) substate=(0x%03h,0x%03h)",
               die0_ltsm_state, die1_ltsm_state, die0_mbtrain_state, die1_mbtrain_state,
               die0_mbtrain_active_substate, die1_mbtrain_active_substate);
      if (any_unknown_drop)
        $fatal(1, "The sideband router dropped an unknown serially received message");
    end
  end

  initial begin : run_test
    int unsigned cycle;
    int unsigned quiet_cycles;
    logic sawDie0LtsmGrant;
    logic sawDie1LtsmGrant;
    logic sawDie0RdiGrant;
    logic sawDie1RdiGrant;
    logic sawDie0FdiGrant;
    logic sawDie1FdiGrant;
    logic sawAnyInternalTransfer;
    logic sawUnknownDrop;
    logic [15:0] die0LtsmVisited;
    logic [15:0] die1LtsmVisited;
    logic [15:0] die0RdiVisited;
    logic [15:0] die1RdiVisited;
    logic [15:0] die0MbtrainVisited;
    logic [15:0] die1MbtrainVisited;
    logic [15:0] die0FdiVisited;
    logic [15:0] die1FdiVisited;
    logic [7:0] die0FdiInitVisited;
    logic [7:0] die1FdiInitVisited;

    if (MAX_LTSM_BRINGUP_CYCLES < 1 || MAX_LINKMGMT_CYCLES < 1 ||
        SERIAL_DRAIN_CYCLES < 1)
      $fatal(1, "Cycle limits and SERIAL_DRAIN_CYCLES must be positive");

    if ($test$plusargs("VCD")) begin
      $dumpfile("D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb.vcd");
      $dumpvars(0, D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb);
    end

    start = 1'b0;
    stable_clk = 1'b0;
    pll_locked = 1'b0;
    stable_supply = 1'b0;
    cycles_1us = 32'd1000;
    protocol_request_active = 1'b0;
    link_0_to_1_enable = 1'b1;
    link_1_to_0_enable = 1'b1;

    reset_n = 1'b0;
    step(3);
    @(negedge clock);
    #1ps;
    reset_n = 1'b1;
    step(1);

    if (die0_ltsm_state !== LTSM_RESET || die1_ltsm_state !== LTSM_RESET)
      $fatal(1, "Post-reset LTSM state mismatch: die0=%0d die1=%0d", die0_ltsm_state, die1_ltsm_state);
    if (die0_rdi_state !== PhyState_reset || die1_rdi_state !== PhyState_reset)
      $fatal(1, "Post-reset RDI state mismatch");
    if (die0_fdi_state !== PhyState_reset || die1_fdi_state !== PhyState_reset)
      $fatal(1, "Post-reset FDI state mismatch");

    start = 1'b1;
    stable_clk = 1'b1;
    pll_locked = 1'b1;
    stable_supply = 1'b1;

    sawDie0LtsmGrant = 1'b0;
    sawDie1LtsmGrant = 1'b0;
    sawDie0RdiGrant = 1'b0;
    sawDie1RdiGrant = 1'b0;
    sawDie0FdiGrant = 1'b0;
    sawDie1FdiGrant = 1'b0;
    sawAnyInternalTransfer = 1'b0;
    sawUnknownDrop = 1'b0;

    die0LtsmVisited = 16'h0001 << die0_ltsm_state;
    die1LtsmVisited = 16'h0001 << die1_ltsm_state;
    die0RdiVisited = 16'h0001 << die0_rdi_state;
    die1RdiVisited = 16'h0001 << die1_rdi_state;
    die0FdiVisited = 16'h0001 << die0_fdi_state;
    die1FdiVisited = 16'h0001 << die1_fdi_state;
    die0FdiInitVisited = 8'h01 << die0_fdi_init_state;
    die1FdiInitVisited = 8'h01 << die1_fdi_init_state;
    die0MbtrainVisited = 16'h0001 << die0_mbtrain_state;
    die1MbtrainVisited = 16'h0001 << die1_mbtrain_state;

    // Phase 1: both physical LTSMs complete SBINIT, MBINIT and MBTRAIN.
    cycle = 0;
    while (cycle < MAX_LTSM_BRINGUP_CYCLES &&
           (die0_ltsm_state != LTSM_ACTIVE || die1_ltsm_state != LTSM_ACTIVE)) begin
      sawDie0LtsmGrant |= die0_grant_ltsm;
      sawDie1LtsmGrant |= die1_grant_ltsm;
      sawDie0RdiGrant |= die0_grant_rdi;
      sawDie1RdiGrant |= die1_grant_rdi;
      sawDie0FdiGrant |= die0_grant_fdi;
      sawDie1FdiGrant |= die1_grant_fdi;
      sawAnyInternalTransfer |= any_internal_transfer;
      sawUnknownDrop |= any_unknown_drop;

      die0LtsmVisited |= 16'h0001 << die0_ltsm_state;
      die1LtsmVisited |= 16'h0001 << die1_ltsm_state;
      die0RdiVisited |= 16'h0001 << die0_rdi_state;
      die1RdiVisited |= 16'h0001 << die1_rdi_state;
      die0FdiVisited |= 16'h0001 << die0_fdi_state;
      die1FdiVisited |= 16'h0001 << die1_fdi_state;
      die0FdiInitVisited |= 8'h01 << die0_fdi_init_state;
      die1FdiInitVisited |= 8'h01 << die1_fdi_init_state;
      die0MbtrainVisited |= 16'h0001 << die0_mbtrain_state;
      die1MbtrainVisited |= 16'h0001 << die1_mbtrain_state;

      if (die0_ltsm_train_error || die1_ltsm_train_error)
        $fatal(1, "LTSM training error during phase 1 at cycle %0d", cycle);
      step(1);
      cycle++;
    end
    if (cycle >= MAX_LTSM_BRINGUP_CYCLES)
      $fatal(1, "Timed out waiting for both LTSMs Active: die0=%0d die1=%0d", die0_ltsm_state, die1_ltsm_state);

    // Phase 2: RDI Active and FDI parameter exchange while protocol remains NOP.
    cycle = 0;
    while (cycle < MAX_LINKMGMT_CYCLES &&
           (die0_fdi_init_state != LinkInitState_FDI_WAIT_LP_REQ_ACTIVE ||
            die1_fdi_init_state != LinkInitState_FDI_WAIT_LP_REQ_ACTIVE)) begin
      sawDie0LtsmGrant |= die0_grant_ltsm;
      sawDie1LtsmGrant |= die1_grant_ltsm;
      sawDie0RdiGrant |= die0_grant_rdi;
      sawDie1RdiGrant |= die1_grant_rdi;
      sawDie0FdiGrant |= die0_grant_fdi;
      sawDie1FdiGrant |= die1_grant_fdi;
      sawAnyInternalTransfer |= any_internal_transfer;
      sawUnknownDrop |= any_unknown_drop;

      die0LtsmVisited |= 16'h0001 << die0_ltsm_state;
      die1LtsmVisited |= 16'h0001 << die1_ltsm_state;
      die0RdiVisited |= 16'h0001 << die0_rdi_state;
      die1RdiVisited |= 16'h0001 << die1_rdi_state;
      die0FdiVisited |= 16'h0001 << die0_fdi_state;
      die1FdiVisited |= 16'h0001 << die1_fdi_state;
      die0FdiInitVisited |= 8'h01 << die0_fdi_init_state;
      die1FdiInitVisited |= 8'h01 << die1_fdi_init_state;
      die0MbtrainVisited |= 16'h0001 << die0_mbtrain_state;
      die1MbtrainVisited |= 16'h0001 << die1_mbtrain_state;

      step(1);
      cycle++;
    end
    if (cycle >= MAX_LINKMGMT_CYCLES)
      $fatal(1, "Timed out waiting for FDI parameter exchange: init=(%0d,%0d) RDI=(%0d,%0d)",
             die0_fdi_init_state, die1_fdi_init_state, die0_rdi_state, die1_rdi_state);
    if (die0_rdi_state !== PhyState_active || die1_rdi_state !== PhyState_active)
      $fatal(1, "RDI did not reach Active before protocol request");
    if (die0_fdi_state !== PhyState_reset || die1_fdi_state !== PhyState_reset)
      $fatal(1, "FDI left Reset before protocol request");

    // Phase 3: issue one NOP-to-Active edge on both protocol interfaces.
    protocol_request_active = 1'b1;
    cycle = 0;
    while (cycle < MAX_LINKMGMT_CYCLES && !all_active) begin
      sawDie0LtsmGrant |= die0_grant_ltsm;
      sawDie1LtsmGrant |= die1_grant_ltsm;
      sawDie0RdiGrant |= die0_grant_rdi;
      sawDie1RdiGrant |= die1_grant_rdi;
      sawDie0FdiGrant |= die0_grant_fdi;
      sawDie1FdiGrant |= die1_grant_fdi;
      sawAnyInternalTransfer |= any_internal_transfer;
      sawUnknownDrop |= any_unknown_drop;

      die0LtsmVisited |= 16'h0001 << die0_ltsm_state;
      die1LtsmVisited |= 16'h0001 << die1_ltsm_state;
      die0RdiVisited |= 16'h0001 << die0_rdi_state;
      die1RdiVisited |= 16'h0001 << die1_rdi_state;
      die0FdiVisited |= 16'h0001 << die0_fdi_state;
      die1FdiVisited |= 16'h0001 << die1_fdi_state;
      die0FdiInitVisited |= 8'h01 << die0_fdi_init_state;
      die1FdiInitVisited |= 8'h01 << die1_fdi_init_state;
      die0MbtrainVisited |= 16'h0001 << die0_mbtrain_state;
      die1MbtrainVisited |= 16'h0001 << die1_mbtrain_state;

      step(1);
      cycle++;
    end
    if (cycle >= MAX_LINKMGMT_CYCLES)
      $fatal(1, "Timed out waiting for all state machines Active: LTSM=(%0d,%0d) RDI=(%0d,%0d) FDI=(%0d,%0d)",
             die0_ltsm_state, die1_ltsm_state, die0_rdi_state, die1_rdi_state,
             die0_fdi_state, die1_fdi_state);

    // Active state alone is insufficient: a final response can still be in a
    // serializer FIFO or on the one-bit wire. Require both links drained and
    // quiet, while the shared scoreboards keep checking all received packets.
    cycle = 0;
    quiet_cycles = 0;
    while (cycle < MAX_LINKMGMT_CYCLES && quiet_cycles < SERIAL_DRAIN_CYCLES) begin
      step(1);
      cycle++;
      if (all_active && serial_idle && !serial_error)
        quiet_cycles++;
      else
        quiet_cycles = 0;
    end
    if (quiet_cycles < SERIAL_DRAIN_CYCLES)
      $fatal(1, "Timed out draining serial links: idle=%b completed 0->1=%0d 1->0=%0d",
             serial_idle, wire_completed_0_to_1, wire_completed_1_to_0);
    if ((wire_completed_0_to_1 == 0) || (wire_completed_1_to_0 == 0))
      $fatal(1, "No completed one-bit packet was observed in one or both directions");

    if (!all_active || die0_ltsm_state != LTSM_ACTIVE || die1_ltsm_state != LTSM_ACTIVE ||
        die0_rdi_state != PhyState_active || die1_rdi_state != PhyState_active ||
        die0_fdi_state != PhyState_active || die1_fdi_state != PhyState_active)
      $fatal(1, "Final Active-state check failed");
    if (die0_ltsm_train_error || die1_ltsm_train_error)
      $fatal(1, "LTSM training error at completion");

    sawAnyInternalTransfer |= any_internal_transfer;
    sawUnknownDrop |= any_unknown_drop;

    die0LtsmVisited |= 16'h0001 << die0_ltsm_state;
    die1LtsmVisited |= 16'h0001 << die1_ltsm_state;
    die0RdiVisited |= 16'h0001 << die0_rdi_state;
    die1RdiVisited |= 16'h0001 << die1_rdi_state;
    die0FdiVisited |= 16'h0001 << die0_fdi_state;
    die1FdiVisited |= 16'h0001 << die1_fdi_state;
    die0FdiInitVisited |= 8'h01 << die0_fdi_init_state;
    die1FdiInitVisited |= 8'h01 << die1_fdi_init_state;
    die0MbtrainVisited |= 16'h0001 << die0_mbtrain_state;
    die1MbtrainVisited |= 16'h0001 << die1_mbtrain_state;

    if ((die0LtsmVisited & 16'h01ff) != 16'h01ff)
      $fatal(1, "Die0 LTSM missed states, visited mask=0x%04h", die0LtsmVisited);
    if ((die1LtsmVisited & 16'h01ff) != 16'h01ff)
      $fatal(1, "Die1 LTSM missed states, visited mask=0x%04h", die1LtsmVisited);
    if ((die0MbtrainVisited & REQUIRED_MBTRAIN_STATE_MASK) !=
        REQUIRED_MBTRAIN_STATE_MASK)
      $fatal(1, "Die0 MBTRAIN missed revised states, visited mask=0x%04h required=0x%04h",
             die0MbtrainVisited, REQUIRED_MBTRAIN_STATE_MASK);
    if ((die1MbtrainVisited & REQUIRED_MBTRAIN_STATE_MASK) !=
        REQUIRED_MBTRAIN_STATE_MASK)
      $fatal(1, "Die1 MBTRAIN missed revised states, visited mask=0x%04h required=0x%04h",
             die1MbtrainVisited, REQUIRED_MBTRAIN_STATE_MASK);
    if ((die0FdiInitVisited & 8'h3f) != 8'h3f)
      $fatal(1, "Die0 FDI init missed states, visited mask=0x%02h", die0FdiInitVisited);
    if ((die1FdiInitVisited & 8'h3f) != 8'h3f)
      $fatal(1, "Die1 FDI init missed states, visited mask=0x%02h", die1FdiInitVisited);
    if ((die0RdiVisited & 16'h0003) != 16'h0003 ||
        (die1RdiVisited & 16'h0003) != 16'h0003)
      $fatal(1, "An RDI did not visit both Reset and Active");
    if ((die0FdiVisited & 16'h0003) != 16'h0003 ||
        (die1FdiVisited & 16'h0003) != 16'h0003)
      $fatal(1, "An FDI did not visit both Reset and Active");

    if (!sawAnyInternalTransfer)
      $fatal(1, "No sideband transfer was observed through the integrated top");
    if (sawUnknownDrop)
      $fatal(1, "The top-level sideband router dropped an unknown message");

    if (!(sawDie0LtsmGrant && sawDie1LtsmGrant))
      $fatal(1, "The shared arbiter never granted one of the LTSM producers");
    if (!(sawDie0RdiGrant && sawDie1RdiGrant))
      $fatal(1, "The shared arbiter never granted one of the RDI producers");
    if (!(sawDie0FdiGrant && sawDie1FdiGrant))
      $fatal(1, "The shared arbiter never granted one of the FDI producers");

    $display("PASS: D2DAdapterLinkMgmtLtsmDualDieBringUpSpec");
    $display("PASS: revised MBTRAIN states visited: die0=0x%04h die1=0x%04h",
             die0MbtrainVisited, die1MbtrainVisited);
    $display("PASS: one-bit wire packets 0->1=%0d 1->0=%0d; serial paths drained",
             wire_completed_0_to_1, wire_completed_1_to_0);
    $finish;
  end
endmodule

`default_nettype wire
