package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class ShiftRegParSerSpec extends AnyFlatSpec with ChiselScalatestTester {
  behavior of "ShiftRegister(size=4)" 
    it should "reset to 0" in {
      test(new ShiftRegParSer(4)) { c =>
        c.reset.poke(true.B)
        c.clock.step(1)
        c.reset.poke(false.B)
        c.clock.step(1)
        c.io.dout.expect(0.U(1.W))
      }
    }
    it should "reset to 0 and shift right inserting din" in {
      test(new ShiftRegParSer(4)) { c =>
        c.reset.poke(true.B)
        c.clock.step(1)
        c.reset.poke(false.B)
        c.clock.step(1)

      // Sequence of inputs and expected outputs after each clock
      // Start: 0000
      // din=1011
      // dout=1 -> 0001
      // dout=1 -> 0011
      // dout=0 -> 0110
      // dout=1 -> 1101

      val input   = 11.U(4.W)
      val expected = Seq(1, 1, 0, 1)

      // load input and check outputs step-by-step
      c.io.din.poke(input)
      c.io.load.poke(true.B)
      c.clock.step(1)
      c.io.load.poke(false.B)
      for (i <- expected.indices) {
        val exp   = expected(i)
        c.io.dout.expect(exp.U)        
        println(s"-- Expected dout=${exp}, got ${c.io.dout.peek().litValue}")
        c.clock.step(1)
      }
      }
    }
}
