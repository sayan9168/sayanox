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

`else` is an alias for `otherwise`. The maintained seed now also accepts
`elif` and the bounded for-in/range forms documented below; the compiler
bootstrap source itself remains written in the original pure-min dialect.

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

A field value may be a whole checked expression since 2026-10-22 -- arithmetic,
a parenthesised group, `len(...)`, a call to a function this program declared,
or a string `+` chain -- and the field takes that expression's kind
(`make test-full-language-expr`):

```sayanox
struct Size {
  bytes
}
make twice(v: num) -> num {
  give v * 2
}
hold text = "abc"
hold a = Size { bytes: len(text) + 1 }   // 4
hold b = Size { bytes: (2 + 3) * 4 }     // 20
hold c = Size { bytes: twice(3) + 1 }    // 7
```

Two field values are still refused on gen2 (seed-min accepts the first): a
dotted field read (`Size { bytes: p.x }`) and a source-level builtin call
(`Label { text: concat(a, b) }`). Bind either to a name first.

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

Seed-min, gen2 and native now specialize generic functions over num, str
and double lists, including multiple type parameters. The `NAME__k` naming
above is gen2's lowering; seed uses reserved `_sx_gen_` names and native
emits machine-code instances. The compiler source now uses a live generic
minimum helper and generic source-size struct during bootstrap, gated by
`make gen3`; this is not exhaustive full-language support. See `make test-generics`,
`make test-seed-generics` and [GENERICS.md](GENERICS.md) for limits and tests.

## Stage-2 forms and backend boundaries

Gen2 and native support the forms below. Seed-min now supports boolean
literals/logic, conditional aliases, break/continue and the documented
string/list/range iteration subset outside functions and inside fully typed
functions. Typed num/str/list signatures and generic function specialization
are supported; not every gen2 expression is accepted. Consult the boundary
sections below and [STATUS.md](STATUS.md) rather than assuming full parity.
Native function-local `hold` and `for` are supported; recursive calls have
separate frame slots for binders and hidden loop state. Word logic is short-circuiting and its numeric value is 0 or 1.

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
`for NAME in EXPR {`; an existing binder must have the compatible kind
(number for numeric ranges/list elements, string for string elements).
Seed-min rejects language keywords as binders. See the range section for
the live upper-bound evaluation contract.

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
Namespaces and import aliases are **not planned for the bootstrap dialect**;
use explicit public-name prefixes. A path rename is not a symbol alias, and
a dotted expression denotes a struct field, not a module member. See
[MODULES.md](MODULES.md) for the contract and diagnostic limitations.

## Unsupported forms

The maintained pure-min path does not claim support for every historical
example. A full standard library and portable native AOT are not claimed. Namespaced
exports/import aliases are outside the bootstrap plan, not promised future
work. Consult [`FEATURES.md`](FEATURES.md) and
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md).

### Typed signatures

A `make` is either fully typed or fully untyped: `make f(a: num, b: num) -> num`
or `make f(a, b)`. A partly typed parameter list, or typed parameters without a
`-> TYPE`, is an error on seed-min, gen2 and native (`make test-typed-sig`). All three
support `num`, `str` and `list` signatures. Seed-min requires a terminal
top-level unconditional `give`; see its typed-function subset below.

### List elements

A list literal holds numbers. Each element is a numeric expression: `[a, a + 1, 2 * n]`
works in a `make` too. A string, list or struct element is refused by name. A parenthesised element such as `[a, (a - 1)]` works on gen2 and native (`make test-list-paren`); `[a, a - 1]` is also fine (`make test-list-expr`).

### Seed-min iteration boundary

The C seed supports named string/list sources and string/list literals outside
functions and inside fully typed functions, for example:

```sayanox
for ch in "ab" {
  show ch
}
for n in [1, 2, 3] {
  when n == 2 { continue }
  show n
}
```

