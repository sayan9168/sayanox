#!/bin/sh
# Closure probes for a broader language, NOT an exhaustive language standard.
# No rejection or wrong output is counted as a success.
set -eu
cc=${CC:-cc}
dir=selfhost/seed_tests/full-language-readiness
mkdir -p "$dir"
blocked=0
for compiler in gen2 gen3; do
    test -x "selfhost/$compiler" || { echo "run true-selfhost and gen3 first" >&2; exit 1; }
    for name in string_interpolation struct_function field_expression index_call; do
        stem=$dir/$compiler-$name
        if ! "./selfhost/$compiler" "selfhost/full_language_tests/$name.sa" "$stem.c" > "$stem.compile.log" 2>&1; then
            echo "[BLOCKED] $compiler $name: compiler refusal ($stem.compile.log)"
            blocked=$((blocked+1)); continue
        fi
        if ! "$cc" -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o "$stem" "$stem.c" > "$stem.cc.log" 2>&1; then
            echo "[BLOCKED] $compiler $name: generated C does not compile ($stem.cc.log)"
            blocked=$((blocked+1)); continue
        fi
        if ! "$stem" > "$stem.out" 2> "$stem.run.log"; then
            echo "[BLOCKED] $compiler $name: generated program fails ($stem.run.log)"
            blocked=$((blocked+1)); continue
        fi
        if ! cmp "selfhost/full_language_tests/$name.want" "$stem.out" > "$stem.diff.log" 2>&1; then
            echo "[BLOCKED] $compiler $name: output differs from required behavior ($stem.out)"
            blocked=$((blocked+1)); continue
        fi
        echo "[OK] broader-language readiness: $compiler $name"
    done
done
if [ "$blocked" -ne 0 ]; then
    echo "[FAIL] full-language readiness: $blocked unmet compiler/behavior checks; full-language self-host NOT proved"
    exit 1
fi
echo '[OK] closure probes pass; this is not an exhaustive full-language acceptance specification'
