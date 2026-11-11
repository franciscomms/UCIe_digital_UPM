# CDC integration constraints for FIVE separately placed controller regions.
# Binding template only: this is not a netlist/STA or timing-closure result.
# Units: ns. Define the SoC clocks before sourcing this file.
# Assumed periods: LTSM=1.25 ns, TX500=2.0 ns, DATA2G/VALID2G/CLOCK2G=0.5 ns.
# Re-derive the bounds if the clocks or handshake RTL change. The target STA
# tool must support -datapath_only max-delay semantics.
#
# Before sourcing, bind EVERY named collection below to EXACT register pins
# in the synthesized netlist; set CTRL_LANES to the elaborated LANES value.
# Pin names below describe RTL intent, NOT literal get_pins wildcard patterns.
# Synthesis register names and Q/D pin spellings are technology/tool dependent.
# Do not substitute broad "all CDC" / "all synchronizer" collections.
#
# Instance aliases used in this documentation:
#   CTRL800: LtsmPhyPatternCtrl800    TX500: PhyPatternTx500
#   DATA2G:  PhyPatternData2g        VALID2G: PhyPatternValid2g
#   CLOCK2G: PhyPatternClock2g
# The three 2 GHz endpoints are separate physical regions. No common parent
# controller or common destination synchronizer instance is required.
#
# Held bundle launch Q pins -> local bundle capture D pins:
#   CTRL_CMD500_SRC:    CTRL800/u_src500/payload_q[*]/Q   (LANES+18 pins)
#   CTRL_CMD500_DST:    TX500/cmd_payload_q[*]/D         (LANES+18 pins)
#   CTRL_CMDDATA2G_SRC: CTRL800/u_srcdata2g/payload_q[*]/Q (LANES pins)
#   CTRL_CMDDATA2G_DST: DATA2G/cmd_lane_mask_q[*]/D       (LANES pins)
# VALID2G and CLOCK2G carry event-only commands. There are NO payload-route
# constraints for their unused, constant source payload registers.
# VALID2G/cmd_sel_async_i[2:0] is currently tied constant at integration; if it
# is later driven from CTRL800, constrain it as a held bundle like DATA2G's mask.
#
# Held result launch Q -> capture D pins (one pin in every collection):
#   CTRL_ABORT500_SRC:     TX500/cmd_aborted_o/Q
#   CTRL_ABORT500_DST:     CTRL800/u_src500/src_aborted_o/D
#   CTRL_ABORTDATA2G_SRC:  DATA2G/cmd_aborted_o/Q
#   CTRL_ABORTDATA2G_DST:  CTRL800/u_srcdata2g/src_aborted_o/D
#   CTRL_ABORTVALID2G_SRC: VALID2G/cmd_aborted_o/Q
#   CTRL_ABORTVALID2G_DST: CTRL800/u_srcvalid2g/src_aborted_o/D
#   CTRL_ABORTCLOCK2G_SRC: CLOCK2G/cmd_aborted_o/Q
#   CTRL_ABORTCLOCK2G_DST: CTRL800/u_srcclock2g/src_aborted_o/D
#
# Request launch Q -> ONLY the destination FIRST synchronizer-stage D pin:
#   CTRL_REQ500_SRC:     CTRL800/u_src500/req_q/Q
#   CTRL_REQ500_DST:     TX500/u_req_sync/sync_q[0]/D
#   CTRL_REQDATA2G_SRC:  CTRL800/u_srcdata2g/req_q/Q
#   CTRL_REQDATA2G_DST:  DATA2G/u_req_sync/sync_q[0]/D
#   CTRL_REQVALID2G_SRC: CTRL800/u_srcvalid2g/req_q/Q
#   CTRL_REQVALID2G_DST: VALID2G/u_req_sync/sync_q[0]/D
#   CTRL_REQCLOCK2G_SRC: CTRL800/u_srcclock2g/req_q/Q
#   CTRL_REQCLOCK2G_DST: CLOCK2G/u_req_sync/sync_q[0]/D
#
# Cancellation launch cones -> ONLY first synchronizer-stage D pins:
#   CTRL_CANCEL500_DST:     TX500/u_cancel_sync/sync_q[0]/D
#   CTRL_CANCELDATA2G_DST:  DATA2G/u_cancel_sync/sync_q[0]/D
#   CTRL_CANCELVALID2G_DST: VALID2G/u_cancel_sync/sync_q[0]/D
#   CTRL_CANCELCLOCK2G_DST: CLOCK2G/u_cancel_sync/sync_q[0]/D
# Each matching CTRL_CANCEL*_SRC must contain ALL THREE launch Q pins:
#   CTRL800/cancel_q/Q, CTRL800/active_kind[0]/Q,
#   CTRL800/active_kind[1]/Q.
# This covers the complete source decode/gating cone AND inter-region route.
#
# Acknowledgment launch Q -> ONLY first source-region synchronizer-stage D:
#   CTRL_ACK500_SRC:     TX500/cmd_ack_o/Q
#   CTRL_ACK500_DST:     CTRL800/u_src500/u_ack_sync/sync_q[0]/D
#   CTRL_ACKDATA2G_SRC:  DATA2G/cmd_ack_o/Q
#   CTRL_ACKDATA2G_DST:  CTRL800/u_srcdata2g/u_ack_sync/sync_q[0]/D
#   CTRL_ACKVALID2G_SRC: VALID2G/cmd_ack_o/Q
#   CTRL_ACKVALID2G_DST: CTRL800/u_srcvalid2g/u_ack_sync/sync_q[0]/D
#   CTRL_ACKCLOCK2G_SRC: CLOCK2G/cmd_ack_o/Q
#   CTRL_ACKCLOCK2G_DST: CTRL800/u_srcclock2g/u_ack_sync/sync_q[0]/D
#
# Retirement-toggle synchronizers: ONLY their FIRST stage D pins, one for
# every instantiated lane index 0 through LANES-1:
#   CTRL_RETIRE500_FIRST_D:
#     TX500/u_engine/g_retire_sync[lane]/u_retire_sync/sync_q[0]/D
#   CTRL_RETIREDATA2G_FIRST_D:
#     DATA2G/g_retire_sync[lane]/u_retire_sync/sync_q[0]/D
# VALID/CLOCK have no local PHY handshake inputs; their analog control outputs
# (phyTrain*, phyDigControl) are registered levels and need no false paths.
#
# If synthesis removes registers for constant/unused lanes or optimizes the
# source encoding, use a reviewed design-specific binding variant. Do not
# silently weaken width checks or bind a later synchronizer stage.

