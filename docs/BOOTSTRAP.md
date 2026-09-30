# Sayanox bootstrap

Canonical entry (no bash/Python critical path):

    make true-selfhost

This is the pure-min seed bootstrap: sxc_seed_min.c -> gen1_min -> gen2.

Verification commands:

    make true-selfhost    # TRUE-SELFHOST-MIN-OK
    make native-test      # NATIVE-TEST-OK
    make gen3             # GEN3-OK; byte identity is reported, not required

Optional paths:

| Command | Role |
|---|---|
| make true-selfhost-full | Optional 44KB full C seed path |
| make seed-min-gen1 | Build gen1 from the min seed |
| make gen3 | Behavioural gen3 tests; gen3->gen4 byte identity is informational only |
| make native-test | Real x86-64 AOT executable tests |

The repository does not claim full-language self-hosting here. The canonical path covers the pure-min bootstrap only.

A C seed remains necessary as the initial executable compiler.
