`default_nettype none
// ============================================================================
// PhyPatternValid2g -- VALID-lane training-bit endpoint (2 GHz domain)
// ============================================================================
// Synchronous slave of PhyTxSequencer.
//
// Analog interface: two registered, glitch-free level bits
//   phyTrainValid, phyTrainLaneid
// While one of them is 1 the analog front end transmits the valid-lane
// pattern, which is always VALTRAIN (11110000) and is generated in the
// analog block. Digital only selects which training bit is raised:
//   VAL_TRAIN       -> phyTrainValid
//   lane-ID burst   -> phyTrainLaneid
// The LFSR valid bit (phyTrainLfsr) is in the 500 MHz domain, in
// PhyPatternValid500m, because the analog front end sends the LFSR valid
// pattern on the 500 MHz clock.
// In ACTIVE both are 0 (the valid lane is driven by the functional path).
//
// {phyTrainValid, phyTrainLaneid} <= val_sel, delayed by START_DELAY.
// No synchronizer, counter, cancel or acknowledgment: PhyTxSequencer owns all
// timing and guarantees val_sel is onehot0.
//
// Timing: val_sel is launched by a clock_tx500 flop and captured on the FIRST
// clock_tx2g edge after the launching edge (related clocks, single-cycle
// synchronous path). Latency from the sequencer edge to the outputs:
//   (1 + START_DELAY) clock_tx2g cycles = (1 + START_DELAY) x 8 UI.
// START_DELAY = 3 aligns these outputs with PhyPatternTx500 (START_DELAY = 0).
//
// Reset: common asynchronous assert, local synchronized release.
// Reset value = idle (0,0).
// ============================================================================
module PhyPatternValid2g #(
  parameter integer SYNC_STAGES = 3,  // reset-release synchronizer depth (>= 2)
  parameter integer START_DELAY = 0   // extra clock_tx2g cycles of fixed latency
) (
  // ---- Local 2 GHz domain -------------------------------------------------
  input  wire       clock_tx2g,          // local control clock
  input  wire       reset_n,             // async reset (assert anywhere, release synced)
  output wire       reset_valid2g_n,     // locally synchronized reset (for neighbours)

  // ---- From PhyTxSequencer (clock_tx500 launched, related clock) ----------
  input  wire [1:0] val_sel,             // {valid, laneid}, onehot0

  // ---- Analog front end: valid pattern is sent while one bit is 1 ---------
  output wire       phyTrainValid,       // VALTRAIN pattern /S1
  output wire       phyTrainLaneid       // valid pattern for lane-ID training
);
  Valid2gResetSync #(.STAGES(SYNC_STAGES)) u_reset_sync (
    .clk_i(clock_tx2g), .arst_ni(reset_n), .rst_no(reset_valid2g_n));

  // Fixed latency-trim pipeline (START_DELAY flops), then the output flops.
  wire [1:0] val_sel_d;
  generate
    if (START_DELAY == 0) begin : g_no_delay
      assign val_sel_d = val_sel;
    end else begin : g_delay
      logic [1:0] dly_q [START_DELAY];
      always_ff @(posedge clock_tx2g or negedge reset_valid2g_n) begin
        if (!reset_valid2g_n) begin
          for (int i = 0; i < START_DELAY; i++) dly_q[i] <= 2'b00;
        end else begin
          dly_q[0] <= val_sel;
          for (int i = 1; i < START_DELAY; i++) dly_q[i] <= dly_q[i-1];
        end
      end
      assign val_sel_d = dly_q[START_DELAY-1];
    end
  endgenerate

  logic [1:0] train_q;  // registered {valid, laneid} to analog
  always_ff @(posedge clock_tx2g or negedge reset_valid2g_n)
    if (!reset_valid2g_n) train_q <= 2'b00;
    else                  train_q <= val_sel_d;
  assign {phyTrainValid, phyTrainLaneid} = train_q;

`ifndef SYNTHESIS
  initial assert (START_DELAY >= 0) else $fatal(1, "VALID START_DELAY must be >= 0");
  assert property (@(posedge clock_tx2g) disable iff (!reset_valid2g_n) $onehot0(train_q))
    else $error("VALID: more than one training bit high");
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

`default_nettype wire
