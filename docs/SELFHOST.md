# Full self-host (Stage-3)

## Claim
The **compiler logic** is written in Sayanox (`selfhost/sxc.sa`).
Bootstrap host (`stage2`, C) is only used once to lower `sxc.sa` → C → binary.

## Loop
```
stage2  (C bootstrap)  compiles  sxc.sa  →  sxc binary
sxc     (Sayanox)      compiles  hello.sa →  hello_out.c
clang                                  →  hello_from_sxc
run                                    →  42
```

## Commands
```sh
make selfhost
# or
./selfhost/bootstrap_selfhost.sh
```

## Files
| File | Role |
|------|------|
| `selfhost/sxc.sa` | Stage-3 compiler in Sayanox |
| `selfhost/sxc` | Binary produced by stage2 from sxc.sa |
| `selfhost/hello_out.c` | C emitted by sxc |
| `selfhost/compiler.sa` | Larger pipeline (still expanding) |

## Limits (honest)
- Current `sxc.sa` handles the **numeric literal → C print** vertical slice used by `hello.sa`.
- Full grammar (all of `compiler.sa` / `parser.sa`) still expands on this path.
- Bootstrap still needs **one** C stage2 binary and **clang** to link C output.
- Next: grow `sxc.sa` until it emits all of itself, then replace stage2.
