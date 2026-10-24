# Sayanox LSP

A language server for `.sa` files: protocol/scanning in Sayanox compiled by
`gen2`, with a small in-tree POSIX C filesystem bridge for folder enumeration.
There is no Node or Python runtime in the path: the server is a native binary
that speaks JSON-RPC 2.0 with `Content-Length` framing on stdin/stdout.

```sh
make lsp        # tools/sayanox_lsp  (gen2 compiles tools/sayanox_lsp.sa)
make test-lsp   # a full session, checked fact by fact
tools/sayanox_lsp < session.txt        # or wire it into an editor
```

## Capabilities

| Method | Support |
|--------|---------|
| `initialize` | yes — `textDocumentSync: 1` (full), completion/hover/definition/documentSymbol/references/formatting/workspaceSymbol/diagnostic/rename/signatureHelp/codeAction providers, `positionEncoding: utf-16`, `serverInfo: sayanox-lsp 2.0` |
| `initialized` | yes |
| `textDocument/didOpen` | yes — stores the document in the open-document table (four slots) and publishes diagnostics |
| `textDocument/didChange` | yes — full-text sync, rewrites that document's slot and re-publishes its diagnostics |
| `textDocument/didClose` | yes — clears that document's slot, publishes empty diagnostics for its URI and stops serving it |
| `textDocument/publishDiagnostics` | on every open/change |
| `textDocument/diagnostic` | pull model (`kind: full`) |
| `textDocument/documentSymbol` | `make` (Function), `struct` (Class), `hold` (Variable) |
| `textDocument/completion` | keywords and the builtin list |
| `textDocument/hover` | builtin documentation, a `make` signature, or the variable's declaration |
| `textDocument/definition` | jumps to the **binder** of the word under the cursor: a parameter or a `hold` in the enclosing function body, else the top-level `make` / `hold` / `struct` line (2026-10-22) |
| `textDocument/references` | every occurrence of the word under the cursor **in the scope that binds it**: a local or parameter is reported inside its own function body only, a top-level name across **open documents plus eligible workspace disk files**, as `Location[]` with UTF-16 columns that cover the whole word. Words inside string literals and `//` comments are not occurrences. `context.includeDeclaration: false` leaves out the binder; a position that is not on a word answers `[]` |
| `workspace/symbol` | symbols from open buffers plus a bounded scan of the initialized local folder; case-insensitive substring query. Open buffers override disk copies; queries refresh the disk snapshot. See limits below |
| `textDocument/formatting` | the `tools/sxfmt.sa` rule set over the protocol: one whole-buffer `TextEdit`, or `[]` when the document is already formatted |
| `textDocument/rename` | a `WorkspaceEdit` with the same resolution as references: a local is renamed **inside its own body**, a top-level name in **every open document and every indexed folder file** (declaration included, strings and comments left alone); the new name must be an identifier, otherwise `null` |
| `textDocument/signatureHelp` | the declaration of the innermost call enclosing the cursor **on the same line, in the same document**, with its parameter list and the argument index the cursor is in; `null` when no declaration is found |
| `textDocument/codeAction` | one action, "Format this Sayanox document", carrying the whole-buffer formatting edit; `[]` when the document is already formatted |
| `workspace/didChangeWatchedFiles` | yes (2026-10-22) — registered with `client/registerCapability` for `**/*.sa` when the client offers dynamic registration; each change re-reads the file and publishes its diagnostics, a delete clears them, and files the client has open are left to `didChange` |
| `shutdown` / `exit` | yes (EOF also ends the session) |

## Error responses (robustness)

A client should never wait for an answer that will not come. The server
follows JSON-RPC 2.0 for input it cannot dispatch (`make test-lsp-robust`,
probe `tools/sayanox-lsp-robust.sh`):

| Input | Response |
|---|---|
| a request (has an `id`) with a method the server does not implement | error `-32601` "method not found", with the same `id` |
| a notification (no `id`) with an unknown method | **no response** (the spec says so) |
| a body that is not a JSON object (`this is not json`) | error `-32700` "parse error", `id: null` |
| an object with no `method` | error `-32600` "invalid request", with its `id` or `null` |
| junk lines before a `Content-Length` frame | skipped; the next valid frame is answered |
| a frame that ends before its declared length | the session ends cleanly; no crash |

After any of these the server keeps serving the next valid request.

Request ids are echoed as sent, so a **string id** (`"id":"abc-1"`) comes back
with its quotes and escapes, a number or `null` comes back unchanged, and a body
with no `id` is a notification (no reply). Covered by `test-lsp-robust`.

