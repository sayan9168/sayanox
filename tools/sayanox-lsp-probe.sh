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
# ---- documents for the references / workspace-symbol / formatting sessions --
# docA declares `zz` and uses it three times; docB defines `helper` and uses
# `zz` once, so a reference search from docA has to span both buffers. docC is
# the same badly indented source that `make test-sxfmt` feeds the formatter
# program, so the two paths can be compared rule for rule.
docA="$work/refA.sa"
docB="$work/refB.sa"
docC="$work/fmtC.sa"
openA='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$docA'","text":"hold zz = 1\nshow zz\nwhen zz == 1 {\n  show zz\n}\n"}}'
openB='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$docB'","text":"make helper(v: num) -> num {\n  give v + zz\n}\nshow helper(2)\n"}}'
openC='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$docC'","text":"hold x = 1  \nwhen x > 0 {  \nshow \"brace } // not comment\"\n// comment { }\nwhen x == 1 {\n  show 42   \n}\n}\n"}}'
refA='{"jsonrpc":"2.0","id":21,"method":"textDocument/references","params":{"textDocument":{"uri":"file://'$docA'"},"position":{"line":1,"character":6},"context":{"includeDeclaration":true}}}'
refB='{"jsonrpc":"2.0","id":22,"method":"textDocument/references","params":{"textDocument":{"uri":"file://'$docA'"},"position":{"line":1,"character":6},"context":{"includeDeclaration":false}}}'
refNone='{"jsonrpc":"2.0","id":23,"method":"textDocument/references","params":{"textDocument":{"uri":"file://'$docA'"},"position":{"line":4,"character":0},"context":{"includeDeclaration":true}}}'
wsQ='{"jsonrpc":"2.0","id":31,"method":"workspace/symbol","params":{"query":"help"}}'
wsAll='{"jsonrpc":"2.0","id":32,"method":"workspace/symbol","params":{"query":""}}'
fmtC='{"jsonrpc":"2.0","id":33,"method":"textDocument/formatting","params":{"textDocument":{"uri":"file://'$docC'"},"options":{"tabSize":2,"insertSpaces":true}}}'
fmtB='{"jsonrpc":"2.0","id":34,"method":"textDocument/formatting","params":{"textDocument":{"uri":"file://'$docB'"},"options":{"tabSize":2,"insertSpaces":true}}}'
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
have4() { case "$out4" in *"$1"*) echo "$2" ;; esac; }
have5() { case "$out5" in *"$1"*) echo "$2" ;; esac; }
miss5() { case "$out5" in *"$1"*) ;; *) echo "$2" ;; esac; }

have '"capabilities"'            'initialize'
have '"sayanox-lsp"'             'serverInfo'
have '"renameProvider":true'     'rename capability'
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

# ------------------------------------------------------------- references
# A reference search answers from every open document, reports UTF-16 columns
# that cover the whole word, and honours context.includeDeclaration: with it
# false the `hold zz = 1` line is not part of the answer. A position that is
# not on a word answers [].
out4=$(
  {
    send "$init"
    send "$openA"
    send "$openB"
    send "$refA"
    send "$refB"
    send "$refNone"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)
have4 '"id":21,"result":[{"uri":"file://'"$docA"'","range":{"start":{"line":0,"character":5},"end":{"line":0,"character":7}}' 'references include the declaration'
have4 '"id":22,"result":[{"uri":"file://'"$docA"'","range":{"start":{"line":1,"character":5}' 'references honour includeDeclaration:false'
have4 '"uri":"file://'"$docB"'"'                    'references span the open documents'
have4 '"id":23,"result":[]'                         'references at a non-word answer empty'

# ------------------------------------------- workspace/symbol + formatting
# workspace/symbol searches the open documents (there is no directory listing
# builtin, so a file that was never opened cannot be found - docs/LSP.md) and
# filters by query, case-insensitively. textDocument/formatting is the sxfmt
# rule set over the protocol: docC comes back as one whole-buffer TextEdit with
# the same text `make test-sxfmt` expects from the formatter program, and a
# document that is already formatted answers [] so the buffer is left alone.
out5=$(
  {
    send "$init"
    send "$openA"
    send "$openB"
    send "$openC"
    send "$wsQ"
    send "$wsAll"
    send "$fmtC"
    send "$fmtB"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)
have5 '"id":31,"result":[{"name":"helper","kind":3'  'workspace symbol matches a query'
have5 '"id":32,"result":[{"name":"zz","kind":13'     'workspace symbol with an empty query spans documents'
have5 '"end":{"line":8,"character":0}},"newText":"hold x = 1' 'formatting answers one whole-buffer edit'
have5 'n  // comment { }'                            'formatting indents a comment inside a block'
have5 'n    show 42'                                 'formatting indents a nested block by four spaces'
miss5 'x = 1  '                                      'formatting strips trailing whitespace'
have5 '"id":34,"result":[]'                          'formatting leaves a formatted document alone'

# ------------------------------------------- rename / signatureHelp / codeAction
# Rename answers a WorkspaceEdit spanning the open documents (declaration
# included); signature help finds the enclosing call on the line, labels it
# with the declaration in the same document, and counts the argument the
# cursor is in; the one code action offers the formatting edit, and only
# when formatting would change the document.
docD="$work/sigD.sa"
openD='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"uri":"file://'$docD'","text":"make add2(a: num, b: num) -> num {\n  give a + b\n}\nshow add2(1, 2)\n"}}'
renA='{"jsonrpc":"2.0","id":41,"method":"textDocument/rename","params":{"textDocument":{"uri":"file://'$docA'"},"position":{"line":1,"character":6},"newName":"ww"}}'
sigD='{"jsonrpc":"2.0","id":42,"method":"textDocument/signatureHelp","params":{"textDocument":{"uri":"file://'$docD'"},"position":{"line":3,"character":13}}}'
actC='{"jsonrpc":"2.0","id":43,"method":"textDocument/codeAction","params":{"textDocument":{"uri":"file://'$docC'"},"range":{"start":{"line":0,"character":0},"end":{"line":0,"character":1}}}}'
actB='{"jsonrpc":"2.0","id":44,"method":"textDocument/codeAction","params":{"textDocument":{"uri":"file://'$docB'"},"range":{"start":{"line":0,"character":0},"end":{"line":0,"character":1}}}}'
out6=$(
  {
    send "$init"
    send "$openA"
    send "$openB"
    send "$openC"
    send "$openD"
    send "$renA"
    send "$sigD"
    send "$actC"
    send "$actB"
    send "$shut"
    send "$exitmsg"
  } | "$bin"
)
have6() { case "$out6" in *"$1"*) echo "$2" ;; esac; }
have6 '"id":41,"result":{"changes":{"file://'"$docA"'":[{"range":{"start":{"line":0,"character":5}' 'rename edits the declaration'
have6 '"newText":"ww"'                              'rename carries the new name'
have6 '"file://'"$docB"'":['                        'rename spans the open documents'
have6 '"label":"make add2(a: num, b: num)'          'signature help labels the declaration'
have6 '"label":"a: num"'                            'signature help lists the parameters'
have6 '"activeParameter":1'                         'signature help counts the argument'
have6 'Format this Sayanox document'                'code action offers formatting'
have6 '"id":44,"result":[]'                         'code action is empty when already formatted'
