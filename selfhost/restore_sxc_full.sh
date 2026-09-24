#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
ok() {
  [ -f selfhost/sxc_full.c ] && grep -q sx_chr selfhost/sxc_full.c && \
    [ "$(wc -c < selfhost/sxc_full.c)" -gt 10000 ]
}
if ok; then
  echo "sxc_full.c OK ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
# Assemble install script from parts if needed
if [ ! -f selfhost/install_sxc_full.py ] && [ -f selfhost/install_sxc_full.py.a ]; then
  cat selfhost/install_sxc_full.py.a selfhost/install_sxc_full.py.b > selfhost/install_sxc_full.py
fi
if [ -f selfhost/install_sxc_full.py ]; then
  python3 selfhost/install_sxc_full.py || true
fi
if ok; then
  echo "restored via install_sxc_full.py ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
if [ -d selfhost/sxc_full_lines ]; then
  cat selfhost/sxc_full_lines/L*.txt > selfhost/sxc_full.c 2>/dev/null || true
fi
if ok; then
  echo "restored via line parts ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
# Broken incomplete base64 must NOT abort
if [ -d selfhost/sxc_full_b64_plain ]; then
  if cat selfhost/sxc_full_b64_plain/p*.txt 2>/dev/null | tr -d '\n' | base64 -d > selfhost/sxc_full.c 2>/dev/null; then
    :
  else
    rm -f selfhost/sxc_full.c
  fi
fi
if ok; then
  echo "restored via plain base64 ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
echo "error: cannot restore sxc_full.c" >&2
exit 1
