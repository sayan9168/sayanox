#!/bin/sh
# Sayanox LSP — stdio JSON-RPC, completion, hover, and source diagnostics.
# POSIX sh only. Diagnostics are intentionally lightweight and line-oriented.
set -eu

KEYWORDS="hold show when otherwise while make give struct use true false concat len push read_file write_file str upper lower trim run arg arg_count"
DOC_URI=""
DOC_TEXT=""

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

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
  n=$(printf '%s' "$body" | wc -c | tr -d ' ')
  printf 'Content-Length: %s\r\n\r\n%s' "$n" "$body"
}

send_notification() {
  send "$1"
}

json_string_field() {
  field=$1
  printf '%s' "$2" | sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

unescape_json_text() {
  # LSP source text normally arrives as JSON string data. Handle the common
  # escapes without requiring a non-POSIX JSON parser.
  printf '%s' "$1" | sed 's/\\n/\
/g; s/\\r//g; s/\\t/	/g; s/\\"/"/g; s/\\\\/\\/g'
}

make_item() {
  sev=$1
  line=$2
  col=$3
  msg=$4
  code=$5
  esc=$(json_escape "$msg")
  printf '{"range":{"start":{"line":%s,"character":%s},"end":{"line":%s,"character":%s}},"severity":%s,"source":"sayanox","code":"%s","message":"%s"}' "$line" "$col" "$line" "$((col + 1))" "$sev" "$code" "$esc"
}

add_item() {
  item=$1
  if [ "$DIAG_FIRST" = 1 ]; then
    DIAG_ITEMS=$item
    DIAG_FIRST=0
  else
    DIAG_ITEMS="$DIAG_ITEMS,$item"
  fi
}

is_keyword() {
  word=$1
  for kw in $KEYWORDS; do
    [ "$word" = "$kw" ] && return 0
  done
  return 1
}

is_identifier() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

looks_like_unknown_keyword() {
  word=$1
  case "$word" in
    hol[dD]|holdd|sh[oO]w|shwo|wh[eE]n|whne|wh[iI]le|whlie|oth[eE]rwise|othwerwise|mak[eE]|mak|giv[eE]|giv|str[uU]ct|strcut|u[sS]e|ue|tru[eE]|tru|fals[eE]|flase)
      is_keyword "$word" && return 1
      return 0
      ;;
  esac
  return 1
}

line_prefix() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//'
}

