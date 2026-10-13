# Full self-host

> **The entry points named in this file do not exist (verified 2026-10-13).**
> There is no `make stage2` target, and no `selfhost/bootstrap_production.sh`,
> `bootstrap_full_selfhost.sh` or `bootstrap_full_language_selfhost.sh`.
> `selfhost/stage2_template.c` is a 93-byte placeholder, `selfhost/stage2_src/`
> holds a README and an 11-byte placeholder, `selfhost/sxc_full.c` is a 30-line
> toy, and `bash selfhost/restore_stage2.sh` exits 1 with
> `error: missing Stage-2 seed`. The supported path is
> `make doctor && make true-selfhost && make gen3 && make native-test`;
> `docs/FULL_LANGUAGE_SELFHOST.md` says what actually runs and
> `make test-doc-claims` keeps this banner honest.

## What “self-host” means here

| Layer | Language | Role |
|-------|----------|------|
| Stage-2 host | C | Lowers any `.sa` (full grammar) → C |
| Sayanox compilers | **Sayanox** | `sayanoxc.sa`, `compiler.sa`, `compiler_boot.sa` |
| Generated programs | C → binary | Output of those compilers |

The **compiler logic is written in Sayanox**. Stage-2 is only the bootstrap host that can lower the full language until the Sayanox-written compiler grows to full grammar.

## One command

```bash
make doctor && make true-selfhost && make gen3 && make native-test
```

Expected: `DOCTOR-OK`, `=== TRUE-SELFHOST-MIN-OK ===`, `[OK] byte-identical
gen3 == gen4` / `=== GEN3-OK ===` and `=== NATIVE-TEST-OK ===`.

The old text here said to run `./selfhost/bootstrap_full_selfhost.sh` and
expect `FULL SELF-HOST OK`. That script is not in the repository and never
produced that line in a fresh checkout; the command above is what is gated.

## Manual steps

```bash
# what the chain above actually does, step by step
./selfhost/seed/sxc_seed_min selfhost/compiler_min.sa > selfhost/gen1_min.c
cc -O2 -o selfhost/gen1_min selfhost/gen1_min.c
./selfhost/gen1_min selfhost/compiler_min.sa selfhost/gen2.c
cc -O2 -o selfhost/gen2 selfhost/gen2.c
./selfhost/gen2 selfhost/compiler_min.sa selfhost/gen3.c
cc -O2 -o selfhost/gen3 selfhost/gen3.c
./selfhost/gen3 selfhost/compiler_min.sa selfhost/gen4.c
cmp selfhost/gen3.c selfhost/gen4.c   # byte-identical, or the gate fails
```

The old "Manual steps" here started with `./selfhost/restore_stage2.sh`, which
exits 1 (`error: missing Stage-2 seed`), and used `./selfhost/stage2`, which is
not built because there is no Stage-2 host source. `clang` is also not a
dependency: `make doctor` requires a C99 `cc`.

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
