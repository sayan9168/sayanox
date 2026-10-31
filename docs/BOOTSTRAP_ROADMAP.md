# Bootstrap roadmap

## Current verified path

The maintained compiler, bootstrap, runtimes and driver are Sayanox. The frozen
C seed and Makefile are retired. A clean checkout starts from the pinned Linux
x86-64 native anchor; that binary remains an explicit trust input.

```text
bootstrap/sxc_native.bin -> source-built native compiler (anchor equality)
                        -> Sayanox C-output frontend + Sayanox seed CLI
                        -> generated C gen1-min -> gen2 -> gen3 -> gen4
                                                        (gen3.c == gen4.c)
```

The compiler implementation uses a bounded bootstrap dialect. Accepted user
programs are **not** narrowed to that implementation dialect: published-language
v1 C-output self-hosting is accepted. See the normative
[profile](FULL_LANGUAGE_PROFILE_V1.md), [contract](FULL_LANGUAGE_CONTRACT_V1.md)
and checkpoint-specific [STATUS](STATUS.md).

```sh
./sx verify-entry
./sx target test-native-bootstrap
./sx target true-selfhost
./sx target gen3
./sx target true-selfhost-full
./sx ci
```

`true-selfhost` checks the pure-min chain; `gen3` requires byte-identical
compiler output; `true-selfhost-full` additionally requires the pinned published
inventory, gen2/gen3 O0/O2 executions, builtin and runtime-boundary matrices,
negative controls and integrity rechecks. A dispatcher or successful C emission
alone is not acceptance. `./sx ci` retains the complete original hard gates.

## C-output compatibility and native output

The portable user-program path remains `.sa -> generated .c -> host C compiler
-> executable`. Host tools and generated C are allowed; they are not maintained
C compiler source. Stage-zero native reconstruction does not require a C seed
or C compiler. See [NATIVE_BOOTSTRAP](NATIVE_BOOTSTRAP.md) for the exact boundary.

`selfhost/native_aot.sa` emits the documented x86-64 Linux native subset.
`tools/native32.sa` emits the narrower i386/AArch64/RV64IM integer/string subset,
including literal byte lengths. ARM64/RV64 execution under the Sayanox emulator
is not full ISA, full-language native support or real-hardware validation.
See [NATIVE](NATIVE.md) and [NATIVE32](NATIVE32.md).

## Remaining work, not completed bootstrap prerequisites

The [remaining-work register](REMAINING_WORK.md) separates implemented work,
acceptance still required, design work and external blockers. In particular:

- Independent diverse reconstruction still needs a reviewed independent
  reference compiler and genuine DDC execution; hashes and fixed points do not
  establish source trust. See [DIVERSE_BOOTSTRAP](DIVERSE_BOOTSTRAP.md).
- Full native parity, precise GC/explicit memory contracts, IDE-complete LSP,
  language-level module identity, deeper stdlib/package infrastructure and
  broader platform coverage remain separate projects.
- Future syntax/type proposals are not missing clauses of the already accepted
  published-language v1 contract. Unsupported forms must keep clear refusals.
- Necessary host tools remain dependencies; all-maintained-Sayanox is not a
  promise to eliminate host utilities, generated C or binary trust inputs.
