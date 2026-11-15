`timescale 1ps/1ps
`default_nettype none

// Asynchronous FIFO boundary. Despite its legacy name, rst is active LOW.
// Assert one common reset for both domains. Each local reset deasserts only
// after RESET_SYNC_STAGES edges of its own clock, including stopped clocks.
module AsyncFifoCustomCore #(
    parameter DEPTH = 32,
    parameter WIDTH = 32,
    parameter integer RESET_SYNC_STAGES = 3
)(
    input wire rst,
    input wire clk_w,
    input wire valid_w,
    output wire ready_w,
    input wire [WIDTH-1:0] data_w,
    input wire clk_r,
    output wire valid_r,
    input wire ready_r,
    output wire [WIDTH-1:0] data_r
);
    wire rst_w_n, rst_r_n;
    ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) write_reset (
        .clk_i(clk_w), .arst_ni(rst), .rst_no(rst_w_n)
    );
    ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) read_reset (
        .clk_i(clk_r), .arst_ni(rst), .rst_no(rst_r_n)
    );
    AsyncFifoCustomCore_local #(.DEPTH(DEPTH), .WIDTH(WIDTH)) core (
        .rst_w_n(rst_w_n), .rst_r_n(rst_r_n),
        .clk_w(clk_w), .valid_w(valid_w), .ready_w(ready_w), .data_w(data_w),
        .clk_r(clk_r), .valid_r(valid_r), .ready_r(ready_r), .data_r(data_r)
    );
endmodule

// Internal core for a parent that already owns its domain resets.
// Both resets MUST asynchronously assert from the same reset event and
// synchronously deassert in their respective domains. Do not reset one side
// alone while the other side runs; reset discards the entire FIFO contents.
// This core deliberately adds no second reset synchronizer or release delay.
module AsyncFifoCustomCore_local #(
    parameter DEPTH = 32,
    parameter WIDTH = 32
)(
    input wire rst_w_n,
    input wire rst_r_n,
    input wire clk_w,
    input wire valid_w,
    output wire ready_w,
    input wire [WIDTH-1:0] data_w,
    input wire clk_r,
    output wire valid_r,
    input wire ready_r,
    output wire [WIDTH-1:0] data_r
);
    localparam PTR_WIDTH = $clog2(DEPTH);
    wire [PTR_WIDTH:0] b_wptr, b_rptr;
    wire [PTR_WIDTH:0] g_wptr, g_rptr;
    wire [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
    wire full, empty;

    // Each Gray-pointer synchronizer resets in its DESTINATION clock domain.
    Sync2Flop #(PTR_WIDTH + 1) wptrSync (
        .clk(clk_r), .rst(rst_r_n), .in(g_wptr), .out(g_wptr_sync)
    );
    Sync2Flop #(PTR_WIDTH + 1) rptrSync (
        .clk(clk_w), .rst(rst_w_n), .in(g_rptr), .out(g_rptr_sync)
    );
    WptrHandler #(PTR_WIDTH) wptrHandler (
        .clk(clk_w), .rst(rst_w_n), .en(valid_w),
        .g_rptr_sync(g_rptr_sync), .g_wptr(g_wptr), .b_wptr(b_wptr), .full(full)
    );
    RptrHandler #(PTR_WIDTH) rptrHandler (
        .clk(clk_r), .rst(rst_r_n), .en(ready_r),
        .g_wptr_sync(g_wptr_sync), .g_rptr(g_rptr), .b_rptr(b_rptr), .empty(empty)
    );
    Fifo #(PTR_WIDTH, WIDTH) fifo (
        .rst(rst_w_n),
        .clk_w(clk_w), .en_w(valid_w), .data_w(data_w), .b_wptr(b_wptr), .full(full),
        .clk_r(clk_r), .en_r(ready_r), .data_r(data_r), .b_rptr(b_rptr), .empty(empty)
    );

    // No interface transfer is advertised while its local state is reset.
    assign valid_r = rst_r_n && !empty;
    assign ready_w = rst_w_n && !full;

    // synthesis translate_off
    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0)
            $fatal(1, "DEPTH must be a power of two and at least four");
        if (WIDTH < 1) $fatal(1, "WIDTH must be positive");
    end
    // synthesis translate_on
