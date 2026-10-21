# Builtins in the maintained pure-min subset

This table describes calls covered by the current seed-min/gen2 compiler tests.
Native AOT coverage and intentional differences are documented in
[`STATUS.md`](STATUS.md).

| Sayanox call | Purpose | seed-min | gen2 | native AOT |
|--------------|---------|----------|------|------------|
| `concat(a, b)` | concatenate strings | yes | yes | yes |
| `len(value)` | string/list length | yes | yes | yes |
| `chr(n)` | one-byte string from numeric code | yes | yes | yes |
| `string_eq(a, b)` | string equality as numeric 0/1 | yes | yes | yes |
| `sx_index(s, i)` / `s[i]` | byte at zero-based index | yes | yes | yes |
| `arg_count()` / `arg(i)` | process argument count/value | yes | yes | yes |
| `read_file(path)` | read a file as a string | yes | yes | yes |
| `write_file(path, data)` | truncate/write a file; numeric status | yes | yes | yes |
| `http_get(url)` | HTTP GET body as a string; `""` on any failure | yes | yes | no (refused with an error) |
| `push(xs, value)` | append a number to a list | yes | yes | yes |

`http_get(url)` is a network read with these fixed rules: GET only, `http://` or
`https://` only, no redirects, 1,000,000-byte body cap, 10-second timeout, URL
length at most 3000 and only the characters `A-Za-z0-9 -._~:/?&=%+#@,;`. Any
failure (404, timeout, refused scheme, bad character) returns `""`. Consecutive
requests in one process are at least 1 second apart (the rate limit; it is
built into the runtime, so no program can turn it off). It shells out to `curl`
(the seed and gen2 runtimes); the native backend refuses it with an explicit
error. Tested against a local server only by `make test-http-get`. The Sayanox
crawler `sayascrape/crawl.sa` is the program that uses it (`make test-sayacrawl`).

`len` accepts strings and numeric lists. List indexing is zero-based. String
indexing returns a numeric byte value; use `chr` when a one-byte string is
needed. The exact edge cases and parity tests are listed in
[`STATUS.md`](STATUS.md).

## Runtime builtins added with the collector (gen1_min / gen2)

These are compiled and run by `selfhost/gen2` (and by the `gen1_min` built from
the same source); the checked-in `seed-min` predates them and rejects them.

| Sayanox call | Purpose |
|--------------|---------|
| `read_line()` | read one line from stdin, without the newline |
| `read_n(n)` | read exactly `n` bytes from stdin |
| `write_out(s)` | write `s` to stdout without a newline |
| `flush_out()` | flush stdout |
| `numstr(n)` | format a number as a string (the `%g` form `show` uses) |
| `gc()` | run a collection now; returns the bytes reclaimed |
| `gc_live()` | bytes currently held by the managed heap |
| `gc_runs()` | number of collections so far |
| `exit(n)` | flush stdout, terminate the process with status `n` |
| `read_dir(path)` | newline-separated entry names, without `.`/`..`; `""` on failure |
| `path_kind(path)` | `0` missing, `1` regular file, `2` directory, `3` other (`lstat`) |
| `path_size(path)` | size in bytes for a regular file, otherwise `0` |
| `path_real(path)` | canonical absolute path, `""` when it does not resolve |
| `spawn(path)` | start a child with piped stdin/stdout; handle 1-8, `0` on failure |
| `child_send(h, s)` | write `s` to the child's stdin; `1` on success, `0` on failure |
| `child_recv(h, n)` | read up to `n` bytes from the child's stdout as text |
| `child_line(h)` | read one line from the child's stdout, without the newline |
| `child_close(h)` | close the child's stdin, wait for it, return its exit status |
| `make_dir(path)` | create a directory (`0700`); `1` on success, `0` on failure |
| `make_link(target, path)` | create a symlink; `1` on success, `0` on failure |
| `remove_path(path)` | remove a file or an empty directory; `1` on success, `0` on failure |
| `write_bytes(path, xs)` | write a list of numbers as raw bytes; `1` on success, `0` on failure |
| `bytes_f64(xs, v)` | append the 8 little-endian IEEE-754 bytes of `v` to a list |
| `read_bytes(path, xs)` | append every byte of a file to a list, NUL bytes included; gives the count, or `-1` if it cannot be read |
| `bit_and(a, b)` / `bit_or(a, b)` / `bit_xor(a, b)` | 64-bit bitwise and/or/xor as a number |
| `bit_not(a)` | 64-bit complement as a number |
| `shl(a, n)` / `shr(a, n)` | unsigned 64-bit shift left/right by `n` bits |

