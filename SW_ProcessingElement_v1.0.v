// Author: Ilir Likalla


/* NOTES:
	- this version of the processing element is ... * UNDER CONSTRUCTION *
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/

`define MAX(x,y)  ((x > y)? x :y)
`define MUX(c,x,y) ((c)? x :y)
module SW_ProcessingElement_v1 
	#( parameter
		SCORE_WIDTH = 12,	// result width in bits
		_A = 2'b00,        	// nucleotide "A"	(for future use!)
		_G = 2'b01,        	// nucleotide "G"
		_T = 2'b10,        	// nucleotide "T"
		_C = 2'b11,        	// nucleotide "C"
		ZERO  = (2**(SCORE_WIDTH-1)) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	)(
// inputs:
		clk,
		rst, 				// active low 
		toggle_in,
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
		toggle_out,
		vld0,
		vld1
		);
			

	 
/* ------- Inputs: -----------*/
input wire clk;
input wire rst;
input wire en_in;						// enable input
input wire toggle_in;					// toggles calculation process between different sequences
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
output reg toggle_out;					// toggle signal for the right neighbour
output reg vld0;						// valid flag, is set when the toggle 0 sequence score has been calculated
output reg vld1;						// valid flag, is set when the toggle 1 sequence score has been calculated


// state definition in one-hot encoding:
localparam idle=2'b10, calculate=2'b01; 
reg [3:0] state_sc_1;		// 1st stage state register
wire [4:0] sc1_state;
reg [3:0] state_sc_2;		// 2nd stage state register
wire [4:0] sc2_state;
reg [3:0] state_hs;			// high score stage state register
wire [4:0] hs_state;

/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag0;		// score of the diagonal element in "M" for toggle 0
reg [SCORE_WIDTH-1:0] I_diag0;		// score of the diagonal element in "I" for toggle 0
reg [SCORE_WIDTH-1:0] M_diag1;		// score of the diagonal element in "M" for toggle 1
reg [SCORE_WIDTH-1:0] I_diag1;		// score of the diagonal element in "I" for toggle 1

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
reg en_s;							// enable for 2nd stage 
reg toggle_s;						// toggle for 2nd stage   

/* ----- END of internal signals. ----- */


