#!/bin/bash
# Pack selfhost/compiler_min.sa into the offline gzip+base64 blobs used by
# `make restore-compiler` (docs/BOOTSTRAP_NO_C_HOST.md).  No Python.
#
# Usage:  ./selfhost/pack_compiler_min.sh
set -e
cd "$(dirname "$0")/.."

SRC=selfhost/compiler_min_gz
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gzip -9 -n -c selfhost/compiler_min.sa | base64 -w 0 > "$tmp/blob.txt"
mkdir -p "$tmp/chunks"
awk '{ L=length($0); i=0; n=0
       while (i<L) { chunk=substr($0,i+1,1100); i+=1100
         printf "%s", chunk > sprintf("'"$tmp"'/chunks/%04d.b64", n); n++ }
     }' "$tmp/blob.txt"

rm -f "$SRC"/*.b64
cp "$tmp"/chunks/*.b64 "$SRC"/
ls "$SRC" | wc -l | xargs echo "blob parts:"

# The live compiler now includes a source module; preserve its offline recovery
# independently so the main bundle's concatenated parts remain one gzip stream.
gzip -9 -n -c selfhost/modules/compiler_text.sa | base64 -w 0 > selfhost/modules/compiler_text.sa.gz.b64
if ! cmp -s selfhost/modules/compiler_text.sa <(base64 -d selfhost/modules/compiler_text.sa.gz.b64 | gzip -d); then
  echo '[FAIL] compiler module recovery round-trip'; exit 1
fi
echo '[OK] compiler module recovery round-trip'
make restore-compiler
if cmp -s selfhost/compiler_min.sa <(cat "$SRC"/*.b64 | tr -d '\n' | base64 -d | gzip -d); then
  echo "[OK] pack-compiler-min: round-trip matches selfhost/compiler_min.sa"
else
  echo "[FAIL] pack-compiler-min: round-trip differs"
  exit 1
fi
