# Status

| Item | State |
|------|--------|
| Stage-2 full language | supported |
| **Native runtime x86_64** | **hold/show/when/while/arith/strings** |
| Full Stage-2 parity on native | **not yet** (use Stage-2) |
| struct/list on native | limited / deferred to Stage-2 |

```sh
make native
./selfhost/native_aot examples/hello.sa /tmp/n && /tmp/n
```
