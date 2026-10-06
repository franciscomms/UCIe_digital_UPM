// Hand-translated synthesizable SystemVerilog.
// Source: RdiTimeoutController(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module RdiTimeoutController (
  input  wire logic        clock,
  input  wire logic        reset_n,

  input  wire logic [31:0] cycles1us,

  input  wire logic startSidebandReqTimer,
  input  wire logic sidebandRspReceived,
  input  wire logic sidebandStallReceived,
  input  wire logic clearSidebandReqTimer,

  output var logic sidebandReqTimerBusy,
  output var logic sidebandReqTimeoutFlag,
  input  wire logic clearTimeoutFlag,

  input  wire logic stallResponseActive,
  input  wire logic stallSent,
  output var logic stallRefreshDue,

  input  wire logic inLinkError,
  output var logic linkErrorResidencyDone
);
  logic [63:0] timeout4ms;
  logic [63:0] timeout8ms;
  logic [63:0] timeout16ms;

  assign timeout4ms  = {32'b0, cycles1us} * 64'd4000;
  assign timeout8ms  = {32'b0, cycles1us} * 64'd8000;
  assign timeout16ms = {32'b0, cycles1us} * 64'd16000;

  function automatic logic [63:0] lastCycle(input logic [63:0] limit);
    lastCycle = (limit == 64'd0) ? 64'd0 : (limit - 64'd1);
  endfunction

  (* keep = "true" *) logic        sbBusy;
  (* keep = "true" *) logic [63:0] sbCounter;
  (* keep = "true" *) logic        sbTimeoutFlag;

  (* keep = "true" *) logic [63:0] stallCounter;
  (* keep = "true" *) logic        stallDue;

  (* keep = "true" *) logic [63:0] linkErrorCounter;
  (* keep = "true" *) logic        linkErrorDone;

  assign sidebandReqTimerBusy   = sbBusy;
  assign sidebandReqTimeoutFlag = sbTimeoutFlag;
  assign stallRefreshDue        = stallDue;
  assign linkErrorResidencyDone = linkErrorDone;

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      sbBusy          <= 1'b0;
      sbCounter       <= 64'd0;
      sbTimeoutFlag   <= 1'b0;
      stallCounter    <= 64'd0;
      stallDue        <= 1'b0;
      linkErrorCounter <= 64'd0;
      linkErrorDone   <= 1'b0;
    end else begin
      // This separate clear precedes the timer logic, matching the Chisel
      // connection priority: a timeout set below wins if both occur together.
      if (clearTimeoutFlag)
        sbTimeoutFlag <= 1'b0;

      if (clearSidebandReqTimer || sidebandRspReceived) begin
        sbBusy    <= 1'b0;
        sbCounter <= 64'd0;
      end else if (startSidebandReqTimer) begin
        sbBusy    <= 1'b1;
        sbCounter <= 64'd0;
      end else if (sbBusy && sidebandStallReceived) begin
        sbCounter <= 64'd0;
      end else if (sbBusy) begin
        if (sbCounter >= lastCycle(timeout8ms)) begin
          sbTimeoutFlag <= 1'b1;
          sbBusy        <= 1'b0;
          sbCounter     <= 64'd0;
        end else begin
          sbCounter <= sbCounter + 64'd1;
        end
      end

      if (!stallResponseActive) begin
        stallCounter <= 64'd0;
        stallDue     <= 1'b0;
      end else if (stallSent) begin
        stallCounter <= 64'd0;
        stallDue     <= 1'b0;
      end else if (!stallDue) begin
        if (stallCounter >= lastCycle(timeout4ms)) begin
          stallDue <= 1'b1;
        end else begin
          stallCounter <= stallCounter + 64'd1;
        end
      end

      if (!inLinkError) begin
        linkErrorCounter <= 64'd0;
        linkErrorDone    <= 1'b0;
      end else if (!linkErrorDone) begin
        if (linkErrorCounter >= lastCycle(timeout16ms)) begin
          linkErrorDone <= 1'b1;
        end else begin
          linkErrorCounter <= linkErrorCounter + 64'd1;
        end
      end
    end
  end
endmodule

`default_nettype wire
