`timescale 1ns/1ps
`default_nettype none

// Self-contained contract test; no absent analog reference RTL is required.
// Check the physical mux coordinates and weighted switch banks independently
// of the production encoder's thermometer loop. The original optional
// comparison with dll_pi_control is retained under test/reference/.
module DllPiEncodingSpec_tb;
  logic [37:0] seen [0:263];
  logic clock = 1'b0;
  always #5 clock = ~clock;
  logic reset_n = 1'b0;
  logic [8:0] phase_index = '0;
  wire [37:0] pipeline_code;
  wire [8:0] pipeline_index;
  wire pipeline_valid;
  logic expected_valid = 1'b0;
  logic [8:0] expected_index = '0;
  logic [511:0] pipeline_seen = '0;
  int pipeline_checks = 0;

  MBTrain_DllPiEncoder pipeline (
    .clock(clock), .reset_n(reset_n), .phase_index(phase_index),
    .phase_code(pipeline_code), .phase_index_out(pipeline_index),
    .valid(pipeline_valid)
  );

  // The input crosses two register boundaries: stage 2 must publish the
  // previous rising edge's index, including its unchanged invalid-index tag.
  // Changing the requested index every cycle catches stale/bank/tag mixtures.
  always @(posedge clock) begin
    if (!reset_n) begin
      expected_valid = 1'b0;
      expected_index = '0;
      #1;
      if (pipeline_valid !== 1'b0 || pipeline_code !== 38'h00001ffff0)
        $fatal(1, "DLL/PI pipeline reset did not clear valid and select phase zero");
    end else begin
      #1;
      if (pipeline_valid !== expected_valid)
        $fatal(1, "DLL/PI pipeline valid latency mismatch");
      if (expected_valid) begin
        if (pipeline_index !== expected_index ||
            pipeline_code !== LtsmParameters_pkg::encode_d2c_phase(expected_index))
          $fatal(1, "DLL/PI pipeline code/tag mismatch expected=%0d actual=%0d code=%h",
            expected_index, pipeline_index, pipeline_code);
        pipeline_seen[expected_index] = 1'b1;
        pipeline_checks++;
      end
      expected_valid = 1'b1;
      expected_index = phase_index;
    end
  end

  task automatic drive_index(input int index);
    @(negedge clock);
    phase_index = 9'(index);
  endtask

  function automatic int weight(input logic [16:0] bank);
    return int'(bank[0]) + 2*$countones(bank[16:1]);
  endfunction

  function automatic bit thermometer(input logic [15:0] bits);
    // Legal coarse masks are zero or a contiguous run of ones at the LSB.
    return (bits & (bits + 16'd1)) == 0;
  endfunction

  initial begin
    logic [37:0] code;
    logic [16:0] upper, lower;
    int sec, step, upper_coordinate, lower_coordinate, physical_phase;
    if (LtsmParameters_pkg::DEFAULT_D2C_PI_CODE_WIDTH != 38)
      $fatal(1, "DLL/PI physical word must have 38 bits");
    for (int phase = 0; phase < 264; phase++) begin
      sec = phase / 33;
      step = phase % 33;
      code = LtsmParameters_pkg::encode_d2c_phase(9'(phase));
      upper = code[20:4];
      lower = code[37:21];
      if (lower !== ~upper || weight(lower) + weight(upper) != 33)
        $fatal(1, "Bank complement/weight mismatch at phase %0d", phase);
      if (code[1:0] != 2'((sec+1)/2) || code[3:2] != 2'(sec/2))
        $fatal(1, "Wrong clock source at phase %0d", phase);
      if (sec % 2) begin
        if (!thermometer(upper[16:1]) || weight(upper) != step)
          $fatal(1, "Odd-sector switch ordering/weight mismatch at %0d", phase);
      end else if (!thermometer(lower[16:1]) || weight(lower) != step)
        $fatal(1, "Even-sector switch ordering/weight mismatch at %0d", phase);
      upper_coordinate = int'(code[1:0])*66;
      lower_coordinate = int'(code[3:2])*66 + 33;
      if (code[1:0] == 0 && code[3:2] == 3) upper_coordinate = 264;
      physical_phase = ((upper_coordinate*weight(upper) +
                         lower_coordinate*weight(lower))/33) % 264;
      if (physical_phase != phase)
        $fatal(1, "Decoded phase mismatch: requested=%0d decoded=%0d", phase, physical_phase);
      for (int previous = 0; previous < phase; previous++)
        if (code === seen[previous]) $fatal(1, "Duplicate phases %0d/%0d", previous, phase);
      seen[phase] = code;
    end
    // Literal phase-zero controls: all upper switches on, both muxes zero.
    for (int invalid_phase = 264; invalid_phase < 512; invalid_phase++)
      if (LtsmParameters_pkg::encode_d2c_phase(9'(invalid_phase)) !== 38'h00001ffff0)
        $fatal(1, "Invalid phase %0d did not select phase zero", invalid_phase);
    @(negedge clock);
    reset_n = 1'b1;
    for (int index = 0; index < 512; index++) drive_index(index);
    repeat (2) @(negedge clock);
    if (pipeline_seen !== '1)
      $fatal(1, "DLL/PI pipeline did not exercise all 512 input indices");

    // Abort a partially filled pipeline, then cross multiple sector boundaries
    // in consecutive cycles to verify fresh tags after reset release.
    drive_index(263);
    drive_index(17);
    #2 reset_n = 1'b0;
    #1;
    if (pipeline_valid !== 1'b0 || pipeline_code !== 38'h00001ffff0)
      $fatal(1, "DLL/PI pipeline asynchronous reset did not discard in-flight output");
    repeat (2) @(negedge clock);
    reset_n = 1'b1;
    phase_index = 9'd33;
    drive_index(263);
    drive_index(66);
    drive_index(511);
    drive_index(0);
    repeat (2) @(negedge clock);
    $display("PASS DllPiEncodingSpec_tb: 264 unique physical phases, 248 invalid-index fallbacks, %0d pipelined code/tag checks and reset",pipeline_checks);
    $finish;
  end
endmodule

`default_nettype wire
