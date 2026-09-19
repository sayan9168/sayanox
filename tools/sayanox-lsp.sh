#!/bin/sh
# Sayanox LSP v0.3 — JSON-RPC stdio
read_msg() {
  cl=""
  while IFS= read -r line; do
    line=$(printf '%s' "$line" | tr -d '\r')
    case "$line" in Content-Length:*) cl=${line#Content-Length: }; cl=$(echo "$cl" | tr -d ' ') ;; "") break ;; esac
  done
  [ -n "$cl" ] || return 1
  dd bs=1 count="$cl" 2>/dev/null
}
send_msg() { body=$1; len=$(printf '%s' "$body" | wc -c); printf 'Content-Length: %s\r\n\r\n%s' "$len" "$body"; }
KEYWORDS='hold show when otherwise else while break continue make give use push len ord chr gc gc_info run write_file read_file arg_count arg assert not and or struct'
while true; do
  msg=$(read_msg) || break
  method=$(printf '%s' "$msg" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  id=$(printf '%s' "$msg" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
  case "$method" in
    initialize)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"capabilities":{"textDocumentSync":1,"completionProvider":{"triggerCharacters":[".","("]},"hoverProvider":true},"serverInfo":{"name":"sayanox-lsp","version":"0.3"}}}' ;;
    textDocument/completion)
      items=""; for k in $KEYWORDS; do items="$items{\"label\":\"$k\",\"kind\":14}," ; done
      items=$(printf '%s' "$items" | sed 's/,$//')
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"isIncomplete":false,"items":['"$items"']}}' ;;
    textDocument/hover)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"contents":{"kind":"markdown","value":"**Sayanox** — break/continue, not, assert, chr, gc_info, make/give"}}}' ;;
    shutdown) send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":null}' ;;
    exit) break ;;
  esac
done
