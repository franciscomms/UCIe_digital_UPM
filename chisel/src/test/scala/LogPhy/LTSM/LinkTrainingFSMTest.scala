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

      // ---------------------------------------------------------------------------------
      // Fixed sideband words used by the peer model
      // ---------------------------------------------------------------------------------
      // These values represent the exact 64-bit headers/payloads expected by the DUT
      // for each LT/SBINIT/MBINIT transaction.
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

      val mbinitRepairValInitReqWord = BigInt("0200000540294012", 16)
      val mbinitRepairValInitRespWord = BigInt("02000005402A8012", 16)
      val mbinitRepairValResultReqWord = BigInt("0200000640294012", 16)
      val mbinitRepairValResultRespWord = BigInt("42000106402A8012", 16)
      val mbinitRepairValDoneReqWord = BigInt("0200000940294012", 16)
      val mbinitRepairValDoneRespWord = BigInt("02000009402A8012", 16)

      // MBINIT.REVERSALMB fixed words (header-only and header+payload)
      // Sender path and receiver path both use these constants.
      val mbinitReversalMbInitReqWord = BigInt("4200000D40294012", 16)
      val mbinitReversalMbInitRespWord = BigInt("4200000D402A8012", 16)
      val mbinitReversalMbClearErrorReqWord = BigInt("4200000E40294012", 16)
      val mbinitReversalMbClearErrorRespWord = BigInt("4200000E402A8012", 16)
      val mbinitReversalMbResultReqWord = BigInt("0200000F40294012", 16)
      val mbinitReversalMbResultRespHeaderWord = BigInt("0200000F402A801B", 16)
      val mbinitReversalMbResultRespPayloadWord = BigInt("000000000000FFFF", 16)
      val mbinitReversalMbDoneReqWord = BigInt("4200001040294012", 16)
      val mbinitReversalMbDoneRespWord = BigInt("42000010402A8012", 16)

      // MBINIT.REPAIRMB fixed words (header-only and header+payload)
      val mbinitRepairMbStartReqWord = BigInt("0200001140294012", 16)
      val mbinitRepairMbStartRespWord = BigInt("02000011402A8012", 16)
      val mbinitRepairMbD2CPointTestReqHeaderWord = BigInt("020000124029401B", 16)
      val mbinitRepairMbD2CPointTestReqPayloadWord = BigInt("0004000000000001", 16)
      val mbinitRepairMbD2CPointTestRespWord = BigInt("02000012402A8012", 16)
      val mbinitRepairMbLfsrClearErrorReqWord = BigInt("4200001340294012", 16)
      val mbinitRepairMbLfsrClearErrorRespWord = BigInt("42000013402A8012", 16)
      val mbinitRepairMbTxInitD2CResultsReqWord = BigInt("0200001440294012", 16)
      val mbinitRepairMbTxInitD2CResultsRespHeaderWord = BigInt("02000014402A801B", 16)
      val mbinitRepairMbTxInitD2CResultsRespPayloadWord = BigInt("000000000000FFFF", 16)
      val mbinitRepairMbEndTxInitD2CPointTestReqWord = BigInt("4200001540294012", 16)
      val mbinitRepairMbEndTxInitD2CPointTestRespWord = BigInt("42000015402A8012", 16)
      val mbinitRepairMbApplyDegradeReq011Word = BigInt("4200031640294012", 16)
      val mbinitRepairMbApplyDegradeReq000Word = BigInt("4200001640294012", 16)
      val mbinitRepairMbApplyDegradeRespWord = BigInt("42000016402A8012", 16)
      val mbinitRepairMbEndReqWord = BigInt("0200001740294012", 16)
      val mbinitRepairMbEndRespWord = BigInt("02000017402A8012", 16)

      // ---------------------------------------------------------------------------------
      // Top-level LT state IDs
      // ---------------------------------------------------------------------------------
      // The top FSM now enters MBINIT through a single super-state. Detailed MBINIT
      // sequencing is driven by MBInitFSM substate debug output.
      val RESET          = 0
      val SBINIT_pattern = 1
      val SBINIT_OORmsg  = 3
      val SBINIT_DONEmsg = 4
      val MBINIT_SUPER   = 5
      val ACTIVE         = 8

      // ---------------------------------------------------------------------------------
      // MBInitFSM substate IDs (visible while LT state is MBINIT_SUPER)
      // ---------------------------------------------------------------------------------
      val MBINIT_PARAM   = 0
      val MBINIT_Cal     = 1
      val MBINIT_REPAIRCLK = 2
      val MBINIT_REPAIRVAL = 3
      val MBINIT_REVERSALMB = 4
      val MBINIT_REPAIRMB = 5

      // ---------------------------------------------------------------------------------
      // Progress/bookkeeping flags
      // ---------------------------------------------------------------------------------
      // Each boolean tracks that a specific handshake milestone was observed/sent.
      // Final assertions use these to guarantee complete protocol coverage.
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
      // MBINIT_REPAIRVAL sender path
      var mbinitRepairValInitReqSeen = false
      var mbinitRepairValInitRespSent = false
      var mbinitRepairValSendPatternSeen = false
      var mbinitRepairValPatternWaitCycles = -1
      var mbinitRepairValFinishedHigh = false
      var mbinitRepairValResultReqSeen = false
      var mbinitRepairValResultRespSent = false
      var mbinitRepairValDoneReqSeen = false
      var mbinitRepairValDoneRespSent = false
      // MBINIT_REPAIRVAL receiver path
      var mbinitRepairValPeerInitReqSent = false
      var mbinitRepairValPeerInitRespSeen = false
      var mbinitRepairValPeerValTrainPatternReceivedHigh = false
      var mbinitRepairValPeerResultReqSent = false
      var mbinitRepairValPeerResultRespSeen = false
      var mbinitRepairValPeerDoneReqSent = false
      var mbinitRepairValPeerDoneRespSeen = false

      // MBINIT_REVERSALMB sender path (DUT initiates, peer responds)
      var mbinitReversalMbInitReqSeen = false
      var mbinitReversalMbInitRespSent = false
      var mbinitReversalMbClearErrorReqSeen = false
      var mbinitReversalMbClearErrorRespSent = false
      var mbinitReversalMbClearErrorRespPending = false
      var mbinitReversalMbSendLaneIdPatternSeen = false
      var mbinitReversalMbLaneIdPatternWaitCycles = -1
      var mbinitReversalMbFinishedLaneIdPatternHigh = false
      var mbinitReversalMbResultReqSeen = false
      var mbinitReversalMbResultRespHeaderSent = false
      var mbinitReversalMbResultRespPayloadSent = false
      var mbinitReversalMbResultRespPayloadGap = 0
      var mbinitReversalMbDoneReqSeen = false
      var mbinitReversalMbDoneRespSent = false
      var mbinitReversalMbDoneRespPending = false

      // MBINIT_REVERSALMB receiver path (peer initiates, DUT responds)
      var mbinitReversalMbPeerInitReqSent = false
      var mbinitReversalMbPeerInitRespSeen = false
      var mbinitReversalMbPeerClearErrorReqSent = false
      var mbinitReversalMbPeerClearErrorRespSeen = false
      var mbinitReversalMbPeerPostClearWaitCycles = -1
      var mbinitReversalMbPeerAllLaneFlagsHigh = false
      var mbinitReversalMbPeerPostLaneFlagsWaitCycles = -1
      var mbinitReversalMbPeerResultReqSent = false
      var mbinitReversalMbPeerResultRespHeaderSeen = false
      var mbinitReversalMbPeerResultRespPayloadSeen = false
      var mbinitReversalMbPeerResultRespPayloadAllOnes = false
      var mbinitReversalMbPeerExpectResultPayload = false
      var mbinitReversalMbPeerResultRespStrictOrderOk = true
      var mbinitReversalMbPeerDoneReqSent = false
      var mbinitReversalMbPeerDoneRespSeen = false
      var prevRxValidWasHigh = false

      // MBINIT_REPAIRMB sender path (DUT initiates, peer responds)
      var mbinitRepairMbStartReqSeen = false
      var mbinitRepairMbStartRespSent = false
      var mbinitRepairMbD2CPointTestReqHeaderSeen = false
      var mbinitRepairMbD2CPointTestReqPayloadSeen = false
      var mbinitRepairMbD2CPointTestRespSent = false
      var mbinitRepairMbLfsrClearErrorReqSeen = false
      var mbinitRepairMbLfsrClearErrorRespSent = false
      var mbinitRepairMbSendLaneIdPatternSeen = false
      var mbinitRepairMbLaneIdPatternWaitCycles = -1
      var mbinitRepairMbFinishedLaneIdPatternHigh = false
      var mbinitRepairMbTxInitD2CResultsReqSeen = false
      var mbinitRepairMbTxInitD2CResultsRespHeaderSent = false
      var mbinitRepairMbTxInitD2CResultsRespPayloadSent = false
      var mbinitRepairMbEndTxInitD2CPointTestReqSeen = false
      var mbinitRepairMbEndTxInitD2CPointTestRespSent = false
      var mbinitRepairMbApplyDegradeReqSeen = false
      var mbinitRepairMbApplyDegradeRespSent = false
      var mbinitRepairMbEndReqSeen = false
      var mbinitRepairMbEndRespSent = false
      // MBINIT_REPAIRMB receiver path (peer initiates, DUT responds)
      var mbinitRepairMbPeerStartReqSent = false
      var mbinitRepairMbPeerStartRespSeen = false
      var mbinitRepairMbPeerD2CReqHeaderSent = false
      var mbinitRepairMbPeerD2CReqPayloadSent = false
      var mbinitRepairMbPeerSetReceiverSeen = false
      var mbinitRepairMbPeerD2CRespSeen = false
      var mbinitRepairMbPeerLfsrReqSent = false
      var mbinitRepairMbPeerLfsrRespSeen = false
      var mbinitRepairMbPeerPostLfsrWaitCycles = -1
      var mbinitRepairMbPeerDetectedLaneBitsHigh = false
      var mbinitRepairMbPeerPostDetectedWaitCycles = -1
      var mbinitRepairMbPeerTxInitReqSent = false
      var mbinitRepairMbPeerTxInitRespHeaderSeen = false
      var mbinitRepairMbPeerTxInitRespPayloadSeen = false
      var mbinitRepairMbPeerExpectTxInitRespPayload = false
      var mbinitRepairMbPeerEndTxReqSent = false
      var mbinitRepairMbPeerEndTxRespSeen = false
      var mbinitRepairMbPeerApplyDegradeReqSent = false

      while (cycle < 250) {//450
        // -----------------------------------------------------------------------------
        // Per-cycle defaults (safe baseline)
        // -----------------------------------------------------------------------------
        // Start every cycle with no RX traffic, then selectively drive one RX word
        // depending on current state/substate and handshake progress.
        c.io.sb_rx_valid.poke(false.B)
        c.io.sb_rx_dout.poke(0.U)
        c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(false.B)
        c.io.flagFromAnalog_FinishedClkPatterns.poke(false.B)
        c.io.flagFromAnalog_FinishedValTrainPattern.poke(false.B)
        c.io.flagFromAnalog_ReversalMbFinishedLaneIDPattern.poke(false.B)
        c.io.flagFromAnalog_RepairMbFinishedLaneIDPattern.poke(false.B)
        c.io.flagFromAnalog_clkPatternReceivedRTRK_L.poke(mbinitRepairClkPeerRTRKHigh.B)
        c.io.flagFromAnalog_clkPatternReceivedRCKN_L.poke(mbinitRepairClkPeerRCKNHigh.B)
        c.io.flagFromAnalog_clkPatternReceivedRCKP_L.poke(mbinitRepairClkPeerRCKPHigh.B)
        c.io.flagFromAnalog_ValTrainPatternReceived.poke(mbinitRepairValPeerValTrainPatternReceivedHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived0.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived1.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived2.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived3.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived4.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived5.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived6.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived7.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived8.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived9.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived10.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived11.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived12.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived13.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived14.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_ReversalMbTrainPatternReceived15.poke(mbinitReversalMbPeerAllLaneFlagsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern0.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern1.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern2.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern3.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern4.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern5.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern6.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern7.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern8.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern9.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern10.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern11.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern12.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern13.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern14.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)
        c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern15.poke(mbinitRepairMbPeerDetectedLaneBitsHigh.B)

        // Keep analog status pins high once their corresponding internal conditions
        // have been reached in the software peer model.
        if (mbinitRepairClkReadyHigh) {
          c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(true.B)
        }
        if (mbinitRepairClkFinishedHigh) {
          c.io.flagFromAnalog_FinishedClkPatterns.poke(true.B)
        }
        if (mbinitRepairValFinishedHigh) {
          c.io.flagFromAnalog_FinishedValTrainPattern.poke(true.B)
        }
        if (mbinitReversalMbFinishedLaneIdPatternHigh) {
          c.io.flagFromAnalog_ReversalMbFinishedLaneIDPattern.poke(true.B)
        }
        if (mbinitRepairMbFinishedLaneIdPatternHigh) {
          c.io.flagFromAnalog_RepairMbFinishedLaneIDPattern.poke(true.B)
        }

        // Global anti-back-to-back policy:
        // do not drive sb_rx_valid high in two consecutive cycles.
        // This mimics spacing constraints and avoids edge-detection races.
        val canSendRxThisCycle = !prevRxValidWasHigh
        var rxSentThisCycle = false

        // -----------------------------------------------------------------------------
        // Reset / bring-up window
        // -----------------------------------------------------------------------------
        // Hold reset and all controls low for first 3 cycles, then release reset and
        // drive static prerequisites to allow LT progression out of RESET.
        if (cycle < 3) {
          c.reset.poke(true.B)
          c.io.start.poke(false.B)
          c.io.stable_clk.poke(false.B)
          c.io.pll_locked.poke(false.B)
          c.io.stable_supply.poke(false.B)
          c.io.sb_tx_ready.poke(false.B)
          c.io.flagFromAnalog_ReadyToExchangeClkPatterns.poke(false.B)
          c.io.flagFromAnalog_FinishedClkPatterns.poke(false.B)
          c.io.flagFromAnalog_FinishedValTrainPattern.poke(false.B)
          c.io.flagFromAnalog_ReversalMbFinishedLaneIDPattern.poke(false.B)
          c.io.flagFromAnalog_RepairMbFinishedLaneIDPattern.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRTRK_L.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRCKN_L.poke(false.B)
          c.io.flagFromAnalog_clkPatternReceivedRCKP_L.poke(false.B)
          c.io.flagFromAnalog_ValTrainPatternReceived.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived0.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived1.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived2.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived3.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived4.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived5.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived6.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived7.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived8.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived9.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived10.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived11.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived12.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived13.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived14.poke(false.B)
          c.io.flagFromAnalog_ReversalMbTrainPatternReceived15.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern0.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern1.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern2.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern3.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern4.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern5.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern6.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern7.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern8.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern9.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern10.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern11.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern12.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern13.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern14.poke(false.B)
          c.io.flagFromAnalog_RepairMbDetectedLaneIDPattern15.poke(false.B)
          mbinitRepairClkPeerRTRKHigh = false
          mbinitRepairClkPeerRCKNHigh = false
          mbinitRepairClkPeerRCKPHigh = false
          mbinitRepairValPeerValTrainPatternReceivedHigh = false
          mbinitReversalMbPeerAllLaneFlagsHigh = false
        } else {
          c.reset.poke(false.B)
          c.io.start.poke(true.B)
          c.io.stable_clk.poke(true.B)
          c.io.pll_locked.poke(true.B)
          c.io.stable_supply.poke(true.B)
          c.io.sb_tx_ready.poke(true.B)
        }

        // Snapshot current LT state and MBINIT substate for this cycle's decisions.
        val stateVal = c.io.state.peek().litValue.toInt
        val mbinitSubstateVal = c.io.dbg_mbinitSubstate.peek().litValue.toInt

        // -----------------------------------------------------------------------------
        // SBINIT_pattern
        // -----------------------------------------------------------------------------
        // Drive two valid clock patterns separated by a programmed gap.
        // This reproduces expected detection behavior in the DUT.
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

        // -----------------------------------------------------------------------------
        // SBINIT_OORmsg
        // -----------------------------------------------------------------------------
        // Echo the out-of-reset success message once.
        if (stateVal == SBINIT_OORmsg && !successSent) {
          if (canSendRxThisCycle) {
            c.io.sb_rx_dout.poke(successMsg.U)
            c.io.sb_rx_valid.poke(true.B)
            successSent = true
            rxSentThisCycle = true
          }
        }

        // -----------------------------------------------------------------------------
        // SBINIT_DONEmsg
        // -----------------------------------------------------------------------------
        // Peer sends DONE_REQ, waits for DUT DONE_RESP visibility, then returns DONE_RESP.
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

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + PARAM substate
        // -----------------------------------------------------------------------------
        // Full bi-directional req/resp exchange with explicit payload staging and
        // inter-message spacing to avoid back-to-back valid pulses.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_PARAM) {
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

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + CAL substate
        // -----------------------------------------------------------------------------
        // DONE handshake with ordered req then resp behavior and gap control.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_Cal) {
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

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + REPAIRCLK substate
        // -----------------------------------------------------------------------------
        // Sender path (DUT initiates) and receiver path (peer initiates) run in parallel.
        // The test tracks and services both, while driving analog pin progression.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_REPAIRCLK) {
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

          // Keep ReadyToExchange high across the whole REPAIRCLK phase so both paths
          // can make forward progress without artificial blocking.
          mbinitRepairClkReadyHigh = true

          // Sender-path responses: peer answers DUT-generated INIT/RESULT/DONE requests.
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

          // Receiver-path requests: peer independently initiates INIT->RESULT->DONE while
          // DUT sender path is active, validating true duplex behavior.
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

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + REPAIRVAL substate
        // -----------------------------------------------------------------------------
        // Similar parallel sender/receiver orchestration as REPAIRCLK, but using
        // ValTrain-specific analog done and result semantics.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_REPAIRVAL) {
          var rxWordValid = false
          var rxWord = BigInt(0)

          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue
            if (!mbinitRepairValInitReqSeen && txWord == mbinitRepairValInitReqWord) {
              mbinitRepairValInitReqSeen = true
            }
            if (!mbinitRepairValResultReqSeen && txWord == mbinitRepairValResultReqWord) {
              mbinitRepairValResultReqSeen = true
            }
            if (!mbinitRepairValDoneReqSeen && txWord == mbinitRepairValDoneReqWord) {
              mbinitRepairValDoneReqSeen = true
            }

            if (!mbinitRepairValPeerInitRespSeen && txWord == mbinitRepairValInitRespWord) {
              mbinitRepairValPeerInitRespSeen = true
            }
            if (!mbinitRepairValPeerResultRespSeen && txWord == mbinitRepairValResultRespWord) {
              mbinitRepairValPeerResultRespSeen = true
            }
            if (!mbinitRepairValPeerDoneRespSeen && txWord == mbinitRepairValDoneRespWord) {
              mbinitRepairValPeerDoneRespSeen = true
            }
          }

          // Sender-path responses: peer acknowledges DUT's INIT/RESULT/DONE sequence.
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairValInitReqSeen && !mbinitRepairValInitRespSent) {
            rxWord = mbinitRepairValInitRespWord
            rxWordValid = true
            mbinitRepairValInitRespSent = true
          }

          if (!mbinitRepairValSendPatternSeen && c.io.flagToAnalog_SendValTrainPattern.peek().litToBoolean) {
            mbinitRepairValSendPatternSeen = true
            mbinitRepairValPatternWaitCycles = 7
          }

          if (mbinitRepairValSendPatternSeen && !mbinitRepairValFinishedHigh) {
            if (mbinitRepairValPatternWaitCycles > 0) {
              mbinitRepairValPatternWaitCycles -= 1
            } else {
              mbinitRepairValFinishedHigh = true
              mbinitRepairValPeerValTrainPatternReceivedHigh = true
            }
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairValResultReqSeen && !mbinitRepairValResultRespSent) {
            rxWord = mbinitRepairValResultRespWord
            rxWordValid = true
            mbinitRepairValResultRespSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairValDoneReqSeen && !mbinitRepairValDoneRespSent) {
            rxWord = mbinitRepairValDoneRespWord
            rxWordValid = true
            mbinitRepairValDoneRespSent = true
          }

          // Receiver-path requests: peer starts its own REPAIRVAL flow in parallel.
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && !mbinitRepairValPeerInitReqSent) {
            rxWord = mbinitRepairValInitReqWord
            rxWordValid = true
            mbinitRepairValPeerInitReqSent = true
          }

          if (mbinitRepairValPeerInitRespSeen) {
            mbinitRepairValPeerValTrainPatternReceivedHigh = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairValPeerInitRespSeen && !mbinitRepairValPeerResultReqSent) {
            rxWord = mbinitRepairValResultReqWord
            rxWordValid = true
            mbinitRepairValPeerResultReqSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairValPeerResultRespSeen && !mbinitRepairValPeerDoneReqSent) {
            rxWord = mbinitRepairValDoneReqWord
            rxWordValid = true
            mbinitRepairValPeerDoneReqSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && rxWordValid) {
            c.io.sb_rx_dout.poke(rxWord.U)
            c.io.sb_rx_valid.poke(true.B)
            rxSentThisCycle = true
          }
        }

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + REVERSALMB substate
        // -----------------------------------------------------------------------------
        // Full duplex REVERSALMB coverage:
        // 1) Sender path: DUT initiates INIT/CLEAR_ERROR/RESULT/DONE and peer responds.
        // 2) Receiver path: peer initiates exact requested sequence and validates payload.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_REVERSALMB) {
          var rxWordValid = false
          var rxWord = BigInt(0)

          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue

            // Sender path observation (DUT -> peer)
            if (!mbinitReversalMbInitReqSeen && txWord == mbinitReversalMbInitReqWord) {
              mbinitReversalMbInitReqSeen = true
            }
            if (!mbinitReversalMbClearErrorReqSeen && txWord == mbinitReversalMbClearErrorReqWord) {
              mbinitReversalMbClearErrorReqSeen = true
              mbinitReversalMbClearErrorRespPending = true
            }
            if (!mbinitReversalMbResultReqSeen && txWord == mbinitReversalMbResultReqWord) {
              mbinitReversalMbResultReqSeen = true
            }
            if (!mbinitReversalMbDoneReqSeen && txWord == mbinitReversalMbDoneReqWord) {
              mbinitReversalMbDoneReqSeen = true
              mbinitReversalMbDoneRespPending = true
            }

            // Receiver path observation (DUT responses to peer-initiated requests)
            if (!mbinitReversalMbPeerInitRespSeen && txWord == mbinitReversalMbInitRespWord) {
              mbinitReversalMbPeerInitRespSeen = true
            }
            if (!mbinitReversalMbPeerClearErrorRespSeen && txWord == mbinitReversalMbClearErrorRespWord) {
              mbinitReversalMbPeerClearErrorRespSeen = true
            }
            if (!mbinitReversalMbPeerResultRespHeaderSeen && txWord == mbinitReversalMbResultRespHeaderWord) {
              mbinitReversalMbPeerResultRespHeaderSeen = true
              mbinitReversalMbPeerExpectResultPayload = true
            } else if (
              mbinitReversalMbPeerExpectResultPayload &&
              !mbinitReversalMbPeerResultRespPayloadSeen
            ) {
              if (txWord == mbinitReversalMbResultRespPayloadWord) {
                mbinitReversalMbPeerResultRespPayloadSeen = true
                mbinitReversalMbPeerResultRespPayloadAllOnes = true
                mbinitReversalMbPeerExpectResultPayload = false
              } else {
                mbinitReversalMbPeerResultRespStrictOrderOk = false
              }
            }
            if (!mbinitReversalMbPeerDoneRespSeen && txWord == mbinitReversalMbDoneRespWord) {
              mbinitReversalMbPeerDoneRespSeen = true
            }
          }

          // Sender path peer responses
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitReversalMbDoneRespPending && !mbinitReversalMbDoneRespSent) {
            rxWord = mbinitReversalMbDoneRespWord
            rxWordValid = true
            mbinitReversalMbDoneRespSent = true
            mbinitReversalMbDoneRespPending = false
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitReversalMbClearErrorRespPending && !mbinitReversalMbClearErrorRespSent) {
            rxWord = mbinitReversalMbClearErrorRespWord
            rxWordValid = true
            mbinitReversalMbClearErrorRespSent = true
            mbinitReversalMbClearErrorRespPending = false
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitReversalMbInitReqSeen && !mbinitReversalMbInitRespSent) {
            rxWord = mbinitReversalMbInitRespWord
            rxWordValid = true
            mbinitReversalMbInitRespSent = true
          }

          if (!mbinitReversalMbSendLaneIdPatternSeen && c.io.flagToAnalog_ReversalMbSendLaneIDPattern.peek().litToBoolean) {
            mbinitReversalMbSendLaneIdPatternSeen = true
            mbinitReversalMbLaneIdPatternWaitCycles = 7
          }

          if (mbinitReversalMbSendLaneIdPatternSeen && !mbinitReversalMbFinishedLaneIdPatternHigh) {
            if (mbinitReversalMbLaneIdPatternWaitCycles > 0) {
              mbinitReversalMbLaneIdPatternWaitCycles -= 1
            } else {
              mbinitReversalMbFinishedLaneIdPatternHigh = true
            }
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitReversalMbResultReqSeen && !mbinitReversalMbResultRespHeaderSent) {
            rxWord = mbinitReversalMbResultRespHeaderWord
            rxWordValid = true
            mbinitReversalMbResultRespHeaderSent = true
            mbinitReversalMbResultRespPayloadGap = 0
          } else if (mbinitReversalMbResultRespHeaderSent && !mbinitReversalMbResultRespPayloadSent) {
            if (mbinitReversalMbResultRespPayloadGap > 0) {
              mbinitReversalMbResultRespPayloadGap -= 1
            } else {
              if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid) {
                rxWord = mbinitReversalMbResultRespPayloadWord
                rxWordValid = true
                mbinitReversalMbResultRespPayloadSent = true
              }
            }
          }

          // Receiver path peer requests
          // Requested sequence:
          // init req -> wait init resp -> clear error req -> wait clear error resp
          // -> wait 5 cycles -> set 16 lane flags high -> wait 5 cycles
          // -> result req -> wait result resp + payload all ones -> done req -> wait done resp.
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && !mbinitReversalMbPeerInitReqSent) {
            rxWord = mbinitReversalMbInitReqWord
            rxWordValid = true
            mbinitReversalMbPeerInitReqSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitReversalMbPeerInitRespSeen && !mbinitReversalMbPeerClearErrorReqSent) {
            rxWord = mbinitReversalMbClearErrorReqWord
            rxWordValid = true
            mbinitReversalMbPeerClearErrorReqSent = true
          }

          if (mbinitReversalMbPeerClearErrorRespSeen && !mbinitReversalMbPeerAllLaneFlagsHigh) {
            if (mbinitReversalMbPeerPostClearWaitCycles < 0) {
              mbinitReversalMbPeerPostClearWaitCycles = 5
            } else if (mbinitReversalMbPeerPostClearWaitCycles > 0) {
              mbinitReversalMbPeerPostClearWaitCycles -= 1
            } else {
              mbinitReversalMbPeerAllLaneFlagsHigh = true
              mbinitReversalMbPeerPostLaneFlagsWaitCycles = 5
            }
          }

          if (
            mbinitReversalMbPeerAllLaneFlagsHigh &&
            !mbinitReversalMbPeerResultReqSent &&
            mbinitReversalMbPeerPostLaneFlagsWaitCycles >= 0
          ) {
            if (mbinitReversalMbPeerPostLaneFlagsWaitCycles > 0) {
              mbinitReversalMbPeerPostLaneFlagsWaitCycles -= 1
            } else if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid) {
              rxWord = mbinitReversalMbResultReqWord
              rxWordValid = true
              mbinitReversalMbPeerResultReqSent = true
            }
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitReversalMbPeerResultRespHeaderSeen &&
            mbinitReversalMbPeerResultRespPayloadSeen &&
            mbinitReversalMbPeerResultRespPayloadAllOnes &&
            !mbinitReversalMbPeerDoneReqSent
          ) {
            rxWord = mbinitReversalMbDoneReqWord
            rxWordValid = true
            mbinitReversalMbPeerDoneReqSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && rxWordValid) {
            c.io.sb_rx_dout.poke(rxWord.U)
            c.io.sb_rx_valid.poke(true.B)
            rxSentThisCycle = true
          }
        }

        // -----------------------------------------------------------------------------
        // MBINIT_SUPER + REPAIRMB substate
        // -----------------------------------------------------------------------------
        // Sequence covered:
        // start req/resp -> d2c req header+payload/resp -> lfsr clear req/resp
        // -> lane ID pattern cmd + wait 10 cycles + finished high
        // -> tx init d2c results req -> results resp (header + payload FFFF)
        // -> end tx init d2c point test req/resp.
        // Also responds to apply-degrade and end requests so LT can progress to ACTIVE.
        if (stateVal == MBINIT_SUPER && mbinitSubstateVal == MBINIT_REPAIRMB) {
          var rxWordValid = false
          var rxWord = BigInt(0)

          if (c.io.sb_tx_valid.peek().litToBoolean) {
            val txWord = c.io.sb_tx_din.peek().litValue
            if (!mbinitRepairMbStartReqSeen && txWord == mbinitRepairMbStartReqWord) {
              mbinitRepairMbStartReqSeen = true
            }
            if (!mbinitRepairMbD2CPointTestReqHeaderSeen && txWord == mbinitRepairMbD2CPointTestReqHeaderWord) {
              mbinitRepairMbD2CPointTestReqHeaderSeen = true
            } else if (
              mbinitRepairMbD2CPointTestReqHeaderSeen &&
              !mbinitRepairMbD2CPointTestReqPayloadSeen &&
              txWord == mbinitRepairMbD2CPointTestReqPayloadWord
            ) {
              mbinitRepairMbD2CPointTestReqPayloadSeen = true
            }
            if (!mbinitRepairMbLfsrClearErrorReqSeen && txWord == mbinitRepairMbLfsrClearErrorReqWord) {
              mbinitRepairMbLfsrClearErrorReqSeen = true
            }
            if (!mbinitRepairMbTxInitD2CResultsReqSeen && txWord == mbinitRepairMbTxInitD2CResultsReqWord) {
              mbinitRepairMbTxInitD2CResultsReqSeen = true
            }
            if (!mbinitRepairMbEndTxInitD2CPointTestReqSeen && txWord == mbinitRepairMbEndTxInitD2CPointTestReqWord) {
              mbinitRepairMbEndTxInitD2CPointTestReqSeen = true
            }
            if (
              !mbinitRepairMbApplyDegradeReqSeen &&
              (txWord == mbinitRepairMbApplyDegradeReq011Word || txWord == mbinitRepairMbApplyDegradeReq000Word)
            ) {
              mbinitRepairMbApplyDegradeReqSeen = true
            }
            if (!mbinitRepairMbEndReqSeen && txWord == mbinitRepairMbEndReqWord) {
              mbinitRepairMbEndReqSeen = true
            }

            if (
              !mbinitRepairMbPeerStartRespSeen &&
              mbinitRepairMbPeerStartReqSent &&
              txWord == mbinitRepairMbStartRespWord
            ) {
              mbinitRepairMbPeerStartRespSeen = true
            }
            if (
              !mbinitRepairMbPeerD2CRespSeen &&
              mbinitRepairMbPeerD2CReqPayloadSent &&
              txWord == mbinitRepairMbD2CPointTestRespWord
            ) {
              mbinitRepairMbPeerD2CRespSeen = true
            }
            if (
              !mbinitRepairMbPeerLfsrRespSeen &&
              mbinitRepairMbPeerLfsrReqSent &&
              txWord == mbinitRepairMbLfsrClearErrorRespWord
            ) {
              mbinitRepairMbPeerLfsrRespSeen = true
            }
            if (
              !mbinitRepairMbPeerTxInitRespHeaderSeen &&
              mbinitRepairMbPeerTxInitReqSent &&
              txWord == mbinitRepairMbTxInitD2CResultsRespHeaderWord
            ) {
              // the correct lane should be checked in the time diagram
              mbinitRepairMbPeerTxInitRespHeaderSeen = true
              mbinitRepairMbPeerExpectTxInitRespPayload = true
            } else if (
              mbinitRepairMbPeerExpectTxInitRespPayload &&
              !mbinitRepairMbPeerTxInitRespPayloadSeen &&
              txWord == mbinitRepairMbTxInitD2CResultsRespPayloadWord
            ) {
              mbinitRepairMbPeerTxInitRespPayloadSeen = true
              mbinitRepairMbPeerExpectTxInitRespPayload = false
            }
            if (
              !mbinitRepairMbPeerEndTxRespSeen &&
              mbinitRepairMbPeerEndTxReqSent &&
              txWord == mbinitRepairMbEndTxInitD2CPointTestRespWord
            ) {
              mbinitRepairMbPeerEndTxRespSeen = true
            }
          }

          if (!mbinitRepairMbPeerSetReceiverSeen && c.io.flagToAnalog_RepairMbSetReceiver.peek().litToBoolean) {
            mbinitRepairMbPeerSetReceiverSeen = true
          }

          if (mbinitRepairMbPeerLfsrRespSeen && !mbinitRepairMbPeerDetectedLaneBitsHigh) {
            if (mbinitRepairMbPeerPostLfsrWaitCycles < 0) {
              mbinitRepairMbPeerPostLfsrWaitCycles = 5
            } else if (mbinitRepairMbPeerPostLfsrWaitCycles > 0) {
              mbinitRepairMbPeerPostLfsrWaitCycles -= 1
            } else {
              mbinitRepairMbPeerDetectedLaneBitsHigh = true
              mbinitRepairMbPeerPostDetectedWaitCycles = 5
            }
          }

          if (
            mbinitRepairMbPeerDetectedLaneBitsHigh &&
            !mbinitRepairMbPeerTxInitReqSent &&
            mbinitRepairMbPeerPostDetectedWaitCycles >= 0
          ) {
            if (mbinitRepairMbPeerPostDetectedWaitCycles > 0) {
              mbinitRepairMbPeerPostDetectedWaitCycles -= 1
            }
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairMbStartReqSeen && !mbinitRepairMbStartRespSent) {
            rxWord = mbinitRepairMbStartRespWord
            rxWordValid = true
            mbinitRepairMbStartRespSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbD2CPointTestReqPayloadSeen && !mbinitRepairMbD2CPointTestRespSent
          ) {
            rxWord = mbinitRepairMbD2CPointTestRespWord
            rxWordValid = true
            mbinitRepairMbD2CPointTestRespSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairMbLfsrClearErrorReqSeen && !mbinitRepairMbLfsrClearErrorRespSent) {
            rxWord = mbinitRepairMbLfsrClearErrorRespWord
            rxWordValid = true
            mbinitRepairMbLfsrClearErrorRespSent = true
          }

          if (!mbinitRepairMbSendLaneIdPatternSeen && c.io.flagToAnalog_RepairMbSendLaneIDPattern.peek().litToBoolean) {
            mbinitRepairMbSendLaneIdPatternSeen = true
            mbinitRepairMbLaneIdPatternWaitCycles = 10
          }

          if (mbinitRepairMbSendLaneIdPatternSeen && !mbinitRepairMbFinishedLaneIdPatternHigh) {
            if (mbinitRepairMbLaneIdPatternWaitCycles > 0) {
              mbinitRepairMbLaneIdPatternWaitCycles -= 1
            } else {
              mbinitRepairMbFinishedLaneIdPatternHigh = true
            }
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbTxInitD2CResultsReqSeen && !mbinitRepairMbTxInitD2CResultsRespHeaderSent
          ) {
            rxWord = mbinitRepairMbTxInitD2CResultsRespHeaderWord
            rxWordValid = true
            mbinitRepairMbTxInitD2CResultsRespHeaderSent = true
          } else if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbTxInitD2CResultsRespHeaderSent && !mbinitRepairMbTxInitD2CResultsRespPayloadSent
          ) {
            rxWord = mbinitRepairMbTxInitD2CResultsRespPayloadWord
            rxWordValid = true
            mbinitRepairMbTxInitD2CResultsRespPayloadSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairMbEndTxInitD2CPointTestReqSeen && !mbinitRepairMbEndTxInitD2CPointTestRespSent) {
            rxWord = mbinitRepairMbEndTxInitD2CPointTestRespWord
            rxWordValid = true
            mbinitRepairMbEndTxInitD2CPointTestRespSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairMbApplyDegradeReqSeen && !mbinitRepairMbApplyDegradeRespSent) {
            rxWord = mbinitRepairMbApplyDegradeRespWord
            rxWordValid = true
            mbinitRepairMbApplyDegradeRespSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && mbinitRepairMbEndReqSeen && !mbinitRepairMbEndRespSent) {
            rxWord = mbinitRepairMbEndRespWord
            rxWordValid = true
            mbinitRepairMbEndRespSent = true
          }

          // Receiver-path sequence:
          // 1) send start req
          // 2) wait start resp
          // 3) send d2c point test req (header then payload)
          // 4) check flagToAnalog_RepairMbSetReceiver
          // 5) wait d2c point test resp
          // 6) send lfsr clear error req
          // 7) wait lfsr clear error resp
          // 8) wait 5 cycles
          // 9) set RepairMbDetectedLaneIDPattern[15:0] high
          // 10) wait 5 cycles
          // 11) send tx init d2c results req
          // 12) wait tx init d2c results resp (header + payload)
          // 13) send end tx init d2c point test req
          // 14) wait end tx init d2c point test resp
          if (canSendRxThisCycle && !rxSentThisCycle && !rxWordValid && !mbinitRepairMbPeerStartReqSent) {
            rxWord = mbinitRepairMbStartReqWord
            rxWordValid = true
            mbinitRepairMbPeerStartReqSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerStartRespSeen && !mbinitRepairMbPeerD2CReqHeaderSent
          ) {
            rxWord = mbinitRepairMbD2CPointTestReqHeaderWord
            rxWordValid = true
            mbinitRepairMbPeerD2CReqHeaderSent = true
          } else if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerD2CReqHeaderSent && !mbinitRepairMbPeerD2CReqPayloadSent
          ) {
            rxWord = mbinitRepairMbD2CPointTestReqPayloadWord
            rxWordValid = true
            mbinitRepairMbPeerD2CReqPayloadSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerD2CRespSeen && !mbinitRepairMbPeerLfsrReqSent
          ) {
            rxWord = mbinitRepairMbLfsrClearErrorReqWord
            rxWordValid = true
            mbinitRepairMbPeerLfsrReqSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerDetectedLaneBitsHigh &&
            mbinitRepairMbPeerPostDetectedWaitCycles == 0 &&
            !mbinitRepairMbPeerTxInitReqSent
          ) {
            rxWord = mbinitRepairMbTxInitD2CResultsReqWord
            rxWordValid = true
            mbinitRepairMbPeerTxInitReqSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerTxInitRespHeaderSeen &&
            mbinitRepairMbPeerTxInitRespPayloadSeen &&
            !mbinitRepairMbPeerEndTxReqSent
          ) {
            rxWord = mbinitRepairMbEndTxInitD2CPointTestReqWord
            rxWordValid = true
            mbinitRepairMbPeerEndTxReqSent = true
          }

          if (
            canSendRxThisCycle && !rxSentThisCycle && !rxWordValid &&
            mbinitRepairMbPeerEndTxRespSeen &&
            !mbinitRepairMbPeerApplyDegradeReqSent
          ) {
            rxWord = mbinitRepairMbApplyDegradeReq011Word
            rxWordValid = true
            mbinitRepairMbPeerApplyDegradeReqSent = true
          }

          if (canSendRxThisCycle && !rxSentThisCycle && rxWordValid) {
            c.io.sb_rx_dout.poke(rxWord.U)
            c.io.sb_rx_valid.poke(true.B)
            rxSentThisCycle = true
          }
        }

        // Remember whether we drove rx_valid this cycle to enforce one-cycle low spacing
        // on the next iteration.
        prevRxValidWasHigh = rxSentThisCycle

        // advance one cycle
        c.clock.step(1)
        cycle += 1
      }

      // ---------------------------------------------------------------------------------
      // End-of-test checks
      // ---------------------------------------------------------------------------------
      // 1) Top FSM reached ACTIVE.
      // 2) All expected handshake milestones across SBINIT + MBINIT substates occurred.
      assert(
        c.io.state.peek().litValue == ACTIVE,
        s"Timeout after $cycle cycles: LT FSM did not reach ACTIVE (state=${c.io.state.peek().litValue}, substate=${c.io.dbg_mbinitSubstate.peek().litValue}) | " +
          s"REV_S(sender): initReqSeen=$mbinitReversalMbInitReqSeen initRespSent=$mbinitReversalMbInitRespSent clearReqSeen=$mbinitReversalMbClearErrorReqSeen clearRespSent=$mbinitReversalMbClearErrorRespSent laneCmdSeen=$mbinitReversalMbSendLaneIdPatternSeen laneDoneHigh=$mbinitReversalMbFinishedLaneIdPatternHigh resultReqSeen=$mbinitReversalMbResultReqSeen resultHdrSent=$mbinitReversalMbResultRespHeaderSent resultPayloadSent=$mbinitReversalMbResultRespPayloadSent doneReqSeen=$mbinitReversalMbDoneReqSeen doneRespSent=$mbinitReversalMbDoneRespSent | " +
            s"REPAIRMB: startReqSeen=$mbinitRepairMbStartReqSeen startRespSent=$mbinitRepairMbStartRespSent d2cHdrSeen=$mbinitRepairMbD2CPointTestReqHeaderSeen d2cPayloadSeen=$mbinitRepairMbD2CPointTestReqPayloadSeen d2cRespSent=$mbinitRepairMbD2CPointTestRespSent lfsrReqSeen=$mbinitRepairMbLfsrClearErrorReqSeen lfsrRespSent=$mbinitRepairMbLfsrClearErrorRespSent laneCmdSeen=$mbinitRepairMbSendLaneIdPatternSeen laneDoneHigh=$mbinitRepairMbFinishedLaneIdPatternHigh txInitReqSeen=$mbinitRepairMbTxInitD2CResultsReqSeen txInitRespHdrSent=$mbinitRepairMbTxInitD2CResultsRespHeaderSent txInitRespPayloadSent=$mbinitRepairMbTxInitD2CResultsRespPayloadSent endTxReqSeen=$mbinitRepairMbEndTxInitD2CPointTestReqSeen endTxRespSent=$mbinitRepairMbEndTxInitD2CPointTestRespSent applyReqSeen=$mbinitRepairMbApplyDegradeReqSeen applyRespSent=$mbinitRepairMbApplyDegradeRespSent endReqSeen=$mbinitRepairMbEndReqSeen endRespSent=$mbinitRepairMbEndRespSent | " +
            s"REPAIRMB_R(receiver): startReqSent=$mbinitRepairMbPeerStartReqSent startRespSeen=$mbinitRepairMbPeerStartRespSeen d2cHdrSent=$mbinitRepairMbPeerD2CReqHeaderSent d2cPayloadSent=$mbinitRepairMbPeerD2CReqPayloadSent setReceiverSeen=$mbinitRepairMbPeerSetReceiverSeen d2cRespSeen=$mbinitRepairMbPeerD2CRespSeen lfsrReqSent=$mbinitRepairMbPeerLfsrReqSent lfsrRespSeen=$mbinitRepairMbPeerLfsrRespSeen laneBitsHigh=$mbinitRepairMbPeerDetectedLaneBitsHigh txInitReqSent=$mbinitRepairMbPeerTxInitReqSent txInitRespHdrSeen=$mbinitRepairMbPeerTxInitRespHeaderSeen txInitRespPayloadSeen=$mbinitRepairMbPeerTxInitRespPayloadSeen endTxReqSent=$mbinitRepairMbPeerEndTxReqSent endTxRespSeen=$mbinitRepairMbPeerEndTxRespSeen applyDegradeReqSent=$mbinitRepairMbPeerApplyDegradeReqSent | " +
            s"REV_R(receiver): initReqSent=$mbinitReversalMbPeerInitReqSent initRespSeen=$mbinitReversalMbPeerInitRespSeen clearReqSent=$mbinitReversalMbPeerClearErrorReqSent clearRespSeen=$mbinitReversalMbPeerClearErrorRespSeen laneFlagsHigh=$mbinitReversalMbPeerAllLaneFlagsHigh resultReqSent=$mbinitReversalMbPeerResultReqSent resultHdrSeen=$mbinitReversalMbPeerResultRespHeaderSeen resultPayloadSeen=$mbinitReversalMbPeerResultRespPayloadSeen payloadAllOnes=$mbinitReversalMbPeerResultRespPayloadAllOnes strictOrderOk=$mbinitReversalMbPeerResultRespStrictOrderOk doneReqSent=$mbinitReversalMbPeerDoneReqSent doneRespSeen=$mbinitReversalMbPeerDoneRespSeen"
      )
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
        mbinitRepairClkPeerDoneReqSent && mbinitRepairClkPeerDoneRespSeen &&
        mbinitRepairValInitReqSeen && mbinitRepairValInitRespSent &&
        mbinitRepairValSendPatternSeen && mbinitRepairValFinishedHigh &&
        mbinitRepairValResultReqSeen && mbinitRepairValResultRespSent &&
        mbinitRepairValDoneReqSeen && mbinitRepairValDoneRespSent &&
        mbinitRepairValPeerInitReqSent && mbinitRepairValPeerInitRespSeen &&
        mbinitRepairValPeerResultReqSent && mbinitRepairValPeerResultRespSeen &&
        mbinitRepairValPeerDoneReqSent && mbinitRepairValPeerDoneRespSeen &&
        mbinitReversalMbInitReqSeen && mbinitReversalMbInitRespSent &&
        mbinitReversalMbClearErrorReqSeen && mbinitReversalMbClearErrorRespSent &&
        mbinitReversalMbSendLaneIdPatternSeen && mbinitReversalMbFinishedLaneIdPatternHigh &&
        mbinitReversalMbResultReqSeen && mbinitReversalMbResultRespHeaderSent && mbinitReversalMbResultRespPayloadSent &&
        mbinitReversalMbDoneReqSeen && mbinitReversalMbDoneRespSent &&
        mbinitReversalMbPeerInitReqSent && mbinitReversalMbPeerInitRespSeen &&
        mbinitReversalMbPeerClearErrorReqSent && mbinitReversalMbPeerClearErrorRespSeen &&
        mbinitReversalMbPeerAllLaneFlagsHigh && mbinitReversalMbPeerResultReqSent &&
        mbinitReversalMbPeerResultRespHeaderSeen && mbinitReversalMbPeerResultRespPayloadSeen &&
        mbinitReversalMbPeerResultRespStrictOrderOk &&
        mbinitReversalMbPeerResultRespPayloadAllOnes &&
        mbinitReversalMbPeerDoneReqSent && mbinitReversalMbPeerDoneRespSeen &&
        mbinitRepairMbStartReqSeen && mbinitRepairMbStartRespSent &&
        mbinitRepairMbD2CPointTestReqHeaderSeen && mbinitRepairMbD2CPointTestReqPayloadSeen &&
        mbinitRepairMbD2CPointTestRespSent &&
        mbinitRepairMbLfsrClearErrorReqSeen && mbinitRepairMbLfsrClearErrorRespSent &&
        mbinitRepairMbSendLaneIdPatternSeen && mbinitRepairMbFinishedLaneIdPatternHigh &&
        mbinitRepairMbTxInitD2CResultsReqSeen && mbinitRepairMbTxInitD2CResultsRespHeaderSent &&
        mbinitRepairMbTxInitD2CResultsRespPayloadSent &&
        mbinitRepairMbEndTxInitD2CPointTestReqSeen && mbinitRepairMbEndTxInitD2CPointTestRespSent &&
        mbinitRepairMbApplyDegradeReqSeen && mbinitRepairMbApplyDegradeRespSent &&
        mbinitRepairMbEndReqSeen && mbinitRepairMbEndRespSent &&
        mbinitRepairMbPeerStartReqSent && mbinitRepairMbPeerStartRespSeen &&
        mbinitRepairMbPeerD2CReqHeaderSent && mbinitRepairMbPeerD2CReqPayloadSent &&
        mbinitRepairMbPeerSetReceiverSeen && mbinitRepairMbPeerD2CRespSeen &&
        mbinitRepairMbPeerLfsrReqSent && mbinitRepairMbPeerLfsrRespSeen &&
        mbinitRepairMbPeerDetectedLaneBitsHigh &&
        mbinitRepairMbPeerTxInitReqSent &&
        mbinitRepairMbPeerTxInitRespHeaderSeen && mbinitRepairMbPeerTxInitRespPayloadSeen &&
        mbinitRepairMbPeerEndTxReqSent && mbinitRepairMbPeerEndTxRespSeen
      )
    }
  }
}