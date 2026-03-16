/*
  TODO:
    - add the LTSM status register (Spec Chap: 9.5.3.34)
    - Optimize RESET wait if needed (large counter version implemented)
    - check flags reset
    - Flooding SB TX fifo when sendinf clkPattern and OOR msg -- add counter
    - implement MBINIT_PARAM negotiation and retries
    - check rising edge when sending in stages
    - DO training error
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
    val flagFromAnalog_clkPatternReceivedRTRK_L   = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKN_L   = Input(Bool())
    val flagFromAnalog_clkPatternReceivedRCKP_L   = Input(Bool())
    val flagFromAnalog_ValTrainPatternReceived    = Input(Bool())
    val flagToAnalog_RepairClkState               = Output(Bool())
    val flagToAnalog_SendClkPatterns              = Output(Bool()) //look where is reset being done
    val flagToAnalog_RepairValState               = Output(Bool())
    val flagToAnalog_SendValTrainPattern          = Output(Bool())

    // needs 4 bits because there are 12 enum states (0..11)
    val state = Output(UInt(4.W))
    
    // debug outputs
    val dbg_flagSbinitFirstClkPatternSeen = Output(Bool())
    val dbg_rxValidRisingEdge = Output(Bool())
    val dbg_sbinitSendCount = Output(UInt(3.W))
    val dbg_sbTxValid = Output(Bool()) 
    val dbg_sbTxDin = Output(UInt(64.W))
    val dbg_flagTrainError = Output(Bool())
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
  io.sb_tx_valid := sbTxValid
  io.sb_tx_din   := sbTxDin

  // ==========================================================
  // LINK TRAINING FSM
  // ==========================================================
  object LTState extends ChiselEnum {
    val RESET, 
      SBINIT_pattern,SBINIT_sendFour, SBINIT_OORmsg, SBINIT_DONEmsg,
      MBINIT_PARAM, MBINIT_Cal, MBINIT_REPAIRCLK, MBINIT_REPAIRVAL, MBINIT, 
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
  io.dbg_sbTxValid := sbTxValid
  io.dbg_sbTxDin := sbTxDin
  io.dbg_flagTrainError := flagTrainError
  io.flagToAnalog_RepairClkState := false.B
  io.flagToAnalog_SendClkPatterns := false.B
  io.flagToAnalog_RepairValState := false.B
  io.flagToAnalog_SendValTrainPattern := false.B

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
        stateReg := LTState.MBINIT_PARAM
      }
    }


    // ========================================================
    // MBINIT 
    // ========================================================

    //MBINIT_PARAM STRICT MATCH (no negotiation)
    //  implement negotiation and retries if needed
    is (LTState.MBINIT_PARAM) {

      when (io.sb_tx_ready && !sbTxValid) {
        //SEND REQ
        //Send req header
        when (!flagMbinitParamSentReqHdr) {
          nextSbTxDin   := MBINIT_PARAM_REQ(63,0)
          nextSbTxValid := true.B
          flagMbinitParamSentReqHdr := true.B
        // send req payload
        } .elsewhen (flagMbinitParamSentReqHdr && !flagMbinitParamSentReqPayload) {
          nextSbTxDin   := MBINIT_PARAM_REQ(127,64)
          nextSbTxValid := true.B
          flagMbinitParamSentReqPayload := true.B
        }
        //SEND RESP
        //done in a different block to avoid req conflic with resp payloads
        when (
            flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
            flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
            flagMbinitParamCorrectReqReceived && !flagMbinitParamSentRespHdr
            ) {
          nextSbTxDin   := MBINIT_PARAM_RESP(63,0)
          nextSbTxValid := true.B
          flagMbinitParamSentRespHdr := true.B
        } .elsewhen (
            flagMbinitParamSentRespHdr && !flagMbinitParamSentRespPayload
            ) {
          nextSbTxDin   := MBINIT_PARAM_RESP(127,64)
          nextSbTxValid := true.B
          flagMbinitParamSentRespPayload := true.B
        }
      }

      // Request payload reception logic
      //update to add negotiation
      when (flagMbinitParamReceivedReqPayload) {
        //exact payload match check for now, add negotiation logic if not matching
        when (remoteParamReqPayload === MBINIT_PARAM_REQ(127,64)) {
          flagMbinitParamCorrectReqReceived := true.B
        } .otherwise {
          flagTrainError := true.B
        }
      } 


      //next state logic
      when (
        flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
        flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
        flagMbinitParamSentRespHdr && flagMbinitParamSentRespPayload &&
        flagMbinitParamReceivedRespHeader && flagMbinitParamReceivedRespPayload
      ) {
        stateReg := LTState.MBINIT_Cal
      }
    }

    is (LTState.MBINIT_Cal) {
      //will there be any calibration in this state?
      when (io.sb_tx_ready && !sbTxValid) {
        when (!flagMbinitCalSentDoneReq) {
          nextSbTxDin   := MBINIT_CAL_DONE_REQ
          nextSbTxValid := true.B
          flagMbinitCalSentDoneReq := true.B
        }.elsewhen (flagMbinitCalReceivedDoneReq && !flagMbinitCalSentDoneResp) {
          nextSbTxDin   := MBINIT_CAL_DONE_RESP
          nextSbTxValid := true.B
          flagMbinitCalSentDoneResp := true.B
        }
      }

      when (
        flagMbinitCalReceivedDoneReq && flagMbinitCalReceivedDoneResp &&
        flagMbinitCalSentDoneReq && flagMbinitCalSentDoneResp
      ) {
        stateReg := LTState.MBINIT_REPAIRCLK
      }
    }

    is (LTState.MBINIT_REPAIRCLK) {

      io.flagToAnalog_RepairClkState := true.B
      //sender
      switch(repairClkSenderStateReg) {
        is(RepairClkSenderState.initReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")
            nextSbTxValid := true.B
            repairClkSenderStateReg := RepairClkSenderState.sendClkPatternsExchange
          }
        }
        is(RepairClkSenderState.sendClkPatternsExchange) {
          when (flagMbinitRepairClk_ReceivedInitResp && io.flagFromAnalog_ReadyToExchangeClkPatterns) {
            io.flagToAnalog_SendClkPatterns := true.B
            repairClkSenderStateReg := RepairClkSenderState.waitingPatternsExchangeFinish
          }
        }
        is(RepairClkSenderState.waitingPatternsExchangeFinish) {
          when (io.flagFromAnalog_FinishedClkPatterns) {
            repairClkSenderStateReg := RepairClkSenderState.sendResultReq
          }
        }
        is(RepairClkSenderState.sendResultReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")
            nextSbTxValid := true.B
            repairClkSenderStateReg := RepairClkSenderState.receiveResultResp
          }
        }
        is(RepairClkSenderState.receiveResultResp) {
          when (flagMbinitRepairClk_ReceivedResultResp){
            //check the result bits in the response and set train error if not successful
            when (mbinitRepairClk_ReceivedResultBits === "b111".U) {
              //successful exchange
              repairClkSenderStateReg := RepairClkSenderState.sendDoneReq
            }.otherwise {
              //repair failed, set train error flag
              flagTrainError := true.B
            }
          }
        }
        is(RepairClkSenderState.sendDoneReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")
            nextSbTxValid := true.B
            repairClkSenderStateReg := RepairClkSenderState.receiveDoneResp
          }
        }
        is(RepairClkSenderState.receiveDoneResp) {
          when (flagMbinitRepairClk_ReceivedDoneResp) {
            repairClkSenderStateReg := RepairClkSenderState.finish
          }
        }
      }

      //receiver
      switch(repairClkReceiverStateReg) {
        is(RepairClkReceiverState.sendInitResp) {
          when (flagMbinitRepairClk_ReceivedInitReq
                  && io.flagFromAnalog_ReadyToExchangeClkPatterns
                  && io.sb_tx_ready && !sbTxValid){
            nextSbTxDin   := MBINIT_REPAIRCLK_INIT_RESP
            nextSbTxValid := true.B
            repairClkReceiverStateReg := RepairClkReceiverState.waitingPatternsExchangeFinish
          }
        }
        //after receiving resp partner sends clk patterns and after that sends resultReq
          //wait for msgResultReq and when arrives check AN signal for correct patterns
        is(RepairClkReceiverState.waitingPatternsExchangeFinish) {
          when (flagMbinitRepairClk_ReceivedResultReq) { //resultReq = partner finished sending patterns
            //TODO: LOG the results
            mbinitRepairClk_logClkPatternReceivedRTRK_L := io.flagFromAnalog_clkPatternReceivedRTRK_L
            mbinitRepairClk_logClkPatternReceivedRCKN_L := io.flagFromAnalog_clkPatternReceivedRCKN_L
            mbinitRepairClk_logClkPatternReceivedRCKP_L := io.flagFromAnalog_clkPatternReceivedRCKP_L

            //check the flags from analog to see if all lanes received the patterns correctly and send response accordingly
            when(io.flagFromAnalog_clkPatternReceivedRTRK_L
              && io.flagFromAnalog_clkPatternReceivedRCKN_L
              && io.flagFromAnalog_clkPatternReceivedRCKP_L
            ){//all clk lanes received correct patterns
              repairClkReceiverStateReg := RepairClkReceiverState.sendResultResp
            }.otherwise {
              //if any lane didnt receive correct pattern send response with failure result bits
              flagTrainError := true.B
            }
          }
        }
        is(RepairClkReceiverState.sendResultResp) {
          when (io.sb_tx_ready && !sbTxValid){
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairClkResultResp(
              "phy",
              "phy",
              mbinitRepairClk_logClkPatternReceivedRTRK_L,
              mbinitRepairClk_logClkPatternReceivedRCKN_L,
              mbinitRepairClk_logClkPatternReceivedRCKP_L
            )
            nextSbTxValid := true.B
            repairClkReceiverStateReg := RepairClkReceiverState.receiveDoneReq
          }
        }
        is(RepairClkReceiverState.receiveDoneReq) {
          when (flagMbinitRepairClk_ReceivedDoneReq) {
            repairClkReceiverStateReg := RepairClkReceiverState.sendDoneResp
          }
        }
        is(RepairClkReceiverState.sendDoneResp) {
          when (io.sb_tx_ready && !sbTxValid){
            nextSbTxDin   := MBINIT_REPAIRCLK_DONE_RESP
            nextSbTxValid := true.B
            repairClkReceiverStateReg := RepairClkReceiverState.finish

          }
        }
      }

      when (repairClkReceiverStateReg === RepairClkReceiverState.finish 
            && repairClkSenderStateReg === RepairClkSenderState.finish) {
        stateReg := LTState.MBINIT_REPAIRVAL
      }

    }

    is (LTState.MBINIT_REPAIRVAL) {

      io.flagToAnalog_RepairValState := true.B

      // sender
      switch(repairValSenderStateReg) {
        is(RepairValSenderState.initReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairValInitReq("phy", "phy")
            nextSbTxValid := true.B
            repairValSenderStateReg := RepairValSenderState.sendValTrainPattern
          }
        }
        is(RepairValSenderState.sendValTrainPattern) {
          when (flagMbinitRepairVal_ReceivedInitResp && io.flagFromAnalog_ReadyToExchangeClkPatterns) {
            io.flagToAnalog_SendValTrainPattern := true.B
            repairValSenderStateReg := RepairValSenderState.waitingValTrainPatternFinish
          }
        }
        is(RepairValSenderState.waitingValTrainPatternFinish) {
          when (io.flagFromAnalog_FinishedValTrainPattern) {
            repairValSenderStateReg := RepairValSenderState.sendResultReq
          }
        }
        is(RepairValSenderState.sendResultReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairValResultReq("phy", "phy")
            nextSbTxValid := true.B
            repairValSenderStateReg := RepairValSenderState.receiveResultResp
          }
        }
        is(RepairValSenderState.receiveResultResp) {
          when (flagMbinitRepairVal_ReceivedResultResp) {
            when (mbinitRepairVal_ReceivedResultBit) {
              repairValSenderStateReg := RepairValSenderState.sendDoneReq
            }.otherwise {
              flagTrainError := true.B
            }
          }
        }
        is(RepairValSenderState.sendDoneReq) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := SidebandMsgGenerator.msgMbinitRepairValDoneReq("phy", "phy")
            nextSbTxValid := true.B
            repairValSenderStateReg := RepairValSenderState.receiveDoneResp
          }
        }
        is(RepairValSenderState.receiveDoneResp) {
          when (flagMbinitRepairVal_ReceivedDoneResp) {
            repairValSenderStateReg := RepairValSenderState.finish
          }
        }
      }

      // receiver
      switch(repairValReceiverStateReg) {
        is(RepairValReceiverState.sendInitResp) {
          when (flagMbinitRepairVal_ReceivedInitReq
                  && io.flagFromAnalog_ReadyToExchangeClkPatterns
                  && io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := MBINIT_REPAIRVAL_INIT_RESP
            nextSbTxValid := true.B
            repairValReceiverStateReg := RepairValReceiverState.waitingValTrainPatternFinish
          }
        }
        is(RepairValReceiverState.waitingValTrainPatternFinish) {
          when (flagMbinitRepairVal_ReceivedResultReq) {
            mbinitRepairVal_logValTrainPatternReceived := io.flagFromAnalog_ValTrainPatternReceived
            repairValReceiverStateReg := RepairValReceiverState.sendResultResp
          }
        }
        is(RepairValReceiverState.sendResultResp) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValResultResp(
              "phy",
              "phy",
              mbinitRepairVal_logValTrainPatternReceived
            )
            nextSbTxValid := true.B
            repairValReceiverStateReg := RepairValReceiverState.receiveDoneReq
          }
        }
        is(RepairValReceiverState.receiveDoneReq) {
          when (flagMbinitRepairVal_ReceivedDoneReq) {
            repairValReceiverStateReg := RepairValReceiverState.sendDoneResp
          }
        }
        is(RepairValReceiverState.sendDoneResp) {
          when (io.sb_tx_ready && !sbTxValid) {
            nextSbTxDin   := MBINIT_REPAIRVAL_DONE_RESP
            nextSbTxValid := true.B
            repairValReceiverStateReg := RepairValReceiverState.finish
          }
        }
      }

      when (repairValReceiverStateReg === RepairValReceiverState.finish &&
            repairValSenderStateReg === RepairValSenderState.finish) {
        stateReg := LTState.MBINIT
      }
    }

      

    is (LTState.MBINIT) {
      stateReg := LTState.MBTRAIN
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