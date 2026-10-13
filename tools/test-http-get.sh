#!/bin/sh
# test-http-get: the http_get(url) network builtin.
#
# Uses ONLY a local server on 127.0.0.1 (random free port). No internet access.
# Checks that gen2, the seed-min compiler and the full seed produce the same
# output, and that the native backend refuses http_get with a clear error.
#
# usage: tools/test-http-get.sh GEN2 SEED_MIN SEED NATIVE
set -eu
GEN2=${1:-selfhost/gen2}
SEED_MIN=${2:-selfhost/seed/sxc_seed_min}
SEED=${3:-selfhost/seed/sxc_seed}
NATIVE=${4:-selfhost/native_aot}
SEED_DIR=$(dirname "$SEED")

D=$(mktemp -d)
SRV=
trap 'if [ -n "$SRV" ]; then kill "$SRV" 2>/dev/null || true; fi; rm -rf "$D"' EXIT

mkdir "$D/site"
printf 'hello from local server\n' > "$D/site/hello.txt"
PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
(cd "$D/site" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
SRV=$!

i=0
until curl -s -m 2 -o /dev/null "http://127.0.0.1:$PORT/hello.txt"; do
  i=$((i + 1))
  if [ "$i" -gt 50 ]; then echo "FAIL: local test server did not start"; exit 1; fi
  sleep 0.1
done

cat > "$D/t.sa" <<EOF
hold body = http_get("http://127.0.0.1:$PORT/hello.txt")
show body
show len(http_get("http://127.0.0.1:$PORT/nope.txt"))
show len(http_get("file:///etc/passwd"))
show len(http_get("http://127.0.0.1:$PORT/x y"))
EOF

# Body keeps its own newline, then show adds one; the three rejected cases are 0.
printf 'hello from local server\n\n0\n0\n0\n' > "$D/want.txt"

# gen2 (the self-hosted compiler) -- compiles directly.
"$GEN2" "$D/t.sa" "$D/gen2.c"
cc -O2 -o "$D/gen2" "$D/gen2.c" -lm
"$D/gen2" > "$D/gen2.out"
cmp -s "$D/gen2.out" "$D/want.txt" || { echo "FAIL: gen2 output differs"; diff "$D/want.txt" "$D/gen2.out" || true; exit 1; }

# seed-min -- compiles directly.
"$SEED_MIN" "$D/t.sa" > "$D/min.c"
cc -O2 -o "$D/min" "$D/min.c"
"$D/min" > "$D/min.out"
cmp -s "$D/min.out" "$D/want.txt" || { echo "FAIL: seed-min output differs"; diff "$D/want.txt" "$D/min.out" || true; exit 1; }

# full seed -- its generated C needs the runtime header and <stdarg.h>.
"$SEED" "$D/t.sa" > "$D/seed.c"
# no -include stdarg.h workaround: selfhost/seed/sx_runtime.h includes it,
# because the seed-generated preamble emits a variadic sx_lit_list
cc -O2 -I"$SEED_DIR" -o "$D/seed" "$D/seed.c" -lm
"$D/seed" > "$D/seed.out"
cmp -s "$D/seed.out" "$D/want.txt" || { echo "FAIL: seed output differs"; diff "$D/want.txt" "$D/seed.out" || true; exit 1; }

# native -- must refuse with a clear message (no silent or misleading error).
if "$NATIVE" "$D/t.sa" "$D/native.out" 2> "$D/native.err"; then
  echo "FAIL: native accepted http_get"; exit 1
fi
grep -q 'http_get is not supported by the native backend' "$D/native.err" \
  || { echo "FAIL: native refusal message missing"; cat "$D/native.err"; exit 1; }

echo "[OK] http_get: gen2, seed-min and seed match; native refuses explicitly; local-only, no internet"
