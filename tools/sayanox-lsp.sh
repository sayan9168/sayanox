#!/bin/sh
# Sayanox LSP v1.0 — JSON-RPC over stdio (no Node/Python)
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

DOC_DIR="${TMPDIR:-/tmp}/sayanox-lsp-$$"
mkdir -p "$DOC_DIR"
trap 'rm -rf "$DOC_DIR"' EXIT

uri_to_key() {
  printf '%s' "$1" | sed 's|file://||;s|/|_|g;s|%20|_|g'
}

store_doc() {
  uri="$1"; text="$2"
  key=$(uri_to_key "$uri")
  printf '%s' "$text" | sed 's/\\n/\n/g;s/\\t/\t/g;s/\\"/"/g' > "$DOC_DIR/$key"
}

get_doc() {
  uri="$1"
  key=$(uri_to_key "$uri")
  [ -f "$DOC_DIR/$key" ] && cat "$DOC_DIR/$key"
}

extract_text() {
  printf '%s' "$1" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1
}

extract_uri() {
  printf '%s' "$1" | sed -n 's/.*"uri"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

KEYWORDS='hold show when otherwise else elif while break continue make give use push len ord chr gc gc_info run write_file read_file arg_count arg assert not and or struct concat str is_str is_num'

diag_for_doc() {
  uri="$1"
  text=$(get_doc "$uri")
  [ -n "$text" ] || { printf '[]'; return; }
  line_no=0
  printf '%s\n' "$text" | while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    case "$line" in
      *'`'*|*'@'*|*'$'*)
        printf '{"range":{"start":{"line":%d,"character":0},"end":{"line":%d,"character":80}},"severity":2,"code":"SX1001","source":"sayanox","message":"bad token (` @ $ not valid in Sayanox)"},' "$((line_no-1))" "$((line_no-1))"
        ;;
    esac
    case "$line" in
      *hold*)
        case "$line" in
          *=*) ;;
          *)
            case "$line" in
              *hold[[:space:]]*[a-z]*)
                printf '{"range":{"start":{"line":%d,"character":0},"end":{"line":%d,"character":80}},"severity":2,"code":"SX1003","source":"sayanox","message":"hold without ="},' "$((line_no-1))" "$((line_no-1))"
                ;;
            esac
            ;;
        esac
        ;;
    esac
    case "$line" in
      *show[[:space:]]*$|*show)
        printf '{"range":{"start":{"line":%d,"character":0},"end":{"line":%d,"character":80}},"severity":2,"code":"SX1004","source":"sayanox","message":"show with empty expression"},' "$((line_no-1))" "$((line_no-1))"
        ;;
    esac
  done | sed 's/,$//'
}

publish_diags() {
  uri="$1"
  items=$(diag_for_doc "$uri")
  send_msg '{"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"'