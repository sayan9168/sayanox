# Stage-2 source parts

Concatenate in order to rebuild `stage2_template.c`:

```bash
cat selfhost/stage2_src/01_front.c selfhost/stage2_src/02_back.c > selfhost/stage2_template.c
clang -o selfhost/stage2 selfhost/stage2_template.c
```

Or run `./selfhost/bootstrap_selfhost.sh` which does this automatically.
