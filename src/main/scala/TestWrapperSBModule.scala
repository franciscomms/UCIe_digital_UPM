package edu.berkeley.cs.ucie.digital

import chisel3._
import chisel3.util._

/**
  * TestWrapperSBModule
  *
  * - Instantiates a SidebandModule (DUT)
  * - Instantiates a "partner" SidebandTx inside the wrapper
  * - Exposes partner TX pins at the wrapper IO
  * - Connects partner.clk_out -> sb.io.rx_clk so RX is clocked by partner TX
  *
  * By default, rx_din remains an external input so tests can drive arbitrary data.
  * If you want the partner TX to drive RX data as well, see the commented line below.
  */
class TestWrapperSBModule extends Module {
  val io = IO(new Bundle {
    // --------------------------
    // DUT (sb) TX signals (to/from system)
    // --------------------------
    val tx_din   = Input(UInt(64.W))
    val tx_valid = Input(Bool())
    val tx_ready = Output(Bool())
    // TX signals to outside
    val tx_dout  = Output(Bool())
    val tx_clk   = Output(Bool())

    // --------------------------
    // DUT (sb) RX signals (to/from system)
    // --------------------------
    val rx_dout  = Output(UInt(64.W))
    val rx_valid = Output(Bool())
    val rxReset  = Input(Bool())
    // RX data from outside (kept external intentionally)
    //val rx_din   = Input(Bool())

    // --------------------------
    // Partner TX pins exposed as IO
    // --------------------------
    val partner_tx_din   = Input(UInt(64.W)) // word to send from partner
    val partner_tx_valid = Input(Bool())     // valid from testbench/driver
    val partner_tx_ready = Output(Bool())    // ready from partner
    val partner_tx_dout  = Output(Bool())    // serialized bit from partner
    val partner_tx_clk   = Output(Bool())    // forwarded clock from partner
  })

  // --------------------------
  // Instantiate DUT (SidebandModule)
  // --------------------------
  val sb = Module(new SidebandModule)

  // DUT TX path passthrough
  sb.io.tx_din   := io.tx_din
  sb.io.tx_valid := io.tx_valid
  // tx_ready now reflects the DUT's internal TX FIFO space
  io.tx_ready    := sb.io.tx_ready
  io.tx_dout     := sb.io.tx_dout
  io.tx_clk      := sb.io.tx_clk

  // DUT RX control/status
  io.rx_dout     := sb.io.rx_dout
  io.rx_valid    := sb.io.rx_valid
  sb.io.rxReset  := io.rxReset

  // --------------------------
  // Instantiate Partner TX
  // --------------------------
  val partnerTx = Module(new SidebandTx)
  partnerTx.io.din   := io.partner_tx_din
  partnerTx.io.valid := io.partner_tx_valid
  io.partner_tx_ready := partnerTx.io.ready
  io.partner_tx_dout  := partnerTx.io.dout
  io.partner_tx_clk   := partnerTx.io.clk_out

  // --------------------------
  // Connect Partner TX clock to DUT RX clock (as requested)
  // --------------------------
  sb.io.rx_clk := partnerTx.io.clk_out

  // Keep RX data as an external input (per your reference)
  //sb.io.rx_din := io.rx_din

  //the partner to drive RX data as well:
  sb.io.rx_din := partnerTx.io.dout
}