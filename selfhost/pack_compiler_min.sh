#!/bin/sh
# Pack selfhost/compiler_min.sa into the offline gzip+base64 blobs used by
# `make restore-compiler`. POSIX sh only: no bash, awk, sed or Python.
#
# Usage:  ./selfhost/pack_compiler_min.sh
set -e
cd "$(dirname "$0")/.."

SRC=selfhost/compiler_min_gz
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' 0 1 2 3 15

gzip -9 -n -c selfhost/compiler_min.sa | base64 | tr -d '\n' > "$tmp/blob.txt"
mkdir -p "$tmp/chunks"
# Fixed 1100-byte parts. Four-character suffixes cover 456976 parts; the loop
# below renames them to the zero-padded 0000.b64 form `restore-compiler` reads.
split -b 1100 -a 4 "$tmp/blob.txt" "$tmp/chunks/part."

rm -f "$SRC"/*.b64
i=0
for part in "$tmp"/chunks/part.*; do
  cp "$part" "$SRC/$(printf '%04d' "$i").b64"
  i=$((i + 1))
done
echo "blob parts: $i"

# The live compiler now includes a source module; preserve its offline recovery
# independently so the main bundle's concatenated parts remain one gzip stream.
gzip -9 -n -c selfhost/modules/compiler_text.sa | base64 | tr -d '\n' > selfhost/modules/compiler_text.sa.gz.b64
base64 -d < selfhost/modules/compiler_text.sa.gz.b64 | gzip -d > "$tmp/module.sa"
if cmp -s selfhost/modules/compiler_text.sa "$tmp/module.sa"; then
  echo '[OK] compiler module recovery round-trip'
else
  echo '[FAIL] compiler module recovery round-trip'; exit 1
fi

make restore-compiler
cat "$SRC"/*.b64 | tr -d '\n' | base64 -d | gzip -d > "$tmp/unpacked.sa"
if cmp -s selfhost/compiler_min.sa "$tmp/unpacked.sa"; then
  echo "[OK] pack-compiler-min: round-trip matches selfhost/compiler_min.sa"
else
  echo "[FAIL] pack-compiler-min: round-trip differs"
  exit 1
fi
