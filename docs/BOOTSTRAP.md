# Sayanox bootstrap

Canonical entry (no bash/Python critical path):

    ./sx target true-selfhost

The current bootstrap is native anchor -> Sayanox seed/frontend -> generated C gen1_min -> gen2. The final C seed is retired; later host C invocations compile generated output, not maintained C source. See [native bootstrap](NATIVE_BOOTSTRAP.md).

Verification commands:

    ./sx target true-selfhost    # TRUE-SELFHOST-MIN-OK
    ./sx target native-test      # NATIVE-TEST-OK
    ./sx target gen3             # GEN3-OK; requires byte-identical gen3 == gen4

## Paths

| Command | Role |
|---|---|
| `./sx target true-selfhost` | Canonical pure-min bootstrap and feature/tool tests |
| `./sx target true-selfhost-full` | Runs minimum/gen3 readiness then refuses an unreviewed full-language claim |
| `./sx target gen1` / `./sx target seed-min-gen1` | Build gen1-min from the maintained min seed |
| `./sx target gen2` | Build the maintained gen2 through gen1-min |
| `./sx target tools` | Build the Sayanox formatter and local package-lock tool |
| `./sx target gen3` | Behavioural tests + **required** gen3==gen4 byte identity |
| `./sx target native-test` | Real x86-64 AOT executable tests |

## Source

`selfhost/compiler_min.sa` is restored offline from `selfhost/compiler_min_gz/*.b64`
(Sayanox Base64 codec embedded in root `sx` plus gzip; no compiler/packer binary or Python required):

    ./sx target restore-compiler     # decode the blobs -> selfhost/compiler_min.sa
    ./sx target pack-compiler        # regenerate the blobs from compiler_min.sa

`pack-compiler` runs the Sayanox packer (gzip -9 -n as a leaf compressor,
Sayanox Base64 codec, 1100-character parts) and verifies the round trip byte-for-byte.

## Scope

The repository does not claim full-language self-hosting here.
The canonical path covers the pure-min bootstrap only.
The initial executable compiler is the explicit pinned native Sayanox anchor, not maintained C source.
