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
  // Core-clock cycles per microsecond. Latched on start; zero clamps to one.
  input wire logic [31:0]  cycles_1us,
  output var logic         busy,
  output var logic         done,
  output var logic         trainError,
  // Latched after the required ERROR and exit-to-speed-degrade exchanges.
  // The parent enters SPEEDIDLE, selects the next supported rate, and handles
  // the minimum-rate TRAINERROR case. This stage never changes analog rate.
  output var logic         exitToSpeedDegrade,
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
    LinkSpeedSenderState_finish = 4'h9,
    LinkSpeedSenderState_waitErrorResp = 4'hA
  } LinkSpeedSenderState_t;

  typedef enum logic [2:0] {
    LinkSpeedReceiverState_idle = 3'h0,
    LinkSpeedReceiverState_waitStartReq = 3'h1,
    LinkSpeedReceiverState_sendStartResp = 3'h2,
    LinkSpeedReceiverState_runPointTest = 3'h3,
    LinkSpeedReceiverState_waitDoneReqOrPointTestReq = 3'h4,
    LinkSpeedReceiverState_sendDoneResp = 3'h5,
    LinkSpeedReceiverState_finish = 3'h6,
    LinkSpeedReceiverState_sendErrorResp = 3'h7
  } LinkSpeedReceiverState_t;

  (* keep = "true" *) LinkSpeedSenderState_t senderStateReg;
  (* keep = "true" *) LinkSpeedReceiverState_t receiverStateReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) logic doneReg;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;
  logic [31:0] timeoutCyclesMinusOneReg;
  logic [31:0] timeoutCycleReg;
  logic [12:0] timeoutMicrosecondsReg;

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
  // Split the 16-lane result count across a register boundary. Four parallel
  // four-lane trees are captured with the result; the final two adder levels
  // are evaluated on the following clock before notifying the point-test FSM.
  logic [2:0] resultFailedGroupsReg [0:3];
  logic resultMalformedReg;
  logic resultCountPendingReg;
  wire [3:0] resultFailedLow = {1'b0, resultFailedGroupsReg[0]} +
                              {1'b0, resultFailedGroupsReg[1]};
  wire [3:0] resultFailedHigh = {1'b0, resultFailedGroupsReg[2]} +
                               {1'b0, resultFailedGroupsReg[3]};
  wire [4:0] resultFailedCount = {1'b0, resultFailedLow} +
                                {1'b0, resultFailedHigh};

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
  logic flagReceivedErrorResp;
  logic flagSentErrorResp;
  logic localFailureReg;
  logic degradeExchangeReg;
  logic exitToSpeedDegradeReg;
  logic flagReceivedDegradeReq;
  logic flagSentDegradeReq;
  logic flagReceivedDegradeResp;
  logic flagSentDegradeResp;
  (* keep = "true" *) logic phyInRetrainReg;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  logic nextSbTxValid;
  logic [127:0] nextSbTxDin;
  // Completion flags and point-test pulses describe accepted transfers, not
  // reservation of the output register. The register holds valid/data while
  // the transport applies backpressure.
  typedef enum logic [4:0] {
    TxNone, TxDoneResp, TxReceiverEndResp, TxReceiverResultsResp,
    TxReceiverLfsrResp, TxReceiverStartResp, TxStartResp, TxErrorResp,
    TxErrorReq, TxDoneReq, TxSenderEndReq, TxSenderResultsReq,
    TxSenderLfsrReq, TxSenderStartReq, TxStartReq, TxDegradeReq, TxDegradeResp
  } TxKind_t;
  TxKind_t sbTxKind, nextSbTxKind;

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
  logic selectSentErrorResp;
  logic selectSentDegradeReq;
  logic selectSentDegradeResp;

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
  wire [127:0] MBTRAIN_LINKSPEED_DONE_STALL_RESP =
    msgWithoutPayloadBase(16'hFFFF, 8'hBA, 8'h19, ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_ERROR_REQ =
    msgMbtrainLinkSpeedErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_ERROR_RESP =
    msgMbtrainLinkSpeedErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DEGRADE_REQ =
    msgMbtrainLinkSpeedExitToSpeedDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBTRAIN_LINKSPEED_DEGRADE_RESP =
    msgMbtrainLinkSpeedExitToSpeedDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

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

  wire receivedErrorNow = running && rxValidRisingEdge &&
    (sb_rx_dout == MBTRAIN_LINKSPEED_ERROR_REQ);
  wire errorRequested = flagReceivedErrorReq || receivedErrorNow;
  wire receivedStallNow = running && rxValidRisingEdge && flagSentDoneReq &&
    !localFailureReg && !errorRequested &&
    (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_STALL_RESP);
  wire timeoutMicrosecondTick = timeoutCycleReg == timeoutCyclesMinusOneReg;
  wire stageTimeoutNow = running && !startPulse && !receivedStallNow &&
    timeoutMicrosecondTick && (timeoutMicrosecondsReg == 13'd7999);
  wire receivedDegradeNow = running && rxValidRisingEdge &&
    (sb_rx_dout == MBTRAIN_LINKSPEED_DEGRADE_REQ) &&
    (localFailureReg || errorRequested);
  wire degradeRequested = flagReceivedDegradeReq || receivedDegradeNow;
  wire localPointTestComplete =
    (senderStateReg == LinkSpeedSenderState_checkErrorLog) ||
    (senderStateReg == LinkSpeedSenderState_sendErrorReq) ||
    (senderStateReg == LinkSpeedSenderState_waitErrorResp) ||
    (senderStateReg == LinkSpeedSenderState_sendDoneReq) ||
    (senderStateReg == LinkSpeedSenderState_waitDoneResp) ||
    (senderStateReg == LinkSpeedSenderState_finish);
  wire remotePointTestComplete =
    (receiverStateReg == LinkSpeedReceiverState_waitDoneReqOrPointTestReq) ||
    (receiverStateReg == LinkSpeedReceiverState_sendDoneResp) ||
    (receiverStateReg == LinkSpeedReceiverState_sendErrorResp) ||
    (receiverStateReg == LinkSpeedReceiverState_finish);
  wire errorExchangeComplete = (localFailureReg || errorRequested) &&
    (!localFailureReg || (flagSentErrorReq && flagReceivedErrorResp)) &&
    (!errorRequested || flagSentErrorResp) &&
    localPointTestComplete && remotePointTestComplete;

  // This implementation uses the low 16 lane bits. A passing summary cannot
  // override a failing bitmap, invalid lane-comparison flag, or malformed
  // reserved payload. Keep the observed failure until the stage restarts.
  function automatic logic [2:0] countFailedFour(input logic [3:0] failed);
    logic [1:0] lowPair, highPair;
    begin
      lowPair = {1'b0, failed[0]} + {1'b0, failed[1]};
      highPair = {1'b0, failed[2]} + {1'b0, failed[3]};
      countFailedFour = {1'b0, lowPair} + {1'b0, highPair};
    end
  endfunction

  // Named combinational values retained from the Chisel source.
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
    exitToSpeedDegrade = exitToSpeedDegradeReg;
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

  // Registered ready/valid TX arbiter and point-test handshake pulses.
  always_comb begin
    d2cSender_start = 1'b0;
    d2cReceiver_start = 1'b0;
    senderSentStartPulse = 1'b0;
    senderSentLfsrPulse = 1'b0;
    senderSentResultsPulse = 1'b0;
    senderSentEndPulse = 1'b0;
    flagToAnalog_d2cReceiver_configureAnalogPulse = running && rxValidRisingEdge && isStartPointTestReq;

    nextSbTxValid = sbTxValid;
    nextSbTxDin = sbTxDin;
    nextSbTxKind = sbTxKind;
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
    selectSentErrorResp = 1'b0;
    selectSentDegradeReq = 1'b0;
    selectSentDegradeResp = 1'b0;

    if (running && !startPulse) begin
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
          if (!errorRequested && !flagReceivedDoneReq && d2cReceiver_receivedPointTestStartReq)
            d2cReceiver_start = 1'b1;
        end
        default: ;
      endcase
    end

    if (sbTxValid && sb_tx_ready) begin
      nextSbTxValid = 1'b0;
      nextSbTxDin = 128'd0;
      nextSbTxKind = TxNone;
      unique case (sbTxKind)
        TxDoneResp: selectSentDoneResp = 1'b1;
        TxReceiverEndResp: selectReceiverEndResp = 1'b1;
        TxReceiverResultsResp: selectReceiverResultsResp = 1'b1;
        TxReceiverLfsrResp: selectReceiverLfsrResp = 1'b1;
        TxReceiverStartResp: selectReceiverStartResp = 1'b1;
        TxStartResp: selectSentStartResp = 1'b1;
        TxErrorResp: selectSentErrorResp = 1'b1;
        TxErrorReq: selectSentErrorReq = 1'b1;
        TxDegradeReq: selectSentDegradeReq = 1'b1;
        TxDegradeResp: selectSentDegradeResp = 1'b1;
        TxDoneReq: selectSentDoneReq = 1'b1;
        TxSenderEndReq: begin selectSenderEndReq = 1'b1; senderSentEndPulse = 1'b1; end
        TxSenderResultsReq: begin selectSenderResultsReq = 1'b1; senderSentResultsPulse = 1'b1; end
        TxSenderLfsrReq: begin selectSenderLfsrReq = 1'b1; senderSentLfsrPulse = 1'b1; end
        TxSenderStartReq: begin selectSenderStartReq = 1'b1; senderSentStartPulse = 1'b1; end
        TxStartReq: selectSentStartReq = 1'b1;
        default: ;
      endcase
    end

    // A visible pending packet is never withdrawn under backpressure. An
    // ERROR_REQ suppresses any new DONE traffic after that packet drains.
    if (running && !startPulse && !sbTxValid) begin
      if ((receiverStateReg == LinkSpeedReceiverState_sendErrorResp) &&
          localPointTestComplete && !flagSentErrorResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_ERROR_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxErrorResp;
      end
      else if (degradeExchangeReg && errorExchangeComplete &&
               degradeRequested && !flagSentDegradeResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DEGRADE_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxDegradeResp;
      end
      else if (degradeExchangeReg && errorExchangeComplete &&
               localFailureReg && !flagSentDegradeReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DEGRADE_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxDegradeReq;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_sendDoneResp) &&
               !errorRequested && !localFailureReg && !flagSentDoneResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxDoneResp;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_runPointTest) && d2cReceiver_sendEndTxInitD2CPointTestResp && !d2cReceiver_sentEndPointTestResp) begin
        nextSbTxDin = END_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxReceiverEndResp;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_runPointTest) && d2cReceiver_sendTxInitD2CResultsResp && !d2cReceiver_sentResultsResp) begin
        nextSbTxDin = msgMbtrainTxInitD2CResultsResp(
          ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
          txInitD2CResultsMsgInfo,
          txInitD2CResultsPayload
        );
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxReceiverResultsResp;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_runPointTest) && d2cReceiver_sendLfsrClearErrorResp && !d2cReceiver_sentLfsrClearResp) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxReceiverLfsrResp;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_runPointTest) && d2cReceiver_sendStartTxInitD2CPointTestResp && !d2cReceiver_sentPointTestStartResp) begin
        nextSbTxDin = START_POINT_TEST_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxReceiverStartResp;
      end
      else if ((receiverStateReg == LinkSpeedReceiverState_sendStartResp) && !flagSentStartResp) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_RESP;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxStartResp;
      end
      else if ((senderStateReg == LinkSpeedSenderState_sendErrorReq) && !flagSentErrorReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_ERROR_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxErrorReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_sendDoneReq) && !errorRequested && !flagSentDoneReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_DONE_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxDoneReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendEndTxInitD2CPointTestReq && !d2cSender_sentEndPointTestReq) begin
        nextSbTxDin = END_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxSenderEndReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendTxInitD2CResultsReq && !d2cSender_sentResultsReq) begin
        nextSbTxDin = TX_INIT_RESULTS_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxSenderResultsReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendLfsrClearErrorReq && !d2cSender_sentLfsrClearReq) begin
        nextSbTxDin = LFSR_CLEAR_ERROR_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxSenderLfsrReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_waitPointTest) && d2cSender_sendStartTxInitD2CPointTestReq && !d2cSender_sentPointTestStartReq) begin
        nextSbTxDin = START_POINT_TEST_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxSenderStartReq;
      end
      else if ((senderStateReg == LinkSpeedSenderState_sendStartReq) && !flagSentStartReq) begin
        nextSbTxDin = MBTRAIN_LINKSPEED_START_REQ;
        nextSbTxValid = 1'b1;
        nextSbTxKind = TxStartReq;
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
      timeoutCyclesMinusOneReg <= 32'd0;
      timeoutCycleReg <= 32'd0;
      timeoutMicrosecondsReg <= 13'd0;
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
      for (int groupIndex = 0; groupIndex < 4; groupIndex++)
        resultFailedGroupsReg[groupIndex] <= 3'd0;
      resultMalformedReg <= 1'b0;
      resultCountPendingReg <= 1'b0;
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
      flagReceivedErrorResp <= 1'b0;
      flagSentErrorResp <= 1'b0;
      localFailureReg <= 1'b0;
      degradeExchangeReg <= 1'b0;
      exitToSpeedDegradeReg <= 1'b0;
      flagReceivedDegradeReq <= 1'b0;
      flagSentDegradeReq <= 1'b0;
      flagReceivedDegradeResp <= 1'b0;
      flagSentDegradeResp <= 1'b0;
      phyInRetrainReg <= 1'b0;
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
      sbTxKind <= TxNone;
    end else begin
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= nextSbTxValid;
      sbTxDin <= nextSbTxDin;
      sbTxKind <= nextSbTxKind;

      // UCIe 2.0 section 4.5: each training substate has an 8 ms residency
      // timeout. Nested cycles/us counters avoid a large multiply. A valid
      // DONE stall response restarts the timeout as required by that section.
      if (running && !startPulse) begin
        if (receivedStallNow) begin
          timeoutCycleReg <= 32'd0;
          timeoutMicrosecondsReg <= 13'd0;
        end else if (timeoutMicrosecondTick) begin
          timeoutCycleReg <= 32'd0;
          if (timeoutMicrosecondsReg != 13'd7999)
            timeoutMicrosecondsReg <= timeoutMicrosecondsReg + 13'd1;
        end else begin
          timeoutCycleReg <= timeoutCycleReg + 32'd1;
        end
      end

      if (startPulse) begin
        timeoutCyclesMinusOneReg <= (cycles_1us == 32'd0) ? 32'd0 : cycles_1us - 32'd1;
        timeoutCycleReg <= 32'd0;
        timeoutMicrosecondsReg <= 13'd0;
        running <= 1'b1;
        doneReg <= 1'b0;
        trainErrorReg <= 1'b0;
        phyInRetrainReg <= 1'b0;
        localFailureReg <= 1'b0;
        degradeExchangeReg <= 1'b0;
        exitToSpeedDegradeReg <= 1'b0;
        flagReceivedDegradeReq <= 1'b0;
        flagSentDegradeReq <= 1'b0;
        flagReceivedDegradeResp <= 1'b0;
        flagSentDegradeResp <= 1'b0;
        flagSentErrorReq <= 1'b0;
        flagReceivedErrorResp <= 1'b0;
        flagSentErrorResp <= 1'b0;
        sbTxValid <= 1'b0;
        sbTxDin <= 128'd0;
        sbTxKind <= TxNone;
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
        resultCountPendingReg <= 1'b0;
        resultMalformedReg <= 1'b0;
        d2cReceiver_loggedLaneComparisonSuccessful <= 16'b0;
      end

      if (running && !startPulse && rxValidRisingEdge) begin
        if (sb_rx_dout == MBTRAIN_LINKSPEED_START_RESP)
          flagReceivedStartResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_RESP)
          flagReceivedDoneResp <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_START_REQ)
          flagReceivedStartReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_DONE_REQ)
          flagReceivedDoneReq <= 1'b1;
        else if (sb_rx_dout == MBTRAIN_LINKSPEED_ERROR_REQ)
          flagReceivedErrorReq <= 1'b1;
        else if ((sb_rx_dout == MBTRAIN_LINKSPEED_ERROR_RESP) &&
                 localFailureReg && flagSentErrorReq)
          flagReceivedErrorResp <= 1'b1;
        else if (receivedDegradeNow)
          flagReceivedDegradeReq <= 1'b1;
        else if ((sb_rx_dout == MBTRAIN_LINKSPEED_DEGRADE_RESP) &&
                 localFailureReg && flagSentDegradeReq)
          flagReceivedDegradeResp <= 1'b1;
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
          if (d2cSender_sentResultsReq && !d2cSender_receivedResultsResp &&
              !resultCountPendingReg) begin
            for (int groupIndex = 0; groupIndex < 4; groupIndex++)
              resultFailedGroupsReg[groupIndex] <=
                countFailedFour(~sb_rx_dout[64 + 4*groupIndex +: 4]);
            resultMalformedReg <= !sb_rx_dout[45] || !sb_rx_dout[44] ||
                                  (sb_rx_dout[127:80] != 48'd0);
            resultCountPendingReg <= 1'b1;
          end
        end
        else if (sb_rx_dout == END_POINT_TEST_REQ)
          d2cReceiver_receivedEndPointTestReq <= 1'b1;
        else if (sb_rx_dout == END_POINT_TEST_RESP)
          d2cSender_receivedEndPointTestResp <= 1'b1;
      end

      if (running && !startPulse && resultCountPendingReg) begin
        logErrorCountReg <= (resultMalformedReg && (resultFailedCount == 5'd0))
                         ? 16'd1 : {11'd0, resultFailedCount};
        d2cSender_receivedResultsResp <= 1'b1;
        resultCountPendingReg <= 1'b0;
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
        resultCountPendingReg <= 1'b0;
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
      if (selectSentErrorResp)
        flagSentErrorResp <= 1'b1;
      if (selectSentDegradeReq)
        flagSentDegradeReq <= 1'b1;
      if (selectSentDegradeResp)
        flagSentDegradeResp <= 1'b1;
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

      if (running && !startPulse) begin
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
            if (logErrorCountReg != 16'd0) begin
              localFailureReg <= 1'b1;
              senderStateReg <= LinkSpeedSenderState_sendErrorReq;
            end else if (errorRequested) begin
              senderStateReg <= LinkSpeedSenderState_finish;
            end else begin
              senderStateReg <= LinkSpeedSenderState_sendDoneReq;
            end
          end
          LinkSpeedSenderState_sendErrorReq: begin
            if (flagSentErrorReq)
              senderStateReg <= LinkSpeedSenderState_waitErrorResp;
          end
          LinkSpeedSenderState_waitErrorResp: begin
            if (flagReceivedErrorResp)
              senderStateReg <= LinkSpeedSenderState_finish;
          end
          LinkSpeedSenderState_sendDoneReq: begin
            if (errorRequested)
              senderStateReg <= LinkSpeedSenderState_finish;
            else if (flagSentDoneReq)
              senderStateReg <= LinkSpeedSenderState_waitDoneResp;
          end
          LinkSpeedSenderState_waitDoneResp: begin
            if (errorRequested || flagReceivedDoneResp)
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
            if (errorRequested) begin
              receiverStateReg <= LinkSpeedReceiverState_sendErrorResp;
            end else if (flagReceivedDoneReq)
              receiverStateReg <= LinkSpeedReceiverState_sendDoneResp;
            else if (d2cReceiver_receivedPointTestStartReq)
              receiverStateReg <= LinkSpeedReceiverState_runPointTest;
          end
          LinkSpeedReceiverState_sendDoneResp: begin
            if (errorRequested)
              receiverStateReg <= LinkSpeedReceiverState_sendErrorResp;
            else if (flagSentDoneResp)
              receiverStateReg <= LinkSpeedReceiverState_finish;
          end
          LinkSpeedReceiverState_finish: begin
            if (errorRequested && !flagSentErrorResp)
              receiverStateReg <= LinkSpeedReceiverState_sendErrorResp;
          end
          LinkSpeedReceiverState_sendErrorResp: begin
            if (flagSentErrorResp)
              receiverStateReg <= LinkSpeedReceiverState_finish;
          end
          default: ;
        endcase

        if (!localFailureReg && !errorRequested &&
            (senderStateReg == LinkSpeedSenderState_finish) &&
            (receiverStateReg == LinkSpeedReceiverState_finish) && !sbTxValid) begin
          doneReg <= 1'b1;
          running <= 1'b0;
        end

        // This profile has no repair/width-degrade engine, so use the separate
        // UCIe 2.0 LINKSPEED exit-to-speed-degrade handshake after ERROR.
        // Only a locally failing transmitter initiates a request. A peer that
        // only sees remote failure responds; simultaneous failures retain both
        // obligations. Do not demand a gratuitous request from a passing peer.
        if (errorExchangeComplete && !sbTxValid)
          degradeExchangeReg <= 1'b1;

        if (degradeExchangeReg && errorExchangeComplete &&
            (!localFailureReg || (flagSentDegradeReq && flagReceivedDegradeResp)) &&
            (!errorRequested || flagReceivedDegradeReq) &&
            (!degradeRequested || flagSentDegradeResp) &&
            (localFailureReg || flagReceivedDegradeReq) && !sbTxValid) begin
          exitToSpeedDegradeReg <= 1'b1;
          trainErrorReg <= 1'b0;
          phyInRetrainReg <= 1'b0;
          doneReg <= 1'b0;
          running <= 1'b0;
          senderStateReg <= LinkSpeedSenderState_finish;
          receiverStateReg <= LinkSpeedReceiverState_finish;
        end
      end

      // A timed-out peer or transport must not keep this stage busy forever.
      // Abort its pending local TX reservation, report failure, and let the
      // parent perform TRAINERROR entry. Already accepted wire traffic belongs
      // to the sideband transport and is not altered here.
      if (stageTimeoutNow) begin
        trainErrorReg <= 1'b1;
        exitToSpeedDegradeReg <= 1'b0;
        phyInRetrainReg <= 1'b0;
        doneReg <= 1'b0;
        running <= 1'b0;
        sbTxValid <= 1'b0;
        sbTxDin <= 128'd0;
        sbTxKind <= TxNone;
        resultCountPendingReg <= 1'b0;
        senderStateReg <= LinkSpeedSenderState_finish;
        receiverStateReg <= LinkSpeedReceiverState_finish;
      end
    end
  end
endmodule

`default_nettype wire
