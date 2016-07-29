// Author: Ilir Likalla

/* NOTES:
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/

module baseCounter
	#( parameter
		BITS = 8				// value width
	)( 
	input wire clk,
	input wire rst,		
	input wire en,				// enable 
	input wire [BITS-1:0] top,	// counter top value
		
	output reg done,			// is set when value == top
	output reg counting			// is set while counter is counting
	);

// --- internal signals: ---
	reg [BITS-1:0] value;	// the counter's internal value
	

// --- description of the sequential part: ---
	always@(posedge clk)
	begin: CNT_SEQ
		if(~rst)
		begin
			value <= 0;
			done <= 1'b0;
			counting <= 1'b0;
		end else if(en) // if enabled count until value == top
		begin
			if( value == top)
			begin
				value <= 0;
				done <= 1'b1;
				counting <= 1'b0;
			end	else
			begin
				done <= 1'b0;
				counting <= 1'b1;
				value <= value + 1;
			end
		end
	end

endmodule
