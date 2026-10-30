# Sayanox memory management

## C-output free-pool limit (2026-10-29)

After sweeping and rebuilding membership, both C-output runtime branches now
trim their size-class free lists: retain at most two blocks per class through
64 KiB, release all larger free blocks with `free`. This bounds the cached
payload/header block sizes below 256 KiB, excluding allocator overhead, live
objects, registry/sort metadata and conservative false roots. It is not an RSS
return guarantee or an arbitrary-program bounded-heap claim. Seed and native
allocator policies are unchanged. `gc_live()` keeps its existing live-block
accounting; released cache bytes are not added to its public counters.

`test-gc` runs an actual-emitted-runtime probe maintained in
`tools/sxgc_pool_lib.sa`: intercept real frees for 60 blocks across 15 classes,
add an unrelated pre-existing warm block, check the sweep hook, per-class caps,
tracked-block free-versus-membership consistency, idempotence, exact warm reuse and live
list/data aliases at O0/O2 and ASan+UBSan (leak detection off). Both the full
and list-only runtime emitters are covered by focused development checks.

### ASan fake-stack root discovery (2026-10-30)

The remote sanitizer probe exposed a separate root-discovery bug: ASan can
move address-taken local roots (including the stack anchor and `jmp_buf`) to
its fake stack. Scanning only the apparent local-address interval could then
reclaim a live list and reuse its header as a string. This is reproducible
with `detect_stack_use_after_return=1`; it is not a free-pool cap violation.

