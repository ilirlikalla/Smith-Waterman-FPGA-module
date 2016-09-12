//   (C) Copyright International Business Machines 2014

module endian_swap #(
  parameter BYTES = 1
)(
  input  [0:8*BYTES-1] data_in,
  input                little_endian,
  output [0:8*BYTES-1] data_out
);

  genvar i;
  generate
    for (i = 0; i < BYTES; i = i + 1) begin: block
      assign data_out[8*i:8*i+7] = (little_endian) ?
               data_in[8*(BYTES-1-i):8*(BYTES-1-i)+7] :
               data_in[8*i:8*i+7];
    end
  endgenerate

endmodule
