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

After running your RTL simulation, copy one of the printed values:

For example:
key=13e2293b702e2669fd339cfee2035d3d97b2ad20f1cb6405c500097aecc6a5ce
pt=d82bca223132bca48bf11f0807436815
ct=3e06a879484c419c8d22cab8a150a887

Then run:

./aes_check.sh "$key" "$pt" "$ct"

The script prints:

Expected: <ciphertext_from_sim>
Got:      <ciphertext_from_openssl>

If both lines match, the RTL AES implementation matches OpenSSL.

---

## Supported Key Sizes

The script automatically detects AES mode based on key length:

- 32 hex characters  → AES-128
- 48 hex characters  → AES-192
- 64 hex characters  → AES-256

---

## Requirements

- openssl
- xxd
- Bash shell

---

## Example Output

Expected: 3e06a879484c419c8d22cab8a150a887
Got:      3e06a879484c419c8d22cab8a150a887


Reference:

* `Advanced Encryption Standard <http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf>`_
* `The Advanced Encryption Standard Algorithm Validation Suite <http://csrc.nist.gov/groups/STM/cavp/documents/aes/AESAVS.pdf>`_
* `Recommendation for Block Cipher Modes of Operation <http://csrc.nist.gov/publications/nistpubs/800-38a/sp800-38a.pdf>`_
* `Cryptographic Algorithm Validation Program (CAVP) <http://csrc.nist.gov/groups/STM/cavp/index.html>`_