if {![info exists CTRL_LANES]} {
  error "Set CTRL_LANES to the elaborated LANES parameter before sourcing"
}
if {![string is integer -strict $CTRL_LANES] || $CTRL_LANES < 1} {
  error "CTRL_LANES must be a positive integer"
}

# Validate the entire binding before emitting any exceptions.
foreach collection_name {
  CTRL_CMD500_SRC CTRL_CMD500_DST CTRL_CMDDATA2G_SRC CTRL_CMDDATA2G_DST
  CTRL_ABORT500_SRC CTRL_ABORT500_DST
  CTRL_ABORTDATA2G_SRC CTRL_ABORTDATA2G_DST
  CTRL_ABORTVALID2G_SRC CTRL_ABORTVALID2G_DST
  CTRL_ABORTCLOCK2G_SRC CTRL_ABORTCLOCK2G_DST
  CTRL_REQ500_SRC CTRL_REQ500_DST CTRL_REQDATA2G_SRC CTRL_REQDATA2G_DST
  CTRL_REQVALID2G_SRC CTRL_REQVALID2G_DST CTRL_REQCLOCK2G_SRC CTRL_REQCLOCK2G_DST
  CTRL_CANCEL500_SRC CTRL_CANCEL500_DST
  CTRL_CANCELDATA2G_SRC CTRL_CANCELDATA2G_DST
  CTRL_CANCELVALID2G_SRC CTRL_CANCELVALID2G_DST
  CTRL_CANCELCLOCK2G_SRC CTRL_CANCELCLOCK2G_DST
  CTRL_ACK500_SRC CTRL_ACK500_DST CTRL_ACKDATA2G_SRC CTRL_ACKDATA2G_DST
  CTRL_ACKVALID2G_SRC CTRL_ACKVALID2G_DST CTRL_ACKCLOCK2G_SRC CTRL_ACKCLOCK2G_DST
  CTRL_RETIRE500_FIRST_D CTRL_RETIREDATA2G_FIRST_D
} {
  if {![info exists $collection_name]} {
    error "Bind $collection_name to concrete synthesized pins before sourcing"
  }
  if {[sizeof_collection [set $collection_name]] == 0} {
    error "Empty CDC collection: $collection_name"
  }
}

