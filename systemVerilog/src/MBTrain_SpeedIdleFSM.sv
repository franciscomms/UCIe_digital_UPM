// SystemVerilog translation of MBTrain_SpeedIdleFSM.scala.
`default_nettype none

module MBTrainSpeedIdleFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic         clock,
  input wire logic         reset_n,
  input wire logic         start,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic [1:0]   dbg_senderState,
  output var logic [1:0]   dbg_receiverState
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [1:0] {
    SpeedIdleSenderState_selectLinkSpeed     = 2'd0,
    SpeedIdleSenderState_sendDoneReq = 2'd1,
    SpeedIdleSenderState_waitDoneResp = 2'd2,
    SpeedIdleSenderState_finish      = 2'd3
  } SpeedIdleSenderState_t;

  typedef enum logic [1:0] {
    SpeedIdleReceiverState_waitDoneReq = 2'd0,
    SpeedIdleReceiverState_sendDoneResp = 2'd1,
    SpeedIdleReceiverState_finish      = 2'd2
  } SpeedIdleReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  (* keep = "true" *) logic flagReceivedSpeedIdleDoneReq;
  (* keep = "true" *) logic flagReceivedSpeedIdleDoneResp;
  (* keep = "true" *) logic flagSentSpeedIdleDoneReq;
  (* keep = "true" *) logic flagSentSpeedIdleDoneResp;
  (* keep = "true" *) SpeedIdleSenderState_t speedIdleSenderStateReg;
  (* keep = "true" *) SpeedIdleReceiverState_t speedIdleReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire [127:0] MBTRAIN_SPEEDIDLE_DONE_REQ  = msgMbtrainSpeedIdleDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_SPEEDIDLE_DONE_RESP = msgMbtrainSpeedIdleDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((speedIdleReceiverStateReg == SpeedIdleReceiverState_sendDoneResp) && !flagSentSpeedIdleDoneResp) begin
        nextSbTxDin   = MBTRAIN_SPEEDIDLE_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((speedIdleSenderStateReg == SpeedIdleSenderState_sendDoneReq) && !flagSentSpeedIdleDoneReq) begin
        nextSbTxDin   = MBTRAIN_SPEEDIDLE_DONE_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;
    dbg_senderState = speedIdleSenderStateReg;
    dbg_receiverState = speedIdleReceiverStateReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin   <= 128'b0;
      running   <= 1'b0;
      doneReg   <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedSpeedIdleDoneReq <= 1'b0;
      flagReceivedSpeedIdleDoneResp <= 1'b0;
      flagSentSpeedIdleDoneReq <= 1'b0;
      flagSentSpeedIdleDoneResp <= 1'b0;
      speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
      speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin   <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedSpeedIdleDoneReq <= 1'b0;
        flagReceivedSpeedIdleDoneResp <= 1'b0;
        flagSentSpeedIdleDoneReq <= 1'b0;
        flagSentSpeedIdleDoneResp <= 1'b0;
        speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
        speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_SPEEDIDLE_DONE_REQ)
          flagReceivedSpeedIdleDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_SPEEDIDLE_DONE_RESP)
          flagReceivedSpeedIdleDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((speedIdleReceiverStateReg == SpeedIdleReceiverState_sendDoneResp) && !flagSentSpeedIdleDoneResp)
          flagSentSpeedIdleDoneResp <= 1'b1;
        else if ((speedIdleSenderStateReg == SpeedIdleSenderState_sendDoneReq) && !flagSentSpeedIdleDoneReq)
          flagSentSpeedIdleDoneReq <= 1'b1;
      end

      unique case (speedIdleSenderStateReg)
        SpeedIdleSenderState_selectLinkSpeed: if (running) speedIdleSenderStateReg <= SpeedIdleSenderState_sendDoneReq;
        SpeedIdleSenderState_sendDoneReq: if (flagSentSpeedIdleDoneReq) speedIdleSenderStateReg <= SpeedIdleSenderState_waitDoneResp;
        SpeedIdleSenderState_waitDoneResp: if (flagReceivedSpeedIdleDoneResp) speedIdleSenderStateReg <= SpeedIdleSenderState_finish;
        SpeedIdleSenderState_finish: speedIdleSenderStateReg <= SpeedIdleSenderState_finish;
        default: speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
      endcase

      unique case (speedIdleReceiverStateReg)
        SpeedIdleReceiverState_waitDoneReq: if (flagReceivedSpeedIdleDoneReq) speedIdleReceiverStateReg <= SpeedIdleReceiverState_sendDoneResp;
        SpeedIdleReceiverState_sendDoneResp: if (flagSentSpeedIdleDoneResp) speedIdleReceiverStateReg <= SpeedIdleReceiverState_finish;
        SpeedIdleReceiverState_finish: speedIdleReceiverStateReg <= SpeedIdleReceiverState_finish;
        default: speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
      endcase

      if (running && (speedIdleSenderStateReg == SpeedIdleSenderState_finish) &&
          (speedIdleReceiverStateReg == SpeedIdleReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire
