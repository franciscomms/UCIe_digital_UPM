`timescale 1ns/1ps
`default_nettype none

module DllPiSweepSpec_tb;
  logic clock = 0;
  always #5 clock = ~clock;
  logic reset_n = 0, start = 0;
  wire busy [0:2], done [0:2], error [0:2], apply_phase [0:2], point_start [0:2];
  logic phase_applied [0:2], point_done [0:2], valid_pass [0:2], cumulative_pass [0:2];
  logic [63:0] lane_pass [0:2];
  wire [37:0] phase_code [0:2], final_code [0:2];
  wire [37:0] left_code [1:2], right_code [1:2];
  wire [15:0] retries [0:2], failed [0:2];
  wire [4:0] state1;
  wire [3:0] state2, statev;
  wire apply_deskew;
  logic deskew_applied;
  wire [1279:0] deskew_codes;
  MBTrain_DataTrainCenter1SweepEngine center1 (
    .clock(clock),.reset_n(reset_n),.start(start),
    .busy(busy[0]),.done(done[0]),.trainError(error[0]),
    .apply_tx_clock_phase(apply_phase[0]),.tx_clock_phase_code(phase_code[0]),
    .tx_clock_phase_applied(phase_applied[0]),.apply_tx_lane_deskew(apply_deskew),
    .tx_lane_deskew_codes(deskew_codes),.tx_lane_deskew_applied(deskew_applied),
    .point_test_start(point_start[0]),.point_test_done(point_done[0]),
    .point_test_lane_pass(lane_pass[0]),.point_test_valid_pass(valid_pass[0]),
    .point_test_cumulative_pass(cumulative_pass[0]),.state(state1),
    .lastFailedComparisons(failed[0]),.retryCount(retries[0]),.finalClockPhase(final_code[0])
  );
  MBTrain_DataTrainCenter2SweepEngine center2 (
    .clock(clock),.reset_n(reset_n),.start(start),
    .busy(busy[1]),.done(done[1]),.trainError(error[1]),
    .apply_tx_clock_phase(apply_phase[1]),.tx_clock_phase_code(phase_code[1]),
    .tx_clock_phase_applied(phase_applied[1]),
    .point_test_start(point_start[1]),.point_test_done(point_done[1]),
    .point_test_lane_pass(lane_pass[1]),.point_test_valid_pass(valid_pass[1]),
    .point_test_cumulative_pass(cumulative_pass[1]),.state(state2),
    .lastFailedComparisons(failed[1]),.retryCount(retries[1]),.finalClockPhase(final_code[1]),
    .globalLeftPhase(left_code[1]),.globalRightPhase(right_code[1])
  );
  MBTrain_ValTrainCenterSweepEngine valid_center (
    .clock(clock),.reset_n(reset_n),.start(start),
    .busy(busy[2]),.done(done[2]),.trainError(error[2]),
    .apply_tx_clock_phase(apply_phase[2]),.tx_clock_phase_code(phase_code[2]),
    .tx_clock_phase_applied(phase_applied[2]),
    .point_test_start(point_start[2]),.point_test_done(point_done[2]),
    .point_test_valid_pass(valid_pass[2]),.state(statev),
    .lastFailedComparisons(failed[2]),.retryCount(retries[2]),.finalClockPhase(final_code[2]),
    .validLeftPhase(left_code[2]),.validRightPhase(right_code[2])
  );

  // Independent reference based on switch weights, not the package encoder.
  function automatic logic [37:0] expected_phase(input int phase);
    int sec, step;
    logic [16:0] later, upper;
    logic [1:0] lower_mux, upper_mux;
    sec=phase/33; step=phase%33;
    later='0; later[0]=1'(step%2);
    for(int sw=0;sw<16;sw++) later[sw+1]=(sw<step/2);
    upper=sec%2 ? later : ~later;
    lower_mux=2'(sec/2); upper_mux=2'((sec+1)/2);
    return {~upper,upper,lower_mux,upper_mux};
  endfunction

  function automatic int decode(input logic [37:0] word);
    for(int phase=0;phase<264;phase++)
      if(word === expected_phase(phase)) return phase;
    $fatal(1,"Illegal DLL/PI word %h",word);
    return -1;
  endfunction

  function automatic logic [19:0] expected_deskew(input int half_steps);
    int first, second;
    logic [19:0] result;
    first=half_steps>19 ? 19 : half_steps;
    second=half_steps>19 ? half_steps-19 : 0;
    result='0; result[0]=1'(first%2); result[10]=1'(second%2);
    for(int sw=0;sw<9;sw++) begin
      result[1+sw]=sw<first/2;
      result[11+sw]=sw<second/2;
    end
    return result;
  endfunction

  function automatic bit pass_at(input int scenario, input int phase);
    case(scenario)
      0: return 1;
      1: return (phase>=30 && phase<=35)||(phase>=80 && phase<=85);
      2: return 0;
      3,6: return phase>=180 && phase<=189;
      4: return phase<=2 || phase>=260;
      5: return phase==263;
      default: return 0;
    endcase
  endfunction

  function automatic int expected_selected_phase(input int scenario);
    case (scenario)
      0: return 131;
      1: return 32;
      3, 6: return 184;
      4: return 261;
      5: return 263;
      default: return -1;
    endcase
  endfunction

  task automatic run_scenario(input int scenario);
    int wait_apply[0:2], wait_point[0:2], sweep_count[0:2], final_count[0:2];
    int point_count[0:2];
    int early_ack_count[0:2];
    int initial_count, verify_count, deskew_count, deskew_wait, cycles, phase;
    int expected_center, expected_left, expected_right, expected_sweeps;
    bit is_initial, is_verify, is_final, in_wait;
    logic [37:0] held_phase[0:2];
    logic [37:0] last_applied_phase[0:2];
    logic [1279:0] held_deskew;
    @(negedge clock);
    reset_n=0; start=0; deskew_applied=0;
    initial_count=0; verify_count=0; deskew_count=0; deskew_wait=0; cycles=0;
    for(int engine=0;engine<3;engine++) begin
      phase_applied[engine]=0; point_done[engine]=0;
      valid_pass[engine]=0; cumulative_pass[engine]=0; lane_pass[engine]='0;
      wait_apply[engine]=0; wait_point[engine]=0;
      sweep_count[engine]=0; final_count[engine]=0;
      point_count[engine]=0; last_applied_phase[engine]='0;
      early_ack_count[engine]=0;
    end
    @(negedge clock);
    reset_n=1; start=1;
    @(negedge clock);
    start=0;
    while(!((done[0]||error[0])&&(done[1]||error[1])&&(done[2]||error[2]))) begin
      if(++cycles>20000) $fatal(1,"Scenario %0d timeout states=%0d/%0d/%0d",scenario,state1,state2,statev);
      deskew_applied=0;
      if(apply_deskew) begin
        if(deskew_wait==0) held_deskew=deskew_codes;
        if(deskew_codes!==held_deskew) $fatal(1,"Deskew changed under backpressure");
        deskew_wait++;
        if(deskew_wait==3) begin
          deskew_applied=1; deskew_count++;
          for(int lane=0;lane<64;lane++) begin
            int delay;
            delay=(scenario==3 && state1==7 && lane<16) ? 3-lane%4 : 0;
            if(deskew_codes[lane*20+:20]!==expected_deskew(delay))
              $fatal(1,"TX deskew incorrect lane=%0d delay=%0d word=%h",lane,delay,deskew_codes[lane*20+:20]);
          end
        end
      end else deskew_wait=0;
      for(int engine=0;engine<3;engine++) begin
        phase_applied[engine]=0;
        // Scenario 5 holds an old/high analog acknowledge through decoder
        // preparation. The FSM must ignore it until a valid apply is issued.
        if (scenario==5 && !apply_phase[engine] &&
            (engine==0 ? (state1==2||state1==9||state1==14) :
             (engine==1 ? (state2==1||state2==6) : (statev==1||statev==6)))) begin
          phase_applied[engine]=1;
          early_ack_count[engine]++;
        end
        if(apply_phase[engine]) begin
          if(wait_apply[engine]==0) held_phase[engine]=phase_code[engine];
          if(phase_code[engine]!==held_phase[engine]) $fatal(1,"PI changed under backpressure engine=%0d",engine);
          wait_apply[engine]++;
          // Vary acknowledgement latency, including the first apply cycle.
          // These checks do not prescribe the decoder preparation latency.
          if(wait_apply[engine]==(scenario==5 ? 1 : 1+(sweep_count[engine]+engine+scenario)%5)) begin
            phase_applied[engine]=1;
            phase=decode(phase_code[engine]);
            last_applied_phase[engine]=phase_code[engine];
            is_initial=engine==0 && state1==2;
            is_verify=engine==0 && state1==9;
            is_final=engine==0 ? state1==14 : (engine==1 ? state2==6 : statev==6);
            if(is_final) begin
              final_count[engine]++;
              if (phase != expected_selected_phase(scenario) ||
                  phase_code[engine] !== final_code[engine])
                $fatal(1,"Stale/wrong final phase applied scenario=%0d engine=%0d got=%0d final_code=%h",
                  scenario,engine,phase,final_code[engine]);
            end
            else begin
              if(phase!=sweep_count[engine]%264) $fatal(1,"Skipped/duplicated phase engine=%0d got=%0d count=%0d",engine,phase,sweep_count[engine]);
              sweep_count[engine]++;
              if(is_initial) initial_count++;
              if(is_verify) verify_count++;
            end
          end
        end else wait_apply[engine]=0;
        in_wait=engine==0 ? (state1==4||state1==11||state1==16) :
          (engine==1 ? (state2==3||state2==8) : (statev==3||statev==8));
        if (point_start[engine]) begin
          point_count[engine]++;
          if (point_count[engine] != sweep_count[engine]+final_count[engine] ||
              phase_code[engine] !== last_applied_phase[engine])
            $fatal(1,"Point test did not start with exactly one acknowledged phase engine=%0d",engine);
        end
        point_done[engine]=0;
        if(in_wait) begin
          if (phase_code[engine] !== last_applied_phase[engine])
            $fatal(1,"PI changed during point-test wait engine=%0d",engine);
          wait_point[engine]++;
          phase=decode(phase_code[engine]);
          is_initial=engine==0 && state1==4;
          is_final=engine==0 ? state1==16 : (engine==1 ? state2==8 : statev==8);
          valid_pass[engine]=is_initial ? 1 : pass_at(scenario,phase);
          cumulative_pass[engine]=valid_pass[engine];
          lane_pass[engine]='0;
          for(int lane=0;lane<16;lane++) begin
            if(is_initial && scenario==3)
              lane_pass[engine][lane]=(phase>=120+lane%4 && phase<=129+lane%4);
            else if(is_initial && scenario==6)
              lane_pass[engine][lane]=phase==(lane==0 ? 0 : 100);
            else lane_pass[engine][lane]=pass_at(scenario,phase);
          end
          if(is_final && scenario==3 && retries[engine]==0) begin
            valid_pass[engine]=0; cumulative_pass[engine]=0; lane_pass[engine]='0;
          end
          if(wait_point[engine]==1+(point_count[engine]+engine+scenario)%3) point_done[engine]=1;
        end else wait_point[engine]=0;
      end
      @(negedge clock);
    end
    deskew_applied=0;
    for(int engine=0;engine<3;engine++) begin
      phase_applied[engine]=0; point_done[engine]=0;
      if (point_count[engine] != sweep_count[engine]+final_count[engine])
        $fatal(1,"Applied phase / point-test count mismatch engine=%0d",engine);
      if (scenario==5 && early_ack_count[engine]==0)
        $fatal(1,"Decoder-wait early acknowledge was not exercised engine=%0d",engine);
      if(scenario==2 || (scenario==6 && engine==0)) begin
        if(!error[engine] || done[engine] || retries[engine]!=1 ||
           sweep_count[engine]!=528 || final_count[engine]!=0)
          $fatal(1,"Failure/retry handling mismatch scenario=%0d engine=%0d",scenario,engine);
      end else begin
        case(scenario)
          0: begin expected_center=131; expected_left=0; expected_right=263; end
          1: begin expected_center=32; expected_left=30; expected_right=35; end
          3,6: begin expected_center=184; expected_left=180; expected_right=189; end
          4: begin expected_center=261; expected_left=260; expected_right=263; end
          default: begin expected_center=263; expected_left=263; expected_right=263; end
        endcase
        expected_sweeps=(engine==0 ? 528 : 264)*(scenario==3 ? 2 : 1);
        if(!done[engine] || error[engine] || retries[engine]!=(scenario==3 ? 1 : 0) ||
           final_code[engine]!==expected_phase(expected_center) ||
           sweep_count[engine]!=expected_sweeps || final_count[engine]!=(scenario==3 ? 2 : 1))
          $fatal(1,"Selection/count mismatch scenario=%0d engine=%0d code=%h sweeps=%0d final=%0d",scenario,engine,final_code[engine],sweep_count[engine],final_count[engine]);
        if(engine>0 && (left_code[engine]!==expected_phase(expected_left) ||
           right_code[engine]!==expected_phase(expected_right))) $fatal(1,"Encoded window endpoints mismatch");
      end
    end
    if(scenario==2 || scenario==6) begin
      if(initial_count!=528 || verify_count!=0 || deskew_count!=2)
        $fatal(1,"Center1 invalid-window/overflow applied deskew or verify");
    end else if(initial_count!=(scenario==3 ? 528 : 264) ||
                verify_count!=initial_count || deskew_count!=(scenario==3 ? 4 : 2))
      $fatal(1,"Center1 initial/verify/deskew coverage incomplete");
    $display("PASS DLL/PI sweep scenario %0d: Center1/Center2/ValTrainCenter",scenario);
  endtask

  initial begin
    for(int scenario=0;scenario<7;scenario++) run_scenario(scenario);
    $display("PASS DllPiSweepSpec_tb: 7 scenarios, ordered 264-phase sweeps, stable acknowledged codes, final selection, varied handshake stalls");
    $finish;
  end
endmodule

`default_nettype wire
