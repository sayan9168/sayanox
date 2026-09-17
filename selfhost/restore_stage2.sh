#!/usr/bin/env bash
# Stage-2 build — full .sa → C compiler
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEMPLATE="selfhost/stage2_template.c"
BASE_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

echo "Fetching Stage-2 base template..."
curl -fsSL "$BASE_URL" -o "$TEMPLATE.base"

echo "Applying Stage-2 fixes (string show + modulo)..."
awk '
BEGIN { done_str = 0 }
/static int looks_string/ && !done_str {
  print "static int is_str_name(const char *n){for(int i=0;i<g_nstrs;i++)if(!strcmp(g_str_names[i],n))return 1;return 0;}"
  done_str = 1
}
{
  line = $0
  # After string-literal check in looks_string, also accept declared string vars
  if (index(line, "if(e[0]==") && index(line, "return 1") && index(line, "return strstr")) {
    sub(/return 1;return strstr/, "return 1;if(is_str_name(e))return 1;return strstr", line)
  }
  # Fix modulo snprintf format
  gsub(/\(long\)\(%s\)%\(long\)/, "(long)(%s)%%(long)", line)
  print line
}
' "$TEMPLATE.base" > "$TEMPLATE"

rm -f "$TEMPLATE.base"

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE"
echo "Stage-2 complete and compiled OK"
