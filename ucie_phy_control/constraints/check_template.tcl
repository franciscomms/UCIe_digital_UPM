# Real Tcl syntax/binding-guard test only; NOT STA or netlist validation.
# Run with tclsh, or tkinter.Tcl().eval('source .../check_template.tcl').
proc sizeof_collection {c} {return [llength $c]}
set calls {}
proc set_max_delay {args} {global calls; lappend calls [linsert $args 0 max]}
proc set_false_path {args} {global calls; lappend calls [linsert $args 0 false]}
proc set_multicycle_path {args} {global calls; lappend calls [linsert $args 0 mcp]}
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
set SEQ_CMD_SRC {}
for {set i 0} {$i < 19} {incr i} {lappend SEQ_CMD_SRC SEQ_CMD_SRC_$i}
set SEQ_CMD_DST {}
for {set i 0} {$i < 40} {incr i} {lappend SEQ_CMD_DST SEQ_CMD_DST_$i}
foreach n {
  SEQ_REQ_SRC SEQ_REQ_DST SEQ_STOP_SRC SEQ_STOP_DST
  SEQ_ACK_SRC SEQ_ACK_DST SEQ_READY_SRC SEQ_READY_DST
  SEQ_ABORT_SRC SEQ_ABORT_DST
} {set $n ${n}_pin}

set calls {}
source $template
set expected {}
foreach {delay prefix} {
  2.0 REQ 2.0 STOP 1.25 ACK 1.25 READY 2.0 CMD 1.25 ABORT
} {
  lappend expected [list max -datapath_only $delay \
    -from [set SEQ_${prefix}_SRC] -to [set SEQ_${prefix}_DST]]
}
if {$calls ne $expected} {
  error "Wrong constraint mapping/order/delay: expected 6 exact max-delay routes, no false paths, no multicycle"
}

# Exercise every collection's missing, empty and wrong-width guard.
set collection_names [lsort [info vars SEQ_*]]
foreach n $collection_names {
  set saved [set $n]
  unset $n
  must_reject "missing $n"
  set $n {}
  must_reject "empty $n"
  if {$n ne "SEQ_CMD_DST"} {
    set $n [concat $saved extra_pin]
    must_reject "wrong-width $n"
  } else {
    set $n [lrange $saved 0 10]
    must_reject "too-small $n"
  }
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
puts "CDC_TEMPLATE_SYNTAX_PASS: 6 exact max-delay routes, no false paths, no multicycle; all missing/empty/width guards and invalid LANES rejected; no STA sign-off"
