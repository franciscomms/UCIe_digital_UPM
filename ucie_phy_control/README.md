# Specialized UCIe pattern controllers

Instantiate a dedicated controller beside each type of transmitter. The generic `PhyPatternTx2g` is replaced by three independently compilable, single-clock modules. The 800 MHz front end has been updated to route commands to all four transmitter endpoints; using the old front end would omit the new links.

| Production file / main module | Place near | Responsibility |
| --- | --- | --- |
| `LtsmPhyPatternCtrl800.sv` | UCIe digital, 800 MHz | Capture LTSM requests, select the endpoint, queue one pending request, synchronize return completion |
| `PhyPatternTx500.sv` | 500 MHz data-lane bank | Existing 32-bit LFSR-word burst control; unchanged from the previous package |
| `PhyPatternData2g.sv` | 2 GHz data-lane bank | Lane-ID byte transmission only, shared across synchronous participating data lanes |
| `PhyPatternValid2g.sv` | Valid transmitter, 2 GHz control | Level controls `phyTrainLfsr` / `phyTrainValid` / `phyTrainLaneid` to the analog front end for 130 iterations |
| `PhyPatternClock2g.sv` | Clock transmitter, 2 GHz control | Level control `phyDigControl` to the analog front end for 130 iterations |

There are five production files in total. Each contains its own uniquely named local helpers and requires only its own clock. `rtl.f` lists the production sources; no generic 2 GHz controller or old shared helper file is required. Preserve the five main instance hierarchies and assign physical regions in the synthesis/place-and-route flow. File boundaries alone do not enforce physical placement.

## What is specialized

| Endpoint | Counter | Command information crossing from 800 MHz | Removed from this endpoint |
| --- | --- | --- | --- |
| Data 2 GHz | 9-bit remaining-byte counter, initialized to 256 | Lane mask only, plus handshake | Generic kind/count bus, valid/clock/LFSR logic |
| Valid 2 GHz | 8-bit remaining-cycle counter, initialized to 130 | 3-bit training-bit select plus handshake | Lane mask, byte/ready interface, finish handshake, pattern generation |
| Clock 2 GHz | 8-bit remaining-cycle counter, initialized to 130 | Event handshake only | Lane mask, byte/ready interface, finish handshake, pattern generation |

These are structural reductions, not a measured silicon-area claim. Separate endpoints add separate CDC/command state, so total area depends on synthesis and the physical implementation.

## Data lane connections

`PhyPatternData2g` controls only lane ID. Each selected data lane supplies its own pattern bytes. It accepts exactly 256 bytes per lane, corresponding to 128 repetitions of the 16-bit lane-ID pattern. Reset the lane-ID byte index on registered `phy_data_start`, then advance only on the shared `phy_data_byte_fire`.

`phy_data_byte_ready[lane]` means local capacity. All selected lanes must accept only on the common `phy_data_byte_fire`; independent ready/valid acceptance would destroy alignment. The fixed burst ends after the 256th accepted byte. `phy_data_byte_last` is qualified by byte_fire.

After normal completion or abort, each participating data path still transports one ordered zero-data fence after its buffered bytes. `phy_data_fence_ready` is local enqueue capacity; enqueue on common `phy_data_fence_fire`. Toggle `phy_data_retire_toggle[lane]` only after its fence reaches the terminal serializer and all preceding bits have physically completed. The controller waits for every selected lane. The data file contains `PhyTxSerializerFence` for those terminal consumers.

Keep separate persistent retirement histories for the 500 MHz LFSR stream and the 2 GHz lane-ID stream. Do not mux unrelated toggles into an endpoint. The global front end serializes the commands, and data mux ownership can use local `phy_data_active`: select lane ID while it is active, otherwise use valid bytes from the existing stream gearbox. Do not feed asynchronous `phy500_active` directly into a 2 GHz mux.

## Valid lane connections: analog level controls

Instantiate one `PhyPatternValid2g` beside the valid transmitter. The valid pattern itself is generated in the analog front end; this endpoint only drives three registered level-control bits:

| Output | Meaning |
| --- | --- |
| `phyTrainLfsr` | Valid pattern accompanies an LFSR pattern |
| `phyTrainValid` | VALTRAIN pattern |
| `phyTrainLaneid` | Valid pattern accompanies a lane-ID pattern |

While **any** of the three is 1 the analog front end sends the valid pattern; while all are 0 it sends nothing.

