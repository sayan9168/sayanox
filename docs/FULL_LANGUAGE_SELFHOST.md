# Full-language self-host

## What you get

| Layer | Implements |
|-------|------------|
| **codegen.sa** (Sayanox) | `hold`, `show`, `when`, `while` → C |
| **Stage-2** (C host) | Full grammar (structs, lists, modules, …) |

## One command

```bash
chmod +x selfhost/bootstrap_full_language_selfhost.sh
./selfhost/bootstrap_full_language_selfhost.sh
```

Expect: `FULL-LANGUAGE SELF-HOST OK`

## How it works

1. Write target path to `selfhost/SX_TARGET` (no newline).
2. Stage-2 lowers `codegen.sa` → `sayanoxc_full_host` binary.
3. That binary (logic written in **Sayanox**) reads the target `.sa` and writes `codegen_emit.c`.
4. `clang` builds and runs the emit → e.g. `42`.

## Supported by Sayanox-written compiler

- `hold name = number`
- `show number` / `show name`
- `when cond { ... }`
- `while cond { ... }`

## Still on Stage-2 host

- `struct`, lists, modules, full stdlib, multi-var programs

Grow `codegen.sa` to shrink reliance on Stage-2.
