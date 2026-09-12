# Stage 2 generic lowering (v0.3.22)

## Supported

| Feature | Status |
|---------|--------|
| show / hold / when / while / give | Yes |
| expressions + comparisons | Yes |
| **make name(params) { body }** | Yes → `sx_name` |
| **arrays** `[]` `[1,2]` `a[i]` | Yes |
| **push** | Yes |
| **read_file / write_file / concat / str / len** | Yes (runtime) |
| structs | Limited (not full field syntax yet) |
| compiler.sa semantic path | Yes |

## Run

```bash
gcc -o stage2 stage2_template.c
./stage2 generic_demo.sa out.c
gcc out.c -o out && ./out
```
