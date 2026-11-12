`default_nettype none
// ============================================================================
// PhyPatternClock2g -- forwarded-clock control endpoint (2 GHz domain)
// ============================================================================
// Decides when the analog clock transmitter sends the forwarded clock. The
// clock pattern itself is generated in the analog block; this module only
// drives one registered, glitch-free level bit:
//   phyDigControl = 1 -> the analog front end transmits the forwarded clock.
//   phyDigControl = 0 -> the analog front end sends zeros (no clock).
//
// Command inputs (levels from the 800 MHz controller, asynchronous here):
//   cmd_req_active    : send the clock continuously (normal operation).
//   cmd_req_clk_train : send the clock-training pattern (ITERATIONS
//                       iterations, default 130), then stop.
// Both are synchronized locally with SYNC_STAGES flops before use.
//
// Behaviour, in priority order:
//   1. cmd_req_active = 1:
//      phyDigControl goes to 1 and stays there without any break. The
//      cycle after phyDigControl is 1, cmd_ack_o goes to 1. Both stay high
//      until cmd_req_active returns to 0. Active pre-empts a training in
//      progress (the training is abandoned; a later request restarts it).
//   2. cmd_req_clk_train = 1 (and active = 0):
//      phyDigControl is held at 1 for ITERATIONS*CYCLES_PER_ITERATION
//      clock_tx2g cycles, then drops to 0 and cmd_ack_o goes to 1. cmd_ack_o
//      stays high until cmd_req_clk_train returns to 0 (four-phase
//      handshake). If cmd_req_clk_train drops before the training finishes,
//      the training is aborted: phyDigControl drops, no ack is given.
//   3. Both requests 0:
//      phyDigControl = 0 (zeros are sent) and cmd_ack_o = 0.
//
// cmd_ack_o is a registered level returned asynchronously to the 800 MHz
// controller, which must synchronize it. Because both requests share the one
// ack, the controller must not use the ack to detect training completion
// while it is also requesting active mode.
//
// Common asynchronous reset assertion is required with the command source;
// reset release is synchronized locally (reset_clock2g_n).
// ============================================================================
module PhyPatternClock2g #(
  parameter integer SYNC_STAGES = 3,           // flops per CDC synchronizer (>= 2)
  parameter integer ITERATIONS = 130,          // clock-pattern iterations per training
  parameter integer CYCLES_PER_ITERATION = 1   // clock_tx2g cycles per iteration
) (
  // ---- Local 2 GHz domain -------------------------------------------------
  input  wire  clock_tx2g,          // local control clock
  input  wire  reset_n,             // async reset (assert anywhere, release synced)
  output wire  reset_clock2g_n,     // locally synchronized reset (for neighbours)

  // ---- Commands from the 800 MHz controller (asynchronous levels) ---------
  input  wire  cmd_req_clk_train,   // 1 = send the 130-iteration training pattern
  input  wire  cmd_req_active,      // 1 = send the clock continuously (priority)
  output logic cmd_ack_o,           // acknowledgment, held until the request drops

  // ---- Analog front end ---------------------------------------------------
  output logic phyDigControl        // 1 = send forwarded clock, 0 = send zeros
);
  // Number of cycles phyDigControl is high for one training, and the counter
  // width needed to hold that value.
  localparam integer TOTAL_CYCLES = ITERATIONS * CYCLES_PER_ITERATION;
  localparam integer CW = $clog2(TOTAL_CYCLES + 1);

  // IDLE       : no request, sending zeros.
  // ACTIVE     : continuous clock (cmd_req_active).
  // TRAIN      : training pattern, counting down remaining_q.
  // TRAIN_DONE : training finished, ack held until cmd_req_clk_train drops.
  typedef enum logic [1:0] {IDLE, ACTIVE, TRAIN, TRAIN_DONE} state_t;
  state_t state_q;
  logic [CW-1:0] remaining_q;  // training cycles left with the clock enabled
  wire train_sync;             // cmd_req_clk_train after the synchronizer
  wire active_sync;            // cmd_req_active after the synchronizer

  // Synchronize the reset release and both request levels into clock_tx2g.
  PhyClock2gCtrlResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(reset_clock2g_n)
  );
  PhyClock2gCtrlSyncBit #(.STAGES(SYNC_STAGES)) u_train_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_clock2g_n),
    .async_i(cmd_req_clk_train), .sync_o(train_sync)
  );
  PhyClock2gCtrlSyncBit #(.STAGES(SYNC_STAGES)) u_active_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_clock2g_n),
    .async_i(cmd_req_active), .sync_o(active_sync)
  );

  // Control FSM. Priority: active > clock training > idle. phyDigControl and
  // cmd_ack_o are flops, so the analog and the controller see clean levels.
  always_ff @(posedge clock_tx2g or negedge reset_clock2g_n) begin
    if (!reset_clock2g_n) begin
      state_q <= IDLE;
      remaining_q <= '0;
      phyDigControl <= 1'b0;
      cmd_ack_o <= 1'b0;
    end else if (active_sync) begin
      // 1) Active: clock on continuously. Ack follows one cycle after
      //    phyDigControl is already 1. Any training in progress is dropped.
      state_q <= ACTIVE;
      remaining_q <= '0;
      phyDigControl <= 1'b1;
      cmd_ack_o <= phyDigControl;
    end else if (train_sync) begin
      // 2) Clock training.
      case (state_q)
        TRAIN: begin
          if (remaining_q == CW'(1)) begin
            // Last training cycle: stop the clock and acknowledge.
            phyDigControl <= 1'b0;
            remaining_q <= '0;
            cmd_ack_o <= 1'b1;
            state_q <= TRAIN_DONE;
          end else begin
            // Still sending: count one more cycle.
            remaining_q <= remaining_q - CW'(1);
          end
        end
        TRAIN_DONE: begin
          // Training finished: zeros on the lane, ack held until the
          // request is removed.
          phyDigControl <= 1'b0;
          cmd_ack_o <= 1'b1;
        end
        default: begin
          // IDLE or ACTIVE (active just dropped): start a new training with
          // the full count. Clock is on from the next cycle.
          remaining_q <= CW'(TOTAL_CYCLES);
          phyDigControl <= 1'b1;
          cmd_ack_o <= 1'b0;
          state_q <= TRAIN;
        end
      endcase
    end else begin
      // 3) No request: send zeros, no ack. Also aborts an unfinished
      //    training if cmd_req_clk_train dropped early.
      state_q <= IDLE;
      remaining_q <= '0;
      phyDigControl <= 1'b0;
      cmd_ack_o <= 1'b0;
    end
  end

  // Simulation-only checks: parameter sanity and output/state consistency.
`ifndef SYNTHESIS
  initial begin
    assert (SYNC_STAGES >= 2)
      else $fatal(1, "Clock command CDC needs at least two synchronizer stages");
    assert (ITERATIONS >= 1 && CYCLES_PER_ITERATION >= 1)
      else $fatal(1, "Clock pattern needs at least one iteration of one cycle");
  end
  always_ff @(posedge clock_tx2g) begin
    if (reset_clock2g_n) begin
      // The clock is on only in ACTIVE or TRAIN.
      assert (phyDigControl == (state_q == ACTIVE || state_q == TRAIN))
        else $error("phyDigControl must be high exactly in ACTIVE or TRAIN");
      // A training is never acknowledged while it is still sending.
      if (state_q == TRAIN)
        assert (!cmd_ack_o)
          else $error("Clock training acknowledged while clock still enabled");
    end
  end
`endif
endmodule

// Reset synchronizer: asserts asynchronously with arst_ni, releases
// synchronously to clk_i after STAGES clock edges.
module PhyClock2gCtrlResetSync #(
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
  initial assert (STAGES >= 2)
    else $fatal(1, "Clock reset synchronizer needs at least two stages");
`endif
endmodule

// Single-bit level synchronizer (STAGES-flop chain) for the asynchronous
// request inputs. Only use for level signals held for several cycles.
module PhyClock2gCtrlSyncBit #(
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
  initial assert (STAGES >= 2)
    else $fatal(1, "Clock command synchronizer needs at least two stages");
`endif
endmodule

`default_nettype wire
