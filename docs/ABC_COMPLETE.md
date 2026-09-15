# A / B / C status

## A — `.sa` codegen depth

| Feature | Status |
|---------|--------|
| struct / list / expr | via `./selfhost/sx` full language |
| subset self-host | `codegen.sa` |

## B — Bootstrap

Stage-2 C is the thin host. No extra scripting languages required to build or run.

```bash
./selfhost/restore_stage2.sh
./selfhost/sx prog.sa --run
```

## C — Ecosystem

| Tool | Path |
|------|------|
| Package manager | `tools/sxpkg` |
| Formatter | `tools/sxfmt.sh` |
| REPL | `tools/sxrepl.sh` |
| Cranelift | Cargo feature `native` |
| GC | Stage-2 runtime (see `docs/GC.md`) |
