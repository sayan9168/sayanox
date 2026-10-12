# Verification logs — latest run 2026-10-12

Final commands, in order, each exited 0:

1. `make doctor` → `make-doctor.log`
2. `make true-selfhost` → `make-true-selfhost-min.log`
3. `make gen3` → `make-gen3.log` (byte-identical gen3/gen4)
4. `make native-test` → `make-native-test.log`

`feature-verification.log` records the additional final run of:
`test-lsp test-lsp-robust test-generics test-native-generics test-native-strgen
 test-native-listgen test-native-locals test-logic-value test-native-lang`.
These are real command outputs; no lines have been replaced with fabricated
PASS messages. Native was already built for this final bootstrap run.

The shorter filenames `gen3.log`, `native-test.log`, `true-selfhost.log` are
historical files, not the logs of this pass. Use the `make-*` files above.

During development two gate runs failed on test expectations: the old seed
continue rejection, and the intentional OOM program after assert-out began
checking exit status. The former is now a positive exact-output test; the
latter explicitly checks a failing status, retained stdout and OOM stderr.
Both were followed by successful complete four-target reruns.

## Continuation: assignment, hold types and LSP Unicode

The four `make-*` logs were regenerated again after the continuation's final
edge-case fixes; all four commands exited 0. `continuation-features.log` is
the successful combined run of `test-seed-assignment test-seed-hold-types
 test-lsp test-lsp-robust` before that final gate run.

`seed-assignment-asan.log` is the actual stdout of the seed-generated
underscore/runtime-prefix self-assignment fixture, compiled with
`cc -O1 -g -fsanitize=address` and executed with
`ASAN_OPTIONS=detect_leaks=0`. Exit status was 0, with no ASan diagnostic.
This is a targeted memory-safety probe, not a leak-free-runtime claim or a
new bootstrap dependency.

Development failures were not treated as passes: the first annotation parity
fixture referenced a gen2 block-local outside its scope; the initial Unicode
helpers used inline give syntax and nested list indexing unsupported by gen2;
and gen2 rejected leading-underscore identifiers. The success fixture was
restricted to the shared scope/syntax, helper expressions were split into
supported statements, and the underscore memory regression is explicitly a
seed-only test. The final logs above reflect the corrected tests and code.

## Literal-iteration increment (2026-10-12)

All four `make-*` logs were regenerated after seed literal-for support was
added. Each command exited 0; gen3/gen4 remained byte-identical. Both
`make-true-selfhost-min.log` and `make-native-test.log` include the new
`test-seed-for-literals` checks (including the native leg in this workspace).
The standalone successful feature run is in `seed-for-literals.log`.
Literal sources are evaluated once per loop entry; this log does not claim
range/call-source/function-local iteration or seed generic support.

## Numeric-range increment (2026-10-12)

The four `make-*` logs were regenerated after numeric ranges were added to
seed-min; all four commands exited 0. `seed-for-range.log` contains the
successful targeted range/limit run. The range test is also part of
`test-stage2`, so the true-selfhost and native-test logs contain it.

An initial native parity attempt failed: native snapshots the upper bound,
whereas seed/gen2 re-evaluate it. The final test explicitly asserts separate
native output (the original limit of 7 and list length of 3 remain in effect),
not equality. Native source was not changed. Counters in the shared fixture
are predeclared so native also permits reading their post-loop values.
The old fixed-bound `native_lang_test.sa` now also runs with exact-output
assertions under seed-min. See STATUS for the remaining range limitations.

## Call-source / producer increment (2026-10-12)

The four `make-*` logs were regenerated after checked builtin call sources,
zero-argument typed producers, signature/prototype registration and the
argument/lowering size guards landed. All four commands exited 0, including
the byte-identical gen3/gen4 check. `seed-for-calls.log` is the successful
targeted `make test-seed-for-calls` run; native was built for that run.

The shared fixture passes seed/gen2 exact-output assertions and native
comparison. The first development version exposed gen2 limitations on typed
forward calls, direct list-literal give, and a list literal nested directly
inside push; it did not compile and was not counted as a pass. The shared
fixture now uses declaration order and named lists. The seed-only forward
fixture separately checks its new prototypes, literal list return, and braces
inside comments. Parameterized typed functions and control-flow producer
bodies remain explicitly unsupported on seed-min.

## 2026-10-12 — seed fully typed functions

Canonical doctor / true-selfhost-min / gen3 / native-test logs above now come
from the fully typed-function increment. All four exited 0 after the final
nested-argument validation change. `seed-typed-functions.log` records the
focused typed functions/signatures, Stage-2 and stdlib run (exit 0).
The new regression is also a dependency of test-stage2/test-typed-sig.

Typed num/str/list parameters, alias-safe string mutation, list references,
control flow, recursion, scoped/annotated locals and function-local for are
seed/gen2-tested. A seed-only fixture covers sibling-block binding reuse,
forward typed calls and boolean literal arguments (known gen2 lowering gaps).
Native string-parameter reassignment and function-local for remain unsupported;
these extended fixtures do not claim native parity. The existing numeric typed
signature and str/list/file stdlib fixtures still check supported native output.

## 2026-10-12 — native parameter reassignment, then live range bounds

Both increments separately passed doctor, true-selfhost, gen3 and native-test.
Canonical four-gate logs now record the final live-range increment (all exit
0; gen3/gen4 byte-identical). Focused successful runs are preserved in
native-param-reassign.log and native-range-live.log. The range regression now
compares one expected output across seed/gen2/native; upper-bound user calls
are native-only tests because seed/gen2 reject that syntax. Native list
alias behavior across capacity growth and function-local for remain gaps.

