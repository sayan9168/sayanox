# Dependency audit — bootstrap critical path

Audited 2026-10-04, re-measured end-to-end 2026-10-06 on branch
`arena/2863bc8a-sayanox` (base `e7e8bdc`). The re-measurement reproduced the
numbers below and added `make doctor` and `make restore-compiler` to the table.
Re-measured again 2026-10-07 at commit `280947f` on branch
`arena/dabcdd33-sayanox` (minimal-`PATH` clean clone, see "Headline" below).

Every number in this file was measured, not estimated. The method: a PATH shim
directory was built containing a logging wrapper for all 644 executables in
`/usr/bin`, `/bin` and `/usr/local/bin`. Each `make` target was then run with
`PATH=/tmp/shim:$PATH`, so the log is a complete record of every external
command that target actually executed. Nothing was inferred from reading the
Makefile.

`/bin/sh` on the audit host is **dash**, so every recipe line was executed by a
strict POSIX shell, not bash.

## Headline

| Target | external commands BEFORE | external commands AFTER |
|--------|--------------------------|--------------------------|
| `make true-selfhost` | `as base64 cat cc cmp diff grep gzip ld make mkdir sed tr wc` (14) | `as cc cmp grep ld make mkdir` (7) |
| `make gen3` | `as cc cmp grep ld make mkdir sed wc` (9) | `as cc cmp ld make mkdir` (6) |
| `make native-test` | `as cc grep ld make mkdir sed` (7) | `as cc grep ld make mkdir` (6) |
| `make doctor` | (did not exist) | `make` (1) |
| `make restore-compiler` (source present) | — | `make grep` (2) |
| `make restore-compiler` (source missing) | — | `make grep cat tr base64 gzip rm` (7) |

`as` and `ld` are not direct dependencies — they are invoked internally by the C
compiler. Removing them from the count, the direct tool set for
`make true-selfhost` went from 12 tools to 5.

Re-verified 2026-10-06, and each of the three "retained" assert tools was proved
*necessary* by removing it from `PATH` one at a time:

| Missing tool | Target | Result |
|--------------|--------|--------|
| `cmp` | `make gen3` | exit 2 — `cmp` is the `gen3 == gen4` fixed point |
| `grep` | `make true-selfhost` | exit 2 (6 `not found` lines) — generated-C markers |
| `mkdir` | `make seed-min-gen1` | exit 127 — the scratch test directory |

The positive side of the same experiment: with a `PATH` containing only
`make cc gcc as ld sh grep cmp mkdir`, `make true-selfhost`, `make gen3` and
`make native-test` all exit 0 (`=== *-OK ===`). Nothing else is consulted.

**Re-measured 2026-10-07** on a fresh `git clone` of commit `280947f`, with
`PATH` set to a directory holding only symlinks to `make cc gcc as ld sh grep
cmp mkdir` (`/bin/sh` = dash):

| Target | exit | last line | `not found` lines |
|--------|------|-----------|-------------------|
| `make doctor` | 0 | `DOCTOR-OK: minimal tool set is complete` | 0 |
| `make true-selfhost` | 0 | `=== TRUE-SELFHOST-MIN-OK ===` | 0 |
| `make gen3` | 0 | `=== GEN3-OK ===` | 0 |
| `make native-test` | 0 | `=== NATIVE-TEST-OK ===` | 0 |

`git status --short` in the clone was empty afterwards: no untracked artifacts
outside the ignored scratch directories.

**Host requirement of `make native-test`:** `native_aot` writes x86-64 machine
code into a static Linux ELF executable and uses Linux system calls directly,
so `native-test` needs an **x86-64 Linux** host (as `ubuntu-latest` is). The
C99 compiler, the POSIX shell and the three assert tools are the same as for
the other targets; nothing more is installed. `true-selfhost` and `gen3` emit
portable C and have no such restriction.

Removed from the critical path entirely: **`sed`, `awk`, `diff`, `wc`, `cat`,
`tr`, `base64`, `gzip`**.

## 1. What each stage actually requires

