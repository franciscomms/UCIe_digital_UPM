import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec
import ucie._
import chiseltest.simulator.VerilatorBackendAnnotation

import scala.collection.mutable

class AsyncFifoDecoupledSpec extends AnyFlatSpec with ChiselScalatestTester {

  "AsyncFifoDecoupledSimWrapper" should "move data correctly across async clocks (with checks + waves)" in {
    test(new AsyncFifoDecoupledSimWrapper(width = 8, depth = 16, wPeriodCycles = 10, rPeriodCycles = 4))
      .withAnnotations(Seq(VerilatorBackendAnnotation, WriteVcdAnnotation)) { dut =>

        dut.clock.setTimeout(0)

        // Init
        dut.io.enq.valid.poke(false.B)
        dut.io.enq.bits.poke(0.U)
        dut.io.deq.ready.poke(true.B)

        // Resets (as in your TB)
        dut.io.enq_reset.poke(true.B)
        dut.io.deq_reset.poke(true.B)
        dut.reset.poke(true.B)
        dut.clock.step(5)
        dut.reset.poke(false.B)
        dut.clock.step(5)
        dut.io.enq_reset.poke(false.B)
        dut.io.deq_reset.poke(false.B)

        val nWords    = 40
        val maxCycles = 4000

        var push = 0
        var pop  = 0

        // Golden queue (what we believe is inside FIFO)
        val q = mutable.Queue[Int]()

        // Simple deterministic backpressure pattern on deq.ready
        def readyPattern(cycle: Int): Boolean = {
          // stall 3 cycles every 10 cycles (creates backpressure)
          val m = cycle % 10
          !(m == 7 || m == 8 || m == 9)
        }

        for (cycle <- 0 until maxCycles) {

          // Drive producer
          if (push < nWords) {
            dut.io.enq.valid.poke(true.B)
            dut.io.enq.bits.poke((push & 0xFF).U)
          } else {
            dut.io.enq.valid.poke(false.B)
          }

          // Drive consumer ready with pattern
          dut.io.deq.ready.poke(readyPattern(cycle).B)

          // Observe handshakes in *this* cycle
          val enqFire = dut.io.enq.valid.peek().litToBoolean && dut.io.enq.ready.peek().litToBoolean
          val deqFire = dut.io.deq.valid.peek().litToBoolean && dut.io.deq.ready.peek().litToBoolean

          // If dequeue happens, check data matches queue head
          if (deqFire) {
            val got = dut.io.deq.bits.peek().litValue.toInt & 0xFF
            assert(q.nonEmpty, s"Deq fired but golden queue is empty at cycle=$cycle")
            val exp = q.dequeue()
            assert(got == exp, f"Data mismatch at cycle=$cycle: expected 0x$exp%02X got 0x$got%02X")
            pop += 1
          }

          // If enqueue happens, push into golden queue
          if (enqFire) {
            q.enqueue(push & 0xFF)
            push += 1
          }

          dut.clock.step(1)

          // Early exit when done and drained
          if (push == nWords && pop == nWords) {
            // All transferred
            // (allow a couple cycles for waveform readability)
            dut.clock.step(5)
            return
          }
        }

        fail(s"Timeout: push=$push pop=$pop qSize=${q.size}")
      }
  }
}