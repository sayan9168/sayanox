# Stage-10 — Checked AST Lowering and Canonical IR

> **The entry points named in this file do not exist (verified 2026-10-13).**
> There is no `make stage2` target, and no `selfhost/bootstrap_production.sh`,
> `bootstrap_full_selfhost.sh` or `bootstrap_full_language_selfhost.sh`.
> `selfhost/stage2_template.c` is a 93-byte placeholder, `selfhost/stage2_src/`
> holds a README and an 11-byte placeholder, `selfhost/sxc_full.c` is a 30-line
> toy, and `bash selfhost/restore_stage2.sh` exits 1 with
> `error: missing Stage-2 seed`. The supported path is
> `make doctor && make true-selfhost && make gen3 && make native-test`;
> `docs/FULL_LANGUAGE_SELFHOST.md` says what actually runs and
> `make test-doc-claims` keeps this banner honest.

Stage-10 is a historical self-hosting milestone. The numbered shell driver has been retired.

Supported build path:

```bash
make stage2
bash selfhost/bootstrap_production.sh
```

The Sayanox lowering sources remain in the repository for compiler development. Numbered `stage*.sh` scripts are not supported entry points.
