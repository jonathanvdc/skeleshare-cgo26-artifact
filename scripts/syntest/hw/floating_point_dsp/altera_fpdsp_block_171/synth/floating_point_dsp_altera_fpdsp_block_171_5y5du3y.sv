module floating_point_dsp_altera_fpdsp_block_171_5y5du3y  (
    input  wire                          clk,
    input  wire                          ena,
    input  wire                          aclr,
    input  wire [31:0]                   ay,
    input  wire [31:0]                   az,
    output wire [31:0]                   result

	);
    wire [1-1:0] clk_vec;
    wire [1-1:0] ena_vec;
    wire [1:0]                   aclr_vec;
    assign clk_vec[0] = clk;
    assign ena_vec[0] = ena;
    assign aclr_vec[1] = aclr;
    assign aclr_vec[0] = aclr;

twentynm_fp_mac  #(
    .ax_clock("NONE"),
    .ay_clock("0"),
    .az_clock("0"),
    .output_clock("0"),
    .accumulate_clock("NONE"),
    .ax_chainin_pl_clock("NONE"),
    .accum_pipeline_clock("NONE"),
    .mult_pipeline_clock("0"),
    .adder_input_clock("0"),
    .accum_adder_clock("NONE"),
    .use_chainin("false"),
    .operation_mode("sp_mult"),
    .adder_subtract("false")
) sp_mult (
    .clk({1'b0,1'b0,clk_vec[0]}),
    .ena({1'b0,1'b0,ena_vec[0]}),
    .aclr(aclr_vec),
    .ay(ay),
    .az(az),

    .chainin(32'b0),
    .resulta(result),
    .chainout()
);
endmodule

