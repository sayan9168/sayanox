#!/bin/sh
# Run after make gen3; check real bootstrap artifacts, not a separate demo.
set -eu
grep -q -F 'use "selfhost/modules/compiler_text.sa"' selfhost/compiler_min.sa
grep -q -F 'make sxminimum<T>' selfhost/modules/compiler_text.sa
for file in selfhost/gen1_min.c selfhost/gen2.c selfhost/gen3.c selfhost/gen4.c; do
    test -s "$file"
    for text in \
        'typedef struct { char *input; char *output; } CompilerPaths;' \
        'sx_read(compiler_paths.input)' \
        'sx_len(compiler_paths.input)' \
        'sx_idx(compiler_paths.input,exd)' \
        'sx_write(compiler_paths.output,out)' \
        'typedef struct { double bytes; } CompilerSourceSize__n;' \
        'compiler_source_size.bytes'; do
        grep -q -F "$text" "$file" || {
            echo "[FAIL] compiler source feature missing in $file: $text" >&2
            exit 1
        }
    done
    case "$file" in
      *gen1_min.c) grep -q -E 'double stop = _sx_gen_[0-9_]+\(end,sx_len\(text\)\)' "$file" ;;
      *) grep -q -F 'sxminimum__n(end,sx_len(text))' "$file" ;;
    esac
done
# Every real compiler generation must compile the same live module fixture.
cc=${CC:-cc}
for compiler in gen1_min gen2 gen3; do
    dest=selfhost/seed_tests/compiler-text-$compiler
    ./selfhost/$compiler selfhost/compiler_text_test.sa "$dest.c" > "$dest.msg"
    "$cc" -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o "$dest" "$dest.c"
    "$dest" > "$dest.out"
    printf '3\n-5\nbcd\ncdef\n0\n0\n1024\n' > "$dest.want"
    cmp "$dest.want" "$dest.out"
done
cmp selfhost/gen3.c selfhost/gen4.c
echo '[OK] compiler source uses live module, generic function, generic struct size state and concrete path fields; gen1-min/gen2/gen3 compile the module fixture; gen3==gen4 (not full-language self-host)'
