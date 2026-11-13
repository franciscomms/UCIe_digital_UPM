# UCIe TX pattern control: Ctrl800 + PhyTxSequencer + five PHY endpoints

The LTSM-side controller `LtsmPhyPatternCtrl800` (800 MHz) talks over **one** CDC handshake to `PhyTxSequencer` (500 MHz). The sequencer is the only clock-domain crossing on the PHY side and the only block that counts cycles. It drives synchronous level enables to five simple endpoints. The endpoints have no synchronizers, no counters and no acknowledgments.

```
 800 MHz (async)            |  500 MHz / 2 GHz (same source, phase aligned 4:1)
                            |
 LtsmPhyPatternCtrl800      |  PhyTxControlTop
 +----------------------+   |  +-----------------------------------------------+
 | flag edge detect     |   |  | PhyTxSequencer (clock_tx500)                  |
 | legality decode      |   |  |  req/stop sync -> IDLE>PRE>BODY>POST>DONE     |
 | 1-deep queue + reseed| req,stop  |  clk_en --------------> PhyPatternClock2g |-> phyDigControl
 | ACTIVE launch / stop |---------->|  val_sel[1:0] ---------> PhyPatternValid2g |-> phyTrainValid/Laneid
 |                      |           |  lfsr_val_en ----------> PhyPatternValid500m -> phyTrainLfsr (clock_tx500)
 | Ltsm800CommandSource | op,mask   |  id_en ----------------> PhyPatternData2g  |-> digControl, laneID_index
 |                      |<----------|  tx500_mode, lane_en --> LANES x Tx500     |-> enable_LFSR, zero_ena,
 |  ack sync            | ack,abort |                           (clock_tx500)    |   load_seed, load_zero
 |  active_ready sync   |<----------|  active_ready_o ---> TX datapath           |
 +----------------------+ active_rdy  +-----------------------------------------------+
```

## Files

| File | Clock | Role |
| --- | --- | --- |
| `../systemVerilog/src/LtsmPhyPatternCtrl800.sv` | 800 MHz | LTSM flag capture, legality decode, queue, ACTIVE launch/stop, single link source (`Ltsm800CommandSource`) |
| `PhyTxSequencer.sv` | 500 MHz | The only CDC receiver and the only owner of timing. FSM, lengths, PRE/POST envelope |
| `PhyPatternClock2g.sv` | 2 GHz | `phyDigControl <= clk_en` |
| `PhyPatternValid2g.sv` | 2 GHz | `{phyTrainValid, phyTrainLaneid} <= val_sel` |
| `PhyPatternValid500m.sv` | 500 MHz | `phyTrainLfsr <= lfsr_en`. The analog front end sends the LFSR valid pattern on the 500 MHz clock |
| `PhyPatternData2g.sv` | 2 GHz | `digControl <= id_en`, LSB/MSB `laneID_index`, `lane_id` pass-through |
| `PhyPatternTx500.sv` | 500 MHz | One per lane: `mode`, `lane_en` -> the four Tx500 controls |
| `PhyTxControlTop.sv` | both | Wiring only: sequencer + Clock2g + Valid2g + Valid500m + Data2g + LANES x Tx500 |

`rtl.f` lists them in compile order. Each file contains its own uniquely named reset-synchronizer helper and elaborates on its own, except the wrapper.

## Clocks

- `clock_tx2g` (2 GHz) and `clock_tx500` (500 MHz) come from the same source and are phase aligned: every `clock_tx500` rising edge coincides with a `clock_tx2g` rising edge. One 2 GHz cycle is 8 UI and one 500 MHz cycle is 32 UI (1 UI = 62.5 ps).
- The 800 MHz LTSM clock is asynchronous to both.
- The sequencer outputs are launched by `clock_tx500` flops. The 2 GHz endpoints capture them on the **first** `clock_tx2g` edge after the launching edge. This is a normal single-cycle synchronous path (0.5 ns), with no multicycle exception, so the latency is deterministic.

## Ctrl800 <-> sequencer protocol

| Signal | Direction | Kind | Rule |
| --- | --- | --- | --- |
| `seq_req` | Ctrl800 -> seq | level | Synchronized at the sequencer. Held high until the synchronized ack is seen. |
| `seq_stop` | Ctrl800 -> seq | level | Synchronized at the sequencer. Raised to end the running command early; held until ack. Falls together with req. |
| `seq_op[2:0]`, `seq_mask[LANES-1:0]` | Ctrl800 -> seq | bundled | Driven one 800 MHz cycle **before** req rises; stable until ack has fallen. Captured once, after req synchronization. |
| `seq_ack` | seq -> Ctrl800 | level | Synchronized in Ctrl800. Rises only after the whole envelope has finished (clock off). Held until synchronized req **and** stop are both low. |
| `seq_aborted` | seq -> Ctrl800 | bundled | Stable while ack is high. 1 = ended by stop. Ctrl800 suppresses the Finished flag. |
| `active_ready` | seq -> Ctrl800, TX datapath | level | High in ACTIVE once PRE has finished (clock running). Ctrl800 returns it synchronized as `ltsm_active_ready`. |

