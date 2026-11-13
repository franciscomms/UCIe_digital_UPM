# CDC / related-clock integration constraints for the TX pattern control.
# Binding template only: this is not a netlist/STA or timing-closure result.
# Units: ns. Define the SoC clocks before sourcing this file.
# Assumed periods: LTSM (CTRL800) = 1.25 ns, clock_tx500 = 2.0 ns,
# clock_tx2g = 0.5 ns. Re-derive the bounds if the clocks or RTL change. The
# target STA tool must support -datapath_only max-delay semantics.
#
# Instance aliases used below:
#   CTRL800: LtsmPhyPatternCtrl800 (u_pattern_ctrl in UcieDigitalTopJtag)
#   SEQ:     PhyTxControlTop/u_seq   (PhyTxSequencer, clock_tx500)
#   CLOCK2G: PhyTxControlTop/u_clock2g, VALID2G: .../u_valid2g,
#   VALID500M: PhyTxControlTop/u_valid500m (clock_tx500),
#   DATA2G:  PhyTxControlTop/u_data2g (clock_tx2g)
#   TX500:   PhyTxControlTop/g_tx500[lane]/u_tx500 (clock_tx500)
#
# ---------------------------------------------------------------------------
# 1. CLOCK RELATIONSHIPS
# ---------------------------------------------------------------------------
# clock_tx2g and clock_tx500 come from the same source and are phase aligned
# (clock_tx500 = clock_tx2g / 4, rising edges coincide). Define clock_tx500 as
# a GENERATED clock of clock_tx2g (or of their common source) so STA times the
# SEQ -> CLOCK2G/VALID2G/DATA2G paths as ordinary SINGLE-CYCLE synchronous
# paths: launch on a clock_tx500 edge, setup check at the NEXT clock_tx2g edge
# (0.5 ns later), hold check at the launching (coincident) edge.
# The 2 GHz endpoints capture on that next edge by design (deterministic
# latency = 1 clock_tx2g cycle). Therefore:
#   - NO multicycle path on clock_tx500 -> clock_tx2g. A multicycle setup of N
#     would let the capture edge vary with routing delay and break the
#     deterministic latency.
#   - NO set_clock_groups -asynchronous / false path between clock_tx500 and
#     clock_tx2g.
# Example (adapt names/sources to the SoC clock tree):
#   create_generated_clock -name clock_tx500 -source [get_pins <div>/CLK] \
#       -divide_by 4 [get_pins <div>/Q]
#
# CTRL800 (800 MHz) is asynchronous to both. The only crossings are the five
# routes below, all bounded by max-delay. No blanket asynchronous clock groups
# or false paths: they would override these bounds.
#
# ---------------------------------------------------------------------------
# 2. BINDINGS (bind EVERY collection to EXACT synthesized pins before sourcing)
# ---------------------------------------------------------------------------
# Set CTRL_LANES to the elaborated LANES value. Pin names describe RTL intent,
# not literal get_pins patterns. Do not substitute broad "all CDC" collections.
#
# Level controls, launch Q -> ONLY the first synchronizer-stage D pin:
#   SEQ_REQ_SRC:    CTRL800/u_src_seq/req_q[0]/Q
#   SEQ_REQ_DST:    SEQ/u_req_sync/sync_q[0]/D
#   SEQ_STOP_SRC:   CTRL800/u_src_seq/stop_q/Q
#   SEQ_STOP_DST:   SEQ/u_stop_sync/sync_q[0]/D
#   SEQ_ACK_SRC:    SEQ/seq_ack_o/Q
#   SEQ_ACK_DST:    CTRL800/u_src_seq/g_lane_ack[0].u_ack_sync/sync_q[0]/D
#   SEQ_READY_SRC:  SEQ/active_ready_o/Q
#   SEQ_READY_DST:  CTRL800/u_active_ready_sync/sync_q[0]/D
#
# Bundled data (held stable around the synchronized control):
#   SEQ_CMD_SRC:    CTRL800/u_src_seq/payload_q[*]/Q   (3 + LANES pins: {op, mask})
#   SEQ_CMD_DST:    every SEQ register D pin in the fanout of seq_op_i/seq_mask_i
#                   (op_q, mask_q, state_q, cnt_q, seq_ack_o and
#                   the output flops clk_en_o, val_sel_o, lfsr_val_en_o, id_en_o, tx500_mode_o,
#                   tx500_lane_en_o, active_ready_o). These are sampled only
#                   after the request has passed u_req_sync.
#
# Why the bundle is safe: payload_q is launched one LTSM cycle BEFORE req_q
# and held until the ack has returned low; SEQ samples it only after
# SYNC_STAGES clock_tx500 edges of synchronized req. Each route must therefore settle
# within one destination period; that is what the max-delay bounds below
# enforce.

