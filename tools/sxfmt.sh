#!/usr/bin/env bash
# Minimal Sayanox formatter (no Python) — awk only
set -euo pipefail
if [[ $# -lt 1 ]]; then echo "usage: sxfmt.sh <file.sa> [--write]"; exit 1; fi
FILE="$1"
WRITE=0
[[ "${2:-}" == "--write" ]] && WRITE=1
OUT="$(mktemp)"
awk '
BEGIN{indent=0; prev=""}
{
  line=$0
  gsub(/\r/,"",line)
  sub(/^[ \t]+/, "", line)
  sub(/[ \t]+$/, "", line)
  if(line==""){ if(prev!="") print ""; prev=""; next }
  if(line ~ /^}/) indent=(indent>0?indent-1:0)
  pad=""
  for(i=0;i<indent;i++) pad=pad "  "
  print pad line
  prev=line
  if(line ~ /\{$/ && line !~ /^\/\//) indent++
}
' "$FILE" > "$OUT"
if [[ "$WRITE" -eq 1 ]]; then mv "$OUT" "$FILE"; echo "formatted $FILE"
else cat "$OUT"; rm -f "$OUT"
fi
