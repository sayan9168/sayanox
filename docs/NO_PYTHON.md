# No Python required

Sayanox **core** toolchain does not need Python.

| Tool | Language |
|------|----------|
| Stage-2 | C (`restore_stage2.sh` → `base64` + `gzip` + `clang`) |
| `sx` CLI | Bash + C |
| Formatter | `tools/sxfmt.sh` (awk) |
| Packages | `tools/sxpkg` (bash) |

Optional only:

- `tools/sayanox-lsp.py` — editor LSP (install Python only if you want it)
- `selfhost/patch_stage2_*.py` — legacy; **not** used by restore

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```
