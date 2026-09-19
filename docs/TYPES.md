# Static types (Stage-2)

Kinds: **number** · **string** · **list** · **struct**

## Rules
- `hold` locks a name's type; wrong reassignment is an error
- `+` on two strings → concat; mixed number/string → type error
- `* / %` require numbers
- comparisons require matching kinds
- bare names must be declared with `hold` first
- `show` uses `%s` for string-typed names

## Errors
```
stage2: file.sa:4: type error: string +: expected string, got number
stage2: file.sa:2: type error: name: undefined variable 'nope' ...
stage2: file.sa:3: error: cannot reassign 'a' to a different type
```
