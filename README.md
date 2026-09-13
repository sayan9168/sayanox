# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.29

New in this release:

- String stdlib: `contains`, `starts_with`, `ends_with`, `upper`, `lower`, `trim`
- Modulo `%`
- Bare assignment `i = i + 1` (after `hold`)
- Type-safe `hold` reassignment (number/string/list mismatch errors)
- GitHub Actions CI (Rust host + Stage-2 + Stage-3)

## Quick start (Termux / Linux)

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
clang -o selfhost/stage2 selfhost/stage2_template.c
chmod +x selfhost/sx
./selfhost/sx selfhost/hello.sa --run
./selfhost/sx selfhost/features_demo.sa --run
```

## Stage-3 / generic compiler

```bash
./selfhost/bootstrap_stage3.sh
./selfhost/bootstrap_generic_compiler.sh
```

## License

MIT
