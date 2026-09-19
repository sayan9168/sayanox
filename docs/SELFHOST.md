# Stage-3 self-host

## Loop
```
stage2 → sxc.sa → sxc binary
sxc → sxc_test_in.sa → sxc_emit.c → run → 0 1 2 99
```

## Grammar slice
```sa
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
hold x = 2
when x == 2 {
  show 99
} otherwise {
  show 0
}
```

## Commands
```sh
make selfhost
```
