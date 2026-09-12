# Phase A — Self-host

## Stage-3 loop

```bash
./selfhost/bootstrap_stage3.sh
```

1. `stage2_template.c` → `stage2` binary  
2. **Generic** lower `compiler_boot.sa` → `stage3.c`  
3. `stage3` binary (no Rust)  
4. `stage3` reads `hello.sa` → `hello_out.c`  

## Files

| File | Role |
|------|------|
| `compiler_boot.sa` | Minimal compiler in Sayanox subset |
| `stage2_template.c` | Generic Sayanox→C |
| `bootstrap_stage3.sh` | Proves the loop |

## Still open in Phase A

- Full `compiler.sa` (large) via **generic** only (today: semantic path + `compiler_boot.sa` generic)
- Richer struct field syntax in Stage-2
