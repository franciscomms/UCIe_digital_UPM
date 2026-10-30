`default_nettype none

// ============================================================================
// jtagControlReplicas
// Digital control for the test of the analog replica modules. One package pin
// pair (pin_fast_in / pin_fast_out) reaches one replica at a time; the slow
// signals of every replica connect straight to a single jtag_tdr_snapshot Test
// Data Register, whatever the test mode. The TAP is external: it drives the
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
//   [9:3]      pll_n                RW   PLL
//   [16:10]    pll_nstep            RW   PLL
//   [17]       pll_start            RW   PLL
//   [18]       pll_reset            RW   PLL
//   [28:19]    pll_bwcnt            RO   PLL
//   [34:29]    pll_maxovershoot     RO   PLL
//   [35]       pll_bwvalid          RO   PLL
//   [36]       rx_pclk              RW   RX Driver + VREF
//   [37]       rx_rst_n             RW   RX Driver + VREF
//   [57:38]    rx_en_vref           RW   RX Driver + VREF
//   [89:58]    dp_data_in           RW   Data Path w/o deskew
//   [90]       dp_zero_ena          RW   Data Path w/o deskew
//   [113:91]   dp_lfsr_seed         RW   Data Path w/o deskew
//   [114]      dp_lfsr_ena          RW   Data Path w/o deskew
//   [115]      dp_seed_load         RW   Data Path w/o deskew
//   [116]      dp_lane_id_mux       RW   Data Path w/o deskew
//   [124:117]  dp_lane_id           RW   Data Path w/o deskew
//   [144:125]  deskew_dcc_config    RW   Deskew + DCC
//   [164:145]  deskew_config        RW   Deskew
//
// Test mode (mode field) and the replica pins routed to the package pins:
//   mode  replica               pin_fast_in ->   -> pin_fast_out
//   0     none                  -                0
//   1     PLL                   -                pll_out
//   2     RX Driver + VREF      rx_rxdata        rx_out
//   3     Data Path w/o deskew  dp_clk_in        dp_data_out
//   4     Deskew + DCC          deskew_dcc_clk_in deskew_dcc_clk_out
//   5     Deskew                deskew_clk_in    deskew_clk_out
//   6     DCC                   dcc_clk_in       dcc_clk_out
//   7     none                  -                0
//   The fast input of every replica that is not selected is held at 0. The DCC
//   has no slow signals and the PLL has no fast input.
//
// Clocks and resets:
//   clock    IP-side clock of the TDR; it must run for register accesses.
//   reset_n  IP-side reset of the TDR. Clears the whole register: mode 0 and
//            every slow input at 0, including pll_reset and rx_rst_n.
//   jtag_nRst  clears both mailbox domains; committed controls are retained.
//   tdr_rst    clears serial shift state; accepted transactions finish once.
//
// Slow signals change together, one clock cycle after the Update-DR is
// synchronized. rx_pclk is a register bit like any other input: write the data
// first and toggle rx_pclk in a later write.
// RO fields are sampled by clock with no synchronizer, so they may be read
// while changing: use pll_bwvalid before trusting pll_bwcnt/pll_maxovershoot.
// The fast paths are combinational and a mode change can glitch them: change
// mode only while pin_fast_in is idle.
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
  input  wire logic        pin_fast_in,
  output var  logic        pin_fast_out,

  // ==========================================================================
  // PLL
  // ==========================================================================
  input  wire logic        pll_out,
  output var  logic [6:0]  pll_n,
  output var  logic [6:0]  pll_nstep,
  output var  logic        pll_start,
  output var  logic        pll_reset,
  input  wire logic [9:0]  pll_bwcnt,
  input  wire logic [5:0]  pll_maxovershoot,
  input  wire logic        pll_bwvalid,

  // ==========================================================================
  // RX DRIVER + VREF
  // ==========================================================================
  output var  logic        rx_rxdata,
  input  wire logic        rx_out,
  output var  logic        rx_pclk,
  output var  logic        rx_rst_n,
  output var  logic [19:0] rx_en_vref,

  // ==========================================================================
  // DATA PATH W/O DESKEW
  // ==========================================================================
  output var  logic        dp_clk_in,
  input  wire logic        dp_data_out,
  output var  logic [31:0] dp_data_in,
  output var  logic        dp_zero_ena,
  output var  logic [22:0] dp_lfsr_seed,
  output var  logic        dp_lfsr_ena,
  output var  logic        dp_seed_load,
  output var  logic        dp_lane_id_mux,
  output var  logic [7:0]  dp_lane_id,

  // ==========================================================================
  // DESKEW + DCC
  // ==========================================================================
  output var  logic        deskew_dcc_clk_in,
  input  wire logic        deskew_dcc_clk_out,
  output var  logic [19:0] deskew_dcc_config,

  // ==========================================================================
  // DESKEW
  // ==========================================================================
  output var  logic        deskew_clk_in,
  input  wire logic        deskew_clk_out,
  output var  logic [19:0] deskew_config,

  // ==========================================================================
  // DCC
  // ==========================================================================
  output var  logic        dcc_clk_in,
  input  wire logic        dcc_clk_out
);

  typedef enum logic [2:0] {
    MODE_NONE       = 3'd0,
    MODE_PLL        = 3'd1,
    MODE_RX         = 3'd2,
    MODE_DATA_PATH  = 3'd3,
    MODE_DESKEW_DCC = 3'd4,
    MODE_DESKEW     = 3'd5,
    MODE_DCC        = 3'd6
  } mode_t;

  // Packed structs start at the MSB: fields are listed from the last register
  // field to the first, so mode lands on bits [2:0].
  typedef struct packed {
    logic [19:0] deskew_config;
    logic [19:0] deskew_dcc_config;
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
    logic        pll_reset;
    logic        pll_start;
    logic [6:0]  pll_nstep;
    logic [6:0]  pll_n;
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
  assign pll_n             = reg_q.pll_n;
  assign pll_nstep         = reg_q.pll_nstep;
  assign pll_start         = reg_q.pll_start;
  assign pll_reset         = reg_q.pll_reset;
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
  assign deskew_dcc_config = reg_q.deskew_dcc_config;
  assign deskew_config     = reg_q.deskew_config;

  // --------------------------------------------------------------------------
  // FAST SIGNALS
  // --------------------------------------------------------------------------
  assign rx_rxdata         = (reg_q.mode == MODE_RX)         & pin_fast_in;
  assign dp_clk_in         = (reg_q.mode == MODE_DATA_PATH)  & pin_fast_in;
  assign deskew_dcc_clk_in = (reg_q.mode == MODE_DESKEW_DCC) & pin_fast_in;
  assign deskew_clk_in     = (reg_q.mode == MODE_DESKEW)     & pin_fast_in;
  assign dcc_clk_in        = (reg_q.mode == MODE_DCC)        & pin_fast_in;

  always_comb begin
    unique case (reg_q.mode)
      MODE_PLL:        pin_fast_out = pll_out;
      MODE_RX:         pin_fast_out = rx_out;
      MODE_DATA_PATH:  pin_fast_out = dp_data_out;
      MODE_DESKEW_DCC: pin_fast_out = deskew_dcc_clk_out;
      MODE_DESKEW:     pin_fast_out = deskew_clk_out;
      MODE_DCC:        pin_fast_out = dcc_clk_out;
      default:         pin_fast_out = 1'b0;
    endcase
  end

endmodule

`default_nettype wire
