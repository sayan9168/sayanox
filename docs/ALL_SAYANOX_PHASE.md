# All-in-Sayanox: the next phase

Status: **next phase — in progress.** Recorded 2026-10-17, updated 2026-10-25.
Phases A, B, **all ten steps of Phase D (Steps 1–10)**, and the **C-free
self-compiling x86-64 ELF64 compiler & toolchain (`tools/sxc_native.sa`)** are
complete:
- `selfhost/native_aot.c` (4,598 lines of C) and **every other non-anchor `.c`
  and `.h` file in the repository** (`selfhost/seed/sxc_seed.c`,
  `selfhost/seed/sx_runtime.h`, `selfhost/rc_runtime.h`,
  `selfhost/rc_runtime_stress.c`, `selfhost/seed_builder_registry_test.c`) have
  been retired and replaced by pure Sayanox (`.sa`) programs, leaving
  **`selfhost/seed/sxc_seed_min.c` as the sole `.c` or `.h` file in the entire
  repository** (enforced by `make test-trust-anchor`, `make verify-seed`, and CI).
- `tools/sxc_native.sa` compiles itself directly to a static Linux x86-64 ELF64
  executable with **zero C compiler (`cc`) and zero libc** to a byte-identical
  fixed point (`sxc_native_gen2.elf == sxc_native_gen3.elf`), and compiles the
  entire Sayanox toolchain — including `selfhost/native_aot`,
  `selfhost/seed/sxc_seed`, `tools/sayanox_lsp`, `tools/sxpkg`, `tools/sxdiag`,
  `tools/sxfmt`, `tools/sxbuild`, `tools/sxsuite`, `tools/sxisaexec`,
  `tools/sxirexec`, `tools/sxmod`, `tools/native32`, `tools/emit_to_ir`, and the
  20,138-line `selfhost/compiler_min.sa` itself — directly to static ELF64
  binaries (`make test-sxc-native`).
