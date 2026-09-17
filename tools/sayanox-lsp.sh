#!/usr/bin/env bash
# Minimal Sayanox LSP (stdio, JSON-RPC) — no third-party runtime
# Capabilities: initialize, completion, hover
set -euo pipefail

KEYWORDS='hold show when otherwise while make give struct use give true false'
STDLIB='concat len push read_file write_file str upper lower trim'

read_message() {
  local content_length=0 line
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && break
    if [[ "$line" =~ [Cc]ontent-[Ll]ength:[[:space:]]*([0-9]+) ]]; then
      content_length="${BASH_REMATCH[1]}"
    fi
  done
  if [[ "$content_length" -gt 0 ]]; then
    head -c "$content_length"
  fi
}

send_message() {
  local body="$1"
  local len
  len=$(printf '%s' "$body" | wc -c)
  printf 'Content-Length: %s\r\n\r\n%s' "$len" "$body"
}

completion_items() {
  local items="[" first=1
  for w in $KEYWORDS $STDLIB; do
    [[ $first -eq 1 ]] || items+=","
    first=0
    items+=$(printf '{"label":"%s","kind":14}' "$w")
  done
  items+="]"
  printf '%s' "$items"
}

while true; do
  msg=$(read_message) || exit 0
  [[ -z "$msg" ]] && continue
  # extract id if present
  id=$(printf '%s' "$msg" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
  method=$(printf '%s' "$msg" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

  case "$method" in
    initialize)
      body=$(printf '{"jsonrpc":"2.0","id":%s,"result":{"capabilities":{"textDocumentSync":1,"completionProvider":{"triggerCharacters":["."]},"hoverProvider":true},"serverInfo":{"name":"sayanox-lsp","version":"0.1.0"}}}' "${id:-1}")
      send_message "$body"
      ;;
    initialized)
      ;;
    textDocument/completion)
      items=$(completion_items)
      body=$(printf '{"jsonrpc":"2.0","id":%s,"result":{"isIncomplete":false,"items":%s}}' "${id:-1}" "$items")
      send_message "$body"
      ;;
    textDocument/hover)
      body=$(printf '{"jsonrpc":"2.0","id":%s,"result":{"contents":{"kind":"markdown","value":"**Sayanox** — hold / show / when / while / make / struct"}}}' "${id:-1}")
      send_message "$body"
      ;;
    shutdown)
      body=$(printf '{"jsonrpc":"2.0","id":%s,"result":null}' "${id:-1}")
      send_message "$body"
      ;;
    exit)
      exit 0
      ;;
    *)
      ;;
  esac
done
