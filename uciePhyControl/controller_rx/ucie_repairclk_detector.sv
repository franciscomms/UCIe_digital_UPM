`timescale 1ps/1ps
// Coarse UCIe REPAIRCLK activity detector, one instance per received lane.
//
// Clock assumptions
//   clk_100mhz is free-running, including when rx_clk is absent.
//   rx_clk is the buffered, single-ended lane under test. During MBINIT the
//   nominal pattern is 16 cycles at 2 GHz followed by 8 periods held low.
//   ltsm_flagToAnalog_RepairClkState is synchronous to clk_100mhz and must
//   remain low for at least one clk_100mhz rising edge between attempts.
//   rst_n asynchronously asserts reset; release is synchronized in each domain.
//
// Measurement
//   A full 192 ns pattern interval has 256 rising edges. With a 100 MHz
//   reference, a 20-cycle (200 ns) observation of an ongoing ideal pattern
//   has 264..272 edges, depending on alignment. The default 256..280 range
//   adds a configurable guard band for frequency and sampling uncertainty.
//   The checker uses differences between synchronized counter snapshots,
//   so acquisition never depends on observing count == 1 or count == 256.
//   A failed window starts another nonoverlapping window until timeout.
//
// Result and timeout
//   The output is 0 while idle, acquiring, or timed out. A passing window
//   sets it to 1 until state exit or reset. TIMEOUT_REF_CYCLES starts at the
//   first enabled reference edge after reset release. Its default is 2.56 us.
//   Increase this parameter if partner startup/sideband latency requires it.
//   Timeout is terminal for this attempt; later activity cannot set the output.
//   There is no separate done output, so pending and failed both read as 0.
//   Deassert/reassert the state input to clear and rearm for another attempt.
//
// Scope
//   This is an average-activity check. Malformed waveforms with the same
//   edge density can pass; it cannot establish 16 consecutive exact patterns.
//
// Physical implementation requirements
//   * Use characterized synchronizer cells and verify the required MTBF.
//   * Preserve the RX Gray register and the two reference synchronizer stages.
//   * Constrain rx_gray_count -> rx_gray_meta inter-bit skew AND maximum data
//     delay to less than the shortest supported RX period (500 ps at 2 GHz).
//     Adapt the margin and constraint syntax to the ASIC flow. A blanket
//     asynchronous false path alone does not enforce these requirements.
//   * Close RX counter/XOR timing at the highest allowed rx_clk frequency.
//   * The 12-bit modulo counter requires fewer than 4096 RX edges per window.
//     At the default 200 ns window this means an input rate below 20.48 GHz.
//   RTL simulation checks logic; physical CDC/STA analysis remains necessary.

`default_nettype none

