#!/usr/bin/env bash
# Stage-2 smoke tests
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh selfhost/sx
./selfhost/restore_stage2.sh

CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc

run_one() {
  local sa="$1" expect="$2"
  ./selfhost/sx "$sa" -o /tmp/sx_test_bin --run >/dev/null
  local got
  got="$(/tmp/sx_test_bin)"
  echo "  $sa -> $got"
  [[ "$got" == *"$expect"* ]] || { echo "FAIL expected $expect"; exit 1; }
}

echo "=== Stage-2 tests ==="
run_one examples/hello.sa "42"
# countdown ends with done
./selfhost/sx examples/countdown.sa -o /tmp/sx_cd --run >/dev/null
[[ "$(/tmp/sx_cd | tail -1)" == "done" ]]
echo "  countdown OK"
./selfhost/sx examples/greet.sa -o /tmp/sx_gr --run >/dev/null
out="$(/tmp/sx_gr)"
echo "$out" | grep -q Hello
echo "$out" | grep -q Sayanox
echo "  greet OK"
echo "=== Stage-2 OK ==="
