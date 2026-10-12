#!/bin/sh
# Real framed sessions; LC_ALL=C makes shell string lengths count UTF-8 bytes.
set -eu
LC_ALL=C
export LC_ALL
bin=$1
send() { printf 'Content-Length: %s\r\n\r\n%s' "${#1}" "$1"; }

session() {
  send '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
  send "$1"
  send '{"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///unicode.sa"},"position":{"line":1,"character":16}}}'
  send '{"jsonrpc":"2.0","id":3,"method":"textDocument/diagnostic","params":{"textDocument":{"uri":"file:///unicode.sa"}}}'
  send '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///unicode.sa","version":2},"contentChanges":[{"text":""}]}}'
  send '{"jsonrpc":"2.0","id":4,"method":"textDocument/diagnostic","params":{"textDocument":{"uri":"file:///unicode.sa"}}}'
  send '{"jsonrpc":"2.0","method":"exit"}'
}
raw='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///unicode.sa","text":"hold target = 1\nshow \"éক😀\" + target\nshow \"😀"}}}'
escaped='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///unicode.sa","text":"hold target = 1\nshow \"\u00e9\u0995\ud83d\ude00\" + target\nshow \"\ud83d\ude00"}}}'
out=$(session "$raw" | "$bin")
escout=$(session "$escaped" | "$bin")
[ "$out" = "$escout" ] || { echo 'FAIL raw and escaped Unicode differ'; exit 1; }
echo 'raw UTF-8 and JSON Unicode escapes agree'
case "$out" in *'"positionEncoding":"utf-16"'*) echo 'UTF-16 advertised' ;; *) exit 1 ;; esac
case "$out" in *'"id":2,"result":{"contents":{"kind":"markdown","value":"`target` — a variable in this document."}}'*) echo 'UTF-16 hover after BMP and supplementary characters' ;; *) printf 'FAIL hover\n%s\n' "$out"; exit 1 ;; esac
case "$out" in *'"start":{"line":2,"character":6},"end":{"line":2,"character":8}'*) echo 'diagnostic range does not split surrogate pair' ;; *) printf 'FAIL diagnostic\n%s\n' "$out"; exit 1 ;; esac
case "$out" in *'"id":4,"result":{"kind":"full","items":[]}'*) echo 'empty full-text didChange clears document' ;; *) exit 1 ;; esac
out=$(
  {
    send "$raw"
    send '{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":"file:///unicode.sa"}}}'
    send '{"jsonrpc":"2.0","id":5,"method":"textDocument/diagnostic","params":{"textDocument":{"uri":"file:///unicode.sa"}}}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"id":5,"result":{"kind":"full","items":[]}'*) echo 'didClose releases document state' ;; *) exit 1 ;; esac
out=$(
  {
    send "$raw"
    send '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///unicode.sa","version":2},"contentChanges":[]}}'
    send '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///other.sa","version":3},"contentChanges":[{"text":""}]}}'
    send '{"jsonrpc":"2.0","id":6,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///unicode.sa"},"position":{"line":1,"character":16}}}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"id":6,"result":{"contents":{"kind":"markdown","value":"`target` — a variable in this document."}}'*) echo 'empty change array and unrelated URI preserve document' ;; *) exit 1 ;; esac
