// Author: Ilir Likalla

/* NOTES:
	- this version of the afu control unit is ... * UNDER CONSTRUCTION *
	- coded based on VERILOG 2001 standard.
	- protocol and commands are based on CAPI User's Manual version 1.2
	- possible faults are associated by the comment "!X!"
*/



module afu_control
   #(	parameter
	// control interface instructions given by PSL:
	J_RESET    =	8'h80,		
	J_START    =	8'h90,	
	J_TIMEBASE =	8'h42,					// not supported
	// command interface instructions:
	READ_CL_NA = 	13'h0A00,				// read cache line and do not allocate
	WRITE_NA   =	13'h0D00				// write cache line and do not allocate
    )(
	input           ha_jval,
	input  [0:7]    ha_jcom,
	input           ha_jcompar,
	input  [0:63]   ha_jea,
	input           ha_jeapar,
	output          ah_jrunning,
	output          ah_jdone,
	output [0:63]   ah_jerror,
	input           ha_pclock,
	// wed request (dma) signals:
	input           misc_ready,
	output          misc_req,
	output [0:56]   misc_addr,
	output [0:12]   misc_com,
	output [0:1023] misc_wr_data,
	input  [0:1023] misc_rd_data,
	// read request (dma) signals:
	input           read_ready,
	output          read_req,
	output  [0:63]  read_addr,
	output  [0:63]  read_size,
	// write request (dma) signals:
	input           write_ready,
	output          write_req,
	output  [0:63]  write_addr,
	output  [0:63]  write_size,
	// afu control (dma & mmio error) signals:
	output          reset,
	input           done,
	input           odd_parity,
	input   [0:12]  detect_err,
	// mmio signals:
	input           done_premmio,
	input           done_postmmio,
	output reg      start_premmio,
	output reg      start_postmmio,
	// ----- aligner control signals: -----
	// *** application signals go here: ***
	output endianess
	
	// ------------------------------------
	);


	// ---- Internal Signals: ----
	
	// state encoding:
	localparam 
		st_idle 		= 12'b100000000000,
		st_premmimo 	= 12'b010000000000,
		st_read_req		= 12'b001000000000,
		st_wed_wr_req	= 12'b000100000000,
		st_wed_wr_wait	= 12'b000010000000,
		st_wed_rd_wait	= 12'b000001000000;
		
	// ===============================================
	// ============ Control I/F Management: ==========
	// --- Internal signals: ---

	reg           reset_int;
	reg           start_int;
	reg           other_int;
	reg           done_int;
	reg           reset_l;
	reg           running_l;
	reg           done_l;
	reg  [0:63]   error_l;
	reg  [0:63]   error_ll;
	reg  [0:7]    jcom_l;
	reg           jcompar_l;
	reg  [0:63]   jea_l;
	reg           jeapar_l;
	reg  [0:14]   detect_error_l;

	wire        all_done;
	wire        jcompar_ul;
	wire        jeapar_ul;
	wire [0:14] detect_error;
	wire        enable_errors;
	wire        error_detected;

	// ---- AFU control I/F logic (error management & decode logic): ----

	assign logic_major = 16'h0;
	assign logic_minor = 16'h1;
	assign enable_errors = 1'b0;
	
	// decode control interface instruction:
	always@(posedge ha_pclock)
	if(~ha_jval) 					// if not a valid control command reset AFU
	begin
		reset_int <= 0;
		start_int <= 0;
		other_int <= 0;
	end else
	begin						
		case(ha_jcom)
			J_RESET:
			begin
				reset_int <= 1;		// reset AFU
				start_int <= 0;	
		     	other_int <= 0;
			end
			
			J_START:
			begin
				reset_int <= 0;
				start_int <= 1;		// start AFU
				other_int <= 0;
			end
			
			default:				 
			begin
				reset_int <= 0;
				start_int <= 0;	
		     	other_int <= 1;		// report command error
			end
		endcase
	end
	

	// --- error management logic: ---

	assign error_detected = enable_errors & |detect_error_l;

	// On parity error detection send reset to all other logic immediately
	assign reset = reset_int || error_detected;

	assign all_done = error_detected || (done && (st_idle && !start_int));

	always @ (posedge ha_pclock) begin
	if (reset_int || all_done)
	  running_l <= 1'b0;
	else if (start_int || running_l)
	  running_l <= 1'b1;
	end

	assign ah_jrunning = running_l;

	// On parity error set appropriate error bit
	always @ (posedge ha_pclock) begin
	if (enable_errors)
	  error_l <= {48'h000000000000, detect_error_l, other_int};
	else
	  error_l <= 64'h0000000000000000;
	end

	assign ah_jerror = error_l;

	always @ (posedge ha_pclock) begin
	if (reset_int)
	  error_ll <= 64'h0000000000000000;
	else
	  error_ll <= error_ll | error_l;
	end

	// On parity error signal jdone immediately
	always @ (posedge ha_pclock) begin
	if (reset_int || start_int || other_int && !(error_detected))
	  done_l <= 1'b0;
	else if (all_done || (error_detected))
	  done_l <= 1'b1;
	end

	always @ (posedge ha_pclock) begin
	if (all_done && ~done_l)
	  done_int <= 1'b1;
	else
	  done_int <= 1'b0;
	end

	assign ah_jdone = done_int;




	// --- Parity checking ---

	always @ (posedge ha_pclock) begin
	if (ha_jval)
	  jcom_l <= ha_jcom;
	else if (done_int)
	  jcom_l <= 8'h0;
	end

	always @ (posedge ha_pclock) begin
	if (ha_jval)
	  jcompar_l <= ha_jcompar;
	else if (done_int)
	  jcompar_l <= odd_parity;
	end

	parity #(
	.BITS(8)
	) jcom_parity (
	.data(jcom_l),
	.odd(odd_parity),
	.par(jcompar_ul)
	);

	always @ (posedge ha_pclock) begin
	if (ha_jval)
	  jea_l <= ha_jea;
	else if (done_int)
	  jea_l <= 64'h0;
	end

	always @ (posedge ha_pclock) begin
	if (ha_jval)
	  jeapar_l <= ha_jeapar;
	else if (done_int)
	  jeapar_l <= odd_parity;
	end

	parity #(
	.BITS(64)
	) jea_parity (
	.data(jea_l),
	.odd(odd_parity),
	.par(jeapar_ul)
	);

	assign detect_error[0] = jcompar_l ^ jcompar_ul;
	assign detect_error[1] = jeapar_l ^ jeapar_ul;
	assign detect_error[2:14] = detect_err;

	always @ (posedge ha_pclock)
	detect_error_l <= detect_error;
	
	// ======== End of Control I/F Management ========
	// ===============================================	



	// ===============================================
	// ============ Aligner Control Logic: ===========
	//  (custom application control logic goes here)
	
	// UNDER CONSTRUCTION ...
	wire        little_endian;

	assign endianess = little_endian;

endmodule