| Stage | External tools | Verdict |
|-------|----------------|---------|
| `restore-compiler` (normal case) | `make`, `grep` | **required** |
| `restore-compiler` (fallback: `compiler_min.sa` missing) | `make`, `grep`, `cat`, `tr`, `base64`, `gzip`, `rm` | `base64`/`gzip`/`cat`/`tr`/`rm` **optional** |
| `verify-seed` (was `fix-seed`) | `make`, `grep` | **required** |
| build `sxc_seed_min` | `make`, `cc` (+ `as`, `ld`) | **required** |
| `seed-min-gen1` | `make`, `cc`, `grep`, `mkdir` | **required** |
| `true-selfhost` | `make`, `cc`, `cmp`, `grep`, `mkdir` | **required** |
| `gen3` | `make`, `cc`, `cmp`, `mkdir` | **required** |
| `native-test` | `make`, `cc`, `grep`, `mkdir` | **required** |
| tests (all `test-*` targets) | `make`, `cc`, `grep`, `cmp`, `mkdir` | **required** |
| `doctor` | `make` | **required** |

### Final minimal tool set

```
make            required
a C99 compiler  required   (cc, clang or gcc — auto-detected)
a POSIX shell   required   (any; recipes are dash-clean)
grep            required   (assertions on generated .c source and on the text
                            of expected compiler/runtime error messages)
cmp             required   (gen3 == gen4 fixed-point, seed-min/gen2 parity)
mkdir           required   (scratch test directory)
base64          optional   (only the offline compiler_min.sa fallback)
gzip            optional   (only the offline compiler_min.sa fallback)
```

`make doctor` checks exactly this list and prints OK/FAIL per tool.

## 2. Interpreted languages: none

Measured across every target above: **no Python, Node, Ruby or Perl process is
ever started.** There are also no `.py`, `.rb`, `.js`, `.ts`, `.pl` or `.lua`
files tracked in the repository at all (`git ls-files` checked).

`make doctor` reports Python and Node as "present, but NOT used anywhere on the
bootstrap path" on hosts that have them, and "absent - fine, nothing needs it"
on hosts that do not.

Re-measured 2026-10-06 across the full logs of `make doctor`,
`make true-selfhost`, `make gen3`, `make native-test`, `make restore-compiler`
and every `test-*` target: **zero** invocations of `python`, `python3`, `node`,
`ruby`, `perl`, `php`, `bash`, `curl`, `wget` or `git`. `git ls-files` still
shows 0 tracked `.py`/`.rb`/`.js`/`.ts`/`.pl`/`.lua`/`.php` files.

## 3. Shell scripts

No `.sh` file is on the critical path. Measured: **`bash` is never executed by
`make true-selfhost`, `make gen3`, `make native-test` or any test target.** All
recipe lines run under the POSIX shell.

| Script | Shebang | Reachable from a required target? | Verdict |
|--------|---------|-----------------------------------|---------|
| `selfhost/pack_compiler_min.sh` | `#!/bin/bash` (`mktemp`, `awk`, `xargs`, process substitution) | No — only `make pack-compiler` (manual maintenance) | optional |
| `selfhost/lang_quality.sh` | `#!/usr/bin/env bash` | No | optional |
| `selfhost/restore_compiler_min.sh` | `#!/usr/bin/env bash` | No — superseded by `make restore-compiler` | removable |
| `selfhost/restore_stage2.sh` | `#!/usr/bin/env bash` | No | removable |
| `selfhost/restore_stage2_template.sh` | `#!/bin/sh` | No | removable |
| `selfhost/restore_sxc.sh` | `#!/bin/sh` | No | removable |
| `selfhost/restore_sxc_full.sh` | `#!/usr/bin/env bash` | No | removable |
| `tools/sayanox-lsp.sh` | `#!/bin/sh` | No — editor tooling | optional |
| `tools/sxpkg.sh` | `#!/bin/sh` | No — package manager | optional |

The five `restore_*.sh` scripts duplicate what Makefile targets now do and are
not referenced by the Makefile; they are candidates for deletion but were left
in place as they are outside the critical path.

## 4. Network

**None on the bootstrap path.** Measured: `curl` and `wget` are never executed.

The only network-capable file is `tools/sxpkg.sh`, an optional package manager
that is not invoked by any Makefile target. It honours a
`SAYANOX_REGISTRY` override.

