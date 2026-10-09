// Complete UCIe LTSM/RDI/FDI bring-up through two production SideBandModules.
// Directed stalls apply to the parallel serializer FIFO inputs. Die-to-die
// transport remains one serial data wire and one forwarded clock per direction.
// Reset convention: asynchronous active-low reset_n; there is no reset signal.

`timescale 1ns/1ps
`default_nettype none

module D2DAdapterLinkMgmtLtsmDualDieBackpressureSpec_tb #(
  parameter int unsigned MAX_CYCLES = 12_000_000,
  parameter int unsigned STEP_CHUNK = 25,
  parameter int unsigned NO_PROGRESS_CYCLES = 500_000,
  parameter int unsigned STALL_CYCLES = 300,
  parameter int unsigned SERIAL_DRAIN_CYCLES = 32
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  localparam int unsigned CYCLE_WIDTH =
    (MAX_CYCLES + 2 <= 2) ? 1 : $clog2(MAX_CYCLES + 2);
  localparam logic [15:0] REQUIRED_MBTRAIN_STATE_MASK = 16'h5FFE;

  logic clock = 1'b0;
  logic reset_n = 1'b1;
  logic [31:0] cycles_1us;

  logic done;
  logic protocol_active_issued;
  logic [5:0] stalled_source_mask;
  logic message_stability_error;
  logic train_error;
  logic no_progress_timeout;
  logic cycle_timeout;
  logic [CYCLE_WIDTH-1:0] cycle_count;
  logic serial_idle;
  logic serial_error;
  logic [31:0] wire_completed_0_to_1;
  logic [31:0] wire_completed_1_to_0;
  logic [3:0] die0_ltsm_state;
  logic [3:0] die1_ltsm_state;
  logic [3:0] die0_mbtrain_state;
  logic [3:0] die1_mbtrain_state;
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  logic [11:0] die0_mbtrain_active_substate;
  logic [11:0] die1_mbtrain_active_substate;
  logic [15:0] die0_ltsm_visited_mask;
  logic [15:0] die1_ltsm_visited_mask;
  logic [15:0] die0_mbtrain_visited_mask;
  logic [15:0] die1_mbtrain_visited_mask;
  logic unknown_drop_error;
  PhyState_t die0_rdi_state;
  PhyState_t die1_rdi_state;
  PhyState_t die0_fdi_state;
  PhyState_t die1_fdi_state;
  LinkInitState_t die0_fdi_init_state;
  LinkInitState_t die1_fdi_init_state;

  always #5ns clock = ~clock;

  task automatic step(input int unsigned cycles);
    repeat (cycles) begin
      @(posedge clock);
      #1ps;
    end
  endtask

  D2DAdapterLinkMgmtLtsmDualDieDirectedBackpressureHarness #(
    .STALL_CYCLES(STALL_CYCLES),
    .MAX_CYCLES(MAX_CYCLES),
    .NO_PROGRESS_CYCLES(NO_PROGRESS_CYCLES),
    .SERIAL_DRAIN_CYCLES(SERIAL_DRAIN_CYCLES)
  ) dut (
    .clock(clock),
    .reset_n(reset_n),
    .cycles_1us(cycles_1us),
    .done(done),
    .protocol_active_issued(protocol_active_issued),
    .stalled_source_mask(stalled_source_mask),
    .message_stability_error(message_stability_error),
    .train_error(train_error),
    .no_progress_timeout(no_progress_timeout),
    .cycle_timeout(cycle_timeout),
    .cycle_count(cycle_count),
    .serial_idle(serial_idle),
    .serial_error(serial_error),
    .wire_completed_0_to_1(wire_completed_0_to_1),
    .wire_completed_1_to_0(wire_completed_1_to_0),
    .die0_ltsm_state(die0_ltsm_state),
    .die1_ltsm_state(die1_ltsm_state),
    .die0_mbtrain_state(die0_mbtrain_state),
    .die1_mbtrain_state(die1_mbtrain_state),
    .die0_mbtrain_active_substate(die0_mbtrain_active_substate),
    .die1_mbtrain_active_substate(die1_mbtrain_active_substate),
    .die0_ltsm_visited_mask(die0_ltsm_visited_mask),
    .die1_ltsm_visited_mask(die1_ltsm_visited_mask),
    .die0_mbtrain_visited_mask(die0_mbtrain_visited_mask),
    .die1_mbtrain_visited_mask(die1_mbtrain_visited_mask),
    .unknown_drop_error(unknown_drop_error),
    .die0_rdi_state(die0_rdi_state),
    .die1_rdi_state(die1_rdi_state),
    .die0_fdi_state(die0_fdi_state),
    .die1_fdi_state(die1_fdi_state),
    .die0_fdi_init_state(die0_fdi_init_state),
    .die1_fdi_init_state(die1_fdi_init_state)
  );

  initial begin : run_test
    int unsigned stepped;
    int unsigned this_chunk;
    int unsigned chunk_cycles;
    logic finished;
    logic fatal_monitor;

    if (STEP_CHUNK < 1)
      $fatal(1, "STEP_CHUNK must be at least one");

    chunk_cycles = STEP_CHUNK;
    void'($value$plusargs("STEP_CHUNK=%d", chunk_cycles));
    if (chunk_cycles < 1)
      $fatal(1, "+STEP_CHUNK must be at least one");

    if ($test$plusargs("VCD")) begin
      $dumpfile("D2DAdapterLinkMgmtLtsmDualDieBackpressureSpec_tb.vcd");
      $dumpvars(0, D2DAdapterLinkMgmtLtsmDualDieBackpressureSpec_tb);
    end

    cycles_1us = 32'd1000;
    reset_n = 1'b0;
    step(3);
    @(negedge clock);
    #1ps;
    reset_n = 1'b1;

    stepped = 0;
    finished = 1'b0;
    fatal_monitor = 1'b0;

    while (stepped < MAX_CYCLES && !finished && !fatal_monitor) begin
      this_chunk = ((MAX_CYCLES - stepped) < chunk_cycles) ?
                   (MAX_CYCLES - stepped) : chunk_cycles;
      step(this_chunk);
      stepped += this_chunk;

      finished = (done === 1'b1);
      fatal_monitor = message_stability_error || train_error ||
                      unknown_drop_error || no_progress_timeout ||
                      cycle_timeout || serial_error;
    end

    if (message_stability_error)
      $fatal(1, "A 128-bit message changed or valid dropped while backpressured: cycle=%0d LTSM=(%0d,%0d) RDI=(%0d,%0d) FDI=(%0d,%0d) FDI_INIT=(%0d,%0d) stalledMask=%06b",
             cycle_count, die0_ltsm_state, die1_ltsm_state, die0_rdi_state,
             die1_rdi_state, die0_fdi_state, die1_fdi_state,
             die0_fdi_init_state, die1_fdi_init_state, stalled_source_mask);
    if (train_error)
      $fatal(1, "One of the LTSMs entered TRAIN_ERROR: cycle=%0d states=(%0d,%0d) MBTRAIN=(%0h,%0h) substate=(0x%03h,0x%03h)",
             cycle_count, die0_ltsm_state, die1_ltsm_state,
             die0_mbtrain_state, die1_mbtrain_state,
             die0_mbtrain_active_substate, die1_mbtrain_active_substate);
    if (serial_error)
      $fatal(1, "Serial packet scoreboard failed: completed 0->1=%0d 1->0=%0d",
             wire_completed_0_to_1, wire_completed_1_to_0);
    if (unknown_drop_error)
      $fatal(1, "The integrated sideband router dropped an unknown packet during LTSM/RDI/FDI traffic");
    if (no_progress_timeout)
      $fatal(1, "No state change, packet acceptance, or serial wire activity for %0d cycles: cycle=%0d",
             NO_PROGRESS_CYCLES, cycle_count);
    if (cycle_timeout)
      $fatal(1, "Full bring-up exceeded %0d cycles", MAX_CYCLES);
    if (protocol_active_issued !== 1'b1)
      $fatal(1, "Both FDIs never completed Parameter Exchange");
    if ((die0_ltsm_visited_mask & 16'h01FF) !== 16'h01FF ||
        (die1_ltsm_visited_mask & 16'h01FF) !== 16'h01FF)
      $fatal(1, "LTSM state coverage mismatch: die0=0x%04h die1=0x%04h",
             die0_ltsm_visited_mask, die1_ltsm_visited_mask);
    if ((die0_mbtrain_visited_mask & REQUIRED_MBTRAIN_STATE_MASK) !==
          REQUIRED_MBTRAIN_STATE_MASK ||
        (die1_mbtrain_visited_mask & REQUIRED_MBTRAIN_STATE_MASK) !==
          REQUIRED_MBTRAIN_STATE_MASK)
      $fatal(1, "MBTRAIN state coverage mismatch: die0=0x%04h die1=0x%04h required=0x%04h",
             die0_mbtrain_visited_mask, die1_mbtrain_visited_mask,
             REQUIRED_MBTRAIN_STATE_MASK);
    if (stalled_source_mask !== 6'b111111)
      $fatal(1, "Did not backpressure LTSM, RDI and FDI in both directions: mask=%06b",
             stalled_source_mask);
    if (done !== 1'b1)
      $fatal(1, "Both dies did not reach Active and drain their serial links by cycle %0d", cycle_count);
    if ((serial_idle !== 1'b1) ||
        (wire_completed_0_to_1 == 0) || (wire_completed_1_to_0 == 0))
      $fatal(1, "Serial completion coverage failed: idle=%b completed 0->1=%0d 1->0=%0d",
             serial_idle, wire_completed_0_to_1, wire_completed_1_to_0);

    $display("[backpressure] PASS: cycle=%0d LTSM=(%0d,%0d) RDI=(%0d,%0d) FDI=(%0d,%0d) FDI_INIT=(%0d,%0d) stalledMask=%06b",
             cycle_count, die0_ltsm_state, die1_ltsm_state, die0_rdi_state,
             die1_rdi_state, die0_fdi_state, die1_fdi_state,
             die0_fdi_init_state, die1_fdi_init_state, stalled_source_mask);
    $display("[backpressure] PASS: LTSM masks=(0x%04h,0x%04h) MBTRAIN masks=(0x%04h,0x%04h)",
             die0_ltsm_visited_mask, die1_ltsm_visited_mask,
             die0_mbtrain_visited_mask, die1_mbtrain_visited_mask);
    $display("[backpressure] PASS: one-bit wire packets 0->1=%0d 1->0=%0d; serial paths drained",
             wire_completed_0_to_1, wire_completed_1_to_0);
    $finish;
  end
endmodule

`default_nettype wire
