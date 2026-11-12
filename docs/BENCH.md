# `sxbench` — what each compiler path costs, and whether they still agree

`tools/sxbench.sa` builds one program with each compiler path, compares what the
resulting programs print, and reports how long each stage took. It is the tool you
reach for after a compiler change.

```sh
./sx target tools/sxbench
./tools/sxbench                              # examples/hello.sa, one compile per path
./tools/sxbench --source tools/sxrepl.sa     # a real program
./tools/sxbench --source examples/hello.sa --repeat 5
```

```
$ ./tools/sxbench --source tools/sxrepl.sa --repeat 2
sxbench: tools/sxrepl.sa  (repeat 2)
native-aot    143.368 ms  .sxbench/image.elf
native image:  deterministic across 2 compile(s)
gen2-emit     198.020 ms  .sxbench/program.c
cc -O2        447.607 ms  .sxbench/program.cc
gen2-total    645.628 ms  what a user waits for
output:        both programs printed the same thing
image:         76 KB
```

(Measured once on this checkout, on one machine. Treat the figures as a
comparison between stages there, not as compiler throughput to quote.)

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `--source FILE` | `examples/hello.sa` | the program to build |
| `--repeat N` | `1` | compile N times; every image must equal the first |
| `--out BIN` | `.sxbench/image.elf` | where the native image goes, and kept |
| `--keep DIR` | off | keep the intermediate files, and say where |
| `--quick` | off | skip the C path (native stage only) |
| `--native CMD` | `./tools/sxc_native` | the native compiler to drive |
| `--gen2 CMD` | `./selfhost/gen2` | the C emitter to drive |

An unknown option is refused with status 2 and named. That is deliberate: an
ignored flag is how a typo becomes "the measurement I did not ask for".

## The two halves, and which one is a promise

**Timing is a report.** A number that moves is information, not a failure. Each
stage is timed around the command that does the work, so the figure includes this
program's own process and file work — compare stages against each other on one
machine; do not quote them as compiler throughput.

The clock is `date +%s%N` read through `run_command`, because the language has no
clock builtin. A machine whose `date` lacks `%N` gives non-numeric text, so every
stage reports `n/a` and the report says `clock: unavailable` rather than printing
confident zeroes.

**Equality is a promise.** Two compilers that disagree about the same source are a
defect, so:

* `--repeat N` compiles the source N times and requires every image to be
  byte-identical to the first (`cmp`). The encoder is documented as
  deterministic, and this exercises that on *your* source instead of on a fixture.
  A non-deterministic compiler is caught and reported as
  `native image: DIFFERS between compiles`.
* The native image and the `gen2` → `cc` executable are both run, and their output
  is compared byte for byte. A disagreement is reported as `MISMATCH` with both
  outputs shown.

Byte equality *between the two images* is not expected and is not claimed: one is
an ELF written directly, the other is C compiled by a host compiler.

## Why `--native` and `--gen2` exist

A determinism check that has only ever been run against a compiler that already
obeys it proves nothing. These switches let `test-sxdiag` plug in a deliberately
bad compiler and require the tool to catch it, which is what the `bench` suite
does:

```sh
# a "compiler" that writes a fresh timestamp into its output
printf '#!/bin/sh\ndate +%%N > "$2"\n' > /tmp/bad.sh && chmod +x /tmp/bad.sh
./tools/sxbench --source examples/hello.sa --repeat 2 --native /tmp/bad.sh
```

```
native image:  DIFFERS between compiles
```

## Limits

* `selfhost/native_aot` is not used: it has no `exit` builtin, and a tool command
  line needs one. `tools/sxc_native` is the native path the build driver ships.
* The C path needs a host C compiler; the native path does not. That asymmetry is
  the point of having both.
* A missing compiler is named and fails the run; it is never silently skipped.
* The determinism check compares the image bytes, not the program's behaviour.
  Two different images can behave identically — that is a determinism defect, not
  a correctness one, and it is reported as such.

## Where it is pinned

* `tools/sxbench.sa` — the implementation; `./sx target tools/sxbench` builds it.
* `tools/sxdiag.sa` — the `bench` suite, 7 cases: the report shape (a row per
  stage, the determinism row, the agreement row), `--quick` skipping the C path
  without reporting a total it did not measure, a missing source refused by name,
  an unknown option refused with status 2, `--out` writing where it was told, a
  non-deterministic compiler caught, and a disagreeing compiler caught.
* `tools/sxmore_gates_lib.sa` — `test-sxdiag` runs the suite and asserts the
  `bench: 7` line.

```sh
./tools/sxdiag bench ./selfhost/seed/sxc_seed_min ./selfhost/gen2 ./selfhost/native_aot /tmp/bench
```