`make restore-compiler` works fully offline. Verified by deleting
`selfhost/compiler_min.sa` and re-running with the shim: the only external
commands used were `base64 cat grep gzip make rm tr`, and the reconstructed file
was **byte-identical** to the original. Re-verified 2026-10-07 after
`compiler_min.sa` grew (new features and error checks): sha256
`ffa45c2d0e122c6caa59c834547b4d2e1537cfcde307ca82d3bd9d074c3fca02`, 239782
bytes, 40 parts of 1100 chars, round-trip byte-identical. (The 2026-10-06
figures, sha256 `aa5ff5ad…` and 33 parts, describe the older source.) The parts are regenerated by `make pack-compiler`, which is the
only thing in the repository that needs `bash`/`awk`/`gzip`/`base64`, and it is
a manual maintenance target — `make restore-compiler` never needs to run it.

## 5. sed / awk "fix-seed" hacks — removed

`fix-seed` used to run ~20 lines of `awk` and `sed -i` that rewrote the seed
sources in place before every build. **Every one of those edits was dead code.**

* The `awk` guard grepped for `ptok(k,(const char*)#ch`. Interpreted as a BRE,
  `r*` means "zero or more `r`", so that pattern can never match the literal
  text `ptok(k,(const char*)#ch` in `sxc_seed.c`. Verified directly:
  `grep -q 'ptok(k,(const char*)#ch' selfhost/seed/sxc_seed.c` returns
  non-zero. The `awk` body never ran. The rewrite was also unnecessary — `P1`
  is only instantiated with single-character punctuation literals, so `#ch`
  already stringizes correctly, and the file compiles as checked in.
* All six `sed -i` guards searched for pre-fix text that is absent from the
  checked-in `sx_runtime.h`. Verified: the five "fixed" markers are present
  (2, 1, 1, 1 and 2 hits) and all four "broken" markers return 0 hits. Running
  the old `fix-seed` left both files with unchanged sha256.

It is replaced by `verify-seed`, a read-only assertion using only `grep` and
`test`. A stale checkout now fails loudly instead of having tracked files
silently rewritten. `fix-seed` is kept as an alias so existing invocations keep
working. This satisfies "prefer checked-in correct sources over runtime
patching", and the target is trivially idempotent because it never writes.

## 6. Test assertions no longer use sed

~40 uses of `... | sed -n Np` line extraction were replaced by a single
pure-shell helper:

```make
assert-out = @__got=$$($(1)); __want=$$(printf '%b' '$(2)'); \
  if [ "$$__got" = "$$__want" ]; then :; else \
    echo "[FAIL] $(1): stdout does not match"; \
    echo "--- want ---"; printf '%s\n' "$$__want"; \
    echo "--- got ---";  printf '%s\n' "$$__got"; exit 1; fi
```

It uses only command substitution, parameter expansion, `printf` and `test` —
all shell builtins. Two non-obvious points found while prototyping it:

* `%%` is **not** unescaped inside a make variable expanded into a recipe, so
  the format string is written `%s`, not `%%s`.
* `printf '-42'` fails as an illegal option. The expected value is therefore
  passed through `printf '%b' '...'`, which also interprets the `\n`
  separators. `native_negative` (which prints `-42`) is the case that exposed
  this.

These assertions are **stricter** than what they replaced. `sed -n 1p` checked
one line and ignored everything else; an exact full-output match now fails on a
spurious extra line. That caught a real gap: `gc-test` previously only checked
that `gc-rc-ok` was printed, and passed regardless of the value on the line
above it. It now pins `2005`, which is the 5 characters of `"start"` plus the
2000 appends in `rc_runtime_stress.c`.

`diff` was replaced by `cmp`, which the Makefile already required for the
`gen3 == gen4` fixed-point check, so it removes a tool rather than adding one.

