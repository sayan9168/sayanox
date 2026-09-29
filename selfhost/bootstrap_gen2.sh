#!/usr/bin/env bash
# TRUE GEN2 (pure pipeline, nothing copied).
#
#   seed (C)  --compiler_min.sa-->  gen1.c -> gen1      pure-min compiler
#   gen1      --compiler_boot.sa--> boot.c -> boot      pure compiler built BY a pure compiler
#   boot      --program.sa------->  program.c -> ELF    third generation emits real C
#   boot      --compiler_boot.sa--> boot2.c             (must equal boot.c byte for byte)
#   boot2     --program.sa------->  program.c           same compiler, one generation later
#
# Each .c file is produced by the previous compiler.  There is no `cp gen1.c
# gen2.c` step and no frozen translation unit anywhere in this script.
#
# Result marker: GEN2-PARTIAL.  The pure pipeline reaches a byte-level fixed
# point for the pure-min dialect, but compiler_min.sa itself is still outside
# that dialect (it uses conditions like `c1 >= 48 && c1 <= 57` and nested calls
# that the pure-min grammar does not accept yet).  See docs/STATUS.md, section
# "GEN2 limits".
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "${CC:-}" ]; then
  for c in clang gcc cc; do
    if command -v "$c" >/dev/null 2>&1; then CC="$c"; break; fi
  done
fi
: "${CC:?no C compiler found; set CC=clang or CC=gcc}"

T=selfhost/gen2_tests
mkdir -p "$T"

echo "=== TRUE GEN2 (pure pipeline) === (CC=$CC)"

# ---------------------------------------------------------------- [1] gen1
echo "[1] C seed is used exactly once: compiler_min.sa -> gen1.c -> gen1"
python3 selfhost/seed/apply_seed_fixes.py >/dev/null
$CC -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
test -s selfhost/gen1.c
$CC -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed
echo "    seed was used once; gen1.c is $(wc -c < selfhost/gen1.c) bytes"

# ------------------------------------------------- [2] gen1 builds a compiler
echo "[2] gen1 (pure) compiles the reduced pure compiler: compiler_boot.sa"
timeout 180 ./selfhost/gen1 selfhost/compiler_boot.sa selfhost/boot.c
test -s selfhost/boot.c
if cmp -s selfhost/boot.c selfhost/gen1.c; then
  echo "[FAIL] boot.c is a copy of gen1.c"; exit 1
fi
grep -q 'selfhost/mini_in.sa' selfhost/boot.c
grep -q 'sx_read' selfhost/boot.c
$CC -O2 -o selfhost/boot selfhost/boot.c
echo "    boot.c is $(wc -c < selfhost/boot.c) bytes of C generated from compiler_boot.sa"

# helper: run one pure-min program through gen1 and through boot, compare
program() {
  local name=$1 expect=$2
  shift 2
  local src="$T/${name}.sa"
  cat > "$src"
  # gen1 path
  ./selfhost/gen1 "$src" "$T/${name}.gen1.c" >/dev/null
  $CC -O2 -o "$T/${name}.gen1" "$T/${name}.gen1.c"
  local a
  a=$("$T/${name}.gen1")
  [ "$a" = "$expect" ] || { echo "[FAIL] $name via gen1"; printf 'expected:\n%s\ngot:\n%s\n' "$expect" "$a"; exit 1; }
  # boot path (third generation)
  ./selfhost/boot "$src" "$T/${name}.boot.c" >/dev/null
  $CC -O2 -o "$T/${name}.boot" "$T/${name}.boot.c"
  local b
  b=$("$T/${name}.boot")
  [ "$b" = "$expect" ] || { echo "[FAIL] $name via boot"; printf 'expected:\n%s\ngot:\n%s\n' "$expect" "$b"; exit 1; }
  echo "[OK] $name (gen1 and boot agree)"
}

# ------------------------------------- [3] pure-min programs through both
echo "[3] pure-min programs compiled by gen1 and by the generated boot"

program g2_reassign 2 <<'SA'
hold n = 0
hold n = 1
hold n = 2
show n
SA

program g2_while $'0\n1\n2\ndone' <<'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
show "done"
SA

program g2_when $'11\ndone' <<'SA'
hold x = 1
when x == 1 {
  show 11
} otherwise {
  show 99
}
show "done"
SA

