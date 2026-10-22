# 2026-10-22 — cryptography, nested JSON, signed packages, a resolving LSP

Four roadmap rows had the same shape: a capability the project said it did not
have, with nothing in the tree that would fail if someone claimed otherwise.
This increment closes three of them and converts the fourth into a measured,
gated blocker. Every claim below is checked by a `make` target, and each of
those targets fails if the new code is removed.

| Row | Was | Is now | Gate |
|---|---|---|---|
| 6. Stdlib | "No crypto. No nested JSON reader." | `stdlib/crypto.sa` (SHA-256, HMAC-SHA256) and `stdlib/json_deep.sa` (nested JSON by path), on seed-min, gen2 and native | `test-stdlib-crypto`, `test-stdlib-json-deep` |
| 7. Packages | "`sum=` is non-cryptographic; no signatures/provenance" | `sha256=`, `origin=`, and `sxpkg sign` / `authenticate` with HMAC-SHA256 | `test-sxpkg-crypto` |
| 8. LSP | "no watchers, no semantic resolution, rename is open-buffers-only" | binder resolution for definition/references/rename, folder-wide rename, `workspace/didChangeWatchedFiles` | `test-lsp-semantic` |
| 5. Nested generics | "refused on all three backends" | still refused — and the blocker underneath is now pinned | `test-struct-field-struct` |

## 1. SHA-256 without bitwise operators

The bootstrap dialect has no `and`, `or`, `xor`, `<<` or `>>` on the seed
path: `bit_and`/`shl`/`shr` exist on gen2 and gen1_min only, and a module that
used them would not be a *stdlib* module. SHA-256 is nothing but those
operations.

`stdlib/crypto.sa` carries each 32-bit word as a number and does the bit work
with division and remainder: `shr(x, n)` is `floor(x / 2^n)`, `and`/`or`/`xor`
are a 32-step loop over the bit pairs, and `not` is `4294967295 - x`. It is
slower than a `uint32_t` implementation by a wide margin, and it runs
identically on all three backends, which is the whole point.

Two further constraints shaped the API. A Sayanox string cannot hold a zero
byte (`chr(0)` truncates), so every entry point has a `_list` form that takes
bytes; and the dialect has no mutable indexing on the seed path
(`xs[i] = v` is gen2-only), so the message schedule is built with `push` and
rolling scalars rather than in-place updates.

`make test-stdlib-crypto` (227 s, dominated by the native build) checks:

* the three FIPS 180-4 vectors: empty, `abc`, and the 56-byte two-block case;
* the padding boundaries at 55, 56, 63, 64 and 65 bytes, which is where a
  length-encoding mistake hides;
* RFC 4231 HMAC cases 1, 2 and 3, including the 131-byte over-long key that
  must be hashed down first;
* hex round-trips (`cx_hex`/`cx_unhex`/`cx_bytes`) and the nine bit primitives
  printed as hex words;
* a tamper fixture: one flipped byte must change the digest, and
  `cx_eq_hex` must still ignore letter case;
* the host's `sha256sum` over the same bytes **when it is installed** — the
  check prints `[SKIP]` otherwise, because no bootstrap gate may depend on a
  tool outside the minimal set (`test-language-deps` would catch it).

All three backends must print the same 33 lines, ending in `crypto-done`.

## 2. Nested JSON, and the 15 refusals

`stdlib/json_util.sa` builds and reads flat objects; it was never a parser.
`stdlib/json_deep.sa` is a reader for nested documents, addressed by path:
`jd_text(doc, "items[2].user.name")`. Nine helpers cover the types, the raw
slice, numbers, booleans, lengths, and `jd_key(doc, path, i)` for walking an
object whose keys are not known ahead of time. Strings are decoded, including
`\uXXXX` and surrogate pairs, into UTF-8.

What it *refuses* is as pinned as what it accepts, because a parser that
accepts everything is not a parser. `make test-stdlib-json-deep` (1.1 s)
checks 8 accepted documents and 15 refusals: empty input, a trailing comma in
an object and in an array, an unterminated array, a missing colon, an unquoted
key, trailing text after a complete value, the numbers `01`, `1.` and `1e`, a
missing value after a colon, the truncated literal `tru`, the unknown escape
`\x`, and the mismatched closers `[1}` and `{"a":1}}`.

The same gate runs a flat object through `json_util.sa` *and* `json_deep.sa`
and requires the answers to agree, so the new module cannot drift away from
the old one where both apply.

## 3. A package checksum you can rely on — and a signature you can audit

`pkg.meta` carried `sum=`: `h = (h * 31 + byte) mod 1000000007`. That detects
an accidental edit. It does not detect a deliberate one:

```
give  ->  hJve        # 'g'+1, 'i'-31
sum=718013937         # unchanged
sha256 20c26979… -> 37b10bb1…
```

`make test-sxpkg-crypto` constructs exactly that pair and requires `verify` to
refuse the swap — which it can only do through the new `sha256=` line. The
collision is in the gate, not in a comment, so the reason the digest exists is
reproducible.

