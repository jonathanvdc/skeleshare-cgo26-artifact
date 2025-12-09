// ***************************************************************************
// Copyright (c) 2013-2018, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// ***************************************************************************
//
// Module Name:  afu.sv
// Project:      Hello AFU
// Description:  Hello AFU supports MMIO Writes and Reads.
//
// Hello_AFU is provided as a starting point for developing AFUs.
//
// It is strongly recommended:
// - register all AFU inputs and outputs
// - output registers should be initialized with a reset
// - Host Writes and Reads must be sent on Virtual Channel (VC): VH0 - PCIe0 link
// - MMIO addressing must be QuardWord Aligned (Quadword = 8 bytes)
// - AFU_ID must be re-generated for new AFUs.
//
// Please see the CCI-P specification for more information about the CCI-P interfaces.
// AFU template provides 4 AFU CSR registers required by the CCI-P protocol(see
// specification for more information) and a scratch register to issue MMIO Writes and Reads.
//
// Scratch_Reg[63:0] @ Byte Address 0x0080 is provided to test MMIO Reads and Writes to the AFU.
//

`include "platform_if.vh"
`include "afu_json_info.vh"

module afu
   (
    input  clk,    // Core clock. CCI interface is synchronous to this clock.
    input  reset,  // CCI interface ACTIVE HIGH reset.

    // CCI-P signals
    input  t_if_ccip_Rx sRx,
    output t_if_ccip_Tx sTx
    );

    // The AFU must respond with its AFU ID in response to MMIO reads of
    // the CCI-P device feature header (DFH).  The AFU ID is a unique ID
    // for a given program.  Here we generated one with the "uuidgen"
    // program and stored it in the AFU's JSON file.  ASE and synthesis
    // setup scripts automatically invoke the OPAE afu_json_mgr script
    // to extract the UUID into afu_json_info.vh.
    logic [127:0] afu_id = `AFU_ACCEL_UUID;

    // The c0 header is normally used for memory read responses.
    // The header must be interpreted as an MMIO response when
    // c0 mmmioRdValid or mmioWrValid is set.  In these cases the
    // c0 header is cast into a ReqMmioHdr.
    t_ccip_c0_ReqMmioHdr mmioHdr;
    assign mmioHdr = t_ccip_c0_ReqMmioHdr'(sRx.c0.hdr);

    // reset reserved signals to 0
    assign sTx.c0.hdr.rsvd0 = '0; // "000000"
    assign sTx.c0.hdr.rsvd1 = '0; // "00"
    assign sTx.c1.hdr.rsvd0 = '0; // "000000"
    assign sTx.c1.hdr.rsvd1 = '0; // "0"
    assign sTx.c1.hdr.rsvd2 = '0; // "000000"
    // is already driven: assign mmioHdr.rsvd = '0; // "0"

    // use curly braces for signals to convert Verilog enums to arrays, which are similar to std_logic_vector in VHDL!

    lift_acc liftunit (

        .clk(clk),
        .reset(reset),
        .afu_id(afu_id),

        .read_req_vc_sel({sTx.c0.hdr.vc_sel}),
        .read_req_cl_len({sTx.c0.hdr.cl_len}),
        .read_req_type({sTx.c0.hdr.req_type}),
        .read_req_address({sTx.c0.hdr.address}),
        .read_req_mdata({sTx.c0.hdr.mdata}),
        .read_req_valid({sTx.c0.valid}),
        .read_req_alm_full({sRx.c0TxAlmFull}),

        .read_rsp_vc_used({sRx.c0.hdr.vc_used}),
        // sRx.c0.hdr.rscv1 = '0; // "0"
        .read_rsp_hit_miss({sRx.c0.hdr.hit_miss}),
        // causes errors .read_rsp_error({sRx.c0.hdr.error}),
        // sRx.c0.hdr.rscv0 = '0; // "0"
        .read_rsp_cl_num({sRx.c0.hdr.cl_num}),
        .read_rsp_type({sRx.c0.hdr.resp_type}),
        .read_rsp_mdata({sRx.c0.hdr.mdata}),
        .read_rsp_data({sRx.c0.data}),
        .read_rsp_valid({sRx.c0.rspValid}),

        // causes errors .write_req_byte_len({sTx.c1.hdr.byte_len}),
        .write_req_vc_sel({sTx.c1.hdr.vc_sel}),
        .write_req_sop({sTx.c1.hdr.sop}),
        // causes errors .write_req_mode({sTx.c1.hdr.mode}),
        .write_req_cl_len({sTx.c1.hdr.cl_len}),
        .write_req_type({sTx.c1.hdr.req_type}),
        // causes errors .write_req_byte_start(sTx.c1.hdr.byte_start),
        .write_req_address({sTx.c1.hdr.address}),
        .write_req_mdata({sTx.c1.hdr.mdata}),
        .write_req_data({sTx.c1.data}),
        .write_req_valid({sTx.c1.valid}),
        .write_req_alm_full({sRx.c1TxAlmFull}),

        .write_rsp_vc_used({sRx.c1.hdr.vc_used}),
        // sRx.c1.hdr.rsvd1 = '0; // "0"
        .write_rsp_hit_miss({sRx.c1.hdr.hit_miss}),
        .write_rsp_format({sRx.c1.hdr.format}),
        // sRx.c1.hdr.rsvd0 = '0; // "0"
        .write_rsp_cl_num({sRx.c1.hdr.cl_num}),
        .write_rsp_type({sRx.c1.hdr.resp_type}),
        .write_rsp_mdata({sRx.c1.hdr.mdata}),
        .write_rsp_valid({sRx.c1.rspValid}),

        .mmio_req_address({mmioHdr.address}),
        .mmio_req_length({mmioHdr.length}),
        .mmio_req_tid({mmioHdr.tid}),
        .mmio_req_data({sRx.c0.data}),
        .mmio_req_read_valid({sRx.c0.mmioRdValid}),
        .mmio_req_write_valid({sRx.c0.mmioWrValid}),

        .mmio_rsp_tid({sTx.c2.hdr.tid}),
        .mmio_rsp_data({sTx.c2.data}),
        .mmio_rsp_read_valid({sTx.c2.mmioRdValid})
    );

endmodule
