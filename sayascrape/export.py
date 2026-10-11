"""Item pipelines. A pipeline is any callable taking one item dict."""

import json
from typing import Any, Dict


class JsonLinesPipeline:
    """Appends each item as one JSON object per line."""

    def __init__(self, path: str):
        self.path = path
        self._fh = open(path, "w", encoding="utf-8")

    def __call__(self, item: Dict[str, Any]) -> None:
        self._fh.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n")
        self._fh.flush()

    def close(self) -> None:
        self._fh.close()