A literal is evaluated once on each entry into its loop. A named source is
re-read each iteration; rebinding that source can change subsequent iteration.
String elements are one-byte strings, list elements are numbers. `break` and
`continue` address the nearest enclosing loop. Numeric expressions inside a
list literal are supported; their evaluation order is not specified here.
The seed also supports the numeric range and checked call-source subsets
below. Inside `make`, `for` requires a fully typed signature. `_sx_iter_` is a reserved prefix for seed-generated temporaries.
See `make test-seed-for-literals` for the output and rejection tests.

### Numeric ranges on seed-min

```sayanox
hold n = 4
for i in 0..n {
  show i
}
```

This prints 0, 1, 2, 3. The range is end-exclusive and advances by 1, including
for fractional bounds (0.5..2.5 visits 0.5 and 1.5). Equal or descending bounds
produce zero iterations; there is no implicit reverse step. Negative bounds,
parentheses, arithmetic and `len(xs)` / `len(s)` bounds are supported outside
functions and inside fully typed functions. Bounds must evaluate to numbers. The start is evaluated on entry;
the upper expression is evaluated at each condition check. Modifying the
counter changes the next iteration. Break leaves the counter unchanged;
continue performs the normal +1 step.

Seed-min rejects other calls and direct field accesses in bounds for now;
assign a field's numeric value to a variable before using it as a bound.
`for` inside an untyped `make` is still unsupported. The special `..` delimiter does not
make malformed numeric literals valid elsewhere in the language.

**Range-bound alignment:** seed, gen2 and native now re-evaluate the upper
expression at each condition check, including after continue; break exits
without another check. `test-seed-for-range` compares the same expected output
on all three, including changing a numeric bound and replacing a list used
by len. A native-only test covers upper-bound user-call side effects: seed
and gen2 still refuse those calls, so that case does not claim parity.

### Call-result iteration on seed-min

```sayanox
make letters() -> str {
  give "ab"
}
make numbers() -> list {
  hold items = [3, 4]
  give items
}
for ch in letters() {
  show ch
}
for n in numbers() {
  show n
}
for ch in concat("x", chr(65)) {
  show ch
}
```

A plain call returning a string or list is evaluated once per loop entry,
then its returned reference is iterated. Supported builtins are checked for
argument count and kinds; numeric results cannot be used as collection
sources. `push(xs, n)` is a list-returning source and runs once, not once per
iteration. Named sources still have their documented re-read behavior.

User functions may declare `num`, `str` and `list` parameters, with an explicit
`-> num`, `-> str` or `-> list`. Every parameter must be annotated, or the
whole signature must use the legacy untyped numeric form. Calls check counts
and kinds, including nested argument expressions at ordinary main call sites.
A typed body must end in a top-level unconditional `give` of the right kind;
earlier returns inside conditions/loops are allowed. Supported statements:
`hold` (optionally annotated), assignment, show, push, when/elif/otherwise,
while, the supported for forms, break and continue. Conditions are numeric.

Typed functions isolate parameters and locals from globals. New locals in a
nested block expire at its end; repeated `hold` of an existing outer local
reassigns it rather than shadowing it. Local kinds cannot change. String
parameters are copied on entry so local reassignment cannot free a caller's
string or another aliased parameter; lists remain shared references. Seed
*string* allocations are collected since 2026-10-22 (a conservative mark &
sweep over the builder registry, [`GC.md`](GC.md)); seed *lists* are still
never freed. Global captures, struct-valued locals and
struct-valued specialization is not part of this typed subset; generic
function signatures are supported as described below. Numeric return values
are useful in expressions, not directly as collection sources.

The seed registers signatures and emits prototypes before bodies, including
for forward calls. Gen2 now also emits prototypes for ordinary typed
functions, so callees may follow callers. Gen2 now also accepts a complete
list literal directly in a -> list return, using its existing hold/list
expression checks (see the list-expression boundary below). The seed still refuses `for` inside an untyped
function and arbitrary expression compositions as collection sources (e.g.
`letters() + "z"`). See `test-seed-for-calls` for exact output and error tests.

