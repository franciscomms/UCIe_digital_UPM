package RdiLinkManagement

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RdiSidebandTimeoutCounterSpec extends AnyFlatSpec with ChiselScalatestTester {
  behavior of "RdiSidebandTimeoutCounter"

  it should "start counting on REQ send and assert timeout after the configured cycles" in {
    val params = SidebandTimeoutCounterParams(timeoutCycles = 8)
    test(new RdiSidebandTimeoutCounter(params)) { dut =>
      dut.io.sb_snd.poke(RdiSideBandMessage.REQ_ACTIVE)
      dut.io.sb_snd_vld.poke(true.B)
      dut.io.sb_snd_rdy.poke(true.B)
      dut.io.sb_rcv.poke(RdiSideBandMessage.NOP)
      dut.io.sb_rcv_vld.poke(false.B)

      dut.clock.step(1)
      dut.io.pending.expect(true.B)
      dut.io.timeout.expect(false.B)

      // advance to just before timeout expiry
      for (_ <- 0 until 7) {
        dut.io.sb_snd_vld.poke(false.B)
        dut.clock.step(1)
      }
      dut.io.pending.expect(true.B)
      dut.io.timeout.expect(false.B)

      dut.clock.step(1)
      dut.io.pending.expect(true.B)
      dut.io.timeout.expect(true.B)
    }
  }

  it should "clear timeout when the matching response arrives" in {
    val params = SidebandTimeoutCounterParams(timeoutCycles = 4)
    test(new RdiSidebandTimeoutCounter(params)) { dut =>
      dut.io.sb_snd.poke(RdiSideBandMessage.REQ_L2)
      dut.io.sb_snd_vld.poke(true.B)
      dut.io.sb_snd_rdy.poke(true.B)
      dut.io.sb_rcv.poke(RdiSideBandMessage.NOP)
      dut.io.sb_rcv_vld.poke(false.B)
      dut.clock.step(1)

      dut.io.sb_snd_vld.poke(false.B)
      dut.io.sb_rcv.poke(RdiSideBandMessage.RSP_L2)
      dut.io.sb_rcv_vld.poke(true.B)
      dut.clock.step(1)

      dut.io.pending.expect(false.B)
      dut.io.timeout.expect(false.B)
    }
  }
}
