# Self-host Function Wiring

The Stage-3 compiler now has an explicit function-lowering boundary for:

- function declarations
- ordered parameters
- parameter slots
- local loads and stores
- calls with argument counts
- explicit returns

The canonical flow is:

```text
.sa source
  -> function/symbol analysis
  -> function IR
  -> local LOAD/STORE + CALL/RETURN
  -> backend lowering
```

For example:

```sa
make add(first_number, second_number) {
  hold sum_value = first_number + second_number
  give sum_value
}

hold result_value = add(10, 32)
show result_value
```

is represented by the compiler-owned IR boundary as a function declaration,
parameter records, local loads, an arithmetic operation, a return, a call and
a destination local store.

## Current boundary

The function IR is intentionally backend-neutral. Parameter and local slots are
identified explicitly, so later native backends do not need to rediscover
source variable names.

## Remaining integration

The next compiler step is to replace the current source-shaped function wiring
with direct consumption of the parser/AST records and then feed those records
through the existing semantic checker and generic IR builder. The C backend
remains the bootstrap backend until the native backend milestone is complete.
