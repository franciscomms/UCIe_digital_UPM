`timescale 1ns/1ps
`default_nettype none

// Real peer-to-peer calibration exchanges, repeated without reset. Checking
// every request/response and analog calibration request catches a stale DONE
// shortcut that a test observing only terminal states would miss.
module TrainingRestartSpec_tb;
  import SidebandMsgGenerator_pkg::*;
  logic clock = 1'b0;
  always #5 clock = ~clock;
  logic reset_n = 1'b0;
  logic start = 1'b0;
  wire [1:0] tx_done, tx_error, tx_valid, rx_done, rx_error, rx_valid;
  wire [1:0] calibrate, calibration_done;
  wire [127:0] tx_packet [0:1], rx_packet [0:1];
  logic [2:0] calibration_delay [0:1];
  logic [1:0] previous_calibrate;
  int tx_req_count [0:1], tx_resp_count [0:1];
  int rx_start_req_count [0:1], rx_start_resp_count [0:1];
  int rx_done_req_count [0:1], rx_done_resp_count [0:1];
  int calibration_count [0:1];

  for (genvar die = 0; die < 2; die++) begin : g_peer
    MBTrainTxSelfCalFSM tx_self_cal (
      .clock(clock), .reset_n(reset_n), .start(start),
      .busy(), .done(tx_done[die]), .trainError(tx_error[die]),
      .sb_tx_ready(1'b1), .sb_tx_valid(tx_valid[die]), .sb_tx_din(tx_packet[die]),
      .sb_rx_valid(tx_valid[1-die]), .sb_rx_dout(tx_packet[1-die]),
      .dbg_senderState(), .dbg_receiverState()
    );
    MBTrainRxClkCalFSM rx_clock_cal (
      .clock(clock), .reset_n(reset_n), .start(start),
      .busy(), .done(rx_done[die]), .trainError(rx_error[die]),
      .sb_tx_ready(1'b1), .sb_tx_valid(rx_valid[die]), .sb_tx_din(rx_packet[die]),
      .sb_rx_valid(rx_valid[1-die]), .sb_rx_dout(rx_packet[1-die]),
      .flagToAnalog_rxClkCalDoCalibration(calibrate[die]),
      .flagFromAnalog_rxClkCalDone(calibration_done[die]),
      .flagToAnalog_rxClkCalSendClockTrack(), .dbg_senderState(), .dbg_receiverState()
    );
    assign calibration_done[die] = calibration_delay[die][2];

    always_ff @(posedge clock or negedge reset_n) begin
      if (!reset_n) begin
        calibration_delay[die] <= '0;
        previous_calibrate[die] <= 1'b0;
        calibration_count[die] <= 0;
        tx_req_count[die] <= 0;
        tx_resp_count[die] <= 0;
        rx_start_req_count[die] <= 0;
        rx_start_resp_count[die] <= 0;
        rx_done_req_count[die] <= 0;
        rx_done_resp_count[die] <= 0;
      end else begin
        previous_calibrate[die] <= calibrate[die];
        calibration_delay[die] <= {calibration_delay[die][1:0],
                                   calibrate[die] && !previous_calibrate[die]};
        if (calibrate[die] && !previous_calibrate[die])
          calibration_count[die] <= calibration_count[die] + 1;
        if (tx_valid[die]) begin
          if (tx_packet[die] == msgMbtrainTxSelfCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            tx_req_count[die] <= tx_req_count[die] + 1;
          else if (tx_packet[die] == msgMbtrainTxSelfCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            tx_resp_count[die] <= tx_resp_count[die] + 1;
          else $fatal(1, "Unexpected TXSELFCAL packet die=%0d", die);
        end
        if (rx_valid[die]) begin
          if (rx_packet[die] == msgMbtrainRxClkCalStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            rx_start_req_count[die] <= rx_start_req_count[die] + 1;
          else if (rx_packet[die] == msgMbtrainRxClkCalStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            rx_start_resp_count[die] <= rx_start_resp_count[die] + 1;
          else if (rx_packet[die] == msgMbtrainRxClkCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            rx_done_req_count[die] <= rx_done_req_count[die] + 1;
          else if (rx_packet[die] == msgMbtrainRxClkCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY))
            rx_done_resp_count[die] <= rx_done_resp_count[die] + 1;
          else $fatal(1, "Unexpected RXCLKCAL packet die=%0d", die);
        end
        if (|tx_error || |rx_error) $fatal(1, "Calibration reported an error");
      end
    end
  end

  task automatic run_training(input int run_number);
    int cycles;
    @(negedge clock);
    start = 1'b1;
    @(negedge clock);
    if (|tx_done || |rx_done)
      $fatal(1, "Sticky DONE was not cleared on restart %0d", run_number);
    cycles = 0;
    while (!( &tx_done && &rx_done )) begin
      if (++cycles > 100)
        $fatal(1, "Calibration restart %0d timed out", run_number);
      @(negedge clock);
    end
    // Keep start asserted as the parent does while observing completion.
    repeat (3) @(negedge clock);
    for (int die = 0; die < 2; die++) begin
      if (tx_req_count[die] != run_number || tx_resp_count[die] != run_number ||
          rx_start_req_count[die] != run_number || rx_start_resp_count[die] != run_number ||
          rx_done_req_count[die] != run_number || rx_done_resp_count[die] != run_number ||
          calibration_count[die] != run_number)
        $fatal(1, "Skipped/repeated exchange on run=%0d die=%0d: TX=%0d/%0d RX=%0d/%0d/%0d/%0d analog=%0d",
          run_number, die, tx_req_count[die], tx_resp_count[die],
          rx_start_req_count[die], rx_start_resp_count[die],
          rx_done_req_count[die], rx_done_resp_count[die], calibration_count[die]);
    end
    start = 1'b0;
    repeat (3) @(negedge clock);
  endtask

  initial begin
    repeat (3) @(negedge clock);
    reset_n = 1'b1;
    run_training(1);
    run_training(2);
    run_training(3);
    $display("PASS TrainingRestartSpec_tb: three complete TXSELFCAL/RXCLKCAL peer exchanges and analog calibrations without reset");
    $finish;
  end
endmodule

`default_nettype wire
