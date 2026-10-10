#!/bin/sh
# Local project/registry commands delegate to Sayanox; online transfers remain shell.
set -e
ROOT="${SAYANOX_ROOT:-.}"
PKGDIR="$ROOT/.sayanox/pkgs"
REG="$ROOT/.sayanox/registry"
LOCK="$ROOT/sx.lock"
MANIFEST="$ROOT/sx.toml"
INDEX="$REG/INDEX"
ONLINE="${SAYANOX_REGISTRY:-https://raw.githubusercontent.com/sayan9168/sayanox/main/registry}"
case "$0" in
  */*) SXPKG_SCRIPT_DIR=${0%/*}; [ -n "$SXPKG_SCRIPT_DIR" ] || SXPKG_SCRIPT_DIR=/ ;;
  *) SXPKG_SCRIPT_DIR=tools ;;
esac
SXPKG_SCRIPT_DIR=$(CDPATH= cd "$SXPKG_SCRIPT_DIR" && pwd)
SAYANOX_REPO_ROOT=$(CDPATH= cd "$SXPKG_SCRIPT_DIR/.." && pwd)
SXPKG_BIN="$SXPKG_SCRIPT_DIR/sxpkg"

cmd="${1:-help}"; shift 2>/dev/null || true

download() {
  url="$1"; dest="$2"; part="$dest.part"
  # Download to a .part file and rename only on success, so an interrupted
  # transfer never leaves a truncated package where a good one should be.
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$part" || { rm -f "$part"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$part" "$url" || { rm -f "$part"; return 1; }
  else
    echo "sxpkg: need curl or wget"; return 1
  fi
  mv -f "$part" "$dest"
}

run_sayanox() {
  sx_cmd="$1"; shift
  [ -x "$SXPKG_BIN" ] || make -C "$SAYANOX_REPO_ROOT" sxpkg
  case "$sx_cmd" in
    init|add) mkdir -p "$PKGDIR" "$REG" ;;
    seed) mkdir -p "$REG/hello" "$REG/math" ;;
  esac
  if (cd "$ROOT" && "$SXPKG_BIN" "$sx_cmd" "$@"); then
    sx_status=0
  else
    sx_status=$?
  fi
  if [ "$sx_cmd" = init ] && [ "$sx_status" -eq 0 ] && [ ! -f "$INDEX" ]; then
    run_sayanox seed
  fi
  if [ "$sx_cmd" = remove ] && [ "$sx_status" -eq 0 ] && [ -n "${1:-}" ] && [ -d "$PKGDIR/$1" ]; then
    rm -rf "$PKGDIR/$1"
  fi
  return "$sx_status"
}

init() {
  run_sayanox init
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
    seed
  fi
  rm -f "$tmp"
}

add() {
  run_sayanox add "$@"
  # The Sayanox binary locks any name it is given. Say so when the name has no
  # local registry copy, so an offline user is not surprised by `verify` later.
  if [ -n "${1:-}" ] && [ ! -f "$REG/$1/pkg.meta" ]; then
    echo "sxpkg: note: $1 has no local registry copy yet (run: sxpkg seed; or sxpkg sync when online)"
  fi
}

# checked: run a Sayanox subcommand and turn its report into an exit status.
# The Sayanox binary cannot set its own exit code (the language has no exit
# builtin), so a failure is recognised from its FAILED line. Output is kept.
checked() {
  [ -x "$SXPKG_BIN" ] || make -C "$SAYANOX_REPO_ROOT" sxpkg >/dev/null
  checked_out=$(cd "$ROOT" && "$SXPKG_BIN" "$@" 2>&1) || true
  [ -n "$checked_out" ] && printf '%s\n' "$checked_out"
  case "$checked_out" in
    *FAILED*|*"sxpkg: DEP "*) return 1 ;;
  esac
  return 0
}

list() {
  run_sayanox list "$@"
}

deps() {
  run_sayanox deps "$@"
}

# install-local: the offline install.  It creates .sayanox/registry/<name>/
# for every locked package (Sayanox has no mkdir) and then lets the Sayanox
# tool copy each package, and its `deps=` closure, out of a local registry
# directory (default ./registry), checking the version and the pkg.meta sum
# on the way.  No network: `install` is the online command.
install_local() {
  src="${1:-registry}"
  mkdir -p "$PKGDIR"
  [ -f "$LOCK" ] || { echo "sxpkg: no sx.lock - run init/add"; exit 1; }
  case "$src" in /*) ;; *) src=$(CDPATH= cd "$ROOT" && pwd)/"$src" ;; esac
  while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; version|name) continue ;; esac
    mkdir -p "$REG/$n"
  done < "$LOCK"
  checked install "$src"
}

install() {
  mkdir -p "$PKGDIR"
  [ -f "$LOCK" ] || { echo "sxpkg: no sx.lock — run init/add"; exit 1; }
  [ -f "$INDEX" ] || sync
  fetched=""
  while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; version|name) continue ;; esac
    case "$n" in
      */*|*..*) echo "sxpkg: refusing unsafe package name '$n'"; continue ;;
    esac
    # Fetch only what is absent. A package counts as present only when both
    # files exist: an empty directory left by a failed download is not a copy.
    if [ ! -f "$REG/$n/pkg.meta" ] || [ ! -f "$REG/$n/main.sa" ]; then
      fetched="$fetched $n"
      mkdir -p "$REG/$n"
      download "$ONLINE/$n/pkg.meta" "$REG/$n/pkg.meta" || echo "sxpkg: could not fetch $n/pkg.meta from $ONLINE"
      download "$ONLINE/$n/main.sa" "$REG/$n/main.sa" || echo "sxpkg: could not fetch $n/main.sa from $ONLINE"
    fi
    if [ -f "$REG/$n/pkg.meta" ] && [ -f "$REG/$n/main.sa" ]; then
      mkdir -p "$PKGDIR/$n"
      cp -r "$REG/$n/." "$PKGDIR/$n/" 2>/dev/null || true
      echo "sxpkg: installed $n -> $PKGDIR/$n"
    else
      echo "sxpkg: missing $n in registry"
    fi
  done < "$LOCK"
  echo "sxpkg: install done"
  # A transfer is accepted only if the locked packages now verify (version and
  # sum). The transport is not trusted; the checksum is the acceptance test.
  # A failed check removes the packages fetched in this run, so a rejected
  # download never stays behind in the registry or the project.
  if ! checked verify; then
    for f in $fetched; do
      rm -rf "$REG/$f" "$PKGDIR/$f"
    done
    [ -n "$fetched" ] && echo "sxpkg: rejected and removed downloaded:$fetched"
    return 1
  fi
}

search() {
  [ -f "$INDEX" ] || sync
  run_sayanox search "$@"
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
  run_sayanox remove "$@"
}

info() {
  run_sayanox info "$@"
}

seed() {
  run_sayanox seed
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
  deps) deps "$@" ;;
  install-local) install_local "$@" ;;
  install) install ;;
  search) search "$@" ;;
  publish) publish ;;
  remove) remove "$@" ;;
  info) info "$@" ;;
  seed) seed ;;
  verify) checked verify ;;
  sum) run_sayanox sum "$@" ;;
  fetch) fetch "$@" ;;
  help|-h|--help)
     echo "sxpkg: init|sync|add|list|deps|install|install-local|search|publish|remove|info|seed|verify|sum|fetch"
     echo "  ONLINE registry: $ONLINE"
     echo "  override: SAYANOX_REGISTRY=https://..."
     ;;
  *) echo "sxpkg: unknown command '$cmd'"
     echo "sxpkg: init|sync|add|list|deps|install|install-local|search|publish|remove|info|seed|verify|sum|fetch"
     exit 2
     ;;
esac

