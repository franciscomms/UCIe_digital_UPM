`default_nettype none
// =============================================================================
// PhyTxControlTop - integration wrapper for the PHY-side TX pattern control
// =============================================================================
// Instantiates PhyTxSequencer, PhyPatternClock2g, PhyPatternValid2g,
// PhyPatternData2g and LANES x PhyPatternTx500. Wiring only, no extra logic.
//
// The seq_* link is the ONLY connection to LtsmPhyPatternCtrl800 (800 MHz,
// asynchronous). Every other path inside is synchronous to clock_tx500 or
// to the related clock_tx2g (same source, 4:1, phase aligned).
//
// Endpoint latency from the sequencer output edge (START_DELAY_* = 0):
//   Clock2g / Valid2g / Data2g : 1 clock_tx2g cycle  =  8 UI
//   Tx500                      : 1 clock_tx500 cycle = 32 UI
// Set START_DELAY_2G = 3 to align all four outputs at 32 UI.
// Preserve each endpoint hierarchy so it can be placed beside its transmitter.
// =============================================================================
module PhyTxControlTop #(
  parameter integer LANES          = 16,
  parameter integer SYNC_STAGES    = 3,
  parameter integer PRE_CYC        = 4,
  parameter integer POST_CYC       = 4,
  parameter integer CLK_LEN        = 96,
  parameter integer START_DELAY_2G = 0,  // Clock2g, Valid2g, Data2g (clock_tx2g cycles)
  parameter integer START_DELAY_TX = 0   // every Tx500 lane (clock_tx500 cycles)
) (
  input  wire              clock_tx500,
  input  wire              clock_tx2g,
  input  wire              reset_n,

  // ---- Link from/to LtsmPhyPatternCtrl800 (asynchronous) --------------------
  input  wire              seq_req_i,
  input  wire              seq_stop_i,
  input  wire [2:0]        seq_op_i,
  input  wire [LANES-1:0]  seq_mask_i,
  output wire              seq_ack_o,
  output wire              seq_aborted_o,
  output wire              active_ready_o,   // clock_tx500: for the TX datapath and Ctrl800

  // ---- Lane ID (quasi-static) -----------------------------------------------
  input  wire [3:0]        lane_id_i,

  // ---- Analog / PHY controls --------------------------------------------------
  output wire              phyDigControl,     // Clock2g
  output wire              phyTrainLfsr,      // Valid2g
  output wire              phyTrainValid,
  output wire              phyTrainLaneid,
  output wire              digControl,        // Data2g
  output wire              laneID_index,
  output wire [3:0]        lane_id_o,
  output wire [LANES-1:0]  enable_LFSR,       // Tx500, one bit per lane
  output wire [LANES-1:0]  zero_ena,
  output wire [LANES-1:0]  load_seed,
  output wire [LANES-1:0]  load_zero
);
  wire clk_en, id_en;
  wire [2:0] val_sel, tx500_mode;
  wire [LANES-1:0] tx500_lane_en;
  wire unused_reset_seq_n, unused_reset_clock2g_n, unused_reset_valid2g_n;

  PhyTxSequencer #(
    .LANES(LANES), .SYNC_STAGES(SYNC_STAGES),
    .PRE_CYC(PRE_CYC), .POST_CYC(POST_CYC), .CLK_LEN(CLK_LEN)
  ) u_seq (
    .clock_tx500(clock_tx500), .reset_n(reset_n), .reset_seq_n(unused_reset_seq_n),
    .seq_req_i(seq_req_i), .seq_stop_i(seq_stop_i),
    .seq_op_i(seq_op_i), .seq_mask_i(seq_mask_i),
    .seq_ack_o(seq_ack_o), .seq_aborted_o(seq_aborted_o),
    .clk_en_o(clk_en), .val_sel_o(val_sel), .id_en_o(id_en),
    .tx500_mode_o(tx500_mode), .tx500_lane_en_o(tx500_lane_en),
    .active_ready_o(active_ready_o));

  PhyPatternClock2g #(.SYNC_STAGES(SYNC_STAGES), .START_DELAY(START_DELAY_2G)) u_clock2g (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n), .reset_clock2g_n(unused_reset_clock2g_n),
    .clk_en(clk_en), .phyDigControl(phyDigControl));

  PhyPatternValid2g #(.SYNC_STAGES(SYNC_STAGES), .START_DELAY(START_DELAY_2G)) u_valid2g (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n), .reset_valid2g_n(unused_reset_valid2g_n),
    .val_sel(val_sel),
    .phyTrainLfsr(phyTrainLfsr), .phyTrainValid(phyTrainValid), .phyTrainLaneid(phyTrainLaneid));

  PhyPatternData2g #(.SYNC_STAGES(SYNC_STAGES), .START_DELAY(START_DELAY_2G)) u_data2g (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n),
    .id_en(id_en), .lane_id_i(lane_id_i),
    .digControl(digControl), .laneID_index(laneID_index), .lane_id_o(lane_id_o));

  for (genvar lane = 0; lane < LANES; lane++) begin : g_tx500
    PhyPatternTx500 #(.SYNC_STAGES(SYNC_STAGES), .START_DELAY(START_DELAY_TX)) u_tx500 (
      .clock_tx500(clock_tx500), .reset_n(reset_n),
      .mode(tx500_mode), .lane_en(tx500_lane_en[lane]),
      .enable_LFSR(enable_LFSR[lane]), .zero_ena(zero_ena[lane]),
      .load_seed(load_seed[lane]), .load_zero(load_zero[lane]));
  end
endmodule

`default_nettype wire
