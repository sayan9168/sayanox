# 2026-10-20 — `read_bytes`, the Sayanox ELF linker, and CI that finishes

On branch `arena/c3f6a7f3-sayanox`. Every run below is on this checkout and
every log in this directory is the actual command output.

Two unrelated things were wrong and both are addressed here:

1. **CI did not finish.** The single `bootstrap` job ran all four gates in
   sequence under `timeout-minutes: 25`. On the merge of PR #30 (run
   `39439680267`) it needed 25m15s: `doctor`+`true-selfhost` 9m15s, `gen3`
   9m43s, and `native-test` was cancelled 6m13s in. The failure was
   `The job has exceeded the maximum execution time of 25m0s`, not a gate
   result — three earlier `push` runs to `main` were cancelled the same way.
2. **Phase D had no reader.** Step 1 (2026-10-18) gave the language a byte
   buffer that could be *written* to disk, but nothing could read one back:
   `read_file` returns a C string, so an ELF image — mostly NUL bytes and page
   padding — arrives truncated. Without a reader the image writer cannot be
   ported at all.

## What changed

| file | before | after | what |
|---|---:|---:|---|
| `.github/workflows/ci.yml` | 1 job, 25 min | 4 jobs, 45 min each | gates in parallel, plus an audit job |
| `.github/workflows/full-bootstrap.yml` | — | new | nightly sequential run, no hand-off, 90 min |
| `selfhost/compiler_min.sa` | 19,540 lines | 19,577 lines | the `read_bytes` builtin, wired in 16 places |
| `selfhost/native_aot.c` | 4,353 lines | 4,415 lines | `link_seam()`: the `SX_LINK_DUMP` dump |
| `tools/sxlink.sa` | — | 337 lines | the ELF image writer and rel32 linker, in Sayanox |
| `Makefile` | 4,860 lines | 5,002 lines | `test-read-bytes`, `test-native-sxlink` (incl. the five ELF layout pins), `tools/sxlink`, `clean` |

### `read_bytes(path, xs)`

Appends every byte of `path` to the list `xs` and gives the count, or `-1`
when the file cannot be read — and then appends nothing, so the buffer is
still usable. It appends rather than returning a fresh list for the same
reason `bytes_f64` does: the codegen has no list-typed return for a builtin
yet. The runtime helper is 1 line of C next to `sx_write_bytes`, an 8 KiB
`fread` loop over `sx_lpush`, which is amortised O(1).

Wiring a builtin means 16 sites in this compiler, not one: the two return-kind
and signature tables, the builtin-name list (both spellings), and then the
argument rewriter, the `fk` classifier and the `fk` emitter, the nested-call
operand map and the argument-word map — each of which exists twice, once per
codegen pass — plus the typed-signature call table and the runtime blob.
`selfhost/gen2.c` was diffed against a pre-change build: 48 changed lines, all
of them the new helper, the new table entries and the new `when` branches. No
other emitted C moved.

### `SX_LINK_DUMP` — the seam

`native_aot` already had `SX_EMIT_LOG` for the instruction list. This is the
same idea one stage later, at the image. When `SX_LINK_DUMP=<dir>` is set,
`link_seam()` writes exactly the three inputs of the image writer:

| file | contents |
|---|---|
| `code.bin` | the emitted machine code, `cn` bytes |
| `data.bin` | the data segment, `dn` bytes |
| `patch.bin` | `npc+npr` 16-byte records: rel32 site, then its resolved target |
| `meta.txt` | `npc npr cn dn` |

It is the honest seam rather than a copy of the result: no ELF header, no
program header, no page rounding, no padding and no displacement reaches those
files, because those are precisely what the Sayanox linker has to compute. The
gate pins that setting the variable changes no emitted byte, the way
`test-native-ir-log` pins it for `SX_EMIT_LOG`.

### `tools/sxlink.sa`

`write_elf()` rewritten in the language: the ELF header, the three program
headers, the page rounding, the padding, the collector's heap cursor
(`OFF_CUR`/`OFF_END`) and every rel32 fixup — call sites and the
`lea r12,[rip+disp32]` that reaches the data segment. It uses nothing outside
the gated surface: `push`, `xs[i] = v`, `len`, `%`, `shr`, `bit_and`,
`write_bytes`, `read_bytes`.

Three bugs found while writing it are worth recording, because all three are
dialect traps rather than arithmetic slips:

