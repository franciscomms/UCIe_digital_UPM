`default_nettype none
// PHYSICAL REGION 1: 800 MHz LTSM command capture / dispatch / completion.
// Place this hierarchy near UCIe digital. Its only clock is the LTSM clock.
//
// This controller talks over ONE CDC handshake (the seq_* link) to
// PhyTxSequencer (ucie_phy_control/, 500 MHz). The sequencer is the only CDC
// point on the PHY side and the only owner of TX pattern timing; it drives
// the clock, valid, data lane-ID and 500 MHz LFSR endpoints together.
//
// Command set sent as seq_op_o:
//   0 CLK_TRAIN  SendClkPatterns
//   1 VAL_TRAIN  SendValTrainPattern, valVref_sendPattern,
//                d2cSender_sendValTrainPattern
//   2 LANEID     ReversalMbSendLaneIDPattern, RepairMbSendLaneIDPattern
//   3 LFSR       dataVref_sendPattern, d2cSender_sendLfsrPattern,
//                rxDeskew_sendLfsrPattern, custom JTAG burst (seq_mask_o)
//   4 RESEED     any of the five reset-scrambler flags (edge detected)
//   5 ACTIVE     launched once on each entry into ltsm_state == 8 (ACTIVE),
//                stopped when ltsm_state != 8. Raises no Finished flag.
// Training lengths are fixed in the sequencer (128 iterations).
//
// Link protocol (see PhyTxSequencer for the receiving side):
//   seq_req_o   level; held until the synchronized ack is seen.
//   seq_stop_o  level; raised to end the running command early, held until
//               ack. Raised for ACTIVE when ltsm_state leaves 8 and for any
//               other command when ltsm_state enters 9 (TRAIN_ERROR) or
//               0 (RESET).
//   seq_op_o, seq_mask_o  bundled; stable from before req rises until ack
//               has fallen.
//   seq_ack_i   synchronized here. Rises after the whole envelope (clock off).
//   A command for which this controller raised stop counts as aborted and
//   does not raise its Finished flag (decided locally, nothing returned).
//
// Preserve hierarchy and apply the bundled-data timing constraints in
// ucie_phy_control/constraints/cdc_constraints.sdc.
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
  // High while a command is pending or running (including all of ACTIVE).
  output wire ltsm_pattern_busy,
  // Sticky until common reset: [0] multiple LTSM edges or LTSM/JTAG (or
  // ACTIVE-entry/JTAG) collision, [1] LTSM request/state mismatch or zero
  // custom mask, [2] queue overflow. A simultaneous LTSM/JTAG edge keeps LTSM
  // priority and rejects the JTAG edge. Discarding a queued command on
  // TRAIN_ERROR/RESET entry does not set an error bit.
  output logic [2:0] ltsm_pattern_error,
  output wire reset_ltsm_n,
  // Status: PHY is in ACTIVE with its clock running (PRE finished).
  // Synchronized copy of the sequencer's active_ready_o.
  output wire ltsm_active_ready,
  // ---- Link to PhyTxSequencer (CDC, see protocol above) --------------------
  output wire seq_req_o,
  output wire seq_stop_o,
  output wire [2:0] seq_op_o,
  output wire [LANES-1:0] seq_mask_o,
  input wire seq_ack_i,
  input wire seq_active_ready_i
);
  // Command encoding (shared with PhyTxSequencer).
  localparam logic [2:0] OP_CLK_TRAIN=3'd0, OP_VAL_TRAIN=3'd1, OP_LANEID=3'd2,
                         OP_LFSR=3'd3, OP_RESEED=3'd4, OP_ACTIVE=3'd5;
  localparam logic [3:0] ST_RESET=4'd0, ST_ACTIVE=4'd8, ST_TRAIN_ERROR=4'd9;
  localparam logic [LANES-1:0] ALL_LANES={LANES{1'b1}};

  Ltsm800ResetSync #(.STAGES(SYNC_STAGES)) u_rst_ltsm
    (.clk_i(clock),.arst_ni(reset_n),.rst_no(reset_ltsm_n));

  wire custom_train_sync;
  logic previous_custom_train;
  Ltsm800SyncBit #(.STAGES(SYNC_STAGES)) u_custom_train_sync (
    .clk_i(clock),.rst_ni(reset_ltsm_n),
    .async_i(custom_train_jtag),.sync_o(custom_train_sync));
  wire custom_rise=custom_train_sync && !previous_custom_train;

  Ltsm800SyncBit #(.STAGES(SYNC_STAGES)) u_active_ready_sync (
    .clk_i(clock),.rst_ni(reset_ltsm_n),
    .async_i(seq_active_ready_i),.sync_o(ltsm_active_ready));

  // LTSM state events. ACTIVE is entered/left on ltsm_state == 8. Trainings
  // are stopped, and a queued training discarded, on ENTRY into TRAIN_ERROR
  // or RESET. Entry (not level) is used so a custom JTAG burst can still be
  // issued while the LTSM sits in RESET (PHY test mode).
  logic [3:0] previous_state;
  wire in_active = (ltsm_state == ST_ACTIVE);
  wire active_entry = in_active && (previous_state != ST_ACTIVE);
  wire in_abort_state = (ltsm_state == ST_TRAIN_ERROR) || (ltsm_state == ST_RESET);
  wire was_abort_state = (previous_state == ST_TRAIN_ERROR) || (previous_state == ST_RESET);
  wire abort_entry = in_abort_state && !was_abort_state;

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
  // ACTIVE entry and LTSM flags have priority over a JTAG edge.
  wire custom_selected=custom_rise && !(|rise) && !active_entry;
  wire custom_collision=custom_rise && ((|rise) || active_entry);
  logic [2:0] decoded_op;
  logic [LANES-1:0] decoded_mask;
  logic decoded_legal;
  wire multiple_rise=(rise != 0) && ((rise & (rise-9'd1)) != 0);
  // Legality decode: MBINIT/MBTRAIN substate numbers unchanged.
  always_comb begin
    decoded_op=OP_CLK_TRAIN;
    decoded_mask=ALL_LANES;
    decoded_legal=1'b0;
    case (rise)
      9'b000000001: decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==2);
      9'b000000010: begin
        decoded_op=OP_VAL_TRAIN;
        decoded_legal=(ltsm_state==5 && ltsm_dbg_mbinitSubstate==3);
      end
      9'b000000100,9'b000001000: begin
        decoded_op=OP_LANEID;
        decoded_legal=(ltsm_state==5 &&
          ((rise[2] && ltsm_dbg_mbinitSubstate==4) ||
           (rise[3] && ltsm_dbg_mbinitSubstate==5)));
      end
      9'b000010000: begin
        decoded_op=OP_VAL_TRAIN;
        decoded_legal=(ltsm_state==6 && (ltsm_dbg_mbtrainState==1 || ltsm_dbg_mbtrainState==7));
      end
      9'b000100000: begin
        decoded_op=OP_LFSR;
        decoded_legal=(ltsm_state==6 &&
          (ltsm_dbg_mbtrainState==2 || ltsm_dbg_mbtrainState==9));
      end
      9'b001000000: begin
        decoded_op=OP_VAL_TRAIN;
        decoded_legal=(ltsm_state==6 && ltsm_dbg_mbtrainState==6);
      end
      9'b010000000: begin
        decoded_op=OP_LFSR;
        decoded_legal=(ltsm_state==6 &&
          (ltsm_dbg_mbtrainState==8 || ltsm_dbg_mbtrainState==11 || ltsm_dbg_mbtrainState==12));
      end
      9'b100000000: begin
        decoded_op=OP_LFSR;
        decoded_legal=(ltsm_state==6 && ltsm_dbg_mbtrainState==10);
      end
      default: begin end
    endcase
    if (custom_selected) begin
      decoded_op=OP_LFSR;
      decoded_mask=ltsm_data_lane_mask;
      decoded_legal=(|ltsm_data_lane_mask);
    end
  end

  // Source-domain capture is necessary: synchronizing the nine raw requests
  // independently would lose short pulses and detach them from their state.
  // Keep one pending pattern and one pending reseed while a handshake runs.
  // Dispatch in capture order, with reset first for edges on the same cycle.
  // State and mask legality are checked at capture. ACTIVE uses the same
  // pattern slot, so a LINKINIT reseed captured earlier is sent before it.
  // A queued ACTIVE is discarded if the state leaves 8 before it launches; a
  // queued training is discarded on TRAIN_ERROR/RESET entry.
  typedef enum logic [1:0] {IDLE,WAIT_DONE,RETURN_ZERO} source_state_t;
  source_state_t source_state;
  logic pending_valid, pending_reset, reset_first;
  logic [LANES-1:0] pending_mask;
  logic [2:0] pending_op, active_op;
  logic [8:0] pending_owner,active_owner;
  wire src_ready, src_done, src_aborted;

  wire pattern_rise = (|rise) || custom_selected;
  wire valid_pattern = pattern_rise && !multiple_rise && decoded_legal;
  // ACTIVE entry never coincides with a legal LTSM training edge (those are
  // only legal in MBINIT/MBTRAIN) and wins over a JTAG edge.
  wire new_pattern = valid_pattern || active_entry;
  wire [2:0] new_op = active_entry ? OP_ACTIVE : decoded_op;
  wire [LANES-1:0] new_mask = active_entry ? ALL_LANES : decoded_mask;
  wire [8:0] new_owner = active_entry ? 9'b0 : rise; // custom/ACTIVE: no owner

  wire drop_pending = pending_valid &&
    ((pending_op == OP_ACTIVE) ? !in_active : abort_entry);
  wire select_reset = pending_reset && (!pending_valid || reset_first);
  wire launch_reset = (source_state==IDLE) && select_reset && src_ready;
  wire launch_pattern = (source_state==IDLE) && !select_reset && pending_valid &&
    !drop_pending && src_ready;
  wire pattern_slot_free = !pending_valid || launch_pattern || drop_pending;
  wire capture_reset = reset_rise && (!pending_reset || launch_reset);
  wire capture_pattern = new_pattern && pattern_slot_free;

  // Early end of the running command. The source half latches it until ack.
  wire stop_command = (source_state==WAIT_DONE) &&
    ((active_op == OP_ACTIVE) ? !in_active : abort_entry);

  assign ltsm_pattern_busy=pending_reset || pending_valid || (source_state!=IDLE);
  always_ff @(posedge clock or negedge reset_ltsm_n) begin
    if (!reset_ltsm_n) begin
      source_state<=IDLE; pending_valid<=0; pending_mask<='0; pending_op<=OP_CLK_TRAIN;
      pending_owner<='0; active_owner<='0; active_op<=OP_CLK_TRAIN;
      pending_reset<=0; reset_first<=0; previous_reset_flags<='0;
      previous_request<='0; previous_custom_train<=0; finished<='0;
      previous_state<=ST_RESET;
      ltsm_pattern_error<='0;
    end else begin
      previous_request<=request;
      previous_reset_flags<=reset_flags;
      previous_custom_train<=custom_train_sync;
      previous_state<=ltsm_state;
      finished<='0;
      if (custom_collision) ltsm_pattern_error[0]<=1;
      if (launch_reset) pending_reset<=0;
      if (launch_pattern || drop_pending) pending_valid<=0;
      if (launch_reset || launch_pattern) begin
        active_owner<=launch_reset ? 9'b0 : pending_owner;
        active_op<=launch_reset ? OP_RESEED : pending_op;
        source_state<=WAIT_DONE;
      end
      if (source_state==WAIT_DONE && src_done) begin
        source_state<=RETURN_ZERO;
        // An aborted command does not report Finished.
        finished<=src_aborted ? 9'b0 : active_owner;
      end
      if (source_state==RETURN_ZERO && src_ready) source_state<=IDLE;
      if (capture_reset) begin
        pending_reset<=1;
        // An older pattern still in its slot goes first. If both slots
        // receive new commands on this clock, the reset goes first.
        reset_first<=!pending_valid || launch_pattern || drop_pending;
      end else if (capture_pattern) begin
        // Any reset already waiting is older than this pattern.
        reset_first<=1;
      end
      if (capture_pattern) begin
        pending_valid<=1;
        pending_mask<=new_mask;
        pending_op<=new_op;
        pending_owner<=new_owner;
      end
      if (multiple_rise) ltsm_pattern_error[0]<=1;
      else if (pattern_rise && !decoded_legal) ltsm_pattern_error[1]<=1;
      if ((reset_rise && !capture_reset) || (new_pattern && !capture_pattern))
        ltsm_pattern_error[2]<=1;
    end
  end

  // One source half for the single sequencer link. Payload = {op, mask}.
  Ltsm800CommandSource #(
    .WIDTH(3+LANES), .STAGES(SYNC_STAGES), .REQ_WIDTH(1), .ACK_WIDTH(1)
  ) u_src_seq (
    .src_clk_i(clock),.src_rst_ni(reset_ltsm_n),
    .src_valid_i(launch_reset || launch_pattern),
    .src_req_i(1'b1),
    .src_stop_i(stop_command),
    .src_ready_o(src_ready),
    .src_data_i(launch_reset ? {OP_RESEED, ALL_LANES} : {pending_op, pending_mask}),
    .src_done_o(src_done),
    .src_aborted_o(src_aborted),
    .link_req_o(seq_req_o),
    .link_stop_o(seq_stop_o),
    .link_payload_o({seq_op_o, seq_mask_o}),
    .link_ack_async_i(seq_ack_i));

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
  assert property (@(posedge clock) disable iff (!reset_ltsm_n)
    (pending_valid && pending_op==OP_ACTIVE) |-> pending_owner==9'b0)
    else $error("ACTIVE must not own a Finished flag");
  assert property (@(posedge clock) disable iff (!reset_ltsm_n)
    seq_stop_o |-> seq_req_o)
    else $error("stop raised without a request");
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
// Early stop: src_stop_i while a command is outstanding raises link_stop_o,
// held until the ack is seen (it falls together with link_req_o).
// src_aborted_o reports, with src_done_o, whether stop was raised for the
// command. It is decided locally; the destination returns only the ack.
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
  input wire src_stop_i,                // end the outstanding command early
  output wire src_ready_o,
  input wire [WIDTH-1:0] src_data_i,
  output logic src_done_o,              // one-cycle completion pulse
  output logic src_aborted_o,           // stop was raised, valid with src_done_o
  output wire [REQ_WIDTH-1:0] link_req_o,
  output wire link_stop_o,
  output wire [WIDTH-1:0] link_payload_o,
  input wire [ACK_WIDTH-1:0] link_ack_async_i
);
  // SRC_LAUNCH: payload already driven, request rises on the next edge, so
  // the bundled payload is stable from BEFORE the request rises.
  typedef enum logic [1:0] {SRC_IDLE,SRC_LAUNCH,SRC_WAIT_ACK,SRC_WAIT_LOW} src_state_t;
  src_state_t src_state_q;
  logic [REQ_WIDTH-1:0] req_q, launch_req_q;
  logic stop_q;
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
  assign link_stop_o=stop_q;
  assign link_payload_o=payload_q;
  always_ff @(posedge src_clk_i or negedge src_rst_ni) begin
    if (!src_rst_ni) begin
      src_state_q<=SRC_IDLE; req_q<=0; launch_req_q<=0; stop_q<=0; payload_q<='0;
      src_done_o<=0; src_aborted_o<=0;
    end else begin
      src_done_o<=0;
      case (src_state_q)
        SRC_IDLE: if (src_valid_i && src_ready_o) begin
          payload_q<=src_data_i; launch_req_q<=src_req_i;
          src_state_q<=SRC_LAUNCH;
        end
        SRC_LAUNCH: begin
          req_q<=launch_req_q;
          if (src_stop_i) stop_q<=1;  // stop requested at launch: raise with req
          src_state_q<=SRC_WAIT_ACK;
        end
        SRC_WAIT_ACK: if (all_ack_high) begin
          // Completion acknowledgment: return req/stop low, report done once.
          // Aborted = this source raised stop for the command.
          src_done_o<=1; src_aborted_o<=stop_q;
          req_q<=0; stop_q<=0; src_state_q<=SRC_WAIT_LOW;
        end else if (src_stop_i) begin
          stop_q<=1;
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
  assert property (@(posedge src_clk_i) disable iff (!src_rst_ni)
    stop_q |-> (|req_q))
    else $error("Source stop held without a request");
`endif
endmodule

`default_nettype wire
