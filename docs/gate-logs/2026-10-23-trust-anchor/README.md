# The C trust anchor, decided and pinned (2026-10-23)

`docs/ALL_SAYANOX_PHASE.md`, "Phase E — the seed", said the C seed has two
honest end states:

1. a prebuilt, checksummed bootstrap binary, or
2. a minimal C seed kept forever as a documented, auditable exception,

and ended: *"Neither option is implemented. Until one is, the seed row above
stays honest and `make all-sayanox` keeps failing."*

**Option 2 is now chosen and implemented as a machine check.** `make
all-sayanox` still fails — that is correct and asserted — but the exception
it refuses is no longer an unmeasured sentence.

| Claim | Where it is checked |
|---|---|
| The anchor is exactly one file, and its size and SHA-256 are pinned | `make test-trust-anchor` — `tools/sxaudit` recomputes them and `cmp`s against the tracked `selfhost/seed/sxc_seed_min.audit` |
| The digest is computed **by Sayanox** (`stdlib/crypto.sa`), not by an external tool | the auditor is `tools/sxaudit.sa`, compiled by gen2; cross-checked once by hand against `sha256sum` |
| The bootstrap compiles that one tracked `.c` and nothing else | `make test-trust-anchor` (the `seed-min` rule is pinned by shape; `gen1_min.c`, `gen2.c`, `gen3.c`, `gen4.c` are generated and gitignored) |
| The external surface is four standard headers, with **zero** references to `system`, `fork`, `exec*`, `dlopen`, `dlsym`, `socket`, `connect`, `setuid`, `unlink`, `rename`, `chmod`, `remove`, `tmpnam`, `getenv` | `make test-trust-anchor` |
| The one shell-out is **emitted runtime text**, not compiler code, and there is exactly one | `make test-trust-anchor` (count pinned at 1; the line must contain `sx_http` and be inside a `puts(`) |
| What the anchor is trusted for is reproducible: compiling the 19.6k-line compiler twice gives byte-identical C | `make test-trust-anchor` |
| The all-in-Sayanox claim still fails closed | `make test-trust-anchor` asserts the refusal text is still in the Makefile; `make all-sayanox` still exits 1 |

## The pin

```
file selfhost/seed/sxc_seed_min.c
bytes 100919
lines 2176
sha256 e4cc34b41041044579ee34ab05c32997f3ad45adbe88973d8403ae43a2a01cb9
```

Tracked as `selfhost/seed/sxc_seed_min.audit`. Changing the seed now requires
regenerating that file, which makes the change visible in review instead of
invisible in a diff of 2000 lines of C.

## The finding that made the gate better

The first draft of the surface check simply banned `popen`. It failed:

```
[FAIL] the trust anchor now references popen
```

The seed does not call `popen`. Line 1894 **emits** a runtime function —
`sx_http`, behind the `http_get` builtin — whose body calls
`popen("curl …")`. So two different statements had been quietly collapsed
into one:

* *the compiler shells out* — **false**, and now asserted false;
* *programs the compiler produces can shell out* — **true**, exactly once,
  and now pinned at exactly once, with the site required to be inside
  emitted text.

An audit that had "passed" by not noticing this would have been worth less
than no audit. The gate now states both facts separately.

## What this does not claim

The seed compiled the compiler that compiled the auditor. A hash pin is
tamper evidence against **drift and unreviewed edits**; it is not immunity
from a seed that was already malicious — Thompson's "Reflections on Trusting
Trust". Breaking that circle needs a second independent implementation to
diverse-double-compile against, and this repository has none: one C compiler,
one seed, no emulator, no second toolchain. That stays open, written down
rather than hashed over.

So the row does not become "C is no longer the trust anchor". It becomes
**"C is still the trust anchor, and it is now a measured one"** — one file,
known size, known digest, known surface, known behaviour, and a gate that
fails the moment any of those change.

## Why the seed was not shrunk instead

Shrinking was the first idea, so it was measured before being abandoned: the
seed was compiled with coverage instrumentation and run on the real workload
(`selfhost/compiler_min.sa`). **78.12 % of its 1540 executable lines run.**
The remainder is not dead weight — it is `die()` diagnostics for malformed
programs and features other fixtures need (`for` headers, nested struct
initialisers, the `USEDIR` splice path). Deleting error paths to make a
"smaller trusted base" would have made the compiler worse while making the
number look better, so the number was left alone and the surface was pinned
instead.

## The four markers

```
DOCTOR-OK
TRUE-SELFHOST-MIN-OK
gen3 == gen4 (byte-identical)
NATIVE-TEST-OK
```

`hard-gates.log` in this folder is the run, which covers this increment and
the module-namespacing one in the same tree.

## Increment gates on this tree

| Gate | Makefile line | What it adds |
|---|---|---|
| `test-trust-anchor` | 2403 (`.PHONY` 2402, `native-test:` 2456, aggregate line 43) | the whole claim above, six `[OK]` lines |
| `tools/sxaudit` rule | 2089 | gen2 → C → reject `#error` → `cc`; depends on `stdlib/crypto.sa` |

New tracked files: `tools/sxaudit.sa` and `selfhost/seed/sxc_seed_min.audit`.
`tools/sxaudit` itself is gitignored like the other built tools.
