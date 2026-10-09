# Sayanox language tutorial

This tutorial targets the maintained seed-min/gen2 subset. The complete
verified feature matrix is in [`STATUS.md`](STATUS.md); the broader language
and native-AOT plans are in [`BOOTSTRAP_ROADMAP.md`](BOOTSTRAP_ROADMAP.md).

## 1. Hello world

```sayanox
show "Hello, Sayanox!"
```

Bootstrap the Sayanox-written compiler and run the example through generated
C:

```sh
make true-selfhost
./selfhost/gen2 examples/hello.sa /tmp/hello.c
cc -O2 -o /tmp/hello /tmp/hello.c
/tmp/hello
```

## 2. Variables and numbers

```sayanox
hold name = "Sayan"
hold year = 2026
show name
show year

hold total = 100000 * 100000
show total                 // 1e+10
show 10 / 4                // 2.5
```

Use `hold name = expression` to reassign a name already introduced with
`hold`. Numbers are IEEE doubles; `%` truncates its operands and checks for a
zero divisor.

## 3. Conditions and loops

```sayanox
hold age = 18
when age >= 18 {
  show "adult"
} otherwise {
  show "minor"
}

hold i = 1
while i <= 3 {
  show i
  hold i = i + 1
}
```

`else` can be used in place of `otherwise`.

## 4. Functions

```sayanox
make add(a, b) {
  give a + b
}

show add(20, 22)
```

The maintained subset supports top-level numeric functions, calls and
recursion.

## 5. Lists and structs

```sayanox
hold numbers = [10, 20, 30]
push(numbers, 40)
show numbers[1]
show len(numbers)

struct Point {
  name
  x
}
hold p = Point { name: "home", x: 4 }
show p.name
show p.x
```

Lists are numeric. Tested compilers support nested structs, named fields and
string fields.

## 6. Strings and file I/O

```sayanox
hold first = "Sayan"
hold last = "ox"
hold word = concat(first, last)
show word
show len(word)
show word[0]

hold text = read_file("input.txt")
hold status = write_file("output.txt", text)
show status
```

The shared subset's supported builtins are listed in [`BUILTINS.md`](BUILTINS.md)
and [`STATUS.md`](STATUS.md).

## 7. Modules

```sayanox
use "library.sa"
show answer()
```

`use` textually splices a file before parsing; it does not provide namespaces,
version resolution or package isolation.

## 8. Native AOT

A tested native subset can be built on x86-64 Linux:

```sh
make native
./selfhost/native_aot examples/hello.sa /tmp/hello-native
/tmp/hello-native
```

The portable path emits C and still requires a C compiler to build each
program. Native AOT is not yet portable to other architectures or operating
systems.

## 9. Remaining work

Namespaced modules, a full standard library and automatic memory management
across all backends are not yet part of the maintained subset. The gen2 path
does have `for`/`for-in` with `break`/`continue`, `elif`, a mark & sweep
collector ([`GC.md`](GC.md)) and generics with one or more type parameters
([`GENERICS.md`](GENERICS.md)); native AOT still bump-allocates. This is an
incremental milestone, not a claim that every language experiment in the
repository is production-ready.
