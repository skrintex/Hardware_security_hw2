#!/usr/bin/env python3
"""
openssl_check.py — Cross-check AES RTL simulation outputs against OpenSSL.

Reads vector dump files produced by aes_ec_tb.sv (vectors_Nk4.txt,
vectors_Nk6.txt, vectors_Nk8.txt) and verifies every (key, pt, ct) tuple
using OpenSSL's AES-ECB implementation as the trusted reference.

Each line of a dump file has the format:
    <key_hex> <pt_hex> <ct_hex> <Nk>

where:
  key_hex   — AES key, big-endian hex (OpenSSL -K format)
                128 bits (32 hex chars) for Nk=4
                192 bits (48 hex chars) for Nk=6
                256 bits (64 hex chars) for Nk=8
  pt_hex    — 128-bit plaintext,  32 hex chars, byte-0 first (FIPS order)
  ct_hex    — 128-bit ciphertext, 32 hex chars, byte-0 first (FIPS order)
  Nk        — number of 32-bit key words (4, 6, or 8)

Usage:
    python3 openssl_check.py [--dir <sim_output_dir>] [--verbose]

Exit code:
    0  all vectors pass
    1  one or more mismatches, or OpenSSL not found
"""

import argparse
import os
import subprocess
import sys

# ── FIPS 197 known-answer vectors (always checked first) ──────────────────────
KNOWN_ANSWER_VECTORS = [
    # (Nk, key_hex, pt_hex, expected_ct_hex, label)
    (
        4,
        "2b7e151628aed2a6abf7158809cf4f3c",
        "3243f6a8885a308d313198a2e0370734",
        "3925841d02dc09fbdc118597196a0b32",
        "FIPS-197 Appendix B",
    ),
    (
        4,
        "000102030405060708090a0b0c0d0e0f",
        "00112233445566778899aabbccddeeff",
        "69c4e0d86a7b0430d8cdb78070b4c55a",
        "FIPS-197 Appendix C.1 (AES-128)",
    ),
    (
        6,
        "000102030405060708090a0b0c0d0e0f1011121314151617",
        "00112233445566778899aabbccddeeff",
        "dda97ca4864cdfe06eaf70a0ec0d7191",
        "FIPS-197 Appendix C.2 (AES-192)",
    ),
    (
        8,
        "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
        "00112233445566778899aabbccddeeff",
        "8ea2b7ca516745bfeafc49904b496089",
        "FIPS-197 Appendix C.3 (AES-256)",
    ),
]

NkToBits = {4: 128, 6: 192, 8: 256}


def openssl_encrypt(key_hex: str, pt_bytes: bytes, nk: int) -> bytes:
    """Encrypt pt_bytes with AES-ECB using OpenSSL as the trusted reference."""
    bits = NkToBits[nk]
    cipher = f"aes-{bits}-ecb"
    result = subprocess.run(
        ["openssl", "enc", f"-{cipher}", "-K", key_hex, "-nosalt", "-nopad"],
        input=pt_bytes,
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"OpenSSL failed ({result.returncode}): {result.stderr.decode().strip()}"
        )
    return result.stdout


def check_openssl_available() -> bool:
    try:
        r = subprocess.run(["openssl", "version"], capture_output=True)
        ver = r.stdout.decode().strip()
        print(f"[INFO] Using: {ver}")
        return r.returncode == 0
    except FileNotFoundError:
        return False


def run_known_answer_tests() -> bool:
    """Run FIPS 197 known-answer tests before touching any simulation output."""
    print("=" * 60)
    print("KNOWN-ANSWER TESTS (FIPS 197)")
    print("=" * 60)
    all_pass = True
    for nk, key_hex, pt_hex, expected_ct_hex, label in KNOWN_ANSWER_VECTORS:
        pt_bytes = bytes.fromhex(pt_hex)
        ct_bytes = openssl_encrypt(key_hex, pt_bytes, nk)
        got_hex = ct_bytes.hex()
        status = "PASS" if got_hex == expected_ct_hex else "FAIL"
        if status == "FAIL":
            all_pass = False
        print(f"  [{status}] {label}")
        if status == "FAIL":
            print(f"         expected: {expected_ct_hex}")
            print(f"         got:      {got_hex}")
    print()
    return all_pass