**Stop / drain.** When the sequencer sees stop in PRE or BODY:
1. Valid bits, Data2g and the Tx500 mode go off on the next edge.
2. `clk_en` stays on for `POST_CYC` cycles.
3. `clk_en` goes off, and ack rises with aborted = 1 on the same edge.

CLK_TRAIN and RESEED have no POST, so they go straight to DONE. If stop is already high when the request is first seen, the sequencer completes immediately with aborted = 1 and sends nothing. Stop during POST changes nothing.

**When Ctrl800 asserts stop:**
- ACTIVE: whenever `ltsm_state != 8`.
- Every other command: on **entry** into `ltsm_state` 9 (TRAIN_ERROR) or 0 (RESET). The same entry also discards a queued training. Neither sets an error bit.
- ACTIVE is launched once on each entry into `ltsm_state == 8`. It goes through the 1-deep queue, so a LINKINIT reseed captured earlier is always sent first.
- A queued ACTIVE is discarded if the state leaves 8 before it launches.

## Command set (`op[2:0]`)

| op | Name | LTSM source flags | clk_en | Valid bit in BODY | Data in BODY | BODY length @500 MHz |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | CLK_TRAIN | SendClkPatterns | BODY only, no PRE/POST | none | off | `CLK_LEN` (default 96 = 128 x 24 UI) |
| 1 | VAL_TRAIN | SendValTrainPattern, valVref_sendPattern, d2cSender_sendValTrainPattern | PRE+BODY+POST | phyTrainValid | off | 32 (128 x 8 UI) |
| 2 | LANEID | ReversalMbSendLaneIDPattern, RepairMbSendLaneIDPattern | PRE+BODY+POST | phyTrainLaneid | Data2g lane ID | 64 (128 x 16 UI) |
| 3 | LFSR | dataVref_sendPattern, d2cSender_sendLfsrPattern, rxDeskew_sendLfsrPattern, custom JTAG burst | PRE+BODY+POST | phyTrainLfsr | Tx500 LFSR on masked lanes | 128 (4096 UI) |
| 4 | RESEED | the 5 reset-scrambler flags (edge detected) | 0 | none | Tx500 SEED pulse, all lanes | 1 |
| 5 | ACTIVE | `ltsm_state == 8` | PRE, continuous, POST | none | Tx500 ACTIVE, all lanes; Data2g off | until stop |

Parameters: `PRE_CYC = 4` and `POST_CYC = 4` (in 500 MHz cycles, both must be at least 1), `CLK_LEN = 96`. All trainings use 128 iterations. Normal training sends all lanes. Only the custom JTAG burst uses `ltsm_data_lane_mask`.

## Endpoint outputs per phase

| Phase | Tx500 {enable_LFSR, zero_ena, load_seed, load_zero} | Valid500m Lfsr, Valid2g {Valid, Laneid} | Data2g digControl | Clock2g phyDigControl |
| --- | --- | --- | --- | --- |
| Idle / reset | 0101 | 000 | 0 | 0 |
| PRE / POST (any op) | 0101 | 000 | 0 | 1 |
| CLK_TRAIN BODY | 0101 | 000 | 0 | 1 |
| VAL_TRAIN BODY | 0101 | 010 | 0 | 1 |
| LANEID BODY | 0101 | 001 | 1 | 1 |
| LFSR BODY, enabled lane | 1100 | 100 | 0 | 1 |
| LFSR BODY, masked-off lane | 0101 | 100 | 0 | 1 |
| RESEED (1 cycle) | 0110 | 000 | 0 | 0 |
| ACTIVE (PRE done, until stop) | 0000 | 000 | 0 | 1 |
| RAW (test only, never issued) | 0001 | 000 | 0 | 0 |

**Sequencer outputs**
- `clk_en_o`.
- `val_sel_o[1:0] = {valid, laneid}` (to Valid2g) and `lfsr_val_en_o` (to Valid500m): at most one of the three bits high, and only in BODY. `lfsr_val_en_o` is high exactly when `tx500_mode_o` is LFSR.
- `id_en_o`.
- `tx500_mode_o`: OFF=0, SEED=1, LFSR=2, ACTIVE=3, RAW=4.
- `tx500_lane_en_o`: the mask for LFSR, all ones for SEED and ACTIVE, 0 otherwise.
- `active_ready_o`.

