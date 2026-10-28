<div align="center">

<img src="assets/sayanox-logo-256.png" alt="Sayanox" width="120" height="120" />

# Sayanox

### A completely original systems programming language with its own self-hosting compiler

**File extension: `.sa`** · Bootstrap written in Sayanox itself · Native AOT (x86-64 Linux)

[![License: Sayanox](https://img.shields.io/badge/License-Sayanox%20v1.1-blue.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-Sayanox-blue)](https://github.com/sayan9168/sayanox)
[![CI](https://github.com/sayan9168/sayanox/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/sayan9168/sayanox/actions/workflows/ci.yml)
[![full-bootstrap](https://github.com/sayan9168/sayanox/actions/workflows/full-bootstrap.yml/badge.svg?branch=main)](https://github.com/sayan9168/sayanox/actions/workflows/full-bootstrap.yml)
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange)](docs/STATUS.md)

</div>

> Sayanox is designed to be **easy to read**, **easy to write**, and **powerful enough** for real systems work.  
> The compiler, tools, and most examples are written in Sayanox.

**Build/test operations use the native Sayanox driver, `./sx target <name>`**, and the gate is named
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

## Sayanox build driver — Makefile removed

`Makefile` has been deleted, not renamed or wrapped. Use the native Sayanox
entry `./sx` from the repository root (Linux x86-64):

```sh
sha256sum -c bootstrap/sx.sha256
./sx doctor
./sx verify-entry
./sx target test-ported test-ported-more test-memory
./sx target test-driver
./sx migration  # 236/236 original target names implemented
```

**All 236 original target names are implemented in Sayanox.** Unknown targets
fail with exit 2, with no fallback. `./sx ci` runs the complete original
minimum-selfhost, gen3 and native acceptance chain; target registration alone
is not proof of acceptance. See the migration ledger for measured results.

`sx` is an intentionally checked-in generated executable, not a shell script.
The generated entry and pinned native compiler anchor are explicit binary trust
inputs. All maintained implementation source is Sayanox; the final C seed and
Makefile are retired. Source retirement and final guarded acceptance are recorded
separately in the migration report. Self-reproduction is not independent trust proof.
See [entry provenance and independent rebuild](bootstrap/README.md) and
[migration implementation and remaining obligations](docs/MAKEFILE_MIGRATION.md).

## Quick Start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
sha256sum -c bootstrap/sx.sha256
./sx target doctor gen2
./sx target native
./selfhost/native_aot examples/hello.sa hello
./hello
```

Missing compilers are bootstrapped by the Sayanox driver. `gen2` explicitly
rebuilds the seed/compiler chain; native tool builds install atomically.
`./sx target clean` removes disposable build outputs but preserves `./sx`, so
cleaning does not remove the entry needed to rebuild.

### Compile via C

```sh
./sx target gen2
./selfhost/gen2 examples/hello.sa hello.c
cc -o hello hello.c
./hello
```

## CI/CD

| Workflow | Current behavior |
|---|---|
| [CI](.github/workflows/ci.yml) | Checks the entry/source pins and runs migrated suites; a separate mandatory full-acceptance job refuses incomplete coverage |
| [full-bootstrap](.github/workflows/full-bootstrap.yml) | Clean source-to-native-entry reconstruction, followed by the full-acceptance blocker |
| [release](.github/workflows/release.yml) | Entry verification and full acceptance before packaging/publication; cannot publish while targets are pending |

```sh
./sx ci  # exits 1 until the entire original acceptance surface is implemented
```

The original hard-gate chain (`doctor`, `true-selfhost`, `gen3`, `native-test`)
has not been replaced with just the migrated subset. Older proof references
below and historical gate logs describe earlier runs, not a successful run of
all those targets through the new driver. Check availability with `./sx migration`.

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
| Struct-typed `make` parameters & returns | ✅ gen2 / gen3 / native · ❌ seed |
| Generic structs (`Box<T>`, `Pair<A, B>`) | ✅ all three backends |
| Nested generics (`Box<Box<num>>`, `Box<list>`) | ✅ since 2026-10-22 |
| Strings | ✅ |
| String interpolation (`${id}`) | ✅ gen2 / gen3 / native · ❌ seed |
| File / argument builtins | ✅ |
| Byte buffers + bitwise (`write_bytes`, `read_bytes`, `bit_*`, `shl`, `shr`) | ✅ gen2 / gen3 / `sxc_native` |
| Process & IPC builtins (`run_command`, `getenv`, `spawn`, `child_*`, `read_line`, `read_n`, `path_*`) | ✅ gen2 / gen3 / `sxc_native` (pure Linux x86-64 syscalls) |
| Modules (`use "file.sa"`) | ✅ textual splice, depth 8 |
| Transitive DAG modules & namespaces (`module ... from "..."`, `alias.member`) | ✅ `sxc_native`, `sxbuild`, and `sxmod --transitive` (multi-dir DAGs, singleton init, cross-module structs) |
| C-free self-compiling x86-64 ELF64 compiler (`tools/sxc_native.sa`) | ✅ compiles itself, all tools, and `compiler_min.sa` directly to static ELF64 with zero `cc` / zero libc |
| Native AOT (x86-64 Linux, written in Sayanox) | ✅ (`selfhost/native_aot.sa`, C backend deleted) |
| Portable IR VM (`tools/sxirexec.sa`) | ✅ executes `emit_to_ir` portable IR directly in Sayanox |
| i386 Linux ELF, emitted by a Sayanox program | ✅ integer expressions, static string spans, `len`, byte indexing, and bounded variable-to-variable `concat` |
| aarch64 & riscv64 ELF64, emitted & user-mode executed in Sayanox | ✅ `tools/native32.sa` emits the same bounded integer/string subset; `tools/sxisaexec.sa` executes it with six-way parity |

See [docs/STATUS.md](docs/STATUS.md) for the full tested feature matrix and known limitations.

---

## Status

Two tables, nothing between them. 167 `./sx target test-*` targets back them up; the
four hard gates above have to stay green, with gen3 and gen4 byte-identical,
for anything to move from the second table to the first.

### Done — and the gate that proves it

| # | What is done | Proof |
|---|---|---|
| 1 | **Self-hosting pure-min dialect.** seed → gen1 → gen2 → gen3, and **gen3 == gen4 byte-identical** | `./sx target true-selfhost`, `./sx target gen3` |
| 2 | **Full-language readiness probes 8/8** — concrete struct function arguments and returns, identifier interpolation, expression-valued struct fields, checked index calls (gen2/gen3) | `./sx target test-full-language-readiness` (runs inside `./sx target gen3`) |
| 3 | **Sayanox seed runtime profile** — traced strings/list headers/buffers preserve aliases; discarded-list churn fits 4 MiB and own-source C1 emission fits 64 MiB | `./sx target test-seed-collector`, `./sx target test-seed-gc`, `./sx target test-seed-borrow`, `./sx target test-seed-bootstrap-budget` |
| 4 | **Nested generic structs** — `Box<Box<num>>`, `Box<Box<Box<num>>>`, `Box<list>`, `Pair<Box<num>, str>` on seed, gen2 and native, with the typedef order C accepts, plus pinned type-argument and literal-agreement refusals | `./sx target test-generic-structs-nested`, `./sx target test-generic-struct-limits` |
| 5 | **Stdlib: nested JSON reader + writer/pretty-printer + symmetric & public-key cryptography** — `stdlib/json_deep.sa` reads/validates nested documents, `stdlib/json_write.sa` builds, updates (`jw_obj_set`/`jw_obj_del`), minifies and pretty-prints nested JSON, `stdlib/crypto.sa` implements SHA-256 and HMAC-SHA256, and `stdlib/pubkey.sa` implements Curve25519 (`GF(2^255 - 19)`) Schnorr-SHA256 public-key signatures. Byte-identical on all three backends | `./sx target test-stdlib-json-deep`, `./sx target test-stdlib-json-write`, `./sx target test-stdlib-crypto`, `./sx target test-sxpkg-pubkey` |
| 6 | **Package digests, provenance, HMAC signatures, and public-key package + index verification** — `pkg.meta` carries `sha256=`, `origin=`, symmetric `sig=`/`signer=`, and asymmetric Curve25519 `pubkey=`/`pubkeyid=`/`pubsig=`; `sxpkg sign-index` / `verify-index` signs and verifies `INDEX.sig` + listed package digests against `.sayanox/trusted_keys` with `.sec` deleted | `./sx target test-sxpkg-crypto`, `./sx target test-sxpkg-pubkey`, `./sx target test-sxpkg-transfer-hardening` |
| 7 | **LSP semantic + type-level hover & cross-file workspace resolution** — definition, references, rename, `hover` (parameter types, inferred call/struct/generic `Box<num>.val` types), and `signatureHelp` resolve across local scopes, `use "..."` imports, open overlays, and unopened indexed workspace `.sa` files | `./sx target test-lsp-semantic`, `./sx target test-lsp-workspace`, `./sx target test-lsp-types` |
| 8 | **A second machine target** — `tools/native32.sa`, written in Sayanox, emits **i386** Linux ELF for integer expressions, static string spans, `len(string)`, byte indexing, and bounded variable-to-variable `concat`; ELFCLASS32/EM_386 and determinism are pinned, with the supported boundary and explicit refusals tested | `./sx target test-native32` ([NATIVE32.md](docs/NATIVE32.md)) |
| 9 | **Third and fourth machine targets, emitted** — `tools/native32.sa` with `arm64` emits ELF64/EM_AARCH64 and with `riscv64` emits ELF64/EM_RISCV (RV64IM); containers, goldens, three-way data-segment agreement across i386/arm64/riscv64 and the refusals are pinned | `./sx target test-native-arm64`, `./sx target test-native-riscv64` |
| 10 | **Module namespacing, one layer out** — `tools/sxmod.sa` rewrites `module NAME from "path"` + `alias.member` into prefixed flat declarations. The gate first proves the flat dialect **cannot** compose two modules that both declare `add` (all three backends refuse it), then compiles the namespaced version to identical stdout, and pins 16 refusals | `./sx target test-sxmod` ([MODULES.md](docs/MODULES.md)) |
| 11 | **Explicit native trust anchor pinned and audited** — Sayanox SHA-256/size audit, source/anchor fixed point, isolated no-C/poisoned-compiler reconstruction and real own-source emission determinism; not independent trust proof | `./sx target test-trust-anchor`, `./sx target test-native-bootstrap` |
| 12 | **Phase D steps 1–10: the entire x86-64 native AOT backend is Sayanox (`selfhost/native_aot.c` deleted)** — `selfhost/native_aot.sa` + `tools/sx{enc,infer,data,emit,runtime,gc,link,pipeline}_lib.sa` + `tools/sxdefs.sa` + `tools/sxemit.sa` replace and delete the 4,598-line C backend cleanly as the sole producer of `./selfhost/native_aot` | `./sx target test-native-sxemit`, `./sx target test-native-emit-split`, `./sx target native-test` |
| 13 | **Stage-2 native parity** — concrete struct-typed `make` parameters & returns and `${id}` string interpolation work natively in `selfhost/native_aot.sa`, matching `gen2` byte-for-byte across 13 positive fixtures and 23 refusals | `./sx target test-native-stage2-parity` |
| 14 | **Portable IR virtual machine (`tools/sxirexec.sa`)** — loads and executes `emit_to_ir --strict --source-offsets` portable IR directly in Sayanox (including ELF-deleted `compile-and-run` and 4-way `seed-min == gen2 == native_aot == sxirexec` parity) | `./sx target test-ir-exec` |
| 15 | **Sayanox build/bootstrap/parity driver (`tools/sxbuild.sa`)** — `doctor`, `inventory`, `build`, `native`, `tool`, `parity`, and `bootstrap` written in Sayanox | `./sx target test-sxbuild` |
| 16 | **No bash, awk, sed, Python, node or ruby** in any maintained build or test path; the four `sh` test drivers and the whole package tool are Sayanox programs | `./sx target test-language-deps` |
| 17 | **Documentation/source audits** — zero maintained C/header/scripts, explicit native trust boundary, no runnable Stage-2 placeholder and historical-doc banners | `./sx target test-doc-claims`, `./sx target all-sayanox` |
| 18 | **C-free native compiler and Sayanox seed bootstrap** — native compiler, C-output frontend and compatibility CLI build from Sayanox; no maintained C seed remains. Generated C compatibility output and its host compiler are retained | `./sx target test-sxc-native`, `./sx target test-native-bootstrap`, `./sx target verify-seed` |
| 19 | **Pure-Sayanox compiler suite runner (`tools/sxsuite.sa`)** — executes 6 compiler test suites (`stage2_interp`, `struct_fn`, `generic_struct_limits`, `full_lang_ready`, `compiler_features`, `ir_audit`) directly in C-free Sayanox | `./sx target test-sxsuite` |
| 20 | **User-mode ARM64 & RISC-V ELF64 emulator (`tools/sxisaexec.sa`)** — executes the tested AArch64/RV64IM integer and static-string compiler subset with 6-way parity; also probes scalar RV64F/D and AArch64 S/D arithmetic plus bounded `openat`/`read`/`write`/`close` syscalls. Not a full RV64GC ISA or full-language compiler claim. | `./sx target test-sxisaexec` |
| 21 | **Transitive multi-directory `module` DAG binder (`tools/sxmod_lib.sa`)** — resolves multi-directory diamond/chain `module` graphs with cycle detection, topological ordering, singleton init, and cross-module `Mod_<mod>_<Struct>` types across `sxc_native`, `sxbuild`, and `sxmod --transitive` | `./sx target test-sxmod-deep` |
| 22 | **Module-aware LSP IDE features (`tools/sayanox_lsp.sa`)** — `module ... from "..."` hover/definition/signatureHelp, cross-module struct field resolution, multiline `signatureHelp`, lexical block-scoped shadowing, and `textDocument/prepareRename` | `./sx target test-lsp-ide` |
| 23 | **Extended 5-backend standard library** — `stdlib/map.sa`, `stdlib/sort.sa`, `stdlib/path.sa`, `stdlib/cli.sa`, and `stdlib/bytes.sa` (hex/base64/LE32/CRC-16) verified across 5 backends (`seed-min == gen2 == native_aot == sxc_native == sxirexec`) | `./sx target test-stdlib-extended` |
| 24 | **CSV row codec in the stdlib** — `stdlib/csv.sa` parses and writes RFC 4180-style rows (quoted fields, embedded commas/CR/LF, doubled quotes, three malformed-row refusals) with a packed-string row type; 44 hand-computed values identical on seed-min, gen2 and native | `./sx target test-stdlib-csv` |
| 25 | **URL / query-string codec (`stdlib/url.sa`)** — percent-encoding and decoding, packed query strings with parse/write/get/has, and refusal of malformed escapes and NUL bytes; 39 values pinned by an independent `urllib` oracle | `./sx target test-stdlib-next` |
| 26 | **Gregorian calendar arithmetic (`stdlib/datetime.sa`)** — Julian Day Numbers, leap years, weekday names, day-of-year, add-days, `YYYY-MM-DD` format/parse and the inverse conversion; 43 values pinned by Python `datetime`/`calendar` | `./sx target test-stdlib-next` |
| 27 | **Checksums and Luhn digits (`stdlib/hash.sa`)** — byte sums, rolling/djb2/sdbm/poly131 hashes, RFC 1950 Adler-32 and Luhn check-digit generation/validation; 24 values pinned by `zlib` and a hand-written Luhn oracle; explicitly non-cryptographic | `./sx target test-stdlib-next` |
| 28 | **First-use generic literal type safety** — gen2/gen3 now check the existing positional type-argument constraints before inferring a layout; 14 literal refusals plus strict O0/O2 positive parity retain seed/native agreement | `./sx target test-generic-struct-limits`, [types contract](docs/TYPES_ROADMAP.md#first-use-literal-constraints-2026-10-27) |
| 29 | **All-source native build/bootstrap migration** — all 236 baseline targets are implemented; Makefile and frozen C seed retired, with explicit pinned native trust inputs | `./sx target all-sayanox`, [migration acceptance](docs/ALL_SAYANOX_PHASE.md) |
| 30 | **Precise generic-head diagnostics** — gen2/gen3 report wrong counts, unsupported/unknown type arguments and bare templates; nine specific refusal checks retain fail-closed C output | `./sx target test-generic-struct-limits`, [diagnostics](docs/TYPES_ROADMAP.md#generic-head-diagnostics-2026-10-28) |

### Remaining — and where the build refuses to claim it

| # | What is still missing | Exactly what is open | Refusal / record |
|---|---|---|---|
| 1 | **Full-language self-host** | String interpolation and struct function signatures now work on `gen2`/`gen3` and `native_aot`, while **seed-min** stays intentionally minimal and the compiler source (`compiler_min.sa`) remains in the pure-min intersection | `./sx target true-selfhost-full` **fails closed** |
| 2 | **Independent bootstrap trust proof** | Native anchor/entry are explicit binary trust inputs. Hashes and fixed points cannot exclude trusting-trust attacks; independent diverse reconstruction remains future work | [trust boundary](bootstrap/README.md) |
| 3 | **Precise / bounded-heap GC guarantees** | Seed strings, list headers and backing buffers are traced and collected. Post-sweep registry/scratch shrinking is implemented with allocation-failure probes (acceptance tracked in [STATUS](docs/STATUS.md)); conservative roots can still retain garbage, and live heaps/allocator overhead remain memory limits. Current budget tests do not prove bounded memory for arbitrary programs | [current seed runtime](docs/NATIVE_BOOTSTRAP.md), [historical GC notes](docs/GC.md) |
| 4 | **Stdlib depth** | `json_write.sa` updates top-level object keys functionally (numbers beyond 6 fractional places are rounded). `pubkey.sa` / `crypto.sa` run on IEEE-754 doubles with no constant-time side-channel claim. HTTP stays optional and outside the bootstrap | [docs/STDLIB.md](docs/STDLIB.md), `./sx target test-network` (optional) |
| 5 | **Package transport & key distribution** | Asymmetric Curve25519 package (`pubsig=`) and index (`INDEX.sig`) verification work offline against pinned `.sayanox/trusted_keys`; online key discovery/CA infrastructure does not exist, and HTTP transport still shells out to `curl`/`wget` | [docs/REGISTRY.md](docs/REGISTRY.md) |
| 6 | **An IDE-complete LSP** | `hover`, `definition`, and `signatureHelp` now infer static types and resolve across `use "..."` and indexed workspace `.sa` files, but the server is still a line/brace-oriented analyzer rather than the full compiler front end: 4 open buffers, 128 indexed files, 256 KiB each, no incremental text sync, and no workspace-wide diagnostic push | [docs/LSP.md](docs/LSP.md) — "still not IDE-complete" |
| 7 | **Full ARM64/RV64GC native compiler/runtime** | `tools/native32.sa` currently emits integer expressions, static string spans, `len`, byte indexing and bounded variable-to-variable `concat` for i386/AArch64/RV64IM, with six-way execution parity; `sxisaexec` also has emulator-only scalar-FP and file-syscall probes. General strings, lists, structs, user functions, FP code generation, file I/O runtime, GC, and broad RV64GC/AArch64 coverage remain open. | [docs/NATIVE32.md](docs/NATIVE32.md), [docs/NATIVE_IR.md](docs/NATIVE_IR.md) |
| 8 | **Namespacing in the language** | `sxmod` is a source-to-source pass. The dialect still has shared declaration tables and no module identity, private visibility, nesting, search paths or import cache. Not planned in the bootstrap compiler | [docs/MODULES.md](docs/MODULES.md) |
| 9 | **`.sa` on GitHub** | Not registered in github-linguist, so GitHub may not show a Sayanox language bar even after C source retirement. The upstream contribution is prepared but not opened (Linguist wants demonstrated in-the-wild usage) | [docs/LINGUIST.md](docs/LINGUIST.md) |
| 10 | **Platforms and registry growth** | x86-64 Linux (plus i386 integer subset and portable IR VM) is executed; the package registry is local; the stdlib is twenty-one `.sa` modules, including `csv.sa`, `url.sa`, `datetime.sa` and `hash.sa` | roadmap below |

### What is deliberately refused

These produce an **error**, not a wrong answer, and gates require the error: a
*concrete* struct name as a generic type argument, an unknown type name, an
escaped type parameter, a wrong type-argument count, gen2 `push(p.xs, v)` and
whole-list `show p.xs`, every late builtin on seed-min and native, and the
tested out-of-subset language forms. `./sx target true-selfhost-full` still refuses an unreviewed exhaustive full-language claim.
`./sx target all-sayanox` audits maintained source and the explicit native binary trust boundary; it does not replace CI.

---

## Sayanox-written Tools

```sh
./sx target tools

./tools/sxfmt input.sa formatted.sa     # formatter
./tools/sxpkg init                      # package manager
./tools/sxpkg add math 0.1.0
./tools/sxpkg list
```

The formatter currently handles whitespace. The package tool is one Sayanox
program, `tools/sxpkg.sa` (built to `./tools/sxpkg` by `./sx target sxpkg`): `init`,
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
path needs bash, awk, sed or Python (`./sx target test-language-deps`). Driving
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
| `selfhost/seed/sxc_seed_min.sa` | Sayanox compatibility CLI; the shared Sayanox frontend emits C using the bounded runtime profile |
| `selfhost/native_aot.sa` | Self-hosted x86-64 Linux native-AOT backend in Sayanox (`selfhost/native_aot.c` deleted) |
| `tools/sx{enc,infer,data,emit,runtime,gc,link,pipeline}_lib.sa` | Shared Sayanox native backend libraries (encoder, phase-2 inference, data/string pools, emit tree, runtime, mark & sweep GC, ELF64 linker, pipeline) |
| `tools/sxbuild.sa` | Sayanox build/bootstrap/parity/tool driver (`doctor`, `inventory`, `build`, `native`, `tool`, `parity`, `bootstrap`) |
| `tools/sxstage2_parity.sa` | Sayanox Stage-2 native parity harness (struct-typed `make` + `${id}` interpolation) |
| `tools/sxirexec.sa` | Sayanox Portable IR virtual machine and 4-backend parity runner (`emit_to_ir` execution) |
| `tools/native32.sa` | Sayanox i386 / AArch64 / RV64IM ELF emitter (integer, static strings, `len`, bounded `concat`) |
| `tools/sxmod.sa` | Sayanox module-namespacing pass (`module` / `alias.member`) |
| `tools/sxaudit.sa` | Sayanox binary/source byte-count and SHA-256 auditor; native-anchor digest pinned in `bootstrap/sxc_native.audit` |
| `tools/sxdiag.sa` | Sayanox negative-diagnostic suites (replaced four `sh` drivers) |
| `stdlib/` | Twenty-one Sayanox modules, including `json_deep.sa`, `json_write.sa`, `crypto.sa`, `pubkey.sa`, `csv.sa`, `url.sa`, `datetime.sa`, and `hash.sa` |
| `sx`, `tools/sxbuild.sa` | Native entry and Sayanox bootstrap/build/test driver; incomplete acceptance migration |
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
seed; the native backend and build driver are Sayanox, and the old build file and tracked shell scripts have been deleted. A
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

- [x] Self-hosting pure-min dialect (`./sx target true-selfhost`, `./sx target gen3`)
- [x] Native AOT subset (x86-64 Linux) (`./sx target native-test`)
- [x] Formatter + local package tool in Sayanox, with digests and keyed signatures
- [x] Language server in Sayanox, with binder-based resolve, folder rename and file watching
- [x] Toolchain free of bash, awk, sed and Python (`./sx target test-language-deps`)
- [x] A collector in the bootstrap seed (strings) (`./sx target test-seed-collector`)
- [x] Nested generic structs on all three backends (`./sx target test-generic-structs-nested`)
- [x] Nested JSON reader and SHA-256/HMAC-SHA256 in the stdlib
- [x] Multi-ISA Sayanox emitter for i386/AArch64/RV64IM with integer, static-string, byte-indexing and bounded-concat subset; AArch64/RV64 output executes under `sxisaexec`
- [x] Module namespacing one layer out (`./sx target test-sxmod`)
- [x] Native anchor pinned and audited; frozen C seed retired (`./sx target test-trust-anchor`)
- [x] **Native AOT backend completely in Sayanox (Phase D steps 1–10)**: `selfhost/native_aot.sa` + `tools/sx*_lib.sa` replaced and deleted `selfhost/native_aot.c` (`./sx target test-native-sxemit`, `./sx target native-test`)
- [x] **Sayanox build/bootstrap/parity driver** (`tools/sxbuild.sa`, `./sx target test-sxbuild`)
- [x] **Stage-2 native parity**: concrete struct-typed `make` functions and `${id}` interpolation on `native_aot` (`./sx target test-native-stage2-parity`)
- [x] **Portable IR virtual machine**: `tools/sxirexec.sa` executes `emit_to_ir` portable IR with 4-way parity (`./sx target test-ir-exec`)
- [x] **Public-key package signatures & signed registry index**: Curve25519 Schnorr-SHA256 in `stdlib/pubkey.sa` + `tools/sxpkg.sa` (`./sx target test-sxpkg-pubkey`)
- [x] **LSP type-level hover, module IDE, multiline `signatureHelp`, block scope & `prepareRename`** (`tools/sayanox_lsp.sa`, `./sx target test-lsp-types`, `./sx target test-lsp-ide`)
- [x] **C-free self-compiling x86-64 ELF64 compiler & toolchain (`tools/sxc_native.sa`) + zero non-anchor C/H files** (`./sx target test-sxc-native`, `./sx target test-trust-anchor`)
- [x] **Pure-Sayanox compiler test suite runner (`tools/sxsuite.sa`)** (`./sx target test-sxsuite`)
- [x] **User-mode ARM64 & RISC-V 64 ELF64 instruction emulator with 6-way parity (`tools/sxisaexec.sa`)** (`./sx target test-sxisaexec`)
- [x] **Transitive multi-directory `module` DAG resolution (`tools/sxmod_lib.sa`)** (`./sx target test-sxmod-deep`)
- [x] **Sayanox CI/CD orchestration** — all 236 original target names ported; complete guarded local CI, no-Make driver integration and release-plan acceptance passed. No remote workflow run or release publication is claimed
- [x] **Portable stdlib data & time batch** — `csv.sa` (rows), `url.sa` (percent-encoding + query strings), `datetime.sa` (Gregorian calendar / JDN), `hash.sa` (rolling hashes, Adler-32, Luhn); 150 oracle-pinned values on seed-min == gen2 == native (`./sx target test-stdlib-csv`, `./sx target test-stdlib-next`)
- [x] **Extended 5-backend standard library (`map`, `sort`, `path`, `cli`, `bytes`)** (`./sx target test-stdlib-extended`)
- [x] **Port the remaining 14 tracked POSIX `.sh` scripts to Sayanox**: `sxsuite`, LSP protocol probes, package-transfer security harness, local HTTP/crawler tests, and `sxpack`; `git ls-files '*.sh'` is now empty (`./sx target test-language-deps`, `./sx target test-trust-anchor`)
- [x] **All maintained implementation source is Sayanox** ([evidence](docs/ALL_SAYANOX_PHASE.md)); the frozen C seed and Makefile are retired. Native-origin own-source fixed point and 64 MiB C1 emission pass. Final guarded acceptance is tracked separately.
- [ ] Full Stage-2 language self-hosting in `seed-min` bootstrap (`./sx target true-selfhost-full` fails closed)
- [ ] Full ARM64/RV64 native compiler/runtime beyond the integer subset (strings, lists, structs, `make`/`give`, floats, file I/O, GC); emulator FP/syscall coverage is in progress (`docs/ALL_SAYANOX_PHASE.md`)
- [ ] Broader platform support

### Maintained source and acceptance

The compiler, native backend, compatibility frontend/runtime templates, tools,
build/bootstrap/dependency/cleanup/recovery logic, tests, audits, CI guards and
release implementation are Sayanox. All 236 original target names remain
implemented. There is no maintained C seed, Makefile or shell script.
Necessary host tools and generated C compatibility output remain supported.

The pinned native compiler and generated entry are explicit binary trust inputs,
not independent source-trust proof. Native-origin C2 == C3 and complete C1
emission under 64 MiB pass. Final guarded acceptance status is recorded in
[the migration report](docs/MAKEFILE_MIGRATION.md); registration or file removal
alone is not substituted for that full run.

All ten steps of Phase D are complete and verified:

| Phase D | Piece | State |
|---|---|---|
| ~~step 1~~ (2026-10-18) | byte buffers, `bit_*`, `shl`/`shr`, `write_bytes`, `bytes_f64` | done, `test-native-primitives` |
| ~~step 2~~ (2026-10-20) | `read_bytes`, the binary reader the buffers were missing | done, `test-read-bytes` |
| ~~step 3~~ (2026-10-20) | `tools/sxlink.sa` — ELF image writer + rel32 linker (`SX_LINK_DUMP`) | done, `test-native-sxlink` |
| ~~step 4~~ (2026-10-21) | `tools/sxencode.sa` — the x86-64 encoder (`SX_ENCODE_LOG`) | done, `test-native-sxencode` |
| ~~step 5~~ (2026-10-23) | `tools/sxdefs.sa` — front-end phase 1, the `use` splice and the definition tables (`SX_DEFS_DUMP`) | done, `test-native-sxdefs` |
| ~~step 6~~ (2026-10-24) | `tools/sxinfer.sa` — phase-2 kind inference: `pk_*`, 16-round fixpoint, generic struct & function instantiation | done, `test-native-sxinfer` |
| ~~step 7~~ (2026-10-24) | `tools/sxemit_lib.sa` + `tools/sxdata_lib.sa` + `tools/sxemit.sa` — the full x86-64 emit tree inside `EMIT-SEAM` | done, `test-native-sxemit`, `test-native-emit-split` |
| ~~step 8~~ (2026-10-24) | `tools/sxruntime.sa` — the 856-line emitted x86-64 runtime (24 routines, 3,521 bytes) | done, `test-native-sxruntime` |
| ~~step 9~~ (2026-10-24) | `tools/sxgc.sa` — the 339-line x86-64 mark & sweep collector (6 routines, 1,209 bytes) | done, `test-native-sxgc` |
| ~~step 10~~ (2026-10-24) | `selfhost/native_aot.sa` + `tools/sxpipeline_lib.sa` — Sayanox backend wired as sole producer; `selfhost/native_aot.c` deleted | done, `./sx target native-test` |

Earlier moves on the same path: on 2026-10-17 the 150-line C IR translator
became `tools/emit_to_ir.sa` with byte-identical output, the LSP folder index
moved into Sayanox (the C directory header and its binder were deleted), the
127-line C framed-session test client became `tools/lsp_workspace_test.sa`, and
ten unreferenced legacy C files were removed. Phase E — the seed — stays with
**option 2**, one pinned and audited C anchor (`./sx target test-trust-anchor`), until
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
./sx doctor
./sx target true-selfhost
./sx target native-test
```

A change lands with the gate that proves it: add a `./sx target test-*` target, keep
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
