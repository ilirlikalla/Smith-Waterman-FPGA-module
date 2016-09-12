// Author: Ilir Likalla


/* NOTES:
	- In this version of the module there are penalty registers every 8 processing elements (this can be changed)
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
	- parameters belonging to the encoded nuclotides are not used.(for future use)
*/

// parameter related macros:
`define PREG_NUM (LENGTH/PREG_FREQ)	// number of penalty register groups
`define set_reg(x) (x/PREG_FREQ)	// sets appropriate penalty register for each processing element
module ScoringModule_v1_1
   #( parameter
		SCORE_WIDTH = 12,			// result's width in bits
		LENGTH=128,					// number of processing elements in the systolic array
		ADDR_WIDTH = log2b(LENGTH)+1,	// element addressing width
		PREG_FREQ = 8,				// frequency of Penalty registers is set to default as 1 register for every 8 PEs
		_A = 2'b10,        			// nucleotide "A"
		_G = 2'b11,        			// nucleotide "G"
		_T = 2'b00,        			// nucleotide "T"
		_C = 2'b01,					// nucleotide "C"
		ZERO = (2**(SCORE_WIDTH-1)) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	)(
	// ---- Inputs: ----
	input wire clk,
	input wire rst,
	input wire en0,								//enable input
	input wire en1,								//enable input
	input wire ld_p,							// load penalties input
	input wire ld_q,							// load query input
	input wire [1:0] data_in,					// target base input		  		
	input wire [(2*LENGTH)-1:0] query,			// query base input
	input wire [ADDR_WIDTH-1:0] output_select,
	// *** for future use: ***
	// input wire [SCORE_WIDTH-1:0] M_in;		// "M": Match score matrix from left neighbour 
	// input wire [SCORE_WIDTH-1:0] I_in;		// "I": In-del score matrix from left neighbour
	// input wire [SCORE_WIDTH-1:0] High_in; 	// highest score from left neighbour

	// --- penalties inputs: ---
	input wire [SCORE_WIDTH-1:0] match,			// match penalty from penalties
	input wire [SCORE_WIDTH-1:0] mismatch,		// mismatch penalty from penalties
	input wire [SCORE_WIDTH-1:0] gap_open, 		// gap open penalty from penalties
	input wire [SCORE_WIDTH-1:0] gap_extend,	// gap extend penalty from penalties
	// -- penalties inputs END.--

	// ---- Outputs: ----
	// *** for future use: ***
	// output reg [1:0] data_out;				// target base out to next module
	// output reg [SCORE_WIDTH-1:0] M_out;		// match score out to right neighbour
	// output reg [SCORE_WIDTH-1:0] I_out;		// in-del score out to right neighbour
	// output reg [SCORE_WIDTH-1:0] High_out;	// highest score out to right neighbour
	// output reg en_out;						// enable signal for the right neighbour

	output reg [SCORE_WIDTH-1:0] result0,	
	output reg [SCORE_WIDTH-1:0] result1,	
	output reg vld0,							// valid flag, is set when sequence score has been calculated
	output reg vld1,							// valid flag, is set when sequence score has been calculated
	output reg toggle,							// toggle flag, chooses which sequence is to be fed
	output ready								// is set when penalties are loaded for the first few processing elements
	);

function integer log2b ; 						// calculates base 2 logarithm of  of 'length'
	input integer i;
	begin 
		
		for(log2b=0; i>0; log2b=log2b+1) 
			i = i >>1; 
	end 
endfunction 		




/* --------- Internal signals: ---------- */
wire [SCORE_WIDTH-1:0] high0_ [0:LENGTH-1];	// bus holding all individual high0 scores of each PE
wire [SCORE_WIDTH-1:0] high1_ [0:LENGTH-1];	// bus holding all individual high1 scores of each PE
wire [SCORE_WIDTH-1:0] M_ [0:LENGTH-1]; 	// bus holding all individual "M"scores of each PE
wire [SCORE_WIDTH-1:0] I_ [0:LENGTH-1]; 	// bus holding all individual "I" scores of each PE
wire [LENGTH-1:0] vld0_; 					// bus holding all valid0 signals from each PE
wire [LENGTH-1:0] vld1_; 					// bus holding all valid1 signals from each PE
wire [LENGTH-1:0] en0_;						// bus holding all enable0 signals from each PE
wire [LENGTH-1:0] en1_;						// bus holding all enable1 signals from each PE
wire [LENGTH-1:0] toggle_;					// bus holding all toggle signals 
wire [1:0] data_ [0:LENGTH-1];				// holds bases that are passing through the PEs

