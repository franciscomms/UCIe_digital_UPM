`timescale 1ps/1ps
`default_nettype none
// One 800 MHz controller per x16 link. Each digital-side flag or state bus
// has the same name and meaning as its source or sink in the supplied RTL.
module rx_ucie_digital_controller #(
    parameter logic [15:0] activeDataLaneMask = 16'hffff,
    parameter logic [15:0] dataVrefMaximumComparisonErrorThreshold = 16'd0,
    parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold = 16'd0,
    parameter integer SYNC_STAGES = 3,
    parameter integer WINDOW_DRAIN_CYCLES = 32,
    parameter bit MIRROR_RX_ON_RETRY = 1'b1,
    parameter bit ENABLE_CENTER_RESEED = 1'b0,
    parameter bit ENABLE_CENTER_COMPARE = 1'b0
) (
    input wire clock,
    input wire reset_n,
    input wire [3:0] ltsm_state,
    input wire [2:0] ltsm_dbg_mbinitSubstate,
    input wire [2:0] jtagLtsm_dbg_mbinitReversalMbReceiverState,
    input wire [3:0] ltsm_dbg_mbtrainState,
    input wire [11:0] ltsm_dbg_mbtrainActiveSubstate,
    input wire ltsm_flagToAnalog_RepairValState,
    input wire ltsm_flagToAnalog_RepairMbSetReceiver,
    input wire ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    input wire ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    input wire ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    input wire ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    input wire ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    input wire ltsm_flagToAnalog_linkInit_resetLfsrScrambler,
    output wire ltsm_flagFromAnalog_ValTrainPatternReceived,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14,
    output wire ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14,
    output wire ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15,
    output wire [15:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern,
    output wire [15:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
    output wire [15:0] ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,

    // Existing PHY-side DATA adapter and shared VALID endpoint connections.
    output wire [15:0] lane_req_o,
    output wire [15:0] lane_req_rst_o,
    output wire [15:0] lane_req_laneid_o,
    output wire lane_reverse_o,
    output wire [15:0] lane_active_o,
    input wire [15:0] lane_ack_i,
    input wire [15:0] lane_armed_i,
    input wire [15:0] lane_pass_i,
    output wire val_req_o,
    output wire val_finish_o,
    input wire val_ack_i,
    input wire val_armed_i,
    input wire val_pass_i,

    // Local Valid point-test feedback in the controller clock domain.
    output wire ltsm_flagFromAnalog_valVref_detectedValPattern,
    output wire ltsm_valVref_pointArmed,
    output wire ltsm_valVref_pointResultReady,

    // 0 = REPAIRVAL; 1 = full-point Valid comparison (Vref or centering).
    output logic val_mode_o,
    output wire center_point_armed_o,
    output wire center_result_ready_o,
    output logic center_valid_pass_o,
    output logic [15:0] center_lane_pass_o,
    output wire linkSpeed_point_armed_o,
    output wire linkSpeed_result_ready_o
);
    localparam logic [3:0] MBINIT=4'd5, MBTRAIN=4'd6, LINKINIT=4'd7, ACTIVE=4'd8;
    (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] reset_q;
    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) reset_q <= '0;
        else reset_q <= {reset_q[SYNC_STAGES-2:0],1'b1};
    end
    wire rst800_n = reset_q[SYNC_STAGES-1];

    wire [15:0] reversal_pass, repair_pass;
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived0 = reversal_pass[0];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived1 = reversal_pass[1];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived2 = reversal_pass[2];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived3 = reversal_pass[3];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived4 = reversal_pass[4];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived5 = reversal_pass[5];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived6 = reversal_pass[6];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived7 = reversal_pass[7];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived8 = reversal_pass[8];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived9 = reversal_pass[9];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived10 = reversal_pass[10];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived11 = reversal_pass[11];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived12 = reversal_pass[12];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived13 = reversal_pass[13];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived14 = reversal_pass[14];
    assign ltsm_flagFromAnalog_ReversalMbTrainPatternReceived15 = reversal_pass[15];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern0 = repair_pass[0];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern1 = repair_pass[1];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern2 = repair_pass[2];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern3 = repair_pass[3];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern4 = repair_pass[4];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern5 = repair_pass[5];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern6 = repair_pass[6];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern7 = repair_pass[7];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern8 = repair_pass[8];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern9 = repair_pass[9];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern10 = repair_pass[10];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern11 = repair_pass[11];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern12 = repair_pass[12];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern13 = repair_pass[13];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern14 = repair_pass[14];
    assign ltsm_flagFromAnalog_RepairMbDetectedLaneIDPattern15 = repair_pass[15];

    wire mb_valid, mb_reverse, mb_close, training_valid, training_close;
    wire [1:0] mb_kind, training_kind;
    wire accepted, done, data_endpoint_armed, valid_endpoint_armed, final_valid_pass;
    wire [15:0] live_pass, final_pass;
    typedef enum logic [2:0] {NONE, INIT_CHECK, DATA_CHECK, PAYLOAD_SEED, VALID_VREF_CHECK, CENTER_POINT} owner_t;
    owner_t owner_q;

    // The middle nibble is the local RxInitD2CPointTestReceiverFSM state in
    // both Valid Vref stages. Each Clear starts a separate lane observation,
    // including the final verification at a previously tested voltage.
    // The endpoint compares the full Vref burst and returns one pass/fail bit.
    localparam logic [3:0] VALVREF = 4'h1, VALTRAINVREF = 4'h7;
    localparam logic [2:0] GROUP_VALID = 3'd3, GROUP_SEED = 3'd0, GROUP_DATA_CENTER = 3'd4;
    localparam logic [3:0] POINT_CLEAR = 4'h5, POINT_SEND_CLEAR_RESP = 4'h6,
                           POINT_WAIT_COUNT_DONE = 4'h7, POINT_WAIT_RESULT = 4'hc;
    wire valid_vref_stage = ltsm_state == MBTRAIN &&
            (ltsm_dbg_mbtrainState == VALVREF || ltsm_dbg_mbtrainState == VALTRAINVREF);
    wire [3:0] point_state = ltsm_dbg_mbtrainActiveSubstate[7:4];
    wire valid_window = valid_vref_stage &&
            (point_state == POINT_SEND_CLEAR_RESP || point_state == POINT_WAIT_COUNT_DONE ||
             point_state == POINT_WAIT_RESULT);
    typedef enum logic [1:0] {VREF_IDLE, VREF_REQUEST, VREF_OBSERVE, VREF_RESULT} valid_point_t;
    valid_point_t valid_point_q;
    logic valid_pass_q;
    wire valid_inflight = owner_q == VALID_VREF_CHECK && valid_point_q == VREF_OBSERVE;
    wire select_valid_vref = valid_window && valid_point_q == VREF_REQUEST;

    // A match may complete before Tx Count Done. Retain both completion and
    // pass; a prior tap or an MBINIT.REPAIRVAL transaction cannot supply either.
    assign ltsm_valVref_pointResultReady = valid_vref_stage &&
            point_state > POINT_CLEAR && valid_point_q == VREF_RESULT;
    assign ltsm_flagFromAnalog_valVref_detectedValPattern = ltsm_valVref_pointResultReady && valid_pass_q;
    assign ltsm_valVref_pointArmed = ltsm_valVref_pointResultReady ||
            (valid_window && valid_inflight && valid_endpoint_armed);

    always_ff @(posedge clock or negedge rst800_n) begin
        if (!rst800_n) begin
            valid_point_q <= VREF_IDLE;
            valid_pass_q <= 1'b0;
        end else if (!valid_vref_stage || point_state < POINT_CLEAR) begin
            valid_point_q <= VREF_IDLE;
            valid_pass_q <= 1'b0;
        end else if (point_state == POINT_CLEAR) begin
            valid_point_q <= VREF_REQUEST;
            valid_pass_q <= 1'b0;
        end else if (valid_window) begin
            if (select_valid_vref && accepted) valid_point_q <= VREF_OBSERVE;
            else if (valid_inflight && done) begin
                valid_point_q <= VREF_RESULT;
                valid_pass_q <= final_pass[0];
            end
        end else if (valid_point_q != VREF_RESULT) begin
            valid_point_q <= VREF_IDLE;
        end
    end

    // The low nibble is the local TxInitD2CPointTestReceiverFSM serving the
    // partner's sweep. Clear arms one point. Results Req closes that point.
    localparam logic [3:0] VALTRAINCENTER = 4'h6, DATATRAINCENTER1 = 4'h8,
                           DATATRAINCENTER2 = 4'hb;
    localparam logic [3:0] CENTER_CLEAR = 4'h4, CENTER_CLEAR_RESP = 4'h5,
                           CENTER_RESULTS_RESP = 4'h7;
    wire center_valid_only = ltsm_dbg_mbtrainState == VALTRAINCENTER;
    wire center_stage = ENABLE_CENTER_COMPARE && ltsm_state == MBTRAIN &&
            (center_valid_only || ltsm_dbg_mbtrainState == DATATRAINCENTER1 ||
                                  ltsm_dbg_mbtrainState == DATATRAINCENTER2);
    wire [3:0] responder_state = ltsm_dbg_mbtrainActiveSubstate[3:0];
    wire center_window = center_stage && responder_state >= CENTER_CLEAR &&
                                         responder_state <= CENTER_RESULTS_RESP;
    typedef enum logic [2:0] {C_IDLE, C_REQUEST_SEED, C_WAIT_SEED, C_REQUEST_COMPARE,
                              C_OBSERVE, C_RESULT} center_state_t;
    center_state_t center_q;
    logic [3:0] center_stage_q;
    logic [15:0] center_seeded_q;
    wire center_current = center_window && center_stage_q == ltsm_dbg_mbtrainState;
    wire select_center = center_current && (center_q == C_REQUEST_SEED || center_q == C_REQUEST_COMPARE);
    wire center_inflight = center_current && center_q == C_OBSERVE && owner_q == CENTER_POINT;
    assign center_point_armed_o = center_current &&
            ((center_inflight && valid_endpoint_armed) || center_q == C_RESULT);
    assign center_result_ready_o = center_current && responder_state == CENTER_RESULTS_RESP &&
                                   center_q == C_RESULT;

    always_ff @(posedge clock or negedge rst800_n) begin
        if (!rst800_n) begin
            center_q <= C_IDLE;
            center_stage_q <= '0;
            center_seeded_q <= '0;
            center_valid_pass_o <= 1'b0;
            center_lane_pass_o <= '0;
        end else if (!center_window || (center_q != C_IDLE && !center_current)) begin
            center_q <= C_IDLE;
            center_valid_pass_o <= 1'b0;
            center_lane_pass_o <= '0;
        end else begin
            case (center_q)
                C_IDLE: if (responder_state <= CENTER_CLEAR_RESP) begin
                    center_stage_q <= ltsm_dbg_mbtrainState;
                    if (center_valid_only) center_q <= C_REQUEST_COMPARE;
                    else if (|activeDataLaneMask) center_q <= C_REQUEST_SEED;
                    else center_q <= C_RESULT;
                end
                C_REQUEST_SEED: if (select_center && accepted) center_q <= C_WAIT_SEED;
                C_WAIT_SEED: if (owner_q == CENTER_POINT && done) begin
                    center_seeded_q <= final_pass & activeDataLaneMask;
                    center_q <= (|(final_pass & activeDataLaneMask)) ? C_REQUEST_COMPARE : C_RESULT;
                end
                C_REQUEST_COMPARE: if (select_center && accepted) center_q <= C_OBSERVE;
                C_OBSERVE: if (owner_q == CENTER_POINT && done) begin
                    center_valid_pass_o <= final_valid_pass;
                    center_lane_pass_o <= center_valid_only ? 16'b0 : final_pass;
                    center_q <= C_RESULT;
                end
                C_RESULT: ;
                default: center_q <= C_IDLE;
            endcase
        end
    end

    // LINKINIT is one cycle in LinkTrainingFSM. Capture its real reset flag;
    // let the physical seed handshake complete even after LTSM enters ACTIVE.
    typedef enum logic [1:0] {IDLE, REQUEST, WAIT_SEED, SEEDED} payload_t;
    payload_t payload_q;
    wire payload_phase = ltsm_state == LINKINIT || ltsm_state == ACTIVE;
    always_ff @(posedge clock or negedge rst800_n) begin
        if (!rst800_n) payload_q <= IDLE;
        else if (!payload_phase) payload_q <= IDLE;
        else begin
            case (payload_q)
                IDLE: if (ltsm_state == LINKINIT && ltsm_flagToAnalog_linkInit_resetLfsrScrambler
                          && (|activeDataLaneMask)) payload_q <= REQUEST;
                REQUEST: if (accepted) payload_q <= WAIT_SEED;
                WAIT_SEED: if (owner_q == PAYLOAD_SEED && done) begin
                    if ((final_pass & activeDataLaneMask) == activeDataLaneMask) payload_q <= SEEDED;
                    else payload_q <= IDLE;
                end
                SEEDED: ;
                default: payload_q <= IDLE;
            endcase
        end
    end
    wire select_mb = ltsm_state == MBINIT && mb_valid;
    wire select_training = ltsm_state == MBTRAIN && training_valid && (|activeDataLaneMask);
    wire select_seed = payload_phase && payload_q == REQUEST;
    wire cmd_valid = owner_q == NONE &&
                     (select_mb || select_training || select_valid_vref || select_center || select_seed);
    wire center_compare = select_center && center_q == C_REQUEST_COMPARE;
    wire [2:0] kind = select_mb ? {1'b0, mb_kind} : select_training ? {1'b0, training_kind} :
                      (select_valid_vref || (center_compare && center_valid_only)) ? GROUP_VALID :
                      center_compare ? GROUP_DATA_CENTER : GROUP_SEED;
    // The dedicated Valid lane uses result bit zero regardless of the Data lane mask.
    wire [15:0] cmd_mask = select_mb ? 16'hffff : kind == GROUP_VALID ? 16'h0001 :
                           center_compare ? center_seeded_q : activeDataLaneMask;
    wire close_window = (owner_q == INIT_CHECK && (mb_close || ltsm_state != MBINIT)) ||
                        (owner_q == DATA_CHECK && (training_close || ltsm_state != MBTRAIN)) ||
                        (owner_q == VALID_VREF_CHECK &&
                         (!valid_inflight || !valid_window || point_state == POINT_WAIT_RESULT)) ||
                        (owner_q == CENTER_POINT &&
                         (!center_inflight || responder_state == CENTER_RESULTS_RESP));
    always_ff @(posedge clock or negedge rst800_n) begin
        if (!rst800_n) begin
            owner_q <= NONE;
            val_mode_o <= 1'b0;
        end else if (accepted) begin
            // Capture the selected operation before raising the Valid request.
            // Keep it stable through acknowledgement and release, even on abort.
            if (kind == GROUP_VALID || kind == GROUP_DATA_CENTER)
                val_mode_o <= select_valid_vref || center_compare;
            if (select_mb) owner_q <= INIT_CHECK;
            else if (select_training) owner_q <= DATA_CHECK;
            else if (select_valid_vref) owner_q <= VALID_VREF_CHECK;
            else if (select_center) owner_q <= CENTER_POINT;
            else owner_q <= PAYLOAD_SEED;
        end else if (done) owner_q <= NONE;
    end

    rx_ltsm_mbinit800 #(.MIRROR_RX_ON_RETRY(MIRROR_RX_ON_RETRY)) mbinit (
        .clock(clock), .reset_n(rst800_n), .ltsm_state(ltsm_state),
        .ltsm_dbg_mbinitSubstate(ltsm_dbg_mbinitSubstate),
        .jtagLtsm_dbg_mbinitReversalMbReceiverState(jtagLtsm_dbg_mbinitReversalMbReceiverState),
        .ltsm_flagToAnalog_RepairValState(ltsm_flagToAnalog_RepairValState),
        .ltsm_flagToAnalog_RepairMbSetReceiver(ltsm_flagToAnalog_RepairMbSetReceiver),
        .ltsm_flagFromAnalog_ValTrainPatternReceived(ltsm_flagFromAnalog_ValTrainPatternReceived),
        .reversal_pass_o(reversal_pass), .repair_pass_o(repair_pass),
        .cmd_valid_o(mb_valid), .cmd_kind_o(mb_kind), .cmd_reverse_o(mb_reverse),
        .valid_finish_o(mb_close), .cmd_accept_i(select_mb && accepted),
        .cmd_done_i(owner_q == INIT_CHECK && done),
        .cmd_live_pass_i(owner_q == INIT_CHECK ? live_pass : 16'b0), .cmd_pass_i(final_pass)
    );
    rx_ltsm_data_training800 #(
        .dataVrefMaximumComparisonErrorThreshold(dataVrefMaximumComparisonErrorThreshold),
        .rxDeskewMaximumComparisonErrorThreshold(rxDeskewMaximumComparisonErrorThreshold),
        .ENABLE_CENTER_RESEED(ENABLE_CENTER_RESEED && !ENABLE_CENTER_COMPARE)
    ) data_training (
        .clock(clock), .reset_n(rst800_n), .ltsm_state(ltsm_state),
        .ltsm_dbg_mbtrainState(ltsm_dbg_mbtrainState), .ltsm_dbg_mbtrainActiveSubstate(ltsm_dbg_mbtrainActiveSubstate),
        .ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest(ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest),
        .ltsm_flagToAnalog_dataVref_clearComparisonErrors(ltsm_flagToAnalog_dataVref_clearComparisonErrors),
        .ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest(ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest),
        .ltsm_flagToAnalog_rxDeskew_clearComparisonErrors(ltsm_flagToAnalog_rxDeskew_clearComparisonErrors),
        .ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler(ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler),
        .ltsm_flagFromAnalog_dataVref_detectedDataPattern(ltsm_flagFromAnalog_dataVref_detectedDataPattern),
        .ltsm_flagFromAnalog_rxDeskew_detectedDataPattern(ltsm_flagFromAnalog_rxDeskew_detectedDataPattern),
        .ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful(ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful),
        .cmd_valid_o(training_valid), .cmd_kind_o(training_kind), .finish_o(training_close),
        .point_armed_o(linkSpeed_point_armed_o), .result_ready_o(linkSpeed_result_ready_o),
        .cmd_armed_i(owner_q == DATA_CHECK && data_endpoint_armed),
        .cmd_accept_i(select_training && accepted), .cmd_done_i(owner_q == DATA_CHECK && done),
        .cmd_live_pass_i(owner_q == DATA_CHECK ? live_pass : 16'b0), .cmd_pass_i(final_pass)
    );
    rx_ltsm_group800 #(.LANES(16), .SYNC_STAGES(SYNC_STAGES), .WINDOW_DRAIN_CYCLES(WINDOW_DRAIN_CYCLES)) lane_commands (
        .clk_800_i(clock), .rst_ni(reset_n), .cmd_valid_i(cmd_valid), .cmd_kind_i(kind),
        .cmd_mask_i(cmd_mask), .cmd_reverse_i(select_mb && mb_reverse),
        .valid_finish_i(close_window), .cmd_accept_o(accepted), .cmd_done_o(done),
        .cmd_live_pass_o(live_pass), .cmd_pass_o(final_pass), .valid_armed_o(valid_endpoint_armed),
        .cmd_valid_pass_o(final_valid_pass), .cmd_armed_o(data_endpoint_armed),
        .active_mask_i(ltsm_state == ACTIVE && payload_q == SEEDED ? activeDataLaneMask : 16'b0),
        .lane_req_o(lane_req_o), .lane_req_rst_o(lane_req_rst_o), .lane_req_laneid_o(lane_req_laneid_o),
        .lane_reverse_o(lane_reverse_o), .lane_active_o(lane_active_o),
        .lane_ack_i(lane_ack_i), .lane_armed_i(lane_armed_i), .lane_pass_i(lane_pass_i),
        .val_req_o(val_req_o), .val_finish_o(val_finish_o),
        .val_ack_i(val_ack_i), .val_armed_i(val_armed_i), .val_pass_i(val_pass_i)
    );
endmodule

// MBINIT uses the functional strobes and stage tags present in the supplied
// digital shell. The digital FSM samples the returned flags on its own peer
// RESULT_REQ. A receiver ACK or end-of-observation is not part of that interface.
module rx_ltsm_mbinit800 #(
    parameter bit MIRROR_RX_ON_RETRY = 1'b1
) (
    input wire clock,
    input wire reset_n,
    input wire [3:0] ltsm_state,
    input wire [2:0] ltsm_dbg_mbinitSubstate,
    input wire [2:0] jtagLtsm_dbg_mbinitReversalMbReceiverState,
    input wire ltsm_flagToAnalog_RepairValState,
    input wire ltsm_flagToAnalog_RepairMbSetReceiver,
    output wire ltsm_flagFromAnalog_ValTrainPatternReceived,
    output wire [15:0] reversal_pass_o,
    output wire [15:0] repair_pass_o,

    // Local transaction interface to the shared lane-command sequencer.
    output wire cmd_valid_o,
    output wire [1:0] cmd_kind_o,
    output wire cmd_reverse_o,
    output wire valid_finish_o,
    input wire cmd_accept_i,
    input wire cmd_done_i,
    input wire [15:0] cmd_pass_i,
    input wire [15:0] cmd_live_pass_i
);
    localparam logic [1:0] ID = 2'd1, VALID = 2'd3;
    typedef enum logic [2:0] {
        NONE, CHECK_VALID, CHECK_FORWARD, CHECK_RETRY, CHECK_REPAIR
    } operation_t;
    operation_t pending_q;
    operation_t flight_q;

    wire mbinit = ltsm_state == 4'd5;
    wire val_phase = mbinit && ltsm_flagToAnalog_RepairValState;
    wire rev_phase = mbinit && ltsm_dbg_mbinitSubstate == 3'd4;
    wire repair_phase = mbinit && ltsm_dbg_mbinitSubstate == 3'd5;
    wire repair_window = repair_phase && ltsm_flagToAnalog_RepairMbSetReceiver;
    // The original receiver FSM enters sendClearErrorResp (2) once per
    // actual peer clear, and sendResultResp (4) immediately AFTER sampling
    // its reversal bitmap. The shell exposes this existing three-bit bus.
    wire rev_clear = rev_phase && jtagLtsm_dbg_mbinitReversalMbReceiverState == 3'd2;
    wire rev_report = rev_phase && jtagLtsm_dbg_mbinitReversalMbReceiverState == 3'd4;
    logic val_prev_q, rev_prev_q, repair_prev_q, rev_clear_prev_q;
    logic first_clear_seen_q, retry_selected_q;
    wire start_val = val_phase && !val_prev_q;
    wire start_forward = rev_phase && !rev_prev_q;
    wire start_retry = rev_clear && !rev_clear_prev_q && first_clear_seen_q;
    wire start_repair = repair_window && !repair_prev_q;
    wire start = start_val || start_forward || start_retry || start_repair;

    logic discard_q;
    logic valid_result_q;
    logic [15:0] reversal_result_q, repair_result_q;
    wire pending_stage = (pending_q == CHECK_VALID && val_phase) ||
                         ((pending_q == CHECK_FORWARD || pending_q == CHECK_RETRY) && rev_phase && !rev_report) ||
                         (pending_q == CHECK_REPAIR && repair_phase);
    wire flight_stage = (flight_q == CHECK_VALID && val_phase) ||
                        ((flight_q == CHECK_FORWARD || flight_q == CHECK_RETRY) && rev_phase && !rev_report) ||
                        (flight_q == CHECK_REPAIR && repair_phase);
    wire current = flight_stage && !discard_q && !start;
    assign cmd_valid_o = pending_stage && !start;
    assign cmd_kind_o = pending_q == CHECK_VALID ? VALID : ID;
    assign cmd_reverse_o = MIRROR_RX_ON_RETRY &&
                           (pending_q == CHECK_RETRY || (pending_q == CHECK_REPAIR && retry_selected_q));
    // A silent/abandoned observation retires on departure from its stage.
    // An incoming REPAIR pin can pulse while the preceding trial is draining.
    assign valid_finish_o = flight_q != NONE && !current;

    // Report each qualified lane independently. A silent lane cannot hide its
    // neighbors at the original digital sampling edge. Hold the completed
    // result through the response; the next peer clear starts a fresh bitmap.
    assign ltsm_flagFromAnalog_ValTrainPatternReceived = !start_val &&
            (valid_result_q || (current && flight_q == CHECK_VALID && cmd_live_pass_i[0]));
    wire checking_reversal = flight_q == CHECK_FORWARD || flight_q == CHECK_RETRY;
    assign reversal_pass_o = (start_forward || start_retry) ? 16'b0 : reversal_result_q |
            ((current && checking_reversal) ? cmd_live_pass_i : 16'b0);
    assign repair_pass_o = start_repair ? 16'b0 : repair_result_q |
            ((current && flight_q == CHECK_REPAIR) ? cmd_live_pass_i : 16'b0);

    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            val_prev_q <= 1'b0;
            rev_prev_q <= 1'b0;
            repair_prev_q <= 1'b0;
            rev_clear_prev_q <= 1'b0;
            first_clear_seen_q <= 1'b0;
            pending_q <= NONE;
            flight_q <= NONE;
            discard_q <= 1'b0;
            retry_selected_q <= 1'b0;
            valid_result_q <= 1'b0;
            reversal_result_q <= '0;
            repair_result_q <= '0;
        end else begin
            val_prev_q <= val_phase;
            rev_prev_q <= rev_phase;
            repair_prev_q <= repair_window;
            rev_clear_prev_q <= rev_clear;
            if (!rev_phase) first_clear_seen_q <= 1'b0;
            else if (rev_clear) first_clear_seen_q <= 1'b1;

            if (current) begin
                if (flight_q == CHECK_VALID && cmd_live_pass_i[0]) valid_result_q <= 1'b1;
                if (checking_reversal) reversal_result_q <= reversal_result_q | cmd_live_pass_i;
                if (flight_q == CHECK_REPAIR) repair_result_q <= repair_result_q | cmd_live_pass_i;
            end

            if (!pending_stage || cmd_accept_i) pending_q <= NONE;
            if (cmd_accept_i) begin
                flight_q <= pending_q;
                discard_q <= 1'b0;
            end else if (cmd_done_i) begin
                flight_q <= NONE;
                discard_q <= 1'b0;
                if (current) begin
                    case (flight_q)
                        CHECK_VALID: valid_result_q <= cmd_pass_i[0];
                        CHECK_FORWARD, CHECK_RETRY: reversal_result_q <= cmd_pass_i;
                        CHECK_REPAIR: repair_result_q <= cmd_pass_i;
                        default: ;
                    endcase
                end
            end else if (flight_q != NONE && !current) begin
                discard_q <= 1'b1;
            end

            if (start_val) begin
                valid_result_q <= 1'b0;
                pending_q <= CHECK_VALID;
            end else if (start_forward) begin
                reversal_result_q <= '0;
                retry_selected_q <= 1'b0;
                pending_q <= CHECK_FORWARD;
            end else if (start_retry) begin
                reversal_result_q <= '0;
                retry_selected_q <= 1'b1;
                pending_q <= CHECK_RETRY;
            end else if (start_repair) begin
                repair_result_q <= '0;
                pending_q <= CHECK_REPAIR;
            end
        end
    end
endmodule

// Fixed 128-word DATA detector. The LTSM inputs and result names are those of
// the supplied digital shell. The private cmd interface drives the DATA adapters.
module rx_ltsm_data_training800 #(
    parameter logic [15:0] dataVrefMaximumComparisonErrorThreshold = 16'd0,
    parameter logic [15:0] rxDeskewMaximumComparisonErrorThreshold = 16'd0,
    parameter bit ENABLE_CENTER_RESEED = 1'b0
) (
    input  wire clock,
    input  wire reset_n,
    input  wire [3:0] ltsm_state,
    input  wire [3:0] ltsm_dbg_mbtrainState,
    input  wire [11:0] ltsm_dbg_mbtrainActiveSubstate,
    input  wire ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest,
    input  wire ltsm_flagToAnalog_dataVref_clearComparisonErrors,
    input  wire ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest,
    input  wire ltsm_flagToAnalog_rxDeskew_clearComparisonErrors,
    input  wire ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler,
    output wire [15:0] ltsm_flagFromAnalog_dataVref_detectedDataPattern,
    output wire [15:0] ltsm_flagFromAnalog_rxDeskew_detectedDataPattern,
    output wire [15:0] ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful,

    output wire cmd_valid_o,
    output wire [1:0] cmd_kind_o,
    output wire finish_o,
    output wire point_armed_o,
    output wire result_ready_o,
    input  wire cmd_armed_i,
    input  wire cmd_accept_i,
    input  wire cmd_done_i,
    input  wire [15:0] cmd_live_pass_i,
    input  wire [15:0] cmd_pass_i
);
    localparam logic [1:0] SEED = 2'd0, LFSR = 2'd2;
    localparam logic [3:0] DATAVREF = 4'h2, VALTRAINCENTER = 4'h6,
                           DATATRAINCENTER1 = 4'h8, DATATRAINVREF = 4'h9,
                           RXDESKEW = 4'ha, DATATRAINCENTER2 = 4'hb, LINKSPEED = 4'hc;
    wire mbtrain = ltsm_state == 4'd6;
    wire vref = mbtrain && dataVrefMaximumComparisonErrorThreshold == 0 &&
                (ltsm_dbg_mbtrainState == DATAVREF || ltsm_dbg_mbtrainState == DATATRAINVREF);
    wire deskew = mbtrain && rxDeskewMaximumComparisonErrorThreshold == 0 &&
                  ltsm_dbg_mbtrainState == RXDESKEW;
    wire speed = mbtrain && ltsm_dbg_mbtrainState == LINKSPEED;
    wire center = ENABLE_CENTER_RESEED && mbtrain &&
                  (ltsm_dbg_mbtrainState == VALTRAINCENTER ||
                   ltsm_dbg_mbtrainState == DATATRAINCENTER1 ||
                   ltsm_dbg_mbtrainState == DATATRAINCENTER2);
    wire local_config = (vref && ltsm_flagToAnalog_dataVref_configureRxInitD2CPointTest) ||
                        (deskew && ltsm_flagToAnalog_rxDeskew_configureRxInitD2CPointTest);
    wire local_clear = (vref && ltsm_flagToAnalog_dataVref_clearComparisonErrors) ||
                       (deskew && ltsm_flagToAnalog_rxDeskew_clearComparisonErrors);
    // In reseed-only configurations the external PHY supplies centering
    // comparisons. The integrated centering checker owns its own seed request.
    // The shell qualifies a LINKSPEED clear against the supported profile.
    wire d2c_reset = (speed || center) && ltsm_flagToAnalog_d2cReceiver_resetLocalRxScrambler;
    logic d2c_reset_prev_q;

    typedef enum logic [2:0] {IDLE, ISSUE_SEED, WAIT_SEED, WAIT_CLEAR,
                              ISSUE_COMPARE, COMPARE, HOLD_RESULT} state_t;
    state_t state_q;
    logic [3:0] stage_q;
    logic clear_seen_q;
    logic [15:0] seed_pass_q, held_pass_q;
    wire same_stage = mbtrain && stage_q == ltsm_dbg_mbtrainState;
    wire d2c_start = d2c_reset && (!d2c_reset_prev_q || !same_stage);
    wire start = local_config || d2c_start;
    // Vref/deskew consume the live bitmap before substate 8. LINKSPEED
    // substate 7 closes its observation and waits for result_ready_o before
    // forming a response, so the final word and its ACK can still arrive.
    wire sampled = same_stage &&
                   (((vref || deskew) && ltsm_dbg_mbtrainActiveSubstate[7:4] == 4'h8) ||
                    (speed && ltsm_dbg_mbtrainActiveSubstate[3:0] == 4'h7));
    wire [15:0] live_pass = seed_pass_q & (cmd_done_i ? cmd_pass_i : cmd_live_pass_i);
    wire [15:0] public_pass = (!same_stage || start) ? 16'b0 :
                              (state_q == COMPARE) ? live_pass : held_pass_q;
    assign ltsm_flagFromAnalog_dataVref_detectedDataPattern = vref ? public_pass : 16'b0;
    assign ltsm_flagFromAnalog_rxDeskew_detectedDataPattern = deskew ? public_pass : 16'b0;
    assign ltsm_flagFromAnalog_d2cReceiver_laneComparisonSuccessful = speed ? public_pass : 16'b0;
    assign point_armed_o = speed && same_stage && !start &&
        ((state_q == COMPARE && cmd_armed_i) || state_q == HOLD_RESULT);
    assign result_ready_o = speed && same_stage && !start && state_q == HOLD_RESULT;
    assign cmd_valid_o = same_stage && !start && !sampled &&
                         (state_q == ISSUE_SEED || state_q == ISSUE_COMPARE);
    assign cmd_kind_o = state_q == ISSUE_COMPARE ? LFSR : SEED;
    assign finish_o = !same_stage || start || sampled || state_q == HOLD_RESULT;

    always_ff @(posedge clock or negedge reset_n) begin
        if (!reset_n) begin
            d2c_reset_prev_q <= 1'b0;
            stage_q <= '0;
            clear_seen_q <= 1'b0;
            seed_pass_q <= '0;
            held_pass_q <= '0;
            state_q <= IDLE;
        end else begin
            d2c_reset_prev_q <= d2c_reset;
            if (start) begin
                // Configure starts the local seed handshake early. A received
                // clear is remembered even while a previous request is releasing.
                stage_q <= ltsm_dbg_mbtrainState;
                clear_seen_q <= local_clear || (speed && d2c_start);
                held_pass_q <= '0;
                seed_pass_q <= '0;
                state_q <= ISSUE_SEED;
            end else if (!same_stage) begin
                state_q <= IDLE;
                held_pass_q <= '0;
            end else if (sampled && !speed) begin
                if (state_q == COMPARE) held_pass_q <= live_pass;
                state_q <= HOLD_RESULT;
            end else begin
                if (local_clear) clear_seen_q <= 1'b1;
                case (state_q)
                    // The group sequencer owns an accepted seed through ACK
                    // and release. Only comparative points need its result.
                    ISSUE_SEED: if (cmd_accept_i) state_q <= center ? IDLE : WAIT_SEED;
                    WAIT_SEED: if (cmd_done_i) begin
                        seed_pass_q <= cmd_pass_i;
                        state_q <= (clear_seen_q || local_clear) ? ISSUE_COMPARE : WAIT_CLEAR;
                    end
                    WAIT_CLEAR: if (local_clear) state_q <= ISSUE_COMPARE;
                    ISSUE_COMPARE: if (cmd_accept_i) state_q <= COMPARE;
                    COMPARE: if (cmd_done_i) begin
                        held_pass_q <= live_pass;
                        state_q <= HOLD_RESULT;
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule

module rx_ltsm_group800 #(
  parameter integer LANES = 16,
  parameter integer SYNC_STAGES = 3,
  // From last partner DATA to local synchronized ACK, in clk_800_i periods.
  // Increase for deeper VALID/data pipelines or greater physical flight time.
  parameter integer WINDOW_DRAIN_CYCLES = 32
) (
  input  wire                 clk_800_i,
  input  wire                 rst_ni,
  input  wire                 cmd_valid_i,
  input  wire [2:0]           cmd_kind_i,
  input  wire [LANES-1:0]     cmd_mask_i,
  input  wire                 cmd_reverse_i,
  input  wire                 valid_finish_i,
  output wire                 cmd_accept_o,
  output var logic            cmd_done_o,
  output var logic [LANES-1:0] cmd_pass_o,
  output wire [LANES-1:0]     cmd_live_pass_o,

  input  wire [LANES-1:0]     active_mask_i,
  output var logic [LANES-1:0] lane_req_o,
  output var logic [LANES-1:0] lane_req_rst_o,
  output var logic [LANES-1:0] lane_req_laneid_o,
  output var logic            lane_reverse_o,
  output var logic [LANES-1:0] lane_active_o,
  input  wire [LANES-1:0]     lane_ack_i,
  input  wire [LANES-1:0]     lane_armed_i,
  input  wire [LANES-1:0]     lane_pass_i,

  output var logic            val_req_o,
  output var logic            val_finish_o,
  input  wire                 val_ack_i,
  input  wire                 val_armed_i,
  input  wire                 val_pass_i,
  output wire                 valid_armed_o,
  output wire                 cmd_armed_o,
  output var logic            cmd_valid_pass_o
);
  localparam logic [2:0] SEED=3'd0, ID=3'd1, LFSR=3'd2, VALID=3'd3, DATA_CENTER=3'd4;
  localparam integer DRAIN_W = $clog2(WINDOW_DRAIN_CYCLES + 1);
  localparam integer RETURN_WIDTH = 3*LANES + 3;
  (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] reset_q;
  always_ff @(posedge clk_800_i or negedge rst_ni) begin
    if (!rst_ni) reset_q <= '0;
    else reset_q <= {reset_q[SYNC_STAGES-2:0], 1'b1};
  end
  wire rst800_n = reset_q[SYNC_STAGES-1];

  // Every bit is a registered level. Control and payload qualification themselves
  // remain in the PHY. The result is stable until after this block captures it.
  (* ASYNC_REG = "TRUE" *) logic [RETURN_WIDTH-1:0] rx_sync_q [0:SYNC_STAGES-1];
  always_ff @(posedge clk_800_i or negedge rst800_n) begin
    if (!rst800_n) begin
      for (int s=0; s<SYNC_STAGES; s++) rx_sync_q[s] <= '0;
    end else begin
      rx_sync_q[0] <= {lane_armed_i, lane_ack_i, lane_pass_i,
                       val_armed_i, val_ack_i, val_pass_i};
      for (int s=1; s<SYNC_STAGES; s++) rx_sync_q[s] <= rx_sync_q[s-1];
    end
  end
  wire [LANES-1:0] armed800, ack800, pass800;
  wire val_armed800, val_ack800, val_pass800;
  assign {armed800, ack800, pass800,
          val_armed800, val_ack800, val_pass800} = rx_sync_q[SYNC_STAGES-1];

  typedef enum logic [1:0] {G_IDLE, G_WAIT, G_SAMPLE, G_RELEASE} group_state_t;
  group_state_t state_q;
  logic [LANES-1:0] mask_q, completed_mask_q, ack_seen_q;
  logic window_closed_q;
  logic [DRAIN_W-1:0] drain_q;
  logic [2:0] kind_q;
  wire is_valid = (kind_q == VALID);
  wire data_center = (kind_q == DATA_CENTER);
  wire all_data_armed = ((armed800 & mask_q) == mask_q);
  assign valid_armed_o = (state_q != G_IDLE) && val_armed800 &&
                         (is_valid || (data_center && all_data_armed));
  wire all_armed = is_valid ? val_armed800 : all_data_armed;
  assign cmd_armed_o = (state_q == G_WAIT || state_q == G_SAMPLE) && all_armed;
  wire all_ack = is_valid ? val_ack800 : ((ack800 & mask_q) == mask_q);
  wire data_released = (((ack800 | armed800) & mask_q) == '0);
  wire valid_released = !(val_ack800 || val_armed800);
  wire released = (is_valid || data_released) && (!(is_valid || data_center) || valid_released);
  // The original LTSM reads individual pass bits on its own result edge.
  // A silent lane must not mask a different lane's completed comparison.
  // Sample synchronized ACK one additional edge before qualifying its held pass.
  wire [LANES-1:0] current_pass = is_valid ? {LANES{val_pass800}} : pass800;
  wire [LANES-1:0] current_ack = is_valid ? {LANES{val_ack800}} : ack800;
  assign cmd_live_pass_o = (state_q == G_WAIT || state_q == G_SAMPLE)
                         ? completed_mask_q & ack_seen_q & current_pass
                         : (state_q == G_RELEASE) ? cmd_pass_o : '0;
  assign cmd_accept_o = rst800_n && (state_q == G_IDLE) && cmd_valid_i;

  always_ff @(posedge clk_800_i or negedge rst800_n) begin
    if (!rst800_n) begin
      state_q <= G_IDLE;
      mask_q <= '0;
      completed_mask_q <= '0;
      ack_seen_q <= '0;
      drain_q <= '0;
      window_closed_q <= 1'b0;
      kind_q <= SEED;
      cmd_done_o <= 1'b0;
      cmd_pass_o <= '0;
      cmd_valid_pass_o <= 1'b0;
      lane_req_o <= '0;
      lane_req_rst_o <= '0;
      lane_req_laneid_o <= '0;
      lane_reverse_o <= 1'b0;
      lane_active_o <= '0;
      val_req_o <= 1'b0;
      val_finish_o <= 1'b0;
    end else begin
      lane_active_o <= active_mask_i;
      cmd_done_o <= 1'b0;
      case (state_q)
        G_IDLE: if (cmd_accept_o) begin
          kind_q <= cmd_kind_i;
          mask_q <= cmd_mask_i;
          completed_mask_q <= cmd_mask_i;
          ack_seen_q <= '0;
          window_closed_q <= valid_finish_i;
          drain_q <= DRAIN_W'(WINDOW_DRAIN_CYCLES);
          cmd_pass_o <= '0;
          cmd_valid_pass_o <= 1'b0;
          // The last ID trial selects the logical-to-physical seed mapping.
          // Keep the selection through reseed, LFSR compare and ACTIVE.
          if (cmd_kind_i == ID) lane_reverse_o <= cmd_reverse_i;
          lane_req_o <= (cmd_kind_i == LFSR || cmd_kind_i == DATA_CENTER) ? cmd_mask_i : '0;
          lane_req_rst_o <= (cmd_kind_i == SEED) ? cmd_mask_i : '0;
          lane_req_laneid_o <= (cmd_kind_i == ID) ? cmd_mask_i : '0;
          if (cmd_mask_i == '0) state_q <= G_SAMPLE;
          else state_q <= G_WAIT;
        end
        G_WAIT: begin
          ack_seen_q <= current_ack;
          // Raise REQ one source clock after the mode register is loaded.
          // A zero mask skips G_WAIT and never requests a Valid transaction.
          // For a combined point, the data adapters first enable normal Valid
          // framing. Only then request its concurrent 4096-UI frame monitor.
          if (is_valid || (data_center && all_data_armed)) begin
            val_req_o <= 1'b1;
            if (valid_finish_i || window_closed_q) val_finish_o <= 1'b1;
          end
          if (valid_finish_i) window_closed_q <= 1'b1;
          if (all_ack && (!data_center || (val_ack800 && window_closed_q))) state_q <= G_SAMPLE;
          else if (!is_valid && kind_q != SEED && all_armed &&
                   (window_closed_q || valid_finish_i)) begin
            // The peer has closed the observation. Leave the request high
            // through capture, compare and return CDC for its final word.
            if (drain_q == DRAIN_W'(1)) begin
              if (!data_center || val_ack800) begin
                completed_mask_q <= ack800 & mask_q;
                state_q <= G_SAMPLE;
              end
            end else drain_q <= drain_q - 1'b1;
          end
        end
        G_SAMPLE: begin
          // Allow one additional destination edge for result vs. ACK path skew.
          // Constrain their source-register to first-stage skew below one clk_800_i period.
          cmd_pass_o <= completed_mask_q & current_pass;
          cmd_valid_pass_o <= (is_valid || data_center) && val_ack800 && val_pass800;
          cmd_done_o <= 1'b1;
          lane_req_o <= '0;
          lane_req_rst_o <= '0;
          lane_req_laneid_o <= '0;
          val_req_o <= 1'b0;
          val_finish_o <= 1'b0;
          state_q <= G_RELEASE;
        end
        G_RELEASE: if (released) begin
          state_q <= G_IDLE;
        end
      endcase
    end
  end
  // synthesis translate_off
  initial if (LANES < 1 || SYNC_STAGES < 2 || WINDOW_DRAIN_CYCLES < 1)
    $fatal(1, "rx_ltsm_group800 requires LANES >= 1, SYNC_STAGES >= 2 and WINDOW_DRAIN_CYCLES >= 1");
  // synthesis translate_on
endmodule

`default_nettype wire