Limits, stated plainly: framing needs `Content-Length`, so a header-less stream
is ignored until one appears.

## Diagnostics

Diagnostics are computed from the document text and the file system — not from
a regex over one line:

| Code | Severity | Meaning |
|------|----------|---------|
| `SX1001` | error | unknown statement: the line starts with a word that is neither a keyword/builtin nor a declared `hold`/`make`/`struct` — and the line is not an assignment or a call |
| `SX1002` | error | unterminated string literal |
| `SX1003` | error | unbalanced braces (with the count of unclosed blocks) |
| `SX1004` | error | unbalanced parentheses |
| `SX1005` | warning | `use "file.sa"` cannot be read next to the document (the same resolution the compiler uses) |

## Editor setup (Neovim)

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "sa",
  callback = function()
    vim.lsp.start({
      name = "sayanox",
      cmd = { "/path/to/sayanox/tools/sayanox_lsp" },
      root_dir = vim.fn.getcwd(),
    })
  end,
})
```

## How it is built and tested

* `tools/sayanox_lsp.sa` implements the protocol/scanning: a JSON reader (string escapes,
  `\uXXXX`), a JSON writer with escaping, the document scanner, the diagnostic
  pass, symbols, completion, hover, definition, references, the formatter and
  the framing loop.
* `tools/sayanox-lsp-probe.sh` pipes six real sessions into the binary —
  (1) initialize, didOpen, hover, definition, documentSymbol, completion,
  diagnostic, didChange, shutdown, exit; (2) a closed document; (3) the
  four-slot cap; (4) references with and without the declaration, plus a
  non-word position; (5) workspace/symbol and formatting; (6) rename across
  the open documents, signature help on a two-parameter call, and the format
  code action (offered, then empty once formatted) — and prints one line
  per verified fact, 38 in all. `make test-lsp` asserts that exact list, and
  the target is part of the `true-selfhost-min` gate — i.e. the LSP is
  exercised by `make test`.
* The server keeps up to **four documents** open (full-text sync). It advertises
  UTF-16 positions and converts UTF-8 scanner offsets at the protocol
  boundary.

## Multiple documents (2026-10-13)

The server used to keep ONE document: a second `didOpen` overwrote it, so with
two Sayanox files open in an editor every request for the first file was
answered from the second file's buffer — a wrong answer, not a missing one.
(`didChange` was guarded against a foreign URI; `didOpen`, `hover`,
`definition`, `documentSymbol` and `textDocument/diagnostic` were not.)

It now keeps a table of four documents. The dialect has no array of strings, so
the table is four parallel pairs of globals (`uri0`/`txt0` … `uri3`/`txt3`) and
exactly three places touch it: the load cascade under the framing loop,
`didOpen` (store) and `didClose` (clear). Every message reloads `doc`/`docuri`
from the table by its own `params.textDocument.uri` before the handlers run, so
each reader answers from the buffer the client asked about.

* A request for a URI that is **not** open gets an empty document, and therefore
  an empty answer — `documentSymbol` → `[]`, `diagnostic` → no items, `hover` →
  the generic blurb — never another file's contents.
* `didChange` for a URI that is not open is ignored: no diagnostics are
  published for a buffer the server does not have.
* A **fifth** `didOpen` evicts the slot that has been open longest (round robin
  through `slotnext`), and the evicted document stops being served until it is
  opened again. Four is a documented cap, not a claim about editor sessions: a
  window with more than four Sayanox buffers will see the oldest go quiet, and
  re-focusing one re-opens it.
* Historical boundary: this originally had no disk index. The 2026-10-16
  folder increment below supersedes that limitation for workspace symbols
  and references only. `use` resolution still uses the served URI directory.

`tools/sayanox-lsp-probe.sh` drives three sessions and `make test-lsp` asserts
all eighteen lines: two documents open at once with the first still served after
the second was opened, a closed document answering `"result":[]` and not being
served from another buffer, and the five-document eviction (`f1` gone, `f5`
still served).

## The old shell server (removed 2026-10-17)

`tools/sayanox-lsp.sh` was the original dependency-free shell stub (keyword
completion, one-line diagnostics). It has been removed: the maintained server
is `tools/sayanox_lsp.sa`, built by gen2. Keeping a sed-based second server
would have kept sed on the toolchain boundary for no maintained behaviour.

### Neovim filetype registration and launch checks

Register the language independently of Linguist (do not map `.sa` to C or
Python). Put this before the autocmd above:

```lua
vim.filetype.add({ extension = { sa = 'sa' } })
```

Run `make lsp` once, then launch the absolute `tools/sayanox_lsp` binary from
the client. Do **not** launch `make lsp` as the server: build output is not
JSON-RPC and would corrupt the stdio transport. The server needs neither
Python nor a network connection. `make test-lsp test-lsp-robust` runs actual
framed request/response sessions, including full-text `didChange`, cleared
diagnostics, escaped ids and malformed/unknown request errors.

## Unicode and document lifecycle (2026-10-11)

`positionEncoding: "utf-16"` is advertised. Incoming hover/definition positions
are converted to UTF-8 byte offsets; diagnostic spans are converted back to
UTF-16, without cutting a supplementary character's surrogate pair. Cursor
positions inside a surrogate pair clamp to that character's start. End-of-line
positions clamp rather than spilling into the next line.

JSON `\uXXXX` strings are decoded into UTF-8, including paired surrogate
escapes. Raw UTF-8 and escaped text are tested for identical protocol output.
`test-lsp-unicode`, included by `test-lsp`, covers accented Latin, Bengali and
emoji preceding a hover target, and a diagnostic ending on an emoji.

A full-text change with `"text":""` now actually clears the document. An empty
change array preserves it; changes for another URI do not overwrite the
active document. Closing the matching URI releases its text. Tests use real
`Content-Length` sessions, not calls to mocked helper functions.

Current product limits: one open document (the latest didOpen wins), full-text
synchronization, one replacement per change notification, no cross-file type
analysis or incremental edits. The JSON field reader is lightweight, not a
complete validating JSON parser. Invalid/unpaired Unicode escapes and escaped
U+0000 are replaced with U+FFFD (the runtime cannot store embedded NUL).
Identifier recognition remains ASCII; UTF-16 positioning does not add Unicode
identifiers to the compiler. These probes do not claim complete LSP conformance
or a full compiler diagnostic pass.

## References, workspace symbols and formatting (2026-10-13)

Three more methods, all answered from the buffers the server already keeps, so
nothing about the four-slot table or the framing loop changed.

### `textDocument/references`

`refs_for(w, text, uri, incl, first)` walks one document line by line, collects
whole-word occurrences of `w` (an identifier run compared with `string_eq`, so
`zz` does not match inside `fuzzy`), and turns each into a `Location`. The
columns go through the existing `utf16_span` helper twice — once for the byte
offset of the word and once for the offset just past its last byte — so a range
covers the whole word and stays correct on a line with accented Latin, Bengali
or emoji in front of it.

`incl` is `context.includeDeclaration`. When it is false, a line whose first
non-blank text is `make w`, `hold w` or `struct w` is skipped, which is the
difference between "find references" and "find references including the
definition" in an editor. Both spellings of the flag are recognised
(`"includeDeclaration":false` and `"includeDeclaration": false`).

The open-buffer part of the request scans all four slots: a helper cannot read the four-slot table
(a function cannot capture globals in this dialect), so the dispatch site calls
`refs_for` once per slot and concatenates. The comma rule lives in the helper —
`first` is the number of items the caller already has, and `len(res)` is exactly
that at each step — so the four scans join into one array without the caller
counting anything.

### `workspace/symbol`

`symbols(text, uri)` became `sym_scan(text, uri, query, first)` with the same
comma rule, and `symbols` now delegates to it with an empty query, so
`documentSymbol` answers byte-for-byte what it always did. `query` filters by
case-insensitive substring (the new `lower` helper is ASCII-only, which is all
a symbol name can be). The dispatch site scans the four slots the same way
references does.

Rename used to retain the old open-buffer limit (open documents only); it
spans the folder index since 2026-10-22, see below.
Signature help is narrower still: the declaration must be in the **same**
document and the call must enclose the cursor on the **same line** (a call
that spans lines, or a declaration in another open document, answers
`null`). The one code action is formatting; there are no quick-fixes for the
SX1001–SX1005 diagnostics yet.

Historical boundary, superseded for symbols/references by the 2026-10-16
folder snapshot below, and for rename and scope by the 2026-10-22 section at
the end: the original implementation searched open documents only, lexically.

### `textDocument/formatting`

`format_text(text)` is a port of `tools/sxfmt.sa`, rule for rule: rebuild the
indentation from brace depth at two spaces per level, strip leading and
trailing whitespace, keep a blank line blank, add a final newline, and count
braces only outside a quoted string (with `\` escapes) and outside a `//`
comment. A line that starts with closing braces is indented at the depth those
braces return to. Tokens and comments are never rewritten.

