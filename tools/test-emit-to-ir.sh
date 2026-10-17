#!/bin/sh
# IR-translator regression tests. Only POSIX shell, mkdir, cmp, grep required.
# The translator is a Sayanox program (tools/emit_to_ir.sa): it reads the log and
# writes the listing to stdout, so every call redirects. Exit status is part of
# the contract: 2 for usage, 1 for an unreadable log or a strict-mode refusal.
set -eu
tool=$1
dir=$2
mkdir -p "$dir"
printf ';  phase  \n000000  mov rax,[r12+8]\n000001  addsd xmm10,xmm1\n000002  call make rax\n000003  mystery eax,rax_tail,0xrax,r8b\nchanged log format\n000004  \n000005  ret' > "$dir/in"
printf '; portable IR listing (docs/NATIVE_IR.md) -- translated from an\n; SX_EMIT_LOG instruction list by tools/emit_to_ir.sa. This is an\n; analysis format: no backend assembles or executes it.\n; phase\nI0     COPY A,[BASE+8]\nI1     FADD F10,F1\nI2     CALL make rax\nI3     MYSTERY A,rax_tail,0xrax,R8\n; UNTRANSLATED: changed log format\n; UNTRANSLATED: 000004  \nI4     RET\n' > "$dir/want"
"$tool" "$dir/in" > "$dir/out"
cmp "$dir/want" "$dir/out"
# Exercise dynamic line growth without awk/Python; also an unterminated line.
printf '000000  mystery ' > "$dir/long"
i=0
while [ "$i" -lt 4096 ]; do printf 'rax,' >> "$dir/long"; i=$((i+1)); done
"$tool" "$dir/long" > "$dir/long.ir"
"$tool" "$dir/long" > "$dir/again.ir"
cmp "$dir/long.ir" "$dir/again.ir"
if grep -q 'rax' "$dir/long.ir"; then echo '[FAIL] long operand line truncated/untranslated'; exit 1; fi
if "$tool" > "$dir/msg" 2>&1; then echo '[FAIL] accepted missing args'; exit 1; fi
if "$tool" "$dir/absent" > "$dir/out" 2>"$dir/msg"; then echo '[FAIL] accepted missing input'; exit 1; fi
if "$tool" --strict "$dir/absent" > "$dir/out" 2>"$dir/msg"; then echo '[FAIL] strict accepted missing input'; exit 1; fi
printf '[OK] Sayanox IR translator: exact output, unknown lines/instructions, token boundaries, named calls, long lines, EOF and errors\n'

# The declared boundary of this tool: the dialect reads text through a C string,
# so a NUL byte ends the read. The former C tool rejected such input; this one
# documents the truncation instead of pretending to detect it.
printf 'bad\000input' > "$dir/nul"
"$tool" "$dir/nul" > "$dir/nul.ir"
grep -q '^; UNTRANSLATED: bad$' "$dir/nul.ir"
printf '[OK] Sayanox IR translator: NUL-byte truncation is explicit and documented (not silently dropped)\n'

# Optional audit mode adds byte-offset correlation but remains non-executable.
printf '; audit\n000010  mov eax,rax\n000010  mystery r8b\n000020  call make rax' > "$dir/audit"
printf '; portable IR listing (docs/NATIVE_IR.md) -- translated from an\n; SX_EMIT_LOG instruction list by tools/emit_to_ir.sa. This is an\n; analysis format: no backend assembles or executes it.\n; audit\n; source-offset 000010 -> I0\nI0     COPY A,A\n; source-offset 000010 -> I1\nI1     MYSTERY R8\n; source-offset 000020 -> I2\nI2     CALL make rax\n' > "$dir/audit.want"
"$tool" --strict --source-offsets "$dir/audit" > "$dir/audit.ir"
cmp "$dir/audit.want" "$dir/audit.ir"
"$tool" --strict --source-offsets "$dir/audit" > "$dir/audit-again.ir"
cmp "$dir/audit.ir" "$dir/audit-again.ir"
"$tool" --strict "$dir/long" > "$dir/long-strict.ir"
printf '000010  ret\n000009  ret\n' > "$dir/backwards"
if "$tool" --strict "$dir/backwards" > "$dir/backwards.ir" 2> "$dir/msg"; then echo '[FAIL] strict accepted backwards offsets'; exit 1; fi
grep -q 'line 2: instruction offsets go backwards' "$dir/msg"
for record in 'changed log format' '000000  ' '00000g  ret'; do
  printf '%s\n' "$record" > "$dir/bad-record"
  if "$tool" --strict "$dir/bad-record" > "$dir/bad-record.ir" 2> "$dir/msg"; then echo '[FAIL] strict accepted malformed record'; exit 1; fi
  grep -q 'line 1: malformed instruction record' "$dir/msg"
done
"$tool" "$dir/backwards" > "$dir/backwards-default.ir"
"$tool" "$dir/audit" > "$dir/plain.ir"
"$tool" -- "$dir/audit" > "$dir/explicit-positional.ir"
cmp "$dir/plain.ir" "$dir/explicit-positional.ir"
printf '[OK] Sayanox IR audit: strict syntax/offset validation, source-offset correlation, duplicate offsets, unknown mnemonics, deterministic output; no executable backend\n'