See `test-seed-typed-functions` for typed calls, aliasing, recursion, scoped
locals, annotations and function-local iteration. Its extended fixtures have separate native tests; `test-native-param-reassign` additionally checks the
typed-parameter fixture on native. Native function-local `for` is separately checked by `test-native-for-functions`. The former seed-only scope/forward/boolean-argument cases now also run
on gen2; dedicated regressions cover each change.

Native parameter reassignment preserves the declared num/str/list kind and
updates the current call frame, not a same-named global. String concat creates
new storage; GC scans parameter frame slots. List rebinding does not rebind
the caller's variable. Native list growth forwards older objects to their successors, preserving
shared mutation across capacity changes. Length, indexing, show and push
resolve these links; GC traces them. Old aliases may retain earlier buffers
until collected, so this is not a constant-space or compacting-GC claim.


### Seed generic functions

`make id<T>(value: T) -> T { give value }` specializes from num/str/list
arguments; multi-parameter signatures bind each type variable independently.
The body is checked as a fully typed function for each requested signature;
local `hold x: T` annotations are substituted without rewriting strings,
comments or ordinary identifiers. Nested/recursive calls reuse a finite
specialization registry. Generic structs and explicit call-site type arguments
remain unsupported. See GENERICS.md for limits and backend-specific tests.


Native accepts optional `hold x: num`, `hold s: str` and `hold xs: list`
annotations both at top level and inside functions. A generic local may use
its bound type variable (`hold x: T`). Initializers, reannotations and later
assignments cannot change the binding kind; unknown type names are errors.
`test-native-generic-local` checks these forms, including typed function-local
loops and string-only generic bodies. Native templates are instantiated only
for requested kinds; an unused numeric body is no longer forced.


### Gen2 function declarations, blocks and boolean arguments

Gen2 emits typed prototypes before function bodies, including ordinary
num/str/list functions, mutual recursion and zero-argument functions (`void`
in C). Existing generic prototypes are reused rather than duplicated.

Each function starts with its own parameter/local name tables. Nested source
blocks remember their incoming name-table lengths and discard newly introduced
bindings at the end; repeated hold of an existing outer binding still assigns
it. Sibling branches may reuse a name with different kinds. For binders remain
in the containing scope where their C declaration lives. Synthetic elif
wrapper blocks do not create extra source bindings. Legacy top-level flat
tracking is unchanged; this is not complete undefined-name/global-capture or
whole-function return analysis. Native sibling-kind behavior is not asserted
by the seed/gen2 scope fixture.

Boolean literal tokens preserved by call-argument paths are now normalized
to double constants in generated expression positions. String contents,
longer names and struct fields named true/false remain unchanged. Shared
call-argument tests compare seed/gen2/native; a separate comparison-argument
case is gen2-only because native still rejects that expression form.

Tests: test-gen2-forward, test-gen2-function-scope,
test-gen2-boolean-args, test-gen2-generic-queue. The last target fixes doubled
request separators and template-record lookup in gen2's specialization queue;
the previous extended nested-generic crash now has a passing regression.


### Gen2 list-expression boundary

A list-returning function may return a complete literal directly:

```sayanox
make values(n: num) -> list {
  give [n, n + 1, n * 2]
}
make empty() -> list {
  give []
}
```

Gen2 reuses its hold/list parser through a fresh temporary at the return
statement itself, preserving branch/loop timing and single evaluation.
The temporary name is checked against the whole source. Element syntax and
checking retain the existing hold/list parser's limits; this is not a general
expression-parser replacement. String/nested-list elements and a direct list
literal in a numeric-returning function are errors.

Inline numeric list arguments now have a typed expression-lowering path.
Supported elements include numeric variables, arithmetic (`+ - * / %`),
comparisons, parentheses, numeric-returning calls (including supported generic
instances), string/list indexing and nested list consumers:

