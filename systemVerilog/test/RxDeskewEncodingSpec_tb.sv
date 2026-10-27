`timescale 1ns/1ps
`default_nettype none

// Independent switch-word oracle plus directed RXDESKEW sweep/handshake tests.
module RxDeskewEncodingSpec_tb;
  logic clock = 1'b0;
  always #5 clock = ~clock;
  logic reset_n = 1'b0, start = 1'b0;
  logic busy, done, trainError, apply, applied = 1'b0, pointStart;
  logic pointDone = 1'b0;
  logic [3:0] pointPass = '0, state;
  logic [79:0] codes, selected, leftCodes, rightCodes;
  logic [15:0] failedCount, retries;

  MBTrain_RxDeskewSweepEngine #(
    .DATA_LANE_COUNT(4), .ACTIVE_DATA_LANE_MASK(4'b0111),
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

  // Each 10-bit cell is a fine bit followed by a low-to-high thermometer.
  // This expression is deliberately separate from the RTL bit-by-bit decoder.
  function automatic logic [19:0] expectedCode(input int halfSteps);
    int first, second, firstCoarse, secondCoarse;
    logic [9:0] firstWord, secondWord;
    if (halfSteps < 0 || halfSteps > 38)
      $fatal(1, "Invalid oracle input %0d", halfSteps);
    first = halfSteps > 19 ? 19 : halfSteps;
    second = halfSteps - first;
    firstCoarse = (1 << (first / 2)) - 1;
    secondCoarse = (1 << (second / 2)) - 1;
    firstWord = 10'((firstCoarse << 1) | (first % 2));
    secondWord = 10'((secondCoarse << 1) | (second % 2));
    return {secondWord, firstWord};
  endfunction

  function automatic int decode(input logic [19:0] value);
    for (int step = 0; step < 39; step++)
      if (value === expectedCode(step)) return step;
    $fatal(1, "Illegal RXDESKEW switch word %h", value);
    return -1;
  endfunction

  function automatic bit passAt(input int scenario, lane, step);
    if (scenario == 3) return 1'b0;
    if (scenario == 2) return 1'b1;
    if (scenario == 1) begin
      case (lane)
        0: return (step >= 2 && step <= 5) || (step >= 12 && step <= 15);
        1: return step == 38;
        default: return step == 0;
      endcase
    end
    case (lane)
      0: return step >= 17 && step <= 22;
      1: return step >= 35 && step <= 38;
      default: return step >= 0 && step <= 5;
    endcase
  endfunction

  task automatic checkWindow(input int lane, mid, lo, hi);
    if (selected[lane*20 +: 20] !== expectedCode(mid) ||
        leftCodes[lane*20 +: 20] !== expectedCode(lo) ||
        rightCodes[lane*20 +: 20] !== expectedCode(hi))
      $fatal(1, "Lane %0d window selected=%h left=%h right=%h; expected steps %0d/%0d/%0d",
        lane, selected[lane*20 +: 20], leftCodes[lane*20 +: 20],
        rightCodes[lane*20 +: 20], mid, lo, hi);
  endtask

  task automatic runScenario(input int scenario, input bit resetBefore = 1'b1,
                             input int applyDelay = 3, input int pointDelay = 2);
    int sweepCount, finalCount, pointCount, cycles, applyWait, pointWait;
    int prepareCount, encodeFinalCount;
    logic [3:0] previousState;
    logic [79:0] heldCodes, previousSelected, previousLeft, previousRight;
    prepareCount = 0;
    encodeFinalCount = 0;
    sweepCount = 0;
    finalCount = 0;
    pointCount = 0;
    cycles = 0;
    applyWait = 0;
    pointWait = 0;
    previousState = '0;
    heldCodes = '0;
    previousSelected = '0;
    previousLeft = '0;
    previousRight = '0;
    @(negedge clock);
    start = 1'b0;
    applied = 1'b0;
    pointDone = 1'b0;
    pointPass = '0;
    if (resetBefore) begin
      reset_n = 1'b0;
      @(negedge clock);
      if (codes !== '0 || selected !== '0 || leftCodes !== '0 || rightCodes !== '0)
        $fatal(1, "Reset must select the zero-delay word and clear endpoints");
      reset_n = 1'b1;
    end
    start = 1'b1;
    @(negedge clock);
    start = 1'b0;
    while (!(done || trainError)) begin
      if (++cycles > 3000) $fatal(1, "RXDESKEW scenario %0d timed out", scenario);
      if (!busy) $fatal(1, "Busy dropped before terminal state");
      // Every physical code application must pass through exactly one encode
      // stage. During final encoding, the registered result vectors still
      // hold their previous values: analysis has latched indices only.
      if (state == 4'ha) begin
        if (state == previousState || apply || pointStart)
          $fatal(1, "Invalid sweep preparation state/handshake");
        prepareCount++;
      end
      if (state == 4'hb) begin
        if (previousState != 4'h4 || apply || pointStart ||
            selected !== previousSelected || leftCodes !== previousLeft ||
            rightCodes !== previousRight)
          $fatal(1, "Final index analysis bypassed the encoding register boundary");
        encodeFinalCount++;
      end
      if (state == 4'h1 && previousState != 4'h1 && previousState != 4'ha)
        $fatal(1, "Sweep apply occurred without a preparation cycle");
      if (state == 4'h5 && previousState != 4'h5 && previousState != 4'hb)
        $fatal(1, "Final apply occurred without a separate encoding cycle");
      applied = 1'b0;
      pointDone = 1'b0;
      if (codes[60 +: 20] !== '0 || selected[60 +: 20] !== '0 ||
          leftCodes[60 +: 20] !== '0 || rightCodes[60 +: 20] !== '0)
        $fatal(1, "Inactive lane did not stay at zero delay");
      if (apply) begin
        if (state != previousState) begin
          heldCodes = codes;
          applyWait = 0;
          if (state == 4'h1) begin
            for (int lane = 0; lane < 3; lane++)
              if (codes[lane*20 +: 20] !== expectedCode(sweepCount % 39))
                $fatal(1, "Sweep skipped/reordered step %0d on lane %0d", sweepCount % 39, lane);
            sweepCount++;
          end else finalCount++;
        end
        if (codes !== heldCodes || pointStart)
          $fatal(1, "Control changed or point test started before apply acknowledgement");
        applied = ++applyWait >= applyDelay;
      end
      if (pointStart) pointCount++;
      if (state == 4'h3 || state == 4'h7) begin
        if (state != previousState) begin
          heldCodes = codes;
          pointWait = 0;
        end
        if (codes !== heldCodes || apply || pointStart)
          $fatal(1, "Code/handshake changed while waiting for point result");
        pointPass = '0;
        if (state == 4'h3) begin
          for (int lane = 0; lane < 3; lane++)
            pointPass[lane] = passAt(scenario, lane, decode(codes[lane*20 +: 20]));
        end else begin
          pointPass = ((scenario == 4 && finalCount == 1) || scenario == 5) ? 4'b0000 : 4'b0111;
        end
        pointDone = ++pointWait >= pointDelay;
      end
      previousState = state;
      previousSelected = selected;
      previousLeft = leftCodes;
      previousRight = rightCodes;
      @(negedge clock);
    end
    applied = 1'b0;
    pointDone = 1'b0;
    if (busy || (done && trainError)) $fatal(1, "Invalid terminal flags");
    if (scenario == 3) begin
      if (!trainError || done || retries != 1 || sweepCount != 78 || finalCount != 0 || failedCount != 117)
        $fatal(1, "No-window retry/exhaustion behavior failed");
    end else if (scenario == 5) begin
      if (!trainError || done || retries != 1 || sweepCount != 78 || finalCount != 2 || failedCount != 104)
        $fatal(1, "Final verification retry/exhaustion failed: errors=%0d", failedCount);
    end else begin
      if (!done || trainError || retries != (scenario == 4 ? 1 : 0) ||
          sweepCount != (scenario == 4 ? 78 : 39) || finalCount != (scenario == 4 ? 2 : 1))
        $fatal(1, "Passing sweep/verification counts failed");
      case (scenario)
        0, 4: begin
          checkWindow(0, 19, 17, 22);
          checkWindow(1, 36, 35, 38);
          checkWindow(2, 2, 0, 5);
        end
        1: begin
          checkWindow(0, 3, 2, 5);
          checkWindow(1, 38, 38, 38);
          checkWindow(2, 0, 0, 0);
        end
        2: begin
          for (int lane = 0; lane < 3; lane++) checkWindow(lane, 19, 0, 38);
        end
      endcase
    end
    if (prepareCount != sweepCount || encodeFinalCount != finalCount)
      $fatal(1, "Pipeline stage count mismatch: sweep %0d/%0d final %0d/%0d",
        prepareCount, sweepCount, encodeFinalCount, finalCount);
    if (pointCount != sweepCount + finalCount)
      $fatal(1, "Expected one point-test start per applied code");
    repeat (3) begin
      @(negedge clock);
      if (apply || pointStart || busy) $fatal(1, "Terminal state did not hold");
    end
    $display("PASS RXDESKEW scenario %0d: sweep=%0d final=%0d retry=%0d", scenario, sweepCount, finalCount, retries);
  endtask

  task automatic resetInPipeline(input logic [3:0] resetState);
    int cycles;
    @(negedge clock);
    start = 1'b1;
    applied = 1'b0;
    pointDone = 1'b0;
    @(negedge clock);
    start = 1'b0;
    cycles = 0;
    while (state != resetState) begin
      if (++cycles > 1000) $fatal(1, "Did not reach pipeline reset state %h", resetState);
      applied = apply;
      pointDone = (state == 4'h3 || state == 4'h7);
      pointPass = 4'b0111;
      @(negedge clock);
    end
    if (apply || pointStart) $fatal(1, "Pipeline reset target asserted a handshake");
    #1 reset_n = 1'b0;
    #1;
    if (state !== 4'h0 || busy || done || trainError || apply || pointStart ||
        codes !== '0 || selected !== '0 || leftCodes !== '0 || rightCodes !== '0)
      $fatal(1, "Asynchronous reset did not flush pipeline state %h", resetState);
    applied = 1'b0;
    pointDone = 1'b0;
    @(negedge clock);
    reset_n = 1'b1;
  endtask

  initial begin
    if (expectedCode(0) !== 20'h00000 || expectedCode(1) !== 20'h00001 ||
        expectedCode(2) !== 20'h00002 || expectedCode(18) !== 20'h003fe ||
        expectedCode(19) !== 20'h003ff || expectedCode(20) !== 20'h007ff ||
        expectedCode(21) !== 20'h00bff || expectedCode(38) !== 20'hfffff)
      $fatal(1, "Independent oracle boundary error");
    for (int scenario = 0; scenario < 6; scenario++) runScenario(scenario);
    runScenario(1, 1'b0, 1, 1); // Restart directly from error; immediate handshakes.
    runScenario(0, 1'b0, 1, 1); // Restart directly from done.
    resetInPipeline(4'ha);
    runScenario(2, 1'b0, 1, 1);
    resetInPipeline(4'hb);
    runScenario(2, 1'b0, 1, 1);
    $display("PASS RxDeskewEncodingSpec_tb: all 39 codes, two-cell boundary, windows, ties, inactive lanes, stalls, retries, pipeline stages and terminal restarts");
    $finish;
  end
endmodule

`default_nettype wire
