`timescale 1ns/1ps

// Drives the TDR bus directly and uses literal bit positions, so a change in
// the register map documented in jtagControlReplicas.sv fails this test.
//   vlib work
//   vlog -sv ../systemVerilog/src/tc_sync.sv ../systemVerilog/src/jtag_tdr_snapshot.sv
//        jtagControlReplicas.sv jtagControlReplicas_tb.sv
//   vsim -c jtagControlReplicas_tb -do "run -all; quit -f"
module jtagControlReplicas_tb;
  localparam int DATA_W = 110;

  logic jtag_nRst = 1'b0;
  logic tdr_rst = 1'b0;
  logic tdr_tck = 1'b0;
  logic tdr_tdi = 1'b0;
  logic tdr_capture = 1'b0;
  logic tdr_shift = 1'b0;
  logic tdr_update = 1'b0;
  logic sel = 1'b1;
  logic tdo;
  logic clock = 1'b0;
  logic reset_n = 1'b0;
  logic pin_fast_out;
  logic [2:0] fast_in_sel;

  logic pll_out = 1'b0;
  logic pll_start;
  logic [9:0] pll_bwcnt = '0;
  logic [5:0] pll_maxovershoot = '0;
  logic pll_bwvalid = 1'b0;
  logic rx_out = 1'b0;
  logic rx_pclk, rx_rst_n;
  logic [19:0] rx_en_vref;
  logic dp_data_out = 1'b0;
  logic [31:0] dp_data_in;
  logic dp_zero_ena;
  logic [22:0] dp_lfsr_seed;
  logic dp_lfsr_ena, dp_seed_load, dp_lane_id_mux;
  logic [7:0] dp_lane_id;
  logic dcc_clk_out = 1'b0;

  always #5 clock = ~clock;

  jtagControlReplicas dut (.*);

  int errors = 0;

  task automatic check(input string name, input logic [255:0] got, input logic [255:0] expected);
    if (got !== expected) begin
      $error("%s: expected %h, got %h", name, expected, got);
      errors++;
    end
  endtask

  task automatic tick(input bit cap, input bit shift, input bit upd, input bit di);
    tdr_capture = cap;
    tdr_shift = shift;
    tdr_update = upd;
    tdr_tdi = di;
    #20 tdr_tck = 1'b1;
    #20 tdr_tck = 1'b0;
    tdr_capture = 1'b0;
    tdr_shift = 1'b0;
    tdr_update = 1'b0;
  endtask

  task automatic scan(input logic [DATA_W:0] tx, output logic [DATA_W:0] rx);
    tick(1, 0, 0, 0);
    for (int i = 0; i <= DATA_W; i++) begin
      rx[i] = tdo;
      tick(0, 1, 0, tx[i]);
    end
    tick(0, 0, 1, 0);
    repeat (10) tick(0, 0, 0, 0); // Let the transaction complete.
  endtask

  task automatic write_reg(input logic [DATA_W-1:0] value);
    logic [DATA_W:0] ignored;
    scan({value, 1'b1}, ignored);
  endtask

  task automatic read_reg(output logic [DATA_W-1:0] value);
    logic [DATA_W:0] rx;
    scan('0, rx); // Launches the snapshot.
    scan('0, rx); // Returns it.
    check("busy", rx[0], 1'b0);
    value = rx[DATA_W:1];
  endtask

  // The analog mux select is one-hot for the selected replica, and only its
  // fast output reaches the pin.
  task automatic check_mode(input logic [2:0] mode);
    logic [DATA_W-1:0] rd;
    logic [2:0] sel_in;
    logic [3:0] sel_out;
    write_reg(DATA_W'(mode));
    read_reg(rd);
    check("mode readback", rd[2:0], mode);
    sel_in  = (mode >= 2 && mode <= 4) ? 3'(1 << (mode - 2)) : '0;
    sel_out = (mode >= 1 && mode <= 4) ? 4'(1 << (mode - 1)) : '0;
    check("fast_in_sel", fast_in_sel, sel_in);
    for (int o = 0; o < 4; o++) begin
      {dcc_clk_out, dp_data_out, rx_out, pll_out} = 4'(1 << o);
      #1 check("fast out", pin_fast_out, sel_out[o]);
    end
    {dcc_clk_out, dp_data_out, rx_out, pll_out} = '1;
    #1 check("fast out all", pin_fast_out, |sel_out);
    {dcc_clk_out, dp_data_out, rx_out, pll_out} = '0;
  endtask

  initial begin : regression
    logic [DATA_W-1:0] rd, wr;
    #33;
    reset_n = 1'b1;
    jtag_nRst = 1'b1;
    repeat (4) tick(0, 0, 0, 0);

    read_reg(rd);
    check("reset value", rd, '0);
    check("reset pll_start", pll_start, 1'b0);
    check("reset rx_rst_n", rx_rst_n, 1'b0);

    for (int m = 0; m < 8; m++) check_mode(3'(m));

    // Every field has a distinct pattern at its documented position.
    wr = '0;
    wr[2:0]     = 3'd2;
    wr[3]       = 1'b1;
    wr[13:4]    = '1;     // RO
    wr[19:14]   = '1;     // RO
    wr[20]      = 1'b1;   // RO
    wr[21]      = 1'b1;
    wr[22]      = 1'b0;
    wr[42:23]   = 20'h3c5a1;
    wr[74:43]   = 32'hdeadbeef;
    wr[75]      = 1'b1;
    wr[98:76]   = 23'h2bcdef;
    wr[99]      = 1'b0;
    wr[100]     = 1'b1;
    wr[101]     = 1'b0;
    wr[109:102] = 8'ha7;
    write_reg(wr);

    check("pll_start", pll_start, 1'b1);
    check("rx_pclk", rx_pclk, 1'b1);
    check("rx_rst_n", rx_rst_n, 1'b0);
    check("rx_en_vref", rx_en_vref, 20'h3c5a1);
    check("dp_data_in", dp_data_in, 32'hdeadbeef);
    check("dp_zero_ena", dp_zero_ena, 1'b1);
    check("dp_lfsr_seed", dp_lfsr_seed, 23'h2bcdef);
    check("dp_lfsr_ena", dp_lfsr_ena, 1'b0);
    check("dp_seed_load", dp_seed_load, 1'b1);
    check("dp_lane_id_mux", dp_lane_id_mux, 1'b0);
    check("dp_lane_id", dp_lane_id, 8'ha7);

    // RO fields report the replica, not the all-ones write above.
    pll_bwcnt = 10'h2a5;
    pll_maxovershoot = 6'h13;
    pll_bwvalid = 1'b0;
    read_reg(rd);
    check("pll_bwcnt", rd[13:4], 10'h2a5);
    check("pll_maxovershoot", rd[19:14], 6'h13);
    check("pll_bwvalid", rd[20], 1'b0);

    // RW fields read back; the read scans above did not disturb them.
    wr[13:4]  = 10'h2a5;
    wr[19:14] = 6'h13;
    wr[20]    = 1'b0;
    check("full readback", rd, wr);
    check("dp_lane_id after read", dp_lane_id, 8'ha7);

    // Slow signals do not depend on the mode.
    wr[2:0] = 3'd0;
    write_reg(wr);
    check("rx_en_vref mode 0", rx_en_vref, 20'h3c5a1);
    check("dp_lfsr_seed mode 0", dp_lfsr_seed, 23'h2bcdef);

    // jtag_nRst keeps committed controls; reset_n clears them.
    jtag_nRst = 1'b0;
    #20 jtag_nRst = 1'b1;
    #40 check("dp_data_in after jtag_nRst", dp_data_in, 32'hdeadbeef);
    reset_n = 1'b0;
    #20 reset_n = 1'b1;
    #40 check("dp_data_in after reset_n", dp_data_in, '0);
    check("fast_in_sel after reset_n", fast_in_sel, 3'b000);

    if (errors != 0) $fatal(1, "jtagControlReplicas_tb: %0d errors", errors);
    $display("jtagControlReplicas_tb: PASS");
    $finish;
  end
endmodule
