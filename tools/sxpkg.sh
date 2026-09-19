#!/bin/sh
# sxpkg — Sayanox package manager + local registry
set -e
ROOT="${SXPKG_ROOT:-.}"
PKGDIR="$ROOT/.sayanox/pkgs"
REG="$ROOT/.sayanox/registry"
LOCK="$ROOT/sx.lock"
MANIFEST="$ROOT/sx.toml"
INDEX="$REG/INDEX"
cmd="${1:-help}"; shift 2>/dev/null || true
seed_registry() {
  mkdir -p "$REG/hello" "$REG/math"
  printf 'name=hello\nversion=0.1.0\ndesc=hello world sample\n' > "$REG/hello/pkg.meta"
  printf 'show "hello from pkg"\n' > "$REG/hello/main.sa"
  printf 'name=math\nversion=0.1.0\ndesc=tiny math helpers\n' > "$REG/math/pkg.meta"
  printf 'make double(n) { give n + n }\n' > "$REG/math/main.sa"
  printf 'hello=0.1.0\nmath=0.1.0\n' > "$INDEX"
}
init() {
  mkdir -p "$PKGDIR" "$REG"
  [ -f "$LOCK" ] || printf '# sx.lock\nversion=1\n' > "$LOCK"
  [ -f "$MANIFEST" ] || printf 'name = "my-pkg"\nversion = "0.1.0"\n' > "$MANIFEST"
  [ -f "$INDEX" ] || seed_registry
  echo "sxpkg: init ok"
}
add() {
  name="$1"; ver="${2:-0.1.0}"
  [ -n "$name" ] || { echo "usage: sxpkg add <name> [ver]"; exit 1; }
  mkdir -p "$PKGDIR" "$REG/$name"
  grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=$ver" >> "$LOCK"
  printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
  echo "sxpkg: added $name $ver"
}
list() { echo "sxpkg: locked"; [ -f "$LOCK" ] && grep -v '^#' "$LOCK" | grep -v '^$' || echo "(none)"; }
install() {
  mkdir -p "$PKGDIR"; [ -f "$LOCK" ] || exit 1
  while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; esac
    [ -d "$REG/$n" ] && { mkdir -p "$PKGDIR/$n"; cp -r "$REG/$n/." "$PKGDIR/$n/" 2>/dev/null; echo "sxpkg: installed $n"; }
  done < "$LOCK"; echo "sxpkg: install done"
}
search() {
  q="${1:-}"; echo "sxpkg: search '$q'"; [ -f "$INDEX" ] || seed_registry
  [ -f "$INDEX" ] && while IFS='=' read -r n v; do case "$n" in *$q*) echo "  $n $v" ;; esac; done < "$INDEX"
}
publish() {
  name=$(grep '^name' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo local)
  ver=$(grep '^version' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo 0.1.0)
  mkdir -p "$REG/$name"; printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
  echo "$name=$ver" >> "$INDEX"; echo "sxpkg: published $name $ver"
}
remove() {
  name="$1"; [ -n "$name" ] || exit 1
  [ -f "$LOCK" ] && { tmp=$(mktemp); grep -v "^$name=" "$LOCK" > "$tmp" && mv "$tmp" "$LOCK"; }
  rm -rf "$PKGDIR/$name" "$REG/$name"; echo "sxpkg: removed $name"
}
info() { [ -f "$REG/$1/pkg.meta" ] && cat "$REG/$1/pkg.meta" || echo "unknown $1"; }

fetch() {
  url="$1"
  [ -n "$url" ] || { echo "usage: sxpkg fetch <url> [name]"; exit 1; }
  name="${2:-remote_pkg}"
  mkdir -p "$REG/$name" "$PKGDIR/$name"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$REG/$name/main.sa" || { echo "sxpkg: fetch failed"; exit 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$REG/$name/main.sa" "$url" || { echo "sxpkg: fetch failed"; exit 1; }
  else
    echo "sxpkg: need curl or wget"; exit 1
  fi
  printf "name=%s\nversion=0.0.0\nsource=%s\n" "$name" "$url" > "$REG/$name/pkg.meta"
  grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=0.0.0" >> "$LOCK"
  cp -r "$REG/$name/." "$PKGDIR/$name/"
  echo "sxpkg: fetched $name from $url"
}
types_check() {
  f="$1"
  [ -f "$f" ] || { echo "usage: sxpkg types <file.sa>"; exit 1; }
  echo "sxpkg: type tags (heuristic)"
  grep -nE "hold |is_str|is_num|make |struct " "$f" | head -40 || true
}
case "$cmd" in
  init) init ;; add) add "$@" ;; list) list ;; install) install ;;
  search) search "$@" ;; publish) publish ;; remove) remove "$@" ;;
  info) info "$@" ;; seed) seed_registry; echo seeded ;;
  fetch) fetch "$@" ;; types) types_check "$@" ;;
  *) echo "sxpkg: init|add|list|install|search|publish|remove|info|seed|fetch|types" ;;
esac
