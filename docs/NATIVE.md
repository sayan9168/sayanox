# Native backend (step 4 — runtime machine code)

Linux **x86_64** ELF with **real runtime instructions** (not only AOT-eval embed).
**No clang** is used to build the user `.sa` binary.

```sh
make native
./selfhost/native_aot examples/hello.sa hello_native
./hello_native
```

## Runtime-supported

| Feature | Notes |
|---------|--------|
| `hold` / `show` | 8 int slots by name initial |
| `+ - * /` `()` | live x86 |
| `when` / `otherwise` / `while` | real jumps |
| `show "string"` | write syscall |

## Not full Stage-2 parity

| Feature | Path |
|---------|------|
| Full struct / list / GC / modules | **Stage-2 → C → clang** |
| All builtins (`read_file`, …) | Stage-2 |
| Non-x86_64 / non-Linux | not yet |

Honest goal: native subset grows; full language remains Stage-2 until ISA coverage is complete.
