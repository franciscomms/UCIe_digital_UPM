// Hand-translated synthesizable SystemVerilog.
// Source: RdiLinkManagementConstants(5).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_rdi_link_management_pkg;
  // Internal RDI Reset/Retrain-to-Active bring-up sub-state.
  typedef enum logic [2:0] {
    RDIBringUpState_IDLE                   = 3'h0,
    RDIBringUpState_ACTIVE_ENTRY_HANDSHAKE = 3'h1,
    RDIBringUpState_BRINGUP_DONE           = 3'h2
  } RDIBringUpState_t;
endpackage

`default_nettype wire
