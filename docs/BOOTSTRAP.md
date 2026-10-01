# Sayanox bootstrap

Canonical entry (no bash/Python critical path):

    make true-selfhost

This is the pure-min seed bootstrap: `sxc_seed_min.c` -> gen1_min -> gen2.

Verification commands:

    make true-selfhost    # TRUE-SELFHOST-MIN-OK
    make native-test      # NATIVE-TEST-OK
    make gen3             # GEN3-OK; requires byte-identical gen3 == gen4

## Paths

| Command | Role |
|---|---|
| `make true-selfhost` | Canonical pure-min bootstrap |
| `make true-selfhost-full` | Optional larger C seed path |
| `make seed-min-gen1` | Build gen1 from the min seed |
| `make gen3` | Behavioural tests + **required** gen3==gen4 byte identity |
| `make native-test` | Real x86-64 AOT executable tests |

## Source

`selfhost/compiler_min.sa` is restored offline from `selfhost/compiler_min_gz/*.b64`
(`base64` + `gzip` only).

## Scope

The repository does not claim full-language self-hosting here.
The canonical path covers the pure-min bootstrap only.
A C seed remains necessary as the initial executable compiler.
