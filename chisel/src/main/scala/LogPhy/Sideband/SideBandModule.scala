package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

class SidebandModule extends Module {
  val io = IO(new Bundle {
    // TX signals from/to system
    val tx_din   = Input(UInt(64.W))
    val tx_valid = Input(Bool())
    val tx_ready = Output(Bool())
    // TX signals to outside
    val tx_dout  = Output(Bool())
    val tx_clk   = Output(Bool())

    // RX signals from/to system
    val rx_dout  = Output(UInt(64.W))
    val rx_valid = Output(Bool())
    val rxReset  = Input(Bool())
    // RX signals from outside
    val rx_din   = Input(Bool())
    val rx_clk   = Input(Bool())
  })

  // --------------------------
  // TX
  // --------------------------
  // Small FIFO buffers outbound words so producers can queue transmissions
  val txFifo = Module(new Queue(UInt(64.W), entries = 4))
  txFifo.io.enq.bits  := io.tx_din
  txFifo.io.enq.valid := io.tx_valid
  io.tx_ready         := txFifo.io.enq.ready //full signal

  val tx = Module(new SidebandTx)
  tx.io.din          := txFifo.io.deq.bits
  tx.io.valid        := txFifo.io.deq.valid
  txFifo.io.deq.ready := tx.io.ready

  io.tx_dout  := tx.io.dout
  io.tx_clk   := tx.io.clk_out

  // --------------------------
  // RX
  // --------------------------
  //rx need to capture data on the fallig edge of the incomming clk
  val rx_module_clk = (!io.rx_clk).asClock
  val rx = withClock(rx_module_clk) {
    Module(new SidebandRx)
  }
  rx.io.din := io.rx_din

  io.rx_dout  := rx.io.dout
  io.rx_valid := rx.io.valid
}