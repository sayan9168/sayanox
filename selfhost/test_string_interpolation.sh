#!/bin/sh
# Identifier-only interpolation in the selfhosted C backend; not seed/native.
set -eu
cc=${CC:-cc}
compilers=${INTERPOLATION_COMPILERS:-'gen2 gen3'}
dir=selfhost/seed_tests/string-interpolation
mkdir -p "$dir"
for compiler in $compilers; do
    test -x "selfhost/$compiler" || { echo "need $compiler" >&2; exit 1; }
    for name in values import gc escaped struct_integration; do
        stem=$dir/$compiler-$name
        "./selfhost/$compiler" "selfhost/interpolation_tests/$name.sa" "$stem.c" >"$stem.log" 2>&1
        for opt in 0 2; do
            "$cc" -std=c11 -D_POSIX_C_SOURCE=200809L -O"$opt" -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o "$stem-O$opt" "$stem.c"
            "$stem-O$opt" >"$stem-O$opt.out"
            cmp "selfhost/interpolation_tests/$name.want" "$stem-O$opt.out"
        done
        echo "[OK] $compiler identifier interpolation: $name (O0/O2)"
    done
    for name in empty unclosed expression call field unknown list struct excess bad_identifier; do
        src=$dir/$name.sa
        case $name in
            empty) printf 'show "${}"\n' > "$src" ;;
            unclosed) printf 'show "${name"\n' > "$src" ;;
            expression) printf 'hold n = 1\nshow "${n + 1}"\n' > "$src" ;;
            call) printf 'show "${arg_count()}"\n' > "$src" ;;
            field) printf 'struct Point { x }\nhold p = Point { x: 7 }\nshow "${p.x}"\n' > "$src" ;;
            unknown) printf 'show "${missing}"\n' > "$src" ;;
            list) printf 'hold xs = [1, 2]\nshow "${xs}"\n' > "$src" ;;
            struct) printf 'struct Point { x }\nhold p = Point { x: 7 }\nshow "${p}"\n' > "$src" ;;
            bad_identifier) printf 'show "${1}"\n' > "$src" ;;
            excess)
                printf 'hold n = 1\nshow "' > "$src"
                i=0; while [ "$i" -lt 17 ]; do printf '${n}' >> "$src"; i=$((i+1)); done
                printf '"\n' >> "$src" ;;
        esac
        stem=$dir/$compiler-$name
        "./selfhost/$compiler" "$src" "$stem.c" >"$stem.log" 2>&1 || :
        grep -q '^#error sayanox-min:' "$stem.c" || { echo "[FAIL] $compiler $name lacks source diagnostic"; exit 1; }
        if "$cc" -O2 -o "$stem" "$stem.c" >"$stem.cc.log" 2>&1; then
            echo "[FAIL] $compiler accepted interpolation $name"; exit 1
        fi
    done
    # The maximum itself must work, not merely the overflow refusal.
    src=$dir/limit.sa
    printf 'hold n = 1\nshow "' > "$src"
    i=0; while [ "$i" -lt 16 ]; do printf '${n}' >> "$src"; i=$((i+1)); done
    printf '"\n' >> "$src"
    stem=$dir/$compiler-limit
    "./selfhost/$compiler" "$src" "$stem.c" >"$stem.log" 2>&1
    "$cc" -O2 -o "$stem" "$stem.c"
    "$stem" >"$stem.out"
    printf '1111111111111111\n' >"$stem.want"
    cmp "$stem.want" "$stem.out"
    echo "[OK] $compiler interpolation: 16-hole boundary and 10 source-diagnostic refusals"
done
