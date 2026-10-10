// SystemVerilog translation of MBTrain_DataTrainCenter1.scala.
`default_nettype none

module MBTrain_DataTrainCenter1 #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED,
  parameter int unsigned d2cPiCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH,
  parameter int unsigned d2cTxDeskewCodeWidth = LtsmParameters_pkg::DEFAULT_D2C_TX_DESKEW_CODE_WIDTH,
  parameter int unsigned d2cDeskewStepsPerPi = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_STEPS_PER_PI,
  parameter bit d2cDeskewAddDelayIncreasesPhase = LtsmParameters_pkg::DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE,
  parameter logic [15:0] d2cMaximumComparisonErrorThreshold = LtsmParameters_pkg::DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD,
  parameter int unsigned d2cMinLaneWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_LANE_WINDOW_STEPS,
  parameter int unsigned d2cMinCommonWindowSteps = LtsmParameters_pkg::DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS,
  parameter int unsigned d2cMaxTrainingRetries = LtsmParameters_pkg::DEFAULT_D2C_MAX_TRAINING_RETRIES
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
  output var logic         flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic         flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
  output var logic         flagToAnalog_d2cSender_applyTxClockPhase,
  output var logic [d2cPiCodeWidth-1:0] flagToAnalog_d2cSender_txClockPhaseCode,
  input wire logic         flagFromAnalog_d2cSender_txClockPhaseApplied,
  output var logic         flagToAnalog_d2cSender_applyTxLaneDeskew,
  output var logic [64*d2cTxDeskewCodeWidth-1:0] flagToAnalog_d2cSender_txLaneDeskewCodes,
  input wire logic         flagFromAnalog_d2cSender_txLaneDeskewApplied,
  output var logic         flagToAnalog_d2cReceiver_configureTxInitD2CPointTest,
  output var logic [15:0]  flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold,
  output var logic         flagToAnalog_d2cReceiver_comparisonMode,
  output var logic [15:0]  flagToAnalog_d2cReceiver_iterationCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_idleCountSettings,
  output var logic [15:0]  flagToAnalog_d2cReceiver_burstCountSettings,
  output var logic         flagToAnalog_d2cReceiver_patternMode,
  output var logic [3:0]   flagToAnalog_d2cReceiver_clockPhaseControl,
  output var logic [2:0]   flagToAnalog_d2cReceiver_validPattern,
  output var logic [2:0]   flagToAnalog_d2cReceiver_dataPattern,
  output var logic         flagToAnalog_d2cReceiver_resetLocalRxScrambler,
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo,
  input wire logic [63:0]  flagFromAnalog_d2cReceiver_txInitD2CResultsPayload,
  output var logic [3:0]   dbg_senderState,
  output var logic [2:0]   dbg_receiverState,
  output var logic [3:0]   dbg_d2cSenderState,
  output var logic [3:0]   dbg_d2cReceiverState,
  output var logic [4:0]   dbg_sweepState,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    DataTrainCenter1SenderState_idle = 4'h0,
    DataTrainCenter1SenderState_sendStartReq = 4'h1,
    DataTrainCenter1SenderState_waitStartResp = 4'h2,
    DataTrainCenter1SenderState_startPointTest = 4'h3,
    DataTrainCenter1SenderState_waitPointTest = 4'h4,
    DataTrainCenter1SenderState_checkErrorLog = 4'h5,
    DataTrainCenter1SenderState_sendDoneReq = 4'h6,
    DataTrainCenter1SenderState_waitDoneResp = 4'h7,
    DataTrainCenter1SenderState_finish = 4'h8
  } DataTrainCenter1SenderState_t;

  typedef enum logic [2:0] {
    DataTrainCenter1ReceiverState_idle = 3'h0,
    DataTrainCenter1ReceiverState_waitStartReq = 3'h1,
    DataTrainCenter1ReceiverState_sendStartResp = 3'h2,
    DataTrainCenter1ReceiverState_runPointTest = 3'h3,
    DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    DataTrainCenter1ReceiverState_sendDoneResp = 3'h5,
    DataTrainCenter1ReceiverState_finish = 3'h6
  } DataTrainCenter1ReceiverState_t;

  (* keep = "true" *) DataTrainCenter1SenderState_t senderStateReg;
  (* keep = "true" *) DataTrainCenter1ReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  (* keep = "true" *) logic flagReceivedStartResp;
  (* keep = "true" *) logic flagReceivedDoneResp;
  (* keep = "true" *) logic flagReceivedStartReq;
  (* keep = "true" *) logic flagReceivedDoneReq;

  (* keep = "true" *) logic d2cSender_receivedPointTestStartResp;
  (* keep = "true" *) logic d2cSender_receivedLfsrClearResp;
  (* keep = "true" *) logic d2cSender_receivedResultsResp;
  (* keep = "true" *) logic d2cSender_receivedEndPointTestResp;

  (* keep = "true" *) logic d2cReceiver_receivedPointTestStartReq;
  (* keep = "true" *) logic d2cReceiver_receivedLfsrClearReq;
  (* keep = "true" *) logic d2cReceiver_receivedResultsReq;
  (* keep = "true" *) logic d2cReceiver_receivedEndPointTestReq;

  (* keep = "true" *) logic flagSentStartReq;
  (* keep = "true" *) logic flagSentDoneReq;
  (* keep = "true" *) logic flagSentStartResp;
  (* keep = "true" *) logic flagSentDoneResp;

  (* keep = "true" *) logic d2cSender_sentPointTestStartReq;
  (* keep = "true" *) logic d2cSender_sentLfsrClearReq;
  (* keep = "true" *) logic d2cSender_sentResultsReq;
  (* keep = "true" *) logic d2cSender_sentEndPointTestReq;

  (* keep = "true" *) logic d2cReceiver_sentPointTestStartResp;
  (* keep = "true" *) logic d2cReceiver_sentLfsrClearResp;
  (* keep = "true" *) logic d2cReceiver_sentResultsResp;
  (* keep = "true" *) logic d2cReceiver_sentEndPointTestResp;

  (* keep = "true" *) logic [15:0] logErrorCountReg;
  (* keep = "true" *) logic [15:0] retryCountReg;
  (* keep = "true" *) logic [15:0] d2cReceiver_loggedResultsMsgInfo;
  (* keep = "true" *) logic [63:0] d2cReceiver_loggedResultsPayload;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;

  // The tested linear sweep engine controls the local forwarded-clock PI and
  // local TX lane deskew.  The existing point-test sender/receiver FSMs and
  // sideband message generation remain in this wrapper.
  logic sweepEngine_start;
  logic sweepEngine_busy;
  logic sweepEngine_done;
  logic sweepEngine_trainError;
  logic sweepEngine_applyTxClockPhase;
  logic [d2cPiCodeWidth-1:0] sweepEngine_txClockPhaseCode;
  logic sweepEngine_applyTxLaneDeskew;
  logic [64*d2cTxDeskewCodeWidth-1:0] sweepEngine_txLaneDeskewCodes;
  logic sweepEngine_pointTestStart;
  logic [4:0] sweepEngine_state;
  logic [15:0] sweepEngine_lastFailedComparisons;
  logic [15:0] sweepEngine_retryCount;
  logic [d2cPiCodeWidth-1:0] sweepEngine_finalClockPhase;

  logic [63:0] d2cSender_resultsLanePassReg;
  logic d2cSender_resultsValidPassReg;
  logic d2cSender_resultsCumulativePassReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;

  logic d2cSender_start;
  logic d2cReceiver_start;
  logic senderSentStartPulse;
  logic senderSentLfsrPulse;
  logic senderSentResultsPulse;
  logic senderSentEndPulse;
  logic flagToAnalog_d2cReceiver_configureAnalogPulse;

  logic selectSentDoneResp;
  logic selectReceiverEndResp;
  logic selectReceiverResultsResp;
  logic selectReceiverLfsrResp;
  logic selectReceiverStartResp;
  logic selectSentStartResp;
  logic selectSentDoneReq;
  logic selectSenderEndReq;
  logic selectSenderResultsReq;
  logic selectSenderLfsrReq;
  logic selectSenderStartReq;
  logic selectSentStartReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_DATATRAINCENTER1_START_REQ =
    msgMbtrainDataTrainCenter1StartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_START_RESP =
    msgMbtrainDataTrainCenter1StartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_DONE_REQ =
    msgMbtrainDataTrainCenter1EndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_DATATRAINCENTER1_DONE_RESP =
    msgMbtrainDataTrainCenter1EndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      d2cMaximumComparisonErrorThreshold,
      1'b1, 16'd1, 16'd0, 16'd4096,
      1'b0, 4'd0, 3'd0, 3'd0
    );
  wire [127:0] START_POINT_TEST_RESP =
    msgMbtrainStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_REQ =
    msgMbtrainLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] LFSR_CLEAR_ERROR_RESP =
    msgMbtrainLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_REQ =
    msgMbtrainTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] TX_INIT_RESULTS_RESP_TEMPLATE =
    msgMbtrainTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, 64'd0);
  wire [127:0] END_POINT_TEST_REQ =
    msgMbtrainEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] END_POINT_TEST_RESP =
    msgMbtrainEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire isStartPointTestReq =
    ((sb_rx_dout[63:0] & 64'h000000FFFFFFFFFF) ==
     (START_POINT_TEST_REQ[63:0] & 64'h000000FFFFFFFFFF));

  // A results response contains variable MsgInfo, payload, and parity bits.
  // Compare only the fixed header fields (including endpoint IDs, code,
  // subcode, and opcode), otherwise a valid pass/fail response is missed.
  wire isTxInitResultsResp =
    (sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
    (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]);

  logic d2cSender_sendStartTxInitD2CPointTestReq;
  logic d2cSender_sendLfsrClearErrorReq;
  logic d2cSender_sendTxInitD2CResultsReq;
  logic d2cSender_sendEndTxInitD2CPointTestReq;
  logic d2cSender_sendDefinedPattern;
  logic d2cSender_resetLocalScrambler;
  logic d2cSender_busy;
  logic d2cSender_done;
  logic [3:0] d2cSender_state;

  logic d2cReceiver_sendStartTxInitD2CPointTestResp;
  logic d2cReceiver_sendLfsrClearErrorResp;
  logic d2cReceiver_sendTxInitD2CResultsResp;
  logic d2cReceiver_sendEndTxInitD2CPointTestResp;
  logic d2cReceiver_resetLocalRxScrambler;
  logic d2cReceiver_busy;
  logic d2cReceiver_done;
  logic [3:0] d2cReceiver_state;

  TxInitD2CPointTestSenderFSM d2cSender (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cSender_start),
    .receivedStartTxInitD2CPointTestResp(d2cSender_receivedPointTestStartResp),
    .receivedLfsrClearErrorResp(d2cSender_receivedLfsrClearResp),
    .receivedTxInitD2CResultsResp(d2cSender_receivedResultsResp),
    .receivedEndTxInitD2CPointTestResp(d2cSender_receivedEndPointTestResp),
    .sentStartTxInitD2CPointTestReq(senderSentStartPulse),
    .sentLfsrClearErrorReq(senderSentLfsrPulse),
    .sentTxInitD2CResultsReq(senderSentResultsPulse),
    .sentEndTxInitD2CPointTestReq(senderSentEndPulse),
    .sentDefinedPattern(flagFromAnalog_d2cSender_lfsrPatternSent),
    .sendStartTxInitD2CPointTestReq(d2cSender_sendStartTxInitD2CPointTestReq),
    .sendLfsrClearErrorReq(d2cSender_sendLfsrClearErrorReq),
    .sendTxInitD2CResultsReq(d2cSender_sendTxInitD2CResultsReq),
    .sendEndTxInitD2CPointTestReq(d2cSender_sendEndTxInitD2CPointTestReq),
    .sendDefinedPattern(d2cSender_sendDefinedPattern),
    .resetLocalScrambler(d2cSender_resetLocalScrambler),
    .busy(d2cSender_busy),
    .done(d2cSender_done),
    .state(d2cSender_state)
  );

  TxInitD2CPointTestReceiverFSM d2cReceiver (
    .clock(clock),
    .reset_n(reset_n),
    .start(d2cReceiver_start),
    .receivedStartTxInitD2CPointTestReq(d2cReceiver_receivedPointTestStartReq),
    .receivedLfsrClearErrorReq(d2cReceiver_receivedLfsrClearReq),
    .receivedTxInitD2CResultsReq(d2cReceiver_receivedResultsReq),
    .receivedEndTxInitD2CPointTestReq(d2cReceiver_receivedEndPointTestReq),
    .sentStartTxInitD2CPointTestResp(d2cReceiver_sentPointTestStartResp),
    .sentLfsrClearErrorResp(d2cReceiver_sentLfsrClearResp),
    .sentTxInitD2CResultsResp(d2cReceiver_sentResultsResp),
    .sentEndTxInitD2CPointTestResp(d2cReceiver_sentEndPointTestResp),
    .sendStartTxInitD2CPointTestResp(d2cReceiver_sendStartTxInitD2CPointTestResp),
    .sendLfsrClearErrorResp(d2cReceiver_sendLfsrClearErrorResp),
    .sendTxInitD2CResultsResp(d2cReceiver_sendTxInitD2CResultsResp),
    .sendEndTxInitD2CPointTestResp(d2cReceiver_sendEndTxInitD2CPointTestResp),
    .resetLocalRxScrambler(d2cReceiver_resetLocalRxScrambler),
    .busy(d2cReceiver_busy),
    .done(d2cReceiver_done),
    .state(d2cReceiver_state)
  );

  MBTrain_DataTrainCenter1SweepEngine #(
    .ucieA(ucieA),
    .PI_CODE_WIDTH(d2cPiCodeWidth),
    .TX_DESKEW_CODE_WIDTH(d2cTxDeskewCodeWidth),
    .DESKEW_STEPS_PER_PI(d2cDeskewStepsPerPi),
    .DESKEW_ADD_DELAY_INCREASES_PHASE(d2cDeskewAddDelayIncreasesPhase),
    .MIN_LANE_WINDOW_STEPS(d2cMinLaneWindowSteps),
    .MIN_COMMON_WINDOW_STEPS(d2cMinCommonWindowSteps),
    .MAX_TRAINING_RETRIES(d2cMaxTrainingRetries)
  ) sweepEngine (
    .clock(clock),
    .reset_n(reset_n),
    .start(sweepEngine_start),
    .busy(sweepEngine_busy),
    .done(sweepEngine_done),
    .trainError(sweepEngine_trainError),
    .apply_tx_clock_phase(sweepEngine_applyTxClockPhase),
    .tx_clock_phase_code(sweepEngine_txClockPhaseCode),
    .tx_clock_phase_applied(flagFromAnalog_d2cSender_txClockPhaseApplied),
    .apply_tx_lane_deskew(sweepEngine_applyTxLaneDeskew),
    .tx_lane_deskew_codes(sweepEngine_txLaneDeskewCodes),
    .tx_lane_deskew_applied(flagFromAnalog_d2cSender_txLaneDeskewApplied),
    .point_test_start(sweepEngine_pointTestStart),
    .point_test_done(d2cSender_done),
    .point_test_lane_pass(d2cSender_resultsLanePassReg),
    .point_test_valid_pass(d2cSender_resultsValidPassReg),
    .point_test_cumulative_pass(d2cSender_resultsCumulativePassReg),
    .state(sweepEngine_state),
    .lastFailedComparisons(sweepEngine_lastFailedComparisons),
    .retryCount(sweepEngine_retryCount),
    .finalClockPhase(sweepEngine_finalClockPhase)
  );

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg || sweepEngine_trainError;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    dbg_senderState = senderStateReg;
    dbg_receiverState = receiverStateReg;
    dbg_d2cSenderState = d2cSender_state;
    dbg_d2cReceiverState = d2cReceiver_state;
    dbg_sweepState = sweepEngine_state;
    lastErrorCount = sweepEngine_lastFailedComparisons;
    retryCount = sweepEngine_retryCount;

    flagToAnalog_d2cSender_sendLfsrPattern = running && d2cSender_sendDefinedPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
    flagToAnalog_d2cSender_applyTxClockPhase = running && sweepEngine_applyTxClockPhase;
    flagToAnalog_d2cSender_txClockPhaseCode = sweepEngine_txClockPhaseCode;
    flagToAnalog_d2cSender_applyTxLaneDeskew = running && sweepEngine_applyTxLaneDeskew;
    flagToAnalog_d2cSender_txLaneDeskewCodes = sweepEngine_txLaneDeskewCodes;
    flagToAnalog_d2cReceiver_configureTxInitD2CPointTest = flagToAnalog_d2cReceiver_configureAnalogPulse;
    flagToAnalog_d2cReceiver_maximumComparisonErrorThreshold = d2c_maximumComparisonErrorThresholdReg;
    flagToAnalog_d2cReceiver_comparisonMode = d2c_comparisonModeReg;
    flagToAnalog_d2cReceiver_iterationCountSettings = d2c_iterationCountSettingsReg;
    flagToAnalog_d2cReceiver_idleCountSettings = d2c_idleCountSettingsReg;
    flagToAnalog_d2cReceiver_burstCountSettings = d2c_burstCountSettingsReg;
    flagToAnalog_d2cReceiver_patternMode = d2c_patternModeReg;
    flagToAnalog_d2cReceiver_clockPhaseControl = d2c_clockPhaseControlReg;
    flagToAnalog_d2cReceiver_validPattern = d2c_validPatternReg;
    flagToAnalog_d2cReceiver_dataPattern = d2c_dataPatternReg;
    flagToAnalog_d2cReceiver_resetLocalRxScrambler = running && d2cReceiver_resetLocalRxScrambler;
  end

  // Combinational local pulses and the source's pulse-style registered TX selector.
  always_comb begin
    sweepEngine_start = running && !startPulse &&
                        (senderStateReg == DataTrainCenter1SenderState_startPointTest);
    d2cSender_start = running && !startPulse &&
                      (senderStateReg == DataTrainCenter1SenderState_waitPointTest) &&
                      sweepEngine_pointTestStart;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    flagToAnalog_d2cReceiver_configureAnalogPulse = running && rxValidRisingEdge && isStartPointTestReq;

    nextSbTxValid = 1'b0;
    nextSbTxDin = 128'b0;
    selectSentDoneResp = 1'b0;
    selectReceiverEndResp = 1'b0;
    selectReceiverResultsResp = 1'b0;
    selectReceiverLfsrResp = 1'b0;
    selectReceiverStartResp = 1'b0;
    selectSentStartResp = 1'b0;
    selectSentDoneReq = 1'b0;
    selectSenderEndReq = 1'b0;
    selectSenderResultsReq = 1'b0;
    selectSenderLfsrReq = 1'b0;
    selectSenderStartReq = 1'b0;
    selectSentStartReq = 1'b0;

    if (!startPulse) begin
      unique case (receiverStateReg)
        DataTrainCenter1ReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == DataTrainCenter1ReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_DONE_RESP;
        nextSbTxValid = 1'b1;
        selectSentDoneResp = 1'b1;
      end
      else if (d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverEndResp = 1'b1;
      end
      else if (d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          d2cReceiver_loggedResultsMsgInfo,
          d2cReceiver_loggedResultsPayload
        );
        nextSbTxValid = 1'b1;
        selectReceiverResultsResp = 1'b1;
      end
      else if (d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverLfsrResp = 1'b1;
      end
      else if (d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        selectReceiverStartResp = 1'b1;
      end
      else if ((receiverStateReg == DataTrainCenter1ReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end

      else if ((senderStateReg == DataTrainCenter1SenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == DataTrainCenter1SenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_DATATRAINCENTER1_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= DataTrainCenter1SenderState_idle;
      receiverStateReg <= DataTrainCenter1ReceiverState_idle;
      running <= 1'b0;
      doneReg <= 1'b0;
      trainErrorReg <= 1'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
      flagReceivedStartResp <= 1'b0;
      flagReceivedDoneResp <= 1'b0;
      flagReceivedStartReq <= 1'b0;
      flagReceivedDoneReq <= 1'b0;
      d2cSender_receivedPointTestStartResp <= 1'b0;
      d2cSender_receivedLfsrClearResp <= 1'b0;
      d2cSender_receivedResultsResp <= 1'b0;
      d2cSender_receivedEndPointTestResp <= 1'b0;
      d2cReceiver_receivedPointTestStartReq <= 1'b0;
      d2cReceiver_receivedLfsrClearReq <= 1'b0;
      d2cReceiver_receivedResultsReq <= 1'b0;
      d2cReceiver_receivedEndPointTestReq <= 1'b0;
      flagSentStartReq <= 1'b0;
      flagSentDoneReq <= 1'b0;
      flagSentStartResp <= 1'b0;
      flagSentDoneResp <= 1'b0;
      d2cSender_sentPointTestStartReq <= 1'b0;
      d2cSender_sentLfsrClearReq <= 1'b0;
      d2cSender_sentResultsReq <= 1'b0;
      d2cSender_sentEndPointTestReq <= 1'b0;
      d2cReceiver_sentPointTestStartResp <= 1'b0;
      d2cReceiver_sentLfsrClearResp <= 1'b0;
      d2cReceiver_sentResultsResp <= 1'b0;
      d2cReceiver_sentEndPointTestResp <= 1'b0;
      logErrorCountReg <= 16'b0;
      retryCountReg <= 16'b0;
      d2cReceiver_loggedResultsMsgInfo <= 16'b0;
      d2cReceiver_loggedResultsPayload <= 64'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;
      d2cSender_resultsLanePassReg <= 64'b0;
      d2cSender_resultsValidPassReg <= 1'b0;
      d2cSender_resultsCumulativePassReg <= 1'b0;

      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;

      if (startPulse) begin
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        senderStateReg <= DataTrainCenter1SenderState_sendStartReq;
        receiverStateReg <= DataTrainCenter1ReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cReceiver_receivedPointTestStartReq <= 1'b0;
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        flagSentStartReq <= 1'b0;
        flagSentDoneReq <= 1'b0;
        flagSentStartResp <= 1'b0;
        flagSentDoneResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
        logErrorCountReg <= 16'b0;
        retryCountReg <= 16'b0;
        d2cReceiver_loggedResultsMsgInfo <= 16'b0;
        d2cReceiver_loggedResultsPayload <= 64'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_DATATRAINCENTER1_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
        else if (isStartPointTestReq) begin
          d2c_maximumComparisonErrorThresholdReg <= sb_rx_dout[55:40];
          d2c_comparisonModeReg <= sb_rx_dout[123];
          d2c_iterationCountSettingsReg <= sb_rx_dout[122:107];
          d2c_idleCountSettingsReg <= sb_rx_dout[106:91];
          d2c_burstCountSettingsReg <= sb_rx_dout[90:75];
          d2c_patternModeReg <= sb_rx_dout[74];
          d2c_clockPhaseControlReg <= sb_rx_dout[73:70];
          d2c_validPatternReg <= sb_rx_dout[69:67];
          d2c_dataPatternReg <= sb_rx_dout[66:64];
          d2cReceiver_receivedPointTestStartReq <= 1'b1;
        end
        else if (sb_rx_dout == START_POINT_TEST_RESP)
          d2cSender_receivedPointTestStartResp <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_REQ)
          d2cReceiver_receivedLfsrClearReq <= 1'b1;
        else if (sb_rx_dout == LFSR_CLEAR_ERROR_RESP)
          d2cSender_receivedLfsrClearResp <= 1'b1;
        else if (sb_rx_dout == TX_INIT_RESULTS_REQ) begin
        d2cReceiver_loggedResultsMsgInfo <= flagFromAnalog_d2cReceiver_txInitD2CResultsMsgInfo;
        d2cReceiver_loggedResultsPayload <= flagFromAnalog_d2cReceiver_txInitD2CResultsPayload;
        d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (isTxInitResultsResp) begin
          d2cSender_receivedResultsResp <= 1'b1;
          d2cSender_resultsLanePassReg <= sb_rx_dout[127:64];
          d2cSender_resultsValidPassReg <= sb_rx_dout[45];
          d2cSender_resultsCumulativePassReg <= sb_rx_dout[44];
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (d2cSender_start) begin
        d2cSender_receivedPointTestStartResp <= 1'b0;
        d2cSender_receivedLfsrClearResp <= 1'b0;
        d2cSender_receivedResultsResp <= 1'b0;
        d2cSender_receivedEndPointTestResp <= 1'b0;
        d2cSender_sentPointTestStartReq <= 1'b0;
        d2cSender_sentLfsrClearReq <= 1'b0;
        d2cSender_sentResultsReq <= 1'b0;
        d2cSender_sentEndPointTestReq <= 1'b0;
        logErrorCountReg <= 16'b0;
        d2cSender_resultsLanePassReg <= 64'b0;
        d2cSender_resultsValidPassReg <= 1'b0;
        d2cSender_resultsCumulativePassReg <= 1'b0;
      end

      // Clear the received Start request only when this wrapper schedules the
      // matching Start response.  d2cReceiver_sentPointTestStartResp is sticky
      // for the rest of the point test; using it here would erase the next
      // phase's newly received Start request before the receiver FSM can restart.
      if (selectReceiverStartResp)
        d2cReceiver_receivedPointTestStartReq <= 1'b0;

      if (d2cReceiver_start) begin
        d2cReceiver_receivedLfsrClearReq <= 1'b0;
        d2cReceiver_receivedResultsReq <= 1'b0;
        d2cReceiver_receivedEndPointTestReq <= 1'b0;
        d2cReceiver_sentPointTestStartResp <= 1'b0;
        d2cReceiver_sentLfsrClearResp <= 1'b0;
        d2cReceiver_sentResultsResp <= 1'b0;
        d2cReceiver_sentEndPointTestResp <= 1'b0;
      end

      if (selectSentDoneResp)
        flagSentDoneResp <= 1'b1;
      if (selectReceiverEndResp)
        d2cReceiver_sentEndPointTestResp <= 1'b1;
      if (selectReceiverResultsResp)
        d2cReceiver_sentResultsResp <= 1'b1;
      if (selectReceiverLfsrResp)
        d2cReceiver_sentLfsrClearResp <= 1'b1;
      if (selectReceiverStartResp)
        d2cReceiver_sentPointTestStartResp <= 1'b1;
      if (selectSentStartResp)
        flagSentStartResp <= 1'b1;
      if (selectSentDoneReq)
        flagSentDoneReq <= 1'b1;
      if (selectSenderEndReq)
        d2cSender_sentEndPointTestReq <= 1'b1;
      if (selectSenderResultsReq)
        d2cSender_sentResultsReq <= 1'b1;
      if (selectSenderLfsrReq)
        d2cSender_sentLfsrClearReq <= 1'b1;
      if (selectSenderStartReq)
        d2cSender_sentPointTestStartReq <= 1'b1;
      if (selectSentStartReq)
        flagSentStartReq <= 1'b1;

      if (!startPulse) begin
        unique case (senderStateReg)
          DataTrainCenter1SenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= DataTrainCenter1SenderState_waitStartResp;
          end
          DataTrainCenter1SenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= DataTrainCenter1SenderState_startPointTest;
          end
          DataTrainCenter1SenderState_startPointTest:
            senderStateReg <= DataTrainCenter1SenderState_waitPointTest;
          DataTrainCenter1SenderState_waitPointTest: begin
            if (sweepEngine_trainError) begin
              trainErrorReg <= 1'b1;
              running <= 1'b0;
              senderStateReg <= DataTrainCenter1SenderState_idle;
              receiverStateReg <= DataTrainCenter1ReceiverState_idle;
            end else if (sweepEngine_done) begin
              senderStateReg <= DataTrainCenter1SenderState_sendDoneReq;
            end
          end
          DataTrainCenter1SenderState_checkErrorLog: begin
            // Retained for state-number compatibility with the original RTL.
            // Retries and error checking now occur inside sweepEngine.
            senderStateReg <= DataTrainCenter1SenderState_waitPointTest;
          end
          DataTrainCenter1SenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= DataTrainCenter1SenderState_waitDoneResp;
          end
          DataTrainCenter1SenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= DataTrainCenter1SenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          DataTrainCenter1ReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_sendStartResp;
          end
          DataTrainCenter1ReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= DataTrainCenter1ReceiverState_runPointTest;
          end
          DataTrainCenter1ReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq;
          end
          DataTrainCenter1ReceiverState_waitDoneReqOrPointTestReq: begin
            if (flagReceivedDoneReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= DataTrainCenter1ReceiverState_runPointTest;
          end
          DataTrainCenter1ReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= DataTrainCenter1ReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == DataTrainCenter1SenderState_finish) &&
            (receiverStateReg == DataTrainCenter1ReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire
