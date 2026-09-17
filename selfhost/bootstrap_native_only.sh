#!/bin/sh
# Bootstrap WITHOUT Stage-2 C host for the native subset.
# Requires once: clang (to compile native_aot.c only).
# After that: .sa in the native subset need NO stage2 and NO second clang.
set -e
cd "$(dirname "$0")/.." || exit 1

echo "=== Native-only bootstrap (no Stage-2) ==="

if [ ! -x selfhost/native_aot ]; then
  echo "Building native_aot (one-time clang on native_aot.c)..."
  make native
fi

run_case() {
  src=$1
  out=$2
  echo "--- $src ---"
  ./selfhost/native_aot "$src" "$out"
  "$out"
}

printf 'show 42\n' > /tmp/sx_native_hello.sa
run_case /tmp/sx_native_hello.sa /tmp/sx_native_hello | grep -q 42

printf 'hold x = 10 + 32\nshow x\n' > /tmp/sx_native_arith.sa
run_case /tmp/sx_native_arith.sa /tmp/sx_native_arith | grep -q 42

printf 'hold i = 3\nwhile i {\n  show i\n  hold i = i - 1\n}\n' > /tmp/sx_native_while.sa
out=$(run_case /tmp/sx_native_while.sa /tmp/sx_native_while)
echo "$out" | grep -q 3
echo "$out" | grep -q 1

printf 'hold xs = [1, 2, 3]\nshow xs[1]\nshow len(xs)\n' > /tmp/sx_native_list.sa
out=$(run_case /tmp/sx_native_list.sa /tmp/sx_native_list)
echo "$out" | grep -q 2
echo "$out" | grep -q 3

printf 'hold p.x = 3\nhold p.y = 4\nshow p.x\nshow p.y\n' > /tmp/sx_native_struct.sa
out=$(run_case /tmp/sx_native_struct.sa /tmp/sx_native_struct)
echo "$out" | grep -q 3
echo "$out" | grep -q 4

echo "=== NATIVE-ONLY OK (no Stage-2 used) ==="
echo "Note: full language still needs Stage-2 + clang."
echo "Next: grow native_aot until it can lower the Sayanox compiler itself."
