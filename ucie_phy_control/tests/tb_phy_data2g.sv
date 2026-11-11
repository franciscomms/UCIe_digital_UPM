`timescale 1ns/1ps
// =============================================================================
// tb_phy_data2g - self-checking testbench for PhyPatternData2g
// =============================================================================
// Drives lane_id_ena asynchronously (off the 2 GHz edges) and checks
// {cmd_ack_o, digControl, laneID_index} on every falling edge of clock_tx2g.
//
// Tests:
//   1. Reset and lane_id_ena = 0 keep all outputs low
//   2. Full burst: 130 iterations of LSB/MSB (260 cycles), then ack held
//      until lane_id_ena = 0
//   3. lane_id_ena dropped mid-burst: outputs low at once, no ack
//   4. Next lane_id_ena after an abort sends a complete burst again
// Always checked: laneID_index only with digControl; ack never with digControl.
// =============================================================================
module tb_phy_data2g;
  localparam integer ITERATIONS = 130;
  localparam integer SYNC_WAIT  = 6;    // synchronizer + output register latency

  logic clock_tx2g = 1'b0;
  logic reset_n = 1'b0;
  logic lane_id_ena = 1'b0;
  logic [3:0] lane_id_i = 4'h0;
  wire  [3:0] lane_id_o;
  wire  cmd_ack_o, digControl, laneID_index;

  always #0.25 clock_tx2g = ~clock_tx2g;   // 2 GHz

  PhyPatternData2g #(.ITERATIONS(ITERATIONS)) dut (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n), .lane_id_ena(lane_id_ena),
    .lane_id_i(lane_id_i), .cmd_ack_o(cmd_ack_o), .digControl(digControl),
    .laneID_index(laneID_index), .lane_id_o(lane_id_o)
  );

  // ---------------------------------------------------------------------------
  // Monitor: output combinations that must never happen.
  // ---------------------------------------------------------------------------
  always @(negedge clock_tx2g) begin
    if (laneID_index && !digControl) $fatal(1, "laneID_index high without digControl");
    if (cmd_ack_o && digControl)     $fatal(1, "cmd_ack_o high while sending");
    if (lane_id_o !== lane_id_i)     $fatal(1, "lane_id_o (%h) != lane_id_i (%h)", lane_id_o, lane_id_i);
  end

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  task automatic async_delay(); #0.09; endtask   // change inputs between edges

  // Check {ack, digControl, index} == exp for n cycles.
  task automatic hold_out(input logic [2:0] exp, input integer n, input string msg);
    repeat (n) begin
      @(negedge clock_tx2g);
      if ({cmd_ack_o, digControl, laneID_index} !== exp)
        $fatal(1, "%s: expected %b, got %b", msg, exp, {cmd_ack_o, digControl, laneID_index});
    end
  endtask

  // Wait for digControl to rise (start of a burst).
  task automatic wait_start(input string msg);
    integer n = 0;
    @(negedge clock_tx2g);
    while (!digControl) begin
      if (++n > SYNC_WAIT) $fatal(1, "%s: digControl did not rise", msg);
      @(negedge clock_tx2g);
    end
  endtask

  // Check a full burst from its first cycle: LSB, MSB x ITERATIONS, then ack.
  task automatic check_burst(input string msg);
    for (int i = 0; i < ITERATIONS; i++) begin
      if (i > 0) @(negedge clock_tx2g);
      if ({cmd_ack_o, digControl, laneID_index} !== 3'b010)
        $fatal(1, "%s: iteration %0d LSB, got %b", msg, i, {cmd_ack_o, digControl, laneID_index});
      @(negedge clock_tx2g);
      if ({cmd_ack_o, digControl, laneID_index} !== 3'b011)
        $fatal(1, "%s: iteration %0d MSB, got %b", msg, i, {cmd_ack_o, digControl, laneID_index});
    end
    hold_out(3'b100, 1, {msg, ": ack right after last iteration"});
  endtask

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------
  initial begin
    // 1. Reset and lane_id_ena = 0 --------------------------------------------
    // DUT reset reaches the flops at the first clock edge (reset synchronizer).
    #2   if ({cmd_ack_o, digControl, laneID_index} !== 3'b000) $fatal(1, "Reset: outputs not low");
    #3.1 reset_n = 1'b1;
    hold_out(3'b000, 20, "Idle with lane_id_ena=0");
    $display("PASS 1: reset and lane_id_ena=0 keep outputs low");

    // 1b. Lane ID pass-through: every value reaches the PHY -------------------
    for (int v = 0; v < 16; v++) begin
      async_delay(); lane_id_i = v[3:0];
      #0.01 if (lane_id_o !== v[3:0]) $fatal(1, "Pass-through: lane_id_o=%h, expected %h", lane_id_o, v);
    end
    async_delay(); lane_id_i = 4'hA;   // keep a non-zero ID for the bursts
    $display("PASS 1b: lane_id_i -> lane_id_o pass-through");

    // 2. Full burst, ack held until lane_id_ena = 0 ---------------------------
    async_delay(); lane_id_ena = 1;
    wait_start("Burst");
    check_burst("Burst");
    hold_out(3'b100, 50, "Ack held while lane_id_ena=1");
    async_delay(); lane_id_ena = 0;
    repeat (SYNC_WAIT) @(negedge clock_tx2g);
    hold_out(3'b000, 20, "Ack dropped after lane_id_ena=0");
    $display("PASS 2: %0d iterations (%0d UI), ack handshake", ITERATIONS, ITERATIONS * 16);

    // 3. Abort mid-burst ------------------------------------------------------
    async_delay(); lane_id_ena = 1;
    wait_start("Abort burst");
    repeat (101) @(negedge clock_tx2g);
    async_delay(); lane_id_ena = 0;
    repeat (SYNC_WAIT) @(negedge clock_tx2g);
    hold_out(3'b000, 2 * ITERATIONS + 20, "Aborted: outputs low, no ack");
    $display("PASS 3: lane_id_ena=0 mid-burst stops at once, no ack");

    // 4. Full burst again after an abort ---------------------------------------
    async_delay(); lane_id_ena = 1;
    wait_start("Burst after abort");
    check_burst("Burst after abort");
    async_delay(); lane_id_ena = 0;
    repeat (SYNC_WAIT) @(negedge clock_tx2g);
    hold_out(3'b000, 10, "Idle after burst");
    $display("PASS 4: complete burst after an abort");

    $display("ALL TESTS PASSED");
    $finish;
  end

  initial begin
    #10000;
    $fatal(1, "Timeout");
  end
endmodule
