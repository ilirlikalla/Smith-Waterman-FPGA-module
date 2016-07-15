


/* NOTES:
	- this version of the processing element has the state machine implemented in a "register gated" way,
	where the state register bits control explictly the outputs of the module. The result was a slower than
    expected synthesised design, but hardware efficient.
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/

`define MAX(x,y)  ((x > y)? x :y)

module SW_ProcessingElement_v_0_4
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
output wire [1:0] data_out;				// target base out to next cell
output wire [SCORE_WIDTH-1:0] M_out;		// match score out to right neighbour
output wire [SCORE_WIDTH-1:0] I_out;		// in-del score out to right neighbour
output wire [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
output wire en_out;						// enable signal for the right neighbour
output wire vld;							// valid flag, is set when sequence score has been calculated

// --- state signals: ---
// matrix score stage:
reg [1:0] state_sc;        // state register
wire sc_idle;
wire sc_calculate; 

// high score stage:
reg [1:0] state_hs;        // state register
wire hs_idle;
wire hs_calculate; 

/* -------- Internal signals: --------- */
// registers:
reg [SCORE_WIDTH-1:0] M_diag;		// score of the respective diagonal element in "M"
reg [SCORE_WIDTH-1:0] I_diag;		// score of the respective diagonal element in "I"

// latched signals:
reg [1:0] data_out_r;				
reg [SCORE_WIDTH-1:0] M_out_r;	
reg [SCORE_WIDTH-1:0] I_out_r;	
reg [SCORE_WIDTH-1:0] High_out_r;	
reg en_out_r;						
reg vld_r;						


// "wires" (used only in combinational logic):
wire  [SCORE_WIDTH-1:0] LUT;
wire  [SCORE_WIDTH-1:0] M_score; 	// keeps the "M" matrix score before comparison with ZERO
wire  [SCORE_WIDTH-1:0] M_bus; 		// the bus keeps the final "M" matrix score
wire  [SCORE_WIDTH-1:0] diag_max; 	// max diagonal between the "I" & "M" diagonals score
wire  [SCORE_WIDTH-1:0] I_max; 		// max between "I" left and up elements score
wire  [SCORE_WIDTH-1:0] M_max; 		// max between "M" left and up elements score
wire  [SCORE_WIDTH-1:0] M_open; 	// penalty for starting a new gap sequence
wire  [SCORE_WIDTH-1:0] I_extend; 	// penalty for extending an existing gap sequence
wire  [SCORE_WIDTH-1:0] I_bus; 		// the bus keeps the final "I" matrix score
wire  [SCORE_WIDTH-1:0] I_M_max; 	// max betwwen "I" & "M" scores
wire  [SCORE_WIDTH-1:0] H_max; 		// max betwwen "I_M_max" & "High_out" 
wire  [SCORE_WIDTH-1:0] H_bus; 		// the bus keeps the final high score

/* ----- END of internal signals. ----- */


