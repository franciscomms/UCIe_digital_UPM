`timescale 1ns/1ps
// =============================================================================
// tb_phy_tx500 - self-checking testbench for PhyPatternTx500
// =============================================================================
// Drives the Ctrl800-side inputs asynchronously (off the 500 MHz edges) and
// checks the PHY outputs and cmd_ack_o against the mode table in the DUT
// header. Outputs are sampled on the falling edge of clock_tx500.
//
// Tests:
//   1. Reset and lane_mask = 0 give OFF, even with modes/requests active
//   2. Level modes: ACTIVE, RAW, raw_data wins over active_mode
//   3. Seed handshake: single load_seed pulse, ack held until req low
//   4. Train handshake: exactly 128 TRAIN cycles, then OFF + ack until req low
//   5. Seed request / level modes are ignored during training
//   6. lane_mask = 0 aborts training (no ack); training restarts on mask = 1
//   7. Seed from ACTIVE returns to ACTIVE afterwards
// =============================================================================
module tb_phy_tx500;
  localparam integer TRAIN_WORDS = 128;

  // Output patterns: {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero}
  localparam logic [4:0] P_OFF       = 5'b0_0101;
  localparam logic [4:0] P_SEED      = 5'b0_0110;
  localparam logic [4:0] P_SEED_ACK  = 5'b1_0100;
  localparam logic [4:0] P_TRAIN     = 5'b0_1100;
  localparam logic [4:0] P_TRAIN_ACK = 5'b1_0101;
  localparam logic [4:0] P_RAW       = 5'b0_0001;
  localparam logic [4:0] P_ACTIVE    = 5'b0_1000;

  logic clock_tx500 = 1'b0;
  logic reset_n = 1'b0;
  logic req_train_lfsr = 1'b0, req_seed_load = 1'b0, lane_mask = 1'b0;
  logic active_mode = 1'b0, raw_data = 1'b0;
  wire  cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero;
  wire [4:0] out = {cmd_ack_o, enable_LFSR, zero_ena, load_seed, load_zero};

  always #1 clock_tx500 = ~clock_tx500;   // 500 MHz

  PhyPatternTx500 #(.TRAIN_WORDS(TRAIN_WORDS)) dut (
    .clock_tx500(clock_tx500), .reset_n(reset_n),
    .req_train_lfsr(req_train_lfsr), .req_seed_load(req_seed_load),
    .lane_mask(lane_mask), .active_mode(active_mode), .raw_data(raw_data),
    .cmd_ack_o(cmd_ack_o), .enable_LFSR(enable_LFSR), .zero_ena(zero_ena),
    .load_seed(load_seed), .load_zero(load_zero)
  );

  // ---------------------------------------------------------------------------
  // Monitors: count TRAIN cycles and load_seed pulses; load_seed is 1 cycle.
  // ---------------------------------------------------------------------------
  integer train_cycles = 0, seed_pulses = 0;
  logic   prev_load_seed = 1'b0;
  always @(negedge clock_tx500) begin
    if (out == P_TRAIN) train_cycles++;
    if (load_seed && !prev_load_seed) seed_pulses++;
    if (load_seed && prev_load_seed) $fatal(1, "load_seed high for more than one cycle");
    prev_load_seed = load_seed;
  end

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  function automatic string name(input logic [4:0] p);
    case (p)
      P_OFF: return "OFF";       P_SEED: return "SEED";
      P_SEED_ACK: return "SEED_ACK"; P_TRAIN: return "TRAIN";
      P_TRAIN_ACK: return "TRAIN_ACK"; P_RAW: return "RAW";
      P_ACTIVE: return "ACTIVE"; default: return "???";
    endcase
  endfunction

  // Change an input between clock edges (asynchronous to the DUT).
  task automatic async_delay(); #0.37; endtask

  // Wait until the outputs show pattern exp (within max_cycles).
  task automatic wait_out(input logic [4:0] exp, input integer max_cycles, input string msg);
    integer n = 0;
    @(negedge clock_tx500);
    while (out !== exp) begin
      if (++n > max_cycles)
        $fatal(1, "%s: expected %s (%b), got %s (%b)", msg, name(exp), exp, name(out), out);
      @(negedge clock_tx500);
    end
  endtask

  // Check the outputs keep pattern exp for n cycles.
  task automatic hold_out(input logic [4:0] exp, input integer n, input string msg);
    repeat (n) begin
      @(negedge clock_tx500);
      if (out !== exp)
        $fatal(1, "%s: expected %s (%b) to hold, got %s (%b)", msg, name(exp), exp, name(out), out);
    end
  endtask

  localparam integer SYNC_WAIT = 6;   // synchronizer + output register latency

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------
  initial begin
    // 1. Reset and lane_mask = 0 --------------------------------------------
    // DUT reset reaches the flops at the first clock edge (reset synchronizer).
    #5   if (out !== P_OFF) $fatal(1, "Reset: outputs not OFF (%b)", out);
    #5.3 reset_n = 1'b1;
    hold_out(P_OFF, 5, "After reset");
    async_delay(); active_mode = 1; raw_data = 1; req_seed_load = 1; req_train_lfsr = 1;
    hold_out(P_OFF, 20, "lane_mask=0 overrides everything");
    if (seed_pulses != 0 || train_cycles != 0) $fatal(1, "lane_mask=0: command ran");
    async_delay(); active_mode = 0; raw_data = 0; req_seed_load = 0; req_train_lfsr = 0;
    async_delay(); lane_mask = 1;
    hold_out(P_OFF, 10, "lane_mask=1, nothing selected");
    $display("PASS 1: reset and lane_mask=0 -> OFF");

    // 2. Level modes ----------------------------------------------------------
    async_delay(); active_mode = 1;
    wait_out(P_ACTIVE, SYNC_WAIT, "active_mode=1");  hold_out(P_ACTIVE, 10, "ACTIVE hold");
    async_delay(); raw_data = 1;
    wait_out(P_RAW, SYNC_WAIT, "raw_data wins");     hold_out(P_RAW, 10, "RAW hold");
    async_delay(); active_mode = 0;
    hold_out(P_RAW, 10, "RAW alone");
    async_delay(); raw_data = 0;
    wait_out(P_OFF, SYNC_WAIT, "no mode -> OFF");
    $display("PASS 2: ACTIVE, RAW, raw_data priority");

    // 3. Seed handshake -------------------------------------------------------
    seed_pulses = 0;
    async_delay(); req_seed_load = 1;
    wait_out(P_SEED, SYNC_WAIT, "seed pulse");
    wait_out(P_SEED_ACK, 1, "seed ack right after pulse");
    hold_out(P_SEED_ACK, 30, "seed ack held while req high");
    async_delay(); req_seed_load = 0;
    wait_out(P_OFF, SYNC_WAIT, "seed ack drops");
    if (seed_pulses != 1) $fatal(1, "Seed: %0d load_seed pulses, expected 1", seed_pulses);
    $display("PASS 3: seed handshake");

    // 4. Train handshake ------------------------------------------------------
    train_cycles = 0;
    async_delay(); req_train_lfsr = 1;
    wait_out(P_TRAIN, SYNC_WAIT, "train start");
    wait_out(P_TRAIN_ACK, TRAIN_WORDS, "train done");
    if (train_cycles != TRAIN_WORDS)
      $fatal(1, "Train: %0d LFSR cycles, expected %0d", train_cycles, TRAIN_WORDS);
    hold_out(P_TRAIN_ACK, 30, "train ack held while req high");
    async_delay(); req_train_lfsr = 0;
    wait_out(P_OFF, SYNC_WAIT, "train ack drops");
    hold_out(P_OFF, 10, "OFF after training");
    $display("PASS 4: train handshake, %0d words", train_cycles);

    // 5. Seed request and level modes ignored during training -----------------
    train_cycles = 0; seed_pulses = 0;
    async_delay(); req_train_lfsr = 1;
    wait_out(P_TRAIN, SYNC_WAIT, "train start (5)");
    repeat (20) @(negedge clock_tx500);
    async_delay(); req_seed_load = 1; active_mode = 1;
    wait_out(P_TRAIN_ACK, TRAIN_WORDS, "train completes despite seed/active");
    if (train_cycles != TRAIN_WORDS || seed_pulses != 0)
      $fatal(1, "Test 5: train=%0d seed=%0d", train_cycles, seed_pulses);
    hold_out(P_TRAIN_ACK, 10, "train ack holds while seed pending");
    async_delay(); req_train_lfsr = 0;
    wait_out(P_SEED, SYNC_WAIT + 1, "pending seed runs after train");
    wait_out(P_SEED_ACK, 1, "seed ack (5)");
    async_delay(); req_seed_load = 0;
    wait_out(P_ACTIVE, SYNC_WAIT, "back to ACTIVE after seed");
    async_delay(); active_mode = 0;
    wait_out(P_OFF, SYNC_WAIT, "OFF (5)");
    $display("PASS 5: seed and level modes ignored during training");

    // 6. lane_mask = 0 aborts training; restart on mask = 1 -------------------
    train_cycles = 0;
    async_delay(); req_train_lfsr = 1;
    wait_out(P_TRAIN, SYNC_WAIT, "train start (6)");
    repeat (50) @(negedge clock_tx500);
    async_delay(); lane_mask = 0;
    wait_out(P_OFF, SYNC_WAIT, "mask=0 aborts training");
    hold_out(P_OFF, 20, "aborted: OFF, no ack");
    if (train_cycles >= TRAIN_WORDS) $fatal(1, "Test 6: training not aborted");
    train_cycles = 0;
    async_delay(); lane_mask = 1;
    wait_out(P_TRAIN, SYNC_WAIT, "train restarts");
    wait_out(P_TRAIN_ACK, TRAIN_WORDS, "restarted train done");
    if (train_cycles != TRAIN_WORDS)
      $fatal(1, "Test 6: restart ran %0d cycles", train_cycles);
    async_delay(); req_train_lfsr = 0;
    wait_out(P_OFF, SYNC_WAIT, "OFF (6)");
    $display("PASS 6: lane_mask=0 aborts training, full restart");

    // 7. Seed from ACTIVE returns to ACTIVE -----------------------------------
    seed_pulses = 0;
    async_delay(); active_mode = 1;
    wait_out(P_ACTIVE, SYNC_WAIT, "ACTIVE (7)");
    async_delay(); req_seed_load = 1;
    wait_out(P_SEED, SYNC_WAIT, "seed from ACTIVE");
    wait_out(P_SEED_ACK, 1, "seed ack (7)");
    async_delay(); req_seed_load = 0;
    wait_out(P_ACTIVE, SYNC_WAIT, "back to ACTIVE (7)");
    if (seed_pulses != 1) $fatal(1, "Test 7: %0d seed pulses", seed_pulses);
    $display("PASS 7: seed from ACTIVE");

    $display("ALL TESTS PASSED");
    $finish;
  end

  // Global timeout
  initial begin
    #100000;
    $fatal(1, "Timeout");
  end
endmodule
