#!/bin/sh
# LSP probe: drive tools/sayanox_lsp through a full session and print one
# short line per verified fact.  Used by `make test-lsp`.
#
#   sh tools/sayanox-lsp-probe.sh <lsp-binary> [work-dir]
#
# Writes a document plus a module next to it in a work directory, so the
# `use "good.sa"` / `use "nope.sa"` diagnostics are exercised for real.  The
# directory defaults to $TMPDIR/sayanox-lsp-probe and is left in place; it is
# never cleaned up here because rm is not part of the minimal tool set the
# bootstrap promises (STATUS.md, "Minimal tool set").
#
# Only shell builtins, mkdir and the LSP binary are used: the payload length is
# ${#payload} instead of `wc -c | tr -d`, which is exact because every payload
# below is pure ASCII.
set -u

bin="$1"
work="${2:-${TMPDIR:-/tmp}/sayanox-lsp-probe}"
mkdir -p "$work"
doc="$work/doc.sa"
doc2="$work/doc2.sa"
printf 'hold a = 1\n' > "$work/good.sa"

send() { printf 'Content-Length: %s\r\n\r\n%s' "${#1}" "$1"; }

init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
open='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$doc'","text":"hold x = 1\nfrobnicate x\nuse \"good.sa\"\nuse \"nope.sa\"\nmake twice(v: num) -> num {\n  give v + v\n}\nshow twice(x)\nwhen x == 2 {\n  show \"oops\n"}}'
change='{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"uri":"file://'$doc'","text":"hold y = 2\nshow y\n"}}'
sym='{"jsonrpc":"2.0","id":2,"method":"textDocument/documentSymbol","params":{"uri":"file://'$doc'"}}'
comp='{"jsonrpc":"2.0","id":3,"method":"textDocument/completion","params":{"uri":"file://'$doc'","position":{"line":7,"character":8}}}'
hov='{"jsonrpc":"2.0","id":4,"method":"textDocument/hover","params":{"uri":"file://'$doc'","position":{"line":0,"character":3}}}'
def='{"jsonrpc":"2.0","id":5,"method":"textDocument/definition","params":{"uri":"file://'$doc'","position":{"line":7,"character":7}}}'
diag='{"jsonrpc":"2.0","id":6,"method":"textDocument/diagnostic","params":{"uri":"file://'$doc'"}}'
# ---- a second document, for the multi-document session ----
# The server keeps four documents open. doc is opened first and doc2 second;
# the symbol request for doc is sent AFTER doc2 was opened, so "symbol
# function" below can only be true if the first buffer is still served instead
# of being overwritten by the second.
open2='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$doc2'","text":"make thrice(v: num) -> num {\n  give v * 3\n}\nshow thrice(2)\n"}}'
sym2='{"jsonrpc":"2.0","id":8,"method":"textDocument/documentSymbol","params":{"uri":"file://'$doc2'"}}'
close2='{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"uri":"file://'$doc2'"}}'
shut='{"jsonrpc":"2.0","id":7,"method":"shutdown","params":{}}'
exitmsg='{"jsonrpc":"2.0","method":"exit"}'

out=$(
  {
    send "$init"
    send "$open"
    send "$hov"
    send "$def"
    send "$comp"
    send "$diag"
    send "$open2"
    send "$sym2"
    send "$sym"
    send "$change"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)

have() { case "$out" in *"$1"*) echo "$2" ;; esac; }
have2() { case "$out2" in *"$1"*) echo "$2" ;; esac; }
miss2() { case "$out2" in *"$1"*) ;; *) echo "$2" ;; esac; }
have3() { case "$out3" in *"$1"*) echo "$2" ;; esac; }
miss3() { case "$out3" in *"$1"*) ;; *) echo "$2" ;; esac; }

have '"capabilities"'            'initialize'
have '"sayanox-lsp"'             'serverInfo'
have 'SX1001'                    'diag unknown-statement'
have 'SX1002'                    'diag unterminated-string'
have 'SX1003'                    'diag unbalanced-braces'
have 'SX1005'                    'diag unresolved-use'
have '"name":"twice"'            'symbol function'
have '"name":"x"'                'symbol variable'
have '"label":"gc_runs"'         'completion builtin'
have '"label":"numstr"'          'completion literal preserved'
have 'hold name = value'         'hover builtin'
have '"line":4'                  'definition'
have '"diagnostics":[]'          'diagnostics cleared on change'
have '"name":"thrice"'          'second document symbols'

# ------------------------------------------------------- closed documents
# A closed document must stop being served, and must not be answered from
# another open buffer: after didClose the symbol request for doc2 has to come
# back empty.
out2=$(
  {
    send "$init"
    send "$open2"
    send "$close2"
    send "$sym2"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)
have2 '"id":8,"result":[]'    'closed document answers empty'
miss2 '"name":"thrice"'       'closed document not served from another buffer'

# ------------------------------------------------------- the four-slot cap
# Five documents: the fifth didOpen evicts the one that has been open longest,
# which is then no longer served (documented in docs/LSP.md). f1 is evicted,
# f5 is not.
mk() { printf '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://%s/cap%s.sa","text":"make f%s(v: num) -> num {\\n  give v + %s\\n}\\nshow f%s(1)\\n"}}' "$work" "$1" "$1" "$1" "$1"; }
sy() { printf '{"jsonrpc":"2.0","id":%s,"method":"textDocument/documentSymbol","params":{"uri":"file://%s/cap%s.sa"}}' "$1" "$work" "$2"; }
out3=$(
  {
    send "$init"
    send "$(mk 1)"
    send "$(mk 2)"
    send "$(mk 3)"
    send "$(mk 4)"
    send "$(mk 5)"
    send "$(sy 11 1)"
    send "$(sy 12 5)"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)
miss3 '"name":"f1"'           'fifth document evicts the oldest'
have3 '"name":"f5"'           'newest document still served'
