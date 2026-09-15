# Sayanox LSP MVP

```bash
python3 tools/sayanox-lsp.py
```

Speaks LSP over stdio. Capabilities:
- `initialize`
- `textDocument/completion` (keywords + stdlib)
- `textDocument/hover`

VS Code / Neovim: point the client at this script as the language server command.
