# Full self-host (Stage-3)

## Claim
Compiler logic is **Sayanox** (`selfhost/sxc.sa`).
C `stage2` is bootstrap only (one lower step).

## Loop
```
stage2   compiles  sxc.sa           → sxc
sxc      parses    sxc_test_in.sa   → sxc_emit.c
clang    links                      → sxc_run
run                                 → 10 / 32
```

## What sxc parses (keyword AST slice)
| Form | Emitted C |
|------|-----------|
| `hold NAME = NUMBER` | `double NAME = NUMBER;` |
| `show NAME` | `printf("%g\n", NAME);` |
| `show NUMBER` | `printf("%g\n", (double)NUMBER);` |

Also skips whitespace and `//` comments.

## Example input
```sa
hold a = 10
hold b = 32
show a
show b
```

## Example output
```c
#include <stdio.h>
int main(void){
  double a = 10;
  double b = 32;
  printf("%g\n", a);
  printf("%g\n", b);
  return 0;
}
```

## Commands
```sh
make selfhost
```

## Stage-2 runtime helpers
- `chr(code)` → one-char string
- `substr(s, start, len)`

## Limits
- No `when` / `while` / `make` in sxc input yet
- Still needs stage2 once + clang to link
- Next: control-flow lowering inside sxc
