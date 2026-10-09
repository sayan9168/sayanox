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

Marking recurses into struct blocks only: strings hold bytes and lists hold
doubles, so both are leaves.

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
* Native still rejects, by name, the full-language statements the backend does
  not model: `for`, `break`, `continue` and `elif` (see the Stage-2 slice in
  [`STATUS.md`](STATUS.md)). Native programs therefore stay in the pure-min
  statement set.

* `selfhost/seed/sxc_seed_min` (the bootstrap seed) has a malloc-only prelude
  and frees only the previous value of a reassigned string variable. Its point
  is to be small and auditable, not to manage memory well.
* `selfhost/seed/sx_runtime.h` is the reference-counted runtime used by the
  full seed `sxc_seed` (`sx_rc_retain` / `sx_rc_release`, `SxRcStr` headers,
  reference counts on lists). `release(value)` performs a deterministic RC
  release there.
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
```

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
