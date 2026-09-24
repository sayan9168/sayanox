#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
ok() {
  [ -f selfhost/sxc_full.c ] && grep -qE 'sx_chr|hold' selfhost/sxc_full.c && \
    [ "$(wc -c < selfhost/sxc_full.c)" -gt 1000 ]
}
if ok; then
  echo "sxc_full.c OK ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
# Assemble full installer from parts if present
if [ ! -f selfhost/install_sxc_full.py ]; then
  if ls selfhost/install_sxc_full.py.p* >/dev/null 2>&1; then
    cat selfhost/install_sxc_full.py.p* > selfhost/install_sxc_full.py
  elif [ -f selfhost/install_sxc_full.py.a ]; then
    cat selfhost/install_sxc_full.py.a selfhost/install_sxc_full.py.b > selfhost/install_sxc_full.py
  fi
fi
if [ -f selfhost/install_sxc_full.py ]; then
  python3 selfhost/install_sxc_full.py || true
fi
if ok; then
  echo "restored via install ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
# Guaranteed minimal seed (always in repo)
if [ -f selfhost/sxc_full_minimal.c ]; then
  cp selfhost/sxc_full_minimal.c selfhost/sxc_full.c
fi
if ok; then
  echo "restored via sxc_full_minimal.c ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
# Broken base64 must not abort CI
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
