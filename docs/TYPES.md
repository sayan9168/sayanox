# Type system (lightweight)

Stage-2 tracks declaration kinds at compile time:

| Kind | Code | Examples |
|------|------|----------|
| number | 0 | `hold x = 42` |
| string | 1 | `hold s = "hi"` |
| list | 2 | `hold xs = [1, 2]` |
| struct | 3 | `hold p = Point { ... }` |

## Rules

- Reassigning a name to a **different kind** is a hard error.
- `show` picks `%g` vs `%s` from expression / declared kind.
- No full inference or generics yet — kinds are local and explicit via usage.

## Future

- Function signatures
- Struct field types beyond `double`
- Cross-module type export
