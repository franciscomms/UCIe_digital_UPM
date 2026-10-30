`timescale 1ns/1ps

// Standalone mailbox regression. The system TAP/scan sequencing is exercised
// separately; these directed cases target clock-domain and reset boundaries.
module JtagSnapshotSpec_tb;
  localparam int DATA_W = 8;
  localparam logic [DATA_W-1:0] RESET_VALUE = 8'ha6;
  logic clk = 1'b0;
  logic run_clk = 1'b1;
  logic nRst = 1'b0;
  logic jtag_nRst = 1'b0;
  logic tdr_tck = 1'b0;
  logic tdr_rst = 1'b0;
  logic tdr_tdi = 1'b0;
  logic tdr_capture = 1'b0;
  logic tdr_shift = 1'b0;
  logic tdr_update = 1'b0;
  logic sel = 1'b1;
  logic tdo;
  logic [DATA_W-1:0] data_in, data_out;
  logic data_out_valid;
  logic [DATA_W-1:0] sensor = 8'h5a;
  integer write_count = 0;
  integer tck_half_ns = 2;
  initial begin
    if ($value$plusargs("TCK_HALF_NS=%d", tck_half_ns)) begin end
    if (tck_half_ns < 1) $fatal(1, "TCK_HALF_NS must be positive");
  end
  logic previous_valid = 1'b0;

  always #5 if (run_clk) clk = ~clk;
  assign data_in = data_out ^ sensor;

  jtag_tdr_snapshot #(.DATA_W(DATA_W), .RESET_VALUE(RESET_VALUE)) dut (.*);

  always @(posedge clk or negedge nRst or negedge jtag_nRst) begin
    if (!nRst || !jtag_nRst) begin
      previous_valid = 1'b0;
    end else begin
      if (data_out_valid) begin
        if (previous_valid) $fatal(1, "write-valid lasted more than one core cycle");
        write_count = write_count + 1;
      end
      previous_valid = data_out_valid;
    end
  end

  task automatic tick(input bit cap, input bit shift, input bit upd, input bit di);
    tdr_capture = cap;
    tdr_shift = shift;
    tdr_update = upd;
    tdr_tdi = di;
    #(tck_half_ns);
    tdr_tck = 1'b1;
    #1;
    tdr_tck = 1'b0;
    #(tck_half_ns);
    tdr_capture = 1'b0;
    tdr_shift = 1'b0;
    tdr_update = 1'b0;
  endtask

  task automatic idle(input int cycles);
    repeat (cycles) tick(0, 0, 0, 0);
  endtask

  task automatic scan(input logic [DATA_W:0] tx,
                      output logic [DATA_W:0] rx,
                      input bit do_update = 1'b1);
    tick(1, 0, 0, 0);
    for (int i = 0; i <= DATA_W; i++) begin
      rx[i] = tdo;
      tick(0, 1, 0, tx[i]);
    end
    tick(0, 0, do_update, 0);
  endtask

  task automatic complete;
    int limit;
    limit = 0;
    while (dut.busy && limit < 200) begin
      idle(1);
      limit++;
    end
    if (dut.busy) $fatal(1, "mailbox did not complete");
    idle(2); // Also consume the synchronized acknowledge edge.
  endtask

  task automatic write_word(input logic [DATA_W-1:0] value);
    logic [DATA_W:0] ignored;
    scan({value, 1'b1}, ignored);
    complete();
  endtask

  task automatic check_snapshot(input logic [DATA_W-1:0] expected);
    logic [DATA_W:0] rx;
    scan('0, rx, 1'b0);
    if (rx !== {expected, 1'b0})
      $fatal(1, "snapshot: expected %h, got %h", {expected, 1'b0}, rx);
  endtask

  task automatic functional_reset;
    @(negedge clk);
    #1 nRst = 1'b0;
    idle(4);
    nRst = 1'b1;
    idle(20);
  endtask

  task automatic stop_core;
    @(negedge clk);
    run_clk = 1'b0;
  endtask

  initial begin : regression
    logic [DATA_W:0] rx;
    logic [DATA_W-1:0] retained;
    integer count_before;
    #21;
    nRst = 1'b1;
    jtag_nRst = 1'b1;
    idle(3);
    if (data_out !== RESET_VALUE) $fatal(1, "incorrect reset value");

    count_before = write_count;
    write_word(8'h3c);
    if (data_out !== 8'h3c || write_count != count_before + 1)
      $fatal(1, "write did not apply exactly once");
    check_snapshot(8'h3c ^ sensor);

    sensor = 8'h96;
    count_before = write_count;
    scan('0, rx); // Read-only Update-DR launches a fresh snapshot.
    complete();
    check_snapshot(8'h3c ^ sensor);
    if (write_count != count_before || data_out !== 8'h3c)
      $fatal(1, "read-only transaction wrote control data");

    // Deselected capture/shift/update must not touch this TDR.
    idle(2);
    sel = 1'b0;
    scan({8'hff, 1'b1}, rx);
    idle(20);
    if (dut.busy || data_out !== 8'h3c || write_count != count_before)
      $fatal(1, "deselected TDR accepted a transaction");
    sel = 1'b1;

    // Both completed request parities must survive an IP-only reset without
    // replay. The original RTL replayed the last write for parity one.
    for (int parity = 1; parity <= 2; parity++) begin
      functional_reset();
      for (int j = 0; j < parity; j++) write_word(8'h20 + 8'(j));
      if (dut.req_toggle_q !== 1'(parity)) $fatal(1, "wrong test parity");
      count_before = write_count;
      functional_reset();
      if (data_out !== RESET_VALUE || write_count != count_before || dut.busy)
        $fatal(1, "IP-only reset replayed a completed write (parity %0d)", parity);
    end

    // TRST resets mailbox state, preserving already committed control data.
    for (int parity = 1; parity <= 2; parity++) begin
      functional_reset();
      for (int j = 0; j < parity; j++) write_word(8'h40 + 8'(j));
      retained = data_out;
      count_before = write_count;
      #1 jtag_nRst = 1'b0;
      idle(4);
      jtag_nRst = 1'b1;
      idle(20);
      if (data_out !== retained || write_count != count_before || dut.busy)
        $fatal(1, "TRST corrupted/replayed committed control (parity %0d)", parity);
    end

    // A stopped IP clock makes busy deterministic even with many scan clocks.
    // TLR must neither cancel nor replay the accepted transaction. The second
    // Update-DR occurs while busy and must be ignored (one warning expected).
    stop_core();
    count_before = write_count;
    scan({8'ha5, 1'b1}, rx);
    if (!dut.busy) $fatal(1, "expected pending write with stopped IP clock");
    tdr_rst = 1'b1;
    idle(3);
    tick(0, 0, 1, 0); // TLR suppresses even a malformed update request.
    if (!dut.busy) $fatal(1, "TLR discarded the pending handshake");
    tdr_rst = 1'b0;
    scan({8'hb4, 1'b1}, rx);
    if (!rx[0]) $fatal(1, "Capture-DR did not report busy");
    run_clk = 1'b1;
    // Keep TLR asserted while the original request finishes in the core.
    tdr_rst = 1'b1;
    idle(20);
    tdr_rst = 1'b0;
    complete();
    if (data_out !== 8'ha5 || write_count != count_before + 1)
      $fatal(1, "TLR/busy handling duplicated or replaced the original write");
    check_snapshot(8'ha5 ^ sensor);

    // TRST cancels an uncommitted request without affecting committed data.
    stop_core();
    retained = data_out;
    count_before = write_count;
    scan({8'hc3, 1'b1}, rx);
    #1 jtag_nRst = 1'b0;
    idle(4);
    jtag_nRst = 1'b1;
    run_clk = 1'b1;
    idle(20);
    if (data_out !== retained || write_count != count_before || dut.busy)
      $fatal(1, "TRST failed to cancel an uncommitted write");

    // IP reset cancels a pending request and restores the reset value.
    stop_core();
    count_before = write_count;
    scan({8'hd2, 1'b1}, rx);
    #1 nRst = 1'b0;
    idle(4);
    nRst = 1'b1;
    run_clk = 1'b1;
    idle(20);
    if (data_out !== RESET_VALUE || write_count != count_before || dut.busy)
      $fatal(1, "IP reset failed to cancel a pending write");

    // Stop TCK after Update-DR, let the IP acknowledge, then bring the
    // acknowledgement through exactly two synchronizer clocks. Capture on
    // the acknowledge-edge cycle must get the NEW snapshot, not rd_data_q.
    count_before = write_count;
    scan({8'h1d, 1'b1}, rx);
    repeat (8) @(posedge clk);
    #1;
    idle(2);
    if (!dut.ack_edge) $fatal(1, "test did not align Capture with acknowledge edge");
    check_snapshot(8'h1d ^ sensor);
    if (write_count != count_before + 1)
      $fatal(1, "acknowledge coincidence test changed write count");

    $display("PASS JtagSnapshotSpec_tb (TCK period %0d ns, core period 10 ns): snapshots, write pulses, busy, TLR, independent resets, acknowledge coincidence", 2*tck_half_ns+1);
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "JtagSnapshotSpec_tb timeout");
  end
endmodule
