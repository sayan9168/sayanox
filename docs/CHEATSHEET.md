# Sayanox cheatsheet

## Run

```bash
./selfhost/sx file.sa --run
# or
cargo run -- file.sa --run
```

## Core syntax

```sayanox
hold x = 42
show x
show "hello"

when x {
  show 1
} otherwise {
  show 0
}

while x {
  show x
  hold x = x - 1
}

make add(a, b) {
  give a + b
}
show add(2, 3)
```

## Data

```sayanox
hold xs = [1, 2, 3]
show xs[0]
show len(xs)
push(xs, 4)

struct Point {
  x
  y
}
```

## Modules

```sayanox
use "other.sa"
```

## Tools

| Tool | Command |
|------|--------|
| CLI | `./selfhost/sx file.sa --run` |
| Packages | `./tools/sxpkg init` |
| Formatter | `./tools/sxfmt.sh file.sa` |
| REPL | `./tools/sxrepl.sh` |
