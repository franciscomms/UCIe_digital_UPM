// Hand-translated synthesizable SystemVerilog.
// Source: sidebandNode(2).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_sideband_params_pkg;
  // All integrated LTSM/FDI/RDI sideband messages are fixed-width 128-bit values.
  parameter int unsigned SIDEBAND_NODE_MSG_WIDTH = 128;
endpackage

`default_nettype wire
