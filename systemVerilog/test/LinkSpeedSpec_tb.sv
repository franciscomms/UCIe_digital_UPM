`timescale 1ns/1ps
`default_nettype none

// Two real LINKSPEED peers, accepted-message transport with deliberate stalls,
// and independent analog lane results. This verifies protocol/cycle behavior;
// clocking a simulation at 800 MHz does not establish physical timing closure.
module LinkSpeedSpec_tb;
  import SidebandMsgGenerator_pkg::*;
  logic clock = 1'b0;
  always #0.625 clock = ~clock;
  logic reset_n = 1'b0, start = 1'b0;
  logic [31:0] cycles_1us = 32'd800;
  wire busy [0:1], done [0:1], train_error [0:1], retrain [0:1];
  wire degrade_exit [0:1];
  wire tx_valid [0:1], send_pattern [0:1];
  logic tx_ready [0:1];
  wire [127:0] tx_message [0:1];
  logic [127:0] wire_message [0:1];
  logic [15:0] lane_pass [0:1];
  logic [2:0] corrupt_mode [0:1];
  wire [15:0] last_errors [0:1];
  int cycle_count = 0;
  int pattern_cycles [0:1];
  int error_req_count [0:1], error_rsp_count [0:1];
  int done_req_count [0:1], done_rsp_count [0:1];
  int degrade_req_count [0:1], degrade_rsp_count [0:1];
  int degrade_req_hold [0:1], degrade_rsp_hold [0:1];
  logic block_all_tx = 1'b0, block_done_response = 1'b0;
  logic inject_stall = 1'b0;
  logic drop_degrade_response [0:1];
  int completed_scenarios = 0;
  localparam logic [127:0] RESULT_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);

  for (genvar die = 0; die < 2; die++) begin : peer
    logic stalled;
    logic [127:0] held_message;
    wire accepted_result = tx_valid[1-die] && tx_ready[1-die] &&
      wire_message[1-die][61:56] == RESULT_TEMPLATE[61:56] &&
      wire_message[1-die][39:0] == RESULT_TEMPLATE[39:0];
    wire deliver_message = tx_valid[1-die] && tx_ready[1-die] &&
      !(drop_degrade_response[1-die] && wire_message[1-die] ==
        msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY));
    MBTrain_LinkSpeed dut (
      .clock(clock), .reset_n(reset_n), .start(start), .cycles_1us(cycles_1us),
      .busy(busy[die]), .done(done[die]), .trainError(train_error[die]),
      .exitToSpeedDegrade(degrade_exit[die]),
      .flagToLtsm_phyInRetrain(retrain[die]),
      .sb_tx_ready(tx_ready[die]), .sb_tx_valid(tx_valid[die]),
      .sb_tx_din(tx_message[die]),
      .sb_rx_valid(inject_stall || deliver_message),
      .sb_rx_dout(inject_stall ? msgWithoutPayloadBase(16'hffff,8'hba,8'h19,
                    ENDPOINT_PHY,ENDPOINT_REMOTE_PHY) : wire_message[1-die]),
      .flagToAnalog_d2cSender_sendLfsrPattern(send_pattern[die]),
      .flagFromAnalog_d2cSender_lfsrPatternSent(pattern_cycles[die] >= 3),
      .flagFromAnalog_d2cReceiver_laneComparisonSuccessful(lane_pass[die]),
      .lastErrorCount(last_errors[die])
    );

    always_comb begin
      tx_ready[die] = !block_all_tx && (cycle_count % (7+die)) >= 3;
      if ((tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY)) &&
          degrade_req_hold[die] < 5) tx_ready[die] = 1'b0;
      if ((tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY)) &&
          degrade_rsp_hold[die] < 5) tx_ready[die] = 1'b0;
      if (block_done_response && tx_message[die] == msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
        tx_ready[die] = 1'b0;
      wire_message[die] = tx_message[die];
      if (tx_message[die][61:56] == RESULT_TEMPLATE[61:56] &&
          tx_message[die][39:0] == RESULT_TEMPLATE[39:0]) begin
        case (corrupt_mode[die])
          1: wire_message[die][45] = 1'b0; // Invalid lane-result flag.
          2: wire_message[die][44] = 1'b0; // Failed summary with all lanes passing.
          3: wire_message[die][127] = 1'b1; // Reserved upper result bits set.
          4: wire_message[die][44] = 1'b1; // Passing summary cannot hide bad lanes.
          default: ;
        endcase
      end
    end

    always @(posedge clock) begin
      if (!reset_n) begin
        stalled <= 1'b0;
        held_message <= '0;
        pattern_cycles[die] <= 0;
        error_req_count[die] <= 0;
        error_rsp_count[die] <= 0;
        done_req_count[die] <= 0;
        done_rsp_count[die] <= 0;
        degrade_req_count[die] <= 0;
        degrade_rsp_count[die] <= 0;
        degrade_req_hold[die] <= 0;
        degrade_rsp_hold[die] <= 0;
      end else begin
        if (stalled && !train_error[die] && (!tx_valid[die] || tx_message[die] !== held_message))
          $fatal(1, "Peer %0d changed an unaccepted packet", die);
        if (degrade_exit[die] && tx_valid[die])
          $fatal(1, "Peer %0d exited before its last accepted degrade response", die);
        stalled <= tx_valid[die] && !tx_ready[die];
        held_message <= tx_message[die];
        pattern_cycles[die] <= send_pattern[die] ? pattern_cycles[die] + 1 : 0;
        if (tx_valid[die] && !tx_ready[die]) begin
          if (tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            degrade_req_hold[die] <= degrade_req_hold[die] + 1;
          if (tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            degrade_rsp_hold[die] <= degrade_rsp_hold[die] + 1;
        end
        if (tx_valid[die] && tx_ready[die]) begin
          if (tx_message[die] == msgMbtrainLinkSpeedErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            error_req_count[die] <= error_req_count[die] + 1;
          if (tx_message[die] == msgMbtrainLinkSpeedErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            error_rsp_count[die] <= error_rsp_count[die] + 1;
          if (tx_message[die] == msgMbtrainLinkSpeedDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            done_req_count[die] <= done_req_count[die] + 1;
          if (tx_message[die] == msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            done_rsp_count[die] <= done_rsp_count[die] + 1;
          if (tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY)) begin
            if (error_req_count[die] != 1 || error_rsp_count[1-die] != 1)
              $fatal(1, "Peer %0d initiated degrade before completing ERROR", die);
            degrade_req_count[die] <= degrade_req_count[die] + 1;
          end
          if (tx_message[die] == msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY)) begin
            if (error_rsp_count[die] != 1 || degrade_req_count[1-die] != 1)
              $fatal(1, "Peer %0d acknowledged degrade out of order", die);
            degrade_rsp_count[die] <= degrade_rsp_count[die] + 1;
          end
        end
      end
    end

    // Acceptance first captures the partial counts. Notification of the
    // point-test FSM must wait for the following registered final count.
    always @(posedge clock) begin
      if (reset_n && accepted_result && dut.d2cSender_sentResultsReq &&
          !dut.d2cSender_receivedResultsResp && !dut.resultCountPendingReg) begin
        #0.001;
        if (!dut.resultCountPendingReg || dut.d2cSender_receivedResultsResp)
          $fatal(1, "Peer %0d bypassed the result-count pipeline boundary", die);
      end
    end
  end

  always @(posedge clock)
    cycle_count <= reset_n ? cycle_count + 1 : 0;

  task automatic run_case(input logic [15:0] pass0, input logic [15:0] pass1,
                          input logic [2:0] corrupt0, input logic [2:0] corrupt1);
    int expected_errors [0:1];
    int cycles;
    bit failure;
    begin
      @(negedge clock);
      reset_n = 0; start = 0;
      cycles_1us = 800; block_all_tx = 0; block_done_response = 0; inject_stall = 0;
      drop_degrade_response[0] = 0; drop_degrade_response[1] = 0;
      lane_pass[0] = pass0; lane_pass[1] = pass1;
      corrupt_mode[0] = corrupt0; corrupt_mode[1] = corrupt1;
      expected_errors[0] = 16 - $countones(pass1);
      expected_errors[1] = 16 - $countones(pass0);
      if (corrupt1 >= 1 && corrupt1 <= 3 && expected_errors[0] == 0) expected_errors[0] = 1;
      if (corrupt0 >= 1 && corrupt0 <= 3 && expected_errors[1] == 0) expected_errors[1] = 1;
      failure = expected_errors[0] != 0 || expected_errors[1] != 0;
      repeat (3) @(negedge clock);
      reset_n = 1; start = 1;
      @(negedge clock);
      start = 0;
      cycles = 0;
      while (!((done[0] || train_error[0] || degrade_exit[0]) &&
               (done[1] || train_error[1] || degrade_exit[1]))) begin
        @(negedge clock);
        if (++cycles > 1000)
          $fatal(1, "LINKSPEED timeout: sender=%h/%h receiver=%h/%h", peer[0].dut.dbg_senderState,
                 peer[1].dut.dbg_senderState, peer[0].dut.dbg_receiverState, peer[1].dut.dbg_receiverState);
      end
      for (int die = 0; die < 2; die++) begin
        if (last_errors[die] != expected_errors[die])
          $fatal(1, "Wrong pipelined count peer=%0d expected=%0d got=%0d", die, expected_errors[die], last_errors[die]);
        if (busy[die] || retrain[die] || train_error[die] ||
            degrade_exit[die] != failure || done[die] == failure)
          $fatal(1, "Wrong completion for peer %0d failure=%0b", die, failure);
        if (error_req_count[die] != (expected_errors[die] != 0) ||
            error_rsp_count[die] != (expected_errors[1-die] != 0))
          $fatal(1, "Error exchange obligations lost or duplicated peer=%0d", die);
        if (!failure && (done_req_count[die] != 1 || done_rsp_count[die] != 1))
          $fatal(1, "Success did not finish both DONE exchanges peer=%0d", die);
        if (degrade_req_count[die] != (expected_errors[die] != 0) ||
            degrade_rsp_count[die] != (expected_errors[1-die] != 0))
          $fatal(1, "Degrade exchange obligations lost or duplicated peer=%0d", die);
      end
      repeat (3) @(negedge clock);
      if (failure && (!degrade_exit[0] || !degrade_exit[1]))
        $fatal(1, "Degrade exit did not remain latched until start/reset");
      completed_scenarios++;
    end
  endtask

  task automatic run_missing_degrade_response;
    int waited;
    begin
      @(negedge clock);
      reset_n = 0; start = 0; block_all_tx = 0; block_done_response = 0; inject_stall = 0;
      cycles_1us = 1;
      lane_pass[0] = '1; lane_pass[1] = 16'hfffe;
      corrupt_mode[0] = 0; corrupt_mode[1] = 0;
      drop_degrade_response[0] = 0; drop_degrade_response[1] = 1;
      repeat (3) @(negedge clock);
      reset_n = 1; start = 1;
      @(negedge clock);
      start = 0; waited = 0;
      while (!train_error[0] && waited <= 8001) begin
        @(negedge clock);
        waited++;
      end
      if (waited != 8000 || !train_error[0] || degrade_exit[0] ||
          !degrade_exit[1] || train_error[1] || degrade_req_count[0] != 1 ||
          degrade_rsp_count[1] != 1)
        $fatal(1, "Lost degrade response did not prevent exit until timeout");
      drop_degrade_response[1] = 0;
      completed_scenarios++;
    end
  endtask

  task automatic run_timeout(input int clocks_per_us);
    int elapsed, expected;
    begin
      @(negedge clock);
      reset_n = 0; start = 0; block_all_tx = 1; block_done_response = 0; inject_stall = 0;
      cycles_1us = 32'(clocks_per_us);
      lane_pass[0] = '1; lane_pass[1] = '1; corrupt_mode[0] = 0; corrupt_mode[1] = 0;
      repeat (3) @(negedge clock);
      reset_n = 1; start = 1;
      @(negedge clock);
      start = 0; elapsed = 0;
      expected = 8000 * (clocks_per_us == 0 ? 1 : clocks_per_us);
      while (!(train_error[0] && train_error[1]) && elapsed <= expected + 2) begin
        @(negedge clock);
        elapsed++;
      end
      if (elapsed != expected || !train_error[0] || !train_error[1] ||
          busy[0] || busy[1] || done[0] || done[1] || degrade_exit[0] || degrade_exit[1] ||
          tx_valid[0] || tx_valid[1])
        $fatal(1, "Timeout did not abort at 8000 us: clocks/us=%0d elapsed=%0d", clocks_per_us, elapsed);
      completed_scenarios++;
    end
  endtask

  task automatic run_stall_extension;
    int waited;
    begin
      @(negedge clock);
      reset_n = 0; start = 0; block_all_tx = 0; block_done_response = 1; inject_stall = 0;
      cycles_1us = 1;
      lane_pass[0] = '1; lane_pass[1] = '1; corrupt_mode[0] = 0; corrupt_mode[1] = 0;
      repeat (3) @(negedge clock);
      reset_n = 1; start = 1;
      @(negedge clock);
      start = 0; waited = 0;
      while (!(tx_valid[0] && tx_valid[1] &&
               tx_message[0] == msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) &&
               tx_message[1] == msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))) begin
        @(negedge clock);
        if (++waited > 1000) $fatal(1, "No stalled DONE responses");
      end
      repeat (6500) @(negedge clock);
      inject_stall = 1;
      @(negedge clock);
      inject_stall = 0;
      repeat (7000) @(negedge clock);
      if (train_error[0] || train_error[1] || !busy[0] || !busy[1])
        $fatal(1, "Valid DONE Stall did not restart the 8 ms counter");
      block_done_response = 0; waited = 0;
      while (!(done[0] && done[1])) begin
        @(negedge clock);
        if (++waited > 1000) $fatal(1, "DONE exchange failed after Stall");
      end
      completed_scenarios++;
    end
  endtask

  initial begin
    lane_pass[0] = '1; lane_pass[1] = '1;
    corrupt_mode[0] = 0; corrupt_mode[1] = 0;
    drop_degrade_response[0] = 0; drop_degrade_response[1] = 0;
    // Literal packets independently enforce the UCIe 2.0 Table 7-9 fields,
    // endpoints and header parity, rather than comparing helpers to themselves.
    if (msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) !==
        128'h000000000000000006000018402d4012 ||
        msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) !==
        128'h000000000000000006000018402e8012)
      $fatal(1, "Wrong exit-to-speed-degrade wire encoding");
    // Every representable failed-lane population, with independent $countones
    // expectations instead of the RTL tree; also exercise each physical bit.
    for (int failures = 0; failures <= 16; failures++)
      run_case(16'hffff, 16'hffff << failures, 0, 0);
    for (int lane = 0; lane < 16; lane++)
      run_case(~(16'b1 << lane), 16'hffff, 0, 0);
    run_case(16'h00ff, 16'hf000, 0, 0); // Both peers fail simultaneously.
    for (int corruption = 1; corruption <= 3; corruption++)
      run_case(16'hffff, 16'hffff, 0, 3'(corruption));
    run_case(16'hffff, 16'hfffe, 0, 4); // Summary says pass; bitmap still fails.
    run_timeout(0); // Explicitly verify zero clamps to one clock/us.
    run_timeout(2);
    run_stall_extension();
    run_missing_degrade_response();
    run_case(16'hffff, 16'hffff, 0, 0); // Recovery after timed-out attempts.
    $display("PASS LinkSpeedSpec_tb: %0d two-peer count/error/degrade/stall/timeout scenarios", completed_scenarios);
    $finish;
  end
endmodule

`default_nettype wire
