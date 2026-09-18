#!/bin/sh
# Sayanox LSP — dependency-free JSON-RPC over stdio
read_msg() {
  cl=""
  while IFS= read -r line; do
    line=$(printf '%s' "$line" | tr -d '\r')
    case "$line" in
      Content-Length:*) cl=${line#Content-Length: }; cl=$(echo "$cl" | tr -d ' ') ;;
      "") break ;;
    esac
  done
  [ -n "$cl" ] || return 1
  dd bs=1 count="$cl" 2>/dev/null
}
send_msg() {
  body=$1
  len=$(printf '%s' "$body" | wc -c)
  printf 'Content-Length: %s\r\n\r\n%s' "$len" "$body"
}
KEYWORDS='hold show when otherwise while make use push len ord gc run write_file read_file arg_count struct'
diag_for() {
  printf '%s' "$1" | awk '
  {
    line=$0; ln=NR
    if (line ~ /`/ || line ~ /@/ || line ~ /\$/) {
      printf "{\"range\":{\"start\":{\"line\":%d,\"character\":0},\"end\":{\"line\":%d,\"character\":80}},\"severity\":2,\"code\":\"SX1001\",\"source\":\"sayanox\",\"message\":\"bad token\"},", ln-1, ln-1
    }
    if (line ~ /^[ \t]*hold[ \t]+[^=]+$/) {
      printf "{\"range\":{\"start\":{\"line\":%d,\"character\":0},\"end\":{\"line\":%d,\"character\":80}},\"severity\":2,\"code\":\"SX1003\",\"source\":\"sayanox\",\"message\":\"hold without =\"},", ln-1, ln-1
    }
  }'
}
DOC=""
while true; do
  msg=$(read_msg) || break
  method=$(printf '%s' "$msg" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  id=$(printf '%s' "$msg" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
  case "$method" in
    initialize)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"capabilities":{"textDocumentSync":1,"completionProvider":{"triggerCharacters":["."]},"hoverProvider":true,"diagnosticProvider":{"interFileDependencies":false}},"serverInfo":{"name":"sayanox-lsp","version":"0.2"}}}'
      ;;
    initialized) ;;
    textDocument/completion)
      items=""
      for k in $KEYWORDS; do
        items="$items{\"label\":\"$k\",\"kind\":14},"
      done
      items=${items%,}
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"isIncomplete":false,"items":['"$items"']}}'
      ;;
    textDocument/hover)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"contents":{"kind":"markdown","value":"**Sayanox** — hold/show/when/while/make/strings/gc"}}}'
      ;;
    textDocument/didOpen|textDocument/didChange)
      DOC=$(printf '%s' "$msg" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1 | sed 's/\\n/\n/g')
      diags=$(diag_for "$DOC")
      diags=${diags%,}
      send_msg '{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file://sayanox","diagnostics":['"$diags"']}}'
      ;;
    textDocument/didClose)
      send_msg '{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"file://sayanox","diagnostics":[]}}'
      ;;
    textDocument/diagnostic)
      diags=$(diag_for "$DOC")
      diags=${diags%,}
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":{"kind":"full","items":['"$diags"']}}'
      ;;
    shutdown)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"',"result":null}'
      ;;
    exit) exit 0 ;;
    *)
      [ -n "$id" ] && send_msg '{"jsonrpc":"2.0","id":'"$id"',"error":{"code":-32601,"message":"Method not found"}}'
      ;;
  esac
done
