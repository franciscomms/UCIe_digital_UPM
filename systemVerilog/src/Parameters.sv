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
  // TX deskew is a physical switch word, not a binary delay code. Each lane
  // has two cascaded cells. Cell 1 is [9:0], cell 2 is [19:10]; within a cell
  // bit 0 selects 0.5 ps and bits 1..9 select 1 ps each (sw-4 through sw4).
  // Fill cell 1 to 9.5 ps before adding delay in cell 2: 0..19 ps total.
  localparam int unsigned TX_DESKEW_CONTROL_WIDTH = 20;
  localparam int unsigned TX_DESKEW_HALF_STEP_WIDTH = 6;
  localparam int unsigned TX_DESKEW_CELL_MAX_HALF_STEPS = 19;
  localparam int unsigned TX_DESKEW_MAX_HALF_STEPS = 38;
  parameter int unsigned DEFAULT_D2C_TX_DESKEW_CODE_WIDTH = TX_DESKEW_CONTROL_WIDTH;
  // Number of 0.5 ps TX delay steps corresponding to one forwarded-clock PI
  // step. Set this ratio to the actual PHY PI resolution; the default is 1.
  parameter int unsigned DEFAULT_D2C_DESKEW_STEPS_PER_PI = 1;

  // The comparisons in this loop are independent thermometer-bit decoders,
  // not a loop-carried search. Numeric range checking is done by the training
  // engine before it calls this function; the function defensively saturates
  // out-of-range 6-bit inputs, but training never applies a saturated result.
  function automatic logic [TX_DESKEW_CONTROL_WIDTH-1:0] encode_tx_deskew(
    input logic [TX_DESKEW_HALF_STEP_WIDTH-1:0] half_steps
  );
    logic [4:0] first_cell_steps;
    logic [4:0] second_cell_steps;
    begin
      if (half_steps >= 6'd38) begin
        first_cell_steps = 5'd19;
        second_cell_steps = 5'd19;
      end else if (half_steps > 6'd19) begin
        first_cell_steps = 5'd19;
        second_cell_steps = 5'(half_steps - 6'd19);
      end else begin
        first_cell_steps = half_steps[4:0];
        second_cell_steps = '0;
      end
      encode_tx_deskew = '0;
      encode_tx_deskew[0] = first_cell_steps[0];
      encode_tx_deskew[10] = second_cell_steps[0];
      for (int unsigned sw = 0; sw < 9; sw++) begin
        encode_tx_deskew[1+sw] = (first_cell_steps >= 5'(2*(sw+1)));
        encode_tx_deskew[11+sw] = (second_cell_steps >= 5'(2*(sw+1)));
      end
    end
  endfunction
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

  // MBTRAIN.RXDESKEW keeps its existing independent 6-bit unsigned binary
  // delay code and 64-value range. It does not use the TX switch encoding.
  parameter int unsigned DEFAULT_RX_DESKEW_CODE_WIDTH = 6;
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
