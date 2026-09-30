# Status

## Canonical entry

    make true-selfhost

The canonical path is pure-min self-hosting, not full-language self-hosting:

    sxc_seed_min.c -> gen1_min -> gen2

### Verification targets

| Target | Expected marker | Scope |
|---|---|---|
| make true-selfhost | TRUE-SELFHOST-MIN-OK | Preferred pure-min bootstrap |
| make native-test | NATIVE-TEST-OK | Real x86-64 AOT tests |
| make gen3 | GEN3-OK | Behavioural compiler regeneration tests |

gen3 reports whether gen3 and gen4 are byte-identical, but byte identity is not required.

### Bootstrap artifacts

selfhost/compiler_min.sa is the canonical quiet pure-min compiler source. Its gzip/base64 restore parts are complete concatenated chunks; make restore-compiler also removes legacy debug show lines and normalizes condition emission to crepl.

### Native backend

selfhost/native_aot.c emits real x86-64 ELF code. Variable slots are mapped across the first 26 letters (a-z), and integer show uses signed decimal output.

### Boundaries

- The preferred bootstrap is seed-min, not the full language.
- true-selfhost-full remains optional.
- No full-language self-host claim is made.
- No byte-identical gen3->gen4 claim is made unless cmp actually passes.

Final verification status is recorded after the clean-clone/CI verification run.
