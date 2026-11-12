`timescale 1ps/1ps
`default_nettype none
// Directed test for PhyPatternClock2g (clk_train / active interface).
// Requests are driven from an asynchronous 800 MHz source clock; the
// endpoint runs on 2 GHz. Checks:
//  1. Idle: phyDigControl = 0, cmd_ack_o = 0.
//  2. Training: phyDigControl high for exactly 130 cycles in one burst, then
//     low; ack only after it is low; ack held until clk_train drops.
//  3. Active: phyDigControl goes high, ack follows it, both stay high
//     without a break until active drops, then both go low.
//  4. Active pre-empts a training in progress with no gap in the clock.
//  5. clk_train dropped early aborts the training without any ack.
module tb_clock2g;
  localparam integer TARGET=130;
  logic src_clk=0,clk=0,arst_n=0;
  always #625 src_clk=~src_clk;                      // 800 MHz source
  initial begin #173; forever #250 clk=~clk; end     // 2 GHz endpoint

  logic train_src=0,active_src=0;
  wire train_dst,active_dst,ack_dst,ack_src,local_rst_n,phyDigControl;
  // Wire delays model the CDC links between the two regions.
  assign #170 train_dst=train_src;
  assign #390 active_dst=active_src;
  assign #220 ack_src=ack_dst;

  PhyPatternClock2g dut(
    .clock_tx2g(clk),.reset_n(arst_n),.reset_clock2g_n(local_rst_n),
    .cmd_req_clk_train(train_dst),.cmd_req_active(active_dst),
    .cmd_ack_o(ack_dst),.phyDigControl(phyDigControl)
  );

  // Monitor on the 2 GHz side: count high cycles and bursts, check ack rules.
  integer high_cycles=0,bursts=0;
  logic prev_on=0,in_active=0;
  always @(posedge clk) if(local_rst_n) begin
    if(phyDigControl) begin
      if(!prev_on) bursts++;
      high_cycles++;
    end
    // In training mode the ack must never be high while the clock is on.
    if(!in_active && phyDigControl && ack_dst)
      $fatal(1,"Training acknowledged while clock still enabled");
    // Ack only rises after phyDigControl is already high (active) or low (train).
    prev_on=phyDigControl;
  end

  task automatic reset_counts;
    @(negedge clk); high_cycles=0; bursts=0;
  endtask

  // Wait n source cycles.
  task automatic src_wait(input integer n);
    repeat(n) @(negedge src_clk);
  endtask

  task automatic expect_idle(input string tag);
    if(phyDigControl!==1'b0 || ack_dst!==1'b0)
      $fatal(1,"%s: expected idle, phy=%b ack=%b",tag,phyDigControl,ack_dst);
  endtask

  // 2. Normal training.
  task automatic case_training;
    reset_counts();
    @(negedge src_clk); train_src=1;
    wait(ack_src===1'b1);
    if(phyDigControl!==1'b0) $fatal(1,"Training ack while clock on");
    if(high_cycles!=TARGET || bursts!=1)
      $fatal(1,"Training: expected one %0d-cycle burst, got %0d cycles in %0d bursts",
             TARGET,high_cycles,bursts);
    src_wait(20);                                   // ack must stay high
    if(ack_dst!==1'b1 || phyDigControl!==1'b0) $fatal(1,"Training ack not held");
    @(negedge src_clk); train_src=0;
    wait(ack_src===1'b0);
    src_wait(8); expect_idle("after training");
    if(high_cycles!=TARGET) $fatal(1,"Clock restarted after training");
    $display("PASS training: %0d cycles",high_cycles);
  endtask

  // 3. Active mode.
  task automatic case_active;
    reset_counts();
    @(negedge src_clk); active_src=1; in_active=1;
    @(posedge phyDigControl);
    if(ack_dst!==1'b0) $fatal(1,"Active ack before phyDigControl");
    wait(ack_src===1'b1);
    src_wait(300);                                  // longer than a training
    if(phyDigControl!==1'b1 || ack_dst!==1'b1 || bursts!=1)
      $fatal(1,"Active: clock/ack not held continuously (bursts=%0d)",bursts);
    @(negedge src_clk); active_src=0;
    wait(ack_src===1'b0);
    src_wait(8); in_active=0; expect_idle("after active");
    $display("PASS active: %0d continuous cycles",high_cycles);
  endtask

  // 4. Active raised during a training: clock continues with no gap.
  task automatic case_preempt;
    reset_counts();
    @(negedge src_clk); train_src=1;
    wait(high_cycles>=20);
    @(negedge src_clk); active_src=1; in_active=1;
    wait(ack_src===1'b1);
    src_wait(200);
    if(phyDigControl!==1'b1 || bursts!=1 || high_cycles<=TARGET)
      $fatal(1,"Pre-empt: clock interrupted (bursts=%0d high=%0d)",bursts,high_cycles);
    @(negedge src_clk); active_src=0; train_src=0;
    wait(ack_src===1'b0);
    src_wait(8); in_active=0; expect_idle("after pre-empt");
    $display("PASS pre-empt: %0d continuous cycles, 1 burst",high_cycles);
  endtask

  // 5. clk_train removed before the end: abort, no ack.
  task automatic case_early_drop;
    reset_counts();
    @(negedge src_clk); train_src=1;
    wait(high_cycles>=30);
    @(negedge src_clk); train_src=0;
    src_wait(20);
    expect_idle("after early drop");
    if(high_cycles>=TARGET || bursts!=1) $fatal(1,"Early drop: training not aborted");
    $display("PASS early drop: aborted after %0d cycles, no ack",high_cycles);
  endtask

  // Ack must never be seen during the early-drop case.
  logic watch_no_ack=0;
  always @(posedge clk) if(watch_no_ack && ack_dst) $fatal(1,"Ack during aborted training");

  initial begin
    #1811 arst_n=1;
    wait(local_rst_n);
    src_wait(6);
    expect_idle("after reset");                    // 1. idle
    case_training();
    case_active();
    case_preempt();
    watch_no_ack=1; case_early_drop(); watch_no_ack=0;
    case_training();                               // still works afterwards
    $display("CLOCK2G_REGRESSION_PASS");
    $finish;
  end
  initial begin #50000000; $fatal(1,"tb_clock2g timeout"); end
endmodule
`default_nettype wire
