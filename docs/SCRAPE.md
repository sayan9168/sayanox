# sayascrape: a Scrapy-style crawler for authorized targets

`sayascrape/` is a small crawler with a Scrapy-like shape: a `Spider` class
with `start_urls` and a `parse()` callback that yields items or follow-up
`Request`s, plus item pipelines. It uses only the Python standard library.

It is for **sites you own or have written permission to test**. The safety
rules below are enforced in code. They are not just advice.

## Safety rules (enforced)

| Rule | Enforcement |
|---|---|
| Authorized targets only | `authorized = True` on the spider, or `--authorized` on the CLI. Without it, nothing is fetched. |
| Scope allowlist | `allowed_domains` is required and non-empty. Start URLs and every followed link must match it. Subdomains match; `notexample.com` does not match `example.com`. Redirects that leave the list are not followed. |
| robots.txt | Fetched per host and honoured for our user agent. There is no switch to turn this off. If robots.txt returns a 5xx or cannot be read, the host is treated as disallowed (fail closed). A 4xx means no rules. |
| Politeness | One request at a time. `download_delay` seconds between requests to one host (default 1.0). Request timeout and a response size cap (`max_bytes`). |
| Caps | `max_pages` and `max_depth`. The crawl stops when either is reached. |
| Method | HTTP GET only. No forms, cookies, logins, request bodies, JavaScript, or payloads. Only HTML and text responses are parsed. |

Out of scope on purpose: exploit or payload tooling, brute-force or
credential guessing, fuzzing, and anything that bypasses robots.txt or the
allowlist. Those are not in this library and will not be added.

## Command line

```sh
python3 -m sayascrape crawl \
  --url https://site.example.test/ \
  --allow site.example.test \
  --authorized \
  --max-pages 100 --max-depth 3 --delay 1.0 \
  --out items.jsonl
```

Without `--authorized`, the command exits with status 2 and writes no file.
The stats line (fetched, items, skipped_robots, skipped_scope, and so on) is
printed as JSON when the crawl ends.

## Writing a spider

```python
from sayascrape import Crawler, JsonLinesPipeline, Request, Spider

class Products(Spider):
    name = "products"
    allowed_domains = ["shop.example.test"]     # the allowlist (required)
    start_urls = ["https://shop.example.test/"]
    authorized = True                           # you own it or have permission
    max_pages = 200
    max_depth = 3
    download_delay = 1.0

    def parse(self, response):
        for attrs, text in response.page.find("span", class_="price"):
            yield {"url": response.url, "price": text}
        for link in response.links():
            yield Request(link, depth=response.depth + 1)

pipe = JsonLinesPipeline("products.jsonl")
stats = Crawler(Products(), pipelines=[pipe]).run()["stats"]
pipe.close()
```

`Response` offers `text`, `title()`, `links()`, `page`, `status`, `headers`,
and `depth`. `HTMLPage` offers `title()`, `meta(name)`, `text()`, `links()`,
and `find(tag, **attrs)`, where `class_="x"` matches one class name.

## Tests

`make test-scrape` runs `python3 -m unittest sayascrape.test_sayascrape`.
The tests start a local server on 127.0.0.1. They cover refusal without
authorization, empty or outside allowlists, subdomain matching, robots.txt
disallow, robots 500 failing closed, robots 404 allowing, out-of-scope
redirects, the page and depth caps, the per-host delay, callback errors
not stopping the crawl, JSON-lines export, and HTML parsing.

## Limits

* Sequential only, so it is polite but slow. No concurrency.
* HTML parsing is `html.parser`-based. There is no CSS or XPath engine.
  `find()` covers tag and attribute or class lookups.
* No persistent job queue, so a crawl cannot resume after a restart.
