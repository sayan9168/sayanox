# Makefile retirement

Status (2026-10-27): **Makefile removed; all 236 original target names implemented in the Sayanox driver; complete guarded local CI and no-Make driver acceptance passed.** Registration and runtime acceptance were checked separately.

## Entry and implementation

`./sx` is the checked-in native Linux x86-64 executable built from `tools/sxbuild.sa`. It is not a shell launcher. The driver implements dispatch, prerequisites, bootstrap, recovery, testing, cleanup, audits, CI and release orchestration in Sayanox. There is no `make` fallback and no runtime reading of historical recipes. Unknown targets fail with exit 2.

The original target-name inventory is preserved in `tools/sxmigration_lib.sa`; the original contracts can be reviewed at commit `c233978e8fb2291880c968c8a11a24b78c476fb5`. Repository history is not loaded or executed by the driver. Leaf external tools such as the host C compiler, archive tools and GitHub CLI remain dependencies; the driver does not claim to implement those programs.

Implementation families:

- `sxbootstrap_lib.sa`: seed verification, compiler recovery, seed → gen1_min → gen2, native compiler fixed point (now reconstructed from the pinned Sayanox native anchor) and C-generation fixed point. `sxpack_lib.sa` shares the offline Sayanox recovery codec with the standalone packer and embeds it in root `sx`, so missing-source recovery needs no compiler/packer binary.
- `sxtargets_lib.sa` and target-name libraries: validation, dependency masks and native tool builds.
- `sxseed_gates_lib.sa`, `sxported_gates_lib.sa`, `sxmore_gates_lib.sa`, memory, package, frontend, backend, ISA and stdlib gate libraries: fixtures, assertions, diagnostic refusals and cross-backend parity in Sayanox.
- `sxaggregate_lib.sa` / `sxaggregate_targets_lib.sa`: full-seed compilation, minimum selfhosting, gen3 feature closure, sanitizer, dependency, network and native-test aggregates.
- `sxnative_acceptance_*_lib.sa`: original native acceptance body, positive fixtures, compile refusals, bounds checks and backend parity.
- `sxpattern_lib.sa`: the pattern subset required by the gates, rather than grep-based assertion orchestration. Not a general POSIX regex implementation.
- `sxlimit_lib.sa`: a small emitted Linux x86-64 kernel binding for resource limits and exec; no shell `ulimit` recipe.
- `sxnet_io_lib.sa`, `sxnet_server.sa`, `sxnet_curl.sa`, `sxnet_test.sa`: bounded native socket binding, real HTTP fixture server/client and network assertions. HTTP policy is in Sayanox; the emitted machine code is the syscall binding. No Python fixture server or skip-on-missing-Python path remains.
- `sxci_guard_lib.sa`, `sxentry_lib.sa`, `sxrelease_lib.sa`: guarded CI, entry rebuild verification and release planning/orchestration.
- `sxclean_lib.sa`: explicit generated-output allowlist; preserves sources, root `sx` and unrelated files, and refuses a directory where an output file was expected.

## Commands

```sh
sha256sum -c bootstrap/sx.sha256
./sx verify-entry
./sx migration
./sx target doctor tools
./sx target test-driver
./sx target test-seed-sanitize test-language-deps test-network
./sx target selfhost/gen1.c selfhost/gen1
./sx target true-selfhost-min gen3 native-test
./sx ci
./sx target clean-plan
```

`migration` reports **236 / 236** and exits 0. `ci` first checks target coverage, then runs doctor, CI shape, minimum selfhosting, gen3 fixed point/features and native acceptance. Individual original target names remain available. `bootstrap-gen3` performs the compiler fixed point only; `gen3` additionally runs the original smoke and feature acceptance. `clean-plan` lists paths without deleting them.

Compiler stages are cached within one invocation. Existing generated seed/gen2 binaries are not source-aware incremental builds: explicitly request `gen2` after editing compiler sources. Native tools are rebuilt from their Sayanox sources using staged output paths, without falling back to C emission after a native compilation failure.

## Trust, recovery and honest boundaries

`bootstrap/sx.sha256` contains 49 records covering root `sx` and the transitive driver/native-compiler inputs, compiler source/module, seed audit and frozen seed. Workflows verify these pins before executing the entry. `verify-entry` rebuilds the driver and compares bytes. Root `sx` and `bootstrap/sxc_native.bin` are explicit trusted bootstrap artifacts; checksums and self-rebuild parity are not an independent trust proof. See [bootstrap reconstruction](../bootstrap/README.md).

The frozen C seed remains unchanged (SHA256 `e4cc34b41041044579ee34ab05c32997f3ad45adbe88973d8403ae43a2a01cb9`). Therefore this migration does **not** justify claiming zero C, full-language selfhosting, or an independently eliminated trust anchor. `all-sayanox` and `true-selfhost-full` retain their honest refusal gates rather than falsely reporting success. Those claims are not required by the original minimum-selfhost CI chain.

