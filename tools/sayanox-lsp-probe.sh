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
shut='{"jsonrpc":"2.0","id":7,"method":"shutdown","params":{}}'
exitmsg='{"jsonrpc":"2.0","method":"exit"}'

out=$(
  {
    send "$init"
    send "$open"
    send "$hov"
    send "$def"
    send "$sym"
    send "$comp"
    send "$diag"
    send "$change"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)

have() { case "$out" in *"$1"*) echo "$2" ;; esac; }

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
