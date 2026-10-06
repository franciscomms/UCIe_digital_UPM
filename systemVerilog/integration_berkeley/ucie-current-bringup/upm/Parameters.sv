// Synthesizable SystemVerilog representation of Parameters.scala.
// The Chisel case class is elaboration-time configuration, so it becomes module parameters.
`default_nettype none

package LtsmParameters_pkg;
  parameter bit         DEFAULT_SB_FEATURE_EXTENSION = 1'b0;
  parameter bit         DEFAULT_UCIE_A               = 1'b0;
  parameter logic [1:0] DEFAULT_MODULE_ID            = 2'd0;
  parameter bit         DEFAULT_CLK_PHASE            = 1'b0;
  parameter bit         DEFAULT_CLK_MODE             = 1'b0;
  parameter logic [4:0] DEFAULT_VOLTAGE_SWING        = 5'd7;
  parameter logic [3:0] DEFAULT_MAX_LINK_SPEED       = 4'd3;

  // DATATRAINCENTER1 local transmitter sweep/deskew defaults.
  // The PI and deskew resolutions are implementation parameters rather than
  // UCIe protocol encodings.
  parameter int unsigned DEFAULT_D2C_PI_CODE_WIDTH = 6;
  parameter int unsigned DEFAULT_D2C_TX_DESKEW_CODE_WIDTH = 6;
  parameter int unsigned DEFAULT_D2C_DESKEW_STEPS_PER_PI = 1;
  parameter bit DEFAULT_D2C_DESKEW_ADD_DELAY_INCREASES_PHASE = 1'b1;
  parameter logic [15:0] DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD = 16'd0;
  parameter int unsigned DEFAULT_D2C_MIN_LANE_WINDOW_STEPS = 1;
  parameter int unsigned DEFAULT_D2C_MIN_COMMON_WINDOW_STEPS = 1;
  parameter int unsigned DEFAULT_D2C_MAX_TRAINING_RETRIES = 1;

  // Valid-receiver Vref sweep defaults shared by MBTRAIN.VALVREF and
  // MBTRAIN.VALTRAINVREF.  The voltage endpoints are PHY/DAC mapping
  // metadata; the digital state machines operate only on Vref codes.
  parameter int unsigned DEFAULT_VALID_VREF_VALUE_COUNT = 16;
  parameter int unsigned DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS = 250;
  parameter int unsigned DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS = 550;
  parameter logic [15:0] DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD = 16'd0;
  parameter int unsigned DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES = 1;
  // UCIe makes the operating-rate VALTRAINVREF optimization optional.
  parameter bit DEFAULT_VALTRAIN_VREF_ENABLE = 1'b1;

  // MBTRAIN.RXDESKEW defaults.  The RX delay control intentionally uses the
  // same unsigned per-lane code convention and default resolution as TX
  // deskew.  Code-to-time mapping remains an analog PHY responsibility.
  parameter int unsigned DEFAULT_RX_DESKEW_CODE_WIDTH =
    DEFAULT_D2C_TX_DESKEW_CODE_WIDTH;
  parameter int unsigned DEFAULT_RX_DESKEW_VALUE_COUNT =
    (1 << DEFAULT_RX_DESKEW_CODE_WIDTH);
  parameter logic [15:0] DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD =
    DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD;
  parameter int unsigned DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES =
    DEFAULT_D2C_MAX_TRAINING_RETRIES;
  parameter bit DEFAULT_RX_DESKEW_ENABLE = 1'b1;
endpackage

`default_nettype wire
