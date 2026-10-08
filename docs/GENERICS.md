# Generics: one type parameter, on purpose

Status (2026-10-08): **single-type-parameter generics are the supported and
documented form.** Multi-parameter generics (`make pair<A, B>(...)`) are **not**
implemented. They are reported as an error, and this is not a planned
milestone.

## The supported form

```sayanox
make twice<T>(a: T) -> T {
  give a
}
show twice(7)
show twice("ok")
```

* One type parameter, named in angle brackets after the function name:
  `make NAME<T>(params) -> T`.
* `T` may be used for any parameter and for the return type. It stands for one
  of the three value kinds: `num`, `str`, or a double list.
* gen2 monomorphises the function: one C copy per call-site kind, named
  `NAME__n`, `NAME__s` or `NAME__l`. Each copy has a prototype before any use.
* An unused generic emits nothing.
* It is a gen2 (full-language) feature. seed-min and the pure-min dialect do not
  read `make NAME<T>`, and native rejects it with
  `generics are not in the native subset`.

Verified by `make test-generics` (14 lines of a program mixing `pickb`, `twice`
and `quad` over num, str and list print identically under gen2 and gen1_min)
and by the `make test-for-str` rejection checks.

## Why not `pair<A, B>`

A second type parameter means each call site must select a *tuple* of kinds,
not one kind. The monomorphiser keys copies on a single kind (`NAME__n`,
`NAME__s`, `NAME__l`), so `pair<A, B>` needs a new key format for every call
site, including nested generic calls inside an already-specialised body. That
rework touches the call-site scanner, the prototype emitter and the naming
scheme together. Doing it halfway would risk mis-compiled C, so the form is
rejected instead:

* gen2 reports `make pair<A, B>` with a clear `must be written with one type parameter`
  error (checked by `make test-for-str`).
* native reports `generics are not in the native subset`.

Multi-parameter generics are a non-goal for the current milestone and are
listed under "Out of scope" in [`STATUS.md`](STATUS.md).

## What this does not claim

* No trait or bound system: `T` has no constraints beyond the three value kinds.
* No type inference beyond the call site's argument kinds.
* No generic structs and no generic lists of arbitrary element types. Lists
  remain double-only (see [`SYNTAX.md`](SYNTAX.md)).
