#!/bin/sh
# C translator regression tests. Only POSIX shell, mkdir, cmp, grep required.
set -eu
tool=$1
dir=$2
mkdir -p "$dir"
printf ';  phase  \n000000  mov rax,[r12+8]\n000001  addsd xmm10,xmm1\n000002  call make rax\n000003  mystery eax,rax_tail,0xrax,r8b\nchanged log format\n000004  \n000005  ret' > "$dir/in"
printf '; portable IR listing (docs/NATIVE_IR.md) -- translated from an\n; SX_EMIT_LOG instruction list by tools/emit_to_ir.c. This is an\n; analysis format: no backend assembles or executes it.\n; phase\nI0     COPY A,[BASE+8]\nI1     FADD F10,F1\nI2     CALL make rax\nI3     MYSTERY A,rax_tail,0xrax,R8\n; UNTRANSLATED: changed log format\n; UNTRANSLATED: 000004  \nI4     RET\n' > "$dir/want"
"$tool" "$dir/in" "$dir/out"
cmp "$dir/want" "$dir/out"
# Exercise dynamic line growth without awk/Python; also an unterminated line.
printf '000000  mystery ' > "$dir/long"
i=0
while [ "$i" -lt 4096 ]; do printf 'rax,' >> "$dir/long"; i=$((i+1)); done
"$tool" "$dir/long" "$dir/long.ir"
"$tool" "$dir/long" "$dir/again.ir"
cmp "$dir/long.ir" "$dir/again.ir"
if grep -q 'rax' "$dir/long.ir"; then echo '[FAIL] long operand line truncated/untranslated'; exit 1; fi
if "$tool" > "$dir/msg" 2>&1; then echo '[FAIL] accepted missing args'; exit 1; fi
if "$tool" "$dir/absent" "$dir/out" > "$dir/msg" 2>&1; then echo '[FAIL] accepted missing input'; exit 1; fi
if "$tool" "$dir/in" "$dir" > "$dir/msg" 2>&1; then echo '[FAIL] accepted unwritable output'; exit 1; fi
if "$tool" "$dir/in" "$dir/in" > "$dir/msg" 2>&1; then echo '[FAIL] accepted identical paths'; exit 1; fi
printf 'bad\000input' > "$dir/nul"
if "$tool" "$dir/nul" "$dir/out" > "$dir/msg" 2>&1; then echo '[FAIL] accepted binary log'; exit 1; fi
printf '[OK] C99 IR translator: exact output, unknown lines/instructions, token boundaries, named calls, long lines, EOF and errors\n'
