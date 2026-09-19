# Status

## Native AOT — feature complete for current scope
- **for i = a to b** · **for x in list**
- **break / continue** · **export**
- **substr** · **string == / !=** · **min/max/exit**
- **gc / gc_step / gc_info** (incremental + STW)
- make/give · arg · assert · not/! · s[i] · modules (use)

```sa
hold xs = [10, 20, 30]
for x in xs { show x }
for i = 1 to 5 { show i }
gc_step   // incremental
export foo
```

## GC
- `gc` — full STW mark-copy
- `gc_step` — cooperative incremental (2 slots)
- Stage-2: pthread concurrent path

## Package registry (local)
```sh
./tools/sxpkg.sh init
./tools/sxpkg.sh seed      # hello + math samples
./tools/sxpkg.sh search hello
./tools/sxpkg.sh add hello && ./tools/sxpkg.sh install
./tools/sxpkg.sh info math
```

## LSP
- `./tools/sayanox-lsp.sh` v0.3+ keywords
