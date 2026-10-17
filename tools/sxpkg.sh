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

# ---------------------------------------------------------------------------
# The network is OPT-IN. The bootstrap is offline by requirement, so a checkout
# must never reach the network by accident: `sync`, `install` (when it has to
# fetch) and `fetch` refuse unless the caller says so explicitly, either with
#
#   SAYANOX_ONLINE=1 sh tools/sxpkg.sh sync
#   sh tools/sxpkg.sh --online sync
#
# SAYANOX_REGISTRY still decides WHERE a transfer goes; it no longer counts as
# permission to transfer. A file:// URL or a plain local path is not the
# network and needs no opt-in -- that is how test-sxpkg-online-local exercises
# the whole transfer, verify and rollback path without a socket.
# ---------------------------------------------------------------------------
ONLINE_OPT_IN="${SAYANOX_ONLINE:-0}"
if [ "$cmd" = "--online" ]; then
  ONLINE_OPT_IN=1
  cmd="${1:-help}"; shift 2>/dev/null || true
fi

need_online() {
  no_target="${1:-$ONLINE}"
  case "$no_target" in
    file://*|/*|./*) return 0 ;;
    http://*|https://*) ;;
    *://*) echo 'sxpkg: unsupported transfer scheme (use http, https, file or a path)' >&2; return 1 ;;
    *) return 0 ;;
  esac
  if [ "$ONLINE_OPT_IN" = 1 ]; then return 0; fi
  echo "sxpkg: refusing to use the network without an explicit opt-in" >&2
  echo "sxpkg:   target: $no_target" >&2
  echo "sxpkg: opt in with SAYANOX_ONLINE=1, or 'sxpkg --online <command>'." >&2
  echo "sxpkg: offline instead: install-local, seed, verify, list, deps, info," >&2
  echo "sxpkg:   or point SAYANOX_REGISTRY at a local directory (file://...)." >&2
  return 1
}

download() {
  url="$1"; dest="$2"; part="$dest.part"
  # Download to a .part file and rename only on success, so an interrupted
  # transfer never leaves a truncated package where a good one should be.
  # Bounded: a host that accepts the connection and then goes quiet must not
  # hang a build or a gate. Failures are already non-fatal at every call site.
  case "$url" in
    file://*) cp "${url#file://}" "$part" || { rm -f "$part"; return 1; }; mv "$part" "$dest"; return $? ;;
    /*|./*) cp "$url" "$part" || { rm -f "$part"; return 1; }; mv "$part" "$dest"; return $? ;;
    http://*|https://*) ;;
    *://*) echo 'sxpkg: unsupported transfer scheme' >&2; return 1 ;;
    *) cp "./$url" "$part" || { rm -f "$part"; return 1; }; mv "$part" "$dest"; return $? ;;
  esac
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$part" || { rm -f "$part"; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=10 --tries=1 -O "$part" "$url" || { rm -f "$part"; return 1; }
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
  need_online || return 1
  mkdir -p "$REG"
  echo "sxpkg: sync from $ONLINE"
  tmp=$(mktemp)
  if download "$ONLINE/INDEX" "$tmp"; then
    if ! preflight_names "$tmp"; then
      rm -f "$tmp"
      echo 'sxpkg: rejected index with unsafe package name' >&2
      return 1
    fi
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
  checked check-name "${1:-}" >/dev/null || return 1
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
  if checked_out=$(cd "$ROOT" && "$SXPKG_BIN" "$@" 2>&1); then
    :
  else
    printf '%s\n' "$checked_out"
    echo "sxpkg: could not run $1 in project $ROOT" >&2
    return 1
  fi
  [ -n "$checked_out" ] && printf '%s\n' "$checked_out"
  case "$checked_out" in
    *FAILED*|*"sxpkg: DEP "*) return 1 ;;
  esac
  return 0
}

# Validation is .sa logic; shell only prevents untrusted path construction.
preflight_names() {
  while IFS='=' read -r pn pv || [ -n "$pn" ]; do
    case "$pn" in \#*|""|name|version) continue ;; esac
    checked check-name "$pn" >/dev/null || {
      echo "sxpkg: refusing unsafe package name '$pn'" >&2; return 1;
    }
  done < "$1"
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
  preflight_names "$LOCK" || return 1
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
  # The lock plus complete cached packages are sufficient; a missing INDEX is
  # not a reason to transfer. Preflight names before constructing any paths.
  preflight_names "$LOCK" || return 1
  fetched=""
  while IFS='=' read -r n v; do
    case "$n" in \#*|"") continue ;; version|name) continue ;; esac
    case "$n" in
      */*|*..*) echo "sxpkg: refusing unsafe package name '$n'"; continue ;;
    esac
    # Fetch only what is absent. A package counts as present only when both
    # files exist: an empty directory left by a failed download is not a copy.
    if [ ! -f "$REG/$n/pkg.meta" ] || [ ! -f "$REG/$n/main.sa" ]; then
      # Everything locked is already local? Then `install` is an offline copy
      # and needs no permission. A transfer does.
      need_online || return 1
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
  [ -f "$INDEX" ] || {
    echo "sxpkg: no local index; run seed (offline) or sync (explicit network)" >&2
    return 1
  }
  run_sayanox search "$@"
}

