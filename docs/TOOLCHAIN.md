# Toolchain — Sayanox implementation and explicit host boundaries

The compiler, runtimes/backends, bootstrap/build driver, package/LSP tools,
audits, tests and release orchestration are maintained in Sayanox. There is no
maintained Makefile, C seed or shell script. Necessary host tools, generated C
compatibility output and the pinned native binary trust inputs remain explicit.

## Supported commands

Run from a Linux x86-64 checkout:

```sh
./sx verify-entry
./sx target gen2
./selfhost/gen2 examples/hello.sa /tmp/hello.c
cc -std=gnu99 -O2 -o /tmp/hello /tmp/hello.c
/tmp/hello
./sx target native
./selfhost/native_aot examples/hello.sa /tmp/hello-native
/tmp/hello-native
```

`selfhost/compiler_min.sa` owns C-output compilation;
`selfhost/native_aot.sa` owns the documented x86-64 native subset.
`tools/native32.sa` emits the narrower i386/AArch64/RV64IM subset directly.
No deleted Stage-2 host or restore script is a supported entry point.

## Acceptance is separate from building

```sh
./sx target test-doc-claims
./sx target all-sayanox
./sx target true-selfhost
./sx target gen3
./sx target true-selfhost-full
./sx ci
```

Pure-min bootstrap and fixed-point checks do not alone establish full-language
acceptance or independent source trust. Published-language v1 C-output
self-hosting is accepted at the checkpoints in [STATUS](STATUS.md). Native
backend coverage remains separately bounded in [NATIVE](NATIVE.md) and
[NATIVE32](NATIVE32.md). All-source inventory is an audit, not a conformance test.

See [BOOTSTRAP_ROADMAP](BOOTSTRAP_ROADMAP.md) for the real chain and
[REMAINING_WORK](REMAINING_WORK.md) for open projects and external blockers.
