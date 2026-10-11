"""sayascrape: a Scrapy-style crawler for authorized targets (standard library only)."""

from .core import (DEFAULT_USER_AGENT, Crawler, Request, Response, ScopeError,
                   Spider, host_in_scope, in_scope, normalize_url)
from .export import JsonLinesPipeline
from .parse import HTMLPage

__all__ = [
    "Crawler", "Spider", "Request", "Response", "ScopeError", "HTMLPage",
    "JsonLinesPipeline", "in_scope", "host_in_scope", "normalize_url",
    "DEFAULT_USER_AGENT",
]
__version__ = "0.1.0"
