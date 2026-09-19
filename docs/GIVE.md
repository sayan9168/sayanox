# give + recursive functions

```sa
make double(n) {
  give n * 2
}
hold x = double(21)
show x

make fib(n) {
  when n <= 1 {
    give n
  } else {
    give fib(n - 1) + fib(n - 2)
  }
}
hold r = fib(10)
show r
```

- `give expr` leaves the value in `rax` and returns
- Recursive calls save/restore all 16 var slots so params survive nested calls
- `else` is accepted as an alias for `otherwise`
