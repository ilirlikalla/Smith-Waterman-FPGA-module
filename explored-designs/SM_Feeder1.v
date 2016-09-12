// Author: Ilir Likalla


/* NOTES:
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


// input selection macros:
`define ID		feed_in[(IN_WIDTH-1)-:ID_WIDTH]
`define LENGTH 	feed_in[(2*TARGET_LENGTH+LEN_WIDTH-1)-:LEN_WIDTH]
`define TARGET 	feed_in[(2*TARGET_LENGTH-1):0]

module SM_feeder1
	#( parameter
		TARGET_LENGTH = 128,			// target sequence's length	
		LEN_WIDTH = 12,					// sequence's length width in bits
		ID_WIDTH = 48,					// sequence's ID width in bits
		IN_WIDTH = (ID_WIDTH			
				+ LEN_WIDTH
				+ (2*TARGET_LENGTH))	// input's width (data_in)
	)(
	input clk,
	input rst,
	input ld,							// load signal
	input toggle,						// toggle from ScoringModule
	input [IN_WIDTH-1:0] feed_in,		// input data
	input re0,							// id0 fifo's read enable
	input re1,							// id1 fifo's read enable
	output reg en0,
	output reg en1,
	output  [1:0] data_out,
	output full,						// is set when the feeder is full of targets
	output [ID_WIDTH-1:0] id0,
	output [ID_WIDTH-1:0] id1				
	);
	
	// --- internal signals: ---

	// counter signals:
	reg [LEN_WIDTH-1:0] counter0;			// counter for toggle 0
	reg [LEN_WIDTH-1:0] counter1;			// counter for toggle 1
	
	// sequence related signals:
	reg [ID_WIDTH-1:0] id [0:1];			// sequence's id registers
	reg [LEN_WIDTH-1:0] length [0:1];		// sequence's length registers
	reg [2*TARGET_LENGTH-1:0] target [0:1];	// target sequence registers
	reg [0:1] target_loaded;				// is set when the respective target register is loaded
	reg ld_indx;							// points to the next register/ that is to be loaded
	reg i0, i1;								// indices for toggle 0 & 1

	// state signals:
	localparam 	idle = 1'b0,
				feed = 1'b1;
	reg [1:0] state;						// state register
	wire [2:0] state_w;

	// fifo signals:
	wire we0, we1;
	wire full0, full1;
 
	// --- instantiations: ---
	
	// fifo for toggle 0:
	fifo
	#(
		.WIDTH(ID_WIDTH),
		.DEPTH(4)
	) id_fifo0 (
	.rst(rst),
	.clk(clk),
	.we(we0),
	.re(re0),
	.in(`ID),
	.full(full0),
	.out(id0)
	);

	// fifo fot toggle 1:
	fifo
	#(
		.WIDTH(ID_WIDTH),
		.DEPTH(4)
	) id_fifo1 (
	.rst(rst),
	.clk(clk),
	.we(we1),
	.re(re1),
	.in(`ID),
	.full(full1),
	.out(id1)
	);

	
    

	// --- sequential part: ---
	assign state_w = {toggle,state};
	always@(posedge clk)
	begin	
		if(~rst)
		begin
			target_loaded <= 2'b00;
	  		ld_indx <= 1'b0;
			en0 <= 1'b0;
			en1 <= 1'b0;
			state <= {idle, idle};
		end else
		begin
			case(state_w)
			// states for toggle 0:
			{1'b0, state[1], idle}:
		
				if(ld)								// !X! ->  data might be overwritten. error signal?
				begin
					
					length[ld_indx] <= `LENGTH;
					target[ld_indx] <= `TARGET;
					target_loaded[ld_indx] <= 1'b1;	
					en0 <= 1'b1;
					i0 <= ld_indx;
					ld_indx <= ~ld_indx;
					state <= {state[1], feed};
				end
		
			{1'b0, state[1], feed}:			
				begin
					target[i0][2*TARGET_LENGTH-1:0] <= {2'b00,target[i0][2*TARGET_LENGTH-1:2]}; // feed bases to scoring module, by shifting out the sequence !X!
					if(counter0 == (length[i0] - 1))
					begin 
						en0 <= 1'b0;
						target_loaded[i0] <= 1'b0;
						state <= {state[1], idle};
					end						
				end  
			// states for toggle 1:
			{1'b1, idle, state[0]}:
		
				if(ld)								// !X! ->  data might be overwritten. error signal?
				begin
					
					length[ld_indx] <= `LENGTH;
					target[ld_indx] <= `TARGET;
					target_loaded[ld_indx] <= 1'b1;
					en1 <= 1'b1;
					i1 <= ld_indx;
					ld_indx <= ~ld_indx;
					state <= {feed, state[0]};
				end
		
			{1'b1, feed, state[0]}:			
				begin
					target[i1][2*TARGET_LENGTH-1:0] <= {2'b00,target[i1][2*TARGET_LENGTH-1:2]}; // feed bases to scoring module, by shifting out the sequence !X!
					if(counter1 == (length[i1] - 1))
					begin 
						en1 <= 1'b0;
						target_loaded[i1] <= 1'b0;
						state <= {idle, state[0]};
					end						
				end  
		endcase
		end
	end
	
	// base counter for toggle 0:		
	always@(posedge clk)
		if(~rst | ~en0)
			counter0 <= 0;
		else if( en0 & ~toggle)
			counter0 <= counter0 + 1;


	// base counter for toggle 1:		
	always@(posedge clk)
		if(~rst | ~en1)
			counter1 <= 0;
		else if( en1 & ~toggle)
			counter1 <= counter1 + 1;
			
	// --- combinational part: ---	
	assign data_out = (toggle)? target[i1][1:0] : target[i0][1:0];
	assign we0 = ld & ~toggle;	
	assign we1 = ld & toggle;
	assign full = &target_loaded ||(ld & (|target_loaded)) || full0 || full1 ;

	


endmodule
