// Parallel XOR network with asynchronous-assert/synchronous-release global reset.
// LFSR restart and seed load remain synchronous.
// UCIe Specification Rev. 2.0, Version 1.0 (2024-08-06),
// section 4.4.1, Table 4-4, Figure 4-30; bit order: section 4.1.1.
// G(x) = x^23 + x^21 + x^16 + x^8 + x^5 + x^2 + 1.
// Serial convention: y = old_s[22];
// new_s = {old_s[21:0], 1'b0} ^ (old_s[22] ? 23'h210125 : 23'b0).
// seed_i[i] maps directly to Di in the specification diagram.
// data_o[0] is earliest; data_o[31] is latest. One lane/stream per instance.
// rst_ni is active low. Its release is synchronized locally unless the parent
// supplies a local reset and sets RESET_INPUT_IS_SYNC=1.
// lfsr_reset_i is an active-high synchronous restart.
// Priority: local reset > lfsr_reset_i > seed_load_i > enable_i > hold.
// Supply a shared local reset in the parent lane so its initial seed-load pulse
// is not delayed or lost behind an additional reset synchronizer here.
// Both resets restore the lane's default seed; seed_load_i loads seed_i exactly.
// Reset/restart/load clears data; the next enabled edge emits the first word.
// Disable holds data/state. No valid output: the consumer tracks accepted enable.
// Load is exact, including zero (a locked state; not a UCIe lane seed).
// Maximum XOR fan-in: 12; balanced two-input XOR depth: 4.
// At 500 MHz, 32 bits/clock supplies four 8-bit slices for a 2 GHz byte path.
// Clock-frequency timing closure requires implementation/STA, not RTL simulation.
`timescale 1ps/1ps
`default_nettype none

