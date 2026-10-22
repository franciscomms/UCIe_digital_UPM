`default_nettype none

// Prepare programmable timeouts outside the active timer comparison path.
// 4000 = 125 << 5, 8000 = 125 << 6, 16000 = 125 << 7,
// and 125*x = 128*x - 3*x. Each arithmetic operation has its own register
// boundary. Full unsigned 32-bit cycles_1us values are supported without
// overflow. Configuration and outputs are synchronous to clock.
module LinkMgmtTimeoutConfig (
  input  wire logic        clock,
  input  wire logic        reset_n,
  input  wire logic [31:0] cycles_1us,
  output wire logic        config_ready,
  output wire logic [43:0] timeout_4ms,
  output wire logic [44:0] timeout_8ms,
  output wire logic [45:0] timeout_16ms,
  output wire logic [43:0] last_4ms,
  output wire logic [44:0] last_8ms,
  output wire logic [45:0] last_16ms
);
  logic [3:0] valid;
  logic [31:0] cycles_s0, cycles_s1, cycles_s2, cycles_s3;
  logic [33:0] triple_s1;
  logic [38:0] shifted_s1, base_s2, base_s3, base_last_s3;
  logic zero_s3;

  // A new value is usable after four sampling edges. A change immediately
  // deasserts ready until that exact value has traversed the pipeline.
  // Running timers keep their own latched limit and do not depend on ready.
  assign config_ready = valid[3] && (cycles_s3 == cycles_1us);
  assign timeout_4ms  = {base_s3, 5'b0};
  assign timeout_8ms  = {base_s3, 6'b0};
  assign timeout_16ms = {base_s3, 7'b0};
  assign last_4ms  = zero_s3 ? 44'd0 : {base_last_s3, 5'b11111};
  assign last_8ms  = zero_s3 ? 45'd0 : {base_last_s3, 6'b111111};
  assign last_16ms = zero_s3 ? 46'd0 : {base_last_s3, 7'b1111111};

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      valid <= 4'b0;
      cycles_s0 <= 32'd0;
      cycles_s1 <= 32'd0;
      cycles_s2 <= 32'd0;
      cycles_s3 <= 32'd0;
      triple_s1 <= 34'd0;
      shifted_s1 <= 39'd0;
      base_s2 <= 39'd0;
      base_s3 <= 39'd0;
      base_last_s3 <= 39'd0;
      zero_s3 <= 1'b1;
    end else begin
      valid <= {valid[2:0], 1'b1};
      cycles_s0 <= cycles_1us;
      cycles_s1 <= cycles_s0;
      cycles_s2 <= cycles_s1;
      cycles_s3 <= cycles_s2;
      triple_s1 <= {1'b0, cycles_s0, 1'b0} + {2'b0, cycles_s0};
      shifted_s1 <= {cycles_s0, 7'b0};
      base_s2 <= shifted_s1 - {5'b0, triple_s1};
      base_s3 <= base_s2;
      base_last_s3 <= (base_s2 == 39'd0) ? 39'd0 : base_s2 - 39'd1;
      zero_s3 <= (base_s2 == 39'd0);
    end
  end
endmodule

`default_nettype wire
