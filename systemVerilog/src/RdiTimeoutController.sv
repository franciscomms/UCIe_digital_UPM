// Hand-translated synthesizable SystemVerilog.
// Source: RdiTimeoutController(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

module RdiTimeoutController (
  input  wire logic        clock,
  input  wire logic        reset_n,

  input  wire logic [31:0] cycles1us,
  // Suppress request-timeout errors; recovery/stall timers remain operational.
  input  wire logic        timeout_disable,

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
  logic configReady;
  logic [43:0] configuredLast4ms;
  logic [44:0] configuredLast8ms;
  logic [45:0] configuredLast16ms;
  logic [43:0] unusedTimeout4ms;
  logic [44:0] unusedTimeout8ms;
  logic [45:0] unusedTimeout16ms;
  LinkMgmtTimeoutConfig timeoutConfig (
    .clock(clock), .reset_n(reset_n), .cycles_1us(cycles1us),
    .config_ready(configReady),
    .timeout_4ms(unusedTimeout4ms), .timeout_8ms(unusedTimeout8ms),
    .timeout_16ms(unusedTimeout16ms),
    .last_4ms(configuredLast4ms), .last_8ms(configuredLast8ms),
    .last_16ms(configuredLast16ms)
  );

  // Each interval owns a stable threshold. Configuration changes affect the
  // next start/restart, including a STALL response or re-enabling timeouts.
  logic [44:0] sbLast;
  logic [43:0] stallLast;
  logic [45:0] linkErrorLast;
  logic sbLimitValid, stallLimitValid, linkErrorLimitValid;

  (* keep = "true" *) logic        sbBusy;
  (* keep = "true" *) logic [44:0] sbCounter;
  (* keep = "true" *) logic        sbTimeoutFlag;

  (* keep = "true" *) logic [43:0] stallCounter;
  (* keep = "true" *) logic        stallDue;

  (* keep = "true" *) logic [45:0] linkErrorCounter;
  (* keep = "true" *) logic        linkErrorDone;

  assign sidebandReqTimerBusy   = sbBusy;
  assign sidebandReqTimeoutFlag = sbTimeoutFlag && !timeout_disable;
  assign stallRefreshDue        = stallDue;
  assign linkErrorResidencyDone = linkErrorDone;

  always_ff @(negedge reset_n or posedge clock) begin
    if (!reset_n) begin
      sbBusy          <= 1'b0;
      sbCounter       <= 45'd0;
      sbTimeoutFlag   <= 1'b0;
      stallCounter    <= 44'd0;
      stallDue        <= 1'b0;
      linkErrorCounter <= 46'd0;
      linkErrorDone   <= 1'b0;
      sbLast <= 45'd0;
      stallLast <= 44'd0;
      linkErrorLast <= 46'd0;
      sbLimitValid <= 1'b0;
      stallLimitValid <= 1'b0;
      linkErrorLimitValid <= 1'b0;
    end else begin
      // This separate clear precedes the timer logic, matching the Chisel
      // connection priority: a timeout set below wins if both occur together.
      if (clearTimeoutFlag || timeout_disable)
        sbTimeoutFlag <= 1'b0;

      if (clearSidebandReqTimer || sidebandRspReceived) begin
        sbBusy    <= 1'b0;
        sbCounter <= 45'd0;
        sbLimitValid <= 1'b0;
      end else if (startSidebandReqTimer) begin
        sbBusy    <= 1'b1;
        sbCounter <= 45'd0;
        sbLast <= configuredLast8ms;
        sbLimitValid <= configReady && !timeout_disable;
      end else if (sbBusy && sidebandStallReceived) begin
        sbCounter <= 45'd0;
        sbLast <= configuredLast8ms;
        sbLimitValid <= configReady && !timeout_disable;
      end else if (sbBusy) begin
        if (timeout_disable) begin
          sbCounter <= 45'd0;
          sbLimitValid <= 1'b0;
        end else if (!sbLimitValid) begin
          // A request may precede configuration readiness after reset/update.
          // Its interval begins when a coherent threshold is available.
          if (configReady) begin
            sbLast <= configuredLast8ms;
            sbLimitValid <= 1'b1;
            if (configuredLast8ms == 45'd0) begin
              sbTimeoutFlag <= 1'b1;
              sbBusy <= 1'b0;
              sbCounter <= 45'd0;
            end else begin
              sbCounter <= 45'd1;
            end
          end
        end else if (sbCounter >= sbLast) begin
          sbTimeoutFlag <= 1'b1;
          sbBusy        <= 1'b0;
          sbCounter     <= 45'd0;
        end else begin
          sbCounter <= sbCounter + 45'd1;
        end
      end

      if (!stallResponseActive) begin
        stallCounter <= 44'd0;
        stallDue     <= 1'b0;
        stallLimitValid <= 1'b0;
      end else if (stallSent) begin
        stallCounter <= 44'd0;
        stallDue     <= 1'b0;
        stallLast <= configuredLast4ms;
        stallLimitValid <= configReady;
      end else if (!stallDue) begin
        if (!stallLimitValid) begin
          if (configReady) begin
            stallLast <= configuredLast4ms;
            stallLimitValid <= 1'b1;
            if (configuredLast4ms == 44'd0)
              stallDue <= 1'b1;
            else
              stallCounter <= 44'd1;
          end
        end else if (stallCounter >= stallLast) begin
          stallDue <= 1'b1;
        end else begin
          stallCounter <= stallCounter + 44'd1;
        end
      end

      if (!inLinkError) begin
        linkErrorCounter <= 46'd0;
        linkErrorDone    <= 1'b0;
        linkErrorLimitValid <= 1'b0;
      end else if (!linkErrorDone) begin
        if (!linkErrorLimitValid) begin
          if (configReady) begin
            linkErrorLast <= configuredLast16ms;
            linkErrorLimitValid <= 1'b1;
            if (configuredLast16ms == 46'd0)
              linkErrorDone <= 1'b1;
            else
              linkErrorCounter <= 46'd1;
          end
        end else if (linkErrorCounter >= linkErrorLast) begin
          linkErrorDone <= 1'b1;
        end else begin
          linkErrorCounter <= linkErrorCounter + 46'd1;
        end
      end
    end
  end
endmodule

`default_nettype wire
