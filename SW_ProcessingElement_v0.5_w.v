


/* NOTES:
	- this version of the processing element is ... * UNDER CONSTRUCTION *
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/

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
		`ifdef _DEBUGGING_
			// monitoring ports for debugging:
		, output M_open_r, 
			I_extend_r,
			diag_max_r,
			LUT_r, data_r,
			M_diag,
			I_diag
		`endif
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
// score 1st stage:
localparam sc1_idle=3'b10, sc1_calculate=3'b01; 
reg [1:0] state_sc_1;		// state register

// score 2nd stage:
localparam sc2_idle=3'b10, sc2_calculate=3'b01; 
reg [1:0] state_sc_2;		// state register

// high score stage:
localparam hs_idle=3'b10, hs_calculate=3'b01; 
reg [1:0] state_hs;			// state register


/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag;		// score of the respective diagonal element in "M"
reg [SCORE_WIDTH-1:0] I_diag;		// score of the respective diagonal element in "I"

// "wires" (used only in combinational logic):
reg [SCORE_WIDTH-1:0] LUT;			// hold the match/mismatch penalty correspodning to target(data_in) and query bases
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

// 1st stage registers:
reg [SCORE_WIDTH-1:0] M_open_r; 
reg [SCORE_WIDTH-1:0] I_extend_r; 	
reg [SCORE_WIDTH-1:0] diag_max_r; 	
reg [SCORE_WIDTH-1:0] LUT_r;
reg [1:0] data_r;
reg en_s;							// enable for stage 2 
reg [SCORE_WIDTH-1:0] M_out_l;   
reg [SCORE_WIDTH-1:0] I_out_l;  

/* ----- END of internal signals. ----- */

