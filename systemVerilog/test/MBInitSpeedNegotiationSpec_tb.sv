`timescale 1ns/1ps
`default_nettype none

module MBInitSpeedNegotiationSpec_tb #(
  parameter logic [3:0] MAX_SPEED = 4'd3
);
  import SidebandMsgGenerator_pkg::*;
  import LtsmParameters_pkg::*;
  logic clock = 0;
  always #0.625 clock = ~clock;
  logic reset_n = 0, start = 0, tx_ready = 0, rx_valid = 0;
  logic [1:0] requested_speed = 0;
  logic [127:0] rx_data = 0;
  wire tx_valid, train_error, busy, done;
  wire [127:0] tx_data;
  wire [1:0] negotiated_speed;
  wire [2:0] substate;
  int req_count = 0, rsp_count = 0, scenarios = 0;
  logic [3:0] expected_cap, expected_speed;
  logic held = 0;
  logic [127:0] held_data;

  MBInitFSM #(.maxLinkSpeed(MAX_SPEED)) dut (
    .clock(clock), .reset_n(reset_n), .start(start),
    .requestedSpeed(requested_speed), .negotiatedSpeed(negotiated_speed),
    .busy(busy), .done(done), .trainError(train_error), .substate(substate),
    .sb_tx_ready(tx_ready), .sb_tx_valid(tx_valid), .sb_tx_din(tx_data),
    .sb_rx_valid(rx_valid), .sb_rx_dout(rx_data)
  );

  function automatic logic [127:0] param_req(input logic [3:0] speed);
    return msgMbinitParamConfigReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      DEFAULT_SB_FEATURE_EXTENSION, DEFAULT_UCIE_A, DEFAULT_MODULE_ID,
      DEFAULT_CLK_PHASE, DEFAULT_CLK_MODE, DEFAULT_VOLTAGE_SWING, speed);
  endfunction
  function automatic logic [127:0] param_rsp(input logic [3:0] speed);
    return msgMbinitParamConfigResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      DEFAULT_CLK_PHASE, DEFAULT_CLK_MODE, speed);
  endfunction
  task automatic tick(input int count = 1);
    repeat (count) begin @(posedge clock); #0.01; end
  endtask
  task automatic receive(input logic [127:0] message);
    @(negedge clock); rx_data = message; rx_valid = 1;
    tick(); @(negedge clock); rx_valid = 0; tick();
  endtask

  always @(posedge clock) begin
    if (!reset_n) begin
      req_count <= 0; rsp_count <= 0; held <= 0;
    end else begin
      if (held && (!tx_valid || tx_data !== held_data))
        $fatal(1, "PARAM changed an unaccepted packet");
      held <= tx_valid && !tx_ready;
      held_data <= tx_data;
      if (tx_valid && tx_ready && substate == 0) begin
        case (tx_data[21:14])
          8'hA5: begin
            if (tx_data !== param_req(expected_cap))
              $fatal(1, "Wrong latched advertisement: %032h cap=%0d", tx_data, expected_cap);
            req_count <= req_count + 1;
          end
          8'hAA: begin
            if (tx_data !== param_rsp(expected_speed))
              $fatal(1, "Wrong highest-common response: %032h speed=%0d", tx_data, expected_speed);
            rsp_count <= rsp_count + 1;
          end
          default: $fatal(1, "Unexpected PARAM packet");
        endcase
      end
    end
  end

  // mode: 0 successful, 1 invalid advertised speed, 2 incorrect response,
  // 3 reserved parameter bit, 4 bad payload parity.
  task automatic run_case(input logic [1:0] requested, input logic [3:0] remote,
                          input int mode = 0);
    logic [127:0] remote_req;
    @(negedge clock); reset_n = 0; start = 0; rx_valid = 0; tx_ready = 0;
    requested_speed = requested;
    expected_cap = (MAX_SPEED < {2'b0, requested}) ? MAX_SPEED : {2'b0, requested};
    expected_speed = (remote < expected_cap) ? remote : expected_cap;
    tick(3); @(negedge clock); reset_n = 1; start = 1;
    tick(); @(negedge clock); start = 0;
    // Deliberately change the pin during negotiation: it must stay latched.
    requested_speed = ~requested;
    tick(8);
    if (!tx_valid || tx_data !== param_req(expected_cap) || req_count != 0)
      $fatal(1, "PARAM did not hold its first request under backpressure");
    remote_req = param_req(remote);
    if (mode == 3) begin remote_req[127] = 1; remote_req[63] = ^remote_req[127:64]; end
    if (mode == 4) remote_req[63] = ~remote_req[63];
    receive(remote_req);
    tick(5);
    @(negedge clock); tx_ready = 1;
    if (mode == 0 || mode == 2) begin
      receive(param_rsp(mode == 2 ? 4'd5 : expected_speed));
    end
    for (int n = 0; n < 100; n++) begin
      tick();
      if (mode == 0 && substate == 1) begin
        if (train_error || negotiated_speed !== expected_speed[1:0] || req_count != 1 || rsp_count != 1)
          $fatal(1, "Negotiation failed req=%0d rsp=%0d agreed=%0d expected=%0d", req_count, rsp_count, negotiated_speed, expected_speed);
        scenarios++;
        return;
      end
      if (mode != 0 && train_error) begin
        if (substate != 0) $fatal(1, "Malformed parameter advanced into CAL");
        scenarios++;
        return;
      end
    end
    $fatal(1, "Negotiation timeout mode=%0d local=%0d remote=%0d state=%0d", mode, requested, remote, substate);
  endtask

  initial begin
    for (int speed = 0; speed < 4; speed++) run_case(2'(speed), 4'(speed));
    run_case(3, 1); run_case(1, 3); run_case(3, 4); run_case(3, 5);
    run_case(3, 6, 1); run_case(3, 15, 1);
    run_case(3, 1, 2); run_case(3, 3, 3); run_case(3, 3, 4);
    $display("PASS MBInitSpeedNegotiationSpec_tb: %0d cases, MAX_SPEED=%0d", scenarios, MAX_SPEED);
    $finish;
  end
  initial begin #100000; $fatal(1, "Global timeout"); end
endmodule
`default_nettype wire
