// Author: Ilir Likalla


/* NOTES:
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


module ScoringModule_v1
   #( parameter
		SCORE_WIDTH = 12,	// result width in bits
		LENGTH=128,			// number of processing elements in the systolic array
		LOG_LENGTH = log2b(LENGTH),		// element addressing width
		_A = 2'b10,        	//nucleotide "A"
		_G = 2'b11,        	//nucleotide "G"
		_T = 2'b00,        	//nucleotide "T"
		_C = 2'b01,			//nucleotide "C"
		ZERO = (2**(SCORE_WIDTH-1)) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	)(
// inputs:
		clk,
		rst, 				// active low 
		en0,
		en1,
		data_in,
		query,
		// M_in,
		// I_in,
		// High_in,
		match,				// penalties
		mismatch,			// penalties
		gap_open,			// penalties
		gap_extend, 		// penalties
		output_select,		// select lines for output multiplexer
// outputs:
	    // data_out,
		// M_out,
		// I_out,
		// High_out,
		result, 			// Smith-waterman result
		//en_out,
		vld0,
		vld1,
		toggle
		);

function integer log2b ; 					// calculates base 2 logarithm of  of 'length'
	input integer i;
	begin 
		
		for(log2b=0; i>0; log2b=log2b+1) 
			i = i >>1; 
	end 
endfunction 		

/* ------- Inputs: -----------*/
input wire clk;
input wire rst;
input wire en0;								//enable input
input wire en1;								//enable input
input wire [1:0] data_in;					// target base input		  		
input wire [(2*LENGTH)-1:0] query;			// query base input
input wire [LOG_LENGTH-1:0] output_select;
// *** for future use: ***
// input wire [SCORE_WIDTH-1:0] M_in;		// "M": Match score matrix from left neighbour 
// input wire [SCORE_WIDTH-1:0] I_in;		// "I": In-del score matrix from left neighbour
// input wire [SCORE_WIDTH-1:0] High_in; 	// highest score from left neighbour

// ---- penalties inputs: -------
input wire [SCORE_WIDTH-1:0] match;			// match penalty from penalties
input wire [SCORE_WIDTH-1:0] mismatch;		// mismatch penalty from penalties
input wire [SCORE_WIDTH-1:0] gap_open; 		// gap open penalty from penalties
input wire [SCORE_WIDTH-1:0] gap_extend;	// gap extend penalty from penalties
// ---- penalties inputs END.----

/* -------- Outputs: ---------*/
// *** for future use: ***
// output reg [1:0] data_out;				// target base out to next cell
// output reg [SCORE_WIDTH-1:0] M_out;		// match score out to right neighbour
// output reg [SCORE_WIDTH-1:0] I_out;		// in-del score out to right neighbour
// output reg [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
// output reg en_out;						// enable signal for the right neighbour

output reg [SCORE_WIDTH-1:0] result;	
output reg vld0;							// valid flag, is set when sequence score has been calculated
output reg vld1;							// valid flag, is set when sequence score has been calculated
output reg toggle;							// toggle flag, chooses which sequence is to be fed



/* --------- Internal signals: ---------- */
wire [SCORE_WIDTH-1:0] high_ [0:LENGTH-1];	// bus holding all individual high scores of each PE
wire [SCORE_WIDTH-1:0] M_ [0:LENGTH-1]; 	// bus holding all individual "M"scores of each PE
wire [SCORE_WIDTH-1:0] I_ [0:LENGTH-1]; 	// bus holding all individual "I" scores of each PE
wire [LENGTH-1:0] vld0_; 					// bus holding all valid0 signals from each PE
wire [LENGTH-1:0] vld1_; 					// bus holding all valid1 signals from each PE
wire [LENGTH-1:0] en_;						// bus holding all enable signals from each PE
wire [LENGTH-1:0] toggle_;					// bus holding all toggle signals 
wire [1:0] data_ [0:LENGTH-1];				// holds bases that are bassing through the PEs
wire enable;								// enable signal for the systolic array	

// ---- output logic: ----


 // select the corrent output: 		
  always@(posedge clk) 
 	if(!rst)
		{toggle, vld0, vld1, result} <= 0;
	else 
		{toggle, vld0, vld1, result} <= {~toggle, vld0_[output_select-1], vld1_[output_select-1], high_[output_select-1]};
		
 // set enable:
	assign enable = en0 | en1;

// ---- instantiation of the systolic array of processing elements: ----
genvar i;
generate 
	for(i=0; i<LENGTH; i=i+1) begin: GEN_BLOCK
		if(i==0)							// instantiate the first processing element and assign proper initial inputs:
			SW_ProcessingElement_v1  
		   #(
				.SCORE_WIDTH(SCORE_WIDTH),	
				._A(_A),        	
				._G(_G),        
				._T(_T),       
				._C(_C),        	
				.ZERO(ZERO)
			) PE0(
		// inputs:
				.clk(clk),
				.rst(rst), 					// active low 
				.toggle_in(toggle),
				.en_in(enable),
				.data_in(data_in),
				.query(query[1:0]),
				.M_in(ZERO),
				.I_in(ZERO),				//  gap_open???   !X!
				.High_in(ZERO),
				.match(match),				// penalties
				.mismatch(mismatch),		// penalties
				.gap_open(gap_open),		// penalties
				.gap_extend(gap_extend), 	// penalties
		// outputs:
				.data_out(data_[i]),
				.M_out(M_[i]),
				.I_out(I_[i]),
				.High_out(high_[i]),
				.en_out(en_[i]),
				.toggle_out(toggle_[i]),
				.vld0(vld0_[i]),
				.vld1(vld1_[i])
				);
		else 								// instantiate the rest of processing elements:
			SW_ProcessingElement_v1  
		   #(
				.SCORE_WIDTH(SCORE_WIDTH),	
				._A(_A),        	
				._G(_G),        
				._T(_T),       
				._C(_C),        	
				.ZERO(ZERO)
			) PE(
		// inputs:
				.clk(clk),
				.rst(rst), 					// active low 
				.toggle_in(toggle_[i-1]),
				.en_in(en_[i-1]),
				.data_in(data_[i-1]),
				.query(query[2*i+1:2*i]),
				.M_in(M_[i-1]),
				.I_in(I_[i-1]),		
				.High_in(high_[i-1]),
				.match(match),				// penalties
				.mismatch(mismatch),		// penalties
				.gap_open(gap_open),		// penalties
				.gap_extend(gap_extend), 	// penalties
		// outputs:
				.data_out(data_[i]),
				.M_out(M_[i]),
				.I_out(I_[i]),
				.High_out(high_[i]),
				.en_out(en_[i]),
				.toggle_out(toggle_[i]),
				.vld0(vld0_[i]),
				.vld1(vld1_[i])
				);
	end
endgenerate

endmodule












