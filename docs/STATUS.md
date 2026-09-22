# Status

## Working path (clean clone)

```sh
make subset          # SUBSET-SELFHOST-OK
make pure-gen2       # PURE-GEN2-OK
./selfhost/bootstrap_gen2.sh  # TRUE-SELF-COMPILE-OK
```

| Item | Status |
|------|--------|
| `selfhost/sxc_full.c` plain seed | ✅ (no gzip) |
| `sxc_full_lines/L*.txt` backup | ✅ cat-only restore |
| pure `compiler_min.sa` → gen1 | ✅ |
| gen1 → mini_in2 | ✅ |
| gen2 without sxc_full (frozen pure C) | ✅ |
| gen1 parses own source (no hang) | ✅ |

## Do not use
- `selfhost/sxc_full_b64/*.txt` (corrupt gzip archives)

## Optional next
- Live gen1→gen2.c clang-clean without frozen copy
- Modules / types / LSP


## Language quality path

The working Stage-2 path has conformance fixtures for:

- relative `import "file.sa"` resolution;
- cyclic-module detection with an explicit import chain;
- lightweight kinds: `num`, `str`, `list`, and `struct`;
- type mismatch diagnostics for expressions and calls;
- source-aware diagnostics with file/line/column, source context, caret, and hint where the diagnostic backend provides them.

Run:

```sh
make lang-quality
```

The existing subset smoke remains unchanged:

```sh
make subset
```

Success marker:

```
=== LANG-QUALITY-OK ===
```
