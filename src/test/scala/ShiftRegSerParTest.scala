package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class ShiftRegSerParSpec extends AnyFlatSpec with ChiselScalatestTester {
  behavior of "ShiftRegister(size=4)" 
    it should "reset to 0" in {
      test(new ShiftRegSerPar(4)) { c =>
        c.reset.poke(true.B)
        c.clock.step(1)
        c.reset.poke(false.B)
        c.clock.step(1)
        c.io.dout.expect(0.U)
      }
    }
    it should "reset to 0 and shift left inserting din at LSB" in {
      test(new ShiftRegSerPar(4)) { c =>
        c.reset.poke(true.B)
        c.clock.step(1)
        c.reset.poke(false.B)
        c.clock.step(1)
        c.io.dout.expect(0.U)

      // Sequence of inputs and expected outputs after each clock
      // Start: 0000
      // din=1 -> 0001
      // din=0 -> 0000
      // din=1 -> 0001
      // din=1 -> 0011
      val inputs   = Seq(true, false, true, true)
      val expected = Seq(1, 2, 5, 11)

      // Drive inputs and check outputs step-by-step
      for (i <- inputs.indices) {
        val inBit = inputs(i)
        val exp   = expected(i)

        c.io.din.poke(inBit.B)
        c.clock.step(1)
        c.io.dout.expect(exp.U)
        println(s"After din=${inBit}, expected dout=${exp}, got ${c.io.dout.peek().litValue}")
      }
      }
    }
}
