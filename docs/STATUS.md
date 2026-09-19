# Status

## Self-host Stage-3 — hold/show keyword parse
```sh
make selfhost   # SELFHOST-OK
```
- Parses `hold NAME = NUM` and `show NAME|NUM`
- Emits real C identifiers (`double a = 10;`)
- `chr` / `substr` in stage2 runtime

## Native AOT
for/for-in/elif/break/continue · read/abs/pow · strings · gc · modules

## Package / LSP
`./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`

## Next
- when/while inside sxc input
- sxc self-compile without stage2
- concurrent GC · deep types · remote registry
