# 2026-10-22 — a collector in the bootstrap seed

Roadmap row 3 said: *no collector, no reference counting, no freelist in
`sxc_seed_min` — an allocation registry and nothing more.* That is no longer
true. The bootstrap seed now emits a **non-moving conservative mark & sweep**
for builder strings, the registry it already kept is reused as the collector's
block list, and the three collector builtins answer on all three backends.

| | Was | Is now | Gate |
|---|---|---|---|
| 3. Seed GC | registry + freeing assignment; everything else accumulated | conservative mark & sweep over that registry; `gc()` / `gc_live()` / `gc_runs()` | `test-seed-collector`, `test-seed-gc` |
| bootstrap memory | gen1-min peaked at **1,278,704 KiB**, gated under a 1,536 MiB cap | peaks at **29,768 KiB**, gated under **64 MiB** | `test-seed-bootstrap-budget` |
| ASan | no conservative scan to defend | collecting fixture runs clean under ASan/UBSan | `test-seed-sanitize` |

## What the seed emits now

The collector needs to know where the roots are. The seed used to emit the
whole program body inside `main`, which makes "every Sayanox variable" and
"the stack anchor" live in the *same* frame — the scan would have had no
defined boundary. So the body moved into its own function:

```c
static int sx_prog(void){ /* every Sayanox variable is a local here */ }
int main(int argc,char **argv){ g_argc=argc; g_argv=argv;
  volatile unsigned char sx_gcanchor=0;
  int (*volatile sx_entry)(void)=sx_prog;
  sx_gc_init((void*)&sx_gcanchor);
  return sx_entry(); }
```

`main`'s frame now always sits above every Sayanox variable, and the volatile
function pointer keeps the call indirect so the body cannot be inlined back
into `main` and lose that ordering. This is the same arrangement gen2 has used
for its own collector (`_sx_gc_program`) since it was written.

`sx_gc_collect` then `setjmp`s to spill the registers and walks every aligned
word between its own frame and that anchor. The C stack is the **whole** root
set, and that is sound only because of the shape this seed emits: lists hold
doubles, struct values are C locals, returned strings are copies, and the only
globals in the prelude are `g_argc`/`g_argv` and the registry itself. No heap
object in the seed runtime holds a string pointer.

The rest is deliberately small — about 55 lines of C in the prelude:

* **Interior pointers count.** Blocks are sorted by address at the start of a
  collection and a candidate word is matched by binary search against the
  whole block, header through `data[cap]`. The runtime's own helpers hold
  cursors into the middle of a string while they allocate; those are roots.
* **Nothing moves.** Borrowed read-only parameters (`test-seed-borrow`) stay
  valid across a collection, and no handle indirection was introduced.
* **The registry is the block list.** Sweeping frees the unmarked blocks and
  rebuilds the buckets from the survivors, so the registry and the collector
  cannot disagree about what exists.
* **Thresholds.** First collection at 8 MiB of live builder bytes, then
  `live * 1.5 + 8 MiB`. `gc()` collects on demand; a failing `malloc` retries
  once after a collection instead of exiting immediately.
* **The freeing assignment stays and still runs first.**
  `{ char *_v = sx_cat(a,b); sx_sb_free(a); a = _v; }` reclaims the common
  case with no tracing at all. The collector only has to find what that
  wrapper cannot see: dropped temporaries, discarded results, and locals that
  are simply never reassigned.
* **ASan.** The scan function carries `no_sanitize_address` behind a feature
  test. Without it, ASan reports `stack-buffer-overflow` on the first root
  scan — reading other frames' redzones is exactly what a conservative
  collector does. That was verified by removing the attribute and watching the
  report appear, which is why `test-seed-sanitize` now runs a *collecting*
  fixture rather than only non-collecting ones.

## The measurements

Same machine, same input, back to back (gcc 12.2):

| measurement | before | after |
|---|---:|---:|
| gen1-min compiling `compiler_min.sa`, peak RSS | 1,278,704 KiB | **29,768 KiB** |
| the same compile, wall clock | 255 s | 272 s |
| the same compile, smallest `ulimit -v` that passes | — (gated at 1,536 MiB) | 48 MiB measured, **64 MiB** gated |
| 4,000,000 dropped temporaries, peak RSS | 346,872 KiB | **17,556 KiB** |
| the same churn under `ulimit -v 65536` | `sx: out of memory` | runs in 0.5 s |

