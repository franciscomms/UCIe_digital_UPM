# Serial-sideband top-level tests

These testbenches instantiate `D2DAdapterLinkMgmtLtsmSBTop` from the supplied
source archive. The three top-level test names are unchanged. All 52 files in
the supplied `src/` directory remain byte-for-byte unchanged.

The die instances now use `D2DAdapterLinkMgmtLtsmSerialDieModel`, which wraps
that production top and the analog training model. The wrapper has **no
128-bit sideband packet ports**: `sb_tx_msg`, `sb_rx_msg`, and their
valid/ready ports have been removed. Its physical sideband port declarations
are:

```systemverilog
output wire logic sb_tx_dout,
output wire logic sb_tx_clk,
input  wire logic sb_rx_din,
input  wire logic sb_rx_clk,
```

The bring-up and backpressure die connections are:

| Physical link | Transmitter | Receiver | Data width |
| --- | --- | --- | --- |
| `sb_0_to_1_data`, `sb_0_to_1_clk` | `die0.sb_tx_dout`, `die0.sb_tx_clk` | `die1.sb_rx_din`, `die1.sb_rx_clk` | 1 bit |
| `sb_1_to_0_data`, `sb_1_to_0_clk` | `die1.sb_tx_dout`, `die1.sb_tx_clk` | `die0.sb_rx_din`, `die0.sb_rx_clk` | 1 bit |

Scalar `sb_tx_enable`, `sb_tx_idle`, and `sb_rx_overflow` are test control
and status signals. The production serializers still use 128-bit packet
storage internally. Passive scoreboards read those internal packets through
hierarchy; no packet bus is connected to a die instance or exposed by the
dual-die harness. The Integrated128 stimulus API is now explicitly named
`bfm_send_*` and `bfm_received_*`; these transactions reach each die through
the BFM's scalar serial data and clock pins.

## Run

Extract this archive alongside the supplied `src/` directory so that `src/`
and `test/` share a parent directory. Use a recent Verilator 5.x with timing
and force/release support, GNU Make, and a C++20 compiler:

```sh
bash test/run_tests.sh all
bash test/run_tests.sh bringup
bash test/run_tests.sh backpressure
bash test/run_tests.sh 128b +SCENARIO=retrain
```

`sources.f` contains the package-first compilation order for other
SystemVerilog simulators; its paths are relative to `test/`. Select one
testbench top per simulation. `run_tests.sh` accepts `VERILATOR`, `JOBS`,
`BUILD_DIR`, `LINT_ONLY=1`, and `TRACE=1` environment overrides. For waveforms,
use `TRACE=1 bash test/run_tests.sh bringup +VCD`. Build and run logs are
written under `test/build/` by default. Any assertion failure returns a
nonzero exit status.

## Changes

- `D2DAdapterLinkMgmtLtsmDualDieHarness.sv`: the shared die model now
  instantiates the production serial top, replacing the old packet top plus
  a separately instantiated PHY. Only one data bit and one forwarded clock
  connect each physical direction. Packet ports have also been removed from
  the die wrapper and the enclosing dual-die harness. The checker uses
  passive `mon_die*` hierarchical taps at TX FIFO admission and RX
  holding-register acceptance.
- The bring-up test checks the new top's receive-overflow indication,
  complete training/state coverage, exactly-once packet delivery, and final
  serial drain.
- The directed backpressure harness/test stalls each LTSM, RDI, and FDI
  producer in both directions and requires all six to resume successfully.
  Because the physical top has no ready pin, `link_*_enable` controls a
  simulation-only `force/release` of
  `dut.u_sideband_phy.tx_ready`. That same signal controls both FIFO enqueue
  and the upstream arbiter handshake. Already queued packets continue
  transmitting; no serial clock or data bits are gated. Ordinary bring-up
  and the 128b scenarios keep this override inactive.
