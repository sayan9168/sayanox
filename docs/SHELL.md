# Build orchestration and Sayanox tools

`Makefile` is the supported build/test entry point. Its recipes use POSIX shell
and a host C compiler for the bootstrap; the main compiler source and the
formatter logic are Sayanox. The repository has **not** yet replaced every
shell tool with a `.sa` program.

```sh
make doctor
make true-selfhost       # C seed-min -> gen1-min -> gen2 + regression tests
make gen3               # gen3 == gen4 fixed point
make sxfmt              # build tools/sxfmt.sa using gen2
make test-sxfmt         # formatter regression tests
make native-test        # optional x86-64 Linux backend tests
```

`make tools` builds the Sayanox formatter and local package-lock utility; it
does not yet build a complete Sayanox CLI or online package manager.
`tools/sxfmt.sa` is a conservative brace-aware whitespace formatter.
`tools/sxpkg.sa` handles local `init`, `add`, `list`, `remove`, `seed`,
`search` and `info`, and the shell entrypoint delegates those commands to it.
Sync/install/publish/fetch and the LSP remain shell programs. Their remaining
porting work is tracked in [`NO_BASH.md`](NO_BASH.md) and
[`SELF_HOSTING_ROADMAP.md`](SELF_HOSTING_ROADMAP.md).

The small C seed, native-AOT implementation, Makefile, POSIX shell and C99
compiler are still part of the current infrastructure. See
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md) for the verified compiler path.
