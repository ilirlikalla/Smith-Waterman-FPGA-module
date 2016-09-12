


/* NOTES:
	- this version of the processing element is a pipelined design(2-stage). The logic is more refined than the
	previous versions, in order to help the synthesis tool for speed optimisation. This is the
	fastest version, with a 2-stage pipeline. (combinational logic is not gated by the enable and reset signals )
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/
//`define _DEBUGGING_
`define MAX(x,y)  ((x > y)? x :y)
`define MUX(c,x,y) ((c)? x :y)
module SW_ProcessingElement
   #( parameter
		SCORE_WIDTH = 12,	// result width in bits
		_A = 2'b00,        	// nucleotide "A"
		_G = 2'b01,        	// nucleotide "G"
		_T = 2'b10,        	// nucleotide "T"
		_C = 2'b11,        	// nucleotide "C"
		ZERO  = (2**(SCORE_WIDTH-1)) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	)(
// inputs:
		clk,
		rst, 				// active low 
		en_in,
		data_in,
		query,
		M_in,
		I_in,
		High_in,
		match,				// LUT
		mismatch,			// LUT
		gap_open,			// LUT
		gap_extend, 		// LUT
// outputs:
	    data_out,
		M_out,
		I_out,
		High_out,
		en_out,
		vld
		);
			
	
	 
/* ------- Inputs: -----------*/
input wire clk;
input wire rst;
input wire en_in;						//enable input
input wire [1:0] data_in;				// target base input		  		
input wire [1:0] query;					// query base input
input wire [SCORE_WIDTH-1:0] M_in;		// "M": Match score matrix from left neighbour 
input wire [SCORE_WIDTH-1:0] I_in;		// "I": In-del score matrix from left neighbour
input wire [SCORE_WIDTH-1:0] High_in; 	// highest score from left neighbour
// ---- LUT inputs: -------
input wire [SCORE_WIDTH-1:0] match;		// match penalty from LUT
input wire [SCORE_WIDTH-1:0] mismatch;	// mismatch penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_open; 	// gap open penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_extend;// gap extend penalty from LUT
// ---- LUT inputs END.----

