#!/bin/sh
# sxpkg — Sayanox package manager (local + online registry)
set -e
ROOT="${SAYANOX_ROOT:-.}"
PKGDIR="$ROOT/.sayanox/pkgs"
REG="$ROOT/.sayanox/registry"
LOCK="$ROOT/sx.lock"
MANIFEST="$ROOT/sx.toml"
INDEX="$REG/INDEX"
ONLINE="${SAYANOX_REGISTRY:-https://raw.githubusercontent.com/sayan9168/sayanox/main/registry}"

cmd="${1:-help}"; shift 2>/dev/null || true

seed_local() {
  mkdir -p "$REG/hello" "$REG/math"
  printf 'name=hello\nversion=0.1.0\ndesc=hello world sample\n' > "$REG/hello/pkg.meta"
  printf 'show "hello from pkg"\n' > "$REG/hello/main.sa"
  printf 'name=math\nversion=0.1.0\ndesc=tiny math helpers\n' > "$REG/math/pkg.meta"
  printf 'make double(n) { give n + n }\n' > "$REG/math/main.sa"
  printf 'hello=0.1.0\nmath=0.1.0\n' > "$INDEX"
}

download() {
  url="$1"; dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$dest" "$url"
  else
    echo "sxpkg: need curl or wget"; return 1
  fi
}

init() {
  mkdir -p "$PKGDIR" "$REG"
  [ -f "$LOCK" ] || printf '# sx.lock\n' > "$LOCK"
  [ -f "$MANIFEST" ] || printf 'name = "my-pkg"\nversion = "0.1.0"\n' > "$MANIFEST"
  [ -f "$INDEX" ] || seed_local
  echo "sxpkg: init ok (registry=$REG online=$ONLINE)"
}

sync() {
  mkdir -p "$REG"
  echo "sxpkg: sync from $ONLINE"
  tmp=$(mktemp)
  if download "$ONLINE/INDEX" "$tmp"; then
    cp "$tmp" "$INDEX"
    echo "sxpkg: index updated"
    while IFS='=' read -r n v; do
      case "$n" in \#*|"") continue ;; esac
      mkdir -p "$REG/$n"
      download "$ONLINE/$n/pkg.meta" "$REG/$n/pkg.meta" 2>/dev/null || true
      download "$ONLINE/$n/main.sa" "$REG/$n/main.sa" 2>/dev/null || true
      echo "  synced $n=$v"
    done < "$INDEX"
  else
    echo "sxpkg: online sync failed; using local seed"
    seed_local
  fi
  rm -f "$tmp"
}

add() {
  name="$1"; ver="${2:-0.1.0}"
  [ -n "$name" ] || { echo "usage: sxpkg add <name> [ver]"; exit 1; }
  mkdir -p "$PKGDIR" "$REG"
  grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=$ver" >> "$LOCK"
  echo "sxpkg: locked $name $ver (run install)"
}

list() {
  echo "sxpkg: locked packages"
  if [ -f "$LOCK" ]; then
    grep -v '^#' "$LOCK" | grep -v '^$' | grep -v '^version=' | grep -v '^name=' || echo "(none)"
  else echo "(none)"; fi
}

install() {
  mkdir -p "$PKGDIR"
  [ -f "$LOCK" ] || { echo "sxpkg: no sx.lock — run init/add"; exit 1; }
  [ -f "$INDEX" ] || sync
  while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; version|name) continue ;; esac
    if [ ! -d "$REG/$n" ]; then
      mkdir -p "$REG/$n"
      download "$ONLINE/$n/pkg.meta" "$REG/$n/pkg.meta" 2>/dev/null || true
      download "$ONLINE/$n/main.sa" "$REG/$n/main.sa" 2>/dev/null || true
    fi
    if [ -d "$REG/$n" ]; then
      mkdir -p "$PKGDIR/$n"
      cp -r "$REG/$n/." "$PKGDIR/$n/" 2>/dev/null || true
      echo "sxpkg: installed $n -> $PKGDIR/$n"
    else
      echo "sxpkg: missing $n in registry"
    fi
  done < "$LOCK"
  echo "sxpkg: install done"
}

search() {
  q="${1:-}"
  echo "sxpkg: search '$q'"
  [ -f "$INDEX" ] || sync
  [ -f "$INDEX" ] && while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; *$q*) echo "  $n $v" ;; esac
  done < "$INDEX"
}

publish() {
  name=$(grep '^name' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo local)
  ver=$(grep '^version' "$MANIFEST" 2>/dev/null | sed 's/.*= *"\?\([^"]*\)"\?.*/\1/' || echo 0.1.0)
  mkdir -p "$REG/$name"
  printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
  [ -f main.sa ] && cp main.sa "$REG/$name/main.sa"
  grep -q "^$name=" "$INDEX" 2>/dev/null || echo "$name=$ver" >> "$INDEX"
  echo "sxpkg: published locally $name $ver"
  echo "sxpkg: to go online, commit registry/$name to the sayanox repo"
}

remove() {
  name="$1"; [ -n "$name" ] || exit 1
  [ -f "$LOCK" ] && { tmp=$(mktemp); grep -v "^$name=" "$LOCK" > "$tmp" && mv "$tmp" "$LOCK"; }
  rm -rf "$PKGDIR/$name"
  echo "sxpkg: removed $name from lock/pkgs"
}

info() {
  n="$1"
  if [ -f "$REG/$n/pkg.meta" ]; then cat "$REG/$n/pkg.meta"
  else echo "unknown $n — try: sxpkg sync && sxpkg search"
  fi
}

fetch() {
  url="$1"; name="${2:-remote_pkg}"
  [ -n "$url" ] || { echo "usage: sxpkg fetch <url> [name]"; exit 1; }
  mkdir -p "$REG/$name" "$PKGDIR/$name"
  download "$url" "$REG/$name/main.sa"
  printf "name=%s\nversion=0.0.0\nsource=%s\n" "$name" "$url" > "$REG/$name/pkg.meta"
  grep -q "^$name=" "$LOCK" 2>/dev/null || echo "$name=0.0.0" >> "$LOCK"
  cp -r "$REG/$name/." "$PKGDIR/$name/"
  echo "sxpkg: fetched $name from $url"
}

case "$cmd" in
  init) init ;;
  sync) sync ;;
  add) add "$@" ;;
  list) list ;;
  install) install ;;
  search) search "$@" ;;
  publish) publish ;;
  remove) remove "$@" ;;
  info) info "$@" ;;
  seed) seed_local; echo seeded ;;
  fetch) fetch "$@" ;;
  *) echo "sxpkg: init|sync|add|list|install|search|publish|remove|info|seed|fetch"
     echo "  ONLINE registry: $ONLINE"
     echo "  override: SAYANOX_REGISTRY=https://..."
     ;;
esac
