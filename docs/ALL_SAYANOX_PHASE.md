# All-in-Sayanox: the next phase

Status: **next phase — not started.** Recorded 2026-10-17, immediately after the
language-dependency pass. Nothing in this document is implemented yet, and no
target reports success for it: `make all-sayanox` fails closed on purpose.

The goal is simple to state: every maintained piece of *logic* in this
repository is a Sayanox program, and the only non-Sayanox pieces left are the
smallest possible bootstrap seam and the build driver.

## Where the tree is today (measured 2026-10-17)

| Layer | Language | Size | Sayanox? |
|---|---|---:|---|
| Compiler (`selfhost/compiler_min.sa` + module) | Sayanox | 18,713 lines | **yes** |
| Formatter, package tool, language server, LSP binder | Sayanox | 4 programs | **yes** |
| All tests and fixtures | Sayanox + `sh` drivers | 274 `.sa` files, 1,063,740 bytes | **yes** (logic) |
| Seed (`selfhost/seed/sxc_seed_min.c`) | C | 2,035 lines | no |
| Native AOT backend (`selfhost/native_aot.c`) | C | 4,353 lines | no |
| LSP directory bridge (`tools/lsp_workspace.h`) | C | 119 lines | no |
| IR analysis tool (`tools/emit_to_ir.c`) | C | 150 lines | no |
| Build driver (`Makefile` + 26 `sh` scripts) | make / POSIX sh | ~4,470 + ~1,730 lines | no |

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

### Phase B — small tools in Sayanox (next)

1. **`tools/emit_to_ir` in Sayanox.** The C tool is a streaming line
   transformer using `read_file`/`write_file`/string builtins that gen2 already
   has. Port it, then keep the existing `test-emit-to-ir` and
   `test-native-ir-portable` gates and require byte-identical IR output against
   the C tool before deleting the C.
   *Prerequisite:* none beyond gen2's current builtins.
2. **LSP directory bridge in Sayanox.** Replace `tools/lsp_workspace.h` with a
   language-level directory API (`read_dir(path)` returning names, plus a stat
   or size-and-kind helper) so `workspace_manifest` stops being a stub and
   `tools/lsp_workspace_bind.sa` stops being needed at all.
   *Prerequisite:* the new builtin must be specified, implemented on gen2, and
   refused with a clear diagnostic on seed-min and native until ported there.

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

## Definition of done

`make all-sayanox` exits 0. It currently prints the inventory above and exits 1
with a pointer to this file, the same way `true-selfhost-full` refuses to claim
a full-language self-host.

A second check will be added when Phase B lands: the target must fail if any
tracked `.c` file on the maintained path is not either (a) marked as a
documented exception in this file or (b) generated. The list of exceptions
starts at four and can only shrink.

## What does not change

* A language always needs an initial executable somewhere in its history. This
  phase removes maintained C *sources* only if Phase E chooses option 1; it can
  never remove the need for a trust anchor.
* `make` may remain the build driver. A Sayanox driver is a nice-to-have, not a
  requirement, and replacing it with a `.sa` program still needs a built
  compiler first.
* No generated C is checked in; `gen3 == gen4` byte identity stays a gate at
  every phase.
