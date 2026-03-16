/*
TODO:
    - maybe io.sb_tx_valid / io.sb_tx_din connected directly on top intead of MUX
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

    val flagToAnalog_RepairClkState = Output(Bool())
    val flagToAnalog_SendClkPatterns = Output(Bool())
    val flagToAnalog_RepairValState = Output(Bool())
    val flagToAnalog_SendValTrainPattern = Output(Bool())

    val substate = Output(UInt(3.W))
    val dbg_mbinitRepairClkSenderState = Output(UInt(3.W))
    val dbg_mbinitRepairClkReceiverState = Output(UInt(3.W))
    val dbg_mbinitRepairValSenderState = Output(UInt(3.W))
    val dbg_mbinitRepairValReceiverState = Output(UInt(3.W))
  })














  object MBInitState extends ChiselEnum {
    val PARAM, CAL, REPAIRCLK, REPAIRVAL, DONE = Value
  }

  object RepairClkSenderState extends ChiselEnum {
    val initReq,
      sendClkPatternsExchange,
      waitingPatternsExchangeFinish,
      sendResultReq,
      receiveResultResp,
      sendDoneReq,
      receiveDoneResp,
      finish = Value
  }

  object RepairClkReceiverState extends ChiselEnum {
    val sendInitResp,
      waitingPatternsExchangeFinish,
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

  val flagMbinitParamReceivedReqHeader = RegInit(false.B)
  val flagMbinitParamReqWaitingPayload = RegInit(false.B)
  val flagMbinitParamReceivedReqPayload = RegInit(false.B)
  val flagMbinitParamSentReqHdr = RegInit(false.B)
  val flagMbinitParamSentReqPayload = RegInit(false.B)
  val flagMbinitParamReceivedRespHeader = RegInit(false.B)
  val flagMbinitParamReceivedRespPayload = RegInit(false.B)
  val flagMbinitParamRespWaitingPayload = RegInit(false.B)
  val flagMbinitParamSentRespHdr = RegInit(false.B)
  val flagMbinitParamSentRespPayload = RegInit(false.B)
  val flagMbinitParamCorrectReqReceived = RegInit(false.B)

  val flagMbinitCalReceivedDoneReq = RegInit(false.B)
  val flagMbinitCalReceivedDoneResp = RegInit(false.B)
  val flagMbinitCalSentDoneReq = RegInit(false.B)
  val flagMbinitCalSentDoneResp = RegInit(false.B)

  val flagMbinitRepairClk_ReceivedInitResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedInitReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedResultReq = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneResp = RegInit(false.B)
  val flagMbinitRepairClk_ReceivedDoneReq = RegInit(false.B)
  val mbinitRepairClk_ReceivedResultBits = RegInit(0.U(3.W))
  val repairClkSenderStateReg = RegInit(RepairClkSenderState.initReq)
  val repairClkReceiverStateReg = RegInit(RepairClkReceiverState.sendInitResp)

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






  io.flagToAnalog_RepairClkState := false.B
  io.flagToAnalog_SendClkPatterns := false.B
  io.flagToAnalog_RepairValState := false.B
  io.flagToAnalog_SendValTrainPattern := false.B

  io.substate := stateReg.asUInt
  io.dbg_mbinitRepairClkSenderState := repairClkSenderStateReg.asUInt
  io.dbg_mbinitRepairClkReceiverState := repairClkReceiverStateReg.asUInt
  io.dbg_mbinitRepairValSenderState := repairValSenderStateReg.asUInt
  io.dbg_mbinitRepairValReceiverState := repairValReceiverStateReg.asUInt

  io.done := running && (stateReg === MBInitState.DONE)
  io.busy := running && (stateReg =/= MBInitState.DONE)























  when(startPulse) {
    running := true.B
    stateReg := MBInitState.PARAM
    trainErrorReg := false.B

    flagMbinitParamReceivedReqHeader := false.B
    flagMbinitParamReqWaitingPayload := false.B
    flagMbinitParamReceivedReqPayload := false.B
    flagMbinitParamSentReqHdr := false.B
    flagMbinitParamSentReqPayload := false.B
    flagMbinitParamReceivedRespHeader := false.B
    flagMbinitParamReceivedRespPayload := false.B
    flagMbinitParamRespWaitingPayload := false.B
    flagMbinitParamSentRespHdr := false.B
    flagMbinitParamSentRespPayload := false.B
    flagMbinitParamCorrectReqReceived := false.B

    flagMbinitCalReceivedDoneReq := false.B
    flagMbinitCalReceivedDoneResp := false.B
    flagMbinitCalSentDoneReq := false.B
    flagMbinitCalSentDoneResp := false.B

    flagMbinitRepairClk_ReceivedInitResp := false.B
    flagMbinitRepairClk_ReceivedInitReq := false.B
    flagMbinitRepairClk_ReceivedResultResp := false.B
    flagMbinitRepairClk_ReceivedResultReq := false.B
    flagMbinitRepairClk_ReceivedDoneResp := false.B
    flagMbinitRepairClk_ReceivedDoneReq := false.B
    mbinitRepairClk_ReceivedResultBits := 0.U
    repairClkSenderStateReg := RepairClkSenderState.initReq
    repairClkReceiverStateReg := RepairClkReceiverState.sendInitResp

    flagMbinitRepairVal_ReceivedInitResp := false.B
    flagMbinitRepairVal_ReceivedInitReq := false.B
    flagMbinitRepairVal_ReceivedResultResp := false.B
    flagMbinitRepairVal_ReceivedResultReq := false.B
    flagMbinitRepairVal_ReceivedDoneResp := false.B
    flagMbinitRepairVal_ReceivedDoneReq := false.B
    mbinitRepairVal_ReceivedResultBit := false.B
    mbinitRepairVal_logValTrainPatternReceived := false.B
    repairValSenderStateReg := RepairValSenderState.initReq
    repairValReceiverStateReg := RepairValReceiverState.sendInitResp

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
      flagMbinitParamReceivedReqHeader := true.B
      flagMbinitParamReqWaitingPayload := true.B
    }
    when(flagMbinitParamReqWaitingPayload) {
      flagMbinitParamReceivedReqPayload := true.B
      flagMbinitParamReqWaitingPayload := false.B
      remoteParamReqPayload := io.sb_rx_dout
    }

    when(io.sb_rx_dout === MBINIT_PARAM_RESP(63, 0)) {
      flagMbinitParamReceivedRespHeader := true.B
      flagMbinitParamRespWaitingPayload := true.B
    }
    when(flagMbinitParamRespWaitingPayload) {
      flagMbinitParamReceivedRespPayload := true.B
      flagMbinitParamRespWaitingPayload := false.B
      remoteParamRespPayload := io.sb_rx_dout
    }

    when(io.sb_rx_dout === MBINIT_CAL_DONE_REQ) {
      flagMbinitCalReceivedDoneReq := true.B
    }

    when(io.sb_rx_dout === MBINIT_CAL_DONE_RESP) {
      flagMbinitCalReceivedDoneResp := true.B
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
  }























  when(running) {
    switch(stateReg) {
      is(MBInitState.PARAM) {
        when(io.sb_tx_ready && !sbTxValid) {
          when(!flagMbinitParamSentReqHdr) {
            nextSbTxDin := MBINIT_PARAM_REQ(63, 0)
            nextSbTxValid := true.B
            flagMbinitParamSentReqHdr := true.B
          }.elsewhen(flagMbinitParamSentReqHdr && !flagMbinitParamSentReqPayload) {
            nextSbTxDin := MBINIT_PARAM_REQ(127, 64)
            nextSbTxValid := true.B
            flagMbinitParamSentReqPayload := true.B
          }

          when(
            flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
            flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
            flagMbinitParamCorrectReqReceived && !flagMbinitParamSentRespHdr
          ) {
            nextSbTxDin := MBINIT_PARAM_RESP(63, 0)
            nextSbTxValid := true.B
            flagMbinitParamSentRespHdr := true.B
          }.elsewhen(flagMbinitParamSentRespHdr && !flagMbinitParamSentRespPayload) {
            nextSbTxDin := MBINIT_PARAM_RESP(127, 64)
            nextSbTxValid := true.B
            flagMbinitParamSentRespPayload := true.B
          }
        }

        when(flagMbinitParamReceivedReqPayload) {
          when(remoteParamReqPayload === MBINIT_PARAM_REQ(127, 64)) {
            flagMbinitParamCorrectReqReceived := true.B
          }.otherwise {
            trainErrorReg := true.B
          }
        }

        when(
          flagMbinitParamSentReqHdr && flagMbinitParamSentReqPayload &&
          flagMbinitParamReceivedReqHeader && flagMbinitParamReceivedReqPayload &&
          flagMbinitParamSentRespHdr && flagMbinitParamSentRespPayload &&
          flagMbinitParamReceivedRespHeader && flagMbinitParamReceivedRespPayload
        ) {
          stateReg := MBInitState.CAL
        }
      }

      is(MBInitState.CAL) {
        when(io.sb_tx_ready && !sbTxValid) {
          when(!flagMbinitCalSentDoneReq) {
            nextSbTxDin := MBINIT_CAL_DONE_REQ
            nextSbTxValid := true.B
            flagMbinitCalSentDoneReq := true.B
          }.elsewhen(flagMbinitCalReceivedDoneReq && !flagMbinitCalSentDoneResp) {
            nextSbTxDin := MBINIT_CAL_DONE_RESP
            nextSbTxValid := true.B
            flagMbinitCalSentDoneResp := true.B
          }
        }

        when(
          flagMbinitCalReceivedDoneReq && flagMbinitCalReceivedDoneResp &&
          flagMbinitCalSentDoneReq && flagMbinitCalSentDoneResp
        ) {
          stateReg := MBInitState.REPAIRCLK
        }
      }

      is(MBInitState.REPAIRCLK) {
        io.flagToAnalog_RepairClkState := true.B

        switch(repairClkSenderStateReg) {
          is(RepairClkSenderState.initReq) {
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkInitReq("phy", "phy")
              nextSbTxValid := true.B
              repairClkSenderStateReg := RepairClkSenderState.sendClkPatternsExchange
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
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkResultReq("phy", "phy")
              nextSbTxValid := true.B
              repairClkSenderStateReg := RepairClkSenderState.receiveResultResp
            }
          }
          is(RepairClkSenderState.receiveResultResp) {
            when(flagMbinitRepairClk_ReceivedResultResp) {
              when(mbinitRepairClk_ReceivedResultBits === "b111".U) {
                repairClkSenderStateReg := RepairClkSenderState.sendDoneReq
              }.otherwise {
                trainErrorReg := true.B
              }
            }
          }
          is(RepairClkSenderState.sendDoneReq) {
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkDoneReq("phy", "phy")
              nextSbTxValid := true.B
              repairClkSenderStateReg := RepairClkSenderState.receiveDoneResp
            }
          }
          is(RepairClkSenderState.receiveDoneResp) {
            when(flagMbinitRepairClk_ReceivedDoneResp) {
              repairClkSenderStateReg := RepairClkSenderState.finish
            }
          }
        }

        switch(repairClkReceiverStateReg) {
          is(RepairClkReceiverState.sendInitResp) {
            when(
              flagMbinitRepairClk_ReceivedInitReq &&
              io.flagFromAnalog_ReadyToExchangeClkPatterns &&
              io.sb_tx_ready && !sbTxValid
            ) {
              nextSbTxDin := MBINIT_REPAIRCLK_INIT_RESP
              nextSbTxValid := true.B
              repairClkReceiverStateReg := RepairClkReceiverState.waitingPatternsExchangeFinish
            }
          }
          is(RepairClkReceiverState.waitingPatternsExchangeFinish) {
            when(flagMbinitRepairClk_ReceivedResultReq) {
              mbinitRepairClk_logClkPatternReceivedRTRK_L := io.flagFromAnalog_clkPatternReceivedRTRK_L
              mbinitRepairClk_logClkPatternReceivedRCKN_L := io.flagFromAnalog_clkPatternReceivedRCKN_L
              mbinitRepairClk_logClkPatternReceivedRCKP_L := io.flagFromAnalog_clkPatternReceivedRCKP_L

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
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairClkResultResp(
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
            when(flagMbinitRepairClk_ReceivedDoneReq) {
              repairClkReceiverStateReg := RepairClkReceiverState.sendDoneResp
            }
          }
          is(RepairClkReceiverState.sendDoneResp) {
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := MBINIT_REPAIRCLK_DONE_RESP
              nextSbTxValid := true.B
              repairClkReceiverStateReg := RepairClkReceiverState.finish
            }
          }
        }

        when(
          repairClkReceiverStateReg === RepairClkReceiverState.finish &&
          repairClkSenderStateReg === RepairClkSenderState.finish
        ) {
          stateReg := MBInitState.REPAIRVAL
        }
      }

      is(MBInitState.REPAIRVAL) {
        io.flagToAnalog_RepairValState := true.B

        switch(repairValSenderStateReg) {
          is(RepairValSenderState.initReq) {
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValInitReq("phy", "phy")
              nextSbTxValid := true.B
              repairValSenderStateReg := RepairValSenderState.sendValTrainPattern
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
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValResultReq("phy", "phy")
              nextSbTxValid := true.B
              repairValSenderStateReg := RepairValSenderState.receiveResultResp
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
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := SidebandMsgGenerator.msgMbinitRepairValDoneReq("phy", "phy")
              nextSbTxValid := true.B
              repairValSenderStateReg := RepairValSenderState.receiveDoneResp
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
              io.flagFromAnalog_ReadyToExchangeClkPatterns &&
              io.sb_tx_ready && !sbTxValid
            ) {
              nextSbTxDin := MBINIT_REPAIRVAL_INIT_RESP
              nextSbTxValid := true.B
              repairValReceiverStateReg := RepairValReceiverState.waitingValTrainPatternFinish
            }
          }
          is(RepairValReceiverState.waitingValTrainPatternFinish) {
            when(flagMbinitRepairVal_ReceivedResultReq) {
              mbinitRepairVal_logValTrainPatternReceived := io.flagFromAnalog_ValTrainPatternReceived
              repairValReceiverStateReg := RepairValReceiverState.sendResultResp
            }
          }
          is(RepairValReceiverState.sendResultResp) {
            when(io.sb_tx_ready && !sbTxValid) {
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
            when(flagMbinitRepairVal_ReceivedDoneReq) {
              repairValReceiverStateReg := RepairValReceiverState.sendDoneResp
            }
          }
          is(RepairValReceiverState.sendDoneResp) {
            when(io.sb_tx_ready && !sbTxValid) {
              nextSbTxDin := MBINIT_REPAIRVAL_DONE_RESP
              nextSbTxValid := true.B
              repairValReceiverStateReg := RepairValReceiverState.finish
            }
          }
        }

        when(
          repairValReceiverStateReg === RepairValReceiverState.finish &&
          repairValSenderStateReg === RepairValSenderState.finish
        ) {
          stateReg := MBInitState.DONE
        }
      }

      is(MBInitState.DONE) {
        stateReg := MBInitState.DONE
      }
    }
  }
}
