# Seed collector fake-stack root reliability — 2026-10-30

## Accepted implementation checkpoint

Implementation: `83a074039b36077e2ff0f9da57707b4891a1c89a`,
[PR #50](https://github.com/sayan9168/sayanox/pull/50).
[CI run 41052510070](https://github.com/sayan9168/sayanox/actions/runs/41052510070)
completed successfully in both required jobs, including each unchanged final
forbidden-invocation audit. `Complete original acceptance` executes the full
`./sx ci` chain, not a reduced gate set. These conclusions were checked through
the jobs API. Earlier green main CI was not counted as acceptance of this code.

This record and its STATUS/GC links are subsequent documentation only; their
new PR CI and post-merge integration results are recorded separately in PR #50.
The implementation and pinned source manifests below remain unchanged.

```text
59a9b8686153ad6b5d3e0f3eaaed47877c8d337b8eead27f252ac1dddc2bd933  selfhost/seed/seed_runtime_lib.sa
2995c4565fbe78473d0fa2f992ffc779ef8836ca2d9c8b32e97ab4e75adf4a7b  tools/sxseed_roots_lib.sa
2bd930fc0a5a202c909c08ad9d169f0da8196c4ef7beb40c701d8b17ba0decfe  tools/sxseed_metadata_lib.sa
93740e76fcfe72569c54dcce460dbfed57a77c840bacd383f00e30a0facafebc  docs/full-language-v1.sha256
1f06c981a1a386f176d6cc9e888654abf52af7b0af8b2b52777dc808a0420a24  bootstrap/sx.sha256
```

## Reproduction and negative control

The previous seed runtime (main `93fc892`, runtime source digest
`e02ac85c9f19bfd56b462234e3b3846d8a06ea98c904c4de76541b3f0be43f2d`)
used the apparent `jmp_buf`/anchor address interval for root discovery. Under
ASan fake-stack mode, different fake-stack frame sizes can lie outside that
interval even though they belong to active caller frames.

The new Sayanox-generated actual-runtime probe uses an 8 KiB address-taken
frame, volatile local aliases, an interior-only string root and a cycle with
a transitive child string. A small-frame draft passed on the old collector
by accident; increasing the frame exposed the missed-root bug. With
`detect_stack_use_after_return=1`, the old runtime failed the live-root
assertion. That failure, not the small-frame draft, is the regression evidence.

The fixed four-mode probe passes. Removing only the live fake-frame scan from
the fixed emitted fixture causes ASan **heap-use-after-free** on the interior
string, with collection identified as its freeing call. This establishes that
the probe needs actual root discovery, not merely a particular absolute free
count. A failed draft helper compilation was not counted as a negative-control
success; the final control compiled and ASan diagnosed the actual memory fault.

Local generated artifacts are ignored, not maintained C source:
`selfhost/seed_tests/seed-roots-before.log`, `seed-stack-roots-before.c`,
`seed-roots-negative.log` and `seed-stack-roots-no-fake.c`.

## Sayanox implementation

`selfhost/seed/seed_runtime_lib.sa` remains the maintained runtime generator.
It now:

1. Maps an ASan fake-stack anchor to its corresponding real frame.
2. Scans the saved register buffer separately from the real stack.
3. Starts the real scan at `__builtin_alloca(0)`, including prologue register
   spills rather than stopping at the frame pointer.
4. Uses the public ASan fake-stack interface to discover referenced live fake
   frames within the active real stack range.
5. Retains instrumentation on actual loads and skips poisoned words.

Stack discovery is separate from heap tracing. Strings and numeric buffers
remain leaves; generic pointer-bearing payloads retain their transitive edges
and cycles. Allocation policies, metadata trimming/failure handling and public
GC counters are unchanged. No root is pinned in a global test variable.

## Required regression gates

The existing `test-seed-collector` gate now requires:

- `tools/sxseed_roots_lib.sa`: aliases, interior-only roots, cycles and child
  strings across repeated collections and unrelated allocations.
- The existing metadata/failure/empty-release/regrowth/numeric-leaf probe,
  with all its prior assertions intact.

Both run O0, O2, the existing O2 ASan+UBSan mode, and an additional O2
ASan+UBSan mode forcing fake-stack use. Existing flags/options were not removed
or weakened. The new mandatory helper and seed runtime are protected by the
full-language source manifest; nested entry pins were refreshed in dependency
order, without changing the reviewed normative language contract or oracles.

## Local and remote verification

The following official local gates completed successfully under the same-shell
CI guard setup:

```text
./sx verify-entry
./sx target test-seed-collector test-gc test-seed-sanitize doctor test-driver
```

The sanitizer target retained its six fixtures and active-ASan negative control.
The independently regenerated four-mode focused root probe and combined
Sayanox gate build also passed. Source-manifest and whitespace checks passed.

A separate guarded local `./sx ci` repeat was still running when this record
was written. Its final exit status and guard audit are not inferred here.
The completed remote full `./sx ci` and both final audits on the implementation
checkpoint are actual acceptance, not a claim that every local process had
already finished. Subsequent results are attached to PR #50.

## Explicit limits

All maintained implementation and test-generator code added by this slice is
Sayanox. Generated C is retained C-output compatibility/runtime testing, not a
restored C seed or a shell-recipe migration. Existing host C/POSIX/sanitizer
boundaries remain; no Python/Node gate requirement or network bootstrap is
introduced.

This is a seed root-reliability fix, not precise GC, elimination of conservative
false roots, arbitrary-program bounded-live-heap/RSS proof or leak-free
execution. Leak detection remains disabled as in the existing gate. It does
not establish independent bootstrap provenance or full native-backend parity.
