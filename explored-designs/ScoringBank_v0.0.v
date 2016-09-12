


/* NOTES:
	- coded based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


module ScoringBank
   #( parameter
		SCORE_WIDTH = 12,	// result width in bits
		LENGTH=128,			// number of processing elements in the systolic array
		NR_MODULES= 4,				// number of scoring modules
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
// input wire [(2*LENGTH)-1:0] query;			// query input
input wire [LOG_LENGTH-1:0] counter_in;
//


/* -------- Outputs: ---------*/
//
output wire [SCORE_WIDTH-1:0] result;	
output wire vld;		// valid flag, is set when sequence score has been calculated



/* --------- Internal signals: ---------- */

wire [NR_MODULES-1:0] vld_; // valid signals from each scoring module
wire [NR_MODULES-1:0] en_; // enable signal for scoring modules
wire [1:0] data_ [0:LENGTH-1];
// registers:
reg [(2*LENGTH)-1:0] query;		// query register
reg [LENGTH-1:0] query_length;	// holds the length of the query
reg  [1:0] target_base [NR_MODULES-1:0]; // holds bases that should be streamed in at the respective scoring modules
// penalty registers (LUT signals):
reg [SCORE_WIDTH-1:0] match;			// match penalty
reg [SCORE_WIDTH-1:0] mismatch;	// mismatch penalty 
reg [SCORE_WIDTH-1:0] gap_open;	// gap open penalty
reg [SCORE_WIDTH-1:0] gap_extend;	// gap extend penalty 


/* -------- Component instantiations: -----------*/
genvar i;
generate

ScoringModule
   #(
		.SCORE_WIDTH(SCORE_WIDTH),	// 
		.LENGTH(LENGTH),			// number of processing elements in the systolic array
		.LOG_LENGTH(),		// element addressing width
		._A(),        	//nucleotide "A"
		._G(),        	//nucleotide "G"
		._T(),        	//nucleotide "T"
		._C(),        	//nucleotide "C"
		.ZERO(ZERO) // $realtobits(2**SCORE_WIDTH) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	) M(
// inputs:
		.clk(clk),
		.rst(rst), 				// active low 
		.en_in(en_[i]),
		// first,
		.data_in(base[i]),
		.query(query),
		// M_in,
		// I_in,
		// High_in,
		.match(match),			// LUT
		.mismatch(mismatch),	// LUT
		.gap_open(gap_open),	// LUT
		.gap_extend(gap_extend), // LUT
		.counter_in(base_counter),	// base counter input
// outputs:
	    // data_out,
		// M_out,
		// I_out,
		// High_out,
		.result(result), 	// Smith-waterman result
		//en_out,
		.vld(valid)
		);

/* -------- END of Component instantiations. --------*/







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












