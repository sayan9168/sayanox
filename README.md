# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.24

- Stage-2 **always generic** (including `compiler.sa`)
- `hold` reassignment (no double declare)
- **struct** `Point { x, y }` + `p.x` + `Point { 1, 2 }`

```bash
gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_generic_out.c
gcc -o selfhost/compiler_generic selfhost/compiler_generic_out.c
./selfhost/compiler_generic
```

## License

MIT
