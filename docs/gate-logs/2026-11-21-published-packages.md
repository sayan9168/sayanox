# Published packages and an index-driven registry gate — 2026-11-21

Branch `arena/875f0c9e-sayanox`, based on `main` at `0edaafb`. This is the
registry half of the day's work: three real packages in the published index, and
`test-registry-sums` rewritten so the index — not a hard-coded list inside the
gate — decides what has to exist and what has to build.

## What landed

| Package | Prefix | What it adds | Depends on |
|---|---|---|---|
| `registry/text` | `pkgtext_` | `pkgtext_slice`, `pkgtext_words`, `pkgtext_flatten`, `pkgtext_repeat`, `pkgtext_title`, `pkgtext_starts` | — |
| `registry/numfmt` | `pkgnf_` | `pkgnf_slice`, `pkgnf_istr`, `pkgnf_commas`, `pkgnf_pad`, `pkgnf_field` | — |
| `registry/kv` | `pkgkv_` | `pkgkv_count`, `pkgkv_value`, `pkgkv_has`, `pkgkv_num` for `a=1;b=22` pair lists | `text@0.1.0` |

`registry/INDEX` now lists seven packages (`hello`, `math`, `strings`, `calc`,
`text`, `numfmt`, `kv`), all `0.1.0`. Every file in them is Sayanox: no C, no
shell, no Python.

`numfmt` exists because `show` prints numbers with `%g`: a whole number above
seven digits comes out as `1.23457e+09`. `pkgnf_istr` builds the decimal text
digit by digit, so `pkgnf_istr(1234567890123)` is exactly
`1234567890123`, and `pkgnf_commas` groups it. That is honest about the range:
it is exact for the integers an IEEE double holds without loss, and it does not
claim to be a big-integer library.

`kv` is the package that makes the dependency machinery matter: its `pkg.meta`
says `deps=text@0.1.0`, its `main.sa` starts with
`use ".sayanox/registry/text/main.sa"`, and it counts pairs by flattening the
separator to spaces and handing the line to `pkgtext_words`. Two packages, one
lock resolution, one splice — the same path a real consumer takes.

## The gate, and what it refused

`make test-registry-sums` used to iterate a list written inside the gate
(`"hello\nmath\nstrings\n"`) and re-derive one sum each. `calc` was already
published and already absent from that list, so a package could be added to the
index with a wrong `sum=`, a missing `pkg.meta`, or a `main.sa` that no program
can compile, and the gate would not notice.

It now reads `registry/INDEX` itself. For each indexed name it checks that
`registry/<name>/pkg.meta` exists and its `name=` equals the directory, its
`version=` equals the index pin, and its `sum=` equals what
`./tools/sxpkg sum registry/<name>/main.sa` prints. Then it writes a one-line
probe program in the fixture directory, compiles it with `gen2` **from inside a
project that carries its own `.sayanox/registry` copy**, and requires the exact
bytes that probe must print:

| Probe | Expected stdout |
|---|---|
| `show "done"` after `use .sayanox/registry/hello/main.sa` | `hello from pkg` LF `done` |
| `show dbl(21)` with `math` | `42` |
| `show greet("bo")` with `strings` | `hi bo` |
| `show dblsqr(3)` with `calc` | `36` |
| `show pkgtext_words("a bb  c")` with `text` | `3` |
| `show pkgnf_commas(1234567)` with `numfmt` | `1,234,567` |
| `show pkgkv_num("a=1;b=22", "b", 59)` with `kv` | `22` |

`emit #error` in the generated C is a failure, as everywhere else in this
project, so a package the seed front end cannot lower cannot pass. The reverse
direction is checked too: every directory under `registry/` must appear in the
index, so a package cannot be dropped from publication quietly.

Three negative controls were run by hand, each restored afterwards:

* `bogus=0.1.0` appended to `registry/INDEX` →
  `[FAIL] published package has no pkg.meta: bogus`;
* a `registry/zzz/` directory with both files and no index line →
  `[FAIL] registry directory missing from the index: zzz`;
* `registry/text/pkg.meta` `sum=` set to `1` →
  `[FAIL] repository registry sum: string mismatch`.

The gate also caught a wrong expectation of mine before it caught any code: the
first draft pinned `pkgtext_words("a bb  c")` as `2`. `a`, `bb` and `c` are three
words. The module was right, the fixture was wrong, and the fixture changed —
the oracle is only an oracle if it is allowed to embarrass the author first.

## Constraints that shaped the code

* **`sum=` must match `sxpkg sum`.** Editing any `registry/*/main.sa` changes
  its sum, so all three new `pkg.meta` files carry the value the tool printed:
  `text` 621150026, `numfmt` 609229368, `kv` 978421545. `test-registry-sums`
  re-derives them; nothing is copied by hand.
* **There is no `cut` builtin.** The first drafts of all three packages used
  `cut(s, a, b)` and died in `gen2` with `unknown function: cut`, because
  `cut` is a *stdlib* helper (`stdlib/str_text.sa`) that a package may not
  assume. `docs/BUILTINS.md` is the list a published package may rely on:
  `concat`, `len`, `chr`, `string_eq`, `sx_index`, `arg_count`/`arg`,
  `read_file`/`write_file`, `push`. So `text` and `numfmt` each carry a small
  clamped slice helper rather than reach into a module the consumer may not
  have installed, and `kv` gets its slicing from `text` — the one place where
  sharing a helper across packages is safe, because it is the declared
  dependency.
* **Splice namespaces are flat.** `use` copies a package's text into the
  program, so a published `slice` would collide with any host that defines one.
  Every name in a package is prefixed `pkg<name>_`.
* **The offline seed stays `hello` + `math`.** `sxpkg seed` writes a two-package
  index into `.sayanox/registry/`, and `kp_wrapper` pins exactly
  `hello=0.1.0\nmath=0.1.0\n` there; `docs/REGISTRY.md` documents that seed as
  the no-network path. The published `registry/` tree is deliberately wider than
  the seed, and the new gate is the place where the wide tree is proven.

## Acceptance for this increment

```
./sx tool sxgates            # rebuilt after every gate edit
./tools/sxgates test-registry-sums   [OK]
./sx tool sxpkg                      # rebuilt after the package edits
./tools/sxpkg sum registry/<p>/main.sa for all seven
```

and through `./sx target`, each of which rebuilds its own prerequisites:

| Target | Result |
| --- | --- |
| `test-sxpkg` | `[OK] Sayanox package acceptance: test-sxpkg` |
| `test-sxpkg-wrapper` | `[OK] Sayanox package acceptance: test-sxpkg-wrapper` |
| `test-pkgs` | `[OK] Sayanox package acceptance: test-pkgs` |
| `test-registry-sums` | `[OK] Sayanox package acceptance: test-registry-sums` |

Every package source was additionally compiled and run by hand on seed-min,
gen2 and `native_aot` from a project directory holding a copy of `registry/`,
and the three outputs are byte-identical per package. `tools/sxpkg_gates_lib.sa`
is pinned in `bootstrap/sx.sha256`, so its entry was repinned; `registry/*` is
not pinned and needed no manifest change.

This is local gated acceptance for one increment. It does not establish
independent bootstrap trust, remote guarded CI, or that the registry is a
distribution channel: publishing is still a git push plus a `sum=`/`sha256=`
record, and R08 (authenticated transport, key distribution, trust roots) stays
open.
