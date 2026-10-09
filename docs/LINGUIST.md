# Getting Sayanox recognized as a language on GitHub

Status: **prepared, not submitted.** Nothing in this document has been merged
into `github-linguist/linguist`, and the language bar on
[sayan9168/sayanox](https://github.com/sayan9168/sayanox) still shows C /
Makefile / Shell.

All upstream facts below were checked against `github-linguist/linguist@main` on
**2026-10-09**.

---

## 1. Why the language bar does not show Sayanox

GitHub computes the language bar with [Linguist](https://github.com/github-linguist/linguist),
which knows a language only if it has an entry in
[`lib/linguist/languages.yml`](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml).
Two facts, both verified against that file on 2026-10-09:

- There is **no `Sayanox:` entry** in `languages.yml` (836 entries carry a
  `language_id`, none of them named Sayanox).
- **No language claims the `.sa` extension.** The extension is unassigned, so
  Linguist reports no language at all for `.sa` files and they contribute
  nothing to the bar.

A repository-local `.gitattributes` cannot register a new language. Linguist's
own [overrides documentation](https://github.com/github-linguist/linguist/blob/main/docs/overrides.md)
says an unregistered language will not appear in language statistics even with
`linguist-language` and `linguist-detectable` set. Only an upstream change to
`languages.yml` fixes the bar.

Mapping `*.sa` to Python, C, Rust or SAS "for stats" is deliberately **not**
done anywhere in this repository. It would report all 173 Sayanox source files
as a language they are not written in, and it would have to be undone later.

### What the bar shows now, and what it would show after a merge

Linguist weights languages by source bytes, excluding generated, vendored,
prose and documentation files. Measured over this tree after the change
described in this document:

| Language | Bytes | Share today | Share once Linguist knows Sayanox |
|---|---:|---:|---:|
| Sayanox (`.sa`) | 757,694 | not counted | **≈ 65 %** |
| C (`.c`) | 232,450 | ≈ 58 % | ≈ 20 % |
| C-family, ambiguous (`.h`, `.inc`) | 17,713 | ≈ 4 % | ≈ 2 % |
| Makefile | 132,991 | ≈ 33 % | ≈ 12 % |
| Shell (`.sh`) | 20,498 | ≈ 5 % | ≈ 2 % |

`.h` and `.inc` are claimed by several languages at once (C, C++,
Objective-C, Assembly, BitBake), so Linguist's classifier decides where those
17 KB land; either way the picture is the same. Sayanox is already the largest
language in the repository by a factor of three. The only thing missing is the
upstream registry entry.

---

## 2. What this repository now ships

Everything Linguist needs from a contributor is prepared here, so the upstream
pull request is a copy-and-check job rather than new work.

| Path | Purpose |
|---|---|
| `.gitattributes` | Marks `.sa` detectable and pre-declares `linguist-language=Sayanox` (inert until upstream merges); marks all 184 generated artifacts as `linguist-generated` |
| `samples/Sayanox/*.sa` | Six sample programs, in the directory layout Linguist expects (`samples/<Language>/`) |
| `grammars/sayanox.tmLanguage.json` | TextMate grammar draft, `scopeName: source.sayanox` |
| `docs/LINGUIST.md` | This plan, the exact `languages.yml` snippet, the checklist and the draft PR text |
| `docs/GITHUB_LANGUAGE.md` | Short statement of the current state |

### 2.1 `.gitattributes`

```gitattributes
*.sa linguist-detectable=true
*.sa linguist-language=Sayanox
```

`linguist-language=Sayanox` resolves to nothing while "Sayanox" is unknown to
Linguist and is ignored, so it cannot mislabel anything today; it starts working
the moment the upstream entry lands. Both rules were verified against every
tracked file with `git check-attr`: all 173 `.sa` files (167 existing plus the
6 new samples) resolve to `linguist-detectable: true` and
`linguist-language: Sayanox`, and none are marked generated.

The generated-artifact rules mark 184 tracked files and cover:

- `*.b64` and `*.b64.p[0-9]` — 159 base64 chunk files, including the 82 in
  `selfhost/compiler_min_gz/`
- the chunk directories `selfhost/{compiler_min_gz,native_src,stage2_src,sxc_full_b64,sxc_full_b64_plain,sxc_full_lines,sxc_sa_parts}/**`
- `*.part`, `*.cpart`, `*.hex` — other split fragments
- `docs/logs/**` and `*.log` — 7 captured build and test logs
- C emitted by the self-hosting compilers: `selfhost/gen*.c`, `selfhost/boot*.c`,
  `selfhost/_smoke.c`, `selfhost/_out.c`, `selfhost/mini_out.c`,
  `selfhost/hello_out.c`, `tools/sxfmt.c`, `tools/sxpkg.c`,
  `tools/sayanox_lsp.c`

Those C outputs are already listed in `.gitignore`, so the rules are
future-proofing: a stray commit cannot quietly make generated C the largest
language in the repository.

Hand-written C is explicitly **left visible** and is *not* marked generated:
`selfhost/seed/sxc_seed.c`, `selfhost/seed/sxc_seed_min.c` (the C bootstrap
seed), `selfhost/native_aot.c` (the x86-64 native AOT backend),
`selfhost/sxc_full.c`, `selfhost/sxc_full_minimal.c`,
`selfhost/stage2_template.c`, `selfhost/stage2_expand.inc`,
`selfhost/build_stage2.c`, `selfhost/sx_driver.c`, `selfhost/sx_launcher.c`,
`selfhost/inject_*.c`, `selfhost/fixup_emit.c`, `selfhost/prove_*.c`,
`selfhost/rc_runtime_stress.c` and the two headers. A verified `git check-attr`
run reports zero of the 19 tracked `.c`/`.h`/`.inc` files as generated. The
hand-written `README.md` files that live inside three of the chunk directories
are un-marked again by a final `**/README.md -linguist-generated` rule, so all
5 tracked READMEs stay visible as documentation.

### 2.2 Samples

Linguist expects samples at `samples/<Language>/` and says plainly that
**"Hello world" and other examples found in tutorials will not be accepted** —
it wants real-world code showing common usage. The six files here are written
against the real compiler and were verified by compiling and running them:

| File | Dialect | Shows | Verified |
|---|---|---|---|
| `hello.sa` | pure-min | `hold`, `show`, `concat`, `arg_count`/`arg`, `when`/`otherwise`, `while` | seed-min + gen2 + native, identical output |
| `lists.sa` | pure-min | list literals, zero-based indexing, `len`, `push`, counters, a helper call used as an index | seed-min + gen2 + native, identical output |
| `structs.sa` | pure-min | `struct` declarations, named and positional literals, string fields, nested structs, struct copies, field access chains | seed-min + gen2 + native, identical output |
| `functions.sa` | pure-min | `make`/`give`, guard clauses, recursion, `%`, comparisons as values, a function result bound and reused | seed-min + gen2 + native, identical output |
| `modules.sa` | pure-min | `use` source splice of `stdlib/tiny.sa`, `read_file`, `write_file`, `sx_index`, `chr` | seed-min + gen2 + native, identical output |
| `control_flow.sa` | gen2 full language | `for … in` over lists/strings/ranges, `break`, `continue`, `and`/`or`/`not`, `true`/`false`, `elif` chains | gen2 runs it; seed-min and native refuse it **by name** rather than mis-compiling |

Five of the six produce byte-identical output on all three backends, which is
the repository's own portability bar. `control_flow.sa` is included because the
full-language forms are a real part of Sayanox and because the way the two
smaller backends reject them by name (`unknown statement 'for'`,
`'for' is a full-language statement and not in the native subset`) is itself
characteristic of the language.

Writing these samples turned up three constraints worth recording, all now
documented in the sample comments because they are exactly the kind of detail a
grammar and a reviewer need:

- An index must be a number literal or a bare name — `xs[len(xs) - 1]` is
  rejected as an `unsupported index expression`, so the index is bound first.
- Each loop body gets its own slot for a name, so two loops that both bind `v`
  collide in the emitted C; the samples use distinct names.
- `native_aot` accepts arithmetic on a struct field inside `show` and `when`,
  but rejects binding the result (`hold d = p.x * p.x` → `* is numeric-only`)
  and rejects passing a field into a user function.

For the upstream PR, `hello.sa` should be dropped or replaced: despite its name
it is a command-line program that parses `argv`, but reviewers filter out
anything that looks like a tutorial hello-world. The strongest candidates to
lead with are `structs.sa`, `functions.sa` and `modules.sa`, and ideally one or
two excerpts of real compiler code — for example from `selfhost/compiler_min.sa`
(13,972 lines of Sayanox that compiles itself) or `tools/sayanox_lsp.sa` (an LSP
3.17 server written in Sayanox). Those are unambiguously real-world usage.

### 2.3 Grammar

`grammars/sayanox.tmLanguage.json` declares `scopeName: source.sayanox` and
`fileTypes: ["sa"]`. It covers every construct the task list requires — `hold`,
`show`, `when`, `while`, `make`, `give`, `struct`, `use`, `//` comments and
double-quoted strings — plus `otherwise`/`else`/`elif`, `for … in`, `break`,
`continue`, the word operators `and`/`or`/`not`, `true`/`false`, numeric
literals (integer, float, exponent), generics, typed parameters and return
arrows, builtin calls, struct literals, member access and reassignment.

It was validated with a real TextMate tokenizer (`vscode-textmate` +
`vscode-oniguruma`), not by inspection:

- The grammar loads and every sample tokenizes with **zero** `invalid.*` tokens.
- All required scopes are produced, with none missing: `storage.type.hold`,
  `keyword.other.output` (`show`), `keyword.control.conditional`
  (`when`/`otherwise`/`elif`), `keyword.control.loop`
  (`while`/`for`/`in`/`break`/`continue`), `storage.type.function` (`make`),
  `keyword.control.return` (`give`), `storage.type.struct`,
  `keyword.control.import` (`use`), `comment.line.double-slash`,
  `string.quoted.double`, `constant.character.escape`.
- Real repository files tokenize correctly too, including generics and typed
  parameters: `selfhost/seed_tests/tg.sa` (5 generic type-parameter lists) and
  `stdlib/str_util.sa` (48 `support.type`, 33 `variable.parameter`, 20 return
  arrows).
- No catastrophic backtracking: the 13,973-line `selfhost/compiler_min.sa`
  produces 128,179 tokens in about 0.5 s.

One non-obvious bug was found and fixed during that validation. `<` is both the
type-parameter bracket and the less-than operator in Sayanox, and a separate
`<…>` rule never fired because the preceding `make NAME` match had already
consumed the name. Declaration and type parameters are therefore matched by a
single rule, with `<…>` recognised only directly after a declared name.

Two things the grammar still needs before it can go upstream:

1. **Its own public repository.** Linguist adds grammars with
   `script/add-grammar https://github.com/<user>/<repo>`, which vendors the repo
   as a git submodule. A grammar file inside this repository cannot be used
   directly. The suggested layout for that repo is
   `syntaxes/sayanox.tmLanguage.json` plus a `LICENSE` and a short README;
   `grammars/sayanox.tmLanguage.json` here is the source of truth to copy.
2. **An allowed license.** Linguist only accepts grammars under one of:
   `apache-2.0`, `bsd-2-clause`, `bsd-3-clause`, `cc0-1.0`, `isc`, `mit`,
   `mpl-2.0`, `ncsa`, `permissive`, `unlicense`, `wtfpl`, `zlib`. This
   repository is MIT, so an MIT grammar repo already qualifies.

---

## 3. The exact `languages.yml` snippet

```yaml
Sayanox:
  type: programming
  color: "#19B3A6"
  extensions:
  - ".sa"
  tm_scope: source.sayanox
  ace_mode: text
```

Notes on each field:

- **Placement.** `languages.yml` is alphabetised; `Sayanox` goes between `Sass`
  and `Scala`.
- **`language_id` is deliberately absent.** The file header says the field is
  generated by running `script/update-ids` and must not be filled in by hand,
  and `CONTRIBUTING.md` step 1 says to omit it. Existing IDs are large
  non-sequential numbers (the largest currently in the file is `1067292664`).
  Run `script/update-ids` and let it assign one.
- **`color: "#19B3A6"`** — a teal. Chosen because it is the most distinct of the
  candidates tried: its minimum RGB distance to any of the 624 colours already
  in `languages.yml` is 0.099, and it is far from C's `#555555`, C++'s
  `#f34b7d` and Makefile's `#427819`. A colour is optional (`#cccccc` is the
  default) but strongly recommended, and the PR template asks for a rationale —
  "selected for maximum distance from existing language colours" is that
  rationale.
- **`extensions`** is written in block style to match the file's convention.
  `.sa` is currently unclaimed, so this adds no conflict with an existing
  language entry.
- **`tm_scope: source.sayanox`** must match the `scopeName` in the grammar,
  which it does.
- **`ace_mode: text`** — Ace has no Sayanox mode, and `text` is the documented
  fallback. No `codemirror_mode` for the same reason.
- No `aliases` key. Linguist already implies the lowercased name `sayanox`;
  adding `sa` as an alias would be a two-letter alias in fenced code blocks and
  is not worth the collision risk.

---

## 4. The blocking problem: in-the-wild usage

This is the honest part, and it is why nothing has been submitted.

`CONTRIBUTING.md` states that Linguist will **only add new extensions once they
have sufficient usage on GitHub**, that it **does not accept PRs for very new or
hobby languages and will close any such PRs**, and gives concrete thresholds:

- at least **2000 files** per extension indexed in the last year, excluding
  forks, for extensions that occur more than once per repo (`.sa` is such an
  extension);
- a **reasonable distribution across unique `user/repo`** combinations, assessed
  by manually clicking through results;
- where one user dominates, that user is filtered out with `-user:<username>`
  before the assessment.

Measured through the GitHub code search API on 2026-10-09:

| Query | Hits | What they actually are |
|---|---:|---|
| `extension:sa` | 24,416 | Overwhelmingly **not** Sayanox: `hello-asm.sa` and friends from `vonzhou/CSAPP` and `shihyu/CSAPP2e` (assembly), and `src/ECB*.SA` from `davidlinsley/DragonBasic` |
| `extension:sa NOT is:fork` | 24,416 | Same population |
| `extension:sa hold show` | 948 | Top hits are all `sayan9168/sayanox` |
| `extension:sa "hold" "give"` | 167 | Mixed: this repository, plus `NetBSD/src sys/arch/m68k/fpsp/round.sa` and `davidlinsley/DragonBasic` |
| `extension:sa sayanox` | 58 | All `sayan9168/sayanox` |

The raw 24,416 looks like it clears 2000, but it does not survive Linguist's
assessment. Clicking through returns assembly and BASIC, not Sayanox, and every
query that actually identifies Sayanox source resolves to one repository owned
by one user — precisely the case the `-user:<username>` filter exists to remove.
**A pull request opened today would be closed as a hobby language.**

There is a second problem. `.sa` is unclaimed in `languages.yml`, but it is not
unused on GitHub: roughly 24,000 indexed `.sa` files are assembly or BASIC.
Assigning `.sa` to Sayanox with no disambiguation would newly misclassify all of
them, and Linguist's stated goal is "to try and avoid false positives". A real
PR therefore has to ship a heuristic, not just an extension.

`lib/linguist/heuristics.yml` keeps its rules under a `disambiguations` list,
alphabetised by extension, with Ruby-compatible patterns checked by
`script/check-regex-compatibility`. A starting point for `.sa`:

```yaml
- extensions: ['.sa']
  rules:
  - language: Sayanox
    pattern: '^\s*(hold|show|when|otherwise|while|make|give|struct|use)\b'
  - language: Assembly
    pattern:
    - '^\s*\.'
    - '^\s*(mov|jmp|call|ret|push|pop|lea|add|sub|imul|idiv)\b'
```

The Sayanox rule is safe to be first: a line starting with one of the eight
statement keywords is not assembly. The Assembly rule needs real work and should
be written against the actual `CSAPP` and `DragonBasic` files rather than
guessed at. This heuristic is a draft, not something validated against that
population, and it is not part of any submitted change.

### What would make the PR eligible

1. Other people and other organisations writing `.sa` programs on public GitHub,
   enough that the Sayanox-specific search clears 2000 indexed files spread over
   many `user/repo` pairs, and still clears it after `-user:sayan9168`.
2. A published grammar repository with an allowed license.
3. A heuristic that separates Sayanox from the assembly and BASIC already living
   in `.sa`.
4. Samples that are real-world code rather than tutorial fragments.

Items 2 and 4 are done or nearly done. Item 3 is drafted. Item 1 is adoption,
which no amount of work inside this repository can produce.

---

## 5. Checklist for the upstream `github-linguist/linguist` PR

Work through this in order. Steps in the first block are prerequisites for
opening anything.

**Before opening a PR**

- [ ] Publish the grammar as its own public repository (suggested:
      `sayan9168/sayanox-tmgrammar`) with `syntaxes/sayanox.tmLanguage.json`
      copied from `grammars/sayanox.tmLanguage.json`.
- [ ] Add an allowed `LICENSE` to that grammar repo. MIT matches this repository
      and is on Linguist's allow-list.
- [ ] Confirm `scopeName` in the published grammar is exactly `source.sayanox`.
- [ ] Re-run the usage search and record the numbers and the date:
      `https://github.com/search?type=code&q=NOT+is%3Afork+path%3A*.sa+hold+show+give`
- [ ] Decide honestly whether those numbers clear 2000 indexed files with a
      real distribution across `user/repo` **after** excluding
      `-user:sayan9168`. If not, stop here — the PR will be closed.
- [ ] Pick the samples: real-world code only. Drop `hello.sa`; prefer
      `structs.sa`, `functions.sa`, `modules.sa` and excerpts of
      `selfhost/compiler_min.sa` or `tools/sayanox_lsp.sa`.
- [ ] Draft the `.sa` disambiguation in `lib/linguist/heuristics.yml` against
      real assembly/BASIC `.sa` files, and run
      `script/check-regex-compatibility lib/linguist/heuristics.yml`.

**In the fork**

- [ ] Add the `Sayanox:` block from section 3 to `lib/linguist/languages.yml`,
      alphabetically between `Sass` and `Scala`, **omitting `language_id`**.
- [ ] Add the grammar with `script/add-grammar https://github.com/<user>/<repo>`
      and fix anything it reports — it will refuse to add a grammar with
      problems.
- [ ] Copy the chosen samples into `samples/Sayanox/`. Do not put a README or any
      non-`.sa` file in that directory: Linguist's sample test attributes every
      file there and a stray Markdown file would be attributed to Markdown and
      fail.
- [ ] Add the `.sa` heuristic to `lib/linguist/heuristics.yml`, keeping the
      `disambiguations` list alphabetised.
- [ ] Run `script/update-ids` to generate `language_id`.
- [ ] Run the test suite: `script/build`, then `bundle exec rake test`.
      The samples test, the languages test and the grammar test must all pass.

**Opening the PR**

- [ ] Use the repository's pull request template. PRs are **not reviewed** if
      the template is not used or not filled in.
- [ ] Tick **I am adding a new language** and complete every sub-item.
- [ ] Paste the search URL with real in-the-wild usage.
- [ ] State the sample licence explicitly. If the samples were written for the
      PR, say so and offer them under Linguist's MIT licence — that is
      explicitly allowed.
- [ ] Link the grammar repository.
- [ ] Give the colour `#19B3A6` and its rationale (maximum distance from
      existing language colours).
- [ ] Mention the heuristic and why `.sa` needs one (assembly and BASIC already
      use the extension in the wild).
- [ ] Do not claim anything is already live on GitHub.com.

**After a merge (if it happens)**

- [ ] Wait for a Linguist release and for GitHub.com to pick it up. A merged PR
      does not change the bar immediately; see Linguist's troubleshooting note
      "My Linguist PR has been merged but GitHub doesn't reflect my changes".
- [ ] Check the repository's language bar and the languages API:
      `https://api.github.com/repos/sayan9168/sayanox/languages`
- [ ] Keep `*.sa linguist-language=Sayanox` in `.gitattributes` as a stable
      override, or remove it if plain extension detection is enough.
- [ ] Update `README.md` and `docs/GITHUB_LANGUAGE.md` to say the bar now shows
      Sayanox — and only then.

---

## 6. Draft pull request text (not submitted)

Ready to paste into `github-linguist/linguist`'s template once section 5's
prerequisites are met. **No PR has been opened.** The usage numbers below are
the 2026-10-09 measurements and must be re-measured before this is used — on
today's numbers the PR would be closed as a hobby language.

> ### Title
>
> Add Sayanox
>
> ### Description
>
> Adds Sayanox, a self-hosting systems programming language that uses the `.sa`
> extension. Sayanox's own compiler is written in Sayanox
> (`selfhost/compiler_min.sa`, ~14,000 lines), as are its formatter, package
> manager and an LSP server.
>
> `.sa` is not currently claimed by any entry in `languages.yml`, but it is not
> unused on GitHub — a large share of indexed `.sa` files are assembly
> (`vonzhou/CSAPP`, `shihyu/CSAPP2e`) or BASIC (`davidlinsley/DragonBasic`).
> This PR therefore includes a `.sa` disambiguation in `heuristics.yml` rather
> than claiming the extension unconditionally.
>
> `languages.yml`, alphabetically between `Sass` and `Scala`, with `language_id`
> generated by `script/update-ids`:
>
> ```yaml
> Sayanox:
>   type: programming
>   color: "#19B3A6"
>   extensions:
>   - ".sa"
>   tm_scope: source.sayanox
>   ace_mode: text
> ```
>
> ### Checklist
>
> - [x] **I am adding a new language.**
>   - [ ] The extension of the new language is used in hundreds of repositories
>     on GitHub.com.
>     - Search results for each extension:
>       - https://github.com/search?type=code&q=NOT+is%3Afork+path%3A*.sa+hold+show+give
>     - **Left unticked on purpose until real adoption exists.** Measured
>       2026-10-09, `extension:sa hold show` returns 948 hits and
>       `extension:sa sayanox` returns 58, both dominated by a single
>       repository. This does not meet the 2000-file and distribution
>       requirement, which is why this text is a draft.
>   - [x] I have included a real-world usage sample for all extensions added in
>     this PR:
>     - Sample source(s): written for this PR from the reference implementation
>       at https://github.com/sayan9168/sayanox (see `samples/Sayanox/`)
>     - Sample license(s): MIT, the licence that covers Linguist
>   - [x] I have included a syntax highlighting grammar:
>     https://github.com/sayan9168/sayanox-tmgrammar *(to be published)*
>   - [x] I have added a color
>     - Hex value: `#19B3A6`
>     - Rationale: selected for maximum perceptual distance from the colours
>       already in `languages.yml` — nearest-neighbour RGB distance 0.099 across
>       all 624 existing colours, and well separated from C `#555555`, C++
>       `#f34b7d` and Makefile `#427819`.
>   - [x] I have updated the heuristics to distinguish my language from others
>     using the same extension: `.sa` disambiguation added, checked with
>     `script/check-regex-compatibility`.

---

## 7. References

- [Linguist `languages.yml`](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)
- [Linguist `CONTRIBUTING.md` — Adding a language](https://github.com/github-linguist/linguist/blob/main/CONTRIBUTING.md#adding-a-language)
- [Linguist overrides](https://github.com/github-linguist/linguist/blob/main/docs/overrides.md)
- [Linguist `heuristics.yml`](https://github.com/github-linguist/linguist/blob/main/lib/linguist/heuristics.yml)
- [Allowed grammar licences](https://github.com/github-linguist/linguist/blob/main/vendor/licenses/config.yml)
- [Troubleshooting: merged but GitHub does not reflect it](https://github.com/github-linguist/linguist/blob/main/docs/troubleshooting.md#my-linguist-pr-has-been-merged-but-github-doesnt-reflect-my-changes)
- [GitHub code search limitations](https://docs.github.com/en/search-github/github-code-search/about-github-code-search)
- Local: [`GITHUB_LANGUAGE.md`](GITHUB_LANGUAGE.md), [`SYNTAX.md`](SYNTAX.md),
  [`GENERICS.md`](GENERICS.md), [`STATUS.md`](STATUS.md)
