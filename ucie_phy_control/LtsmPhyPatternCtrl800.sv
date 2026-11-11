`default_nettype none
// PHYSICAL REGION 1: 800 MHz LTSM command capture / dispatch / completion.
// Place this hierarchy near UCIe digital. Its only clock is the LTSM clock.
// Four receivers: 500 MHz LFSR, 2 GHz data ID, 2 GHz valid, 2 GHz clock repair.
// Data links carry a held payload/mask; valid and clock use event-only links.
// Preserve hierarchy and apply the bundled-data timing constraints in README.
module LtsmPhyPatternCtrl800 #(
  parameter integer LANES=16,
  parameter integer SYNC_STAGES=3
) (
  input wire clock,
  input wire reset_n,
  input wire [3:0] ltsm_state,
  input wire [2:0] ltsm_dbg_mbinitSubstate,
  input wire [3:0] ltsm_dbg_mbtrainState,
  // All LTSM inputs, including this mask, are synchronous to clock.
  // Use all physical participating data lanes, including repair lanes if used.
  input wire [LANES-1:0] ltsm_data_lane_mask,
  input wire ltsm_flagToAnalog_SendClkPatterns,
  input wire ltsm_flagToAnalog_SendValTrainPattern,
  input wire ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
  input wire ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
  input wire ltsm_flagToAnalog_valVref_sendPattern,
  input wire ltsm_flagToAnalog_dataVref_sendPattern,
  input wire ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
  input wire ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
  input wire ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
  output wire ltsm_flagFromAnalog_FinishedClkPatterns,
  output wire ltsm_flagFromAnalog_FinishedValTrainPattern,
  output wire ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
  output wire ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
  output wire ltsm_flagFromAnalog_valVref_finishedPattern,
  output wire ltsm_flagFromAnalog_dataVref_finishedPattern,
  output wire ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
  output wire ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
  output wire ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
  output wire ltsm_pattern_busy,
  output logic ltsm_pattern_aborted,
  // Sticky until common reset: [0] multiple simultaneous request edges,
  // [1] request/state/mask mismatch, [2] pending command queue overflow.
  output logic [2:0] ltsm_pattern_error,
  output wire reset_ltsm_n,
  // Inter-region links. Payload is held through the entire four-phase handshake.
  // These are CDC links, not synchronous ready/valid ports across the floorplan.
  output wire tx500_req_o,
  output wire [LANES+17:0] tx500_payload_o,
  output wire tx500_cancel_o,
  input wire tx500_ack_i,
  input wire tx500_aborted_i,
  output wire txdata2g_req_o,
  output wire [LANES-1:0] txdata2g_lane_mask_o,
  output wire txdata2g_cancel_o,
  input wire txdata2g_ack_i,
  input wire txdata2g_aborted_i,
  output wire txvalid2g_req_o,
  output wire txvalid2g_cancel_o,
  input wire txvalid2g_ack_i,
  input wire txvalid2g_aborted_i,
  output wire txclock2g_req_o,
  output wire txclock2g_cancel_o,
  input wire txclock2g_ack_i,
  input wire txclock2g_aborted_i
);
  localparam logic [1:0] K_CLK=2'd0, K_VAL=2'd1, K_ID=2'd2, K_LFSR=2'd3;
  // Specialized endpoint counts are fixed locally. The existing 500 MHz
  // endpoint retains its command format: 128 words of 32 serial UI each.
  localparam logic [15:0] LFSR_WORDS=16'd128;
  localparam logic [8:0] HELD_MASK=9'b1_1111_0000;
  localparam logic [LANES-1:0] SINGLE_PATH={{(LANES-1){1'b0}},1'b1};

  Ltsm800ResetSync #(.STAGES(SYNC_STAGES)) u_rst_ltsm
    (.clk_i(clock),.arst_ni(reset_n),.rst_no(reset_ltsm_n));

  wire [8:0] request={ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    ltsm_flagToAnalog_dataVref_sendPattern,
    ltsm_flagToAnalog_valVref_sendPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_SendValTrainPattern,ltsm_flagToAnalog_SendClkPatterns};
  logic [8:0] previous_request, finished;
  wire [8:0] rise=request & ~previous_request;
  wire [10:0] context_now={ltsm_state,ltsm_dbg_mbinitSubstate,ltsm_dbg_mbtrainState};
  logic [1:0] decoded_kind;
  logic [LANES-1:0] decoded_mask;
  logic decoded_legal;
  wire multiple_rise=(rise != 0) && ((rise & (rise-9'd1)) != 0);
  always_comb begin
    decoded_kind=K_CLK;
    decoded_mask=SINGLE_PATH;
    decoded_legal=1'b0;
    case (rise)
      9'b000000001: decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==2);
      9'b000000010: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==3);
      end
      9'b000000100,9'b000001000: begin
        decoded_kind=K_ID; decoded_mask=ltsm_data_lane_mask;
        decoded_legal=(ltsm_state==5 && (|ltsm_data_lane_mask) &&
          ((rise[2] && ltsm_dbg_mbinitSubstate==4) ||
           (rise[3] && ltsm_dbg_mbinitSubstate==5)));
      end
      9'b000010000: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==6 && (ltsm_dbg_mbtrainState==1 || ltsm_dbg_mbtrainState==7));
      end
      9'b000100000: begin
        decoded_kind=K_LFSR; decoded_mask=ltsm_data_lane_mask;
        decoded_legal=(ltsm_state==6 && (|ltsm_data_lane_mask) &&
          (ltsm_dbg_mbtrainState==2 || ltsm_dbg_mbtrainState==9));
      end
      9'b001000000: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==6 && ltsm_dbg_mbtrainState==6);
      end
      9'b010000000: begin
        decoded_kind=K_LFSR; decoded_mask=ltsm_data_lane_mask;
        decoded_legal=(ltsm_state==6 && (|ltsm_data_lane_mask) &&
          (ltsm_dbg_mbtrainState==8 || ltsm_dbg_mbtrainState==11 || ltsm_dbg_mbtrainState==12));
      end
      9'b100000000: begin
        decoded_kind=K_LFSR; decoded_mask=ltsm_data_lane_mask;
        decoded_legal=(ltsm_state==6 && (|ltsm_data_lane_mask) && ltsm_dbg_mbtrainState==10);
      end
      default: begin end
    endcase
  end

  // Source-domain capture is necessary: synchronizing the nine raw requests
  // independently would lose short pulses and detach them from their state.
  // One pending entry supports an abort/state transition followed by a request.
  typedef enum logic [1:0] {IDLE,WAIT_DONE,RETURN_ZERO} source_state_t;
  source_state_t source_state;
  logic pending_valid;
  logic [LANES-1:0] pending_mask;
  logic [1:0] pending_kind;
  logic [8:0] pending_owner,active_owner;
  logic [10:0] pending_context,active_context;
  logic [1:0] active_kind;
  logic cancel_q;
  wire pending_cancel=(context_now!=pending_context) ||
    (|(pending_owner & HELD_MASK & ~request));
  wire cancel_now=(context_now!=active_context) ||
    (|(active_owner & HELD_MASK & ~request));
  // Channel index follows the local pattern-kind enumeration.
  wire [3:0] channel_ready,channel_done,channel_aborted;
  wire selected_ready=channel_ready[pending_kind];
  wire launch=(source_state==IDLE) && pending_valid && !pending_cancel && selected_ready;
  wire active_done=channel_done[active_kind];
  wire active_aborted=channel_aborted[active_kind];
  wire active_ready=channel_ready[active_kind];
  assign ltsm_pattern_busy=pending_valid || (source_state!=IDLE);
  always_ff @(posedge clock or negedge reset_ltsm_n) begin
    if (!reset_ltsm_n) begin
      source_state<=IDLE; pending_valid<=0; pending_mask<='0; pending_kind<=K_CLK;
      pending_owner<='0; active_owner<='0;
      pending_context<='0; active_context<='0;
      active_kind<=K_CLK; cancel_q<=0; previous_request<='0; finished<='0;
      ltsm_pattern_aborted<=0; ltsm_pattern_error<='0;
    end else begin
      previous_request<=request;
      finished<='0;
      ltsm_pattern_aborted<=0;
      if (pending_valid && pending_cancel) begin
        pending_valid<=0;
        ltsm_pattern_aborted<=1;
      end
      if (launch) begin
        pending_valid<=0;
        active_owner<=pending_owner;
        active_context<=pending_context;
        active_kind<=pending_kind;
        cancel_q<=0;
        source_state<=WAIT_DONE;
      end
      if (source_state==WAIT_DONE) begin
        if (cancel_now) cancel_q<=1;
        if (active_done) begin
          // Clear cancel with request return-to-zero, BEFORE mailbox ready.
          // This lets cancellation settle before a following command arrives.
          cancel_q<=0;
          source_state<=RETURN_ZERO;
          if (active_aborted || cancel_q || cancel_now) ltsm_pattern_aborted<=1;
          else finished<=active_owner;
        end
      end
      if (source_state==RETURN_ZERO && active_ready) source_state<=IDLE;
      if (|rise) begin
        if (multiple_rise) ltsm_pattern_error[0]<=1;
        else if (!decoded_legal) ltsm_pattern_error[1]<=1;
        else if (pending_valid && !launch && !pending_cancel) ltsm_pattern_error[2]<=1;
        else begin
          pending_valid<=1;
          pending_mask<=decoded_mask;
          pending_kind<=decoded_kind;
          pending_owner<=rise;
          pending_context<=context_now;
        end
      end
    end
  end

  // Four source halves and all return synchronizers remain in this region.
  Ltsm800CommandSource #(.WIDTH(LANES+18),.STAGES(SYNC_STAGES)) u_src500 (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_valid_i(launch && pending_kind==K_LFSR),
    .src_ready_o(channel_ready[K_LFSR]),.src_data_i({pending_mask,LFSR_WORDS,K_LFSR}),
    .src_done_o(channel_done[K_LFSR]),.src_aborted_o(channel_aborted[K_LFSR]),
    .link_req_o(tx500_req_o),.link_payload_o(tx500_payload_o),
    .link_ack_async_i(tx500_ack_i),.link_aborted_async_i(tx500_aborted_i));
  Ltsm800CommandSource #(.WIDTH(LANES),.STAGES(SYNC_STAGES)) u_srcdata2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_valid_i(launch && pending_kind==K_ID),
    .src_ready_o(channel_ready[K_ID]),.src_data_i(pending_mask),
    .src_done_o(channel_done[K_ID]),.src_aborted_o(channel_aborted[K_ID]),
    .link_req_o(txdata2g_req_o),.link_payload_o(txdata2g_lane_mask_o),
    .link_ack_async_i(txdata2g_ack_i),.link_aborted_async_i(txdata2g_aborted_i));
  // Event-only endpoints have no command payload route. The constant source
  // payload bit below is unconnected and can be removed by synthesis.
  wire unused_valid_payload,unused_clock_payload;
  Ltsm800CommandSource #(.WIDTH(1),.STAGES(SYNC_STAGES)) u_srcvalid2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_valid_i(launch && pending_kind==K_VAL),
    .src_ready_o(channel_ready[K_VAL]),.src_data_i(1'b0),
    .src_done_o(channel_done[K_VAL]),.src_aborted_o(channel_aborted[K_VAL]),
    .link_req_o(txvalid2g_req_o),.link_payload_o(unused_valid_payload),
    .link_ack_async_i(txvalid2g_ack_i),.link_aborted_async_i(txvalid2g_aborted_i));
  Ltsm800CommandSource #(.WIDTH(1),.STAGES(SYNC_STAGES)) u_srcclock2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_valid_i(launch && pending_kind==K_CLK),
    .src_ready_o(channel_ready[K_CLK]),.src_data_i(1'b0),
    .src_done_o(channel_done[K_CLK]),.src_aborted_o(channel_aborted[K_CLK]),
    .link_req_o(txclock2g_req_o),.link_payload_o(unused_clock_payload),
    .link_ack_async_i(txclock2g_ack_i),.link_aborted_async_i(txclock2g_aborted_i));
  assign tx500_cancel_o=cancel_q && active_kind==K_LFSR;
  assign txdata2g_cancel_o=cancel_q && active_kind==K_ID;
  assign txvalid2g_cancel_o=cancel_q && active_kind==K_VAL;
  assign txclock2g_cancel_o=cancel_q && active_kind==K_CLK;

  assign {ltsm_flagFromAnalog_rxDeskew_lfsrPatternSent,
    ltsm_flagFromAnalog_d2cSender_lfsrPatternSent,
    ltsm_flagFromAnalog_d2cSender_valTrainPatternSent,
    ltsm_flagFromAnalog_dataVref_finishedPattern,
    ltsm_flagFromAnalog_valVref_finishedPattern,
    ltsm_flagFromAnalog_RepairMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_ReversalMbFinishedLaneIDPattern,
    ltsm_flagFromAnalog_FinishedValTrainPattern,
    ltsm_flagFromAnalog_FinishedClkPatterns}=finished;
`ifndef SYNTHESIS
  initial assert (LANES>=1) else $fatal(1,"LANES must be positive");
  assert property (@(posedge clock) disable iff (!reset_ltsm_n) $onehot0(finished));
  assert property (@(posedge clock) disable iff (!reset_ltsm_n) $onehot0({tx500_req_o,txdata2g_req_o,txvalid2g_req_o,txclock2g_req_o}));
`endif
endmodule
`default_nettype wire


`default_nettype none
module Ltsm800ResetSync #(
  parameter integer STAGES = 3
) (
  input  wire clk_i,
  input  wire arst_ni,
  output wire rst_no
);
  (* async_reg = "true", dont_touch = "true" *) logic [STAGES-1:0] release_q;
  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) release_q <= '0;
    else release_q <= {release_q[STAGES-2:0], 1'b1};
  end
  assign rst_no = release_q[STAGES-1];
`ifndef SYNTHESIS
  initial assert (STAGES >= 2) else $fatal(1, "Reset synchronizer needs >=2 stages");
`endif
endmodule

module Ltsm800SyncBit #(
  parameter integer STAGES = 3
) (
  input  wire clk_i,
  input  wire rst_ni,
  input  wire async_i,
  output wire sync_o
);
  (* async_reg = "true", dont_touch = "true" *) logic [STAGES-1:0] sync_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sync_q <= '0;
    else sync_q <= {sync_q[STAGES-2:0], async_i};
  end
  assign sync_o = sync_q[STAGES-1];
`ifndef SYNTHESIS
  initial assert (STAGES >= 2) else $fatal(1, "CDC synchronizer needs >=2 stages");
`endif
endmodule

// Source half of the execution-acknowledged mailbox. Physical boundary ports
// are explicit; no destination clock or destination flops exist in this module.
// Payload and returning result use a bundled-data CDC timing contract.
module Ltsm800CommandSource #(
  parameter integer WIDTH=34,
  parameter integer STAGES=3
) (
  input wire src_clk_i,
  input wire src_rst_ni,
  input wire src_valid_i,
  output wire src_ready_o,
  input wire [WIDTH-1:0] src_data_i,
  output logic src_done_o,
  output logic src_aborted_o,
  output wire link_req_o,
  output wire [WIDTH-1:0] link_payload_o,
  input wire link_ack_async_i,
  input wire link_aborted_async_i
);
  typedef enum logic [1:0] {SRC_IDLE,SRC_WAIT_ACK,SRC_WAIT_LOW} src_state_t;
  src_state_t src_state_q;
  logic req_q;
  logic [WIDTH-1:0] payload_q;
  wire ack_sync;
  Ltsm800SyncBit #(.STAGES(STAGES)) u_ack_sync (
    .clk_i(src_clk_i),.rst_ni(src_rst_ni),.async_i(link_ack_async_i),.sync_o(ack_sync));
  assign src_ready_o=(src_state_q==SRC_IDLE);
  assign link_req_o=req_q;
  assign link_payload_o=payload_q;
  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
    if (!src_rst_ni) begin
      src_state_q<=SRC_IDLE; req_q<=0; payload_q<='0;
      src_done_o<=0; src_aborted_o<=0;
    end else begin
      src_done_o<=0;
      case (src_state_q)
        SRC_IDLE: if (src_valid_i) begin
          payload_q<=src_data_i; req_q<=1; src_aborted_o<=0;
          src_state_q<=SRC_WAIT_ACK;
        end
        SRC_WAIT_ACK: if (ack_sync) begin
          // Stable result accompanies the remote registered ack. Bound this
          // data path in STA; do not independently synchronize result bits.
          src_aborted_o<=link_aborted_async_i;
          src_done_o<=1; req_q<=0; src_state_q<=SRC_WAIT_LOW;
        end
        SRC_WAIT_LOW: if (!ack_sync) src_state_q<=SRC_IDLE;
        default: src_state_q<=SRC_IDLE;
      endcase
    end
  end
`ifndef SYNTHESIS
  initial assert (WIDTH>0) else $fatal(1,"Mailbox WIDTH must be positive");
  assert property (@(posedge src_clk_i) disable iff (!src_rst_ni)
    req_q && $past(req_q) |-> $stable(payload_q))
    else $error("Source changed held command payload while request active");
`endif
endmodule

`default_nettype wire
