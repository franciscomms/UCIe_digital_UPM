package ucie

import chisel3._
import chisel3.util._

class Packer(val inWidth: Int = 128, val outWidth: Int = 512) extends Module {
  require(inWidth > 0)
  require(outWidth > 0)
  require(outWidth % inWidth == 0)

  private val ratio = outWidth / inWidth

  val io = IO(new Bundle {
    val in  = Flipped(Decoupled(UInt(inWidth.W)))
    val out = Decoupled(UInt(outWidth.W))
  })

  if (ratio == 1) {
    // Same width: no packing needed
    io.out.bits  := io.in.bits
    io.out.valid := io.in.valid
    io.in.ready  := io.out.ready
  } else {
    val idxBits = (log2Ceil(ratio) max 1)

    val bufVec  = RegInit(VecInit(Seq.fill(ratio)(0.U(inWidth.W))))
    val beatIdx = RegInit(0.U(idxBits.W))
    val full    = RegInit(false.B)

    io.out.bits  := bufVec.asUInt
    io.out.valid := full

    io.in.ready := !full || io.out.fire

    when(io.out.fire) {
      full    := false.B
      beatIdx := 0.U
      // optional clear
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