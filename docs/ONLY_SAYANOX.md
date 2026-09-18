# Only Sayanox — what that means

## Your goal

All **programs**, **compiler logic**, **tools**, and **stdlib** written in **Sayanox (`.sa`)** — not Python, not Rust, not Bash scripts as the language.

## Hard fact (every language has this)

A computer cannot run `.sa` source until **something** turns it into machine code.

That “something” must exist first:

| Layer | What it is | Language |
|-------|------------|----------|
| **Sayanox language** | lexer, parser, codegen, CLI, examples, tools | **only `.sa`** |
| **Bootstrap seed** | first AOT / Stage-2 host so `.sa` can run at all | minimal C → one binary |

Without a seed, `git clone` alone cannot invent an x86_64 executable from pure text.

This is the same reason C needed an assembler, Rust needed a first compiler, etc.

## What is already Sayanox

- `selfhost/*.sa` — compiler pipeline (`sayanoxc.sa`, `codegen.sa`, `lexer.sa`, …)
- `tools/*.sa` — sxfmt, sxpkg, …
- `examples/*.sa`

## What is *not* the language (seed only)

- `selfhost/native_aot.c` / `native_src/*` — **seed** native AOT so subset `.sa` becomes ELF **without** clang for *user programs*
- `selfhost/build_stage2.c` / Stage-2 — **seed** full-language path
- `Makefile` — not a language; only orchestrates the seed build once

## Target end-state

1. Seed built **once** on a machine (`make native` or `make stage2`).
2. After that: you write **only `.sa`**.
3. Grow native + self-host until the seed is rarely touched and eventually replaceable by a Sayanox-written emitter (still needs *some* first binary in history).

## What we will not claim

We will **not** claim “zero C on disk and still magically runs after clone with no binary.” That is physically impossible.

We **do** claim: **your language and your programs are Sayanox; other files are bootstrap machinery only.**
