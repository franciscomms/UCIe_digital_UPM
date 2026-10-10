// Twelve writable 32-bit registers and two 64-bit registers, using UCIe layouts.
// This simple bank does not enforce RO, reserved-bit, W1C or capability rules:
// software and local hardware are responsible for the values they write.
// Link DVSEC uses 0x00C/0x010/0x014; PHY uses full addresses from 0x1000.
// Reads are combinational; writes occur on rising edges, with local priority.
module UCIePhyRegisterBlock (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Local port: write one 32-bit word when we=1.
    input  logic        local_we_i,
    input  logic [31:0] local_addr_i,
    input  logic [31:0] local_wdata_i,
    output logic [31:0] local_rdata_o,

    // SB port: keep we/address/data/BE stable until an edge with waccepted=1.
    input  logic        sb_we_i,
    input  logic [31:0] sb_addr_i,
    input  logic [31:0] sb_wdata_i,
    input  logic [3:0]  sb_be_i,
    output logic [31:0] sb_rdata_o,
    output logic        sb_waccepted_o,
    output logic [31:0] phy_control_o
);
    // UCIe Link Capability, address 0x00C (9.5.1.4, Table 9-8).
    // Advertises Link and Adapter capabilities to software. Writable here like the
    // existing registers; RO, HWInit and reserved-field rules are not enforced.
    // [0] Raw Format; [3:1] max width: 0=x16, 1=x32, 2=x64, 3=x128, 4=x256, 7=x8;
    // [7:4] max speed: 0=4, 1=8, 2=12, 3=16, 4=24, 5=32 GT/s; [8] Retimer;
    // [9] multi-protocol; [10] Advanced Package; [15:11] Streaming Flit Formats;
    // [16] enhanced multi-protocol; [17] PCIe standard start header;
    // [18] PCIe latency-optimized optional bytes; [19] parity error signaling;
    // [20] Advanced module width: 1=x32, 0=x64; [21] x32 support in x64 module;
    // [22] Standard module width: 1=x8, 0=x16; [23] sideband PMO; [31:24] reserved.
    logic [31:0] ucie_link_capability_q;

    // UCIe Link Control, address 0x010 (9.5.1.5, Table 9-9).
    // Stores requested settings. This bank does not start training, automatically
    // clear command bits, or constrain values against Link Capability.
    // [0] Raw enable; [1] multi-protocol; [5:2] target width; [9:6] target speed;
    // [10] start training; [11] retrain; [12] unused; [17:13] Streaming formats;
    // [18] enhanced multi-protocol; [19] PCIe standard start header;
    // [20] PCIe latency-optimized optional bytes; [21] sideband PMO; [31:22] reserved.
    logic [31:0] ucie_link_control_q;

    // UCIe Link Status, address 0x014 (9.5.1.6, Table 9-10).
    // Stores observed Link results. This bank does not implement RO, RW1C/RW1CS,
    // mirroring, or automatic event/status updates.
    // [0] Raw enabled; [1] multi-protocol; [2] enhanced multi-protocol;
    // [3] x32 Advanced module; [6:4] reserved; [10:7] active width;
    // [14:11] active speed; [15] Link up; [16] training; [17] status changed;
    // [18] bandwidth changed; [19] correctable error; [20] non-fatal error;
    // [21] fatal error; [25:22] Flit Format; [26] sideband PMO; [31:27] reserved.
    logic [31:0] ucie_link_status_q;

    // PHY Capability, address 0x1000 (UCIe Table 9-47).
    // Describes the PHY's supported features. Initialize it to match the hardware;
    // consumers read it before choosing settings. Writable here like any register.
    // [2:0] reserved; [3] RX termination support; [4] TX equalization support;
    // [9:5] TX swing code: 1=0.40 V, 2=0.45 V, ... 16=1.15 V;
    // [10] reserved; [12:11] RX clock: 00=strobe/free-running, 10=free-running only;
    // [14:13] phase: 00=differential, 01/10=quadrature at 24/32 GT/s and
    // differential up to 16 GT/s; [15] package: 1=Standard, 0=Advanced;
    // [16] TCM support; [31:17] reserved. Other field encodings are reserved.
    logic [31:0] phy_capability_q;

    // PHY Control, address 0x1004 (UCIe Table 9-48).
    // Stores requested settings. The PHY controller reads phy_control_o and
    // applies them; writing Control does not automatically change Status.
    // [2:0] reserved; [3] RX termination enable; [4] TX equalization enable;
    // [5] RX clock: 0=strobe, 1=free-running; [6] phase: 0=differential only,
    // 1=quadrature at 24/32 GT/s and differential up to 16 GT/s;
    // [7] force x32 in Advanced x64 (not applicable to Standard Package);
    // [8] force x8 in Standard x16 for debug, only without lane reversal;
    // [31:9] reserved. The caller must select supported settings.
    logic [31:0] phy_control_q;

    // PHY Status, address 0x1008 (UCIe Table 9-49).
    // Stores observed results provided by PHY hardware, for external monitoring.
    // Both ports can overwrite it; callers must avoid replacing real status with
    // requested settings. Clock fields describe the REMOTE partner, not Control.
    // [2:0] reserved; [3] actual local RX termination; [4] actual local TX EQ;
    // [5] remote RX clock mode: 0=strobe, 1=free-running;
    // [6] remote phase: 0=differential, 1=quadrature at 24/32 GT/s;
    // [7] lane reversal within the module; [31:8] reserved.
    logic [31:0] phy_status_q;

    // PHY Initialization and Debug, address 0x100C (9.5.3.25, Table 9-50).
    // NOT USED IN THE CURRENT VERSION: storage only; no LTSM pause/resume logic.
    // Software can select a training pause point for future debug integration.
    // [2:0] initialization control: 000=normal training to ACTIVE;
    // 001=pause after MBINIT.PARAM step 2; 010=after MBTRAIN.VALVREF step 1;
    // 011=after MBTRAIN.RXDESKEW step 1; 100=after MBTRAIN.DATATRAINCENTER2
    // step 1 (the last two apply to initial training and retraining).
    // Other codes reserved. [4:3] reserved; [5] Resume Training: a 0->1
    // transition requests continuation; [31:6] reserved. Reset: zero.
    // Future LTSM integration must disable the relevant timeouts while paused;
    // a corresponding remote sideband message can also allow training to resume.
    // This register does not automatically start training or clear Resume Training.
    logic [31:0] phy_init_debug_q;

    // Training Setup 1, module 0, address 0x1010 (9.5.3.26, Table 9-51).
    // Configuration for the pattern generator/training controller, not results.
    // Software/FW may program it via SB before a test; local PHY may configure it
    // if the integration assigns ownership to hardware. No automatic updates here.
    // [2:0] data pattern: 000=per-lane LFSR, 001=per-lane ID;
    // PHY-Compliance only: 010=AA clock, 011=all zeros, 100=all ones,
    // 101=inverted clock. Other codes reserved.
    // [5:3] valid pattern: 000=functional 1111 0000 (LSB first); others reserved.
    // [9:6] clock phase: 0=TX-found clock PI center, 1=left training edge,
    // 2=right training edge; others reserved. [10] mode: 0=continuous, 1=burst.
    // [26:11] burst duration in UI (not bank clock cycles), default 4.
    // [31:27] reserved. Other fields default zero: reset word = 0x00002000.
    logic [31:0] training_setup1_q;

    // Training Setup 2, module 0, address 0x1020 (9.5.3.27, Table 9-52).
    // Complements Setup 1: the pattern controller executes burst/idle iterations.
    // [15:0] idle count: low duration after a burst in UI, default 4.
    // [31:16] iterations of burst followed by idle, default 4.
    // Reset = 0x00040004. RW configuration; counters live outside this bank.
    logic [31:0] training_setup2_q;

    // Training Setup 3, module 0, addresses 0x1030/0x1034 (9.5.3.28, Table 9-53).
    // RX comparison lane mask: bit n=1 excludes lane n from comparison;
    // bit n=0 does not mask it. It does not turn lanes off or mark them failed.
    // [63:0] lane mask, reset zero (none masked). The RX comparator consumes it.
    // 0x1030 accesses [31:0]; 0x1034 accesses [63:32]. Writes preserve the other
    // half; two accesses are not atomic. Program while idle or coordinate use.
    logic [63:0] training_setup3_q;

    // Training Setup 4, module 0, address 0x1050 (9.5.3.29, Table 9-54).
    // RX comparison configuration, not an error counter. Reset: zero.
    // [3:0] redundant repair-lane mask: bit 0 masks RD0, bit 1 masks RD1, etc.
    // [15:4] per-lane comparison error threshold for counting to start.
    // [31:16] aggregate comparison error threshold for counting to start.
    // Threshold zero counts all errors. Repair-lane applicability depends on PHY.
    // Thresholds are carried in the corresponding TX/RX-initiated Data-to-Clock
    // point-test and eye-sweep SB messages: remote uses them for TX-initiated
    // tests; RX uses them locally and informs the remote for RX-initiated tests.
    // Caller controls settings; comparison and message generation are external.
    logic [31:0] training_setup4_q;

    // Current Lane Map Module 0, addresses 0x1060/0x1064 (UCIe 9.5.3.30,
    // Table 9-55, D2D/PHY offset 0x1060). Reset: all zero.
    // Bit n indicates physical RX lane n is operational. PHY training logic
    // supplies the map; writing it does not activate or repair physical lanes.
    // Standard Package uses [15:0]; [63:16] do not apply and callers should keep
    // them zero. This simple RW bank does not enforce that restriction.
    // 0x1060 accesses [31:0]; 0x1064 accesses [63:32]. Each write preserves the
    // other half. Two accesses are not atomic; coordinate snapshots externally.
    logic [63:0] current_lane_map_module0_q;

    // Error Log 0, address 0x1080 (UCIe Table 9-59, module 0).
    // Training history for diagnosis. The LTSM builds and writes this word;
    // this bank does not shift states or detect training failures automatically.
    // [7:0] latest state N; [8] lane reversal; [9] width degradation (Standard);
    // [15:10] reserved; [23:16] state N-1; [31:24] state N-2.
    // State encodings (hex), also used by N-3 in Log 1:
    // 00 RESET, 01 SBINIT, 02 MBINIT.PARAM, 03 MBINIT.CAL, 04 MBINIT.REPAIRCLK,
    // 05 MBINIT.REPAIRVAL, 06 MBINIT.REVERSALMB, 07 MBINIT.REPAIRMB,
    // 08 MBTRAIN.VALVREF, 09 MBTRAIN.DATAVREF, 0A MBTRAIN.SPEEDIDLE,
    // 0B MBTRAIN.TXSELFCAL, 0C MBTRAIN.RXSELFCAL, 0D MBTRAIN.VALTRAINCENTER,
    // 0E MBTRAIN.VALTRAINVREF, 0F MBTRAIN.DATATRAINCENTER1,
    // 10 MBTRAIN.DATATRAINVREF, 11 MBTRAIN.RXDESKEW, 12 MBTRAIN.DATATRAINCENTER2,
    // 13 MBTRAIN.LINKSPEED, 14 MBTRAIN.REPAIR, 15 PHYRETRAIN, 16 LINKINIT,
    // 17 ACTIVE, 18 TRAINERROR, 19 L1/L2; other encodings reserved.
    logic [31:0] error_log0_q;

    // Error Log 1, address 0x1090 (UCIe Table 9-60, module 0).
    // Additional history and PHY error flags, supplied explicitly by the caller.
    // [7:0] state N-3; [8] training timeout escalated to fatal;
    // [9] sideband handshake timeout, excluding training messages;
    // [10] remote LinkError request over RDI sideband; [11] internal PHY error;
    // [31:12] reserved. All bits are ordinary RW in this simplified bank:
    // writing 1 stores 1, writing 0 stores 0. No automatic events or W1C/W1S.
    // Callers coordinate updates and preserve any history/errors they want to keep.
    logic [31:0] error_log1_q;

    // Two independent combinational read ports; unknown addresses return zero.
    always_comb begin
        case (local_addr_i)
            32'h00C: local_rdata_o = ucie_link_capability_q;
            32'h010: local_rdata_o = ucie_link_control_q;
            32'h014: local_rdata_o = ucie_link_status_q;
            32'h1000: local_rdata_o = phy_capability_q;
            32'h1004: local_rdata_o = phy_control_q;
            32'h1008: local_rdata_o = phy_status_q;
            32'h100C: local_rdata_o = phy_init_debug_q;
            32'h1010: local_rdata_o = training_setup1_q;
            32'h1020: local_rdata_o = training_setup2_q;
            32'h1030: local_rdata_o = training_setup3_q[31:0];
            32'h1034: local_rdata_o = training_setup3_q[63:32];
            32'h1050: local_rdata_o = training_setup4_q;
            32'h1060: local_rdata_o = current_lane_map_module0_q[31:0];
            32'h1064: local_rdata_o = current_lane_map_module0_q[63:32];
            32'h1080: local_rdata_o = error_log0_q;
            32'h1090: local_rdata_o = error_log1_q;
            default: local_rdata_o = 32'b0;
        endcase
        case (sb_addr_i)
            32'h00C: sb_rdata_o = ucie_link_capability_q;
            32'h010: sb_rdata_o = ucie_link_control_q;
            32'h014: sb_rdata_o = ucie_link_status_q;
            32'h1000: sb_rdata_o = phy_capability_q;
            32'h1004: sb_rdata_o = phy_control_q;
            32'h1008: sb_rdata_o = phy_status_q;
            32'h100C: sb_rdata_o = phy_init_debug_q;
            32'h1010: sb_rdata_o = training_setup1_q;
            32'h1020: sb_rdata_o = training_setup2_q;
            32'h1030: sb_rdata_o = training_setup3_q[31:0];
            32'h1034: sb_rdata_o = training_setup3_q[63:32];
            32'h1050: sb_rdata_o = training_setup4_q;
            32'h1060: sb_rdata_o = current_lane_map_module0_q[31:0];
            32'h1064: sb_rdata_o = current_lane_map_module0_q[63:32];
            32'h1080: sb_rdata_o = error_log0_q;
            32'h1090: sb_rdata_o = error_log1_q;
            default: sb_rdata_o = 32'b0;
        endcase
    end

    assign phy_control_o = phy_control_q;
    // Combinational acceptance at the clock edge, not a delayed completion pulse.
    // Continuous local writes defer SB. Unmapped SB writes are acknowledged no-ops.
    assign sb_waccepted_o = rst_ni && sb_we_i && !local_we_i;

    // Register updates. Keep the previous example reset values explicitly.
    // Domain Reset clears history; Link Down alone must not assert this reset.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ucie_link_capability_q <= 32'h0000_0001;
            ucie_link_control_q    <= 32'h0000_0000;
            ucie_link_status_q     <= 32'h0000_0000;
            phy_capability_q <= 32'h0000_8028;
            phy_control_q    <= 32'h0000_0008;
            phy_status_q     <= 32'h0000_0008;
            phy_init_debug_q <= 32'h0000_0000;
            training_setup1_q <= 32'h0000_2000;
            training_setup2_q <= 32'h0004_0004;
            training_setup3_q <= 64'h0000_0000_0000_0000;
            training_setup4_q <= 32'h0000_0000;
            current_lane_map_module0_q <= 64'h0000_0000_0000_0000;
            error_log0_q     <= 32'h0000_0000;
            error_log1_q     <= 32'h0000_0000;
        end else if (local_we_i) begin
            case (local_addr_i)
                32'h00C: ucie_link_capability_q <= local_wdata_i;
                32'h010: ucie_link_control_q    <= local_wdata_i;
                32'h014: ucie_link_status_q     <= local_wdata_i;
                32'h1000: phy_capability_q <= local_wdata_i;
                32'h1004: phy_control_q    <= local_wdata_i;
                32'h1008: phy_status_q     <= local_wdata_i;
                32'h100C: phy_init_debug_q <= local_wdata_i;
                32'h1010: training_setup1_q <= local_wdata_i;
                32'h1020: training_setup2_q <= local_wdata_i;
                32'h1030: training_setup3_q[31:0] <= local_wdata_i;
                32'h1034: training_setup3_q[63:32] <= local_wdata_i;
                32'h1050: training_setup4_q <= local_wdata_i;
                32'h1060: current_lane_map_module0_q[31:0]  <= local_wdata_i;
                32'h1064: current_lane_map_module0_q[63:32] <= local_wdata_i;
                32'h1080: error_log0_q     <= local_wdata_i;
                32'h1090: error_log1_q     <= local_wdata_i;
                default: begin end
            endcase
        end else if (sb_waccepted_o) begin
            // BE selects bytes only
            for (int b = 0; b < 4; b++) begin
                if (sb_be_i[b]) begin
                    case (sb_addr_i)
                        32'h00C: ucie_link_capability_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h010: ucie_link_control_q[b*8 +: 8]    <= sb_wdata_i[b*8 +: 8];
                        32'h014: ucie_link_status_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h1000: phy_capability_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1004: phy_control_q[b*8 +: 8]    <= sb_wdata_i[b*8 +: 8];
                        32'h1008: phy_status_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h100C: phy_init_debug_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1010: training_setup1_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1020: training_setup2_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1030: training_setup3_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1034: training_setup3_q[32+b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1050: training_setup4_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1060: current_lane_map_module0_q[b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1064: current_lane_map_module0_q[32+b*8 +: 8] <= sb_wdata_i[b*8 +: 8];
                        32'h1080: error_log0_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        32'h1090: error_log1_q[b*8 +: 8]     <= sb_wdata_i[b*8 +: 8];
                        default: begin end
                    endcase
                end
            end
        end
    end
endmodule
