# Gate log — 2026-11-03 — R02 step 10: a call is an operand

## What was refused before

Steps 8 and 9 made a call a *whole value*: `hold x = f(1)`, `x = f(1)`,
`show f(1)`, a `when`/`while` condition and another call's argument. An operator
next to a call did not work, because the expression emitter resolved a name
against the variable table only:

```
$ ./tools/native32 /tmp/pm/e1.sa /tmp/pm/e1.elf i386
native32: line 5: unknown name 'add'
```

## The change

1. **The function table is asked first.** `call_shape_at(toks, k, tn)` answers
   "is the token at `k` a declared function followed by `(`", and the expression
   emitter has a block for exactly that shape: emit the call at the token where
   it stands, then `emit_push_acc`, so the result is an ordinary operand and the
   rest of the expression (operators, parentheses, comparisons) is unchanged.
2. **One call path, not two.** The argument-splitting/edge-recording/call
   emission that used to live inside `try_user_call` moved to
   `emit_call_tokens(toks, openat, close, fi, nm)`. The whole-value path calls it
   with the whole text, the operand path calls it with the subrange, so
   `hold x = f(1)` and `hold x = f(1) + 1` emit byte-identical call sequences.
3. **Recursion covers the new edges.** The edge is recorded inside
   `emit_call_tokens`, so an operand call is in the call graph and the acyclic
   walk refuses `give f(n) + 1` exactly like `give f(n - 1)`.

The call is emitted after the callee's own arguments have been popped into
parameter slots, and the callee's expression leaves one value in the
accumulator, so the shared value stack is balanced at every point; the calling
convention itself (step 8) is untouched.

## A defect found by running the new path

The first build of the operand path failed every case with

```
native32: line 5: two values in a row in an expression
```

The cause was not the call: the new block advances the token cursor (`k =
cclose`) and the blocks that follow it in the same iteration still evaluated
their conditions with `t0` from the *old* token and with the *new* `k`, so the
name block ran a second time on `add` at the `)` position. Instrumenting the
loop with a token/k/want log showed one iteration (`0:vadd/w1`) followed by the
argument sub-expressions and then the bogus failure. Each iteration now carries a
`call_done` flag and the later blocks are guarded by it. This is the class of bug
that only shows up when the code is executed, so it went into the log rather than
into a commit message.

## Operand forms, executed

`/tmp/pm/g10.sa` prints, on i386 (`md5 3b0a843d2f180b531431718c62fd6e36`):

| source | expected | printed |
| --- | --- | --- |
| `hold a = inc(4) + 1` | 6 | 6 |
| `show 1 + inc(1)` | 3 | 3 |
| `show inc(inc(1)) + 10` | 13 | 13 |
| `show 2 * inc(3) - 1` | 7 | 7 |
| `show (inc(1) + inc(2)) * 2` | 10 | 10 |
| `show add(inc(1) + 1, inc(2))` | 6 | 6 |
| `show 100 - seven() * 3` | 79 | 79 |
| `show add(1, 1) == 2` | 1 | 1 |
| `when inc(1) + 1 == 3 { show "yes" }` | yes | yes |
| `show seven() + seven()` | 14 | 14 |

The same source compiled for AArch64 and RV64IM and executed under `sxisaexec`
produced the same bytes:

```
$ md5sum g10.i386.out g10.arm64.out g10.rv64.out
3b0a843d2f180b531431718c62fd6e36  g10.i386.out
3b0a843d2f180b531431718c62fd6e36  g10.arm64.out
3b0a843d2f180b531431718c62fd6e36  g10.rv64.out
```

Two neighbours of the same code path were checked while the probe was up:
`s[inc(1)]` on `"abcdef"` printed `99` (index 2, `c`) and
`len(concat(s, chr(inc(1))))` printed `7`, because the string-index and `chr`
beside an expression already compile through `emit_expression`.

## Fixture

`selfhost/native32_tests/fn.sa` gained six operand lines — grouped calls,
precedence, a call as one argument subterm, a condition, and a negative-multiple
case:

```sayanox
show add(2, 3) + 1
show 1 + twice(3)
show add(1, 1) * add(2, 2)
show (inc(1) + inc(2)) * 2
hold deep = 100 - seven() * 3
show deep
when inc(1) + 1 == 3 { show "operand" }
```

It prints 19 lines (`5 30 6 10 3 7 10 7 8 yes 13 8 6 7 8 10 79 operand done`),
pins i386 **8305** bytes, and the AArch64/RV64IM goldens were regenerated. The
fixture still runs on all six execution paths (seed, gen2, native C, AOT i386,
AOT AArch64, AOT RV64IM) with the parity assertion inside the gate.

## Refusals (51 -> 52)

- `refuse/fn_recursion_in_operand.sa` is new: `give f(n) + 1` records the edge
  from the operand path and is refused with
  `'f' takes part in a recursive call chain, which native32 v1 refuses: one
  parameter slot per function`.
- Everything else keeps its diagnostic: unknown call name, wrong arity, a string
  argument, division, `concat(...)` inside another expression (now including
  `concat` inside an operand expression, since a call may feed an operator but a
  `concat` may not).

## Gates

```
$ ./sx target test-native32        -> 0   (4-backend parity, i386 size pins, goldens, 52 refusals)
$ ./sx target test-native-arm64    -> 0
$ ./sx target test-native-riscv64  -> 0
```

## Negative controls (the gate actually tests these numbers)

Both were run against the real gate, one at a time, with the pin restored
afterwards:

```
$ sed -i 's/expected = 8305/expected = 8304/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] reviewed i386 image size: got 8305, want 8304
sxbuild: target failed: test-native32          -> NEG1 EXIT 1

$ sed -i 's/arch, 0, 52)/arch, 0, 51)/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] complete backend refusal matrix: got 52, want 51
sxbuild: target failed: test-native32          -> NEG2 EXIT 1
```

The two controls fail at the first fixture and at the refusal walk respectively,
which is why they return in seconds while a green run takes minutes: the walk
stops at the first failing assertion. The library file was restored byte for byte
before the green runs quoted above.
