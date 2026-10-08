# Sayanox project status

This file summarizes the current supported milestone. The verified feature
matrix and precise limitations live in [`STATUS.md`](STATUS.md), which is the
source of truth for compiler behavior.

## Verified and complete for this milestone

- **Reproducible pure-min bootstrap:** `make true-selfhost` builds seed-min,
  gen1-min and gen2, then runs the shared-dialect feature tests.
- **Fixed-point rebuild:** `make gen3` verifies that gen3 and gen4 generate
  byte-identical compiler output.
- **Portable C backend:** the self-hosted compiler emits C for the documented
  pure-min dialect; generated user programs are built with a host C compiler.
- **Native AOT subset:** `selfhost/native_aot.c` emits x86-64 Linux machine
  code for the subset documented in `STATUS.md`. A C compiler is needed to
  build the bootstrap binary, but not to compile or run a program after that.
- **Regression and environment checks:** `make doctor`, `make true-selfhost`,
  `make gen3`, and `make native-test` are run by CI on a clean checkout.
- **Numeric consistency fixes:** integer-only arithmetic is evaluated as
  double across all three backends, and `%` by zero reports the same
  non-zero-exit `division by zero` diagnostic everywhere.

## Not complete / explicit boundaries

- The self-hosted compiler is **not** a full Stage-2 compiler. It implements
  the pure-min subset, not every Sayanox experiment or demo in the repository.
- Native AOT output is x86-64 Linux only; the portable path emits C and still
  requires a C compiler to build the resulting program.
- String-plus-number and bare function/builtin-call statements are rejected by
  all three backends (`make test-native-num`, `make test-push-stmt`); the
  remaining native differences are `hold` inside a function body, the missing
  collector and the full-language statements (STATUS.md, "Measured
  divergences").
- Namespaced/versioned modules, a full standard library and remote package
  hosting are not implemented as part of this milestone; `use "file.sa"` is a
  textual splice, `stdlib/tiny.sa` is seven numeric helpers and the
  `.sayanox/registry` written by `sxpkg` is a local convention (`make
  test-pkgs`), not a resolver. Garbage collection
  arrived with the gen2 collector ([`GC.md`](GC.md)) and generic functions
  monomorphise the single-type-parameter form ([`SYNTAX.md`](SYNTAX.md)).

Run the verified checks with:

```sh
make doctor
make true-selfhost
make gen3
make native-test
```
