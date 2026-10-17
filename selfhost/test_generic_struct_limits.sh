#!/bin/sh
# Current bootstrap contract: no nested/struct/list generic struct arguments.
# Gen2 diagnoses via #error C; seed/native must return failure themselves.
set -eu
cc=${CC:-cc}
dir=selfhost/seed_tests/generic-limits
mkdir -p "$dir"
check() {
    name=$1
    type=$2
    value=$3
    src=$dir/$name.sa
    # Valid instances first ensure an existing specialization cannot mask a bad
    # argument or turn it into the previously registered numeric/string layout.
    cat > "$src" <<EOF
struct Box<T> { v }
struct Pair<A, B> { a, b }
hold good = Box<num> { 7 }
hold text = Box<str> { "safe" }
hold bad = $type { $value }
show good.v
show text.v
EOF
    if ./selfhost/seed/sxc_seed_min "$src" > "$dir/$name-seed.c" 2> "$dir/$name-seed.err"; then
        echo "[FAIL] seed accepted $name"; exit 1
    fi
    grep -q 'seed_min:' "$dir/$name-seed.err"
    grep -Eq 'not implemented|cannot hold a list' "$dir/$name-seed.err"
    ./selfhost/gen2 "$src" "$dir/$name-gen2.c" > "$dir/$name-gen2.msg" 2>&1
    grep -q '#error sayanox-min:' "$dir/$name-gen2.c"
    # A language refusal must prevent a downstream build, not just print prose.
    if $cc -c "$dir/$name-gen2.c" -o "$dir/$name-gen2.o" > "$dir/$name-cc.err" 2>&1; then
        echo "[FAIL] gen2 refusal remained compilable: $name"; exit 1
    fi
    if ./selfhost/native_aot "$src" "$dir/$name-native" > "$dir/$name-native.msg" 2>&1; then
        echo "[FAIL] native accepted $name"; exit 1
    fi
    grep -Eq 'not implemented|cannot hold a list|a type argument must be num, str or list' "$dir/$name-native.msg"
    echo "[OK] generic struct bootstrap limit: $name refused by seed/gen2/native; gen2 C cannot compile"
}
check nested-num 'Box<Box<num>>' '7'
check nested-str 'Box<Box<str>>' '"unsafe"'
check nested-spaced 'Box< Box < num > >' '7'
check nested-comment 'Box< // type
 Box<num> >' '7'
check nested-second 'Pair<num, Box<str>>' '1, "unsafe"'
check list 'Box<list>' '[1, 2]'
check list-second 'Pair<str, list>' '"safe", [1, 2]'
echo '[OK] permanent bootstrap generic-struct boundary: scalar type arguments only; no recursive/list layout claimed'
