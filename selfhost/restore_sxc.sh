#!/bin/sh
set -e
cd "$(dirname "$0")/.."
if [ -f selfhost/sxc.sa.b64 ]; then
  cat selfhost/sxc.sa.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc.sa
  echo "restored sxc.sa ($(wc -c < selfhost/sxc.sa) bytes)"
fi
