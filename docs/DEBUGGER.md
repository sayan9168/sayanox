# Debugging a Sayanox program

`tools/sxirexec` is the portable IR virtual machine. It executes the
target-independent IR listing that `tools/emit_to_ir` produces, and the same
program has been running under it since `test-ir-exec` started comparing
`seed-min == gen2 == native_aot == sxirexec` four ways. The debugger is that
interpreter with the stop test switched on, not a second interpreter written
next to it: `execute_ir` takes the path of a command script, and with the path
empty every branch the debugger would take is skipped, so a session and a plain
run cannot drift apart.

```sh
# Compile the source to its portable IR bundle, then debug that bundle.
./tools/sxirexec debug <program.sa> <work_dir> <session-file>
./tools/sxirexec debug <program.sa> <work_dir> -        # commands on stdin

# Or debug a bundle that already exists.
./tools/sxirexec debug-bundle <prog.ir> <data.bin> <patch.bin> <session-file>

# Without a target of its own, the tool is built like any other tool:
./sx tool sxirexec
```

`<work_dir>` is where the bundle lands (`prog.ir`, `data.bin`, `patch.bin`).
It is created if missing, and the ELF binary `native_aot` writes on the way is
deleted before anything executes, exactly as `compile-and-run` already does: a
debugging session cannot run a machine binary either.

## A session

The fixture `selfhost/debug_tests/fact.sa` prints `9` (1! + 2! + 3!) and is in
the native subset, so it emits portable IR. This script
(`selfhost/debug_tests/fact.session`) sets a breakpoint on the recursive call
and looks around:

```
break src 0x0001c8
run
where
bt
info
step 3
where
reg SP
delete 89
info
break 89
continue
```

```
$ ./tools/sxirexec debug selfhost/debug_tests/fact.sa /tmp/dbg selfhost/debug_tests/fact.session
sxdbg: at src 0x00004a (ip 0/134, depth 0)
sxdbg: break at ip 89 (src 0x0001c8)
sxdbg: at src 0x0001c8 (ip 89/134, depth 2)
sxdbg: at src 0x0001c8 (ip 89/134, depth 2)
sxdbg: #0 returns to src 0x000255 (ip 123)
sxdbg: #1 returns to src 0x000063 (ip 5)
sxdbg: breakpoints: 89
sxdbg: at src 0x00007a (ip 7/134, depth 3)
sxdbg: at src 0x00007a (ip 7/134, depth 3)
sxdbg: SP = 0x2000ff70 (536936304)
sxdbg: deleted ip 89; 0 breakpoints
sxdbg: no breakpoints
sxdbg: break at ip 89
sxdbg: at src 0x0001c8 (ip 89/134, depth 2)
2
sxdbg: at src 0x0001c8 (ip 89/134, depth 2)
3
2
9
sxdbg: end of program after 365 instructions and 5 stops
```

Every line this debugger writes starts with `sxdbg:`; every other line is the
program's own output, printed where it happened. The last line says how the
session ended and what it cost.

## Where you are

A stop line carries three coordinates:

* **`src 0x0001c8`** — the byte offset `emit_to_ir --source-offsets` recorded for
  this instruction. It is the value `prog.ir` prints itself
  (`; source-offset 0001c8 -> I102`), so a reader of the listing can set a
  breakpoint without counting instructions. `break src <offset>` is the
  coordinate to prefer.
* **`ip 89/134`** — the index of the instruction in the VM's own instruction
  list, which is what `break <n>`, `step` and `next` talk about. It is *not*
  the `I<n>` label in `prog.ir`: the listing also contains the runtime stubs and
  the collector, which the VM executes as builtin calls rather than as
  instructions, so the two numbering schemes are related but not equal.
* **`depth 2`** — how many calls are live, which is the length of the VM's
  return-address stack.

## Commands

