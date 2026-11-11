# Validation record: clock lane with eight-bit serializer input

> **2026-11-06 — not yet re-validated.** `PhyPatternValid2g.sv` and `PhyPatternClock2g.sv` were changed to analog level controls (`phyTrainLfsr`/`phyTrainValid`/`phyTrainLaneid`, `phyDigControl`, 130 iterations each), and `tests/tb_valid_clock2g.sv` / `tests/tb_ltsm_specialized.sv` were updated to match. These compiled cleanly with Questa `vlog` but were not simulated (no simulator license available). The results and hashes below describe the previous byte-interface versions.

Validated 2026-10-31 using Verilator build `vUNKNOWN-built20260516-4e853d8` (simulation reports 5.49). All five production files independently elaborate as their own tops. All three assertion-enabled regression builds and simulations passed with no warnings or errors; warnings were treated as fatal.

The clock controller now counts accepted eight-bit serializer words, not local control-clock periods. Tests assume each payload bit becomes one serialized physical output bit.

| Test | Result and coverage |
| --- | --- |
| `tb_data_lfsr` | PASS: unchanged 500 MHz LFSR 128-word and data 256-byte paths; masks, stalls, exact stopping, delayed per-lane retirement, cancellation and reuse |
| `tb_valid_clock2g` | PASS: valid 128-byte bursts in both bit orders; clock 768-byte bursts in both bit orders; four alternating plus two zero bytes per group; 128 groups; 512 alternating / 256 zero words; stalled output stability; zero/midburst/phase-boundary/late-finish cancellation; same-channel reuse |
| Clock serialized-bit scoreboard | PASS: independently serializes all 6144 accepted bits and checks 128 groups of 16 active plus 8 low physical clock periods. Completion waits for the last modeled bit interval and the full finish acknowledgment return-to-zero. |
| `tb_ltsm_specialized` | PASS: all 13 LTSM routes, now expecting 768 accepted clock bytes; nine completion outputs; queued cross-channel abort/restart, invalid/multiple/empty-mask/overflow errors and reset recovery |
| CDC constraint-template check | PASS: unchanged 18 max-delay routes and two retirement false paths; real Tcl syntax/binding-guard test. Not STA. |

The tests use unequal inter-region transport delays: request 170 ps, payload/mask 430 ps, cancel 390 ps, acknowledgment 220 ps and result 610 ps. These fit the conservative constraints and do not model metastability.

Run `tests/run_tests.sh` with Verilator installed. The script uses unsplit generated C++ for portability with the packaged compiler. Raw run and standalone-lint logs are in `validation/`.

The serializer model verifies the output-bit sequence and completion ordering. It does not establish the real serializer bit rate, analog clock waveform timing, or gap-free throughput. At 16 Gb/s physical serialization, an alternating byte generates 8 GHz clock periods; ready pacing alone cannot make that a continuous 2 GHz clock. A 2 GHz physical forwarded clock requires 4 Gb/s bit serialization with this one-bit-to-one-bit mapping. Actual PHY/serializer integration and timing/CDC/RDC/MTBF sign-off remain required.

## Tested source hashes

- `LtsmPhyPatternCtrl800.sv`: `7796cd0a1bb821c3f53bef610621d424ffecdf0884e83a6a49b98668c8a48720`
- `PhyPatternTx500.sv`: `276df8bed96d4d4c7c48fb8a738f30714d252b729c1bb39be8bff897e9c4f97a`
- `PhyPatternData2g.sv`: `5b7951d7fa53a214377122e4561da4bb381d52a869b85162bfecf28b2081a151`
- `PhyPatternValid2g.sv`: `dc291c0345fd39e28a9ac0f90bcc17bfcc7e0bdc917427692ca7b752dbeec658`
- `PhyPatternClock2g.sv`: `f352bb0ae4333047406abcc4cd3eae98862ba5ab89ff117da3be67a227e51cfa`
