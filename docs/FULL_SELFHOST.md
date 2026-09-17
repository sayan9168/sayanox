# Full self-host

## What “self-host” means here

| Layer | Language | Role |
|-------|----------|------|
| Stage-2 host | C | Lowers any `.sa` (full grammar) → C |
| Sayanox compilers | **Sayanox** | `sayanoxc.sa`, `compiler.sa`, `compiler_boot.sa` |
| Generated programs | C → binary | Output of those compilers |

The **compiler logic is written in Sayanox**. Stage-2 is only the bootstrap host that can lower the full language until the Sayanox-written compiler grows to full grammar.

## One command

```bash
chmod +x selfhost/bootstrap_full_selfhost.sh
./selfhost/bootstrap_full_selfhost.sh
```

Expected: all steps print `OK` and `FULL SELF-HOST OK`.

## Manual steps

```bash
./selfhost/restore_stage2.sh

# Build Sayanox-written compiler to native binary
./selfhost/stage2 selfhost/sayanoxc.sa selfhost/sayanoxc_host.c
clang -o selfhost/sayanoxc_host selfhost/sayanoxc_host.c
./selfhost/sayanoxc_host          # writes sayanoxc_out.c
clang -o selfhost/sayanoxc_prog selfhost/sayanoxc_out.c
./selfhost/sayanoxc_prog          # → 42
```

## Loop diagram

```text
  sayanoxc.sa ──Stage-2──► sayanoxc_host (native)
       │                        │
       │                        ▼
       │                  hello.sa → C → 42
       │
  compiler.sa ──Stage-2──► stage3_compiler (native)
                                │
                                ▼
                          hello_out.c → 42
```

## Next expansion

Grow `sayanoxc.sa` to emit `hold` / `when` / `while` / `make` so Stage-2 is needed less for everyday programs.
