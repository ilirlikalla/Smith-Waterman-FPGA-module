//   (C) Copyright International Business Machines 2014

module afu (
  // Command interface
  output         ah_cvalid,      // Command valid
  output [0:7]   ah_ctag,        // Command tag
  output         ah_ctagpar,     // Command tag parity
  output [0:12]  ah_com,         // Command code
  output         ah_compar,      // Command code parity
  output [0:2]   ah_cabt,        // Command ABT
  output [0:63]  ah_cea,         // Command address
  output         ah_ceapar,      // Command address parity
  output [0:15]  ah_cch,         // Command context handle
  output [0:11]  ah_csize,       // Command size
  input  [0:7]   ha_croom,       // Command room
  // Buffer interface
  input          ha_brvalid,     // Buffer Read valid
  input  [0:7]   ha_brtag,       // Buffer Read tag
  input          ha_brtagpar,    // Buffer Read tag parity
  input  [0:5]   ha_brad,        // Buffer Read address
  output [0:3]   ah_brlat,       // Buffer Read latency
  output [0:511] ah_brdata,      // Buffer Read data
  output [0:7]   ah_brpar,       // Buffer Read parity
  input          ha_bwvalid,     // Buffer Write valid
  input  [0:7]   ha_bwtag,       // Buffer Write tag
  input          ha_bwtagpar,    // Buffer Write tag parity
  input  [0:5]   ha_bwad,        // Buffer Write address
  input  [0:511] ha_bwdata,      // Buffer Write data
  input  [0:7]   ha_bwpar,       // Buffer Write parity
  // Response interface
  input          ha_rvalid,      // Response valid
  input  [0:7]   ha_rtag,        // Response tag
  input          ha_rtagpar,     // Response tag parity
  input  [0:7]   ha_response,    // Response
  input  [0:8]   ha_rcredits,    // Response credits
  input  [0:1]   ha_rcachestate, // Response cache state
  input  [0:12]  ha_rcachepos,   // Response cache pos
  // MMIO interface
  input          ha_mmval,       // A valid MMIO is present
  input          ha_mmcfg,       // MMIO is AFU descriptor space access
  input          ha_mmrnw,       // 1 = read, 0 = write
  input          ha_mmdw,        // 1 = doubleword, 0 = word
  input  [0:23]  ha_mmad,        // mmio address
  input          ha_mmadpar,     // mmio address parity
  input  [0:63]  ha_mmdata,      // Write data
  input          ha_mmdatapar,   // Write data parity
  output         ah_mmack,       // Write is complete or Read is valid
  output [0:63]  ah_mmdata,      // Read data
  output         ah_mmdatapar,   // Read data parity
  // Control interface
  input          ha_jval,        // Job valid
  input  [0:7]   ha_jcom,        // Job command
  input          ha_jcompar,     // Job command parity
  input  [0:63]  ha_jea,         // Job address
  input          ha_jeapar,      // Job address parity
  output         ah_jrunning,    // Job running
  output         ah_jdone,       // Job done
  output         ah_jcack,       // Acknowledge completion of LLCMD
  output [0:63]  ah_jerror,      // Job error
  output         ah_jyield,      // Job yield
  output         ah_tbreq,       // Timebase command request
  output         ah_paren,       // Parity enable
  input          ha_pclock       // clock
);

  // Internal wire
  wire           reset;
  wire           done;
  wire [0:1]     mmio_parity_err;
  wire [0:3]     dma_parity_err;
  wire [0:6]     dma_resp_err;
  wire [0:12]    detect_err;
  wire           misc_ready;
  wire           misc_req;
  wire [0:56]    misc_addr;
  wire [0:12]    misc_com;
  wire [0:1023]  misc_wr_data;
  wire [0:1023]  misc_rd_data;
  wire           read_ready;
  wire           read_req;
  wire [0:63]    read_addr;
  wire [0:63]    read_size;
  wire           read_data_ready;
  wire           write_ready;
  wire           write_req;
  wire [0:63]    write_addr;
  wire [0:63]    write_size;
  wire           write_data_ready;
  //wire [0:511]   data; // removed by ilir
  //wire           data_ack; // removed by ilir
  wire           odd_parity;
  wire           done_premmio;
  wire           done_postmmio;
  wire           start_premmio;
  wire           start_postmmio;

  //Internal signal names
  wire         ah_cvalid_int;      // Command valid
  wire [0:7]   ah_ctag_int;        // Command tag
  wire         ah_ctagpar_int;     // Command tag parity
  wire [0:12]  ah_com_int;         // Command code
  wire         ah_compar_int;      // Command code parity
  wire [0:2]   ah_cabt_int;        // Command ABT
  wire [0:63]  ah_cea_int;         // Command address
  wire         ah_ceapar_int;      // Command address parity
  wire [0:15]  ah_cch_int;         // Command context handle
  wire [0:11]  ah_csize_int;       // Command size

  wire         ah_jrunning_int;    // Job running
  wire         ah_jdone_int;       // Job done
  wire [0:63]  ah_jerror_int;      // Job error

  //Command Interface trace array signals
  wire         command_trace_val;
  wire [0:7]   command_trace_wtag;
  wire [0:119] command_trace_wdata;

  wire         jcontrol_trace_val;
  wire [0:140] jcontrol_trace_wdata;




