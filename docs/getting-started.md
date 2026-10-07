# Getting started with Sayanox

Sayanox source files use the `.sa` extension. This guide uses the maintained
seed-min/gen2 compiler path; it does not require Cargo or a Rust toolchain.
For the exact supported subset and backend differences, see
[`STATUS.md`](STATUS.md).

## 1. Build and verify the compiler

Install `make`, a POSIX shell and a C99 compiler (`cc`, `clang` or `gcc`), then
run from the repository root:

```sh
make doctor
make true-selfhost
make gen3
```

`make true-selfhost` builds gen2 from the Sayanox source and runs its feature
regressions. `make gen3` checks that the compiler has reached a reproducible
fixed point (`gen3 == gen4`).

## 2. Run your first program

`examples/hello.sa` contains a minimal program:

```sayanox
show "Hello from Sayanox!"
```

Compile it to C with gen2, then build and run the generated C:

```sh
./selfhost/gen2 examples/hello.sa /tmp/hello.c
cc -O2 -o /tmp/hello /tmp/hello.c
/tmp/hello
```

The optional native-AOT subset is available on x86-64 Linux:

```sh
make native
./selfhost/native_aot examples/hello.sa /tmp/hello-native
/tmp/hello-native
```

## 3. Bindings and arithmetic

```sayanox
hold name = "Sayan"
hold count = 2.5
show name
show count * 2
hold count = count + 1
```

Numbers are IEEE doubles. `/` is true division; `%` truncates its operands to
integers and reports `division by zero` for a zero divisor.

## 4. Conditions and loops

```sayanox
hold n = 3
when n > 0 {
  show "positive"
} else {
  show "not positive"
}

hold i = 1
while i <= 3 {
  show i
  hold i = i + 1
}
```

## 5. Functions

```sayanox
make square(n) {
  give n * n
}

show square(8)
```

Top-level numeric functions support recursive calls in the maintained subset.

## 6. Lists and structs

Lists hold numbers:

```sayanox
hold values = [10, 20, 30]
push(values, 40)
show values[1]
show len(values)
```

Struct fields are declared by name and can hold supported number or string
values; nested structs and field chains are tested:

```sayanox
struct Point {
  label,
  x
}
hold p = Point { label: "origin", x: 0 }
show p.label
show p.x
```

## 7. Strings, files and arguments

The shared runtime provides the string operations listed in
[`STATUS.md`](STATUS.md), including `concat`, `len`, `chr`, `string_eq` and
string indexing. File and command-line helpers include `read_file`,
`write_file`, `arg` and `arg_count`.

```sayanox
hold text = concat("hello", " Sayanox")
show text
show len(text)
```

## 8. Modules

`use` textually splices another `.sa` source file before parsing:

```sayanox
use "library.sa"
show answer()
```

This is not namespaced or versioned package importing. See
[`REGISTRY.md`](REGISTRY.md) for the separate package-tooling status.

## 9. Current boundaries

The maintained bootstrap does not yet include every form shown in historical
examples. Namespaced exports, a full standard library and automatic memory
management across all backends remain future work; the gen2 path has
`for`/`for-in`/`elif`, single-type-parameter generics and a mark & sweep
collector, while native AOT still bump-allocates. The native-AOT compiler is
x86-64 Linux only. See
[`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md) for the larger plan.
