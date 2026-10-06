package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

class SidebandTx extends Module {
  val io = IO(new Bundle {
    val din     = Input(UInt(64.W)) // 64-bit word to transmit
    val valid   = Input(Bool())     // producer asserts when din is valid
    val ready   = Output(Bool())    // TX ready to accept a new word
    val dout    = Output(Bool())    // serialized bit (LSB-first)
    val clk_out = Output(Bool())    // forwarded clock; toggles only while sending
  })

  // ---- FSM states ----
  object S extends ChiselEnum {
    val IDLE, BUSY, GAP32 = Value
  }
  val state = RegInit(S.IDLE)

  // ---- Datapath regs ----
  val shiftReg  = RegInit(0.U(64.W))
  val bitsLeft  = RegInit(0.U(7.W))         // [0..64]
  val idleCount = RegInit(0.U(6.W))         // 6 bits → 0..63 (we use exactly 32)

  // ---- Defaults ----
  io.ready   := (state === S.IDLE)
  io.dout    := false.B
  io.clk_out := false.B

  val accept = io.valid && io.ready

  switch (state) {
    is (S.IDLE) {
      io.ready   := true.B
      io.dout    := false.B
      io.clk_out := false.B

      when (accept) {
        shiftReg  := io.din
        bitsLeft  := 64.U
        idleCount := 0.U
        state     := S.BUSY
      }
    }

    is (S.BUSY) {
      // Output current LSB and forward the clock while sending
      io.ready   := false.B
      io.dout    := shiftReg(0)     // LSB-first
      io.clk_out := clock.asBool    // only active during BUSY

      when (bitsLeft === 1.U) {
        // This cycle outputs the last bit
        bitsLeft  := 0.U
        idleCount := 32.U            // fixed 32-cycle enforced gap
        state     := S.GAP32
      } .otherwise {
        bitsLeft := bitsLeft - 1.U
        shiftReg := Cat(0.U(1.W), shiftReg(63, 1))
      }
    }

    is (S.GAP32) {
      // Enforced gap: no clock, no data, not ready
      io.ready   := false.B
      io.dout    := false.B
      io.clk_out := false.B

      when (idleCount === 0.U) {
        state := S.IDLE
      } .otherwise {
        idleCount := idleCount - 1.U
      }
    }
  }

  // ---- DEBUG IO ----
  val dbg = IO(new Bundle {
    val state     = Output(UInt(2.W))
    val shiftReg  = Output(UInt(64.W))
    val bitsLeft  = Output(UInt(7.W))
    val idleCount = Output(UInt(6.W))
  })
  dbg.state     := state.asUInt
  dbg.shiftReg  := shiftReg
  dbg.bitsLeft  := bitsLeft
  dbg.idleCount := idleCount
}