| Command | Meaning |
| --- | --- |
| `break src <offset>` | stop before the instruction that carries this source offset |
| `break <ip>` | stop before this instruction index |
| `delete <ip>` / `clear` | drop one breakpoint / all of them |
| `info` | list the breakpoints |
| `step [k]` | retire `k` instructions (default 1) and stop again |
| `next` | run until the current call returns, then stop |
| `continue` (`run`) | run to the next breakpoint |
| `where` | print the current stop line |
| `src` | print the current source offset alone |
| `bt` | the return addresses on the call stack, innermost first |
| `regs` / `reg <name>` | all twenty registers and the flags / one register |
| `mem <addr> [len]` | hex dump `len` bytes (default 16, at most 256) of the VM's memory |
| `help` | the command list |
| `quit` | stop the session, leaving the program where it is |

`regs` prints `A C D B SP BP SI DI R8..R11 BASE R13..R15` then `F0..F3`, the
same names `prog.ir` uses, plus the C/Z/S/P flags.

## How a session is driven

* A session always stops at the first instruction. That is where a script sets
  its breakpoints, before the program has run.
* After that, **one command line is consumed per stop**. If a script wants to
  read state after `step 3`, the following line is read at the instruction it
  stopped on.
* Blank lines and lines starting with `#` are skipped, in a script file and on
  stdin alike.
* On stdin (`-`), an empty line or end of input means "continue", so a session
  can be replayed from a file with `cat` or typed a line at a time.
* When a script runs out, execution continues to the end rather than stopping
  again.

Exit status is 0 for a session that ended normally or on `quit`, 1 for a VM or
emit failure, and 2 for a usage error. A session file that does not exist is an
error (exit 1) rather than a session that quietly runs the program without
stopping.

## What it does not do, and why

The debugger debugs the **portable IR**, so it can show what the VM has:
instructions, source offsets, optional emitted source-line tables, registers,
memory, the call stack, conditional register breakpoints, and program output in
order.

* **Source line table (`SX_LINE_MAP`).** `sxirexec debug` passes
  `SX_LINE_MAP=<work>/lines.map` when emitting the bundle, so `line` (`l`)
  prints the current 1-based source line and text, and `break line <n>` sets a
  breakpoint at the first emitted instruction on or after line `<n>`. Bundles
  built manually without `lines.map` still debug normally by offset or `ip`.
* **Conditional breakpoints (`if <reg> <op> <val>`).** Any `break <ip>`,
  `break src 0x<off>`, or `break line <n>` command accepts an optional
  `if <reg> <op> <val>` suffix (`==`, `!=`, `<`, `<=`, `>`, `>=` over `A..R15`,
  `BASE`, `F0..F3`).
* **No variable names or types.** The portable IR has no debug information:
  what a stack slot means is known to the front end that emitted it, not to the
  VM. `mem`, `reg SP` and the frame base are what the machine offers.
* **No watchpoints, reverse execution or core dumps.**
  Each of those is a feature with its own evidence, not a flag to be added
  quietly.
* **No machine-binary debugging.** The subject is the portable listing, which is
  the point: the run that is debugged is the same run the parity gate compares
  with three other backends.

## Verification

`./sx target test-ir-exec` builds `sxirexec`, then:

* runs `selfhost/debug_tests/fact.session` and compares the transcript byte for
  byte with the reviewed `fact.session.want`;
* pipes `selfhost/debug_tests/stdin.session` into the debugger with `-` and
  compares that transcript with `stdin.session.want`, so the stdin path is
  pinned too, including the `quit` ending;
* runs the same program undebugged and compares the result with a native build,
  which is what makes the program output inside a transcript checkable against
  something the debugger did not produce;
* feeds a session path that does not exist and requires the run to fail, so
  "missing script" cannot silently become "ran it anyway";
* keeps the four 4-way parity cases and the five `native == IR VM` cases that
  were there before the debugger existed.

The transcripts pin the VM's own numbering (`ip 89/134`, `365 instructions`), so
a change in how instructions are counted, or in the IR this fixture emits, shows
up as a diff to review instead of drifting quietly.
