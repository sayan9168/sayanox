# Status

Last updated: **2026-10-25** (C-free self-compiling x86-64 ELF64 compiler &
toolchain `tools/sxc_native.sa` compiling itself, all 30+ tools including
`sayanox_lsp`/`sxpkg`/`sxdiag`, and 20,138-line `compiler_min.sa` directly to
static Linux ELF64 binaries with zero `cc` and zero libc; all non-anchor
`.c`/`.h` files retired so `selfhost/seed/sxc_seed_min.c` is the sole tracked
C/H file; all 14 remaining tracked `.sh` scripts ported to `.sa` tools;
`tools/sxsuite.sa` 6-suite compiler test runner; `tools/sxisaexec.sa` user-mode
AArch64 and RV64IM emulator with 6-way integer parity plus initial scalar FP
and file-syscall probes; `tools/sxmod_lib.sa` transitive
multi-directory `module` DAG resolver; `tools/sayanox_lsp.sa` module IDE,
multiline `signatureHelp`, lexical block shadowing, and `prepareRename`; and
5-backend `stdlib/{map,sort,path,cli,bytes}.sa`)

The short version — every finished item next to the `make` gate that proves
it, and every unfinished item next to the place the build refuses to claim it
— is the two status tables at the top of
[`../README.md`](../README.md#status). This file is the long version.

Seven of the open roadmap rows moved, each with a gate that fails without the
new code:

* **Phase D step 5: the native backend's phase 1 is Sayanox.**
  `tools/sxdefs.sa` (1,118 lines) is `expand_use()` and `collect_defs()` —
  the `use` splice and the struct / generic-struct / function / global tables
  `selfhost/native_aot.c` builds before anything else. It is the first ported
  piece that reads the **program text** instead of replaying a recorded
  stream (`tools/sxlink.sa` is handed a code blob, `tools/sxencode.sa` a list
  of encoder calls). The seam is `SX_DEFS_DUMP=<dir>`, which writes
  `expand.sa` and `defs.txt` *between* `collect_defs()` and `infer()` and
  changes nothing else — so every `kind=-1` in the dump is phase 1 saying
  "not my job", and the comparison tests one pass instead of two.
  `make test-native-sxdefs` (part of `native-test`) requires byte identity of
  both files on nine fixtures — including a two-level `use` splice that
  expands to 34,114 bytes and the 1,159-line `tools/sxencode.sa` — **and**
  identical diagnostics: 34 out-of-subset programs (33 distinct messages) and
  the real 20,106-line compiler are refused by both with the same text after
  the tool name and the same exit status. The table shape is pinned by
  content as well, so a change on both sides still fails with a reason.
  **Kind inference, the emit tree, the 856-line runtime and the collector are
  still C**, and `native_aot` still runs its own phase 1 to compile anything:
  `sxdefs` is proved equal to it, not wired in as the producer.

* **Multi-ISA machine-code targets (row 9).** `tools/native32.sa` compiles a
  bounded Sayanox subset to i386, AArch64 and RV64IM Linux ELF with its own
  front end, encoders and container writers. Integer expression parity and
  ELF layouts are pinned; `make test-sxisaexec` also checks static-string
  values and bounded variable-to-variable concat end-to-end across six
  execution paths. Fifteen unsupported programs are refused on each target.
  **This is not the full compiler/runtime**: general string operations, lists,
  structs, user functions, FP code generation, file I/O and GC remain open.
  `/` stays refused because Sayanox numbers are doubles.

  `tools/sxisaexec.sa` now executes the generated AArch64 and RV64IM images on
  this x86-64 host. `make test-sxisaexec` retains six-way integer parity,
  executes the reviewed AArch64/RV64 goldens, and pins emulator faults. An
  initial interpreter slice additionally executes scalar S/D floating-point
  arithmetic and openat/read/write/close file operations on real temporary
  files. Those emulator features are not yet emitted by `native32`; neither
  the compiler nor its runtime is full-language yet ([NATIVE32.md](NATIVE32.md)).

* **The last two readiness probes (row 1 — the claim itself stays open).**
  A struct literal field may now be a whole checked expression
  (`Size { bytes: len(text) + 1 }`, `(2 + 3) * 4`, `offset() + twice(3)`,
  `head + "anox"`), and an index may call a function the program declared
  with `-> num` (`values[twice(offset()) + 1]`). Both were gen2-only gaps:
  seed-min and native accepted them already, so
  `selfhost/full_language_expr.sa` prints the same eleven lines on all three
  (`make test-full-language-expr`). `make test-full-language-readiness` goes
  from four unmet checks to **8/8 passing**, and `make gen3` now runs it, so
  a regression breaks a hard gate. **This does not make the full-language
  claim**: four closure probes are not an acceptance specification,
  `true-selfhost-full` still fails closed, and the new gate asserts that
  refusal so the probes passing cannot quietly become a claim. Seed/native
  interpolation and struct function signatures are still open.

* **Nested generics (row 5).** A generic struct type argument may now be
  `list` or another instantiation: `Box<Box<num>>` is `Box__Box__n` holding a
  `Box__n`, `Box<list>` is `Box__l` holding the list pointer, and
  `Pair<Box<num>, str>` is `Pair__Box__n_s`. The blocker measured earlier the
  same day turned out to be one missing case, not a worklist: gen2 could not
  fill a struct-typed field from a *name* (`Outer { i }`), only from a nested
  literal, because the struct-literal walker looked names up in the string
  table and not in the struct-variable table. Inner instantiations are built
  first, so the mangled typedefs come out in an order C accepts with no sort,
  and the depth is bounded by the source text because a type argument is
  written out in full. `make test-generic-structs-nested` runs
  `selfhost/generic_struct_nested.sa` on seed-min, gen2 and native (eleven
  byte-identical lines) and pins all seven mangled typedefs plus their order;
  `make test-struct-field-struct` flipped from pinning gen2's refusal to
  pinning all three backends reading `o.b.v`. The 2026-10-16 decision that
  called the scalar-only boundary *permanent* is marked reversed in
  `docs/TYPES_ROADMAP.md` and `docs/GENERICS.md` rather than deleted.
* **Seed GC (row 3).** `selfhost/seed/sxc_seed_min` emits a non-moving
  conservative mark & sweep for builder strings, reusing the allocation
  registry it already kept as the block list. The program body moved into
  `static int sx_prog(void)` so that `main` can plant a stack anchor above
  every Sayanox variable; roots are the C stack only, interior pointers keep
  their block, nothing moves, and the scan opts out of ASan on purpose.
  `gc()` / `gc_live()` / `gc_runs()` now answer on all three backends.
  Measured here: gen1-min compiling the compiler peaks at **29,768 KiB
  instead of 1,278,704 KiB** (255 s → 272 s) and emits byte-identical gen2 C,
  so `make test-seed-bootstrap-budget` drops from a 1,536 MiB cap to 64 MiB.
  `make test-seed-collector` runs 4,000,000 dropped temporaries, a borrowed
  read and an untouched 512 KiB live string on seed-min, gen2 and native
  inside 64 MiB — the same fixture built by the previous seed dies with
  `sx: out of memory`. Strings only: seed lists are still never freed.
* **Stdlib (row 6).** `stdlib/crypto.sa` is SHA-256 and HMAC-SHA256 in the
  dialect all three backends accept — no bitwise operators, so the 32-bit
  words are carried in doubles and the rotations are division and remainder.
  `stdlib/json_deep.sa` reads nested JSON by path (`items[2].user.name`), with
  15 pinned refusals. `make test-stdlib-crypto` checks the FIPS 180-4 and RFC
  4231 vectors (and `sha256sum` when it is installed); `make
  test-stdlib-json-deep` checks 8 accepted documents, the 15 refusals, and
  that the new reader agrees with `json_util.sa` on flat objects. Both run on
  seed-min, gen2 and native.
* **Packages (row 7).** `pkg.meta` now records `sha256=` (the real digest of
  `main.sa`) and `origin=`, and `sxpkg sign` adds `signer=`/`sig=`, an
  HMAC-SHA256 over `name`, `version` and the digest. `sxpkg authenticate`
  reports `authentic` / `UNSIGNED` / `NOKEY` / `BAD <reason>`, and
  `SAYANOX_REQUIRE_SIGNED=1` turns "cannot check" into exit 1. This is a
  **keyed, symmetric** signature: the checker needs the same secret, so it is
  not a public-key signature and the documents say so everywhere.
  `make test-sxpkg-crypto` builds an actual `sum=` collision (`give` →
  `hJve` keeps `sum=718013937`) and requires `verify` to refuse it, which only
  the digest can do. A registry with no signatures gets byte-identical
  `verify` output to the pre-signature tool (`cmp`-checked).
* **LSP (row 8).** Definition, references and rename resolve the **binder** of
  a name instead of matching its spelling: a parameter or a `hold` inside a
  function body is answered inside that body only, a top-level name across the
  folder; words inside string literals and comments are not occurrences.
  Rename now reaches indexed files the editor never opened, and
  `workspace/didChangeWatchedFiles` is registered with the client and
  re-publishes diagnostics for files that change on disk. `make
  test-lsp-semantic` pins all of it, and fails on its first check against the
  previous server binary.
* **Logs:** `docs/gate-logs/2026-10-23-native-frontend-phase1/`,
  `docs/gate-logs/2026-10-22-crypto-json-signed-packages-lsp/`,
  `docs/gate-logs/2026-10-22-seed-collector/` and
  `docs/gate-logs/2026-10-22-nested-generics/`.
* **Still open:** row 1 (full-language self-host). Row 10 moved: module
  namespacing exists as a Sayanox source-to-source pass with its own gate
  (`make test-sxmod`), while the *compiler* still has textual `use` splicing
  and one flat name table.
  Row 9 moved: AArch64 and RV64IM images for the documented integer subset
  are emitted by `native32` and executed by the Sayanox `sxisaexec` emulator
  (`make test-sxisaexec`); its initial scalar FP/syscall probes are green,
  while the *native subset compiler* remains x86-64 only. Row 1 moved but is **not** closed: its four readiness probes
  pass on gen2 and gen3, while the claim still needs a reviewed acceptance
  specification, seed/native interpolation and struct function signatures.
  Row 5 is closed for the forms it named; a
  *concrete* struct name as a type argument stays refused on all three
  backends, and gen2 keeps its long-standing divergence of learning a field
  kind from a single contradicting literal.

---

# 2026-10-22 — the package tool is one Sayanox program

The package tool is one Sayanox program. `tools/sxpkg.sh` is deleted;
`tools/sxpkg.sa` (2,565 lines, built to `./tools/sxpkg` by `make sxpkg`) now
answers every command the wrapper answered — `init`, `add`, `list`, `remove`,
`seed`, `search`, `info`, `deps`, `verify`, `sum`, `publish`, `install`,
`install-local`, `sync`, `fetch` — plus the online opt-in policy,
`SAYANOX_ROOT`/`SAYANOX_REGISTRY`/`SAYANOX_ONLINE`, the `.part` staging, the
checksum acceptance, the rollback and its own exit statuses. Two builtins made
that possible: `run_command(cmd)` (2026-10-21) to start the transfer, and
`getenv(name)` (2026-10-22) to read what the shell used to read. There is no
`chdir`, so every path is built through the project root instead.

The one thing still outside Sayanox is the transfer *program* — `curl`, or
`wget` when there is no curl, found by scanning `PATH`. That is a decision, not
a gap: `test-sxpkg-transfer-hardening` mocks those two through `PATH` and
asserts they were called, so replacing them with the `http_get` builtin would
delete the test's subject. It is recorded in `docs/NO_BASH.md`.

Log: `docs/gate-logs/2026-10-22-package-tool-in-sayanox/`.

---

# 2026-10-21 — dead wood and `run_command`

The tree stopped carrying a second copy of itself on 2026-10-21. 288 tracked
files that no build, test or document read are gone: the base64 chunk
directories and loose bundles that restored files already present as plaintext
(`native_src/`, `stage2_blob/`, `sxc_full_b64*`, `sxc_full_lines/`,
`sxc_sa_parts/`, `sxc_out_c/`, `stage2_template_parts/`, `codegen_*.b64`,
`sxc*.sa.b64`, `compiler_min.sa.gz.b64{,.p0...p3}` — about 380 KB), the Stage-2
scaffolding that could only ever exit 1 (`stage2_template.c`, `sxc_full.c`,
`sxc_full_minimal.c`, `restore_stage2.sh`, `restore_sxc.sh`,
`restore_sxc_full.sh`, `restore_stage2_template.sh`, `selfhost/sx`,
`stage2_src/`), the last Python (`sayascrape/*.py`, 738 lines) with its
`test-scrape` target, 33 abandoned documents, and ~70 `.sa` demos, stage
sketches and examples that no target referenced. Nothing was removed to make a
gate pass: every surviving gate is unchanged or stricter, and
`test-doc-claims` now *asserts* the placeholders stay gone instead of asserting
that a 93-byte `PLACEHOLDER` file is still there.

Losing dependencies came with one language increment. `spawn(path)` starts a
program with no arguments, so every driver that ran `gen2 in.sa out.c` had to be
shell; `run_command(cmd)` (2026-10-21) gives a Sayanox program the exit status of a
command line. Four `sh` drivers became `tools/sxdiag.sa`: the 23 inline, 7
postfix, 14 return-path and 31 name-resolution refusals are now cases in a
Sayanox program, checked by `make test-sxdiag` with an unknown-suite refusal and
two accept-everything controls so the assertions cannot become decoration.

Phase D step 4 landed on 2026-10-21: the native backend's x86-64 instruction
encoder is Sayanox. `SX_ENCODE_LOG` records the encoder's own calls — one
record per primitive, plus one `b` line per byte `e1()` appends — and
`tools/sxencode.sa` (1,159 lines) replays them to a **byte-identical** code
segment on five fixtures (4,912 to 15,380 bytes each), checking every named
record against the bytes C wrote for that same call. The recorder is inert
(the ELF is identical with and without it), the fixture set exercises all 50
records, and a missing log, a wrong-length `code.bin` and an unknown record
are clear errors (`make test-native-sxencode`, part of `native-test`).
`selfhost/native_aot.c` is still C — 4,597 lines after the 2026-10-23 phase-1
seam, up from 4,415, not down — and its row below stays until the rest of the
front end, the emit tree, the runtime and the collector are ported. Logs:
[`2026-10-21 encode seam`](gate-logs/2026-10-21-encode-seam/).

Phase D moved before that and CI was fixed. `read_bytes(path, xs)` joined the byte-buffer
surface (it appends a whole file, NUL bytes included, and gives the count or
`-1`; `make test-read-bytes`), and the native backend's ELF image writer and
rel32 linker are now Sayanox: `tools/sxlink.sa` links five fixtures
byte-identically to C's `write_elf()` and its output runs
(`make test-native-sxlink`, against a new `SX_LINK_DUMP` seam that changes no
emitted byte). `selfhost/native_aot.c` is still C and its row below stays.
CI now runs the four gates as parallel jobs — one sequential job under
`timeout-minutes: 25` was being killed by the runner at 25m15s, so `main`
reported a timeout instead of a result. The new shape has been green three times
([1](https://github.com/sayan9168/sayanox/actions/runs/39477167629), [2](https://github.com/sayan9168/sayanox/actions/runs/39490134812), [3](https://github.com/sayan9168/sayanox/actions/runs/39494506063)) at 26m17s, 21m57s
and 29m31s wall, the longest single job 15m49s against a per-job 45m0s limit:
the headroom is per gate, and the run total moves with the runner, since gate 3
alone measured 5m49s to 15m49s for the same bytes. Alongside it,
`.github/workflows/full-bootstrap.yml` re-runs the whole chain in one job
nightly so the no-hand-off claim stays verified. Logs: [`2026-10-20 read_bytes + sxlink`](gate-logs/2026-10-20-read-bytes-sxlink/).

Language-dependency update: the maintained toolchain is now C, make, POSIX sh
and Sayanox — bash, awk, sed, Python, Perl, Node and Ruby are gone from the
maintained paths (`make test-language-deps`, part of `true-selfhost`). All four
required gates passed; gen3/gen4 remain byte-identical. Current logs:
[`2026-10-17 language deps`](gate-logs/2026-10-17-language-deps/). The next
phase is recorded below and in [ALL_SAYANOX_PHASE.md](ALL_SAYANOX_PHASE.md);
`make all-sayanox` fails closed. Older measurements below remain historical,
not new peak-RSS claims.

## Current verification

```sh
make doctor         # DOCTOR-OK
make true-selfhost   # TRUE-SELFHOST-MIN-OK (includes test-language-deps)
make gen3           # GEN3-OK; gen3.c == gen4.c byte-identical
make native-test    # NATIVE-TEST-OK (x86-64 Linux)
```

This pass's real final logs are
[`doctor`](logs/ten-remaining-final-doctor.log),
[`true-selfhost`](logs/ten-remaining-final-true-selfhost.log),
[`gen3`](logs/ten-remaining-final-gen3.log), and
[`native-test`](logs/ten-remaining-final-native-test.log). Dependency and
memory increments were separately gated (`ten-deps-*`, `ten-memory-*`). See
[`docs/logs/README.md`](logs/README.md) for scope and development failures.
The four targets were also run with Python/Node/Ruby/Perl and real curl/wget
blocked; package opt-in tests use an explicit failing transport stub.
Bootstrap requires make, a C99-capable toolchain, POSIX shell/utilities and
no network. See [DEPENDENCY.md](../DEPENDENCY.md): doctor checks core tools,
not every utility used by the expanded test suite.

## Language-dependency reduction (started 2026-10-17; shell-source ports completed 2026-10-25)

The bootstrap and default gates use C, make, inline POSIX recipes and Sayanox;
**zero tracked `.sh` files remain**. Bash, awk and sed are not invoked by the
maintained compiler or test suites. Optional local HTTP fixtures still use
Python as a server process; online package transfer still delegates to curl or
wget. This pass preserves the existing `gen3 == gen4` compiler fixed point.

* **Tracked shell-driver migration:** the last 14 test, LSP-probe, transfer,
  local-network, pack and restore scripts now live in `tools/sxsuite.sa`,
  `tools/sxlsp_probe.sa`, `tools/sxpkg_transfer_test.sa`, `tools/sxnet_test.sa`
  and `tools/sxpack.sa`; `git ls-files '*.sh'` is empty.
* **Sayanox offline packer:** Base64 encoding/decoding, chunking, gzip-stream
  round trips, and compiler/module byte comparisons are implemented in
  `tools/sxpack.sa`. The pre-bootstrap missing-compiler fallback remains an
  inline Makefile recipe because it runs before sxc_native can build sxpack.
* **Makefile shell boundary:** there are no script files, but inline recipes
  still invoke standard host utilities for the bootstrap and broad gate suite.
  No awk/sed command appears in a Makefile recipe.
* **Proof:** `make test-language-deps` pins zero tracked shell scripts, the
  Sayanox-owned packer, and interpreter-free selected build/test paths. It is
  an explicit boundary gate, not a claim that optional HTTP fixture setup has
  no Python dependency.

`make test-language-deps` is a boundary test of the exercised paths, not a
proof that an optional target (the opt-in Python HTTP tests) is interpreter
free. The small hand-written C seed and the C native backend remain, as does
the Makefile/POSIX-sh orchestration; see [NO_BASH.md](NO_BASH.md) and
[ONLY_SAYANOX.md](ONLY_SAYANOX.md).

## Next phase — all-in-Sayanox (in progress)

**Writing the remaining pieces in Sayanox is the next phase.** It is recorded
here so it is not lost, and it is machine-checked: `make all-sayanox` prints the
measured inventory below and **exits 1**, the same way `true-selfhost-full`
refuses a full-language claim. Plan: [ALL_SAYANOX_PHASE.md](ALL_SAYANOX_PHASE.md).

| Still not Sayanox | Language | Size (2026-10-20) | Unblocks |
|---|---|---:|---|
| `selfhost/seed/sxc_seed_min.c` | C | 2,176 lines (measured 2026-10-23) | Phase E — **decided 2026-10-23: option 2**, the minimal C seed stays as a documented, auditable, pinned exception (`make test-trust-anchor`: size + SHA-256 recomputed by Sayanox, four headers, no process/network call, deterministic output, the one emitted `popen` counted). Option 1, a prebuilt binary rebuilt from `.sa`, still needs Phase D |
| `selfhost/native_aot.c` | C | 4,597 lines | Phase D — the language surface, the ELF image writer/linker, the x86-64 instruction encoder and front-end phase 1 (`use` expansion + `collect_defs`) are done; what is left is kind inference, the emit tree, the runtime stubs and the collector |
| `Makefile` + 14 sh scripts | make / POSIX sh | 5,188 lines | Later — a Sayanox build driver still needs a built compiler first |

Already Sayanox and gated: the compiler (`compiler_min.sa`), the formatter, the
package tool — one binary since 2026-10-22, every command including the
online opt-in policy, `SAYANOX_ROOT` and its exit statuses; its shell wrapper
is deleted and only `curl`/`wget` is still an external program — the language
server (including its folder index since 2026-10-17), the IR translator
(`tools/emit_to_ir.sa`, byte-identical output), the directory builtins
(`test-path-builtins`), the process builtins (`test-proc-builtins`), the LSP
framed-session test client (`tools/lsp_workspace_test.sa`), the byte-buffer and
bitwise surface the native backend needs (`test-native-primitives`), its binary
reader (`read_bytes`, `test-read-bytes`) and, since 2026-10-20, the native
backend's ELF image writer and rel32 linker (`tools/sxlink.sa`,
`test-native-sxlink`), since 2026-10-21, its x86-64 instruction encoder
(`tools/sxencode.sa`, `test-native-sxencode`) and, since 2026-10-23, its
front-end phase 1 — the `use` splice and the definition tables
(`tools/sxdefs.sa`, `test-native-sxdefs`).
Ten unreferenced legacy C files were deleted the same day, alongside the three
that gained Sayanox replacements.

Phase D started on 2026-10-18 with `write_bytes`, `bytes_f64`, `bit_and`,
`bit_or`, `bit_xor`, `bit_not`, `shl` and `shr`: a byte buffer is an ordinary
list of numbers, `push` grows it, `xs[i] = v` patches it and `write_bytes`
puts it on disk without stopping at a NUL byte. `make test-native-primitives`
checks every operator against a value computed in C and then runs a static
x86-64 ELF executable that a Sayanox program emitted with nothing but those
builtins.

Phase D continued on 2026-10-20 with the reader that surface was missing and
with the first piece of the backend itself. `read_bytes(path, xs)` appends
every byte of a file to a byte buffer and gives the count, or `-1` when it
cannot be read — `read_file` cannot do that job because it returns a C string,
so an ELF image (mostly NUL bytes and page padding) arrives truncated. Then
`tools/sxlink.sa` rewrote `write_elf()` in the language: ELF header, three
program headers, page rounding, padding, the collector's heap cursor and every
rel32 fixup, using nothing but `push`, `xs[i] = v`, `len`, `%`, `shr`,
`bit_and`, `write_bytes` and `read_bytes`. It is written against a seam rather
than against the C source: `SX_LINK_DUMP=<dir>` dumps `code.bin`, `data.bin`,
`patch.bin` (one 16-byte record per rel32 site, site then resolved target) and
`meta.txt`, changing no emitted byte. Five fixtures — including a multi-page
code segment — link byte-identically and run identically.

Phase D step 4 (2026-10-21) ported the **encoder**. Everything that writes a
byte into the code segment does it through about fifty primitives, and
`tools/sxencode.sa` is those primitives in Sayanox: `SX_ENCODE_LOG=<path>`
records each call — name, integer arguments — plus one `b <byte>` line per byte
`e1()` appends, and the replay rebuilds `code.bin` and must match it byte for
byte. Five fixtures (4,912 to 15,380 code bytes) do, the recorder changes no
emitted byte, all fifty records are exercised, and each named record is checked
against the bytes C wrote for that same call, so a wrong ModRM or a disp8/ disp32
mistake fails at the instruction. Why a separate seam: `SX_EMIT_LOG` is written
for a reader and cannot say `0x01` vs `0x03`, or whether a displacement cost one
byte or four, and the runtime's own `J_cc`/`J_mp` jumps are not in it at all.
64-bit immediates travel as two 32-bit halves because a Sayanox number is a C
double. Two byte-identical C changes came with it: an already-bound jump now
emits its displacement instead of patching zeros in place, and `L_new` logs the
id it hands out because the runtime resets the label counter before each helper.
Honest limits: the phase-4 runtime's hand-written machine code arrives as raw
bytes and is copied, not ported; `native_aot` still drives its own encoder to
produce the executables the gates run; and the frontend, emit tree, runtime and
collector are still C.

What that does **not** mean: `native_aot` still resolves a `make` or builtin
name to a code offset, so the records arrive with their targets resolved; and
the C `write_elf()` is still what produces the executables the gates run.
The port of `selfhost/native_aot.c` itself is **not** done: it is still 4,597
lines of C and this row stays in the table until it is.

On 2026-10-19 the compiler itself was fixed, not extended: its `make` signature
pre-pass did not understand `//` comments, so a double quote inside a comment
toggled string mode and every later `make` lost its typed parameter list. The
generated C then read `a: num, b: num` as four untyped parameters. Found while
porting `tools/sxpkg.sa`; `make test-comment-quotes` pins it from both ends and
the whole suite was re-run because the compiler is the one file a small change
can move widely. Logs: [2026-10-19-comment-quotes](gate-logs/2026-10-19-comment-quotes/).

Phase C moved a long way on 2026-10-18: the package tool's whole file side —
publish, install-local, local sync, local fetch, the `seed` folders and the
folder primitives — is Sayanox, and the five sxpkg gates still pass unchanged
(`make test-sxpkg-sayanox-logic` pins the new surface). What is left of C is
the http(s) transport, and it is a language blocker rather than a missing
step: `spawn(path)` takes no argv, so Sayanox cannot launch curl or wget, and
the hardening gate pins curl/wget as the transport it must keep using.

Phase order: **B** ~~IR tool~~, ~~directory builtin + LSP bridge~~ (both done) → **C** online
package transport (the file side is done; the http(s) transport is a documented
exception), **D** native backend, **E** seed. Each phase must keep
`gen3 == gen4` and the four hard gates green, and each must delete its row from
the table above rather than add a new claim. No target may report success for
this phase before the table is empty or every remaining row is a documented
exception.

## Current roadmap — seed | gen2 | native | still missing

This table supersedes the dated historical roadmaps below. “Seed” means the
maintained seed-min bootstrap root, not the older full seed. Existing support
is not presented as new work in this PR.

| Area | seed-min | gen2 | native | Still missing / tested boundary |
|---|---|---|---|---|
| 1. Full-language self-host / memory | Read-only string borrowing and safe builder registry retained. Compiler now uses a live `.sa` module, generic minimum and generic source-size struct; module recovery round-trip tested. | gen1-min/gen2/gen3 compile the live module fixture; gen3/gen4 remain identical. | Not the compiler self-host path. | **Not complete / no full-language claim.** Concrete struct function arguments/returns now pass on gen2/gen3 (bounded, `test-struct-functions`); identifier interpolation now also passes on gen2/gen3 (`test-string-interpolation`); expression-valued struct fields and checked index calls now pass too (`test-full-language-expr`), so `make test-full-language-readiness` is 8/8 and runs inside `make gen3`. Seed/native interpolation and struct function signatures remain open, and four closure probes are not an acceptance specification. `true-selfhost-full` fails closed; no exhaustive language specification exists. Historical ~82% RSS reduction is unchanged, not remeasured. [Evidence](FULL_LANGUAGE_SELFHOST.md#full-language-completion-attempt-and-measured-blockers-2026-10-17). |
| 2. List-valued struct fields / `for v in p.xs` | **Supported:** distinct list field kind emits `sx_list *`; field storage preserves aliases (including growth) and `for v in p.xs` works. | **Supported for concrete structs:** field tag `3` emits `sx_list *`; literals and pointer copies, nested field chains, `p.xs[i]` reads/writes, `len()` indexes/conditions, and `for v in p.xs` are type-lowered. | **Supported:** one pointer word per field; `BK_STRUCT` tracing reaches the list pointer and its growth-forward chain across collections. | `Box<list>` is supported since 2026-10-22 (`Box__l`, `test-generic-structs-nested`). Gen2 direct `push(p.xs, v)` and `show p.xs` remain explicit refusals; use an alias, `len`, or an index. `test-list-struct-fields` runs shared alias/iteration output on all three plus native GC; `test-gen2-list-struct-fields` adds strict-C Gen2 layout/write/condition coverage and pins refusals. |
| 3. Seed GC | **Conservative mark & sweep over the builder registry (new 2026-10-22).** Roots are the C stack only: the body is emitted as `sx_prog` and `main` plants the anchor above it; interior pointers keep their block, nothing moves, the root scan opts out of ASan. First collection at 8 MiB of live builder bytes, then `live * 1.5 + 8 MiB`; `gc()`/`gc_live()`/`gc_runs()` now answer here too. Exact registry and freeing assignment unchanged. | Existing conservative mark/sweep. | Existing mark/sweep. | **Strings only — seed lists are still never freed**, the registry's buckets still never shrink, conservative roots can retain garbage, and a genuinely live 8 MiB set still exits 1 with `sx: out of memory`. Measured here: gen1-min compiling the compiler peaks at 29,768 KiB instead of 1,278,704 KiB (255 s → 272 s) with byte-identical gen2 C, so the bootstrap budget cap drops 1536 MiB → 64 MiB. Not a bounded-heap claim for arbitrary programs. `test-seed-collector`, `test-seed-gc`, `test-seed-borrow`, optional `test-seed-sanitize` / `test-seed-bootstrap-budget`; [GC.md](GC.md#a-collector-in-the-bootstrap-seed-2026-10-22). |
| 4. Struct-typed hold | **Supported:** `hold p: Pt` retains the declared concrete struct identity and rejects scalar/wrong-struct initializers. | Existing accepted/type-checked support. | **Supported:** same named-identity check during collection and emission. | Struct reassignment remains outside this slice. Concrete function parameters/returns now have separate bounded gen2/gen3 support (`test-struct-functions`), not seed/native support. `test-type-refusals` runs the valid copy and scalar/wrong-struct refusals on all three. |
| 5. Nested generic structs | **Supported (2026-10-22):** `instantiate_gstruct` recurses; the inner instantiation is built first, so `Box__n` gets a lower `StructDef` index than `Box__Box__n` and the typedefs emit in an order C accepts. | **Supported (2026-10-22):** `gxargs` parses a type-argument list recursively and returns the nested instantiations innermost-first; `gxmerge` folds them in without a duplicate typedef. Unblocked by teaching the struct-literal walker that a *name* can be struct-typed. | **Supported (2026-10-22):** `gs_instantiate` recurses and records the nested argument's struct identity; a field is one word and `BK_STRUCT` tracing already visits it, so no new GC descriptor. | `Box<Box<num>>` → `Box__Box__n`, `Box<Box<Box<num>>>`, `Box<list>` → `Box__l` (holds the pointer; growth through the original name is visible), `Pair<Box<num>, str>` → `Pair__Box__n_s`. Scalar-only spellings are unchanged (`Pair<num, str>` is still `Pair__ns`). Still refused everywhere: a *concrete* struct name, an unknown name, an escaped type parameter, a wrong argument count. gen2 keeps its documented divergence of learning a field kind from a single contradicting literal. `test-generic-structs-nested` gates the parity fixture and the typedef order; `test-generic-struct-limits` the ten refusals. |
| 6. Stdlib | Ten modules: the portable helpers, flat JSON text utilities, **nested JSON reading (`json_deep.sa`) and SHA-256/HMAC-SHA256 (`crypto.sa`)**, all byte-identical with gen2 and native. | Same tested modules. | Same tested portable subset, including the two new modules. | Nested JSON is **read-only**: no nested writer, no mutation, no pretty-printer; first key wins on duplicates. `crypto.sa` is hashing only — no public-key signature, cipher, KDF beyond HMAC, or constant-time promise, and it is slow by construction (no bitwise operators in the dialect: 32-bit words are carried in doubles). HTTP/crawler integration remains optional and outside bootstrap (`test-network`). `test-stdlib-crypto`, `test-stdlib-json-deep`; [STDLIB.md](STDLIB.md#nested-json-and-cryptography-2026-10-22). |
| 7. Packages | Tool built through gen2, not a seed runtime API. | `.sa` lock/checksum/name validation plus publish, install-local and the local-registry sync/fetch (staging, checksums, rollback); shell keeps only the http(s) transport and the online opt-in. **`pkg.meta` now carries `sha256=` and `origin=`, and `sxpkg sign`/`authenticate` add and check an HMAC-SHA256 `sig=`/`signer=`** (`stdlib/crypto.sa`, no new dependency). Cached install needs no INDEX; local/bare-relative/file copies need no curl/wget. | No native compilation claim for sxpkg. | Online remains opt-in. The signature is **symmetric**: `authenticate` needs the same secret that signed, so there is no public-key signature, no signed index, no key distribution and no first-download trust. `origin=` is a provenance note, not proof. `sum=` stays (non-cryptographic) so older registries keep verifying; `sha256=` is the acceptance test, and `test-sxpkg-crypto` proves it by refusing a real `sum=` collision. No concurrent/crash-proof transaction claim. `test-sxpkg-crypto`, `test-sxpkg-transfer-hardening`, `test-sxpkg-online-local`, `test-sxpkg-online-optin`; [REGISTRY.md](REGISTRY.md#commands). |
| 8. LSP workspace scan | Not a seed-compiled tool claim. | `.sa` protocol, scanning **and folder walk** (no C bridge since 2026-10-17). workspace/symbol and references search a bounded initialized local folder with four open-buffer overlays; query-time refresh. **Definition/references/rename resolve the binder (parameter, body `hold`, or top-level declaration) instead of matching spelling, skip strings and comments, rename across indexed files, and `workspace/didChangeWatchedFiles` is registered and answered.** | Not a native-AOT compiler claim; host C links the tool. | Scope resolution is **not type resolution**: no symbol table, no following `use` to another file's declaration, no shadowing inside nested blocks, struct fields and variables share a namespace. One root, 128 disk files/256 KiB each, depth/entry caps; no symlink traversal, no truncation notices, no workspace diagnostic pass (a watched-file notification answers at most 32 changes). signatureHelp same-document/same-line; codeAction formatting only. `test-lsp-semantic`, `test-lsp-workspace`, `test-lsp`, `test-lsp-robust`, `test-lsp-unicode`. [LSP scope/logs](LSP.md#semantic-resolution-folder-rename-and-file-watching-2026-10-22). **Still not IDE-complete.** |
| 9. Second target / IR | Host C path unchanged. | Host C path unchanged. | x86-64 Linux ELF only. C99 listing adds optional strict record/nondecreasing-offset audit and source-offset correlation; native gate compares both modes deterministically. | `tools/native32.sa` emits i386, AArch64 and RV64IM ELF for integer expressions, static string spans, `len`, byte indexing, and bounded variable-to-variable `concat` (pointer+length globals and a 60 KiB bump heap). `tools/sxisaexec.sa` executes real AArch64/RV64 images with six-way parity, concat heap-limit, fault, scalar S/D arithmetic, and openat/read/write/close syscall probes. General string operations, lists, structs, functions, FP code generation, GC and broad ISA coverage remain open; emulator-only execution is not compiler support. `test-native32`, `test-native-arm64`, `test-native-riscv64`, `test-sxisaexec`, `test-emit-to-ir`, `test-native-ir-portable`, `test-native-emit-split`; [NATIVE_IR.md](NATIVE_IR.md#strict-log-audit-and-source-offset-correlation-2026-10-16). |
| 10. Namespacing / aliases | Textual `use` splicing only; unchanged. | Textual `use` splicing only; unchanged. | Textual `use` splicing only; unchanged. | **Not planned in the compiler; implemented one layer out** (2026-10-23): the dialect still has shared declaration tables, explicit public prefixes and no module identity/import scopes/qualified resolution. `tools/sxmod.sa` (Sayanox, built by gen2) rewrites `module NAME from "path"` + `alias.member` into prefixed flat declarations before compilation. `test-sxmod` first proves the flat dialect **cannot** compose two modules that both declare `add` (seed-min: duplicate function name; cc rejects gen2's C; native_aot: declared twice), then compiles the namespaced version on all three backends to identical stdout, pins what the rewrite must not touch (strings, comments, locals, parameters, struct fields), proves a member is not visible unqualified, and pins 16 refusals. Still missing: module identity in the language, private visibility, nesting, search paths, an import cache. `test-sxmod`, `test-use`; [MODULES.md](MODULES.md). |

### Done / missing / refused

* **Done:** concrete list-valued struct fields and `for v in p.xs` on all
  three backends (including Gen2 layout/literal/copy/index/iteration lowering);
  concrete named-struct `hold` identity checks on all three; native list-pointer
  GC tracing; a hardened native emit-seam gate; SHA-256/HMAC-SHA256 and a
  nested JSON reader in the stdlib on all three backends; package digests,
  provenance and keyed signatures; LSP scope resolution, folder-wide
  rename and file watching; a conservative mark & sweep **collector in the
  bootstrap seed** (`test-seed-collector`); **nested generic structs** on all
  three backends (`test-generic-structs-nested`); Sayanox i386, AArch64 and
  RV64IM emitters with integer and static-string images running through
  `sxisaexec` with 6-way parity (`test-native32`, `test-sxisaexec`); **module
  namespacing one layer out** (`tools/sxmod.sa`, `test-sxmod`); the **C seed
  pinned and audited by a Sayanox tool** (`tools/sxaudit.sa`,
  `test-trust-anchor`); and Phase D steps 3-5 of the native backend in Sayanox
  — the ELF writer/linker, the x86-64 encoder and **front-end phase 1**
  (`tools/sxlink.sa`, `tools/sxencode.sa`, `tools/sxdefs.sa`), each proved
  byte-equal through a dump seam that changes no emitted byte.
* **Missing/outside the tested subset:** full-language self-host,
  *type*-level and incremental workspace indexing, and the full-language native
  compiler/runtime on ARM64/RV64 (native32 currently covers integer expressions
  and static strings only). The emulator's FP and file-syscall checks are
  narrow probes, not a complete RV64GC/AArch64 implementation or compiler
  feature.
  Also still open, and listed with the rest in the **Remaining** table of
  [`../README.md`](../README.md#remaining--and-where-the-build-refuses-to-claim-it):
  the four Sayanox ports of the native backend are **not wired in** (the C
  file still compiles everything, and kind inference, the emit tree, the
  856-line runtime and the 339-line collector are unported); the 2,176-line C
  seed and the `Makefile` are still the bootstrap and build driver; all 14
  tracked `.sh` scripts have been replaced by `.sa` tools (`git ls-files
  '*.sh'` is empty); seed **lists** are still never freed; nested JSON is
  read-only; the package signature is symmetric; and module identity is not in
  the language.
* **Refused by design:** a *concrete* struct name as a generic type argument,
  an unknown name, an escaped type parameter, a wrong type-argument count, and
  the tested unsupported full-language forms. These gates require errors
  rather than wrong layout/code generation. (Generic `Box<list>`,
  `Box<Box<num>>` and a struct-typed struct field on gen2 left this list on
  2026-10-22; they are gated positively now.)
* **Not planned in the compiler:** bootstrap module aliases/namespaces. No
  compiler implementation and no uniform new syntax-refusal diagnostic is
  claimed. Namespacing is available one layer out, as the `tools/sxmod` pass
  (`make test-sxmod`); see MODULES.md.

The final four gate logs are the links in **Current verification** above; the
last markers are `DOCTOR-OK`, `TRUE-SELFHOST-MIN-OK`, `GEN3-OK`, and
`NATIVE-TEST-OK`.

### What changed in this PR

* Replaced the Python IR translator with checked streaming C99 and regression
  tests (unknown lines/instructions, token boundaries, long lines, EOF/errors).
* Removed Python-backed HTTP/crawler tests from the bootstrap aggregate,
  retaining them as explicit optional tests. Corrected dependency claims.
* Made local package transfers truly local and made opt-in tests deterministic
  with a checked failing transport stub rather than requests to `.invalid`.
* Reduced seed-generated compiler memory by borrowing read-only parameters.
  ASan exposed a pre-existing read-before-literal in builder detection; an
  exact allocation registry fixes it. No collector or general leak fix claimed.
* Added alias-preserving list-valued concrete struct fields on all three backends, including Gen2's `sx_list *` layout, literals/copies, indexed reads/writes, nested chains, list-field conditions and `for v in p.xs`; native retains a GC retention probe. `Box<list>`, direct `push(p.xs, v)`, and whole-list `show p.xs` remain explicit boundaries.
* Ported named struct-typed `hold` checking to seed-min and native, including exact concrete-struct identity checks; `test-type-refusals` exercises all three backends.
* Fixed a native seam test that printed shell numeric errors while reporting success: unique marker checks now make malformed marker discovery fail.

The shared stress fixture performs 30,000 reads of a 16 KiB string while
retaining a list: seed/gen2/native match exact output. Seed peak RSS in the
optional Linux measurement fell from 482,992 to 1,468 KiB. The old seed program
failed a 128 MiB address-space cap; the new one passed. The lexical alias fixture
is seed-only because it exercises known gen2 parser limitations. ASan/UBSan
passed the new alias and allocation-registry tests **with leak detection off**.
Measurements and exact scope: `logs/ten-memory.log`, `logs/ten-borrow-asan.log`.

License remains **Sayanox License v1.1**. No Linguist change, language-statistics
mapping, second backend, workspace scan, or full-language claim is included.

---

## Historical status and measurements

The remainder records earlier dated increments. Historical dependency counts,
append-complexity claims and memory ceilings are superseded by the current
roadmap, DEPENDENCY.md and GC.md above; old log paths identify their own runs.

## The nine-item increment (2026-10-13, second pass)

Maximal correct progress on the nine STATUS items, with the pure-min
bootstrap kept green (the four gate logs above are this pass's own runs):

1. **Full-language self-host** — still **not claimed**. The compiler source
   itself grew instead: parenthesised `for` sources and `%`/`len()`/nested
   index expressions are implemented *in* `compiler_min.sa` and self-compile
   through seed -> gen1 -> gen2 -> gen3 == gen4. A measured inventory of the
   full-language features the compiler source does and does not use is in
   [`FULL_LANGUAGE_SELFHOST.md`](FULL_LANGUAGE_SELFHOST.md); the binding
   constraint is gen2's self-compile memory (~3.72 GB peak for the current
   source in a 3.9 GB sandbox, ~3.60 GB for HEAD alone).
2. **`for` gaps** — `for c in (s)` / `for v in (xs)` (parenthesised source)
   now work on seed-min, gen2 and native (`test-for-paren`); only whole-source
   parens unwrap, so `(lo + 1)..(hi * 2)` bounds keep the range path.
   At that dated snapshot, `for v in p.xs` was a clear error everywhere. It is
   now supported for concrete list fields on seed-min, Gen2 and native; see the
   current roadmap table above for the remaining generic/direct-operation
   boundaries.
3. **Expression/analysis gaps** — `%` in an index (`test-gen2-index-mod`,
   left-associative with `*`/`/`), `len()` and nested indexes inside `[ ]`
   (`test-gen2-expr-lowering`), and a string `+` chain in a `give` all lower
   correctly on gen2 now; calls other than `len()`, commas, quotes, empty and
   unbalanced indexes stay clear refusals, never wrong C.
4. **Types** — nested generics (`Box<Box<num>>`) refused on all three
   backends *at that dated snapshot*; they are supported since 2026-10-22
   (`test-generic-structs-nested`). A struct field annotation (`p: Pt`) is refused on all three
   (it silently registered `Pt` as an extra field before this pass); a
   At that dated snapshot, a struct-typed `hold` annotation was gen2-only.
   It is now supported for named concrete structs on seed-min/gen2/native; see
   the current table and [`TYPES_ROADMAP.md`](TYPES_ROADMAP.md).
5. **Seed GC** — unchanged by design: seed-min stays the measured
   no-collector bootstrap root (`test-seed-gc`, [`GC.md`](GC.md)).
6. **Stdlib** — eighth module `stdlib/json_util.sa`: flat-object JSON
   build/read, byte-identical on seed-min, gen2 and native
   (`test-stdlib-modules`), with its non-goals (nesting, exponents, `\u`
   above U+007F) documented in [`STDLIB.md`](STDLIB.md).
7. **Online packages** — shell `publish`/`fetch` now write `sum=` exactly
   like the Sayanox implementation, so shell-handled packages verify the
   same way; still opt-in only, still no cryptographic claim
   ([`SXPKG_ONLINE.md`](SXPKG_ONLINE.md)).
8. **LSP** — rename (open documents only), signature help (same document,
   same line) and a format-only code action added and probed
   (`test-lsp`, 38 facts); no workspace scan exists and none is claimed
   ([`LSP.md`](LSP.md)).
9. **Native second target** — `tools/emit_to_ir.sa` translates the
   `SX_EMIT_LOG` instruction list into a portable IR *listing*
   (lossless, deterministic, x86 register names abstracted;
   `test-native-ir-portable`). Nothing assembles or executes that listing.
   *(Later: `tools/native32.sa` emits i386, AArch64 and RV64IM ELF for a
   documented integer subset, and `tools/sxisaexec.sa` executes the AArch64 /
   RV64 images with six-way parity (`make test-sxisaexec`). Scalar S/D FP and
   basic file syscalls are now emulator probes; `native_aot` and `native-test`
   remain x86-64 only for the full native subset.)*
   ([`NATIVE_IR.md`](NATIVE_IR.md)).

One regression was caught by the gates during this pass and fixed before
the green run above: the seed's first parenthesised-`for` implementation
also unwrapped parenthesised range *bounds*; the unwrap now requires the
first `(` to match the last token before `{`.

## Minimal tool set (re-measured 2026-10-07)

Full audit, measurements and method: **[`DEPENDENCY.md`](../DEPENDENCY.md)**.

The bootstrap needs a host C toolchain and `make` — that is not "zero
dependencies" and is not claimed to be. What it does *not* need is any
Python, Node, Ruby, Perl or PHP on the bootstrap path. POSIX shell recipes
and tracked shell wrappers/probes are used; they are not Sayanox binaries.

| Tool | Needed for | Status |
|------|-----------|--------|
| `make` | the only entry point | **required** |
| C99 compiler (`cc`/`clang`/`gcc`) | building seed-min, gen1_min, gen2, gen3, native_aot | **required** |
| POSIX shell | recipe lines (verified under dash) | **required** |
| `grep` | asserting markers in *generated C* and expected error messages | **required** (proved: without it `true-selfhost` exits 2) |
| `cmp` | `gen3 == gen4` fixed point, seed-min/gen2 parity | **required** (proved: without it `gen3` exits 2) |
| `mkdir` | scratch test directory | **required** (proved: without it `seed-min-gen1` exits 127) |
| `base64`, `gzip`, `cat`, `tr`, `rm` | **only** the offline `compiler_min.sa` fallback | optional |

Measured external commands per target with a PATH logging shim (`as`/`ld` are
internal to the compiler):

| Target | External commands |
|--------|-------------------|
| `make doctor` | `make` |
| `make restore-compiler` (source present) | `make grep` |
| `make restore-compiler` (source missing) | `make grep cat tr base64 gzip rm` |
| `make true-selfhost` | `as cc cmp grep ld make mkdir` |
| `make gen3` | `as cc cmp ld make mkdir` |
| `make native-test` | `as cc grep ld make mkdir` |

Positive control for the three "required" assert tools, re-run 2026-10-08 on
this checkout with a `PATH` containing only `make cc as ld sh grep cmp mkdir`:
`make doctor`, `make true-selfhost` (which now runs `test-pkgs`, `test-stdlib`,
`test-builtin-names` and `test-stage2-demos` as well), `make gen3` and `make
native-test` all exit 0 with no `not found` line. No `curl`/`wget` and no
interpreter is ever executed — the bootstrap is fully offline. `make native-test` additionally needs an **x86-64
Linux** host, because `native_aot` writes x86-64 Linux ELF executables;
`true-selfhost` and `gen3` emit portable C.

Removed from the critical path in the earlier pass: `sed`, `awk`, `diff`, `wc`,
`cat`, `tr`, `base64`, `gzip` (the last five survive only in the optional
offline-restore fallback). The LSP probe used `mktemp`/`wc -c`/`tr -d`/`rm -rf`
until 2026-10-08; it now takes its work directory as an argument (created with
`mkdir`, left behind on purpose) and measures payloads with `${#payload}`, so
`make true-selfhost` needs no tool outside the list above. Since 2026-10-17
Compiler archive packing and restoration are now driven by `tools/sxpack.sa`
(the bootstrap's missing-source fallback stays inline in the Makefile). All
tracked `.sh` files are retired; `make test-language-deps` checks this along
with the absence of awk/sed in Makefile recipes.

`fix-seed` was ~20 lines of `awk` + `sed -i` rewriting the seed sources in
place. Every edit in it was dead: the `awk` guard's grep pattern
`ptok(k,(const char*)#ch` is a BRE where `r*` means "zero or more `r`", so it
could never match, and all six `sed -i` guards looked for pre-fix text that is
no longer in the checked-in sources. It is now `verify-seed`, a read-only
assertion (`fix-seed` remains as an alias). Test assertions moved off
`sed -n Np` onto a pure-shell `assert-out` helper that compares whole stdout
using only builtins, which is stricter than the per-line checks it replaced.

## Bootstrap memory (re-measured 2026-10-07, with the collector)

`selfhost/compiler_min.sa` is 400,647 bytes (391 KB; it was 244,058 bytes
earlier the same day — the growth is the generic pre-pass, the collector text
and the newer language checks). The
compiler flushes its `body` buffer into `obody` at ~1 KB (except while collecting
a function body), avoiding a flat O(n^2) accumulator that previously allocated
~2.5 GB and was killed on low-RAM hosts. A final string/identifier-aware C
literal pass flushes after at most 512 input bytes per chunk (before `.0`
expansion), bounding the temporary builder and avoiding a full-prefix copy per
character.
Measured 2026-10-07 after the mark & sweep collector landed (peak RSS from
`wait4` `ru_maxrss`):

| Step | Peak RSS (with GC) | (pre-GC, same day) |
|------|--------------------|--------------------|
| `seed-min` compiling `compiler_min.sa` -> `gen1_min.c` | 1.9 MB | 1.8 MB |
| `gen1_min` compiling `compiler_min.sa` -> `gen2.c` | 100.6 MB | 57.9 MB |
| `gen2` compiling `compiler_min.sa` -> `gen3.c` | 32.6 MB | 218.6 MB |

`gen2`'s own peak fell 6.7x: it is built by `gen1_min`, emits the collector
into itself, and now frees the strings it allocates while compiling.
`gen1_min` is built by the malloc-only seed and reads a bigger source than
before, so its peak grew; it runs once per bootstrap and is not on the
memory-critical path.

On this checkout `gen1_min` and `gen2` each need ~20 s to compile
`compiler_min.sa`, `make gen2` ~35 s, `make true-selfhost` ~2 min,
`make gen3` ~1 min and `make native-test` ~3 s. `gen2` produces byte-identical
output under `ulimit -v 65536` (a 64 MB address-space cap, down from 400 MB
before the collector), and `make gen3` reaches its fixed point
(`gen3 == gen4`) without being killed.

## Language roadmap (2026-10-11)

Done means the feature is implemented and a `make` target that runs in a gate
(or is part of one) checks it. Missing means not implemented on that backend.
Deferred means it is too large for the current pass; the reason is given.
Four gates on this checkout: `DOCTOR-OK`, `TRUE-SELFHOST-MIN-OK`, `GEN3-OK`,
`NATIVE-TEST-OK`.

The authoritative backend/gate/missing-work table is the roadmap at the end
of this document. Seed Stage-2 was extended this pass; native logic values,
generics and function-local slots already existed and were re-tested.

## Coverage (pure-min dialect)

| Feature | seed-min | gen2 (compiler_min) | native (native_aot) |
|---------|----------|---------------------|---------------------|
| `hold` / `show` (num, str) | yes | yes | yes |
| `when` / `while`, `== != < <= > >=` | yes | yes | yes |
| `otherwise` after `}` | yes | yes | yes |
| `else` alias after `}` (true *and* false branch) | yes | yes | yes (false branch fixed 2026-10-06) |
| `+ -` on numbers, string `+` (concat) | yes | yes | yes |
| string `+` number (`"a" + 1`) | error | error (was silently wrong: `s + n` printed the *name* `n`) | error (2026-10-08: matched the shared subset; the number used to be joined with `%g`) |
| `*` | yes | yes | yes |
| `/` | yes (10/4 = 2.5) | yes (2.5) | yes (2.5; IEEE double, 2026-10-07) |
| `/` by zero | `inf` / `-nan` | `inf` / `-nan` | `inf` / `-nan` |
| `%` modulo (truncates both sides, `-7 % 3` = -1) | yes | yes | yes |
| `%` by zero | exit 1, `division by zero` | exit 1, `division by zero` | exit 1, `division by zero` |
| chained ops (`a + b + c`; `* / %` bind tighter, left-assoc) | yes | yes | yes |
| `%` inside `when`/`while` conditions | yes | yes | yes |
| `make` / `give` (top level, numeric) | yes | yes | yes (enabled 2026-10-06; `hold` inside a body is a clear error) |
| recursion | yes | yes | yes (`fac(5)` = 120, `fib(20)` = 6765, mutual recursion) |
| lists: `[..]`, `xs[i]`, `len` | yes | yes | yes |
| `hold xs = push(xs, v)` (expression form) | yes | yes | yes |
| bare `push(xs, v)` statement | yes (2026-10-07) | yes (2026-10-07) | yes |
| bare call statement (`write_file(p, s)` on its own line) | error: `unknown statement` | error: `unknown statement` | error: `unknown statement` (2026-10-08; `push(xs, v)` is the only call statement, as in the other two) |
| structs: number fields, `p.x`, `Point { 1, 2 }` | yes | yes | yes |
| structs: string fields (`name: "ada"`) | yes | yes | yes |
| structs: nested 2 and 3 deep (`Line { a: Point { 1, 2 } }`, `l.a.x`), typed copy `hold m = l.a` | yes | yes | yes (verified with `make native-test`) |
| copy of a doubly nested field (`hold p2 = r.q.p`) | yes (fixed 2026-10-06) | yes | yes |
| string builtins: `concat len chr` | yes | yes | yes |
| string builtins: `string_eq` | yes | yes | yes (numeric result) |
| string builtins: `sx_index` and `s[i]` | yes | yes | yes (fixed 2026-10-06) |
| builtins: `read_file write_file arg arg_count` | yes | yes | yes (fixed 2026-10-07: `arg_count()` counts argv[0], `arg(0)` is the binary path, `write_file` truncates and returns 1, a missing file reads as `""`) |
| `use "file.sa"` (modules) | yes | yes | yes (spliced before parsing; missing file / unquoted path are clear errors) |
| base `OP` operand on either side (`10 % 3`, `p.x + p.y`, `xs[1] + 5`, `len(xs) + 1`, `3 * xs[0]`, `p.x * p.x`) | yes | yes | yes (right of `* / %` fixed 2026-10-06) |
| parenthesized base expression (`(a + 3) * 4`) | yes (20) | yes (20; 2026-10-07) | yes (20) |
| fractional literal (`hold x = 2.5`; `2.` and `1.2.3` are errors) | yes (2026-10-07) | yes (2026-10-07; used to print 2) | yes (2026-10-07) |
| integer-only arithmetic uses double constants (`100000 * 100000` = `1e+10`) | yes (2026-10-07) | yes (2026-10-07) | yes |
| list literal with 10+ elements | yes | yes (was invalid C) | yes |
| whole-list copy `hold ys = xs` | yes | yes (2026-10-07) | yes |
| a builtin word used as a variable (`hold index = 1`, then `sx_index(s, index)`) | yes | yes (2026-10-08: the argument-text rewriter only maps a builtin that is really *called*; it used to emit `sx_idx(s, sx_idx)`) | yes (never had the bug) |

## Measured divergences (re-measured 2026-10-08)

The two native-only *statement/type* extensions that used to be listed here are
gone: a bare call statement other than `push(xs, v)`, and `string + number`,
are now rejected by native with the same wording as seed-min and gen2
(`make test-native-num`, `make test-push-stmt`). The seed-min and gen2
compilers agree on the whole shared dialect; 64 repository `.sa` programs have
also been compared across all three backends for byte-identical stdout.

What is still different, and honest about it:

| Area | seed-min | gen2 | native |
|------|----------|------|--------|
| `hold` inside a `make` body | accepted | accepted (a local slot) | accepted since 2026-10-11 (a local slot in the call's own frame; the collector scans it) |
| collector builtins `gc()` / `gc_live()` / `gc_runs()` | yes since 2026-10-22 (conservative mark & sweep over the builder registry; this row used to read "error: no collector in the seed runtime") | yes (mark & sweep) | yes (native mark & sweep, see `GC.md`; corrected 2026-10-10 — this row used to say `undefined variable 'gc'`) |
| memory under an address-space cap (measured 2026-10-13, re-measured 2026-10-22, `make test-seed-gc` / `make test-seed-collector`) | the freeing assignment alone keeps a 200k churn and a 2000-step accumulation inside a 4 MiB cap, below the collector's 8 MiB threshold; an 8388608-byte live set still exits 1 with `sx: out of memory`; with the collector, 4,000,000 dropped temporaries run inside 64 MiB (17,556 KiB peak) where the pre-collector seed needed 346,872 KiB | mark & sweep, first collection at 8 MiB of managed heap: the same churn needs a 64 MiB cap and fails at 16 MiB with `sx: out of memory` (was a segfault) | mark & sweep at every statement boundary past a debt threshold: the same churn runs inside a 4 MiB cap (`test-native-mem`) |
| Stage-2 | boolean literals/logic, elif, while break/continue, named/literal string-list for and numeric ranges outside make | broader Stage-2 including literals/calls/ranges and typed functions | broader Stage-2 plus logic values and kind generics |
| diagnostic wording | own text (`seed_min: ...`) | own text (`min: ...` / `#error` line) | own text (`native_aot: ...`) |
| host and memory | any C host, malloc-based, builder-backed strings with a freeing assignment wrapper and (2026-10-22) a conservative mark & sweep for those strings — lists are still never freed; see `GC.md` §2 | any C host, mark & sweep | x86-64 Linux only; own heap (first-fit + bump) with a mark & sweep collector (corrected 2026-10-10; was "bump-allocated, never freed") |

The full seed `sxc_seed` is deliberately not a column in that table: it is not
on the bootstrap path (`seed-min -> gen1_min -> gen2` is), and until 2026-10-13
it could not compile a comparison at all. Measured now, with `make
test-seed-gc`:

* its lexer recorded a single-character operator token's text as the
  *stringized char literal*, quotes included (`'*'`, `'<'`), so `emit_expr`
  matched none of its operator spellings and dropped the operator — `show 2 * 3`
  became `sx_show(((double)2LL),((double)3LL)))`, which does not compile.
  Arithmetic, comparisons and `while`/`when` conditions were all broken. Fixed
  by building the token text from the character value; the fixture
  `selfhost/seed_gc_ops.sa` now prints the same nine values on the full seed,
  seed-min and gen2;
* `gc()` exists but is a documented no-op returning `0`, `gc_live()` and
  `gc_runs()` do not exist, and `SX_GC_DEBUG=1` shows the reference counts are
  not releasing in loops: 6000 objects are still alive at exit after 2000
  iterations that retain nothing (`GC.md` §2, "The two seeds, measured");
* its object table is a static 2097152-entry array, so a 4 MiB cap cannot even
  start it and its measurements run under a 64 MiB cap;
* a program using `%` needs `-lm` *after* the sources on the link line
  (`sx_modv` calls `fmod`);
* it prints a large integer as `8388608` where seed-min, gen2 and native print
  `8.38861e+06`. That formatting difference is pinned, not fixed: the full seed
  is not a release backend.

Two numeric mismatches from the prior audit are fixed and covered by
`make test-float` and `make test-native-num`:

* Integer-only expressions now use double literals in generated C. This covers
  nested arithmetic, conditions, function arguments and `give` expressions;
  `show 100000 * 100000` prints `1e+10` on seed-min, gen2 and native rather
  than overflowing as a 32-bit C `int`.
* `%` now checks the truncated divisor before taking the remainder. Every
  backend exits non-zero with a clear `division by zero` diagnostic.

In seed-min, integer tokens are emitted with a `.0` suffix. gen2 applies a
string/identifier-aware integer-token normalization to generated function and
main code, flushing after at most 512 input bytes per chunk (before `.0`
expansion). Runtime code, strings and identifiers are unchanged. Native
arithmetic already uses IEEE doubles. Generated-C modulo expressions use the
same `sx_mod` helper in seed-min and gen2; native checks for zero before signed
remainder.

The documented dialect (see `docs/SYNTAX.md`, `docs/CHEATSHEET.md`) shows
`push(xs, 4)` as a statement; all three backends accept it, and
`hold xs = push(xs, v)` works everywhere.

Struct field types come from the literals that fill them: a field is `double`
or `char *`, the first literal that mentions it decides, and a conflicting
later literal is a hard error. `hold s = u.name` is typed as a string.

### gen2 gaps found on 2026-10-08: all fixed

Reproduced on gen2 while adding the Stage-2 slice, then fixed and pinned by
`make test-gen2-gaps` (part of `true-selfhost-min`):

* **`len(` in a range bound.** `for i in 0..len(xs)` (a declared list,
  `sx_llen`) and `for j in 0..len(s)` (a string, `sx_len`) compile and run.
  Before, the C called an undefined `len` and failed at link time.
* **String `==` and `!=`.** `A == B` and `A != B` compile to `sx_eq` (strcmp)
  when A is a declared string and B is a declared string or a quoted literal.
  Before, they compared addresses, so two equal strings built with `concat`
  compared unequal. The rewrite is narrow on purpose: other operand shapes are
  copied unchanged.
* **`else when`, `else if` and `otherwise when`.** These are chains like
  `elif`. Before, `} else if COND {` also failed (the plain `else` was emitted
  twice), so the documented `else if` form did not work on gen2 either.
  `} elif COND {` was always fine.
* **String ordering.** `s < t` and the other orderings on strings were
  pointer compares, which gave arbitrary answers. Now `sx_cmp` (strcmp) on
  gen2 and `strcmp` on seed-min, for declared strings and quoted literals on
  either side (`make test-gen2-gaps`). Native orderings were added 2026-10-10 (`make test-native-strord`).
* **`%` inside a builtin-call argument.** `chr(48 + m % 10)`,
  `concat("x", chr(m % 10))` and `chr(48 + x * m % 10)` now compile. Each `%`
  becomes `sx_mod(L, R)`, using the same operand rule as the condition
  rewrite: L is the `* / %` chain to its left (`x * m % 10` is
  `(x * m) % 10`), R is the next atom. `%` inside a string literal is text.
  Seed-min and gen2 print the same output (`make test-gen2-gaps`).

Design notes (documented behaviour, not gaps):

* **Flat scope.** Pure-min scoping is flat: a `hold x = ...` inside a `when`
  or `while` body assigns to the outer `x` and does not shadow it. This is the
  rule the compiler is written against (see the `for` notes in
  `selfhost/compiler_min.sa`). Do not rely on shadowing.
* **String ordering and equality (2026-10-08).** `<`, `<=`, `>`, `>=`, `==`
  and `!=` between two strings compare by content (`strcmp`) on gen2 and on
  seed-min. A string compared with a number, list or struct is an error on
  seed-min. Native implements `==`/`!=` (`string_eq`) and, since 2026-10-10, the orderings
  (unsigned-byte strcmp, `make test-native-strord`). Recorded as closed below.

### Divergences measured on 2026-10-13 (open, not fixed)

Found while growing `stdlib/` (item: stdlib growth) and while finishing the
seed `for` forms. Each one was reproduced with a minimal program; none is
papered over in the library, and each is pinned by a test or documented here.

* **FIXED 2026-10-13: gen2 index expressions.** `xs[i - 1]` and `xs[1 + 1]`
  used to make gen2 emit
  `#error sayanox-min: unsupported index expression (number or name only)`, and
  an index inside a `when`/`while` condition or a `for` bound was copied
  verbatim so the C subscripted an `sx_list` struct with a double
  (`array subscript is not an integer`). An index is now a numeric expression
  in all three positions, on all three backends (`make test-gen2-index-expr`,
  39 values). **Fixed again later the same day:** `len(NAME)` and a nested
  `NAME[IDX]` inside `[ ]` now lower too, in a value, in a chain operand, in a
  condition, in a `for` bound and inside a typed body (helper `idx_lower`,
  `make test-gen2-expr-lowering`, 18 values). What gen2 still refuses inside
  `[ ]`, each with a clear diagnostic and a `#error` rather than invalid C:
  `%`, a call other than `len()`, a comma, a quoted string, an empty index,
  unbalanced parentheses or brackets, and an expression that ends with an
  operator. The workaround is `hold n = <expr>` then `xs[n]`; seed-min and
  native accept a call other than `len()` inside an index, so that one row
  stays open as a narrower divergence.
  *(Later: `%` landed on 2026-10-14 (`test-gen2-index-mod`), and on 2026-10-22
  a call to a function declared `-> num` landed too — `test-full-language-expr`.
  A quoted string, a non-numeric call and a `list` parameter are still the
  gen2-only refusals.)*
* **FIXED 2026-10-13: gen2 `give` with a direct string `+` chain.** Inside a
  function body, `give "hi " + name` and `give "a" + "b"` used to emit invalid C
  (`invalid operands to binary + (have 'char *' and 'char *')`), so the
  generated file failed to compile, while the same chain in a `hold` worked.
  The expression rewriter behind `give`, `when`/`while` conditions and
  parenthesized expressions now joins two strings through `sx_cat` and nests a
  chain, exactly as the value-position parser already did
  (`make test-gen2-expr-lowering`, 11 values identical on seed-min, gen2 and
  native). A `+` with exactly one string side is refused with the value
  parser's own sentence, and so is `%` with a string operand — a `min:`
  diagnostic plus a `#error`, never C that only fails at cc time. A struct
  string field and a user-function call are not classified as strings there
  yet, so `give "n=" + p.name` is refused rather than mis-compiled; bind it
  with `hold` first.
* **A negative index and a unary sign.** `xs[-1]` wraps to the last element on
  seed-min and gen2 (`sx_lget`/`sx_idx` add the length when the index is
  negative). native refuses a unary sign in an index at compile time
  (`native_aot: bad expression`) and reports `list index out of range` at run
  time for `xs[0 - 1]`. `make test-gen2-index-expr` pins seed-min/gen2
  agreement and asserts that native still refuses, so the difference cannot
  drift silently.
* **A `make` in the middle of `compiler_min.sa` is not a definition.** The
  self-hosted compiler source keeps all 16 of its `make` helpers in the leading
  block (lines 1-841) before any top-level statement. Adding `raw_index` after
  ~2400 lines of top-level code made gen1_min emit a signature whose parameter
  annotations had been split into extra parameters
  (`raw_index(double source, double str, double from, double num, ...)`), so
  gen2.c did not compile. Moving the helper into the leading block fixed it.
  Recorded here because it is a constraint on editing the compiler source, not
  a property of user programs: a user program with a `make` after top-level
  statements compiles fine on all three backends.
* **A global read inside an untyped `make` body.** seed-min and gen2 refuse it
  with their own clear diagnostics; `native_aot` still prints the value,
  because its scope model differs. Hoisting top-level variables out of
  `main()` so that all three agree was rejected as a design direction: the
  compilers prefer an explicit refusal to codegen that quietly reads the wrong
  storage. `for` sources inside untyped `make` bodies were completed instead
  (`test-seed-for-untyped`).

## Verified behaviour

```bash
make true-selfhost   # seed-min -> gen1_min -> gen2, then every feature test on gen2
make gen3            # gen3 == gen4 byte-identical + feature tests on gen3
make native-test     # real x86-64: core control flow, lists, structs, modules,
                     # recursion, double/large-constant math, %0 diagnostics,
                     # file and argv builtins
make seed-min        # seed-min: hold/show/while/struct/list/fn/%/else/use
```

Program:

```sayanox
hold a = 10
show a % 3
when a > 5 { show 1 } else { show 0 }
```

prints `1` then `1` via gen2 (and via seed-min and via native).

Chain and struct examples verified by `make test-chain`, `make test-user` and
`make test-nest`:

```sayanox
hold s = "a"
show s + "b" + "!"          # ab!

struct Point { name, x }
struct Line  { a, b }
hold l = Line { a: Point { name: "p1", x: 1 }, b: Point { name: "p2", x: 2 } }
show l.a.name               # p1     (seed-min)
show l.a.x                  # 1      (seed-min)
```

## Sayanox-written tooling milestone

`tools/sxfmt.sa` is a working, conservative formatter written in Sayanox and
compiled by the maintained gen2 compiler. `make sxfmt` builds it; `make test-sxfmt`
checks nested-block indentation, braces inside strings/comments, trailing
whitespace removal, final-newline normalization and idempotence. It preserves
tokens and is not yet a syntax-aware formatter.

`tools/sxpkg.sa` implements local `init`, `add`, `list`, `remove`, `seed`,
`search`, `info`, `verify` and `sum`; the shell entrypoint delegates these
commands to it. `make sxpkg` builds the program and `make test-sxpkg` checks
the command path. Offline integrity: `pkg.meta` carries a `sum=` content check
that `verify` compares against the project's registry copy
([`REGISTRY.md`](REGISTRY.md)). It is not a security signature.
Sync/install/publish/fetch and package-directory operations remain in shell.

The language server is a full Sayanox program (`tools/sayanox_lsp.sa`, built
by gen2 and covered by `make test-lsp`); the old sed-based shell fallback
`tools/sayanox-lsp.sh` was removed on 2026-10-17. These are migration slices, not an "all tools
are Sayanox" claim: online package operations, the seed and the native backend
still use shell/C infrastructure. See
[`ONLY_SAYANOX.md`](ONLY_SAYANOX.md) and
[`SELF_HOSTING_ROADMAP.md`](SELF_HOSTING_ROADMAP.md).

## Honest boundaries

* **Modules** (`use "file.sa"`): spliced before parsing, depth <= 8, only at a
  real statement start (never inside strings or `//` comments). A missing file
  is a hard error: gen2 emits `#error` into the generated C (so the C compile
  fails loudly); seed-min prints to stderr and exits non-zero. An unquoted
  path (`use other.sa`) is reported the same way instead of being compiled as
  garbage identifiers. Paths resolve against the current directory first, then
  next to the input file.
* **Structs** are typed from literals (see above); a missing field defaults to
  `""`/`0` in seed-min, while gen2 requires every field of a literal to be
  present. **Nested structs** (`a: Point { 1, 2 }`, chains such as `l.a.x`)
  work in **all three backends** (verified with output parity in
  `make test-nest` for seed-min/gen2 and in `make native-test` for native,
  including three levels deep). Rules, enforced by all three:
  the nested struct must be declared before the struct that nests it (so
  typedefs stay dependency-ordered), a struct-valued field must be filled in
  every literal, a struct value can be copied with a typed declaration
  (`hold m = l.b`, `hold r = q`), and a chain through a field that has no
  struct type is a hard error. A list inside a struct field and a struct
  value inside a list are hard errors in both compilers; `show` of a struct
  value is a hard error in gen2 and in native. Copying a *doubly* nested
  field (`hold p2 = r.q.p`) now works in **all three backends** (seed-min's
  first collect pass used to walk the chain before the literal scan had
  typed its links and died with a misleading "has no struct type"; fixed
  2026-10-06, pinned by `make test-nest` and `make native-test`), as does
  copying one level (`hold m = l.a`).
* **Parenthesized expressions** (`show (a + 3) * 4`, nested parens, parens in
  `hold`, `give` and conditions) work in all three backends since 2026-10-07
  (`make test-parens`, and native output parity in `make native-test`).
  Parentheses around a non-numeric value and unbalanced parentheses are clear
  errors in gen2.
* **Numbers are IEEE doubles** in all three backends: integer and fractional
  literals (`2.5`, `0.75`; `2.` and `1.2.3` are clear errors), `/` is true
  division (`10 / 4` = 2.5, `1 / 0` = `inf`), `%` truncates both operands to
  integers first, and `show` prints like C's `printf("%g")` (`0.333333`,
  `1e+10`). Constant-only arithmetic, conditions, function arguments and
  returns also use double literals, avoiding C's 32-bit integer overflow.
  `% 0` exits with the same `division by zero` diagnostic in all three.
* **Strings and numbers do not mix in pure-min**: `+` joins two strings or adds
  two numbers. seed-min and gen2 reject `"a" + 1`, `1 + "a"` and `-`/`*`/`/`/`%`
  on strings with a clear error (gen2 used to paste the variable's *name* into
  the string: `s + n` printed `an`). native used to accept the mix and format
  the number with `%g`; since 2026-10-08 it rejects it with the same wording,
  so all three backends implement one subset — use `concat(s, n)` to build
  a string from a number.
* **Statements**: a statement starts with `hold show when while make give
  struct use` (plus `otherwise`/`else` after a `}`) or is a bare
  `push(xs, v)`. Anything else — a misspelled keyword, a bare
  `write_file(...)` call — is an `unknown statement` error in seed-min,
  gen2 (gen2 used to drop such lines silently or emit invalid C) and, since
  2026-10-08, native (it used to run any bare builtin call).
  Seed-min now also supports `elif`, `break`/`continue`, boolean word
  operators/literals, and `for` over named list/string sources or literals outside make.
  Unsupported iteration forms receive explicit diagnostics (see roadmap).
* **String iteration** binds a one-byte string per iteration. Empty strings,
  nesting, repeated counter names across sequential loops and UTF-8 byte
  iteration are tested on seed-min and gen2 by `make test-for-str`; native
  also supports string iteration. `"é"` is two iterations, not one codepoint.
  The source variable is re-read each iteration, including after rebinding.
* **Collector builtins** (`gc()`, `gc_live()`, `gc_runs()`) are gen2/gen1_min
  and native (mark & sweep, corrected 2026-10-10): the seed runtime has no
  collector. They are ordinary expression
  calls, so `hold freed = gc()` works; a *bare* `gc` statement is still an
  unknown statement.
* **Lists** are `double`-only, one type per program; `push` returns the list
  and also works as a bare statement. `hold ys = xs` copies the list
  reference. A string, list or struct as a list element is a clear error in
  every backend, and `+`/`-` on a list is a clear error (never pointer
  arithmetic in the emitted C).
* **Functions**: top level only, numeric params/return, recursion works in
  all three backends (native function codegen was fixed and enabled
  2026-10-06: up to 6 numeric params, forward references, mutual recursion,
  zero-arg calls, and calls as arguments of other calls). Calling a user
  function is supported in `hold` RHS, `show` and `give`. Native function
  locals use per-call stack frames; recursive local holds are covered by
  `test-native-locals`. Seed-min and gen2 emit C locals. Typed string/list
  signatures and generics are now supported by seed-min as well as gen2/native,
  within the documented per-backend subsets.
* **Statements are newline-terminated**: write one statement per line. In
  particular `give 0 }` on one line swallows the `}` into the returned
  expression; the compiler now reports that as an error instead of letting it
  become invalid C.
* **`hold`/`show`** accept a chain of binary operands — number, name, field
  (`p.x + p.y`), index (`xs[1]`), call (`len(xs)`) — with the usual precedence
  (`* / %` bind tighter than `+ -`) and left-associativity; `hold u = s + t +
  "!"` concatenates strings, and `%` lowers through the checked `sx_mod`
  helper in the C backends.
* **`use` paths** resolve against the current directory first, then next to
  the input file, so `./selfhost/gen2 dir/main.sa out.c` finds `dir/lib.sa`.
* **Conditions** in `when`/`while` are copied as C text with `%` lowered to
  `sx_mod(a, b)`, so `while a % 10 > 0` uses the same truncation and zero-divisor
  behavior as ordinary expressions; the remaining operators must be valid C
  (`*`, `/` and comparisons are).
* **native_aot** covers `hold/show/when/else/while`, IEEE double numbers
  (fractional literals, true `/`, `%g` output identical to seed-min),
  `+ - * / %`
  (postfix operands on either side of any operator: `p.x * p.x`, `3 * xs[0]`;
  `/` and `%` stay left-associative), comparisons, `show "str"`, string
  `concat`/`len`/`chr`/`string_eq`/`sx_index` and `s[i]` (the index builtin
  used to lose its index inside its own strlen call; fixed 2026-10-06),
  literal lists (`[1, 2]`, `xs[i]`, `len`, `push` — the list grows in place,
  out-of-range indexes die), structs including nested ones
  (`Line { a: Point { 1, 2 } }`, `l.a.x` chains, typed copies of a struct
  field, doubly nested copies `hold p2 = t.q.p`), `use "file.sa"` module
  splice (before parsing, depth <= 8, resolved against the input file's
  directory then the cwd; missing file and unquoted path are clear errors;
  the splice buffer grows, so a large library file cannot overflow it), and
  functions: top-level `make`/`give`, up to 6 numeric params, recursion
  (`fib(20)` = 6765, `fac(20)` exact), forward references, mutual recursion,
  zero-arg calls, global assignment from a body, and calls/builtins as
  arguments of other calls — every staged argument and every index base
  rides on the machine stack, so a nested or recursive call cannot clobber
  them. Function codegen was enabled 2026-10-06 after fixing the parameter
  spills (params 1/3/4 spilled rbx/r13/r9 instead of rdi/rdx/rcx), the frame
  size (a fixed 32-byte frame let the first push overwrite params 5-6) and
  argument staging; `make native-test` pins all of it.
  Every distinct variable name gets its own data slot (two names sharing a
  first letter no longer share storage) and an undeclared name is a hard
  error instead of reading as 0. Rejected with a clear error: `hold` inside
  a `make` body, `give` outside a function, `make` inside a block, a wrong
  argument count, a non-numeric argument or `give`, field access on a
  non-struct, a later-declared nested struct, a list inside a struct field
  and `show` of a struct value.
  The file and argument builtins (`read_file`, `write_file`, `arg`,
  `arg_count`) work and match seed-min/gen2 (`make test-native-io`, including
  a 160 KiB round trip). The statement and type subset is the same as seed-min
  and gen2: string + number and bare non-`push` call statements are rejected
  (`make test-native-num`). The remaining differences are the ones in the
  divergence table (the seed Stage-2/type limits and platform differences). Native output is x86-64 Linux only. The runtime
  is a flat BSS data area plus a **real mark & sweep collector** over lazily
  `mmap`ped chunks (malloc/memcpy/copy semantics verified by probe programs).
  Blocks carry a 32-byte header (size|FREE, magic, mark/next, kind);
  `r_malloc` is first-fit over a free list and then bumps; `r_gc` traces from
  a precise root table (every string/list/struct global plus the literal
  scratch, filled in after codegen) *and* conservatively from `[rsp,
  stktop)`, frees what it cannot reach, coalesces adjacent runs, rebuilds the
  free list and `munmap`s chunks a sweep emptied completely. Collections are
  triggered at statement boundaries once the bytes allocated since the last
  one pass `max(2 * live, 64 KiB)`. `gc()`, `gc_live()` and `gc_runs()` are
  therefore **real on native**, not compatibility no-ops: `gc()` collects and
  returns the bytes reclaimed.
  `make test-native-mem` (part of `native-test`) pins the behaviour: a
  262144-byte string (larger than one 64 KiB chunk), a 100000-element `push`
  loop and a 20000-iteration `concat` loop keep every value and index correct;
  a 200000-iteration churn loop (~8 MB allocated, nothing retained) **finishes
  inside a 4 MiB `ulimit -v` cap** running 200+ collections, and strings,
  list elements and struct fields still read back correctly after 30000
  allocating iterations; a program that genuinely retains 8 MiB still dies with
  the documented `out of memory` diagnostic, stdout written before the failure
  is kept, and the status is non-zero rather than memory being corrupted.
  The collector is not compacting and the conservative half of the root set
  can retain garbage (a stale stack word keeps a block alive); see
  [`GC.md`](GC.md).
* **Stage-2 demo programs**: `selfhost/minimal_lexer.sa`,
  `selfhost/stage2_functions.sa` and `selfhost/stage2_variables.sa` are
  written in the pure-min dialect and are compiled and run by both seed-min
  and gen2 with byte-identical stdout (`make test-stage2-demos`). They
  illustrate the Stage-2 *contract* (explicit slots, function contracts) —
  they are not the full Stage-2 language.
* Still not part of pure-min: modules with namespacing/aliases *in the
  compiler* — the dialect still has one flat name table. Namespacing is
  available as the `tools/sxmod` pass, which rewrites `module`/`alias.member`
  into prefixed flat names before compilation ([`MODULES.md`](MODULES.md),
  `make test-sxmod`). The GC is no longer on that list:
  gen2-compiled programs link the collector in [`GC.md`](GC.md). Generics are
  no longer on it either: `make NAME<T>(a: T, b: T) -> T` monomorphises one
  copy per call-site kind (`make test-generics`, [`SYNTAX.md`](SYNTAX.md)).

## Feature tests

| Target | Covers |
|--------|--------|
| `make test-reassign` / `test-while` / `test-when` | core statements |
| `make test-mod` | `%` lowering + `else` alias |
| `make test-chain` | chained `+ - * / %`, precedence, string `+` (seed-min and gen2 agree) |
| `make test-condmod` | checked `%` lowering inside `when`/`while` conditions |
| `make test-struct2` | named fields, two structs, `p.x + p.y` |
| `make test-user` | struct string fields (`User name/age`); mismatches are hard errors; a string chain that starts at a struct field links and prints the same in seed-min, gen2 and native (gen2 used to omit `sx_cat`) |
| `make test-nest` | nested structs in seed-min and Gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies including the doubly nested `hold p2 = t.q.p`); concrete list-field alias growth and Gen2 dotted-index lowering; clear errors for forward decls, bad chains and show-of-struct |
| `make test-list2` | literal, index, `len`, `push` |
| `make test-use` | splice, nested depth 2, missing-file error |
| `make test-fn2` | params, call in `show`, recursion (`fac 5 = 120`) |
| `make test-boot` | gen2 compiles `compiler_boot.sa` and the result runs |
| `make test-parity` | seed-min and gen2 agree on one program using the whole shared dialect |
| `make seed-min` / `test-struct` / `test-list` / `test-fn` | same features on the C seed |
| `make test-prec` | precedence (`a + 3 * 4` = 14 in seed-min and gen2) |
| `make test-float` | fractional literals, true division, double constant arithmetic (including large products in conditions and functions), and deterministic `% 0` errors in seed-min and gen2; malformed numbers are rejected outside strings/comments |
| `make test-parens` | parenthesized expressions in seed-min and gen2 (`(a + 3) * 4` = 20, nesting, unary minus, parens in conditions and `give`); non-numeric and unbalanced parens are clear errors |
| `make test-push-stmt` | bare `push(xs, v)` in seed-min and gen2; push onto a non-list, unknown statements, string + number, number + string, string `-` and `*`, a string list element, 10+ element list literals, struct-in-list, `hold ys = xs`, list arithmetic — all clear errors or correct output |
| `make test-builtin-names` | a variable named `index`/`len`/`arg` keeps its value while `len(s)`, `chr(65)` and a nested `sx_index(s, index)` still map to the runtime helpers, on seed-min and gen2 (gen2 used to emit `sx_idx(s, sx_idx)`, which is also what made `tools/sxpkg.sa`'s `search` never match) |
| `make test-native-num` (part of `native-test`) | native doubles: `test-float`/`test-parens`/`test-push-stmt` programs give the same output as seed-min and gen2; large integer-only arithmetic, `%` truncation and `% 0` diagnostic, `%g` formatting, IEEE `/ 0`, struct-field string chains; string + number, number + string and bare non-`push` call statements are rejected with the shared wording |
| `make test-lsp` | the Sayanox language server in five live JSON-RPC sessions (probe written with shell builtins + `mkdir` only), 29 asserted facts: initialize/serverInfo, didOpen + publishDiagnostics, SX1001/SX1002/SX1003/SX1005 diagnostics, documentSymbol (function + variable), completion (builtin names survive in string literals), hover, definition, a didChange that clears the diagnostics, a closed document answering empty, the four-slot eviction cap, `references` across the open documents with and without `includeDeclaration` plus a non-word position answering `[]`, `workspace/symbol` with a query and with an empty one, and `textDocument/formatting` on a badly indented buffer (whole-buffer edit, two-space-per-level indent, trailing whitespace stripped) and on an already formatted one (`[]`) |
| `make test-generics` | two legs. (a) single type parameter: `make NAME<T> ... -> T` — 14 lines of a program mixing `pickb`/`twice`/`quad` over num, str and list print identically under gen2 and gen1_min; each `NAME__n/s/l` appears exactly once, every call sees a prototype, an unused generic emits nothing. (b) **multi-parameter**: `pair<A, B> -> A`, `swap<A, B> -> B`, `three<A, B, C> -> C` and `usefirst<A, B>` (which calls `pair` and binds the result with `hold`) over `nn`/`ns`/`sn`/`ls`/`ln`/`sl`/`nsl`, each copy asserted exactly once, per-parameter C types checked, no `#error`, no implicit declaration, and gen1_min output **byte-identical** to gen2; two rejection cases (a parameter that does not use a type parameter, a return type naming an undeclared one) |
| `make test-gc` | gen2 mark & sweep from the language side: a 2000-iteration `concat` loop stays under 200 KB of live heap after `gc()`, `gc_runs()` counts a collection, `gc()` reclaims bytes, and the surviving string is intact (`len` + first byte) |
| `make test-seed-gc` | what memory management the two seeds actually have, measured under `ulimit -v` caps: seed-min has a builder registry, a freeing assignment and (2026-10-22) a conservative mark & sweep over that registry: the 200k churn, 2000-step accumulation and temp loop stay inside a 4 MiB cap without the collector ever reaching its 8 MiB threshold, an 8388608-byte live set still exits 1 with `sx: out of memory`, and `gc()`/`gc_live()`/`gc_runs()` now report real numbers (`gc(1)` is still refused), the full seed has a refcount representation whose counts never release in a loop (`SX_GC_DEBUG=1` reports 6000 objects alive after 2000 iterations, `gc()` is a no-op returning 0, `gc_live()` is an undefined function, a 4 MiB cap cannot start it) plus the operator-lexer fix that made it compile comparisons at all, and gen2 keeps a 200k churn and an 8 MiB live set correct inside 64 MiB, checks all three of its runtime allocations, and fails at 16 MiB with `sx: out of memory` instead of a segfault |
| `make test-generic-structs` | generic structs are **implemented** on all three backends: `struct Box<T> { v }` is a template and each instantiation is its own concrete struct (`Box<num>` is `Box__n`, `Box<str>` is `Box__s`, `Pair<num, str>` is `Pair__ns`), so the gate pins those three typedefs in the generated C and the parity fixture `selfhost/generic_struct_box.sa` (`7 seven 8 7 9 nine` — byte-identical on seed-min, gen2 and native). It also pins four refusals that all three backends make (wrong type argument count, a *concrete* struct name as a type argument, a bare template name, one instantiation used with two kinds), the `Box<list>` support block that replaced the old list refusal on 2026-10-22 (`Box__l` with an `sx_list *` field, and a `push` through the original name visible through the field), the older concrete-name workaround (`NumBox`, `TextBox`, `PairBox` — `7 seven 8 eight 2 8 9`) and a dotted field read inside a struct literal as seed-min-only (gen2 `#error`, native refuses) |
| `make test-full-language-expr` | the last two broader-language readiness probes, as a three-backend parity fixture (`selfhost/full_language_expr.sa`, eleven lines): a struct literal field may be a whole checked expression (`len(text) + 1`, `(2 + 3) * 4`, `len("hello") % 3`, `span / 2 - 1`, `offset() + twice(3)`, `head + "anox"` for a string field) and an index may call a function declared `-> num` (`values[offset()]`, `values[twice(offset()) + 1]`, `values[twice(offset()) % 3]`). seed-min, gen2 and native print the same bytes; five greps pin gen2's lowered C (`((Size){(sx_len(text) + 1.0)})`, `sx_lget(values,twice(offset()))`, `sx_cat(head,"anox")`, ...). It also pins what stays refused — an unknown function and a wrong argument count on all three, a `-> str` call on gen2/native (seed-min emits C that will not compile) — and asserts statically that `true-selfhost-full` still fails closed, so passing the probes cannot turn into a full-language claim |
| `make test-generic-structs-nested` | a generic type argument may be `list` or another instantiation (2026-10-22): `selfhost/generic_struct_nested.sa` prints the same eleven lines on seed-min, gen2 and native, and both emitted C files carry all seven mangled typedefs — `Box__n`, `Box__Box__n`, `Box__Box__Box__n`, `Box__l` (`sx_list *`), `Box__s`, `Pair__Box__n_s` and the unchanged `Pair__ns` — with `Box__n` declared before `Box__Box__n`, which is the ordering property the implementation relies on instead of a sort. The list field holds the pointer, so a `push` through the original name is visible through `b.v` |
| `make test-sxpkg-online-optin` | the network is opt-in: `sync`, an `install` that has to fetch, and a remote `fetch` refuse without `SAYANOX_ONLINE=1` or `sxpkg --online <cmd>`, naming the opt-in and the offline commands and leaving no `.part` file; with the opt-in the same commands reach the transfer (a `.invalid` host, so they fail in the resolver and `sync` falls back to the offline seed); an all-local `install` and a `file://` fetch never ask |
| `make test-native-emit-split` (part of `native-test`) | the x86-64 backend is a region, not a seasoning: the 1332 lines between `EMIT-SEAM-BEGIN` and `EMIT-SEAM-END` contain no `e1(`/`e32(`/`e64(`, no `memcpy` into `code` and no direct read of the code cursor `cn` (labels come from `here()`), the seam primitives are all defined in the encoder region above `phase 1`, and an emitted program still runs. The refactor itself was checked byte for byte against the pre-seam binary on six fixtures |
| `make test-native32` (part of `native-test`) | `tools/native32.sa` emits a bounded i386 ELF for integer expressions, string spans, `len`, and variable-to-variable `concat`; deterministic bytes, ELFCLASS32/ET_EXEC/EM_386, the two program headers, entry point and image sizes are pinned. The arithmetic/control fixtures match seed-min, gen2 and x86-64 native AOT, and refusal tests cover division, fractions, unsupported literal/expression concat operands, functions, lists, unknown names, `&&`, 2^31 and unclosed blocks. Static-string, byte-index and bounded variable-concat parity across all six execution paths, plus string-index bounds and bounded-heap exhaustion on AArch64/RV64IM, are covered by `make test-sxisaexec`; i386 string-index bounds and heap exhaustion are covered by `make test-native32` when kernel IA32 execution is available. The emulator-only FP/syscall probes remain separate from compiler support. This remains a limited subset, not the full native compiler ([`NATIVE32.md`](NATIVE32.md)) |
| `make test-trust-anchor` (part of `native-test`) | the C trust anchor is one pinned, auditable file. `tools/sxaudit.sa` (Sayanox, `stdlib/crypto.sa`, compiled by gen2) recomputes the size and SHA-256 of `selfhost/seed/sxc_seed_min.c` and the gate compares them with the tracked pin `selfhost/seed/sxc_seed_min.audit` (2176 lines, 100919 bytes, `e4cc34b4…1cb9`); the seed-min rule compiles that file and nothing else (every later `.c` is generated and gitignored); the surface is exactly four standard headers with zero references to `system`, `fork`, `exec*`, `dlopen`, `dlsym`, `socket`, `connect`, `setuid`, `unlink`, `rename`, `chmod`, `remove`, `tmpnam` or `getenv`; the single `popen`/`pclose`/`curl` site is pinned at one and asserted to be inside the **emitted runtime text** (`sx_http`, behind `http_get`) rather than in the compiler; compiling the 20.1k-line compiler twice gives byte-identical C; and `all-sayanox` still refuses the all-in-Sayanox claim. **Not a solution to trusting-trust** — the seed compiled the compiler that compiled the auditor, so this is tamper evidence against drift, not immunity ([ALL_SAYANOX_PHASE.md](ALL_SAYANOX_PHASE.md#phase-e-decision-2026-10-23-option-2-and-it-is-now-measured)) |
| `make test-sxmod` (part of `native-test`) | module namespacing as a source-to-source pass: `tools/sxmod.sa`, written in Sayanox and compiled by gen2, rewrites `module NAME from "path"` and `alias.member` into prefixed flat declarations. The gate opens with the negative control — two modules that both declare `add` cannot be composed by the flat dialect at all (seed-min *duplicate function name*, `cc` rejects the C gen2 emits, native_aot *declared twice*) — then compiles the namespaced version and gets the same nine pinned lines from seed-min, gen2 and native_aot; the rewrite is deterministic; module-level names and their internal references are prefixed while locals, parameters, struct fields, comments and string literals are left byte for byte; a member is **not** reachable unqualified (`add(2, 3)` after the pass names nothing and the compiler says so); and 16 refusals each exit non-zero with a diagnostic. Not a language change: the compiler still has textual `use` and one flat name table ([`MODULES.md`](MODULES.md#namespaced-modules-as-a-pass-toolssxmod-2026-10-23)) |
| `make test-native-arm64` (part of `native-test`) | `tools/native32.sa` emits AArch64 ELF for the bounded integer/string subset, including `len`, byte indexing, and variable-to-variable `concat`. Three historical integer fixtures remain deterministic and match tracked goldens; ELFCLASS64/ET_EXEC/EM_AARCH64, program headers, addresses, code bytes and data-layout parity are pinned. `make test-sxisaexec` executes compiler-generated AArch64 and RV64 string-variable and concatenation cases in the Sayanox emulator; broader runtime features are still missing. See [`NATIVE32.md`](NATIVE32.md). |
| `make test-native-ir-portable` (part of `native-test`) | the `SX_EMIT_LOG` instruction list translates to the portable IR listing (`tools/emit_to_ir.sa`, [`NATIVE_IR.md`](NATIVE_IR.md)): deterministic (two runs cmp clean), lossless (one IR instruction per logged instruction), no x86 register names on IR instruction lines, abstract machine model preserved (`FADD`, `FCMP`, `I2F`, named `CALL`s, phase markers). An analysis format only — nothing assembles or executes it. The executable second ISA is a separate program, `tools/native32.sa` (`make test-native32`), which does not read this listing |
| `make test-native-ir-log` (part of `native-test`) | the emit tree's instruction list is inspectable and pinned: with `SX_EMIT_LOG=<path>` every encoder primitive records the code offset, the mnemonic and the operands in assembly order, plus a `;` line per label slot, per fixup, per emitted `make` and per phase — 1122 instructions, 2 slots and 41 rel32 fixups for `selfhost/native_ir_log_test.sa`, with every call target named (`call make twice`, `call builtin gccheck`). The recorder is inert (the ELF built with it `cmp`s clean against the one built without it, and against the pre-recorder compiler on six fixtures), the list is deterministic, every line is an instruction line or a comment line, the offsets never go backwards, every rel32 fixup lands on a jump, no call target or operand falls back to a placeholder name, the six phases come in order, the fixture's top-level mnemonic vocabulary is pinned exactly, and the language emitter provably never touches the recorder state |
| `make test-native-io` (part of `native-test`) | native `read_file`/`write_file`/`arg`/`arg_count` give the same results as seed-min and gen2 (argv[0] counted, truncating write returns 1, missing file reads as `""`, 160 KiB round trip) |
| `make test-native-mem` (part of `native-test`) | native memory with a real collector: a string doubled to 262144 bytes is served whole; 100000 `push`es keep every value; a 200000-iteration churn loop (~8 MB allocated, nothing retained) **finishes inside a 4 MiB `ulimit -v` cap** running 200+ collections; `gc_runs()` > 0, `gc()` reclaims bytes and `gc_live()` reports a positive live count; strings, list elements and struct fields survive 30000 allocating iterations; a program that genuinely retains 8 MiB still exits non-zero with stdout written before the failure kept and `out of memory` on stderr. See [`GC.md`](GC.md). |
| `make test-stage2-demos` | the three Stage-2 contract demos (`minimal_lexer`, `stage2_functions`, `stage2_variables`) compile byte-identically under seed-min and gen2; the string-only one also runs natively when `native_aot` is built (the native half is skipped, loudly, on the portable `true-selfhost` path, and executed in `make native-test`) |
| `make test-stage2` | gen2/gen1 Stage-2 parity plus seed/gen2 shared Stage-2 outputs and explicit seed limits (`test-seed-stage2`, `test-seed-limits`) |
| `make test-stdlib` | portable numeric helpers including interpolation on seed/gen2/native when built; string/list/file modules on gen2 and native; seed typed-module rejection |
| `make test-pkgs` | the offline package path: `sxpkg.sh init`+`seed` write `.sayanox/registry/{hello,math,strings}` with no network, `sxpkg add` records the lock, a program with `use \".sayanox/registry/math/main.sa\"` runs the same on seed-min, gen2 and native, and `sxpkg verify` passes on a clean project, reports the tampered `main.sa` as a `sum` MISMATCH, and passes again after the re-seed. **Plus the dependency path** on `registry/calc` (`deps=math@0.1.0`): `add` locks the closure and prints a line per package, the lock is compared byte for byte, `deps` prints the closure, a bare `install` reports `cannot write .sayanox/registry/<name>/`, `sh tools/sxpkg.sh install-local registry` installs both sum-checked, `verify` reports both, `use \".sayanox/registry/calc/main.sa\"` prints `36`/`25` identically on seed-min and gen2, and the `not in sx.lock` / `but sx.lock has` errors are asserted |
| `make test-gen2-gaps` | string `<`/`<=`/`>`/`>=`/`==`/`!=` by content on gen2 and seed-min, and native since 2026-10-10 (same output; string vs number is an error on seed-min); the gen2 fixes of 2026-10-08: `len(NAME)` in a range bound (list `sx_llen`, string `sx_len`); string `==`/`!=` between declared strings as strcmp (two equal runtime strings compare equal); `} else when`, `} else if` and `} otherwise when` chains including nested ones, with the same output as `elif`; seed-min and native match the conditional chain aliases; `%` inside builtin-call arguments is sx_mod, same as seed-min. |
| `make test-for-paren` | a parenthesised `for` source (`for v in (xs)`, `for c in (s)`) on seed-min, gen2 and native with identical output |
| `make test-gen2-index-mod` | `%` inside an index expression (values, conditions, for bounds, typed bodies, nested indexes), identical on seed-min, gen2 and native, `sx_mod` in the emitted C |
| `make test-type-refusals` | the type forms no backend implements are refused everywhere with a clear diagnostic: a *concrete* struct name as a generic type argument (`Box<Pt>` — this row used to be nested generics, which are implemented since 2026-10-22) and struct field annotations (`p: Pt` in a struct body, which used to silently register `Pt` as an extra field); and the gen2-only struct-typed `hold` annotation works and is type-checked there while seed-min and native refuse it by name |
| `make test-gen2-index-expr` | an index is a numeric expression in a value position, in a `when`/`while` condition, in a `for` bound and inside a typed function body: 39 hand-computed values identical on seed-min, gen2 and native; 6 unsupported index forms (a call that is not `len()` and not a declared `-> num` function — here `pick(xs)`, which takes a list — a comma, a quote, an empty index, unbalanced parentheses, a trailing operator) refused with a `min:` diagnostic and a `#error`; a negative index wraps on seed-min and gen2 and is asserted to stay refused by native. `%` in an index moved from this refusal list to supported (`make test-gen2-index-mod`). |
| `make test-gen2-expr-lowering` | the two gen2 expression gaps closed 2026-10-13: a string `+` chain in a `give`/condition joins through `sx_cat` (11 hand-computed values, `selfhost/gen2_str_cat_test.sa`), and `len(NAME)`/a nested `NAME[IDX]` inside `[ ]` lower to `sx_llen`/`sx_len` and `sx_lget`/`sx_idx` in a value, a chain operand, a condition, a `for` bound and a typed body (18 values, `selfhost/gen2_index_call_test.sa`) — both byte-identical on seed-min, gen2 and native, with the emitted C greps pinned; 5 unsupported forms (a call in an index that is neither `len()` nor a declared `-> num` function, a quote in an index, unbalanced brackets, a `+` with one string side, `%` with a string operand) refused with a `min:` diagnostic and a `#error`. |
| `make test-stdlib-modules` | the stdlib modules added 2026-10-13 (`num_util`, `list_algo`, `str_text`): 99 hand-computed values identical on seed-min, gen2 and native, each module alone, and all modules in one program; plus `json_util` (the eighth module): flat-object JSON build/read, hand-computed values byte-identical on seed-min, gen2 and native. |
| `make test-doc-claims` | no document advertises an entry point that is not in the repository: 24 legacy docs carry the "entry points do not exist" banner, `stage2_template.c` is still a placeholder, `restore_stage2.sh` still exits 1, and there is still no `stage2:` target. |
| `make test-registry-sums` | every `pkg.meta` `sum=` in the repository equals `sxpkg sum` of its `main.sa` (offline integrity; see [`REGISTRY.md`](REGISTRY.md)) |
| `make test-for-str` | the Stage-2 slice on gen2: `for c in <string>` byte walk, vowel count with `string_eq`, `break`/`continue`, empty string, nested loops, a rebound counter, `\"é\"` as two bytes, the diagnostics for a number, a list and a counter clash; seed-min matches named-source and literal cases; native runs string iteration; a `make NAME<T>` whose second parameter is not a type parameter is refused with the generic diagnostic. |
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, nested structs (2 and 3 levels, typed copy incl. doubly nested, seed-min/gen2 output parity), `use` splice (depth 2, input-dir resolution, missing-file and unquoted-path errors), functions (recursion `fac`/`fib`, 6 params, forward refs, mutual recursion, zero-arg, global assignment, builtin and string args), postfix right of `* / %` + left-assoc, string `s[i]`/`sx_index`, `else`/`otherwise` false branch, unsupported constructs rejected (incl. give-outside, make-in-block, wrong arg count/type, non-numeric give) |

## Historical roadmap snapshot (synced 2026-10-13)

This is a dated snapshot preserved for the older pass record. The current
seed|min|gen2|native table near the top of this document supersedes it,
including concrete list-valued fields and named concrete struct `hold` support.
This table replaced the 2026-10-08 roadmap when it was written. Every "done" cell names the gate
that checks it; a "missing" cell says why it is missing. "n/a" means the thing
does not exist on that backend by design (not a gap that is being hidden).

The three backends are `seed-min` (the C seed, `selfhost/seed/sxc_seed_min`),
`gen2` (the compiler built by `gen1_min`, which is what `true-selfhost`
ships) and `native` (`selfhost/native_aot`, x86-64 Linux only).

| Area | seed-min | gen2 | native | Gate(s) | Still missing |
|---|---|---|---|---|---|
| Pure-min bootstrap | root compiler | self-hosted C emitter | x86-64 Linux ELF | `doctor`, `true-selfhost`, `gen3`, `native-test` | no second native target (a portable IR *listing* exists: `tools/emit_to_ir.sa`, `test-native-ir-portable` — nothing assembles or executes it); no full-language self-host claim |
| Numeric stdlib (`tiny.sa`, 40 definitions) | yes | yes | yes | `test-stdlib`, `test-stdlib-growth`, `test-stdlib-interpolation` | small numeric library, not JSON/HTTP/crypto; new helpers: lerp, saturate, smoothstep01, distance_sq |
| String/list/file utility modules | yes | yes | yes (already implemented) | `test-stdlib` | limited helpers, not a full portable I/O abstraction |
| Boolean literals, and/or/not | yes, values and conditions | yes | yes (pre-existing) | `test-seed-stage2`, `test-logic-value`, `test-native-cond`, `test-native-logicarg` | seed numeric/string/list bare assignment now supported (`test-seed-assignment`); gen2 has expression-context limits (e.g. chr logic arguments) |
| elif, conditional aliases, break/continue | elif, else-if/else-when/otherwise-when; breaks/continues in while and supported for | yes | yes | `test-stage2`, `test-full-lang`, `test-native-lang` | seed unsupported iteration forms remain explicit errors |
| String/list for | variables, literals, checked calls and dotted field chains, inside fully typed make AND inside untyped make; literals/calls captured once per entry | variables, literals, calls, and concrete list-valued field chains | yes | `test-for-str`, `test-seed-for-literals`, `test-seed-for-calls`, `test-seed-for-untyped`, `test-seed-for-fields`, `test-native-lang`, `test-gen2-list-struct-fields` | At this historical snapshot, `for v in p.xs` was a hard error on all three. The current table supersedes that point: it works for concrete list fields on all three; generic list fields remain refused. A parenthesised source (`for c in (s)`) works on all three since 2026-10-13 (`test-for-paren`), and a parenthesised range stays refused; native function-local for is frame-local and recursion/GC tested; `_sx_iter_` is reserved in seed |
| Numeric range for | numeric literals/variables/arithmetic, indexing and len; also inside fully typed make | yes | yes; upper bound re-evaluated per check | `test-seed-for-range`, `test-full-lang`, `test-native-lang` | all three re-read upper bound each condition. Seed accepts direct field access in a bound (`for i in 0..p.n`), so the older "hold field values in numeric variables first" note is stale; a user call in a range BOUND (`for i in 0..f()`) compiles on gen2 and native but seed-min still refuses it (`seed-min for range bounds support len(...) but not other calls yet`) — verified 2026-10-13 |
| Function generics | num/str/list specialization; one or multiple type parameters | num/str/list monomorphisation | num/str/list monomorphisation (pre-existing) | `test-generics`, `test-seed-limits`, `test-native-generics`, `test-native-strgen`, `test-native-listgen` | some backend-specific body/lowering gaps; struct generics are a separate row below |
| Typed functions | num/str/list parameters and returns, isolated locals, control flow, terminal give | broader typed functions, some lowering gaps | typed functions; kind-preserving parameter reassignment | `test-seed-typed-functions`, `test-typed-sig` | seed global capture and full return-path inference remain absent |
| Function-local hold | yes | yes | frame-local, recursion tested | `test-native-locals`, `native-test` | no new ABI or second architecture |
| Explicit hold types | num/str/list outside make and inside fully typed make; initializers, assignments and reannotations checked | num/str/list syntax already accepted | num/str/list, also function-local and bound generic T | `test-seed-hold-types`, `test-full-lang`, `test-native-generic-local` | seed untyped-function annotations; a *struct*-typed annotation (`hold p: Pt = Pt { 1, 2 }`, even `hold b: Box__n`) is **gen2-only** as measured 2026-10-13 — gen2 accepts and type-checks it, seed-min and native refuse it by name (`test-type-refusals`) — see [type design](TYPES_ROADMAP.md) |
| Struct types | literal-typed, plus generic templates: `struct Box<T> { v }` instantiated per type argument as `Box__n`/`Box__s` | literal-typed, plus the same templates rewritten to their mangled concrete name before the walker runs | literal-typed, plus templates instantiated at both literal sites with per-instantiation field kinds for the collector | `test-struct2`, `test-nest`, `native-test`, `test-generic-structs` | a type argument is `num` or `str` only (no nested instantiation, no struct or list argument); gen2's wording for a bad type argument list is its general `undefined name`/stray-token error, and gen2 learns a field kind from a single contradicting literal where seed-min and native refuse it — all measured in [TYPES_ROADMAP.md](TYPES_ROADMAP.md). A dotted field read inside a struct literal stays seed-min-only |
| GC | mark/sweep over the builder registry since 2026-10-22 (strings only; lists never freed) plus the freeing assignment wrapper | mark/sweep, all three runtime allocations checked | mark/sweep | `test-gc`, `test-native-mem`, `test-seed-gc`, `test-seed-collector` | measured 2026-10-22: seed-min collects dropped temporaries (gen1-min peak 1,278,704 → 29,768 KiB, identical gen2 C) and a live set still fails as `sx: out of memory`; the full seed's refcount table never releases in a loop (`SX_GC_DEBUG=1` reports 6000 objects alive after 2000 iterations) and `gc()` there is a no-op; gen2's first collection fires at 8 MiB of managed heap, so it needs more address space than native; conservative native stack scanning |
| Packages, offline | tool built by gen2 | registry/lock/deps/install-local/verify | not a native-tool claim | `test-pkgs`, `test-sxpkg-polish`, new `test-pkg-errors` | search no longer implicitly syncs; shell still supplies filesystem/process operations; execution failures now propagate |
| Packages, online | not bootstrap | explicit sync/install/fetch commands, **opt-in** since 2026-10-13 | n/a | `test-sxpkg-online-local`, `test-sxpkg-online-optin` (both in the aggregates, both socket-free) | no cryptographic integrity (`pkgsum` detects edits; it is not a hash anyone should trust for provenance), no signatures, no remote publish; shell `publish`/`fetch` write `sum=` since 2026-10-13, matching the Sayanox implementation, so shell-handled packages verify the same way; `SAYANOX_REGISTRY` says where, `SAYANOX_ONLINE=1`/`--online` says whether |
| LSP | tool built by gen2 | existing .sa JSON-RPC server | n/a | `test-lsp`, `test-lsp-robust`, `test-lsp-unicode` | **four documents** open at once since 2026-10-13 (a fifth evicts the oldest), each request answered from its own URI's buffer and an unopened URI answered empty; still no workspace index or cross-file analysis: references, workspace/symbol and rename see **open buffers only**, signature help needs the declaration in the same document and the call on the same line, and the only code action is formatting; rename, signature help and the format code action added 2026-10-13 and pinned by the probe's sixth session (`test-lsp`, 38 facts); UTF-16/Unicode and empty changes tested by `test-lsp-unicode` |
| Platform | host C | host C | x86-64 Linux only | four bootstrap gates | other native platforms unsupported, not emulated |

### Changes and verification in this pass

* Added four portable numeric helpers and hand-computed cross-backend tests.
* Added the bounded seed Stage-2 subset above, including precedence,
  short-circuit guards that would otherwise divide by zero, nested loops,
  source rebinding, empty strings and UTF-8 byte iteration. Extended existing
  stage2/for-str gates; replaced obsolete continue/elif rejection tests with
  exact-output tests. Unsupported iteration and generic forms fail explicitly.
* Strengthened the shared `assert-out` helper: correct stdout with a nonzero
  process exit is now a test failure. The intentional native OOM test instead
  explicitly checks nonzero status, retained stdout and the OOM diagnostic.
* Packages: search without a local index is an offline error, not an implicit
  download; checked wrapper no longer swallows execution/project failures.
* Re-tested existing native boolean values, numeric/string/list generics,
  local holds, offline packages and LSP probes. Did not reimplement or claim
  these as new features. Corrected prior contradictory roadmap rows.
* Generic structs have a design/deferral document. The first pass did not add
  hold annotations or LSP protocol changes; the continuation below does. Seed
  generics, a full inference rewrite and native ABI changes remain unfinished.
* No Linguist PR, no extension remapping, and no network bootstrap step.

`selfhost/STAGE2.md` describes a legacy separate stage2 binary. The maintained
path is seed-min → gen1_min → gen2 → gen3/gen4, with byte-identical gen3/gen4
checked by `make gen3`. `true-selfhost-full` remains unimplemented.

### Continuation: remaining-work progress

* Seed-min bare assignment for existing numeric/string/list variables now
  shares the hold emission path, with explicit type mismatch errors. Added
  conditional aliases (`else if`, `else when`, `otherwise when/if`) to both
  scanner and emitter; old rejection tests now compare real output with gen2.
* Added checked seed `hold name: num/str/list` outside functions. Function-local
  annotations and parameters shadowing annotated globals fail clearly rather
  than silently reusing incorrect storage. See `test-seed-hold-types`.
* Fixed seed string self-assignment for underscore/runtime-prefix variable
  names and collision with the old generated `_sx_v` temporary. Prefixes no
  longer imply owned runtime-call results. A separate seed-only regression
  fixture also ran under AddressSanitizer (leak checking disabled). Gen2 does
  not currently compile the leading-underscore fixture; no parity is claimed
  for those names.
* LSP now handles UTF-16 positions and BMP/surrogate-pair JSON escapes. Added
  real protocol tests with Latin/Bengali/emoji, empty document changes, empty
  change arrays, unrelated-URI changes, and close-state cleanup.
* Each area passed doctor/true-selfhost/gen3/native-test. The final logs were
  regenerated after the edge-case fixes. No seed generics, broader iteration,
  generic structs, multi-document LSP or second native target is claimed.

### Next increment: literal iteration (2026-10-12)

Seed-min now accepts `for ch in "abc"` and `for value in [1, 2, 3]`
outside `make`. Each literal source is evaluated once per loop entry into a
reserved hidden temporary, including numeric expressions/calls within a list.
Named sources retain their existing re-read-each-iteration semantics.

`test-seed-for-literals` is included by both `test-stage2` and `test-for-str`.
It checks hand-computed output on seed/gen2, plus native parity when built:
side effects occur once per entry, body mutations do not re-evaluate the list,
empty loops execute no body, nesting works, break/continue progress correctly,
and UTF-8 strings iterate by byte. Incompatible binders, nonnumeric list
members, reserved-name collisions and unsupported source expressions fail.
At the end of that increment, range sources, call-result sources, function-local
for, and seed generics remained unfinished. Numeric ranges are added below. This change does not introduce a
collector into the seed runtime.

### Next increment: numeric range iteration (2026-10-12)

Seed-min now accepts `for i in 0..N`, including negative/fractional bounds,
arithmetic, parentheses and `len` of lists/strings. The start is assigned on
entry, the upper expression is re-read on every condition test, the comparison
is strict `<`, and the counter advances by 1. `continue` reaches that step;
`break` leaves without stepping. Reassigning the counter affects progression.
An empty/reversed range performs no body. New counters are numeric; an existing
string/list counter or a language-keyword binder is rejected.

`test-seed-for-range`, part of `test-stage2`, checks exact seed/gen2 output and
rejection of malformed bounds, wrong types, invalid len arity/operand,
undefined names, bad indexing, unsupported calls/fields and invalid numeric
literals. The `..` lexer exception applies only inside range headers: `show
1..2`, `show 2.` and `show 1.2.3` remain errors. Old range-rejection tests in
`test-full-lang` and `test-native-lang` are now positive seed output checks.

**Historical divergence (fixed by the native range increment below):** native evaluated its upper bound once, while
seed/gen2 re-evaluate it. Changing `limit` or replacing the list used by
`len(xs)` inside the body therefore yields different loop counts. The new
native regression leg asserts a separate, hand-checked snapshot expectation,
not false cross-backend parity. Native code was not modified. Predeclare a
native counter if its post-loop value is needed. This semantic alignment is
still missing work, not silently fixed by the seed implementation.

The seed range subset deliberately refuses function calls other than `len`
(and its existing `sx_len` alias), direct field access in bounds, and all for
loops inside functions. At the end of the range increment, call-result iteration was still unfinished.
The producer/call increment below adds a subset; seed generics and
function-local iteration remain unfinished.

### Earlier increment: call-result iteration and typed producers (2026-10-12)

Historical boundary: the following describes that increment alone. The fully
typed-function increment below supersedes its parameter/body restrictions.

Seed-min now accepts plain string/list-producing calls as `for` sources,
including checked builtins and zero-argument user producers with explicit
`-> str` / `-> list` returns. The call runs once per loop entry; its returned
reference is kept in a hidden temporary. Rebinding an input string during
the loop does not re-run the call. List references are not deep copies, so
mutations to the same list remain visible. Numeric call results are refused
as collection sources. Numeric range-bound restrictions are unchanged.

All parser passes share a function-header reader and a signature registry.
Generated C has prototypes, and call result kinds drive both expressions and
global hold collection. New annotated producers have isolated local symbol
tables; they cannot accidentally reference main's C locals. Argument
count/kind checks apply in call-source and producer expressions. Return kinds
are checked; a producer must end in an unconditional give. Supported bodies
are straight-line hold/show/give/push/assignment statements. Parameters,
control flow, global capture, structs and local hold annotations are not
added to this producer subset. Existing unannotated numeric functions remain
available. Generic monomorphisation is not implemented by this registry.

`test-seed-for-calls` is included by `test-stage2` and `test-for-str`. The shared
fixture checks one evaluation per entry, returned strings/lists, producer
locals versus same-named globals, nested/empty loops, break/continue, builtin
sources (including read_file) and ordinary holds of producer results, with
hand-computed output on seed/gen2 and native parity when built. Negative
cases cover mismatched gives/arguments, missing terminal give, unsupported
bodies/parameters, unknown functions/variables and duplicate definitions.
The seed's 16-argument and 64 KiB call-lowering limits now fail explicitly.

A separate seed-only fixture checks typed forward calls and literal-list
returns. At that step gen2 lacked typed forward prototypes (now fixed below)
and had limits on direct list-literal returns/nested push literals (bounded
support is added in the later list-expression increment); the shared
fixture uses declaration order and named list locals. No broader gen2/native
parity or general typed-parameter support is claimed. Seed allocations remain
uncollected; this does not add a GC or a leak-free runtime.


### Fully typed seed functions (2026-10-12)

Seed-min now accepts all-or-nothing num/str/list parameter annotations with
explicit num/str/list returns. Calls check argument counts and kinds, even
in main and nested argument expressions; prototypes carry the same kinds.
Fully typed functions have isolated parameters/locals, stable kinds, local
hold annotations, conditional/loop control flow, early returns and supported
for forms. New nested-block locals expire at block end. Existing outer holds
reassign rather than shadow. A terminal top-level unconditional give remains
mandatory. String parameters are copied before local mutation; list parameters
retain shared-reference semantics. This is not a GC implementation.

`test-seed-typed-functions` covers alias-safe string parameter assignment,
list mutation, recursive calls, while/when, annotated locals, recursive for,
nested list/string walks, break/continue, checked call sources, scope errors,
wrong call arguments and signatures. Extended fixtures compare seed/gen2;
seed-only cases cover sibling-block names, typed forward calls and boolean
literal call arguments. Those cases now also pass on gen2, as recorded below. Native
now passes the typed-parameter fixture via test-native-param-reassign, but
now supports function-local for, tested with a shared unannotated-local
fixture. The original annotated-local fixture now also runs on native.

`test-typed-sig` now runs its numeric recursion fixture on all three backends;
`test-stage2` compares its mixed fixture on seed/gen2/gen1_min. `test-stdlib`
now runs str/list/file utility modules on seed and compares all output with
gen2, retaining the existing native expected-output test.

At that increment, still missing: seed generic specialization, generic structs/concrete type
identity, global captures in typed seed functions, general return-path
analysis, untyped-function for, arbitrary iterable expressions, native list-alias behavior across capacity
growth and the gen2 lowering gaps above. See SYNTAX.md and
TYPES_ROADMAP.md for the exact supported boundary.

Validation after the final nested-call argument guard: `make doctor`,
`make true-selfhost`, `make gen3` and `make native-test` all exited 0; gen3 and
gen4 were byte-identical. Logs: `docs/logs/make-doctor.log`,
`make-true-selfhost-min.log`, `make-gen3.log`, `make-native-test.log`, and
`seed-typed-functions.log` (paths relative to docs/logs for the latter four).


### Native parameter reassignment and live range bounds (2026-10-12)

Two separately gated increments:

* Native assignments to parameters now enforce each parameter's declared
  num/str/list kind and store into its call-frame slot. Lookup matches reads:
  a parameter takes precedence over a same-named global. Statement-boundary
  recognition now permits a following parameter assignment (actual binding
  validation remains in the statement emitter). No eager free is introduced;
  native strings returned by concat are fresh, and the collector scans frames.
* Native numeric range upper expressions now execute at each condition check,
  rather than before the loop. The start is still evaluated only on entry.
  Break does not recheck; continue advances the counter then rechecks.

`test-native-param-reassign` covers the previous typed-parameter fixture,
string recursion/caller preservation, list rebinding/mutation, wrong-kind
errors, same-named globals and explicit GC across recursive frames. The new
portable fixture matches seed/gen2/native. GC/name-collision cases are tested
separately on native. List capacity-growth alias parity is NOT established:
the native runtime may replace a list object on growth, leaving other aliases
on its older storage. This remains runtime work.

`test-seed-for-range` now uses ONE expected output for all three backends,
including shrinking bounds and len of a replaced list. The native-only
`test-native-range-live` also checks upper-call side effects, empty ranges,
break and continue; seed/gen2 reject user function calls in range bounds.

After EACH increment all four gates exited 0, with byte-identical gen3/gen4.
Canonical docs/logs gate logs now contain the final range increment. Focused
logs: native-param-reassign.log and native-range-live.log. Seed generic
specialization, generic structs, native function-local for and documented
gen2 lowering gaps remain unfinished; these changes do not claim them.


### Native function-local for, list aliases, seed generics (2026-10-12)

Three further implementation areas were completed and separately gated:

1. **Native function-local for:** range/list/string loop binders and hidden
   state now occupy the current call frame, not global slots. Parameter
   binders reuse their parameter slot with kind checks; new locals do not
   mutate same-named globals. Hidden names cannot be spelled by source code.
   Recursive loops, nested loops, early return, break/continue, explicit GC,
   binder mismatches and hidden-name collisions are tested. There is a clear
   64-level loop-nesting limit. The first shared fixture uses inferred locals; a subsequent native
   annotation increment below covers the original typed-local fixture too.
2. **Native list growth aliases:** payload +8 now holds a successor link.
   Push resolves the latest object and links growth back to the old object;
   len/index/show resolve the same chain. The collector traces the link,
   not numeric elements. No same-named global is rewritten when pushing a
   parameter. Tests cover 100-element growth through a parameter, different
   generations of aliases, ordinary rebinding, explicit collection and
   reclaimed-block reuse. Old aliases can retain earlier growth buffers;
   this is not a compacting collector or a no-overhead identity scheme.
3. **Seed generic functions:** a demand-driven worklist generates and checks
   concrete num/str/list bodies, with independent type variables, recursive
   calls, mutual recursion, local type annotations, deduplicated variants,
   prototypes and deterministic output. Function/type/source limits fail
   explicitly. No generic struct syntax or layout is implied. Shared tests
   cover basic/multi-type calls and numeric recursion on all three backends;
   extended nested/string-only recursive cases are seed-only because of
   an observed gen2 limitation. Native now passes the extended fixture after
   demand-driven generic emission. See GENERICS.md for the exact contract.

Focused targets: test-native-for-functions, test-native-list-alias,
test-seed-generics (also the existing test-generics multi-parameter fixture).
Each area passed doctor, true-selfhost, gen3 and native-test before moving
on. Final canonical logs include the combined changes and final hardening.
Seed compiler ASan/UBSan checks on the extended/scope generic fixtures also
passed with leak detection disabled (not a runtime leak-free claim).

**At that increment, still incomplete:** generic structs/concrete type
identities and cross-backend layout/GC checking; gen2 forward/scope/boolean/
list-expression and nested-generic lowering gaps (see the later fixes below); broader iterable-expression/seed untyped-function
support and whole-function return analysis. These are not reported as PASS.


### Native local annotations and demand-driven generic bodies (2026-10-12)

A fourth separately gated area adds optional num/str/list hold annotations
to native collection, inference and emission. Concrete generic bodies can
use `hold x: T`; wrong types and unknown annotations fail explicitly. Native
now compiles the original annotated typed-loop fixture and the existing
multi-parameter generic/local-annotation fixture.

Numeric generic bases join the same demand worklist as string/list variants;
unused templates no longer force a numeric body. This fixes the string-only
recursive template in seed_generics_extended_test.sa on native, while that
fixture still exposes a gen2 nested-specialization failure. A separate shared
fixture checks annotated locals, list aliases, string-only templates and an
unused body across all three backends. No gen2 source was changed here.

After this final area all four gates again exited 0, including byte-identical
gen3/gen4. Canonical logs in docs/logs now correspond to these final changes.
Generic structs and the documented gen2/scope/expression gaps remain open;
this is substantial progress, not an all-language-complete claim.


### Gen2 forward calls, function scope, booleans and nested generics (2026-10-12)

Four separately tested and gated compiler_min.sa increments:

* **Typed forward prototypes:** ordinary num/str/list functions now contribute
  C prototypes before bodies; generic prototypes are reused. Zero-argument
  definitions use void. String/list forward returns and mutual recursion
  pass strict C prototype/implicit-declaration checks and seed/native parity.
* **Function declaration scope:** function name tables start empty before
  parameters are registered. Source blocks preserve outer declarations but
  expire newly introduced locals; sibling branches can use the same name
  with different kinds. Nested while/for and elif wrapper bookkeeping are
  tested. Legacy top-level flat declaration tracking remains unchanged.
* **Boolean call arguments:** whole true/false tokens in expression positions
  lower to doubles, preserving strings, longer identifiers and boolean-named
  struct fields. A shared fixture passes on seed/gen2/native; comparison
  arguments are separately gen2-tested (native rejects that case).
* **Nested generic queue:** consecutive request separators no longer turn a
  kind into a bogus function name. Template lookup only examines record
  headers, not matching parameter/body fields. The previously crashing
  extended generic fixture and a name-collision fixture now pass. Extended
  emitted C is identical between gen1_min and gen2.

Targets: test-gen2-forward, test-gen2-function-scope,
test-gen2-boolean-args, test-gen2-generic-queue. The original
seed_typed_scope_test.sa was also manually checked on gen2: output
9 / 11 / forward! / 1. The scope fixture is seed/gen2, not a claim about
native sibling-kind scope semantics or complete undefined-name analysis.

After each area doctor, true-selfhost, gen3 and native-test exited 0;
gen3/gen4 remained byte-identical. The offline compiler bundle was regenerated
with make pack-compiler after each source increment and its decoded bytes
compared to the source. Final SHA-256:
a8c0bbf59df4316fdbdf803bc7121eee1d8a6a7d92bfdb9e92c67a075cae3ccc
(96 gzip/base64 parts of at most 1100 characters).

At that increment, still open: generic structs/concrete type identity and
layout/GC work; direct list-literal returns/general list expressions on gen2; complete
undefined-name/return-path analysis and broader iterable/legacy-function
support. Further generic inference edge cases are not implied fixed by a
queue repair. No all-language-complete claim is made.


### Gen2 list returns, literal call arguments and GC anchor (2026-10-12)

Three further separately gated areas:

* Direct complete list-literal returns in -> list functions now lower through
  the existing checked hold/list parser at the return's original location.
  Empty/arithmetic-element lists, observed element calls, early returns,
  forward/generic functions and collision-free temporary names are tested.
  Seed/gen2/native output matches; gen1_min/gen2 generated C is identical.
* Empty/signed-decimal numeric list literals now work inline in call arguments,
  including push, len, user/generic calls and nested pushes. Allocations remain
  inline (a loop-condition regression detects accidental hoisting). Casts to
  double preserve the variadic list ABI. List-valued literal/call operands
  select list helpers. Expression elements still require a named hold;
  unsupported/malformed inline forms produce #error diagnostics. Direct
  list sx_index is a separate gen2 case, not native parity.
* An additional -O0 check exposed an existing GC anchor placement problem:
  the optimizer-dependent layout could put the main anchor below live locals.
  Generated programs now execute under a caller-frame anchor via a volatile
  indirect call and post-call store. Both -O0 and -O2 compiler binaries emit
  identical C for the new fixtures; generated programs preserve string/list
  and function roots across 2,000 explicit collections. Name collisions are
  tested. This is a tested-host fix, not a universal conservative-GC proof.

Targets: test-gen2-list-return, test-gen2-list-args, test-gen2-gc-roots.
The failed -O0 probe was fixed before final validation, not waived. After each
area all four gates exited 0; the final combined gen3/gen4 are byte-identical.
The offline compiler bundle was regenerated and round-trip checked. That increment
source SHA-256: ab08bb4c7d181189d16f97a1817f91a11f68b8a506be83e43c137150ce9e8e14
(99 parts, at most 1100 base64 characters each).

Still missing: generic structs and concrete type/layout/GC identities;
fully general inline list expressions (use named holds for numeric expression
elements), complete undefined-name/return-path analysis, and the other
backend-specific expression/scope limits documented above. None are marked
complete by these bounded additions.


### Gen2 inline list constant arithmetic (2026-10-12)

Extended the inline literal parser from signed decimal atoms to constant
arithmetic: unary signs, + - * / and balanced parentheses. Decimal tokens
are normalized to doubles before C emission, preserving fractional division,
precedence and left associativity. Parentheses inside a list no longer
misroute the enclosing call to the numeric-only grouping-expression path;
return/condition rewrites leave list division to the list parser. Call-text
collection retains whitespace inside brackets, so `[1 2]` is diagnosed
instead of silently becoming `[12]`.

`test-gen2-list-arithmetic` verifies generic list results, nested push/len,
return and when/while call paths, fresh loop-condition allocations, quoted
text, fractional division and leading-zero decimal constants. Seed/gen2/native
outputs match; gen1/gen2 C is identical; generated -O0/-O2 programs both pass.
The expanded negative suite rejects malformed groups/numbers, adjacent
numbers, names/calls, modulo/comparisons, nested lists and list postfix forms.
Both targets are part of the standard gates.

The offline bundle was regenerated and round-trip checked (99 parts).
Current compiler SHA-256:
f33bf80644ae6ccafd24fd8cbf1023e67170ffcfc85b2dbcaa48e3002321537c
All four gates exited 0, with gen3/gen4 byte-identical. Actual focused logs
and gate tails: docs/logs/gen2-list-arithmetic.log and
docs/logs/gen2-list-arithmetic-gates.log; canonical gate logs are refreshed.

Still open: inline elements containing names/calls (use a named hold),
modulo/comparisons in inline lists, general list postfix/compound expressions,
generic structs, and full undefined-name/return-path analysis. This is a
bounded extension, not completion of the expression/type-system roadmap.


### Structural return paths across three frontends (2026-10-12)

Implemented a conservative structural return proof in the seed, gen2 and
native frontends. Explicitly typed functions and generated generic instances
must not fall through. Exhaustive/nested branch chains and returning suffixes
are accepted; seed's old terminal-top-level-give restriction is removed.
Loops may execute zero times for proof purposes; no constant-condition or
termination analysis is claimed. The scanner ignores strings/comments and
balanced expression delimiters, and refuses to prove nesting beyond 128.
Ordinary expression/type validation remains separate. Untyped behavior is
unchanged.

`test-return-paths` is wired into test-typed-sig and native-test. It checks
num/str/list and generic successes against all three backends, byte-identical
gen1/gen2 C, and missing arms, nested fallthrough, loop-only returns,
unreachable loop returns, and fake give tokens in comments/strings. C output
is also built with -Werror=return-type. The fixture exposed and now regresses
two gen2 bugs: a nested real else could prematurely close an enclosing elif
wrapper, and give text treated quoted braces/comment markers as syntax.

All four gates exited 0; gen3/gen4 remain byte-identical. Packing crossed 100
parts and exposed lexicographic misordering of two-digit chunk filenames.
The packer now writes four-digit filenames; restore also accepts the legacy
first-chunk filename. The 101-part bundle round-trips, and a missing-source
restore to a separate test path was compared byte-for-byte with the source.
Current compiler SHA-256:
d740da4a6745b5f30aa3b5de278bf3fa33b9b1786e7b556c17ad2d18ddfbdddd
Logs: docs/logs/return-paths.log, return-path-gates.log, return-path-restore.log,
and the refreshed canonical gate/pack logs.

Still unfinished: generic structs/concrete type identities and layouts;
inline-list variables/calls/modulo/comparisons and general list expressions;
complete undefined-name checking and the other backend limitations recorded
above. The structural return-path portion is implemented, not the whole
compiler roadmap.


### Gen2 reference resolution (2026-10-12)

Implemented pre-lowering value/call reference checks using the current binding
and signature tables, across hold/show, assignments/indexed writes, push,
conditions, for headers and give. Nested call arguments and list/index
expressions are included. Unknown values/callees now produce explicit #error
diagnostics; they are not left as unexplained identifiers in generated C.
Function scope expiry prevents parameters/branch locals leaking to other
scopes. Forward signatures, generic instances, field labels/selectors,
builtin-like binding names, and quoted/commented text retain their behavior.

The first true-selfhost run exposed a missing string-iterator binding in the
lookup: those binders can exist in sdecls without decls. Lookup now covers all
three value tables; a generic string-iteration regression was added. After
that fix, the focused target and all four gates exited 0. gen1/gen2 fixture C
and gen3/gen4 compiler C are byte-identical. Positive output agrees across
seed/gen2/native; 31 negative programs cover missing references/callees.

`test-name-resolution` is wired into test-typed-sig and native-test. Logs:
docs/logs/name-resolution.log and name-resolution-gates.log, with the canonical
gate and pack logs refreshed. Offline bundle round-trip passed (103 parts).
Current compiler SHA-256:
1be1bdd3f4b38fe6625472df16f25c993f683431cf7178ee6653fc5c7df888b7

Boundary: name lookup follows the existing binding contract; the legacy
main-level flat policy is unchanged, and this does not prove definite
assignment or perform complete expression type inference. Generic structs,
inline list variables/calls/modulo/comparisons and general list expressions
are still unfinished. These are not marked complete by the name checks.


### Typed inline numeric-list expressions (2026-10-12)

Implemented pre-emission typed lowering for inline list literals in supported
expression statement paths. Elements now accept numeric names, arithmetic,
modulo/comparisons, indexing, numeric-returning ordinary/generic calls, and
nested list consumers. Nested calls check parameter counts/kinds and returns;
wrong element/operator/index kinds are rejected. Concrete generic parameter
metadata is registered at request time as well as definition time.

Generated automatic double temporaries plus comma expressions preserve the
variadic ABI and left-to-right, single evaluation of inline list elements.
Their declarations are outside the statement, but assignments and allocation
stay inside each expression (including every loop-condition check). A private
prefix avoids source-name collisions. This guarantee is for the new inline
path; existing hold/direct-return list lowering is not rewritten. Seed's
variadic evaluation order is not claimed to match. Native list kind inference
and element counting now use its comparison-aware parser.

Tests: test-inline-expressions and test-inline-runtime, wired into the gates.
The common expression fixture matches seed/gen2/native. Separate sequence
fixtures match gen2 -O0/-O2 and native, covering side effects, mutable-list
observations, fresh conditions and helper-name collisions. Negative cases
cover type/arity errors, malformed expressions and unsupported postfix forms.
Additional -O0/-O2 compiler binaries emit identical C for the expression fixture.

An extra minimal test after the initial green gates found that inline-only
string expressions failed to request string runtime helpers. This was fixed,
a permanent regression was added, and all four gates were rerun successfully.
Final doctor/true-selfhost/gen3/native-test exit 0; gen3/gen4 are byte-identical.
The offline bundle round-trip passes (107 parts). Current compiler SHA-256:
71402d5e701251336eb4658fcda801de9917b26bd7fe5f466cc4dc596b0b8d50
Logs: docs/logs/inline-expressions.log, inline-expression-gates.log,
inline-expression-extra.log, plus refreshed canonical gate/pack logs.

Remaining: generic structs/concrete layouts and type identities; arbitrary
list postfix/compound expressions and inline struct-field expressions (use
named numeric holds); seed sequencing parity; full type/definite-assignment
analysis and previously documented backend limits. These are not marked
complete by this increment.


### Seed sequencing and checked field/list postfix calls (2026-10-13)

Two implementation areas were independently four-gated:

1. Seed numeric list constructors now use a source-collision-free linked
   builder stack and comma expressions. Element evaluation is left-to-right
   and once only, including nested/recursive constructors. Shared sequencing
   and builder-collision fixtures pass seed O0/O2, gen2 and native.
2. Gen2 inline numeric-list elements now resolve named/nested struct fields.
   Known calls containing list/index syntax are parsed as whole typed
   expressions, accepting grouped literal indexing and indexed list-returning
   calls while checking outer argument kinds. Generic argument inference
   refines first-token guesses with resolved expression kinds; nested list
   commas no longer split multi-parameter arguments. Seed permits checked
   named-struct/field-chain access only after validating the field metadata.

`test-list-postfix` checks seed/gen2/native parity and seed/gen2 rejection of
unknown fields, nonstruct selectors, nonnumeric elements, invalid index kinds
and list-parameter mismatches. Existing inline expression regressions remain
green. Both new targets are wired into typed-signature/native-test gates.

Actual results after EACH area: doctor, true-selfhost, gen3 and native-test
all exited 0; gen3/gen4 were byte-identical. Full logs:
`docs/logs/seed-sequence-gates.log`, `docs/logs/list-postfix-gates.log`.
Focused logs: `docs/logs/seed-list-sequence.log`, `docs/logs/list-postfix.log`.
Canonical gate logs are refreshed to the second area's run.

Offline bundle round-trip passes (109 parts). Current compiler SHA-256:
7ca320d53672c33c19396d607b18872ec818985f6af38c45047a9e66492ca061
See `docs/logs/gen2-offline-pack.log`.

**The full requested scope is not complete.** Generic structs/concrete layout
and type identities remain unimplemented. Arbitrary literal-headed postfix
and compound expressions outside the checked call paths remain open (for
example direct `hold n = [1][0]`). Gen2 legacy named-hold/direct-literal-return
list constructors still lack the new ordering guarantee. Struct-valued field
initialization retains the documented nested-literal restriction. Full type
inference/definite assignment and previously documented backend limits are
not claimed. The older increment sections above are historical snapshots.


### Seed `for` inside untyped `make`, call and field sources (2026-10-13)

The last unsupported seed `for` forms are now compiled rather than refused.
Nine changes to `selfhost/seed/sxc_seed_min.c` (`for_header`,
`field_chain_source`, the struct-metadata pass and the emitter) plus two gen2
fixes in `selfhost/compiler_min.sa`:

1. `for v in make_xs()` — a call as the iteration SOURCE, inside or outside a
   `make` body. The call is hoisted into the hidden per-loop temporary
   `_sx_iter_src_%u`, so it is evaluated once per loop entry, exactly like a
   literal source. The result must be `str` or `list`; anything else is a
   `seed_min:` error, and a call whose type is not yet known in an early pass
   resolves non-fatally instead of poisoning the pass.
2. `for v in p.items` and `for c in p.name` — dotted field chains as sources,
   walked by `field_chain_source()`, which stops at `..` so a numeric range
   bound that contains a field is still parsed as a range.
3. `for` inside an UNTYPED `make` body (no parameter or return annotations),
   where the body scope is isolated: hidden temporaries are per-loop, and the
   iteration variable does not leak.
4. A struct local declared inside a `make` body (`hold p = P { n: 2 }`) is
   accepted by seed-min, gen2 and native and prints the same value.
5. Field-source parsing resolves non-fatally in the early passes and is only
   enforced once `types_final` is set; routing it through `atom()`/`expr()`
   early was tried and rejected, because those helpers hard-fail on names the
   type pass has not registered yet.
6. `atom()`'s undefined-name check had to keep an exemption for a struct
   literal (`find_struct(id) >= 0 && S[P] == '{'`); without it, valid struct
   locals stopped compiling.
7. gen2 emitted `sx_len` without the `static double` storage class in one path,
   which broke `-Werror` builds of the generated C; fixed in
   `compiler_min.sa`.
8. An index mutated in the same statement that dereferences it
   (`si = -1; kind = SD[si].fty[ff] ? ...`) read `SD[-1]`, because the
   assignment is sequenced before the right-hand side. The index is now set in
   a separate statement. This is a language-level trap worth remembering: never
   mutate an index in the same statement that dereferences it.
9. `test-seed-limits` used to assert a refusal loop for a form that is now
   supported. That case was converted into an exact-output positive check, as
   is the convention whenever a documented limitation is removed.

Fixtures and expected stdout (three-way identical, hand-computed):

* `selfhost/seed_for_untyped_test.sa` →
  `6,a,b,c,x,y,7,8,9,0,1,2,3,12,a,b,c,d,0,2,4,6,0,untyped-for-done`
  (`SFU_WANT`, `make test-seed-for-untyped`)
* `selfhost/seed_for_fields_test.sa` →
  `a,b,x,y,7,p,q,z,0,a,c,2,2,m,n,2,2,3,fields-done`
  (`SFF_WANT`, `make test-seed-for-fields`)

Both targets also assert that gen2 emits `static double sx_len`, that a struct
local inside a `make` body compiles to `7` on all three backends, and that 10
(seed-for-untyped) plus 6 (seed-for-fields) malformed programs exit non-zero
with `seed_min:` in stderr. The older malformed list-typed-field iteration
case is no longer a current boundary: concrete inferred list fields support
`for v in p.xs` on seed-min, Gen2 and native under the focused list-field
gates. Parenthesised iteration sources are also supported where documented.

Not claimed: a global read inside an untyped `make` body is still refused by
seed-min and gen2 (native prints the value — recorded under "Measured
divergences"). Generic list-field specialization and several other full-
language forms remain outside the bootstrap dialect.

### Stdlib growth: `num_util.sa`, `list_algo.sa`, `str_text.sa` (2026-10-13)

Three new modules, 52 helpers, in `make test-stdlib-modules` (wired into
`test-stdlib`, `test-stdlib-growth`, `test-stage2`, `test-for-str`,
`native-test` and the `true-selfhost-min` aggregate):

| Module | Prefix | Helpers | Notes |
|---|---|---|---|
| `stdlib/num_util.sa` | `nu_` | 17 | untyped and numeric, so the native-AOT subset runs it too, like `tiny.sa` |
| `stdlib/list_algo.sa` | `la_` | 17 | typed `list` parameters; every transform returns a NEW list |
| `stdlib/str_text.sa` | `t_` | 18 | typed `str` parameters; byte-oriented, ASCII-only |

`selfhost/stdlib_modules_test.sa` prints 99 hand-computed values, and seed-min,
gen2 and native must print byte-identical stdout — including two deliberately
empty lines (`t_slice("hello", 9, 2)` and `t_trim("   ")`) and two lines with
trailing/leading spaces (`t_pad_right`, `t_pad_left`). The target additionally
compiles each module alone, and compiles all seven modules together in one
program on all three backends, which is what proves the new prefixes do not
collide with the existing `s_`, `l_`, `f_` and `tiny.sa` names.

`nu_trunc` is built on the one double-to-integer conversion the pure-min
dialect offers — `x % 1000000000000000`, because `sx_mod` casts both operands
to `long` — and every other rounding helper derives from it. Verified identical
on seed-min, gen2 and native: `2.75 → 2`, `-2.75 → -2`, `-7 % 3 → -1`.
`nu_mod_pos` is Euclidean modulo (sign of the divisor), `nu_int_div` floor
division, `nu_pi` prints `3.14159` because `show` uses `%g`.

Two gen2 limitations shaped the library and are recorded under "Measured
divergences" rather than hidden:

* gen2 index expressions had to be a literal or a plain name when this module
  was written, so `la_sorted` carried the previous element in a variable
  instead of writing `xs[i - 1]`. Superseded later the same day by the
  index-expression increment below: `la_sorted` now reads `xs[i] < xs[i - 1]`
  and is the live stdlib exercise for it. The second limitation still stands.
* a bare `give "a" + b` inside a function body does not compile on gen2, so
  every string helper accumulates into a `hold` and returns that.

Honest boundary: this is growth of a small portable library. There is no JSON,
no HTTP client, no date/time, no unicode (strings are C `char *`, one byte per
"character", so a multi-byte UTF-8 sequence is split), and no transcendental
math beyond `nu_pi` and the degree/radian conversions. `docs/STDLIB.md` lists
every helper and the rules a new one must follow.

Gates after BOTH areas (one run, `make doctor true-selfhost gen3 native-test`,
exit 0): `DOCTOR-OK: core tool set is complete`,
`=== TRUE-SELFHOST-MIN-OK ===`, `[OK] byte-identical gen3 == gen4` /
`=== GEN3-OK ===`, `=== NATIVE-TEST-OK ===`. Focused logs:
`docs/logs/seed-for-untyped.log`, `docs/logs/seed-for-fields.log`,
`docs/logs/stdlib-modules.log`.

Current compiler SHA-256 (`selfhost/compiler_min.sa`, after the two gen2 fixes
in this increment):
47503b07d5458c9d01d3e8b7224b39be54a8caf27d0023f3ec9e8fc4d42d59ee
The checked-in offline bundle in `selfhost/compiler_min_gz/` still encodes the
PREVIOUS source (109 parts, sha256 7ca320d5...); it is regenerated with
`make pack-compiler` and the part count recorded here when the compiler source
settles. `restore-compiler`'s fast path uses the checked-in plain source, so the
bootstrap does not depend on the bundle being current.

### Index expressions in the self-hosted compiler, and an honest full-language claim (2026-10-13)

Two things moved: a real language feature was added to the Sayanox-written
compiler source, and the documents that described a full-language path that
does not exist were corrected.

**1. An index is a numeric expression.** `selfhost/compiler_min.sa` gains one
helper, `raw_index(source, from, n) -> str`, in the leading block of `make`
definitions, and four call sites use it: the two copies of the value-position
parser and the two copies of the postfix-operand parser (the operand parser is
why `xs[i] + xs[i - 1]` failed while `xs[i - 1]` alone worked). The condition
rewriter and the `for`-bound rewriter each gained their own lowering, because
they copy text rather than call the expression parser. A declared list becomes
`sx_lget(NAME, IDX)` and a declared string becomes `sx_idx(NAME, IDX)`; both
runtime helpers already took a `double` and truncated it, so no runtime change
was needed. Before this increment gen2 refused every index that was not a
literal or a plain name, and copied an index inside a condition or a bound
verbatim, which produced C that subscripted an `sx_list` struct with a double
(`array subscript is not an integer`).

`make test-gen2-index-expr` pins it: 39 hand-computed values from
`selfhost/gen2_index_expr_test.sa` must be byte-identical on seed-min, gen2 and
native, covering literal/name/parenthesised/field indexes, string indexes,
indexes in conditions, indexes in `for` bounds, indexes on both sides of a
binary operator, and indexes inside typed function bodies; five `grep`
assertions check the emitted C actually contains the lowered calls; and 13
malformed index programs must produce a `min:` diagnostic and a `#error` in the
generated C rather than invalid C. Refused on purpose, each with the workaround
named in the message: `%`, any call including `len()`, a nested index, a comma,
a quoted string, an empty index, unbalanced parentheses and a trailing
operator. `xs[]` used to reach C as `sx_lget(xs,)`; it is now a clear refusal.

**2. The full-language self-host documents were false, and are now honest.**
`docs/FULL_LANGUAGE_SELFHOST.md` told the reader to run
`./selfhost/bootstrap_full_language_selfhost.sh` and expect
`FULL-LANGUAGE SELF-HOST OK`; `docs/FULL_SELFHOST.md` told them to run
`./selfhost/restore_stage2.sh` and `make stage2`. Measured on 2026-10-13: no
such scripts exist, there is no `stage2:` target in the Makefile,
`selfhost/stage2_template.c` is a 93-byte placeholder comment,
`selfhost/stage2_src/` is a README plus an 11-byte placeholder,
`selfhost/sxc_full.c` is a 30-line toy that lowers only `hold NAME = <digits>`
and `show`, and `bash selfhost/restore_stage2.sh` exits 1 with
`error: missing Stage-2 seed`. So there is **no Stage-2 C host that lowers the
full grammar**, and no claim of one survives:

* `docs/FULL_LANGUAGE_SELFHOST.md` was rewritten around what is actually gated
  (the C seed, the Sayanox compiler source, gen1_min -> gen2 -> gen3 -> gen4
  with `gen3 == gen4` byte-identical, and `native_aot`), with a per-feature list
  that names the gate for each line, the refusals, and the measured absence of
  the Stage-2 host.
* `docs/FULL_SELFHOST.md` keeps its history but its two command blocks were
  replaced with the commands that exist.
* 3 remaining legacy documents (`docs/FULL_SELFHOST.md`,
  `docs/TOOLCHAIN.md`, `docs/VNEXT_STATUS.md`) carry a banner stating exactly
  which entry points do not exist and what the supported path is. On 2026-10-21
  the other 21 — the `docs/STAGE5..STAGE28` sequence, `docs/ABC_COMPLETE.md`,
  `docs/UNIFIED.md`, `docs/GIVE.md`, `docs/ERRORS.md`, `docs/SXC_*`,
  `docs/SELFHOST_*`, `docs/PURE_SA.md`, `docs/SHELL.md`, `docs/SAYANOXC.md`,
  `docs/RUST_OPTIONAL.md` and the five `selfhost/*.md` pages — were **deleted**.
  They described architectures that no longer exist, and a banner is a weaker
  claim than not shipping the page at all.
* `make test-doc-claims` (wired into `test-stage2`, `test-for-str` and the
  `true-selfhost-min` aggregate) fails if a document advertises a missing entry
  point without the banner, if any deleted Stage-2 placeholder comes back
  (`stage2_template.c`, `sxc_full.c`, `sxc_full_minimal.c`, `restore_stage2.sh`,
  `restore_sxc.sh`, `restore_sxc_full.sh`, `restore_stage2_template.sh`,
  `selfhost/sx`, `stage2_src/`, `stage2`), or if a `stage2:` target appears — in
  which case the docs are the thing that must be updated.

Two constraints on editing the compiler source were found the hard way and are
recorded in `docs/FULL_LANGUAGE_SELFHOST.md`: a `make` definition placed after
top-level statements is not parsed as a definition (gen1_min emitted
`raw_index(double source, double str, double from, double num, double n,
double num)` and gen2.c did not compile until the helper moved into the leading
block), and a scan name shared by two blocks must be declared at the top of the
file, because a first `hold` inside a block becomes a C local of that block
only.

Not claimed: gen2 is not a full-language compiler. A bare string `+` chain in a
`give` still does not compile, `%` and calls inside an index are refused, a
global read inside an untyped `make` is refused, native still rejects a unary
sign in an index and does not wrap a negative one, and generic structs with
concrete layouts and type identities remain unimplemented. The increment is one
feature plus one honesty correction, both gated. (Later the same day the bare
string `+` chain in a `give` and `len()`/a nested index inside `[ ]` were fixed
too, and `%` plus a call other than `len()` inside an index remain refused —
see "Gen2 expression lowering" below.)


---

## Seed memory management measured, and the full seed can compile an operator again (2026-10-13)

> Superseded on 2026-10-22 for seed-min: it now has a conservative mark & sweep
> and real `gc()`/`gc_live()`/`gc_runs()`. The measurements below are kept as
> the record of what the no-GC seed did; see
> [GC.md](GC.md#a-collector-in-the-bootstrap-seed-2026-10-22).

Item 3 of the roadmap asked for a real collector subset in the seed **or** a
documented no-GC seed plus a stress test. Measuring first produced the second
answer for one seed, a correction for the other, and a bug fix that was hiding
behind both.

**The full seed could not compile a comparison.** `sxc_seed`'s lexer pushed
single-character operator tokens with the macro

```c
#define P1(ch,k) if(c==ch){ i++; col++; ptok(k,(const char*)#ch,0,sl,sc); continue; }
```

`#ch` stringizes the *argument as written*, quotes included, so `P1('*',T_STAR)`
recorded the three-character text `'*'`. `emit_expr` compares that against
`"*"`, matched nothing, and fell through to the tail of its `E_BIN` case: it
printed the two operands and a closing paren with no operator and no opening
call. `show 2 * 3` became `sx_show(((double)2LL),((double)3LL)))` and
`while i < 3` became `while(sx_truthy(x0,((double)3LL))))` — every program with
arithmetic, a comparison or a loop condition failed to compile. The fix builds
the one-character text from the value (`char ob[2]={(char)(ch),0}`), the idiom
the "unexpected character" diagnostic in the same loop already used;
two-character operators were pushed with explicit strings and were always
correct. `selfhost/seed_gc_ops.sa` now prints `6 5 4 2.5 2 9 0 1 2` on the full
seed, seed-min and gen2 alike.

A 2026-10-04 audit note in the Makefile had declared this area fine ("P1 is only
instantiated with single-char punctuation literals, so `#ch` already stringizes
correctly"). That note was wrong, and because the `fix-seed` awk guard it
described never matched, nothing ever tested it. The note is corrected in place
and `make verify-seed` now fails on a checkout that still has the old macro.

**Seed memory, measured.** `make test-seed-gc` runs five fixtures
(`selfhost/seed_gc_{churn,grow,retain,ops,tmp}.sa`) through seed-min, gen2 and
the full seed under `ulimit -v` caps — 4 MiB is the floor for a dynamically
linked binary, below it `libc.so.6` cannot be mapped:

| fixture | seed-min, 4 MiB cap | gen2, 16 / 64 MiB cap | full seed, 64 MiB cap |
| --- | --- | --- | --- |
| 200k concat churn, nothing retained | `200000` | segfault → now `sx: out of memory` / `200000` | `200000` |
| 2000 concats into one 2003-char string | `2003 97 120` | `2003 97 120` (8 MiB cap is enough) | `2003 97 120` |
| 20 doublings, 8388608 bytes live | exits 1, `sx: out of memory`, stdout `before` kept | exits 1 / `before 8.38861e+06 after` | `before 8388608 after` |
| 2000 temp concats, `SX_GC_DEBUG=1` | no counter exists | collector: `gc_runs()` ≥ 1, `gc_live()` small | **6000 objects still alive at exit** |

So: **seed-min is documented no-GC**, and the two mechanisms that keep it flat
are now written down and pinned — `concat`/`chr` results carry a hidden `sx_sb`
`{magic,len,cap,data[]}` header so repeated concatenation onto the same
left-hand side grows in place, and a string assignment is emitted as
`{ char *_v = sx_cat(a,b); sx_sb_free(a); a = _v; }`, which frees the old
left-hand side after evaluating the right-hand side. Everything else leaks, and
`gc()`/`gc_live()`/`gc_runs()` are refused at compile time rather than silently
returning 0. **The full seed's reference counts do not release in loops**:
three objects per iteration stay registered, memory grows with total allocation
rather than with the live set, `gc()` is a documented no-op returning `0`, and
`gc_live()`/`gc_runs()` do not exist there. That is recorded as the honest state
in [`GC.md`](GC.md) §2 rather than fixed.

**gen2 no longer segfaults under memory pressure.** Its emitted runtime ignored
the results of its own `calloc` (the block hash table, two calls) and `malloc`
(the sweep's sort array and each new block), so a capped run dereferenced NULL
and died with SIGSEGV — exit 139 and no diagnostic. All three sites now print
`sx: out of memory` to stderr and exit 1; the target asserts the three checks
are present in the generated C. Measured alongside it: gen2's first collection
only fires at 8 MiB of managed heap (`sx_gc_thresh` starts at `8u << 20`, then
`live * 1.5 + 4 MiB`), which is why a churn that native runs inside 4 MiB needs
64 MiB here. That threshold is a constant in the emitted runtime and is not
tuned by this increment.

Two smaller seed corrections ride along: `selfhost/seed/sx_runtime.h` now
includes `<stdarg.h>` itself (the seed emits a variadic `sx_lit_list` into every
file, and with GCC 14's defaults a missing prototype is a hard error — the
`-include stdarg.h` workaround is gone from `tools/test-http-get.sh`), and its
pointer to the nonexistent `docs/MEMORY.md` now names `docs/GC.md`.
`make verify-seed` asserts both.

Not claimed: neither seed has a collector; the full seed's release path is
measured broken and left documented; the full seed still needs ≥ 64 MiB of
address space for its static 2097152-entry object table, still needs `-lm` after
the sources when a program uses `%`, and still prints `8388608` where the other
three backends print `8.38861e+06` — all three are pinned by the test, not
fixed. The bootstrap path is unchanged in behaviour: seed-min emits the same C
as before, and gen2's generated code differs only by the three allocation
checks.

---

## Generic-struct refusals, opt-in packages, a multi-document LSP, and the native emit seam (2026-10-13)

Four roadmap items in one increment: the type-system item (7), online packages
(5), the LSP product path (6) and the native platform item (2). None of them
changes the bootstrap dialect, and all four are gated.

### 7. Generic structs: the refusal is now the feature

(Superseded later the same day: generic structs are **implemented** on all
three backends — see the last increment in this file. What follows is the
diagnostic step that came first, kept as the record of it.)

Generic structs were still **not implemented** at this point — no type identity,
no per-instantiation layout, no specialization worklist
([`TYPES_ROADMAP.md`](TYPES_ROADMAP.md) listed the five prerequisites). What
changed here is that the three backends said so, instead of reporting a symptom
of their own parser:

| Backend | Before | Now |
|---|---|---|
| seed-min | `seed_min: { at 10` — a brace, at a *character offset* | `generic structs are not implemented: a struct declaration cannot take a type parameter list, so declare a concrete struct name (docs/TYPES_ROADMAP.md)`, exit 1, from all four scan paths that see a struct declaration |
| gen2 | `min: undefined name: Box` for `Box<num> { 1 }`, and `min: struct literal must fill every field` for `Box { 1 }` — wrong about the program the user wrote, because `<T>` was swallowed into the field list | the same sentence on stdout **and** `#error sayanox-min: generic structs are not implemented: …` in the generated C |
| native | `native_aot: struct Box needs { fields }` | `native_aot: generic structs are not implemented: struct 'Box' cannot take a type parameter list, …`, exit 1 |

`make test-generic-structs` pins those three diagnostics, pins the supported
workaround (`selfhost/generic_struct_concrete.sa`: `NumBox`, `TextBox` and
`PairBox` in one program — `7 seven 8 eight 2 8 9`, byte-identical on all three
backends), and pins one divergence found while writing it: a **dotted field read
inside a struct literal** (`hold a2 = NumBox { a.v }`) is accepted by seed-min
and refused by gen2 (`#error … literal value must be a number, string, name, or
nested struct`) and native (`field 'NumBox.v' is used with two different
types`). Refused, not miscompiled — and the portable spelling (`hold v = a.v`,
then `NumBox { v }`) is in the fixture's comment.

### 5. Online packages are opt-in, and both online targets are gated

`SAYANOX_REGISTRY` used to be both the *where* and the *permission*: with the
default registry URL, `sxpkg sync`, `sxpkg install` and `sxpkg fetch` simply
reached for the network. They now refuse first:

```sh
sxpkg: refusing to use the network without an explicit opt-in
sxpkg:   target: https://registry.invalid/r
sxpkg: opt in with SAYANOX_ONLINE=1, or 'sxpkg --online <command>'.
sxpkg: offline instead: install-local, seed, verify, list, deps, info,
sxpkg:   or point SAYANOX_REGISTRY at a local directory (file://...).
```

Permission is `SAYANOX_ONLINE=1` or `sxpkg --online <command>`. A `file://` URL
or a plain local path is not the network and never asks, and `install` decides
per package: a locked package whose `pkg.meta` **and** `main.sa` are already
local is copied and verified offline even when the registry URL is remote — only
a genuinely missing package asks. `download()` is now bounded
(`curl --connect-timeout 10 --max-time 60`, `wget --timeout=10 --tries=1`), so a
host that accepts and then goes quiet cannot hang a build. `publish` still never
uploads, with or without an opt-in: going online is a commit to
`registry/<name>`, which is a review step, not a client command.

`make test-sxpkg-online-optin` asserts all of it, and `make
test-sxpkg-online-local` (which existed but was on no gate) is now in both
aggregates. Neither target opens a socket: the online path is exercised against
a `file://` registry, and the opt-in path against `.invalid` host names (RFC
2606), which fail in the resolver. Both skip cleanly if neither `curl` nor
`wget` exists. Still not claimed: signatures, a cryptographic hash, version
ranges, upload.

### 6. The LSP keeps four documents, and answers each from its own buffer

The server kept ONE document. A second `didOpen` overwrote it, so with two
Sayanox files open every request for the first was answered from the second's
buffer — a wrong answer, not a missing one. `didChange` was guarded against a
foreign URI; `didOpen`, `hover`, `definition`, `documentSymbol` and
`textDocument/diagnostic` were not.

It now keeps a four-slot table. The dialect has no array of strings, so the
table is four parallel pairs of globals (`uri0`/`txt0` … `uri3`/`txt3`) and
exactly three places touch it: a load cascade under the framing loop, `didOpen`
(store) and `didClose` (clear). Every message reloads `doc`/`docuri` from its own
`params.textDocument.uri` before the handlers run, so the readers are unchanged
and each answers from the buffer the client asked about. A request for a URI
that is not open gets an empty document and therefore an empty answer
(`documentSymbol` → `[]`, `diagnostic` → no items), never another file's
contents; `didChange` for an unopened URI publishes nothing; a **fifth**
`didOpen` evicts the slot that has been open longest, and the evicted document
stops being served until it is opened again. That cap is a documented limit, not
a claim about editor sessions.

`tools/sayanox-lsp-probe.sh` now drives three sessions and `make test-lsp`
asserts eighteen lines instead of thirteen: two documents open at once with the
first still served after the second was opened, a closed document answering
`"result":[]` and not being served from another buffer, and the five-document
eviction (`f1` gone, `f5` served). Still not implemented: `workspace/symbol`,
references, rename, formatting, and any cross-file analysis.

### 2. Native: an emit seam, not a second target

`native_aot.c` is a single-pass compiler — it parses and emits in the same walk
— so a second target cannot mean swapping a file, and none is claimed. What now
exists is a seam: the machine-specific half of the file is delimited, and the
language half provably does not touch it.

* Everything that writes bytes lives in the `x86-64 mini encoder` region above
  `phase 1`, and the API gained five named primitives for the sequences the emit
  tree used to write itself: `here()` (a label position), `patch_imm32()`,
  `leave_ret()`, `sub_rsp_imm32_slot()` and `jmp5_slot()`.
* The language-level emitter is bracketed by `EMIT-SEAM-BEGIN` /
  `EMIT-SEAM-END`: 1302 lines, no `e1(`/`e32(`/`e64(`, no `memcpy` into `code`,
  and no direct read of the cursor `cn` (28 of them became `here()`). A
  hand-rolled rel32 patch that duplicated `erel32j` is gone.
* Below the end marker the file is x86-64 again by nature — the phase-4 runtime
  stubs, the collector and the ELF container — and [`NATIVE.md`](NATIVE.md)
  records the two contracts a replacement backend inherits: the System V AMD64
  calling convention the emit tree assumes, and the collector's block layout.
* The refactor was verified **byte for byte**: six fixtures emit executables
  that `cmp` clean against the binaries produced by the pre-seam `native_aot`.
  `make test-native-emit-split` keeps the region clean and runs one program end
  to end.

Two honesty corrections ride along. `docs/NATIVE.md` described the native IR
boundary through `parse_prim`, `parse_term`, `parse_expr`, `estmt` and `eblk` —
five functions that do not exist in the file; the emit tree is `emit_prim` →
`emit_post` → `emit_term` → `emit_rel` → `emit_expr` under `emit_prog`/`emit_fn`.
And the build's last warning is gone: `emit_prim` (void) had a `return <value>`,
while the identical line in `pk_prim` (int) is correct and was left alone.

### Gates

`make doctor && make true-selfhost && make gen3 && make native-test` passed
after each of the four items and once more, chained exactly like that, at the
end. The four logs of the final run are
[`docs/logs/four-items-doctor.log`](logs/four-items-doctor.log) (`DOCTOR-OK`),
[`docs/logs/four-items-true-selfhost.log`](logs/four-items-true-selfhost.log)
(`TRUE-SELFHOST-MIN-OK`, 886 lines),
[`docs/logs/four-items-gen3.log`](logs/four-items-gen3.log) (`GEN3-OK`,
including `[OK] byte-identical gen3 == gen4`, which is the check that the
compiler's own source edits did not move its fixed point) and
[`docs/logs/four-items-native-test.log`](logs/four-items-native-test.log)
(`NATIVE-TEST-OK`, 103 `[OK]` lines). The earlier seed-memory run of the same
chain is `gates_item3` in the same directory. The three new targets (`test-generic-structs`,
`test-sxpkg-online-optin`, `test-native-emit-split`) plus the two newly gated
ones (`test-seed-gc`, `test-sxpkg-online-local`) are wired into the
`true-selfhost-min` and `native-test` aggregates as appropriate — the native one
only where `native_aot` is built.

Not claimed: generic structs, a second native target, a workspace-aware LSP,
signed or uploaded packages, or any change to the pure-min bootstrap dialect.
(The LSP row is now narrower: references, workspace symbols and formatting
landed later the same day — see below. A workspace *scan* is still not claimed,
because the dialect has no directory-listing builtin. Generic structs also
landed later the same day, and the native emit tree got an instruction-list
recorder — both below.)


---

## Gen2 expression lowering: a string chain in a `give`, and `len()` or a nested index inside `[ ]` (2026-10-13)

The two gen2 gaps that were still recorded as open divergences are closed in the
self-hosted compiler source (`selfhost/compiler_min.sa`), and both are gated by
one new target, `make test-gen2-expr-lowering`, wired into the
`true-selfhost-min` and `native-test` aggregates. Nothing changed in the
pure-min bootstrap dialect, in seed-min, in the full seed or in `native_aot`:
this increment only removes two places where gen2 was the odd backend out.

### The `give` that could not join two strings

`give "hi " + name` inside a function body was copied into the C as
`return "hi " + name;`, which cc rejects with `invalid operands to binary +
(have 'char *' and 'char *')`. The same chain in a `hold` always worked,
because the value-position parser joins two strings through `sx_cat`. The
expression rewriter that feeds a `give`, a `when`/`while` condition and a
parenthesized expression now does the same:

* it already scanned back over the left operand and forward over the right one
  to lower `%` through `sx_mod`; that handler now covers `+` as well, and the
  back-scan also walks over a quoted literal (counting the backslashes before a
  quote, so an escaped `\"` does not end the walk early);
* `str_operand(text, sdecls)` decides whether an operand is a string: a quoted
  literal, an `sx_cat(...)` group, a name in the string declaration table
  (`sdecls`, which holds `str` parameters and `for` variables too), or a call
  to a builtin that gives a string (`concat`, `chr`, `numstr`, `arg`,
  `read_line`, `read_n`, `read_file`, `http_get` and their `sx_` names). Spaces
  left by the scans are trimmed before the table lookup;
* both strings → `sx_cat(L, R)`, nested for a chain, so `"x" + n + "y"` becomes
  `sx_cat(sx_cat("x" , n) , "y")` and `concat(p, q) + "/" + p` becomes
  `sx_cat(sx_cat(sx_cat(p, q) , "/") , p)`;
* exactly one string → refused with the value parser's own sentence, `+ joins
  two strings or adds two numbers; the other side of 'v' is not a string (bind
  it with hold first)`, as a `min:` diagnostic on stdout and a `#error` in the
  C. seed-min refuses the same program, so the backends agree on the diagnosis;
* `%` with a string operand is refused too (`'%' truncates two numbers; one of
  its operands is a string`), which seed-min and native already did.

A struct string field (`give "n=" + p.name`) and a call to a user function that
gives a string are *not* classified as strings by `str_operand`, so those two
forms are refused rather than mis-compiled; binding the value with `hold` first
works everywhere, as before.

`selfhost/gen2_str_cat_test.sa` is 11 hand-computed values — literal + name,
name + literal, a three-part chain, an escaped quote inside a literal, a call
operand, a chain in a `hold` inside a typed body, and a string comparison in a
condition — byte-identical on seed-min, gen2 and native, with the emitted
`sx_cat` forms pinned by `grep`.

### `len()` and a nested index inside `[ ]`

`xs[len(xs) - 1]` was refused in a value position (`unsupported index
expression`) and copied verbatim into the C in a condition and in a `for`
bound, where cc reported `array subscript is not an integer`. Two helpers in
the leading definition block fix every position at once:

* `tbl_has(table, name)` answers whether a `|name|name|` declaration table
  holds a name — the tables belong to the main loop and a helper cannot
  capture them, so they are passed in;
* `idx_lower(text, ldecls, sdecls)` lowers index text into C: `len(NAME)` to
  `sx_llen`/`sx_len` and `NAME[IDX]` to `sx_lget`/`sx_idx`, each chosen by the
  declaration tables, recursing into a nested index, and copying numbers,
  names, dotted field chains, parentheses and `+ - * /` verbatim (which is
  already valid C). It gives `""` when it cannot lower — `%`, a call other than
  `len()`, a quoted string, a comma, a stray bracket, a name declared neither
  list nor string — and every caller keeps its existing refusal then.

`raw_index` now copies a call and a nested `[...]` verbatim instead of refusing
them, tracking bracket depth so the closing `]` of the outer index still ends
the scan. Copying verbatim matters: a caller advances its own cursor by `len()`
of the result, so the text and the position have to stay in step, and the
lowering happens where the C is emitted. `idx_lower` is wired at the four
value-position call sites (the two value parsers and the two postfix-operand
parsers), in the condition rewriter's index path and in the `for`-bound
rewriter, so all of these now work in gen2:

```
xs[len(xs) - 1]        xs[len(xs) - len(ys)]   xs[ys[0]]      xs[ys[1] + 1]
s[len(s) - 2]          when xs[len(xs) - 1] > 39              for k in 0..ys[len(ys) - 1]
make pick(v: list) -> num { give v[len(v) - 1] }              show xs[i + 1] + xs[len(xs) - 1]
```

`selfhost/gen2_index_call_test.sa` is 18 hand-computed values covering exactly
those forms, byte-identical on seed-min, gen2 and native, with the emitted
`sx_llen`/`sx_len`/`sx_lget`/`sx_idx` forms pinned by `grep` in a value, a
condition, a `for` bound and a typed body.

Still refused inside `[ ]`, each with a `min:` diagnostic and a `#error` rather
than invalid C: `%`, a call other than `len()` (so `xs[pick(xs)]`, which
seed-min and native do accept — that row stays open as a narrower divergence),
a quoted string, a comma, an empty index, unbalanced parentheses or brackets,
and an expression that ends with an operator. `make test-gen2-index-expr` keeps
its 39 values and now pins 9 refused forms instead of 13; its five
`len()`/nested-index refusals moved to the new target as positive parity
checks.

### Two lessons this increment re-learned the hard way

* A `hold` name may be declared only **once per generated C function**, and the
  whole main compile loop of `compiler_min.sa` is one function. Reusing a scan
  name that another block already declares (`cwq`, `cwb2`) or naming the same
  helper result at two sibling call sites (`ixl`, `opxl`) makes gen1_min emit a
  bare assignment with no declaration, and gen2.c then fails to compile with
  `'NAME' undeclared`. Every new name in this increment is unique to its site.
* The back-scan for an operand has to know which end of a literal it starts
  from: the first version stopped at the *closing* quote, so `"[" + j` emitted
  `"[sx_cat(" , j)`. The fixture that caught it is a three-part chain, which is
  why `gen2_str_cat_test.sa` has one.

### Gates

`make test-gen2-expr-lowering` and the updated `make test-gen2-index-expr` both
pass, including native parity for both fixtures and all 6 + 9 pinned refusals.
The full chain `make doctor && make true-selfhost && make gen3 &&
make native-test` was re-run after the source edits and the offline pack was
regenerated (`make pack-compiler`, 119 parts, round-trip verified against
`selfhost/compiler_min.sa`). Re-running that chain for a later increment found
one stale pin this pass had left behind: `test-list2` still asserted a `#error`
for `show xs[len(xs) - 1]`, which is exactly the refusal this increment removed.
That leg now compiles the fixture, greps the emitted C for
`sx_lget(xs,sx_llen(xs) - 1.0)` and asserts the value `6`; the index forms that
are genuinely still refused stay pinned by `test-gen2-index-expr` and
`test-gen2-expr-lowering`, so no guard was lost by the move. The four logs of the
branch-final run of that same
chain — taken after the LSP and native instruction-list increments below, so
they cover this increment too — are `docs/logs/ir-log-doctor.log`,
`docs/logs/ir-log-true-selfhost.log`, `docs/logs/ir-log-gen3.log` and
`docs/logs/ir-log-native-test.log`.

Not claimed: a call other than `len()` inside an index, `%` inside an index, a
struct string field or a user-function call as a `+` operand in a `give`,
generic structs, a second native target, or any change to seed-min, the full
seed, `native_aot` or the pure-min bootstrap dialect. (Generic structs landed in
the next increment, and with them changes to seed-min, gen2 and `native_aot` —
see below.)


---

## The LSP answers references, workspace symbols and formatting (2026-10-13)

`tools/sayanox_lsp.sa` gained three methods — `textDocument/references`,
`workspace/symbol` and `textDocument/formatting` — all answered from the buffers
the server already keeps, so the four-slot document table, the framing loop and
every existing answer are untouched. `make test-lsp` now asserts 29 facts over
five sessions instead of 18 over three, and the two extra sessions are the new
methods. [`docs/LSP.md`](LSP.md) documents each one.

* **references** — `refs_for(w, text, uri, incl, first)` collects whole-word
  occurrences of the word under the cursor (an identifier run compared with
  `string_eq`, so `zz` does not match inside `fuzzy`) and returns `Location[]`.
  Columns go through the existing `utf16_span` helper twice — the word's byte
  offset and the offset just past its last byte — so a range covers the whole
  word and stays right on a line with accented Latin, Bengali or emoji before
  it. `context.includeDeclaration: false` skips the line whose first non-blank
  text is `make w`, `hold w` or `struct w`; both spellings of the flag (with and
  without the space after the colon) are recognised. A position that is not on a
  word answers `[]`.
* **workspace/symbol** — `symbols(text, uri)` became
  `sym_scan(text, uri, query, first)` and `symbols` delegates to it with an
  empty query, so `documentSymbol` answers byte-for-byte what it always did
  (the probe still pins `"name":"twice"` and `"name":"x"`). A non-empty `query`
  filters by case-insensitive substring through a new ASCII `lower` helper.
* **formatting** — `format_text(text)` is a rule-for-rule port of
  `tools/sxfmt.sa`: indentation rebuilt from brace depth at two spaces per
  level, leading and trailing whitespace stripped, blank lines kept blank, a
  final newline added, braces counted only outside a quoted string (with `\`
  escapes) and outside a `//` comment, a line starting with closing braces
  indented at the depth those braces return to, and tokens and comments never
  rewritten. `format_edit(text)` answers `[]` when the text comes back
  unchanged, so a client leaves a formatted buffer alone, and otherwise one
  whole-buffer `TextEdit` whose end is one past the last newline (or the UTF-16
  width of the last line when there is none), with `newText` through the
  existing `json_esc`. The probe feeds it the same badly indented source that
  `make test-sxfmt` feeds the formatter *program* and asserts the indentation,
  the stripped trailing whitespace and the range — which is what makes "the LSP
  formats like `sxfmt`" a checked claim rather than a comment.

Because a function cannot capture globals in this dialect, the four-slot table
stays unreadable from a helper; both spanning methods therefore cascade in the
dispatch site, one call per slot, and the comma rule lives inside the helper
(`first` is the number of items the caller already has, and `len(res)` is
exactly that at each step). Capabilities advertise `referencesProvider`,
`documentFormattingProvider` and `workspaceSymbolProvider`; the robustness and
Unicode probes still pass unchanged (11 and 7 lines).

Not claimed: a workspace *scan*. `workspace/symbol` and `references` only see
documents a client opened, because the dialect has no directory-listing builtin
and the server does not spawn a process; a file nobody opened cannot be
searched. Also not claimed: rename, code actions, signature help, incremental
sync, or a formatter that rewrites tokens.

## Native: the emit tree's instruction list is recorded, named and pinned (2026-10-13)

The fourth item of this pass was "native towards a second target". What landed is
the half of that which a single-pass compiler can land honestly: the instruction
list the emit tree produces is now a file, with names a human can read and a
target that pins it. No second emitter exists and none is claimed.

### Why not an ARM64 or riscv64 skeleton

`native_aot.c` parses and emits in the same walk, so "a second target" cannot be
a new file beside the first. The emit tree itself picks the registers, spills
through `push`/`pop`, and assumes System V AMD64 returns in `rax`/`xmm0`; a
skeleton emitter for another ISA would either duplicate those 1332 lines — which
is a second compiler, not a second target — or hang off an interface that does
not exist yet. The step that does not fake anything is to make the existing
contract observable first: exactly what the emit tree asks the encoder for,
instruction by instruction, so that a second backend is written against a list
instead of against prose.

### What landed

* **`SX_EMIT_LOG=<path>`.** Every encoder primitive writes one line: the code
  offset the instruction starts at, the mnemonic, and the operands in assembly
  order — `mov [r12+672],rax`, `addsd xmm0,xmm1`, `ucomisd xmm0,xmm1`,
  `sub rsp,<imm32 slot>`, `call make twice`, `call builtin concat`. That covers
  the integer helpers (`mv_rr`, `mv_m64`, `mv_r64m`, `lea_rm`, `mov_imm64`,
  `mov_imm8m`, `mvz_rm`, `bin_rr`, `bin_imm8`, `bin_imm32`, `fm7`, `test_rr`,
  `xor_rr`, `incdec_r`, `inc_mem_r`, `push_r`, `pop_r`, `jcc_rel32`,
  `jmp_rel32`, `setcc`, `movzx_al_to_rax`, `sar_imm`, `shl_imm`, `shr_imm`), the
  ten SSE wrappers, and the seam API (`leave_ret`, `sub_rsp_imm32_slot`,
  `jmp5_slot`, `lea_r12_data`, `call_p`).
* **`;` lines for the three things a replacement backend also has to provide:**
  a label slot and the offset of its placeholder, a fixup that resolves it
  (`fixup rel32 [000177] -> 0001ee (113)`, next to the `jae rel32(0)` that was
  emitted at `000177` with the target still unknown, and the `jmp rel32(-167)`
  back edge whose displacement was known immediately), and orientation — one
  marker per emitted `make` (`--- make twice[0] at 0002a4 ---`) and one per
  phase (entry, top level, exit syscall, make bodies, runtime stubs, collector).
* **Names instead of ids.** `call builtin 28` tells a backend author nothing, so
  the list prints `call builtin gccheck`. The tables sit beside the ids they
  name: `bname_tbl` next to the `B_*` enum with every entry designated by id, so
  inserting a builtin cannot silently reorder the names; `fname` reads `F[]`, so
  a `make` is called by its source name including generic instances. A
  `_Static_assert` keeps the table inside its bound, and an unnamed id would
  print as `id28` — which `make test-native-ir-log` forbids, so a missing name
  fails a gate instead of degrading the log.
* **A fixture**, `selfhost/native_ir_log_test.sa`: two `make`s (one numeric, one
  joining two strings through `+`), a `hold` chain, `len()`, a list built in a
  `for`, an index read inside a `when`, and hand-computed output
  (`42`, `ir-log`, `6`, `3`, `42`, `ir-log-done`).

The recorder reads arguments and nothing else — no `code`, no `cn` — so the
bytes cannot change, and that was measured rather than assumed: the emitted ELF
is `cmp`-identical with and without `SX_EMIT_LOG`, and identical to the output of
the pre-recorder compiler on `native_ir_log_test`, `native_lang_test`,
`native_for_functions_test`, `generic_struct_concrete`, `native_strord_test` and
`stdlib_growth_test`. Two logged runs of the same source `cmp` clean, so the list
is a function of the source.

The emit seam grew from 1302 to 1332 lines for this: the two name tables live
inside the seam because the `B_*` enum they name does, and `emit_fn` announces
itself with one `ilogc` line. The recorder *state* stays in the encoder region,
and `make test-native-ir-log` asserts the seam never touches it — the language
emitter may announce a phase, but only the encoder records instructions.

### Gates

`make test-native-ir-log` is new, is part of `native-test`, and prints six `[OK]`
lines: no emitted byte changes, the list is deterministic (1182 lines), 1122
instructions with 2 label slots and 41 rel32 fixups on monotonic offsets and six
phases in order, every call target and operand named, the machine model visible
(26 pinned strings, from `movq xmm0,rcx` and `call builtin llen` to `leave` and `ret`), the top level's
mnemonics exactly
`add addsd call cvtsi2sd cvttsd2si jae je jmp lea mov movq movzx mulsd pop push seta ucomisd`,
and the recorder confined to the encoder. `make test-native-emit-split` still
passes unchanged. The fixture's instruction list, the format and what a second
backend has to reproduce are documented in
[`docs/NATIVE_IR.md`](NATIVE_IR.md), with a pointer from the emit-seam section of
[`docs/NATIVE.md`](NATIVE.md).

The whole chain was re-run for this increment and is green: `DOCTOR-OK`;
`TRUE-SELFHOST-MIN-OK` (902 lines, 156 `[OK]`); `GEN3-OK` with gen3 == gen4
byte-identical; `NATIVE-TEST-OK` (791 lines, 142 `[OK]`), containing both the
six lines above and `[OK] emit seam: 1332 lines of language-level emitter`. The
logs are `docs/logs/ir-log-doctor.log`, `docs/logs/ir-log-true-selfhost.log`,
`docs/logs/ir-log-gen3.log` and `docs/logs/ir-log-native-test.log`.

Not claimed: a second target, a portable IR, a register allocator, an
ARM64/riscv64 emitter, or any change to the emitted bytes. The list is still
x86-64-shaped — the emit tree chooses the registers and the calling convention —
and `SX_EMIT_LOG` is a window onto that, not a way out of it.


---

## Increment (2026-10-13, latest): generic structs — a template, and one concrete type per instantiation

`struct Box<T> { v }` is now a **template**: parameter names and field names and
no layout, and it never becomes a struct of its own. Each *instantiation*
becomes an ordinary concrete struct under a mangled name — `Box<num>` is
`Box__n`, `Box<str>` is `Box__s`, `Pair<num, str>` is `Pair__ns` — the suffixes
generic functions already use, so the mangled name *is* the type identity. Two
specializations get their own field kinds, their own C typedef and, on native,
their own pointer-kind map for the collector, and they can never share a field
slot.

That closes the first two of the five prerequisites
[`TYPES_ROADMAP.md`](TYPES_ROADMAP.md) has carried since 2026-10-12, and closes
3 and 5 for the supported forms: typedefs and native field/GC descriptors are
emitted per instantiation in first-use order, and instantiation happens on
demand at a literal site, idempotently, with no worklist and no cycle check
needed because nesting is refused. Prerequisite 4 is partly closed — the type
argument fixes the field kind at the literal, so one instantiation used with two
kinds is refused — and cannot be finished until a struct-typed `hold` annotation
exists, which no backend has.

Three implementations, one contract:

* **seed-min** got a `GStruct` template table beside `StructDef`, and
  `parse_type_params` / `skip_struct_decl` / `instantiate_gstruct` shared by all
  four places that walk a struct declaration (the scanner, the function emitter,
  `collect()` and `stmt()`) — miss one and the failure is a bare `{ at
  <offset>` instead of a diagnostic. Instantiation happens where a struct
  literal is parsed, and `collect()`'s own hand-rolled right-hand-side scan had
  to learn the same form, or a `hold` is declared `double` while the assignment
  emits a struct literal — C type errors with no Sayanox diagnostic at all.
* **gen2** got a pre-pass instead of walker surgery: `gxscan` collects the
  templates, `gxpass` rewrites every instantiation to its mangled name and seeds
  `sdefs` with the instantiations in first-use order, so the existing struct
  machinery (field kinds, `ftypes`, typedef emission) only ever sees a concrete
  struct. A template declaration is skipped by the walker and never enters
  `sdefs`, or `Box` would look concrete with the template's fields.
* **native** got a `GSDef` table plus `gs_find`/`gs_instantiate`, called at both
  struct-literal sites (kind packing and emission). The type arguments seed the
  per-field kind map that the collector's pointer scan reads, so a `Box<str>`
  field is a root and a `Box<num>` field is not.

### Measured

* **Parity**: `selfhost/generic_struct_box.sa` (new) prints `7`, `seven`, `8`,
  `7`, `9`, `nine` on seed-min, gen2 and native. The gate `cmp`s seed-min's
  stdout against native's and greps the three mangled typedefs out of the C that
  seed-min and gen2 emit, because the layout *is* the claim.
* **Refusals, all three backends**: a wrong type argument count, a struct name
  as a type argument, `list` as a type argument, a bare template name, and one
  instantiation used with two kinds. The per-backend wording is the table in
  [`TYPES_ROADMAP.md`](TYPES_ROADMAP.md). seed-min and native name the problem;
  gen2 refuses three of the five through its general `undefined name` /
  stray-token errors, so the gate pins gen2's *failure* there and its wording
  only where gen2 names the problem (the two-kinds case). `list` is worth
  calling out: gen2 used to rewrite `Box<list>` and emit C that cannot compile
  (`incompatible types when initializing type 'double' using type 'sx_list *'`),
  and now refuses it like the other two backends, whose list refusal predates
  this increment.
* **GC survival on native**: a `Box<str>` and a `Box<num>` held across 3000
  allocating iterations both survive, `show gc_runs()` reports 2, and the output
  is byte-identical to the same program written with two concrete struct names
  on the pre-increment native.
* **Unchanged and still gated**: the concrete-name workaround
  (`generic_struct_concrete.sa`, `7 seven 8 eight 2 8 9` on all three) and the
  dotted-field-read-inside-a-literal divergence (seed-min only, gen2 `#error`,
  native refuses).

### Self-host memory ceiling

Implementing this in gen2 hit a hard wall, recorded here because it constrains
every future gen2 feature. A generated function copies each `str` parameter on
entry — `param = sx_sb_from(param)` in the emitted C, 1078 times in
`gen1_min.c` — and never frees the copy. Measured on this 4 GB workspace:

| Run | Peak RSS | Result |
|---|---|---|
| `read_file` a 624 KB source, scan it with `sx_index` | 0.9 MB | fine |
| the same scan, calling a 6-char keyword helper per position | 4 GB in 3.7 s | OOM-killed |
| `gen1_min` compiling `compiler_min.sa` before this increment (616,569 bytes) | 3.20 GB | 178 s, exit 0 |
| the same, with a first 450-line draft of this feature (+54 KB) | > 3.9 GB | OOM-killed |
| the same, with 2400 lines of trivial *flat* filler instead (+35 KB) | 3.18 GB | OOM-killed |
| the same, with the shipped version (+9.2 KB, position-based scans) | 3.68 GB | 186 s, exit 0 |

So the self-compile's peak grows by roughly 27–50 MB per KB of
`compiler_min.sa`, the ceiling here is about 3.9 GB, and HEAD was already at
3.20 GB — about 20 KB of headroom. The filler run proves it is *size* and not
nesting or this feature's content: 2400 lines of `make zzfillN(a: str, b: num)`
that nothing calls are enough to kill it. Two rules follow, and the comments in
`compiler_min.sa` say so:

1. A per-position scan must not call a helper that takes the scanned string.
   `gxscan`/`gxpass` walk positions and build a string only once an occurrence
   is confirmed.
2. A gen2 feature has a byte budget, not just a correctness budget. This one
   shipped at +9.2 KB after a +54 KB draft was killed, and its rewrite pass runs
   only when the program declares a template, so the self-host path — which
   declares none — never pays for it.

Fixing the copy itself (release a parameter's builder on every return path, or
do not copy when the callee cannot mutate) is the highest-value remaining work
in this repo: it would give the self-host path orders of magnitude of headroom
and probably most of those three minutes back. It is not attempted here, because
it changes the calling convention of every generated function and all four gates
would have to be re-proven against it.

### Gates

`make test-generic-structs` was **flipped**: it pinned three refusals of the
syntax and now pins the support (parity fixture plus the three mangled
typedefs), the five refusals above, and the two older sections unchanged.
`selfhost/generic_struct_refuse.sa` was deleted — the program it held
(`struct Box<T> { v }` with `Box<num> { 1 }`) now compiles and runs, and its
refusal cases live in the gate as `printf` fixtures beside the refusals the gate
already built that way.

The whole chain was re-run for this increment and is green: `DOCTOR-OK`;
`TRUE-SELFHOST-MIN-OK` (976 lines, 166 `[OK]`); `GEN3-OK` with gen3 ==
gen4 byte-identical; `NATIVE-TEST-OK` (864 lines, 152 `[OK]`). Logs:
`docs/logs/gs-doctor.log`, `gs-true-selfhost.log`, `gs-gen3.log`,
`gs-native-test.log`.

Not claimed **at that historical increment**: nested instantiations
(`Box<Box<num>>`), a struct or a list as a type argument, struct-typed
annotations or any cross-specialization assignment check, gen2 diagnostics
that name the template, gen2's positional field-kind
check for a single contradicting literal (`Box<num> { "seven" }` alone is
accepted by gen2 and refused by seed-min and native), a specialization worklist
with recursion (there is nothing to recurse into yet), or any change to the
pure-min bootstrap *dialect* — seed-min the compiler grew; the dialect it
accepts did not.
