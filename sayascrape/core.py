"""sayascrape core: a small Scrapy-style crawler for AUTHORIZED targets.

Safety model (all enforced in code, not just documented):

* Scope is an allowlist. A spider must name its `allowed_domains`; a URL is
  fetched only if its host is listed (or is a subdomain of a listed host).
  Redirects that leave the scope are not followed.
* The crawl must be explicitly authorized (`Spider.authorized = True` or
  `--authorized` on the CLI). Without it, nothing is fetched.
* robots.txt is fetched per host and honoured for our user agent. If
  robots.txt cannot be read because of a server error or network failure,
  the host is treated as disallowed (fail closed).
* Politeness: one request at a time, a minimum delay per host
  (`download_delay`), a request timeout, and a response size cap.
* Caps: `max_pages` and `max_depth`. The crawl stops when either is reached.
* Only HTTP GET of HTML/text pages. No forms, no cookies, no authentication,
  no JavaScript execution, no request bodies, no payload generation.
"""

from __future__ import annotations

import collections
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from dataclasses import dataclass, field
from typing import Any, Callable, Dict, Iterable, Iterator, List, Optional, Union

from .parse import HTMLPage

DEFAULT_USER_AGENT = "sayascrape/0.1 (+authorized-crawl; contact the site owner)"


class ScopeError(Exception):
    """A URL, or a spider configuration, is outside the authorized scope."""


@dataclass
class Request:
    url: str
    depth: int = 0
    callback: Optional[str] = None
    meta: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Response:
    url: str
    status: int
    headers: Dict[str, str]
    body: bytes
    depth: int
    meta: Dict[str, Any]
    _page: Optional[HTMLPage] = None

    @property
    def text(self) -> str:
        charset = "utf-8"
        ctype = self.headers.get("Content-Type", "")
        if "charset=" in ctype:
            charset = ctype.split("charset=", 1)[1].split(";")[0].strip() or "utf-8"
        try:
            return self.body.decode(charset, errors="replace")
        except LookupError:
            return self.body.decode("utf-8", errors="replace")

    @property
    def page(self) -> HTMLPage:
        if self._page is None:
            self._page = HTMLPage(self.text, base_url=self.url)
        return self._page

    def links(self) -> List[str]:
        return self.page.links()

    def title(self) -> str:
        return self.page.title()


def normalize_url(url: str) -> str:
    """Canonical form used for de-duplication: lowercase scheme and host,
    no fragment, default ports removed, empty path becomes '/'."""
    parts = urllib.parse.urlsplit(url)
    scheme = parts.scheme.lower()
    host = (parts.hostname or "").lower()
    port = parts.port
    if port and not ((scheme == "http" and port == 80) or (scheme == "https" and port == 443)):
        netloc = f"{host}:{port}"
    else:
        netloc = host
    path = parts.path or "/"
    return urllib.parse.urlunsplit((scheme, netloc, path, parts.query, ""))


def host_in_scope(host: str, allowed: Iterable[str]) -> bool:
    host = (host or "").lower()
    for dom in allowed:
        dom = dom.lower().lstrip(".")
        if host == dom or host.endswith("." + dom):
            return True
    return False


class Spider:
    """Subclass and override `parse`. Class attributes configure the crawl."""

    name: str = "spider"
    allowed_domains: List[str] = []
    start_urls: List[str] = []
    authorized: bool = False          # must be set to True by the operator
    max_pages: int = 50
    max_depth: int = 2
    download_delay: float = 1.0       # seconds between requests to one host
    timeout: float = 10.0
    max_bytes: int = 1_000_000
    user_agent: str = DEFAULT_USER_AGENT
    respect_robots: bool = True

    def parse(self, response: Response) -> Iterator[Union[Dict[str, Any], Request]]:
        """Default: yield the title and follow every in-scope link."""
        yield {"url": response.url, "title": response.title()}
        for link in response.links():
            yield Request(link, depth=response.depth + 1)

    def validate(self) -> None:
        if not self.authorized:
            raise ScopeError(
                "refusing to crawl: the spider is not marked authorized "
                "(set authorized = True only for targets you own or have written permission to test)"
            )
        if not self.allowed_domains:
            raise ScopeError("refusing to crawl: allowed_domains is empty (an allowlist is required)")
        if not self.start_urls:
            raise ScopeError("no start_urls")
        for url in self.start_urls:
            if not in_scope(url, self.allowed_domains):
                raise ScopeError(f"start URL is outside allowed_domains: {url}")
        if self.max_pages < 1 or self.max_depth < 0:
            raise ScopeError("max_pages must be >= 1 and max_depth >= 0")
        if self.download_delay < 0:
            raise ScopeError("download_delay must be >= 0")


def in_scope(url: str, allowed: Iterable[str]) -> bool:
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ("http", "https"):
        return False
    return host_in_scope(parts.hostname or "", allowed)


