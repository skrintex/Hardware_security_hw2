module aes128 (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         start,       // pulse
    input  logic [127:0] key,
    input  logic [127:0] plaintext,

    output logic         done,        // pulse
    output logic [127:0] ciphertext
);

    // ----------------------------
    // Latch inputs at start
    // ----------------------------
    logic [127:0] key_lat;
    logic [127:0] pt_lat;

    // ----------------------------
    // RNG: simple free-running LFSR32
    // (good enough for delay/hiding; not crypto RNG)
    // ----------------------------
    logic [31:0] rnd32;
    logic        lfsr_fb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rnd32 <= 32'h1; // nonzero seed
        end else begin
            // taps example: 32,22,2,1
            lfsr_fb <= rnd32[31] ^ rnd32[21] ^ rnd32[1] ^ rnd32[0];
            rnd32   <= {rnd32[30:0], lfsr_fb};
        end
    end

    // ----------------------------
    // Random delay controller
    // ----------------------------
    typedef enum logic [1:0] {IDLE, DELAY, RUN} state_t;
    state_t state;

    logic [3:0] delay_cnt;
    logic       load_int;       // pulse into aes_encrypt
    logic       active;         // enable noise during DELAY/RUN

    always_comb begin
        active = (state != IDLE);
    end

    // Accept start only when idle (single-flight)
    logic start_acc;
    always_comb begin
        start_acc = start && (state == IDLE);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            delay_cnt <= 4'd0;
            load_int  <= 1'b0;
            key_lat   <= '0;
            pt_lat    <= '0;
        end else begin
            load_int <= 1'b0; // default: pulse low

            case (state)
                IDLE: begin
                    if (start_acc) begin
                        key_lat <= key;
                        pt_lat  <= plaintext;

                        delay_cnt <= rnd32[3:0];
                        if (rnd32[3:0] == 4'd0) begin
                            load_int <= 1'b1;
                            state    <= RUN;
                        end else begin
                            state <= DELAY;
                        end
                    end
                end

                DELAY: begin
                    if (delay_cnt == 4'd1) begin
                        delay_cnt <= 4'd0;
                        load_int  <= 1'b1;
                        state     <= RUN;
                    end else begin
                        delay_cnt <= delay_cnt - 4'd1;
                    end
                end

                RUN: begin
                    // wait for core to assert valid
                    if (valid_core) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ----------------------------
    // AES core (baseline)
    // ----------------------------
    logic [127:0] ct_core;
    logic         valid_core;

    aes_encrypt #(.Nk(4)) u_aes (
        .clk   (clk),
        .rst_n (rst_n),
        .key   (key_lat),
        .load  (load_int),
        .pt    (pt_lat),
        .ct    (ct_core),
        .valid (valid_core)
    );

    assign ciphertext = ct_core;

    // done pulse = rising edge of valid_core
    logic valid_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_d <= 1'b0;
            done    <= 1'b0;
        end else begin
            valid_d <= valid_core;
            done    <= valid_core & ~valid_d;
        end
    end

    // ----------------------------
    // Noise generator (parallel switching)
    // ----------------------------
    (* keep = "true" *) logic [127:0] noise_state;
    (* keep = "true" *) logic         noise_sink;

    noise_gen u_noise (
        .clk         (clk),
        .rst_n       (rst_n),
        .rnd32       (rnd32),
        .en          (active),
        .noise_state (noise_state)
    );

    // Sink so synthesis doesn't delete the noise network as "unused"
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            noise_sink <= 1'b0;
        end else if (active) begin
            noise_sink <= noise_sink ^ (^noise_state);
        end
    end

endmodule
