// SystemVerilog translation of States.scala.
`default_nettype none

package LinkTrainingState_pkg;
  typedef enum logic [2:0] {
    LinkTrainingState_reset     = 3'd0,
    LinkTrainingState_sbInit    = 3'd1,
    LinkTrainingState_mbInit    = 3'd2,
    LinkTrainingState_mbTrain   = 3'd3,
    LinkTrainingState_linkInit  = 3'd4,
    LinkTrainingState_active    = 3'd5,
    LinkTrainingState_linkError = 3'd6,
    LinkTrainingState_retrain   = 3'd7
  } LinkTrainingState_t;
endpackage

`default_nettype wire