- The remaining **14 tracked POSIX-shell scripts are now retired**. Their test,
  LSP probe, pack/restore, local HTTP/crawler and transfer-mock logic is in
  `tools/{sxsuite,sxlsp_probe,sxpkg_transfer_test,sxnet_test,sxpack}.sa`;
  `git ls-files '*.sh'` is pinned to empty by `make test-trust-anchor` and
  `make test-language-deps`. The Makefile retains only essential inline
  bootstrap recipes (the compiler-source recovery fallback still needs the
  host's `base64` and `gzip`, before Sayanox can build `sxpack`).
- Joined by `tools/sxsuite.sa` (pure-Sayanox replacement for 6 compiler test
  suites, `make test-sxsuite`), `tools/sxisaexec.sa` (user-mode ARM64 AArch64 +
  RISC-V RV64IM ELF64 instruction emulator with scalar FP/syscall probes and 6-way parity,
  `make test-sxisaexec`), `tools/sxmod_lib.sa` + `tools/sxmod.sa --transitive`
  (multi-directory diamond/chain `module` DAG resolver, `make test-sxmod-deep`),
  `tools/sayanox_lsp.sa` (module-aware IDE resolution, multiline
  `signatureHelp`, lexical block shadowing, and `prepareRename`,
  `make test-lsp-ide`), and 5 universal stdlib modules (`stdlib/{map,sort,path,cli,bytes}.sa`,
  `make test-stdlib-extended`).
Only the pinned C seed (`selfhost/seed/sxc_seed_min.c`, Phase E option 2) and
the top-level `Makefile` (including inline POSIX recipe commands) remain
outside `.sa`, so `make all-sayanox` still fails closed on purpose.

The goal is simple to state: every maintained piece of *logic* in this
repository is a Sayanox program, and the only non-Sayanox source pieces left
are the smallest possible bootstrap seam and the build driver. Online package
transfers still delegate socket I/O to external curl/wget; optional local
network fixtures use Python's HTTP server.

## Where the tree is today (measured 2026-10-25)

| Layer | Language | Size | Sayanox? |
|---|---|---:|---|
| Compiler (`selfhost/compiler_min.sa` + module) | Sayanox | 20,138 lines | **yes** |
| C-free self-compiling x86-64 ELF64 compiler (`tools/sxc_native.sa` + `tools/sx*_lib.sa`) & Stage-2 native backend (`selfhost/native_aot.sa`) | Sayanox | 11 modules | **yes** (compiles itself & all tools with zero `cc`) |
| Full-seed compatibility compiler (`selfhost/seed/sxc_seed.sa`), GC/registry harnesses (`rc_runtime_stress.sa`, `seed_builder_registry_test.sa`), `sayanox_lsp`, `sxpkg`, `sxfmt`, `sxdiag`, `sxsuite`, `sxisaexec` (AArch64 + RV64 F/D-subset ELF64 emulator), `sxirexec`, `emit_to_ir`, `sxbuild`, `sxmod` (`--transitive` DAG), `native32` (4-ISA), `sxaudit`, `sxlink`, `sxencode`, `sxdefs`, `sxinfer`, `sxruntime`, `sxgc`, `sxemit`, and 17 `stdlib/*.sa` modules | Sayanox | 34+ programs | **yes** |
| Non-anchor `.c` / `.h` files anywhere in the repository | — | **0 files** | **retired (`make test-trust-anchor`)** |
| Seed (`selfhost/seed/sxc_seed_min.c`) | C | 2,176 lines | no — **the sole `.c`/`.h` file in the repo**, documented, auditable and pinned (Phase E option 2, `make test-trust-anchor`) |
| Top-level CI entry points (`Makefile` + inline recipes alongside `tools/sxbuild.sa` + `tools/sxsuite.sa`) | make / POSIX recipe shell | ~5,400 lines; **0 tracked `.sh`** | no |

The tree also stopped carrying a second copy of itself on 2026-10-21: about
380 KB of base64 chunk directories (`native_src/`, `stage2_blob/`,
`sxc_full_b64*`, `sxc_full_lines/`, `sxc_sa_parts/`, `sxc_out_c/`,
`stage2_template_parts/`, `codegen_*.b64`, `sxc*.sa.b64`,
`compiler_min.sa.gz.b64{,.p0...p3}`) restored files that already existed as
plaintext, and 33 abandoned documents described architectures that no longer
exist. `DEPENDENCY.md` lists every deletion with the reason.

Ten tracked C helpers that nothing referenced (`inject_chr.c`, `inject_gc.c`,
`inject_types.c`, `prove_loop.c`, `prove_recompile.c`, `fixup_emit.c`,
`sx_launcher.c`, `sx_driver.c`, `build_stage2.c`, plus `stage2_expand.inc`)
were deleted on 2026-10-17, and the three 30-line Stage-2 toys on 2026-10-21.
The tree now has **1** tracked C/header/inc file (`selfhost/seed/sxc_seed_min.c`),
with zero other `.c` or `.h` files anywhere in the repository.

The 2026-10-17 language-dependency pass already removed bash, awk, sed,
Python, Perl, Node and Ruby from the maintained paths
(`make test-language-deps`, part of `true-selfhost`). So the remaining
dependencies are exactly the five rows above — not interpreters, and not
package managers.

## Phases

Each phase ends with a gate, and each phase keeps `gen3 == gen4` green. No
phase may weaken an existing test to pass.

### Phase A — tool logic and interpreter freedom (done, 2026-10-17; all tracked shell scripts retired, 2026-10-25)

Compiler, formatter, local package commands, language server and the LSP binder
are `.sa`. The 14 remaining tracked `.sh` entry points have since been ported
or replaced with pure-Sayanox suites and tools; the tracked `.sh` count is now
zero. The offline compiler-source fallback remains a small inline Makefile
recipe because it must run before the Sayanox packer can be built. Gate:
`test-language-deps`.

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
3. **LSP test client and process builtins in Sayanox (done, 2026-10-17).**
   The language gained `spawn(path)`, `child_send(h, s)`, `child_recv(h, n)`,
   `child_line(h)`, `child_close(h)`, `make_dir(path)`, `make_link(target,
   path)` and `remove_path(path)`. `tools/lsp_workspace_test.sa` is the framed
   test client that used to be 127 lines of C: it spawns the server, holds
   initialize / symbol / reference / overlay / refresh / bad-root / cap
   sessions and asserts on the answers. Its stdout is byte-identical to the
   C client it replaced, which is how the port was accepted before the C file
   was deleted. `tools/` now contains no C at all.
   Gates: `test-proc-builtins`, `test-lsp-workspace`.
   Honest difference: `child_recv` reads up to `n` bytes and stops at EOF
   (the C client used `fread`, which loops); a silent child blocks the caller
   exactly as the C client's blocking read did.

4. **The package tool's file logic in Sayanox (done, 2026-10-18; the install
   loop followed on 2026-10-19).**
   `tools/sxpkg.sa` grew from 1,149 to 1,898 lines and now owns `publish`,
   `install-local`, the local-registry branches of `sync` and `fetch`, the
   `seed` folder creation, and — since 2026-10-19 — the whole offline half of
   `install`: `check-lock` preflights the names, `need-fetch` says which locked
   packages have no complete registry copy, and `install-cached` copies and
   reports them. `tools/sxpkg.sh` dropped from 345 to 347 lines while losing
   every `grep`, `cut`, `tr`, `cp`, `mkdir` and `rm -rf` in those paths, and
   with them the `while IFS='=' read` loop that walked `sx.lock` itself: it
   keeps `need_online`/`SAYANOX_ONLINE` (Sayanox has no `getenv`), the
   http(s) transport (`spawn` takes a path with no argv, so it cannot pass a
   URL to curl or wget), and the dispatch.
   New in the language's toolbox rather than in the compiler: `ensure_dir`
   (`mkdir -p`), `rm_tree` (`rm -rf`, via `read_dir` + `remove_path` recursion)
   and `copy_tree` (`cp -r src/. dst/`) are ordinary `make` functions built on
   the cut-#7 builtins; `toml_field` reads a `key = "value"` line the way
   `grep '^key' | cut -d= -f2- | tr -d '" '` did.
   Gates: the five sxpkg gates above **pass unchanged** (that is the
   acceptance test for a behavioural port) plus the new
   `test-sxpkg-sayanox-logic`, which pins publish's files and single report,
   install-local's folders and three exit codes, sync's index preflight and
   seed fallback, fetch's lock/pin and full rollback, and the three folder
   primitives.
   Honest differences, none of them load-bearing:
   * `install-local` now also creates `.sayanox/pkgs/<name>/` (the shell only
     made `.sayanox/pkgs` itself); it still copies into the registry only,
     exactly as before.
   * `install-local` exits 1 when the lock cannot be resolved, while a bare
     `./tools/sxpkg install` still prints its FAILED report and exits 0 —
     `test-pkgs` pins that, and the wrapper's `checked` has always mapped the
     report to a status. The status was added for the delegation, not to change
     the bare command.
   * a local `sync` that finds no INDEX reports `sxpkg: sync failed; using
     local seed` instead of `online sync failed`, and the fallback is the same
     `seed` command.
   * `sync` from a local registry refuses an unsafe index without writing it,
     where the shell needed a `mktemp` file to do the same.
   * online transport still invokes `curl` or `wget` through `run_command`; the
     security boundary is pinned by `tools/sxpkg_transfer_test.sa`, a pure-
     Sayanox mock transport suite. No tracked shell test driver is required.

