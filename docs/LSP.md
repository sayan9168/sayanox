# Sayanox LSP v1.0

```sh
chmod +x tools/sayanox-lsp.sh
```

## Capabilities

| Method | Support |
|--------|---------|
| `initialize` | yes |
| `textDocument/completion` | keywords + builtins |
| `textDocument/hover` | language tip |
| `textDocument/definition` | stub |
| `textDocument/documentSymbol` | make / hold / struct |
| `textDocument/diagnostic` | SX1001 |
| `textDocument/publishDiagnostics` | on open/change |
| `didOpen` / `didChange` / `didClose` | yes |
| `shutdown` / `exit` | yes |

## Neovim

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sa",
  callback = function()
    vim.lsp.start({
      name = "sayanox",
      cmd = { "/path/to/sayanox/tools/sayanox-lsp.sh" },
      root_dir = vim.fn.getcwd(),
    })
  end,
})
```
