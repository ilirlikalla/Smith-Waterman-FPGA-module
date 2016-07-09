


/* NOTES:
	- this version of the processing element, has the combinational logic gated by the enable and reset signals (en_in & rst)
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/

`define MAX(x,y)  ((x > y)? x :y)

module SW_ProcessingElement
   #( parameter
		SCORE_WIDTH = 12,	// result width in bits
		_A = 2'b00,        	//nucleotide "A"
		_G = 2'b01,        	//nucleotide "G"
		_T = 2'b10,        	//nucleotide "T"
		_C = 2'b11,        	//nucleotide "C"
		ZERO  = (2**(SCORE_WIDTH-1)) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	)(
// inputs:
		clk,
		rst, 				// active low 
		en_in,
		first,
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
input wire en_in;	//enable input
input wire first;	// flag that indicates if the processing cell is the first element of the systolic array
input wire [1:0] data_in;		// target base input		  		
input wire [1:0] query;			// query base input
input wire [SCORE_WIDTH-1:0] M_in;	// "M": Match score matrix from left neighbour 
input wire [SCORE_WIDTH-1:0] I_in;	// "I": In-del score matrix from left neighbour
input wire [SCORE_WIDTH-1:0] High_in; 	// highest score from left neighbour
// ---- LUT inputs: -------
input wire [SCORE_WIDTH-1:0] match;		// match penalty from LUT
input wire [SCORE_WIDTH-1:0] mismatch;	// mismatch penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_open; // gap open penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_extend;// gap extend penalty from LUT
// ---- LUT inputs END.----

/* -------- Outputs: ---------*/
output reg [1:0] data_out;	// target base out to next cell
output reg [SCORE_WIDTH-1:0] M_out;	// match score out to right neighbour
output reg [SCORE_WIDTH-1:0] I_out;	// in-del score out to right neighbour
output reg [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
output reg en_out;	// enable signal for the right neighbour
output reg vld;		// valid flag, is set when sequence score has been calculated


// state definition in one-hot encoding:
localparam WAIT=3'b10, CALCULATE=3'b01; //, RESULT=3'b001; 
reg [1:0] state;        // state register


/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag;	// score of the respective diagonal element in "M"
reg [SCORE_WIDTH-1:0] I_diag;		// score of the respective diagonal element in "I"

// "wires" (used only in combinational logic):
reg [SCORE_WIDTH-1:0] LUT;
reg [SCORE_WIDTH-1:0] M_score; 		// keeps the "M" matrix score before comparison with ZERO
reg [SCORE_WIDTH-1:0] M_bus; 			// the bus keeps the final "M" matrix score
reg [SCORE_WIDTH-1:0] diag_max; 		// max diagonal between the "I" & "M" diagonals score
reg [SCORE_WIDTH-1:0] I_max; 			// max between "I" left and up elements score
reg [SCORE_WIDTH-1:0] M_max; 			// max between "M" left and up elements score
reg [SCORE_WIDTH-1:0] M_open; 		// penalty for starting a new gap sequence
reg [SCORE_WIDTH-1:0] I_extend; 		// penalty for extending an existing gap sequence
reg [SCORE_WIDTH-1:0] I_bus; 			// the bus keeps the final "I" matrix score
reg [SCORE_WIDTH-1:0] I_M_max; 		// max betwwen "I" & "M" scores


/* ----- END of internal signals. ----- */
						

/* ----------- Combinational part of score calculation:  ----------- */

always@*
begin: COMB_CALC
	
	LUT = 0; 
	diag_max = 0;
	M_score = 0;
	M_bus = 0;
	I_max = 0;
	M_max = 0;
	M_open = 0;
	I_extend = 0;
	I_bus = 0;
	I_M_max = 0;
	
	if(en_in==1'b1 & rst==1'b1)
	begin
		// "M" matrix logic:
		LUT = (data_in == query)? match : mismatch; //  the proper match penalty
		diag_max = `MAX(M_diag, I_diag); // (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
		M_score = LUT + diag_max;
		M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!
		//  M_bus = (M_score > ZERO)? M_score :`ZERO;

		// "I" matrix logic:
		I_max = `MAX(I_in, I_out); //(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
		M_max = `MAX(M_in, M_out); //(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
		M_open = M_max + gap_open+ gap_extend; // penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
		I_extend = I_max + gap_extend; // penalty to extend gap in current alignment			
		I_bus = `MAX(M_open, I_extend); //(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
		
		// Highest score logic:
		I_M_max = `MAX(I_bus, M_bus); // max between "I" and "M" matrices
	end
end
/* ------------------ END of Combinational part. ------------------  */
						
									
/*  Under construction !!!	
 Sequential part of the state machine: */
always@(posedge clk) 
begin: SEQ_STATE
	if(rst==1'b0)
	begin
		state<= WAIT;
		/* set regs to initial state!!!*/
		vld <= 1'b0;
		en_out <= 1'b0;
		M_out <= ZERO;
		I_out <= ZERO;
		High_out <= ZERO;
		M_diag <= ZERO;
		I_diag <= ZERO ;//+ gap_extend;			//  !X!  ->  gap_extend???
	end
	else begin
		case(state)
			WAIT:	// initial/waiting state (reset state)
				if(en_in==1'b1)
				begin // start calculating
					// do 1st iteration calculation here:					!X!
					M_out <= M_bus; // connect score bus to output reg 
					I_out <= I_bus; 	 // connect score bus to output reg 
					High_out <= `MAX(High_in, I_M_max);	// compare current PE's high score with the left neighbour's 
					M_diag <= M_in;   // score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= data_in;
					en_out <= 1'b1;
					vld <= 1'b0;
					/* incomplete! */	
					state <= CALCULATE;
				end
				else begin // waiting for data
				//set output to zero: 
					vld <= 1'b0;				    
					M_out <= ZERO;
					I_out <= ZERO;
					High_out <= ZERO;
					en_out <= 1'b0;
					M_diag <= ZERO;
					I_diag <= ZERO ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= 2'b00;
					/* incomplete! */
				end
				
			CALCULATE: // calculation happens in this state
				if(en_in==1'b0) 
				begin // show result.
					vld <= 1'b1;
					en_out <= 1'b0;
					state <= WAIT;
				end
				else begin // continue calculating.
				/* incomplete! */
					M_out <= M_bus; // connect score bus to output reg 
					I_out <= I_bus; 	 // connect score bus to output reg 
					High_out <= `MAX(High_in, I_M_max);	// compare current PE's high score with the left neighbour's 
					M_diag <= M_in;	 // score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in ;//+ gap_extend;		//  !X!  ->  gap_extend???
					data_out <= data_in;
				end
				
			// RESULT:		// result is asserted in this state     !X! this state might be redundant
			// begin
				// vld <= 1'b1;
				// en_out <= 1'b0;
				// state <= WAIT;
			// end
				/* incomplete! */
			default: state <= WAIT;  // in case of failure go to the "safe" state (reset)
		endcase
	end
end


endmodule 
