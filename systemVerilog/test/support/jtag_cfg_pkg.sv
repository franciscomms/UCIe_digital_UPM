/*   
*   JTAG TAP Configuration
*
*   Author: Alex R!
*/

package jtag_cfg_pkg;

	// JTAG IR REGISTER LENGTH
	localparam int unsigned JTAG_IR_WIDTH = 5;	// Minimum of 5 bits to satisfy RISC-V DEBUG SPEC !!!

	// TDRs ENUM

	//-------- RISCV DEBUG SPEC RESERVED IR CODES --------//
	//							 				  	      //
	//  0x00 -> BYPASS (VIA EXTEST)	| INTERNALLY MANAGED  //
	//  0x01 -> IDCODE			 	| INTERNALLY MANAGED  //
	//  0x02 -> BYPASS (VIA SAMPLE)	| INTERNALLY MANAGED  //
	//													  //
	//  0x03 to 0x0F -> **** FREE **** (13 OPCODES)	      //
	//  0x10 -> RISC-V DTMCS     				  	      //
	//  0x11 -> RISC-V DMI	    				  	      //
	//  0x12 to 0x17 -> RESERVED (ROUTED TO BYPASS)	      //
	//  0x18 to 0x1E -> **** FREE **** (7 OPCODES) 	      //
	//													  //
	//  0x1F -> BYPASS				| INTERNALLY MANAGED  //
	//----------------------------------------------------//

	typedef enum logic [(JTAG_IR_WIDTH - 1) : 0] {
		BYPASS_0	= 'h00, 
		IDCODE 		= 'h01,
		TDR_SNAP 	= 'h03,
		TDR_STEP 	= 'h04,
		RV_DTMCS 	= 'h10,
		RV_DMI		= 'h11,
		BYPASS_1   	= 'h1f
	} tdr_id_t;

	// JTAG ID CODE (FOR NOW SAME AS XHEEP 32'h1000_1C05)
	localparam logic [10:0] JTAG_IDCODE_MAN_NUM 	= 11'h602;	
	localparam logic [15:0] JTAG_IDCODE_PART_NUM 	= 16'h0001;
	localparam logic [3:0]  JTAG_IDCODE_VER_NUM		= 4'h1;

	localparam logic [31:0]  JTAG_IDCODE_VALUE	= {
		JTAG_IDCODE_VER_NUM,
		JTAG_IDCODE_PART_NUM,
		JTAG_IDCODE_MAN_NUM,
		1'b1
	};

endpackage