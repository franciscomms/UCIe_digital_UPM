// Hand-translated synthesizable SystemVerilog.
// Source: D2DAdapterConstants(4).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_d2dadapter_pkg;
  // FDI initialization substates used by LinkManagementController.
  typedef enum logic [2:0] {
    LinkInitState_FDI_INIT_START         = 3'h0,
    LinkInitState_FDI_WAIT_RDI_ACTIVE    = 3'h1,
    LinkInitState_FDI_PARAM_EXCH         = 3'h2,
    LinkInitState_FDI_WAIT_LP_REQ_ACTIVE = 3'h3,
    LinkInitState_FDI_ACTIVE_HANDSHAKE   = 3'h4,
    LinkInitState_FDI_ACTIVE_ENTRY_DONE  = 3'h5
  } LinkInitState_t;

  parameter int unsigned D2Dlinkerrcnt_SIZE  = 64;
  parameter int unsigned D2Dparamexchcnt_SIZE = 64;
endpackage

`default_nettype wire
