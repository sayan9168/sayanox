# Stage-2 source parts

Concatenate in order to rebuild `stage2_template.c`:

```bash
cat selfhost/stage2_src/01_front.c selfhost/stage2_src/02_back.c > selfhost/stage2_template.c
clang -o selfhost/stage2 selfhost/stage2_template.c
```

The supported repository-level equivalent is:

```bash
make stage2
```

or:

```bash
./selfhost/restore_stage2.sh
```
