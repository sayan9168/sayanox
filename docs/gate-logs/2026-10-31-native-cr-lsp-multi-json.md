# Native CR decode fix, multi-change LSP notifications, JSON boundary oracle — 2026-10-31

## Reviewed increment

Three slices on top of the merged `79427b0`:

- **R13 — native `\r` decode.** `tools/sxdata_lib.sa` required full-language
  mode before mapping `\r` to CR, so a pure-min program printed `arb` for
  `"a\rb"` while seed-min, gen2 and the published C-output contract printed
  `a`, CR, `b`. Length stayed 3 in every backend, which is why the divergence
  looked like a byte bug rather than an escape bug. CR now decodes in every
  mode.
- **R05 — several change objects per notification.** `textDocument/didChange`
  applies up to eight `range` + `text` objects in order, with bounded
  per-element field scans (`num_field_between`, `str_field_between`) and a
  string-aware object extent (`obj_end`) so a brace inside a replacement text
  cannot end the element early.
- **R07 — JSON boundary/precision oracle.**
  `selfhost/stdlib_json_boundary_test.sa` is compared with the hand-written
  43-line `selfhost/stdlib_json_boundary.want`.

## Anchor consequence (R13)

`bootstrap/sxc_native.bin` is a derived artifact and pins the compiler sources,
so it was rebuilt instead of patched:

```
./bootstrap/sxc_native.bin tools/sxc_native.sa s1   -> new compiler
./s1 tools/sxc_native.sa s2                          -> s2
./s2 tools/sxc_native.sa s3                          -> s3
cmp s2 s3                                            -> identical (fixed point)
```

`s3` was installed as `bootstrap/sxc_native.bin`
(`sha256 9cfd3d1d7c3033af783f5a30247659d4837edb708ba84ac679a4f4ecbb58c367`,
688128 bytes, 689 text lines), `./tools/sxaudit bootstrap/sxc_native.bin`
regenerated `bootstrap/sxc_native.audit`, and `bootstrap/native.sha256` /
`bootstrap/sx.sha256` were refreshed. The stamp of the previous anchor is kept
in git history, not re-derived here; no independent-trust claim is made or
implied by a fixed point.

## Executed evidence (local, this tree)

```
./sx target test-stdlib-next          -> 0   (5 modules x seed-min / gen2 / native AOT)
./sx target test-lsp                  -> 0   (47 facts, two incremental sessions)
./sx target test-lsp-robust test-lsp-unicode test-lsp-workspace \
  test-lsp-semantic test-lsp-types test-lsp-ide -> 0
./sx target test-stdlib-json-write    -> 0
./sx target test-stdlib-json-deep     -> 0
./sx target test-gc                   -> 0   (O0 / O2 / ASan+UBSan, fake-stack roots)
./sx target verify-seed               -> 0
./sx target test-native-bootstrap     -> 0   (new anchor re-derives the same fixed point; DDC controls)
./sx target test-doc-claims           -> 0
./sx target test-ci-shape             -> 0
sha256sum -c bootstrap/native.sha256  -> OK
sha256sum -c bootstrap/sx.sha256      -> OK
sha256sum -c docs/full-language-v1.sha256 -> OK
./sx ci                               -> 0   (570 [OK], 0 [FAIL], === TRUE-SELFHOST-FULL-V1-OK ===)
```

## What each claim rests on

**R13.** The regression is not a new fixture: `selfhost/stdlib_text_test.sa`
carries `"a\rb"` and `"\r\t\r"` as **source literals** again, and
`test-stdlib-next` requires seed-min, gen2 and native AOT to reproduce the same
hand-written `selfhost/stdlib_text.want`. On the previous tree the native
backend printed `alpha betar gamma` for line 1 and `r` for line 4.

**R05.** The probe's eighth session opens a two-declaration document, sends
**three** change objects in one `didChange` (two range replacements and an
insertion at the end), and then asks for `documentSymbol` and
`textDocument/diagnostic`: both new names are present, the replaced names are
gone, and the inserted `bogus 1` line is diagnosed. Still not claimed: more
than eight objects, more than four buffers, workspace-wide diagnostic push, or
compiler-grade incremental re-parsing.

**R07.** The 43 expected lines were written by hand and checked line by line
before being committed as `stdlib_json_boundary.want`; the fixture is compiled
by three different backends and all three must reproduce those bytes, so no
compiler under test produces its own oracle.

## Remote acceptance

Tracked in the pull request for this branch. This record does not predict it.
