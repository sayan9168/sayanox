# Sayanox LSP

A language server for `.sa` files, written in Sayanox and compiled by `gen2`.
There is no Node or Python runtime in the path: the server is a native binary
that speaks JSON-RPC 2.0 with `Content-Length` framing on stdin/stdout.

```sh
make lsp        # tools/sayanox_lsp  (gen2 compiles tools/sayanox_lsp.sa)
make test-lsp   # a full session, checked fact by fact
tools/sayanox_lsp < session.txt        # or wire it into an editor
```

## Capabilities

| Method | Support |
|--------|---------|
| `initialize` | yes — `textDocumentSync: 1` (full), completion/hover/definition/documentSymbol/diagnostic providers, `serverInfo: sayanox-lsp 2.0` |
| `initialized` | yes |
| `textDocument/didOpen` | yes — stores the document and publishes diagnostics |
| `textDocument/didChange` | yes — full-text sync, re-publishes diagnostics |
| `textDocument/didClose` | yes — clears diagnostics and releases the matching document state |
| `textDocument/publishDiagnostics` | on every open/change |
| `textDocument/diagnostic` | pull model (`kind: full`) |
| `textDocument/documentSymbol` | `make` (Function), `struct` (Class), `hold` (Variable) |
| `textDocument/completion` | keywords and the builtin list |
| `textDocument/hover` | builtin documentation, a `make` signature, or the variable's declaration |
| `textDocument/definition` | jumps to the `make` / `hold` / `struct` line of the word under the cursor |
| `shutdown` / `exit` | yes (EOF also ends the session) |

## Error responses (robustness)

A client should never wait for an answer that will not come. The server
follows JSON-RPC 2.0 for input it cannot dispatch (`make test-lsp-robust`,
probe `tools/sayanox-lsp-robust.sh`):

| Input | Response |
|---|---|
| a request (has an `id`) with a method the server does not implement | error `-32601` "method not found", with the same `id` |
| a notification (no `id`) with an unknown method | **no response** (the spec says so) |
| a body that is not a JSON object (`this is not json`) | error `-32700` "parse error", `id: null` |
| an object with no `method` | error `-32600` "invalid request", with its `id` or `null` |
| junk lines before a `Content-Length` frame | skipped; the next valid frame is answered |
| a frame that ends before its declared length | the session ends cleanly; no crash |

After any of these the server keeps serving the next valid request.

Request ids are echoed as sent, so a **string id** (`"id":"abc-1"`) comes back
with its quotes and escapes, a number or `null` comes back unchanged, and a body
with no `id` is a notification (no reply). Covered by `test-lsp-robust`.

Limits, stated plainly: framing needs `Content-Length`, so a header-less stream
is ignored until one appears.

## Diagnostics

Diagnostics are computed from the document text and the file system — not from
a regex over one line:

| Code | Severity | Meaning |
|------|----------|---------|
| `SX1001` | error | unknown statement: the line starts with a word that is neither a keyword/builtin nor a declared `hold`/`make`/`struct` — and the line is not an assignment or a call |
| `SX1002` | error | unterminated string literal |
| `SX1003` | error | unbalanced braces (with the count of unclosed blocks) |
| `SX1004` | error | unbalanced parentheses |
| `SX1005` | warning | `use "file.sa"` cannot be read next to the document (the same resolution the compiler uses) |

## Editor setup (Neovim)

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sa",
  callback = function()
    vim.lsp.start({
      name = "sayanox",
      cmd = { "/path/to/sayanox/tools/sayanox_lsp" },
      root_dir = vim.fn.getcwd(),
    })
  end,
})
```

## How it is built and tested

* `tools/sayanox_lsp.sa` is the whole server: a JSON reader (string escapes,
  `\uXXXX`), a JSON writer with escaping, the document scanner, the diagnostic
  pass, symbols, completion, hover and definition, and the framing loop.
* `tools/sayanox-lsp-probe.sh` pipes a real session (initialize, didOpen,
  hover, definition, documentSymbol, completion, diagnostic, didChange,
  shutdown, exit) into the binary and prints one line per verified fact.
  `make test-lsp` asserts that list, and the target is part of the
  `true-selfhost-min` gate — i.e. the LSP is exercised by `make test`.
* The server keeps one document (full-text sync). It advertises UTF-16
  positions and converts UTF-8 scanner offsets at the protocol boundary.

## The old shell server

`tools/sayanox-lsp.sh` is the original dependency-free shell stub (keyword
completion, one-line diagnostics). It is kept for environments where no
compiled binary can be shipped; the Sayanox implementation above is the
supported one and is what the tests cover.

### Neovim filetype registration and launch checks

Register the language independently of Linguist (do not map `.sa` to C or
Python). Put this before the autocmd above:

```lua
vim.filetype.add({ extension = { sa = 'sa' } })
```

Run `make lsp` once, then launch the absolute `tools/sayanox_lsp` binary from
the client. Do **not** launch `make lsp` as the server: build output is not
JSON-RPC and would corrupt the stdio transport. The server needs neither
Python nor a network connection. `make test-lsp test-lsp-robust` runs actual
framed request/response sessions, including full-text `didChange`, cleared
diagnostics, escaped ids and malformed/unknown request errors.

## Unicode and document lifecycle (2026-10-11)

`positionEncoding: "utf-16"` is advertised. Incoming hover/definition positions
are converted to UTF-8 byte offsets; diagnostic spans are converted back to
UTF-16, without cutting a supplementary character's surrogate pair. Cursor
positions inside a surrogate pair clamp to that character's start. End-of-line
positions clamp rather than spilling into the next line.

JSON `\uXXXX` strings are decoded into UTF-8, including paired surrogate
escapes. Raw UTF-8 and escaped text are tested for identical protocol output.
`test-lsp-unicode`, included by `test-lsp`, covers accented Latin, Bengali and
emoji preceding a hover target, and a diagnostic ending on an emoji.

A full-text change with `"text":""` now actually clears the document. An empty
change array preserves it; changes for another URI do not overwrite the
active document. Closing the matching URI releases its text. Tests use real
`Content-Length` sessions, not calls to mocked helper functions.

Current product limits: one open document (the latest didOpen wins), full-text
synchronization, one replacement per change notification, no cross-file type
analysis or incremental edits. The JSON field reader is lightweight, not a
complete validating JSON parser. Invalid/unpaired Unicode escapes and escaped
U+0000 are replaced with U+FFFD (the runtime cannot store embedded NUL).
Identifier recognition remains ASCII; UTF-16 positioning does not add Unicode
identifiers to the compiler. These probes do not claim complete LSP conformance
or a full compiler diagnostic pass.