// ============== START of sample logic SIGNALS ===================
  // Job.v signals:
	wire little_endian;
  // DMA signals:
  wire [0:511] sequence_data;	
  reg read_ack;
  reg write_data_ack;
  reg [0:511] write_data_out;
  
 
// =============== END of sample logic SIGNALS ====================


  // Move data whenever both read and write ports are data ready
  //assign data_ack = read_data_ready && write_data_ready; // removed by ilir

  assign ah_paren = 1'b1;   // Enable parity
  assign odd_parity = 1'b1; // Odd parity
  assign ah_jcack = 1'b0;   // Dedicated mode AFU, LLCMD not supported
  assign ah_jyield = 1'b0;   // Job yield not usedww
  assign ah_tbreq = 1'b0;   // Timebase request not used

  assign detect_err = {mmio_parity_err, dma_parity_err, dma_resp_err};

  mmio m0 (
    .ha_mmval(ha_mmval),
    .ha_mmcfg(ha_mmcfg),
    .ha_mmrnw(ha_mmrnw),
    .ha_mmdw(ha_mmdw),
    .ha_mmad(ha_mmad),
    .ha_mmadpar(ha_mmadpar),
    .ha_mmdata(ha_mmdata),
    .ha_mmdatapar(ha_mmdatapar),
    .ah_mmack(ah_mmack),
    .ah_mmdata(ah_mmdata),
    .ah_mmdatapar(ah_mmdatapar),
    .parity_error(mmio_parity_err),
    .odd_parity(odd_parity),
    .reset(reset),
    .ha_pclock(ha_pclock),
    .command_trace_val(command_trace_val),
    .command_trace_wtag(command_trace_wtag),
    .command_trace_wdata(command_trace_wdata),
    .response_trace_val(ha_rvalid),
    .response_trace_wtag(ha_rtag),
    .response_trace_wdata({ha_rvalid, ha_rtag, ha_rtagpar, ha_response, ha_rcredits, ha_rcachestate, ha_rcachepos}),
    .jcontrol_trace_val(jcontrol_trace_val),
    .jcontrol_trace_wdata(jcontrol_trace_wdata),
    .done_premmio(done_premmio),
    .done_postmmio(done_postmmio),
    .start_premmio(start_premmio),
    .start_postmmio(start_postmmio)
  );

  job j0 (
    .ha_jval(ha_jval),
    .ha_jcom(ha_jcom),
    .ha_jcompar(ha_jcompar),
    .ha_jea(ha_jea),
    .ha_jeapar(ha_jeapar),
    .ah_jrunning(ah_jrunning_int),
    .ah_jdone(ah_jdone_int),
    .ah_jerror(ah_jerror_int),
    .ha_pclock(ha_pclock),
    .misc_ready(misc_ready),
    .misc_req(misc_req),
    .misc_addr(misc_addr),
    .misc_com(misc_com),
    .misc_wr_data(misc_wr_data),
    .misc_rd_data(misc_rd_data),
    .read_ready(read_ready),
    .read_req(read_req),
    .read_addr(read_addr),
    .read_size(read_size),
    .write_ready(write_ready),
    .write_req(write_req),
    .write_addr(write_addr),
    .write_size(write_size),
    .reset(reset),
    .done(done),
    .odd_parity(odd_parity),
    .detect_err(detect_err),
    .done_premmio(done_premmio),
    .done_postmmio(done_postmmio),
    .start_premmio(start_premmio),
    .start_postmmio(start_postmmio),
		.endianess(little_endian)
  );

   reg 		 ha_rvalid_l;
   reg [0:7] 	 ha_rtag_l;
   reg 		 ha_rtagpar_l;
   reg [0:7] 	 ha_response_l;
   reg [0:8] 	 ha_rcredits_l;

   
   always @ (posedge ha_pclock)
      ha_rvalid_l <= ha_rvalid;

   always @ (posedge ha_pclock)
      ha_rtag_l <= ha_rtag;

   always @ (posedge ha_pclock)
      ha_rtagpar_l <= ha_rtagpar;

   always @ (posedge ha_pclock)
      ha_response_l <= ha_response;
   
   always @ (posedge ha_pclock)
      ha_rcredits_l <= ha_rcredits;
   

  dma d0 (
    .misc_ready(misc_ready),
    .misc_req(misc_req),
    .misc_ch(16'h0),
    .misc_addr(misc_addr),
    .misc_com(misc_com),
    .misc_wr_data(misc_wr_data),
    .misc_rd_data(misc_rd_data),
    .read_ready(read_ready),
    .read_req(read_req),
    .read_ch(16'h0),
    .read_addr(read_addr),
    .read_size(read_size),
    .read_data_ready(read_data_ready),
    .read_data(sequence_data),			  // disconnected! 'data' was wired here 
    .read_data_ack(read_ack),	        // disconnected! 'data_ack' was wired here
    .write_ready(write_ready),
    .write_req(write_req),
    .write_ch(16'h0),
    .write_addr(write_addr),
    .write_size(write_size),
    .write_data_ready(write_data_ready),
    .write_data(write_data_out),			  // disconnected! 'data' was wired here 
    .write_data_ack(write_data_ack),	        // disconnected! 'data_ack' was wired here
    .reset(reset),
    .odd_parity(odd_parity),
    .idle(done),
    .parity_err(dma_parity_err),
    .resp_err(dma_resp_err),
    .ah_cvalid(ah_cvalid_int),
    .ah_ctag(ah_ctag_int),
    .ah_ctagpar(ah_ctagpar_int),
    .ah_com(ah_com_int),
    .ah_compar(ah_compar_int),
    .ah_cabt(ah_cabt_int),
    .ah_cea(ah_cea_int),
    .ah_ceapar(ah_ceapar_int),
    .ah_cch(ah_cch_int),
    .ah_csize(ah_csize_int),
    .ha_croom(ha_croom),
    .ha_brvalid(ha_brvalid),
    .ha_brtag(ha_brtag),
    .ha_brtagpar(ha_brtagpar),
    .ha_brad(ha_brad),
    .ah_brlat(ah_brlat),
    .ah_brdata(ah_brdata),
    .ah_brpar(ah_brpar),
    .ha_bwvalid(ha_bwvalid),
    .ha_bwtag(ha_bwtag),
    .ha_bwtagpar(ha_bwtagpar),
    .ha_bwad(ha_bwad),
    .ha_bwdata(ha_bwdata),
    .ha_bwpar(ha_bwpar),
    .ha_rvalid(ha_rvalid_l),
    .ha_rtag(ha_rtag_l),
    .ha_rtagpar(ha_rtagpar_l),
    .ha_response(ha_response_l),
    .ha_rcredits(ha_rcredits_l),
    .ha_pclock(ha_pclock)
  );

// ============== START of sample logic ==========================
   
  // ---- signals: ------ 
   // sequence descriptor signals:
  reg [463:0]	seq_reg [0:1];		// two registers of 232 bases each
  reg [15:0]	seq_length [0:1];	// holds sequence lengths
  reg index_s;									// register index
	wire [0:15] length_w;				
	wire [0:463] sequence_w;
  
   
  // control signals:
  reg enable_s; 								// enables scoring module
  reg enable_c;                 // enables base counter
  wire valid_s;  								// valid from scoring module
  wire [0:11] result_s;         // scoring module output
  
  reg [0:11] result_r;
  reg [15:0] base_cnt;
  
  // FSM signals:
  reg [0:3]	scoring_state;
  
	// **** sc_st_xxxx => scoring_state_xxxx ****
  parameter sc_st_idle = 4'b1000, 
   			sc_st_read_seq = 4'b0100, 
	     sc_st_calculate = 4'b0010,
    sc_st_write_result = 4'b0001;
      			
  // ---- end of signals ----
  
  
	ScoringModule
	#(
	.SCORE_WIDTH(12),		// result width in bits
	.LENGTH(128),				// number of processing elements in the systolic array
	.LOG_LENGTH(),			// processing element addressing width
	._A(),        			// nucleotide "A" encoding
	._G(),        			// nucleotide "G" encoding
	._T(),        			// nucleotide "T" encoding
	._C(),        			// nucleotide "C" encoding
	.ZERO() 						// $realtobits(2**SCORE_WIDTH) // value of the biased zero, bias= 2 ^ SCORE_WIDTH	
	) DUT(
	// inputs:
	.clk(ha_pclock),
	.rst(~reset), 			// active low 
	.en_in(enable_s),
	.data_in(seq_reg[1][1:0]), 				// target bases go in here ** to be set
	.query(seq_reg[0]),  					// query goes here ** to be set 
	.match(5),					// match penalty
	.mismatch(-4),			// mismatch penalty
	.gap_open(-12),			// opening a new gap penalty 
	.gap_extend(-4 ), 	// extending gap length penalty 
	.output_select(seq_length[1]),	// select lines for output multiplexer ** to be set 
	// outputs: 
	.result(result_s), 	// Smith-waterman result
	.vld(valid_s)
	);

	// ------ State machine: --------

  // ---- sequential part: ----
  always@(posedge ha_pclock)
		begin: STATE_SEQUENTIAL
			if (reset) 
			begin
				result_r <= 16'd0;
				index_s <= 1'b0;
				scoring_state <= 4'b1000;
			end 
			else begin
				case(scoring_state)

					sc_st_idle: // stays idle
							if(read_req) // proceed to next state
								scoring_state <= sc_st_read_seq;

					sc_st_read_seq: // waits for sequences from dma.v
							begin
								if(read_ready)// jump to next state 
								begin
									scoring_state <= sc_st_calculate;
								end 
								else begin // decode sequence data
									if(read_data_ready) 
				 					begin
										seq_reg[index_s] <= sequence_w; // get sequence bases !X!
										seq_length[index_s] <= length_w; // get sequenece length !X!
										index_s <= ~ index_s; // increment register index (data is read in order from dma.v)
									end
								end
							end
				
					sc_st_calculate:  // starts the scoring module to do the calculation
							begin
								if(valid_s) // store result and jump to next state
								begin
									result_r <= result_s; // store result
									scoring_state <= sc_st_write_result;
								end
								else begin
									seq_reg[1][463:0] <= {2'b00,seq_reg[1][463:2]}; // feed bases to scoring module, by shifting out the sequence !X!
								end
							end  
					sc_st_write_result: // send result and wait for it to be written by dma.v
								if(write_ready) // jump to idle state
									scoring_state <= sc_st_idle;
				
					default: scoring_state <= 4'b1000; // jump to 'safe' state
				endcase
			end
		end
    
   // ---- combinational part: ----
	always@*
		begin: STATE_COMBINATIONAL
			// avoid latching:
			enable_s = 1'b0;
			enable_c = 1'b0;
			read_ack = 1'b0;
			write_data_out = 512'd0;
			write_data_ack = 1'b0;
			case(scoring_state)

				//sc_st_idle:
						// ... do nothing 

				sc_st_read_seq:
							if(read_data_ready) 
								read_ack <= 1'b1; // send acknowledge
				
				sc_st_calculate:
						begin
							enable_c = 1'b1;	// enable base counter
							if(base_cnt == seq_length[1]) // if all the sequence has been feed to the scoring module
							begin
								enable_s = 1'b0;	// stop the module 
								enable_c = 1'b0;  // stop the base counter !X!
							end
						 	else
								enable_s = 1'b1; // send enable to scoring module 
							
						end 
				sc_st_write_result:
						if(write_data_ready)
						begin
							write_data_out= {500'd0,result_r}; // send result to dma.v write bus
							write_data_ack=1'b1;  // send write acknowledge
						end
						
				//default: // do nothing 
			endcase
		end

	// ---- base counter: ----
	always@(posedge ha_pclock)
	if(reset | valid_s)
		base_cnt <= 16'd0;
	else if( enable_c)
		base_cnt <= base_cnt + 1;
	
	// ---- fix endianess of sequence_data: ----
		endian_swap #(
		.BYTES(2)
	) endian_length (
		.data_in(sequence_data[32:47]),
		.little_endian(little_endian),
		.data_out(length_w)
	);

	endian_swap #(
		.BYTES(58)
	) endian_sequence (
		.data_in(sequence_data[48:511]),
		.little_endian(little_endian),
		.data_out(sequence_w)
	);



// ============+=== END of sample logic ==========================

   assign ah_cvalid = ah_cvalid_int;      // Command valid
   assign ah_ctag = ah_ctag_int;        // Command tag
   assign ah_ctagpar = ah_ctagpar_int;     // Command tag parity
   assign ah_com = ah_com_int;         // Command code
   assign ah_compar = ah_compar_int;      // Command code parity
   assign ah_cabt = ah_cabt_int;        // Command ABT
   assign ah_cea = ah_cea_int;         // Command address
   assign ah_ceapar = ah_ceapar_int;      // Command address parity
   assign ah_cch = ah_cch_int;         // Command context handle
   assign ah_csize = ah_csize_int;       // Command size
   assign ah_jrunning = ah_jrunning_int;
   assign ah_jdone = ah_jdone_int;
   assign ah_jerror = ah_jerror_int;

   assign command_trace_val = ah_cvalid_int;
   assign command_trace_wtag = ah_ctag_int;
   assign command_trace_wdata = {ah_cvalid_int, ah_ctag_int, ah_ctagpar_int, ah_com_int, ah_compar_int, ah_cea_int, ah_ceapar_int, ah_cabt_int, ah_cch_int, ah_csize_int};
   assign jcontrol_trace_val = ha_jval || ah_jdone_int;
   assign jcontrol_trace_wdata = {ha_jval, ha_jcom, ha_jcompar, ha_jea, ha_jeapar, ah_jrunning_int, ah_jdone_int, ah_jerror_int};

endmodule
