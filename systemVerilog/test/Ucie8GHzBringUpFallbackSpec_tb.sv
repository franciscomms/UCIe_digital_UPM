// Dedicated full serial bring-up: fail lane 0 at 8 GHz, then retrain at 6 GHz.
// Two real digital dies communicate through the existing one-bit sideband
// serializers/CDC. The behavioral PHY reports FFFE only at speed code 3 on
// die0's receiver; it reports FFFF at code 2. No DUT state/rate is forced.
// The GHz labels denote requested PHY settings, not simulated analog clocks.
// Compile the shared harness and D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb
// before this file, or use scripts/run_tests.sh Ucie8GHzBringUpFallbackSpec_tb.
`timescale 1ns/1ps
`default_nettype none

module Ucie8GHzBringUpFallbackSpec_tb #(
  parameter bit TEST_MODE_DIGITAL = 1'b0
);
  import SidebandMsgGenerator_pkg::*;

  D2DAdapterLinkMgmtLtsmDualDieBringUpSpec_tb #(
    .LINK_SPEED_FAIL_TOP_RATE_MASK(2'b01),
    .LINK_SPEED_FAIL_ALL_RATES(1'b0),
    .TEST_MODE_DIGITAL(TEST_MODE_DIGITAL)
  ) scenario ();

  wire clock = scenario.clock;
  wire reset_n = scenario.reset_n;
  wire [1:0] tx_fire = {
    scenario.dut.mon_die1_tx_valid && scenario.dut.mon_die1_tx_ready,
    scenario.dut.mon_die0_tx_valid && scenario.dut.mon_die0_tx_ready};
  wire [1:0] rx_fire = {
    scenario.dut.mon_die1_rx_valid && scenario.dut.mon_die1_rx_ready,
    scenario.dut.mon_die0_rx_valid && scenario.dut.mon_die0_rx_ready};
  wire [127:0] tx_message [0:1];
  wire [127:0] rx_message [0:1];
  assign tx_message[0] = scenario.dut.mon_die0_tx_msg;
  assign tx_message[1] = scenario.dut.mon_die1_tx_msg;
  assign rx_message[0] = scenario.dut.mon_die0_rx_msg;
  assign rx_message[1] = scenario.dut.mon_die1_rx_msg;
  // The child completes a local send when the pulse-capture queue accepts it.
  // The downstream serializer tap can lag under backpressure. Observe both:
  // capture for local apply ordering, serializer TX/RX for eventual delivery.
  wire [1:0] capture_fire;
  wire [127:0] capture_message [0:1];
  assign capture_fire[0] = scenario.dut.die0.sb_mon_ltsm_enqueue;
  assign capture_fire[1] = scenario.dut.die1.sb_mon_ltsm_enqueue;
  assign capture_message[0] = scenario.dut.die0.sb_mon_ltsm_enqueue_msg;
  assign capture_message[1] = scenario.dut.die1.sb_mon_ltsm_enqueue_msg;
  wire [1:0] applied = {
    scenario.dut.die1.ltsm_flagFromAnalog_linkSpeed_speedApplied,
    scenario.dut.die0.ltsm_flagFromAnalog_linkSpeed_speedApplied};
  wire [1:0] calibrate_rx = {
    scenario.dut.die1.ltsm_flagToAnalog_rxClkCal_doCalibration,
    scenario.dut.die0.ltsm_flagToAnalog_rxClkCal_doCalibration};

  localparam logic [127:0] ERROR_REQ =
    msgMbtrainLinkSpeedErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] ERROR_RESP =
    msgMbtrainLinkSpeedErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] DEGRADE_REQ =
    msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [127:0] DEGRADE_RESP =
    msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  localparam logic [15:0] REQUIRED_RATE_STAGES = 16'h1ff8; // SPEEDIDLE..LINKSPEED

  // Event bit 0=ERROR request, 1=ERROR response, 2=DEGRADE request, 3=response.
  // Each direction is checked at both TX acceptance and actual serial RX.
  bit [3:0] tx_events [0:1], rx_events [0:1], capture_events [0:1];
  bit [15:0] stages [0:1][0:1]; // rate index 0=8 GHz, 1=6 GHz
  bit [10:0] training_packets [0:1][0:1];
  bit result_seen [0:1][0:1], rx_calibrated [0:1][0:1];
  logic [3:0] previous_stage [0:1];
  logic [1:0] previous_apply, previous_applied;
  bit checked_active;

  function automatic int event_index(input logic [127:0] message);
    if (message == ERROR_REQ) return 0;
    if (message == ERROR_RESP) return 1;
    if (message == DEGRADE_REQ) return 2;
    if (message == DEGRADE_RESP) return 3;
    return -1;
  endfunction

  function automatic string event_name(input int index);
    case (index)
      0: return "LINKSPEED ERROR request";
      1: return "LINKSPEED ERROR response";
      2: return "LINKSPEED speed-degrade request";
      3: return "LINKSPEED speed-degrade response";
      default: return "unknown";
    endcase
  endfunction

  function automatic string stage_name(input logic [3:0] stage);
    case (stage)
      3: return "SPEEDIDLE";
      4: return "TXSELFCAL";
      5: return "RXCLKCAL";
      6: return "VALTRAINCENTER";
      7: return "VALTRAINVREF";
      8: return "DATATRAINCENTER1";
      9: return "DATATRAINVREF";
      10: return "RXDESKEW";
      11: return "DATATRAINCENTER2";
      12: return "LINKSPEED";
      default: return "other";
    endcase
  endfunction

  // Fresh stage protocol traffic prevents a bare state-visit mask from passing
  // when sticky completion flags skip the actual second calibration/sweep.
  function automatic int training_packet_index(input logic [127:0] message);
    if (message[4:0] != 5'h12 || message[21:14] != 8'hb5) return -1;
    case (message[39:32])
      8'h05: return 0; // TXSELFCAL done
      8'h06: return 1; // RXCLKCAL start
      8'h07: return 2; // RXCLKCAL done
      8'h08: return 3; // VALTRAINCENTER start
      8'h09: return 4; // VALTRAINCENTER done
      8'h0c: return 5; // DATATRAINCENTER1 start
      8'h0d: return 6; // DATATRAINCENTER1 end
      8'h13: return 7; // DATATRAINCENTER2 start
      8'h14: return 8; // DATATRAINCENTER2 end
      8'h15: return 9; // LINKSPEED start
      8'h19: return 10; // LINKSPEED done (only expected at 6 GHz)
      default: return -1;
    endcase
  endfunction

  initial $display("SCENARIO: 8 GHz first attempt fails lane 0; expect ERROR -> DEGRADE -> 6 GHz retraining -> Active");

  // Blocking scoreboard updates make same-cycle events visible to later checks
  // within this passive monitor. Stimulus and DUT registers are not modified.
  always @(posedge clock or negedge reset_n) begin : monitor
    int rate, event_id, packet_id;
    if (!reset_n) begin
      previous_apply = '0;
      previous_applied = '0;
      checked_active = 1'b0;
      for (int die = 0; die < 2; die++) begin
        tx_events[die] = '0;
        rx_events[die] = '0;
        capture_events[die] = '0;
        previous_stage[die] = '0;
        for (int r = 0; r < 2; r++) begin
          stages[die][r] = '0;
          training_packets[die][r] = '0;
          result_seen[die][r] = 1'b0;
          rx_calibrated[die][r] = 1'b0;
        end
      end
    end else begin
      for (int die = 0; die < 2; die++) begin
        rate = (scenario.observedSpeedCode[die] == 2'd2) ? 1 : 0;
        if (scenario.observedSpeedCode[die] inside {2'd2, 2'd3}) begin
          stages[die][rate] |= 16'h1 << scenario.observedMbtrainState[die];
          if (calibrate_rx[die]) rx_calibrated[die][rate] = 1'b1;
          if (scenario.observedMbtrainState[die] != previous_stage[die] &&
              scenario.observedMbtrainState[die] inside {[4'd3:4'd12]})
            $display("FALLBACK cycle=%0d die%0d %0d GHz enter %s",
              scenario.elapsedCycles, die, rate ? 6 : 8,
              stage_name(scenario.observedMbtrainState[die]));
        end

        if (rx_fire[die]) begin
          event_id = event_index(rx_message[die]);
          if (event_id >= 0) begin
            if (rx_events[die][event_id] || ((event_id % 2) != die))
              $fatal(1, "Duplicate/wrong-direction fallback RX event die%0d index%0d", die, event_id);
            rx_events[die][event_id] = 1'b1;
            $display("FALLBACK cycle=%0d die%0d RX %s", scenario.elapsedCycles, die, event_name(event_id));
          end
          if (scenario.observedMbtrainState[die] == 4'hc &&
              rx_message[die][4:0] == 5'h1b &&
              rx_message[die][21:14] == 8'h8a && rx_message[die][39:32] == 8'h03) begin
            if (result_seen[die][rate]) $fatal(1, "Duplicate LINKSPEED result");
            if (rate == 0 && die == 1) begin
              if (rx_message[die][55:40] !== 16'h0020 || rx_message[die][127:64] !== 64'hfffe)
                $fatal(1, "8 GHz failure did not reach die1 over the serial link");
              $display("FALLBACK cycle=%0d die1 8 GHz result FAIL: lane0 failed, bitmap=FFFE", scenario.elapsedCycles);
            end else begin
              if (rx_message[die][55:40] !== 16'h0030 || rx_message[die][127:64] !== 64'hffff)
                $fatal(1, "Expected all lanes to pass at die%0d rate index%0d", die, rate);
              $display("FALLBACK cycle=%0d die%0d %0d GHz result PASS: bitmap=FFFF", scenario.elapsedCycles, die, rate ? 6 : 8);
            end
            result_seen[die][rate] = 1'b1;
          end
        end

        if (capture_fire[die]) begin
          event_id = event_index(capture_message[die]);
          if (event_id >= 0) begin
            if (capture_events[die][event_id]) $fatal(1, "Duplicate queued fallback event");
            capture_events[die][event_id] = 1'b1;
          end
        end

        if (tx_fire[die]) begin
          packet_id = training_packet_index(tx_message[die]);
          if (packet_id >= 0) training_packets[die][rate][packet_id] = 1'b1;
          event_id = event_index(tx_message[die]);
          if (event_id >= 0) begin
            if (tx_events[die][event_id] || ((event_id % 2) == die))
              $fatal(1, "Duplicate/wrong-direction fallback TX event die%0d index%0d", die, event_id);
            if (event_id == 0 && !result_seen[1][0])
              $fatal(1, "ERROR sent before the failed result was received");
            if (event_id == 1 && !rx_events[0][0])
              $fatal(1, "ERROR response before request");
            if (event_id == 2 && !rx_events[1][1])
              $fatal(1, "Speed degrade requested before ERROR completed");
            if (event_id == 3 && (!rx_events[0][2] || !tx_events[0][1]))
              $fatal(1, "Speed degrade response out of order");
            tx_events[die][event_id] = 1'b1;
            $display("FALLBACK cycle=%0d die%0d TX %s", scenario.elapsedCycles, die, event_name(event_id));
          end
        end

        if (scenario.observedSpeedApply[die] && !previous_apply[die]) begin
          if (rate == 1 && ((capture_events[die] | rx_events[die]) != 4'hf))
            $fatal(1, "Die%0d applied lower speed before completing local ERROR/DEGRADE obligations", die);
          $display("FALLBACK cycle=%0d die%0d PHY apply %0d GHz (code=%b)",
            scenario.elapsedCycles, die, rate ? 6 : 8, scenario.observedSpeedCode[die]);
        end
        if (applied[die] && !previous_applied[die])
          $display("FALLBACK cycle=%0d die%0d PHY acknowledges %0d GHz", scenario.elapsedCycles, die, rate ? 6 : 8);
        previous_stage[die] = scenario.observedMbtrainState[die];
      end
      previous_apply = scenario.observedSpeedApply;
      previous_applied = applied;

      if (scenario.all_active && !checked_active) begin
        for (int die = 0; die < 2; die++) begin
          if ((tx_events[die] | rx_events[die]) != 4'hf)
            $fatal(1, "Missing ERROR/DEGRADE protocol event");
          for (int r = 0; r < 2; r++) begin
            if ((stages[die][r] & REQUIRED_RATE_STAGES) != REQUIRED_RATE_STAGES ||
                !result_seen[die][r] || !rx_calibrated[die][r] ||
                training_packets[die][r][9:0] != 10'h3ff)
              $fatal(1, "Incomplete actual training die%0d rate index%0d: stages=%h packets=%h", die, r, stages[die][r], training_packets[die][r]);
          end
          if (!training_packets[die][1][10]) $fatal(1, "Missing lower-speed LINKSPEED done request");
        end
        checked_active = 1'b1;
        $display("PASS: Ucie8GHzBringUpFallbackSpec: 8 GHz failed, ERROR/DEGRADE exchanged, both dies retrained and reached Active at 6 GHz");
      end
    end
  end

  // The reused scenario owns timeout, final serial drain and $finish. Ensure
  // its success cannot accidentally bypass this dedicated scenario's checks.
  final begin
    assert (checked_active) else $error("Dedicated speed-fallback checks did not complete");
  end
endmodule

`default_nettype wire