// ========================================					
// ========= Score stage logic: ===========
	
	//#################### STAGE 1: #####################
	
	// ---- 1st stage Combinational part: ----

	always@*
	begin: SC1_COMB
		// avoid latching:
		LUT = 0; 
		diag_max = 0;
		I_max = 0;
		M_max = 0;
		M_open = 0;
		I_extend = 0;
        //$display("stage1 comb");
		LUT = (data_in == query)? match : mismatch; //  the proper match penalty
		if(state_sc_1 == sc1_calculate)		
		begin
			// "M" matrix logic:			
			diag_max = `MAX(M_diag, I_diag); 		// find max between the two matrices diagonals
			
			// "I" matrix logic:
			I_max = `MAX(I_in, I_out_l);				// calculate max between left and upper neighbour in "I"	!X! 1 cycle later?
			M_max = `MAX(M_in, M_out_l); 				// calculate max between left and upper neighbour in "M"	!X! 1 cycle later?
			M_open = M_max + gap_open + gap_extend; // penalty to open an extra gap		!X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = I_max + gap_extend; 			// penalty to extend an existing gap
				
		end else
		begin
			// "M" matrix logic:
			diag_max = `MAX(M_diag, I_diag); 		// find max between the two matrices diagonals
			
			// "I" matrix logic:
			I_max = `MAX(I_in, I_out_l); 				// calculate max between left and upper neighbour in "I"	!X! 1 cycle later?
			M_max = `MAX(M_in, M_out_l); 				// calculate max between left and upper neighbour in "M"	!X! 1 cycle later?
			M_open = ZERO + gap_open + gap_extend; 	// penalty to open the first gap in the current sequence	!X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = ZERO + gap_extend;			// extend "non-existing" gap (Insert gap before the first base in the sequence)			

		end
		
	end
	
	
	// ---- 1st stage sequential part: ----
	
	always@(posedge clk)
	begin: sc1_SEQ
		if(rst==1'b0)
		begin
			/* set regs to initial state!!!*/
			en_s <= 1'b0;
			M_open_r <= ZERO;
			I_extend_r <= ZERO;
			diag_max_r <= ZERO;
			LUT_r <= ZERO ;
			data_r <= 2'b00;
			M_diag <= ZERO;
			I_diag <= ZERO ;						//  !X!  ->  gap_extend???	
			state_sc_1 <= sc1_idle;
		end
		else begin
			//$display("stage1 seq");
			en_s <= en_in;
			//data_r <= data_in;
			case(state_sc_1)
			
			sc1_idle:
				if(en_in==1'b1)
				begin // latch results:
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag <= M_in;	 				// score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;				//  !X!  ->  gap_extend???
					state_sc_1 <= sc1_calculate;
				end
				else begin // idle:
				//set output to zero: 		    
					en_s <= 1'b0;
					M_open_r <= ZERO;
					I_extend_r <= ZERO;
					diag_max_r <= ZERO;
					LUT_r <= ZERO ;
					data_r <= 2'b00;
					M_diag <= ZERO;
					I_diag <= ZERO;					//  !X!  ->  gap_extend???	
				end // EN_IN == 0
			
			sc1_calculate:
				if(en_in==1'b0) 
				begin // show result.
					en_s <= 1'b0;
					// flush stage registers:
					// M_open_r <= ZERO;
					// I_extend_r <= ZERO;
					// diag_max_r <= ZERO;
					// LUT_r <= ZERO ;
					// data_r <= 2'b00;
					// M_diag <= ZERO;
					// I_diag <= ZERO ;
					state_sc_1 <= sc1_idle;
				end
				else begin // continue latching
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag <= M_in;					// score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;				//  !X!  ->  gap_extend???
				end // en_iN == 1
			default: state_sc_1 <= sc1_idle;		// go to safe state
			endcase
		end
	end
	
	// ################## STAGE 2: ######################
	
	// ---- 2nd stage Combinational part: ----

	always@*
	begin: sc2_COMB
		// avoid latching:	
        //$display("stage2 comb");		
		M_score = 0;
		M_bus = 0;
		I_bus = 0;
		if(state_sc_2 == sc2_calculate)		
		begin
			// "M" matrix logic:			
			M_score = LUT_r + diag_max_r;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!

			// "I" matrix logic:
			I_bus = `MAX(M_open_r, I_extend_r); 		//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		end else
		begin
			// "M" matrix logic:
			M_score = LUT_r + ZERO;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!
			
			// "I" matrix logic:	
			I_bus = `MAX(M_open_r, I_extend_r); 		//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		end
		
	end
	
	
	// ---- 2nd stage sequential part: ----
	
	always@(posedge clk)
	begin: sc2_SEQ
		if(~rst)
		begin
			/* set regs to initial state!!!*/
			en_out <= 1'b0;
			M_out <= ZERO;
			I_out <= ZERO;
			M_out_l <= ZERO;
			I_out_l <= ZERO;	
			data_out <= 2'b00;
			// High_in_l2 <= ZERO;				// latch high in 
			state_sc_2 <= sc2_idle;
		end
		else begin
			en_out <= en_s;
			// latch outputs back to 1st stage:
			M_out_l <= M_out;
			I_out_l <= I_out;
			//data_out <= data_r;
			// $display("stage2 seq");
			case(state_sc_2)
			
			sc2_idle:
				if(en_s==1'b1)
				begin // start calculating
					// do 1st iteration calculation here:					!X!
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 	 				// connect score bus to output reg 
					// M_out_l <= M_out;
					// I_out_l <= I_out;
					data_out <= data_r;
					en_out <= 1'b1;
					state_sc_2 <= sc2_calculate;
				end
				else begin // waiting for data
				// set output to zero: 		    
					M_out <= ZERO;
					I_out <= ZERO;
					M_out_l <= ZERO;
					I_out_l <= ZERO;
					en_out <= 1'b0;
					data_out <= 2'b00;
				end // en_s == 0
			
			sc2_calculate:
				if(en_s==1'b0) 
				begin // show result.
					en_out <= 1'b0;
					state_sc_2 <= sc2_idle;
					M_out <= ZERO;
					I_out <= ZERO;
					M_out_l <= ZERO;
					I_out_l <= ZERO;
				end
				else begin // continue calculating.
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 					// connect score bus to output reg 
					data_out <= data_r;
				end // en_s == 1
			default: state_sc_2 <= sc2_idle; 				// go to safe state
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
		H_max = `MAX(High_in, High_out);		// max between current PE's high score, and its left neighbour
		H_bus = `MAX(`MUX(state_hs == hs_calculate, H_max, High_in), I_M_max); 		// ignore self high score, if it's in idle state
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
