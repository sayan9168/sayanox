# Sayanox Parser Specification

## Status

This document defines the parser contract for the Sayanox language. The parser is considered locked only when the Rust parser and the self-hosted parser satisfy the conformance checks in CI.

## Program

A program is an ordered sequence of statements. Statements are separated by source boundaries; semicolons are accepted as punctuation but are not required.

## Statements

```text
statement :=
    [export] hold IDENT = expression
  | make IDENT ( parameters ) block
  | [export] struct IDENT { fields }
  | show expression
  | give expression
  | when expression block [otherwise block]
  | while expression block
  | use STRING
  | IDENT = expression
  | expression
```

`export` is valid only before `hold`, `make`, or `struct`.

## Blocks

```text
block := { statement* }
```

Braces must balance and nested blocks are allowed.

## Expressions

Expressions use the following precedence, from lowest to highest:

1. Equality: `==`, `!=`
2. Comparison: `>`, `<`, `>=`, `<=`
3. Addition: `+`, `-`
4. Multiplication: `*`, `/`, `%`
5. Unary negation: `-expression`
6. Postfix: calls, indexing, field access
7. Primary expressions

```text
expression      := equality

equality        := comparison ( (== | !=) comparison )*
comparison      := term ( (> | < | >= | <=) term )*
term            := factor ( (+ | -) factor )*
factor          := unary ( (* | / | %) unary )*
unary            := -unary | postfix
postfix          := primary ( call | index | field )*
call             := ( expression ( , expression )* )?
index            := [ expression ]
field            := . IDENT
```

## Primary expressions

```text
primary := NUMBER
         | STRING
         | IDENT
         | ( expression )
         | [ expression-list? ]
         | IDENT { field-init-list? }
```

A struct literal field initializer is `IDENT : expression`.

## Functions

```text
make add(a, b) {
    give a + b
}
```

Parameters are identifiers. A function body is a normal statement block. `give` supplies the function result.

## Structs

```text
struct User { name, age }
hold user = User { name: "Sayan", age: 18 }
```

Struct declarations contain comma-separated field identifiers. Struct literals contain comma-separated named field initializers.

## Imports

```text
use "math.sa"
```

The import path must be a string literal.

## Diagnostics

Parser errors must report the source line and column whenever a token is available. Diagnostics should describe the expected construct instead of only reporting a generic syntax failure.

## AST contract

The Rust AST is the canonical semantic shape for the current language version:

- `Show(Expr)`
- `Hold { name, value, exported }`
- `Assign { name, value }`
- `Make { name, params, body, exported }`
- `Give(Expr)`
- `When { condition, then_body, otherwise_body }`
- `While { condition, body }`
- `StructDef { name, fields, exported }`
- `Use { path }`
- `Expr(Expr)`

Expressions include numbers, strings, identifiers, binary operations, calls, arrays, indexes, struct literals, and fields.

## Lock criteria

The parser milestone is not locked merely because a parser executable runs. A lock requires:

1. `cargo test` passes.
2. Host parser accepts the valid conformance fixture.
3. Host parser rejects the invalid fixture with a line/column diagnostic.
4. Self-hosted parser builds through Stage-2.
5. Self-hosted parser reports `parse OK` for the valid fixture.
6. Stage-3 and Stage-4 remain green after the parser changes.