if {![info exists CTRL_LANES]} {
  error "Set CTRL_LANES to the elaborated LANES parameter before sourcing"
}
if {![string is integer -strict $CTRL_LANES] || $CTRL_LANES < 1} {
  error "CTRL_LANES must be a positive integer"
}

# Validate the entire binding before emitting any exceptions.
foreach collection_name {
  SEQ_REQ_SRC SEQ_REQ_DST SEQ_STOP_SRC SEQ_STOP_DST
  SEQ_ACK_SRC SEQ_ACK_DST SEQ_READY_SRC SEQ_READY_DST
  SEQ_CMD_SRC SEQ_CMD_DST
} {
  if {![info exists $collection_name]} {
    error "Bind $collection_name to concrete synthesized pins before sourcing"
  }
  if {[sizeof_collection [set $collection_name]] == 0} {
    error "Empty CDC collection: $collection_name"
  }
}
if {[sizeof_collection $SEQ_CMD_SRC] != ($CTRL_LANES + 3)} {
  error "Wrong command bundle width in SEQ_CMD_SRC; expected LANES+3 pins"
}
# The destination cone must at least contain op_q and mask_q (LANES+3 D pins).
if {[sizeof_collection $SEQ_CMD_DST] < ($CTRL_LANES + 3)} {
  error "SEQ_CMD_DST must cover op_q, mask_q and the rest of the payload fanout"
}
foreach collection_name {
  SEQ_REQ_SRC SEQ_REQ_DST SEQ_STOP_SRC SEQ_STOP_DST
  SEQ_ACK_SRC SEQ_ACK_DST SEQ_READY_SRC SEQ_READY_DST
} {
  if {[sizeof_collection [set $collection_name]] != 1} {
    error "Expected exactly one pin in $collection_name"
  }
}

# ---------------------------------------------------------------------------
# 3. CONSTRAINTS: each route bounded by ONE destination clock period.
# ---------------------------------------------------------------------------
# Controls into first synchronizer stages: propagation limits so a stale edge
# cannot survive into the next handshake phase. Not a setup relationship.
set_max_delay -datapath_only 2.0  -from $SEQ_REQ_SRC   -to $SEQ_REQ_DST
set_max_delay -datapath_only 2.0  -from $SEQ_STOP_SRC  -to $SEQ_STOP_DST
set_max_delay -datapath_only 1.25 -from $SEQ_ACK_SRC   -to $SEQ_ACK_DST
set_max_delay -datapath_only 1.25 -from $SEQ_READY_SRC -to $SEQ_READY_DST
# Bundled data.
set_max_delay -datapath_only 2.0  -from $SEQ_CMD_SRC   -to $SEQ_CMD_DST
# DO NOT false-path any of these five routes: in common STA exception
# precedence a false path overrides max delay and removes the bound. Use the
# tool's asynchronous first-stage min/hold treatment without disabling the
# max-delay checks; verify the tool's actual semantics.
#
# clock_tx500 -> clock_tx2g (SEQ -> CLOCK2G/VALID2G/DATA2G) and
# clock_tx500 -> clock_tx500 (SEQ -> TX500): NO exceptions. Timed as normal
# synchronous paths (see section 1). The 0.5 ns SEQ -> 2 GHz budget is the
# demanding one: place SEQ so its output flops reach the three 2 GHz
# endpoints in time.
#
# Physical integration requirements (not executable floorplan constraints):
# - Cluster each synchronizer chain in its RECEIVING region (req/stop in SEQ,
#   ack/active_ready in CTRL800).
# - Preserve hierarchies: CTRL800, SEQ, CLOCK2G, VALID2G, VALID500M, DATA2G,
#   each TX500.
# - Apply technology-specific synchronizer-cell, placement and MTBF rules;
#   ASYNC_REG/dont_touch attributes alone do not establish reliability.
# - Common asynchronous reset assertion with per-block synchronized release.
#   Reset distribution/recovery/removal constraints belong to the SoC flow.
# - Report the effective exceptions in the actual STA tool.
