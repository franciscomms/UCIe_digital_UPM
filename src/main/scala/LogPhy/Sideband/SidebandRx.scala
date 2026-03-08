package edu.berkeley.cs.ucie.digital
import chisel3._
import chisel3.util._

class SidebandRx extends Module {
  val io = IO(new Bundle {
    val din   = Input(Bool())      // incoming bit, LSB-first
    val dout  = Output(UInt(64.W)) // full word
    val valid = Output(Bool())     // assert exactly when the 64th bit arrives
  })

  // Shift register
  val shiftReg = RegInit(0.U(64.W))

  // Counter 0..64 exactly as your protocol requires
  val bitCount = RegInit(0.U(7.W))

  // Track previous value of bitCount to detect transitions
  val prevBitCount = RegNext(bitCount)

  // ==========================================================================
  // SHIFT (always one bit per cycle)
  // LSB-first → incoming at least-significant position
  // ==========================================================================
  shiftReg := Cat(shiftReg(62, 0), io.din.asUInt)

  // ==========================================================================
  // COUNTER 0..64 → wrap at 64 → 0
  // ==========================================================================
  val reached64 = (bitCount === 63.U)

  val nextCount = Mux(reached64, 0.U, bitCount + 1.U)
  bitCount := nextCount

  // ==========================================================================
  // VALID: assert when the *new* bit would make bitCount reach 64
  //
  // That is: prevBitCount + 1 == 64
  // ==========================================================================
  io.valid := (prevBitCount + 1.U === 64.U)

  // ==========================================================================
  // Output reversed so that LSB-first stream → correct word order
  // ==========================================================================
  io.dout := Reverse(shiftReg)

  // Debug outputs
  val dbg = IO(new Bundle {
    val shiftReg     = Output(UInt(64.W))
    val bitCount     = Output(UInt(7.W))
    val prevBitCount = Output(UInt(7.W))
  })

  dbg.shiftReg     := shiftReg
  dbg.bitCount     := bitCount
  dbg.prevBitCount := prevBitCount
}