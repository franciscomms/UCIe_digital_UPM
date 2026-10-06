// Hand-translated synthesizable SystemVerilog.
// Source: Fdi(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_fdi_params_pkg;
  // SystemVerilog equivalent of the Scala elaboration-time FdiParams defaults.
  parameter int unsigned FDI_WIDTH      = 64;
  parameter int unsigned FDI_DLLP_WIDTH = 128;
  parameter int unsigned FDI_SB_WIDTH   = 128;
endpackage

`default_nettype wire