`format_edit(text)` answers `[]` when `format_text` gives back the same text —
so a client leaves an already-formatted buffer alone — and otherwise one
`TextEdit` whose range is the whole document: `{0,0}` to one past the last
newline when the text ends with one, else to the UTF-16 width of the last line.
`newText` goes through the existing `json_esc`, so newlines, quotes and
backslashes are escaped.

The probe feeds it the same badly indented source that `make test-sxfmt` feeds
the formatter program (`hold x = 1  ` with trailing spaces, a `}` and a `//`
inside a string literal, a nested block) and asserts the indentation, the
stripped trailing whitespace and the whole-buffer range, which is what makes
"the LSP formats like `sxfmt`" a checked claim rather than a comment.

## Bounded local workspace folder index (2026-10-16)

The built server now finds declarations and references in `.sa` files that
were **never opened**, including subdirectories and more than four disk files.
This is an on-demand filesystem snapshot index, not a persistent/incremental
symbol database. Each `workspace/symbol` or `textDocument/references` refreshes
the manifest and reads eligible disk files. No shell command or external
indexing service runs.

### Root, overlay and refresh behavior

* `initialize.params.rootUri` selects one local folder. If absent/null/empty,
  the first `workspaceFolders` URI is used. Only `file:///...` and
  `file://localhost/...` are accepted; percent escapes are decoded and the
  root is canonicalized with `realpath`. Invalid escapes, encoded NUL,
  nonexistent roots and nonlocal/HTTP roots give an empty disk index, without
  breaking later requests. No root means the prior open-buffer behavior.
