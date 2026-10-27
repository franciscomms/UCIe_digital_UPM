/* Copyright 2018 ETH Zurich and University of Bologna.
* Copyright and related rights are licensed under the Solderpad Hardware
* License, Version 0.51 (the “License”); you may not use this file except in
* compliance with the License.  You may obtain a copy of the License at
* http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
* or agreed to in writing, software, hardware and materials distributed under
* this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied. See the License for the
* specific language governing permissions and limitations under the License.
*
* File:   dmi_jtag_tap.sv
* Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
* Date:   19.7.2018
*
* Description: JTAG TAP for DMI (according to debug spec 0.13)
*
* Modified by: Alex R!
*/

module jtag_tap 
	import jtag_cfg_pkg::*;
(
	// JTAG PORT
	input  logic	jtag_nRst,  // JTAG test reset pad

	input  logic	tck,    	// JTAG test clock pad
	input  logic	tms,    	// JTAG test mode select pad
	input  logic	tdi,     	// JTAG test data input pad
	output logic	tdo,     	// JTAG test data output pad
	output logic	tdo_en, 	// Data out output enable
	input  logic	testmode_i,

	// TDR COMMON BUS
	output logic	tdr_rst,
	output logic	tdr_tck,
	output logic	tdr_tdi,
	output logic	tdr_update,
	output logic	tdr_capture,
	output logic	tdr_shift,

	// TDRs
	output logic	dtmcs_sel,
	input  logic	dtmcs_tdo,

	output logic	dmi_sel,
	input  logic	dmi_tdo,

	output logic 	tdr_snap_sel,
	input  logic 	tdr_snap_tdo,

	output logic 	tdr_step_sel,
	input  logic 	tdr_step_tdo
);
	// ------------------------------------------------------------------------
	// TYPEDEFS
	// ------------------------------------------------------------------------

	typedef enum logic [3:0] {
		TestLogicReset, 
		RunTestIdle, 
		SelectDrScan,
		CaptureDr, 
		ShiftDr, 
		Exit1Dr, 
		PauseDr, 
		Exit2Dr,
		UpdateDr, 
		SelectIrScan, 
		CaptureIr, 
		ShiftIr,
		Exit1Ir,
		PauseIr, 
		Exit2Ir, 
		UpdateIr
	} tap_state_e;

	// ------------------------------------------------------------------------
	// SIGNALS
	// ------------------------------------------------------------------------

	// FSM state
	tap_state_e tap_state_q, tap_state_d;

	// DR signals
	logic update_dr, shift_dr, capture_dr;

	// IR signals
	logic capture_ir, shift_ir, update_ir, test_logic_reset; // pause_ir

	// IR shift register
	logic [(JTAG_IR_WIDTH - 1) : 0]  jtag_ir_shift_d, jtag_ir_shift_q;

	// IR shadow register -> captured from shift register upon update_ir
	tdr_id_t jtag_ir_d, jtag_ir_q;

	// IDCODE and BYPASS Regs
	logic [31:0] idcode_d, idcode_q;  // 32-bits
	logic        bypass_d, bypass_q;  // 1-bit

	// Internal TDR sel
	logic idcode_sel;
	logic bypass_sel;

	// TDO mux out
	logic tdo_mux;

	// TDO output reg clock
	logic tck_n;

	// ------------------------------------------------------------------------
	// IR LOGIC
	// ------------------------------------------------------------------------

	always_comb begin : p_jtag
		jtag_ir_shift_d = jtag_ir_shift_q;
		jtag_ir_d       = jtag_ir_q;

		// IR shift register
		if (shift_ir) begin
			jtag_ir_shift_d = {tdi, jtag_ir_shift_q[(JTAG_IR_WIDTH - 1) : 1]};
		end

		// capture IR register
		if (capture_ir) begin
			jtag_ir_shift_d =  JTAG_IR_WIDTH'(4'b0101);
		end

		// update IR register
		if (update_ir) begin
			jtag_ir_d = tdr_id_t'(jtag_ir_shift_q);
		end

		if (test_logic_reset) begin
			// Bring all TAP state to the initial value.
			jtag_ir_shift_d = '0;
			jtag_ir_d = IDCODE;
		end
	end

	always_ff @(posedge tck, negedge jtag_nRst) begin : p_jtag_ir_reg
		if (!jtag_nRst) begin
			jtag_ir_shift_q <= '0;
			jtag_ir_q       <= IDCODE;
		end else begin
			jtag_ir_shift_q <= jtag_ir_shift_d;
			jtag_ir_q       <= jtag_ir_d;
		end
	end

	// ------------------------------------------------------------------------
	// DR INTERNAL REGS
	// ------------------------------------------------------------------------

	always_comb begin
		idcode_d = idcode_q;
		bypass_d = bypass_q;

		if (capture_dr) begin
			if (idcode_sel) idcode_d = JTAG_IDCODE_VALUE;
			if (bypass_sel) bypass_d = 1'b0;
		end

		if (shift_dr) begin
			if (idcode_sel) idcode_d = {tdi, 31'(idcode_q >> 1)};
			if (bypass_sel) bypass_d = tdi;
		end

		if (test_logic_reset) begin
			// Bring all TAP state to the initial value.
			idcode_d = JTAG_IDCODE_VALUE;
			bypass_d = 1'b0;
		end
	end

	// ------------------------------------------------------------------------
	// TDR SELECT
	// ------------------------------------------------------------------------

	always_comb begin : p_data_reg_sel
		dtmcs_sel 		= 1'b0;
		dmi_sel   		= 1'b0;
		tdr_snap_sel 	= 1'b0;
		tdr_step_sel 	= 1'b0;
		idcode_sel  	= 1'b0;
		bypass_sel  	= 1'b0;

		unique case (jtag_ir_q)
			BYPASS_0:	bypass_sel		= 1'b1;
			IDCODE:    	idcode_sel  	= 1'b1;

			TDR_SNAP:	tdr_snap_sel 	= 1'b1;
			TDR_STEP:	tdr_step_sel 	= 1'b1;

			RV_DTMCS:	dtmcs_sel 		= 1'b1;
			RV_DMI: 	dmi_sel   		= 1'b1;

			BYPASS_1:   bypass_sel  	= 1'b1;

			default:	bypass_sel  	= 1'b1;
		endcase
	end

	// ------------------------------------------------------------------------
	// TDO MUX
	// ------------------------------------------------------------------------

	always_comb begin : p_out_sel
		if (shift_ir) begin
			// IR Register Shift
			tdo_mux = jtag_ir_shift_q[0];
	
		end else begin
			// DR Register Shift
			unique case (jtag_ir_q)
				IDCODE:         tdo_mux 	= idcode_q[0];		// Reading ID code

				TDR_SNAP:		tdo_mux 	= tdr_snap_tdo;
				TDR_STEP:		tdo_mux 	= tdr_step_tdo;

				RV_DTMCS:       tdo_mux 	= dtmcs_tdo;   		// Read from DTMCS TDO
				RV_DMI:      	tdo_mux 	= dmi_tdo;			// Read from DMI TDO

				default:        tdo_mux 	= bypass_q;			// BYPASS instruction
			endcase
		end
	end

	// ------------------------------------------------------------------------
	// TDO REGISTER
	// ------------------------------------------------------------------------
	
	tc_clk_inverter i_tck_inv (
		.clk_i ( tck  ),
		.clk_o ( tck_n )
	);

	// TDO changes state at negative edge of TCK
	always_ff @(posedge tck_n, negedge jtag_nRst) begin : p_tdo_regs
		if (!jtag_nRst) begin
			tdo     <= 1'b0;
			tdo_en <= 1'b0;
		end else begin
			tdo     <= tdo_mux;
			tdo_en <= (shift_ir | shift_dr);
		end
	end

	// ------------------------------------------------------------------------
	// TAP FSM
	// ------------------------------------------------------------------------

	// Determination of next state; purely combinatorial
	always_comb begin : p_tap_fsm

		test_logic_reset   = 1'b0;

		capture_dr         = 1'b0;
		shift_dr           = 1'b0;
		update_dr          = 1'b0;

		capture_ir         = 1'b0;
		shift_ir           = 1'b0;
		// pause_ir           = 1'b0; unused
		update_ir          = 1'b0;

		unique case (tap_state_q)
			TestLogicReset: begin
				tap_state_d = (tms) ? TestLogicReset : RunTestIdle;
				test_logic_reset = 1'b1;
			end
			RunTestIdle: begin
				tap_state_d = (tms) ? SelectDrScan : RunTestIdle;
			end
			// DR Path
			SelectDrScan: begin
				tap_state_d = (tms) ? SelectIrScan : CaptureDr;
			end
			CaptureDr: begin
				capture_dr = 1'b1;
				tap_state_d = (tms) ? Exit1Dr : ShiftDr;
			end
			ShiftDr: begin
				shift_dr = 1'b1;
				tap_state_d = (tms) ? Exit1Dr : ShiftDr;
			end
			Exit1Dr: begin
				tap_state_d = (tms) ? UpdateDr : PauseDr;
			end
			PauseDr: begin
				tap_state_d = (tms) ? Exit2Dr : PauseDr;
			end
			Exit2Dr: begin
				tap_state_d = (tms) ? UpdateDr : ShiftDr;
			end
			UpdateDr: begin
				update_dr = 1'b1;
				tap_state_d = (tms) ? SelectDrScan : RunTestIdle;
			end
			// IR Path
			SelectIrScan: begin
				tap_state_d = (tms) ? TestLogicReset : CaptureIr;
			end
			// In this controller state, the shift register bank in the
			// Instruction Register parallel loads a pattern of fixed values on
			// the rising edge of TCK. The last two significant bits must always
			// be "01".
			CaptureIr: begin
				capture_ir = 1'b1;
				tap_state_d = (tms) ? Exit1Ir : ShiftIr;
			end
			// In this controller state, the instruction register gets connected
			// between TDI and TDO, and the captured pattern gets shifted on
			// each rising edge of TCK. The instruction available on the TDI
			// pin is also shifted in to the instruction register.
			ShiftIr: begin
				shift_ir = 1'b1;
				tap_state_d = (tms) ? Exit1Ir : ShiftIr;
			end
			Exit1Ir: begin
				tap_state_d = (tms) ? UpdateIr : PauseIr;
			end
			PauseIr: begin
				// pause_ir = 1'b1; // unused
				tap_state_d = (tms) ? Exit2Ir : PauseIr;
			end
			Exit2Ir: begin
				tap_state_d = (tms) ? UpdateIr : ShiftIr;
			end
			// In this controller state, the instruction in the instruction
			// shift register is latched to the latch bank of the Instruction
			// Register on every falling edge of TCK. This instruction becomes
			// the current instruction once it is latched.
			UpdateIr: begin
				update_ir = 1'b1;
				tap_state_d = (tms) ? SelectDrScan : RunTestIdle;
			end
			default: ; // can't actually happen since case is full
		endcase
	end

	always_ff @(posedge tck or negedge jtag_nRst) begin : p_regs
		if (!jtag_nRst) begin
			tap_state_q <= TestLogicReset;
			idcode_q    <= JTAG_IDCODE_VALUE;
			bypass_q    <= 1'b0;
		end else begin
			tap_state_q <= tap_state_d;
			idcode_q    <= idcode_d;
			bypass_q    <= bypass_d;
		end
	end

	// ------------------------------------------------------------------------
	// PASSTHROUGH SIGNALS
	// ------------------------------------------------------------------------

	assign tdr_tck 		= tck;
	assign tdr_tdi 		= tdi;
	assign tdr_update	= update_dr;
	assign tdr_shift 	= shift_dr;
	assign tdr_capture 	= capture_dr;
	assign tdr_rst 		= test_logic_reset;


endmodule : jtag_tap
