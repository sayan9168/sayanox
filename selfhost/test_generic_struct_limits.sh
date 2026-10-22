#!/bin/sh
# The generic-struct type-argument boundary, after nested and list arguments
# landed (2026-10-22).
#
# ACCEPTED now, and gated positively by selfhost/generic_struct_nested.sa:
#   Box<list>, Box<Box<num>>, Box<Box<Box<num>>>, Pair<Box<num>, str>,
#   and the same lists written across lines or with a // note inside them.
#
# STILL REFUSED by all three backends, which is what this script pins: a type
# argument that is not num/str/list and not an instantiation of a declared
# generic struct -- a concrete struct name, an unknown name, a type parameter
# that escaped its template -- and the wrong number of arguments.
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
struct Pt { x }
hold good = Box<num> { 7 }
hold text = Box<str> { "safe" }
hold nest = Box<Box<num>> { good }
hold bad = $type { $value }
show good.v
show text.v
show nest.v.v
EOF
    if ./selfhost/seed/sxc_seed_min "$src" > "$dir/$name-seed.c" 2> "$dir/$name-seed.err"; then
        echo "[FAIL] seed accepted $name"; exit 1
    fi
    grep -q 'seed_min:' "$dir/$name-seed.err"
    grep -Eq 'a type argument must be|type argument, got|type arguments, got|is a generic struct' "$dir/$name-seed.err"
    ./selfhost/gen2 "$src" "$dir/$name-gen2.c" > "$dir/$name-gen2.msg" 2>&1
    grep -q '#error sayanox-min:' "$dir/$name-gen2.c"
    # A language refusal must prevent a downstream build, not just print prose.
    if $cc -c "$dir/$name-gen2.c" -o "$dir/$name-gen2.o" > "$dir/$name-cc.err" 2>&1; then
        echo "[FAIL] gen2 refusal remained compilable: $name"; exit 1
    fi
    if ./selfhost/native_aot "$src" "$dir/$name-native" > "$dir/$name-native.msg" 2>&1; then
        echo "[FAIL] native accepted $name"; exit 1
    fi
    grep -Eq 'a type argument must be|type argument, got|type arguments, got|is a generic struct' "$dir/$name-native.msg"
    echo "[OK] generic struct type-argument limit: $name refused by seed/gen2/native; gen2 C cannot compile"
}
check concrete-struct 'Box<Pt>' '7'
check concrete-struct-second 'Pair<num, Pt>' '1, 2'
check unknown-name 'Box<Nope>' '7'
check escaped-parameter 'Box<T>' '7'
check too-many 'Box<num, str>' '7, "x"'
check too-few 'Pair<num>' '1, "x"'
check bare-template 'Box' '7'
# The literal must agree with its own type argument. seed-min and native both
# check this; gen2 learns a field kind from a single contradicting literal
# instead (the long-standing divergence recorded in docs/TYPES_ROADMAP.md), so
# only the two checking backends are asserted here.
argcheck() {
    name=$1
    type=$2
    value=$3
    want=$4
    src=$dir/$name.sa
    cat > "$src" <<EOF
struct Box<T> { v }
hold good = Box<num> { 7 }
hold text = Box<str> { "safe" }
hold bad = $type { $value }
show good.v
EOF
    if ./selfhost/seed/sxc_seed_min "$src" > "$dir/$name-seed.c" 2> "$dir/$name-seed.err"; then
        echo "[FAIL] seed accepted $name"; exit 1
    fi
    grep -q "$want" "$dir/$name-seed.err"
    if ./selfhost/native_aot "$src" "$dir/$name-native" > "$dir/$name-native.msg" 2>&1; then
        echo "[FAIL] native accepted $name"; exit 1
    fi
    grep -q "$want" "$dir/$name-native.msg"
    echo "[OK] generic struct literal limit: $name refused by seed-min and native (gen2 diverges: documented)"
}
argcheck nested-gets-number 'Box<Box<num>>' '7' 'its type argument says so'
argcheck nested-wrong-struct 'Box<Box<num>>' 'text' 'the literal gives a Box__s'
argcheck list-gets-number 'Box<list>' '7' 'its type argument says so'
echo '[OK] generic-struct type arguments: num, str, list and nested instantiations; everything else refused by all three backends'
