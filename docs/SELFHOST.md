# Self-host + CLI

## Build once
```sh
make selfhost
```

## Compile any matching .sa
```sh
./selfhost/sxc path/to/file.sa path/to/out.c
clang -O2 -o app path/to/out.c
./app
```

Defaults if args omitted:
- input: `selfhost/sxc_test_in.sa`
- output: `selfhost/sxc_emit.c`

## Grammar
make/give/call · hold/show · while · when/otherwise

## Stage-2 helpers
`arg_count()` · `arg(i)` · `chr` · `substr`
