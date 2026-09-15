#!/usr/bin/env python3
"""Sayanox LSP MVP — stdio JSON-RPC (hover + completion)."""
import json
import sys

KEYWORDS = [
    "hold", "show", "when", "otherwise", "while", "make", "give",
    "struct", "use", "export", "true", "false",
]
STDLIB = ["len", "concat", "str", "push", "read_file", "write_file", "upper", "lower", "trim"]


def read_message():
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        line = line.decode("utf-8", errors="replace").strip()
        if line == "":
            break
        if ":" in line:
            k, v = line.split(":", 1)
            headers[k.strip().lower()] = v.strip()
    length = int(headers.get("content-length", "0"))
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def send(msg):
    data = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(data)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def respond(req_id, result):
    send({"jsonrpc": "2.0", "id": req_id, "result": result})


def main():
    while True:
        msg = read_message()
        if msg is None:
            break
        method = msg.get("method")
        req_id = msg.get("id")
        if method == "initialize":
            respond(
                req_id,
                {
                    "capabilities": {
                        "hoverProvider": True,
                        "completionProvider": {"triggerCharacters": ["."]},
                        "textDocumentSync": 1,
                    },
                    "serverInfo": {"name": "sayanox-lsp", "version": "0.1.0"},
                },
            )
        elif method == "initialized":
            pass
        elif method == "shutdown":
            respond(req_id, None)
        elif method == "exit":
            break
        elif method == "textDocument/completion" and req_id is not None:
            items = [{"label": k, "kind": 14} for k in KEYWORDS]
            items += [{"label": s, "kind": 3} for s in STDLIB]
            respond(req_id, items)
        elif method == "textDocument/hover" and req_id is not None:
            respond(
                req_id,
                {
                    "contents": {
                        "kind": "markdown",
                        "value": "**Sayanox** — `hold` / `show` / `when` / `make`\n\nCompile: `sayanox file.sa` or `./selfhost/sx file.sa --run`",
                    }
                },
            )
        elif req_id is not None:
            respond(req_id, None)


if __name__ == "__main__":
    main()
