// Hand-translated synthesizable SystemVerilog.
// Source: StallController(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module StallCtrl (
  input  wire logic clock,
  input  wire logic reset_n,

  input  wire logic start,
  input  wire logic release_i,
  input  wire logic ack,

  output var logic req,
  output var logic aligned,
  output var logic done,
  output var logic busy
);
  typedef enum logic [1:0] {
    StallState_Idle        = 2'd0,
    StallState_WaitAckRise = 2'd1,
    StallState_StalledHold = 2'd2,
    StallState_WaitAckFall = 2'd3
  } StallState_t;

  (* keep = "true" *) StallState_t st;
  StallState_t st_next;

  always_comb begin
    st_next = st;
    req     = 1'b0;
    aligned = 1'b0;
    done    = 1'b0;
    busy    = (st != StallState_Idle);

    case (st)
      StallState_Idle: begin
        if (start && !ack)
          st_next = StallState_WaitAckRise;
      end

      StallState_WaitAckRise: begin
        req = 1'b1;
        if (ack)
          st_next = StallState_StalledHold;
      end

      StallState_StalledHold: begin
        req     = 1'b1;
        aligned = 1'b1;
        if (release_i && ack)
          st_next = StallState_WaitAckFall;
      end

      StallState_WaitAckFall: begin
        if (!ack) begin
          done    = 1'b1;
          st_next = StallState_Idle;
        end
      end

      default: st_next = StallState_Idle;
    endcase
  end

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      st <= StallState_Idle;
    end else begin
      st <= st_next;
    end
  end
endmodule

`default_nettype wire
