#!/usr/bin/env bash
# TRUE GEN1: the C seed compiles the pure mini-compiler (compiler_min.sa) into
# gen1, and gen1 compiles pure-min programs:
#
#   hold NAME = NUMBER | NAME | "text" | NAME + NUMBER | call(...)
#   show EXPR
#   while NAME OP NUMBER|NAME { ... }
#   when  NAME OP NUMBER|NAME { ... } otherwise { ... }
#
# Nothing is copied or frozen: gen1.c is produced by selfhost/seed/sxc_seed.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

# Portable C compiler pick: $CC, else clang (CI, Termux), else gcc/cc (Linux).
if [ -z "${CC:-}" ]; then
  for c in clang gcc cc; do
    if command -v "$c" >/dev/null 2>&1; then CC="$c"; break; fi
  done
fi
: "${CC:?no C compiler found; set CC=clang or CC=gcc}"

mkdir -p selfhost/seed_tests
T=selfhost/seed_tests

echo "=== TRUE GEN1 === (CC=$CC)"
if [ -x selfhost/restore_compiler_min.sh ]; then
  chmod +x selfhost/restore_compiler_min.sh
  ./selfhost/restore_compiler_min.sh || true
fi
python3 selfhost/seed/apply_seed_fixes.py
$CC -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed

echo "[1] seed: compiler_min.sa -> gen1.c"
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
test -s selfhost/gen1.c
grep -q sx_boot selfhost/gen1.c

echo "[2] $CC: gen1.c -> gen1"
$CC -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed

# check NAME EXPECTED_STDOUT [EXPECTED_WHILE_COUNT]
# feeds the program on stdin, compiles it with gen1 and compares stdout exactly.
check() {
  local name=$1 expect=$2 want_while=${3:-}
  shift 2
  local src="$T/${name}.sa" cf="$T/${name}.c"
  cat > "$src"
  local counts
  counts=$(./selfhost/gen1 "$src" "$cf")
  test -s "$cf"
  # the compiler always ends its own counters with the liveness marker 1
  echo "$counts" | tail -1 | grep -qx 1
  if [ -n "$want_while" ]; then
    echo "$counts" | sed -n 3p | grep -qx "$want_while"
  fi
  $CC -O2 -o "$T/$name" "$cf"
  local out
  out=$("$T/$name")
  if [ "$out" != "$expect" ]; then
    echo "[FAIL] $name"
    printf 'expected:\n%s\ngot:\n%s\n' "$expect" "$out"
    exit 1
  fi
  echo "[OK] $name"
}

echo "[3] reassign: hold n = 0 / 1 / 2 -> 2"
check g1_reassign 2 <<'SA'
hold n = 0
hold n = 1
hold n = 2
show n
SA

echo "[4] while: 0 1 2 then done"
check g1_while $'0\n1\n2\ndone' 1 <<'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
show "done"
SA

echo "[5] when (false branch skipped): only 99"
check g1_when_false 99 0 <<'SA'
hold x = 2
when x == 1 {
  show 11
}
show 99
SA

echo "[6] when / otherwise: 11 then done"
check g1_when_else $'11\ndone' 0 <<'SA'
hold x = 1
when x == 1 {
  show 11
} otherwise {
  show 99
}
show "done"
SA

echo "[7] nested while/when inside a while body"
check g1_nested $'0\n1\n1\n1\n0\n1\nend' 2 <<'SA'
hold i = 0
hold j = 0
while i < 3 {
  hold j = 0
  while j < 2 {
    when i == 1 {
      show i
    } otherwise {
      show j
    }
    hold j = j + 1
  }
  hold i = i + 1
}
show "end"
SA

echo "[8] all six comparison operators"
check g1_ops $'3\n5\n6' 0 <<'SA'
hold a = 5
when a != 5 { show 1 }
when a < 5 { show 2 }
when a <= 5 { show 3 }
when a > 5 { show 4 }
when a >= 5 { show 5 }
when a == 5 { show 6 }
SA

echo "[9] multi-hold + string"
check g1_str $'10\n20\nhi' <<'SA'
hold a = 10
hold b = 20
show a
show b
show "hi"
SA

echo "[10] string builtins in a target program"
check g1_builtins $'abcd\n4\n98\nb' <<'SA'
hold s = "ab"
hold t = concat(s, "cd")
show t
hold L = len(t)
show L
hold c = sx_index(t, 1)
show c
hold ch = chr(c)
show ch
SA

echo "[11] mini_in"
check g1_mini $'42\ndone' <<'SA'
hold answer = 42
show answer
show "done"
SA

echo "[12] gen1 emits real loop/branch C (not a frozen translation unit)"
grep -q 'while (n < 3) {' "$T/g1_while.c"
grep -q 'if (x == 1) {' "$T/g1_when_else.c"
grep -q '} else {' "$T/g1_when_else.c"
grep -q 'double n = 0;' "$T/g1_while.c"
grep -q 'n = n + 1;' "$T/g1_while.c"
grep -q 'sx_b_read_file' selfhost/gen1.c
grep -q decls selfhost/compiler_min.sa
echo "[OK] emitted C contains while/if/else and reassign"

echo "=== GEN1-OK ==="
