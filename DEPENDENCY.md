# Dependency audit — 2026-10-27

All maintained implementation source is Sayanox. The Makefile, final frozen C
seed and maintained shell scripts are retired. The original 236 target names
are implemented by native `./sx`; target registration and actual full guarded
acceptance are measured separately in [the migration report](docs/MAKEFILE_MIGRATION.md).

## Trust inputs

- Generated static Linux x86-64 `sx`, rebuilt from `tools/sxbuild.sa` by
  `./sx verify-entry`.
- Pinned native `bootstrap/sxc_native.bin`, reconstructed from its Sayanox
  compiler sources over three generations, requiring source-built equality with
  the anchor before installation.
- `bootstrap/sx.sha256`, `bootstrap/native.sha256` and the Sayanox SHA-256/size
  audit `bootstrap/sxc_native.audit` make input drift visible.

These binary inputs are explicitly trusted, not independent proof of source
trustworthiness. Hashes/self-reproduction cannot eliminate trusting-trust attacks.
See [bootstrap provenance](bootstrap/README.md).

## Permitted external tool boundaries

- Linux x86-64 and its syscall ABI execute the static native compiler/tools.
- A POSIX process-launch shell runs leaf commands assembled by the Sayanox
  driver. Quoting, graph selection, dependency state, validations and assertions
  belong to Sayanox, not an embedded legacy recipe interpreter.
- The external C99 toolchain (including its assembler/linker) compiles
  **generated C output** for retained compatibility, self-hosting and parity
  tests. No maintained C bootstrap compiler source is compiled.
- `chmod`/`mv` publish staged native executables. Git and checksum/archive tools
  provide repository, integrity and release-container operations.
- `gzip` is a leaf compressor/decompressor for offline recovery. Base64,
  partitioning, recovery orchestration and byte-identity checks are Sayanox.
- Optional external transport is explicit. Maintained local HTTP/package/LSP
  fixtures and clients are Sayanox; bootstrap must not download a compiler.

A native tool failure never silently falls back to C. Explicit C tool emission
remains available with `SXBUILD_VIA_C=1`; that is an intentional host-C route,
not the native bootstrap. Existing CC/compiler override failure propagation is
preserved.

## Ownership of operations

`./sx target <name>` uses Sayanox implementations for build/bootstrap,
dependencies, tests, clean, recovery, audits, CI and release logic. Cleanup
preserves trusted entry/anchor/source inputs and removes disposable artifacts.
The C-output runtime text in Sayanox backend templates is generated output,
not a disguised stored C parser or compiler.

Stage 0 builds the native C-output frontend and seed CLI from Sayanox. Later
stages retain real own-source C compilation and fixed-point checks. The native
origin chain C1 -> C2 == C3 passes, and complete C1 emission passes under the
existing 64 MiB address-space bound. The Sayanox seed's string/list tracing
collector retains borrowing/alias semantics and passes the 4 MiB churn budget.

## Executable enforcement

```sh
sha256sum -c bootstrap/sx.sha256
./sx verify-entry
./sx target test-native-bootstrap test-language-deps test-trust-anchor test-doc-claims
./sx ci-guard
./sx ci
./sx target test-driver
./sx ci-guard-check
```

CI guard creation and checking are Sayanox. Native recording shims refuse and
record make, Python/Python3, Node, Ruby, Perl, curl and wget; swallowed child
failures remain visible in the evidence marker. The isolated compiler/seed
bootstrap additionally poisons cc/gcc/clang and contains no C source. Changed
source/anchor inputs must be refused without replacing the installed compiler.

The original complete CI chain is retained; a smaller successful subset is not
substituted for it. Release still requires the full chain, entry equality,
gen3/gen4 C identity and clean tracked source. No publication is implied by
source migration, auditing or a release plan. Full-language conformance beyond
the reviewed acceptance subset remains a separate fail-closed claim.
