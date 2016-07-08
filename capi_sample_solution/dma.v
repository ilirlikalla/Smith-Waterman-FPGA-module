//   (C) Copyright International Business Machines 2014

module dma (
  output          misc_ready,		// Misc. port ready
  input           misc_req,		// Misc. request
  input  [0:15]   misc_ch,              // Misc. context handle
  input  [0:56]   misc_addr,		// Misc. cacheline address
  input  [0:12]   misc_com,		// Misc. command
  input  [0:1023] misc_wr_data,		// Misc. write data
  output [0:1023] misc_rd_data,		// Misc. read data
  output          read_ready,		// Read port ready
  input           read_req,		// Read request
  input  [0:15]   read_ch,              // Read context handle
  input  [0:63]   read_addr,		// Read cacheline address
  input  [0:63]   read_size,		// Read bytes to read
  output          read_data_ready,	// Read data ready
  output [0:511]  read_data,		// Read read data
  input           read_data_ack,	// Read data acknowledge
  output          write_ready,		// Write port ready
  input           write_req,		// Write request
  input  [0:15]   write_ch,             // Write context handle
  input  [0:63]   write_addr,		// Write cacheline address
  input  [0:63]   write_size,		// Write bytes to write
  output          write_data_ready,	// Write data ready
  input  [0:511]  write_data,		// Write write data
  input           write_data_ack,	// Write data acknowledge
  input           reset,
  input           odd_parity,
  output          idle,
  output [0:3]    parity_err,
  output [0:6]    resp_err,
  output          ah_cvalid,
  output [0:7]    ah_ctag,
  output          ah_ctagpar,
  output [0:12]   ah_com,
  output          ah_compar,
  output [0:2]    ah_cabt,
  output [0:63]   ah_cea,
  output          ah_ceapar,
  output [0:15]   ah_cch,
  output [0:11]   ah_csize,
  input  [0:7]    ha_croom,
  input           ha_brvalid,
  input  [0:7]    ha_brtag,
  input           ha_brtagpar,
  input  [0:5]    ha_brad,
  output [0:3]    ah_brlat,
  output [0:511]  ah_brdata,
  output [0:7]    ah_brpar,
  input           ha_bwvalid,
  input  [0:7]    ha_bwtag,
  input           ha_bwtagpar,
  input  [0:5]    ha_bwad,
  input  [0:511]  ha_bwdata,
  input  [0:7]    ha_bwpar,
  input           ha_rvalid,
  input  [0:7]    ha_rtag,
  input           ha_rtagpar,
  input  [0:7]    ha_response,
  input  [0:8]    ha_rcredits,
  input           ha_pclock
);

  // Internal signals
  //
  wire          misc_st_idle;		// Misc. port idle
  wire          misc_st_start;		// Misc. port request received
  wire          misc_st_data;		// Misc. port data buffering
  wire          misc_st_request;	// Misc. port to drive command request
  wire          misc_st_response;	// Misc. port awaiting response
  wire          misc_start;		// Misc. port accept request
  wire          misc_write;
  wire          misc_request_ul;
  wire [0:511]  misc_brdata_ul;
  wire          misc_resp;
  wire          misc_write_enable;
  wire          read_st_idle;		// Read port idle
  wire          read_st_request;	// Read port driving requests
  wire          read_st_wait;		// Read port awaiting responses
  wire          read_start;		// Read port accept request
  wire          read_queue;
  wire [0:4]    read_tag;
  wire          read_request_ul;
  wire [0:63]   read_req_addr;
  wire          read_data_move;
  wire          read_data_push;
  wire          read_stage0;
  wire          read_stage4_move;
  wire [0:511]  read_data_stage0;
  wire          read_acknowledge;
  wire          read_write;
  wire          read_done;
  wire          read_resp;
  wire          write_st_idle;		// Write port idle
  wire          write_st_request;	// Write port driving requests
  wire          write_st_wait;		// Write port awaiting responses
  wire          write_start;		// Write port accept request
  wire          write_block;
  wire          write_queue;
  wire          write_store_addr;
  wire          write_store_size;
  wire          write_request_ul;
  wire          write_acknowledge;
  wire          write_idle;
  wire          write_done;
  wire [0:63]   write_req_addr;
  wire [0:7]    write_req_size;
  wire [0:511]  write_brdata;
  wire [0:511]  write_buffer_wr_data;
  wire [0:6]    write_buffer_wr_addr;
  wire [0:6]    write_buffer_rd_addr;
  wire [0:511]  write_buffer_alt_data;
  wire [0:6]    write_buffer_alt_addr;
  wire          write_buffer_wr_enable;
  wire [0:7]    write_size_less1;
  wire [0:7]    write_buffer_par;
  wire [0:7]    write_brpar;
  wire          write_resp;
  wire          write_queued;
  wire [56:63]  write_align_addr;
  wire          resp_done;
  wire          resp_aerror;
  wire          resp_derror;
  wire          resp_nlock;
  wire          resp_nres;
  wire          resp_flushed;
  wire          resp_fault;
  wire          resp_failed;
  wire          resp_paged;
  wire          resp_context;
  wire          resp_dead;
  wire          resp_retry;
  wire [0:7]    bwpar_ul;
  wire          ctagpar_ul;
  wire          compar_ul;
  wire          ceapar_ul;
  wire          brtagpar_ul;
  wire          bwtagpar_ul;
  wire          rtagpar_ul;
  wire          restart_request;
  wire [0:3]    parity_err_ul;
  wire [0:2]    misc_tag_prefix;
  wire [0:2]    write_tag_prefix;
  wire [0:2]    read_tag_prefix;

  reg  [0:4]    misc_state;
  reg  [0:15]   misc_ch_l;
  reg  [0:56]   misc_addr_l;
  reg  [0:12]   misc_com_l;
  reg  [0:511]  misc_rdata0;
  reg  [0:511]  misc_rdata1;
  reg  [0:511]  misc_wdata0;
  reg  [0:511]  misc_wdata1;
  reg           misc_half;
  reg           misc_request;
  reg           read_request;
  reg  [0:2]    read_state;
  reg  [0:15]   read_ch_l;
  reg  [0:63]   read_addr_l;
  reg  [0:63]   read_size_l;
  reg  [0:5]    read_deliver;
  reg  [0:63]   read_deliver_bytes;
  wire [0:31]   read_deliver_bytes_portion; //rblack added for timing
  reg  [0:31]   read_valid;
  reg  [0:31]   read_pending;
  reg  [0:31]   read_waiting;
  reg  [0:511]  read_data_stage1;
  reg  [0:511]  read_data_stage2;
  reg  [0:511]  read_data_stage3;
  reg  [0:511]  read_data_stage4;
  reg           read_stage0_valid;
  reg           read_stage1_valid;
  reg           read_stage2_valid;
  reg           read_stage3_valid;
  reg           read_stage4_valid;
  reg  [0:4]    read_index;
  reg  [0:4]    read_index_l;
  reg  [0:511]  bwdata_l;
  reg  [0:7]    ha_bwpar_l;
  reg  [0:7]    bwpar_l;
  reg           write_request;
  reg           write_start_l;
  reg  [0:2]    write_state;
  reg  [0:15]   write_ch_l;
  reg  [0:63]   write_addr_l;
  reg  [0:63]   write_size_l;
  wire [0:31]   write_size_add_portion; //rblack added for timing
  reg  [0:6]    write_bytes;
  reg  [0:7]    write_bytes_cl;
  reg  [0:7]    write_bytes_cl_l;
  reg  [0:63]   write_pending_addr;
  reg  [0:63]   write_pending_bytes;
  wire [0:31]   write_pending_bytes_portion1; //rblack added for timing
  wire [0:31]   write_pending_bytes_portion2; //rblack added for timing
  wire [0:31]   write_pending_bytes_portion3; //rblack added for timing
  reg  [0:63]   write_deliver_bytes;
  wire [0:31]   write_deliver_bytes_portion; //rblack added for timing
  reg  [0:31]   write_valid_addr;
  reg  [0:31]   write_valid_size;
  reg  [0:31]   write_waiting;
  reg           write_stage0_valid;
  reg           write_stage1_valid;
  reg           write_stage2_valid;
  reg           write_stage3_valid;
  reg  [0:511]  write_data_stage0;
  reg  [0:511]  write_data_stage2;
  reg  [0:511]  write_data_stage3;
  reg  [0:63]   write_addr_stage2;
  reg  [0:63]   write_addr_stage3;
  reg  [0:5]    write_tag_stage3;
  reg  [0:7]    write_size_stage2;
  reg  [0:7]    write_size_stage3;
  reg  [0:4]    write_index;
  reg  [0:4]    write_index_l;
  reg           cvalid;
  reg           cvalid_l;
  reg  [0:15]   cch;
  reg  [0:15]   cch_l;
  reg  [0:7]    credits;
  reg  [0:7]    ctag;
  reg  [0:7]    ctag_l;
  reg           ctagpar_l;
  reg  [0:11]   csize;
  reg  [0:11]   csize_l;
  reg  [0:12]   com;
  reg  [0:12]   com_l;
  reg           compar_l;
  reg  [0:63]   cea;
  reg  [0:63]   cea_l;
  reg           ceapar_l;
  reg  [0:7]    brtag_l;
  reg  [0:7]    bwtag_l;
  reg  [0:7]    rtag_l;
  reg           brtagpar_l;
  reg           bwtagpar_l;
  reg           rtagpar_l;
  reg  [0:6]    resp_error;
  reg           restart_pending;
  reg  [0:3]    parity_err_l;
  reg           restart_request_l;
  reg [0:511]   write_brdata_l;
  reg [0:7]     write_brpar_l;
  reg           ha_bwvalid_l;
  reg [0:511]   write_buffer_wr_data_l;
  reg [0:6]     write_buffer_wr_addr_l;
  reg           write_buffer_wr_enable_l;

