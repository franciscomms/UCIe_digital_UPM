`timescale 1ns/1ps
`default_nettype none

// Repeat all three complete centering stages without resetting their sticky
// point-test children. This models speed fallback and catches stale transactions.
module CenterStageRestartSpec_tb;
  import SidebandMsgGenerator_pkg::*;
  logic clock=0;
  always #5 clock=~clock;
  logic reset_n=0, start=0, round_reset=0;
  int round_number=0;
  wire [1:0] complete [0:2], failed [0:2];
  wire [1:0] tx_valid [0:2], phase_apply [0:2], pattern [0:2];
  wire [127:0] tx_message [0:2][0:1];
  int phase_wait [0:2][0:1], phase_count [0:2][0:1];
  bit seen_first [0:2][0:1];
  function automatic logic [127:0] expected_start(input int kind);
    case(kind)
      0: return msgMbtrainValTrainCenterStartReq(ENDPOINT_PHY,ENDPOINT_REMOTE_PHY);
      1: return msgMbtrainDataTrainCenter1StartReq(ENDPOINT_PHY,ENDPOINT_REMOTE_PHY);
      default: return msgMbtrainDataTrainCenter2StartReq(ENDPOINT_PHY,ENDPOINT_REMOTE_PHY);
    endcase
  endfunction
  for(genvar die=0;die<2;die++) begin : stage0
    wire apply_deskew;
    MBTrain_ValTrainCenter dut (
      .clock(clock),.reset_n(reset_n),.start(start),
      .done(complete[0][die]),.trainError(failed[0][die]),
      .sb_tx_ready(1'b1),.sb_tx_valid(tx_valid[0][die]),.sb_tx_din(tx_message[0][die]),
      .sb_rx_valid(tx_valid[0][1-die]),.sb_rx_dout(tx_message[0][1-die]),
      .flagToAnalog_d2cSender_applyTxClockPhase(phase_apply[0][die]),
      .flagFromAnalog_d2cSender_txClockPhaseApplied(phase_wait[0][die]>=2),
      .flagToAnalog_d2cSender_sendValTrainPattern(pattern[0][die]),
      .flagFromAnalog_d2cSender_valTrainPatternSent(pattern[0][die]),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(16'h0030),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(64'h000000000000ffff)
    );
    always @(posedge clock) begin
      if(!reset_n || round_reset) begin
        phase_wait[0][die]<=0; phase_count[0][die]<=0; seen_first[0][die]<=0;
      end else begin
        phase_wait[0][die]<=phase_apply[0][die] ? phase_wait[0][die]+1 : 0;
        if(phase_apply[0][die] && phase_wait[0][die]>=2) phase_count[0][die]++;
        if(start && tx_valid[0][die] && !seen_first[0][die]) begin
          if(tx_message[0][die]!==expected_start(0))
            $fatal(1,"Stale first packet round=%0d kind=0 die=%0d header=%h",round_number,die,tx_message[0][die][63:0]);
          seen_first[0][die]<=1;
        end
      end
    end
  end
  for(genvar die=0;die<2;die++) begin : stage1
    wire apply_deskew;
    MBTrain_DataTrainCenter1 dut (
      .clock(clock),.reset_n(reset_n),.start(start),
      .done(complete[1][die]),.trainError(failed[1][die]),
      .sb_tx_ready(1'b1),.sb_tx_valid(tx_valid[1][die]),.sb_tx_din(tx_message[1][die]),
      .sb_rx_valid(tx_valid[1][1-die]),.sb_rx_dout(tx_message[1][1-die]),
      .flagToAnalog_d2cSender_applyTxClockPhase(phase_apply[1][die]),
      .flagFromAnalog_d2cSender_txClockPhaseApplied(phase_wait[1][die]>=2),
      .flagToAnalog_d2cSender_sendLfsrPattern(pattern[1][die]),
      .flagFromAnalog_d2cSender_lfsrPatternSent(pattern[1][die]),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(16'h0030),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(64'h000000000000ffff),
      .flagToAnalog_d2cSender_applyTxLaneDeskew(apply_deskew),
      .flagFromAnalog_d2cSender_txLaneDeskewApplied(apply_deskew)
    );
    always @(posedge clock) begin
      if(!reset_n || round_reset) begin
        phase_wait[1][die]<=0; phase_count[1][die]<=0; seen_first[1][die]<=0;
      end else begin
        phase_wait[1][die]<=phase_apply[1][die] ? phase_wait[1][die]+1 : 0;
        if(phase_apply[1][die] && phase_wait[1][die]>=2) phase_count[1][die]++;
        if(start && tx_valid[1][die] && !seen_first[1][die]) begin
          if(tx_message[1][die]!==expected_start(1))
            $fatal(1,"Stale first packet round=%0d kind=1 die=%0d header=%h",round_number,die,tx_message[1][die][63:0]);
          seen_first[1][die]<=1;
        end
      end
    end
  end
  for(genvar die=0;die<2;die++) begin : stage2
    wire apply_deskew;
    MBTrain_DataTrainCenter2 dut (
      .clock(clock),.reset_n(reset_n),.start(start),
      .done(complete[2][die]),.trainError(failed[2][die]),
      .sb_tx_ready(1'b1),.sb_tx_valid(tx_valid[2][die]),.sb_tx_din(tx_message[2][die]),
      .sb_rx_valid(tx_valid[2][1-die]),.sb_rx_dout(tx_message[2][1-die]),
      .flagToAnalog_d2cSender_applyTxClockPhase(phase_apply[2][die]),
      .flagFromAnalog_d2cSender_txClockPhaseApplied(phase_wait[2][die]>=2),
      .flagToAnalog_d2cSender_sendLfsrPattern(pattern[2][die]),
      .flagFromAnalog_d2cSender_lfsrPatternSent(pattern[2][die]),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo(16'h0030),
      .flagFromAnalog_d2cReceiver_txInitD2CResultsPayload(64'h000000000000ffff)
    );
    always @(posedge clock) begin
      if(!reset_n || round_reset) begin
        phase_wait[2][die]<=0; phase_count[2][die]<=0; seen_first[2][die]<=0;
      end else begin
        phase_wait[2][die]<=phase_apply[2][die] ? phase_wait[2][die]+1 : 0;
        if(phase_apply[2][die] && phase_wait[2][die]>=2) phase_count[2][die]++;
        if(start && tx_valid[2][die] && !seen_first[2][die]) begin
          if(tx_message[2][die]!==expected_start(2))
            $fatal(1,"Stale first packet round=%0d kind=2 die=%0d header=%h",round_number,die,tx_message[2][die][63:0]);
          seen_first[2][die]<=1;
        end
      end
    end
  end
  initial begin
    repeat(3) @(negedge clock);
    reset_n=1;
    for(int round_index=0;round_index<3;round_index++) begin
      int cycles;
      round_number=round_index;
      start=0; round_reset=1;
      @(negedge clock);
      round_reset=0; start=1;
      // Allow each wrapper to clear its previous sticky done on the start edge.
      repeat(2) @(negedge clock);
      cycles=0;
      while(!(complete[0]==2'b11 && complete[1]==2'b11 && complete[2]==2'b11)) begin
        if(failed[0] || failed[1] || failed[2]) $fatal(1,"Center stage error round=%0d",round_index);
        @(negedge clock);
        if(++cycles>60000) $fatal(1,"Center restart timeout round=%0d done=%b/%b/%b",round_index,complete[0],complete[1],complete[2]);
      end
      for(int kind=0;kind<3;kind++) for(int die=0;die<2;die++) begin
        if(phase_count[kind][die]!=(kind==1 ? 529 : 265))
          $fatal(1,"Repeated center skipped points round=%0d kind=%0d die=%0d phases=%0d",round_index,kind,die,phase_count[kind][die]);
      end
      $display("PASS center restart round=%0d phases=265/529/265 on both peers",round_index);
      start=0;
      repeat(20) @(negedge clock);
    end
    $display("PASS CenterStageRestartSpec_tb: all three stages, three starts without reset, no stale packets or skipped phases");
    $finish;
  end
endmodule
`default_nettype wire
