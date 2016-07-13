//   (C) Copyright International Business Machines 2014

module job (
  input           ha_jval,
  input  [0:7]    ha_jcom,
  input           ha_jcompar,
  input  [0:63]   ha_jea,
  input           ha_jeapar,
  output          ah_jrunning,
  output          ah_jdone,
  output [0:63]   ah_jerror,
  input           ha_pclock,
  input           misc_ready,
  output          misc_req,
  output [0:56]   misc_addr,
  output [0:12]   misc_com,
  output [0:1023] misc_wr_data,
  input  [0:1023] misc_rd_data,
  input           read_ready,
  output          read_req,
  output  [0:63]  read_addr,
  output  [0:63]  read_size,
  input           write_ready,
  output          write_req,
  output  [0:63]  write_addr,
  output  [0:63]  write_size,
  output          reset,
  input           done,
  input           odd_parity,
  input   [0:12]  detect_err,
  input           done_premmio,
  input           done_postmmio,
  output reg      start_premmio,
  output reg      start_postmmio
);

  // Internal signals

  reg           reset_int;
  reg           start_int;
  reg           other_int;
  reg           done_int;
  reg           reset_l;
  reg           running_l;
  reg           done_l;
  reg  [0:63]   error_l;
  reg  [0:63]   error_ll;
  reg  [0:11]   job_state;
  reg  [0:63]   wed_address;
  reg  [0:1023] wed_data;
  reg  [0:7]    jcom_l;
  reg           jcompar_l;
  reg  [0:63]   jea_l;
  reg           jeapar_l;
  reg  [0:14]   detect_error_l;

  wire        job_st_idle;
  wire        job_st_premmio;
  wire        job_st_rd_req;
  wire        job_st_rd_wait;	
  wire        job_st_wr_req;
  wire        job_st_wr_wait;	
  wire        job_st_rd_seq_req;
  wire        job_st_wr_res_req;
  wire        job_st_done_req;
  wire        job_st_done_wait;
  wire        job_st_done;
  wire        job_st_postmmio;
  wire        wed_request;
  wire        wed_load;
  wire        wed_store;
  wire        wed_done;
  wire        load_req;
  wire        save_req;
  wire [0:12] wed_com;
  wire [0:15] wed_endian_bits;
  wire        little_endian;
  wire [0:15] wed_status;
  wire [0:15] logic_major;
  wire [0:15] logic_minor;
  wire [0:15] wed_major;
  wire [0:15] wed_minor;
  wire [0:63] wed_from;
  wire [0:63] wed_to;
  wire [0:63] wed_size;
  wire [0:63] wed_next;
  wire        all_done;
  wire        jcompar_ul;
  wire        jeapar_ul;
  wire [0:14] detect_error;
  wire        enable_errors;
  wire        error_detected;
  reg         done_premmio_l;
  reg         done_postmmio_l;

