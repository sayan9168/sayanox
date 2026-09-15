#!/usr/bin/env bash
# Minimal Sayanox REPL — each line compiled via Stage-2 sx
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x selfhost/sx selfhost/restore_stage2.sh 2>/dev/null || true
if [[ ! -x selfhost/stage2 ]]; then
  ./selfhost/restore_stage2.sh
fi

TMPDIR="${TMPDIR:-/tmp}"
FILE="$TMPDIR/sayanox_repl_$$.sa"

echo "Sayanox REPL (empty line or :q to quit)"
echo "Tip: one statement per line, e.g.  show 42"

while true; do
  printf 'sa> '
  if ! IFS= read -r line; then
    break
  fi
  [[ -z "$line" || "$line" == ":q" || "$line" == "quit" ]] && break
  printf '%s\n' "$line" > "$FILE"
  if ./selfhost/sx "$FILE" -o "$TMPDIR/sayanox_repl_out" --run 2>/tmp/sayanox_repl_err; then
    true
  else
    cat /tmp/sayanox_repl_err >&2 || true
  fi
done

rm -f "$FILE" "$TMPDIR/sayanox_repl_out" "$TMPDIR/sayanox_repl_out.c" 2>/dev/null || true
echo "bye"
