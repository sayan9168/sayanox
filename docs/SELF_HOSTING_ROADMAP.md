# Sayanox self-hosting roadmap

## Goal

Move more of the maintained Sayanox compiler and developer tooling into
Sayanox itself while preserving a reproducible, testable bootstrap. Self-hosting
is a progression; it does not mean deleting the first C seed before another
trusted compiler can replace it.

## Current verified architecture

```text
C seed-min -> gen1-min (compiled from compiler_min.sa) -> gen2
                                                    -> gen3 -> gen4
                                                       byte-identical
```

`selfhost/compiler_min.sa` is the Sayanox-written compiler for the documented
pure-min subset. A host C99 compiler builds the generated C. The separate
native-AOT path is implemented in C and emits x86-64 Linux machine code for a
tested subset. `make true-selfhost`, `make gen3` and `make native-test` are the
current regression entry points.

This path does not require Rust. Older files and documents describing a Rust
bootstrap, Cargo CLI, or a full Stage-2 compiler are historical experiments and
are not part of the verified current bootstrap.

## Engineering principles

1. **Keep the language source authoritative.** New shared-dialect behavior
   should be specified in Sayanox source and covered by seed-min/gen2 tests.
2. **Preserve backend parity.** When a feature is supported by native AOT, add
   matching tests or a clear, intentional diagnostic for unsupported forms.
3. **Keep bootstrap reproducible.** Every compiler change must pass the
   fixed-point check; regenerate the packed offline fallback after changing
   `compiler_min.sa`.
4. **Prefer incremental slices.** Add one syntax/runtime capability with tests
   and diagnostics at a time rather than claiming a full language from demos.

## Remaining roadmap

### Language and compiler

- Grow beyond the pure-min compiler toward the full language experiments in
  `selfhost/`, with a real parsed/checked IR pipeline.
- Add missing control-flow and expression syntax (for example, range/for-in
  loops and `elif`) with clear cross-backend semantics.
- Add namespaced modules and dependency/version resolution instead of the
  current textual `use` splice.
- Expand the standard library and improve error/source-span reporting.

### Runtime and native backend

- Define a consistent ownership policy, then implement it in all maintained
  backends before claiming automatic memory management or GC.
- Expand native AOT coverage and add a portable backend target; current native
  output is x86-64 Linux only.

### Tools and packages

- **Formatter first slice delivered:** `tools/sxfmt.sa` is now built by gen2;
  `make test-sxfmt` verifies brace-aware two-space indentation, whitespace
  trimming, strings/comments, final newline and idempotence. It is deliberately
  whitespace-only, not yet parser-backed.
- **Local package-tool slice delivered:** `tools/sxpkg.sa` implements
  `init`, `add`, `list`, `remove`, `seed`, `search` and `info`; the shell
  entrypoint delegates these commands to it and `make test-sxpkg` covers them.
  Port the remaining package-directory and sync/install/publish/fetch behavior
  from `tools/sxpkg.sh`; this needs Sayanox filesystem, process and network APIs.
- Port `tools/sayanox-lsp.sh` only after the language/runtime can read and write
  JSON-RPC over stdin/stdout and parse JSON safely.
- Add reproducible package locks, dependency validation and remote publishing
  only after the registry protocol and trust model are defined.

### Bootstrap boundary

The current maintained path intentionally keeps `selfhost/seed/sxc_seed_min.c`
as the first executable seed, uses `compiler_min.sa` for the Sayanox-owned
compiler, and retains C for the x86-64 native backend. `Makefile` and POSIX
shell recipes orchestrate bootstrap/tests. Porting ordinary tool and compiler
logic to Sayanox is the goal; removing every host/bootstrap primitive in one
step is not a realistic or safe acceptance criterion.

## Definition of success

A feature is complete when the grammar and semantics are documented, its tests
cover valid and invalid programs, supported backends agree (or have explicit
documented differences), the bootstrap fixed point passes, and user-facing
docs no longer overstate support. The full Stage-2 experiments are not yet
self-hosted; see [`STATUS.md`](STATUS.md) and [`FEATURES.md`](FEATURES.md) for
the current verified boundary.
