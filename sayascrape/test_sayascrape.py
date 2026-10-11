"""Tests for sayascrape. They run a local HTTP server on 127.0.0.1 and never
touch the internet. Run: python3 -m unittest sayascrape.test_sayascrape"""

import http.server
import json
import os
import tempfile
import threading
import unittest

from sayascrape import (Crawler, HTMLPage, JsonLinesPipeline, Request, ScopeError,
                        Spider, host_in_scope, in_scope, normalize_url)

PAGES = {
    "/": '<html><head><title>Home</title><meta name="description" content="d1"></head>'
         '<body><a href="/a">a</a> <a href="/b.html#x">b</a> <a href="/private/x">p</a>'
         '<a href="http://localhost:1/other">external</a><a href="mailto:x@y">m</a></body></html>',
    "/a": '<html><title>A</title><body><a href="/c">c</a><a href="/">home</a></body></html>',
    "/b.html": '<html><title>B</title><body><a href="/c">c</a></body></html>',
    "/c": '<html><title>C</title><body>deep</body></html>',
    "/private/x": '<html><title>secret</title></html>',
    "/redir": None,  # answered with a redirect in the handler
}
ROBOTS = "User-agent: *\nDisallow: /private/\n"


class Site(http.server.BaseHTTPRequestHandler):
    hits = []
    robots_status = 200

    def log_message(self, *a):
        pass

    def do_GET(self):
        Site.hits.append(self.path)
        if self.path == "/robots.txt":
            if Site.robots_status != 200:
                self.send_response(Site.robots_status)
                self.end_headers()
                return
            return self._send(200, ROBOTS, "text/plain")
        if self.path == "/redir":
            self.send_response(302)
            self.send_header("Location", "http://localhost:1/elsewhere")
            self.end_headers()
            return
        body = PAGES.get(self.path)
        if body is None:
            return self._send(404, "nope", "text/plain")
        self._send(200, body, "text/html; charset=utf-8")

    def _send(self, code, body, ctype):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


class ServerCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Site)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        Site.hits = []
        Site.robots_status = 200

    @property
    def base(self):
        return f"http://127.0.0.1:{self.port}"

    def spider(self, **kw):
        class S(Spider):
            name = "t"
            allowed_domains = ["127.0.0.1"]
            authorized = True
            download_delay = 0.0
            start_urls = [self.base + "/"]
        for k, v in kw.items():
            setattr(S, k, v)
        return S()


class TestSafetyRefusals(unittest.TestCase):
    def test_refuses_without_authorization(self):
        class S(Spider):
            allowed_domains = ["example.com"]
            start_urls = ["https://example.com/"]
        with self.assertRaises(ScopeError):
            Crawler(S())

    def test_refuses_empty_allowlist(self):
        class S(Spider):
            authorized = True
            start_urls = ["https://example.com/"]
        with self.assertRaises(ScopeError):
            Crawler(S())

    def test_refuses_start_url_outside_allowlist(self):
        class S(Spider):
            authorized = True
            allowed_domains = ["example.com"]
            start_urls = ["https://evil.test/"]
        with self.assertRaises(ScopeError):
            Crawler(S())

    def test_scope_matching(self):
        self.assertTrue(host_in_scope("example.com", ["example.com"]))
        self.assertTrue(host_in_scope("a.example.com", ["example.com"]))
        self.assertFalse(host_in_scope("notexample.com", ["example.com"]))
        self.assertFalse(host_in_scope("example.com.evil.test", ["example.com"]))
        self.assertFalse(in_scope("ftp://example.com/", ["example.com"]))

    def test_normalize(self):
        self.assertEqual(normalize_url("HTTP://Ex.COM:80/a#f"), "http://ex.com/a")
        self.assertEqual(normalize_url("https://ex.com"), "https://ex.com/")


