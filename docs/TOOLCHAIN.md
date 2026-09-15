# Sayanox toolchain

Build and run with **shell + C + optional Rust host** only.

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
./tools/sxfmt.sh examples/hello.sa
./tools/sxpkg init
```

No third-party scripting languages are required for the core path.
