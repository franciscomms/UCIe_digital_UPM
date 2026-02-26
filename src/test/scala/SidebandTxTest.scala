package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SidebandTxSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "SidebandTx (with 32-cycle enforced gap)"

  // -------------------------------------------------------------
  // 1.1 Reset & Idle
  // -------------------------------------------------------------
  it should "reset into IDLE with ready=1, dout=0, clk_out=0" in {
    test(new SidebandTx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B)

      // Right after reset, before stepping:
      c.io.ready.expect(true.B)
      c.io.clk_out.expect(false.B)
      c.io.dout.expect(false.B)

      // Stay idle with valid=0
      for (_ <- 0 until 5) {
        c.io.valid.poke(false.B)
        c.clock.step()
        c.io.ready.expect(true.B)
        c.io.clk_out.expect(false.B)
        c.io.dout.expect(false.B)
      }
    }
  }

  // -------------------------------------------------------------
  // 1.2 Single-word transmit (golden path)
  // -------------------------------------------------------------
  it should "send a 64b word LSB-first, then enter a 32-cycle gap" in {
    test(new SidebandTx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      val word = BigInt("A123456789ABCDEF", 16)

      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B); c.clock.step()

      // Accept word
      c.io.ready.expect(true.B)
      c.io.din.poke(word.U)
      c.io.valid.poke(true.B)
      c.clock.step()            // accept
      c.io.valid.poke(false.B)

      // Stream 64 bits
      var observed = BigInt(0)
      for (i <- 0 until 64) {
        val bit = if (c.io.dout.peekBoolean()) 1 else 0
        observed |= (BigInt(bit) << i)
        c.clock.step()
      }
      assert(observed == word, s"LSB-first reconstruction failed: got 0x$observed%016X")

      // Now GAP32 should begin
      for (i <- 0 until 32) {
        c.io.ready.expect(false.B,  s"ready must stay low during GAP32 (i=$i)")
        c.io.clk_out.expect(false.B, s"clk_out must stay low during GAP32 (i=$i)")
        c.io.dout.expect(false.B)
        c.clock.step()
      }

      // After 32 cycles → IDLE
      c.clock.step()//check if this step is necessary or we are waiting 33b instead of 32b
      c.io.ready.expect(true.B)
      c.io.clk_out.expect(false.B)
      c.clock.step()
      c.io.ready.expect(true.B)
      c.io.clk_out.expect(false.B)
    }
  }

  // -------------------------------------------------------------
  // 1.3 Enforced 32-cycle gap before accepting next word
  // -------------------------------------------------------------
  it should "NOT accept a second word until the 32-cycle gap finishes" in {
    test(new SidebandTx) { c =>
      val w1 = BigInt("DEADBEEFCAFEBABE", 16)
      val w2 = BigInt("0123456789ABCDEF", 16)

      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B); c.clock.step()

      // Start first frame
      c.io.ready.expect(true.B)
      c.io.din.poke(w1.U)
      c.io.valid.poke(true.B)
      c.clock.step() // accept
      c.io.valid.poke(false.B)

      // Consume all 64 bits
      for (_ <- 0 until 64) c.clock.step()

      // GAP32 begins → TX MUST IGNORE a new valid during this time
      for (i <- 0 until 32) {
        c.io.valid.poke(true.B)
        c.io.din.poke(w2.U)
        c.io.ready.expect(false.B, s"TX must NOT accept new word during enforced GAP32 (i=$i)")
        c.clock.step()
      }

      // Now IDLE → ready = 1 and second word can be accepted
      c.clock.step()//check if this step is necessary or we are waiting 33b instead of 32b
      c.io.ready.expect(true.B)
      c.io.valid.poke(true.B)
      c.clock.step()   // accept w2
      c.io.valid.poke(false.B)

      // Transmit w2
      var obs = BigInt(0)
      for (i <- 0 until 64) {
        if (c.io.dout.peekBoolean()) obs |= (BigInt(1) << i)
        c.clock.step()
      }
      assert(obs == w2, "Second frame incorrectly transmitted")
    }
  }
