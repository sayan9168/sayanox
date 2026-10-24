# Nested generic structs (2026-10-22)

| Claim | Where it is checked |
|---|---|
| A generic struct type argument may be another instantiation: `Box<Box<num>>`, `Box<Box<Box<num>>>`, `Pair<Box<num>, str>` | `make test-generic-structs-nested` |
| A generic struct type argument may be `list`: `Box<list>` holds the list pointer | `make test-generic-structs-nested`, `make test-generic-structs` |
| gen2 reads a struct-typed struct field filled from a **name**, not only from a nested literal | `make test-struct-field-struct` |
| A concrete struct name, an unknown name, an escaped type parameter and a wrong argument count stay refused on all three backends | `make test-generic-struct-limits`, `make test-type-refusals` |

This closes row 5 of the status matrix for the two forms it named. It also
reverses an explicit decision: `docs/TYPES_ROADMAP.md` and `docs/GENERICS.md`
had called the scalar-only boundary **permanent** on 2026-10-16. Both
sections are kept verbatim with a "reversed" blockquote on top rather than
deleted, because the requirements they listed are the checklist the
implementation has to answer.

## What actually blocked it

The 2026-10-13 note predicted that nesting would need "recursive
specialization identity, a bounded worklist, dependency-ordered layouts,
cycle rules and correct native tracing for each pointer field". Measuring
each one on 2026-10-22 found a single real blocker:

* **Identity** — already solved. The mangled name *is* the type identity, and
  a nested argument only makes the name longer.
* **Ordering** — no worklist and no sort. Build the inner instantiation
  *first* and the outer one necessarily gets a higher struct index, which is
  the order the typedefs are already emitted in. The gate pins
  `Box__n`'s typedef line number as lower than `Box__Box__n`'s in both
  emitted C files.
* **Cycles** — cannot be spelled. A type argument is written out in full at
  the literal site, so the depth is bounded by the source text; there is no
  name a template could use to refer to itself. gen2 caps the recursion at
  depth 8 anyway.
* **Native tracing** — already correct. A struct field is one machine word
  and `BK_STRUCT` means "scan every word", so a nested field is a collector
  root with no new descriptor.
* **The real blocker, on gen2 only** — a struct-typed struct field could not
  be filled from a *name*:

  ```
  struct Inner { v }
  struct Outer { b }
  hold i = Inner { 7 }
  hold o = Outer { i }       # min: field 'b' of struct 'Outer' is not a struct
  show o.b.v
  ```

  while the same program written with a nested *literal* already worked and
  already emitted `typedef struct { Inner b; } Outer;`. The layout existed;
  the struct-literal walker simply looked a name up in the string table
  (`sdecls`) and never in the struct-variable table (`svars`), so the field
  was recorded as a number. Adding that lookup is the whole fix, and
  `Box__Box__n` then has something to lower to.

## Mangling

One code per argument: `n`, `s`, `l` for `num`, `str`, `list`, and the inner
mangled name for a nested instantiation. Codes run together while every one
is a single letter, so nothing that existed before changed name; `_` separates
them as soon as one argument is nested.

| Written | Mangled | Emitted layout |
|---|---|---|
| `Box<num>` | `Box__n` | `typedef struct { double v; } Box__n;` |
| `Box<str>` | `Box__s` | `typedef struct { char *v; } Box__s;` |
| `Box<list>` | `Box__l` | `typedef struct { sx_list *v; } Box__l;` |
| `Box<Box<num>>` | `Box__Box__n` | `typedef struct { Box__n v; } Box__Box__n;` |
| `Box<Box<Box<num>>>` | `Box__Box__Box__n` | `typedef struct { Box__Box__n v; } Box__Box__Box__n;` |
| `Pair<num, str>` | `Pair__ns` | `typedef struct { double a; char *b; } Pair__ns;` |
| `Pair<Box<num>, str>` | `Pair__Box__n_s` | `typedef struct { Box__n a; char *b; } Pair__Box__n_s;` |

seed-min and gen2 emit those seven typedefs byte-for-byte identically, in that
order.

## The fixture

`selfhost/generic_struct_nested.sa`, eleven lines, byte-identical on seed-min,
gen2 and native:

