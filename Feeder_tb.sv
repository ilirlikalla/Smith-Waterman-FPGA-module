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
`define IN_WIDTH (`ID_WIDTH	\
				+ `LEN_WIDTH 	\
                + (2*`LENGTH)) // ScoreBank input's width 
// --- test data macros: ---
// `define TEST_FILE "./data/score_test.fa" //  "../data/data.fa"
// `define TEST_FILE "../data/data.fa"
// `define TEST_FILE "../data/data100.fa"
// `define QUERY_FILE "../data/query100.fa"
`define TEST_FILE "../data/data1.fa"
`define QUERY_FILE "../data/query1.fa"

module Feeder_tb;

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
	integer seq_read= 0; 				// flags that indicate that all sequences are read from the TEST_FILE
	integer i;							// base indices
	integer k= 0;						// sequence indices
	integer j0= 0, j1= 0;				// result's inices
	integer query_len; 					// query length 
	integer length;						// length for Str2bit()
	integer nr, id;						//  nr of sequences for toggle 0 and 1, & sequence id
	logic [0:`LENGTH*2-1] query ; 		// query bit stream saved here!!!
	logic [0:`LENGTH*2-1] target ; 		// target bit stream saved here!!!

	event done;							// for syncronization between blocks
/* SIGNALS: */
	logic clk,rst;
	logic mode;
	logic signed [`SCORE_WIDTH-1:0] result0;
	logic signed [`SCORE_WIDTH-1:0] result1;
	//logic [11:0] base_counter;
	logic ld_s;							// sequential load
	logic ld;							// load sequence signal
	logic toggle;						// toggle from ScoringModule
	logic [`IN_WIDTH-1:0] feed_in;		// input data
	logic re0;							// id0 fifo's read enable
	logic re1;							// id1 fifo's read enable
	logic en0;
	logic en1;
	logic [1:0] data;
	wire full;						// is set when the feeder is full of targets
	logic [`ID_WIDTH-1:0] id0;
	logic [`ID_WIDTH-1:0] id1;	
	logic valid0, valid1;
	// penalties:

/* DUT instantiation: */
    
	SM_feeder
	#(
		.TARGET_LENGTH(`LENGTH),			// target sequence's length	
		.LEN_WIDTH(`LEN_WIDTH),					// sequence's length width in bits
		.ID_WIDTH(`ID_WIDTH)					// sequence's ID width in bits
	) DUT(
	.clk(clk),
	.rst(rst),
	.ld(ld),
	.toggle(toggle),
	.feed_in(feed_in),
	.re0(valid0),
	.re1(valid1),
	// out:
	.en0(en0),
	.en1(en1),
	.data_out(data),
	.full(full),
	.id0(id0),
	.id1(id1)			
	);




	ScoringModule_v1
   #(
		.SCORE_WIDTH(`SCORE_WIDTH),	// result width in bits
		.LENGTH(`LENGTH),			// number of processing elements in the systolic array
		.ADDR_WIDTH(),				// element addressing width
		._A(),        				//nucleotide1 "A"
		._G(),        				//nucleotide "G"
		._T(),        				//nucleotide "T"
		._C(),        				//nucleotide "C"
		.ZERO(`ZERO) 				// $realtobits(2**SCORE_WIDTH) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	) SM(
	.clk(clk),
	.rst(rst), 						// active low 
	.en0(en0),
	.en1(en1),
	.data_in(data),
	.query(query),
	.match(5),						// LUT
	.mismatch(-4),					// LUT
	.gap_open(-12),					// LUT
	.gap_extend(-4 ), 				// LUT
	.output_select(query_len),		// select lines for output multiplexer
	.result0(result0), 				// Smith-waterman result
	.result1(result1), 				// Smith-waterman result
	.vld0(valid0),
	.vld1(valid1),
	.toggle(toggle)
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
	$dumpfile("feeder.vcd");
	$dumpvars;
    #clk_period;

	// init:
	rst= 1;
	id = 0;
	ld_s= 0;
	#clk_period;

	// force reset and wait for 3 cycles:
	rst= 0;
	#(3*clk_period);
	rst= 1;
	#clk_period;


	// read query from file and encode it to a bitstream:
	fd= $fopen(`QUERY_FILE,"r");
	$fscanf(fd,"%s",q_str);
	$fscanf(fd,"%s",q_str);
	query= StrToBit("query",q_str);
	query_len = length;
	$fclose(fd);
	#clk_period;


	
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
	#((`LENGTH)*2*clk_period);				// wait for the last sequence to be processed		 
	$stop; 									// stop simulation
end


// --- feed module: ---
always@(posedge clk)
begin: SB_stimulus
	
	// if there are no more sequences stop:
	ld <= 0; 
	if(k >= nr)
	begin
		-> done;													// blocking trigger!!!
		disable SB_stimulus;										// stop this process
	end
	
	if(seq_read && !full)
	begin
		feed_in[(`IN_WIDTH-1)-:`ID_WIDTH] <= k; 					// put sequence's ID
		feed_in[(`IN_WIDTH-`ID_WIDTH-1)-:`LEN_WIDTH] <= str[k].len;	// put sequence's length
		feed_in[(2*`LENGTH-1):0] <= StrToBit(db[k],str[k]);			// put sequence's bases
		ld <= 1;														// assert load signal to the feeder
		k <= k+1;
	end
end

//assign ld = ~full & ld_s;

bit [0:100]vflg  = 0;	// vflg(i) is set if that result is already read
integer j, r_id, r_result;

// --- get results: ---

// check for toggle 0 results:
always@(posedge valid0)
begin: Display_results0	
	if(valid0 == 1)	// precaution
	begin
		$display("@%8tns %10s score:%4d, id:%3d", $time, db[id0],result0+`ZERO, id0);
		//j0= j0+1;
	end
end

// check for toggle 1 results:
always@(posedge valid1)
begin: Display_results1	
	if(valid1 == 1)	// precaution
	begin
		$display("@%8tns %10s score:%4d, id:%3d", $time, db[id1],result1+`ZERO, id1);
		//j0= j0+1;
	end
end

endmodule
