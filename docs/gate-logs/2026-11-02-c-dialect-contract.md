# Gate log — 2026-11-02 — CI image moved to gcc 15: pin the C dialect

## How it was found

The first push of the `chr(<expression>)` increment failed both CI jobs on
`test-gen2-boolean-args` (surfaced as `target failed: test-typed-sig`) while the
same commit passed locally, in a pristine clone and in a shallow clone. GitHub's
job logs are not reachable from this sandbox (the signed log URL points at
`*.blob.core.windows.net`, outside the allowed hosts), so a temporary workflow
step re-ran the failing target with `set +e` and printed its output as
`::error::` annotations, which are reachable through the check-runs API:

```
DIAG cc=cc (Ubuntu 15.2.0-16ubuntu1) 15.2.0 cpus=4
DIAG retry exit=1
DIAGF 7:selfhost/seed_tests/g2b.c:300:25: error: expected identifier or '(' before 'true'
DIAGF 10:selfhost/seed_tests/g2b.c:300:38: error: expected identifier or '(' before 'false'
DIAGF 25:selfhost/seed_tests/g2b.c:341:32: error: expected identifier before 'true'
DIAGF 28:selfhost/seed_tests/g2b.c:342:32: error: expected identifier before 'false'
DIAGF 31:[FAIL] C compilation failed for selfhost/seed_tests/g2b.c
DIAGT selfhost/seed_tests/g2b.c:340:30: warning: excess elements in struct initializer
```

The temporary step was removed again; the workflow file is identical to `main`.

## Root cause

`selfhost/gen2_boolean_args_test.sa` uses `true`/`false` as identifiers:

```
struct Flags { true, false }
hold flags = Flags { true: 4, false: 5 }
```

The C backend writes identifiers verbatim, so the emitted C contains
`typedef struct { double true; double false; } Flags;`. That is legal in C11 and
C17, but gcc 15 defaults to `-std=gnu23`, where `true` and `false` are keywords.
Nothing in the repository had stated which dialect the emitted C targets.

## The change

Generated C is now compiled as C11 by the gates. Every gate-side compile of
generated C passes `-std=gnu11` (following `tools/sxbootstrap_lib.sa`, which
already pinned `-std=gnu99`):

- `tools/sxgate_lib.sa` (`gl_compile_c`, the helper most gates use),
- `tools/sxbuild.sa` (bootstrap stage compiles and the `compile_sa_via_c` path),
- `tools/sxparity_gates_lib.sa`, `tools/sxgc_pool_lib.sa`,
  `tools/sxaggregate_lib.sa`, `tools/sxisa_gates_lib.sa`,
  `tools/sxlast_language_gates_lib.sa`, `tools/sxstage2_parity.sa`,
  `tools/sxnet_test.sa`, `tools/sxpkg_pubkey_test.sa`,
- `tools/sxsuite.sa` and `tools/sxirexec.sa` compiles that had no dialect flag.

`-std=c11` sites elsewhere (`tools/sxfull.sa`, most of `tools/sxsuite.sa`) were
already immune and were left alone.

No compiler output changed: the emitted C, every golden and every pinned i386
image size are untouched.

## What is still open (recorded, not papered over)

Emitted identifiers are not C23-clean. A program that names a field, local,
parameter or function `true`, `false` or `bool` still cannot be compiled with a
C23-default compiler. Closing that needs identifier mangling in every C emitter
plus a gate that compiles the emitted C under both dialects: register item R17.

## Verification

Local (gcc 12.2.0, which cannot reproduce the C23 reinterpretation):

```
$ ./sx target test-sxbuild
[OK] sxbuild target: test-sxbuild          -> 0
```

The real oracle is the gcc 15.2.0 CI image, and both jobs pass on it:

| job | result | duration |
| --- | --- | --- |
| Complete original acceptance (`./sx ci` on the runner) | **pass** | 51m06s |
| Sayanox entry and migrated acceptance gates (`doctor test-driver` + the migrated acceptance executables) | **pass** | 29m30s |

The same two jobs had failed on the identical tree before the pin, at 7m28s and
6m32s inside `test-gen2-boolean-args`.

The complete local chain on gcc 12.2.0 also passes with the new flags:

```
$ ./sx ci
[OK] complete original CI acceptance chain and published-language v1 full acceptance
=== TRUE-SELFHOST-FULL-V1-OK ===
CI EXIT 0        (569 [OK] lines, 0 [FAIL])
```
