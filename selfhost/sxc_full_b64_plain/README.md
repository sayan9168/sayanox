# Plain base64 sxc_full seed (NO gzip)

Reassemble:

```sh
cat selfhost/sxc_full_b64_plain/p*.txt | tr -d '\n' | base64 -d > selfhost/sxc_full.c
grep -q sx_chr selfhost/sxc_full.c
# must be > 10000 bytes
```

Or use `./selfhost/restore_sxc_full.sh`

Do **not** use the old gzip `sxc_full_b64/` directory.
