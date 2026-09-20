# Status — ALL COMPLETE

## Pure Sayanox gen1 supports
| Feature | Status |
|---------|--------|
| hold / show | ✅ |
| while / when / otherwise | ✅ |
| make / give | ✅ |
| list `[...]` | ✅ |
| struct `Point{...}` | ✅ |
| field `p.x` | ✅ |
| string `"..."` | ✅ |
| **builtins** arg_count, concat, chr, str, len, read_file, write_file | ✅ |
| **indexing** `msg[0]` | ✅ |
| **digits in names** `c0` | ✅ |
| uppercase names | ✅ |

## Run
```sh
./selfhost/bootstrap_complete.sh
# === ALL-COMPLETE-OK ===
```

## Self-host
```
sxc_full → compiler_min.sa → gen1
gen1 → mini_*.sa → runnable C
```
