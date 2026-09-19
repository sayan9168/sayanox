# Garbage collection

## Modes
| Mode | API | Notes |
|------|-----|--------|
| Stop-the-world | `gc()` | Full collect |
| Cooperative concurrent-style | `gc_step()` | Incremental; call in long loops |
| Info | `gc_info()` | heap stats |

## Concurrent design
Native ELF has no pthread → cooperative `gc_step()` is the concurrent-style path.
Stage-2 C host may use `-pthread` for optional mark threads later.

```sa
hold i = 0
while i < 10000 {
  when i % 100 == 0 { gc_step() }
  hold i = i + 1
}
gc()
```
