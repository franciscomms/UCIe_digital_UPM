`timescale 1ns/1ps
`default_nettype none

// Integration fixture, NOT a production SoC bridge:
// - supplied TAP RTL and the actual uploaded jtag_cfg_pkg instruction constants;
// - actual UcieDigitalTopJtag and all five TDRs;
// - bank_select below supplies the missing five-bank decoder/TDO mux in the TB.
// A real system must supply that decoder/opcode allocation; the attached TAP
// alone cannot address all five wrapper registers.
// The wide snapshots are injected at each TDR's data_in boundary. This checks
// every serialized bit and clock-domain transaction, not analog training.
// New speed fields are additionally scanned through the actual top-level muxes,
// with only the aggregate LTSM status outputs forced for wiring coverage.
module JtagTapIntegrationSpec_tb;
  import jtag_cfg_pkg::*;
  localparam int MAX_DR_W = 2863;
  logic clock = 0;
  always #3 clock = ~clock;
  logic reset_n = 0, jtag_nRst = 0;
  logic tck = 0, tms = 1, tdi = 0;
  wire tdo, tdo_en;
  wire tdr_rst, tdr_tck, tdr_tdi, tdr_capture, tdr_shift, tdr_update;
  wire snap_sel, step_sel, dtmcs_sel, dmi_sel;
  wire tdo_ctrl, tdo_dig, tdo_fdi, tdo_rdi, tdo_ltsm;
  logic [2:0] bank_select = 0;
  logic selected_tdo;
  logic [2556:0] dig_live;
  logic [179:0] fdi_live;
  logic [173:0] rdi_live;
  logic [2861:0] ltsm_live;
  logic [MAX_DR_W-1:0] tx, rx, ignored, expected_dr;
  logic [2556:0] held_dig;
  logic [179:0] held_fdi;
  logic [173:0] held_rdi;
  logic [2861:0] held_ltsm;
  logic sample_bit;
  int checks = 0;
  logic [1:0] speed_live = 2'b0;
  logic speed_apply_live = 1'b0, speed_idle_live = 1'b0;

  always_comb begin
    case (bank_select)
      0: selected_tdo = tdo_ctrl;
      1: selected_tdo = tdo_dig;
      2: selected_tdo = tdo_fdi;
      3: selected_tdo = tdo_rdi;
      4: selected_tdo = tdo_ltsm;
      default: selected_tdo = 0;
    endcase
  end

  jtag_tap tap (
    .jtag_nRst(jtag_nRst), .tck(tck), .tms(tms), .tdi(tdi),
    .tdo(tdo), .tdo_en(tdo_en), .testmode_i(1'b0),
    .tdr_rst(tdr_rst), .tdr_tck(tdr_tck), .tdr_tdi(tdr_tdi),
    .tdr_update(tdr_update), .tdr_capture(tdr_capture), .tdr_shift(tdr_shift),
    .dtmcs_sel(dtmcs_sel), .dtmcs_tdo(1'b0),
    .dmi_sel(dmi_sel), .dmi_tdo(1'b0),
    .tdr_snap_sel(snap_sel), .tdr_snap_tdo(selected_tdo),
    .tdr_step_sel(step_sel), .tdr_step_tdo(1'b0)
  );
  UcieDigitalTopJtag dut (
    .jtag_nRst(jtag_nRst),
    .tdr_rst(tdr_rst),
    .tdr_tck(tdr_tck),
    .tdr_tdi(tdr_tdi),
    .tdr_capture(tdr_capture),
    .tdr_shift(tdr_shift),
    .tdr_update(tdr_update),
    .sel_ctrl((snap_sel && bank_select==3'd0)),
    .sel_dig((snap_sel && bank_select==3'd1)),
    .sel_fdi((snap_sel && bank_select==3'd2)),
    .sel_rdi((snap_sel && bank_select==3'd3)),
    .sel_ltsm((snap_sel && bank_select==3'd4)),
    .clock(clock),
    .reset_n(reset_n),
    .fdi_lp_state_req(UcieUPM_interfaces_pkg::PhyStateReq_nop),
    .fdi_lp_linkerror('0),
    .fdi_lp_rx_active_sts('0),
    .fdi_lp_wake_req('0),
    .fdi_lp_clk_ack('0),
    .fdi_lp_stall_ack('0),
    .timeout_disable('0),
    .cycles_1us('0),
    .ltsm_start('0),
    .ltsm_linkSpeed_requestedSpeed(2'd3),
    .ltsm_flagFromAnalog_linkSpeed_speedApplied(1'b0),
    .ltsm_stable_clk('0),
    .ltsm_pll_locked('0),
    .ltsm_stable_supply('0),
    .ltsm_flagFromAnalog_ReadyToExchangeClkPatterns('0),
    .ltsm_flagFromAnalog_FinishedClkPatterns('0),
    .ltsm_flagFromAnalog_FinishedValTrainPattern('0),
    .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern('0),
    .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern('0),
    .ltsm_flagFromAnalog_clkPatternReceivedRTRK_L('0),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKN_L('0),
    .ltsm_flagFromAnalog_clkPatternReceivedRCKP_L('0),
    .ltsm_flagFromAnalog_ValTrainPatternReceived('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14('0),
    .ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14('0),
    .ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15('0),
    .ltsm_flagFromAnalog_valVref_detectedValPattern('0),
    .ltsm_flagFromAnalog_valVref_finishedPattern('0),
    .ltsm_flagFromAnalog_valVref_rxVrefApplied('0),
    .ltsm_flagFromAnalog_dataVref_detectedDataPattern('0),
    .ltsm_flagFromAnalog_dataVref_finishedPattern('0),
    .ltsm_flagFromAnalog_dataVref_rxVrefApplied('0),
    .ltsm_flagFromAnalog_rxClkCal_done('0),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent('0),
    .ltsm_flagFromAnalog_d2cSender_txClockPhaseApplied('0),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo('0),
    .ltsm_flagFromAnalog_d2cReceiver_txInitD2CResultsPayload('0),
    .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent('0),
    .ltsm_flagFromAnalog_d2cSender_txLaneDeskewApplied('0),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent('0),
    .ltsm_flagFromAnalog_rxDeskew_rxLaneDeskewApplied('0),
    .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern('0),
    .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful('0),
    .sb_rx_din('0),
    .sb_rx_clk('0),
    .tdo_ctrl(tdo_ctrl),
    .tdo_dig(tdo_dig),
    .tdo_fdi(tdo_fdi),
    .tdo_rdi(tdo_rdi),
    .tdo_ltsm(tdo_ltsm)
  );

  // Sample on the next rising edge; the TAP launches TDO on falling TCK.
  task automatic tick(input bit next_tms, input bit next_tdi, output bit out_bit);
    tms = next_tms;
    tdi = next_tdi;
    #7;
    out_bit = tdo;
    tck = 1;
    #7;
    tck = 0;
    #1;
  endtask
  task automatic idle(input int cycles);
    bit unused_bit;
    repeat(cycles) tick(0, 0, unused_bit);
  endtask
  task automatic select_ir(input logic [JTAG_IR_WIDTH-1:0] code);
    bit unused_bit;
    logic [JTAG_IR_WIDTH-1:0] captured;
    tick(1,0,unused_bit); // Select-DR
    tick(1,0,unused_bit); // Select-IR
    tick(0,0,unused_bit); // Capture-IR
    tick(0,0,unused_bit); // Shift-IR, capture occurs here
    for (int i=0; i<JTAG_IR_WIDTH; i++) begin
      if (!tdo_en) $fatal(1,"TDO must be enabled during Shift-IR");
      tick(i==JTAG_IR_WIDTH-1,code[i],captured[i]);
    end
    if (captured[1:0] !== 2'b01) $fatal(1,"IR capture signature");
    tick(1,0,unused_bit); // Update-IR
    tick(0,0,unused_bit); // Idle: commits IR in the supplied TAP
    checks++;
  endtask
  task automatic scan_dr(input int width,
                         input logic [MAX_DR_W-1:0] in_bits,
                         output logic [MAX_DR_W-1:0] out_bits);
    bit unused_bit;
    out_bits = '0;
    tick(1,0,unused_bit); // Select-DR
    tick(0,0,unused_bit); // Capture-DR
    tick(0,0,unused_bit); // Shift-DR, capture occurs here
    for (int i=0; i<width; i++) begin
      if (!tdo_en) $fatal(1,"TDO must be enabled during Shift-DR");
      tick(i==width-1,in_bits[i],out_bits[i]);
    end
    tick(1,0,unused_bit); // Update-DR
    tick(0,0,unused_bit); // Idle: commits DR in the supplied TAP
  endtask
  function automatic int dr_width(input int bank);
    case (bank)
      0: return 9;
      1: return 2558;
      2: return 181;
      3: return 175;
      4: return 2863;
      default: return 0;
    endcase
  endfunction
  function automatic logic [MAX_DR_W-1:0] pattern(input int seed);
    logic [31:0] lfsr;
    lfsr = 32'hb59d_1237 ^ (32'h0034_5991 * 32'(seed));
    for (int i=0; i<MAX_DR_W; i++) begin
      pattern[i] = lfsr[0];
      lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
    end
  endfunction
  task automatic control_write(input logic [7:0] value);
    bank_select = 0;
    tx = '0;
    tx[8:0] = {value, 1'b1};
    scan_dr(9, tx, ignored);
    idle(12);
    if (dut.ctrl_q !== value) $fatal(1,"Control write failed");
    scan_dr(9, '0, rx);
    if (rx[8:0] !== {value, 1'b0}) $fatal(1,"Control snapshot/readback failed");
    idle(12);
    checks++;
  endtask

  // These offsets deliberately agree with the checked-in default host map.
  // They test actual serial field packing rather than forcing the input struct.
  task automatic speed_fields_scan(input int bank);
    int request_lsb, ack_lsb, code_lsb, apply_lsb, idle_lsb;
    logic [1:0] expected_speed;
    logic expected_apply, expected_idle;
    if (bank == 1) begin
      request_lsb=4; ack_lsb=3; code_lsb=83; apply_lsb=82; idle_lsb=81;
    end else begin
      request_lsb=2; ack_lsb=1; code_lsb=233; apply_lsb=232; idle_lsb=231;
    end
    control_write(8'(8+bank)); // digital=1 or LTSM=4; keep block reset asserted.
    for (int requested=0; requested<4; requested++) begin
      bank_select = 3'(bank);
      tx = '0;
      tx[0] = 1'b1;
      tx[request_lsb +: 2] = 2'(requested);
      tx[ack_lsb] = 1'(requested);
      expected_speed = 2'(3-requested);
      expected_apply = 1'(requested >> 1);
      expected_idle = 1'(requested);
      speed_live = expected_speed;
      speed_apply_live = expected_apply;
      speed_idle_live = expected_idle;
      scan_dr(dr_width(bank), tx, ignored);
      idle(12);
      if (dut.u_top.u_core.ltsm.linkSpeed_requestedSpeed !== 2'(requested) ||
          dut.u_top.u_core.ltsm.flagFromAnalog_linkSpeed_speedApplied !== 1'(requested))
        $fatal(1,"Serial requested-speed/ack field failed bank=%0d code=%0d",bank,requested);
      if (bank==1 && (dut.dig_in.ltsm_linkSpeed_requestedSpeed !== 2'(requested) ||
                     dut.dig_in.ltsm_flagFromAnalog_linkSpeed_speedApplied !== 1'(requested)))
        $fatal(1,"Digital speed fields are at the wrong scan offsets");
      if (bank==4 && (dut.ltsm_in.linkSpeed_requestedSpeed !== 2'(requested) ||
                     dut.ltsm_in.flagFromAnalog_linkSpeed_speedApplied !== 1'(requested)))
        $fatal(1,"LTSM speed fields are at the wrong scan offsets");
      // Read back a snapshot through real LTSM/Core/Top/packed-field routing.
      // Change live output first to prove the returned value was latched.
      speed_live = ~expected_speed;
      speed_apply_live = ~expected_apply;
      speed_idle_live = ~expected_idle;
      scan_dr(dr_width(bank), '0, rx);
      if (rx[0] || rx[code_lsb +: 2] !== expected_speed ||
          rx[apply_lsb] !== expected_apply || rx[idle_lsb] !== expected_idle)
        $fatal(1,"Serial selected-speed/apply/idle snapshot failed bank=%0d code=%0d",bank,requested);
      idle(12);
      checks++;
    end
  endtask

  initial begin
    dig_live = '0; fdi_live = '0; rdi_live = '0; ltsm_live = '0;
    held_dig = '0; held_fdi = '0; held_rdi = '0; held_ltsm = '0;
    // These force points isolate serializer coverage from PHY/training behavior.
    force dut.dig_data_in = dig_live;
    force dut.fdi_data_in = fdi_live;
    force dut.rdi_data_in = rdi_live;
    force dut.ltsm_data_in = ltsm_live;
    #12;
    reset_n = 1;
    jtag_nRst = 1;
    repeat (6) tick(1,0,sample_bit);
    tick(0,0,sample_bit); // Idle
    if (dut.CTRL_W+1!=9 || dut.DIG_W+1!=2558 || dut.FDI_W+1!=181 ||
        dut.RDI_W+1!=175 || dut.LTSM_W+1!=2863)
      $fatal(1,"Default scan lengths changed; update host map and test fixture");

    // Reset defaults to IDCODE; no IR selection is needed for this first scan.
    scan_dr(32, '0, rx);
    if (rx[31:0] !== JTAG_IDCODE_VALUE) $fatal(1,"IDCODE scan ordering/value");
    select_ir(BYPASS_1);
    tx = '0; tx[7:0] = 8'b10110010;
    scan_dr(8, tx, rx);
    if (rx[7:0] !== {tx[6:0],1'b0}) $fatal(1,"BYPASS one-bit latency");
    select_ir(TDR_SNAP);

    // Exercise all control modes while holding their selected block in reset.
    for (int mode=0; mode<=7; mode++) begin
      control_write(8'h08 | 8'(mode));
      if ({dut.u_top.testModeLtsm,dut.u_top.testModeRdi,
           dut.u_top.testModeFdi,dut.u_top.testModeDigital} !==
          ((mode>=1 && mode<=4) ? (4'b1 << (mode-1)) : 4'b0))
        $fatal(1,"Mode decode is not mutually exclusive, mode=%0d",mode);
      if (dut.test_reset_n !== 0) $fatal(1,"Control reset not asserted");
    end
    control_write(8'h09); // digital test mode, core held reset for data scans

    // Every bank receives a distinct wide write. All snapshot bits (including
    // bit 19 of every widened control word and topmost DR bit) are exercised.
    for (int bank=1; bank<=4; bank++) begin
      bank_select = 3'(bank);
      tx = pattern(bank);
      tx[0] = 1;
      expected_dr = pattern(bank+17);
      expected_dr[0] = 0;
      case (bank)
        1: begin dig_live=expected_dr[2557:1]; held_dig=tx[2557:1]; end
        2: begin fdi_live=expected_dr[180:1]; held_fdi=tx[180:1]; end
        3: begin rdi_live=expected_dr[174:1]; held_rdi=tx[174:1]; end
        4: begin ltsm_live=expected_dr[2862:1]; held_ltsm=tx[2862:1]; end
      endcase
      scan_dr(dr_width(bank), tx, ignored);
      idle(12);
      if (dut.dig_data_out !== held_dig || dut.fdi_data_out !== held_fdi ||
          dut.rdi_data_out !== held_rdi || dut.ltsm_data_out !== held_ltsm ||
          dut.ctrl_q !== 8'h09)
        $fatal(1,"Selected write/other-bank isolation failed, bank=%0d",bank);
      // Change live data AFTER acknowledgement; the returned snapshot must
      // retain the prior transaction's value throughout the next long scan.
      dig_live = ~dig_live; fdi_live = ~fdi_live;
      rdi_live = ~rdi_live; ltsm_live = ~ltsm_live;
      scan_dr(dr_width(bank), '0, rx);
      for (int i=0; i<dr_width(bank); i++)
        if (rx[i] !== expected_dr[i])
          $fatal(1,"Snapshot/LSB-first serialization mismatch bank=%0d bit=%0d",bank,i);
      idle(12);
      // That read-only Update-DR snapshots the inverted live value. Checking
      // its response guarantees both 0 and 1 are tested at every data bit,
      // including the new high control-word bits and the topmost scan bit.
      expected_dr = ~expected_dr;
      expected_dr[0] = 0;
      scan_dr(dr_width(bank), '0, rx);
      for (int i=0; i<dr_width(bank); i++)
        if (rx[i] !== expected_dr[i])
          $fatal(1,"Complement snapshot mismatch bank=%0d bit=%0d",bank,i);
      idle(12);
      if (dut.dig_data_out !== held_dig || dut.fdi_data_out !== held_fdi ||
          dut.rdi_data_out !== held_rdi || dut.ltsm_data_out !== held_ltsm)
        $fatal(1,"Read-only scan modified a bank");
      checks++;
    end
    release dut.dig_data_in;
    release dut.ltsm_data_in;
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_speedCode = speed_live;
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_applySpeed = speed_apply_live;
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_electricalIdle = speed_idle_live;
    speed_fields_scan(1);
    speed_fields_scan(4);
    release dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_speedCode;
    release dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_applySpeed;
    release dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_electricalIdle;
    control_write(8'h09); // select digital mode while still held in reset
    control_write(8'h01); // release core within same test mode
    if (!dut.test_reset_n) $fatal(1,"Control reset not released");
    control_write(8'h09);
    control_write(8'h08); // return to functional mode while reset selected
    if (tdo_en) $fatal(1,"TDO unexpectedly enabled in Idle");
    $display("PASS JtagTapIntegrationSpec_tb checks=%0d; actual TAP opcodes; test-only bank decoder",checks);
    $finish;
  end
  initial begin
    #2000000;
    $fatal(1,"JTAG integration watchdog");
  end
endmodule
`default_nettype wire
