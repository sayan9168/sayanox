#!/usr/bin/env python3
"""Minimal Sayanox formatter: normalize blank lines and indent braces."""
import sys
from pathlib import Path


def format_source(src: str) -> str:
    lines = src.replace("\r\n", "\n").split("\n")
    out = []
    indent = 0
    for raw in lines:
        line = raw.strip()
        if not line:
            if out and out[-1] != "":
                out.append("")
            continue
        if line.startswith("}"):
            indent = max(0, indent - 1)
        out.append(("  " * indent) + line)
        if line.endswith("{") and not line.startswith("//"):
            indent += 1
    while out and out[-1] == "":
        out.pop()
    return "\n".join(out) + "\n"


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: sxfmt.py <file.sa> [--write]")
        sys.exit(1)
    path = Path(sys.argv[1])
    write = "--write" in sys.argv[2:]
    text = path.read_text(encoding="utf-8")
    formatted = format_source(text)
    if write:
        path.write_text(formatted, encoding="utf-8")
        print(f"formatted {path}")
    else:
        sys.stdout.write(formatted)


if __name__ == "__main__":
    main()
