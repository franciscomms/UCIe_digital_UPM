/*
series IN to parallel OUT - Shift Register 

Receive LSB first
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
class ShiftRegSerPar (size: Int) extends Module {
  val io = IO(new Bundle {
    val din = Input(Bool())
    val dout = Output(UInt(size.W))
  })
  val shiftReg = RegInit(0.U(size.W))
  
  shiftReg := shiftReg(size-2, 0) ## io.din
  io.dout := shiftReg
}