### Phase C — package and process behavior in Sayanox (transport boundary remains)

Phase C started with the process and directory builtins (`spawn`, `child_*`,
`make_dir`, `make_link`, `remove_path` and the directory builtins), which
unblocked the tools. Package transfer policy and hardening are Sayanox. The
actual HTTP transport is still an external `curl` or `wget` executable:
`spawn(path)` takes no arguments, and `run_command` is used by `tools/sxpkg.sa`
to pass transport arguments. This is a documented dependency, not shell source.
`tools/sxpkg_transfer_test.sa` provides mocked curl/wget binaries and verifies
opt-in, path safety, rollback and cache verification with no network.
Tests: `test-sxpkg`, `test-sxpkg-polish`, `test-sxpkg-online-local`,
`test-sxpkg-transfer-hardening`, `test-sxpkg-online-optin`.

### Phase D — native backend in Sayanox

Port `selfhost/native_aot.c` (4,597 lines of x86-64 ELF emission) to Sayanox.
This is the largest piece. It started out needing three language features that
did not exist; all three are now answered (the third by a different route than
expected), and what is left is the port itself:

* a byte buffer with indexed writes at arbitrary offsets (`write_out` is
  append-only);
* integer bit operations for encodings (shifts, masks, `&`, `|`, `^`);
* a syscall/memory surface, or a way to emit an ELF section layout without raw
  pointers — **resolved the other way on 2026-10-20**: `tools/sxlink.sa` emits
  a complete ELF image layout with no pointers and no syscall surface, out of
  an ordinary list of numbers, so this bullet is closed by step 3 below rather
  than by a new language feature.

