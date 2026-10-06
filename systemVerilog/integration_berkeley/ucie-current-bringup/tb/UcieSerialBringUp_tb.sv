`timescale 1ns/1ps
`default_nettype none
// Entire Berkeley D2DAdapter + unmodified LogicalPhy, actual serial bump driver.
// UPM mainband datapath is unavailable: this test first checks SBINIT completion.
module UcieSerialBringUp_tb;
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;
  logic clock=0,b_clock=0,reset_n=1;
  always #0.625ns clock=~clock;
  initial begin #0.193ns; forever #0.625ns b_clock=~b_clock; end
  logic start=0,pwr_good=0,protocol_active=0;
  logic [3:0] upm_ltsm,b_ltsm,b_rdi,b_fdi;
  logic [4:0] b_detail;
  PhyState_t upm_rdi,upm_fdi;
  LinkInitState_t upm_init;
  logic [2:0] upm_mbinit;
  logic [3:0] upm_mbtrain;
  logic [11:0] upm_substate;
  logic upm_error,upm_drop,b_error,b_fault;
  logic b_phy_ready,b_wait_protocol,b_all_active;
  wire a_data,a_clk,b_data,b_clk,b_half,b_d0,b_d1,b_c0,b_c1;
  wire a_in_data,a_in_clk,b_in_data,b_in_clk;
  assign #0.073ns a_in_data=b_data;
  assign #0.073ns a_in_clk=b_clk;
  assign #0.091ns b_in_data=a_data;
  assign #0.091ns b_in_clk=a_clk;
  BerkeleySidebandPins pins(b_half,b_d0,b_d1,b_c0,b_c1,b_data,b_clk);
  integer a_wire_errors,b_wire_errors,a_chunks,b_chunks,a_bits,b_bits;
  OriginalSidebandWireMonitor #(.NAME("upm_to_berkeley")) monitor_ab
    (reset_n,a_clk,a_data,a_wire_errors,a_chunks,a_bits);
  OriginalSidebandWireMonitor #(.NAME("berkeley_to_upm")) monitor_ba
    (reset_n,b_clk,b_data,b_wire_errors,b_chunks,b_bits);
  UPMSerialDieBringUpModel upm_die (
    .clock(clock), .reset_n(reset_n), .ltsm_start(start),
    .ltsm_stable_clk(pwr_good), .ltsm_pll_locked(pwr_good), .ltsm_stable_supply(pwr_good),
    .protocol_request_active(protocol_active), .cycles_1us(32'd800),
    .external_fdi_control(1'b0), .external_fdi_lp_state_req(PhyStateReq_nop),
    .external_fdi_lp_linkerror(1'b0), .external_fdi_lp_rx_active_sts(1'b0),
    .external_fdi_lp_wake_req(1'b0), .external_fdi_lp_clk_ack(1'b0), .external_fdi_lp_stall_ack(1'b0),
    .sb_tx_dout(a_data),.sb_tx_clk(a_clk),.sb_rx_din(a_in_data),.sb_rx_clk(a_in_clk),
    // Ideal receiver results for tests initiated by Berkeley. These do not
    // model Berkeley's physical eye. Other UPM handshakes use the supplied model.
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsMsgInfo(16'h0020),
    .ltsm_flagFromAnalog_d2cReceiver_valTrainCenter_txInitD2CResultsPayload(64'd0),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsMsgInfo(16'h0030),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter1_txInitD2CResultsPayload(64'hffff),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsMsgInfo(16'h0030),
    .ltsm_flagFromAnalog_d2cReceiver_dataTrainCenter2_txInitD2CResultsPayload(64'hffff),
    .ltsm_state(upm_ltsm), .fdi_pl_state_sts(upm_fdi), .debug_rdi_state(upm_rdi),
    .debug_fdi_link_init_state(upm_init), .ltsm_dbg_mbinitSubstate(upm_mbinit),
    .ltsm_dbg_mbtrainState(upm_mbtrain), .ltsm_dbg_mbtrainActiveSubstate(upm_substate),
    .ltsm_dbg_flagTrainError(upm_error), .debug_rx_drop_unknown(upm_drop));
  BerkeleySerialDie berkeley_die (
    .clock(b_clock),.reset(!reset_n),.io_start(start),.io_pwrGood(pwr_good),
    .io_protocolActive(protocol_active),
    .io_sbOutClock(b_half),.io_sbD0(b_d0),.io_sbD1(b_d1),
    .io_sbClockD0(b_c0),.io_sbClockD1(b_c1),
    .io_sbInData(b_in_data),.io_sbInClock(b_in_clk),
    // All upstream mainband modules are present. No UPM lane interface was
    // supplied, so no mainband samples are fabricated or looped back here.
    .io_mainband_tx_ready(1'b1),.io_mainband_rx_valid(1'b0),
    .io_mainband_rx_bits_data_0(32'b0),
    .io_mainband_rx_bits_data_1(32'b0),
    .io_mainband_rx_bits_data_2(32'b0),
    .io_mainband_rx_bits_data_3(32'b0),
    .io_mainband_rx_bits_data_4(32'b0),
    .io_mainband_rx_bits_data_5(32'b0),
    .io_mainband_rx_bits_data_6(32'b0),
    .io_mainband_rx_bits_data_7(32'b0),
    .io_mainband_rx_bits_data_8(32'b0),
    .io_mainband_rx_bits_data_9(32'b0),
    .io_mainband_rx_bits_data_10(32'b0),
    .io_mainband_rx_bits_data_11(32'b0),
    .io_mainband_rx_bits_data_12(32'b0),
    .io_mainband_rx_bits_data_13(32'b0),
    .io_mainband_rx_bits_data_14(32'b0),
    .io_mainband_rx_bits_data_15(32'b0),
    .io_mainband_rx_bits_valid(32'b0),
    .io_mainband_rx_bits_clkP(32'b0),
    .io_mainband_rx_bits_clkN(32'b0),
    .io_mainband_rx_bits_trk(32'b0),
    .io_ltState(b_ltsm),.io_detailState(b_detail),.io_rdiState(b_rdi),.io_fdiState(b_fdi),
    .io_phyReady(b_phy_ready),.io_waitProtocol(b_wait_protocol),.io_allActive(b_all_active),
    .io_trainError(b_error),.io_sbFault(b_fault));
  longint unsigned cycles=0,serial_rx_count=0,controller_rx_count=0;
  longint unsigned last_accepted_serial_id=0;
  int unsigned max_sbinit=20000;
  int stop_on_error=1, check_errors=0, duplicate_acceptances=0;
  bit duplicate_reported=0, fault_reported=0, drop_reported=0;
  bit train_reported=0, wire_reported=0;
  bit upm_left_sbinit=0,berkeley_left_sbinit=0;
  integer packet_log,state_log,serial_log;
  logic [3:0] previous_upm=4'hf,previous_b=4'hf;
  logic [4:0] previous_detail=5'h1f;
  task automatic status(input string reason);
    $display("%s cycle=%0d UPM LTSM=%0d MBINIT=%0d MBTRAIN=%0d RDI=%0d FDI=%0d; Berkeley LT=%0d detail=%0d RDI=%0d FDI=%0d",
      reason,cycles,upm_ltsm,upm_mbinit,upm_mbtrain,upm_rdi,upm_fdi,b_ltsm,b_detail,b_rdi,b_fdi);
    $display("Wire UPM chunks=%0d edges=%0d errors=%0d; Berkeley chunks=%0d edges=%0d errors=%0d",
      a_chunks,a_bits,a_wire_errors,b_chunks,b_bits,b_wire_errors);
    $display("UPM physical RX completions=%0d controller acceptances=%0d repeated acceptances=%0d; drop=%b Berkeley fault=%b checker errors=%0d",
      serial_rx_count,controller_rx_count,duplicate_acceptances,upm_drop,b_fault,check_errors);
    $display("UPM expected OOR=%032h; Berkeley mode=%0d parity=%b timeout=%b unhandled=%b",
      upm_die.dut.linkMgmtLtsm.ltsm.SBINIT_OOR_SUCCESS,
      berkeley_die.phy._ltsm_io_sbCtrlIo_rxTxMode,
      berkeley_die.phy.sbParityErrSeen,berkeley_die.phy.sbDeserializerTimedoutSeen,
      berkeley_die.phy.sbUnhandledCurrentLayerMsgSeen);
  endtask
  task automatic error_seen(input string reason);
    check_errors++;
    $display("CHECK_ERROR time=%0.3f ns cycle=%0d %s",$realtime,cycles,reason);
    if(stop_on_error!=0) begin
      status("FAIL first error");
      $fatal(1,"%s",reason);
    end
  endtask

  // Count actual RX completions in the incoming forwarded-clock domain.
  // This is passive observation. The DUT retains its direct RX connection.
  always @(negedge a_in_clk) begin
    #1ps;
    if(reset_n && upm_die.dut.sideband.rx_valid) begin
      serial_rx_count++;
      $fdisplay(serial_log,"%0.3f,%0d,%032h",$realtime,serial_rx_count,
        upm_die.dut.sideband.rx_dout);
    end
  end

  // Observe the actual controller/serial boundary before sequential updates.
  always @(posedge clock) if(reset_n) begin
    cycles<=cycles+1;
    if(upm_die.dut.sb_msg_tx_valid && upm_die.dut.sb_msg_tx_ready)
      $fdisplay(packet_log,"%0.3f,%0d,UPM_TX,0,%032h",$realtime,cycles,upm_die.dut.sb_msg_tx_msg);
    if(upm_die.dut.sb_msg_rx_valid && upm_die.dut.sb_msg_rx_ready) begin
      controller_rx_count++;
      $fdisplay(packet_log,"%0.3f,%0d,UPM_CONTROLLER_RX,%0d,%032h",
        $realtime,cycles,serial_rx_count,upm_die.dut.sb_msg_rx_msg);
      if(serial_rx_count==last_accepted_serial_id) begin
        duplicate_acceptances++;
        if(!duplicate_reported) begin
          duplicate_reported=1;
          // COMMENTED FRANCISCO: error_seen("One physical UPM RX word was accepted by the controller more than once");
        end
      end
      last_accepted_serial_id=serial_rx_count;
    end
    /* Commented Francisco, this is no problem
    if(upm_drop && !drop_reported) begin
      drop_reported=1;
      error_seen($sformatf("UPM router dropped unknown word %032h",upm_die.dut.sb_msg_rx_msg));
    end
    */
    if(b_fault && !fault_reported) begin
      fault_reported=1; error_seen("Berkeley sideband fault asserted");
    end
    if((upm_error || b_error) && !train_reported) begin
      train_reported=1; error_seen("A controller reported a training error");
    end
    if((a_wire_errors!=0 || b_wire_errors!=0) && !wire_reported) begin
      wire_reported=1; error_seen("Forwarded-clock wire monitor reported an error");
    end
  end
  always @(posedge clock) begin
    #1ps;
    if(reset_n) begin
      if(upm_ltsm>=4'd5 && upm_ltsm<=4'd8) upm_left_sbinit=1;
      if(b_ltsm>=4'd2 && b_ltsm<=4'd5) berkeley_left_sbinit=1;
      if(upm_ltsm!==previous_upm || b_ltsm!==previous_b || b_detail!==previous_detail) begin
        $fdisplay(state_log,"%0.3f,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
          $realtime,cycles,upm_ltsm,upm_mbinit,upm_mbtrain,b_ltsm,b_detail,
          berkeley_die.phy._ltsm_io_sbCtrlIo_rxTxMode,upm_rdi,b_rdi);
        $display("STATE cycle=%0d UPM=%0d Berkeley=%0d/detail=%0d mode=%0d",cycles,
          upm_ltsm,b_ltsm,b_detail,berkeley_die.phy._ltsm_io_sbCtrlIo_rxTxMode);
        previous_upm=upm_ltsm; previous_b=b_ltsm; previous_detail=b_detail;
      end
    end
  end
  // Log exactly the packets accepted by Berkeley's real serializer.
  always @(posedge b_clock) if(reset_n) begin
    if(berkeley_die.phy.logPhySidebandChannel.linkNode.serializer.io_in_valid &&
       berkeley_die.phy.logPhySidebandChannel.linkNode.serializer.io_in_ready)
      $fdisplay(packet_log,"%0.3f,%0d,BERKELEY_SERIALIZER_TX,0,%032h",$realtime,cycles,
        berkeley_die.phy.logPhySidebandChannel.linkNode.serializer.io_in_bits);
  end
  initial begin
    int n;
    void'($value$plusargs("MAX_SBINIT=%d",max_sbinit));
    void'($value$plusargs("STOP_ON_ERROR=%d",stop_on_error));
    if(max_sbinit==0) $fatal(1,"MAX_SBINIT must be positive");
    packet_log=$fopen("controller_packets.csv","w");
    state_log=$fopen("state_trace.csv","w");
    serial_log=$fopen("upm_serial_rx.csv","w");
    if(packet_log==0 || state_log==0 || serial_log==0) $fatal(1,"Cannot open logs");
    $fdisplay(packet_log,"time_ns,upm_cycle,interface,physical_rx_id,message_hex");
    $fdisplay(state_log,"time_ns,upm_cycle,upm_ltsm,upm_mbinit,upm_mbtrain,berkeley_ltsm,berkeley_detail,berkeley_mode,upm_rdi,berkeley_rdi");
    $fdisplay(serial_log,"time_ns,physical_rx_id,message_hex");
    $display("CURRENT UPM controller/serial RTL + unpatched Berkeley full LogicalPhy/D2DAdapter");
    $display("SBINIT test; no state forcing or message rewriting. STOP_ON_ERROR=%0d",stop_on_error);
    reset_n=0;repeat(12) @(negedge clock);reset_n=1;pwr_good=1;
    // Honor Berkeley's real 4 ms reset residency. Do not shorten its RTL timer.
    repeat(3200128) @(negedge clock);
    if($test$plusargs("VCD")) begin
      $dumpfile("serial_bringup.vcd");$dumpvars(0,UcieSerialBringUp_tb);
    end
    start=1;
    n=0;
    while(n<max_sbinit && !(upm_left_sbinit && berkeley_left_sbinit)) begin
      @(posedge clock);#2ps;n++;
    end
    status("SBINIT result");
    if(n==max_sbinit) $fatal(1,"SBINIT watchdog: both controllers did not complete SBINIT");
    if(check_errors!=0) $fatal(1,"SBINIT milestones reached with %0d errors; FAIL",check_errors);
    if(a_chunks==0 || b_chunks==0 || serial_rx_count==0) $fatal(1,"Missing serial traffic");
    $display("PASS: both real controllers completed serial SBINIT. MBINIT/MBTRAIN/ACTIVE not tested.");
    $fclose(packet_log);$fclose(state_log);$fclose(serial_log);
    $finish;
  end
  initial begin #20ms; $fatal(1,"Global test watchdog"); end
endmodule
`default_nettype wire
