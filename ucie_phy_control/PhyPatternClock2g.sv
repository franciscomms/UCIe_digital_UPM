`default_nettype none

// Dedicated CLOCK-lane pattern endpoint; one local 2 GHz clock domain.
//
// Analog interface: a single level control bit, phyDigControl.
//   phyDigControl = 1 -> the analog front end transmits the forwarded clock.
//   phyDigControl = 0 -> the analog front end does not transmit the clock.
// The pattern itself is generated in the analog block; this endpoint only
// decides how long the clock is sent. phyDigControl is a registered,
// glitch-free output.
//
// Duration: each command holds phyDigControl high for ITERATIONS valid-pattern
// iterations (default 130). One iteration lasts CYCLES_PER_ITERATION
// clock_tx2g cycles (default 1, i.e. one 8-UI pattern per local cycle). The
// bit is therefore high for exactly ITERATIONS*CYCLES_PER_ITERATION cycles.
//
// Source command protocol (unchanged): assert cmd_req_async_i and hold it
// until cmd_ack_o has been synchronized back to the source. Then lower request.
// If cancelling, hold cmd_cancel_async_i until acknowledgment, then lower it.
// Cancellation drops phyDigControl on the next local edge. The endpoint holds
// cmd_ack_o until BOTH request and cancel synchronize low. cmd_aborted_o is
// stable while acknowledgment is high. There is no command payload.
//
// Common asynchronous reset assertion is required with the command source;
// reset release is synchronized locally below.
module PhyPatternClock2g #(
  parameter integer SYNC_STAGES = 3,           // flops per CDC synchronizer (>= 2)
  parameter integer ITERATIONS = 130,          // valid-pattern iterations per command
  parameter integer CYCLES_PER_ITERATION = 1   // clock_tx2g cycles per iteration
) (
  // ---- Local 2 GHz domain -------------------------------------------------
  input  wire  clock_tx2g,          // local control clock
  input  wire  reset_n,             // async reset (assert anywhere, release synced)

  // ---- Command link from the 800 MHz controller (asynchronous) ------------
  input  wire  cmd_req_async_i,     // request: held high until cmd_ack_o seen
  input  wire  cmd_cancel_async_i,  // cancel: held high until cmd_ack_o seen
  output logic cmd_ack_o,           // completion: held until req/cancel low
  output logic cmd_aborted_o,       // 1 = command was cancelled; stable with ack
  output wire  reset_clock2g_n,     // locally synchronized reset (for neighbours)

  // ---- Analog front end ---------------------------------------------------
  output logic phyDigControl        // 1 = send forwarded clock, 0 = no clock
);
  // Number of local cycles phyDigControl stays high for one full command,
  // and the counter width needed to hold that value.
  localparam integer TOTAL_CYCLES = ITERATIONS * CYCLES_PER_ITERATION;
  localparam integer CW = $clog2(TOTAL_CYCLES + 1);

  // IDLE         : waiting for a synchronized request.
  // RUN          : phyDigControl high, counting down remaining_q.
  // WAIT_REQ_LOW : ack high, waiting for the source to drop request/cancel.
  typedef enum logic [1:0] {IDLE, RUN, WAIT_REQ_LOW} state_t;
  state_t state_q;
  logic [CW-1:0] remaining_q;  // cycles left with the clock enabled
  wire req_sync;               // cmd_req_async_i after the synchronizer
  wire cancel_sync;            // cmd_cancel_async_i after the synchronizer

  // Reset release and command inputs are synchronized into clock_tx2g
  // before any logic uses them.
  PhyClock2gCtrlResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(reset_clock2g_n)
  );
  PhyClock2gCtrlSyncBit #(.STAGES(SYNC_STAGES)) u_req_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_clock2g_n),
    .async_i(cmd_req_async_i), .sync_o(req_sync)
  );
  PhyClock2gCtrlSyncBit #(.STAGES(SYNC_STAGES)) u_cancel_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_clock2g_n),
    .async_i(cmd_cancel_async_i), .sync_o(cancel_sync)
  );

  // Main control FSM. phyDigControl is a flop so the analog sees a clean,
  // glitch-free level.
  always_ff @(posedge clock_tx2g or negedge reset_clock2g_n) begin
    if (!reset_clock2g_n) begin
      state_q <= IDLE;
      remaining_q <= '0;
      phyDigControl <= 1'b0;
      cmd_ack_o <= 1'b0;
      cmd_aborted_o <= 1'b0;
    end else begin
      case (state_q)
        // New command: clear the previous result, then either start the
        // clock or, if already cancelled, complete immediately.
        IDLE: if (req_sync) begin
          cmd_aborted_o <= 1'b0;
          if (cancel_sync) begin
            // Cancelled before start: nothing is sent.
            cmd_aborted_o <= 1'b1;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else begin
            // Load the full count and enable the clock from the next cycle.
            remaining_q <= CW'(TOTAL_CYCLES);
            phyDigControl <= 1'b1;
            state_q <= RUN;
          end
        end

        // Clock enabled. Each cycle here is one counted cycle; the bit is
        // high for exactly TOTAL_CYCLES cycles unless cancelled.
        RUN: begin
          if (cancel_sync) begin
            // Cancel: stop the clock now and report an aborted command.
            phyDigControl <= 1'b0;
            remaining_q <= '0;
            cmd_aborted_o <= 1'b1;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else if (remaining_q == CW'(1)) begin
            // Last counted cycle: stop the clock and report normal completion.
            phyDigControl <= 1'b0;
            remaining_q <= '0;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else begin
            remaining_q <= remaining_q - CW'(1);
          end
        end

        // Four-phase return-to-zero: keep ack (and aborted) stable until the
        // source has dropped both request and cancel, so neither can leak
        // into the next command.
        WAIT_REQ_LOW: if (!req_sync && !cancel_sync) begin
          cmd_ack_o <= 1'b0;
          state_q <= IDLE;
        end

        // Illegal state encoding: recover safely with the clock off.
        default: begin
          state_q <= IDLE;
          phyDigControl <= 1'b0;
          cmd_ack_o <= 1'b0;
        end
      endcase
    end
  end

  // Simulation-only checks: parameter sanity, phyDigControl high only in
  // RUN, and no acknowledgment while the clock is still enabled.
`ifndef SYNTHESIS
  initial begin
    assert (SYNC_STAGES >= 2)
      else $fatal(1, "Clock command CDC needs at least two synchronizer stages");
    assert (ITERATIONS >= 1 && CYCLES_PER_ITERATION >= 1)
      else $fatal(1, "Clock pattern needs at least one iteration of one cycle");
  end
  always_ff @(posedge clock_tx2g) begin
    if (reset_clock2g_n) begin
      assert (phyDigControl == (state_q == RUN))
        else $error("phyDigControl must be high exactly while RUN");
      if (cmd_ack_o)
        assert (!phyDigControl)
          else $error("Clock command acknowledged while clock still enabled");
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
// request/cancel inputs. Only use for level signals held for several cycles.
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
