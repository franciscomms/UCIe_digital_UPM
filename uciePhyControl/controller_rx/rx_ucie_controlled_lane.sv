`timescale 1ps/1ps
`default_nettype none

// Receive path for ONE physical DATA lane. Compile this file with the supplied
// ucie_lfsr23_32 and AsyncFifoCustomCore sources. This file provides the lane
// in place of the older definition bundled with rx_ucie_control_adapter.
// The old rx_ucie_data_lane source also defines a different ucie_lfsr23_32.
// Select a single definition of each module in the project file list.
//
// Connect one bit i of the separate rx_ucie_digital_controller as follows.
//   lane_req_o[i]        -> req             cmd_ack_o       -> lane_ack_i[i]
//   lane_req_rst_o[i]    -> req_rst         cmd_armed_o     -> lane_armed_i[i]
//   lane_req_laneid_o[i] -> req_laneid      cmd_pass_mask_o -> lane_pass_i[i]
//   lane_active_o[i]     -> active_i
// The controller holds requests and synchronizes the three returned levels.
// The supplied link controller issues MBINIT lane-ID commands to all 16
// positions even with a smaller activeDataLaneMask. For isolated testing,
// drive the scalar handshake here or instantiate rx_ltsm_group800 with LANES=1.
//
// Connect rx_ucie_valid_lane.{frame_valid_o, frame_offset_o, framing_error_o}
// directly to the corresponding inputs below. DATA and VALID must use the
// same clk_i, raw-bit ordering and deserializer latency. Connect frame_enable_o
// and valid_restart_o to bit i of rx_ltsm_valid_endpoint.lane_frame_enable_i
// and lane_restart_i. VALID training and the link controller stay external.
//
// Clock contract: clk_i is 2 GHz, clk_500_i is a phase-related divide-by-four.
// Assert publish_i on one fast edge per four, halfway between consecutive
// rising clk_500_i edges. Constrain the control and publication paths between
// these clocks. clk_800_i is the independent FIFO read clock. Reset asserts
// asynchronously and releases separately in each domain. Keep clocks stable
// before sending traffic after ARMED or ACTIVE_READY.
// Lane-ID comparison uses expected_lane_id_i directly; no reversal is present.
//
// Test-only raw payload mode: tie test_raw_i LOW for normal UCIe operation.
// Drive it as a held configuration level (not the custom_train_jtag trigger).
// It is synchronized to clk_500_i and selected while the payload path is idle.
// Set it at least SYNC_STAGES+1 clk_500_i edges before asserting active_i;
// keep wire VALID idle until active_ready_o. Changes during ACTIVE/retirement
// take effect only after that payload session has drained.
// Raw mode holds the LFSR's synchronous reset HIGH, keeping its output zero
// while framed DATA still follows the normal assembly and FIFO path. It does
// not load an all-zero seed and does not alter Lane-ID or LFSR training.
// Use the normal req_rst/ACK transaction before every payload session. After
// raw mode, this reloads lfsr_seed_i (the LFSR reset restores its own default
// seed); coordinate TX/RX reseeding before returning to scrambled traffic.
module rx_ucie_controlled_lane #(
  parameter bit RAW_Q0_AT_MSB = 1'b1,
  parameter int unsigned CONTROL_PIPE_STAGES = 1,
  parameter int unsigned FIFO_DEPTH = 32,
  parameter integer SYNC_STAGES = 3,
  parameter integer RESET_SYNC_STAGES = 3
) (
  input  wire        clk_i,
  input  wire        clk_500_i,
  input  wire        clk_800_i,
  input  wire        rst_ni,
  input  wire        publish_i,

  input  wire        req,
  input  wire        req_rst,
  input  wire        req_laneid,
  input  wire        active_i,
  input  wire        test_raw_i,           // Test configuration; normal operation = 0
  output wire        cmd_armed_o,
  output wire        active_ready_o,        // 500 MHz observation
  output wire        cmd_ack_o,
  output wire        cmd_pass_mask_o,

  input  wire [7:0]  data_word_i,           // One physical lane's raw capture
  input  wire [7:0]  expected_lane_id_i,    // Static physical lane ID
  input  wire [22:0] lfsr_seed_i,           // Selected logical TX lane's seed
  input  wire        frame_valid_i,
  input  wire [2:0]  frame_offset_i,
  input  wire        framing_error_i,
  output logic       frame_enable_o,        // Both outputs in the 2 GHz domain
  output logic       valid_restart_o,

  input  wire        fifo_rd_ready_i,       // 800 MHz ready/valid interface
  output wire        fifo_rd_valid_o,
  output wire [31:0] fifo_rd_data_o,
  output logic       fifo_overflow_o,       // Sticky until reset, 500 MHz
  output logic       stream_error_o,        // Framing fault pulse, 500 MHz
  output logic       lfsr_sync_lost_o       // Sticky until reset/reseed, 500 MHz
);
  // One local reset per clock domain, shared by all state in that domain.
  wire rst_fast_n, rst_500_n, rst_800_n;
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_fast
    (.clk_i(clk_i), .arst_ni(rst_ni), .rst_no(rst_fast_n));
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_500
    (.clk_i(clk_500_i), .arst_ni(rst_ni), .rst_no(rst_500_n));
  ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_800
    (.clk_i(clk_800_i), .arst_ni(rst_ni), .rst_no(rst_800_n));

  wire id_enable, lfsr_enable, payload_enable, seed_load;
  wire frame_enable_500, restart_500, id_done;
  logic compare_done, compare_pass;

  rx_ucie_controlled_lane_control #(
    .SYNC_STAGES(SYNC_STAGES), .CONTROL_PIPE_STAGES(CONTROL_PIPE_STAGES),
    .RESET_INPUT_IS_SYNC(1'b1)
  ) control (
    .clk_500_i(clk_500_i), .rst_ni(rst_500_n),
    .req(req), .req_rst(req_rst), .req_laneid(req_laneid),
    .active_i(active_i),
    .cmd_armed_o(cmd_armed_o), .active_ready_o(active_ready_o),
    .cmd_ack_o(cmd_ack_o), .cmd_pass_mask_o(cmd_pass_mask_o),
    .lane_train_done_i(id_done), .lane_train_pass_i(id_done),
    .lfsr_train_done_i(compare_done), .lfsr_train_pass_i(compare_pass),
    .lane_train_enable_o(id_enable),
    .lfsr_enable_o(lfsr_enable), .descramble_enable_o(payload_enable),
    .lfsr_seed_load_o(seed_load), .frame_enable_o(frame_enable_500),
    .valid_restart_o(restart_500)
  );

  logic id_enable_fast, stream_enable_fast;
  always_ff @(posedge clk_i or negedge rst_fast_n) begin
    if (!rst_fast_n) begin
      id_enable_fast <= 1'b0;
      stream_enable_fast <= 1'b0;
      frame_enable_o <= 1'b0;
      valid_restart_o <= 1'b0;
    end else if (publish_i) begin
      id_enable_fast <= id_enable;
      stream_enable_fast <= lfsr_enable;
      frame_enable_o <= frame_enable_500;
      valid_restart_o <= restart_500;
    end
  end

  wire [31:0] rx_word;
  wire rx_valid, rx_error;
  rx_ucie_controlled_lane_capture #(
    .RAW_Q0_AT_MSB(RAW_Q0_AT_MSB), .CONTROL_PIPE_STAGES(CONTROL_PIPE_STAGES)
  ) data_lane (
    .clk_i(clk_i), .clk_500_i(clk_500_i),
    .rst_ni(rst_fast_n), .rst_500_ni(rst_500_n), .publish_i(publish_i),
    .data_word_i(data_word_i), .frame_valid_i(frame_valid_i),
    .frame_offset_i(frame_offset_i), .framing_error_i(framing_error_i),
    .id_enable_i(id_enable_fast), .id_enable_500_i(id_enable),
    .stream_enable_i(stream_enable_fast),
    .expected_id_i(expected_lane_id_i), .published_word_o(rx_word),
    .published_valid_o(rx_valid), .published_error_o(rx_error), .id_done_o(id_done)
  );

  // Seed is provided externally, as in the original interface. Hold it stable
  // before reset release and throughout req_rst/ACK. No seed generator is used.
  // The pending load also captures reset pulses while clk_500_i is stopped.
  logic initial_seed_pending;
  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) initial_seed_pending <= 1'b1;
    else initial_seed_pending <= 1'b0;
  end
  wire load_seed = initial_seed_pending || seed_load;

  // The test setting may originate at 800 MHz or in a JTAG register. Latch
  // only between payload sessions, including the final registered word, so
  // a mode change cannot reinterpret an in-flight raw_q/PRBS pair.
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] test_raw_sync_q;
  logic test_raw_q;
  logic payload_q;
  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) begin
      test_raw_sync_q <= '0;
      test_raw_q <= 1'b0;
    end else begin
      test_raw_sync_q <= {test_raw_sync_q[SYNC_STAGES-2:0], test_raw_i};
      if (!payload_enable && !payload_q)
        test_raw_q <= test_raw_sync_q[SYNC_STAGES-1];
    end
  end
  wire test_lfsr_reset = test_raw_q && (payload_enable || payload_q);

  localparam int TRAIN_WORDS = 128;
  localparam int COUNT_W = $clog2(TRAIN_WORDS + 1);
  logic [COUNT_W-1:0] issued;
  wire train_enable = lfsr_enable && !payload_enable;
  wire train_open = train_enable && !compare_done && issued < COUNT_W'(TRAIN_WORDS);
  wire issue = rst_500_n && rx_valid && !load_seed && !lfsr_sync_lost_o && (payload_enable || train_open);
  wire last_issue = issue && train_open && issued == COUNT_W'(TRAIN_WORDS - 1);
  // A reported word and error in one publication mean the word came first.
  // A trailing error following the 128th training word lies outside that trial.
  wire stream_fault = rx_error && (payload_enable || (train_open && !last_issue));

  wire [31:0] prbs_word;
  ucie_lfsr23_32 #(.RESET_INPUT_IS_SYNC(1'b1)) lfsr (
    .clk_i(clk_500_i), .rst_ni(rst_500_n), .enable_i(issue),
    .seed_load_i(load_seed), .lfsr_reset_i(test_lfsr_reset), .seed_i(lfsr_seed_i),
    .data_o(prbs_word)
  );

  // data_o is registered in the supplied generator. Capture its corresponding
  // raw word and operation on the same enabled edge. Bubbles consume no PRBS.
  logic [31:0] raw_q;
  logic train_q, last_q, mismatch_seen;
  wire [31:0] decoded_word = raw_q ^ prbs_word;
  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) begin
      raw_q <= '0;
      train_q <= 1'b0;
      last_q <= 1'b0;
      payload_q <= 1'b0;
    end else if (load_seed) begin
      train_q <= 1'b0;
      last_q <= 1'b0;
      payload_q <= 1'b0;
    end else begin
      train_q <= issue && train_open;
      last_q <= last_issue;
      payload_q <= issue && payload_enable;
      if (issue) raw_q <= rx_word;
    end
  end

  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) begin
      stream_error_o <= 1'b0;
      lfsr_sync_lost_o <= 1'b0;
    end else if (load_seed) begin
      stream_error_o <= 1'b0;
      lfsr_sync_lost_o <= 1'b0;
    end else begin
      stream_error_o <= stream_fault;
      if (stream_fault) lfsr_sync_lost_o <= 1'b1;
    end
  end

  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) begin
      issued <= '0;
      compare_done <= 1'b0;
      compare_pass <= 1'b0;
      mismatch_seen <= 1'b0;
    end else if (load_seed || !train_enable) begin
      issued <= '0;
      compare_done <= 1'b0;
      compare_pass <= 1'b0;
      mismatch_seen <= 1'b0;
    end else if (!compare_done) begin
      if (issue) issued <= issued + 1'b1;
      if (stream_fault || lfsr_sync_lost_o) begin
        compare_done <= 1'b1;
        compare_pass <= 1'b0;
      end else if (train_q) begin
        mismatch_seen <= mismatch_seen || (|decoded_word);
        if (last_q) begin
          compare_done <= 1'b1;
          compare_pass <= !mismatch_seen && !(|decoded_word);
        end
      end
    end
  end

  // Serial capture cannot stall. Record each dropped word when the FIFO is
  // full and keep the LFSR in step with the incoming wire stream.
  logic [31:0] fifo_data_q;
  logic fifo_valid_q;
  wire fifo_ready;
  always_ff @(posedge clk_500_i or negedge rst_500_n) begin
    if (!rst_500_n) begin
      fifo_valid_q <= 1'b0;
      fifo_data_q <= '0;
      fifo_overflow_o <= 1'b0;
    end else begin
      fifo_valid_q <= payload_q;
      if (payload_q) fifo_data_q <= decoded_word;
      if (fifo_valid_q && !fifo_ready) fifo_overflow_o <= 1'b1;
    end
  end
  AsyncFifoCustomCore_local #(.DEPTH(FIFO_DEPTH), .WIDTH(32)) fifo (
    .rst_w_n(rst_500_n), .rst_r_n(rst_800_n),
    .clk_w(clk_500_i), .valid_w(fifo_valid_q), .ready_w(fifo_ready), .data_w(fifo_data_q),
    .clk_r(clk_800_i), .valid_r(fifo_rd_valid_o), .ready_r(fifo_rd_ready_i),
    .data_r(fifo_rd_data_o)
  );

  // synthesis translate_off
  initial begin
    if (FIFO_DEPTH < 4 || (FIFO_DEPTH & (FIFO_DEPTH - 1)) != 0)
      $fatal(1, "FIFO_DEPTH must be a power of two and at least four");
  end
  // synthesis translate_on
