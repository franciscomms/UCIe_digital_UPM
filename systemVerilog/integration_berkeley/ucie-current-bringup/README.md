# Current UPM–Berkeley serial controller bring-up

This is the adapted `UcieSerialBringUp_tb` for the UPM files supplied on
2026-09-16. It instantiates both real training state machines and both real
serial paths. The supplied implementation currently fails during SBINIT.
The package makes that failure reproducible; it does not claim ACTIVE success.

## Run this test first

Extract into a new directory, open Questa, and change to `ucie-current-bringup`.
Do not combine this file list with older kits.

```tcl
cd {/your/extracted/path/ucie-current-bringup}
do bringup.do
```

On Windows, use your actual path, for example:

```tcl
cd {C:/projects/ucie-current-bringup}
do bringup.do
```

`bringup.do` compiles `bringup.f`, loads `UcieSerialBringUp_tb`, and stops at the
first detected error. It also loads the explicitly named compilation unit so
Berkeley's generated `bind` checks elaborate. No Scala or Chisel tools are
needed: all Berkeley-generated SystemVerilog is included.

There is a real 4 ms reset wait before software start. This is Berkeley's
existing timer, not a hung test. The default first error occurs around
4.000263125 ms, immediately after the first sideband word has been received.

To retain later diagnostics, run in a fresh simulation session:

```tcl
do bringup_diagnostic.do
```

This runs the same hardware with `+STOP_ON_ERROR=0 +MAX_SBINIT=20000`. It records
errors and continues to the bounded SBINIT watchdog. It still reports FAIL.
The run writes CSV/log files in the current working directory. Save them before
running another case if you need both. Recorded local runs are under `logs/`.

The test passes only if both actual controllers leave SBINIT, bidirectional
serial traffic occurs, and no checker error occurs. It stops at that milestone;
this milestone is not MBINIT/MBTRAIN or ACTIVE completion.

## Exact hardware being simulated

UPM:

- `upm/LinkTrainingFSM.sv` is byte-identical to
  `LinkTrainingFSM(20260916-131741).sv`.
- `upm/SidebandTx.sv` is byte-identical to `SidebandTx 1 (1).sv`.
- `upm/SidebandRx.sv` and `upm/SideBandModule.sv` are byte-identical to the earlier
  uploaded originals. The old replacement FIFO/CDC receiver is not used.
- Other controller/training sources are from the original `ucie_dig_src(2).zip`.
- The only additional controller-source edit is the two agreed `AA...` to
  `55...` literals in `SidebandMsgGenerator_corregido.sv`. The exact two-line
  change is in `docs/pattern-only.patch`.

Berkeley:

- Commit `caf0daf1135f5b87225fa4903fcc3dfb87863de5` of
  <https://github.com/ucb-bar/ucie>.
- Full original `D2DAdapter` and `LogicalPhy`, including LinkTrainingSM,
  SBInit, mainband training/pattern modules, SidebandLinkNode, serializer,
  deserializer, queues, routing, and generated verification modules.
- Neither previously discussed Berkeley serializer/deserializer patch is
  applied. Original generated module names are retained, without a B_ prefix.
- `BerkeleySerialDie.scala` is the previously supplied boundary/configuration
  wrapper; it connects original Berkeley modules rather than replacing them.
- `sb_driver.v` is Berkeley's original bump-driver model. Two instances turn its
  two-phase data/clock outputs into the two physical sideband wires.

All 245 UPM/Berkeley source hashes are recorded in `source_manifest.json`.
`python scripts/check_sources.py` checks them. Source edits you make later will
intentionally make that original-snapshot check fail until its manifest is
explicitly updated.

## Necessary interface wiring

`integration/UPMSerialControllerConnection.sv` exposes the full interface of
`D2DAdapterLinkMgmtLtsmTop` and connects it to the original SideBandModule ports.
The older uploaded serial top exposed only part of that full interface; it is
preserved, uncompiled, in `reference/upm/`.

The new wrapper forwards the existing controller parameters and analog ports.
It uses the original direct receive data/valid wiring and leaves RX ready
unconnected to the serial block, exactly because the supplied SideBandModule
has no RX ready input. It neither inserts a CDC adapter nor suppresses repeated
valid events. This allows the test to expose the receive-integration defect.

Both dies have independent phase-offset 800 MHz clocks. The serial wire model
uses fixed matched clock/data propagation delays, 73 ps Berkeley-to-UPM and
91 ps UPM-to-Berkeley. No bits, fields, messages, or clock pulses are changed.

The UPM analog handshake models are adapted from the supplied bring-up harness.
No UPM mainband lane datapath was supplied; Berkeley's mainband receive input
is consequently inactive in this first SBINIT test. A full mainband training
model remains necessary after the sideband/controller issues are resolved.
No FSM state is forced and no internal done/result signal is forced.

## Current results

Static elaboration: 251 HDL files, zero errors, 990 other diagnostics using
pyslang 11.0.0. This includes the complete test hierarchy and verification
sidecars. It is not a warning-free lint report.

Actual simulation: Verilator with timing and assertions enabled. Questa is
unavailable in this environment; the supplied Questa commands have not been
executed here. Details and traces are in `docs/VALIDATION.md` and `logs/`.

| Run | Result | Observation |
|---|---|---|
| `bringup.do` equivalent | FAIL | The first physical received word is accepted twice by UPM's local controller |
| `bringup_diagnostic.do` equivalent | FAIL | Repeated receive accepts, extra Berkeley zero chunks, and OOR message mismatch; both controllers remain in SBINIT |

At the first failure each direction has exactly one 64-bit burst, with 64
sampling edges and zero wire errors. This confirms that the failure is separate
from the transmitter's corrected extra-edge problem.

The next required UPM correction is a receive event/clock-domain bridge that
holds each completed word for the local consumer and delivers it exactly once.
Clearing valid only on the next incoming serial clock edge cannot provide a
one-local-clock event when that serial clock is stopped. The diagnostic run
also preserves the further Berkeley mode-transition and SBINIT field findings;
fixing this first receive issue alone is not a demonstrated complete bring-up.

## Files to inspect

- `tb/UcieSerialBringUp_tb.sv`: actual controller co-simulation, checks, watchdog.
- `integration/UPMSerialControllerConnection.sv`: complete UPM interface wiring.
- `tb/UPMSerialBringUpModels.sv`: supplied-style UPM analog/control responses.
- `bringup.f`: complete portable compile list, relative to this directory.
- `bringup.do`: first-error run; `bringup_diagnostic.do`: extended trace run.
- `docs/VALIDATION.md`: observed failures and their concrete evidence.

Useful waveforms are `upm_ltsm`, `b_ltsm`, `b_detail`, `a_clk`, `b_clk`,
`a_data`, `b_data`, and `upm_die/dut/sb_msg_rx_valid`, `sb_msg_rx_ready`,
`sb_msg_rx_msg`. The generated hierarchy includes Berkeley's original bound
verification instances under `berkeley_die/phy/`.