publish() {
  name=$(grep '^name' "$MANIFEST" 2>/dev/null | cut -d= -f2- | tr -d '" ' || echo local)
  ver=$(grep '^version' "$MANIFEST" 2>/dev/null | cut -d= -f2- | tr -d '" ' || echo 0.1.0)
  mkdir -p "$REG/$name"
  printf 'name=%s\nversion=%s\n' "$name" "$ver" > "$REG/$name/pkg.meta"
  [ -f main.sa ] && cp main.sa "$REG/$name/main.sa"
  # Record the content sum exactly like the Sayanox implementation writes it,
  # so `verify` can check a shell-published package the same way. pkgsum is a
  # change detector, not a cryptographic hash (see docs/SXPKG_ONLINE.md).
  if [ -f "$REG/$name/main.sa" ]; then
    s=$(run_sayanox sum "$REG/$name/main.sa" 2>/dev/null | cut -d' ' -f3)
    [ -n "$s" ] && printf 'sum=%s\n' "$s" >> "$REG/$name/pkg.meta"
  fi
  grep -q "^$name=" "$INDEX" 2>/dev/null || echo "$name=$ver" >> "$INDEX"
  echo "sxpkg: published locally $name $ver"
  echo "sxpkg: to go online, commit registry/$name to the sayanox repo"
  # `publish` never uploads, with or without an opt-in: going online is a commit
  # to the repository registry, which is a review step, not a client command.
  # SAYANOX_ONLINE=1 changes nothing here on purpose.
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

fetch() (
  url="${1:-}"; name="${2:-remote_pkg}"
  [ -n "$url" ] || { echo "usage: sxpkg fetch <url> [name]"; exit 1; }
  checked check-name "$name" >/dev/null || { echo 'sxpkg: invalid fetch name' >&2; exit 1; }
  # Never silently replace a cache, project copy, or a differently pinned lock.
  if [ -e "$REG/$name" ] || [ -e "$PKGDIR/$name" ] || grep -q "^$name=" "$LOCK" 2>/dev/null; then
    echo "sxpkg: fetch refuses existing package/lock '$name'" >&2; exit 1
  fi
  need_online "$url" || exit 1
  mkdir -p "$REG" "$PKGDIR"
  stage=$(mktemp -d "$REG/.fetch.XXXXXX")
  stage=$(CDPATH= cd "$stage" && pwd)
  committed=0; reg_owned=0; pkg_owned=0
  trap 'if [ "$committed" != 1 ]; then
    [ "$reg_owned" = 0 ] || rm -rf "$REG/$name"
    [ "$pkg_owned" = 0 ] || rm -rf "$PKGDIR/$name"
  fi; rm -rf "$stage"' 0
  trap 'exit 1' 1 2 3 15
  mkdir "$stage/registry" "$stage/package"
  download "$url" "$stage/registry/main.sa" || exit 1
  s=$(run_sayanox sum "$stage/registry/main.sa" | cut -d' ' -f3)
  case "$s" in ''|*[!0-9]*) echo 'sxpkg: failed to compute fetched checksum' >&2; exit 1 ;; esac
  printf 'name=%s\nversion=0.0.0\nsum=%s\n' "$name" "$s" > "$stage/registry/pkg.meta"
  cp -r "$stage/registry/." "$stage/package/"
  if [ -f "$LOCK" ]; then cat "$LOCK" > "$stage/lock"; else : > "$stage/lock"; fi
  # An extra newline also handles a pre-existing lock without a final newline.
  printf '\n%s=0.0.0\n' "$name" >> "$stage/lock"
  reg_owned=1; mv "$stage/registry" "$REG/$name"
  pkg_owned=1; mv "$stage/package" "$PKGDIR/$name"
  mv "$stage/lock" "$LOCK"
  committed=1
  echo "sxpkg: fetched $name from $url (checksum recorded; not authenticated)"
)

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
     echo "  override: SAYANOX_REGISTRY=https://... (or file:///path/to/registry)"
     echo "  network is opt-in: SAYANOX_ONLINE=1 or 'sxpkg --online <command>'"
     echo "  offline commands: init add list deps info search seed verify sum install-local publish"
     ;;
  *) echo "sxpkg: unknown command '$cmd'"
     echo "sxpkg: init|sync|add|list|deps|install|install-local|search|publish|remove|info|seed|verify|sum|fetch"
     exit 2
     ;;
esac