* **Page 0 has to be padded explicitly.** The C writer `malloc`s the whole
  image and `memset`s it, so the 3,864 zero bytes between the program headers
  and the code segment exist by construction. A buffer built by appending has
  to say so; without it the code segment landed at offset 232 while the
  program headers still claimed 4096.
* **`bit_and` is not a mask you can skip.** `img[data_off] = bit_and(cur,
  4294967295)` stores the whole 32-bit word in one byte slot. The C
  `memcpy(&cur, 8)` writes eight little-endian bytes, so the Sayanox side has
  to emit four `bit_and(shr(cur, 8*k), 255)` bytes and four zeros.
* **Page rounding cannot use a bitmask.** `~4095` is `2^64-4096`, which a
  double cannot hold exactly, so `bit_and(n + 4095, mask)` is out; the helpers
  go through the checked `%` and special-case a zero remainder, because
  `n + (4096 - n % 4096)` would grow an already-aligned value by a page.

Also: a Sayanox function named `link` becomes a C function named `link`, which
collides with POSIX `link(2)` from `<unistd.h>`. It is `link_image` here.

## Gates

| gate | result | log |
|---|---|---|
| `make doctor` | `DOCTOR-OK` | [`doctor.log`](doctor.log) |
| `make test-read-bytes` (new) | `[OK] read_bytes: ...` | [`read-bytes.log`](read-bytes.log) |
| `make test-native-sxlink` (new) | `[OK] sxlink: five fixtures ...` | [`native-sxlink.log`](native-sxlink.log) |
| `make gen3` | `GEN3-OK`, `gen3.c == gen4.c` byte-identical | [`gen3.log`](gen3.log) |
| `make true-selfhost` | `TRUE-SELFHOST-MIN-OK`, 197 `[OK]` lines | [`true-selfhost.log`](true-selfhost.log) |
| `make native-test` | `NATIVE-TEST-OK`, 184 `[OK]` lines | [`native-test.log`](native-test.log) |
| `make test-language-deps` | `[OK] language deps: no bash/awk/sed/python/perl/node/ruby invoked` | [`language-deps.log`](language-deps.log) |
| `make all-sayanox` | **still refuses** (`exit 1`), on purpose, printing the updated inventory | [`all-sayanox.log`](all-sayanox.log) |

All four were re-run after the compiler change, on this checkout, on a 2-core
box: `true-selfhost` 17m, `gen3` 11m, `native-test` 8m. `test-doc-claims` is
inside `true-selfhost` and is the gate that forbids this directory from
claiming a phase is finished: it fails if `make all-sayanox` ever returns 0
without `docs/ALL_SAYANOX_PHASE.md`, `docs/STATUS.md` and `README.md` moving in
the same change.

`test-read-bytes` is on the `true-selfhost` list, `test-native-sxlink` on the
`native-test` list, so both run in CI on every PR.

The five linker fixtures, chosen because each moves a different part of the
image:

| fixture | ELF | patches (`npc npr`) | what it exercises |
|---|---:|---|---|
| inline hello | 16,384 | 32 1 | the smallest image, one `lea r12` |
| inline `fac`/`fib` | 16,384 | 45 3 | recursion, so backward and forward call rel32s |
| inline strings/struct/list/`gc()` | 16,384 | 57 1 | a data segment full of strings, the root table, a collection |
| `selfhost/native_strord_test.sa` | 16,384 | 127 1 | string ordering, many call sites |
| `selfhost/stdlib_growth_test.sa` | 24,576 | 327 41 | a **multi-page** code segment, so `round_page` actually rounds |

For each: compile with and without the dump and the two ELFs must be identical;
then the Sayanox-linked ELF must be byte-identical to the C-linked one; then
both are `chmod +x`'d, run, and their stdout+stderr must match. Plus a
`show 42` assertion on the hello fixture so the comparison cannot be two
identical failures, and two refusal legs (a missing dump directory, and
`Makefile` passed where an ELF belongs).

Byte identity is only evidence while the two implementations agree, so the gate
also pins the layout `sxlink` hard-codes: the ELF ident bytes, `e_phnum == 3`,
the entry point at `BASE + 0x1000` (4198400), and `p_offset` of the code
segment (4096) and the data segment (12288). A change on the C side of
`write_elf()` now fails with the reason instead of appearing as an unexplained
`cmp` diff. A change on *both* sides still fails, because what is pinned is the
documented contract, not whatever the two happen to share today.

