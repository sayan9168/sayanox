#!/bin/sh
# Prove Stage-3 self-host: Sayanox compiler compiles a program.
set -e
cd "$(dirname "$0")/.."
make stage2
./selfhost/stage2 selfhost/sxc.sa selfhost/sxc_out.c
clang -O2 -pthread -o selfhost/sxc selfhost/sxc_out.c
./selfhost/sxc
clang -O2 -o selfhost/hello_from_sxc selfhost/hello_out.c
out=$(./selfhost/hello_from_sxc)
echo "sxc emitted program output: $out"
case "$out" in
  *42*) echo SELFHOST-OK; exit 0 ;;
  *) echo SELFHOST-FAIL; exit 1 ;;
esac
