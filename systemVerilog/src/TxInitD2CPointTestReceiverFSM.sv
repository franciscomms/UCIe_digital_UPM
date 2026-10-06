// SystemVerilog translation of TxInitD2CPointTestReceiverFSM.scala.
// All state-holding elements use the project-wide active-low asynchronous reset_n.
`default_nettype none

module TxInitD2CPointTestReceiverFSM (
  input wire logic clock,
  input wire logic reset_n,

  input wire logic start,
  output var logic busy,
  output var logic done,
  output var logic [3:0] state,

  input wire logic receivedStartTxInitD2CPointTestReq,
  output var logic sendStartTxInitD2CPointTestResp,
  input wire logic sentStartTxInitD2CPointTestResp,

  input wire logic receivedLfsrClearErrorReq,
  output var logic resetLocalRxScrambler,
  output var logic sendLfsrClearErrorResp,
  input wire logic sentLfsrClearErrorResp,

  input wire logic receivedTxInitD2CResultsReq,
  output var logic sendTxInitD2CResultsResp,
  input wire logic sentTxInitD2CResultsResp,

  input wire logic receivedEndTxInitD2CPointTestReq,
  output var logic sendEndTxInitD2CPointTestResp,
  input wire logic sentEndTxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    TxInitD2CPointTestReceiverState_idle                   = 4'h0,
    TxInitD2CPointTestReceiverState_waitStartReq           = 4'h1,
    TxInitD2CPointTestReceiverState_sendStartResp          = 4'h2,
    TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq  = 4'h3,
    TxInitD2CPointTestReceiverState_resetRxScrambler       = 4'h4,
    TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp = 4'h5,
    TxInitD2CPointTestReceiverState_waitResultsReq         = 4'h6,
    TxInitD2CPointTestReceiverState_sendResultsResp        = 4'h7,
    TxInitD2CPointTestReceiverState_waitEndReq             = 4'h8,
    TxInitD2CPointTestReceiverState_sendEndResp            = 4'h9,
    TxInitD2CPointTestReceiverState_finish                 = 4'hA
  } TxInitD2CPointTestReceiverState_t;

  (* keep = "true" *) TxInitD2CPointTestReceiverState_t stateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;

  // Sticky action registers. They clear only on reset or a new start pulse.
  (* keep = "true" *) logic sendStartTxInitD2CPointTestRespReg;
  (* keep = "true" *) logic resetLocalRxScramblerReg;
  (* keep = "true" *) logic sendLfsrClearErrorRespReg;
  (* keep = "true" *) logic sendTxInitD2CResultsRespReg;
  (* keep = "true" *) logic sendEndTxInitD2CPointTestRespReg;

  (* keep = "true" *) logic previousStart;
  wire startPulse = start && !previousStart;

  always_comb begin
    busy  = runningReg && !doneReg;
    done  = doneReg;
    state = stateReg;

    sendStartTxInitD2CPointTestResp = sendStartTxInitD2CPointTestRespReg;
    resetLocalRxScrambler           = resetLocalRxScramblerReg;
    sendLfsrClearErrorResp          = sendLfsrClearErrorRespReg;
    sendTxInitD2CResultsResp        = sendTxInitD2CResultsRespReg;
    sendEndTxInitD2CPointTestResp   = sendEndTxInitD2CPointTestRespReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg                              <= TxInitD2CPointTestReceiverState_idle;
      runningReg                            <= 1'b0;
      doneReg                               <= 1'b0;
      sendStartTxInitD2CPointTestRespReg    <= 1'b0;
      resetLocalRxScramblerReg              <= 1'b0;
      sendLfsrClearErrorRespReg             <= 1'b0;
      sendTxInitD2CResultsRespReg           <= 1'b0;
      sendEndTxInitD2CPointTestRespReg      <= 1'b0;
      previousStart                         <= 1'b0;
    end else begin
      previousStart <= start;

      // startPulse has priority over the normal receiver sequence and permits a
      // restart from any current state.
      if (startPulse) begin
        runningReg                         <= 1'b1;
        doneReg                            <= 1'b0;
        stateReg                           <= TxInitD2CPointTestReceiverState_waitStartReq;
        sendStartTxInitD2CPointTestRespReg <= 1'b0;
        resetLocalRxScramblerReg           <= 1'b0;
        sendLfsrClearErrorRespReg          <= 1'b0;
        sendTxInitD2CResultsRespReg        <= 1'b0;
        sendEndTxInitD2CPointTestRespReg   <= 1'b0;
      end else if (runningReg) begin
        case (stateReg)
          TxInitD2CPointTestReceiverState_idle: begin
            stateReg <= TxInitD2CPointTestReceiverState_waitStartReq;
          end

          TxInitD2CPointTestReceiverState_waitStartReq: begin
            if (receivedStartTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendStartResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendStartResp: begin
            sendStartTxInitD2CPointTestRespReg <= 1'b1;
            if (sentStartTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitLfsrClearErrorReq: begin
            if (receivedLfsrClearErrorReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_resetRxScrambler;
            end
          end

          TxInitD2CPointTestReceiverState_resetRxScrambler: begin
            resetLocalRxScramblerReg <= 1'b1;
            stateReg <= TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp;
          end

          TxInitD2CPointTestReceiverState_sendLfsrClearErrorResp: begin
            sendLfsrClearErrorRespReg <= 1'b1;
            if (sentLfsrClearErrorResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitResultsReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitResultsReq: begin
            if (receivedTxInitD2CResultsReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendResultsResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendResultsResp: begin
            sendTxInitD2CResultsRespReg <= 1'b1;
            if (sentTxInitD2CResultsResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_waitEndReq;
            end
          end

          TxInitD2CPointTestReceiverState_waitEndReq: begin
            if (receivedEndTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestReceiverState_sendEndResp;
            end
          end

          TxInitD2CPointTestReceiverState_sendEndResp: begin
            sendEndTxInitD2CPointTestRespReg <= 1'b1;
            if (sentEndTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestReceiverState_finish;
            end
          end

          TxInitD2CPointTestReceiverState_finish: begin
            doneReg <= 1'b1;
          end

          default: begin
            // Preserve Chisel switch semantics: no implicit illegal-state repair.
          end
        endcase
      end

      // This is a separate, later Chisel when block. Its assignments therefore
      // override earlier state/running assignments in the same cycle. doneReg is
      // deliberately not cleared here and stays sticky until the next startPulse.
      if (!start && doneReg && !startPulse) begin
        runningReg <= 1'b0;
        stateReg   <= TxInitD2CPointTestReceiverState_idle;
      end
    end
  end
endmodule

`default_nettype wire
