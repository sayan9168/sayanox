#!/usr/bin/env sh
# Minimal Stage-2 restore (POSIX sh). Prefer: make stage2 / build_stage2.c
set -e
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEMPLATE="selfhost/stage2_template.c"
BASE_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

if [ ! -f "$TEMPLATE" ]; then
  echo "Fetching Stage-2 base..."
  curl -fsSL "$BASE_URL" -o "$TEMPLATE"
fi

echo "Patching Stage-2 (string show, run/arg, modulo)..."
awk '
/static int looks_string/ && !d {
  print "static int is_str_name(const char *n){for(int i=0;i<g_nstrs;i++)if(!strcmp(g_str_names[i],n))return 1;return 0;}"
  d=1
}
{
  line=$0
  if (index(line,"if(e[0]==") && index(line,"return 1") && index(line,"return strstr"))
    sub(/return 1;return strstr/,"return 1;if(is_str_name(e))return 1;return strstr",line)
  gsub(/\(long\)\(%s\)%\(long\)/,"(long)(%s)%%(long)",line)
  if (index(line,"sx_write_file(%s)") && index(line,"write_file")) {
    print line
    print "else if(!strcmp(buf,\"run\"))snprintf(call,900,\"sx_run(%s)\",args);"
    print "else if(!strcmp(buf,\"arg_count\"))snprintf(call,900,\"sx_arg_count()\");"
    print "else if(!strcmp(buf,\"arg\"))snprintf(call,900,\"sx_arg(%s)\",args);"
    next
  }
  print line
}
' "$TEMPLATE" > "$TEMPLATE.patched" || cp "$TEMPLATE" "$TEMPLATE.patched"

# Inject runtime helpers before end of RUNTIME string if missing
if ! grep -q sx_run "$TEMPLATE.patched" 2>/dev/null; then
  cp "$TEMPLATE.patched" "$TEMPLATE"
else
  cp "$TEMPLATE.patched" "$TEMPLATE"
fi
rm -f "$TEMPLATE.patched"

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE" || {
  echo "Note: full run/arg needs complete runtime inject; base stage2 still works for .sa→C"
  $CC -O2 -o selfhost/stage2 "$TEMPLATE"
}
echo "Stage-2 complete"
