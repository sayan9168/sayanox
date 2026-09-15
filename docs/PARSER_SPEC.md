# Sayanox Parser Specification

## Purpose

The Sayanox parser converts the lexer token stream into the language AST defined by `src/ast.rs`. The parser is deterministic, reports source locations, and never silently skips malformed syntax.

## Program

```text
program        := statement* EOF
statement      := export_decl | show | hold | make | struct | give | when | while | use | assignment | expression
export_decl    := 'export' (hold | make | struct)
```

## Statements

```text
show           := 'show' expression
hold           := 'hold' IDENT '=' expression
assignment     := IDENT '=' expression
make           := 'make' IDENT '(' parameters? ')' block
struct         := 'struct' IDENT '{' fields? '}'
give           := 'give' expression
when           := 'when' expression block ('otherwise' block)?
while          := 'while' expression block
use            := 'use' STRING
block          := '{' statement* '}'
parameters     := IDENT (',' IDENT)*
fields         := IDENT (',' IDENT)*
```

## Expressions

Expressions use precedence climbing through these levels, from lowest to highest:

1. equality: `==`, `!=`
2. comparison: `>`, `<`, `>=`, `<=`
3. additive: `+`, `-`
4. multiplicative: `*`, `/`, `%`
5. unary: `-`
6. postfix: calls, indexing, field access
7. primary: number, string, identifier, grouped expression, array, struct literal

```text
expression     := equality
equality       := comparison (('==' | '!=') comparison)*
comparison     := term (('>' | '<' | '>=' | '<=') term)*
term           := factor (('+' | '-') factor)*
factor         := unary (('*' | '/' | '%') unary)*
unary          := '-' unary | postfix
postfix        := primary (call | index | field)*
call           := '(' arguments? ')'
index          := '[' expression ']'
field          := '.' IDENT
arguments      := expression (',' expression)*
primary        := NUMBER | STRING | IDENT | '(' expression ')' | array | struct_literal
array          := '[' (expression (',' expression)*)? ']'
struct_literal := IDENT '{' (IDENT ':' expression (',' IDENT ':' expression)*)? '}'
```

## AST contract

The Rust implementation in `src/parser.rs` is the semantic reference for the current language. The self-hosted parser must produce equivalent statement/expression structure before the parser milestone is considered locked.

Required coverage:

- literals and identifiers
- arithmetic and comparison precedence
- unary minus
- function calls and nested calls
- arrays and nested indexing
- field access
- struct literals
- variable declarations and assignments
- functions and returns
- conditional and loop blocks
- structs and imports
- exports
- malformed delimiter and operand diagnostics

## Lock gate

Parser work is considered complete only when:

- Rust host build and tests pass.
- Stage-2 self-host bootstrap passes.
- Stage-3 bootstrap passes.
- Stage-4 toolchain passes.
- The parser fixture passes through the self-hosted parser.
- The parser fixture covers every grammar category listed above.

A green compile alone is not sufficient for the parser lock.
