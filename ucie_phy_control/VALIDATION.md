# Validation record: Ctrl800 + PhyTxSequencer TX pattern control

> **Status (2026-11-12): written, NOT yet run.** The RTL restructure (single seq_* link, `PhyTxSequencer`, synchronous endpoints) and the new testbenches below have not been linted or simulated. No Verilator was available in the authoring environment. Run `tests/run_tests.sh` and the `systemVerilog/test` regression, then replace this banner with the results (pass/fail counts, seeds, tool version) and the hashes of the tested sources.
>
> All results from earlier versions (byte-interface endpoints, four separate links) are obsolete, and their logs were removed from `validation/`.

## How to run

```
cd ucie_phy_control
tests/run_tests.sh                     # lint + tb_phy_tx_sequencer (8 seeds) + tb_ltsm_specialized
SEEDS="1 2 3 4 5 6 7 8 9 10" tests/run_tests.sh
tclsh constraints/check_template.tcl   # SDC template syntax/binding guards (not STA)
cd ../systemVerilog && test/run_tests.sh all   # full digital regression
```

`run_tests.sh` treats lint warnings as fatal. It lints `LtsmPhyPatternCtrl800`, `PhyTxSequencer`, `PhyPatternTx500`, `PhyPatternData2g`, `PhyPatternValid2g`, `PhyPatternValid500m` and `PhyPatternClock2g` each as its own top, then lints `PhyTxControlTop` with its parts.

## Test plan

### `tests/tb_phy_tx_sequencer.sv`

Clocks: 2 GHz and 500 MHz phase aligned. 800 MHz runs at a random phase taken from `+SEED`. Link delays are unequal: req 170 ps, op/mask 430 ps, ack 220 ps. Three `PhyTxControlTop` configurations run in parallel from one 800 MHz source:

| Case | PRE/POST | CLK_LEN | Note |
| --- | --- | --- | --- |
| c0 default | 4 / 4 | 96 | |
| c1 shortpost | 4 / 1 | 32 | minimum clock trail after the 500 MHz LFSR outputs (8 UI) |
| c2 longpre | 12 / 6 | 32 | |

Checked continuously in every case:
- **Legal rows.** Every cycle, the sequencer outputs form exactly one legal row of the endpoint table: Idle, clock-only, VAL, ID, LFSR with lanes = mask, SEED with all lanes, or ACTIVE with all lanes and ready.
- **Envelope per command.** The run-length trace must be exact:
  - Training command: PRE, then BODY for its exact length (32/64/128/`CLK_LEN`/1), then POST. CLK_TRAIN and RESEED have BODY only.
  - ACTIVE: exactly PRE clock-only cycles, then ACTIVE. It is never acked and is left only through reset.
  - No idle gap inside a command. Ack rises only with the clock enable already off.
- **Fixed latency.** Every edge of every endpoint output must equal the corresponding sequencer edge, delayed by exactly one cycle of the endpoint clock (8 UI at 2 GHz, 32 UI at 500 MHz), with the same value. This covers every Tx500 lane individually, so all lanes start on the same cycle and masked lanes stay OFF. The measured latency is printed as `LATENCY ...` lines.
- **Data2g.** LSB first, alternating every cycle, `laneID_index` is 0 when disabled, the burst ends on MSB, and a completed burst is 256 cycles.
- **Cross-checks on the endpoint outputs.**
  - Valid/data/LFSR are never active without the clock.
  - The RESEED word never appears with the clock, and its pulse lasts exactly one cycle.
  - The ACTIVE word (0000) appears only with clock = 1, valid = 000 and data = 0.

Scenarios:
- Standalone Tx500 rows, including RAW (0001), masked lanes, a held SEED that gives a single pulse, and an unknown mode.
- Every op completes normally, with LFSR masks 1111 and 1010.
- RESEED then ACTIVE (LINKINIT order). ACTIVE endpoint outputs are checked explicitly. ACTIVE must stay active with no ack, and reset must return every output to Idle.
- 16 back-to-back random training commands (ACTIVE excluded, because only reset ends it).
- Asynchronous reset in the middle of an LFSR burst: every output must be in the Idle row immediately, followed by recovery with LFSR and ACTIVE commands.

### `tests/tb_ltsm_specialized.sv` (Ctrl800 + PhyTxControlTop, LANES = 2)

- **LTSM routes.** All 13 legal state/substate routes of the 9 LTSM flags must produce:
  - the expected op on the link, with the mask all ones;
  - the expected PHY outputs;
  - exactly one Finished pulse on the owner flag, and no retrigger while a flag is held.
- **RESEED.** A reset-scrambler flag gives one RESEED, a one-cycle seed pulse on all lanes, no clock and no Finished.
- **Custom JTAG burst.** Gives LFSR with the programmed mask and no Finished.
- **LINKINIT then ACTIVE.** The reseed is sent before ACTIVE on the link and at the PHY. The ACTIVE PHY outputs are correct, and `busy` stays high in ACTIVE. With no stop, leaving state 8 does not end ACTIVE: the clock, Tx500 ACTIVE and `ltsm_active_ready` stay on. Only reset returns the PHY to Idle.
- **ACTIVE after reset.** Entering 8 again launches ACTIVE once.
- **TRAIN_ERROR during an LFSR training.** The running burst is not cut short. It completes with no Finished, the queued training is discarded, and no error bit is set.
- **Errors.** An illegal state sets `error[1]`. A third request while one runs and one is queued sets `error[2]`, and the queued request still completes.

### `systemVerilog/test` regression

Changes in that directory:
- `sources.f` now lists `../src/LtsmPhyPatternCtrl800.sv`. It was missing although `UcieDigitalTopJtag` instantiates it.
- The three benches that instantiate `UcieDigitalTopJtag` tie the new `seq_ack_i` and `seq_active_ready_i` inputs to 0.

No bench referenced the removed ports.

## Limits

- The tests do not model metastability or PHY/serializer behavior. The analog waveforms (VALTRAIN pattern, forwarded clock, lane-ID bytes, LFSR data) are outside this RTL.
- The SDC template check is not STA. The 0.5 ns SEQ -> 2 GHz single-cycle paths must be closed in the real flow.