**Step 1 of Phase D (done, 2026-10-18): the language surface.** Two of the
three bullets are now in the language and gated. A byte buffer is an ordinary
list of numbers: `push` grows it, `xs[i] = v` patches it at an arbitrary
offset (it lowers to `sx_lset`), `len` bounds it, and `write_bytes(path, xs)`
writes the raw bytes — `write_file` cannot, because it takes a C string and
stops at the first NUL. `bytes_f64(xs, v)` appends the exact eight
little-endian IEEE-754 bytes of a double. `bit_and`, `bit_or`, `bit_xor`,
`bit_not`, `shl` and `shr` supply the encodings. seed-min and native refuse
all eight, exactly as they refuse every other late builtin.
Gate: `test-native-primitives` — it checks each operator against a value
computed in C and then *runs* a static x86-64 ELF executable that a Sayanox
program emitted with nothing but `push`, those operators and `write_bytes`.

Honest limits of step 1, recorded rather than hidden: a Sayanox number is a C
`double`, so a bitwise result at or above 2^53 is rounded when it becomes a
number (exact below 2^53, which covers every register, prefix, ModRM and
displacement an emitter needs; `bit_not(x)` for a small `x` is the one call
whose result is never exact, so the idiom is `bit_and(bit_not(x), mask)`);
`write_bytes` refuses a byte outside `0`-`255`; and there is still no
list-typed builtin return, which is why the double splitter is `bytes_f64`
instead of a `f64_bytes` that returns a list.

**Step 2 (2026-10-20): `read_bytes`, the reader the byte-buffer surface was
missing.** `write_bytes` could put a byte buffer on disk but nothing could read
one back, because `read_file` returns a C string and an ELF image is mostly NUL
bytes and page padding. `read_bytes(path, xs)` appends every byte of a file to
`xs` and gives the count, or `-1` when it cannot be read (and then appends
nothing). It appends rather than returning a fresh list for the same reason
`bytes_f64` does: the codegen still has no list-typed return for a builtin.
Gate: `make test-read-bytes` — a round trip through a NUL byte and a `0xFF`
byte, the append-on-second-read contract, the `-1`, and the refusal by seed-min
and by the native backend.

**Step 3 (2026-10-20): the ELF image writer and linker are Sayanox.**
`tools/sxlink.sa` (about 330 lines, built by gen2 and cc like every other tool)
is `write_elf()` rewritten in the language: the ELF header, the three program
headers, the page rounding, the padding, the collector's heap cursor
(`OFF_CUR`/`OFF_END`) and every rel32 fixup — call sites and the
`lea r12,[rip+disp32]` that reaches the data segment. It is written against a
seam, not against the C source: `SX_LINK_DUMP=<dir>` makes `native_aot` dump
exactly the three inputs of the image writer (`code.bin`, `data.bin`, and
`patch.bin` — one 16-byte record per rel32 site, site then resolved target —
plus `meta.txt` with the call-patch count), the same convention as
`SX_EMIT_LOG`, changing no emitted byte.

Gate: `make test-native-sxlink`, part of `native-test`. Five fixtures — a bare
program, recursion, a data segment full of strings plus a collection, a
string-ordering program and a multi-page code segment — each compiled twice,
with and without the dump, and the two images must be identical; then the
Sayanox-linked image must be **byte-identical** to the C-linked one and must
**run** and print the same thing. Missing dump directory and a non-ELF input
are clear errors. Because byte identity is only evidence while the two
implementations agree, the gate also pins the layout `sxlink` hard-codes — the
ELF ident, `e_phnum == 3`, the entry point at `BASE + 0x1000`, and `p_offset`
of the code and data segments — so a change on the C side fails with the reason
instead of as an unexplained `cmp` diff.

What step 3 does *not* claim, stated plainly:

