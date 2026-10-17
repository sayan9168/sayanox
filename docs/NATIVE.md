# Native AOT status

## Current implementation

Sayanox currently has a self-contained Linux x86-64 native AOT seed in `selfhost/native_aot.c`.

The path is:

```text
.sa -> native collection/kind passes -> recursive emit walk -> x86-64 Linux ELF
```

The emitted program does not require a generated C file or a second compiler.

The maintained native source (`selfhost/native_aot.c`, canonical and self-contained) covers the pure-min subset: `hold`, `show`, IEEE-double numeric expressions (`+ - * / %`, comparisons, parentheses), `when` / `else` / `otherwise`, `while`, lists, strings with the `concat`/`len`/`chr`/`string_eq`/`sx_index` builtins, structs including nested ones and typed copies, `use "file.sa"` module splice (depth <= 8), and top-level `make`/`give` functions with recursion (typed scalar/list functions and checked function-local holds; see the current tests). Anything else is a hard error with a clear message — see [`docs/STATUS.md`](STATUS.md) for the exact boundaries. The files under `selfhost/native_src/` are historical fragments, not a split of the current source.

## Cranelift status

Cranelift is **not the active native backend**. The repository's current direction removed the Cranelift dependency to keep the bootstrap path small.

The active native backend emits Linux x86-64 machine code directly. `docs/CRANELIFT.md` is historical/status information, not a build requirement.

## Current IR boundary

There is no IR in the SSA sense, and no intermediate program representation at
all: `selfhost/native_aot.c` is a single-pass compiler whose recursive-descent
parser emits machine code as it walks the source. The five functions this
section used to name — `parse_prim`, `parse_term`, `parse_expr`, `estmt`,
`eblk` — do not exist in the file (corrected 2026-10-13). The emit tree is
`emit_prim` → `emit_post` → `emit_term` → `emit_rel` → `emit_expr`, driven by
`emit_prog` (statements) and `emit_fn` (function bodies). Kind inference is a
separate earlier pass (`phase 2`, no codegen), so an expression's operand kinds
are known before any byte is written, but nothing is materialised as a tree or
an instruction list.

The two compilation paths are:

- **Native:** `.sa -> phases (use expansion, statement skipping, definition
  collection, kind inference) -> emit tree -> x86-64 machine code -> ELF`
- **C fallback:** `.sa -> generated .c -> cc -> executable`

No generated `.c` is required by the native backend.

## The emit seam (2026-10-13)

A second target would not be a new file, and none is claimed: `native_aot.c`
parses and emits in the same walk. What exists now is a **seam** — the
machine-specific half of the file is delimited and named, and the language half
provably does not touch it. `make test-native-emit-split` (part of
`native-test`) asserts every row of this table:

| Region | Where | What it is |
|---|---|---|
| `==== x86-64 mini encoder ====` | above `phase 1: collect definitions` | the only code that writes bytes: `e1`/`e32`/`e64`, `here()`, `erel32`/`erel32j`, `patch_imm32`, `jmp5_slot`, `sub_rsp_imm32_slot`, `leave_ret`, the instruction helpers (`mv_m64`, `mv_r64m`, `mv_rr`, `lea_rm`, `mov_imm64`, `mov_imm8m`, `push_r`, `pop_r`, `sse_rr`, `call_p`, `emit_d2i`, `emit_i2d`, `movq_xr`, `movq_rx`, `cvttsd2si`, `cvtsi2sd`, `rexb`, `emit_modrm`) and the `jl_*` label lists |
| phases 1–2 | | `use` expansion, statement skipping, definition collection, kind inference — no codegen |
| `EMIT-SEAM-BEGIN` … `EMIT-SEAM-END` | 1332 lines | the language-level emitter: the emit tree, statement/block/function emission, conditions and loops. No `e1(`/`e32(`/`e64(`, no `memcpy` into `code`, and no direct read of the code cursor `cn`; label positions come from `here()` |
| phase 4, collector, ELF | below `EMIT-SEAM-END` | the runtime stubs (number formatting, list and string builtins, file and http syscalls), the mark & sweep collector and the ELF container — machine code by nature |

