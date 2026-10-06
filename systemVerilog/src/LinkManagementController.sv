// Hand-translated synthesizable SystemVerilog.
// Source: LinkManagementController(1).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module LinkManagementController #(
  parameter int unsigned FDI_WIDTH          = UcieUPM_fdi_params_pkg::FDI_WIDTH,
  parameter int unsigned FDI_DLLP_WIDTH     = UcieUPM_fdi_params_pkg::FDI_DLLP_WIDTH,
  parameter int unsigned FDI_SB_WIDTH       = UcieUPM_fdi_params_pkg::FDI_SB_WIDTH,
  parameter int unsigned RDI_WIDTH          = UcieUPM_rdi_params_pkg::RDI_WIDTH,
  parameter int unsigned RDI_SB_WIDTH       = UcieUPM_rdi_params_pkg::RDI_SB_WIDTH,
  parameter int unsigned SB_NODE_MSG_WIDTH  = UcieUPM_sideband_params_pkg::SIDEBAND_NODE_MSG_WIDTH
) (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire UcieUPM_interfaces_pkg::PhyStateReq_t fdi_lp_state_req,
  input  wire logic                                  fdi_lp_linkerror,
  input  wire logic                                  fdi_lp_rx_active_sts,
  output var UcieUPM_interfaces_pkg::PhyState_t    fdi_pl_state_sts,
  output var logic                                  fdi_pl_rx_active_req,
  output var logic                                  fdi_pl_inband_pres,
  output var logic                                  fdi_pl_wake_ack,
  input  wire logic                                  fdi_lp_wake_req,
  output var logic                                  fdi_pl_clk_req,
  input  wire logic                                  fdi_lp_clk_ack,
  output var logic                                  fdi_pl_stall_req,
  input  wire logic                                  fdi_lp_stall_ack,

  output var UcieUPM_d2dadapter_pkg::LinkInitState_t debug_link_init_state,

  output var logic                                  rdi_lp_linkerror,
  output var UcieUPM_interfaces_pkg::PhyStateReq_t rdi_lp_state_req,
  input  wire UcieUPM_interfaces_pkg::PhyState_t    rdi_pl_state_sts,
  input  wire logic                                  rdi_pl_inband_pres,

  output var logic fdiNeedsRdiAwake,
  input  wire logic rdiAwake,
  input  wire logic rdiNeedsFdiAwake,
  output var logic fdiAwake,

  input  wire logic rdi_pl_stall_req,
  output var logic rdi_lp_stall_ack,

  output var logic         sb_snd_valid,
  output var logic [127:0] sb_snd_msg,
  input  wire logic         sb_snd_ready,

  input  wire logic         sb_rcv_valid,
  input  wire logic [127:0] sb_rcv_msg,
  output var logic         sb_rcv_ready,

  input  wire logic [31:0] cycles_1us
);
  import UcieUPM_interfaces_pkg::*;
  import UcieUPM_d2dadapter_pkg::*;
  import SidebandMsgGenerator_pkg::*;

  function automatic logic [127:0] zeroMessage();
    zeroMessage = 128'b0;
  endfunction

  // Sideband registered producer.
  (* keep = "true" *) logic [127:0] sb_snd_msg_reg;
  (* keep = "true" *) logic         sb_snd_vld_reg;
  logic [127:0] sb_snd_msg_reg_next;
  logic         sb_snd_vld_reg_next;
  logic [127:0] sb_snd_msg_next;
  logic         sb_snd_vld_next;

  assign sb_snd_msg   = sb_snd_msg_reg;
  assign sb_snd_valid = sb_snd_vld_reg;
  assign sb_rcv_ready = 1'b1;

  logic txFire;
  logic rxFire;
  assign txFire = sb_snd_valid && sb_snd_ready;
  assign rxFire = sb_rcv_valid && sb_rcv_ready;

  // Explicit sideband decode signals are retained for readable waves.
  (* keep = "true" *) logic [127:0] tx_message;
  (* keep = "true" *) logic [63:0]  tx_header;
  (* keep = "true" *) logic [63:0]  tx_payload;
  (* keep = "true" *) logic         tx_hasPayload;
  (* keep = "true" *) logic [127:0] rx_message;
  (* keep = "true" *) logic [63:0]  rx_header;
  (* keep = "true" *) logic [63:0]  rx_payload;
  (* keep = "true" *) logic         rx_hasPayload;
  (* keep = "true" *) logic [7:0]   tx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgSub;
  (* keep = "true" *) logic [7:0]   rx_msgCode;
  (* keep = "true" *) logic [15:0]  rx_msgInfo;

  logic tx_is_adapter_req;
  logic tx_is_adapter_rsp;
  logic rx_is_adapter_req;
  logic rx_is_adapter_rsp;
  (* keep = "true" *) logic rx_is_param_exchange;
  (* keep = "true" *) logic rx_is_param_exchange_stall;
  (* keep = "true" *) logic rx_is_adv_cap_adapter;
  (* keep = "true" *) logic rx_is_adv_cap_adapter_stall;
  (* keep = "true" *) logic rx_is_adv_cap_adapter_nonstall;

  assign tx_message    = sb_snd_msg_reg;
  assign tx_header     = headerOf(tx_message);
  assign tx_payload    = payloadOf(tx_message);
  assign tx_hasPayload = hasPayload(tx_message);
  assign rx_message    = sb_rcv_msg;
  assign rx_header     = headerOf(rx_message);
  assign rx_payload    = payloadOf(rx_message);
  assign rx_hasPayload = hasPayload(rx_message);

  assign tx_msgSub  = UCIe2_Field_msgSub({64'b0, tx_header});
  assign rx_msgSub  = UCIe2_Field_msgSub({64'b0, rx_header});
  assign rx_msgCode = UCIe2_Field_msgCode({64'b0, rx_header});
  assign rx_msgInfo = UCIe2_Field_msgInfo({64'b0, rx_header});

  assign tx_is_adapter_req = UCIe2_isAdapterLinkMgmtReq({64'b0, tx_header});
  assign tx_is_adapter_rsp = UCIe2_isAdapterLinkMgmtRsp({64'b0, tx_header});
  assign rx_is_adapter_req = rxFire && UCIe2_isAdapterLinkMgmtReq({64'b0, rx_header});
  assign rx_is_adapter_rsp = rxFire && UCIe2_isAdapterLinkMgmtRsp({64'b0, rx_header});

  assign rx_is_param_exchange       = rxFire && UCIe2_isParamExchange(rx_message);
  assign rx_is_param_exchange_stall = rxFire && UCIe2_isParamExchangeStall(rx_message);
  assign rx_is_adv_cap_adapter = rx_is_param_exchange &&
                                 (rx_msgCode == UCIe2_ParamExch_ADV_CAP_MSGCODE) &&
                                 (rx_msgSub == UCIe2_ParamExch_SUB_ADAPTER);
  assign rx_is_adv_cap_adapter_stall = rx_is_adv_cap_adapter &&
                                       (rx_msgInfo == UCIe2_MsgInfo_STALL);
  assign rx_is_adv_cap_adapter_nonstall = rx_is_adv_cap_adapter &&
                                          !rx_is_adv_cap_adapter_stall;

  function automatic logic txIsAdapterReq(input logic [7:0] sub);
    txIsAdapterReq = tx_is_adapter_req && (tx_msgSub == sub);
  endfunction
  function automatic logic txIsAdapterRsp(input logic [7:0] sub);
    txIsAdapterRsp = tx_is_adapter_rsp && (tx_msgSub == sub);
  endfunction
  function automatic logic rxIsAdapterReq(input logic [7:0] sub);
    rxIsAdapterReq = rx_is_adapter_req && (rx_msgSub == sub);
  endfunction
  function automatic logic rxIsAdapterRsp(input logic [7:0] sub);
    rxIsAdapterRsp = rx_is_adapter_rsp && (rx_msgSub == sub);
  endfunction

  localparam logic [63:0] rawStreamingAdvCapPayload = 64'h0000_0000_0000_0091;

  function automatic logic advCapRawFormat(input logic [63:0] p);
    advCapRawFormat = p[0];
  endfunction
  function automatic logic advCapStreaming(input logic [63:0] p);
    advCapStreaming = p[4];
  endfunction
  function automatic logic advCapStack0Enabled(input logic [63:0] p);
    advCapStack0Enabled = p[7];
  endfunction
  function automatic logic advCapRawStreamingCompatible(input logic [63:0] p);
    advCapRawStreamingCompatible = advCapRawFormat(p) && advCapStreaming(p) &&
                                     advCapStack0Enabled(p);
  endfunction

  logic paramExchStallReceived;
  (* keep = "true" *) logic rx_advcap_raw_streaming_compatible;
  assign paramExchStallReceived = rx_is_param_exchange_stall;
  assign rx_advcap_raw_streaming_compatible = advCapRawStreamingCompatible(rx_payload);

  // Output and state registers.
  (* keep = "true" *) logic rdi_lp_linkerror_reg;
  (* keep = "true" *) PhyStateReq_t rdi_lp_state_req_reg;
  PhyStateReq_t rdi_lp_state_req_reg_next;
  (* keep = "true" *) PhyStateReq_t linkinit_rdi_lp_state_req;
  PhyStateReq_t linkinit_rdi_lp_state_req_next;

  (* keep = "true" *) logic fdi_pl_rxactive_req_reg;
  logic fdi_pl_rxactive_req_reg_next;
  (* keep = "true" *) logic fdi_pl_inband_pres_reg;

  logic fdiAwake_reg;
  logic fdi_pl_wake_ack_reg;

  (* keep = "true" *) PhyState_t link_state_reg;
  (* keep = "true" *) PhyState_t link_state_prev_reg;
  (* keep = "true" *) LinkInitState_t linkinit_state_reg;
  LinkInitState_t linkinit_state_reg_next;
  PhyState_t next_state;

  (* keep = "true" *) PhyStateReq_t fdi_lp_state_req_prev_reg;
  (* keep = "true" *) logic retrain_to_active_initiated;
  logic retrain_to_active_initiated_next;

  (* keep = "true" *) logic nopToActive;
  (* keep = "true" *) logic nopToDisabled;
  (* keep = "true" *) logic nopToLinkreset;

  (* keep = "true" *) logic pendingDisabledFromReset;
  (* keep = "true" *) logic pendingLinkresetFromReset;
  logic pendingDisabledFromReset_next;
  logic pendingLinkresetFromReset_next;

  assign rdi_lp_linkerror      = rdi_lp_linkerror_reg;
  assign rdi_lp_state_req      = rdi_lp_state_req_reg;
  assign fdi_pl_state_sts      = link_state_reg;
  assign fdi_pl_rx_active_req  = fdi_pl_rxactive_req_reg;
  assign fdi_pl_inband_pres    = fdi_pl_inband_pres_reg;
  assign debug_link_init_state = linkinit_state_reg;
  assign fdiNeedsRdiAwake      = 1'b1;
  assign fdiAwake              = fdiAwake_reg;
  assign fdi_pl_wake_ack       = fdi_pl_wake_ack_reg;
  assign fdi_pl_clk_req        = 1'b1;

  // FDI stall controller.
  (* keep = "true" *) logic linkmgmt_stallreq_reg;
  logic linkmgmt_stallreq_reg_next;
  logic stall_req;
  (* keep = "true" *) logic stallhandler_handshake_done;
  (* keep = "true" *) logic stall_4phaseshandshake_done;
  logic stall_busy;

  StallCtrl stall_module (
    .clock   (clock),
    .reset_n   (reset_n),
    .start   (linkmgmt_stallreq_reg && !stall_busy),
    .release_i (link_state_reg != PhyState_active),
    .ack     (fdi_lp_stall_ack),
    .req     (stall_req),
    .aligned (stallhandler_handshake_done),
    .done    (stall_4phaseshandshake_done),
    .busy    (stall_busy)
  );
  assign fdi_pl_stall_req = stall_req;

  (* keep = "true" *) logic rdi_lp_stall_ack_reg;
  logic rdi_lp_stall_ack_reg_next;
  assign rdi_lp_stall_ack = rdi_lp_stall_ack_reg;

  // Placeholder internal causes retained as registers, as in the source revision.
  (* keep = "true" *) logic linkerror_internal;
  (* keep = "true" *) logic linkreset_internal;
  (* keep = "true" *) logic disabled_internal;

  logic linkerror_phy_sts;
  logic linkreset_rdiphy_sts;
  logic disabled_rdiphy_sts;
  logic retrain_rdiphy_sts;
  logic active_rdiphy_sts;
  assign linkerror_phy_sts     = (rdi_pl_state_sts == PhyState_linkError);
  assign linkreset_rdiphy_sts  = (rdi_pl_state_sts == PhyState_linkReset);
  assign disabled_rdiphy_sts   = (rdi_pl_state_sts == PhyState_disabled);
  assign retrain_rdiphy_sts    = (rdi_pl_state_sts == PhyState_retrain);
  assign active_rdiphy_sts     = (rdi_pl_state_sts == PhyState_active);

  (* keep = "true" *) logic active_entry;
  logic rx_deactive;
  logic rx_active;
  assign rx_deactive = !fdi_lp_rx_active_sts && !fdi_pl_rxactive_req_reg;
  assign rx_active   =  fdi_lp_rx_active_sts &&  fdi_pl_rxactive_req_reg;

  (* keep = "true" *) logic [63:0] linkerrorCounter;
  logic [63:0] maxCount_linkerr;
  logic linkerrorResidencyDone;
  assign maxCount_linkerr = {32'b0, cycles_1us} * 64'd16000;
  assign linkerrorResidencyDone = (linkerrorCounter == maxCount_linkerr);

  wire timeout_done = 1'b0;
  (* keep = "true" *) logic [63:0] paramexchCounter;
  logic [63:0] maxCount_paramexch;
  logic paramexchTimesUp;
  assign maxCount_paramexch = {32'b0, cycles_1us} * 64'd8000;
  assign paramexchTimesUp = (paramexchCounter == maxCount_paramexch);

  logic disabled_entry;
  logic linkreset_entry;
  logic disabled_entry_rst;
  logic linkreset_entry_rst;
  logic disabled_handshake_done;
  logic linkreset_handshake_done;

  (* keep = "true" *) logic disabled_cleanup_done;
  (* keep = "true" *) logic linkreset_cleanup_done;

  // Sideband transaction flags.
  (* keep = "true" *) logic active_sbmsg_loc_req_flag;
  (* keep = "true" *) logic active_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic active_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic active_sbmsg_rem_req_flag;
  logic active_sbmsg_loc_req_flag_next;
  logic active_sbmsg_loc_rsp_flag_next;
  logic active_sbmsg_rem_rsp_flag_next;
  logic active_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic disabled_sbmsg_loc_req_flag;
  (* keep = "true" *) logic disabled_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic disabled_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic disabled_sbmsg_rem_req_flag;
  logic disabled_sbmsg_loc_req_flag_next;
  logic disabled_sbmsg_loc_rsp_flag_next;
  logic disabled_sbmsg_rem_rsp_flag_next;
  logic disabled_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic linkreset_sbmsg_loc_req_flag;
  (* keep = "true" *) logic linkreset_sbmsg_loc_rsp_flag;
  (* keep = "true" *) logic linkreset_sbmsg_rem_rsp_flag;
  (* keep = "true" *) logic linkreset_sbmsg_rem_req_flag;
  logic linkreset_sbmsg_loc_req_flag_next;
  logic linkreset_sbmsg_loc_rsp_flag_next;
  logic linkreset_sbmsg_rem_rsp_flag_next;
  logic linkreset_sbmsg_rem_req_flag_next;

  (* keep = "true" *) logic adv_cap_local_sent_flag;
  (* keep = "true" *) logic adv_cap_remote_rcv_flag;
  (* keep = "true" *) logic param_exch_incompatible_reg;
  logic adv_cap_local_sent_flag_next;
  logic adv_cap_remote_rcv_flag_next;
  logic param_exch_incompatible_reg_next;

  logic param_exch_done;
  logic disabled_req;
  logic linkreset_req;
  logic retrain_req;

  assign disabled_req = (fdi_lp_state_req == PhyStateReq_disabled) ||
                        disabled_sbmsg_rem_req_flag || disabled_internal;
  assign linkreset_req = (fdi_lp_state_req == PhyStateReq_linkReset) ||
                         linkreset_sbmsg_rem_req_flag || linkreset_internal;
  assign retrain_req = (fdi_lp_state_req == PhyStateReq_retrain);

  assign disabled_entry_rst = pendingDisabledFromReset || nopToDisabled ||
                              disabled_sbmsg_rem_req_flag || disabled_rdiphy_sts ||
                              disabled_internal;
  assign linkreset_entry_rst = pendingLinkresetFromReset || nopToLinkreset ||
                               linkreset_sbmsg_rem_req_flag || linkreset_rdiphy_sts ||
                               linkreset_internal;
  assign disabled_entry = disabled_req || disabled_rdiphy_sts;
  assign linkreset_entry = linkreset_req || linkreset_rdiphy_sts;
  assign disabled_handshake_done =
    (disabled_sbmsg_rem_req_flag && disabled_sbmsg_rem_rsp_flag) ||
    (disabled_sbmsg_loc_req_flag && disabled_sbmsg_loc_rsp_flag);
  assign linkreset_handshake_done =
    (linkreset_sbmsg_rem_req_flag && linkreset_sbmsg_rem_rsp_flag) ||
    (linkreset_sbmsg_loc_req_flag && linkreset_sbmsg_loc_rsp_flag);
  assign param_exch_done = adv_cap_local_sent_flag && adv_cap_remote_rcv_flag;

  logic inbandShouldBeHigh;
  assign inbandShouldBeHigh =
    (link_state_reg == PhyState_active) ||
    (link_state_reg == PhyState_retrain) ||
    ((link_state_reg == PhyState_reset) &&
     ((linkinit_state_reg == LinkInitState_FDI_WAIT_LP_REQ_ACTIVE) ||
      (linkinit_state_reg == LinkInitState_FDI_ACTIVE_HANDSHAKE) ||
      (linkinit_state_reg == LinkInitState_FDI_ACTIVE_ENTRY_DONE)));

  // Main next-state and sideband logic.
  always_comb begin
    sb_snd_msg_reg_next = sb_snd_msg_reg;
    sb_snd_vld_reg_next = sb_snd_vld_reg;
    sb_snd_msg_next = zeroMessage();
    sb_snd_vld_next = 1'b0;

    rdi_lp_state_req_reg_next = rdi_lp_state_req_reg;
    linkinit_rdi_lp_state_req_next = linkinit_rdi_lp_state_req;
    fdi_pl_rxactive_req_reg_next = fdi_pl_rxactive_req_reg;
    linkinit_state_reg_next = linkinit_state_reg;
    next_state = PhyState_reset;
    retrain_to_active_initiated_next = retrain_to_active_initiated;
    linkmgmt_stallreq_reg_next = linkmgmt_stallreq_reg;
    rdi_lp_stall_ack_reg_next = rdi_lp_stall_ack_reg;
    pendingDisabledFromReset_next = pendingDisabledFromReset;
    pendingLinkresetFromReset_next = pendingLinkresetFromReset;
    active_entry = 1'b0;

    active_sbmsg_loc_req_flag_next = active_sbmsg_loc_req_flag;
    active_sbmsg_loc_rsp_flag_next = active_sbmsg_loc_rsp_flag;
    active_sbmsg_rem_rsp_flag_next = active_sbmsg_rem_rsp_flag;
    active_sbmsg_rem_req_flag_next = active_sbmsg_rem_req_flag;
    disabled_sbmsg_loc_req_flag_next = disabled_sbmsg_loc_req_flag;
    disabled_sbmsg_loc_rsp_flag_next = disabled_sbmsg_loc_rsp_flag;
    disabled_sbmsg_rem_rsp_flag_next = disabled_sbmsg_rem_rsp_flag;
    disabled_sbmsg_rem_req_flag_next = disabled_sbmsg_rem_req_flag;
    linkreset_sbmsg_loc_req_flag_next = linkreset_sbmsg_loc_req_flag;
    linkreset_sbmsg_loc_rsp_flag_next = linkreset_sbmsg_loc_rsp_flag;
    linkreset_sbmsg_rem_rsp_flag_next = linkreset_sbmsg_rem_rsp_flag;
    linkreset_sbmsg_rem_req_flag_next = linkreset_sbmsg_rem_req_flag;
    adv_cap_local_sent_flag_next = adv_cap_local_sent_flag;
    adv_cap_remote_rcv_flag_next = adv_cap_remote_rcv_flag;
    param_exch_incompatible_reg_next = param_exch_incompatible_reg;

    // Latch Reset-exit requests from the registered NOP-transition indicators.
    if (link_state_reg != PhyState_reset) begin
      pendingDisabledFromReset_next = 1'b0;
      pendingLinkresetFromReset_next = 1'b0;
    end else begin
      if (nopToDisabled)
        pendingDisabledFromReset_next = 1'b1;
      if (nopToLinkreset)
        pendingLinkresetFromReset_next = 1'b1;
    end

    // Acknowledge a PHY-originated stall only after the local stall controller is aligned.
    if (!rdi_pl_stall_req)
      rdi_lp_stall_ack_reg_next = 1'b0;
    else if (stallhandler_handshake_done)
      rdi_lp_stall_ack_reg_next = 1'b1;

    // Parameter exchange flags.
    if (txFire && UCIe2_isParamExchange(sb_snd_msg_reg) &&
        (UCIe2_Field_msgCode({64'b0, tx_header}) == UCIe2_ParamExch_ADV_CAP_MSGCODE) &&
        (UCIe2_Field_msgSub({64'b0, tx_header}) == UCIe2_ParamExch_SUB_ADAPTER)) begin
      adv_cap_local_sent_flag_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      adv_cap_local_sent_flag_next = 1'b0;
    end

    if (rx_is_adv_cap_adapter_nonstall && rx_advcap_raw_streaming_compatible) begin
      adv_cap_remote_rcv_flag_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      adv_cap_remote_rcv_flag_next = 1'b0;
    end

    if (rx_is_adv_cap_adapter_nonstall && !rx_advcap_raw_streaming_compatible) begin
      param_exch_incompatible_reg_next = 1'b1;
    end else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
                 (link_state_reg == PhyState_active)) begin
      param_exch_incompatible_reg_next = 1'b0;
    end

    // Active sideband flags.
    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_loc_req_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_loc_rsp_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_loc_rsp_flag_next = 1'b0;

    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_rem_req_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_ACTIVE))
      active_sbmsg_rem_rsp_flag_next = 1'b1;
    else if ((linkinit_state_reg == LinkInitState_FDI_INIT_START) ||
             (link_state_reg == PhyState_active))
      active_sbmsg_rem_rsp_flag_next = 1'b0;

    // Disabled sideband flags.
    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_rem_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_rem_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_rem_rsp_flag_next = 1'b0;

    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_loc_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_DISABLE))
      disabled_sbmsg_loc_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_disabled)
      disabled_sbmsg_loc_rsp_flag_next = 1'b0;

    // LinkReset sideband flags.
    if (rxIsAdapterReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_rem_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_rem_req_flag_next = 1'b0;

    if (txFire && txIsAdapterRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_rem_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_rem_rsp_flag_next = 1'b0;

    if (txFire && txIsAdapterReq(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_loc_req_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_loc_req_flag_next = 1'b0;

    if (rxIsAdapterRsp(UCIe2_LinkMgmtSubCode_LINKRESET))
      linkreset_sbmsg_loc_rsp_flag_next = 1'b1;
    else if (link_state_reg == PhyState_linkReset)
      linkreset_sbmsg_loc_rsp_flag_next = 1'b0;

    // FDI state machine. next_state is computed before the link-init FSM below,
    // because the link-init ACTIVE_ENTRY_DONE condition reads the final next_state wire.
    case (link_state_reg)
      PhyState_reset: begin
        rdi_lp_state_req_reg_next = linkinit_rdi_lp_state_req;
        linkmgmt_stallreq_reg_next = 1'b0;
        sb_snd_msg_next = zeroMessage();
        next_state = PhyState_reset;
        retrain_to_active_initiated_next = 1'b0;

        if (linkinit_state_reg == LinkInitState_FDI_INIT_START) begin
          sb_snd_msg_next = zeroMessage();
          fdi_pl_rxactive_req_reg_next = 1'b0;
        end else if (linkinit_state_reg == LinkInitState_FDI_PARAM_EXCH) begin
          if (!adv_cap_local_sent_flag) begin
            sb_snd_msg_next = UCIe2_ParamExchange_advCapAdapter(
              rawStreamingAdvCapPayload, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D,
              UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else begin
            sb_snd_msg_next = zeroMessage();
          end
        end else if (linkinit_state_reg == LinkInitState_FDI_ACTIVE_HANDSHAKE) begin
          fdi_pl_rxactive_req_reg_next = 1'b1;
          if (!active_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqActive(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (active_sbmsg_rem_req_flag && rx_active &&
                       !active_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspActive(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else begin
            sb_snd_msg_next = zeroMessage();
          end
        end

        if (linkerror_phy_sts) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          next_state = PhyState_linkError;
        end else if (disabled_entry_rst) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done)
            next_state = PhyState_disabled;
        end else if (linkreset_entry_rst) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done)
            next_state = PhyState_linkReset;
        end else if (linkinit_state_reg == LinkInitState_FDI_ACTIVE_ENTRY_DONE) begin
          next_state = PhyState_active;
        end
      end

      PhyState_active: begin
        sb_snd_msg_next = zeroMessage();
        linkmgmt_stallreq_reg_next = linkreset_req || disabled_req || retrain_req ||
                                     rdi_pl_stall_req;
        next_state = PhyState_active;

        if (linkerror_phy_sts) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          next_state = PhyState_linkError;
        end else if (disabled_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done)
            next_state = PhyState_disabled;
        end else if (linkreset_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done)
            next_state = PhyState_linkReset;
        end else if (retrain_req && stallhandler_handshake_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_retrain;
          if (retrain_rdiphy_sts) begin
            if (rx_active)
              fdi_pl_rxactive_req_reg_next = 1'b0;
            if (rx_deactive) begin
              rdi_lp_state_req_reg_next = PhyStateReq_retrain;
              next_state = PhyState_retrain;
            end
          end
        end else if (retrain_rdiphy_sts && stallhandler_handshake_done) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive) begin
            rdi_lp_state_req_reg_next = PhyStateReq_retrain;
            next_state = PhyState_retrain;
          end
        end else if (disabled_rdiphy_sts && !disabled_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_disabled;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else if (linkreset_rdiphy_sts && !linkreset_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_linkReset;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else if (retrain_rdiphy_sts && !retrain_req) begin
          if (rx_active)
            fdi_pl_rxactive_req_reg_next = 1'b0;
          if (rx_deactive)
            next_state = PhyState_retrain;
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_retrain: begin
        sb_snd_msg_next = zeroMessage();
        linkmgmt_stallreq_reg_next = 1'b0;
        rdi_lp_state_req_reg_next = PhyStateReq_nop;
        next_state = PhyState_retrain;

        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (disabled_entry) begin
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && disabled_handshake_done) begin
            next_state = PhyState_disabled;
            if (!disabled_rdiphy_sts)
              rdi_lp_state_req_reg_next = PhyStateReq_disabled;
          end
        end else if (linkreset_entry) begin
          if (linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!linkreset_sbmsg_rem_req_flag && !linkreset_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqLinkReset(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          if (rx_deactive && linkreset_handshake_done) begin
            next_state = PhyState_linkReset;
            if (!linkreset_rdiphy_sts)
              rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
          end
        end else if (nopToActive) begin
          fdi_pl_rxactive_req_reg_next = 1'b1;
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          retrain_to_active_initiated_next = 1'b1;
        end else if (retrain_to_active_initiated) begin
          if (active_rdiphy_sts) begin
            if (!active_sbmsg_loc_req_flag) begin
              sb_snd_msg_next = UCIe2_Adapter_reqActive(
                0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
              sb_snd_vld_next = 1'b1;
            end else if (active_sbmsg_rem_req_flag && rx_active &&
                         !active_sbmsg_rem_rsp_flag) begin
              sb_snd_msg_next = UCIe2_Adapter_rspActive(
                0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
              sb_snd_vld_next = 1'b1;
            end else begin
              sb_snd_msg_next = zeroMessage();
            end
            if (active_sbmsg_loc_rsp_flag && active_sbmsg_rem_rsp_flag) begin
              retrain_to_active_initiated_next = 1'b0;
              next_state = PhyState_active;
            end
          end
        end
      end

      PhyState_linkError: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_linkError;
        if ((fdi_lp_state_req == PhyStateReq_active) && !linkerror_internal &&
            linkerrorResidencyDone && rx_deactive && !fdi_lp_linkerror) begin
          if (rdi_pl_state_sts == PhyState_reset) begin
            rdi_lp_state_req_reg_next = PhyStateReq_nop;
            next_state = PhyState_reset;
          end else begin
            rdi_lp_state_req_reg_next = PhyStateReq_active;
          end
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_disabled: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_disabled;
        sb_snd_msg_next = zeroMessage();
        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (rdi_pl_state_sts != PhyState_disabled) begin
          rdi_lp_state_req_reg_next = PhyStateReq_disabled;
        end else if ((fdi_lp_state_req == PhyStateReq_active) && disabled_cleanup_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          next_state = PhyState_reset;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      PhyState_linkReset: begin
        linkmgmt_stallreq_reg_next = 1'b0;
        next_state = PhyState_linkReset;
        sb_snd_msg_next = zeroMessage();
        if (linkerror_phy_sts) begin
          next_state = PhyState_linkError;
        end else if (disabled_entry) begin
          if (disabled_sbmsg_rem_req_flag && !disabled_sbmsg_rem_rsp_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_rspDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D, UCIe2_MsgInfo_REGULAR);
            sb_snd_vld_next = 1'b1;
          end else if (!disabled_sbmsg_rem_req_flag && !disabled_sbmsg_loc_req_flag) begin
            sb_snd_msg_next = UCIe2_Adapter_reqDisable(
              0, ENDPOINT_D2D, ENDPOINT_REMOTE_D2D);
            sb_snd_vld_next = 1'b1;
          end
          next_state = PhyState_disabled;
        end else if (rdi_pl_state_sts != PhyState_linkReset) begin
          rdi_lp_state_req_reg_next = PhyStateReq_linkReset;
        end else if ((fdi_lp_state_req == PhyStateReq_active) && linkreset_cleanup_done) begin
          rdi_lp_state_req_reg_next = PhyStateReq_active;
          next_state = PhyState_reset;
        end else begin
          rdi_lp_state_req_reg_next = PhyStateReq_nop;
        end
      end

      default: begin
        next_state = PhyState_reset;
      end
    endcase

    // Link-initialization FSM. It consumes the final next_state value above.
    case (linkinit_state_reg)
      LinkInitState_FDI_INIT_START: begin
        active_entry = 1'b0;
        linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
        if (rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_active;
          linkinit_state_reg_next = LinkInitState_FDI_WAIT_RDI_ACTIVE;
        end
      end

      LinkInitState_FDI_WAIT_RDI_ACTIVE: begin
        if (!rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
        end else if (rdi_pl_state_sts == PhyState_active) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_PARAM_EXCH;
        end
      end

      LinkInitState_FDI_PARAM_EXCH: begin
        if (param_exch_done)
          linkinit_state_reg_next = LinkInitState_FDI_WAIT_LP_REQ_ACTIVE;
      end

      LinkInitState_FDI_WAIT_LP_REQ_ACTIVE: begin
        if (nopToActive)
          linkinit_state_reg_next = LinkInitState_FDI_ACTIVE_HANDSHAKE;
      end

      LinkInitState_FDI_ACTIVE_HANDSHAKE: begin
        if (!rdi_pl_inband_pres) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
        end else if (active_sbmsg_loc_rsp_flag && active_sbmsg_rem_rsp_flag) begin
          linkinit_state_reg_next = LinkInitState_FDI_ACTIVE_ENTRY_DONE;
        end
      end

      LinkInitState_FDI_ACTIVE_ENTRY_DONE: begin
        if (!rdi_pl_inband_pres ||
            ((link_state_reg != PhyState_reset) && (next_state == PhyState_reset))) begin
          linkinit_rdi_lp_state_req_next = PhyStateReq_nop;
          linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
          active_entry = 1'b0;
        end else if (fdi_lp_state_req == PhyStateReq_active) begin
          active_entry = 1'b1;
        end
      end

      default: linkinit_state_reg_next = LinkInitState_FDI_INIT_START;
    endcase

    // Decoupled TX register commit.
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
      linkmgmt_stallreq_reg <= 1'b0;
      sb_snd_msg_reg <= 128'b0;
      sb_snd_vld_reg <= 1'b0;
      rdi_lp_linkerror_reg <= 1'b0;
      rdi_lp_state_req_reg <= PhyStateReq_nop;
      linkinit_rdi_lp_state_req <= PhyStateReq_nop;
      fdi_pl_rxactive_req_reg <= 1'b0;
      fdi_pl_inband_pres_reg <= 1'b0;
      fdiAwake_reg <= 1'b0;
      fdi_pl_wake_ack_reg <= 1'b0;
      link_state_reg <= PhyState_reset;
      link_state_prev_reg <= PhyState_reset;
      linkinit_state_reg <= LinkInitState_FDI_INIT_START;
      fdi_lp_state_req_prev_reg <= PhyStateReq_nop;
      retrain_to_active_initiated <= 1'b0;
      nopToActive <= 1'b0;
      nopToDisabled <= 1'b0;
      nopToLinkreset <= 1'b0;
      pendingDisabledFromReset <= 1'b0;
      pendingLinkresetFromReset <= 1'b0;
      rdi_lp_stall_ack_reg <= 1'b0;
      linkerror_internal <= 1'b0;
      linkreset_internal <= 1'b0;
      disabled_internal <= 1'b0;
      linkerrorCounter <= 64'd0;
      paramexchCounter <= 64'd0;
      disabled_cleanup_done <= 1'b1;
      linkreset_cleanup_done <= 1'b1;
      active_sbmsg_loc_req_flag <= 1'b0;
      active_sbmsg_loc_rsp_flag <= 1'b0;
      active_sbmsg_rem_rsp_flag <= 1'b0;
      active_sbmsg_rem_req_flag <= 1'b0;
      disabled_sbmsg_loc_req_flag <= 1'b0;
      disabled_sbmsg_loc_rsp_flag <= 1'b0;
      disabled_sbmsg_rem_rsp_flag <= 1'b0;
      disabled_sbmsg_rem_req_flag <= 1'b0;
      linkreset_sbmsg_loc_req_flag <= 1'b0;
      linkreset_sbmsg_loc_rsp_flag <= 1'b0;
      linkreset_sbmsg_rem_rsp_flag <= 1'b0;
      linkreset_sbmsg_rem_req_flag <= 1'b0;
      adv_cap_local_sent_flag <= 1'b0;
      adv_cap_remote_rcv_flag <= 1'b0;
      param_exch_incompatible_reg <= 1'b0;
    end else begin
      linkmgmt_stallreq_reg <= linkmgmt_stallreq_reg_next;
      sb_snd_msg_reg <= sb_snd_msg_reg_next;
      sb_snd_vld_reg <= sb_snd_vld_reg_next;
      rdi_lp_linkerror_reg <= fdi_lp_linkerror || linkerror_internal || timeout_done ||
                              paramexchTimesUp || param_exch_incompatible_reg;
      rdi_lp_state_req_reg <= rdi_lp_state_req_reg_next;
      linkinit_rdi_lp_state_req <= linkinit_rdi_lp_state_req_next;
      fdi_pl_rxactive_req_reg <= fdi_pl_rxactive_req_reg_next;
      fdi_pl_inband_pres_reg <= inbandShouldBeHigh;
      fdiAwake_reg <= rdiNeedsFdiAwake;
      fdi_pl_wake_ack_reg <= fdi_lp_wake_req;
      link_state_prev_reg <= link_state_reg;
      link_state_reg <= next_state;
      linkinit_state_reg <= linkinit_state_reg_next;
      fdi_lp_state_req_prev_reg <= fdi_lp_state_req;
      retrain_to_active_initiated <= retrain_to_active_initiated_next;
      nopToActive <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                     (fdi_lp_state_req == PhyStateReq_active);
      nopToDisabled <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                       (fdi_lp_state_req == PhyStateReq_disabled);
      nopToLinkreset <= (fdi_lp_state_req_prev_reg == PhyStateReq_nop) &&
                        (fdi_lp_state_req == PhyStateReq_linkReset);
      pendingDisabledFromReset <= pendingDisabledFromReset_next;
      pendingLinkresetFromReset <= pendingLinkresetFromReset_next;
      rdi_lp_stall_ack_reg <= rdi_lp_stall_ack_reg_next;

      // Source placeholder registers intentionally retain their reset values.

      if (link_state_reg == PhyState_linkError) begin
        if (!linkerrorResidencyDone)
          linkerrorCounter <= linkerrorCounter + 64'd1;
      end else begin
        linkerrorCounter <= 64'd0;
      end

      if ((linkinit_state_reg == LinkInitState_FDI_PARAM_EXCH) &&
          (rdi_pl_state_sts == PhyState_active)) begin
        if (paramExchStallReceived)
          paramexchCounter <= 64'd0;
        else if (!paramexchTimesUp)
          paramexchCounter <= paramexchCounter + 64'd1;
      end else begin
        paramexchCounter <= 64'd0;
      end

      active_sbmsg_loc_req_flag <= active_sbmsg_loc_req_flag_next;
      active_sbmsg_loc_rsp_flag <= active_sbmsg_loc_rsp_flag_next;
      active_sbmsg_rem_rsp_flag <= active_sbmsg_rem_rsp_flag_next;
      active_sbmsg_rem_req_flag <= active_sbmsg_rem_req_flag_next;
      disabled_sbmsg_loc_req_flag <= disabled_sbmsg_loc_req_flag_next;
      disabled_sbmsg_loc_rsp_flag <= disabled_sbmsg_loc_rsp_flag_next;
      disabled_sbmsg_rem_rsp_flag <= disabled_sbmsg_rem_rsp_flag_next;
      disabled_sbmsg_rem_req_flag <= disabled_sbmsg_rem_req_flag_next;
      linkreset_sbmsg_loc_req_flag <= linkreset_sbmsg_loc_req_flag_next;
      linkreset_sbmsg_loc_rsp_flag <= linkreset_sbmsg_loc_rsp_flag_next;
      linkreset_sbmsg_rem_rsp_flag <= linkreset_sbmsg_rem_rsp_flag_next;
      linkreset_sbmsg_rem_req_flag <= linkreset_sbmsg_rem_req_flag_next;
      adv_cap_local_sent_flag <= adv_cap_local_sent_flag_next;
      adv_cap_remote_rcv_flag <= adv_cap_remote_rcv_flag_next;
      param_exch_incompatible_reg <= param_exch_incompatible_reg_next;
    end
  end

  // Parameters and inputs retained for source/integration compatibility.
  wire _unused_ok = &{1'b0, fdi_lp_clk_ack, rdiAwake, link_state_prev_reg[0],
                      stall_4phaseshandshake_done, active_entry};
endmodule

`default_nettype wire
