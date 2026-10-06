// SystemVerilog translation of TxInitD2CPointTestSenderFSM.scala.
// All state-holding elements use the project-wide active-low asynchronous reset_n.
`default_nettype none

module TxInitD2CPointTestSenderFSM (
  input wire logic clock,
  input wire logic reset_n,

  input wire logic start,
  output var logic busy,
  output var logic done,
  output var logic [3:0] state,

  output var logic sendStartTxInitD2CPointTestReq,
  input wire logic sentStartTxInitD2CPointTestReq,
  input wire logic receivedStartTxInitD2CPointTestResp,

  output var logic resetLocalScrambler,

  output var logic sendLfsrClearErrorReq,
  input wire logic sentLfsrClearErrorReq,
  input wire logic receivedLfsrClearErrorResp,

  output var logic sendDefinedPattern,
  input wire logic sentDefinedPattern,

  output var logic sendTxInitD2CResultsReq,
  input wire logic sentTxInitD2CResultsReq,
  input wire logic receivedTxInitD2CResultsResp,

  output var logic sendEndTxInitD2CPointTestReq,
  input wire logic sentEndTxInitD2CPointTestReq,
  input wire logic receivedEndTxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    TxInitD2CPointTestSenderState_idle                   = 4'h0,
    TxInitD2CPointTestSenderState_sendStartReq           = 4'h1,
    TxInitD2CPointTestSenderState_waitStartResp          = 4'h2,
    TxInitD2CPointTestSenderState_resetScrambler         = 4'h3,
    TxInitD2CPointTestSenderState_sendLfsrClearErrorReq  = 4'h4,
    TxInitD2CPointTestSenderState_waitLfsrClearErrorResp = 4'h5,
    TxInitD2CPointTestSenderState_requestPatternSend     = 4'h6,
    TxInitD2CPointTestSenderState_waitPatternSent        = 4'h7,
    TxInitD2CPointTestSenderState_sendResultsReq         = 4'h8,
    TxInitD2CPointTestSenderState_waitResultsResp        = 4'h9,
    TxInitD2CPointTestSenderState_sendEndReq             = 4'hA,
    TxInitD2CPointTestSenderState_waitEndResp            = 4'hB,
    TxInitD2CPointTestSenderState_finish                 = 4'hC
  } TxInitD2CPointTestSenderState_t;

  (* keep = "true" *) TxInitD2CPointTestSenderState_t stateReg;
  (* keep = "true" *) logic prevStart;

  // Sticky action registers. They clear only on reset or a new start rising edge.
  (* keep = "true" *) logic sendStartReqReg;
  (* keep = "true" *) logic resetScramblerReg;
  (* keep = "true" *) logic sendLfsrReqReg;
  (* keep = "true" *) logic sendPatternReg;
  (* keep = "true" *) logic sendResultsReqReg;
  (* keep = "true" *) logic sendEndReqReg;

  wire startPulse = start && !prevStart;

  always_comb begin
    state = stateReg;

    busy = (stateReg != TxInitD2CPointTestSenderState_idle) &&
           (stateReg != TxInitD2CPointTestSenderState_finish);
    done = (stateReg == TxInitD2CPointTestSenderState_finish);

    sendStartTxInitD2CPointTestReq = sendStartReqReg;
    resetLocalScrambler            = resetScramblerReg;
    sendLfsrClearErrorReq          = sendLfsrReqReg;
    sendDefinedPattern             = sendPatternReg;
    sendTxInitD2CResultsReq        = sendResultsReqReg;
    sendEndTxInitD2CPointTestReq   = sendEndReqReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg          <= TxInitD2CPointTestSenderState_idle;
      prevStart         <= 1'b0;
      sendStartReqReg   <= 1'b0;
      resetScramblerReg <= 1'b0;
      sendLfsrReqReg    <= 1'b0;
      sendPatternReg    <= 1'b0;
      sendResultsReqReg <= 1'b0;
      sendEndReqReg     <= 1'b0;
    end else begin
      prevStart <= start;

      // A rising edge of start restarts the sequence from any state and clears
      // every sticky action register, matching the Chisel priority.
      if (startPulse) begin
        stateReg          <= TxInitD2CPointTestSenderState_sendStartReq;
        sendStartReqReg   <= 1'b0;
        resetScramblerReg <= 1'b0;
        sendLfsrReqReg    <= 1'b0;
        sendPatternReg    <= 1'b0;
        sendResultsReqReg <= 1'b0;
        sendEndReqReg     <= 1'b0;
      end else begin
        case (stateReg)
          TxInitD2CPointTestSenderState_idle: begin
            stateReg <= TxInitD2CPointTestSenderState_idle;
          end

          TxInitD2CPointTestSenderState_sendStartReq: begin
            sendStartReqReg <= 1'b1;
            if (sentStartTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitStartResp;
            end
          end

          TxInitD2CPointTestSenderState_waitStartResp: begin
            if (receivedStartTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestSenderState_resetScrambler;
            end
          end

          TxInitD2CPointTestSenderState_resetScrambler: begin
            resetScramblerReg <= 1'b1;
            stateReg <= TxInitD2CPointTestSenderState_sendLfsrClearErrorReq;
          end

          TxInitD2CPointTestSenderState_sendLfsrClearErrorReq: begin
            sendLfsrReqReg <= 1'b1;
            if (sentLfsrClearErrorReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitLfsrClearErrorResp;
            end
          end

          TxInitD2CPointTestSenderState_waitLfsrClearErrorResp: begin
            if (receivedLfsrClearErrorResp) begin
              stateReg <= TxInitD2CPointTestSenderState_requestPatternSend;
            end
          end

          TxInitD2CPointTestSenderState_requestPatternSend: begin
            sendPatternReg <= 1'b1;
            stateReg <= TxInitD2CPointTestSenderState_waitPatternSent;
          end

          TxInitD2CPointTestSenderState_waitPatternSent: begin
            if (sentDefinedPattern) begin
              stateReg <= TxInitD2CPointTestSenderState_sendResultsReq;
            end
          end

          TxInitD2CPointTestSenderState_sendResultsReq: begin
            sendResultsReqReg <= 1'b1;
            if (sentTxInitD2CResultsReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitResultsResp;
            end
          end

          TxInitD2CPointTestSenderState_waitResultsResp: begin
            if (receivedTxInitD2CResultsResp) begin
              stateReg <= TxInitD2CPointTestSenderState_sendEndReq;
            end
          end

          TxInitD2CPointTestSenderState_sendEndReq: begin
            sendEndReqReg <= 1'b1;
            if (sentEndTxInitD2CPointTestReq) begin
              stateReg <= TxInitD2CPointTestSenderState_waitEndResp;
            end
          end

          TxInitD2CPointTestSenderState_waitEndResp: begin
            if (receivedEndTxInitD2CPointTestResp) begin
              stateReg <= TxInitD2CPointTestSenderState_finish;
            end
          end

          TxInitD2CPointTestSenderState_finish: begin
            stateReg <= TxInitD2CPointTestSenderState_finish;
          end

          default: begin
            // Chisel's switch has no default assignment; retain all registers
            // if an illegal state is observed rather than inventing recovery.
          end
        endcase
      end
    end
  end
endmodule

`default_nettype wire
