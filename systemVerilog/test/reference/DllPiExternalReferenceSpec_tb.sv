// Optional: requires the separately supplied dll_pi_control golden RTL.
`timescale 1ns/1ps
`default_nettype none

// The supplied reference decoder is kept unchanged under reference_dll_pi.
// Expected words below are computed independently from physical bank weights.
module DllPiExternalReferenceSpec_tb;
  logic clock = 0;
  always #5 clock = ~clock;
  logic reset_n = 0, update = 0;
  logic [2:0] sector;
  logic [5:0] step;
  wire s0, s1, s2, s3, invert, applied, error;
  wire [16:0] upper_en, lower_en;
  wire [2:0] active_sector;
  wire [5:0] active_step, raw_code;
  logic [37:0] last_word, seen [0:263];
  int commands = 0, encoding_checks = 0;
  dll_pi_control reference_dut (
    .ctrl_clk(clock), .rst_n(reset_n), .update_en(update),
    .sector_req(sector), .delay_step_req(step),
    .s0(s0), .s1(s1), .s2(s2), .s3(s3),
    .upper_en(upper_en), .lower_en(lower_en),
    .sector_active(active_sector), .delay_step_active(active_step),
    .pi_code_active(raw_code), .invert_active(invert),
    .update_applied(applied), .request_error(error)
  );

  function automatic logic [37:0] expected(input int sec, input int delay);
    logic [16:0] later, upper, lower;
    logic [1:0] upper_mux, lower_mux;
    later = '0;
    later[0] = 1'(delay % 2);
    for (int switch_index = 0; switch_index < 16; switch_index++)
      later[switch_index+1] = switch_index < delay/2;
    upper_mux = 2'((sec+1)/2);
    lower_mux = 2'(sec/2);
    upper = sec % 2 ? later : ~later;
    lower = ~upper;
    return {lower, upper, lower_mux, upper_mux};
  endfunction

  function automatic int weight(input logic [16:0] bank);
    int result;
    result = int'(bank[0]);
    for (int bit_index = 1; bit_index < 17; bit_index++)
      result += 2*int'(bank[bit_index]);
    return result;
  endfunction

  function automatic int physical_phase(input logic [37:0] word);
    int upper_coordinate, lower_coordinate;
    upper_coordinate = int'(word[1:0])*66;
    lower_coordinate = int'(word[3:2])*66+33;
    // The upper CLK0 input is the next-cycle endpoint beside lower CLK315.
    if(word[1:0]==0 && word[3:2]==3) upper_coordinate=264;
    return ((upper_coordinate*weight(word[20:4]) +
             lower_coordinate*weight(word[37:21]))/33)%264;
  endfunction

  initial begin
    sector = 0;
    step = 0;
    @(negedge clock);
    if ({lower_en,upper_en,s3,s2,s1,s0} !== expected(0,0))
      $fatal(1,"Reference RTL reset is not sector0/step0");
    reset_n = 1;
    for (int sec = 0; sec < 8; sec++) begin
      for (int delay = 0; delay <= 33; delay++) begin
        sector = 3'(sec);
        step = 6'(delay);
        update = 1;
        @(negedge clock);
        if ({lower_en,upper_en,s3,s2,s1,s0} !== expected(sec,delay) ||
            !applied || error || active_sector != sec || active_step != delay ||
            raw_code != 33-delay || invert != (sec%2 == 0))
          $fatal(1,"Reference command mismatch sector=%0d step=%0d",sec,delay);
        if (lower_en !== ~upper_en || weight(lower_en)+weight(upper_en) != 33 ||
            (sec%2 ? weight(upper_en) : weight(lower_en)) != delay)
          $fatal(1,"Bank complement/weight/order mismatch");
        if(physical_phase({lower_en,upper_en,s3,s2,s1,s0}) != (sec*33+delay)%264)
          $fatal(1,"Decoded physical phase/wrap mismatch sector=%0d step=%0d",sec,delay);
        commands++;
        if (delay < 33) begin
          int phase;
          logic [37:0] encoded;
          phase = sec*33 + delay;
          encoded = LtsmParameters_pkg::encode_d2c_phase(9'(phase));
          if (encoded !== expected(sec,delay) || encoded !== {lower_en,upper_en,s3,s2,s1,s0})
            $fatal(1,"Production/reference mismatch phase=%0d code=%h",phase,encoded);
          for (int previous = 0; previous < phase; previous++)
            if (encoded == seen[previous]) $fatal(1,"Duplicate phase word %0d/%0d",phase,previous);
          seen[phase] = encoded;
          encoding_checks++;
        end else begin
          // Endpoint sec/33 and next-sector/0 select the same clock phase,
          // although the unused mux and enabled-bank orientation may differ.
          if (physical_phase({lower_en,upper_en,s3,s2,s1,s0}) !=
              physical_phase(expected((sec+1)%8,0)))
            $fatal(1,"Endpoint coordinate mismatch");
        end
      end
    end
    last_word = {lower_en,upper_en,s3,s2,s1,s0};
    for (int delay = 34; delay < 64; delay++) begin
      step = 6'(delay);
      @(negedge clock);
      if (!error || applied || {lower_en,upper_en,s3,s2,s1,s0} !== last_word)
        $fatal(1,"Reference invalid command changed active controls");
    end
    update = 0;
    @(negedge clock);
    if (error || applied || {lower_en,upper_en,s3,s2,s1,s0} !== last_word)
      $fatal(1,"Reference inactive-update hold failed");
    for (int invalid_phase = 264; invalid_phase < 512; invalid_phase++)
      if (LtsmParameters_pkg::encode_d2c_phase(9'(invalid_phase)) !== expected(0,0))
        $fatal(1,"Invalid phase index did not select deterministic phase0 fallback");
    if (commands != 272 || encoding_checks != 264)
      $fatal(1,"Exhaustive coverage incomplete");
    $display("PASS DllPiEncodingSpec_tb: 272 reference commands, 264 unique production phases, invalid-command hold");
    $finish;
  end
endmodule

`default_nettype wire
