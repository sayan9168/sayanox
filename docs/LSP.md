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
| `textDocument/didClose` | yes — clears the diagnostics for the URI |
| `textDocument/publishDiagnostics` | on every open/change |
| `textDocument/diagnostic` | pull model (`kind: full`) |
| `textDocument/documentSymbol` | `make` (Function), `struct` (Class), `hold` (Variable) |
| `textDocument/completion` | keywords and the builtin list |
| `textDocument/hover` | builtin documentation, a `make` signature, or the variable's declaration |
| `textDocument/definition` | jumps to the `make` / `hold` / `struct` line of the word under the cursor |
| `shutdown` / `exit` | yes (EOF also ends the session) |

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
* The server only keeps one document (full-text sync) and treats positions as
  byte offsets, which is right for ASCII and close enough for UTF-8 without
  multi-byte characters.

## The old shell server

`tools/sayanox-lsp.sh` is the original dependency-free shell stub (keyword
completion, one-line diagnostics). It is kept for environments where no
compiled binary can be shipped; the Sayanox implementation above is the
supported one and is what the tests cover.
