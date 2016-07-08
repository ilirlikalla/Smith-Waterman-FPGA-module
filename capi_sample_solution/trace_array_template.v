//   (C) Copyright International Business Machines 2014

//Use this define to build RAMs using desired attributes or let the tool infer them by commenting out.
`define use_altera_atts

module trace_array_template# (
   parameter RAM_OPT = "m20k,no_rw_check",
   parameter ADDR_WIDTH = 8,
   parameter DATA_WIDTH = 120,
   parameter TRACE_ID   = "0x0",
//Don't overwrite parameters below this line
   parameter DATA_WITH_TIMESTAMP = DATA_WIDTH+40,
   parameter DATA_WITH_TIMESTAMP_AND_ZEROES = DATA_WITH_TIMESTAMP+64,
   parameter RAM_DEPTH = 2**ADDR_WIDTH,
   parameter READS_PER_LINE = (DATA_WITH_TIMESTAMP%64 == 0) ? (DATA_WITH_TIMESTAMP/64) : ((DATA_WITH_TIMESTAMP/64) + 1),
   parameter NUMBER_OF_SELS = DATA_WITH_TIMESTAMP_AND_ZEROES/64,
   parameter SEL_WIDTH_DIV = $clog2(NUMBER_OF_SELS),
   parameter COVERED_BITS = 64*(2**SEL_WIDTH_DIV),
   parameter SEL_WIDTH_COVERED = COVERED_BITS-DATA_WITH_TIMESTAMP_AND_ZEROES,
   parameter EXTRA_SEL_BIT = (SEL_WIDTH_COVERED >= 0) ? 0 : 1,
   parameter SEL_WIDTH = SEL_WIDTH_DIV + EXTRA_SEL_BIT
   )
   (
   clk,
   reset,
   read_controls,
   trace_rvalid,
   flow_mode_in,
   trace_data_in,
   trace_valid,
   trace_tag,
   local_trace_stop,
   trace_data_out,
   trace_data_ack_out);


input   clk;
input   reset;
input   [17:21] read_controls;
input   trace_rvalid;
input   flow_mode_in;
input   [0:DATA_WIDTH-1] trace_data_in;
input   trace_valid;
input   [0:ADDR_WIDTH-1] trace_tag;
input   local_trace_stop;
output  [0:63] trace_data_out;
output  reg trace_data_ack_out;

wire    trace_ctl;
wire    flow_mode;
wire    trace_stopped_in;
reg     trace_stopped_q = 1'b 0; 
wire    [0:39] tstamp_in; 
reg     [0:39] tstamp_q = 40'h 0000000000; 
wire    [0:DATA_WITH_TIMESTAMP-1] tra_dat_tag;
wire    seq_num_in;
reg     seq_num_q = 1'b 0;
wire    tra_push;
wire    [0:ADDR_WIDTH-1] wradr_in;
wire    [0:ADDR_WIDTH-1] wradrp1;
reg     [0:ADDR_WIDTH-1] wradr_q = 0;
wire    [0:ADDR_WIDTH-1] rdadr_in;
wire    [0:ADDR_WIDTH-1] rdadrp1;
reg     [0:ADDR_WIDTH-1] rdadr_q = 0;
wire    end_of_line_read;
wire    tra_top;
wire    [0:DATA_WITH_TIMESTAMP-1] tra_dat_flw;
wire    [0:ADDR_WIDTH-1] tra_wradr;
wire    [0:DATA_WITH_TIMESTAMP-1] tra_dat_in;
wire    read_this_trace;
wire    tra_rden;
wire    [0:ADDR_WIDTH-1] tra_radr;
reg     [0:DATA_WITH_TIMESTAMP-1] tra_dout = 0;
wire    [0:SEL_WIDTH-1] pline_sel;
wire    [0:SEL_WIDTH-1] pline_sel_next;
reg     [0:SEL_WIDTH-1] pline_sel_q = 0;
wire    [0:(64*(2**SEL_WIDTH))-1] data;

`ifdef use_altera_atts	
(* ramstyle = RAM_OPT *)reg     [0:DATA_WITH_TIMESTAMP-1] r [0:RAM_DEPTH-1];
`else
reg     [0:DATA_WITH_TIMESTAMP-1] r [0:RAM_DEPTH-1];
`endif

