// Filename: aes_encrypt.sv
//
// Copyright (c) 2013, Intel Corporation
// All rights reserved

`include "flops.svh"

module aes_encrypt
#(
    parameter Nk=4,
    parameter Nr=Nk+6
) (
    input logic clk,
    input logic rst_n,

    input logic [32*Nk-1:0] key,

    input logic load,
    input logic [127:0] pt,

    output logic [127:0] ct,
    output logic valid
);

logic [127:0] k_sch_w [0:Nr];
logic [7:0]   k_chk_w [0:Nr];

logic [127:0] k_sch_r [0:Nr];
logic [7:0]   k_chk_r [0:Nr];

logic load_d;
logic [127:0] pt_d;
`DFFEN_ARN(pt_d, pt, load, clk, rst_n, '0)
`DFF_ARN(load_d, load, clk, rst_n, 1'b0)

aes_key_expand #(Nk) key_expand(
    .key   (key),
    .k_sch (k_sch_w),
    .k_chk (k_chk_w)
);

aes_cipher #(Nk) cipher(
    .clk   (clk),
    .rst_n (rst_n),
    .k_sch (k_sch_r),
    .k_chk (k_chk_r),
    .load  (load_d),
    .pt    (pt_d),
    .ct    (ct),
    .valid (valid)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int r = 0; r <= Nr; r++) begin
        k_sch_r[r] <= '0;
        k_chk_r[r] <= '0;
        end
    end else if (load) begin
        for (int r = 0; r <= Nr; r++) begin
        k_sch_r[r] <= k_sch_w[r];
        k_chk_r[r] <= k_chk_w[r];
        end
    end
end
endmodule: aes_encrypt
