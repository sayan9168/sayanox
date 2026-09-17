# What is complete

- Stage-2 path restored when template is PLACEHOLDER (`build_stage2.c`)
- Production bootstrap + multi-var codegen
- Struct/list codegen demos + test script
- LSP stdio diagnostics (braces, hold without `=`, keyword typos)
- sxpkg local registry, search, optional `REGISTRY_URL`
- Legacy numbered stage/step shell scripts removed
- CI: stage2, production, struct/list, examples

## Still open

- Native backend (no clang)
- Full struct field generality in all programs via codegen only
- Remote package hosting (beyond URL index)
