# 2026-10-19 — the signature pre-pass learns about `//` comments

Cut #10 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

## What changed

While porting `tools/sxpkg.sa` (cut #9) the generated `tools/sxpkg.c` stopped
compiling. The cause was not in the port: the compiler's `make` signature
pre-pass scans the whole file for `make` at the start of a line while tracking
string literals, and its comment-tracking branch is dead code — the `fscm`
flag is declared but never set to 1. So a double quote inside a `//` comment
toggled string mode.

One odd quote makes the pre-pass treat the rest of the file as one string
literal. Every later `make` is missed, each of those functions falls back to
the raw parameter parse, and that parse reads `a: num, b: num` as *four*
untyped parameters instead of two typed ones:

```
static double add2(double a, double num, double b, double num);
   ^ the mangled form, from a compiler with the fix reverted
```

plus `#error sayanox-min: unknown function: add2` and, for the recursive ones,
a forward declaration that never matches the definition. It fails at build
time, so it is loud, but the cause is invisible in the `.sa` source.

The real lexer already understood `//` — three separate places in
`selfhost/compiler_min.sa` skip a line comment, and one of them explicitly
notes that "a `/` that starts a `//` comment is not division". Only the
signature pre-pass did not. It now does the same thing: on `//` it sets the
comment flag and jumps past both slashes, and the existing (previously
unreachable) comment branch runs it to the end of the line.

| file | before | after |
|---|---:|---:|
| `selfhost/compiler_min.sa` | 19,527 lines | 19,540 lines |
| `Makefile` | 4,790 lines | 4,828 lines (new gate + two gate lists) |

No new builtin, no new statement, no change to the language surface. This is a
bug fix in code that is already Sayanox.

## The proof that the gate is worth having

A gate that passes on both the broken and the fixed compiler proves nothing,
so the fix was reverted into a second binary and the same fixture compiled
with both:

```
$ /tmp/gen2_old odd.sa odd_old.c        # fix reverted
min: unknown function: add2
$ grep add2 odd_old.c
202:static double add2(double a, double num, double b, double num);
203:static double add2(double a, double num, double b, double num) {
$ cc -O2 -o odd_old odd_old.c
odd_old.c:202:59: error: redefinition of parameter 'num'
odd_old.c:217:14: error: too few arguments to function 'add2'

$ ./selfhost/gen2 odd.sa odd.c          # fix applied
$ grep add2 odd.c
201:static double add2(double a, double b);
202:static double add2(double a, double b) {
$ ./odd
3
```

## Gates (all exit 0)

The whole suite below was one `make` invocation, so `gen2` was rebuilt once and
every gate ran against the same binaries; `full-suite.log` is that run in full
(2,532 lines, `SUITE_EXIT=2`) and each gate's slice is also kept separately.
`SUITE_EXIT` is 2 and not 0 only because `all-sayanox` is in the batch and
fails on purpose. `gen3` was run afterwards against the same `gen2`
(`gen3.log`), ending in `=== GEN3-OK ===` and `[OK] byte-identical gen3 ==
gen4`.

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost-min` — `=== TRUE-SELFHOST-MIN-OK ===`
  (`true-selfhost.log`); the new gate is inside it through the `test-stage2`
  chain
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-native-primitives` — `[OK] native primitives: ...`
  (`native-primitives.log`)
- **`make test-comment-quotes` — the new gate** (`comment-quotes.log`):

  ```
  static double add2(double a, double b);
  static char *toml_field(char *text, char *key);
  [OK] a double quote inside a // comment no longer breaks the signature pre-pass; gen2 and seed-min agree
  ```

  It pins, from both ends:
  - a fixture whose comment carries **one** quote must still compile to
    `static double add2(double a, double b);`, must build with
    `-Werror=implicit-function-declaration`, and must print `3`;
  - the generated C must contain neither a mangled `double str,` /
    `double str)` parameter nor the naive scanner's `double num`;
  - `tools/sxpkg.sa` — the file that exposed the bug — must still compile to a
    typed `static char *toml_field(char *text, char *key);` with no mangled
    parameter list;
  - seed-min, which runs its own pre-pass, must agree on the same fixture.
- The five sxpkg gates, **unchanged and still green** — the acceptance test
  for cut #9, re-run because this cut rebuilds the compiler every one of them
  depends on: `test-sxpkg.log`, `test-sxpkg-wrapper.log`,
  `test-sxpkg-polish.log`, `test-sxpkg-online-local.log`,
  `test-sxpkg-transfer-hardening.log`, `test-sxpkg-online-optin.log`
- `make test-sxpkg-sayanox-logic` — cut #9's gate, still green
  (`test-sxpkg-sayanox-logic.log`)
- `make test-proc-builtins`, `make test-path-builtins`,
  `make test-exit-builtin`, `make test-language-deps`, `make test-doc-claims`
  — unchanged and still green (`proc-builtins.log`, `path-builtins.log`,
  `exit-builtin.log`, `language-deps.log`, `doc-claims.log`)

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`). The
  inventory it prints now reads 279 `.sa` files, 4,828 Makefile lines and
  still lists the seed, the native backend and the build driver.

## Honest limits

- **This cut changes the compiler, so every gate above had to be re-run, not
  just the new one.** The compiler is the one file where a "small" change can
  move a long list of generated C files; the full suite is the evidence.
- **The pre-pass fix is deliberately narrow.** It recognises `//` and stops at
  the end of the line. It does not add block comments, does not teach the
  naive parameter scanner to skip a type annotation, and does not make the
  scanner unreachable in general — the pre-pass now simply records the
  signature it was always meant to record. The naive scanner is still there.
- **A comment with an odd number of quotes is now harmless, but a comment that
  is not a comment is not.** If a future edit puts `//` inside a string
  literal, the pre-pass is inside string mode and will not treat it as a
  comment, which is correct.
- `gen3 == gen4` byte identity still holds, so the fix is a fixed point of the
  bootstrap: the compiler that gen2 produces from itself is unchanged.
- Nothing here is a language-surface claim. `docs/BUILTINS.md` records the bug
  and the fix in the same section as the string-comparison limitation, which
  is still open.
