#!/bin/sh
# test-sayacrawl: sayascrape/crawl.sa, the Sayanox crawler (gen2 full language).
#
# Serves a small site from 127.0.0.1 only (no internet). Checks the exact output for:
#   * an authorized crawl (links, relative and absolute hrefs, external links
#     ignored, robots.txt Disallow respected, depth cap 2),
#   * the page cap (MAX_PAGES=2) and the depth cap (MAX_DEPTH=0),
#   * refusals: no --authorized, START_URL off ALLOWED_HOST, robots.txt missing.
#
# usage: tools/test-sayacrawl.sh GEN2 CRAWL_SA
set -eu
GEN2=${1:-selfhost/gen2}
SRC=${2:-sayascrape/crawl.sa}

D=$(mktemp -d)
SRV1=
SRV2=
trap 'for p in $SRV1 $SRV2; do kill "$p" 2>/dev/null || true; done; rm -rf "$D"' EXIT

free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()'
}
wait_up() {
  i=0
  until curl -s -m 2 -o /dev/null "http://127.0.0.1:$1/"; do
    i=$((i + 1))
    if [ "$i" -gt 50 ]; then echo "FAIL: test server on $1 did not start"; exit 1; fi
    sleep 0.1
  done
}

P=$(free_port)
Q=$(free_port)
mkdir -p "$D/site/private" "$D/bare"

cat > "$D/site/index.html" <<EOF
<html><body>
<a href="a.html">a</a> <a href='/b.html'>b</a>
<a href="http://127.0.0.1:$P/c.html">c</a> <a href="http://other.example/x">x</a>
<a href="#top">top</a> <a href="mailto:x@example.com">mail</a>
<a href="/private/p.html">p</a>
</body></html>
EOF
printf '<a href="/index.html">i</a> <a href="d.html">d</a>\n' > "$D/site/a.html"
printf '<a href="/e.html">e</a>\n' > "$D/site/b.html"
printf 'no links here\n' > "$D/site/c.html"
printf 'leaf page\n' > "$D/site/d.html"
printf '<a href="f.html">f</a>\n' > "$D/site/e.html"
printf 'private\n' > "$D/site/private/p.html"
printf 'User-agent: *\nDisallow: /private/\n# comment line\n' > "$D/site/robots.txt"
printf 'page without robots\n' > "$D/bare/index.html"

(cd "$D/site" && exec python3 -m http.server "$P" --bind 127.0.0.1 >/dev/null 2>&1) &
SRV1=$!
(cd "$D/bare" && exec python3 -m http.server "$Q" --bind 127.0.0.1 >/dev/null 2>&1) &
SRV2=$!
wait_up "$P"
wait_up "$Q"

"$GEN2" "$SRC" "$D/crawl.c"
cc -O2 -o "$D/crawl" "$D/crawl.c" -lm

# 1. authorized crawl with the default caps (20 pages, depth 2)
cat > "$D/want_full.txt" <<EOF
ROBOTS: http://127.0.0.1:$P/robots.txt
FETCH depth=0 links=5 http://127.0.0.1:$P/index.html
FETCH depth=1 links=2 http://127.0.0.1:$P/a.html
FETCH depth=1 links=1 http://127.0.0.1:$P/b.html
FETCH depth=1 links=0 http://127.0.0.1:$P/c.html
SKIP robots: http://127.0.0.1:$P/private/p.html
FETCH depth=2 links=0 http://127.0.0.1:$P/d.html
FETCH depth=2 links=1 http://127.0.0.1:$P/e.html
DONE pages=6
EOF
"$D/crawl" --authorized "http://127.0.0.1:$P/index.html" "127.0.0.1:$P" > "$D/full.txt"
cmp -s "$D/full.txt" "$D/want_full.txt" || { echo "FAIL: full crawl output differs"; diff "$D/want_full.txt" "$D/full.txt" || true; exit 1; }

# 2. page cap: MAX_PAGES=2 stops after index and a
cat > "$D/want_cap.txt" <<EOF
ROBOTS: http://127.0.0.1:$P/robots.txt
FETCH depth=0 links=5 http://127.0.0.1:$P/index.html
FETCH depth=1 links=2 http://127.0.0.1:$P/a.html
DONE pages=2
EOF
"$D/crawl" --authorized "http://127.0.0.1:$P/index.html" "127.0.0.1:$P" 2 > "$D/cap.txt"
cmp -s "$D/cap.txt" "$D/want_cap.txt" || { echo "FAIL: page cap output differs"; diff "$D/want_cap.txt" "$D/cap.txt" || true; exit 1; }

# 3. depth cap: MAX_DEPTH=0 fetches only the start page
cat > "$D/want_depth.txt" <<EOF
ROBOTS: http://127.0.0.1:$P/robots.txt
FETCH depth=0 links=5 http://127.0.0.1:$P/index.html
DONE pages=1
EOF
"$D/crawl" --authorized "http://127.0.0.1:$P/index.html" "127.0.0.1:$P" 20 0 > "$D/depth.txt"
cmp -s "$D/depth.txt" "$D/want_depth.txt" || { echo "FAIL: depth cap output differs"; diff "$D/want_depth.txt" "$D/depth.txt" || true; exit 1; }

# 4. refusal: no --authorized -> no request, only the refusal lines
"$D/crawl" "http://127.0.0.1:$P/index.html" "127.0.0.1:$P" > "$D/noauth.txt"
if grep -q 'FETCH\|ROBOTS' "$D/noauth.txt"; then echo "FAIL: crawl ran without --authorized"; exit 1; fi
grep -q '^REFUSED: usage: crawl --authorized' "$D/noauth.txt" || { echo "FAIL: usage refusal missing"; exit 1; }

# 5. refusal: START_URL off ALLOWED_HOST
"$D/crawl" --authorized "http://127.0.0.1:$P/index.html" "other.example" > "$D/offhost.txt"
grep -q '^REFUSED: START_URL is not on ALLOWED_HOST' "$D/offhost.txt" || { echo "FAIL: off-host refusal missing"; cat "$D/offhost.txt"; exit 1; }
if grep -q 'FETCH' "$D/offhost.txt"; then echo "FAIL: off-host start was fetched"; exit 1; fi

# 6. refusal: no robots.txt on the site (fail closed, no crawl)
"$D/crawl" --authorized "http://127.0.0.1:$Q/index.html" "127.0.0.1:$Q" > "$D/norobots.txt"
cat > "$D/want_norobots.txt" <<EOF
REFUSED: robots.txt missing, empty or unreachable at http://127.0.0.1:$Q/robots.txt
EOF
cmp -s "$D/norobots.txt" "$D/want_norobots.txt" || { echo "FAIL: missing-robots refusal differs"; cat "$D/norobots.txt"; exit 1; }

echo "[OK] sayacrawl: authorized crawl (robots Disallow, allowlist, relative+absolute links), page cap, depth cap, and refusals (no --authorized, off-host, no robots.txt)"
