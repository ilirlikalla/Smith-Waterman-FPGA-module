module PrioEncoder
	#( parameter
		BITS = 4,
		O_BITS = $clog2(BITS)
	)(
	input [BITS-1:0] in,
	output reg [O_BITS-1:0] out
	);

	integer i;
	always@*
	begin
		out = 0;
		for( i= BITS-1; i>= 0; i = i-1)
			if(~in[i])
				out = i;
	end
endmodule
