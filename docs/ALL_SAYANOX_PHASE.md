# All-in-Sayanox: the next phase

Status: **next phase — in progress.** Recorded 2026-10-17, immediately after
the language-dependency pass. Phase A is done and Phase B has started (the IR
translator is Sayanox; see the table). No target reports success for the whole
phase: `make all-sayanox` still fails closed on purpose.

The goal is simple to state: every maintained piece of *logic* in this
repository is a Sayanox program, and the only non-Sayanox pieces left are the
smallest possible bootstrap seam and the build driver.

## Where the tree is today (measured 2026-10-17)

| Layer | Language | Size | Sayanox? |
|---|---|---:|---|
| Compiler (`selfhost/compiler_min.sa` + module) | Sayanox | 18,721 lines | **yes** |
| Formatter, package tool, language server, LSP binder, IR tool | Sayanox | 5 programs | **yes** |
| All tests and fixtures | Sayanox + `sh` drivers | 275 `.sa` files, 1,068,383 bytes | **yes** (logic) |
| Seed (`selfhost/seed/sxc_seed_min.c`) | C | 2,035 lines | no |
| Native AOT backend (`selfhost/native_aot.c`) | C | 4,353 lines | no |
| LSP framed-session test client (`tools/lsp_workspace_test.c`) | C | 127 lines | no (a harness, not server logic) |
| Build driver (`Makefile` + 25 `sh` scripts) | make / POSIX sh | ~4,510 lines | no |

Nine tracked C helpers that nothing referenced (`inject_chr.c`, `inject_gc.c`,
`inject_types.c`, `prove_loop.c`, `prove_recompile.c`, `fixup_emit.c`,
`sx_launcher.c`, `sx_driver.c`, `build_stage2.c`, plus `stage2_expand.inc`)
were deleted on 2026-10-17. The tree now has 12 tracked C/header/inc files.

The 2026-10-17 language-dependency pass already removed bash, awk, sed,
Python, Perl, Node and Ruby from the maintained paths
(`make test-language-deps`, part of `true-selfhost`). So the remaining
dependencies are exactly the five rows above — not interpreters, and not
package managers.

## Phases

Each phase ends with a gate, and each phase keeps `gen3 == gen4` green. No
phase may weaken an existing test to pass.

### Phase A — tool logic and interpreter freedom (done, 2026-10-17)

Compiler, formatter, local package commands, language server and the LSP binder
are `.sa`. All tracked scripts are POSIX `sh`. Gate: `test-language-deps`.

### Phase B — small tools in Sayanox (in progress)

1. **`tools/emit_to_ir` in Sayanox (done, 2026-10-17).** `tools/emit_to_ir.sa`
   replaces the 150-line C tool. Output is byte-identical for every instruction
   record, register/mnemonic rename, unknown line, named `call` operand list,
   8 KB operand line and source-offset audit; the only difference is the header
   line that names the tool. The tool writes to stdout instead of taking an
   output path (Sayanox has no mode-taking file API), so call sites redirect.
   Gates: `test-emit-to-ir` and `test-native-ir-portable`.
   Limitations, documented rather than hidden: input is read through a C string,
   so a NUL byte truncates the log (the C tool rejected it); the script now
   asserts the truncation is visible as `; UNTRANSLATED: bad`.
2. **LSP directory bridge in Sayanox (done, 2026-10-17).** The language now
   has `read_dir(path)` (newline-separated names), `path_kind(path)`
   (lstat: missing/file/dir/other), `path_size(path)` and `path_real(path)`;
   gen2 implements them, seed-min and native refuse them, and
   `make test-path-builtins` pins both. `workspace_manifest` in
   `tools/sayanox_lsp.sa` is a real walk: skip rules, depth 16, 256 KiB per
   file, 128 files, 2 MiB manifest, percent-encoded URIs. With it came the
   deletion of `tools/lsp_workspace.h` and `tools/lsp_workspace_bind.sa`, so
   the LSP build is now gen2 + cc with no binding step.
   Gates: `test-lsp`, `test-lsp-robust`, `test-lsp-workspace`,
   `test-path-builtins`.
   Honest difference: the listing is in filesystem order instead of sorted
   bytewise, and the file cap is applied to the finished walk rather than
   during it. Both bounds still hold; the order does not.

