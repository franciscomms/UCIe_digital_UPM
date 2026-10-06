// Synthesizable compatibility adapter for the LinkTrainingFSM TX pulse interface.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LtsmSidebandTxCapture #(
  parameter int unsigned ENTRIES = 4
) (
  input  wire logic         clock,
  input  wire logic         reset_n,

  input  wire logic         raw_valid,
  input  wire logic [127:0] raw_msg,
  output var  logic         raw_ready,

  output var  logic         out_valid,
  output var  logic [127:0] out_msg,
  input  wire logic         out_ready
);
  localparam int unsigned PTR_WIDTH   = (ENTRIES <= 2) ? 1 : $clog2(ENTRIES);
  localparam int unsigned COUNT_WIDTH = (ENTRIES < 2) ? 1 : $clog2(ENTRIES + 1);

  logic [127:0] queue_mem [0:ENTRIES-1];
  (* keep = "true" *) logic [PTR_WIDTH-1:0]   enq_ptr;
  (* keep = "true" *) logic [PTR_WIDTH-1:0]   deq_ptr;
  (* keep = "true" *) logic [COUNT_WIDTH-1:0] count;

  logic queue_enq_ready;
  logic enq_fire;
  logic deq_fire;

  function automatic logic [PTR_WIDTH-1:0] increment_ptr(
    input logic [PTR_WIDTH-1:0] ptr
  );
    if (ptr == ENTRIES - 1)
      increment_ptr = '0;
    else
      increment_ptr = ptr + 1'b1;
  endfunction

  // Reserve one entry for a pulse that the LTSM may generate on the cycle
  // after it sampled raw_ready high.
  always_comb begin
    raw_ready       = (count <= (ENTRIES - 2));
    queue_enq_ready = (count < ENTRIES);
    out_valid       = (count != 0);
    out_msg         = queue_mem[deq_ptr];
    enq_fire        = raw_valid && queue_enq_ready;
    deq_fire        = out_valid && out_ready;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      enq_ptr <= '0;
      deq_ptr <= '0;
      count   <= '0;
    end else begin
      if (enq_fire) begin
        queue_mem[enq_ptr] <= raw_msg;
        enq_ptr            <= increment_ptr(enq_ptr);
      end

      if (deq_fire)
        deq_ptr <= increment_ptr(deq_ptr);

      case ({enq_fire, deq_fire})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

`ifndef SYNTHESIS
  initial begin
    if (ENTRIES < 2)
      $fatal(1, "LtsmSidebandTxCapture ENTRIES must be at least 2");
  end

  always @(posedge clock) begin
    if (reset_n && raw_valid && !queue_enq_ready)
      $error("LTSM TX pulse arrived while the compatibility queue was full");
  end
`endif
endmodule

`default_nettype wire
