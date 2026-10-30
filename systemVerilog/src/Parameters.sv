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

  // DLL/PI controls from the supplied ucie_pi_control reference. The physical
  // word is {lower_en[16:0], upper_en[16:0], s3, s2, s1, s0}; the two mux
  // selects are {s1,s0} and {s3,s2}. Bank bit 0 is the weight-1 fine switch;
  // bits 1..16 are weight-2 coarse switches SW0..SW15. These are enable bits,
  // not clock waveforms and not a binary phase number.
  localparam int unsigned D2C_PI_CONTROL_WIDTH = 38;
  localparam int unsigned D2C_PI_SECTOR_COUNT = 8;
  localparam int unsigned D2C_PI_INTERVALS_PER_SECTOR = 33;
  localparam int unsigned D2C_PI_PHASE_COUNT =
    D2C_PI_SECTOR_COUNT * D2C_PI_INTERVALS_PER_SECTOR;
  localparam int unsigned D2C_PI_INDEX_WIDTH = $clog2(D2C_PI_PHASE_COUNT);
  parameter int unsigned DEFAULT_D2C_PI_CODE_WIDTH = D2C_PI_CONTROL_WIDTH;

  // Divide-free decomposition into {sector[2:0], step[5:0]}. Each constant
  // sector interval is compared in parallel; the one-hot results are combined
  // by an explicit balanced OR. All multiplies below have constant operands.
  // Invalid standalone indices produce the phase-0 setting, as before.
  function automatic logic [8:0] decompose_d2c_phase(
    input logic [D2C_PI_INDEX_WIDTH-1:0] phase_index
  );
    logic [8:0] sector_parts [0:D2C_PI_SECTOR_COUNT-1];
    begin
      for (int unsigned sec = 0; sec < D2C_PI_SECTOR_COUNT; sec++) begin
        sector_parts[sec] = '0;
        if ((phase_index >= D2C_PI_INDEX_WIDTH'(sec * D2C_PI_INTERVALS_PER_SECTOR)) &&
            (phase_index < D2C_PI_INDEX_WIDTH'((sec + 1) * D2C_PI_INTERVALS_PER_SECTOR)))
          sector_parts[sec] = {3'(sec),
            6'(phase_index - D2C_PI_INDEX_WIDTH'(sec * D2C_PI_INTERVALS_PER_SECTOR))};
      end
      decompose_d2c_phase =
        ((sector_parts[0] | sector_parts[1]) | (sector_parts[2] | sector_parts[3])) |
        ((sector_parts[4] | sector_parts[5]) | (sector_parts[6] | sector_parts[7]));
    end
  endfunction

  // Decode the registered sector/step into DLL mux and complementary PI banks.
  // MBTrain_DllPiEncoder places registers before and after this function.
  function automatic logic [D2C_PI_CONTROL_WIDTH-1:0] encode_d2c_parts(
    input logic [8:0] phase_parts
  );
    logic [2:0] sector;
    logic [5:0] step;
    logic [1:0] upper_select, lower_select;
    logic [16:0] later_en, upper_en, lower_en;
    begin
      sector = phase_parts[8:6];
      step = phase_parts[5:0];
      lower_select = sector[2:1];
      upper_select = lower_select + {1'b0, sector[0]};
      later_en = '0;
      later_en[0] = step[0];
      for (int unsigned sw = 0; sw < 16; sw++)
        later_en[sw+1] = (step >= 6'(2*(sw+1)));
      upper_en = sector[0] ? later_en : ~later_en;
      lower_en = ~upper_en;
      encode_d2c_parts = {lower_en, upper_en, lower_select, upper_select};
    end
  endfunction

  // Pure encoding helper for constants and verification. Runtime sweep outputs
  // use MBTrain_DllPiEncoder so interval selection and bank decoding cannot
  // become one register-to-output timing path. The 264 ordered indices cover
  // each sector's steps 0..32; step 33 is the next sector's step 0.
  function automatic logic [D2C_PI_CONTROL_WIDTH-1:0] encode_d2c_phase(
    input logic [D2C_PI_INDEX_WIDTH-1:0] phase_index
  );
    encode_d2c_phase = encode_d2c_parts(decompose_d2c_phase(phase_index));
  endfunction

  // DATATRAINCENTER1 local transmitter deskew defaults.
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
  // step. Set this ratio to the actual PHY PI resolution at the training
  // rate; the default is 1. The 264 phase intervals are not inherently 0.5 ps.
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

  // Vref controls shared by VALVREF, DATAVREF, VALTRAINVREF and DATATRAINVREF.
  // The analog word is one-hot: bit 0 selects the lowest Vref tap, bit 19
  // the highest. Sweep/window arithmetic uses binary tap indices internally.
  // Voltage endpoints are PHY/DAC metadata; the analog macro owns the mapping.
  localparam int unsigned DEFAULT_VREF_CODE_WIDTH = 20;
  parameter int unsigned DEFAULT_VALID_VREF_VALUE_COUNT = 20;
  parameter int unsigned DEFAULT_VALID_VREF_MINIMUM_MILLIVOLTS = 250;
  parameter int unsigned DEFAULT_VALID_VREF_MAXIMUM_MILLIVOLTS = 550;
  parameter logic [15:0] DEFAULT_VALID_VREF_MAX_COMPARISON_ERROR_THRESHOLD = 16'd0;
  parameter int unsigned DEFAULT_VALID_VREF_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_VALID_VREF_MAX_TRAINING_RETRIES = 1;
  // UCIe makes the operating-rate VALTRAINVREF optimization optional.
  parameter bit DEFAULT_VALTRAIN_VREF_ENABLE = 1'b1;

  // RXDESKEW uses the same two-cell physical switch encoding as TXDESKEW:
  // 20 controls per lane, with 39 legal delays (0..38 half-ps steps).
  parameter int unsigned DEFAULT_RX_DESKEW_CODE_WIDTH = TX_DESKEW_CONTROL_WIDTH;
  parameter int unsigned DEFAULT_RX_DESKEW_VALUE_COUNT =
    TX_DESKEW_MAX_HALF_STEPS + 1;
  parameter logic [15:0] DEFAULT_RX_DESKEW_MAX_COMPARISON_ERROR_THRESHOLD =
    DEFAULT_D2C_MAX_COMPARISON_ERROR_THRESHOLD;
  parameter int unsigned DEFAULT_RX_DESKEW_MIN_PASSING_WINDOW_VALUES = 1;
  parameter int unsigned DEFAULT_RX_DESKEW_MAX_TRAINING_RETRIES =
    DEFAULT_D2C_MAX_TRAINING_RETRIES;
  parameter bit DEFAULT_RX_DESKEW_ENABLE = 1'b1;
endpackage

`default_nettype wire
