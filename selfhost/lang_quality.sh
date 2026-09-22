#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v clang >/dev/null 2>&1 || { echo "error: clang is required" >&2; exit 1; }
chmod +x selfhost/sx
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_ok() {
  local src="$1" needle="$2"
  ./selfhost/sx "$src" -o "$tmp/out" >/dev/null
  "$tmp/out" > "$tmp/stdout"
  grep -Fq "$needle" "$tmp/stdout"
}

run_ok examples/lang_quality/modules/main.sa "42"
run_ok examples/lang_quality/types_ok.sa "42"

set +e
./selfhost/sx examples/lang_quality/modules/cycle_a.sa -o "$tmp/cycle" >"$tmp/cycle.out" 2>"$tmp/cycle.err"
cycle_rc=$?
./selfhost/sx examples/lang_quality/types_bad.sa -o "$tmp/types" >"$tmp/types.out" 2>"$tmp/types.err"
type_rc=$?
set -e

test "$cycle_rc" -ne 0
grep -Fq "cyclic module import detected" "$tmp/cycle.err"
grep -Fq "cycle_a.sa" "$tmp/cycle.err"
grep -Fq "cycle_b.sa" "$tmp/cycle.err"

test "$type_rc" -ne 0
grep -Fq "type error" "$tmp/types.err"
grep -Eq ':[0-9]+(:[0-9]+)?:' "$tmp/types.err"
grep -Eq 'num|number' "$tmp/types.err"
grep -Eq 'str|string' "$tmp/types.err"

./selfhost/sx examples/lang_quality/diagnostic_bad.sa -o "$tmp/diag" >/dev/null 2>"$tmp/diag.err" || true
if grep -Eq ':[0-9]+:[0-9]+:.*error' "$tmp/diag.err"; then
  grep -Fq "^" "$tmp/diag.err"
fi

echo "=== LANG-QUALITY-OK ==="
