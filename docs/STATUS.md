# Status

## Working on clean clone

| Target | Result |
|--------|--------|
| `make subset` | **SUBSET-SELFHOST-OK** |
| `make native-test` | **OK** (42) |
| `make gc-test` | **OK** (2005 / gc-rc-ok) |
| Stage-2 seed | restored via `sxc_full.c` |

## Bootstrap chain

```
sxc_full.c  (C seed, required once)
    |
    v
compiler_min.sa  -->  gen1
    |
    +--> mini_in2 (while/when/make) via gen1
    |
sxc_full --> mini_field / builtins / index / list+struct
```

## True self-compile

```sh
./selfhost/bootstrap_gen2.sh
```

- gen1 is built from pure `compiler_min.sa` via sxc_full
- gen1 compiles `mini_in2.sa` successfully
- Full gen1→gen2 of `compiler_min.sa` still incomplete (gen1 does not yet lower all builtins when compiling itself)

## Seeds present

- `selfhost/sxc_full.c` — canonical C seed
- `selfhost/stage2_template.c` — copy of sxc_full when restored
- `selfhost/build_stage2.c` — falls back to sxc_full.c if blobs fail
