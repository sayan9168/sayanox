# 2026-10-21 — dead wood out, `run_command(cmd)` in

On branch `arena/0c0d6e74-sayanox`. Every log in this directory is the actual
command output; `status.txt` records each gate's exit status.

Two things happened in this pass, and they are the same thing seen from two
sides: the tree stopped carrying copies of itself, and a Sayanox program gained
the ability to drive another program, so four shell drivers could stop being
shell.

## 1. 288 tracked files deleted

Nothing here was deleted to make a gate pass. Each group was read, checked
against every reference in `Makefile`, `tools/*.sh`, `.github/` and the docs,
and removed only when the answer was "nothing reads this".

| group | files | why it was dead |
|---|---:|---|
| base64 chunk directories and loose bundles | 100 | restored files that already exist as plaintext: `native_src/` (59 fragments of `native_aot.c`), `stage2_blob/`, `stage2_src/`, `sxc_full_b64/`, `sxc_full_b64_plain/`, `sxc_full_lines/`, `sxc_sa_parts/`, `sxc_out_c/`, `stage2_template_parts/`, `codegen_{a,b,c,d}.b64`, `codegen.sa.gz.b64`, `sxc.sa.b64`, `sxc_fn.sa.b64`, `stage2_tpl_a.b64`, `stage2_template.c{,.gz}.b64`, `native_aot.c.gz.b64`, `compiler_min.sa.gz.b64{,.p0...p3}` — about 380 KB |
| Stage-2 scaffolding | 9 | `stage2_template.c` (93 bytes, `PLACEHOLDER`), `sxc_full.c` and `sxc_full_minimal.c` (30-line toys), `restore_stage2.sh`, `restore_stage2_template.sh`, `restore_sxc.sh`, `restore_sxc_full.sh`, `selfhost/sx`, `stage2_src/` — restorers whose inputs were already gone, so they could only exit 1 |
| `selfhost/lang_quality.sh` + `examples/lang_quality/` | 5 | drove the same absent host; no target ran it |
| `sayascrape/*.py` and `make test-scrape` | 6 | the last Python in the tree, 738 lines, never on a bootstrap path; `sayascrape/crawl.sa` is the crawler and `test-sayacrawl` still tests it |
| abandoned documents | 51 | the `docs/STAGE5..STAGE28` sequence, `ABC_COMPLETE`, `UNIFIED`, `SXC_*`, `SELFHOST_*`, `PURE_SA`, `SHELL`, `SAYANOXC`, `RUST_OPTIONAL`, `CRANELIFT`, `parser-spec`/`PARSER_SPEC`, `BOOTSTRAP_STEP1`, `BOOTSTRAP_NO_C_HOST`, `OWNERSHIP`, and the five `selfhost/*.md` pages that documented the deleted CLI |
| `.sa` demos, stage sketches and examples | 121 | `stage*_*.sa`, `*_demo.sa`, `typecheck`/`typeenv`/`ast`/`semantic`/`lowering`/`ir_*` experiments and 44 examples that no target, test or document names |

The one bundle that is still read stays: `selfhost/compiler_min_gz/` (121
chunks) is the offline copy of `compiler_min.sa` that `make restore-compiler`
falls back to. `.gitattributes` lost the directory rules for the deleted chunk
families and kept the one that still applies.

`test-doc-claims` was rewritten rather than relaxed. It used to assert that
`selfhost/stage2_template.c` **still contained `PLACEHOLDER`** and that
`restore_stage2.sh` **still failed** — i.e. it asserted a file must keep
existing in a particular sorry state. It now asserts those nine paths stay
absent, so a Stage-2 host cannot reappear as a placeholder, and keeps the
banner rule for the three documents that still name the missing entry points.

## 2. `run_command(cmd)`, and four drivers that stopped being shell

`spawn(path)` starts a program with **no arguments**. That is why every driver
that had to say `gen2 in.sa out.c` was still a `.sh` file: not for lack of
language, but for lack of a way to pass arguments.

`run_command(cmd)` closes it: one command line handed to `/bin/sh -c`, the exit
status back as a number, stdout and stderr inherited. It is not called `run`
because `make run()` is a common helper name in these tools and a builtin
shadows a user definition -- the first build of this change failed exactly
there, with `tools/sxlink.sa`'s own zero-argument `run()` rewritten to the
builtin. That is recorded rather than quietly fixed: the name of a builtin is
part of the language surface, and this one had to be chosen against existing
code.

