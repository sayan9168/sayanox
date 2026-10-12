#!/bin/sh
# Run from repository root. No Python or network required.
set -eu
seed=$1
gen2=$2
native=$3
work=$4
mkdir -p "$work"
for body in \
  'show 1' \
  'when n > 0 {\n give 1\n}' \
  'when n > 0 {\n give 1\n} elif n == 0 {\n give 0\n}' \
  'when n > 0 {\n give 1\n} else {\n show 2\n}' \
  'when n > 0 {\n when n > 1 {\n give 1\n}\n} else {\n give 0\n}' \
  'while n > 0 {\n give 1\n}' \
  'for i in 0..n {\n give i\n}' \
  'while true {\n break\n give 1\n}' \
  'show "give 1 } otherwise { give 2"\n// give 3' \
  '// give 1\nshow 0'; do
  printf 'make f(n: num) -> num {\n%b\n}\nshow f(1)\n' "$body" > "$work/return_bad.sa"
  if "$seed" "$work/return_bad.sa" > "$work/return_bad_seed.c" 2> "$work/return_bad_seed.err"; then
    echo '[FAIL] seed accepted a function with an unproved return path'; exit 1
  fi
  grep -q 'may fall through without give' "$work/return_bad_seed.err"
  "$gen2" "$work/return_bad.sa" "$work/return_bad.c" > "$work/return_bad.log"
  grep -q '^#error.*may fall through without give' "$work/return_bad.c"
  if "$native" "$work/return_bad.sa" "$work/return_bad_native" > "$work/return_bad_native.log" 2>&1; then
    echo '[FAIL] native accepted a function with an unproved return path'; exit 1
  fi
  grep -q 'may fall through without give' "$work/return_bad_native.log"
done
for kind in str list; do
  printf 'make f() -> %s {\n show 0\n}\n' "$kind" > "$work/return_bad.sa"
  if "$seed" "$work/return_bad.sa" > /dev/null 2> "$work/return_bad_seed.err"; then exit 1; fi
  grep -q 'may fall through without give' "$work/return_bad_seed.err"
  "$gen2" "$work/return_bad.sa" "$work/return_bad.c" > "$work/return_bad.log"
  grep -q '^#error.*may fall through without give' "$work/return_bad.c"
  if "$native" "$work/return_bad.sa" "$work/return_bad_native" > "$work/return_bad_native.log" 2>&1; then exit 1; fi
  grep -q 'may fall through without give' "$work/return_bad_native.log"
done
printf 'make f<T>(n: T) -> T {\n when n > 0 {\n give n\n }\n}\nshow f(1)\n' > "$work/return_bad.sa"
if "$seed" "$work/return_bad.sa" > /dev/null 2> "$work/return_bad_seed.err"; then exit 1; fi
grep -q 'may fall through without give' "$work/return_bad_seed.err"
"$gen2" "$work/return_bad.sa" "$work/return_bad.c" > "$work/return_bad.log"
grep -q '^#error.*may fall through without give' "$work/return_bad.c"
if "$native" "$work/return_bad.sa" "$work/return_bad_native" > "$work/return_bad_native.log" 2>&1; then exit 1; fi
grep -q 'may fall through without give' "$work/return_bad_native.log"
echo '[OK] return-path diagnostics: missing arms, nested fallthrough, zero-iteration loops, unreachable loop returns, strings/comments and num/str/list/generic functions; all three frontends'
