# Status

## Self-host (Stage-3) — COMPLETE for vertical slice
```sh
make selfhost
# SELFHOST-OK
```
- `selfhost/sxc.sa` written in **Sayanox**
- Bootstrap: stage2 lowers sxc → binary once
- sxc compiles `hello.sa` → C → runs as **42**

## Native AOT
- for / for-in / elif / break / continue
- read / abs / pow / contains / startswith / repeat
- is_str / is_num / substr / string== / min max exit
- gc / gc_step / export / modules

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
