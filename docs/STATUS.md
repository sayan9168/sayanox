# Status

## CI seed restore

```sh
./selfhost/restore_sxc_full.sh
# uses install_sxc_full.py (or .a+.b parts) — never aborts on bad base64
make subset   # SUBSET-SELFHOST-OK
```

Broken `sxc_full_b64_plain` incomplete parts are ignored.

## Working markers
- SUBSET-SELFHOST-OK
- PURE-EMIT-OK
- TRUE-PURE-GEN2-OK (when full compiler_min present)
