package edu.berkeley.cs.ucie.digital
package d2dadapter

import chisel3._
import chisel3.util._

class RdiBringupFsmIO extends Bundle {
  val pl_inband_pres = Input(Bool())
  val lp_clk_ack     = Input(Bool())
  val lp_state_req   = Input(PhyStateReq())

  val sb_valid = Input(Bool())
  val sb_rcv   = Input(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))

  val enable = Input(Bool())
  val clear  = Input(Bool())

  val pl_clk_req = Output(Bool())
  val sb_snd_msg = Output(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))

  val bringup_state_sts = Output(RdiLinkInitState())
  val active_entry_done = Output(Bool())

  val active_loc_req_sent = Output(Bool())
  val active_rem_req_rcvd = Output(Bool())
  val active_rem_rsp_sent = Output(Bool())
  val active_hs_done      = Output(Bool())
}

class RdiBringupFsm extends Module {
  val io = IO(new RdiBringupFsmIO)

  val bringup_state_reg = RegInit(RdiLinkInitState.RDI_INIT_START)

  val pl_clk_req_reg = RegInit(false.B)
  val sb_snd_msg_reg = RegInit(SideBandMessage.NOP)

  val active_loc_req_sent = RegInit(false.B)
  val active_rem_req_rcvd = RegInit(false.B)
  val active_rem_rsp_sent = RegInit(false.B)

  val active_hs_done = WireDefault(false.B)
  active_hs_done := (active_rem_req_rcvd && active_rem_rsp_sent) || active_loc_req_sent

  io.pl_clk_req := pl_clk_req_reg
  io.sb_snd_msg := sb_snd_msg_reg

  io.bringup_state_sts := bringup_state_reg
  io.active_entry_done := (bringup_state_reg === RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE)

  io.active_loc_req_sent := active_loc_req_sent
  io.active_rem_req_rcvd := active_rem_req_rcvd
  io.active_rem_rsp_sent := active_rem_rsp_sent
  io.active_hs_done      := active_hs_done

  when(io.clear || !io.enable) {
    active_loc_req_sent := false.B
    active_rem_req_rcvd := false.B
    active_rem_rsp_sent := false.B
  }.otherwise {
    when(io.sb_valid && io.sb_rcv === SideBandMessage.REQ_ACTIVE) {
      active_rem_req_rcvd := true.B
    }

    when(sb_snd_msg_reg === SideBandMessage.REQ_ACTIVE) {
      active_loc_req_sent := true.B
    }

    when(sb_snd_msg_reg === SideBandMessage.RSP_ACTIVE) {
      active_rem_rsp_sent := true.B
    }
  }

  when(io.clear || !io.enable) {
    bringup_state_reg := RdiLinkInitState.RDI_INIT_START
    pl_clk_req_reg    := false.B
    sb_snd_msg_reg    := SideBandMessage.NOP

  }.otherwise {
    pl_clk_req_reg := false.B
    sb_snd_msg_reg := SideBandMessage.NOP

    switch(bringup_state_reg) {
      is(RdiLinkInitState.RDI_INIT_START) {
        when(io.pl_inband_pres) {
          bringup_state_reg := RdiLinkInitState.RDI_WAIT_CLK_ACK
        }
      }

      is(RdiLinkInitState.RDI_WAIT_CLK_ACK) {
        pl_clk_req_reg := true.B

        when(!io.pl_inband_pres) {
          bringup_state_reg := RdiLinkInitState.RDI_INIT_START
        }.elsewhen(io.lp_clk_ack) {
        }
      }

      is(RdiLinkInitState.RDI_WAIT_ACTIVE_REQ) {
        pl_clk_req_reg := true.B

        when(!io.pl_inband_pres) {
          bringup_state_reg := RdiLinkInitState.RDI_INIT_START
        }.elsewhen(io.lp_state_req === PhyStateReq.active) {
          bringup_state_reg := RdiLinkInitState.RDI_ACTIVE_HANDSHAKE
        }
      }

      is(RdiLinkInitState.RDI_ACTIVE_HANDSHAKE) {
        pl_clk_req_reg := true.B

        sb_snd_msg_reg := SideBandMessage.REQ_ACTIVE

        when(!io.pl_inband_pres) {
          bringup_state_reg := RdiLinkInitState.RDI_INIT_START

        }.otherwise {

          when(active_rem_req_rcvd && !active_rem_rsp_sent) {
            sb_snd_msg_reg := SideBandMessage.RSP_ACTIVE

          }.elsewhen(!active_loc_req_sent) {
            sb_snd_msg_reg := SideBandMessage.REQ_ACTIVE
          }

          when(active_hs_done) {
            bringup_state_reg := RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE
          }
        }
      }

      is(RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE) {
        bringup_state_reg := RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE
      }
    }
  }
}