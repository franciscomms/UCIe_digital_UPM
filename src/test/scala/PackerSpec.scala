package ucie

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class PackerSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "Packer"

  it should "pack 4 beats (8->32) LSB-first into one word" in {
    test(new Packer(inWidth = 8, outWidth = 32)).withAnnotations(Seq(WriteVcdAnnotation)) { dut =>
      dut.io.in.valid.poke(false.B)
      dut.io.out.ready.poke(true.B)
      dut.clock.step(2)

      // Send 4 beats: 0x11, 0x22, 0x33, 0x44
      val beats = Seq(0x11, 0x22, 0x33, 0x44)

      beats.foreach { b =>
        dut.io.in.bits.poke(b.U)
        dut.io.in.valid.poke(true.B)
        // wait until accepted (should be immediate here)
        while (!dut.io.in.ready.peek().litToBoolean) dut.clock.step(1)
        dut.clock.step(1)
      }
      dut.io.in.valid.poke(false.B)

      // After last beat, full becomes true on next cycle -> out.valid should assert
      // Wait for out.valid then check the word and consume it
      while (!dut.io.out.valid.peek().litToBoolean) dut.clock.step(1)

      val got = dut.io.out.bits.peek().litValue
      val expected = 0x44332211L
      assert(got == expected, f"Expected 0x$expected%08X but got 0x$got%08X")

      // Consume
      dut.io.out.ready.poke(true.B)
      dut.clock.step(1)
      assert(!dut.io.out.valid.peek().litToBoolean, "After consuming, out.valid should drop (not full)")
    }
  }

  it should "apply backpressure when full and handle out.fire && in.fire in same cycle (8->32)" in {
    test(new Packer(inWidth = 8, outWidth = 32)).withAnnotations(Seq(WriteVcdAnnotation)) { dut =>
      dut.io.in.valid.poke(false.B)
      dut.io.out.ready.poke(true.B)
      dut.clock.step(2)

      def pushBeat(b: Int): Unit = {
        dut.io.in.bits.poke(b.U)
        dut.io.in.valid.poke(true.B)
        while (!dut.io.in.ready.peek().litToBoolean) dut.clock.step(1)
        dut.clock.step(1)
        dut.io.in.valid.poke(false.B)
      }

      // Fill first word: 0x11 0x22 0x33 0x44 -> 0x44332211
      Seq(0x11, 0x22, 0x33, 0x44).foreach(pushBeat)

      // Wait until full/valid
      while (!dut.io.out.valid.peek().litToBoolean) dut.clock.step(1)

      // Stall downstream: out.ready=0
      dut.io.out.ready.poke(false.B)
      dut.clock.step(1)

      // While full and stalled, in.ready must be 0 (no double buffering)
      dut.io.in.bits.poke(0xAA.U)
      dut.io.in.valid.poke(true.B)
      assert(!dut.io.in.ready.peek().litToBoolean, "When full and out not ready, in.ready must be 0")

      // Now enable out.ready=1, keep in.valid=1 so we force simultaneous out.fire & in.fire
      dut.io.out.ready.poke(true.B)

      // In this cycle, the old word should be consumed AND the first beat of next word accepted.
      // Step one cycle
      dut.clock.step(1)

      // Now continue sending remaining beats for second word: already accepted 0xAA as beat0,
      // send beats 0xBB,0xCC,0xDD -> expected word = 0xDDCCBBAA
      dut.io.in.valid.poke(false.B)
      Seq(0xBB, 0xCC, 0xDD).foreach(pushBeat)

      // Wait for second word to appear
      while (!dut.io.out.valid.peek().litToBoolean) dut.clock.step(1)
      val got2 = dut.io.out.bits.peek().litValue
      val expected2 = 0xDDCCBBAAL
      assert(got2 == expected2, f"Expected 0x$expected2%08X but got 0x$got2%08X")

      // Consume second
      dut.io.out.ready.poke(true.B)
      dut.clock.step(1)
    }
  }

  it should "work for ratio=1 (32->32) as passthrough (no loss, no reordering)" in {
  test(new Packer(inWidth = 32, outWidth = 32)).withAnnotations(Seq(WriteVcdAnnotation)) { dut =>
    dut.io.out.ready.poke(true.B)
    dut.io.in.valid.poke(false.B)
    dut.clock.step(2)

    val inputs = Seq(
      BigInt("11111111", 16),
      BigInt("22222222", 16),
      BigInt("33333333", 16),
      BigInt("44444444", 16),
      BigInt("55555555", 16)
    )

    var collected = Vector.empty[BigInt]

    // Drive inputs and collect outputs in the SAME cycles
    for (v <- inputs) {
      dut.io.in.bits.poke(v.U)
      dut.io.in.valid.poke(true.B)

      // In passthrough, if ready=1, we expect out.valid=1 same cycle.
      // But to be safe with different implementations, we step 1 cycle and then sample fire.
      dut.clock.step(1)

      if (dut.io.out.valid.peek().litToBoolean && dut.io.out.ready.peek().litToBoolean) {
        collected = collected :+ dut.io.out.bits.peek().litValue
      }
    }

    // Stop driving
    dut.io.in.valid.poke(false.B)

    // Drain any remaining items for a few cycles (covers 1-cycle latency implementations too)
    var guard = 0
    while (collected.length < inputs.length && guard < 20) {
      if (dut.io.out.valid.peek().litToBoolean && dut.io.out.ready.peek().litToBoolean) {
        collected = collected :+ dut.io.out.bits.peek().litValue
      }
      dut.clock.step(1)
      guard += 1
    }

    assert(collected == inputs, s"Expected $inputs, got $collected")
  }
}
}