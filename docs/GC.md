# Memory management (design)

Sayanox currently uses **C stack + heap helpers** from Stage-2 runtime (`SxList`, strings).

## Options (future)

1. **Region / arena** — reset per program run (simplest)
2. **Reference counting** — for lists/strings
3. **Mark-sweep GC** — needs runtime type tags

## MVP stance

- No automatic GC in v0.4
- Prefer explicit `hold` lifetimes and Stage-2 list ownership
- Path to GC: tag every heap object, roots from stack frames in VM/`--run`

This file marks GC as **specified, not fully implemented**.
