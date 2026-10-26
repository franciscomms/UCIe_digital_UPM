// -----------------------------------------------------------------------------
// jtag_tdr_snapshot.sv
//
// Snapshot TDR: captures a bus living in the IP clock domain at the moment a
// request is issued, and optionally writes a control word into the IP with a
// synchronized one-cycle pulse. CDC-lint clean: only two single-bit crossings
// go through synchronizers; the data buses cross under a synchronized qualifier
// (DMUX / multi-cycle-path scheme).
//
// -----------------------------------------------------------------------------
// **** OPERATIONS ****
//
//   - DR-scan #1  shift in {data, we} => Update-DR launches one transaction:
//                                           * we=1: data_out <= data, data_out_valid
//                                                   pulses for one clk cycle
//                                           * we=0: read only
//                                           * In both cases the IP side takes a
//                                             snapshot of data_in one clk cycle
//                                             after the write is applied.
//
//   - DR-scan #2  shift out {rd_data, busy} Capture-DR returns the snapshot of
//                                           the last completed transaction and
//                                           the busy flag. If busy=1 the previous
//                                           transaction is still in flight: repeat
//                                           the read scan (with we=0).
//
//   - An Update-DR while busy=1 is IGNORED (a $warning is printed in
//     simulation). Capture-DR precedes Shift-DR in every scan, so the debugger
//     always sees busy before deciding whether to write.
//
// 
// **** DATA REGISTER LAYOUT (DATA_W + 1 bits, LSB shifted first) ****
//
//   - TDI (write):  bit 0        we        1 = write data_out, 0 = read only
//                   bits [DW:1]  data      value written to data_out
//
//   - TDO (read):   bit 0        busy      1 = transaction in flight
//                   bits [DW:1]  rd_data   snapshot of data_in
//
// 
// **** CLOCK DOMAIN CROSSINGS ****
//
//   req_toggle_q   TCK -> clk   1 bit, 2-flop synchronizer
//   ack_toggle_q   clk -> TCK   1 bit, 2-flop synchronizer
//   wr_data_q      TCK -> clk   multi-bit, loaded only on req_pulse (derived
//                               from the synchronized toggle); stable while
//                               busy=1
//   snap_q         clk -> TCK   multi-bit, loaded only on the synchronized ack
//                               edge; written one cycle before ack toggles
//
//
// **** RESET BEHAVIOUR ****
//
//   jtag_nRst   asynchronous reset of the TCK side (TRST# / POR)
//   nRst        asynchronous reset of the IP side
//   tdr_rst     Test-Logic-Reset (level, active high): re-synchronizes the
//               request toggle to the acknowledged one. Recovers the TDR after a
//               TCK-side reset (OpenOCD always starts with Test-Logic-Reset).
//               If issued with a transaction in flight, a second TLR may be
//               needed. An IP reset with a pending request re-executes it when
//               the IP leaves reset.
//
//
// Author: Alex R!


