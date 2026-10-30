// UCIe 2.0 MBTRAIN.RXDESKEW implementation.
//
// Each die concurrently performs two roles:
//   1. Receiver initiator: optionally sweep local per-lane RX deskew codes and
//      run one receiver-initiated D2C point test at every code.
//   2. Transmitter responder: serve the partner receiver's point tests by
//      transmitting the 4096-UI continuous LFSR pattern with functional Valid
//      framing.
//
// The RX delay-control vector intentionally mirrors the project's TX deskew
// control convention: one unsigned implementation-defined code per Data lane,
// an apply request, and an applied acknowledgement.
`default_nettype none

module MBTrainRxDeskewFSM #(
  parameter bit sbFeatureExtension =
    LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing =
    LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed =
    LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter bit performRxDeskew =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_ENABLE,
  parameter int unsigned dataLaneCount = 16,
  parameter logic [dataLaneCount-1:0] activeDataLaneMask =
    {dataLaneCount{1'b1}},
  parameter int unsigned rxDeskewCodeWidth =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_CODE_WIDTH,
  parameter int unsigned rxDeskewValueCount =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_VALUE_COUNT,
  parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned rxDeskewMinPassingWindowValues =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES,
  parameter int unsigned rxDeskewMaxTrainingRetries =
    LtsmParameters_pkg::DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES
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

  // Local receiver controls: these are the RX lane delays being optimized.
  output      logic                         flagToAnalog_rxDeskewApplyRxLaneDeskew,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] flagToAnalog_rxDeskewRxLaneDeskewCodes,
  input  wire logic                         flagFromAnalog_rxDeskewRxLaneDeskewApplied,
  output      logic                         flagToAnalog_rxDeskewConfigureRxInitD2CPointTest,
  output      logic [15:0]                  flagToAnalog_rxDeskewMaximumComparisonErrorThreshold,
  output      logic                         flagToAnalog_rxDeskewComparisonMode,
  output      logic [15:0]                  flagToAnalog_rxDeskewIterationCountSettings,
  output      logic [15:0]                  flagToAnalog_rxDeskewIdleCountSettings,
  output      logic [15:0]                  flagToAnalog_rxDeskewBurstCountSettings,
  output      logic                         flagToAnalog_rxDeskewPatternMode,
  output      logic [3:0]                   flagToAnalog_rxDeskewClockPhaseControl,
  output      logic [2:0]                   flagToAnalog_rxDeskewValidPattern,
  output      logic [2:0]                   flagToAnalog_rxDeskewDataPattern,
  output      logic                         flagToAnalog_rxDeskewClearComparisonErrors,
  input  wire logic [dataLaneCount-1:0] flagFromAnalog_rxDeskewDetectedDataPattern,

  // Local transmitter controls used while serving the opposite receiver.
  output      logic                         flagToAnalog_rxDeskewSendLfsrPattern,
  input  wire logic                         flagFromAnalog_rxDeskewLfsrPatternSent,
  output      logic                         flagToAnalog_rxDeskewResetLocalTxScrambler,

  output      logic [3:0]                   dbg_localState,
  output      logic [2:0]                   dbg_remoteState,
  output      logic [3:0]                   dbg_sweepState,
  output      logic [3:0]                   dbg_pointInitiatorState,
  output      logic [3:0]                   dbg_pointResponderState,
  output      logic [15:0]                  lastErrorCount,
  output      logic [15:0]                  retryCount,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] selectedRxDeskewCodes,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] validWindowLeftCodes,
  output      logic [dataLaneCount*rxDeskewCodeWidth-1:0] validWindowRightCodes
);
  import SidebandMsgGenerator_pkg::*;

  logic unusedConfiguration;
  assign unusedConfiguration = sbFeatureExtension ^ ucieA ^ moduleID[0] ^
                               clkPhase ^ clkMode ^ voltageSwing[0] ^
                               maxLinkSpeed[0];

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
  // this latch, an asymmetric optional RXDESKEW configuration can lose the
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

  wire [127:0] OUTER_START_REQ =
    msgMbtrainRxDeskewStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_START_RESP =
    msgMbtrainRxDeskewStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_REQ =
    msgMbtrainRxDeskewEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] OUTER_END_RESP =
    msgMbtrainRxDeskewEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  // Continuous Data-lane LFSR training: 4096 UI accompanied by the
  // functional Valid framing.  Track remains low while this state is active.
  wire [127:0] RXINIT_START_REQ =
    msgMbtrainDataVrefStartRxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      rxDeskewMaximumComparisonErrorThreshold,
      1'b0,       // per-lane comparison
      16'd1,      // continuous-mode convention
      16'd0,      // no idle UI
      16'd4096,   // 4K UI continuous LFSR burst
      1'b0,       // continuous pattern mode
      4'd0,       // forwarded-clock phase is not changed here
      3'd0,       // functional Valid framing
      3'd0        // Data-lane LFSR
    );
  wire [127:0] RXINIT_START_RESP =
    msgMbtrainDataVrefStartRxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
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
  logic sweepApplyDeskew;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepDeskewCodes;
  logic sweepPointStart;
  logic [3:0] sweepState;
  logic [15:0] sweepFailedLaneCount;
  logic [15:0] sweepRetryCount;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepFinalDeskewCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepLeftCodes;
  logic [dataLaneCount*rxDeskewCodeWidth-1:0] sweepRightCodes;

  logic initiatorSendStartReq;
  logic initiatorSendClearResp;
  logic initiatorSendCountResp;
  logic initiatorSendEndReq;
  logic initiatorConfigureReceiver;
  logic initiatorClearErrors;
  logic initiatorBusy;
  logic initiatorDone;
  logic [dataLaneCount-1:0] initiatorPointPassVector;
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

  MBTrain_RxDeskewSweepEngine #(
    .DATA_LANE_COUNT(dataLaneCount),
    .ACTIVE_DATA_LANE_MASK(activeDataLaneMask),
    .RX_DESKEW_VALUE_COUNT(rxDeskewValueCount),
    .RX_DESKEW_CODE_WIDTH(rxDeskewCodeWidth),
    .MIN_PASSING_WINDOW_VALUES(rxDeskewMinPassingWindowValues),
    .MAX_TRAINING_RETRIES(rxDeskewMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepStart),
    .busy(sweepBusy),
    .done(sweepDone),
    .trainError(sweepTrainError),
    .apply_rx_lane_deskew(sweepApplyDeskew),
    .rx_lane_deskew_codes(sweepDeskewCodes),
    .rx_lane_deskew_applied(flagFromAnalog_rxDeskewRxLaneDeskewApplied),
    .point_test_start(sweepPointStart),
    .point_test_done(initiatorDone),
    .point_test_pass(initiatorPointPassVector),
    .state(sweepState),
    .lastFailedLaneCount(sweepFailedLaneCount),
    .retryCount(sweepRetryCount),
    .finalRxDeskewCodes(sweepFinalDeskewCodes),
    .validWindowLeftCodes(sweepLeftCodes),
    .validWindowRightCodes(sweepRightCodes)
  );

  RxInitD2CPointTestReceiverFSM #(
    .RESULT_WIDTH(dataLaneCount)
  ) pointInitiator (
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
    .detectedValidPattern(flagFromAnalog_rxDeskewDetectedDataPattern),
    .sendRxInitD2CTxCountDoneResp(initiatorSendCountResp),
    .sentRxInitD2CTxCountDoneResp(initiatorCountRespSent),
    .sendEndRxInitD2CPointTestReq(initiatorSendEndReq),
    .sentEndRxInitD2CPointTestReq(initiatorEndReqSent),
    .receivedEndRxInitD2CPointTestResp(receivedEndPointResp),
    .busy(initiatorBusy),
    .done(initiatorDone),
    .pointTestPass(initiatorPointPassVector),
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
    .sentDefinedPattern(flagFromAnalog_rxDeskewLfsrPatternSent),
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

    flagToAnalog_rxDeskewApplyRxLaneDeskew = runningReg && performRxDeskew &&
                               sweepApplyDeskew;
    flagToAnalog_rxDeskewRxLaneDeskewCodes = sweepDeskewCodes;
    flagToAnalog_rxDeskewConfigureRxInitD2CPointTest = runningReg &&
                                               initiatorConfigureReceiver;
    flagToAnalog_rxDeskewMaximumComparisonErrorThreshold =
      rxDeskewMaximumComparisonErrorThreshold;
    flagToAnalog_rxDeskewComparisonMode = 1'b0;
    flagToAnalog_rxDeskewIterationCountSettings = 16'd1;
    flagToAnalog_rxDeskewIdleCountSettings = 16'd0;
    flagToAnalog_rxDeskewBurstCountSettings = 16'd4096;
    flagToAnalog_rxDeskewPatternMode = 1'b0;
    flagToAnalog_rxDeskewClockPhaseControl = 4'd0;
    flagToAnalog_rxDeskewValidPattern = 3'd0;
    flagToAnalog_rxDeskewDataPattern = 3'd0;
    flagToAnalog_rxDeskewClearComparisonErrors = runningReg && initiatorClearErrors;

    flagToAnalog_rxDeskewSendLfsrPattern = runningReg && responderSendPattern;
    flagToAnalog_rxDeskewResetLocalTxScrambler = runningReg &&
                                         responderResetTxScrambler;

    dbg_localState = localStateReg;
    dbg_remoteState = remoteStateReg;
    dbg_sweepState = sweepState;
    dbg_pointInitiatorState = initiatorState;
    dbg_pointResponderState = responderState;
    lastErrorCount = sweepFailedLaneCount;
    retryCount = sweepRetryCount;
    selectedRxDeskewCodes = sweepFinalDeskewCodes;
    validWindowLeftCodes = sweepLeftCodes;
    validWindowRightCodes = sweepRightCodes;
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
              if (performRxDeskew)
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
