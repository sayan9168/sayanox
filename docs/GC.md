# GC

## Native
| Call | Behavior |
|------|----------|
| `gc` | Stop-the-world mark-copy all string slots |
| `gc_step` | Incremental: copy 2 live string slots (cooperative) |
| `gc_info()` | Current bump offset |

## Stage-2
- pthread concurrent mark-sweep

## Design
True OS-thread concurrent GC in pure ELF (no libc/pthread) is limited.
`gc_step` gives cooperative concurrent-style collection for long loops:
```sa
while work {
  gc_step
  // ...
}
```