```sayanox
use_list([n, n + 1, next(n), n % 3, n > 0])
use_list([len(text), xs[i], len([n, next(n)])])
```

Calls **inside these elements** check parameter count/kinds and return kinds
against collected signatures. String concatenation/comparison and string/list
values can be used in appropriately typed nested calls, but each final list
element must be numeric. For example `len(text + "!")` is numeric; `text + "!"`
as a list element is not. A list of lists remains invalid.

This lowering runs while the statement's lexical kind tables are available.
It applies to the supported hold/show/give/condition call paths; it is not a
whole-program expression/type-parser replacement. Private generated names
are checked against source text. Forward/generic signatures remain available
at the call site. Numeric results, including comparisons, occupy double
slots before entering the variadic list ABI. Integer division does not sneak
in through C tokens; modulo uses the checked helper.

Newly lowered inline literals evaluate their elements once, left-to-right,
using automatic numeric temporaries and comma expressions. Only declarations
are placed before the enclosing statement: evaluation and allocation stay
inside the expression, including each loop-condition check. No GNU statement
expressions or loop-invariant allocation hoisting are used. This sequencing
is tested against native at -O0/-O2. Seed now also preserves left-to-right,
single evaluation for all numeric list constructors, including nested and
recursive constructors, through a collision-free linked builder stack and
comma sequencing. Gen2's older named-hold/direct-literal-return lowering is
not changed to the new sequencing scheme.

Inline numeric-list elements can traverse named struct fields, including
nested numeric/string fields, while their concrete field metadata is known:

```sayanox
show use_list([p.x, len(w.point.label), w.point.label[0]])
show plus(([1, 2])[0])
show plus(identity([3, 4])[1])
show identity([30, 40][1])
```

The complete checked call is parsed when it contains list/index syntax, so
postfix numeric results are checked against the outer parameter kind too.
Passing `[1][0]` to a list parameter remains an error; passing it to a numeric
parameter is valid. Generic argument inference refines the first-token guess
using the resolved whole expression kind, and argument scanning respects
commas inside lists/groups. Seed checked field access requires a known named
struct or field chain and rejects unknown fields or nonstruct selectors.

An index may also call a function declared `-> num` (`values[offset()]`,
`values[twice(offset()) + 1]`), with numeric arguments that are themselves
index expressions; the arity and every declared parameter kind are checked.
A quoted string, a call returning a string or taking a list, an unknown
function and a wrong argument count stay refused inside `[ ]` on gen2
(`make test-full-language-expr`, `make test-gen2-index-expr`).

Still unsupported: struct values as numeric-list elements, arithmetic on list
values, and arbitrary literal-headed postfix/compound expressions outside
these checked call paths. This is not a universal expression-parser replacement;
for example, direct `hold n = [1][0]` is not covered by this increment. Struct
fields containing other structs still use the documented nested-literal
initialization rules. Generic structs and universal outer-call type checking
remain unimplemented. Malformed syntax, mixed numeric/string arithmetic,
nested-list elements and wrong checked-call signatures produce diagnostics.

Targets: `test-gen2-list-return`, `test-gen2-list-args`,
`test-gen2-list-arithmetic`, `test-inline-expressions`, `test-inline-runtime`,
`test-seed-list-sequence`, `test-list-postfix`.

### Generated C garbage-collector anchor

Generated programs now run in an inner function called by a small main
wrapper. The stack anchor stays alive in the caller frame; a volatile
indirect entry and a post-call volatile store keep that frame present in the
tested builds. This fixes live-root loss observed when compiling/running at
-O0. Wrapper names avoid source identifiers. `test-gen2-gc-roots` compares
-O0/-O2 compiler output and generated programs across 2,000 explicit
collections. The collector is still conservative and stack-direction/toolchain
dependent; these tests do not establish portability to all targets or LTO.


### Typed function return paths

Functions with an explicit return signature must not fall through without a
value. All three frontends accept exhaustive branches, including nested
when/elif/else chains, without requiring a redundant final give:

