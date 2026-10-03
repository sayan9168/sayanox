# Pure Sayanox compiler (`compiler_min.sa`)

Compiles the **pure-min** dialect and is written only in Sayanox:

```
hold / show / when / while / otherwise | else
make / give (top level, numeric, recursion)
lists: [..], xs[i], len(xs), push(xs, v)
structs: numeric fields, Point { x: 3, y: 4 }, p.x
%  (* / + -), string concat/len/chr/index/read_file/write_file/arg/arg_count
use "file.sa"   (splice, depth <= 8, missing file = hard error)
```

Chain:

```
seed-min (C)  ->  compiler_min.sa  ->  gen1_min
gen1_min      ->  compiler_min.sa  ->  gen2
gen2          ->  compiler_min.sa  ->  gen3      (gen3 == gen4, byte-identical)
```

```sh
make true-selfhost   # TRUE-SELFHOST-MIN-OK
make gen3            # GEN3-OK
```

Boundaries (see docs/STATUS.md): a `hold` RHS takes one binary operand,
`when`/`while` conditions are copied verbatim, struct fields are numeric only,
modules are plain splicing without namespaces.
