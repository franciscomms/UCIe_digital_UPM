`timescale 1ps/1ps
`default_nettype none
module tb_ltsm_specialized;
  logic clock=0, clock_tx500=0, clock_tx2g=0, reset_n=0;
  always #625 clock=~clock;
  initial begin #121; forever #1000 clock_tx500=~clock_tx500; end
  initial begin #87; forever #250 clock_tx2g=~clock_tx2g; end
  logic [3:0] ltsm_state=0, ltsm_dbg_mbtrainState=0;
  logic [2:0] ltsm_dbg_mbinitSubstate=0;
  logic [1:0] ltsm_data_lane_mask=2'b11;
  logic [8:0] req=0;
  wire [8:0] done;
  wire busy, aborted;
  wire [2:0] errors;
  wire reset_ltsm_n,reset_tx500_n,reset_tx2g_n;
  logic [1:0] phy500_word_ready=0, phy500_fence_ready=3,phy500_retire_toggle=0;
  wire phy500_active,phy500_word_valid,phy500_word_last,phy500_word_fire;
  wire phy500_seed_load,phy500_fence_valid,phy500_fence_fire;
  wire [1:0] phy500_lane_mask;
  logic [1:0] phy2g_unit_ready=0,phy2g_fence_ready=3,phy2g_retire_toggle=0;
  wire phy2g_active,phy2g_start,phy2g_unit_valid,phy2g_unit_last,phy2g_unit_fire;
  wire phy2g_fence_valid,phy2g_fence_fire;
  wire [1:0] phy2g_kind,phy2g_lane_mask;
  // Explicitly instantiate all five real production tops. Signal aliases
  // below serve only the common scoreboard; no generic2GHz engine exists.
  wire reset_data2g_n,reset_valid2g_n,reset_clock2g_n;
  wire phy_data_active,phy_data_start,phy_data_byte_valid,phy_data_byte_last;
  wire phy_data_byte_fire,phy_data_fence_valid,phy_data_fence_fire;
  wire [1:0] phy_data_lane_mask;
  // VALID/CLOCK are level controls to the analog front end.
  wire phyTrainLfsr,phyTrainValid,phyTrainLaneid,phyDigControl;
  wire phy_valid_active,phy_clock_active;
  logic prev_valid_on=0,prev_clock_on=0;
  wire req500_src,req500_dst,cancel500_src,cancel500_dst;
  wire ack500_src,ack500_dst,aborted500_src,aborted500_dst;
  assign #170 req500_dst=req500_src;
  assign #390 cancel500_dst=cancel500_src;
  assign #220 ack500_src=ack500_dst;
  assign #610 aborted500_src=aborted500_dst;
  wire reqdata2g_src,reqdata2g_dst,canceldata2g_src,canceldata2g_dst;
  wire ackdata2g_src,ackdata2g_dst,aborteddata2g_src,aborteddata2g_dst;
  assign #170 reqdata2g_dst=reqdata2g_src;
  assign #390 canceldata2g_dst=canceldata2g_src;
  assign #220 ackdata2g_src=ackdata2g_dst;
  assign #610 aborteddata2g_src=aborteddata2g_dst;
  wire reqvalid2g_src,reqvalid2g_dst,cancelvalid2g_src,cancelvalid2g_dst;
  wire ackvalid2g_src,ackvalid2g_dst,abortedvalid2g_src,abortedvalid2g_dst;
  assign #170 reqvalid2g_dst=reqvalid2g_src;
  assign #390 cancelvalid2g_dst=cancelvalid2g_src;
  assign #220 ackvalid2g_src=ackvalid2g_dst;
  assign #610 abortedvalid2g_src=abortedvalid2g_dst;
  wire reqclock2g_src,reqclock2g_dst,cancelclock2g_src,cancelclock2g_dst;
  wire ackclock2g_src,ackclock2g_dst,abortedclock2g_src,abortedclock2g_dst;
  assign #170 reqclock2g_dst=reqclock2g_src;
  assign #390 cancelclock2g_dst=cancelclock2g_src;
  assign #220 ackclock2g_src=ackclock2g_dst;
  assign #610 abortedclock2g_src=abortedclock2g_dst;
  wire [19:0] payload500_src,payload500_dst;
  wire [1:0] data_mask_src,data_mask_dst;
  assign #430 payload500_dst=payload500_src;
  assign #430 data_mask_dst=data_mask_src;
  LtsmPhyPatternCtrl800 #(.LANES(2)) u_source (
    .clock(clock),
    .reset_n(reset_n),
    .ltsm_state(ltsm_state),
    .ltsm_dbg_mbinitSubstate(ltsm_dbg_mbinitSubstate),
    .ltsm_dbg_mbtrainState(ltsm_dbg_mbtrainState),
    .ltsm_data_lane_mask(ltsm_data_lane_mask),
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
    .ltsm_pattern_aborted(aborted),
    .ltsm_pattern_error(errors),
    .reset_ltsm_n(reset_ltsm_n),
    .tx500_req_o(req500_src),
    .tx500_payload_o(payload500_src),
    .tx500_cancel_o(cancel500_src),
    .tx500_ack_i(ack500_src),
    .tx500_aborted_i(aborted500_src),
    .txdata2g_req_o(reqdata2g_src),
    .txdata2g_lane_mask_o(data_mask_src),
    .txdata2g_cancel_o(canceldata2g_src),
    .txdata2g_ack_i(ackdata2g_src),
    .txdata2g_aborted_i(aborteddata2g_src),
    .txvalid2g_req_o(reqvalid2g_src),
    .txvalid2g_cancel_o(cancelvalid2g_src),
    .txvalid2g_ack_i(ackvalid2g_src),
    .txvalid2g_aborted_i(abortedvalid2g_src),
    .txclock2g_req_o(reqclock2g_src),
    .txclock2g_cancel_o(cancelclock2g_src),
    .txclock2g_ack_i(ackclock2g_src),
    .txclock2g_aborted_i(abortedclock2g_src)
  );
  PhyPatternTx500 #(.LANES(2)) u_500 (
    .clock_tx500(clock_tx500),
    .reset_n(reset_n),
    .cmd_req_async_i(req500_dst),
    .cmd_payload_async_i(payload500_dst),
    .cmd_cancel_async_i(cancel500_dst),
    .cmd_ack_o(ack500_dst),
    .cmd_aborted_o(aborted500_dst),
    .reset_tx500_n(reset_tx500_n),
    .phy500_word_ready(phy500_word_ready),
    .phy500_fence_ready(phy500_fence_ready),
    .phy500_retire_toggle(phy500_retire_toggle),
    .phy500_active(phy500_active),
    .phy500_lane_mask(phy500_lane_mask),
    .phy500_word_valid(phy500_word_valid),
    .phy500_word_last(phy500_word_last),
    .phy500_word_fire(phy500_word_fire),
    .phy500_seed_load(phy500_seed_load),
    .phy500_fence_valid(phy500_fence_valid),
    .phy500_fence_fire(phy500_fence_fire)
  );
  PhyPatternData2g #(.LANES(2)) u_data2g (
    .clock_tx2g(clock_tx2g),
    .reset_n(reset_n),
    .cmd_req_async_i(reqdata2g_dst),
    .cmd_lane_mask_async_i(data_mask_dst),
    .cmd_cancel_async_i(canceldata2g_dst),
    .cmd_ack_o(ackdata2g_dst),
    .cmd_aborted_o(aborteddata2g_dst),
    .reset_data2g_n(reset_data2g_n),
    .phy_data_byte_ready(phy2g_unit_ready),
    .phy_data_fence_ready(phy2g_fence_ready),
    .phy_data_retire_toggle(phy2g_retire_toggle),
    .phy_data_active(phy_data_active),
    .phy_data_lane_mask(phy_data_lane_mask),
    .phy_data_start(phy_data_start),
    .phy_data_byte_valid(phy_data_byte_valid),
    .phy_data_byte_last(phy_data_byte_last),
    .phy_data_byte_fire(phy_data_byte_fire),
    .phy_data_fence_valid(phy_data_fence_valid),
    .phy_data_fence_fire(phy_data_fence_fire)
  );
  PhyPatternValid2g  u_valid2g (
    .clock_tx2g(clock_tx2g),
    .reset_n(reset_n),
    .cmd_req_async_i(reqvalid2g_dst),
    .cmd_sel_async_i(3'b010), // controller issues VALTRAIN only
    .cmd_cancel_async_i(cancelvalid2g_dst),
    .cmd_ack_o(ackvalid2g_dst),
    .cmd_aborted_o(abortedvalid2g_dst),
    .reset_valid2g_n(reset_valid2g_n),
    .phyTrainLfsr(phyTrainLfsr),
    .phyTrainValid(phyTrainValid),
    .phyTrainLaneid(phyTrainLaneid)
  );
  PhyPatternClock2g  u_clock2g (
    .clock_tx2g(clock_tx2g),
    .reset_n(reset_n),
    .cmd_req_async_i(reqclock2g_dst),
    .cmd_cancel_async_i(cancelclock2g_dst),
    .cmd_ack_o(ackclock2g_dst),
    .cmd_aborted_o(abortedclock2g_dst),
    .reset_clock2g_n(reset_clock2g_n),
    .phyDigControl(phyDigControl)
  );
  assign reset_tx2g_n=reset_data2g_n && reset_valid2g_n && reset_clock2g_n;
  assign phy_valid_active=phyTrainLfsr || phyTrainValid || phyTrainLaneid;
  assign phy_clock_active=phyDigControl;
  assign phy2g_active=phy_data_active || phy_valid_active || phy_clock_active;
  assign phy2g_kind=phy_data_active?2'd2:(phy_valid_active?2'd1:2'd0);
  assign phy2g_lane_mask=phy_data_active?phy_data_lane_mask:2'b01;
  // For the level-control endpoints every high cycle is one pattern iteration;
  // the rising edge is the start and the falling edge is the finish.
  assign phy2g_start=phy_data_start || (phy_valid_active && !prev_valid_on) ||
    (phy_clock_active && !prev_clock_on);
  assign phy2g_unit_valid=phy_data_byte_valid || phy_valid_active || phy_clock_active;
  assign phy2g_unit_last=phy_data_byte_last ||
    (phy_valid_active && u_valid2g.remaining_q==1) ||
    (phy_clock_active && u_clock2g.remaining_q==1);
  assign phy2g_unit_fire=phy_data_byte_fire || phy_valid_active || phy_clock_active;
  assign phy2g_fence_valid=phy_data_fence_valid;
  assign phy2g_fence_fire=phy_data_fence_fire ||
    (!phy_valid_active && prev_valid_on) ||
    (!phy_clock_active && prev_clock_on);

  always @(posedge clock_tx2g or negedge reset_tx2g_n) begin
    if(!reset_tx2g_n) begin
      prev_valid_on<=0;prev_clock_on<=0;
    end else begin
      prev_valid_on<=phy_valid_active;prev_clock_on<=phy_clock_active;
      if(phyTrainLfsr || phyTrainLaneid) $fatal(1,"Unexpected VALID training bit selected");
      if(ackvalid2g_dst && phy_valid_active) $fatal(1,"VALID command acknowledged while pattern enabled");
      if(ackclock2g_dst && phy_clock_active) $fatal(1,"CLOCK command acknowledged while clock enabled");
    end
  end
  assert property (@(posedge clock) disable iff(!reset_ltsm_n)
    $onehot0({phy500_active,phy_data_active,phy_valid_active,phy_clock_active}));

  integer words500=0, units2g=0, fence500=0,fence2g=0,seed_count=0,start2g=0;
  integer finish_count=0,abort_count=0, cycles500=0,cycles2g=0;
  integer delay500[2]='{0,0},delay2g[2]='{0,0};
  integer expected_count=0,expected_kind=0;
  logic [8:0] expected_done=0;
  logic [1:0] expected_mask=3;
  logic check_exact=0,block500=0,block2g=0;
  logic [8:0] prev_done=0;
  logic prev_seed=0,prev_start=0;
  always @(negedge clock_tx500) begin
    cycles500++;
    phy500_word_ready = block500 ? 2'b00 : ((cycles500%7)==0 ? 2'b01:2'b11);
  end
  always @(negedge clock_tx2g) begin
    cycles2g++;
    // All three2GHz endpoints accept paced8bit pattern words.
    phy2g_unit_ready = block2g ? 2'b00 :
      (((cycles2g%4)!=0) ? 2'b11:2'b00);
  end
  always @(posedge clock_tx500 or negedge reset_tx500_n) begin
    if(!reset_tx500_n) begin
      phy500_retire_toggle<=0; delay500[0]<=0;delay500[1]<=0;prev_seed=0;
    end else begin
      for(integer j=0;j<2;j++) begin
        if(delay500[j]>0) begin
          delay500[j]<=delay500[j]-1;
          if(delay500[j]==1) phy500_retire_toggle[j]<=~phy500_retire_toggle[j];
        end
        if(phy500_fence_fire && phy500_lane_mask[j]) delay500[j]<=11+17*j;
      end
      if(phy500_seed_load) begin
        seed_count++;
        if(prev_seed) $fatal(1,"Seed pulse wider than one local cycle");
        if(check_exact && phy500_lane_mask!==expected_mask) $fatal(1,"Seed before lane mask captured");
      end
      prev_seed=phy500_seed_load;
      if(phy500_word_fire) begin
        words500++;
        if(check_exact) begin
          if(phy500_lane_mask!==expected_mask) $fatal(1,"Wrong500 lane mask");
          if(words500>expected_count) $fatal(1,"Excess500 words");
          if(phy500_word_last!==(words500==expected_count)) $fatal(1,"Wrong500 last");
        end
      end
      if(phy500_fence_fire) fence500++;
    end
  end
  always @(posedge clock_tx2g or negedge reset_tx2g_n) begin
    if(!reset_tx2g_n) begin
      phy2g_retire_toggle<=0;delay2g[0]<=0;delay2g[1]<=0;prev_start=0;
    end else begin
      for(integer j=0;j<2;j++) begin
        if(delay2g[j]>0) begin
          delay2g[j]<=delay2g[j]-1;
          if(delay2g[j]==1) phy2g_retire_toggle[j]<=~phy2g_retire_toggle[j];
        end
        if(phy_data_fence_fire && phy_data_lane_mask[j]) delay2g[j]<=13+21*j;
      end
      if(phy2g_start) begin
        start2g++;
        if(prev_start) $fatal(1,"Start pulse wider than one local cycle");
        if(check_exact && (phy2g_kind!==2'(expected_kind) || phy2g_lane_mask!==expected_mask))
          $fatal(1,"Start must accompany newly captured kind and mask");
      end
      prev_start=phy2g_start;
      if(phy2g_unit_fire) begin
        units2g++;
        if(check_exact) begin
          if(phy2g_kind!==2'(expected_kind)) $fatal(1,"Wrong2g kind");
          if(phy2g_lane_mask!==expected_mask) $fatal(1,"Wrong2g lane mask");
          if(units2g>expected_count) $fatal(1,"Excess2g units");
          if(phy2g_unit_last!==(units2g==expected_count)) $fatal(1,"Wrong2g last");
        end
      end
      if(phy2g_fence_fire) fence2g++;
    end
  end
  always @(posedge clock) if(reset_ltsm_n) begin
    if(|done) begin
      finish_count++;
      if(done!==expected_done) $fatal(1,"Wrong requester completed: %b expected%b",done,expected_done);
      if(|prev_done) $fatal(1,"Completion pulse repeated");
      if(delay500[0]!=0 || delay500[1]!=0 || delay2g[0]!=0 || delay2g[1]!=0 ||
         phy_valid_active || phy_clock_active)
        $fatal(1,"Source done before serializer drain");
    end
    if(aborted) abort_count++;
    prev_done=done;
  end
  task automatic clear_scores;
    words500=0;units2g=0;fence500=0;fence2g=0;seed_count=0;start2g=0;
    finish_count=0;abort_count=0;prev_done=0;
  endtask
  task automatic reset_all;
    @(negedge clock); reset_n=0;req=0;check_exact=0;block500=0;block2g=0;
    repeat(5) @(negedge clock);
    reset_n=1;
    wait(reset_ltsm_n && reset_tx500_n && reset_tx2g_n);
    repeat(6) @(negedge clock);
    clear_scores();
    if(errors!=0 || busy || (|done)) $fatal(1,"Reset left stale transaction");
  endtask
  task automatic request_pulse(input integer owner);
    @(negedge clock);req=9'b1<<owner;
    @(negedge clock);req=0;
    @(negedge clock);
  endtask
  task automatic run_route(input integer owner,input integer initstate,input integer trainstate,
                           input integer k,input integer n,input logic[1:0] m);
    wait(!busy);
    @(negedge clock);clear_scores();
    ltsm_state=4'(owner<4?5:6);ltsm_dbg_mbinitSubstate=3'(initstate);
    ltsm_dbg_mbtrainState=4'(trainstate);ltsm_data_lane_mask=m;
    expected_count=n;expected_kind=k;expected_done=9'b1<<owner;
    expected_mask=(k==0 || k==1)?2'b01:m;check_exact=1;
    @(negedge clock);req=9'b1<<owner;
    if(owner<4) begin @(negedge clock);req=0; end
    wait(finish_count==1);
    wait(!busy);
    repeat(20) @(negedge clock); // held requests must NOT retrigger
    if(finish_count!=1 || abort_count!=0 || errors!=0) $fatal(1,"Route completion/error mismatch");
    if(k==3) begin
      if(words500!=n || units2g!=0 || fence500!=1 || fence2g!=0 || seed_count!=1)
        $fatal(1,"500 route count mismatch");
    end else if(units2g!=n || words500!=0 || fence2g!=1 || fence500!=0 || start2g!=1)
      $fatal(1,"2g route count mismatch");
    req=0;
    repeat(3) @(negedge clock);
    $display("PASS LTSM owner%0d init%0d train%0d kind%0d count%0d",owner,initstate,trainstate,k,n);
  endtask
  initial begin
    reset_all();
    run_route(0,2,0,0,130,3);
    run_route(1,3,0,1,130,3);
    run_route(2,4,0,2,256,3);
    run_route(3,5,0,2,256,1);
    run_route(4,0,1,1,130,3);
    run_route(5,0,2,3,128,3);
    run_route(6,0,6,1,130,3);
    run_route(4,0,7,1,130,3);
    run_route(7,0,8,3,128,3);
    run_route(5,0,9,3,128,1);
    run_route(8,0,10,3,128,3);
    run_route(7,0,11,3,128,3);
    run_route(7,0,12,3,128,3);

    // State change aborts the active500 burst; one-cycle MBINIT request is
    // retained pending until the old source and serializer have fully drained.
    @(negedge clock);clear_scores();check_exact=0;
    ltsm_state=6;ltsm_dbg_mbtrainState=2;ltsm_dbg_mbinitSubstate=0;
    ltsm_data_lane_mask=3;req=9'b1<<5;expected_done=9'b1<<1;
    wait(words500>=12);
    @(negedge clock);ltsm_state=5;ltsm_dbg_mbinitSubstate=3;ltsm_dbg_mbtrainState=0;req=9'b1<<1;
    @(negedge clock);req=0;
    wait(finish_count==1);wait(!busy);
    repeat(8) @(negedge clock);
    if(abort_count!=1 || finish_count!=1 || words500>=128 || units2g!=130 || errors!=0)
      $fatal(1,"Queued transition lost/duplicated command");
    $display("PASS state-change abort then pending one-cycle request");

    // A held request withdrawn within the same state aborts and does not emit
    // a normal Finished pulse. Its next rising edge starts a fresh burst.
    clear_scores();ltsm_state=6;ltsm_dbg_mbtrainState=8;ltsm_dbg_mbinitSubstate=0;
    req=9'b1<<7;expected_done=9'b1<<7;
    wait(words500>=10);
    @(negedge clock);req=0;
    wait(abort_count==1);wait(!busy);
    if(finish_count!=0 || words500>=128) $fatal(1,"Held-request abort failed");
    run_route(7,0,8,3,128,3);

    reset_all();
    @(negedge clock);ltsm_state=0;ltsm_dbg_mbinitSubstate=2;
    request_pulse(0);
    repeat(20) @(negedge clock);
    if(errors!=3'b010 || busy || words500!=0 || units2g!=0 || finish_count!=0)
      $fatal(1,"Illegal context was not rejected");
    $display("PASS wrong-state command rejection");

    reset_all();
    @(negedge clock);ltsm_state=5;ltsm_dbg_mbinitSubstate=2;req=9'b11;
    @(negedge clock);req=0;
    repeat(10) @(negedge clock);
    if(errors!=3'b001 || busy) $fatal(1,"Simultaneous requests not rejected");
    $display("PASS simultaneous request rejection");

    reset_all();
    @(negedge clock);ltsm_state=5;ltsm_dbg_mbinitSubstate=4;ltsm_data_lane_mask=0;
    request_pulse(2);
    repeat(10) @(negedge clock);
    if(errors!=3'b010 || busy) $fatal(1,"Empty mask not rejected");
    $display("PASS empty mask rejection");

    reset_all();
    @(negedge clock);ltsm_state=5;ltsm_dbg_mbinitSubstate=4;ltsm_data_lane_mask=3;block2g=1;
    request_pulse(2);wait(phy2g_active);
    request_pulse(2);request_pulse(2);
    repeat(4) @(negedge clock);
    if(errors!=3'b100) $fatal(1,"Pending queue overflow not reported");
    $display("PASS pending queue overflow reporting");
    // Common reset is also tested with an active command and pending request.
    reset_all();
    repeat(25) @(negedge clock);
    if(finish_count!=0 || abort_count!=0 || busy) $fatal(1,"Reset left phantom completion");
    run_route(2,4,0,2,256,3);
    $display("LTSM_SPECIALIZED_REGRESSION_PASS");
    $finish;
  end
  initial begin #100000000; $fatal(1,"Top regression timeout"); end
endmodule
`default_nettype wire
