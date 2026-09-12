# Self-Hosting Sayanox

## What works now (Stage 1)

```text
Rust sayanox  --compiles-->  compiler.sa  --gcc-->  stage1 (Sayanox-built binary)
stage1        --reads----->  hello.sa
              --writes---->  hello_out.c
gcc hello_out.c && ./hello_out
```

Run:

```bash
./selfhost/bootstrap.sh
```

## Features used by the Stage-1 compiler

- `read_file` / `write_file`
- `len` / `push` / `concat` / `str`
- Character lexer (keywords, numbers, operators)
- C emission for `show <number>`

## What is still left for full self-host (Stage 2)

Stage 1 cannot yet compile **`compiler.sa` itself**, because that file uses nested `make`, complex control flow, and heavy string building.

Closing the loop needs full C lowering of every construct in `compiler.sa`.

## Files

| File | Role |
|------|------|
| `compiler.sa` | Stage-1 compiler source |
| `hello.sa` | Sample input |
| `bootstrap.sh` | Stage 0 → Stage 1 |
