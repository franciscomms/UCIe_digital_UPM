/*
  TODO:
    - add the LTSM status register (Spec Chap: 9.5.3.34)
    - Optimize RESET wait if needed (large counter version implemented)
    - Msg flags need to be reseted
*/

package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

class LinkTrainingFSM extends Module {
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
        MBINIT, 
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
  val flagFirstPattern = RegInit(false.B)
  val sbinitSendCount = RegInit(0.U(3.W))

  // SBINIT_DONEmsg handshaking flags
  val flagReceivedSbinitDoneReq  = RegInit(false.B)
  val flagReceivedSbinitDoneResp = RegInit(false.B)
  val sentSbinitDoneResp     = RegInit(false.B)
  val flagSendSbinitDoneResp  = RegInit(false.B)

  // Message detection flags (set on RX rising edge, consumed in FSM)
  val flagSbinitClkPatternSeen          = RegInit(false.B)
  val flagSbinitOorSuccessSeen   = RegInit(false.B)

  // previous-cycle register for sb_rx_valid and rising-edge detector
  val prevRxValid = RegNext(io.sb_rx_valid, false.B)
  val rxValidRisingEdge = io.sb_rx_valid && (!prevRxValid)

  
  // ==========================================================
  // Patterns
  // ==========================================================
  val SBINIT_CLK_PATTERN = "hAAAAAAAAAAAAAAAA".U(64.W)
  val SBINIT_OOR_SUCCESS = SidebandMsgGenerator.msgWithoutData("SBINIT_out_of_Reset_success", "phy", "phy")
  val SBINIT_DONE_REQ    = SidebandMsgGenerator.msgWithoutData("SBINIT_done_req",  "phy", "phy")
  val SBINIT_DONE_RESP   = SidebandMsgGenerator.msgWithoutData("SBINIT_done_resp", "phy", "phy")
  val MBINIT_PARAM_REQ   = 0//TBD - SidebandMsgGenerator.msgWithoutData("MBINIT_param_req", "phy", "phy")

  // ==========================================================
  // Default TX outputs (idle) are driven by next-state wires above
  // ==========================================================
  
  // expose debug signals
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
    }

    when (io.sb_rx_dout === SBINIT_DONE_REQ) {
      flagReceivedSbinitDoneReq  := true.B
      flagSendSbinitDoneResp  := true.B
    }

    when (io.sb_rx_dout === SBINIT_DONE_RESP) {
      flagReceivedSbinitDoneResp := true.B
    }

    when (io.sb_rx_dout === MBINIT_PARAM_REQ) {
      flagReceivedMbinitParamReq := true.B
      flagWaitingMbinitParamReqPayload := true.B
    }
    when (flagWaitingMbinitParamReqPayload) {
      //get all the data from the payload and set flag to false
    }

    
  }

  // ==========================================================
  // FSM logic
  // ==========================================================
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
        flagReceivedSbinitDoneReq  := false.B
        flagReceivedSbinitDoneResp := false.B
        sentSbinitDoneResp     := false.B
        flagSendSbinitDoneResp  := false.B
        flagSbinitOorSuccessSeen   := false.B
        stateReg := LTState.SBINIT_DONEmsg
      }
    }

    // ========================================================
    // SBINIT_DONEmsg 
    // ========================================================
    is (LTState.SBINIT_DONEmsg) {
      // TX scheduling: prioritize sending the response when pending, otherwise keep sending reqs
      when (io.sb_tx_ready && !sbTxValid) {
        when (flagSendSbinitDoneResp) {
          nextSbTxDin   := SBINIT_DONE_RESP
          nextSbTxValid := true.B
          flagSendSbinitDoneResp := false.B
          sentSbinitDoneResp := true.B
        } .otherwise {
          nextSbTxDin   := SBINIT_DONE_REQ
          nextSbTxValid := true.B
        }
      }

      // Completion check: both sides acknowledged and we sent our response
      when (flagReceivedSbinitDoneReq && flagReceivedSbinitDoneResp && sentSbinitDoneResp) {
        stateReg := LTState.MBINIT
      }
    }


    // ========================================================
    // MBINIT -> MBTRAIN -> LINKINIT -> ACTIVE
    // ========================================================
    is (LTState.MBINIT) {
      stateReg := LTState.MBTRAIN
    }

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