```
7        two.v.v        Box<Box<num>> filled from a name
41       lit.v.v        Box<Box<num>> filled from a nested literal
7        three.v.v.v    Box<Box<Box<num>>>
3        len(lb.v)      Box<list> over a 3-element list
4        len(lb.v)      after push(xs, 7): the field holds the POINTER
7        lb.v[3]        and indexes through it
7        mix.a.v        Pair<Box<num>, str>, first argument
outer    mix.b          ... and its second
9        plain.a        Pair<num, str> is still Pair__ns
nine     plain.b
inner    txt.v          Box<str>
```

## Per backend

* **seed-min** (`selfhost/seed/sxc_seed_min.c`): `instantiate_gstruct` takes a
  second out-parameter and recurses. A type argument that is a name followed
  by `<` and known to the template table is instantiated first and contributes
  `SD[inner].name` as its code; the nested argument's struct index is recorded
  so the literal can refuse `Box<Box<num>> { Box<str> { "x" } }` by naming both
  mangled types. The `TY_LIST` refusal is deleted — the existing `FT_LIST`
  field kind already did the work.
* **gen2** (`selfhost/compiler_min.sa`): three new functions in the pre-pass.
  `gxargs` parses one type-argument list recursively and returns
  `ENDPOS / CODE / COUNT / DEFS`, with `DEFS` carrying every nested
  instantiation innermost-first; `gxmerge` folds those into the running list
  without emitting a typedef twice; `gxskip` lets a type-argument list span
  lines and carry `// ...` notes, which seed-min's `skip()` always allowed.
  Plus the `svars` lookup in the struct-literal walker described above.
  Everything downstream still sees only concrete struct names.
* **native** (`selfhost/native_aot.c`): `gs_instantiate` recurses the same way
  with `gss[sid][i]` holding the nested argument's struct identity, and `gsw`
  skips comments inside the list.

## What did not change

* `Pair<num, str>` is still `Pair__ns`, `Box<num>` still `Box__n`. The `_`
  separator only appears when an argument is nested, so no existing emitted
  name moved and `make test-generic-structs` still pins the old typedefs.
* No new GC descriptor on any backend. gen2/seed-min nest by value in the C
  struct; native nests one word under `BK_STRUCT`.
* Generic *functions* are untouched.

## Honest boundaries

* A **concrete** struct name is still not a type argument (`Box<Pt>`). A
  concrete struct has no parameter list to substitute, so there is nothing an
  instantiation would specialize.
* gen2 keeps its long-standing divergence: a *single* literal that contradicts
  its own type argument (`Box<num> { "seven" }`, and now equally
  `Box<Box<num>> { 7 }`) is accepted there and gives the field the literal's
  kind, where seed-min and native refuse. This is not new, it is inherited;
  `test-generic-struct-limits` asserts the two checking backends by name and
  says in its own `[OK]` line that gen2 diverges.
* gen2's diagnostic for a bad type-argument list is still its general
  `undefined name: Box`, not a sentence naming the template. The gate pins
  gen2's *failure* and the fact that the emitted C will not compile, not that
  wording.
* Depth is bounded by the source text, so there is still no cycle policy —
  because a cycle still cannot be written.

## Gates

```
make test-generic-structs-nested  # the new three-backend fixture + typedef order
make test-generic-structs         # scalar parity, now also Box<list> support
make test-generic-struct-limits   # 7 bad type arguments + 3 bad literals
make test-type-refusals           # Box<Pt> replaces the nested-generic row
make test-struct-field-struct     # gen2 now reads o.b.v instead of refusing it
make test-struct2 test-nest       # concrete nested structs, unchanged
make test-list-struct-fields test-gen2-list-struct-fields
make test-language-deps           # no bash/awk/sed/python in the new recipes
```

and the four hard gates:

```
make doctor         # DOCTOR-OK
make true-selfhost  # TRUE-SELFHOST-MIN-OK
make gen3           # GEN3-OK (gen3.c == gen4.c)
make native-test    # NATIVE-TEST-OK
```

See `hard-gates.log` in this folder for the markers and the line numbers at
which this increment's gates ran inside the aggregates.
