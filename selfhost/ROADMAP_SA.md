# Sayanox .sa codegen

## Done
- **Names → C identifiers**: `count` → `v_99_111_117_110_116` (full name, unique)
- **String content**: `show "hello"` → `putchar` sequence (real chars)
- **List**: `hold xs = [1, 2, 3]` → `double v_..._a[8] = {1, 2, 3}`
- **Struct**: `struct Point { }` → `struct SPoint { double x; double y; }`
- make / give / params / when / while / otherwise

```bash
./selfhost/step5_all.sh
```

## Note
Stage-2 `make` cannot return strings, so names use code-based ids and strings use `putchar`.
Full language programs: `./selfhost/sx file.sa --run`
