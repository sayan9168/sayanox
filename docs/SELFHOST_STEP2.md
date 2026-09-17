# Self-host Step 2 — Variables, Scopes, Calls, and Returns

Step 2 establishes the compiler-facing model for ordinary local variables and functions.

## Variable model

A binding has two language-owned operations:

- `STORE(slot, value)` — produce/update a local binding.
- `LOAD(slot)` — read a previously bound value.

The backend must not decide variable semantics. It only maps the already-lowered operation to its target representation.

## Scope model

Each function introduces a lexical child scope. Slots are local to that scope. A later implementation can add nested blocks and captured variables without changing the basic STORE/LOAD abstraction.

## Function model

A Sayanox function has:

1. name
2. ordered parameters
3. lexical local scope
4. body
5. explicit `give` return value

Calls are represented independently from the backend. This allows the same frontend/IR to feed the existing bootstrap backend and a future native backend.

## Current status

The language-level contracts and regression sources are now checked into `selfhost/`.

This is **not yet the claim that the complete compiler backend supports arbitrary multi-character variable names, nested scopes, recursion, or every function expression**. Those are the next implementation pieces required before Step 2 can be called fully production-complete.

The current bootstrap still uses the Stage-2 C seed to compile Sayanox compiler sources. The long-term C-free target remains a native Sayanox backend.
