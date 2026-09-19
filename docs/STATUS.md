# Status

## Self-host Stage-3 — expanded
```sh
make selfhost   # SELFHOST-OK (prints 10 and 32)
```
- `sxc.sa` in Sayanox collects all ints → emits C
- Test input: `sxc_test_in.sa` (hold a=10, b=32)

## Native AOT
for/for-in/elif/break/continue · read/abs/pow · string ops · gc · modules

## Package / LSP
`./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`

## Still future
- Full AST parse inside sxc (hold/show/when keywords)
- sxc compiling itself end-to-end without stage2
- True concurrent GC · deep types · remote registry