* `workspace/symbol` merges the four open buffers with eligible disk symbols.
  An exactly matching open URI suppresses its disk copy, so unsaved text wins
  and a declaration is not duplicated. Matching uses canonical percent-encoded
  file URIs; alternate URI aliases/symlink spellings are not unified.
* `references` can take its cursor word from an unopened eligible disk file
  and search all open buffers plus eligible disk files. Existing UTF-16 range
  generation and `includeDeclaration` filtering are reused. Closed files are
  read only—no workspace file edits are made.
* Closing a buffer restores its disk view for these two methods. A fifth open
  buffer still evicts one of the four unsaved overlays; its eligible disk copy
  can then be searched, but unsaved evicted text is not retained.
* Edits, new files and deletion on disk are observed on the next query, and
  since 2026-10-22 a client that supports `workspace/didChangeWatchedFiles`
  also gets diagnostics for a changed file without querying. There is still no
  background worker and no cancellation. Queries are synchronous and a large
  folder can be slow.
* Folder changes after initialization, multiple workspace roots, `rootPath`,
  remote/virtual filesystems and scanning dependencies outside the selected
  root are not implemented.

### Actual scan limits

`workspace_manifest` in `tools/sayanox_lsp.sa` walks the folder with the
Sayanox directory builtins (`read_dir`, `path_kind`, `path_size`,
`path_real`). The limits are:

* 128 regular `.sa` files; 256 KiB per file; a 2 MiB manifest;
* depth 16 below the selected root and at most 4,096 names per directory
  (the `read_dir` cap);
* no symlink traversal (`lstat`, so kind 3 is skipped); hidden entries and
  `node_modules`, `build`, `dist`, `target`, `vendor` are skipped; filenames
  containing CR/LF are skipped by `read_dir`.

The listing is no longer sorted: entries come in filesystem order, which also
decides which 128 files win when a folder is larger than the cap. The old C
bridge sorted each directory bytewise, and applied its 4 MiB aggregate-size
budget during the walk; the Sayanox walk applies the file cap and the 2 MiB
manifest cap to the finished listing. Both differences are bounds-preserving,
not behavior-preserving, and the 128-file cap test still pins the bound.

Unreadable/oversized/skipped files and files beyond a cap simply do not
contribute. There is **no truncation/progress notification** yet. Within the
caps traversal is sorted; beyond a directory's collected-name limit the subset
can depend on filesystem enumeration order. These filters are not a total
process-memory bound, hostile-filesystem sandbox, race-proof symlink defense
or stable cross-query snapshot: files can change while a query runs.

### Build and test boundary

