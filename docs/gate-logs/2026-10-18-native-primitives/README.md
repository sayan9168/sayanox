# 2026-10-18 — the byte-buffer and bitwise surface for the native backend

Cut #8 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

## What changed

The language gained the eight builtins that `selfhost/native_aot.c` needs
before it can be rewritten in Sayanox:

| new builtin | behaviour |
|---|---|
| `write_bytes(path, xs)` | write a list of numbers as raw bytes; `1` on success, `0` on failure; refuses a value outside `0`-`255` |
| `bytes_f64(xs, v)` | append the 8 little-endian IEEE-754 bytes of `v` to a list |
| `bit_and(a, b)` / `bit_or(a, b)` / `bit_xor(a, b)` | 64-bit bitwise and/or/xor, returned as a number |
| `bit_not(a)` | 64-bit complement, returned as a number |
| `shl(a, n)` / `shr(a, n)` | unsigned 64-bit shift by `n` bits; `n` outside `0`-`63` is a hard error |

A byte buffer is an ordinary list of numbers: `push` grows it, `xs[i] = v`
patches it at an arbitrary offset (it lowers to `sx_lset`), `len` bounds it,
and `write_bytes` is what finally puts it on disk. `write_file` cannot do that
job, because it takes a C string and therefore stops at the first NUL byte —
the ELF emitted by this gate is full of NULs and is 132 bytes long.

`bytes_f64` returns a list instead of being a list-returning builtin, because
the codegen has no list-typed return for builtins yet; it appends to the list
it is given and returns it, exactly like `push`.

## Gates (all exit 0)

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost` — `=== TRUE-SELFHOST-MIN-OK ===` (`true-selfhost.log`);
  the new gate is inside it through `test-stage2`
- `make gen3` — `=== GEN3-OK ===` and `[OK] byte-identical gen3 == gen4`
  (`gen3.log`). This is the gate that says the compiler is still a fixed
  point after 311 new lines in `selfhost/compiler_min.sa`.
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-native-primitives` — the new gate (`native-primitives.log`):
  - every bitwise operator is checked against a value computed independently
    in C and written down as a literal;
  - `bytes_f64` is checked against the exact byte patterns of `1.5`, `0.0`
    and `-2.0`;
  - `write_bytes` is checked for a 24-byte round trip that contains NULs;
  - the program then writes a **complete static x86-64 ELF executable** that
    exits 42, using nothing but `push`, the bitwise helpers and
    `write_bytes`, and the gate **runs it**;
  - the emitted file's ELF magic, x86-64 machine id (`3e`) and exact 132-byte
    size are pinned before it is executed;
  - seed-min refuses all eight builtins with
    `call names an unknown function or builtin`.
- `make test-proc-builtins`, `make test-path-builtins`,
  `make test-exit-builtin`, `make test-language-deps`, `make test-doc-claims`
  — unchanged and still green (`proc-builtins.log`, `path-builtins.log`,
  `exit-builtin.log`, `language-deps.log`, `doc-claims.log`)

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`). The
  inventory it prints now reads 279 `.sa` files and still lists the seed, the
  native backend and the build driver.

## Honest limits

- A Sayanox number is a C `double`, so a bitwise result at or above 2^53 is
  rounded when it becomes a number. Everything below 2^53 is exact, which
  covers every register, prefix, ModRM and displacement a code emitter needs.
  `bit_not(x)` for a small `x` is the one call whose result is never exact,
  so the documented idiom is `bit_and(bit_not(x), mask)`.
- `write_bytes` refuses a byte outside `0`-`255` and returns `0` rather than
  writing a truncated file. There is no append mode.
- The port of `selfhost/native_aot.c` itself is **not** done. It is still
  4,353 lines of C and its row is still in the `all-sayanox` inventory and in
  `docs/ALL_SAYANOX_PHASE.md`.
- A pre-existing lowering gap was found while writing the gate and is
  documented in `docs/BUILTINS.md` instead of being hidden: `call == "text"`
  inside a condition still lowers to a C pointer comparison, so it compares
  addresses rather than contents. `name == "text"` with a plain variable on
  the left is lowered correctly. The gate uses `string_eq(call, "text") == 1`
  and no gate depends on the broken form.
