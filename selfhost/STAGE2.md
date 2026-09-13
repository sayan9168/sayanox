# Stage-2 (complete)

Stage-2 is the self-host `.sa` → C compiler.

## Build

```bash
./selfhost/restore_stage2.sh
# produces selfhost/stage2 binary
```

## Features (English messages)

- show / hold / when / otherwise / while / make / give / struct
- lists, strings, indexing, modulo `%`
- bare assignment, type-safe hold
- stdlib: len, concat, str, read_file, write_file, upper, lower, trim, ...
- `use "file.sa"` multi-file expansion

## Verify

```bash
./selfhost/bootstrap_selfhost.sh
```

Expect: `=== STAGE-2 COMPLETE + SELF-HOST OK ===`
