# Sayanox memory management

## Model: reference counting

Sayanox's managed string/list runtime uses **single-threaded reference counting**. There is no background collector and no concurrent GC claim.

### Managed objects

- Heap strings returned by `concat` and `str` use an `SxRcStr` header containing a reference count and byte length.
- Emitted `SxList` values carry a reference count and own their element buffer.
- Ordinary compiler/parser scratch allocations remain ordinary C allocations and are not language-level managed objects.

### API

String runtime functions:

- `sx_rc_retain(p)` increments a managed string reference.
- `sx_rc_release(p)` decrements it and frees the object at zero.
- `sx_concat(a, b)` creates a managed string with one owning reference.
- `sx_str(n)` creates a managed string with one owning reference.

Language-facing compatibility helpers include `release(value)` and `gc()` / `gc_info()`. `release` performs deterministic RC release. `gc()` does not scan memory and currently returns without performing a collection; it exists for source compatibility with older examples.

List runtime functions emitted by the Sayanox code generator include `sx_list_retain` and `sx_list_release`. A list owns its element buffer until its reference count reaches zero.

## Lifetime rules

1. A newly created managed string/list starts with one reference.
2. Copying a managed pointer requires retaining the new owner.
3. Every owner must eventually release its reference.
4. Release at zero frees the object immediately.
5. Managed objects are not moved and there is no tracing pass.
6. The runtime is single-threaded; no pthreads, locks, or background collector are required.

The current subset compiler keeps ownership deliberately explicit. Code paths that do not yet emit automatic retain/release on every variable copy must use the runtime ownership API rather than pretending a tracing collector exists.

## Why this model

Reference counting is the smallest predictable step away from malloc-only lifetime management. It provides deterministic reclamation without introducing a root scanner, moving heap, safepoints, or a second GC implementation.

## Stress test

The regression source `examples/gc_rc_loop.sa` repeatedly creates temporary concatenations and releases the previous owner. The test checks that a large number of allocations completes and that the final string remains valid.

Run the runtime regression with:

```sh
make gc-test
```

CI also runs the existing `mini_*` subset tests. No GC feature changes the pure `.sa -> gen1` bootstrap path.

## What is not implemented

- No concurrent GC.
- No stop-the-world mark/sweep collector.
- No moving collector.
- No automatic cycle detection for reference-counted object graphs.
- No claim that every C `malloc` in compiler tooling is managed.