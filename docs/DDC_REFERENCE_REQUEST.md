# DDC reference request — what an independent supply must contain

Status: **open request; no reference has been supplied.** This page is the exact
ask behind [REMAINING_WORK](REMAINING_WORK.md) item R03 and the conditional
protocol in [DIVERSE_BOOTSTRAP](DIVERSE_BOOTSTRAP.md). Nothing here closes that
item on its own.

The repository can decide whether a returned receipt is internally consistent.
It cannot manufacture independence: a second compiler written here, a renamed
anchor, a wrapper, generated C, or a rebuild of the same sources is *not* an
independent reference, and treating it as one would be the exact substitution
the register forbids.

## 1. The one executable that is actually needed

Supply `T`: a regular (non-symlink, or a symlink resolved before use) Linux
x86-64 executable implementing the documented Sayanox subset with the interface

```text
T INPUT.sa OUTPUT
```

from the repository root. `T` must process `use` imports and write an executable
Linux x86-64 result, or exit nonzero. No network access, no fallback to a
repository compiler, no invocation of `sx` or `bootstrap/sxc_native.bin` anywhere
in its own build chain or at run time. `T` and its dependencies must stay
byte-identical for the whole run.

## 2. Provenance material that must travel with it

1. **Implementation and review scope** — what it is, who wrote it, what parts of
   the Sayanox subset it implements, and what was reviewed by whom.
2. **Build chain and toolchain provenance** — the compilers/interpreters used,
   their versions and trust roots, and an explicit statement of why no repository
   binary takes part in building `T`.
3. **Known limitations** — semantics `T` does not implement, and the runtime
   dependencies it needs on the host.
4. **Digests** — SHA-256 of the shipped executable and of the source snapshot,
   plus a source snapshot or an immutable retrieval reference.
5. **Reviewer identity and trust assumptions** — who signs off, and what is
   being assumed rather than proved.

Absence of any of these makes the run evidence-only, not a conditional proof.

## 3. Running the protocol

`tools/sxddc.sa` is a Sayanox program. It must itself be compiled by `T` — a
verifier built by the anchor could lie about its own comparisons.

```sh
# 1. build the verifier with the reference, not with this repository
PATH_TO_T tools/sxddc.sa /tmp/ddc-verifier

# Reproduce that build for the record (a rebuild must be byte-identical):
PATH_TO_T tools/sxddc.sa /tmp/ddc-verifier-2
cmp /tmp/ddc-verifier /tmp/ddc-verifier-2

# 2. run the protocol in a fresh directory
/tmp/ddc-verifier run PATH_TO_T REVIEWED_SHA256 REVIEW_FILE /tmp/ddc-run

# 3. return the whole /tmp/ddc-run directory
```

The run refuses to overwrite existing evidence, checks the source and entry pins
before and after execution, checks the reference digest at start and end, and
writes `INCOMPLETE` or `FAILED` receipts on any refusal or mismatch. Only a
successful run may contain `CONDITIONAL_DDC_MATCH`. It never installs a
generated compiler and never replaces a repository binary.

## 4. How the returned evidence is checked here

```sh
./tools/sxddc verify /tmp/ddc-run PATH_TO_T
```

This rechecks, with the host's own `sha256sum` and `cmp`:

- the receipt's first line is a conditional match, not `INCOMPLETE`/`FAILED`;
- the recorded reference digest equals both the receipt and (when given) the
  live reference executable;
- the recorded review digest equals the receipt, `review.sha256` and the review
  file itself, and the review is nonempty;
- the recorded source and entry manifest digests equal the current pinned
  manifests, so the receipt belongs to this tree;
- `stage2` is byte-identical to `bootstrap/sxc_native.bin` and `entry` is
  byte-identical to `sx`;
- every artifact the receipt names is present.

Eight controls for this checker run in `./tools/sxddc self-test`: a consistent
synthetic receipt passes, and a corrupted `stage2`, a reference record that
disagrees with the receipt, a foreign manifest digest, an `INCOMPLETE` receipt,
a review edited after the receipt, a missing artifact, and a live reference that
does not match the recorded digest are all refused.

**What `verify` does not do.** It cannot prove that `T` ran, that `T` is
independent, that the review is truthful, or that the source is harmless.
A receipt and its artifacts can be fabricated by anyone able to write the
directory; the check proves the recorded bytes agree, nothing more. Step 7 of
the protocol — an independent human review of the assumptions and a repeat of
the final comparisons on a trusted host — stays external and manual.

## 5. What accepting a supply will look like

Only when a supplied `T` and its review exist and the protocol has actually been
executed will R03 move from *externally blocked* to a recorded conditional
result. The record will then state, at minimum:

- the reference digest, the review digest and the reviewer identity;
- the exact commands and exit statuses of the run and the recheck;
- the source checkpoint the run was performed against;
- the explicit assumption that `T`, the driver, the host, `sha256sum`, `cmp` and
  the source review are trustworthy;
- the fact that `CONDITIONAL_DDC_MATCH` is a conditional statement, not a
  certification of the source or of the host.

Until then the repository keeps saying *not established*. No release, tag, CI
green run, hash difference or passing control set changes that wording.