// ========================================					
// ========= Score stage logic: ===========
	
	// ---- Combinational part: ----

    assign LUT = (data_in == query)? match : mismatch;						//  the proper match penalty
		
	// "M" matrix logic:
	assign diag_max = `MAX(M_diag, I_diag); 								// find max between the two matrices diagonals
	assign M_score = ((sc_calculate)? diag_max : ZERO) + LUT; 
	assign M_bus = (M_score[SCORE_WIDTH-1] == 1'b1)? M_score :ZERO;  		// check if "M" matrix element is larger or equal to ZERO. This bus holds "M" score. !!! SKIP THIS STEP FOR GLOBAL ALIGNMENT !!!
	
	// "I" matrix logic:
	assign I_max = `MAX(I_in, I_out_r); 									//(I_in > I_out_r)? I_in : I_out_r; // calculate max between left and up neighbour in "I"
	assign M_max = `MAX(M_in, M_out_r); 									//(M_in > M_out_r)? M_in : M_out_r; // calculate max between left and up neighbour in "M"
	assign M_open = ((sc_calculate)? M_max : ZERO) + gap_open + gap_extend; // penalty to open gap in current alignment            !X!  ->  + gap_extend??? (this corrects some results in data1.fa)
	assign I_extend = ((sc_calculate)? I_max : ZERO) + gap_extend ; 		// penalty to extend gap in current alignment			
	assign I_bus = `MAX(M_open, I_extend); 									//(M_open > I_extend)? M_open : I_extend; // this bus holds "I" score
	
	// connect outputs to their respective "latches"
	assign data_out = data_out_r;
	assign en_out = en_out_r;
	assign M_out = M_out_r;
	assign I_out = I_out_r;
	
	// ---- sequential part: ----
	
	// buffer en_out_r:
	always@(posedge clk)
	if(~rst)
		en_out_r <= 1'b0;
	else 
		en_out_r <= en_in;
		
	// buffer data:
	always@(posedge clk)
	if(~rst)
		data_out_r <= 2'b00;
	else 
		data_out_r <= data_in;	
		
	// set M_diag:
	always@(posedge clk)
	if(~rst || ~en_in) // !X!
		M_diag <= ZERO;
	else if((sc_idle || sc_calculate) && en_in)
		M_diag <= M_in;
		
	// set I_diag:
	always@(posedge clk)
	if(~rst || ~en_in) // !X!
		I_diag <= ZERO;
	else if((sc_idle || sc_calculate) && en_in)
		I_diag <= I_in;
		
	// set M_out_r:
	always@(posedge clk)
	if(!rst || (sc_idle  && ~en_in))
		M_out_r <= ZERO;
	else if((sc_idle || sc_calculate) && en_in)
		M_out_r <= M_bus;
 
	
	// set I_out_r:
	always@(posedge clk)
	if(~rst || (sc_idle  && ~en_in))
		I_out_r <= ZERO;
	else if((sc_idle || sc_calculate) && en_in)
		I_out_r <= I_bus;
 	
	// Matrix score state machine 
	assign sc_idle = state_sc[1];
	assign sc_calculate = state_sc[0];
	
	always@(posedge clk)	// !X!
	if(~rst || (sc_calculate && ~en_in)) 
		state_sc <= 2'b10; 	// go to idle state
	else if(sc_idle && en_in)	
		state_sc <= 2'b01; 	// go to calculate state
		
	
// ====== END of Score stage logic. =======
// ========================================					


// ========================================					
// ======= High Score stage logic: ========
	
	// ---- Combinational part: ----

	assign I_M_max = `MAX(M_out_r, I_out_r); 	// max between "I" and "M" matrices
	assign H_max = `MAX(High_in, I_M_max);		
	assign H_bus = `MAX(H_max, High_out_r);
	
	// connect outputs to their respective "latches"
	assign vld = vld_r;
	assign High_out = High_out_r;
	
	// ---- sequential part: ----
	
	// set valid signal:
	always@(posedge clk)
	if(hs_calculate && ~en_out_r)
		vld_r <= 1'b1;
	else // every other case clear valid
	    vld_r <= 1'b0;
		
    // set High_out_r:
	always@(posedge clk)
	if(~rst || (hs_idle  && ~en_out_r))
		High_out_r <= ZERO;
	else if(hs_idle  && en_out_r)
		High_out_r <= H_max;
	else if(hs_calculate && en_out_r)
		High_out_r <= H_bus;
	
	// High score state machine:
	assign hs_idle = state_hs[1];
	assign hs_calculate = state_hs[0];
	
	always@(posedge clk)	// !X!
	if(~rst || (hs_calculate && ~en_out_r))
		state_hs <= 2'b10;
	else if(hs_idle && en_out_r)
		state_hs <= 2'b01;

// ==== END of High Score stage logic. ====
// ========================================	
						
						
endmodule 
