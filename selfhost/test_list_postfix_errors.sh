#!/bin/sh
set -eu
gen2=$1
seed=$2
work=$3
mkdir -p "$work"
for expr in '[p.missing]' '[p.x.missing]' '[p.label]' '[len(p.x)]' '[p.x][0]' '([p.x])[0]' '[p.x]["bad"]'; do
  cat > "$work/postfix_bad.sa" <<'SRC'
struct Point {
  x, label
}
make size(xs: list) -> num {
  give len(xs)
}
hold p = Point { x: 3, label: "bad" }
SRC
  printf 'show size(%s)\n' "$expr" >> "$work/postfix_bad.sa"
  "$gen2" "$work/postfix_bad.sa" "$work/postfix_bad.c" > "$work/postfix_bad.log"
  if ! grep -q '^#error.*inline list arguments' "$work/postfix_bad.c"; then
    echo "[FAIL] gen2 accepted invalid field/postfix argument: $expr"
    cat "$work/postfix_bad.log"
    exit 1
  fi
  if "$seed" "$work/postfix_bad.sa" > "$work/postfix_bad_seed.c" 2> "$work/postfix_bad_seed.log"; then
    echo "[FAIL] seed accepted invalid field/postfix argument: $expr"
    exit 1
  fi
  test -s "$work/postfix_bad_seed.log"
done
echo '[OK] seed/gen2 reject unknown fields, nonstruct selectors, nonnumeric elements, invalid index kinds and list-parameter kind mismatches'