All of them are flops decoded from the next state, so every enable of one command changes on the same `clock_tx500` edge.

**Endpoint details**
- **Tx500:** `lane_en = 0` forces OFF. SEED is edge-qualified, so `load_seed` is exactly one cycle even if the mode were held. Unknown modes behave as OFF.
- **Data2g:** `laneID_index` is 0 (LSB) on the first enabled cycle, then alternates every 2 GHz cycle. It is 0 while disabled. A LANEID body is 256 2 GHz cycles, so the burst always ends on MSB. `lane_id_o = lane_id_i` passes straight through and must be stable while `digControl` is high.

## Lengths

| op | BODY (500 MHz cycles) | BODY (UI) | Clock high (500 MHz cycles) |
| --- | --- | --- | --- |
| CLK_TRAIN | `CLK_LEN` = 96 | 3072 = 128 x 24 | 96 |
| VAL_TRAIN | 32 | 1024 = 128 x 8 | 4 + 32 + 4 = 40 |
| LANEID | 64 | 2048 = 128 x 16 | 72 |
| LFSR | 128 | 4096 = 128 x 32 | 136 |
| RESEED | 1 | 32 | 0 |
| ACTIVE | until stop | - | 4 + N + 4 |

**`CLK_LEN` is an open point.** The default of 96 assumes the analog clock pattern iteration is 24 UI: 16 UI of toggling plus 8 UI low, the UCIe forwarded-clock training pattern, with 128 iterations. If the analog block's clock iteration is 8 UI, use `CLK_LEN = 32`.

## Latencies

Latency is measured from the `clock_tx500` edge on which the sequencer output changes to the edge on which the endpoint output changes. It is fixed and identical for every edge.

| Endpoint | Latency |
| --- | --- |
| PhyPatternClock2g | 1 x 2 GHz cycle = 0.5 ns = 8 UI |
| PhyPatternValid2g | 1 x 2 GHz cycle = 0.5 ns = 8 UI |
| PhyPatternData2g | 1 x 2 GHz cycle = 0.5 ns = 8 UI |
| PhyPatternValid500m | 1 x 500 MHz cycle = 2.0 ns = 32 UI |
| PhyPatternTx500 | 1 x 500 MHz cycle = 2.0 ns = 32 UI |

There is no latency-trim pipeline: no command needs signals from different domains to line up edge for edge.
- **Lane ID:** `phyTrainLaneid` and `digControl`/`laneID_index` are all 2 GHz, so they are aligned.
- **LFSR:** `phyTrainLfsr` and `enable_LFSR` are both 500 MHz and switch on the same `clock_tx500` edge.
- **Forwarded clock:** at 2 GHz it leads the 500 MHz outputs by 24 UI. It only has to cover the burst, which the PRE/POST envelope guarantees: it leads by `PRE_CYC x 32 + 24` UI and trails by `POST_CYC x 32 - 24` UI (at least 8 UI with `POST_CYC = 1`).
- Any analog or serializer path difference must be handled in the analog block, or by adding a pipeline back into the endpoint concerned.

## Timing diagrams

LFSR training, defaults (PRE 4, POST 4). Each column is one 500 MHz cycle (32 UI). `e` is the sequencer edge on which the synchronized request is first seen.

```
500 MHz edge        e   e+1 e+2 e+3 e+4 e+5 ...  e+131 e+132 e+133 e+134 e+135 e+136 e+137
seq state          IDLE|PRE              |BODY (128 cycles)      |POST                   |DONE
seq clk_en         ____/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\____
seq lfsr_val_en    ____________________/~~~~~~~~~~~~~~~~~~~~~~~~\___________________________
seq tx500_mode=LFSR____________________/~~~~~~~~~~~~~~~~~~~~~~~~\___________________________
seq_ack            ______________________________________________________________________/~~~ (held until req, stop low)
phyDigControl      _____/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\___  (+8 UI)
phyTrainLfsr       _____________________|~~~~~~~~~~~~~~~~~~~~~~~~~|_________________________  (+32 UI, 500 MHz)
Tx500 (en lanes)   0101................|1100 (+32 UI) ..............|0101..........................
                    <- PRE 128 UI ->  <------- BODY 4096 UI ------> <- POST 128 UI ->
```

So the clock leads valid and data by 4 cycles (128 UI) and trails them by 4 cycles. `phyTrainLfsr` and the Tx500 LFSR mode switch on the same sequencer edge and are both produced in the 500 MHz domain, so at the outputs they are aligned (32 UI). The 2 GHz clock edges are 24 UI earlier, inside the PRE/POST envelope.

