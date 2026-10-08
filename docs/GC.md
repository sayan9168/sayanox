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

* `selfhost/native_aot.c` is the x86-64 direct backend. Its runtime is a flat
  BSS data area plus one bump allocator over lazily `mmap`ped 64 KiB chunks
  (a request bigger than 64 KiB gets its own page-rounded chunk). It never
  frees; native programs are for demos and small benchmarks. That is not
  "zero memory management": when `mmap` fails, `r_malloc` dies with the
  documented `out of memory` message and a non-zero exit status instead of
  corrupting memory. `make test-native-mem` pins all of it: a 2000-iteration
  `concat` loop and a 1500-element `push` loop keep computing correct values
  and indexes, the same big-allocation program under a 4 MiB
  `ulimit -v` cap dies loudly, and the gen2-only collector builtins
  (`gc()`, `gc_live()`, `gc_runs()`) are compile-time errors in native.
  A real free path would need ownership and aliasing information the
  hand-written emitter does not track (a string slot can be aliased by a
  copy, a struct field or a loop-carried value), so it is not claimed.
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
make gc-test     # reference-counting runtime slice (2000 concats, length + ok)
make test-gc     # gen2 mark & sweep: bounded heap, collections, gc()/gc_live()
```

CI runs both as part of `make test`. No GC feature changes the pure
`.sa -> gen1` bootstrap path: the seed compiler never sees the collector.

## What is not implemented

* No concurrent or incremental collector.
* No moving/compacting collector.
* No finalizers or weak references.
* No cycle problem *for the collector* (tracing reclaims cycles), but the
  `rc_runtime.h` slice cannot reclaim cycles.
* The native AOT backend still bump-allocates and never frees.
* Not every C `malloc` in the compiler tooling is managed.
