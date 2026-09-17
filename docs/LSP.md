# Sayanox LSP

```bash
chmod +x tools/sayanox-lsp.sh
# Point your editor's language server command at:
#   /path/to/sayanox/tools/sayanox-lsp.sh
```

## Capabilities

| Method | Support |
|--------|--------|
| `initialize` | yes |
| `textDocument/completion` | keywords + stdlib |
| `textDocument/hover` | brief language tip |
| `shutdown` / `exit` | yes |

stdio JSON-RPC, no extra runtime.