class _NoRedirectOutOfScope(urllib.request.HTTPRedirectHandler):
    """Follow redirects only while they stay inside the allowlist."""

    def __init__(self, allowed: Iterable[str]):
        self.allowed = list(allowed)

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not in_scope(newurl, self.allowed):
            raise urllib.error.URLError(f"redirect leaves the allowlist: {newurl}")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Fetcher:
    """Synchronous HTTP GET with a user agent, timeout and size cap."""

    def __init__(self, spider: Spider):
        self.spider = spider
        self.opener = urllib.request.build_opener(_NoRedirectOutOfScope(spider.allowed_domains))

    def get(self, url: str) -> Optional[Response]:
        req = urllib.request.Request(url, headers={"User-Agent": self.spider.user_agent})
        try:
            with self.opener.open(req, timeout=self.spider.timeout) as resp:
                status = resp.status
                headers = {k: v for k, v in resp.headers.items()}
                body = resp.read(self.spider.max_bytes + 1)
        except urllib.error.HTTPError as e:
            status = e.code
            headers = {k: v for k, v in (e.headers.items() if e.headers else [])}
            body = b""
        except (urllib.error.URLError, OSError, ValueError):
            return None
        if len(body) > self.spider.max_bytes:
            body = body[: self.spider.max_bytes]
        ctype = headers.get("Content-Type", "")
        if body and "html" not in ctype and "text" not in ctype:
            body = b""  # only pages we can read are parsed
        return Response(url=url, status=status, headers=headers, body=body, depth=0, meta={})


class RobotsCache:
    """robots.txt per host, fetched once. Fails closed on server errors."""

    def __init__(self, fetcher: Fetcher, user_agent: str):
        self.fetcher = fetcher
        self.user_agent = user_agent
        self._cache: Dict[str, Optional[urllib.robotparser.RobotFileParser]] = {}

    def allowed(self, url: str) -> bool:
        parts = urllib.parse.urlsplit(url)
        origin = f"{parts.scheme}://{parts.netloc}"
        if origin not in self._cache:
            self._cache[origin] = self._load(origin)
        rp = self._cache[origin]
        if rp is None:          # could not read robots.txt: fail closed
            return False
        return rp.can_fetch(self.user_agent, url)

    def _load(self, origin: str) -> Optional[urllib.robotparser.RobotFileParser]:
        robots_url = origin + "/robots.txt"
        rp = urllib.robotparser.RobotFileParser()
        req = urllib.request.Request(robots_url, headers={"User-Agent": self.user_agent})
        try:
            with self.fetcher.opener.open(req, timeout=self.fetcher.spider.timeout) as resp:
                body = resp.read(500_000).decode("utf-8", errors="replace")
            rp.parse(body.splitlines())
            return rp
        except urllib.error.HTTPError as e:
            if 400 <= e.code < 500:   # no robots.txt: everything allowed
                rp.parse([])
                return rp
            return None               # 5xx: fail closed
        except (urllib.error.URLError, OSError, ValueError):
            return None


class Crawler:
    """Runs one spider. `run()` returns the items and a stats dictionary."""

    def __init__(self, spider: Spider, pipelines: Optional[List[Callable[[Dict[str, Any]], None]]] = None,
                 clock: Callable[[], float] = time.monotonic,
                 sleep: Callable[[float], None] = time.sleep):
        spider.validate()
        self.spider = spider
        self.pipelines = list(pipelines or [])
        self.clock = clock
        self.sleep = sleep
        self.fetcher = Fetcher(spider)
        self.robots = RobotsCache(self.fetcher, spider.user_agent)
        self.stats: Dict[str, int] = collections.Counter()
        self.items: List[Dict[str, Any]] = []
        self._seen: set = set()
        self._last_hit: Dict[str, float] = {}
        self._queue: collections.deque = collections.deque()

    def _enqueue(self, req: Request) -> None:
        if req.depth > self.spider.max_depth:
            self.stats["skipped_depth"] += 1
            return
        if not in_scope(req.url, self.spider.allowed_domains):
            self.stats["skipped_scope"] += 1
            return
        key = normalize_url(req.url)
        if key in self._seen:
            self.stats["skipped_duplicate"] += 1
            return
        self._seen.add(key)
        self._queue.append(req)

    def _wait_for_host(self, url: str) -> None:
        host = urllib.parse.urlsplit(url).netloc
        last = self._last_hit.get(host)
        if last is not None:
            remaining = self.spider.download_delay - (self.clock() - last)
            if remaining > 0:
                self.sleep(remaining)
        self._last_hit[host] = self.clock()

    def run(self) -> Dict[str, Any]:
        for url in self.spider.start_urls:
            self._enqueue(Request(url, depth=0))
        fetched = 0
        while self._queue and fetched < self.spider.max_pages:
            req = self._queue.popleft()
            if self.spider.respect_robots and not self.robots.allowed(req.url):
                self.stats["skipped_robots"] += 1
                continue
            self._wait_for_host(req.url)
            resp = self.fetcher.get(req.url)
            fetched += 1
            if resp is None:
                self.stats["errors"] += 1
                continue
            resp.depth = req.depth
            resp.meta = req.meta
            self.stats["fetched"] += 1
            if resp.status >= 400:
                self.stats[f"status_{resp.status}"] += 1
                continue
            try:
                outputs = list(self.spider.parse(resp) or [])
            except Exception as exc:  # a broken callback must not stop the crawl
                self.stats["callback_errors"] += 1
                self.stats["last_callback_error"] = str(exc)[:200]
                continue
            for out in outputs:
                if isinstance(out, Request):
                    self._enqueue(out)
                elif isinstance(out, dict):
                    self.items.append(out)
                    for pipe in self.pipelines:
                        pipe(out)
                    self.stats["items"] += 1
        self.stats["pending"] = len(self._queue)
        return {"items": self.items, "stats": dict(self.stats)}
