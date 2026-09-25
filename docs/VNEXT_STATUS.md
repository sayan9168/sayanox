# Sayanox vNext — Repository Audit & Status (Phase 1)

Date: 2026-09-25. This audit was produced by inspecting the actual code,
not by trusting `docs/STATUS.md`. Every claim below was verified with the
commands listed in "Exact test commands".

## Current architecture (as found)

| Component | File(s) | Reality |
|---|---|---|
| Seed compiler ("sxc_full") | `selfhost/sxc_full.c` (30 lines) | Minimal C subset compiler: only `hold x = NUMBER`, `show NAME`, `show "string"`. It does **not** contain `sx_chr` or any of the runtime helpers the scripts grep for. |
| Pure-Sayanox mini compiler | `selfhost/compiler_min.sa` (350 lines) | Hand-written `.sa` scanner/codegen for the same tiny subset. Uses builtins `arg_count arg read_file len sx_index chr concat str write_file show hold when while give`. |
| Larger .sa compiler sources | `selfhost/compiler.sa lexer.sa parser.sa codegen.sa ...` | Written against a **richer builtin set that no binary in this repo implements** (`list_get push string_len make`). They are not wired into any build/test path. |
| Native AOT | `selfhost/native_aot.c` (90 lines) | Linux x86-64 ELF emitter, but it **interprets** `.sa` at compile time and emits the output bytes as a static `write()` blob. Supports `hold/show/when/while` on integers only. No functions, lists, strings-as-values, calls. |
| Runtime | `selfhost/rc_runtime.h` | Tiny refcounted-string header (`sx_rc_new/retain/release/concat`). Not linked from any working pipeline; most generated C uses plain doubles/puts. |
| CLI | `selfhost/sx` (bash), `tools/sxpkg.sh`, `tools/sayanox-lsp.sh` | Bash wrappers around nonexistent binaries in most paths. |
| CI | `.github/workflows/ci.yml` | Contains `|| echo "skip"` soft-failures everywhere; pure-gen2 step is optional and its script fakes Gen2 (see below). |

## Working features (verified)

- `cc -O2 selfhost/sxc_full.c` compiles; seed compiles `hold x = 42 / show x` to C that prints 42.
- `make subset` passes (`SUBSET-SELFHOST-OK`) — but only the smoke part runs; the gen1 path is skipped because the seed lacks `sx_chr`.
- `native_aot` produces a runnable ELF for integer examples (`examples/native_hello.sa` → prints 42).
- `rc_runtime_stress.c` builds and prints `gc-rc-ok` (`make gc-test` passes).

## Fake / broken things found (must be fixed)

1. **Fake Gen2**: `bootstrap_true_pure_gen2.sh` step [4] literally does
   `cp selfhost/gen1.c selfhost/gen2.c` and then prints `TRUE-PURE-GEN2-OK`.
   The emitted `gen2_raw.c` (from gen1 compiling compiler_min.sa) is never
   compiled or checked. This violates the absolute rule of this upgrade.
2. **Seed too weak**: `sxc_full.c` cannot compile `compiler_min.sa`
   (no `arg_count/read_file/len/index/chr/str/write_file`, no expressions,
   no `give`, no blocks). Therefore no genuine generation chain exists today.
3. **CI dishonesty**: `make native-test || echo "native skip"`,
   `make gc-test || echo "rc skip"`, pure-gen2 guarded by greps that can
   never pass, and `restore_sxc_full.sh` references missing files
   (`install_sxc_full.py`, split parts) and falls back silently.
4. **Dead/duplicated artifacts**: dozens of base64/gz/hex chunk directories
   (`codegen_a.b64`, `stage2_blob/`, `native_src/n*.b64`, `sxc_full_lines/`,
   `sxc_out_c/`, ...) restoring files that already exist in plaintext;
   ~60 stage docs describing abandoned architectures.
5. **Docs overclaim**: `README.md` says "make stage2 / make sx" — neither
   target exists in the Makefile. `docs/STATUS.md` claims markers that the
   scripts fake. `gc()` is documented honestly as non-collecting, good,
   but several examples still call it expecting collection.
6. **No conformance suite, no std library, no formatter, no test runner,
   no project tooling** despite docs mentioning them.

## Bootstrap dependencies (actual)

- clang/gcc only to build the seed `sxc_full` and each generated C file.
- Everything above the seed must come from Sayanox-compiled compilers.

## Recommended implementation order (adopted)

1. Phase 1: this audit (`docs/VNEXT_STATUS.md`).
2. Phase 2: real seed compiler `selfhost/seed/sxc_seed.c` (C bootstrap only)
   supporting the full language subset needed to compile a real compiler
   written in Sayanox; genuine Gen1.
3. Phase 3: pure `compiler_min.sa` (Sayanox compiler in Sayanox) + true
   Gen2/Gen3 reproducibility tests (byte-diff + behavioral diff), removing
   the `cp gen1.c gen2.c` fake.
4. Phase 4: scanner/indexing/runtime helpers regression tests.
5. Phase 5-6: language core + type-checked frontend (`src/frontend`) with
   precise diagnostics (file:line:col, category, snippet, caret).
6. Phase 7: module system with cycle detection.
7. Phase 8: memory/ownership runtime + leak/double-release/stress tests.
8. Phase 9: backend-independent IR + textual dump.
9. Phase 10: honest native backend (real compilation, clear diagnostics).
10. Phase 11-13: stdlib, unified CLI (`sayanox`), manifest, formatter, test runner.
11. Phase 14: editor/tooling notes.
12. Phase 15: honest CI (no `|| echo skip`).
13. Phase 16: documentation rewrite + release prep.
