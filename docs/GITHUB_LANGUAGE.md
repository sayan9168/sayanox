# GitHub language recognition

For the full plan, the prepared samples and grammar, the exact `languages.yml`
snippet, the upstream PR checklist and the draft PR text, see
**[`LINGUIST.md`](LINGUIST.md)**. This page is the short version.

## Current state

Sayanox files use `.sa`, but the upstream GitHub Linguist language registry
currently has neither a `Sayanox` language entry nor a `.sa` extension mapping.
Verified against `lib/linguist/languages.yml` on 2026-10-09: no `Sayanox:` entry
exists, and no language claims `.sa`. GitHub's language API for the repository
consequently reports C, Makefile, Shell and C++, but not Sayanox.

Because `.sa` files are invisible to Linguist, the roughly 758 KB of Sayanox
source in this repository — about 65% of its source bytes — does not reach the
language bar at all. What the bar shows is what is left: the hand-written C
bootstrap seed and native backend, the `Makefile` and the shell scripts.

A project-local `.gitattributes` file cannot create a new Linguist language.
The upstream Linguist override guide explicitly says an unregistered language
will not appear in language statistics even when `linguist-language` and
`linguist-detectable` are set. Setting `.sa` to Rust, SAS, Python, C or another
existing language would only mislabel the source, so this repository does not do
that.

## What this repository has done

- Added a root `.gitattributes` that marks `.sa` as `linguist-detectable` and
  pre-declares `linguist-language=Sayanox`. Both are inert until Linguist learns
  the language; neither mislabels anything today.
- Marked the generated artifacts as `linguist-generated` — 184 tracked files:
  the 159 base64 chunk files, the chunk directories under `selfhost/`, the build
  logs in `docs/logs/`, and the C that the self-hosting compilers emit
  (`selfhost/gen*.c`, `tools/sxfmt.c` and friends). The hand-written C — the
  seed, the native AOT backend, the stage-2 template — is left visible on
  purpose, as are the READMEs that sit inside the chunk directories.
- Added `samples/Sayanox/` with six sample programs in the layout Linguist
  expects, verified by compiling and running them on seed-min, gen2 and
  native AOT.
- Added `grammars/sayanox.tmLanguage.json`, a `source.sayanox` TextMate grammar
  validated with a real TextMate tokenizer against the samples and against
  14,000 lines of the self-hosted compiler.

## What is still required for a real fix

1. Add Sayanox to [`github-linguist/linguist`'s language registry](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml),
   with `.sa` as its extension and a stable TextMate scope such as
   `source.sayanox`. The exact snippet is in [`LINGUIST.md`](LINGUIST.md#3-the-exact-languagesyml-snippet).
2. Publish the TextMate grammar as its own public repository, because Linguist
   vendors grammars as git submodules with `script/add-grammar <repo url>`.
3. Add real-world samples and a `.sa` disambiguation heuristic — about 24,000
   indexed `.sa` files on GitHub are assembly or BASIC, so claiming the
   extension without one would misclassify them.
4. Have the upstream change reviewed and merged, then allow GitHub to refresh
   the repository's language statistics.
5. Once the language exists upstream, the `*.sa linguist-language=Sayanox` line
   already in `.gitattributes` keeps detection pinned.

This repository can prepare and test its syntax description, but only the
Linguist project can register a new key for GitHub.com. Its contribution policy
also requires sufficient widespread public GitHub usage and says very new or
hobby languages will not be accepted. Measured on 2026-10-09, every search that
actually identifies Sayanox source resolves to this one repository, so an
upstream request is not eligible yet and **no pull request has been opened**.
[`LINGUIST.md`](LINGUIST.md#4-the-blocking-problem-in-the-wild-usage) has the
queries, the numbers and what would change them.

Nothing here claims that GitHub's language bar already shows Sayanox.

References:

- [`LINGUIST.md`](LINGUIST.md) — the full plan, checklist and draft PR text
- [Linguist overrides](https://github.com/github-linguist/linguist/blob/main/docs/overrides.md)
- [Linguist language registry](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)
- [Linguist contribution guide](https://github.com/github-linguist/linguist/blob/main/CONTRIBUTING.md#adding-a-language)
