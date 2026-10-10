// Directed two-die bring-up over the production one-bit sideband serializers.
// Stall packet acceptance at the serializer FIFO input; the forwarded serial
// clocks and data wires are never gated by the testbench.
// Reset convention: asynchronous active-low reset_n.

`timescale 1ns/1ps
`default_nettype none

module D2DAdapterLinkMgmtLtsmDualDieDirectedBackpressureHarness #(
  // Only behavior-control parameters belong at this level.  FDI/RDI widths
  // are internal DUT defaults and are not part of the backpressure harness.
  parameter int unsigned STALL_CYCLES       = 300,
  parameter int unsigned MAX_CYCLES         = 12_000_000,
  parameter int unsigned NO_PROGRESS_CYCLES = 500_000,
  parameter int unsigned SERIAL_DRAIN_CYCLES = 32,
  parameter int unsigned CYCLE_WIDTH =
    (MAX_CYCLES + 2 <= 2) ? 1 : $clog2(MAX_CYCLES + 2)
) (
  input wire logic clock,
  input wire logic reset_n,
  input wire logic [31:0] cycles_1us,

  output var logic done,
  output var logic protocol_active_issued,
  output var logic [5:0] stalled_source_mask,
  output var logic message_stability_error,
  output var logic train_error,
  output var logic no_progress_timeout,
  output var logic cycle_timeout,
  output var logic [CYCLE_WIDTH-1:0] cycle_count,
  output var logic serial_idle,
  output var logic serial_error,
  output var logic [31:0] wire_completed_0_to_1,
  output var logic [31:0] wire_completed_1_to_0,

  output var logic [3:0] die0_ltsm_state,
  output var logic [3:0] die1_ltsm_state,
  output var logic [3:0] die0_mbtrain_state,
  output var logic [3:0] die1_mbtrain_state,
  // TODO(debug-review): MBTrainFSM.activeSubstate is redundant with the dbg_mbtrain*State pins (packed view of the active MBTRAIN substate); kept for top-level/testbench compatibility, review for removal.
  output var logic [11:0] die0_mbtrain_active_substate,
  output var logic [11:0] die1_mbtrain_active_substate,
  output var logic [15:0] die0_ltsm_visited_mask,
  output var logic [15:0] die1_ltsm_visited_mask,
  output var logic [15:0] die0_mbtrain_visited_mask,
  output var logic [15:0] die1_mbtrain_visited_mask,
  output var logic unknown_drop_error,
  output var UcieUPM_interfaces_pkg::PhyState_t die0_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyState_t die1_rdi_state,
  output var UcieUPM_interfaces_pkg::PhyState_t die0_fdi_state,
  output var UcieUPM_interfaces_pkg::PhyState_t die1_fdi_state,
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t die0_fdi_init_state,
  output var UcieUPM_d2dadapter_pkg::LinkInitState_t die1_fdi_init_state
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;

  initial begin
    if (STALL_CYCLES < 1)       $fatal(1, "STALL_CYCLES must be at least one");
    if (MAX_CYCLES < 1)         $fatal(1, "MAX_CYCLES must be positive");
    if (NO_PROGRESS_CYCLES < 1) $fatal(1, "NO_PROGRESS_CYCLES must be positive");
    if (SERIAL_DRAIN_CYCLES < 1) $fatal(1, "SERIAL_DRAIN_CYCLES must be positive");
  end

  localparam int unsigned NO_PROGRESS_WIDTH =
    (NO_PROGRESS_CYCLES + 2 <= 2) ? 1 : $clog2(NO_PROGRESS_CYCLES + 2);
  localparam int unsigned STALL_COUNT_WIDTH =
    (STALL_CYCLES + 1 <= 2) ? 1 : $clog2(STALL_CYCLES + 1);
  localparam int unsigned DRAIN_COUNT_WIDTH =
    (SERIAL_DRAIN_CYCLES + 1 <= 2) ? 1 : $clog2(SERIAL_DRAIN_CYCLES + 1);

  logic core_start;
  logic core_protocol_request_active;
  logic core_link_0_to_1_enable;
  logic core_link_1_to_0_enable;

  logic [3:0] core_die0_ltsm_state;
  logic [3:0] core_die1_ltsm_state;
  logic [3:0] core_die0_mbtrain_state;
  logic [3:0] core_die1_mbtrain_state;
  logic [11:0] core_die0_mbtrain_active_substate;
  logic [11:0] core_die1_mbtrain_active_substate;
  logic [127:0] core_progress_signature;
  logic core_any_unknown_drop;
  PhyState_t core_die0_rdi_state;
  PhyState_t core_die1_rdi_state;
  PhyState_t core_die0_fdi_state;
  PhyState_t core_die1_fdi_state;
  LinkInitState_t core_die0_fdi_init_state;
  LinkInitState_t core_die1_fdi_init_state;

  logic core_die0_grant_ltsm;
  logic core_die0_grant_rdi;
  logic core_die0_grant_fdi;
  logic core_die1_grant_ltsm;
  logic core_die1_grant_rdi;
  logic core_die1_grant_fdi;

  logic core_die0_tx_valid;
  logic [127:0] core_die0_tx_msg;
  logic core_die0_tx_ready;
  logic core_die1_tx_valid;
  logic [127:0] core_die1_tx_msg;
  logic core_die1_tx_ready;

  logic core_die0_ltsm_train_error;
  logic core_die1_ltsm_train_error;
  logic core_all_active;
  logic core_serial_idle;
  logic core_serial_error;
  logic core_serial_wire_activity;
  logic [31:0] core_wire_completed_0_to_1;
  logic [31:0] core_wire_completed_1_to_0;
  logic [DRAIN_COUNT_WIDTH-1:0] serialDrainCount;

  logic started;
  logic protocolActiveIssued;
  logic bothWaitingForProtocol;

  logic [2:0] source01;
  logic [2:0] source10;
  logic [2:0] stalled01Seen;
  logic [2:0] stalled10Seen;
  logic [STALL_COUNT_WIDTH-1:0] stall01Remaining;
  logic [STALL_COUNT_WIDTH-1:0] stall10Remaining;
  logic [2:0] untested01;
  logic [2:0] untested10;
  logic startStall01;
  logic startStall10;
  logic block01;
  logic block10;

  logic holding0;
  logic [127:0] heldMessage0;
  logic holding1;
  logic [127:0] heldMessage1;
  logic messageStabilityError;

  logic [CYCLE_WIDTH-1:0] cycleCount;
  logic [198:0] progressSignature;
  logic [198:0] previousProgressSignature;
  logic acceptedMessage;
  logic forwardProgress;
  logic [NO_PROGRESS_WIDTH-1:0] noProgressCount;
  logic [15:0] die0LtsmVisited;
  logic [15:0] die1LtsmVisited;
  logic [15:0] die0MbtrainVisited;
  logic [15:0] die1MbtrainVisited;
  logic unknownDropError;

  always_comb begin
    source01 = 3'b000;
    if (core_die0_grant_ltsm)
      source01 = 3'b001;
    else if (core_die0_grant_rdi)
      source01 = 3'b010;
    else if (core_die0_grant_fdi)
      source01 = 3'b100;

    source10 = 3'b000;
    if (core_die1_grant_ltsm)
      source10 = 3'b001;
    else if (core_die1_grant_rdi)
      source10 = 3'b010;
    else if (core_die1_grant_fdi)
      source10 = 3'b100;

    untested01 = source01 & ~stalled01Seen;
    untested10 = source10 & ~stalled10Seen;

    startStall01 = (stall01Remaining == '0) && core_die0_tx_valid && (|untested01);
    startStall10 = (stall10Remaining == '0) && core_die1_tx_valid && (|untested10);

    block01 = startStall01 || (stall01Remaining != '0);
    block10 = startStall10 || (stall10Remaining != '0);

    bothWaitingForProtocol =
      (core_die0_fdi_init_state == LinkInitState_FDI_WAIT_LP_REQ_ACTIVE) &&
      (core_die1_fdi_init_state == LinkInitState_FDI_WAIT_LP_REQ_ACTIVE);

    // The core signature includes MBINIT, MBTRAIN, the active MBTRAIN
    // substate, and message fields. Wire completion counters also recognize
    // progress independently of the phase of the forwarded-clock observation.
    progressSignature = {
      core_progress_signature,
      core_wire_completed_0_to_1,
      core_wire_completed_1_to_0,
      stalled01Seen,
      stalled10Seen,
      protocolActiveIssued
    };

    acceptedMessage =
      (core_die0_tx_valid && core_die0_tx_ready) ||
      (core_die1_tx_valid && core_die1_tx_ready);

    forwardProgress =
      (progressSignature != previousProgressSignature) ||
      acceptedMessage || core_serial_wire_activity ||
      startStall01 || startStall10;

    core_start = started;
    core_protocol_request_active = protocolActiveIssued;
    core_link_0_to_1_enable = !block01;
    core_link_1_to_0_enable = !block10;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      started <= 1'b0;
      protocolActiveIssued <= 1'b0;
      stalled01Seen <= 3'b000;
      stalled10Seen <= 3'b000;
      stall01Remaining <= '0;
      stall10Remaining <= '0;
      holding0 <= 1'b0;
      heldMessage0 <= 128'b0;
      holding1 <= 1'b0;
      heldMessage1 <= 128'b0;
      messageStabilityError <= 1'b0;
      cycleCount <= '0;
      previousProgressSignature <= '0;
      noProgressCount <= '0;
      die0LtsmVisited <= 16'h0001;
      die1LtsmVisited <= 16'h0001;
      die0MbtrainVisited <= 16'h0001;
      die1MbtrainVisited <= 16'h0001;
      unknownDropError <= 1'b0;
      serialDrainCount <= '0;
    end else begin
      started <= 1'b1;

      if (!protocolActiveIssued && bothWaitingForProtocol)
        protocolActiveIssued <= 1'b1;

      if (startStall01) begin
        stalled01Seen <= stalled01Seen | source01;
        stall01Remaining <= STALL_CYCLES - 1;
      end else if (stall01Remaining != '0) begin
        stall01Remaining <= stall01Remaining - 1'b1;
      end

      if (startStall10) begin
        stalled10Seen <= stalled10Seen | source10;
        stall10Remaining <= STALL_CYCLES - 1;
      end else if (stall10Remaining != '0) begin
        stall10Remaining <= stall10Remaining - 1'b1;
      end

      if (!holding0) begin
        if (core_die0_tx_valid && !core_die0_tx_ready) begin
          holding0 <= 1'b1;
          heldMessage0 <= core_die0_tx_msg;
        end
      end else begin
        // Check the acceptance edge too: the message remains the pending
        // message until valid AND ready are sampled high together.
        if ((core_die0_tx_valid !== 1'b1) || (core_die0_tx_msg !== heldMessage0))
          messageStabilityError <= 1'b1;
        if (core_die0_tx_valid && core_die0_tx_ready)
          holding0 <= 1'b0;
      end

      if (!holding1) begin
        if (core_die1_tx_valid && !core_die1_tx_ready) begin
          holding1 <= 1'b1;
          heldMessage1 <= core_die1_tx_msg;
        end
      end else begin
        if ((core_die1_tx_valid !== 1'b1) || (core_die1_tx_msg !== heldMessage1))
          messageStabilityError <= 1'b1;
        if (core_die1_tx_valid && core_die1_tx_ready)
          holding1 <= 1'b0;
      end

      if (!done && cycleCount < MAX_CYCLES)
        cycleCount <= cycleCount + 1'b1;

      previousProgressSignature <= progressSignature;
      die0LtsmVisited <= die0LtsmVisited | (16'h0001 << core_die0_ltsm_state);
      die1LtsmVisited <= die1LtsmVisited | (16'h0001 << core_die1_ltsm_state);
      die0MbtrainVisited <= die0MbtrainVisited |
                            (16'h0001 << core_die0_mbtrain_state);
      die1MbtrainVisited <= die1MbtrainVisited |
                            (16'h0001 << core_die1_mbtrain_state);
      if (core_any_unknown_drop)
        unknownDropError <= 1'b1;

      // Active can precede delivery of the last queued response. Wait for
      // actual serial completion and a quiet interval before reporting done.
      if (core_all_active && core_serial_idle && !core_serial_error &&
          (core_wire_completed_0_to_1 != 0) &&
          (core_wire_completed_1_to_0 != 0)) begin
        if (serialDrainCount < SERIAL_DRAIN_CYCLES)
          serialDrainCount <= serialDrainCount + 1'b1;
      end else begin
        serialDrainCount <= '0;
      end

      if (done || forwardProgress)
        noProgressCount <= '0;
      else if (noProgressCount < NO_PROGRESS_CYCLES)
        noProgressCount <= noProgressCount + 1'b1;
    end
  end

  // The shared harness has no data-width parameters: the instantiated DUTs
  // take FDI/RDI/sideband widths from their RTL package defaults.
  D2DAdapterLinkMgmtLtsmDualDieHarness core (
    .clock(clock),
    .reset_n(reset_n),
    .start(core_start),
    .stable_clk(core_start),
    .pll_locked(core_start),
    .stable_supply(core_start),
    .cycles_1us(cycles_1us),
    .protocol_request_active(core_protocol_request_active),
    .link_0_to_1_enable(core_link_0_to_1_enable),
    .link_1_to_0_enable(core_link_1_to_0_enable),

    .die0_ltsm_state(core_die0_ltsm_state),
    .die1_ltsm_state(core_die1_ltsm_state),
    .die0_rdi_state(core_die0_rdi_state),
    .die1_rdi_state(core_die1_rdi_state),
    .die0_fdi_state(core_die0_fdi_state),
    .die1_fdi_state(core_die1_fdi_state),
    .die0_fdi_init_state(core_die0_fdi_init_state),
    .die1_fdi_init_state(core_die1_fdi_init_state),

    .die0_mbinit_substate(),
    .die1_mbinit_substate(),
    .die0_mbtrain_state(core_die0_mbtrain_state),
    .die1_mbtrain_state(core_die1_mbtrain_state),
    .die0_mbtrain_active_substate(core_die0_mbtrain_active_substate),
    .die1_mbtrain_active_substate(core_die1_mbtrain_active_substate),
    .die0_ltsm_train_error(core_die0_ltsm_train_error),
    .die1_ltsm_train_error(core_die1_ltsm_train_error),

    .die0_grant_ltsm(core_die0_grant_ltsm),
    .die0_grant_rdi(core_die0_grant_rdi),
    .die0_grant_fdi(core_die0_grant_fdi),
    .die1_grant_ltsm(core_die1_grant_ltsm),
    .die1_grant_rdi(core_die1_grant_rdi),
    .die1_grant_fdi(core_die1_grant_fdi),

    .die0_tx_valid(core_die0_tx_valid),
    .die0_tx_msg(core_die0_tx_msg),
    .die0_tx_ready(core_die0_tx_ready),
    .die1_tx_valid(core_die1_tx_valid),
    .die1_tx_msg(core_die1_tx_msg),
    .die1_tx_ready(core_die1_tx_ready),

    .die0_tx_fire(),
    .die1_tx_fire(),
    .die0_rx_fire(),
    .die1_rx_fire(),
    .die0_tx_locked(),
    .die1_tx_locked(),
    .die0_rx_drop_unknown(),
    .die1_rx_drop_unknown(),
    .progress_signature(core_progress_signature),
    .grant_mask(),
    .both_ltsm_active(),
    .both_fdi_wait_protocol(),
    .any_internal_transfer(),
    .any_train_error(),
    .any_unknown_drop(core_any_unknown_drop),
    .all_active(core_all_active),
    .serial_wire_activity(core_serial_wire_activity),
    .serial_idle(core_serial_idle),
    .serial_error(core_serial_error),
    .wire_completed_0_to_1(core_wire_completed_0_to_1),
    .wire_completed_1_to_0(core_wire_completed_1_to_0)
  );

  always_comb begin
    done = core_all_active && core_serial_idle && !core_serial_error &&
           (serialDrainCount >= SERIAL_DRAIN_CYCLES);
    protocol_active_issued = protocolActiveIssued;
    stalled_source_mask = {stalled10Seen, stalled01Seen};
    message_stability_error = messageStabilityError;
    train_error = core_die0_ltsm_train_error || core_die1_ltsm_train_error;
    no_progress_timeout = noProgressCount >= NO_PROGRESS_CYCLES;
    cycle_timeout = !done && (cycleCount >= MAX_CYCLES);
    cycle_count = cycleCount;
    serial_idle = core_serial_idle;
    serial_error = core_serial_error;
    wire_completed_0_to_1 = core_wire_completed_0_to_1;
    wire_completed_1_to_0 = core_wire_completed_1_to_0;

    die0_ltsm_state = core_die0_ltsm_state;
    die1_ltsm_state = core_die1_ltsm_state;
    die0_mbtrain_state = core_die0_mbtrain_state;
    die1_mbtrain_state = core_die1_mbtrain_state;
    die0_mbtrain_active_substate = core_die0_mbtrain_active_substate;
    die1_mbtrain_active_substate = core_die1_mbtrain_active_substate;
    die0_ltsm_visited_mask = die0LtsmVisited;
    die1_ltsm_visited_mask = die1LtsmVisited;
    die0_mbtrain_visited_mask = die0MbtrainVisited;
    die1_mbtrain_visited_mask = die1MbtrainVisited;
    unknown_drop_error = unknownDropError;
    die0_rdi_state = core_die0_rdi_state;
    die1_rdi_state = core_die1_rdi_state;
    die0_fdi_state = core_die0_fdi_state;
    die1_fdi_state = core_die1_fdi_state;
    die0_fdi_init_state = core_die0_fdi_init_state;
    die1_fdi_init_state = core_die1_fdi_init_state;
  end
endmodule

`default_nettype wire
