"""python -m sayascrape crawl --url URL --allow HOST [options]

Every crawl must name its allowlist and pass --authorized. robots.txt is
always honoured; there is no option to turn it off.
"""

import argparse
import json
import sys

from .core import Crawler, ScopeError, Spider
from .export import JsonLinesPipeline


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="sayascrape")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("crawl", help="crawl an authorized site and export items")
    c.add_argument("--url", action="append", required=True, help="start URL (repeatable)")
    c.add_argument("--allow", action="append", required=True, help="allowed host (repeatable)")
    c.add_argument("--authorized", action="store_true",
                   help="confirm you own the target or have written permission to crawl it")
    c.add_argument("--max-pages", type=int, default=50)
    c.add_argument("--max-depth", type=int, default=2)
    c.add_argument("--delay", type=float, default=1.0, help="seconds between requests to one host")
    c.add_argument("--out", default="items.jsonl")
    args = ap.parse_args(argv)

    class CliSpider(Spider):
        name = "cli"
        allowed_domains = args.allow
        start_urls = args.url
        authorized = args.authorized
        max_pages = args.max_pages
        max_depth = args.max_depth
        download_delay = args.delay

    try:
        crawler = Crawler(CliSpider())      # validates scope and authorization first
    except ScopeError as e:
        print(f"sayascrape: {e}", file=sys.stderr)
        return 2
    pipe = JsonLinesPipeline(args.out)
    crawler.pipelines.append(pipe)
    try:
        result = crawler.run()
    finally:
        pipe.close()
    print(json.dumps(result["stats"], sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
