# Sayanox syntax reference

This reference describes the maintained pure-min compiler dialect. Older
Stage-2 and compiler-stage examples may contain additional experimental forms.
See [`STATUS.md`](STATUS.md) for backend-specific coverage and limitations.

## Source files and comments

Source files use `.sa`. A line comment starts with `//`.

## Bindings and output

```sayanox
hold value = 42
hold name = "Sayan"
show value
show "text"
show value + 1
```

A name must be introduced with `hold` before it can be reassigned. `show`
prints one expression per statement.

## Numbers and operators

Numeric values are IEEE doubles. Integer and fractional literals are
supported; a trailing decimal point (`2.`) and a second decimal point
(`1.2.3`) are errors.

```sayanox
show 10 / 4             // 2.5
show (2 + 3) * 4        // 20
show 100000 * 100000    // 1e+10
show 10 % 3             // 1
```

Arithmetic operators are `+`, `-`, `*`, `/` and `%`. Multiplication,
division and remainder bind more tightly than addition and subtraction;
operators at the same precedence are left-associative. `%` truncates both
operands to integers and reports `division by zero` for a zero divisor.
Comparisons are `==`, `!=`, `<`, `<=`, `>` and `>=`.

## Functions

```sayanox
make square(x) {
  give x * x
}

show square(8)
```

Function declarations are top-level. In the tested shared subset, parameters
and return values are numeric; recursion is supported.

## Conditions and loops

```sayanox
when condition {
  show "yes"
} otherwise {
  show "no"
}

while condition {
  show "loop"
}
```

`else` is an alias for `otherwise`. Range/for-in loops and `elif` are not part
of the maintained pure-min subset.

## Strings and builtins

String literals use double quotes. Shared builtins include `concat`, `len`,
`chr`, `string_eq`, `sx_index`, `read_file`, `write_file`, `arg` and
`arg_count`. String indexing uses `s[i]` (zero-based); `sx_index(s, i)` is
also available. Exact backend coverage is in [`STATUS.md`](STATUS.md).

## Lists

Lists contain numbers:

```sayanox
hold items = [1, 2, 3]
show items[0]
show len(items)
push(items, 4)
```

## Structs

Struct fields are declared by name. The tested compilers support numeric and
string fields, nested struct values and field access:

```sayanox
struct Point {
  name
  x
}
hold p = Point { name: "origin", x: 0 }
show p.name
show p.x
```

## Generics

A function whose parameters and return type are all the same type parameter is
compiled once per concrete type its call sites use (`gen2` and `gen1_min`):

```sayanox
make twice<T>(a: T) -> T {
  hold x: T = a
  give pickb(x, x)
}
make pickb<T>(a: T, b: T) -> T {
  give a
}

hold s = "hi"
show twice(4)        // 4      - a num copy, twice__n
show twice(s)        // hi     - a str copy, twice__s
show len(twice("ab")) // 2
```

The kind of a call is the kind of its own first argument: a string literal or a
variable declared `str` selects the string copy, a list literal or a variable
declared `list` the list copy, anything else the numeric copy. The fixed kinds
of the builtins, the declared return kinds of ordinary functions and - for a
nested generic call - that call's own first argument are followed too, so
`give pickb(x, x)` and `show twice(twice("z"))` work. `T` may only appear as the
type of every parameter and of the return type; any other generic header is
reported as an error (`make pair<A, B>` is not supported).

Single-type-parameter generics are the documented limit on purpose. A
specialised copy is keyed by exactly one kind per call site (`NAME__n`,
`NAME__s`, `NAME__l`), so `pair<A, B>` would need a kind *tuple* per call
site, a per-parameter kind in the emitted C signature, and `__` suffixes
built from several kinds - including for nested generic calls inside a
specialised body. That rework is not in this milestone: `make pair<A, B>`
fails with the clear "one type parameter" diagnostic above instead of
mis-compiling. The same behaviour is pinned by `make test-generics`.

Generics are a full-language (`gen2`) feature: the seed and the pure-min dialect
do not read `make NAME<T>`. See `make test-generics`.

## Modules and files

```sayanox
use "library.sa"
hold data = read_file("data.txt")
hold status = write_file("data.txt", data)
```

`use` is a textual source splice, not a namespaced or versioned import.

## Unsupported forms

The maintained pure-min path does not claim support for every historical
example. Namespaced exports, a full standard library and portable native AOT
remain future work. Consult [`FEATURES.md`](FEATURES.md) and
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md).
