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
  case "$sx_cmd" in
    init|add) sx ensure-dir "$PKGDIR" >/dev/null && sx ensure-dir "$REG" >/dev/null ;;
    seed) : ;;
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
    sx rm-tree "$PKGDIR/$1"
  fi
  return "$sx_status"
}

# sx: run the Sayanox package tool, building it first if it is missing.  Every
# folder and copy operation the wrapper used to do with mkdir/cp/rm now goes
# through it (ensure-dir, rm-tree, copy-tree), so the shell only has to know how
# to reach the network.
sx() {
  [ -x "$SXPKG_BIN" ] || make -C "$SAYANOX_REPO_ROOT" sxpkg >/dev/null
  "$SXPKG_BIN" "$@"
}

init() {
  run_sayanox init
}

sync() {
  need_online || return 1
  # A file:// URL or a plain path is not the network, so the whole refresh is
  # Sayanox: it writes the INDEX only after every name in it has been checked,
  # and it falls back to the local seed when there is nothing to read.
  case "$ONLINE" in
    file://*|/*|./*)
      (cd "$ROOT" && sx sync-local "$ONLINE")
      return $?
      ;;
  esac
  sx ensure-dir "$REG" >/dev/null
  echo "sxpkg: sync from $ONLINE"
  tmp=$(mktemp)
  if download "$ONLINE/INDEX" "$tmp"; then
    if ! (cd "$ROOT" && sx check-lock "$tmp"); then
      rm -f "$tmp"
      echo 'sxpkg: rejected index with unsafe package name' >&2
      return 1
    fi
    cp "$tmp" "$INDEX"
    echo "sxpkg: index updated"
    while IFS='=' read -r n v; do
      case "$n" in \#*|"") continue ;; esac
      sx ensure-dir "$REG/$n" >/dev/null
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
# The Sayanox binary also sets its own exit status now, but the FAILED and DEP
# report lines stay the contract the wrapper keys on, so a command that only
# reports (verify, deps) still maps to a status here. Output is kept.
checked() {
  if checked_out=$(cd "$ROOT" && sx "$@" 2>&1); then
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

list() {
  run_sayanox list "$@"
}

deps() {
  run_sayanox deps "$@"
}

# install-local: the offline install.  Sayanox owns all of it now: it preflights
# every locked name, creates .sayanox/registry/<name>/ and .sayanox/pkgs/<name>/,
# copies each package (and its `deps=` closure) out of a local registry directory
# (default ./registry) while checking the version and the pkg.meta sum, and
# exits non-zero when the lock cannot be resolved.  No network.
install_local() {
  src="${1:-registry}"
  [ -f "$LOCK" ] || { echo "sxpkg: no sx.lock - run init/add"; exit 1; }
  case "$src" in /*) ;; *) src=$(CDPATH= cd "$ROOT" && pwd)/"$src" ;; esac
  (cd "$ROOT" && sx install-local "$src")
}

install() {
  sx ensure-dir "$PKGDIR" >/dev/null
  [ -f "$LOCK" ] || { echo "sxpkg: no sx.lock — run init/add"; exit 1; }
  # The lock plus complete cached packages are sufficient; a missing INDEX is
  # not a reason to transfer. Preflight names before constructing any paths.
  (cd "$ROOT" && sx check-lock) || return 1
  # Sayanox says which locked packages have no complete registry copy, so the
  # shell only has to fetch those and never walks the lock itself. A package
  # counts as present only when both files exist: an empty directory left by a
  # failed download is not a copy.
  fetched=""
  for n in $(cd "$ROOT" && sx need-fetch); do
    # Everything locked is already local? Then `install` is an offline copy and
    # needs no permission. A transfer does.
    need_online || return 1
    fetched="$fetched $n"
    sx ensure-dir "$REG/$n" >/dev/null
    download "$ONLINE/$n/pkg.meta" "$REG/$n/pkg.meta" || echo "sxpkg: could not fetch $n/pkg.meta from $ONLINE"
    download "$ONLINE/$n/main.sa" "$REG/$n/main.sa" || echo "sxpkg: could not fetch $n/main.sa from $ONLINE"
  done
  # Copy and report whatever is now complete. The pkgdir is made absolute for
  # the same reason install-local absolutises its source: the binary runs with
  # the project root as its working directory.
  pkg=$(CDPATH= cd "$ROOT" && pwd)/.sayanox/pkgs
  (cd "$ROOT" && sx install-cached "$pkg") || return 1
  echo "sxpkg: install done"
  # A transfer is accepted only if the locked packages now verify (version and
  # sum). The transport is not trusted; the checksum is the acceptance test.
  # A failed check removes the packages fetched in this run, so a rejected
  # download never stays behind in the registry or the project.
  if ! checked verify; then
    for f in $fetched; do
      sx rm-tree "$REG/$f"
      sx rm-tree "$PKGDIR/$f"
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

# publish: Sayanox owns it.  name/version come from sx.toml, the content sum is
# recorded in pkg.meta exactly like the registry seed writes it, and the INDEX
# gains `name=version` unless it is already there.  The shell version of this
# needed grep, cut, tr and cp; it is now one delegation.
publish() {
  (cd "$ROOT" && sx publish)
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
  # A file:// URL or a plain path is not the network: Sayanox reads it, records
  # the sum in pkg.meta and sx.lock, and rolls the whole thing back if any write
  # fails.  Resolve the source against the caller's directory first, because
  # fetch-local runs with the project root as its working directory.
  case "$url" in
    file://*|/*|./*)
      case "$url" in
        file://*) fsrc="${url#file://}" ;;
        /*) fsrc="$url" ;;
        ./*) fsrc="$PWD/${url#./}" ;;
        *) fsrc="$PWD/$url" ;;
      esac
      [ -x "$SXPKG_BIN" ] || make -C "$SAYANOX_REPO_ROOT" sxpkg >/dev/null
      cd "$ROOT" && exec "$SXPKG_BIN" fetch-local "$fsrc" "$name" "$url"
      ;;
  esac
  sx ensure-dir "$REG" >/dev/null && sx ensure-dir "$PKGDIR" >/dev/null
  stage=$(mktemp -d "$REG/.fetch.XXXXXX")
  stage=$(CDPATH= cd "$stage" && pwd)
  committed=0; reg_owned=0; pkg_owned=0
  trap 'if [ "$committed" != 1 ]; then
    [ "$reg_owned" = 0 ] || sx rm-tree "$REG/$name"
    [ "$pkg_owned" = 0 ] || sx rm-tree "$PKGDIR/$name"
  fi; sx rm-tree "$stage"' 0
  trap 'exit 1' 1 2 3 15
  sx ensure-dir "$stage/registry" >/dev/null && sx ensure-dir "$stage/package" >/dev/null
  download "$url" "$stage/registry/main.sa" || exit 1
  s=$(run_sayanox sum "$stage/registry/main.sa" | cut -d' ' -f3)
  case "$s" in ''|*[!0-9]*) echo 'sxpkg: failed to compute fetched checksum' >&2; exit 1 ;; esac
  printf 'name=%s\nversion=0.0.0\nsum=%s\n' "$name" "$s" > "$stage/registry/pkg.meta"
  sx copy-tree "$stage/registry" "$stage/package"
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