// ================ Decoding the control command ===============
//      **************** DO NOT EDIT!!! *******************

  // Reset, start and running -decode logic (ilir):

  assign logic_major = 16'h0;
  assign logic_minor = 16'h1;
  assign enable_errors = 1'b0;

  always @ (posedge ha_pclock) begin
    if (ha_jval) begin
      if (ha_jcom == 9'h080) begin
        reset_int <= 1;
        start_int <= 0;
        other_int <= 0;
      end
      else if (ha_jcom == 9'h090) begin
        reset_int <= 0;
        start_int <= 1;
        other_int <= 0;
      end
      else begin
        reset_int <= 0;
        start_int <= 0;
        other_int <= 1;
      end
    end
    else begin
      reset_int <= 0;
      start_int <= 0;
      other_int <= 0;
    end
  end

  always @ (posedge ha_pclock) begin
    if (reset_int)
      reset_l <= 1'b1;
    else if (reset_l)
      reset_l <= ~done_l;
  end

  assign error_detected = enable_errors & |detect_error_l;

  // On parity error detection send reset to all other logic immediately
//  assign reset = reset_int || reset_l || error_detected;
  assign reset = reset_int || error_detected;

  assign all_done = error_detected || (done && (job_st_idle && !start_int));

  always @ (posedge ha_pclock) begin
    if (reset_int || all_done)
      running_l <= 1'b0;
    else if (start_int || running_l)
      running_l <= 1'b1;
  end

  assign ah_jrunning = running_l;

  // On parity error set appropriate error bit
  always @ (posedge ha_pclock) begin
    if (enable_errors)
      error_l <= {48'h000000000000, detect_error_l, other_int};
    else
      error_l <= 64'h0000000000000000;
  end

  assign ah_jerror = error_l;

  always @ (posedge ha_pclock) begin
    if (reset_int)
      error_ll <= 64'h0000000000000000;
    else
      error_ll <= error_ll | error_l;
  end

  // On parity error signal jdone immediately
  always @ (posedge ha_pclock) begin
    if (reset_int || start_int || other_int && !(error_detected))
      done_l <= 1'b0;
    else if (all_done || (error_detected))
      done_l <= 1'b1;
  end

  always @ (posedge ha_pclock) begin
    if (all_done && ~done_l)
      done_int <= 1'b1;
    else
      done_int <= 1'b0;
  end

  assign ah_jdone = done_int;
// =========== End of Decoding the control command =============

// #################### STATE MACHINE: #########################


  // Job state machine

  assign job_st_idle = job_state[0];  
  assign job_st_premmio = job_state[1]; 	// optional
  assign job_st_rd_req = job_state[2];
  assign job_st_rd_wait = job_state[3];
  assign job_st_wr_req = job_state[4];
  assign job_st_wr_wait = job_state[5];
  assign job_st_rd_seq_req = job_state[6];
  assign job_st_wr_res_req = job_state[7];
  assign job_st_done = job_state[8];
  assign job_st_done_req = job_state[9];
  assign job_st_done_wait = job_state[10];
  assign job_st_postmmio = job_state[11];	// optional

  assign wed_request = misc_ready &&
                       (job_st_rd_req || job_st_wr_req || job_st_done_req);

  always @ (posedge ha_pclock) begin
    if (start_int)
      wed_address <= ha_jea;
  end

  assign wed_load = job_st_rd_wait && misc_ready;
  assign wed_store = job_st_wr_wait && misc_ready;
  assign load_req = job_st_rd_seq_req && read_ready;
  assign save_req = job_st_wr_res_req && write_ready;
  assign wed_done = job_st_done_wait && misc_ready;
  assign read_req = load_req;
  assign write_req = save_req;

  always @ (posedge ha_pclock) begin
    if (wed_load)
      wed_data <= misc_rd_data;
  end

  always @ (posedge ha_pclock) begin
    done_premmio_l <= done_premmio;
    done_postmmio_l <= done_postmmio;
    start_premmio <= job_st_premmio;
    start_postmmio <= job_st_postmmio;
  end

  always @ (posedge ha_pclock) begin
    if (reset_int)
      job_state <= 12'b100000000000;	// idle
    else if (job_st_idle && start_int)
      job_state <= 12'b010000000000;	// premmio
    else if (job_st_premmio && done_premmio_l)
      job_state <= 12'b001000000000;	// read request
    else if (job_st_rd_req && wed_request)
      job_state <= 12'b000100000000;	// read wait
    else if (wed_load)
      job_state <= 12'b000010000000;	// write request
    else if (job_st_wr_req && wed_request)
      job_state <= 12'b000001000000; 	// write wait
    else if (wed_store)
      job_state <= 12'b000000100000;	// mv read 
    else if (load_req)
      job_state <= 12'b000000010000;	// mv write 
    else if (save_req)
      job_state <= 12'b000000001000;	// done 
    else if (job_st_done && done)
      job_state <= 12'b000000000100; 	// done request
    else if (job_st_done_req && wed_request)
      job_state <= 12'b000000000010;	// done wait
    else if (wed_done)
      job_state <= 12'b000000000001;	// postmmio
    else if (job_st_postmmio && done_postmmio_l)
      job_state <= 12'b100000000000;	// idle
  end

  // WED data

  assign wed_endian_bits = wed_data[0:15];
  assign little_endian = wed_endian_bits[7];

  endian_swap #(
    .BYTES(2)
  ) endian_status (
    .data_in(wed_data[16:31]),
    .little_endian(little_endian),
    .data_out(wed_status)
  );

  endian_swap #(
    .BYTES(8)
  ) endian_from (
    .data_in(wed_data[64:127]),
    .little_endian(little_endian),
    .data_out(wed_from)
  );

  endian_swap #(
    .BYTES(8)
  ) endian_to (
    .data_in(wed_data[128:191]),
    .little_endian(little_endian),
    .data_out(wed_to)
  );

  endian_swap #(
    .BYTES(8)
  ) endian_size (
    .data_in(wed_data[192:255]),
    .little_endian(little_endian),
    .data_out(wed_size)
  );

  endian_swap #(
    .BYTES(2)
  ) endian_major (
    .data_in(logic_major),
    .little_endian(little_endian),
    .data_out(wed_major)
  );

  endian_swap #(
    .BYTES(2)
  ) endian_minor (
    .data_in(logic_minor),
    .little_endian(little_endian),
    .data_out(wed_minor)
  );

  // Misc. port

  assign wed_com = (job_st_wr_req || job_st_done_req) ? 13'h0D00 : 13'h0A00;
  assign misc_req = wed_request;
  assign misc_addr = wed_address[0:56];
  assign misc_com = wed_com;
  assign misc_wr_data = {wed_data[0:30], job_st_done_req, wed_major, wed_minor,
                         wed_data[64:319], error_l, wed_data[384:1023]};

  // Read port

  assign read_addr = wed_from;
  assign read_size = wed_size;

  // Write port

  assign write_addr = wed_to;
  assign write_size = wed_size;
// ############# END OF STATE MACHINE ##########################

// ============== Parity checking DO NOT EDIT: =================
  // Parity checking

  always @ (posedge ha_pclock) begin
    if (ha_jval)
      jcom_l <= ha_jcom;
    else if (done_int)
      jcom_l <= 8'h0;
  end

  always @ (posedge ha_pclock) begin
    if (ha_jval)
      jcompar_l <= ha_jcompar;
    else if (done_int)
      jcompar_l <= odd_parity;
  end

  parity #(
    .BITS(8)
  ) jcom_parity (
    .data(jcom_l),
    .odd(odd_parity),
    .par(jcompar_ul)
  );

  always @ (posedge ha_pclock) begin
    if (ha_jval)
      jea_l <= ha_jea;
    else if (done_int)
      jea_l <= 64'h0;
  end

  always @ (posedge ha_pclock) begin
    if (ha_jval)
      jeapar_l <= ha_jeapar;
    else if (done_int)
      jeapar_l <= odd_parity;
  end

  parity #(
    .BITS(64)
  ) jea_parity (
    .data(jea_l),
    .odd(odd_parity),
    .par(jeapar_ul)
  );

  assign detect_error[0] = jcompar_l ^ jcompar_ul;
  assign detect_error[1] = jeapar_l ^ jeapar_ul;
  assign detect_error[2:14] = detect_err;

  always @ (posedge ha_pclock)
    detect_error_l <= detect_error;

endmodule
