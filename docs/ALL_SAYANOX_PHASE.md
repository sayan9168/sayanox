# All-in-Sayanox: the next phase

Status: **next phase — in progress.** Recorded 2026-10-17, immediately after
the language-dependency pass. Phase A is done and Phase B has started (the IR
translator is Sayanox; see the table). No target reports success for the whole
phase: `make all-sayanox` still fails closed on purpose.

The goal is simple to state: every maintained piece of *logic* in this
repository is a Sayanox program, and the only non-Sayanox pieces left are the
smallest possible bootstrap seam and the build driver.

## Where the tree is today (measured 2026-10-20)

| Layer | Language | Size | Sayanox? |
|---|---|---:|---|
| Compiler (`selfhost/compiler_min.sa` + module) | Sayanox | 19,577 lines | **yes** |
| Formatter, package tool, language server, IR tool, LSP test client, ELF linker | Sayanox | 6 programs | **yes** |
| All tests and fixtures | Sayanox + `sh` drivers | 280 `.sa` files, 1,183,149 bytes | **yes** (logic) |
| Seed (`selfhost/seed/sxc_seed_min.c`) | C | 2,035 lines | no |
| Native AOT backend (`selfhost/native_aot.c`) | C | 4,415 lines | no — its ELF image writer and rel32 linker are now also Sayanox (`tools/sxlink.sa`, byte-identical); the C one still produces the executables the gates run |
| Build driver (`Makefile` + 25 `sh` scripts) | make / POSIX sh | 4,987 lines | no |

Ten tracked C helpers that nothing referenced (`inject_chr.c`, `inject_gc.c`,
`inject_types.c`, `prove_loop.c`, `prove_recompile.c`, `fixup_emit.c`,
`sx_launcher.c`, `sx_driver.c`, `build_stage2.c`, plus `stage2_expand.inc`)
were deleted on 2026-10-17. The tree now has 10 tracked C/header/inc files:
the seed, the native backend and their test/stress harnesses.

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
   * the http(s) halves of `sync`, `install` and `fetch` are unchanged shell,
     including the `.fetch.XXXXXX` staging directory and its `trap` rollback.

### Phase C — package and process behavior in Sayanox (in progress)

Phase C started with the process and directory builtins (`spawn`, `child_*`,
`make_dir`, `make_link`, `remove_path` and the directory builtins), which is
what unblocked everything below. What is left of Phase C is the network
transport itself, and it is blocked by the language rather than by effort:
`spawn(path)` takes no arguments, so Sayanox cannot run
`curl -fsSL --connect-timeout 10 --max-time 60 <url> -o <part>`, and
`selfhost/test_sxpkg_transfer_hardening.sh` mocks `curl`/`wget` through `PATH`
and asserts `$MOCK_CALLS` contains them, so switching to `http_get` would
break a gate that must stay unchanged. `docs/SXPKG_ONLINE.md` records the same
boundary. The portable slice is done; the transport is a documented exception,
not a missing step.
Tests: `test-sxpkg`, `test-sxpkg-polish`, `test-sxpkg-online-local`,
`test-sxpkg-transfer-hardening`, `test-sxpkg-online-optin` must pass unchanged.

### Phase D — native backend in Sayanox

Port `selfhost/native_aot.c` (4,415 lines of x86-64 ELF emission) to Sayanox.
This is the largest piece and needs language features that do not exist yet:

* a byte buffer with indexed writes at arbitrary offsets (`write_out` is
  append-only);
* integer bit operations for encodings (shifts, masks, `&`, `|`, `^`);
* a syscall/memory surface, or a way to emit an ELF section layout without raw
  pointers.

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
are clear errors.

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

Neither option is implemented. Until one is, the seed row above stays honest
and `make all-sayanox` keeps failing.

## Progress log

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
