# Sayanox memory management

Sayanox has two runtimes, and which one a program gets depends on which
backend compiles it.

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

Both seeds are compilers that emit C with a runtime prelude, and neither has a
collector in the sense of §1 or §2. `make test-seed-gc` measures what they
actually do, under `ulimit -v` address-space caps (4 MiB is the floor for a
dynamically linked binary: below it `libc.so.6` itself cannot be mapped).

**`selfhost/seed/sxc_seed_min` — the bootstrap seed: no collector, by design.**
As of 2026-10-15 its prelude uses malloc/free and an exact, resizable builder
allocation registry. This is **not a collector or reference counting**: the
registry determines whether a pointer owns a builder without dereferencing
bytes before a string literal. `sx_sb_free` removes an owning entry; foreign
and interior pointers are not freed. The old magic-header probe caused an
ASan global-buffer-overflow and has been removed.

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

`test-seed-gc` still proves the existing 200k churn, 2000-step accumulation
and temporary loop fit a 4 MiB address-space cap, and that an oversized retained
string fails loudly without losing preceding stdout. It refuses `gc()` rather
than pretending to collect. (Native does have working collection.)

New `test-seed-borrow` pins seed alias/reassignment/recursive return/binder
cases and a shared seed/gen2/native stress fixture: 30,000 reads of a 16 KiB
string with a live list. Optional Linux `wait4`/`ru_maxrss` measurements:

| Seed-generated program | Before (KiB) | Final (KiB) |
|---|---:|---:|
| gen1-min compiling compiler_min.sa into gen2 C | 3,823,428 | 704,184 |
| read-only string stress | 482,992 | 1,468 |

The compiler outputs compared byte-identical. Stress failed at a 128 MiB
address-space cap before and passed after. This does **not** establish bounded
memory for arbitrary no-GC programs. Lists, dropped locals, unused function
results and temporaries still lack general reclamation; the registry itself
retains unreleased builders and its bucket capacity does not shrink.

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
```

`test-seed-gc` also pins gen2's behaviour under address-space pressure: its
first collection only fires at 8 MiB of managed heap (`sx_gc_thresh` starts at
`8u << 20`, afterwards `live * 1.5 + 4 MiB`), so the 200k churn that native runs
inside 4 MiB needs 64 MiB there and cannot run in 16 MiB. That used to be a
segfault, because the collector ignored the results of its own `calloc` (block
hash table) and `malloc` (sort array, new block); all three sites now exit 1
with `sx: out of memory`, and the target asserts the three checks are present
in the generated C.

CI runs these as part of `make test`. No GC feature changes the pure
`.sa -> gen1` bootstrap path: the seed compiler never sees the collector.

## What is not implemented

* No concurrent or incremental collector.
* No moving/compacting collector.
* No finalizers or weak references.
* No cycle problem *for the collector* (tracing reclaims cycles), but the
  `rc_runtime.h` slice cannot reclaim cycles.
* No compacting or generational collector on either backend: blocks never
  move, so a long-running program can fragment.
* Not every C `malloc` in the compiler tooling is managed.
* No collector in either seed. `sxc_seed_min` is documented no-GC (builder
  strings plus a freeing assignment cover the accumulation patterns, everything
  else leaks) and the full seed's reference counts are measured not to release
  in loops. Neither is on the bootstrap path's memory story: the bootstrap
  compiles the compiler, it does not run long-lived programs.
* No heap-threshold tuning knob: gen2's 8 MiB first-collection threshold is a
  constant in the emitted runtime, which is why it needs more address space
  than native for the same churn.
