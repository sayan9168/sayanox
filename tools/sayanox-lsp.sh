#!/bin/sh
# Sayanox LSP v1.0 — JSON-RPC stdio (no Node/Python)
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
DOC="${TMPDIR:-/tmp}/sx-lsp-$$.txt"
trap 'rm -f "$DOC"' EXIT
extract_uri() { printf '%s' "$1" | sed -n 's/.*"uri"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1; }
extract_text() { printf '%s' "$1" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1; }
KEYWORDS='hold show when otherwise else elif while break continue make give use push len ord chr gc gc_info run write_file read_file arg_count arg assert not and or struct concat str is_str is_num'
CAPS='{"textDocumentSync":1,"completionProvider":{"triggerCharacters":[".","("]},"hoverProvider":true,"definitionProvider":true,"documentSymbolProvider":true,"diagnosticProvider":{"interFileDependencies":false,"workspaceDiagnostics":false}}'
while true; do
  msg=$(read_msg) || break
  method=$(printf '%s' "$msg" | sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  id=$(printf '%s' "$msg" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
  uri=$(extract_uri "$msg")
  case "$method" in
    initialize)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":{"capabilities":'"$CAPS"',"serverInfo":{"name":"sayanox-lsp","version":"1.0"}}}' ;;
    textDocument/didOpen|textDocument/didChange)
      text=$(extract_text "$msg")
      printf '%s' "$text" | sed 's/\\n/\n/g;s/\\"/"/g' > "$DOC"
      diags=""; ln=0
      while IFS= read -r line || [ -n "$line" ]; do
        ln=$((ln+1)); L=$((ln-1))
        case "$line" in *'`'*|*'@'*|*'$'*) diags="$diags{\"range\":{\"start\":{\"line\":$L,\"character\":0},\"end\":{\"line\":$L,\"character\":80}},\"severity\":2,\"code\":\"SX1001\",\"source\":\"sayanox\",\"message\":\"bad token\"}," ;; esac
      done < "$DOC"
      diags=$(printf '%s' "$diags" | sed 's/,$//')
      [ -n "$uri" ] && send_msg '{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"'"$uri"'","diagnostics":['"$diags"']}}'
      ;;
    textDocument/didClose)
      [ -n "$uri" ] && send_msg '{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"'"$uri"'","diagnostics":[]}}' ;;
    textDocument/completion)
      items=""; for k in $KEYWORDS; do items="$items{\"label\":\"$k\",\"kind\":14,\"detail\":\"keyword\"},"; done
      items=$(printf '%s' "$items" | sed 's/,$//')
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":{"isIncomplete":false,"items":['"$items"']}}' ;;
    textDocument/hover)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":{"contents":{"kind":"markdown","value":"**Sayanox** `hold` `show` `when`/`elif` `while` `make`/`give` `struct` — builtins `len` `concat` `chr` `gc`"}}}' ;;
    textDocument/definition)
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":null}' ;;
    textDocument/documentSymbol)
      syms=""; ln=0
      if [ -f "$DOC" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
          ln=$((ln+1)); L=$((ln-1)); name=""
          case "$line" in
            *make[[:space:]]*) name=$(printf '%s' "$line" | sed -n 's/.*make[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/p'); k=12 ;;
            *hold[[:space:]]*) name=$(printf '%s' "$line" | sed -n 's/.*hold[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/p'); k=13 ;;
            *struct[[:space:]]*) name=$(printf '%s' "$line" | sed -n 's/.*struct[[:space:]]*\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/p'); k=5 ;;
          esac
          [ -n "$name" ] && syms="$syms{\"name\":\"$name\",\"kind\":$k,\"location\":{\"uri\":\"$uri\",\"range\":{\"start\":{\"line\":$L,\"character\":0},\"end\":{\"line\":$L,\"character\":80}}}},"
        done < "$DOC"
      fi
      syms=$(printf '%s' "$syms" | sed 's/,$//')
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":['"$syms"']}' ;;
    textDocument/diagnostic)
      diags=""; ln=0
      if [ -f "$DOC" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
          ln=$((ln+1)); L=$((ln-1))
          case "$line" in *'`'*|*'@'*|*'$'*) diags="$diags{\"range\":{\"start\":{\"line\":$L,\"character\":0},\"end\":{\"line\":$L,\"character\":80}},\"severity\":2,\"code\":\"SX1001\",\"source\":\"sayanox\",\"message\":\"bad token\"}," ;; esac
        done < "$DOC"
      fi
      diags=$(printf '%s' "$diags" | sed 's/,$//')
      send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":{"kind":"full","items":['"$diags"']}}' ;;
    shutdown) send_msg '{"jsonrpc":"2.0","id":'"${id:-0}"','"result":null}' ;;
    exit) break ;;
  esac
done