module ucie_lfsr23_32 #(
    parameter integer LANE_ID = 0,  // Nonnegative logical lane index.
    parameter integer RESET_SYNC_STAGES = 3,
    parameter bit RESET_INPUT_IS_SYNC = 1'b0
) (
    // Explicit input net types for tools enforcing `default_nettype none.
    input  wire logic        clk_i,
    input  wire logic        rst_ni,
    input  wire logic        enable_i,
    input  wire logic        seed_load_i,
    input  wire logic        lfsr_reset_i,
    input  wire logic [22:0] seed_i,
    output      logic [31:0] data_o
);

    function automatic [22:0] lane_seed(input integer lane);
        case (lane % 8)
            0: lane_seed = 23'h1DBFBC;
            1: lane_seed = 23'h0607BB;
            2: lane_seed = 23'h1EC760;
            3: lane_seed = 23'h18C0DB;
            4: lane_seed = 23'h010F12;
            5: lane_seed = 23'h19CFC9;
            6: lane_seed = 23'h0277CE;
            7: lane_seed = 23'h1BB807;
            default: lane_seed = 23'h1DBFBC;
        endcase
    endfunction

    localparam logic [22:0] RESET_SEED = lane_seed(LANE_ID);

    wire rst_local_n;
    if (RESET_INPUT_IS_SYNC) begin : g_reset_from_parent
        assign rst_local_n = rst_ni;
    end else begin : g_reset_sync
        ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_sync (
            .clk_i(clk_i), .arst_ni(rst_ni), .rst_no(rst_local_n)
        );
    end

    logic [22:0] state_q;
    wire  [22:0] state_d;
    wire  [31:0] data_d;

    // Fully reduced GF(2) output transform, evaluated from state_q.
    assign data_d[0] = state_q[22];
    assign data_d[1] = state_q[21];
    assign data_d[2] = (state_q[20] ^ state_q[22]);
    assign data_d[3] = (state_q[19] ^ state_q[21]);
    assign data_d[4] = (state_q[18] ^ (state_q[20] ^ state_q[22]));
    assign data_d[5] = (state_q[17] ^ (state_q[19] ^ state_q[21]));
    assign data_d[6] = ((state_q[16] ^ state_q[18]) ^ (state_q[20] ^ state_q[22]));
    assign data_d[7] = ((state_q[15] ^ state_q[17]) ^ (state_q[19] ^ (state_q[21] ^ state_q[22])));
    assign data_d[8] = ((state_q[14] ^ (state_q[16] ^ state_q[18])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22])));
    assign data_d[9] = ((state_q[13] ^ (state_q[15] ^ state_q[17])) ^ (state_q[19] ^ (state_q[20] ^ state_q[21])));
    assign data_d[10] = ((state_q[12] ^ (state_q[14] ^ state_q[16])) ^ ((state_q[18] ^ state_q[19]) ^ (state_q[20] ^ state_q[22])));
    assign data_d[11] = (((state_q[11] ^ state_q[13]) ^ (state_q[15] ^ state_q[17])) ^ ((state_q[18] ^ state_q[19]) ^ (state_q[21] ^ state_q[22])));
    assign data_d[12] = (((state_q[10] ^ state_q[12]) ^ (state_q[14] ^ state_q[16])) ^ ((state_q[17] ^ state_q[18]) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));
    assign data_d[13] = (((state_q[9] ^ state_q[11]) ^ (state_q[13] ^ state_q[15])) ^ ((state_q[16] ^ state_q[17]) ^ (state_q[19] ^ (state_q[20] ^ state_q[21]))));
    assign data_d[14] = (((state_q[8] ^ state_q[10]) ^ (state_q[12] ^ state_q[14])) ^ ((state_q[15] ^ state_q[16]) ^ (state_q[18] ^ (state_q[19] ^ state_q[20]))));
    assign data_d[15] = (((state_q[7] ^ state_q[9]) ^ (state_q[11] ^ state_q[13])) ^ ((state_q[14] ^ state_q[15]) ^ (state_q[17] ^ (state_q[18] ^ state_q[19]))));
    assign data_d[16] = (((state_q[6] ^ state_q[8]) ^ (state_q[10] ^ state_q[12])) ^ ((state_q[13] ^ state_q[14]) ^ (state_q[16] ^ (state_q[17] ^ state_q[18]))));
    assign data_d[17] = (((state_q[5] ^ state_q[7]) ^ (state_q[9] ^ state_q[11])) ^ ((state_q[12] ^ state_q[13]) ^ (state_q[15] ^ (state_q[16] ^ state_q[17]))));
    assign data_d[18] = (((state_q[4] ^ state_q[6]) ^ (state_q[8] ^ state_q[10])) ^ ((state_q[11] ^ state_q[12]) ^ (state_q[14] ^ (state_q[15] ^ state_q[16]))));
    assign data_d[19] = (((state_q[3] ^ state_q[5]) ^ (state_q[7] ^ state_q[9])) ^ ((state_q[10] ^ state_q[11]) ^ (state_q[13] ^ (state_q[14] ^ state_q[15]))));
    assign data_d[20] = (((state_q[2] ^ state_q[4]) ^ (state_q[6] ^ (state_q[8] ^ state_q[9]))) ^ ((state_q[10] ^ state_q[12]) ^ (state_q[13] ^ (state_q[14] ^ state_q[22]))));
    assign data_d[21] = (((state_q[1] ^ state_q[3]) ^ (state_q[5] ^ (state_q[7] ^ state_q[8]))) ^ ((state_q[9] ^ state_q[11]) ^ (state_q[12] ^ (state_q[13] ^ state_q[21]))));
    assign data_d[22] = (((state_q[0] ^ state_q[2]) ^ (state_q[4] ^ (state_q[6] ^ state_q[7]))) ^ ((state_q[8] ^ (state_q[10] ^ state_q[11])) ^ (state_q[12] ^ (state_q[20] ^ state_q[22]))));
    assign data_d[23] = (((state_q[1] ^ state_q[3]) ^ (state_q[5] ^ (state_q[6] ^ state_q[7]))) ^ ((state_q[9] ^ (state_q[10] ^ state_q[11])) ^ (state_q[19] ^ (state_q[21] ^ state_q[22]))));
    assign data_d[24] = (((state_q[0] ^ state_q[2]) ^ (state_q[4] ^ (state_q[5] ^ state_q[6]))) ^ ((state_q[8] ^ (state_q[9] ^ state_q[10])) ^ (state_q[18] ^ (state_q[20] ^ state_q[21]))));
    assign data_d[25] = (((state_q[1] ^ state_q[3]) ^ (state_q[4] ^ (state_q[5] ^ state_q[7]))) ^ ((state_q[8] ^ (state_q[9] ^ state_q[17])) ^ (state_q[19] ^ (state_q[20] ^ state_q[22]))));
    assign data_d[26] = (((state_q[0] ^ state_q[2]) ^ (state_q[3] ^ (state_q[4] ^ state_q[6]))) ^ ((state_q[7] ^ (state_q[8] ^ state_q[16])) ^ (state_q[18] ^ (state_q[19] ^ state_q[21]))));
    assign data_d[27] = (((state_q[1] ^ state_q[2]) ^ (state_q[3] ^ (state_q[5] ^ state_q[6]))) ^ ((state_q[7] ^ (state_q[15] ^ state_q[17])) ^ (state_q[18] ^ (state_q[20] ^ state_q[22]))));
    assign data_d[28] = (((state_q[0] ^ state_q[1]) ^ (state_q[2] ^ (state_q[4] ^ state_q[5]))) ^ ((state_q[6] ^ (state_q[14] ^ state_q[16])) ^ (state_q[17] ^ (state_q[19] ^ state_q[21]))));
    assign data_d[29] = (((state_q[0] ^ state_q[1]) ^ (state_q[3] ^ (state_q[4] ^ state_q[5]))) ^ ((state_q[13] ^ (state_q[15] ^ state_q[16])) ^ (state_q[18] ^ (state_q[20] ^ state_q[22]))));
    assign data_d[30] = (((state_q[0] ^ state_q[2]) ^ (state_q[3] ^ (state_q[4] ^ state_q[12]))) ^ ((state_q[14] ^ (state_q[15] ^ state_q[17])) ^ (state_q[19] ^ (state_q[21] ^ state_q[22]))));
    assign data_d[31] = (((state_q[1] ^ state_q[2]) ^ (state_q[3] ^ (state_q[11] ^ state_q[13]))) ^ ((state_q[14] ^ (state_q[16] ^ state_q[18])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));

    // State after exactly 32 serial advances.
    assign state_d[0] = (((state_q[1] ^ state_q[2]) ^ (state_q[3] ^ (state_q[11] ^ state_q[13]))) ^ ((state_q[14] ^ (state_q[16] ^ state_q[18])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[1] = (((state_q[0] ^ state_q[2]) ^ (state_q[3] ^ (state_q[4] ^ state_q[12]))) ^ ((state_q[14] ^ (state_q[15] ^ state_q[17])) ^ (state_q[19] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[2] = (((state_q[0] ^ state_q[2]) ^ (state_q[4] ^ state_q[5])) ^ ((state_q[11] ^ state_q[14]) ^ (state_q[15] ^ state_q[21])));
    assign state_d[3] = (((state_q[1] ^ state_q[3]) ^ (state_q[5] ^ state_q[6])) ^ ((state_q[12] ^ state_q[15]) ^ (state_q[16] ^ state_q[22])));
    assign state_d[4] = (((state_q[0] ^ state_q[2]) ^ (state_q[4] ^ state_q[6])) ^ ((state_q[7] ^ state_q[13]) ^ (state_q[16] ^ state_q[17])));
    assign state_d[5] = (((state_q[2] ^ state_q[5]) ^ (state_q[7] ^ (state_q[8] ^ state_q[11]))) ^ ((state_q[13] ^ (state_q[16] ^ state_q[17])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[6] = (((state_q[0] ^ state_q[3]) ^ (state_q[6] ^ (state_q[8] ^ state_q[9]))) ^ ((state_q[12] ^ (state_q[14] ^ state_q[17])) ^ (state_q[18] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[7] = (((state_q[0] ^ state_q[1]) ^ (state_q[4] ^ (state_q[7] ^ state_q[9]))) ^ ((state_q[10] ^ (state_q[13] ^ state_q[15])) ^ (state_q[18] ^ (state_q[19] ^ state_q[22]))));
    assign state_d[8] = (((state_q[0] ^ state_q[3]) ^ (state_q[5] ^ (state_q[8] ^ state_q[10]))) ^ ((state_q[13] ^ state_q[18]) ^ (state_q[19] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[9] = (((state_q[0] ^ state_q[1]) ^ (state_q[4] ^ (state_q[6] ^ state_q[9]))) ^ ((state_q[11] ^ state_q[14]) ^ (state_q[19] ^ (state_q[20] ^ state_q[22]))));
    assign state_d[10] = (((state_q[1] ^ state_q[2]) ^ (state_q[5] ^ state_q[7])) ^ ((state_q[10] ^ state_q[12]) ^ (state_q[15] ^ (state_q[20] ^ state_q[21]))));
    assign state_d[11] = (((state_q[2] ^ state_q[3]) ^ (state_q[6] ^ state_q[8])) ^ ((state_q[11] ^ state_q[13]) ^ (state_q[16] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[12] = (((state_q[0] ^ state_q[3]) ^ (state_q[4] ^ state_q[7])) ^ ((state_q[9] ^ state_q[12]) ^ (state_q[14] ^ (state_q[17] ^ state_q[22]))));
    assign state_d[13] = (((state_q[0] ^ state_q[1]) ^ (state_q[4] ^ state_q[5])) ^ ((state_q[8] ^ state_q[10]) ^ (state_q[13] ^ (state_q[15] ^ state_q[18]))));
    assign state_d[14] = (((state_q[0] ^ state_q[1]) ^ (state_q[2] ^ (state_q[5] ^ state_q[6]))) ^ ((state_q[9] ^ state_q[11]) ^ (state_q[14] ^ (state_q[16] ^ state_q[19]))));
    assign state_d[15] = (((state_q[0] ^ state_q[1]) ^ (state_q[2] ^ (state_q[3] ^ state_q[6]))) ^ ((state_q[7] ^ (state_q[10] ^ state_q[12])) ^ (state_q[15] ^ (state_q[17] ^ state_q[20]))));
    assign state_d[16] = ((state_q[4] ^ (state_q[7] ^ state_q[8])) ^ (state_q[14] ^ (state_q[20] ^ state_q[22])));
    assign state_d[17] = ((state_q[5] ^ state_q[8]) ^ (state_q[9] ^ (state_q[15] ^ state_q[21])));
    assign state_d[18] = ((state_q[0] ^ (state_q[6] ^ state_q[9])) ^ (state_q[10] ^ (state_q[16] ^ state_q[22])));
    assign state_d[19] = ((state_q[0] ^ (state_q[1] ^ state_q[7])) ^ (state_q[10] ^ (state_q[11] ^ state_q[17])));
    assign state_d[20] = ((state_q[1] ^ (state_q[2] ^ state_q[8])) ^ (state_q[11] ^ (state_q[12] ^ state_q[18])));
    assign state_d[21] = (((state_q[0] ^ (state_q[1] ^ state_q[9])) ^ (state_q[11] ^ (state_q[12] ^ state_q[14]))) ^ ((state_q[16] ^ (state_q[18] ^ state_q[19])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));
    assign state_d[22] = (((state_q[0] ^ (state_q[1] ^ state_q[2])) ^ (state_q[10] ^ (state_q[12] ^ state_q[13]))) ^ ((state_q[15] ^ (state_q[17] ^ state_q[19])) ^ (state_q[20] ^ (state_q[21] ^ state_q[22]))));

    always_ff @(posedge clk_i or negedge rst_local_n) begin
        if (!rst_local_n) begin
            state_q <= RESET_SEED;
            data_o  <= 32'b0;
        end else if (lfsr_reset_i) begin
            state_q <= RESET_SEED;
            data_o  <= 32'b0;
        end else if (seed_load_i) begin
            state_q <= seed_i;
            data_o  <= 32'b0;
        end else if (enable_i) begin
            state_q <= state_d;
            data_o  <= data_d;
        end
    end
endmodule

`default_nettype wire
