package edu.berkeley.cs.ucie.digital

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class LinkTrainingFSMSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "LinkTrainingFSM"

/*  it should "reset then advance through all stages with minimal stimuli" in {
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
*/
  it should "advance through all stages using a while-driven clock loop" in {
    test(new LinkTrainingFSM).withAnnotations(Seq(WriteVcdAnnotation)) { c =>

      // fixed stimulus words
      val pattern     = BigInt("AAAAAAAAAAAAAAAA", 16)
      val successMsg  = BigInt("0200010040244012", 16)
      val doneReqMsg  = BigInt("4200000140254012", 16)
      val doneRespMsg = BigInt("4200000140268012", 16)
      val mbinitParamReqHeaderWord  = BigInt("820000004029401B", 16)
      val mbinitParamReqPayloadWord = BigInt("0000000000000073", 16)
      val mbinitParamRespHeaderWord = BigInt("02000000402A801B", 16)
      val mbinitParamRespPayloadWord = BigInt("0000000000000003", 16)
      val mbinitCalDoneReqWord = BigInt("4200000240294012", 16)
      val mbinitCalDoneRespWord = BigInt("42000002402A8012", 16)
      val mbinitRepairClkInitReqWord = BigInt("0200000340294012", 16)
      val mbinitRepairClkInitRespWord = BigInt("02000003402A8012", 16)
      val mbinitRepairClkResultReqWord  = BigInt("4200000440294012", 16)
      val mbinitRepairClkResultRespWord = BigInt("02000704402A8012", 16) // all clks patterns detected
      val mbinitRepairClkDoneReqWord = BigInt("4200000840294012", 16)
      val mbinitRepairClkDoneRespWord = BigInt("42000008402A8012", 16)

      // state ids
      val RESET          = 0
      val SBINIT_pattern = 1
      val SBINIT_OORmsg  = 3
      val SBINIT_DONEmsg = 4
      val MBINIT_PARAM   = 5
      val MBINIT_Cal     = 6
      val MBINIT_REPAIRCLK = 7
      val ACTIVE         = 11

      // loop and progress flags
      var cycle = 0
      var firstPatternSent = false
      var gapAfterFirst = 0
      var secondPatternSent = false
      var successSent = false
      var doneReqSent = false
      var doneRespObserved = false
      var doneRespSent = false
      var mbinitParamReqHeaderSent = false
      var mbinitParamReqPayloadSent = false
      var mbinitParamReqPayloadGap = 0
      var mbinitParamAfterReqPayloadWait = 0
      var mbinitParamDutReqHeaderSeen = false
      var mbinitParamDutReqPayloadSeen = false
      var mbinitParamRespHeaderSent = false
      var mbinitParamRespPayloadSent = false
      var mbinitParamRespPayloadGap = 0
      var mbinitCalDoneReqSent = false
      var mbinitCalDutDoneReqSeen = false
      var mbinitCalDutDoneRespSeen = false
      var mbinitCalDoneRespSent = false
      var mbinitCalAfterReqWait = 0
      var mbinitRepairClkInitReqSeen = false
      var mbinitRepairClkInitRespSent = false
      var mbinitRepairClkReadyHigh = false
      var mbinitRepairClkSendPatternsSeen = false
      var mbinitRepairClkPatternWaitCycles = -1
      var mbinitRepairClkFinishedHigh = false
      var mbinitRepairClkResultReqSeen = false
      var mbinitRepairClkResultRespSent = false
      var mbinitRepairClkDoneReqSeen = false
      var mbinitRepairClkDoneRespSent = false

      // receiver-side parallel path (peer initiates, DUT responds)
      var mbinitRepairClkPeerInitReqSent = false
      var mbinitRepairClkPeerInitRespSeen = false
      var mbinitRepairClkPeerResultReqSent = false
      var mbinitRepairClkPeerResultRespSeen = false
      var mbinitRepairClkPeerDoneReqSent = false
      var mbinitRepairClkPeerDoneRespSeen = false
      var mbinitRepairClkPeerAnalogStage = 0
      var mbinitRepairClkPeerRTRKHigh = false
      var mbinitRepairClkPeerRCKNHigh = false
      var mbinitRepairClkPeerRCKPHigh = false
      var prevRxValidWasHigh = false

      while (cycle < 300) {
        // default RX inputs each cycle
        c.io.sb_rx_valid.poke(false.B)
        c.io.sb_rx_dout.poke(0.U)
        c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(false.B)
        c.io.flagFromAnalog_FinishedClkPatterns.poke(false.B)
        c.io.flagFromAnalog_clkPatternReceivedRTRK_L.poke(mbinitRepairClkPeerRTRKHigh.B)
        c.io.flagFromAnalog_clkPatternReceivedRCKN_L.poke(mbinitRepairClkPeerRCKNHigh.B)
        c.io.flagFromAnalog_clkPatternReceivedRCKP_L.poke(mbinitRepairClkPeerRCKPHigh.B)

        if (mbinitRepairClkReadyHigh) {
          c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(true.B)
        }
        if (mbinitRepairClkFinishedHigh) {
          c.io.flagFromAnalog_FinishedClkPatterns.poke(true.B)
        }

        val canSendRxThisCycle = !prevRxValidWasHigh
        var rxSentThisCycle = false

        // reset phase for first three cycles
        if (cycle < 3) {
          c.reset.poke(true.B)
          c.io.start.poke(false.B)
          c.io.stable_clk.poke(false.B)
          c.io.pll_locked.poke(false.B)
          c.io.stable_supply.poke(false.B)
          c.io.sb_tx_ready.poke(false.B)
          c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(false.B)
          c.io.flagFromAnalog_FinishedClkPatterns.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRTRK_L.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRCKN_L.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRCKP_L.poke(false.B)
          mbinitRepairClkPeerRTRKHigh = false
          mbinitRepairClkPeerRCKNHigh = false
          mbinitRepairClkPeerRCKPHigh = false
        } else {
          c.reset.poke(false.B)
          c.io.start.poke(true.B)
          c.io.stable_clk.poke(true.B)
          c.io.pll_locked.poke(true.B)
          c.io.stable_supply.poke(true.B)
          c.io.sb_tx_ready.poke(true.B)
        }

        val stateVal = c.io.state.peek().litValue.toInt

        // SBINIT pattern handshake
        if (stateVal == SBINIT_pattern) {
          if (!firstPatternSent) {
            if (canSendRxThisCycle) {
              c.io.sb_rx_dout.poke(pattern.U)
              c.io.sb_rx_valid.poke(true.B)
              firstPatternSent = true
              gapAfterFirst = 32
              rxSentThisCycle = true
            }
          } else if (gapAfterFirst > 0) {
            gapAfterFirst -= 1
          } else if (!secondPatternSent) {
            if (canSendRxThisCycle) {
              c.io.sb_rx_dout.poke(pattern.U)
              c.io.sb_rx_valid.poke(true.B)
              secondPatternSent = true
              rxSentThisCycle = true
            }
          }
        }

        // SBINIT OOR ack
        if (stateVal == SBINIT_OORmsg && !successSent) {
          if (canSendRxThisCycle) {
            c.io.sb_rx_dout.poke(successMsg.U)
            c.io.sb_rx_valid.poke(true.B)
            successSent = true
            rxSentThisCycle = true
          }
        }

        // SBINIT DONE req/resp exchange
        if (stateVal == SBINIT_DONEmsg) {
          //send req
          if (!doneReqSent) {
            if (canSendRxThisCycle) {
              c.io.sb_rx_dout.poke(doneReqMsg.U)
              c.io.sb_rx_valid.poke(true.B)
              doneReqSent = true
              rxSentThisCycle = true
            }
          }

          //wait for module to sent the req and response
          
          
          if (c.io.sb_tx_valid.peek().litToBoolean && c.io.sb_tx_din.peek().litValue == doneRespMsg) {
            doneRespObserved = true
          }
          //After seeing resp send our resp
          if (doneRespObserved && !doneRespSent) {
            if (canSendRxThisCycle && !rxSentThisCycle) {
              c.io.sb_rx_dout.poke(doneRespMsg.U)
              c.io.sb_rx_valid.poke(true.B)
              doneRespSent = true
              rxSentThisCycle = true
            }
          }
        }

        // MBINIT.PARAM req/resp with payloads
        if (stateVal == MBINIT_PARAM) {
          //reception from DUT
          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue
            if (!mbinitParamDutReqHeaderSeen && txWord == mbinitParamReqHeaderWord) {
              mbinitParamDutReqHeaderSeen = true
            } else if (!mbinitParamDutReqPayloadSeen && txWord == mbinitParamReqPayloadWord) {
              mbinitParamDutReqPayloadSeen = true
            }
          }

          //send req
          if (!mbinitParamReqHeaderSent) {
            if (canSendRxThisCycle) {
              c.io.sb_rx_dout.poke(mbinitParamReqHeaderWord.U)
              c.io.sb_rx_valid.poke(true.B)
              mbinitParamReqHeaderSent = true
              mbinitParamReqPayloadGap = 3
              rxSentThisCycle = true
            }
          } else if (mbinitParamReqHeaderSent && !mbinitParamReqPayloadSent) {
            if (mbinitParamReqPayloadGap > 0) {
              mbinitParamReqPayloadGap -= 1
            } else {
              if (canSendRxThisCycle && !rxSentThisCycle) {
                c.io.sb_rx_dout.poke(mbinitParamReqPayloadWord.U)
                c.io.sb_rx_valid.poke(true.B)
                mbinitParamReqPayloadSent = true
                mbinitParamAfterReqPayloadWait = 3
                rxSentThisCycle = true
              }
            }
          }

          if (mbinitParamReqPayloadSent && mbinitParamAfterReqPayloadWait > 0) {
            mbinitParamAfterReqPayloadWait -= 1
          }

          //send resp
          if (mbinitParamDutReqPayloadSeen && mbinitParamReqPayloadSent && mbinitParamAfterReqPayloadWait == 0 && !mbinitParamRespHeaderSent) {
            if (canSendRxThisCycle && !rxSentThisCycle) {
              c.io.sb_rx_dout.poke(mbinitParamRespHeaderWord.U)
              c.io.sb_rx_valid.poke(true.B)
              mbinitParamRespHeaderSent = true
              mbinitParamRespPayloadGap = 3
              rxSentThisCycle = true
            }
          } else if (mbinitParamRespHeaderSent && !mbinitParamRespPayloadSent) {
            if (mbinitParamRespPayloadGap > 0) {
              mbinitParamRespPayloadGap -= 1
            } else {
              if (canSendRxThisCycle && !rxSentThisCycle) {
                c.io.sb_rx_dout.poke(mbinitParamRespPayloadWord.U)
                c.io.sb_rx_valid.poke(true.B)
                mbinitParamRespPayloadSent = true
                rxSentThisCycle = true
              }
            }
          }
        }

        // MBINIT.CAL done req/resp exchange
        if (stateVal == MBINIT_Cal) {
          // capture DUT TX words
          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue
            if (!mbinitCalDutDoneReqSeen && txWord == mbinitCalDoneReqWord) {
              mbinitCalDutDoneReqSeen = true
            }
            if (!mbinitCalDutDoneRespSeen && txWord == mbinitCalDoneRespWord) {
              mbinitCalDutDoneRespSeen = true
            }
          }

          // send CAL done req first
          if (!mbinitCalDoneReqSent) {
            if (canSendRxThisCycle) {
              c.io.sb_rx_dout.poke(mbinitCalDoneReqWord.U)
              c.io.sb_rx_valid.poke(true.B)
              mbinitCalDoneReqSent = true
              mbinitCalAfterReqWait = 3
              rxSentThisCycle = true
            }
          }

          // wait 3 cycles before sending CAL done resp
          if (mbinitCalDoneReqSent && mbinitCalAfterReqWait > 0) {
            mbinitCalAfterReqWait -= 1
          }

          // send CAL done resp after DUT req is observed and wait expires
          if (mbinitCalDutDoneReqSeen && mbinitCalAfterReqWait == 0 && !mbinitCalDoneRespSent) {
            if (canSendRxThisCycle && !rxSentThisCycle) {
              c.io.sb_rx_dout.poke(mbinitCalDoneRespWord.U)
              c.io.sb_rx_valid.poke(true.B)
              mbinitCalDoneRespSent = true
              rxSentThisCycle = true
            }
          }
        }

        if (stateVal == MBINIT_REPAIRCLK) {
          var rxWordValid = false
          var rxWord = BigInt(0)

          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue
            if (!mbinitRepairClkInitReqSeen && txWord == mbinitRepairClkInitReqWord) {
              mbinitRepairClkInitReqSeen = true
            }
            if (!mbinitRepairClkResultReqSeen && txWord == mbinitRepairClkResultReqWord) {
              mbinitRepairClkResultReqSeen = true
            }
            if (!mbinitRepairClkDoneReqSeen && txWord == mbinitRepairClkDoneReqWord) {
              mbinitRepairClkDoneReqSeen = true
            }

            if (!mbinitRepairClkPeerInitRespSeen && txWord == mbinitRepairClkInitRespWord) {
              mbinitRepairClkPeerInitRespSeen = true
            }
            if (!mbinitRepairClkPeerResultRespSeen && txWord == mbinitRepairClkResultRespWord) {
              mbinitRepairClkPeerResultRespSeen = true
            }
            if (!mbinitRepairClkPeerDoneRespSeen && txWord == mbinitRepairClkDoneRespWord) {
              mbinitRepairClkPeerDoneRespSeen = true
            }
          }

          // keep analog ready high through MBINIT_REPAIRCLK so both paths can progress in parallel
          mbinitRepairClkReadyHigh = true

          // sender path responses (peer answers DUT requests)
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairClkInitReqSeen && !mbinitRepairClkInitRespSent) {
            rxWord = mbinitRepairClkInitRespWord
            rxWordValid = true
            mbinitRepairClkInitRespSent = true
          }

          if (!mbinitRepairClkSendPatternsSeen && c.io.flagToAnalog_SendClkPatterns.peek().litToBoolean) {
            mbinitRepairClkSendPatternsSeen = true
            mbinitRepairClkPatternWaitCycles = 7
          }

          if (mbinitRepairClkSendPatternsSeen && !mbinitRepairClkFinishedHigh) {
            if (mbinitRepairClkPatternWaitCycles > 0) {
              mbinitRepairClkPatternWaitCycles -= 1
            } else {
              mbinitRepairClkFinishedHigh = true
            }
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairClkResultReqSeen && !mbinitRepairClkResultRespSent) {
            rxWord = mbinitRepairClkResultRespWord
            rxWordValid = true
            mbinitRepairClkResultRespSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairClkDoneReqSeen && !mbinitRepairClkDoneRespSent) {
            rxWord = mbinitRepairClkDoneRespWord
            rxWordValid = true
            mbinitRepairClkDoneRespSent = true
          }

          // receiver path requests (peer initiates while sender path is also running)
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && !mbinitRepairClkPeerInitReqSent) {
            rxWord = mbinitRepairClkInitReqWord
            rxWordValid = true
            mbinitRepairClkPeerInitReqSent = true
          }

          if (mbinitRepairClkPeerInitRespSeen && !mbinitRepairClkPeerResultReqSent) {
            if (mbinitRepairClkPeerAnalogStage == 0) {
              c.io.flagFromAnalog_clkPatternReceivedRTRK_L.poke(true.B)
              mbinitRepairClkPeerRTRKHigh = true
              mbinitRepairClkPeerAnalogStage = 1
            } else if (mbinitRepairClkPeerAnalogStage == 1) {
              c.io.flagFromAnalog_clkPatternReceivedRCKN_L.poke(true.B)
              mbinitRepairClkPeerRCKNHigh = true
              mbinitRepairClkPeerAnalogStage = 2
            } else if (mbinitRepairClkPeerAnalogStage == 2) {
              c.io.flagFromAnalog_clkPatternReceivedRCKP_L.poke(true.B)
              mbinitRepairClkPeerRCKPHigh = true
              mbinitRepairClkPeerAnalogStage = 3
            } else if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid) {
              rxWord = mbinitRepairClkResultReqWord
              rxWordValid = true
              mbinitRepairClkPeerResultReqSent = true
            }
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairClkPeerResultRespSeen && !mbinitRepairClkPeerDoneReqSent) {
            rxWord = mbinitRepairClkDoneReqWord
            rxWordValid = true
            mbinitRepairClkPeerDoneReqSent = true
          } 

          if (canSendRxThisCycle && !rxSentThisCycle && rxWordValid) {
            c.io.sb_rx_dout.poke(rxWord.U)
            c.io.sb_rx_valid.poke(true.B)
            rxSentThisCycle = true
          }
        }

        prevRxValidWasHigh = rxSentThisCycle

        // advance one cycle
        c.clock.step(1)
        cycle += 1
      }

      // final state check
      c.io.state.expect(ACTIVE.U)
      // handshake completion checks
      assert(
        firstPatternSent && secondPatternSent && successSent && doneReqSent && doneRespObserved && doneRespSent &&
        mbinitParamReqHeaderSent && mbinitParamReqPayloadSent &&
        mbinitParamDutReqHeaderSeen && mbinitParamDutReqPayloadSeen &&
        mbinitParamRespHeaderSent && mbinitParamRespPayloadSent &&
        mbinitCalDoneReqSent && mbinitCalDutDoneReqSeen && mbinitCalDutDoneRespSeen && mbinitCalDoneRespSent &&
        mbinitRepairClkInitReqSeen && mbinitRepairClkInitRespSent && mbinitRepairClkReadyHigh &&
        mbinitRepairClkSendPatternsSeen && mbinitRepairClkFinishedHigh &&
        mbinitRepairClkResultReqSeen && mbinitRepairClkResultRespSent &&
        mbinitRepairClkDoneReqSeen && mbinitRepairClkDoneRespSent &&
        mbinitRepairClkPeerInitReqSent && mbinitRepairClkPeerInitRespSeen &&
        mbinitRepairClkPeerResultReqSent && mbinitRepairClkPeerResultRespSeen &&
        mbinitRepairClkPeerDoneReqSent && mbinitRepairClkPeerDoneRespSeen
      )
    }
  }
}