`default_nettype none
// =============================================================================
// PhyTxControlTop - integration wrapper for the PHY-side TX pattern control
// =============================================================================
// Instantiates PhyTxSequencer, PhyPatternClock2g, PhyPatternValid2g,
// PhyPatternValid500m and LANES data lanes (PhyPatternData2g + PhyPatternTx500
// each, Lane ID i from the sequencer).
// Wiring only, no extra logic.
//
// The seq_* link is the ONLY connection to LtsmPhyPatternCtrl800 (800 MHz,
// asynchronous). Every other path inside is synchronous to clock_tx500 or
// to the related clock_tx2g (same source, 4:1, phase aligned).
//
// Endpoint latency from the sequencer output edge (fixed, one output flop):
//   Clock2g / Valid2g / Data2g : 1 clock_tx2g cycle  =  8 UI
//   Valid500m / Tx500          : 1 clock_tx500 cycle = 32 UI
// Signals that must match edge for edge are always in one domain (lane ID:
// Valid2g + Data2g; LFSR: Valid500m + Tx500). The 2 GHz forwarded clock only
// has to cover the burst, which the PRE/POST envelope guarantees: it leads
// the 500 MHz outputs by PRE x 32 + 24 UI and trails them by POST x 32 - 24 UI.
// Preserve each endpoint hierarchy so it can be placed beside its transmitter.
// =============================================================================
module PhyTxControlTop #(
  parameter integer LANES          = 16,
  parameter integer SYNC_STAGES    = 3,
  parameter integer PRE_CYC        = 4,
  parameter integer POST_CYC       = 4,
  parameter integer CLK_LEN        = 96
) (
  input  wire              clock_tx500,
  input  wire              clock_tx2g,
  input  wire              reset_n,

  // ---- Link from/to LtsmPhyPatternCtrl800 (asynchronous) --------------------
  input  wire              seq_req_i,
  input  wire [2:0]        seq_op_i,
  input  wire [LANES-1:0]  seq_mask_i,
  output wire              seq_ack_o,
  output wire              active_ready_o,   // clock_tx500: for the TX datapath and Ctrl800

  // ---- Static Lane IDs (from UcieDigitalTopJtag laneid0..laneid15) ----------
  // Data lane N sends laneidN. Lanes >= LANES are unused.
  input  wire [3:0]        laneid0,
  input  wire [3:0]        laneid1,
  input  wire [3:0]        laneid2,
  input  wire [3:0]        laneid3,
  input  wire [3:0]        laneid4,
  input  wire [3:0]        laneid5,
  input  wire [3:0]        laneid6,
  input  wire [3:0]        laneid7,
  input  wire [3:0]        laneid8,
  input  wire [3:0]        laneid9,
  input  wire [3:0]        laneid10,
  input  wire [3:0]        laneid11,
  input  wire [3:0]        laneid12,
  input  wire [3:0]        laneid13,
  input  wire [3:0]        laneid14,
  input  wire [3:0]        laneid15,

  // ---- Analog / PHY controls --------------------------------------------------
  output wire              phyDigControl,     // Clock2g
  output wire              phyTrainLfsr,      // Valid500m
  output wire              phyTrainValid,     // Valid2g
  output wire              phyTrainLaneid,
  output wire [LANES-1:0]  digControl,        // Data2g, one per data lane
  output wire [LANES-1:0]  laneID_index,
  output wire [LANES-1:0][3:0] lane_id_o,    // Lane ID sent by each lane (= laneidN)
  output wire [LANES-1:0]  enable_LFSR,       // Tx500, one bit per lane
  output wire [LANES-1:0]  zero_ena,
  output wire [LANES-1:0]  load_seed,
  output wire [LANES-1:0]  load_zero
);
  wire clk_en, id_en, lfsr_val_en;
  wire [1:0] val_sel;
  wire [2:0] tx500_mode;
  wire [LANES-1:0] tx500_lane_en;
  // Lane IDs from the sequencer, one wire per data lane.
  wire [3:0] lane_id0;
  wire [3:0] lane_id1;
  wire [3:0] lane_id2;
  wire [3:0] lane_id3;
  wire [3:0] lane_id4;
  wire [3:0] lane_id5;
  wire [3:0] lane_id6;
  wire [3:0] lane_id7;
  wire [3:0] lane_id8;
  wire [3:0] lane_id9;
  wire [3:0] lane_id10;
  wire [3:0] lane_id11;
  wire [3:0] lane_id12;
  wire [3:0] lane_id13;
  wire [3:0] lane_id14;
  wire [3:0] lane_id15;
  wire unused_reset_seq_n, unused_reset_clock2g_n, unused_reset_valid2g_n;
  wire unused_reset_valid500m_n;

  PhyTxSequencer #(
    .LANES(LANES), .SYNC_STAGES(SYNC_STAGES),
    .PRE_CYC(PRE_CYC), .POST_CYC(POST_CYC), .CLK_LEN(CLK_LEN)
  ) u_seq (
    .clock_tx500(clock_tx500), .reset_n(reset_n), .reset_seq_n(unused_reset_seq_n),
    .seq_req_i(seq_req_i),
    .seq_op_i(seq_op_i), .seq_mask_i(seq_mask_i),
    .seq_ack_o(seq_ack_o),
    .clk_en_o(clk_en), .val_sel_o(val_sel), .lfsr_val_en_o(lfsr_val_en), .id_en_o(id_en),
    .tx500_mode_o(tx500_mode), .tx500_lane_en_o(tx500_lane_en),
    .active_ready_o(active_ready_o),
    .laneid0_i(laneid0),
    .laneid1_i(laneid1),
    .laneid2_i(laneid2),
    .laneid3_i(laneid3),
    .laneid4_i(laneid4),
    .laneid5_i(laneid5),
    .laneid6_i(laneid6),
    .laneid7_i(laneid7),
    .laneid8_i(laneid8),
    .laneid9_i(laneid9),
    .laneid10_i(laneid10),
    .laneid11_i(laneid11),
    .laneid12_i(laneid12),
    .laneid13_i(laneid13),
    .laneid14_i(laneid14),
    .laneid15_i(laneid15),
    .laneid0_o(lane_id0),
    .laneid1_o(lane_id1),
    .laneid2_o(lane_id2),
    .laneid3_o(lane_id3),
    .laneid4_o(lane_id4),
    .laneid5_o(lane_id5),
    .laneid6_o(lane_id6),
    .laneid7_o(lane_id7),
    .laneid8_o(lane_id8),
    .laneid9_o(lane_id9),
    .laneid10_o(lane_id10),
    .laneid11_o(lane_id11),
    .laneid12_o(lane_id12),
    .laneid13_o(lane_id13),
    .laneid14_o(lane_id14),
    .laneid15_o(lane_id15));


  PhyPatternClock2g #(.SYNC_STAGES(SYNC_STAGES)) u_clock2g (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n), .reset_clock2g_n(unused_reset_clock2g_n),
    .clk_en(clk_en), .phyDigControl(phyDigControl));

  PhyPatternValid2g #(.SYNC_STAGES(SYNC_STAGES)) u_valid2g (
    .clock_tx2g(clock_tx2g), .reset_n(reset_n), .reset_valid2g_n(unused_reset_valid2g_n),
    .val_sel(val_sel),
    .phyTrainValid(phyTrainValid), .phyTrainLaneid(phyTrainLaneid));

  PhyPatternValid500m #(.SYNC_STAGES(SYNC_STAGES)) u_valid500m (
    .clock_tx500(clock_tx500), .reset_n(reset_n), .reset_valid500m_n(unused_reset_valid500m_n),
    .lfsr_en(lfsr_val_en), .phyTrainLfsr(phyTrainLfsr));

    PhyPatternData2g #(.SYNC_STAGES(SYNC_STAGES)) u_data2g (
      .clock_tx2g(clock_tx2g), .reset_n(reset_n),
    .id_en(id_en), .lane_id_i(lane_id_i),
    .digControl(digControl), .laneID_index(laneID_index), .lane_id_o(lane_id_o));

  for (genvar lane = 0; lane < LANES; lane++) begin : g_tx500
    PhyPatternTx500 #(.SYNC_STAGES(SYNC_STAGES)) u_tx500 (
      .clock_tx500(clock_tx500), .reset_n(reset_n),
      .mode(tx500_mode), .lane_en(tx500_lane_en[lane]),
      .enable_LFSR(enable_LFSR[lane]), .zero_ena(zero_ena[lane]),
      .load_seed(load_seed[lane]), .load_zero(load_zero[lane]));
  end
endmodule

`default_nettype wire
