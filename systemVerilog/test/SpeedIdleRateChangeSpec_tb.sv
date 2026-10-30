`timescale 1ns/1ps
`default_nettype none

module SpeedIdleRateChangeSpec_tb;
  import SidebandMsgGenerator_pkg::*;
  logic clock = 0;
  always #0.625 clock = ~clock;
  logic reset_n = 0, start = 0, speed_applied = 0, at_floor = 0;
  logic tx_ready = 0, rx_valid = 0;
  logic [31:0] cycles_us = 1;
  logic [127:0] rx_data = 0;
  wire tx_valid, busy, done, train_error;
  wire [127:0] tx_data;
  wire [1:0] sender_state, receiver_state;
  int done_req_count = 0, done_rsp_count = 0, error_req_count = 0, error_rsp_count = 0;
  int scenarios = 0;
  logic held = 0;
  logic [127:0] held_data;
  localparam logic [127:0] DONE_REQ = msgMbtrainSpeedIdleDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] DONE_RSP = msgMbtrainSpeedIdleDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] ERROR_REQ = msgWithoutPayloadBase(16'd0,
    UCIe2_LtsmMsgCode_TRAINERROR_REQ, 8'd0, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] ERROR_RSP = msgWithoutPayloadBase(16'd0,
    UCIe2_LtsmMsgCode_TRAINERROR_RSP, 8'd0, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  MBTrainSpeedIdleFSM dut (
    .clock(clock), .reset_n(reset_n), .start(start), .speedApplied(speed_applied),
    .speedDegradeAtFloor(at_floor), .cycles_1us(cycles_us),
    .busy(busy), .done(done), .trainError(train_error),
    .sb_tx_ready(tx_ready), .sb_tx_valid(tx_valid), .sb_tx_din(tx_data),
    .sb_rx_valid(rx_valid), .sb_rx_dout(rx_data),
    .dbg_senderState(sender_state), .dbg_receiverState(receiver_state)
  );
  task automatic tick(input int count = 1);
    repeat (count) begin @(posedge clock); #0.01; end
  endtask
  task automatic receive(input logic [127:0] message);
    @(negedge clock); rx_data = message; rx_valid = 1;
    tick(); @(negedge clock); rx_valid = 0; tick();
  endtask
  task automatic begin_case(input bit floor_case, input logic [31:0] cycles = 1);
    @(negedge clock); reset_n = 0; start = 0; speed_applied = 0;
    at_floor = floor_case; cycles_us = cycles; tx_ready = 0; rx_valid = 0;
    tick(3); @(negedge clock); reset_n = 1; start = 1;
    tick(); @(negedge clock); start = 0; tick();
  endtask
  task automatic await_exit(input bit expect_error, input int limit = 100);
    for (int n = 0; n < limit; n++) begin
      tick();
      if (done || train_error) begin
        if (train_error != expect_error || done == expect_error || busy || tx_valid)
          $fatal(1, "Incorrect SPEEDIDLE exit done=%b error=%b busy=%b valid=%b", done, train_error, busy, tx_valid);
        scenarios++;
        return;
      end
    end
    $fatal(1, "SPEEDIDLE exit timeout");
  endtask
  task automatic await_error_request(input int limit = 8100);
    for (int n = 0; n < limit; n++) begin
      tick();
      if (done || train_error) $fatal(1, "Exited before the TRAINERROR request was accepted");
      if (error_req_count == 1) return;
    end
    $fatal(1, "Missing residency-timeout TRAINERROR request");
  endtask
  always @(posedge clock) begin
    if (!reset_n) begin
      done_req_count <= 0; done_rsp_count <= 0; error_req_count <= 0; error_rsp_count <= 0; held <= 0;
    end else begin
      if (held && (!tx_valid || tx_data !== held_data))
        $fatal(1, "SPEEDIDLE changed an unaccepted packet");
      held <= tx_valid && !tx_ready; held_data <= tx_data;
      if (tx_valid && tx_ready) begin
        case (tx_data)
          DONE_REQ: done_req_count <= done_req_count + 1;
          DONE_RSP: done_rsp_count <= done_rsp_count + 1;
          ERROR_REQ: error_req_count <= error_req_count + 1;
          ERROR_RSP: error_rsp_count <= error_rsp_count + 1;
          default: $fatal(1, "Unexpected SPEEDIDLE packet %032h", tx_data);
        endcase
      end
    end
  end

  initial begin
    // A peer's early done request cannot bypass our PLL acknowledgement.
    begin_case(0); receive(DONE_REQ); tick(12);
    if (tx_valid || sender_state != 0 || done || train_error)
      $fatal(1, "SPEEDIDLE progressed before applied acknowledgement");
    @(negedge clock); speed_applied = 1; tick();
    @(negedge clock); speed_applied = 0; tick(12);
    if (!tx_valid || tx_data !== DONE_RSP) $fatal(1, "Applied pulse was not retained");
    @(negedge clock); tx_ready = 1;
    while (done_req_count == 0) tick();
    receive(DONE_RSP); await_exit(0);
    if (done_req_count != 1 || done_rsp_count != 1 || error_req_count != 0 || error_rsp_count != 0)
      $fatal(1, "Normal SPEEDIDLE repeated or incorrect packet");

    // At 4 GT/s, no PLL ack is required: exchange TRAINERROR entry instead.
    begin_case(1); tick(10);
    if (!tx_valid || tx_data !== ERROR_REQ || train_error) $fatal(1, "Floor did not hold TRAINERROR request");
    receive(ERROR_REQ); tick(8);
    @(negedge clock); tx_ready = 1;
    while (error_req_count == 0) tick();
    receive(ERROR_RSP); await_exit(1);
    if (error_req_count != 1 || error_rsp_count != 1 || done_req_count != 0 || done_rsp_count != 0)
      $fatal(1, "Floor handshake packets incorrect");

    // A partner can abort while this side waits for its PLL; respond once.
    begin_case(0); receive(ERROR_REQ); tick(10);
    if (!tx_valid || tx_data !== ERROR_RSP || train_error)
      $fatal(1, "Peer TRAINERROR did not wait for accepted response");
    @(negedge clock); tx_ready = 1; await_exit(1);
    if (error_req_count != 0 || error_rsp_count != 1 || done_req_count != 0 || done_rsp_count != 0)
      $fatal(1, "Peer-initiated TRAINERROR sent unexpected request");

    // An abort cannot replace an earlier unaccepted packet. Drain that packet,
    // then the error response, before reporting the terminal exit.
    begin_case(0); @(negedge clock); speed_applied = 1; tick(8);
    if (!tx_valid || tx_data !== DONE_REQ) $fatal(1, "Expected pending normal request");
    receive(ERROR_REQ); tick(10);
    if (!tx_valid || tx_data !== DONE_REQ || train_error)
      $fatal(1, "TRAINERROR replaced a pending normal packet");
    @(negedge clock); tx_ready = 1; await_exit(1);
    if (error_req_count != 0 || error_rsp_count != 1 || done_req_count != 1 || done_rsp_count != 0)
      $fatal(1, "Abort did not drain exactly the pending packet and error response");

    // A missing PLL acknowledgement starts TRAINERROR after normal 8 ms
    // residency. Its own unanswered request then receives a fresh 8 ms bound.
    begin_case(0); @(negedge clock); tx_ready = 1; tick(7980);
    if (tx_valid || error_req_count != 0 || done || train_error)
      $fatal(1, "PLL residency timeout fired too early");
    await_error_request(40);
    if (done_req_count != 0 || done_rsp_count != 0)
      $fatal(1, "Unapplied rate sent SPEEDIDLE done packets");
    tick(7990);
    if (train_error) $fatal(1, "TRAINERROR entry timer was not restarted");
    await_exit(1, 20);

    // Completing one direction cannot disable the residency watchdog for a
    // missing partner done response; a late done cannot end the error exchange.
    begin_case(0); @(negedge clock); tx_ready = 1; speed_applied = 1;
    receive(DONE_REQ);
    while (done_req_count == 0 || done_rsp_count == 0) tick();
    await_error_request();
    receive(DONE_RSP); tick(5);
    if (done || train_error) $fatal(1, "Late SPEEDIDLE response bypassed TRAINERROR handshake");
    receive(ERROR_RSP); await_exit(1);
    if (done_req_count != 1 || done_rsp_count != 1 || error_req_count != 1 || error_rsp_count != 0)
      $fatal(1, "Missing done-response timeout repeated packets");

    // The watchdog must preserve a normal packet stalled at the timeout, then
    // issue its error request only after that original packet is accepted.
    begin_case(0); @(negedge clock); speed_applied = 1; tick(8020);
    if (!tx_valid || tx_data !== DONE_REQ || done || train_error)
      $fatal(1, "Residency timeout corrupted a pending packet");
    @(negedge clock); tx_ready = 1; await_error_request(30);
    if (done_req_count != 1) $fatal(1, "Error request overtook pending done request");
    receive(ERROR_RSP); await_exit(1);
    if (error_req_count != 1 || done_rsp_count != 0 || error_rsp_count != 0)
      $fatal(1, "Stalled residency timeout repeated packets");

    // 8 ms timeout is measured from accepted local request, never its enqueue.
    // Exercise both zero-to-one clamp and the nested cycle/us counter.
    for (int cycles = 0; cycles <= 2; cycles++) begin
      int elapsed;
      begin_case(1, 32'(cycles)); tick(30);
      if (train_error) $fatal(1, "Timeout ran before request acceptance");
      @(negedge clock); tx_ready = 1;
      while (error_req_count == 0) tick();
      elapsed = 0;
      while (!train_error && elapsed < 17000) begin tick(); elapsed++; end
      if (!train_error || elapsed < 8000 * ((cycles == 0) ? 1 : cycles) ||
          elapsed > 8000 * ((cycles == 0) ? 1 : cycles) + 3 || done || busy ||
          error_req_count != 1 || error_rsp_count != 0 || done_req_count != 0 || done_rsp_count != 0)
        $fatal(1, "Incorrect TRAINERROR timeout cycles/us=%0d elapsed=%0d", cycles, elapsed);
      scenarios++;
    end
    $display("PASS SpeedIdleRateChangeSpec_tb: %0d cases", scenarios);
    $finish;
  end
  initial begin #100000; $fatal(1, "Global timeout"); end
endmodule
`default_nettype wire
