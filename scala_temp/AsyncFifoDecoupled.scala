package ucie

import chisel3._
import chisel3.util._
import chisel3.util.HasBlackBoxResource

/** BlackBox del SV AsyncFifoCustomCore (reset activo-bajo en SV). */
class AsyncFifoCustomCoreBB(depth: Int, width: Int)
    extends BlackBox(Map("DEPTH" -> depth, "WIDTH" -> width))
    with HasBlackBoxResource {

    override def desiredName: String = "AsyncFifoCustomCore"

  val io = IO(new Bundle {
    val rst = Input(Bool()) // activo-bajo (SV usa negedge rst)

    val clk_w   = Input(Clock())
    val valid_w = Input(Bool())
    val ready_w = Output(Bool())
    val data_w  = Input(UInt(width.W))

    val clk_r   = Input(Clock())
    val valid_r = Output(Bool())
    val ready_r = Input(Bool())
    val data_r  = Output(UInt(width.W))
  })

  addResource("/vsrc/AsyncFifoCustomCore.sv")
}

class AsyncFifoDecoupled(depth: Int, width: Int) extends Module {
  require(depth > 1)
  require((depth & (depth - 1)) == 0)

  val io = IO(new Bundle {
    // dominio enqueue
    val enq_clock = Input(Clock())
    val enq_reset = Input(Bool()) // activo-alto en Chisel
    val enq       = Flipped(Decoupled(UInt(width.W)))

    // dominio dequeue
    val deq_clock = Input(Clock())
    val deq_reset = Input(Bool()) // activo-alto en Chisel  
    val deq       = Decoupled(UInt(width.W))
  })

  val bb = Module(new AsyncFifoCustomCoreBB(depth = depth, width = width))

  val rstActiveHigh = io.enq_reset || io.deq_reset
  bb.io.rst := ~rstActiveHigh // BB espera activo-bajo

  // Write (enq) side: Decoupled -> SV
  bb.io.clk_w   := io.enq_clock
  bb.io.valid_w := io.enq.valid
  bb.io.data_w  := io.enq.bits
  io.enq.ready  := bb.io.ready_w

  // Read (deq) side: SV -> Decoupled
  bb.io.clk_r   := io.deq_clock
  bb.io.ready_r := io.deq.ready
  io.deq.valid  := bb.io.valid_r
  io.deq.bits   := bb.io.data_r
}