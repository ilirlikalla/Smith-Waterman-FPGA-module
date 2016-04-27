


/* NOTE: possible faults are associated by the comment "!X!"
*/

`define MAX(x,y)  ((x > y)? x :y)

module SW_ProcessingElement(
// inputs:
		clk,
		rst, 				// active low 
		en_in,
		first,
		data_in
		query,
		M_in,
		I_in,
		High_in,
		match,			// LUT
		mismatch,	// LUT
		gap_open,	// LUT
		gap_extend, // LUT
// outputs:				
		M_out,
		I_out,
		High_out,
		en_out,
		vld
		);
parameter
    SCORE_WIDTH = 12,	// 
    //LENGTH=128,			// number of processing elements in the systolic array
	//LOGLENGTH = 8,		// element addressing width
	_A = 2'b00,        	//nucleotide "A"
    _G = 2'b01,        	//nucleotide "G"
    _T = 2'b10,        	//nucleotide "T"
    _C = 2'b11,        	//nucleotide "C"
	ZERO  = $realtobits(2**SCORE_WIDTH);	// value of the biased zero, bias= 2 ^ SCORE_WIDTH			
	
	 
/* ------- Inputs: -----------*/
input wire clk;
input wire rst;
input wire en_in:	//enable input
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
output reg [SCORE_WIDTH-1] M_out;	// match score out to right neighbour
output reg [SCORE_WIDTH-1] I_out;	// in-del score out to right neighbour
output reg [SCORE_WIDTH-1] High_out;	// highest score out to right neighbour
output reg en_out;	// enable signal for the right neighbour
output reg vld;		// valid flag, is set when sequence score has been calculated


		/*
		output reg  o_rst;
		output reg [SCORE_WIDTH-1:0] o_right_m;            //output of score from t-1 for M matrix
		output reg [SCORE_WIDTH-1:0] o_right_i;				//output of score for t-1 for I matrix
		output reg [SCORE_WIDTH-1:0] o_high;		//output of currently highest score
		output reg  o_en;                              //tells neighbor data is valid
		output reg [1:0] o_data; */

// state definition in one-hot encoding:
localparam WAIT=3'b100, CALCULATE=3'b010, RESULT=3'b001; 
reg [2:0] state;        // state register


/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag;	// score of the respective diagonal element in "M"
reg [SCORE_WIDTH-1:0] I_diag;		// score of the respective diagonal element in "I"

// wires:
wire [SCORE_WIDTH-1:0] LUT;
wire [SCORE_WIDTH-1:0] M_score; 		// keeps the "M" matrix score before comparison with ZERO
wire [SCORE_WIDTH-1:0] M_bus; 			// the bus keeps the final "M" matrix score
/* ----- END of internal signals. ----- */
						

/* ----------- Sequential part of score calculation:  ----------- */
 //  - enable control should be added!!! more area???

// "M" matrix logic:
assign	LUT = (data_in == query)? match : mismatch; // assign the proper match penalty
assign	diag_max = `MAX(M_diag, I_diag); // (M_diag > I_diag)? M_diag : I_diag; // find max between the two matrices diagonals
assign	M_score = LUT + diag_max;
assign	M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  // check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score
	// assign M_bus = (M_score > ZERO)? M_score :`ZERO;
	
// "I" matrix logic:
assign	I_max = `MAX(I_in, I_out); //(I_in > I_out)? I_in : I_out; // calculate max between left and up neighbour in "I"
assign M_max = `MAX(M_in, M_out); //(M_in > M_out)? M_in : M_out; // calculate max between left and up neighbour in "M"
assign M_open = M_max + gap_open; // penalty to open gap in current alignment            !X!  ->  + gap_extend???
assign I_extend = I_max + gap_extend; // penalty to extend gap in current alignment			
assign I_bus = `MAX(M_open, I_extend); //(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score

// Highest score logic:
assign I_M_max = `MAX(I_bus, M_bus); // max between "I" and "M" matrices

/* ------------------ END of Sequential part. ------------------  */
						
									
/*  Under construction !!!	
 Sequential part of the state machine: */
always@(posedge clk) 
begin: SEQ_STATE
	if(rst==1'b0)
		state<= WAIT;
		/* set regs to initial state!!!*/
		vld <= 1'b0;
		en_out <= 1'b0;
		M_out <= ZERO;
		I_out <= ZERO;
		High_out <= ZERO;
		M_diag <= ZERO;
		I_diag <= ZERO;			//  !X!  ->  gap_extend???
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
					I_diag <= I_in;		//  !X!  ->  gap_extend???
					en_out <= 1'b1;
					/* incomplete! */	
					state <= CALCULATE;
				end
				else begin // waiting for data
				//set output to zero: 
					// vld <= 1'b0;
					// en_out <= 1'b0;
					M_out <= ZERO;
					I_out <= ZERO;
					High_out <= ZERO;
					M_diag <= ZERO;
					I_diag <= ZERO;		//  !X!  ->  gap_extend???
					/* incomplete! */
				end
				
			CALCULATE: // calculation happens in this state
				if(en_in==1'b0) 
				begin // show result.
					vld <= 1'b1;
					state <= RESULT;
				end
				else begin // continue calculating.
				/* incomplete! */
					M_out <= M_bus; // connect score bus to output reg 
					I_out <= I_bus; 	 // connect score bus to output reg 
					High_out <= `MAX(High_in, I_M_max);	// compare current PE's high score with the left neighbour's 
					M_diag <= M_in;	 // score from left neighbour serves as diagonal score in the next cycle
					I_diag <= I_in;		//  !X!  ->  gap_extend???
				end
				
			RESULT:		// result is asserted in this state
				vld <= 1'b1;
				en_out <= 1'b0;
				state <= WAIT;
				/* incomplete! */
			default: state <= WAIT;  // in case of failure go to the "safe" state (reset)
		endcase;
	end
end

	

endmodule 
