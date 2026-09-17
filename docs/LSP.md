# Sayanox LSP

The repository includes a dependency-free POSIX `sh` language server at:

```text
tools/sayanox-lsp.sh
```

It uses **JSON-RPC over stdio**. It does not require Node, Python, Rust, or another LSP runtime.

## Editor setup

Point your editor's Sayanox language-server command directly at the script:

```bash
chmod +x tools/sayanox-lsp.sh
/path/to/sayanox/tools/sayanox-lsp.sh
```

The server must be launched as a long-running stdio process. Do not pipe normal source files into it; the editor sends LSP JSON-RPC messages on stdin and reads framed responses/notifications from stdout.

### VS Code-style clients

Configure the language server command as:

```text
/path/to/sayanox/tools/sayanox-lsp.sh
```

Use the repository's `.sa` files as the Sayanox language/document type and keep the server transport as stdio.

### Neovim-style clients

The equivalent command is:

```text
{ "/path/to/sayanox/tools/sayanox-lsp.sh" }
```

The important part is that the client starts one persistent process per workspace/document session and communicates using LSP stdio framing.

## Diagnostics

The server now provides lightweight real diagnostics through both the pull-style `textDocument/diagnostic` request and `textDocument/publishDiagnostics` notifications.

Current checks:

| Code | Check |
|------|-------|
| `SX1001` | bad token: `` ` ``, `@`, or `$` |
| `SX1002` | common misspelled/unknown Sayanox keyword in statement position |
| `SX1003` | `hold` without `=` |
| `SX1004` | `show` with an empty expression |
| `SX1005` | unmatched `{` or `}` |

Diagnostics are intentionally **best-effort and line-oriented**. They are not a replacement for the Sayanox compiler's parser/type checker. In particular, `SX1002` only recognizes a small set of common keyword misspellings so normal user-defined identifiers are not incorrectly reported as unknown keywords.

Diagnostics are refreshed after `textDocument/didOpen` and `textDocument/didChange`. `textDocument/didClose` clears diagnostics for the document.

## Capabilities

| Method | Support |
|--------|---------|
| `initialize` | yes |
| `textDocument/completion` | keywords + stdlib |
| `textDocument/hover` | brief language tip |
| `textDocument/definition` | stub (`null`) |
| `textDocument/diagnostic` | real lightweight diagnostics |
| `textDocument/publishDiagnostics` | real lightweight diagnostics |
| `textDocument/didOpen` | diagnostics refresh |
| `textDocument/didChange` | diagnostics refresh |
| `textDocument/didClose` | diagnostics clear |
| `shutdown` / `exit` | yes |

## Manual JSON-RPC smoke test

The server expects standard LSP `Content-Length` framing. For editor integration, let the editor send `initialize`, `didOpen`, and `didChange` messages rather than invoking the script with a normal `.sa` file.

Example diagnostic source:

```sayanox
hold answer
show
when true {
  show answer
}
}
```

The server reports the missing `=`, empty `show`, and unmatched `}` locations.