- `cmd_sel_async_i[2:0] = {lfsr, valid, laneid}` selects which bit(s) are raised. It is bundled command data: hold it stable from before request until acknowledgment returns low. It is captured once after request synchronization. The current 800 MHz front end only issues VALTRAIN, so tie it to `3'b010` until the front end routes LFSR/lane-ID selections here.
- Each command holds the selected bit(s) high for `ITERATIONS` (default **130**) valid-pattern iterations of `CYCLES_PER_ITERATION` (default 1) `clock_tx2g` cycles each, then drops them and acknowledges the command.
- Cancellation drops the bits on the next local edge and acknowledges with `cmd_aborted_o=1`. A command cancelled before start raises nothing.

There is no ready, byte or finish handshake on the analog side. If the analog block needs time to stop after the bit falls, that latency is not covered by the command acknowledgment.

## Clock lane connections: analog level control

Instantiate one `PhyPatternClock2g` beside the clock transmitter. It drives a single registered bit, `phyDigControl`:

- `phyDigControl = 1`: the analog front end sends the forwarded clock.
- `phyDigControl = 0`: the clock is not sent.

Each command holds `phyDigControl` high for `ITERATIONS` (default **130**) valid-pattern iterations of `CYCLES_PER_ITERATION` (default 1) `clock_tx2g` cycles each, then drops it and acknowledges. Cancellation behaves as for valid. The previous on/off clock-repair byte sequence (16 on + 8 low periods) is no longer generated here; the clock is sent continuously while the bit is high.

This controller implements the clock-pattern request only. Normal forwarded-clock operation during data/valid transmission remains part of the PHY clock policy. Physical pin selection, redundant clock/valid mapping, tristate controls and analog behavior are not inferred here.

## Front-end wiring

Keep all original LTSM request, state, lane-mask, completion and diagnostic ports on `LtsmPhyPatternCtrl800`. Connect four separate links:

| Source port prefix | Endpoint | Payload |
| --- | --- | --- |
| `tx500_*` | `PhyPatternTx500` | Existing `tx500_payload_o[LANES+17:0]` to `cmd_payload_async_i` |
| `txdata2g_*` | `PhyPatternData2g` | `txdata2g_lane_mask_o[LANES-1:0]` to `cmd_lane_mask_async_i` |
| `txvalid2g_*` | `PhyPatternValid2g` | None from the front end yet; tie `cmd_sel_async_i` to `3'b010` |
| `txclock2g_*` | `PhyPatternClock2g` | None |

For each prefix, connect `_req_o` to `cmd_req_async_i`, `_cancel_o` to `cmd_cancel_async_i`, `_ack_i` from `cmd_ack_o`, and `_aborted_i` from `cmd_aborted_o`. Valid and clock therefore need only four command/result wires each, in addition to clock/reset and their local PHY signals.

The front end holds each request until completion and waits for the entire request/acknowledgment return-to-zero before issuing another endpoint command. Payloads and masks remain stable through that handshake. Each receiving endpoint starts with local request/cancel synchronizers; return acknowledgments synchronize at the 800 MHz source. One pending LTSM request is retained while an old operation drains. Cancellation suppresses the original Finished pulse and reports `ltsm_pattern_aborted`; source error bits retain their previous meanings.

## Counts, pacing and reset

Training counts: LFSR 128 x 32-bit words, lane ID 256 x 8-bit bytes. Valid and clock hold their analog control bit(s) for 130 iterations (provisional value, parameter `ITERATIONS`). Counts are per participating path, not multiplied by lane count. These correspond to the supplied RTL and UCIe training definitions used in the previous version.

At 2 GHz, accepting eight bits every clock means 16 Gb/s. MBINIT uses 4 GT/s; ready/serializer pacing must reflect the actual configured rate. Correct accepted counts alone do not prevent on-wire gaps: data, valid and clock PHYs must maintain continuous required waveforms without underflow or unintended repetition.

Use common asynchronous reset assertion for the source, all endpoints, local finish producers and retirement-toggle producers. Each endpoint supplies its own synchronized reset release. Use `reset_ltsm_n` for the LTSM too, or hold requests inactive until it releases. Independent in-flight reset of one region is unsupported.

## Timing and validation

The SDC binding template identifies the four request/cancel/ack routes, all return-result bundles, the 500 MHz command payload and the data-lane mask. It deliberately has no valid/clock payload route. Bind it to the actual synthesized pins. Conservative propagation budgets are one destination period; distant routing must meet those limits or the CDC capture protocol/budget must be re-proven. Keep each synchronizer chain together at its receiving region. Do not use broad false paths that disable required bundle/control max-delay checks.

`tests/run_tests.sh` elaborates each production file separately and runs specialized endpoint and full front-end regressions. Test wiring is simulation-only. `VALIDATION.md` records actual results and limits. No real PHY or serializer RTL was supplied, so physical timing, continuous wire behavior, analog clock generation and actual output-completion integration still require implementation verification.
