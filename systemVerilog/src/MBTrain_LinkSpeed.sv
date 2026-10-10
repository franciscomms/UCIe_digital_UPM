// SystemVerilog translation of MBTrain_LinkSpeed.scala.
`default_nettype none

module MBTrain_LinkSpeed #(
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
  output var logic         flagToLtsm_phyInRetrain,
  input wire logic         sb_tx_ready,
  output var logic         sb_tx_valid,
  output var logic [127:0] sb_tx_din,
  input wire logic         sb_rx_valid,
  input wire logic [127:0] sb_rx_dout,
  output var logic         flagToAnalog_d2cSender_sendLfsrPattern,
  input wire logic         flagFromAnalog_d2cSender_lfsrPatternSent,
  output var logic         flagToAnalog_d2cSender_resetLocalScrambler,
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
  input wire logic [15:0]  flagFromAnalog_d2cReceiver_laneComparisonSuccessful,
  output var logic [3:0]   dbg_senderState,
  output var logic [2:0]   dbg_receiverState,
  output var logic [3:0]   dbg_d2cSenderState,
  output var logic [3:0]   dbg_d2cReceiverState,
  output var logic [15:0]  lastErrorCount,
  output var logic [15:0]  retryCount
);
  import SidebandMsgGenerator_pkg::*;

  typedef enum logic [3:0] {
    LinkSpeedSenderState_idle = 4'h0,
    LinkSpeedSenderState_sendStartReq = 4'h1,
    LinkSpeedSenderState_waitStartResp = 4'h2,
    LinkSpeedSenderState_startPointTest = 4'h3,
    LinkSpeedSenderState_waitPointTest = 4'h4,
    LinkSpeedSenderState_checkErrorLog = 4'h5,
    LinkSpeedSenderState_sendErrorReq = 4'h6,
    LinkSpeedSenderState_sendDoneReq = 4'h7,
    LinkSpeedSenderState_waitDoneResp = 4'h8,
    LinkSpeedSenderState_finish = 4'h9
  } LinkSpeedSenderState_t;

  typedef enum logic [2:0] {
    LinkSpeedReceiverState_idle = 3'h0,
    LinkSpeedReceiverState_waitStartReq = 3'h1,
    LinkSpeedReceiverState_sendStartResp = 3'h2,
    LinkSpeedReceiverState_runPointTest = 3'h3,
    LinkSpeedReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    LinkSpeedReceiverState_sendDoneResp = 3'h5,
    LinkSpeedReceiverState_finish = 3'h6
  } LinkSpeedReceiverState_t;

  (* keep = "true" *) LinkSpeedSenderState_t senderStateReg;
  (* keep = "true" *) LinkSpeedReceiverState_t receiverStateReg;
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
  (* keep = "true" *) logic [15:0] d2cReceiver_loggedLaneComparisonSuccessful;

  (* keep = "true" *) logic [15:0] d2c_maximumComparisonErrorThresholdReg;
  (* keep = "true" *) logic d2c_comparisonModeReg;
  (* keep = "true" *) logic [15:0] d2c_iterationCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_idleCountSettingsReg;
  (* keep = "true" *) logic [15:0] d2c_burstCountSettingsReg;
  (* keep = "true" *) logic d2c_patternModeReg;
  (* keep = "true" *) logic [3:0] d2c_clockPhaseControlReg;
  (* keep = "true" *) logic [2:0] d2c_validPatternReg;
  (* keep = "true" *) logic [2:0] d2c_dataPatternReg;

  (* keep = "true" *) logic flagReceivedErrorReq;
  (* keep = "true" *) logic flagSentErrorReq;
  (* keep = "true" *) logic phyInRetrainReg;

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
  logic selectSentErrorReq;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBTRAIN_LINKSPEED_START_REQ =
    msgMbtrainLinkSpeedStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_START_RESP =
    msgMbtrainLinkSpeedStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DONE_REQ =
    msgMbtrainLinkSpeedDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DONE_RESP =
    msgMbtrainLinkSpeedDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_ERROR_REQ =
    msgMbtrainLinkSpeedErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] START_POINT_TEST_REQ =
    msgMbtrainStartTxInitD2CPointTestReq(
      ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
      16'd0, 1'b1, 16'd1, 16'd0, 16'd4096,
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

  // Named combinational values retained from the Chisel source.
  wire laneComparisonValid = sb_rx_dout[45];
  wire cumulativeLanePass  = sb_rx_dout[44];
  wire [15:0] txInitD2CResultsMsgInfo = {
    10'b0,
    1'b1,
    (&d2cReceiver_loggedLaneComparisonSuccessful),
    4'b0
  };
  wire [63:0] txInitD2CResultsPayload = {
    48'b0,
    d2cReceiver_loggedLaneComparisonSuccessful
  };

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

  always_comb begin
    busy = running && !doneReg;
    done = doneReg;
    trainError = trainErrorReg;
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    dbg_senderState = senderStateReg;
    dbg_receiverState = receiverStateReg;
    dbg_d2cSenderState = d2cSender_state;
    dbg_d2cReceiverState = d2cReceiver_state;
    lastErrorCount = logErrorCountReg;
    retryCount = retryCountReg;
    flagToLtsm_phyInRetrain = phyInRetrainReg;

    flagToAnalog_d2cSender_sendLfsrPattern = running && d2cSender_sendDefinedPattern;
    flagToAnalog_d2cSender_resetLocalScrambler = running && d2cSender_resetLocalScrambler;
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
    d2cSender_start = 1'b0;
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
    selectSentErrorReq = 1'b0;

    if (!startPulse) begin
      unique case (senderStateReg)
        LinkSpeedSenderState_startPointTest: d2cSender_start = 1'b1;
        default: ;
      endcase
      unique case (receiverStateReg)
        LinkSpeedReceiverState_sendStartResp: begin
          if (flagSentStartResp)
            d2cReceiver_start = 1'b1;
        end
        LinkSpeedReceiverState_waitDoneReqOrPointTestReq: begin
          if (!flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (running && sb_tx_ready && !sbTxValid) begin
      if ((receiverStateReg == LinkSpeedReceiverState_sendDoneResp) && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_RESP;
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
          txInitD2CResultsMsgInfo,
          txInitD2CResultsPayload
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
      else if ((receiverStateReg == LinkSpeedReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_RESP;
        nextSbTxValid = 1'b1;
        selectSentStartResp = 1'b1;
      end
    else if ((senderStateReg == LinkSpeedSenderState_sendErrorReq) && !flagSentErrorReq) begin
      nextSbTxDin = MBTRAIN_LINKSPEED_ERROR_REQ;
      nextSbTxValid = 1'b1;
      selectSentErrorReq = 1'b1;
    end
      else if ((senderStateReg == LinkSpeedSenderState_sendDoneReq) && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_REQ;
        nextSbTxValid = 1'b1;
        selectSentDoneReq = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderEndReq = 1'b1;
        senderSentEndPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        selectSenderResultsReq = 1'b1;
        senderSentResultsPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        selectSenderLfsrReq = 1'b1;
        senderSentLfsrPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        selectSenderStartReq = 1'b1;
        senderSentStartPulse = 1'b1;
      end
      else if ((senderStateReg == LinkSpeedSenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_REQ;
        nextSbTxValid = 1'b1;
        selectSentStartReq = 1'b1;
      end
    end
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      senderStateReg <= LinkSpeedSenderState_idle;
      receiverStateReg <= LinkSpeedReceiverState_idle;
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
      d2cReceiver_loggedLaneComparisonSuccessful <= 16'b0;
      d2c_maximumComparisonErrorThresholdReg <= 16'b0;
      d2c_comparisonModeReg <= 1'b0;
      d2c_iterationCountSettingsReg <= 16'b0;
      d2c_idleCountSettingsReg <= 16'b0;
      d2c_burstCountSettingsReg <= 16'b0;
      d2c_patternModeReg <= 1'b0;
      d2c_clockPhaseControlReg <= 4'b0;
      d2c_validPatternReg <= 3'b0;
      d2c_dataPatternReg <= 3'b0;
      flagReceivedErrorReq <= 1'b0;
      flagSentErrorReq <= 1'b0;
      phyInRetrainReg <= 1'b0;
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
        senderStateReg <= LinkSpeedSenderState_sendStartReq;
        receiverStateReg <= LinkSpeedReceiverState_waitStartReq;
        flagReceivedStartResp <= 1'b0;
        flagReceivedDoneResp <= 1'b0;
        flagReceivedStartReq <= 1'b0;
        flagReceivedDoneReq <= 1'b0;
      flagReceivedErrorReq <= 1'b0;
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
      d2cReceiver_loggedLaneComparisonSuccessful <= 16'b0;
      end

      if (running && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_LINKSPEED_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
      else if (sb_rx_dout == MBTRAIN_LINKSPEED_ERROR_REQ) begin
        flagReceivedErrorReq <= 1'b1;
      end
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
        d2cReceiver_loggedLaneComparisonSuccessful <= flagFromAnalog_d2cReceiver_laneComparisonSuccessful;
        d2cReceiver_receivedResultsReq <= 1'b1;
        end
        else if (((sb_rx_dout[61:56] == TX_INIT_RESULTS_RESP_TEMPLATE[61:56]) &&
         (sb_rx_dout[39:0]  == TX_INIT_RESULTS_RESP_TEMPLATE[39:0]))) begin
        d2cSender_receivedResultsResp <= 1'b1;
        logErrorCountReg <= (laneComparisonValid && cumulativeLanePass) ? 16'd0 : 16'd1;
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
      end

      if (d2cReceiver_sentPointTestStartResp)
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
      if (selectSentErrorReq)
        flagSentErrorReq <= 1'b1;
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
          LinkSpeedSenderState_sendStartReq: begin
            if (flagSentStartReq)
              senderStateReg <= LinkSpeedSenderState_waitStartResp;
          end
          LinkSpeedSenderState_waitStartResp: begin
            if (flagReceivedStartResp)
              senderStateReg <= LinkSpeedSenderState_startPointTest;
          end
          LinkSpeedSenderState_startPointTest:
            senderStateReg <= LinkSpeedSenderState_waitPointTest;
          LinkSpeedSenderState_waitPointTest: begin
            if (d2cSender_done)
              senderStateReg <= LinkSpeedSenderState_checkErrorLog;
          end
          LinkSpeedSenderState_checkErrorLog: begin
            // Source currently forces numberOfErrors to zero until PHY result wiring is completed.
            logErrorCountReg <= 16'd0;
            if (16'd0 > 16'd0) begin
              phyInRetrainReg <= 1'b1;
              senderStateReg <= LinkSpeedSenderState_sendErrorReq;
            end else begin
              senderStateReg <= LinkSpeedSenderState_sendDoneReq;
            end
          end
          LinkSpeedSenderState_sendErrorReq: begin
            if (flagSentErrorReq)
              senderStateReg <= LinkSpeedSenderState_finish;
          end
          LinkSpeedSenderState_sendDoneReq: begin
            if (flagSentDoneReq)
              senderStateReg <= LinkSpeedSenderState_waitDoneResp;
          end
          LinkSpeedSenderState_waitDoneResp: begin
            if (flagReceivedDoneResp)
              senderStateReg <= LinkSpeedSenderState_finish;
          end
          default: ;
        endcase

        unique case (receiverStateReg)
          LinkSpeedReceiverState_waitStartReq: begin
            if (flagReceivedStartReq)
              receiverStateReg <= LinkSpeedReceiverState_sendStartResp;
          end
          LinkSpeedReceiverState_sendStartResp: begin
            if (flagSentStartResp)
              receiverStateReg <= LinkSpeedReceiverState_runPointTest;
          end
          LinkSpeedReceiverState_runPointTest: begin
            if (d2cReceiver_done)
              receiverStateReg <= LinkSpeedReceiverState_waitDoneReqOrPointTestReq;
          end
          LinkSpeedReceiverState_waitDoneReqOrPointTestReq: begin
                        if (flagReceivedErrorReq) begin
              // Source TODO: receiver-side LINKSPEED error-resolution flow is not yet implemented.
              receiverStateReg <= receiverStateReg;
            end else if (flagReceivedDoneReq)
              receiverStateReg <= LinkSpeedReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= LinkSpeedReceiverState_runPointTest;
          end
          LinkSpeedReceiverState_sendDoneResp: begin
            if (flagSentDoneResp)
              receiverStateReg <= LinkSpeedReceiverState_finish;
          end
          default: ;
        endcase

        if ((senderStateReg == LinkSpeedSenderState_finish) &&
            (receiverStateReg == LinkSpeedReceiverState_finish)) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end
      end
    end
  end
endmodule

`default_nettype wire