// penalty register groups:
reg [`PREG_NUM-1:0] p_valid;				// valid signals for penalty registers
reg [SCORE_WIDTH-1:0] match_r [0:`PREG_NUM-1];
reg [SCORE_WIDTH-1:0] mismatch_r [0:`PREG_NUM-1];
reg [SCORE_WIDTH-1:0] gap_open_r [0:`PREG_NUM-1];
reg [SCORE_WIDTH-1:0] gap_extend_r [0:`PREG_NUM-1];

// query regiser:
reg [(2*LENGTH)-1:0] query_r;				// query register
reg [ADDR_WIDTH-1:0] q_length;				// query's length
reg q_valid;								// query valid signal
// ---- output logic: ----


 // select the corrent output: 		
	always@(posedge clk) 
	if(!rst)
		{toggle, vld0, vld1, result0, result1} <= 0;
	else 
		{toggle, vld0, vld1, result0, result1} <= {~toggle, vld0_[q_length], vld1_[q_length], high0_[q_length], high1_[q_length]};
	
// penalty setup logic:
	integer p;
	always@(posedge clk)
	begin
		if(~rst)
		begin
			q_valid <= 1'b0;
			p_valid <= 0;
			q_length <= 0;
			// do not reset the "wide" registers, it may slow down the design
		end else
		begin
			if(ld_q)
			begin
				q_valid <= ld_q;
				query_r <= query;
				q_length <= output_select - 1;	// fix length 			
			end

			for(p= 0; p <`PREG_NUM; p= p+1)
				if(p==0)
				begin
					if(ld_p)
					begin
						// load penalies for the first PREG_NUM processing elements:
						p_valid[p] <= ld_p;
						match_r[p] <= match;
						mismatch_r[p] <= mismatch;
						gap_open_r[p] <= gap_open;
						gap_extend_r[p] <= gap_extend;
					end
				end else if(p_valid[p-1])
				begin 
					// propagate penalties:
					p_valid[p] <= p_valid[p-1];
					match_r[p] <= match_r[p-1];
					mismatch_r[p] <= mismatch_r[p-1];
					gap_open_r[p] <= gap_open_r[p-1];
					gap_extend_r[p] <= gap_extend_r[p-1];	
				end
		end
	end		
	
	assign ready = q_valid && p_valid[0];	// if penalties are loaded for at least the first element the module is ready to work

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
			.en0_in(en0),
			.en1_in(en1),
			.data_in(data_in),
			.query(query_r[1:0]),
			.M_in(ZERO),
			.I_in(ZERO),				//  gap_open???   !X!
			.High0_in(ZERO),
			.High1_in(ZERO),
			.match(match_r[`set_reg(i)]),				// penalties
			.mismatch(mismatch_r[`set_reg(i)]),			// penalties
			.gap_open(gap_open_r[`set_reg(i)]),			// penalties
			.gap_extend(gap_extend_r[`set_reg(i)]), 	// penalties
			// outputs:
			.data_out(data_[i]),
			.M_out(M_[i]),
			.I_out(I_[i]),
			.High0_out(high0_[i]),
			.High1_out(high1_[i]),
			.en0_out(en0_[i]),
			.en1_out(en1_[i]),
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
			.en0_in(en0_[i-1]),
			.en1_in(en1_[i-1]),
			.data_in(data_[i-1]),
			.query(query_r[2*i+1:2*i]),
			.M_in(M_[i-1]),
			.I_in(I_[i-1]),		
			.High0_in(high0_[i-1]),
			.High1_in(high1_[i-1]),
			.match(match_r[`set_reg(i)]),				// penalties
			.mismatch(mismatch_r[`set_reg(i)]),			// penalties
			.gap_open(gap_open_r[`set_reg(i)]),			// penalties
			.gap_extend(gap_extend_r[`set_reg(i)]), 	// penalties
			// outputs:
			.data_out(data_[i]),
			.M_out(M_[i]),
			.I_out(I_[i]),
			.High0_out(high0_[i]),
			.High1_out(high1_[i]),
			.en0_out(en0_[i]),
			.en1_out(en1_[i]),
			.toggle_out(toggle_[i]),
			.vld0(vld0_[i]),
			.vld1(vld1_[i])
			);
	end
endgenerate

endmodule












