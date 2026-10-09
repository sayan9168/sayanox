# Generics: type parameters, monomorphised

Status (2026-10-09): **generics with one or more type parameters are the
supported and documented form.** `make twice<T>(a: T) -> T` and
`make pair<A, B>(a: A, b: B) -> A` both compile; every type parameter is
resolved at each call site from the argument that uses it, and the whole
generic is monomorphised into ordinary C.

## The supported form

```sayanox
make twice<T>(a: T) -> T {
  give a
}
make pair<A, B>(a: A, b: B) -> A {
  give a
}
show twice(7)          // 7
show twice("ok")       // ok
show pair(1, "x")      // 1
show pair("x", 1)      // x
```

* One or more type parameters, named in a comma-separated list in angle
  brackets after the function name: `make NAME<T>(...)` or
  `make NAME<A, B>(...)`, up to `<A, B, C>` and beyond.
* Every parameter's type and the return type must name one of the type
  parameters. A parameter typed `num`, a return type that names nothing, or a
  return type naming an undeclared parameter is **reported as an error**
  (`must be written with type parameters used by every parameter and the
  return type`), never silently compiled.
* Each type parameter stands for one of the three value kinds: `num`, `str`,
  or a double list.
* Type-parameter names are single characters or identifiers; a generic may
  have up to 10 type parameters (the internal tables store indices as one
  character each).

## How a call site picks the kinds

The kind of a type parameter is the kind of the **first argument whose
declared parameter uses it**:

* a string literal, or a variable declared `str`, gives `s`;
* a list literal, or a variable declared `list`, gives `l`;
* anything else gives `n`;
* the fixed kinds of the builtins (`concat` → `s`, `len` → `n`, `push` → `l`,
  …), the declared return kinds of ordinary functions, and — for a nested
  generic call — that call's own arguments, are followed too, so
  `give pickb(x, x)` and `show twice(twice("z"))` work.

With one type parameter this is exactly the old "kind of the first argument"
rule, which is why single-parameter generics keep the names `NAME__n`,
`NAME__s`, `NAME__l`.

## The specialised name

A copy is named `NAME__` followed by one kind character per type parameter,
in declaration order:

| generic | call | copy |
|---|---|---|
| `twice<T>` | `twice("x")` | `twice__s` |
| `pair<A, B>` | `pair(1, "x")` | `pair__ns` |
| `pair<A, B>` | `pair(s, xs)` | `pair__sl` |
| `three<A, B, C>` | `three(1, "x", xs)` | `three__nsl` |

Each copy gets a prototype before any use, and is emitted **once** however
many call sites ask for it. An unused generic emits nothing.

The emitted C signature is per-parameter, not one type for the whole function:

```c
static double  pair__ns(double a, char * b);   /* A = num, B = str, -> A */
static char *  pair__sn(char * a, double b);   /* A = str, B = num, -> A */
static sx_list *  pair__ls(sx_list * a, char * b);
```

A generic that calls another generic inside its body specialises the callee
with the kinds it was given itself (`usefirst<A, B>` calling `pair<A, B>`
produces `pair__ls` inside `usefirst__ls`), and `hold v: T = callee(...)` in
such a body knows the callee's result kind, because the callee's kind is
recorded as soon as the nested call is queued.

## Backends

* gen2 and gen1_min implement this; both produce byte-identical C
  (`make test-generics` diffs the two outputs).
* It is a full-language feature: seed-min and the pure-min dialect do not read
  `make NAME<...>` at all and reject the program.
* native rejects every generic with `generics are not in the native subset`.

## Verified by

`make test-generics` covers, on gen2 with gen1_min agreement:

* the single-parameter program (`pickb`/`twice`/`quad`/`wrap`/`unused` over
  num, str and list, nested and cross-generic calls, one copy per kind, every
  call prototyped, an unused generic emitting nothing);
* a multi-parameter program: `pair<A, B>` (returning `A`), `swap<A, B>`
  (returning `B`), `three<A, B, C>` (returning `C`), `usefirst<A, B>` calling
  `pair<A, B>` and binding the result in a `hold`, over the kind combinations
  `nn`, `ns`, `sn`, `ls`, `ln`, `sl`, `nsl` — each copy asserted to appear
  exactly once, no `#error`, no implicit declaration;
* two rejection cases: a parameter that does not use a type parameter, and a
  return type naming an undeclared one.

## What this does not claim

* No trait or bound system: a type parameter has no constraints beyond the
  three value kinds.
* No type inference beyond the call site's argument kinds, and no inference
  for a type parameter that no argument pins down (it falls back to `num`).
* No generic structs and no generic lists of arbitrary element types. Lists
  remain double-only (see [`SYNTAX.md`](SYNTAX.md)).
* Kinds are per *value kind*, not per declared type: `A` and `B` can both be
  `num` without any distinction being made.