endmodule

// Helper reset inputs are already synchronized to their own clk.
module Sync2Flop #(
    parameter PTR_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire [PTR_WIDTH-1:0] in,
    output wire [PTR_WIDTH-1:0] out
);
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] mid, sync_q;
    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            sync_q <= '0;
            mid <= '0;
        end else begin
            sync_q <= mid;
            mid <= in;
        end
    end
    assign out = sync_q;
endmodule

module WptrHandler #(
    parameter PTR_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire en,
    input wire [PTR_WIDTH:0] g_rptr_sync,
    output reg [PTR_WIDTH:0] g_wptr, b_wptr,
    output reg full
);
    wire [PTR_WIDTH:0] b_wptr_next = b_wptr + {{PTR_WIDTH{1'b0}}, (en & ~full)};
    wire [PTR_WIDTH:0] g_wptr_next = b_wptr_next ^ (b_wptr_next >> 1);
    wire full_next = g_wptr_next ==
                    {~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1], g_rptr_sync[PTR_WIDTH-2:0]};

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            g_wptr <= '0;
            b_wptr <= '0;
            full <= 1'b0;
        end else begin
            g_wptr <= g_wptr_next;
            b_wptr <= b_wptr_next;
            full <= full_next;
        end
    end
endmodule

module RptrHandler #(
    parameter PTR_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire en,
    input wire [PTR_WIDTH:0] g_wptr_sync,
    output reg [PTR_WIDTH:0] g_rptr, b_rptr,
    output reg empty
);
    wire [PTR_WIDTH:0] b_rptr_next = b_rptr + {{PTR_WIDTH{1'b0}}, (en & ~empty)};
    wire [PTR_WIDTH:0] g_rptr_next = b_rptr_next ^ (b_rptr_next >> 1);
    wire empty_next = g_rptr_next == g_wptr_sync;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            g_rptr <= '0;
            b_rptr <= '0;
            empty <= 1'b1;
        end else begin
            g_rptr <= g_rptr_next;
            b_rptr <= b_rptr_next;
            empty <= empty_next;
        end
    end
endmodule

module Fifo #(
    parameter PTR_WIDTH = 8,
    parameter WIDTH = 8
)(
    input wire rst,
    input wire [WIDTH-1:0] data_w,
    input wire clk_w,
    input wire en_w,
    input wire [PTR_WIDTH:0] b_wptr,
    input wire full,
    output wire [WIDTH-1:0] data_r,
    input wire clk_r,
    input wire en_r,
    input wire [PTR_WIDTH:0] b_rptr,
    input wire empty
);
    localparam ENTRIES = 2**PTR_WIDTH;
    integer i;
    reg [WIDTH-1:0] fifoBank [0:ENTRIES-1];

    // Retain the supplied flop-bank reset behavior. An SRAM implementation
    // would normally leave payload memory unreset and reset only pointers.
    always_ff @(posedge clk_w or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < ENTRIES; i = i + 1) fifoBank[i] <= '0;
        end else if (en_w && !full) begin
            fifoBank[b_wptr[PTR_WIDTH-1:0]] <= data_w;
        end
    end
    // Existing first-word-fall-through interface: valid_r qualifies this data.
    assign data_r = fifoBank[b_rptr[PTR_WIDTH-1:0]];
endmodule

module BinaryToGray #(
    parameter WIDTH = 8
)(
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    assign out[WIDTH-1] = in[WIDTH-1];
    for (genvar i = WIDTH-2; i >= 0; i = i-1) begin : g_binary_to_gray
        assign out[i] = in[i] ^ in[i+1];
    end
endmodule

module GrayToBinary #(
    parameter WIDTH = 8
)(
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    assign out[WIDTH-1] = in[WIDTH-1];
    for (genvar i = WIDTH-2; i >= 0; i = i-1) begin : g_gray_to_binary
        assign out[i] = ^(in >> i);
    end
endmodule

`default_nettype wire
