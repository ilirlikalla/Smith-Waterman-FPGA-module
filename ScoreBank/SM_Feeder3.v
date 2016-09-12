// Author: Ilir Likalla


/* NOTES:
	- in this version of the feeder module the state machines are expressed as separate 'always@' blocks
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


// input selection macros:
`define ID		buffer_in[(IN_WIDTH-1)-:ID_WIDTH]
`define LENGTH 	buffer_in[(2*TARGET_LENGTH+LEN_WIDTH-1)-:LEN_WIDTH]
`define TARGET 	buffer_in[(2*TARGET_LENGTH-1):0]

module SM_feeder3
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
	output reg [1:0] data_out,
	output reg full,					// is set when the feeder is full of targets
	output [ID_WIDTH-1:0] id0,
	output [ID_WIDTH-1:0] id1				
	);
	
	// --- internal signals: ---

	// counter signals:
	reg [LEN_WIDTH-1:0] counter0;		// base counter for toggle 0
	reg [LEN_WIDTH-1:0] counter1;		// base counter for toggle 1
	
	// sequence related signals:
	reg [LEN_WIDTH-1:0] length0;		// sequence's length register 0
	reg [LEN_WIDTH-1:0] length1;		// sequence's length register 1
	reg [2*TARGET_LENGTH-1:0] target0;	// target sequence registers
	reg [2*TARGET_LENGTH-1:0] target1;	// target sequence registers
	reg loaded0;						// is set when the respective target register is loaded
	reg loaded1;						// is set when the respective target register is loaded
	reg [IN_WIDTH-1:0] buffer_in;		// input buffer
	reg buffer_vld;						// valid signal for the buffer_in

	// state signals:
	localparam 	idle = 2'b10,
				feed = 2'b01;
	reg [1:0] state0;					// state for toggle 0 register
	reg [1:0] state1;					// state for toggle 1 register

	// fifo signals:
	reg we0, we1;
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
	
	// input buffer logic:
	always@(posedge clk)
	begin
		buffer_vld <= 1'b0;
		if(~loaded0 || ~ loaded1)
			{buffer_vld, buffer_in} <= {ld, feed_in};
	end


	// toggle 0 state machine:
	always@(posedge clk)
	begin
		if(~rst)
		begin
			loaded0 <= 1'b0;
			en0 <= 1'b0;
			state0 <= idle;
		end else
		begin if(toggle)
			case(state0)
			idle:
				if(buffer_vld && ~loaded0)
				begin
					length0 <= `LENGTH;
					target0 <= `TARGET;
					loaded0 <= 1'b1;	
					en0 <= 1'b1;
					state0 <= feed;				// enable the state machine to feed data on toggle 0
				end	
			feed:
				begin
					target0[2*TARGET_LENGTH-1:0] <= {2'b00,target0[2*TARGET_LENGTH-1:2]}; // feed bases to scoring module, by shifting out the sequence !X!
					if(counter0 == (length0 - 1))
					begin 
						en0 <= 1'b0;
						loaded0 <= 1'b0;
						state0 <= idle;
					end	
				end
			default: 
				state0 <= idle;		// go to safe state
			endcase
		end
	end

	// toggle 0 state machine:
	always@(posedge clk)
	begin
		if(~rst)
		begin
			loaded1 <= 1'b0;
			en1 <= 1'b0;
			state1 <= idle;
		end else
		begin if(~toggle)
			case(state1)
			idle:
				if(buffer_vld && ~loaded1)
				begin
					length1 <= `LENGTH;
					target1 <= `TARGET;
					loaded1 <= 1'b1;	
					en1 <= 1'b1;
					state1 <= feed;				// enable the state machine to feed data on toggle 0
				end	
			feed:
				begin
					target1[2*TARGET_LENGTH-1:0] <= {2'b00,target1[2*TARGET_LENGTH-1:2]}; // feed bases to scoring module, by shifting out the sequence !X!
					if(counter1 == (length1 - 1))
					begin 
						en1 <= 1'b0;
						loaded1 <= 1'b0;
						state1 <= idle;
					end	
				end
			default: 
				state1 <= idle;		// go to safe state
			endcase
		end
	end
	
	// base counter for toggle 0:		
	always@(posedge clk)
		if(~rst | ~en0)
			counter0 <= 0;
		else if( en0 & toggle)
			counter0 <= counter0 + 1;

	// base counter for toggle 1:		
	always@(posedge clk)
		if(~rst | ~en1)
			counter1 <= 0;
		else if( en1 & ~toggle)
			counter1 <= counter1 + 1;
			
	// --- combinational part: ---	

	always@*
	begin
		we0 = 0;
		we1 = 0;
		data_out = 0;
		data_out = (toggle)? target1[1:0] : target0[1:0];
		full = (buffer_vld && (loaded0 || loaded1)) || (loaded0 && loaded1) || full0 || full1 ;
		if(state0 == idle)
			we0 = buffer_vld && ~loaded0 && toggle;
		if(state1 == idle) 
			we1 = buffer_vld && ~loaded1 && ~toggle;
	end
	

	
endmodule
