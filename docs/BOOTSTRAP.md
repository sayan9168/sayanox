# Sayanox bootstrap

The subset self-host path is intentionally small.

## Bootstrap chain

```text
C compiler (clang)
    |
    v
sxc_full.c
    |
    v
gen1
    |
    +--> subset .sa programs
    |
    +--> compiler_min.sa -> gen2
                       |
                       v
                      gen2
                       |
                       +--> subset .sa programs
```

## What still needs clang

A C compiler is still required only to create the first executable compiler when no trusted bootstrap compiler is already available.

The remaining C-dependent step is:

```sh
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c
```

The reason is bootstrapping: a machine needs at least one executable compiler before it can execute the Sayanox compiler.

After gen1 exists, the subset path does not need sxc_full.c for source compilation.

## Preferred subset path

If selfhost/gen1 already exists:

```sh
./selfhost/gen1 selfhost/program.sa selfhost/program.c
clang -O2 -o selfhost/program selfhost/program.c
./selfhost/program
```

For the next compiler generation:

```sh
./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2.c
clang -O2 -o selfhost/gen2 selfhost/gen2.c
```

Then prefer gen2 for subsequent subset compilation:

```sh
./selfhost/gen2 selfhost/program.sa selfhost/program.c
```

The generated application is still C in the current subset backend, so clang is needed to turn generated C into a native application. This is separate from the compiler bootstrap dependency.

## Bootstrap fallback

gen1 is the preferred bootstrap compiler once it exists. sxc_full.c is only the seed fallback.

A known-good generated gen1.c may be frozen as a last-resort bootstrap artifact when reproducible bootstrapping requires it. It is not the normal subset compilation path.

Do not regenerate gen1 from sxc_full.c merely to compile ordinary subset programs.

## Supported entry points

Use:

```sh
make subset
```

or, when selfhost/gen1 already exists:

```sh
make subset-existing
```

`make complete` remains an alias for the supported subset smoke test for compatibility.

The true self-compile proof remains:

```sh
./selfhost/bootstrap_gen2.sh
```

That script prefers an existing gen1; it falls back to the C seed only when no gen1 executable is available.

## Source of truth

The compiler implementation for the subset is in Sayanox source under selfhost/.

The C seed exists only to solve the initial bootstrap problem. The long-term goal is to eliminate that seed from the normal development path.
