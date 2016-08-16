// Author: Ilir Likalla


/* NOTES:
	- this testbench serves for the ScoreBank module *** IT IS NOT COMPLETED ***
	- possible faults are associated by the comment "!X!"
*/

`define LF 8'h0A 			 	// line feed char
`define ZERO  (2**(12-1)) 		// biased zero for score width 12 bits
`define STRING_LENGTH 150 
`timescale 1 ns / 100 ps
// --- ScoringModule macros: ---
`define SCORE_WIDTH 12
`define LENGTH 128				// module's length
// --- ScoreBank macros: ---
`define MODULES 2 				// nr of modules per bank
`define ID_WIDTH 48				// sequence ID field's width
`define LEN_WIDTH 12 			// sequence length field's width
`define IN_WIDTH (2 +`ID_WIDTH	\
				+ `LEN_WIDTH 	\
                + (2*`LENGTH)) // ScoreBank input's width 
// --- test data macros: ---
// `define TEST_FILE "./data/score_test.fa" //  "../data/data.fa"
// `define TEST_FILE "../data/data.fa"
// `define TEST_FILE "../data/data100.fa"
// `define QUERY_FILE "../data/query100.fa"
`define TEST_FILE "../data/data1.fa"
`define QUERY_FILE "../data/query1.fa"

module ScorieBank_v1_tb;

/* function to encode neuclotides from ASCII to binary: */
function automatic [1:0] ConvertToBase(input logic [7:0] base);
	case(base)
		"A", "a": ConvertToBase = 2'b10;
		"G", "g": ConvertToBase = 2'b11;
		"T", "t": ConvertToBase = 2'b00;
		"C", "c": ConvertToBase = 2'b01;
	default: ConvertToBase = 2'bZZ;
	endcase
endfunction



/* VARIABLES:  */
	logic [7:0] char;
	logic [1:0] base;
	string q_str, str[100], db[100];	// strings of chars from the file kept here.
	integer fd;
	integer seq_read= 0; 						// flags that indicate that all sequences are read from the TEST_FILE
	integer seq_read_l;
	integer i;									// base indices
	integer k= 0;								// sequence indices
	integer length, nr, id;						// query length, nr of sequences for toggle 0 and 1
	logic [0:`LENGTH*2-1] query ; 				// query bit stream saved here!!!
	logic [0:`LENGTH*2-1] target ; 				// target bit stream saved here!!!

	event done;									// for syncronization between blocks
/* SIGNALS: */
	logic clk,rst;
	logic unsigned [6:0]query_length;
	logic mode, enable;
	logic signed [`SCORE_WIDTH-1:0] result0;
	//logic [11:0] base_counter;
	
	logic ld, ld_q;
	logic ld_sequence;							// if set, a new target sequence is loaded in  
	logic ld_penalties;							// if set, penalties are loaded	
	logic [0:`IN_WIDTH-1] data_in;  				// sequence data input
	
	logic ready;								// is set if the module is ready to process data
	logic full;									// is set if the module's sequence registers are full
	logic [0:(2*`MODULES*`SCORE_WIDTH)-1] results;	// results outputs
	logic [0:(2*`MODULES*`ID_WIDTH)-1] IDs;		// respective ID of each result
	logic [0:(2*`MODULES)-1] vld;					// respective valid signal for each result
	logic [`ID_WIDTH+`SCORE_WIDTH-1:0] max;		// Bank's maximum score for the current query
	logic vld_max;								// max valid

	// penalties:
	logic [`SCORE_WIDTH-1:0] match 		= 5;
	logic [`SCORE_WIDTH-1:0] mismatch	= -4;
	logic [`SCORE_WIDTH-1:0] gap_open	= -12;
	logic [`SCORE_WIDTH-1:0] gap_extend	= -4;
	logic [(4*`SCORE_WIDTH)-1:0] penalties = {match, mismatch, gap_open, gap_extend};

/* DUT instantiation: */
    
	ScoreBank_v1
	#( 	
		.SCORE_WIDTH(`SCORE_WIDTH),		// result's width in bits
		.ID_WIDTH(`ID_WIDTH),			// sequence's ID width in bits
		.LEN_WIDTH(`LEN_WIDTH),			// sequence's length width in bits
		.TARGET_LENGTH(`LENGTH),		// target sequence's length
		.MODULES(`MODULES), 			// number of Scoring Modules
		.MODULE_LENGTH(`LENGTH),		// number of processing elements per module
		.ZERO(`ZERO) 					// value of the biased zero, bias= 2 ^ SCORE_WIDTH

	) DUT (
	.clk,
	.rst,
	.ld_sequence,						// if set, a new target sequence is loaded in  
	//input ld_query,					// if set, a new query sequence is loaded		!X! -> this port might be redundant
	.ld_penalties,						// if set, penalties are loaded	
	.data_in,  					// sequence data input
	.penalties, 						// penalties input. Four penalties are loaded simultaneously
	.ready,								// is set if the module is ready to process data
	.full,								// is set if the module's sequence registers are full
	.results,							// results outputs
	.IDs,								// respective ID of each result
	.vld,								// respective valid signal for each result
	.max,								// Bank's maximum score for the current query
	.vld_max							// max valid
	);


/* function to encode a string to a bitstream: */
function automatic [`STRING_LENGTH*50-1:0] StrToBit(input string seq,input string str);  // (input: file_descriptor,output: read_query, query_length)
 integer i,j;
 
 begin	
	
	j= 0;
	for(i= 0;i<str.len(); i++)
	begin
		StrToBit[j+:2]=ConvertToBase(str[i]);
		j= j+2;
	end
	//$display("%s length: %d",seq ,str.len());
	length= str.len();

 end
endfunction

parameter clk_period= 4;
initial
begin: CLOCK
	clk=0;
	forever #(clk_period/2) clk=~clk;
end
	


// --- initialise signals & read data from files: ---  
initial
begin: INIT_TB
	$dumpfile("scoring_bank_v1.vcd");
	$dumpvars;
    #clk_period;

	// init:
	rst= 1;
	id = 0;
	enable= 0;
	ld_penalties = 0;
	ld_sequence = 0;
	#clk_period;

	// force reset and wait for 3 cycles:
	rst= 0;
	#(3*clk_period);
	rst= 1;
	
	// load penalties:
	ld_penalties = 1;
	#clk_period;
	ld_penalties = 0;

	// read query from file and encode it to a bitstream:
	fd= $fopen(`QUERY_FILE,"r");
	$fscanf(fd,"%s",q_str);
	$fscanf(fd,"%s",q_str);
	
	$fclose(fd);
	#clk_period;

	// load query:
	query= StrToBit("query",q_str);
	data_in[0:1] = 2'b01;					// query sequence 
	data_in[2+:`ID_WIDTH] = id;
	data_in[(2+`ID_WIDTH)+:`LEN_WIDTH] = length;
	data_in[(2+`ID_WIDTH +`LEN_WIDTH):`IN_WIDTH-1] = query;
	ld_q = 1;
	#clk_period;
	ld_q = 0;
	
	// read target sequences:
	fd= $fopen(`TEST_FILE,"r");
	while(!$feof(fd))
	begin
		// read line and check if it is a DNA read or not
		$fscanf(fd,"%s",str[k]);
		if( str[k][0]==">")
		begin
			db[k]=str[k];
			$fscanf(fd,"%s",str[k]); 		// read next database sequence;
			k= k+1;
		end else break;
	end
	$fclose(fd);
	seq_read = 1;
	// save nr of sequences:
	nr = k;

	// reset indices:
    i = 0;
	k = 0;
	
	@done; 									// wait for all sequences to be fed			
	#((`LENGTH*3)*clk_period);				// wait for the last sequence to be processed		 
	$stop; 									// stop simulation
end


// --- feed module: ---
always@(posedge clk)
begin: SB_stimulus
	
	// if there are no more sequences stop:
	if(k >= nr)
	begin
		-> done;						// blocking trigger!!!
		disable SB_stimulus;						// stop this process
	end
	
	if(ld )
	begin
		k = k+1;
	end
	data_in[0:1] <= 2'b10;					// target sequence 
	data_in[2+:`ID_WIDTH] <= k;
	data_in[(2+`ID_WIDTH +`LEN_WIDTH):`IN_WIDTH-1] <= StrToBit(db[k], str[k]);
	data_in[(2+`ID_WIDTH)+:`LEN_WIDTH] <= length;
	//ld_sequence <= ld;
	seq_read_l <= seq_read;		
end

always@*
begin:SB_stim_comb
	ld= 0;
	
	if(~full && seq_read_l && (k< nr) )
		ld = 1;
	ld_sequence = ld || (ld_q && data_in[1]);
	//ld = ld_l && ld_s;
end

bit [0:100]vflg  = 0;	// vflg(i) is set if that result is already read
integer j, r_id, r_result;
//// --- get results: ---
always@(posedge clk)
begin: Display_results	
	
	for(j=0; j<2*`MODULES; j= j+1)
	begin
		r_id = IDs[(j*`ID_WIDTH)+:`ID_WIDTH];
		r_result = results[(j*`SCORE_WIDTH)+:`SCORE_WIDTH];
		if(vld[j] && ~vflg[r_id])
		begin
			$display("@%8t: %10s score: \t%d", $time, db[r_id], r_result-`ZERO);
			vflg[r_id] = 1;
		end
	end
end


endmodule