`grep` remains, but only for its idiomatic job — asserting that a *generated C
file* contains or does not contain a marker (`#error`, a `typedef`, the
`(double)((long)(a)%(long)(b))` lowering), or that a compiler rejected a program
with the *right* message (for example gen2's `'n' is not a string`, or the
native runtime's `division by zero`). All 13 remaining `grep` calls that
checked *program output* were converted to `assert-out`.

## 7. Pre-existing problems found, not fixed

Reported rather than silently changed, since they are outside this task.

### The legacy `seed-bin` chain does not compile

`make subset`, `make gen1`, `make gen2` and `make true-selfhost-full` **fail on
the base commit too** (exit 2, before and after this change). The self-hosted
`sxc_seed` emits C that uses `va_list`/`va_arg`, but the generated file never
includes `<stdarg.h>`:

```
selfhost/_smoke.c:17:49: warning: implicit declaration of function 'va_start'
selfhost/_smoke.c:17:141: error: expected expression before 'double'
```

Re-measured 2026-10-06: the four targets still fail on the current tree, and the
error has moved one stage further. `make subset` now dies in the generated
smoke program (`selfhost/_smoke.c:17:141: error: expected expression before
'double'`) and `make gen1`, `make gen2` and `make true-selfhost-full` all die in
the legacy self-hosted `sxc_seed` with
`selfhost/compiler_min.sa:543:18: semantic error: undefined function 'sx_eq'`
(the legacy compiler predates the `sx_eq` builtin that `compiler_min.sa` uses).
These are pre-existing and untouched by this pass.

`make gen3` is **not** affected: it uses the `gen2` that `true-selfhost-min`
builds from `compiler_min.sa`, not this chain. CI does not run `subset`,
`gen1`, `gen2` or `true-selfhost-full`. Fixing the chain means teaching the
legacy `sxc_seed` the missing builtins (or dropping the chain); it was not
attempted here.

### `make clean` deleted a tracked binary — fixed 2026-10-06

`selfhost/seed/sxc_seed` is a checked-in binary and `clean:` used to run
`rm -f $(SEED_BIN)`, so a build-then-clean cycle left a deleted-but-committed
file in the working tree. `clean:` no longer touches it: it removes only
generated artifacts (`gen1*`, `gen2*`, `gen3*`, `gen4.c`, `sxc_seed_min`,
`native_aot`, the `boot_from_gen2*` scratch programs). `selfhost/seed/sxc_seed`
is rebuilt from `sxc_seed.c` by the `.PHONY` target `make seed-bin` whenever it
is needed, so untracking it later stays an option.

### `restore-compiler` could overwrite a good source — fixed 2026-10-06

The fallback decoded the blob straight into `selfhost/compiler_min.sa` and only
then ran its marker checks. With `grep` missing from `PATH` the checks fail
*after* the file has been replaced, so an out-of-date blob silently downgraded a
newer `compiler_min.sa`. Now the decode goes to `compiler_min.sa.tmp`, every
check runs against the temp file, and only a fully verified decode is copied
over the real file (`.tmp` is removed on every failure path). Verified: with
`grep` absent the target exits 2 and the sha256 of the existing source is
unchanged; with a deliberately corrupted `00.b64` and no source file present,
the target exits 2 and creates no file and no stray `.tmp`.

## 8. Reproducing this audit

```bash
make doctor          # === DOCTOR-OK ===, tool table
make true-selfhost   # === TRUE-SELFHOST-MIN-OK ===
make gen3            # === GEN3-OK ===, [OK] byte-identical gen3 == gen4
make native-test     # === NATIVE-TEST-OK ===
```

Measured 2026-10-06 on this host (3939 MB RAM, 2 CPUs, `/bin/sh` = dash) from a
clean tree. On 2026-10-07, with the larger test suite, the minimal-`PATH` clean
clone took 18.9 s (`true-selfhost`), 11.4 s (`gen3`) and 2.4 s (`native-test`);
peak RSS was not re-measured.

| Step | Wall time | Peak RSS (VmHWM) |
|------|-----------|------------------|
| `make true-selfhost` | 11.9 s | seed-min 1.5 MB, gen1_min 29 MB, gen2 75 MB |
| `make gen3` | 7.4 s | 75 MB (gen2 compiling `compiler_min.sa`) |
| `make native-test` | 0.2 s | — |

No step comes near the OOM killer: `gen2` still produces byte-identical output
under `ulimit -v 400000` (a 400 MB address-space cap).

To re-measure the external command set yourself, put logging wrappers for your
`PATH` earlier in `PATH` and diff the resulting invocation log against the
tables above.
