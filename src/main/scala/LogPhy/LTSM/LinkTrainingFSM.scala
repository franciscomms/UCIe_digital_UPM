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

    // needs 4 bits because there are 12 enum states (0..11)
    val state = Output(UInt(4.W))
    
    // debug outputs
    val dbg_flagSbinitFirstClkPatternSeen = Output(Bool())
    val dbg_rxValidRisingEdge = Output(Bool())
    val dbg_sbinitSendCount = Output(UInt(3.W))
    val dbg_sbTxValid = Output(Bool()) 
    val dbg_sbTxDin = Output(UInt(64.W))
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
      MBINIT_PARAM, MBINIT_Cal, MBINIT_REPAIRCLK, MBINIT, 
      MBTRAIN, 
      LINKINIT, 
      ACTIVE = Value
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
  // MBINIT.REPAIRCLK handshake flags
  val flagMbinitRepairClkReceivedInitReq   = RegInit(false.B)
  val flagMbinitRepairClkReceivedInitResp  = RegInit(false.B)
  val flagMbinitRepairClkSentInitReq       = RegInit(false.B)
  val flagMbinitRepairClkSentInitResp      = RegInit(false.B)
  val flagMbinitRepairClkReceivedResultReq  = RegInit(false.B)
  val flagMbinitRepairClkReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairClkSentResultReq      = RegInit(false.B)
  val flagMbinitRepairClkSentResultResp     = RegInit(false.B)
  val flagMbinitRepairClkReceivedDoneReq   = RegInit(false.B)
  val flagMbinitRepairClkReceivedDoneResp  = RegInit(false.B)
  val flagMbinitRepairClkSentDoneReq       = RegInit(false.B)
  val flagMbinitRepairClkSentDoneResp      = RegInit(false.B)
  val repairClkLaneIdx = RegInit(0.U(2.W)) // 0=RCKP_L, 1=RCKN_L, 2=RTRK_L
  val flagRCKP_LSentPattern         = RegInit(false.B)
  val flagRCKP_LDetectedCorrectly   = RegInit(false.B)
  val flagRCKP_LDetectedIncorrectly = RegInit(false.B)
  val flagRCKN_LSentPattern         = RegInit(false.B)
  val flagRCKN_LDetectedCorrectly   = RegInit(false.B)
  val flagRCKN_LDetectedIncorrectly = RegInit(false.B)
  val flagRTRK_LSentPattern         = RegInit(false.B)
  val flagRTRK_LDetectedCorrectly   = RegInit(false.B)
  val flagRTRK_LDetectedIncorrectly = RegInit(false.B)
  // TRAIN ERROR
  val flagTrainError = RegInit(false.B)



  // MBINIT_PARAM payloads
  val remoteParamReqPayload           = RegInit(0.U(64.W))
  val remoteParamRespPayload          = RegInit(0.U(64.W))

  // previous-cycle register for sb_rx_valid and rising-edge detector
  val prevRxValid = RegNext(io.sb_rx_valid, false.B)
  val rxValidRisingEdge = io.sb_rx_valid && (!prevRxValid)
  val prevState = RegNext(stateReg, LTState.RESET)

  //CHECK this logic
  val enteringMbinitRepairClk = stateReg === LTState.MBINIT_REPAIRCLK && prevState =/= LTState.MBINIT_REPAIRCLK

  val clearMbinitRepairClkReceivedInitReq    = WireDefault(false.B)
  val clearMbinitRepairClkReceivedInitResp   = WireDefault(false.B)
  val clearMbinitRepairClkReceivedResultReq  = WireDefault(false.B)
  val clearMbinitRepairClkReceivedResultResp = WireDefault(false.B)
  val clearMbinitRepairClkReceivedDoneReq    = WireDefault(false.B)
  val clearMbinitRepairClkReceivedDoneResp   = WireDefault(false.B)

  
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
  val MBINIT_REPAIRCLK_INIT_REQ   = SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")
  val MBINIT_REPAIRCLK_INIT_RESP  = SidebandMsgGenerator.msgMbinitRepairClkInitResp("phy", "phy")
  val MBINIT_REPAIRCLK_RESULT_REQ = SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")
  val MBINIT_REPAIRCLK_RESULT_RESP = SidebandMsgGenerator.msgMbinitRepairClkResultResp("phy", "phy")
  val MBINIT_REPAIRCLK_DONE_REQ   = SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")
  val MBINIT_REPAIRCLK_DONE_RESP  = SidebandMsgGenerator.msgMbinitRepairClkDoneResp("phy", "phy")

  // ==========================================================
  // Debug signals
  // ==========================================================
  io.dbg_flagSbinitFirstClkPatternSeen := flagSbinitFirstClkPatternSeen
  io.dbg_rxValidRisingEdge := rxValidRisingEdge
  io.dbg_sbinitSendCount := sbinitSendCount
  io.dbg_sbTxValid := sbTxValid
  io.dbg_sbTxDin := sbTxDin

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

      when (
        stateReg === LTState.MBINIT_REPAIRCLK &&
        flagMbinitRepairClkSentResultReq && !flagMbinitRepairClkReceivedResultResp &&
        io.sb_rx_dout =/= MBINIT_REPAIRCLK_RESULT_RESP
      ) {
        switch(repairClkLaneIdx) {
          is(0.U) { flagRCKP_LDetectedIncorrectly := true.B }
          is(1.U) { flagRCKN_LDetectedIncorrectly := true.B }
          is(2.U) { flagRTRK_LDetectedIncorrectly := true.B }
        }
        flagTrainError := true.B
      }
    }
  }

  // MBINIT.REPAIRCLK received flags ownership:
  // 1) clear on state entry or explicit consume, 2) set on RX edge match
  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedInitReq) {
    flagMbinitRepairClkReceivedInitReq := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_INIT_REQ) {
    flagMbinitRepairClkReceivedInitReq := true.B
  }

  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedInitResp) {
    flagMbinitRepairClkReceivedInitResp := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_INIT_RESP) {
    flagMbinitRepairClkReceivedInitResp := true.B
  }

  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedResultReq) {
    flagMbinitRepairClkReceivedResultReq := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_RESULT_REQ) {
    flagMbinitRepairClkReceivedResultReq := true.B
  }

  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedResultResp) {
    flagMbinitRepairClkReceivedResultResp := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_RESULT_RESP) {
    flagMbinitRepairClkReceivedResultResp := true.B
  }

  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedDoneReq) {
    flagMbinitRepairClkReceivedDoneReq := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_DONE_REQ) {
    flagMbinitRepairClkReceivedDoneReq := true.B
  }

  when (enteringMbinitRepairClk || clearMbinitRepairClkReceivedDoneResp) {
    flagMbinitRepairClkReceivedDoneResp := false.B
  }.elsewhen (rxValidRisingEdge && io.sb_rx_dout === MBINIT_REPAIRCLK_DONE_RESP) {
    flagMbinitRepairClkReceivedDoneResp := true.B
  }

  // Reset MBINIT.REPAIRCLK flags on state entry to avoid stale retrain state
  when (enteringMbinitRepairClk) {
    flagMbinitRepairClkSentInitReq := false.B
    flagMbinitRepairClkSentInitResp := false.B
    flagMbinitRepairClkSentResultReq := false.B
    flagMbinitRepairClkSentResultResp := false.B
    flagMbinitRepairClkSentDoneReq := false.B
    flagMbinitRepairClkSentDoneResp := false.B
    repairClkLaneIdx := 0.U
    flagRCKP_LSentPattern := false.B
    flagRCKP_LDetectedCorrectly := false.B
    flagRCKP_LDetectedIncorrectly := false.B
    flagRCKN_LSentPattern := false.B
    flagRCKN_LDetectedCorrectly := false.B
    flagRCKN_LDetectedIncorrectly := false.B
    flagRTRK_LSentPattern := false.B
    flagRTRK_LDetectedCorrectly := false.B
    flagRTRK_LDetectedIncorrectly := false.B
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
      when (io.sb_tx_ready && !sbTxValid) {
        // respond to partner requests first
        when (flagMbinitRepairClkReceivedDoneReq && !flagMbinitRepairClkSentDoneResp) {
          nextSbTxDin   := MBINIT_REPAIRCLK_DONE_RESP
          nextSbTxValid := true.B
          flagMbinitRepairClkSentDoneResp := true.B
        }.elsewhen (flagMbinitRepairClkReceivedResultReq && !flagMbinitRepairClkSentResultResp) {
          nextSbTxDin   := MBINIT_REPAIRCLK_RESULT_RESP
          nextSbTxValid := true.B
          flagMbinitRepairClkSentResultResp := true.B
        }.elsewhen (flagMbinitRepairClkReceivedInitReq && !flagMbinitRepairClkSentInitResp) {
          nextSbTxDin   := MBINIT_REPAIRCLK_INIT_RESP
          nextSbTxValid := true.B
          flagMbinitRepairClkSentInitResp := true.B
        }
        // active lane flow (RCKP_L, RCKN_L, RTRK_L)
        .elsewhen (!flagTrainError && repairClkLaneIdx <= 2.U) {
          when (!flagMbinitRepairClkSentInitReq) {
            nextSbTxDin   := MBINIT_REPAIRCLK_INIT_REQ
            nextSbTxValid := true.B
            flagMbinitRepairClkSentInitReq := true.B
          }.elsewhen (flagMbinitRepairClkReceivedInitResp) {
            // Placeholder for 128 iterations clock repair pattern (not implemented here)
            // TODO: real pattern generation (16 clocks + 8 low, pattern not scrambled)
            switch(repairClkLaneIdx) {
              is(0.U) { flagRCKP_LSentPattern := true.B }
              is(1.U) { flagRCKN_LSentPattern := true.B }
              is(2.U) { flagRTRK_LSentPattern := true.B }
            }

            when (!flagMbinitRepairClkSentResultReq) {
              nextSbTxDin   := MBINIT_REPAIRCLK_RESULT_REQ
              nextSbTxValid := true.B
              flagMbinitRepairClkSentResultReq := true.B
            }
          }
        }
        // after 3 lanes, close with done req
        .elsewhen (!flagTrainError && repairClkLaneIdx === 3.U && !flagMbinitRepairClkSentDoneReq) {
          nextSbTxDin   := MBINIT_REPAIRCLK_DONE_REQ
          nextSbTxValid := true.B
          flagMbinitRepairClkSentDoneReq := true.B
        }
      }

      // per-lane completion: advance lane only after RESULT_RESP for that lane
      when (
        !flagTrainError && repairClkLaneIdx <= 2.U &&
        flagMbinitRepairClkSentResultReq && flagMbinitRepairClkReceivedResultResp
      ) {
        // TODO: real detection decode from result resp payload
        switch(repairClkLaneIdx) {
          is(0.U) { flagRCKP_LDetectedCorrectly := true.B }
          is(1.U) { flagRCKN_LDetectedCorrectly := true.B }
          is(2.U) { flagRTRK_LDetectedCorrectly := true.B }
        }

        repairClkLaneIdx := repairClkLaneIdx + 1.U
        clearMbinitRepairClkReceivedInitReq := true.B
        clearMbinitRepairClkReceivedInitResp := true.B
        flagMbinitRepairClkSentInitReq := false.B
        flagMbinitRepairClkSentInitResp := false.B
        clearMbinitRepairClkReceivedResultReq := true.B
        clearMbinitRepairClkReceivedResultResp := true.B
        flagMbinitRepairClkSentResultReq := false.B
        flagMbinitRepairClkSentResultResp := false.B
      }

      when (flagRCKP_LDetectedIncorrectly || flagRCKN_LDetectedIncorrectly || flagRTRK_LDetectedIncorrectly) {
        flagTrainError := true.B
        // TODO: TRAINERROR handling (perform TRAINERROR handshake and transition)
      }

      when (
        !flagTrainError &&
        flagRCKP_LDetectedCorrectly && flagRCKN_LDetectedCorrectly && flagRTRK_LDetectedCorrectly &&
        flagMbinitRepairClkReceivedDoneReq && flagMbinitRepairClkReceivedDoneResp &&
        flagMbinitRepairClkSentDoneReq && flagMbinitRepairClkSentDoneResp
      ) {
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