
`define LF 8'h0A  // line feed char
`define ZERO  (2**(12-1)) // biased zero for score width 12 bits
`define STRING_LENGTH 50 
`timescale 1 ns / 100 ps
`define SCORE_WIDTH 12
`define LENGTH 48
`define TEST_FILE "score_test.fa"
module ScoringModule_tb;

/* function to encode neuclotides from ASCII to binary: */
function automatic [1:0] ConvertToBase(input logic [7:0] base);
	case(base)
		"A", "a": ConvertToBase = 2'b00;
		"G", "g": ConvertToBase = 2'b01;
		"T", "t": ConvertToBase = 2'b10;
		"C", "c": ConvertToBase = 2'b11;
	default: ConvertToBase = 2'bZZ;
	endcase
endfunction



/* VARIABLES:  */
	logic [7:0] char;
	logic [1:0] base;
	string str,db;		// string of chars from the file kept here.
	integer fd, i,j=1,length;
	logic [0:`STRING_LENGTH*2-1] query ; 	// query bit stream saved here!!!

/* SIGNALS: */
	logic clk,rst;
	logic unsigned [6:0]query_length;
	logic mode, enable;
	logic valid;
	logic signed [`SCORE_WIDTH-1:0] result;
	logic [11:0] base_counter;

/* DUT instantiation: */

ScoringModule
   #(
		.SCORE_WIDTH(`SCORE_WIDTH),	// 
		.LENGTH(`LENGTH),			// number of processing elements in the systolic array
		.LOG_LENGTH(),		// element addressing width
		._A(),        	//nucleotide "A"
		._G(),        	//nucleotide "G"
		._T(),        	//nucleotide "T"
		._C(),        	//nucleotide "C"
		.ZERO(`ZERO) // $realtobits(2**SCORE_WIDTH) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	) DUT(
// inputs:
		.clk(clk),
		.rst(rst), 				// active low 
		.en_in(enable),
		// first,
		.data_in(base),
		.query(query),
		// M_in,
		// I_in,
		// High_in,
		.match(5),			// LUT
		.mismatch(-4),	// LUT
		.gap_open(-12),	// LUT
		.gap_extend(-4 ), // LUT
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

 // sw_gen_affine DUT(.clk(clk),
             // .rst(rst),
             // .i_query_length(query_length),
				 // .i_local(mode),
             // .query(query),
             // .i_vld(enable),
             // .i_data(base),
             // .o_vld(valid),
             // .m_result(result)
             // );

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
	//readQ=0;
	//$fgetc(fd);
 end
endfunction

parameter clk_period= 10;
initial
begin: CLOCK
	clk=0;
	forever #(clk_period/2) clk=~clk;
end
	


  
initial
begin: STIMULUS
	
    #10;
	fd= $fopen(TEST_FILE,"r");
	rst= 1;
	enable= 0;	// no data to send
	mode=1; 		// set to local alignment mode (Smith-waterman mode)
	base_counter<= 31;
	#10;
	// force reset and wait for 3 cycles:
	rst= 0;
	i=0;
	#(3*clk_period);
	rst= 1;
	
	// read query from file and encode it to a bitstream:
	$fscanf(fd,"%s",str);
	$fscanf(fd,"%s",str);
	query= StrToBit(str);
	query_length = length-1;
	#clk_period;
	
	while(!$feof(fd))
	begin
	    
		
		// read line and check if it is a DNA read or not
		$fscanf(fd,"%s",str);
		if( str[0]==">")
		begin
			db=str;
			$fscanf(fd,"%s",str); // read next database sequence;
		end
		 
		// stream in the sequence base by base
		for(i=0; i<str.len(); i++)
		begin
		    
			base=ConvertToBase(str[i]); // send base to data_in
		    enable=1;
			#clk_period;
			
		end
		
		enable=0;
		//rst=1;  // reset if valid signal doesn't work
		#clk_period;
		//
		//rst=1;
		// char=$fgetc(fd);
		// if(char == ">"  || char == `LF)
		// begin
		   
			//
			// $fscanf(fd,"%s",str); // discard line
			// char=$fgetc(fd);
			// char=$fgetc(fd); // discard new line character (twice)
			// i=0;
			// if(str=="query")
				// $display(readQ(fd));				
		// end
		// $display("at time %t char is %c",$time, char);
		// base = ConvertToBase(char);
		// i= i+1;
		// #clk_period;
	end
	$fclose(fd);
	#((length+5)*clk_period);

	$stop;
end

always@(posedge clk)
	if(valid == 1)
		begin
			$display("db%d score:\t%d",j,result+`ZERO);
			j= j+1;
		end

endmodule