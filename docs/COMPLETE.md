# Sayanox project status

## Accepted milestone, not universal language completion

All maintained implementation source is Sayanox: compiler/frontends, runtime
and backend implementations, build/bootstrap/recovery/cleanup logic, tools,
CI guards and test orchestration. The Makefile, maintained C seed and maintained
shell scripts are retired. Generated C compatibility output and necessary host
tools remain supported. The pinned native anchor and generated entry are
**explicit binary trust inputs**, not an independent trust proof.

Published-language v1 **C-output self-hosting is accepted**. The implementation
uses a pure-min bootstrap dialect; that does not restrict accepted user programs
to pure-min. The required 19-clause/43-builtin inventory, gen2/gen3 O0/O2 ledger,
builtin signature/runtime/import boundaries, negative controls, bootstrap
budget/recovery and gen3/gen4 fixed point belong to the full acceptance chain.
See [STATUS](STATUS.md), the [normative profile](FULL_LANGUAGE_PROFILE_V1.md)
and [contract](FULL_LANGUAGE_CONTRACT_V1.md), not historical demo grammars.

Checkpoint `0fca5622713db82df308f8f77d9589b414c1a901` has completed
[main CI](https://github.com/sayan9168/sayanox/actions/runs/41162923167): both
required jobs and both final guard audits succeeded. This historical checkpoint
is evidence for its exact tree, not advance acceptance of subsequent changes.

## Supported paths

```sh
./sx verify-entry
./sx target test-native-bootstrap
./sx target true-selfhost
./sx target gen3
./sx target true-selfhost-full
./sx target all-sayanox
./sx ci
```

- `true-selfhost`: reproducible pure-min bootstrap and shared-dialect tests.
- `gen3`: source-built gen3/gen4 compiler-output equality.
- `true-selfhost-full`: complete pinned published-language v1 C-output contract;
  no reduced-success fallback or replacement by source registration.
- `all-sayanox`: maintained-source and explicit anchor audit, not a substitute
  for full language conformance or CI.
- `ci`: complete original acceptance chain, including full published acceptance.

The x86-64 native AOT compiler is `selfhost/native_aot.sa`; it supports more than
`tools/native32.sa`, but is still a documented subset compiler. The multi-ISA
compiler emits i386/AArch64/RV64IM for bounded integer/string operations,
including static spans, literal/variable byte lengths, checked byte indexing and
bounded concat. Emulator FP/file-syscall probes do not imply compiler lowering.

## Still open

Independent bootstrap trust, full native backend parity, precise GC/stronger
memory contracts, deeper standard library and package infrastructure,
IDE-complete tooling, language-level namespaces and broader platforms remain
open. Conservative GC already exists; it is not a missing collector. Numeric
lists and deliberately refused future type forms are not promises of arbitrary
container types. See [remaining work and acceptance criteria](REMAINING_WORK.md).

Historical C-seed, missing-collector and Makefile descriptions in dated logs
are not the current milestone. The source of truth for exact feature boundaries
and accepted checkpoints remains [STATUS](STATUS.md).