analyze_document() {
  DIAG_ITEMS=""
  DIAG_FIRST=1
  brace_depth=0
  line_no=0

  # Feed the source through a temporary FIFO-free line loop. The here-string
  # equivalent is avoided because POSIX sh has no here-string syntax.
  old_ifs=$IFS
  IFS='
'
  printf '%s\n' "$DOC_TEXT" | while IFS= read -r raw || [ -n "$raw" ]; do
    line="$raw"
    trimmed=$(line_prefix "$line")

    # Strip simple // comments for the line-oriented checks.
    code_line=$(printf '%s' "$line" | sed 's|//.*$||')

    # Bad token: characters which are never valid in the Sayanox source subset.
    case "$code_line" in
      *'`'*|*'@'*|*'$'*)
        badcol=$(printf '%s' "$code_line" | awk '{ for (i=1;i<=length($0);i++) { c=substr($0,i,1); if (c=="`" || c=="@" || c=="$") { print i-1; exit } } }')
        add_item "$(make_item 1 "$line_no" "${badcol:-0}" "bad token in Sayanox source" "SX1001")"
        ;;
    esac

    # Unknown statement keyword: only inspect the first identifier in a
    # statement position, so ordinary user variables are not reported.
    first=$(printf '%s' "$trimmed" | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p')
    if [ -n "$first" ] && ! is_keyword "$first"; then
      case "$first" in
        [A-Z]*|_*|[a-z]*=*) : ;;
        *)
          if looks_like_unknown_keyword "$first"; then
            col=$(printf '%s' "$line" | awk -v w="$first" '{ p=index($0,w); print p-1 }')
            add_item "$(make_item 2 "$line_no" "${col:-0}" "unknown keyword: $first" "SX1002")"
          fi
          ;;
      esac
    fi

    # hold requires an assignment operator on the same statement line.
    case "$trimmed" in
      hold[[:space:]]*)
        if ! printf '%s' "$code_line" | grep -q '='; then
          col=$(printf '%s' "$line" | awk '{ p=index($0,"hold"); print p-1 }')
          add_item "$(make_item 1 "$line_no" "${col:-0}" "hold declaration requires =" "SX1003")"
        fi
        ;;
    esac

    # Best-effort empty show expression detection.
    case "$trimmed" in
      show|show[[:space:]])
        col=$(printf '%s' "$line" | awk '{ p=index($0,"show"); print p-1 }')
        add_item "$(make_item 1 "$line_no" "${col:-0}" "show requires an expression" "SX1004")"
        ;;
    esac

    # Braces are tracked across lines. Ignore braces occurring after //.
    opens=$(printf '%s' "$code_line" | tr -cd '{' | wc -c | tr -d ' ')
    closes=$(printf '%s' "$code_line" | tr -cd '}' | wc -c | tr -d ' ')
    i=0
    while [ "$i" -lt "${opens:-0}" ]; do brace_depth=$((brace_depth + 1)); i=$((i + 1)); done
    i=0
    while [ "$i" -lt "${closes:-0}" ]; do
      if [ "$brace_depth" -eq 0 ]; then
        col=$(printf '%s' "$line" | awk '{ p=index($0,"}"); print p-1 }')
        add_item "$(make_item 1 "$line_no" "${col:-0}" "unmatched }" "SX1005")"
      else
        brace_depth=$((brace_depth - 1))
      fi
      i=$((i + 1))
    done

    line_no=$((line_no + 1))
  done
  IFS=$old_ifs

  if [ "$brace_depth" -gt 0 ]; then
    last_line=$line_no
    [ "$last_line" -gt 0 ] && last_line=$((last_line - 1))
    add_item "$(make_item 1 "$last_line" 0 "unmatched {" "SX1005")"
  fi
}

publish_diagnostics() {
  analyze_document
  uri=$(json_escape "$DOC_URI")
  send_notification "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"$uri\",\"diagnostics\":[${DIAG_ITEMS:-}]}}"
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
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"capabilities\":{\"textDocumentSync\":1,\"completionProvider\":{\"triggerCharacters\":[\".\"]},\"hoverProvider\":true,\"definitionProvider\":true,\"diagnosticProvider\":{\"interFileDependencies\":false,\"workspaceDiagnostics\":false}},\"serverInfo\":{\"name\":\"sayanox-lsp\",\"version\":\"0.3.0\"}}}"
      ;;
    initialized)
      ;;
    textDocument/didOpen)
      DOC_URI=$(json_string_field uri "$msg")
      DOC_TEXT=$(unescape_json_text "$(json_string_field text "$msg")")
      publish_diagnostics
      ;;
    textDocument/didChange)
      uri=$(json_string_field uri "$msg")
      text=$(json_string_field text "$msg")
      [ -n "$uri" ] && DOC_URI=$uri
      [ -n "$text" ] && DOC_TEXT=$(unescape_json_text "$text")
      publish_diagnostics
      ;;
    textDocument/didClose)
      DOC_URI=$(json_string_field uri "$msg")
      send_notification "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"$(json_escape "$DOC_URI")\",\"diagnostics\":[]}}"
      ;;
    textDocument/diagnostic)
      uri=$(json_string_field uri "$msg")
      [ -n "$uri" ] && DOC_URI=$uri
      analyze_document
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":{\"kind\":\"full\",\"items\":[${DIAG_ITEMS:-}]}}"
      ;;
    textDocument/publishDiagnostics)
      publish_diagnostics
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
    shutdown)
      send "{\"jsonrpc\":\"2.0\",\"id\":${id:-1},\"result\":null}"
      ;;
    exit)
      exit 0
      ;;
  esac
done
