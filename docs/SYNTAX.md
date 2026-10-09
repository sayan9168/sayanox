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

A function whose parameters and return type all name one of its type
parameters is compiled once per concrete kind combination its call sites use
(`gen2` and `gen1_min`):

```sayanox
make twice<T>(a: T) -> T {
  hold x: T = a
  give pickb(x, x)
}
make pickb<T>(a: T, b: T) -> T {
  give a
}
make pair<A, B>(a: A, b: B) -> A {
  give a
}

hold s = "hi"
show twice(4)         // 4      - a num copy, twice__n
show twice(s)         // hi     - a str copy, twice__s
show len(twice("ab")) // 2
show pair(1, "x")     // 1      - pair__ns: A = num, B = str
show pair(s, [1, 2])  // hi     - pair__sl: A = str, B = list
```

A generic declares one or more type parameters in angle brackets — `NAME<T>`
or `NAME<A, B>` (comma-separated). Each type parameter's kind is the kind of
the first argument whose parameter uses it: a string literal or a variable
declared `str` selects `s`, a list literal or a variable declared `list`
selects `l`, anything else `n`. The fixed kinds of the builtins, the declared
return kinds of ordinary functions and - for a nested generic call - that
call's own arguments are followed too, so `give pickb(x, x)` and
`show twice(twice("z"))` work.

The specialised copy is named `NAME__` plus one kind character per type
parameter: `twice__s`, `pair__ns`, `three__nsl`. Each parameter gets its own
C type, so `pair__ns` is `double pair__ns(double a, char * b)`.

Every parameter's type and the return type must name one of the type
parameters; any other generic header is reported as an error (`must be
written with type parameters used by every parameter and the return type`)
instead of being compiled wrongly.

Generics are a full-language (`gen2`) feature: the seed and the pure-min
dialect do not read `make NAME<...>` at all, and native rejects it with
`generics are not in the native subset`. See `make test-generics` and
[`GENERICS.md`](GENERICS.md).

## Full-language extras (`gen2` only)

The reference above is the **pure-min dialect**, which seed-min, gen2 and
native all accept. gen2 additionally accepts the following forms. seed-min
reports `unknown statement` for them and native names the one it does not
have (`'for' is a full-language statement ...`, `'and' is a full-language
word operator or boolean literal ...`), so nothing is ever mis-compiled.

### Loops over values

```sayanox
hold xs = [1, 2, 3]
for v in xs {          // one iteration per element, v is a number
  show v
}
for v in [4, 5] {      // a list literal, a call, ...: any expression
  show v               // `hold` accepts, bound to a hidden variable first
}
hold s = "abc"
for c in s {           // one iteration per byte, c is a one-character string
  show c
}
for c in "xy" {
  show c
}
for i in 0..10 {       // the counting form: 10 iterations
  show i
}
```

`break` and `continue` work in every loop, and loops nest. The form is
`for NAME in EXPR {`; `NAME` must not already be a number, a string or a
list, except that a string loop may rebind a name that is already a string.

### Word operators and boolean literals

```sayanox
when a == 1 and b == 0 {   // &&  - short-circuits
when a == 2 or b == 9 {    // ||  - short-circuits
when not a == 2 {          // !(a == 2): `not` binds looser than a comparison
when not (a == 2) and b == 0 {
hold flag = true           // 1
hold off = false           // 0
```

`and` binds tighter than `or`, as in C. `not` takes the rest of the
comparison up to the next `and` / `or`, so `not a == 2 and b == 0` is
`!(a == 2) && b == 0` — **not** C's `(!a) == 2 && b == 0`. Because `and` and
`or` lower to `&&` and `||`, the right-hand side is not evaluated when the
left-hand side already decides the result.

### Condition chains

```sayanox
when n == 1 {
  show "one"
} elif n == 2 {          // `else if`, `else when`, `otherwise when` too
  show "two"
} otherwise {
  show "many"
}
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
example. Namespaced exports, a full standard library and portable native AOT
remain future work. Consult [`FEATURES.md`](FEATURES.md) and
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md).