////////////////////////////////////////////////////////////////////////////
//Logic affecting all of the dma engine.
////////////////////////////////////////////////////////////////////////////

//idle/done signal. dma is idle/done when all 3 sub state machines are done.
  assign idle = misc_st_idle && read_st_idle && write_st_idle;

////////////////////////////////////////////////////////////////////////////
//Credit Tracking Logic
////////////////////////////////////////////////////////////////////////////

//Any afu must track credits from psl.
//ha_croom gives initial sample of maximum credit and can be sampled during
//afu reset. Any command issued means 1 less credit. ha_rvalid normally means
//1 returned credit. Issuing a command and getting a return in the same cycle
//normally nullfies to no change in credit.
  always @ (posedge ha_pclock) begin
    if (reset)
      credits <= ha_croom;
    else if ((misc_request || write_request || read_request
              || restart_request) && !ha_rvalid)
      credits <= credits-8'h01;
    else if (ha_rvalid) begin
      if (!(misc_request || write_request || read_request ||
            restart_request))
        begin
        if (ha_rcredits[0])
          credits <= credits-(~ha_rcredits[1:8]+8'h01);
        else
          credits <= credits+ha_rcredits[1:8];
      end
      else begin
        if (ha_rcredits[0])
          credits <= credits-(~ha_rcredits[1:8]);
        else
          credits <= credits+ha_rcredits[1:8]-8'h01;
      end
    end
  end

////////////////////////////////////////////////////////////////////////////
//Response Interface logic
////////////////////////////////////////////////////////////////////////////

//A done response means command issued with a given tag completed
//successfully. Please refer to hdk documentation of psl response interface
//for meaning of all other response types.
  assign resp_done = ha_rvalid && (ha_response==8'h00);
  assign resp_aerror = ha_rvalid && (ha_response==8'h01);
  assign resp_derror = ha_rvalid && (ha_response==8'h03);
  assign resp_nlock = ha_rvalid && (ha_response==8'h04);
  assign resp_nres = ha_rvalid && (ha_response==8'h05);
  assign resp_flushed = ha_rvalid && (ha_response==8'h06);
  assign resp_fault = ha_rvalid && (ha_response==8'h07);
  assign resp_failed = ha_rvalid && (ha_response==8'h08);
  assign resp_paged = ha_rvalid && (ha_response==8'h0a);
  assign resp_context = ha_rvalid && (ha_response==8'h0b);

  // Deal with not "done" responses. Not ever expecting most response codes,
  // so afu should signal error if these occur. Never asked for reservation or
  // lock, so nres/nlock shouldn't happen. Failed is normally response to bad
  // parity or unsupported command type. Most others mean something went wrong
  // during address translation.
  assign resp_dead = resp_aerror || resp_derror || resp_nres || resp_fault ||
                     resp_failed || resp_context || resp_nlock;
  //Paged means O/S requested afu to continue. Should issue restart command if this is
  //the case. Flushed is not necessarily result of bad command, usually means
  //bad command occurred earlier in time.
  assign resp_retry = resp_flushed || resp_paged;

  // Capture first resp failure
  always @ (posedge ha_pclock) begin
    if (reset)
      resp_error <= 0;
    else if (resp_dead && (resp_error==0))
      resp_error <= {resp_aerror, resp_derror, resp_nlock, resp_nres,
                     resp_fault, resp_failed, resp_context};
  end

  assign resp_err = resp_error;

  //256 command tags possible. Reserving 32 for misc commands (restart command
  //and wed commands), 32 for copy engine reads, and 32 for copy engine
  //writes. Remaining tags never used.
  assign misc_tag_prefix = 3'b000;
  assign write_tag_prefix = 3'b001;
  assign read_tag_prefix = 3'b010;

  assign misc_resp = ha_rvalid && (ha_rtag[0:2]==misc_tag_prefix);
  assign read_resp = ha_rvalid && (ha_rtag[0:2]==read_tag_prefix);
  assign write_resp = ha_rvalid && (ha_rtag[0:2]==write_tag_prefix);

////////////////////////////////////////////////////////////////////////////
//Command Source:Restart Commands
////////////////////////////////////////////////////////////////////////////

  //Paged Response kicks off restart. Next response that gets a done status
  //indicates restart completed, any other command would get a flushed
  //response.
  always @ (posedge ha_pclock) begin
    if (reset || (restart_request_l && resp_done))
      restart_pending <= 0;
    else if (resp_paged)
      restart_pending <= 1;
  end

  //Command arbitration. Restart command will be issued to psl when this is asserted,
  //directly drives command interface.
  assign restart_request = restart_pending && !restart_request_l &&
                           !read_request && !write_request && !misc_request &&
                            !(misc_st_response ||
                            |(read_pending) || |(write_waiting));

  //Done response won't come again after a paged response until restart
  //command is finished.
  always @ (posedge ha_pclock) begin
    if (reset || (restart_request_l && resp_done))
      restart_request_l <= 1'b0;
    else if (restart_request)
      restart_request_l <= 1'b1;
  end

////////////////////////////////////////////////////////////////////////////
//Command Source:Miscellaneous State Machine/Port
////////////////////////////////////////////////////////////////////////////

//Only Miscellaneous commands issued are read and write of wed before copy
//funciton and write after copy function has been performed.

//State machine
//Next state =
//idle: when afu is in reset or current state is response state and got a misc
//done response with done response code
//start: when in idle state and job unit requests wed operation. 1 cycle state.
//data: 1 cycle after start state
//request: data state and wed command not queued in write queue. or in
//response state and retrying command.
//response: request state and request is being sent to psl
  always @ (posedge ha_pclock) begin
    if (reset)
      misc_state <= 'b10000; // misc_st_idle
    else if (misc_st_idle && misc_req)
      misc_state <= 'b01000; // misc_st_start
    else if (misc_st_start)
      misc_state <= 'b00100; // misc_st_data
    else if (misc_st_data && misc_write_enable && misc_half)
      misc_state <= 'b00010; // misc_st_request
    else if (misc_st_request && misc_request_ul)
      misc_state <= 'b00001; // misc_st_response
    else if (misc_st_response && misc_resp && resp_retry)
      misc_state <= 'b00010; // misc_st_request
    else if (misc_st_response && misc_resp && resp_done)
      misc_state <= 'b10000; // misc_st_idle
  end

//Decode state machine bits
  assign misc_st_idle = misc_state[0];
  assign misc_st_start = misc_state[1];
  assign misc_st_data = misc_state[2];
  assign misc_st_request = misc_state[3];
  assign misc_st_response = misc_state[4];

//Control signals based on misc state machine
  assign misc_ready = misc_st_idle;
  assign misc_start = misc_st_idle && misc_req;
  assign misc_write_enable = misc_st_data && !write_stage3_valid;

//Command arbitration. Wed request given high priority. As long as there is
//credit and no pending restart, it will issue while other commands wait.
  assign misc_request_ul = |credits && misc_st_request &&
                           !restart_pending;

  always @ (posedge ha_pclock)
    misc_request <= misc_request_ul;

  always @ (posedge ha_pclock) begin
    if (misc_req) begin
      misc_wdata0 <= misc_wr_data[0:511];
      misc_wdata1 <= misc_wr_data[512:1023];
    end
  end

  always @ (posedge ha_pclock) begin
    if (misc_req)
      misc_half <= 1'b0;
    else if (misc_write_enable)
      misc_half <= ~misc_half;
  end

  assign misc_brdata_ul = misc_half ? misc_wdata1 : misc_wdata0;

//Misc command generation
  always @ (posedge ha_pclock) begin
    if (misc_start)
      misc_addr_l <= misc_addr;
  end

  always @ (posedge ha_pclock) begin
    if (misc_start)
      misc_com_l <= misc_com;
  end

  always @ (posedge ha_pclock) begin
    if (misc_start)
      misc_ch_l <= misc_ch;
  end

  assign misc_write = ha_bwvalid && (ha_bwtag[0:2]==misc_tag_prefix);

  always @ (posedge ha_pclock) begin
    if (misc_write ) begin
      misc_rdata1 <= ha_bwdata;
      misc_rdata0 <= misc_rdata1;
    end
  end

  assign misc_rd_data = {misc_rdata0, misc_rdata1};


////////////////////////////////////////////////////////////////////////////
//Command Source:Read Copy Data State Machine/Port
////////////////////////////////////////////////////////////////////////////

//State Machine
//Next state = 
//idle: when afu is reset or all read commands have successfully completed
//request: when job module tells state machine to start reading.
//wait: when no commands are left to queue in read buffer and all commands
//have completed from psl with done status
  always @ (posedge ha_pclock) begin
    if (reset)
      read_state <= 3'b100; // read_st_idle
    else if (read_st_idle && read_req)
      read_state <= 3'b010; // read_st_request
    else if (read_st_request && !(|read_size_l) && !(|read_valid))
      read_state <= 3'b001; // read_st_wait
    else if (read_done)
      read_state <= 3'b100; // read_st_idle
  end

//Decode state machine bits
  assign read_st_idle = read_state[0];
  assign read_st_request = read_state[1];
  assign read_st_wait = read_state[2];

//Control signals based on state machine states
  assign read_ready = read_st_idle;
  assign read_start = read_st_idle && read_req;
  assign read_done = read_st_wait && !(|read_deliver_bytes);

//Context handle is always 0 for dedicated mode afu.
  always @ (posedge ha_pclock) begin
    if (read_start)
      read_ch_l <= read_ch;
  end


//When state machine starts, sample starting 'From' effective address.
//Add cacheline every time address gets queued in read command buffer.
  always @ (posedge ha_pclock) begin
    if (read_start)
      read_addr_l <= read_addr;
    else if (read_queue)
        read_addr_l <= read_addr_l + 64'h0000_0000_0000_0080;
  end

//Sample number of cachlines to copy when start is received. Anytime command
//is queued, subtract one cacheline from remaining total.
  always @ (posedge ha_pclock) begin
    if (read_start)
      read_size_l <= read_size;
    else if (read_queue)
      read_size_l <= read_size_l - 64'h0000_0000_0000_0080;
  end

//Queue read command when there is still a command left to queue (size isn't
//0), in request state, prior read in same buffer index already completed.
  assign read_queue = read_st_request && !read_valid[read_tag] && |read_size_l
                      && !(read_request && (read_tag==read_index));
//Normally an afu would have more rigorous tag tacking logic. tag is decided
//by index into buffer for this afu.
  assign read_tag = read_addr_l[52:56];

//Queue of read commands. Since the only variable in the read commands is
//address, that's the only thing that needs queued. Command code, size, cabt,
//cch are constants; parity can be calculated on the fly in one cycle; and tag
//is based on index into buffer.
  ram #(
    .WIDTH(64),
    .DEPTH(32)
  ) ram_rd_addr (
    .clk(ha_pclock),
    .wrad(read_tag),
    .d(read_addr_l),
    .we(read_queue),
    .rdad(read_index),
    .q(read_req_addr)
  );

//Command arbitration. Following logic gives read commands lowest priority of
//4 possible sources. Pending restart will not allow read request, write
//request won't allow read request, and misc request won't allow read request.
  assign read_request_ul = |credits && !write_request_ul &&
                           !restart_pending && !misc_request_ul &&
                           read_valid[read_index] &&
                           !(read_pending[read_index] ||
                             read_waiting[read_index]);

  always @ (posedge ha_pclock)
    read_request <= read_request_ul;

//Index to read from read command buffer. At start, select index where first
//command will get queued.
  always @ (posedge ha_pclock) begin
    if (reset)
      read_index <= 5'b0;
    else if (read_start)
      read_index <= read_addr[52:56];
    else if (!(|read_valid) && read_queue)
      read_index <= read_addr_l[52:56];
    else if (read_request_ul || (|read_valid && !read_valid[read_index]))
      read_index <= read_index+5'b00001;
  end

  always @ (posedge ha_pclock) begin
    if (read_request_ul)
      read_index_l <= read_index;
  end


//Set read valid status bit when queued into buffer. valid bit only set to
//0 when same tagged command completes with a Done response.
  genvar rvtag;
  generate
    for (rvtag = 0; rvtag < 32; rvtag = rvtag + 1) begin: gen_rd_valid
      always @ (posedge ha_pclock) begin
        if (reset)
          read_valid[rvtag] <= 1'b0;
        else if (read_queue && (rvtag==read_tag))
          read_valid[rvtag] <= 1'b1;
        else if (read_resp && resp_done && (rvtag==ha_rtag[3:7]))
          read_valid[rvtag] <= 1'b0;
      end
    end
  endgenerate

/*
//Set read pending status bit when issuing command to psl, deassert when any
//psl response corresponding to a read tag is received.
*/
  genvar rptag;
  generate
    for (rptag = 0; rptag < 32; rptag = rptag + 1) begin: gen_rd_pending
      always @ (posedge ha_pclock) begin
        if (reset || (read_resp && (rptag==ha_rtag[3:7])))
          read_pending[rptag] <= 1'b0;
        else if (read_request && (rptag==read_index_l))
          read_pending[rptag] <= 1'b1;
      end
    end
  endgenerate

//Set read waiting status bits when read data is received from psl. Deassert
//when delivering data to write pipeline.
  genvar rwindex;
  generate
    for (rwindex = 0; rwindex < 32; rwindex = rwindex + 1) begin: gen_rd_waiting
      always @ (posedge ha_pclock) begin
        if (reset || read_start)
          read_waiting[rwindex] <= 1'b0;
        else if (read_resp && resp_done && (rwindex==ha_rtag[3:7]))
          read_waiting[rwindex] <= 1'b1;
        else if (read_stage0 && (rwindex==read_deliver[0:4]) && read_deliver[5])
          read_waiting[rwindex] <= 1'b0;
      end
    end
  endgenerate

////////////////////////////////////////////////////////////////////////////
//Read Data pipeline. Logic overseeing delivery to write pipeline.
////////////////////////////////////////////////////////////////////////////

//Copy data is coming in from psl
  assign read_write = ha_bwvalid && (ha_bwtag[0:2]==read_tag_prefix);

//Read data queue. Push in all valid copy data.
  ram #(
    .WIDTH(512),
    .DEPTH(64)
  ) ram_rd_data (
    .clk(ha_pclock),
    .wrad({ha_bwtag[3:7],ha_bwad[5]}),
    .d(ha_bwdata),
    .we(read_write),
    .rdad(read_deliver),
    .q(read_data_stage0)
  );

//Deliver half cacheline at a time. start at half cacheline address sampled at
//start of read job. Increment by 1 when movded into pipeline.
  always @ (posedge ha_pclock) begin
    if (read_start)
      read_deliver <= read_addr[52:57];
    else if (read_stage0)
      read_deliver <= read_deliver+6'b000001;
  end

  assign read_data_move = (!(read_stage2_valid || read_stage3_valid) ||
                           (!(read_stage1_valid || read_stage3_valid ||
                              read_stage4_valid) &&
                            read_waiting[read_deliver[0:4]]) ||
                           (!read_stage4_valid && read_acknowledge));

  assign read_data_push = read_stage1_valid;

  assign read_stage0 = !read_start && |read_deliver_bytes && read_data_move &&
                       ((read_waiting[read_deliver[0:4]]) ||
                        (read_st_wait && !(|read_pending) && !(|read_waiting)));

  always @ (posedge ha_pclock)
    if (reset || read_start)
      read_stage0_valid <= 1'b0;
    else
      read_stage0_valid <= read_stage0;

  always @ (posedge ha_pclock) begin
    if (read_stage0_valid)
      read_data_stage1 <= read_data_stage0;
  end

  always @ (posedge ha_pclock) begin
    if (reset || read_start)
      read_stage1_valid <= 1'b0;
    else
      read_stage1_valid <= read_stage0_valid;
  end

  always @ (posedge ha_pclock) begin
    if (read_data_move || read_data_push) begin
        read_data_stage2<=read_data_stage1;
    end
  end

  always @ (posedge ha_pclock) begin
    if (read_start || read_done)
      read_stage2_valid <= 1'b0;
    else if (read_data_move || read_data_push)
      read_stage2_valid <= read_stage1_valid;
  end

  always @ (posedge ha_pclock) begin
    if (read_data_move || (read_data_push && read_stage2_valid)) begin
        read_data_stage3<=read_data_stage2;
    end
  end

  always @ (posedge ha_pclock) begin
    if (read_start || read_done)
      read_stage3_valid <= 1'b0;
    else if (read_data_move || (read_data_push && read_stage2_valid))
      read_stage3_valid <= read_stage2_valid && |read_deliver_bytes;
  end

  assign read_stage4_move = read_stage3_valid && (!read_acknowledge &&
                                 (read_data_move  ||
                                  (read_data_push && read_stage2_valid &&
                                   read_stage3_valid)));

  always @ (posedge ha_pclock) begin
    if (read_stage4_move)
      read_data_stage4 <= read_data_stage3;
  end

  always @ (posedge ha_pclock) begin
    if (read_start || read_done)
      read_stage4_valid <= 1'b0;
    else if (read_stage4_move || read_acknowledge)
      read_stage4_valid <= read_stage3_valid && read_stage4_move;
  end

  assign read_data_ready = (read_stage3_valid || read_stage4_valid) &&
                           |read_deliver_bytes;

  assign read_data = read_stage4_valid ? read_data_stage4 : read_data_stage3;

  assign read_deliver_bytes_portion = read_deliver_bytes[32:63]-32'h40;//rblack added for timing

  always @ (posedge ha_pclock) begin
    if (read_start)
      read_deliver_bytes <= read_size;
    else if (read_acknowledge) begin
      if (|read_deliver_bytes[0:57])
          read_deliver_bytes <= {read_deliver_bytes[0:31],read_deliver_bytes_portion};//rblack added for timing
      else
        read_deliver_bytes <= 0;
    end
  end

  assign read_acknowledge = read_data_ready && read_data_ack;

////////////////////////////////////////////////////////////////////////////
//Command Source:Write Copy Data State Machine/Port
////////////////////////////////////////////////////////////////////////////

//State machine
//next state =
//idle: when afu is reset or all commands have successfully completed
//request: when start is sent from job module
//wait: when all commands have received a done response in the write queue.
  always @ (posedge ha_pclock) begin
    if (reset)
      write_state <= 3'b100; // write_st_idle
    else if (write_st_idle && write_req)
      write_state <= 3'b010; // write_st_request
    else if (write_idle)
      write_state <= 3'b001; // write_st_wait
    else if (write_done)
      write_state <= 3'b100; // write_st_idle
  end

//Decode state machine bits
  assign write_st_idle = write_state[0];
  assign write_st_request = write_state[1];
  assign write_st_wait = write_state[2];

//Control signals based on state machine.
  assign write_ready = write_st_idle;
  assign write_start = write_st_idle && write_req;
  assign write_idle = write_st_request && !(|write_size_l) &&
                      !(write_stage2_valid || write_stage3_valid || 
                        |write_valid_size);
  assign write_done = write_st_wait && !(|write_valid_size || |write_waiting);

  always @ (posedge ha_pclock)
    write_start_l <= write_start;

  always @ (posedge ha_pclock) begin
    if (write_start)
      write_ch_l <= write_ch;
  end

//Add half cacheline every time write command is queued
  always @ (posedge ha_pclock) begin
    if (write_start)
      write_addr_l <= write_addr;
    else if (write_queue) begin
        write_addr_l <= write_addr_l + 64'h0000_0000_0000_0040;
    end
  end

  assign write_size_add_portion = write_size_l[32:63] - {25'h0, write_bytes};//rblack added for timing

//Sample total number of cachelines to copy at start of write state machine.
//Subtract write bytes from the total size when queueing
  always @ (posedge ha_pclock) begin
    if (reset)
      write_size_l <= 64'h0;
    else if (write_start)
      write_size_l <= write_size;
    else if (write_queue)
      write_size_l <= {write_size_l[0:31],write_size_add_portion};//rblack added for timing
  end

//write pending address incremented when write is acknowledged
  always @ (posedge ha_pclock) begin
    if (reset)
      write_pending_addr <= 64'h0;
    else if (write_start)
      write_pending_addr <= write_addr;
    else if (write_acknowledge)
      write_pending_addr <= write_pending_addr + 64'h0000_0000_0000_0040;
  end

  assign write_pending_bytes_portion1 = write_pending_bytes[32:63] + {25'h0, (7'h40-write_bytes)};//rblack added for timing
  assign write_pending_bytes_portion2 = write_pending_bytes[32:63] + 32'h40;//rblack added for timing
  assign write_pending_bytes_portion3 = write_pending_bytes[32:63] - {25'h0, write_bytes};//rblack added for timing

  always @ (posedge ha_pclock) begin
    if (write_start || reset)
      write_pending_bytes <= 0;
    else if (write_acknowledge && write_queue)
        write_pending_bytes <= {write_pending_bytes[0:31],write_pending_bytes_portion1};//rblack added for timing
    else if (write_acknowledge)
      write_pending_bytes <= {write_pending_bytes[0:31],write_pending_bytes_portion2};//rblack added for timing
    else if (write_queue) begin
        write_pending_bytes <= {write_pending_bytes[0:31],write_pending_bytes_portion3};//rblack added for timing
    end
  end

  assign write_block = (!write_addr_l[57] && |write_bytes_cl_l[1:7] &&
                        write_stage2_valid) ||
                        write_addr_stage3[57] &&
                        (1'b0);

//Queue write in write buffer
  assign write_queue = (write_pending_bytes>=write_bytes) && |write_bytes &&
                       |write_size_l && !write_block;

  assign write_queued = |(write_valid_size & ~write_waiting);

  always @ (posedge ha_pclock) begin
    if (write_start)
      write_bytes <= 7'h00;
    else if (write_start_l)
      write_bytes <= (write_size_l[57:63]>7'h40) ||
                     |write_size_l[0:56] ?
                     7'h40 : write_size_l[57:63];
    else if (write_queue) begin
      if (|write_size_l[0:56] ||
          ((write_size_l[56:63]-{1'b0,write_bytes})>8'h40))
        write_bytes <= 7'h40;
      else
        write_bytes <= write_size_l[57:63] - write_bytes;
    end
  end

  always @ (posedge ha_pclock) begin
    if (write_start_l)
      write_bytes_cl <= (write_size_l[56:63]>8'h80) ||
                        |write_size_l[0:55] ?
                        8'h80 : write_size_l[56:63];
    else if (write_queue && write_addr_l[57]) begin
      if (|write_size_l[0:56] ||
          ((write_size_l[55:63]-{1'b0,write_bytes_cl})>9'h80))
        write_bytes_cl <= 8'h80;
      else
        write_bytes_cl <= write_size_l[56:63] - {1'b0,write_bytes};
    end
  end

  always @ (posedge ha_pclock)
    write_bytes_cl_l <= write_bytes_cl;

  assign write_deliver_bytes_portion = write_deliver_bytes[32:63]-32'h40;//rblack added for timing

  always @ (posedge ha_pclock) begin
    if (reset)
      write_deliver_bytes <= 64'h0;
    else if (write_start)
      write_deliver_bytes <= write_size;
    else if (write_acknowledge) begin
      if (write_deliver_bytes >= 64'h40)
        write_deliver_bytes <= {write_deliver_bytes[0:31],write_deliver_bytes_portion};//rblack added for timing
      else
        write_deliver_bytes <= 64'h0;
    end
  end

  assign write_data_ready = |write_deliver_bytes && !write_block &&
                            !write_valid_size[write_pending_addr[52:56]] &&
                            !write_valid_size[5'h1+write_pending_addr[52:56]];

  assign write_acknowledge = write_data_ready && write_data_ack;

  always @ (posedge ha_pclock) begin
    if (write_acknowledge || (!(|write_deliver_bytes) && write_queue))
      write_data_stage0 <= write_data;
  end

  always @ (posedge ha_pclock) begin
    if (write_start)
      write_addr_stage2 <= write_addr;
    else if (write_queue)
      write_addr_stage2 <= write_addr_l;
  end

  always @ (posedge ha_pclock) begin
    if (write_start)
      write_addr_stage3 <= write_addr;
    else if (write_stage2_valid)
      write_addr_stage3 <= write_addr_stage2;
  end

  always @ (posedge ha_pclock) begin
    if (write_start)
      write_size_stage2 <= 8'h00;
    else if (write_queue)
        write_size_stage2 <= write_bytes_cl;
  end

  always @ (posedge ha_pclock)
    write_size_stage3 <= write_size_stage2;

  assign write_size_less1 = write_size_stage2-8'h01;

  assign write_align_addr = write_addr_stage2[57] ? write_addr_stage3[56:63] :
                                write_addr_stage2[56:63];

  always @ (posedge ha_pclock) begin
    if (reset || write_start)
      write_stage0_valid <= 0;
    else if (write_acknowledge)
      write_stage0_valid <= 1;
  end

  always @ (posedge ha_pclock)
    write_stage1_valid <= write_stage0_valid;

//Write command buffer write enable signals
  assign write_store_addr = !write_valid_addr[write_addr_stage3[52:56]] &&
                            write_stage3_valid;

  assign write_store_size = (write_stage3_valid &&
                             (write_addr_stage3[57] || !(|write_size_l)));

  ram #(
    .WIDTH(64),
    .DEPTH(32)
  ) ram_wr_addr (
    .clk(ha_pclock),
    .wrad(write_addr_stage3[52:56]),
    .d(write_addr_stage3),
    .we(write_store_addr),
    .rdad(write_index),
    .q(write_req_addr)
  );

  ram #(
    .WIDTH(8),
    .DEPTH(32)
  ) ram_wr_size (
    .clk(ha_pclock),
    .wrad(write_addr_stage3[52:56]),
    .d(write_size_stage3),
    .we(write_store_size),
    .rdad(write_index),
    .q(write_req_size)
  );

//Command arbitration. Writes have higher priority than reads. If there are
//credits available, no restart is pending, and no miscellaneous command is
//being issued, write command will be able to issue. Must have a valid command
//queued and not be waiting on command in same read index.
  assign write_request_ul = |credits && !write_waiting[write_index] &&
                            !misc_request_ul && write_valid_size[write_index] && !restart_pending;

  always @ (posedge ha_pclock) begin
    write_request <= write_request_ul;
  end

//Command buffer read address
  always @ (posedge ha_pclock) begin
    if (reset)
      write_index <= 5'b0;
    else if (write_start)
      write_index <= write_addr[52:56];
    else if ((write_queued && !write_request && !write_valid_size[write_index])
             || write_request_ul)
      write_index <= write_index+5'b00001;
  end

  always @ (posedge ha_pclock) begin
    if (write_start || write_request_ul)
      write_index_l <= write_index;
  end

//Set write valid
  genvar watag;
  generate
    for (watag = 0; watag < 32; watag = watag + 1) begin: gen_wa_valid
      always @ (posedge ha_pclock) begin
        if (reset)
          write_valid_addr[watag] <= 1'b0;
        else if (write_store_addr && (watag==write_addr_stage3[52:56]))
          write_valid_addr[watag] <= 1'b1;
        else if ((write_resp) && (watag==ha_rtag[3:7]) &&
                 resp_done)
          write_valid_addr[watag] <= 1'b0;
      end
    end
  endgenerate

  genvar wdtag;
  generate
    for (wdtag = 0; wdtag < 32; wdtag = wdtag + 1) begin: gen_wd_valid
      always @ (posedge ha_pclock) begin
        if (reset)
          write_valid_size[wdtag] <= 1'b0;
        else if (write_store_size && (wdtag==write_addr_stage3[52:56]))
          write_valid_size[wdtag] <= 1'b1;
        else if ((write_resp) && (wdtag==ha_rtag[3:7]) &&
                 resp_done)
          write_valid_size[wdtag] <= 1'b0;
      end
    end
  endgenerate

  genvar wwtag;
  generate
    for (wwtag = 0; wwtag < 32; wwtag = wwtag + 1) begin: gen_wr_waiting
      always @ (posedge ha_pclock) begin
        if (reset)
          write_waiting[wwtag] <= 1'b0;
        else if (write_request && (wwtag==write_index_l))
          write_waiting[wwtag] <= 1'b1;
        else if ((write_resp) && (wwtag==ha_rtag[3:7]))
          write_waiting[wwtag] <= 1'b0;
      end
    end
  endgenerate

  always @ (posedge ha_pclock) begin
    if (write_queue) begin
        write_data_stage2<=write_data_stage0;
    end
  end

  always @ (posedge ha_pclock)
    write_stage2_valid <= write_queue;

  always @ (posedge ha_pclock)
    write_stage3_valid <= write_stage2_valid;

  always @ (posedge ha_pclock) begin
    if (write_acknowledge || write_stage1_valid || write_stage2_valid) begin
        write_data_stage3<=write_data_stage2;
    end
  end

  always @ (posedge ha_pclock)
    write_tag_stage3 <= write_addr_stage2[52:57];

  assign write_buffer_alt_data = misc_brdata_ul;

  assign write_buffer_alt_addr = {1'b0, misc_addr_l[52:56], misc_half};

  assign write_buffer_wr_data = write_stage3_valid ? write_data_stage3 :
                                write_buffer_alt_data;

  assign write_buffer_wr_addr = write_stage3_valid ? {1'b1, write_tag_stage3} :
                                write_buffer_alt_addr;

  assign write_buffer_wr_enable = write_stage3_valid ||
                                  misc_write_enable;

  assign write_buffer_rd_addr = {ha_brtag[2:7],ha_brad[5]};

  always @ (posedge ha_pclock) begin
    write_buffer_wr_data_l <= write_buffer_wr_data;
    write_buffer_wr_addr_l <= write_buffer_wr_addr;
    write_buffer_wr_enable_l <= write_buffer_wr_enable;
  end

  ram #(
    .WIDTH(512),
    .DEPTH(128)
  ) ram_wr_data (
    .clk(ha_pclock),
    .wrad(write_buffer_wr_addr_l),
    .d(write_buffer_wr_data_l),
    .we(write_buffer_wr_enable_l),
    .rdad(write_buffer_rd_addr),
    .q(write_brdata)
  );

  dw_parity #(
    .DOUBLE_WORDS(8)
  ) write_parity (
    .data(write_buffer_wr_data_l),
    .odd(odd_parity),
    .par(write_buffer_par)
  );

  ram #(
    .WIDTH(8),
    .DEPTH(128)
  ) ram_wr_parity (
    .clk(ha_pclock),
    .wrad(write_buffer_wr_addr_l),
    .d(write_buffer_par),
    .we(write_buffer_wr_enable_l),
    .rdad({ha_brtag[2:7],ha_brad[5]}),
    .q(write_brpar)
  );

////////////////////////////////////////////////////////////////////////////
//Command Interface Logic.
////////////////////////////////////////////////////////////////////////////

//Issue cvalid from 4 possible command sources.
  always @ (posedge ha_pclock)
    cvalid <= restart_request || misc_request || read_request || write_request;

//Pick context handle from 4 possible command sources. Dedicated afu, so all
//contexts will be 0.
  always @ (posedge ha_pclock) begin
    if (restart_request)
      cch <= 0;
    else if (misc_request)
      cch <= misc_ch_l;
    else if (read_request)
      cch <= read_ch_l;
    else if (write_request)
      cch <= write_ch_l;
  end

//Pick effective address based on command source
  always @ (posedge ha_pclock) begin
    if (restart_request)
      cea <= 0;
    else if (misc_request)
      cea <= {misc_addr_l, 7'b0};
    else if (write_request) begin
      cea <= write_req_addr;
    end
    else if (read_request)
      cea <= {read_req_addr[0:56], 7'b0};
  end

//Pick csize based on command source
  always @ (posedge ha_pclock) begin
    if (restart_request)
      csize <= 0;
    else if (write_request)
      csize <= write_req_size;
    else if (misc_request || write_request || read_request)
      csize <= 8'h80;
  end

//Pick tag based on command source
  always @ (posedge ha_pclock) begin
    if (restart_request)
      ctag <= 0;
    else if (misc_request)
      ctag <= {misc_tag_prefix, misc_addr_l[52:56]};
    else if (write_request)
      ctag <= {write_tag_prefix, write_index_l};
    else if (read_request)
      ctag <= {read_tag_prefix, read_index_l};
  end

//Pick command code based on command source
  always @ (posedge ha_pclock) begin
    if (restart_request)
      com <= 13'h0001;
    else if (misc_request)
      com <= misc_com_l;
    else if (write_request)
      com <= 13'h0D00;
    else if (read_request)
      com <= 13'h0A00;
  end

//Latch command interface signals to align with parity
  always @ (posedge ha_pclock)
    cvalid_l <= cvalid;

  always @ (posedge ha_pclock)
    cch_l <= cch;

  always @ (posedge ha_pclock)
    ctag_l <= ctag;

  always @ (posedge ha_pclock)
    com_l <= com;

  always @ (posedge ha_pclock)
    cea_l <= cea;

  always @ (posedge ha_pclock)
    csize_l <= csize;

//Generate parity for command tag, command code, and cea. Latch parity info.
  parity #(
    .BITS(8)
  ) ctag_parity (
    .data(ctag),
    .odd(odd_parity),
    .par(ctagpar_ul)
  );

  parity #(
    .BITS(13)
  ) com_parity (
    .data(com),
    .odd(odd_parity),
    .par(compar_ul)
  );

  parity #(
    .BITS(64)
  ) ea_parity (
    .data(cea),
    .odd(odd_parity),
    .par(ceapar_ul)
  );

  always @ (posedge ha_pclock)
    ctagpar_l <= ctagpar_ul;

  always @ (posedge ha_pclock)
    compar_l <= compar_ul;

  always @ (posedge ha_pclock)
    ceapar_l <= ceapar_ul;

//Assign command interface outputs
  assign ah_cvalid = cvalid_l;
  assign ah_ctag = ctag_l;
  assign ah_ctagpar = ctagpar_l;
  assign ah_com = com_l;
  assign ah_compar = compar_l;
  assign ah_cabt = 3'b0;
  assign ah_cea = cea_l;
  assign ah_cch = cch_l;
  assign ah_ceapar = ceapar_l;
  assign ah_csize = csize_l;

////////////////////////////////////////////////////////////////////////////
//Read Buffer Interface  Logic
////////////////////////////////////////////////////////////////////////////

  // latch brdata and parity
  always @ (posedge ha_pclock) begin
    write_brdata_l <= write_brdata;
    write_brpar_l  <= write_brpar;
  end
   
  //assign psl interface read data outputs.
  assign ah_brlat = 4'h1;
  assign ah_brdata = write_brdata_l;
  assign ah_brpar = write_brpar_l;

////////////////////////////////////////////////////////////////////////////
//Parity checking of psl response and buffer interface inputs
////////////////////////////////////////////////////////////////////////////

//Check bwdata parity
  always @ (posedge ha_pclock) begin
    if (reset)
      bwdata_l <= 512'h0;
    else if (ha_bwvalid)
      bwdata_l <= ha_bwdata;
  end
   
  always @ (posedge ha_pclock)
      ha_bwvalid_l <= ha_bwvalid;

  always @ (posedge ha_pclock) begin
    if (reset)
      ha_bwpar_l <= 8'hff;
    else if (ha_bwvalid_l)
      ha_bwpar_l <= ha_bwpar;
  end

  dw_parity #(
    .DOUBLE_WORDS(8)
  ) read_parity (
    .data(bwdata_l),
    .odd(odd_parity),
    .par(bwpar_ul)
  );

  always @ (posedge ha_pclock) begin
    if (reset)
      bwpar_l <= 8'hff;
    else
      bwpar_l <= bwpar_ul;
  end

  assign parity_err_ul[0] = |(ha_bwpar_l^bwpar_l) && !reset;

//Check brtag parity
  always @ (posedge ha_pclock) begin
    if (reset)
      brtag_l <= 8'h0;
    else if (ha_brvalid)
      brtag_l <= ha_brtag;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      brtagpar_l <= odd_parity;
    else if (ha_brvalid)
      brtagpar_l <= ha_brtagpar;
  end

  parity #(
    .BITS(8)
  ) brtag_parity (
    .data(brtag_l),
    .odd(odd_parity),
    .par(brtagpar_ul)
  );

  assign parity_err_ul[1] = (brtagpar_l ^ brtagpar_ul) && !reset;

//Check bwtag parity
  always @ (posedge ha_pclock) begin
    if (reset)
      bwtag_l <= 8'h0;
    else if (ha_bwvalid)
      bwtag_l <= ha_bwtag;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      bwtagpar_l <= odd_parity;
    else if (ha_bwvalid)
      bwtagpar_l <= ha_bwtagpar;
  end

  parity #(
    .BITS(8)
  ) bwtag_parity (
    .data(bwtag_l),
    .odd(odd_parity),
    .par(bwtagpar_ul)
  );

  assign parity_err_ul[2] = (bwtagpar_l ^ bwtagpar_ul) && !reset;

//Check rtag parity
  always @ (posedge ha_pclock) begin
    if (reset)
      rtag_l <= 8'h0;
    else if (ha_rvalid)
      rtag_l <= ha_rtag;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      rtagpar_l <= odd_parity;
    else if (ha_rvalid)
      rtagpar_l <= ha_rtagpar;
  end

  parity #(
    .BITS(8)
  ) rtag_parity (
    .data(rtag_l),
    .odd(odd_parity),
    .par(rtagpar_ul)
  );

  assign parity_err_ul[3] = (rtagpar_l ^ rtagpar_ul) && !reset;

  always @ (posedge ha_pclock)
    parity_err_l <= parity_err_ul;

  assign parity_err = parity_err_l;

endmodule
