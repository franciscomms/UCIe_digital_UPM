// SystemVerilog translation of MBTrain_RxClkCalFSM.scala.
`default_nettype none

module MBTrainRxClkCalFSM #(
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
  output var logic         flagToAnalog_rxClkCalDoCalibration,
  input wire logic         flagFromAnalog_rxClkCalDone,
  output var logic         flagToAnalog_rxClkCalSendClockTrack,
  output var logic [2:0]   dbg_senderState,
  output var logic [2:0]   dbg_receiverState
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [2:0] {
    RxClkCalSenderState_sendStartReq      = 3'd0,
    RxClkCalSenderState_waitStartResp     = 3'd1,
    RxClkCalSenderState_startAnalogCal    = 3'd2,
    RxClkCalSenderState_waitAnalogCalDone = 3'd3,
    RxClkCalSenderState_sendDoneReq       = 3'd4,
    RxClkCalSenderState_waitDoneResp      = 3'd5,
    RxClkCalSenderState_finish            = 3'd6
  } RxClkCalSenderState_t;

  typedef enum logic [2:0] {
    RxClkCalReceiverState_waitStartReq    = 3'd0,
    RxClkCalReceiverState_startClockTrack = 3'd1,
    RxClkCalReceiverState_sendStartResp   = 3'd2,
    RxClkCalReceiverState_waitDoneReq     = 3'd3,
    RxClkCalReceiverState_sendDoneResp    = 3'd4,
    RxClkCalReceiverState_finish          = 3'd5
  } RxClkCalReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedRxClkCalStartReq;
  (* keep = "true" *) logic flagReceivedRxClkCalStartResp;
  (* keep = "true" *) logic flagReceivedRxClkCalDoneReq;
  (* keep = "true" *) logic flagReceivedRxClkCalDoneResp;
  (* keep = "true" *) logic flagSentRxClkCalStartReq;
  (* keep = "true" *) logic flagSentRxClkCalStartResp;
  (* keep = "true" *) logic flagSentRxClkCalDoneReq;
  (* keep = "true" *) logic flagSentRxClkCalDoneResp;

  (* keep = "true" *) RxClkCalSenderState_t rxClkCalSenderStateReg;
  (* keep = "true" *) RxClkCalReceiverState_t rxClkCalReceiverStateReg;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_RXCLKCAL_START_REQ  = msgMbtrainRxClkCalStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_START_RESP = msgMbtrainRxClkCalStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_DONE_REQ   = msgMbtrainRxClkCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_RXCLKCAL_DONE_RESP  = msgMbtrainRxClkCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    nextSbTxValid = 1'b0;
    nextSbTxDin   = 128'b0;

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp) && !flagSentRxClkCalDoneResp) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_DONE_RESP;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendDoneReq) && !flagSentRxClkCalDoneReq) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_DONE_REQ;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) && !flagSentRxClkCalStartResp) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_START_RESP;
        nextSbTxValid = 1'b1;
      end else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendStartReq) && !flagSentRxClkCalStartReq) begin
        nextSbTxDin   = MBTRAIN_RXCLKCAL_START_REQ;
        nextSbTxValid = 1'b1;
      end
    end

    sb_tx_valid = sbTxValid;
    sb_tx_din   = sbTxDin;
    busy        = running && !doneReg;
    done        = doneReg;
    trainError  = trainErrorReg;

    // Chisel assigned a 10-bit Cat into an 8-bit output. Preserve the low 8 bits.
    dbg_senderState = rxClkCalSenderStateReg;
    dbg_receiverState = rxClkCalReceiverStateReg;

    flagToAnalog_rxClkCalDoCalibration = running &&
      ((rxClkCalSenderStateReg == RxClkCalSenderState_startAnalogCal) ||
       (rxClkCalSenderStateReg == RxClkCalSenderState_waitAnalogCalDone));

    flagToAnalog_rxClkCalSendClockTrack = running &&
      ((rxClkCalReceiverStateReg == RxClkCalReceiverState_startClockTrack) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_waitDoneReq) ||
       (rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp));
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedRxClkCalStartReq <= 1'b0;
      flagReceivedRxClkCalStartResp <= 1'b0;
      flagReceivedRxClkCalDoneReq <= 1'b0;
      flagReceivedRxClkCalDoneResp <= 1'b0;
      flagSentRxClkCalStartReq <= 1'b0;
      flagSentRxClkCalStartResp <= 1'b0;
      flagSentRxClkCalDoneReq <= 1'b0;
      flagSentRxClkCalDoneResp <= 1'b0;
      rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
      rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
    end else begin
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;
      prevStart <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        flagReceivedRxClkCalStartReq <= 1'b0;
        flagReceivedRxClkCalStartResp <= 1'b0;
        flagReceivedRxClkCalDoneReq <= 1'b0;
        flagReceivedRxClkCalDoneResp <= 1'b0;
        flagSentRxClkCalStartReq <= 1'b0;
        flagSentRxClkCalStartResp <= 1'b0;
        flagSentRxClkCalDoneReq <= 1'b0;
        flagSentRxClkCalDoneResp <= 1'b0;
        rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
        rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_START_REQ)
          flagReceivedRxClkCalStartReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_START_RESP)
          flagReceivedRxClkCalStartResp <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_DONE_REQ)
          flagReceivedRxClkCalDoneReq <= 1'b1;
        if (sb_rx_dout == MBTRAIN_RXCLKCAL_DONE_RESP)
          flagReceivedRxClkCalDoneResp <= 1'b1;
      end

      if (running && sb_tx_ready && !sbTxValid) begin
        if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendDoneResp) && !flagSentRxClkCalDoneResp)
          flagSentRxClkCalDoneResp <= 1'b1;
        else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendDoneReq) && !flagSentRxClkCalDoneReq)
          flagSentRxClkCalDoneReq <= 1'b1;
        else if ((rxClkCalReceiverStateReg == RxClkCalReceiverState_sendStartResp) && !flagSentRxClkCalStartResp)
          flagSentRxClkCalStartResp <= 1'b1;
        else if ((rxClkCalSenderStateReg == RxClkCalSenderState_sendStartReq) && !flagSentRxClkCalStartReq)
          flagSentRxClkCalStartReq <= 1'b1;
      end

      unique case (rxClkCalSenderStateReg)
        RxClkCalSenderState_sendStartReq:
          if (flagSentRxClkCalStartReq) rxClkCalSenderStateReg <= RxClkCalSenderState_waitStartResp;
        RxClkCalSenderState_waitStartResp:
          if (flagReceivedRxClkCalStartResp) rxClkCalSenderStateReg <= RxClkCalSenderState_startAnalogCal;
        RxClkCalSenderState_startAnalogCal:
          rxClkCalSenderStateReg <= RxClkCalSenderState_waitAnalogCalDone;
        RxClkCalSenderState_waitAnalogCalDone:
          if (flagFromAnalog_rxClkCalDone) rxClkCalSenderStateReg <= RxClkCalSenderState_sendDoneReq;
        RxClkCalSenderState_sendDoneReq:
          if (flagSentRxClkCalDoneReq) rxClkCalSenderStateReg <= RxClkCalSenderState_waitDoneResp;
        RxClkCalSenderState_waitDoneResp:
          if (flagReceivedRxClkCalDoneResp) rxClkCalSenderStateReg <= RxClkCalSenderState_finish;
        RxClkCalSenderState_finish:
          rxClkCalSenderStateReg <= RxClkCalSenderState_finish;
        default: rxClkCalSenderStateReg <= RxClkCalSenderState_sendStartReq;
      endcase

      unique case (rxClkCalReceiverStateReg)
        RxClkCalReceiverState_waitStartReq:
          if (flagReceivedRxClkCalStartReq) rxClkCalReceiverStateReg <= RxClkCalReceiverState_startClockTrack;
        RxClkCalReceiverState_startClockTrack:
          rxClkCalReceiverStateReg <= RxClkCalReceiverState_sendStartResp;
        RxClkCalReceiverState_sendStartResp:
          if (flagSentRxClkCalStartResp) rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitDoneReq;
        RxClkCalReceiverState_waitDoneReq:
          if (flagReceivedRxClkCalDoneReq) rxClkCalReceiverStateReg <= RxClkCalReceiverState_sendDoneResp;
        RxClkCalReceiverState_sendDoneResp:
          if (flagSentRxClkCalDoneResp) rxClkCalReceiverStateReg <= RxClkCalReceiverState_finish;
        RxClkCalReceiverState_finish:
          rxClkCalReceiverStateReg <= RxClkCalReceiverState_finish;
        default: rxClkCalReceiverStateReg <= RxClkCalReceiverState_waitStartReq;
      endcase

      if (running &&
          (rxClkCalSenderStateReg == RxClkCalSenderState_finish) &&
          (rxClkCalReceiverStateReg == RxClkCalReceiverState_finish)) begin
        doneReg <= 1'b1;
        running <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire
