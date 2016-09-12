# Verilog code for calculating the Smith-Waterman score on FPGA
This code models a Smith-Waterman alignment score pipeline. The design is adapted for FPGA implementations.

# Folder structure:

	./AFU-capi_mem_cpy_example 	-> contains HDL from the IBM's "mem_cpy" example
	./capi_sample_aligner 		-> contains of the sample CAPI aligner, which was built for test purposes
	./CAPI_template 			-> template code for interfacing the ScoreBank with CAPI (could not finish this in time)
	./data 						-> contains the data used for the testbenches
	./ScoreBank					-> contains the optimized Smith-Waterman pipeline, together with the necessary testbenches
	./modelsim					-> modelsim projects for each design
	./waves						-> waves for different modelsim	projects
	./explored_designs			-> previous iterations of the modules
	
