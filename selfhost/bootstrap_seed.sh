#!/usr/bin/env bash
# Phase-2 seed compiler conformance (must pass in CI)
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

echo "=== SEED COMPILER ==="
# Portable C compiler pick: $CC, else clang (CI, Termux), else gcc/cc (Linux).
if [ -z "${CC:-}" ]; then
  for c in clang gcc cc; do
    if command -v "$c" >/dev/null 2>&1; then CC="$c"; break; fi
  done
fi
: "${CC:?no C compiler found; set CC=clang or CC=gcc}"

test -f selfhost/seed/sxc_seed.c
test -f selfhost/seed/sx_runtime.h
python3 selfhost/seed/apply_seed_fixes.py
$CC -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed

run() {
  local name=$1 expect=$2
  shift 2
  local src="selfhost/seed_tests/${name}.sa"
  mkdir -p selfhost/seed_tests
  cat > "$src"
  # Support seed that writes to stdout (legacy) or to out path (fixed)
  if ./selfhost/seed/sxc_seed "$src" "selfhost/seed_tests/${name}.c" 2>/tmp/sx_seed_err; then
    if [ ! -s "selfhost/seed_tests/${name}.c" ]; then
      ./selfhost/seed/sxc_seed "$src" > "selfhost/seed_tests/${name}.c"
    fi
  else
    ./selfhost/seed/sxc_seed "$src" > "selfhost/seed_tests/${name}.c"
  fi
  test -s "selfhost/seed_tests/${name}.c"
  $CC -O2 -o "selfhost/seed_tests/${name}" "selfhost/seed_tests/${name}.c" -I selfhost/seed
  local out
  out=$("selfhost/seed_tests/${name}")
  echo "$out" | grep -q "$expect"
  echo "[OK] $name ($expect)"
}

run hold 42 <<'SA'
hold x = 42
show x
SA

run when 99 <<'SA'
hold x = 2
when x == 1 {
  show 11
} otherwise {
  show 99
}
show "done"
SA

run while done <<'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
show "done"
SA

run make 42 <<'SA'
make double(x) {
  give x + x
}
hold a = 21
show double(a)
SA

run index 72 <<'SA'
hold msg = "Hi"
hold c0 = msg[0]
show c0
show "done"
SA

run concat ab <<'SA'
hold s = concat("a", "b")
show s
show "done"
SA

run len 5 <<'SA'
hold s = "hello"
show len(s)
show "done"
SA

run reassign 2 <<'SA'
hold n = 0
hold n = 1
hold n = n + 1
show n
SA

run list 20 <<'SA'
hold xs = [10, 20, 30]
show xs[1]
show "done"
SA

run mini2 42 <<'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
make double(x) {
  give x + x
}
hold a = 21
show double(a)
hold x = 2
when x == 1 {
  show 11
} otherwise {
  show 99
}
show "done"
SA

echo "=== SEED-OK ==="
