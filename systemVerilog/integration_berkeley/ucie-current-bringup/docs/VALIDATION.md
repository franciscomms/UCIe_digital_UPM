# Validation — 2026-09-16

## What was executed

The latest full-interface FSM differs from the original ZIP only in the
SBINIT pattern literal. It and the fixed SidebandTx are compiled unchanged.
The original RX and SideBandModule are also compiled unchanged. The message
package has precisely the two pattern-literal edits previously explained.
Berkeley generated RTL is the unpatched full logical-PHY/adapter variant.

Pyslang 11.0.0 elaborates 251 files with 0 errors and 990 other diagnostics.
The diagnostics include widths, unused/open outputs, generated expressions,
and verification upward references. `logs/static_elaboration.log` is complete.

Verilator Python distribution 5.48.0, using the already installed toolchain,
built and executed both runs with --timing and --assert. The generation and
C++ build logs are included. This environment's wheel required explicit C++20
and PCH include flags during make; no HDL change was made to accommodate it.
Neither VCS nor Questa was executed here.

Both runs honor Berkeley's 3,200,000-cycle minimum reset residency at 800 MHz.
Software start is asserted after 3,200,128 local cycles. No timing counter or
state is forced. MAX_SBINIT is an additional test watchdog after start.

## First-error run

Command-line arguments: `+STOP_ON_ERROR=1`.

At cycle 3,200,198 (4,000,263.125 ns), the checker fails on repeated acceptance
of the same physical UPM receive word. Both LTSMs are still in SBINIT.

| Event | Time (ns) | Physical RX ID | Word |
|---|---:|---:|---|
| Original UPM serial RX completes | 4000259.017 | 1 | `00000000000000005555555555555555` |
| UPM controller accepts it | 4000259.375 | 1 | same word |
| UPM controller accepts it again | 4000263.125 | 1 | same word |

Physical RX completion is passively observed once after each falling incoming
clock edge, after the RX nonblocking assignments settle. Controller acceptance
is observed independently on its local clock when valid and ready are both
high. The test never drives either of those interfaces.

At this failure:

- UPM wire: one complete burst, 64 sampling edges, zero wire errors.
- Berkeley wire: one complete burst, 64 sampling edges, zero wire errors.
- UPM: one physical RX completion, two controller acceptances.
- Berkeley parity, timeout, and aggregate sideband fault are zero.

The cause is visible in the original SidebandRx: validReg is asserted on the
last bit and is cleared only on the next incoming clock edge. When the peer
inserts the required idle gap, valid remains asserted. The original local
LtsmSidebandRxPulseAdapter re-enters Idle after its Pulse and Gap states,
reasserts ready, and accepts that still-asserted word again. Discarding receive
ready at SideBandModule does not establish an exactly-once local handshake.

This is an RTL integration/CDC issue, not a new serialization-order issue.

## Extended diagnostic run

Arguments: `+STOP_ON_ERROR=0 +MAX_SBINIT=20000`.

This is the identical hardware. Continuing after a checker error permits
observing further behavior; it does not waive failures. The run exits with a
nonzero result at the SBINIT watchdog, cycle 3,220,128.

- UPM state: 3, SBINIT Out-of-Reset.
- Berkeley state: 1, SBINIT; detailed state 1.
- Both RDI and FDI status values: Reset.
- 19 physical UPM RX completions, 6,355 controller acceptances, 6,336 repeated
  acceptances of already-delivered physical words.
- UPM wire: 206 completed bursts and 13,196 sampled bits, zero wire errors.
  The additional 12 bits belong to the final in-progress burst at the watchdog;
  they are not an extra-edge defect.
- Berkeley wire: 19 completed bursts, 1,216 sampled bits, zero wire errors.

### Berkeley zero chunks

The decoded Berkeley-to-UPM stream contains six initial 55... bursts, followed
by zero and alternating further 55.../zero bursts. The first zero completion
occurs at 4,000,979.017 ns. UPM's router flags that zero word as unknown.

`controller_packets.csv` records the inputs actually accepted by Berkeley's
serializer: no all-zero packet was supplied for those zero bursts. Its
unchanged serializer still computes one versus two beats from live txMode.
When the controller switches to packet mode, the 55... pattern's opcode is
not classified as a header-only packet, and a zero upper half can be emitted.
No extra-clock defect is needed to explain this: each emitted burst here has
exactly 64 bits. The unpatched hardware behavior is retained in this package.

### Out-of-Reset field mismatch

The actual OOR header received over the serial wires is
`0600000040244012`. The current UPM FSM expects `0200010040244012` and compares
the complete 128-bit word against its constructed success constant.

| Field | UPM expected | Actual Berkeley RX word |
|---|---|---|
| Message info, bits 55:40 | `0001` | `0000` |
| Destination, bits 58:56 | `010` | `110` |

The headers are shown after the real serializer/deserializer path; no message
bits are rewritten by this test. Resolving these semantics remains a protocol
implementation task. This run does not adjudicate the UCIe specification's
required values, and the test does not convert them to force a match.

## Reproduction and evidence

`logs/strict/` and `logs/diagnostic/` each contain:

- `simulation.log`: simulator output and failing assertion/watchdog.
- `upm_serial_rx.csv`: one record per physical decoded receive completion.
- `controller_packets.csv`: UPM TX accepts, UPM local RX accepts, Berkeley
  serializer input accepts; the physical RX ID exposes repeated delivery.
- `upm_to_berkeley_wire.csv`, `berkeley_to_upm_wire.csv`: passive pin decoding
  and timing checks.
- `state_trace.csv`: controller state changes.

The source manifest verifies unchanged originals. The four earlier isolated
transport tests passed with this TX; these controller tests expose failures
that those transport-only scoreboards could not check.

## Remaining scope

A passing SBINIT test has not been obtained with the supplied implementation.
There is therefore no ACTIVE result. This harness is the first controller
co-simulation checkpoint, not a full UCIe compliance or payload test.
Berkeley's complete mainband logic remains present but its mainband RX is
inactive because there is no corresponding supplied UPM lane datapath.
After fixing sideband/controller issues, extend the environment with a
specified mainband/analog model before claiming MBINIT, MBTRAIN, or ACTIVE.
