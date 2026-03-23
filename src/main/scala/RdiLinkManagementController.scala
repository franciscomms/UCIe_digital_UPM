package edu.berkeley.cs.ucie.digital
package d2dadapter

import chisel3._
import chisel3.util._
import interfaces._
import sideband._

class RdiLinkManagementController extends Module {
  val io = IO(new Bundle {
    // =========================
    // PHY-facing RDI signals
    // =========================

    // From PHY to Adapter
    val pl_inband_pres = Input(Bool())
    // val pl_state_sts   = Input(PhyState())
    val pl_wake_ack    = Input(Bool())
    // val pl_clk_req     = Input(Bool()) // No necesaria probablemente
    val pl_clk_req     = Output(Bool()) // La driveamos desde la FSM de bring-up, pero la reflejamos también como salida directa por si la lógica de arriba la quiere usar para algo más que el bring-up

    // From Adapter to PHY
    val lp_state_req   = Output(PhyStateReq())
    val lp_wake_req    = Output(Bool())
    val lp_clk_ack     = Output(Bool())

    // fdi state request from upper logic
    val fdi_state_req = Input(PhyStateReq())

    // =========================
    // Sideband interface
    // =========================
    val sb_valid = Input(Bool())
    val sb_rdy   = Input(Bool())
    val sb_rcv   = Input(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))
    val sb_snd   = Output(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))

    // =========================
    // Outputs towards upper logic / FDI
    // =========================
    val rdi_pl_inband_pres = Output(Bool())
    val rdi_pl_state_sts   = Output(PhyState()) //??????