wire    [0:ADDR_WIDTH-1] addr_width_ones = {(ADDR_WIDTH){1'b1}};
wire    [0:ADDR_WIDTH-1] addr_width_zeroes = {(ADDR_WIDTH){1'b0}};
wire    [0:ADDR_WIDTH-1] addr_width_one = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
wire    [0:SEL_WIDTH-1] sel_width_zeroes = {(SEL_WIDTH){1'b0}};
wire    [0:SEL_WIDTH-1] sel_width_one = {{(SEL_WIDTH-1){1'b0}}, 1'b1};
wire    [0:DATA_WIDTH-1] data_width_zeroes = {(DATA_WITH_TIMESTAMP){1'b0}};
wire    trace_id_bit0 = ((TRACE_ID == "0x8") || (TRACE_ID == "0x9")  || (TRACE_ID == "0xA")  || (TRACE_ID == "0xB")  || (TRACE_ID == "0xC")  || (TRACE_ID == "0xD")  || (TRACE_ID == "0xE")  || (TRACE_ID == "0xF")) ? 1'b 1 : 1'b 0;
wire    trace_id_bit1 = ((TRACE_ID == "0x4") || (TRACE_ID == "0x5")  || (TRACE_ID == "0x6")  || (TRACE_ID == "0x7")  || (TRACE_ID == "0xC")  || (TRACE_ID == "0xD")  || (TRACE_ID == "0xE")  || (TRACE_ID == "0xF")) ? 1'b 1 : 1'b 0;
wire    trace_id_bit2 = ((TRACE_ID == "0x2") || (TRACE_ID == "0x3")  || (TRACE_ID == "0x6")  || (TRACE_ID == "0x7")  || (TRACE_ID == "0xA")  || (TRACE_ID == "0xB")  || (TRACE_ID == "0xE")  || (TRACE_ID == "0xF")) ? 1'b 1 : 1'b 0;
wire    trace_id_bit3 = ((TRACE_ID == "0x1") || (TRACE_ID == "0x3")  || (TRACE_ID == "0x5")  || (TRACE_ID == "0x7")  || (TRACE_ID == "0x9")  || (TRACE_ID == "0xB")  || (TRACE_ID == "0xD")  || (TRACE_ID == "0xF")) ? 1'b 1 : 1'b 0;

//--------------------------
//--Create a trace statistics file to log which trace arrays are implemented
//-- Use a global variable 'trace_stat_created' to know if we need to open a
//-- new file and append to it or create a new one.
//--------------------------

assign trace_ctl = read_controls[21];
assign flow_mode = flow_mode_in;
assign trace_stopped_in = local_trace_stop | trace_ctl | trace_stopped_q;

//Trace saved at tag address tag with a 40-bit timestamp.
assign tstamp_in = tstamp_q + 40'h 0000_0000_01;

///// Tracefmt is TAG
//Write trace where indicated.
assign tra_dat_tag = {tstamp_q, trace_data_in};
 
///// Tracefmt is Flow
// Keep tracek of address, sequence number
//flip sequence number when the trace array has been filled 
assign seq_num_in = (tra_push & tra_top & ~seq_num_q) | (tra_push & ~tra_top & seq_num_q) | (~tra_push & seq_num_q);

assign tra_push = trace_valid & ~trace_stopped_q;

//Write address into trace array
assign wradrp1 = wradr_q + addr_width_one;
assign wradr_in = (tra_push) ? wradrp1 : wradr_q;

assign tra_top = (wradr_q == addr_width_ones) ? 1'b 1 : 1'b 0;

//Use Sequence number and Timestamp in Trace
assign tra_dat_flw = {seq_num_q, tstamp_q[1:39], trace_data_in};

//Data and Address controls muxed according to tracefmt.
assign tra_wradr = (flow_mode) ? wradr_q : trace_tag;
assign tra_dat_in = (flow_mode) ? tra_dat_flw : tra_dat_tag;

//Trace Array RAM
always @(posedge clk)
   begin : trace_array_ram1
     if(tra_push)
       begin
         r[tra_wradr] <= tra_dat_in;
       end
     if(tra_rden)
       begin
         tra_dout <= r[tra_radr];
       end
   end

//Read the trace array using MMIO.  Walk thru the array for each read request.
//Track read tag internally to walk through the array.
assign end_of_line_read = ((pline_sel_q == READS_PER_LINE) & tra_rden) ? (1'b 1) : (1'b 0);
assign rdadrp1 = (end_of_line_read) ? (rdadr_q + addr_width_one) : (rdadr_q);
assign rdadr_in = (tra_rden) ? rdadrp1 : rdadr_q;
assign tra_radr = rdadr_in;

//IF the trace is >64bits, it takes multiple reads per line.
assign read_this_trace = (read_controls[17] == trace_id_bit0) & (read_controls[18] == trace_id_bit1) & (read_controls[19] == trace_id_bit2) & (read_controls[20] == trace_id_bit3) & trace_rvalid;
assign tra_rden = read_this_trace;

//Track line position internally and reset when moving to next array line
assign pline_sel_next = (pline_sel_q == READS_PER_LINE) ? sel_width_one : (pline_sel_q + sel_width_one);
assign pline_sel = (tra_rden) ? pline_sel_next : pline_sel_q;

//input to mux for data out.
//First 64 bits are all 0's for select bits equal to all 0's. signal is padded with 0's at the end.
assign data  = {64'h 00000000_00000000, tra_dout, {((64*(2**SEL_WIDTH))-DATA_WITH_TIMESTAMP_AND_ZEROES){1'b0}}};

//DATA_IN_WIDTH parameter to mux should always be a multiple of 64 bits.
trace_array_muxout_template #(
   .DATA_IN_WIDTH((64*(2**SEL_WIDTH)))
  )
  mux1 (
   .data(data),
   .sel(pline_sel_q),
   .data_out(trace_data_out)
  );

//Flip flops
always @(posedge clk)
  begin : reg_1
     if(reset)begin
     trace_stopped_q <= 1'b 0;
     tstamp_q <= 40'h 0000000000;
     seq_num_q <= 1'b 0;
     wradr_q <= addr_width_zeroes;
     rdadr_q <= addr_width_zeroes;
     pline_sel_q <= sel_width_zeroes;
     trace_data_ack_out <= 1'b 0;
     end
     else begin
     trace_stopped_q <= trace_stopped_in;
     tstamp_q <= tstamp_in;
     seq_num_q <= seq_num_in;
     wradr_q <= wradr_in;
     rdadr_q <= rdadr_in;
     pline_sel_q <= pline_sel;
     trace_data_ack_out <= read_this_trace;
     end
   end

endmodule // module trace_array_template
