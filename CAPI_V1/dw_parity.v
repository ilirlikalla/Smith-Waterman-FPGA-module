//   (C) Copyright International Business Machines 2014

module dw_parity #(
  parameter DOUBLE_WORDS = 1
)(
  input  [0:64*DOUBLE_WORDS-1] data,
  input                       odd,
  output [0:DOUBLE_WORDS-1]   par
);

  genvar i;
  generate
    for (i = 0; i < DOUBLE_WORDS; i = i + 1) begin: block
      assign par[i] = ^{data[64*i +: 64], odd};
    end
  endgenerate

endmodule
