# Self-host and compiler CLI

The supported driver is the native Sayanox entry `./sx`. Run commands from the
repository root on Linux x86-64. A host C compiler builds generated C output;
no maintained C seed or Makefile is required.

```sh
./sx target true-selfhost
./sx target gen3
./sx target true-selfhost-full
```

The first target checks the pure-min implementation chain; the second requires
gen3/gen4 byte identity; the third checks the complete pinned published-language
v1 C-output profile. Published user programs are not narrowed to pure-min.

## Compile a program through the C-output backend

```sh
./selfhost/gen2 examples/hello.sa /tmp/hello.c
cc -std=gnu99 -O2 -o /tmp/hello /tmp/hello.c
/tmp/hello
```

Use explicit input/output paths. `selfhost/compiler_min.sa` is the maintained
C-output compiler source. Supported syntax, builtin signatures and documented
refusals are defined by [FULL_LANGUAGE_PROFILE_V1](FULL_LANGUAGE_PROFILE_V1.md),
[SYNTAX](SYNTAX.md) and [BUILTINS](BUILTINS.md).

## Native output and trust boundaries

```sh
./sx target native
./selfhost/native_aot examples/hello.sa /tmp/hello-native
/tmp/hello-native
```

Native AOT has its own [supported subset](NATIVE.md); C-output acceptance does
not imply every native backend implements the full language. The multi-ISA
subset is documented separately in [NATIVE32](NATIVE32.md).

The [native bootstrap](NATIVE_BOOTSTRAP.md) starts from an explicit pinned
binary anchor. Self-reproduction and gen3/gen4 equality are determinism checks,
not independent trust proof. See [DIVERSE_BOOTSTRAP](DIVERSE_BOOTSTRAP.md) and
the [remaining-work register](REMAINING_WORK.md).

## Native AOT Debugging Guide (R02/R19)

When debugging `./sx target native` failures or compiler bugs (e.g., `sx_index`
bounds, `concat` data image mismatches):

1. **Verify Seed Integrity**: Run `./sx target test-full-language-readiness` or
   `./sx target test-stdlib-next` to ensure `[OK] verify-seed` and component
   integrity checks pass.
2. **Inspect Logs**: Check `/tmp/test_out*.txt` or process logs for seed
   verification and component integrity (`bootstrap/sxc_native.bin: OK`,
   `tools/sxc_native.sa: OK`, etc.).
3. **Trace Native AOT**: Use `./sx target native --debug` (if available) or
   inspect `selfhost/native_aot.sa` for `sx_index` or `concat` data image mismatches.
4. **CI/CD Integration**: Documentation previews are published by the separate
   `.github/workflows/docs.yml` workflow, never from a `ci.yml` job:
   `./sx ci-guard` replaces `node`, `curl` and `npx` with failing shims for
   every later step, so a deployment step inside an armed job would trip the
   guard. See [CI](CI.md).

See [REMAINING_WORK.md](REMAINING_WORK.md) for the current increment log and
[STATUS.md](STATUS.md) for the 2026-11-12 decimal negative controls update.

