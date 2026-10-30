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
  input wire logic         speedApplied,
  input wire logic         speedDegradeAtFloor,
  input wire logic [31:0]  cycles_1us,
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

  // The two FSMs use the same four-phase exchange for SPEEDIDLE completion
  // and, at the minimum rate, TRAINERROR entry. The latter is a distinct wire
  // protocol: E5/00 request, EA/00 response (UCIe 2.0 Table 7-9).
  logic sbTxValid;
  logic [127:0] sbTxDin;
  logic running, doneReg, trainErrorReg;
  logic prevStart, prevRxValid;
  logic errorModeReg, localErrorRequestReg, appliedReg;
  logic receivedReq, receivedResp, sentReq, sentResp;
  SpeedIdleSenderState_t speedIdleSenderStateReg;
  SpeedIdleReceiverState_t speedIdleReceiverStateReg;
  logic [31:0] cyclesPerUsMinusOneReg, cycleCounter;
  logic [12:0] microsecondCounter;
  logic errorTimeoutReached;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire txFire = sbTxValid && sb_tx_ready;
  wire [127:0] SPEED_DONE_REQ = msgMbtrainSpeedIdleDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] SPEED_DONE_RESP = msgMbtrainSpeedIdleDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] ERROR_ENTRY_REQ = msgWithoutPayloadBase(
    16'h0000, UCIe2_LtsmMsgCode_TRAINERROR_REQ, 8'h00, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] ERROR_ENTRY_RESP = msgWithoutPayloadBase(
    16'h0000, UCIe2_LtsmMsgCode_TRAINERROR_RSP, 8'h00, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] selectedReq = errorModeReg ? ERROR_ENTRY_REQ : SPEED_DONE_REQ;
  wire [127:0] selectedResp = errorModeReg ? ERROR_ENTRY_RESP : SPEED_DONE_RESP;
  wire maySend = errorModeReg || appliedReg;
  wire normalExchangeComplete = sentReq && receivedResp && receivedReq && sentResp &&
                                !sbTxValid && !sb_rx_valid;
  wire normalResidencyExpired = !errorModeReg &&
    (cycleCounter == cyclesPerUsMinusOneReg) && (microsecondCounter == 13'd7999);
  wire peerErrorRequest = rxValidRisingEdge && sb_rx_dout == ERROR_ENTRY_REQ;

  assign sb_tx_valid = sbTxValid;
  assign sb_tx_din = sbTxDin;
  assign busy = running;
  assign done = doneReg;
  assign trainError = trainErrorReg;
  assign dbg_senderState = speedIdleSenderStateReg;
  assign dbg_receiverState = speedIdleReceiverStateReg;

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin <= '0;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      errorModeReg <= 1'b0;
      localErrorRequestReg <= 1'b0;
      appliedReg <= 1'b0;
      receivedReq <= 1'b0;
      receivedResp <= 1'b0;
      sentReq <= 1'b0;
      sentResp <= 1'b0;
      speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
      speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
      cyclesPerUsMinusOneReg <= 32'd0;
      cycleCounter <= '0;
      microsecondCounter <= '0;
      errorTimeoutReached <= 1'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      if (startPulse) begin
        sbTxValid <= 1'b0;
        sbTxDin <= '0;
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        errorModeReg <= speedDegradeAtFloor;
        localErrorRequestReg <= speedDegradeAtFloor;
        appliedReg <= 1'b0;
        receivedReq <= 1'b0;
        receivedResp <= 1'b0;
        sentReq <= 1'b0;
        sentResp <= 1'b0;
        speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
        speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
        // Zero is clamped to one clock/us to keep a test configuration finite.
        // Store the terminal count once, keeping subtraction out of the timer
        // comparison path during training.
        cyclesPerUsMinusOneReg <= (cycles_1us == 0) ? 32'd0 : cycles_1us - 32'd1;
        cycleCounter <= '0;
        microsecondCounter <= '0;
        errorTimeoutReached <= 1'b0;
      end else if (running) begin
        if (speedApplied && !errorModeReg) appliedReg <= 1'b1;

        // Keep a pending packet unchanged until the receiver accepts it.
        if (txFire) begin
          sbTxValid <= 1'b0;
          sbTxDin <= '0;
          if (sbTxDin == selectedReq) sentReq <= 1'b1;
          if (sbTxDin == selectedResp) sentResp <= 1'b1;
        end else if (!sbTxValid && maySend && !normalResidencyExpired) begin
          if (receivedReq && !sentResp) begin
            sbTxValid <= 1'b1;
            sbTxDin <= selectedResp;
          end else if (speedIdleSenderStateReg == SpeedIdleSenderState_sendDoneReq && !sentReq &&
                       (!errorModeReg || localErrorRequestReg)) begin
            sbTxValid <= 1'b1;
            sbTxDin <= selectedReq;
          end
        end

        if (rxValidRisingEdge) begin
          if (sb_rx_dout == selectedReq) receivedReq <= 1'b1;
          if (sb_rx_dout == selectedResp && sentReq) receivedResp <= 1'b1;
        end

        case (speedIdleSenderStateReg)
          SpeedIdleSenderState_selectLinkSpeed:
            if (maySend) speedIdleSenderStateReg <= SpeedIdleSenderState_sendDoneReq;
          SpeedIdleSenderState_sendDoneReq:
            if (sentReq) speedIdleSenderStateReg <= SpeedIdleSenderState_waitDoneResp;
          SpeedIdleSenderState_waitDoneResp:
            if (receivedResp) speedIdleSenderStateReg <= SpeedIdleSenderState_finish;
          default: ;
        endcase
        case (speedIdleReceiverStateReg)
          SpeedIdleReceiverState_waitDoneReq:
            if (receivedReq && maySend) speedIdleReceiverStateReg <= SpeedIdleReceiverState_sendDoneResp;
          SpeedIdleReceiverState_sendDoneResp:
            if (sentResp) speedIdleReceiverStateReg <= SpeedIdleReceiverState_finish;
          default: ;
        endcase

        // UCIe 2.0 4.5 bounds normal SPEEDIDLE residency to 8 ms, including
        // the PLL/applied wait and its done exchange. On expiry, enter the
        // TRAINERROR handshake and restart the counter. Section 4.5.3.8 then
        // permits entry after 8 ms without a response to our accepted request.
        // Nested counters avoid a timing-critical cycles_1us * 8000 multiply.
        if ((!errorModeReg && !normalExchangeComplete) ||
            (errorModeReg && sentReq && !receivedResp && !errorTimeoutReached)) begin
          if (cycleCounter == cyclesPerUsMinusOneReg) begin
            cycleCounter <= '0;
            if (microsecondCounter == 13'd7999) begin
              if (errorModeReg) errorTimeoutReached <= 1'b1;
            end
            else microsecondCounter <= microsecondCounter + 1'b1;
          end else cycleCounter <= cycleCounter + 1'b1;
        end

        // Complete accepted writes and any peer request before reporting an
        // exit. The parent capture queue must also drain before a global reset.
        if (!sbTxValid && !sb_rx_valid &&
            (errorModeReg ?
              ((localErrorRequestReg ? (sentReq && (receivedResp || errorTimeoutReached)) :
                                      (receivedReq && sentResp)) && (!receivedReq || sentResp)) :
              (sentReq && receivedResp && receivedReq && sentResp))) begin
          running <= 1'b0;
          if (errorModeReg) trainErrorReg <= 1'b1;
          else doneReg <= 1'b1;
        end

        // Either an explicit partner error or our residency watchdog aborts
        // normal SPEEDIDLE. Preserve outstanding packets and drain them before
        // the error exchange. A simultaneous peer request needs only a reply.
        if (!errorModeReg && (peerErrorRequest ||
                              (normalResidencyExpired && !normalExchangeComplete))) begin
          errorModeReg <= 1'b1;
          localErrorRequestReg <= !peerErrorRequest;
          receivedReq <= peerErrorRequest;
          receivedResp <= 1'b0;
          sentReq <= 1'b0;
          sentResp <= 1'b0;
          doneReg <= 1'b0;
          running <= 1'b1;
          speedIdleSenderStateReg <= SpeedIdleSenderState_selectLinkSpeed;
          speedIdleReceiverStateReg <= SpeedIdleReceiverState_waitDoneReq;
          cycleCounter <= '0;
          microsecondCounter <= '0;
          errorTimeoutReached <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire
