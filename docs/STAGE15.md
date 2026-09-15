# Stage 15 — Checked AST and Semantic Boundary

Stage 15 adds a compiler-owned canonical AST arena and deterministic semantic validation for the current minimal source subset.

Pipeline boundary:

`source -> parser boundary -> canonical AST arena -> semantic checks -> IR`

The checked fixture models `hold answer = 40 + 2` followed by `show answer`. It validates assignment shape, binary expression operands, and name resolution before the IR/backend stages.

Run:

```bash
bash selfhost/stage15_checked_pipeline.sh
```

This is an incremental self-hosting milestone; the Rust implementation remains the bootstrap implementation. The next major step is replacing the fixture node construction with nodes produced directly by the existing self-hosted parser.
