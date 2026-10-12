#!/bin/sh
set -eu
gen2=$1
work=$2
for expr in '[s]' '[s+1]' '[xs]' '[xs+1]' '[word()]' '[plus(s)]' '[plus()]' '[plus(1,2)]' '[len(3)]' '[sx_index(3,0)]' '[[1]]' '[len([s])]' '[sx_index("a","b")]' '[s<3]' '[1==s]' '[1+]' '[1,]' '[1 2]' '[1.2.3]' '[()]' '[(1]' '[1][0]' '[1]+2'; do
  cat > "$work/inline_bad.sa" <<'SRC'
make size(xs: list) -> num {
  give len(xs)
}
make plus(n: num) -> num {
  give n + 1
}
make word() -> str {
  give "bad"
}
hold s = "bad"
hold xs = [1]
SRC
  printf 'show size(%s)\n' "$expr" >> "$work/inline_bad.sa"
  "$gen2" "$work/inline_bad.sa" "$work/inline_bad.c" > "$work/inline_bad.log"
  if ! grep -q '^#error.*inline list arguments' "$work/inline_bad.c"; then
    echo "[FAIL] invalid inline expression accepted: $expr"; cat "$work/inline_bad.log"; exit 1
  fi
done
echo '[OK] typed inline diagnostics: nonnumeric elements/operators, call arity/kinds, nested numeric-list violations, malformed syntax and numeric postfix values passed to list parameters'
