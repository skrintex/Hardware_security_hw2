// Filename: aes_ec_tb.sv
//
// Copyright (c) 2013, Intel Corporation
// All rights reserved

module aes_ec_tb #(parameter Nk=4)
(
    output bit done
);

import aes_dpi_pkg::*;

int NUM_VECS = 1000;
int r;
int mismatch_count = 0;

bit clk;
bit rst_n = 1'b1;

bit key_ready = 1'b0;
bit producer_done = 1'b0;
bit consumer_done = 1'b0;

logic [32*Nk-1:0] key;

logic load = 0;
logic [127:0] pt;

logic [127:0] ct;
logic valid;

bit [127:0] vecs [$];
bit [127:0] ct_gold;

// File handle for OpenSSL verification dump
int dump_fd;
string dump_fname;

initial r = $value$plusargs("NUM_VECS=%d", NUM_VECS);

// ---------------------------------------------------------------
// Hex print helpers
// ---------------------------------------------------------------

task automatic print_ascii16(input logic [127:0] x);
  $write("\"");
  for (int b = 15; b >= 0; b--) begin
    byte c = x[b*8 +: 8];
    if (c >= 32 && c <= 126) $write("%c", c);
    else $write(".");
  end
  $write("\"\n");
endtask

task automatic print_hex_stream_128(input logic [127:0] x);
  for (int b = 0; b < 16; b++) begin
    $write("%02x", x[b*8 +: 8]);
  end
  $write("\n");
endtask

task automatic print_hex_stream_key(input logic [32*Nk-1:0] k);
  for (int b = 0; b < 4*Nk; b++) begin
    $write("%02x", k[b*8 +: 8]);
  end
  $write("\n");
endtask

// ---------------------------------------------------------------
// Dump helpers for OpenSSL checker
//
// Key byte order: word-by-word, MSByte first within each word.
// This produces the big-endian FIPS / OpenSSL -K hex string.
//   Word 0 = key[31:0]  → print key[31:24], key[23:16], key[15:8], key[7:0]
//   Word 1 = key[63:32] → print key[63:56], key[55:48], key[47:40], key[39:32]
//   ...
//
// PT / CT byte order: key[b*8+:8] for b=0..15 (LSByte first).
// This matches the FIPS state layout that OpenSSL also uses for -in bytes.
// ---------------------------------------------------------------

function automatic string key_to_openssl_hex(input logic [32*Nk-1:0] k);
  string s = "";
  string tmp;
  for (int w = 0; w < Nk; w++)
    for (int b = 3; b >= 0; b--) begin
      tmp.itoa(k[(w*32 + b*8) +: 8]);  // placeholder — see $sformatf below
      s = {s, $sformatf("%02x", k[(w*32 + b*8) +: 8])};
    end
  return s;
endfunction

function automatic string bytes128_to_hex(input logic [127:0] x);
  string s = "";
  for (int b = 0; b < 16; b++)
    s = {s, $sformatf("%02x", x[b*8 +: 8])};
  return s;
endfunction

task automatic dump_vector(
    input logic [32*Nk-1:0] k,
    input logic [127:0]     p,
    input logic [127:0]     c
);
  $fdisplay(dump_fd, "%s %s %s %0d",
            key_to_openssl_hex(k),
            bytes128_to_hex(p),
            bytes128_to_hex(c),
            Nk);
endtask

// ---------------------------------------------------------------
// Setup: reset DUT, pick random key, open dump file
// ---------------------------------------------------------------
initial begin: setup

    rst_n = 1'b0;
    repeat(4) @(posedge clk) #1;

    rst_n = 1'b1;
    repeat(4) @(posedge clk) #1;

    for (int i = 0; i < Nk; ++i)
        key[32*i+:32] = $urandom();
    repeat(4) @(posedge clk) #1;

    // Open per-instance dump file: vectors_Nk<N>.txt
    dump_fname = $sformatf("vectors_Nk%0d.txt", Nk);
    dump_fd = $fopen(dump_fname, "w");
    if (dump_fd == 0) begin
        $fatal(1, "ERROR: could not open %s for writing", dump_fname);
    end

    key_ready = 1'b1;

end: setup

// ---------------------------------------------------------------
// Producer: drive random plaintexts into DUT
// ---------------------------------------------------------------
initial begin: producer

    wait (key_ready);

    for (int i = 0; i < NUM_VECS; ++i) begin
        load = 1'b1;
        for (int j = 0; j < 4; ++j)
            pt[32*j+:32] = $urandom();
        vecs.push_front(pt);

        @(posedge clk) #1;
        load = 1'b0;
    end

    producer_done = 1'b1;

end: producer

// ---------------------------------------------------------------
// Consumer: collect DUT outputs, check against DPI reference,
//           dump (key, pt, ct) tuples to file for OpenSSL check
// ---------------------------------------------------------------
initial begin: consumer

    int count;
    bit [127:0] pt_ref;

    wait (key_ready);

    count = 0;
    while (count < NUM_VECS) begin
        @(posedge clk) #1;

        if (valid) begin
            pt_ref = vecs.pop_back();
            aes_encrypt_dpi(Nk, ct_gold, pt_ref, key);

            // --- debug print for first 5 vectors ---
            if (count < 5) begin
                $write("key=");   print_hex_stream_key(key);
                $write("pt=");    print_hex_stream_128(pt_ref);
                $write("ct=");    print_hex_stream_128(ct);
                $write("gold=");  print_hex_stream_128(ct_gold);
                $display("");
            end

            // --- functional check vs DPI reference (non-fatal so all vectors dump) ---
            if (ct !== ct_gold) begin
                $display("[Nk=%0d vec %0d] DUT ct MISMATCH: got %032h expected %032h",
                         Nk, count, ct, ct_gold);
                mismatch_count += 1;
            end

            // --- dump vector for OpenSSL cross-check ---
            dump_vector(key, pt_ref, ct);

            count += 1;
        end
    end

    $fclose(dump_fd);
    $display("[aes_ec_tb Nk=%0d] Dumped %0d vectors to %s (%0d DUT mismatches vs DPI ref)",
             Nk, NUM_VECS, dump_fname, mismatch_count);

    consumer_done = 1'b1;

end: consumer

clk_gen clocks(.*);
aes_encrypt #(Nk) dut(.*);

always_comb done = producer_done & consumer_done;

endmodule: aes_ec_tb
