# 2026-10-17 — removing C: the IR tool moves to Sayanox

Cut #5 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

All exit 0:

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost` — `=== TRUE-SELFHOST-MIN-OK ===` (`true-selfhost.log`),
  which now includes `test-exit-builtin` and the updated `test-doc-claims`
- `make gen3` — `=== GEN3-OK ===`, gen3 and gen4 byte-identical (`gen3.log`)
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-language-deps` — static and dynamic boundary green
  (`language-deps.log`); it also runs inside `true-selfhost`
- `make test-doc-claims` — green (`doc-claims.log`), now asserting that
  `tools/emit_to_ir.c` does not come back and that the phase doc records the
  Sayanox translator
- `make test-exit-builtin` — green (`exit-builtin.log`)
- `make test-emit-to-ir` — green (`emit-to-ir.log`), and
  `make test-native-ir-portable` (inside `native-test`) green

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`, make
  reports status 2 for the recipe's `exit 1`). The inventory it prints now has
  one row fewer.

## Second pass — the LSP folder index moves into the language

`tools/lsp_workspace.h` (119 C lines) and `tools/lsp_workspace_bind.sa` are
deleted. The compiler gained four directory builtins, and
`workspace_manifest` in `tools/sayanox_lsp.sa` is a real walk now.

* Builtins: `read_dir`, `path_kind` (lstat), `path_size`, `path_real`
  (realpath, with an explicit prototype so `-std=c99` builds see it).
  `make test-path-builtins` pins listing, kinds, sizes, realpath and
  seed-min's refusal.
* `workspace_manifest`: skip rules, depth 16, 256 KiB per file, 128 files,
  2 MiB manifest, percent-encoded URIs.
* `make lsp` is now exactly `gen2` + `cc`, with no binding step.
* `test-lsp`, `test-lsp-robust`, `test-lsp-workspace` and `test-lsp-unicode`
  are green — including symlink/hidden/oversized skipping, encoded paths,
  overlays, refresh after edit/delete and the enforced 128-file cap.

Honest differences, recorded in `docs/LSP.md`: the listing is in filesystem
order instead of sorted bytewise, and the file cap is applied to the finished
walk instead of during it.

## What changed

1. **`tools/emit_to_ir.sa` replaces `tools/emit_to_ir.c`.** 328 lines of
   Sayanox, built by `gen2` and then `cc` from the Makefile. Output was compared
   against the C tool on the real 1,182-line `SX_EMIT_LOG` and on the audit
   fixture: identical except the header line that names the tool. The script
   pins exact output, unknown lines and mnemonics, token boundaries inside
   operands (so `rax_tail` and `0xrax` survive), opaque `call` operand lists,
   an 8 KB operand line, unterminated final lines, `--strict` malformed-record
   and backwards-offset refusals, `--source-offsets` correlation and all exit
   statuses (2 usage, 1 unreadable/refused).

2. **`exit(n)` builtin** added to `selfhost/compiler_min.sa` so the ported tool
   can exit non-zero: it flushes stdout first and returns a numeric type, so
   `hold code = exit(2)` works. `make test-exit-builtin` pins the status, the
   flush and the fact that seed-min refuses it with a clear diagnostic.

3. **Dead C deleted.** Nine tracked files nothing referenced:
   `selfhost/inject_chr.c`, `inject_gc.c`, `inject_types.c`, `prove_loop.c`,
   `prove_recompile.c`, `fixup_emit.c`, `sx_launcher.c`, `sx_driver.c`,
   `build_stage2.c`, plus `stage2_expand.inc` (ten files, nine of them C).
   Documentation that pointed at them was corrected (`docs/TOOLCHAIN.md` no
   longer advertises a stage-2 make target that never existed, `docs/NATIVE.md` documents
   the two real backend entry points).

The tree now has **12** tracked `.c`/`.h`/`.inc` files, down from 22.

## Honest boundaries

- The IR tool still needs `cc` to turn the compiler's C output into an
  executable. The *source* is Sayanox; the C toolchain is not removed.
- Input is read as a C string, so a NUL byte truncates the log. The C tool
  rejected that input. The port documents the truncation and the test asserts
  the result contains `; UNTRANSLATED: bad` rather than silently dropping it.
- Output goes to stdout instead of an output-path argument because the dialect
  has no mode-taking file API; every call site redirects.
- The seed (2,035 lines), the native backend (4,353), the LSP directory bridge
  (119 + its 127-line test) and the make/POSIX-sh driver remain, and
  `make all-sayanox` keeps refusing the claim.