// ========================================					
// ========= Score stage logic: ===========
	
	//#################### STAGE 1: #####################
	assign sc1_state = {toggle_in, state_sc_1};
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
		if( (sc1_state == {1'b0, state_sc_1[3:2], calculate}) || (sc1_state == {1'b1, calculate, state_sc_1[1:0]}) )		
		begin
			// "M" matrix logic:			
			diag_max = `MAX(`MUX(toggle_in,M_diag1, M_diag0), `MUX(toggle_in, I_diag1, I_diag0)); 		// (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
//$display("here c --------------");
			// "I" matrix logic:
			I_max = `MAX(I_in, I_out); 				//(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
			M_max = `MAX(M_in, M_out); 				//(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
			M_open = M_max + gap_open + gap_extend; // penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = I_max + gap_extend; 			// penalty to extend gap in current alignment			
				//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		end else
		begin
			// "M" matrix logic:
			diag_max = `MAX(`MUX(toggle_in,M_diag1, M_diag0), `MUX(toggle_in, I_diag1, I_diag0)); 		// (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
			
			// "I" matrix logic:
			I_max = `MAX(I_in, I_out); 				//(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
			M_max = `MAX(M_in, M_out); 				//(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
			M_open = ZERO + gap_open + gap_extend; 	// penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
			I_extend = ZERO + gap_extend;			// penalty to extend gap in current alignment			

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
			M_diag0 <= ZERO;
			I_diag0 <= ZERO ;							//  !X!  ->  gap_extend???	
			M_diag1 <= ZERO;
			I_diag1 <= ZERO ;							//  !X!  ->  gap_extend???	
			state_sc_1 <= {idle, idle};
		end
		else begin
			en_s <= en_in;
			toggle_s <= toggle_in;
			case({toggle_in, state_sc_1})
				// --- states for toggle flag = 0: ---
			//{1'b0, idle, idle},{1'b0, calculate, idle}:// idle state for toggle 0
			{1'b0, state_sc_1[3:2], idle}:
				if(en_in==1'b1)
				begin // latch results:
	//$display("here2");
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag0 <= M_in;	 				// score from left neighbour serves as diagonal score in the next cycle
					I_diag0 <= I_in ;					//  !X!  ->  gap_extend???  
					state_sc_1 <= {state_sc_1[3:2], calculate};
				end
				else begin // idle:
	//$display("here3");
				//set output to zero: 		    
					en_s <= 1'b0;
					M_open_r <= ZERO;
					I_extend_r <= ZERO;
					diag_max_r <= ZERO;
					LUT_r <= ZERO ;
					data_r <= 2'b00;
					M_diag0 <= ZERO;
					I_diag0 <= ZERO ;					//  !X!  ->  gap_extend???	
				end // EN_IN == 0
			
			{1'b0, state_sc_1[3:2], calculate}:	// calculate state for toggle 0		
				if(en_in==1'b0) 
				begin // show result.
					en_s <= 1'b0;
					//data_r <= 2'b00;
					//M_diag0 <= ZERO;
					//I_diag0 <= ZERO ;					//  !X!  ->  gap_extend???	
					state_sc_1 <= {state_sc_1[3:2], idle};
				end
				else begin // continue latching
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag0 <= M_in;	 			// score from left neighbour serves as diagonal score in the next cycle
					I_diag0 <= I_in ;				//  !X!  ->  gap_extend???
				end // en_iN == 1.
				
			// --- states for toggle flag = 1: ---
			{1'b1, idle, state_sc_1[1:0]}:					// idle state for toggle 1
				if(en_in==1'b1)
				begin // latch results:
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag1 <= M_in;	 			// score from left neighbour serves as diagonal score in the next cycle
					I_diag1 <= I_in ;				//  !X!  ->  gap_extend???  ; 2 pairs of diagonal registers might be needed
					state_sc_1 <= {calculate, state_sc_1[1:0]};
				end
				else begin // idle:
				//set output to zero: 		    
					en_s <= 1'b0;
					M_open_r <= ZERO;
					I_extend_r <= ZERO;
					diag_max_r <= ZERO;
					LUT_r <= ZERO ;
					data_r <= 2'b00;
					M_diag1 <= ZERO;
					I_diag1 <= ZERO ;				//  !X!  ->  gap_extend???	
				end // EN_IN == 0
			
			{1'b1, calculate, state_sc_1[1:0]}:				// calculate state for toggle 1
				if(en_in==1'b0) 
				begin // show result.
					en_s <= 1'b0;
					//data_r <= 2'b00;
					//M_diag1 <= ZERO;
					//I_diag1 <= ZERO ;				//  !X!  ->  gap_extend???	
					state_sc_1 <= {idle, state_sc_1[1:0]};
				end
				else begin // continue latching
					en_s <= 1'b1;
					M_open_r <= M_open;
					I_extend_r <= I_extend;
					diag_max_r <= diag_max;
					LUT_r <= LUT ;
					data_r <= data_in;
					M_diag1 <= M_in;	 			// score from left neighbour serves as diagonal score in the next cycle
					I_diag1 <= I_in ;				//  !X!  ->  gap_extend???
				end // en_iN == 1.
				
			default: state_sc_1 <= {idle, idle}; 	// go to safe state
			endcase
		end
	end
	
	// ################## STAGE 2: ######################
	
	assign sc2_state = {toggle_s, state_sc_2};
	// ---- 2nd stage Combinational part: ----

	always@*
	begin: sc2_COMB
		// avoid latching:	
        //$display("stage2 comb");		
		M_score = 0;
		M_bus = 0;
		I_bus = 0;
		if( (sc2_state == {1'b0, state_sc_2[3:2], calculate}) || (sc2_state == {1'b1, calculate, state_sc_2[1:0]}) )		
		begin
			// "M" matrix logic:			
			M_score = LUT_r + diag_max_r;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!

			// "I" matrix logic:
			I_bus = `MAX(M_open_r, I_extend_r); 	// this bus holds "I" score
		end else
		begin
			// "M" matrix logic:
			M_score = LUT_r + ZERO;
			M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!
			
			// "I" matrix logic:	
			I_bus = `MAX(M_open_r, I_extend_r); 	// this bus holds "I" score
		end
		
	end
	
	
	// ---- 2nd stage sequential part: ----
	
	always@(posedge clk)
	begin: sc2_SEQ
		if(rst==1'b0)
		begin
			/* set regs to initial state!!!*/
			en_out <= 1'b0;
			M_out <= ZERO;
			I_out <= ZERO;		
			data_out <= 2'b00;
			
			state_sc_2 <= {idle, idle};
		end
		else begin
			en_out <= en_s;
			toggle_out <= toggle_s; 		
			
			case(sc2_state)
			// --- states for toggle = 0: ---
			{1'b0, state_sc_2[3:2], idle}:
				if(en_s==1'b1)
				begin // start calculating !X!	
					M_out <= M_bus; 					// connect score bus to output reg
					I_out <= I_bus; 	 				// connect score bus to output reg 
					data_out <= data_r;
					en_out <= 1'b1;
					state_sc_2 <= {state_sc_2[3:2], calculate};
				end
				else begin // waiting for data
				//set output to zero: 		    
					M_out <= ZERO;
					I_out <= ZERO;
					en_out <= 1'b0;
					data_out <= 2'b00;
				end // en_s == 0
			
			{1'b0, state_sc_2[3:2], calculate}:
				if(en_s==1'b0) 
				begin // show result.
					en_out <= 1'b0;
					state_sc_2 <= {state_sc_2[3:2], idle};
				end
				else begin // continue calculating.
					M_out <= M_bus; 					// connect score bus to output reg
					I_out <= I_bus; 					// connect score bus to output reg 
					data_out <= data_r;
				end // en_s == 1
				
			// --- states for toggle = 1: ---
			{1'b1, idle, state_sc_2[1:0]}:
				if(en_s==1'b1)
				begin // start calculatin !X!
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 	 				// connect score bus to output reg 
					data_out <= data_r;
					en_out <= 1'b1;
					state_sc_2 <= {calculate, state_sc_2[1:0]};
				end
				else begin // waiting for data
				//set output to zero: 		    
					M_out <= ZERO;
					I_out <= ZERO;
					en_out <= 1'b0;
					data_out <= 2'b00;
				end // en_s == 0
			
			{1'b1, calculate, state_sc_2[1:0]}:
				if(en_s==1'b0) 
				begin // show result.
					en_out <= 1'b0;
					state_sc_2 <= {idle, state_sc_2[1:0]};
				end	// connect score bus to output reg 
				else begin // continue calculating.
					M_out <= M_bus; 					// connect score bus to output reg 
					I_out <= I_bus; 					// connect score bus to output reg 
					data_out <= data_r;
				end // en_s == 1	
				
			default: state_sc_2 <= {idle, idle}; // go to safe state
			endcase
		end
	end
// ====== END of Score stage logic. =======
// ========================================					


// ========================================					
// ======= High Score stage logic: ========
// ============ ( STAGE 3 )  ==============	

	assign hs_state = {toggle_out, state_hs};
	// ---- Combinational part: ----

	always@*
	begin: HS_COMB
		// avoid latching:
		H_max = 0;
		I_M_max = 0;
        I_M_max = `MAX(M_out, I_out); 			// max between "I" and "M" matrices
		// if(state_hs == idle)
			// H_max =  (I_M_max[SCORE_WIDTH-1] == 1'b1)? I_M_max :ZERO; //`MAX(ZERO, I_M_max);  // check if I_M_max is greater than zero
        // else if(state_hs == calculate)
		H_max = `MAX(High_in, High_out);		// max between current PE's high score, and its left neighbour
		H_bus = `MAX(`MUX( (hs_state == {1'b0, state_hs[3:2], calculate}) || (hs_state == {1'b1, calculate, state_hs[1:0]}) , H_max, High_in), I_M_max); 		// final high score
	end
	
	
	// ---- sequential part: ----
	
	always@(posedge clk)
	begin: HS_SEQ
		if(rst==1'b0)
		begin
			/* set regs to initial state!!!*/
			vld0 <= 1'b0;
			vld1 <= 1'b0;
			High_out <= ZERO;
			state_hs <= {idle, idle};
		end
		else begin
			case(hs_state)
			// --- states for toggle = 0: ---
			{1'b0, state_hs[3:2], idle}:
				if(en_out==1'b1)
				begin // start calculating
					High_out <= H_bus;			// compare current PE's high score with the left neighbour's !X!
					vld0 <= 1'b0;	
					state_hs <= {state_hs[3:2], calculate}; 
				end
				else begin // waiting for data
				//set output to zero: 		    
					vld0 <= 1'b0; 
					High_out <= ZERO;
				end
			
			{1'b0, state_hs[3:2], calculate}:
				if(en_out==1'b0) 
				begin // show result.
					vld0 <= 1'b1;
					vld1 <= 1'b0; 
					state_hs <= {state_hs[3:2], idle};
				end
				else // continue calculating.
					High_out <= H_bus;			// compare current PE's high score with the left neighbour's 
					
			// --- states for toggle = 1: ---
			{1'b1, idle, state_hs[1:0]}:
				if(en_out==1'b1)
				begin // start calculating
					High_out <= H_bus;			// compare current PE's high score with the left neighbour's !X!
					vld1 <= 1'b0;	
					state_hs <= {calculate, state_hs[1:0]}; 
				end
				else begin // waiting for data
				//set output to zero: 		    
					vld1 <= 1'b0; 
					High_out <= ZERO;
				end
			
			{1'b1, calculate, state_hs[1:0]}:
				if(en_out==1'b0) 
				begin // show result.
					vld0 <= 1'b0;
					vld1 <= 1'b1;
					state_hs <= {idle, state_hs[1:0]};
				end
				else // continue calculating.
					High_out <= H_bus;			// compare current PE's high score with the left neighbour's 
			
			default: begin
						//$display("here1");
					 state_hs <= {idle, idle};
					end
			endcase
		end
	end
// ==== END of High Score stage logic. ====
// ========================================	
						
						
endmodule 
