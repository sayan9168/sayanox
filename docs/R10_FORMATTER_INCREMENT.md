# R10 formatter increment: fail closed on malformed delimiters

`tools/sxfmt.sa` now refuses unterminated quoted strings and structurally
unbalanced braces before writing the destination. A close brace must have an
open brace earlier in the source; unclosed blocks and strings at EOF are errors.
The formatter leaves an existing output file untouched on refusal.

The existing successful formatting contract, token preservation, comment/string
handling, final newline, and idempotence remain intact. `test-sxfmt` now includes
real CLI regressions for an unclosed block, an unmatched close brace, and an
unterminated string, and checks that each refusal preserves a sentinel output.

This is a bounded R10 slice, **not** a completed syntax-aware formatter: token
spacing/configuration and a full parser-backed syntax validation remain open.
Run `./sx target test-sxfmt` and the full guarded `./sx ci` before considering
this increment accepted. No test result is claimed by this documentation.
