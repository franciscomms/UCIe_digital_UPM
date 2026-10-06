/*
TODO:
    - maybe io.sb_tx_valid / io.sb_tx_din connected directly on top intead of MUX
    - check variables and IOs resets
    - confirm the lane reversal will be fixed until we train again
    - RepairMbSenderState do state where not all lanes are correct
*/

package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

class MBInitFSM(
  designParams: DesignParams = DesignParams()
) extends Module {
  val io = IO(new Bundle {
    val start = Input(Bool())
    val busy = Output(Bool())
    val done = Output(Bool())
    val trainError = Output(Bool())

    val sb_tx_din = Output(UInt(64.W))
    val sb_tx_valid = Output(Bool())
    val sb_tx_ready = Input(Bool())
    //on LTSM:  io.sb_tx_valid := Mux(stateReg === LTState.MBINIT_SUPER, mbInitFsm.io.sb_tx_valid, sbTxValid)
    //          io.sb_tx_din := Mux(stateReg === LTState.MBINIT_SUPER, mbInitFsm.io.sb_tx_din, sbTxDin)

    val sb_rx_dout = Input(UInt(64.W))
    val sb_rx_valid = Input(Bool())

    val flagFromAnalog_ReadyToExchangeClkPatterns = Input(Bool())
    val flagFromAnalog_FinishedClkPatterns = Input(Bool())
    val flagFromAnalog_FinishedValTrainPattern = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRTRK_L = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKN_L = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKP_L = Input(Bool())
    val flagFromAnalog_ValTrainPatternReceived = Input(Bool())
    
    val flagFromAnalog_ReversalMbFinishedLaneIDPattern = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived0 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived1 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived2 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived3 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived4 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived5 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived6 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived7 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived8 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived9 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived10 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived11 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived12 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived13 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived14 = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived15 = Input(Bool())
    val flagFromAnalog_RepairMbFinishedLaneIDPattern = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern0 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern1 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern2 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern3 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern4 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern5 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern6 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern7 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern8 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern9 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern10 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern11 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern12 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern13 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern14 = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern15 = Input(Bool())

    val flagToAnalog_RepairClkState = Output(Bool())
    val flagToAnalog_SendClkPatterns = Output(Bool())
    val flagToAnalog_RepairValState = Output(Bool())
    val flagToAnalog_SendValTrainPattern = Output(Bool())
    val flagToAnalog_RepairMbSendLaneIDPattern = Output(Bool())
    val flagToAnalog_RepairMbSetReceiver = Output(Bool())
    val flagToAnalog_ReversalMbSendLaneIDPattern = Output(Bool())
    val flagToAnalog_LaneReversalApplied = Output(Bool())

    val substate = Output(UInt(3.W))
    val dbg_mbinitRepairClkSenderState = Output(UInt(3.W))
    val dbg_mbinitRepairClkReceiverState = Output(UInt(3.W))
    val dbg_mbinitRepairValSenderState = Output(UInt(3.W))
    val dbg_mbinitRepairValReceiverState = Output(UInt(3.W))
    val dbg_mbinitReversalMbReceivedSuccessCount = Output(UInt(5.W))
  })














  object MBInitState extends ChiselEnum {
    val PARAM, // 0x00
      CAL, // 0x01
      REPAIRCLK, // 0x02
      REPAIRVAL, // 0x03
      REVERSALMB, // 0x04
      REPAIRMB, // 0x05
      DONE = Value // 0x06
  }

  object ParamSenderState extends ChiselEnum {
    val sendReqHeader, // 0x00
      sendReqPayload, // 0x01
      waitResp, // 0x02
      finish = Value // 0x03
  }

  object ParamReceiverState extends ChiselEnum {
    val waitReq, // 0x00
      validateReqPayload, // 0x01
      sendRespHeader, // 0x02
      sendRespPayload, // 0x03
      finish = Value // 0x04
  }

  object CalSenderState extends ChiselEnum {
    val sendDoneReq, // 0x00
      waitDoneResp, // 0x01
      finish = Value // 0x02
  }

  object CalReceiverState extends ChiselEnum {
    val waitDoneReq, // 0x00
      sendDoneResp, // 0x01
      finish = Value // 0x02
  }

  object RepairClkSenderState extends ChiselEnum {
    val initReq, // 0x00
      sendClkPatternsExchange, // 0x01
      waitingPatternsExchangeFinish, // 0x02
      sendResultReq, // 0x03
      receiveResultResp, // 0x04
      sendDoneReq, // 0x05
      receiveDoneResp, // 0x06
      finish = Value // 0x07
  }

  object RepairClkReceiverState extends ChiselEnum {
    val sendInitResp, // 0x00
      waitingPatternsExchangeFinish, // 0x01
      sendResultResp, // 0x02
      receiveDoneReq, // 0x03
      sendDoneResp, // 0x04
      finish = Value // 0x05
  }

  object RepairValSenderState extends ChiselEnum {
    val initReq, // 0x00
      sendValTrainPattern, // 0x01
      waitingValTrainPatternFinish, // 0x02
      sendResultReq, // 0x03
      receiveResultResp, // 0x04
      sendDoneReq, // 0x05
      receiveDoneResp, // 0x06
      finish = Value // 0x07
  }

  object RepairValReceiverState extends ChiselEnum {
    val sendInitResp, // 0x00
      waitingValTrainPatternFinish, // 0x01
      sendResultResp, // 0x02
      receiveDoneReq, // 0x03
      sendDoneResp, // 0x04
      finish = Value // 0x05
  }

  object ReversalMbSenderState extends ChiselEnum {
    val initReq, // 0x00
      waitInitResp, // 0x01
      sendClearErrorReq, // 0x02
      waitClearErrorResp, // 0x03
      sendLaneIDPattern, // 0x04
      waitingLaneIDPatternFinish, // 0x05
      sendResultReq, // 0x06
      waitResultResp, // 0x07
      sendDoneReq, // 0x08
      waitDoneResp, // 0x09
      finish = Value // 0x0A
  }

  object ReversalMbReceiverState extends ChiselEnum {
    val sendInitResp, // 0x00
      waitClearErrorReq, // 0x01
      sendClearErrorResp, // 0x02
      waitResultReq, // 0x03
      sendResultRespHeader, // 0x04
      sendResultRespPayload, // 0x05
      waitDoneReqOrClearErrorReq, // 0x06
      sendDoneResp, // 0x07
      finish = Value // 0x08
  }

  object RepairMbSenderState extends ChiselEnum {
    val sendStartReq, // 0x00
      waitStartResp, // 0x01
      d2cPointTestSendReqHeader, // 0x02
      d2cPointTestSendReqPayload, // 0x03
      d2cPointTestWaitResp, // 0x04
      d2cPointTestLfsrClearErrorSendReq, // 0x05
      d2cPointTestLfsrClearErrorWaitResp, // 0x06
      sendLaneIDPattern, // 0x07
      waitingLaneIDPatternFinish, // 0x08
      txInitD2CResultsSendReq, // 0x09
      txInitD2CResultsWaitResp, // 0x0A
      endTxInitD2CPointTestSendReq, // 0x0B
      endTxInitD2CPointTestWaitResp, // 0x0C
      analyzeWidthDegradation, // 0x0D
      sendApplyDegradeReq, // 0x0E
      waitApplyDegradeResp, // 0x0F
      sendEndReq, // 0x10
      waitEndResp, // 0x11
      finish = Value // 0x12
  }

  object RepairMbReceiverState extends ChiselEnum {
    val waitStartReq, // 0x00
      sendStartResp, // 0x01
      waitD2CPointTestReq, // 0x02
      setReceiver, // 0x03
      sendD2CPointTestResp, // 0x04
      waitLfsrClearErrorReq, // 0x05
      sendLfsrClearErrorResp, // 0x06
      waitTxInitD2CResultsReq, // 0x07
      sendTxInitD2CResultsRespHeader, // 0x08
      sendTxInitD2CResultsRespPayload, // 0x09
      waitEndTxInitD2CPointTestReq, // 0x0A
      sendEndTxInitD2CPointTestResp, // 0x0B
        waitApplyDegradeReq, // 0x0C
        sendApplyDegradeResp, // 0x0D
      finish = Value // 0x0E
  }












  // maybe do valid hold-until-accepted
  val sbTxValid = RegInit(false.B)
  val sbTxDin = RegInit(0.U(64.W))
  val nextSbTxValid = WireDefault(false.B)
  val nextSbTxDin = WireDefault(0.U(64.W))
  sbTxValid := nextSbTxValid
  sbTxDin := nextSbTxDin
  io.sb_tx_valid := sbTxValid
  io.sb_tx_din := sbTxDin

  val trainErrorReg = RegInit(false.B)
  io.trainError := trainErrorReg

  val running = RegInit(false.B)
  val stateReg = RegInit(MBInitState.PARAM)

  val prevStart = RegNext(io.start, false.B)
  val startPulse = io.start && !prevStart

  val prevRxValid = RegNext(io.sb_rx_valid, false.B)
  val rxValidRisingEdge = io.sb_rx_valid && (!prevRxValid)

  val flagMbinitParam_ReceivedReqHeader = RegInit(false.B)
  val flagMbinitParam_ReqWaitingPayload = RegInit(false.B)
  val flagMbinitParam_ReceivedReqPayload = RegInit(false.B)
  val flagMbinitParam_SentReqHdr = RegInit(false.B)
  val flagMbinitParam_SentReqPayload = RegInit(false.B)
  val flagMbinitParam_ReceivedRespHeader = RegInit(false.B)
  val flagMbinitParam_ReceivedRespPayload = RegInit(false.B)
  val flagMbinitParam_RespWaitingPayload = RegInit(false.B)
  val flagMbinitParam_SentRespHdr = RegInit(false.B)
  val flagMbinitParam_SentRespPayload = RegInit(false.B)
  val flagMbinitParam_SendReqHeader = RegInit(false.B)
  val flagMbinitParam_SendReqPayload = RegInit(false.B)
  val flagMbinitParam_SendRespHeader = RegInit(false.B)
  val flagMbinitParam_SendRespPayload = RegInit(false.B)
  val flagMbinitParam_ReceivedCorrectReq = RegInit(false.B)
  val paramSenderStateReg = RegInit(ParamSenderState.sendReqHeader)
  val paramReceiverStateReg = RegInit(ParamReceiverState.waitReq)

  val flagMbinitCal_ReceivedDoneReq = RegInit(false.B)
  val flagMbinitCal_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitCal_SentDoneReq = RegInit(false.B)
  val flagMbinitCal_SentDoneResp = RegInit(false.B)
  val flagMbinitCal_SendDoneReq = RegInit(false.B)
  val flagMbinitCal_SendDoneResp = RegInit(false.B)
  val calSenderStateReg = RegInit(CalSenderState.sendDoneReq)
  val calReceiverStateReg = RegInit(CalReceiverState.waitDoneReq)

  val flagMbinitRepairClk_ReceivedInitResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedInitReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneReq = RegInit(false.B)
  val flagMbinitRepairClk_SentInitReq = RegInit(false.B)
  val flagMbinitRepairClk_SentResultReq = RegInit(false.B)
  val flagMbinitRepairClk_SentDoneReq = RegInit(false.B)
  val flagMbinitRepairClk_SentInitResp = RegInit(false.B)
  val flagMbinitRepairClk_SentResultResp = RegInit(false.B)
  val flagMbinitRepairClk_SentDoneResp = RegInit(false.B)
  val flagMbinitRepairClk_SendInitReq = RegInit(false.B)
  val flagMbinitRepairClk_SendResultReq = RegInit(false.B)
  val flagMbinitRepairClk_SendDoneReq = RegInit(false.B)
  val flagMbinitRepairClk_SendInitResp = RegInit(false.B)
  val flagMbinitRepairClk_SendResultResp = RegInit(false.B)
  val flagMbinitRepairClk_SendDoneResp = RegInit(false.B)
  val mbinitRepairClk_ReceivedResultBits = RegInit(0.U(3.W))
  val repairClkSenderStateReg = RegInit(RepairClkSenderState.initReq)
  val repairClkReceiverStateReg = RegInit(RepairClkReceiverState.sendInitResp)
  val flagMbinitRepairVal_SentInitReq = RegInit(false.B)
  val flagMbinitRepairVal_SentResultReq = RegInit(false.B)
  val flagMbinitRepairVal_SentDoneReq = RegInit(false.B)
  val flagMbinitRepairVal_SentInitResp = RegInit(false.B)
  val flagMbinitRepairVal_SentResultResp = RegInit(false.B)
  val flagMbinitRepairVal_SentDoneResp = RegInit(false.B)

  val flagMbinitRepairVal_ReceivedInitResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedInitReq = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedResultReq = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedDoneReq = RegInit(false.B)
  val flagMbinitRepairVal_SendInitReq = RegInit(false.B)
  val flagMbinitRepairVal_SendResultReq = RegInit(false.B)
  val flagMbinitRepairVal_SendDoneReq = RegInit(false.B)
  val flagMbinitRepairVal_SendInitResp = RegInit(false.B)
  val flagMbinitRepairVal_SendResultResp = RegInit(false.B)
  val flagMbinitRepairVal_SendDoneResp = RegInit(false.B)
  val mbinitRepairVal_ReceivedResultBit = RegInit(false.B)
  val mbinitRepairVal_logValTrainPatternReceived = RegInit(false.B)
  val repairValSenderStateReg = RegInit(RepairValSenderState.initReq)
  val repairValReceiverStateReg = RegInit(RepairValReceiverState.sendInitResp)

  val flagMbinitReversalMb_ReceivedInitReq = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedInitResp = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedClearErrorReq = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedClearErrorResp = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedResultReq = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedResultRespHeader = RegInit(false.B)
  val flagMbinitReversalMb_ResultRespWaitingPayload = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedResultRespPayload = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedDoneReq = RegInit(false.B)
  val flagMbinitReversalMb_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitReversalMb_SendInitReq = RegInit(false.B)
  val flagMbinitReversalMb_SendClearErrorReq = RegInit(false.B)
  val flagMbinitReversalMb_SendResultReq = RegInit(false.B)
  val flagMbinitReversalMb_SendDoneReq = RegInit(false.B)
  val flagMbinitReversalMb_SendInitResp = RegInit(false.B)
  val flagMbinitReversalMb_SendClearErrorResp = RegInit(false.B)
  val flagMbinitReversalMb_SendResultRespHeader = RegInit(false.B)
  val flagMbinitReversalMb_SendResultRespPayload = RegInit(false.B)
  val flagMbinitReversalMb_SendDoneResp = RegInit(false.B)
  val flagMbinitReversalMb_SentInitReq = RegInit(false.B)
  val flagMbinitReversalMb_SentClearErrorReq = RegInit(false.B)
  val flagMbinitReversalMb_SentResultReq = RegInit(false.B)
  val flagMbinitReversalMb_SentDoneReq = RegInit(false.B)
  val flagMbinitReversalMb_SentInitResp = RegInit(false.B)
  val flagMbinitReversalMb_SentClearErrorResp = RegInit(false.B)
  val flagMbinitReversalMb_SentResultRespHeader = RegInit(false.B)
  val flagMbinitReversalMb_SentResultRespPayload = RegInit(false.B)
  val flagMbinitReversalMb_SentDoneResp = RegInit(false.B)
  val reversalMbSenderStateReg = RegInit(ReversalMbSenderState.initReq)
  val reversalMbReceiverStateReg = RegInit(ReversalMbReceiverState.sendInitResp)
  
  val flagMbinitRepairMb_ReceivedStartReq = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedStartResp = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedD2CPointTestReqHeader = RegInit(false.B)
  val flagMbinitRepairMb_D2CPointTestReqWaitingPayload = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedD2CPointTestReqPayload = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedLfsrClearErrorReq = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedTxInitD2CResultsReq = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedLfsrClearErrorResp = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader = RegInit(false.B)
  val flagMbinitRepairMb_TxInitD2CResultsRespWaitingPayload = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedApplyDegradeReq = RegInit(false.B)
  val mbinitRepairMb_ReceivedApplyDegradeReqLaneMap = RegInit(0.U(3.W))
  val flagMbinitRepairMb_ReceivedApplyDegradeResp = RegInit(false.B)
  val flagMbinitRepairMb_ReceivedEndResp = RegInit(false.B)
  val flagMbinitRepairMb_ApplyWidthDegradation = RegInit(false.B)
  val mbinitRepairMb_TxInitD2CResultsRespMsgInfo = RegInit(0.U(16.W))
  val mbinitRepairMb_TxInitD2CResultsRespPayload = RegInit(0.U(64.W))
  val mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits = RegInit(0.U(16.W))
  val flagMbinitRepairMb_SendStartReq = RegInit(false.B)
  val flagMbinitRepairMb_SendD2CPointTestReqHeader = RegInit(false.B)
  val flagMbinitRepairMb_SendD2CPointTestReqPayload = RegInit(false.B)
  val flagMbinitRepairMb_SendLfsrClearErrorReq = RegInit(false.B)
  val flagMbinitRepairMb_SendTxInitD2CResultsReq = RegInit(false.B)
  val flagMbinitRepairMb_SendEndTxInitD2CPointTestReq = RegInit(false.B)
  val flagMbinitRepairMb_SendApplyDegradeReq = RegInit(false.B)
  val flagMbinitRepairMb_SendEndReq = RegInit(false.B)
  val flagMbinitRepairMb_SendStartResp = RegInit(false.B)
  val flagMbinitRepairMb_SendD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_SendLfsrClearErrorResp = RegInit(false.B)
  val flagMbinitRepairMb_SendTxInitD2CResultsRespHeader = RegInit(false.B)
  val flagMbinitRepairMb_SendTxInitD2CResultsRespPayload = RegInit(false.B)
  val flagMbinitRepairMb_SendEndTxInitD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_SendApplyDegradeResp = RegInit(false.B)
  val flagMbinitRepairMb_SentStartReq = RegInit(false.B)
  val flagMbinitRepairMb_SentD2CPointTestReqHeader = RegInit(false.B)
  val flagMbinitRepairMb_SentD2CPointTestReqPayload = RegInit(false.B)
  val flagMbinitRepairMb_SentLfsrClearErrorReq = RegInit(false.B)
  val flagMbinitRepairMb_SentTxInitD2CResultsReq = RegInit(false.B)
  val flagMbinitRepairMb_SentEndTxInitD2CPointTestReq = RegInit(false.B)
  val flagMbinitRepairMb_SentApplyDegradeReq = RegInit(false.B)
  val flagMbinitRepairMb_SentEndReq = RegInit(false.B)
  val flagMbinitRepairMb_SentStartResp = RegInit(false.B)
  val flagMbinitRepairMb_SentD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_SentLfsrClearErrorResp = RegInit(false.B)
  val flagMbinitRepairMb_SentTxInitD2CResultsRespHeader = RegInit(false.B)
  val flagMbinitRepairMb_SentTxInitD2CResultsRespPayload = RegInit(false.B)
  val flagMbinitRepairMb_SentEndTxInitD2CPointTestResp = RegInit(false.B)
  val flagMbinitRepairMb_SentApplyDegradeResp = RegInit(false.B)
  val flagMbinitRepairMb_SentEndResp = RegInit(false.B)
  val repairMbSenderStateReg = RegInit(RepairMbSenderState.sendStartReq)
  val repairMbReceiverStateReg = RegInit(RepairMbReceiverState.waitStartReq)
  val repairMb_DetectedLaneIDPatternLog = RegInit(0.U(16.W))
  val reversalMbLaneStatusLog = RegInit(0.U(16.W))
  val reversalMb_LaneReversalApplied = RegInit(false.B)

  val reversalMb_ReceivedSuccessCount = RegInit(0.U(5.W))

  val mbinitRepairClk_logClkPatternReceivedRTRK_L = RegInit(false.B)
  val mbinitRepairClk_logClkPatternReceivedRCKN_L = RegInit(false.B)
  val mbinitRepairClk_logClkPatternReceivedRCKP_L = RegInit(false.B)

  val remoteParamReqPayload = RegInit(0.U(64.W))
  val remoteParamRespPayload = RegInit(0.U(64.W))
























  val MBINIT_PARAM_REQ = SidebandMsgGenerator.msgMbinitParamConfigReq(
    "phy",
    "phy",
    designParams.sbFeatureExtension,
    designParams.ucieA,
    designParams.moduleID,
    designParams.clkPhase,
    designParams.clkMode,
    designParams.voltageSwing,
    designParams.maxLinkSpeed
  )
  val MBINIT_PARAM_RESP = SidebandMsgGenerator.msgMbinitParamConfigResp(
    "phy",
    "phy",
    designParams.clkPhase,
    designParams.clkMode,
    designParams.maxLinkSpeed
  )
  val MBINIT_CAL_DONE_REQ = SidebandMsgGenerator.msgMbinitCalDoneReq("phy", "phy")
  val MBINIT_CAL_DONE_RESP = SidebandMsgGenerator.msgMbinitCalDoneResp("phy", "phy")
  val MBINIT_REPAIRCLK_INIT_RESP = SidebandMsgGenerator.msgMbinitRepairClkInitResp("phy", "phy")
  val MBINIT_REPAIRCLK_RESULT_RESP = SidebandMsgGenerator.msgMbinitRepairClkResultResp(
    "phy",
    "phy",
    0.U(1.W),
    0.U(1.W),
    0.U(1.W)
  )
  val MBINIT_REPAIRCLK_DONE_RESP = SidebandMsgGenerator.msgMbinitRepairClkDoneResp("phy", "phy")
  val MBINIT_REPAIRVAL_INIT_RESP = SidebandMsgGenerator.msgMbinitRepairValInitResp("phy", "phy")
  val MBINIT_REPAIRVAL_RESULT_RESP = SidebandMsgGenerator.msgMbinitRepairValResultResp(
    "phy",
    "phy",
    0.U(1.W)
  )
  val MBINIT_REPAIRVAL_DONE_RESP = SidebandMsgGenerator.msgMbinitRepairValDoneResp("phy", "phy")
  val MBINIT_REVERSALMB_INIT_RESP = SidebandMsgGenerator.msgMbinitReversalMbInitResp("phy", "phy")
  val MBINIT_REVERSALMB_CLEAR_ERROR_RESP = SidebandMsgGenerator.msgMbinitReversalMbClearErrorResp("phy", "phy")
  val MBINIT_REVERSALMB_RESULT_RESP = SidebandMsgGenerator.msgMbinitReversalMbResultResp("phy", "phy", 0.U(16.W))
  val MBINIT_REVERSALMB_DONE_REQ = SidebandMsgGenerator.msgMbinitReversalMbDoneReq("phy", "phy")
  val MBINIT_REVERSALMB_DONE_RESP = SidebandMsgGenerator.msgMbinitReversalMbDoneResp("phy", "phy")
  val MBINIT_REPAIRMB_START_RESP = SidebandMsgGenerator.msgMbinitRepairMbStartResp("phy", "phy")
  val MBINIT_REPAIRMB_D2C_POINT_TEST_REQ = SidebandMsgGenerator.msgMbinitRepairMbStartTxInitD2CPointTestReq(
    "phy",
    "phy",
    0.U(16.W),
    0.U(1.W),
    "h0080".U(16.W),
    0.U(16.W),
    0.U(16.W),
    0.U(1.W),
    0.U(4.W),
    0.U(3.W),
    1.U(3.W)
  )
  val MBINIT_REPAIRMB_D2C_POINT_TEST_RESP = SidebandMsgGenerator.msgMbinitRepairMbStartTxInitD2CPointTestResp("phy", "phy")
  val MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP = SidebandMsgGenerator.msgMbinitRepairMbLfsrClearErrorResp("phy", "phy")
  val MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ = SidebandMsgGenerator.msgMbinitRepairMbTxInitD2CResultsReq("phy", "phy")
  val MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP = SidebandMsgGenerator.msgMbinitRepairMbTxInitD2CResultsResp(
    "phy",
    "phy",
    0.U(16.W),
    0.U(64.W)
  )
  val MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ = SidebandMsgGenerator.msgMbinitRepairMbEndTxInitD2CPointTestReq("phy", "phy")
  val MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP = SidebandMsgGenerator.msgMbinitRepairMbEndTxInitD2CPointTestResp("phy", "phy")
  val MBINIT_REPAIRMB_APPLY_DEGRADE_RESP = SidebandMsgGenerator.msgMbinitRepairMbApplyDegradeResp("phy", "phy")
  val MBINIT_REPAIRMB_END_REQ = SidebandMsgGenerator.msgMbinitRepairMbEndReq("phy", "phy")
  val MBINIT_REPAIRMB_END_RESP = SidebandMsgGenerator.msgMbinitRepairMbEndResp("phy", "phy")






  io.flagToAnalog_RepairClkState := false.B
  io.flagToAnalog_SendClkPatterns := false.B
  io.flagToAnalog_RepairValState := false.B
  io.flagToAnalog_SendValTrainPattern := false.B
  io.flagToAnalog_RepairMbSendLaneIDPattern := false.B
  io.flagToAnalog_RepairMbSetReceiver := false.B
  io.flagToAnalog_ReversalMbSendLaneIDPattern := false.B
  io.flagToAnalog_LaneReversalApplied := reversalMb_LaneReversalApplied

  io.substate := stateReg.asUInt
  io.dbg_mbinitRepairClkSenderState := repairClkSenderStateReg.asUInt
  io.dbg_mbinitRepairClkReceiverState := repairClkReceiverStateReg.asUInt
  io.dbg_mbinitRepairValSenderState := repairValSenderStateReg.asUInt
  io.dbg_mbinitRepairValReceiverState := repairValReceiverStateReg.asUInt
  io.dbg_mbinitReversalMbReceivedSuccessCount := reversalMb_ReceivedSuccessCount

  io.done := running && (stateReg === MBInitState.DONE)
  io.busy := running && (stateReg =/= MBInitState.DONE)























  when(startPulse) {
    running := true.B
    stateReg := MBInitState.PARAM
    trainErrorReg := false.B

    flagMbinitParam_ReceivedReqHeader := false.B
    flagMbinitParam_ReqWaitingPayload := false.B
    flagMbinitParam_ReceivedReqPayload := false.B
    flagMbinitParam_SentReqHdr := false.B
    flagMbinitParam_SentReqPayload := false.B
    flagMbinitParam_ReceivedRespHeader := false.B
    flagMbinitParam_ReceivedRespPayload := false.B
    flagMbinitParam_RespWaitingPayload := false.B
    flagMbinitParam_SentRespHdr := false.B
    flagMbinitParam_SentRespPayload := false.B
    flagMbinitParam_SendReqHeader := false.B
    flagMbinitParam_SendReqPayload := false.B
    flagMbinitParam_SendRespHeader := false.B
    flagMbinitParam_SendRespPayload := false.B
    flagMbinitParam_ReceivedCorrectReq := false.B
    paramSenderStateReg := ParamSenderState.sendReqHeader
    paramReceiverStateReg := ParamReceiverState.waitReq

    flagMbinitCal_ReceivedDoneReq := false.B
    flagMbinitCal_ReceivedDoneResp := false.B
    flagMbinitCal_SentDoneReq := false.B
    flagMbinitCal_SentDoneResp := false.B
    flagMbinitCal_SendDoneReq := false.B
    flagMbinitCal_SendDoneResp := false.B
    calSenderStateReg := CalSenderState.sendDoneReq
    calReceiverStateReg := CalReceiverState.waitDoneReq

    flagMbinitRepairClk_ReceivedInitResp := false.B
    flagMbinitRepairClk_ReceivedInitReq := false.B
    flagMbinitRepairClk_ReceivedResultResp := false.B
    flagMbinitRepairClk_ReceivedResultReq := false.B
    flagMbinitRepairClk_ReceivedDoneResp := false.B
    flagMbinitRepairClk_ReceivedDoneReq := false.B
    flagMbinitRepairClk_SentInitReq := false.B
    flagMbinitRepairClk_SentResultReq := false.B
    flagMbinitRepairClk_SentDoneReq := false.B
    flagMbinitRepairClk_SentInitResp := false.B
    flagMbinitRepairClk_SentResultResp := false.B
    flagMbinitRepairClk_SentDoneResp := false.B
    flagMbinitRepairClk_SendInitReq := false.B
    flagMbinitRepairClk_SendResultReq := false.B
    flagMbinitRepairClk_SendDoneReq := false.B
    flagMbinitRepairClk_SendInitResp := false.B
    flagMbinitRepairClk_SendResultResp := false.B
    flagMbinitRepairClk_SendDoneResp := false.B
    mbinitRepairClk_ReceivedResultBits := 0.U
    repairClkSenderStateReg := RepairClkSenderState.initReq
    repairClkReceiverStateReg := RepairClkReceiverState.sendInitResp

    flagMbinitRepairVal_SentInitReq := false.B
    flagMbinitRepairVal_SentResultReq := false.B
    flagMbinitRepairVal_SentDoneReq := false.B
    flagMbinitRepairVal_SentInitResp := false.B
    flagMbinitRepairVal_SentResultResp := false.B
    flagMbinitRepairVal_SentDoneResp := false.B

    flagMbinitRepairVal_ReceivedInitResp := false.B
    flagMbinitRepairVal_ReceivedInitReq := false.B
    flagMbinitRepairVal_ReceivedResultResp := false.B
    flagMbinitRepairVal_ReceivedResultReq := false.B
    flagMbinitRepairVal_ReceivedDoneResp := false.B
    flagMbinitRepairVal_ReceivedDoneReq := false.B
    flagMbinitRepairVal_SendInitReq := false.B
    flagMbinitRepairVal_SendResultReq := false.B
    flagMbinitRepairVal_SendDoneReq := false.B
    flagMbinitRepairVal_SendInitResp := false.B
    flagMbinitRepairVal_SendResultResp := false.B
    flagMbinitRepairVal_SendDoneResp := false.B
    mbinitRepairVal_ReceivedResultBit := false.B
    mbinitRepairVal_logValTrainPatternReceived := false.B
    repairValSenderStateReg := RepairValSenderState.initReq
    repairValReceiverStateReg := RepairValReceiverState.sendInitResp
    flagMbinitReversalMb_ReceivedInitReq := false.B
    flagMbinitReversalMb_ReceivedInitResp := false.B
    flagMbinitReversalMb_ReceivedClearErrorReq := false.B
    flagMbinitReversalMb_ReceivedClearErrorResp := false.B
    flagMbinitReversalMb_ReceivedResultReq := false.B
    flagMbinitReversalMb_ReceivedResultRespHeader := false.B
    flagMbinitReversalMb_ResultRespWaitingPayload := false.B
    flagMbinitReversalMb_ReceivedResultRespPayload := false.B
    flagMbinitReversalMb_ReceivedDoneReq := false.B
    flagMbinitReversalMb_ReceivedDoneResp := false.B
    flagMbinitReversalMb_SendInitReq := false.B
    flagMbinitReversalMb_SendClearErrorReq := false.B
    flagMbinitReversalMb_SendResultReq := false.B
    flagMbinitReversalMb_SendDoneReq := false.B
    flagMbinitReversalMb_SendInitResp := false.B
    flagMbinitReversalMb_SendClearErrorResp := false.B
    flagMbinitReversalMb_SendResultRespHeader := false.B
    flagMbinitReversalMb_SendResultRespPayload := false.B
    flagMbinitReversalMb_SendDoneResp := false.B
    flagMbinitReversalMb_SentInitReq := false.B
    flagMbinitReversalMb_SentClearErrorReq := false.B
    flagMbinitReversalMb_SentResultReq := false.B
    flagMbinitReversalMb_SentDoneReq := false.B
    flagMbinitReversalMb_SentInitResp := false.B
    flagMbinitReversalMb_SentClearErrorResp := false.B
    flagMbinitReversalMb_SentResultRespHeader := false.B
    flagMbinitReversalMb_SentResultRespPayload := false.B
    flagMbinitReversalMb_SentDoneResp := false.B
    reversalMbSenderStateReg := ReversalMbSenderState.initReq
    reversalMbReceiverStateReg := ReversalMbReceiverState.sendInitResp
    flagMbinitRepairMb_ReceivedStartReq := false.B
    flagMbinitRepairMb_ReceivedStartResp := false.B
    flagMbinitRepairMb_ReceivedD2CPointTestReqHeader := false.B
    flagMbinitRepairMb_D2CPointTestReqWaitingPayload := false.B
    flagMbinitRepairMb_ReceivedD2CPointTestReqPayload := false.B
    flagMbinitRepairMb_ReceivedLfsrClearErrorReq := false.B
    flagMbinitRepairMb_ReceivedTxInitD2CResultsReq := false.B
    flagMbinitRepairMb_ReceivedD2CPointTestResp := false.B
    flagMbinitRepairMb_ReceivedLfsrClearErrorResp := false.B
    flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader := false.B
    flagMbinitRepairMb_TxInitD2CResultsRespWaitingPayload := false.B
    flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload := false.B
    flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq := false.B
    flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp := false.B
    flagMbinitRepairMb_ReceivedApplyDegradeReq := false.B
    mbinitRepairMb_ReceivedApplyDegradeReqLaneMap := 0.U
    flagMbinitRepairMb_ReceivedApplyDegradeResp := false.B
    flagMbinitRepairMb_ReceivedEndResp := false.B
    flagMbinitRepairMb_ApplyWidthDegradation := false.B
    mbinitRepairMb_TxInitD2CResultsRespMsgInfo := 0.U
    mbinitRepairMb_TxInitD2CResultsRespPayload := 0.U
    mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits := 0.U
    flagMbinitRepairMb_SendStartReq := false.B
    flagMbinitRepairMb_SendD2CPointTestReqHeader := false.B
    flagMbinitRepairMb_SendD2CPointTestReqPayload := false.B
    flagMbinitRepairMb_SendLfsrClearErrorReq := false.B
    flagMbinitRepairMb_SendTxInitD2CResultsReq := false.B
    flagMbinitRepairMb_SendEndTxInitD2CPointTestReq := false.B
    flagMbinitRepairMb_SendApplyDegradeReq := false.B
    flagMbinitRepairMb_SendEndReq := false.B
    flagMbinitRepairMb_SendStartResp := false.B
    flagMbinitRepairMb_SendD2CPointTestResp := false.B
    flagMbinitRepairMb_SendLfsrClearErrorResp := false.B
    flagMbinitRepairMb_SendTxInitD2CResultsRespHeader := false.B
    flagMbinitRepairMb_SendTxInitD2CResultsRespPayload := false.B
    flagMbinitRepairMb_SendEndTxInitD2CPointTestResp := false.B
    flagMbinitRepairMb_SendApplyDegradeResp := false.B
    flagMbinitRepairMb_SentStartReq := false.B
    flagMbinitRepairMb_SentD2CPointTestReqHeader := false.B
    flagMbinitRepairMb_SentD2CPointTestReqPayload := false.B
    flagMbinitRepairMb_SentLfsrClearErrorReq := false.B
    flagMbinitRepairMb_SentTxInitD2CResultsReq := false.B
    flagMbinitRepairMb_SentEndTxInitD2CPointTestReq := false.B
    flagMbinitRepairMb_SentApplyDegradeReq := false.B
    flagMbinitRepairMb_SentEndReq := false.B
    flagMbinitRepairMb_SentStartResp := false.B
    flagMbinitRepairMb_SentD2CPointTestResp := false.B
    flagMbinitRepairMb_SentLfsrClearErrorResp := false.B
    flagMbinitRepairMb_SentTxInitD2CResultsRespHeader := false.B
    flagMbinitRepairMb_SentTxInitD2CResultsRespPayload := false.B
    flagMbinitRepairMb_SentEndTxInitD2CPointTestResp := false.B
    flagMbinitRepairMb_SentApplyDegradeResp := false.B
    flagMbinitRepairMb_SentEndResp := false.B
    repairMbSenderStateReg := RepairMbSenderState.sendStartReq
    repairMbReceiverStateReg := RepairMbReceiverState.waitStartReq
    repairMb_DetectedLaneIDPatternLog := 0.U
    reversalMbLaneStatusLog := 0.U
    reversalMb_LaneReversalApplied := false.B

    mbinitRepairClk_logClkPatternReceivedRTRK_L := false.B
    mbinitRepairClk_logClkPatternReceivedRCKN_L := false.B
    mbinitRepairClk_logClkPatternReceivedRCKP_L := false.B

    remoteParamReqPayload := 0.U
    remoteParamRespPayload := 0.U
  }



  when(!io.start && stateReg === MBInitState.DONE) {
    running := false.B
  }










  when(rxValidRisingEdge) { //not add "&& running" because we want to be able to receive messages even if we are not running, in order to set the correct flags and trainErrorReg in case of receiving unexpected messages when not running
    when(io.sb_rx_dout === MBINIT_PARAM_REQ(63, 0)) {
      flagMbinitParam_ReceivedReqHeader := true.B
      flagMbinitParam_ReqWaitingPayload := true.B
    }
    when(flagMbinitParam_ReqWaitingPayload) {
      flagMbinitParam_ReceivedReqPayload := true.B
      flagMbinitParam_ReqWaitingPayload := false.B
      remoteParamReqPayload := io.sb_rx_dout
    }

    when(io.sb_rx_dout === MBINIT_PARAM_RESP(63, 0)) {
      flagMbinitParam_ReceivedRespHeader := true.B
      flagMbinitParam_RespWaitingPayload := true.B
    }
    when(flagMbinitParam_RespWaitingPayload) {
      flagMbinitParam_ReceivedRespPayload := true.B
      flagMbinitParam_RespWaitingPayload := false.B
      remoteParamRespPayload := io.sb_rx_dout
    }

    when(io.sb_rx_dout === MBINIT_CAL_DONE_REQ) {
      flagMbinitCal_ReceivedDoneReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_CAL_DONE_RESP) {
      flagMbinitCal_ReceivedDoneResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")) {
      flagMbinitRepairClk_ReceivedInitReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRCLK_INIT_RESP) {
      flagMbinitRepairClk_ReceivedInitResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")) {
      flagMbinitRepairClk_ReceivedResultReq := true.B
    }

    when(
      (io.sb_rx_dout & "hBFFFF8FFFFFFFFFF".U(64.W)) ===
      (MBINIT_REPAIRCLK_RESULT_RESP & "hBFFFF8FFFFFFFFFF".U(64.W))
    ) {
      flagMbinitRepairClk_ReceivedResultResp := true.B
      mbinitRepairClk_ReceivedResultBits := io.sb_rx_dout(42, 40)
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")) {
      flagMbinitRepairClk_ReceivedDoneReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRCLK_DONE_RESP) {
      flagMbinitRepairClk_ReceivedDoneResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValInitReq("phy", "phy")) {
      flagMbinitRepairVal_ReceivedInitReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRVAL_INIT_RESP) {
      flagMbinitRepairVal_ReceivedInitResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValResultReq("phy", "phy")) {
      flagMbinitRepairVal_ReceivedResultReq := true.B
    }

    when(
      (io.sb_rx_dout & "hBFFFFEFFFFFFFFFF".U(64.W)) ===
      (MBINIT_REPAIRVAL_RESULT_RESP & "hBFFFFEFFFFFFFFFF".U(64.W))
    ) {
      flagMbinitRepairVal_ReceivedResultResp := true.B
      mbinitRepairVal_ReceivedResultBit := io.sb_rx_dout(40)
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValDoneReq("phy", "phy")) {
      flagMbinitRepairVal_ReceivedDoneReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRVAL_DONE_RESP) {
      flagMbinitRepairVal_ReceivedDoneResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitReversalMbInitReq("phy", "phy")) {
      flagMbinitReversalMb_ReceivedInitReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REVERSALMB_INIT_RESP) {
      flagMbinitReversalMb_ReceivedInitResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitReversalMbClearErrorReq("phy", "phy")) {
      flagMbinitReversalMb_ReceivedClearErrorReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REVERSALMB_CLEAR_ERROR_RESP) {
      flagMbinitReversalMb_ReceivedClearErrorResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitReversalMbResultReq("phy", "phy")) {
      flagMbinitReversalMb_ReceivedResultReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REVERSALMB_RESULT_RESP(63, 0)) {
      flagMbinitReversalMb_ReceivedResultRespHeader := true.B
      flagMbinitReversalMb_ResultRespWaitingPayload := true.B
    }
    when(flagMbinitReversalMb_ResultRespWaitingPayload) {
      flagMbinitReversalMb_ReceivedResultRespPayload := true.B
      flagMbinitReversalMb_ResultRespWaitingPayload := false.B
      reversalMb_ReceivedSuccessCount := PopCount(io.sb_rx_dout(15, 0))
    }

    when(io.sb_rx_dout === MBINIT_REVERSALMB_DONE_REQ) {
      flagMbinitReversalMb_ReceivedDoneReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REVERSALMB_DONE_RESP) {
      flagMbinitReversalMb_ReceivedDoneResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairMbStartReq("phy", "phy")) {
      flagMbinitRepairMb_ReceivedStartReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_START_RESP) {
      flagMbinitRepairMb_ReceivedStartResp := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_D2C_POINT_TEST_REQ(63, 0)) {
      flagMbinitRepairMb_ReceivedD2CPointTestReqHeader := true.B
      flagMbinitRepairMb_D2CPointTestReqWaitingPayload := true.B
    }
    when(flagMbinitRepairMb_D2CPointTestReqWaitingPayload) {
      flagMbinitRepairMb_ReceivedD2CPointTestReqPayload := true.B
      flagMbinitRepairMb_D2CPointTestReqWaitingPayload := false.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_D2C_POINT_TEST_RESP) {
      flagMbinitRepairMb_ReceivedD2CPointTestResp := true.B
    }

    when(io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairMbLfsrClearErrorReq("phy", "phy")) {
      flagMbinitRepairMb_ReceivedLfsrClearErrorReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP) {
      flagMbinitRepairMb_ReceivedLfsrClearErrorResp := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ) {
      flagMbinitRepairMb_ReceivedTxInitD2CResultsReq := true.B
    }

    when(
      //confirm the mask is correct
      (io.sb_rx_dout & "h3F0000FFFFFFFFFF".U(64.W)) ===
      (MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_RESP(63, 0) & "h3F0000FFFFFFFFFF".U(64.W))
    ) {
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespHeader := true.B
      flagMbinitRepairMb_TxInitD2CResultsRespWaitingPayload := true.B
      mbinitRepairMb_TxInitD2CResultsRespMsgInfo := io.sb_rx_dout(55, 40)
    }
    when(flagMbinitRepairMb_TxInitD2CResultsRespWaitingPayload) {
      flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload := true.B
      flagMbinitRepairMb_TxInitD2CResultsRespWaitingPayload := false.B
      mbinitRepairMb_TxInitD2CResultsRespPayload := io.sb_rx_dout
      mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits := io.sb_rx_dout(15, 0) //only for UCIe-S
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ) {
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP) {
      flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp := true.B
    }

    when(
      (io.sb_rx_dout & "hBFFFF8FFFFFFFFFF".U(64.W)) ===
      (SidebandMsgGenerator.msgMbinitRepairMbApplyDegradeReq("phy", "phy", 0.U(3.W)) & "hBFFFF8FFFFFFFFFF".U(64.W))
    ) {
      flagMbinitRepairMb_ReceivedApplyDegradeReq := true.B
      mbinitRepairMb_ReceivedApplyDegradeReqLaneMap := io.sb_rx_dout(42, 40)
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_APPLY_DEGRADE_RESP) {
      flagMbinitRepairMb_ReceivedApplyDegradeResp := true.B
    }

    when(io.sb_rx_dout === MBINIT_REPAIRMB_END_RESP) {
      flagMbinitRepairMb_ReceivedEndResp := true.B
    }
  }























  when(running) {
    switch(stateReg) {
      is(MBInitState.PARAM) {
        //SENDER
        switch(paramSenderStateReg) {
          is(ParamSenderState.sendReqHeader) {
            when(flagMbinitParam_SentReqHdr) {
              flagMbinitParam_SendReqHeader := false.B
              paramSenderStateReg := ParamSenderState.sendReqPayload
            }.otherwise {
              flagMbinitParam_SendReqHeader := true.B
            }
          }
          is(ParamSenderState.sendReqPayload) {
            when(flagMbinitParam_SentReqPayload) {
              flagMbinitParam_SendReqPayload := false.B
              paramSenderStateReg := ParamSenderState.waitResp
            }.otherwise {
              flagMbinitParam_SendReqPayload := true.B
            }
          }
          is(ParamSenderState.waitResp) {
            when(flagMbinitParam_ReceivedRespHeader && flagMbinitParam_ReceivedRespPayload) {
              paramSenderStateReg := ParamSenderState.finish
            }
          }
        }

        //RECEIVER
        switch(paramReceiverStateReg) {
          is(ParamReceiverState.waitReq) {
            when(flagMbinitParam_ReceivedReqHeader && flagMbinitParam_ReceivedReqPayload) {
              paramReceiverStateReg := ParamReceiverState.validateReqPayload
            }
          }
          is(ParamReceiverState.validateReqPayload) {
            //only correct if exactly match the expected parameters
            when(remoteParamReqPayload === MBINIT_PARAM_REQ(127, 64)) {
              flagMbinitParam_ReceivedCorrectReq := true.B
              paramReceiverStateReg := ParamReceiverState.sendRespHeader
            }.otherwise {
              trainErrorReg := true.B
            }
          }
          is(ParamReceiverState.sendRespHeader) {
            when(flagMbinitParam_SentRespHdr) {
              flagMbinitParam_SendRespHeader := false.B
              paramReceiverStateReg := ParamReceiverState.sendRespPayload
            }.otherwise {
              flagMbinitParam_SendRespHeader := true.B
            }
          }
          is(ParamReceiverState.sendRespPayload) {
            when(flagMbinitParam_SentRespPayload) {
              flagMbinitParam_SendRespPayload := false.B
              paramReceiverStateReg := ParamReceiverState.finish
            }.otherwise {
              flagMbinitParam_SendRespPayload := true.B
            }
          }
        }


        // Centralized TX arbitration for PARAM sender/receiver requests.
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitParam_SendRespHeader) {
            nextSbTxDin := MBINIT_PARAM_RESP(63, 0)
            nextSbTxValid := true.B
            flagMbinitParam_SentRespHdr := true.B
          }.elsewhen(flagMbinitParam_SendRespPayload) {
            nextSbTxDin := MBINIT_PARAM_RESP(127, 64)
            nextSbTxValid := true.B
            flagMbinitParam_SentRespPayload := true.B
          }.elsewhen(flagMbinitParam_SendReqHeader) {
            nextSbTxDin := MBINIT_PARAM_REQ(63, 0)
            nextSbTxValid := true.B
            flagMbinitParam_SentReqHdr := true.B
          }.elsewhen(flagMbinitParam_SendReqPayload) {
            nextSbTxDin := MBINIT_PARAM_REQ(127, 64)
            nextSbTxValid := true.B
            flagMbinitParam_SentReqPayload := true.B
          }
        }

      //Finish PARAM state and move to CAL state
      //    all message flags reseted here
        when(
          paramSenderStateReg === ParamSenderState.finish &&
          paramReceiverStateReg === ParamReceiverState.finish
        ) {
          flagMbinitParam_SendReqHeader := false.B
          flagMbinitParam_SendReqPayload := false.B
          flagMbinitParam_SendRespHeader := false.B
          flagMbinitParam_SendRespPayload := false.B
          flagMbinitParam_SentReqHdr := false.B
          flagMbinitParam_SentReqPayload := false.B
          flagMbinitParam_SentRespHdr := false.B
          flagMbinitParam_SentRespPayload := false.B
          stateReg := MBInitState.CAL
        }
      }

      is(MBInitState.CAL) {
        switch(calSenderStateReg) {
          is(CalSenderState.sendDoneReq) {
            when(flagMbinitCal_SentDoneReq) {
              flagMbinitCal_SendDoneReq := false.B
              calSenderStateReg := CalSenderState.waitDoneResp
            }.otherwise {
              flagMbinitCal_SendDoneReq := true.B
            }
          }
          is(CalSenderState.waitDoneResp) {
            when(flagMbinitCal_ReceivedDoneResp) {
              calSenderStateReg := CalSenderState.finish
            }
          }
        }

        switch(calReceiverStateReg) {
          is(CalReceiverState.waitDoneReq) {
            when(flagMbinitCal_ReceivedDoneReq) {
              calReceiverStateReg := CalReceiverState.sendDoneResp
            }
          }
          is(CalReceiverState.sendDoneResp) {
            when(flagMbinitCal_SentDoneResp) {
              flagMbinitCal_SendDoneResp := false.B
              calReceiverStateReg := CalReceiverState.finish
            }.otherwise {
              flagMbinitCal_SendDoneResp := true.B
            }
          }
        }

        // Centralized TX arbitration for CAL sender/receiver requests.
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitCal_SendDoneResp) {
            nextSbTxDin := MBINIT_CAL_DONE_RESP
            nextSbTxValid := true.B
            flagMbinitCal_SentDoneResp := true.B
          }.elsewhen(flagMbinitCal_SendDoneReq) {
            nextSbTxDin := MBINIT_CAL_DONE_REQ
            nextSbTxValid := true.B
            flagMbinitCal_SentDoneReq := true.B
          }
        }

        when(
          calSenderStateReg === CalSenderState.finish &&
          calReceiverStateReg === CalReceiverState.finish
        ) {
          flagMbinitCal_SendDoneReq := false.B
          flagMbinitCal_SendDoneResp := false.B
          flagMbinitCal_SentDoneReq := false.B
          flagMbinitCal_SentDoneResp := false.B
          stateReg := MBInitState.REPAIRCLK
        }
      }

      is(MBInitState.REPAIRCLK) {
        io.flagToAnalog_RepairClkState := true.B

        switch(repairClkSenderStateReg) {
          is(RepairClkSenderState.initReq) {
            when(flagMbinitRepairClk_SentInitReq) {
              flagMbinitRepairClk_SendInitReq := false.B
              repairClkSenderStateReg := RepairClkSenderState.sendClkPatternsExchange
            }.otherwise {
              flagMbinitRepairClk_SendInitReq := true.B
            }
          }
          is(RepairClkSenderState.sendClkPatternsExchange) {
            when(flagMbinitRepairClk_ReceivedInitResp && io.flagFromAnalog_ReadyToExchangeClkPatterns) {
              io.flagToAnalog_SendClkPatterns := true.B
              repairClkSenderStateReg := RepairClkSenderState.waitingPatternsExchangeFinish
            }
          }
          is(RepairClkSenderState.waitingPatternsExchangeFinish) {
            when(io.flagFromAnalog_FinishedClkPatterns) {
              repairClkSenderStateReg := RepairClkSenderState.sendResultReq
            }
          }
          is(RepairClkSenderState.sendResultReq) {
            when(flagMbinitRepairClk_SentResultReq) {
              flagMbinitRepairClk_SendResultReq := false.B
              repairClkSenderStateReg := RepairClkSenderState.receiveResultResp
            }.otherwise {
              flagMbinitRepairClk_SendResultReq := true.B
            }
          }
          is(RepairClkSenderState.receiveResultResp) {
            //all three bits corret or error
            when(flagMbinitRepairClk_ReceivedResultResp) {
              when(mbinitRepairClk_ReceivedResultBits === "b111".U) {
                repairClkSenderStateReg := RepairClkSenderState.sendDoneReq
              }.otherwise {
                trainErrorReg := true.B
              }
            }
          }
          is(RepairClkSenderState.sendDoneReq) {
            when(flagMbinitRepairClk_SentDoneReq) {
              flagMbinitRepairClk_SendDoneReq := false.B
              repairClkSenderStateReg := RepairClkSenderState.receiveDoneResp
            }.otherwise {
              flagMbinitRepairClk_SendDoneReq := true.B
            }
          }
          is(RepairClkSenderState.receiveDoneResp) {
            when(flagMbinitRepairClk_ReceivedDoneResp) {
              repairClkSenderStateReg := RepairClkSenderState.finish
            }
          }
        }

        //receiver FSM
        switch(repairClkReceiverStateReg) {
          is(RepairClkReceiverState.sendInitResp) {
            when(
              flagMbinitRepairClk_ReceivedInitReq &&
              io.flagFromAnalog_ReadyToExchangeClkPatterns
            ) {
              when(flagMbinitRepairClk_SentInitResp) {
                flagMbinitRepairClk_SendInitResp := false.B
                repairClkReceiverStateReg := RepairClkReceiverState.waitingPatternsExchangeFinish
              }.otherwise {
                flagMbinitRepairClk_SendInitResp := true.B
              }
            }
          }
          is(RepairClkReceiverState.waitingPatternsExchangeFinish) {
            //now: all three lanes bit true when receiving result request or error
            when(flagMbinitRepairClk_ReceivedResultReq) {
              mbinitRepairClk_logClkPatternReceivedRTRK_L := io.flagFromAnalog_clkPatternReceivedRTRK_L
              mbinitRepairClk_logClkPatternReceivedRCKN_L := io.flagFromAnalog_clkPatternReceivedRCKN_L
              mbinitRepairClk_logClkPatternReceivedRCKP_L := io.flagFromAnalog_clkPatternReceivedRCKP_L

              //check if all three lanes are true
              when(
                io.flagFromAnalog_clkPatternReceivedRTRK_L &&
                io.flagFromAnalog_clkPatternReceivedRCKN_L &&
                io.flagFromAnalog_clkPatternReceivedRCKP_L
              ) {
                repairClkReceiverStateReg := RepairClkReceiverState.sendResultResp
              }.otherwise {
                trainErrorReg := true.B
              }
            }
          }
          is(RepairClkReceiverState.sendResultResp) {
            when(flagMbinitRepairClk_SentResultResp) {
              flagMbinitRepairClk_SendResultResp := false.B
              repairClkReceiverStateReg := RepairClkReceiverState.receiveDoneReq
            }.otherwise {
              flagMbinitRepairClk_SendResultResp := true.B
            }
          }
          is(RepairClkReceiverState.receiveDoneReq) {
            when(flagMbinitRepairClk_ReceivedDoneReq) {
              repairClkReceiverStateReg := RepairClkReceiverState.sendDoneResp
            }
          }
          is(RepairClkReceiverState.sendDoneResp) {
            when(flagMbinitRepairClk_SentDoneResp) {
              flagMbinitRepairClk_SendDoneResp := false.B
              repairClkReceiverStateReg := RepairClkReceiverState.finish
            }.otherwise {
              flagMbinitRepairClk_SendDoneResp := true.B
            }
          }
        }

        // Centralized TX arbitration for REPAIRCLK sender/receiver requests.
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitRepairClk_SendInitResp) {
            nextSbTxDin := MBINIT_REPAIRCLK_INIT_RESP
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentInitResp := true.B
          }.elsewhen(flagMbinitRepairClk_SendResultResp) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkResultResp(
              "phy",
              "phy",
              mbinitRepairClk_logClkPatternReceivedRTRK_L,
              mbinitRepairClk_logClkPatternReceivedRCKN_L,
              mbinitRepairClk_logClkPatternReceivedRCKP_L
            )
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentResultResp := true.B
          }.elsewhen(flagMbinitRepairClk_SendDoneResp) {
            nextSbTxDin := MBINIT_REPAIRCLK_DONE_RESP
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentDoneResp := true.B
          }.elsewhen(flagMbinitRepairClk_SendInitReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentInitReq := true.B
          }.elsewhen(flagMbinitRepairClk_SendResultReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentResultReq := true.B
          }.elsewhen(flagMbinitRepairClk_SendDoneReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairClk_SentDoneReq := true.B
          }
        }

        when(
          repairClkReceiverStateReg === RepairClkReceiverState.finish &&
          repairClkSenderStateReg === RepairClkSenderState.finish
        ) {
          flagMbinitRepairClk_SendInitReq := false.B
          flagMbinitRepairClk_SendResultReq := false.B
          flagMbinitRepairClk_SendDoneReq := false.B
          flagMbinitRepairClk_SendInitResp := false.B
          flagMbinitRepairClk_SendResultResp := false.B
          flagMbinitRepairClk_SendDoneResp := false.B
          flagMbinitRepairClk_SentInitReq := false.B
          flagMbinitRepairClk_SentResultReq := false.B
          flagMbinitRepairClk_SentDoneReq := false.B
          flagMbinitRepairClk_SentInitResp := false.B
          flagMbinitRepairClk_SentResultResp := false.B
          flagMbinitRepairClk_SentDoneResp := false.B
          stateReg := MBInitState.REPAIRVAL
        }
      }

      is(MBInitState.REPAIRVAL) {
        io.flagToAnalog_RepairValState := true.B

        switch(repairValSenderStateReg) {
          is(RepairValSenderState.initReq) {
            when(flagMbinitRepairVal_SentInitReq) {
              flagMbinitRepairVal_SendInitReq := false.B
              repairValSenderStateReg := RepairValSenderState.sendValTrainPattern
            }.otherwise {
              flagMbinitRepairVal_SendInitReq := true.B
            }
          }
          is(RepairValSenderState.sendValTrainPattern) {
            when(flagMbinitRepairVal_ReceivedInitResp && io.flagFromAnalog_ReadyToExchangeClkPatterns) {
              io.flagToAnalog_SendValTrainPattern := true.B
              repairValSenderStateReg := RepairValSenderState.waitingValTrainPatternFinish
            }
          }
          is(RepairValSenderState.waitingValTrainPatternFinish) {
            when(io.flagFromAnalog_FinishedValTrainPattern) {
              repairValSenderStateReg := RepairValSenderState.sendResultReq
            }
          }
          is(RepairValSenderState.sendResultReq) {
            when(flagMbinitRepairVal_SentResultReq) {
              flagMbinitRepairVal_SendResultReq := false.B
              repairValSenderStateReg := RepairValSenderState.receiveResultResp
            }.otherwise {
              flagMbinitRepairVal_SendResultReq := true.B
            }
          }
          is(RepairValSenderState.receiveResultResp) {
            when(flagMbinitRepairVal_ReceivedResultResp) {
              when(mbinitRepairVal_ReceivedResultBit) {
                repairValSenderStateReg := RepairValSenderState.sendDoneReq
              }.otherwise {
                trainErrorReg := true.B
              }
            }
          }
          is(RepairValSenderState.sendDoneReq) {
            when(flagMbinitRepairVal_SentDoneReq) {
              flagMbinitRepairVal_SendDoneReq := false.B
              repairValSenderStateReg := RepairValSenderState.receiveDoneResp
            }.otherwise {
              flagMbinitRepairVal_SendDoneReq := true.B
            }
          }
          is(RepairValSenderState.receiveDoneResp) {
            when(flagMbinitRepairVal_ReceivedDoneResp) {
              repairValSenderStateReg := RepairValSenderState.finish
            }
          }
        }

        switch(repairValReceiverStateReg) {
          is(RepairValReceiverState.sendInitResp) {
            when(
              flagMbinitRepairVal_ReceivedInitReq &&
              io.flagFromAnalog_ReadyToExchangeClkPatterns
            ) {
              when(flagMbinitRepairVal_SentInitResp) {
                flagMbinitRepairVal_SendInitResp := false.B
                repairValReceiverStateReg := RepairValReceiverState.waitingValTrainPatternFinish
              }.otherwise {
                flagMbinitRepairVal_SendInitResp := true.B
              }
            }
          }
          is(RepairValReceiverState.waitingValTrainPatternFinish) {
            when(flagMbinitRepairVal_ReceivedResultReq) {
              mbinitRepairVal_logValTrainPatternReceived := io.flagFromAnalog_ValTrainPatternReceived
              repairValReceiverStateReg := RepairValReceiverState.sendResultResp
            }
          }
          is(RepairValReceiverState.sendResultResp) {
            when(flagMbinitRepairVal_SentResultResp) {
              flagMbinitRepairVal_SendResultResp := false.B
              repairValReceiverStateReg := RepairValReceiverState.receiveDoneReq
            }.otherwise {
              flagMbinitRepairVal_SendResultResp := true.B
            }
          }
          is(RepairValReceiverState.receiveDoneReq) {
            when(flagMbinitRepairVal_ReceivedDoneReq) {
              repairValReceiverStateReg := RepairValReceiverState.sendDoneResp
            }
          }
          is(RepairValReceiverState.sendDoneResp) {
            when(flagMbinitRepairVal_SentDoneResp) {
              flagMbinitRepairVal_SendDoneResp := false.B
              repairValReceiverStateReg := RepairValReceiverState.finish
            }.otherwise {
              flagMbinitRepairVal_SendDoneResp := true.B
            }
          }
        }

        // Centralized TX arbitration for REPAIRVAL sender/receiver requests.
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitRepairVal_SendInitResp) {
            nextSbTxDin := MBINIT_REPAIRVAL_INIT_RESP
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendInitResp := false.B
            flagMbinitRepairVal_SentInitResp := true.B
          }.elsewhen(flagMbinitRepairVal_SendResultResp) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValResultResp(
              "phy",
              "phy",
              mbinitRepairVal_logValTrainPatternReceived
            )
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendResultResp := false.B
            flagMbinitRepairVal_SentResultResp := true.B
          }.elsewhen(flagMbinitRepairVal_SendDoneResp) {
            nextSbTxDin := MBINIT_REPAIRVAL_DONE_RESP
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendDoneResp := false.B
            flagMbinitRepairVal_SentDoneResp := true.B
          }.elsewhen(flagMbinitRepairVal_SendInitReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValInitReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendInitReq := false.B
            flagMbinitRepairVal_SentInitReq := true.B
          }.elsewhen(flagMbinitRepairVal_SendResultReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValResultReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendResultReq := false.B
            flagMbinitRepairVal_SentResultReq := true.B
          }.elsewhen(flagMbinitRepairVal_SendDoneReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValDoneReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairVal_SendDoneReq := false.B
            flagMbinitRepairVal_SentDoneReq := true.B
          }
        }

        when(
          repairValReceiverStateReg === RepairValReceiverState.finish &&
          repairValSenderStateReg === RepairValSenderState.finish
        ) {
          stateReg := MBInitState.REVERSALMB
        }
      }


      is(MBInitState.REVERSALMB) {
        // SENDER:
        // Sender sends init req and waits for init resp.
        switch(reversalMbSenderStateReg) {
          is(ReversalMbSenderState.initReq) {
            when(flagMbinitReversalMb_SentInitReq) {
              flagMbinitReversalMb_SendInitReq := false.B
              reversalMbSenderStateReg := ReversalMbSenderState.waitInitResp
            }.otherwise {
              flagMbinitReversalMb_SendInitReq := true.B
            }
          }
          is(ReversalMbSenderState.waitInitResp) {
            when(flagMbinitReversalMb_ReceivedInitResp) {
              reversalMbSenderStateReg := ReversalMbSenderState.sendClearErrorReq
            }
          }
          is(ReversalMbSenderState.sendClearErrorReq) {
            when(flagMbinitReversalMb_SentClearErrorReq) {
              flagMbinitReversalMb_SendClearErrorReq := false.B
              reversalMbSenderStateReg := ReversalMbSenderState.waitClearErrorResp
            }.otherwise {
              flagMbinitReversalMb_SendClearErrorReq := true.B
            }
          }
          is(ReversalMbSenderState.waitClearErrorResp) {
            when(flagMbinitReversalMb_ReceivedClearErrorResp) {
              flagMbinitReversalMb_ReceivedClearErrorResp := false.B
              reversalMbSenderStateReg := ReversalMbSenderState.sendLaneIDPattern
            }
          }
          is(ReversalMbSenderState.sendLaneIDPattern) {
            io.flagToAnalog_ReversalMbSendLaneIDPattern := true.B
            reversalMbSenderStateReg := ReversalMbSenderState.waitingLaneIDPatternFinish
          }
          is(ReversalMbSenderState.waitingLaneIDPatternFinish) {
            when(io.flagFromAnalog_ReversalMbFinishedLaneIDPattern) {
              reversalMbSenderStateReg := ReversalMbSenderState.sendResultReq
            }
          }
          is(ReversalMbSenderState.sendResultReq) {
            when(flagMbinitReversalMb_SentResultReq) {
              flagMbinitReversalMb_SendResultReq := false.B
              reversalMbSenderStateReg := ReversalMbSenderState.waitResultResp
            }.otherwise {
              flagMbinitReversalMb_SendResultReq := true.B
            }
          }
          is(ReversalMbSenderState.waitResultResp) {
            when(flagMbinitReversalMb_ReceivedResultRespPayload) {
              //clears resultResp header and payload flags to be ready for next time if we need to retry
              flagMbinitReversalMb_ReceivedResultRespHeader := false.B
              flagMbinitReversalMb_ReceivedResultRespPayload := false.B
              when(reversalMb_ReceivedSuccessCount > 8.U) {
                reversalMbSenderStateReg := ReversalMbSenderState.sendDoneReq
              }.otherwise {
                when(reversalMb_LaneReversalApplied) {
                  // If lane reversal has already been applied and we still have 8 or fewer lanes successful, 
                    //then we have an electrical error and cannot recover, so we set the trainErrorReg to indicate this.
                  trainErrorReg := true.B
                }.otherwise {
                  // If lane reversal has not been applied yet and we have 8 or fewer lanes successful, then we apply lane reversal and try again.
                  reversalMb_LaneReversalApplied := true.B
                  //Todo: RESET the FLAGS HERE
                  reversalMbSenderStateReg := ReversalMbSenderState.sendClearErrorReq
                }
              }
            }
          }
          is(ReversalMbSenderState.sendDoneReq) {
            when(flagMbinitReversalMb_SentDoneReq) {
              flagMbinitReversalMb_SendDoneReq := false.B
              reversalMbSenderStateReg := ReversalMbSenderState.waitDoneResp
            }.otherwise {
              flagMbinitReversalMb_SendDoneReq := true.B
            }
          }
          is(ReversalMbSenderState.waitDoneResp) {
            when(flagMbinitReversalMb_ReceivedDoneResp) {
              reversalMbSenderStateReg := ReversalMbSenderState.finish
            }
          }
        }

        //RECEIVER:
        // Receiver sends init resp when init req is received and partner is ready.
        switch(reversalMbReceiverStateReg) {
          is(ReversalMbReceiverState.sendInitResp) {
            when(
              flagMbinitReversalMb_ReceivedInitReq &&
              io.flagFromAnalog_ReadyToExchangeClkPatterns
            ) {
              when(flagMbinitReversalMb_SentInitResp) {
                flagMbinitReversalMb_SendInitResp := false.B
                reversalMbReceiverStateReg := ReversalMbReceiverState.waitClearErrorReq
              }.otherwise {
                flagMbinitReversalMb_SendInitResp := true.B
              }
            }
          }
          is(ReversalMbReceiverState.waitClearErrorReq) {
            when(flagMbinitReversalMb_ReceivedClearErrorReq) {
              flagMbinitReversalMb_ReceivedClearErrorReq := false.B
              reversalMbLaneStatusLog := 0.U
              reversalMbReceiverStateReg := ReversalMbReceiverState.sendClearErrorResp
            }
          }
          is(ReversalMbReceiverState.sendClearErrorResp) {
            when(flagMbinitReversalMb_SentClearErrorResp) {
              flagMbinitReversalMb_SendClearErrorResp := false.B
              reversalMbReceiverStateReg := ReversalMbReceiverState.waitResultReq
            }.otherwise {
              flagMbinitReversalMb_SendClearErrorResp := true.B
            }
          }
          is(ReversalMbReceiverState.waitResultReq) {
            when(flagMbinitReversalMb_ReceivedResultReq) {
              flagMbinitReversalMb_ReceivedResultReq := false.B
              //log the 16 lane status bits from analog
              reversalMbLaneStatusLog := Cat(
                io.flagFromAnalog_ReversalMbTrainPatternReceived15,
                io.flagFromAnalog_ReversalMbTrainPatternReceived14,
                io.flagFromAnalog_ReversalMbTrainPatternReceived13,
                io.flagFromAnalog_ReversalMbTrainPatternReceived12,
                io.flagFromAnalog_ReversalMbTrainPatternReceived11,
                io.flagFromAnalog_ReversalMbTrainPatternReceived10,
                io.flagFromAnalog_ReversalMbTrainPatternReceived9,
                io.flagFromAnalog_ReversalMbTrainPatternReceived8,
                io.flagFromAnalog_ReversalMbTrainPatternReceived7,
                io.flagFromAnalog_ReversalMbTrainPatternReceived6,
                io.flagFromAnalog_ReversalMbTrainPatternReceived5,
                io.flagFromAnalog_ReversalMbTrainPatternReceived4,
                io.flagFromAnalog_ReversalMbTrainPatternReceived3,
                io.flagFromAnalog_ReversalMbTrainPatternReceived2,
                io.flagFromAnalog_ReversalMbTrainPatternReceived1,
                io.flagFromAnalog_ReversalMbTrainPatternReceived0
              )
              reversalMbReceiverStateReg := ReversalMbReceiverState.sendResultRespHeader
            }
          }
          is(ReversalMbReceiverState.sendResultRespHeader) {
            when(flagMbinitReversalMb_SentResultRespHeader) {
              flagMbinitReversalMb_SendResultRespHeader := false.B
              reversalMbReceiverStateReg := ReversalMbReceiverState.sendResultRespPayload
            }.otherwise {
              flagMbinitReversalMb_SendResultRespHeader := true.B
            }
          }
          is(ReversalMbReceiverState.sendResultRespPayload) {
            when(flagMbinitReversalMb_SentResultRespPayload) {
              flagMbinitReversalMb_SendResultRespPayload := false.B
              reversalMbReceiverStateReg := ReversalMbReceiverState.waitDoneReqOrClearErrorReq
            }.otherwise {
              flagMbinitReversalMb_SendResultRespPayload := true.B
            }
          }
          is(ReversalMbReceiverState.waitDoneReqOrClearErrorReq) {
            // After sending the result response, the receiver waits for either a done request 
              //(if everything is successful or we have already applied lane reversal) or a clear 
              //error request (if we need to apply lane reversal and try again). 
              //If we have an error the partner will call TRAIN ERROR
            when(flagMbinitReversalMb_ReceivedClearErrorReq) {
              //flag reseted in waitClearErrorReq state, so we don't need to reset it here
              reversalMbReceiverStateReg := ReversalMbReceiverState.waitClearErrorReq
            }.elsewhen(flagMbinitReversalMb_ReceivedDoneReq) {
              flagMbinitReversalMb_ReceivedDoneReq := false.B
              reversalMbReceiverStateReg := ReversalMbReceiverState.sendDoneResp
            }
          }
          is(ReversalMbReceiverState.sendDoneResp) {
            when(flagMbinitReversalMb_SentDoneResp) {
              flagMbinitReversalMb_SendDoneResp := false.B
              reversalMbReceiverStateReg := ReversalMbReceiverState.finish
            }.otherwise {
              flagMbinitReversalMb_SendDoneResp := true.B
            }
          }
        }

        // Centralized TX arbitration for REVERSALMB sender/receiver requests.
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitReversalMb_SendInitResp) {
            nextSbTxDin := MBINIT_REVERSALMB_INIT_RESP
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentInitResp := true.B
          }.elsewhen(flagMbinitReversalMb_SendClearErrorResp) {
            nextSbTxDin := MBINIT_REVERSALMB_CLEAR_ERROR_RESP
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentClearErrorResp := true.B
          }.elsewhen(flagMbinitReversalMb_SendResultRespHeader) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitReversalMbResultResp(
              "phy",
              "phy",
              reversalMbLaneStatusLog
            )(63, 0)
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentResultRespHeader := true.B
          }.elsewhen(flagMbinitReversalMb_SendResultRespPayload) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitReversalMbResultResp(
              "phy",
              "phy",
              reversalMbLaneStatusLog
            )(127, 64)
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentResultRespPayload := true.B
          }.elsewhen(flagMbinitReversalMb_SendDoneResp) {
            nextSbTxDin := MBINIT_REVERSALMB_DONE_RESP
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentDoneResp := true.B
          }.elsewhen(flagMbinitReversalMb_SendInitReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitReversalMbInitReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentInitReq := true.B
          }.elsewhen(flagMbinitReversalMb_SendClearErrorReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitReversalMbClearErrorReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentClearErrorReq := true.B
          }.elsewhen(flagMbinitReversalMb_SendResultReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitReversalMbResultReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentResultReq := true.B
          }.elsewhen(flagMbinitReversalMb_SendDoneReq) {
            nextSbTxDin := MBINIT_REVERSALMB_DONE_REQ
            nextSbTxValid := true.B
            flagMbinitReversalMb_SentDoneReq := true.B
          }
        }

        when(
          reversalMbReceiverStateReg === ReversalMbReceiverState.finish &&
          reversalMbSenderStateReg === ReversalMbSenderState.finish
        ) {
          flagMbinitReversalMb_SendInitReq := false.B
          flagMbinitReversalMb_SendClearErrorReq := false.B
          flagMbinitReversalMb_SendResultReq := false.B
          flagMbinitReversalMb_SendDoneReq := false.B
          flagMbinitReversalMb_SendInitResp := false.B
          flagMbinitReversalMb_SendClearErrorResp := false.B
          flagMbinitReversalMb_SendResultRespHeader := false.B
          flagMbinitReversalMb_SendResultRespPayload := false.B
          flagMbinitReversalMb_SendDoneResp := false.B
          flagMbinitReversalMb_SentInitReq := false.B
          flagMbinitReversalMb_SentClearErrorReq := false.B
          flagMbinitReversalMb_SentResultReq := false.B
          flagMbinitReversalMb_SentDoneReq := false.B
          flagMbinitReversalMb_SentInitResp := false.B
          flagMbinitReversalMb_SentClearErrorResp := false.B
          flagMbinitReversalMb_SentResultRespHeader := false.B
          flagMbinitReversalMb_SentResultRespPayload := false.B
          flagMbinitReversalMb_SentDoneResp := false.B
          stateReg := MBInitState.REPAIRMB
        }
      }




      is(MBInitState.REPAIRMB) {

        //SENDER REPAIRMB
        //
        switch(repairMbSenderStateReg) {
          is(RepairMbSenderState.sendStartReq) {
            when(flagMbinitRepairMb_SentStartReq) {
              flagMbinitRepairMb_SendStartReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.waitStartResp
            }.otherwise {
              flagMbinitRepairMb_SendStartReq := true.B
            }
          }
          is(RepairMbSenderState.waitStartResp) {
            when(flagMbinitRepairMb_ReceivedStartResp) {
              repairMbSenderStateReg := RepairMbSenderState.d2cPointTestSendReqHeader
            }
          }
          is(RepairMbSenderState.d2cPointTestSendReqHeader) {
            when(flagMbinitRepairMb_SentD2CPointTestReqHeader) {
              flagMbinitRepairMb_SendD2CPointTestReqHeader := false.B
              repairMbSenderStateReg := RepairMbSenderState.d2cPointTestSendReqPayload
            }.otherwise {
              flagMbinitRepairMb_SendD2CPointTestReqHeader := true.B
            }
          }
          is(RepairMbSenderState.d2cPointTestSendReqPayload) {
            when(flagMbinitRepairMb_SentD2CPointTestReqPayload) {
              flagMbinitRepairMb_SendD2CPointTestReqPayload := false.B
              repairMbSenderStateReg := RepairMbSenderState.d2cPointTestWaitResp
            }.otherwise {
              flagMbinitRepairMb_SendD2CPointTestReqPayload := true.B
            }
          }
          is(RepairMbSenderState.d2cPointTestWaitResp) {
            when(flagMbinitRepairMb_ReceivedD2CPointTestResp) {
              repairMbSenderStateReg := RepairMbSenderState.d2cPointTestLfsrClearErrorSendReq
            }
          }

          // TODO: do alternative for the posibility of partner not sending the clear error req
          is(RepairMbSenderState.d2cPointTestLfsrClearErrorSendReq) {
            when(flagMbinitRepairMb_SentLfsrClearErrorReq) {
              flagMbinitRepairMb_SendLfsrClearErrorReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.d2cPointTestLfsrClearErrorWaitResp
            }.otherwise {
              flagMbinitRepairMb_SendLfsrClearErrorReq := true.B
            }
          }
          is(RepairMbSenderState.d2cPointTestLfsrClearErrorWaitResp) {
            when(flagMbinitRepairMb_ReceivedLfsrClearErrorResp) {
              repairMbSenderStateReg := RepairMbSenderState.sendLaneIDPattern
            }
          }
          is(RepairMbSenderState.sendLaneIDPattern) {
            io.flagToAnalog_RepairMbSendLaneIDPattern := true.B
            repairMbSenderStateReg := RepairMbSenderState.waitingLaneIDPatternFinish
          }
          is(RepairMbSenderState.waitingLaneIDPatternFinish) {
            when(io.flagFromAnalog_RepairMbFinishedLaneIDPattern) {
              repairMbSenderStateReg := RepairMbSenderState.txInitD2CResultsSendReq
            }
          }
          is(RepairMbSenderState.txInitD2CResultsSendReq) {
            when(flagMbinitRepairMb_SentTxInitD2CResultsReq) {
              flagMbinitRepairMb_SendTxInitD2CResultsReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.txInitD2CResultsWaitResp
            }.otherwise {
              flagMbinitRepairMb_SendTxInitD2CResultsReq := true.B
            }
          }
          is(RepairMbSenderState.txInitD2CResultsWaitResp) {
            when(flagMbinitRepairMb_ReceivedTxInitD2CResultsRespPayload) {
              repairMbSenderStateReg := RepairMbSenderState.endTxInitD2CPointTestSendReq
            }
          }
          is(RepairMbSenderState.endTxInitD2CPointTestSendReq) {
            when(flagMbinitRepairMb_SentEndTxInitD2CPointTestReq) {
              flagMbinitRepairMb_SendEndTxInitD2CPointTestReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.endTxInitD2CPointTestWaitResp
            }.otherwise {
              flagMbinitRepairMb_SendEndTxInitD2CPointTestReq := true.B
            }
          }
          is(RepairMbSenderState.endTxInitD2CPointTestWaitResp) {
            when(flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestResp) {
              repairMbSenderStateReg := RepairMbSenderState.analyzeWidthDegradation
            }
          }
          is(RepairMbSenderState.analyzeWidthDegradation) {
            //NOW: width degradation only 16 lanes working or ERROR
            when(mbinitRepairMb_TxInitD2CResultsRespLaneCompareBits === "hFFFF".U(16.W)) {
              flagMbinitRepairMb_ApplyWidthDegradation := false.B
              repairMbSenderStateReg := RepairMbSenderState.sendApplyDegradeReq
            }.otherwise {
              flagMbinitRepairMb_ApplyWidthDegradation := true.B
              repairMbSenderStateReg := RepairMbSenderState.sendApplyDegradeReq
            }
          }
          is(RepairMbSenderState.sendApplyDegradeReq) {
            when(flagMbinitRepairMb_SentApplyDegradeReq) {
              flagMbinitRepairMb_SendApplyDegradeReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.waitApplyDegradeResp
            }.otherwise {
              flagMbinitRepairMb_SendApplyDegradeReq := true.B
            }
          }
          is(RepairMbSenderState.waitApplyDegradeResp) {
            when(flagMbinitRepairMb_ReceivedApplyDegradeResp) {
              repairMbSenderStateReg := RepairMbSenderState.sendEndReq
            }
          }
          is(RepairMbSenderState.sendEndReq) {
            when(flagMbinitRepairMb_SentEndReq) {
              flagMbinitRepairMb_SendEndReq := false.B
              repairMbSenderStateReg := RepairMbSenderState.waitEndResp
            }.otherwise {
              flagMbinitRepairMb_SendEndReq := true.B
            }
          }
          is(RepairMbSenderState.waitEndResp) {
            when(flagMbinitRepairMb_ReceivedEndResp) {
              repairMbSenderStateReg := RepairMbSenderState.finish
            }
          }
          is(RepairMbSenderState.finish) {
            repairMbSenderStateReg := RepairMbSenderState.finish
          }
        }


        // RECEIVER REPAIRMB
        //
        switch(repairMbReceiverStateReg) {
          is(RepairMbReceiverState.waitStartReq) {
            when(flagMbinitRepairMb_ReceivedStartReq) {
              repairMbReceiverStateReg := RepairMbReceiverState.sendStartResp
            }
          }
          is(RepairMbReceiverState.sendStartResp) {
            when(flagMbinitRepairMb_SentStartResp) {
              flagMbinitRepairMb_SendStartResp := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.waitD2CPointTestReq
            }.otherwise {
              flagMbinitRepairMb_SendStartResp := true.B
            }
          }
          is(RepairMbReceiverState.waitD2CPointTestReq) {
            when(
              flagMbinitRepairMb_ReceivedD2CPointTestReqHeader &&
              flagMbinitRepairMb_ReceivedD2CPointTestReqPayload
            ) {
              repairMbReceiverStateReg := RepairMbReceiverState.setReceiver
            }
          }
          is(RepairMbReceiverState.setReceiver) {
            io.flagToAnalog_RepairMbSetReceiver := true.B
            repairMbReceiverStateReg := RepairMbReceiverState.sendD2CPointTestResp
          }
          is(RepairMbReceiverState.sendD2CPointTestResp) {
            when(flagMbinitRepairMb_SentD2CPointTestResp) {
              flagMbinitRepairMb_SendD2CPointTestResp := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.waitLfsrClearErrorReq
            }.otherwise {
              flagMbinitRepairMb_SendD2CPointTestResp := true.B
            }
          }
          is(RepairMbReceiverState.waitLfsrClearErrorReq) {
            // TODO: do alternative for the posibility of partner not sending the clear error req
            // Ambigous state where receiver is waiting for either the clear error req or directly the data
            when(flagMbinitRepairMb_ReceivedLfsrClearErrorReq) {
              repairMbReceiverStateReg := RepairMbReceiverState.sendLfsrClearErrorResp
            }
          }
          is(RepairMbReceiverState.sendLfsrClearErrorResp) {
            //SCRAMBLER IS NOT RESETED (pg 153 - c. LFSR Reset has no impact in MBINIT.REPAIRMB)
            when(flagMbinitRepairMb_SentLfsrClearErrorResp) {
              flagMbinitRepairMb_SendLfsrClearErrorResp := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.waitTxInitD2CResultsReq
            }.otherwise {
              flagMbinitRepairMb_SendLfsrClearErrorResp := true.B
            }
          }
          is(RepairMbReceiverState.waitTxInitD2CResultsReq) {
            when(flagMbinitRepairMb_ReceivedTxInitD2CResultsReq) {
              repairMb_DetectedLaneIDPatternLog := Cat(
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern15,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern14,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern13,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern12,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern11,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern10,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern9,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern8,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern7,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern6,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern5,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern4,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern3,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern2,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern1,
                io.flagFromAnalog_RepairMbDetectedLaneIDPattern0
              )
              repairMbReceiverStateReg := RepairMbReceiverState.sendTxInitD2CResultsRespHeader
            }
          }
          is(RepairMbReceiverState.sendTxInitD2CResultsRespHeader) {
            when(flagMbinitRepairMb_SentTxInitD2CResultsRespHeader) {
              flagMbinitRepairMb_SendTxInitD2CResultsRespHeader := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.sendTxInitD2CResultsRespPayload
            }.otherwise {
              flagMbinitRepairMb_SendTxInitD2CResultsRespHeader := true.B
            }
          }
          is(RepairMbReceiverState.sendTxInitD2CResultsRespPayload) {
            when(flagMbinitRepairMb_SentTxInitD2CResultsRespPayload) {
              flagMbinitRepairMb_SendTxInitD2CResultsRespPayload := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.waitEndTxInitD2CPointTestReq
            }.otherwise {
              flagMbinitRepairMb_SendTxInitD2CResultsRespPayload := true.B
            }
          }
          is(RepairMbReceiverState.waitEndTxInitD2CPointTestReq) {
            when(flagMbinitRepairMb_ReceivedEndTxInitD2CPointTestReq) {
              repairMbReceiverStateReg := RepairMbReceiverState.sendEndTxInitD2CPointTestResp
            }
          }
          is(RepairMbReceiverState.sendEndTxInitD2CPointTestResp) {
            when(flagMbinitRepairMb_SentEndTxInitD2CPointTestResp) {
              flagMbinitRepairMb_SendEndTxInitD2CPointTestResp := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.waitApplyDegradeReq
            }.otherwise {
              flagMbinitRepairMb_SendEndTxInitD2CPointTestResp := true.B
            }
          }
          is(RepairMbReceiverState.waitApplyDegradeReq) {
            when(flagMbinitRepairMb_ReceivedApplyDegradeReq) {
              when(mbinitRepairMb_ReceivedApplyDegradeReqLaneMap === "b011".U) {
                repairMbReceiverStateReg := RepairMbReceiverState.sendApplyDegradeResp
              }.otherwise {
                trainErrorReg := true.B
              }
            }
          }
          is(RepairMbReceiverState.sendApplyDegradeResp) {
            when(flagMbinitRepairMb_SentApplyDegradeResp) {
              flagMbinitRepairMb_SendApplyDegradeResp := false.B
              repairMbReceiverStateReg := RepairMbReceiverState.finish
            }.otherwise {
              flagMbinitRepairMb_SendApplyDegradeResp := true.B
            }
          }
          is(RepairMbReceiverState.finish) {
            repairMbReceiverStateReg := RepairMbReceiverState.finish
          }
        }

        when(
          repairMbReceiverStateReg === RepairMbReceiverState.finish &&
          repairMbSenderStateReg === RepairMbSenderState.finish
        ) {
          flagMbinitRepairMb_SendStartReq := false.B
          flagMbinitRepairMb_SendD2CPointTestReqHeader := false.B
          flagMbinitRepairMb_SendD2CPointTestReqPayload := false.B
          flagMbinitRepairMb_SendLfsrClearErrorReq := false.B
          flagMbinitRepairMb_SendTxInitD2CResultsReq := false.B
          flagMbinitRepairMb_SendEndTxInitD2CPointTestReq := false.B
          flagMbinitRepairMb_SendApplyDegradeReq := false.B
          flagMbinitRepairMb_SendEndReq := false.B
          flagMbinitRepairMb_SendStartResp := false.B
          flagMbinitRepairMb_SendD2CPointTestResp := false.B
          flagMbinitRepairMb_SendLfsrClearErrorResp := false.B
          flagMbinitRepairMb_SendTxInitD2CResultsRespHeader := false.B
          flagMbinitRepairMb_SendTxInitD2CResultsRespPayload := false.B
          flagMbinitRepairMb_SendEndTxInitD2CPointTestResp := false.B
          flagMbinitRepairMb_SendApplyDegradeResp := false.B
          flagMbinitRepairMb_SentStartReq := false.B
          flagMbinitRepairMb_SentD2CPointTestReqHeader := false.B
          flagMbinitRepairMb_SentD2CPointTestReqPayload := false.B
          flagMbinitRepairMb_SentLfsrClearErrorReq := false.B
          flagMbinitRepairMb_SentTxInitD2CResultsReq := false.B
          flagMbinitRepairMb_SentEndTxInitD2CPointTestReq := false.B
          flagMbinitRepairMb_SentApplyDegradeReq := false.B
          flagMbinitRepairMb_SentEndReq := false.B
          flagMbinitRepairMb_SentStartResp := false.B
          flagMbinitRepairMb_SentD2CPointTestResp := false.B
          flagMbinitRepairMb_SentLfsrClearErrorResp := false.B
          flagMbinitRepairMb_SentTxInitD2CResultsRespHeader := false.B
          flagMbinitRepairMb_SentTxInitD2CResultsRespPayload := false.B
          flagMbinitRepairMb_SentEndTxInitD2CPointTestResp := false.B
          flagMbinitRepairMb_SentApplyDegradeResp := false.B
          flagMbinitRepairMb_SentEndResp := false.B
          stateReg := MBInitState.DONE
        }





















        // Centralized TX arbitration for REPAIRMB sender/receiver requests.
        //TODO: give priority to payloads over headers in case of simultaneous send
        when(io.sb_tx_ready && !sbTxValid) {
          when(flagMbinitRepairMb_SendStartResp) {
            nextSbTxDin := MBINIT_REPAIRMB_START_RESP
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentStartResp := true.B
          }.elsewhen(flagMbinitRepairMb_SendD2CPointTestResp) {
            nextSbTxDin := MBINIT_REPAIRMB_D2C_POINT_TEST_RESP
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentD2CPointTestResp := true.B
          }.elsewhen(flagMbinitRepairMb_SendLfsrClearErrorResp) {
            nextSbTxDin := MBINIT_REPAIRMB_LFSR_CLEAR_ERROR_RESP
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentLfsrClearErrorResp := true.B
          }.elsewhen(flagMbinitRepairMb_SendTxInitD2CResultsRespHeader) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairMbTxInitD2CResultsResp(
              "phy",
              "phy",
              0.U(16.W),
              Cat(0.U(48.W), repairMb_DetectedLaneIDPatternLog)
            )(63, 0)
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentTxInitD2CResultsRespHeader := true.B
          }.elsewhen(flagMbinitRepairMb_SendTxInitD2CResultsRespPayload) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairMbTxInitD2CResultsResp(
              "phy",
              "phy",
              0.U(16.W),
              Cat(0.U(48.W), repairMb_DetectedLaneIDPatternLog)
            )(127, 64)
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentTxInitD2CResultsRespPayload := true.B
          }.elsewhen(flagMbinitRepairMb_SendEndTxInitD2CPointTestResp) {
            nextSbTxDin := MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_RESP
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentEndTxInitD2CPointTestResp := true.B
          }.elsewhen(flagMbinitRepairMb_SendApplyDegradeResp) {
            nextSbTxDin := MBINIT_REPAIRMB_APPLY_DEGRADE_RESP
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentApplyDegradeResp := true.B
          }.elsewhen(flagMbinitRepairMb_SendStartReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairMbStartReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentStartReq := true.B
          }.elsewhen(flagMbinitRepairMb_SendD2CPointTestReqHeader) {
            nextSbTxDin := MBINIT_REPAIRMB_D2C_POINT_TEST_REQ(63, 0)
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentD2CPointTestReqHeader := true.B
          }.elsewhen(flagMbinitRepairMb_SendD2CPointTestReqPayload) {
            nextSbTxDin := MBINIT_REPAIRMB_D2C_POINT_TEST_REQ(127, 64)
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentD2CPointTestReqPayload := true.B
          }.elsewhen(flagMbinitRepairMb_SendLfsrClearErrorReq) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairMbLfsrClearErrorReq("phy", "phy")
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentLfsrClearErrorReq := true.B
          }.elsewhen(flagMbinitRepairMb_SendTxInitD2CResultsReq) {
            nextSbTxDin := MBINIT_REPAIRMB_TX_INIT_D2C_RESULTS_REQ
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentTxInitD2CResultsReq := true.B
          }.elsewhen(flagMbinitRepairMb_SendEndTxInitD2CPointTestReq) {
            nextSbTxDin := MBINIT_REPAIRMB_END_TX_INIT_D2C_POINT_TEST_REQ
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentEndTxInitD2CPointTestReq := true.B
          }.elsewhen(flagMbinitRepairMb_SendApplyDegradeReq) {
            nextSbTxDin := Mux(
              flagMbinitRepairMb_ApplyWidthDegradation,
              SidebandMsgGenerator.msgMbinitRepairMbApplyDegradeReq("phy", "phy", "b000".U(3.W)),
              SidebandMsgGenerator.msgMbinitRepairMbApplyDegradeReq("phy", "phy", "b011".U(3.W))
            )
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentApplyDegradeReq := true.B
          }.elsewhen(flagMbinitRepairMb_SendEndReq) {
            nextSbTxDin := MBINIT_REPAIRMB_END_REQ
            nextSbTxValid := true.B
            flagMbinitRepairMb_SentEndReq := true.B
          }
        }
      }

      

      is(MBInitState.DONE) {
        stateReg := MBInitState.DONE
      }
    }
  }
}
