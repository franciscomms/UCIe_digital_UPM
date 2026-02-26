// for com 100 ciclos de relogio e peek de ready para tx

package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class SidebandModuleSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "SidebandModuleSpec_using_TestWrapperSBModule"

  it should "send partner word into RX while DUT TX sends another word concurrently" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      // --------- Messages ---------
      val partnerWord = BigInt("9123456789ABCDE9", 16) // Partner TX -> RX
      val dutTxWord   = BigInt("99AABBBBCCCCDDD9", 16)  // DUT TX -> observed at tx_dout

      // --------- Reset ---------

      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // Ready en IDLE
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)

      // --------- Armar ambas transmisiones ---------
      //load data into fifo
      c.io.tx_din.poke(dutTxWord.U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      //load data into partner
      c.io.partner_tx_valid.poke(true.B)
      c.io.partner_tx_din.poke(partnerWord.U)

      // Un ciclo para aceptar
      c.clock.step(1)

      // Deassert valids
      c.io.tx_valid.poke(false.B)
      c.io.partner_tx_valid.poke(false.B)

      // after one word tx queue is not full, partner ready should go down
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(false.B)
      

      // --------- Ejecutar 64 bits: dos steps por bit ---------
      // Step 1: posedge -> los TX actualizan 'dout'
      // Step 2: "negedge" efectivo -> RX (clockeado con !rx_clk) captura
      for (i <- 0 until 64) {

        // Verificar bit serial del DUT TX (LSB-first)
        val expectedDutBit = ((dutTxWord >> i) & 1) == 1
        c.io.tx_dout.expect(expectedDutBit.B)

        c.clock.step(1)
      }

      // Dar un ciclo extra por si rx_valid se aserta al final
      c.clock.step(1)

      // --------- Comprobar RX ---------
      c.io.rx_valid.expect(true.B)
      c.io.rx_dout.expect(partnerWord.U)

      // (Opcional) esperar a que ambos vuelvan a IDLE tras la GAP32
      c.clock.step(40)
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)
    }
  }

  it should "send 4 partner words into RX while DUT TX sends 4 other words concurrently" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>
      
      // --------------------------
      //   TEST VECTORS
      // --------------------------
      val partnerWords = Seq(
        BigInt("1111222233334444", 16),
        BigInt("5555666677778888", 16),
        BigInt("9999AAAABBBBCCCC", 16),
        BigInt("DDDDEEEEFFFF0001", 16)
      )

      val dutWords = Seq(
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16),
        BigInt("AAAAAAAAAAAAAAAA", 16),
        BigInt("9000000000000009", 16)
      )

      // --------------------------
      //   RESET
      // --------------------------
      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // --------------------------
      // Loop over 4 messages
      // --------------------------
      for (msgIndex <- 0 until 4) {

        val pw = partnerWords(msgIndex)
        val dw = dutWords(msgIndex)

        // Both should be ready in IDLE
        c.io.tx_ready.expect(true.B)
        c.io.partner_tx_ready.expect(true.B)

        // --------------------------
        // DRIVE BOTH TX (DUT FIFO first, partner one cycle later)
        // --------------------------
        // load data into DUT FIFO first
        c.io.tx_din.poke(dw.U)
        c.io.tx_valid.poke(true.B)
        c.clock.step(1)
        // now load partner TX (will be accepted next cycle)
        c.io.partner_tx_din.poke(pw.U)
        c.io.partner_tx_valid.poke(true.B)

        // Accept in one cycle
        c.clock.step(1)

        // Deassert valids
        c.io.tx_valid.poke(false.B)
        c.io.partner_tx_valid.poke(false.B)

        c.io.tx_ready.expect(false.B)
        c.io.partner_tx_ready.expect(false.B)

        // --------------------------
        //   64 bits of TX/RX
        // --------------------------
        for (bit <- 0 until 64) {
          val expectedTxBit = ((dw >> bit) & 1) == 1
          c.io.tx_dout.expect(expectedTxBit.B)
          c.clock.step(1)
        }

        // One extra step for rx_valid to rise
        c.clock.step(1)

        // --------------------------
        // Check RX received partner word
        // --------------------------
        c.io.rx_valid.expect(true.B)
        c.io.rx_dout.expect(pw.U)

        // --------------------------
        // Wait through GAP32 → back to IDLE
        // --------------------------
        c.clock.step(40)

        c.io.tx_ready.expect(true.B)
        c.io.partner_tx_ready.expect(true.B)
      }
    }
  }

  it should "ignore 5th DUT word when TX FIFO is full while partner streams to RX" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      val partnerWords = Seq(
        BigInt("1111222233334444", 16),
        BigInt("5555666677778888", 16),
        BigInt("9999AAAABBBBCCCC", 16),
        BigInt("DDDDEEEEFFFF0001", 16)
      )

      val dutWords = Seq(
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16),
        BigInt("AAAAAAAAAAAAAAAA", 16),
        BigInt("9000000000000009", 16) // should be dropped (6th enqueue)
      )

      // Reset
      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // Enqueue 5 DUT words back-to-back; only first 4 should fit in FIFO
      for (w <- dutWords) {
        c.io.tx_din.poke(w.U)
        c.io.tx_valid.poke(true.B)
        c.clock.step(1)
        c.io.tx_valid.poke(false.B)
      }

      // FIFO should have gone full after 4 enqueues; 5th not accepted
      c.io.tx_ready.expect(false.B)

      // Drain transmissions one by one; partner sends a word alongside each
      for (idx <- 0 until 4) {
        // launch partner word for RX
        c.io.partner_tx_din.poke(partnerWords(idx).U)
        c.io.partner_tx_valid.poke(true.B)
        c.clock.step(1)
        c.io.partner_tx_valid.poke(false.B)

        // capture serialized DUT word
        var captured: BigInt = 0
        for (bit <- 0 until 64) {
          val bitVal = c.io.tx_dout.peek().litToBoolean
          if (bitVal) captured = captured | (BigInt(1) << bit)
          c.clock.step(1)
        }

        // allow rx_valid to assert after partner finishes
        c.clock.step(1)

        // Check DUT word (5th should never appear) and partner RX delivery
        assert(captured == dutWords(idx), s"DUT word $idx mismatch: got 0x${captured.toString(16)} expected 0x${dutWords(idx).toString(16)}")
        c.io.rx_valid.expect(true.B)
        c.io.rx_dout.expect(partnerWords(idx).U)

        // GAP32 before next word
        c.clock.step(32)
      }

      // After four words transmitted, DUT should be idle and ready again; no 5th word sent
      c.io.tx_ready.expect(true.B)
      // Observe some idle cycles to confirm no extra bits toggle as a new word
      for (_ <- 0 until 16) {
        c.io.tx_dout.expect(false.B)
        c.clock.step(1)
      }
    }
  }

  it should "drop 6th DUT word when FIFO fills and still transmit first 5 in order" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      val dutWords = Seq(
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16),
        BigInt("AAAAAAAAAAAAAAAA", 16),
        BigInt("9000000000000009", 16)
      )

      // Reset
      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // Enqueue six words back-to-back; FIFO depth is 4 and first dequeues immediately, so the first five should get accepted, sixth should be dropped
      for (w <- dutWords) {
        c.io.tx_din.poke(w.U)
        c.io.tx_valid.poke(true.B)
        c.clock.step(1)
        c.io.tx_valid.poke(false.B)
      }

      // TX should be busy and FIFO should have dropped the 6th enqueue
      c.io.tx_ready.expect(false.B)

      // The first word begins transmitting the cycle after it was accepted
      var txIndex = 0
      for (_ <- 0 until 5) {
        var observed: BigInt = 0
        for (bit <- 0 until 64) {
          c.clock.step(1)
          val bitVal = c.io.tx_dout.peek().litToBoolean
          if (bitVal) observed = observed | (BigInt(1) << bit)
        }

        // After each 64-bit word, expect enforced 32-cycle gap
        for (_ <- 0 until 32) {
          c.clock.step(1)
          c.io.tx_dout.expect(false.B)
        }

        assert(observed == dutWords(txIndex), s"Transmitted word $txIndex mismatch: got 0x${observed.toString(16)} expected 0x${dutWords(txIndex).toString(16)}")
        txIndex += 1
      }

      // After five words drained, ready returns high; sixth was dropped
      c.io.tx_ready.expect(true.B)
      for (_ <- 0 until 16) {
        c.io.tx_dout.expect(false.B)
        c.clock.step(1)
      }
    }
  }

  it should "fill the fifo, empty it and receive new words" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      val dutWords = Seq(
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16),
        BigInt("AAAAAAAAAAAAAAAA", 16),
        BigInt("9000000000000009", 16), // should be dropped
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16),
        BigInt("AAAAAAAAAAAAAAAA", 16),
        BigInt("9000000000000009", 16),
      )

      // Reset
      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // Enqueue first word
      c.io.tx_din.poke(dutWords(0).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // Enqueue remaining four words back-to-back; observe via waveform
      c.io.tx_din.poke(dutWords(1).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      c.io.tx_din.poke(dutWords(2).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      c.io.tx_din.poke(dutWords(3).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // 5th should be sent, first is already out of FIFO
      c.io.tx_din.poke(dutWords(4).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // 6th should also be ignored; send to verify overflow beyond depth
      c.io.tx_din.poke(dutWords(5).U)
      c.io.tx_valid.poke(true.B)
      c.io.tx_ready.expect(false.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      /* Wait for the ready to be high again anf fill the FIFO 
      with 6 more words to confirm it can accept new enqueues 
      in the middle of second word. 

      Should only accept the 7th, 1st was transmitted, 5th is in fifo 
      6th is dropped, 7th gets into fifo and others are ignored
      */
      c.clock.step(150)
      c.io.tx_ready.expect(true.B)

      // 7th should be sent 
      c.io.tx_din.poke(dutWords(6).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)    
      //c.io.tx_ready.expect(false.B)
  
      // 8th 
      c.io.tx_din.poke(dutWords(7).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)      
      // 9th   
      c.io.tx_din.poke(dutWords(8).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)
            // 10th   
      c.io.tx_din.poke(dutWords(9).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)
            // 11th   
      c.io.tx_din.poke(dutWords(10).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)
            // 12th   
      c.io.tx_din.poke(dutWords(11).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)
      // Let waveform show transmission; no further checks here
      c.clock.step(600)
      c.io.tx_ready.expect(true.B)
    }
  }
/*
-----CONFIRM TEST WITH WAVEFORM-----
*/
  it should "linear test: 4 msgs, DUT TX starts, partner starts 20 cycles later (no loops)" in {
    test(new TestWrapperSBModule).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      // ======================================
      // RESET
      // ======================================
      c.reset.poke(true.B)
      c.io.rxReset.poke(false.B)
      c.clock.step(4)
      c.reset.poke(false.B)
      c.clock.step(2)

      // ======================================
      // MESSAGE DATA
      // ======================================

      val partnerWords = Seq(
        BigInt("1111222233334444", 16),
        BigInt("5555666677778888", 16),
        BigInt("9999AAAABBBBCCCC", 16),
        BigInt("DDDDEEEEFFFF0001", 16)
      )

      val dutWords = Seq(
        BigInt("ABCDEF0102030405", 16),
        BigInt("0F0E0D0C0B0A0908", 16),
        BigInt("1122334455667788", 16),
        BigInt("99AABBBBCCCCDDD9", 16)
      )

      // =====================================================
      // MESSAGE 1
      // =====================================================

      // DUT TX sends word #1
      c.io.tx_din.poke(dutWords(0).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // TX busy
      c.io.tx_ready.expect(false.B)

      // wait 20 cycles before partner starts
      c.clock.step(20)

      // partner TX sends word #1
      c.io.partner_tx_din.poke(partnerWords(0).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // partner is busy
      c.io.partner_tx_ready.expect(false.B)

      // DUT still has 64 - 20 = 44 cycles left
      c.clock.step(44)

      // now DUT TX finished → send next TX word
      c.io.tx_din.poke(dutWords(1).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // partner has 20 cycles left
      c.clock.step(20)

      // rx_valid should assert now (partner word 1 complete)
      c.clock.step(1)
      c.io.rx_valid.expect(true.B)
      c.io.rx_dout.expect(partnerWords(0).U)

      // send partner TX word #2
      c.io.partner_tx_din.poke(partnerWords(1).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // GAP32 until both TX engines return to IDLE
      c.clock.step(40)
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)


      // =====================================================
      // MESSAGE 2
      // =====================================================

      // DUT TX sends word #2 (already poked above)
      c.io.tx_din.poke(dutWords(1).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // wait 20 cycles
      c.clock.step(20)

      // partner TX sends word #2 (already poked above)
      c.io.partner_tx_din.poke(partnerWords(1).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // partner busy
      c.io.partner_tx_ready.expect(false.B)

      // DUT 44 cycles left
      c.clock.step(44)

      // DUT TX word #3
      c.io.tx_din.poke(dutWords(2).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // partner 20 cycles left
      c.clock.step(20)

      // rx should capture partner word #2
      c.clock.step(1)
      c.io.rx_valid.expect(true.B)
      c.io.rx_dout.expect(partnerWords(1).U)

      // partner TX word #3
      c.io.partner_tx_din.poke(partnerWords(2).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // GAP32
      c.clock.step(40)
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)


      // =====================================================
      // MESSAGE 3
      // =====================================================

      // DUT TX sends word #3
      c.io.tx_din.poke(dutWords(2).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // wait 20 cycles
      c.clock.step(20)

      // partner TX sends word #3
      c.io.partner_tx_din.poke(partnerWords(2).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // partner busy
      c.io.partner_tx_ready.expect(false.B)

      // DUT remaining 44 cycles
      c.clock.step(44)

      // DUT TX word #4
      c.io.tx_din.poke(dutWords(3).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // partner 20 cycles left
      c.clock.step(20)

      // rx gets partner word #3
      c.clock.step(1)
      c.io.rx_valid.expect(true.B)
      c.io.rx_dout.expect(partnerWords(2).U)

      // partner TX word #4
      c.io.partner_tx_din.poke(partnerWords(3).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // GAP32
      c.clock.step(40)
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)


      // =====================================================
      // MESSAGE 4
      // =====================================================

      // DUT TX sends word #4
      c.io.tx_din.poke(dutWords(3).U)
      c.io.tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.tx_valid.poke(false.B)

      // wait 20 cycles
      c.clock.step(20)

      // partner TX sends word #4
      c.io.partner_tx_din.poke(partnerWords(3).U)
      c.io.partner_tx_valid.poke(true.B)
      c.clock.step(1)
      c.io.partner_tx_valid.poke(false.B)

      // partner busy
      c.io.partner_tx_ready.expect(false.B)

      // DUT remaining 44 cycles
      c.clock.step(44)

      // partner remaining 20 cycles
      c.clock.step(20)

      // rx gets partner word #4
      c.clock.step(1)
      c.io.rx_valid.expect(true.B)
      c.io.rx_dout.expect(partnerWords(3).U)

      // final GAP32
      c.clock.step(40)
      c.io.tx_ready.expect(true.B)
      c.io.partner_tx_ready.expect(true.B)
    }
  }
}