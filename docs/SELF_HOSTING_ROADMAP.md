# Sayanox Self-Hosting Roadmap

## Goal

Make Sayanox progressively independent of Rust and other implementation languages.

This does **not** mean deleting Rust immediately. The Rust compiler is currently a trusted bootstrap implementation. Removing it before the Sayanox implementation can replace its responsibilities would make the project less reliable, not more independent.

## Architecture policy

### 1. Sayanox is the source of truth

New language semantics, compiler behavior, standard-library APIs, tooling behavior and user-facing features should be designed in Sayanox first whenever the current language capabilities allow it.

### 2. Rust is bootstrap infrastructure

Rust should be treated as a bootstrap/compiler implementation rather than the permanent language definition. Existing Rust code should remain stable while equivalent Sayanox implementations are developed and validated.

### 3. Replace by capability, not by file count

A Rust module should only be retired after its Sayanox replacement has:

- equivalent or better behavior;
- deterministic tests;
- useful diagnostics;
- bootstrap coverage;
- a documented migration path;
- no regression in the existing `.sa` examples.

## Migration order

### Phase A — Compiler frontend

Move these responsibilities into Sayanox source:

- source loading;
- tokenization;
- parsing;
- AST construction;
- source spans;
- diagnostics and error rendering;
- module/import resolution;
- semantic/type checking.

### Phase B — Compiler middle/end

Then move:

- intermediate representation;
- constant evaluation;
- lowering;
- code generation orchestration;
- bytecode/VM compilation;
- optimization passes.

Native code generation can remain a backend boundary until Sayanox has a stable native backend of its own.

### Phase C — Developer tooling

Rewrite or replace the shell-based tools with Sayanox implementations where practical:

- formatter (`sxfmt`);
- package manager (`sxpkg`);
- REPL;
- test runner;
- project/build driver;
- documentation tooling;
- debugger support.

### Phase D — Runtime ownership

Increase Sayanox ownership of:

- standard library;
- collections;
- strings;
- file/process abstractions where supported;
- concurrency abstractions;
- error/result handling;
- runtime services.

### Phase E — Self-hosted bootstrap

Target a small trusted bootstrap seed rather than a permanent Rust dependency:

```text
Trusted bootstrap
      |
      v
Sayanox compiler source
      |
      v
Sayanox compiler binary
      |
      v
Rebuild Sayanox compiler
      |
      v
Rebuild again and compare
```

The final validation is a reproducible bootstrap cycle: the Sayanox compiler builds a compiler capable of rebuilding itself without depending on the Rust compiler for normal development.

## Current status

The repository already contains Sayanox-written self-hosting experiments such as `selfhost/sayanoxc.sa` and `selfhost/compiler.sa`. These are currently small bootstrap/compiler slices rather than a complete self-hosted compiler.

The next engineering priority is therefore **expanding those Sayanox implementations into real compiler components**, not simply deleting Rust files.

## Definition of success

Sayanox reaches meaningful self-hosting when a contributor can clone the repository, bootstrap the compiler from the small trusted seed, and then use the resulting Sayanox-built toolchain for normal language development.

Rust can then be reduced further without sacrificing correctness or reproducibility.
