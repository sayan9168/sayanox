# Status

## Clean clone

```sh
chmod +x selfhost/restore_sxc_full.sh
./selfhost/restore_sxc_full.sh
make subset      # SUBSET-SELFHOST-OK
make pure-gen2   # PURE-GEN2-OK
```

| Item | Status |
|------|--------|
| plain `sxc_full.c` (>10KB, has sx_chr) | required seed |
| `sxc_full_lines/L*.txt` | cat restore |
| `sxc_full_b64_plain/p*.txt` | base64 (no gzip) restore |
| pure compiler_min.sa → gen1 | OK |
| gen1 → mini_in2 | OK |
| gen2 via frozen pure C | OK |

**Do not use** gzip `sxc_full_b64` (corrupt).

## Optional next
- Live gen1→gen2.c without freeze
- Modules / types / LSP