Both compiles emitted **byte-identical gen2 C**. That is the real argument
that the collector is correct: a four-minute compile that allocates gigabytes
and collects dozens of times produced the same 2.9 MB of C as the version that
never freed anything, and then `make gen3` showed gen3.c == gen4.c on top of
it.

The 43× memory reduction costs 7% more wall clock. That trade is also what
unblocks the three roadmap rows that need `selfhost/compiler_min.sa` to grow:
the previous increment left them alone because the bootstrap was close to the
machine's memory ceiling.

## The new gate

`selfhost/seed_gc_drop.sa` is one fixture that all three backends compile and
run to the same seven lines:

```
524288        len(keep): a 512 KiB string the churn loop never touches
4.88e+08      the loop's accumulator: 4,000,000 * (7 + 115)
1             gc_runs() after an explicit gc(), minus gc_runs() before it
auto          gc_runs() was ALREADY non-zero: the runtime collected by itself
524288        keep is still exactly as long after every collection
97            keep[0]
112           keep[524287]
```

It drops 4,000,000 temporaries that no assignment can ever free (the wrapper
only sees the variable being reassigned, and nothing here is), reads a
borrowed read-only parameter in the same loop, and holds `keep` alive in the
frame *below* the loop — reachable only if the root scan really walks the
whole stack. `test-seed-collector` pins all seven lines on seed-min, gen2 and
native inside a 64 MiB address space, and greps the emitted C for the anchor,
the entry function, the automatic trigger and the ASan opt-out.

`test-seed-gc` changed where it had to: it used to assert that seed-min
*refuses* `gc()`. It now asserts that `gc()`, `gc_live()` and `gc_runs()`
answer with real numbers, that `gc(1)` is still a `seed_min:` diagnostic, and
— unchanged — that a genuinely live 8 MiB set still exits 1 with `sx: out of
memory` inside a 4 MiB cap. Collecting cannot reclaim a live set, and the gate
still says so.

## What did not change

* **Seed lists are still never freed.** `sx_list` headers and their element
  buffers are plain `malloc` in the seed runtime; only builder strings are
  collected. `test-seed-list-budget` remains a finite-workload gate, not a
  reclamation claim.
* The registry's bucket array still never shrinks.
* The full seed (`selfhost/seed/sx_runtime.h`) is untouched: its reference
  counts still do not release in a loop, `gc()` there is still a no-op
  returning 0, and `gc_live()` still does not exist.
* gen2 and native keep their own collectors; nothing in their emitted runtimes
  changed, and `make test-gc` / `make test-native-mem` are unmodified.
* No new bootstrap dependency: the collector is C in the emitted prelude, and
  `test-language-deps` still passes.

## Honest boundaries

This is not a bounded-heap runtime. Conservative roots can retain garbage
until the stale stack word is overwritten; the collector itself needs a little
memory to run and will skip a collection (raising its threshold) rather than
fail if it cannot allocate its two scratch arrays; and the stack-only root set
is sound *because* of the shape this seed emits — a future seed that stored
strings inside heap objects would have to trace them.

## Gates

```
make test-seed-collector        # the new three-backend fixture
make test-seed-gc               # both seeds, caps, builtins, live-set OOM
make test-seed-borrow           # borrowed reads still valid across collections
make test-seed-sanitize         # ASan/UBSan, now including a collecting run
make test-seed-bootstrap-budget # gen1-min inside 64 MiB, identical gen2 C
make test-seed-for-untyped      # `hold a = gc()` is no longer an error case
make test-language-deps         # no bash/awk/sed/python in the new recipes
```

and the four hard gates, all green on this tree:

```
make doctor         # DOCTOR-OK
make true-selfhost  # TRUE-SELFHOST-MIN-OK
make gen3           # GEN3-OK (gen3.c == gen4.c)
make native-test    # NATIVE-TEST-OK
```

Run as plain `make` (no `-o restore-compiler`) on this tree in 36 minutes,
12:36:45 to 13:12:57 UTC; see `hard-gates.log` in this folder for the four
markers, `[OK] byte-identical gen3 == gen4`, and this increment's gates with
the line numbers at which they ran inside the aggregates.
