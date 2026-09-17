# Step 1 — Full Self-Host Compiler Pipeline

Step 1 establishes one canonical bootstrap cycle for the Sayanox compiler.

## Pipeline

```text
Sayanox source (.sa)
        |
        v
   Lexer / Parser
        |
        v
      AST
        |
        v
 Semantic checking
        |
        v
   Checked AST
        |
        v
      Sayanox IR
        |
        v
     Lowering
        |
        v
     Backend
        |
        v
 executable program
```

The repository keeps the compiler stages as Sayanox source under `selfhost/`. The
current bootstrap seed is deliberately small and temporary: `build_stage2.c` and
the generated Stage-2 binary provide the initial host needed to execute the
Sayanox-written compiler.

## Canonical command

```sh
bash selfhost/bootstrap_cycle.sh
```

The cycle:

1. verifies the required self-host stages exist;
2. rebuilds the Stage-2 bootstrap binary;
3. lowers `selfhost/compiler.sa` using Stage-2;
4. builds and runs the Sayanox compiler host;
5. verifies generated C produces `42` for the bootstrap program;
6. verifies the normal `sx` CLI still compiles `examples/hello.sa`.

## What Step 1 does not claim

Step 1 does **not** claim that Sayanox is already C-free. The Stage-2 C seed and a
C compiler are still required for this bootstrap boundary. Removing that boundary
is a later native-backend milestone.

Likewise, collection types, complete function semantics, Result/Option, and the
expanded standard library are separate milestones and should not be declared
complete merely because this bootstrap cycle passes.

## Design rule

Every new compiler feature should move into the Sayanox-owned pipeline rather than
adding another permanent bootstrap script. The temporary host is an implementation
detail, not part of the Sayanox language design.
