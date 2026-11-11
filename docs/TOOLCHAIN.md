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

## Release publication

A release is cut by the gated workflow and by `/sx release` only after the
complete acceptance chain passes. Packaging is bound to a commit id, not to the
symbolic `HEAD`:

```sh
RELEASE_TAG=v0.3.30 ./sx release-identity   # check only; never packages or calls gh
```

`release-identity` resolves `HEAD` to a full 40-character commit id, refuses a
checkout that differs from `GITHUB_SHA`, refuses an existing remote tag
(`git ls-remote --tags origin refs/tags/<tag>`) that names another commit, and
fails closed when the remote cannot be read. `release` then archives that id,
creates a new tag with `--target <commit>`, only verifies a tag that already
exists, and re-reads the remote tag after publication so a moved tag fails the
run. Argument shaping and identity decisions are Sayanox in
`tools/sxrelease_identity_lib.sa`; `git` and `gh` remain leaf host boundaries.
`./sx target test-release-identity` proves the contract against a recording mock
`git`/`gh` PATH, including mismatched and moved tags. Release-plan output is a
plan, not a test of publication identity.

See [BOOTSTRAP_ROADMAP](BOOTSTRAP_ROADMAP.md) for the real chain and
[REMAINING_WORK](REMAINING_WORK.md) for open projects and external blockers.

## Developer loop: REPL, scaffolding, project tests

Two tools close the loop between writing a program and running it:

```sh
./sx target tools/sxrepl
./sx target tools/sxcli
./tools/sxrepl                     # read-eval-print loop, :help for directives
./tools/sxcli new hello demo       # scaffold Sayanox.toml, main.sa, tests/, README
./tools/sxcli test hello           # compile and run every tests/*.sa
```

Both are plain Sayanox programs over documented builtins, so they added no
language or backend surface. The REPL recompiles the whole session on each prompt
(that is what keeps earlier bindings visible) and prints only the new output; a
fragment that does not compile is refused and dropped without ending the session.
`./sx target test-sxdiag` runs their 19-case `calc` suite and the 3-case
`calc-backend` suite, which builds the same source by `gen2` -> `cc` and by the
shipped native path and requires identical answers. See
[`REPL.md`](REPL.md).