The network fixture transport is deliberately private: bounded plain HTTP over IPv4 loopback, not a production replacement for curl/TLS. The frozen runtime's curl invocation resolves to the real-socket Sayanox client only inside the harness's private PATH. Native http_get remains an explicit compile refusal, as in the original acceptance contract.

The generated C collector skips ASan-poisoned conservative stack words using the sanitizer interface, keeping actual loads instrumented. The sanitizer gate includes an independently corrupted string-read negative control proving ASan still detects a real fault. Leak detection remains explicitly disabled, matching the original gate.

## Verification ledger

Previously completed families include bootstrap/native fixed point, no-Make driver integration (with a recording make poison), cleanup/entry reconstruction, package hardening, frontend/IR/language, ISA, backend modules, stdlib growth/resource limits, guarded CI failure propagation and release-plan validation. These are individual acceptance results, not a claim of remote CI success.

Latest measured results:

- Target registration: **236 / 236**, exit 0.
- Full-seed diagnostic regression: quoted `#error` data accepted; real line-leading generated directive refused; exclusive stdout temporary path compiled and ran, exit 0.
- Native acceptance body, RC/GC stress and subset: exit 0.
- Rebuilt gen2 plus ASan/UBSan: all five fixtures and active-sanitizer corruption control passed, exit 0.
- Compiler recovery bundle regenerated and byte-for-byte verified after the collector change.
- Dependency interpreter-poison checks and real-socket HTTP/crawler matrices: exit 0.
- Refreshed root entry byte parity and all 49 checksum records: exit 0.
- Cold entry-only recovery: compiler and module recovered byte-for-byte with no seed/native-compiler/packer binaries and invalid compiler overrides; corrupt compiler/module bundles refused without overwriting source sentinels. The driver regression includes this gate. Cleanup also covers the recovery harness and both native socket helpers.
- Full-seed compiler C generation and binary build: exit 0; the resulting gen1 compiler also compiled and ran the quoted-diagnostic smoke fixture. Runtime patching skips C string literals, and balanced substring copying avoids quadratic compiler-sized suffix copies.
- `target grammar test`: complete minimum-selfhost aggregate and both original markers, exit 0.
- `all-sayanox`: measured seed/build-driver lines and tracked C/H, shell and Sayanox counts, followed by the required honest exit-1 refusal. Documentation audit checks those metrics.

- Complete local `./sx ci` with the workflow's eight forbidden-tool guards: **exit 0**, including `TRUE-SELFHOST-MIN-OK`, `GEN3-OK`, `NATIVE-TEST-OK` and the final no-forbidden-invocation check.
- Refreshed `target test-driver`: **exit 0**, including no-Make integration, recording make poison, eight-tool guard refusal/evidence tests, safe cleanup, pattern predicates, resource launcher and valid/invalid release plans. Its CI negative control now injects a missing C compiler and checks prerequisite failure, rather than expecting the obsolete pending-target refusal or recursively running a second CI over shared fixtures.
- Final guarded sequential `target test-language-deps test-recovery test-doc-claims`, `./sx ci`, `target test-driver`, and guard evidence check: **exit 0** on the final shared-recovery implementation (`selfhost/seed_tests/final-guarded-ci-v3.log`).
- Final `target test-seed-sanitize test-network`, entry byte parity, all source/entry checksums, migration audit and `git diff --check`: **exit 0** after that complete guarded run.

No acceptance process remains running. No remote workflow result is asserted. No commit, push, actual release, archive publication or PR operation was requested or performed. Release validation must use guarded planning rather than invoking the publishing path.

## Follow-on all-source migration (2026-10-27)

Both compiler and minimal-seed reconstruction now use Sayanox. Stage 0,
missing-seed reconstruction and `sx bootstrap` compile the maintained Sayanox
frontend/CLI, not the legacy C source. The native anchor reproduces itself over
three generations before installation; generated-C compatibility stages remain.

The isolated native-bootstrap test also rebuilds the seed from Sayanox, with no
C source and recording cc/gcc/clang poisons. Source/anchor corruption is refused.
All 14 seed gates pass, including generics, borrowing and type refusals; the GC
memory gate passes. A new discarded-list regression proves automatic collection
and alias retention under 4 MiB, alongside the existing finite-list workload.
Six actual ASan/UBSan/stdout comparisons pass. Recovery sources are repacked and
verified byte-identical. The current native entry and integrity pins verify;
CI-shape remains green.

The native-origin own-source C pipeline now passes: native SA seed -> C1 ->
C2 == C3, including complete C1 emission under the existing 64 MiB address-space
limit. The frozen C seed and its old audit are deleted. Source/docs/release
audits now enforce the explicit native binary trust boundary instead of a C
source exception. Final complete guarded acceptance is pending; earlier full-CI
results above belong to the Makefile-retirement checkpoint, not this final
all-source run. See [native bootstrap](NATIVE_BOOTSTRAP.md) for exact evidence.
