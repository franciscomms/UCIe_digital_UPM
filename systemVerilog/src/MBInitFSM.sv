// SystemVerilog translation of MBInitFSM.scala.
`default_nettype none

module MBInitFSM #(
  parameter bit sbFeatureExtension = LtsmParameters_pkg::DEFAULT_SB_FEATURE_EXTENSION,
  parameter bit ucieA               = LtsmParameters_pkg::DEFAULT_UCIE_A,
  parameter logic [1:0] moduleID    = LtsmParameters_pkg::DEFAULT_MODULE_ID,
  parameter bit clkPhase            = LtsmParameters_pkg::DEFAULT_CLK_PHASE,
  parameter bit clkMode             = LtsmParameters_pkg::DEFAULT_CLK_MODE,
  parameter logic [4:0] voltageSwing = LtsmParameters_pkg::DEFAULT_VOLTAGE_SWING,
  parameter logic [3:0] maxLinkSpeed = LtsmParameters_pkg::DEFAULT_MAX_LINK_SPEED
) (
  input wire logic clock,
  input wire logic reset_n,
  input wire logic           start,
  output var logic           busy,
  output var logic           done,
  output var logic           trainError,
  output var logic [127:0]   sb_tx_din,
  output var logic           sb_tx_valid,
  input wire logic           sb_tx_ready,
  input wire logic [127:0]   sb_rx_dout,
  input wire logic           sb_rx_valid,
  input wire logic           flagFromAnalog_ReadyToExchangeClkPatterns,
  input wire logic           flagFromAnalog_FinishedClkPatterns,
  input wire logic           flagFromAnalog_FinishedValTrainPattern,
  input wire logic           flagFromAnalog_clkPatternReceivedRTRK_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKN_L,
  input wire logic           flagFromAnalog_clkPatternReceivedRCKP_L,
  input wire logic           flagFromAnalog_ValTrainPatternReceived,
  input wire logic           flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived0,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived1,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived2,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived3,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived4,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived5,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived6,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived7,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived8,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived9,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived10,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived11,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived12,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived13,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived14,
  input wire logic           flagFromAnalog_ReversalMbTrainPatternReceived15,
  input wire logic           flagFromAnalog_RepairMbFinishedLaneIDPattern,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern0,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern1,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern2,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern3,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern4,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern5,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern6,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern7,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern8,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern9,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern10,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern11,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern12,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern13,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern14,
  input wire logic           flagFromAnalog_RepairMbDetectedLaneIDPattern15,
  output var logic           flagToAnalog_RepairClkState,
  output var logic           flagToAnalog_SendClkPatterns,
  output var logic           flagToAnalog_RepairValState,
  output var logic           flagToAnalog_SendValTrainPattern,
  output var logic           flagToAnalog_RepairMbSendLaneIDPattern,
  output var logic           flagToAnalog_RepairMbSetReceiver,
  output var logic           flagToAnalog_ReversalMbSendLaneIDPattern,
  output var logic           flagToAnalog_LaneReversalApplied,
  output var logic [2:0]     substate,
  output var logic [2:0]     dbg_mbinitRepairClkSenderState,
  output var logic [2:0]     dbg_mbinitRepairClkReceiverState,
  output var logic [2:0]     dbg_mbinitRepairValSenderState,
  output var logic [2:0]     dbg_mbinitRepairValReceiverState,
  output var logic [4:0]     dbg_mbinitReversalMbReceivedSuccessCount
);
  import SidebandMsgGenerator_pkg::*;

  // Portable synthesizable replacement for SystemVerilog $countones.
  function automatic logic [4:0] countOnes16(input logic [15:0] value);
    integer bit_index;
    begin
      countOnes16 = 5'd0;
      for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1)
        countOnes16 = countOnes16 + value[bit_index];
    end
  endfunction

  typedef enum logic [2:0] {
    MBInitState_PARAM = 3'd0,
    MBInitState_CAL = 3'd1,
    MBInitState_REPAIRCLK = 3'd2,
    MBInitState_REPAIRVAL = 3'd3,
    MBInitState_REVERSALMB = 3'd4,
    MBInitState_REPAIRMB = 3'd5,
    MBInitState_DONE = 3'd6
  } MBInitState_t;

  typedef enum logic [1:0] {
    ParamSenderState_sendReqHeader = 2'd0,
    ParamSenderState_waitResp = 2'd1,
    ParamSenderState_finish = 2'd2
  } ParamSenderState_t;

  typedef enum logic [1:0] {
    ParamReceiverState_waitReq = 2'd0,
    ParamReceiverState_validateReqPayload = 2'd1,
    ParamReceiverState_sendRespHeader = 2'd2,
    ParamReceiverState_finish = 2'd3
  } ParamReceiverState_t;

  typedef enum logic [1:0] {
    CalSenderState_sendDoneReq = 2'd0,
    CalSenderState_waitDoneResp = 2'd1,
    CalSenderState_finish = 2'd2
  } CalSenderState_t;

  typedef enum logic [1:0] {
    CalReceiverState_waitDoneReq = 2'd0,
    CalReceiverState_sendDoneResp = 2'd1,
    CalReceiverState_finish = 2'd2
  } CalReceiverState_t;

  typedef enum logic [2:0] {
    RepairClkSenderState_initReq = 3'd0,
    RepairClkSenderState_sendClkPatternsExchange = 3'd1,
    RepairClkSenderState_waitingPatternsExchangeFinish = 3'd2,
    RepairClkSenderState_sendResultReq = 3'd3,
    RepairClkSenderState_receiveResultResp = 3'd4,
    RepairClkSenderState_sendDoneReq = 3'd5,
    RepairClkSenderState_receiveDoneResp = 3'd6,
    RepairClkSenderState_finish = 3'd7
  } RepairClkSenderState_t;

  typedef enum logic [2:0] {
    RepairClkReceiverState_sendInitResp = 3'd0,
    RepairClkReceiverState_waitingPatternsExchangeFinish = 3'd1,
    RepairClkReceiverState_sendResultResp = 3'd2,
    RepairClkReceiverState_receiveDoneReq = 3'd3,
    RepairClkReceiverState_sendDoneResp = 3'd4,
    RepairClkReceiverState_finish = 3'd5
  } RepairClkReceiverState_t;

  typedef enum logic [2:0] {
    RepairValSenderState_initReq = 3'd0,
    RepairValSenderState_sendValTrainPattern = 3'd1,
    RepairValSenderState_waitingValTrainPatternFinish = 3'd2,
    RepairValSenderState_sendResultReq = 3'd3,
    RepairValSenderState_receiveResultResp = 3'd4,
    RepairValSenderState_sendDoneReq = 3'd5,
    RepairValSenderState_receiveDoneResp = 3'd6,
    RepairValSenderState_finish = 3'd7
  } RepairValSenderState_t;

  typedef enum logic [2:0] {
    RepairValReceiverState_sendInitResp = 3'd0,
    RepairValReceiverState_waitingValTrainPatternFinish = 3'd1,
    RepairValReceiverState_sendResultResp = 3'd2,
    RepairValReceiverState_receiveDoneReq = 3'd3,
    RepairValReceiverState_sendDoneResp = 3'd4,
    RepairValReceiverState_finish = 3'd5
  } RepairValReceiverState_t;

  typedef enum logic [3:0] {
    ReversalMbSenderState_initReq = 4'd0,
    ReversalMbSenderState_waitInitResp = 4'd1,
    ReversalMbSenderState_sendClearErrorReq = 4'd2,
    ReversalMbSenderState_waitClearErrorResp = 4'd3,
    ReversalMbSenderState_sendLaneIDPattern = 4'd4,
    ReversalMbSenderState_waitingLaneIDPatternFinish = 4'd5,
    ReversalMbSenderState_sendResultReq = 4'd6,
    ReversalMbSenderState_waitResultResp = 4'd7,
    ReversalMbSenderState_sendDoneReq = 4'd8,
    ReversalMbSenderState_waitDoneResp = 4'd9,
    ReversalMbSenderState_finish = 4'd10
  } ReversalMbSenderState_t;

  typedef enum logic [2:0] {
    ReversalMbReceiverState_sendInitResp = 3'd0,
    ReversalMbReceiverState_waitClearErrorReq = 3'd1,
    ReversalMbReceiverState_sendClearErrorResp = 3'd2,
    ReversalMbReceiverState_waitResultReq = 3'd3,
    ReversalMbReceiverState_sendResultResp = 3'd4,
    ReversalMbReceiverState_waitDoneReqOrClearErrorReq = 3'd5,
    ReversalMbReceiverState_sendDoneResp = 3'd6,
    ReversalMbReceiverState_finish = 3'd7
  } ReversalMbReceiverState_t;

  typedef enum logic [4:0] {
    RepairMbSenderState_sendStartReq = 5'd0,
    RepairMbSenderState_waitStartResp = 5'd1,
    RepairMbSenderState_d2cPointTestSendReq = 5'd2,
    RepairMbSenderState_d2cPointTestWaitResp = 5'd3,
    RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq = 5'd4,
    RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp = 5'd5,
    RepairMbSenderState_sendLaneIDPattern = 5'd6,
    RepairMbSenderState_waitingLaneIDPatternFinish = 5'd7,
    RepairMbSenderState_txInitD2CResultsSendReq = 5'd8,
    RepairMbSenderState_txInitD2CResultsWaitResp = 5'd9,
    RepairMbSenderState_endTxInitD2CPointTestSendReq = 5'd10,
    RepairMbSenderState_endTxInitD2CPointTestWaitResp = 5'd11,
    RepairMbSenderState_analyzeWidthDegradation = 5'd12,
    RepairMbSenderState_sendApplyDegradeReq = 5'd13,
    RepairMbSenderState_waitApplyDegradeResp = 5'd14,
    RepairMbSenderState_sendEndReq = 5'd15,
    RepairMbSenderState_waitEndResp = 5'd16,
    RepairMbSenderState_finish = 5'd17
  } RepairMbSenderState_t;

  typedef enum logic [3:0] {
    RepairMbReceiverState_waitStartReq = 4'd0,
    RepairMbReceiverState_sendStartResp = 4'd1,
    RepairMbReceiverState_waitD2CPointTestReq = 4'd2,
    RepairMbReceiverState_setReceiver = 4'd3,
    RepairMbReceiverState_sendD2CPointTestResp = 4'd4,
    RepairMbReceiverState_waitLfsrClearErrorReq = 4'd5,
    RepairMbReceiverState_sendLfsrClearErrorResp = 4'd6,
    RepairMbReceiverState_waitTxInitD2CResultsReq = 4'd7,
    RepairMbReceiverState_sendTxInitD2CResultsResp = 4'd8,
    RepairMbReceiverState_waitEndTxInitD2CPointTestReq = 4'd9,
    RepairMbReceiverState_sendEndTxInitD2CPointTestResp = 4'd10,
    RepairMbReceiverState_waitApplyDegradeReq = 4'd11,
    RepairMbReceiverState_sendApplyDegradeResp = 4'd12,
    RepairMbReceiverState_waitEndReq = 4'd13,
    RepairMbReceiverState_sendEndResp = 4'd14,
    RepairMbReceiverState_finish = 4'd15
  } RepairMbReceiverState_t;

  (* keep = "true" *) logic sbTxValid;
  (* keep = "true" *) logic [127:0] sbTxDin;
  (* keep = "true" *) logic trainErrorReg;
  (* keep = "true" *) logic running;
  (* keep = "true" *) MBInitState_t stateReg;
  (* keep = "true" *) logic flagMbinitParam_ReceivedReqHeader;
  (* keep = "true" *) logic flagMbinitParam_ReceivedReqPayload;
  (* keep = "true" *) logic flagMbinitParam_SentReq;
  (* keep = "true" *) logic flagMbinitParam_ReceivedRespHeader;
  (* keep = "true" *) logic flagMbinitParam_ReceivedRespPayload;
  (* keep = "true" *) logic flagMbinitParam_SentResp;
  (* keep = "true" *) logic flagMbinitParam_SendReq;
  (* keep = "true" *) logic flagMbinitParam_SendResp;
  (* keep = "true" *) logic flagMbinitParam_ReceivedCorrectReq;
  (* keep = "true" *) ParamSenderState_t paramSenderStateReg;
  (* keep = "true" *) ParamReceiverState_t paramReceiverStateReg;
  (* keep = "true" *) logic flagMbinitCal_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitCal_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitCal_SentDoneReq;
  (* keep = "true" *) logic flagMbinitCal_SentDoneResp;
  (* keep = "true" *) logic flagMbinitCal_SendDoneReq;
  (* keep = "true" *) logic flagMbinitCal_SendDoneResp;
  (* keep = "true" *) CalSenderState_t calSenderStateReg;
  (* keep = "true" *) CalReceiverState_t calReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitRepairClk_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SentInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SentResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SentDoneResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendInitReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendResultReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendDoneReq;
  (* keep = "true" *) logic flagMbinitRepairClk_SendInitResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendResultResp;
  (* keep = "true" *) logic flagMbinitRepairClk_SendDoneResp;
  (* keep = "true" *) logic [2:0] mbinitRepairClk_ReceivedResultBits;
  (* keep = "true" *) RepairClkSenderState_t repairClkSenderStateReg;
  (* keep = "true" *) RepairClkReceiverState_t repairClkReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairVal_SentInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SentInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SentResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SentDoneResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitRepairVal_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendInitReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendResultReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendDoneReq;
  (* keep = "true" *) logic flagMbinitRepairVal_SendInitResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SendResultResp;
  (* keep = "true" *) logic flagMbinitRepairVal_SendDoneResp;
  (* keep = "true" *) logic mbinitRepairVal_ReceivedResultBit;
  (* keep = "true" *) logic mbinitRepairVal_logValTrainPatternReceived;
  (* keep = "true" *) RepairValSenderState_t repairValSenderStateReg;
  (* keep = "true" *) RepairValReceiverState_t repairValReceiverStateReg;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultRespHeader;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedResultRespPayload;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_ReceivedDoneResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SendInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendResultResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SendDoneResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentInitReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentClearErrorReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentResultReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentDoneReq;
  (* keep = "true" *) logic flagMbinitReversalMb_SentInitResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentClearErrorResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentResultResp;
  (* keep = "true" *) logic flagMbinitReversalMb_SentDoneResp;
  (* keep = "true" *) ReversalMbSenderState_t reversalMbSenderStateReg;
  (* keep = "true" *) ReversalMbReceiverState_t reversalMbReceiverStateReg;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestReqHeader;
  (* keep = "true" *) logic flagMbinitRepairMb_D2CPointTestReqWaitingPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestReqPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedApplyDegradeReq;
  (* keep = "true" *) logic [2:0] mbinitRepairMb_ReceivedApplyDegradeReqLaneMap;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_ReceivedEndResp;
  (* keep = "true" *) logic flagMbinitRepairMb_ApplyWidthDegradation;
  (* keep = "true" *) logic [15:0] mbinitRepairMb_TxInitD2CResultsRespMsgInfo;
  (* keep = "true" *) logic [63:0] mbinitRepairMb_TxInitD2CResultsRespPayload;
  (* keep = "true" *) logic [15:0] mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits;
  (* keep = "true" *) logic flagMbinitRepairMb_SendStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendApplyDegradeReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SendStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendTxInitD2CResultsResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SendEndResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentStartReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentLfsrClearErrorReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentTxInitD2CResultsReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndTxInitD2CPointTestReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentApplyDegradeReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndReq;
  (* keep = "true" *) logic flagMbinitRepairMb_SentStartResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentLfsrClearErrorResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentTxInitD2CResultsResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndTxInitD2CPointTestResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentApplyDegradeResp;
  (* keep = "true" *) logic flagMbinitRepairMb_SentEndResp;
  (* keep = "true" *) RepairMbSenderState_t repairMbSenderStateReg;
  (* keep = "true" *) RepairMbReceiverState_t repairMbReceiverStateReg;
  (* keep = "true" *) logic [15:0] repairMb_DetectedLaneIDPatternLog;
  (* keep = "true" *) logic [15:0] reversalMbLaneStatusLog;
  (* keep = "true" *) logic reversalMb_LaneReversalApplied;
  (* keep = "true" *) logic [4:0] reversalMb_ReceivedSuccessCount;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRTRK_L;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRCKN_L;
  (* keep = "true" *) logic mbinitRepairClk_logClkPatternReceivedRCKP_L;
  (* keep = "true" *) logic [63:0] remoteParamReqPayload;
  (* keep = "true" *) logic [63:0] remoteParamRespPayload;
  (* keep = "true" *) logic prevStart;
  (* keep = "true" *) logic prevRxValid;

  wire startPulse = start && !prevStart;
  wire rxValidRisingEdge = sb_rx_valid && !prevRxValid;

  wire [127:0] MBINIT_PARAM_REQ = msgMbinitParamConfigReq(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, sbFeatureExtension, ucieA, moduleID,
    clkPhase, clkMode, voltageSwing, maxLinkSpeed);
  wire [127:0] MBINIT_PARAM_RESP = msgMbinitParamConfigResp(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, clkPhase, clkMode, maxLinkSpeed);
  wire [127:0] MBINIT_CAL_DONE_REQ = msgMbinitCalDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_CAL_DONE_RESP = msgMbinitCalDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRCLK_INIT_REQ = msgMbinitRepairClkInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_INIT_RESP = msgMbinitRepairClkInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_RESULT_REQ = msgMbinitRepairClkResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_RESULT_RESP = msgMbinitRepairClkResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 1'b0, 1'b0, 1'b0);
  wire [127:0] MBINIT_REPAIRCLK_DONE_REQ = msgMbinitRepairClkDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRCLK_DONE_RESP = msgMbinitRepairClkDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRVAL_INIT_REQ = msgMbinitRepairValInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_INIT_RESP = msgMbinitRepairValInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_RESULT_REQ = msgMbinitRepairValResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_RESULT_RESP = msgMbinitRepairValResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 1'b0);
  wire [127:0] MBINIT_REPAIRVAL_DONE_REQ = msgMbinitRepairValDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRVAL_DONE_RESP = msgMbinitRepairValDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REVERSALMB_INIT_REQ = msgMbinitReversalMbInitReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_INIT_RESP = msgMbinitReversalMbInitResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_CLEAR_ERROR_REQ = msgMbinitReversalMbClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_CLEAR_ERROR_RESP = msgMbinitReversalMbClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_RESULT_REQ = msgMbinitReversalMbResultReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_RESULT_RESP = msgMbinitReversalMbResultResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0);
  wire [127:0] MBINIT_REVERSALMB_DONE_REQ = msgMbinitReversalMbDoneReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REVERSALMB_DONE_RESP = msgMbinitReversalMbDoneResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  wire [127:0] MBINIT_REPAIRMB_START_REQ = msgMbinitRepairMbStartReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_START_RESP = msgMbinitRepairMbStartResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_D2C_POINT_TEST_REQ = msgMbinitRepairMbStartTxInitD2CPointTestReq(
    ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0, 1'b0, 16'h0080, 16'b0,
    16'b0, 1'b0, 4'b0, 3'b0, 3'b001);
  wire [127:0] MBINIT_REPAIRMB_D2C_POINT_TEST_RESP = msgMbinitRepairMbStartTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ = msgMbinitRepairMbLfsrClearErrorReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP = msgMbinitRepairMbLfsrClearErrorResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ = msgMbinitRepairMbTxInitD2CResultsReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP = msgMbinitRepairMbTxInitD2CResultsResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'b0, 64'b0);
  wire [127:0] MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ = msgMbinitRepairMbEndTxInitD2CPointTestReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP = msgMbinitRepairMbEndTxInitD2CPointTestResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_APPLY_DEGRADE_REQ_TEMPLATE = msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b000);
  wire [127:0] MBINIT_REPAIRMB_APPLY_DEGRADE_RESP = msgMbinitRepairMbApplyDegradeResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_REQ = msgMbinitRepairMbEndReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
  wire [127:0] MBINIT_REPAIRMB_END_RESP = msgMbinitRepairMbEndResp(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);

  always_comb begin
    sb_tx_valid = sbTxValid;
    sb_tx_din = sbTxDin;
    trainError = trainErrorReg;
    done = running && (stateReg == MBInitState_DONE);
    busy = running && (stateReg != MBInitState_DONE);

    flagToAnalog_RepairClkState = running && (stateReg == MBInitState_REPAIRCLK);
    flagToAnalog_SendClkPatterns = running &&
      (stateReg == MBInitState_REPAIRCLK) &&
      (repairClkSenderStateReg == RepairClkSenderState_sendClkPatternsExchange) &&
      flagMbinitRepairClk_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns;
    flagToAnalog_RepairValState = running && (stateReg == MBInitState_REPAIRVAL);
    flagToAnalog_SendValTrainPattern = running &&
      (stateReg == MBInitState_REPAIRVAL) &&
      (repairValSenderStateReg == RepairValSenderState_sendValTrainPattern) &&
      flagMbinitRepairVal_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns;
    flagToAnalog_ReversalMbSendLaneIDPattern = running &&
      (stateReg == MBInitState_REVERSALMB) &&
      (reversalMbSenderStateReg == ReversalMbSenderState_sendLaneIDPattern);
    flagToAnalog_RepairMbSendLaneIDPattern = running &&
      (stateReg == MBInitState_REPAIRMB) &&
      (repairMbSenderStateReg == RepairMbSenderState_sendLaneIDPattern);
    flagToAnalog_RepairMbSetReceiver = running &&
      (stateReg == MBInitState_REPAIRMB) &&
      (repairMbReceiverStateReg == RepairMbReceiverState_setReceiver);
    flagToAnalog_LaneReversalApplied = reversalMb_LaneReversalApplied;

    substate = stateReg;
    dbg_mbinitRepairClkSenderState = repairClkSenderStateReg;
    dbg_mbinitRepairClkReceiverState = repairClkReceiverStateReg;
    dbg_mbinitRepairValSenderState = repairValSenderStateReg;
    dbg_mbinitRepairValReceiverState = repairValReceiverStateReg;
    dbg_mbinitReversalMbReceivedSuccessCount = reversalMb_ReceivedSuccessCount;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;
      trainErrorReg <= 1'b0;
      running <= 1'b0;
      stateReg <= MBInitState_PARAM;
      flagMbinitParam_ReceivedReqHeader <= 1'b0;
      flagMbinitParam_ReceivedReqPayload <= 1'b0;
      flagMbinitParam_SentReq <= 1'b0;
      flagMbinitParam_ReceivedRespHeader <= 1'b0;
      flagMbinitParam_ReceivedRespPayload <= 1'b0;
      flagMbinitParam_SentResp <= 1'b0;
      flagMbinitParam_SendReq <= 1'b0;
      flagMbinitParam_SendResp <= 1'b0;
      flagMbinitParam_ReceivedCorrectReq <= 1'b0;
      paramSenderStateReg <= ParamSenderState_sendReqHeader;
      paramReceiverStateReg <= ParamReceiverState_waitReq;
      flagMbinitCal_ReceivedDoneReq <= 1'b0;
      flagMbinitCal_ReceivedDoneResp <= 1'b0;
      flagMbinitCal_SentDoneReq <= 1'b0;
      flagMbinitCal_SentDoneResp <= 1'b0;
      flagMbinitCal_SendDoneReq <= 1'b0;
      flagMbinitCal_SendDoneResp <= 1'b0;
      calSenderStateReg <= CalSenderState_sendDoneReq;
      calReceiverStateReg <= CalReceiverState_waitDoneReq;
      flagMbinitRepairClk_ReceivedInitResp <= 1'b0;
      flagMbinitRepairClk_ReceivedInitReq <= 1'b0;
      flagMbinitRepairClk_ReceivedResultResp <= 1'b0;
      flagMbinitRepairClk_ReceivedResultReq <= 1'b0;
      flagMbinitRepairClk_ReceivedDoneResp <= 1'b0;
      flagMbinitRepairClk_ReceivedDoneReq <= 1'b0;
      flagMbinitRepairClk_SentInitReq <= 1'b0;
      flagMbinitRepairClk_SentResultReq <= 1'b0;
      flagMbinitRepairClk_SentDoneReq <= 1'b0;
      flagMbinitRepairClk_SentInitResp <= 1'b0;
      flagMbinitRepairClk_SentResultResp <= 1'b0;
      flagMbinitRepairClk_SentDoneResp <= 1'b0;
      flagMbinitRepairClk_SendInitReq <= 1'b0;
      flagMbinitRepairClk_SendResultReq <= 1'b0;
      flagMbinitRepairClk_SendDoneReq <= 1'b0;
      flagMbinitRepairClk_SendInitResp <= 1'b0;
      flagMbinitRepairClk_SendResultResp <= 1'b0;
      flagMbinitRepairClk_SendDoneResp <= 1'b0;
      mbinitRepairClk_ReceivedResultBits <= 3'b0;
      repairClkSenderStateReg <= RepairClkSenderState_initReq;
      repairClkReceiverStateReg <= RepairClkReceiverState_sendInitResp;
      flagMbinitRepairVal_SentInitReq <= 1'b0;
      flagMbinitRepairVal_SentResultReq <= 1'b0;
      flagMbinitRepairVal_SentDoneReq <= 1'b0;
      flagMbinitRepairVal_SentInitResp <= 1'b0;
      flagMbinitRepairVal_SentResultResp <= 1'b0;
      flagMbinitRepairVal_SentDoneResp <= 1'b0;
      flagMbinitRepairVal_ReceivedInitResp <= 1'b0;
      flagMbinitRepairVal_ReceivedInitReq <= 1'b0;
      flagMbinitRepairVal_ReceivedResultResp <= 1'b0;
      flagMbinitRepairVal_ReceivedResultReq <= 1'b0;
      flagMbinitRepairVal_ReceivedDoneResp <= 1'b0;
      flagMbinitRepairVal_ReceivedDoneReq <= 1'b0;
      flagMbinitRepairVal_SendInitReq <= 1'b0;
      flagMbinitRepairVal_SendResultReq <= 1'b0;
      flagMbinitRepairVal_SendDoneReq <= 1'b0;
      flagMbinitRepairVal_SendInitResp <= 1'b0;
      flagMbinitRepairVal_SendResultResp <= 1'b0;
      flagMbinitRepairVal_SendDoneResp <= 1'b0;
      mbinitRepairVal_ReceivedResultBit <= 1'b0;
      mbinitRepairVal_logValTrainPatternReceived <= 1'b0;
      repairValSenderStateReg <= RepairValSenderState_initReq;
      repairValReceiverStateReg <= RepairValReceiverState_sendInitResp;
      flagMbinitReversalMb_ReceivedInitReq <= 1'b0;
      flagMbinitReversalMb_ReceivedInitResp <= 1'b0;
      flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
      flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
      flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
      flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
      flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
      flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
      flagMbinitReversalMb_ReceivedDoneResp <= 1'b0;
      flagMbinitReversalMb_SendInitReq <= 1'b0;
      flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
      flagMbinitReversalMb_SendResultReq <= 1'b0;
      flagMbinitReversalMb_SendDoneReq <= 1'b0;
      flagMbinitReversalMb_SendInitResp <= 1'b0;
      flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
      flagMbinitReversalMb_SendResultResp <= 1'b0;
      flagMbinitReversalMb_SendDoneResp <= 1'b0;
      flagMbinitReversalMb_SentInitReq <= 1'b0;
      flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
      flagMbinitReversalMb_SentResultReq <= 1'b0;
      flagMbinitReversalMb_SentDoneReq <= 1'b0;
      flagMbinitReversalMb_SentInitResp <= 1'b0;
      flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
      flagMbinitReversalMb_SentResultResp <= 1'b0;
      flagMbinitReversalMb_SentDoneResp <= 1'b0;
      reversalMbSenderStateReg <= ReversalMbSenderState_initReq;
      reversalMbReceiverStateReg <= ReversalMbReceiverState_sendInitResp;
      flagMbinitRepairMb_ReceivedStartReq <= 1'b0;
      flagMbinitRepairMb_ReceivedStartResp <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b0;
      flagMbinitRepairMb_D2CPointTestReqWaitingPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b0;
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b0;
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b0;
      mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= 3'b0;
      flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
      flagMbinitRepairMb_ReceivedEndResp <= 1'b0;
      flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
      mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= 16'b0;
      mbinitRepairMb_TxInitD2CResultsRespPayload <= 64'b0;
      mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= 16'b0;
      flagMbinitRepairMb_SendStartReq <= 1'b0;
      flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
      flagMbinitRepairMb_SendEndReq <= 1'b0;
      flagMbinitRepairMb_SendStartResp <= 1'b0;
      flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
      flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_SendEndResp <= 1'b0;
      flagMbinitRepairMb_SentStartReq <= 1'b0;
      flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
      flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
      flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
      flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
      flagMbinitRepairMb_SentEndReq <= 1'b0;
      flagMbinitRepairMb_SentStartResp <= 1'b0;
      flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
      flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
      flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
      flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
      flagMbinitRepairMb_SentEndResp <= 1'b0;
      repairMbSenderStateReg <= RepairMbSenderState_sendStartReq;
      repairMbReceiverStateReg <= RepairMbReceiverState_waitStartReq;
      repairMb_DetectedLaneIDPatternLog <= 16'b0;
      reversalMbLaneStatusLog <= 16'b0;
      reversalMb_LaneReversalApplied <= 1'b0;
      reversalMb_ReceivedSuccessCount <= 5'b0;
      mbinitRepairClk_logClkPatternReceivedRTRK_L <= 1'b0;
      mbinitRepairClk_logClkPatternReceivedRCKN_L <= 1'b0;
      mbinitRepairClk_logClkPatternReceivedRCKP_L <= 1'b0;
      remoteParamReqPayload <= 64'b0;
      remoteParamRespPayload <= 64'b0;
      prevStart <= 1'b0;
      prevRxValid <= 1'b0;
    end else begin
      // RegNext semantics and the source's defaulted pulse-style TX registers.
      prevStart <= start;
      prevRxValid <= sb_rx_valid;
      sbTxValid <= 1'b0;
      sbTxDin <= 128'b0;

      if (startPulse) begin
        running <= 1'b1;
        stateReg <= MBInitState_PARAM;
        trainErrorReg <= 1'b0;
        flagMbinitParam_ReceivedReqHeader <= 1'b0;
        flagMbinitParam_ReceivedReqPayload <= 1'b0;
        flagMbinitParam_SentReq <= 1'b0;
        flagMbinitParam_ReceivedRespHeader <= 1'b0;
        flagMbinitParam_ReceivedRespPayload <= 1'b0;
        flagMbinitParam_SentResp <= 1'b0;
        flagMbinitParam_SendReq <= 1'b0;
        flagMbinitParam_SendResp <= 1'b0;
        flagMbinitParam_ReceivedCorrectReq <= 1'b0;
        paramSenderStateReg <= ParamSenderState_sendReqHeader;
        paramReceiverStateReg <= ParamReceiverState_waitReq;
        flagMbinitCal_ReceivedDoneReq <= 1'b0;
        flagMbinitCal_ReceivedDoneResp <= 1'b0;
        flagMbinitCal_SentDoneReq <= 1'b0;
        flagMbinitCal_SentDoneResp <= 1'b0;
        flagMbinitCal_SendDoneReq <= 1'b0;
        flagMbinitCal_SendDoneResp <= 1'b0;
        calSenderStateReg <= CalSenderState_sendDoneReq;
        calReceiverStateReg <= CalReceiverState_waitDoneReq;
        flagMbinitRepairClk_ReceivedInitResp <= 1'b0;
        flagMbinitRepairClk_ReceivedInitReq <= 1'b0;
        flagMbinitRepairClk_ReceivedResultResp <= 1'b0;
        flagMbinitRepairClk_ReceivedResultReq <= 1'b0;
        flagMbinitRepairClk_ReceivedDoneResp <= 1'b0;
        flagMbinitRepairClk_ReceivedDoneReq <= 1'b0;
        flagMbinitRepairClk_SentInitReq <= 1'b0;
        flagMbinitRepairClk_SentResultReq <= 1'b0;
        flagMbinitRepairClk_SentDoneReq <= 1'b0;
        flagMbinitRepairClk_SentInitResp <= 1'b0;
        flagMbinitRepairClk_SentResultResp <= 1'b0;
        flagMbinitRepairClk_SentDoneResp <= 1'b0;
        flagMbinitRepairClk_SendInitReq <= 1'b0;
        flagMbinitRepairClk_SendResultReq <= 1'b0;
        flagMbinitRepairClk_SendDoneReq <= 1'b0;
        flagMbinitRepairClk_SendInitResp <= 1'b0;
        flagMbinitRepairClk_SendResultResp <= 1'b0;
        flagMbinitRepairClk_SendDoneResp <= 1'b0;
        mbinitRepairClk_ReceivedResultBits <= 0;
        repairClkSenderStateReg <= RepairClkSenderState_initReq;
        repairClkReceiverStateReg <= RepairClkReceiverState_sendInitResp;
        flagMbinitRepairVal_SentInitReq <= 1'b0;
        flagMbinitRepairVal_SentResultReq <= 1'b0;
        flagMbinitRepairVal_SentDoneReq <= 1'b0;
        flagMbinitRepairVal_SentInitResp <= 1'b0;
        flagMbinitRepairVal_SentResultResp <= 1'b0;
        flagMbinitRepairVal_SentDoneResp <= 1'b0;
        flagMbinitRepairVal_ReceivedInitResp <= 1'b0;
        flagMbinitRepairVal_ReceivedInitReq <= 1'b0;
        flagMbinitRepairVal_ReceivedResultResp <= 1'b0;
        flagMbinitRepairVal_ReceivedResultReq <= 1'b0;
        flagMbinitRepairVal_ReceivedDoneResp <= 1'b0;
        flagMbinitRepairVal_ReceivedDoneReq <= 1'b0;
        flagMbinitRepairVal_SendInitReq <= 1'b0;
        flagMbinitRepairVal_SendResultReq <= 1'b0;
        flagMbinitRepairVal_SendDoneReq <= 1'b0;
        flagMbinitRepairVal_SendInitResp <= 1'b0;
        flagMbinitRepairVal_SendResultResp <= 1'b0;
        flagMbinitRepairVal_SendDoneResp <= 1'b0;
        mbinitRepairVal_ReceivedResultBit <= 1'b0;
        mbinitRepairVal_logValTrainPatternReceived <= 1'b0;
        repairValSenderStateReg <= RepairValSenderState_initReq;
        repairValReceiverStateReg <= RepairValReceiverState_sendInitResp;
        flagMbinitReversalMb_ReceivedInitReq <= 1'b0;
        flagMbinitReversalMb_ReceivedInitResp <= 1'b0;
        flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
        flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
        flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
        flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
        flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
        flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
        flagMbinitReversalMb_ReceivedDoneResp <= 1'b0;
        flagMbinitReversalMb_SendInitReq <= 1'b0;
        flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
        flagMbinitReversalMb_SendResultReq <= 1'b0;
        flagMbinitReversalMb_SendDoneReq <= 1'b0;
        flagMbinitReversalMb_SendInitResp <= 1'b0;
        flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
        flagMbinitReversalMb_SendResultResp <= 1'b0;
        flagMbinitReversalMb_SendDoneResp <= 1'b0;
        flagMbinitReversalMb_SentInitReq <= 1'b0;
        flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
        flagMbinitReversalMb_SentResultReq <= 1'b0;
        flagMbinitReversalMb_SentDoneReq <= 1'b0;
        flagMbinitReversalMb_SentInitResp <= 1'b0;
        flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
        flagMbinitReversalMb_SentResultResp <= 1'b0;
        flagMbinitReversalMb_SentDoneResp <= 1'b0;
        reversalMbSenderStateReg <= ReversalMbSenderState_initReq;
        reversalMbReceiverStateReg <= ReversalMbReceiverState_sendInitResp;
        flagMbinitRepairMb_ReceivedStartReq <= 1'b0;
        flagMbinitRepairMb_ReceivedStartResp <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b0;
        flagMbinitRepairMb_D2CPointTestReqWaitingPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b0;
        flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b0;
        flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b0;
        mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= 0;
        flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
        flagMbinitRepairMb_ReceivedEndResp <= 1'b0;
        flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
        mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= 0;
        mbinitRepairMb_TxInitD2CResultsRespPayload <= 0;
        mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= 0;
        flagMbinitRepairMb_SendStartReq <= 1'b0;
        flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
        flagMbinitRepairMb_SendEndReq <= 1'b0;
        flagMbinitRepairMb_SendStartResp <= 1'b0;
        flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
        flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_SendEndResp <= 1'b0;
        flagMbinitRepairMb_SentStartReq <= 1'b0;
        flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
        flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
        flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
        flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
        flagMbinitRepairMb_SentEndReq <= 1'b0;
        flagMbinitRepairMb_SentStartResp <= 1'b0;
        flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
        flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
        flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
        flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
        flagMbinitRepairMb_SentEndResp <= 1'b0;
        repairMbSenderStateReg <= RepairMbSenderState_sendStartReq;
        repairMbReceiverStateReg <= RepairMbReceiverState_waitStartReq;
        repairMb_DetectedLaneIDPatternLog <= 0;
        reversalMbLaneStatusLog <= 0;
        reversalMb_LaneReversalApplied <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRTRK_L <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRCKN_L <= 1'b0;
        mbinitRepairClk_logClkPatternReceivedRCKP_L <= 1'b0;
        remoteParamReqPayload <= 0;
        remoteParamRespPayload <= 0;
      end
      if (!start && stateReg == MBInitState_DONE) begin
        running <= 1'b0;
      end
      if (rxValidRisingEdge) begin
        if (sb_rx_dout == MBINIT_PARAM_REQ) begin
          flagMbinitParam_ReceivedReqHeader <= 1'b1;
          flagMbinitParam_ReceivedReqPayload <= 1'b1;
          remoteParamReqPayload <= sb_rx_dout[127:64];
        end
        if (sb_rx_dout == MBINIT_PARAM_RESP) begin
          flagMbinitParam_ReceivedRespHeader <= 1'b1;
          flagMbinitParam_ReceivedRespPayload <= 1'b1;
          remoteParamRespPayload <= sb_rx_dout[127:64];
        end
        if (sb_rx_dout == MBINIT_CAL_DONE_REQ) begin
          flagMbinitCal_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_CAL_DONE_RESP) begin
          flagMbinitCal_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_INIT_REQ) begin
          flagMbinitRepairClk_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_INIT_RESP) begin
          flagMbinitRepairClk_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_RESULT_REQ) begin
          flagMbinitRepairClk_ReceivedResultReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFF8FFFFFFFFFF}) == (MBINIT_REPAIRCLK_RESULT_RESP & {64'd0, 64'hBFFFF8FFFFFFFFFF})) begin
          flagMbinitRepairClk_ReceivedResultResp <= 1'b1;
          mbinitRepairClk_ReceivedResultBits <= sb_rx_dout[42:40];
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_DONE_REQ) begin
          flagMbinitRepairClk_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRCLK_DONE_RESP) begin
          flagMbinitRepairClk_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_INIT_REQ) begin
          flagMbinitRepairVal_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_INIT_RESP) begin
          flagMbinitRepairVal_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_RESULT_REQ) begin
          flagMbinitRepairVal_ReceivedResultReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFFEFFFFFFFFFF}) == (MBINIT_REPAIRVAL_RESULT_RESP & {64'd0, 64'hBFFFFEFFFFFFFFFF})) begin
          flagMbinitRepairVal_ReceivedResultResp <= 1'b1;
          mbinitRepairVal_ReceivedResultBit <= sb_rx_dout[40];
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_DONE_REQ) begin
          flagMbinitRepairVal_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRVAL_DONE_RESP) begin
          flagMbinitRepairVal_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_INIT_REQ) begin
          flagMbinitReversalMb_ReceivedInitReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_INIT_RESP) begin
          flagMbinitReversalMb_ReceivedInitResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_CLEAR_ERROR_REQ) begin
          flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_CLEAR_ERROR_RESP) begin
          flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_RESULT_REQ) begin
          flagMbinitReversalMb_ReceivedResultReq <= 1'b1;
        end
        if (sb_rx_dout[63:0] == MBINIT_REVERSALMB_RESULT_RESP[63:0]) begin
          flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b1;
          flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b1;
          reversalMb_ReceivedSuccessCount <= countOnes16(sb_rx_dout[79:64]);
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_DONE_REQ) begin
          flagMbinitReversalMb_ReceivedDoneReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REVERSALMB_DONE_RESP) begin
          flagMbinitReversalMb_ReceivedDoneResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_START_REQ) begin
          flagMbinitRepairMb_ReceivedStartReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_START_RESP) begin
          flagMbinitRepairMb_ReceivedStartResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_D2C_POINT_TEST_REQ) begin
          flagMbinitRepairMb_ReceivedD2CPointTestReqHeader <= 1'b1;
          flagMbinitRepairMb_ReceivedD2CPointTestReqPayload <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_D2C_POINT_TEST_RESP) begin
          flagMbinitRepairMb_ReceivedD2CPointTestResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ) begin
          flagMbinitRepairMb_ReceivedLfsrClearErrorReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP) begin
          flagMbinitRepairMb_ReceivedLfsrClearErrorResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ) begin
          flagMbinitRepairMb_ReceivedTxInitD2CResultsReq <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'h3F0000FFFFFFFFFF}) == (MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP & {64'd0, 64'h3F0000FFFFFFFFFF})) begin
          flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader <= 1'b1;
          flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload <= 1'b1;
          mbinitRepairMb_TxInitD2CResultsRespMsgInfo <= sb_rx_dout[55:40];
          mbinitRepairMb_TxInitD2CResultsRespPayload <= sb_rx_dout[127:64];
          mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits <= sb_rx_dout[79:64];
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ) begin
          flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP) begin
          flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp <= 1'b1;
        end
        if ((sb_rx_dout & {64'd0, 64'hBFFFF8FFFFFFFFFF}) == (MBINIT_REPAIRMB_APPLY_DEGRADE_REQ_TEMPLATE & {64'd0, 64'hBFFFF8FFFFFFFFFF})) begin
          flagMbinitRepairMb_ReceivedApplyDegradeReq <= 1'b1;
          mbinitRepairMb_ReceivedApplyDegradeReqLaneMap <= sb_rx_dout[42:40];
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_APPLY_DEGRADE_RESP) begin
          flagMbinitRepairMb_ReceivedApplyDegradeResp <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_REQ) begin
          flagMbinitRepairMb_ReceivedEndReq <= 1'b1;
        end
        if (sb_rx_dout == MBINIT_REPAIRMB_END_RESP) begin
          flagMbinitRepairMb_ReceivedEndResp <= 1'b1;
        end
      end
      if (running) begin
        unique case (stateReg)
          MBInitState_PARAM: begin
            unique case (paramSenderStateReg)
              ParamSenderState_sendReqHeader: begin
                if (flagMbinitParam_SentReq) begin
                  flagMbinitParam_SendReq <= 1'b0;
                  paramSenderStateReg <= ParamSenderState_waitResp;
                end
                else begin
                  flagMbinitParam_SendReq <= 1'b1;
                end
              end
              ParamSenderState_waitResp: begin
                if (flagMbinitParam_ReceivedRespHeader && flagMbinitParam_ReceivedRespPayload) begin
                  paramSenderStateReg <= ParamSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (paramReceiverStateReg)
              ParamReceiverState_waitReq: begin
                if (flagMbinitParam_ReceivedReqHeader && flagMbinitParam_ReceivedReqPayload) begin
                  paramReceiverStateReg <= ParamReceiverState_validateReqPayload;
                end
              end
              ParamReceiverState_validateReqPayload: begin
                if (remoteParamReqPayload == MBINIT_PARAM_REQ[127:64]) begin
                  flagMbinitParam_ReceivedCorrectReq <= 1'b1;
                  paramReceiverStateReg <= ParamReceiverState_sendRespHeader;
                end
                else begin
                  trainErrorReg <= 1'b1;
                end
              end
              ParamReceiverState_sendRespHeader: begin
                if (flagMbinitParam_SentResp) begin
                  flagMbinitParam_SendResp <= 1'b0;
                  paramReceiverStateReg <= ParamReceiverState_finish;
                end
                else begin
                  flagMbinitParam_SendResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitParam_SendResp) begin
                sbTxDin <= MBINIT_PARAM_RESP;
                sbTxValid <= 1'b1;
                flagMbinitParam_SentResp <= 1'b1;
              end
              else if (flagMbinitParam_SendReq) begin
                sbTxDin <= MBINIT_PARAM_REQ;
                sbTxValid <= 1'b1;
                flagMbinitParam_SentReq <= 1'b1;
              end
            end
            if (paramSenderStateReg == ParamSenderState_finish && paramReceiverStateReg == ParamReceiverState_finish) begin
              flagMbinitParam_SendReq <= 1'b0;
              flagMbinitParam_SendResp <= 1'b0;
              flagMbinitParam_SentReq <= 1'b0;
              flagMbinitParam_SentResp <= 1'b0;
              stateReg <= MBInitState_CAL;
            end
          end
          MBInitState_CAL: begin
            unique case (calSenderStateReg)
              CalSenderState_sendDoneReq: begin
                if (flagMbinitCal_SentDoneReq) begin
                  flagMbinitCal_SendDoneReq <= 1'b0;
                  calSenderStateReg <= CalSenderState_waitDoneResp;
                end
                else begin
                  flagMbinitCal_SendDoneReq <= 1'b1;
                end
              end
              CalSenderState_waitDoneResp: begin
                if (flagMbinitCal_ReceivedDoneResp) begin
                  calSenderStateReg <= CalSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (calReceiverStateReg)
              CalReceiverState_waitDoneReq: begin
                if (flagMbinitCal_ReceivedDoneReq) begin
                  calReceiverStateReg <= CalReceiverState_sendDoneResp;
                end
              end
              CalReceiverState_sendDoneResp: begin
                if (flagMbinitCal_SentDoneResp) begin
                  flagMbinitCal_SendDoneResp <= 1'b0;
                  calReceiverStateReg <= CalReceiverState_finish;
                end
                else begin
                  flagMbinitCal_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitCal_SendDoneResp) begin
                sbTxDin <= MBINIT_CAL_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitCal_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitCal_SendDoneReq) begin
                sbTxDin <= MBINIT_CAL_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitCal_SentDoneReq <= 1'b1;
              end
            end
            if (calSenderStateReg == CalSenderState_finish && calReceiverStateReg == CalReceiverState_finish) begin
              flagMbinitCal_SendDoneReq <= 1'b0;
              flagMbinitCal_SendDoneResp <= 1'b0;
              flagMbinitCal_SentDoneReq <= 1'b0;
              flagMbinitCal_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRCLK;
            end
          end
          MBInitState_REPAIRCLK: begin
            unique case (repairClkSenderStateReg)
              RepairClkSenderState_initReq: begin
                if (flagMbinitRepairClk_SentInitReq) begin
                  flagMbinitRepairClk_SendInitReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_sendClkPatternsExchange;
                end
                else begin
                  flagMbinitRepairClk_SendInitReq <= 1'b1;
                end
              end
              RepairClkSenderState_sendClkPatternsExchange: begin
                if (flagMbinitRepairClk_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  repairClkSenderStateReg <= RepairClkSenderState_waitingPatternsExchangeFinish;
                end
              end
              RepairClkSenderState_waitingPatternsExchangeFinish: begin
                if (flagFromAnalog_FinishedClkPatterns) begin
                  repairClkSenderStateReg <= RepairClkSenderState_sendResultReq;
                end
              end
              RepairClkSenderState_sendResultReq: begin
                if (flagMbinitRepairClk_SentResultReq) begin
                  flagMbinitRepairClk_SendResultReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_receiveResultResp;
                end
                else begin
                  flagMbinitRepairClk_SendResultReq <= 1'b1;
                end
              end
              RepairClkSenderState_receiveResultResp: begin
                if (flagMbinitRepairClk_ReceivedResultResp) begin
                  if (mbinitRepairClk_ReceivedResultBits == 3'b111) begin
                    repairClkSenderStateReg <= RepairClkSenderState_sendDoneReq;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairClkSenderState_sendDoneReq: begin
                if (flagMbinitRepairClk_SentDoneReq) begin
                  flagMbinitRepairClk_SendDoneReq <= 1'b0;
                  repairClkSenderStateReg <= RepairClkSenderState_receiveDoneResp;
                end
                else begin
                  flagMbinitRepairClk_SendDoneReq <= 1'b1;
                end
              end
              RepairClkSenderState_receiveDoneResp: begin
                if (flagMbinitRepairClk_ReceivedDoneResp) begin
                  repairClkSenderStateReg <= RepairClkSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (repairClkReceiverStateReg)
              RepairClkReceiverState_sendInitResp: begin
                if (flagMbinitRepairClk_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitRepairClk_SentInitResp) begin
                    flagMbinitRepairClk_SendInitResp <= 1'b0;
                    repairClkReceiverStateReg <= RepairClkReceiverState_waitingPatternsExchangeFinish;
                  end
                  else begin
                    flagMbinitRepairClk_SendInitResp <= 1'b1;
                  end
                end
              end
              RepairClkReceiverState_waitingPatternsExchangeFinish: begin
                if (flagMbinitRepairClk_ReceivedResultReq) begin
                  mbinitRepairClk_logClkPatternReceivedRTRK_L <= flagFromAnalog_clkPatternReceivedRTRK_L;
                  mbinitRepairClk_logClkPatternReceivedRCKN_L <= flagFromAnalog_clkPatternReceivedRCKN_L;
                  mbinitRepairClk_logClkPatternReceivedRCKP_L <= flagFromAnalog_clkPatternReceivedRCKP_L;
                  if (flagFromAnalog_clkPatternReceivedRTRK_L && flagFromAnalog_clkPatternReceivedRCKN_L && flagFromAnalog_clkPatternReceivedRCKP_L) begin
                    repairClkReceiverStateReg <= RepairClkReceiverState_sendResultResp;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairClkReceiverState_sendResultResp: begin
                if (flagMbinitRepairClk_SentResultResp) begin
                  flagMbinitRepairClk_SendResultResp <= 1'b0;
                  repairClkReceiverStateReg <= RepairClkReceiverState_receiveDoneReq;
                end
                else begin
                  flagMbinitRepairClk_SendResultResp <= 1'b1;
                end
              end
              RepairClkReceiverState_receiveDoneReq: begin
                if (flagMbinitRepairClk_ReceivedDoneReq) begin
                  repairClkReceiverStateReg <= RepairClkReceiverState_sendDoneResp;
                end
              end
              RepairClkReceiverState_sendDoneResp: begin
                if (flagMbinitRepairClk_SentDoneResp) begin
                  flagMbinitRepairClk_SendDoneResp <= 1'b0;
                  repairClkReceiverStateReg <= RepairClkReceiverState_finish;
                end
                else begin
                  flagMbinitRepairClk_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairClk_SendInitResp) begin
                sbTxDin <= MBINIT_REPAIRCLK_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentInitResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendResultResp) begin
                sbTxDin <= msgMbinitRepairClkResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, mbinitRepairClk_logClkPatternReceivedRTRK_L, mbinitRepairClk_logClkPatternReceivedRCKN_L, mbinitRepairClk_logClkPatternReceivedRCKP_L );
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentResultResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendDoneResp) begin
                sbTxDin <= MBINIT_REPAIRCLK_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendInitReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentInitReq <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendResultReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentResultReq <= 1'b1;
              end
              else if (flagMbinitRepairClk_SendDoneReq) begin
                sbTxDin <= MBINIT_REPAIRCLK_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairClk_SentDoneReq <= 1'b1;
              end
            end
            if (repairClkReceiverStateReg == RepairClkReceiverState_finish && repairClkSenderStateReg == RepairClkSenderState_finish) begin
              flagMbinitRepairClk_SendInitReq <= 1'b0;
              flagMbinitRepairClk_SendResultReq <= 1'b0;
              flagMbinitRepairClk_SendDoneReq <= 1'b0;
              flagMbinitRepairClk_SendInitResp <= 1'b0;
              flagMbinitRepairClk_SendResultResp <= 1'b0;
              flagMbinitRepairClk_SendDoneResp <= 1'b0;
              flagMbinitRepairClk_SentInitReq <= 1'b0;
              flagMbinitRepairClk_SentResultReq <= 1'b0;
              flagMbinitRepairClk_SentDoneReq <= 1'b0;
              flagMbinitRepairClk_SentInitResp <= 1'b0;
              flagMbinitRepairClk_SentResultResp <= 1'b0;
              flagMbinitRepairClk_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRVAL;
            end
          end
          MBInitState_REPAIRVAL: begin
            unique case (repairValSenderStateReg)
              RepairValSenderState_initReq: begin
                if (flagMbinitRepairVal_SentInitReq) begin
                  flagMbinitRepairVal_SendInitReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_sendValTrainPattern;
                end
                else begin
                  flagMbinitRepairVal_SendInitReq <= 1'b1;
                end
              end
              RepairValSenderState_sendValTrainPattern: begin
                if (flagMbinitRepairVal_ReceivedInitResp && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  repairValSenderStateReg <= RepairValSenderState_waitingValTrainPatternFinish;
                end
              end
              RepairValSenderState_waitingValTrainPatternFinish: begin
                if (flagFromAnalog_FinishedValTrainPattern) begin
                  repairValSenderStateReg <= RepairValSenderState_sendResultReq;
                end
              end
              RepairValSenderState_sendResultReq: begin
                if (flagMbinitRepairVal_SentResultReq) begin
                  flagMbinitRepairVal_SendResultReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_receiveResultResp;
                end
                else begin
                  flagMbinitRepairVal_SendResultReq <= 1'b1;
                end
              end
              RepairValSenderState_receiveResultResp: begin
                if (flagMbinitRepairVal_ReceivedResultResp) begin
                  if (mbinitRepairVal_ReceivedResultBit) begin
                    repairValSenderStateReg <= RepairValSenderState_sendDoneReq;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairValSenderState_sendDoneReq: begin
                if (flagMbinitRepairVal_SentDoneReq) begin
                  flagMbinitRepairVal_SendDoneReq <= 1'b0;
                  repairValSenderStateReg <= RepairValSenderState_receiveDoneResp;
                end
                else begin
                  flagMbinitRepairVal_SendDoneReq <= 1'b1;
                end
              end
              RepairValSenderState_receiveDoneResp: begin
                if (flagMbinitRepairVal_ReceivedDoneResp) begin
                  repairValSenderStateReg <= RepairValSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (repairValReceiverStateReg)
              RepairValReceiverState_sendInitResp: begin
                if (flagMbinitRepairVal_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitRepairVal_SentInitResp) begin
                    flagMbinitRepairVal_SendInitResp <= 1'b0;
                    repairValReceiverStateReg <= RepairValReceiverState_waitingValTrainPatternFinish;
                  end
                  else begin
                    flagMbinitRepairVal_SendInitResp <= 1'b1;
                  end
                end
              end
              RepairValReceiverState_waitingValTrainPatternFinish: begin
                if (flagMbinitRepairVal_ReceivedResultReq) begin
                  mbinitRepairVal_logValTrainPatternReceived <= flagFromAnalog_ValTrainPatternReceived;
                  repairValReceiverStateReg <= RepairValReceiverState_sendResultResp;
                end
              end
              RepairValReceiverState_sendResultResp: begin
                if (flagMbinitRepairVal_SentResultResp) begin
                  flagMbinitRepairVal_SendResultResp <= 1'b0;
                  repairValReceiverStateReg <= RepairValReceiverState_receiveDoneReq;
                end
                else begin
                  flagMbinitRepairVal_SendResultResp <= 1'b1;
                end
              end
              RepairValReceiverState_receiveDoneReq: begin
                if (flagMbinitRepairVal_ReceivedDoneReq) begin
                  repairValReceiverStateReg <= RepairValReceiverState_sendDoneResp;
                end
              end
              RepairValReceiverState_sendDoneResp: begin
                if (flagMbinitRepairVal_SentDoneResp) begin
                  flagMbinitRepairVal_SendDoneResp <= 1'b0;
                  repairValReceiverStateReg <= RepairValReceiverState_finish;
                end
                else begin
                  flagMbinitRepairVal_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairVal_SendInitResp) begin
                sbTxDin <= MBINIT_REPAIRVAL_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendInitResp <= 1'b0;
                flagMbinitRepairVal_SentInitResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendResultResp) begin
                sbTxDin <= msgMbinitRepairValResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, mbinitRepairVal_logValTrainPatternReceived );
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendResultResp <= 1'b0;
                flagMbinitRepairVal_SentResultResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendDoneResp) begin
                sbTxDin <= MBINIT_REPAIRVAL_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendDoneResp <= 1'b0;
                flagMbinitRepairVal_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendInitReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendInitReq <= 1'b0;
                flagMbinitRepairVal_SentInitReq <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendResultReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendResultReq <= 1'b0;
                flagMbinitRepairVal_SentResultReq <= 1'b1;
              end
              else if (flagMbinitRepairVal_SendDoneReq) begin
                sbTxDin <= MBINIT_REPAIRVAL_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairVal_SendDoneReq <= 1'b0;
                flagMbinitRepairVal_SentDoneReq <= 1'b1;
              end
            end
            if (repairValReceiverStateReg == RepairValReceiverState_finish && repairValSenderStateReg == RepairValSenderState_finish) begin
              stateReg <= MBInitState_REVERSALMB;
            end
          end
          MBInitState_REVERSALMB: begin
            unique case (reversalMbSenderStateReg)
              ReversalMbSenderState_initReq: begin
                if (flagMbinitReversalMb_SentInitReq) begin
                  flagMbinitReversalMb_SendInitReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitInitResp;
                end
                else begin
                  flagMbinitReversalMb_SendInitReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitInitResp: begin
                if (flagMbinitReversalMb_ReceivedInitResp) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendClearErrorReq;
                end
              end
              ReversalMbSenderState_sendClearErrorReq: begin
                if (flagMbinitReversalMb_SentClearErrorReq) begin
                  flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitClearErrorResp;
                end
                else begin
                  flagMbinitReversalMb_SendClearErrorReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitClearErrorResp: begin
                if (flagMbinitReversalMb_ReceivedClearErrorResp) begin
                  flagMbinitReversalMb_ReceivedClearErrorResp <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendLaneIDPattern;
                end
              end
              ReversalMbSenderState_sendLaneIDPattern: begin
                reversalMbSenderStateReg <= ReversalMbSenderState_waitingLaneIDPatternFinish;
              end
              ReversalMbSenderState_waitingLaneIDPatternFinish: begin
                if (flagFromAnalog_ReversalMbFinishedLaneIDPattern) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_sendResultReq;
                end
              end
              ReversalMbSenderState_sendResultReq: begin
                if (flagMbinitReversalMb_SentResultReq) begin
                  flagMbinitReversalMb_SendResultReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitResultResp;
                end
                else begin
                  flagMbinitReversalMb_SendResultReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitResultResp: begin
                if (flagMbinitReversalMb_ReceivedResultRespPayload) begin
                  flagMbinitReversalMb_ReceivedResultRespHeader <= 1'b0;
                  flagMbinitReversalMb_ReceivedResultRespPayload <= 1'b0;
                  if (reversalMb_ReceivedSuccessCount > 8) begin
                    reversalMbSenderStateReg <= ReversalMbSenderState_sendDoneReq;
                  end
                  else begin
                    if (reversalMb_LaneReversalApplied) begin
                      trainErrorReg <= 1'b1;
                    end
                    else begin
                      reversalMb_LaneReversalApplied <= 1'b1;
                      reversalMbSenderStateReg <= ReversalMbSenderState_sendClearErrorReq;
                    end
                  end
                end
              end
              ReversalMbSenderState_sendDoneReq: begin
                if (flagMbinitReversalMb_SentDoneReq) begin
                  flagMbinitReversalMb_SendDoneReq <= 1'b0;
                  reversalMbSenderStateReg <= ReversalMbSenderState_waitDoneResp;
                end
                else begin
                  flagMbinitReversalMb_SendDoneReq <= 1'b1;
                end
              end
              ReversalMbSenderState_waitDoneResp: begin
                if (flagMbinitReversalMb_ReceivedDoneResp) begin
                  reversalMbSenderStateReg <= ReversalMbSenderState_finish;
                end
              end
              default: ;
            endcase
            unique case (reversalMbReceiverStateReg)
              ReversalMbReceiverState_sendInitResp: begin
                if (flagMbinitReversalMb_ReceivedInitReq && flagFromAnalog_ReadyToExchangeClkPatterns) begin
                  if (flagMbinitReversalMb_SentInitResp) begin
                    flagMbinitReversalMb_SendInitResp <= 1'b0;
                    reversalMbReceiverStateReg <= ReversalMbReceiverState_waitClearErrorReq;
                  end
                  else begin
                    flagMbinitReversalMb_SendInitResp <= 1'b1;
                  end
                end
              end
              ReversalMbReceiverState_waitClearErrorReq: begin
                if (flagMbinitReversalMb_ReceivedClearErrorReq) begin
                  flagMbinitReversalMb_ReceivedClearErrorReq <= 1'b0;
                  reversalMbLaneStatusLog <= 0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendClearErrorResp;
                end
              end
              ReversalMbReceiverState_sendClearErrorResp: begin
                if (flagMbinitReversalMb_SentClearErrorResp) begin
                  flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitResultReq;
                end
                else begin
                  flagMbinitReversalMb_SendClearErrorResp <= 1'b1;
                end
              end
              ReversalMbReceiverState_waitResultReq: begin
                if (flagMbinitReversalMb_ReceivedResultReq) begin
                  flagMbinitReversalMb_ReceivedResultReq <= 1'b0;
                  reversalMbLaneStatusLog <= {flagFromAnalog_ReversalMbTrainPatternReceived15, flagFromAnalog_ReversalMbTrainPatternReceived14, flagFromAnalog_ReversalMbTrainPatternReceived13, flagFromAnalog_ReversalMbTrainPatternReceived12, flagFromAnalog_ReversalMbTrainPatternReceived11, flagFromAnalog_ReversalMbTrainPatternReceived10, flagFromAnalog_ReversalMbTrainPatternReceived9, flagFromAnalog_ReversalMbTrainPatternReceived8, flagFromAnalog_ReversalMbTrainPatternReceived7, flagFromAnalog_ReversalMbTrainPatternReceived6, flagFromAnalog_ReversalMbTrainPatternReceived5, flagFromAnalog_ReversalMbTrainPatternReceived4, flagFromAnalog_ReversalMbTrainPatternReceived3, flagFromAnalog_ReversalMbTrainPatternReceived2, flagFromAnalog_ReversalMbTrainPatternReceived1, flagFromAnalog_ReversalMbTrainPatternReceived0};
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendResultResp;
                end
              end
              ReversalMbReceiverState_sendResultResp: begin
                if (flagMbinitReversalMb_SentResultResp) begin
                  flagMbinitReversalMb_SendResultResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitDoneReqOrClearErrorReq;
                end
                else begin
                  flagMbinitReversalMb_SendResultResp <= 1'b1;
                end
              end
              ReversalMbReceiverState_waitDoneReqOrClearErrorReq: begin
                if (flagMbinitReversalMb_ReceivedClearErrorReq) begin
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_waitClearErrorReq;
                end
                else if (flagMbinitReversalMb_ReceivedDoneReq) begin
                  flagMbinitReversalMb_ReceivedDoneReq <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_sendDoneResp;
                end
              end
              ReversalMbReceiverState_sendDoneResp: begin
                if (flagMbinitReversalMb_SentDoneResp) begin
                  flagMbinitReversalMb_SendDoneResp <= 1'b0;
                  reversalMbReceiverStateReg <= ReversalMbReceiverState_finish;
                end
                else begin
                  flagMbinitReversalMb_SendDoneResp <= 1'b1;
                end
              end
              default: ;
            endcase
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitReversalMb_SendInitResp) begin
                sbTxDin <= MBINIT_REVERSALMB_INIT_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentInitResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendClearErrorResp) begin
                sbTxDin <= MBINIT_REVERSALMB_CLEAR_ERROR_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentClearErrorResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendResultResp) begin
                sbTxDin <= msgMbinitReversalMbResultResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, reversalMbLaneStatusLog );
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentResultResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendDoneResp) begin
                sbTxDin <= MBINIT_REVERSALMB_DONE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentDoneResp <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendInitReq) begin
                sbTxDin <= MBINIT_REVERSALMB_INIT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentInitReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendClearErrorReq) begin
                sbTxDin <= MBINIT_REVERSALMB_CLEAR_ERROR_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentClearErrorReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendResultReq) begin
                sbTxDin <= MBINIT_REVERSALMB_RESULT_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentResultReq <= 1'b1;
              end
              else if (flagMbinitReversalMb_SendDoneReq) begin
                sbTxDin <= MBINIT_REVERSALMB_DONE_REQ;
                sbTxValid <= 1'b1;
                flagMbinitReversalMb_SentDoneReq <= 1'b1;
              end
            end
            if (reversalMbReceiverStateReg == ReversalMbReceiverState_finish && reversalMbSenderStateReg == ReversalMbSenderState_finish) begin
              flagMbinitReversalMb_SendInitReq <= 1'b0;
              flagMbinitReversalMb_SendClearErrorReq <= 1'b0;
              flagMbinitReversalMb_SendResultReq <= 1'b0;
              flagMbinitReversalMb_SendDoneReq <= 1'b0;
              flagMbinitReversalMb_SendInitResp <= 1'b0;
              flagMbinitReversalMb_SendClearErrorResp <= 1'b0;
              flagMbinitReversalMb_SendResultResp <= 1'b0;
              flagMbinitReversalMb_SendDoneResp <= 1'b0;
              flagMbinitReversalMb_SentInitReq <= 1'b0;
              flagMbinitReversalMb_SentClearErrorReq <= 1'b0;
              flagMbinitReversalMb_SentResultReq <= 1'b0;
              flagMbinitReversalMb_SentDoneReq <= 1'b0;
              flagMbinitReversalMb_SentInitResp <= 1'b0;
              flagMbinitReversalMb_SentClearErrorResp <= 1'b0;
              flagMbinitReversalMb_SentResultResp <= 1'b0;
              flagMbinitReversalMb_SentDoneResp <= 1'b0;
              stateReg <= MBInitState_REPAIRMB;
            end
          end
          MBInitState_REPAIRMB: begin
            unique case (repairMbSenderStateReg)
              RepairMbSenderState_sendStartReq: begin
                if (flagMbinitRepairMb_SentStartReq) begin
                  flagMbinitRepairMb_SendStartReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitStartResp;
                end
                else begin
                  flagMbinitRepairMb_SendStartReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitStartResp: begin
                if (flagMbinitRepairMb_ReceivedStartResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestSendReq;
                end
              end
              RepairMbSenderState_d2cPointTestSendReq: begin
                if (flagMbinitRepairMb_SentD2CPointTestReq) begin
                  flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendD2CPointTestReq <= 1'b1;
                end
              end
              RepairMbSenderState_d2cPointTestWaitResp: begin
                if (flagMbinitRepairMb_ReceivedD2CPointTestResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq;
                end
              end
              RepairMbSenderState_d2cPointTestLfsrClearErrorSendReq: begin
                if (flagMbinitRepairMb_SentLfsrClearErrorReq) begin
                  flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b1;
                end
              end
              RepairMbSenderState_d2cPointTestLfsrClearErrorWaitResp: begin
                if (flagMbinitRepairMb_ReceivedLfsrClearErrorResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_sendLaneIDPattern;
                end
              end
              RepairMbSenderState_sendLaneIDPattern: begin
                repairMbSenderStateReg <= RepairMbSenderState_waitingLaneIDPatternFinish;
              end
              RepairMbSenderState_waitingLaneIDPatternFinish: begin
                if (flagFromAnalog_RepairMbFinishedLaneIDPattern) begin
                  repairMbSenderStateReg <= RepairMbSenderState_txInitD2CResultsSendReq;
                end
              end
              RepairMbSenderState_txInitD2CResultsSendReq: begin
                if (flagMbinitRepairMb_SentTxInitD2CResultsReq) begin
                  flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_txInitD2CResultsWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b1;
                end
              end
              RepairMbSenderState_txInitD2CResultsWaitResp: begin
                if (flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload) begin
                  repairMbSenderStateReg <= RepairMbSenderState_endTxInitD2CPointTestSendReq;
                end
              end
              RepairMbSenderState_endTxInitD2CPointTestSendReq: begin
                if (flagMbinitRepairMb_SentEndTxInitD2CPointTestReq) begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_endTxInitD2CPointTestWaitResp;
                end
                else begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b1;
                end
              end
              RepairMbSenderState_endTxInitD2CPointTestWaitResp: begin
                if (flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_analyzeWidthDegradation;
                end
              end
              RepairMbSenderState_analyzeWidthDegradation: begin
                if (mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits == 16'hFFFF) begin
                  flagMbinitRepairMb_ApplyWidthDegradation <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_sendApplyDegradeReq;
                end
                else begin
                  flagMbinitRepairMb_ApplyWidthDegradation <= 1'b1;
                  repairMbSenderStateReg <= RepairMbSenderState_sendApplyDegradeReq;
                end
              end
              RepairMbSenderState_sendApplyDegradeReq: begin
                if (flagMbinitRepairMb_SentApplyDegradeReq) begin
                  flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitApplyDegradeResp;
                end
                else begin
                  flagMbinitRepairMb_SendApplyDegradeReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitApplyDegradeResp: begin
                if (flagMbinitRepairMb_ReceivedApplyDegradeResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_sendEndReq;
                end
              end
              RepairMbSenderState_sendEndReq: begin
                if (flagMbinitRepairMb_SentEndReq) begin
                  flagMbinitRepairMb_SendEndReq <= 1'b0;
                  repairMbSenderStateReg <= RepairMbSenderState_waitEndResp;
                end
                else begin
                  flagMbinitRepairMb_SendEndReq <= 1'b1;
                end
              end
              RepairMbSenderState_waitEndResp: begin
                if (flagMbinitRepairMb_ReceivedEndResp) begin
                  repairMbSenderStateReg <= RepairMbSenderState_finish;
                end
              end
              RepairMbSenderState_finish: begin
                repairMbSenderStateReg <= RepairMbSenderState_finish;
              end
              default: ;
            endcase
            unique case (repairMbReceiverStateReg)
              RepairMbReceiverState_waitStartReq: begin
                if (flagMbinitRepairMb_ReceivedStartReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendStartResp;
                end
              end
              RepairMbReceiverState_sendStartResp: begin
                if (flagMbinitRepairMb_SentStartResp) begin
                  flagMbinitRepairMb_SendStartResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitD2CPointTestReq;
                end
                else begin
                  flagMbinitRepairMb_SendStartResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitD2CPointTestReq: begin
                if (flagMbinitRepairMb_ReceivedD2CPointTestReqHeader && flagMbinitRepairMb_ReceivedD2CPointTestReqPayload) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_setReceiver;
                end
              end
              RepairMbReceiverState_setReceiver: begin
                repairMbReceiverStateReg <= RepairMbReceiverState_sendD2CPointTestResp;
              end
              RepairMbReceiverState_sendD2CPointTestResp: begin
                if (flagMbinitRepairMb_SentD2CPointTestResp) begin
                  flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitLfsrClearErrorReq;
                end
                else begin
                  flagMbinitRepairMb_SendD2CPointTestResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitLfsrClearErrorReq: begin
                if (flagMbinitRepairMb_ReceivedLfsrClearErrorReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendLfsrClearErrorResp;
                end
              end
              RepairMbReceiverState_sendLfsrClearErrorResp: begin
                if (flagMbinitRepairMb_SentLfsrClearErrorResp) begin
                  flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitTxInitD2CResultsReq;
                end
                else begin
                  flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitTxInitD2CResultsReq: begin
                if (flagMbinitRepairMb_ReceivedTxInitD2CResultsReq) begin
                  repairMb_DetectedLaneIDPatternLog <= {flagFromAnalog_RepairMbDetectedLaneIDPattern15, flagFromAnalog_RepairMbDetectedLaneIDPattern14, flagFromAnalog_RepairMbDetectedLaneIDPattern13, flagFromAnalog_RepairMbDetectedLaneIDPattern12, flagFromAnalog_RepairMbDetectedLaneIDPattern11, flagFromAnalog_RepairMbDetectedLaneIDPattern10, flagFromAnalog_RepairMbDetectedLaneIDPattern9, flagFromAnalog_RepairMbDetectedLaneIDPattern8, flagFromAnalog_RepairMbDetectedLaneIDPattern7, flagFromAnalog_RepairMbDetectedLaneIDPattern6, flagFromAnalog_RepairMbDetectedLaneIDPattern5, flagFromAnalog_RepairMbDetectedLaneIDPattern4, flagFromAnalog_RepairMbDetectedLaneIDPattern3, flagFromAnalog_RepairMbDetectedLaneIDPattern2, flagFromAnalog_RepairMbDetectedLaneIDPattern1, flagFromAnalog_RepairMbDetectedLaneIDPattern0};
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendTxInitD2CResultsResp;
                end
              end
              RepairMbReceiverState_sendTxInitD2CResultsResp: begin
                if (flagMbinitRepairMb_SentTxInitD2CResultsResp) begin
                  flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitEndTxInitD2CPointTestReq;
                end
                else begin
                  flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitEndTxInitD2CPointTestReq: begin
                if (flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq) begin
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendEndTxInitD2CPointTestResp;
                end
              end
              RepairMbReceiverState_sendEndTxInitD2CPointTestResp: begin
                if (flagMbinitRepairMb_SentEndTxInitD2CPointTestResp) begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitApplyDegradeReq;
                end
                else begin
                  flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitApplyDegradeReq: begin
                if (flagMbinitRepairMb_ReceivedApplyDegradeReq) begin
                  if (mbinitRepairMb_ReceivedApplyDegradeReqLaneMap == 3'b011) begin
                    repairMbReceiverStateReg <= RepairMbReceiverState_sendApplyDegradeResp;
                  end
                  else begin
                    trainErrorReg <= 1'b1;
                  end
                end
              end
              RepairMbReceiverState_sendApplyDegradeResp: begin
                if (flagMbinitRepairMb_SentApplyDegradeResp) begin
                  flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_waitEndReq;
                end
                else begin
                  flagMbinitRepairMb_SendApplyDegradeResp <= 1'b1;
                end
              end
              RepairMbReceiverState_waitEndReq: begin
                if (flagMbinitRepairMb_ReceivedEndReq) begin
                  flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_sendEndResp;
                end
              end
              RepairMbReceiverState_sendEndResp: begin
                if (flagMbinitRepairMb_SentEndResp) begin
                  flagMbinitRepairMb_SendEndResp <= 1'b0;
                  repairMbReceiverStateReg <= RepairMbReceiverState_finish;
                end
                else begin
                  flagMbinitRepairMb_SendEndResp <= 1'b1;
                end
              end
              RepairMbReceiverState_finish: begin
                repairMbReceiverStateReg <= RepairMbReceiverState_finish;
              end
              default: ;
            endcase
            if (repairMbReceiverStateReg == RepairMbReceiverState_finish && repairMbSenderStateReg == RepairMbSenderState_finish) begin
              flagMbinitRepairMb_SendStartReq <= 1'b0;
              flagMbinitRepairMb_SendD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SendLfsrClearErrorReq <= 1'b0;
              flagMbinitRepairMb_SendTxInitD2CResultsReq <= 1'b0;
              flagMbinitRepairMb_SendEndTxInitD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SendApplyDegradeReq <= 1'b0;
              flagMbinitRepairMb_SendEndReq <= 1'b0;
              flagMbinitRepairMb_SendStartResp <= 1'b0;
              flagMbinitRepairMb_SendD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SendLfsrClearErrorResp <= 1'b0;
              flagMbinitRepairMb_SendTxInitD2CResultsResp <= 1'b0;
              flagMbinitRepairMb_SendEndTxInitD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SendApplyDegradeResp <= 1'b0;
              flagMbinitRepairMb_SendEndResp <= 1'b0;
              flagMbinitRepairMb_ReceivedEndReq <= 1'b0;
              flagMbinitRepairMb_SentStartReq <= 1'b0;
              flagMbinitRepairMb_SentD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b0;
              flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b0;
              flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b0;
              flagMbinitRepairMb_SentApplyDegradeReq <= 1'b0;
              flagMbinitRepairMb_SentEndReq <= 1'b0;
              flagMbinitRepairMb_SentStartResp <= 1'b0;
              flagMbinitRepairMb_SentD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b0;
              flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b0;
              flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b0;
              flagMbinitRepairMb_SentApplyDegradeResp <= 1'b0;
              flagMbinitRepairMb_SentEndResp <= 1'b0;
              stateReg <= MBInitState_DONE;
            end
            if (sb_tx_ready && !sbTxValid) begin
              if (flagMbinitRepairMb_SendStartResp) begin
                sbTxDin <= MBINIT_REPAIRMB_START_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentStartResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendD2CPointTestResp) begin
                sbTxDin <= MBINIT_REPAIRMB_D2C_POINT_TEST_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentD2CPointTestResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendLfsrClearErrorResp) begin
                sbTxDin <= MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentLfsrClearErrorResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendTxInitD2CResultsResp) begin
                sbTxDin <= msgMbinitRepairMbTxInitD2CResultsResp( ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 16'd0, {48'd0, repairMb_DetectedLaneIDPatternLog} );
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentTxInitD2CResultsResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndTxInitD2CPointTestResp) begin
                sbTxDin <= MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndTxInitD2CPointTestResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendApplyDegradeResp) begin
                sbTxDin <= MBINIT_REPAIRMB_APPLY_DEGRADE_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentApplyDegradeResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndResp) begin
                sbTxDin <= MBINIT_REPAIRMB_END_RESP;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndResp <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendStartReq) begin
                sbTxDin <= MBINIT_REPAIRMB_START_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentStartReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendD2CPointTestReq) begin
                sbTxDin <= MBINIT_REPAIRMB_D2C_POINT_TEST_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentD2CPointTestReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendLfsrClearErrorReq) begin
                sbTxDin <= MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentLfsrClearErrorReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendTxInitD2CResultsReq) begin
                sbTxDin <= MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentTxInitD2CResultsReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndTxInitD2CPointTestReq) begin
                sbTxDin <= MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndTxInitD2CPointTestReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendApplyDegradeReq) begin
                sbTxDin <= (flagMbinitRepairMb_ApplyWidthDegradation ? msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b000) : msgMbinitRepairMbApplyDegradeReq(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY, 3'b011));
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentApplyDegradeReq <= 1'b1;
              end
              else if (flagMbinitRepairMb_SendEndReq) begin
                sbTxDin <= MBINIT_REPAIRMB_END_REQ;
                sbTxValid <= 1'b1;
                flagMbinitRepairMb_SentEndReq <= 1'b1;
              end
            end
          end
          MBInitState_DONE: begin
            stateReg <= MBInitState_DONE;
          end
          default: ;
        endcase
      end
    end
  end
endmodule

`default_nettype wire
