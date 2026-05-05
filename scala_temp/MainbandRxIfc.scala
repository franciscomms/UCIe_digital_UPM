package ucie

import chisel3._
import chisel3.util._

/**
  * MainbandRxIfc (generic wide -> narrow "unpacker")
  *
  * - Input  (mb):  wide word stream (in_width)
  * - Output (out): narrow beat stream (out_width)
  *
  * Constraints:
  *   out_width <= in_width
  *   in_width % out_width == 0
  *
  * Behavior:
  * - When ratio == 1 (same width), it's a pure Decoupled passthrough.
  * - When ratio > 1, it stores one wide word and then outputs it in slices of out_width,
  *   LSB-first (out gets bits [out_width-1:0], then shifts right).
  */
class MainbandRxIfc(val in_width: Int, val out_width: Int) extends Module {
  require(in_width > 0)
  require(out_width > 0)
  require(out_width <= in_width)
  require(in_width % out_width == 0)

  private val ratio = in_width / out_width

  val io = IO(new Bundle {
    val mb  = Flipped(Decoupled(UInt(in_width.W))) // From FIFO/mainband (wide)
    val out = Decoupled(UInt(out_width.W))         // To internal logic (narrow)
  })

  // Fast path: same width -> no buffering needed
  if (ratio == 1) {
    io.out.bits  := io.mb.bits
    io.out.valid := io.mb.valid
    io.mb.ready  := io.out.ready

  } else {
    // Buffer holds one wide word, then we stream it out in ratio beats
    val idxW = (log2Ceil(ratio + 1))

    val buf      = RegInit(0.U(in_width.W))
    val remBeats = RegInit(0.U(idxW.W)) // how many beats left to send from buf

    val haveWord = remBeats =/= 0.U

    // Output current slice (LSB-first)
    io.out.bits  := buf(out_width - 1, 0)
    io.out.valid := haveWord

    val sendingLast = io.out.fire && (remBeats === 1.U)
    io.mb.ready := !haveWord || sendingLast

    // If we output a beat, shift buffer and decrement remaining beats
    val bufAfterOut = Mux(io.out.fire, (buf >> out_width).asUInt, buf)
    val remAfterOut = Mux(io.out.fire, remBeats - 1.U, remBeats)

    buf      := Mux(io.mb.fire, io.mb.bits, bufAfterOut)
    remBeats := Mux(io.mb.fire, ratio.U, remAfterOut)
  }
}