The tool gained three commands (`sha256`, `sign`, `authenticate`) and
`pkg.meta` gained four fields (`sha256=`, `origin=`, `signer=`, `sig=`). The
signature is

```
sig    = HMAC-SHA256(secret, "sayanox-pkg-v1\nname=<n>\nversion=<v>\nsha256=<d>\n")
signer = first 16 hex digits of SHA-256(secret)
```

with the secret from `SAYANOX_SIGN_KEY`, `SAYANOX_SIGN_KEYFILE`, or
`.sayanox/keys/default.key`. The domain-separated preimage means a signature
cannot be replayed under another name or version.

**It is a keyed digest, not a public-key signature.** The checker needs the
same secret as the signer. The tool's header comment, `REGISTRY.md`,
`SXPKG_ONLINE.md` and the STATUS row all say so in those words; the gate name
ends in `crypto`, not `trust`.

Compatibility is pinned, not assumed: over a registry with no signatures,
`verify`'s output is compared byte for byte (`cmp`) against the
pre-signature tool's, and a `pkg.meta` with no `sha256=` (an older registry)
still verifies on `sum=` alone. Five refusal paths are checked — another key,
tampered `main.sa`, a rewritten `sha256=`, no key present, and
`SAYANOX_REQUIRE_SIGNED=1` over an unsigned package — each with its exit code.

## 4. The LSP stops guessing which `total` you meant

Definition, references and rename matched *spelling*. In a file with

```
make beta(count: num) -> num { hold total = 9 … }
make alpha(count: num) -> num { hold total = 0 … }
hold total = 1
```

"go to definition" on alpha's `total` answered beta's line, renaming a local
rewrote every `total` in every open buffer, and a word inside a string or a
comment counted as a use.

Six helpers now resolve the binder before answering: `brace_delta` (a line's
brace balance, quotes and `//` excluded), `fn_open_line` / `fn_close_line`
(the body that contains a line), `sig_param` (does this signature declare that
parameter), `local_decl_line` (the `hold`/`for`/parameter that binds a name in
a body) and `top_decl_line` (the first declaration at depth 0). References and
rename take the body's line range; both scanners skip strings and comments.

Rename also reaches the folder: `workspace_rename` walks the same bounded
index `workspace/symbol` uses and adds one changes entry per indexed file the
client has not opened.

File watching is a real registration, not a capability bit: on `initialized`,
if the client's capabilities mention `didChangeWatchedFiles`, the server sends
`client/registerCapability` for `**/*.sa` (kind 7). Each notification
re-reads the named files, publishes their diagnostics, clears them on a
delete, and skips files the client has open — `didChange` owns those. At most
32 changes are answered per notification. A client that offers no dynamic
registration is sent nothing and sees exactly the session it saw before.

`make test-lsp-semantic` drives all of this over real framed sessions from a
Sayanox client (`tools/lsp_semantic_test.sa`, `spawn` + `child_send` +
`child_recv`). Its fixture declares `total` three times and `count` twice and
puts both inside a string and a comment, so the counts are exact: 2 locations
for the parameter, 4 for the local, 4 edits for the local rename, both URIs
for the folder rename. Run against the previous server binary the gate fails
on its first check.

## 5. What did not move, and why

Rows 1 (full-language self-host), 3 (seed GC), 9 (second ISA) and 10
(namespacing) are untouched. Row 5 (nested generics) is untouched *as a
feature*, but the reason is now measured rather than asserted:

```
struct Inner { v }   struct Outer { b }
hold i = Inner { 7 }   hold o = Outer { i }   show o.b.v
```

seed-min prints 7. native prints 7. gen2 refuses: *field 'b' of struct 'Outer'
is not a struct; the chain must end there*. Mangling `Box<Box<num>>` into
`Box__Box__n` is the easy half of nested generics; the hard half is that on
gen2 the mangled struct would have a field it cannot represent. `make
test-struct-field-struct` pins all three behaviours and says, in its failure
message, that flipping it unblocks row 5.

The three rows that touch `selfhost/compiler_min.sa` were left alone
deliberately. The self-host peak is ~3.68 GB of the ~3.9 GB available, and the
measured cost of source added to that file is 27–50 MB of peak RSS per KB; a
+54 KB draft was OOM-killed during an earlier increment. Work that cannot be
done without editing the compiler needs that headroom problem solved first,
and solving it is its own increment.

## Gates

```
make test-stdlib-crypto        # SHA-256 / HMAC-SHA256, three backends
make test-stdlib-json-deep     # nested JSON, 8 accepts + 15 refusals
make test-sxpkg-crypto         # digest, collision, signatures, provenance
make test-lsp-semantic         # scope, folder rename, watchers
make test-struct-field-struct  # the measured nested-generics blocker
```

and the four hard gates, all green on this tree:

```
make doctor         # DOCTOR-OK
make true-selfhost  # TRUE-SELFHOST-MIN-OK
make gen3           # GEN3-OK (gen3.c == gen4.c)
make native-test    # NATIVE-TEST-OK
```
