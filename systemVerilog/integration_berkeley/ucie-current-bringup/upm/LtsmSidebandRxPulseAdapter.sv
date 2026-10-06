// Synthesizable compatibility adapter from valid/ready RX to a one-cycle LTSM pulse.
// Reset convention: asynchronous active-low reset_n.

`default_nettype none

module LtsmSidebandRxPulseAdapter (
  input  wire logic         clock,
  input  wire logic         reset_n,

  input  wire logic         in_valid,
  input  wire logic [127:0] in_msg,
  output var  logic         in_ready,

  output var  logic         out_valid,
  output var  logic [127:0] out_msg
);
  typedef enum logic [1:0] {
    RxState_Idle  = 2'd0,
    RxState_Pulse = 2'd1,
    RxState_Gap   = 2'd2
  } RxState_t;

  (* keep = "true" *) RxState_t     state;
  (* keep = "true" *) logic [127:0] msgReg;

  always_comb begin
    in_ready = (state == RxState_Idle);
    out_valid = (state == RxState_Pulse);
    out_msg = msgReg;
  end

  always_ff @(posedge clock or negedge reset_n) begin
    if (!reset_n) begin
      state  <= RxState_Idle;
      msgReg <= 128'b0;
    end else begin
      case (state)
        RxState_Idle: begin
          if (in_valid && in_ready) begin
            msgReg <= in_msg;
            state  <= RxState_Pulse;
          end
        end

        RxState_Pulse: begin
          state <= RxState_Gap;
        end

        RxState_Gap: begin
          state <= RxState_Idle;
        end

        default: begin
          state  <= RxState_Idle;
          msgReg <= 128'b0;
        end
      endcase
    end
  end
endmodule

`default_nettype wire
