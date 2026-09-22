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