```sayanox
make sign(n: num) -> num {
  when n < 0 {
    give -1
  } elif n == 0 {
    give 0
  } otherwise {
    give 1
  }
}
```

A missing else needs a later returning suffix. Returns inside loops alone
are insufficient, because this check conservatively permits zero iterations,
even for a literal true condition. It does not prove termination or evaluate
conditions. Nesting beyond 128 is not proven. Existing untyped-function
behavior is unchanged. Quoted text/comments do not count as give statements.
Tests: `make test-return-paths` (seed/gen2/native).

The accompanying gen2 fixes keep nested else bodies separate from synthetic
elif wrappers and preserve quotes/escapes in give expressions, including
literal `}` and `//` text.


### Name resolution before expression lowering

Gen2 now checks value references against the active binding tables before
lowering hold/show, assignments (including indexed writes), push, when/while,
for sources/bounds and give. Nested call arguments and list/index expressions
are scanned too. An unbound value emits `undefined name: NAME`; an unregistered
callee emits `unknown function: NAME` in the compiler's generated #error
channel, instead of leaving the host C compiler to discover it.

Function names and value bindings are separate lookups. Signature collection
preserves forward calls and generated generic instances. Struct field labels
and selectors are not mistaken for value bindings; string literals, escapes
and comments are skipped. Builtin-like value names such as `index` and `len`
remain usable. String iteration binders are included in the lookup.

Function-local scope expiry is respected, including sibling blocks and
parameters that must not leak into main. The existing legacy **top-level flat
binding policy** is unchanged. This is name resolution, not a new type checker
or definite-assignment analysis: it does not prove that every binding is
initialized on every control-flow path or change unsupported expression syntax.
Targets: `test-name-resolution` (positive seed/gen2/native parity and gen2
negative-reference regressions).


### Concrete named struct function signatures (gen2/gen3 only)

```sayanox
struct Point { x }
hold witness = Point { x: 0 }
make copy_point(p: Point) -> Point {
  give p
}
make coordinate(p: Point) -> num {
  give p.x
}
hold p = Point { x: 7 }
hold q: Point = copy_point(p)
show coordinate(q)
```

These are real by-value signatures; argument and return identities must match,
including through nested calls. Struct names may contain digits/underscores.
String/list fields and nested literal layouts retain their existing types.
The field-reading function needs a preceding layout witness literal because
field inference remains source-ordered; a pure copy does not. Bind struct
results directly before using their fields. Grouped struct-valued holds and
unknown function types have explicit source refusals. Generic struct signature
annotations and general struct reassignment/field-expression constructors are
not added. Seed-min/native struct function signatures remain unsupported.
`test-struct-functions` tests gen2/gen3 output, nominal mismatch diagnostics and
GC retention at O0/O2; this is not full-language self-host support.


### Identifier string interpolation (gen2/gen3 only)

```sayanox
hold name = "Sayanox"
hold n = 3
show "hello ${name}, count=${n}"
show "literal \${name}"
```

Output is `hello Sayanox, count=3`, then the literal `literal ${name}`.
A hole is one identifier, not a general expression, field selector or call.
It must resolve to a string or number; numeric formatting is the existing
`numstr` (`%g`) behavior. Bind an expression/field to a name first. Unknown
names, list/struct values, malformed holes and more than 16 holes per literal
have source diagnostics. Adjacent holes and escaped quotes/backslashes work;
`\\${name}` means a literal backslash followed by the substituted value.
The compiler skips interpolation in `//` comments and processes imported code
after textual splicing. This does not add interpolation to `use` paths or
otherwise broaden the expression grammar of struct field initializers.

Generated C requires C11 (`_Generic` scalar dispatch); each hole identifier is
evaluated once. `make test-string-interpolation` pins gen2/gen3 values, scope,
escaping, imports, GC retention and refusals at O0/O2. Seed/native interpolation
and arbitrary expression/format-specifier holes remain unsupported.
