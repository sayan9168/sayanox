# native_src

Historical fragments of an earlier split of the native backend. They do
**not** assemble into the current `selfhost/native_aot.c` (the full part set
was never checked in; only `05.cpart` and `c08.part` remain).

The canonical, self-contained source is `selfhost/native_aot.c`. Build it
with:

```sh
make native        # cc -O2 -o selfhost/native_aot selfhost/native_aot.c
make native-test   # full backend test battery
```

Do not overwrite `selfhost/native_aot.c` from these parts.
