`define LF 8'h0A
`define STRING_LENGTH 50
`timescale 1 ns / 100 ps
module aligner_tb;



/* function to encode neuclotides from ASCII to binary: */
function automatic [1:0] ConvertToBase(input reg [7:0] base);
	case(base)
		"A", "a": ConvertToBase = 2'b00;
		"G", "g": ConvertToBase = 2'b01;
		"T", "t": ConvertToBase = 2'b10;
		"C", "c": ConvertToBase = 2'b11;
	default: ConvertToBase = 2'bZZ;
	endcase
endfunction



/* VARIABLES:  */
	reg [7:0] char;
	reg [1:0] base;
	reg [0:`STRING_LENGTH*8-1] str;		// string of chars from the file kept here.
	integer fd, i,j,length;
	reg [0:`STRING_LENGTH*2-1] query ; 	// query bit stream saved here!!!

/* SIGNALS: */
	reg clk,rst;
	reg [5:0]query_length;
	reg mode, valid_in;
	wire valid;
	wire signed [10:0] result;

/* DUT instantiation: */

 sw_gen_affine DUT(.clk(clk),
             .rst(rst),
             .i_query_length(query_length),
				 .i_local(mode),
             .query(query),
             .i_vld(valid_in),
             .i_data(base),
             .o_vld(valid),
             .m_result(result)
             );

/* function to encode a string to a bitstream: */
function automatic [`STRING_LENGTH*50-1:0] StrToBit(input reg [`STRING_LENGTH*8-1:0] str);  // (input: file_descriptor,output: read_query, query_length)
 integer i,j;
 
 begin	
	i= 0;
	j= 0;
	while(str[i+:8]!=8'd0)
	begin
		StrToBit[j+:2]=ConvertToBase(str[i+:8]);
		i= i+8;
		j= j+2;
	end
	$display("query length: %d, %d",j,(j/2));
	length= (j/2);
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
	fd= $fopen("score_test.fa","r");
	rst= 0;
	valid_in= 0;	// no data to send
	mode=0; 		// set to local alignment mode (Smith-waterman mode)
	#10;
	// assert reset and wait for 3 cycles:
	rst= 1;
	i=0;
	#(3*clk_period);
	rst= 0;
	
	// read query from file and encode it to a bitstream:
	$fscanf(fd,"%s",str);
	$fscanf(fd,"%s",str);
	query= StrToBit(str);
	query_length = length;
	#clk_period;
	while(!$feof(fd))
	begin
	    
		
		// read line and check if it is a DNA read or not
		$fscanf(fd,"%s",str);
		if( str[0+:8]==">")
			$fscanf(fd,"%s",str); // read next database sequence;
		// stream in the sequence base by base 
		i=0;
		while(str[i+:8]!=8'd0)
		begin
			base=ConvertToBase(str[i+:8]);
		    valid_in=1;
			i= i+1;
			#clk_period;
		end
		valid_in=0;
		#clk_period;
		// char=$fgetc(fd);
		// if(char == ">"  || char == `LF)
		// begin
		   
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
	$stop;
end

endmodule