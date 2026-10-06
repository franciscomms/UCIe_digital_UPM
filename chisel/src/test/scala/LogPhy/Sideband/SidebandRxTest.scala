package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SidebandRxSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "SidebandRx"

  // 1) Reset behavior
  it should "reset with bitCount=0, valid=0, dout=0 and then start counting bits" in {
    test(new SidebandRx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      // Apply reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B)

      // Immediately after reset
      c.io.valid.expect(false.B)
      c.dbg.bitCount.expect(0.U)
      c.io.dout.expect(0.U)

      // Drive a few bits, valid must stay low, counter must advance
      for (i <- 0 until 10) {
        val bit = (i & 1) == 1 // 0,1,0,1,...
        c.io.din.poke(bit.B)
        c.clock.step()
        c.io.valid.expect(false.B)
      }
      c.dbg.bitCount.expect(10.U)

      // Apply reset again
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B)

      // Immediately after reset confirm bitcount is zero
      c.io.valid.expect(false.B)
      c.dbg.bitCount.expect(0.U)
      c.io.dout.expect(0.U)
    }
  }

  // 2) Back-to-back words: 4 fixed words (no gaps), LSB-first
  it should "receive 4 back-to-back 64b words (LSB-first), pulsing valid on each 64th bit with correct dout" in {
    test(new SidebandRx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B)

      // Define fixed words (no randomness)
      val w0 = BigInt("9123456789ABCDE9", 16)
      val w1 = BigInt("FEDCBA9876543210", 16)
      val w2 = BigInt("A5A5A5A5A5A5A5A5", 16)
      val w3 = BigInt("5A5A5A5A5A5A5A5A", 16)
      val words = Seq(w0, w1, w2, w3)

      for ((w, idx) <- words.zipWithIndex) {
        // Present bits 0..62 first; valid must remain low
        for (i <- 0 until 63) {
          val bit = ((w >> i) & 1) == 1
          c.io.din.poke(bit.B)
          c.clock.step()
          c.io.valid.expect(false.B, s"valid must be low before bit 64 (word $idx, bit $i)")
        }

        // Present bit 63; expect valid high and dout == w on this cycle
        val bit63 = ((w >> 63) & 1) == 1
        c.io.din.poke(bit63.B)
        c.clock.step()
        c.io.valid.expect(true.B, s"valid must pulse on the 64th bit of word $idx")
        c.io.dout.expect(w.U, s"dout must equal the word on its valid cycle (word $idx)")
      }
    }
  }

  // 3) Partial word then a full word: only the full word should be recognized
  // NOTE: With current RTL (continuous shifting, no realignment), this will likely FAIL now.
  // Keep it to capture the intended behavior you plan to implement later (timeout/realign).
  it should "ignore a preceding partial word and only assert valid for the next full 64-bit word boundary" in {
    test(new SidebandRx).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      // Reset
      c.reset.poke(true.B);  c.clock.step()
      c.reset.poke(false.B)

      // Send a partial word: P bits (e.g., 17) — arbitrary fixed pattern
      val partialBits = 17
      val partialVal  = BigInt("15555", 16) // 0b1_0101_0101_0101_0101 (17 bits), LSB-first
      for (i <- 0 until partialBits) {
        val bit = ((partialVal >> i) & 1) == 1
        c.io.din.poke(bit.B)
        c.clock.step()
        c.io.valid.expect(false.B, "valid must remain low during partial segment")
      }

      // Now send a full 64-bit word we expect to be captured cleanly
      val fullWord = BigInt("0123456789ABCDEF", 16)

      // Drive bits 0..62 of the full word; valid must remain low
      for (i <- 0 until 63) {
        val bit = ((fullWord >> i) & 1) == 1
        c.io.din.poke(bit.B)
        c.clock.step()
        c.io.valid.expect(false.B, "valid must remain low until the 64th bit of the full word")
      }

      // Drive bit 63; expect valid high and dout == fullWord
      val bit63 = ((fullWord >> 63) & 1) == 1
      c.io.din.poke(bit63.B)
      c.clock.step()
      c.io.valid.expect(true.B, "valid should pulse exactly on the full word boundary")
      c.io.dout.expect(fullWord.U, "dout should equal the intended full word")
    }
  }
}