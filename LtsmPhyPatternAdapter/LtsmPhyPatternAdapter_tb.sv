`timescale 1ns/1ps
`default_nettype none
module LtsmPhyPatternAdapter_tb;
  logic clock = 0, reset_n = 0;
  logic [3:0] st = 4'd5; logic [2:0] sub = 0; logic [3:0] mbt = 0;
  logic [8:0] req = 0; wire [8:0] fin; wire [3:0] phy; logic sent = 0;
  int errors = 0;
  always #1 clock = ~clock;

  LtsmPhyPatternAdapter dut (
    .clock, .reset_n, .ltsm_state(st), .ltsm_dbg_mbinitSubstate(sub), .ltsm_dbg_mbtrainState(mbt),
    .ltsm_flagToAnalog_SendClkPatterns(req[0]), .ltsm_flagToAnalog_SendValTrainPattern(req[1]),
    .ltsm_flagToAnalog_ReversalMbSendLaneIDPattern(req[2]), .ltsm_flagToAnalog_RepairMbSendLaneIDPattern(req[3]),
    .ltsm_flagToAnalog_valVref_sendPattern(req[4]), .ltsm_flagToAnalog_dataVref_sendPattern(req[5]),
    .ltsm_flagToAnalog_d2cSender_sendValTrainPattern(req[6]), .ltsm_flagToAnalog_d2cSender_sendLfsrPattern(req[7]),
    .ltsm_flagToAnalog_rxDeskew_sendLfsrPattern(req[8]),
    .ltsm_flagFromAnalog_FinishedClkPatterns(fin[0]), .ltsm_flagFromAnalog_FinishedValTrainPattern(fin[1]),
    .ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern(fin[2]), .ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern(fin[3]),
    .ltsm_flagFromAnalog_valVref_finishedPattern(fin[4]), .ltsm_flagFromAnalog_dataVref_finishedPattern(fin[5]),
    .ltsm_flagFromAnalog_d2cSender_valTrainPatternSent(fin[6]), .ltsm_flagFromAnalog_d2cSender_lfsrPatternSent(fin[7]),
    .ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent(fin[8]),
    .phy_sendClkRepairPattern(phy[0]), .phy_sendValTrainPattern(phy[1]),
    .phy_sendLaneIdPattern(phy[2]), .phy_sendLfsrPattern(phy[3]), .phy_patternSent(sent));

  function automatic void check(bit ok, string msg);
    if (!ok) begin errors++; $display("FAIL %s t=%0t", msg, $time); end
  endfunction

  task automatic edges(int n);
    repeat (n) begin
      sent = 1; repeat (2) @(negedge clock);
      sent = 0; repeat (2) @(negedge clock);
    end
  endtask

  // kind: 0 = one-clock pulse, 1 = held until finished, 2 = sticky after finished
  task automatic burst(string name, int idx, int kind, logic [3:0] mstate, logic [3:0] bitv, int count);
    int finCount = 0, n = 0; bit phyLowAtFinish = 0;
    mbt = mstate; st = (mstate != 0) ? 4'd6 : 4'd5;
    @(negedge clock);
    check(phy == 0, {name, " idle before"});
    req[idx] = 1;
    if (kind == 0) begin @(negedge clock); req[idx] = 0; end else @(negedge clock);
    check(phy == bitv, {name, " phy bit set"});
    edges(count - 1);
    check(phy == bitv, {name, " bit still high one edge before the count"});
    check(fin == 0, {name, " no early finished"});
    sent = 1;
    while (fin == 0 && n < 8) begin @(negedge clock); n++; end
    check(fin == 9'(1 << idx), {name, " finished on own flag"});
    check(phy == 0, {name, " bit falls with finished"});
    @(negedge clock);
    check(fin == 0, {name, " finished one clock wide"});
    if (kind == 1) req[idx] = 0;
    sent = 0; repeat (3) @(negedge clock);
    edges(2);
    check(phy == 0 && fin == 0, {name, " late edges ignored"});
    if (kind == 2) begin
      check(phy == 0, {name, " sticky flag does not restart"});
      req[idx] = 0; @(negedge clock);
    end
    $display("ok-run %s count=%0d", name, count);
  endtask

  initial begin
    repeat (3) @(negedge clock); reset_n = 1; @(negedge clock);

    sub = 2; burst("REPAIRCLK", 0, 0, 0, 4'b0001, 300);
    sub = 3; burst("REPAIRVAL", 1, 0, 0, 4'b0010, 300);
    sub = 4; burst("REVERSALMB", 2, 0, 0, 4'b0100, 300);
    sub = 5; burst("REPAIRMB", 3, 0, 0, 4'b0100, 300);
    sub = 6;
    burst("VALVREF", 4, 1, 4'h1, 4'b0010, 128);
    burst("DATAVREF", 5, 1, 4'h2, 4'b1000, 300);
    burst("VALTRAINCENTER", 6, 2, 4'h6, 4'b0010, 128);
    burst("VALTRAINVREF", 4, 1, 4'h7, 4'b0010, 128);
    burst("DATATRAINCENTER1", 7, 2, 4'h8, 4'b1000, 300);
    burst("DATATRAINVREF", 5, 1, 4'h9, 4'b1000, 300);
    burst("RXDESKEW", 8, 1, 4'hA, 4'b1000, 300);
    burst("DATATRAINCENTER2", 7, 2, 4'hB, 4'b1000, 300);
    burst("LINKSPEED", 7, 2, 4'hC, 4'b1000, 300);

    // Abort: held request falls, no finished; the next burst counts from zero.
    mbt = 4'h1; @(negedge clock); req[4] = 1; @(negedge clock);
    edges(5); req[4] = 0; @(negedge clock); @(negedge clock);
    check(phy == 0 && fin == 0, "abort on request drop");
    burst("VALVREF after abort", 4, 1, 4'h1, 4'b0010, 128);

    // Abort: pulse request, substate changes; no finished.
    st = 5; mbt = 0; sub = 2; @(negedge clock); req[0] = 1; @(negedge clock); req[0] = 0;
    edges(5); sub = 3; @(negedge clock); @(negedge clock);
    check(phy == 0 && fin == 0, "abort on substate change");

    // Abort and new request in the same cycle: new burst must start.
    sub = 4; @(negedge clock); req[2] = 1; @(negedge clock); req[2] = 0; edges(3);
    sub = 5; req[3] = 1; @(negedge clock); req[3] = 0; @(negedge clock);
    check(phy == 4'b0100, "restart on abort");
    edges(300); repeat (4) @(negedge clock);
    check(phy == 0, "restart ran a full fresh count");

    // Reset during a burst.
    sub = 2; @(negedge clock); req[0] = 1; @(negedge clock); req[0] = 0; edges(2);
    reset_n = 0; @(negedge clock); check(phy == 0, "reset clears bit"); reset_n = 1;
    repeat (3) @(negedge clock);

    if (errors == 0) $display("TB PASSED"); else $display("TB FAILED errors=%0d", errors);
    $finish;
  end
endmodule
`default_nettype wire
