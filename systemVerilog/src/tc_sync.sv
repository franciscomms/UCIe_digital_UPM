`default_nettype none

// ============================================================================
// tc_sync
// Generic multi-flop synchronizer, same interface as tc_sync in the PULP
// tech_cells_generic library (used by jtag_tdr_snapshot). Behavioural model:
// replace with the technology synchronizer cell for synthesis.
// ============================================================================
module tc_sync #(
  parameter int unsigned Stages     = 2,
  parameter bit          ResetValue = 1'b0
) (
  input  wire logic clk_i,
  input  wire logic rst_ni,
  input  wire logic serial_i,
  output var  logic serial_o
);

  logic [Stages-1:0] reg_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) reg_q <= {Stages{ResetValue}};
    else         reg_q <= {reg_q[Stages-2:0], serial_i};
  end

  assign serial_o = reg_q[Stages-1];

endmodule

`default_nettype wire