## Getting CI to the new shape took three runs

The scheduling change is the easy half of a workflow edit; the hand-off between
jobs is the half that has to be proved. All three failures were in the hand-off,
none in a gate:

| run | what failed | cause |
|---|---|---|
| [`39466336851`](https://github.com/sayan9168/sayanox/actions/runs/39466336851) | gates 3 and 4, at `chmod +x selfhost/gen2 ...` before `make` ran | the restore assumed where the artifact would be extracted, and assumed wrong; the download step reported success with nothing at those paths |
| [`39468807496`](https://github.com/sayan9168/sayanox/actions/runs/39468807496) | the same two, now naming all three files | same assumption — but the step was made to report each missing file by name, which is what turned an exit code into a diagnosis |
| [`39471474117`](https://github.com/sayan9168/sayanox/actions/runs/39471474117) | gate 3 only, at 12m22s, **inside** `make gen3` | `selfhost/test_compiler_source_features.sh` greps four files — `gen1_min.c`, `gen2.c`, `gen3.c`, `gen4.c` — and only the three binaries had been handed over. Under `set -eu` a missing file is a silent exit 1 |

What the shape is now: the bootstrap job stages the binaries **and the two
generated C files** flat in `gate-binaries/`, the consumers download into
`gate-binaries/` and *search* it for each name, copy each to the path the
Makefile wants, `touch` the `.c` files and then the binaries (an artifact does
not preserve mtimes, and make rebuilds a target whose prerequisite is the same
age as it — without the touch, gate 3 would rebuild gen2 for four minutes and
stop being the gate it is), and finally *run* gen2 — and seed-min, in gate 4 —
on `selfhost/mini_in.sa`, because the point of a hand-off is a compiler that
works, not three files that exist.

Gate 4 passed on the third run, before the gen3 cause was known: `native-test`
needs the binaries but not the generated C.

The fourth run, [`39477167629`](https://github.com/sayan9168/sayanox/actions/runs/39477167629)
on `e6b6632`, was green end to end — the first time these four gates reported a
result on GitHub instead of a runner timeout:

| job | window | wall |
|---|---|---|
| `audit` | 18:43:00 → 18:43:06Z | 6s |
| `bootstrap` (gates 1+2) | 18:43:01 → 18:57:30Z | 14m29s |
| `fixed-point` (gate 3) | 18:57:32 → 19:07:16Z | 9m44s |
| `native` (gate 4) | 18:57:33 → 19:09:14Z | 11m41s |

Worth stating plainly, because it is the part that is easy to over-claim: the
parallel shape did **not** make CI faster. The run took 26m17s wall — *longer*
than the 25m0s ceiling that was killing it — since gates 3 and 4 still wait for
`bootstrap`, and the critical path is 14m29s + 11m41s. What changed is that the
ceiling now applies per job, where the longest job is 14m29s against a
45m0s limit, so a gate that gets slow fails as that gate, with its own log,
instead of the whole run being cancelled at a round number.

## What this does not claim

* `native_aot` still resolves a `make` name or a builtin name to a code offset,
  so `patch.bin` arrives with its targets resolved. `sxlink` turns offsets into
  bytes; it does not turn names into offsets.
* `write_elf()` in C is still what produces the executables that `make native`
  and `make native-test` run. `sxlink` is proved equivalent to it on five
  fixtures; it is not wired in as the producer, because doing that makes the
  native backend's output path depend on gen2, which is a real ordering change
  to the bootstrap and belongs to the next cut.
* `selfhost/native_aot.c` **grew** by 62 lines (the seam) and is still C:
  4,415 lines. The scanner, parser, type inference, encoder tree, the 856-line
  runtime and the 339-line collector are all still there. Its row in
  [ALL_SAYANOX_PHASE.md](../../ALL_SAYANOX_PHASE.md) stays.
* `make all-sayanox` still exits 1 and `make test-doc-claims` still requires
  that it does. Nothing here flips a phase.
* The CI change is a scheduling change. It does not skip a gate, relax an
  assertion or fetch anything from outside the repository; the only thing
  crossing a job boundary is a binary the previous job built with `make` from
  tracked sources. `full-bootstrap.yml` re-runs the whole chain in one job, in
  order, with no artifacts and no cache, nightly and on demand, so if the
  parallel shape ever hides something that workflow goes red while CI is green.