All of them are ordinary expressions, so they nest inside other calls
(`concat(a, numstr(n))`) and can be stored (`hold n = numstr(v)`). Native AOT
does not implement them. See [`GC.md`](GC.md).

`read_dir`, `path_kind`, `path_size` and `path_real` are the directory
surface added on 2026-10-17 (the prerequisite for moving the LSP's folder
index out of C). `read_dir` skips `.`/`..` and names containing a newline or
carriage return, and caps one directory at 4096 names and 4 MB; `path_kind`
and `path_size` use `lstat`, so a symlink reports `3` and is never followed;
`path_real` is `realpath(3)`. seed-min and the native backend refuse all four
(`make test-path-builtins` pins both the behaviour and the refusal).

`spawn`, `child_send`, `child_recv`, `child_line` and `child_close` are the
process surface added on 2026-10-17 so Sayanox tools can drive another Sayanox
binary: the LSP framed-session test client uses them and no C harness is left
in `tools/`. At most eight children are alive at once; a handle that was never
spawned is answered with `0` / `""` / `""` / `-1` instead of crashing, and a
write to a child that already exited fails (`SIGPIPE` is ignored by the
runtime) instead of killing the caller. `child_recv` returns text, so an
embedded NUL byte ends the string early; use `child_line` for line protocols.
`make_dir`, `make_link` and `remove_path` complete the filesystem surface the
same client needs; `remove_path` falls back to `rmdir` for a directory.
`make test-proc-builtins` pins all of it, and seed-min refuses every one of
these builtins the same way it refuses the directory ones.

`write_bytes`, `bytes_f64` and the six bitwise calls are the byte-buffer
surface added on 2026-10-18 as the first step toward rewriting
`selfhost/native_aot.c` in Sayanox: a byte buffer is an ordinary list of
numbers, `push` grows it, `xs[i] = v` patches it, `len` bounds it and
`write_bytes` is what finally puts it on disk. `write_file` cannot do that
job because it takes a C string and therefore stops at the first NUL byte;
`write_bytes` refuses any value outside `0`-`255` and returns `0` rather than
writing a truncated file. `bytes_f64` returns the exact eight bytes of a
double instead of a list-returning builtin, because the codegen has no
list-typed return for builtins yet.

The bitwise calls are honest about their one real limit: a Sayanox number is a
C `double`, so a result at or above 2^53 is rounded when it becomes a number.
`bit_and`, `bit_or`, `bit_xor`, `shl` and `shr` are exact below 2^53, which
covers every register, prefix, ModRM and displacement a code emitter needs;
`bit_not(x)` for a small `x` is the one call whose result is never exact, so
the idiom is `bit_and(bit_not(x), mask)`. An operand outside `0`-`2^64`, a
shift count outside `0`-`63` or a byte outside `0`-`255` is a hard error, not
a silent zero. `make test-native-primitives` pins all of it: it checks every
operator against a value computed in C and then runs a static x86-64 ELF
executable that a Sayanox program wrote with nothing but `push`, the bitwise
helpers and `write_bytes`.

