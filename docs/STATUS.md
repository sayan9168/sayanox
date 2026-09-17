# Project status

## Done

- Stage-2 full `.sa` → C host
- Self-host loops (`bootstrap_full_selfhost.sh`, `bootstrap_full_language_selfhost.sh`)
- Sayanox-written `codegen.sa` (hold/show/when/while)
- `sx`, `sxfmt.sh`, `sxpkg` (+ `sx.lock`), `sxrepl.sh`, `sayanox-lsp.sh`
- GC docs, types/errors docs, no Python in core

## Still deeper later

- `codegen.sa`: struct / list / multi-var / modules
- C-free production bootstrap (Stage-2 still hosts full grammar)
- Cranelift feature parity with C backend
- LSP: diagnostics / goto-def / rename
- Package registry (beyond path/git + lockfile)

## Commands

```bash
./selfhost/bootstrap_all.sh
./selfhost/sx examples/hello.sa --run
./tools/sxpkg install
```
