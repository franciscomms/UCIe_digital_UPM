/*
paralel IN to series OUT Shift Register with load

sends LSB first
*/

/*
TODO:
organize MSB/LSB sequence
*/

package edu.berkeley.cs.ucie.digital

import chisel3._


/**
 * 
 */
class ShiftRegParSer (size: Int) extends Module {
  val io = IO(new Bundle {
    val din = Input(UInt(size.W))
    val load = Input(Bool())
    val dout = Output(Bool())
  })
  val shiftReg = RegInit(0.U(size.W))
  when (io.load) {
    shiftReg := io.din
  } .otherwise {
    shiftReg := 0.U(1.W) ## shiftReg(size-1, 1) 
  }
  io.dout := shiftReg(0)
}