endmodule

// Fast side of one DATA lane, beside the shared rx_ucie_valid_lane decoder.
// At edge n both lanes sample the current raw byte. The VALID decision just
// after n refers to the window {raw[n], raw[n-1]}. Keep that DATA window
// beside the five decision bits through every optional entry-pipeline stage.
// The 500 MHz receiver samples the publish registers two fast periods after
// publish_i. Time this related-clock path in both directions.
module rx_ucie_controlled_lane_capture #(
  parameter bit RAW_Q0_AT_MSB = 1'b1,
  parameter int unsigned CONTROL_PIPE_STAGES = 1
) (
  input  wire        clk_i,
  input  wire        clk_500_i,
  input  wire        rst_ni,              // Already synchronized to clk_i.
  input  wire        rst_500_ni,          // Already synchronized to clk_500_i.
  input  wire        publish_i,           // Exactly one edge in four.
  input  wire [7:0]  data_word_i,
  input  wire        frame_valid_i,
  input  wire [2:0]  frame_offset_i,
  input  wire        framing_error_i,
  input  wire        id_enable_i,
  input  wire        id_enable_500_i,
  input  wire        stream_enable_i,
  input  wire [7:0]  expected_id_i,   // Stable in the 500 MHz domain for the trial.
  output logic [31:0] published_word_o,
  output logic        published_valid_o,
  output logic        published_error_o,
  output logic        id_done_o
);
  function automatic logic [7:0] chronological(input logic [7:0] raw);
    if (RAW_Q0_AT_MSB)
      chronological = {raw[0], raw[4], raw[2], raw[6], raw[1], raw[5], raw[3], raw[7]};
    else
      chronological = {raw[7], raw[3], raw[5], raw[1], raw[6], raw[2], raw[4], raw[0]};
  endfunction

  wire [7:0] current_byte = chronological(data_word_i);
  logic [7:0] previous_byte_q;
  logic [15:0] window_q;
  logic id_prev_q, stream_prev_q, id_window_q, stream_window_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      previous_byte_q <= '0;
      window_q <= '0;
      id_prev_q <= 1'b0;
      stream_prev_q <= 1'b0;
      id_window_q <= 1'b0;
      stream_window_q <= 1'b0;
    end else begin
      previous_byte_q <= current_byte;
      window_q <= {current_byte, previous_byte_q};
      id_prev_q <= id_enable_i;
      stream_prev_q <= stream_enable_i;
      // Reject windows straddling the start of this lane's new operation,
      // including when a peer keeps the shared VALID decoder enabled.
      id_window_q <= id_enable_i && id_prev_q;
      stream_window_q <= stream_enable_i && stream_prev_q;
    end
  end

  typedef struct packed {
    logic [15:0] window_bits;
    logic [2:0] offset;
    logic valid;
    logic error;
    logic id_window;
    logic stream_window;
  } frame_t;
  wire frame_t stage [0:CONTROL_PIPE_STAGES];
  assign stage[0] = {window_q, frame_offset_i, frame_valid_i, framing_error_i,
                     id_window_q, stream_window_q};

  for (genvar i = 0; i < CONTROL_PIPE_STAGES; i++) begin : g_entry
    wire frame_t entry = stage[i];
    frame_t q;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) q <= '0;
      else q <= {entry.window_bits, entry.offset, entry.valid, entry.error,
                 entry.id_window && id_enable_i, entry.stream_window && stream_enable_i};
    end
    assign stage[i+1] = q;
  end

  wire frame_t decision = stage[CONTROL_PIPE_STAGES];
  logic [7:0] byte_q;
  logic id_byte_valid_q, stream_byte_valid_q, stream_byte_error_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      byte_q <= '0;
      id_byte_valid_q <= 1'b0;
      stream_byte_valid_q <= 1'b0;
      stream_byte_error_q <= 1'b0;
    end else begin
      byte_q <= 8'(decision.window_bits >> decision.offset);
      id_byte_valid_q <= id_enable_i && decision.id_window && decision.valid && !decision.error;
      stream_byte_valid_q <= stream_enable_i && decision.stream_window && decision.valid && !decision.error;
      stream_byte_error_q <= stream_enable_i && decision.stream_window && decision.error;
    end
  end

  // Pack four adjacent byte times for 500 MHz ID comparison. Keep an
  // individual valid bit for each slot, including gaps and framing errors.
  // Byte 0 (bits 7:0) is oldest. Slot 3 includes the current publish edge.
  logic [23:0] id_bytes_q;
  logic [2:0] id_valid_q;
  logic [31:0] published_id_bytes_q;
  logic [3:0] published_id_valid_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_bytes_q <= '0;
      id_valid_q <= '0;
      published_id_bytes_q <= '0;
      published_id_valid_q <= '0;
    end else begin
      id_bytes_q <= {byte_q, id_bytes_q[23:8]};
      id_valid_q <= id_enable_i ? {id_byte_valid_q, id_valid_q[2:1]} : '0;
      if (publish_i) begin
        published_id_bytes_q <= {byte_q, id_bytes_q};
        published_id_valid_q <= id_enable_i ? {id_byte_valid_q, id_valid_q} : '0;
      end
    end
  end

  // A pattern can start on either byte parity. For each parity test two
  // disjoint pairs per block. The first pair on one parity crosses blocks.
  logic [7:0] previous_last_byte_q;
  logic previous_last_valid_q;
  wire [15:0] id_pattern = {4'hA, expected_id_i, 4'hA};
  wire [3:0] id_pair_match;
  assign id_pair_match[0] = published_id_valid_q[0] && previous_last_valid_q &&
                            ({published_id_bytes_q[7:0], previous_last_byte_q} == id_pattern);
  for (genvar slot = 1; slot < 4; slot++) begin : g_id_pair
    assign id_pair_match[slot] = (&published_id_valid_q[slot-1 +: 2]) &&
                                 (published_id_bytes_q[8*(slot-1) +: 16] == id_pattern);
  end

  // A counter needs four bits because id_done_o latches the sixteenth hit.
  // Check the first pair separately: a later mismatch cannot undo success.
  logic [1:0] reached_sixteen;
  for (genvar parity = 0; parity < 2; parity++) begin : g_id_streak
    logic [3:0] count_q;
    wire first_pair_match = id_pair_match[parity];
    wire second_match = id_pair_match[parity+2];
    assign reached_sixteen[parity] = first_pair_match &&
                    ((count_q == 4'd15) || (second_match && count_q == 4'd14));
    always_ff @(posedge clk_500_i or negedge rst_500_ni) begin
      if (!rst_500_ni) count_q <= '0;
      else if (!id_enable_500_i) count_q <= '0;
      else if (!id_done_o) begin
        if (!second_match) count_q <= '0;
        else if (!first_pair_match) count_q <= 4'd1;
        else count_q <= count_q + 4'd2;
      end
    end
  end

  always_ff @(posedge clk_500_i or negedge rst_500_ni) begin
    if (!rst_500_ni) begin
      previous_last_byte_q <= '0;
      previous_last_valid_q <= 1'b0;
      id_done_o <= 1'b0;
    end else if (!id_enable_500_i) begin
      previous_last_byte_q <= '0;
      previous_last_valid_q <= 1'b0;
      id_done_o <= 1'b0;
    end else begin
      previous_last_byte_q <= published_id_bytes_q[31:24];
      previous_last_valid_q <= published_id_valid_q[3];
      if (|reached_sixteen) id_done_o <= 1'b1;
    end
  end

  // A VALID idle inserts no byte. After a framing error the LFSR phase is
  // unknown, so discard this word and further stream bytes until disarmed.
  logic [23:0] assembly_q;
  logic [1:0] byte_index_q;
  logic stream_faulted_q;
  wire stream_fault = stream_enable_i && !stream_faulted_q && stream_byte_error_q;
  wire stream_byte = stream_enable_i && !stream_faulted_q && stream_byte_valid_q;
  wire word_complete = stream_byte && (byte_index_q == 2'd3);
  wire [31:0] complete_word = {byte_q, assembly_q};
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      byte_index_q <= '0;
      assembly_q <= '0;
      stream_faulted_q <= 1'b0;
    end else if (!stream_enable_i) begin
      byte_index_q <= '0;
      assembly_q <= '0;
      stream_faulted_q <= 1'b0;
    end else if (stream_fault) begin
      byte_index_q <= '0;
      stream_faulted_q <= 1'b1;
    end else if (stream_byte) begin
      case (byte_index_q)
        2'd0: assembly_q[7:0] <= byte_q;
        2'd1: assembly_q[15:8] <= byte_q;
        2'd2: assembly_q[23:16] <= byte_q;
        default: ;
      endcase
      byte_index_q <= byte_index_q + 1'b1;
    end
  end

  // At most one completed word per four fast edges. Include an event on
  // the publish edge itself. If both flags are set the word preceded the fault.
  logic [31:0] pending_word_q;
  logic pending_valid_q, pending_error_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pending_word_q <= '0;
      pending_valid_q <= 1'b0;
      pending_error_q <= 1'b0;
      published_word_o <= '0;
      published_valid_o <= 1'b0;
      published_error_o <= 1'b0;
    end else begin
      if (publish_i) begin
        published_valid_o <= stream_enable_i && (pending_valid_q || word_complete);
        published_error_o <= stream_enable_i && (pending_error_q || stream_fault);
        if (word_complete) published_word_o <= complete_word;
        else if (pending_valid_q) published_word_o <= pending_word_q;
      end
      if (publish_i || !stream_enable_i) begin
        pending_valid_q <= 1'b0;
        pending_error_q <= 1'b0;
      end else begin
        if (word_complete) begin
          pending_word_q <= complete_word;
          pending_valid_q <= 1'b1;
        end
        if (stream_fault) pending_error_q <= 1'b1;
      end
    end
  end
endmodule

// Per-lane 500 MHz endpoint for the held commands from rx_ltsm_group800.
// Drive the controller's selected ACK/ARMED/PASS input bits directly from
// these registered outputs. rx_ltsm_group800 synchronizes them at 800 MHz.
module rx_ucie_controlled_lane_control #(
  parameter integer SYNC_STAGES = 3,
  parameter integer CONTROL_PIPE_STAGES = 1,
  parameter integer RESET_SYNC_STAGES = 3,
  parameter bit RESET_INPUT_IS_SYNC = 1'b0
) (
  input  wire  clk_500_i,
  input  wire  rst_ni,
  input  wire  req,
  input  wire  req_rst,
  input  wire  req_laneid,
  input  wire  active_i,
  output logic cmd_armed_o,
  output logic cmd_ack_o,
  output logic cmd_pass_mask_o,
  output logic active_ready_o,

  input  wire  lane_train_done_i,
  input  wire  lane_train_pass_i,
  input  wire  lfsr_train_done_i,
  input  wire  lfsr_train_pass_i,
  output wire  lane_train_enable_o,
  output wire  lfsr_enable_o,
  output wire  descramble_enable_o,
  output logic lfsr_seed_load_o,
  output wire  frame_enable_o,
  output logic valid_restart_o
);
  // Four fast captures per 500 MHz edge. Account for VALID delivery,
  // alignment history, block publication, and the processing pipeline.
  localparam integer FLUSH_EDGES = 5 + (CONTROL_PIPE_STAGES + 3) / 4;
  localparam integer GUARD_W = $clog2(FLUSH_EDGES + 1);

  wire rst500_n;
  if (RESET_INPUT_IS_SYNC) begin : g_local_reset
    assign rst500_n = rst_ni;
  end else begin : g_reset_sync
    ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_sync
      (.clk_i(clk_500_i), .arst_ni(rst_ni), .rst_no(rst500_n));
  end

  // One held level for each command and ACTIVE. Commands remain held until
  // their handshake completes, as in the original endpoint.
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] train_sync_q, seed_sync_q, id_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] active_sync_q;
  always_ff @(posedge clk_500_i or negedge rst500_n) begin
    if (!rst500_n) begin
      train_sync_q <= '0;
      seed_sync_q <= '0;
      id_sync_q <= '0;
      active_sync_q <= '0;
    end else begin
      train_sync_q <= {train_sync_q[SYNC_STAGES-2:0], req};
      seed_sync_q <= {seed_sync_q[SYNC_STAGES-2:0], req_rst};
      id_sync_q <= {id_sync_q[SYNC_STAGES-2:0], req_laneid};
      active_sync_q <= {active_sync_q[SYNC_STAGES-2:0], active_i};
    end
  end

  wire train500 = train_sync_q[SYNC_STAGES-1];
  wire seed500 = seed_sync_q[SYNC_STAGES-1];
  wire id500 = id_sync_q[SYNC_STAGES-1];
  wire active500 = active_sync_q[SYNC_STAGES-1];
  wire req500 = train500 || seed500 || id500;
  wire conflict500 = (train500 && seed500) || (train500 && id500) || (seed500 && id500);

  typedef enum logic [3:0] {
    P_IDLE, P_DECODE, P_SEED, P_FLUSH, P_ARM, P_COMPARE,
    P_REPORT, P_WAIT_LOW, P_ACTIVE_ARM, P_ACTIVE, P_RETIRE
  } phy_state_t;
  phy_state_t phy_q;

  logic compare_run_q, payload_run_q, id500_q, seen_low_q, seeded_q;
  logic [GUARD_W-1:0] guard_q;
  wire done = id500_q ? lane_train_done_i : lfsr_train_done_i;
  wire pass = id500_q ? lane_train_pass_i : lfsr_train_pass_i;

  assign lane_train_enable_o = compare_run_q && id500_q;
  assign descramble_enable_o = payload_run_q;
  assign lfsr_enable_o = (compare_run_q && !id500_q) || payload_run_q;
  assign frame_enable_o = compare_run_q || payload_run_q;

  always_ff @(posedge clk_500_i or negedge rst500_n) begin
    if (!rst500_n) begin
      phy_q <= P_IDLE;
      cmd_ack_o <= 1'b0;
      cmd_armed_o <= 1'b0;
      cmd_pass_mask_o <= 1'b0;
      active_ready_o <= 1'b0;
      compare_run_q <= 1'b0;
      payload_run_q <= 1'b0;
      id500_q <= 1'b0;
      guard_q <= '0;
      seen_low_q <= 1'b0;
      seeded_q <= 1'b0;
      lfsr_seed_load_o <= 1'b0;
      valid_restart_o <= 1'b0;
    end else begin
      lfsr_seed_load_o <= 1'b0;
      valid_restart_o <= 1'b0;

      case (phy_q)
        P_IDLE: begin
          if (req500) begin
            seen_low_q <= 1'b0;
            cmd_pass_mask_o <= 1'b0;
            phy_q <= P_DECODE;
          end else if (active500 && seeded_q) begin
            seeded_q <= 1'b0;
            payload_run_q <= 1'b1;
            valid_restart_o <= 1'b1;
            guard_q <= GUARD_W'(FLUSH_EDGES);
            phy_q <= P_ACTIVE_ARM;
          end
        end

        P_DECODE: begin
          // Preserve the original command-decode stage and handshake latency.
          id500_q <= id500;
          if (conflict500 || !req500) begin
            phy_q <= P_REPORT;
          end else begin
            valid_restart_o <= 1'b1;
            if (seed500) begin
              lfsr_seed_load_o <= 1'b1;
              phy_q <= P_SEED;
            end else begin
              guard_q <= GUARD_W'(FLUSH_EDGES);
              phy_q <= P_FLUSH;
            end
          end
        end

        P_SEED: begin
          seeded_q <= 1'b1;
          cmd_pass_mask_o <= 1'b1;
          phy_q <= P_REPORT;
        end

        P_FLUSH: begin
          if (guard_q != GUARD_W'(1)) guard_q <= guard_q - 1'b1;
          else begin
            compare_run_q <= 1'b1;
            if (!id500_q) seeded_q <= 1'b0;
            guard_q <= GUARD_W'(2);
            phy_q <= P_ARM;
          end
        end

        P_ARM: begin
          // A sticky DONE from a preceding trial cannot complete a new one.
          seen_low_q <= seen_low_q || !done;
          if (guard_q != GUARD_W'(1)) guard_q <= guard_q - 1'b1;
          else begin
            cmd_armed_o <= 1'b1;
            phy_q <= P_COMPARE;
          end
        end

        P_COMPARE: begin
          seen_low_q <= seen_low_q || !done;
          if (!req500) begin
            // The controller may close an armed observation without an ACK.
            compare_run_q <= 1'b0;
            cmd_armed_o <= 1'b0;
            cmd_pass_mask_o <= 1'b0;
            phy_q <= P_IDLE;
          end else if (done && seen_low_q) begin
            cmd_pass_mask_o <= pass;
            compare_run_q <= 1'b0;
            phy_q <= P_REPORT;
          end
        end

        P_REPORT: begin
          // PASS is stable at least one local clock before ACK rises.
          cmd_ack_o <= 1'b1;
          phy_q <= P_WAIT_LOW;
        end

        P_WAIT_LOW: if (!req500) begin
          cmd_ack_o <= 1'b0;
          cmd_armed_o <= 1'b0;
          phy_q <= P_IDLE;
        end

        P_ACTIVE_ARM, P_ACTIVE: begin
          if (!active500 || req500) begin
            // With VALID idle, retire any final payload word before a new command.
            guard_q <= GUARD_W'(FLUSH_EDGES);
            phy_q <= P_RETIRE;
          end else if (phy_q == P_ACTIVE_ARM) begin
            if (guard_q != GUARD_W'(1)) guard_q <= guard_q - 1'b1;
            else begin
              active_ready_o <= 1'b1;
              phy_q <= P_ACTIVE;
            end
          end
        end

        P_RETIRE: begin
          if (guard_q != GUARD_W'(1)) guard_q <= guard_q - 1'b1;
          else begin
            payload_run_q <= 1'b0;
            active_ready_o <= 1'b0;
            phy_q <= P_IDLE;
          end
        end

        default: begin
          compare_run_q <= 1'b0;
          payload_run_q <= 1'b0;
          active_ready_o <= 1'b0;
          seeded_q <= 1'b0;
          cmd_pass_mask_o <= 1'b0;
          phy_q <= P_REPORT;
        end
      endcase
    end
  end

  // synthesis translate_off
  initial begin
    if (SYNC_STAGES < 2)
      $fatal(1, "SYNC_STAGES must be at least 2");
    if (CONTROL_PIPE_STAGES < 0)
      $fatal(1, "CONTROL_PIPE_STAGES must be nonnegative");
  end
  // synthesis translate_on
endmodule

`default_nettype wire
