// Hand-translated synthesizable SystemVerilog.
// Source: RdiLinkManagementController(20260805-195425).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module RdiLinkManagementController (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic ltsm_lp_wake_req,
  output var logic ltsm_pl_wake_ack,

  output var logic ltsm_pl_clk_req,
  input  wire logic ltsm_lp_clk_ack,

  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t lp_state_req,
  output var UcieUPM_interfaces_pkg::PhyState_t    pl_state_sts,

  output var logic pl_stallreq,
  input  wire logic lp_stallack,

  output var logic rdi_pl_inband_pres,
  input  wire logic ltsm_pl_inband_pres,

  input  wire logic fdiNeedsRdiAwake,
  output var logic rdiAwake,
  output var logic rdiNeedsFdiAwake,
  input  wire logic fdiAwake,

  output var logic         sb_snd_valid,
  output var logic [127:0] sb_snd_msg,
  input  wire logic         sb_snd_ready,

  input  wire logic         sb_rcv_valid,
  input  wire logic [127:0] sb_rcv_msg,
  output var logic         sb_rcv_ready,

  input  wire logic lp_linkerror,

  output var logic        pl_phyinrecenter,
  input  wire logic [31:0] cycles_1us
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_rdi_link_management_pkg::*;
  import SidebandMsgGenerator_pkg::*;

  function automatic logic [127:0] zeroMessage();
    zeroMessage = 128'b0;
  endfunction

  // Registered sideband producer.
  (* keep = "true" *) logic [127:0] sb_snd_msg_reg;
  (* keep = "true" *) logic         sb_snd_vld_reg;
  logic [127:0] sb_snd_msg_reg_next;
  logic         sb_snd_vld_reg_next;

  logic [127:0] sb_snd_msg_next;
  logic         sb_snd_vld_next;
  logic [127:0] bringup_sb_snd;
  logic         bringup_sb_snd_vld;
  logic [127:0] global_sb_snd;
  logic         global_sb_snd_vld;

  assign sb_snd_msg   = sb_snd_msg_reg;
  assign sb_snd_valid = sb_snd_vld_reg;
  assign sb_rcv_ready = 1'b1;

  logic txFire;
  logic rxFire;
  assign txFire = sb_snd_valid && sb_snd_ready;
  assign rxFire = sb_rcv_valid && sb_rcv_ready;

  // Sideband decode signals retain their Chisel names for waveform readability.
  (* keep = "true" *) logic [127:0] tx_message;
  (* keep = "true" *) logic [127:0] rx_message;
  (* keep = "true" *) logic [63:0]  tx_header;
  (* keep = "true" *) logic [63:0]  rx_header;
  (* keep = "true" *) logic [7:0]   tx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgSub;
  (* keep = "true" *) logic [7:0]   tx_msgCode;
  (* keep = "true" *) logic [7:0]   rx_msgCode;
  (* keep = "true" *) logic [15:0]  rx_msgInfo;

  logic tx_is_rdi_req;
  logic tx_is_rdi_rsp;
  logic rx_is_rdi_req;
  logic rx_is_rdi_rsp;
  logic rx_is_rdi_rsp_stall;

  assign tx_message = sb_snd_msg_reg;
  assign rx_message = sb_rcv_msg;
  assign tx_header  = headerOf(tx_message);
  assign rx_header  = headerOf(rx_message);
  assign tx_msgSub  = UCIe2_Field_msgSub({64'b0, tx_header});
  assign rx_msgSub  = UCIe2_Field_msgSub({64'b0, rx_header});
  assign tx_msgCode = UCIe2_Field_msgCode({64'b0, tx_header});
  assign rx_msgCode = UCIe2_Field_msgCode({64'b0, rx_header});
  assign rx_msgInfo = UCIe2_Field_msgInfo({64'b0, rx_header});

  assign tx_is_rdi_req = UCIe2_isRdiLinkMgmtReq({64'b0, tx_header});
  assign tx_is_rdi_rsp = UCIe2_isRdiLinkMgmtRsp({64'b0, tx_header});
  assign rx_is_rdi_req = rxFire && UCIe2_isRdiLinkMgmtReq({64'b0, rx_header});
  assign rx_is_rdi_rsp = rxFire && UCIe2_isRdiLinkMgmtRsp({64'b0, rx_header});
  assign rx_is_rdi_rsp_stall = rx_is_rdi_rsp && (rx_msgInfo == UCIe2_MsgInfo_STALL);

  function automatic logic txIsRdiReq(input logic [7:0] sub);
    txIsRdiReq = txFire && tx_is_rdi_req && (tx_msgSub == sub);
  endfunction
  function automatic logic txIsRdiRsp(input logic [7:0] sub);
    txIsRdiRsp = txFire && tx_is_rdi_rsp && (tx_msgSub == sub);
  endfunction
  function automatic logic rxIsRdiReq(input logic [7:0] sub);
    rxIsRdiReq = rx_is_rdi_req && (rx_msgSub == sub);
  endfunction
  function automatic logic rxIsRdiRsp(input logic [7:0] sub);
    rxIsRdiRsp = rx_is_rdi_rsp && (rx_msgSub == sub);
  endfunction

  (* keep = "true" *) RDIBringUpState_t bringup_state_reg;
  RDIBringUpState_t bringup_state_reg_next;
  (* keep = "true" *) PhyState_t global_state_reg;
  PhyState_t global_state_reg_next;

  assign pl_state_sts       = global_state_reg;
  assign pl_phyinrecenter   = 1'b0;
  assign rdiNeedsFdiAwake   = 1'b1;
  assign ltsm_pl_clk_req    = 1'b1;

  logic rdiAwake_reg;
  logic ltsm_pl_wake_ack_reg;
  assign rdiAwake          = rdiAwake_reg;
  assign ltsm_pl_wake_ack  = ltsm_pl_wake_ack_reg;

  logic link_down_state;
  logic remote_notify_required;
  assign link_down_state = (global_state_reg == PhyState_linkError) ||
                           (global_state_reg == PhyState_disabled) ||
                           (global_state_reg == PhyState_linkReset);
  assign remote_notify_required = !(link_down_state && !pl_phyinrecenter);

  // Stall controller.
  logic stall_start;
  logic stall_release;
  logic stall_req;
  (* keep = "true" *) logic stallhandler_handshake_done;
  (* keep = "true" *) logic stall_4phase_done;
  (* keep = "true" *) logic stall_busy;

  StallCtrl stall_module (
    .clock   (clock),
    .reset_n   (reset_n),
    .start   (stall_start),
    .release_i (stall_release),
    .ack     (lp_stallack),
    .req     (stall_req),
    .aligned (stallhandler_handshake_done),
    .done    (stall_4phase_done),
    .busy    (stall_busy)
  );
  assign pl_stallreq = stall_req;

  (* keep = "true" *) logic retrain_to_active_initiated;
  logic retrain_to_active_initiated_next;
  wire retrain_internal = 1'b0;

  (* keep = "true" *) PhyStateReq_t lp_state_req_prev_reg;
  wire reset_internal = !reset_n;

  (* keep = "true" *) logic [7:0] pending_req_sub_reg;
  (* keep = "true" *) logic       waiting_rsp_reg;
  logic [7:0] pending_req_sub_reg_next;
  logic       waiting_rsp_reg_next;

  logic local_req_sent;
  logic sideband_stall_received;
  logic expected_remote_rsp_received;
  assign local_req_sent = txFire && tx_is_rdi_req;
  assign sideband_stall_received = waiting_rsp_reg && rx_is_rdi_rsp_stall &&
                                   (rx_msgSub == pending_req_sub_reg);
  assign expected_remote_rsp_received = waiting_rsp_reg && rx_is_rdi_rsp &&
                                        !rx_is_rdi_rsp_stall &&
                                        (rx_msgSub == pending_req_sub_reg);

  logic rdi_timeout_sidebandReqTimerBusy;
  logic rdi_timeout_sidebandReqTimeoutFlag;
  logic rdi_timeout_stallRefreshDue;
  logic rdi_timeout_linkErrorResidencyDone;

  RdiTimeoutController rdi_timeout (
    .clock                     (clock),
    .reset_n                   (reset_n),
    .cycles1us                 (cycles_1us),
    .startSidebandReqTimer     (local_req_sent),
    .sidebandRspReceived       (expected_remote_rsp_received),
    .sidebandStallReceived     (sideband_stall_received),
    .clearSidebandReqTimer     (!reset_n || (global_state_reg == PhyState_linkError)),
    .sidebandReqTimerBusy      (rdi_timeout_sidebandReqTimerBusy),
    .sidebandReqTimeoutFlag    (rdi_timeout_sidebandReqTimeoutFlag),
    .clearTimeoutFlag          (!reset_n || (global_state_reg == PhyState_linkError)),
    .stallResponseActive       (1'b0),
    .stallSent                 (1'b0),
    .stallRefreshDue           (rdi_timeout_stallRefreshDue),
    .inLinkError               (global_state_reg == PhyState_linkError),
    .linkErrorResidencyDone    (rdi_timeout_linkErrorResidencyDone)
  );

  wire linkerror_internal = rdi_timeout_sidebandReqTimeoutFlag;

  (* keep = "true" *) logic disabled_procedure_done;
  (* keep = "true" *) logic linkreset_procedure_done;
  (* keep = "true" *) logic retrain_procedure_done;
  (* keep = "true" *) logic linkerror_procedure_done;
  logic disabled_procedure_done_next;
  logic linkreset_procedure_done_next;
  logic retrain_procedure_done_next;
  logic linkerror_procedure_done_next;

  wire linkreset_internal = 1'b0;

  (* keep = "true" *) logic reset_to_active_inialitated;
  logic reset_to_active_inialitated_next;
  (* keep = "true" *) logic bringup_start;
  logic bringup_start_next;
  (* keep = "true" *) logic bringup_done;
  logic bringup_done_next;

  (* keep = "true" *) logic remote_linkerror_req_flag;
  (* keep = "true" *) logic remote_linkerror_rsp_flag;
  (* keep = "true" *) logic local_linkerror_req_flag;
  (* keep = "true" *) logic local_linkerror_rsp_flag;
  logic remote_linkerror_req_flag_next;
  logic remote_linkerror_rsp_flag_next;
  logic local_linkerror_req_flag_next;
  logic local_linkerror_rsp_flag_next;

  (* keep = "true" *) logic remote_disabled_req_flag;
  (* keep = "true" *) logic remote_disabled_rsp_flag;
  (* keep = "true" *) logic local_disabled_req_flag;
  (* keep = "true" *) logic local_disabled_rsp_flag;
  logic remote_disabled_req_flag_next;
  logic remote_disabled_rsp_flag_next;
  logic local_disabled_req_flag_next;
  logic local_disabled_rsp_flag_next;

  (* keep = "true" *) logic remote_linkreset_req_flag;
  (* keep = "true" *) logic remote_linkreset_rsp_flag;
  (* keep = "true" *) logic local_linkreset_req_flag;
  (* keep = "true" *) logic local_linkreset_rsp_flag;
  logic remote_linkreset_req_flag_next;
  logic remote_linkreset_rsp_flag_next;
  logic local_linkreset_req_flag_next;
  logic local_linkreset_rsp_flag_next;

  (* keep = "true" *) logic remote_retrain_req_flag;
  (* keep = "true" *) logic remote_retrain_rsp_flag;
  (* keep = "true" *) logic local_retrain_req_flag;
  (* keep = "true" *) logic local_retrain_rsp_flag;
  logic remote_retrain_req_flag_next;
  logic remote_retrain_rsp_flag_next;
  logic local_retrain_req_flag_next;
  logic local_retrain_rsp_flag_next;

  (* keep = "true" *) logic remote_active_entry_req_flag;
  (* keep = "true" *) logic remote_active_entry_rsp_flag;
  (* keep = "true" *) logic local_active_entry_req_flag;
  (* keep = "true" *) logic local_active_entry_rsp_flag;
  logic remote_active_entry_req_flag_next;
  logic remote_active_entry_rsp_flag_next;
  logic local_active_entry_req_flag_next;
  logic local_active_entry_rsp_flag_next;

  logic linkreset_handshake_done;
  logic disabled_handshake_done;
  logic linkerror_handshake_done;
  logic retrain_handshake_done;
  assign linkreset_handshake_done =
    (local_linkreset_req_flag && remote_linkreset_rsp_flag) ||
    (remote_linkreset_req_flag && local_linkreset_rsp_flag);
  assign disabled_handshake_done =
    (local_disabled_req_flag && remote_disabled_rsp_flag) ||
    (remote_disabled_req_flag && local_disabled_rsp_flag);
  assign linkerror_handshake_done =
    (local_linkerror_req_flag && remote_linkerror_rsp_flag) ||
    (remote_linkerror_req_flag && local_linkerror_rsp_flag);
  assign retrain_handshake_done =
    (local_retrain_req_flag && remote_retrain_rsp_flag) ||
    (remote_retrain_req_flag && local_retrain_rsp_flag);

  logic linkerror_asserted;
  wire disabled_internal = 1'b0;
  logic disabled_req;
  logic retrain_req;
  logic linkreset_req;
  assign linkerror_asserted = lp_linkerror || linkerror_internal || remote_linkerror_req_flag;
  assign disabled_req = (lp_state_req == PhyStateReq_disabled) || disabled_internal || remote_disabled_req_flag;
  assign retrain_req  = (lp_state_req == PhyStateReq_retrain) || retrain_internal || remote_retrain_req_flag;
  assign linkreset_req = (lp_state_req == PhyStateReq_linkReset) || linkreset_internal || remote_linkreset_req_flag;

  (* keep = "true" *) logic nopToActive;
  (* keep = "true" *) logic nopToDisabled;
  (* keep = "true" *) logic nopToLinkreset;

  (* keep = "true" *) logic pendingDisabledFromReset;
  (* keep = "true" *) logic pendingLinkresetFromReset;
  logic pendingDisabledFromReset_next;
  logic pendingLinkresetFromReset_next;

  logic disabled_entry_rst;
  logic linkreset_entry_rst;
  assign disabled_entry_rst = pendingDisabledFromReset || nopToDisabled ||
                              disabled_internal || remote_disabled_req_flag;
  assign linkreset_entry_rst = pendingLinkresetFromReset || nopToLinkreset ||
                               linkreset_internal || remote_linkreset_req_flag;

  logic active_exit_needs_stall;
  assign active_exit_needs_stall = (global_state_reg == PhyState_active) &&
                                   !linkerror_asserted &&
                                   (disabled_req || linkreset_req || retrain_req);
  assign stall_start   = active_exit_needs_stall && !stall_busy;
  assign stall_release = (global_state_reg != PhyState_active);

  logic rdiStateAllowsInband;
  logic rdiPlInbandPresNext;
  (* keep = "true" *) logic rdiPlInbandPresReg;
  assign rdiStateAllowsInband = (global_state_reg == PhyState_reset) ||
                                (global_state_reg == PhyState_active) ||
                                (global_state_reg == PhyState_retrain);
  assign rdiPlInbandPresNext = ltsm_pl_inband_pres && rdiStateAllowsInband &&
                               !linkerror_asserted;
  assign rdi_pl_inband_pres = rdiPlInbandPresReg;

  // Combinational next-state logic. Register expressions use current register values,
  // matching Chisel's synchronous Reg semantics and source-order connection priority.
  always_comb begin
    sb_snd_msg_reg_next = sb_snd_msg_reg;
    sb_snd_vld_reg_next = sb_snd_vld_reg;

    bringup_state_reg_next = bringup_state_reg;
    global_state_reg_next  = global_state_reg;
    retrain_to_active_initiated_next = retrain_to_active_initiated;
    pending_req_sub_reg_next = pending_req_sub_reg;
    waiting_rsp_reg_next     = waiting_rsp_reg;

    disabled_procedure_done_next = disabled_procedure_done;
    linkreset_procedure_done_next = linkreset_procedure_done;
    retrain_procedure_done_next   = retrain_procedure_done;
    linkerror_procedure_done_next = linkerror_procedure_done;

    reset_to_active_inialitated_next = reset_to_active_inialitated;
    bringup_start_next = bringup_start;
    bringup_done_next  = bringup_done;

    remote_linkerror_req_flag_next = remote_linkerror_req_flag;
    remote_linkerror_rsp_flag_next = remote_linkerror_rsp_flag;
    local_linkerror_req_flag_next  = local_linkerror_req_flag;
    local_linkerror_rsp_flag_next  = local_linkerror_rsp_flag;

    remote_disabled_req_flag_next = remote_disabled_req_flag;
    remote_disabled_rsp_flag_next = remote_disabled_rsp_flag;
    local_disabled_req_flag_next  = local_disabled_req_flag;
    local_disabled_rsp_flag_next  = local_disabled_rsp_flag;

    remote_linkreset_req_flag_next = remote_linkreset_req_flag;
    remote_linkreset_rsp_flag_next = remote_linkreset_rsp_flag;
    local_linkreset_req_flag_next  = local_linkreset_req_flag;
    local_linkreset_rsp_flag_next  = local_linkreset_rsp_flag;

    remote_retrain_req_flag_next = remote_retrain_req_flag;
    remote_retrain_rsp_flag_next = remote_retrain_rsp_flag;
    local_retrain_req_flag_next  = local_retrain_req_flag;
    local_retrain_rsp_flag_next  = local_retrain_rsp_flag;

    remote_active_entry_req_flag_next = remote_active_entry_req_flag;
    remote_active_entry_rsp_flag_next = remote_active_entry_rsp_flag;
    local_active_entry_req_flag_next  = local_active_entry_req_flag;
    local_active_entry_rsp_flag_next  = local_active_entry_rsp_flag;

    pendingDisabledFromReset_next  = pendingDisabledFromReset;
    pendingLinkresetFromReset_next = pendingLinkresetFromReset;

    bringup_sb_snd     = zeroMessage();
    bringup_sb_snd_vld = 1'b0;
    global_sb_snd      = zeroMessage();
    global_sb_snd_vld  = 1'b0;
    sb_snd_msg_next    = zeroMessage();
    sb_snd_vld_next    = 1'b0;

    // Outstanding request tracking.
    if (global_state_reg == PhyState_linkError) begin
      pending_req_sub_reg_next = 8'd0;
      waiting_rsp_reg_next     = 1'b0;
    end else if (local_req_sent) begin
      pending_req_sub_reg_next = tx_msgSub;
      waiting_rsp_reg_next     = 1'b1;
    end else if (expected_remote_rsp_received) begin
      waiting_rsp_reg_next = 1'b0;
    end

    // Sideband transaction flags.
    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_LINKERROR))
      remote_linkerror_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      remote_linkerror_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKERROR))
      remote_linkerror_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      remote_linkerror_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_LINKERROR))
      local_linkerror_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      local_linkerror_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKERROR))
      local_linkerror_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkError)
      local_linkerror_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_DISABLE))
      remote_disabled_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      remote_disabled_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      remote_disabled_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      remote_disabled_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_DISABLE))
      local_disabled_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      local_disabled_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      local_disabled_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_disabled)
      local_disabled_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      remote_linkreset_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      remote_linkreset_req_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      local_linkreset_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      local_linkreset_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      remote_linkreset_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      remote_linkreset_rsp_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      local_linkreset_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_linkReset)
      local_linkreset_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_RETRAIN))
      remote_retrain_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      remote_retrain_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_RETRAIN))
      remote_retrain_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      remote_retrain_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_RETRAIN))
      local_retrain_req_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      local_retrain_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_RETRAIN))
      local_retrain_rsp_flag_next = 1'b1;
    else if (global_state_reg == PhyState_retrain)
      local_retrain_rsp_flag_next = 1'b0;

    if (rxIsRdiReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      remote_active_entry_req_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      remote_active_entry_req_flag_next = 1'b0;

    if (rxIsRdiRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      remote_active_entry_rsp_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      remote_active_entry_rsp_flag_next = 1'b0;

    if (txIsRdiReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      local_active_entry_req_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      local_active_entry_req_flag_next = 1'b0;

    if (txIsRdiRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      local_active_entry_rsp_flag_next = 1'b1;
    else if (bringup_state_reg == RDIBringUpState_BRINGUP_DONE)
      local_active_entry_rsp_flag_next = 1'b0;

    // Latch Reset-exit requests using the registered NOP transition indicators.
    if (global_state_reg != PhyState_reset) begin
      pendingDisabledFromReset_next  = 1'b0;
      pendingLinkresetFromReset_next = 1'b0;
    end else begin
      if (nopToDisabled)
        pendingDisabledFromReset_next = 1'b1;
      if (nopToLinkreset)
        pendingLinkresetFromReset_next = 1'b1;
    end

    // RDI bring-up sub-FSM.
    case (bringup_state_reg)
      RDIBringUpState_IDLE: begin
        if (bringup_start)
          bringup_state_reg_next = RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE;
      end

      RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE: begin
        if (!local_active_entry_req_flag) begin
          bringup_sb_snd = UCIe2_RDI_reqActive(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
          bringup_sb_snd_vld = 1'b1;
        end else if (remote_active_entry_req_flag && !local_active_entry_rsp_flag) begin
          bringup_sb_snd = UCIe2_RDI_rspActive(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                               UCIe2_MsgInfo_REGULAR);
          bringup_sb_snd_vld = 1'b1;
        end else if (remote_active_entry_rsp_flag) begin
          bringup_state_reg_next = RDIBringUpState_BRINGUP_DONE;
        end
      end

      RDIBringUpState_BRINGUP_DONE: begin
        bringup_done_next = 1'b1;
        if (global_state_reg == PhyState_active) begin
          bringup_state_reg_next = RDIBringUpState_IDLE;
          bringup_done_next = 1'b0;
        end
      end

      default: bringup_state_reg_next = RDIBringUpState_IDLE;
    endcase

    // Global RDI state machine.
    case (global_state_reg)
      PhyState_reset: begin
        if (reset_to_active_inialitated) begin
          global_sb_snd     = zeroMessage();
          global_sb_snd_vld = 1'b0;
        end

        if (linkerror_asserted) begin
          if (remote_linkerror_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end
          linkerror_procedure_done_next = 1'b0;
          global_state_reg_next = PhyState_linkError;
        end else if ((lp_state_req == PhyStateReq_nop) && !reset_to_active_inialitated) begin
          global_state_reg_next = PhyState_reset;
        end else if (disabled_entry_rst && !reset_to_active_inialitated) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) begin
            global_state_reg_next = PhyState_disabled;
            disabled_procedure_done_next = 1'b0;
          end else if (!remote_disabled_req_flag && !remote_notify_required) begin
            global_state_reg_next = PhyState_disabled;
            disabled_procedure_done_next = 1'b0;
          end
        end else if (linkreset_entry_rst && !reset_to_active_inialitated) begin
          if (remote_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end else if (!remote_linkreset_req_flag && !remote_notify_required) begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end
        end else if (((lp_state_req == PhyStateReq_active) &&
                      (lp_state_req_prev_reg == PhyStateReq_nop)) ||
                     reset_to_active_inialitated) begin
          if (!reset_to_active_inialitated) begin
            bringup_start_next = 1'b1;
            reset_to_active_inialitated_next = 1'b1;
          end
          if (bringup_done && reset_to_active_inialitated) begin
            global_state_reg_next = PhyState_active;
            reset_to_active_inialitated_next = 1'b0;
            bringup_start_next = 1'b0;
          end
        end
      end

      PhyState_active: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (linkerror_asserted) begin
          if (remote_linkerror_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkError(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end
          linkerror_procedure_done_next = 1'b0;
          global_state_reg_next = PhyState_linkError;
        end else if (disabled_req && stallhandler_handshake_done) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_disabled_req_flag || remote_notify_required) && disabled_handshake_done) begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end else if (!(remote_disabled_req_flag || remote_notify_required)) begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end
        end else if (linkreset_req && stallhandler_handshake_done) begin
          if (remote_linkreset_req_flag && !local_linkreset_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_linkreset_req_flag || remote_notify_required) && linkreset_handshake_done) begin
            linkreset_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_linkReset;
          end else if (!(remote_linkreset_req_flag || remote_notify_required)) begin
            linkreset_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_linkReset;
          end
        end else if (retrain_req && stallhandler_handshake_done) begin
          if (remote_retrain_req_flag && !local_retrain_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspRetrain(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_retrain_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqRetrain(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if ((remote_retrain_req_flag || remote_notify_required) && retrain_handshake_done) begin
            retrain_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_retrain;
          end else if (!remote_retrain_req_flag && !remote_notify_required) begin
            retrain_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_retrain;
          end
        end
      end

      PhyState_retrain: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (linkerror_asserted) begin
          global_state_reg_next = PhyState_linkError;
        end else if (!retrain_to_active_initiated &&
                     ((lp_state_req == PhyStateReq_disabled) || remote_disabled_req_flag)) begin
          if (remote_disabled_req_flag && !local_disabled_rsp_flag) begin
            global_sb_snd = UCIe2_RDI_rspDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                 UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required && !local_disabled_req_flag) begin
            global_sb_snd = UCIe2_RDI_reqDisable(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if (remote_disabled_req_flag || remote_notify_required) begin
            if (disabled_handshake_done) begin
              disabled_procedure_done_next = 1'b0;
              global_state_reg_next = PhyState_disabled;
            end
          end else begin
            disabled_procedure_done_next = 1'b0;
            global_state_reg_next = PhyState_disabled;
          end
        end else if (!retrain_to_active_initiated &&
                     ((lp_state_req == PhyStateReq_linkReset) || remote_linkreset_req_flag)) begin
          if (remote_linkreset_req_flag) begin
            global_sb_snd = UCIe2_RDI_rspLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY,
                                                   UCIe2_MsgInfo_REGULAR);
            global_sb_snd_vld = 1'b1;
          end else if (remote_notify_required) begin
            global_sb_snd = UCIe2_RDI_reqLinkReset(ENDPOINT_PHY, ENDPOINT_REMOTE_PHY);
            global_sb_snd_vld = 1'b1;
          end

          if (remote_linkreset_req_flag || remote_notify_required) begin
            if (linkreset_handshake_done) begin
              global_state_reg_next = PhyState_linkReset;
              linkreset_procedure_done_next = 1'b0;
            end
          end else begin
            global_state_reg_next = PhyState_linkReset;
            linkreset_procedure_done_next = 1'b0;
          end
        end else if ((lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (lp_state_req == PhyStateReq_active) &&
                     !retrain_to_active_initiated) begin
          retrain_to_active_initiated_next = 1'b1;
          bringup_start_next = 1'b1;
        end else if (retrain_to_active_initiated) begin
          if (bringup_done) begin
            global_state_reg_next = PhyState_active;
            retrain_to_active_initiated_next = 1'b0;
            bringup_start_next = 1'b0;
          end
        end
      end

      PhyState_linkReset: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (lp_linkerror || linkerror_internal) begin
          global_state_reg_next = PhyState_linkError;
        end else if (disabled_internal || (lp_state_req == PhyStateReq_disabled)) begin
          global_state_reg_next = PhyState_disabled;
        end else if (((lp_state_req == PhyStateReq_active) || reset_internal) &&
                     linkreset_procedure_done) begin
          global_state_reg_next = PhyState_reset;
        end else if (!linkreset_procedure_done) begin
          // Source TODO completion condition is currently true.B.
          linkreset_procedure_done_next = 1'b1;
        end
      end

      PhyState_disabled: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (lp_linkerror || linkerror_internal) begin
          global_state_reg_next = PhyState_linkError;
        end else if (((lp_state_req == PhyStateReq_active) || reset_internal) &&
                     disabled_procedure_done) begin
          global_state_reg_next = PhyState_reset;
        end else if (!disabled_procedure_done) begin
          // Source TODO completion condition is currently true.B.
          disabled_procedure_done_next = 1'b1;
        end
      end

      PhyState_linkError: begin
        global_sb_snd     = zeroMessage();
        global_sb_snd_vld = 1'b0;

        if (!linkerror_procedure_done)
          linkerror_procedure_done_next = 1'b1;

        if (lp_linkerror || linkerror_internal || remote_linkerror_req_flag) begin
          global_state_reg_next = PhyState_linkError;
          linkerror_procedure_done_next = 1'b0;
        end else if (reset_internal ||
                     ((lp_state_req == PhyStateReq_active) && !lp_linkerror &&
                      rdi_timeout_linkErrorResidencyDone)) begin
          global_state_reg_next = PhyState_reset;
        end
      end

      default: global_state_reg_next = PhyState_reset;
    endcase

    // Sideband source arbitration: bring-up has priority over global transitions.
    if (bringup_sb_snd_vld) begin
      sb_snd_msg_next = bringup_sb_snd;
      sb_snd_vld_next = 1'b1;
    end else if (global_sb_snd_vld) begin
      sb_snd_msg_next = global_sb_snd;
      sb_snd_vld_next = 1'b1;
    end

    // Hold a pending valid message until accepted. A firing cycle clears the
    // register and does not simultaneously load another candidate, matching Chisel.
    if (sb_snd_vld_reg) begin
      if (txFire) begin
        sb_snd_msg_reg_next = zeroMessage();
        sb_snd_vld_reg_next = 1'b0;
      end
    end else begin
      sb_snd_msg_reg_next = sb_snd_msg_next;
      sb_snd_vld_reg_next = sb_snd_vld_next;
    end
  end

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      sb_snd_msg_reg <= 128'b0;
      sb_snd_vld_reg <= 1'b0;
      bringup_state_reg <= RDIBringUpState_IDLE;
      global_state_reg  <= PhyState_reset;
      rdiAwake_reg <= 1'b0;
      ltsm_pl_wake_ack_reg <= 1'b0;
      retrain_to_active_initiated <= 1'b0;
      lp_state_req_prev_reg <= PhyStateReq_nop;
      pending_req_sub_reg <= 8'd0;
      waiting_rsp_reg <= 1'b0;
      disabled_procedure_done <= 1'b1;
      linkreset_procedure_done <= 1'b1;
      retrain_procedure_done <= 1'b1;
      linkerror_procedure_done <= 1'b1;
      reset_to_active_inialitated <= 1'b0;
      bringup_start <= 1'b0;
      bringup_done <= 1'b0;
      remote_linkerror_req_flag <= 1'b0;
      remote_linkerror_rsp_flag <= 1'b0;
      local_linkerror_req_flag <= 1'b0;
      local_linkerror_rsp_flag <= 1'b0;
      remote_disabled_req_flag <= 1'b0;
      remote_disabled_rsp_flag <= 1'b0;
      local_disabled_req_flag <= 1'b0;
      local_disabled_rsp_flag <= 1'b0;
      remote_linkreset_req_flag <= 1'b0;
      remote_linkreset_rsp_flag <= 1'b0;
      local_linkreset_req_flag <= 1'b0;
      local_linkreset_rsp_flag <= 1'b0;
      remote_retrain_req_flag <= 1'b0;
      remote_retrain_rsp_flag <= 1'b0;
      local_retrain_req_flag <= 1'b0;
      local_retrain_rsp_flag <= 1'b0;
      remote_active_entry_req_flag <= 1'b0;
      remote_active_entry_rsp_flag <= 1'b0;
      local_active_entry_req_flag <= 1'b0;
      local_active_entry_rsp_flag <= 1'b0;
      nopToActive <= 1'b0;
      nopToDisabled <= 1'b0;
      nopToLinkreset <= 1'b0;
      pendingDisabledFromReset <= 1'b0;
      pendingLinkresetFromReset <= 1'b0;
      rdiPlInbandPresReg <= 1'b0;
    end else begin
      sb_snd_msg_reg <= sb_snd_msg_reg_next;
      sb_snd_vld_reg <= sb_snd_vld_reg_next;
      bringup_state_reg <= bringup_state_reg_next;
      global_state_reg  <= global_state_reg_next;
      rdiAwake_reg <= fdiNeedsRdiAwake;
      ltsm_pl_wake_ack_reg <= ltsm_lp_wake_req;
      retrain_to_active_initiated <= retrain_to_active_initiated_next;
      lp_state_req_prev_reg <= lp_state_req;
      pending_req_sub_reg <= pending_req_sub_reg_next;
      waiting_rsp_reg <= waiting_rsp_reg_next;
      disabled_procedure_done <= disabled_procedure_done_next;
      linkreset_procedure_done <= linkreset_procedure_done_next;
      retrain_procedure_done <= retrain_procedure_done_next;
      linkerror_procedure_done <= linkerror_procedure_done_next;
      reset_to_active_inialitated <= reset_to_active_inialitated_next;
      bringup_start <= bringup_start_next;
      bringup_done <= bringup_done_next;
      remote_linkerror_req_flag <= remote_linkerror_req_flag_next;
      remote_linkerror_rsp_flag <= remote_linkerror_rsp_flag_next;
      local_linkerror_req_flag <= local_linkerror_req_flag_next;
      local_linkerror_rsp_flag <= local_linkerror_rsp_flag_next;
      remote_disabled_req_flag <= remote_disabled_req_flag_next;
      remote_disabled_rsp_flag <= remote_disabled_rsp_flag_next;
      local_disabled_req_flag <= local_disabled_req_flag_next;
      local_disabled_rsp_flag <= local_disabled_rsp_flag_next;
      remote_linkreset_req_flag <= remote_linkreset_req_flag_next;
      remote_linkreset_rsp_flag <= remote_linkreset_rsp_flag_next;
      local_linkreset_req_flag <= local_linkreset_req_flag_next;
      local_linkreset_rsp_flag <= local_linkreset_rsp_flag_next;
      remote_retrain_req_flag <= remote_retrain_req_flag_next;
      remote_retrain_rsp_flag <= remote_retrain_rsp_flag_next;
      local_retrain_req_flag <= local_retrain_req_flag_next;
      local_retrain_rsp_flag <= local_retrain_rsp_flag_next;
      remote_active_entry_req_flag <= remote_active_entry_req_flag_next;
      remote_active_entry_rsp_flag <= remote_active_entry_rsp_flag_next;
      local_active_entry_req_flag <= local_active_entry_req_flag_next;
      local_active_entry_rsp_flag <= local_active_entry_rsp_flag_next;
      nopToActive <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (lp_state_req == PhyStateReq_active);
      nopToDisabled <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                       (lp_state_req == PhyStateReq_disabled);
      nopToLinkreset <= (lp_state_req_prev_reg == PhyStateReq_nop) &&
                        (lp_state_req == PhyStateReq_linkReset);
      pendingDisabledFromReset <= pendingDisabledFromReset_next;
      pendingLinkresetFromReset <= pendingLinkresetFromReset_next;
      rdiPlInbandPresReg <= rdiPlInbandPresNext;
    end
  end

  // Deliberately unused in the source revision; retained as named signals/ports.
  wire _unused_ok = &{1'b0, ltsm_lp_clk_ack, fdiAwake,
                      rdi_timeout_sidebandReqTimerBusy,
                      rdi_timeout_stallRefreshDue,
                      linkerror_handshake_done,
                      stall_4phase_done};
endmodule

`default_nettype wire