There is no C header and no generated-C binder any more. `make lsp` compiles
`tools/sayanox_lsp.sa` with gen2 and links it; the folder index is ordinary
Sayanox. This removed `tools/lsp_workspace.h` (119 lines) and
`tools/lsp_workspace_bind.sa` on 2026-10-17. A standalone compilation of the
.sa` file therefore has the same folder support as the Makefile build.

Both `test-lsp` and `test-lsp-robust` now require `test-lsp-workspace`.
The test client `tools/lsp_workspace_test.sa` is Sayanox too: it spawns the
server with the language's own `spawn`/`child_send`/`child_line`/`child_recv`/
`child_close` builtins and reads actual `Content-Length` frames with
handshakes (no timing sleeps or interpreter). It checks unopened/nested file
symbols, case-insensitive query, references with/without declarations, URI
encoding for spaces, more than four disk files, open overlay precedence and
no duplicates, close fallback, disk edit/delete refresh, first workspace
folder, invalid/nonlocal roots, symlink/hidden/oversized filtering and the
128-file cap. Existing protocol, Unicode and four-buffer probes remain.
Logs: [2026-10-16 workspace LSP](gate-logs/2026-10-16-lsp-workspace/).

### Remaining IDE gaps — not IDE-complete

*Rewritten 2026-10-22: the three items this section used to lead with
(semantic resolution, rename beyond open buffers, file watching) are
implemented and gated; what is left is listed below.*

Resolution is **scope resolution, not type resolution**. The server knows
which declaration binds a name — a parameter, a `hold` in the enclosing body,
or a top-level `make`/`hold`/`struct` — and it ignores words inside strings
and comments. It does **not** know types: a struct field and a variable with
the same name are the same name to it, `use`d files are not followed to their
declarations (a top-level name is searched for across the folder index by
spelling), and shadowing inside nested `when`/`while` blocks of the same
function body is not distinguished from the body's own binding. There is no
compiler-backed symbol table: the resolver is a brace-depth scan of the
document, not the front end that gen2 uses.

Signature help still requires a same-document declaration and a same-line
call; code actions still offer formatting only, not diagnostic fixes. Hover,
documentSymbol and diagnostics retain their open-document behavior, and there
is no workspace diagnostic pass (a watched-file notification publishes
diagnostics for the named files only, up to 32 per notification). Four
open-buffer slots and the 128-file folder cap remain. These improvements do
not establish IDE completeness.

## Semantic resolution, folder rename and file watching (2026-10-22)

Three gaps closed in one increment, all in `tools/sayanox_lsp.sa`, all checked
by `make test-lsp-semantic` (required by `test-lsp` and `test-lsp-robust`).

**Scope.** Five helpers do the work: `brace_delta` reads one line's brace
balance the way the formatter does (quotes and `//` excluded), `fn_open_line`
finds the `make` whose body contains a line, `fn_close_line` finds where that
body ends, `sig_param` tells whether a signature declares a given parameter,
and `local_decl_line` finds the `hold`/`for`/parameter that binds a name
inside a body. `top_decl_line` is the other half: the first `make`, `struct`
or `hold` written at depth 0. Definition answers the local binder when there
is one and the top-level binder otherwise; references and rename pass the
body's line range to the scanner, which now also skips words inside string
literals and comments.

The fixture that pins it declares `total` three times (two function bodies and
the top level) and `count` twice, and puts both names inside a string and a
comment. The checks are exact: definition from inside the second body answers
*its* `hold`, not the first body's; a reference search on a parameter answers
exactly two locations; a reference search on the local `total` answers exactly
four, skipping the string, the comment, the other body and the global.

**Folder-wide rename.** `workspace_rename` walks the same bounded folder index
`workspace/symbol` and `references` use, and adds one `"uri":[edits]` entry per
indexed file the client does not have open. The gate renames a function
declared in an open buffer and used twice in a file that was never opened, and
requires both URIs and all four edits in the one `WorkspaceEdit`.

**File watching.** On `initialized`, when the client's capabilities mention
`didChangeWatchedFiles`, the server sends `client/registerCapability` for
`**/*.sa` (kind 7: create, change, delete). A client that does not offer
dynamic registration is sent nothing, and its session is byte-for-byte what it
was before. Each `workspace/didChangeWatchedFiles` notification refreshes the
folder index and publishes diagnostics per changed file: the file is re-read
from disk, a `type: 3` (deleted) or unreadable file publishes `[]` to clear
its diagnostics, and a file the client has open is skipped because `didChange`
already owns it. At most 32 changes are answered per notification, so a branch
checkout cannot make the server write an unbounded burst of frames. The
client's reply to the registration request — a body with an `id`, a `result`
and no `method` — is now ignored instead of answered with `-32600`.

The test client is `tools/lsp_semantic_test.sa`, Sayanox like the folder one,
driving real framed sessions through `spawn`/`child_send`/`child_recv`. Run
against the previous server binary it fails on its first check, which is how
the gate was confirmed to be discriminating rather than decorative.
