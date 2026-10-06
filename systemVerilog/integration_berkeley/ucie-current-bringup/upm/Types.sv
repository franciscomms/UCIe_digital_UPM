// Hand-translated synthesizable SystemVerilog.
// Source: Types(3).scala
// Original Chisel signal/register names are retained wherever SystemVerilog scoping permits.

`default_nettype none

package UcieUPM_interfaces_pkg;
  // UCIe logical-link state encoding shared by the FDI and RDI controllers.
  typedef enum logic [3:0] {
    PhyState_reset       = 4'h0,
    PhyState_active      = 4'h1,
    PhyState_activePmNak = 4'h3,
    PhyState_l1          = 4'h4,
    PhyState_l2          = 4'h8,
    PhyState_linkReset   = 4'h9,
    PhyState_linkError   = 4'hA,
    PhyState_retrain     = 4'hB,
    PhyState_disabled    = 4'hC
  } PhyState_t;

  // UCIe upper-layer state request encoding shared by FDI and RDI.
  typedef enum logic [3:0] {
    PhyStateReq_nop       = 4'h0,
    PhyStateReq_active    = 4'h1,
    PhyStateReq_l1        = 4'h4,
    PhyStateReq_l2        = 4'h8,
    PhyStateReq_linkReset = 4'h9,
    PhyStateReq_retrain   = 4'hB,
    PhyStateReq_disabled  = 4'hC
  } PhyStateReq_t;
endpackage

`default_nettype wire
