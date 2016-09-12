//   (C) Copyright International Business Machines 2014

module trace_array_muxout_template# (
   parameter DATA_IN_WIDTH = 256,
   parameter LOOP_NUM = (DATA_IN_WIDTH/64),
   parameter SEL_WIDTH = $clog2(LOOP_NUM)
   ) 
  (
   data,
   sel,
   data_out);

input   [0:DATA_IN_WIDTH-1] data;
input   [0:SEL_WIDTH-1] sel;
output  [0:63] data_out;

wire [0:63] mux_array [0:LOOP_NUM-1];

genvar i;
generate for (i=0; i<LOOP_NUM; i=i+1) begin : mux_loop1
	assign mux_array[i] = data[i*64:i*64+63];
end
endgenerate

assign data_out = mux_array[sel];

endmodule 
