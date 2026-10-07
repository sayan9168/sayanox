# Sayanox cheatsheet

## Build and run

```sh
make doctor
make true-selfhost
make gen3
./selfhost/gen2 examples/hello.sa /tmp/hello.c
cc -O2 -o /tmp/hello /tmp/hello.c
/tmp/hello
```

## Core syntax

```sayanox
hold x = 42
show x
show "hello"

when x > 0 {
  show 1
} otherwise {
  show 0
}

while x > 0 {
  show x
  hold x = x - 1
}

make add(a, b) {
  give a + b
}
show add(2, 3)
```

## Numbers

```sayanox
hold rate = 2.5
show rate * 4
show 10 / 4       // 2.5
show 10 % 3       // 1; operands are truncated before remainder
```

`% 0` reports `division by zero`. Integer-only constant expressions use
floating-point arithmetic in the generated C as well.

## Lists and structs

```sayanox
hold xs = [1, 2, 3]
show xs[0]
show len(xs)
push(xs, 4)

struct Point {
  x
  y
}
hold p = Point { x: 3, y: 4 }
show p.x
```

## Strings and modules

```sayanox
hold message = concat("hello", " world")
show len(message)
show message[0]

use "other.sa"       // textual source splice, not a namespace import
```

The shared subset also provides `chr`, `string_eq`, file helpers and command-
line argument helpers. See [`BUILTINS.md`](BUILTINS.md) and
[`STATUS.md`](STATUS.md) for exact backend coverage.

## Native AOT

On x86-64 Linux:

```sh
make native
./selfhost/native_aot examples/hello.sa /tmp/hello-native
/tmp/hello-native
```

The native compiler implements a tested subset and reports clear errors for
unsupported syntax. It is not a portable replacement for the C backend.
