# Self-Hosting Sayanox

## Number → string

```sa
hold s = str(42)
show s
```

## Bootstrap script

```bash
./selfhost/bootstrap.sh
```

1. **Stage 0** — Rust `sayanox` compiles `compiler.sa` → `stage1` binary  
2. **Stage 1** — Sayanox-built binary reads `hello.sa`, writes `hello_out.c`  
3. `gcc hello_out.c` → run  

## Grammar (tokenizer)

`show`, `hold`, `give`, `when`/`while`, numbers, idents, `+ - * /`.

## Full self-host (Stage 2)

Stage 1 compiling `compiler.sa` itself needs complete C lowering of the full language inside the self-host compiler.
