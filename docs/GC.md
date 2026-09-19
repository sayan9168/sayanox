# Garbage collection

## Modes
| Mode | API | Notes |
|------|-----|--------|
| **Start bg thread** | `gc_start()` | OS pthread; sweeps every ~50ms |
| Stop-the-world | `gc()` | Full registry sweep now |
| Cooperative | `gc_step()` | One sweep under same lock |
| Info | `gc_info()` | Live registered heap bytes |
| Manual | `release(s)` | Drop RC on a heap string |

## Concurrent design (Stage-2 C host)
- Heap strings from `concat` / `str` are **registered** with RC=1
- Reassigning a string `hold` **releases** the previous pointer
- Background thread (`gc_start`) periodically sweeps RC≤0 slots under a mutex
- Native ELF path remains cooperative (`gc_step` only; no pthread)

```sa
hold _ = gc_start()
hold s = "a"
hold i = 0
while i < 100 {
  hold s = concat(s, "x")
  hold i = i + 1
}
show gc_info()
hold _ = gc()
show "ok"
```

Build: `clang -O2 -pthread ...`
