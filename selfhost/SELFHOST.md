# Sayanox self-hosting

## Pipeline

```text
stage2_template.c  --clang-->  stage2 binary
      |
      +-- compiles any .sa subset --> C --> clang --> native binary
      |
      +-- compiles compiler_boot.sa --> stage3 --> writes hello_out.c --> 42
      |
      +-- CLI: ./selfhost/sx file.sa [--run]
```

## Prove it

```bash
chmod +x selfhost/bootstrap_selfhost.sh
./selfhost/bootstrap_selfhost.sh
```

## What “full self-host” means here

1. **Stage-2** is the production self-host compiler for the Sayanox subset (no Rust needed to compile `.sa`).
2. **sx** is the path-based CLI over Stage-2.
3. **Stage-3** is a Sayanox program (`compiler_boot.sa`) compiled by Stage-2 that itself emits C.
4. Optional: `use "file.sa"` when `expand_uses` is present in `stage2_template.c`.

Rust host remains available for diagnostics / types / export modules (`cargo build --release`).
