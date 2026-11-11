`default_nettype none

// Dedicated VALID-lane pattern endpoint; one local 2 GHz clock domain.
//
// Analog interface: three level control bits.
//   phyTrainLfsr, phyTrainValid, phyTrainLaneid
// While ANY of them is 1 the analog front end transmits the valid pattern;
// while all are 0 it does not. The pattern itself is generated in the analog
// block; this endpoint only decides which bit is raised and for how long.
// All three are registered, glitch-free outputs.
//
// Bit selection: cmd_sel_async_i = {lfsr, valid, laneid} is a bundled command
// payload. The source holds it stable from before asserting request until
// acknowledgment returns low; it is captured once, after request
// synchronization (same rule as the Data2g lane mask). Constrain this
// bundled-data path; do not synchronize each bit independently. The selected
// bit(s) are driven high for the whole burst.
//
// Duration: each command holds the selected bit(s) high for ITERATIONS
// valid-pattern iterations (default 130). One iteration lasts
// CYCLES_PER_ITERATION clock_tx2g cycles (default 1, i.e. one 8-UI pattern
// per local cycle). The bits are therefore high for exactly
// ITERATIONS*CYCLES_PER_ITERATION cycles.
//
// Source command protocol (unchanged): request held high until cmd_ack_o,
// then the source lowers request/cancel; acknowledgment stays high until both
// synchronized inputs are low. Cancellation drops all bits on the next local
// edge. cmd_aborted_o is stable while acknowledgment is high.
// Common asynchronous reset assertion is required with the command source;
// reset release is synchronized locally below.
module PhyPatternValid2g #(
  parameter integer SYNC_STAGES = 3,           // flops per CDC synchronizer (>= 2)
  parameter integer ITERATIONS = 130,          // valid-pattern iterations per command
  parameter integer CYCLES_PER_ITERATION = 1   // clock_tx2g cycles per iteration
) (
  // ---- Local 2 GHz domain -------------------------------------------------
  input  wire       clock_tx2g,          // local control clock
  input  wire       reset_n,             // async reset (assert anywhere, release synced)

  // ---- Command link from the 800 MHz controller (asynchronous) ------------
  input  wire       cmd_req_async_i,     // request: held high until cmd_ack_o seen
  input  wire [2:0] cmd_sel_async_i,     // {lfsr, valid, laneid}; bundled with req
  input  wire       cmd_cancel_async_i,  // cancel: held high until cmd_ack_o seen
  output logic      cmd_ack_o,           // completion: held until req/cancel low
  output logic      cmd_aborted_o,       // 1 = command was cancelled; stable with ack
  output wire       reset_valid2g_n,     // locally synchronized reset (for neighbours)

  // ---- Analog front end: valid pattern is sent while any bit is 1 ---------
  output wire       phyTrainLfsr,        // valid pattern for LFSR training
  output wire       phyTrainValid,       // VALTRAIN pattern
  output wire       phyTrainLaneid       // valid pattern for lane-ID training
);
  // Number of local cycles the selected bit(s) stay high for one full
  // command, and the counter width needed to hold that value.
  localparam integer TOTAL_CYCLES = ITERATIONS * CYCLES_PER_ITERATION;
  localparam integer CW = $clog2(TOTAL_CYCLES + 1);

  // Reset release and command inputs are synchronized into clock_tx2g
  // before any logic uses them. cmd_sel_async_i is NOT synchronized: it is
  // stable whenever req_sync is high, so it is sampled directly then.
  wire req_sync, cancel_sync;
  Valid2gResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(reset_valid2g_n)
  );
  Valid2gSyncBit #(.STAGES(SYNC_STAGES)) u_req_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_valid2g_n),
    .async_i(cmd_req_async_i), .sync_o(req_sync)
  );
  Valid2gSyncBit #(.STAGES(SYNC_STAGES)) u_cancel_sync (
    .clk_i(clock_tx2g), .rst_ni(reset_valid2g_n),
    .async_i(cmd_cancel_async_i), .sync_o(cancel_sync)
  );

  // IDLE         : waiting for a synchronized request.
  // RUN          : selected bit(s) high, counting down remaining_q.
  // WAIT_REQ_LOW : ack high, waiting for the source to drop request/cancel.
  typedef enum logic [1:0] {IDLE, RUN, WAIT_REQ_LOW} state_t;
  state_t state_q;
  logic [CW-1:0] remaining_q;  // cycles left with the pattern enabled
  logic [2:0] train_q;         // registered {lfsr, valid, laneid} to analog

  // Outputs come straight from flops, so the analog sees glitch-free levels.
  assign {phyTrainLfsr, phyTrainValid, phyTrainLaneid} = train_q;

  // Main control FSM.
  always_ff @(posedge clock_tx2g or negedge reset_valid2g_n) begin
    if (!reset_valid2g_n) begin
      state_q <= IDLE;
      remaining_q <= '0;
      train_q <= 3'b000;
      cmd_ack_o <= 1'b0;
      cmd_aborted_o <= 1'b0;
    end else begin
      case (state_q)
        // New command: clear the previous result, then either start the
        // pattern or, if already cancelled, complete immediately.
        IDLE: if (req_sync) begin
          cmd_aborted_o <= 1'b0;
          if (cancel_sync) begin
            // Cancelled before start: nothing is sent.
            cmd_aborted_o <= 1'b1;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else begin
            // Load the full count and raise the selected bit(s) from the
            // next cycle.
            remaining_q <= CW'(TOTAL_CYCLES);
            train_q <= cmd_sel_async_i;  // bundled payload, stable here
            state_q <= RUN;
          end
        end

        // Pattern enabled. The bit(s) are high for exactly TOTAL_CYCLES
        // cycles unless cancelled.
        RUN: begin
          if (cancel_sync) begin
            // Cancel: stop the pattern now and report an aborted command.
            train_q <= 3'b000;
            remaining_q <= '0;
            cmd_aborted_o <= 1'b1;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else if (remaining_q == CW'(1)) begin
            // Last counted cycle: stop the pattern, normal completion.
            train_q <= 3'b000;
            remaining_q <= '0;
            cmd_ack_o <= 1'b1;
            state_q <= WAIT_REQ_LOW;
          end else begin
            remaining_q <= remaining_q - CW'(1);
          end
        end

        WAIT_REQ_LOW: if (!req_sync && !cancel_sync) begin
          // Return-to-zero includes cancellation, so it cannot leak into the
          // next transaction.
          cmd_ack_o <= 1'b0;
          state_q <= IDLE;
        end

        // Illegal state encoding: recover safely with all bits off.
        default: begin
          state_q <= IDLE;
          train_q <= 3'b000;
          cmd_ack_o <= 1'b0;
        end
      endcase
    end
  end

  // Simulation-only checks: a started command selects at least one bit,
  // bits are high only in RUN, the counter never underflows, and the
  // aborted result stays stable while ack is held.
`ifndef SYNTHESIS
  initial begin
    assert (ITERATIONS >= 1 && CYCLES_PER_ITERATION >= 1)
      else $fatal(1, "VALID pattern needs at least one iteration of one cycle");
  end
  always_ff @(posedge clock_tx2g) begin
    if (reset_valid2g_n) begin
      if (state_q == IDLE && req_sync && !cancel_sync)
        assert (cmd_sel_async_i != 3'b000 && !$isunknown(cmd_sel_async_i))
          else $error("VALID command started with no training bit selected");
      if (state_q != RUN)
        assert (train_q == 3'b000)
          else $error("VALID training bit high outside RUN");
      if (state_q == RUN)
        assert (remaining_q != 0)
          else $error("VALID burst counter underflow");
    end
  end
  assert property (@(posedge clock_tx2g) disable iff (!reset_valid2g_n)
    cmd_ack_o && $past(cmd_ack_o) |-> $stable(cmd_aborted_o))
    else $error("VALID command result changed while acknowledgment held");
`endif
endmodule

// Reset synchronizer: asserts asynchronously with arst_ni, releases
// synchronously to clk_i after STAGES clock edges.
module Valid2gResetSync #(
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
  initial assert (STAGES >= 2) else $fatal(1, "VALID reset synchronizer needs >=2 stages");
`endif
endmodule

// Single-bit level synchronizer (STAGES-flop chain) for the asynchronous
// request/cancel inputs. Only use for level signals held for several cycles.
module Valid2gSyncBit #(
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
  initial assert (STAGES >= 2) else $fatal(1, "VALID CDC synchronizer needs >=2 stages");
`endif
endmodule

`default_nettype wire