    val rdi_lp_linkerror = Output(Bool()) // linkerror request from RDI to PHY
    val rdi_pl_state_sts = Input(PhyState()) // PHY state status

  })

  // ============================================================
  // Registers
  // ============================================================

  val rdi_init_state_reg = RegInit(RdiLinkInitState.RDI_INIT_START)

  val lp_state_req_reg = RegInit(PhyStateReq.nop)
  val lp_wake_req_reg  = RegInit(false.B)
  val lp_clk_ack_reg   = RegInit(false.B)

  val sb_snd_msg_reg   = RegInit(SideBandMessage.NOP)

  // ============================================================
  // Sticky flags for RDI Active Entry handshake
  // ============================================================

  val active_loc_req_sent = RegInit(false.B)
  val active_loc_rsp_rcvd = RegInit(false.B)
  val active_rem_req_rcvd = RegInit(false.B)
  val active_rem_rsp_sent = RegInit(false.B)



  // ============================================================
  // L1 and L2 flags
  // ============================================================

  val l1_sbmsg_loc_req_flag = RegInit(false.B)
  val l1_sbmsg_loc_rsp_flag = RegInit(false.B)
  val l1_sbmsg_rem_req_flag = RegInit(false.B)
  val l1_sbmsg_rem_rsp_flag = RegInit(false.B)
  val l1_sbmsg_pmnak_flag   = RegInit(false.B)

  val l2_sbmsg_loc_req_flag = RegInit(false.B)
  val l2_sbmsg_loc_rsp_flag = RegInit(false.B)
  val l2_sbmsg_rem_req_flag = RegInit(false.B)
  val l2_sbmsg_rem_rsp_flag = RegInit(false.B)
  val l2_sbmsg_pmnak_flag   = RegInit(false.B)



  val pm_exit_pending_from_remote = RegInit(false.B)
  val pm_exit_pending_from_local  = RegInit(false.B)

  val pm_wait_1us_counter = RegInit(0.U(32.W))
  val pm_wait_1us_done    = pm_wait_1us_counter === io.cycles_1us

  val l1_handshake_done = WireDefault(false.B)
  val l2_handshake_done = WireDefault(false.B)



  l1_handshake_done := l1_sbmsg_loc_req_flag && l1_sbmsg_loc_rsp_flag &&
                      l1_sbmsg_rem_req_flag && l1_sbmsg_rem_rsp_flag

  l2_handshake_done := l2_sbmsg_loc_req_flag && l2_sbmsg_loc_rsp_flag &&
                      l2_sbmsg_rem_req_flag && l2_sbmsg_rem_rsp_flag

  // ============================================================
  // Derived conditions
  // ============================================================

  val active_hs_done = active_loc_req_sent && active_loc_rsp_rcvd &&
                        active_rem_req_rcvd && active_rem_rsp_sent

  // ============================================================
  // Defaults
  // ============================================================

  io.lp_state_req := lp_state_req_reg
  io.lp_wake_req  := lp_wake_req_reg
  io.lp_clk_ack   := lp_clk_ack_reg

  io.sb_snd := sb_snd_msg_reg

  io.rdi_pl_inband_pres := io.pl_inband_pres // correcto
  io.rdi_pl_state_sts   := // io.pl_state_sts

  io.pl_clk_req := 

  //io.debug_init_state := rdi_init_state_reg

  // Safe defaults every cycle
  // lp_state_req_reg := PhyStateReq.nop
  // lp_wake_req_reg  := false.B
  // sb_snd_msg_reg   := SideBandMessage.NOP



  //Stall module!!!!
  val stall_module = Module(new StallCtrl()) // still to check

  // Placeholder simple for clk req/ack
  // Luego lo refinaremos si hace falta
  lp_clk_ack_reg := RegNext(io.pl_clk_req, false.B)

  // ============================================================
  // Sideband Active handshake sticky flags
  // ============================================================

  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.REQ_ACTIVE) {
    active_loc_req_sent := true.B
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.RSP_ACTIVE) {
    active_loc_rsp_rcvd := true.B
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.REQ_ACTIVE) {
    active_rem_req_rcvd := true.B
  }

  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.RSP_ACTIVE) {
    active_rem_rsp_sent := true.B
  }

  // TO DO: CHECK ALL THE STICKY FLAGS!!!! 
  // =========================
  // L1 sideband flags
  // =========================
  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.REQ_L1) {
    l1_sbmsg_loc_req_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L1 || rdi_global_state_reg === RdiGlobalState.ACTIVE) { //mirar bien los resests de las flags
    when(!io.rdi_req_l1) { l1_sbmsg_loc_req_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.RSP_L1) {
    l1_sbmsg_loc_rsp_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L1 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.rdi_req_l1) { l1_sbmsg_loc_rsp_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.REQ_L1) {
    l1_sbmsg_rem_req_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L1 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.sb_valid) { l1_sbmsg_rem_req_flag := false.B }
  }

  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.RSP_L1) {
    l1_sbmsg_rem_rsp_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L1 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.sb_valid) { l1_sbmsg_rem_rsp_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.RSP_PMNAK) {
    l1_sbmsg_pmnak_flag := true.B
  }.elsewhen(rdi_global_state_reg =/= RdiGlobalState.PMNAK) {
    l1_sbmsg_pmnak_flag := false.B
  }

  // =========================
  // L2 sideband flags
  // =========================
  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.REQ_L2) {
    l2_sbmsg_loc_req_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L2 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.rdi_req_l2) { l2_sbmsg_loc_req_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.RSP_L2) {
    l2_sbmsg_loc_rsp_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L2 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.rdi_req_l2) { l2_sbmsg_loc_rsp_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.REQ_L2) {
    l2_sbmsg_rem_req_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L2 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.sb_valid) { l2_sbmsg_rem_req_flag := false.B }
  }

  when (io.sb_rdy && sb_snd_msg_reg === SideBandMessage.RSP_L2) {
    l2_sbmsg_rem_rsp_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.L2 || rdi_global_state_reg === RdiGlobalState.ACTIVE) {
    when(!io.sb_valid) { l2_sbmsg_rem_rsp_flag := false.B }
  }

  when (io.sb_valid && io.sb_rcv === SideBandMessage.RSP_PMNAK) {
    l2_sbmsg_pmnak_flag := true.B
  }.elsewhen(rdi_global_state_reg =/= RdiGlobalState.PMNAK) {
    l2_sbmsg_pmnak_flag := false.B
  }



  when(io.fdi_state_req === PhyStateReq.active)    { pending_active_req    := true.B }
  when(io.fdi_state_req === PhyStateReq.l1)        { pending_l1_req        := true.B }
  when(io.fdi_state_req === PhyStateReq.l2)        { pending_l2_req        := true.B }
  when(io.fdi_state_req === PhyStateReq.retrain)   { pending_retrain_req   := true.B }
  when(io.fdi_state_req === PhyStateReq.linkReset) { pending_linkreset_req := true.B }
  when(io.fdi_state_req === PhyStateReq.disabled)  { pending_disabled_req  := true.B }


 // sticky flag to capture the remote sideband message to enter linkerror
  val remote_linkerror_req_flag = RegInit(false.B)
  when(io.sb_valid && io.sb_rcv === SideBandMessage.REQ_LINKERROR) {
    remote_linkerror_req_flag := true.B
  }.elsewhen(rdi_global_state_reg === RdiGlobalState.LINKERROR || rdi_global_state_reg === RdiGlobalState.PMNAK) { // what happen if i get remote request while i already am in linkerror or pmnak?? stay in linkerror or pmnak but reset the flag? or ignore the remote request until i exit from linkerror/pmnak?
    when(!io.sb_valid) { remote_linkerror_req_flag := false.B }
  }



  // ====================================================================================================================================================================================
  // ====================================================================================================================================================================================
  // ====================================================================================================================================================================================
  // ====================================================================================================================================================================================
  // ====================================================================================================================================================================================


  val retrain_req     = io.fdi_lp_state_req === PhyStateReq.retrain
  val retrain_phy_sts = io.pl_state_sts === PhyState.retrain

  val fdi_lp_state_req_prev_reg = RegNext(io.fdi_lp_state_req, PhyStateReq.nop)
  val nopToActive = WireDefault(false.B)
  nopToActive := (fdi_lp_state_req_prev_reg === PhyStateReq.nop) &&
                (io.fdi_lp_state_req === PhyStateReq.active)


  val reset_internal = WireDefault(false.B) // still to be implemented

  // link error combinational logic
  val linkerror_internal = WireDefault(false.B) // still to be implemented
  
  val linkerror_asserted = WireDefault(false.B)
  linkerror_asserted := io.rdi_lp_req_linkerror || linkerror_internal || remote_linkerror_req_flag // check this
  
  // LinkError→Reset: The lower layer transitions to Reset due to an internal request to move to Reset
  // (e.g., reset pin assertion, or software clearing the error status bits that triggered the error) OR
  // (lp_state_req == Active and lp_linkerror = 0, while pl_state_sts == LinkError AND
  // minimum residency requirements are met AND no internal condition such as an error state
  // requires the lower layer to remain in LinkError). Lower Layer must implement a minimum
  // residency time in LinkError of 16 ms to ensure that the remote Link partner will be forced to enter

  val linkerror_exit_allowed = WireDefault(false.B) // do i need to implement this or fdi should?
  linkerror_exit_allowed := (io.fdi_lp_state_req === PhyStateReq.active && !linkerror_asserted && io.pl_state_sts === PhyState.LINKERROR && time_in_linkerror >= 16)


  val disabled_internal = WireDefault(false.B) // still to be implemented
  val disabled_cleanup_done = WireDefault(true.B) // TODO: define 

  val linkreset_done = WireDefault(true.B) // TODO: define conditions for this


  // ============================================================
  // RDI bring-up sub-FSM
  // ============================================================

  val rdi_init_state_reg = RegInit(RdiLinkInitState.RDI_INIT_START)

  // Salidas por defecto
  // pl_state_sts_reg   := PhyState.reset
  // pl_inband_pres_reg := false.B ---> correcto?? Debo hacer el drive en la FSM o directamente reflejar io.pl_inband_pres como hago ahora??
  // pl_clk_req_reg     := false.B
  sb_snd_msg_reg     := SideBandMessage.NOP

  switch(rdi_init_state_reg) {

    is(RdiLinkInitState.RDI_INIT_START) {
      when(io.pl_inband_pres) {
        rdi_init_state_reg := RdiLinkInitState.RDI_WAIT_CLK_ACK
      }
    }

    is(RdiLinkInitState.RDI_WAIT_CLK_ACK) {
      // pl_inband_pres_reg := true.B
      pl_clk_req_reg     := true.B
      // pl_state_sts_reg   := PhyState.reset

      when(!io.pl_inband_pres) {
        rdi_init_state_reg := RdiLinkInitState.RDI_INIT_START
      }.elsewhen(io.lp_clk_ack) {
        rdi_init_state_reg := RdiLinkInitState  I_WAIT_ACTIVE_REQ
      }
    }

    is(RdiLinkInitState.RDI_WAIT_ACTIVE_REQ) {
      // pl_inband_pres_reg := true.B
      pl_clk_req_reg     := true.B
      // pl_state_sts_reg   := PhyState.reset

      when(!io.pl_inband_pres) {
        rdi_init_state_reg := RdiLinkInitState.RDI_INIT_START
      }.elsewhen(io.lp_state_req === PhyStateReq.active) { //cambiar esto por la signal req de FDI
        rdi_init_state_reg := RdiLinkInitState.RDI_ACTIVE_HANDSHAKE
        // Send REQ_ACTIVE al FDI a través del sideband
        // sb_snd_msg_reg := RdiSideBandMessage.REQ_ACTIVE // still to be defined
      }
    }

    is(RdiLinkInitState.RDI_ACTIVE_HANDSHAKE) {

      // pl_inband_pres_reg := true.B
      pl_clk_req_reg     := true.B

      sb_snd_msg_reg := RdiSideBandMessage.REQ_ACTIVE // still to be defined
      // Por defecto no enviar mensaje
      // sb_snd_msg_reg := SideBandMessage.NOP // mirar esto

      when(!io.pl_inband_pres) {
        rdi_init_state_reg := RdiLinkInitState.RDI_INIT_START

      }.otherwise {

        when(active_rem_req_rcvd && !active_rem_rsp_sent) {
          sb_snd_msg_reg := SideBandMessage.RSP_ACTIVE

        }.elsewhen(!active_loc_req_sent) {
          sb_snd_msg_reg := SideBandMessage.REQ_ACTIVE
        }

        when(active_hs_done) {
          rdi_init_state_reg := RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE
        }
      }
    }

    is(RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE) {
      // pl_inband_pres_reg := true.B
      pl_clk_req_reg     := true.B

      when(!io.pl_inband_pres) {
        rdi_init_state_reg := RdiLinkInitState.RDI_INIT_START
      
      }.elsewhen(rdi_global_state_reg =/= PhyState.reset) {
        // La FSM global ya hizo Reset -> Active
        rdi_init_state_reg := RdiLinkInitState.RDI_INIT_START
      }
    }
  }



  // La spec te obliga a una ventana de 1 µs cuando recibes 
  // un PM Request remoto y tú sigues en Active con lp_state_req=Active; si se mantiene así, respondes PMNAK.

  switch(rdi_global_state_reg) {

  is(RdiGlobalState.RESET) { //TODO
    
    
    // La entrada a ACTIVE la hace tu sub-FSM de bring-up
    when(rdi_init_state_reg === RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE) {
      rdi_global_state_reg := RdiGlobalState.ACTIVE
    
    
    
    
    
    }.elsewhen(io.rdi_lp_req_linkerror) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR
    
    }.elsewhen(io.rdi_req_disabled) {
      rdi_global_state_reg := RdiGlobalState.DISABLED 
    
    }.elsewhen(io.rdi_req_linkreset) {
      rdi_global_state_reg := RdiGlobalState.LINKRESET
    }
  }

  is(RdiGlobalState.ACTIVE) {
    sb_snd_msg_reg   := SideBandMessage.NOP // check this
    lp_state_req_reg := PhyStateReq.nop // check this
  
    when(io.fdi_lp_state_req === PhyStateReq.linkError) { // Local request of LinkError
      rdi_global_state_reg := RdiGlobalState.LINKERROR

    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.disabled) { // Local request of Disabled
      rdi_global_state_reg := RdiGlobalState.DISABLED

    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.linkReset) { // Local request of LinkReset
      rdi_global_state_reg := RdiGlobalState.LINKRESET

    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.retrain) { // Local request of Retrain
      lp_state_req_reg := PhyStateReq.retrain // request to PHY to enter Retrain

      when(retrain_phy_sts) { // wait to observe PHY in Retrain before changing your own state to Retrain
        rdi_global_state_reg := RdiGlobalState.RETRAIN
      }

    }.elsewhen(retrain_phy_sts && !retrain_req) {  // Follow PHY: el PHY ya está en Retrain aunque tú no lo hubieras pedido
      rdi_global_state_reg := RdiGlobalState.RETRAIN

    // Local request to L1
    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.l1) {
      lp_state_req_reg := PhyStateReq.l1

      when(l1_sbmsg_rem_req_flag && !l1_sbmsg_rem_rsp_flag) {
        sb_snd_msg_reg := SideBandMessage.RSP_L1
      }.elsewhen(!l1_sbmsg_loc_req_flag) {
        sb_snd_msg_reg := SideBandMessage.REQ_L1
      }

      when(l1_sbmsg_pmnak_flag) {
        rdi_global_state_reg := RdiGlobalState.PMNAK
      }.elsewhen(l1_handshake_done) {
        rdi_global_state_reg := RdiGlobalState.L1
      }

    // Local request to L2
    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.l2) {
      lp_state_req_reg := PhyStateReq.l2

      when(l2_sbmsg_rem_req_flag && !l2_sbmsg_rem_rsp_flag) {
        sb_snd_msg_reg := SideBandMessage.RSP_L2
      }.elsewhen(!l2_sbmsg_loc_req_flag) {
        sb_snd_msg_reg := SideBandMessage.REQ_L2
      }

      when(l2_sbmsg_pmnak_flag) {
        rdi_global_state_reg := RdiGlobalState.PMNAK
      }.elsewhen(l2_handshake_done) {
        rdi_global_state_reg := RdiGlobalState.L2
      }

    // Remote PM request while local stays Active
    }.elsewhen(l1_sbmsg_rem_req_flag && pm_wait_1us_done) {
      sb_snd_msg_reg := SideBandMessage.RSP_PMNAK
      rdi_global_state_reg := RdiGlobalState.PMNAK

    }.elsewhen(l2_sbmsg_rem_req_flag && pm_wait_1us_done) {
      sb_snd_msg_reg := SideBandMessage.RSP_PMNAK
      rdi_global_state_reg := RdiGlobalState.PMNAK
    }
  }

  is(RdiGlobalState.PMNAK) {
    
    
    
    
    
    
    
    
    when(io.rdi_lp_req_linkerror) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR
    }.elsewhen(io.rdi_req_disabled) {
      rdi_global_state_reg := RdiGlobalState.DISABLED
    }.elsewhen(io.rdi_req_linkreset) {
      rdi_global_state_reg := RdiGlobalState.LINKRESET
    }.elsewhen(io.rdi_req_retrain) {
      rdi_global_state_reg := RdiGlobalState.RETRAIN
    }.elsewhen(io.rdi_req_active) {
      rdi_global_state_reg := RdiGlobalState.ACTIVE
    }
  }

  is(RdiGlobalState.L1) {
    when(io.rdi_lp_req_linkerror) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR
    }.elsewhen(io.rdi_req_disabled) {
      rdi_global_state_reg := RdiGlobalState.DISABLED
    }.elsewhen(io.rdi_req_linkreset) {
      rdi_global_state_reg := RdiGlobalState.LINKRESET
    }.elsewhen(io.rdi_req_active) {
      rdi_global_state_reg := RdiGlobalState.ACTIVE
    }
  }

  is(RdiGlobalState.L2) {
    when(io.rdi_lp_req_linkerror) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR
    }.elsewhen(io.rdi_req_disabled) {
      rdi_global_state_reg := RdiGlobalState.DISABLED
    }.elsewhen(io.rdi_req_linkreset) {
      rdi_global_state_reg := RdiGlobalState.LINKRESET
    }.elsewhen(io.rdi_req_active) {
      // desde L2 normalmente vuelves pasando por RESET
      rdi_global_state_reg := RdiGlobalState.RESET
    }
  }

  is(RdiGlobalState.RETRAIN) {
  sb_snd_msg_reg   := SideBandMessage.NOP
  lp_state_req_reg := PhyStateReq.nop

  when(linkerror_asserted) { // Local request of LinkError mientras estoy en Retrain
    retrain_to_active_initiated := false.B
    retrain_exit_to_disabled    := false.B
    retrain_exit_to_linkreset   := false.B
    rdi_global_state_reg        := RdiGlobalState.LINKERROR

  // Request de Disabled mientras estoy en RETRAIN
  }.elsewhen(!retrain_to_active_initiated && //check this. disabled has priority over transition to active?
             io.fdi_lp_state_req === PhyStateReq.disabled) {
      retrain_exit_to_disabled    := true.B
      retrain_exit_to_linkreset   := false.B
      retrain_to_active_initiated := true.B
      rdi_init_state_reg          := RdiLinkInitState.RDI_ACTIVE_HANDSHAKE

  // Request de LinkReset mientras estoy en RETRAIN
  }.elsewhen(!retrain_to_active_initiated &&
             io.fdi_lp_state_req === PhyStateReq.linkReset) {
      retrain_exit_to_disabled    := false.B
      retrain_exit_to_linkreset   := true.B
      retrain_to_active_initiated := true.B
      rdi_init_state_reg          := RdiLinkInitState.RDI_ACTIVE_HANDSHAKE

  // Request normal de volver a ACTIVE
  }.elsewhen(!retrain_to_active_initiated &&
             ((retrain_from_l1_flag && (io.fdi_lp_state_req === PhyStateReq.active) && (io.rdi_pl_state_sts === PhyState.retrain)) ||
              ((!retrain_from_l1_flag) && nopToActive))) {
      retrain_exit_to_disabled    := false.B
      retrain_exit_to_linkreset   := false.B
      retrain_to_active_initiated := true.B
      rdi_init_state_reg          := RdiLinkInitState.RDI_ACTIVE_HANDSHAKE

  }.elsewhen(retrain_to_active_initiated) { // Ya he arrancado la salida de RETRAIN; ahora espero a que termine la subFSM
      when(rdi_init_state_reg === RdiLinkInitState.RDI_ACTIVE_ENTRY_DONE) {
        retrain_to_active_initiated := false.B
        retrain_exit_to_disabled    := false.B
        retrain_exit_to_linkreset   := false.B
        retrain_from_l1_flag          := false.B
        rdi_global_state_reg        := RdiGlobalState.ACTIVE
      }
    }
  }


  is(RdiGlobalState.LINKRESET) {
    // sb_snd_msg_reg   := SideBandMessage.NOP
    // lp_state_req_reg := PhyStateReq.nop // check this: o linkReset dependiendo

    when(linkerror_asserted && // LinkReset → LinkError
      io.rdi_pl_state_sts === PhyState.linkReset) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR

    }.elsewhen( // LinkReset → Disabled
      (disabled_internal || io.fdi_lp_state_req === PhyStateReq.disabled) && // is this bolean condition correct?
      io.rdi_pl_state_sts === PhyState.linkReset // why we need to check phy state here?
    ) {
        rdi_global_state_reg := RdiGlobalState.DISABLED

    
    }.elsewhen(reset_internal) { // LinkReset → Reset (internal)
        rdi_global_state_reg := RdiGlobalState.RESET

    }.elsewhen( // LinkReset → Reset (normal recovery)
      io.fdi_lp_state_req === PhyStateReq.active &&
      io.rdi_pl_state_sts === PhyState.linkReset &&
      linkreset_done // flush terminado
    ) {
        rdi_global_state_reg := RdiGlobalState.RESET
    
    }
  }

  is(RdiGlobalState.DISABLED) { // done??
    // sb_snd_msg_reg   := SideBandMessage.NOP // check this in the future
    // lp_state_req_reg := PhyStateReq.nop

    when(linkerror_asserted &&
      (io.rdi_pl_state_sts === PhyState.disabled)) {
      rdi_global_state_reg := RdiGlobalState.LINKERROR
    
    }.elsewhen(reset_internal) {
      rdi_global_state_reg := RdiGlobalState.RESET

    }.elsewhen( // Normal recovery path
      (io.fdi_lp_state_req === PhyStateReq.active) &&
      (io.rdi_pl_state_sts === PhyState.disabled) &&
      disabled_cleanup_done) {
      rdi_global_state_reg := RdiGlobalState.RESET
    }
  }


  is(RdiGlobalState.LINKERROR) { //TODO
    sb_snd_msg_reg   := SideBandMessage.NOP
    lp_state_req_reg := PhyStateReq.nop

    when(io.fdi_lp_state_req === PhyStateReq.disabled) { // LinkError → Disabled
      rdi_global_state_reg := RdiGlobalState.DISABLED

    }.elsewhen(io.fdi_lp_state_req === PhyStateReq.linkReset) { // LinkError → LinkReset
      rdi_global_state_reg := RdiGlobalState.LINKRESET

    }.elsewhen(reset_internal) { // LinkError → Reset (internal)
      rdi_global_state_reg := RdiGlobalState.RESET

    }.elsewhen(linkerror_exit_allowed) { // LinkError → Reset (normal recovery)
      rdi_global_state_reg := RdiGlobalState.RESET
    }
  }
}


