//   (C) Copyright International Business Machines 2014

module parity #(
  parameter BITS = 1
)(
  input  [0:BITS-1] data,
  input             odd,
  output            par
);

  assign par = ^{data, odd};

endmodule
