# Conditional diverse double-compilation (DDC)

Status: **harness implemented; independent reconstruction NOT established**.
No independently implemented and independently bootstrapped Sayanox compiler
is supplied or has been tested. Do not mark the independent-trust roadmap item
complete, and do not use the harness controls as permission to claim that proof.
All maintained implementation source remains Sayanox. No historical C seed is
restored. This is separate from the already passing self-host/fixed-point gates.

## What would establish the conditional result?

Let S be the reviewed native compiler source `tools/sxc_native.sa` and its
pinned transitive sources, A the candidate `bootstrap/sxc_native.bin`, and T an
independently trusted compiler capable of compiling this Sayanox subset.

1. Independently build and review T, without executing `sx`, A, or descendants
   of either anywhere in T's build chain. T must implement the necessary source
   language correctly, including imports, numeric/byte/list behavior and Linux
   process/file operations. A renamed anchor, a wrapper around it, an alternative
   backend reached through it, or its generated C is **not** such a T.
2. Review S and the entry-driver sources for the intended behavior. DDC relates
   binaries to source under assumptions; it does not prove the source harmless,
   prove the source language specification correct, or audit a host OS.
3. Compile this verifier with T, not the repository anchor. Trust/review the
   host OS, process launcher, `sha256sum` and `cmp` as well. An anchor-built
   verifier could lie about execution and comparisons.
4. Compute B1 = T(S). Its bytes are *not* required to equal A: a different
   backend/toolchain is expected to produce different code.
5. Execute B1 to compile S, producing B2. Require B2 == A byte for byte.
6. Execute B2 on `tools/sxbuild.sa`. Require the result == `sx` byte for byte.
7. Independently inspect the evidence and repeat the final comparisons with
   trusted host tools. Keep the source snapshot and reference-tool provenance.

The source compiler's deterministic native encoder makes step 5 meaningful,
regardless of the code generator T used for B1. T must not merely invoke A as
an undocumented subcommand. Correct translation and reproducible compilation
are assumptions, not consequences of checking hashes.

## Reference-tool contract and external review

The executable interface is `T INPUT.sa OUTPUT`, from the repository root.
Supply T as a regular executable file (resolve any symlink before invocation).
It must process `use` imports and create an executable Linux x86-64 result, or
exit nonzero. No optional network fetches or fallback to repository compilers.
The reference and its dependencies must remain unchanged throughout the run.

Supply a nonempty external review document identifying:

- implementation, version, sources and review scope;
- independently obtained build toolchain, its provenance and trust roots;
- the full build chain and why it does not depend on either repository binary;
- supported Sayanox semantics, runtime dependencies and known limitations;
- the reviewed reference executable SHA-256 and source snapshot;
- reviewer/operator identity and explicit trust assumptions.

The driver records the review's hash. It **does not authenticate the reviewer**,
verify the claims inside the document or infer independence from a different
binary hash. Different bytes are not proof of independent provenance. Exact
copies of the two known repository trust inputs are rejected, including renamed
copies; this is only a circular-input control, not a complete wrapper detector.

## Run only once an acceptable reference exists

The following are a protocol, **not a completed run**. Paths named REFERENCE
and independently-built-verifier refer to external reviewed executables, not
files shipped here. A fresh evidence directory is required.

```text
REFERENCE tools/sxddc.sa independently-built-verifier
independently-built-verifier run REFERENCE REVIEWED_SHA256 REVIEW_FILE NEW_WORKDIR
```

The driver checks source/entry pins before and after execution, checks the
reference digest, refuses to overwrite evidence, and never installs a generated
compiler or replaces a trusted repository binary. It saves phase logs, the
review, manifest/reference hashes and both compiler stages. Failed or incomplete
runs must not have a `CONDITIONAL_DDC_MATCH` report. Existing failed evidence is
preserved; choose a different new directory to retry.

On success the report deliberately says `CONDITIONAL_DDC_MATCH`, not an
unqualified `TRUST-PROOF-OK`. Independently check the report's assumptions and
run the host `cmp` comparisons of `NEW_WORKDIR/stage2` with the anchor and
`NEW_WORKDIR/entry` with `sx`. Report/console output alone is not certification.
The driver is not a security sandbox: run reference tools only after approval,
with protected sources and a stable host/toolchain. It does not defend against
an attacker controlling the OS, host utilities or concurrent file replacement.

## Repository-owned controls (not a DDC run)

```sh
./sx tool sxddc
./tools/sxddc self-test
./sx target test-native-bootstrap
```

The first command uses the existing anchor, so its result is only a convenience
checker, **not an independent verifier**. The existing native-bootstrap gate
runs the same harness controls in CI. Controls cover equal/corrupted/missing
artifacts, known circular inputs, child failure, stage2 mismatch, incorrect
reference digests and refusal to overwrite existing evidence. The negative
`selfhost/ddc_tests/copy_self.sa` executable intentionally copies itself; it
must be rejected and is not a reference compiler. No success-path reconstruction
with a genuine independent T has been performed. Neither hashes, passing these
controls nor the original fixed point close the roadmap's trust requirement.

## Exit and evidence contract

- Exit 0 from `self-test`: controls passed, **no independent compiler tested**.
- Exit 0 from `run`: conditional byte matches under the reviewed assumptions.
- Exit 2: invalid invocation, rejected inputs, failed phase or mismatched output.
- `INCOMPLETE` or `FAILED` receipts: no independent reconstruction established.

There is intentionally no automatic download, permissive fallback, hidden
reference substitute, or default reference path. The current independent-trust
item remains blocked on supplying/reviewing T and executing the protocol.