module jtag_tdr_snapshot #(
	parameter int unsigned          	DATA_W  	= 32,
	parameter logic [(DATA_W - 1) : 0]	RESET_VALUE = '0     // data_out after nRst
) (
	// TAP BUS: tdr_tck domain
	input  logic jtag_nRst,
	input  logic tdr_rst,
	input  logic tdr_tck,
	input  logic tdr_tdi,
	input  logic tdr_capture,
	input  logic tdr_shift,
	input  logic tdr_update,
	input  logic sel,
	output logic tdo,

	// IP BUS: clk domain
	input  logic                 	clk,
	input  logic                 	nRst,
	input  logic [(DATA_W - 1) : 0] data_in,         // sampled (snapshot) on every transaction
	output logic [(DATA_W - 1) : 0] data_out,        // registered, holds its value
	output logic                 	data_out_valid   // one clk-cycle pulse per write
);

	localparam int unsigned DR_W = DATA_W + 1;

	// -----------------------------------------------------------------------------
	// TCK domain
	// -----------------------------------------------------------------------------

	logic [(DR_W - 1) : 0]		shift_q;
	logic [(DATA_W - 1) : 0] 	wr_data_q;      // stable while busy
	logic                 		wr_en_q;        // stable while busy
	logic                 		req_toggle_q;
	logic                 		ack_sync;       // ack_toggle_q synchronized to tck
	logic                 		ack_sync_d1;    // edge detection
	logic [(DATA_W - 1) : 0] 	rd_data_q;
	logic                 		busy, ack_edge, do_update;

	// clk-domain register read under ack
	logic [(DATA_W - 1) : 0] snap_q;

	assign busy      = (req_toggle_q != ack_sync);
	assign ack_edge  = (ack_sync != ack_sync_d1);
	assign do_update = sel & tdr_update & ~busy;
	assign tdo       = shift_q[0];

	always_ff @(posedge tdr_tck or negedge jtag_nRst) begin
		if (!jtag_nRst) begin
			shift_q      <= '0;
			wr_data_q    <= '0;
			wr_en_q      <= 1'b0;
			req_toggle_q <= 1'b0;
			ack_sync_d1  <= 1'b0;
			rd_data_q    <= '0;
		end else begin
			ack_sync_d1 <= ack_sync;

			// standard TDR shift register. If the acknowledge edge coincides with
			// Capture-DR (OpenOCD's shortest path Run-Test/Idle -> Select-DR ->
			// Capture-DR reaches the capture edge exactly when rd_data_q is being
			// loaded), take snap_q directly: it has been stable since ack toggled.
			if (sel && tdr_capture) shift_q <= {(ack_edge ? snap_q : rd_data_q), busy};
			if (sel && tdr_shift)   shift_q <= {tdr_tdi, shift_q[(DR_W - 1) : 1]};

			// launch a transaction: freeze the payload and flip the request toggle
			if (do_update) begin
				wr_data_q    <= shift_q[(DR_W - 1) : 1];
				wr_en_q      <= shift_q[0];
				req_toggle_q <= ~req_toggle_q;
			end

			// response: snap_q has been stable since before ack toggled
			if (ack_edge) rd_data_q <= snap_q;

			// Test-Logic-Reset: re-synchronize
			if (tdr_rst) req_toggle_q <= ack_sync;
		end
	end

	// -----------------------------------------------------------------------------
	// IP CLK domain
	// -----------------------------------------------------------------------------

	logic                 		req_sync;       // req_toggle_q synchronized to clk
	logic                 		req_sync_d1;
	logic                 		req_pulse;      // cycle 1: a transaction arrived -> register data_out
	logic                 		req_pulse_d1;   // cycle 2: data_out_valid (data_out already updated)
	logic                 		req_pulse_d2;   // cycle 3: snapshot + acknowledge
	logic                 		ack_toggle_q;
	logic [(DATA_W - 1) : 0] 	data_out_q;

	assign req_pulse      = (req_sync != req_sync_d1);
	assign data_out       = data_out_q;
	assign data_out_valid = req_pulse_d1 & wr_en_q;

	always_ff @(posedge clk or negedge nRst) begin
		if (!nRst) begin
			req_sync_d1  <= 1'b0;
			req_pulse_d1 <= 1'b0;
			req_pulse_d2 <= 1'b0;
			ack_toggle_q <= 1'b0;
			snap_q       <= '0;
			data_out_q   <= RESET_VALUE;
		end else begin
			req_sync_d1  <= req_sync;
			req_pulse_d1 <= req_pulse;
			req_pulse_d2 <= req_pulse_d1;

			// cycle 1: register the write (payload has been stable since the TCK side froze it)
			if (req_pulse && wr_en_q) data_out_q <= wr_data_q;

			// cycle 2: data_out_valid is high (assign above)

			// cycle 3: snapshot and acknowledge (IP response to the write)
			if (req_pulse_d2) begin
				snap_q       <= data_in;
				ack_toggle_q <= ~ack_toggle_q;
			end
		end
	end

	// -----------------------------------------------------------------------------
	// SYNCHRONIZERS
	// -----------------------------------------------------------------------------

	tc_sync #(
		.Stages(2)
	) u_sync_req (
		.clk_i		(clk),
		.rst_ni		(nRst),
		.serial_i	(req_toggle_q),
		.serial_o	(req_sync)
	);

	tc_sync #(
		.Stages(2)
	) u_ack_req (
		.clk_i		(tdr_tck),
		.rst_ni		(jtag_nRst),
		.serial_i	(ack_toggle_q),
		.serial_o	(ack_sync)
	);

	// -----------------------------------------------------------------------------
	// SIMULATION ASSERTS
	// -----------------------------------------------------------------------------

	`ifndef SYNTHESIS
		a_cap_upd   : assert property (@(posedge tdr_tck) disable iff (!jtag_nRst) !(tdr_capture && tdr_update))
						else $error("%m: capture and update asserted together");
		a_cap_shift : assert property (@(posedge tdr_tck) disable iff (!jtag_nRst) !(tdr_capture && tdr_shift))
						else $error("%m: capture and shift asserted together");
		a_sel_shift : assert property (@(posedge tdr_tck) disable iff (!jtag_nRst) (sel && tdr_shift) |=> sel)
						else $error("%m: sel changed during shift");
		a_wr_stable : assert property (@(posedge tdr_tck) disable iff (!jtag_nRst)
										(busy && $past(busy)) |-> ($stable(wr_data_q) && $stable(wr_en_q)))
						else $error("%m: write payload changed while busy");
		a_snap_stable : assert property (@(posedge clk) disable iff (!nRst)
										!req_pulse_d1 |-> $stable(snap_q))
						else $error("%m: snapshot changed outside the acknowledge cycle");
		 a_valid_data : assert property (@(posedge clk) disable iff (!nRst)
                                   data_out_valid |-> (data_out == wr_data_q))
                else $error("%m: data_out_valid with stale data_out");

		always @(posedge tdr_tck)
			if (jtag_nRst && sel && tdr_update && busy)
			$warning("%m: Update-DR ignored (busy=1) at %t", $time);
	`endif

endmodule