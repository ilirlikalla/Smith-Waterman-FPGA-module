// Author: Ilir Likalla


/* NOTES:
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
	- parameters belonging to the encoded nuclotides are not used.(for future use)
*/

module ScoreBank_v2
	#( parameter
		SCORE_WIDTH = 12,					// result's width in bits
		ID_WIDTH = 48,						// sequence's ID width in bits
		LEN_WIDTH = 12,						// sequence's length width in bits
		TARGET_LENGTH = 128,				// target sequence's length
		MODULES = 2, 						// number of Scoring Modules
		MODULE_LENGTH = 128,				// number of processing elements per module
		ADDR_WIDTH = $clog2(MODULE_LENGTH)+1,// module's element addressing width
		_A = 2'b10,        					// nucleotide "A"
		_G = 2'b11,        					// nucleotide "G"
		_T = 2'b00,        					// nucleotide "T"
		_C = 2'b01,							// nucleotide "C"
		ZERO = (2**(SCORE_WIDTH-1)), 		// value of the biased zero, bias= 2 ^ SCORE_WIDTH
		IN_WIDTH = (2 + ID_WIDTH		
				+ LEN_WIDTH
				+ (2*TARGET_LENGTH)),		// input's width (data_in)
		FEED_ADDR = $clog2(MODULES)			// scoring module's feeder addresing bits
	)(
	input clk,
	input rst,
	input ld_sequence,								// if set, a new target sequence is loaded in  
	input ld_penalties,								// if set, penalties are loaded	
	input [0:IN_WIDTH-1] data_in,  					// sequence data input
	input [(4*SCORE_WIDTH)-1:0] penalties, 			// penalties input. Four penalties are loaded simultaneously
	output reg ready,								// is set if the module is ready to process data
	output reg full,								// is set if the module's sequence registers are full
	output [0:(2*MODULES*SCORE_WIDTH)-1] results,	// results outputs
	output [0:(2*MODULES*ID_WIDTH)-1] IDs,			// respective ID of each result
	output [0:(2*MODULES)-1] vld,					// respective valid signal for each result
	output [ID_WIDTH+SCORE_WIDTH-1:0] max,			// Bank's maximum score for the current query
	output vld_max									// max valid
	);




// ---- Internal signals: ----
	
	reg [SCORE_WIDTH-1:0] match;							// match penalty register
	reg [SCORE_WIDTH-1:0] mismatch;							// mismatch penalty register
	reg [SCORE_WIDTH-1:0] gap_open;							// penalty for opening a new gap (just opening NOT extending)
	reg [SCORE_WIDTH-1:0] gap_extend;						// penalty to extend a gap sequence 

	reg [(2*TARGET_LENGTH)-1:0] targets [0:(2*MODULES)-1];	// target sequences registers (shift regs)
	reg target_valid [0:(2*MODULES)-1];						// if set, the respective target reg is full
	//reg [(2*MODULE_LENGTH)-1:0] query ;						// query register.
	reg [ID_WIDTH-1:0] q_ID;								// query's ID
	reg [LEN_WIDTH-1:0] q_length;							// query's length
	reg query_valid;										// is set when the query is loaded
	
	// intra-module nets:
	wire [MODULES-1:0] en0_;						// bus holding all enable0 signals
	wire [MODULES-1:0] en1_;						// bus holding all enable1 signals 
	wire [MODULES-1:0] toggle_;						// bus holding all toggle signals 
	wire [MODULES-1:0] full_;						// bus holding all feeder's full signals
	wire [1:0] data_ [0:MODULES-1];					// holds bases that are passing through the PEs
	wire [FEED_ADDR-1:0] feed_sel;					// feeder module selection bits
	reg [MODULES-1:0] ld_;							// bus holding all feeder's load signals
	reg ld_query;

// --- module instantiations: ---

	// scoring modules and their respective feeders
	genvar i;
	generate
		for(i=0; i< MODULES; i= i + 1)
		begin
			// Scoring module:
			ScoringModule_v1_1
			#(
				.SCORE_WIDTH(SCORE_WIDTH),	
				.LENGTH(MODULE_LENGTH),					
				.ADDR_WIDTH(ADDR_WIDTH),	
				.PREG_FREQ(),								// !x! -> SET TO DEFAULT
				._A(_A),        	
				._G(_G),        
				._T(_T),       
				._C(_C),        	
				.ZERO(ZERO)
			) SM (
			// Inputs:
			.clk(clk),
			.rst(rst),
			.en0(en0_[i]),		
			.en1(en1_[i]),
			.ld_p(ld_penalties),							
			.ld_q(ld_query),	
			.data_in(data_[i]),  		
			.query(data_in[2+ID_WIDTH +LEN_WIDTH:IN_WIDTH-1]),
			.output_select(q_length),
			.match(match),
			.mismatch(mismatch),
			.gap_open(gap_open),
			.gap_extend(gap_extend),
			// Outputs:
			.result0(results[(i*SCORE_WIDTH)+:SCORE_WIDTH]),
			.result1(results[((i+MODULES)*SCORE_WIDTH)+:SCORE_WIDTH]),
			.vld0(vld[i]),
			.vld1(vld[i+MODULES]),
			.toggle(toggle_[i]),		
			.ready()										// !X! -> port not connected
			);
	
			// Scoring module's feresult1_eder:
			SM_feeder
			#(
				.TARGET_LENGTH(TARGET_LENGTH),	
				.LEN_WIDTH(LEN_WIDTH),
				.ID_WIDTH(ID_WIDTH),
				.IN_WIDTH(IN_WIDTH-2)
			) FD (
			.clk(clk),
			.rst(rst),
			.ld(ld_[i]),
			.toggle(toggle_[i]),
			.feed_in( data_in[2:IN_WIDTH-1]),
			.en0(en0_[i]),
			.en1(en1_[i]),
			.re0(vld[i]),
			.re1(vld[i+MODULES]),
			.data_out(data_[i]),
			.full(full_[i]),
			.id0(IDs[(i*ID_WIDTH)+:ID_WIDTH]),
			.id1(IDs[((i+MODULES)*ID_WIDTH)+:ID_WIDTH])
			);
		end	
	endgenerate

	// priority encoder:
	PrioEncoder
	#(
		.BITS(MODULES)
	) enc0 (
	.in(full_),
	.out(feed_sel)
	);

// --- input logic: ---
    
    // combinatiol part:
	always@*
	begin
		ready = 0;
		full = 0;
		ld_ = 0;
		ld_query = 0;
		
		q_length = data_in[(2+ID_WIDTH)+:LEN_WIDTH];			// wire query's length to output_select
		{match, mismatch, gap_open, gap_extend} = penalties;
		ld_query = ld_sequence && data_in[1];
		full = &full_ ;
		if(ld_sequence && data_in[0])
			ld_[feed_sel] = ld_sequence;
		
		//ready = ~ld_penalties;  				// !X! -> redundant ???	
		
	end
	
	// sequential part:
	always@(posedge clk)
	begin
		if(~rst)
		begin
		
			query_valid <= 0; 					// !X! -> redundant ???
		end else 
		begin
				
			if(ld_sequence && (data_in[0:1] == 2'b01))
				{query_valid, q_ID} <= data_in[1:2+ID_WIDTH-1];
		end
	end
	

endmodule