Both C-output emitters now map a fake-stack anchor back to its real frame,
scan the real caller frames plus the saved registers, and use ASan's public
fake-stack interface to scan referenced live fake frames. Poisoned words are
still skipped and actual loads remain instrumented. The existing sanitizer
mode is unchanged; an additional mandatory probe forces fake-stack mode on.
No sanitizer suppression, root pinning in the probe, cap relaxation or
ci-guard change is used. Full CI acceptance subsequently passed on main
`7e1bfec` (run [41017856651](https://github.com/sayan9168/sayanox/actions/runs/41017856651));
see the [checkpoint evidence](gate-logs/2026-10-30-gc-full-v1.md).

Sayanox has two runtimes, and which one a program gets depends on which
backend compiles it.

## Current seed profile (2026-10-28)

The native-origin seed is maintained in
`selfhost/seed/seed_runtime_lib.sa`. It traces **strings, list headers and
backing buffers**, including transitive non-string payload edges. Payloads do
not move; aliases are not released on assignment. The dated seed measurements
below describe older implementations, not the current list lifetime policy,
thresholds or sanitizer scanning mechanism. Current stack scanning skips ASan
poisoned words rather than disabling instrumentation on the entire scanner.

Numeric backing buffers (`kind == 2`) are now **pointer-free leaves** in the
seed collector. List headers (`kind == 1`) still trace the backing-buffer
pointer; generic pointer-bearing payloads and their cycles remain traced.
Numeric words are no longer interpreted as heap edges, even if their bits
happen to equal a managed pointer. Strings remain leaves. This change applies
to the seed compatibility runtime, not the separate gen2/native collectors.
Stack/register roots are still conservative: this is not fully precise GC.

The metadata probe explicitly marks a real list header and runs the actual
heap-trace phase with pointer-shaped bits in its numeric buffer. The referenced
object must stay unmarked until a genuine generic pointer edge is marked.
No sweep is performed in this isolated precision check; subsequent real
collections check list/buffer survival, aliases and buffer growth. It fails
against the old scan-all-buffer behavior and passes at O0/O2 and ASan+UBSan.

After a complete sweep, registry buckets are now compacted when occupancy is
below one quarter. For nonempty heaps, the power-of-two bucket table has a 1,024-entry floor.
Collector scratch (sorted allocation pointers and mark bytes) also shrinks
below one-quarter occupancy, to `max(live allocations, 1024)` entries. When the registry is empty, collection frees the bucket table, sorted-pointer
array and bitmap, resetting all pointers/capacities to zero without allocating.
This releases the otherwise retained 17 KiB minimum metadata on x86-64 (not an
RSS-return guarantee). Repeated empty collections remain allocation-free; the
next allocation rebuilds the registry and later collection regrows scratch. Empty
collection also avoids passing NULL scratch to `qsort`/`memset`. No live object is
relocated and no trim runs while marking or sweeping uses the scratch arrays.

Compaction is **best effort**: a failed bucket allocation leaves the old table
and chains intact. A failed pointer-array realloc retains both old capacities;
if the pointer array shrinks but the bitmap realloc fails, the common capacity
is reduced to the smaller array while the larger old bitmap remains valid.
Later growth can retry both allocations. Metadata, fragmentation, genuinely
live heaps and conservative false roots still consume memory. This is not
precise GC, a guaranteed RSS decrease, or bounded memory for arbitrary programs.

`./sx target test-seed-collector` now also builds a compatibility-C probe from
the **actual seed-emitted runtime**, with the probe maintained as Sayanox source
in `tools/sxseed_metadata_lib.sa`. It grows over 8,192 live allocations, drops
most, and asserts bucket/scratch compaction, live alias/cycle identity, exact
registry membership, foreign/interior pointer rejection, and regrowth. Four
cases exercise ordinary compaction and injected bucket, pointer-array and
bitmap allocation failures, including growth after the partial bitmap failure.
An initially empty collection is checked separately. Three additional rounds
explicitly empty the registry with the runtime free helper (so conservative
stack remnants cannot make the test nondeterministic), assert zero metadata
under forced allocation failure, repeat empty collection and regrow past 8,192
allocations. These probes run at O0/O2 and with ASan+UBSan in the collector gate. The existing 64 MiB
seed/gen2 churn and native parity fixtures remain required. The optional
`./sx target test-seed-sanitize` includes this probe as its sixth ASan/UBSan
fixture; **leak detection remains disabled**, not a leak-free claim.

Focused collector/sanitizer gates and new guarded `./sx ci` passed locally.
Final acceptance additionally requires both new remote jobs to succeed; follow
[PR #42 checks and completion evidence](https://github.com/sayan9168/sayanox/pull/42).
Earlier release success is not acceptance for this change.

## 1. gen2-compiled programs: conservative mark & sweep (the default)

Programs compiled by `selfhost/gen2` — and by `gen1_min`, which emits the same
prelude — link a **non-moving, conservative mark & sweep collector**. The
collector lives in `selfhost/compiler_min.sa` as part of the emitted prelude,
so it is exercised by every `make gen2`.

### What is managed

* every string byte buffer (`chr`, `concat`, `read_file`, `read_line`,
  `read_n`, `numstr`, ...)
* `sx_list` headers and their element buffers (list literals, `push`, growth)

Allocations go through `sx_gc_alloc(kind, payload)`: 26 size classes from
32 bytes up to 1 GiB (`SX_NCLS`, size `32 << class`), each with its own free
list, plus a sorted block list for interior-pointer lookups and a hash table
for O(1) "is this a block?" checks.

### How it runs

* `sx_gc_init(&sx_gcanchor)` runs at the top of `main`; the collector scans the
  machine stack between that anchor and its own frame, plus the `jmp_buf` it
  spills the caller-saved registers into (`setjmp`). Anything that looks like a
  pointer into (or into the interior of) a live block keeps that block alive.
* Marking recurses into list element buffers; sweeping pushes dead blocks onto
  the per-class free lists and updates the live-byte counter.
* A collection triggers automatically when the live bytes since the last
  collection reach `1.5 * reclaimed + 4 MiB`, and on demand from the language.

### Language surface

| call | meaning | C runtime name |
|------|---------|----------------|
| `gc()` | collect now, returns the bytes reclaimed | `sx_gc_run` |
| `gc_live()` | bytes currently held by the managed heap | `sx_gc_live` |
| `gc_runs()` | number of collections so far | `sx_gc_count` |

`make test-gc` compiles a Sayanox program that concatenates in a loop, and
asserts that the heap stays bounded, that a collection happened, that `gc()`
runs, and that the surviving string is still intact.

### Honest boundaries

* **Non-moving**: block addresses are stable, so interior pointers are found by
  binary search over the sorted block list. No compaction, no handle
  indirection, no moving/fragmenting collector.
* **Conservative**: a word that merely looks like a pointer pins a block. This
  can only delay reclamation, never cause a false reclamation.
* **Stop the world, single threaded**: no concurrent marking, no background
  threads, no finalizers, no weak references.
* The collector costs about 5 KB of C in every emitted program, and the prelude
  now emits `#include <setjmp.h>` unconditionally.

Peak RSS of the compiler itself dropped from 218.6 MB to 32.6 MB once the
collector was in place (see the table in [`STATUS.md`](STATUS.md)).

## 2. Native AOT and the seeds

### The native collector

`selfhost/native_aot.c` — the x86-64 direct backend — has a real mark & sweep
collector, not a bump-only arena. It shares the design of §1 (tracing, so
cycles are not a problem) but is precise about roots instead of fully
conservative, because the emitter knows exactly where a heap pointer can live.

**Blocks.** Every value the runtime allocates gets a 32-byte header in front of
a 16-byte-aligned payload:

```
  +0   size | FREE   bit 0 marks a free block; bits 1-3 are always 0
  +8   magic         SX_BLK_MAGIC, so a stray integer never looks like a block
  +16  mark / next   mark bit during a collection, free-list link otherwise
  +24  kind          num / str / list / struct
  +32  payload
```

**Chunks.** Blocks live in `mmap`ped chunks (64 KiB, or page-rounded `need +
64 KiB + 4 KiB + header` for a big request). Chunks are linked through their
first 8 bytes, so the collector can walk every block it ever handed out, and
`[OFF_HLO, OFF_HHI)` records the whole window so a candidate pointer can be
rejected with two compares.

**Allocation.** `r_malloc` is first-fit over the free list, splitting a block
when at least 48 bytes are left over; otherwise it hands the block out whole
(keeping its real size, so the walk stays in step). If nothing fits it bumps
the cursor of the current chunk, and if that is exhausted it maps a new chunk.

**Roots.** Two sources, both scanned by `r_gc`:

* *precise* — a root table at `OFF_ROOTS`, filled in after codegen when the
  kind of every global is final, listing the data-segment offset of every
  string, list and struct slot plus the literal scratch word;
* *conservative* — every word in `[rsp, OFF_STKTOP)`. `gc()` is an ordinary
  call that may sit in the middle of an expression, where a half-built value
  lives only on the machine stack. A word that merely *looks* like a pointer
  can delay a reclamation and can never cause a false one, because a candidate
  is only accepted at an exact payload start behind a matching magic word.

Marking recurses into `BK_STRUCT` blocks word by word. Strings are leaves;
lists contain doubles plus the runtime growth-forward pointer, which is traced
explicitly. A list-valued struct field is therefore safe: its word marks the
list header, and list marking retains its backing/growth chain.

**Sweep.** Three passes over every chunk: free unmarked blocks (reclaiming
their bytes) and coalesce adjacent free runs; hand the runs back to the free
list; then `munmap` any chunk that is now entirely free and is not the chunk
the bump cursor lives in — without that, a program whose live set keeps
growing would keep every chunk it ever mapped.

**Trigger.** `r_gccheck` is emitted at every statement boundary, where the only
heap pointers are globals and the machine stack, and collects once the bytes
allocated since the last collection pass `max(2 * live, 64 KiB)`.

**Language surface.** `gc()`, `gc_live()` and `gc_runs()` are real on native:
`gc()` collects now and returns the bytes it reclaimed, `gc_live()` reports the
bytes the last sweep saw alive (plus whatever has been allocated since), and
`gc_runs()` counts the collections.

`make test-native-mem` pins that contract:

* a string doubled 18 times (262144 bytes, far above one 64 KiB chunk) is
  served whole and its last byte reads back correctly;
* a 100000-element `push` loop (growth crosses many chunks) keeps every value:
  `len` 100000, `xs[0]` 0, `xs[99999]` 99999;
* a 200000-iteration churn loop — roughly 8 MB of allocation, nothing
  retained — **finishes inside a 4 MiB `ulimit -v` cap**, running 200+
  collections. This is the assertion the old bump allocator failed, and the
  reason the backend has a collector at all;
* `gc_runs()` is greater than zero after 5000 allocating iterations, `gc()`
  returns a positive number of reclaimed bytes, and `gc_live()` reports a
  positive live count;
* strings, list elements and struct fields still read back correctly after
  30000 allocating iterations, so nothing reachable is reclaimed;
* `test-list-struct-fields` first grows `p.xs` through an alias, then retains
  the original field pointer through 6000 allocating iterations, requires
  `gc_runs() > 0`, and iterates the current list; this pins both the
  `BK_STRUCT` list-pointer root and the list growth-forward tracing path.
* a program that genuinely *retains* more than 4 MiB (a string doubled 20
  times, 8 MiB live) still dies with the documented `out of memory` message and
  a non-zero exit status, keeping the output it wrote first.

### Honest boundaries (native)

* The collector is not compacting and not generational: blocks never move, so
  a long-running program can still fragment.
* The conservative half of the root set can retain garbage — a stale stack
  word that happens to point into the heap keeps that block alive until the
  word is overwritten. That costs memory, never safety.
* Chunks are only handed back when a sweep empties one completely; a chunk
  holding one small live block stays mapped.
* Native is still not a full-language backend. Its tested subset includes
  `for`, `break` and `continue`; unsupported forms must keep producing a
  backend diagnostic rather than x86 code with guessed semantics. See the
  Stage-2 slice in [`STATUS.md`](STATUS.md).

### The two seeds, measured

Both seeds are compilers that emit C with a runtime prelude. `make test-seed-gc`
measures what they actually do, under `ulimit -v` address-space caps (4 MiB is
the floor for a dynamically linked binary: below it `libc.so.6` itself cannot
be mapped).

**`selfhost/seed/sxc_seed_min` — the bootstrap seed: a conservative collector
since 2026-10-22.** Its prelude still uses malloc/free and the exact, resizable
builder allocation registry added on 2026-10-15: the registry decides whether a
pointer owns a builder without dereferencing bytes before a string literal, and
`sx_sb_free` removes an owning entry when a variable is reassigned. What is new
is that the same registry is now also the collector's block list — see
[A collector in the bootstrap seed](#a-collector-in-the-bootstrap-seed-2026-10-22)
below. The old magic-header probe caused an ASan global-buffer-overflow and has
been removed.

* Strings produced by `concat` / `chr` / `read_file` carry a hidden header
  `{len,cap,next,data[]}`. Each concat allocates a fresh buffer and copies its
  arguments. Earlier “in-place, amortised O(1)” documentation was incorrect;
  repeated append still copies accumulated bytes.
* Reassignment evaluates the RHS before releasing the old LHS. This keeps
  tested self-reassignment/alias patterns safe; it is not a complete ownership
  model for arbitrary programs.
* Read-only string parameters are now borrowed. A conservative lexical scan
  keeps entry copies for parameters that might be rebound by assignment,
  annotation or a for binder, even in nested control flow. String locals and
  returned strings retain their existing copy behavior. No calling convention
  change or free-at-every-return transformation was introduced.

`test-seed-gc` still proves the existing 200k churn, 2000-step accumulation and
temporary loop fit a 4 MiB address-space cap — on the freeing assignment alone,
below the collector's 8 MiB threshold — and that an oversized *retained* string
still fails loudly without losing preceding stdout: collecting cannot reclaim a
live set. `gc()`, `gc_live()` and `gc_runs()` now answer in seed-min too, with
the same meaning they have on gen2 and native.

New `test-seed-borrow` pins seed alias/reassignment/recursive return/binder
cases and a shared seed/gen2/native stress fixture: 30,000 reads of a 16 KiB
string with a live list. Optional Linux `wait4`/`ru_maxrss` measurements:

| Seed-generated program | Before (KiB) | Final (KiB) |
|---|---:|---:|
| gen1-min compiling compiler_min.sa into gen2 C | 3,823,428 | 704,184 |
| read-only string stress | 482,992 | 1,468 |

The compiler outputs compared byte-identical. Stress failed at a 128 MiB
address-space cap before and passed after. Those two numbers predate the
collector; the current ones are in the 2026-10-22 section below. Dropped string
locals, unused string results and string temporaries are reclaimed now —
**lists are not**: `sx_list` headers and their element buffers are plain
`malloc` in the seed runtime and are never freed, and the registry's bucket
capacity still does not shrink.

`seed_builder_registry_test.c` exercises the actual emitted runtime with 4096
live builders, table growth, release/reallocation, interior/foreign pointers
and overlapping concat inputs. The alias and registry probes pass ASan/UBSan
with **leak detection disabled**. These optional measurements/sanitizers are
not bootstrap dependencies; logs are `ten-memory.log` and `ten-borrow-asan.log`.
The legacy full seed below was not changed by this optimization.

**`selfhost/seed/sx_runtime.h` — the full seed: a reference-counted
representation that does not reclaim.** The runtime has `SxStrHdr` string
headers, retain/release functions, an object table (`SX_TAB_CAP` 2097152) and
`gc()` kept as a documented no-op alias that returns `0.0`; `gc_live()` and
`gc_runs()` do not exist there at all. Measured with `SX_GC_DEBUG=1`, which
prints a live-object count at exit:

| program | objects alive at exit |
| --- | --- |
| `hold s = "x"` / `show len(s)` | 1 |
| 2000 iterations of `hold t = concat("aaa…", "b")`, nothing retained | **6000** |
| 2000 concats accumulating into one retained string | **4001** |

Three objects per iteration stay registered, so the release path does not fire
in a loop: memory grows with *total* allocation, not with the live set. The
same churn that leaves seed-min flat inside 4 MiB needs 64 MiB here, and a
1M-iteration version dies with `sx: out of memory` (or
`sx: runtime object table overflow` once the 2097152-entry table is full).
Because the object table is a static array, a 4 MiB cap cannot even start a
full-seed program — it faults in the loader — so `test-seed-gc` measures this
backend under a 64 MiB cap. Two further measured facts: values it prints use a
different format (`8388608` where the other three backends print
`8.38861e+06`), and a program using `%` needs `-lm` *after* the sources on the
link line, because `sx_modv` calls `fmod`.

* `selfhost/rc_runtime.h` is the standalone reference-counting experiment
  exercised by `selfhost/rc_runtime_stress.c`. It is the historical slice that
  `make gc-test` still checks: a managed string header with a reference count,
  `sx_rc_retain` / `sx_rc_release`, deterministic release at zero, and no
  background collector.
* `selfhost/rc_runtime.h` is the standalone reference-counting experiment
  exercised by `selfhost/rc_runtime_stress.c`. It is the historical slice that
  `make gc-test` still checks: a managed string header with a reference count,
  `sx_rc_retain` / `sx_rc_release`, deterministic release at zero, and no
  background collector.

## Stress tests

```sh
make gc-test         # reference-counting runtime slice (2000 concats, length + ok)
make test-gc         # gen2 mark & sweep: bounded heap, collections, gc()/gc_live()
make test-native-mem # native mark & sweep: churn inside a 4 MiB cap, no UAF
make test-list-struct-fields # seed/native list-field aliases + native GC root probe
make test-seed-gc    # both seeds: builder + freeing assignment, no-op gc(),
                     # live-object counts, and what each one does under a cap
make test-seed-collector # seed-min/gen2/native on one fixture: 4,000,000
                     # dropped temporaries, a borrowed read and an untouched
                     # 512 KiB live string, all inside a 64 MiB cap
```

`test-seed-gc` also pins gen2's behaviour under address-space pressure: its
first collection only fires at 8 MiB of managed heap (`sx_gc_thresh` starts at
`8u << 20`, afterwards `live * 1.5 + 4 MiB`), so the 200k churn that native runs
inside 4 MiB needs 64 MiB there and cannot run in 16 MiB. That used to be a
segfault, because the collector ignored the results of its own `calloc` (block
hash table) and `malloc` (sort array, new block); all three sites now exit 1
with `sx: out of memory`, and the target asserts the three checks are present
in the generated C.

CI runs these as part of `make test`. Since 2026-10-22 the `.sa -> gen1`
bootstrap path *does* include a collector: `gen1_min` is a seed-emitted program
like any other, so it collects while it compiles. The gate that keeps that
honest is `make true-selfhost` plus `test-seed-bootstrap-budget` — the C it
emits must stay byte-identical to the uncapped gen2 C.

## What is not implemented

* No concurrent or incremental collector.
* No moving/compacting collector.
* No finalizers or weak references.
* No cycle problem *for the collector* (tracing reclaims cycles), but the
  `rc_runtime.h` slice cannot reclaim cycles.
* No compacting or generational collector on either backend: blocks never
  move, so a long-running program can fragment.
* Not every C `malloc` in the compiler tooling is managed.
* No collector in the **full** seed: its reference counts are measured not to
  release in loops. `sxc_seed_min` does collect since 2026-10-22, but only
  builder strings — seed lists (`sx_list` and their element buffers) are plain
  `malloc` there and are still never freed.
* No heap-threshold tuning knob: gen2's 8 MiB first-collection threshold is a
  constant in the emitted runtime, which is why it needs more address space
  than native for the same churn.

### Finite no-GC bootstrap budget and repeatable sanitizers (2026-10-16)

This increment deliberately keeps the seed runtime unchanged: no RC, freelist,
collector, implicit list release, or new ownership convention. The bootstrap
root remains seed-min. Gen2 and native retain their existing mark/sweep.
Stronger executable evidence is available instead:

* `make test-seed-borrow` now runs the 30,000-read / 16 KiB source fixture
  under a **128 MiB address-space cap**, checking all output and the retained
  list. The shared gen2/native output checks remain.
* `make test-seed-gc` now includes `test-seed-list-budget`: **20,000 pushes**
  through a list parameter/return, with a second live alias, under **32 MiB**.
  It verifies length, first value, appended endpoints and alias identity through
  multiple reallocations. It allocates one growing list, **not** 20,000 dropped
  lists; this is not evidence of list reclamation.
* The emitted-runtime registry probe now repeats **32 cycles of 4,096 live
  builders**. Each cycle asserts zero remaining registered builders after
  explicit releases and unchanged bucket capacity. This tests explicit release
  and table reuse; it does not add generated cleanup of locals or temporaries.
* Optional `make test-seed-sanitize` compiles the actual seed-emitted borrow,
  read-stress and list-budget C plus the emitted-runtime registry harness with
  ASan/UBSan. It fails on sanitizer errors and compares program stdout to the
  ordinary builds. **Leak detection is explicitly disabled**; it is not a
  leak-free claim or an audit of the seed compiler's own C implementation.
  Sanitizer support is not required by the four bootstrap gates. The default
  flags use non-PIE executables; `SANITIZER_FLAGS` is overridable. No virtual
  address-space cap is applied to ASan's shadow mappings.
* After `make true-selfhost`, optional `make test-seed-bootstrap-budget`
  reruns the **real no-GC gen1-min compiling the current compiler source**
  under **1,536 MiB virtual address space**, then compares its output byte for
  byte with the uncapped gen2 C. It passed on this Linux sandbox. This is a
  fixed-input process budget, not a measured peak RSS or a bound for arbitrary
  source sizes/programs. Cap recipes use the existing Linux `ulimit -v` model.
  *(That cap is 64 MiB as of 2026-10-22, and gen1-min is no longer no-GC —
  see the next section.)*

The intentional operating model is a finite, short-lived bootstrap process;
process exit returns unreleased allocations to the OS. Dropped lists, unused
results, temporaries and some locals still accumulate. The legacy full seed
still has no effective collection path. Do not use either as a long-running
bounded-heap runtime on the strength of these tests.

All four required gates passed in order (`doctor`, `true-selfhost`, `gen3`,
`native-test`), including byte-identical gen3/gen4. Actual combined stdout/stderr:
[`2026-10-16 seed budget logs`](gate-logs/2026-10-16-seed-budget/).
`sanitize.log` and `bootstrap-budget.log` record the optional evidence. The new
recipes use C, make and shell/utilities only; no interpreter was added to the
bootstrap path. Full-language self-host is still not claimed.

### A collector in the bootstrap seed (2026-10-22)

`selfhost/seed/sxc_seed_min` now emits a **non-moving conservative mark &
sweep** for builder strings. The exact allocation registry it already kept is
reused as the collector's block list, so this is roughly 55 lines of extra C in
the prelude rather than a new allocator.

**How it finds roots.** The C stack, and nothing else. The seed used to emit
the whole program body inside `main`; it now emits

```c
static int sx_prog(void){ /* every Sayanox variable is a local here */ }
int main(int argc,char **argv){ g_argc=argc; g_argv=argv;
  volatile unsigned char sx_gcanchor=0;
  int (*volatile sx_entry)(void)=sx_prog;
  sx_gc_init((void*)&sx_gcanchor);
  return sx_entry(); }
```

so `main`'s frame — which holds the anchor — always sits above every Sayanox
variable, and the volatile function pointer keeps the call indirect so the body
cannot be inlined back into `main`. `sx_gc_collect` then `setjmp`s to spill the
registers and scans every aligned word between its own frame and that anchor.
That is sufficient because **no heap object in this runtime holds a string
pointer**: lists hold doubles, struct values are C locals, and the only globals
are `g_argc`/`g_argv` and the registry itself.

**The rest of the mechanism.**

* Interior pointers keep their block alive: the blocks are sorted by address at
  the start of each collection and a candidate word is matched by binary search
  against the whole block (header through `data[cap]`). A cursor into the middle
  of a string, such as the ones the runtime's own helpers hold while they
  allocate, is a root.
* Nothing moves and no object is copied, so borrowed read-only parameters
  (see `test-seed-borrow`) stay valid across a collection.
* Sweeping frees the unmarked blocks and rebuilds the registry's buckets from
  the survivors, so the registry and the collector cannot disagree about what
  exists.
* First collection at 8 MiB of live builder bytes, afterwards
  `live * 1.5 + 8 MiB`. `gc()` collects on demand, and a failing `malloc`
  retries once after a collection instead of exiting immediately.
* The scan function carries `no_sanitize_address` behind a feature test
  (`__SANITIZE_ADDRESS__` / `__has_feature`). Without it ASan reports a
  stack-buffer-overflow on the first root scan, because reading other frames'
  redzones is exactly what a conservative collector does; `test-seed-sanitize`
  runs a collecting fixture under ASan/UBSan to keep that opt-out honest.
* The freeing assignment wrapper is unchanged and still runs first. It reclaims
  the common case immediately; the collector only has to find what the wrapper
  cannot see — dropped temporaries, discarded results, locals never reassigned.

**Language surface.** `gc()`, `gc_live()` and `gc_runs()` now exist on all three
backends with the same meanings as §1 (`sx_gc_run` returns the bytes freed by
that collection, `sx_gc_live` the live builder bytes, `sx_gc_count` the number
of collections). `gc(1)` is still a compile-time error with a `seed_min:`
diagnostic.

**Measured on this machine (gcc 12.2, same input, back to back).**

| measurement | before | after |
|---|---:|---:|
| gen1-min compiling `compiler_min.sa`, peak RSS | 1,278,704 KiB | 29,768 KiB |
| the same compile, wall clock | 255 s | 272 s |
| the same compile, address-space cap it passes | 1,536 MiB (gate) | 48 MiB measured, **64 MiB** gated |
| `seed_gc_drop.sa` churn (4,000,000 dropped temporaries), peak RSS | 346,872 KiB | 17,556 KiB |
| the same churn under `ulimit -v 65536` | `sx: out of memory` | runs in 0.5 s |

Both compiles emitted **byte-identical gen2 C**, which is the real argument
that the collector is correct: a three-minute compile that allocates gigabytes
and collects dozens of times produced the same 2.9 MB of C as the version that
never freed anything.

**What did not change.** Seed lists (`sx_list` headers and their element
buffers) are still plain `malloc` and are never freed. The registry's bucket
array still never shrinks. The full seed (`sx_runtime.h`) is untouched and its
reference counts still do not release in loops. gen2 and native keep their own
collectors; nothing in their emitted runtimes changed.

**Honest boundaries.** This is not a bounded-heap claim for arbitrary programs:
a genuinely live set still dies loudly (`test-seed-gc` keeps the 8 MiB retained
string failing with `sx: out of memory` inside a 4 MiB cap), conservative roots
can retain garbage until the stack word is overwritten, and the collector
itself needs a little memory to run — if its two arrays cannot be allocated it
skips the collection and raises the threshold rather than failing. Stack-only
roots are sound *because* of the shape the seed emits; a future seed that
stored strings in heap objects would have to trace them.

**Gates.** `make test-seed-collector` (new: the three-backend fixture),
`make test-seed-gc`, `make test-seed-borrow`, `make test-seed-sanitize`,
`make test-seed-bootstrap-budget`, and above all `make true-selfhost` and
`make gen3`, which now run the collector inside the bootstrap itself.
