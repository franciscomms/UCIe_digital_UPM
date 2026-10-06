package RdiLinkManagement

import chisel3._
import chiseltest._
import org.scalatest.flatspec.AnyFlatSpec

class RdiDisabledSpec extends AnyFlatSpec with ChiselScalatestTester {

  behavior of "RdiLinkManagementController DISABLED state"

  it should "enter DISABLED, send REQ_DISABLED, receive RSP_DISABLED and return to RESET on ACTIVE request" in {
    test(new RdiLinkManagementController) { dut =>

      dut.io.lp_linkerror.poke(false.B)
      dut.io.lp_state_req.poke(PhyState.RESET)

      dut.io.sb_rcv.poke(RdiSideBandMessage.NOP)
      dut.io.sb_rcv_vld.poke(false.B)
      dut.io.sb_rdy.poke(true.B)

      dut.clock.step(2)

      dut.io.pl_state_sts.expect(PhyState.RESET)

      dut.io.lp_state_req.poke(PhyState.DISABLED)
      dut.clock.step(1)

      dut.io.pl_state_sts.expect(PhyState.DISABLED)

      dut.io.sb_snd.expect(RdiSideBandMessage.REQ_DISABLED)
      dut.io.sb_snd_vld.expect(true.B)

      dut.clock.step(1)

      dut.io.sb_rcv.poke(RdiSideBandMessage.RSP_DISABLED)
      dut.io.sb_rcv_vld.poke(true.B)
      dut.clock.step(1)

      dut.io.sb_rcv_vld.poke(false.B)
      dut.io.sb_rcv.poke(RdiSideBandMessage.NOP)

      dut.clock.step(2)

      dut.io.lp_state_req.poke(PhyState.ACTIVE)
      dut.clock.step(1)

      dut.io.pl_state_sts.expect(PhyState.RESET)
    }
  }

  it should "go to LINKERROR from DISABLED when lp_linkerror is asserted" in {
    test(new RdiLinkManagementController) { dut =>

      dut.io.lp_linkerror.poke(false.B)
      dut.io.lp_state_req.poke(PhyState.RESET)

      dut.io.sb_rcv.poke(RdiSideBandMessage.NOP)
      dut.io.sb_rcv_vld.poke(false.B)
      dut.io.sb_rdy.poke(true.B)

      dut.clock.step(2)

      dut.io.lp_state_req.poke(PhyState.DISABLED)
      dut.clock.step(1)

      dut.io.pl_state_sts.expect(PhyState.DISABLED)

      dut.io.lp_linkerror.poke(true.B)
      dut.clock.step(1)

      dut.io.pl_state_sts.expect(PhyState.LINKERROR)
    }
  }
}