It is wired through the same sixteen sites in `selfhost/compiler_min.sa` as
every other builtin (the return and signature tables, both builtin-name lists,
the argument rewriter, the `fk` classifier and emitter in both passes, the
nested-call operand and argument-word maps, the typed-signature call table, the
in-call name list and the runtime blob), seed-min refuses it like every other
late builtin, and the native backend refuses it too.

The first consumer is `tools/sxdiag.sa`, which replaced four shell drivers:

| deleted | cases | now |
|---|---:|---|
| `selfhost/test_inline_expression_errors.sh` | 23 | `tools/sxdiag inline` |
| `selfhost/test_list_postfix_errors.sh` | 7 | `tools/sxdiag postfix` |
| `selfhost/test_return_paths.sh` | 14 | `tools/sxdiag return` |
| `selfhost/test_name_resolution.sh` | 31 | `tools/sxdiag name` |

The cases used to be quoted C snippets inside a heredoc, checked by `grep -q`
against a generated file. They are now data in a Sayanox program: a `~~`
separated case string, a `write_file`, a `run_command`, a `read_file` and a `contains`.
A new refusal is one more case in that string, not another round of shell
quoting.

`make test-sxdiag` (part of `native-test`) does not just run the four suites —
it also refuses an unknown suite name, refuses to run with no suite, and runs
two **accept-everything controls**: pointed at `/bin/true`, the `return` and
`inline` suites must FAIL. Without that, a suite whose assertions quietly
stopped matching would still print `[OK]`.

## Gate results

This gate was run **twice**, and the first run is part of the record.

The first pass (kept as `first-pass.md`) came back with two red rows, and both
were caused by this change rather than by the tree it inherited:

* `make test-language-deps` failed at `make test-seed-gc` with
  `seed_min: open at 0`. The recipe is `for f in churn grow retain ops tmp` +
  `selfhost/seed_gc_$$f.sa`, so four of the five files are never *named* in the
  `Makefile`; the name search that cleared the deletion batch did not see the
  loop. Restored with `git checkout HEAD -- selfhost/seed_gc_{churn,grow,retain,tmp}.sa`.
* `make native-test` failed to build `tools/sxlink`:
  `selfhost/seed_tests/sxlink.c:525: too few arguments to function 'sx_run'`.
  That is the `run`-is-a-builtin mistake described in section 2 — the builtin
  shadowed `sxlink.sa`'s own zero-argument `make run()`. Renamed to
  `run_command` at all sixteen sites, and the whole chain rebuilt.

The second pass is the table below, from a clean rebuild (`make gen2` before
it, so nothing green came from a stale binary):

| gate | result |
|---|---|
| `make gen2` | ok — `=== GEN2-OK ===` from the seed-built compiler |
| `make doctor` | ok |
| `make test-doc-claims` | ok — 3 legacy documents carry the banner; the deleted placeholders are asserted absent |
| `make test-language-deps` | ok |
| `make gen3` | ok — `=== GEN3-OK ===`, `gen3 == gen4` byte-identical with `run_command` in the compiler |
| `make native-test` | ok — includes `test-native-sxlink`, `test-native-sxencode` and `test-sxdiag` |
| `make test-sxdiag` | ok — 23 / 7 / 14 / 31 refusals, plus the negative controls |
| `make all-sayanox` | still exits 1, as designed — seed 2,035 lines, native backend 4,498, driver 5,170 lines + 15 `sh`, 159 `.sa` |

## What this does not claim

* `selfhost/native_aot.c` (4,498 lines) and `selfhost/seed/sxc_seed_min.c`
  (2,035 lines) are still C, and `Makefile` plus 15 `sh` scripts are still the
  build driver. Those three rows are what `make all-sayanox` keeps printing.
* `run_command(cmd)` is a driver primitive, not a build system: the quoting rules are
  the shell's, and the command lines are built from paths this repository
  controls. It does not make the *Makefile* redundant, and it does not by
  itself move `tools/sxpkg.sh` off curl/wget — that wrapper's remaining shell is
  a policy decision (`test-sxpkg-transfer-hardening`), not an argv limitation.
* The deletions are compared against references, not against intent. Two of
  them (`selfhost/seed_gc_{churn,grow,retain,tmp}.sa`) were restored during
  this pass because `test-seed-gc` reaches them through a `for f in churn grow
  retain ops tmp` loop, which a name search does not see. The gate found it;
  that is the argument for running the gates after deleting, not before.
