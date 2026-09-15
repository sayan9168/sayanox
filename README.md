# Sayanox

**Sayanox** — an original programming language (`.sa`). By **Sayan Mahata**.

> **Self-hosting first:** Sayanox source is becoming the primary place for compiler, tooling, and runtime logic. Rust is kept as a bootstrap implementation while the Sayanox toolchain grows toward self-hosting.

## Quick start

The normal development path uses the Sayanox self-host toolchain:

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

## Toolchain roles

| Component | Role | Long-term status |
|------|------|------|
| `selfhost/*.sa` | Compiler and bootstrap logic written in Sayanox | **Primary / expanding** |
| `selfhost/sx` | Sayanox-first compile/run driver | **Primary** |
| `tools/sxfmt.sh` | Formatter | Migration target: Sayanox |
| `tools/sxpkg` | Package manager | Migration target: Sayanox |
| `tools/sxrepl.sh` | REPL | Migration target: Sayanox |
| Rust implementation | Bootstrap compiler/runtime implementation | **Bootstrap / shrinking** |
| C/Clang | Temporary bootstrap/link boundary | **Temporary** |

The Rust implementation is **not** the long-term language implementation. It exists to bootstrap and validate the Sayanox implementation while more of the toolchain is rewritten in Sayanox itself.

## Self-hosting direction

The project is intentionally moving through these stages:

1. **Bootstrap** — keep the existing Rust implementation reliable.
2. **Sayanox compiler frontend** — lexer, parser, AST, diagnostics and semantic analysis move into Sayanox.
3. **Sayanox code generation** — compiler lowering and backend orchestration move into Sayanox.
4. **Sayanox tooling** — formatter, package manager, REPL, test runner and build driver move into Sayanox.
5. **Sayanox runtime** — progressively replace bootstrap-only runtime pieces with Sayanox-owned implementations where practical.
6. **Self-hosted compiler** — Sayanox can rebuild the Sayanox compiler/toolchain from Sayanox source with only a small trusted bootstrap seed.

See [`docs/SELF_HOSTING_ROADMAP.md`](docs/SELF_HOSTING_ROADMAP.md) for the implementation rules and milestones.

## Optional native backend

The host-native backend remains optional and is not required for the Sayanox-first VM path:

```bash
cargo build --release --features native
```

## License

MIT
