#!/bin/sh
# Sayanox package manager — minimal, no Node/Python
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REG="$ROOT/packages"
LOCK="$ROOT/sx.lock"
PKGDIR="$ROOT/.sx/pkgs"
cmd=${1:-help}
case "$cmd" in
  init)
    mkdir -p "$REG" "$PKGDIR"
    [ -f "$LOCK" ] || printf '# sx.lock\nversion=1\n' > "$LOCK"
    [ -f "$ROOT/sx.toml" ] || printf 'name = "app"\nversion = "0.1.0"\n' > "$ROOT/sx.toml"
    echo "sxpkg: initialized"
    ;;
  add)
    name=$2
    [ -n "$name" ] || { echo "usage: sxpkg add <name>"; exit 1; }
    mkdir -p "$REG/$name"
    printf 'name=%s\nversion=0.1.0\n' "$name" > "$REG/$name/pkg.meta"
    printf 'show "%s loaded"\n' "$name" > "$REG/$name/lib.sa"
    grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=0.1.0" >> "$LOCK"
    echo "sxpkg: added $name"
    ;;
  list)
    echo "Installed / registered:"
    [ -f "$LOCK" ] && grep -v '^#' "$LOCK" || echo "(none)"
    ;;
  install)
    mkdir -p "$PKGDIR"
    if [ -f "$LOCK" ]; then
      while IFS='=' read -r n v; do
        case "$n" in \#*|"") continue ;; esac
        if [ -d "$REG/$n" ]; then
          mkdir -p "$PKGDIR/$n"
          cp -r "$REG/$n/." "$PKGDIR/$n/" 2>/dev/null
          echo "sxpkg: installed $n $v"
        else
          echo "sxpkg: missing registry entry for $n"
        fi
      done < "$LOCK"
    fi
    echo "sxpkg: install done"
    ;;
  help|*)
    echo "sxpkg — Sayanox package manager"
    echo "  init | add <name> | list | install"
    ;;
esac
