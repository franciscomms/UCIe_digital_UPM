package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class LinkTrainingFSMSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "LinkTrainingFSM"

  it should "reset then advance through all stages with minimal stimuli" in {
    test(new LinkTrainingFSM).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      // ------------------------------------------------------------
      // Reset at the beginning (synchronous reset sequence)
      // ------------------------------------------------------------
      c.reset.poke(true.B)
      // During reset, drive safe defaults on inputs
      c.io.start.poke(false.B)
      c.io.stable_clk.poke(false.B)
      c.io.pll_locked.poke(false.B)
      c.io.stable_supply.poke(false.B)
      c.io.sb_tx_ready.poke(false.B)
      c.io.sb_rx_valid.poke(false.B)
      c.io.sb_rx_dout.poke(0.U)
      c.clock.step(3)    // hold reset for a few cycles
      c.reset.poke(false.B)
      c.clock.step(1)    // let it settle one cycle

      // ------------------------------------------------------------
      // Bring stability inputs high so we can leave RESET
      // ------------------------------------------------------------
      c.io.start.poke(true.B)
      c.io.stable_clk.poke(true.B)
      c.io.pll_locked.poke(true.B)
      c.io.stable_supply.poke(true.B)

      // Sideband TX ready (so FSM can present pattern words)
      c.io.sb_tx_ready.poke(true.B)

      // ------------------------------------------------------------
      // Wait more than RESET_CYCLES to exit RESET
      // NOTE: Your RTL has RESET_CYCLES = 10.U for sim now.
      //       If you restore 3,200,000, increase the steps here.
      // ------------------------------------------------------------
      c.io.state.expect(0.U) // LTState.RESET
      c.clock.step(12)
      c.io.state.expect(1.U) // LTState.SBINIT_pattern

      // still waiting for patterns and sending pattern in TX
      c.clock.step(12)
      c.io.state.expect(1.U) 

      // ------------------------------------------------------------
      // Provide two consecutive good pattern words (0xAAAAAAAAAAAAAAAA)
      // to hit the "128 UI" condition in your simplified detector.
      // ------------------------------------------------------------
      val pattern = BigInt("AAAAAAAAAAAAAAAA", 16)

      // First detection: sets flag, stays in SBINIT_pattern
      c.io.sb_rx_dout.poke(pattern.U)
      c.io.sb_rx_valid.poke(true.B)
      c.clock.step(1)
      c.io.sb_rx_dout.poke(0.U)
      c.io.sb_rx_valid.poke(false.B)
      c.clock.step(32) //next pattern comes after 32 UIs
      c.io.state.expect(1.U)

      // Second consecutive detection: should move to SBINIT_sendFour
      c.io.sb_rx_dout.poke(pattern.U)
      c.io.sb_rx_valid.poke(true.B)
      c.clock.step(1)
      c.io.sb_rx_dout.poke(0.U)
      c.io.sb_rx_valid.poke(false.B)
      c.clock.step(1)
      c.io.state.expect(2.U) // LTState.SBINIT_sendFour

      // Allow SBINIT_sendFour to transmit 4 words (each word uses two cycles: assert then deassert)
      c.clock.step(7)
      c.io.state.expect(3.U) // LTState.SBINIT_OORmsg

      // ------------------------------------------------------------
      // SBINIT_OORmsg: the FSM should send SBINIT_out_of_Reset_success
      // and only advance after receiving the same message back.
      // ------------------------------------------------------------
      // Expected SBINIT_out_of_Reset_success 64-bit word (MSB-first hex)
      val successMsg = BigInt("0200010040244012", 16)
      val doneReqMsg  = BigInt("4200000140254012", 16)
      val doneRespMsg = BigInt("4200000140268012", 16)

      // Provide the success message on the RX path (pulse valid for one cycle)
      c.clock.step(10)
      c.io.sb_rx_dout.poke(successMsg)
      c.io.sb_rx_valid.poke(true.B)
      c.clock.step(1)

      // Deassert RX
      c.io.sb_rx_dout.poke(0.U)
      c.io.sb_rx_valid.poke(false.B)
      c.clock.step(1)
      
      // After reception, FSM should advance to SBINIT_DONEmsg
      c.io.state.expect(4.U) // LTState.SBINIT_DONEmsg

      // ------------------------------------------------------------
      // SBINIT_DONEmsg handshake: partner sends done_req, DUT responds, partner sends done_resp
      // ------------------------------------------------------------
      // Partner sends SBINIT_done_req
      c.io.sb_rx_dout.poke(doneReqMsg)
      c.io.sb_rx_valid.poke(true.B)
      c.clock.step(1)
      c.io.sb_rx_dout.poke(0.U)
      c.io.sb_rx_valid.poke(false.B)

      // Allow DUT to issue its done_resp
      c.clock.step(1)
      if (c.io.sb_tx_valid.peek().litToBoolean) {
        c.io.sb_tx_din.expect(doneRespMsg.U)
      }

      // Partner returns SBINIT_done_resp
      c.io.sb_rx_dout.poke(doneRespMsg)
      c.io.sb_rx_valid.poke(true.B)
      c.clock.step(1)
      c.io.sb_rx_dout.poke(0.U)
      c.io.sb_rx_valid.poke(false.B)

      // Give FSM one more cycle to complete handshake and advance
      c.clock.step(1)

      c.io.state.expect(5.U) // LTState.MBINIT

      // MBINIT -> MBTRAIN
      c.clock.step(1)
      c.io.state.expect(6.U) // LTState.MBTRAIN

      // MBTRAIN -> LINKINIT
      c.clock.step(1)
      c.io.state.expect(7.U) // LTState.LINKINIT

      // LINKINIT -> ACTIVE
      c.clock.step(1)
      c.io.state.expect(8.U) // LTState.ACTIVE

      // Remains ACTIVE
      c.clock.step(2)
      c.io.state.expect(8.U)
  
    }
  }
}