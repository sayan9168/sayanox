# Self-Hosting Sayanox — Stage 2

## Pipeline

```text
Stage 0  Rust sayanox
           compiles compiler.sa  ->  stage1.c  ->  stage1 binary

Stage 1  ./stage1  (Sayanox-built)
           reads  hello.sa  ->  hello_out.c
           emits  stage2_cc.c   (Stage-2 mini compiler source)

Stage 2  gcc stage2_cc.c -o stage2
         ./stage2
           reads  hello.sa  ->  stage2_out.c
         gcc stage2_out.c && ./stage2_out
```

## Run

```bash
./selfhost/bootstrap.sh
```

## What Stage 2 is

- Stage 2 compiler **source is produced by the Sayanox-built Stage 1 binary**
- Stage 2 is a C mini-compiler for the subset `show <number>`
- Stage 2 reads `.sa` from disk and writes `.c`

## What Stage 2 is not (yet)

- Stage 2 does **not** compile full `compiler.sa`
- That needs complete self-host C lowering of every construct in `compiler.sa`

## Files

| File | Role |
|------|------|
| `compiler.sa` | Stage-1 source |
| `hello.sa` | Sample input |
| `stage2_cc.c` | Emitted by Stage 1 |
| `stage2_out.c` | Emitted by Stage 2 |
| `bootstrap.sh` | Stage 0/1/2 driver |
