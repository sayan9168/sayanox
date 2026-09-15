# Sayanox compiler written in Sayanox

The language compiles itself through a thin C Stage-2 host.

```text
  .sa source
      |
      v
  Stage-2 (C)  ---- lowers ---->  C program
      |
      v
  sayanoxc.sa / compiler.sa   (logic is pure Sayanox)
      |
      v
  generated C  ---- clang ---->  binary
```

## Files

| File | Role |
|------|------|
| `selfhost/sayanoxc.sa` | Minimal self-hosted compiler (`show <number>` → C) |
| `selfhost/compiler.sa` | Stage-3 entry compiler |
| `selfhost/compiler_boot.sa` | Bootstrap helper |
| `selfhost/lexer.sa` | Lexer in Sayanox |
| `selfhost/parser.sa` | Parser in Sayanox |
| `selfhost/codegen.sa` | Codegen in Sayanox |

## Run

```bash
./selfhost/restore_stage2.sh
./selfhost/sx selfhost/sayanoxc.sa --run
# writes selfhost/sayanoxc_out.c
clang -o selfhost/sayanoxc_out selfhost/sayanoxc_out.c
./selfhost/sayanoxc_out
```

Stage-2 is only the host that executes Sayanox; **compiler algorithms are written in Sayanox**.
