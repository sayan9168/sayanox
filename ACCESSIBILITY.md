# Accessibility

This document describes Sayanox’s accessibility posture for the **project and documentation**, not a claim that every compiled program is accessible by default.

## Commitment

We want the Sayanox repository, docs, and tooling to be usable by as many people as possible, including people who use assistive technologies.

## What this project is

Sayanox is a programming language and self-hosting compiler toolkit (`.sa` sources, C seed, native AOT on x86-64 Linux, offline packages, LSP slice). Most interaction is through:

* a terminal (`make`, compilers, tests)
* Markdown documentation in the repository
* optional editor integration via the language server (`make lsp` / `tools/sayanox_lsp.sa`)

## Supported environments (development)

* **Text-first workflow:** All primary docs are plain Markdown; build and test entry points are documented commands in the README and `docs/STATUS.md`.
* **Keyboard / CLI:** Bootstrap and tests are driven from the shell (`make doctor`, `make true-selfhost`, `make gen3`, `make native-test`). No GUI is required to build or verify the core compiler path.
* **Editors:** The LSP speaks standard JSON-RPC; accessibility of a given editor depends on that editor and OS, not only on Sayanox.

## Known limitations

* **Native AOT** targets **x86-64 Linux** only today; other platforms use the C backend path where available.
* **Color / badges** in the README are decorative; information is also written in text.
* **Diagrams or screenshots** in docs (if any) may lack full text equivalents; prefer filing an issue when something is unclear without visuals.
* Generated or binary artifacts are not intended as the accessible source of truth — use `.sa` / Markdown / logged test output.

## Reporting barriers

If documentation, issue templates, error messages, or tooling block access:

1. Open an issue: https://github.com/sayan9168/sayanox/issues  
2. Or contact the maintainer: [@sayan9168](https://github.com/sayan9168)

Please describe the barrier, your environment (OS, assistive tech if relevant), and what would help.

## Continuous improvement

We treat accessibility reports like other quality bugs: triage, fix when feasible, and document permanent limitations honestly in `docs/STATUS.md` when they are platform or scope limits rather than oversights.
