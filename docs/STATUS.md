# Status

## Native AOT — next scope complete
- **for / for-in** · **elif** · **break / continue**
- **read()** stdin · **abs / pow** · **repeat**
- **contains / startswith** · **is_str / is_num**
- **substr** · **string ==** · **min/max/exit**
- **gc / gc_step / gc_info** · **export** · modules

```sa
hold s = read()
show abs(0 - 7)
show pow(2, 10)
show contains("hello", "ell")
show repeat("ab", 3)
when n == 1 { show 1 } elif n == 2 { show 2 } else { show 3 }
```

## Package / LSP
- `./tools/sxpkg.sh` local registry
- `./tools/sayanox-lsp.sh`
