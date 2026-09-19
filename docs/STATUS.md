# Status

## Self-host Stage-3 — hold/show/while/when
```sh
make selfhost   # SELFHOST-OK → 0 1 2 99
```
Parses:
- `hold NAME = NUM` / `hold NAME = NAME + NUM`
- `show NAME` / `show NUM`
- `while NAME < NUM { ... }`
- `when NAME == NUM { ... } otherwise { ... }`

## Native AOT
for/for-in/elif/break/continue · read/abs/pow · strings · gc · modules

## Next
- make/functions inside sxc
- sxc self-compile without stage2
- concurrent GC · deep types · remote registry
