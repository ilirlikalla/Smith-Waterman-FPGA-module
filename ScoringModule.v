


/* NOTES:
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


module ScoringModule
   #( parameter
		SCORE_WIDTH = 12,	// 
		LENGTH=128,			// number of processing elements in the systolic array
		LOG_LENGTH = log2b(LENGTH),		// element addressing width
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
		// first,
		data_in,
		query,
		// M_in,
		// I_in,
		// High_in,
		match,			// LUT
		mismatch,	// LUT
		gap_open,	// LUT
		gap_extend, // LUT
		counter_in,	// base counter input
// outputs:
	    // data_out,
		// M_out,
		// I_out,
		// High_out,
		result, 	// Smith-waterman result
		//en_out,
		vld
		);

function integer log2b ; // calculates base 2 logarithm of  of 'length'
	input integer i;
	begin 
		
		for(log2b=0; i>0; log2b=log2b+1) 
			i = i >>1; 
	end 
endfunction 		

/* ------- Inputs: -----------*/
input wire clk;
input wire rst;
input wire en_in;	//enable input
// input wire first;	// flag that indicates if the processing cell is the first element of the systolic array
input wire [1:0] data_in;		// target base input		  		
input wire [(2*LENGTH)-1:0] query;			// query base input
input wire [LOG_LENGTH-1:0] counter_in;
//
// input wire [SCORE_WIDTH-1:0] M_in;	// "M": Match score matrix from left neighbour 
// input wire [SCORE_WIDTH-1:0] I_in;	// "I": In-del score matrix from left neighbour
// input wire [SCORE_WIDTH-1:0] High_in; 	// highest score from left neighbour

// ---- LUT inputs: -------
input wire [SCORE_WIDTH-1:0] match;		// match penalty from LUT
input wire [SCORE_WIDTH-1:0] mismatch;	// mismatch penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_open; // gap open penalty from LUT
input wire [SCORE_WIDTH-1:0] gap_extend;// gap extend penalty from LUT
// ---- LUT inputs END.----

/* -------- Outputs: ---------*/
//
// output reg [1:0] data_out;	// target base out to next cell
// output reg [SCORE_WIDTH-1:0] M_out;	// match score out to right neighbour
// output reg [SCORE_WIDTH-1:0] I_out;	// in-del score out to right neighbour
// output reg [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
// output reg en_out;	// enable signal for the right neighbour

output wire [SCORE_WIDTH-1:0] result;	
output wire vld;		// valid flag, is set when sequence score has been calculated



/* --------- Internal signals: ---------- */
wire [SCORE_WIDTH-1:0] high_ [0:LENGTH-1]; // bus holding all individual high scores of each PE
wire [SCORE_WIDTH-1:0] M_ [0:LENGTH-1]; // bus holding all individual "M"scores of each PE
wire [SCORE_WIDTH-1:0] I_ [0:LENGTH-1]; // bus holding all individual "I" scores of each PE
wire [LENGTH-1:0] vld_; // bus holding all valid signals from each PE
wire [LENGTH-1:0] en_;
wire [1:0] data_ [0:LENGTH-1];


// output mux logic:
assign {vld,result} = (vld_[counter_in]==1'b1)? {vld_[counter_in],high_[counter_in]} : {1'b0, ZERO}; //  insert enable??? !X!  ( counter -1) ???

// instantiation of the systolic array of processing elements:
genvar i;
generate 
	for(i=0; i<LENGTH; i=i+1)
		if(i==0)	// instantiate the first processing element and assign proper initial inputs:
			SW_ProcessingElement    
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
				.rst(rst), 				// active low 
				.en_in(en_in),
				.first(1'b1),	// not used!!! (28.04.16)
				.data_in(data_in),
				.query(query[1:0]),
				.M_in(ZERO),
				.I_in(ZERO),		//  gap_open???   !X!
				.High_in(ZERO),
				.match(match),			// LUT
				.mismatch(mismatch),	// LUT
				.gap_open(gap_open),	// LUT
				.gap_extend(gap_extend), // LUT
		// outputs:
				.data_out(data_[i]),
				.M_out(M_[i]),
				.I_out(I_[i]),
				.High_out(high_[i]),
				.en_out(en_[i]),
				.vld(vld_[i])
				);
		else // instantiate the rest of processing elements:
			SW_ProcessingElement    
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
				.rst(rst), 				// active low 
				.en_in(en_[i-1]),
				.first(1'b0),	// not used!!! (28.04.16)
				.data_in(data_[i-1]),
				.query(query[2*i+1:2*i]),
				.M_in(M_[i-1]),
				.I_in(I_[i-1]),		
				.High_in(high_[i-1]),
				.match(match),			// LUT
				.mismatch(mismatch),	// LUT
				.gap_open(gap_open),	// LUT
				.gap_extend(gap_extend), // LUT
		// outputs:
				.data_out(data_[i]),
				.M_out(M_[i]),
				.I_out(I_[i]),
				.High_out(high_[i]),
				.en_out(en_[i]),
				.vld(vld_[i])
				);
endgenerate

endmodule