* `native_aot` still resolves a `make` name or a builtin name to a code offset,
  so the patch records arrive with their targets already resolved. The Sayanox
  linker turns offsets into bytes; it does not turn names into offsets.
* The C `write_elf()` is still what `make native` and `make native-test` use to
  produce the executables those gates run. `sxlink` is proved equivalent to it
  on the fixtures and is not yet wired in as the producer, because wiring it in
  means the native backend's output path depends on gen2 — a real ordering
  change to the bootstrap, and the next step, not this one.
* The rest of `selfhost/native_aot.c` — the scanner, the parser, the type
  inference, the encoder tree, the 856-line runtime and the 339-line collector
  — is still C. Its row stays in the table above with its line count.

**Step 4 (2026-10-21): the instruction encoder is Sayanox.** Everything in
`native_aot.c` that writes a byte into `code[]` does it through about fifty
primitives in the encoder region — `rexb`, `emit_modrm`, the `mov`/`lea`/arith/
shift/SSE2 helpers, the two stores the phase-4 runtime writes with, and the
label/ patch machinery (`L_new`, `L_bind`, `J_cc`, `J_mp`, `patch_imm32`,
`erel32`, `erel32j`). `tools/sxencode.sa` (1,159 lines, built by gen2 and cc
like the other tools) is those primitives in Sayanox, driven by a new seam.

Why a fourth seam: `SX_EMIT_LOG` is written for a reader, and it drops exactly
the decisions an encoder makes. `add %rax,%rbx` does not say `0x01` or `0x03`;
`mov [r12+rcx*8-16],%rax` does not say whether the displacement cost one byte or
four; and `J_cc`/`J_mp`, which the runtime uses for its own control flow, are not
in the instruction list at all. `SX_ENCODE_LOG=<path>` therefore records the
encoder's **own calls** — one line per primitive, its name and the integer
arguments it was handed — plus one `b <byte>` line for each byte `e1()` appends.
64-bit immediates travel as two 32-bit halves, because a Sayanox number is a C
double and is exact only below 2^53.

Gate: `make test-native-sxencode`, part of `native-test`. Five fixtures replay
to **byte-identical** `code.bin` (4,912 to 15,380 bytes each), the recorder
changes no emitted byte, the fixture set exercises all fifty records, and a
missing log, a wrong-length `code.bin` and an unknown record are clear errors.
The comparison is worth more than a diff for three reasons:

* every named record is followed by the bytes C wrote for that same call, and
  the replay stops on the first disagreement — a wrong ModRM fails at the
  instruction, not in a later `cmp`;
* the label table is the C one, including the runtime's `nlbl = 0` resets
  before each helper, so `L_new` records carry their id and re-binding a label
  patches exactly the sites C patched;
* `tools/sxencode.sa` keeps `MAXLBL` 96 and 24 references per label, and
  refuses a stream that exceeds them.

What step 4 does *not* claim, stated plainly:

* `native_aot` still drives its own encoder to produce the executables the gates
  run. Making `sxencode` the producer has the same consequence, and the same
  reason to wait, as making `sxlink` the producer.
* the bytes the phase-4 runtime writes **by hand** — the 856-line stub block and
  the collector, written as `e1(...)` literals rather than through an encoder —
  reach the replay as raw `b` records and are copied, not encoded. The whole
  file is compared, so they are covered, but they are not ported: what is ported
  is the encoder, which is what every byte of a user program goes through.
* the stream carries label ids and absolute patch offsets. Turning a `make` name
  or a builtin name into an offset is still the C frontend's job, exactly as
  `sxlink` receives resolved rel32 targets.
* the scanner, the parser, the type inference, the emit tree, the runtime stubs
  and the collector are still C. The row above stays in the table with its line
  count, and `native_aot.c` grew by the seam rather than shrinking.

**Step 5 (2026-10-23): phase 1 of the front end is Sayanox.** Steps 3 and 4
are *replays*: `sxlink` is handed a code blob and resolved patch records, and
`sxencode` is handed a list of encoder calls, so both are checked against
decisions the C front end already made. `tools/sxdefs.sa` (1,118 lines,
built by gen2 and cc like the other tools) is the first piece that reads the
**program text**. It is the two passes `native_aot` runs before anything
else:

