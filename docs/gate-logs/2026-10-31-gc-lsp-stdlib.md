# Empty-heap GC release, LSP incremental sync, stdlib text oracle — 2026-10-31

## Reviewed increment

- Implementation checkpoint `78a709c`; documentation/status follow-up `9b34d32`;
  merged as `d958713` ([PR #55](https://github.com/sayan9168/sayanox/pull/55)).
- Fresh [GitHub run 41192778447](https://github.com/sayan9168/sayanox/actions/runs/41192778447)
  at `78a709c`: **Complete original acceptance** passed (42m31s) and
  **Sayanox entry and migrated acceptance gates** passed (27m15s).
- Fresh [GitHub run 41195741945](https://github.com/sayan9168/sayanox/actions/runs/41195741945)
  at `9b34d32`: both jobs passed again (40m05s / 24m08s).
- No gate, sanitizer, cap, fixture or pin was weakened or removed. Two new
  test files (`selfhost/stdlib_text_test.sa`, `selfhost/stdlib_text.want`) and
  five new LSP probe facts were added.

## Executed evidence (local, this tree)

```
./sx target gen2                                    -> 0 (6m23s, after the compiler_min edit)
./sx target test-gc                                 -> 0
./sx target test-lsp                                -> 0
./sx target test-lsp-robust test-lsp-unicode test-lsp-workspace \
  test-lsp-semantic test-lsp-types test-lsp-ide     -> 0
./sx target test-stdlib-next                        -> 0
./sx target test-stdlib-modules                     -> 0
./sx target doctor test-doc-claims                  -> 0
./sx target pack-compiler                           -> 0 (150 parts, byte-identical round trip)
sha256sum -c bootstrap/native.sha256                -> OK
sha256sum -c bootstrap/sx.sha256                    -> OK
sha256sum -c docs/full-language-v1.sha256           -> OK
./sx ci                                             -> 0 (569 [OK], 0 [FAIL])
  ... === TRUE-SELFHOST-FULL-V1-OK ===
```

## What each claim rests on

**GC (R04, partial).** The emitted C-output collector no longer returns before
trimming when no managed block is registered, and its trim keeps nothing while
`sx_gcall` is null. A program that dropped every value used to hold two blocks
per size class through 64 KiB — `2 x 32 x (2^15 - 1) = 2,097,152` bytes. The
probe in `tools/sxgc_pool_lib.sa` fills all fifteen classes with four blocks
each (4,194,176 cached bytes) before any managed allocation exists, collects,
and requires every free list to be empty and every block freed exactly once.
Against a locally built old-behaviour runtime the same probe aborts at
`sx_gfree[c]==0` (exit 134), so it discriminates rather than restating the new
code. `test-gc` runs O0, O2 and ASan+UBSan with forced fake-stack roots; the
existing cache-policy, reuse, alias and double-free assertions are unchanged.
Not claimed: precise GC, bounded heap for arbitrary live programs, RSS return.

**LSP (R05, partial).** `initialize` advertises
`textDocumentSync: {"openClose": true, "change": 2}`; `didChange` splices a
UTF-16 `range` with line/character clamping and reversed ranges treated as
insertions, and still accepts whole-buffer replacements. `test-lsp` drives a
seventh framed session (capability, replacement, dropped old symbol, line
deletion, out-of-range clamp) and pins 43 facts. Not claimed: more than one
change object per notification, more than four buffers, compiler-grade
incremental re-parse, workspace-wide diagnostic push — still not IDE-complete.

**Stdlib (R07, partial).** `t_count_char`, `t_starts_with`, `t_ends_with` and
`t_normalize_ws` in `stdlib/str_text.sa` are checked against the hand-written
`selfhost/stdlib_text.want`; `test-stdlib-next` compiles the fixture with
seed-min, gen2 and native AOT and requires all three stdout streams to match.
The expected bytes come from none of the compilers under test.

## Defect found in this increment (not fixed)

`native_aot` keeps `len("a\rb")` at 3 but emits the bytes `arb`; seed-min,
gen2 and the published C-output contract decode CR (`0x0D`). Registered as R13
in [REMAINING_WORK](../REMAINING_WORK.md) and in [NATIVE32](../NATIVE32.md).
The stdlib fixture builds CR with `chr(13)` so a whitespace helper is not
hidden behind an escape bug; the fixture can switch back to source literals once
the decoder is fixed or `\r` is refused at parse time.
