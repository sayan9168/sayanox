# Bootstrap roadmap

## Current verified path

```text
C seed-min -> gen1-min -> gen2 -> feature tests
                            \\-> gen3 -> gen4 (byte-identical fixed point)
```

Use:

```sh
make true-selfhost
make gen3
make native-test
```

The preferred self-host path compiles `selfhost/compiler_min.sa`, written in
Sayanox, into C. A host C compiler builds that generated C. The portable user
program path is therefore `.sa -> .c -> C compiler -> executable`.

For the documented native-AOT subset, `selfhost/native_aot.c` emits x86-64
Linux machine code directly. Build this bootstrap once with `make native`; it
then compiles supported `.sa` programs without invoking clang or another C
compiler for each program.

## Remaining roadmap

1. Expand the Sayanox compiler beyond the pure-min subset, preserving explicit
   diagnostics and seed-min/gen2/native behavioral tests.
2. Broaden native AOT or document unsupported language constructs precisely;
   native output remains x86-64 Linux only.
3. Add namespaced modules, a fuller standard library and improved ownership /
   memory management when the language has the necessary abstractions.
4. Extend package tooling beyond the current local registry and URL index.

## Not claimed

The full Stage-2 language is not self-hosted, the native backend is not
portable, remote package hosting is not implemented, and a clean checkout
still needs `make`, a POSIX shell and a C99 compiler to bootstrap. See
[`STATUS.md`](STATUS.md) for the feature-by-feature verified scope and
[`COMPLETE.md`](COMPLETE.md) for the current milestone summary.
