#!/usr/bin/env bash
# Grammar growth tests for the true gen1 target grammar.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

./selfhost/bootstrap_gen1.sh

CC="${CC:-clang}"
T=selfhost/grammar_tests
mkdir -p "$T"

check() {
  local name=$1 expect=$2
  shift 2
  local src="$T/$name.sa" cf="$T/$name.c"
  cat > "$src"
  ./selfhost/gen1 "$src" "$cf" >/dev/null
  test -s "$cf"
  "$CC" -O2 -o "$T/$name" "$cf"
  local got
  got=$("$T/$name")
  test "$got" = "$expect"
  echo "[OK] $name"
}

check condition_and_or  <<'SA'
hold x = 2
when x >= 1 && x <= 3 {
  show 1
} otherwise {
  show 0
}
when x < 1 || x > 1 {
  show 0
} otherwise {
  show 0
}
SA

check while_arithmetic $'0
1
2' <<'SA'
hold n = 3
hold pos = 0
while pos + 1 < n {
  show pos
  hold pos = pos + 1
}
SA

check nested_builtin $'aB' <<'SA'
hold s = concat("a", chr(66))
show s
SA

grep -q 'if (x >= 1 && x <= 3) {' "$T/condition_and_or.c"
grep -q 'while (pos + 1 < n) {' "$T/while_arithmetic.c"
grep -q 'sx_cat("a", sx_chr(66))' "$T/nested_builtin.c"

echo "=== GRAMMAR-GROW-OK ==="
1
1' <<'SA'
hold x = 2
when x >= 1 && x <= 3 {
  show 1
} otherwise {
  show 0
}
when x < 1 || x > 3 {
  show 0
} otherwise {
  show 0
}
SA

check while_arithmetic $'0
1
2' <<'SA'
hold n = 3
hold pos = 0
while pos + 1 < n {
  show pos
  hold pos = pos + 1
}
SA

check nested_builtin $'aB' <<'SA'
hold s = concat("a", chr(66))
show s
SA

grep -q 'if (x >= 1 && x <= 3) {' "$T/condition_and_or.c"
grep -q 'while (pos + 1 < n) {' "$T/while_arithmetic.c"
grep -q 'sx_cat("a", sx_chr(66))' "$T/nested_builtin.c"

echo "=== GRAMMAR-GROW-OK ==="