* `expand_use()` — splice every `use "path"` line, depth at most 8, each path
  tried against the *top* file's directory first and then as written (a
  nested `use` resolves against the file named on the command line, not
  against the file it is written in), comments left alone, and the newline
  that ended the `use` line preserved;
* `collect_defs()` — walk the expanded text at the top level, with the same
  string-aware statement skipping, and build the four tables every later pass
  reads: concrete structs with their field names, generic struct **templates**
  (`struct Box<T> { v }`, which deliberately take no `S[]` slot), functions
  with their parameter names, typed-signature kinds, type parameters and
  return kind, and the globals a top-level `hold` declares with the kind and
  struct identity of its annotation.

The seam is `SX_DEFS_DUMP=<dir>`: `native_aot` writes `expand.sa` (the
expanded source, byte for byte) and `defs.txt` (the four tables in
declaration order) **between `collect_defs()` and `infer()`**, and changes
nothing else. Dumping before `infer()` is the point: phase 1 deliberately
leaves the field kinds, the unannotated global kinds and every generic
instantiation unset, so each `kind=-1` in the dump is part of the contract
and the comparison tests one pass instead of two.

Gate: `make test-native-sxdefs`, part of `native-test`.

* **Byte identity** of both outputs on nine fixtures, including two with a
  two-level `use` splice (34,114 expanded bytes for
  `stdlib_json_deep_test.sa`) and the 1,159-line `tools/sxencode.sa`. A
  fixture that phase 1 accepts but a later pass refuses is still compared —
  the dump exists either way — and the inertness check then compares the
  whole run: same stdout, same stderr, same image when one was produced.
* **Identical diagnostics** for 34 out-of-subset programs (33 distinct
  messages) and for the real 20,106-line compiler, which fails phase 1 at
  `make sxfenv: at most 6 params`. Same text after the tool name, same exit
  status. A port that parses the same programs but explains itself
  differently is not the same pass.
* **The contract pinned by content**, so a change on *both* sides still fails
  with a reason: the two-level splice reaching the function table, the
  generic templates, a generic signature's per-parameter type indices,
  `str`/`list`/struct annotations, every field kind still `-1`, exactly six
  globals, and no block-local name in the global table.

What step 5 does *not* claim, stated plainly:

* `native_aot` still runs its own phase 1 to compile anything. `sxdefs` is
  proved equal to it on fixtures and is not wired in as the producer, for the
  same reason `sxlink` and `sxencode` are not.
* Kind inference (`pk_*`, the fixpoint and the generic instantiation it
  drives), the emit tree, the 856-line runtime and the collector are still C.
  `native_aot.c` grew from 4,498 to 4,597 lines by the seam.
* `tools/sxdefs.sa` reads its input with `read_file()`, which stops at a NUL
  byte, and reports a `use` path that names a directory as "cannot open use
  file" where C's `access(R_OK)` lets it through to a read error. Both are
  written down in the file's header rather than hidden.

The **encoder seam** built earlier (`SX_EMIT_LOG`, `test-native-emit-split`,
`test-native-ir-log`) is what makes the remaining port incremental: a Sayanox
backend is written against a pinned instruction list rather than against the C
source. `SX_LINK_DUMP` is the same idea one stage later, at the image instead
of at the instruction.

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

### Phase E decision (2026-10-23): option 2, and it is now measured

**Option 2 is chosen: the minimal C seed stays, as a documented, auditable,
pinned exception.** Option 1 is not ruled out for ever, but it needs
something this repository does not have — a reproducible way to rebuild the
prebuilt binary from `.sa` with the Sayanox native backend, which means
`native_aot` itself in Sayanox (Phase D) first.

Choosing is not enough on its own, so the exception is now machine-checked by
`make test-trust-anchor`:

