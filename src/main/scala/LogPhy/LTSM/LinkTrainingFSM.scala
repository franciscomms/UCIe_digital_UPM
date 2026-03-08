/*
  TODO:
    - add the LTSM status register (Spec Chap: 9.5.3.34)
    - Optimize RESET wait if needed (large counter version implemented)
    - Msg flags need to be reseted
    - Flooding SB TX fifo when sendinf clkPattern and OOR msg
    - implement MBINIT_PARAM negotiation and retries
    - confirm flags reset before entering/ after leaving respective state
    - check rising edge when sending in stages
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

    // needs 4 bits because there are 9 enum states (0..8)
    val state = Output(UInt(4.W))
    
    // debug outputs
    val dbg_flagFirstPattern = Output(Bool())
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
      MBINIT_PARAM, MBINIT, 
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
  val flagSbinitClkPatternSeen  = RegInit(false.B)
  val flagSbinitOorSuccessSeen  = RegInit(false.B)
  val flagFirstPattern = RegInit(false.B)
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

  // ==========================================================
  // Debug signals
  // ==========================================================
  io.dbg_flagFirstPattern := flagFirstPattern
  io.dbg_rxValidRisingEdge := rxValidRisingEdge
  io.dbg_sbinitSendCount := sbinitSendCount
  io.dbg_sbTxValid := sbTxValid
  io.dbg_sbTxDin := sbTxDin

  // ==========================================================
  // Messages reception
  // ==========================================================
  when (rxValidRisingEdge) {
    when (io.sb_rx_dout === SBINIT_CLK_PATTERN) {
      flagSbinitClkPatternSeen := true.B
    } .otherwise {
      // any other word breaks consecutive detection of the clock pattern
      flagFirstPattern := false.B
    }

    when (io.sb_rx_dout === SBINIT_OOR_SUCCESS) {
      flagSbinitOorSuccessSeen := true.B
    }.elsewhen (stateReg === LTState.RESET ||| stateReg === LTState.SBINIT_DONEmsg) {
      // if we see any message other than the expected OOR success during RESET or pattern detection, restart pattern detection
      flagSbinitClkPatternSeen := false.B
      flagFirstPattern := false.B
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
      when (flagSbinitClkPatternSeen) {
        when (flagFirstPattern === false.B) {
          flagFirstPattern := true.B
          flagSbinitClkPatternSeen := false.B
        } .otherwise {
          flagSbinitClkPatternSeen := false.B
          flagFirstPattern := false.B
          stateReg := LTState.SBINIT_sendFour
        }
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
        // clear DONE handshake flags on entry
        flagSbinitReceivedDoneReq  := false.B
        flagSbinitReceivedDoneResp := false.B
        flagSbinitSentDoneResp     := false.B
        flagSbinitSendDoneResp  := false.B
        sentSbinitDoneReq      := false.B
        flagSbinitOorSuccessSeen   := false.B
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
        }.elsewhen (flagSbinitReceivedDoneReq) {
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
        when (!flagMbinitParamSentReqHdr) {
          nextSbTxDin   := MBINIT_PARAM_REQ(63,0)
          nextSbTxValid := true.B
          flagMbinitParamSentReqHdr := true.B
        } .elsewhen (flagMbinitParamSentReqHdr && !flagMbinitParamSentReqPayload) {
          nextSbTxDin   := MBINIT_PARAM_REQ(127,64)
          nextSbTxValid := true.B
          flagMbinitParamSentReqPayload := true.B
        } .elsewhen (
            flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
            flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
            !flagMbinitParamSentRespHdr
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

      when (
        flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
        flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
        flagMbinitParamSentRespHdr && flagMbinitParamSentRespPayload &&
        flagMbinitParamReceivedRespHeader && flagMbinitParamReceivedRespPayload
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