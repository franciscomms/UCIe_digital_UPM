# Real Tcl syntax/binding-guard test only; NOT STA or netlist validation.
# Run with tclsh, or tkinter.Tcl().eval('source .../check_template.tcl').
proc sizeof_collection {c} {return [llength $c]}
set calls {}
proc set_max_delay {args} {global calls; lappend calls [linsert $args 0 max]}
proc set_false_path {args} {global calls; lappend calls [linsert $args 0 false]}
set template [file join [file dirname [info script]] cdc_constraints.sdc]

proc must_reject {label} {
  global template calls
  set calls {}
  if {![catch {uplevel #0 [list source $template]} msg]} {
    error "$label should be rejected"
  }
  if {[llength $calls] != 0} {
    error "$label emitted partial constraints before rejecting the binding"
  }
}

must_reject "unbound template"
set CTRL_LANES 16
foreach n {CTRL_CMD500_SRC CTRL_CMD500_DST} {
  set $n {}
  for {set i 0} {$i < 34} {incr i} {lappend $n ${n}_$i}
}
foreach n {
  CTRL_CMDDATA2G_SRC CTRL_CMDDATA2G_DST
  CTRL_RETIRE500_FIRST_D CTRL_RETIREDATA2G_FIRST_D
} {
  set $n {}
  for {set i 0} {$i < 16} {incr i} {lappend $n ${n}_$i}
}
foreach n {
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
} {set $n ${n}_pin}
foreach n {
  CTRL_CANCEL500_SRC CTRL_CANCELDATA2G_SRC
  CTRL_CANCELVALID2G_SRC CTRL_CANCELCLOCK2G_SRC
} {set $n {cancel_Q active_kind_0_Q active_kind_1_Q}}

set calls {}
source $template
set expected {}
foreach {delay prefix} {
  2.0 CMD500 0.5 CMDDATA2G
  1.25 ABORT500 1.25 ABORTDATA2G 1.25 ABORTVALID2G 1.25 ABORTCLOCK2G
  2.0 REQ500 0.5 REQDATA2G 0.5 REQVALID2G 0.5 REQCLOCK2G
  2.0 CANCEL500 0.5 CANCELDATA2G 0.5 CANCELVALID2G 0.5 CANCELCLOCK2G
  1.25 ACK500 1.25 ACKDATA2G 1.25 ACKVALID2G 1.25 ACKCLOCK2G
} {
  lappend expected [list max -datapath_only $delay \
    -from [set CTRL_${prefix}_SRC] -to [set CTRL_${prefix}_DST]]
}
lappend expected [list false -to $CTRL_RETIRE500_FIRST_D]
lappend expected [list false -to $CTRL_RETIREDATA2G_FIRST_D]
if {$calls ne $expected} {
  error "Wrong constraint mapping/order/delay: expected 18 exact max-delay routes and two retirement false paths"
}

# Exercise every collection's missing, empty and wrong-width guard, not just
# one representative signal. Proper pin identity still needs netlist review.
set collection_names [lsort [info vars CTRL_*]]
set collection_names [lsearch -all -inline -not -exact $collection_names CTRL_LANES]
foreach n $collection_names {
  set saved [set $n]
  unset $n
  must_reject "missing $n"
  set $n {}
  must_reject "empty $n"
  set $n [concat $saved extra_pin]
  must_reject "wrong-width $n"
  set $n $saved
}
foreach bad_lanes {0 -1 abc 1.5} {
  set CTRL_LANES $bad_lanes
  must_reject "invalid LANES=$bad_lanes"
}
set CTRL_LANES 16
set calls {}
source $template
if {$calls ne $expected} {error "valid bindings failed after guard tests"}
puts "CDC_TEMPLATE_SYNTAX_PASS: 18 exact max-delay routes, two retirement false paths; all missing/empty/width guards and invalid LANES rejected; no STA sign-off"
