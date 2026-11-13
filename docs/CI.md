# CI/CD

Four workflows live in `.github/workflows/`. Three of them protect the
bootstrap and one publishes documentation.

| Workflow | Trigger | Job(s) | Purpose |
| --- | --- | --- | --- |
| `ci.yml` | push/PR to `main` | `migrated-gates`, `full-acceptance-blocker` | Fast migrated gates, then the complete original acceptance chain |
| `full-bootstrap.yml` | weekly cron, manual | `full-bootstrap` | Clean checkout, native reconstruction, full acceptance |
| `release.yml` | `v*` tag, manual | `release` | Acceptance, evidence, package, publish |
| `docs.yml` | docs changes, manual | `docs-site` | Render `docs/` and publish a Vercel preview |

## The entry pin is the first gate, on purpose

Every job starts with:

```sh
sha256sum -c bootstrap/sx.sha256
./sx ci-guard
./sx verify-entry
```

`bootstrap/sx.sha256` pins the reviewed entry (`sx`) and every source that
feeds it. `verify-entry` then rebuilds `tools/sxbuild.sa` with the pinned
native anchor and compares the result byte for byte with `sx`.

The two checks fail closed in different ways:

* A changed source that was never re-pinned fails `sha256sum -c` with a single
  `FAILED` line.
* A re-pinned source whose checked-in `sx` was not rebuilt fails
  `verify-entry` with `sx does not match current Sayanox driver sources`.

**Rule for changing driver sources.** If you edit any file in the
`bootstrap/sx.sha256` manifest - including `tools/sxbuild.sa` - you must either
revert the edit or do all three of:

```sh
./sx tool sxbuild /tmp/sx.review     # rebuild the entry from the sources
cmp /tmp/sx.review sx                # review what changed, byte for byte
# then install the reviewed binary over sx and re-pin both sx and the source
```

Nothing in CI rewrites `sx` or the manifest for you. An unreviewed source edit
that skips this step is exactly what broke `main` on 2026-11-12: the driver was
modified, the entry and its pin were not, and both jobs died at the first step.

## The CI guard forbids host runtimes

`./sx ci-guard` installs failing shims for `make`, `python`, `python3`, `node`,
`ruby`, `perl`, `curl` and `wget` into `$RUNNER_TEMP/sayanox-ci-guard/bin` and
prepends that directory to `GITHUB_PATH`. Every later step of that job inherits
them, so any accidental invocation fails immediately and leaves evidence that
`ci-guard-check` reports - even when the failing gate is masked by `if: always()`.

Consequences:

* No step inside an armed job may call `node`, `npx`, a shell recipe or a
  network client. That is why documentation deployment is **not** part of
  `ci.yml`.
* `actions/checkout` and `gh` are leaf host boundaries; the guards arm after
  checkout and before any Sayanox gate.

## Documentation previews (`docs.yml`)

`tools/docsite.mjs` renders `docs/*.md` into a static site with no dependencies
beyond the Node runtime that GitHub runners already provide:

```sh
node tools/docsite.mjs docs site   # every docs/*.md -> site/
```

`docs.yml` renders that site and publishes it with the Vercel CLI. It skips the
deploy - without failing the workflow - when the token is absent, so a fork or a
fresh clone never turns the pipeline red.

To enable real deployments, configure the repository:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `VERCEL_TOKEN` | A Vercel token with deploy rights |
| Variable (optional) | `VERCEL_ORG_ID` | Team/user id, pins the target account |
| Variable (optional) | `VERCEL_PROJECT_ID` | Existing project id, avoids creating one |

Without `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID` the CLI creates (or reuses) a
project named after the deployed directory and prints its preview URL, which the
workflow comments on the pull request.

`.vercel/` and `site/` are ignored by git; the site is a build artifact.

## Permissions

`ci.yml`, `full-bootstrap.yml` and `docs.yml` request `contents: read`.
Only `release.yml` asks for `contents: write`, because publishing a release
writes to this repository. A documentation preview never needs write access to
anything but the pull request it comments on, which is scoped separately in
`docs.yml`.
