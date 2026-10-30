`timescale 1ns/1ps
`default_nettype none

// Nondefault seven-point, three-lane configuration: an undersized window
// forces a retry, then equal-length windows must choose the first midpoint.
module RxDeskewPipelineSpec_tb;
  logic clock = 1'b0;
  always #5 clock = ~clock;
  logic reset_n = 1'b0, start = 1'b0;
  logic busy, done, trainError, apply, applied = 1'b0, pointStart;
  logic pointDone = 1'b0;
  logic [2:0] pointPass = '0;
  logic [3:0] state;
  logic [59:0] codes, selected, leftCodes, rightCodes;
  logic [15:0] failedCount, retries;

  MBTrain_RxDeskewSweepEngine #(
    .DATA_LANE_COUNT(3), .ACTIVE_DATA_LANE_MASK(3'b101),
    .RX_DESKEW_VALUE_COUNT(7), .MIN_PASSING_WINDOW_VALUES(3),
    .MAX_TRAINING_RETRIES(1)
  ) dut (
    .clock(clock), .reset_n(reset_n), .start(start),
    .busy(busy), .done(done), .trainError(trainError),
    .apply_rx_lane_deskew(apply), .rx_lane_deskew_codes(codes),
    .rx_lane_deskew_applied(applied), .point_test_start(pointStart),
    .point_test_done(pointDone), .point_test_pass(pointPass),
    .state(state), .lastFailedLaneCount(failedCount), .retryCount(retries),
    .finalRxDeskewCodes(selected), .validWindowLeftCodes(leftCodes),
    .validWindowRightCodes(rightCodes)
  );

  function automatic logic [19:0] expectedCode(input int halfSteps);
    // All seven settings use only the first cell. Independent thermometer
    // expression checks that the preparation stage did not skip an index.
    return 20'((((1 << (halfSteps / 2)) - 1) << 1) | (halfSteps % 2));
  endfunction

  initial begin : regression
    int cycles, sweepCount, finalCount, startCount, prepCount, encodeCount;
    int applyWait, pointWait, step;
    logic [3:0] previousState;
    logic [59:0] heldCodes;
    cycles = 0;
    sweepCount = 0;
    finalCount = 0;
    startCount = 0;
    prepCount = 0;
    encodeCount = 0;
    applyWait = 0;
    pointWait = 0;
    previousState = '0;
    heldCodes = '0;
    repeat (2) @(negedge clock);
    reset_n = 1'b1;
    start = 1'b1;
    @(negedge clock);
    start = 1'b0;
    while (!done && !trainError) begin
      if (++cycles > 1000) $fatal(1, "Nondefault RXDESKEW pipeline timeout");
      if (!busy || codes[39:20] !== '0 || selected[39:20] !== '0 ||
          leftCodes[39:20] !== '0 || rightCodes[39:20] !== '0)
        $fatal(1, "Busy/inactive-lane contract failed");
      applied = 1'b0;
      pointDone = 1'b0;
      if (state == 4'ha) begin
        if (apply || pointStart || previousState == 4'ha)
          $fatal(1, "Sweep preparation must take exactly one silent cycle");
        prepCount++;
      end
      if (state == 4'hb) begin
        if (apply || pointStart || previousState != 4'h4 || retries != 1)
          $fatal(1, "Final encoding entered before a qualifying retry window");
        encodeCount++;
      end
      if (apply) begin
        if (state != previousState) begin
          heldCodes = codes;
          applyWait = 0;
          if (state == 4'h1) begin
            if (previousState != 4'ha)
              $fatal(1, "Sweep code did not pass through preparation");
            step = sweepCount % 7;
            if (codes[19:0] !== expectedCode(step) || codes[59:40] !== expectedCode(step))
              $fatal(1, "Nondefault sweep index skipped/reordered: %0d", step);
            sweepCount++;
          end else begin
            if (state != 4'h5 || previousState != 4'hb || sweepCount != 14)
              $fatal(1, "Final code applied before the successful full retry");
            finalCount++;
          end
        end
        if (codes !== heldCodes || pointStart)
          $fatal(1, "Registered code changed before acknowledgement");
        applied = ++applyWait >= ((sweepCount % 4) + 1);
      end
      if (pointStart) startCount++;
      if (state == 4'h3 || state == 4'h7) begin
        if (state != previousState) begin
          pointWait = 0;
          heldCodes = codes;
        end
        if (apply || pointStart || codes !== heldCodes)
          $fatal(1, "Control changed while waiting for a delayed result");
        if (state == 4'h3) begin
          step = (sweepCount - 1) % 7;
          pointPass[0] = (retries == 0) ? (step >= 2 && step <= 3) :
                                         (step >= 1 && step <= 3);
          pointPass[1] = 1'b0; // Inactive failures must be ignored.
          pointPass[2] = (retries == 0) || (step <= 2 || step >= 4);
        end else pointPass = 3'b101;
        pointDone = ++pointWait >= ((sweepCount % 3) + 1);
      end
      previousState = state;
      @(negedge clock);
    end
    if (!done || trainError || busy || retries != 1 || failedCount != 5 ||
        sweepCount != 14 || finalCount != 1 || startCount != 15 ||
        prepCount != 14 || encodeCount != 1)
      $fatal(1, "Nondefault minimum-window retry/pipeline accounting failed");
    if (selected !== {expectedCode(1), 20'b0, expectedCode(2)} ||
        leftCodes !== {expectedCode(0), 20'b0, expectedCode(1)} ||
        rightCodes !== {expectedCode(2), 20'b0, expectedCode(3)})
      $fatal(1, "Nondefault midpoint/endpoints or equal-window tie failed");
    $display("PASS RxDeskewPipelineSpec_tb: nondefault count/minimum, inactive lane, undersized-window retry, tie, registered codes and variable stalls");
    $finish;
  end
endmodule

`default_nettype wire