foreach collection_name {CTRL_CMD500_SRC CTRL_CMD500_DST} {
  if {[sizeof_collection [set $collection_name]] != ($CTRL_LANES + 18)} {
    error "Wrong command bundle width in $collection_name; expected LANES+18 pins"
  }
}
foreach collection_name {
  CTRL_CMDDATA2G_SRC CTRL_CMDDATA2G_DST
  CTRL_RETIRE500_FIRST_D CTRL_RETIREDATA2G_FIRST_D
} {
  if {[sizeof_collection [set $collection_name]] != $CTRL_LANES} {
    error "Expected exactly LANES pins in $collection_name"
  }
}
foreach collection_name {
  CTRL_ABORT500_SRC CTRL_ABORT500_DST
  CTRL_ABORTDATA2G_SRC CTRL_ABORTDATA2G_DST
  CTRL_ABORTVALID2G_SRC CTRL_ABORTVALID2G_DST
  CTRL_ABORTCLOCK2G_SRC CTRL_ABORTCLOCK2G_DST
  CTRL_REQ500_SRC CTRL_REQ500_DST CTRL_REQDATA2G_SRC CTRL_REQDATA2G_DST
  CTRL_REQVALID2G_SRC CTRL_REQVALID2G_DST CTRL_REQCLOCK2G_SRC CTRL_REQCLOCK2G_DST
  CTRL_CANCEL500_DST CTRL_CANCELDATA2G_DST
  CTRL_CANCELVALID2G_DST CTRL_CANCELCLOCK2G_DST
  CTRL_ACK500_SRC CTRL_ACK500_DST CTRL_ACKDATA2G_SRC CTRL_ACKDATA2G_DST
  CTRL_ACKVALID2G_SRC CTRL_ACKVALID2G_DST CTRL_ACKCLOCK2G_SRC CTRL_ACKCLOCK2G_DST
} {
  if {[sizeof_collection [set $collection_name]] != 1} {
    error "Expected exactly one pin in $collection_name"
  }
}
foreach collection_name {
  CTRL_CANCEL500_SRC CTRL_CANCELDATA2G_SRC
  CTRL_CANCELVALID2G_SRC CTRL_CANCELCLOCK2G_SRC
} {
  if {[sizeof_collection [set $collection_name]] != 3} {
    error "Expected cancel_q AND both active_kind Q pins in $collection_name"
  }
}

# Each full Q-to-D route is bounded by ONE destination clock period.
# Synchronized request/ack and local capture sequencing supply settling time;
# held bundles are not unconstrained asynchronous buses. Meet these limits
# after routing at the implementation timing corners.
set_max_delay -datapath_only 2.0  -from $CTRL_CMD500_SRC -to $CTRL_CMD500_DST
set_max_delay -datapath_only 0.5  -from $CTRL_CMDDATA2G_SRC -to $CTRL_CMDDATA2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ABORT500_SRC -to $CTRL_ABORT500_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ABORTDATA2G_SRC -to $CTRL_ABORTDATA2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ABORTVALID2G_SRC -to $CTRL_ABORTVALID2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ABORTCLOCK2G_SRC -to $CTRL_ABORTCLOCK2G_DST

