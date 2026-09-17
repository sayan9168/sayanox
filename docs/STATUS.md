# Project status

## Done

- Stage-2 full `.sa` → C (primary compiler — **no Rust**)
- Self-host loops + `codegen.sa` (hold/show/when/while in Sayanox)
- `sx`, `sxfmt.sh`, `sxpkg` (+ lockfile), `sxrepl.sh`, `sayanox-lsp.sh`
- Rust host / Cranelift / Cargo **removed**

## Later depth

- `codegen.sa`: struct / list / multi-var / modules
- C-free production bootstrap (Stage-2 still hosts full grammar)
- LSP diagnostics / goto-def
- Package registry

```bash
./selfhost/bootstrap_all.sh
./selfhost/sx examples/hello.sa --run
```
