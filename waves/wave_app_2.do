onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group {command interface} /top/ah_cvalid
add wave -noupdate -expand -group {command interface} /top/ah_ctag
add wave -noupdate -expand -group {command interface} /top/ah_ctagpar
add wave -noupdate -expand -group {command interface} /top/ah_com
add wave -noupdate -expand -group {command interface} /top/ah_compar
add wave -noupdate -expand -group {command interface} /top/ah_cabt
add wave -noupdate -expand -group {command interface} /top/ah_cea
add wave -noupdate -expand -group {command interface} /top/ah_ceapar
add wave -noupdate -expand -group {command interface} /top/ah_csize
add wave -noupdate -expand -group {command interface} /top/ha_croom
add wave -noupdate -expand -group {buffer interface} /top/ha_brvalid
add wave -noupdate -expand -group {buffer interface} /top/ha_brtag
add wave -noupdate -expand -group {buffer interface} /top/ha_brtagpar
add wave -noupdate -expand -group {buffer interface} /top/ha_brad
add wave -noupdate -expand -group {buffer interface} /top/ah_brlat
add wave -noupdate -expand -group {buffer interface} /top/ah_brdata
add wave -noupdate -expand -group {buffer interface} /top/ah_brpar
add wave -noupdate -expand -group {buffer interface} /top/ha_bwvalid
add wave -noupdate -expand -group {buffer interface} /top/ha_bwtag
add wave -noupdate -expand -group {buffer interface} /top/ha_bwtagpar
add wave -noupdate -expand -group {buffer interface} /top/ha_bwad
add wave -noupdate -expand -group {buffer interface} -radix hexadecimal /top/ha_bwdata
add wave -noupdate -expand -group {buffer interface} /top/ha_bwpar
add wave -noupdate -expand -group {Response interface} /top/ha_rvalid
add wave -noupdate -expand -group {Response interface} /top/ha_rtag
add wave -noupdate -expand -group {Response interface} /top/ha_rtagpar
add wave -noupdate -expand -group {Response interface} /top/ha_response
add wave -noupdate -expand -group {Response interface} /top/ha_rcredits
add wave -noupdate -expand -group {Response interface} /top/ha_rcachestate
add wave -noupdate -expand -group {Response interface} /top/ha_rcachepos
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmval
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmrnw
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmdw
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmad
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmadpar
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmdata
add wave -noupdate -expand -group {MMIO interface} /top/ha_mmdatapar
add wave -noupdate -expand -group {MMIO interface} /top/ah_mmack
add wave -noupdate -expand -group {MMIO interface} /top/ah_mmdata
add wave -noupdate -expand -group {Control interface} /top/ha_jval
add wave -noupdate -expand -group {Control interface} /top/ha_jcom
add wave -noupdate -expand -group {Control interface} /top/ha_jcompar
add wave -noupdate -expand -group {Control interface} /top/ha_jea
add wave -noupdate -expand -group {Control interface} /top/ha_jeapar
add wave -noupdate -expand -group {Control interface} /top/ah_jrunning
add wave -noupdate -expand -group {Control interface} /top/ah_jdone
add wave -noupdate -expand -group {Control interface} /top/ah_jerror
add wave -noupdate -expand -group {Control interface} /top/ah_paren
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_idle
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_premmio
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_rd_req
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_rd_wait
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_wr_req
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_wr_wait
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_mv_rd_req
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_mv_wr_req
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_done_req
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_done_wait
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_done
add wave -noupdate -group {Job FSM} /top/a0/j0/job_st_postmmio
add wave -noupdate -group {DMA FSM} /top/a0/d0/misc_st_idle
add wave -noupdate -group {DMA FSM} /top/a0/d0/misc_st_start
add wave -noupdate -group {DMA FSM} /top/a0/d0/misc_st_data
add wave -noupdate -group {DMA FSM} /top/a0/d0/misc_st_request
add wave -noupdate -group {DMA FSM} /top/a0/d0/misc_st_response
add wave -noupdate -group {DMA FSM} /top/a0/d0/read_st_idle
add wave -noupdate -group {DMA FSM} /top/a0/d0/read_st_request
add wave -noupdate -group {DMA FSM} /top/a0/d0/read_st_wait
add wave -noupdate -group {DMA FSM} /top/a0/d0/write_st_idle
add wave -noupdate -group {DMA FSM} /top/a0/d0/write_st_request
add wave -noupdate -group {DMA FSM} /top/a0/d0/write_st_wait
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmval
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmcfg
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmrnw
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdw
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmad
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmadpar
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdatapar
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmack
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmdatapar
add wave -noupdate -group {MMIO signals} /top/a0/m0/parity_error
add wave -noupdate -group {MMIO signals} /top/a0/m0/odd_parity
add wave -noupdate -group {MMIO signals} /top/a0/m0/reset
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_pclock
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_wtag
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_wtag
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/jcontrol_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/jcontrol_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/done_premmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/done_postmmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/start_premmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/start_postmmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmval
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmcfg
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmrnw
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdw
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmad
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmadpar
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_mmdatapar
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmack
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/ah_mmdatapar
add wave -noupdate -group {MMIO signals} /top/a0/m0/parity_error
add wave -noupdate -group {MMIO signals} /top/a0/m0/odd_parity
add wave -noupdate -group {MMIO signals} /top/a0/m0/reset
add wave -noupdate -group {MMIO signals} /top/a0/m0/ha_pclock
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_wtag
add wave -noupdate -group {MMIO signals} /top/a0/m0/command_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_wtag
add wave -noupdate -group {MMIO signals} /top/a0/m0/response_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/jcontrol_trace_val
add wave -noupdate -group {MMIO signals} /top/a0/m0/jcontrol_trace_wdata
add wave -noupdate -group {MMIO signals} /top/a0/m0/done_premmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/done_postmmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/start_premmio
add wave -noupdate -group {MMIO signals} /top/a0/m0/start_postmmio
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jval
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jcom
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jcompar
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jea
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jeapar
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jrunning
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jdone
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jerror
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_pclock
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_req
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_com
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_wr_data
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_rd_data
add wave -noupdate -group {JOB signals} /top/a0/j0/read_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/read_req
add wave -noupdate -group {JOB signals} /top/a0/j0/read_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/read_size
add wave -noupdate -group {JOB signals} /top/a0/j0/write_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/write_req
add wave -noupdate -group {JOB signals} /top/a0/j0/write_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/write_size
add wave -noupdate -group {JOB signals} /top/a0/j0/reset
add wave -noupdate -group {JOB signals} /top/a0/j0/done
add wave -noupdate -group {JOB signals} /top/a0/j0/odd_parity
add wave -noupdate -group {JOB signals} /top/a0/j0/detect_err
add wave -noupdate -group {JOB signals} /top/a0/j0/done_premmio
add wave -noupdate -group {JOB signals} /top/a0/j0/done_postmmio
add wave -noupdate -group {JOB signals} /top/a0/j0/start_premmio
add wave -noupdate -group {JOB signals} /top/a0/j0/start_postmmio
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jval
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jcom
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jcompar
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jea
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_jeapar
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jrunning
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jdone
add wave -noupdate -group {JOB signals} /top/a0/j0/ah_jerror
add wave -noupdate -group {JOB signals} /top/a0/j0/ha_pclock
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_req
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_com
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_wr_data
add wave -noupdate -group {JOB signals} /top/a0/j0/misc_rd_data
add wave -noupdate -group {JOB signals} /top/a0/j0/read_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/read_req
add wave -noupdate -group {JOB signals} /top/a0/j0/read_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/read_size
add wave -noupdate -group {JOB signals} /top/a0/j0/write_ready
add wave -noupdate -group {JOB signals} /top/a0/j0/write_req
add wave -noupdate -group {JOB signals} /top/a0/j0/write_addr
add wave -noupdate -group {JOB signals} /top/a0/j0/write_size
add wave -noupdate -group {JOB signals} /top/a0/j0/reset
add wave -noupdate -group {JOB signals} /top/a0/j0/done
add wave -noupdate -group {JOB signals} /top/a0/j0/odd_parity
add wave -noupdate -group {JOB signals} /top/a0/j0/detect_err
add wave -noupdate -group {JOB signals} /top/a0/j0/done_premmio
add wave -noupdate -group {JOB signals} /top/a0/j0/done_postmmio
add wave -noupdate -group {JOB signals} /top/a0/j0/start_premmio
add wave -noupdate -group {JOB signals} /top/a0/j0/start_postmmio
add wave -noupdate -divider {DMA signals}
add wave -noupdate -group WED /top/a0/d0/misc_ready
add wave -noupdate -group WED /top/a0/d0/misc_req
add wave -noupdate -group WED /top/a0/d0/misc_ch
add wave -noupdate -group WED /top/a0/d0/misc_addr
add wave -noupdate -group WED /top/a0/d0/misc_com
add wave -noupdate -group WED /top/a0/d0/misc_wr_data
add wave -noupdate -group WED /top/a0/d0/misc_rd_data
add wave -noupdate -expand -group READ /top/a0/d0/read_ready
add wave -noupdate -expand -group READ /top/a0/d0/read_req
add wave -noupdate -expand -group READ /top/a0/d0/read_ch
add wave -noupdate -expand -group READ /top/a0/d0/read_addr
add wave -noupdate -expand -group READ /top/a0/d0/read_size
add wave -noupdate -expand -group READ /top/a0/d0/read_data_ready
add wave -noupdate -expand -group READ /top/a0/d0/read_data
add wave -noupdate -expand -group READ /top/a0/d0/read_data_ack
add wave -noupdate -expand -group WRITE /top/a0/d0/write_ready
add wave -noupdate -expand -group WRITE /top/a0/d0/write_req
add wave -noupdate -expand -group WRITE /top/a0/d0/write_ch
add wave -noupdate -expand -group WRITE /top/a0/d0/write_addr
add wave -noupdate -expand -group WRITE /top/a0/d0/write_size
add wave -noupdate -expand -group WRITE /top/a0/d0/write_data_ready
add wave -noupdate -expand -group WRITE /top/a0/d0/write_data
add wave -noupdate -expand -group WRITE /top/a0/d0/write_data_ack
add wave -noupdate -expand -group {State machine} /top/a0/seq_reg
add wave -noupdate -expand -group {State machine} /top/a0/seq_length
add wave -noupdate -expand -group {State machine} /top/a0/read_ack
add wave -noupdate -expand -group {State machine} /top/a0/little_endian
add wave -noupdate -expand -group {State machine} /top/a0/index_s
add wave -noupdate -expand -group {State machine} /top/a0/length_w
add wave -noupdate -expand -group {State machine} /top/a0/sequence_w
add wave -noupdate -expand -group {State machine} /top/a0/enable_s
add wave -noupdate -expand -group {State machine} /top/a0/enable_c
add wave -noupdate -expand -group {State machine} /top/a0/valid_s
add wave -noupdate -expand -group {State machine} /top/a0/result_s
add wave -noupdate -expand -group {State machine} /top/a0/result_r
add wave -noupdate -expand -group {State machine} /top/a0/write_data_out
add wave -noupdate -expand -group {State machine} /top/a0/write_data_ack
add wave -noupdate -expand -group {State machine} /top/a0/base_cnt
add wave -noupdate -expand -group {State machine} /top/a0/scoring_state
add wave -noupdate -group {Scoring module} /top/a0/DUT/rst
add wave -noupdate -group {Scoring module} /top/a0/DUT/en_in
add wave -noupdate -group {Scoring module} /top/a0/DUT/data_in
add wave -noupdate -group {Scoring module} /top/a0/DUT/query
add wave -noupdate -group {Scoring module} /top/a0/DUT/output_select
add wave -noupdate -group {Scoring module} /top/a0/DUT/match
add wave -noupdate -group {Scoring module} /top/a0/DUT/mismatch
add wave -noupdate -group {Scoring module} /top/a0/DUT/gap_open
add wave -noupdate -group {Scoring module} /top/a0/DUT/gap_extend
add wave -noupdate -group {Scoring module} /top/a0/DUT/result
add wave -noupdate -group {Scoring module} /top/a0/DUT/vld
add wave -noupdate -group {Scoring module} /top/a0/DUT/high_
add wave -noupdate -group {Scoring module} /top/a0/DUT/M_
add wave -noupdate -group {Scoring module} /top/a0/DUT/I_
add wave -noupdate -group {Scoring module} /top/a0/DUT/vld_
add wave -noupdate -group {Scoring module} /top/a0/DUT/en_
add wave -noupdate -group {Scoring module} /top/a0/DUT/data_
add wave -noupdate -divider {END of DMA signals}
add wave -noupdate /top/ha_pclock
add wave -noupdate /top/ha_pclock
add wave -noupdate -divider {DMA signals}
add wave -noupdate /top/a0/d0/reset
add wave -noupdate /top/a0/d0/odd_parity
add wave -noupdate /top/a0/d0/idle
add wave -noupdate /top/a0/d0/parity_err
add wave -noupdate /top/a0/d0/resp_err
add wave -noupdate /top/a0/d0/ah_cvalid
add wave -noupdate /top/a0/d0/ah_ctag
add wave -noupdate /top/a0/d0/ah_ctagpar
add wave -noupdate /top/a0/d0/ah_com
add wave -noupdate /top/a0/d0/ah_compar
add wave -noupdate /top/a0/d0/ah_cabt
add wave -noupdate /top/a0/d0/ah_cea
add wave -noupdate /top/a0/d0/ah_ceapar
add wave -noupdate /top/a0/d0/ah_cch
add wave -noupdate /top/a0/d0/ah_csize
add wave -noupdate /top/a0/d0/ha_croom
add wave -noupdate /top/a0/d0/ha_brvalid
add wave -noupdate /top/a0/d0/ha_brtag
add wave -noupdate /top/a0/d0/ha_brtagpar
add wave -noupdate /top/a0/d0/ha_brad
add wave -noupdate /top/a0/d0/ah_brlat
add wave -noupdate /top/a0/d0/ah_brdata
add wave -noupdate /top/a0/d0/ah_brpar
add wave -noupdate /top/a0/d0/ha_bwvalid
add wave -noupdate /top/a0/d0/ha_bwtag
add wave -noupdate /top/a0/d0/ha_bwtagpar
add wave -noupdate /top/a0/d0/ha_bwad
add wave -noupdate /top/a0/d0/ha_bwdata
add wave -noupdate /top/a0/d0/ha_bwpar
add wave -noupdate /top/a0/d0/ha_rvalid
add wave -noupdate /top/a0/d0/ha_rtag
add wave -noupdate /top/a0/d0/ha_rtagpar
add wave -noupdate /top/a0/d0/ha_response
add wave -noupdate /top/a0/d0/ha_rcredits
add wave -noupdate /top/a0/d0/ha_pclock
add wave -noupdate -divider {END of DMA signals}
add wave -noupdate /top/ah_mmack
add wave -noupdate /top/ah_mmdata
add wave -noupdate /top/ha_jval
add wave -noupdate /top/ha_jcom
add wave -noupdate /top/ha_jcompar
add wave -noupdate /top/ha_jea
add wave -noupdate /top/ha_jeapar
add wave -noupdate /top/ah_jrunning
add wave -noupdate /top/ah_jdone
add wave -noupdate /top/ah_jerror
add wave -noupdate /top/ah_paren
add wave -noupdate /top/a0/j0/job_st_idle
add wave -noupdate /top/a0/j0/job_st_premmio
add wave -noupdate /top/a0/j0/job_st_rd_req
add wave -noupdate /top/a0/j0/job_st_rd_wait
add wave -noupdate /top/ha_pclock
add wave -noupdate /top/a0/j0/job_st_idle
add wave -noupdate /top/a0/j0/job_st_premmio
add wave -noupdate /top/a0/j0/job_st_rd_req
add wave -noupdate /top/a0/j0/job_st_rd_wait
add wave -noupdate /top/a0/j0/job_st_wr_req
add wave -noupdate /top/a0/j0/job_st_wr_wait
add wave -noupdate /top/a0/j0/job_st_mv_rd_req
add wave -noupdate /top/a0/j0/job_st_mv_wr_req
add wave -noupdate /top/a0/j0/job_st_done_req
add wave -noupdate /top/a0/j0/job_st_done_wait
add wave -noupdate /top/a0/j0/job_st_done
add wave -noupdate /top/a0/j0/job_st_postmmio
add wave -noupdate /top/a0/d0/misc_st_idle
add wave -noupdate /top/a0/d0/misc_st_start
add wave -noupdate /top/a0/d0/misc_st_data
add wave -noupdate /top/a0/d0/misc_st_request
add wave -noupdate /top/a0/d0/misc_st_response
add wave -noupdate /top/a0/d0/read_st_idle
add wave -noupdate /top/a0/d0/read_st_request
add wave -noupdate /top/a0/d0/read_st_wait
add wave -noupdate /top/a0/d0/write_st_idle
add wave -noupdate /top/a0/d0/write_st_request
add wave -noupdate /top/a0/d0/write_st_wait
add wave -noupdate /top/ha_pclock
add wave -noupdate /top/ah_cvalid
add wave -noupdate /top/ah_ctag
add wave -noupdate /top/ah_ctagpar
add wave -noupdate /top/ah_com
add wave -noupdate /top/ah_compar
add wave -noupdate /top/ah_cabt
add wave -noupdate /top/ah_cea
add wave -noupdate /top/ah_ceapar
add wave -noupdate /top/ah_csize
add wave -noupdate /top/ha_croom
add wave -noupdate /top/ha_brvalid
add wave -noupdate /top/ha_brtag
add wave -noupdate /top/ha_brtagpar
add wave -noupdate /top/ha_brad
add wave -noupdate /top/ah_brlat
add wave -noupdate /top/ah_brdata
add wave -noupdate /top/ah_brpar
add wave -noupdate /top/ha_bwvalid
add wave -noupdate /top/ha_bwtag
add wave -noupdate /top/ha_bwtagpar
add wave -noupdate /top/ha_bwad
add wave -noupdate /top/ha_bwdata
add wave -noupdate /top/ha_bwpar
add wave -noupdate /top/ha_rvalid
add wave -noupdate /top/ha_rtag
add wave -noupdate /top/ha_rtagpar
add wave -noupdate /top/ha_response
add wave -noupdate /top/ha_rcredits
add wave -noupdate /top/ha_rcachestate
add wave -noupdate /top/ha_rcachepos
add wave -noupdate /top/ha_mmval
add wave -noupdate /top/ha_mmrnw
add wave -noupdate /top/ha_mmdw
add wave -noupdate /top/ha_mmad
add wave -noupdate /top/ha_mmadpar
add wave -noupdate /top/ha_mmdata
add wave -noupdate /top/ha_mmdatapar
add wave -noupdate /top/ah_mmack
add wave -noupdate /top/ah_mmdata
add wave -noupdate /top/ha_jval
add wave -noupdate /top/ha_jcom
add wave -noupdate /top/ha_jcompar
add wave -noupdate /top/ha_jea
add wave -noupdate /top/ha_jeapar
add wave -noupdate /top/ah_jrunning
add wave -noupdate /top/ah_jdone
add wave -noupdate /top/ah_jerror
add wave -noupdate /top/ah_paren
add wave -noupdate /top/a0/j0/job_st_idle
add wave -noupdate /top/a0/j0/job_st_premmio
add wave -noupdate /top/a0/j0/job_st_rd_req
add wave -noupdate /top/a0/j0/job_st_rd_wait
add wave -noupdate /top/a0/j0/job_st_wr_req
add wave -noupdate /top/a0/j0/job_st_wr_wait
add wave -noupdate /top/a0/j0/job_st_mv_rd_req
add wave -noupdate /top/a0/j0/job_st_mv_wr_req
add wave -noupdate /top/a0/j0/job_st_done_req
add wave -noupdate /top/a0/j0/job_st_done_wait
add wave -noupdate /top/a0/j0/job_st_done
add wave -noupdate /top/a0/j0/job_st_postmmio
add wave -noupdate /top/a0/d0/misc_st_idle
add wave -noupdate /top/a0/d0/misc_st_start
add wave -noupdate /top/a0/d0/misc_st_data
add wave -noupdate /top/a0/d0/misc_st_request
add wave -noupdate /top/a0/d0/misc_st_response
add wave -noupdate /top/a0/d0/read_st_idle
add wave -noupdate /top/a0/d0/read_st_request
add wave -noupdate /top/a0/d0/read_st_wait
add wave -noupdate /top/a0/d0/write_st_idle
add wave -noupdate /top/a0/d0/write_st_request
add wave -noupdate /top/a0/d0/write_st_wait
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {125 ns} 0} {{Cursor 2} {17611 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 291
configure wave -valuecolwidth 166
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {20 ns} {323 ns}
