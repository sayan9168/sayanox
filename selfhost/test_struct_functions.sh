#!/bin/sh
# The selfhosted C backend, not the seed/native ABI. No interpreter needed.
set -eu
cc=${CC:-cc}
compilers=${STRUCT_FUNCTION_COMPILERS:-'gen2 gen3'}
dir=selfhost/seed_tests/struct-functions
mkdir -p "$dir"
for compiler in $compilers; do
    test -x "selfhost/$compiler" || { echo "need $compiler" >&2; exit 1; }
    for name in values gc gc_register; do
        stem=$dir/$compiler-$name
        "./selfhost/$compiler" "selfhost/struct_function_tests/$name.sa" "$stem.c" >"$stem.log" 2>&1
        for opt in 0 2; do
            "$cc" -O"$opt" -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o "$stem-O$opt" "$stem.c"
            "$stem-O$opt" >"$stem-O$opt.out"
            cmp "selfhost/struct_function_tests/$name.want" "$stem-O$opt.out"
        done
        echo "[OK] $compiler named struct functions: $name (O0/O2)"
    done
    for name in argument identity return_scalar return_identity scalar_return arity_many arity_few nested_argument arithmetic grouped unknown_param unknown_return unresolved_field show_value; do
        src=$dir/$name.sa
        cat > "$src" <<'SA'
struct Point { x }
struct Other { x }
hold p = Point { x: 7 }
hold other = Other { x: 8 }
make copy_point(p: Point) -> Point {
  give p
}
SA
        case $name in
            argument) printf 'hold q = copy_point(1)\n' >> "$src" ;;
            identity) printf 'hold q = copy_point(other)\n' >> "$src" ;;
            return_scalar) printf 'make bad(p: Point) -> Point {\n give 1\n}\n' >> "$src" ;;
            return_identity) printf 'make bad(p: Other) -> Point {\n give p\n}\n' >> "$src" ;;
            scalar_return) printf 'make bad(p: Point) -> num {\n give p\n}\n' >> "$src" ;;
            arity_many) printf 'hold q = copy_point(p, p)\n' >> "$src" ;;
            arity_few) printf 'hold q = copy_point()\n' >> "$src" ;;
            nested_argument) printf 'hold q = copy_point(copy_point(other))\n' >> "$src" ;;
            arithmetic) printf 'hold q = copy_point(p) + 1\n' >> "$src" ;;
            grouped) printf 'hold q = (copy_point(p))\n' >> "$src" ;;
            unknown_param) printf 'make bad(p: Missing) -> num {\n give 1\n}\n' >> "$src" ;;
            unknown_return) printf 'make bad(p: num) -> Missing {\n give p\n}\n' >> "$src" ;;
            unresolved_field) cat > "$src" <<'SA'
struct Point { x }
make bad(p: Point) -> num {
  give p.x
}
hold p = Point { x: 7 }
SA
                ;;
            show_value) printf 'show copy_point(p)\n' >> "$src" ;;
        esac
        stem=$dir/$compiler-$name
        "./selfhost/$compiler" "$src" "$stem.c" >"$stem.log" 2>&1 || :
        # A C type error alone is NOT a checked source refusal.
        grep -q '^#error sayanox-min:' "$stem.c" || { echo "[FAIL] $compiler $name lacks source diagnostic"; exit 1; }
        if "$cc" -O2 -o "$stem" "$stem.c" >"$stem.cc.log" 2>&1; then
            echo "[FAIL] $compiler accepted $name"; exit 1
        fi
    done
    echo "[OK] $compiler struct signature mismatches and bounded-form refusals (14 cases)"
done
