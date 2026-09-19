# Static types (Stage-2)

Kinds: **number** · **string** · **list** · **struct**

## Rules
- `hold` locks type; wrong reassignment → error
- `+` two strings → concat; mixed → type error
- `* / %` need numbers
- comparisons need matching kinds
- undeclared names → error
- `show` uses `%s` for string-typed names

## Examples
```sa
hold a = 1
hold s = "hi"
hold z = a + s   // type error
show nope        // undefined
```