/* -------- Outputs: ---------*/
output reg [1:0] data_out;				// target base out to next cell
output reg [SCORE_WIDTH-1:0] M_out;		// match score out to right neighbour
output reg [SCORE_WIDTH-1:0] I_out;		// in-del score out to right neighbour
output reg [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
output reg en_out;						// enable signal for the right neighbour
output reg vld;							// valid flag, is set when sequence score has been calculated


// state definition in one-hot encoding:
// score stage:
localparam sc_idle=3'b10, sc_calculate=3'b01; //, RESULT=3'b001; 
reg [1:0] state_sc;        // state register
// high score stage:
localparam hs_idle=3'b10, hs_calculate=3'b01; //, RESULT=3'b001; 
reg [1:0] state_hs;        // state register


/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag;		// score of the respective diagonal element in "M"
reg [SCORE_WIDTH-1:0] I_diag;		// score of the respective diagonal element in "I"

// "wires" (used only in combinational logic):
reg [SCORE_WIDTH-1:0] LUT;
reg [SCORE_WIDTH-1:0] M_score; 		// keeps the "M" matrix score before comparison with ZERO
reg [SCORE_WIDTH-1:0] M_bus; 		// the bus keeps the final "M" matrix score
reg [SCORE_WIDTH-1:0] diag_max; 	// max diagonal between the "I" & "M" diagonals score
reg [SCORE_WIDTH-1:0] I_max; 		// max between "I" left and up elements score
reg [SCORE_WIDTH-1:0] M_max; 		// max between "M" left and up elements score
reg [SCORE_WIDTH-1:0] M_open; 		// penalty for starting a new gap sequence
reg [SCORE_WIDTH-1:0] I_extend; 	// penalty for extending an existing gap sequence
reg [SCORE_WIDTH-1:0] I_bus; 		// the bus keeps the final "I" matrix score
reg [SCORE_WIDTH-1:0] I_M_max; 		// max betwwen "I" & "M" scores
reg [SCORE_WIDTH-1:0] H_max; 		// max betwwen "I_M_max" & "High_out" 
reg [SCORE_WIDTH-1:0] H_bus; 		// high score bus

/* ----- END of internal signals. ----- */
//`ifdef _DEBUGGING_
//	integer file;
//	initial
//	begin 
//		file = $fopen("SW_PE_v_03");
//		$fmonitor(file,"@%8tns: M_open_r:%d, I_extend_r:%d, diag_max_r:%d, LUT_r:%d, data_r:%d, M_diag:%d, I_diag:%d",
//						$time, M_open, I_extend, diag_max, LUT, data_in, M_diag, I_diag);
//		$fclose(file);
//	end				
//`endif	

// ========================================					
// ========= Score stage logic: ===========
	
	// ---- Combinational part: ----

	always@*
	begin: SC_COMB
		// avoid latching:
		LUT = 0; 
		diag_max = 0;
		M_score = 0;
		M_bus = 0;
		I_max = 0;
		M_max = 0;
		M_open = 0;
		I_extend = 0;
		I_bus = 0;
		
		if(state_sc == sc_calculate)		
		begin
			LUT = (data_in == query)? match : mismatch; //  the proper match penalty
			
			// "M" matrix logic:			
			diag_max = `MAX(M_diag, I_diag); 		// (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
			M_score = LUT + diag_max;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!

			// "I" matrix logic:
			I_max = `MAX(I_in, I_out); 				//(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
			M_max = `MAX(M_in, M_out); 				//(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
			M_open = M_max + gap_open + gap_extend; // penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = I_max + gap_extend; 			// penalty to extend gap in current alignment			
			I_bus = `MAX(M_open, I_extend); 		//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		end else
		begin
		    LUT = (data_in == query)? match : mismatch; //  the proper match penalty
			// "M" matrix logic:
			diag_max = `MAX(M_diag, I_diag); 		// (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
			M_score = LUT + ZERO;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!
			
			// "I" matrix logic:
			I_max = `MAX(I_in, I_out); 				//(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
			M_max = `MAX(M_in, M_out); 				//(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
			M_open = ZERO + gap_open + gap_extend; 	// penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = ZERO + gap_extend;			// penalty to extend gap in current alignment			
			I_bus = `MAX(M_open, I_extend); 		//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		end
		
	end
	
	
	// ---- sequential part: ----
	
	always@(posedge clk)
	begin: SC_SEQ
		if(rst==1'b0)
		begin
			/* set regs to initial state!!!*/
			en_out <= 1'b0;
			M_out <= ZERO;
			I_out <= ZERO;
			M_diag <= ZERO;
			I_diag <= ZERO ;//+ gap_extend;			//  !X!  ->  gap_extend???	
			data_out <= 2'b00;
			state_sc <= sc_idle;
		end
		else begin
			en_out <= en_in;
			case(state_sc)
			
			sc_idle:
				if(en_in==1'b1)
				begin // start calculating
					// do 1st iteration calculation here:					!X!
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 	 				// connect score bus to output reg 
					M_diag <= M_in;   					// score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= data_in;
					en_out <= 1'b1;
					state_sc <= sc_calculate;
				end
				else begin // waiting for data
				//set output to zero: 		    
					M_out <= ZERO;
					I_out <= ZERO;
					en_out <= 1'b0;
					M_diag <= ZERO;
					I_diag <= ZERO ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= 2'b00;
				end // EN_IN == 0
			
			sc_calculate:
				if(en_in==1'b0) 
				begin // show result.
					en_out <= 1'b0;
					state_sc <= sc_idle;
				end
				else begin // continue calculating.
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 					// connect score bus to output reg 
					M_diag <= M_in;	 					// score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= data_in;
				end // en_iN == 1
			default: state_sc <= sc_idle; 				// go to safe state
			
			endcase
		end
	end
// ====== END of Score stage logic. =======
// ========================================					


// ========================================					
// ======= High Score stage logic: ========
	
	// ---- Combinational part: ----

	always@*
	begin: HS_COMB
		// avoid latching:
		H_max = 0;
		I_M_max = 0;
		
        I_M_max = `MAX(M_out, I_out); 			// max between "I" and "M" matrices
		// if(state_hs == hs_idle)
			// H_max =  (I_M_max[SCORE_WIDTH-1] == 1'b1)? I_M_max :ZERO; //`MAX(ZERO, I_M_max);  // check if I_M_max is greater than zero
        // else if(state_hs == hs_calculate)
		H_max = `MAX(High_in, High_out);		// max between current PE's high score, and its left neighbour
		H_bus = `MAX(`MUX(state_hs == hs_calculate, H_max, High_in), I_M_max); 		// final high score
	end
	
	
	// ---- sequential part: ----
	
	always@(posedge clk)
	begin: HS_SEQ
		if(rst==1'b0)
		begin
			/* set regs to initial state!!!*/
			vld <= 1'b0;
			High_out <= ZERO;
			state_hs <= hs_idle;
		end
		else begin
			case(state_hs)
			
			hs_idle:
				if(en_out==1'b1)
				begin // start calculating
					// do 1st iteration calculation here:					!X!
					High_out <= H_bus;					// compare current PE's high score with the left neighbour's 
					vld <= 1'b0;	
					state_hs <= hs_calculate; 
				end
				else begin // waiting for data
				//set output to zero: 		    
					vld <= 1'b0; 
					High_out <= ZERO;
				end
			
			hs_calculate:
				if(en_out==1'b0) 
				begin // show result.
					vld <= 1'b1;
					state_hs <= hs_idle;
				end
				else // continue calculating.
					High_out <= H_bus;	// compare current PE's high score with the left neighbour's 
			
			endcase
		end
	end
// ==== END of High Score stage logic. ====
// ========================================	
						
						
endmodule 