ACTIVE enter and exit (`ltsm_state` 7 -> 8 -> other):

```
ltsm_state (800)   7 (LINKINIT) |8 (ACTIVE) ...........................................|5/9/0
Ctrl800 link       RESEED cmd  -> ACTIVE cmd (req held) ...........................stop^ ... ack(aborted)
seq state          ..SEED|DONE| IDLE |PRE     |BODY (ACTIVE, no end)                |POST    |DONE
seq clk_en         ______________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\_____
seq tx500_mode     0 |1| 0 ..............0 0 0 0|3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 |0 0 0 0|0
active_ready_o     ______________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\___________
Tx500              0101|0110|0101 .....  0101   |0000 (functional data) ........... |0101 ........
Valid / Data2g     000 / 0 throughout (the functional path drives valid and data in ACTIVE)
phyDigControl      ______________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\_____
ltsm_active_ready  __________________________________/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\_______  (synchronized)
```

## Ctrl800 details

Unchanged from the previous version:
- Edge detection on every flag.
- The legality decode, with the same MBINIT/MBTRAIN substate numbers.
- The custom JTAG burst path.
- The 1-deep pattern queue plus the reseed slot and its ordering (reseed first for same-cycle edges).
- The error bits, `ltsm_pattern_busy` and `reset_ltsm_n`.

The K_* kinds became the ops above, and the four links became one `Ltsm800CommandSource` with payload {op, mask}, stop and the aborted return.

| Item | Behavior |
| --- | --- |
| `ltsm_pattern_error[0]` | Multiple LTSM edges in one cycle, or a JTAG edge colliding with an LTSM edge or with ACTIVE entry |
| `ltsm_pattern_error[1]` | LTSM flag in an illegal state/substate, or a zero custom mask |
| `ltsm_pattern_error[2]` | Queue overflow (pattern slot or reseed slot full) |
| Finished flags | One pulse on the owner's flag after a non-aborted command. CLK/VAL/LANEID/LFSR only. RESEED, custom and ACTIVE have no flag |
| `ltsm_pattern_busy` | Pending or running command, including **all of ACTIVE** |
| `ltsm_active_ready` | Synchronized `active_ready` from the sequencer |

Removed:
- The `ltsm_clk_active_req` input and the `clk_train_preempted` / `clk_active_q` logic.
- The onehot0 assertion on the old requests.
- All `tx500_*`, `txdata2g_*`, `txvalid2g_*` and `txclock2g_*` ports.

## Integration (`UcieDigitalTopJtag`)

The top replaces the old link ports with `seq_req_o`, `seq_stop_o`, `seq_op_o[2:0]`, `seq_mask_o[dataLaneCount-1:0]`, `seq_ack_i`, `seq_aborted_i` and `seq_active_ready_i`, and adds the status output `ltsm_active_ready`. Connect these to `PhyTxControlTop` in the PHY region. The `ltsm_clk_active_req` tie-off is gone.

`ltsm_state` reaches Ctrl800 ungated. Only the training flags are gated by `pattern_normal_enable`. As a result, ACTIVE entry launches the clock in every mode where the LTSM reaches ACTIVE.

## Reset

Reset assertion is common and asynchronous: Ctrl800, the sequencer and every endpoint share `reset_n`. Each block releases with its own reset synchronizer: `Ltsm800ResetSync`, `PhySeqResetSync`, `PhyClock2gCtrlResetSync`, `Valid2gResetSync`, `Valid500mResetSync`, `Data2gResetSync` and `Phy500CtrlResetSync`. Reset values are the Idle row of the endpoint table. Resetting a single region while a command is in flight is not supported.

## Timing constraints

`constraints/cdc_constraints.sdc` is a binding template:
- Max-delay of one destination period on the req, stop, ack and active_ready first synchronizer stages, and on the {op, mask} and aborted bundles.
- No false paths and no blanket clock groups.
- No multicycle path on 500 MHz -> 2 GHz: define `clock_tx500` as a generated clock of the 2 GHz source so STA times those paths as single-cycle (0.5 ns).

`constraints/check_template.tcl` checks only the template's syntax and binding guards. It is not STA.

## Verification

`tests/run_tests.sh` (Verilator 5.x):
- Lints every production file on its own, and the wrapper.
- Runs `tb_phy_tx_sequencer` over several seeds (`SEEDS="1 2 3"` to override).
- Runs `tb_ltsm_specialized`.

`VALIDATION.md` records what each test covers and the current status.
