package RdiLinkManagement

import chisel3._
import chisel3.util._

class RdiLinkManagementController extends Module {
  val io = IO(new Bundle {
    // Adapter to PHY data transfer interface
    // val lp_irdy = Input(Bool()) // Physical Layer is ready to accept data 
    // val lp_valid = Input(Bool())
    // val lp_data  = Input(UInt(64.W)) // check width
    // val pl_trdy = Output(Bool()) // Phy is ready to accept data from the adapter

    // Phy to Adapter transfer interface
    // val pl_valid = Output(Bool())
    // val pl_data  = Output(UInt(64.W)) // check width

    // From Adapter to PHY (not used in this version)
    // val lp_wake_req    = Input(Bool())
    // val pl_clk_ack     = Output(Bool())
  
    val lp_state_req = Input(PhyState())
    val pl_state_sts   = Output(PhyState())

    // Physical Sideband Link Interface
    // TODO: Check if backpressure is needed for the sideband interface and implement it if so
    val sb_snd       = Output(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))
    val sb_snd_vld = Output(Bool())
    val sb__snd_rdy       = Input(Bool())

    val sb_rcv       = Input(UInt(D2DAdapterSignalSize.SIDEBAND_MESSAGE_OP_WIDTH))
    val sb_rcv_vld     = Input(Bool())
    val sb_rcv_rdy     = Output(Bool())

    // Sideband interface TODO: Check width and content of these signals
    // val pl_cfg = Output(UInt(32.W))
    // val pl_cfg_vld = Output(Bool())
    // val pl_cfg_crd = Output(UInt(16.W))

    // val lp_cfg = Input(UInt(32.W))
    // val lp_cfg_vld = Input(Bool())
    // val lp_cfg_crd = Input(UInt(16.W))

    // val pl_inband_pres = Output(Bool())
    val lp_linkerror = Input(Bool())

    // val pl_lnk_cfg = Output(UInt(3.W))

    val pl_phyinrecenter = Output(Bool())

  })
 
  io.sb_rcv_rdy := true.B // TODO: Implement proper flow control for sideband interface if needed
  
  // Bring-up sideband source
  val bringup_sb_snd     = WireDefault(RdiSideBandMessage.NOP)
  val bringup_sb_snd_vld = WireDefault(false.B)

  // Global FSM sideband source
  val global_sb_snd      = WireDefault(RdiSideBandMessage.NOP)
  val global_sb_snd_vld  = WireDefault(false.B)

  val bringup_state_reg = RegInit(RDIBringUpState.IDLE)
  val global_state_reg = RegInit(PhyState.RESET)
  
  io.pl_state_sts := global_state_reg

  io.pl_phyinrecenter := false.B // TODO: Check if I generate the output or LTSM does

  val link_down_state = global_state_reg === PhyState.LINKERROR || global_state_reg === PhyState.DISABLED || global_state_reg === PhyState.LINKRESET
  val remote_notify_required = !(link_down_state && !io.pl_phyinrecenter)

  val stall_handshake_asserted = RegInit(false.B)
  // Stall module!!!!
  // val stall_module = Module(new StallCtrl()) // still to check

  // This signal must only be asserted if pl_state_sts is Active or when performing the
  // pl_stallreq/lp_stallack handshake when the pl_state_sts is LinkError
  // TODO: Check this condition
  // io.pl_trdy := (io.pl_state_sts === PhyState.ACTIVE) || (io.pl_state_sts === PhyState.LINKERROR && stall_handshake_asserted) // TODO: Implement stall handshake (if needed)

  val retrain_to_active_initiated = RegInit(false.B)
  val retrain_internal = WireDefault(false.B) // TODO: Implement internal retrain request conditions
  val retrain_req = io.lp_state_req === PhyState.RETRAIN || retrain_internal

  val lp_state_req_prev_reg = RegNext(io.lp_state_req, PhyState.NOP)

  val reset_internal = reset.asBool // TODO: Check this

    val pending_req_reg = RegInit(RdiSideBandMessage.NOP)
  val waiting_rsp_reg = RegInit(false.B)

  val local_req_sent =
  io.sb_snd_vld && (
    io.sb_snd === RdiSideBandMessage.REQ_ACTIVE    ||
    io.sb_snd === RdiSideBandMessage.REQ_L1        ||
    io.sb_snd === RdiSideBandMessage.REQ_L2        ||
    io.sb_snd === RdiSideBandMessage.REQ_LINKRESET ||
    io.sb_snd === RdiSideBandMessage.REQ_LINKERROR ||
    io.sb_snd === RdiSideBandMessage.REQ_RETRAIN   ||
    io.sb_snd === RdiSideBandMessage.REQ_DISABLED
  )

  val expected_remote_rsp_received =
  waiting_rsp_reg &&
  io.sb_rcv_vld &&
  (
    ((pending_req_reg === RdiSideBandMessage.REQ_ACTIVE)    && (io.sb_rcv === RdiSideBandMessage.RSP_ACTIVE))    ||
    ((pending_req_reg === RdiSideBandMessage.REQ_L1)        && (io.sb_rcv === RdiSideBandMessage.RSP_L1))        ||
    ((pending_req_reg === RdiSideBandMessage.REQ_L2)        && (io.sb_rcv === RdiSideBandMessage.RSP_L2))        ||
    ((pending_req_reg === RdiSideBandMessage.REQ_LINKRESET) && (io.sb_rcv === RdiSideBandMessage.RSP_LINKRESET)) ||
    ((pending_req_reg === RdiSideBandMessage.REQ_LINKERROR) && (io.sb_rcv === RdiSideBandMessage.RSP_LINKERROR)) ||
    ((pending_req_reg === RdiSideBandMessage.REQ_RETRAIN)   && (io.sb_rcv === RdiSideBandMessage.RSP_RETRAIN))   ||
    ((pending_req_reg === RdiSideBandMessage.REQ_DISABLED)  && (io.sb_rcv === RdiSideBandMessage.RSP_DISABLED))
  )

  when(reset.asBool || (global_state_reg === PhyState.LINKERROR)) {
    pending_req_reg := RdiSideBandMessage.NOP
    waiting_rsp_reg := false.B

  }.elsewhen(local_req_sent) {
    pending_req_reg := io.sb_snd
    waiting_rsp_reg := true.B

  }.elsewhen(expected_remote_rsp_received) {
    waiting_rsp_reg := false.B
  }

  val rdi_timeout = Module(new RdiTimeoutController())
  rdi_timeout.io.startSidebandReqTimer := local_req_sent
  rdi_timeout.io.sidebandRspReceived   := expected_remote_rsp_received
  rdi_timeout.io.inLinkError := global_state_reg === PhyState.LINKERROR
  rdi_timeout.io.sidebandStallReceived := false.B // TODO: Implement stall condition
  
  rdi_timeout.io.clearSidebandReqTimer :=
  reset.asBool || (global_state_reg === PhyState.LINKERROR)

  rdi_timeout.io.clearTimeoutFlag :=
  reset.asBool || (global_state_reg === PhyState.LINKERROR)

  rdi_timeout.io.stallResponseActive := false.B
  rdi_timeout.io.stallSent           := false.B

  rdi_timeout.io.cycles1us := 800.U
  
  val linkerror_internal = rdi_timeout.io.sidebandReqTimeoutFlag

  val disabled_procedure_done = RegInit(true.B)
  val linkreset_procedure_done = RegInit(true.B)
  val retrain_procedure_done = RegInit(true.B)
  val linkerror_procedure_done = RegInit(true.B)

  val linkreset_internal = WireDefault(false.B) // TODO: Implement

  val reset_to_active_inialitated = RegInit(false.B)

  val bringup_start = RegInit(false.B)
  val bringup_done = RegInit(false.B)

  val remote_linkerror_req_flag = RegInit(false.B)
  val remote_linkerror_rsp_flag = RegInit(false.B)
  val local_linkerror_req_flag = RegInit(false.B)
  val local_linkerror_rsp_flag = RegInit(false.B)

  val remote_disabled_req_flag = RegInit(false.B)
  val remote_disabled_rsp_flag = RegInit(false.B)
  val local_disabled_req_flag = RegInit(false.B)
  val local_disabled_rsp_flag = RegInit(false.B)
  
  val remote_linkreset_req_flag = RegInit(false.B)
  val remote_linkreset_rsp_flag = RegInit(false.B)
  val local_linkreset_req_flag = RegInit(false.B)
  val local_linkreset_rsp_flag = RegInit(false.B)

  val remote_retrain_req_flag = RegInit(false.B)
  val remote_retrain_rsp_flag = RegInit(false.B)
  val local_retrain_req_flag = RegInit(false.B)
  val local_retrain_rsp_flag = RegInit(false.B)

  val remote_active_entry_req_flag = RegInit(false.B)
  val remote_active_entry_rsp_flag = RegInit(false.B)
  val local_active_entry_req_flag = RegInit(false.B)
  val local_active_entry_rsp_flag = RegInit(false.B)

  // Sideband message handling for Remote LinkError Request
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.REQ_LINKERROR) {
    remote_linkerror_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKERROR) {
    remote_linkerror_req_flag := false.B
  }

  // Sideband message handling for Remote LinkError Response
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.RSP_LINKERROR) {
    remote_linkerror_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKERROR) {
    remote_linkerror_rsp_flag := false.B
  }

  // Sideband message handling for Local LinkError Request
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.REQ_LINKERROR) {
    local_linkerror_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKERROR) {
    local_linkerror_req_flag := false.B
  }

  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.RSP_LINKERROR) {
    local_linkerror_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKERROR) {
    local_linkerror_rsp_flag := false.B
  }

  // Sideband message handling for Remote Disabled Request
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.REQ_DISABLED) {
    remote_disabled_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.DISABLED) {
    remote_disabled_req_flag := false.B
  }

  // Sideband message handling for Remote Disabled Response
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.RSP_DISABLED) {
    remote_disabled_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.DISABLED) {
    remote_disabled_rsp_flag := false.B
  }

  // Sideband message handling for Local Disabled Request
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.REQ_DISABLED) {
    local_disabled_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.DISABLED) {
    local_disabled_req_flag := false.B
  }

  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.RSP_DISABLED) {
    local_disabled_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.DISABLED) {
    local_disabled_rsp_flag := false.B
  }
  
  // Sideband message handling for Remote LinkReset Request
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.REQ_LINKRESET) {
    remote_linkreset_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKRESET) {
    remote_linkreset_req_flag := false.B
  }

  // Sideband message handling for Local LinkReset Request
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.REQ_LINKRESET) {
    local_linkreset_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.LINKRESET) {
    local_linkreset_req_flag := false.B
  }

  // Sideband message handling for Remote LinkError Request
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.REQ_RETRAIN) {
    remote_retrain_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.RETRAIN) {
    remote_retrain_req_flag := false.B
  }

  // Sideband message handling for Remote LinkError Response
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.RSP_RETRAIN) {
    remote_retrain_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.RETRAIN) {
    remote_retrain_rsp_flag := false.B
  }

  // Sideband message handling for Local LinkError Request
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.REQ_RETRAIN) {
    local_retrain_req_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.RETRAIN) {
    local_retrain_req_flag := false.B
  }

  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.RSP_RETRAIN) {
    local_retrain_rsp_flag := true.B
  
  }.elsewhen (global_state_reg === PhyState.RETRAIN) {
    local_retrain_rsp_flag := false.B
  }

  // Sideband message handling for Active Entry Handshake
  when(io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.REQ_ACTIVE) {
    remote_active_entry_req_flag := true.B
  
  }.elsewhen (bringup_state_reg === RDIBringUpState.BRINGUP_DONE) {
    remote_active_entry_req_flag := false.B
  }

  // Sideband message handling for Remote Active Entry Response
  when (io.sb_rcv_vld && io.sb_rcv === RdiSideBandMessage.RSP_ACTIVE) {
    remote_active_entry_rsp_flag := true.B
  
  }.elsewhen (bringup_state_reg === RDIBringUpState.BRINGUP_DONE) {
    remote_active_entry_rsp_flag := false.B
  }

  // Sideband message handling for Local Active Entry Request
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.REQ_ACTIVE) {
    local_active_entry_req_flag := true.B
  
  }.elsewhen (bringup_state_reg === RDIBringUpState.BRINGUP_DONE) {
    local_active_entry_req_flag := false.B
  }

  // Sideband message handling for Local Active Entry Response
  when (io.sb_snd_vld && io.sb_snd === RdiSideBandMessage.RSP_ACTIVE) {
    local_active_entry_rsp_flag := true.B
  
  }.elsewhen (bringup_state_reg === RDIBringUpState.BRINGUP_DONE) {
    local_active_entry_rsp_flag := false.B
  }

  val linkreset_handshake_done = (local_linkreset_req_flag && remote_linkreset_rsp_flag) ||
    (remote_linkreset_req_flag && local_linkreset_rsp_flag)

  val disabled_handshake_done = (local_disabled_req_flag && remote_disabled_rsp_flag) || 
    (remote_disabled_req_flag && local_disabled_rsp_flag)

  val linkerror_handshake_done = (local_linkerror_req_flag && remote_linkerror_rsp_flag) || 
    (remote_linkerror_req_flag && local_linkerror_rsp_flag)

  val retrain_handshake_done = (local_retrain_req_flag && remote_retrain_rsp_flag) || 
    (remote_retrain_req_flag && local_retrain_rsp_flag)
  

  // link error combinational logic
  val linkerror_asserted = io.lp_linkerror || linkerror_internal || remote_linkerror_req_flag
  val disabled_internal = WireDefault(false.B) // TODO: Implement
  val disabled_req = io.lp_state_req === PhyState.DISABLED || disabled_internal || remote_disabled_req_flag

  val sb_snd_reg     = RegInit(RdiSideBandMessage.NOP)
  val sb_snd_vld_reg = RegInit(false.B)

  // Sideband output arbitration
  when(bringup_sb_snd_vld) {
  sb_snd_reg     := bringup_sb_snd
  sb_snd_vld_reg := true.B

  }.elsewhen(global_sb_snd_vld) {
  sb_snd_reg     := global_sb_snd
  sb_snd_vld_reg := true.B
  
  }.otherwise {
    sb_snd_reg     := RdiSideBandMessage.NOP
    sb_snd_vld_reg := false.B
  } 

  io.sb_snd     := sb_snd_reg
  io.sb_snd_vld := sb_snd_vld_reg

  // ============================================================
  // RDI bring-up sub-FSM
  // ============================================================
  switch(bringup_state_reg) {
    is(RDIBringUpState.IDLE) {
      when(bringup_start) {
        bringup_state_reg := RDIBringUpState.ACTIVE_ENTRY_HANDSHAKE
      }
    }

    is(RDIBringUpState.ACTIVE_ENTRY_HANDSHAKE) { 
      when(!local_active_entry_req_flag) {
        bringup_sb_snd := RdiSideBandMessage.REQ_ACTIVE
        bringup_sb_snd_vld := true.B
      
      }.elsewhen(remote_active_entry_req_flag && !local_active_entry_rsp_flag) {
        bringup_sb_snd := RdiSideBandMessage.RSP_ACTIVE
        bringup_sb_snd_vld := true.B
      
      }.elsewhen(remote_active_entry_rsp_flag) { // Active entry handshake complete
        bringup_state_reg := RDIBringUpState.BRINGUP_DONE
      }
    }

    is(RDIBringUpState.BRINGUP_DONE) {
      bringup_done := true.B
      
      when(!reset_to_active_inialitated) {
        bringup_state_reg := RDIBringUpState.IDLE
        bringup_done := false.B
      }
    }
  }

  switch(global_state_reg) {
    is(PhyState.RESET) {
      when(reset_to_active_inialitated) { // During bring-up, bring-up FSM takes controls over sideband interface
        global_sb_snd := RdiSideBandMessage.NOP
        global_sb_snd_vld := false.B
      }

        when(linkerror_asserted) { // LinkError request
          when(remote_linkerror_req_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_LINKERROR
            global_sb_snd_vld := true.B

          }.elsewhen(remote_notify_required) {
            global_sb_snd := RdiSideBandMessage.REQ_LINKERROR
            global_sb_snd_vld := true.B
            

          }

          when((remote_linkerror_req_flag || remote_notify_required) && linkerror_handshake_done) {
              linkerror_procedure_done := false.B
              global_state_reg := PhyState.LINKERROR
          
          }.elsewhen(!remote_linkerror_req_flag && !remote_notify_required) {
              global_state_reg := PhyState.LINKERROR
              linkerror_procedure_done := false.B
          }

        }.elsewhen(io.lp_state_req === PhyState.NOP && !reset_to_active_inialitated) { // NOP state, waiting for requests
          global_state_reg := PhyState.RESET
        
        }.elsewhen(((io.lp_state_req === PhyState.LINKRESET && lp_state_req_prev_reg === PhyState.NOP) // LinkReset request
          || remote_linkreset_req_flag) && !reset_to_active_inialitated) {
          when(remote_linkreset_req_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_LINKRESET
            global_sb_snd_vld := true.B

          }.elsewhen(remote_notify_required) {
            global_sb_snd := RdiSideBandMessage.REQ_LINKRESET
            global_sb_snd_vld := true.B
            

          }

          when ((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) {
            global_state_reg := PhyState.LINKRESET
            linkreset_procedure_done := false.B
            

          }.elsewhen(!remote_linkreset_req_flag && !remote_notify_required) {
            global_state_reg := PhyState.LINKRESET
            linkreset_procedure_done := false.B
          }
          

        }.elsewhen(((disabled_req && lp_state_req_prev_reg === PhyState.NOP) || remote_disabled_req_flag) && !reset_to_active_inialitated) { // Disabled request
            when(remote_disabled_req_flag && !local_disabled_rsp_flag) {
              global_sb_snd := RdiSideBandMessage.RSP_DISABLED
              global_sb_snd_vld := true.B

            }.elsewhen(remote_notify_required && !local_disabled_req_flag) {
              global_sb_snd := RdiSideBandMessage.REQ_DISABLED
              global_sb_snd_vld := true.B
              
            }

            when((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) {
              global_state_reg := PhyState.DISABLED
              disabled_procedure_done := false.B
              

            }.elsewhen(!remote_disabled_req_flag && !remote_notify_required) {
              global_state_reg := PhyState.DISABLED
              disabled_procedure_done := false.B

            }          

        }.elsewhen((io.lp_state_req === PhyState.ACTIVE && lp_state_req_prev_reg === PhyState.NOP) || reset_to_active_inialitated) {
          // we launch the active entry handshake
          when(!reset_to_active_inialitated) {
            bringup_start := true.B
            reset_to_active_inialitated := true.B
          }
          
          when(bringup_done && reset_to_active_inialitated) {
            global_state_reg := PhyState.ACTIVE
            reset_to_active_inialitated := false.B
            bringup_start := false.B
          }
        }
    }

    is(PhyState.ACTIVE) {
      global_sb_snd_vld := false.B
      global_sb_snd := RdiSideBandMessage.NOP
      
      when(linkerror_asserted) {
        global_state_reg := PhyState.LINKERROR

      }.elsewhen(disabled_req) {
          when(remote_disabled_req_flag && !local_disabled_rsp_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_DISABLED
            global_sb_snd_vld := true.B

          }.otherwise {
            when(remote_notify_required && !local_disabled_req_flag) {
              global_sb_snd := RdiSideBandMessage.REQ_DISABLED
              global_sb_snd_vld := true.B
              
            }
          }

          when((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) {
            disabled_procedure_done := false.B
            global_state_reg := PhyState.DISABLED
            

          }.elsewhen(!(remote_disabled_req_flag && remote_notify_required)) {
            disabled_procedure_done := false.B
            global_state_reg := PhyState.DISABLED

          }
          
      }.elsewhen(io.lp_state_req === PhyState.LINKRESET || linkreset_internal || remote_linkreset_req_flag) {
          when (remote_linkreset_req_flag && !local_linkreset_rsp_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_LINKRESET
            global_sb_snd_vld := true.B

          }.otherwise {
              when(remote_notify_required && !local_linkreset_req_flag) {
                global_sb_snd := RdiSideBandMessage.REQ_LINKRESET
                global_sb_snd_vld := true.B
                
              }
          }

          when((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) {
            linkreset_procedure_done := false.B
            global_state_reg         := PhyState.LINKRESET
            
          
          }.otherwise {
            linkreset_procedure_done := false.B
            global_state_reg         := PhyState.LINKRESET

          }

      }.elsewhen(retrain_req) {
          when (remote_retrain_req_flag && !local_retrain_rsp_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_RETRAIN
            global_sb_snd_vld := true.B

          }.otherwise {
              when(remote_notify_required && !local_retrain_req_flag) {
                global_sb_snd := RdiSideBandMessage.REQ_RETRAIN
                global_sb_snd_vld := true.B
                
              }
          }

          when((remote_retrain_req_flag || remote_notify_required) && retrain_handshake_done) {
            retrain_procedure_done := false.B
            global_state_reg         := PhyState.RETRAIN
            

          }.otherwise {
            retrain_procedure_done := false.B
            global_state_reg         := PhyState.RETRAIN

          }
      
      }
    }

    is(PhyState.RETRAIN) {
      global_sb_snd := RdiSideBandMessage.NOP
      global_sb_snd_vld := false.B
      
      when(linkerror_asserted) { // Local request of LinkError mientras estoy en Retrain
        global_state_reg        := PhyState.LINKERROR

      // Request de Disabled mientras estoy en RETRAIN
      }.elsewhen(!retrain_to_active_initiated && io.lp_state_req === PhyState.DISABLED) {
          when (remote_notify_required) {
            global_sb_snd := RdiSideBandMessage.REQ_DISABLED
            global_sb_snd_vld := true.B
            

            when (disabled_handshake_done) {
              disabled_procedure_done := false.B
              global_state_reg := PhyState.DISABLED
              
            }

          }.otherwise {
            global_state_reg := PhyState.DISABLED
          }

      // Request de LinkReset mientras estoy en RETRAIN
      }.elsewhen(!retrain_to_active_initiated && (io.lp_state_req === PhyState.LINKRESET || remote_linkreset_req_flag)) {
          when(remote_linkreset_req_flag) {
            global_sb_snd := RdiSideBandMessage.RSP_LINKRESET
            global_sb_snd_vld := true.B
          
          }.elsewhen(remote_notify_required) {
            global_sb_snd := RdiSideBandMessage.REQ_LINKRESET
            global_sb_snd_vld := true.B
            

          }

          when (remote_linkreset_req_flag || remote_notify_required) {
            when (linkreset_handshake_done) {
              global_state_reg         := PhyState.LINKRESET
              linkreset_procedure_done := false.B
              
            }

          }.otherwise {
              global_state_reg := PhyState.LINKRESET
              linkreset_procedure_done := false.B
          }


      // Active entry request
      }.elsewhen((lp_state_req_prev_reg === PhyState.NOP && io.lp_state_req === PhyState.ACTIVE) && !retrain_to_active_initiated) {
          retrain_to_active_initiated := true.B
          bringup_start := true.B // we can reuse the bringup FSM for the active entry handshake during retrain

      }.elsewhen(retrain_to_active_initiated) { // Active entry Handshake in progress
          when(bringup_done) {
            global_state_reg        := PhyState.ACTIVE
            retrain_to_active_initiated := false.B
            bringup_start := false.B
          }
        }
    }

    is(PhyState.LINKRESET) { // check if we need TODO something in LINKRESET (like reset registers, flags, etc.. )
      global_sb_snd := RdiSideBandMessage.NOP
      global_sb_snd_vld := false.B


      when(io.lp_linkerror || linkerror_internal) {
        global_state_reg := PhyState.LINKERROR

      }.elsewhen(disabled_internal || io.lp_state_req === PhyState.DISABLED) {
        global_state_reg := PhyState.DISABLED

      }.elsewhen((io.lp_state_req === PhyState.ACTIVE || reset_internal) && linkreset_procedure_done) {
        global_state_reg := PhyState.RESET // LINKRESET -> RESET -> ACTIVE
      
      }.elsewhen(!linkreset_procedure_done) {

        // TODO: Implement LinkReset state actions
        
        when (true.B) { // TODO: Define the conditions for completing the LinkReset procedure.
          linkreset_procedure_done := true.B

        }
      }

    }

    is(PhyState.DISABLED) {
      global_sb_snd := RdiSideBandMessage.NOP 
      global_sb_snd_vld := false.B

      when(io.lp_linkerror || linkerror_internal) {
        global_state_reg := PhyState.LINKERROR
      
      }.elsewhen((io.lp_state_req === PhyState.ACTIVE || reset_internal) && disabled_procedure_done) { // DISABLED -> RESET -> ACTIVE
        global_state_reg := PhyState.RESET

      }.elsewhen(!disabled_procedure_done) {
         
        // TODO: Define Disabled state actions

        // Check if all procedures for DISABLED state are done
        when (true.B) { // TODO: Define the conditions for completing the Disabled procedure.
          disabled_procedure_done := true.B

        }
      }
    }

    // The lower layer may enter LinkError state due to Internal LinkError requests such as when:
    //  - Encountering uncorrectable errors due to hardware failure or directed by Upper Layer
    //  - Remote Link partner requests entry into LinkError (RDI only) 

    is(PhyState.LINKERROR) {
      global_sb_snd := RdiSideBandMessage.NOP
      global_sb_snd_vld := false.B
      // CHECK: If I need to make anything

      when(!linkerror_procedure_done) {

        // TODO: Linkerror state actions

        linkerror_procedure_done := true.B
      }

      when(io.lp_linkerror || linkerror_internal || remote_linkerror_req_flag) { // LinkError request
        global_state_reg := PhyState.LINKERROR
        linkerror_procedure_done := false.B 

      }.elsewhen(reset_internal || (io.lp_state_req === PhyState.ACTIVE && !io.lp_linkerror && rdi_timeout.io.linkErrorResidencyDone)) {
        global_state_reg := PhyState.RESET
      }
    }
  }
}

