`timescale 1ns/1ps
`default_nettype none

// Wiring contract test, not a substitute for analog training or CDC signoff.
// Force only the MBTrain output boundary so the real LTSM/Core/Top/TopJtag
// wiring and packed capture fields carry walking-one patterns in every bit.
module UcieCodeWidthSpec_tb;
  UcieDigitalTopJtag dut (
    .clock(1'b0), .reset_n(1'b0), .jtag_nRst(1'b0), .tdr_rst(1'b0),
    .tdr_tck(1'b0), .tdr_tdi(1'b0), .tdr_capture(1'b0),
    .tdr_shift(1'b0), .tdr_update(1'b0),
    .sel_ctrl(1'b0), .sel_dig(1'b0), .sel_fdi(1'b0),
    .sel_rdi(1'b0), .sel_ltsm(1'b0),
    .ltsm_linkSpeed_requestedSpeed(requested_speed),
    .ltsm_flagFromAnalog_linkSpeed_speedApplied(speed_applied)
  );
  // Standalone instances ensure that a parent's explicit parameter forwarding
  // cannot mask stale defaults in either lower-level top module. A reduced
  // sweep count must still preserve the physical 20-bit interface.
  UcieDigitalCore #(.validVrefValueCount(4), .dataVrefValueCount(4),
                   .rxDeskewValueCount(4)) standalone_core (
    .clock(1'b0), .reset_n(1'b0), .testModeFdi(1'b0),
    .testModeRdi(1'b0), .testModeLtsm(1'b0)
  );
  UcieDigitalTop standalone_top (
    .clock(1'b0), .reset_n(1'b0), .testModeDigital(1'b0),
    .testModeFdi(1'b0), .testModeRdi(1'b0), .testModeLtsm(1'b0)
  );
  logic [19:0] valid_code = '0;
  logic [319:0] data_codes = '0;
  logic [319:0] rx_codes = '0;
  logic [37:0] phase_code = '0;
  logic [1279:0] tx_codes = '0;
  logic [7:0] mode_control = 8'h08;
  logic [1:0] requested_speed = 2'b0;
  logic speed_applied = 1'b0;
  logic [1:0] selected_speed = 2'b0;
  logic apply_speed = 1'b0, electrical_idle = 1'b0;
  logic [1:0] digital_requested_speed = 2'b0, ltsm_requested_speed = 2'b0;
  logic digital_speed_applied = 1'b0, ltsm_speed_applied = 1'b0;

  task automatic check_paths(input int mode);
    if (dut.ltsm_flagToAnalog_valVref_rxVrefCode !== (mode == 0 ? valid_code : 20'b0))
      $fatal(1, "Functional valVref_rxVrefCode mismatch mode=%0d", mode);
    if (dut.dig_out.ltsm_flagToAnalog_valVref_rxVrefCode !== (mode == 1 ? valid_code : 20'b0))
      $fatal(1, "Digital capture valVref_rxVrefCode mismatch mode=%0d", mode);
    if (dut.ltsm_out.flagToAnalog_valVref_rxVrefCode !== (mode == 4 ? valid_code : 20'b0))
      $fatal(1, "LTSM capture valVref_rxVrefCode mismatch mode=%0d", mode);
    if (dut.ltsm_flagToAnalog_dataVref_rxVrefCodes !== (mode == 0 ? data_codes : 320'b0))
      $fatal(1, "Functional dataVref_rxVrefCodes mismatch mode=%0d", mode);
    if (dut.dig_out.ltsm_flagToAnalog_dataVref_rxVrefCodes !== (mode == 1 ? data_codes : 320'b0))
      $fatal(1, "Digital capture dataVref_rxVrefCodes mismatch mode=%0d", mode);
    if (dut.ltsm_out.flagToAnalog_dataVref_rxVrefCodes !== (mode == 4 ? data_codes : 320'b0))
      $fatal(1, "LTSM capture dataVref_rxVrefCodes mismatch mode=%0d", mode);
    if (dut.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes !== (mode == 0 ? rx_codes : 320'b0))
      $fatal(1, "Functional rxDeskew_rxLaneDeskewCodes mismatch mode=%0d", mode);
    if (dut.dig_out.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes !== (mode == 1 ? rx_codes : 320'b0))
      $fatal(1, "Digital capture rxDeskew_rxLaneDeskewCodes mismatch mode=%0d", mode);
    if (dut.ltsm_out.flagToAnalog_rxDeskew_rxLaneDeskewCodes !== (mode == 4 ? rx_codes : 320'b0))
      $fatal(1, "LTSM capture rxDeskew_rxLaneDeskewCodes mismatch mode=%0d", mode);
    if (dut.ltsm_flagToAnalog_d2cSender_txClockPhaseCode !== (mode == 0 ? phase_code : 38'b0))
      $fatal(1, "Functional d2cSender_txClockPhaseCode mismatch mode=%0d", mode);
    if (dut.dig_out.ltsm_flagToAnalog_d2cSender_txClockPhaseCode !== (mode == 1 ? phase_code : 38'b0))
      $fatal(1, "Digital capture d2cSender_txClockPhaseCode mismatch mode=%0d", mode);
    if (dut.ltsm_out.flagToAnalog_d2cSender_txClockPhaseCode !== (mode == 4 ? phase_code : 38'b0))
      $fatal(1, "LTSM capture d2cSender_txClockPhaseCode mismatch mode=%0d", mode);
    if (dut.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes !== (mode == 0 ? tx_codes : 1280'b0))
      $fatal(1, "Functional d2cSender_txLaneDeskewCodes mismatch mode=%0d", mode);
    if (dut.dig_out.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes !== (mode == 1 ? tx_codes : 1280'b0))
      $fatal(1, "Digital capture d2cSender_txLaneDeskewCodes mismatch mode=%0d", mode);
    if (dut.ltsm_out.flagToAnalog_d2cSender_txLaneDeskewCodes !== (mode == 4 ? tx_codes : 1280'b0))
      $fatal(1, "LTSM capture d2cSender_txLaneDeskewCodes mismatch mode=%0d", mode);
  endtask

  task automatic check_speed_paths(input int mode);
    logic [1:0] expected_requested;
    logic expected_applied;
    expected_requested = mode == 1 ? digital_requested_speed :
                         mode == 4 ? ltsm_requested_speed : requested_speed;
    expected_applied = mode == 1 ? digital_speed_applied :
                       mode == 4 ? ltsm_speed_applied : speed_applied;
    if (dut.u_top.u_core.ltsm.linkSpeed_requestedSpeed !== expected_requested ||
        dut.u_top.u_core.ltsm.flagFromAnalog_linkSpeed_speedApplied !== expected_applied)
      $fatal(1, "Requested speed/analog acknowledgement input routing failed mode=%0d", mode);
    if ({dut.ltsm_flagToAnalog_linkSpeed_speedCode,
         dut.ltsm_flagToAnalog_linkSpeed_applySpeed,
         dut.ltsm_flagToAnalog_linkSpeed_electricalIdle} !==
        (mode == 0 ? {selected_speed, apply_speed, electrical_idle} : 4'b0))
      $fatal(1, "Functional speed-control output routing failed mode=%0d", mode);
    if ({dut.dig_out.ltsm_flagToAnalog_linkSpeed_speedCode,
         dut.dig_out.ltsm_flagToAnalog_linkSpeed_applySpeed,
         dut.dig_out.ltsm_flagToAnalog_linkSpeed_electricalIdle} !==
        (mode == 1 ? {selected_speed, apply_speed, electrical_idle} : 4'b0))
      $fatal(1, "Digital speed-control capture routing failed mode=%0d", mode);
    if ({dut.ltsm_out.flagToAnalog_linkSpeed_speedCode,
         dut.ltsm_out.flagToAnalog_linkSpeed_applySpeed,
         dut.ltsm_out.flagToAnalog_linkSpeed_electricalIdle} !==
        (mode == 4 ? {selected_speed, apply_speed, electrical_idle} : 4'b0))
      $fatal(1, "LTSM speed-control capture routing failed mode=%0d", mode);
  endtask

  initial begin
    if ($bits(dut.ltsm_linkSpeed_requestedSpeed) != 2 ||
        $bits(dut.ltsm_flagToAnalog_linkSpeed_speedCode) != 2 ||
        $bits(dut.u_top.ltsm_linkSpeed_requestedSpeed) != 2 ||
        $bits(dut.u_top.ltsm_flagToAnalog_linkSpeed_speedCode) != 2 ||
        $bits(dut.u_top.u_core.ltsm_linkSpeed_requestedSpeed) != 2 ||
        $bits(dut.u_top.u_core.ltsm_flagToAnalog_linkSpeed_speedCode) != 2 ||
        $bits(standalone_core.ltsm_linkSpeed_requestedSpeed) != 2 ||
        $bits(standalone_top.ltsm_flagToAnalog_linkSpeed_speedCode) != 2)
      $fatal(1, "Requested/selected speed must be two bits through every top");
    force dut.dig_in.ltsm_linkSpeed_requestedSpeed = digital_requested_speed;
    force dut.dig_in.ltsm_flagFromAnalog_linkSpeed_speedApplied = digital_speed_applied;
    force dut.ltsm_in.linkSpeed_requestedSpeed = ltsm_requested_speed;
    force dut.ltsm_in.flagFromAnalog_linkSpeed_speedApplied = ltsm_speed_applied;
    // Speed selection also occurs outside MBTRAIN, so force the aggregate
    // LTSM output boundary for this wiring-only test.
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_speedCode = selected_speed;
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_applySpeed = apply_speed;
    force dut.u_top.u_core.ltsm.flagToAnalog_linkSpeed_electricalIdle = electrical_idle;
    if ($bits(dut.ltsm_flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "dut.valVref_rxVrefCode: wrong width");
    if ($bits(dut.ltsm_flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "dut.dataVref_rxVrefCodes: wrong width");
    if ($bits(dut.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "dut.rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(dut.ltsm_flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "dut.d2cSender_txClockPhaseCode: wrong width");
    if ($bits(dut.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "dut.d2cSender_txLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.ltsm_flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "dut.u_top.valVref_rxVrefCode: wrong width");
    if ($bits(dut.u_top.ltsm_flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "dut.u_top.dataVref_rxVrefCodes: wrong width");
    if ($bits(dut.u_top.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "dut.u_top.rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.ltsm_flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "dut.u_top.d2cSender_txClockPhaseCode: wrong width");
    if ($bits(dut.u_top.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "dut.u_top.d2cSender_txLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm_flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "dut.u_top.u_core.valVref_rxVrefCode: wrong width");
    if ($bits(dut.u_top.u_core.ltsm_flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "dut.u_top.u_core.dataVref_rxVrefCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "dut.u_top.u_core.rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm_flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "dut.u_top.u_core.d2cSender_txClockPhaseCode: wrong width");
    if ($bits(dut.u_top.u_core.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "dut.u_top.u_core.d2cSender_txLaneDeskewCodes: wrong width");
    if ($bits(standalone_core.ltsm_flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "standalone_core.valVref_rxVrefCode: wrong width");
    if ($bits(standalone_core.ltsm_flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "standalone_core.dataVref_rxVrefCodes: wrong width");
    if ($bits(standalone_core.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "standalone_core.rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(standalone_core.ltsm_flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "standalone_core.d2cSender_txClockPhaseCode: wrong width");
    if ($bits(standalone_core.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "standalone_core.d2cSender_txLaneDeskewCodes: wrong width");
    if ($bits(standalone_top.ltsm_flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "standalone_top.valVref_rxVrefCode: wrong width");
    if ($bits(standalone_top.ltsm_flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "standalone_top.dataVref_rxVrefCodes: wrong width");
    if ($bits(standalone_top.ltsm_flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "standalone_top.rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(standalone_top.ltsm_flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "standalone_top.d2cSender_txClockPhaseCode: wrong width");
    if ($bits(standalone_top.ltsm_flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "standalone_top.d2cSender_txLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_valVref_rxVrefCode) != 20)
      $fatal(1, "MBTrain valVref_rxVrefCode: wrong width");
    if ($bits(dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_dataVref_rxVrefCodes) != 320)
      $fatal(1, "MBTrain dataVref_rxVrefCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_rxDeskew_rxLaneDeskewCodes) != 320)
      $fatal(1, "MBTrain rxDeskew_rxLaneDeskewCodes: wrong width");
    if ($bits(dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_d2cSender_txClockPhaseCode) != 38)
      $fatal(1, "MBTrain d2cSender_txClockPhaseCode: wrong width");
    if ($bits(dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_d2cSender_txLaneDeskewCodes) != 1280)
      $fatal(1, "MBTrain d2cSender_txLaneDeskewCodes: wrong width");
    if (dut.DIG_IN_W != 232 || dut.DIG_OUT_W != 2557 ||
        dut.FDI_IN_W != 180 || dut.FDI_OUT_W != 151 ||
        dut.RDI_IN_W != 174 || dut.RDI_OUT_W != 141 ||
        dut.LTSM_IN_W != 318 || dut.LTSM_OUT_W != 2862)
      $fatal(1, "Default packed scan-map size changed; update host scan definitions");
    force dut.ctrl_q = mode_control;
    force dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_valVref_rxVrefCode = valid_code;
    force dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_dataVref_rxVrefCodes = data_codes;
    force dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_rxDeskew_rxLaneDeskewCodes = rx_codes;
    force dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_d2cSender_txClockPhaseCode = phase_code;
    force dut.u_top.u_core.ltsm.mbTrainFsm.flagToAnalog_d2cSender_txLaneDeskewCodes = tx_codes;
    for (int pass = 0; pass < 3; pass++) begin
      int mode;
      mode = pass == 2 ? 4 : pass;
      mode_control = 8'(8 + mode); // Keep reset asserted across mode changes.
      for (int speed = 0; speed < 4; speed++) begin
        requested_speed = 2'(speed);
        digital_requested_speed = 2'(speed ^ 1);
        ltsm_requested_speed = 2'(speed ^ 2);
        speed_applied = 1'(speed);
        digital_speed_applied = ~1'(speed);
        ltsm_speed_applied = 1'(speed >> 1);
        selected_speed = 2'(3-speed);
        apply_speed = 1'(speed);
        electrical_idle = 1'(speed >> 1);
        #1;
        check_speed_paths(mode);
      end
      #1;
      check_paths(mode);
      for (int bit_index = 0; bit_index < 20; bit_index++) begin
        valid_code = 20'b1 << bit_index;
        #1;
        check_paths(mode);
      end
      valid_code = '0;
      for (int bit_index = 0; bit_index < 320; bit_index++) begin
        data_codes = 320'b1 << bit_index;
        #1;
        check_paths(mode);
      end
      data_codes = '0;
      for (int bit_index = 0; bit_index < 320; bit_index++) begin
        rx_codes = 320'b1 << bit_index;
        #1;
        check_paths(mode);
      end
      rx_codes = '0;
      for (int bit_index = 0; bit_index < 38; bit_index++) begin
        phase_code = 38'b1 << bit_index;
        #1;
        check_paths(mode);
      end
      phase_code = '0;
      for (int bit_index = 0; bit_index < 1280; bit_index++) begin
        tx_codes = 1280'b1 << bit_index;
        #1;
        check_paths(mode);
      end
      tx_codes = '0;
      #1;
      check_paths(mode);
    end
    $display("PASS UcieCodeWidthSpec_tb: 20/320/320/38/1280-bit paths, all walking bits, 2-bit speed/request/ack paths, functional/digital/LTSM modes");
    $finish;
  end
endmodule

`default_nettype wire
