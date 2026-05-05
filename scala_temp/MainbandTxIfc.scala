package ucie

import chisel3._
import chisel3.util._

class MainbandTxIfc(val in_width: Int, val out_width: Int) extends Module {
  require(in_width > 0)
  require(out_width > 0)
  require(in_width <= out_width)
  require(out_width % in_width == 0)

  private val ratio = out_width / in_width

  val io = IO(new Bundle {
    val in = Flipped(Decoupled(UInt(in_width.W)))
    val mb = Decoupled(UInt(out_width.W))
  })

  if (ratio == 1) {
    io.mb.bits  := io.in.bits
    io.mb.valid := io.in.valid
    io.in.ready := io.mb.ready

  } else {
    val idxBits = (log2Ceil(ratio) max 1)

    val bufVec  = RegInit(VecInit(Seq.fill(ratio)(0.U(in_width.W))))
    val beatIdx = RegInit(0.U(idxBits.W))
    val full    = RegInit(false.B)

    io.mb.bits  := bufVec.asUInt
    io.mb.valid := full

    io.in.ready := !full || io.mb.fire

    when(io.mb.fire) {
      full    := false.B
      beatIdx := 0.U
      for (i <- 0 until ratio) { bufVec(i) := 0.U }
    }

    when(io.in.fire) {
      val effectiveIdx = Mux(full, 0.U, beatIdx)

      when(full) {
        for (i <- 0 until ratio) { bufVec(i) := 0.U }
      }

      bufVec(effectiveIdx) := io.in.bits

      when(effectiveIdx === (ratio - 1).U) {
        full    := true.B
        beatIdx := 0.U
      }.otherwise {
        beatIdx := effectiveIdx + 1.U
      }
    }
  }
}