class TestCrawl(ServerCase):
    def test_crawl_follows_scope_and_robots(self):
        sp = self.spider(max_pages=20, max_depth=3)
        result = Crawler(sp).run()
        titles = sorted(i.get("title") for i in result["items"])
        self.assertIn("Home", titles)
        self.assertIn("C", titles)
        self.assertNotIn("secret", titles)            # /private/ is disallowed by robots.txt
        self.assertNotIn("/private/x", Site.hits)     # never requested
        self.assertNotIn("/redir", Site.hits)
        self.assertGreaterEqual(result["stats"].get("skipped_robots", 0), 1)
        self.assertGreaterEqual(result["stats"].get("skipped_scope", 0), 1)  # localhost:1 link

    def test_max_pages_cap(self):
        sp = self.spider(max_pages=2, max_depth=5)
        result = Crawler(sp).run()
        self.assertLessEqual(result["stats"]["fetched"], 2)

    def test_max_depth_cap(self):
        sp = self.spider(max_pages=50, max_depth=1)
        result = Crawler(sp).run()
        titles = [i.get("title") for i in result["items"]]
        self.assertIn("A", titles)
        self.assertNotIn("C", titles)       # /c is at depth 2
        self.assertGreaterEqual(result["stats"].get("skipped_depth", 0), 1)

    def test_robots_500_fails_closed(self):
        Site.robots_status = 500
        sp = self.spider(max_pages=20)
        result = Crawler(sp).run()
        self.assertEqual(result["stats"].get("fetched", 0), 0)
        self.assertEqual(result["items"], [])

    def test_robots_404_means_allowed(self):
        Site.robots_status = 404
        sp = self.spider(max_pages=20, max_depth=1)
        result = Crawler(sp).run()
        self.assertIn("/private/x", Site.hits)      # no robots rules: /private/ is allowed
        self.assertIn("secret", [i.get("title") for i in result["items"]])

    def test_delay_is_enforced_per_host(self):
        slept = []
        clock = [0.0]

        def fake_clock():
            return clock[0]

        def fake_sleep(s):
            slept.append(s)
            clock[0] += s

        sp = self.spider(max_pages=3, max_depth=1, download_delay=2.0)
        Crawler(sp, clock=fake_clock, sleep=fake_sleep).run()
        self.assertTrue(slept, "expected the crawler to wait between requests to one host")
        self.assertTrue(all(s > 0 for s in slept))

    def test_callback_error_does_not_stop_crawl(self):
        class S(Spider):
            name = "boom"
            allowed_domains = ["127.0.0.1"]
            authorized = True
            download_delay = 0.0
            start_urls = [self.base + "/"]
            max_depth = 1

            def parse(self, response):
                if response.url.endswith("/a"):
                    raise RuntimeError("bad page")
                yield {"url": response.url}
                for link in response.links():
                    yield Request(link, depth=response.depth + 1)

        result = Crawler(S()).run()
        self.assertEqual(result["stats"].get("callback_errors"), 1)
        self.assertTrue(any(i["url"].endswith("/b.html") for i in result["items"]))

    def test_pipeline_writes_jsonl(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "items.jsonl")
            pipe = JsonLinesPipeline(path)
            Crawler(self.spider(max_pages=5, max_depth=1), pipelines=[pipe]).run()
            pipe.close()
            with open(path, encoding="utf-8") as fh:
                rows = [json.loads(line) for line in fh if line.strip()]
            self.assertTrue(rows)
            self.assertTrue(all("url" in r for r in rows))


class TestParsing(unittest.TestCase):
    def test_links_title_meta_text(self):
        html = ('<html><head><title> My  Page </title><meta name="Description" content="hi">'
                '<script>var x = "hidden";</script></head>'
                '<body><p>Hello <b>world</b></p>'
                '<a href="rel/x">r</a><a href="https://other.test/y#frag">o</a>'
                '<a href="javascript:void(0)">j</a><a href="rel/x">dup</a></body></html>')
        page = HTMLPage(html, base_url="http://ex.test/dir/index.html")
        self.assertEqual(page.title(), "My Page")
        self.assertEqual(page.meta("description"), "hi")
        self.assertIn("Hello world", page.text())
        self.assertNotIn("hidden", page.text())
        self.assertEqual(page.links(), ["http://ex.test/dir/rel/x", "https://other.test/y"])

    def test_find_by_class(self):
        html = '<span class="price big">9</span><span class="x">1</span><h1>T</h1>'
        page = HTMLPage(html)
        self.assertEqual([t for _, t in page.find("span", class_="price")], ["9"])
        self.assertEqual([t for _, t in page.find("h1")], ["T"])


if __name__ == "__main__":
    unittest.main()
