// Author: Ilir Likalla


/* NOTES:
	- this module stores the results obtained by the ScoreBank module, and send them back to the main memory.
	- code based on VERILOG 2001 standard.
	- possible faults are associated by the comment "!X!"
*/


module ResBuffer
	#( parameter
		SIZE = 8, 							// buffer size
		RES_NUM = 4,						// number of results 
		SCORE_WIDTH = 12,					// result's width in bits
		ID_WIDTH = 48						// sequence's ID width in bits
	)(
	input clk,
	input rst,
	input [RES_NUM-1:0] vld_in,					// valid signals from the score bank
	input [RES_NUM*SCORE_WIDTH-1:0] result_in,	// results from the score bank
	input [RES_NUM*ID_WIDTH-1:0] ID_in,			// IDs from the score bank
