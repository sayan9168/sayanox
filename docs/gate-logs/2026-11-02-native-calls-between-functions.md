# Gate log — 2026-11-02 — R02 step 9: calls between functions

## What was refused before

Step 8 let only the main program call a function:

```
$ ./tools/native32 refuse/fn_call_in_body.sa out.elf i386
native32: line 1: 'one' is called from inside a make body; native32 v1 only lets the main program call a function
```

The reason was mechanical: `bl` (AArch64) and `jal` (RV64IM) overwrite the link
register, so a call made from inside a body returned to the wrong address.

## The change

1. **Link-register save/restore.** `emit_fn_prologue` opens every body with
   `str x30,[sp,#-16]!` (AArch64) or `addi sp,sp,-16` + `sd ra,8(sp)` (RV64IM),
   and `emit_fn_ret` restores before returning (`ldr x30,[sp],#16` /
   `ld ra,8(sp)` + `addi sp,sp,16` + `jalr x0,0(x1)`). i386 needs nothing: `call`
   already pushes the return address on the stack the expression evaluator uses.
2. **Calls from a body are accepted** and record an edge `(caller, callee)` —
   `-1` for the main program.
3. **The call graph must be acyclic.** `reaches(from, to, seen)` walks the edges,
   and after all bodies are emitted every edge is checked; a cycle is refused
   with

   ```
   native32: line 1: 'ping' takes part in a recursive call chain, which native32 v1 refuses: one parameter slot per function
   ```

   which is the honest reason: each function owns one parameter slot, so a second
   live invocation would overwrite it.

## Fixture

`selfhost/native32_tests/fn.sa` gained

```sayanox
make inc(n: num) -> num {
  give n + 1
}
make apply2(n: num) -> num {
  give add(inc(n), inc(n))
}
…
show apply2(3)
```

so the fixture covers a body calling another function twice inside one call, and
a three-level chain (`main -> apply2 -> inc`). It now prints 13 lines:

```
5
30
6
10
3
7
10
7
8
yes
13
8
done
```

i386 image 8293 bytes; AArch64/RV64IM goldens regenerated for the new
prologue/epilogue; the gate also runs the same source on the seed, gen2 and
native AOT backends and compares output.

A dedicated three-function probe (`inc`, `double`, `addinc`, `apply2`, `deep`)
printed `5 11 8 done` identically on i386, AArch64 under `sxisaexec` and RV64IM
under `sxisaexec`.

## Two encoder defects found by running the images

Both were invisible to the i386 tests and to reading the code:

| symptom | cause | fix |
| --- | --- | --- |
| `sxisaexec: AArch64 misaligned PC 16385` | `str x30` prologue constant was `0xF81F1FFE`, i.e. `[sp,#-15]!` — one bit-field off | `0xF81F0FFE` (`[sp,#-16]!`) |
| RV64IM ran off the rails entirely (fixed in step 8) | the `ret` was `0x806F` = `JAL` | `0x8067` = `JALR x0,0(x1)` |

The three-ISA output equality in the gate is the check that keeps both honest:
i386 executes natively, AArch64 and RV64IM execute under `sxisaexec`, and the
fixture's bytes must match.

## Refusals (matrix stays 51)

- `refuse/fn_call_in_body.sa` deleted — a body calling a function is legal now.
- `refuse/fn_mutual_recursion.sa` added (`ping`/`pong`).
- `refuse/fn_recursion.sa` keeps its place and now reports the cycle diagnostic.

## Gates

```
$ ./sx target test-native32        -> 0
$ ./sx target test-native-arm64    -> 0
$ ./sx target test-native-riscv64  -> 0
```
