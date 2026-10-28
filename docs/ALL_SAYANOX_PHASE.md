# All maintained implementation source in Sayanox

Status (2026-10-27): **source retirement and guarded migration acceptance passed**
([PR #40 CI run](https://github.com/sayan9168/sayanox/actions/runs/40496211582)).

The audit covers all maintained implementation source with an explicit binary trust input and retained C-output compatibility.

The Makefile and final frozen C seed have been removed. The maintained compiler,
frontends, runtimes/backends, build/bootstrap logic, dependency handling, recovery,
cleanup, audits, tests, package/LSP tooling, CI guard and release implementation
are Sayanox (`.sa`). The original 236 target names remain implemented by `./sx`.
Metadata, documentation, CI YAML and generated artifacts are not language source.

## Explicit binary trust input

A clean Linux x86-64 checkout starts with generated `sx` and the pinned native
compiler `bootstrap/sxc_native.bin`. These are explicit binary trust inputs,
**not independent proof that source is trustworthy**. The native compiler
rebuilds itself over three generations and requires byte equality with the
anchor before installation. The entry must match a rebuild of `tools/sxbuild.sa`.
Hashes and self-reproduction do not eliminate trusting-trust attacks.
See [native bootstrap](NATIVE_BOOTSTRAP.md) and [entry provenance](../bootstrap/README.md).

## Real bootstrap and C-output compatibility

Stage 0 compiles `selfhost/compiler_min.sa` to a native C-output frontend and
`selfhost/seed/sxc_seed_min.sa` to the native compatibility CLI. No maintained C
compiler source is hidden in strings or reconstructed from Git/network history.
`seed_runtime_lib.sa` contains **emitted runtime templates**, not a stored C parser.
Generated C and its host compiler remain supported for compatibility and tests.
Necessary external tools (including process-launch shell, host C compiler,
Git/checksum/archive utilities and optional transports) remain dependencies.
This is not a claim that host utilities or generated machine code are Sayanox.

The native-origin own-source chain passes: Sayanox seed -> C1 -> C2 -> identical
C3. C1's complete own-source emission passes under a 64 MiB address-space limit.
The isolated bootstrap test reconstructs both compiler and seed from Sayanox
without any C source, while recording cc/gcc/clang poisons remain unused.

All 14 seed compatibility gates and the GC memory gate pass. Aliases survive
collection; discarded list headers and backing buffers are reclaimed within a
4 MiB test budget. Six actual ASan/UBSan runs pass with stdout comparisons
(leak detection explicitly disabled for the conservative collector). Compact
source-view words are checked for byte/48-bit precision on both native and C
backends. Balanced source splices preserve semantics without quadratic copying.
Recovery packing/restoration verifies byte-identical source files.

## Audits and acceptance

```sh
sha256sum -c bootstrap/sx.sha256
./sx verify-entry
./sx target verify-seed all-sayanox test-trust-anchor test-doc-claims
./sx target test-native-bootstrap
./sx ci-guard
./sx ci
./sx target test-driver
./sx ci-guard-check
```

The source audit rejects maintained tracked C/header or shell-script files,
reappearing retired inputs and Makefile. It measures the explicit native binary
anchor using the Sayanox SHA-256 auditor. `all-sayanox` is an inventory/bootstrap
audit, not a substitute for complete guarded CI, a release, or an exhaustive
full-language claim. Full-language conformance still has a separate fail-closed
boundary when no reviewed exhaustive specification exists.

The historical C exception (Phase E option 2) is retired. Tools such as
`tools/emit_to_ir.sa` remain genuine Sayanox implementations, not aliases for
removed host scripts. The linked PR #40 run passed the complete original and
migrated acceptance jobs; that is migration evidence, not a claim that every
remaining language or platform feature is implemented.
