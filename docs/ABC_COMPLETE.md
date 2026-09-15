# A / B / C completion status

## A — `.sa` codegen depth

| Feature | Status | How |
|---------|--------|-----|
| struct fields | MVP | Rust host + Stage-2 `sx` full language; `.sa` codegen emits struct stub |
| list push / len | MVP | Stage-2 runtime `push`/`len`; codegen list + index |
| expressions | MVP | Stage-2 full expr; `.sa` codegen numbers/idents |
| otherwise | Done | codegen.sa |

**Full language programs:** `./selfhost/sx file.sa --run`  
**Subset self-host compiler:** `python3 selfhost/install_codegen.py && ./selfhost/step5_all.sh`

## B — Bootstrap

Stage-2 C is the **thin permanent host** (cannot boot a CPU from zero).

```bash
./selfhost/restore_stage2.sh   # build stage2
./selfhost/sx prog.sa --run    # no Rust required
make selfhost                  # full verification
```

More logic lives in `.sa` (codegen.sa); C only executes it.

## C — Ecosystem MVP

| Tool | Path | Command |
|------|------|--------|
| Package manager | `tools/sxpkg` | `sxpkg init \| install \| list \| add` |
| LSP (MVP) | `tools/sayanox-lsp.py` | stdio JSON-RPC hover/complete |
| GC note | `docs/GC.md` | design; runtime still manual/C |
| Cranelift AOT | Cargo feature `native` | `cargo build --features native` then `--native` / `--jit` |

Honest limit: LSP/GC/Cranelift are **MVP / optional**, not production-grade IDE or GC.