# Bound request/cancel/ack propagation as well. In particular, a delayed old
# cancellation must not survive into a later request. Each endpoint waits for
# synchronized request AND cancellation low before lowering its ack.
# These are propagation limits into first-stage metastability-resolution
# registers, not a synchronous setup relationship between the clocks.
set_max_delay -datapath_only 2.0  -from $CTRL_REQ500_SRC -to $CTRL_REQ500_DST
set_max_delay -datapath_only 0.5  -from $CTRL_REQDATA2G_SRC -to $CTRL_REQDATA2G_DST
set_max_delay -datapath_only 0.5  -from $CTRL_REQVALID2G_SRC -to $CTRL_REQVALID2G_DST
set_max_delay -datapath_only 0.5  -from $CTRL_REQCLOCK2G_SRC -to $CTRL_REQCLOCK2G_DST
set_max_delay -datapath_only 2.0  -from $CTRL_CANCEL500_SRC -to $CTRL_CANCEL500_DST
set_max_delay -datapath_only 0.5  -from $CTRL_CANCELDATA2G_SRC -to $CTRL_CANCELDATA2G_DST
set_max_delay -datapath_only 0.5  -from $CTRL_CANCELVALID2G_SRC -to $CTRL_CANCELVALID2G_DST
set_max_delay -datapath_only 0.5  -from $CTRL_CANCELCLOCK2G_SRC -to $CTRL_CANCELCLOCK2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ACK500_SRC -to $CTRL_ACK500_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ACKDATA2G_SRC -to $CTRL_ACKDATA2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ACKVALID2G_SRC -to $CTRL_ACKVALID2G_DST
set_max_delay -datapath_only 1.25 -from $CTRL_ACKCLOCK2G_SRC -to $CTRL_ACKCLOCK2G_DST
# DO NOT false-path these twelve controls: in common STA exception precedence,
# a false path overrides max delay and removes the required route bound.
# Use the target flow's asynchronous first-stage min/hold treatment without
# disabling the max-delay checks; verify the tool's actual semantics.

# Retirement can be delayed without allowing the next transaction to start:
# the engine waits for all selected retirement toggles. False-path ONLY their
# first-stage D pins. Keep every later synchronizer-stage path timed and short.
set_false_path -to $CTRL_RETIRE500_FIRST_D
set_false_path -to $CTRL_RETIREDATA2G_FIRST_D

# Physical integration requirements (not executable floorplan constraints):
# - Cluster synchronizer stages tightly in their RECEIVING region. Do not put
#   first stages at the remote launch region. Long wires terminate locally.
# - Put 800 MHz command captures beside LTSM, TX500 with its lane bank, DATA2G
#   with the 2 GHz lane-ID bank, VALID2G beside the valid generator, and CLOCK2G
#   beside the forwarded-clock generator. Local output paths remain timed.
# - A 0.5 ns inter-region route can be demanding. Route/buffer/floorplan to
#   meet it, or redesign and re-prove capture/handshake timing before relaxing
#   the bound. Do not insert independent payload registers as a timing fix.
# - Do NOT use blanket asynchronous clock_groups/false paths overriding these
#   18 max-delay checks. Report effective exceptions in the actual STA tool.
# - Preserve payload/result hold behavior through the complete return-to-zero
#   handshake. Check min/hold behavior and CDC assumptions separately.
# - Apply technology-specific synchronizer-cell, placement and MTBF rules;
#   ASYNC_REG/dont_touch attributes alone do not establish reliability.
# - Common reset assertion and per-region synchronous release are required.
#   Reset distribution/recovery/removal constraints belong to the SoC flow.
# - Local ready/fire, CLOCKREPAIR waveform generation, VALID finish handshake,
#   S3-to-S1 data/fence transport, serializer empty and output pin timing remain
#   separate PHY timing responsibilities. This template does not sign them off.
