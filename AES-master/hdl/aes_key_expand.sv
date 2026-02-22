// Filename: aes_key_expand.sv
//
// Copyright (c) 2013, Intel Corporation
// All rights reserved

`include "aes.svh"

module aes_key_expand
#(
    parameter Nk=4,
    parameter Nr=Nk+6
) (
    input logic [32*Nk-1:0] key,
    output logic [127:0] k_sch [0:Nr],
    output logic [7:0]   k_chk [0:Nr]
);

logic [31:0] temp [4*(Nr+1)];

generate
    for (genvar i = 0; i < Nk; ++i) begin
        always_comb
            temp[i] = key[32*i+:32];
    end

    for (genvar i = Nk; i < 4*(Nr+1); ++i) begin
        if (i % Nk == 0)
            always_comb
                temp[i] = temp[i-Nk]
                        ^ SubWord(RotWord(temp[i-1]))
                        ^ {24'h0, RCON[i/Nk]};
        else if (Nk > 6 && (i % Nk == 4))
            always_comb
                temp[i] = temp[i-Nk] ^ SubWord(temp[i-1]);
        else
            always_comb
                temp[i] = temp[i-Nk] ^ temp[i-1];
    end
endgenerate

generate
  for (genvar i = 0; i <= Nr; ++i) begin
    always_comb begin
        k_sch[i] = {temp[4*i+3], temp[4*i+2], temp[4*i+1], temp[4*i+0]};
        k_chk[i] = xor_bytes_128(k_sch[i]);
    end
  end
endgenerate

function automatic logic [7:0] xor_bytes_128(input logic [127:0] x);
    logic [7:0] s;
    s = 8'h00;
    for (int j = 0; j < 16; j++) s ^= x[j*8 +: 8];
    return s;
endfunction

endmodule: aes_key_expand
