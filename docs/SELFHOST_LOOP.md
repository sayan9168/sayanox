# Stage-3 self-host without stage2

## Fast path (no stage2 binary)
```sh
make selfhost-fast
# decodes selfhost/sxc_out_c/*.b64 → sxc_out.c → clang → ./selfhost/sxc
```

`sxc_out.c` is the Stage-2 lowering of `sxc.sa`, stored compressed so **building the Stage-3 compiler only needs clang**.

## App path (also no stage2)
```sh
./selfhost/sxc my.sa my.c
clang -O2 -o my my.c
```

## Regenerating sxc_out (when sxc.sa changes)
```sh
make selfhost   # uses stage2 once
# then re-pack selfhost/sxc_out.c into sxc_out_c/*.b64
```

## Limit
Re-lowering the full `sxc.sa` source still requires stage2 (or a future full-language sxc).
Running and compiling **user programs** in the supported subset does **not**.
