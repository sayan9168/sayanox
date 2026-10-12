#!/bin/sh
set -eu
gen2=$1
work=$2
mkdir -p "$work"
for text in \
  'show ghost' \
  'hold x = ghost' \
  'hold x = x + 1' \
  'hold x = 1 + ghost' \
  'show 1 + ghost' \
  'show len(ghost)' \
  'show len(concat("a", ghost))' \
  'hold xs = [1, ghost + 2]' \
  'hold xs = [ghost]\nshow len(xs)' \
  'hold xs = [\n ghost\n]' \
  'hold xs = [1]\nshow xs[ghost]' \
  'hold xs = [1]\npush(xs, ghost)' \
  'hold xs = [1]\nxs[ghost] = 2' \
  'when ghost > 0 {\n show 1\n}' \
  'when 1 == ghost {\n show 1\n}' \
  'while len(ghost) > 0 {\n break\n}' \
  'for i in 0..ghost {\n show i\n}' \
  'for i in ghost {\n show i\n}' \
  'make f(n: num) -> num {\n give ghost + n\n}\nshow f(1)' \
  'make f(n: num) -> num {\n give n\n}\nshow n' \
  'make f(n: num) -> num {\n when n {\n hold ghost = 1\n }\n give ghost\n}\nshow f(1)' \
  'make f(n: num) -> num {\n when n {\n hold ghost = 1\n } else {\n show ghost\n }\n give 0\n}\nshow f(1)' \
  'make f<T>(n: T) -> T {\n give ghost\n}\nshow f(1)' \
  'struct Pair { x, y }\nhold p = Pair { x: 1, y: ghost }' \
  'show ghost.x' \
  'show future\nhold future = 1'; do
  printf '%b\n' "$text" > "$work/name_bad.sa"
  "$gen2" "$work/name_bad.sa" "$work/name_bad.c" > "$work/name_bad.log"
  if ! grep -q '^#error.*\(undefined name\|unknown.*expression\|undeclared\)' "$work/name_bad.c"; then
    echo "[FAIL] missing reference diagnostic: $text"; cat "$work/name_bad.log"; exit 1
  fi
done
for text in \
  'show absent(1)' \
  'hold x = absent(1)' \
  'show len(absent(1))' \
  'make f(n: num) -> num {\n give absent(n)\n}\nshow f(1)' \
  'when absent(1) {\n show 1\n}'; do
  printf '%b\n' "$text" > "$work/name_bad.sa"
  "$gen2" "$work/name_bad.sa" "$work/name_bad.c" > "$work/name_bad.log"
  if ! grep -q '^#error.*unknown function' "$work/name_bad.c"; then
    echo "[FAIL] missing function diagnostic: $text"; cat "$work/name_bad.log"; exit 1
  fi
done
echo '[OK] gen2 reference diagnostics: initializers, arithmetic, nested calls, lists/indexes, writes, conditions, loops, returns, function/sibling scopes, generic bodies and unknown callees'