| Pinned | Value on 2026-10-23 |
|---|---|
| the anchor is one file | `selfhost/seed/sxc_seed_min.c` — the `seed-min` rule compiles it and nothing else; `gen1_min.c`, `gen2.c`, `gen3.c`, `gen4.c` are all generated and gitignored |
| size | 2176 lines, 100 919 bytes |
| SHA-256 | `e4cc34b41041044579ee34ab05c32997f3ad45adbe88973d8403ae43a2a01cb9` |
| who computes it | `tools/sxaudit.sa` — **Sayanox**, using `stdlib/crypto.sa`, compiled by gen2 |
| headers | exactly four: `ctype.h`, `stdio.h`, `stdlib.h`, `string.h` |
| forbidden, count 0 | `system`, `fork`, `exec*`, `dlopen`, `dlsym`, `socket`, `connect`, `setuid`, `unlink`, `rename`, `chmod`, `remove`, `tmpnam`, `getenv` |
| the one shell-out | exactly one `popen`/`pclose`/`curl`, and it is **emitted runtime text**, not compiler code: the `sx_http` function behind the `http_get` builtin. The compiler itself never shells out; every program it compiles carries that one site |
| behaviour | compiling the 19 600-line compiler twice gives byte-identical C |

That last-but-one row is the kind of thing an audit is *for*. "The seed does
not shell out" and "programs the seed compiles cannot shell out" are
different statements, and only the first one is true. The gate pins the
count at one so a second site cannot appear quietly.

**What this does not fix.** The seed compiled the compiler that compiled the
auditor. A hash pin is tamper evidence against drift and unreviewed edits; it
is not immunity from a seed that was already malicious, which is Thompson's
"Reflections on Trusting Trust" and needs a second independent implementation
to diverse-double-compile against. There is no second implementation here, so
that remains open and is written down rather than hashed over. C is still the
trust anchor — it is now a *measured* one, with a size, a digest, a surface
and a behaviour that cannot change without a reviewer saying so.

`make all-sayanox` still exits 1, and `test-trust-anchor` asserts that it
still refuses the claim. The seed row in the inventory stays exactly as
honest as it was.

## Progress log

* **2026-10-23 — Phase D step 5.** `tools/sxdefs.sa` is the native backend's
  phase 1 — `use` expansion and `collect_defs()` — in Sayanox, checked against
  a new `SX_DEFS_DUMP` seam (`test-native-sxdefs`, part of `native-test`):
  nine fixtures produce byte-identical expanded source and byte-identical
  definition tables, 34 refusals and the 20,106-line compiler produce
  identical diagnostics and exit statuses, and the dump changes no emitted
  byte. It is the first ported piece that reads program text rather than
  replaying a recorded stream. `native_aot.c` grew from 4,498 to 4,597 lines
  by the seam and is still C.
* **2026-10-21 — Phase B.5: `run_command(cmd)` and four drivers leave the shell.**
  `spawn(path)` starts a program with no arguments, which is why every driver
  that ran `gen2 in.sa out.c` had to stay in POSIX sh. `run_command(cmd)` closes that
  gap: one command line, `/bin/sh -c`, exit status as a number, stdout and
  stderr inherited. It is wired through the same 16 sites as every other
  builtin, seed-min and the native backend refuse it, and the language docs
  describe it as a driver primitive rather than a build system.
  `tools/sxdiag.sa` is the first consumer, and it replaced four shell files:
  `selfhost/test_return_paths.sh`, `test_name_resolution.sh`,
  `test_inline_expression_errors.sh` and `test_list_postfix_errors.sh`. The
  cases they checked (23 inline, 7 postfix, 14 return-path, 31
  name-resolution refusals) now live in Sayanox, with an unknown-suite refusal
  and two accept-everything controls so the assertions cannot become
  decoration (`make test-sxdiag`, part of `native-test`). The same day the tree
  lost 224 dead files and the compiler gained no other change, so the whole
  suite was re-run: `gen3 == gen4` still holds.
* **2026-10-21 — Phase D step 4.** `tools/sxencode.sa` is the x86-64
  instruction encoder in Sayanox, replayed against a new `SX_ENCODE_LOG` seam
  (`test-native-sxencode`): five fixtures rebuild `code.bin` byte-identically,
  every named record is checked against the bytes C wrote for the same call, and
  the recorder changes no emitted byte. Two C changes came with it, both
  byte-identical on all 23 native fixtures: a jump whose label is already bound
  now emits its displacement instead of writing zeros and patching them in
  place, and `L_new` logs the id it hands out because the runtime helpers reset
  the label counter. `native_aot.c` grew from 4,415 to 4,498 lines and is still
  C.
