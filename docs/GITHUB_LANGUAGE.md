# GitHub language recognition

## Current state

Sayanox files use `.sa`, but the upstream GitHub Linguist language registry
currently has neither a `Sayanox` language entry nor a `.sa` extension mapping.
GitHub's language API for the repository consequently reports C, Makefile,
Shell and C++, but not Sayanox.

A project-local `.gitattributes` file cannot create a new Linguist language.
The upstream Linguist override guide explicitly says an unregistered language
will not appear in language statistics even when `linguist-language` and
`linguist-detectable` are set. Setting `.sa` to Rust, SAS or another existing
language would only mislabel the source, so this repository does not do that.

## What is required for a real fix

1. Add Sayanox to [`github-linguist/linguist`'s language registry](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml),
   with `.sa` as its extension and a stable TextMate scope such as
   `source.sayanox`.
2. Provide a TextMate grammar and Linguist fixtures/tests for the actual Sayanox
   syntax, then have the upstream change reviewed and merged.
3. Once the language exists upstream, add `*.sa linguist-language=Sayanox` to
   this repository's `.gitattributes` if detection still needs an override.
4. Allow GitHub to refresh the repository's language statistics.

This repository can prepare and test its syntax description, but only the
Linguist project can register a new key for GitHub.com. Its contribution policy
also requires sufficient widespread public GitHub usage and says very new or
hobby languages will not be accepted. Sayanox may therefore need adoption
outside this repository before an upstream request is eligible. The current
local changes do not claim that GitHub's language bar already shows Sayanox.

References:

- [Linguist overrides](https://github.com/github-linguist/linguist/blob/main/docs/overrides.md)
- [Linguist language registry](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)
