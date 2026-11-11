`timescale 1ps/1ps
`default_nettype none

// Behavioral PHY fixture. An ordered fence is retained until separate,
// deliberately different per-lane serializer-drain delays have elapsed.
// The real800MHz source half and real500MHz/2GHz endpoints are connected
// through unequal170-610ps wire delays. Tests do not model metastability.
module phy_control_case #(
  parameter bit IS_500 = 1'b1,
  parameter integer DST_HALF_PS = 1000
);
  localparam integer LANES = 3;
  localparam integer WIDTH = LANES + 18;
  logic src_clk = 0, dst_clk = 0, arst_n = 0;
  always #625 src_clk = ~src_clk;
  initial begin #173; forever #(DST_HALF_PS) dst_clk = ~dst_clk; end
  wire src_rst_n, dst_rst_n;
  Ltsm800ResetSync u_sreset(src_clk, arst_n, src_rst_n);

  logic src_valid = 0;
  wire src_ready, src_done, src_aborted;
  logic [WIDTH-1:0] src_data = 0;
  wire dst_valid, dst_ready, complete, aborted;
  wire [WIDTH-1:0] dst_data;
  logic cancel_src = 0;
  wire cancel_dst, req_at_endpoint;
  wire req_src,req_dst,ack_src,ack_dst,abort_src,abort_dst,cancel_wire;
  wire [WIDTH-1:0] payload_src,payload_dst;
  assign #170 req_dst=req_src;
  assign #430 payload_dst=payload_src;
  assign #390 cancel_wire=cancel_src;
  assign #220 ack_src=ack_dst;
  assign #610 abort_src=abort_dst;
  Ltsm800CommandSource #(.WIDTH(WIDTH)) u_source (
    .src_clk_i(src_clk), .src_rst_ni(src_rst_n), .src_valid_i(src_valid),
    .src_ready_o(src_ready), .src_data_i(src_data), .src_done_o(src_done),
    .src_aborted_o(src_aborted), .link_req_o(req_src),.link_payload_o(payload_src),
    .link_ack_async_i(ack_src),.link_aborted_async_i(abort_src)
  );
  wire active, valid, last, fire, seed, clk_on, fence_valid, fence_fire;
  wire [1:0] kind;
  wire [LANES-1:0] mask;
  logic [LANES-1:0] lane_ready = '0, fence_ready = '0, retire_toggle = '0;
  if(IS_500) begin : g500
    PhyPatternTx500 #(.LANES(LANES)) u_endpoint(
      .clock_tx500(dst_clk),.reset_n(arst_n),.reset_tx500_n(dst_rst_n),
      .cmd_req_async_i(req_dst),.cmd_payload_async_i(payload_dst),
      .cmd_cancel_async_i(cancel_wire),.cmd_ack_o(ack_dst),.cmd_aborted_o(abort_dst),
      .phy500_word_ready(lane_ready),.phy500_fence_ready(fence_ready),
      .phy500_retire_toggle(retire_toggle),.phy500_active(active),
      .phy500_lane_mask(mask),.phy500_word_valid(valid),.phy500_word_last(last),
      .phy500_word_fire(fire),.phy500_seed_load(seed),
      .phy500_fence_valid(fence_valid),.phy500_fence_fire(fence_fire)
    );
    assign kind=2'd3;
    assign clk_on=1'b0;
    assign dst_valid=u_endpoint.cmd_valid;
    assign dst_ready=u_endpoint.cmd_ready;
    assign dst_data=u_endpoint.cmd_payload_q;
    assign complete=u_endpoint.complete;
    assign aborted=u_endpoint.aborted;
    assign cancel_dst=u_endpoint.cancel_sync;
    assign req_at_endpoint=u_endpoint.req_sync;
  end else begin : g2g
    wire data_start;
    logic previous_ack=0;
    PhyPatternData2g #(.LANES(LANES)) u_endpoint(
      .clock_tx2g(dst_clk),.reset_n(arst_n),.reset_data2g_n(dst_rst_n),
      .cmd_req_async_i(req_dst),.cmd_lane_mask_async_i(payload_dst[WIDTH-1:18]),
      .cmd_cancel_async_i(cancel_wire),.cmd_ack_o(ack_dst),.cmd_aborted_o(abort_dst),
      .phy_data_byte_ready(lane_ready),.phy_data_fence_ready(fence_ready),
      .phy_data_retire_toggle(retire_toggle),.phy_data_active(active),
      .phy_data_lane_mask(mask),.phy_data_start(data_start),
      .phy_data_byte_valid(valid),.phy_data_byte_last(last),.phy_data_byte_fire(fire),
      .phy_data_fence_valid(fence_valid),.phy_data_fence_fire(fence_fire)
    );
    always @(posedge dst_clk or negedge dst_rst_n)
      if(!dst_rst_n) previous_ack<=0; else previous_ack<=ack_dst;
    assign seed=1'b0;
    assign kind=2'd2;
    assign clk_on=1'b0;
    assign dst_valid=data_start;
    assign dst_ready=1'b1;
    assign dst_data={mask,16'd256,2'd2};
    assign complete=ack_dst && !previous_ack;
    assign aborted=abort_dst;
    assign cancel_dst=u_endpoint.cancel_sync;
    assign req_at_endpoint=u_endpoint.req_sync;
  end

  integer beats=0, fences=0, completions=0, commands=0, seeds=0, src_dones=0;
  integer highs=0, lows=0, cycle=0, expected_units=0;
  logic expected_abort=0, allow_completion=0, stall=0, zero_ready=0;
  logic [WIDTH-1:0] expected_command='0;
  logic prev_done=0;
  always @(negedge dst_clk) begin
    cycle = cycle + 1;
    if (zero_ready) lane_ready = '0;
    else if (stall) begin
      lane_ready[0] = ((cycle % 5) != 0);
      lane_ready[1] = ((cycle % 7) != 0);
      lane_ready[2] = ((cycle % 3) != 0);
    end else lane_ready = '1;
    fence_ready = ((cycle % 4) == 0) ? 3'b000 : 3'b111;
  end
  always @(posedge dst_clk) if (dst_rst_n) begin
    if (dst_valid && dst_ready) begin
      commands++;
      if (dst_data !== expected_command) $fatal(1,"Captured command corrupted");
    end
    if (seed) seeds++;
    if (fire) begin
      if (cancel_dst) $fatal(1,"Accepted data after local cancellation");
      if ((lane_ready & mask) !== mask) $fatal(1,"Accepted before all active lanes ready");
      if (beats >= expected_units) $fatal(1,"Excess accepted unit");
      if (last !== (beats == expected_units-1)) $fatal(1,"Last marker is off by one");
      if (kind == 2'd0) begin
        if (clk_on !== ((beats % 24) < 16)) $fatal(1,"Clock repair phase mismatch");
        if (clk_on) highs++; else lows++;
      end
      beats++;
    end
    if (fence_fire) begin
      fences++;
      if ((fence_ready & mask) !== mask) $fatal(1,"Fence accepted non-atomically");
      if (fences != 1) $fatal(1,"Duplicate fence");
      if (!expected_abort && beats != expected_units) $fatal(1,"Fence before final unit");
    end
    if (complete) begin
      completions++;
      if (!allow_completion) $fatal(1,"Completion before final lane physically drained");
      if (fences != 1) $fatal(1,"Completion missing fence");
      if (aborted !== expected_abort) $fatal(1,"Wrong local abort status");
    end
  end
  always @(posedge src_clk) if (src_rst_n) begin
    if (src_done) begin
      src_dones++;
      if (prev_done) $fatal(1,"Completion lasted more than one source cycle");
      if (src_aborted !== expected_abort) $fatal(1,"Wrong returned abort status");
      if (!allow_completion) $fatal(1,"Premature source completion");
    end
    prev_done = src_done;
  end

  task automatic send(input logic[1:0] k,input integer n,input logic[LANES-1:0] m);
    wait(src_ready);
    @(negedge src_clk);
    expected_command = {m,16'(n),k};
    src_data = expected_command;
    src_valid = 1;
    @(negedge src_clk);
    src_valid = 0;
    // Deliberate post-accept changes verify that the mailbox really holds it.
    src_data = ~expected_command;
  endtask

  task automatic retire_selected(input logic[LANES-1:0] m);
    wait(fences == 1);
    repeat(9) @(negedge dst_clk);
    if (src_dones != 0 || completions != 0) $fatal(1,"Done during serializer buffering");
    for(integer j=0;j<LANES;j++) begin
      if (m[j]) begin
        #137;
        retire_toggle[j] = ~retire_toggle[j];
        if ((m >> (j+1)) == 0) allow_completion=1;
        repeat(9+j) @(negedge dst_clk);
        if ((m >> (j+1)) != 0 && (src_dones != 0 || completions != 0))
          $fatal(1,"One lane completion incorrectly completed group");
      end
    end
    wait(src_dones == 1);
    // Directed cancellation tail: request has returned low but the source
    // deliberately keeps cancellation asserted. The endpoint must retain ack
    // until cancellation has also traversed its synchronizer and fallen.
    // This is source protocol delay; the physical cancel wire remains390ps.
    if(expected_abort) begin
      wait(!req_at_endpoint);
      repeat(4) begin
        @(negedge dst_clk);
        if(!ack_dst || !cancel_dst || src_ready)
          $fatal(1,"Endpoint released acknowledgment before cancellation returned low");
      end
      $display("PASS endpoint%0d acknowledgment held through cancellation tail",IS_500?500:2000);
    end
    @(negedge src_clk); cancel_src = 0;
    wait(src_ready);
    repeat(14) @(negedge src_clk);
    if (src_dones != 1 || completions != 1 || commands != 1 || fences != 1)
      $fatal(1,"Command/completion is not exactly once");
  endtask

  task automatic reset_case(input integer n,input bit a);
    wait(src_ready && !active);
    @(negedge src_clk);
    beats=0; fences=0; completions=0; commands=0; seeds=0; src_dones=0;
    highs=0; lows=0; expected_units=n; expected_abort=a; allow_completion=0;
  endtask

  task automatic run_burst(input logic[1:0] k,input integer n,input logic[LANES-1:0] m,input bit stalled);
    reset_case(n,0); stall=stalled; zero_ready=0;
    send(k,n,m);
    retire_selected(m);
    if (beats != n) $fatal(1,"Incorrect length: %0d vs %0d",beats,n);
    if (seeds != ((k==2'd3)?1:0)) $fatal(1,"Unexpected seed event count");
    if (k==0 && (highs!=2048 || lows!=1024)) $fatal(1,"Wrong repair total on/off cycles");
    $display("PASS endpoint%0d kind=%0d units=%0d mask=%b stalled=%0d",IS_500?500:2000,k,n,m,stalled);
  endtask

  task automatic run_abort(input bit before_data);
    logic [1:0] k;
    integer at_cancel;
    k = IS_500 ? 2'd3 : 2'd2;
    reset_case(IS_500?128:256,1); stall=1; zero_ready=before_data;
    if (before_data) begin
      @(negedge src_clk); cancel_src=1;
      repeat(8) @(negedge dst_clk);
    end
    send(k,IS_500?128:256,3'b111);
    if (!before_data) begin
      wait(beats>=13);
      @(negedge src_clk); cancel_src=1;
    end
    wait(cancel_dst);
    @(negedge dst_clk); at_cancel=beats;
    repeat(5) @(negedge dst_clk);
    if (beats != at_cancel) $fatal(1,"Local abort did not stop acceptance");
    if (before_data && beats != 0) $fatal(1,"Pre-cancel burst sent data");
    if (!before_data && (beats == 0 || beats >= (IS_500?128:256))) $fatal(1,"Midburst abort setup failed");
    retire_selected(3'b111);
    zero_ready=0;
    $display("PASS endpoint%0d abort before_data=%0d accepted=%0d",IS_500?500:2000,before_data,beats);
    // Same mode next: stale retirement toggles must not satisfy a new fence.
    run_burst(k,IS_500?128:256,3'b111,1);
  endtask

  task automatic run_all;
    #111; arst_n=0;
    #1700; arst_n=1;
    wait(src_rst_n && dst_rst_n);
    repeat(7) @(negedge src_clk);
    if (src_done || complete || active) $fatal(1,"Reset generated phantom transaction");
    if (IS_500) begin
      run_burst(3,128,3'b111,0);
      run_burst(3,128,3'b101,1);
    end else begin
      run_burst(2,256,3'b111,1);
      run_burst(2,256,3'b101,1);
    end
    run_abort(0);
    run_abort(1);
  endtask
endmodule

module tb_data_lfsr;
  phy_control_case #(.IS_500(1),.DST_HALF_PS(1000)) test500();
  phy_control_case #(.IS_500(0),.DST_HALF_PS(250)) test2g();
  logic fclk=0, frst_n=0, fvalid=0, fempty=0;
  wire fready, ftoggle;
  always #250 fclk=~fclk;
  PhyTxSerializerFence u_terminal(
    .clk_i(fclk),.rst_ni(frst_n),.fence_valid_i(fvalid),
    .fence_ready_o(fready),.serializer_empty_i(fempty),.retire_toggle_o(ftoggle)
  );
  task automatic terminal_test;
    #1000; frst_n=1;
    @(negedge fclk); fvalid=1;
    repeat(13) @(negedge fclk);
    if(ftoggle || fready) $fatal(1,"Terminal accepted fence before empty");
    fempty=1;
    @(negedge fclk); fvalid=0;
    if(!ftoggle) $fatal(1,"Terminal did not retire fence after empty");
    repeat(8) @(negedge fclk);
    if(!ftoggle) $fatal(1,"Terminal duplicated toggle");
    fempty=0; fvalid=1;
    repeat(4) @(negedge fclk);
    fempty=1;
    @(negedge fclk); fvalid=0;
    if(ftoggle) $fatal(1,"Second fence did not produce second toggle");
    $display("PASS serializer fence waits for real drain and retires exactly once");
  endtask
  initial begin
    fork
      test500.run_all();
      test2g.run_all();
      terminal_test();
    join
    $display("DATA_LFSR_REGRESSION_PASS");
    $finish;
  end
  initial begin #100000000; $fatal(1,"Regression timeout"); end
endmodule
`default_nettype wire
