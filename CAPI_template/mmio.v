
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
`ifdef _TRACE_
	// ... put trace ports here ...
`endif
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
`ifdef _TRACE_
	// ... put trace signals here ...
`endif
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

`ifdef _TRACE_
	// ... put trace stuff here ...
`else
  always @ (posedge ha_pclock)
    mmio_read <= ha_mmval && !ha_mmcfg && ha_mmrnw;
`endif	

  always @ (posedge ha_pclock)
    mmio_read_l <= mmio_read;
`ifdef _TRACE_
	// ... put trace stuff here ...
`else
  always @ (posedge ha_pclock)
    mmio_write <= ha_mmval && !ha_mmcfg && !ha_mmrnw;
`endif
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
  // First 4 bytes BEEF in ascii for rev ID, class code. 
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
      cfg_data <= 64'h4645454200000000;
    else
      cfg_data <= 64'h0000000000000000;
  end

  // Read data

  always @ (posedge ha_pclock) begin
    if (cfg_read_l) 
	begin
      if (mmio_dw_l)
        mmio_rd_data <= cfg_data;
      else if (mmio_ad[23])
        mmio_rd_data <= {cfg_data[32:63], cfg_data[32:63]};
      else
        mmio_rd_data <= {cfg_data[0:31], cfg_data[0:31]};
    end
`ifdef _TRACE_
	// ... put trace stuff here ...
`endif
    else if (mmio_read_l) 
	begin
      mmio_rd_data <= trace_options_reg;
    end else
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
`ifdef _TRACE_
	// ... put trace stuff here ...
`else
  always @ (posedge ha_pclock)
    mmio_ack <= cfg_read_l || cfg_write_l || mmio_read_l || mmio_write_l;
`endif
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

`ifdef _TRACE_
	// ... put trace stuff here ...
`endif
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
