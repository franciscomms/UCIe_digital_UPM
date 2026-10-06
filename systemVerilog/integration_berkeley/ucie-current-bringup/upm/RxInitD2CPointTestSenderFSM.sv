// Transmitter-side responder for a UCIe receiver-initiated D2C point test.
//
// This FSM begins after a Start Rx Init D2C Point Test request has been
// received.  It acknowledges Start, performs the clear-error handshake,
// transmits the requested pattern, reports Tx Count Done, and responds to the
// receiver's End request.  It is not interchangeable with
// TxInitD2CPointTestSenderFSM, where the local transmitter initiates the test.
`default_nettype none

module RxInitD2CPointTestSenderFSM (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  output      logic busy,
  output      logic done,
  output      logic [3:0] state,

  output      logic sendStartRxInitD2CPointTestResp,
  input  wire logic sentStartRxInitD2CPointTestResp,

  output      logic resetLocalScrambler,
  output      logic sendLfsrClearErrorReq,
  input  wire logic sentLfsrClearErrorReq,
  input  wire logic receivedLfsrClearErrorResp,

  output      logic sendDefinedPattern,
  input  wire logic sentDefinedPattern,

  output      logic sendRxInitD2CTxCountDoneReq,
  input  wire logic sentRxInitD2CTxCountDoneReq,
  input  wire logic receivedRxInitD2CTxCountDoneResp,

  input  wire logic receivedEndRxInitD2CPointTestReq,
  output      logic sendEndRxInitD2CPointTestResp,
  input  wire logic sentEndRxInitD2CPointTestResp
);
  typedef enum logic [3:0] {
    RxInitSenderState_idle              = 4'h0,
    RxInitSenderState_sendStartResp     = 4'h1,
    RxInitSenderState_sendClearReq      = 4'h2,
    RxInitSenderState_waitClearResp     = 4'h3,
    RxInitSenderState_resetScrambler    = 4'h4,
    RxInitSenderState_sendPattern       = 4'h5,
    RxInitSenderState_sendCountDoneReq  = 4'h6,
    RxInitSenderState_waitCountDoneResp = 4'h7,
    RxInitSenderState_waitEndReq        = 4'h8,
    RxInitSenderState_sendEndResp       = 4'h9,
    RxInitSenderState_finish            = 4'hA
  } RxInitSenderState_t;

  (* keep = "true" *) RxInitSenderState_t stateReg;
  (* keep = "true" *) logic previousStart;

  wire startPulse = start && !previousStart;

  always_comb begin
    busy = (stateReg != RxInitSenderState_idle) &&
           (stateReg != RxInitSenderState_finish);
    done = (stateReg == RxInitSenderState_finish);
    state = stateReg;

    sendStartRxInitD2CPointTestResp =
      (stateReg == RxInitSenderState_sendStartResp);
    sendLfsrClearErrorReq = (stateReg == RxInitSenderState_sendClearReq);
    resetLocalScrambler = (stateReg == RxInitSenderState_resetScrambler);
    sendDefinedPattern = (stateReg == RxInitSenderState_sendPattern);
    sendRxInitD2CTxCountDoneReq =
      (stateReg == RxInitSenderState_sendCountDoneReq);
    sendEndRxInitD2CPointTestResp =
      (stateReg == RxInitSenderState_sendEndResp);
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg      <= RxInitSenderState_idle;
      previousStart <= 1'b0;
    end else begin
      previousStart <= start;

      if (startPulse) begin
        stateReg <= RxInitSenderState_sendStartResp;
      end else begin
        unique case (stateReg)
          RxInitSenderState_idle: ;

          RxInitSenderState_sendStartResp: begin
            if (sentStartRxInitD2CPointTestResp)
              stateReg <= RxInitSenderState_sendClearReq;
          end

          RxInitSenderState_sendClearReq: begin
            if (sentLfsrClearErrorReq)
              stateReg <= RxInitSenderState_waitClearResp;
          end

          RxInitSenderState_waitClearResp: begin
            if (receivedLfsrClearErrorResp)
              stateReg <= RxInitSenderState_resetScrambler;
          end

          RxInitSenderState_resetScrambler:
            stateReg <= RxInitSenderState_sendPattern;

          RxInitSenderState_sendPattern: begin
            if (sentDefinedPattern)
              stateReg <= RxInitSenderState_sendCountDoneReq;
          end

          RxInitSenderState_sendCountDoneReq: begin
            if (sentRxInitD2CTxCountDoneReq)
              stateReg <= RxInitSenderState_waitCountDoneResp;
          end

          RxInitSenderState_waitCountDoneResp: begin
            if (receivedRxInitD2CTxCountDoneResp)
              stateReg <= RxInitSenderState_waitEndReq;
          end

          RxInitSenderState_waitEndReq: begin
            if (receivedEndRxInitD2CPointTestReq)
              stateReg <= RxInitSenderState_sendEndResp;
          end

          RxInitSenderState_sendEndResp: begin
            if (sentEndRxInitD2CPointTestResp)
              stateReg <= RxInitSenderState_finish;
          end

          RxInitSenderState_finish: ;

          default: stateReg <= RxInitSenderState_idle;
        endcase
      end
    end
  end
endmodule

`default_nettype wire