## 2026-10-12 — native function loops/list identity; seed and native generics

Four areas each passed doctor, true-selfhost, gen3 and native-test before
continuing: native frame-local for; GC-traced list growth forwarding; seed
function specialization; native annotated locals/demand-driven generic bodies.
The four canonical gate logs now record the final combined state (exit 0,
gen3/gen4 byte-identical). Focused logs:

* native-for-functions.log — recursive range/list/string loops, explicit GC,
  parameter binders, early returns and collision-safe hidden state.
* native-list-alias.log — aliases through repeated growth, parameters,
  rebinding, GC and reclaimed-block reuse.
* seed-generics.log — checked/deduplicated num/str/list instantiations,
  multiple type variables, recursive/forward calls, deterministic C and limits.
* native-generic-local.log — hold annotations, bound generic locals,
  string-only generic recursion, on-demand numeric bases and kind errors.

Extended generic tests are seed/native, not gen2 parity: the extended fixture
still exposes a gen2 nested-specialization error. Generic structs are not
implemented. See GENERICS.md and STATUS.md for the exact supported boundary.

## 2026-10-12 — gen2 typed prototypes, function scope, booleans, generic queue

Four areas each passed all four mandatory gates. Canonical gate logs now
record the final combined state. gen2-increment-gates.log contains actual
log tails from each area's four runs; focused logs are gen2-forward.log,
gen2-scope.log, gen2-bool.log and gen2-nested.log. Offline source/bundle
round-trip verification is recorded in gen2-offline-pack.log.

The formerly crashing extended generic fixture now passes gen2 too. Shared
forward/boolean fixtures match seed/native; the different-kind sibling-scope
fixture only asserts seed/gen2 behavior. A comparison-argument case is
separate from native parity. Generic structs and broad list-expression/type
analysis work remain unfinished; see STATUS.md.

## 2026-10-12 — gen2 list expressions and caller-frame GC anchor

Direct complete list-literal returns, inline numeric-literal list arguments,
and the subsequently discovered -O0 GC anchor defect were separately tested
and gated. Canonical gate logs now record the final combined state (all exit
0; gen3/gen4 byte-identical). gen2-list-and-gc.log contains the final focused
run; gen2-list-gates.log preserves actual tails from each area's four gates.
The refreshed offline bundle/source round trip is in gen2-offline-pack.log.

The extra -O0 compiler initially produced corrupted output. After the anchor
fix its output matches the -O2 compiler, and generated -O0/-O2 programs both
pass 2,000 explicit collections with live string/list/function roots. No
all-toolchain/LTO GC guarantee is claimed. Inline expression-list elements
still need a named hold; generic structs remain unimplemented.

## 2026-10-12 — gen2 inline list constant arithmetic

The next bounded extension adds + - * /, unary signs and parentheses to
numeric inline-list elements. gen2-list-arithmetic.log is the successful
focused run (including the expanded invalid-list suite).
gen2-list-arithmetic-gates.log contains actual tails from all four subsequent
gates, each exit 0. Canonical gate logs and gen2-offline-pack.log now correspond
to this newer source; gen3/gen4 are byte-identical. Compiler SHA-256:
f33bf80644ae6ccafd24fd8cbf1023e67170ffcfc85b2dbcaa48e3002321537c.
Names/calls inside inline lists, generic structs and complete static analysis
are still not implemented.

## 2026-10-12 — structural return paths

return-paths.log records the successful three-frontend focused run, including
positive parity and rejected missing-return cases. return-path-gates.log has
actual tails from the four subsequent gates, all exit 0. The canonical logs
now reflect this increment; gen3/gen4 are byte-identical. The refreshed
101-part offline bundle round-trips, and return-path-restore.log records an
actual missing-source restore to an isolated path (also compared to source).
Four-digit archive filenames fix the ordering failure found at part 100.
The structural proof deliberately does not infer loop termination or constant
conditions. Remaining generic-struct, expression and name-analysis gaps are
listed in STATUS.md.

## 2026-10-12 — gen2 reference resolution

name-resolution.log records the focused positive parity and invalid-reference
checks; name-resolution-gates.log contains actual tails from the final four
gates, all exit 0. Canonical gate logs now correspond to this increment, with
byte-identical gen3/gen4. The initial string-iterator lookup regression was
fixed and added to the fixture before this final run. gen2-offline-pack.log
records the updated 103-part archive round trip. Name resolution follows the
existing binding policy; no definite-assignment or whole-type-system claim is
made. Remaining work is recorded in STATUS.md and TYPES_ROADMAP.md.

## 2026-10-12 — typed inline numeric-list expressions

inline-expressions.log contains shared seed/gen2/native expression parity,
gen2/native sequencing checks, invalid-type/arity/syntax cases and the
inline-only runtime dependency regression. inline-expression-extra.log records
identical generated C from -O0/-O2 compiler binaries. The initial green-gate
state had a missed string-runtime dependency in an extra minimal probe; it was
fixed and tested before the final four-gate run. inline-expression-gates.log
contains actual tails from that run, all exit 0. Canonical logs are refreshed;
gen3/gen4 are byte-identical, and the 107-part archive round-trip passes.
Seed left-to-right sequencing and generic structs are not claimed implemented.
