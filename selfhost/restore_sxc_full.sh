#!/bin/sh
# Restore the legacy selfhost/sxc_full.c from the checked-in minimal seed or the
# plain base64 bundle. POSIX sh only: the former Python installer path and the
# Python branch were dead (selfhost/install_sxc_full.py is not in the tree) and
# are removed rather than kept as an interpreter dependency.
set -eu
cd "$(cd "$(dirname "$0")/.." && pwd)"
ok() {
  [ -f selfhost/sxc_full.c ] && grep -qE 'sx_chr|hold' selfhost/sxc_full.c && \
    [ "$(wc -c < selfhost/sxc_full.c)" -gt 1000 ]
}
if ok; then
  echo "sxc_full.c OK ($(wc -c < selfhost/sxc_full.c) bytes)"
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
