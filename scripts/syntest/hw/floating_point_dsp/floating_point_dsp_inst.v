	floating_point_dsp u0 (
		.aclr   (_connected_to_aclr_),   //   input,   width = 1,   aclr.aclr
		.ay     (_connected_to_ay_),     //   input,  width = 32,     ay.ay
		.az     (_connected_to_az_),     //   input,  width = 32,     az.az
		.clk    (_connected_to_clk_),    //   input,   width = 1,    clk.clk
		.ena    (_connected_to_ena_),    //   input,   width = 1,    ena.ena
		.result (_connected_to_result_)  //  output,  width = 32, result.result
	);

