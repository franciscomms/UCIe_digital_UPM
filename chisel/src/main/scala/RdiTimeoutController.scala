package RdiLinkManagement

import chisel3._
import chisel3.util._

class RdiTimeoutController extends Module {
  val io = IO(new Bundle {
    val cycles1us = Input(UInt(32.W))

    val startSidebandReqTimer = Input(Bool())
    val sidebandRspReceived   = Input(Bool())
    val sidebandStallReceived = Input(Bool())
    val clearSidebandReqTimer = Input(Bool())

    val sidebandReqTimerBusy = Output(Bool())
    val sidebandReqTimeoutFlag = Output(Bool())
    val clearTimeoutFlag = Input(Bool())

    val stallResponseActive = Input(Bool())
    val stallSent           = Input(Bool())
    val stallRefreshDue     = Output(Bool())

    val inLinkError            = Input(Bool())
    val linkErrorResidencyDone = Output(Bool())
  })

  val timeout4ms  = io.cycles1us * 4000.U
  val timeout8ms  = io.cycles1us * 8000.U
  val timeout16ms = io.cycles1us * 16000.U

  private def lastCycle(limit: UInt): UInt =
    Mux(limit === 0.U, 0.U, limit - 1.U)

  val sbBusy        = RegInit(false.B)
  val sbCounter     = RegInit(0.U(64.W))
  val sbTimeoutFlag = RegInit(false.B)

  when(io.clearTimeoutFlag) {
    sbTimeoutFlag := false.B
  }

  when(io.clearSidebandReqTimer || io.sidebandRspReceived) {
    sbBusy    := false.B
    sbCounter := 0.U
  
  }.elsewhen(io.startSidebandReqTimer) {
    sbBusy    := true.B
    sbCounter := 0.U
  
  }.elsewhen(sbBusy && io.sidebandStallReceived) {
    sbCounter := 0.U
  
  }.elsewhen(sbBusy) {
    when(sbCounter >= lastCycle(timeout8ms)) {
      sbTimeoutFlag := true.B
      sbBusy        := false.B
      sbCounter     := 0.U
    
    }.otherwise {
      sbCounter := sbCounter + 1.U
    }
  }

  io.sidebandReqTimerBusy    := sbBusy
  io.sidebandReqTimeoutFlag  := sbTimeoutFlag

  val stallCounter = RegInit(0.U(64.W))
  val stallDue     = RegInit(false.B)

  when(!io.stallResponseActive) {
    stallCounter := 0.U
    stallDue     := false.B
  
  }.elsewhen(io.stallSent) {
    stallCounter := 0.U
    stallDue     := false.B
  
  }.elsewhen(!stallDue) {
    when(stallCounter >= lastCycle(timeout4ms)) {
      stallDue := true.B
    
    }.otherwise {
      stallCounter := stallCounter + 1.U
    }
  }

  io.stallRefreshDue := stallDue

  val linkErrorCounter = RegInit(0.U(64.W))
  val linkErrorDone    = RegInit(false.B)

  when(!io.inLinkError) {
    linkErrorCounter := 0.U
    linkErrorDone    := false.B
  
  }.elsewhen(!linkErrorDone) {
    when(linkErrorCounter >= lastCycle(timeout16ms)) {
      linkErrorDone := true.B
    
    }.otherwise {
      linkErrorCounter := linkErrorCounter + 1.U
    }
  }

  io.linkErrorResidencyDone := linkErrorDone
}