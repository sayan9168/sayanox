# Native Sayanox bootstrap — 2026-10-27

## Scope and current status

The selected goal is **all maintained source in Sayanox**, retaining compiler C-output compatibility and its tests. Necessary host tools remain external dependencies; generated C output is allowed. A native binary anchor is an explicitly accepted trust input, **not** an independent source-trust proof.

The native compiler and minimal-seed bootstrap implementations now use Sayanox.
`seed-min-bin`, missing-seed reconstruction and `sx bootstrap` no longer compile
any maintained C source. The frozen C seed and old C audit have been deleted
following the native-origin own-source proof below. Final guarded acceptance
is pending; source retirement is not being substituted for that full run.

## Native compiler reconstruction

```sh
sha256sum -c bootstrap/sx.sha256
./sx target native-bootstrap
./sx target test-native-bootstrap
./sx verify-entry
```

`native-bootstrap` and `sxc-native` use `tools/sxnative_bootstrap_lib.sa`:

1. Verify `bootstrap/native.sha256`, covering the anchor and its transitive Sayanox compiler sources.
2. `bootstrap/sxc_native.bin` builds native compiler 1 from `tools/sxc_native.sa`.
3. Compiler 1 builds compiler 2; compiler 2 builds compiler 3.
4. Require compiler 2 == compiler 3 == the pinned anchor.
5. Atomically install `tools/sxc_native` only after verification.

No C compiler, libc linker, or C seed is used. The anchor is a static Linux x86-64 ELF. Cleanup preserves it. Self-reproduction and hashes detect drift, not trusting-trust attacks; stronger assurance requires independent/diverse reconstruction and review.

## Minimal-seed reconstruction

`tools/sxbootstrap_lib.sa` implements stage 0 as:

1. Verify the Sayanox seed inputs and recover compiler sources if necessary.
2. Reconstruct the native compiler through the verified path above.
3. Compile `selfhost/compiler_min.sa` to the native `selfhost/native_c_emitter`.
4. Compile `selfhost/seed/sxc_seed_min.sa` to the native seed CLI.
5. Atomically publish both executables.

The shared frontend owns parsing, type checking, generic specialization and C lowering. The CLI selects the compatibility/runtime profile; it does not embed a stored C compiler or an old shell recipe. `seed_runtime_lib.sa` contains emitted C runtime templates, as required by the retained C backend.

Stages 1, 2 and 4 retain generated-C compilation and fixed-point checks. Those host C invocations compile **output**, not maintained C bootstrap source. The explicit `SXBUILD_VIA_C=1` tool route also remains supported. Necessary shell/process-launch and host-tool dependencies are not claimed to be Sayanox implementations.

## Collector and compatibility evidence

The seed runtime uses a single exact-membership hash registry for strings, list headers and backing buffers. Conservative stack roots retain aliases; marked list/data payloads are traced transitively, once per collection, including cycles. No assignment frees a borrowed alias. Registry identities are removed with dead allocations; `len` does not scan a permanent list registry. ASan-poisoned stack words are checked before actual instrumented loads; there is no blanket no-sanitize annotation.

Latest local checks:

- All 14 seed compatibility gates pass after canonical-source and environment-lookup fixes.
- `test-seed-gc` passes, including the existing memory, collector and finite-list gates.
- A new discarded-list workload retains a borrowed alias across 150,000 iterations and automatic collections within **4 MiB**; it is part of `test-seed-list-budget`.
- Six actual ASan + UBSan runs pass with stdout comparison: borrow, borrow stress, finite list budget, string collector churn, builder registry and discarded-list churn. Leak detection is explicitly disabled for the conservative runtime; address/undefined-behavior failures halt execution.
- Recovery packing/restoration verifies byte-identical compiler/module sources.
- Native entry rebuild matches the checked-in `sx`; root/native integrity manifests verify.

`test-native-bootstrap` now proves **both** compiler and seed reconstruction in an isolated workspace with no C source. Recording native shims for `cc`, `gcc`, and `clang` exit 99 if invoked. The test passes without invoking them; source/anchor corruption is refused without replacing the installed native compiler.

## Own-source proof and remaining acceptance

The canonical native-origin chain passes: native Sayanox seed -> C1 -> C2 ->
byte-identical C3. C1's full own-source emission also passes under the existing
64 MiB address-space bound. A separate C-derived diagnostic chain reproduced
canonical C output earlier; it is not used as native source-trust evidence.

C-output self-compilation exposed scratch declarations whose C block scope
differed from native function-wide bindings; these are predeclared, and inline
`give` closures are formatted for the default C frontend. Seed checking retains
runtime-builtin aliases with their actual argument/return kinds. Direct encoded
environment lookup avoids copying entire declaration tables. A compact six-byte
numeric source view preserves exact bytes on native integers and C doubles;
source splices refresh that view. Whole-source rewrites for list returns,
else-if and iteration calls now use balanced slicing instead of quadratic
single-character concatenation.

The old C exception has been replaced in the source/docs/release audits by the
explicit native binary trust input. The final full guarded CI/driver acceptance
run is still required; it must not be replaced with target registration or a
smaller subset of successful tests.
