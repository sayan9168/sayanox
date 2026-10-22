#!/bin/sh
# Deterministic offline + opt-in transfers. Stubs never open a socket.
# The wrapper is gone; tools/sxpkg is the Sayanox binary and finds curl/wget
# itself by scanning PATH, so the mocked transports below are still the only
# ones reachable.
set -eu
repo=$(pwd)
w=$repo/tools/sxpkg
base=$repo/selfhost/seed_tests/sxpkg-hardening
rm -rf "$base"
mkdir -p "$base/project" "$base/mock" "$base/wget-only"
p=$base/project
export MOCK_SOURCE=$base/source.sa MOCK_CALLS=$base/calls
printf 'show 123\n' > "$MOCK_SOURCE"
: > "$MOCK_CALLS"
cat > "$base/mock/curl" <<'EOF'
#!/bin/sh
set -eu
printf 'curl\n' >> "$MOCK_CALLS"
last=
for arg do
  if [ "$last" = -o ]; then dest=$arg; fi
  last=$arg
done
if [ "${MOCK_FAIL:-0}" = 1 ]; then printf 'partial' > "$dest"; exit 1; fi
cp "$MOCK_SOURCE" "$dest"
EOF
cat > "$base/wget-only/wget" <<'EOF'
#!/bin/sh
set -eu
printf 'wget\n' >> "$MOCK_CALLS"
last=
for arg do
  if [ "$last" = -O ]; then dest=$arg; fi
  last=$arg
done
cp "$MOCK_SOURCE" "$dest"
EOF
chmod +x "$base/mock/curl" "$base/wget-only/wget"
# Wget branch without relying on host-installed curl/wget. Only shell tools
# used by the wrapper are exposed; no real transport executable is reachable.
for tool in sh cp mv rm mkdir mktemp grep cat cut; do
    ln -s "$(command -v "$tool")" "$base/wget-only/$tool"
done
export SAYANOX_ROOT=$p
"$w" init > "$base/init.out"
cp "$p/sx.lock" "$base/original.lock"
if PATH="$base/mock:$PATH" "$w" fetch https://registry.invalid/a denied > "$base/denied.out" 2>&1; then
    echo '[FAIL] transfer without opt-in'; exit 1
fi
test ! -s "$MOCK_CALLS"
# Reject unsafe names before either creating paths or calling a transport.
for name in '../escape' 'a/b' 'bad name' 'a.b' 'name' 'version'; do
    if PATH="$base/mock:$PATH" "$w" --online fetch https://registry.invalid/a "$name" > "$base/name.out" 2>&1; then
        echo '[FAIL] unsafe name accepted'; exit 1
    fi
done
test ! -s "$MOCK_CALLS"
cmp "$p/sx.lock" "$base/original.lock"
# A failed mocked transfer writes partial bytes: no package or lock survives.
if PATH="$base/mock:$PATH" MOCK_FAIL=1 "$w" --online fetch https://registry.invalid/a broken > "$base/broken.out" 2>&1; then
    echo '[FAIL] interrupted transfer accepted'; exit 1
fi
test ! -e "$p/.sayanox/registry/broken"
test ! -e "$p/.sayanox/pkgs/broken"
cmp "$p/sx.lock" "$base/original.lock"
PATH="$base/mock:$PATH" "$w" --online fetch https://registry.invalid/a remote > "$base/remote.out"
"$w" verify > "$base/verify.out"
grep -q 'verify ok' "$base/verify.out"
grep -q '^sum=[0-9]' "$p/.sayanox/registry/remote/pkg.meta"
cmp "$MOCK_SOURCE" "$p/.sayanox/pkgs/remote/main.sa"
# Existing packages/pins must not be overwritten by fetch.
cp "$MOCK_CALLS" "$base/before.calls"
cp "$p/sx.lock" "$base/before.lock"
if PATH="$base/mock:$PATH" "$w" --online fetch https://registry.invalid/a remote > "$base/existing.out" 2>&1; then
    echo '[FAIL] fetch overwrote existing package'; exit 1
fi
cmp "$MOCK_CALLS" "$base/before.calls"
cmp "$p/sx.lock" "$base/before.lock"
# Wget-only successful opt-in, also with checksum and copied bytes.
PATH="$base/wget-only" SAYANOX_ONLINE=1 "$w" fetch https://registry.invalid/a wgetpkg > "$base/wget.out"
grep -q '^wget$' "$MOCK_CALLS"
"$w" verify > "$base/wget-verify.out"
grep -q 'verify ok' "$base/wget-verify.out"
# Rooted and bare-relative local paths need neither permission nor transport.
cp "$MOCK_SOURCE" "$base/local.sa"
(cd "$base" && PATH="$base/mock:$PATH" "$w" fetch local.sa localpkg) > "$base/local.out"
# Reject unsafe downloaded index entries before replacing a good local INDEX.
cp "$p/.sayanox/registry/INDEX" "$base/index-before"
printf '../escape=0.1.0\n' > "$base/bad-index"
if PATH="$base/mock:$PATH" MOCK_SOURCE="$base/bad-index" SAYANOX_REGISTRY=https://registry.invalid/r "$w" --online sync > "$base/index-bad.out" 2>&1; then
    echo '[FAIL] unsafe index accepted'; exit 1
fi
cmp "$p/.sayanox/registry/INDEX" "$base/index-before"
test ! -e "$p/.sayanox/escape"
# A hand-edited unsafe lock must fail both offline and transfer installs.
cp "$p/sx.lock" "$base/safe.lock"
printf '../escape=0.1.0\n' >> "$p/sx.lock"
cp "$MOCK_CALLS" "$base/before.calls"
for cmd in install install-local; do
    if PATH="$base/mock:$PATH" SAYANOX_REGISTRY=https://registry.invalid/r "$w" "$cmd" > "$base/unsafe-$cmd.out" 2>&1; then
        echo '[FAIL] unsafe lock accepted'; exit 1
    fi
done
cmp "$MOCK_CALLS" "$base/before.calls"
cp "$base/safe.lock" "$p/sx.lock"
# Offline cached install must not demand INDEX or attempt a transfer.
rm -f "$p/.sayanox/registry/INDEX"
cp "$MOCK_CALLS" "$base/before.calls"
PATH="$base/mock:$PATH" SAYANOX_REGISTRY=https://registry.invalid/r "$w" install > "$base/offline.out"
grep -q 'verify ok' "$base/offline.out"
cmp "$MOCK_CALLS" "$base/before.calls"
# Tampered cache is rejected offline, not accepted because no fetch occurred.
printf 'tamper\n' >> "$p/.sayanox/registry/remote/main.sa"
if "$w" verify > "$base/tamper.out" 2>&1; then
    echo '[FAIL] checksum mismatch accepted'; exit 1
fi
grep -q 'MISMATCH' "$base/tamper.out"
# No fetch staging tree or partial file may remain after success/failure.
if [ -n "$(find "$p" -name '*.part' -o -name '.fetch.*')" ]; then
    echo '[FAIL] transfer staging left behind'; exit 1
fi
echo '[OK] sxpkg hardening: no-opt-in/name refusal before transport; interrupted fetch rollback; curl/wget mocked success; checksum verification/tamper; overwrite refusal; rooted relative local fetch; cached install without INDEX; no DNS'
