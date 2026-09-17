#!/bin/sh
# Sayanox LSP — initialize, completion, hover, definition stub, diagnostics stub
set -e
KEYWORDS="hold show when otherwise while make give struct use true false concat len push read_file write_file str upper lower trim run arg arg_count"
read_msg() {
  cl=0
  while IFS= read -r line; do
    line=$(printf '%s' "$line" | tr -d '\r')
    [ -z "$line" ] && break
    case "$line" in
      [Cc]ontent-[Ll]ength:*) cl=$(printf '%s' "$line" | sed 's/.*: *//') ;;
    esac
  done
  [ "$cl" -gt 0 ] 2>/dev/null && head -c "$cl" || true
}
send() {
  body=$1
  n=$(printf '%s' "$body" | wc -c)
  printf 'Content-Length: %s\r\n\r\n%s' "$n" "$body"
}
items='['
f=1
for w in $KEYWORDS; do
  [ "$f" = 1 ] || items="$items,"
  f=0
  items="$items{\"label\":\"$w\",\"kind\":14}"
done
items="$items]"
while true; do
  msg=$(read_msg) || exit 0
  [ -z "$msg" ] && continue
  id=$(printf '%s' "$msg" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  method=$(printf '%s' "$msg" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  case "$method" in
    initialize)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"capabilities\":{\"textDocumentSync\":1,\"completionProvider\":{\"triggerCharacters\":[\".\"]},\"hoverProvider\":true,\"definitionProvider\":true,\"diagnosticProvider\":true},\"serverInfo\":{\"name\":\"sayanox-lsp\",\"version\":\"0.2.0\"}}}"
      ;;
    textDocument/completion)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"isIncomplete\":false,\"items\":$items}}"
      ;;
    textDocument/hover)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"contents\":{\"kind\":\"markdown\",\"value\":\"**Sayanox** hold show when while make struct use run arg\"}}}"
      ;;
    textDocument/definition)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":null}"
      ;;
    textDocument/diagnostic|textDocument/publishDiagnostics)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"kind\":\"full\",\"items\":[]}}"
      ;;
    shutdown) send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":null}" ;;
    exit) exit 0 ;;
  esac
done