A replacement backend would need its own encoder, phase-4 stubs, collector
and container, plus an ABI-aware adaptation of the emit walk; merely replacing
byte encodings is insufficient. It inherits two contracts the emit tree assumes, which are the
honest reason this is a seam and not a portable IR: the System V AMD64 calling
convention (`rax`/`xmm0` returns, the frame that `sub_rsp_imm32_slot` opens and
`leave_ret` closes) and the collector's block layout (`BH_HDR`, the `BK_*`
kinds).

Before the seam, the emit tree wrote six byte sequences itself — the function
prologue and its later immediate patch, `leave; ret` twice, a `jmp rel32` slot,
and a hand-rolled rel32 patch that duplicated `erel32j` — and read `cn` in 28
places. Those are now named primitives. The refactor was verified byte for byte:
`native_strord_test`, `native_cond_test`, `stdlib_growth_test`,
`examples/native_hello`, `gen2_index_expr_test` and `generic_struct_concrete`
all emit executables that `cmp` clean against the binaries produced by the
pre-seam `native_aot`, and the build lost its last warning (a `return <value>`
inside the void `emit_prim`; the identical line inside the int-returning
`pk_prim` was deliberately left alone).

### The instruction list, recorded

The seam says *how* the emitter reaches the machine; `SX_EMIT_LOG` says *what it
asks for*. With `SX_EMIT_LOG=/tmp/x.log` in the environment every encoder
primitive writes one line — the code offset, the mnemonic and the operands in
assembly order — plus a `;` line for each label slot, each fixup, each emitted
`make` and each phase:

```sh
SX_EMIT_LOG=/tmp/hello.log ./selfhost/native_aot examples/native_hello.sa /tmp/hello
```

That file is the instruction list the emit tree produces, and it is the concrete
thing a second backend is written against. The recorder only reads the
primitives' arguments, so the emitted ELF is byte-identical with and without it.
`make test-native-ir-log` (part of `native-test`) pins the list for
`selfhost/native_ir_log_test.sa` and cmp's both binaries;
[NATIVE_IR.md](NATIVE_IR.md) documents the format, the value model it exposes
and what the recorder is *not* — there is still one emitter of machine code here,
not two.

## Build and run

Build the native compiler seed once:

```sh
make native
```

Compile and run a native program:

```sh
./selfhost/native_aot examples/native_hello.sa /tmp/sayanox_native_hello
/tmp/sayanox_native_hello
```

Expected output:

```text
42
```

There is no `bootstrap-native` Makefile target; use `make native`.

## Unified driver

`selfhost/sx_driver.c` supports explicit backend selection:

```sh
./selfhost/sx --backend=native -o out examples/native_hello.sa
./out

./selfhost/sx --backend=c -o out examples/native_hello.sa
./out
```

`--backend=c` remains the compatibility fallback for programs outside the native subset. `--backend=auto` prefers the native compiler when available and otherwise uses the C route.

## Limitations

The native backend is a subset compiler; there is no complete Stage-2 host
in this repository to replace. Native support must not be assumed for every `.sa` construct.

When native lowering cannot safely support a program, use:

```sh
./selfhost/sx --backend=c -o out program.sa
```

The native backend is currently Linux x86-64 specific.

## Bootstrap impact

The native compiler is separate from the pure `gen1` subset path. Native AOT changes must not alter the `.sa -> gen1 -> subset` bootstrap chain.

The C source is used only to build the native compiler executable itself:

```text
clang -> native_aot -> .sa -> ELF
```

User programs compiled by `native_aot` do not pass through clang.

## Second-ISA decision and IR audit (2026-10-16)

**No executable second ISA is implemented or claimed.** Native compilation and
`native-test` remain x86-64 Linux only. The C fallback's host portability does
not establish a second direct-to-ELF backend. There is no aarch64 execution
smoke gate in this repository.

The bounded improvement here is analysis tooling: the existing C99 streaming
`emit_to_ir` translator now has strict record/offset auditing and optional
source-byte-offset correlation comments. Its default output stays compatible.
The native gate compares both audit runs, checks their correlation counts and
compares the default listing with the audit listing minus added comments.
This does not modify code emission or define executable IR. In particular,
abstract registers collapse x86 widths and preserve ABI/layout assumptions.
See [NATIVE_IR.md](NATIVE_IR.md#strict-log-audit-and-source-offset-correlation-2026-10-16)
for precise acceptance rules, tests and non-claims. No interpreter or network
dependency was added.