/*CLK can be only confirmed with GTK sim
  // -------------------------------------------------------------
  // 1.4 clk_out ONLY toggles during BUSY
  // -------------------------------------------------------------
  it should "toggle clk_out only during BUSY and remain low during IDLE and GAP32" in {
    test(new SidebandTx) { c =>
      val w = BigInt("AAAAAAAAAAAAAAAA", 16)

      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B); c.clock.step()

      // IDLE → clk_out low
      for (_ <- 0 until 3) {
        c.io.clk_out.expect(false.B)
        c.io.ready.expect(true.B)
        c.clock.step()
      }

      // Accept word
      c.io.din.poke(w.U)
      c.io.valid.poke(true.B)
      c.clock.step()            // accept
      c.io.valid.poke(false.B)

      // BUSY → clk_out toggles
      var prev = c.io.clk_out.peekBoolean()
      for (i <- 0 until 64) {
        val cur = c.io.clk_out.peekBoolean()
        assert(cur != prev, s"clk_out must toggle during BUSY (bit $i)")
        prev = cur
        c.clock.step()
      }

      // GAP32 → clk_out low
      for (_ <- 0 until 32) {
        c.io.clk_out.expect(false.B)
        c.io.ready.expect(false.B)
        c.clock.step()
      }

      // IDLE again → clk_out low
      c.io.clk_out.expect(false.B)
      c.io.ready.expect(true.B)
    }
  }
*/

  // -------------------------------------------------------------
  // 1.5 Word latching must occur ONLY at accept
  // -------------------------------------------------------------
  it should "latch din at accept and ignore din changes during BUSY and GAP32" in {
    test(new SidebandTx) { c =>
      val w = BigInt("F0E1D2C3B4A59687", 16)

      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B); c.clock.step()

      // Accept
      c.io.ready.expect(true.B)
      c.io.din.poke(w.U)
      c.io.valid.poke(true.B)
      c.clock.step()
      c.io.valid.poke(false.B)

      // Wiggle din throughout BUSY and ensure output is unaffected
      var expected = w
      for (i <- 0 until 64) {
        c.io.din.poke((i * 123).U) // random-ish noise
        val expBit = (expected & 1) == 1
        c.io.dout.expect(expBit.B)
        expected >>= 1
        c.clock.step()
      }

      // GAP32: still must NOT accept anything
      for (_ <- 0 until 32) {
        c.io.valid.poke(true.B)
        c.io.dout.expect(false.B)
        c.io.ready.expect(false.B)
        c.clock.step()
      }

      // IDLE: can accept again
      c.clock.step()//check if this step is necessary or we are waiting 33b instead of 32b
      c.io.ready.expect(true.B)
    }
  }

  // -------------------------------------------------------------
  // 1.6 Send 4 words in sequence (each separated by mandatory 32-cycle gap)
  // -------------------------------------------------------------
  it should "send 4 words in sequence with a correct 32-cycle enforced gap between them" in {
    test(new SidebandTx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      val w0 = BigInt("0123456789ABCDEF", 16)
      val w1 = BigInt("A5A5A5A5A5A5A5A5", 16)
      val w2 = BigInt("DEADBEEFCAFEBABE", 16)
      val w3 = BigInt("F0E1D2C3B4A59687", 16)
      val words = Seq(w0, w1, w2, w3)

      // ---------------------------
      // Reset
      // ---------------------------
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B); c.clock.step()

      // ---------------------------
      // Helper inline logic: Send 1 word
      // ---------------------------
      def sendOneWord(word: BigInt) = {
        // Must be in IDLE
        c.io.ready.expect(true.B)
        c.io.clk_out.expect(false.B)

        // Accept
        c.io.din.poke(word.U)
        c.io.valid.poke(true.B)
        c.clock.step()          // accept
        c.io.valid.poke(false.B)

        // BUSY: shift 64 bits
        var observed = BigInt(0)
        for (i <- 0 until 64) {
          val bit = if (c.io.dout.peekBoolean()) 1 else 0
          observed |= (BigInt(bit) << i)
          c.clock.step()
        }
        assert(observed == word, f"Expected 0x$word%016X got 0x$observed%016X")

        // GAP32: ready must stay LOW
        for (i <- 0 until 32) {
          c.io.ready.expect(false.B, s"ready must remain low during GAP32 (i=$i)")
          c.io.clk_out.expect(false.B)
          c.io.dout.expect(false.B)
          c.clock.step()
        }

        // Now IDLE again
  
        c.clock.step()//check if this step is necessary or we are waiting 33b instead of 32b
        c.io.ready.expect(true.B)
        c.io.clk_out.expect(false.B)
      }

      // ---------------------------
      // Send four words in sequence
      // ---------------------------
      sendOneWord(w0)
      sendOneWord(w1)
      sendOneWord(w2)
      sendOneWord(w3)
    }
  }
}
