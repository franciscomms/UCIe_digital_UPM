`timescale 1ps/1ps
`default_nettype none
// One shared 2 GHz VALID lane for 16 DATA lanes. Connect bit n of
// lane_frame_enable_i to DATA lane n's frame_enable_o on the same clock.
// Framing retains phase across wire idle while at least one lane is receiving.
// To reacquire, let all lane enables go low for at least one clk_i edge.
// Enable framing during wire idle before the first DATA frame.
//
// Set val_mode_i before asserting val_req_i and hold both through ACK.
// Send the pattern after observing ARMED. A passing streak completes the trial.
// The controller issues a full-point request with DATA framing already armed
// only for combined DATA centering. That trial checks 512 delivered frame bytes
// (4096 UIs) while the DATA lanes continue receiving the shared frame tuple.
// To close a trial still awaiting a pass, assert val_finish_i after the
// final receive capture (including any split pattern) and hold it through ACK.
// Sample PASS with ACK. Release REQ and FINISH, then wait for ACK and ARMED
// low before issuing another request. The controller synchronizes return levels.
//
// Raw [7:0] = {Q0,Q4,Q2,Q6,Q1,Q5,Q3,Q7} by default. After reordering,
// bit 0 is earliest. The serial frame 11110000 therefore has value 8'h0f.
// Set RAW_Q0_AT_MSB identically on VALID and DATA. Drive each DATA lane's
// entry registers directly from the decoded frame tuple.
// train_done_o is a sticky pass indication, cleared when a new trial arms.
module rx_ucie_valid_lane #(
  parameter bit RAW_Q0_AT_MSB = 1'b1,
  parameter integer RESET_SYNC_STAGES = 3
) (
  input  wire             clk_i,
  input  wire             rst_ni,
  input  wire             val_req_i,
  input  wire             val_mode_i,       // 0 = repair, 1 = full point
  input  wire             val_finish_i,
  input  wire      [15:0] lane_frame_enable_i,
  input  wire      [7:0]  valid_word_i,
  output var logic        val_armed_o,
  output var logic        val_ack_o,
  output var logic        val_pass_o,
  output var logic        train_done_o,
  output wire      [7:0]  train_pattern_o,
  output var logic        phase_locked_o,
  output wire             frame_valid_o,
  output wire      [2:0]  frame_offset_o,
  output wire             framing_error_o
);
  // REPAIRVAL qualifies on 16 consecutive aligned patterns. Both Valid
  // Vref states require all 128 eight-UI patterns at the same alignment.
  localparam int REPAIR_MATCHES = 16;
  localparam int VREF_WORDS = 128;
  localparam int COUNT_WIDTH = $clog2(VREF_WORDS);
  localparam int CENTER_FRAMES = 4096 / 8;
  localparam int CENTER_COUNT_WIDTH = $clog2(CENTER_FRAMES);
  localparam logic [7:0] VALID_FRAME = 8'h0f;

  localparam int SYNC_STAGES = 3;
  wire rstvalid_n;
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_sync
    (.clk_i(clk_i), .arst_ni(rst_ni), .rst_no(rstvalid_n));
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] req_sync_q, finish_sync_q, mode_sync_q;
  always_ff @(posedge clk_i or negedge rstvalid_n) begin
    if (!rstvalid_n) begin
      req_sync_q <= '0;
      finish_sync_q <= '0;
      mode_sync_q <= '0;
    end else begin
      req_sync_q <= {req_sync_q[SYNC_STAGES-2:0], val_req_i};
      finish_sync_q <= {finish_sync_q[SYNC_STAGES-2:0], val_finish_i};
      mode_sync_q <= {mode_sync_q[SYNC_STAGES-2:0], val_mode_i};
    end
  end
  wire req_sync = req_sync_q[SYNC_STAGES-1];
  wire finish_sync = finish_sync_q[SYNC_STAGES-1];

  typedef enum logic [2:0] {V_IDLE, V_CLEAR, V_OBSERVE, V_DRAIN_FIRST,
                            V_DRAIN_LAST, V_SAMPLE, V_REPORT, V_RELEASE} valid_state_t;
  valid_state_t state_q;
  logic vref_q, combined_q;
  wire frame_wanted = |lane_frame_enable_i;
  wire framing = frame_wanted && (state_q == V_IDLE || combined_q);
  wire training = (state_q == V_OBSERVE) && !combined_q;
  wire monitoring = (state_q == V_OBSERVE) && combined_q;

  always_ff @(posedge clk_i or negedge rstvalid_n) begin
    if (!rstvalid_n) begin
      state_q <= V_IDLE;
      val_armed_o <= 1'b0;
      val_ack_o <= 1'b0;
      val_pass_o <= 1'b0;
      vref_q <= 1'b0;
      combined_q <= 1'b0;
    end else begin
      case (state_q)
        V_IDLE: if (req_sync && (!frame_wanted || mode_sync_q[SYNC_STAGES-1])) begin
          val_pass_o <= 1'b0;
          combined_q <= frame_wanted;
          state_q <= V_CLEAR;
        end
        V_CLEAR: begin
          vref_q <= mode_sync_q[SYNC_STAGES-1];
          val_armed_o <= 1'b1;
          state_q <= V_OBSERVE;
        end
        V_OBSERVE: begin
          if (train_done_o) state_q <= V_SAMPLE;
          else if (finish_sync) state_q <= combined_q ? V_DRAIN_FIRST : V_SAMPLE;
        end
        // The capture at FINISH may supply a frame byte to DATA two edges
        // later. Retire both possible trailing decisions before sampling PASS.
        V_DRAIN_FIRST: state_q <= V_DRAIN_LAST;
        V_DRAIN_LAST: state_q <= V_SAMPLE;
        V_SAMPLE: begin
          // The streak counter includes the capture on the last OBSERVE edge.
          val_pass_o <= train_done_o;
          state_q <= V_REPORT;
        end
        V_REPORT: begin
          val_ack_o <= 1'b1;
          state_q <= V_RELEASE;
        end
        V_RELEASE: if (!req_sync && !finish_sync) begin
          val_ack_o <= 1'b0;
          val_armed_o <= 1'b0;
          state_q <= V_IDLE;
        end
        default: begin
          state_q <= V_IDLE;
          val_armed_o <= 1'b0;
          val_ack_o <= 1'b0;
          val_pass_o <= 1'b0;
        end
      endcase
    end
  end

  function automatic logic [7:0] chronological(input logic [7:0] raw);
    if (RAW_Q0_AT_MSB)
      chronological = {raw[0],raw[4],raw[2],raw[6],raw[1],raw[5],raw[3],raw[7]};
    else
      chronological = {raw[7],raw[3],raw[5],raw[1],raw[6],raw[2],raw[4],raw[0]};
  endfunction

  logic training_q, framing_q;
  logic monitoring_q, monitoring_qq;
  logic [7:0] previous_word_q;
  wire [7:0] current_word = chronological(valid_word_i);
  wire [15:0] window_bits = {current_word, previous_word_q};
  // frame_matches[k] checks the eight UIs starting at bit k of the previous capture.
  wire [7:0] frame_matches;
  for (genvar k = 0; k < 8; k++) begin : g_pattern
    assign frame_matches[k] = (window_bits[k +: 8] == VALID_FRAME);
  end

  always_ff @(posedge clk_i or negedge rstvalid_n) begin
    if (!rstvalid_n) begin
      previous_word_q <= '0;
      training_q <= 1'b0;
      framing_q <= 1'b0;
      monitoring_q <= 1'b0;
      monitoring_qq <= 1'b0;
    end else begin
      previous_word_q <= current_word;
      training_q <= training;
      framing_q <= framing;
      monitoring_q <= monitoring;
      monitoring_qq <= monitoring_q;
    end
  end

  // Count patterns that END in the current capture. For offset 0 the whole
  // frame is in current_word. Offsets 1..7 use the previous capture too.
  // The eight candidates cannot overlap: 11110000 has no matching proper
  // prefix and suffix. A changed phase starts a new streak at one.
  wire [7:0] train_matches = {frame_matches[7:1] & {7{training_q}}, current_word == VALID_FRAME};
  logic [2:0] train_offset, train_offset_q;
  always_comb begin
    train_offset = '0;
    for (int k = 1; k < 8; k++)
      if (train_matches[k]) train_offset = 3'(k);
  end
  logic [COUNT_WIDTH-1:0] train_count_q;
  logic [CENTER_COUNT_WIDTH-1:0] center_count_q;
  // The registered tuple consumed on edge n starts in capture n-2. For a
  // nonzero offset its last UI comes from n-1. Both must belong to the trial.
  wire monitor_slot = monitoring_qq && (frame_offset_o == 3'd0 || monitoring_q);
  logic train_seen_q;
  wire [COUNT_WIDTH-1:0] last_count = vref_q ?
                                      COUNT_WIDTH'(VREF_WORDS-1) : COUNT_WIDTH'(REPAIR_MATCHES-1);
  wire [15:0] rotated_pattern = {VALID_FRAME, VALID_FRAME} << train_offset_q;
  assign train_pattern_o = train_seen_q ? rotated_pattern[15:8] : 8'd0;

  always_ff @(posedge clk_i or negedge rstvalid_n) begin
    if (!rstvalid_n) begin
      train_count_q <= '0;
      center_count_q <= '0;
      train_done_o <= 1'b0;
      train_offset_q <= '0;
      train_seen_q <= 1'b0;
    end else if (state_q == V_CLEAR) begin
      train_count_q <= '0;
      center_count_q <= '0;
      train_done_o <= 1'b0;
      train_offset_q <= '0;
      train_seen_q <= 1'b0;
    end else if (monitor_slot && !train_done_o) begin
      if (frame_valid_o) begin
        train_seen_q <= 1'b1;
        train_offset_q <= frame_offset_o;
        if (center_count_q == CENTER_COUNT_WIDTH'(CENTER_FRAMES-1))
          train_done_o <= 1'b1;
        else
          center_count_q <= center_count_q + 1'b1;
      end else begin
        center_count_q <= '0;
      end
    end else if (training && (!training_q || !train_done_o)) begin
      if (!training_q) begin
        train_done_o <= 1'b0;
        train_seen_q <= 1'b0;
      end
      if (|train_matches) begin
        train_seen_q <= 1'b1;
        train_offset_q <= train_offset;
        if (!training_q || train_offset != train_offset_q)
          train_count_q <= COUNT_WIDTH'(1);
        else if (train_count_q == last_count)
          train_done_o <= 1'b1;
        else
          train_count_q <= train_count_q + 1'b1;
      end else begin
        train_count_q <= '0;
      end
    end
  end

  // Framing decisions refer to the byte STARTING in the previous capture,
  // as required by the DATA window pipeline. Bit-zero acquisition needs a
  // known predecessor in the same session to establish a real rising edge.
  logic predecessor_q, predecessor_known_q;
  wire [7:0] predecessors = {previous_word_q[6:0], predecessor_q};
  wire [7:0] rising = previous_word_q & ~predecessors & {7'h7f, predecessor_known_q};
  wire [7:0] candidates = rising & frame_matches;
  logic [2:0] candidate_offset;
  always_comb begin
    candidate_offset = '0;
    for (int k = 1; k < 8; k++)
      if (candidates[k]) candidate_offset = 3'(k);
  end

  logic decoded_valid_q, decoded_error_q;
  logic [2:0] decoded_offset_q;
  wire [7:0] aligned_valid = 8'(window_bits >> decoded_offset_q);
  wire clear_framing = !framing || !framing_q;
  always_ff @(posedge clk_i or negedge rstvalid_n) begin
    if (!rstvalid_n) begin
      predecessor_q <= 1'b0;
      predecessor_known_q <= 1'b0;
      decoded_valid_q <= 1'b0;
      decoded_error_q <= 1'b0;
      decoded_offset_q <= '0;
      phase_locked_o <= 1'b0;
    end else if (clear_framing) begin
      predecessor_q <= 1'b0;
      predecessor_known_q <= 1'b0;
      decoded_valid_q <= 1'b0;
      decoded_error_q <= 1'b0;
      decoded_offset_q <= '0;
      phase_locked_o <= 1'b0;
    end else begin
      predecessor_q <= previous_word_q[7];
      predecessor_known_q <= 1'b1;
      decoded_valid_q <= 1'b0;
      decoded_error_q <= 1'b0;
      if (!phase_locked_o) begin
        if (|candidates) begin
          decoded_offset_q <= candidate_offset;
          phase_locked_o <= 1'b1;
          decoded_valid_q <= 1'b1;
        end else if (|rising) begin
          decoded_error_q <= 1'b1;
        end
      end else begin
        // Idle preserves the byte phase. A malformed frame reports an error
        // at that same phase until the controller starts a fresh session.
        case (aligned_valid)
          VALID_FRAME: decoded_valid_q <= 1'b1;
          8'h00: ;
          default: decoded_error_q <= 1'b1;
        endcase
      end
    end
  end

  assign {frame_valid_o, frame_offset_o, framing_error_o} =
         {decoded_valid_q, decoded_offset_q, decoded_error_q};

endmodule

`default_nettype wire
