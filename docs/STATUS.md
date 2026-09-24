# Status

## TRUE-PURE-GEN2-OK (live, no repo freeze)

```sh
python3 selfhost/install_sxc_full.py   # if needed
./selfhost/bootstrap_true_pure_gen2.sh
# === TRUE-PURE-GEN2-OK ===
```

| Step | Result |
|------|--------|
| Seed sxc_full via install script | OK |
| Live pure .sa → gen1.c every run | OK |
| gen1 → mini_in2 | OK |
| gen1 → gen2_raw.c (no hang) | OK |
| gen2 from live gen1.c | OK |
| gen1 == gen2 on mini_in2 | OK |
| No gen1_frozen.c required in repo | OK |

## Remaining for full pure emit
gen2_raw.c is not yet clang-clean as a full compiler; gen2 still uses live gen1.c until pure emit is complete.

## Optional next
- clang-clean gen2_raw only (no gen1.c copy)
- Modules / types / LSP
