# Native Sayanox bootstrap and entry (Linux x86-64)

`../sx` is the generated static ELF of `tools/sxbuild.sa`. It starts the
Sayanox-owned build DAG in a clean checkout without a compiler, Makefile,
shell launcher, recipe interpreter or network download. `tools/sxbuild` is a
disposable installation of that program.

```sh
sha256sum -c bootstrap/sx.sha256
./sx target native-bootstrap
./sx verify-entry
./sx target seed-min-bin
./sx target test-native-bootstrap
./sx doctor
```

## Explicit trust boundary

There are two explicit prebuilt trust inputs: generated `sx` and
`bootstrap/sxc_native.bin`. A checksum detects drift, not a malicious bootstrap
or a trusting-trust attack. Self-reproduction is not independent diverse
reconstruction. Reviewers seeking stronger assurance need another independent
implementation/toolchain; this repository does not claim that proof.

`bootstrap/native.sha256` pins the native compiler anchor and transitive Sayanox
compiler inputs. `bootstrap/sx.sha256` pins the entry and its bootstrap/source
boundary. `bootstrap/sxc_native.audit` records the binary's size and Sayanox
SHA-256 digest. All pins must be reviewed when their inputs change.

Native reconstruction compiles `tools/sxc_native.sa` through compiler 1, 2 and
3, requiring compiler 2 == compiler 3 == the anchor. Only then is the native
compiler atomically installed. `verify-entry` rebuilds `tools/sxbuild.sa` and
compares its bytes with `sx`; it never silently replaces a mismatching entry.

Stage 0 builds the compatibility seed CLI and shared C-output frontend from
Sayanox. The final frozen C seed and its audit have been deleted; no bootstrap
step restores them from history, downloads them, or executes a stored C parser.
The retained C backend emits C output and runtime templates, and later C-output
fixed-point stages legitimately invoke the external host C compiler.

`test-native-bootstrap` reconstructs both native compiler and seed in an
isolated workspace with no C source. Native recording shims for cc/gcc/clang
must remain unused. Corrupt source/anchor inputs must fail without replacing
the installed compiler. This tests behavior, not just dispatcher registration.

`clean` preserves `sx`, the anchor, pins and maintained sources, while removing
disposable compiler/tool outputs. Recovery decoding is implemented in Sayanox
and verifies the packed compiler/module source bytes. Build/test orchestration,
audits, CI guards and release logic are Sayanox; necessary host process/tool
boundaries remain explicit dependencies.

See [native bootstrap details](../docs/NATIVE_BOOTSTRAP.md) and
[all-source migration](../docs/ALL_SAYANOX_PHASE.md). Release publication is a
separate explicit operation; rebuilding/verifying this entry does not publish,
commit or push anything.
