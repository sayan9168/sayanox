# Dependency audit — 2026-10-15

## Maintained contract

Bootstrap uses **make + a C99-capable C toolchain + POSIX shell/utilities**.
No Python, Node, Ruby or Perl is required by `doctor`, `true-selfhost`, `gen3`
or `native-test`. No bootstrap step requires network access. The license
remains Sayanox License v1.1.

| Path | Requirements / boundary |
|---|---|
| seed-min → gen1-min → gen2 | make, C compiler (including its assembler/linker), POSIX shell and utilities |
| gen2 → gen3 → gen4 | same; `cmp` checks the C fixed point |
| native-test | same, on **x86-64 Linux** (generated ELF uses Linux syscalls) |
| portable analysis listing | `tools/emit_to_ir.c`, built with C99; not a second backend |
| source-present restore | local marker checks with `grep`, no decoding/network |
| missing-source restore | additionally `base64`, `gzip`, `cat`, `tr`, `rm`; checked-in offline bundle |
| optional `test-network` / HTTP / crawler tests | Python test server and curl; explicitly excluded from bootstrap |
| maintenance `pack-compiler` | optional Bash/compression utilities; not run by bootstrap |
| package/LSP tools | .sa programs compiled through gen2, POSIX shell wrappers/tests |
| explicit remote package transfer | optional curl/wget, online opt-in; not needed by bootstrap or local package tests |

`grep`, `cmp`, `mkdir` are core checks. The expanded feature gates also use
POSIX utilities such as `awk`, `cat`, `chmod`, `cp`, `cut`, `diff`, `dirname`,
`find`, `head`, `rm`, `sed`, `sort`, `tr`, `wc`. These are not a new language
runtime requirement. Doctor checks the core set, not an exhaustive execution
trace of every optional test recipe. Its success is **not** a minimal-PATH
proof. On a bare system, install the usual POSIX utilities alongside make/cc.

## Dependency regression corrected

PR #26's `native-test` reached `python3 tools/emit_to_ir.py` through
`test-native-ir-portable`. Its green gate on this host did **not** establish
Python independence, and the old doctor message/document claim was too broad.
The audit also found `true-selfhost` invoked Python HTTP/crawler tests. Those
remain available via `make test-network`, not as bootstrap prerequisites.
Package tests now use local copies and a checked transport stub, not real DNS
or network transfers.

The translator is replaced with streaming C99; the Python file is removed.
`make test-emit-to-ir` exercises it without an interpreter. Unknown log lines
are preserved as comments; read/write errors fail rather than printing PASS.

The older 2026-10-04–07 command-count and 400 MB measurements described older
commits, not this expanded compiler/test suite. They are not current claims.
In particular, “no shell script on the critical path”, “only three utilities”
and “all test-* targets measured interpreter-free” were stale. Historical
verification output remains in `docs/logs/`; consult its dated README.

## Reproduce

```sh
make doctor
make true-selfhost
make gen3
make native-test
```

The 2026-10-15 dependency-stage run uses a PATH prefix whose `python`,
`python3`, `node`, `ruby`, `perl`, `curl`, `wget` commands fail loudly and log
any invocation. All four targets must exit 0, and the invocation log must be
empty. Package opt-in legs intentionally shadow curl with a POSIX-shell
failing test stub (they assert its marker). Thus no real network client or
blocked interpreter was executed; this is not a claim that
every possible optional test/environment is covered. Actual output is kept
in `docs/logs/ten-deps-*.log`; subsequent final runs are `ten-final-*.log`.

Compiler-source recovery remains offline. After changing compiler_min.sa,
regenerate its checked-in bundle with `make pack-compiler` and verify a
byte-identical decode; a source-present gate alone does not check bundle sync.
