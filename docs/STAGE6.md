# Stage-6: Scoped Type Environment

Stage-6 moves another piece of compiler semantics into Sayanox itself: the type environment.

## What changed

`selfhost/typeenv.sa` implements a bootstrap-safe semantic environment with:

- explicit primitive type names: `number`, `string`, `bool`, `list`, `unknown`
- symbol declarations
- lexical scope depth
- nested-scope shadowing
- reverse lookup of the nearest visible binding
- duplicate declaration detection inside the current scope
- type expectation checks
- semantic error accounting

The implementation is written in Sayanox. The Stage-2 compiler is only the temporary seed used to turn it into an executable bootstrap tool.

## Smoke test

Run from the repository root:

```bash
bash selfhost/stage6_typeenv.sh
```

The test restores Stage-2, compiles `selfhost/typeenv.sa`, executes it, and verifies the success marker.

## CI

`.github/workflows/selfhost-stage6.yml` runs the same smoke test on Ubuntu with Clang. It is intentionally separate from the existing CI so Stage-6 can evolve without destabilizing the older bootstrap stages.

## Why this is a bigger step

Stage-5 introduced primitive inference and assignment checking. Stage-6 gives that semantic layer an actual environment model. This is the foundation needed for a real type checker that can reason about functions, parameters, return values, blocks, imports, and user-defined types.

## Next boundary

The next major self-hosting boundary is to connect the environment to the Sayanox parser/AST and make semantic checking consume parsed declarations and expressions instead of scanning source text heuristically. After that, function signatures, return types, user-defined structs, and richer diagnostics can move into the Sayanox implementation.