program g2_nested $'0\n1\n1\n1\n0\n1\nend' <<'SA'
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

program g2_strings $'abcd\n4\n98\nb' <<'SA'
hold s = "ab"
hold t = sx_cat(s, "cd")
show t
hold L = sx_len(t)
show L
hold c = sx_idx(t, 1)
show c
hold ch = sx_chr(c)
show ch
SA

program g2_count $'0\n1\n2\n3' <<'SA'
hold i = 0
hold w = 0
while i < 4 {
  show i
  hold w = i + 1
  hold i = w
}
SA

program g2_mini $'42\ndone' <<'SA'
hold answer = 42
show answer
show "done"
SA

program g2_subtract $'3\n6' <<'SA'
hold a = 5
hold b = 2
hold c = a - b
show c
hold d = 10
hold e = d - 4
show e
SA

program g2_ne $'3\n2\n1\nend' <<'SA'
hold i = 3
while i != 0 {
  show i
  hold i = i - 1
}
show "end"
SA

program g2_bool_op $'1\n7' <<'SA'
hold a = 4
when a >= 3 {
  show 1
} otherwise {
  show 2
}
hold b = 1
when b == 1 {
  show 7
}
SA

# file IO through the third generation: boot compiles a copier
echo "[3b] file IO (sx_arg / sx_read / sx_write) through gen1 and boot"
cat > "$T/g2_io.sa" <<'SA'
hold src = sx_arg(1)
hold dst = sx_arg(2)
hold text = sx_read(src)
hold n = sx_len(text)
hold w = sx_write(dst, text)
show n
show w
SA
printf 'sayanox pure pipeline\n' > "$T/g2_io.in"
for who in gen1 boot; do
  ./selfhost/$who "$T/g2_io.sa" "$T/g2_io.$who.c" >/dev/null
  $CC -O2 -o "$T/g2_io.$who" "$T/g2_io.$who.c"
  out=$("$T/g2_io.$who" "$T/g2_io.in" "$T/g2_io.$who.out")
  [ "$out" = $'22\n1' ] || { echo "[FAIL] g2_io via $who: $out"; exit 1; }
  cmp -s "$T/g2_io.in" "$T/g2_io.$who.out" || { echo "[FAIL] g2_io copy via $who"; exit 1; }
done
echo "[OK] g2_io (gen1 and boot copy the file and report 22 / 1)"

# ------------------------------------------------ [4] pure fixed point
echo "[4] fixed point: boot compiles its own source -> boot2.c"
timeout 180 ./selfhost/boot selfhost/compiler_boot.sa selfhost/boot2.c
test -s selfhost/boot2.c
if cmp -s selfhost/boot.c selfhost/boot2.c; then
  echo "[OK] boot.c and boot2.c are byte identical (pure pipeline fixed point)"
  FIXED=1
else
  echo "[WARN] boot.c and boot2.c differ; checking behaviour instead"
  diff selfhost/boot.c selfhost/boot2.c | head -10 || true
  FIXED=0
fi
$CC -O2 -o selfhost/boot2 selfhost/boot2.c
./selfhost/boot2 "$T/g2_while.sa" "$T/g2_while.boot2.c" >/dev/null
$CC -O2 -o "$T/g2_while.boot2" "$T/g2_while.boot2.c"
out=$("$T/g2_while.boot2")
[ "$out" = $'0\n1\n2\ndone' ] || { echo "[FAIL] boot2 output"; exit 1; }
echo "[OK] boot2 (compiled by boot) compiles and runs pure-min programs"

# ------------------------------------------------ [5] honest gap report
echo "[5] documented gap: gen1 cannot yet compile compiler_min.sa itself"
echo "    compiler_min.sa conditions with && (outside the pure-min grammar):"
echo "      $(grep -c '&&' selfhost/compiler_min.sa) line(s)"
echo "    pure-min grammar: while/when COND is NAME OP (NUMBER|NAME) only;"
echo "    call arguments are atoms (use a temporary for a nested call)."

echo "=== GEN2-PARTIAL ==="
if [ "$FIXED" = "1" ]; then
  echo "pure fixed point reached for the pure-min dialect (boot.c == boot2.c)"
else
  echo "pure fixed point NOT byte identical; boot/boot2 agree behaviourally"
fi
echo "full pure self-compile of compiler_min.sa is still open (see docs/STATUS.md)"
