# Sayanox lightweight type system

Stage-2 and the self-host subset use four expression kinds:

- `num` — numeric values and arithmetic
- `str` — string values
- `list` — list/array values
- `struct` — named struct values

The C backend may use the descriptive names `number` and `string` internally; these are the same language kinds as `num` and `str`.

## Checking rules

Type checking happens while lowering declarations, assignments, expressions, and calls.

- `hold` establishes the declared kind of a binding.
- Reassigning a binding with a different kind is an error.
- `+` accepts two `num` values or two `str` values. Mixed `num + str` is rejected.
- `-`, `*`, `/`, and `%` require `num` operands.
- Comparisons require compatible operand kinds.
- `show` selects the correct output representation for `num` and `str`.
- Calls validate known argument kinds when function information is available.
- Lists and structs retain their kind tags instead of being treated as arbitrary values.

## Example

```sa
hold count = 10
hold name = "Sayan"
hold values = [1, 2, 3]

show count
show name
show values[0]
```

Invalid code should identify the operation and the conflicting kinds:

```sa
hold count = 10
hold name = "Sayan"
hold broken = count + name
```

Expected diagnostic shape:

```text
stage2: example.sa:3: type error: +: expected matching operands, got num and str
```

## Design boundary

This is intentionally a lightweight static checker. It does not introduce a separate type-language stack or replace the existing Stage-2 parser. The existing declaration-kind tables and expression-kind checks are extended instead.
