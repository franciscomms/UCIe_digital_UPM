`timescale 1ns/1ps
`default_nettype none

// Directed digital tests for the shared engines used by all four Vref states.
module VrefOneHotSpec_tb;
  logic clock = 1'b0;
  always #5 clock = ~clock;
  logic reset_n = 1'b0;
  logic start = 1'b0;
  logic validApply, validApplied = 1'b0, validPointStart;
  logic validPointDone = 1'b0, validPointPass = 1'b0;
  logic validBusy, validDone, validError;
  logic [19:0] validCode, validSelected, validLeft, validRight;
  logic [3:0] validState;
  logic [15:0] validFailed, validRetries;
  logic dataApply, dataApplied = 1'b0, dataPointStart;
  logic dataPointDone = 1'b0;
  logic [3:0] dataPointPass = '0;
  logic dataBusy, dataDone, dataError;
  logic [79:0] dataCodes, dataSelected, dataLeft, dataRight;
  logic [3:0] dataState;
  logic [15:0] dataFailed, dataRetries;

  MBTrain_ValidVrefSweepEngine #(.MAX_TRAINING_RETRIES(1)) validDut (
    .clock(clock), .reset_n(reset_n), .start(start),
    .busy(validBusy), .done(validDone), .trainError(validError),
    .apply_rx_vref(validApply), .rx_vref_code(validCode),
    .rx_vref_applied(validApplied), .point_test_start(validPointStart),
    .point_test_done(validPointDone), .point_test_pass(validPointPass),
    .state(validState), .lastFailedPointCount(validFailed),
    .retryCount(validRetries), .finalVrefCode(validSelected),
    .validLeftCode(validLeft), .validRightCode(validRight)
  );
  MBTrain_DataVrefSweepEngine #(
    .DATA_LANE_COUNT(4), .ACTIVE_DATA_LANE_MASK(4'b0111),
    .MAX_TRAINING_RETRIES(1)
  ) dataDut (
    .clock(clock), .reset_n(reset_n), .start(start),
    .busy(dataBusy), .done(dataDone), .trainError(dataError),
    .apply_rx_vref(dataApply), .rx_vref_codes(dataCodes),
    .rx_vref_applied(dataApplied), .point_test_start(dataPointStart),
    .point_test_done(dataPointDone), .point_test_pass(dataPointPass),
    .state(dataState), .lastFailedLaneCount(dataFailed),
    .retryCount(dataRetries), .finalVrefCodes(dataSelected),
    .validLeftCodes(dataLeft), .validRightCodes(dataRight)
  );

  function automatic logic [19:0] code(input int tap);
    return 20'b1 << tap;
  endfunction

  function automatic int decode(input logic [19:0] value);
    for (int tap = 0; tap < 20; tap++)
      if (value == code(tap)) return tap;
    $fatal(1, "Vref code is not exactly one-hot: %h", value);
    return -1;
  endfunction

  function automatic bit validPassAt(input int scenario, input int tap);
    case (scenario)
      0, 3: return tap >= 4 && tap <= 9;
      1: return (tap >= 2 && tap <= 5) || (tap >= 12 && tap <= 15);
      2: return 1'b0;
      default: return 1'b1;
    endcase
  endfunction

  function automatic bit dataPassAt(input int scenario, input int lane, input int tap);
    if (scenario == 2) return 1'b0;
    if (scenario == 4) return 1'b1;
    if (scenario == 1) begin
      case (lane)
        0: return (tap >= 2 && tap <= 5) || (tap >= 12 && tap <= 15);
        1: return tap == 19;
        default: return tap == 0;
      endcase
    end
    case (lane)
      0: return tap == 0;
      1: return tap >= 16 && tap <= 19;
      default: return 1'b1;
    endcase
  endfunction

  task automatic checkWindow(
    input logic [19:0] selectedCode, leftCode, rightCode,
    input int selectedTap, leftTap, rightTap
  );
    if (selectedCode !== code(selectedTap) ||
        leftCode !== code(leftTap) || rightCode !== code(rightTap))
      $fatal(1, "Window mismatch: selected=%h left=%h right=%h; expected taps %0d/%0d/%0d",
        selectedCode, leftCode, rightCode, selectedTap, leftTap, rightTap);
  endtask

  task automatic runScenario(input int scenario);
    int validSweepApplies, dataSweepApplies, validFinalApplies, dataFinalApplies;
    int cycles, tap;
    validSweepApplies = 0;
    dataSweepApplies = 0;
    validFinalApplies = 0;
    dataFinalApplies = 0;
    cycles = 0;
    @(negedge clock);
    reset_n = 1'b0;
    start = 1'b0;
    validApplied = 1'b0;
    dataApplied = 1'b0;
    validPointDone = 1'b0;
    dataPointDone = 1'b0;
    @(negedge clock);
    if (validSelected !== '0 || validLeft !== '0 || validRight !== '0 ||
        dataSelected !== '0 || dataLeft !== '0 || dataRight !== '0)
      $fatal(1, "Unselected windows must be zero after reset");
    reset_n = 1'b1;
    start = 1'b1;
    @(negedge clock);
    start = 1'b0;
    while (!((validDone || validError) && (dataDone || dataError))) begin
      if (++cycles > 1000) $fatal(1, "Scenario %0d timed out", scenario);
      validApplied = validApply;
      dataApplied = dataApply;
      validPointDone = validState == 4'h3 || validState == 4'h7;
      dataPointDone = dataState == 4'h3 || dataState == 4'h7;
      if (validApply) begin
        tap = decode(validCode);
        if (validState == 4'h1) begin
          if (tap != validSweepApplies % 20)
            $fatal(1, "Valid sweep skipped/reordered a tap");
          validSweepApplies++;
        end else validFinalApplies++;
      end
      if (dataApply) begin
        for (int lane = 0; lane < 3; lane++) begin
          tap = decode(dataCodes[lane*20 +: 20]);
          if (dataState == 4'h1 && tap != dataSweepApplies % 20)
            $fatal(1, "Data sweep skipped/reordered a tap on lane %0d", lane);
        end
        if (dataState == 4'h1) dataSweepApplies++;
        else dataFinalApplies++;
      end
      if (dataCodes[60 +: 20] !== '0 || dataSelected[60 +: 20] !== '0 ||
          dataLeft[60 +: 20] !== '0 || dataRight[60 +: 20] !== '0)
        $fatal(1, "Inactive data lane must stay zero");
      if (validState == 4'h3)
        validPointPass = validPassAt(scenario, decode(validCode));
      else if (validState == 4'h7)
        validPointPass = !(scenario == 3 && validFinalApplies == 1);
      if (dataState == 4'h3) begin
        dataPointPass = '0;
        for (int lane = 0; lane < 3; lane++)
          dataPointPass[lane] =
            dataPassAt(scenario, lane, decode(dataCodes[lane*20 +: 20]));
      end else if (dataState == 4'h7)
        dataPointPass = scenario == 3 && dataFinalApplies == 1 ? 4'b0000 : 4'b0111;
      @(negedge clock);
    end
    validApplied = 1'b0;
    dataApplied = 1'b0;
    validPointDone = 1'b0;
    dataPointDone = 1'b0;
    if (scenario == 2) begin
      if (!validError || !dataError || validRetries != 1 || dataRetries != 1 ||
          validSweepApplies != 40 || dataSweepApplies != 40 ||
          validFinalApplies != 0 || dataFinalApplies != 0)
        $fatal(1, "No-window retry/error behavior failed");
    end else begin
      if (!validDone || !dataDone || validError || dataError)
        $fatal(1, "Passing windows did not complete");
      if (validSweepApplies != (scenario == 3 ? 40 : 20) ||
          dataSweepApplies != (scenario == 3 ? 40 : 20) ||
          validFinalApplies != (scenario == 3 ? 2 : 1) ||
          dataFinalApplies != (scenario == 3 ? 2 : 1) ||
          validRetries != (scenario == 3 ? 1 : 0) ||
          dataRetries != (scenario == 3 ? 1 : 0))
        $fatal(1, "Unexpected sweep or final-verify counts");
      case (scenario)
        0, 3: begin
          checkWindow(validSelected, validLeft, validRight, 6, 4, 9);
          checkWindow(dataSelected[0 +: 20], dataLeft[0 +: 20], dataRight[0 +: 20], 0, 0, 0);
          checkWindow(dataSelected[20 +: 20], dataLeft[20 +: 20], dataRight[20 +: 20], 17, 16, 19);
          checkWindow(dataSelected[40 +: 20], dataLeft[40 +: 20], dataRight[40 +: 20], 9, 0, 19);
        end
        1: begin
          checkWindow(validSelected, validLeft, validRight, 3, 2, 5);
          checkWindow(dataSelected[0 +: 20], dataLeft[0 +: 20], dataRight[0 +: 20], 3, 2, 5);
          checkWindow(dataSelected[20 +: 20], dataLeft[20 +: 20], dataRight[20 +: 20], 19, 19, 19);
          checkWindow(dataSelected[40 +: 20], dataLeft[40 +: 20], dataRight[40 +: 20], 0, 0, 0);
        end
        default: begin
          checkWindow(validSelected, validLeft, validRight, 9, 0, 19);
          for (int lane = 0; lane < 3; lane++)
            checkWindow(dataSelected[lane*20 +: 20], dataLeft[lane*20 +: 20],
              dataRight[lane*20 +: 20], 9, 0, 19);
        end
      endcase
    end
    $display("PASS Vref one-hot scenario %0d", scenario);
  endtask

  initial begin
    for (int scenario = 0; scenario < 5; scenario++) runScenario(scenario);
    $display("PASS VrefOneHotSpec_tb");
    $finish;
  end
endmodule

`default_nettype wire
