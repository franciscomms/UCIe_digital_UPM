// Receiver-side controller for a UCIe receiver-initiated D2C point test.
//
// This FSM is the initiator of the transaction because the local receiver is
// the component being optimized.  It is intentionally separate from
// TxInitD2CPointTestReceiverFSM: in a Tx-initiated test the receiver is the
// responder and returns results over sideband, while in an Rx-initiated test
// the receiver sends Start/End requests and captures the local comparison
// result when the remote transmitter reports Tx Count Done.
`default_nettype none

module RxInitD2CPointTestReceiverFSM #(
    parameter integer RESULT_WIDTH = 1
) (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  output      logic busy,
  output      logic done,
  output      logic [3:0] state,

  output      logic configureReceiver,

  output      logic sendStartRxInitD2CPointTestReq,
  input  wire logic sentStartRxInitD2CPointTestReq,
  input  wire logic receivedStartRxInitD2CPointTestResp,

  input  wire logic receivedLfsrClearErrorReq,
  output      logic clearComparisonErrors,
  output      logic sendLfsrClearErrorResp,
  input  wire logic sentLfsrClearErrorResp,

  input  wire logic receivedRxInitD2CTxCountDoneReq,
  input  wire logic [RESULT_WIDTH-1:0] detectedValidPattern,
  output      logic sendRxInitD2CTxCountDoneResp,
  input  wire logic sentRxInitD2CTxCountDoneResp,

  output      logic sendEndRxInitD2CPointTestReq,
  input  wire logic sentEndRxInitD2CPointTestReq,
  input  wire logic receivedEndRxInitD2CPointTestResp,

  output      logic [RESULT_WIDTH-1:0] pointTestPass
);
  typedef enum logic [3:0] {
    RxInitReceiverState_idle              = 4'h0,
    RxInitReceiverState_configure         = 4'h1,
    RxInitReceiverState_sendStartReq      = 4'h2,
    RxInitReceiverState_waitStartResp     = 4'h3,
    RxInitReceiverState_waitClearReq      = 4'h4,
    RxInitReceiverState_clearErrors       = 4'h5,
    RxInitReceiverState_sendClearResp     = 4'h6,
    RxInitReceiverState_waitCountDoneReq  = 4'h7,
    RxInitReceiverState_sendCountDoneResp = 4'h8,
    RxInitReceiverState_sendEndReq        = 4'h9,
    RxInitReceiverState_waitEndResp       = 4'hA,
    RxInitReceiverState_finish            = 4'hB
  } RxInitReceiverState_t;

  (* keep = "true" *) RxInitReceiverState_t stateReg;
  (* keep = "true" *) logic [RESULT_WIDTH-1:0] pointTestPassReg;
  (* keep = "true" *) logic previousStart;

  wire startPulse = start && !previousStart;

  always_comb begin
    busy = (stateReg != RxInitReceiverState_idle) &&
           (stateReg != RxInitReceiverState_finish);
    done = (stateReg == RxInitReceiverState_finish);
    state = stateReg;

    configureReceiver = (stateReg == RxInitReceiverState_configure);
    sendStartRxInitD2CPointTestReq =
      (stateReg == RxInitReceiverState_sendStartReq);
    clearComparisonErrors = (stateReg == RxInitReceiverState_clearErrors);
    sendLfsrClearErrorResp = (stateReg == RxInitReceiverState_sendClearResp);
    sendRxInitD2CTxCountDoneResp =
      (stateReg == RxInitReceiverState_sendCountDoneResp);
    sendEndRxInitD2CPointTestReq =
      (stateReg == RxInitReceiverState_sendEndReq);
    pointTestPass = pointTestPassReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      stateReg         <= RxInitReceiverState_idle;
      pointTestPassReg <= 1'b0;
      previousStart    <= 1'b0;
    end else begin
      previousStart <= start;

      // A new point-test pulse restarts the controller from either idle or the
      // sticky finish state.  The containing Vref sweep emits one start pulse
      // for each tested Vref code and one for final verification.
      if (startPulse) begin
        stateReg         <= RxInitReceiverState_configure;
        pointTestPassReg <= 1'b0;
      end else begin
        unique case (stateReg)
          RxInitReceiverState_idle: ;

          RxInitReceiverState_configure:
            stateReg <= RxInitReceiverState_sendStartReq;

          RxInitReceiverState_sendStartReq: begin
            if (sentStartRxInitD2CPointTestReq)
              stateReg <= RxInitReceiverState_waitStartResp;
          end

          RxInitReceiverState_waitStartResp: begin
            if (receivedStartRxInitD2CPointTestResp)
              stateReg <= RxInitReceiverState_waitClearReq;
          end

          RxInitReceiverState_waitClearReq: begin
            if (receivedLfsrClearErrorReq)
              stateReg <= RxInitReceiverState_clearErrors;
          end

          RxInitReceiverState_clearErrors:
            stateReg <= RxInitReceiverState_sendClearResp;

          RxInitReceiverState_sendClearResp: begin
            if (sentLfsrClearErrorResp)
              stateReg <= RxInitReceiverState_waitCountDoneReq;
          end

          RxInitReceiverState_waitCountDoneReq: begin
            if (receivedRxInitD2CTxCountDoneReq) begin
              pointTestPassReg <= detectedValidPattern;
              stateReg <= RxInitReceiverState_sendCountDoneResp;
            end
          end

          RxInitReceiverState_sendCountDoneResp: begin
            if (sentRxInitD2CTxCountDoneResp)
              stateReg <= RxInitReceiverState_sendEndReq;
          end

          RxInitReceiverState_sendEndReq: begin
            if (sentEndRxInitD2CPointTestReq)
              stateReg <= RxInitReceiverState_waitEndResp;
          end

          RxInitReceiverState_waitEndResp: begin
            if (receivedEndRxInitD2CPointTestResp)
              stateReg <= RxInitReceiverState_finish;
          end

          RxInitReceiverState_finish: ;

          default: stateReg <= RxInitReceiverState_idle;
        endcase
      end
    end
  end
endmodule

`default_nettype wire
