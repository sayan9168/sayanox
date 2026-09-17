#!/usr/bin/env bash
# Stage-2 build — full .sa → C compiler (no third-party scripts)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEMPLATE="selfhost/stage2_template.c"
BASE_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

echo "Fetching Stage-2 base template..."
curl -fsSL "$BASE_URL" -o "$TEMPLATE.base"

echo "Applying Stage-2 fixes (string show + modulo)..."
# 1) Track declared string names so `show name` uses %s
awk '
/static int looks_string/ && !done {
  print "static int is_str_name(const char *n){for(int i=0;i<g_nstrs;i++)if(!strcmp(g_str_names[i],n))return 1;return 0;}"
  done=1
}
{print}
' "$TEMPLATE.base" > "$TEMPLATE.mid"

# 2) looks_string: also match declared string variables
sed 's/if(e\[0\]=='"'"'"'"'"'"')return 1;return strstr/if(e[0]=='"'"'"'"'"'"')return 1;if(is_str_name(e))return 1;return strstr/' \
  "$TEMPLATE.mid" > "$TEMPLATE.sed1" || cp "$TEMPLATE.mid" "$TEMPLATE.sed1"

# Portable sed for quote check (GNU/BSD)
if grep -q 'is_str_name(e)' "$TEMPLATE.sed1" 2>/dev/null; then
  cp "$TEMPLATE.sed1" "$TEMPLATE.pre"
else
  # fallback python-free: insert after first return 1 in looks_string via awk
  awk '
    BEGIN{done=0}
    /static int looks_string/ {inls=1}
    inls && /if\(e\[0\]==/ && /return 1/ && !done {
      print
      print "if(is_str_name(e))return 1;"
      done=1
      next
    }
    {print}
  ' "$TEMPLATE.mid" > "$TEMPLATE.pre"
fi

# 3) Fix snprintf modulo format (%%)
sed 's/(long)(%s)%(long)/(long)(%s)%%(long)/g' "$TEMPLATE.pre" > "$TEMPLATE"

rm -f "$TEMPLATE.base" "$TEMPLATE.mid" "$TEMPLATE.sed1" "$TEMPLATE.pre"

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE"
echo "Stage-2 complete and compiled OK"