`read_bytes` is the reader that surface was missing, added on 2026-10-20 with
`tools/sxlink.sa`. `write_bytes` could put a byte buffer on disk, but nothing
could read one back: `read_file` returns a C string, so an ELF image -- which
is mostly NUL bytes and page padding -- arrived truncated. `read_bytes(path,
xs)` appends every byte of the file to `xs` and gives the count, so a buffer
that round-trips a binary file is `hold n = read_bytes(p, xs)` followed by
`xs[i]`. It appends rather than returning a fresh list for the same reason
`bytes_f64` appends: the codegen still has no list-typed return for a builtin.
`-1` means it could not be read, and then nothing was appended, so a caller can
retry into the same buffer. `make test-read-bytes` pins the round trip through
a NUL byte and a `0xFF` byte, the append-on-second-read contract, the `-1`,
and the refusal by seed-min and by the native backend.

One known limitation of the comparison lowering, unchanged by this addition:
`call == "text"` (and `!=`, `<`, `>`, `<=`, `>=`) still lowers to a C pointer
comparison, so it compares addresses instead of contents and is silently
wrong. `name == "text"`, where the left side is a plain variable, is lowered
correctly to `sx_eq`. Use `string_eq(call, "text") == 1` for the call form
until the condition rewriter learns to classify a call; the gates use that
form and no gate depends on the broken one.

A second limitation, found on 2026-10-18 while porting `tools/sxpkg.sa` and
fixed the same day: **the compiler's signature pre-pass did not understand
`//` comments.** It scanned the whole file for `make` at the start of a line
while tracking string literals, and the comment-tracking branch in that loop
was dead code (`fscm` was never set to 1), so a double quote inside a comment
toggled string mode. A comment with an *odd* number of double quotes therefore
made the pre-pass treat the rest of the file as one string literal, every later
`make` was missed, and each of those functions fell back to the raw parameter
parse — which reads `a: num, b: num` as four untyped parameters. The result was
C that did not compile (`static double add2(double a, double num, double b,
double num)`, plus a `#error sayanox-min: unknown function:` for the recursive
ones), so it was loud at build time, but the cause was invisible in the `.sa`
source. The pre-pass now recognises `//` and runs to the end of the line
before it can see a quote, the same way the real lexer already did.
`make test-comment-quotes` pins it from both ends: a fixture whose comment
carries one quote must still compile to `double a, double b`, run, and print
`3`; `tools/sxpkg.sa` must still compile to a typed `char *toml_field(char
*text, char *key)` with no mangled parameter list; and seed-min, which has its
own pre-pass, must agree.

`exit(n)` was added on 2026-10-17 so Sayanox CLI tools can report failure
without a C helper. It flushes stdout before terminating, returns a number
type, and follows the ordinary-expression rule above (`hold code = exit(2)`,
`show exit(2)`); bare `exit(2)` on its own line is an `unknown statement` like
every other bare call. seed-min, native AOT and the checked-in Stage-2 seed do
not implement it (`make test-exit-builtin` pins both the behaviour and the
refusal).

The maintained C backends accept the builtins in expressions (for example,
`hold status = write_file(path, text)`). A *statement* is `hold show when
while make give struct use` or a bare `push(xs, v)`; every other bare call —
`write_file(path, text)` on its own line, a user-function call — is an
`unknown statement` in seed-min, gen2 and (since 2026-10-08) native, which
used to run any bare builtin call. `string + number` is rejected by all three
for the same reason; build a message with `concat(s, n)` if a program has to
run everywhere.

## Tiny portable library: `stdlib/tiny.sa`

The repository ships one small library, used with the ordinary module splice:

```sayanox
use "stdlib/tiny.sa"

show min2(3, 7)      // 3
show max2(3, 7)      // 7
show absv(0 - 5)     // 5
show sum_to(10)      // 55   (recursive)
show pow_int(2, 10)  // 1024 (recursive)
show is_even(42)     // 1
show gcd(48, 36)     // 12   (recursive, uses %)
```

It is deliberately numeric-only: the native-AOT subset has no string-returning
functions and no list/string function parameters, so every helper here runs
unchanged on seed-min, gen2 and native (`make test-stdlib` compares their
output). Use the builtins above for string and list work. This is not a full
standard library — [`STATUS.md`](STATUS.md) records that boundary.
