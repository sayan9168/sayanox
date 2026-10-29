# Published-language self-host contract v1.0

Implementation review: 2026-10-29. Scope: the user's selected **currently
published language**, not future proposals. The normative rules are in
[FULL_LANGUAGE_PROFILE_V1.md](FULL_LANGUAGE_PROFILE_V1.md); the review and
conflict resolutions are in [FULL_LANGUAGE_REVIEW_V1.md](FULL_LANGUAGE_REVIEW_V1.md).
**Execution status is separate and is recorded in STATUS.md. A reviewed contract
or a registered command is not a successful acceptance run.**

## Target and trust boundary

The target is the Sayanox-written C-output compiler on maintained x86-64 Linux,
compiled from the pinned native Sayanox anchor and subsequently from its own
source. Its implementation remains in the pure-min intersection. Accepted user
programs are not narrowed to that implementation subset. Generated C, C11 cc,
POSIX process tools, coreutils timeout and digest verification are explicit host dependencies.
No Makefile, C seed, Python/Node test implementation or remote network bootstrap
is introduced. Native backend profiles, future ARM/RV completeness, module
namespaces and independent diverse bootstrap remain separate work.

## Independent inventories and evidence

- `FULL_LANGUAGE_CASES_V1.tsv`: **19 stable clause IDs**, with executable gates
  and source-anchored positive, invalid and boundary references. These cover
  tokens, arithmetic/types/scope, control/iteration/functions, lists, structs,
  generics, strings/interpolation, expression contexts, imports, all builtins,
  GC and bootstrap/runtime obligations.
- `FULL_LANGUAGE_BUILTINS_V1.tsv`: **43 canonical published calls**, with
  parameter/result kinds and runtime references. No invented `index` spelling
  is counted; the published byte API is `sx_index`.
- `tools/sxfull.sa` contains independent required ID sets, reference validation,
  required pin coverage and execution-key validation. Missing/duplicate IDs,
  missing sources/anchors/oracles and unprotected artifacts are failures.
- `docs/full-language-v1.sha256` binds the reviewed specification, inventories,
  compiler, gate implementations, fixtures and stdout oracles. Updating the
  manifest is a review action, not a way to bless a failing program.

## Executable gate

Run `./sx target true-selfhost-full`. Its Sayanox driver:

1. Clears optional compiler selectors if set; verifies pins and inventories.
2. Requires minimum acceptance and fresh source-built gen3/gen4 equality.
3. Executes the union of every clause's named gates, including the 64 MiB
   bootstrap budget, native-origin reconstruction and cold recovery.
4. Runs **19 closure/context programs** at O0/O2 on gen2/gen3, plus **34 invalid
   programs** under strict C builds. The exact **212 execution/refusal keys**
   (76 positive executions + 136 refused C builds) must be present exactly once.
5. Compiles valid counterparts for all 43 APIs and every incompatible argument
   kind/position and missing/extra arity: currently **184 valid C builds and 944 checked
   C refusals**, across both generations and optimizations. These compilation
   counts are not mislabeled as runtime executions.
6. Executes checked numeric, process/stream/file and HTTP failure/body boundaries;
   tests eight import splices, the ninth, cycles and invalid import paths.
   The HTTP stand-in is compiled from Sayanox, independently checked, and must
   leave an invocation marker. Separate loopback tests exercise real HTTP policy.
7. Runs negative controls for omitted/duplicated IDs and executions, missing
   case references, invalid signature kinds, omitted oracle protection, changed
   oracles and corrupted digests. Rechecks integrity after execution.

Only that complete successful path prints `TRUE-SELFHOST-FULL-V1-OK`.
`./sx ci` retains all original mandatory acceptance and also requires this
profile gate. No continue-on-error or reduced-selector shortcut earns a pass.

## Completion record

The five-item task additionally requires final-checkpoint **guarded local CI and
remote CI**, recorded with the exact source/checkpoint, fixed-point digest and
real exit statuses. The local profile marker alone is not a remote CI result or
an independent bootstrap trust proof. Do not reuse earlier green releases as
acceptance of this source. See STATUS.md for actual progress and failures.

A changed published contract needs a reviewed profile/inventory/oracle change
and fresh acceptance. A refused documented valid program is a regression, not
permission to remove that form from the inventory.
