# sayascrape: a crawler for authorized targets, in Sayanox

`sayascrape/` is a small crawler with a Scrapy-like shape, written in Sayanox:
a crawler driver, a set of safety rules enforced in the program, and a page
parser. It fetches pages with the `http_get` builtin (see
[`BUILTINS.md`](BUILTINS.md)) and prints a line per decision instead of
yielding Python objects.

The Python package that used to live here (`__init__.py`, `core.py`,
`parse.py`, `export.py`, `test_sayascrape.py`) was deleted on 2026-10-21 with
its `make test-scrape` target. It was the last Python in the repository, it
was never on a bootstrap path, and it duplicated the rules the Sayanox
crawler already enforces. Deleting it removed a dependency; it did not remove
a feature.

It is for **sites you own or have written permission to test**. The safety
rules below are enforced in code. They are not just advice.

## Safety rules (enforced)

| Rule | Enforcement |
|---|---|
| Authorized targets only | `--authorized` must be the first argument. Without it, the program prints `REFUSED` and makes no request. |
| Scope allowlist | `ALLOWED_HOST` (`host[:port]`) is required. Start URL and every followed link must match it exactly; other links are ignored. |
| robots.txt | Fetched first. `User-agent: *` and `User-agent: sayanox` `Disallow` prefixes are respected. An empty, missing or unreachable robots.txt stops the crawl (`REFUSED`), because `http_get` returns `""` for both a 404 and a network error — the host is treated as disallowed (fail closed). There is no switch to turn this off. |
| Politeness | One request per second: `http_get` waits at least 1 s between requests. |
| Caps | `MAX_PAGES` (1..50, default 20) and `MAX_DEPTH` (0..5, default 2). The crawl stops when either is reached. |
| Method | HTTP GET only. No forms, cookies, logins, request bodies, JavaScript, or payloads. |

Out of scope on purpose: exploit or payload tooling, brute-force or
credential guessing, fuzzing, and anything that bypasses robots.txt or the
allowlist. Those are not in this program and will not be added.

## Running it

It is a gen2 (full-language) program: it uses typed `str` helper functions,
which the pure-min seed and the native backend do not accept.

```sh
selfhost/gen2 sayascrape/crawl.sa crawl.c && cc -O2 -o crawl crawl.c -lm
./crawl --authorized http://HOST:PORT/index.html HOST:PORT [MAX_PAGES] [MAX_DEPTH]
```

Output is line-oriented:

```
ROBOTS: ...
FETCH depth=D links=N URL
SKIP robots: URL
FAILED: URL
DONE pages=N
```

There is no exit status (gen2 has no `exit`), so refusals are read from
stdout: a run that is not authorized, or that has no start URL or
`ALLOWED_HOST`, prints `REFUSED` and stops.

## Tests

`make test-sayacrawl` builds and runs it against a local HTTP server on
127.0.0.1 only, and checks exact output for the crawl, both caps and each
refusal. It is part of `make test-network`, which is optional and never a
bootstrap prerequisite.

## Limits

* Sequential only, so it is polite but slow. No concurrency.
* No HTML engine: links are found by a small scanner, so unusual markup is
  skipped rather than guessed at.
* No persistent job queue, so a crawl cannot resume after a restart.
* A site without robots.txt is refused, where the old Python version allowed
  it on a 404.
