#!/bin/bash

key="$1"
pt="$2"
ct="$3"

# Auto-detect AES size
case ${#key} in
  32) cipher="aes-128-ecb" ;;
  48) cipher="aes-192-ecb" ;;
  64) cipher="aes-256-ecb" ;;
  *)  echo "Invalid key length"; exit 1 ;;
esac

out=$(echo "$pt" | xxd -r -p | \
  openssl enc -"$cipher" -K "$key" -nosalt -nopad | \
  xxd -p -c 16)

echo "Expected: $ct"
echo "Got:      $out"