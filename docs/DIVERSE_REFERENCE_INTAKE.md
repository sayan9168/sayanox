# Independent reference intake — work started 2026-10-30

Status: **reference/provenance audit started; independent proof NOT established**.
This work began only after documentation closure PR #49 was merged, with both
required PR CI jobs green. It is not a replacement for the
[DDC protocol](DIVERSE_BOOTSTRAP.md).

## Initial findings

- The repository contains the conditional verifier `tools/sxddc.sa` and the
  deliberately invalid `selfhost/ddc_tests/copy_self.sa`, not an independently
  implemented and independently bootstrapped reference compiler.
- GitHub repository search on 2026-10-30 did not identify an acceptable external
  compiler. Queries `sayanox compiler fork:true` and
  `sayanox compiler -user:sayan9168` returned no results. A broader `sayanox`
  search found this project and unrelated projects, not a reviewed reference.
  These bounded searches are discovery only: they do not prove no reference
  exists, discover private tools, or certify any implementation's provenance.
- `./sx tool sxddc && ./tools/sxddc self-test` exited 0. Its output explicitly
  says **NO independent compiler tested**. The verifier used here was built
  with the repository anchor; these are controls, not an independent DDC run.
- No reference was downloaded/executed and no success receipt was fabricated.

## Identities under review — NOT independent trust evidence

At this checkpoint:

```text
7ce90160ed28b125e4d4197a38072b35682c800d5d1fa4764afddeed9c45b698  bootstrap/native.sha256
10272e8717ab0e0296ee72c9240568e56a078bbc9bd8c748946f88795ef60997  bootstrap/sxc_native.bin
ae46a00296f025edc8617f3435e41efa21d83d91a495166f50225cbf709c218f  sx
6ccb238ddb620c27e5dc7e86577d34b39bc66c795de536c26ab455dfde4e97ad  tools/sxddc.sa
```

These hashes identify the candidate and verifier sources. They do not prove
independence, correctness or absence of a trusting-trust attack.

## Required next input: candidate T and reviewable provenance

Do not proceed to a claimed independent run until the following are available:

1. A regular executable reference compiler **T**, with source repository,
   immutable source revision and complete build instructions.
2. The full build/dependency chain, including the origin of every executable
   used to build T. No step may execute `sx`, the candidate native anchor, a
   descendant of either, or their generated output as a hidden compiler.
3. Independently obtained/reviewed toolchain and its explicit trust roots.
   Host `cc` alone is not T: it does not implement Sayanox syntax/semantics.
4. A reviewed executable digest and a nonempty, honestly attributed external
   review covering language semantics, known limits, dependencies and build
   provenance. The harness cannot authenticate a reviewer or establish these
   claims by reading a document.
5. Approval to execute that candidate in a protected, stable environment.
   The verifier is not a sandbox.

Renaming an anchor, using gen2/gen3 produced by the native-origin chain,
changing its backend, wrapping it in another executable, or finding a fork
with different binary bytes does not supply independence.

## Required compilation capability

T must compile the pinned `tools/sxc_native.sa` and its nine transitive Sayanox
libraries from `bootstrap/native.sha256`; the manifest also contains the
candidate binary, which is not a source library. The current compiler front
end uses `use` imports, typed functions, numeric/string/list behavior, source
parsing and byte processing, and Linux file/process operations. Capability
must be established by tests and actual compilation, not inferred from a tool
name or source-language claim.

T must also compile `tools/sxddc.sa` and its required language/runtime features
so the verifier can be rebuilt without the repository anchor. The verifier
and reviewed native source must not change mid-run. Partial source acceptance
is not permission to narrow the candidate source or the published language.

## Execution and acceptance sequence after intake

1. Review the candidate T, its complete build chain and the native/entry source.
2. Build T independently and independently compile the verifier with T.
3. Under that verifier, produce B1 = T(native compiler source).
4. Execute B1 on the same source to obtain B2; require B2 byte-equal to the
   candidate native anchor. B1 need not have the anchor's bytes.
5. Use B2 to compile the entry source; require equality with `sx`.
6. Inspect all preserved logs, source/reference hashes and the review; repeat
   comparisons with independently trusted host tools.
7. Record only a **conditional** result under the explicit review/toolchain/OS
   assumptions. A failed phase, missing artifact or unreviewed provenance keeps
   the independent-trust item open.

If no candidate can be supplied, the next engineering step is a separately
reviewed independent reference implementation and bootstrap design. It must
explain how its first executable is built without this anchor. No new maintained
C seed, Python/Node dependency, automatic network bootstrap or other exception
to the repository's all-Sayanox policy is silently authorized by this intake.
Choosing such a route requires an explicit trust-boundary/scope decision;
writing a second compiler in Sayanox and compiling it with this anchor alone
would still be circular.