module ucie_repairclk_detector #(
    parameter int unsigned WINDOW_REF_CYCLES  = 20,
    parameter int unsigned MIN_RX_EDGES       = 256,
    parameter int unsigned MAX_RX_EDGES       = 280,
    parameter int unsigned TIMEOUT_REF_CYCLES = 256,
    parameter integer RESET_SYNC_STAGES = 2
) (
    input  wire logic clk_100mhz,
    input  wire logic rx_clk,
    input  wire logic rst_n,
    input  wire logic ltsm_flagToAnalog_RepairClkState,
    output logic ltsm_flagFromAnalog_clkPatternReceived
);

    localparam int unsigned RX_COUNT_WIDTH = 12;
    localparam int unsigned WINDOW_COUNT_WIDTH =
        (WINDOW_REF_CYCLES > 1) ? $clog2(WINDOW_REF_CYCLES) : 1;
    localparam int unsigned TIMEOUT_COUNT_WIDTH =
        (TIMEOUT_REF_CYCLES > 1) ? $clog2(TIMEOUT_REF_CYCLES) : 1;

    // Reset can assert with a stopped RX clock. Release consumes two RX edges
    // before the source counter runs; acquisition excludes these startup edges.
    wire rx_async_reset_n = rst_n & ltsm_flagToAnalog_RepairClkState;

    wire rx_reset_n, ref_reset_n;
    ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_rx
      (.clk_i(rx_clk), .arst_ni(rx_async_reset_n), .rst_no(rx_reset_n));
    // Independent free-running reference reset: missing RX must still time out.
    ucie_reset_sync #(.STAGES(RESET_SYNC_STAGES)) reset_ref
      (.clk_i(clk_100mhz), .arst_ni(rst_n), .rst_no(ref_reset_n));

    logic [RX_COUNT_WIDTH-1:0] rx_binary_count;
    logic [RX_COUNT_WIDTH-1:0] rx_gray_count;

    always_ff @(posedge rx_clk or negedge rx_reset_n) begin
        if (!rx_reset_n) begin
            rx_binary_count <= '0;
            rx_gray_count   <= '0;
        end else begin
            rx_binary_count <= rx_binary_count + 1'b1;
            // Register the encoding of the current binary count. This keeps
            // the Gray path separate from the incrementer, with a one-edge
            // reporting lag. That lag is common to both measurement snapshots.
            rx_gray_count <= rx_binary_count ^ (rx_binary_count >> 1);
        end
    end

    // Only registered Gray bits cross the asynchronous clock boundary.
    // The destination can skip counts. It consumes coherent snapshots rather
    // than requiring every source increment to be observed.
    (* ASYNC_REG = "TRUE" *) logic [RX_COUNT_WIDTH-1:0] rx_gray_meta;
    (* ASYNC_REG = "TRUE" *) logic [RX_COUNT_WIDTH-1:0] rx_gray_sync;

    always_ff @(posedge clk_100mhz or negedge ref_reset_n) begin
        if (!ref_reset_n) begin
            rx_gray_meta <= '0;
            rx_gray_sync <= '0;
        end else if (!ltsm_flagToAnalog_RepairClkState) begin
            rx_gray_meta <= '0;
            rx_gray_sync <= '0;
        end else begin
            rx_gray_meta <= rx_gray_count;
            rx_gray_sync <= rx_gray_meta;
        end
    end

    function automatic logic [RX_COUNT_WIDTH-1:0] gray_to_binary(
        input logic [RX_COUNT_WIDTH-1:0] gray_value
    );
        gray_to_binary[RX_COUNT_WIDTH-1] = gray_value[RX_COUNT_WIDTH-1];
        for (int bit_index = RX_COUNT_WIDTH-2; bit_index >= 0; bit_index--) begin
            gray_to_binary[bit_index] =
                gray_to_binary[bit_index+1] ^ gray_value[bit_index];
        end
    endfunction

    wire [RX_COUNT_WIDTH-1:0] observed_count = gray_to_binary(rx_gray_sync);
    logic [RX_COUNT_WIDTH-1:0] window_start_count;
    // Deliberate 12-bit unsigned modulo subtraction handles a counter wrap.
    wire [RX_COUNT_WIDTH-1:0] window_edges = observed_count - window_start_count;

    logic [WINDOW_COUNT_WIDTH-1:0] window_cycles;
    logic [TIMEOUT_COUNT_WIDTH-1:0] timeout_cycles;
    logic window_active;
    logic timed_out;

    always_ff @(posedge clk_100mhz or negedge ref_reset_n) begin
        if (!ref_reset_n) begin
            window_start_count <= '0;
            window_cycles      <= '0;
            timeout_cycles     <= '0;
            window_active      <= 1'b0;
            timed_out          <= 1'b0;
            ltsm_flagFromAnalog_clkPatternReceived <= 1'b0;
        end else if (!ltsm_flagToAnalog_RepairClkState) begin
            window_start_count <= '0;
            window_cycles      <= '0;
            timeout_cycles     <= '0;
            window_active      <= 1'b0;
            timed_out          <= 1'b0;
            ltsm_flagFromAnalog_clkPatternReceived <= 1'b0;
        end else if (!ltsm_flagFromAnalog_clkPatternReceived && !timed_out) begin
            // The deadline has priority over a coincident window completion.
            if (timeout_cycles == TIMEOUT_COUNT_WIDTH'(TIMEOUT_REF_CYCLES-1)) begin
                timed_out     <= 1'b1;
                window_active <= 1'b0;
            end else begin
                timeout_cycles <= timeout_cycles + 1'b1;

                if (!window_active) begin
                    if (observed_count != '0) begin
                        window_start_count <= observed_count;
                        window_cycles      <= '0;
                        window_active      <= 1'b1;
                    end
                end else if (window_cycles == WINDOW_COUNT_WIDTH'(WINDOW_REF_CYCLES-1)) begin
                    if ((window_edges >= RX_COUNT_WIDTH'(MIN_RX_EDGES)) &&
                        (window_edges <= RX_COUNT_WIDTH'(MAX_RX_EDGES))) begin
                        ltsm_flagFromAnalog_clkPatternReceived <= 1'b1;
                    end
                    window_start_count <= observed_count;
                    window_cycles      <= '0;
                end else begin
                    window_cycles <= window_cycles + 1'b1;
                end
            end
        end
    end

    // Parameter checks for simulation/elaboration. Recompute the edge bounds
    // whenever the window length or either clock frequency changes.
    // synthesis translate_off
    initial begin
        if (WINDOW_REF_CYCLES < 1)
            $fatal(1, "WINDOW_REF_CYCLES must be positive");
        if (TIMEOUT_REF_CYCLES <= WINDOW_REF_CYCLES + 4)
            $fatal(1, "TIMEOUT_REF_CYCLES must allow acquisition plus a full window");
        if ((MIN_RX_EDGES < 1) || (MIN_RX_EDGES > MAX_RX_EDGES) ||
            (MAX_RX_EDGES >= (1 << RX_COUNT_WIDTH)))
            $fatal(1, "Invalid RX edge-count acceptance bounds");
    end
    // synthesis translate_on

endmodule

`default_nettype wire
