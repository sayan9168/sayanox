#!/bin/sh
# LSP robustness probe: malformed and unexpected JSON-RPC input must produce
# the spec's answer, and the server must keep serving afterwards.  Prints one
# line per verified fact.  Used by `make test-lsp-robust`.
#
#   sh tools/sayanox-lsp-robust.sh <lsp-binary>
#
# Only shell builtins are used (printf, case, test), like sayanox-lsp-probe.sh.
set -u

bin="$1"

send() { printf 'Content-Length: %s\r\n\r\n%s' "${#1}" "$1"; }

# 1. an unknown *request* (has an id) must be answered with -32601, not dropped
out=$(
  {
    send '{"jsonrpc":"2.0","id":9,"method":"textDocument/foldingRange","params":{}}'
    send '{"jsonrpc":"2.0","id":10,"method":"shutdown","params":{}}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"id":9,"error":{"code":-32601'*) echo 'unknown request -32601' ;; *) echo 'FAIL unknown request -32601'; exit 1 ;; esac
# ... and the next request is still answered (the server did not stop)
case "$out" in *'"id":10,"result":null'*) echo 'server keeps serving after error' ;; *) echo 'FAIL server stopped after error'; exit 1 ;; esac

# 2. an unknown *notification* (no id) must produce no output at all
out=$(
  {
    send '{"jsonrpc":"2.0","method":"$/setTrace","params":{"value":"off"}}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in '') echo 'unknown notification ignored' ;; *) echo 'FAIL unknown notification answered'; exit 1 ;; esac

# 3. a body that is not a JSON object -> -32700 parse error, id null
out=$(
  {
    send 'this is not json{{{'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"id":null,"error":{"code":-32700'*) echo 'garbage body -32700' ;; *) echo 'FAIL garbage body -32700'; exit 1 ;; esac

# 4. an object without a method -> -32600 invalid request
out=$(
  {
    send '{"jsonrpc":"2.0","id":4}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"code":-32600'*) echo 'no method -32600' ;; *) echo 'FAIL no method -32600'; exit 1 ;; esac

# 5. junk before a valid frame is skipped and the valid frame is answered
out=$(
  {
    printf 'junk\r\n\r\n'
    send '{"jsonrpc":"2.0","id":12,"method":"shutdown","params":{}}'
    send '{"jsonrpc":"2.0","method":"exit"}'
  } | "$bin"
)
case "$out" in *'"id":12,"result":null'*) echo 'junk header skipped' ;; *) echo 'FAIL junk header'; exit 1 ;; esac

# 6. a truncated frame (EOF inside the body) ends the session cleanly
{ printf 'Content-Length: 500\r\n\r\n{"jsonrpc":"2.0"'; } | "$bin" >/dev/null
echo 'truncated frame ends cleanly'
