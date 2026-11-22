`default_nettype none

// ============================================================================
// jtagControlReplicas
// Digital control for the test of the analog replica modules. One replica at a
// time is reached through the fast package pins: its fast output goes to
// pin_fast_out through a digital mux in this module, and its fast input is
// connected to the input pin by an external analog mux driven by the one-hot
// fast_in_sel. The slow signals of every replica connect straight to a single
// jtag_tdr_snapshot Test Data Register, whatever the test mode. The TAP is external: it drives the
// shared TDR bus (tdr_*) and sel, and muxes tdo.
//
// The register uses the jtag_tdr_snapshot protocol (see that file):
//   DR bit 0      we (TDI) / busy (TDO)
//   DR bits [N:1] data_out (TDI, written when we=1) / snapshot of data_in (TDO)
//
// Register map (data bit; DR bit = data bit + 1). RO fields are driven by the
// replica: writes to them have no effect. RW fields read back the written value.
//
//   bits       field                dir  module
//   [2:0]      mode                 RW   test mode, see below
//   [3]        pll_start            RW   PLL
//   [13:4]     pll_bwcnt            RO   PLL
//   [19:14]    pll_maxovershoot     RO   PLL
//   [20]       pll_bwvalid          RO   PLL
//   [21]       rx_pclk              RW   RX Driver + VREF
//   [22]       rx_rst_n             RW   RX Driver + VREF
//   [42:23]    rx_en_vref           RW   RX Driver + VREF
//   [74:43]    dp_data_in           RW   Data Path w/o deskew
//   [75]       dp_zero_ena          RW   Data Path w/o deskew
//   [98:76]    dp_lfsr_seed         RW   Data Path w/o deskew
//   [99]       dp_lfsr_ena          RW   Data Path w/o deskew
//   [100]      dp_seed_load         RW   Data Path w/o deskew
//   [101]      dp_lane_id_mux       RW   Data Path w/o deskew
//   [109:102]  dp_lane_id           RW   Data Path w/o deskew
//
// Test mode (mode field), analog input mux select and digital output mux:
//   mode  replica               fast_in_sel  fast input   -> pin_fast_out
//   0     none                  3'b000       -            0
//   1     PLL                   3'b000       -            pll_out
//   2     RX Driver + VREF      3'b001       RXDATA       rx_out
//   3     Data Path w/o deskew  3'b010       CLK_in       dp_data_out
//   4     DCC                   3'b100       CLK_in       dcc_clk_out
//   5-7   none                  3'b000       -            0
//   fast_in_sel has at most one bit set; all zeros leaves every replica input
//   disconnected from the pin. The DCC has no slow signals and the PLL has no
//   fast input.
//
// Clocks and resets:
//   clock    IP-side clock of the TDR; it must run for register accesses.
//   reset_n  IP-side reset of the TDR. Clears the whole register: mode 0 and
//            every slow input at 0, including rx_rst_n.
//   jtag_nRst  clears both mailbox domains; committed controls are retained.
//   tdr_rst    clears serial shift state; accepted transactions finish once.
//
// Slow signals change together, one clock cycle after the Update-DR is
// synchronized. rx_pclk is a register bit like any other input: write the data
// first and toggle rx_pclk in a later write.
// RO fields are sampled by clock with no synchronizer, so they may be read
// while changing: use pll_bwvalid before trusting pll_bwcnt/pll_maxovershoot.
// fast_in_sel is decoded from mode and registered on clock, so it changes
// glitch-free one clock cycle after the slow signals. On a direct switch
// between two replicas, one bit falls and another rises on the same edge: if
// the analog mux is not break-before-make, go through mode 0 first.
// pin_fast_out is a combinational mux and a mode change can glitch it.
// ============================================================================

module jtagControlReplicas (
  // ==========================================================================
  // JTAG TDR BUS (from the external TAP, tdr_tck domain)
  // ==========================================================================
  input  wire logic        jtag_nRst,
  input  wire logic        tdr_rst,
  input  wire logic        tdr_tck,
  input  wire logic        tdr_tdi,
  input  wire logic        tdr_capture,
  input  wire logic        tdr_shift,
  input  wire logic        tdr_update,
  input  wire logic        sel,
  output var  logic        tdo,

  input  wire logic        clock,
  input  wire logic        reset_n,

  // ==========================================================================
  // PACKAGE PINS
  // ==========================================================================
  output var  logic        pin_fast_out,

  // ==========================================================================
  // EXTERNAL ANALOG INPUT MUX (one-hot: [0] RX, [1] Data Path, [2] DCC)
  // PLL don't have a fast input, so it is not selected.
  // ==========================================================================
  output var  logic [2:0]  fast_in_sel,

  // ==========================================================================
  // PLL
  // ==========================================================================
  input  wire logic        pll_out,
  output var  logic        pll_start,
  input  wire logic [9:0]  pll_bwcnt,
  input  wire logic [5:0]  pll_maxovershoot,
  input  wire logic        pll_bwvalid,

  // ==========================================================================
  // RX DRIVER + VREF
  // ==========================================================================
  input  wire logic        rx_out,
  output var  logic        rx_pclk,
  output var  logic        rx_rst_n,
  output var  logic [19:0] rx_en_vref,

  // ==========================================================================
  // DATA PATH W/O DESKEW
  // ==========================================================================
  input  wire logic        dp_data_out,
  output var  logic [31:0] dp_data_in,
  output var  logic        dp_zero_ena,
  output var  logic [22:0] dp_lfsr_seed,
  output var  logic        dp_lfsr_ena,
  output var  logic        dp_seed_load,
  output var  logic        dp_lane_id_mux,
  output var  logic [7:0]  dp_lane_id,

  // ==========================================================================
  // DCC
  // ==========================================================================
  input  wire logic        dcc_clk_out
);

  typedef enum logic [2:0] {
    MODE_NONE       = 3'd0,
    MODE_PLL        = 3'd1,
    MODE_RX         = 3'd2,
    MODE_DATA_PATH  = 3'd3,
    MODE_DCC        = 3'd4
  } mode_t;

  // Packed structs start at the MSB: fields are listed from the last register
  // field to the first, so mode lands on bits [2:0].
  typedef struct packed {
    logic [7:0]  dp_lane_id;
    logic        dp_lane_id_mux;
    logic        dp_seed_load;
    logic        dp_lfsr_ena;
    logic [22:0] dp_lfsr_seed;
    logic        dp_zero_ena;
    logic [31:0] dp_data_in;
    logic [19:0] rx_en_vref;
    logic        rx_rst_n;
    logic        rx_pclk;
    logic        pll_bwvalid;
    logic [5:0]  pll_maxovershoot;
    logic [9:0]  pll_bwcnt;
    logic        pll_start;
    logic [2:0]  mode;
  } reg_t;

  localparam int unsigned DATA_W = $bits(reg_t);

  reg_t reg_q;
  reg_t reg_rd;

  // --------------------------------------------------------------------------
  // TDR
  // --------------------------------------------------------------------------
  always_comb begin
    reg_rd                  = reg_q;
    reg_rd.pll_bwcnt        = pll_bwcnt;
    reg_rd.pll_maxovershoot = pll_maxovershoot;
    reg_rd.pll_bwvalid      = pll_bwvalid;
  end

  jtag_tdr_snapshot #(
    .DATA_W      (DATA_W),
    .RESET_VALUE ('0)
  ) u_tdr (
    .jtag_nRst     (jtag_nRst),
    .tdr_rst       (tdr_rst),
    .tdr_tck       (tdr_tck),
    .tdr_tdi       (tdr_tdi),
    .tdr_capture   (tdr_capture),
    .tdr_shift     (tdr_shift),
    .tdr_update    (tdr_update),
    .sel           (sel),
    .tdo           (tdo),
    .clk           (clock),
    .nRst          (reset_n),
    .data_in       (reg_rd),
    .data_out      (reg_q),
    .data_out_valid()
  );

  // --------------------------------------------------------------------------
  // SLOW SIGNALS
  // --------------------------------------------------------------------------
  assign pll_start         = reg_q.pll_start;
  assign rx_pclk           = reg_q.rx_pclk;
  assign rx_rst_n          = reg_q.rx_rst_n;
  assign rx_en_vref        = reg_q.rx_en_vref;
  assign dp_data_in        = reg_q.dp_data_in;
  assign dp_zero_ena       = reg_q.dp_zero_ena;
  assign dp_lfsr_seed      = reg_q.dp_lfsr_seed;
  assign dp_lfsr_ena       = reg_q.dp_lfsr_ena;
  assign dp_seed_load      = reg_q.dp_seed_load;
  assign dp_lane_id_mux    = reg_q.dp_lane_id_mux;
  assign dp_lane_id        = reg_q.dp_lane_id;

  // --------------------------------------------------------------------------
  // FAST SIGNALS
  // --------------------------------------------------------------------------
  logic [2:0] fast_in_sel_d;

  always_comb begin
    unique case (reg_q.mode)
      MODE_RX:         fast_in_sel_d = 3'b001;
      MODE_DATA_PATH:  fast_in_sel_d = 3'b010;
      MODE_DCC:        fast_in_sel_d = 3'b100;
      default:         fast_in_sel_d = 3'b000;
    endcase
  end

  // Registered so the analog mux select never glitches.
  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) fast_in_sel <= '0;
    else          fast_in_sel <= fast_in_sel_d;
  end

  always_comb begin
    unique case (reg_q.mode)
      MODE_PLL:        pin_fast_out = pll_out;
      MODE_RX:         pin_fast_out = rx_out;
      MODE_DATA_PATH:  pin_fast_out = dp_data_out;
      MODE_DCC:        pin_fast_out = dcc_clk_out;
      default:         pin_fast_out = 1'b0;
    endcase
  end

endmodule

`default_nettype wire
