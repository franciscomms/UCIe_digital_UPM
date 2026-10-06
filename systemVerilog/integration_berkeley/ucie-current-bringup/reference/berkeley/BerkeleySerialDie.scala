package edu.berkeley.cs.uciedigital.serialinterop

import chisel3._
import chisel3.util._
import _root_.circt.stage.ChiselStage
import edu.berkeley.cs.uciedigital.interfaces._
import edu.berkeley.cs.uciedigital.sideband._
import edu.berkeley.cs.uciedigital.logphy._
import edu.berkeley.cs.uciedigital.d2dadapter._

/** Complete upstream D2DAdapter and LogicalPhy, including actual sideband serdes. */
class BerkeleySerialDie extends Module {
  val io = IO(new Bundle {
    val start = Input(Bool())
    val pwrGood = Input(Bool())
    val protocolActive = Input(Bool())
    val sbOutClock = Output(Clock())
    val sbD0 = Output(Bool())
    val sbD1 = Output(Bool())
    val sbClockD0 = Output(Bool())
    val sbClockD1 = Output(Bool())
    val sbInData = Input(Bool())
    val sbInClock = Input(Bool())
    // Full digital mainband port. The supplied UPM top has no matching datapath.
    val mainband = new MainbandLaneIO(AfeParams(mbLanes = 16, mbSerializerRatio = 32))
    val ltState = Output(UInt(4.W))
    val detailState = Output(UInt(5.W))
    val rdiState = Output(UInt(4.W))
    val fdiState = Output(UInt(4.W))
    val phyReady = Output(Bool())
    val waitProtocol = Output(Bool())
    val allActive = Output(Bool())
    val trainError = Output(Bool())
    val sbFault = Output(Bool())
  })
  val phy = Module(new LogicalPhy(
    afeParams = AfeParams(mbLanes = 16, mbSerializerRatio = 32),
    sbParams = SidebandParams(), rdiParams = RdiParams(64, 32)))
  val adapter = Module(new D2DAdapter(FdiParams(64, 32), RdiParams(64, 32), SidebandParams()))
  adapter.io.rdi <> phy.io.rdi
  val sb = phy.io.analog.sidebandLink
  io.sbOutClock := sb.out.clk
  io.sbD0 := sb.out.d0.asBool
  io.sbD1 := sb.out.d1.asBool
  io.sbClockD0 := sb.out.fwClockD0.asBool
  io.sbClockD1 := sb.out.fwClockD1.asBool
  sb.in.bits := io.sbInData.asUInt
  sb.in.fwClock := io.sbInClock.asUInt
  io.mainband <> phy.io.analog.mainband

  phy.io.ctrl.pwrGood := io.pwrGood
  phy.io.ctrl.swStartLinkTraining := io.start
  phy.io.ctrl.retryTrainingAmt := 0.U
  phy.io.ctrl.maxErrorThresholdPerLane := 0.U
  phy.io.ctrl.changeInRuntimeLinkCtrlRegsDetected := false.B
  phy.io.ctrl.runtimeLinkCtrlBusyBit := false.B
  phy.io.ctrl.runtimeRequestForRepair := false.B
  phy.io.ctrl.swRetrainRequest := false.B
  phy.io.ctrl.linkOpParamOverride := false.B
  phy.io.ctrl.clockPhaseSelect := 0.U
  phy.io.ctrl.localPhyParamSettings.valid := true.B
  phy.io.ctrl.localPhyParamSettings.bits := 0.U.asTypeOf(new PHYParamExchangeIO)
  // Match the supplied UPM test model: Standard Package x16, code 3, swing 7.
  phy.io.ctrl.localPhyParamSettings.bits.maxDataRate := 3.U
  phy.io.ctrl.localPhyParamSettings.bits.voltageSwing := 7.U
  phy.io.ctrl.linkTrainingParameters := 0.U.asTypeOf(new LinkOperationParameters)
  phy.io.analog.status.pllLock := io.pwrGood
  phy.io.analog.status.clocksUngatedAndStable := io.pwrGood

  adapter.io.regs.corrProtoReport := true.B
  adapter.io.regs.nonFatalProtoReport := true.B
  adapter.io.regs.fatalProtoReport := true.B
  val fdi = adapter.io.fdi
  fdi.lpStateReq := Mux(io.protocolActive, FDIStateReq.active, FDIStateReq.nop)
  fdi.lpLinkError := false.B
  fdi.lpRxActiveSts := RegNext(fdi.plRxActiveReq, false.B)
  fdi.lpStallAck := RegNext(fdi.plStallReq, false.B)
  fdi.lpClkAck := RegNext(fdi.plClkReq, false.B)
  fdi.lpWakeReq := true.B
  fdi.lpIrdy := false.B
  fdi.lpValid := false.B
  fdi.lpData := 0.U
  fdi.lpCfg := 0.U
  fdi.lpCfgVld := false.B
  fdi.plCfgCrd := false.B

  io.ltState := phy.io.status.ltState.asUInt
  io.detailState := phy.io.status.currentState.asUInt
  io.rdiState := phy.io.rdi.plStateSts.asUInt
  io.fdiState := fdi.plStateSts.asUInt
  // Berkeley enters PHY ACTIVE after RDI bring-up in LINKINIT. A test must
  // permit LINKINIT here rather than impose UPM's ordering on Berkeley.
  io.phyReady := phy.io.status.ltState === LTState.sLINKINIT || phy.io.status.ltState === LTState.sACTIVE
  io.waitProtocol := fdi.plInbandPres && fdi.plStateSts === FDIState.reset
  io.allActive := phy.io.status.ltState === LTState.sACTIVE &&
    phy.io.rdi.plStateSts === RDIState.active && fdi.plStateSts === FDIState.active
  io.trainError := phy.io.status.trainingTimedout || phy.io.status.fatalTrainingError || phy.io.rdi.plTrainError
  val s = phy.io.status.sideband
  io.sbFault := s.sbParityErrSeen || s.sbRxPriorityQueuesFullSeen ||
    s.sbDeserializerTimedoutSeen || s.sbInvalidRouteUpperSeen ||
    s.sbInvalidRouteCurrSeen || s.sbInvalidRouteLowerSeen || s.sbUnhandledCurrentLayerMsgSeen ||
    adapter.io.regs.sideband.parityErr || adapter.io.regs.sideband.rxQueuesFull ||
    adapter.io.regs.sideband.invalidRoute || adapter.io.regs.sideband.errMsgFatal
}

object EmitBerkeleySerialDie extends App {
  ChiselStage.emitSystemVerilogFile(new BerkeleySerialDie,
    args = Array("-td", args.headOption.getOrElse("generatedVerilog/interop")),
    firtoolOpts = Array("-O=debug", "--disable-all-randomization", "--strip-debug-info",
      "--lowering-options=disallowLocalVariables"))
}
