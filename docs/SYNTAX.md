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

## Modules and files

```sayanox
use "library.sa"
hold data = read_file("data.txt")
hold status = write_file("data.txt", data)
```

`use` is a textual source splice, not a namespaced or versioned import.

## Unsupported forms

The maintained pure-min path does not claim support for every historical
example. Namespaced exports, a full standard library, generics and portable
native AOT remain future work. Consult [`FEATURES.md`](FEATURES.md) and
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md).
