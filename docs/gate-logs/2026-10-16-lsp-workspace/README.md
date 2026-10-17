# Bounded LSP workspace snapshot — 2026-10-16

Actual combined stdout/stderr from one successful `&&` chain:

1. `make test-lsp test-lsp-robust` (`suite.log`)
2. `make doctor`
3. `make true-selfhost`
4. `make gen3`
5. `make native-test`

The chain exited 0. Gen3 and gen4 were byte-identical. The LSP suite runs
existing protocol/Unicode/four-buffer probes plus the new in-tree framed C
client against never-opened disk files, a space-containing workspace/subfolder,
open overlays, disk mutation/deletion with response handshakes, first
workspaceFolder, invalid/nonlocal roots, symlink/hidden/oversized exclusion,
and the enforced 128-file cap. No sleeps, interpreter, shell-spawned indexer,
network or DNS are involved.

`binding-refusal.log` records an EXPECTED failed build-binding probe: a synthetic
generated fallback returning `changed` instead of the required empty string
was rejected by the AWK binding. This is not a failed final bootstrap gate.

The initial focused client build had a test-only snprintf truncation warning;
its path handling was tightened before these final suite/gate runs. The final
suite contains no compiler warnings. No semantic reference engine, persistent
incremental database, workspace rename or IDE-complete claim is made.