### Phase C — package and process behavior in Sayanox

Move the remaining `tools/sxpkg.sh` logic (sync/install/publish/fetch,
staging, checksums, rollback) into `tools/sxpkg.sa`, leaving the shell file as
an `exec` shim at most. Remaining blockers: directory enumeration (Phase B),
a process-spawn or HTTP builtin that the runtime already exposes (`http_get`
exists on gen2 and is refused on native), and safe temp-directory creation.
Tests: `test-sxpkg`, `test-sxpkg-polish`, `test-sxpkg-online-local`,
`test-sxpkg-transfer-hardening`, `test-sxpkg-online-optin` must pass unchanged.

### Phase D — native backend in Sayanox

Port `selfhost/native_aot.c` (4,353 lines of x86-64 ELF emission) to Sayanox.
This is the largest piece and needs language features that do not exist yet:

* a byte buffer with indexed writes at arbitrary offsets (`write_out` is
  append-only);
* integer bit operations for encodings (shifts, masks, `&`, `|`, `^`);
* a syscall/memory surface, or a way to emit an ELF section layout without raw
  pointers.

Interim honest target: `native_aot` stays C, but the **encoder seam** already
exists (`SX_EMIT_LOG`, `test-native-emit-split`, `test-native-ir-log`), so a
Sayanox backend is written against a pinned instruction list rather than
against the C source. That is why those gates were built first.

### Phase E — the seed

The C seed exists so a fresh checkout can produce an executable compiler.
"All in Sayanox" therefore has two honest end states, and the choice must be
recorded before this phase starts:

1. **Prebuilt bootstrap binary:** ship a signed/checksummed `gen2` artifact, so
   no C source is needed, and rebuild it from `.sa` with the Sayanox native
   backend. The tree then contains no maintained C, but a *binary* is still a
   trust anchor.
2. **Minimal C seed kept forever:** keep `sxc_seed_min.c` as a documented,
   auditable exception (a few thousand lines) and state that the compiler
   itself is fully Sayanox.

Neither option is implemented. Until one is, the seed row above stays honest
and `make all-sayanox` keeps failing.

## Progress log

* **2026-10-17 — Phase B.2 done.** Directory builtins + Sayanox folder index;
  `tools/lsp_workspace.h` and `tools/lsp_workspace_bind.sa` deleted. The tree
  has 11 tracked C/header/inc files, down from 23 at the start of the day.
* **2026-10-17 — Phase B.1 done.** `tools/emit_to_ir.c` deleted;
  `tools/emit_to_ir.sa` (328 lines) built by gen2 and cc through the Makefile,
  identical output on the real 1,182-line `SX_EMIT_LOG`, the audit mode, the
  long-line case and all five exit-status cases.
* **2026-10-17 — `exit(n)` builtin added** to the Sayanox compiler for CLI
  tools (`gen1_min`/`gen2`/`gen3`), with `make test-exit-builtin`; seed-min and
  native refuse it.
* **2026-10-17 — dead C removed.** Nine tracked helpers with no reference.

## Definition of done

`make all-sayanox` exits 0. It currently prints the inventory above and exits 1
with a pointer to this file, the same way `true-selfhost-full` refuses to claim
a full-language self-host.

A second check lands with Phase B: the target must fail if any tracked `.c`
file on the maintained path is not either (a) marked as a documented exception
in this file or (b) generated. The exception list starts at four
(seed, native backend, LSP bridge header, LSP bridge test) and can only shrink.
The IR tool has already left it.

## What does not change

* A language always needs an initial executable somewhere in its history. This
  phase removes maintained C *sources* only if Phase E chooses option 1; it can
  never remove the need for a trust anchor.
* `make` may remain the build driver. A Sayanox driver is a nice-to-have, not a
  requirement, and replacing it with a `.sa` program still needs a built
  compiler first.
* No generated C is checked in; `gen3 == gen4` byte identity stays a gate at
  every phase.
