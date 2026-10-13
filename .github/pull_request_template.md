## Summary

Briefly describe what this PR does and why.

## Type of change

- [ ] Bug fix
- [ ] New feature / language or compiler change
- [ ] Tests only
- [ ] Documentation
- [ ] Tooling / CI / Makefile
- [ ] Other (describe)

## Checklist

- [ ] I ran `make doctor` and it printed `DOCTOR-OK`
- [ ] If this touches the compiler, seed, native, or bootstrap path, I ran:
  - [ ] `make true-selfhost`
  - [ ] `make gen3`
  - [ ] `make native-test` (x86-64 Linux only)
- [ ] New behavior has tests or an existing gate covers it
- [ ] Docs updated if behavior or status claims changed (`docs/STATUS.md` when relevant)
- [ ] I did not map `*.sa` to another language for GitHub stats
- [ ] License remains Sayanox License v1.1; I did not reintroduce MIT-only claims for the language tree

## Test plan

How did you verify this? Paste commands and key output lines (not full logs unless asked).

```sh
# example
make doctor
# make true-selfhost
```

## Notes for reviewers

Anything risky, temporary, or intentionally incomplete?
