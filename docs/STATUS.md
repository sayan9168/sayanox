# Status

## Pure Sayanox bootstrap

The supported pure-Sayanox bootstrap path is:

```
sxc_full (C seed)
  -> compiler_min.sa
  -> gen1
  -> compiler_min.sa
  -> gen2
```

gen1 and gen2 are both native binaries produced from generated C.

## True self-compile proof

Run:

```sh
chmod +x selfhost/bootstrap_gen2.sh
./selfhost/bootstrap_gen2.sh
```

The proof requires:

1. sxc_full builds gen1 from selfhost/compiler_min.sa.
2. gen1 compiles the same selfhost/compiler_min.sa into selfhost/gen2.c.
3. Clang builds gen2.
4. gen1 and gen2 compile mini_in2.sa, and the resulting programs produce byte-for-byte identical output.
5. The existing mini_in2, mini_field, mini_builtin, mini_index, and mini_in3 sources still compile and run.

The self-compile step has a bounded timeout so a scanner/parser regression cannot leave the bootstrap hanging indefinitely.

## Hold RHS coverage

The compiler-min source exercises hold RHS support for:

- read_file(...)
- write_file(...)
- concat(...)
- chr(...)
- str(...)
- len(...)
- arg(...)
- arg_count()
- string indexing such as source[pos]

These operations are required for compiler_min.sa to be a valid gen1 input and for gen1 to reproduce gen2.

## Current status

The true self-compile script is the executable proof entry point. Do not mark the bootstrap complete unless bootstrap_gen2.sh finishes with:

```
=== TRUE-SELF-COMPILE-OK ===
```