- The Integrated128 harness/test retains 128-bit logical BFM transactions
  (64-bit header plus optional 64-bit payload), while every injected packet
  travels through the physical serial RX pins. During training, serial BFMs
  relay complete LTSM packets between the two dies. Directed management
  scenarios then use the BFM peer. Injection completion now waits for both
  serialization and acceptance through the integrated RX holding register.
- All harnesses fail on receive overflow. The passive serial checker also
  checks RX data/valid stability while the receiving controller is stalled,
  alongside its existing wire decoding, ordering, TX stability, and
  exactly-once checks. The serial BFM and `timescale.sv` are retained.

The harnesses use a common 10 ns controller clock and sample data on the
falling edge of the forwarded serial clock. Training keeps the existing
`cycles_1us=1000` timer scaling to allow serial traffic; this is functional
simulation timing, not a physical-rate or CDC signoff test.

## Validation against the supplied RTL

All three tops were rebuilt with the scalar-only die interfaces on
2026-10-10, with timing and assertions enabled. Execution used
the Verilator pip distribution 5.48.0 (its simulator banner reports 5.49).
The wheel needed local build environment settings
`MAKEFLAGS='CFG_CXXFLAGS_PCH_I=-include'` and `VERILATOR_ROOT` pointing at the
installed wheel; these packaging-specific settings are not imposed by the
portable runner.

| Test or 128b scenario | Result |
| --- | --- |
| Dual-die bring-up | PASS; 1,334 packets each direction; MBTRAIN masks `0x5fff`; links drained |
| Dual-die backpressure | PASS at cycle 152,103; stalled and resumed masks both `111111`; 1,334 packets each direction |
| `retrain` | PASS |
| `disabled` | FAIL: extra Adapter Req.Disable after returning to Reset |
| `linkreset` | FAIL: extra Adapter Req.LinkReset after returning to Reset |
| `linkerror` | PASS |
| `direct_reset_exits`, case `disabled` | FAIL: extra Adapter Req.Disable |
| `direct_reset_exits`, case `linkreset` | FAIL: repeated RDI Req.LinkReset |
| `direct_reset_exits`, case `linkerror` | PASS |

Consequently, the default `all` regression currently fails in the 128b
Disabled scenario. Individual scenarios were also executed so the early
failure did not hide later results. Saved outputs are in `validation_logs/`.
No duplicate-message expectation was relaxed and no source RTL was patched.

The observed failures originate before serialization:

1. In `LinkManagementController.sv`, the Disabled/LinkReset exit branches
   move FDI to Reset while issuing a registered RDI Active request. For one
   cycle, RDI still reports its previous Disabled/LinkReset state. The
   `disabled_entry_rst` / `linkreset_entry_rst` expressions treat that status
   as another entry request, and the Reset branch queues another Adapter
   request after the earlier transaction flags have cleared. Relevant source
   locations are lines 328–333, 538–567, and 733–770. The unexpected headers
   are `4500000c2000c012` and `450000092000c012`. The Disabled trace shows
   FDI=Reset/RDI=Disabled at time 2256005000, followed by the second Adapter
   enqueue at 2256015000 (trace timestamps are in ps).
2. In `RdiLinkManagementController.sv`, the Reset-to-LinkReset branch at
   lines 581–589 keeps asserting a request while `remote_notify_required`
   remains true. It lacks the already-sent-request guard used by the
   adjacent Disabled branch. The direct LinkReset trace shows repeated
   accepted RDI requests with header `0600000940004012`.

Reproduce with:

```sh
bash test/run_tests.sh 128b +SCENARIO=disabled +SERIAL_TRACE
bash test/run_tests.sh 128b +SCENARIO=linkreset +SERIAL_TRACE
bash test/run_tests.sh 128b +SCENARIO=direct_reset_exits +DIRECT_RESET_CASE=linkreset +SERIAL_TRACE
```

Compilation retains existing width/constant-comparison warnings, optional
unconnected serial-monitor output warnings, and `UNOPTFLAT` analysis
warnings in the source StallController paths. No compilation or simulator
convergence error occurred. The runner keeps warnings visible in build logs.
