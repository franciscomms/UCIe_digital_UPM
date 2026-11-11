`timescale 1ps/1ps
`default_nettype none
// Checks the level-control VALID/CLOCK endpoints:
//  - CLOCK drives phyDigControl, VALID drives {phyTrainLfsr,phyTrainValid,phyTrainLaneid}.
//  - A normal command keeps the selected bit(s) high for exactly 130 cycles.
//  - Cancellation mid-burst stops early; cancellation before start sends nothing.
//  - Completion returns to the source only after the bit(s) are low again.
module scalar_pattern_case #(
  parameter bit CLOCK_MODE=0,
  parameter logic [2:0] SEL=3'b010
);
  localparam integer TARGET=130;
  logic src_clk=0,clk=0,arst_n=0;
  always #625 src_clk=~src_clk;
  initial begin #173; forever #250 clk=~clk; end
  wire src_rst_n,local_rst_n;
  Ltsm800ResetSync u_reset(src_clk,arst_n,src_rst_n);
  logic src_valid=0,cancel_src=0;
  wire src_ready,src_done,src_aborted;
  wire req_src,req_dst,ack_src,ack_dst,abort_src,abort_dst,cancel_dst_wire;
  wire unused_payload;
  assign #170 req_dst=req_src;
  assign #390 cancel_dst_wire=cancel_src;
  assign #220 ack_src=ack_dst;
  assign #610 abort_src=abort_dst;
  Ltsm800CommandSource #(.WIDTH(1)) u_source(
    .src_clk_i(src_clk),.src_rst_ni(src_rst_n),.src_valid_i(src_valid),
    .src_ready_o(src_ready),.src_data_i(1'b0),.src_done_o(src_done),
    .src_aborted_o(src_aborted),.link_req_o(req_src),.link_payload_o(unused_payload),
    .link_ack_async_i(ack_src),.link_aborted_async_i(abort_src)
  );
  wire [2:0] bits;  // VALID: {lfsr,valid,laneid}; CLOCK: {0,phyDigControl,0}
  wire req_sync,cancel_sync;
  logic [2:0] expected_bits;
  if(CLOCK_MODE) begin : gclock
    wire phyDigControl;
    PhyPatternClock2g u_endpoint(
      .clock_tx2g(clk),.reset_n(arst_n),.cmd_req_async_i(req_dst),
      .cmd_cancel_async_i(cancel_dst_wire),.cmd_ack_o(ack_dst),.cmd_aborted_o(abort_dst),
      .reset_clock2g_n(local_rst_n),.phyDigControl(phyDigControl)
    );
    assign bits={1'b0,phyDigControl,1'b0};
    assign req_sync=u_endpoint.req_sync;
    assign cancel_sync=u_endpoint.cancel_sync;
    initial expected_bits=3'b010;
  end else begin : gvalid
    wire lfsr,valid,laneid;
    PhyPatternValid2g u_endpoint(
      .clock_tx2g(clk),.reset_n(arst_n),.cmd_req_async_i(req_dst),.cmd_sel_async_i(SEL),
      .cmd_cancel_async_i(cancel_dst_wire),.cmd_ack_o(ack_dst),.cmd_aborted_o(abort_dst),
      .reset_valid2g_n(local_rst_n),
      .phyTrainLfsr(lfsr),.phyTrainValid(valid),.phyTrainLaneid(laneid)
    );
    assign bits={lfsr,valid,laneid};
    assign req_sync=u_endpoint.req_sync;
    assign cancel_sync=u_endpoint.cancel_sync;
    initial expected_bits=SEL;
  end
  integer high_cycles=0,bursts=0,dones=0;
  logic expected_abort=0,prev_on=0,prev_done=0;
  always @(posedge clk) if(local_rst_n) begin
    // Sample the registered outputs just before this edge updates them.
    if(bits!==3'b000) begin
      if(bits!==expected_bits) $fatal(1,"Wrong control bit(s): %b expected %b",bits,expected_bits);
      if(!prev_on) bursts++;
      high_cycles++;
      if(high_cycles>TARGET) $fatal(1,"Control bit held longer than %0d cycles",TARGET);
      if(ack_dst) $fatal(1,"Command acknowledged while pattern still enabled");
    end
    prev_on=(bits!==3'b000);
  end
  always @(posedge src_clk) if(src_rst_n) begin
    if(src_done) begin
      dones++;
      if(prev_done || src_aborted!==expected_abort) $fatal(1,"Bad returned completion");
      if(bits!==3'b000) $fatal(1,"Source completion while pattern still enabled");
    end
    prev_done=src_done;
  end
  task automatic begin_case(input bit aborted_case);
    wait(src_ready);
    @(negedge src_clk);
    high_cycles=0;bursts=0;dones=0;prev_done=0;expected_abort=aborted_case;
  endtask
  task automatic send;
    @(negedge src_clk);src_valid=1;
    @(negedge src_clk);src_valid=0;
  endtask
  task automatic wait_done;
    wait(dones==1);
    @(negedge src_clk);cancel_src=0;
    wait(src_ready);
    repeat(12) @(negedge src_clk);
    if(dones!=1) $fatal(1,"Duplicate completion");
  endtask
  task automatic normal_case;
    begin_case(0);send();wait_done();
    if(high_cycles!=TARGET || bursts!=1) $fatal(1,"Expected one %0d-cycle burst, got %0d cycles in %0d bursts",TARGET,high_cycles,bursts);
    $display("PASS CLOCK=%0d SEL=%b normal burst %0d cycles",CLOCK_MODE,expected_bits,high_cycles);
  endtask
  task automatic abort_case(input bit before_start);
    begin_case(1);
    if(before_start) begin
      cancel_src=1;
      repeat(8) @(negedge clk);
    end
    send();
    if(!before_start) begin
      wait(high_cycles>=11);
      @(negedge src_clk);cancel_src=1;
    end
    wait_done();
    if(before_start && high_cycles!=0) $fatal(1,"Pre-start cancellation enabled the pattern");
    if(!before_start && (high_cycles==0 || high_cycles>=TARGET || bursts!=1)) $fatal(1,"Midburst cancellation ineffective");
    $display("PASS CLOCK=%0d SEL=%b abort before_start=%0d high=%0d",CLOCK_MODE,expected_bits,before_start,high_cycles);
    normal_case();
  endtask
  task automatic run_all;
    #1811;arst_n=1;
    wait(src_rst_n && local_rst_n);
    repeat(6) @(negedge src_clk);
    normal_case();abort_case(0);abort_case(1);
  endtask
endmodule
module tb_valid_clock2g;
  scalar_pattern_case #(.CLOCK_MODE(0),.SEL(3'b100)) valid_lfsr();
  scalar_pattern_case #(.CLOCK_MODE(0),.SEL(3'b010)) valid_valid();
  scalar_pattern_case #(.CLOCK_MODE(0),.SEL(3'b001)) valid_laneid();
  scalar_pattern_case #(.CLOCK_MODE(1)) clock();
  initial begin
    fork valid_lfsr.run_all();valid_valid.run_all();valid_laneid.run_all();clock.run_all();join
    $display("VALID_CLOCK_REGRESSION_PASS");$finish;
  end
  initial begin #100000000;$fatal(1,"Scalar endpoint timeout");end
endmodule
`default_nettype wire
