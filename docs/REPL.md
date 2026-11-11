# REPL, project scaffolding and project tests

Two ecosystem tools added on 2026-11-10 close the developer loop around the
language: a read-eval-print loop, and a small CLI that scaffolds a project and
runs its tests. Both are ordinary Sayanox programs in `tools/`, both are built by
`./sx target`, and both are pinned by the `calc` suite of `test-sxdiag`.

```sh
./sx target tools/sxrepl        # build the REPL
./sx target tools/sxcli         # build the scaffolding CLI
./tools/sxrepl                  # start a session
./tools/sxcli new hello         # create a project that runs as-is
./tools/sxcli test hello        # compile and run its tests
```

Nothing here is a new language feature. The REPL, the scaffold and the test
runner are built entirely out of already documented builtins (`read_line`,
`write_out`, `run_command`, `read_dir`, `path_kind`, `make_dir`, `read_file`,
`write_file`, plus ordinary string work), so no compiler change was needed and
no backend had to learn anything new.

## `sxrepl` — the loop

```
$ ./tools/sxrepl
sayanox repl -- :help for directives, :quit to leave
sa> hold x = 1 + 2
sa> show x
3
sa> make twice(n: num) -> num {
..>   give n * 2
..> }
sa> show twice(x * 10)
30
```

The model is the one thing worth understanding: **one prompt recompiles the whole
session**. Every accepted line is appended to a session source file, which is
compiled by the real compiler and run. That is what makes earlier bindings,
functions, structs and `use` lines stay visible on later lines, and it is why the
REPL cannot show an answer the compiler would not produce. It is not an
incremental evaluator, has no bytecode interpreter, and makes no speed claim: a
prompt costs one compile of everything typed so far.

Only the new output is printed. Each run's stdout is compared with the byte count
of the previous run's stdout, and only the tail past that count is shown, so
recompiling from the top does not replay earlier answers.

### Directives

| Directive | Effect |
|-----------|--------|
| `:help` | list the directives |
| `:show` | print the session source |
| `:save FILE` | write the session source to `FILE` |
| `:reset` | forget every fragment accepted so far |
| `:quit`, `:q` | leave |

A line starting with `:` is never compiled. An unknown directive is refused by
name and does not end the session.

### Options

| Option | Default | Effect |
|--------|---------|--------|
| `--compiler CMD` | `./selfhost/gen2` | the compiler used for each prompt |
| `--no-prompt` | off | no banner and no `sa>` prompt, for piped scripts |
| `--limit N` | `200` | refuse the session past `N` fragments |

### Rules and honest limits

* A fragment that does not compile is **refused and dropped**; the session keeps
  the state it had, and the compiler's own diagnostic is shown. A typo does not
  end the session.
* Braces continue a fragment: while a `{` is unbalanced, the prompt is `..>` and
  the lines are joined, so `make`, `struct` and multi-statement bodies can be
  typed one line at a time. Braces inside string literals and after `//` do not
  count.
* Blank lines are ignored. Because `read_line()` returns `""` both for an empty
  line and at end of input, **end of input is two consecutive empty reads**; a
  piped script ends with a blank line, an interactive user presses Enter twice or
  types `:quit`.
* One line is one fragment unless braces are open, so a call spread over several
  lines cannot be typed without the braces.
* The REPL does not print an expression's value for you. It has no parser, so it
  cannot know which expression you typed; use `show` on the line, which is also
  what a program would say. This is a deliberate limit, not an omission.
* Output goes through `write_out`. `write_file("/dev/stdout", s)` returns success
  and prints nothing (opening `/dev/stdout` truncates it), a trap worth knowing
  before writing another tool that prints.

A saved session compiles on its own:

```sh
$ ./tools/sxrepl
sa> hold n = 6
sa> show concat("n squared is ", numstr(n * n))
n squared is 36
sa> :save /tmp/sess.sa
saved /tmp/sess.sa
sa> :quit
$ ./selfhost/gen2 /tmp/sess.sa /tmp/sess.c && cc -std=gnu11 -O2 -o /tmp/sess /tmp/sess.c -lm && /tmp/sess
n squared is 36
```

## `sxcli` — scaffolding and tests

```
sxcli new DIR [NAME]    scaffold a project (NAME defaults to `app`)
sxcli test [DIR]        compile and run every test in DIR (default `.`)
sxcli help              the list
```

`new` writes four files and refuses a directory that is already a project, so a
typo cannot overwrite work:

```
DIR/Sayanox.toml     package name and version
DIR/main.sa          the program
DIR/tests/basic.sa   one test
DIR/README.md        how to build and test it
```

The generated `main.sa` compiles and runs as-is:

```sh
$ ./tools/sxcli new hello demo
sxcli: created hello/
  Sayanox.toml  main.sa  README.md  tests/basic.sa
  next: sx build hello/main.sa hello/main
$ ./selfhost/gen2 hello/main.sa /tmp/hello.c && cc -std=gnu11 -O2 -o /tmp/hello /tmp/hello.c -lm && /tmp/hello
hello, demo
```

`test` compiles each `tests/*.sa` with the project's compiler, builds it and runs
it. A test **passes when it compiles, builds and exits 0**; its stdout is shown.
The last line reports the manifest's name and the count either way:

```
$ ./tools/sxcli test hello
demo: ok
PASS basic.sa
demo: 1 tests, 1 passed
```

A failing test does not stop the run, is named, and makes the command exit 1:

```
$ ./tools/sxcli test hello
demo: ok
PASS basic.sa
about to fail
FAIL failing.sa: exit 1
demo: 2 tests, 1 passed
```

There is intentionally **no runner API, no `expect`, no matchers**. Any such
function would have to fail from inside the language, which is a language feature
and not a tool. A test that wants to fail exits non-zero, which every program can
already do. A test that does not compile is reported as `does not compile` with
the frontend's own message, not blamed on the C stage: `gen2` writes a source
containing `#error` and still exits 0, so the runner reads the emitted C to
classify the failure.

The compiler default is `./selfhost/gen2`; set `SX` to point at another one.

## Where they are pinned

* `tools/sxrepl.sa`, `tools/sxcli.sa` — the implementations.
* `tools/sxbuild.sa` — both are targets, so `./sx target tools/sxrepl` and
  `./sx target tools/sxcli` work, and `test-sxdiag` builds them before running.
* `tools/sxdiag.sa` — the `calc` suite, 16 cases: the session protocol
  (carrying a binding, multi-line fragments, a refused fragment, `:show`/`:save`,
  a saved session compiling, `--limit`, an unknown directive, a missing compiler)
  and the CLI (the four scaffold files, the scaffolded program's output, a passing
  run, a failing test, a test that does not compile, a non-project, refusing to
  overwrite, usage status 2).
* `tools/sxmore_gates_lib.sa` — `test-sxdiag` runs the suite and asserts the
  `calc: 16` line.

```sh
./sx target test-sxdiag
./tools/sxdiag calc ./selfhost/seed/sxc_seed_min ./selfhost/gen2 ./selfhost/native_aot /tmp/calc
```
