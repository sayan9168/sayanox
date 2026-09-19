#!/bin/sh
# sxpkg — Sayanox package manager
set -e
ROOT="${SXPKG_ROOT:-.}"
PKGDIR="$ROOT/.sayanox/pkgs"
REG="$ROOT/.sayanox/registry"
LOCK="$ROOT/sx.lock"
MANIFEST="$ROOT/sx.toml"
cmd="${1:-help}"; shift 2>/dev/null || true
case "$cmd" in
  init)
    mkdir -p "$PKGDIR" "$REG"
    [ -f "$LOCK" ] || printf '# sx.lock\nversion=1\n' > "$LOCK"
    [ -f "$MANIFEST" ] || printf 'name = "my-pkg"\nversion = "0.1.0"\n' > "$MANIFEST"
    echo "sxpkg: init ok" ;;
  add)
    name="$1"; ver="${2:-0.1.0}"
    [ -n "$name" ] || { echo "usage: sxpkg add <name> [ver]"; exit 1; }
    mkdir -p "$PKGDIR" "$REG/$name"
    grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=$ver" >> "$LOCK"
    printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
    echo "sxpkg: added $name $ver" ;;
  list)
    echo "sxpkg: packages"; [ -f "$LOCK" ] && grep -v '^#' "$LOCK" | grep -v '^$' || echo "(none)" ;;
  install)
    mkdir -p "$PKGDIR"; [ -f "$LOCK" ] || exit 1
    while IFS='=' read -r n v; do
      case "$n" in \#*|"") continue ;; esac
      [ -d "$REG/$n" ] && { mkdir -p "$PKGDIR/$n"; cp -r "$REG/$n/." "$PKGDIR/$n/" 2>/dev/null; echo "sxpkg: installed $n"; }
    done < "$LOCK"; echo "sxpkg: install done" ;;
  search)
    q="$1"; echo "sxpkg: search '$q'"
    for d in "$REG"/*; do [ -d "$d" ] || continue; bn=$(basename "$d"); case "$bn" in *$q*) echo "  $bn" ;; esac; done ;;
  publish)
    name=$(grep '^name' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo local)
    ver=$(grep '^version' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo 0.1.0)
    mkdir -p "$REG/$name"; printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
    echo "sxpkg: published $name $ver" ;;
  remove)
    name="$1"; [ -n "$name" ] || exit 1
    [ -f "$LOCK" ] && { tmp=$(mktemp); grep -v "^$name=" "$LOCK" > "$tmp" && mv "$tmp" "$LOCK"; }
    rm -rf "$PKGDIR/$name" "$REG/$name"; echo "sxpkg: removed $name" ;;
  *)
    echo "sxpkg: init|add|list|install|search|publish|remove" ;;
esac
