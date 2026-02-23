Advanced Encryption Standard (AES) SystemVerilog Core
=====================================================

# AES OpenSSL Verification Helper

This script verifies AES encryption results from RTL simulation using OpenSSL.

It compares:
- Key (hex)
- Plaintext (hex)
- Ciphertext (hex)

against OpenSSL AES-ECB output (no padding).

---

## Usage
Run by:
```bash
make vcs-sim
```

After running your RTL simulation, copy one of the printed values:

For example:
```bash
key=13e2293b702e2669fd339cfee2035d3d97b2ad20f1cb6405c500097aecc6a5ce
pt=d82bca223132bca48bf11f0807436815
ct=3e06a879484c419c8d22cab8a150a887
```

Then run:
```bash
./aes_check.sh "$key" "$pt" "$ct"
```

The script prints:

Expected: <ciphertext_from_sim>
Got:      <ciphertext_from_openssl>

If both lines match, the RTL AES implementation matches OpenSSL.

---

## Requirements

- openssl
- xxd
- Bash shell

---

## Example Output

Expected: 3e06a879484c419c8d22cab8a150a887
Got:      3e06a879484c419c8d22cab8a150a887

## Key Schedule Integrity Protection

To enhance robustness against fault injection attacks, this AES core incorporates a lightweight integrity-check mechanism into the key schedule.

For each round key, an 8-bit XOR checksum is computed during key expansion and stored alongside the corresponding round key. During encryption, the checksum is recomputed and verified before the round key is consumed by the cipher pipeline. If a mismatch is detected, the valid signal is deasserted, preventing faulty ciphertext from propagating to the output.

This approach introduces spatial redundancy for key material integrity with minimal hardware overhead. It is particularly effective against transient or injected faults that target round keys, which are commonly exploited in Differential Fault Analysis (DFA) attacks. By detecting key corruption early in the pipeline, the design mitigates the risk of leaking secret information through fault-induced faulty outputs.

## References
# Fault Injection and Differential Fault Analysis
* `On the Importance of Checking Cryptographic Protocols for Faults (Boneh, DeMillo, Lipton, 1997) https://crypto.stanford.edu/~dabo/pubs/papers/faults.pdf`_
* `Differential Fault Analysis on AES (Dusart, Letourneux, Vivolo, 2002) https://www.iacr.org/archive/ches2003/27790239/27790239.pdf`_
* `Fault Analysis in Cryptography (Barenghi et al., 2012) https://eprint.iacr.org/2012/553.pdf`_

# Fault Detection Countermeasures
* `Concurrent Error Detection for AES Hardware Implementations (Bertoni et al., 2003)https://www.iacr.org/archive/ches2003/27790227/27790227.pdf`_
* `Hardware Countermeasures Against Fault Attacks (Barenghi et al., 2010)https://eprint.iacr.org/2010/520.pdf`_



Origin Reference:

* `Advanced Encryption Standard <http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf>`_
* `The Advanced Encryption Standard Algorithm Validation Suite <http://csrc.nist.gov/groups/STM/cavp/documents/aes/AESAVS.pdf>`_
* `Recommendation for Block Cipher Modes of Operation <http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf>`_
* `Cryptographic Algorithm Validation Program (CAVP) <http://csrc.nist.gov/groups/STM/cavp/index.html>`_
