//   (C) Copyright International Business Machines 2014

module ram #(
  parameter RAM_OPT = "m20k,no_rw_check",
  parameter WIDTH = 64,
  parameter DEPTH = 32,
  parameter ADDR_BITS = $clog2(DEPTH)
)(
  input                  clk,
  input  [0:ADDR_BITS-1] wrad,
  input                  we,
  input  [0:WIDTH-1]     d,
  input  [0:ADDR_BITS-1] rdad,
  output [0:WIDTH-1]     q
);

  reg [0:WIDTH-1] out;

`ifdef use_altera_atts	
  (* ramstyle = RAM_OPT *)reg [0:WIDTH-1] memory [0:DEPTH-1];
`else
  reg [0:WIDTH-1] memory [0:DEPTH-1];
`endif

  always @ (posedge clk) begin
    if (we)
      memory[wrad] <= d;
    out <= memory[rdad];
  end

  assign q = out;

endmodule
