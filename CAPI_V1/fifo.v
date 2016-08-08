// Author: Ilir Likalla

/* NOTES:
	- depth MUST be a power of 2
*/
module fifo
	#(parameter
		MEM_OPT = "m20k,no_rw_check",
		WIDTH = 48,
		DEPTH = 4,
		ADDR_BITS = $clog2(DEPTH)
	)(
	input rst,
	input clk,			
	input we,					// write enable
	input re,					// read enable
	input [0:WIDTH-1] in,		// data in port
	output full,				// fifo full flag
	output reg [0:WIDTH-1] out	// data out port
	);


	
	reg [0:ADDR_BITS-1] i_ad;	// data in in address (pointer)
	reg [0:ADDR_BITS-1] o_ad;	// data out address (pointer)
	reg [0:DEPTH-1] vld;		// data valid signals
	reg re_shw;					// shadow of read enable
`ifdef use_altera_atts	
	(* ramstyle = MEM_OPT *)reg [0:WIDTH-1] ram [0:DEPTH-1];
`else
	reg [0:WIDTH-1] ram [0:DEPTH-1];
`endif
	
	// simultaneous read & write (unless fifo is full):
	always @ (posedge clk) 
	begin:FIFO_SEQ
		if(~rst)
		begin
			i_ad <= 0;
			o_ad <= 0;
			vld <= 0;
			re_shw <=0;
		end else 
		begin 
			// input logic:					
			if (we)
			begin
				{vld[i_ad], ram[i_ad]} <= {1'b1, in};
			 	i_ad <= i_ad + 1;
			end
			// output logic:
			out <= ram[o_ad];
			if (re && ~re_shw)
			begin
				vld[o_ad] <= 1'b0;
				o_ad <= o_ad + 1; 
			end
			re_shw <= re;	// update re's shadow
		end
	end

	assign full = &vld;		 // set full signal

endmodule
