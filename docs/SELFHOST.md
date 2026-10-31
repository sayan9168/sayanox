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
