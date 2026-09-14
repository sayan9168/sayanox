# Compiler in Sayanox (.sa)

## Done (1 + 2)

### 1. Expanded .sa codegen
- Multi-var via `S[charCode]` slots (`hold a` / `hold b`)
- `show` number / name / `fn()`
- `when` / `while` / `otherwise`
- `make fn() { give number }`

### 2. Bootstrap role
- Stage-2 C remains the **thin host** that executes `.sa` (cannot invent a CPU from nothing)
- Compiler **logic** for the subset lives in `codegen.sa` (Sayanox)
- Install: `python3 selfhost/install_codegen.py` then `./selfhost/step5_all.sh`

```bash
git pull
./selfhost/step5_all.sh
```

## Still later (optional)
- Full param expressions, structs/strings/lists in .sa codegen
- Replace more of Stage-2 C with .sa incrementally
- LSP / GC / package registry
