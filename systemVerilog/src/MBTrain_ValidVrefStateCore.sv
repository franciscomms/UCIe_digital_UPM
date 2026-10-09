// Shared implementation for UCIe MBTRAIN.VALVREF and MBTRAIN.VALTRAINVREF.
//
// Each die has two concurrent roles:
//   1. Receiver initiator: sweep the local Valid receiver Vref and initiate one
//      Rx Init D2C point test for every code.
//   2. Transmitter responder: serve the opposite die's Rx Init D2C point tests
//      by transmitting the fixed, unscrambled 1024-UI VALTRAIN sequence.
//
// IS_VALTRAIN_VREF selects only the outer MBTRAIN Start/End(Done) messages.  The
// receiver-initiated point-test protocol and Vref search are otherwise shared.
//
// SidebandMsgGenerator_pkg supplies the packet encodings.  The generic
// RxInitD2CPointTestReceiverFSM and RxInitD2CPointTestSenderFSM modules supply
// the sequencing.  The project-owned TxInitD2CPointTest* modules remain in the
// build for transmitter-initiated states but cannot replace these Rx-init roles.
`default_nettype none

module MBTrain_ValidVrefStateCore #(
  parameter bit IS_VALTRAIN_VREF = 1'b0,
  parameter bit PERFORM_LOCAL_TRAINING = 1'b1,
  parameter int unsigned VREF_VALUE_COUNT = 16,
  parameter int unsigned VREF_CODE_WIDTH =
    (VREF_VALUE_COUNT <= 1) ? 1 : $clog2(VREF_VALUE_COUNT),
  parameter logic [15:0] MAXIMUM_COMPARISON_ERROR_THRESHOLD = 16'd0,
  parameter int unsigned MIN_PASSING_WINDOW_VALUES = 1,
  parameter int unsigned MAX_TRAINING_RETRIES = 1
) (
  input  wire logic                         clock,
  input  wire logic                         reset_n,
  input  wire logic                         start,
  output      logic                         busy,
  output      logic                         done,
  output      logic                         trainError,

  input  wire logic                         sb_tx_ready,
  output      logic                         sb_tx_valid,
  output      logic [127:0]                 sb_tx_din,
  input  wire logic                         sb_rx_valid,
  input  wire logic [127:0]                 sb_rx_dout,

  // Local receiver controls: this is the Vref being optimized.
  output      logic                         flagToAnalog_applyRxVref,
  output      logic [VREF_CODE_WIDTH-1:0]   flagToAnalog_rxVrefCode,
  input  wire logic                         flagFromAnalog_rxVrefApplied,
  output      logic                         flagToAnalog_configureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_maximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_comparisonMode,
  output      logic [15:0]                  flagToAnalog_iterationCountSettings,
  output      logic [15:0]                  flagToAnalog_idleCountSettings,
  output      logic [15:0]                  flagToAnalog_burstCountSettings,
  output      logic                         flagToAnalog_patternMode,
  output      logic [3:0]                   flagToAnalog_clockPhaseControl,
  output      logic [2:0]                   flagToAnalog_validPattern,
  output      logic [2:0]                   flagToAnalog_dataPattern,
  output      logic                         flagToAnalog_clearComparisonErrors,
  input  wire logic                         flagFromAnalog_detectedValPattern,

  // Local transmitter controls used while serving the opposite receiver.
  output      logic                         flagToAnalog_sendValTrainPattern,
  input  wire logic                         flagFromAnalog_valTrainPatternSent,
  output      logic                         flagToAnalog_resetLocalTxScrambler,

  output      logic [3:0]                   dbg_localState,
  output      logic [2:0]                   dbg_remoteState,
  output      logic [3:0]                   dbg_sweepState,
  output      logic [3:0]                   dbg_pointInitiatorState,
  output      logic [3:0]                   dbg_pointResponderState,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [VREF_CODE_WIDTH-1:0]   selectedVrefCode,
  output      logic [VREF_CODE_WIDTH-1:0]   validWindowLeftCode,
  output      logic [VREF_CODE_WIDTH-1:0]   validWindowRightCode
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LocalState_idle          = 4'h0,
    LocalState_sendStartReq  = 4'h1,
    LocalState_waitStartResp = 4'h2,
    LocalState_startSweep    = 4'h3,
    LocalState_waitSweep     = 4'h4,
    LocalState_sendEndReq    = 4'h5,
    LocalState_waitEndResp   = 4'h6,
    LocalState_finish        = 4'h7,
    LocalState_error         = 4'h8
  } LocalState_t;

  typedef enum logic [2:0] {
    RemoteState_idle          = 3'h0,
    RemoteState_waitStartReq  = 3'h1,
    RemoteState_sendStartResp = 3'h2,
    RemoteState_active        = 3'h3,
    RemoteState_sendEndResp   = 3'h4,
    RemoteState_finish        = 3'h5
  } RemoteState_t;

  typedef enum logic [4:0] {
    TxSource_none                    = 5'd0,
    TxSource_remoteOuterEndResp      = 5'd1,
    TxSource_pointResponderEndResp   = 5'd2,
    TxSource_pointInitiatorCountResp = 5'd3,
    TxSource_pointResponderCountReq  = 5'd4,
    TxSource_pointInitiatorClearResp = 5'd5,
    TxSource_pointResponderClearReq  = 5'd6,
    TxSource_pointResponderStartResp = 5'd7,
    TxSource_remoteOuterStartResp    = 5'd8,
    TxSource_pointInitiatorEndReq    = 5'd9,
    TxSource_pointInitiatorStartReq  = 5'd10,
    TxSource_localOuterEndReq        = 5'd11,
    TxSource_localOuterStartReq      = 5'd12
  } TxSource_t;

  (* keep = "true" *) LocalState_t localStateReg;
  (* keep = "true" *) RemoteState_t remoteStateReg;
  (* keep = "true" *) logic runningReg;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  // Latch the peer's outer End/Done request when it arrives while the local
  // transmitter responder is still completing its final point test.  Without
  // this latch, an asymmetric optional VALTRAINVREF configuration can lose the
  // one-cycle sideband request and deadlock.
  (* keep = "true" *) logic remoteOuterEndPendingReg;

  (* keep = "true" *) logic sbTxValidReg;
  (* keep = "true" *) logic [127:0] sbTxDinReg;
  (* keep = "true" *) TxSource_t sbTxSourceReg;
  logic txLoadValid;
  logic [127:0] txLoadDin;
  TxSource_t txLoadSource;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;
  wire txTransfer = sbTxValidReg && sb_tx_ready;

  wire [127:0] OUTER_START_REQ = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_START_RESP = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_REQ = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_RESP = IS_VALTRAIN_VREF ?
    msgMbtrainValTrainVrefDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY) :
    msgMbtrainValVrefEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // Continuous functional VALTRAIN: 128 repetitions of 11110000 = 1024 UI.
  // The ValidPattern encoding 0 selects the functional Valid pattern; Data and
  // Track remain low in the PHY while this state is active.
  wire [127:0] RXINIT_START_REQ =
    msgMbtrainValVrefStartRxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      MAXIMUM_COMPARISON_ERROR_THRESHOLD,
      1'b0,       // per-lane comparison
      16'd1,      // continuous-mode convention
      16'd0,      // no idle UI
      16'd1024,   // 1024 UI VALTRAIN burst
      1'b0,       // continuous pattern mode
      4'd0,       // forwarded-clock phase is not changed here
      3'd0,       // functional Valid pattern
      3'd0        // no Data pattern
    );
  wire [127:0] RXINIT_START_RESP =
    msgMbtrainValVrefStartRxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_REQ =
    msgMbtrainRxInitD2CTxCountDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_COUNT_DONE_RESP =
    msgMbtrainRxInitD2CTxCountDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_REQ =
    msgMbtrainRxInitD2CEndPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_RESP =
    msgMbtrainRxInitD2CEndPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // The Start Rx Init request contains variable MsgInfo/payload/parity.  Match
  // its fixed message-code/subcode/source/opcode fields in the low 40 bits.
  wire isRxInitStartReq =
    (sb_rx_dout[39:0] == RXINIT_START_REQ[39:0]);

  wire receivedOuterStartReq = rxValidRisingEdge &&
                               (sb_rx_dout == OUTER_START_REQ);
  wire receivedOuterStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == OUTER_START_RESP);
  wire receivedOuterEndReq = rxValidRisingEdge &&
                             (sb_rx_dout == OUTER_END_REQ);
  wire receivedOuterEndResp = rxValidRisingEdge &&
                              (sb_rx_dout == OUTER_END_RESP);

  wire receivedPointStartReq = rxValidRisingEdge && isRxInitStartReq;
  wire receivedPointStartResp = rxValidRisingEdge &&
                                (sb_rx_dout == RXINIT_START_RESP);
  wire receivedClearErrorReq = rxValidRisingEdge &&
                               (sb_rx_dout == CLEAR_ERROR_REQ);
  wire receivedClearErrorResp = rxValidRisingEdge &&
                                (sb_rx_dout == CLEAR_ERROR_RESP);
  wire receivedTxCountDoneReq = rxValidRisingEdge &&
                                (sb_rx_dout == TX_COUNT_DONE_REQ);
  wire receivedTxCountDoneResp = rxValidRisingEdge &&
                                 (sb_rx_dout == TX_COUNT_DONE_RESP);
  wire receivedEndPointReq = rxValidRisingEdge &&
                             (sb_rx_dout == END_POINT_REQ);
  wire receivedEndPointResp = rxValidRisingEdge &&
                              (sb_rx_dout == END_POINT_RESP);

  wire localOuterStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterStartReq);
  wire localOuterEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_localOuterEndReq);
  wire remoteOuterStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterStartResp);
  wire remoteOuterEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_remoteOuterEndResp);

  wire initiatorStartReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorStartReq);
  wire initiatorClearRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorClearResp);
  wire initiatorCountRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorCountResp);
  wire initiatorEndReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointInitiatorEndReq);

  wire responderStartRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderStartResp);
  wire responderClearReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderClearReq);
  wire responderCountReqSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderCountReq);
  wire responderEndRespSent = txTransfer &&
    (sbTxSourceReg == TxSource_pointResponderEndResp);

  logic sweepStart;
  logic sweepBusy;
  logic sweepDone;
  logic sweepTrainError;
  logic sweepApplyVref;
  logic [VREF_CODE_WIDTH-1:0] sweepVrefCode;
  logic sweepPointStart;
  logic [3:0] sweepState;
  logic [15:0] sweepFailedPointCount;
  logic [15:0] sweepRetryCount;
  logic [VREF_CODE_WIDTH-1:0] sweepFinalCode;
  logic [VREF_CODE_WIDTH-1:0] sweepLeftCode;
  logic [VREF_CODE_WIDTH-1:0] sweepRightCode;

  logic initiatorSendStartReq;
  logic initiatorSendClearResp;
  logic initiatorSendCountResp;
  logic initiatorSendEndReq;
  logic initiatorConfigureReceiver;
  logic initiatorClearErrors;
  logic initiatorBusy;
  logic initiatorDone;
  logic initiatorPointPass;
  logic [3:0] initiatorState;

  logic responderSendStartResp;
  logic responderSendClearReq;
  logic responderSendCountReq;
  logic responderSendEndResp;
  logic responderSendPattern;
  logic responderResetTxScrambler;
  logic responderBusy;
  logic responderDone;
  logic [3:0] responderState;

  wire responderStart = runningReg &&
                        (remoteStateReg == RemoteState_active) &&
                        receivedPointStartReq;

  assign sweepStart = runningReg &&
                      (localStateReg == LocalState_startSweep);

  MBTrain_ValidVrefSweepEngine #(
    .VREF_VALUE_COUNT(VREF_VALUE_COUNT),
    .VREF_CODE_WIDTH(VREF_CODE_WIDTH),
    .MIN_PASSING_WINDOW_VALUES(MIN_PASSING_WINDOW_VALUES),
    .MAX_TRAINING_RETRIES(MAX_TRAINING_RETRIES)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepStart),
    .busy(sweepBusy),
    .done(sweepDone),
    .trainError(sweepTrainError),
    .apply_rx_vref(sweepApplyVref),
    .rx_vref_code(sweepVrefCode),
    .rx_vref_applied(flagFromAnalog_rxVrefApplied),
    .point_test_start(sweepPointStart),
    .point_test_done(initiatorDone),
    .point_test_pass(initiatorPointPass),
    .state(sweepState),
    .lastFailedPointCount(sweepFailedPointCount),
    .retryCount(sweepRetryCount),
    .finalVrefCode(sweepFinalCode),
    .validLeftCode(sweepLeftCode),
    .validRightCode(sweepRightCode)
  );

  RxInitD2CPointTestReceiverFSM pointInitiator (
    .clock(clock),
    .reset_n(reset_n),
    .start(runningReg && sweepPointStart),
    .configureReceiver(initiatorConfigureReceiver),
    .sendStartRxInitD2CPointTestReq(initiatorSendStartReq),
    .sentStartRxInitD2CPointTestReq(initiatorStartReqSent),
    .receivedStartRxInitD2CPointTestResp(receivedPointStartResp),
    .receivedLfsrClearErrorReq(receivedClearErrorReq),
    .clearComparisonErrors(initiatorClearErrors),
    .sendLfsrClearErrorResp(initiatorSendClearResp),
    .sentLfsrClearErrorResp(initiatorClearRespSent),
    .receivedRxInitD2CTxCountDoneReq(receivedTxCountDoneReq),
    .detectedValidPattern(flagFromAnalog_detectedValPattern),
    .sendRxInitD2CTxCountDoneResp(initiatorSendCountResp),
    .sentRxInitD2CTxCountDoneResp(initiatorCountRespSent),
    .sendEndRxInitD2CPointTestReq(initiatorSendEndReq),
    .sentEndRxInitD2CPointTestReq(initiatorEndReqSent),
    .receivedEndRxInitD2CPointTestResp(receivedEndPointResp),
    .busy(initiatorBusy),
    .done(initiatorDone),
    .pointTestPass(initiatorPointPass),
    .state(initiatorState)
  );

  RxInitD2CPointTestSenderFSM pointResponder (
    .clock(clock),
    .reset_n(reset_n),
    .start(responderStart),
    .sendStartRxInitD2CPointTestResp(responderSendStartResp),
    .sentStartRxInitD2CPointTestResp(responderStartRespSent),
    .resetLocalScrambler(responderResetTxScrambler),
    .sendLfsrClearErrorReq(responderSendClearReq),
    .sentLfsrClearErrorReq(responderClearReqSent),
    .receivedLfsrClearErrorResp(receivedClearErrorResp),
    .sendDefinedPattern(responderSendPattern),
    .sentDefinedPattern(flagFromAnalog_valTrainPatternSent),
    .sendRxInitD2CTxCountDoneReq(responderSendCountReq),
    .sentRxInitD2CTxCountDoneReq(responderCountReqSent),
    .receivedRxInitD2CTxCountDoneResp(receivedTxCountDoneResp),
    .receivedEndRxInitD2CPointTestReq(receivedEndPointReq),
    .sendEndRxInitD2CPointTestResp(responderSendEndResp),
    .sentEndRxInitD2CPointTestResp(responderEndRespSent),
    .busy(responderBusy),
    .done(responderDone),
    .state(responderState)
  );

  always_comb begin
    busy       = runningReg && !doneReg;
    done       = doneReg;
    trainError = trainErrorReg || sweepTrainError;
    sb_tx_valid = sbTxValidReg;
    sb_tx_din   = sbTxDinReg;

    flagToAnalog_applyRxVref = runningReg && PERFORM_LOCAL_TRAINING &&
                               sweepApplyVref;
    flagToAnalog_rxVrefCode = sweepVrefCode;
    flagToAnalog_configureRxInitD2CPointTest = runningReg &&
                                               initiatorConfigureReceiver;
    flagToAnalog_maximumComparisonErrorThreshold =
      MAXIMUM_COMPARISON_ERROR_THRESHOLD;
    flagToAnalog_comparisonMode = 1'b0;
    flagToAnalog_iterationCountSettings = 16'd1;
    flagToAnalog_idleCountSettings = 16'd0;
    flagToAnalog_burstCountSettings = 16'd1024;
    flagToAnalog_patternMode = 1'b0;
    flagToAnalog_clockPhaseControl = 4'd0;
    flagToAnalog_validPattern = 3'd0;
    flagToAnalog_dataPattern = 3'd0;
    flagToAnalog_clearComparisonErrors = runningReg && initiatorClearErrors;

    flagToAnalog_sendValTrainPattern = runningReg && responderSendPattern;
    flagToAnalog_resetLocalTxScrambler = runningReg &&
                                         responderResetTxScrambler;

    dbg_localState = localStateReg;
    dbg_remoteState = remoteStateReg;
    dbg_sweepState = sweepState;
    dbg_pointInitiatorState = initiatorState;
    dbg_pointResponderState = responderState;
    lastErrorCount = sweepFailedPointCount;
    retryCount = sweepRetryCount;
    selectedVrefCode = sweepFinalCode;
    validWindowLeftCode = sweepLeftCode;
    validWindowRightCode = sweepRightCode;
  end

  // One-deep sideband TX buffer.  Protocol responses and the remote
  // transmitter role take priority, preventing a local sweep from starving the
  // opposite die's receiver-initiated point test.
  always_comb begin
    txLoadValid  = 1'b0;
    txLoadDin    = 128'd0;
    txLoadSource = TxSource_none;

    if (runningReg && !sbTxValidReg) begin
      if (remoteStateReg == RemoteState_sendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_RESP;
        txLoadSource = TxSource_remoteOuterEndResp;
      end else if (responderSendEndResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_RESP;
        txLoadSource = TxSource_pointResponderEndResp;
      end else if (initiatorSendCountResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_RESP;
        txLoadSource = TxSource_pointInitiatorCountResp;
      end else if (responderSendCountReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = TX_COUNT_DONE_REQ;
        txLoadSource = TxSource_pointResponderCountReq;
      end else if (initiatorSendClearResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_RESP;
        txLoadSource = TxSource_pointInitiatorClearResp;
      end else if (responderSendClearReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = CLEAR_ERROR_REQ;
        txLoadSource = TxSource_pointResponderClearReq;
      end else if (responderSendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_RESP;
        txLoadSource = TxSource_pointResponderStartResp;
      end else if (remoteStateReg == RemoteState_sendStartResp) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_RESP;
        txLoadSource = TxSource_remoteOuterStartResp;
      end else if (initiatorSendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = END_POINT_REQ;
        txLoadSource = TxSource_pointInitiatorEndReq;
      end else if (initiatorSendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = RXINIT_START_REQ;
        txLoadSource = TxSource_pointInitiatorStartReq;
      end else if (localStateReg == LocalState_sendEndReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_END_REQ;
        txLoadSource = TxSource_localOuterEndReq;
      end else if (localStateReg == LocalState_sendStartReq) begin
        txLoadValid  = 1'b1;
        txLoadDin    = OUTER_START_REQ;
        txLoadSource = TxSource_localOuterStartReq;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else if (!runningReg) begin
      sbTxValidReg  <= 1'b0;
      sbTxDinReg    <= 128'd0;
      sbTxSourceReg <= TxSource_none;
    end else begin
      if (txTransfer) begin
        sbTxValidReg  <= 1'b0;
        sbTxSourceReg <= TxSource_none;
      end
      if (!sbTxValidReg && txLoadValid) begin
        sbTxValidReg  <= 1'b1;
        sbTxDinReg    <= txLoadDin;
        sbTxSourceReg <= txLoadSource;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      localStateReg  <= LocalState_idle;
      remoteStateReg <= RemoteState_idle;
      runningReg     <= 1'b0;
      doneReg        <= 1'b0;
      trainErrorReg  <= 1'b0;
      prevStart      <= 1'b0;
      prevRxValid    <= 1'b0;
      remoteOuterEndPendingReg <= 1'b0;
    end else begin
      prevStart   <= start;
      prevRxValid <= sb_rx_valid;

      if (startPulse) begin
        localStateReg  <= LocalState_sendStartReq;
        remoteStateReg <= RemoteState_waitStartReq;
        runningReg     <= 1'b1;
        doneReg        <= 1'b0;
        trainErrorReg  <= 1'b0;
        remoteOuterEndPendingReg <= 1'b0;
      end else if (runningReg) begin
        // End/Done may be received before the last remotely initiated point
        // test has completely retired.  Preserve it until the responder is
        // idle, then issue the outer response.
        if (receivedOuterEndReq)
          remoteOuterEndPendingReg <= 1'b1;

        unique case (localStateReg)
          LocalState_sendStartReq: begin
            if (localOuterStartReqSent)
              localStateReg <= LocalState_waitStartResp;
          end
          LocalState_waitStartResp: begin
            if (receivedOuterStartResp) begin
              if (PERFORM_LOCAL_TRAINING)
                localStateReg <= LocalState_startSweep;
              else
                localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_startSweep:
            localStateReg <= LocalState_waitSweep;
          LocalState_waitSweep: begin
            if (sweepTrainError) begin
              localStateReg <= LocalState_error;
              trainErrorReg <= 1'b1;
              runningReg    <= 1'b0;
            end else if (sweepDone) begin
              localStateReg <= LocalState_sendEndReq;
            end
          end
          LocalState_sendEndReq: begin
            if (localOuterEndReqSent)
              localStateReg <= LocalState_waitEndResp;
          end
          LocalState_waitEndResp: begin
            if (receivedOuterEndResp)
              localStateReg <= LocalState_finish;
          end
          LocalState_finish: ;
          LocalState_error: ;
          default: localStateReg <= LocalState_idle;
        endcase

        unique case (remoteStateReg)
          RemoteState_waitStartReq: begin
            if (receivedOuterStartReq)
              remoteStateReg <= RemoteState_sendStartResp;
          end
          RemoteState_sendStartResp: begin
            if (remoteOuterStartRespSent)
              remoteStateReg <= RemoteState_active;
          end
          RemoteState_active: begin
            if ((receivedOuterEndReq || remoteOuterEndPendingReg) &&
                !responderBusy) begin
              remoteStateReg <= RemoteState_sendEndResp;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_sendEndResp: begin
            if (remoteOuterEndRespSent) begin
              remoteStateReg <= RemoteState_finish;
              remoteOuterEndPendingReg <= 1'b0;
            end
          end
          RemoteState_finish: ;
          default: remoteStateReg <= RemoteState_idle;
        endcase

        if ((localStateReg == LocalState_finish) &&
            (remoteStateReg == RemoteState_finish)) begin
          runningReg <= 1'b0;
          doneReg    <= 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire
