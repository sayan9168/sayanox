# Status — remaining steps completed (slices)

## 1. Self-host control flow + functions
```sh
make selfhost      # while/when → 0 1 2 99
make selfhost-fn   # make/give/call → 42
```
- `sxc.sa` — hold/show/while/when/otherwise
- `sxc_fn.sa` — make NAME(p) { give p + p } + call

## 2. Day-to-day without re-running stage2
Once `sxc` / `sxc_fn` binaries exist, they compile matching `.sa` → C without stage2.
Stage2 is **bootstrap only** (build the Sayanox compilers once).

## 3. Package manager remote
```sh
./tools/sxpkg.sh fetch <url> [name]
./tools/sxpkg.sh types file.sa
```

## 4. GC
- STW `gc` + cooperative concurrent-style `gc_step` (see docs/GC.md)

## 5. Types
- Runtime tags + Stage-2 decl checks + `sxpkg types` (see docs/TYPES.md)

## Native AOT
for/for-in/elif/break/continue · strings · modules · gc