* **2026-10-20 — Phase D steps 2 and 3.** `read_bytes` joined the byte-buffer
  surface (`test-read-bytes`), and `tools/sxlink.sa` rewrote the native
  backend's ELF image writer and rel32 linker in Sayanox against a new
  `SX_LINK_DUMP` seam (`test-native-sxlink`): five fixtures link
  byte-identically to C's `write_elf()` and run identically, and the dump
  changes no emitted byte. `selfhost/native_aot.c` grew by the seam and is
  still C; its row above is unchanged. CI moved to parallel gate jobs the same
  day (`.github/workflows/ci.yml`, plus a nightly sequential
  `full-bootstrap.yml` that keeps the no-hand-off claim verified).
* **2026-10-19 — a compiler bug fixed, not a language change.** The `make`
  signature pre-pass did not understand `//` comments (its comment flag is
  declared but never set), so a double quote inside a comment toggled string
  mode and every later `make` lost its typed parameter list; the raw parameter
  parse then read `a: num, b: num` as four untyped parameters and the generated
  C stopped compiling. It surfaced while porting `tools/sxpkg.sa`. The pre-pass
  now recognises `//` and runs to the end of the line, the way the real lexer
  already did, and `make test-comment-quotes` pins it from both ends — the same
  fixture is compiled with the fix reverted to prove the gate distinguishes.
  The whole suite was re-run because the compiler is the one file where a small
  change moves a long list of generated C files.
  Logs: `docs/gate-logs/2026-10-19-comment-quotes/`.
* **2026-10-17 — Phase B.2 done.** Directory builtins + Sayanox folder index;
  `tools/lsp_workspace.h` and `tools/lsp_workspace_bind.sa` deleted. The tree
  has 11 tracked C/header/inc files, down from 23 at the start of the day.
* **2026-10-18 — Phase B.3 done.** Process builtins (`spawn`, `child_send`,
  `child_recv`, `child_line`, `child_close`, `make_dir`, `make_link`,
  `remove_path`) and a Sayanox LSP framed-session test client;
  `tools/lsp_workspace_test.c` deleted, so `tools/` holds no C. The tree has
  10 tracked C/header/inc files, down from 23 at the start of the phase.
* **2026-10-17 — Phase B.1 done.** `tools/emit_to_ir.c` deleted;
  `tools/emit_to_ir.sa` (328 lines) built by gen2 and cc through the Makefile,
  identical output on the real 1,182-line `SX_EMIT_LOG`, the audit mode, the
  long-line case and all five exit-status cases.
* **2026-10-17 — `exit(n)` builtin added** to the Sayanox compiler for CLI
  tools (`gen1_min`/`gen2`/`gen3`), with `make test-exit-builtin`; seed-min and
  native refuse it.
* **2026-10-17 — dead C removed.** Ten tracked helpers with no reference.

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

## Current next phase

### Phase F — full ARM64 and RISC-V native backend (in progress; started 2026-10-25)

The goal is to extend `tools/native32.sa` from integer expressions and static
string spans to full string/list/struct/function support, IEEE-754 values, file
I/O, and GC, compiling and executing natively for AArch64 and RV64GC. The
recent static-string slice is useful but does not close the compiler/runtime
milestone; a capable ELF emulator is necessary for proof but does not itself
mean the backend is complete.

**Verified compiler slice:** static-string values now use image-backed
pointer+length globals and support literal assignment/reassignment and `show`
on i386, AArch64, and RV64IM. `make test-sxisaexec` includes six-way parity
for branch- and loop-dependent string lengths, as well as the earlier integer
fixtures.

**Verified emulator-only probes:** `tools/sxisaexec.sa` executes scalar
IEEE-754 S/D arithmetic and Linux `openat`/`read`/`write`/`close`/`exit` on
both architectures against temporary host files. The virtual file table is
intentionally bounded to one open file and 64 KiB per file; it is test
infrastructure, not the target runtime ABI.

Still open for the backend: general heap-backed/dynamic string operations
(beyond the bounded variable-to-variable `concat` slice), lists, structs, user
`make`/`give`, IEEE-754 code generation and formatting, native file I/O,
mark-and-sweep GC, full RV64GC/AArch64 coverage, and broad parity for each.
Until these are implemented and gated, native32 is a deliberately limited
compiler subset, not a full-language native compiler claim.
