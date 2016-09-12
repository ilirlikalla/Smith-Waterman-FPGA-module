//   (C) Copyright International Business Machines 2014

module mmio (
  input          ha_mmval,
  input          ha_mmcfg,
  input          ha_mmrnw,
  input          ha_mmdw,
  input  [0:23]  ha_mmad,
  input          ha_mmadpar,
  input  [0:63]  ha_mmdata,
  input          ha_mmdatapar,
  output         ah_mmack,
  output [0:63]  ah_mmdata,
  output         ah_mmdatapar,
  output [0:1]   parity_error,
  input          odd_parity,
  input          reset,
  input          ha_pclock,
  input         command_trace_val,
  input [0:7]   command_trace_wtag,
  input [0:119] command_trace_wdata,
  input	        response_trace_val,
  input [0:7]   response_trace_wtag,
  input [0:41]  response_trace_wdata,
  input         jcontrol_trace_val,
  input [0:140] jcontrol_trace_wdata,
  output        done_premmio,
  output        done_postmmio,
  input         start_premmio,
  input         start_postmmio

);

  // Internal signals

  reg         cfg_read;
  reg         cfg_read_l;
  reg         cfg_write;
  reg         cfg_write_l;
  reg         mmio_read;
  reg         mmio_read_l;
  reg         mmio_write;
  reg         mmio_write_l;
  reg  [0:23] mmio_ad;
  reg         mmio_adpar;
  reg         mmio_dw;
  reg         mmio_dw_l;
  reg  [0:63] mmio_wr_data;
  reg         mmio_wr_datapar;
  reg  [0:63] mmio_rd_data;
  reg  [0:63] mmio_rd_data_l;
  reg         mmio_rd_datapar_l;
  reg         mmio_ack;
  reg         mmio_ack_l;
  reg  [0:63] cfg_data;

  wire        mmio_adpar_ul;
  wire        mmio_wr_datapar_ul;
  wire        mmio_rd_datapar;

  // Trace array signals
  reg          command_trace_val_l;
  reg  [0:7]   command_trace_wtag_l;
  reg  [0:119] command_trace_wdata_l;
  reg          response_trace_val_l;
  reg  [0:7]   response_trace_wtag_l;
  reg  [0:41]  response_trace_wdata_l;
  reg          jcontrol_trace_val_l;
  reg  [0:140] jcontrol_trace_wdata_l;

  reg  [0:63]  trace_read_reg;

  reg         trace_rval_l;
  wire [0:23] trace_mmioad = 24'h FFFFFE;

  wire        command_trace_ack;
  wire [0:63] command_trace_data_out;
  wire        response_trace_ack;
  wire [0:63] response_trace_data_out;
  wire        control_trace_ack;
  wire [0:63] control_trace_data_out;
  reg         trace_write_ack;

  wire        local_trace_stop_condition;

  reg  [0:63] trace_options_reg;

  // Input latching

  always @ (posedge ha_pclock)
    cfg_read <= ha_mmval && ha_mmcfg && ha_mmrnw;

  always @ (posedge ha_pclock)
    cfg_read_l <= cfg_read;

  always @ (posedge ha_pclock)
    cfg_write <= ha_mmval && ha_mmcfg && !ha_mmrnw;

  always @ (posedge ha_pclock)
    cfg_write_l <= cfg_write;

  always @ (posedge ha_pclock)
    mmio_read <= ha_mmval && !ha_mmcfg && ha_mmrnw && (ha_mmad != trace_mmioad);

  always @ (posedge ha_pclock)
    mmio_read_l <= mmio_read;

  always @ (posedge ha_pclock)
    mmio_write <= ha_mmval && !ha_mmcfg && !ha_mmrnw && (ha_mmad != trace_mmioad);

  always @ (posedge ha_pclock)
    mmio_write_l <= mmio_write;

  always @ (posedge ha_pclock) begin
    if (ha_mmval)
      mmio_dw <= ha_mmdw;
  end

  always @ (posedge ha_pclock)
      mmio_dw_l <= mmio_dw;

  always @ (posedge ha_pclock) begin
    if (reset)
      mmio_ad <= 24'h0;
    if (ha_mmval)
      mmio_ad <= ha_mmad;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      mmio_adpar <= odd_parity;
    else if (ha_mmval)
      mmio_adpar <= ha_mmadpar;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      mmio_wr_data <= 64'h0;
    if (ha_mmval && !ha_mmrnw)
      mmio_wr_data <= ha_mmdata;
  end

  always @ (posedge ha_pclock) begin
    if (reset)
      mmio_wr_datapar <= odd_parity;
    if (ha_mmval && !ha_mmrnw)
      mmio_wr_datapar <= ha_mmdatapar;
  end

  // AFU descriptor
  // Offset 0x00(0), bit 31 -> AFU supports only 1 process at a time
  // Offset 0x00(0), bit 47 -> AFU has one Configuration Record (CR).
  // Offset 0x00(0), bit 59 -> AFU supports dedicated process
  // Offset 0x20(4), bits 0:7 -> 0x00 to indicate implementation specific CR.
  // bits 8:63 -> 0x1 to indicate minimum possible length of 256 bytes per CR. 
  // Offset 0x28(5), bits 0:63 -> point to next descr read offset for CR.
  // the lowest 8 bits are 0 because it must be 256 byte aligned address.
  // Offset 0x30(6), bit 07 -> AFU Problem State Area Required
  // Offset 0x100(32), start of little endian CR data as per pointer at 0x28.
  // First 4 bytes for device ID, vendor id set to DEAD in ascii.
  // Next 4 bytes 0.
  // Offset 0x108(33), next little endian data
  // First 4 bytes 'alig' in ascii for rev ID, class code. 
  // Next 4 bytes 0.
  // Though 256 bytes allocated, don't care about rest.

  always @ (posedge ha_pclock) begin
    if (mmio_ad[0:22]==0)//Offset 0x00
      cfg_data <= 64'h0000000100010010;
    else if (mmio_ad[0:22]==4)//Offset 0x20
      cfg_data <= 64'h0000000000000001;
    else if (mmio_ad[0:22]==5)//Offset 0x28
      cfg_data <= 64'h0000000000000100;
    else if (mmio_ad[0:22]==6)//Offset 0x30
      cfg_data <= 64'h0100000000000000;
    else if (mmio_ad[0:22]==32)//Offset 0x100
      cfg_data <= 64'h4441454400000000;
    else if (mmio_ad[0:22]==33)//Offset 0x108
      cfg_data <= 64'h616c696700000000;
    else			  
      cfg_data <= 64'h0000000000000000;
  end

  // Read data

  always @ (posedge ha_pclock) begin
    if (cfg_read_l) begin
      if (mmio_dw_l)
        mmio_rd_data <= cfg_data;
      else if (mmio_ad[23])
        mmio_rd_data <= {cfg_data[32:63], cfg_data[32:63]};
      else
        mmio_rd_data <= {cfg_data[0:31], cfg_data[0:31]};
    end
    else if (command_trace_ack) begin
      mmio_rd_data <= command_trace_data_out;
    end
    else if (response_trace_ack) begin
      mmio_rd_data <= response_trace_data_out;
    end
    else if (control_trace_ack) begin
      mmio_rd_data <= control_trace_data_out;
    end
    else if (mmio_read_l) begin
      mmio_rd_data <= trace_options_reg;
    end
    else
      mmio_rd_data <= 64'h0;
  end

  parity #(
    .BITS(64)
  ) rd_data_parity (
    .data(mmio_rd_data),
    .odd(odd_parity),
    .par(mmio_rd_datapar)
  );

  // MMIO acknowledge

  always @ (posedge ha_pclock)
    mmio_ack <= cfg_read_l || cfg_write_l || mmio_read_l || mmio_write_l || command_trace_ack || response_trace_ack || control_trace_ack || trace_write_ack;

  // Latched outputs

  always @ (posedge ha_pclock)
    mmio_rd_data_l <= mmio_rd_data;

  always @ (posedge ha_pclock)
    mmio_rd_datapar_l <= mmio_rd_datapar;

  always @ (posedge ha_pclock)
    mmio_ack_l <= mmio_ack;

  assign ah_mmack = mmio_ack_l;
  assign ah_mmdata = mmio_rd_data_l;
  assign ah_mmdatapar = mmio_rd_datapar_l;

  // Parity checking

  parity #(
    .BITS(24)
  ) ad_parity (
    .data(mmio_ad),
    .odd(odd_parity),
    .par(mmio_adpar_ul)
  );

  parity #(
    .BITS(64)
  ) wr_data_parity (
    .data(mmio_wr_data),
    .odd(odd_parity),
    .par(mmio_wr_datapar_ul)
  );

  assign parity_error[0] = mmio_adpar ^ mmio_adpar_ul;
  assign parity_error[1] = mmio_wr_datapar ^ mmio_wr_datapar_ul;

