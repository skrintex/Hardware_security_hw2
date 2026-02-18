module noise_gen (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] rnd32,
    input  logic        en,
    output logic [127:0] noise_state
);
    logic fb;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            noise_state <= 128'h1;
        end else if (en) begin
            fb <= rnd32[0] ^ rnd32[5] ^ rnd32[9] ^ rnd32[31];
            noise_state <= {noise_state[126:0], fb};
        end
    end
endmodule