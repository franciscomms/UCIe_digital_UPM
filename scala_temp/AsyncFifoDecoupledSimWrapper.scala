package ucie

import chisel3._
import chisel3.util._

class AsyncFifoDecoupledSimWrapper(
  width: Int,
  depth: Int,
  wPeriodCycles: Int = 10,
  rPeriodCycles: Int = 4  
) extends Module {

  require(wPeriodCycles >= 2 && (wPeriodCycles % 2 == 0))
  require(rPeriodCycles >= 2 && (rPeriodCycles % 2 == 0))

  val io = IO(new Bundle {
    // Interfaz decoupled 
    val enq = Flipped(Decoupled(UInt(width.W)))
    val deq = Decoupled(UInt(width.W))

    val enq_reset = Input(Bool())
    val deq_reset = Input(Bool())
  })

  // 1) Generación de clocks internos (bool -> asClock)
  val wClkBool = RegInit(false.B)
  val rClkBool = RegInit(false.B)

  val wHalf = (wPeriodCycles / 2).U
  val rHalf = (rPeriodCycles / 2).U

  val wCnt = RegInit(0.U(32.W))
  val rCnt = RegInit(0.U(32.W))

  // Toggle wclk cada wHalf ciclos del clock top
  wCnt := Mux(wCnt === (wHalf - 1.U), 0.U, wCnt + 1.U)
  when (wCnt === (wHalf - 1.U)) { wClkBool := ~wClkBool }

  // Toggle rclk cada rHalf ciclos del clock top
  rCnt := Mux(rCnt === (rHalf - 1.U), 0.U, rCnt + 1.U)
    when (rCnt === (rHalf - 1.U)) { rClkBool := ~rClkBool }

  val wclk: Clock = wClkBool.asClock
  val rclk: Clock = rClkBool.asClock

  // 2) Instancia de DUT multi-clock
  val dut = Module(new AsyncFifoDecoupled(width = width, depth = depth))

  // Conectamos clocks internos
  dut.io.enq_clock := wclk
  dut.io.deq_clock := rclk

  // Conectamos resets por dominio si existen en tu diseño
  dut.io.enq_reset := io.enq_reset
  dut.io.deq_reset := io.deq_reset

  // Conectamos decoupled
  dut.io.enq <> io.enq
  io.deq <> dut.io.deq
}