//Trace Array Logic

  trace_array_template #(
   .RAM_OPT("m20k,no_rw_check"),
   .ADDR_WIDTH(8),
   .DATA_WIDTH(120),
   .TRACE_ID("0x0")
  ) command_interface_trace (
   .clk(ha_pclock),
   .reset(reset),
   .read_controls({trace_read_reg[60:63], trace_read_reg[0]}),
   .trace_rvalid(trace_rval_l),
//   .flow_mode_in(trace_read_reg[16]),
   .flow_mode_in(1'b 1),
   .trace_data_in(command_trace_wdata_l),
   .trace_valid(command_trace_val_l),
   .trace_tag(command_trace_wtag_l),
   .local_trace_stop(1'b 0),
   .trace_data_out(command_trace_data_out),
   .trace_data_ack_out(command_trace_ack)
  );
  
    trace_array_template #(
   .RAM_OPT("m20k,no_rw_check"),
   .ADDR_WIDTH(8),
   .DATA_WIDTH(42),
   .TRACE_ID("0x1")
  ) response_interface_trace (
   .clk(ha_pclock),
   .reset(reset),
   .read_controls({trace_read_reg[60:63], trace_read_reg[0]}),
   .trace_rvalid(trace_rval_l),
//   .flow_mode_in(trace_read_reg[17]),
   .flow_mode_in(1'b 1),
   .trace_data_in(response_trace_wdata_l),
   .trace_valid(response_trace_val_l),
   .trace_tag(response_trace_wtag_l),
   .local_trace_stop(1'b 0),
   .trace_data_out(response_trace_data_out),
   .trace_data_ack_out(response_trace_ack)
  );

    trace_array_template #(
   .RAM_OPT("m20k,no_rw_check"),
   .ADDR_WIDTH(8),
   .DATA_WIDTH(141),
   .TRACE_ID("0x2")
  ) control_interface_trace (
   .clk(ha_pclock),
   .reset(reset),
   .read_controls({trace_read_reg[60:63], trace_read_reg[0]}),
   .trace_rvalid(trace_rval_l),
   .flow_mode_in(1'b 1),
   .trace_data_in(jcontrol_trace_wdata_l),
   .trace_valid(jcontrol_trace_val_l),
   .trace_tag(8'h 00),
   .local_trace_stop(1'b 0),
   .trace_data_out(control_trace_data_out),
   .trace_data_ack_out(control_trace_ack)
  );

  assign local_trace_stop_condition = parity_error[0] | parity_error[1];

  always @ (posedge ha_pclock)
  begin
    if(reset)begin
    command_trace_val_l <= 1'b 0;
    command_trace_wtag_l <= 8'h 00;
    command_trace_wdata_l <= 120'h 0000_0000_0000_0000_0000_0000_0000_00;
    response_trace_val_l <= 1'b 0;
    response_trace_wtag_l <= 8'h 00;
    response_trace_wdata_l <= {40'h 0000_0000_00, 2'b 00};
    jcontrol_trace_val_l <= 1'b 0;
    jcontrol_trace_wdata_l <= {140'h 0000_0000_0000_0000_0000_0000_0000_0000_000, 1'b 0};
    trace_rval_l <= 1'b 0;
    trace_write_ack <= 1'b 0;
    end
    else begin  
    command_trace_val_l <= command_trace_val;
    command_trace_wtag_l <= command_trace_wtag;
    command_trace_wdata_l <= command_trace_wdata;
    response_trace_val_l <= response_trace_val;
    response_trace_wtag_l <= response_trace_wtag;
    response_trace_wdata_l <= response_trace_wdata;
    jcontrol_trace_val_l <= jcontrol_trace_val;
    jcontrol_trace_wdata_l <= jcontrol_trace_wdata;
    trace_rval_l <= ha_mmval && !ha_mmcfg && ha_mmrnw && ha_mmdw && (ha_mmad == trace_mmioad);
    trace_write_ack <= ha_mmval && !ha_mmcfg && !ha_mmrnw && ha_mmdw && (ha_mmad == trace_mmioad);
    end
  end

  always @ (posedge ha_pclock)
  begin
    if(reset)
    trace_read_reg <= 64'h 0000_0000_0000_0000;
    else if(ha_mmval && !ha_mmcfg && !ha_mmrnw && ha_mmdw && (ha_mmad == trace_mmioad))
            trace_read_reg <= {ha_mmdata[0], 15'b 000000000000000, ha_mmdata[16:31], 28'h 0000000, ha_mmdata[60:63]};
    else trace_read_reg <= trace_read_reg;
  end

  always @ (posedge ha_pclock)
  begin
    if(reset)
    trace_options_reg[0:31] <= 32'h 0000_0000;
    else if(mmio_write_l)
    trace_options_reg[0:31] <= mmio_wr_data[0:31];
    else trace_options_reg[0:31] <= trace_options_reg[0:31];
    if(reset)
    trace_options_reg[32:63] <= 32'h 0000_0000;
    else trace_options_reg[32:63] <= {start_premmio,start_postmmio, 2'b 00, 28'h 1234_567};
  end

  assign done_premmio = trace_options_reg[0];
  assign done_postmmio = trace_options_reg[1];

endmodule