def check_vector_file(path: str, verbose: bool) -> tuple[int, int]:
    """
    Check all vectors in a dump file.

    Returns (pass_count, fail_count).
    """
    passes = 0
    fails = 0
    errors = []

    with open(path) as fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) != 4:
                print(f"  [WARN] {path}:{lineno}: malformed line, skipping: {line!r}")
                continue

            key_hex, pt_hex, ct_rtl_hex, nk_str = parts
            nk = int(nk_str)

            if nk not in NkToBits:
                print(f"  [WARN] {path}:{lineno}: unknown Nk={nk}, skipping")
                continue

            pt_bytes = bytes.fromhex(pt_hex)
            ct_openssl = openssl_encrypt(key_hex, pt_bytes, nk)
            ct_openssl_hex = ct_openssl.hex()

            if ct_rtl_hex == ct_openssl_hex:
                passes += 1
                if verbose:
                    print(f"  [PASS] line {lineno:5d}  key={key_hex[:16]}...  ct={ct_rtl_hex}")
            else:
                fails += 1
                errors.append((lineno, key_hex, pt_hex, ct_rtl_hex, ct_openssl_hex))
                print(
                    f"  [FAIL] line {lineno:5d}  key={key_hex}  pt={pt_hex}"
                )
                print(f"         RTL:    {ct_rtl_hex}")
                print(f"         OpenSSL:{ct_openssl_hex}")

    return passes, fails


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dir",
        default=".",
        help="Directory containing vectors_Nk4.txt / Nk6.txt / Nk8.txt (default: .)",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Print every passing vector too"
    )
    parser.add_argument(
        "--nk",
        type=int,
        choices=[4, 6, 8],
        default=None,
        help="Only check vectors for this Nk value",
    )
    args = parser.parse_args()

    # ── Sanity: check OpenSSL is available ──────────────────────────────────
    if not check_openssl_available():
        print("[ERROR] openssl binary not found in PATH.")
        sys.exit(1)

    # ── Run known-answer tests first ────────────────────────────────────────
    kat_ok = run_known_answer_tests()
    if not kat_ok:
        print("[FATAL] OpenSSL failed FIPS known-answer tests — environment problem.")
        sys.exit(1)
    print("[INFO] All FIPS known-answer tests passed.\n")

    # ── Check simulation dump files ─────────────────────────────────────────
    nk_values = [args.nk] if args.nk else [4, 6, 8]
    total_pass = 0
    total_fail = 0
    files_checked = 0

    print("=" * 60)
    print("SIMULATION VECTOR CROSS-CHECK")
    print("=" * 60)

    for nk in nk_values:
        fname = os.path.join(args.dir, f"vectors_Nk{nk}.txt")
        if not os.path.exists(fname):
            print(f"  [SKIP] {fname} not found")
            continue

        file_size = os.path.getsize(fname)
        print(f"\nChecking {fname}  ({file_size} bytes) ...")
        p, f = check_vector_file(fname, args.verbose)
        total_pass += p
        total_fail += f
        files_checked += 1
        status = "PASS" if f == 0 else "FAIL"
        print(f"  => [{status}]  {p} passed,  {f} failed")

    # ── Summary ─────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Files checked : {files_checked}")
    print(f"  Vectors passed: {total_pass}")
    print(f"  Vectors failed: {total_fail}")

    if files_checked == 0:
        print("\n[WARN] No dump files found. Run the simulation first:")
        print("       make vcs-sim  (or make inca-sim)")
        print("       Then re-run: python3 openssl_check.py")
        sys.exit(1)

    if total_fail == 0:
        print(f"\n[RESULT] ALL {total_pass} VECTORS MATCH OPENSSL. RTL IS CORRECT.")
        sys.exit(0)
    else:
        print(f"\n[RESULT] FAIL — {total_fail} MISMATCH(ES) DETECTED.")
        sys.exit(1)


if __name__ == "__main__":
    main()
