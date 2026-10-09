// SystemVerilog translation of MBTrain_TxSelfCalFSM.scala.
`default_nettype none

module MBTrainTxSelfCalFSM #(
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
    TxSelfCalSenderState_doTxSelfCal     = 2'd0,
    TxSelfCalSenderState_sendDoneReq = 2'd1,
    TxSelfCalSenderState_waitDoneResp = 2'd2,
    TxSelfCalSenderState_finish      = 2'd3
  } TxSelfCalSenderState_t;

  typedef enum logic [1:0] {
    TxSelfCalReceiverState_waitDoneReq = 2'd0,
    TxSelfCalReceiverState_sendDoneResp = 2'd1,
    TxSelfCalReceiverState_finish      = 2'd2
  } TxSelfCalReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  (* keep = "true" *) logic flagReceivedTxSelfCalDoneReq;
  (* keep = "true" *) logic flagReceivedTxSelfCalDoneResp;
  (* keep = "true" *) logic flagSentTxSelfCalDoneReq;
  (* keep = "true" *) logic flagSentTxSelfCalDoneResp;
  (* keep = "true" *) TxSelfCalSenderState_t txSelfCalSenderStateReg;
  (* keep = "true" *) TxSelfCalReceiverState_t txSelfCalReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire [127:0] MBTRAIN_TXSELFCAL_DONE_REQ  = msgMbtrainTxSelfCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_TXSELFCAL_DONE_RESP = msgMbtrainTxSelfCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((txSelfCalReceiverStateReg == TxSelfCalReceiverState_sendDoneResp) && !flagSentTxSelfCalDoneResp) begin
        nextSbTxDin   = MBTRAIN_TXSELFCAL_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((txSelfCalSenderStateReg == TxSelfCalSenderState_sendDoneReq) && !flagSentTxSelfCalDoneReq) begin
        nextSbTxDin   = MBTRAIN_TXSELFCAL_DONE_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;
    dbg_senderState = txSelfCalSenderStateReg;
    dbg_receiverState = txSelfCalReceiverStateReg;
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
      flagReceivedTxSelfCalDoneReq <= 1'b0;
      flagReceivedTxSelfCalDoneResp <= 1'b0;
      flagSentTxSelfCalDoneReq <= 1'b0;
      flagSentTxSelfCalDoneResp <= 1'b0;
      txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
      txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin   <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedTxSelfCalDoneReq <= 1'b0;
        flagReceivedTxSelfCalDoneResp <= 1'b0;
        flagSentTxSelfCalDoneReq <= 1'b0;
        flagSentTxSelfCalDoneResp <= 1'b0;
        txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
        txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_TXSELFCAL_DONE_REQ)
          flagReceivedTxSelfCalDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_TXSELFCAL_DONE_RESP)
          flagReceivedTxSelfCalDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((txSelfCalReceiverStateReg == TxSelfCalReceiverState_sendDoneResp) && !flagSentTxSelfCalDoneResp)
          flagSentTxSelfCalDoneResp <= 1'b1;
        else if ((txSelfCalSenderStateReg == TxSelfCalSenderState_sendDoneReq) && !flagSentTxSelfCalDoneReq)
          flagSentTxSelfCalDoneReq <= 1'b1;
      end

      unique case (txSelfCalSenderStateReg)
        TxSelfCalSenderState_doTxSelfCal: if (running) txSelfCalSenderStateReg <= TxSelfCalSenderState_sendDoneReq;
        TxSelfCalSenderState_sendDoneReq: if (flagSentTxSelfCalDoneReq) txSelfCalSenderStateReg <= TxSelfCalSenderState_waitDoneResp;
        TxSelfCalSenderState_waitDoneResp: if (flagReceivedTxSelfCalDoneResp) txSelfCalSenderStateReg <= TxSelfCalSenderState_finish;
        TxSelfCalSenderState_finish: txSelfCalSenderStateReg <= TxSelfCalSenderState_finish;
        default: txSelfCalSenderStateReg <= TxSelfCalSenderState_doTxSelfCal;
      endcase

      unique case (txSelfCalReceiverStateReg)
        TxSelfCalReceiverState_waitDoneReq: if (flagReceivedTxSelfCalDoneReq) txSelfCalReceiverStateReg <= TxSelfCalReceiverState_sendDoneResp;
        TxSelfCalReceiverState_sendDoneResp: if (flagSentTxSelfCalDoneResp) txSelfCalReceiverStateReg <= TxSelfCalReceiverState_finish;
        TxSelfCalReceiverState_finish: txSelfCalReceiverStateReg <= TxSelfCalReceiverState_finish;
        default: txSelfCalReceiverStateReg <= TxSelfCalReceiverState_waitDoneReq;
      endcase

      if (running && (txSelfCalSenderStateReg == TxSelfCalSenderState_finish) &&
          (txSelfCalReceiverStateReg == TxSelfCalReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire
