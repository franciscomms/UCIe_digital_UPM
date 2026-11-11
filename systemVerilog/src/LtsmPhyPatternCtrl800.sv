`default_nettype none
// PHYSICAL REGION 1: 800 MHz LTSM command capture / dispatch / completion.
// Place this hierarchy near UCIe digital. Its only clock is the LTSM clock.
// Four receivers: 500 MHz LFSR, 2 GHz data ID, 2 GHz valid, 2 GHz clock repair.
// Only the 500 MHz link carries a lane mask; all 2 GHz links are event-only.
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
  // All LTSM inputs, including this configuration mask, are synchronous to clock.
  // The mask is used ONLY for custom tests. Normal training selects all LANES.
  // For JTAG use, start while busy is low and keep the mask stable until busy
  // has asserted and returned low. A JTAG-programmed mask needs its own safe
  // configuration transfer into clock; only the trigger is synchronized here.
  input wire [LANES-1:0] ltsm_data_lane_mask,
  // Asynchronous JTAG register LEVEL, synchronized internally. One rising edge
  // requests one custom LFSR burst. Holding high does not repeat the test.
  // After completion, clear it and allow SYNC_STAGES+1 clock cycles of low
  // before asserting it again. Use a held register bit, not a short TCK pulse.
  // Issue custom tests with the normal data path in its externally selected
  // test mode. This controller does not arbitrate FIFO/normal traffic.
  input wire custom_train_jtag,
  input wire ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
  input wire ltsm_flagToAnalog_valVref_resetLocalTxScrambler,
  input wire ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
  input wire ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
  input wire ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
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
  // Sticky until common reset: [0] multiple LTSM edges or LTSM/JTAG collision,
  // [1] LTSM request/state mismatch or zero custom mask, [2] queue overflow.
  // A simultaneous LTSM/JTAG edge keeps LTSM priority and rejects the JTAG edge.
  output logic [2:0] ltsm_pattern_error,
  output wire reset_ltsm_n,
  // Inter-region links. Payload is held through the entire four-phase handshake.
  // These are CDC links, not synchronous ready/valid ports across the floorplan.
  // Each lane raises its ACK when it has handled the request and holds it
  // until it observes REQ low. REQ falls after every lane has acknowledged;
  // the next command waits until every ACK has returned low.
  // Commands run to completion; only common reset can interrupt a command.
  // tx500_ack_i[lane] covers either a burst or a reseed on that lane.
  // A reseed resets all TX LFSRs. For a burst, masked-off lanes acknowledge
  // without transmitting. txdata2g_ack_i[lane] acknowledges lane-ID training.
  // The clock and valid engines each return a single ACK.
  // Each enabled 500 MHz lane sends 4096 UI (128 32-bit words) per normal
  // or custom burst. The burst length is implicit.
  output wire tx500_req_o,
  output wire tx500_req_rst_o,
  output wire [LANES-1:0] tx500_payload_o,
  input wire [LANES-1:0] tx500_ack_i,
  output wire txdata2g_req_o,
  input wire [LANES-1:0] txdata2g_ack_i,
  output wire txvalid2g_req_o,
  input wire txvalid2g_ack_i,
  output wire txclock2g_req_o,
  input wire txclock2g_ack_i
);
  // Local destination selectors. Reset and burst share the 500 MHz endpoint.
  localparam logic [1:0] K_CLK=2'd0, K_VAL=2'd1, K_ID=2'd2, K_LFSR=2'd3;
  localparam logic [LANES-1:0] ALL_LANES={LANES{1'b1}};

  Ltsm800ResetSync #(.STAGES(SYNC_STAGES)) u_rst_ltsm
    (.clk_i(clock),.arst_ni(reset_n),.rst_no(reset_ltsm_n));

  wire custom_train_sync;
  logic previous_custom_train;
  Ltsm800SyncBit #(.STAGES(SYNC_STAGES)) u_custom_train_sync (
    .clk_i(clock),.rst_ni(reset_ltsm_n),
    .async_i(custom_train_jtag),.sync_o(custom_train_sync));
  wire custom_rise=custom_train_sync && !previous_custom_train;

  wire [8:0] request={ltsm_flagToAnalog_rxDeskew_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_sendLfsrPattern,
    ltsm_flagToAnalog_d2cSender_sendValTrainPattern,
    ltsm_flagToAnalog_dataVref_sendPattern,
    ltsm_flagToAnalog_valVref_sendPattern,
    ltsm_flagToAnalog_RepairMbSendLaneIDPattern,
    ltsm_flagToAnalog_ReversalMbSendLaneIDPattern,
    ltsm_flagToAnalog_SendValTrainPattern,ltsm_flagToAnalog_SendClkPatterns};
  // Detect each input separately: a held sender flag must not hide a new
  // edge on a different flag. Simultaneous edges request one common reseed.
  // LINKINIT holds its flag high for the entire state. Capture the entry once.
  wire [4:0] reset_flags = {
    ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    ltsm_flagToAnalog_rxDeskew_resetLocalTxScrambler,
    ltsm_flagToAnalog_d2cSender_resetLocalScrambler,
    ltsm_flagToAnalog_dataVref_resetLocalTxScrambler,
    ltsm_flagToAnalog_valVref_resetLocalTxScrambler};
  logic [4:0] previous_reset_flags;
  wire reset_rise = |(reset_flags & ~previous_reset_flags);
  logic [8:0] previous_request, finished;
  wire [8:0] rise=request & ~previous_request;
  wire custom_selected=custom_rise && !(|rise);
  wire custom_collision=custom_rise && (|rise);
  logic [1:0] decoded_kind;
  logic [LANES-1:0] decoded_mask;
  logic decoded_legal;
  wire multiple_rise=(rise != 0) && ((rise & (rise-9'd1)) != 0);
  always_comb begin
    decoded_kind=K_CLK;
    decoded_mask=ALL_LANES;
    decoded_legal=1'b0;
    case (rise)
      9'b000000001: decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==2);
      9'b000000010: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==3);
      end
      9'b000000100,9'b000001000: begin
        decoded_kind=K_ID;
        decoded_legal=(ltsm_state==5 &&
          ((rise[2] && ltsm_dbg_mbinitSubstate==4) ||
           (rise[3] && ltsm_dbg_mbinitSubstate==5)));
      end
      9'b000010000: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==6 && (ltsm_dbg_mbtrainState==1 || ltsm_dbg_mbtrainState==7));
      end
      9'b000100000: begin
        decoded_kind=K_LFSR;
        decoded_legal=(ltsm_state==6 &&
          (ltsm_dbg_mbtrainState==2 || ltsm_dbg_mbtrainState==9));
      end
      9'b001000000: begin
        decoded_kind=K_VAL;
        decoded_legal=(ltsm_state==6 && ltsm_dbg_mbtrainState==6);
      end
      9'b010000000: begin
        decoded_kind=K_LFSR;
        decoded_legal=(ltsm_state==6 &&
          (ltsm_dbg_mbtrainState==8 || ltsm_dbg_mbtrainState==11 || ltsm_dbg_mbtrainState==12));
      end
      9'b100000000: begin
        decoded_kind=K_LFSR;
        decoded_legal=(ltsm_state==6 && ltsm_dbg_mbtrainState==10);
      end
      default: begin end
    endcase
    if (custom_selected) begin
      decoded_kind=K_LFSR;
      decoded_mask=ltsm_data_lane_mask;
      decoded_legal=(|ltsm_data_lane_mask);
    end
  end

  // Source-domain capture is necessary: synchronizing the nine raw requests
  // independently would lose short pulses and detach them from their state.
  // Keep one pending pattern and one pending reseed while a handshake runs.
  // Dispatch in capture order, with reset first for edges on the same cycle.
  // State and mask legality are checked at capture. Later state changes or
  // request deassertion do not discard an accepted active or pending command.
  typedef enum logic [1:0] {IDLE,WAIT_DONE,RETURN_ZERO} source_state_t;
  source_state_t source_state;
  logic pending_valid, pending_reset, reset_first;
  logic [LANES-1:0] pending_mask;
  logic [1:0] pending_kind;
  logic [8:0] pending_owner,active_owner;
  logic [1:0] active_kind;
  // Channel index follows the local pattern-kind enumeration.
  wire [3:0] channel_ready,channel_done;
  wire selected_ready=channel_ready[pending_kind];
  wire select_reset = pending_reset && (!pending_valid || reset_first);
  wire launch_reset = (source_state==IDLE) && select_reset && channel_ready[K_LFSR];
  wire launch_pattern = (source_state==IDLE) && !select_reset && pending_valid && selected_ready;
  wire capture_reset = reset_rise && (!pending_reset || launch_reset);
  wire pattern_rise = (|rise) || custom_rise;
  wire valid_pattern = pattern_rise && !multiple_rise && decoded_legal;
  wire capture_pattern = valid_pattern && (!pending_valid || launch_pattern);
  wire active_done=channel_done[active_kind];
  wire active_ready=channel_ready[active_kind];
  assign ltsm_pattern_busy=pending_reset || pending_valid || (source_state!=IDLE);
  always_ff @(posedge clock or negedge reset_ltsm_n) begin
    if (!reset_ltsm_n) begin
      source_state<=IDLE; pending_valid<=0; pending_mask<='0; pending_kind<=K_CLK;
      pending_owner<='0; active_owner<='0;
      pending_reset<=0; reset_first<=0; previous_reset_flags<='0;
      active_kind<=K_CLK; previous_request<='0; previous_custom_train<=0; finished<='0;
      ltsm_pattern_error<='0;
    end else begin
      previous_request<=request;
      previous_reset_flags<=reset_flags;
      previous_custom_train<=custom_train_sync;
      finished<='0;
      if (custom_collision) ltsm_pattern_error[0]<=1;
      if (launch_reset) pending_reset<=0;
      if (launch_pattern) pending_valid<=0;
      if (launch_reset || launch_pattern) begin
        active_owner<=launch_reset ? 9'b0 : pending_owner;
        active_kind<=launch_reset ? K_LFSR : pending_kind;
        source_state<=WAIT_DONE;
      end
      if (source_state==WAIT_DONE) begin
        if (active_done) begin
          source_state<=RETURN_ZERO;
          finished<=active_owner;
        end
      end
      if (source_state==RETURN_ZERO && active_ready) source_state<=IDLE;
      if (capture_reset) begin
        pending_reset<=1;
        // An older pattern still in its slot goes first. If both slots
        // receive new commands on this clock, the reset goes first.
        reset_first<=!pending_valid || launch_pattern;
      end else if (capture_pattern) begin
        // Any reset already waiting is older than this pattern.
        reset_first<=1;
      end
      if (capture_pattern) begin
        pending_valid<=1;
        pending_mask<=decoded_mask;
        pending_kind<=decoded_kind;
        pending_owner<=rise; // custom burst has no LTSM completion owner
      end
      if (multiple_rise) ltsm_pattern_error[0]<=1;
      else if (pattern_rise && !decoded_legal) ltsm_pattern_error[1]<=1;
      if ((reset_rise && !capture_reset) || (valid_pattern && !capture_pattern))
        ltsm_pattern_error[2]<=1;
    end
  end

  // Four source halves and all return synchronizers remain in this region.
  // Burst and reseed share the same per-lane ACKs and return-to-zero FSM.
  Ltsm800CommandSource #(
    .WIDTH(LANES), .STAGES(SYNC_STAGES), .REQ_WIDTH(2), .ACK_WIDTH(LANES)
  ) u_src500 (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),
    .src_valid_i(launch_reset || (launch_pattern && pending_kind==K_LFSR)),
    .src_req_i({launch_reset,!launch_reset}),
    .src_ready_o(channel_ready[K_LFSR]),.src_data_i(launch_reset ? ALL_LANES : pending_mask),
    .src_done_o(channel_done[K_LFSR]),
    .link_req_o({tx500_req_rst_o,tx500_req_o}),.link_payload_o(tx500_payload_o),
    .link_ack_async_i(tx500_ack_i));
  // All 2 GHz endpoints train all their relevant lanes. No lane mask is routed.
  // Constant source payload bits are unconnected and can be removed by synthesis.
  wire unused_id_payload,unused_valid_payload,unused_clock_payload;
  Ltsm800CommandSource #(.WIDTH(1),.STAGES(SYNC_STAGES),.ACK_WIDTH(LANES)) u_srcdata2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_req_i(1'b1),.src_valid_i(launch_pattern && pending_kind==K_ID),
    .src_ready_o(channel_ready[K_ID]),.src_data_i(1'b0),
    .src_done_o(channel_done[K_ID]),
    .link_req_o(txdata2g_req_o),.link_payload_o(unused_id_payload),
    .link_ack_async_i(txdata2g_ack_i));
  Ltsm800CommandSource #(.WIDTH(1),.STAGES(SYNC_STAGES)) u_srcvalid2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_req_i(1'b1),.src_valid_i(launch_pattern && pending_kind==K_VAL),
    .src_ready_o(channel_ready[K_VAL]),.src_data_i(1'b0),
    .src_done_o(channel_done[K_VAL]),
    .link_req_o(txvalid2g_req_o),.link_payload_o(unused_valid_payload),
    .link_ack_async_i(txvalid2g_ack_i));
  Ltsm800CommandSource #(.WIDTH(1),.STAGES(SYNC_STAGES)) u_srcclock2g (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),.src_req_i(1'b1),.src_valid_i(launch_pattern && pending_kind==K_CLK),
    .src_ready_o(channel_ready[K_CLK]),.src_data_i(1'b0),
    .src_done_o(channel_done[K_CLK]),
    .link_req_o(txclock2g_req_o),.link_payload_o(unused_clock_payload),
    .link_ack_async_i(txclock2g_ack_i));

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
  assert property (@(posedge clock) disable iff (!reset_ltsm_n) $onehot0({tx500_req_rst_o,tx500_req_o,txdata2g_req_o,txvalid2g_req_o,txclock2g_req_o}));
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
// Payload uses a bundled-data CDC timing contract. Synchronize each ACK bit
// before checking for unanimous completion or return to idle.
module Ltsm800CommandSource #(
  parameter integer WIDTH=34,
  parameter integer STAGES=3,
  parameter integer REQ_WIDTH=1,
  parameter integer ACK_WIDTH=1
) (
  input wire src_clk_i,
  input wire src_rst_ni,
  input wire src_valid_i,
  input wire [REQ_WIDTH-1:0] src_req_i, // one-hot command, captured at launch
  output wire src_ready_o,
  input wire [WIDTH-1:0] src_data_i,
  output logic src_done_o,
  output wire [REQ_WIDTH-1:0] link_req_o,
  output wire [WIDTH-1:0] link_payload_o,
  input wire [ACK_WIDTH-1:0] link_ack_async_i
);
  typedef enum logic [1:0] {SRC_IDLE,SRC_WAIT_ACK,SRC_WAIT_LOW} src_state_t;
  src_state_t src_state_q;
  logic [REQ_WIDTH-1:0] req_q;
  logic [WIDTH-1:0] payload_q;
  wire [ACK_WIDTH-1:0] ack_sync;
  for (genvar lane = 0; lane < ACK_WIDTH; lane++) begin : g_lane_ack
    Ltsm800SyncBit #(.STAGES(STAGES)) u_ack_sync (
      .clk_i(src_clk_i), .rst_ni(src_rst_ni),
      .async_i(link_ack_async_i[lane]), .sync_o(ack_sync[lane]));
  end
  wire all_ack_high = &ack_sync;
  wire all_ack_low = ~|ack_sync;
  assign src_ready_o=(src_state_q==SRC_IDLE) && all_ack_low;
  assign link_req_o=req_q;
  assign link_payload_o=payload_q;
  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
    if (!src_rst_ni) begin
      src_state_q<=SRC_IDLE; req_q<=0; payload_q<='0;
      src_done_o<=0;
    end else begin
      src_done_o<=0;
      case (src_state_q)
        SRC_IDLE: if (src_valid_i && src_ready_o) begin
          payload_q<=src_data_i; req_q<=src_req_i;
          src_state_q<=SRC_WAIT_ACK;
        end
        SRC_WAIT_ACK: if (all_ack_high) begin
          // Completion acknowledgment: return req low and report done once.
          src_done_o<=1; req_q<=0; src_state_q<=SRC_WAIT_LOW;
        end
        SRC_WAIT_LOW: if (all_ack_low) src_state_q<=SRC_IDLE;
        default: src_state_q<=SRC_IDLE;
      endcase
    end
  end
`ifndef SYNTHESIS
  initial assert (WIDTH>0) else $fatal(1,"Mailbox WIDTH must be positive");
  initial assert (ACK_WIDTH>0) else $fatal(1,"Mailbox ACK_WIDTH must be positive");
  assert property (@(posedge src_clk_i) disable iff (!src_rst_ni)
    (|req_q) && $past(|req_q) |-> $stable({req_q,payload_q}))
    else $error("Source changed held command payload while request active");
`endif
endmodule

`default_nettype wire
