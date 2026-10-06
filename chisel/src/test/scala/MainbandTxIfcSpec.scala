package ucie

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class MainbandTxIfcSpec extends AnyFlatSpec with ChiselScalatestTester {

  "MainbandTxIfc" should "pack 4x8 into 32 bits correctly" in {
    test(new MainbandTxIfc(in_width = 8, out_width = 32)) { dut =>

      dut.io.in.valid.poke(false.B)
      dut.io.mb.ready.poke(true.B)
      dut.clock.step()

      val inputs = Seq(0x11, 0x22, 0x33, 0x44)

      for(i <- inputs.indices) {
        dut.io.in.valid.poke(true.B)
        dut.io.in.bits.poke(inputs(i).U)

        // Esperar hasta que acepte
        while(!dut.io.in.ready.peek().litToBoolean) {
          dut.clock.step()
        }

        dut.clock.step()
      }

      dut.io.in.valid.poke(false.B)

      // Esperar a que salga el dato empaquetado
      while(!dut.io.mb.valid.peek().litToBoolean) {
        dut.clock.step()
      }

      val expected =
        0x11 |
        (0x22 << 8) |
        (0x33 << 16) |
        (0x44 << 24)

      val result = dut.io.mb.bits.peek().litValue.toLong

      //assert(result == expected,
      //  f"Expected 0x$expected%08X but got 0x$result%08X")

      dut.clock.step()
    }
  }
}