# Remaining work — executable acceptance, not completion by checklist

This register covers the projects requested after the 2026-10-31 audit. It does
**not** mark all of them implemented. Code, negative controls and fresh guarded
acceptance are required for each increment. An external dependency is not a
passing gate. All maintained implementation/test changes must remain Sayanox;
C-output compatibility, pure-min bootstrap, gen3/gen4 equality, existing caps,
sanitizers, aliases and CI recording guards must remain intact.

## Accepted baseline

Main checkpoint `0fca5622713db82df308f8f77d9589b414c1a901` passed both jobs and
final guard audits in [run 41162923167](https://github.com/sayan9168/sayanox/actions/runs/41162923167).
All-maintained-Sayanox migration, published-language v1 C-output self-hosting,
conservative-collector reliability and the bounded multi-ISA literal `len`
increment are accepted there. This does not pre-accept later edits.

The current documentation-consistency increment corrects stale guides and adds
Sayanox regression checks to `test-doc-claims`. Its implementation/testing
status is tracked in [STATUS](STATUS.md); it is not an implementation of the
remaining compiler/runtime/tooling projects below.

## Work register

| ID | Project and current state | Required completion evidence |
|---|---|---|
| R01 | **Current documentation consistency — current increment** | Correct current README/bootstrap/milestone/LSP/start guides; preserve clearly labelled historical records. Actual current-source `test-doc-claims` with stale-command/architecture negative controls, source audit and fresh guarded complete CI. A prose sentinel is not a proof of every documentation claim. |
| R02 | **Full native parity — open implementation project; string-value copy landed 2026-10-31, `string_eq` landed 2026-11-01, general string expressions and `chr(<integer expression>)` landed 2026-11-02 (still open: `concat`/`chr(<expr>)` inside other expressions, user functions, aggregates, FP, file/runtime APIs, GC)** | Start with bounded numeric user functions in `native32`, then aggregates/general strings, FP lowering, file/runtime APIs and GC. Each stage needs independent output oracles, cross-backend execution, deterministic images, type/arity/unsupported-form refusals, recursion/stack/cap tests where applicable, and complete guarded CI. ARM/RV emulator FP/syscalls alone do not close compiler lowering. Do not label one bounded function slice full parity. **Landed:** `hold b = a` / `b = a` copy a string variable's `(pointer, length)` pair on i386/AArch64/RV64IM, with a six-way parity fixture, cross-ISA data comparison, reviewed goldens and three new refusals. **Landed 2026-11-01:** `string_eq(A, B)` compiles to one shared comparison routine per image (length test, then a byte loop) returning 0/1, works in `when`/`while` conditions and composes with numeric operators, with its own six-way fixture, cross-ISA data comparison, reviewed goldens and four new refusals (matrix 22). Adding it exposed and fixed a real AArch64 emulator defect (64-bit add/subtract never set N/Z/C/V). **Landed 2026-11-01 (second step):** `chr(X)` builds a one-byte string from an integer literal or a numeric variable in the three whole-value positions (`hold s = chr(X)`, `s = chr(X)`, `show chr(X)`), with the C backend's low-byte rule, `chr(0)` as empty text, per-occurrence data cells, six-way parity and four more refusals (matrix 26). That step also moved the text segment to two pages (the `streq` image had consumed the first page exactly, leaving zero code bytes) and widened the emulator's image window to `0x400000..0x424000`. **Landed 2026-11-02 (third step):** `chr(X)` now also lowers as one whole argument of `concat`, `string_eq` and `len` (`concat(chr(a), "x")`, `concat(chr(a), chr(b))`, `string_eq(chr(65), s)`, `string_eq(chr(a), chr(b))`, `len(chr(65))`) by hoisting the existing cell/`udiv`/`cell + 1 - length` sequence into a hidden `(pointer, length)` slot before the existing push paths run, with five more refusals (matrix 26 -> 31; the old `concat_call` refusal became a legal program and was removed). Fixture `chr_nested.sa` (hold, assign and `when`-condition forms) runs on all six execution paths with reviewed AArch64/RV64IM goldens; its data segment is pinned by size rather than byte equality because a `concat` literal still stores an arch-specific pointer in the data image (R14). `chr` as an operand of anything else, arbitrary string-valued expressions and signed literal arguments still have no lowering; the next step remains bounded numeric user functions. |
| R03 | **Independent bootstrap — externally blocked** | Supply and independently review a reference compiler, verifier and build provenance that do not descend from the repository anchor; execute the actual conditional DDC protocol and independently check final bytes. The selected reference-supply path has no supplied reference. No C/Rust reference implementation exception is authorized. Harness controls, renaming a binary and same-anchor fixed points are not substitutes. |
| R04 | **Precise GC and stronger memory contracts — open design/implementation; one bounded fix landed 2026-10-31** | Define root/type maps and exact pointer-bearing fields for the selected runtime; retain aliases/interior-root policy, cycles and children under O0/O2 and ASan+UBSan including forced fake-stack mode. Test failure/recovery and resource limits. State bounded workloads/allocator assumptions explicitly: arbitrary unbounded live programs cannot have an unconditional finite heap/RSS guarantee. Existing conservative GC is implemented, not absent. **Landed:** an empty managed heap now releases the whole free-list cache instead of retaining two blocks per class (up to 2,097,152 bytes), with a negative control that fails on the previous emitter. Precise roots, type maps and bounded-heap claims remain open — see [GC](GC.md). |
| R05 | **IDE-complete LSP — open implementation project; incremental sync landed 2026-10-31** | Reuse compiler semantics where supported; incremental UTF-16 edits, multi-file diagnostics, invalidation and scalable bounded indexing need real protocol/session tests, disk/open-overlay precedence, malformed-request and resource-limit controls. Existing four-buffer and bounded workspace behavior must stay green. **Landed:** `didChange` range splicing with clamping, a capability of `change: 2`, and up to eight change objects per notification applied in order (2026-10-31), driven by real framed sessions in `test-lsp` (47 facts). Still open: four buffers, no workspace-wide diagnostic push, no compiler-grade incremental re-parse, no edit merging beyond the sequential rule — the server is still not IDE-complete. |
| R06 | **Language-level modules — open language design** | Specify canonical module identities, scopes, visibility/export and import caching/cycle policy; implement qualified binding across functions/types/fields/generics and all promised backends. Add collision/privacy/cycle/import tests. `sxmod` rewriting and path renaming do not establish these semantics. Preserve the current bootstrap splice dialect. |
| R07 | **Stdlib depth — open implementation project; oracle-gated text helpers landed 2026-10-31** | Extend nested JSON updates/round trips with explicit number-precision policy, malformed/boundary inputs and cross-backend output oracles. Preserve the published IEEE-double contract; exact decimal facilities require an explicit separate representation, not a silent numeric-semantic change. Existing reader/crypto/data/time modules are not missing. **Landed:** `t_count_char`, `t_starts_with`, `t_ends_with`, `t_normalize_ws` in `stdlib/str_text.sa`, checked against a hand-written `selfhost/stdlib_text.want`, plus the 43-line JSON boundary/precision oracle `selfhost/stdlib_json_boundary.want` (minification, key prefixes, deletion cases, nested paths, number policy, escaping, malformed refusals) — both on seed-min, gen2 and native AOT by `test-stdlib-next`. Depth remains open: nested *writes* by path and an exact-decimal representation are still unimplemented. |
| R08 | **Package transport, key distribution and crypto assurance — open; security review needed** | Define authenticated trust-root/key rotation/revocation and transport policy; execute malicious index/archive/key/path/downgrade/offline controls. Optional HTTP is not a bootstrap dependency. Any transport replacement must preserve verification before installation. A constant-time claim additionally needs an appropriate integer/runtime design and independent security review; passing ordinary arithmetic/timing smoke tests does not certify it. Current pinned-key offline signatures already work. |
| R09 | **Broader platforms and hardware — open; execution environments needed** | Define OS/ABI support and implement the required runtime/object/container paths. Run actual native programs on each promised OS/CPU, including syscall/error/resource and bootstrap tests. Existing x86-host ARM/RV emulation is not real-hardware evidence. Do not add a CI matrix that merely skips unsupported binaries. |
| R10 | **Syntax-aware formatter — open implementation project** | Use token/parser structure with explicit malformed-source behavior; preserve strings/comments and program meaning. Require idempotence, formatting oracles and compile/execute parity, including multiline/Unicode/nested cases. Existing brace/whitespace formatter remains supported. |
| R11 | **GitHub language recognition — externally gated** | Gather legitimate independent in-the-wild `.sa` use and follow upstream Linguist requirements. Open an evidence-backed contribution only when qualified; upstream review/acceptance is not controlled by this repository. No language-bar relabelling or spam PR. |
| R12 | **Updated public release — publication pending** | Choose a version for an accepted checkpoint, run the unchanged gated Sayanox release path, verify published tag/assets/evidence and state exact included features. The audit found v1.0.4 behind main; that is not authorization to label unfinished roadmap work complete or bypass release gates. |
| R13 | **Native backend `\r` escape divergence — FIXED 2026-10-31** | `tools/sxdata_lib.sa` gated CR decoding on full-language mode, so a pure-min program printed `arb` for `"a\rb"` while seed-min, gen2 and the C-output contract printed `a`, CR, `b`. CR now decodes in every mode; the pinned native anchor was rebuilt from source to a three-stage fixed point and both manifests/audits were regenerated; `selfhost/stdlib_text_test.sa` keeps the source literals as the regression test on all three backends. Reopen only if a new mode is added that bypasses this decoder. |
| R14 | **`concat` data image is not cross-ISA identical — FIXED 2026-11-02** | The emitter used to write the literal temp slot's pointer (`literal_base + offset`) into the **data** segment at layout time, and the bump pointer's initial value the same way, so every `concat` program's data image differed between i386 (`134520832`) and AArch64/RV64IM (`4202496`). Both are now runtime values: a literal argument's `(pointer, length)` pair is stored by the program at the call site (the slot stays zero in the image), and the 4-byte bump-pointer slot at data offset 32 is initialised once by the entry code with the target's own base. Data segments are byte-identical on all three targets, so `chr_nested` (the first accepted `concat` program) is back on the full cross-ISA byte comparison and the temporary layout-only pin is deleted. Pinned image sizes grew by 4 bytes (data) with unchanged execution output on all six paths. |
| R15 | **`sxbuild inventory` counted gitignored default outputs — FIXED 2026-11-02** | `is_generated_c_artifact` knew the checked-in generator names plus a "has a `.sa` peer" rule, but not the gitignored default output paths of the compiler (`selfhost/mini_out.c`, `_smoke.c`, `_out.c`, `hello_out.c`, `boot.c`, `boot2.c`), so any ad-hoc compiler run left the inventory reporting stray C files. Those six names are now listed in `is_known_selfhost_c`, documented as "keep in step with the `selfhost/*.c` entries in .gitignore". `test-sxbuild` grew a real regression: it creates all six files, asserts the count stays `0`, then creates a genuine stray `.c`, asserts the count is `1` (so the fix is not a blanket ignore), then removes them — the pre-fix compiler fails that gate. |
| R16 | **AArch64 64-bit add/subtract never set flags — FIXED 2026-11-01** | `tools/sxisaexec.sa` computed 64-bit ADD/SUB (immediate and shifted register) results but updated `N`/`Z`/`C`/`V` only in the 32-bit paths, so any 64-bit `cmp` followed by `b.cond` branched on stale flags. The `streq` fixture reproduced it (`string_eq` on AArch64 printed `0,1,1,1,…` instead of `1,1,1,0,…`), and `test-sxisaexec` fails on the previous emulator and passes on the fixed one, so the regression is pinned. Reopen only if a new flag-consuming 64-bit form is added. |

### Increment log - 2026-11-01 (slices outside the audit list)

* **R02 step 2 — `string_eq` in `native32`:** a numeric expression over two
  string variables or literals on i386/AArch64/RV64IM. Push both
  `(pointer, length)` pairs, call one comparison routine emitted once per image
  (different length => 0, else a byte loop), leave 0/1 on the value stack. No
  allocation, no scratch globals, and literals keep the data image
  arch-neutral. Four refusals: wrong arity, numeric argument, unknown name, and
  a stray `,`. Fixture `streq.sa` (15 lines of output) runs on all six execution
  paths and through the cross-ISA data comparison; goldens are reviewed AArch64
  and RV64IM images.
* **R02 step 3 — `chr` in `native32`, plus the second code page:** `chr(X)` for
  an integer literal or a numeric variable in the three whole-value string
  positions. The low byte is kept (`chr(300)` = byte 44), `chr(0)` is empty
  text, each source occurrence owns a 4-byte data cell holding the byte and the
  newline that `show` expects, and the stored pointer is `cell + 1 - length` so
  an empty `chr` prints one line break. Nothing is allocated. The step could not
  be emitted into the old layout at all: the `streq` image had landed exactly on
  the one-page ceiling (`4096 - 116` bytes of code), so the text segment is now
  two pages (`streq` 4270 -> 8366 bytes, `chr` 8354) with data at
  `0x0804A000`/`0x402000`, and `tools/sxisaexec.sa` maps
  `0x400000..0x424000` so the 60 KiB concat heap still fits above the moved
  data. Four refusals (matrix 22 -> 26): wrong arity, a string argument, an
  unknown name, and an argument that is neither literal nor variable. Fixture
  `chr.sa` (20 output lines) runs on all six execution paths and through the
  cross-ISA data comparison; goldens are reviewed AArch64 and RV64IM images.
* **R02 step 4 — nested `chr`:** `chr(X)` as one whole argument of `concat`,
  `string_eq` and `len`, emitted by hoisting the committed cell sequence into a
  hidden `(pointer, length)` slot (`chr_kind_of`, `emit_chr_value`,
  `emit_load_abs`) and feeding the existing push paths, with no new push form
  and no allocation. Five new refusals (matrix 26 -> 31); `refuse/concat_call.sa`
  was deleted because `concat(text, chr(121))` is now a legal program. Fixture
  `chr_nested.sa` (14 output lines) runs on all six execution paths, pins
  i386 8534 bytes and adds reviewed AArch64/RV64IM goldens. `chr` argument
  validation is now shared between the whole-value and nested positions, so
  `chr("A")` cannot silently decode a literal token as a code - it is refused.
* **R02 step 6 — `chr` of an integer expression:** `X` in `chr(X)` may now be
  any integer expression the subset compiles, not just a literal or a bare
  numeric variable. The expression block runs first (value in the accumulator),
  the value is parked in a shared 4-byte scratch word and read back through the
  numeric-slot path, so the per-occurrence cell keeps `[byte][newline][0][0]`;
  `chr_arg` became parenthesis-aware so `chr((n + 1) * 2)` parses while a
  top-level comma still means arity. `refuse/chr_expression.sa` was deleted
  (`chr(n + 1)` is legal now) and four refusals were added (matrix 36 -> 39):
  a string variable in the `chr` expression, an unknown name, `chr(n, 1)`, and
  `string_eq(chr(n + 1), "A")`. Fixture `chr_expr.sa` (9 output lines, i386
  8313 bytes, reviewed AArch64/RV64IM goldens) runs on all six execution paths.
  Still open: `chr` of an expression as an argument of `concat`, `string_eq` and
  `len`, which parse their arguments by token count.
* **R02 step 5 — general string-valued expressions:** `show concat(A, B)` and
  `concat` nested as a `concat` operand. The concat emitter is now built from
  three functions over file-scope compiler state - `materialize_concat_operand`
  (a name's pair, a literal pair written at runtime, a `chr` cell, or a nested
  call emitted first into a hidden pair slot), `emit_concat_copy` (the one copy
  routine, unchanged machine code) and `emit_concat_pair` - so a nested call is
  emitted before its parent instead of being rejected, and a `show` reuses the
  same copy plus the shared string-print sequence (`emit_show_string_slot`,
  also now used by `show NAME` and `show chr(...)`). Nesting is capped at seven
  levels; `concat` stays a statement-level form and its refusal inside another
  expression now says so instead of "this backend has no functions". Five new
  refusals (matrix 31 -> 36) and a new `concat_expr.sa` fixture (13 output
  lines, i386 8590 bytes, reviewed AArch64/RV64IM goldens) on all six execution
  paths. Slot allocation for `chr` operands moved from the parser into emission,
  so the reviewed goldens of the `concat` fixtures were regenerated; every
  pinned image size is unchanged.
* **R16 found and fixed — 64-bit AArch64 compare flags:** the emulator never set
  `N`/`Z`/`C`/`V` for 64-bit ADD/SUB (both immediate and shifted register), so
  the new routine's `cmp x1, x3` branched on stale flags and AArch64 output
  disagreed with the other five paths. Fixed in `tools/sxisaexec.sa`; the
  `streq` six-way run is the regression (fails on the old emulator).

### Increment log - 2026-10-31 (slices outside the audit list)

Delivered, each with a gate that fails on the previous code:

* **R04 (partial):** empty managed heap releases the whole C-output free-list
  cache (`tools/sxgc_pool_lib.sa`, `test-gc` at O0/O2/ASan+UBSan). Precise
  roots/type maps and any bounded-heap claim stay open.
* **R05 (partial):** incremental UTF-16 `didChange` splicing with clamping plus
  `change: 2` capability, driven by a real session in `test-lsp` (43 facts).
  Four buffers and no workspace diagnostic push remain.
* **R07 (partial):** four `str_text.sa` helpers checked against a hand-written
  stdout oracle on seed-min, gen2 and native AOT (`test-stdlib-next`).

Found in the first block: **R13**, the native `\r` literal-escape divergence (fixed in the second block below).

Second block on the same day (register R05/R07/R13):

* **R13 fixed:** `\r` decodes in the pure-min native path too; the native anchor
  was rebuilt (`bootstrap/sxc_native.bin` regenerated from a three-stage
  fixed point, `bootstrap/sxc_native.audit` and both manifests refreshed) and
  the stdlib text fixture carries the regression literals.
* **R05 step:** up to eight `didChange` change objects per notification, applied
  in order, with bounded per-element field scans and string-aware object
  extents; `test-lsp` pins 47 facts across two incremental sessions.
* **R07 step:** 43-line JSON boundary/precision oracle
  (`selfhost/stdlib_json_boundary.{sa,want}`) on seed-min, gen2 and native AOT.

Third block on the same day (register R02 first step):

* **R02 step landed:** string-value copy in `tools/native32.sa` for
  i386/AArch64/RV64IM — `hold b = a` and `b = a` copy the `(pointer, length)`
  pair, allocate nothing, and stay independent of later source reassignment.
  New `strcopy.sa` fixture (six execution paths + cross-ISA data comparison +
  reviewed goldens for arm64/riscv64) and three refusals
  (`copy_type`, `copy_back`, `copy_unknown`), refusal matrix 18.
* **R14 found:** a `concat` program bakes an arch-specific absolute literal
  address into its data image, so cross-ISA data identity only holds for
  programs without `concat`. Recorded, not fixed.

Deferred with a reason: R02's "one capability beyond integer plus `len`" needs
new i386/AArch64/RV64IM encoder paths and `sxisaexec` parity for each new form;
shipping one half-covered form would be breadth without proof. It is the next
reviewable increment, not a completed one.

## Concrete release follow-up found during this increment

`tools/sxrelease_lib.sa` tests/packages `HEAD`, but its dispatch publication
command currently calls `gh release create` without explicitly binding a new
tag to that tested commit or checking an existing tag's commit identity.
For a new dispatched tag, the GitHub CLI can select the default branch instead
of the tested checkout. Before publishing an updated release, harden this path
with explicit tested-commit targeting, existing-tag identity checks and
negative controls for mismatched/moved tags. Do not treat release-plan output
as a test of publication identity. No release is published by the current
documentation increment.

## Order and working rules

1. Close R01 with regression checks and fresh acceptance before compiler changes.
2. Take R02 in reviewable implementation increments, beginning with numeric
   user-function semantics and its refusal/stack contract; do not silently
   shrink published-language v1 to fit native limitations.
3. R05/R07/R10 can follow as separately tested tooling/library increments.
   R04/R06/R08/R09 require explicit semantic/runtime/platform designs, not only
   more success labels. Track each actual implementation and its fresh CI.
4. R03 and R11 need external provenance/evidence; R08/R09 also need appropriate
   review/execution resources before their strongest claims can close.
5. Publish R12 only through the gated release path for the exact accepted tree.

For each completed increment record the source checkpoint, actual commands and
exit statuses, output/refusal evidence, unchanged source/entry pins, complete
PR checks and post-merge integration. Registration, documentation and old green
runs are never fresh implementation acceptance. This register must not be used
as a substitute for doing the listed work.

## Current references

- [Milestone](COMPLETE.md), [bootstrap chain](BOOTSTRAP_ROADMAP.md),
  [native trust boundary](NATIVE_BOOTSTRAP.md), [DDC protocol](DIVERSE_BOOTSTRAP.md).
- [Native x86-64](NATIVE.md), [multi-ISA subset](NATIVE32.md), [GC](GC.md).
- [LSP](LSP.md), [module semantics](MODULES.md), [stdlib](STDLIB.md),
  [registry](REGISTRY.md), [Linguist](LINGUIST.md).
- [Published-language profile](FULL_LANGUAGE_PROFILE_V1.md) and
  [accepted checkpoint history](STATUS.md).
