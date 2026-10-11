"""HTML extraction with the standard library only.

HTMLPage gives Scrapy-like helpers: links(), title(), meta(name), text(),
and find(tag, **attrs) which returns (attributes, text) pairs.
"""

from __future__ import annotations

import urllib.parse
from html.parser import HTMLParser
from typing import Dict, List, Optional, Tuple

SKIP_TEXT = {"script", "style", "noscript", "template"}


class _Collector(HTMLParser):
    def __init__(self, base_url: str):
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.links_: List[str] = []
        self.title_parts: List[str] = []
        self.metas: Dict[str, str] = {}
        self.text_parts: List[str] = []
        self.elements: List[Tuple[str, Dict[str, str], str]] = []  # (tag, attrs, text)
        self._in_title = False
        self._skip = 0
        self._stack: List[Tuple[str, Dict[str, str], List[str]]] = []
        self._base_set = False

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if tag == "base" and "href" in a and not self._base_set:
            self.base_url = urllib.parse.urljoin(self.base_url, a["href"])
            self._base_set = True
        if tag == "a" and a.get("href"):
            href = a["href"].strip()
            if href and not href.lower().startswith(("javascript:", "mailto:", "tel:", "#")):
                self.links_.append(urllib.parse.urljoin(self.base_url, href).split("#", 1)[0])
        if tag == "meta" and "name" in a and "content" in a:
            self.metas.setdefault(a["name"].lower(), a["content"])
        if tag == "title":
            self._in_title = True
        if tag in SKIP_TEXT:
            self._skip += 1
        self._stack.append((tag, a, []))

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if tag in SKIP_TEXT and self._skip:
            self._skip -= 1
        # close the innermost open element with this name
        for i in range(len(self._stack) - 1, -1, -1):
            if self._stack[i][0] == tag:
                t, a, parts = self._stack.pop(i)
                self.elements.append((t, a, " ".join(" ".join(parts).split())))
                break

    def handle_data(self, data):
        if self._in_title:
            self.title_parts.append(data)
        if self._skip:
            return
        self.text_parts.append(data)
        for _, _, parts in self._stack:
            parts.append(data)


class HTMLPage:
    def __init__(self, html: str, base_url: str = ""):
        self._c = _Collector(base_url)
        self._c.feed(html)
        self._c.close()

    def links(self) -> List[str]:
        """Absolute http(s) links, in document order, without duplicates."""
        seen = set()
        out = []
        for link in self._c.links_:
            if urllib.parse.urlsplit(link).scheme not in ("http", "https"):
                continue
            if link not in seen:
                seen.add(link)
                out.append(link)
        return out

    def title(self) -> str:
        return " ".join("".join(self._c.title_parts).split())

    def meta(self, name: str) -> Optional[str]:
        return self._c.metas.get(name.lower())

    def text(self) -> str:
        return " ".join("".join(self._c.text_parts).split())

    def find(self, tag: str, **attrs: str) -> List[Tuple[Dict[str, str], str]]:
        """Elements with this tag whose attributes match, as (attrs, text).
        Use `class_` for the class attribute, as in find("h1") or find("span", class_="price")."""
        want = {("class" if k == "class_" else k.replace("_", "-")): v for k, v in attrs.items()}
        out = []
        for t, a, text in self._c.elements:
            if t != tag:
                continue
            if all(a.get(k) == v or (k == "class" and v in a.get("class", "").split()) for k, v in want.items()):
                out.append((a, text))
        return out
