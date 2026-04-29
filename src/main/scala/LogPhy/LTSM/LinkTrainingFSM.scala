/*
  TODO:
    - add the LTSM status register (Spec Chap: 9.5.3.34)
    - Optimize RESET wait if needed (large counter version implemented)
    - check flags reset
    - Flooding SB TX fifo when sendinf clkPattern and OOR msg -- add counter
    - implement MBINIT_PARAM negotiation and retries
    - check rising edge when sending in stages
    - DO training error
    - confirm messages with payload are not interrupted
*/

package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

class LinkTrainingFSM(
  designParams: DesignParams = DesignParams()
  ) extends Module {
  val io = IO(new Bundle {

    // --------------------------
    // System-side TX -> SBmodule
    // --------------------------
    val sb_tx_din   = Output(UInt(64.W))
    val sb_tx_valid = Output(Bool())
    val sb_tx_ready = Input(Bool())

    // --------------------------
    // System-side RX <- SBmodule
    // --------------------------
    val sb_rx_dout  = Input(UInt(64.W))
    val sb_rx_valid = Input(Bool())

    // --------------------------
    // Link training control inputs
    // --------------------------
    val start          = Input(Bool())
    val stable_clk     = Input(Bool())
    val pll_locked     = Input(Bool())
    val stable_supply  = Input(Bool())
    val flagFromAnalog_ReadyToExchangeClkPatterns = Input(Bool())
    val flagFromAnalog_FinishedClkPatterns        = Input(Bool())
    val flagFromAnalog_FinishedValTrainPattern    = Input(Bool())
    val flagFromAnalog_ReversalMbFinishedLaneIDPattern = Input(Bool())
    val flagFromAnalog_RepairMbFinishedLaneIDPattern   = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRTRK_L   = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKN_L   = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKP_L   = Input(Bool())
    val flagFromAnalog_ValTrainPatternReceived    = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived0   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived1   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived2   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived3   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived4   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived5   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived6   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived7   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived8   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived9   = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived10  = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived11  = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived12  = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived13  = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived14  = Input(Bool())
    val flagFromAnalog_ReversalMbTrainPatternReceived15  = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern0    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern1    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern2    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern3    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern4    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern5    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern6    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern7    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern8    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern9    = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern10   = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern11   = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern12   = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern13   = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern14   = Input(Bool())
    val flagFromAnalog_RepairMbDetectedLaneIDPattern15   = Input(Bool())
    val flagToAnalog_RepairClkState               = Output(Bool())
    val flagToAnalog_SendClkPatterns              = Output(Bool()) //look where is reset being done
    val flagToAnalog_RepairValState               = Output(Bool())
    val flagToAnalog_SendValTrainPattern          = Output(Bool())
    val flagToAnalog_ReversalMbSendLaneIDPattern  = Output(Bool())
    val flagToAnalog_RepairMbSendLaneIDPattern    = Output(Bool())
    val flagToAnalog_RepairMbSetReceiver          = Output(Bool())
    val flagToAnalog_LaneReversalApplied          = Output(Bool())

    // needs 4 bits because there are 12 enum states (0..11)
    val state = Output(UInt(4.W))
    
    // debug outputs
    val dbg_flagSbinitFirstClkPatternSeen = Output(Bool())
    val dbg_rxValidRisingEdge = Output(Bool())
    val dbg_sbinitSendCount = Output(UInt(3.W))
    val dbg_sbTxValid = Output(Bool()) 
    val dbg_sbTxDin = Output(UInt(64.W))
    val dbg_flagTrainError = Output(Bool())
    val dbg_mbinitSubstate = Output(UInt(3.W))
    val dbg_mbinitReversalMbReceivedSuccessCount = Output(UInt(5.W))
  })










  // ==========================================================
  // Outputs registers to avoid combinational loops in the FSM logic
  // ==========================================================
  val sbTxValid = RegInit(false.B)
  val sbTxDin = RegInit(0.U(64.W))
  val nextSbTxValid = WireDefault(false.B)
  val nextSbTxDin   = WireDefault(0.U(64.W))
  sbTxValid := nextSbTxValid
  sbTxDin   := nextSbTxDin

  // ==========================================================
  // FSM
  // ==========================================================
  object LTState extends ChiselEnum {
    val RESET, 
      SBINIT_pattern,SBINIT_sendFour, SBINIT_OORmsg, SBINIT_DONEmsg,
      MBINIT_SUPER,
      MBTRAIN, 
      LINKINIT, 
      ACTIVE = Value
  }

  object RepairClkSenderState extends ChiselEnum {
    val initReq,
      sendClkPatternsExchange,
      waitingPatternsExchangeFinish,
      sendResultReq,
      receiveResultResp,
      sendDoneReq,
      receiveDoneResp,
      receiveDoneReq,
      finish = Value
  }

  object RepairClkReceiverState extends ChiselEnum {
    val receiveInitReq,
      sendInitResp,
      waitingPatternsExchangeFinish,
      receiveResultReq,
      sendResultResp,
      receiveDoneReq,
      sendDoneResp,
      finish = Value
  }

  object RepairValSenderState extends ChiselEnum {
    val initReq,
      sendValTrainPattern,
      waitingValTrainPatternFinish,
      sendResultReq,
      receiveResultResp,
      sendDoneReq,
      receiveDoneResp,
      finish = Value
  }

  object RepairValReceiverState extends ChiselEnum {
    val sendInitResp,
      waitingValTrainPatternFinish,
      sendResultResp,
      receiveDoneReq,
      sendDoneResp,
      finish = Value
  }

  val stateReg = RegInit(LTState.RESET)
  io.state := stateReg.asUInt

  // ==========================================================
  // RESET dwell: direct 4 ms counter at system clock
  // At 800 MHz: 4 ms = 3,200,000 cycles -> need 22 bits
  // ==========================================================
  val RESET_CYCLES = 10.U//3200000.U
  val resetCnt = RegInit(0.U(23.W))













  // ==========================================================
  // SBINIT pattern detection state
  // ==========================================================
  // Message detection flags (set on RX rising edge, consumed in FSM)
  val flagSbinitOorSuccessSeen  = RegInit(false.B)
  val flagSbinitFirstClkPatternSeen = RegInit(false.B)
  val flagSbinitSecondClkPatternSeen = RegInit(false.B)
  val sbinitSendCount = RegInit(0.U(3.W))

  // SBINIT_DONEmsg handshaking flags
  val flagSbinitReceivedDoneReq  = RegInit(false.B)
  val flagSbinitReceivedDoneResp = RegInit(false.B)
  val flagSbinitSentDoneReq     = RegInit(false.B)
  val flagSbinitSentDoneResp  = RegInit(false.B)
  // MBINIT_PARAM_REQ handshake flags
  val flagMbinitParamReceivedReqHeader      = RegInit(false.B)
  val flagMbinitParamReqWaitingPayload = RegInit(false.B)
  val flagMbinitParamReceivedReqPayload = RegInit(false.B)
  val flagMbinitParamSentReqHdr       = RegInit(false.B)
  val flagMbinitParamSentReqPayload   = RegInit(false.B)
  val flagMbinitParamReceivedRespHeader  = RegInit(false.B)
  val flagMbinitParamReceivedRespPayload = RegInit(false.B)
  val flagMbinitParamRespWaitingPayload = RegInit(false.B)
  val flagMbinitParamSentRespHdr      = RegInit(false.B)
  val flagMbinitParamSentRespPayload  = RegInit(false.B)
  val flagMbinitParamCorrectReqReceived = RegInit(false.B)
  // MBINIT.CAL_DONE handshake flags
  val flagMbinitCalReceivedDoneReq  = RegInit(false.B)
  val flagMbinitCalReceivedDoneResp = RegInit(false.B)
  val flagMbinitCalSentDoneReq      = RegInit(false.B)
  val flagMbinitCalSentDoneResp     = RegInit(false.B)
  // MBINIT_REPAIRCLK sender flags (placeholder)
  val flagMbinitRepairClk_SentInitReq      = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedInitResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedInitReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneReq = RegInit(false.B)
  val mbinitRepairClk_ReceivedResultBits = RegInit(0.U(3.W))
  val flagMbinitRepairClk_SentClkPatterns  = RegInit(false.B)
  val flagMbinitRepairClk_SentResultReq    = RegInit(false.B)
  val repairClkSenderStateReg = RegInit(RepairClkSenderState.initReq)
  val repairClkReceiverStateReg = RegInit(RepairClkReceiverState.sendInitResp)
  // MBINIT_REPAIRVAL flags
  val flagMbinitRepairVal_ReceivedInitResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedInitReq = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedResultReq = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitRepairVal_ReceivedDoneReq = RegInit(false.B)
  val mbinitRepairVal_ReceivedResultBit = RegInit(false.B)
  val mbinitRepairVal_logValTrainPatternReceived = RegInit(false.B)
  val repairValSenderStateReg = RegInit(RepairValSenderState.initReq)
  val repairValReceiverStateReg = RegInit(RepairValReceiverState.sendInitResp)
  // TRAIN ERROR
  val flagTrainError = RegInit(false.B)
  // MBINIT_REPAIRCLK receiver logs from analog
  val mbinitRepairClk_logClkPatternReceivedRTRK_L = RegInit(false.B)
  val mbinitRepairClk_logClkPatternReceivedRCKN_L = RegInit(false.B)
  val mbinitRepairClk_logClkPatternReceivedRCKP_L = RegInit(false.B)



  // MBINIT_PARAM payloads
  val remoteParamReqPayload           = RegInit(0.U(64.W))
  val remoteParamRespPayload          = RegInit(0.U(64.W))

  // previous-cycle register for sb_rx_valid and rising-edge detector
  val prevRxValid = RegNext(io.sb_rx_valid, false.B)
  val rxValidRisingEdge = io.sb_rx_valid && (!prevRxValid)
  val prevState = RegNext(stateReg, LTState.RESET)












  // ==========================================================
  // FSMs Instatiations
  // ==========================================================

  val mbInitFsm = Module(new MBInitFSM(designParams))
  mbInitFsm.io.start := (stateReg === LTState.MBINIT_SUPER)
  mbInitFsm.io.sb_tx_ready := io.sb_tx_ready
  mbInitFsm.io.sb_rx_dout := io.sb_rx_dout
  mbInitFsm.io.sb_rx_valid := io.sb_rx_valid
  mbInitFsm.io.flagFromAnalog_ReadyToExchangeClkPatterns := io.flagFromAnalog_ReadyToExchangeClkPatterns
  mbInitFsm.io.flagFromAnalog_FinishedClkPatterns := io.flagFromAnalog_FinishedClkPatterns
  mbInitFsm.io.flagFromAnalog_FinishedValTrainPattern := io.flagFromAnalog_FinishedValTrainPattern
  mbInitFsm.io.flagFromAnalog_ReversalMbFinishedLaneIDPattern := io.flagFromAnalog_ReversalMbFinishedLaneIDPattern
  mbInitFsm.io.flagFromAnalog_RepairMbFinishedLaneIDPattern := io.flagFromAnalog_RepairMbFinishedLaneIDPattern
  mbInitFsm.io.flagFromAnalog_clkPatternReceivedRTRK_L := io.flagFromAnalog_clkPatternReceivedRTRK_L
  mbInitFsm.io.flagFromAnalog_clkPatternReceivedRCKN_L := io.flagFromAnalog_clkPatternReceivedRCKN_L
  mbInitFsm.io.flagFromAnalog_clkPatternReceivedRCKP_L := io.flagFromAnalog_clkPatternReceivedRCKP_L
  mbInitFsm.io.flagFromAnalog_ValTrainPatternReceived := io.flagFromAnalog_ValTrainPatternReceived
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived0 := io.flagFromAnalog_ReversalMbTrainPatternReceived0
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived1 := io.flagFromAnalog_ReversalMbTrainPatternReceived1
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived2 := io.flagFromAnalog_ReversalMbTrainPatternReceived2
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived3 := io.flagFromAnalog_ReversalMbTrainPatternReceived3
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived4 := io.flagFromAnalog_ReversalMbTrainPatternReceived4
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived5 := io.flagFromAnalog_ReversalMbTrainPatternReceived5
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived6 := io.flagFromAnalog_ReversalMbTrainPatternReceived6
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived7 := io.flagFromAnalog_ReversalMbTrainPatternReceived7
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived8 := io.flagFromAnalog_ReversalMbTrainPatternReceived8
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived9 := io.flagFromAnalog_ReversalMbTrainPatternReceived9
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived10 := io.flagFromAnalog_ReversalMbTrainPatternReceived10
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived11 := io.flagFromAnalog_ReversalMbTrainPatternReceived11
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived12 := io.flagFromAnalog_ReversalMbTrainPatternReceived12
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived13 := io.flagFromAnalog_ReversalMbTrainPatternReceived13
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived14 := io.flagFromAnalog_ReversalMbTrainPatternReceived14
  mbInitFsm.io.flagFromAnalog_ReversalMbTrainPatternReceived15 := io.flagFromAnalog_ReversalMbTrainPatternReceived15
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern0 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern0
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern1 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern1
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern2 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern2
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern3 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern3
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern4 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern4
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern5 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern5
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern6 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern6
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern7 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern7
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern8 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern8
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern9 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern9
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern10 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern10
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern11 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern11
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern12 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern12
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern13 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern13
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern14 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern14
  mbInitFsm.io.flagFromAnalog_RepairMbDetectedLaneIDPattern15 := io.flagFromAnalog_RepairMbDetectedLaneIDPattern15
    
  io.flagToAnalog_RepairClkState := mbInitFsm.io.flagToAnalog_RepairClkState
  io.flagToAnalog_SendClkPatterns := mbInitFsm.io.flagToAnalog_SendClkPatterns
  io.flagToAnalog_RepairValState := mbInitFsm.io.flagToAnalog_RepairValState
  io.flagToAnalog_SendValTrainPattern := mbInitFsm.io.flagToAnalog_SendValTrainPattern
  io.flagToAnalog_ReversalMbSendLaneIDPattern := mbInitFsm.io.flagToAnalog_ReversalMbSendLaneIDPattern
  io.flagToAnalog_RepairMbSendLaneIDPattern := mbInitFsm.io.flagToAnalog_RepairMbSendLaneIDPattern
  io.flagToAnalog_RepairMbSetReceiver := mbInitFsm.io.flagToAnalog_RepairMbSetReceiver
  io.flagToAnalog_LaneReversalApplied := mbInitFsm.io.flagToAnalog_LaneReversalApplied
  io.sb_tx_valid := Mux(stateReg === LTState.MBINIT_SUPER, mbInitFsm.io.sb_tx_valid, sbTxValid)
  io.sb_tx_din := Mux(stateReg === LTState.MBINIT_SUPER, mbInitFsm.io.sb_tx_din, sbTxDin)

  














  
  // ==========================================================
  // Patterns
  // ==========================================================
  val SBINIT_CLK_PATTERN = "hAAAAAAAAAAAAAAAA".U(64.W)
  val SBINIT_OOR_SUCCESS = SidebandMsgGenerator.msgSbinitOutOfResetSuccess("phy", "phy")
  val SBINIT_DONE_REQ    = SidebandMsgGenerator.msgSbinitDoneReq("phy", "phy")
  val SBINIT_DONE_RESP   = SidebandMsgGenerator.msgSbinitDoneResp("phy", "phy")
  val MBINIT_PARAM_REQ   = SidebandMsgGenerator.msgMbinitParamConfigReq(
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
  val paramsResponse_clkPhase = designParams.clkPhase
  val paramsResponse_clkMode = designParams.clkMode
  val paramsResponse_maxLinkSpeed = designParams.maxLinkSpeed
  //reinstate when implementing response logic in the PARAM stage
  val MBINIT_PARAM_RESP  = SidebandMsgGenerator.msgMbinitParamConfigResp(
    "phy",
    "phy",
    paramsResponse_clkPhase,
    paramsResponse_clkMode,
    paramsResponse_maxLinkSpeed
  )
  val MBINIT_CAL_DONE_REQ  = SidebandMsgGenerator.msgMbinitCalDoneReq("phy", "phy")
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

  
  
  
  
  
  
  
  
  
  // ==========================================================
  // Debug signals
  // ==========================================================
  io.dbg_flagSbinitFirstClkPatternSeen := flagSbinitFirstClkPatternSeen
  io.dbg_rxValidRisingEdge := rxValidRisingEdge
  io.dbg_sbinitSendCount := sbinitSendCount
  io.dbg_sbTxValid := io.sb_tx_valid
  io.dbg_sbTxDin := io.sb_tx_din
  io.dbg_flagTrainError := flagTrainError || mbInitFsm.io.trainError
  io.dbg_mbinitSubstate := mbInitFsm.io.substate
  io.dbg_mbinitReversalMbReceivedSuccessCount := mbInitFsm.io.dbg_mbinitReversalMbReceivedSuccessCount



  
  



  
  
  
  // ==========================================================
  // Messages reception
  // ==========================================================
  when (rxValidRisingEdge) {
    when (stateReg === LTState.RESET) {
      flagSbinitFirstClkPatternSeen := false.B
      flagSbinitSecondClkPatternSeen := false.B
      flagSbinitOorSuccessSeen := false.B
      flagSbinitReceivedDoneReq  := false.B
      flagSbinitReceivedDoneResp := false.B
      //mbinit PARAM
      flagMbinitParamReceivedReqHeader := false.B
      flagMbinitParamReqWaitingPayload := false.B
      flagMbinitParamReceivedReqPayload := false.B
      flagMbinitParamReceivedRespHeader := false.B
      flagMbinitParamReceivedRespPayload := false.B
      flagMbinitParamRespWaitingPayload := false.B
      //mbinit Cal
      flagMbinitCalReceivedDoneReq  := false.B
      flagMbinitCalReceivedDoneResp := false.B
      //mbinit RepairClk sender
      flagMbinitRepairClk_ReceivedInitReq := false.B
      flagMbinitRepairClk_ReceivedInitResp := false.B
      flagMbinitRepairClk_ReceivedResultReq := false.B
      flagMbinitRepairClk_ReceivedResultResp := false.B
      flagMbinitRepairClk_ReceivedDoneReq := false.B
      flagMbinitRepairClk_ReceivedDoneResp := false.B
      mbinitRepairClk_ReceivedResultBits := 0.U
      //mbinit RepairVal sender/receiver
      flagMbinitRepairVal_ReceivedInitReq := false.B
      flagMbinitRepairVal_ReceivedInitResp := false.B
      flagMbinitRepairVal_ReceivedResultReq := false.B
      flagMbinitRepairVal_ReceivedResultResp := false.B
      flagMbinitRepairVal_ReceivedDoneReq := false.B
      flagMbinitRepairVal_ReceivedDoneResp := false.B
      mbinitRepairVal_ReceivedResultBit := false.B
      mbinitRepairVal_logValTrainPatternReceived := false.B
    }.otherwise {
      when (io.sb_rx_dout === SBINIT_CLK_PATTERN && !flagSbinitFirstClkPatternSeen) { //receiving two consecutive clk patterns
        flagSbinitFirstClkPatternSeen := true.B
      }.elsewhen (io.sb_rx_dout === SBINIT_CLK_PATTERN && flagSbinitFirstClkPatternSeen) {
        // when first pattern seen and second pattern arrives consecutively
        flagSbinitSecondClkPatternSeen := true.B 
      }.otherwise {
        // any other word breaks consecutive detection of the clock pattern
        //dont reset second pattern after two detections we can change state
        flagSbinitFirstClkPatternSeen := false.B
      }

      when (io.sb_rx_dout === SBINIT_OOR_SUCCESS) {
        flagSbinitOorSuccessSeen := true.B
      }

      when (io.sb_rx_dout === SBINIT_DONE_REQ) {
        flagSbinitReceivedDoneReq  := true.B
      }

      when (io.sb_rx_dout === SBINIT_DONE_RESP) {
        flagSbinitReceivedDoneResp := true.B
      }

      when (io.sb_rx_dout === MBINIT_PARAM_REQ(63,0)) {
        flagMbinitParamReceivedReqHeader := true.B
        flagMbinitParamReqWaitingPayload := true.B
      }
      when (flagMbinitParamReqWaitingPayload) { //RECEIVING PAYLOAD
        flagMbinitParamReceivedReqPayload := true.B
        flagMbinitParamReqWaitingPayload := false.B
        //get the data from the payload
        remoteParamReqPayload := io.sb_rx_dout
      }

      when (io.sb_rx_dout === MBINIT_PARAM_RESP(63,0)) {
        flagMbinitParamReceivedRespHeader := true.B
        flagMbinitParamRespWaitingPayload := true.B
      }
      when (flagMbinitParamRespWaitingPayload) { //RECEIVING PAYLOAD
        flagMbinitParamReceivedRespPayload := true.B
        flagMbinitParamRespWaitingPayload := false.B
        //get the data from the payload
        remoteParamRespPayload := io.sb_rx_dout
      }

      when (io.sb_rx_dout === MBINIT_CAL_DONE_REQ) {
        flagMbinitCalReceivedDoneReq := true.B
      }

      when (io.sb_rx_dout === MBINIT_CAL_DONE_RESP) {
        flagMbinitCalReceivedDoneResp := true.B
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")) {
        flagMbinitRepairClk_ReceivedInitReq := true.B
      }

      when (io.sb_rx_dout === MBINIT_REPAIRCLK_INIT_RESP) {
        flagMbinitRepairClk_ReceivedInitResp := true.B
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")) {
        flagMbinitRepairClk_ReceivedResultReq := true.B
      }

      when ( //apply mask to compare RESULT_RESP while ignoring msgInfo[2:0]
        (io.sb_rx_dout & "hBFFFF8FFFFFFFFFF".U(64.W)) ===
        (MBINIT_REPAIRCLK_RESULT_RESP & "hBFFFF8FFFFFFFFFF".U(64.W))
      ) {
        flagMbinitRepairClk_ReceivedResultResp := true.B
        mbinitRepairClk_ReceivedResultBits := io.sb_rx_dout(42,40)
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")) {
        flagMbinitRepairClk_ReceivedDoneReq := true.B
      }

      when (io.sb_rx_dout === MBINIT_REPAIRCLK_DONE_RESP) {
        flagMbinitRepairClk_ReceivedDoneResp := true.B
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValInitReq("phy", "phy")) {
        flagMbinitRepairVal_ReceivedInitReq := true.B
      }

      when (io.sb_rx_dout === MBINIT_REPAIRVAL_INIT_RESP) {
        flagMbinitRepairVal_ReceivedInitResp := true.B
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValResultReq("phy", "phy")) {
        flagMbinitRepairVal_ReceivedResultReq := true.B
      }

      when (
        (io.sb_rx_dout & "hBFFFFEFFFFFFFFFF".U(64.W)) ===
        (MBINIT_REPAIRVAL_RESULT_RESP & "hBFFFFEFFFFFFFFFF".U(64.W))
      ) {
        flagMbinitRepairVal_ReceivedResultResp := true.B
        mbinitRepairVal_ReceivedResultBit := io.sb_rx_dout(40)
      }

      when (io.sb_rx_dout === SidebandMsgGenerator.msgMbinitRepairValDoneReq("phy", "phy")) {
        flagMbinitRepairVal_ReceivedDoneReq := true.B
      }

      when (io.sb_rx_dout === MBINIT_REPAIRVAL_DONE_RESP) {
        flagMbinitRepairVal_ReceivedDoneResp := true.B
      }
    }
  }










  // ====================================================================================================================
  // ====================================================================================================================
  // FSM logic
  // ====================================================================================================================
  // ====================================================================================================================

  switch(stateReg) {

    // ========================================================
    // RESET — wait 4ms using the big counter
    // ========================================================
    is (LTState.RESET) {

      when (resetCnt =/= RESET_CYCLES) {
        resetCnt := resetCnt + 1.U
        stateReg := LTState.RESET
      }
      .otherwise {
        // when counter is done, check stability
        when (io.start && io.stable_clk && io.pll_locked && io.stable_supply) {
          //resetCnt := 0.U
          stateReg := LTState.SBINIT_pattern
        }
        .otherwise {
          stateReg := LTState.RESET
        }
      }
    }


    // ========================================================
    // SBINIT_pattern
    // ========================================================
    is (LTState.SBINIT_pattern) {
      //////////////
      // TX pattern
      when (io.sb_tx_ready && !sbTxValid) {
        nextSbTxDin   := SidebandMsgGenerator.msgSbinitClkPattern()
        nextSbTxValid := true.B
      }

      /////////////////
      // RX detection via flag set on rising edge
      when (flagSbinitSecondClkPatternSeen) {
        stateReg := LTState.SBINIT_sendFour
      }
    }

    is (LTState.SBINIT_sendFour) {
      when (io.sb_tx_ready && !sbTxValid && sbinitSendCount < 4.U) {
        nextSbTxDin   := SidebandMsgGenerator.msgSbinitClkPattern() 
        nextSbTxValid := true.B
        sbinitSendCount := sbinitSendCount + 1.U
      }

      when (sbinitSendCount === 3.U) {
        stateReg := LTState.SBINIT_OORmsg
        sbinitSendCount := 0.U
      }
    }

    // ========================================================
    // SBINIT_OORmsg 
    // ========================================================
    is (LTState.SBINIT_OORmsg) {
      when (io.sb_tx_ready && !sbTxValid) {
        nextSbTxDin   := SBINIT_OOR_SUCCESS
        nextSbTxValid := true.B
      }

      when (flagSbinitOorSuccessSeen) {
        stateReg := LTState.SBINIT_DONEmsg
      }
    }

    // ========================================================
    // SBINIT_DONEmsg 
    // ========================================================
    is (LTState.SBINIT_DONEmsg) {
      // TX scheduling: prioritize sending the response when pending, otherwise send req once
      when (io.sb_tx_ready && !sbTxValid) { //¿tx edge?
        when (!flagSbinitSentDoneReq){
            nextSbTxDin   := SBINIT_DONE_REQ
            nextSbTxValid := true.B
            flagSbinitSentDoneReq := true.B
        }.elsewhen (flagSbinitReceivedDoneReq && !flagSbinitSentDoneResp) {
            nextSbTxDin   := SBINIT_DONE_RESP
            nextSbTxValid := true.B
            flagSbinitSentDoneResp := true.B
        }
      }
      // Completion check: both sides acknowledged and we sent our response
      when (flagSbinitReceivedDoneReq && flagSbinitReceivedDoneResp && 
            flagSbinitSentDoneReq && flagSbinitSentDoneResp) {
        stateReg := LTState.MBINIT_SUPER
      }
    }

    is (LTState.MBINIT_SUPER) {
      when (mbInitFsm.io.done) {
        stateReg := LTState.MBTRAIN
      }
    }

    // ========================================================
    // MBTRAIN -> LINKINIT -> ACTIVE
    // ========================================================

    is (LTState.MBTRAIN) {
      stateReg := LTState.LINKINIT
    }

    is (LTState.LINKINIT) {
      stateReg := LTState.ACTIVE
    }

    is (LTState.ACTIVE) {
      stateReg := LTState.ACTIVE
    }
  }
}