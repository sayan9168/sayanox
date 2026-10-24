<div align="center">

<img src="assets/sayanox-logo-256.png" alt="Sayanox" width="120" height="120" />

# Sayanox

### A completely original systems programming language with its own self-hosting compiler

**File extension: `.sa`** · Bootstrap written in Sayanox itself · Native AOT (x86-64 Linux)

[![License: Sayanox](https://img.shields.io/badge/License-Sayanox%20v1.1-blue.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-Sayanox-blue)](https://github.com/sayan9168/sayanox)
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange)](docs/STATUS.md)

</div>

> Sayanox is designed to be **easy to read**, **easy to write**, and **powerful enough** for real systems work.  
> The compiler, tools, and most examples are written in Sayanox.

**Every claim on this page is checked by a `make` gate**, and the gate is named
next to the claim. What is finished is in [Done](#done--and-the-gate-that-proves-it);
what is not is in [Remaining](#remaining--and-where-the-build-refuses-to-claim-it).
Nothing is listed as done unless a target proves it on a clean tree.

---

## Why Sayanox?

Most new languages are either:
- Too academic, or
- Thin wrappers around existing runtimes.

Sayanox aims for a clean middle ground:

- Simple, readable syntax
- Strong focus on **self-hosting** (the compiler is written in itself)
- Native code generation (AOT)
- Built-in tools: formatter + package manager written in Sayanox
- Educational + practical at the same time

---

## Quick Start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox

make doctor          # check environment
make true-selfhost   # build the self-hosted compiler
make gen3            # gen3 == gen4 (byte-identical)
make native-test     # the native backend and every tool gate
```

Those four targets are the **hard gates**. A full run takes roughly half an
hour and ends with `DOCTOR-OK`, `TRUE-SELFHOST-MIN-OK`, `GEN3-OK` and
`NATIVE-TEST-OK`. The last recorded run is in
[`docs/gate-logs/`](docs/gate-logs/) — 31 dated logs, one per landed change.

### Compile a program

```sh
# Using the Sayanox-written compiler (produces C)
./selfhost/gen2 examples/hello.sa hello.c
cc -o hello hello.c
./hello
```

### Native AOT (x86-64 Linux)

```sh
make native
./selfhost/native_aot examples/hello.sa hello
./hello
```

---

## Language Features (Current Milestone)

The **pure-min** dialect currently supports:

| Feature | Status |
|---------|--------|
| `hold` / `show` | ✅ |
| `when` / `while` | ✅ |
| `else` / `otherwise` | ✅ |
| Recursive functions (`make` / `give`) | ✅ |
| Integer + floating arithmetic | ✅ |
| Checked integer `%` | ✅ |
| Lists | ✅ |
| Nested structs | ✅ |
| List-valued struct fields + `for v in p.xs` | ✅ all three backends |
| Struct-typed `hold` with identity checks | ✅ all three backends |
| Generic structs (`Box<T>`, `Pair<A, B>`) | ✅ all three backends |
| Nested generics (`Box<Box<num>>`, `Box<list>`) | ✅ since 2026-10-22 |
| Strings | ✅ |
| String interpolation | ✅ gen2 / gen3 · ❌ seed, native |
| File / argument builtins | ✅ |
| Byte buffers + bitwise (`write_bytes`, `read_bytes`, `bit_*`, `shl`, `shr`) | ✅ gen2 / gen3 (seed and native refuse them, like every late builtin) |
| Process builtins (`run_command`, `getenv`) | ✅ gen2 / gen3 |
| Modules (`use "file.sa"`) | ✅ textual splice, depth 8 |
| Module namespaces / aliases | ⚠️ one layer out — `tools/sxmod`, not the compiler |
| Native AOT (x86-64 Linux) | ✅ (subset) |
| i386 Linux ELF, emitted by a Sayanox program | ✅ (integer subset) |
| aarch64 ELF64, emitted by the same program | ⚠️ emitted and pinned, **never executed here** |

See [docs/STATUS.md](docs/STATUS.md) for the full tested feature matrix and known limitations.

---

## Status

Two tables, nothing between them. 147 `make test-*` targets back them up; the
four hard gates above have to stay green, with gen3 and gen4 byte-identical,
for anything to move from the second table to the first.

### Done — and the gate that proves it

| # | What is done | Proof |
|---|---|---|
| 1 | **Self-hosting pure-min dialect.** seed → gen1 → gen2 → gen3, and **gen3 == gen4 byte-identical** | `make true-selfhost`, `make gen3` |
| 2 | **Full-language readiness probes 8/8** — concrete struct function arguments and returns, identifier interpolation, expression-valued struct fields, checked index calls (gen2/gen3) | `make test-full-language-readiness` (runs inside `make gen3`) |
| 3 | **A collector in the C seed** — conservative mark & sweep over the builder registry. Bootstrap peak RSS **1,278,704 KiB → 29,768 KiB** with byte-identical generated C, so the budget cap drops 1536 MiB → 64 MiB | `make test-seed-collector`, `make test-seed-gc`, `make test-seed-borrow` |
| 4 | **Nested generic structs** — `Box<Box<num>>`, `Box<Box<Box<num>>>`, `Box<list>`, `Pair<Box<num>, str>` on seed, gen2 and native, with the typedef order C accepts, plus ten pinned refusals | `make test-generic-structs-nested`, `make test-generic-struct-limits` |
| 5 | **Stdlib: nested JSON + cryptography** — `stdlib/json_deep.sa` reads nested documents, `stdlib/crypto.sa` is SHA-256 and HMAC-SHA256 written in the dialect (no bitwise operators in seed: 32-bit words ride in doubles). Byte-identical on all three backends | `make test-stdlib-json-deep`, `make test-stdlib-crypto` |
| 6 | **Package digests, provenance and signatures** — `pkg.meta` carries `sha256=` and `origin=`; `sxpkg sign` / `authenticate` add and check an HMAC-SHA256 `sig=`/`signer=`. The gate refuses a *real* `sum=` collision | `make test-sxpkg-crypto`, `make test-sxpkg-transfer-hardening` |
| 7 | **LSP semantic resolution** — definition, references and rename resolve the binder (parameter, body `hold`, top-level declaration) instead of matching spelling, skip strings and comments, rename across indexed files; `workspace/didChangeWatchedFiles` is registered and answered | `make test-lsp-semantic`, `make test-lsp-workspace` |
| 8 | **A second machine target** — `tools/native32.sa`, written in Sayanox, emits **i386** Linux ELF for a documented integer subset; four backends print identical bytes, ELFCLASS32/EM_386 and determinism are pinned, nine refusals | `make test-native32` ([NATIVE32.md](docs/NATIVE32.md)) |
| 9 | **A third machine target, emitted** — the same program with `arm64` emits ELF64/EM_AARCH64; container, goldens, data-segment agreement between the two encoders and the refusals are pinned | `make test-native-arm64` |
| 10 | **Module namespacing, one layer out** — `tools/sxmod.sa` rewrites `module NAME from "path"` + `alias.member` into prefixed flat declarations. The gate first proves the flat dialect **cannot** compose two modules that both declare `add` (all three backends refuse it), then compiles the namespaced version to identical stdout, and pins 16 refusals | `make test-sxmod` ([MODULES.md](docs/MODULES.md)) |
| 11 | **The C trust anchor is pinned and audited** — the seed is one file: 2,176 lines, 100,919 bytes, SHA-256 `e4cc34b4…a2a01cb9`, recomputed by `tools/sxaudit.sa` (Sayanox, on `stdlib/crypto.sa`) and compared with the tracked pin; four standard headers, no `system`/`exec*`/`socket`/`getenv` in the compiler surface; compiling the 20.1k-line compiler twice gives byte-identical C | `make test-trust-anchor` |
| 12 | **Phase D step 1–2: the language surface the backend needs** — byte buffers, `bit_and/or/xor/not`, `shl`, `shr`, `write_bytes`, `bytes_f64`, `read_bytes` — gated by *running* an ELF a Sayanox program emitted with them | `make test-native-primitives`, `make test-read-bytes` |
| 13 | **Phase D step 3: the ELF image writer and rel32 linker are Sayanox** — `tools/sxlink.sa`, against the `SX_LINK_DUMP` seam; five fixtures link byte-identically to C and run | `make test-native-sxlink` |
| 14 | **Phase D step 4: the x86-64 instruction encoder is Sayanox** — `tools/sxencode.sa` replays `SX_ENCODE_LOG` and reproduces five code segments byte-for-byte with the same ~50-record vocabulary | `make test-native-sxencode` |
| 15 | **Phase D step 5: the native front end's phase 1 is Sayanox** — `tools/sxdefs.sa` (1,118 lines) is `expand_use()` + `collect_defs()`: the `use` splice and the four definition tables, against the `SX_DEFS_DUMP` seam. 151 `.sa` files across `selfhost`, `stdlib`, `tools`, `examples`, `samples` and `registry` swept by hand: 145 byte-identical on both outputs, 6 identical refusals, 0 diffs; 34 refusal fixtures and the real 20,106-line compiler produce the same diagnostics | `make test-native-sxdefs` ([log](docs/gate-logs/2026-10-23-native-frontend-phase1/)) |
| 16 | **No bash, awk, sed, Python, node or ruby** in any maintained build or test path; the four `sh` test drivers and the whole package tool are Sayanox programs | `make test-language-deps` |
| 17 | **The documentation is machine-checked** — the docs may not claim what the build does not do; `all-sayanox` must still fail, no Stage-2 placeholder may return, legacy docs keep their banner | `make test-doc-claims` |

### Remaining — and where the build refuses to claim it

| # | What is still missing | Exactly what is open | Refusal / record |
|---|---|---|---|
| 1 | **Full-language self-host** | String interpolation and struct function signatures are still open on **seed and native**; there is no exhaustive language specification, and four closure probes are not an acceptance spec | `make true-selfhost-full` **fails closed** |
| 2 | **The native backend in Sayanox** | `selfhost/native_aot.c` is still **4,597 lines of C** and still runs its own phase 1. The four Sayanox ports (`sxlink`, `sxencode`, `sxdefs`, and the primitives) are proved *equal* through dump seams — they are **not wired in** | `make all-sayanox` **fails closed** |
| 3 | **Phase D steps 6–10** | Still C: kind inference (`pk_*`, the fixpoint and the generic instantiation it drives), the emit tree, the 856-line emitted runtime, the 339-line collector — and then the wiring that deletes the C | same; plan in [docs/ALL_SAYANOX_PHASE.md](docs/ALL_SAYANOX_PHASE.md) |
| 4 | **The seed in Sayanox (Phase E)** | 2,176 lines of C. The decision is recorded as **option 2** — keep one pinned, audited, minimal anchor — because option 1 (a prebuilt bootstrap binary) needs the rest of Phase D first. The seed compiled the compiler that compiled the auditor, so this is tamper *evidence*, not an answer to trusting-trust | same + `make test-trust-anchor` |
| 5 | **The build driver in Sayanox** | `Makefile` (6,275 lines) and 14 POSIX `sh` scripts still drive the build | same |
| 6 | **Seed GC completeness** | **Strings only — seed lists are never freed.** Registry buckets never shrink, conservative roots can retain garbage, and a genuinely live 8 MiB set still exits 1 with `sx: out of memory`. Not a bounded-heap claim | [docs/GC.md](docs/GC.md) |
| 7 | **Stdlib depth** | Nested JSON is **read-only**: no writer, no mutation, no pretty-printer, first key wins on duplicates. `crypto.sa` is hashing only — no public-key signature, no cipher, no KDF beyond HMAC, no constant-time promise, and slow by construction. HTTP stays optional and outside the bootstrap | [docs/STDLIB.md](docs/STDLIB.md), `make test-network` (optional) |
| 8 | **Package trust** | The signature is **symmetric**: `authenticate` needs the same secret that signed. No public-key signature, no signed index, no key distribution, no first-download trust. `origin=` is a provenance note, not proof. Transport still shells out to `curl`/`wget`. No crash-proof transaction claim | [docs/REGISTRY.md](docs/REGISTRY.md) |
| 9 | **An IDE-complete LSP** | Scope resolution is **not type resolution**: no symbol table, no following `use` into another file's declaration, no shadowing inside nested blocks, fields and variables share a namespace. One root, 128 files, 256 KiB each, ≤32 changes per watch notification, no workspace diagnostic pass | [docs/LSP.md](docs/LSP.md) — "still not IDE-complete" |
| 10 | **Second-ISA parity** | i386 and aarch64 cover a **documented integer subset**: no heap, strings, lists, structs, functions or collector there. **Nothing aarch64 has ever been executed here** (no ARM hardware, no emulator). No riscv64 emitter, no IR executor — instruction-count preservation is not semantic losslessness | [docs/NATIVE32.md](docs/NATIVE32.md), [docs/NATIVE_IR.md](docs/NATIVE_IR.md) |
| 11 | **Namespacing in the language** | `sxmod` is a source-to-source pass. The dialect still has shared declaration tables and no module identity, private visibility, nesting, search paths or import cache. Not planned in the bootstrap compiler | [docs/MODULES.md](docs/MODULES.md) |
| 12 | **`.sa` on GitHub** | Not registered in github-linguist, so the language bar keeps showing C. The upstream contribution is prepared but not opened (Linguist wants demonstrated in-the-wild usage) | [docs/LINGUIST.md](docs/LINGUIST.md) |
| 13 | **Platforms and registry growth** | x86-64 Linux is the only executed platform; the package registry is local; the stdlib is ten modules | roadmap below |

### What is deliberately refused

These produce an **error**, not a wrong answer, and gates require the error: a
*concrete* struct name as a generic type argument, an unknown type name, an
escaped type parameter, a wrong type-argument count, gen2 `push(p.xs, v)` and
whole-list `show p.xs`, every late builtin on seed-min and native, and the
tested out-of-subset language forms. `make all-sayanox` and
`make true-selfhost-full` fail on purpose — they are the two places the project
refuses to overstate itself.

---

## Sayanox-written Tools

```sh
make tools

./tools/sxfmt input.sa formatted.sa     # formatter
./tools/sxpkg init                      # package manager
./tools/sxpkg add math 0.1.0
./tools/sxpkg list
```

The formatter currently handles whitespace. The package tool is one Sayanox
program, `tools/sxpkg.sa` (built to `./tools/sxpkg` by `make sxpkg`): `init`,
`add`, `list`, `remove`, `seed`, `search`, `info`, `deps`, `verify`, `sum`,
`sign`, `authenticate`, `publish`, `install`, `install-local`, `sync`, `fetch`,
the online opt-in policy, `SAYANOX_ROOT`/`SAYANOX_REGISTRY`/`SAYANOX_ONLINE`,
and its own exit statuses. Its shell wrapper was deleted on 2026-10-22; the
only program it still starts is the transport itself, `curl` or `wget`. Full
registry support is still evolving — see
[docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md).

The language server (`tools/sayanox_lsp.sa`) with its folder index and binder,
the IR translator (`tools/emit_to_ir.sa`), four pieces of the native backend —
its ELF image writer with the rel32 linker (`tools/sxlink.sa`), its x86-64
instruction encoder (`tools/sxencode.sa`), its front-end phase 1
(`tools/sxdefs.sa`) and a whole second/third ISA emitter for the integer subset
(`tools/native32.sa`) — the module-namespacing pass (`tools/sxmod.sa`), the
seed auditor (`tools/sxaudit.sa`) and the negative-diagnostic suites
(`tools/sxdiag.sa`) are Sayanox programs too, and no maintained build or test
path needs bash, awk, sed or Python (`make test-language-deps`). Driving
another program used to require the shell, because `spawn(path)` takes no
arguments; since 2026-10-21 `run_command(cmd)` gives a Sayanox program the exit
status of a command line, which is what let four `sh` test drivers and then the
whole package tool move over, and since 2026-10-22 `getenv(name)` lets it read
the environment the wrappers used to read.

---

## Project Layout

| Path | Role |
|------|------|
| `*.sa` | Sayanox source (compiler, tools, stdlib, examples, fixtures) |
| `selfhost/compiler_min.sa` | Maintained pure-min compiler written in Sayanox (20,106 lines) |
| `selfhost/seed/sxc_seed_min.c` | The C bootstrap seed — the trust anchor, pinned by `selfhost/seed/sxc_seed_min.audit` |
| `selfhost/native_aot.c` | x86-64 Linux native-AOT backend (still C) |
| `tools/sxlink.sa` | Sayanox ELF image writer + rel32 linker for that backend |
| `tools/sxencode.sa` | Sayanox x86-64 instruction encoder for that backend |
| `tools/sxdefs.sa` | Sayanox front-end phase 1: the `use` splice and the definition tables |
| `tools/native32.sa` | Sayanox i386 / aarch64 ELF emitter (integer subset) |
| `tools/sxmod.sa` | Sayanox module-namespacing pass (`module` / `alias.member`) |
| `tools/sxaudit.sa` | Sayanox auditor for the C seed (size + SHA-256 against the pin) |
| `tools/sxdiag.sa` | Sayanox negative-diagnostic suites (replaced four `sh` drivers) |
| `stdlib/` | Ten Sayanox modules, including `json_deep.sa` and `crypto.sa` |
| `Makefile` | Bootstrap, tests, verification (147 `test-*` targets) |
| `docs/` | Status, design notes, language docs |
| `docs/gate-logs/` | One dated folder per landed change: what was claimed, and the run that proves it |

---

## Language on GitHub

The badge above says **Language: Sayanox** because that is what the source is.
GitHub's own language bar may still say **C**, and that is expected.

Sayanox uses the `.sa` extension, which is not yet registered in
[github-linguist](https://github.com/github-linguist/linguist)'s
`languages.yml`. Linguist only counts languages it knows, so the 259 `.sa`
files — about 1.4 MB, roughly 62% of the source Linguist would count —
contribute nothing to the bar today, and what is left is the hand-written C
seed and native backend, the `Makefile` and the shell scripts. A
`.gitattributes` cannot register a new language; only an upstream Linguist
change can, so **the bar will keep showing C until that change is merged**.

`.sa` is deliberately not mapped to Python, C or any other existing language to
make the statistics look better — that would mislabel the source.

Everything needed for the upstream contribution is prepared in this repository:
`.gitattributes`, `samples/Sayanox/`, `grammars/sayanox.tmLanguage.json`, the
exact `languages.yml` snippet, a PR checklist and draft PR text. See
**[docs/LINGUIST.md](docs/LINGUIST.md)** — including the honest assessment of
why the pull request has not been opened yet (Linguist requires demonstrated
in-the-wild usage of an extension). [docs/GITHUB_LANGUAGE.md](docs/GITHUB_LANGUAGE.md)
has the short version.

---

## Roadmap (High Level)

- [x] Self-hosting pure-min dialect (`make true-selfhost`, `make gen3`)
- [x] Native AOT subset (x86-64 Linux) (`make native-test`)
- [x] Formatter + local package tool in Sayanox, with digests and keyed signatures
- [x] Language server in Sayanox, with binder-based resolve, folder rename and file watching
- [x] Toolchain free of bash, awk, sed and Python (`make test-language-deps`)
- [x] A collector in the bootstrap seed (strings) (`make test-seed-collector`)
- [x] Nested generic structs on all three backends (`make test-generic-structs-nested`)
- [x] Nested JSON reader and SHA-256/HMAC-SHA256 in the stdlib
- [x] A second and third machine target emitted by a Sayanox program — i386 runs, aarch64 is pinned but not executed
- [x] Module namespacing one layer out (`make test-sxmod`)
- [x] The C seed pinned and audited as a documented exception (`make test-trust-anchor`)
- [ ] **Next phase — all-in-Sayanox toolchain** ([plan](docs/ALL_SAYANOX_PHASE.md)):
      port the rest of the native backend (kind inference, the emit tree, the
      runtime, the collector), wire the finished ports in, and move the build
      driver into Sayanox. Steps 1–5 of Phase D have landed (byte buffers,
      `read_bytes`, `sxlink`, `sxencode`, `sxdefs`); `make all-sayanox` fails
      closed until the rest does
- [ ] Full Stage-2 language self-hosting — seed/native interpolation and struct
      function signatures first; `make true-selfhost-full` fails closed
- [ ] The native subset (heap, strings, lists, structs, functions, collector) on
      a second ISA, plus execution evidence for aarch64
- [ ] Public-key package signatures, a signed index and first-download trust
- [ ] Type-level and incremental workspace indexing in the LSP
- [ ] Broader platform support
- [ ] Standard library growth

### Next phase: everything in Sayanox

The maintained *logic* is already Sayanox: the compiler
(`selfhost/compiler_min.sa`), the formatter, the package tool, the language
server and its framed-session test client. Since 2026-10-17 no maintained path
needs bash, awk, sed or Python either.

What is still not Sayanox is small, measurable, and listed in
[docs/ALL_SAYANOX_PHASE.md](docs/ALL_SAYANOX_PHASE.md): the 2,176-line C seed,
the 4,597-line C native backend, and the make/POSIX-sh build driver.
`make all-sayanox` prints that inventory on every run — it computes the numbers
instead of quoting them — and then **fails closed**, the same way
`true-selfhost-full` refuses to claim a full-language self-host, so the
remaining work cannot silently drift or be forgotten.

The port is deliberately incremental, each step written against a dump seam
that changes no emitted byte:

| Phase D | Piece | State |
|---|---|---|
| ~~step 1~~ (2026-10-18) | byte buffers, `bit_*`, `shl`/`shr`, `write_bytes`, `bytes_f64` | done, `test-native-primitives` |
| ~~step 2~~ (2026-10-20) | `read_bytes`, the binary reader the buffers were missing | done, `test-read-bytes` |
| ~~step 3~~ (2026-10-20) | `tools/sxlink.sa` — ELF image writer + rel32 linker (`SX_LINK_DUMP`) | done, `test-native-sxlink` |
| ~~step 4~~ (2026-10-21) | `tools/sxencode.sa` — the x86-64 encoder (`SX_ENCODE_LOG`) | done, `test-native-sxencode` |
| ~~step 5~~ (2026-10-23) | `tools/sxdefs.sa` — front-end phase 1, the `use` splice and the definition tables (`SX_DEFS_DUMP`) | done, `test-native-sxdefs` |
| step 6 | kind inference: `pk_*`, the fixpoint, generic instantiation | **open** |
| step 7 | the emit tree | **open** |
| step 8 | the 856-line emitted runtime | **open** |
| step 9 | the 339-line collector | **open** |
| step 10 | wire the Sayanox ports in as the producers and delete the C | **open** |

Earlier moves on the same path: on 2026-10-17 the 150-line C IR translator
became `tools/emit_to_ir.sa` with byte-identical output, the LSP folder index
moved into Sayanox (the C directory header and its binder were deleted), the
127-line C framed-session test client became `tools/lsp_workspace_test.sa`, and
ten unreferenced legacy C files were removed. Phase E — the seed — stays with
**option 2**, one pinned and audited C anchor (`make test-trust-anchor`), until
Phase D makes option 1 (a prebuilt bootstrap binary, rebuildable from `.sa`)
honest.

---

## Logo

<p align="center">
  <img src="assets/sayanox-logo-256.png" alt="Sayanox mark" width="96" height="96" />
</p>

The mark is a rounded-square badge on an indigo&nbsp;→&nbsp;cyan gradient,
carrying a geometric <strong>S</strong> built from two 270-degree circular arcs.
It is the boot chain made visible: a self-hosting compiler has to be folded out
of itself, and two arcs whose tangents meet eastward at the waist are the
smallest shape that says so without drawing a compiler.

The full set — vector masters, rasters, the wordmark lockup and a 1280×640
social card — lives in [`assets/`](assets/), with the palette, the exact
geometry and the usage notes in [`assets/README.md`](assets/README.md).

```html
<!-- the mark, at any size -->
<img src="assets/sayanox-logo.svg" alt="Sayanox" width="64" />

<!-- wordmark lockup, for a dark or coloured ground -->
<img src="assets/sayanox-lockup.svg" alt="Sayanox" height="48" />

<!-- browser tab icon -->
<link rel="icon" type="image/svg+xml" href="assets/favicon.svg" />
```

---

## Contributing

This is an active research + engineering project. Issues and pull requests are welcome.

```sh
make doctor
make true-selfhost
make native-test
```

A change lands with the gate that proves it: add a `make test-*` target, keep
the four hard gates green with gen3 == gen4, update the two status tables
above, and leave a dated folder in `docs/gate-logs/`. If a claim cannot be
checked by a target, it belongs in the **Remaining** table instead.

---

## License

[Sayanox License v1.1](LICENSE) © [Sayan](https://github.com/sayan9168) (sayan9168)

Full text: [LICENSE](LICENSE) · License home: [sayanox-license](https://github.com/sayan9168/sayanox-license)

---

<div align="center">

**Built by [Sayan the researcher](https://github.com/sayan9168)**  
[Portfolio](https://sayan9168.github.io) · [GrokOSINT](https://github.com/sayan9168/GrokOSINT)

</div>
