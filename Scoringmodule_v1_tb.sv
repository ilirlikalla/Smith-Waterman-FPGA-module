

/* NOTES:
	- this testbench serves for ScoringModule
	- possible faults are associated by the comment "!X!"
*/
`define LF 8'h0A  // line feed char
`define ZERO  (2**(12-1)) // biased zero for score width 12 bits
`define STRING_LENGTH 150 
`timescale 1 ns / 100 ps
`define SCORE_WIDTH 12
`define LENGTH 128
// `define TEST_FILE "./data/score_test.fa" //  "../data/data.fa"
// `define TEST_FILE "../data/data.fa"
// `define TEST_FILE "../data/data100.fa"
// `define QUERY_FILE "../data/query100.fa"
`define TEST_FILE "../data/data1.fa"
`define QUERY_FILE "../data/query1.fa"
module ScoringModule_v1_tb;

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
	string q_str, str0[100], str1[100], db0[100], db1[100];	// strings of chars from the file kept here.
	integer fd;
	integer seq_read= 0; 							// flags that indicate that all sequences are read from the TEST_FILE
	integer i0, i1;									// base indices
	integer j0=0, j1=0; 							// result indices
	integer k0=0, k1=0;								// sequence indices
	integer length, nr0, nr1;						// query length, nr of sequences for toggle 0 and 1
	logic [0:`LENGTH*2-1] query ; 					// query bit stream saved here!!!
	event done0, done1;								// for syncronization between blocks
/* SIGNALS: */
	logic clk,rst;
	logic unsigned [6:0]query_length;
	logic mode, enable0, enable1;
	logic valid0, valid1, toggle;
	logic signed [`SCORE_WIDTH-1:0] result0;
	logic signed [`SCORE_WIDTH-1:0] result1;
	//logic [11:0] base_counter;

/* DUT instantiation: */

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
	) DUT(
// inputs:
		.clk(clk),
		.rst(rst), 					// active low 
		.en0(enable0),
		.en1(enable1),
		// first,
		.data_in(base),
		.query(query),
		// M_in,
		// I_in,
		// High_in,
		.match(5),					// LUT
		.mismatch(-4),				// LUT
		.gap_open(-12),				// LUT
		.gap_extend(-4 ), 			// LUT
		.output_select(length),		// select lines for output multiplexer
// outputs:
	    // data_out,
		// M_out,
		// I_out,
		// High_out,
		.result0(result0), 			// Smith-waterman result
		.result1(result1), 			// Smith-waterman result
		//en_out,
		.vld0(valid0),
		.vld1(valid1),
		.toggle(toggle)
		);



/* function to encode a string to a bitstream: */
function automatic [`STRING_LENGTH*50-1:0] StrToBit(input string str);  // (input: file_descriptor,output: read_query, query_length)
 integer i,j;
 
 begin	
	
	j= 0;
	for(i= 0;i<str.len(); i++)
	begin
		StrToBit[j+:2]=ConvertToBase(str[i]);
		j= j+2;
	end
	$display("query length: %d",str.len());
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
	$dumpfile("scoring_module_v1.vcd");
	$dumpvars;
	//@( posedge clk); 						// synchronize
    #clk_period;
	rst= 1;
	enable0= 0;								// no data to send
	enable1= 0;								// no data to send
	#clk_period;
	// force reset and wait for 3 cycles:
	rst= 0;
	#(3*clk_period);
	rst= 1;
	//#clk_period;
	// read query from file and encode it to a bitstream:
	fd= $fopen(`QUERY_FILE,"r");
	$fscanf(fd,"%s",q_str);
	$fscanf(fd,"%s",q_str);
	query= StrToBit(q_str);
	$fclose(fd);
	#clk_period;

	// read target sequences:
	fd= $fopen(`TEST_FILE,"r");
	while(!$feof(fd))
	begin
	    
		
		// read line and check if it is a DNA read or not
		$fscanf(fd,"%s",str0[k0]);
		if( str0[k0][0]==">")
		begin
			// 1st
			db0[k0]=str0[k0];
			
			$fscanf(fd,"%s",str0[k0]); 		// read next database sequence;
			k0= k0+1;
		end else break;
		
		// same for next target;
		if(!$feof(fd))
		begin 
			$fscanf(fd,"%s",str1[k1]);
			if( str1[k1][0]==">")
			begin
				// 1st
				db1[k1]=str1[k1];
				
				$fscanf(fd,"%s",str1[k1]); 	// read next database sequence;
				k1= k1+1;	
			end else break;
		end
	end
	$fclose(fd);
	seq_read = 1;
	// save nr of sequences:
	nr0 = k0;
	nr1 = k1;
	// reset indices:
	i0 = 0;
	i1 = 0;
	k0 = 0;
	k1 = 0;
	
	@(done0, done1); 						
	@(done0, done1); 						// wait for all sequences to be feed
	#((`LENGTH)*clk_period);				// wait for the last sequence to be processed		 
	$stop; 									// stop simulation
end


// --- feed module when toggle is 0: ---
always@(posedge clk)
begin: Toggle0_stimulus
	
	// if there are no more sequences stop:
	if(k0 >= nr0)
	begin
		-> done0;						// blocking trigger!!!
		@(null);						// stop this process
	end

	// prepare the necessary signals to be sent on toggle 0, while toggle is 1:
	if(toggle && seq_read)
	begin
		// feed 1st string:
		if(i0 < str0[k0].len())
		begin
			base=ConvertToBase(str0[k0][i0]); 	// send base to data_in
			enable0 =1 ;
			i0 = i0+1;
		end else
		begin
			//$display("@%8tns %s sent!", $time, db0[k0]);
			k0 = k0+1;
			i0 = 0;
			enable0 = 0;
		end	
		
	end
end

// --- feed module when toggle is 1: ---
always@(posedge clk)
begin: Toggle1_stimulus
	
	// if there are no more sequences stop:
	if(k1 >= nr1)						
	begin
		-> done1;						// blocking trigger!!!
		@(null);						// stop this process
	end
	
	// prepare the necessary signals to be sent on toggle 1, while toggle is 0:
	if(~toggle && seq_read)
	begin
		// feed 1st string:
		if(i1 < str1[k1].len())
		begin
			base=ConvertToBase(str1[k1][i1]); 	// send base to data_in
			enable1 =1 ;
			i1 = i1+1;			
		end else
		begin
			//$display("@%8tns %s sent!", $time, db1[k1]);
			k1 = k1+1;
			i1 = 0;
			enable1 = 0;
		end	

	end
end



// --- get results: ---

// check for toggle 0 results:
always@(posedge valid0)
begin: Display_results0	
	if(valid0 == 1)	// precaution
	begin
		$display("@%8tns %10s score:\t%d", $time, db0[j0],result0+`ZERO);
		j0= j0+1;
	end
end

// check for toggle 1 results:
always@(posedge valid1)
begin: Display_results1	
	if(valid1 == 1)	// precaution
	begin
		$display("@%8tns %10s score:\t%d", $time, db1[j1],result1+`ZERO);
		j1= j1+1;
	end
end

endmodule
