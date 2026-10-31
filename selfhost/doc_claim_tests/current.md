# Supported current guide

```sh
./sx target doctor true-selfhost gen3 native-test
./sx ci
```

Sayanox declaration syntax is valid: `make doctor(n: num) -> num` and `make square(n)`.
The Makefile and maintained C seed are retired; necessary host tools remain.

Spaced declarations such as `make doctor (n: num) -> num` and generic
`make native<T>(v: T)` remain language syntax. Ordinary words such as
remake doctor and remake native are not build commands.
