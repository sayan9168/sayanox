# Sayanox bootstrap Makefile — sole entry point
# Preferred: make true-selfhost (seed-min -> gen1-min -> gen2). Optional: native, gen3; full is not yet implemented

# Pin the C locale across every recipe and sub-make so C compiler diagnostics
# (GCC quotes identifiers as UTF-8 curly quotes under LANG=C.UTF-8), sort order
# and character ranges behave identically on runner images and local shells.
export LC_ALL := C

CC ?= $(shell command -v clang >/dev/null 2>&1 && echo clang || (command -v gcc >/dev/null 2>&1 && echo gcc || echo cc))

SEED_SA  := selfhost/seed/sxc_seed.sa
SEED_BIN := selfhost/seed/sxc_seed
SEED_MIN_C   := selfhost/seed/sxc_seed_min.c
SEED_MIN_BIN := selfhost/seed/sxc_seed_min
SXC_NATIVE_SA := tools/sxc_native.sa
SXC_NATIVE_LIBS := tools/sxenc_lib.sa tools/sxinfer_lib.sa tools/sxdata_lib.sa tools/sxemit_lib.sa tools/sxruntime_lib.sa tools/sxgc_lib.sa tools/sxlink_lib.sa tools/sxpipeline_lib.sa tools/sxmod_lib.sa
SXC_NATIVE_BIN := tools/sxc_native
NATIVE_SRC := selfhost/native_aot.sa
NATIVE_LIBS := tools/sxenc_lib.sa tools/sxinfer_lib.sa tools/sxdata_lib.sa tools/sxemit_lib.sa tools/sxruntime_lib.sa tools/sxgc_lib.sa tools/sxlink_lib.sa tools/sxpipeline_lib.sa
NATIVE_BIN := selfhost/native_aot
MIN_SA   := selfhost/compiler_min.sa
MIN_MODULE := selfhost/modules/compiler_text.sa
MIN_MODULE_BLOB := selfhost/modules/compiler_text.sa.gz.b64
GEN1_C   := selfhost/gen1.c
GEN1     := selfhost/gen1
GEN1_MIN_C := selfhost/gen1_min.c
GEN1_MIN   := selfhost/gen1_min
GEN2_C   := selfhost/gen2.c
GEN2     := selfhost/gen2
GEN3_C   := selfhost/gen3.c
GEN3     := selfhost/gen3
BOOT_SA  := selfhost/compiler_boot.sa
TESTS    := selfhost/seed_tests
SXFMT_C  := tools/sxfmt.c
SXFMT_BIN := tools/sxfmt
SXPKG_C  := tools/sxpkg.c
SXPKG_BIN := tools/sxpkg
LSP_C    := tools/sayanox_lsp.c
LSP_BIN  := tools/sayanox_lsp
SXDIAG_SA  := tools/sxdiag.sa
SXDIAG_C   := tools/sxdiag.c
SXDIAG_BIN := tools/sxdiag

.PHONY: all subset seed gen1 gen2 test true-selfhost true-selfhost-min true-selfhost-full selfhost \
        native native-test seed-min seed-min-gen1 gen3 clean restore-compiler fix-seed verify-seed \
        seed-bin doctor tools sxfmt test-sxfmt sxpkg test-sxpkg test-sxpkg-wrapper \
        test-reassign test-while test-when test-mod test-struct2 test-list2 test-use \
        test-boot test-fn test-fn2 test-list test-struct test-parity test-chain test-condmod test-user test-nest test-prec test-float test-parens test-push-stmt test-full-lang test-native-num test-native-io test-native-mem \
        test-for-str test-seed-for-untyped test-seed-for-fields test-gen2-gaps test-registry-sums test-stdlib test-pkgs test-stage2-demos test-stage2 \
        pack-compiler test-http-get test-sayacrawl test-lsp-robust test-stdlib-growth test-sxpkg-polish test-stdlib-modules test-gen2-index-expr test-gen2-expr-lowering test-doc-claims test-native-strord test-native-cond test-native-lang test-native-locals test-give-index test-typed-sig test-list-expr test-list-paren test-native-strfn test-native-strgen test-native-listgen test-native-logicarg test-cond-string test-gen2-logic-builtin test-struct-logic test-logic-value test-native-generics test-sxpkg-online-local test-seed-gc test-generic-structs test-sxpkg-online-optin test-native-emit-split test-native-ir-log test-for-paren test-gen2-index-mod test-type-refusals test-native-ir-portable test-gen2-list-struct-fields test-language-deps test-exit-builtin test-path-builtins test-proc-builtins test-comment-quotes test-native-primitives \
        test-sxpkg-sayanox-logic test-read-bytes test-native-sxlink test-native-sxencode test-native-sxdefs test-native-sxinfer test-native-sxruntime test-native-sxgc test-native-sxemit test-sxdiag test-native32 test-native-arm64 test-native-riscv64 test-stdlib-json-write test-sxmod test-trust-anchor \
        sxc-native test-sxc-native test-sxsuite test-sxisaexec test-sxmod-deep test-lsp-ide test-stdlib-extended \
        ci test-ci-shape test-stdlib-csv test-stdlib-next

all: true-selfhost-min

# ---------------------------------------------------------------------------
# assert-out: run a program and compare its ENTIRE stdout to an expected value.
#
#   $(call assert-out,<program>,<expected text, \n between lines>)
#
# Uses only shell builtins -- command substitution, parameter expansion, printf
# and test. No sed, awk, grep, head, tail, wc or diff. It replaced ~40 uses of
# `... | sed -n Np` line extraction across the test targets.
#
# Comparing the whole output is strictly stronger than the per-line checks it
# replaced: a spurious extra line now fails, where `sed -n 1p` would not notice.
# Write a literal % in the expected text as % (make does not unescape %% here).
# ---------------------------------------------------------------------------
assert-out = @__got=$$($(1)) || { echo "[FAIL] $(1): program exited nonzero"; exit 1; }; __want=$$(printf '%b' '$(2)'); \
  if [ "$$__got" = "$$__want" ]; then :; else \
    echo "[FAIL] $(1): stdout does not match"; \
    echo "--- want ---"; printf '%s\n' "$$__want"; \
    echo "--- got ---";  printf '%s\n' "$$__got"; exit 1; fi

# ---------------------------------------------------------------------------
# verify-seed: assert the checked-in seed sources are in their known-good state.
#
# This target used to be `fix-seed`: ~20 lines of awk + `sed -i` that rewrote
# the seed sources in place before every build. Audited 2026-10-04 -- every one
# of those edits was dead code:
#
#   * The awk guard grepped for `ptok(k,(const char*)#ch`. As a BRE, `r*` means
#     "zero or more r", so that pattern can never match the literal text
#     `ptok(k,(const char*)#ch` in sxc_seed.c. The awk body never ran.
#     The parenthetical that used to follow -- "the rewrite was unnecessary
#     anyway: P1 is only instantiated with single-char punctuation literals, so
#     `#ch` already stringizes correctly" -- was WRONG, and because the guard
#     never matched nobody ever found out. `#ch` stringizes its argument WITH
#     the character-literal quotes, so P1('<',T_LT) recorded the three-character
#     token text `'<'`. emit_expr compares that against "<" and matched nothing,
#     so EVERY single-character operator vanished from the generated C
#     (`show 2 * 3` became `sx_show(((double)2LL),((double)3LL)))`) and no full
#     seed program with arithmetic, a comparison or a while/when condition
#     compiled at all. Fixed 2026-10-13: P1 builds the one-character token text
#     from the value (`char ob[2]={(char)(ch),0}`), the idiom the "unexpected
#     character" diagnostic in the same loop already used. Two-character
#     operators (== != && || <= >=) are pushed with explicit strings and were
#     always correct. test-seed-gc pins it: selfhost/seed_gc_ops.sa prints the
#     same nine values on the full seed, seed-min and gen2.
#   * All six `sed -i` guards searched for pre-fix text that is no longer
#     present in the checked-in sx_runtime.h, so they were all no-ops.
#
# The correct sources are checked in, so there is nothing left to patch at
# build time. Runtime patching of tracked sources is therefore replaced by a
# read-only assertion: a stale checkout now fails loudly instead of having its
# files silently rewritten. Uses only grep + test. `fix-seed` is kept as an
# alias so existing invocations keep working.
# ---------------------------------------------------------------------------
verify-seed:
	@test -f $(SEED_MIN_C) || { echo "FAIL: missing $(SEED_MIN_C)"; exit 1; }
	@test -f selfhost/seed/sxc_seed_min.audit || { echo "FAIL: missing selfhost/seed/sxc_seed_min.audit"; exit 1; }
	@test -f $(SEED_SA) || { echo "FAIL: missing $(SEED_SA)"; exit 1; }
	@for f in selfhost/seed/sxc_seed.c selfhost/seed/sx_runtime.h selfhost/rc_runtime.h selfhost/rc_runtime_stress.c selfhost/seed_builder_registry_test.c; do \
	  test ! -e "$$f" || { echo "FAIL: retired C/header file $$f reappeared"; exit 1; }; \
	done
	@echo "[OK] verify-seed (single C trust anchor + Sayanox seed verified; no awk/sed patching)"

fix-seed: verify-seed

tools/sxpack: tools/sxpack.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxpack.sa $@

tools/sxlsp_probe: tools/sxlsp_probe.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxlsp_probe.sa $@

tools/sxpkg_transfer_test: tools/sxpkg_transfer_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxpkg_transfer_test.sa $@

tools/sxnet_test: tools/sxnet_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxnet_test.sa $@

pack-compiler: tools/sxpack
	@# Regenerate selfhost/compiler_min_gz/*.b64 from selfhost/compiler_min.sa in pure Sayanox
	./tools/sxpack pack

# ---------------------------------------------------------------------------
# restore-compiler: guarantee selfhost/compiler_min.sa is present and sane.
#
# Fully offline -- this target never touches the network.
#
# Fast path (normal): compiler_min.sa is checked-in plaintext and the Makefile
# verifies its markers. Fallback: decode the checked-in gzip+base64 blob with
# POSIX utilities when the plaintext source is missing. After the compiler is
# bootstrapped, `tools/sxpack.sa` can regenerate and byte-verify both archives
# entirely under Sayanox control (`make pack-compiler`). The bootstrap fallback
# remains a deliberately tiny Makefile recipe: sxpack itself needs gen2.
# ---------------------------------------------------------------------------
.PHONY: restore-compiler-module
restore-compiler-module:
	@if test -s $(MIN_MODULE) && grep -q -F 'make sxminimum<T>' $(MIN_MODULE) && grep -q -F 'make sxeslice(' $(MIN_MODULE); then \
	  echo '[OK] compiler module (checked-in source verified; no decoder used)'; \
	else \
	  test -s $(MIN_MODULE_BLOB) || { echo 'FAIL: compiler text module and recovery blob missing'; exit 1; }; \
	  base64 -d < $(MIN_MODULE_BLOB) > $(MIN_MODULE).gz.tmp && \
	  gzip -d -c $(MIN_MODULE).gz.tmp > $(MIN_MODULE).tmp && \
	  grep -q -F 'make sxminimum<T>' $(MIN_MODULE).tmp && \
	  grep -q -F 'make sxeslice(' $(MIN_MODULE).tmp && \
	  mv $(MIN_MODULE).tmp $(MIN_MODULE) || { rm -f $(MIN_MODULE).tmp $(MIN_MODULE).gz.tmp; echo 'FAIL: compiler module recovery'; exit 1; }; \
	  rm -f $(MIN_MODULE).gz.tmp; echo '[OK] compiler module restored offline'; \
	fi

restore-compiler: restore-compiler-module
	@if test -s $(MIN_SA) \
	   && grep -q 'read_file' $(MIN_SA) \
	   && grep -q 'arg_count' $(MIN_SA) \
	   && grep -q 'sx_eq' $(MIN_SA); then \
	  echo "[OK] restore-compiler (checked-in source verified; no base64/gzip used)"; \
	  exit 0; \
	fi; \
	echo "[restore-compiler] $(MIN_SA) absent or incomplete -> decoding gzip+base64 parts (offline)"; \
	{ test -f selfhost/compiler_min_gz/0000.b64 || test -f selfhost/compiler_min_gz/00.b64; } \
	  || { echo "FAIL: no $(MIN_SA) and no compiler_min_gz bundle to restore from"; exit 1; }; \
	cat selfhost/compiler_min_gz/*.b64 | tr -d '\n' | base64 -d | gzip -d > $(MIN_SA).tmp \
	  || { echo "FAIL: could not decode selfhost/compiler_min_gz/*.b64 (need base64 and gzip)"; rm -f $(MIN_SA).tmp; exit 1; }; \
	test -s $(MIN_SA).tmp || { echo "FAIL: decoded $(MIN_SA) is empty"; rm -f $(MIN_SA).tmp; exit 1; }; \
	grep -q 'read_file' $(MIN_SA).tmp && grep -q 'arg_count' $(MIN_SA).tmp && grep -q 'sx_eq' $(MIN_SA).tmp \
	  || { echo "FAIL: restored compiler_min is missing expected markers (existing $(MIN_SA) left untouched)"; rm -f $(MIN_SA).tmp; exit 1; }; \
	cat $(MIN_SA).tmp > $(MIN_SA); rm -f $(MIN_SA).tmp; \
	echo "[OK] restore-compiler (restored offline from gzip+base64 parts; no Python, no network)"

seed-bin: fix-seed $(SEED_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SEED_SA) $(SEED_BIN)
	@echo "[OK] seed-bin (C-free ELF64 built from $(SEED_SA) by sxc_native)"

$(GEN1_C): seed-bin restore-compiler
	./$(SEED_BIN) $(MIN_SA) > $(GEN1_C)
	@test -s $(GEN1_C)

$(GEN1): $(GEN1_C)
	$(CC) -O2 -o $(GEN1) $(GEN1_C) -lm
	@echo "[OK] gen1"

# The maintained gen2 path is bootstrapped by the small pure-min C seed.
# The older full-seed route is experimental and does not define this target.
# restore-compiler is order-only so a phony recovery check does not force every
# sub-make and CI hand-off job to rebuild gen1_min and gen2 from scratch.
$(GEN1_MIN_C): $(SEED_MIN_BIN) $(MIN_SA) $(MIN_MODULE) | restore-compiler
	./$(SEED_MIN_BIN) $(MIN_SA) > $(GEN1_MIN_C)
	@test -s $(GEN1_MIN_C)

$(GEN1_MIN): $(GEN1_MIN_C)
	$(CC) -O2 -o $(GEN1_MIN) $(GEN1_MIN_C)
	@echo "[OK] gen1_min"

$(GEN2_C): $(GEN1_MIN) $(MIN_SA) $(MIN_MODULE) | restore-compiler
	./$(GEN1_MIN) $(MIN_SA) $(GEN2_C)
	@test -s $(GEN2_C)

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

# C-free self-compiling x86-64 ELF64 compiler (tools/sxc_native): bootstrapped
# once from gen2 and immediately verified at its C-free ELF64 fixed point.
$(SXC_NATIVE_BIN): $(SXC_NATIVE_SA) $(SXC_NATIVE_LIBS) $(GEN2)
	@mkdir -p $(TESTS)
	./$(GEN2) $(SXC_NATIVE_SA) $(TESTS)/sxc_native_boot.c >/dev/null
	@if grep -q '^#error' $(TESTS)/sxc_native_boot.c; then echo "[FAIL] sxc_native: #error in bootstrap C"; exit 1; fi
	$(CC) -std=gnu99 -O2 -Wno-implicit-function-declaration -o $(TESTS)/sxc_native_boot $(TESTS)/sxc_native_boot.c
	./$(TESTS)/sxc_native_boot $(SXC_NATIVE_SA) $(TESTS)/sxc_native_fp1
	./$(TESTS)/sxc_native_fp1 $(SXC_NATIVE_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXC_NATIVE_SA) $(TESTS)/sxc_native_fp2
	cmp -s $(SXC_NATIVE_BIN) $(TESTS)/sxc_native_fp2
	@rm -f $(TESTS)/sxc_native_fp1 $(TESTS)/sxc_native_fp2
	@echo "[OK] C-free x86-64 ELF64 compiler $(SXC_NATIVE_BIN) reached self-hosted fixed point"

sxc-native: $(SXC_NATIVE_BIN)

$(SXFMT_BIN): $(SXC_NATIVE_BIN) tools/sxfmt.sa
	./$(SXC_NATIVE_BIN) tools/sxfmt.sa $(SXFMT_BIN)
	@echo "[OK] Sayanox formatter built C-free from tools/sxfmt.sa"

sxfmt: $(SXFMT_BIN)

$(SXPKG_BIN): $(SXC_NATIVE_BIN) tools/sxpkg.sa stdlib/crypto.sa stdlib/pubkey.sa
	./$(SXC_NATIVE_BIN) tools/sxpkg.sa $(SXPKG_BIN)
	@echo "[OK] Sayanox local package-lock tool built C-free from tools/sxpkg.sa"

sxpkg: $(SXPKG_BIN)
tools: sxfmt sxpkg

# The language server is compiled directly to a static x86-64 ELF64 binary by
# sxc_native with zero C compiler and zero libc.
$(LSP_BIN): $(SXC_NATIVE_BIN) tools/sayanox_lsp.sa
	./$(SXC_NATIVE_BIN) tools/sayanox_lsp.sa $(LSP_BIN)

lsp: $(LSP_BIN)
	@echo "=== LSP-OK ==="

# Full JSON-RPC sessions against the built server: initialize, didOpen, hover,
# definition, documentSymbol, completion, diagnostic, didChange, shutdown,
# exit; a closed document and the four-slot cap; references across the open
# documents with and without the declaration; workspace/symbol with a query and
# without; and textDocument/formatting (the sxfmt rule set) on a badly indented
# buffer and on one that is already formatted.  The probe prints one line per
# verified fact: 29 of them, in this order.
test-lsp: $(LSP_BIN) tools/sxlsp_probe
	@mkdir -p $(TESTS)
	$(call assert-out,./tools/sxlsp_probe probe ./$(LSP_BIN) $(TESTS)/lsp-probe,initialize\nserverInfo\nrename capability\ndiag unknown-statement\ndiag unterminated-string\ndiag unbalanced-braces\ndiag unresolved-use\nsymbol function\nsymbol variable\ncompletion builtin\ncompletion literal preserved\nhover builtin\ndefinition\ndiagnostics cleared on change\nsecond document symbols\nclosed document answers empty\nclosed document not served from another buffer\nfifth document evicts the oldest\nnewest document still served\nreferences include the declaration\nreferences honour includeDeclaration:false\nreferences span the open documents\nreferences at a non-word answer empty\nworkspace symbol matches a query\nworkspace symbol with an empty query spans documents\nformatting answers one whole-buffer edit\nformatting indents a comment inside a block\nformatting indents a nested block by four spaces\nformatting strips trailing whitespace\nformatting leaves a formatted document alone\nrename edits the declaration\nrename carries the new name\nrename spans the open documents\nsignature help labels the declaration\nsignature help lists the parameters\nsignature help counts the argument\ncode action offers formatting\ncode action is empty when already formatted)
	@echo "[OK] Sayanox LSP: live JSON-RPC sessions, real diagnostics, symbols, completion, hover, definition, references, workspace symbols, formatting"

# Malformed and unexpected JSON-RPC input: unknown requests get -32601,
# unknown notifications stay silent, bad bodies get -32700 / -32600, and the
# server keeps serving afterwards. Probe: tools/sxlsp_probe.sa.
test-lsp-robust: $(LSP_BIN) tools/sxlsp_probe
	@$(call assert-out,./tools/sxlsp_probe robust ./$(LSP_BIN),unknown request -32601\nserver keeps serving after error\nunknown notification ignored\ngarbage body -32700\nno method -32600\njunk header skipped\ntruncated frame ends cleanly\nstring id echoed on a result\nstring id with an escaped quote echoed on an error\nnegative id echoed\nnull id echoed)
	@echo "[OK] Sayanox LSP robustness: JSON-RPC error responses for bad input"

test-sxfmt: sxfmt
	@mkdir -p $(TESTS)
	@printf 'hold x = 1  \nwhen x > 0 {  \nshow "brace } // not comment"\n// comment { }\nwhen x == 1 {\n  show 42   \n}\n}\n' > $(TESTS)/sxfmt-in.sa
	@printf 'hold x = 1\nwhen x > 0 {\n  show "brace } // not comment"\n  // comment { }\n  when x == 1 {\n    show 42\n  }\n}\n' > $(TESTS)/sxfmt-want.sa
	./$(SXFMT_BIN) $(TESTS)/sxfmt-in.sa $(TESTS)/sxfmt-out.sa
	cmp $(TESTS)/sxfmt-want.sa $(TESTS)/sxfmt-out.sa
	./$(SXFMT_BIN) $(TESTS)/sxfmt-out.sa $(TESTS)/sxfmt-again.sa
	cmp $(TESTS)/sxfmt-out.sa $(TESTS)/sxfmt-again.sa
	@printf 'hold x = 7  ' > $(TESTS)/sxfmt-no-final-newline.sa
	./$(SXFMT_BIN) $(TESTS)/sxfmt-no-final-newline.sa $(TESTS)/sxfmt-final-newline.sa
	@printf 'hold x = 7\n' > $(TESTS)/sxfmt-final-want.sa
	cmp $(TESTS)/sxfmt-final-want.sa $(TESTS)/sxfmt-final-newline.sa
	@echo "[OK] Sayanox formatter: indentation, strings/comments, final newline, idempotence"

test-sxpkg: sxpkg
	@mkdir -p $(TESTS)/sxpkg
	@printf '' > $(TESTS)/sxpkg/sx.lock
	@printf '' > $(TESTS)/sxpkg/sx.toml
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) init
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg/sx.lock-want
	cmp $(TESTS)/sxpkg/sx.lock-want $(TESTS)/sxpkg/sx.lock
	@printf 'name = "my-pkg"\nversion = "0.1.0"\n' > $(TESTS)/sxpkg/sx.toml-want
	cmp $(TESTS)/sxpkg/sx.toml-want $(TESTS)/sxpkg/sx.toml
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) add math 0.1.0
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) add math 0.2.0
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) add strings
	@printf '# sx.lock\nversion=1\nmath=0.2.0\nstrings=0.1.0\n' > $(TESTS)/sxpkg/sx.lock-want
	cmp $(TESTS)/sxpkg/sx.lock-want $(TESTS)/sxpkg/sx.lock
	$(call assert-out,cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) list,sxpkg: locked packages\nmath=0.2.0\nstrings=0.1.0)
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) remove math
	@printf '# sx.lock\nversion=1\nstrings=0.1.0\n' > $(TESTS)/sxpkg/sx.lock-want
	cmp $(TESTS)/sxpkg/sx.lock-want $(TESTS)/sxpkg/sx.lock
	cd $(TESTS)/sxpkg && ../../../$(SXPKG_BIN) init >/dev/null
	cmp $(TESTS)/sxpkg/sx.lock-want $(TESTS)/sxpkg/sx.lock
	@echo "[OK] Sayanox package tool: init/add/update/list/remove"

test-sxpkg-wrapper: sxpkg
	@mkdir -p $(TESTS)/sxpkg-wrapper
	@printf '' > $(TESTS)/sxpkg-wrapper/sx.lock
	@printf '' > $(TESTS)/sxpkg-wrapper/sx.toml
	cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) init >/dev/null
	cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) add local-pkg >/dev/null
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) list,sxpkg: locked packages\nlocal-pkg=0.1.0)
	cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) remove local-pkg >/dev/null
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) list,sxpkg: locked packages\n(none))
	cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) seed >/dev/null
	@printf 'hello=0.1.0\nmath=0.1.0\n' > $(TESTS)/sxpkg-wrapper/index-want
	cmp $(TESTS)/sxpkg-wrapper/index-want $(TESTS)/sxpkg-wrapper/.sayanox/registry/INDEX
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) search math,sxpkg: search math\n  math 0.1.0)
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && ../../../$(SXPKG_BIN) info math,name=math\nversion=0.1.0\ndesc=tiny math helpers (dbl, sqr)\nsum=718013937)
	@mkdir -p $(TESTS)/sxpkg-wrapper/project
	@printf '' > $(TESTS)/sxpkg-wrapper/project/sx.lock
	@printf '' > $(TESTS)/sxpkg-wrapper/project/sx.toml
	cd $(TESTS)/sxpkg-wrapper && SAYANOX_ROOT=project ../../../$(SXPKG_BIN) init >/dev/null
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-wrapper/project/lock-want
	cmp $(TESTS)/sxpkg-wrapper/project/lock-want $(TESTS)/sxpkg-wrapper/project/sx.lock
	cd $(TESTS)/sxpkg-wrapper && SAYANOX_ROOT=project ../../../$(SXPKG_BIN) add rooted 0.1.0 >/dev/null
	@printf '# sx.lock\nversion=1\nrooted=0.1.0\n' > $(TESTS)/sxpkg-wrapper/project/lock-want
	cmp $(TESTS)/sxpkg-wrapper/project/lock-want $(TESTS)/sxpkg-wrapper/project/sx.lock
	@echo "[OK] sxpkg: one Sayanox binary for the whole package tool, no shell wrapper"


test-reassign:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./$(GEN2) $(TESTS)/ts_re.sa $(TESTS)/ts_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re $(TESTS)/ts_re.c
	$(call assert-out,./$(TESTS)/ts_re,2)
	@echo "[OK] gen2 reassign"

test-while:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/ts_wh.sa
	./$(GEN2) $(TESTS)/ts_wh.sa $(TESTS)/ts_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wh $(TESTS)/ts_wh.c
	$(call assert-out,./$(TESTS)/ts_wh,0\n1\n2\ndone)
	@echo "[OK] gen2 while"

test-when:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/ts_wn.sa
	./$(GEN2) $(TESTS)/ts_wn.sa $(TESTS)/ts_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wn $(TESTS)/ts_wn.c
	$(call assert-out,./$(TESTS)/ts_wn,99)
	@echo "[OK] gen2 when"

test-mod:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/ts_mod.sa
	./$(GEN2) $(TESTS)/ts_mod.sa $(TESTS)/ts_mod.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_mod $(TESTS)/ts_mod.c
	@grep -q 'sx_mod((double)(a),(double)(3.0))' $(TESTS)/ts_mod.c
	@grep -q '} else {' $(TESTS)/ts_mod.c
	$(call assert-out,./$(TESTS)/ts_mod,1\n1)
	@echo "[OK] gen2 modulo + else"

test-user:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'struct User {\n  name,\n  age\n}\nhold u = User { name: "Ada", age: 36 }\nshow u.name\nshow u.age\nhold s = u.name\nshow s\nshow u.name + "!"\nshow u.age + 1\nhold v = User { "Bob", 7 }\nshow v.name\nshow len(v.name)\n' > $(TESTS)/ts_user.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_user.sa > $(TESTS)/ts_user_sm.c
	$(CC) -O2 -o $(TESTS)/ts_user_sm $(TESTS)/ts_user_sm.c
	./$(GEN2) $(TESTS)/ts_user.sa $(TESTS)/ts_user_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_user_g2 $(TESTS)/ts_user_g2.c
	@grep -q 'char \*name; double age' $(TESTS)/ts_user_sm.c
	@grep -q 'char \*name; double age' $(TESTS)/ts_user_g2.c
	@./$(TESTS)/ts_user_sm > $(TESTS)/ts_user_sm.out; ./$(TESTS)/ts_user_g2 > $(TESTS)/ts_user_g2.out; \
	 cmp $(TESTS)/ts_user_sm.out $(TESTS)/ts_user_g2.out
	@# a program whose ONLY string operation is a chain starting at a struct
	@# field: gen2 used to leave sx_cat out of the runtime (link error)
	@printf 'struct U {\n  name\n}\nhold u = U { name: "x" }\nhold t = u.name + "y"\nshow t\nshow u.name + "z"\n' > $(TESTS)/ts_fcat.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_fcat.sa > $(TESTS)/ts_fcat_sm.c
	$(CC) -O2 -o $(TESTS)/ts_fcat_sm $(TESTS)/ts_fcat_sm.c
	$(call assert-out,./$(TESTS)/ts_fcat_sm,xy\nxz)
	./$(GEN2) $(TESTS)/ts_fcat.sa $(TESTS)/ts_fcat_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_fcat_g2 $(TESTS)/ts_fcat_g2.c
	$(call assert-out,./$(TESTS)/ts_fcat_g2,xy\nxz)
	$(call assert-out,./$(TESTS)/ts_user_g2,Ada\n36\nAda\nAda!\n37\nBob\n3)
	@printf 'struct User {\n  name,\n  age\n}\nhold a = User { name: "Ada", age: 36 }\nhold b = User { name: 1, age: 2 }\n' > $(TESTS)/ts_userbad.sa
	@./$(GEN2) $(TESTS)/ts_userbad.sa $(TESTS)/ts_userbad.c >/dev/null; grep -q '#error' $(TESTS)/ts_userbad.c
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_userbad.sa > /dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a struct field type mismatch"; exit 1; fi
	@printf 'struct User {\n  name,\n  age\n}\nhold u = User { age: 1, name: "Ada" }\n' > $(TESTS)/ts_order.sa
	@./$(GEN2) $(TESTS)/ts_order.sa $(TESTS)/ts_order.c >/dev/null; grep -q '#error' $(TESTS)/ts_order.c
	@printf 'struct User {\n  name,\n  age\n}\nhold u = User { age: 36, name: "Ada" }\nshow u.name\nshow u.age\n' > $(TESTS)/ts_part.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_part.sa > $(TESTS)/ts_part_sm.c
	$(CC) -O2 -o $(TESTS)/ts_part_sm $(TESTS)/ts_part_sm.c
	$(call assert-out,./$(TESTS)/ts_part_sm,Ada\n36)
	@echo "[OK] struct string fields (User name/age): seed-min and gen2 agree; mismatches rejected"

test-chain:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold t = "b"\nhold s = "a"\nshow s + t\nhold u = s + t + "!"\nshow u\nhold a = 1\nhold b = 2\nhold c = 3\nshow a + b + c\nshow a * b + c\nshow 1 + 2 * 3\nhold d = 10 - 2 - 3\nshow d\nshow 10 %% 4 + 1\nshow a %% 2 + b * c\n' > $(TESTS)/ts_chain.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_chain.sa > $(TESTS)/ts_chain_sm.c
	$(CC) -O2 -o $(TESTS)/ts_chain_sm $(TESTS)/ts_chain_sm.c
	./$(GEN2) $(TESTS)/ts_chain.sa $(TESTS)/ts_chain_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_chain_g2 $(TESTS)/ts_chain_g2.c
	@./$(TESTS)/ts_chain_sm > $(TESTS)/ts_chain_sm.out; ./$(TESTS)/ts_chain_g2 > $(TESTS)/ts_chain_g2.out; \
	 cmp $(TESTS)/ts_chain_sm.out $(TESTS)/ts_chain_g2.out
	$(call assert-out,./$(TESTS)/ts_chain_g2,ab\nab!\n6\n5\n7\n5\n3\n7)
	@echo "[OK] gen2 chained + - * / % (and string + name) agree with seed-min"

test-condmod:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold a = 17\nwhile a %% 10 > 0 {\n  show a %% 10\n  hold a = a - 3\n}\nwhen 10 %% 3 == 1 {\n  show "mod-ok"\n}\n' > $(TESTS)/ts_cm.sa
	./$(GEN2) $(TESTS)/ts_cm.sa $(TESTS)/ts_cm.c >/dev/null
	@grep -q 'sx_mod((double)(a)' $(TESTS)/ts_cm.c
	@grep -q 'sx_mod((double)(10.0' $(TESTS)/ts_cm.c
	$(CC) -O2 -o $(TESTS)/ts_cm $(TESTS)/ts_cm.c
	$(call assert-out,./$(TESTS)/ts_cm,7\n4\n1\n8\n5\n2\nmod-ok)
	@echo "[OK] gen2 while/when condition % uses checked sx_mod"

test-struct2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'struct Point {\n  x,\n  y\n}\nstruct Pair {\n  a,\n  b\n}\nhold p = Point { x: 3, y: 4 }\nshow p.x\nshow p.y\nshow p.x + p.y\nhold q = Pair { a: 5, b: 6 }\nshow q.a + q.b\n' > $(TESTS)/ts_st2.sa
	./$(GEN2) $(TESTS)/ts_st2.sa $(TESTS)/ts_st2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_st2 $(TESTS)/ts_st2.c
	$(call assert-out,./$(TESTS)/ts_st2,3\n4\n7\n11)
	@echo "[OK] gen2 structs: named fields, two structs, field expr"

test-list2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold xs = [10, 20, 30]\nshow xs[0]\nshow len(xs)\nhold xs = push(xs, 40)\nshow len(xs)\nshow xs[3]\n' > $(TESTS)/ts_li2.sa
	./$(GEN2) $(TESTS)/ts_li2.sa $(TESTS)/ts_li2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li2 $(TESTS)/ts_li2.c
	$(call assert-out,./$(TESTS)/ts_li2,10\n3\n4\n40)
	@printf 'hold xs = [5, 6]\nshow xs[1] + 1\nshow len(xs)\n' > $(TESTS)/ts_li3.sa
	./$(GEN2) $(TESTS)/ts_li3.sa $(TESTS)/ts_li3.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li3 $(TESTS)/ts_li3.c
	$(call assert-out,./$(TESTS)/ts_li3,7\n2)
	@printf 'hold xs = [5, 6]\nshow len(xs) + 1\nshow 10 %% 3\nhold y = 10 + 2\nshow y\n' > $(TESTS)/ts_li4.sa
	./$(GEN2) $(TESTS)/ts_li4.sa $(TESTS)/ts_li4.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li4 $(TESTS)/ts_li4.c
	$(call assert-out,./$(TESTS)/ts_li4,3\n1\n12)
	@# `xs[len(xs) - 1]` was a refusal here until 2026-10-13: len() inside an
	@# index now lowers to sx_llen, so this leg became a value assertion. The
	@# index forms that ARE still refused are pinned by test-gen2-index-expr and
	@# test-gen2-expr-lowering, so nothing lost its guard by moving.
	@printf 'hold xs = [5, 6]\nshow xs[len(xs) - 1]\n' > $(TESTS)/ts_li5.sa
	./$(GEN2) $(TESTS)/ts_li5.sa $(TESTS)/ts_li5.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li5 $(TESTS)/ts_li5.c
	@grep -q -F 'sx_lget(xs,sx_llen(xs) - 1.0)' $(TESTS)/ts_li5.c
	$(call assert-out,./$(TESTS)/ts_li5,6)
	@echo "[OK] gen2 lists: literal, index, len, push, and len() inside an index"

test-use:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold z = 99\n' > $(TESTS)/ts_other.sa
	@printf 'use "selfhost/seed_tests/ts_other.sa"\nshow z\n' > $(TESTS)/ts_use.sa
	./$(GEN2) $(TESTS)/ts_use.sa $(TESTS)/ts_use.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_use $(TESTS)/ts_use.c
	$(call assert-out,./$(TESTS)/ts_use,99)
	@printf 'use "selfhost/seed_tests/ts_other.sa"\nhold y = 1\n' > $(TESTS)/ts_mid.sa
	@printf 'use "selfhost/seed_tests/ts_mid.sa"\nshow z\nshow y\n' > $(TESTS)/ts_top.sa
	./$(GEN2) $(TESTS)/ts_top.sa $(TESTS)/ts_top.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_top $(TESTS)/ts_top.c
	$(call assert-out,./$(TESTS)/ts_top,99\n1)
	@printf 'use "selfhost/seed_tests/no_such_file.sa"\nshow 1\n' > $(TESTS)/ts_miss.sa
	@./$(GEN2) $(TESTS)/ts_miss.sa $(TESTS)/ts_miss.c >/dev/null 2>&1 || true
	@grep -q '#error' $(TESTS)/ts_miss.c
	@printf 'use other.sa\nshow 1\n' > $(TESTS)/ts_uq.sa
	./$(GEN2) $(TESTS)/ts_uq.sa $(TESTS)/ts_uq.c >/dev/null
	@grep -q '#error' $(TESTS)/ts_uq.c
	@echo "[OK] gen2 use: splice, nested depth 2, missing file and unquoted path are hard errors"

test-nest:
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'struct Point {\n  name,\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: Point { name: "p1", x: 1 }, b: Point { name: "p2", x: 2 } }\nshow l.a.name\nshow l.a.x\nshow l.b.name\nshow l.b.x\nhold m = l.b\nshow m.name\nshow m.x\n' > $(TESTS)/ts_nest.sa
	@# seed-min reference: ordered struct-typed fields, .a.x chains, run
	./$(SEED_MIN_BIN) $(TESTS)/ts_nest.sa > $(TESTS)/ts_nest_sm.c
	$(CC) -O2 -o $(TESTS)/ts_nest_sm $(TESTS)/ts_nest_sm.c
	@grep -q 'typedef struct { char \*name; double x; } Point;' $(TESTS)/ts_nest_sm.c
	@grep -q 'typedef struct { Point a; Point b; } Line;' $(TESTS)/ts_nest_sm.c
	$(call assert-out,./$(TESTS)/ts_nest_sm,p1\n1\np2\n2\np2\n2)
	@# gen2 must agree byte-for-byte on stdout (output parity with seed-min)
	./$(GEN2) $(TESTS)/ts_nest.sa $(TESTS)/ts_nest_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_nest_g2 $(TESTS)/ts_nest_g2.c
	@grep -q 'typedef struct { char \*name; double x; } Point;' $(TESTS)/ts_nest_g2.c
	@grep -q 'typedef struct { Point a; Point b; } Line;' $(TESTS)/ts_nest_g2.c
	$(call assert-out,./$(TESTS)/ts_nest_g2,p1\n1\np2\n2\np2\n2)
	@# three levels deep: Scene -> Rect -> Point, plus a string field and
	@# a typed struct copy (hold rr = s.r)
	@printf 'struct Point {\n  x,\n  y\n}\nstruct Rect {\n  o,\n  sz\n}\nstruct Scene {\n  r,\n  label\n}\nhold s = Scene { r: Rect { o: Point { 1, 2 }, sz: Point { 3, 4 } }, label: "main" }\nshow s.r.o.x\nshow s.r.o.y\nshow s.r.sz.x\nshow s.label\nhold rr = s.r\nshow rr.sz.y\n' > $(TESTS)/ts_nest3.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_nest3.sa > $(TESTS)/ts_nest3_sm.c
	$(CC) -O2 -o $(TESTS)/ts_nest3_sm $(TESTS)/ts_nest3_sm.c
	$(call assert-out,./$(TESTS)/ts_nest3_sm,1\n2\n3\nmain\n4)
	./$(GEN2) $(TESTS)/ts_nest3.sa $(TESTS)/ts_nest3_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_nest3_g2 $(TESTS)/ts_nest3_g2.c
	@grep -q 'typedef struct { Point o; Point sz; } Rect;' $(TESTS)/ts_nest3_g2.c
	@grep -q 'typedef struct { Rect r; char \*label; } Scene;' $(TESTS)/ts_nest3_g2.c
	$(call assert-out,./$(TESTS)/ts_nest3_g2,1\n2\n3\nmain\n4)
	@# doubly nested field copy: `hold p2 = t.q.p` used to be rejected by
	@# seed-min's first collect pass (struct field types are only fixed by
	@# the literal scan that runs after it) with the misleading "field 'q'
	@# has no struct type"; gen2 always accepted it. Both must print 7.
	@printf 'struct Point {\n  x\n}\nstruct Mid {\n  p\n}\nstruct Top {\n  q\n}\nhold t = Top { q: Mid { p: Point { x: 7 } } }\nhold p2 = t.q.p\nshow p2.x\n' > $(TESTS)/ts_nestcopy.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_nestcopy.sa > $(TESTS)/ts_nestcopy_sm.c
	$(CC) -O2 -o $(TESTS)/ts_nestcopy_sm $(TESTS)/ts_nestcopy_sm.c
	$(call assert-out,./$(TESTS)/ts_nestcopy_sm,7)
	./$(GEN2) $(TESTS)/ts_nestcopy.sa $(TESTS)/ts_nestcopy_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_nestcopy_g2 $(TESTS)/ts_nestcopy_g2.c
	$(call assert-out,./$(TESTS)/ts_nestcopy_g2,7)
	@# a chain that is REALLY invalid must still be a hard error in seed-min
	@printf 'struct Point {\n  x\n}\nhold q = Point { x: 1 }\nhold p2 = q.x.y\n' > $(TESTS)/ts_nestcopybad.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestcopybad.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a copy through a number field"; exit 1; fi
	@echo "[OK] doubly nested field copy (hold p2 = t.q.p): seed-min and gen2 agree; bad chains still hard errors"
	@# a nested struct must be declared before the struct that nests it
	@printf 'struct Line {\n  a\n}\nstruct Point {\n  x\n}\nhold l = Line { a: Point { 1 } }\n' > $(TESTS)/ts_nestfwd.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestfwd.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a nested struct declared later"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_nestfwd.sa $(TESTS)/ts_nestfwd_g2.c >/dev/null 2>&1 || true
	@grep -q 'declare the nested struct first' $(TESTS)/ts_nestfwd_g2.c
	@# Concrete list fields are pointer-valued on both seed-min and gen2.
	@# The alias must observe growth, and gen2 must lower the dotted index.
	@printf 'struct Line {\n  a\n}\nhold l = Line { a: [1] }\nhold alias = l.a\npush(alias, 2)\nshow len(l.a)\nshow l.a[1]\n' > $(TESTS)/ts_nestlist.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_nestlist.sa > $(TESTS)/ts_nestlist_sm.c
	$(CC) -O2 -o $(TESTS)/ts_nestlist_sm $(TESTS)/ts_nestlist_sm.c
	$(call assert-out,./$(TESTS)/ts_nestlist_sm,2\n2)
	./$(GEN2) $(TESTS)/ts_nestlist.sa $(TESTS)/ts_nestlist_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/ts_nestlist_g2 $(TESTS)/ts_nestlist_g2.c
	$(call assert-out,./$(TESTS)/ts_nestlist_g2,2\n2)
	@grep -q -F 'typedef struct { sx_list *a; } Line;' $(TESTS)/ts_nestlist_g2.c
	@grep -q -F 'sx_lget((l).a,1.0)' $(TESTS)/ts_nestlist_g2.c
	@# chaining through a numeric field is a clear error, not bad C
	@printf 'struct Line {\n  a\n}\nhold l = Line { a: 1 }\nshow l.a.x\n' > $(TESTS)/ts_nestmiss.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestmiss.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a chain through a numeric struct field"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_nestmiss.sa $(TESTS)/ts_nestmiss_g2.c >/dev/null 2>&1 || true
	@grep -q 'is not a struct' $(TESTS)/ts_nestmiss_g2.c
	@# a struct value cannot be shown
	@printf 'struct Point {\n  x\n}\nhold q = Point { x: 1 }\nshow q\n' > $(TESTS)/ts_nestshow.sa
	@./$(GEN2) $(TESTS)/ts_nestshow.sa $(TESTS)/ts_nestshow_g2.c >/dev/null 2>&1 || true
	@grep -q 'show value cannot be a struct' $(TESTS)/ts_nestshow_g2.c
	@echo "[OK] nested structs in seed-min and gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies incl. doubly nested); concrete list fields preserve aliases and gen2 lowers dotted indexes; forward decls/bad chains/show-of-struct stay clear errors"

test-prec:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@# a + 3 * 4 must be 14 (native used to answer 15: the term-level used r15,
	@# which is also where emit_rel kept the left operand)
	@printf 'hold a = 2\nshow a + 3 * 4\nshow a * 3 + 4\nshow 1 + 2 * 3\nshow a + 3 / 3\nshow a + 1 %% 3\n' > $(TESTS)/ts_prec.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_prec.sa > $(TESTS)/ts_prec_sm.c
	$(CC) -O2 -o $(TESTS)/ts_prec_sm $(TESTS)/ts_prec_sm.c
	$(call assert-out,./$(TESTS)/ts_prec_sm,14\n10\n7\n3\n3)
	./$(GEN2) $(TESTS)/ts_prec.sa $(TESTS)/ts_prec_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_prec_g2 $(TESTS)/ts_prec_g2.c
	$(call assert-out,./$(TESTS)/ts_prec_g2,14\n10\n7\n3\n3)
	@echo "[OK] precedence: a + 3 * 4 = 14 in seed-min and gen2"
	@# (parenthesized expressions moved to `make test-parens`: gen2 runs them now)

# ---------------------------------------------------------------------------
# test-float: fractional literals, true `/`, and IEEE-double constant math
# (seed-min and gen2 agree). `10 / 4` is 2.5; integer-only products do not
# overflow in C `int`, and `% 0` is a deterministic language diagnostic.
# ---------------------------------------------------------------------------
test-float:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold x = 2.5\nshow x\nshow x * 2\nshow 10 / 4\nshow 7 / 2 * 2\nshow 1 / 3\nhold xs = [1.5, 2]\nshow xs[0]\nstruct P {\n  v\n}\nhold p = P { v: 1.25 }\nshow p.v\nwhen x > 2.4 {\n  show 1\n}\nshow 10 %% 4\nshow 0.5 + 0.25\nhold y = -1.5\nshow y\nshow 5 %% 2.5\n' > $(TESTS)/ts_float.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_float.sa > $(TESTS)/ts_float_sm.c
	$(CC) -O2 -o $(TESTS)/ts_float_sm $(TESTS)/ts_float_sm.c
	$(call assert-out,./$(TESTS)/ts_float_sm,2.5\n5\n2.5\n7\n0.333333\n1.5\n1.25\n1\n2\n0.75\n-1.5\n1)
	./$(GEN2) $(TESTS)/ts_float.sa $(TESTS)/ts_float_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_float_g2 $(TESTS)/ts_float_g2.c
	$(call assert-out,./$(TESTS)/ts_float_g2,2.5\n5\n2.5\n7\n0.333333\n1.5\n1.25\n1\n2\n0.75\n-1.5\n1)
	@printf 'hold x = 2.\nshow x\n' > $(TESTS)/ts_floatbad.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_floatbad.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted the malformed literal 2."; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_floatbad.sa $(TESTS)/ts_floatbad_g2.c >/dev/null 2>&1 || true
	@grep -q '#error' $(TESTS)/ts_floatbad_g2.c
	@# two fractional parts: gen2 used to copy `1.2.3` into the C verbatim
	@printf 'hold x = 1.2.3\nshow x\nshow "v1.2.3"\n' > $(TESTS)/ts_float3.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_float3.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted 1.2.3"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_float3.sa $(TESTS)/ts_float3_g2.c >/dev/null 2>&1 || true
	@grep -q 'malformed number literal' $(TESTS)/ts_float3_g2.c
	@printf 'show "v1.2.3"\n// 4.5.6 in a comment\nhold v1 = 2.5\nshow v1\n' > $(TESTS)/ts_float4.sa
	./$(GEN2) $(TESTS)/ts_float4.sa $(TESTS)/ts_float4_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_float4_g2 $(TESTS)/ts_float4_g2.c
	$(call assert-out,./$(TESTS)/ts_float4_g2,v1.2.3\n2.5)
	@# Every integer literal must reach C arithmetic as a double: two constant
	@# operands used to overflow in 32-bit int before assignment to a double.
	@printf 'show 100000 * 100000\nshow 100000 + 100000 * 100000\nshow 100000 * 100000.0\nshow (100000 * 100000) / 2\nhold a = 100000\nshow a * 100000\nwhen 100000 * 100000 > 2000000000 {\n  show 1\n} else {\n  show 0\n}\nmake big() {\n  give 100000 * 100000\n}\nmake pass(n) {\n  give n\n}\nshow big()\nshow pass(100000 * 100000)\n' > $(TESTS)/ts_big.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_big.sa > $(TESTS)/ts_big_sm.c
	$(CC) -O2 -o $(TESTS)/ts_big_sm $(TESTS)/ts_big_sm.c
	$(call assert-out,./$(TESTS)/ts_big_sm,1e+10\n1.00001e+10\n1e+10\n5e+09\n1e+10\n1\n1e+10\n1e+10)
	./$(GEN2) $(TESTS)/ts_big.sa $(TESTS)/ts_big_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_big_g2 $(TESTS)/ts_big_g2.c
	$(call assert-out,./$(TESTS)/ts_big_g2,1e+10\n1.00001e+10\n1e+10\n5e+09\n1e+10\n1\n1e+10\n1e+10)
	@# Both C backends diagnose modulo-by-zero consistently, including a
	@# runtime divisor; all backends must report the language diagnostic.
	@printf 'hold zero = 0\nshow 7 %% zero\n' > $(TESTS)/ts_modzero.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_modzero.sa > $(TESTS)/ts_modzero_sm.c
	$(CC) -O2 -o $(TESTS)/ts_modzero_sm $(TESTS)/ts_modzero_sm.c
	@if ./$(TESTS)/ts_modzero_sm >/dev/null 2>$(TESTS)/ts_modzero_sm.err; then echo "[FAIL] seed-min accepted modulo by zero"; exit 1; fi
	@grep -q 'division by zero' $(TESTS)/ts_modzero_sm.err
	./$(GEN2) $(TESTS)/ts_modzero.sa $(TESTS)/ts_modzero_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_modzero_g2 $(TESTS)/ts_modzero_g2.c
	@if ./$(TESTS)/ts_modzero_g2 >/dev/null 2>$(TESTS)/ts_modzero_g2.err; then echo "[FAIL] gen2 accepted modulo by zero"; exit 1; fi
	@grep -q 'division by zero' $(TESTS)/ts_modzero_g2.err
	@echo "[OK] fractional/double literals, integer-only overflow, true division, and modulo-zero diagnostics: seed-min and gen2 agree"

# ---------------------------------------------------------------------------
# test-parens: parenthesized expressions on seed-min and gen2.  gen2 compiles
# a hold/show with a grouping paren through the verbatim-C + `%` rewrite it
# uses for conditions; non-numeric content inside the parens (strings,
# lists, fields, builtins) is a clear #error, never broken C.
# ---------------------------------------------------------------------------
test-parens:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold a = 2\nshow (a + 3) * 4\nshow 4 * (a + 3)\nhold b = (a + 1) %% 2\nshow b\nshow ((a))\nshow (10 / 4) * 2\nshow -(a + 1)\nshow (a %% 3 + 1) * 2\nhold b = (b + 1) * 10\nshow b\nshow (a < 3) + 1\nmake f(x) {\n  give (x + 1) * 2\n}\nshow (f(2) + 1) * 2\nmake g(x) {\n  give x %% 3\n}\nshow g(7)\nwhen (a + 1) * 2 == 6 {\n  show 6\n}\n' > $(TESTS)/ts_parens.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_parens.sa > $(TESTS)/ts_parens_sm.c
	$(CC) -O2 -o $(TESTS)/ts_parens_sm $(TESTS)/ts_parens_sm.c
	$(call assert-out,./$(TESTS)/ts_parens_sm,20\n20\n1\n2\n5\n-3\n6\n20\n2\n14\n1\n6)
	./$(GEN2) $(TESTS)/ts_parens.sa $(TESTS)/ts_parens_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_parens_g2 $(TESTS)/ts_parens_g2.c
	$(call assert-out,./$(TESTS)/ts_parens_g2,20\n20\n1\n2\n5\n-3\n6\n20\n2\n14\n1\n6)
	@printf 'hold s = "x"\nshow (s + 1) * 2\n' > $(TESTS)/ts_parenstr.sa
	@./$(GEN2) $(TESTS)/ts_parenstr.sa $(TESTS)/ts_parenstr_g2.c >/dev/null 2>&1 || true
	@grep -q 'parenthesized expression must be numeric' $(TESTS)/ts_parenstr_g2.c
	@printf 'show (len("ab") + 1) * 2\n' > $(TESTS)/ts_parenb.sa
	@./$(GEN2) $(TESTS)/ts_parenb.sa $(TESTS)/ts_parenb_g2.c >/dev/null 2>&1 || true
	@$(CC) -O2 -o $(TESTS)/ts_parenb_g2 $(TESTS)/ts_parenb_g2.c && test "$$(./$(TESTS)/ts_parenb_g2)" = "6" || { echo "FAILED: len in a parenthesized expression (gen2)"; exit 1; }
	@printf 'show (1 + 2\n' > $(TESTS)/ts_parenu.sa
	@./$(GEN2) $(TESTS)/ts_parenu.sa $(TESTS)/ts_parenu_g2.c >/dev/null 2>&1 || true
	@grep -q "unbalanced '('" $(TESTS)/ts_parenu_g2.c
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_parenu.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted an unbalanced paren"; exit 1; fi
	@echo "[OK] parenthesized expressions: seed-min and gen2 agree ((a + 3) * 4 = 20); non-numeric parens and unbalanced parens are clear errors"

# ---------------------------------------------------------------------------
# test-full-lang: the Stage-2 full language on gen2 (the C seed stays
# pure-min and is expected to REJECT these forms, which is asserted too):
#   for i in A..B { }        for v in LIST { }      break / continue
#   } elif COND { } / } else if COND { }
#   hold x: TYPE = value     make f(a, b: str) -> str
#   and / or / not / true / false
#   += -= *= /= %=           builtins inside give / conditions / parens
# ---------------------------------------------------------------------------
test-full-lang:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold total = 0\nfor i in 0..5 {\n  hold total = total + i\n}\nshow total\nhold k = 1\nfor k in 1..100 {\n  when k == 4 {\n    break\n  }\n}\nshow k\nhold odd = 0\nfor i in 0..10 {\n  when i %% 2 == 0 {\n    continue\n  }\n  hold odd = odd + 1\n}\nshow odd\n' > $(TESTS)/fl_for.sa
	./$(GEN2) $(TESTS)/fl_for.sa $(TESTS)/fl_for.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_for $(TESTS)/fl_for.c
	$(call assert-out,./$(TESTS)/fl_for,10\n4\n5)
	./$(SEED_MIN_BIN) $(TESTS)/fl_for.sa > $(TESTS)/fl_for_seed.c
	$(CC) -O2 -o $(TESTS)/fl_for_seed $(TESTS)/fl_for_seed.c
	$(call assert-out,./$(TESTS)/fl_for_seed,10\n4\n5)
	@printf 'hold xs = [3, 4, 5]\nhold sum = 0\nfor v in xs {\n  hold sum = sum + v\n}\nshow sum\nfor v in xs {\n  when v == 4 {\n    continue\n  }\n  show v\n}\n' > $(TESTS)/fl_list.sa
	./$(GEN2) $(TESTS)/fl_list.sa $(TESTS)/fl_list.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_list $(TESTS)/fl_list.c
	$(call assert-out,./$(TESTS)/fl_list,12\n3\n5)
	@printf 'hold grade = 0\nhold score = 85\nwhen score >= 90 {\n  hold grade = 4\n} elif score >= 80 {\n  hold grade = 3\n} elif score >= 70 {\n  hold grade = 2\n} otherwise {\n  hold grade = 1\n}\nshow grade\nwhen score >= 80 {\n  hold grade = 9\n} elif score >= 70 {\n  hold grade = 8\n}\nshow grade\n' > $(TESTS)/fl_elif.sa
	./$(GEN2) $(TESTS)/fl_elif.sa $(TESTS)/fl_elif.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_elif $(TESTS)/fl_elif.c
	$(call assert-out,./$(TESTS)/fl_elif,3\n9)
	./$(SEED_MIN_BIN) $(TESTS)/fl_elif.sa > $(TESTS)/fl_elif_sm.c
	$(CC) -O2 -o $(TESTS)/fl_elif_sm $(TESTS)/fl_elif_sm.c
	$(call assert-out,./$(TESTS)/fl_elif_sm,3\n9)
	@printf 'make greet(name: str) -> str {\n  give concat("hi ", name)\n}\nmake twice(n: num) -> num {\n  give n * 2\n}\nhold m = greet("ada")\nshow m\nshow twice(21)\nshow len(m)\n' > $(TESTS)/fl_fn.sa
	./$(GEN2) $(TESTS)/fl_fn.sa $(TESTS)/fl_fn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_fn $(TESTS)/fl_fn.c
	$(call assert-out,./$(TESTS)/fl_fn,hi ada\n42\n6)
	@printf 'hold n: num = 4\nhold s: str = "abc"\nhold xs: list = [1, 2]\nshow n + len(xs)\nshow s\nhold ok = 0\nwhen n > 2 and s != "z" {\n  hold ok = 1\n}\nshow ok\nwhen not ok or n == 0 {\n  show 7\n} otherwise {\n  show 8\n}\nhold flag = true\nshow flag\n' > $(TESTS)/fl_type.sa
	./$(GEN2) $(TESTS)/fl_type.sa $(TESTS)/fl_type.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_type $(TESTS)/fl_type.c
	$(call assert-out,./$(TESTS)/fl_type,6\nabc\n1\n8\n1)
	@printf 'hold s = "a"\nhold s += "b"\nshow s\nhold x = 10\nhold x += 5\nhold x -= 3\nhold x *= 2\nshow x\nhold x /= 4\nhold x %%= 4\nshow x\n' > $(TESTS)/fl_comp.sa
	./$(GEN2) $(TESTS)/fl_comp.sa $(TESTS)/fl_comp.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_comp $(TESTS)/fl_comp.c
	$(call assert-out,./$(TESTS)/fl_comp,ab\n24\n2)
	@printf 'hold n: str = 5\n' > $(TESTS)/fl_badtype.sa
	./$(GEN2) $(TESTS)/fl_badtype.sa $(TESTS)/fl_badtype.c >/dev/null 2>&1 || true
	@grep -q "type error: 'n' is declared str but the value is a number" $(TESTS)/fl_badtype.c
	@printf 'hold n = 1\nbreak\n' > $(TESTS)/fl_badbreak.sa
	./$(GEN2) $(TESTS)/fl_badbreak.sa $(TESTS)/fl_badbreak.c >/dev/null 2>&1 || true
	@grep -q "break/continue outside a loop" $(TESTS)/fl_badbreak.c
	@printf 'hold n = 1\nhold m += 1\n' > $(TESTS)/fl_badcomp.sa
	./$(GEN2) $(TESTS)/fl_badcomp.sa $(TESTS)/fl_badcomp.c >/dev/null 2>&1 || true
	@grep -q "compound assignment needs an existing variable" $(TESTS)/fl_badcomp.c
	@printf 'hold xs = [1, 2]\nfor v in xs {\n  break\n}\nhold ys = 1\nfor v in ys {\n}\n' > $(TESTS)/fl_badlist.sa
	./$(GEN2) $(TESTS)/fl_badlist.sa $(TESTS)/fl_badlist.c >/dev/null 2>&1 || true
	@grep -q "for loop: 'ys' is not a list" $(TESTS)/fl_badlist.c
	@echo "[OK] full language: for/break/continue/elif, typed functions, annotations, and/or/not, compound assignment"

# ---------------------------------------------------------------------------
# test-generics: `make NAME<T>(a: T, b: T) -> T { ... }`.  A call asks for one
# specialised copy named NAME__k (k = n, s or l) of the generic body with T
# replaced by the concrete type; the copy is emitted once per kind, and the
# kind of a call is the kind of its own first argument (string literal or
# declared str variable -> s, list literal or declared list variable -> l, the
# fixed kinds of the builtins, the declared return kinds of the other
# functions, and - for a nested generic call - its own first argument again),
# so nested calls, `give`, `when` and arguments of plain calls all work.
# ---------------------------------------------------------------------------
test-generics:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(GEN1_MIN) || (echo "need gen1_min"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'make pickb<T>(a: T, b: T) -> T {\n  give a\n}\nmake twice<T>(a: T) -> T {\n  hold x: T = a\n  give pickb(x, x)\n}\nmake quad<T>(a: T) -> T {\n  give twice(twice(a))\n}\nmake wrap<T>(a: T) -> T {\n  hold t: T = a\n  when len(t) > 0 {\n    hold t = a\n  }\n  give t\n}\nmake shout(n: num) -> str {\n  give concat("v=", numstr(n))\n}\nmake unused<T>(a: T) -> T {\n  give a\n}\nhold xs = [1, 2, 3]\nhold s = "hi"\nshow pickb(3, 7)\nshow twice(4)\nshow twice(s)\nshow quad(2)\nshow twice(twice("z"))\nshow len(quad(xs))\nshow len(twice(s))\nhold y = twice(5)\nshow y + 1\nshow shout(twice(9))\nshow pickb("a", "b")\nwhen twice(6) == 6 {\n  show 12\n}\nhold q = pickb(xs, xs)\nshow len(q)\nshow wrap(s)\nshow len(wrap("ab"))\n' > $(TESTS)/tg.sa
	./$(GEN2) $(TESTS)/tg.sa $(TESTS)/tg.c >/dev/null
	@if grep -q '#error' $(TESTS)/tg.c; then echo "[FAIL] generics: #error in the output"; exit 1; fi
	$(CC) -O2 -o $(TESTS)/tg $(TESTS)/tg.c
	$(call assert-out,./$(TESTS)/tg,3\n4\nhi\n2\nz\n3\n2\n6\nv=9\na\n12\n3\nhi\n2)
	@# one definition per (name, kind) - exactly one, however many calls ask
	@test `grep -c 'static double twice__n(double a) {' $(TESTS)/tg.c` = 1
	@test `grep -c 'static char \*twice__s(char \* a) {' $(TESTS)/tg.c` = 1
	@test `grep -c 'static sx_list \*twice__l(sx_list \* a) {' $(TESTS)/tg.c` = 1
	@test `grep -c 'static double quad__n(double a) {' $(TESTS)/tg.c` = 1
	@test `grep -c 'unused__' $(TESTS)/tg.c` = 0
	@# every call must see a prototype (a definition further down is fine)
	@$(CC) -O2 -Wall -o $(TESTS)/tg-w $(TESTS)/tg.c 2>$(TESTS)/tg.warn
	@if grep -q 'implicit declaration' $(TESTS)/tg.warn; then echo "[FAIL] generics: a call without a prototype"; exit 1; fi
	@# the same program through the seed-built compiler must agree
	./$(GEN1_MIN) $(TESTS)/tg.sa $(TESTS)/tg_g1.c >/dev/null
	$(CC) -O2 -o $(TESTS)/tg_g1 $(TESTS)/tg_g1.c
	$(call assert-out,./$(TESTS)/tg_g1,3\n4\nhi\n2\nz\n3\n2\n6\nv=9\na\n12\n3\nhi\n2)
	@# This fixture also uses numstr, outside the seed builtin subset.
	@if ./$(SEED_MIN_BIN) $(TESTS)/tg.sa >/dev/null 2>$(TESTS)/tg_seed.err; then \
	  echo "[FAIL] seed-min accepted unsupported numstr builtin"; exit 1; fi
	@grep -q 'unknown or unsupported function' $(TESTS)/tg_seed.err
	@# a generic whose parameters or return type name something other than its
	@# own type parameters gets a clear diagnostic instead of an unsuffixed call
	@printf 'make pair<T>(a: T, b: num) -> T {\n  give a\n}\nshow pair(1, 2)\n' > $(TESTS)/tg_bad.sa
	@./$(GEN2) $(TESTS)/tg_bad.sa $(TESTS)/tg_bad.c >/dev/null 2>&1 || true
	@grep -q "must be written with type parameters used by every parameter" $(TESTS)/tg_bad.c
	@# a generic whose return type names an undeclared type parameter is refused too
	@printf 'make f2<T>(a: T) -> U {\n  give a\n}\nshow f2(1)\n' > $(TESTS)/tg_bad2.sa
	@./$(GEN2) $(TESTS)/tg_bad2.sa $(TESTS)/tg_bad2.c >/dev/null 2>&1 || true
	@grep -q "must be written with type parameters used by every parameter" $(TESTS)/tg_bad2.c
	@# ---- multi-parameter generics: make NAME<A, B>(...) ----------------------
	@# every type parameter gets its own kind, taken from the argument that uses
	@# it, so the specialised name carries one kind character per parameter
	@printf 'make pair<A, B>(a: A, b: B) -> A {\n  give a\n}\nmake swap<A, B>(a: A, b: B) -> B {\n  give b\n}\nmake three<A, B, C>(a: A, b: B, c: C) -> C {\n  give c\n}\nmake usefirst<A, B>(a: A, b: B) -> A {\n  hold r: A = pair(a, b)\n  give r\n}\nhold xs = [1, 2, 3]\nhold s = "hi"\nshow pair(1, "x")\nshow swap(1, "x")\nshow swap("x", 1)\nshow pair("x", 1)\nshow pair(1, 2)\nshow len(three(1, "x", xs))\nshow usefirst(5, s)\nshow len(usefirst(xs, s))\nshow len(usefirst(xs, 7))\nshow pair(s, xs)\n' > $(TESTS)/tg_mp.sa
	./$(GEN2) $(TESTS)/tg_mp.sa $(TESTS)/tg_mp.c >/dev/null
	@if grep -q '#error' $(TESTS)/tg_mp.c; then echo "[FAIL] multi-param generics: #error in the output"; exit 1; fi
	$(CC) -O2 -o $(TESTS)/tg_mp $(TESTS)/tg_mp.c
	$(call assert-out,./$(TESTS)/tg_mp,1\nx\n1\nx\n1\n3\n5\n3\n3\nhi)
	@# one definition per (name, kinds), however many calls ask for it
	@test `grep -c 'static double pair__nn(double a, double b) {' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static double  pair__ns(double a, char \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static char \*  pair__sn(char \* a, double b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static sx_list \*  pair__ls(sx_list \* a, char \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static sx_list \*  pair__ln(sx_list \* a, double b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static char \*  pair__sl(char \* a, sx_list \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static sx_list \*  three__nsl(double a, char \* b, sx_list \* c);' $(TESTS)/tg_mp.c` = 1
	@# a return type that is the second parameter of the generic, not the first
	@test `grep -c 'static char \*  swap__ns(double a, char \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static double  swap__sn(char \* a, double b);' $(TESTS)/tg_mp.c` = 1
	@# a generic calling a two-parameter generic: the callee is specialised with
	@# its own kinds, and `hold v: T = callee(..)` inside the body knows the result
	@test `grep -c 'static sx_list \*  usefirst__ls(sx_list \* a, char \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'static double  usefirst__ns(double a, char \* b);' $(TESTS)/tg_mp.c` = 1
	@test `grep -c 'sx_list \*r = pair__ls(a,b);' $(TESTS)/tg_mp.c` = 1
	@# every call must see a prototype
	@$(CC) -O2 -Wall -o $(TESTS)/tg_mp-w $(TESTS)/tg_mp.c 2>$(TESTS)/tg_mp.warn
	@if grep -q 'implicit declaration' $(TESTS)/tg_mp.warn; then echo "[FAIL] multi-param generics: a call without a prototype"; exit 1; fi
	@# the same program through the seed-built compiler must agree byte for byte
	./$(GEN1_MIN) $(TESTS)/tg_mp.sa $(TESTS)/tg_mp_g1.c >/dev/null
	@diff $(TESTS)/tg_mp.c $(TESTS)/tg_mp_g1.c >/dev/null || { echo "[FAIL] multi-param generics: gen1_min output differs"; exit 1; }
	$(CC) -O2 -o $(TESTS)/tg_mp_g1 $(TESTS)/tg_mp_g1.c
	$(call assert-out,./$(TESTS)/tg_mp_g1,1\nx\n1\nx\n1\n3\n5\n3\n3\nhi)
	./$(SEED_MIN_BIN) $(TESTS)/tg_mp.sa > $(TESTS)/tg_mp_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/tg_mp_seed $(TESTS)/tg_mp_seed.c
	$(call assert-out,./$(TESTS)/tg_mp_seed,1\nx\n1\nx\n1\n3\n5\n3\n3\nhi)
	./$(NATIVE_BIN) $(TESTS)/tg_mp.sa $(TESTS)/tg_mp_nat
	$(call assert-out,./$(TESTS)/tg_mp_nat,1\nx\n1\nx\n1\n3\n5\n3\n3\nhi)
	@echo "[OK] generics: one copy per call-site kind, nested and cross-generic calls, T = num/str/list, multi-parameter <A, B> and <A, B, C>, gen2 and gen1_min agree"


# ---------------------------------------------------------------------------
# test-push-stmt: bare `push(xs, v)` statement == `hold xs = push(xs, v)` on
# seed-min and gen2 (native already had it).  Pushing onto a non-list, an
# unknown statement word and leftover tokens are clear errors on both.
# ---------------------------------------------------------------------------
test-push-stmt:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold xs = []\npush(xs, 5)\npush(xs, 6 + 1)\nhold i = 0\nwhile i < 3 {\n  push(xs, i * 10)\n  hold i = i + 1\n}\nshow len(xs)\nshow xs[1]\nshow xs[4]\n' > $(TESTS)/ts_push.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_push.sa > $(TESTS)/ts_push_sm.c
	$(CC) -O2 -o $(TESTS)/ts_push_sm $(TESTS)/ts_push_sm.c
	$(call assert-out,./$(TESTS)/ts_push_sm,5\n7\n20)
	./$(GEN2) $(TESTS)/ts_push.sa $(TESTS)/ts_push_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_push_g2 $(TESTS)/ts_push_g2.c
	$(call assert-out,./$(TESTS)/ts_push_g2,5\n7\n20)
	@printf 'hold n = 1\npush(n, 5)\n' > $(TESTS)/ts_pushbad.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_pushbad.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted push onto a number"; exit 1; fi
	@./$(SEED_MIN_BIN) $(TESTS)/ts_pushbad.sa 2>&1 >/dev/null | grep -q "'n' is not a list"
	@./$(GEN2) $(TESTS)/ts_pushbad.sa $(TESTS)/ts_pushbad_g2.c >/dev/null 2>&1 || true
	@grep -q "'n' is not a list" $(TESTS)/ts_pushbad_g2.c
	@printf 'hold i = 0\nwhile i < 3 {\n  hold i = i + 1\n  when i == 2 { kantho }\n}\n' > $(TESTS)/ts_unkstmt.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_unkstmt.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted an unknown statement"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_unkstmt.sa $(TESTS)/ts_unkstmt_g2.c >/dev/null 2>&1 || true
	@grep -q "unknown statement 'kantho'" $(TESTS)/ts_unkstmt_g2.c
	@# continue in while is shared with seed-min
	@printf 'hold i = 0\nwhile i < 3 {\n  hold i = i + 1\n  when i == 2 { continue }\n}\nshow i\n' > $(TESTS)/ts_cont.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_cont.sa > $(TESTS)/ts_cont_sm.c
	$(CC) -O2 -o $(TESTS)/ts_cont_sm $(TESTS)/ts_cont_sm.c
	$(call assert-out,./$(TESTS)/ts_cont_sm,3)
	./$(GEN2) $(TESTS)/ts_cont.sa $(TESTS)/ts_cont_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_cont_g2 $(TESTS)/ts_cont_g2.c
	$(call assert-out,./$(TESTS)/ts_cont_g2,3)
	@printf 'hold a = 1\nshow a b\n' > $(TESTS)/ts_junk.sa
	@./$(GEN2) $(TESTS)/ts_junk.sa $(TESTS)/ts_junk_g2.c >/dev/null 2>&1 || true
	@grep -q '#error' $(TESTS)/ts_junk_g2.c
	@printf 'hold xs = [1, 2]\nhold ys = xs\npush(ys, 9)\nshow ys[2]\nshow len(ys)\n' > $(TESTS)/ts_lalias.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_lalias.sa > $(TESTS)/ts_lalias_sm.c
	$(CC) -O2 -o $(TESTS)/ts_lalias_sm $(TESTS)/ts_lalias_sm.c
	$(call assert-out,./$(TESTS)/ts_lalias_sm,9\n3)
	./$(GEN2) $(TESTS)/ts_lalias.sa $(TESTS)/ts_lalias_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_lalias_g2 $(TESTS)/ts_lalias_g2.c
	$(call assert-out,./$(TESTS)/ts_lalias_g2,9\n3)
	@printf 'hold xs = [1]\nhold ys = xs + 1\n' > $(TESTS)/ts_lop.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_lop.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted + on a list (pointer arithmetic)"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_lop.sa $(TESTS)/ts_lop_g2.c >/dev/null 2>&1 || true
	@grep -q "list 'xs' can only be held whole" $(TESTS)/ts_lop_g2.c
	@printf 'hold s = "a"\nshow s - 1\n' > $(TESTS)/ts_sop.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_sop.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted - on a string (pointer arithmetic)"; exit 1; fi
	@echo "[OK] bare push(xs, v): seed-min and gen2 agree; push onto a non-list and unknown statements are clear errors"
	@printf 'hold xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]\nshow len(xs)\nshow xs[10]\n' > $(TESTS)/ts_l11.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_l11.sa > $(TESTS)/ts_l11_sm.c
	$(CC) -O2 -o $(TESTS)/ts_l11_sm $(TESTS)/ts_l11_sm.c
	$(call assert-out,./$(TESTS)/ts_l11_sm,11\n11)
	./$(GEN2) $(TESTS)/ts_l11.sa $(TESTS)/ts_l11_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_l11_g2 $(TESTS)/ts_l11_g2.c
	$(call assert-out,./$(TESTS)/ts_l11_g2,11\n11)
	@printf 'struct P {\n  x\n}\nhold p = P { x: 1 }\nhold xs = [p]\n' > $(TESTS)/ts_sinl.sa
	@printf 'struct P {\n  x\n}\nhold p = P { x: 1 }\nhold xs = []\npush(xs, p)\n' > $(TESTS)/ts_sinl2.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_sinl.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted a struct in a list"; exit 1; fi
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_sinl2.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted push of a struct"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_sinl.sa $(TESTS)/ts_sinl_g2.c >/dev/null 2>&1 || true
	@grep -q 'list elements must be numbers' $(TESTS)/ts_sinl_g2.c
	@./$(GEN2) $(TESTS)/ts_sinl2.sa $(TESTS)/ts_sinl2_g2.c >/dev/null 2>&1 || true
	@grep -q "push: 'p' is not a number" $(TESTS)/ts_sinl2_g2.c
	@printf 'hold s = "a"\nhold n = 4\nshow s + n\n' > $(TESTS)/ts_strnum.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_strnum.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted string + number"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_strnum.sa $(TESTS)/ts_strnum_g2.c >/dev/null 2>&1 || true
	@grep -q "'n' is not a string" $(TESTS)/ts_strnum_g2.c
	@printf 'hold s = "a"\nshow 3 + s\n' > $(TESTS)/ts_numstr.sa
	@./$(GEN2) $(TESTS)/ts_numstr.sa $(TESTS)/ts_numstr_g2.c >/dev/null 2>&1 || true
	@grep -q "is a string but the left side is not" $(TESTS)/ts_numstr_g2.c
	@printf 'hold s = "a"\nshow s * 2\n' > $(TESTS)/ts_strmul.sa
	@./$(GEN2) $(TESTS)/ts_strmul.sa $(TESTS)/ts_strmul_g2.c >/dev/null 2>&1 || true
	@grep -q "only + works on strings (found '\*')" $(TESTS)/ts_strmul_g2.c
	@printf 'hold xs = ["a"]\n' > $(TESTS)/ts_strlist.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_strlist.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted a string list element"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_strlist.sa $(TESTS)/ts_strlist_g2.c >/dev/null 2>&1 || true
	@grep -q 'list elements must be numbers' $(TESTS)/ts_strlist_g2.c
	@echo "[OK] string + number, string * number and a string list element are clear errors on seed-min and gen2 (gen2 used to paste the variable NAME: s + n printed an; seed-min emitted invalid C for [\"a\"])"
	@echo "[OK] list literals with 10+ elements on seed-min and gen2; a struct in a list (literal or push) is a clear error on both"
	@echo "[OK] hold ys = xs (whole list) on seed-min and gen2; + / - on a list or string-minus-number are clear errors, never pointer arithmetic"

# ---------------------------------------------------------------------------
# test-native-num: native numbers are IEEE doubles, like seed-min and gen2.
# The same programs as test-float / test-parens / test-push-stmt must give
# the same output natively; `show` formats like printf("%g") (checked against
# seed-min over ~3500 values); / by zero follows IEEE and % by zero reports
# `division by zero`; regressions for
# native parser fixes found while doing this (comment line after a number,
# `while n {`, a comparison inside parens, a call statement before a block,
# the missing newline after "[list len=N]").  The statement/type subset is the
# pure-min one here too: string + number and a bare call other than
# push(xs, v) are rejected, matching seed-min and gen2.
# ---------------------------------------------------------------------------
test-native-num: $(NATIVE_BIN)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@test -f $(TESTS)/ts_big.sa && test -f $(TESTS)/ts_modzero.sa || $(MAKE) --no-print-directory test-float
	@test -f $(TESTS)/ts_parens.sa || $(MAKE) --no-print-directory test-parens
	@test -f $(TESTS)/ts_push.sa || $(MAKE) --no-print-directory test-push-stmt
	./$(NATIVE_BIN) $(TESTS)/ts_float.sa $(TESTS)/ts_float_nat
	$(call assert-out,./$(TESTS)/ts_float_nat,2.5\n5\n2.5\n7\n0.333333\n1.5\n1.25\n1\n2\n0.75\n-1.5\n1)
	./$(NATIVE_BIN) $(TESTS)/ts_big.sa $(TESTS)/ts_big_nat
	$(call assert-out,./$(TESTS)/ts_big_nat,1e+10\n1.00001e+10\n1e+10\n5e+09\n1e+10\n1\n1e+10\n1e+10)
	./$(NATIVE_BIN) $(TESTS)/ts_modzero.sa $(TESTS)/ts_modzero_nat
	@if ./$(TESTS)/ts_modzero_nat >/dev/null 2>$(TESTS)/ts_modzero_nat.err; then echo "[FAIL] native accepted modulo by zero"; exit 1; fi
	@grep -q 'division by zero' $(TESTS)/ts_modzero_nat.err
	./$(NATIVE_BIN) $(TESTS)/ts_parens.sa $(TESTS)/ts_parens_nat
	$(call assert-out,./$(TESTS)/ts_parens_nat,20\n20\n1\n2\n5\n-3\n6\n20\n2\n14\n1\n6)
	./$(NATIVE_BIN) $(TESTS)/ts_push.sa $(TESTS)/ts_push_nat
	$(call assert-out,./$(TESTS)/ts_push_nat,5\n7\n20)
	@printf 'hold x = 0.0000000001\nhold i = 0\nwhile i < 400 {\n  show x\n  show 0 - x / 7\n  show x * 3.3 + 1\n  hold x = x * 1.37\n  hold i = i + 1\n}\nhold j = 0\nwhile j < 800 {\n  show j / 7\n  show j * j / 13\n  show j %% 17\n  hold j = j + 1\n}\nshow 999999.5\nshow 123456789\nshow 0.0001\nshow 0.00001234\nshow 0 - 0\n' > $(TESTS)/ts_fmt.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_fmt.sa > $(TESTS)/ts_fmt_sm.c
	$(CC) -O2 -o $(TESTS)/ts_fmt_sm $(TESTS)/ts_fmt_sm.c
	./$(NATIVE_BIN) $(TESTS)/ts_fmt.sa $(TESTS)/ts_fmt_nat
	@if [ "$$(./$(TESTS)/ts_fmt_nat)" = "$$(./$(TESTS)/ts_fmt_sm)" ]; then :; else \
	  echo "[FAIL] native number formatting differs from seed-min (printf %g)"; exit 1; fi
	@printf 'show 1 / 0\nshow 0 - 1 / 0\nshow 0 / 0\n' > $(TESTS)/ts_div0.sa
	./$(NATIVE_BIN) $(TESTS)/ts_div0.sa $(TESTS)/ts_div0_nat
	$(call assert-out,./$(TESTS)/ts_div0_nat,inf\n-inf\n-nan)
	@# parity: the shared subset has no string + number and no bare call other
	@# than push(xs, v).  native used to accept both (the number went through
	@# %g), so a program that only ran natively looked fine here and failed on
	@# seed-min/gen2.  Reuse test-push-stmt's programs and pin the rejections.
	@test -f $(TESTS)/ts_strnum.sa || $(MAKE) --no-print-directory test-push-stmt
	@if ./$(NATIVE_BIN) $(TESTS)/ts_strnum.sa $(TESTS)/ts_strnum_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted a string + a number"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/ts_strnum.sa $(TESTS)/ts_strnum_nat 2>&1 | grep -q 'a string + a number is not in the pure-min subset'
	@if ./$(NATIVE_BIN) $(TESTS)/ts_numstr.sa $(TESTS)/ts_numstr_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted a number + a string"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/ts_numstr.sa $(TESTS)/ts_numstr_nat 2>&1 | grep -q 'a string + a number is not in the pure-min subset'
	@printf 'write_file("$(TESTS)/ts_barecall.txt", "x")\nshow 1\n' > $(TESTS)/ts_barecall.sa
	@if ./$(NATIVE_BIN) $(TESTS)/ts_barecall.sa $(TESTS)/ts_barecall_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted a bare write_file(...) statement"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/ts_barecall.sa $(TESTS)/ts_barecall_nat 2>&1 | grep -q 'unknown statement: "write_file"'
	@printf 'make f(n) {\n  give n\n}\nf(1)\n' > $(TESTS)/ts_bareuser.sa
	@if ./$(NATIVE_BIN) $(TESTS)/ts_bareuser.sa $(TESTS)/ts_bareuser_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted a bare user-function call statement"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/ts_bareuser.sa $(TESTS)/ts_bareuser_nat 2>&1 | grep -q 'unknown statement: "f"'
	@printf 'struct U {\n  name\n}\nhold u = U { name: "x" }\nhold t = u.name + "y"\nshow t\nshow u.name + "z"\n' > $(TESTS)/ts_fcat_n.sa
	./$(NATIVE_BIN) $(TESTS)/ts_fcat_n.sa $(TESTS)/ts_fcat_nat
	$(call assert-out,./$(TESTS)/ts_fcat_nat,xy\nxz)
	@printf 'show 1 / 0\nshow 0 - 1 / 0\nshow 0 / 0\n' > $(TESTS)/ts_div0b.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_div0b.sa > $(TESTS)/ts_div0b_sm.c
	$(CC) -O2 -o $(TESTS)/ts_div0b_sm $(TESTS)/ts_div0b_sm.c 2>/dev/null
	$(call assert-out,./$(TESTS)/ts_div0b_sm,inf\n-inf\n-nan)
	@printf 'show 7 %% 0.5\n' > $(TESTS)/ts_mod0.sa
	./$(NATIVE_BIN) $(TESTS)/ts_mod0.sa $(TESTS)/ts_mod0_nat
	@./$(TESTS)/ts_mod0_nat 2>&1 | grep -q 'division by zero'
	@printf 'hold x = 2.\n' > $(TESTS)/ts_floatbad_nat.sa
	@if ./$(NATIVE_BIN) $(TESTS)/ts_floatbad_nat.sa $(TESTS)/ts_floatbad_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted the malformed literal 2."; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/ts_floatbad_nat.sa $(TESTS)/ts_floatbad_nat 2>&1 | grep -q 'malformed number literal'
	@printf 'hold n = 3\n// a comment line right after a number\nwhile n {\n  hold n = n - 1\n}\nshow (n > 1) + (n < 1)\nhold xs = [1]\npush(xs, 2.5)\nhold k = 0\nwhile k < 2 {\n  hold k = k + 0.5\n}\nshow k\nshow xs\nshow xs[1]\n' > $(TESTS)/ts_natfix.sa
	./$(NATIVE_BIN) $(TESTS)/ts_natfix.sa $(TESTS)/ts_natfix_nat
	$(call assert-out,./$(TESTS)/ts_natfix_nat,1\n2\n[list len=2]\n2.5)
	./$(SEED_MIN_BIN) $(TESTS)/ts_natfix.sa > $(TESTS)/ts_natfix_sm.c
	$(CC) -O2 -o $(TESTS)/ts_natfix_sm $(TESTS)/ts_natfix_sm.c
	$(call assert-out,./$(TESTS)/ts_natfix_sm,1\n2\n[list len=2]\n2.5)
	@test -f $(TESTS)/ts_lalias.sa || $(MAKE) --no-print-directory test-push-stmt
	./$(NATIVE_BIN) $(TESTS)/ts_lalias.sa $(TESTS)/ts_lalias_nat
	$(call assert-out,./$(TESTS)/ts_lalias_nat,9\n3)
	@if ./$(NATIVE_BIN) $(TESTS)/ts_lop.sa $(TESTS)/ts_lop_nat 2>/dev/null; then \
	  echo "[FAIL] native accepted + on a list"; exit 1; fi
	./$(NATIVE_BIN) $(TESTS)/ts_l11.sa $(TESTS)/ts_l11_nat
	$(call assert-out,./$(TESTS)/ts_l11_nat,11\n11)
	@if ./$(NATIVE_BIN) $(TESTS)/ts_sinl.sa $(TESTS)/ts_sinl_nat 2>/dev/null; then echo "[FAIL] native accepted a struct in a list"; exit 1; fi
	@if ./$(NATIVE_BIN) $(TESTS)/ts_sinl2.sa $(TESTS)/ts_sinl2_nat 2>/dev/null; then echo "[FAIL] native accepted push of a struct"; exit 1; fi
	@echo "[OK] native doubles: literals, large constant arithmetic, true division, truncating % and matching % by zero diagnostic; %g formatting and shared tests match seed-min/gen2; string + number and bare non-push calls are rejected exactly like seed-min and gen2"

# ---------------------------------------------------------------------------
# test-native-io: read_file / write_file / arg / arg_count natively, with
# seed-min and gen2 semantics: arg_count() counts argv[0]; arg(0) is the
# binary path; out-of-range arg is ""; write_file truncates and returns 1
# (0 if the file cannot be opened); read_file of a missing file is "".  A
# 160 KiB round trip exercises reads/allocations above the 64 KiB chunk.
# ---------------------------------------------------------------------------
test-native-io: $(NATIVE_BIN)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'show arg_count()\nshow arg(1)\nshow arg(2)\nshow len(arg(7))\nhold p = "$(TESTS)/io_small.txt"\nshow write_file(p, "a first line that is long")\nshow write_file(p, "short")\nshow read_file(p)\nshow len(read_file("$(TESTS)/io_does_not_exist.txt"))\nshow write_file("$(TESTS)/io_no_such_dir/x.txt", "y")\nhold s = "0123456789"\nhold i = 0\nwhile i < 14 {\n  hold s = concat(s, s)\n  hold i = i + 1\n}\nshow write_file("$(TESTS)/io_big.txt", s)\nhold b = read_file("$(TESTS)/io_big.txt")\nshow len(b)\nshow b[163839]\nshow arg(0)\n' > $(TESTS)/ts_io.sa
	./$(NATIVE_BIN) $(TESTS)/ts_io.sa $(TESTS)/ts_io_nat
	$(call assert-out,./$(TESTS)/ts_io_nat alpha "beta gamma",3\nalpha\nbeta gamma\n0\n1\n1\nshort\n0\n0\n1\n163840\n57\n./$(TESTS)/ts_io_nat)
	./$(SEED_MIN_BIN) $(TESTS)/ts_io.sa > $(TESTS)/ts_io_sm.c
	$(CC) -O2 -o $(TESTS)/ts_io_sm $(TESTS)/ts_io_sm.c
	$(call assert-out,./$(TESTS)/ts_io_sm alpha "beta gamma",3\nalpha\nbeta gamma\n0\n1\n1\nshort\n0\n0\n1\n163840\n57\n./$(TESTS)/ts_io_sm)
	@if [ -x $(GEN2) ]; then \
	  ./$(GEN2) $(TESTS)/ts_io.sa $(TESTS)/ts_io_g2.c >/dev/null && \
	  $(CC) -O2 -o $(TESTS)/ts_io_g2 $(TESTS)/ts_io_g2.c && \
	  __got=$$(./$(TESTS)/ts_io_g2 alpha "beta gamma") && \
	  __want=$$(printf '3\nalpha\nbeta gamma\n0\n1\n1\nshort\n0\n0\n1\n163840\n57\n./$(TESTS)/ts_io_g2') && \
	  if [ "$$__got" = "$$__want" ]; then :; else echo "[FAIL] gen2 I/O output differs"; printf '%s\n' "$$__got"; exit 1; fi; \
	fi
	@echo "[OK] native read_file/write_file/arg/arg_count: same results as seed-min and gen2 (argv[0] counted, truncating write returns 1, missing file reads as \"\", 160 KiB round trip)"

# ---------------------------------------------------------------------------
# test-native-mem: the native AOT emitter has a real collector (docs/GC.md,
# "The native collector").  Blocks are 32-byte headers over mmap()ed chunks,
# r_malloc is first-fit over a free list and then bumps, and a mark & sweep
# pass runs at every statement boundary once the allocation debt passes a
# threshold.  These tests pin what that actually means:
#
#   * long allocating loops (4001-byte string built by 2000 concats, 1500
#     pushes) keep computing correct values and indexes;
#   * a 200k-iteration churn loop (~8 MB allocated, nothing retained) now
#     stays inside a 4 MiB address-space cap instead of dying -- that is the
#     whole point of the free path, and it is exactly what the old bump
#     allocator could not do;
#   * gc() / gc_live() / gc_runs() are real on native: gc() returns the bytes
#     it reclaimed, gc_runs() counts the collections and gc_live() reports the
#     bytes the last sweep saw alive;
#   * values survive collections: strings, list elements and struct fields all
#     still read back correctly after tens of thousands of allocating
#     iterations, so nothing is reclaimed while it is still reachable;
#   * a program that genuinely retains more than 4 MiB still dies with the
#     documented `out of memory` diagnostic and a non-zero exit status, and
#     keeps the output it wrote before dying.
# ---------------------------------------------------------------------------
test-native-mem: $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold s = "x"\nhold i = 0\nwhile i < 2000 {\n  hold s = concat(s, "ab")\n  hold i = i + 1\n}\nshow len(s)\nshow s[0]\nshow s[4000]\nhold xs = []\nhold j = 0\nwhile j < 1500 {\n  push(xs, j * 2)\n  hold j = j + 1\n}\nshow len(xs)\nshow xs[1499]\nhold t = concat("", "tail")\nshow t\n' > $(TESTS)/native_mem.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem.sa $(TESTS)/native_mem
	$(call assert-out,./$(TESTS)/native_mem,4001\n120\n98\n1500\n2998\ntail)
	@# ---- the free path: 200k allocating iterations under a 4 MiB cap ----
	@printf 'hold i = 0\nwhile i < 200000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow i\nshow gc_runs()\n' > $(TESTS)/native_mem_oom.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem_oom.sa $(TESTS)/native_mem_oom
	@__o=$$(sh -c 'ulimit -v 4096; ./$(TESTS)/native_mem_oom') || { \
	  echo "[FAIL] native churn loop died inside a 4 MiB cap (the collector must reclaim)"; exit 1; }; \
	  printf '%s\n' "$$__o" | { \
	    IFS= read -r __i; IFS= read -r __r; \
	    if [ "$$__i" != "200000" ]; then \
	      echo "[FAIL] native churn loop under a 4 MiB cap printed $$__i"; exit 1; fi; \
	    if [ "$$__r" -lt 1 ] 2>/dev/null; then \
	      echo "[FAIL] native churn loop under a 4 MiB cap ran no collection"; exit 1; fi; }
	@echo "[OK] native collector: 200k allocating iterations (~8 MB) stay inside a 4 MiB cap"
	@# ---- gc() / gc_live() / gc_runs() are real, not no-ops ----
	@printf 'hold i = 0\nwhile i < 5000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow gc_runs()\nshow gc()\nshow gc_live()\n' > $(TESTS)/native_mem_gc.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem_gc.sa $(TESTS)/native_mem_gc
	@__o=$$(./$(TESTS)/native_mem_gc); \
	  printf '%s\n' "$$__o" | { \
	    IFS= read -r __r; IFS= read -r __c; IFS= read -r __l; \
	    if [ "$$__r" -lt 1 ] 2>/dev/null; then \
	      echo "[FAIL] native gc_runs() reported $$__r after 5000 allocating iterations"; exit 1; fi; \
	    if [ "$$__c" -lt 1 ] 2>/dev/null; then \
	      echo "[FAIL] native gc() reclaimed $$__c bytes"; exit 1; fi; \
	    if [ "$$__l" -lt 1 ] 2>/dev/null; then \
	      echo "[FAIL] native gc_live() reported $$__l"; exit 1; fi; }
	@echo "[OK] native gc()/gc_live()/gc_runs() are real (collections run, bytes are reclaimed, live bytes reported)"
	@# ---- nothing reachable is reclaimed: strings, lists and structs ----
	@printf 'struct Box {\n  n,\n  s\n}\nhold b = Box { 1, "hello-world" }\nhold a0 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\nhold a3 = "dddddddddddddddddddddddddddd"\nhold xs = []\nhold i = 0\nwhile i < 30000 {\n  hold junk = concat("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", "yyyyyyyyyyyyyyyyyyyyyyyyyy")\n  push(xs, i)\n  hold i = i + 1\n}\nshow len(a0)\nshow a0[0]\nshow a0[47]\nshow a3[27]\nshow b.n\nshow b.s\nshow len(xs)\nshow xs[0]\nshow xs[29999]\n' > $(TESTS)/native_mem_keep.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem_keep.sa $(TESTS)/native_mem_keep
	$(call assert-out,./$(TESTS)/native_mem_keep,48\n97\n97\n100\n1\nhello-world\n30000\n0\n29999)
	@echo "[OK] native collector keeps reachable strings, list elements and struct fields (30k allocating iterations)"
	@# ---- the bump-only contract that still holds: whole-chunk allocations ----
	@# a single allocation bigger than one 64 KiB chunk is served whole
	@printf 'hold s = "x"\nhold i = 0\nwhile i < 18 {\n  hold s = concat(s, s)\n  hold i = i + 1\n}\nshow len(s)\nshow s[262143]\n' > $(TESTS)/native_bigalloc.sa
	./$(NATIVE_BIN) $(TESTS)/native_bigalloc.sa $(TESTS)/native_bigalloc
	$(call assert-out,./$(TESTS)/native_bigalloc,262144\n120)
	@# 100k list elements: growth by doubling crosses many chunks, every value kept
	@printf 'hold xs = []\nhold j = 0\nwhile j < 100000 {\n  push(xs, j)\n  hold j = j + 1\n}\nshow len(xs)\nshow xs[0]\nshow xs[99999]\n' > $(TESTS)/native_biglist.sa
	./$(NATIVE_BIN) $(TESTS)/native_biglist.sa $(TESTS)/native_biglist
	$(call assert-out,./$(TESTS)/native_biglist,100000\n0\n99999)
	@# a smaller churn loop still fits under the cap
	@printf 'hold i = 0\nwhile i < 20000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow i\n' > $(TESTS)/native_mem_fit.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem_fit.sa $(TESTS)/native_mem_fit
	$(call assert-out,sh -c 'ulimit -v 4096; ./$(TESTS)/native_mem_fit',20000)
	@# ---- what the collector cannot do: a genuinely 8 MiB live set ----
	@# output written before an out-of-memory exit is kept, the exit is non-zero
	@printf 'show "before"\nhold s = "abcdefgh"\nhold i = 0\nwhile i < 20 {\n  hold s = concat(s, s)\n  hold i = i + 1\n}\nshow len(s)\nshow "after"\n' > $(TESTS)/native_oom_out.sa
	./$(NATIVE_BIN) $(TESTS)/native_oom_out.sa $(TESTS)/native_oom_out
	@if __got=$$(sh -c 'ulimit -v 4096; ./$(TESTS)/native_oom_out 2>$(TESTS)/native_oom_out.err'); then \
	  echo "[FAIL] native survived the 4 MiB cap while retaining 8 MiB"; exit 1; fi; \
	  [ "$$__got" = before ] || { echo '[FAIL] native OOM lost stdout or continued execution'; exit 1; }
	@grep -q 'out of memory' $(TESTS)/native_oom_out.err
	@echo "[OK] native memory: a real free path (churn fits in 4 MiB, reachable values survive, an 8 MiB live set still dies loudly)"

# ---------------------------------------------------------------------------
# test-seed-gc: what memory management the two SEEDS actually have, MEASURED.
#
# docs/GC.md documents the collectors this repository really has: the gen2/
# gen3/gen4 conservative mark & sweep, the native chunked mmap heap, and the
# refcount runtime in selfhost/seed/sx_runtime.h. Neither seed had ever been
# measured, so the claims below are pinned here instead of asserted in prose.
#
#   sxc_seed_min -- THE BOOTSTRAP SEED (selfhost/seed/sxc_seed_min.c)
#     A conservative mark & sweep over the allocation registry (2026-10-22),
#     on top of the exact registry (2026-10-15) that replaced the unsafe
#     magic-header probe. Builder-backed strings carry {len,cap,next,data[]}
#     and freeing assignments remove old builders from that registry.
#     Concatenation copies into a fresh allocation; it is not an in-place or
#     amortised-O(1) append. See test-seed-borrow for safe borrowed read-only
#     arguments and registry resize/reuse checks.
#       * a string assignment is emitted as
#           { char *_v = sx_cat(a,b); sx_sb_free(a); a = _v; }
#         so the RHS is evaluated into a temp first and the OLD LHS is freed
#         (sx_sb_app itself never frees either side: that would double-free
#         aliased variables). That wrapper still reclaims the common case
#         immediately; the collector exists for what it cannot see -- dropped
#         temporaries, discarded call results, locals never reassigned.
#       * roots are the C stack and nothing else. The program body is emitted
#         as `static int sx_prog(void)` reached through a volatile function
#         pointer, and main plants `sx_gcanchor` above it, so the scan from
#         that anchor down to the collector's own frame covers every Sayanox
#         variable; no heap object in this runtime holds a string pointer
#         (lists hold doubles). Interior pointers are honoured by binary
#         search over the sorted block list, nothing ever moves, and the scan
#         function carries no_sanitize_address -- reading other frames is the
#         point, and test-seed-sanitize runs a collecting fixture under ASan.
#       * first collection at 8 MiB of live builder bytes, then
#         live * 1.5 + 8 MiB; gc() collects on demand and a failing malloc
#         retries once after a collection.
#     Measured: a 200k-iteration concat churn that retains nothing, a 2000-step
#     accumulation to a 2003-char string and a 2000-iteration temp loop all run
#     inside a 4 MiB address space (`ulimit -v 4096` -- that is the floor for a
#     dynamically linked binary, below it libc.so.6 itself cannot be mapped) on
#     the freeing assignment alone, never reaching the collector threshold,
#     while a program that keeps doubling one retained string to 8388608 bytes
#     still dies with `sx: out of memory` on stderr and exit 1, keeping the
#     stdout it already wrote: collecting cannot reclaim a live set.
#     gc()/gc_live()/gc_runs() now exist here too and report real numbers, so
#     all three backends answer the same way; test-seed-collector pins what
#     actually changed, and test-seed-bootstrap-budget pins the consequence
#     for the bootstrap itself (1,278,704 KiB peak RSS -> 29,768 KiB).
#
#   sxc_seed -- the full seed (selfhost/seed/sxc_seed.c + seed/sx_runtime.h)
#     A refcount REPRESENTATION and an object table (SX_TAB_CAP 2097152), with
#     gc() kept as a documented no-op alias that returns 0 -- and, measured, no
#     reclamation in practice: SX_GC_DEBUG=1 reports
#     `6000 objects still alive at exit` after 2000 loop iterations that retain
#     nothing (three objects per iteration: two literals and the result), where
#     the same loop leaves the min seed flat inside 4 MiB. Its static object
#     table also means a 4 MiB cap cannot even start it, so its measurements
#     here run under a 64 MiB cap. Programs using `%` need `-lm` AFTER the
#     sources on the link line (sx_modv calls fmod).
#     This target also pins the lexer fix that made the full seed usable: P1()
#     recorded an operator token's text as `#ch`, i.e. WITH the char literal's
#     quotes ("'*'", "'<'"), so emit_expr matched none of its operator
#     spellings and dropped the operator from the generated C.
#
#   gen2 -- the self-hosted pure-min compiler (selfhost/compiler_min.sa)
#     A real conservative mark & sweep; test-gc pins gc()/gc_live()/gc_runs().
#     Its first collection only fires at 8 MiB of managed heap
#     (sx_gc_thresh = 8u << 20, afterwards live * 1.5 + 4 MiB), so it needs far
#     more address space than native: the 200k churn that native runs inside
#     4 MiB (test-native-mem) needs 64 MiB here and cannot run in 16 MiB. That
#     used to be a SEGFAULT, because the collector ignored its own calloc and
#     malloc results; all three allocation sites in the emitted runtime are now
#     checked and fail as `sx: out of memory` with exit 1.
#
#   native -- see test-native-mem: chunked mmap heap, collection at every
#     statement boundary once the allocation debt passes a threshold, 200k
#     churn inside 4 MiB, and an 8 MiB live set that dies loudly.
#
# Known divergence pinned below rather than hidden: for the same program the
# full seed prints a large integer as `8388608` where seed-min/gen2/native
# print `8.38861e+06`.
# ---------------------------------------------------------------------------
.PHONY: test-seed-gc
test-seed-gc: $(GEN2) $(SEED_MIN_BIN) seed-bin
	mkdir -p $(TESTS)
	# ---- build all five fixtures with all three seed/gen2 backends ----
	set -e; for f in churn grow retain ops tmp; do \
	  ./$(SEED_MIN_BIN) selfhost/seed_gc_$$f.sa > $(TESTS)/sgc_$${f}_ms.c; \
	  $(CC) -O2 -o $(TESTS)/sgc_$${f}_ms $(TESTS)/sgc_$${f}_ms.c; \
	  ./$(GEN2) selfhost/seed_gc_$$f.sa $(TESTS)/sgc_$${f}_g2.c >/dev/null; \
	  $(CC) -O2 -o $(TESTS)/sgc_$${f}_g2 $(TESTS)/sgc_$${f}_g2.c; \
	  ./$(SEED_BIN) selfhost/seed_gc_$$f.sa > $(TESTS)/sgc_$${f}_fs.c; \
	  $(CC) -O2 -I selfhost/seed -o $(TESTS)/sgc_$${f}_fs $(TESTS)/sgc_$${f}_fs.c -lm; \
	done
	# ---- seed-min: builder, freeing assignment, collector behind both ----
	grep -q -F 'sx_sb_register(h)' $(TESTS)/sgc_grow_ms.c
	grep -q -F 'sx_sb_free(' $(TESTS)/sgc_grow_ms.c
	grep -q -F 'sx_gc_collect();' $(TESTS)/sgc_grow_ms.c
	$(call assert-out,sh -c 'ulimit -v 4096; ./$(TESTS)/sgc_churn_ms',200000)
	$(call assert-out,sh -c 'ulimit -v 4096; ./$(TESTS)/sgc_grow_ms',2003\n97\n120)
	$(call assert-out,sh -c 'ulimit -v 4096; ./$(TESTS)/sgc_tmp_ms',2000)
	echo "[OK] seed-min: 200k churn, a 2000-step accumulation and a temp loop all stay inside a 4 MiB address space on the freeing assignment alone (the 8 MiB collector threshold is never reached there)"
	# ---- seed-min: an 8 MiB live set dies loudly, not silently ----
	if __got=$$(sh -c 'ulimit -v 4096; ./$(TESTS)/sgc_retain_ms 2>$(TESTS)/sgc_retain_ms.err'); then \
	  echo "[FAIL] seed-min survived a 4 MiB cap while retaining 8388608 bytes"; exit 1; fi; \
	  [ "$$__got" = before ] || { echo "[FAIL] seed-min OOM lost stdout or continued: $$__got"; exit 1; }
	grep -q -F 'sx: out of memory' $(TESTS)/sgc_retain_ms.err
	echo "[OK] seed-min: an 8 MiB live set inside a 4 MiB cap exits 1 with \`sx: out of memory\` and keeps the stdout it already wrote"
	# ---- seed-min has the collector builtins now, and they are not no-ops ----
	printf 'show gc()\nshow gc_runs()\nshow gc_live()\n' > $(TESTS)/sgc_gc_ms.sa
	./$(SEED_MIN_BIN) $(TESTS)/sgc_gc_ms.sa > $(TESTS)/sgc_gc_ms.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sgc_gc_ms $(TESTS)/sgc_gc_ms.c
	$(call assert-out,./$(TESTS)/sgc_gc_ms,0\n1\n0)
	printf 'show gc(1)\n' > $(TESTS)/sgc_gc_bad.sa
	if ./$(SEED_MIN_BIN) $(TESTS)/sgc_gc_bad.sa > /dev/null 2>$(TESTS)/sgc_gc_bad.err; then \
	  echo "[FAIL] seed-min accepted gc(1), which takes no arguments"; exit 1; fi
	grep -q -F 'seed_min:' $(TESTS)/sgc_gc_bad.err
	echo "[OK] seed-min: gc()/gc_live()/gc_runs() exist and report real numbers (nothing to free in an empty program, one collection counted); a wrong arity still gets a seed_min: diagnostic"
	# ---- full seed: the operator lexer fix, and parity with the others ----
	$(call assert-out,./$(TESTS)/sgc_ops_ms,6\n5\n4\n2.5\n2\n9\n0\n1\n2)
	$(call assert-out,./$(TESTS)/sgc_ops_g2,6\n5\n4\n2.5\n2\n9\n0\n1\n2)
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_ops_fs',6\n5\n4\n2.5\n2\n9\n0\n1\n2)
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_grow_fs',2003\n97\n120)
	echo "[OK] full seed: every single-character operator is emitted again (it used to record the token text as a quoted char literal) and ops/grow match seed-min and gen2 exactly"
	# ---- full seed: refcount representation, gc() no-op, no release path ----
	printf 'show gc()\n' > $(TESTS)/sgc_noop_fs.sa
	./$(SEED_BIN) $(TESTS)/sgc_noop_fs.sa > $(TESTS)/sgc_noop_fs.c
	$(CC) -O2 -I selfhost/seed -o $(TESTS)/sgc_noop_fs $(TESTS)/sgc_noop_fs.c -lm
	$(call assert-out,./$(TESTS)/sgc_noop_fs,0)
	printf 'show gc_live()\n' > $(TESTS)/sgc_live_fs.sa
	if ./$(SEED_BIN) $(TESTS)/sgc_live_fs.sa > /dev/null 2>$(TESTS)/sgc_live_fs.err; then \
	  echo "[FAIL] the full seed accepted gc_live(), which its runtime does not have"; exit 1; fi
	grep -q -F "undefined function 'gc_live'" $(TESTS)/sgc_live_fs.err
	SX_GC_DEBUG=1 ./$(TESTS)/sgc_tmp_fs > $(TESTS)/sgc_tmp_fs.out 2>$(TESTS)/sgc_tmp_fs.err
	$(call assert-out,cat $(TESTS)/sgc_tmp_fs.out,2000)
	grep -q -F 'sx-gc-debug: 6000 objects still alive at exit' $(TESTS)/sgc_tmp_fs.err
	echo "[OK] full seed: gc() is a no-op returning 0, gc_live() does not exist, and SX_GC_DEBUG=1 counts 6000 objects alive after 2000 iterations that retain nothing (no working release path)"
	# ---- full seed: static object table, and the number-format divergence ----
	if sh -c 'ulimit -v 4096; ./$(TESTS)/sgc_tmp_fs' >/dev/null 2>&1; then \
	  echo "[FAIL] the full seed started inside a 4 MiB cap: its SX_TAB_CAP 2097152 object table is static and should not fit"; exit 1; fi
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_retain_fs',before\n8388608\nafter)
	$(call assert-out,./$(TESTS)/sgc_retain_ms,before\n8.38861e+06\nafter)
	$(call assert-out,./$(TESTS)/sgc_retain_g2,before\n8.38861e+06\nafter)
	echo "[OK] full seed: needs >= 64 MiB of address space (static object table) and prints 8388608 where seed-min/gen2 print 8.38861e+06 (documented divergence)"
	# ---- gen2: real mark & sweep, generous threshold, checked allocations ----
	test $$(grep -c -F 'sx: out of memory' $(TESTS)/sgc_churn_g2.c) -eq 3 \
	  || { echo "[FAIL] the gen2 runtime does not check all three of its allocations"; exit 1; }
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_churn_g2',200000)
	$(call assert-out,sh -c 'ulimit -v 8192; ./$(TESTS)/sgc_grow_g2',2003\n97\n120)
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_retain_g2',before\n8.38861e+06\nafter)
	if __got=$$(sh -c 'ulimit -v 16384; ./$(TESTS)/sgc_churn_g2 2>$(TESTS)/sgc_churn_g2.err'); then \
	  echo "[FAIL] gen2 ran a 200k churn inside a 16 MiB cap; its 8 MiB heap threshold should not allow that"; exit 1; fi; \
	  case "$$__got" in *Segmentation*) echo "[FAIL] gen2 segfaulted under memory pressure"; exit 1;; esac
	grep -q -F 'sx: out of memory' $(TESTS)/sgc_churn_g2.err
	echo "[OK] gen2: mark & sweep keeps a 200k churn and an 8 MiB live set correct inside 64 MiB, all three runtime allocations are checked, and 16 MiB fails as \`sx: out of memory\` with exit 1 instead of a segfault"
	# ---- gen2 really does collect during the churn (test-gc pins the builtins) ----
	printf 'hold i = 0\nwhile i < 200000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow i\nshow gc_runs()\nshow gc_live()\n' > $(TESTS)/sgc_runs_g2.sa
	./$(GEN2) $(TESTS)/sgc_runs_g2.sa $(TESTS)/sgc_runs_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/sgc_runs_g2 $(TESTS)/sgc_runs_g2.c
	__o=$$(sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_runs_g2'); \
	 printf '%s\n' "$$__o" | { \
	   IFS= read -r __first; IFS= read -r __r; IFS= read -r __l; \
	   if [ "$$__r" -lt 1 ] 2>/dev/null; then echo "[FAIL] gen2 ran no collection in a 200k churn: $$__o"; exit 1; fi; \
	   if [ "$$__l" -lt 1 ] 2>/dev/null; then echo "[FAIL] gen2 gc_live() reported $$__l after a 200k churn"; exit 1; fi; }
	echo "[OK] gen2: a 200k churn collects (gc_runs() >= 1) and the live set stays small (gc_live() reported)"
	echo "[OK] seed GC: seed-min = freeing assignment plus a conservative mark & sweep over the builder registry (a live set still OOMs loudly); full seed = refcount table with gc() as a no-op and no release; gen2 = checked mark & sweep; native = test-native-mem"

# ---------------------------------------------------------------------------
# test-generic-structs: generic structs ARE implemented, on all three backends,
# with one concrete type per instantiation -- and the type argument list is
# checked, so a mistake is a named refusal rather than wrong code.
#
# `struct Box<T> { v }` is a template: parameter names and field names, no
# layout, and it never becomes a struct of its own. Each instantiation is
# mangled to a concrete struct name -- Box<num> is Box__n, Box<str> is Box__s,
# Pair<num,str> is Pair__ns -- using the suffixes generic FUNCTIONS already use,
# so the mangled name is the type identity: two specializations get their own
# field kinds, their own typedef and (on native) their own GC block descriptor,
# and they can never share a slot. That is items 1 and 2 of the five-point list
# in docs/TYPES_ROADMAP.md ("A safe implementation needs"); the same document
# records what is still missing -- a CONCRETE struct name as a type argument
# and gen2's wording for a bad type argument list. (Nested instantiations such
# as Box<Box<num>> and a list type argument were on that list until
# 2026-10-22; they are gated by test-generic-structs-nested now.)
#
# selfhost/generic_struct_box.sa is the shared parity fixture: three
# instantiations in one program, six printed lines, byte-identical on seed-min,
# gen2 and native. The typedefs are pinned as well, because the layout IS the
# claim -- `double v` for Box__n and `char *v` for Box__s in one program.
#
# The second half pins the refusals: a wrong type argument count, a CONCRETE
# struct name as a type argument, a bare template name, and one instantiation
# used with two different kinds -- plus, where the list refusal used to be, a
# support block for Box<list>. All three backends refuse all four.
# seed-min and native name the problem, so their wording is pinned; gen2
# refuses through its general "undefined name" and stray-token errors, so for
# gen2 only the failure is pinned (plus its wording for the two-kinds case,
# which it does name). Pinning gen2's weak wording would freeze it, so the gate
# asserts the honest part: no backend compiles any of these.
#
# The last two sections predate generic structs and are unchanged: the
# concrete-name workaround (one struct name per layout) still prints the same
# bytes on all three backends, and a dotted field read inside a struct literal
# (`NumBox { a.v }`) stays seed-min-only -- refused by gen2 (#error) and native.
# Refused, not miscompiled.
# ---------------------------------------------------------------------------
.PHONY: test-generic-structs
test-generic-structs: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	mkdir -p $(TESTS)
	# ---- support: one concrete type per instantiation, three-way parity ----
	./$(SEED_MIN_BIN) selfhost/generic_struct_box.sa > $(TESTS)/gs_box_ms.c
	grep -q -F 'typedef struct { double v; } Box__n;' $(TESTS)/gs_box_ms.c
	grep -q -F 'typedef struct { char *v; } Box__s;' $(TESTS)/gs_box_ms.c
	grep -q -F 'typedef struct { double a; char *b; } Pair__ns;' $(TESTS)/gs_box_ms.c
	$(CC) -O2 -o $(TESTS)/gs_box_ms $(TESTS)/gs_box_ms.c
	$(call assert-out,./$(TESTS)/gs_box_ms,7\nseven\n8\n7\n9\nnine)
	./$(GEN2) selfhost/generic_struct_box.sa $(TESTS)/gs_box_g2.c >/dev/null
	grep -q -F 'typedef struct { double v; } Box__n;' $(TESTS)/gs_box_g2.c
	grep -q -F 'typedef struct { char *v; } Box__s;' $(TESTS)/gs_box_g2.c
	grep -q -F 'typedef struct { double a; char *b; } Pair__ns;' $(TESTS)/gs_box_g2.c
	$(CC) -O2 -o $(TESTS)/gs_box_g2 $(TESTS)/gs_box_g2.c
	$(call assert-out,./$(TESTS)/gs_box_g2,7\nseven\n8\n7\n9\nnine)
	echo "[OK] generic structs: Box<num>, Box<str> and Pair<num,str> are three types with their own layouts, identical on seed-min and gen2"
	if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/generic_struct_box.sa $(TESTS)/gs_box_nat && \
	  ./$(TESTS)/gs_box_nat > $(TESTS)/gs_box_nat.out && \
	  ./$(TESTS)/gs_box_ms > $(TESTS)/gs_box_ms.out && \
	  cmp $(TESTS)/gs_box_ms.out $(TESTS)/gs_box_nat.out && \
	  echo "[generic-structs] native: the same instantiations print the same bytes as seed-min"; \
	fi
	# ---- refusal 1: the wrong number of type arguments ----
	printf 'struct Box<T> {\n  v\n}\nhold b = Box<num, str> { 7 }\nshow b.v\n' > $(TESTS)/gs_arity.sa
	if ./$(SEED_MIN_BIN) $(TESTS)/gs_arity.sa > $(TESTS)/gs_arity_ms.c 2>$(TESTS)/gs_arity_ms.err; then \
	  echo "[FAIL] seed-min accepted Box<num, str> against a one-parameter template"; exit 1; fi
	grep -q -F 'Box takes 1 type argument, got 2' $(TESTS)/gs_arity_ms.err
	./$(GEN2) $(TESTS)/gs_arity.sa $(TESTS)/gs_arity_g2.c >/dev/null 2>&1 || true
	grep -q -F '#error sayanox-min:' $(TESTS)/gs_arity_g2.c
	if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gs_arity.sa $(TESTS)/gs_arity_nat 2>$(TESTS)/gs_arity_nat.err; then \
	    echo "[FAIL] native accepted Box<num, str> against a one-parameter template"; exit 1; fi; \
	  grep -q -F 'takes 1 type argument, got 2' $(TESTS)/gs_arity_nat.err; \
	fi
	echo "[OK] generic structs: a wrong type argument count is refused by all three backends"
	# ---- refusal 2: a struct name as a type argument ----
	printf 'struct NumBox {\n  v\n}\nstruct Box<T> {\n  v\n}\nhold n = NumBox { 3 }\nhold b = Box<NumBox> { n }\nshow b.v\n' > $(TESTS)/gs_argstruct.sa
	if ./$(SEED_MIN_BIN) $(TESTS)/gs_argstruct.sa > $(TESTS)/gs_argstruct_ms.c 2>$(TESTS)/gs_argstruct_ms.err; then \
	  echo "[FAIL] seed-min accepted a struct name as a type argument"; exit 1; fi
	grep -q -F "a type argument must be num, str, list or an instantiation of a generic struct (got 'NumBox')" $(TESTS)/gs_argstruct_ms.err
	./$(GEN2) $(TESTS)/gs_argstruct.sa $(TESTS)/gs_argstruct_g2.c >/dev/null 2>&1 || true
	grep -q -F '#error sayanox-min:' $(TESTS)/gs_argstruct_g2.c
	if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gs_argstruct.sa $(TESTS)/gs_argstruct_nat 2>$(TESTS)/gs_argstruct_nat.err; then \
	    echo "[FAIL] native accepted a struct name as a type argument"; exit 1; fi; \
	  grep -q -F "a type argument must be num, str, list or an instantiation of a generic struct (got 'NumBox')" $(TESTS)/gs_argstruct_nat.err; \
	fi
	echo "[OK] generic structs: a CONCRETE struct name as a type argument is refused by all three backends (an instantiation of a generic one is not: test-generic-structs-nested)"
	# ---- support 2: a list type argument stores the list POINTER ----
	# This was refusal 3 until 2026-10-22. Box<list> is Box__l; the field holds
	# the pointer, so growth through the original name is visible through it.
	printf 'struct Box<T> {\n  v\n}\nhold xs = [1, 2]\nhold b = Box<list> { xs }\nshow len(b.v)\npush(xs, 3)\nshow len(b.v)\n' > $(TESTS)/gs_arglist.sa
	./$(SEED_MIN_BIN) $(TESTS)/gs_arglist.sa > $(TESTS)/gs_arglist_ms.c
	grep -q -F 'typedef struct { sx_list *v; } Box__l;' $(TESTS)/gs_arglist_ms.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gs_arglist_ms $(TESTS)/gs_arglist_ms.c
	./$(GEN2) $(TESTS)/gs_arglist.sa $(TESTS)/gs_arglist_g2.c >/dev/null
	grep -q -F 'typedef struct { sx_list *v; } Box__l;' $(TESTS)/gs_arglist_g2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gs_arglist_g2 $(TESTS)/gs_arglist_g2.c
	$(call assert-out,./$(TESTS)/gs_arglist_ms,2\n3)
	$(call assert-out,./$(TESTS)/gs_arglist_g2,2\n3)
	if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/gs_arglist.sa $(TESTS)/gs_arglist_nat && \
	  ./$(TESTS)/gs_arglist_nat > $(TESTS)/gs_arglist_nat.out && \
	  ./$(TESTS)/gs_arglist_ms > $(TESTS)/gs_arglist_ms.out && \
	  cmp $(TESTS)/gs_arglist_ms.out $(TESTS)/gs_arglist_nat.out; \
	fi
	echo "[OK] generic structs: a list type argument gives Box__l an sx_list * field on all three backends, and the alias survives growth"
	# ---- refusal 4: a bare template name, with no type arguments ----
	printf 'struct Box<T> {\n  v\n}\nhold b = Box { 7 }\nshow b.v\n' > $(TESTS)/gs_bare.sa
	if ./$(SEED_MIN_BIN) $(TESTS)/gs_bare.sa > $(TESTS)/gs_bare_ms.c 2>$(TESTS)/gs_bare_ms.err; then \
	  echo "[FAIL] seed-min accepted a bare template name"; exit 1; fi
	grep -q -F 'Box is a generic struct: write Box<num> { ... }' $(TESTS)/gs_bare_ms.err
	./$(GEN2) $(TESTS)/gs_bare.sa $(TESTS)/gs_bare_g2.c >/dev/null 2>&1 || true
	grep -q -F '#error sayanox-min:' $(TESTS)/gs_bare_g2.c
	if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gs_bare.sa $(TESTS)/gs_bare_nat 2>$(TESTS)/gs_bare_nat.err; then \
	    echo "[FAIL] native accepted a bare template name"; exit 1; fi; \
	  grep -q -F 'is a generic struct: write Box<num> { ... }' $(TESTS)/gs_bare_nat.err; \
	fi
	echo "[OK] generic structs: a bare template name is refused by all three backends"
	# ---- refusal 5: one instantiation used with two different kinds ----
	printf 'struct Box<T> {\n  v\n}\nhold b = Box<num> { 7 }\nhold s = Box<num> { "seven" }\nshow b.v\nshow s.v\n' > $(TESTS)/gs_twokinds.sa
	if ./$(SEED_MIN_BIN) $(TESTS)/gs_twokinds.sa > $(TESTS)/gs_twokinds_ms.c 2>$(TESTS)/gs_twokinds_ms.err; then \
	  echo "[FAIL] seed-min accepted two kinds in one instantiation"; exit 1; fi
	grep -q -F "Box__n field 'v' is num (its type argument says so), the literal gives str" $(TESTS)/gs_twokinds_ms.err
	./$(GEN2) $(TESTS)/gs_twokinds.sa $(TESTS)/gs_twokinds_g2.c >/dev/null 2>&1 || true
	grep -q -F '#error sayanox-min: struct field is used with two different value kinds' $(TESTS)/gs_twokinds_g2.c
	if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gs_twokinds.sa $(TESTS)/gs_twokinds_nat 2>$(TESTS)/gs_twokinds_nat.err; then \
	    echo "[FAIL] native accepted two kinds in one instantiation"; exit 1; fi; \
	  grep -q -F "field 'v' is a number (its type argument says so), the literal gives a string" $(TESTS)/gs_twokinds_nat.err; \
	fi
	echo "[OK] generic structs: one instantiation cannot hold two kinds -- the type argument fixes the field kind"
	# ---- the supported workaround: concrete names, three-way parity ----
	./$(SEED_MIN_BIN) selfhost/generic_struct_concrete.sa > $(TESTS)/gs_conc_ms.c
	$(CC) -O2 -o $(TESTS)/gs_conc_ms $(TESTS)/gs_conc_ms.c
	./$(GEN2) selfhost/generic_struct_concrete.sa $(TESTS)/gs_conc_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gs_conc_g2 $(TESTS)/gs_conc_g2.c
	$(call assert-out,./$(TESTS)/gs_conc_ms,7\nseven\n8\neight\n2\n8\n9)
	$(call assert-out,./$(TESTS)/gs_conc_g2,7\nseven\n8\neight\n2\n8\n9)
	if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/generic_struct_concrete.sa $(TESTS)/gs_conc_nat && \
	  ./$(TESTS)/gs_conc_nat > $(TESTS)/gs_conc_nat.out && \
	  ./$(TESTS)/gs_conc_ms > $(TESTS)/gs_conc_ms.out && \
	  cmp $(TESTS)/gs_conc_ms.out $(TESTS)/gs_conc_nat.out && \
	  echo "[generic-structs] native: concrete struct names print the same bytes as seed-min"; \
	fi
	echo "[OK] generic structs workaround: two same-shaped concrete structs in one program, identical on seed-min, gen2 and native"
	# ---- the adjacent divergence: a dotted field read inside a struct literal ----
	printf 'struct NumBox {\n  v\n}\nhold a = NumBox { 7 }\nhold a2 = NumBox { a.v }\nshow a2.v\n' > $(TESTS)/gs_field_lit.sa
	./$(SEED_MIN_BIN) $(TESTS)/gs_field_lit.sa > $(TESTS)/gs_field_lit_ms.c
	$(CC) -O2 -o $(TESTS)/gs_field_lit_ms $(TESTS)/gs_field_lit_ms.c
	$(call assert-out,./$(TESTS)/gs_field_lit_ms,7)
	./$(GEN2) $(TESTS)/gs_field_lit.sa $(TESTS)/gs_field_lit_g2.c > $(TESTS)/gs_field_lit_g2.out 2>&1 || true
	grep -q -F '#error sayanox-min: struct/list literal value must be a number, string, name, or nested struct' $(TESTS)/gs_field_lit_g2.c
	if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gs_field_lit.sa $(TESTS)/gs_field_lit_nat 2>$(TESTS)/gs_field_lit_nat.err; then \
	    echo "[FAIL] native accepted a dotted field read inside a struct literal"; exit 1; fi; \
	  grep -q -F 'is used with two different types' $(TESTS)/gs_field_lit_nat.err \
	    || { echo "[FAIL] native refusal for a field read in a literal changed wording:"; cat $(TESTS)/gs_field_lit_nat.err; exit 1; }; \
	fi
	echo "[OK] generic structs: a dotted field read inside a struct literal stays seed-min-only (gen2 #error, native refuses) -- a documented divergence, not silent wrong code"

# ---------------------------------------------------------------------------
# test-stage2-demos: the three Stage-2 contract demos in selfhost/ are
# pure-min programs (top-level slots, numeric functions, string loops).  They
# must stay runnable: seed-min and gen2 compile them and print byte-identical
# stdout, and the string-only one (minimal_lexer) also runs natively when
# native_aot is built (this target is part of `make native-test`, and its
# native half is skipped on the portable `true-selfhost` path).  This
# does NOT claim the full Stage-2 language - the demos are a contract sketch,
# which is exactly why they are in the shared dialect.
# ---------------------------------------------------------------------------
test-stage2-demos: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/minimal_lexer.sa > $(TESTS)/stage2_lexer_sm.c
	$(CC) -O2 -o $(TESTS)/stage2_lexer_sm $(TESTS)/stage2_lexer_sm.c
	./$(GEN2) selfhost/minimal_lexer.sa $(TESTS)/stage2_lexer_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/stage2_lexer_g2 $(TESTS)/stage2_lexer_g2.c
	@./$(TESTS)/stage2_lexer_sm > $(TESTS)/stage2_lexer_sm.out; ./$(TESTS)/stage2_lexer_g2 > $(TESTS)/stage2_lexer_g2.out; \
	  cmp $(TESTS)/stage2_lexer_sm.out $(TESTS)/stage2_lexer_g2.out
	$(call assert-out,./$(TESTS)/stage2_lexer_g2,=== Self-Hosting Phase 1.5 ===\nshow 42\n7\n115\n104\n111\n119\n32\n52\n50\nTokens:\n1\n11\n0\nPhase 1.5 complete — dynamic push + len + string walk)
	@# native_aot is built by `make native-test`, not by the portable
	@# `true-selfhost` path, so its lexer check runs only when the binary is
	@# there (a clean checkout has neither) -- `make native-test` includes this
	@# target, so the native half is executed for real there.
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/minimal_lexer.sa $(TESTS)/stage2_lexer_nat && \
	  ./$(TESTS)/stage2_lexer_nat > $(TESTS)/stage2_lexer_nat.out && \
	  cmp $(TESTS)/stage2_lexer_sm.out $(TESTS)/stage2_lexer_nat.out && \
	  echo "[stage2] native lexer: stdout identical to seed-min/gen2"; \
	else \
	  echo "[stage2] native lexer: skipped (native_aot is not built here)"; \
	fi
	@# the two demos with make/give: seed-min and gen2 agree byte for byte
	./$(SEED_MIN_BIN) selfhost/stage2_functions.sa > $(TESTS)/stage2_fn_sm.c
	$(CC) -O2 -o $(TESTS)/stage2_fn_sm $(TESTS)/stage2_fn_sm.c
	./$(GEN2) selfhost/stage2_functions.sa $(TESTS)/stage2_fn_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/stage2_fn_g2 $(TESTS)/stage2_fn_g2.c
	$(call assert-out,./$(TESTS)/stage2_fn_sm,42\n1764)
	$(call assert-out,./$(TESTS)/stage2_fn_g2,42\n1764)
	./$(SEED_MIN_BIN) selfhost/stage2_variables.sa > $(TESTS)/stage2_var_sm.c
	$(CC) -O2 -o $(TESTS)/stage2_var_sm $(TESTS)/stage2_var_sm.c
	./$(GEN2) selfhost/stage2_variables.sa $(TESTS)/stage2_var_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/stage2_var_g2 $(TESTS)/stage2_var_g2.c
	$(call assert-out,./$(TESTS)/stage2_var_sm,42)
	$(call assert-out,./$(TESTS)/stage2_var_g2,42)
	@echo "[OK] Stage-2 demos (minimal_lexer, stage2_functions, stage2_variables): seed-min == gen2 byte for byte, plus the lexer natively when native_aot is built; contract sketches, not the full Stage-2 language"

# ---------------------------------------------------------------------------
# test-stdlib: the tiny portable library stdlib/tiny.sa is used with a plain
# `use` splice and must behave identically on every backend: seed-min and
# gen2 are checked here, and the native leg runs too whenever native_aot has
# been built (native-test). The typed str/list/file utility modules below
# also run on seed-min, gen2 and the maintained native subset.
# ---------------------------------------------------------------------------
test-stdlib: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'use "stdlib/tiny.sa"\nshow min2(3, 7)\nshow max2(3, 7)\nshow absv(0 - 5)\nshow absv(5)\nshow sum_to(10)\nshow pow_int(2, 10)\nshow is_even(42)\nshow is_even(7)\nshow gcd(48, 36)\nshow gcd(1071, 462)\nshow clamp(15, 0, 10)\nshow clamp(0 - 3, 0, 10)\nshow clamp(4, 0, 10)\nshow sign(0 - 9)\nshow sign(0)\nshow sign(12)\nshow is_odd(7)\nshow is_odd(0 - 4)\nshow is_odd(0 - 3)\nshow lcm(4, 6)\nshow lcm(0, 5)\nshow lcm(21, 6)\nshow fact(5)\nshow fact(0)\nshow fib(10)\nshow fib(1)\nshow is_prime(2)\nshow is_prime(1)\nshow is_prime(91)\nshow is_prime(97)\nshow sum_range(1, 5)\nshow sum_range(5, 5)\nshow sum_range(6, 5)\nshow sum_sq(4)\nshow count_digits(0)\nshow count_digits(12345)\nshow count_digits(0 - 42)\nshow digit_sum(12345)\nshow digit_sum(0 - 99)\nshow trunc10(456)\nshow reverse_num(1234)\nshow reverse_num(1200)\nshow is_square(0)\nshow is_square(49)\nshow is_square(50)\nshow between(5, 1, 10)\nshow between(0, 1, 10)\nshow between(11, 1, 10)\n' > $(TESTS)/std_t.sa
	./$(SEED_MIN_BIN) $(TESTS)/std_t.sa > $(TESTS)/std_sm.c
	$(CC) -O2 -o $(TESTS)/std_sm $(TESTS)/std_sm.c
	./$(GEN2) $(TESTS)/std_t.sa $(TESTS)/std_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/std_g2 $(TESTS)/std_g2.c
	@./$(TESTS)/std_sm > $(TESTS)/std_sm.out; ./$(TESTS)/std_g2 > $(TESTS)/std_g2.out; \
	  cmp $(TESTS)/std_sm.out $(TESTS)/std_g2.out
	$(call assert-out,./$(TESTS)/std_g2,3\n7\n5\n5\n55\n1024\n1\n0\n12\n21\n10\n0\n4\n-1\n0\n1\n1\n0\n1\n12\n0\n42\n120\n1\n55\n1\n1\n0\n0\n1\n15\n5\n0\n30\n1\n5\n2\n15\n18\n45\n4321\n21\n1\n1\n0\n1\n0\n0)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/std_t.sa $(TESTS)/std_nat && \
	  ./$(TESTS)/std_nat > $(TESTS)/std_nat.out && \
	  cmp $(TESTS)/std_sm.out $(TESTS)/std_nat.out || exit 1; \
	fi
	@echo "[OK] tiny stdlib via use: seed-min == gen2 (== native when built) on 30 numeric helpers"
	@# ---- the string / list / file modules: gen2 only, by design ----
	@# Typed utility modules now run on seed-min too; compare all output.
	@printf 'use "stdlib/str_util.sa"\nuse "stdlib/list_util.sa"\nuse "stdlib/file_util.sa"\nshow s_len("hello")\nshow s_at("hello", 1)\nshow s_join("ab", "cd")\nshow s_prefix("hello", 3)\nshow s_prefix("hi", 9)\nshow s_suffix("hello", 2)\nshow s_suffix("hi", 9)\nshow s_reverse("hello")\nshow s_repeat("xy", 3)\nshow s_count("banana", 97)\nshow s_contains("banana", 97)\nshow s_contains("banana", 122)\nshow s_eq("ab", "ab")\nshow s_eq("ab", "ac")\nshow s_upper("Hi There 42!")\nshow s_lower("Hi There 42!")\nshow s_starts("hello", "he")\nshow s_starts("hello", "lo")\nshow s_ends("hello", "lo")\nshow s_ends("hello", "he")\nhold xs = [3, 1, 4, 1, 5]\nshow l_len(xs)\nshow l_get(xs, 2)\nshow l_sum(xs)\nshow l_max(xs)\nshow l_min(xs)\nshow l_count(xs, 1)\nshow l_contains(xs, 9)\nhold r = l_reverse(xs)\nshow len(r)\nshow r[0]\nshow r[4]\nhold g = l_range(4)\nshow len(g)\nshow g[3]\nhold p = "$(TESTS)/std_f.txt"\nshow f_write(p, "one\\ntwo\\nthree")\nshow f_read(p)\nshow f_size(p)\nshow f_lines(p)\nshow f_exists(p)\nshow f_exists("$(TESTS)/std_no_such_file")\n' > $(TESTS)/std_sl.sa
	./$(GEN2) $(TESTS)/std_sl.sa $(TESTS)/std_sl.c >/dev/null
	$(CC) -O2 -Wall -o $(TESTS)/std_sl $(TESTS)/std_sl.c 2>$(TESTS)/std_sl.warn
	@if grep -q ' error' $(TESTS)/std_sl.warn; then \
	  echo "[FAIL] stdlib str/list/file module produced C that does not build"; \
	  head -20 $(TESTS)/std_sl.warn; exit 1; fi
	$(call assert-out,./$(TESTS)/std_sl,5\n101\nabcd\nhel\nhi\nlo\nhi\nolleh\nxyxyxy\n3\n1\n0\n1\n0\nHI THERE 42!\nhi there 42!\n1\n0\n1\n0\n5\n4\n14\n5\n1\n2\n0\n5\n5\n3\n4\n3\n1\none\ntwo\nthree\n13\n3\n1\n0)
	./$(SEED_MIN_BIN) $(TESTS)/std_sl.sa > $(TESTS)/std_sl_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/std_sl_seed $(TESTS)/std_sl_seed.c
	./$(TESTS)/std_sl_seed > $(TESTS)/std_sl_seed.out
	./$(TESTS)/std_sl > $(TESTS)/std_sl_g2.out
	cmp $(TESTS)/std_sl_seed.out $(TESTS)/std_sl_g2.out
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/std_sl.sa $(TESTS)/std_sl_nat >/dev/null 2>&1 || { echo "[FAIL] native refused the str/list module"; exit 1; }; \
	  ./$(TESTS)/std_sl_nat > $(TESTS)/std_sl_nat.out; ./$(TESTS)/std_sl > $(TESTS)/std_sl_g2.out; \
	  cmp $(TESTS)/std_sl_nat.out $(TESTS)/std_sl_g2.out || { echo "[FAIL] native str/list module differs from gen2"; exit 1; }; \
	fi
	@echo "[OK] stdlib str/list/file modules on gen2 (typed parameters); seed-min and native run them with the same output"

# ---------------------------------------------------------------------------
# test-sxpkg-polish: the wrapper's offline behaviour, pinned. The Sayanox binary
# cannot set an exit status, so the shell wrapper turns a FAILED/DEP report
# into rc 1 (verify, install-local), an unknown command is rc 2, and `publish`
# prints its report once (it used to run twice through a duplicated dispatch).
test-sxpkg-polish: sxpkg
	@mkdir -p $(TESTS)/sxpkg-polish
	@printf '' > $(TESTS)/sxpkg-polish/sx.lock
	@printf 'name = "pol-pkg"\nversion = "0.1.0"\n' > $(TESTS)/sxpkg-polish/sx.toml
	cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) init >/dev/null
	cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) add nosuch 1.0 | grep -q 'nosuch has no local registry copy'
	@if (cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) verify >/dev/null 2>&1); then \
	  echo "[FAIL] sxpkg verify exited 0 with a missing package"; exit 1; fi
	@if (cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) install-local $(CURDIR)/registry >/dev/null 2>&1); then \
	  echo "[FAIL] sxpkg install-local exited 0 with an unresolvable lock entry"; exit 1; fi
	@cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) bogus >/dev/null 2>&1; \
	  rc=$$?; if [ $$rc -ne 2 ]; then echo "[FAIL] unknown sxpkg command exited $$rc, want 2"; exit 1; fi
	@n=$$(cd $(TESTS)/sxpkg-polish && ../../../$(SXPKG_BIN) publish | grep -c 'sxpkg: published locally pol-pkg 0.1.0'); \
	  if [ "$$n" != 1 ]; then echo "[FAIL] sxpkg publish reported $$n times, want 1"; exit 1; fi
	@echo "[OK] sxpkg offline polish: add note, verify/install-local exit codes, unknown command rc 2, publish once"


# ---------------------------------------------------------------------------
# test-sxpkg-sayanox-logic: the part of sxpkg that moved out of the shell.
#
# tools/sxpkg.sa is the whole package tool since 2026-10-22: the shell wrapper
# that carried publish, install-local's folder loop, the local-registry halves
# of sync and fetch, the online opt-in policy, SAYANOX_ROOT and the exit
# statuses is gone.  The `getenv` and `run_command` builtins replaced it, and
# the one program it still starts is the http(s) transport itself.
#
# Pinned here:
#   * publish writes pkg.meta (name/version/sum) and main.sa, adds exactly one
#     INDEX entry, reports exactly once, and never creates a project copy.
#   * install-local creates .sayanox/registry/<n>/ and .sayanox/pkgs/<n>/ for
#     every locked name, copies, and exits 1 for an unresolvable lock, an
#     unsafe name, or a missing sx.lock.
#   * sync against a local registry writes the INDEX only after every name in
#     it has passed the check, so a hostile index can neither escape the
#     registry nor destroy the one already installed, and it falls back to the
#     local seed when there is no INDEX to read.
#   * fetch from a local source records the sum in pkg.meta and sx.lock, copies
#     to both places, refuses an existing package, and leaves nothing behind --
#     no package copy and an unchanged lock -- when it cannot write.
#   * ensure-dir / rm-tree / copy-tree are mkdir -p, rm -rf and cp -r.
#   * the compiler's signature pre-pass reads every line as code, so a comment
#     with an odd number of double quotes silently strips the types from every
#     later `make`.  The generated C and a fixture both pin that it did not.
# ---------------------------------------------------------------------------
.PHONY: test-sxpkg-sayanox-logic
test-sxpkg-sayanox-logic: sxpkg
	@mkdir -p $(TESTS)/sxpkg-sayanox
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox sx.lock sx.toml main.sa srcreg syncreg badreg deep csrc cdst fetchsrc.sa
	@# ---- a comment with balanced quotes must not break a typed signature ----
	@printf '// a comment with two "quotes" in it, balanced\nmake f(a: num, b: str) -> num {\n  give len(b)\n}\nshow f(1, "x")\n' > $(TESTS)/sxpkg-sayanox/quotes.sa
	@./$(GEN2) $(TESTS)/sxpkg-sayanox/quotes.sa $(TESTS)/sxpkg-sayanox/quotes.c >/dev/null
	@grep -q -F 'static double f(double a, char *b)' $(TESTS)/sxpkg-sayanox/quotes.c \
	  || { echo "[FAIL] a comment with balanced quotes broke a typed make signature"; exit 1; }
	@$(CC) -O2 -o $(TESTS)/sxpkg-sayanox/quotes $(TESTS)/sxpkg-sayanox/quotes.c
	@q=$$($(TESTS)/sxpkg-sayanox/quotes); test "$$q" = 1 \
	  || { echo "[FAIL] the quotes fixture printed '$$q', want 1"; exit 1; }
	@./$(GEN2) tools/sxpkg.sa $(TESTS)/sxpkg-sayanox/sxpkg_check.c >/dev/null
	@if grep -q -F ', double str,' $(TESTS)/sxpkg-sayanox/sxpkg_check.c; then \
	  echo "[FAIL] a typed make in tools/sxpkg.sa lost its parameter types"; \
	  echo "       (a comment with an odd number of double quotes does that)"; exit 1; fi
	@# ---- publish ----
	@printf 'name = "pub-pkg"\nversion = "2.3.4"\n' > $(TESTS)/sxpkg-sayanox/sx.toml
	@printf 'show "pub"\n' > $(TESTS)/sxpkg-sayanox/main.sa
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) publish > pub.out
	@grep -q -F 'sxpkg: published locally pub-pkg 2.3.4' $(TESTS)/sxpkg-sayanox/pub.out \
	  || { echo "[FAIL] publish did not report the package"; exit 1; }
	@test $$(grep -c -F 'sxpkg: published locally' $(TESTS)/sxpkg-sayanox/pub.out) -eq 1 \
	  || { echo "[FAIL] publish reported more than once"; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/.sayanox/registry/pub-pkg/main.sa \
	  || { echo "[FAIL] publish wrote no main.sa"; exit 1; }
	@grep -q -F 'name=pub-pkg' $(TESTS)/sxpkg-sayanox/.sayanox/registry/pub-pkg/pkg.meta \
	  || { echo "[FAIL] publish wrote no pkg.meta name"; exit 1; }
	@grep -q -F 'version=2.3.4' $(TESTS)/sxpkg-sayanox/.sayanox/registry/pub-pkg/pkg.meta \
	  || { echo "[FAIL] publish wrote no pkg.meta version"; exit 1; }
	@grep -q -E '^sum=[0-9]+$$' $(TESTS)/sxpkg-sayanox/.sayanox/registry/pub-pkg/pkg.meta \
	  || { echo "[FAIL] publish recorded no content sum"; exit 1; }
	@printf 'pub-pkg=2.3.4\n' > $(TESTS)/sxpkg-sayanox/index-want
	@cmp $(TESTS)/sxpkg-sayanox/index-want $(TESTS)/sxpkg-sayanox/.sayanox/registry/INDEX \
	  || { echo "[FAIL] publish wrote the wrong INDEX"; exit 1; }
	@test ! -e $(TESTS)/sxpkg-sayanox/.sayanox/pkgs \
	  || { echo "[FAIL] publish created a project copy; it never installs"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) publish >/dev/null
	@cmp $(TESTS)/sxpkg-sayanox/index-want $(TESTS)/sxpkg-sayanox/.sayanox/registry/INDEX \
	  || { echo "[FAIL] a second publish duplicated the INDEX entry"; exit 1; }
	@printf '# sx.lock\nversion=1\npub-pkg=2.3.4\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) verify | grep -q 'verify ok' \
	  || { echo "[FAIL] a Sayanox-published package does not verify"; exit 1; }
	@# ---- install-local ----
	@mkdir -p $(TESTS)/sxpkg-sayanox/srcreg
	@cp -r registry/math registry/strings $(TESTS)/sxpkg-sayanox/srcreg/
	@printf '# sx.lock\nversion=1\nmath=0.1.0\nstrings=0.1.0\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) install-local srcreg > il.out
	@grep -q -F 'sxpkg: install ok' $(TESTS)/sxpkg-sayanox/il.out \
	  || { echo "[FAIL] install-local did not report ok"; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/.sayanox/registry/math/pkg.meta \
	  || { echo "[FAIL] install-local wrote no registry copy"; exit 1; }
	@test -d $(TESTS)/sxpkg-sayanox/.sayanox/pkgs/math \
	  || { echo "[FAIL] install-local created no project folder"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) verify | grep -q 'verify ok' \
	  || { echo "[FAIL] an install-local package does not verify"; exit 1; }
	@printf '# sx.lock\nversion=1\nnosuch=9.9\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) install-local srcreg >/dev/null 2>&1); then \
	  echo "[FAIL] install-local exited 0 with an unresolvable lock entry"; exit 1; fi
	@printf '# sx.lock\nversion=1\n../escape=1.0\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) install-local srcreg >/dev/null 2>&1); then \
	  echo "[FAIL] install-local accepted an unsafe package name"; exit 1; fi
	@test ! -e $(TESTS)/escape || { echo "[FAIL] install-local escaped the tests directory"; exit 1; }
	@rm -f $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) install-local srcreg >/dev/null 2>&1); then \
	  echo "[FAIL] install-local exited 0 with no sx.lock"; exit 1; fi
	@# ---- sync against a local registry ----
	@mkdir -p $(TESTS)/sxpkg-sayanox/syncreg/hello $(TESTS)/sxpkg-sayanox/syncreg/math
	@cp registry/hello/main.sa registry/hello/pkg.meta $(TESTS)/sxpkg-sayanox/syncreg/hello/
	@cp registry/math/main.sa registry/math/pkg.meta $(TESTS)/sxpkg-sayanox/syncreg/math/
	@printf 'hello=0.1.0\nmath=0.1.0\n' > $(TESTS)/sxpkg-sayanox/syncreg/INDEX
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox
	@cd $(TESTS)/sxpkg-sayanox && SAYANOX_REGISTRY=file://$(CURDIR)/$(TESTS)/sxpkg-sayanox/syncreg \
	    ../../../$(SXPKG_BIN) sync > sync.out
	@grep -q -F 'sxpkg: index updated' $(TESTS)/sxpkg-sayanox/sync.out \
	  || { echo "[FAIL] sync did not report the index"; exit 1; }
	@grep -q -F '  synced math=0.1.0' $(TESTS)/sxpkg-sayanox/sync.out \
	  || { echo "[FAIL] sync did not report the package"; exit 1; }
	@printf 'hello=0.1.0\nmath=0.1.0\n' > $(TESTS)/sxpkg-sayanox/index-want
	@cmp $(TESTS)/sxpkg-sayanox/index-want $(TESTS)/sxpkg-sayanox/.sayanox/registry/INDEX \
	  || { echo "[FAIL] sync wrote the wrong INDEX"; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/.sayanox/registry/math/main.sa \
	  || { echo "[FAIL] sync copied no package"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && SAYANOX_REGISTRY=file://$(CURDIR)/$(TESTS)/sxpkg-sayanox/syncreg \
	    ../../../$(SXPKG_BIN) sync > sync2.out
	@test $$(grep -c -F '  synced math=0.1.0' $(TESTS)/sxpkg-sayanox/sync2.out) -eq 1 \
	  || { echo "[FAIL] a second sync duplicated the report"; exit 1; }
	@mkdir -p $(TESTS)/sxpkg-sayanox/badreg
	@printf '../escape=0.1.0\nmath=0.1.0\n' > $(TESTS)/sxpkg-sayanox/badreg/INDEX
	@if (cd $(TESTS)/sxpkg-sayanox && \
	      SAYANOX_REGISTRY=file://$(CURDIR)/$(TESTS)/sxpkg-sayanox/badreg \
	      ../../../$(SXPKG_BIN) sync >/dev/null 2>&1); then \
	  echo "[FAIL] sync accepted an index with an unsafe package name"; exit 1; fi
	@cmp $(TESTS)/sxpkg-sayanox/index-want $(TESTS)/sxpkg-sayanox/.sayanox/registry/INDEX \
	  || { echo "[FAIL] a rejected index destroyed the installed one"; exit 1; }
	@test ! -e $(TESTS)/escape || { echo "[FAIL] sync escaped the tests directory"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox
	@cd $(TESTS)/sxpkg-sayanox && SAYANOX_REGISTRY=file:///nonexistent-registry \
	    ../../../$(SXPKG_BIN) sync > sync3.out
	@grep -q -F 'sxpkg: local registry seeded' $(TESTS)/sxpkg-sayanox/sync3.out \
	  || { echo "[FAIL] sync did not fall back to the local seed"; exit 1; }
	@# ---- fetch from a local source ----
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@printf 'show "fetched"\n' > $(TESTS)/sxpkg-sayanox/fetchsrc.sa
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) fetch fetchsrc.sa fetched > fetch.out
	@grep -q -F 'sxpkg: fetched fetched from fetchsrc.sa (checksum recorded; not authenticated)' \
	    $(TESTS)/sxpkg-sayanox/fetch.out || { echo "[FAIL] fetch did not report the package"; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/.sayanox/registry/fetched/main.sa \
	  || { echo "[FAIL] fetch wrote no registry copy"; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/.sayanox/pkgs/fetched/main.sa \
	  || { echo "[FAIL] fetch wrote no project copy"; exit 1; }
	@grep -q -E '^sum=[0-9]+$$' $(TESTS)/sxpkg-sayanox/.sayanox/registry/fetched/pkg.meta \
	  || { echo "[FAIL] fetch recorded no content sum"; exit 1; }
	@grep -q -F 'fetched=0.0.0' $(TESTS)/sxpkg-sayanox/sx.lock \
	  || { echo "[FAIL] fetch did not pin the package in sx.lock"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) verify | grep -q 'verify ok' \
	  || { echo "[FAIL] a fetched package does not verify"; exit 1; }
	@if (cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) fetch fetchsrc.sa fetched >/dev/null 2>&1); then \
	  echo "[FAIL] fetch overwrote an existing package"; exit 1; fi
	@grep -q -F 'fetched=0.0.0' $(TESTS)/sxpkg-sayanox/sx.lock \
	  || { echo "[FAIL] a refused fetch changed sx.lock"; exit 1; }
	@if (cd $(TESTS)/sxpkg-sayanox && find . -name '*.part' | grep -q .); then \
	  echo "[FAIL] a .part file was left behind"; exit 1; fi
	@if (cd $(TESTS)/sxpkg-sayanox && find . -name '.fetch.*' | grep -q .); then \
	  echo "[FAIL] a staging directory was left behind"; exit 1; fi
	@# ---- rollback: an unusable registry must leave nothing behind ----
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@printf 'not a directory' > $(TESTS)/sxpkg-sayanox/.sayanox
	@if (cd $(TESTS)/sxpkg-sayanox && ../../../$(SXPKG_BIN) fetch fetchsrc.sa rolled >/dev/null 2>&1); then \
	  echo "[FAIL] fetch succeeded with an unusable registry"; exit 1; fi
	@test ! -e $(TESTS)/sxpkg-sayanox/.sayanox/registry/rolled \
	  || { echo "[FAIL] a failed fetch left a registry copy"; exit 1; }
	@test ! -e $(TESTS)/sxpkg-sayanox/.sayanox/pkgs/rolled \
	  || { echo "[FAIL] a failed fetch left a project copy"; exit 1; }
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-sayanox/lock-want
	@cmp $(TESTS)/sxpkg-sayanox/lock-want $(TESTS)/sxpkg-sayanox/sx.lock \
	  || { echo "[FAIL] a failed fetch changed sx.lock"; exit 1; }
	@# ---- the folder and copy primitives the wrapper now delegates ----
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox deep csrc cdst
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) ensure-dir deep/a/b
	@test -d $(TESTS)/sxpkg-sayanox/deep/a/b || { echo "[FAIL] ensure-dir made no nested folder"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) ensure-dir deep/a/b
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) rm-tree deep
	@test ! -e $(TESTS)/sxpkg-sayanox/deep || { echo "[FAIL] rm-tree left the folder"; exit 1; }
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) rm-tree deep
	@mkdir -p $(TESTS)/sxpkg-sayanox/csrc/sub
	@printf 'one' > $(TESTS)/sxpkg-sayanox/csrc/a
	@printf 'two' > $(TESTS)/sxpkg-sayanox/csrc/sub/b
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) copy-tree csrc cdst
	@test "$$(cat $(TESTS)/sxpkg-sayanox/cdst/a)" = one || { echo "[FAIL] copy-tree lost a file"; exit 1; }
	@test "$$(cat $(TESTS)/sxpkg-sayanox/cdst/sub/b)" = two || { echo "[FAIL] copy-tree did not recurse"; exit 1; }
	@# ---- check-lock / need-fetch / install-cached: the install loop ----
	@# the wrapper used to walk itself. A file with no final newline too.
	@cd $(TESTS)/sxpkg-sayanox && rm -rf .sayanox icdir
	@printf '# sx.lock\nversion=1\n../escape=0.1.0' > $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) check-lock >/dev/null 2>&1); then \
	   echo "[FAIL] check-lock ignored a final line with no newline"; exit 1; fi
	@printf '# sx.lock\nversion=1\nstrings=0.1.0\n../escape=0.1.0\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) check-lock >/dev/null 2>&1); then \
	   echo "[FAIL] check-lock accepted an unsafe name"; exit 1; fi
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) check-lock > cl.out 2>&1 || true
	@grep -q -F "sxpkg: refusing unsafe package name '../escape'" $(TESTS)/sxpkg-sayanox/cl.out \
	  || { echo "[FAIL] check-lock did not name the unsafe package"; cat $(TESTS)/sxpkg-sayanox/cl.out; exit 1; }
	@# need-fetch names exactly the locked packages with no complete copy
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) seed >/dev/null
	@printf 'hello=0.1.0\nstrings=0.1.0\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) need-fetch > nf.want
	@printf 'strings\n' > $(TESTS)/sxpkg-sayanox/nf.have
	@cmp $(TESTS)/sxpkg-sayanox/nf.have $(TESTS)/sxpkg-sayanox/nf.want \
	  || { echo "[FAIL] need-fetch named the wrong packages"; cat $(TESTS)/sxpkg-sayanox/nf.want; exit 1; }
	@# install-cached copies the complete ones and reports the rest, and it
	@# refuses to build a path from an unsafe name even when called directly
	@cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) install-cached icdir > ic.out
	@printf 'sxpkg: installed hello -> icdir/hello\nsxpkg: missing strings in registry\n' > $(TESTS)/sxpkg-sayanox/ic.want
	@cmp $(TESTS)/sxpkg-sayanox/ic.want $(TESTS)/sxpkg-sayanox/ic.out \
	  || { echo "[FAIL] install-cached printed the wrong report"; cat $(TESTS)/sxpkg-sayanox/ic.out; exit 1; }
	@test -f $(TESTS)/sxpkg-sayanox/icdir/hello/main.sa \
	  || { echo "[FAIL] install-cached did not copy a complete package"; exit 1; }
	@printf 'hello=0.1.0\n../escape=0.1.0\n' > $(TESTS)/sxpkg-sayanox/sx.lock
	@if (cd $(TESTS)/sxpkg-sayanox && $(CURDIR)/$(SXPKG_BIN) install-cached icdir2 >/dev/null 2>&1); then \
	   echo "[FAIL] install-cached accepted an unsafe name"; exit 1; fi
	@test ! -e $(TESTS)/escape \
	  || { echo "[FAIL] install-cached built a path outside the project"; exit 1; }
	@echo "[OK] sxpkg in Sayanox: publish, install-local, local sync/fetch, rollback, the folder primitives, and check-lock/need-fetch/install-cached"

# ---------------------------------------------------------------------------
# test-native-emit-split: the x86-64 backend is a REGION of native_aot.c, not a
# seasoning spread through it.
#
# native_aot.c is a single-pass compiler -- it parses Sayanox and emits machine
# code in the same walk -- so "a second target" cannot mean swapping a file, and
# this target does not claim one exists. What it does claim, and check, is the
# seam a second backend would be written against:
#
#   * the encoder API (e1/e32/e64, here(), erel32/erel32j, patch_imm32,
#     jmp5_slot, sub_rsp_imm32_slot, leave_ret and the instruction helpers) is
#     the only code that writes bytes, and all of it sits above the
#     "phase 1: collect definitions" marker;
#   * the language-level emitter is delimited by EMIT-SEAM-BEGIN /
#     EMIT-SEAM-END and contains no raw byte write (e1(, e32(, e64(, memcpy
#     into `code`) and no direct read of the code cursor `cn`: label positions
#     come from here();
#   * below EMIT-SEAM-END the file is x86-64 again by nature -- the phase-4
#     runtime stubs, the collector and the ELF container. A second backend
#     replaces the encoder, those stubs and the container, and reuses the
#     parser, the four phases and the emit tree unchanged. docs/NATIVE.md lists
#     the API under "The emit seam".
#
# Before this pass the emit tree wrote six byte sequences itself (the function
# prologue `sub rsp,imm32` and its later patch, `leave; ret` twice, a `jmp
# rel32` slot, and a hand-rolled rel32 patch that duplicated erel32j) and read
# `cn` in 28 places. Those are now named primitives. The refactor was verified
# byte for byte: five fixtures emitted executables that `cmp` clean against the
# binaries produced by the pre-seam native_aot, and the build lost its last
# warning (a `return <value>` in the void emit_prim). This target keeps the
# region clean by construction and then runs one program end to end.
# ---------------------------------------------------------------------------
.PHONY: test-native-emit-split
test-native-emit-split: $(NATIVE_BIN)
	mkdir -p $(TESTS)
	test $$(grep -c -F 'EMIT-SEAM-BEGIN: the language-level emitter.' tools/sxemit_lib.sa) -eq 1 \
	  || { echo "[FAIL] the EMIT-SEAM-BEGIN marker is missing or duplicated"; exit 1; }
	test $$(grep -c -F 'EMIT-SEAM-END: below this line' tools/sxemit_lib.sa) -eq 1 \
	  || { echo "[FAIL] the EMIT-SEAM-END marker is missing or duplicated"; exit 1; }
	test $$(grep -c -F 'make collect_defs(' tools/sxinfer_lib.sa) -eq 1 \
	  || { echo "[FAIL] the phase-1 collect_defs entry is missing or duplicated"; exit 1; }
	test $$(grep -c -F 'make make_enc_state(' tools/sxenc_lib.sa) -eq 1 \
	  || { echo "[FAIL] the encoder entry is missing or duplicated"; exit 1; }
	b=$$(grep -n -F 'EMIT-SEAM-BEGIN: the language-level emitter.' tools/sxemit_lib.sa | cut -d: -f1); \
	 e=$$(grep -n -F 'EMIT-SEAM-END: below this line' tools/sxemit_lib.sa | cut -d: -f1); \
	 if [ "$$b" -ge "$$e" ]; then echo "[FAIL] the emit-seam markers are out of order"; exit 1; fi; \
	 tail -n +$$((b + 1)) tools/sxemit_lib.sa | head -n $$((e - b - 1)) > $(TESTS)/seam_region.sa; \
	 for pat in 'e1(' 'e16(' 'e32(' 'enc_code_at(' '36000'; do \
	   if grep -q -F "$$pat" $(TESTS)/seam_region.sa; then \
	     echo "[FAIL] the language emitter writes code bytes directly: $$pat"; \
	     grep -n -F "$$pat" $(TESTS)/seam_region.sa | head -3; exit 1; fi; \
	 done; \
	 if [ -n "$$(grep -n -F 'est[' $(TESTS)/seam_region.sa | head -3)" ]; then \
	   echo "[FAIL] the language emitter reads the encoder state directly (use here_local()):"; \
	   grep -n -F 'est[' $(TESTS)/seam_region.sa | head -3; exit 1; fi; \
	 echo "[OK] emit seam: $$((e - b)) lines of Sayanox language-level emitter, no raw byte write, no direct cursor read"
	# ---- the seam API is defined in tools/sxenc_lib.sa, separate from phase 1/3 ----
	for fn in 'make here_local(' 'make patch_imm32(' 'make leave_ret(' \
	          'make sub_rsp_imm32_slot(' 'make jmp5_slot(' 'make erel32j('; do \
	  grep -q -F "$$fn" tools/sxenc_lib.sa \
	    || { echo "[FAIL] seam helper is not defined in tools/sxenc_lib.sa: $$fn"; exit 1; }; \
	done
	echo "[OK] emit seam: here_local/patch_imm32/leave_ret/sub_rsp_imm32_slot/jmp5_slot/erel32j are all tools/sxenc_lib.sa primitives"
	# ---- and the Sayanox backend works end to end ----
	./$(NATIVE_BIN) selfhost/generic_struct_concrete.sa $(TESTS)/seam_nat
	$(call assert-out,./$(TESTS)/seam_nat,7\nseven\n8\neight\n2\n8\n9)
	./$(NATIVE_BIN) selfhost/native_strord_test.sa $(TESTS)/seam_nat2
	test -x $(TESTS)/seam_nat2 && ./$(TESTS)/seam_nat2 > $(TESTS)/seam_nat2.out
	echo "[OK] native emit split: the Sayanox language emitter is backend-free, tools/sxenc_lib.sa and phase-4/4b stubs are the only machine code, and emitted programs run"

# ---------------------------------------------------------------------------
# test-native-ir-log: the emit tree's instruction list is inspectable, and
# pinned -- the specification a second backend is written against.
#
# test-native-emit-split proves the language-level emitter reaches the machine
# only through the encoder API, and docs/NATIVE.md lists that API. What was
# still prose is the CONTENT of the contract: which instructions, in which
# order, with which operands, and which slots stay unresolved until a fixup.
# SX_EMIT_LOG=<path> makes every encoder primitive write one line -- the code
# offset the instruction starts at, the mnemonic and the operands in assembly
# order -- plus a "; " line for each label slot, each fixup, each emitted make
# and each phase. That file is the instruction list: a riscv64 or ARM64 backend
# is a program that produces the same list with its own mnemonics and its own
# encodings, and this target pins the list the x86-64 one produces for a
# fixture using numbers, strings, a list, a branch, a loop and two makes.
#
# The recorder only READS the primitives' arguments, so nothing about the bytes
# changes: the ELF built with the log is cmp'd against the ELF built without
# it, and two logged runs are cmp'd against each other. The log's own
# invariants are checked as well -- every line is an instruction line or a
# comment line, the offsets never go backwards, every rel32 fixup lands on a
# jump, no call target or operand falls back to a placeholder name, the six
# phases come in order -- the mnemonic vocabulary of the fixture's top level is
# pinned exactly, and the language emitter is asserted never to touch the
# recorder state: only the encoder records instructions.
#
# This is a step TOWARDS a second target, not a second target: there is still
# exactly one emitter of machine code, and docs/NATIVE_IR.md says so.
# ---------------------------------------------------------------------------
IRL_FIX := selfhost/native_ir_log_test.sa
IRL_MN_WANT := add addsd call cvtsi2sd cvttsd2si jae je jmp lea mov movq movzx mulsd pop push seta ucomisd
IRL_OFF6 := [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]
.PHONY: test-native-ir-log
test-native-ir-log: $(NATIVE_BIN)
	mkdir -p $(TESTS)
	# ---- 1. the fixture still runs and prints the hand-computed values ----
	./$(NATIVE_BIN) $(IRL_FIX) $(TESTS)/irl_nat
	$(call assert-out,./$(TESTS)/irl_nat,42\nir-log\n6\n3\n42\nir-log-done)
	# ---- 2. the recorder is inert: not one emitted byte changes ----
	SX_EMIT_LOG=$(TESTS)/irl.log ./$(NATIVE_BIN) $(IRL_FIX) $(TESTS)/irl_logged
	cmp $(TESTS)/irl_nat $(TESTS)/irl_logged
	echo "[OK] native ir log: SX_EMIT_LOG changes no emitted byte (the two ELFs cmp clean)"
	# ---- 3. the instruction list is a function of the source ----
	SX_EMIT_LOG=$(TESTS)/irl_again.log ./$(NATIVE_BIN) $(IRL_FIX) $(TESTS)/irl_logged2
	cmp $(TESTS)/irl.log $(TESTS)/irl_again.log
	echo "[OK] native ir log: the same source gives the same instruction list ($$(grep -c . $(TESTS)/irl.log) lines)"
	# ---- 4. every line is an instruction line or a '; ' comment line ----
	test $$(grep -c -v -E '^([0-9a-f]{6}  |;)' $(TESTS)/irl.log) -eq 0 \
	  || { echo "[FAIL] the instruction list has a line in neither format:"; grep -n -v -E '^([0-9a-f]{6}  |;)' $(TESTS)/irl.log | head -3; exit 1; }
	# ---- 5. the log's invariants: monotonic offsets, fixups land on jumps,
	#         six phases in order, a reported code size ----
	@# POSIX shell + grep/cut/sort/paste: no awk. Each check appends to `bad`.
	@log=$(TESTS)/irl.log; bad=0; \
	 np=$$(grep -c -F '=== phase:' $$log); \
	 if [ "$$np" -ne 6 ]; then echo "[FAIL] expected 6 phase markers, got $$np"; bad=1; fi; \
	 fx=$$(grep -c -E '^;       fixup' $$log); \
	 if [ "$$fx" -lt 1 ]; then echo "[FAIL] the list has no fixup line, so no unresolved slot was resolved"; bad=1; fi; \
	 tot=$$(grep -E '^;       code bytes: ' $$log | tr -s ' ' | cut -d' ' -f4); \
	 if [ "$${tot:-0}" -le 0 ] 2>/dev/null; then echo "[FAIL] the list does not report its code size"; bad=1; fi; \
	 grep -E '^[0-9a-f]{6}  ' $$log | cut -c1-6 > $(TESTS)/irl_offsets.txt; \
	 if ! LC_ALL=C sort -c $(TESTS)/irl_offsets.txt 2>/dev/null; then \
	   echo "[FAIL] the instruction offsets go backwards"; bad=1; fi; \
	 grep -E '^[0-9a-f]{6}  ' $$log | cut -c9- | cut -d' ' -f1 > $(TESTS)/irl_mnem.txt; \
	 paste -d' ' $(TESTS)/irl_offsets.txt $(TESTS)/irl_mnem.txt | \
	   while IFS=' ' read -r __off __mn; do case "$$__mn" in j*) echo "$$__off" ;; esac; done > $(TESTS)/irl_jumps.txt; \
	 grep -E '^;       fixup' $$log | cut -d'[' -f2 | cut -c1-6 > $(TESTS)/irl_fixups.txt; \
	 while IFS= read -r __target; do \
	   if ! grep -q -x "$$__target" $(TESTS)/irl_jumps.txt; then \
	     echo "[FAIL] a rel32 fixup does not land on a jump: [$$__target]"; bad=1; fi; \
	 done < $(TESTS)/irl_fixups.txt; \
	 if [ "$$bad" -ne 0 ]; then exit 1; fi
	@i=$$(grep -c -E '^[0-9a-f]{6}  ' $(TESTS)/irl.log); sl=$$(grep -c -F ';       slot ' $(TESTS)/irl.log); fx=$$(grep -c -F ';       fixup' $(TESTS)/irl.log); \
	 echo "[OK] native ir log: $$i instructions, $$sl label slots, $$fx rel32 fixups, monotonic offsets, six phases in order"
	# ---- 6. every call target and every operand has a real name ----
	test $$(grep -c -E 'call builtin id[0-9]|call make make[0-9]|bin[0-9a-f][0-9a-f] |grp1_[0-9]|jcc[0-9]+ |setcc[0-9]+ |f7\?|xmm\?|r32\?|[^a-z0-9]r\?' $(TESTS)/irl.log) -eq 0 \
	  || { echo "[FAIL] a call target or an operand fell back to a placeholder name:"; grep -n -E 'call builtin id[0-9]|call make make[0-9]|bin[0-9a-f][0-9a-f] |grp1_[0-9]|jcc[0-9]+ |setcc[0-9]+ |f7\?|xmm\?|r32\?|[^a-z0-9]r\?' $(TESTS)/irl.log | head -3; exit 1; }
	# ---- 7. the machine model is visible in the list ----
	@for pat in 'movq xmm0,rcx' 'movq xmm1,rax' 'addsd xmm0,xmm1' 'mulsd xmm0,xmm1' 'movq rax,xmm0' \
	              'ucomisd xmm0,xmm1' 'seta eax' 'movzx rax,al' 'cvtsi2sd xmm0,rax' 'cvttsd2si rax,xmm0' \
	              'call make twice' 'call make join' '--- make twice[0] at ' '--- make join[1] at ' \
	              'call builtin concat' 'call builtin putstr' 'call builtin strlen' 'call builtin shownum' \
	              'call builtin mlist' 'call builtin lpush' 'call builtin lget' 'call builtin llen' \
	              'sub rsp,<imm32 slot>' 'lea r12,[rip+<disp32 slot>]' 'leave' 'ret'; do \
	  grep -q -F -e "$$pat" $(TESTS)/irl.log || { echo "[FAIL] the instruction list is missing: $$pat"; exit 1; }; \
	done
	echo "[OK] native ir log: numbers are double bits through xmm, strings and lists are named stub calls, makes are named call targets"
	# ---- 8. the instruction vocabulary of the fixture's top level, pinned ----
	@b=$$(grep -n -F '=== phase: top level' $(TESTS)/irl.log | cut -d: -f1); \
	 e=$$(grep -n -F '=== phase: exit syscall' $(TESTS)/irl.log | cut -d: -f1); \
	 got=$$(tail -n +$$((b + 1)) $(TESTS)/irl.log | head -n $$((e - b - 1)) | grep -E '^[0-9a-f]{6}  ' | cut -c9- | cut -d' ' -f1 | sort -u | tr '\n' ' '); \
	 got=$${got% }; \
	 if [ "$$got" = "$(IRL_MN_WANT)" ]; then :; else \
	   echo "[FAIL] the top level's instruction vocabulary changed"; \
	   echo "--- want ---"; echo "$(IRL_MN_WANT)"; echo "--- got ---"; echo "$$got"; \
	   echo "(if that is intentional, update IRL_MN_WANT and say why in docs/NATIVE_IR.md)"; exit 1; fi
	echo "[OK] native ir log: the fixture's top level emits exactly these mnemonics: $(IRL_MN_WANT)"
	# ---- 9. only the encoder records; the emitter may announce, not write ----
	@b=$$(grep -n -F 'EMIT-SEAM-BEGIN: the language-level emitter.' tools/sxemit_lib.sa | cut -d: -f1); \
	 e=$$(grep -n -F 'EMIT-SEAM-END: below this line' tools/sxemit_lib.sa | cut -d: -f1); \
	 tail -n +$$((b + 1)) tools/sxemit_lib.sa | head -n $$((e - b - 1)) > $(TESTS)/irl_seam.sa; \
	 test $$(grep -c -E 'ilog_inst|ilog_push' $(TESTS)/irl_seam.sa) -eq 0 \
	  || { echo "[FAIL] the language emitter touches the recorder state:"; grep -n -E 'ilog_inst|ilog_push' $(TESTS)/irl_seam.sa | head -3; exit 1; }
	echo "[OK] native ir log: the instruction list is written by the encoder alone -- a second backend replaces the encoder and keeps the emit tree"

# ---------------------------------------------------------------------------
# test-sxpkg-online-optin: the network is opt-in, and the offline path is not.
#
# `SAYANOX_REGISTRY` decides WHERE a transfer goes; it is no longer permission
# to transfer. `sync`, `install` (when it actually has to fetch) and `fetch`
# refuse without `SAYANOX_ONLINE=1` or `sxpkg --online <command>`, and they
# refuse BEFORE any transfer starts, so a checkout, a CI runner or a bootstrap
# gate can never reach a host by accident. A `file://` URL or a plain local
# path is not the network and needs no opt-in -- that is how
# test-sxpkg-online-local exercises the whole transfer, verify and rollback
# path without a socket.
#
# Every remote URL here is a `.invalid` host (RFC 2606: guaranteed not to
# resolve), so the opt-in leg fails in the test stub (no network) within milliseconds and the
# target does not depend on connectivity in either direction.
# ---------------------------------------------------------------------------

# test-native-ir-portable: the SX_EMIT_LOG instruction list translates to the
# IR analysis listing (tools/emit_to_ir.sa, docs/NATIVE_IR.md) with instruction
# counts and deterministic source-offset correlation preserved. The IR is an analysis format -- this target pins the
# translation, and deliberately does NOT claim a second backend or ISA.
# tools/emit_to_ir is now a Sayanox program: gen2 compiles it, cc builds it.
# It writes the listing to stdout, so call sites redirect.
tools/emit_to_ir: tools/emit_to_ir.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/emit_to_ir.sa $@
	@echo "[OK] Sayanox IR translator built C-free from tools/emit_to_ir.sa"

.PHONY: test-emit-to-ir
test-emit-to-ir: tools/emit_to_ir tools/sxsuite
	./tools/sxsuite ir_audit $(TESTS)/emit-tool

test-native-ir-portable: $(NATIVE_BIN) tools/emit_to_ir test-emit-to-ir
	@mkdir -p $(TESTS)
	./$(NATIVE_BIN) $(IRL_FIX) $(TESTS)/irp_nat >/dev/null
	$(call assert-out,./$(TESTS)/irp_nat,42\nir-log\n6\n3\n42\nir-log-done)
	SX_EMIT_LOG=$(TESTS)/irp.log ./$(NATIVE_BIN) $(IRL_FIX) $(TESTS)/irp_logged
	./tools/emit_to_ir $(TESTS)/irp.log > $(TESTS)/irp.ir
	./tools/emit_to_ir $(TESTS)/irp.log > $(TESTS)/irp_again.ir
	cmp $(TESTS)/irp.ir $(TESTS)/irp_again.ir
	./tools/emit_to_ir --strict --source-offsets $(TESTS)/irp.log > $(TESTS)/irp_audit.ir
	./tools/emit_to_ir --strict --source-offsets $(TESTS)/irp.log > $(TESTS)/irp_audit_again.ir
	cmp $(TESTS)/irp_audit.ir $(TESTS)/irp_audit_again.ir
	@grep -v '^; source-offset ' $(TESTS)/irp_audit.ir > $(TESTS)/irp_audit_base.ir
	cmp $(TESTS)/irp.ir $(TESTS)/irp_audit_base.ir
	@test $$(grep -c '^; source-offset ' $(TESTS)/irp_audit.ir) -eq $$(grep -cE '^I[0-9]+ ' $(TESTS)/irp.ir)
	@# instruction-preserving: register widths/ISA semantics are NOT lossless
	@test $$(grep -cE '^I[0-9]+ ' $(TESTS)/irp.ir) -eq $$(grep -cE '^[0-9a-f]{6}  ' $(TESTS)/irp.log) \
	  || { echo "[FAIL] the IR dropped or invented an instruction"; exit 1; }
	@# portable: no x86 register name survives translation
	@test $$(grep -E '^I[0-9]+ ' $(TESTS)/irp.ir | grep -cE '\b(rax|rcx|rdx|rbx|rsp|rbp|rsi|rdi|r1[2-5]|xmm[0-9]+)\b') -eq 0 \
	  || { echo "[FAIL] an x86 register name survived into the IR:"; grep -E '^I[0-9]+ ' $(TESTS)/irp.ir | grep -nE '\b(rax|rcx|rdx|rbx|rsp|rbp|rsi|rdi|r1[2-5]|xmm[0-9]+)\b' | head -3; exit 1; }
	@# the machine model survives in abstract form
	@for pat in 'FADD ' 'CALL make twice' 'CALL builtin shownum' '=== phase: make bodies' 'I2F ' 'FCMP '; do \
	  grep -q -F "$$pat" $(TESTS)/irp.ir || { echo "[FAIL] the IR lost '$$pat'"; exit 1; }; \
	done
	@echo '[OK] IR analysis listing: instruction counts/calls/phases preserved; strict record/offset audit and source correlation deterministic; register widths abstracted (this listing is still not an executable second ISA; the executable one is tools/native32.sa, make test-native32)'
native-test: test-native-ir-portable

# ---------------------------------------------------------------------------
# tools/sxlink: the Sayanox ELF image writer and linker (Phase D step 3).
#
# selfhost/native_aot.c compiles a program into a code blob, a data blob and a
# list of rel32 sites; write_elf() in that file is what turns those into a
# runnable static ELF. SX_LINK_DUMP=<dir> dumps exactly those three inputs --
# code.bin, data.bin, patch.bin and a meta.txt with the call-patch count -- and
# tools/sxlink.sa rebuilds the image from them: ELF header, three program
# headers, page rounding, padding, the collector's heap cursor and every rel32
# fixup, using nothing but push / xs[i] / len / % / shr / bit_and / write_bytes
# and read_bytes.
#
# The gate is byte identity plus execution: the Sayanox-linked file must be the
# same bytes as the C-linked one and must run and print the same thing. It also
# pins that the dump changes no emitted byte, the way test-native-ir-log pins
# SX_EMIT_LOG.
#
# What is still C, stated plainly: native_aot resolves a `make` or builtin name
# to a code offset, so the patch records arrive with their targets resolved.
# This is the image writer and the linker, not the whole backend.
SXLINK_BIN := tools/sxlink
SXLINK_SA  := tools/sxlink.sa

tools/sxlink: $(SXLINK_SA) tools/sxlink_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXLINK_SA) $@
	@echo "[OK] Sayanox ELF linker built C-free from $(SXLINK_SA)"

.PHONY: test-native-sxlink
test-native-sxlink: $(NATIVE_BIN) $(SXLINK_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxlink
	@# One fixture per shape that moves the image: a bare program, recursion
	@# (call rel32s), a data segment full of strings plus a collection, a
	@# string-ordering program and a multi-page code segment. Each is a shape
	@# the native backend already compiles elsewhere in this suite, so the
	@# gate adds a comparison rather than inventing coverage.
	@printf 'hold x = 40\nhold x = x + 2\nshow x\n' > $(TESTS)/sxlink_hello.sa
	@printf 'make fac(n) {\n  when n <= 1 {\n    give 1\n  }\n  give n * fac(n - 1)\n}\nmake fib(n) {\n  when n <= 1 {\n    give n\n  } else {\n    give fib(n - 1) + fib(n - 2)\n  }\n}\nshow fac(6)\nshow fib(20)\n' > $(TESTS)/sxlink_fn.sa
	@# strings in the data segment, a struct that holds them, and a loop that
	@# grows one: the data blob and the collector's root table both move
	@printf 'struct Item {\n  name,\n  count\n}\nhold it = Item { name: "first", count: 3 }\nshow it.name\nshow it.count\nhold s = ""\nhold i = 0\nwhile i < 40 {\n  s = concat(s, "sayanox")\n  i = i + 1\n}\nshow len(s)\nshow sx_index(s, 250)\nhold items = [1, 2, 3]\npush(items, 4)\nshow len(items)\nshow gc()\n' > $(TESTS)/sxlink_data.sa
	@for fix in $(TESTS)/sxlink_hello.sa $(TESTS)/sxlink_fn.sa $(TESTS)/sxlink_data.sa selfhost/native_strord_test.sa selfhost/stdlib_growth_test.sa; do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  mkdir -p $(TESTS)/sxlink/$$name; \
	  ./$(NATIVE_BIN) $$fix $(TESTS)/sxlink/$$name/off.elf; \
	  SX_LINK_DUMP=$(TESTS)/sxlink/$$name ./$(NATIVE_BIN) $$fix $(TESTS)/sxlink/$$name/c.elf; \
	  cmp $(TESTS)/sxlink/$$name/off.elf $(TESTS)/sxlink/$$name/c.elf \
	    || { echo "[FAIL] sxlink: SX_LINK_DUMP changed the emitted bytes for $$name"; exit 1; }; \
	  ./tools/sxlink $(TESTS)/sxlink/$$name/c.elf $(TESTS)/sxlink/$$name $(TESTS)/sxlink/$$name/sx.elf > $(TESTS)/sxlink/$$name/report; \
	  cmp $(TESTS)/sxlink/$$name/c.elf $(TESTS)/sxlink/$$name/sx.elf \
	    || { echo "[FAIL] sxlink: the Sayanox-linked image is not byte-identical for $$name"; exit 1; }; \
	  chmod +x $(TESTS)/sxlink/$$name/c.elf $(TESTS)/sxlink/$$name/sx.elf; \
	  $(TESTS)/sxlink/$$name/c.elf > $(TESTS)/sxlink/$$name/c.out 2>&1 || true; \
	  $(TESTS)/sxlink/$$name/sx.elf > $(TESTS)/sxlink/$$name/sx.out 2>&1 || true; \
	  cmp $(TESTS)/sxlink/$$name/c.out $(TESTS)/sxlink/$$name/sx.out \
	    || { echo "[FAIL] sxlink: the Sayanox-linked executable behaves differently for $$name"; exit 1; }; \
	  echo "  [ok] $$name: $$(wc -c < $(TESTS)/sxlink/$$name/c.elf) bytes, $$(cut -d' ' -f1-2 $(TESTS)/sxlink/$$name/meta.txt 2>/dev/null || head -c 20 $(TESTS)/sxlink/$$name/meta.txt) patches"; \
	done
	@# the C-linked hello must still print 42, so the comparison above is not
	@# two identical failures
	$(call assert-out,$(TESTS)/sxlink/sxlink_hello/sx.elf,42)
	@# Byte identity to write_elf() is only evidence while the two agree. These
	@# pin the layout sxlink hard-codes, so a change on the C side fails here
	@# with the reason instead of appearing as an unexplained cmp diff -- and a
	@# change on BOTH sides still fails, because the contract below is the
	@# documented one, not whatever the two implementations happen to share.
	@test "$$(od -An -tx1 -v -N 8 $(TESTS)/sxlink/sxlink_hello/c.elf | tr -d ' \n')" = 7f454c4602010100 \
	  || { echo "[FAIL] sxlink: the ELF ident bytes moved"; exit 1; }
	@test "$$(od -An -tu2 -v -j 56 -N 2 $(TESTS)/sxlink/sxlink_hello/c.elf | tr -d ' \n')" = 3 \
	  || { echo "[FAIL] sxlink: write_elf no longer emits exactly three program headers"; exit 1; }
	@test "$$(od -An -tu8 -v -j 24 -N 8 $(TESTS)/sxlink/sxlink_hello/c.elf | tr -d ' \n')" = 4198400 \
	  || { echo "[FAIL] sxlink: the entry point is no longer BASE 0x400000 + the 0x1000 code offset"; exit 1; }
	@test "$$(od -An -tu8 -v -j 128 -N 8 $(TESTS)/sxlink/sxlink_hello/c.elf | tr -d ' \n')" = 4096 \
	  || { echo "[FAIL] sxlink: the code segment (phdr 1, p_offset at 128) no longer starts on page 1"; exit 1; }
	@test "$$(od -An -tu8 -v -j 184 -N 8 $(TESTS)/sxlink/sxlink_hello/c.elf | tr -d ' \n')" = 12288 \
	  || { echo "[FAIL] sxlink: the data segment (phdr 2, p_offset at 184) no longer follows the page-rounded code segment"; exit 1; }
	@# a missing dump is a clear error, not a silently short file
	@if ./tools/sxlink $(TESTS)/sxlink/sxlink_hello/c.elf $(TESTS)/sxlink/nope $(TESTS)/sxlink/bad.elf >/dev/null 2>&1; then \
	  echo "[FAIL] sxlink accepted a dump directory that does not exist"; exit 1; fi
	@./tools/sxlink $(TESTS)/sxlink/sxlink_hello/c.elf $(TESTS)/sxlink/nope $(TESTS)/sxlink/bad.elf 2>&1 >/dev/null | grep -q 'cannot read code.bin'
	@# and a file that is not an ELF is refused before anything is written
	@if ./tools/sxlink Makefile $(TESTS)/sxlink/sxlink_hello $(TESTS)/sxlink/bad2.elf >/dev/null 2>&1; then \
	  echo "[FAIL] sxlink accepted a non-ELF linked file"; exit 1; fi
	@./tools/sxlink Makefile $(TESTS)/sxlink/sxlink_hello $(TESTS)/sxlink/bad2.elf 2>&1 >/dev/null | grep -q 'not an ELF'
	@echo "[OK] sxlink: five fixtures link byte-identically to write_elf and run identically; the dump changes no emitted byte; the ELF ident, the three program headers, the entry point and the page-1 code offset are pinned; missing dump and non-ELF input are clear errors"

# ---------------------------------------------------------------------------
# tools/native32 + test-native32: a SECOND machine-code target (2026-10-23).
#
# docs/STATUS.md carried "a second native ISA: none -- x86-64 Linux only" as
# an open row. tools/native32.sa closes the narrow, provable version of it: a
# Sayanox program becomes a 32-bit x86 (i386) Linux ELF, emitted by a backend
# that is itself written in Sayanox and compiled by gen2. It is an
# independent front end and an independent encoder; it reproduces none of
# native_aot's instruction list.
#
# What this gate proves:
#   * three fixtures print the same bytes on FOUR backends -- seed-min (C),
#     gen2 (C), native_aot (x86-64 machine code) and native32 (i386 machine
#     code). Two of those are machine-code backends for different ISAs.
#   * the container really is i386: ELFCLASS32 + EM_386, against native_aot's
#     ELFCLASS64 + EM_X86_64 for the same source file.
#   * emission is deterministic, and the entry point, the program-header
#     count and the image sizes are pinned.
#   * fifteen out-of-subset programs are refused with a diagnostic and exit 1,
#     and the ones that are legal Sayanox still run on seed-min -- so the
#     refusals are a subset boundary, not a broken front end.
#
# What it does NOT claim: this is not the full native runtime. The current
# subset has integers, static string spans, len(), byte indexing, and bounded
#     variable/literal concat, but no general string operations, lists, structs, functions,
# FP code generation, GC or general file API; `/` remains refused because
# Sayanox numbers are doubles. `sxisaexec` runs the tested AArch64/RV64 subset.
# See docs/NATIVE32.md; native_aot remains the x86-64 backend.
#
# Running the i386 binaries needs a kernel with IA32 emulation. Without it
# the byte assertions still run and the execution ones say [SKIP].
# ---------------------------------------------------------------------------
SXA_BIN := tools/sxaudit
SXA_SA  := tools/sxaudit.sa

tools/sxaudit: $(SXA_SA) stdlib/crypto.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXA_SA) $@
	@echo '[OK] the trust-anchor auditor built C-free from tools/sxaudit.sa'

SXM_BIN := tools/sxmod
SXM_SA  := tools/sxmod.sa
SXM_T   := selfhost/sxmod_tests

tools/sxmod: $(SXM_SA) tools/sxmod_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXM_SA) $@
	@echo '[OK] the namespacing pass built C-free from tools/sxmod.sa'

N32_BIN := tools/native32
N32_SA  := tools/native32.sa
N32_T   := selfhost/native32_tests

tools/native32: $(N32_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(N32_SA) $@
	@echo "[OK] the multi-ISA backend built C-free from $(N32_SA)"

.PHONY: test-native32
test-native32: $(SEED_MIN_BIN) $(GEN2) $(N32_BIN)
	@mkdir -p $(TESTS)/n32
	@printf 'show 1\n' > $(TESTS)/n32/canary.sa
	@./$(N32_BIN) $(TESTS)/n32/canary.sa $(TESTS)/n32/canary
	@chmod +x $(TESTS)/n32/canary
	@run=1; ./$(TESTS)/n32/canary > $(TESTS)/n32/canary.out 2>/dev/null || run=0; \
	 if [ "$$run" = 1 ] && [ "$$(cat $(TESTS)/n32/canary.out)" != "1" ]; then run=0; fi; \
	 echo $$run > $(TESTS)/n32/runnable
	@if [ "$$(cat $(TESTS)/n32/runnable)" = 0 ]; then \
	  echo "[SKIP] this kernel cannot execute i386 binaries; the byte assertions below still run"; fi
	@for f in expr flow text; do \
	  ./$(SEED_MIN_BIN) $(N32_T)/$$f.sa > $(TESTS)/n32/$$f.ms.c; \
	  $(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/n32/$$f.ms $(TESTS)/n32/$$f.ms.c; \
	  ./$(TESTS)/n32/$$f.ms > $(TESTS)/n32/$$f.want; \
	  ./$(GEN2) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.g2.c >/dev/null; \
	  $(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/n32/$$f.g2 $(TESTS)/n32/$$f.g2.c; \
	  ./$(TESTS)/n32/$$f.g2 > $(TESTS)/n32/$$f.g2.out; \
	  cmp $(TESTS)/n32/$$f.want $(TESTS)/n32/$$f.g2.out \
	    || { echo "[FAIL] gen2 disagrees with seed-min on $$f.sa"; exit 1; }; \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.elf \
	    || { echo "[FAIL] native32 refused $$f.sa, which is inside its documented subset"; exit 1; }; \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.elf2; \
	  cmp $(TESTS)/n32/$$f.elf $(TESTS)/n32/$$f.elf2 \
	    || { echo "[FAIL] native32 emitted different bytes for $$f.sa on a second run"; exit 1; }; \
	  chmod +x $(TESTS)/n32/$$f.elf; \
	  if [ -x $(NATIVE_BIN) ]; then \
	    ./$(NATIVE_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.nat >/dev/null; \
	    ./$(TESTS)/n32/$$f.nat > $(TESTS)/n32/$$f.nat.out; \
	    cmp $(TESTS)/n32/$$f.want $(TESTS)/n32/$$f.nat.out \
	      || { echo "[FAIL] native_aot disagrees with seed-min on $$f.sa"; exit 1; }; \
	  fi; \
	  if [ "$$(cat $(TESTS)/n32/runnable)" = 1 ]; then \
	    ./$(TESTS)/n32/$$f.elf > $(TESTS)/n32/$$f.got; \
	    cmp $(TESTS)/n32/$$f.want $(TESTS)/n32/$$f.got \
	      || { echo "[FAIL] the i386 binary for $$f.sa printed something else"; exit 1; }; \
	  fi; \
	done
	@if [ "$$(cat $(TESTS)/n32/runnable)" = 1 ]; then \
	  echo '[OK] i386: expr, flow and text print the same bytes under seed-min, gen2, native_aot and native32 -- four backends, two instruction sets'; \
	else echo '[SKIP] the i386 binaries were emitted and compared byte-for-byte, but not executed'; fi
	@# the container is really i386, and really different from native_aot's
	@test "$$(od -An -tx1 -v -N 8 $(TESTS)/n32/expr.elf | tr -d ' \n')" = 7f454c4601010100 \
	  || { echo "[FAIL] native32: the image is no longer ELFCLASS32"; exit 1; }
	@test "$$(od -An -tu2 -v -j 16 -N 2 $(TESTS)/n32/expr.elf | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] native32: the image is no longer ET_EXEC"; exit 1; }
	@test "$$(od -An -tu2 -v -j 18 -N 2 $(TESTS)/n32/expr.elf | tr -d ' \n')" = 3 \
	  || { echo "[FAIL] native32: e_machine is no longer EM_386"; exit 1; }
	@test "$$(od -An -tu2 -v -j 44 -N 2 $(TESTS)/n32/expr.elf | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] native32: the image no longer has exactly two program headers"; exit 1; }
	@test "$$(od -An -tu4 -v -j 24 -N 4 $(TESTS)/n32/expr.elf | tr -d ' \n')" = 134512842 \
	  || { echo "[FAIL] native32: the entry point moved (0x08048000 + 116 header bytes + the 86-byte print-decimal routine)"; exit 1; }
	@test "$$(wc -c < $(TESTS)/n32/expr.elf)" = 4140 || { echo "[FAIL] native32: expr.sa no longer emits a 4140-byte image"; exit 1; }
	@test "$$(wc -c < $(TESTS)/n32/flow.elf)" = 4172 || { echo "[FAIL] native32: flow.sa no longer emits a 4172-byte image"; exit 1; }
	@test "$$(wc -c < $(TESTS)/n32/text.elf)" = 4185 || { echo "[FAIL] native32: text.sa no longer emits a 4185-byte image"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  test "$$(od -An -tx1 -v -N 8 $(TESTS)/n32/expr.nat | tr -d ' \n')" = 7f454c4602010100 \
	    || { echo "[FAIL] native_aot's image is no longer ELFCLASS64"; exit 1; }; \
	  test "$$(od -An -tu2 -v -j 18 -N 2 $(TESTS)/n32/expr.nat | tr -d ' \n')" = 62 \
	    || { echo "[FAIL] native_aot's image is no longer EM_X86_64"; exit 1; }; \
	fi
	@echo '[OK] i386 container: ELFCLASS32 / ET_EXEC / EM_386, two program headers, entry 0x080480ca, three pinned image sizes, byte-deterministic -- native_aot on the same source is ELFCLASS64 / EM_X86_64'
	@# out-of-subset programs are refused by name, never miscompiled
	@for f in $(N32_T)/refuse/*.sa; do \
	  if ./$(N32_BIN) $$f $(TESTS)/n32/bad.elf > $(TESTS)/n32/bad.err 2>&1; then \
	    echo "[FAIL] native32 accepted $$f, which is outside its subset"; exit 1; fi; \
	  grep -q 'native32: ' $(TESTS)/n32/bad.err \
	    || { echo "[FAIL] $$f was refused without a native32 diagnostic"; exit 1; }; \
	done
	@echo '[OK] i386 refusals: division, fractions, string concatenation/NUL, string type misuse, len(number), functions, lists, unknown names, &&, 2^31 and unclosed blocks are each refused with a diagnostic and a non-zero exit'
	@# and the refused programs that are legal Sayanox still run elsewhere,
	@# so this is a subset boundary rather than a broken front end
	@for f in division strvalue nulstring function list concat_call concat_expression; do \
	  ./$(SEED_MIN_BIN) $(N32_T)/refuse/$$f.sa > $(TESTS)/n32/ok_$$f.c; \
	  $(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/n32/ok_$$f $(TESTS)/n32/ok_$$f.c; \
	  ./$(TESTS)/n32/ok_$$f > /dev/null \
	    || { echo "[FAIL] refuse/$$f.sa does not even run on seed-min, so it is a broken program and proves nothing"; exit 1; }; \
	done
	@$(call assert-out,./$(TESTS)/n32/ok_division,3.5)
	@echo '[OK] i386 subset boundary: all seven refused programs that are legal Sayanox still run on seed-min (7 / 2 is 3.5; concat with a nested string expression remains outside this backend subset)'
	@./$(N32_BIN) $(N32_T)/heap_exhaust.sa $(TESTS)/n32/heap_exhaust.i386
	@chmod +x $(TESTS)/n32/heap_exhaust.i386
	@if [ "$$(cat $(TESTS)/n32/runnable)" = 1 ]; then \
	  ./$(TESTS)/n32/heap_exhaust.i386 > $(TESTS)/n32/heap_exhaust.i386.out; rc=$$?; \
	  test "$$rc" = 1 || { echo "[FAIL] i386 concat heap exhaustion returned $$rc instead of 1"; exit 1; }; \
	  test ! -s $(TESTS)/n32/heap_exhaust.i386.out || { echo "[FAIL] i386 heap-limit fixture reached unreachable output"; exit 1; }; \
	  echo '[OK] i386 concat heap exhaustion is bounded and exits 1'; \
	else echo '[SKIP] i386 concat heap exhaustion runtime: kernel lacks IA32 execution'; fi
	@./$(N32_BIN) $(N32_T)/string_index_oob.sa $(TESTS)/n32/string_index_oob.i386
	@chmod +x $(TESTS)/n32/string_index_oob.i386
	@if [ "$$(cat $(TESTS)/n32/runnable)" = 1 ]; then \
	  ./$(TESTS)/n32/string_index_oob.i386 > $(TESTS)/n32/string_index_oob.i386.out; rc=$$?; \
	  test "$$rc" = 1 || { echo "[FAIL] i386 out-of-range string index returned $$rc instead of 1"; exit 1; }; \
	  test ! -s $(TESTS)/n32/string_index_oob.i386.out || { echo "[FAIL] i386 out-of-range string index wrote output"; exit 1; }; \
	  echo '[OK] i386 string indexing rejects out-of-range reads'; \
	else echo '[SKIP] i386 string-index bounds runtime: kernel lacks IA32 execution'; fi

native-test: test-native32


# ---------------------------------------------------------------------------
# test-native-arm64: the SAME front end, a second encoder, a third ISA.
#
# tools/native32.sa takes `arm64` as its third argument and emits an
# AArch64 ELF64 instead of an i386 ELF32. This gate pins historical integer
# goldens, container details, deterministic emission and cross-target data
# layout. The separate pure-Sayanox `test-sxisaexec` gate executes compiler
# output on AArch64 and RV64, including the current static-string and bounded concat slice.
# Neither gate claims the backend implements the full architecture or language.
.PHONY: test-native-arm64
test-native-arm64: $(SEED_MIN_BIN) $(N32_BIN)
	@mkdir -p $(TESTS)/n32
	@for f in expr flow text; do \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.a64 arm64 \
	    || { echo "[FAIL] native32 arm64 refused $$f.sa, which is inside its documented subset"; exit 1; }; \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.a64b arm64; \
	  cmp $(TESTS)/n32/$$f.a64 $(TESTS)/n32/$$f.a64b \
	    || { echo "[FAIL] the arm64 encoder emitted different bytes for $$f.sa on a second run"; exit 1; }; \
	  cmp $(TESTS)/n32/$$f.a64 $(N32_T)/golden/$$f.arm64.elf \
	    || { echo "[FAIL] the arm64 image for $$f.sa differs from the reviewed golden $(N32_T)/golden/$$f.arm64.elf"; exit 1; }; \
	done
	@echo '[OK] arm64: expr, flow and text are emitted deterministically and match reviewed goldens; test-sxisaexec executes the AArch64 ELF subset'
	@# the container is really AArch64, and really not the i386 one
	@test "$$(od -An -tx1 -v -N 8 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 7f454c4602010100 \
	  || { echo "[FAIL] the arm64 image is no longer ELFCLASS64"; exit 1; }
	@test "$$(od -An -tu2 -v -j 16 -N 2 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] the arm64 image is no longer ET_EXEC"; exit 1; }
	@test "$$(od -An -tu2 -v -j 18 -N 2 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 183 \
	  || { echo "[FAIL] e_machine is no longer EM_AARCH64 (183)"; exit 1; }
	@test "$$(od -An -tu2 -v -j 54 -N 2 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 56 \
	  || { echo "[FAIL] e_phentsize is no longer the ELF64 value 56"; exit 1; }
	@test "$$(od -An -tu2 -v -j 56 -N 2 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] the arm64 image no longer has exactly two program headers"; exit 1; }
	@test "$$(od -An -tu8 -v -j 24 -N 8 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 4194612 \
	  || { echo "[FAIL] the arm64 entry point moved (0x400000 + 176 header bytes + the 132-byte print-decimal routine)"; exit 1; }
	@test "$$(od -An -tu8 -v -j 80 -N 8 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 4194304 \
	  || { echo "[FAIL] the arm64 text segment no longer loads at 0x400000"; exit 1; }
	@test "$$(od -An -tu8 -v -j 136 -N 8 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 4198400 \
	  || { echo "[FAIL] the arm64 data segment no longer loads at 0x401000"; exit 1; }
	@# the first instruction of the print routine, and the exit sequence at the
	@# end of the text segment, spelled out as bytes: mov w4,w0 ... mov x0,#0 /
	@# mov x8,#93 / svc #0. A careless regeneration of the goldens would have
	@# to reproduce these too.
	@test "$$(od -An -tx1 -v -j 176 -N 4 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = e403002a \
	  || { echo "[FAIL] the arm64 print routine no longer starts with mov w4, w0"; exit 1; }
	@sz=$$(od -An -tu8 -v -j 96 -N 8 $(TESTS)/n32/expr.a64 | tr -d ' \n'); \
	 test "$$(od -An -tx1 -v -j $$((sz - 12)) -N 12 $(TESTS)/n32/expr.a64 | tr -d ' \n')" = 000080d2a80b80d2010000d4 \
	   || { echo "[FAIL] the arm64 text segment no longer ends in mov x0,#0 / mov x8,#93 / svc #0"; exit 1; }
	@echo '[OK] arm64 container: ELFCLASS64 / ET_EXEC / EM_AARCH64, two program headers, entry 0x400134, text at 0x400000 and data at 0x401000, exit via svc #0 with x8=93'
	@# one front end, two encoders: the data segment either encoder lays out
	@# for the same source has to be the same bytes
	@for f in expr flow text; do \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.i32 i386; \
	  tail -c +4097 $(TESTS)/n32/$$f.i32 > $(TESTS)/n32/$$f.d32; \
	  tail -c +4097 $(TESTS)/n32/$$f.a64 > $(TESTS)/n32/$$f.d64; \
	  cmp $(TESTS)/n32/$$f.d32 $(TESTS)/n32/$$f.d64 \
	    || { echo "[FAIL] the i386 and arm64 images for $$f.sa disagree about the data segment"; exit 1; }; \
	  if cmp -s $(TESTS)/n32/$$f.i32 $(TESTS)/n32/$$f.a64; then \
	    echo "[FAIL] the i386 and arm64 images for $$f.sa are identical, so one of the encoders did not run"; exit 1; fi; \
	done
	@echo '[OK] one front end, two encoders: i386 and arm64 lay out byte-identical data segments for the same source while their text segments differ'
	@# the subset boundary does not move when the target changes
	@for f in $(N32_T)/refuse/*.sa; do \
	  if ./$(N32_BIN) $$f $(TESTS)/n32/bad.a64 arm64 > $(TESTS)/n32/bada.err 2>&1; then \
	    echo "[FAIL] the arm64 target accepted $$f, which is outside the subset"; exit 1; fi; \
	  grep -q 'native32: ' $(TESTS)/n32/bada.err \
	    || { echo "[FAIL] $$f was refused for arm64 without a native32 diagnostic"; exit 1; }; \
	done
	@if ./$(N32_BIN) $(N32_T)/expr.sa $(TESTS)/n32/bad.a64 sparc > $(TESTS)/n32/badt.err 2>&1; then \
	  echo "[FAIL] an unknown target was accepted"; exit 1; fi
	@grep -q 'native32: unknown target' $(TESTS)/n32/badt.err \
	  || { echo "[FAIL] an unknown target was refused without naming the problem"; exit 1; }
	@echo '[OK] arm64 refusals: all fifteen out-of-subset programs are refused on this target too, and an unknown target name is refused rather than silently defaulted'

native-test: test-native-arm64

# ---------------------------------------------------------------------------
# test-native-riscv64: FOURTH machine-code target -- RV64IM Linux ELF64
# (ELFCLASS64 / EM_RISCV = 243), emitted by tools/native32.sa in Sayanox.
#
# This emission gate pins RV64IM bytes, reviewed goldens, the ELF64/EM_RISCV
# container, the print-decimal prologue and exit epilogue, three-way
# data-segment identity and the refusal boundary. `test-sxisaexec` separately
# runs the exercised RV64 image subset; neither is a full RV64GC claim.
# ---------------------------------------------------------------------------
.PHONY: test-native-riscv64
test-native-riscv64: $(SEED_MIN_BIN) $(N32_BIN)
	@mkdir -p $(TESTS)/n32
	@for f in expr flow text; do \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.rv64 riscv64 \
	    || { echo "[FAIL] native32 riscv64 refused $$f.sa, which is inside its documented subset"; exit 1; }; \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.rv64b riscv64; \
	  cmp $(TESTS)/n32/$$f.rv64 $(TESTS)/n32/$$f.rv64b \
	    || { echo "[FAIL] the riscv64 encoder emitted different bytes for $$f.sa on a second run"; exit 1; }; \
	  cmp $(TESTS)/n32/$$f.rv64 $(N32_T)/golden/$$f.riscv64.elf \
	    || { echo "[FAIL] the riscv64 image for $$f.sa differs from the reviewed golden $(N32_T)/golden/$$f.riscv64.elf"; exit 1; }; \
	done
	@echo '[OK] riscv64: expr, flow and text are emitted deterministically and match reviewed goldens; test-sxisaexec executes the RV64IM ELF subset'
	@test "$$(od -An -tx1 -v -N 8 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 7f454c4602010100 \
	  || { echo "[FAIL] the riscv64 image is no longer ELFCLASS64"; exit 1; }
	@test "$$(od -An -tu2 -v -j 16 -N 2 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] the riscv64 image is no longer ET_EXEC"; exit 1; }
	@test "$$(od -An -tu2 -v -j 18 -N 2 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 243 \
	  || { echo "[FAIL] e_machine is no longer EM_RISCV (243)"; exit 1; }
	@test "$$(od -An -tu2 -v -j 54 -N 2 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 56 \
	  || { echo "[FAIL] e_phentsize is no longer the ELF64 value 56"; exit 1; }
	@test "$$(od -An -tu2 -v -j 56 -N 2 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 2 \
	  || { echo "[FAIL] the riscv64 image no longer has exactly two program headers"; exit 1; }
	@test "$$(od -An -tu8 -v -j 24 -N 8 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 4194600 \
	  || { echo "[FAIL] the riscv64 entry point moved (0x400000 + 176 header bytes + the 120-byte print-decimal routine)"; exit 1; }
	@test "$$(od -An -tu8 -v -j 80 -N 8 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 4194304 \
	  || { echo "[FAIL] the riscv64 text segment no longer loads at 0x400000"; exit 1; }
	@test "$$(od -An -tu8 -v -j 136 -N 8 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 4198400 \
	  || { echo "[FAIL] the riscv64 data segment no longer loads at 0x401000"; exit 1; }
	@test "$$(od -An -tx1 -v -j 176 -N 4 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 9b020500 \
	  || { echo "[FAIL] the riscv64 print routine no longer starts with addiw t0, a0, 0"; exit 1; }
	@sz=$$(od -An -tu8 -v -j 96 -N 8 $(TESTS)/n32/expr.rv64 | tr -d ' \n'); \
	 test "$$(od -An -tx1 -v -j $$((sz - 12)) -N 12 $(TESTS)/n32/expr.rv64 | tr -d ' \n')" = 130500009308d00573000000 \
	   || { echo "[FAIL] the riscv64 text segment no longer ends in addi a0,zero,0 / addi a7,zero,93 / ecall"; exit 1; }
	@echo '[OK] riscv64 container: ELFCLASS64 / ET_EXEC / EM_RISCV (243), two program headers, entry 0x400128, text at 0x400000 and data at 0x401000, exit via ecall with a7=93'
	@for f in expr flow text; do \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.i32 i386; \
	  ./$(N32_BIN) $(N32_T)/$$f.sa $(TESTS)/n32/$$f.a64 arm64; \
	  tail -c +4097 $(TESTS)/n32/$$f.i32 > $(TESTS)/n32/$$f.d32; \
	  tail -c +4097 $(TESTS)/n32/$$f.a64 > $(TESTS)/n32/$$f.d64; \
	  tail -c +4097 $(TESTS)/n32/$$f.rv64 > $(TESTS)/n32/$$f.drv; \
	  cmp $(TESTS)/n32/$$f.d32 $(TESTS)/n32/$$f.drv \
	    || { echo "[FAIL] i386 and riscv64 disagree on the data segment for $$f.sa"; exit 1; }; \
	  cmp $(TESTS)/n32/$$f.d64 $(TESTS)/n32/$$f.drv \
	    || { echo "[FAIL] arm64 and riscv64 disagree on the data segment for $$f.sa"; exit 1; }; \
	  if cmp -s $(TESTS)/n32/$$f.a64 $(TESTS)/n32/$$f.rv64; then \
	    echo "[FAIL] arm64 and riscv64 images are identical on $$f.sa"; exit 1; fi; \
	done
	@echo '[OK] one front end, three encoders: i386, arm64 and riscv64 lay out byte-identical data segments while emitting distinct machine code'
	@for f in $(N32_T)/refuse/*.sa; do \
	  if ./$(N32_BIN) $$f $(TESTS)/n32/bad.rv64 riscv64 > $(TESTS)/n32/badrv.err 2>&1; then \
	    echo "[FAIL] the riscv64 target accepted $$f, which is outside the subset"; exit 1; fi; \
	  grep -q 'native32: ' $(TESTS)/n32/badrv.err \
	    || { echo "[FAIL] $$f was refused for riscv64 without a native32 diagnostic"; exit 1; }; \
	done
	@echo '[OK] riscv64 refusals: all fifteen out-of-subset programs are refused cleanly on this target too'

native-test: test-native-riscv64


# ---------------------------------------------------------------------------
# test-sxmod: module namespacing, as a source-to-source pass in Sayanox.
#
# docs/MODULES.md says the bootstrap dialect has textual `use` splicing and
# no module identity -- one flat name table, no aliases, no qualified names.
# That is still true of the compiler. tools/sxmod.sa adds the capability at
# the layer where it can be built honestly: it rewrites a program written
# with `module NAME from "path"` into plain bootstrap Sayanox with every
# module declaration prefixed.
#
# The gate starts from the negative control, because without it the feature
# is only a renaming exercise: two modules that both declare `add` cannot be
# spliced into one program by ANY backend. Then it shows the same two modules
# composing cleanly through the pass, with identical stdout on seed-min,
# gen2 and native_aot.
.PHONY: test-sxmod
test-sxmod: $(SEED_MIN_BIN) $(GEN2) $(SXM_BIN)
	@mkdir -p $(TESTS)/sxm
	@# 1. the flat dialect cannot compose these two modules at all
	@if ./$(SEED_MIN_BIN) $(SXM_T)/collide_flat.sa > $(TESTS)/sxm/collide.c 2>$(TESTS)/sxm/collide.err; then \
	  echo "[FAIL] seed-min accepted two spliced modules that both declare add"; exit 1; fi
	@grep -q 'duplicate function name' $(TESTS)/sxm/collide.err \
	  || { echo "[FAIL] seed-min refused the flat splice for the wrong reason"; cat $(TESTS)/sxm/collide.err; exit 1; }
	@./$(GEN2) $(SXM_T)/collide_flat.sa $(TESTS)/sxm/collide_g2.c >/dev/null 2>&1 || true
	@if LC_ALL=C $(CC) -O2 -o $(TESTS)/sxm/collide_g2 $(TESTS)/sxm/collide_g2.c 2>$(TESTS)/sxm/collide_g2.err; then \
	  echo "[FAIL] the C gen2 emitted for the flat splice compiled, so there was no collision"; exit 1; fi
	@grep -q "'add'" $(TESTS)/sxm/collide_g2.err \
	  || { echo "[FAIL] cc rejected gen2's flat splice for an unrelated reason"; cat $(TESTS)/sxm/collide_g2.err; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(SXM_T)/collide_flat.sa $(TESTS)/sxm/collide_nat >/dev/null 2>$(TESTS)/sxm/collide_nat.err; then \
	    echo "[FAIL] native_aot accepted two spliced modules that both declare add"; exit 1; fi; \
	  grep -q 'declared twice' $(TESTS)/sxm/collide_nat.err \
	    || { echo "[FAIL] native_aot refused the flat splice for the wrong reason"; exit 1; }; \
	fi
	@echo '[OK] the flat dialect cannot compose two modules that both declare `add`: seed-min says duplicate function name, cc rejects gen2 C, native_aot says declared twice'
	@# 2. the same two modules through the pass, on three backends
	@./$(SXM_BIN) $(SXM_T)/app.sa $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] sxmod refused selfhost/sxmod_tests/app.sa"; exit 1; }
	@./$(SXM_BIN) $(SXM_T)/app.sa $(TESTS)/sxm/app2.sa
	@cmp $(TESTS)/sxm/app.sa $(TESTS)/sxm/app2.sa \
	  || { echo "[FAIL] the namespacing pass is not deterministic"; exit 1; }
	@./$(SEED_MIN_BIN) $(TESTS)/sxm/app.sa > $(TESTS)/sxm/app_ms.c
	@$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sxm/app_ms $(TESTS)/sxm/app_ms.c
	@./$(TESTS)/sxm/app_ms > $(TESTS)/sxm/app.want
	@cmp $(SXM_T)/app.want $(TESTS)/sxm/app.want \
	  || { echo "[FAIL] the namespaced program no longer prints the nine pinned lines"; exit 1; }
	@./$(GEN2) $(TESTS)/sxm/app.sa $(TESTS)/sxm/app_g2.c >/dev/null
	@$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sxm/app_g2 $(TESTS)/sxm/app_g2.c
	@./$(TESTS)/sxm/app_g2 > $(TESTS)/sxm/app.g2
	@cmp $(TESTS)/sxm/app.want $(TESTS)/sxm/app.g2 \
	  || { echo "[FAIL] gen2 disagrees with seed-min on the namespaced program"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/sxm/app.sa $(TESTS)/sxm/app_nat >/dev/null; \
	  ./$(TESTS)/sxm/app_nat > $(TESTS)/sxm/app.nat; \
	  cmp $(TESTS)/sxm/app.want $(TESTS)/sxm/app.nat \
	    || { echo "[FAIL] native_aot disagrees with seed-min on the namespaced program"; exit 1; }; \
	else echo "[SKIP] native_aot is not built; the seed-min/gen2 comparison still ran"; fi
	@echo '[OK] two modules that each declare `add` compose through sxmod and print the same nine lines under seed-min, gen2 and native_aot'
	@# 3. what the rewrite did and did not touch
	@grep -q 'make math__add(' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] the math module was not prefixed"; exit 1; }
	@grep -q 'make text__add(' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] the text module was not prefixed"; exit 1; }
	@grep -q 'show math__scaled(4, math__scale)' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] a qualified read of a module-level `hold` was not prefixed"; exit 1; }
	@grep -q 'hold math__base = math__add(40, 2)' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] a top-level initialiser calling the same module was not prefixed"; exit 1; }
	@grep -q 'hold once = math__scaled(v, k)' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] a module-internal call was not prefixed"; exit 1; }
	@grep -q '"add is a word in this string"' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] the rewrite changed the inside of a string literal"; exit 1; }
	@grep -q 'the word add appears in this comment' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] the rewrite changed the inside of a comment"; exit 1; }
	@grep -q '^show p.x$$' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] a struct field access was rewritten as if it were a module reference"; exit 1; }
	@grep -q 'hold mark = "!"' $(TESTS)/sxm/app.sa \
	  || { echo "[FAIL] a local hold was prefixed"; exit 1; }
	@if grep -q 'text__mark\|math__once\|math__v\|p__x' $(TESTS)/sxm/app.sa; then \
	  echo "[FAIL] a local, a parameter or a field was given a module prefix"; exit 1; fi
	@echo '[OK] the rewrite prefixes exactly the module-level names: internal references and initialisers follow, while locals, parameters, struct fields, comments and string literals are left byte for byte'
	@# 4. a member is not reachable without its module name
	@./$(SXM_BIN) $(SXM_T)/unqualified.sa $(TESTS)/sxm/unq.sa \
	  || { echo "[FAIL] sxmod refused the unqualified fixture; it should pass it through untouched"; exit 1; }
	@if ./$(SEED_MIN_BIN) $(TESTS)/sxm/unq.sa > $(TESTS)/sxm/unq.c 2>$(TESTS)/sxm/unq.err; then \
	  echo "[FAIL] a module member was reachable without its module name"; exit 1; fi
	@grep -q 'unknown function' $(TESTS)/sxm/unq.err \
	  || { echo "[FAIL] the unqualified call failed for an unrelated reason"; cat $(TESTS)/sxm/unq.err; exit 1; }
	@echo '[OK] a module member is not visible unqualified: `add(2, 3)` after the pass names nothing and the compiler says so'
	@# 5. every refusal, by name
	@for f in $(SXM_T)/refuse/*.sa; do \
	  if ./$(SXM_BIN) $$f $(TESTS)/sxm/bad.sa > $(TESTS)/sxm/bad.err 2>&1; then \
	    echo "[FAIL] sxmod accepted $$f"; exit 1; fi; \
	  grep -q 'sxmod: ' $(TESTS)/sxm/bad.err \
	    || { echo "[FAIL] $$f was refused without an sxmod diagnostic"; exit 1; }; \
	done
	@test "$$(ls $(SXM_T)/refuse/*.sa | wc -l)" = 16 \
	  || { echo "[FAIL] the refusal set changed size; update the gate and docs/MODULES.md"; exit 1; }
	@echo '[OK] sxmod refusals: unknown member, bare alias, duplicate alias, duplicate member, missing/unquoted path, no `from`, a late `module` line, an uppercase module name, an empty module, no module at all, `use` in a program or a module, a `module` inside a module, and a parameter or local that shadows a module name -- 16 refusals, each with a diagnostic and a non-zero exit'

native-test: test-sxmod


# ---------------------------------------------------------------------------
# test-trust-anchor: the C seed is ONE pinned, auditable file.
#
# docs/ALL_SAYANOX_PHASE.md "Phase E -- the seed" says the C seed has two
# honest end states -- a prebuilt checksummed binary, or a minimal C seed
# kept forever as a documented auditable exception -- and that neither was
# implemented. This gate implements the second one as a machine check.
#
# It does NOT claim the trust problem is solved. The seed compiled the
# compiler that compiled the auditor, so a hash pin is tamper evidence
# against drift, not immunity from a malicious seed (Thompson). Breaking that
# circle needs a second independent implementation to diverse-double-compile
# against, and this repository has none. What is claimed is bounded and
# checkable: the anchor is one named file of a pinned size and SHA-256, its
# external surface is four standard headers and no process, network or
# dynamic-loading call, its output on the real workload is deterministic, and
# the all-Sayanox claim still fails closed.
.PHONY: test-trust-anchor
test-trust-anchor: $(GEN2) $(SXA_BIN) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)/anchor
	@# 1. size and digest, computed by Sayanox (stdlib/crypto.sa), pinned
	@./$(SXA_BIN) $(SEED_MIN_C) > $(TESTS)/anchor/seed.audit \
	  || { echo "[FAIL] the auditor could not read the seed"; exit 1; }
	@cmp selfhost/seed/sxc_seed_min.audit $(TESTS)/anchor/seed.audit \
	  || { echo "[FAIL] the trust anchor changed: selfhost/seed/sxc_seed_min.c no longer matches its pinned size and SHA-256 in selfhost/seed/sxc_seed_min.audit. If the change is intended, review the C by hand, regenerate the pin with ./$(SXA_BIN) $(SEED_MIN_C), and say why in the commit"; exit 1; }
	@echo '[OK] trust anchor pinned: selfhost/seed/sxc_seed_min.c is 2176 lines / 100919 bytes, SHA-256 e4cc34b4...1cb9, recomputed here by Sayanox itself (stdlib/crypto.sa) and compared with the tracked pin'
	@# 2. the bootstrap compiles exactly this one tracked C file
	@grep -q '^	$$(CC) -O2 -o $$(SEED_MIN_BIN) $$(SEED_MIN_C)$$' Makefile \
	  || { echo "[FAIL] the seed build rule changed shape; re-audit what C the bootstrap compiles"; exit 1; }
	@test "$$(grep -c '\.c' $(TESTS)/anchor/seed.audit)" = 1 \
	  || { echo "[FAIL] the audit record names more than one C file"; exit 1; }
	@test "$$(git ls-files '*.c' '*.h')" = "selfhost/seed/sxc_seed_min.c" \
	  || { echo "[FAIL] tracked .c/.h files exist outside selfhost/seed/sxc_seed_min.c:"; git ls-files '*.c' '*.h'; exit 1; }
	@test -z "$$(find . -path './.git' -prune -o -type f -name '*.sh' -print)" \
	  || { echo "[FAIL] .sh files remain in the working tree:"; find . -path './.git' -prune -o -type f -name '*.sh' -print; exit 1; }
	@echo '[OK] one anchor: selfhost/seed/sxc_seed_min.c is the ONLY tracked .c/.h file in the entire repository, and no .sh scripts remain in the working tree'
	@# 3. the external surface of the anchor
	@test "$$(grep -c '^#include' $(SEED_MIN_C))" = 4 \
	  || { echo "[FAIL] the seed's #include set changed size"; grep '^#include' $(SEED_MIN_C); exit 1; }
	@for h in ctype.h stdio.h stdlib.h string.h; do \
	  grep -q "^#include <$$h>" $(SEED_MIN_C) \
	    || { echo "[FAIL] the seed no longer includes $$h, or includes it differently"; exit 1; }; \
	done
	@for bad in system fork execl execv execve dlopen dlsym socket connect setuid unlink rename chmod remove tmpnam getenv; do \
	  if grep -qw "$$bad" $(SEED_MIN_C); then \
	    echo "[FAIL] the trust anchor now references $$bad; its surface must stay: read a file, write a file, print"; exit 1; fi; \
	done
	@echo '[OK] anchor surface: four standard headers (ctype, stdio, stdlib, string), and not one reference to system, fork, exec*, dlopen, socket, setuid, unlink, rename, chmod, remove, tmpnam or getenv -- 2176 lines a reviewer can actually read'
	@# 3b. the one shell-out is in the RUNTIME TEXT the anchor emits, not in
	@# the anchor itself, and it is the documented http_get builtin. Pinning
	@# the count is what stops a second one appearing quietly.
	@test "$$(grep -cw popen $(SEED_MIN_C))" = 1 \
	  || { echo "[FAIL] the number of popen sites in the seed changed; there must be exactly one, inside the emitted sx_http runtime"; exit 1; }
	@test "$$(grep -cw curl $(SEED_MIN_C))" = 1 \
	  || { echo "[FAIL] the number of curl sites in the seed changed"; exit 1; }
	@grep -nw popen $(SEED_MIN_C) | grep -q 'sx_http' \
	  || { echo "[FAIL] the seed's popen is no longer the emitted sx_http runtime function"; exit 1; }
	@grep -nw popen $(SEED_MIN_C) | grep -q 'puts(' \
	  || { echo "[FAIL] the seed's popen is no longer inside emitted runtime text -- the compiler itself now shells out"; exit 1; }
	@echo '[OK] the anchor itself never shells out: the single popen/pclose/curl site is one line of RUNTIME text it emits (sx_http, behind the http_get builtin), so every compiled program carries exactly one shell-out and the compiler carries none'
	@# 4. the anchor is deterministic on the real workload
	@./$(SEED_MIN_BIN) selfhost/compiler_min.sa > $(TESTS)/anchor/c1.c
	@./$(SEED_MIN_BIN) selfhost/compiler_min.sa > $(TESTS)/anchor/c2.c
	@cmp $(TESTS)/anchor/c1.c $(TESTS)/anchor/c2.c \
	  || { echo "[FAIL] the seed is not deterministic on selfhost/compiler_min.sa"; exit 1; }
	@test "$$(wc -c < $(TESTS)/anchor/c1.c)" -gt 100000 \
	  || { echo "[FAIL] the seed produced an implausibly small compiler"; exit 1; }
	@echo '[OK] anchor behaviour: compiling the 20.1k-line compiler twice gives byte-identical C, so what the anchor is trusted for is reproducible'
	@# 5. the claim still fails closed
	@grep -q 'not all maintained logic is Sayanox yet; refusing an all-in-Sayanox claim' Makefile \
	  || { echo "[FAIL] the all-sayanox target no longer refuses the claim"; exit 1; }
	@grep -q 'Phase E decision (2026-10-23): option 2' docs/ALL_SAYANOX_PHASE.md \
	  || { echo "[FAIL] the recorded Phase E decision is gone from docs/ALL_SAYANOX_PHASE.md"; exit 1; }
	@echo '[OK] still failing closed: `make all-sayanox` refuses the all-in-Sayanox claim, and this gate pins the exception rather than removing it -- C is still the trust anchor, now a measured one'

native-test: test-trust-anchor


# ---------------------------------------------------------------------------
# test-native-sxencode: the instruction encoder is Sayanox.
#
# selfhost/native_aot.c writes every byte of the code segment through about
# fifty primitives: the mov/lea/arith/SSE2 helpers, emit_modrm and rexb, the
# label-and-fixup machinery, and the two raw stores the phase-4 runtime uses.
# `SX_ENCODE_LOG=<path>` records one line per call -- the primitive's name and
# the integer arguments it was handed -- and `e1`, the one function that appends
# a byte, records the byte as well. tools/sxencode.sa replays that stream and
# rebuilds code.bin, which is the same file SX_LINK_DUMP writes for
# tools/sxlink.sa: the container and the contents, each held to the C bytes by
# fixtures instead of by inspection.
#
# Three things make the comparison worth more than a diff:
#
#   1. It is exact. Every fixture's code.bin must be byte-identical, not
#      "equivalent" and not a prefix, including the runtime's hand-written
#      machine code, which arrives as raw byte records and is copied because
#      there is no encoding to reproduce.
#   2. It is checked twice. Each named record is followed by the bytes the C
#      encoder wrote for that same call, and the replay refuses to continue if
#      its own encoding disagrees with them. A wrong ModRM or a displacement
#      that should have been one byte therefore fails at the instruction, not
#      in a later cmp.
#   3. The recorder is inert. Each fixture is compiled twice, with and without
#      the log, and the two ELFs are cmp'd, so no byte can change when the seam
#      is on.
#
# The record vocabulary is pinned from both ends: the name list (`op_id`) and
# the encoding list (`apply`) must have the same length, and the fixture set
# must exercise every record, so a primitive cannot be added on one side only
# and a dropped one cannot pass unnoticed. 64-bit immediates travel as two
# 32-bit halves because a Sayanox number is a C double and is exact only below
# 2^53 -- the gate would see a rounded constant immediately.
#
# This is a step TOWARDS the native backend being Sayanox, not the backend:
# native_aot still drives its own encoder to produce the executables the gates
# run, and docs/ALL_SAYANOX_PHASE.md says so.
# ---------------------------------------------------------------------------
SXENCODE_BIN := tools/sxencode
SXENCODE_SA  := tools/sxencode.sa
SXENCODE_FIX := $(TESTS)/sxencode_hello.sa selfhost/native_ir_log_test.sa \
                selfhost/native_logic_arg_test.sa selfhost/native_strord_test.sa \
                selfhost/stdlib_growth_test.sa
SXENCODE_OPS := J_cc J_mp L_bind L_new addsd b bin_imm32 bin_imm8 bin_rr call_p \
                cvtsd2si cvtsi2sd cvttsd2si divsd erel32 erel32j fm7 inc_mem_r \
                incdec_r jcc_rel32 jmp5_slot jmp_rel32 lea_r12_data lea_rm \
                leave_ret mov_imm64 mov_imm8m movq_rx movq_xr movzx_al_to_rax \
                mulsd mv_m64 mv_r64m mv_rr mvz_rm patch_imm32 pop_r push_r \
                raw_patch32 sar_imm setcc shl_imm shr_imm stal_rdi stb_rdi \
                sub_rsp_slot subsd test_rr ucomisd xor_rr

tools/sxencode: $(SXENCODE_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXENCODE_SA) $@
	@echo "[OK] Sayanox instruction encoder built C-free from $(SXENCODE_SA)"

.PHONY: test-native-sxencode
test-native-sxencode: $(NATIVE_BIN) $(SXENCODE_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxencode
	@# ---- the two record tables are the same length ----
	@n=$$(grep -c 'when string_eq(name, "' $(SXENCODE_SA)); \
	 m=$$(grep -c '^  when id == [0-9]* { st = ' $(SXENCODE_SA)); \
	 if [ "$$n" != "$$m" ]; then \
	   echo "[FAIL] sxencode: $$n record names but $$m encodings -- op_id and apply disagree"; exit 1; fi; \
	 echo "  [ok] $$n records: the name list and the encoding list are the same length"
	@# ---- one fixture per shape that moves the encoder ----
	@# a bare program, the instruction-list fixture, a boolean-argument function
	@# (which is what emits jmp5_slot), a string-ordering loop and the stdlib
	@# growth fixture (which is the one that emits sar_imm and patch_imm32)
	@printf 'hold x = 40\nhold x = x + 2\nshow x\n' > $(TESTS)/sxencode_hello.sa
	@for fix in $(SXENCODE_FIX); do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxencode/$$name; \
	  mkdir -p $$d; \
	  ./$(NATIVE_BIN) $$fix $$d/off.elf; \
	  SX_ENCODE_LOG=$$d/enc.log SX_LINK_DUMP=$$d ./$(NATIVE_BIN) $$fix $$d/c.elf; \
	  cmp $$d/off.elf $$d/c.elf \
	    || { echo "[FAIL] sxencode: SX_ENCODE_LOG changed the emitted bytes for $$name"; exit 1; }; \
	  ./$(SXENCODE_BIN) $$d/enc.log $$d/code.bin $$d/sx.bin > $$d/report \
	    || { echo "[FAIL] sxencode: the replay refused $$name"; head -20 $$d/report; exit 1; }; \
	  cmp $$d/code.bin $$d/sx.bin \
	    || { echo "[FAIL] sxencode: the Sayanox-encoded code is not byte-identical for $$name"; exit 1; }; \
	  echo "  [ok] $$name: $$(wc -c < $$d/code.bin) code bytes, $$(tr '\n' ' ' < $$d/report | cut -d' ' -f2-3)"; \
	done
	@# ---- the fixture set exercises every record ----
	@got=$$(grep -h -v '^;' $(TESTS)/sxencode/*/enc.log | cut -d' ' -f1 | sort -u | tr '\n' ' '); \
	 want='$(SXENCODE_OPS) '; \
	 if [ "$$got" != "$$want" ]; then \
	   echo "[FAIL] sxencode: the fixtures do not exercise the pinned record set"; \
	   echo "--- want ---"; echo "$$want"; echo "--- got ---"; echo "$$got"; exit 1; fi; \
	 echo "  [ok] the fixture set exercises all $$(echo $$want | wc -w) records"
	@# ---- the failures are clear, not silently short ----
	@if ./$(SXENCODE_BIN) $(TESTS)/sxencode/nope.log $(TESTS)/sxencode/sxencode_hello/code.bin $(TESTS)/sxencode/bad.bin >/dev/null 2>&1; then \
	  echo "[FAIL] sxencode accepted a log path that does not exist"; exit 1; fi
	@./$(SXENCODE_BIN) $(TESTS)/sxencode/nope.log $(TESTS)/sxencode/sxencode_hello/code.bin $(TESTS)/sxencode/bad.bin 2>&1 >/dev/null | grep -q 'cannot read the encode log'
	@printf '1\n' > $(TESTS)/sxencode/short.bin
	@if ./$(SXENCODE_BIN) $(TESTS)/sxencode/sxencode_hello/enc.log $(TESTS)/sxencode/short.bin $(TESTS)/sxencode/bad.bin >/dev/null 2>&1; then \
	  echo "[FAIL] sxencode accepted a code.bin of the wrong length"; exit 1; fi
	@./$(SXENCODE_BIN) $(TESTS)/sxencode/sxencode_hello/enc.log $(TESTS)/sxencode/short.bin $(TESTS)/sxencode/bad.bin 2>&1 >/dev/null | grep -q 'different length'
	@printf 'bogus_record 1 2\n' > $(TESTS)/sxencode/bogus.log
	@if ./$(SXENCODE_BIN) $(TESTS)/sxencode/bogus.log $(TESTS)/sxencode/sxencode_hello/code.bin $(TESTS)/sxencode/bad.bin >/dev/null 2>&1; then \
	  echo "[FAIL] sxencode accepted a record it does not implement"; exit 1; fi
	@./$(SXENCODE_BIN) $(TESTS)/sxencode/bogus.log $(TESTS)/sxencode/sxencode_hello/code.bin $(TESTS)/sxencode/bad.bin 2>&1 >/dev/null | grep -q 'unknown record'
	@echo "[OK] sxencode: the encoder is Sayanox -- five fixtures replay to byte-identical code, every named record is checked against the bytes C wrote for the same call, the recorder changes no emitted byte, all record names are exercised, and a missing log, a wrong-length code.bin and an unknown record are clear errors"

# ---------------------------------------------------------------------------
# tools/sxdefs + test-native-sxdefs: PHASE 1 OF THE NATIVE FRONT END, IN
# SAYANOX (2026-10-23, Phase D step 5).
#
# tools/sxlink.sa took the ELF image writer out of C and tools/sxencode.sa
# took the instruction encoder; both are driven by a recorded stream, so they
# replay what the C FRONT END decided. tools/sxdefs.sa is the first piece
# that reads the program text instead: it is `expand_use()` and
# `collect_defs()` -- the `use` splice and the definition tables -- written in
# Sayanox and compared with C's.
#
# The seam is SX_DEFS_DUMP=<dir>: native_aot writes expand.sa (the expanded
# source) and defs.txt (the struct, generic-struct, function and global
# tables) between collect_defs() and infer(), and changes nothing else. The
# dump sits before infer() on purpose, so that the comparison tests ONE pass:
# every `kind=-1` in defs.txt is phase 1 saying "not my job".
#
# Three things are checked, because byte identity alone would only say the
# two implementations agree:
#   * both outputs are byte-identical on nine fixtures, including two with a
#     two-level `use` splice and the 1,159-line tools/sxencode.sa;
#   * the DIAGNOSTICS are identical for 34 refusals plus the real 20,106-line
#     compiler -- same text after the tool name, same exit status;
#   * the shape of the table is pinned by content, so a change on BOTH sides
#     still fails here with a reason.
#
# What is still C: kind inference, the emit tree, the runtime stubs and the
# collector. native_aot also still runs its own phase 1 to compile anything;
# sxdefs is proved equal to it, not wired in as the producer, exactly as
# sxlink and sxencode are.
SXDEFS_BIN := tools/sxdefs
SXDEFS_SA  := tools/sxdefs.sa
SXDEFS_FIX := selfhost/sxdefs_tests/program.sa selfhost/sxdefs_tests/quirks.sa \
              selfhost/native_strord_test.sa selfhost/stdlib_growth_test.sa \
              selfhost/stdlib_json_deep_test.sa selfhost/generic_struct_nested.sa \
              selfhost/full_language_expr.sa tools/sxencode.sa tools/native32.sa

tools/sxdefs: $(SXDEFS_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXDEFS_SA) $@
	@echo "[OK] Sayanox phase-1 front end built C-free from $(SXDEFS_SA)"

.PHONY: test-native-sxdefs
test-native-sxdefs: $(NATIVE_BIN) $(SXDEFS_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxdefs
	@# ---- the expansion and the tables agree, byte for byte ----
	@# Some fixtures are phase-1 clean but use builtins the native backend
	@# refuses later (tools/sxencode.sa calls exit()): the dump is written
	@# between collect_defs and infer, so phase 1 is still comparable. The
	@# inertness check then compares the whole run -- same stdout, same
	@# stderr, and the same image whenever one was produced.
	@for fix in $(SXDEFS_FIX); do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxdefs/$$name; \
	  mkdir -p $$d; \
	  ./$(NATIVE_BIN) $$fix $$d/off.elf > $$d/off.log 2>&1 || true; \
	  SX_DEFS_DUMP=$$d ./$(NATIVE_BIN) $$fix $$d/c.elf > $$d/c.log 2>&1 || true; \
	  test -f $$d/defs.txt \
	    || { echo "[FAIL] sxdefs: no SX_DEFS_DUMP was written for $$name"; exit 1; }; \
	  cmp $$d/off.log $$d/c.log \
	    || { echo "[FAIL] sxdefs: SX_DEFS_DUMP changed what native_aot reported for $$name"; exit 1; }; \
	  if [ -f $$d/off.elf ]; then cmp $$d/off.elf $$d/c.elf \
	    || { echo "[FAIL] sxdefs: SX_DEFS_DUMP changed the emitted bytes for $$name"; exit 1; }; fi; \
	  ./$(SXDEFS_BIN) $$fix expand $$d/sx.expand \
	    || { echo "[FAIL] sxdefs: the Sayanox expansion refused $$name"; exit 1; }; \
	  ./$(SXDEFS_BIN) $$fix defs $$d/sx.defs \
	    || { echo "[FAIL] sxdefs: the Sayanox collection refused $$name"; exit 1; }; \
	  cmp $$d/expand.sa $$d/sx.expand \
	    || { echo "[FAIL] sxdefs: the Sayanox use-expansion is not byte-identical for $$name"; exit 1; }; \
	  cmp $$d/defs.txt $$d/sx.defs \
	    || { echo "[FAIL] sxdefs: the Sayanox definition tables are not byte-identical for $$name"; exit 1; }; \
	  echo "  [ok] $$name: $$(wc -c < $$d/expand.sa) expanded bytes, $$(grep -c '' $$d/defs.txt) table lines"; \
	done
	@echo "[OK] sxdefs: nine fixtures expand and collect byte-identically to native_aot's phase 1, and the dump changes no emitted byte"
	@# ---- the fixture is a real program, not a parse exercise ----
	@chmod +x $(TESTS)/sxdefs/program/c.elf
	@$(TESTS)/sxdefs/program/c.elf > $(TESTS)/sxdefs/program.out
	@cmp selfhost/sxdefs_tests/program.want $(TESTS)/sxdefs/program.out \
	  || { echo "[FAIL] sxdefs: the fixture no longer prints what it printed"; exit 1; }
	@# ---- the contract, pinned by content ----
	@# the splice fed the collection: shout() comes from the second level
	@# (mods/text.sa, spliced into mods/geom.sa, spliced into program.sa)
	@grep -q -F 'fn 0 shout nparam=1 gen=0 ntp=0 rk=1 rtp=-1' $(TESTS)/sxdefs/program/defs.txt \
	  || { echo "[FAIL] sxdefs: the two-level use splice no longer reaches the function table"; exit 1; }
	@grep -q -F 'struct 0 Point nf=2' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F 'gstruct 0 Box np=1 nf=1' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F 'gstruct 1 Pair np=2 nf=2' $(TESTS)/sxdefs/program/defs.txt
	@# a generic function: every parameter carries a type-parameter index
	@grep -q -F 'fn 5 pick nparam=2 gen=1 ntp=2 rk=0 rtp=0' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F '  param 1 b k=0 tp=1' $(TESTS)/sxdefs/program/defs.txt
	@# annotations: str, list and two different struct identities
	@grep -q -F 'glob 1 title kind=1 sid=-1' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F 'glob 2 here kind=3 sid=0' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F 'glob 3 sizes kind=2 sid=-1' $(TESTS)/sxdefs/program/defs.txt
	@grep -q -F 'glob 4 s kind=3 sid=1' $(TESTS)/sxdefs/program/defs.txt
	@# phase 1 leaves the field kinds to infer(): every field is kind=-1
	@if grep '^  field ' $(TESTS)/sxdefs/program/defs.txt | grep -v -q 'kind=-1 sid=-1'; then \
	  echo "[FAIL] sxdefs: a field kind is set before infer() ran -- the dump point moved"; exit 1; fi
	@# a hold inside a top-level block is NOT a global: collect_defs skips the
	@# whole block, and `hold count = ...` twice is still one global
	@test "$$(grep -c '^glob ' $(TESTS)/sxdefs/program/defs.txt)" = 6 \
	  || { echo "[FAIL] sxdefs: the global table is no longer the six top-level holds"; exit 1; }
	@if grep -q 'inner' $(TESTS)/sxdefs/program/defs.txt; then \
	  echo "[FAIL] sxdefs: a hold inside a top-level block reached the global table"; exit 1; fi
	@# the expansion: the use line is gone, the module text is in, and the
	@# word `use` inside a comment is still a comment
	@if grep -q '^use "mods/geom.sa"' $(TESTS)/sxdefs/program/expand.sa; then \
	  echo "[FAIL] sxdefs: the use line survived the expansion"; exit 1; fi
	@grep -q -F 'make shout(s: str) -> str' $(TESTS)/sxdefs/program/expand.sa \
	  || { echo "[FAIL] sxdefs: the second-level module text is missing from the expansion"; exit 1; }
	@grep -q -F 'use "not-a-real-file.sa"' $(TESTS)/sxdefs/program/expand.sa \
	  || { echo "[FAIL] sxdefs: a use inside a comment was treated as a use"; exit 1; }
	@echo "[OK] sxdefs: the table is pinned by content -- two-level splice, generic templates, a generic signature, str/list/struct annotations, every field kind still -1, six globals and no block-local name, and a use inside a comment stays a comment"
	@# ---- refusals: same text, same status ----
	@test "$$(ls selfhost/sxdefs_tests/refuse/*.sa | wc -l)" = 34 \
	  || { echo "[FAIL] sxdefs: the refusal set is no longer 34 programs"; exit 1; }
	@mkdir -p $(TESTS)/sxdefs/refuse
	@for fix in selfhost/sxdefs_tests/refuse/*.sa; do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxdefs/refuse; \
	  ./$(NATIVE_BIN) $$fix $$d/$$name.elf 2> $$d/$$name.c.err; crc=$$?; \
	  ./$(SXDEFS_BIN) $$fix defs $$d/$$name.defs 2> $$d/$$name.s.err; src=$$?; \
	  [ $$crc = 1 ] || { echo "[FAIL] sxdefs: native_aot did not refuse $$name (exit $$crc)"; exit 1; }; \
	  [ $$src = 1 ] || { echo "[FAIL] sxdefs: the Sayanox phase 1 did not refuse $$name (exit $$src)"; exit 1; }; \
	  test -s $$d/$$name.c.err || { echo "[FAIL] sxdefs: native_aot refused $$name with no message"; exit 1; }; \
	  cut -d' ' -f2- < $$d/$$name.c.err > $$d/$$name.c.msg; \
	  cut -d' ' -f2- < $$d/$$name.s.err > $$d/$$name.s.msg; \
	  cmp -s $$d/$$name.c.msg $$d/$$name.s.msg || { \
	    echo "[FAIL] sxdefs: different diagnostic for $$name"; \
	    echo "  native_aot: $$(cat $$d/$$name.c.msg)"; \
	    echo "  sxdefs    : $$(cat $$d/$$name.s.msg)"; exit 1; }; \
	done
	@# the 34 are 34 DIFFERENT messages' worth of coverage, not one repeated
	@test "$$(cat $(TESTS)/sxdefs/refuse/*.c.msg | sort -u | wc -l)" -ge 24 \
	  || { echo "[FAIL] sxdefs: the refusal set collapsed onto a handful of messages"; exit 1; }
	@echo "[OK] sxdefs: 34 out-of-subset programs are refused by both phase 1 implementations with the same text and the same exit status ($$(cat $(TESTS)/sxdefs/refuse/*.c.msg | sort -u | wc -l) distinct messages)"
	@# ---- the real compiler: 20,106 lines, refused identically ----
	@./$(NATIVE_BIN) $(MIN_SA) $(TESTS)/sxdefs/min.elf 2> $(TESTS)/sxdefs/min.c.err; crc=$$?; \
	 ./$(SXDEFS_BIN) $(MIN_SA) defs $(TESTS)/sxdefs/min.defs 2> $(TESTS)/sxdefs/min.s.err; src=$$?; \
	 [ $$crc = 1 ] && [ $$src = 1 ] \
	   || { echo "[FAIL] sxdefs: the compiler is not refused by both (exit $$crc / $$src)"; exit 1; }
	@cut -d' ' -f2- < $(TESTS)/sxdefs/min.c.err > $(TESTS)/sxdefs/min.c.msg
	@cut -d' ' -f2- < $(TESTS)/sxdefs/min.s.err > $(TESTS)/sxdefs/min.s.msg
	@cmp $(TESTS)/sxdefs/min.c.msg $(TESTS)/sxdefs/min.s.msg \
	  || { echo "[FAIL] sxdefs: the compiler is refused with different words"; exit 1; }
	@grep -q 'at most 6 params' $(TESTS)/sxdefs/min.c.msg \
	  || { echo "[FAIL] sxdefs: the compiler now fails phase 1 for a different reason -- re-read the claim"; exit 1; }
	@echo "[OK] sxdefs: the 20,106-line compiler itself walks both phase 1 implementations to the same refusal ($$(cat $(TESTS)/sxdefs/min.c.msg))"
	@# ---- the tool's own failures are clear ----
	@if ./$(SXDEFS_BIN) selfhost/sxdefs_tests/program.sa tables $(TESTS)/sxdefs/bad.out >/dev/null 2>&1; then \
	  echo "[FAIL] sxdefs accepted a mode it does not implement"; exit 1; fi
	@./$(SXDEFS_BIN) selfhost/sxdefs_tests/program.sa tables $(TESTS)/sxdefs/bad.out 2>&1 >/dev/null | grep -q "unknown mode 'tables'"
	@if ./$(SXDEFS_BIN) selfhost/sxdefs_tests/nope.sa defs $(TESTS)/sxdefs/bad.out >/dev/null 2>&1; then \
	  echo "[FAIL] sxdefs accepted an input file that does not exist"; exit 1; fi
	@if ./$(SXDEFS_BIN) selfhost/sxdefs_tests/program.sa defs >/dev/null 2>&1; then \
	  echo "[FAIL] sxdefs accepted a command line with no output path"; exit 1; fi
	@echo "[OK] sxdefs: an unknown mode, a missing input and a missing output path are clear errors"

native-test: test-native-sxdefs

# ---------------------------------------------------------------------------
# tools/sxinfer + test-native-sxinfer: PHASE 2 OF THE NATIVE FRONT END, IN
# SAYANOX (Phase D step 6).
#
# tools/sxdefs.sa stopped before infer(): every field kind was -1, every
# unannotated global kind was -1, and no generic template had been
# instantiated. tools/sxinfer.sa ports phase 2 -- pk_*, the 16-round fixpoint,
# gs_instantiate() (including nested Box<Box<num>> and Pair<Box<str>, list>),
# pick_instance() generic function monomorphisation, dry gen_cond() over
# and/or/not, and the pk_soft=0 validation pass -- with ZERO C changes to
# selfhost/native_aot.c.
#
# Checked four ways:
#   * its phase-1 defs slice is byte-identical to SX_DEFS_DUMP on 12 fixtures;
#   * its binary heap-root table (OFF_ROOTS) is byte-identical to
#     SX_LINK_DUMP's data.bin[144..] on all 12 fixtures;
#   * its resolved infer.txt pins three-level concrete chains, nested generic
#     struct specialisations and generic function monomorphisations;
#   * 39 phase-1-clean, phase-2-invalid fixtures (39 distinct messages) are
#     accepted by sxdefs and refused by both native_aot and sxinfer with exit 1
#     and byte-identical diagnostic text.
# ---------------------------------------------------------------------------
SXINFER_BIN := tools/sxinfer
SXINFER_SA  := tools/sxinfer.sa
SXINFER_FIX := selfhost/sxinfer_tests/program.sa selfhost/sxdefs_tests/program.sa \
               selfhost/sxdefs_tests/quirks.sa selfhost/generic_struct_concrete.sa \
               selfhost/generic_struct_box.sa selfhost/generic_struct_nested.sa \
               selfhost/full_language_expr.sa selfhost/native_generics_test.sa \
               selfhost/native_strord_test.sa selfhost/stdlib_growth_test.sa \
               selfhost/stdlib_json_deep_test.sa selfhost/stdlib_crypto_test.sa

tools/sxinfer: $(SXINFER_SA) tools/sxinfer_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXINFER_SA) $@
	@echo "[OK] Sayanox phase-2 kind inference built C-free from $(SXINFER_SA)"

.PHONY: test-native-sxinfer
test-native-sxinfer: $(NATIVE_BIN) $(SXDEFS_BIN) $(SXINFER_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxinfer
	@for fix in $(SXINFER_FIX); do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  pdir=$${fix%/*}; pdir=$${pdir##*/}; tag=$${pdir}_$${name}; \
	  d=$(TESTS)/sxinfer/$$tag; \
	  mkdir -p $$d; \
	  SX_DEFS_DUMP=$$d SX_LINK_DUMP=$$d ./$(NATIVE_BIN) $$fix $$d/c.elf > $$d/c.log 2>&1 \
	    || { echo "[FAIL] sxinfer: native_aot refused $$fix"; cat $$d/c.log; exit 1; }; \
	  ./$(SXINFER_BIN) $$fix defs $$d/sx.defs \
	    || { echo "[FAIL] sxinfer: defs mode refused $$fix"; exit 1; }; \
	  cmp $$d/defs.txt $$d/sx.defs \
	    || { echo "[FAIL] sxinfer: phase-1 defs mismatch on $$fix"; exit 1; }; \
	  ./$(SXINFER_BIN) $$fix roots $$d/sx.roots \
	    || { echo "[FAIL] sxinfer: roots mode refused $$fix"; exit 1; }; \
	  rsz=$$(wc -c < $$d/sx.roots); \
	  dd if=$$d/data.bin bs=1 skip=144 count=$$rsz of=$$d/c.roots 2>/dev/null; \
	  cmp $$d/c.roots $$d/sx.roots \
	    || { echo "[FAIL] sxinfer: binary OFF_ROOTS table disagrees with native_aot data.bin on $$fix"; exit 1; }; \
	  ./$(SXINFER_BIN) $$fix infer $$d/sx.infer \
	    || { echo "[FAIL] sxinfer: infer mode refused $$fix"; exit 1; }; \
	  echo "  [ok] $$tag: $$rsz root-table bytes exact, $$(wc -l < $$d/sx.infer) infer lines"; \
	done
	@chmod +x $(TESTS)/sxinfer/sxinfer_tests_program/c.elf
	@$(TESTS)/sxinfer/sxinfer_tests_program/c.elf > $(TESTS)/sxinfer/program.out
	@cmp selfhost/sxinfer_tests/program.want $(TESTS)/sxinfer/program.out \
	  || { echo "[FAIL] sxinfer: fixture program output drifted"; exit 1; }
	@# ---- pin the resolved phase-2 contract by content ----
	@grep -q -F 'struct 1 Rect nf=2 gskn=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F '  field 0 o kind=3 sid=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'struct 2 Scene nf=2 gskn=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F '  field 0 r kind=3 sid=1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'struct 4 Box__Box__n nf=1 gskn=1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F '  targ 0 kind=3 sid=3' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'struct 6 Pair__Box__s_l nf=2 gskn=2' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'fn 2 id nparam=1 gen=0 rk=1 inst_of=0 queued=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'fn 3 id nparam=1 gen=0 rk=2 inst_of=0 queued=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'fn 4 first nparam=2 gen=0 rk=1 inst_of=1 queued=0' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'glob 1 inner_x kind=0 sid=-1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'glob 6 g_lst kind=2 sid=-1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@grep -q -F 'glob 7 g_mix kind=1 sid=-1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer
	@if grep 'kind=-1' $(TESTS)/sxinfer/sxinfer_tests_program/sx.infer >/dev/null; then \
	  echo "[FAIL] sxinfer: an unresolved kind=-1 survived phase 2"; exit 1; fi
	@echo "[OK] sxinfer: 12 fixtures match native_aot on phase-1 defs and binary OFF_ROOTS; nested generic structs, 3-level field chains and generic function monomorphisations are pinned"
	@# ---- 39 phase-2 refusals: accepted by phase 1, refused identically in phase 2 ----
	@test "$$(ls selfhost/sxinfer_tests/refuse/*.sa | wc -l)" = 39 \
	  || { echo "[FAIL] sxinfer: refusal fixture count is no longer 39"; exit 1; }
	@mkdir -p $(TESTS)/sxinfer/refuse
	@for fix in selfhost/sxinfer_tests/refuse/*.sa; do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxinfer/refuse; \
	  ./$(SXDEFS_BIN) $$fix defs $$d/$$name.p1 \
	    || { echo "[FAIL] sxinfer: $$name failed in phase 1 instead of phase 2"; exit 1; }; \
	  ./$(NATIVE_BIN) $$fix $$d/$$name.elf 2> $$d/$$name.c.err; crc=$$?; \
	  ./$(SXINFER_BIN) $$fix infer $$d/$$name.inf 2> $$d/$$name.s.err; src=$$?; \
	  [ $$crc = 1 ] || { echo "[FAIL] sxinfer: native_aot did not refuse $$name (exit $$crc)"; exit 1; }; \
	  [ $$src = 1 ] || { echo "[FAIL] sxinfer: Sayanox phase 2 did not refuse $$name (exit $$src)"; exit 1; }; \
	  cut -d' ' -f2- < $$d/$$name.c.err > $$d/$$name.c.msg; \
	  cut -d' ' -f2- < $$d/$$name.s.err > $$d/$$name.s.msg; \
	  cmp -s $$d/$$name.c.msg $$d/$$name.s.msg || { \
	    echo "[FAIL] sxinfer: different diagnostic for $$name"; \
	    echo "  native_aot: $$(cat $$d/$$name.c.msg)"; \
	    echo "  sxinfer   : $$(cat $$d/$$name.s.msg)"; exit 1; }; \
	done
	@test "$$(cat $(TESTS)/sxinfer/refuse/*.c.msg | sort -u | wc -l)" = 39 \
	  || { echo "[FAIL] sxinfer: refusal messages are no longer 39 distinct diagnostics"; exit 1; }
	@if ./$(SXINFER_BIN) selfhost/sxinfer_tests/program.sa bogus $(TESTS)/sxinfer/bad.out >/dev/null 2>&1; then \
	  echo "[FAIL] sxinfer accepted an unknown mode"; exit 1; fi
	@if ./$(SXINFER_BIN) selfhost/sxinfer_tests/nope.sa infer $(TESTS)/sxinfer/bad.out >/dev/null 2>&1; then \
	  echo "[FAIL] sxinfer accepted a missing file"; exit 1; fi
	@echo "[OK] sxinfer: 39 phase-1-clean programs are refused in phase 2 with 39 distinct byte-identical diagnostics"

native-test: test-native-sxinfer

# ---------------------------------------------------------------------------
# tools/sxruntime + tools/sxgc: PHASE D STEPS 8 & 9 -- THE 856-LINE x86-64
# RUNTIME BUILTINS AND THE 339-LINE COLLECTOR, IN SAYANOX.
#
# Built on tools/sxenc_lib.sa (no C added to selfhost/native_aot.c):
#   * tools/sxruntime.sa emits all 24 phase-4 runtime routines (3,521 bytes:
#     r_malloc, r_strlen, r_cmpstr, r_strord, r_concat, r_n2str, r_shownum,
#     r_putstr, r_wcstr, r_itono, r_itowrite, r_showlist, r_mlist, r_lget,
#     r_llen, r_lpush, r_sget, r_chr, r_readfile, r_writefile, r_arg, r_argc,
#     r_nfmt IEEE-754 %g formatter, r_die);
#   * tools/sxgc.sa emits all 6 native mark & sweep collector routines (1,209
#     bytes: r_findblock, r_mark, r_gc, r_gccheck, r_gc_live, r_gc_runs).
#
# Chaining `sxruntime -> sxgc -> sxlink` replaces all 4,730 bytes of machine-
# code runtime and collector plus their patch.bin relocations and links the
# final x86-64 ELF in Sayanox, byte-identical to native_aot.
# ---------------------------------------------------------------------------
SXRUNTIME_BIN := tools/sxruntime
SXRUNTIME_SA  := tools/sxruntime.sa
SXGC_BIN      := tools/sxgc
SXGC_SA       := tools/sxgc.sa
SXEMIT_BIN    := tools/sxemit
SXEMIT_SA     := tools/sxemit.sa
SXRTGC_FIX    := selfhost/sxinfer_tests/program.sa selfhost/native_strord_test.sa \
                 selfhost/stdlib_growth_test.sa selfhost/stdlib_crypto_test.sa

tools/sxemit: $(SXEMIT_SA) $(NATIVE_LIBS) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXEMIT_SA) $@
	@echo "[OK] Sayanox phase-3/full native emitter built C-free from $(SXEMIT_SA)"

tools/sxruntime: $(SXRUNTIME_SA) tools/sxruntime_lib.sa tools/sxenc_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXRUNTIME_SA) $@
	@echo "[OK] Sayanox x86-64 runtime emitter built C-free from $(SXRUNTIME_SA)"

tools/sxgc: $(SXGC_SA) tools/sxgc_lib.sa tools/sxenc_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXGC_SA) $@
	@echo "[OK] Sayanox x86-64 collector emitter built C-free from $(SXGC_SA)"

.PHONY: test-native-sxruntime
test-native-sxruntime: $(NATIVE_BIN) $(SXRUNTIME_BIN) $(SXLINK_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxruntime
	@for fix in $(SXRTGC_FIX); do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxruntime/$$name; \
	  mkdir -p $$d/in $$d/out; \
	  ./$(NATIVE_BIN) $$fix $$d/off.elf >/dev/null; \
	  SX_EMIT_LOG=$$d/emit.log SX_LINK_DUMP=$$d/in ./$(NATIVE_BIN) $$fix $$d/c.elf >/dev/null; \
	  cmp $$d/off.elf $$d/c.elf || { echo "[FAIL] sxruntime: dump changed emitted bytes on $$name"; exit 1; }; \
	  ./$(SXRUNTIME_BIN) $$d/emit.log $$d/in $$d/out >/dev/null \
	    || { echo "[FAIL] sxruntime disagreed on $$name"; exit 1; }; \
	  cmp $$d/in/code.bin $$d/out/code.bin || { echo "[FAIL] sxruntime: spliced code.bin differs on $$name"; exit 1; }; \
	  cmp $$d/in/patch.bin $$d/out/patch.bin || { echo "[FAIL] sxruntime: spliced patch.bin differs on $$name"; exit 1; }; \
	  ./$(SXLINK_BIN) $$d/c.elf $$d/out $$d/sx.elf >/dev/null; \
	  chmod +x $$d/sx.elf; \
	  cmp $$d/c.elf $$d/sx.elf || { echo "[FAIL] sxruntime: Sayanox-linked ELF differs on $$name"; exit 1; }; \
	  $$d/c.elf > $$d/c.out; $$d/sx.elf > $$d/sx.out; \
	  cmp $$d/c.out $$d/sx.out || { echo "[FAIL] sxruntime: stdout differs on $$name"; exit 1; }; \
	  echo "  [ok] $$name: 3521 runtime bytes + patches byte-identical and runnable"; \
	done
	@# tamper control: flipping runtime bytes must be caught at the exact offset
	@mkdir -p $(TESTS)/sxruntime/tamper/in
	@cp $(TESTS)/sxruntime/program/in/* $(TESTS)/sxruntime/tamper/in/
	@csz=$$(wc -c < $(TESTS)/sxruntime/tamper/in/code.bin); \
	  printf '\252\125' | dd of=$(TESTS)/sxruntime/tamper/in/code.bin bs=1 seek=$$((csz - 2000)) count=2 conv=notrunc 2>/dev/null
	@if ./$(SXRUNTIME_BIN) $(TESTS)/sxruntime/program/emit.log $(TESTS)/sxruntime/tamper/in $(TESTS)/sxruntime/tamper/out >/dev/null 2>&1; then \
	  echo "[FAIL] sxruntime accepted a tampered runtime byte"; exit 1; fi
	@./$(SXRUNTIME_BIN) $(TESTS)/sxruntime/program/emit.log $(TESTS)/sxruntime/tamper/in $(TESTS)/sxruntime/tamper/out 2>&1 >/dev/null | grep -q 'byte mismatch at runtime'
	@echo "[OK] sxruntime: all 24 x86-64 runtime routines (3,521 bytes, incl. IEEE-754 %g formatter) match native_aot byte-for-byte, link via sxlink and execute identically"

.PHONY: test-native-sxgc
test-native-sxgc: $(NATIVE_BIN) $(SXRUNTIME_BIN) $(SXGC_BIN) $(SXLINK_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/sxgc
	@printf 'hold i = 0\nwhile i < 200000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow i\nshow gc_runs()\n' > $(TESTS)/sxgc_oom.sa
	@printf 'struct Box {\n  n,\n  s\n}\nhold b = Box { 1, "hello-world" }\nhold a0 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\nhold xs = []\nhold i = 0\nwhile i < 30000 {\n  hold junk = concat("zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", "yyyyyyyyyyyyyyyyyyyyyyyyyy")\n  push(xs, i)\n  hold i = i + 1\n}\nshow len(a0)\nshow b.s\nshow len(xs)\nshow xs[29999]\nshow gc() >= 0\nshow gc_live() > 0\n' > $(TESTS)/sxgc_keep.sa
	@for fix in $(TESTS)/sxgc_oom.sa $(TESTS)/sxgc_keep.sa selfhost/sxinfer_tests/program.sa; do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxgc/$$name; \
	  mkdir -p $$d/in $$d/rt $$d/rt_gc; \
	  SX_EMIT_LOG=$$d/emit.log SX_LINK_DUMP=$$d/in ./$(NATIVE_BIN) $$fix $$d/c.elf >/dev/null; \
	  ./$(SXRUNTIME_BIN) $$d/emit.log $$d/in $$d/rt >/dev/null; \
	  ./$(SXGC_BIN) $$d/emit.log $$d/rt $$d/rt_gc >/dev/null; \
	  cmp $$d/in/code.bin $$d/rt_gc/code.bin || { echo "[FAIL] sxgc: spliced code.bin differs on $$name"; exit 1; }; \
	  cmp $$d/in/patch.bin $$d/rt_gc/patch.bin || { echo "[FAIL] sxgc: spliced patch.bin differs on $$name"; exit 1; }; \
	  ./$(SXLINK_BIN) $$d/c.elf $$d/rt_gc $$d/sx.elf >/dev/null; \
	  chmod +x $$d/sx.elf; \
	  cmp $$d/c.elf $$d/sx.elf || { echo "[FAIL] sxgc: chained sxruntime+sxgc+sxlink ELF differs on $$name"; exit 1; }; \
	  echo "  [ok] $$name: 4730 runtime+collector bytes emitted and linked in Sayanox, byte-identical to C"; \
	done
	@# execute the Sayanox-emitted collector under the 4 MiB address-space cap
	@__o=$$(sh -c 'ulimit -v 4096; ./$(TESTS)/sxgc/sxgc_oom/sx.elf') || { \
	  echo "[FAIL] Sayanox-emitted collector died under a 4 MiB cap"; exit 1; }; \
	  printf '%s\n' "$$__o" | { \
	    IFS= read -r __i; IFS= read -r __r; \
	    [ "$$__i" = "200000" ] && [ "$$__r" -ge 1 ] 2>/dev/null \
	      || { echo "[FAIL] Sayanox-emitted collector bad output: $$__o"; exit 1; }; }
	$(call assert-out,./$(TESTS)/sxgc/sxgc_keep/sx.elf,48\nhello-world\n30000\n29999\n1\n1)
	@# tamper control on the collector region
	@mkdir -p $(TESTS)/sxgc/tamper/in
	@cp $(TESTS)/sxgc/sxgc_oom/in/* $(TESTS)/sxgc/tamper/in/
	@csz=$$(wc -c < $(TESTS)/sxgc/tamper/in/code.bin); \
	  printf '\377' | dd of=$(TESTS)/sxgc/tamper/in/code.bin bs=1 seek=$$((csz - 20)) count=1 conv=notrunc 2>/dev/null
	@if ./$(SXGC_BIN) $(TESTS)/sxgc/sxgc_oom/emit.log $(TESTS)/sxgc/tamper/in $(TESTS)/sxgc/tamper/out >/dev/null 2>&1; then \
	  echo "[FAIL] sxgc accepted a tampered collector byte"; exit 1; fi
	@./$(SXGC_BIN) $(TESTS)/sxgc/sxgc_oom/emit.log $(TESTS)/sxgc/tamper/in $(TESTS)/sxgc/tamper/out 2>&1 >/dev/null | grep -q 'byte mismatch at collector'
	@echo "[OK] sxgc: all 6 x86-64 collector routines (1,209 bytes) + sxruntime (3,521 bytes) + sxlink produce byte-identical ELFs and reclaim 200k allocations inside 4 MiB"

.PHONY: test-native-sxemit
test-native-sxemit: $(NATIVE_BIN) $(SXEMIT_BIN) $(SXENCODE_BIN) $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)/sxemit
	@printf 'hold b1 = 0.1\nhold b2 = 0.2\nhold b4 = 3.141592653589793\nhold t0 = 9007199254740992\nhold t1 = 9007199254740993\nhold t2 = 9007199254740994\nhold t3 = 9007199254740995\nhold c2 = 999999999999999934463\nhold c3 = 999999999999999934465\nshow b1 + b2\nshow b4\nshow t1 - t0\nshow t3 - t2\nwhen c3 > c2 {\n  show 1\n}\n' > $(TESTS)/sxemit/ieee_edge.sa
	@for fix in selfhost/sxinfer_tests/program.sa selfhost/native_strord_test.sa selfhost/native_cond_test.sa selfhost/stdlib_crypto_test.sa $(TESTS)/sxemit/ieee_edge.sa; do \
	  name=$${fix##*/}; name=$${name%.sa}; \
	  d=$(TESTS)/sxemit/$$name; \
	  mkdir -p $$d/na_ld $$d/sx_ld $$d/na_dd $$d/sx_dd; \
	  SX_LINK_DUMP=$$d/na_ld SX_DEFS_DUMP=$$d/na_dd SX_EMIT_LOG=$$d/na.ilog SX_ENCODE_LOG=$$d/na.elog \
	    ./$(NATIVE_BIN) $$fix $$d/na.elf >/dev/null; \
	  SX_LINK_DUMP=$$d/sx_ld SX_DEFS_DUMP=$$d/sx_dd SX_EMIT_LOG=$$d/sx.ilog SX_ENCODE_LOG=$$d/sx.elog \
	    ./$(SXEMIT_BIN) $$fix $$d/sx.elf >/dev/null; \
	  cmp $$d/na.elf $$d/sx.elf || { echo "[FAIL] sxemit: ELF differs on $$name"; exit 1; }; \
	  cmp $$d/na_ld/code.bin $$d/sx_ld/code.bin || { echo "[FAIL] sxemit: code.bin differs on $$name"; exit 1; }; \
	  cmp $$d/na_ld/data.bin $$d/sx_ld/data.bin || { echo "[FAIL] sxemit: data.bin differs on $$name"; exit 1; }; \
	  cmp $$d/na_ld/patch.bin $$d/sx_ld/patch.bin || { echo "[FAIL] sxemit: patch.bin differs on $$name"; exit 1; }; \
	  cmp $$d/na.ilog $$d/sx.ilog || { echo "[FAIL] sxemit: SX_EMIT_LOG differs on $$name"; exit 1; }; \
	  cmp $$d/na.elog $$d/sx.elog || { echo "[FAIL] sxemit: SX_ENCODE_LOG differs on $$name"; exit 1; }; \
	  ./$(SXENCODE_BIN) $$d/sx.elog $$d/sx_ld/code.bin $$d/re_code.bin >/dev/null; \
	  cmp $$d/sx_ld/code.bin $$d/re_code.bin || { echo "[FAIL] sxemit: sxencode round-trip differs on $$name"; exit 1; }; \
	  $$d/sx.elf > $$d/sx.out; \
	  ./$(GEN2) $$fix $$d/g2.c >/dev/null && $(CC) -O1 -o $$d/g2 $$d/g2.c && $$d/g2 > $$d/g2.out; \
	  cmp $$d/sx.out $$d/g2.out || { echo "[FAIL] sxemit: runtime output differs from gen2 on $$name"; exit 1; }; \
	  echo "  [ok] $$name: ELF + code.bin + data.bin + logs + gen2 execution parity verified"; \
	done
	@# Phase-3 refusal diagnostics (return-flow proof, loop/scope refusals)
	@printf 'make f(x: num) -> num {\n  when x > 0 {\n    give 1\n  }\n}\nshow f(1)\n' > $(TESTS)/sxemit/bad_rf.sa
	@if ./$(SXEMIT_BIN) $(TESTS)/sxemit/bad_rf.sa $(TESTS)/sxemit/bad_rf.elf 2>$(TESTS)/sxemit/bad_rf.err; then \
	  echo "[FAIL] sxemit accepted a function that falls off without give"; exit 1; fi
	@grep -q 'may fall through without give' $(TESTS)/sxemit/bad_rf.err
	@printf 'break\n' > $(TESTS)/sxemit/bad_brk.sa
	@if ./$(SXEMIT_BIN) $(TESTS)/sxemit/bad_brk.sa $(TESTS)/sxemit/bad_brk.elf 2>$(TESTS)/sxemit/bad_brk.err; then \
	  echo "[FAIL] sxemit accepted break outside loop"; exit 1; fi
	@grep -q 'break outside a loop' $(TESTS)/sxemit/bad_brk.err
	@echo "[OK] sxemit: phase-3 emit tree + pure-Sayanox IEEE-754 encoder + phases 1..5 match native_aot and gen2 across all fixtures"

native-test: test-native-sxruntime test-native-sxgc test-native-sxemit

native-test: test-native-sxlink test-native-sxencode test-sxdiag

# ---------------------------------------------------------------------------
# test-read-bytes: read_bytes(path, xs) appends the WHOLE file to a byte buffer
# and gives the count, or -1 when the file cannot be read. It is the reader
# that tools/sxlink.sa needs, because read_file goes through a C string and
# stops at the first NUL -- an ELF image is mostly NUL. A byte buffer is an
# ordinary list of numbers, so `xs[i]` reads it back and `len` bounds it.
#
# The round trip below goes through a NUL byte and a 0xFF byte on purpose, and
# the failure leg pins that a missing file appends nothing rather than
# half-filling the buffer. seed-min refuses read_bytes, like every other late
# builtin, and the native backend has no file surface at all.
# ---------------------------------------------------------------------------
.PHONY: test-read-bytes
test-read-bytes: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@# the program takes its scratch directory as arg(1), because assert-out
	@# owns the whole recipe line and a `cd` in front of it would be swallowed
	@printf 'hold dir = arg(1)\nhold p1 = concat(dir, "/WRITEBIN")\nhold p2 = concat(dir, "/WRITEBIN2")\nhold xs = []\nxs = push(xs, 72)\nxs = push(xs, 0)\nxs = push(xs, 255)\nxs = push(xs, 10)\nhold wrote = write_bytes(p1, xs)\nshow wrote\nhold ys = []\nhold got = read_bytes(p1, ys)\nshow got\nshow len(ys)\nshow ys[0]\nshow ys[1]\nshow ys[2]\nshow ys[3]\nhold twice = read_bytes(p1, ys)\nshow twice\nshow len(ys)\nshow ys[4]\nhold miss = read_bytes(concat(dir, "/READBIN-MISSING"), ys)\nshow miss\nshow len(ys)\nhold round = write_bytes(p2, ys)\nshow round\nshow len(ys)\n' > $(TESTS)/read_bytes.sa
	@rm -rf $(TESTS)/read_bytes_run && mkdir -p $(TESTS)/read_bytes_run
	./$(GEN2) $(TESTS)/read_bytes.sa $(TESTS)/read_bytes.c >/dev/null
	@if grep -q '#error' $(TESTS)/read_bytes.c; then echo "[FAIL] read_bytes: #error in the generated C"; exit 1; fi
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/read_bytes $(TESTS)/read_bytes.c
	$(call assert-out,./$(TESTS)/read_bytes '$(CURDIR)/$(TESTS)/read_bytes_run',1\n4\n4\n72\n0\n255\n10\n4\n8\n72\n-1\n8\n1\n8)
	@# The bytes on disk are checked by the program itself -- it reads them back
	@# and prints every one, including the NUL and the 0xFF, and the assert-out
	@# above compares the whole stdout. Only the file sizes are checked here,
	@# because a C string would have stopped at the NUL and a `wc -c` of 4 is
	@# what says it did not. (No od/hexdump: DEPENDENCY.md lists the utilities
	@# the recipes may use, and that list is kept short on purpose.)
	@test "$$(wc -c < $(TESTS)/read_bytes_run/WRITEBIN)" = 4 \
	  || { echo "[FAIL] read_bytes: write_bytes did not write the NUL byte"; exit 1; }
	@# a second read of the same file APPENDS rather than replaces: that is the
	@# documented contract (a byte buffer is an ordinary list and `push` grows
	@# it), so writing the buffer back out gives the four bytes twice
	@test "$$(wc -c < $(TESTS)/read_bytes_run/WRITEBIN2)" = 8 \
	  || { echo "[FAIL] read_bytes: the appended buffer did not round-trip"; exit 1; }
	@# seed-min refuses read_bytes with the same diagnostic every other late
	@# builtin gets, and so does the native backend, which has no file surface
	@printf 'hold xs = []\nhold n = read_bytes("x", xs)\nshow n\n' > $(TESTS)/read_bytes_seed.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/read_bytes_seed.sa > /dev/null 2>$(TESTS)/read_bytes_seed.err; then \
	  echo "[FAIL] seed-min accepted read_bytes without implementing it"; exit 1; fi
	@grep -q 'call names an unknown function or builtin' $(TESTS)/read_bytes_seed.err \
	  || { echo "[FAIL] seed-min refused read_bytes without a clear diagnostic"; cat $(TESTS)/read_bytes_seed.err; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/read_bytes_seed.sa $(TESTS)/read_bytes_seed.elf 2>/dev/null; then \
	  echo "[FAIL] native accepted read_bytes without implementing it"; exit 1; fi
	@echo "[OK] read_bytes: whole-file binary read into a byte buffer (NUL and 0xFF survive), a second read appends, -1 on a missing file with the buffer untouched; seed-min and native refuse it"

test-read-bytes: $(NATIVE_BIN)

.PHONY: test-sxpkg-online-optin
test-sxpkg-online-optin: sxpkg
	rm -rf $(TESTS)/sxpkg-optin && mkdir -p $(TESTS)/sxpkg-optin/p $(TESTS)/sxpkg-optin/mock
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 cd $$P/p && $$W init >/dev/null && $$W add strings 0.1.0 >/dev/null
	# ---- 1. sync refuses without an opt-in, and names the way to opt in ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 if (cd $$P/p && SAYANOX_REGISTRY=https://registry.invalid/r $$W sync) >$$P/no.out 2>$$P/no.err; then \
	   echo "[FAIL] sxpkg sync reached for the network without an opt-in"; exit 1; fi; \
	 grep -q -F 'refusing to use the network without an explicit opt-in' $$P/no.err \
	   || { echo "[FAIL] the refusal does not say why:"; cat $$P/no.err; exit 1; }; \
	 grep -q -F 'SAYANOX_ONLINE=1' $$P/no.err \
	   || { echo "[FAIL] the refusal does not name the opt-in"; exit 1; }; \
	 grep -q -F 'install-local' $$P/no.err \
	   || { echo "[FAIL] the refusal does not offer the offline commands"; exit 1; }
	echo "[OK] sxpkg sync: refused with no opt-in, naming SAYANOX_ONLINE=1, --online and the offline commands"
	# A deterministic failing transport proves opt-in without DNS/network/curl.
	@printf '#!/bin/sh\necho "test transfer attempted" >&2\nexit 1\n' > $(TESTS)/sxpkg-optin/mock/curl
	@chmod +x $(TESTS)/sxpkg-optin/mock/curl
	# ---- 2. SAYANOX_ONLINE=1 lifts it; failed transport falls back to local seed ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 (cd $$P/p && PATH="$$P/mock:$$PATH" SAYANOX_ONLINE=1 SAYANOX_REGISTRY=https://registry.invalid/r $$W sync) >$$P/yes.out 2>$$P/yes.err \
	   || { echo "[FAIL] an opted-in sync exited nonzero:"; cat $$P/yes.err; exit 1; }; \
	 if grep -q -F 'refusing to use the network' $$P/yes.out $$P/yes.err; then \
	   echo "[FAIL] SAYANOX_ONLINE=1 did not lift the refusal"; exit 1; fi; \
	 grep -q -F 'online sync failed; using local seed' $$P/yes.out \
	   || { echo "[FAIL] the opted-in sync never reached the transfer step:"; cat $$P/yes.out; exit 1; }
	@grep -q -F "test transfer attempted" $(TESTS)/sxpkg-optin/yes.err
	# ---- 3. the --online flag form is the same permission ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 (cd $$P/p && PATH="$$P/mock:$$PATH" SAYANOX_REGISTRY=https://registry.invalid/r $$W --online sync) >$$P/flag.out 2>$$P/flag.err \
	   || { echo "[FAIL] 'sxpkg --online sync' exited nonzero:"; cat $$P/flag.err; exit 1; }; \
	 grep -q -F 'online sync failed; using local seed' $$P/flag.out \
	   || { echo "[FAIL] 'sxpkg --online sync' did not attempt the transfer:"; cat $$P/flag.out; exit 1; }
	@grep -q -F "test transfer attempted" $(TESTS)/sxpkg-optin/flag.err
	echo "[OK] sxpkg opt-in: SAYANOX_ONLINE=1 and 'sxpkg --online <cmd>' both permit the transfer, which then fails in the test stub (no network) and falls back to the offline seed"
	# ---- 4. install with every locked package already local needs no opt-in ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 rm -rf $$P/p/.sayanox/registry/strings && cp -r registry/strings $$P/p/.sayanox/registry/strings && \
	 (cd $$P/p && SAYANOX_REGISTRY=https://registry.invalid/r $$W install) >$$P/off.out 2>$$P/off.err \
	   || { echo "[FAIL] an all-local install demanded the network:"; cat $$P/off.out $$P/off.err; exit 1; }; \
	 grep -q -F 'verify ok' $$P/off.out || { echo "[FAIL] the all-local install did not verify:"; cat $$P/off.out; exit 1; }; \
	 if grep -q -F 'refusing to use the network' $$P/off.out $$P/off.err; then \
	   echo "[FAIL] an all-local install printed the network refusal"; exit 1; fi
	echo "[OK] sxpkg install: an all-local lock is copied and verified with no opt-in (offline stays first-class)"
	# ---- 5. install that must fetch refuses without an opt-in ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 rm -rf $$P/p/.sayanox/registry/strings; \
	 if (cd $$P/p && SAYANOX_REGISTRY=https://registry.invalid/r $$W install) >$$P/need.out 2>$$P/need.err; then \
	   echo "[FAIL] sxpkg install reached for the network without an opt-in"; exit 1; fi; \
	 grep -q -F 'refusing to use the network without an explicit opt-in' $$P/need.err \
	   || { echo "[FAIL] the install refusal does not say why:"; cat $$P/need.err; exit 1; }
	# ---- 6. fetch: a file:// URL is local, a remote URL is not ----
	W=$(CURDIR)/$(SXPKG_BIN); P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 printf 'show 1\n' > $$P/one.sa; \
	 (cd $$P/p && $$W fetch file://$$P/one.sa onepkg) >$$P/f1.out 2>$$P/f1.err \
	   || { echo "[FAIL] fetch of a file:// URL asked for an opt-in:"; cat $$P/f1.err; exit 1; }; \
	 grep -q -F 'fetched onepkg' $$P/f1.out || { echo "[FAIL] the file:// fetch did not complete:"; cat $$P/f1.out; exit 1; }; \
	 if (cd $$P/p && $$W fetch https://registry.invalid/one.sa onepkg2) >$$P/f2.out 2>$$P/f2.err; then \
	   echo "[FAIL] sxpkg fetch reached for the network without an opt-in"; exit 1; fi; \
	 grep -q -F 'refusing to use the network without an explicit opt-in' $$P/f2.err \
	   || { echo "[FAIL] the fetch refusal does not say why:"; cat $$P/f2.err; exit 1; }
	# ---- 7. a refused transfer leaves nothing behind ----
	P=$(CURDIR)/$(TESTS)/sxpkg-optin; \
	 if [ -n "$$(find $$P -name '*.part' 2>/dev/null)" ]; then \
	   echo "[FAIL] a refused transfer left a .part file:"; find $$P -name '*.part'; exit 1; fi; \
	 if [ -e $$P/p/.sayanox/registry/onepkg2 ]; then \
	   echo "[FAIL] a refused fetch created a package directory"; exit 1; fi
	echo "[OK] sxpkg fetch: a file:// URL needs no opt-in, a remote URL refuses without one, and a refusal leaves no .part file and no package directory"
	echo "[OK] sxpkg online is opt-in: sync/install/fetch refuse before any transfer, SAYANOX_ONLINE=1 and --online lift it, file:// and all-local paths never ask"

# ---------------------------------------------------------------------------
# test-sxpkg-online-local: the online install path, tested against a LOCAL
# registry through file:// URLs (no network or transfer runtime). Part of
# bootstrap gates; local copies use POSIX cp, not curl/wget.
#   good remote     -> installed and verified, rc 0
#   tampered remote -> rejected: verify fails, the download is removed, rc 1
#   missing remote  -> no partial .part file is left, rc 1
# ---------------------------------------------------------------------------
test-sxpkg-online-local: sxpkg
	@rm -rf $(TESTS)/sxpkg-online && mkdir -p $(TESTS)/sxpkg-online
	@cp -r registry $(TESTS)/sxpkg-online/good
	@cp -r $(TESTS)/sxpkg-online/good $(TESTS)/sxpkg-online/bad
	@printf 'show 999\n' >> $(TESTS)/sxpkg-online/bad/strings/main.sa
	@cp -r $(TESTS)/sxpkg-online/good $(TESTS)/sxpkg-online/miss && rm -rf $(TESTS)/sxpkg-online/miss/strings
	@W=$(CURDIR)/$(SXPKG_BIN); \
	for c in good bad miss; do \
	  mkdir -p $(TESTS)/sxpkg-online/p_$$c && cd $(TESTS)/sxpkg-online/p_$$c && \
	  $$W init >/dev/null && $$W add strings 0.1.0 >/dev/null || exit 1; \
	  SAYANOX_REGISTRY=file://$(CURDIR)/$(TESTS)/sxpkg-online/$$c $$W install >$(CURDIR)/$(TESTS)/sxpkg-online/$$c.out 2>&1; rc=$$?; \
	  cd $(CURDIR); \
	  case $$c in \
	    good) [ $$rc -eq 0 ] || { echo "[FAIL] good remote: rc=$$rc"; exit 1; }; \
	          grep -q 'verify ok' $(TESTS)/sxpkg-online/$$c.out || { echo "[FAIL] good remote: not verified"; exit 1; } ;; \
	    bad)  [ $$rc -eq 1 ] || { echo "[FAIL] tampered remote accepted (rc=$$rc)"; exit 1; }; \
	          [ ! -e $(TESTS)/sxpkg-online/p_bad/.sayanox/registry/strings/main.sa ] || { echo "[FAIL] tampered package left in the registry"; exit 1; } ;; \
	    miss) [ $$rc -eq 1 ] || { echo "[FAIL] missing remote not rejected (rc=$$rc)"; exit 1; }; \
	          [ ! -e $(TESTS)/sxpkg-online/p_miss/.sayanox/registry/strings/main.sa.part ] || { echo "[FAIL] partial download left behind"; exit 1; } ;; \
	  esac; \
	done
	@echo "[OK] sxpkg online install (file:// registry): good accepted, tampered rejected and removed, missing leaves no partial file"

# ---------------------------------------------------------------------------
# test-stdlib-growth: the numeric helpers added to stdlib/tiny.sa on 2026-10-10
# (tri, min3/max3, ceil_div, pow_mod, collatz_steps, digit_at, is_palindrome,
# isqrt). Hand-computed expected values; seed-min, gen2 and native (when built)
# must print identical bytes. Source: selfhost/stdlib_growth_test.sa.
# ---------------------------------------------------------------------------
test-stdlib-growth: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_growth_test.sa > $(TESTS)/sg_sm.c
	$(CC) -O2 -o $(TESTS)/sg_sm $(TESTS)/sg_sm.c
	./$(GEN2) selfhost/stdlib_growth_test.sa $(TESTS)/sg_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/sg_g2 $(TESTS)/sg_g2.c
	$(call assert-out,./$(TESTS)/sg_g2,55\n0\n0\n2\n9\n-7\n4\n4\n0\n1\n24\n1\n1\n0\n8\n16\n5\n1\n3\n0\n1\n0\n0\n1\n0\n3\n4\n4\n1000)
	@./$(TESTS)/sg_sm > $(TESTS)/sg_sm.out && ./$(TESTS)/sg_g2 > $(TESTS)/sg_g2.out && cmp $(TESTS)/sg_sm.out $(TESTS)/sg_g2.out
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_growth_test.sa $(TESTS)/sg_nat && \
	  ./$(TESTS)/sg_nat > $(TESTS)/sg_nat.out && cmp $(TESTS)/sg_g2.out $(TESTS)/sg_nat.out || exit 1; \
	fi
	@echo "[OK] stdlib growth: 9 new public numeric helpers, seed-min == gen2 (== native when built)"

# ---------------------------------------------------------------------------
# test-stdlib-modules: three new stdlib modules, checked on ALL THREE backends.
#
#   stdlib/num_util.sa   untyped numeric helpers: trunc/floor/ceil/round/frac
#                        (built on `% 1e15`, the dialect's only double->int
#                        truncation), Euclidean modulo, integer division,
#                        wrap, range mapping, avg/median3, degrees/radians,
#                        angle normalisation. Untyped and numeric like tiny.sa,
#                        so the native-AOT subset runs it too.
#   stdlib/list_algo.sa  typed list algorithms: insertion sort, sorted check,
#                        index_of, append, slice/take/drop, cumsum, repeat,
#                        scale/offset, zip_add, count_gt, remove_at, insert_at,
#                        distinct. Every transform returns a NEW list; the
#                        fixture re-checks the input length afterwards.
#   stdlib/str_text.sa   typed byte-string helpers: index_of/last_index_of,
#                        slice, trim/trim_left/trim_right, cmp, is_digits,
#                        pad_left/pad_right, word_count, replace, remove,
#                        hash, parse_uint, uint_str.
#
# 99 hand-computed values in selfhost/stdlib_modules_test.sa; seed-min, gen2
# and native must print identical bytes. This is growth of a SMALL portable
# library, not a full stdlib claim: no JSON, no HTTP client, no dates, no
# unicode, no floating-point transcendental functions (see docs/STDLIB.md).
# ---------------------------------------------------------------------------
.PHONY: test-stdlib-modules
STM_WANT := 2\n-2\n2\n-3\n3\n3\n-2\n3\n3\n2\n-2\n0.25\n-0.25\n3\n7\n2\n1\n3\n-3\n2\n1\n150\n1\n3.5\n2\n3.14159\n180\n269.5\n1\n5\n1\n1\n3\n4\n5\n0\n1\n5\n2\n1\n-1\n3\n3\n3\n1\n1\n2\n1\n1\n1\n3\n6\n3\n7\n6\n11\n2\n22\n3\n4\n4\n6\n9\n6\n9\n4\n5\n1\n5\n-1\nell\nlo\n\nab\nab  \n  ab\n\n-1\n1\n0\n1\n0\n0\n007\n7..\n1234\n2\n0\nazc\nabc\n0\n97\n3105\n42\n0\n1234\n0\n7\nmodules-done
test-stdlib-modules: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_modules_test.sa > $(TESTS)/stm_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stm_seed $(TESTS)/stm_seed.c
	./$(GEN2) selfhost/stdlib_modules_test.sa $(TESTS)/stm_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stm_gen2 $(TESTS)/stm_gen2.c
	$(call assert-out,./$(TESTS)/stm_seed,$(STM_WANT))
	$(call assert-out,./$(TESTS)/stm_gen2,$(STM_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_modules_test.sa $(TESTS)/stm_native || exit 1; \
	  ./$(TESTS)/stm_native > $(TESTS)/stm_native.out || exit 1; \
	  ./$(TESTS)/stm_seed > $(TESTS)/stm_seed.out || exit 1; \
	  cmp $(TESTS)/stm_seed.out $(TESTS)/stm_native.out || { echo "[FAIL] native stdlib modules differ from seed-min"; exit 1; }; \
	  echo '[OK] native stdlib module parity (num_util, list_algo, str_text)'; \
	else echo '[SKIP] native stdlib module parity: native_aot not built'; fi
	@# each module stands alone, and all seven modules coexist without a name
	@# collision (the prefixes nu_/la_/t_ keep them apart)
	@printf 'use "stdlib/num_util.sa"\nshow nu_floor(2.5)\nshow nu_ceil(2.5)\n' > $(TESTS)/stm_alone_num.sa
	./$(SEED_MIN_BIN) $(TESTS)/stm_alone_num.sa > $(TESTS)/stm_alone_num.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_alone_num $(TESTS)/stm_alone_num.c
	$(call assert-out,./$(TESTS)/stm_alone_num,2\n3)
	@printf 'use "stdlib/list_algo.sa"\nhold xs = [3, 1, 2]\nhold s = la_sort(xs)\nshow s[0]\nshow s[2]\nshow la_sorted(s)\n' > $(TESTS)/stm_alone_list.sa
	./$(SEED_MIN_BIN) $(TESTS)/stm_alone_list.sa > $(TESTS)/stm_alone_list.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_alone_list $(TESTS)/stm_alone_list.c
	$(call assert-out,./$(TESTS)/stm_alone_list,1\n3\n1)
	./$(GEN2) $(TESTS)/stm_alone_list.sa $(TESTS)/stm_alone_list_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_alone_list_g2 $(TESTS)/stm_alone_list_g2.c
	$(call assert-out,./$(TESTS)/stm_alone_list_g2,1\n3\n1)
	@printf 'use "stdlib/str_text.sa"\nshow t_trim("  hi  ")\nshow t_word_count("a b  c")\nshow t_uint_str(90)\n' > $(TESTS)/stm_alone_str.sa
	./$(SEED_MIN_BIN) $(TESTS)/stm_alone_str.sa > $(TESTS)/stm_alone_str.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_alone_str $(TESTS)/stm_alone_str.c
	$(call assert-out,./$(TESTS)/stm_alone_str,hi\n3\n90)
	./$(GEN2) $(TESTS)/stm_alone_str.sa $(TESTS)/stm_alone_str_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_alone_str_g2 $(TESTS)/stm_alone_str_g2.c
	$(call assert-out,./$(TESTS)/stm_alone_str_g2,hi\n3\n90)
	@printf 'use "stdlib/tiny.sa"\nuse "stdlib/num_util.sa"\nuse "stdlib/str_util.sa"\nuse "stdlib/str_text.sa"\nuse "stdlib/list_util.sa"\nuse "stdlib/list_algo.sa"\nuse "stdlib/file_util.sa"\nshow gcd(12, 18)\nshow nu_round(2.6)\nshow s_len("abc")\nshow t_index_of("abc", 99)\nhold xs = [2, 1]\nshow l_sum(xs)\nhold s = la_sort(xs)\nshow s[0]\nshow f_exists("$(TESTS)/stm_no_such_file")\n' > $(TESTS)/stm_all.sa
	./$(SEED_MIN_BIN) $(TESTS)/stm_all.sa > $(TESTS)/stm_all_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_all_seed $(TESTS)/stm_all_seed.c
	$(call assert-out,./$(TESTS)/stm_all_seed,6\n3\n3\n2\n3\n1\n0)
	./$(GEN2) $(TESTS)/stm_all.sa $(TESTS)/stm_all_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stm_all_g2 $(TESTS)/stm_all_g2.c
	$(call assert-out,./$(TESTS)/stm_all_g2,6\n3\n3\n2\n3\n1\n0)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/stm_all.sa $(TESTS)/stm_all_native || exit 1; \
	  $(TESTS)/stm_all_native > $(TESTS)/stm_all_native.out || exit 1; \
	  ./$(TESTS)/stm_all_seed > $(TESTS)/stm_all_seed.out || exit 1; \
	  cmp $(TESTS)/stm_all_seed.out $(TESTS)/stm_all_native.out || { echo "[FAIL] native all-modules program differs"; exit 1; }; \
	fi
	@# ---- stdlib/json_util.sa: flat-object JSON build/read, three backends --
	./$(SEED_MIN_BIN) selfhost/stdlib_json_test.sa > $(TESTS)/sjson_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sjson_seed $(TESTS)/sjson_seed.c
	./$(GEN2) selfhost/stdlib_json_test.sa $(TESTS)/sjson_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sjson_gen2 $(TESTS)/sjson_gen2.c
	./$(TESTS)/sjson_seed > $(TESTS)/sjson_seed.out; ./$(TESTS)/sjson_gen2 > $(TESTS)/sjson_gen2.out; \
	  cmp $(TESTS)/sjson_seed.out $(TESTS)/sjson_gen2.out
	@grep -q -F '{"name":"a\"b","n":42,"ok":true,"pi":3.5}' $(TESTS)/sjson_seed.out || { echo "[FAIL] json builder output wrong"; cat $(TESTS)/sjson_seed.out; exit 1; }
	@grep -q -F 'json-done' $(TESTS)/sjson_seed.out || { echo "[FAIL] json fixture did not run to completion"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_json_test.sa $(TESTS)/sjson_native || exit 1; \
	  ./$(TESTS)/sjson_native > $(TESTS)/sjson_native.out || exit 1; \
	  cmp $(TESTS)/sjson_seed.out $(TESTS)/sjson_native.out || { echo "[FAIL] native json_util differs from seed-min"; exit 1; }; \
	  echo '[OK] native json_util parity (flat-object build/read)'; \
	else echo '[SKIP] native json_util parity: native_aot not built'; fi

	@echo '[OK] stdlib growth: num_util (17 helpers) + list_algo (17) + str_text (18) = 52 helpers, 99 hand-computed values identical on seed-min, gen2 and native; each module stands alone and all seven coexist'
test-stdlib: test-stdlib-modules
test-stdlib-growth: test-stdlib-modules

# ---------------------------------------------------------------------------
# test-native-strord: string ordering < <= > >= on native (added 2026-10-10).
# Native used to refuse it; it now compares bytes as unsigned char, like
# strcmp. Expected output is hand-computed; seed-min, gen2 and native must all
# print it. Source: selfhost/native_strord_test.sa.
# ---------------------------------------------------------------------------
NSO_WANT := 1\n0\n1\n0\n1\n1\n1\n1\n1\n1\n1\n1\n1\n100\n300
test-native-strord: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/native_strord_test.sa > $(TESTS)/nso_sm.c
	$(CC) -O2 -o $(TESTS)/nso_sm $(TESTS)/nso_sm.c
	./$(GEN2) selfhost/native_strord_test.sa $(TESTS)/nso_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nso_g2 $(TESTS)/nso_g2.c
	$(call assert-out,./$(TESTS)/nso_sm,$(NSO_WANT))
	$(call assert-out,./$(TESTS)/nso_g2,$(NSO_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/native_strord_test.sa $(TESTS)/nso_nat || exit 1; \
	  ./$(TESTS)/nso_nat > $(TESTS)/nso_nat.out || exit 1; \
	  ./$(TESTS)/nso_g2 > $(TESTS)/nso_g2.out || exit 1; \
	  cmp $(TESTS)/nso_g2.out $(TESTS)/nso_nat.out || { echo "[FAIL] native string ordering differs from gen2"; exit 1; }; \
	fi
	@echo "[OK] string ordering < <= > >=: seed-min == gen2 (== native when built)"

# ---------------------------------------------------------------------------
# test-native-lang: true/false, and/or/not as values, elif / else if / else
# when, for over a range, a list and a string, break and continue (added
# 2026-10-11).  Source: selfhost/native_lang_test.sa.  The expected output is
# hand-computed (and/or give 1 or 0, as C's && and ||); gen2 must print it and
# native must match gen2 byte for byte.  seed-min refuses the file.
# ---------------------------------------------------------------------------
NLA_WANT := 1\n0\n5\n7\n300\n200\n100\n2\n4\n10\n12\na\nb\nc\n0\n1\n2\n4\n5\n1\n3\n4\n0\n10\n20\n1\n77
test-native-lang: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_lang_test.sa $(TESTS)/nla_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nla_g2 $(TESTS)/nla_g2.c
	$(call assert-out,./$(TESTS)/nla_g2,$(NLA_WANT))
	./$(SEED_MIN_BIN) selfhost/native_lang_test.sa > $(TESTS)/nla_seed.c
	$(CC) -O2 -o $(TESTS)/nla_seed $(TESTS)/nla_seed.c
	$(call assert-out,./$(TESTS)/nla_seed,$(NLA_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/native_lang_test.sa $(TESTS)/nla_nat || exit 1; \
	  ./$(TESTS)/nla_nat > $(TESTS)/nla_nat.out || exit 1; \
	  ./$(TESTS)/nla_g2 > $(TESTS)/nla_g2.out || exit 1; \
	  cmp $(TESTS)/nla_g2.out $(TESTS)/nla_nat.out || { echo "[FAIL] native language test differs from gen2"; exit 1; }; \
	  printf 'make f(n) {\n  for i in 0..2 {\n    show i\n  }\n  give 0\n}\nshow f(1)\n' > $(TESTS)/nla_neg1.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nla_neg1.sa $(TESTS)/nla_neg1 || exit 1; \
	  printf '0\n1\n0\n' > $(TESTS)/nla_for_fn.want; \
	  ./$(TESTS)/nla_neg1 > $(TESTS)/nla_for_fn.out || exit 1; \
	  cmp $(TESTS)/nla_for_fn.want $(TESTS)/nla_for_fn.out || exit 1; \
	  printf 'hold a = 1\nbreak\n' > $(TESTS)/nla_neg2.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nla_neg2.sa $(TESTS)/nla_neg2 2>&1 | grep -q 'break outside a loop' || { echo "[FAIL] native accepted break outside a loop"; exit 1; }; \
	  printf 'hold s = "ab"\nwhen s and 1 {\n  show 1\n}\n' > $(TESTS)/nla_neg3.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nla_neg3.sa $(TESTS)/nla_neg3 2>&1 | grep -q 'must be a number' || { echo "[FAIL] native accepted a string operand of and"; exit 1; }; \
	fi
	@echo "[OK] native: true/false, and/or/not in conditions, elif / else if / else when, for over a range, a list and a string, break and continue; native and seed-min == gen2 byte for byte"

# ---------------------------------------------------------------------------
# test-native-locals: `hold` inside a make body (added 2026-10-11).  A local
# is a slot in the call's own frame, so recursion gets fresh locals; the
# collector sees the frame's values (conservative stack scan).  Source:
# selfhost/native_locals_test.sa.  Expected output is hand-computed; gen2 must
# print it and native must match gen2 byte for byte.
# ---------------------------------------------------------------------------
NLO_WANT := 20\n1\n2\n10\n7\n6\n4
test-native-locals: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_locals_test.sa $(TESTS)/nlo_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nlo_g2 $(TESTS)/nlo_g2.c
	$(call assert-out,./$(TESTS)/nlo_g2,$(NLO_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/native_locals_test.sa $(TESTS)/nlo_nat || exit 1; \
	  ./$(TESTS)/nlo_nat > $(TESTS)/nlo_nat.out || exit 1; \
	  ./$(TESTS)/nlo_g2 > $(TESTS)/nlo_g2.out || exit 1; \
	  cmp $(TESTS)/nlo_g2.out $(TESTS)/nlo_nat.out || { echo "[FAIL] native make locals differ from gen2"; exit 1; }; \
	  printf 'hold x = 1\nmake f(x) {\n  hold x = 2\n  give x\n}\nshow f(1)\n' > $(TESTS)/nlo_neg1.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nlo_neg1.sa $(TESTS)/nlo_neg1 2>&1 | grep -q 'it is a parameter of make' || { echo "[FAIL] native let a local shadow a parameter"; exit 1; }; \
	fi
	@echo "[OK] native: hold inside make (per-call locals, recursion, while, strings, collector keeps a local alive); native == gen2 byte for byte"

# ---------------------------------------------------------------------------
# test-give-index: `give xs[i]` inside a make (added 2026-10-11).  gen2 used to
# emit xs[1.0] (the postfix index rewrite only ran on hold/show operands).
# Source: selfhost/give_index_test.sa; hand-computed output; gen2 and native
# must both print it.
# ---------------------------------------------------------------------------
GIX_WANT := 4\n34\n5\n15\n8
test-give-index: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/give_index_test.sa $(TESTS)/gix_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gix_g2 $(TESTS)/gix_g2.c
	$(call assert-out,./$(TESTS)/gix_g2,$(GIX_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/give_index_test.sa $(TESTS)/gix_nat || exit 1; \
	  ./$(TESTS)/gix_nat > $(TESTS)/gix_nat.out || exit 1; \
	  ./$(TESTS)/gix_g2 > $(TESTS)/gix_g2.out || exit 1; \
	  cmp $(TESTS)/gix_g2.out $(TESTS)/gix_nat.out || { echo "[FAIL] native give index differs from gen2"; exit 1; }; \
	fi
	@echo "[OK] give xs[i] inside make: gen2 and native print the hand-computed values"

# ---------------------------------------------------------------------------
# test-typed-sig: typed signatures (added 2026-10-11).  A make is either fully
# typed (`make f(a: num, b: num) -> num`) or fully untyped (the shared pure-min
# form); a partly typed parameter list or a missing return type is an error on
# all three backends. Seed-min requires an explicit final give.  Source:
# selfhost/typed_sig_test.sa; expected output hand-computed.
# ---------------------------------------------------------------------------
TSG_WANT := 5\n120\n7
test-typed-sig: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/typed_sig_test.sa $(TESTS)/tsg_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/tsg_g2 $(TESTS)/tsg_g2.c
	$(call assert-out,./$(TESTS)/tsg_g2,$(TSG_WANT))
	./$(SEED_MIN_BIN) selfhost/typed_sig_test.sa > $(TESTS)/tsg_seed.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/tsg_seed $(TESTS)/tsg_seed.c
	$(call assert-out,./$(TESTS)/tsg_seed,$(TSG_WANT))
	@printf 'make bad(a: num, b) -> num {\n  give a + b\n}\nshow bad(1, 2)\n' > $(TESTS)/tsg_mixed.sa
	@printf 'make bad(a: num) {\n  give a\n}\nshow bad(1)\n' > $(TESTS)/tsg_noret.sa
	@./$(GEN2) $(TESTS)/tsg_mixed.sa $(TESTS)/tsg_m.c | grep -q 'a typed make needs a type on every parameter' || { echo "[FAIL] gen2 accepted a partly typed signature"; exit 1; }
	@./$(GEN2) $(TESTS)/tsg_noret.sa $(TESTS)/tsg_n.c | grep -q 'a typed make needs a return type' || { echo "[FAIL] gen2 accepted a typed signature with no return type"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/typed_sig_test.sa $(TESTS)/tsg_nat || exit 1; \
	  ./$(TESTS)/tsg_nat > $(TESTS)/tsg_nat.out || exit 1; \
	  ./$(TESTS)/tsg_g2 > $(TESTS)/tsg_g2.out || exit 1; \
	  cmp $(TESTS)/tsg_g2.out $(TESTS)/tsg_nat.out || { echo "[FAIL] native typed signatures differ from gen2"; exit 1; }; \
	  ./$(NATIVE_BIN) $(TESTS)/tsg_mixed.sa $(TESTS)/tsg_m2 2>&1 | grep -q 'a typed signature needs a type on every parameter' || { echo "[FAIL] native accepted a partly typed signature"; exit 1; }; \
	  ./$(NATIVE_BIN) $(TESTS)/tsg_noret.sa $(TESTS)/tsg_n2 2>&1 | grep -q 'a typed signature needs a return type' || { echo "[FAIL] native accepted a typed signature with no return type"; exit 1; }; \
	fi
	@echo "[OK] typed signatures: fully typed make runs on gen2 and native (same output); partly typed or return-less signatures are refused; seed-min matches the fixture"

# ---------------------------------------------------------------------------
# test-list-expr: list literal elements are numeric expressions (added
# 2026-10-11): `[a, a + 1]`, `[n, n * 2]` inside a make.  A string, list or
# struct element is refused by name on gen2 and native.  Source:
# selfhost/list_expr_test.sa; expected output hand-computed.
# ---------------------------------------------------------------------------
LEX_WANT := 5\n2\n14\n3\n8
test-list-expr: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/list_expr_test.sa $(TESTS)/lex_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/lex_g2 $(TESTS)/lex_g2.c
	$(call assert-out,./$(TESTS)/lex_g2,$(LEX_WANT))
	@printf 'hold xs = [1, "x"]\nshow len(xs)\n' > $(TESTS)/lex_bad.sa
	@./$(GEN2) $(TESTS)/lex_bad.sa $(TESTS)/lex_bad_g2.c | grep -q 'list elements must be numbers' || { echo "[FAIL] gen2 accepted a string list element"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/list_expr_test.sa $(TESTS)/lex_nat || exit 1; \
	  ./$(TESTS)/lex_nat > $(TESTS)/lex_nat.out || exit 1; \
	  ./$(TESTS)/lex_g2 > $(TESTS)/lex_g2.out || exit 1; \
	  cmp $(TESTS)/lex_g2.out $(TESTS)/lex_nat.out || { echo "[FAIL] native list expressions differ from gen2"; exit 1; }; \
	  ./$(NATIVE_BIN) $(TESTS)/lex_bad.sa $(TESTS)/lex_bad_nat 2>&1 | grep -q 'list elements must be numbers' || { echo "[FAIL] native accepted a string list element"; exit 1; }; \
	fi
	@echo "[OK] list literal elements are numeric expressions (params, operators, push); string elements refused on gen2 and native"

# test-list-paren: list literal elements with grouping parentheses ([a, (a - 1)]),
# STATUS known gap (item 6). Hand-computed output; gen2 and native must match.
test-list-paren: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/list_paren_test.sa $(TESTS)/lp_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/lp_g2 $(TESTS)/lp_g2.c
	$(call assert-out,./$(TESTS)/lp_g2,5\n4\n10\n5\n4\n7\n2)
	./$(NATIVE_BIN) selfhost/list_paren_test.sa $(TESTS)/lp_nat
	./$(TESTS)/lp_nat > $(TESTS)/lp_nat.out
	./$(TESTS)/lp_g2 > $(TESTS)/lp_g2.out
	@cmp $(TESTS)/lp_g2.out $(TESTS)/lp_nat.out || { echo "FAILED: native list parens differ from gen2"; exit 1; }
	@echo "[OK] list literal elements with grouping parens: gen2 and native agree"

# test-native-strfn: native string parameters and string return values (typed `str`).
# Hand-computed output; gen2 and native must match; type mistakes are refused.
test-native-strfn: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_str_fn_test.sa $(TESTS)/nsf_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nsf_g2 $(TESTS)/nsf_g2.c
	./$(NATIVE_BIN) selfhost/native_str_fn_test.sa $(TESTS)/nsf_nat
	./$(TESTS)/nsf_nat > $(TESTS)/nsf_nat.out
	./$(TESTS)/nsf_g2 > $(TESTS)/nsf_g2.out
	@printf 'hi bob\n6\nh\n1\n4\n' > $(TESTS)/nsf_want.out
	@cmp $(TESTS)/nsf_nat.out $(TESTS)/nsf_want.out || { echo "FAILED: native string functions differ from the hand-computed output"; exit 1; }
	@cmp $(TESTS)/nsf_g2.out $(TESTS)/nsf_want.out || { echo "FAILED: gen2 string functions differ from the hand-computed output"; exit 1; }
	@printf 'make count(s: str) -> num {\n  give len(s)\n}\nshow count(5)\n' > $(TESTS)/nsf_bad1.sa
	@./$(NATIVE_BIN) $(TESTS)/nsf_bad1.sa $(TESTS)/nsf_bad1 2>&1 | grep -q 'takes a string' || { echo "FAILED: native accepted a number for a str parameter"; exit 1; }
	@printf 'make f(a: num) -> str {\n  give 1\n}\nhold z = f(1)\nshow z\n' > $(TESTS)/nsf_bad2.sa
	@./$(NATIVE_BIN) $(TESTS)/nsf_bad2.sa $(TESTS)/nsf_bad2 2>&1 | grep -q 'give must give a string' || { echo "FAILED: native accepted a number return for a str function"; exit 1; }
	@echo "[OK] native string parameters and string returns: same output as gen2; number/string mistakes refused"

# test-native-strgen: native generics over str (one copy per call-site kind),
# gen2 and native must match; two kinds for one type parameter and list args are refused.
test-native-strgen: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_str_gen_test.sa $(TESTS)/nsg_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nsg_g2 $(TESTS)/nsg_g2.c
	./$(NATIVE_BIN) selfhost/native_str_gen_test.sa $(TESTS)/nsg_nat
	./$(TESTS)/nsg_nat > $(TESTS)/nsg_nat.out
	./$(TESTS)/nsg_g2 > $(TESTS)/nsg_g2.out
	@printf 'abc\n42\nyo\n7\n5\nnest\n' > $(TESTS)/nsg_want.out
	@cmp $(TESTS)/nsg_nat.out $(TESTS)/nsg_want.out || { echo "FAILED: native string generics differ from the hand-computed output"; exit 1; }
	@cmp $(TESTS)/nsg_g2.out $(TESTS)/nsg_want.out || { echo "FAILED: gen2 string generics differ from the hand-computed output"; exit 1; }
	@printf 'make pair<T>(a: T, b: T) -> T {\n  give a\n}\nshow pair(1, "x")\n' > $(TESTS)/nsg_bad1.sa
	@./$(NATIVE_BIN) $(TESTS)/nsg_bad1.sa $(TESTS)/nsg_bad1 2>&1 | grep -q 'given two different kinds' || { echo "FAILED: native accepted two kinds for one type parameter"; exit 1; }
	@echo "[OK] native generics over str: same output as gen2; two kinds for one type parameter are refused (list generics: test-native-listgen)"

# test-native-listgen: native lists as typed parameters (xs: list), list return values
# and list generics (make f<T> with T = list); gen2 and native must match; struct and
# wrong-kind returns are refused.
test-native-listgen: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_list_gen_test.sa $(TESTS)/nlg_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nlg_g2 $(TESTS)/nlg_g2.c
	./$(NATIVE_BIN) selfhost/native_list_gen_test.sa $(TESTS)/nlg_nat
	./$(TESTS)/nlg_nat > $(TESTS)/nlg_nat.out
	./$(TESTS)/nlg_g2 > $(TESTS)/nlg_g2.out
	@printf '3\n4\n6\n3\n9\n2\n8\n' > $(TESTS)/nlg_want.out
	@cmp $(TESTS)/nlg_nat.out $(TESTS)/nlg_want.out || { echo "FAILED: native list functions differ from the hand-computed output"; exit 1; }
	@cmp $(TESTS)/nlg_g2.out $(TESTS)/nlg_want.out || { echo "FAILED: gen2 list functions differ from the hand-computed output"; exit 1; }
	@printf 'make f(xs: list) -> num {\n  give xs\n}\nshow f([1])\n' > $(TESTS)/nlg_bad1.sa
	@./$(NATIVE_BIN) $(TESTS)/nlg_bad1.sa $(TESTS)/nlg_bad1 2>&1 | grep -q 'give must give a number (got a list)' || { echo "FAILED: native accepted a list returned from a number function"; exit 1; }
	@printf 'make g(s: struct) -> num {\n  give 1\n}\nshow 1\n' > $(TESTS)/nlg_bad2.sa
	@./$(NATIVE_BIN) $(TESTS)/nlg_bad2.sa $(TESTS)/nlg_bad2 2>&1 | grep -q "not in the native subset" || { echo "FAILED: native accepted a struct parameter"; exit 1; }
	@echo "[OK] native lists as parameters, return values and generic arguments: same output as gen2 (list is passed by reference on both); wrong-kind returns and struct parameters refused"

# test-native-logicarg: and/or/not as builtin arguments and struct field values (native).
# Hand-computed output. gen2 still refuses these forms (see docs/STATUS.md).
test-native-logicarg: $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(NATIVE_BIN) selfhost/native_logic_arg_test.sa $(TESTS)/nla_nat
	./$(TESTS)/nla_nat > $(TESTS)/nla_nat.out
	@printf '1\n1\nA\nB\nA\n3\n121\nB\n' > $(TESTS)/nla_want.out
	@cmp $(TESTS)/nla_nat.out $(TESTS)/nla_want.out || { echo "FAILED: native logic values in builtin arguments and struct fields differ from the hand-computed output"; exit 1; }
	@echo "[OK] native: and/or/not as builtin arguments (chr, len, sx_index) and as struct field values, hand-computed output"

# test-cond-string: item 9 -- a string or list operand of and/or/not in a when/while
# condition (or a bare string condition) is refused by gen2 and native; == on strings and
# a name inside a call stay allowed (gen2 and native agree on the output).
test-cond-string: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	@for c in 'hold s = "ab"\nhold a = 1\nwhen s and a {\n  show 1\n}' 'hold s = "ab"\nhold a = 1\nwhen a and s {\n  show 1\n}' 'hold s = "ab"\nhold a = 1\nwhen not s {\n  show 1\n}' 'hold s = "ab"\nwhen s {\n  show 1\n}' 'hold s = "ab"\nhold a = 1\nwhile s and a {\n  show 1\n  hold a = 0\n}' 'hold s = "ab"\nhold a = 1\nwhen (s and a) {\n  show 1\n}'; do \
	  printf "$$c\n" > $(TESTS)/cs_bad.sa; \
	  if ./$(GEN2) $(TESTS)/cs_bad.sa $(TESTS)/cs_bad.c 2>&1 | grep -q 'a condition must be numeric'; then :; else echo "FAILED: gen2 accepted a string operand in a condition"; exit 1; fi; \
	  if ./$(NATIVE_BIN) $(TESTS)/cs_bad.sa $(TESTS)/cs_bad >/dev/null 2>&1; then echo "FAILED: native accepted a string operand in a condition"; exit 1; fi; \
	done
	./$(GEN2) selfhost/cond_string_ok_test.sa $(TESTS)/cs_ok.c >/dev/null
	$(CC) -O2 -o $(TESTS)/cs_ok_g2 $(TESTS)/cs_ok.c
	./$(NATIVE_BIN) selfhost/cond_string_ok_test.sa $(TESTS)/cs_ok_nat
	@test "$$(./$(TESTS)/cs_ok_g2 | tr '\n' ' ')" = "7 8 " || { echo "FAILED: gen2 output of the valid string conditions"; exit 1; }
	@test "$$(./$(TESTS)/cs_ok_nat | tr '\n' ' ')" = "7 8 " || { echo "FAILED: native output of the valid string conditions"; exit 1; }
	@echo "[OK] string operands in and/or/not conditions and bare string conditions refused by gen2 and native; == on strings and calls still accepted (7 8)"

# test-gen2-logic-builtin: and/or/not as operands of numeric builtins (len, sx_index,
# string_eq) in gen2 and native; hand-computed output. chr stays refused (string result).
test-gen2-logic-builtin: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_logic_builtin_test.sa $(TESTS)/glb_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/glb_g2 $(TESTS)/glb_g2.c
	./$(NATIVE_BIN) selfhost/gen2_logic_builtin_test.sa $(TESTS)/glb_nat
	./$(TESTS)/glb_g2 > $(TESTS)/glb_g2.out
	./$(TESTS)/glb_nat > $(TESTS)/glb_nat.out
	@printf '3\n3\n121\n2\n6\n' > $(TESTS)/glb_want.out
	@cmp $(TESTS)/glb_g2.out $(TESTS)/glb_want.out || { echo "FAILED: gen2 logic operands of numeric builtins differ from the hand-computed output"; exit 1; }
	@cmp $(TESTS)/glb_nat.out $(TESTS)/glb_want.out || { echo "FAILED: native logic operands of numeric builtins differ from the hand-computed output"; exit 1; }
	@echo "[OK] gen2 and native: and/or/not as operands of len, sx_index and string_eq (hand-computed output)"

# test-struct-logic: and/or/not as struct field values (gen2 hoists them to temporaries)
# on gen2 and native, hand-computed output; a string operand in a logic field stays refused.
test-struct-logic: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/struct_logic_test.sa $(TESTS)/sl_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/sl_g2 $(TESTS)/sl_g2.c
	./$(NATIVE_BIN) selfhost/struct_logic_test.sa $(TESTS)/sl_nat
	./$(TESTS)/sl_g2 > $(TESTS)/sl_g2.out
	./$(TESTS)/sl_nat > $(TESTS)/sl_nat.out
	@printf 'x, and {y}: or\n1\ntail and\n0\n3\n2\n' > $(TESTS)/sl_want.out
	@cmp $(TESTS)/sl_g2.out $(TESTS)/sl_want.out || { echo "FAILED: gen2 struct field logic values differ from the hand-computed output"; exit 1; }
	@cmp $(TESTS)/sl_nat.out $(TESTS)/sl_want.out || { echo "FAILED: native struct field logic values differ from the hand-computed output"; exit 1; }
	@printf 'hold s = "x"\nhold a = 1\nstruct Pair {\n  s,\n  n\n}\nhold q = Pair { s: "k", n: s and a }\nshow q.n\n' > $(TESTS)/sl_bad.sa
	@./$(GEN2) $(TESTS)/sl_bad.sa $(TESTS)/sl_bad_g2.c >/dev/null 2>&1 || true
	@grep -q '#error' $(TESTS)/sl_bad_g2.c || { echo "FAILED: a string operand in a struct field logic value must be refused by gen2"; exit 1; }
	@echo "[OK] gen2 and native: and/or/not as struct field values (hand-computed output); a string operand is refused"

# Optional network integration suite; never a bootstrap prerequisite.
# It is Sayanox only: the Python sayascrape package it used to test was deleted
# on 2026-10-21 together with its `test-scrape` target. sayascrape/crawl.sa is
# the crawler and tools/test-sayacrawl.sh drives it, so the suite lost a
# dependency instead of a feature.
.PHONY: test-network
test-network: test-http-get test-sayacrawl

# test-http-get: http_get(url) network builtin (GET only, http/https only, 1 MB cap,
# 10 s timeout, no redirects). Local server only; native refuses it explicitly.
test-http-get: $(GEN2) $(SEED_MIN_BIN) $(SEED_BIN) $(NATIVE_BIN) tools/sxnet_test
	@CC='$(CC)' ./tools/sxnet_test http-get ./$(GEN2) ./$(SEED_MIN_BIN) ./$(SEED_BIN) ./$(NATIVE_BIN) || { echo "[FAIL] test-http-get"; exit 1; }

# test-sayacrawl: sayascrape/crawl.sa, the Sayanox crawler (gen2 full language, typed
# str helpers). Local server only; exact-output checks for crawl, caps and refusals.
test-sayacrawl: $(GEN2) tools/sxnet_test
	@CC='$(CC)' ./tools/sxnet_test sayacrawl ./$(GEN2) sayascrape/crawl.sa || { echo "[FAIL] test-sayacrawl"; exit 1; }

# test-logic-value: and / or / not as values (hold, show, give, assignment,
# parenthesized groups). Expected output is hand-checked; gen2 and native must match.
LV_WANT := 0\n1\n0\nx and y\n1\n1\n1\n1\n1\n1\n8\n2\n1\n
test-logic-value: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/logic_value_test.sa $(TESTS)/lv_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/lv_g2 $(TESTS)/lv_g2.c
	$(call assert-out,./$(TESTS)/lv_g2,$(LV_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/logic_value_test.sa $(TESTS)/lv_nat || exit 1; \
	  ./$(TESTS)/lv_nat > $(TESTS)/lv_nat.out || exit 1; \
	  ./$(TESTS)/lv_g2 > $(TESTS)/lv_g2.out || exit 1; \
	  cmp $(TESTS)/lv_g2.out $(TESTS)/lv_nat.out || { echo "[FAIL] native logic values differ from gen2"; exit 1; }; \
	  printf 'hold a = 1\nhold v = a and "x"\nshow v\n' > $(TESTS)/lv_bad.sa; \
	  if ./$(NATIVE_BIN) $(TESTS)/lv_bad.sa $(TESTS)/lv_bad_nat >/dev/null 2>&1; then echo "[FAIL] native accepted a string logic operand"; exit 1; fi; \
	fi
	@echo "[OK] and/or/not as values in hold, show, give, assignment and parentheses: gen2 and native agree"

# test-native-generics: make NAME<T> / NAME<A, B> over numbers on native (each T is num).
# Expected output is hand-computed; gen2 (which monomorphises) and native must match.
NG_WANT := 7\n1\n4\n4\n10\n11\n6\n
test-native-generics: $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_generics_test.sa $(TESTS)/ng_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ng_g2 $(TESTS)/ng_g2.c
	$(call assert-out,./$(TESTS)/ng_g2,$(NG_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/native_generics_test.sa $(TESTS)/ng_nat || exit 1; \
	  ./$(TESTS)/ng_nat > $(TESTS)/ng_nat.out || exit 1; \
	  ./$(TESTS)/ng_g2 > $(TESTS)/ng_g2.out || exit 1; \
	  cmp $(TESTS)/ng_g2.out $(TESTS)/ng_nat.out || { echo "[FAIL] native generics differ from gen2"; exit 1; }; \
	  printf 'make f<T>(a) {\n  give a\n}\nshow f(1)\n' > $(TESTS)/ng_untyped.sa; \
	  if ./$(NATIVE_BIN) $(TESTS)/ng_untyped.sa $(TESTS)/ng_untyped >/dev/null 2>&1; then echo "[FAIL] native accepted an untyped generic"; exit 1; fi; \
	  printf 'make f<T>(a: T) -> T {\n  give a\n}\nshow f("x")\n' > $(TESTS)/ng_str.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/ng_str.sa $(TESTS)/ng_str >/dev/null 2>&1 && $(TESTS)/ng_str | grep -qx x || { echo "[FAIL] native refused a string generic"; exit 1; }; \
	  printf 'make f<T>(a: T) -> T {\n  give a\n}\nhold l = f([1, 2])\nshow 1\n' > $(TESTS)/ng_list.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/ng_list.sa $(TESTS)/ng_list >/dev/null 2>&1 && $(TESTS)/ng_list | grep -qx 1 || { echo "[FAIL] native refused a list generic"; exit 1; }; \
	fi
	@echo "[OK] native generics over numbers: make NAME<T> and NAME<A, B>, generic calling generic, gen2 and native agree; untyped generics refused by native (str and list generics: test-native-strgen, test-native-listgen)"

# ---------------------------------------------------------------------------
# test-native-cond: and / or / not, parentheses, in when and while conditions
# on native (added 2026-10-11).  Source: selfhost/native_cond_test.sa.  The
# expected output is hand-computed; gen2 must print it and native must match
# gen2 byte for byte.  seed-min refuses the file.  Word operators as values
# (show a and b) are covered by test-logic-value.
# ---------------------------------------------------------------------------
NCO_WANT := 1\n3\n4\n6\n7\n9\n10\n11\n12\n13\n15\n17\n18\n0\n1\n2\n5\n1\n0
test-native-cond: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/native_cond_test.sa $(TESTS)/nco_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/nco_g2 $(TESTS)/nco_g2.c
	$(call assert-out,./$(TESTS)/nco_g2,$(NCO_WANT))
	./$(SEED_MIN_BIN) selfhost/native_cond_test.sa > $(TESTS)/nco_seed.c
	$(CC) -O2 -o $(TESTS)/nco_seed $(TESTS)/nco_seed.c
	$(call assert-out,./$(TESTS)/nco_seed,$(NCO_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/native_cond_test.sa $(TESTS)/nco_nat || exit 1; \
	  ./$(TESTS)/nco_nat > $(TESTS)/nco_nat.out || exit 1; \
	  ./$(TESTS)/nco_g2 > $(TESTS)/nco_g2.out || exit 1; \
	  cmp $(TESTS)/nco_g2.out $(TESTS)/nco_nat.out || { echo "[FAIL] native and/or/not conditions differ from gen2"; exit 1; }; \
	  printf 'hold s = "ab"\nhold a = 1\nwhen s and a {\n  show 1\n}\n' > $(TESTS)/nco_neg1.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nco_neg1.sa $(TESTS)/nco_neg1 2>&1 | grep -q 'must be a number' || { echo "[FAIL] native accepted a string operand of and"; exit 1; }; \
	  printf 'hold a = 1\nshow a and a\n' > $(TESTS)/nco_neg2.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nco_neg2.sa $(TESTS)/nco_neg2 >/dev/null 2>&1 || { echo "[FAIL] native refused and in a value"; exit 1; }; \
	  ./$(TESTS)/nco_neg2 | grep -qx 1 || { echo "[FAIL] native value of a and a is not 1"; exit 1; }; \
	  printf 'hold a = 1\nwhen a and {\n  show 1\n}\n' > $(TESTS)/nco_neg3.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/nco_neg3.sa $(TESTS)/nco_neg3 2>&1 | grep -q 'missing operand' || { echo "[FAIL] native accepted a dangling and"; exit 1; }; \
	fi
	@echo "[OK] and/or/not and parentheses in when/while conditions: gen2 prints the hand-computed output, seed-min and native match gen2"


# ---------------------------------------------------------------------------
# test-pkgs: the offline package use-path, with no network at all.
#
#   * `sxpkg init` (which makes the folders) plus the Sayanox `sxpkg seed` writes a
#     local registry under .sayanox/registry/ - hello and math samples with
#     mkdir + write_file, no curl/wget, no download;
#   * `sxpkg add math 0.1.0` records the lock, `list`/`search` read it back;
#   * a program uses the seeded package with a plain relative `use`:
#
#         use ".sayanox/registry/math/main.sa"
#
#     and the result compiles and runs identically on seed-min, gen2 and
#     (when native_aot is built) native.
#
# sync/publish/fetch are the online shell commands and are NOT part of this
# path or of any bootstrap target.  The target deliberately uses no `rm`/`cp`:
# it has to stay inside the minimal tool set `make doctor` verifies, so it
# writes over whatever the previous run left behind (the seed overwrites both
# sample packages, and a `test -s` guards the result).
# ---------------------------------------------------------------------------
test-pkgs: sxpkg $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)/pkgs-proj
	cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) init >/dev/null
	cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) seed >/dev/null
	cd $(TESTS)/pkgs-proj && test -s .sayanox/registry/math/main.sa
	cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) add math 0.1.0 >/dev/null
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) list,sxpkg: locked packages\nmath=0.1.0)
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) search math,sxpkg: search math\n  math 0.1.0)
	@printf 'use ".sayanox/registry/math/main.sa"\nshow dbl(21)\nshow sqr(6)\n' > $(TESTS)/pkgs-proj/use_math.sa
	./$(SEED_MIN_BIN) $(TESTS)/pkgs-proj/use_math.sa > $(TESTS)/pkgs-proj/use_sm.c
	$(CC) -O2 -o $(TESTS)/pkgs-proj/use_sm $(TESTS)/pkgs-proj/use_sm.c
	./$(GEN2) $(TESTS)/pkgs-proj/use_math.sa $(TESTS)/pkgs-proj/use_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/pkgs-proj/use_g2 $(TESTS)/pkgs-proj/use_g2.c
	@cd $(TESTS)/pkgs-proj && ./use_sm > use_sm.out && ./use_g2 > use_g2.out && cmp use_sm.out use_g2.out
	$(call assert-out,cd $(TESTS)/pkgs-proj && ./use_g2,42\n36)
	@# offline dependency resolve + install: `calc` declares `deps=math@0.1.0`, so
	@# locking it pulls math in too, and one `install` copies both out of the
	@# repo's registry/ (a plain directory) with their versions and sums checked.
	@rm -rf $(TESTS)/pkgs-deps
	@mkdir -p $(TESTS)/pkgs-deps
	@rm -rf $(TESTS)/pkgs-deps/registry
	@cp -r registry $(TESTS)/pkgs-deps/registry
	@mkdir -p $(TESTS)/pkgs-deps/.sayanox/registry
	@cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) init >/dev/null
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) add calc 0.1.0,sxpkg: locked math 0.1.0 (dependency of calc)\nsxpkg: locked calc 0.1.0\nsxpkg: note: calc has no local registry copy yet (run: sxpkg seed; or sxpkg sync when online))
	@printf '# sx.lock\nversion=1\ncalc=0.1.0\nmath=0.1.0\n' > $(TESTS)/pkgs-deps/lock-want
	cmp $(TESTS)/pkgs-deps/lock-want $(TESTS)/pkgs-deps/sx.lock
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) deps,sxpkg: dependency closure\n  calc 0.1.0\n  math 0.1.0)
	@# A bare `install` does not create destinations: it reports what it could not
	@# write. Empty the project registry first, so the report is about a missing
	@# destination and not about whatever the seed happened to leave there.
	@rm -rf $(TESTS)/pkgs-deps/.sayanox/registry
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) install registry,sxpkg: MISSING calc: cannot write .sayanox/registry/calc/; run sxpkg install-local to create the folders\nsxpkg: MISSING math: cannot write .sayanox/registry/math/; run sxpkg install-local to create the folders\nsxpkg: install FAILED (2 problem(s)))
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) install-local registry,sxpkg: installed calc 0.1.0\nsxpkg: installed math 0.1.0\nsxpkg: install ok)
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) verify,sxpkg: verified calc 0.1.0\nsxpkg: verified math 0.1.0\nsxpkg: verify ok (2 locked packages))
	@# an installed package may `use` its dependency: calc uses math's dbl/sqr
	@printf 'use ".sayanox/registry/calc/main.sa"\nshow dblsqr(3)\nshow sqr(5)\n' > $(TESTS)/pkgs-deps/use_calc.sa
	./$(SEED_MIN_BIN) $(TESTS)/pkgs-deps/use_calc.sa > $(TESTS)/pkgs-deps/use_calc_sm.c
	$(CC) -O2 -o $(TESTS)/pkgs-deps/use_calc_sm $(TESTS)/pkgs-deps/use_calc_sm.c
	./$(GEN2) $(TESTS)/pkgs-deps/use_calc.sa $(TESTS)/pkgs-deps/use_calc_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/pkgs-deps/use_calc_g2 $(TESTS)/pkgs-deps/use_calc_g2.c
	@cd $(TESTS)/pkgs-deps && ./use_calc_sm > uc_sm.out && ./use_calc_g2 > uc_g2.out && cmp uc_sm.out uc_g2.out
	$(call assert-out,cd $(TESTS)/pkgs-deps && ./use_calc_g2,36\n25)
	@# a dependency the lock does not pin is an error, not a silent skip
	@printf '# sx.lock\nversion=1\ncalc=0.1.0\n' > $(TESTS)/pkgs-deps/sx.lock
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) deps,sxpkg: DEP calc needs math@0.1.0 which is not in sx.lock; run: sxpkg add math 0.1.0)
	@printf '# sx.lock\nversion=1\ncalc=0.1.0\nmath=0.2.0\n' > $(TESTS)/pkgs-deps/sx.lock
	$(call assert-out,cd $(TESTS)/pkgs-deps && ../../../$(SXPKG_BIN) deps,sxpkg: DEP calc needs math@0.1.0 but sx.lock has 0.2.0)
	@# offline integrity: the lock is checked against the registry copy (version + pkg.meta sum)
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) verify,sxpkg: verified math 0.1.0\nsxpkg: verify ok (1 locked packages))
	@printf 'make dbl(n) {\n  give n + n + 0\n}\n' > $(TESTS)/pkgs-proj/.sayanox/registry/math/main.sa
	@# a failed verify is still an exact-output assertion here, and now also an
	@# exit status: the `:` keeps assert-out's stdout comparison in charge
	$(call assert-out,cd $(TESTS)/pkgs-proj && { ../../../$(SXPKG_BIN) verify; :; },sxpkg: MISMATCH math: main.sa sums to 115762249 but pkg.meta says 718013937\nsxpkg: verify FAILED (1 problem(s)))
	cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) seed >/dev/null
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) verify,sxpkg: verified math 0.1.0\nsxpkg: verify ok (1 locked packages))
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) sum .sayanox/registry/math/main.sa,sxpkg: sum 718013937 .sayanox/registry/math/main.sa)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/pkgs-proj/use_math.sa $(TESTS)/pkgs-proj/use_nat && \
	  cd $(TESTS)/pkgs-proj && ./use_nat > use_nat.out && cmp use_sm.out use_nat.out || exit 1; \
	fi
	@echo "[OK] offline packages: sxpkg seed writes .sayanox/registry (no network), deps= resolution pulls a package's dependencies into the lock, install-local copies them out of a local registry directory with their sums checked, and use \".sayanox/registry/<pkg>/main.sa\" runs the same on seed-min, gen2 (and native when built)"

# ---------------------------------------------------------------------------
# test-builtin-names: a builtin word only becomes a runtime function when it
# is really *called*.  `hold index = 1` then `sx_index(s, index)` is legal and
# must stay legal: before 2026-10-08 the argument-text rewriter mapped every
# occurrence of `index`, so the second argument was emitted as the runtime
# function itself (`sx_idx(s, sx_idx)`) and gen2 produced C that did not even
# compile -- which is why tools/sxpkg.sa's `search` silently matched nothing.
# seed-min and gen2 must agree on both halves: the variables keep their
# values, and real builtin calls still map to their runtime helpers.
# ---------------------------------------------------------------------------
test-builtin-names: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold index = 1\nhold len = 2\nhold arg = 3\nshow index + len + arg\nhold s = "abc"\nshow sx_index(s, index)\nshow len(s)\nshow concat(s, chr(65))\nhold n = 9\nshow chr(n + 56)\n' > $(TESTS)/bnames.sa
	./$(SEED_MIN_BIN) $(TESTS)/bnames.sa > $(TESTS)/bnames_sm.c
	$(CC) -O2 -o $(TESTS)/bnames_sm $(TESTS)/bnames_sm.c
	./$(GEN2) $(TESTS)/bnames.sa $(TESTS)/bnames_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/bnames_g2 $(TESTS)/bnames_g2.c
	@./$(TESTS)/bnames_sm > $(TESTS)/bnames_sm.out; ./$(TESTS)/bnames_g2 > $(TESTS)/bnames_g2.out; cmp $(TESTS)/bnames_sm.out $(TESTS)/bnames_g2.out
	$(call assert-out,./$(TESTS)/bnames_g2,6\n98\n3\nabcA\nA)
	@echo "[OK] builtin-word names: variables called index/len/arg stay variables, real builtin calls still map (seed-min == gen2)"

# ---------------------------------------------------------------------------
# test-exit-builtin: exit(n) is a real builtin on the Sayanox-written compiler
# (gen1_min/gen2/gen3), added on 2026-10-17 so Sayanox CLI tools can report a
# failure status instead of relying on the C tool that used to do their work.
# It flushes stdout first, does not swallow the status, and stays an ordinary
# expression (`hold code = exit(2)`), matching how bare call statements are
# restricted in this dialect. seed-min and native still reject it.
# ---------------------------------------------------------------------------
.PHONY: test-exit-builtin
test-exit-builtin: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold a = arg(1)\nwhen string_eq(a, "stop") {\n  hold msg = write_out("before-exit\\n")\n  hold code = exit(7)\n}\nshow 42\n' > $(TESTS)/exit_builtin.sa
	./$(GEN2) $(TESTS)/exit_builtin.sa $(TESTS)/exit_builtin.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/exit_builtin $(TESTS)/exit_builtin.c
	$(call assert-out,./$(TESTS)/exit_builtin keep,42)
	@__o=$$(./$(TESTS)/exit_builtin stop); __rc=$$?; \
	 if [ "$$__rc" != 7 ]; then echo "[FAIL] exit(7) produced status $$__rc"; exit 1; fi; \
	 if [ "$$__o" != "before-exit" ]; then echo "[FAIL] stdout was not flushed before exit: $$__o"; exit 1; fi
	@if ./$(SEED_MIN_BIN) $(TESTS)/exit_builtin.sa > $(TESTS)/exit_seed.c 2>$(TESTS)/exit_seed.err; then \
	   echo "[FAIL] seed-min accepted exit() without implementing it"; exit 1; fi
	@grep -q 'call names an unknown function or builtin' $(TESTS)/exit_seed.err \
	  || { echo "[FAIL] seed-min refused exit() without a clear diagnostic"; cat $(TESTS)/exit_seed.err; exit 1; }
	@echo "[OK] exit builtin: status propagates, stdout flushes first, seed-min refuses it with a clear diagnostic"
test-stage2: test-exit-builtin

# ---------------------------------------------------------------------------
# test-path-builtins: read_dir/path_kind/path_size/path_real are the language
# surface that replaced the C LSP directory bridge. gen2 implements them on
# opendir/lstat/realpath; seed-min and native refuse them (the native backend
# has no directory model). read_dir returns newline-separated names, skips "."
# and "..", and caps a directory at 4096 names and 4 MB.
# ---------------------------------------------------------------------------
.PHONY: test-path-builtins
test-path-builtins: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/pathb_dir $(TESTS)/pathb_dir_link
	@mkdir -p $(TESTS)/pathb_dir/sub
	@printf 'x' > $(TESTS)/pathb_dir/a.sa
	@printf 'yy' > $(TESTS)/pathb_dir/sub/b.sa
	@ln -sfn pathb_dir $(TESTS)/pathb_dir_link
	@printf 'hold d = read_dir("$(TESTS)/pathb_dir")\nshow len(d)\nshow path_kind("$(TESTS)/pathb_dir")\nshow path_kind("$(TESTS)/pathb_dir/a.sa")\nshow path_kind("$(TESTS)/pathb_dir/sub/b.sa")\nshow path_kind("$(TESTS)/pathb_dir_link")\nshow path_kind("$(TESTS)/pathb_dir/missing")\nshow path_size("$(TESTS)/pathb_dir/a.sa")\nshow path_size("$(TESTS)/pathb_dir/sub/b.sa")\nshow path_real("$(TESTS)/pathb_dir/../pathb_dir")\nshow len(path_real("$(TESTS)/pathb_dir/missing"))\n' > $(TESTS)/pathb_gen.sa
	./$(GEN2) $(TESTS)/pathb_gen.sa $(TESTS)/pathb_gen.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/pathb_gen $(TESTS)/pathb_gen.c
	@./$(TESTS)/pathb_gen > $(TESTS)/pathb_gen.out
	@test "$$(head -n 1 $(TESTS)/pathb_gen.out)" = 9 \
	  || { echo "[FAIL] read_dir did not return 'sub\\na.sa\\n' (9 bytes)"; cat $(TESTS)/pathb_gen.out; exit 1; }
	@printf '2\n1\n1\n3\n0\n1\n2\n' > $(TESTS)/pathb_gen.want
	@tail -n +2 $(TESTS)/pathb_gen.out | head -n 7 > $(TESTS)/pathb_gen.kinds
	@cmp $(TESTS)/pathb_gen.kinds $(TESTS)/pathb_gen.want \
	  || { echo "[FAIL] path_kind/path_size disagree with the filesystem"; cat $(TESTS)/pathb_gen.out; exit 1; }
	@test "$$(head -n 9 $(TESTS)/pathb_gen.out | tail -n 1)" = "$(CURDIR)/$(TESTS)/pathb_dir" \
	  || { echo "[FAIL] path_real did not canonicalize"; head -n 9 $(TESTS)/pathb_gen.out | tail -n 1; exit 1; }
	@test "$$(head -n 10 $(TESTS)/pathb_gen.out | tail -n 1)" = 0 \
	  || { echo "[FAIL] path_real did not return an empty string for a missing path"; exit 1; }
	@if ./$(SEED_MIN_BIN) $(TESTS)/pathb_gen.sa > $(TESTS)/pathb_gen_seed.c 2>$(TESTS)/pathb_gen_seed.err; then \
	   echo "[FAIL] seed-min accepted the path builtins without implementing them"; exit 1; fi
	@grep -q 'call names an unknown function or builtin' $(TESTS)/pathb_gen_seed.err \
	  || { echo "[FAIL] seed-min refused the path builtins without a clear diagnostic"; cat $(TESTS)/pathb_gen_seed.err; exit 1; }
	@echo "[OK] path builtins: read_dir listing, lstat kinds (file/dir/symlink/missing), sizes, realpath; seed-min refuses them"
test-stage2: test-exit-builtin test-path-builtins test-proc-builtins test-comment-quotes test-native-primitives

# ---------------------------------------------------------------------------
# test-proc-builtins: spawn / child_send / child_recv / child_line /
# child_close and make_dir / make_link / remove_path are the language surface
# that replaced the C LSP test client. gen2 implements them on fork/exec and
# pipes; seed-min refuses them, exactly like the directory builtins. A child is
# a real framed session: two requests, two answers, one clean exit.
# ---------------------------------------------------------------------------
.PHONY: test-proc-builtins
test-proc-builtins: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/proc_frame_dir
	./$(GEN2) selfhost/proc_frame_server.sa $(TESTS)/proc_frame_server.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/proc_frame_server $(TESTS)/proc_frame_server.c
	./$(GEN2) selfhost/proc_frame_client.sa $(TESTS)/proc_frame_client.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/proc_frame_client $(TESTS)/proc_frame_client.c
	@./$(TESTS)/proc_frame_client '$(CURDIR)/$(TESTS)/proc_frame_server' '$(CURDIR)/$(TESTS)/proc_frame_dir' > $(TESTS)/proc_frame.out
	@printf 'spawn, child_send, child_line, child_recv, child_close: one framed session, two answers, clean exit\nmake_dir, make_link, remove_path and dead handles behave as documented\n' > $(TESTS)/proc_frame.want
	@cmp $(TESTS)/proc_frame.want $(TESTS)/proc_frame.out \
	  || { echo "[FAIL] process builtins: unexpected client output"; cat $(TESTS)/proc_frame.out; exit 1; }
	@printf 'hold h = spawn("x")\nshow h\nhold n = make_dir("x")\nshow n\n' > $(TESTS)/proc_frame_seed.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/proc_frame_seed.sa > /dev/null 2>$(TESTS)/proc_frame_seed.err; then \
	   echo "[FAIL] seed-min accepted the process builtins without implementing them"; exit 1; fi
	@grep -q 'call names an unknown function or builtin' $(TESTS)/proc_frame_seed.err \
	  || { echo "[FAIL] seed-min refused the process builtins without a clear diagnostic"; cat $(TESTS)/proc_frame_seed.err; exit 1; }
	@echo "[OK] process builtins: spawn and a framed child session, make_dir/make_link/remove_path, dead handles; seed-min refuses them"

# ---------------------------------------------------------------------------
# test-comment-quotes: the `make` signature pre-pass did not know about //
# comments -- the comment-tracking branch in that loop is dead code (its flag
# is never set to 1) -- so a double quote inside a comment toggled string
# mode. One odd quote made every later `make` lose its typed parameter list,
# and the naive scanner that takes over emitted `double a, double num, ...`
# from the text of `a: num, b: num`. The generated C then stopped compiling
# far from the cause. Found while porting tools/sxpkg.sa; pinned here.
# ---------------------------------------------------------------------------
test-comment-quotes: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@rm -rf $(TESTS)/cq
	@mkdir -p $(TESTS)/cq
	@printf '// a comment with one " quote inside it\nmake add2(a: num, b: num) -> num {\n  give a + b\n}\nhold r = add2(1, 2)\nshow r\n' > $(TESTS)/cq/odd.sa
	@./$(GEN2) $(TESTS)/cq/odd.sa $(TESTS)/cq/odd.c >/dev/null
	@grep -q 'static double add2(double a, double b);' $(TESTS)/cq/odd.c \
	  || { echo "[FAIL] a double quote inside a // comment broke the signature pre-pass"; \
	       head -3 $(TESTS)/cq/odd.c; exit 1; }
	@if grep -qE 'double str[,)]' $(TESTS)/cq/odd.c; then \
	   echo "[FAIL] a double quote inside a // comment mangled the parameter list"; exit 1; fi
	@if grep -q 'double num' $(TESTS)/cq/odd.c; then \
	   echo "[FAIL] the naive parameter scanner took over for add2"; exit 1; fi
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/cq/odd $(TESTS)/cq/odd.c
	$(call assert-out,./$(TESTS)/cq/odd,3)
	@# the file that exposed it: tools/sxpkg.sa carries such a comment
	@./$(GEN2) tools/sxpkg.sa $(TESTS)/cq/sxpkg.c >/dev/null
	@if grep -qE 'double str[,)]' $(TESTS)/cq/sxpkg.c; then \
	   echo "[FAIL] tools/sxpkg.c was generated with mangled signatures"; exit 1; fi
	@grep -q 'static char \*toml_field(char \*text, char \*key);' $(TESTS)/cq/sxpkg.c \
	  || { echo "[FAIL] tools/sxpkg.c lost its typed signatures"; exit 1; }
	@# seed-min runs its own pre-pass; both compilers must agree
	@./$(SEED_MIN_BIN) $(TESTS)/cq/odd.sa > $(TESTS)/cq/odd_seed.c
	@grep -q 'static double add2(double a, double b){' $(TESTS)/cq/odd_seed.c \
	  || { echo "[FAIL] seed-min and gen2 disagree on a quote inside a // comment"; exit 1; }
	@grep 'static double add2' $(TESTS)/cq/odd.c | head -1
	@grep 'static char \*toml_field' $(TESTS)/cq/sxpkg.c | head -1
	@echo "[OK] a double quote inside a // comment no longer breaks the signature pre-pass; gen2 and seed-min agree"

# ---------------------------------------------------------------------------
# test-native-primitives: bit_and / bit_or / bit_xor / bit_not / shl / shr,
# write_bytes and bytes_f64 are the primitive surface that
# selfhost/native_aot.c needs before it can be rewritten in Sayanox. gen2
# implements them; seed-min refuses them, like every other late builtin.
#
# The gate does not stop at arithmetic: selfhost/native_primitives.sa writes a
# complete static x86-64 ELF executable out of a byte buffer plus the bitwise
# helpers, and the gate then RUNS that file.  A byte buffer that the kernel
# loads and that exits 42 is the real proof, not a printout.
# ---------------------------------------------------------------------------
.PHONY: test-native-primitives
test-native-primitives: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@rm -f $(TESTS)/native_primitives.elf $(TESTS)/native_primitives.bin
	./$(GEN2) selfhost/native_primitives.sa $(TESTS)/native_primitives.c >/dev/null
	@if grep -q '#error' $(TESTS)/native_primitives.c; then echo "[FAIL] native primitives: #error in the output"; exit 1; fi
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/native_primitives $(TESTS)/native_primitives.c
	@./$(TESTS)/native_primitives '$(CURDIR)/$(TESTS)/native_primitives.elf' '$(CURDIR)/$(TESTS)/native_primitives.bin' > $(TESTS)/native_primitives.out
	@printf 'bit_and bit_or bit_xor bit_not shl shr bytes_f64 write_bytes: checked, and the emitted ELF exits 42\n' > $(TESTS)/native_primitives.want
	@cmp $(TESTS)/native_primitives.want $(TESTS)/native_primitives.out \
	  || { echo "[FAIL] native primitives: unexpected program output"; cat $(TESTS)/native_primitives.out; exit 1; }
	@# the byte buffer is a real ELF: magic, x86-64 machine id, exact size
	@test "$$(od -An -tx1 -N4 $(TESTS)/native_primitives.elf | tr -d ' \n')" = 7f454c46 \
	  || { echo "[FAIL] native primitives: the emitted file is not an ELF"; exit 1; }
	@test "$$(od -An -tx1 -j18 -N2 $(TESTS)/native_primitives.elf | tr -d ' \n')" = 3e00 \
	  || { echo "[FAIL] native primitives: the emitted ELF is not x86-64"; exit 1; }
	@test "$$(wc -c < $(TESTS)/native_primitives.elf)" = 132 \
	  || { echo "[FAIL] native primitives: the emitted ELF has the wrong size"; exit 1; }
	@chmod +x $(TESTS)/native_primitives.elf
	@./$(TESTS)/native_primitives.elf; __rc=$$?; \
	 if [ "$$__rc" != 42 ]; then echo "[FAIL] native primitives: the emitted ELF exited $$__rc, want 42"; exit 1; fi
	@printf 'hold a = bit_and(12, 10)\nshow a\nhold b = write_bytes("x", [])\nshow b\nhold c = bytes_f64([], 1.5)\nshow len(c)\nhold d = shl(1, 3)\nshow d\nhold e = shr(8, 1)\nshow e\n' > $(TESTS)/native_primitives_seed.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/native_primitives_seed.sa > /dev/null 2>$(TESTS)/native_primitives_seed.err; then \
	   echo "[FAIL] seed-min accepted the native primitives without implementing them"; exit 1; fi
	@grep -q 'call names an unknown function or builtin' $(TESTS)/native_primitives_seed.err \
	  || { echo "[FAIL] seed-min refused the native primitives without a clear diagnostic"; cat $(TESTS)/native_primitives_seed.err; exit 1; }
	@echo "[OK] native primitives: bitwise ops, write_bytes and bytes_f64; a Sayanox byte buffer emits a static x86-64 ELF that exits 42; seed-min refuses them"

# ---------------------------------------------------------------------------
# test-stage2: the Stage-2 slice on gen2 beyond the string walk — the word
# operators `and` / `or` / `not` with `not` binding looser than a comparison,
# the boolean literals `true` / `false`, `for` over a list (a variable, a list
# literal, a call returning a list or a string), nested loops, break/continue
# in a list loop, `elif` chains and `and` inside a `while` condition.
#
# `and` / `or` short-circuit because they lower to C's && and ||: the two
# `10 % 0` guards below would abort with `division by zero` if the right-hand
# side were evaluated, so reaching the end of the program proves it.
# ---------------------------------------------------------------------------
test-stage2: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'make mkl() -> list {\n  hold r = [4, 5]\n  give r\n}\nmake mks() -> str {\n  give "pq"\n}\nmake isone(n: num) -> num {\n  when not n == 5 {\n    give 1\n  }\n  give 0\n}\nhold a = 1\nhold b = 0\nhold s = "hi"\nhold xs = [7, 8]\nhold ys = [1, 2]\nshow true\nshow false\nwhen a == 1 and b == 0 {\n  show 1\n}\nwhen a == 2 or b == 0 {\n  show 2\n}\nwhen not a == 2 and b == 0 {\n  show 3\n}\nwhen not a == 1 or b == 9 {\n  show 4\n}\nwhen not s == "no" {\n  show 5\n}\nwhen not (a == 2) {\n  show 6\n}\nwhen a == 2 and 10 %% 0 == 0 {\n  show 7\n}\nwhen a == 1 or 10 %% 0 == 0 {\n  show 8\n}\nshow isone(4)\nshow isone(5)\nfor v in xs {\n  show v\n}\nfor v in [3, 4] {\n  show v\n}\nfor c in "ab" {\n  show c\n}\nfor c in mks() {\n  show c\n}\nfor v in mkl() {\n  show v\n}\nfor p in xs {\n  for q in ys {\n    show p\n    show q\n  }\n}\nfor v in xs {\n  when v == 7 {\n    continue\n  }\n  show v\n}\nfor v in xs {\n  when v == 8 {\n    break\n  }\n  show v\n}\nhold k = 0\nwhen a == 9 {\n  hold k = 1\n} elif a == 1 {\n  hold k = 2\n} otherwise {\n  hold k = 3\n}\nshow k\nhold m = 0\nwhile m < 3 and a == 1 {\n  hold m = m + 1\n}\nshow m\n' > $(TESTS)/s2.sa
	./$(GEN2) $(TESTS)/s2.sa $(TESTS)/s2.c >/dev/null
	@if grep -q '#error' $(TESTS)/s2.c; then echo "[FAIL] stage2: #error in the output"; exit 1; fi
	$(CC) -O2 -o $(TESTS)/s2 $(TESTS)/s2.c
	$(call assert-out,./$(TESTS)/s2,1\n0\n1\n2\n3\n5\n6\n8\n1\n0\n7\n8\n3\n4\na\nb\np\nq\n4\n5\n7\n1\n7\n2\n8\n1\n8\n2\n8\n7\n2\n3)
	@# `not` binds looser than a comparison: `not a == 2 and b == 0` is
	@# `!(a == 2) && b == 0`, not C's `(!a) == 2 && b == 0`
	@grep -q 'if (!(a == 2.0) && b == 0.0) {' $(TESTS)/s2.c
	@grep -q 'if (!(sx_eq(s, "no") == 1.0)) {' $(TESTS)/s2.c
	@grep -q 'if (!(a == 1.0) || b == 9.0) {' $(TESTS)/s2.c
	@# `and` / `or` keep C precedence (&& binds tighter than ||) and short-circuit
	@grep -q 'if (a == 1.0 && b == 0.0) {' $(TESTS)/s2.c
	@grep -q 'if (a == 2.0 || b == 0.0) {' $(TESTS)/s2.c
	@grep -q 'while (m < 3.0 && a == 1.0) {' $(TESTS)/s2.c
	@# `for v in [3, 4]`: the list literal is bound to a hidden variable first
	@grep -q 'sx_list \*__sx_fv' $(TESTS)/s2.c
	@grep -q 'for (double __sx_ix = 0.0; __sx_ix < sx_llen(__sx_fv' $(TESTS)/s2.c
	@# `for c in "ab"` and `for c in mks()`: a string source, byte by byte
	@grep -q 'c = sx_chr(sx_idx(__sx_fv' $(TESTS)/s2.c
	@# every call must see a prototype
	@$(CC) -O2 -Wall -o $(TESTS)/s2-w $(TESTS)/s2.c 2>$(TESTS)/s2.warn
	@if grep -q 'implicit declaration' $(TESTS)/s2.warn; then echo "[FAIL] stage2: a call without a prototype"; exit 1; fi
	@# the same program through the seed-built compiler must agree byte for byte
	./$(GEN1_MIN) $(TESTS)/s2.sa $(TESTS)/s2_g1.c >/dev/null
	@diff $(TESTS)/s2.c $(TESTS)/s2_g1.c >/dev/null || { echo "[FAIL] stage2: gen1_min output differs"; exit 1; }
	$(CC) -O2 -o $(TESTS)/s2_g1 $(TESTS)/s2_g1.c
	$(call assert-out,./$(TESTS)/s2_g1,1\n0\n1\n2\n3\n5\n6\n8\n1\n0\n7\n8\n3\n4\na\nb\np\nq\n4\n5\n7\n1\n7\n2\n8\n1\n8\n2\n8\n7\n2\n3)
	./$(SEED_MIN_BIN) $(TESTS)/s2.sa > $(TESTS)/s2_seed.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/s2_seed $(TESTS)/s2_seed.c
	./$(TESTS)/s2_seed > $(TESTS)/s2_seed.out
	./$(TESTS)/s2 > $(TESTS)/s2_gen2.out
	cmp $(TESTS)/s2_seed.out $(TESTS)/s2_gen2.out
	@# native names the forms it does not have instead of miscompiling them
	@if [ -x $(NATIVE_BIN) ]; then \
	  printf 'hold xs = [1, 2]\nfor v in xs {\n  show v\n}\n' > $(TESTS)/s2_for.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_for.sa $(TESTS)/s2_for || { echo "[FAIL] native refused for over a list"; exit 1; }; \
	  ./$(TESTS)/s2_for | tr '\n' ' ' | grep -qx '1 2 ' || { echo "[FAIL] native for over a list printed the wrong result"; exit 1; }; \
	  printf 'hold a = 1\nhold b = 0\nwhen a == 1 and b == 0 {\n  show 1\n}\n' > $(TESTS)/s2_and.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_and.sa $(TESTS)/s2_and || { echo "[FAIL] native refused and in a when condition"; exit 1; }; \
	  ./$(TESTS)/s2_and | grep -qx 1 || { echo "[FAIL] native and in a when condition printed the wrong result"; exit 1; }; \
	  printf 'hold a = 1\nwhen not (a == 2) {\n  show 1\n}\n' > $(TESTS)/s2_not.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_not.sa $(TESTS)/s2_not || { echo "[FAIL] native refused not in a when condition"; exit 1; }; \
	  ./$(TESTS)/s2_not | grep -qx 1 || { echo "[FAIL] native not in a when condition printed the wrong result"; exit 1; }; \
	  printf 'show true\nshow false\n' > $(TESTS)/s2_true.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_true.sa $(TESTS)/s2_true || { echo "[FAIL] native refused show true"; exit 1; }; \
	  ./$(TESTS)/s2_true | tr '\n' ' ' | grep -qx '1 0 ' || { echo "[FAIL] native show true/false printed the wrong result"; exit 1; }; \
	  echo "  native runs true/false and for; and/not in conditions run (test-native-lang)"; \
	else \
	  echo "[stage2] native rejection: skipped (native_aot is not built here)"; \
	fi
	@echo "[OK] Stage-2 language: and/or/not precedence and short-circuit, not binds looser than a comparison, true/false, for over a list variable/literal/call, nested loops, break/continue, elif chains; gen2 == gen1_min; seed subset tested separately; native supports Stage-2"

# ---------------------------------------------------------------------------
# test-for-str: the one Stage-2 language slice added on gen2 (2026-10-08).
#
#     hold s = "abc"
#     for c in s {          # c is the one-byte string at each index
#       show c
#     }
#
# A declared string is walked one byte at a time (sx_index), in the same
# `for NAME in EXPR {` form as the list walk. The counter is a new name per
# loop, or a name that is already a string (rebinding), never a number or a
# list. seed-min and native do not have the statement and must say so.
# Bytes, not characters: "é" is two iterations. Pinned here on gen2 (and the
# rejections on seed-min and native when native_aot is built).
# ---------------------------------------------------------------------------
test-for-str: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold word = "sayanox"\nhold vowels = 0\nhold other = 0\nfor ch in word {\n  when string_eq(ch, "a") == 1 || string_eq(ch, "e") == 1 || string_eq(ch, "i") == 1 || string_eq(ch, "o") == 1 || string_eq(ch, "u") == 1 {\n    hold vowels = vowels + 1\n  } otherwise {\n    hold other = other + 1\n  }\n}\nshow vowels\nshow other\n' > $(TESTS)/fs_vowels.sa
	./$(GEN2) $(TESTS)/fs_vowels.sa $(TESTS)/fs_vowels.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fs_vowels $(TESTS)/fs_vowels.c
	$(call assert-out,./$(TESTS)/fs_vowels,3\n4)
	@# break and continue inside the string loop; `hello world` stops at the first o
	@printf 'hold s = "hello world"\nhold n = 0\nfor c in s {\n  when string_eq(c, " ") == 1 {\n    continue\n  }\n  hold n = n + 1\n  when string_eq(c, "o") == 1 {\n    break\n  }\n}\nshow n\n' > $(TESTS)/fs_brk.sa
	./$(GEN2) $(TESTS)/fs_brk.sa $(TESTS)/fs_brk.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fs_brk $(TESTS)/fs_brk.c
	$(call assert-out,./$(TESTS)/fs_brk,5)
	@# an empty string runs no body; nested loops; rebinding the same counter name
	@printf 'hold e = ""\nfor c in e {\n  show "never"\n}\nhold s = "ab"\nfor c in s {\n  for d in s {\n    show concat(c, d)\n  }\n}\nfor c in s {\n  show c\n}\nshow "end"\n' > $(TESTS)/fs_nest.sa
	./$(GEN2) $(TESTS)/fs_nest.sa $(TESTS)/fs_nest.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fs_nest $(TESTS)/fs_nest.c
	$(call assert-out,./$(TESTS)/fs_nest,aa\nab\nba\nbb\na\nb\nend)
	@# bytes, not characters: "é" is two UTF-8 bytes, so two iterations
	@printf 'hold u = "\303\251"\nhold n = 0\nfor b in u {\n  hold n = n + 1\n}\nshow n\n' > $(TESTS)/fs_bytes.sa
	./$(GEN2) $(TESTS)/fs_bytes.sa $(TESTS)/fs_bytes.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fs_bytes $(TESTS)/fs_bytes.c
	$(call assert-out,./$(TESTS)/fs_bytes,2)
	@# the clear diagnostics (gen2 writes them as #error lines)
	@printf 'hold x = 0\nfor c in x {\n  show c\n}\n' > $(TESTS)/fs_num.sa
	./$(GEN2) $(TESTS)/fs_num.sa $(TESTS)/fs_num.c >/dev/null 2>&1 || true
	@grep -q "'x' is not a list or a string" $(TESTS)/fs_num.c
	@printf 'hold n = 5\nhold s = "ab"\nfor n in s {\n  show n\n}\n' > $(TESTS)/fs_clash.sa
	./$(GEN2) $(TESTS)/fs_clash.sa $(TESTS)/fs_clash.c >/dev/null 2>&1 || true
	@grep -q "'n' is already a number or a list" $(TESTS)/fs_clash.c
	@printf 'hold c = [1, 2]\nhold s = "ab"\nfor c in s {\n  show c\n}\n' > $(TESTS)/fs_listclash.sa
	./$(GEN2) $(TESTS)/fs_listclash.sa $(TESTS)/fs_listclash.c >/dev/null 2>&1 || true
	@grep -q "'c' is already a number or a list" $(TESTS)/fs_listclash.c
	@# Seed-min matches gen2 on named string-source iteration
	@for case in vowels brk nest bytes; do \
	  ./$(SEED_MIN_BIN) $(TESTS)/fs_$$case.sa > $(TESTS)/fs_$${case}_seed.c || exit 1; \
	  $(CC) -O2 -o $(TESTS)/fs_$${case}_seed $(TESTS)/fs_$${case}_seed.c || exit 1; \
	  ./$(TESTS)/fs_$${case}_seed > $(TESTS)/fs_$${case}_seed.out || exit 1; \
	  ./$(TESTS)/fs_$$case > $(TESTS)/fs_$${case}_gen2.out || exit 1; \
	  cmp $(TESTS)/fs_$${case}_seed.out $(TESTS)/fs_$${case}_gen2.out || exit 1; \
	done
	@# native (when built) runs for over a string (since 2026-10-11, test-native-lang)
	@if [ -x $(NATIVE_BIN) ]; then \
	  printf 'hold word = "abc"\nfor ch in word {\n  show ch\n}\n' > $(TESTS)/fs_nat.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/fs_nat.sa $(TESTS)/fs_native || exit 1; \
	  ./$(TESTS)/fs_native | tr '\n' ' ' | grep -qx 'a b c ' || { echo "[FAIL] native for over a string printed the wrong result"; exit 1; }; \
	  echo "[stage2] native runs for over a string"; \
	else \
	  echo "[stage2] native rejection: skipped (native_aot is not built here)"; \
	fi
	@# generics: gen2 monomorphises one or more type parameters; native has none
	@printf 'make pair<T>(a: T, b: str) -> T {\n  give a\n}\nshow pair(1, "x")\n' > $(TESTS)/fs_pair.sa
	./$(GEN2) $(TESTS)/fs_pair.sa $(TESTS)/fs_pair.c >/dev/null 2>&1 || true
	@grep -q "must be written with type parameters used by every parameter" $(TESTS)/fs_pair.c
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/fs_pair.sa $(TESTS)/fs_pair_nat 2>&1 | grep -q 'type parameters used by every parameter'; then :; \
	  else echo "[FAIL] native did not reject make NAME<...>"; exit 1; fi; \
	fi
	@echo "[OK] Stage-2 slice: for c in <string> on gen2 (vowels, break/continue, empty, nested, rebinding, bytes); seed-min matches variable-source cases; native runs it"

# ---------------------------------------------------------------------------
# test-registry-sums: every repository package carries a `sum=` line in its
# pkg.meta equal to `sxpkg sum` of its main.sa (the offline integrity sum that
# `sxpkg verify` checks; see docs/REGISTRY.md). Pure shell + the sxpkg binary.
# ---------------------------------------------------------------------------
test-registry-sums: sxpkg
	@for p in hello math strings; do \
	  want=""; \
	  while IFS= read -r l; do case "$$l" in sum=*) want=$${l#sum=};; esac; done < registry/$$p/pkg.meta; \
	  got=$$(./$(SXPKG_BIN) sum registry/$$p/main.sa); \
	  if [ -n "$$want" ] && [ "$$got" = "sxpkg: sum $$want registry/$$p/main.sa" ]; then \
	    echo "  ok registry/$$p sum=$$want"; \
	  else echo "[FAIL] registry/$$p: pkg.meta sum '$$want' != main.sa ($$got)"; exit 1; fi; \
	done
	@echo "[OK] repository registry: every pkg.meta sum= matches its main.sa"

# ---------------------------------------------------------------------------
# test-gen2-gaps: the three gen2 gaps that were recorded as divergences on
# 2026-10-08 and are now fixed (docs/STATUS.md):
#   * `len(NAME)` inside a range bound: `for i in 0..len(xs)` (list) and
#     `for j in 0..len(s)` (string) emit sx_llen / sx_len, not a bare `len`;
#   * `} else when COND {`, `} else if COND {` and `} otherwise when COND {`
#     are the same chain as `elif` (they used to emit a second `else` level);
#   * the chain links into a plain `} else {` / `} otherwise {` as before.
# Seed-min and native refuse the chain forms (they are gen2-only).
# ---------------------------------------------------------------------------
test-gen2-gaps: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold xs = [1, 2, 3, 4]\nhold s = "abcd"\nfor i in 0..len(xs) {\n  show i\n}\nfor j in 0..len(s) {\n  show j\n}\n' > $(TESTS)/gg_len.sa
	./$(GEN2) $(TESTS)/gg_len.sa $(TESTS)/gg_len.c >/dev/null
	@grep -q 'sx_llen(' $(TESTS)/gg_len.c && grep -q 'sx_len(s)' $(TESTS)/gg_len.c
	$(CC) -O2 -o $(TESTS)/gg_len $(TESTS)/gg_len.c
	$(call assert-out,./$(TESTS)/gg_len,0\n1\n2\n3\n0\n1\n2\n3)
	@printf 'hold n = 0\nwhile n < 6 {\n  when n == 0 {\n    show 100\n  } else when n == 1 {\n    show 101\n  } else if n == 2 {\n    show 102\n  } otherwise when n == 3 {\n    show 103\n  } else {\n    show 109\n  }\n  when n >= 4 {\n    when n == 4 {\n      show 7\n    } else when n == 5 {\n      show 8\n    }\n  }\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/gg_chain.sa
	./$(GEN2) $(TESTS)/gg_chain.sa $(TESTS)/gg_chain.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gg_chain $(TESTS)/gg_chain.c
	$(call assert-out,./$(TESTS)/gg_chain,100\n101\n102\n103\n109\n7\n109\n8\ndone)
	@# `==` / `!=` between declared strings is a strcmp, not an address compare:
	@# two equal strings built at run time (concat) must compare equal
	@printf 'hold s = "ab"\nhold t = concat("a", "b")\nhold u = concat("a", "c")\nwhen t == s {\n  show 1\n} otherwise {\n  show 0\n}\nwhen t != u {\n  show 2\n} otherwise {\n  show 3\n}\nwhen s == "ab" {\n  show 4\n}\nwhen u == "ab" {\n  show 5\n} otherwise {\n  show 6\n}\nwhen string_eq(t, s) == 1 {\n  show 7\n}\n' > $(TESTS)/gg_streq.sa
	./$(GEN2) $(TESTS)/gg_streq.sa $(TESTS)/gg_streq.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gg_streq $(TESTS)/gg_streq.c
	$(call assert-out,./$(TESTS)/gg_streq,1\n2\n4\n6\n7)
	@# `%` inside a builtin-call argument: sx_mod(L, R) with the same operand rule as
	@# the condition rewrite (x * m % 10 is (x * m) % 10); % in a string literal is text
	@printf 'hold m = 17\nhold d = chr(48 + m %% 10)\nshow d\nshow concat("x", chr(48 + m %% 10))\nhold x = 3\nhold e = chr(48 + x * m %% 10)\nshow e\nshow concat("100%%", chr(50 + m %% 3))\nhold r = concat("v=", chr(48 + m / 2 %% 10))\nshow r\n' > $(TESTS)/gg_pct.sa
	./$(GEN2) $(TESTS)/gg_pct.sa $(TESTS)/gg_pct.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gg_pct $(TESTS)/gg_pct.c
	$(call assert-out,./$(TESTS)/gg_pct,7\nx7\n1\n100%4\nv=8)
	@./$(SEED_MIN_BIN) $(TESTS)/gg_pct.sa > $(TESTS)/gg_pct_sm.c && $(CC) -O2 -o $(TESTS)/gg_pct_sm $(TESTS)/gg_pct_sm.c && ./$(TESTS)/gg_pct_sm > $(TESTS)/gg_pct_sm.out && ./$(TESTS)/gg_pct > $(TESTS)/gg_pct_g2.out && cmp $(TESTS)/gg_pct_sm.out $(TESTS)/gg_pct_g2.out
	@# string ordering (< <= > >=) and == / != compare by content: gen2 and seed-min agree
	@printf 'hold s = "ab"\nhold t = concat("a", "b")\nhold u = concat("a", "c")\nhold n = 3\nwhen t == s {\n  show 1\n}\nwhen t != u {\n  show 2\n}\nwhen s < u {\n  show 3\n}\nwhen u < s {\n  show 4\n} otherwise {\n  show 5\n}\nwhen s <= t {\n  show 6\n}\nwhen u >= t {\n  show 7\n}\nwhen u > t {\n  show 8\n}\nwhen t > u {\n  show 9\n} otherwise {\n  show 10\n}\nwhen n < 5 {\n  show 11\n}\nwhen n >= 3 {\n  show 12\n}\nwhen t < "b" {\n  show 13\n}\nwhen "a" < u {\n  show 14\n} otherwise {\n  show 15\n}\n' > $(TESTS)/gg_ord.sa
	./$(GEN2) $(TESTS)/gg_ord.sa $(TESTS)/gg_ord.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gg_ord $(TESTS)/gg_ord.c
	$(call assert-out,./$(TESTS)/gg_ord,1\n2\n3\n5\n6\n7\n8\n10\n11\n12\n13\n14)
	@./$(SEED_MIN_BIN) $(TESTS)/gg_ord.sa > $(TESTS)/gg_ord_sm.c && $(CC) -O2 -o $(TESTS)/gg_ord_sm $(TESTS)/gg_ord_sm.c && ./$(TESTS)/gg_ord_sm > $(TESTS)/gg_ord_sm.out && ./$(TESTS)/gg_ord > $(TESTS)/gg_ord_g2.out && cmp $(TESTS)/gg_ord_sm.out $(TESTS)/gg_ord_g2.out
	@# a string against a number is an error on seed-min and native; native ordering == gen2
	@printf 'hold s = "ab"\nhold n = 3\nwhen s < n {\n  show 1\n}\n' > $(TESTS)/gg_ordmix.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/gg_ordmix.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted string < number"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/gg_ord.sa $(TESTS)/gg_ordnat >/dev/null 2>&1 && ./$(TESTS)/gg_ordnat > $(TESTS)/gg_ord_nat.out && cmp $(TESTS)/gg_ord_nat.out $(TESTS)/gg_ord_g2.out || { echo "[FAIL] native string ordering differs from gen2"; exit 1; }; \
	  if ./$(NATIVE_BIN) $(TESTS)/gg_ordmix.sa $(TESTS)/gg_ordmixnat >/dev/null 2>&1; then echo "[FAIL] native accepted string < number"; exit 1; fi; \
	fi
	@# the chain forms: seed-min, gen2 and native agree
	./$(SEED_MIN_BIN) $(TESTS)/gg_chain.sa > $(TESTS)/gg_chain_seed.c
	$(CC) -O2 -o $(TESTS)/gg_chain_seed $(TESTS)/gg_chain_seed.c
	./$(TESTS)/gg_chain_seed > $(TESTS)/gg_chain_seed.out
	./$(TESTS)/gg_chain > $(TESTS)/gg_chain_g2.out
	cmp $(TESTS)/gg_chain_seed.out $(TESTS)/gg_chain_g2.out
	@# native runs the chain forms too (they landed with elif): it must match gen2
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/gg_chain.sa $(TESTS)/gg_nat || exit 1; \
	  ./$(TESTS)/gg_nat > $(TESTS)/gg_nat.out || exit 1; \
	  ./$(TESTS)/gg_chain > $(TESTS)/gg_chain_g2.out || exit 1; \
	  cmp $(TESTS)/gg_chain_g2.out $(TESTS)/gg_nat.out || { echo "[FAIL] native else-if chain differs from gen2"; exit 1; }; \
	fi
	@echo "[OK] gen2 gaps: len() in a range bound (list and string), string == / != on runtime strings, else when / else if / otherwise when chains (incl. nested) on gen2, % inside builtin-call arguments (sx_mod, same as seed-min); seed-min and native match the chains"

# ---------------------------------------------------------------------------
# test-doc-claims: no document may advertise an entry point that is not in the
# repository. There is no `stage2:` target, no selfhost/bootstrap_production.sh,
# no bootstrap_full_selfhost.sh and no bootstrap_full_language_selfhost.sh.
#
# On 2026-10-21 the placeholder scaffolding was deleted rather than kept: the
# 93-byte stage2_template.c PLACEHOLDER, its 11-byte selfhost/stage2_src/,
# the 30-line sxc_full.c and sxc_full_minimal.c toy, the restore_stage2.sh
# wrapper that could only exit 1 because its inputs were gone, the
# restore_stage2_template.sh / restore_sxc.sh / restore_sxc_full.sh restorers
# whose bundles were dead, and selfhost/sx, a CLI for the absent host. Those
# files were not evidence of anything; they were files that had to stay
# identical to keep a claim true. This target now asserts they stay gone, so a
# Stage-2 host cannot reappear as a placeholder, and the documents that name
# the missing entry points still carry their banner.
#
# If a real Stage-2 host ever lands, this target fails and points at the docs
# that need updating -- that is the intent.
#
# docs/FULL_LANGUAGE_SELFHOST.md and docs/STATUS.md are exempt from the banner
# check on purpose: those two are where the absence is RECORDED, so they have to
# name the missing entry points to say they are missing. Every other document
# that names one must carry the banner.
# ---------------------------------------------------------------------------
.PHONY: test-doc-claims
test-doc-claims:
	@for f in selfhost/stage2_template.c selfhost/sxc_full.c selfhost/sxc_full_minimal.c \
	          selfhost/restore_stage2.sh selfhost/restore_sxc.sh selfhost/restore_sxc_full.sh \
	          selfhost/restore_stage2_template.sh selfhost/sx selfhost/stage2_src selfhost/stage2; do \
	  test ! -e "$$f" \
	    || { echo "[FAIL] the deleted Stage-2 placeholder $$f is back: there is no Stage-2 host, so nothing may pretend to be one -- see docs/FULL_LANGUAGE_SELFHOST.md"; exit 1; }; \
	done
	@if grep -q '^stage2:' Makefile; then \
	  echo "[FAIL] a stage2: target exists now: update the docs and this target"; exit 1; \
	fi
	@miss=0; \
	for f in $$(grep -rl -e 'make stage2' -e 'bootstrap_production.sh' -e 'bootstrap_full_selfhost.sh' -e 'bootstrap_full_language_selfhost.sh' docs --include='*.md' 2>/dev/null); do \
	  case "$$f" in \
	    docs/FULL_LANGUAGE_SELFHOST.md|docs/STATUS.md) continue ;; \
	  esac; \
	  grep -q 'The entry points named in this file do not exist' "$$f" \
	    || { echo "[FAIL] $$f advertises a missing entry point without the honest banner"; miss=1; }; \
	done; \
	if [ "$$miss" != 0 ]; then exit 1; fi
	@grep -q 'The Stage-2 host is not in this repository' docs/FULL_LANGUAGE_SELFHOST.md \
	  || { echo "[FAIL] docs/FULL_LANGUAGE_SELFHOST.md lost its honest Stage-2 section"; exit 1; }
	@for f in selfhost/seed/sxc_seed_min.c selfhost/compiler_min.sa selfhost/native_aot.sa docs/STATUS.md docs/STDLIB.md; do \
	  test -s "$$f" || { echo "[FAIL] docs/FULL_LANGUAGE_SELFHOST.md references $$f, which is missing or empty"; exit 1; }; \
	done
	@test ! -e selfhost/native_aot.c \
	  || { echo "[FAIL] the C native backend selfhost/native_aot.c is back: selfhost/native_aot.sa superseded it"; exit 1; }
	@# the next phase is recorded and still honestly open
	@grep -q 'ALL_SAYANOX_PHASE.md' README.md \
	  || { echo "[FAIL] README.md no longer links the all-in-Sayanox next phase"; exit 1; }
	@test -s docs/ALL_SAYANOX_PHASE.md \
	  || { echo "[FAIL] docs/ALL_SAYANOX_PHASE.md is missing"; exit 1; }
	@grep -q 'next phase' docs/ALL_SAYANOX_PHASE.md && grep -q 'in progress' docs/ALL_SAYANOX_PHASE.md \
	  || { echo "[FAIL] docs/ALL_SAYANOX_PHASE.md lost its honest next-phase status"; exit 1; }
	@grep -q 'tools/emit_to_ir.sa' docs/ALL_SAYANOX_PHASE.md \
	  || { echo "[FAIL] ALL_SAYANOX_PHASE.md does not record the Sayanox IR translator"; exit 1; }
	@test ! -e tools/emit_to_ir.c \
	  || { echo "[FAIL] the C IR translator is back: the Sayanox one superseded it"; exit 1; }
	@if $(MAKE) --no-print-directory all-sayanox >/dev/null 2>&1; then \
	  echo "[FAIL] all-sayanox now reports success: update docs/ALL_SAYANOX_PHASE.md, README.md and this target instead of keeping a stale claim"; exit 1; fi
	@echo "[OK] doc claims: $$(grep -rl 'The entry points named in this file do not exist' docs selfhost --include='*.md' | wc -l) legacy documents carry the banner; no Stage-2 host, bootstrap script or make target is advertised that does not exist"
test-stage2: test-doc-claims
test-for-str: test-doc-claims

# ---------------------------------------------------------------------------
# test-language-deps: the maintained toolchain must not need bash, awk, sed,
# Python, Perl, Node or Ruby. Two checks:
#
#   1. static -- every tracked shebang script is POSIX sh, no recipe line in
#      this Makefile invokes awk or sed, the LSP build does not use the old awk
#      binder, and the offline packer chunks with `split`, not awk.
#   2. dynamic -- a PATH shim makes those interpreters fail loudly and logs any
#      invocation. Tools that are already built are kept (`-o`, so the four-
#      minute compiler rebuild is not repeated), and the paths that used to
#      need an interpreter are re-run: LSP binding + sessions, the IR log
#      checks, the native/seed GC checks, the generic-limit fixture and the
#      package wrapper. Any logged invocation fails the gate.
#
# This is a boundary test of the exercised paths, not a proof that no optional
# target (for example the opt-in Python HTTP tests) uses an interpreter.
# ---------------------------------------------------------------------------
DEP_SHIM_DIR := $(TESTS)/depshim
DEP_SHIM_LOG := $(TESTS)/depshim.log
.PHONY: test-language-deps
test-language-deps: $(GEN2) $(SXC_NATIVE_BIN) $(LSP_BIN) $(NATIVE_BIN) $(SEED_MIN_BIN) $(SXPKG_BIN) tools/sxlsp_probe tools/sxpkg_transfer_test tools/sxpack
	@# ---- static ----
	@if [ -n "$$(find . -path './.git' -prune -o -type f -name '*.sh' -print)" ]; then \
	  echo "[FAIL] .sh scripts remain in the working tree:"; \
	  find . -path './.git' -prune -o -type f -name '*.sh' -print; exit 1; fi
	@if grep -nE '^	[@-]*[[:space:]]*(awk|sed)([[:space:]]|$$)' Makefile; then \
	  echo "[FAIL] a Makefile recipe invokes awk or sed"; exit 1; fi
	@test ! -e tools/lsp_workspace_bind.awk || { echo "[FAIL] the old awk LSP binder still exists"; exit 1; }
	@test ! -e tools/lsp_workspace_bind.sa || { echo "[FAIL] the LSP binder is back: the server walks folders itself now"; exit 1; }
	@test ! -e tools/lsp_workspace.h || { echo "[FAIL] the C LSP directory bridge is back"; exit 1; }
	@grep -q 'make workspace_manifest' tools/sayanox_lsp.sa && grep -q 'read_dir(' tools/sayanox_lsp.sa \
	  || { echo "[FAIL] the LSP no longer builds its folder index in Sayanox"; exit 1; }
	@grep -q 'pos + 1100' tools/sxpack.sa || { echo "[FAIL] tools/sxpack.sa no longer chunks at 1100 bytes"; exit 1; }
	@./tools/sxpack verify >/dev/null || { echo "[FAIL] tools/sxpack verify failed"; exit 1; }
	@echo "[OK] language deps (static): 0 tracked .sh scripts; pure-Sayanox sxpack/sxlsp_probe; no awk/sed in build or test recipes"
	@# ---- dynamic ----
	@mkdir -p $(DEP_SHIM_DIR)
	@rm -f $(DEP_SHIM_LOG)
	@for t in bash awk sed python3 python perl node ruby; do \
	  printf '#!/bin/sh\necho "%s invoked: $*" >> "%s"\nexit 127\n' "$$t" "$(CURDIR)/$(DEP_SHIM_LOG)" > "$(DEP_SHIM_DIR)/$$t"; \
	  chmod +x "$(DEP_SHIM_DIR)/$$t"; \
	done
	@PATH="$(CURDIR)/$(DEP_SHIM_DIR):$$PATH" sh -c \
	  './$(GEN2) tools/sayanox_lsp.sa $(TESTS)/lsp_shim.c && ./$(GEN2) tools/sayanox_lsp.sa $(TESTS)/lsp_shim_again.c && ./$(SXC_NATIVE_BIN) tools/sayanox_lsp.sa $(TESTS)/lsp_shim.elf'
	@cmp $(TESTS)/lsp_shim.c $(TESTS)/lsp_shim_again.c
	@cmp $(TESTS)/lsp_shim.elf $(LSP_BIN)
	@PATH="$(CURDIR)/$(DEP_SHIM_DIR):$$PATH" $(MAKE) --no-print-directory \
	  -o $(GEN2_C) -o $(GEN2) -o $(GEN1_MIN_C) -o $(GEN1_MIN) -o $(SEED_MIN_BIN) -o $(SXC_NATIVE_BIN) \
	  -o tools/sxlsp_probe -o tools/sxpkg_transfer_test -o tools/sxpack \
	  test-lsp test-lsp-robust test-native-ir-log test-native-mem test-seed-gc test-seed-generics test-sxpkg-online-local test-sxpkg-sayanox-logic
	@if [ -s $(DEP_SHIM_LOG) ]; then echo "[FAIL] a removed interpreter was invoked:"; cat $(DEP_SHIM_LOG); exit 1; fi
	@echo "[OK] language deps: no bash/awk/sed/python/perl/node/ruby invoked by the exercised build, test and LSP paths"

# ---------------------------------------------------------------------------
# test-gen2-index-expr: an index is a numeric EXPRESSION, in every position.
#
# Before this increment gen2 accepted only a literal or a plain name inside
# `[ ]` (`#error sayanox-min: unsupported index expression (number or name
# only)`) while seed-min and native accepted arithmetic; worse, an index in a
# `when`/`while` condition or in a `for` bound was copied verbatim, so the
# generated C subscripted an sx_list struct with a double and failed to compile
# ("array subscript is not an integer"). Both are fixed in the self-hosted
# compiler source (selfhost/compiler_min.sa, helper `raw_index`, four call
# sites: the two value-position parsers and the two postfix-operand parsers,
# plus the condition rewriter and the for-bound rewriter).
#
# Fixture selfhost/gen2_index_expr_test.sa: 39 hand-computed values covering
# literal/name/field/parenthesised indexes, unary minus-free arithmetic, string
# indexes, indexes in conditions and for bounds, and indexes inside typed
# function bodies. seed-min, gen2 and native must print identical bytes.
#
# Still refused by gen2 -- loudly, never as invalid C, and each pinned by the
# error loop below: `%` inside an index, a call other than len(), a comma, a
# quoted string, an empty index, unbalanced parentheses or brackets and an
# expression ending in an operator. The workaround the diagnostic names is to
# bind the value with `hold` first. `len(NAME)` and a nested `NAME[IDX]` used
# to be on that list and are lowered now: test-gen2-expr-lowering pins them.
# A negative index (`xs[-1]`) wraps on seed-min and gen2 but is an out-of-range
# error on native, so it is checked separately rather than in the parity file.
# ---------------------------------------------------------------------------
.PHONY: test-gen2-index-expr
GIXE_WANT := 30\n20\n30\n20\n20\n30\n30\n20\n40\n30\nc\nb\ne\n99\n50\n40\n20\n1\n2\n3\n4\n5\n6\n20\n30\n0\n1\n0\n1\n0\n1\n0\n1\n30\n1\n0\n1\nx\nindex-expr-done
test-gen2-index-expr: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/gen2_index_expr_test.sa > $(TESTS)/gixe_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gixe_seed $(TESTS)/gixe_seed.c
	./$(GEN2) selfhost/gen2_index_expr_test.sa $(TESTS)/gixe_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gixe_gen2 $(TESTS)/gixe_gen2.c
	$(call assert-out,./$(TESTS)/gixe_seed,$(GIXE_WANT))
	$(call assert-out,./$(TESTS)/gixe_gen2,$(GIXE_WANT))
	@# the lowering itself: sx_lget/sx_idx with the expression as the second
	@# argument, in a value, in a condition, in a for bound and in a typed body
	@grep -q -F 'sx_lget(xs,i - 1.0)' $(TESTS)/gixe_gen2.c || { echo "[FAIL] no arithmetic list index in a value position"; exit 1; }
	@grep -q -F 'if (sx_lget(xs,i - 1.0) == 20.0)' $(TESTS)/gixe_gen2.c || { echo "[FAIL] no arithmetic list index in a condition"; exit 1; }
	@grep -q -F 'for (k = 0.0; k < sx_lget(xs,0.0) / 5.0' $(TESTS)/gixe_gen2.c || { echo "[FAIL] no list index in a for bound"; exit 1; }
	@grep -q -F 'if (sx_lget(ys,z) < sx_lget(ys,z - 1.0))' $(TESTS)/gixe_gen2.c || { echo "[FAIL] no index pair inside a typed function condition"; exit 1; }
	@grep -q -F 'sx_idx(s,i)' $(TESTS)/gixe_gen2.c || { echo "[FAIL] no string index lowering"; exit 1; }
	@if grep -q -F 'xs[i' $(TESTS)/gixe_gen2.c; then echo "[FAIL] an index was copied into the C verbatim"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/gen2_index_expr_test.sa $(TESTS)/gixe_native || exit 1; \
	  ./$(TESTS)/gixe_native > $(TESTS)/gixe_native.out || exit 1; \
	  ./$(TESTS)/gixe_seed > $(TESTS)/gixe_seed.out || exit 1; \
	  cmp $(TESTS)/gixe_seed.out $(TESTS)/gixe_native.out || { echo "[FAIL] native index expressions differ from seed-min"; exit 1; }; \
	  echo '[OK] native index-expression parity (values, conditions, for bounds, typed bodies)'; \
	else echo '[SKIP] native index-expression parity: native_aot not built'; fi
	@# ---- refusals: a clear diagnostic plus a #error, never invalid C --------
	@printf 'hold xs = [1, 2, 3]\nmake pick(v: list) -> num {\n  give v[0]\n}\nshow xs[pick(xs)]\n' > $(TESTS)/gixe_bad_call.sa
	@printf 'hold xs = [1, 2, 3]\nshow xs[1, 2]\n' > $(TESTS)/gixe_bad_comma.sa
	@printf 'hold xs = [1, 2, 3]\nshow xs["a"]\n' > $(TESTS)/gixe_bad_quote.sa
	@printf 'hold xs = [1, 2, 3]\nshow xs[]\n' > $(TESTS)/gixe_bad_empty.sa
	@printf 'hold xs = [1, 2, 3]\nhold i = 1\nshow xs[(i]\n' > $(TESTS)/gixe_bad_unbal.sa
	@printf 'hold xs = [1, 2, 3]\nhold i = 1\nshow xs[i +]\n' > $(TESTS)/gixe_bad_trailop.sa
	@for t in call comma quote empty unbal trailop; do \
	  ./$(GEN2) $(TESTS)/gixe_bad_$$t.sa $(TESTS)/gixe_bad_$$t.c > $(TESTS)/gixe_bad_$$t.msg 2>&1; \
	  grep -q '#error sayanox-min:' $(TESTS)/gixe_bad_$$t.c || { echo "[FAIL] gixe_bad_$$t: the generated C has no #error"; exit 1; }; \
	  grep -q '^min: ' $(TESTS)/gixe_bad_$$t.msg || { echo "[FAIL] gixe_bad_$$t: no 'min:' diagnostic"; cat $(TESTS)/gixe_bad_$$t.msg; exit 1; }; \
	  echo "  refused $$t: $$(grep -m1 '^min: ' $(TESTS)/gixe_bad_$$t.msg | cut -c1-88)"; \
	done
	@# ---- a negative index wraps on seed-min and gen2; native refuses it -----
	@printf 'hold xs = [10, 20, 30, 40]\nshow xs[-1]\nshow xs[-2]\n' > $(TESTS)/gixe_neg.sa
	./$(SEED_MIN_BIN) $(TESTS)/gixe_neg.sa > $(TESTS)/gixe_neg_seed.c
	$(CC) -O2 -o $(TESTS)/gixe_neg_seed $(TESTS)/gixe_neg_seed.c
	$(call assert-out,./$(TESTS)/gixe_neg_seed,40\n30)
	./$(GEN2) $(TESTS)/gixe_neg.sa $(TESTS)/gixe_neg_gen2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/gixe_neg_gen2 $(TESTS)/gixe_neg_gen2.c
	$(call assert-out,./$(TESTS)/gixe_neg_gen2,40\n30)
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gixe_neg.sa $(TESTS)/gixe_neg_nat >/dev/null 2>&1 && ./$(TESTS)/gixe_neg_nat >/dev/null 2>&1; then \
	    echo "[FAIL] native accepted a negative index (documented as refused)"; exit 1; \
	  fi; \
	  echo '[OK] native refuses a negative index, as documented'; \
	fi
	@echo '[OK] gen2 index expressions: arithmetic/field indexes in values, conditions, for bounds and typed bodies (39 values identical on seed-min, gen2 and native); 6 unsupported index forms refused with a clear diagnostic and a #error (% in an index is supported now: test-gen2-index-mod)'

# test-for-paren: a parenthesised `for` source, `for v in (xs)`, takes the
# normal collection path on all three backends. (A parenthesised RANGE is a
# different thing and stays refused/tested in the seed for-field targets.)
test-for-paren: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/for_paren_test.sa > $(TESTS)/tfp_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/tfp_seed $(TESTS)/tfp_seed.c
	./$(GEN2) selfhost/for_paren_test.sa $(TESTS)/tfp_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/tfp_gen2 $(TESTS)/tfp_gen2.c
	$(call assert-out,./$(TESTS)/tfp_seed,a\nb\n7\n8\na\nb\nx\ny\nz\nz\n3\nparen-done)
	./$(TESTS)/tfp_seed > $(TESTS)/tfp_seed.out; ./$(TESTS)/tfp_gen2 > $(TESTS)/tfp_gen2.out; \
	  cmp $(TESTS)/tfp_seed.out $(TESTS)/tfp_gen2.out
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/for_paren_test.sa $(TESTS)/tfp_native || exit 1; \
	  ./$(TESTS)/tfp_native > $(TESTS)/tfp_native.out || exit 1; \
	  cmp $(TESTS)/tfp_seed.out $(TESTS)/tfp_native.out || { echo "[FAIL] native parenthesised-for differs from seed-min"; exit 1; }; \
	  echo '[OK] native parenthesised-for parity'; \
	else echo '[SKIP] native parenthesised-for parity: native_aot not built'; fi
	@echo '[OK] parenthesised for source: seed-min == gen2 (== native when built)'

# test-gen2-index-mod: `%` inside an index expression, left-associative with
# `*` and `/`, in values, conditions, for bounds, typed bodies and nested
# indexes. It used to be refused; the refusal list lives in
# test-gen2-index-expr and no longer names it.
test-gen2-index-mod: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/gen2_index_mod_test.sa > $(TESTS)/gim_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/gim_seed $(TESTS)/gim_seed.c
	./$(GEN2) selfhost/gen2_index_mod_test.sa $(TESTS)/gim_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/gim_gen2 $(TESTS)/gim_gen2.c
	./$(TESTS)/gim_seed > $(TESTS)/gim_seed.out; ./$(TESTS)/gim_gen2 > $(TESTS)/gim_gen2.out; \
	  cmp $(TESTS)/gim_seed.out $(TESTS)/gim_gen2.out
	@grep -q -F 'sx_mod' $(TESTS)/gim_gen2.c || { echo "[FAIL] no sx_mod in the gen2 index lowering"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/gen2_index_mod_test.sa $(TESTS)/gim_native || exit 1; \
	  ./$(TESTS)/gim_native > $(TESTS)/gim_native.out || exit 1; \
	  cmp $(TESTS)/gim_seed.out $(TESTS)/gim_native.out || { echo "[FAIL] native %-index differs from seed-min"; exit 1; }; \
	  echo '[OK] native %-index parity'; \
	else echo '[SKIP] native %-index parity: native_aot not built'; fi
	@echo '[OK] % in index expressions: seed-min == gen2 (== native when built)'

# test-type-refusals: forms without an implementation must be rejected rather
# than becoming malformed C.  A named struct annotation on `hold` is now a
# portable checked form: seed-min, gen2 and native all require the exact
# declared concrete struct identity.
test-type-refusals: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	@printf 'struct Pt {\n  x\n}\nstruct Box<T> {\n  v\n}\nhold b = Box<Pt> { 7 }\nshow 1\n' > $(TESTS)/ttr_nested.sa
	@printf 'struct Pt {\n  x\n  y\n}\nstruct Wrap {\n  p: Pt\n  n\n}\nshow 1\n' > $(TESTS)/ttr_fieldann.sa
	@printf 'struct Pt {\n  x\n  y\n}\nhold p: Pt = Pt { 1, 2 }\nhold q: Pt = p\nshow q.x\nshow q.y\n' > $(TESTS)/ttr_holdann.sa
	@printf 'struct Pt {\n  x\n  y\n}\nhold p: Pt = 5\nshow 1\n' > $(TESTS)/ttr_holdann_bad.sa
	@printf 'struct Pt {\n  x\n}\nstruct Qt {\n  x\n}\nhold p: Pt = Qt { 5 }\n' > $(TESTS)/ttr_holdann_wrongstruct.sa
	@# A type argument that is a CONCRETE struct name stays refused on all
	@# three. `Box<Box<num>>` is no longer in this table: a type argument may be
	@# an instantiation of a generic struct since 2026-10-22, which
	@# test-generic-structs-nested gates positively.
	@if ./$(SEED_MIN_BIN) $(TESTS)/ttr_nested.sa > $(TESTS)/ttr_nested_seed.c 2> $(TESTS)/ttr_nested_seed.msg; then echo "[FAIL] seed-min accepted Box<Pt>"; exit 1; fi
	@grep -q "a type argument must be" $(TESTS)/ttr_nested_seed.msg || { echo "[FAIL] seed-min type-argument refusal is unclear"; cat $(TESTS)/ttr_nested_seed.msg; exit 1; }
	@./$(GEN2) $(TESTS)/ttr_nested.sa $(TESTS)/ttr_nested_gen2.c > $(TESTS)/ttr_nested_gen2.msg 2>&1; \
	  grep -q '#error sayanox-min:' $(TESTS)/ttr_nested_gen2.c || { echo "[FAIL] gen2 accepted Box<Pt>"; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/ttr_nested.sa $(TESTS)/ttr_nested_native > $(TESTS)/ttr_nested_native.msg 2>&1; then echo "[FAIL] native accepted Box<Pt>"; exit 1; fi
	@grep -q "a type argument must be" $(TESTS)/ttr_nested_native.msg || { echo "[FAIL] native type-argument refusal is unclear"; cat $(TESTS)/ttr_nested_native.msg; exit 1; }
	@echo '[OK] a concrete struct name as a type argument refused on seed-min, gen2 and native (a generic instantiation is accepted: test-generic-structs-nested)'
	@# struct FIELD annotation: refused on all three (was: extra field)
	@if ./$(SEED_MIN_BIN) $(TESTS)/ttr_fieldann.sa > $(TESTS)/ttr_fieldann_seed.c 2> $(TESTS)/ttr_fieldann_seed.msg; then echo "[FAIL] seed-min accepted a struct field annotation"; exit 1; fi
	@grep -q "field annotations are not supported" $(TESTS)/ttr_fieldann_seed.msg || { echo "[FAIL] seed-min field-annotation refusal is unclear"; cat $(TESTS)/ttr_fieldann_seed.msg; exit 1; }
	@./$(GEN2) $(TESTS)/ttr_fieldann.sa $(TESTS)/ttr_fieldann_gen2.c > $(TESTS)/ttr_fieldann_gen2.msg 2>&1; \
	  grep -q 'struct field annotations are not supported' $(TESTS)/ttr_fieldann_gen2.c || { echo "[FAIL] gen2 accepted a struct field annotation"; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/ttr_fieldann.sa $(TESTS)/ttr_fieldann_native > $(TESTS)/ttr_fieldann_native.msg 2>&1; then echo "[FAIL] native accepted a struct field annotation"; exit 1; fi
	@grep -q "field annotations are not supported" $(TESTS)/ttr_fieldann_native.msg || { echo "[FAIL] native field-annotation refusal is unclear"; cat $(TESTS)/ttr_fieldann_native.msg; exit 1; }
	@echo '[OK] struct field annotations refused on seed-min, gen2 and native'
	@# Named struct holds: valid identity-preserving copy on every backend.
	./$(SEED_MIN_BIN) $(TESTS)/ttr_holdann.sa > $(TESTS)/ttr_holdann_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/ttr_holdann_seed $(TESTS)/ttr_holdann_seed.c
	./$(GEN2) $(TESTS)/ttr_holdann.sa $(TESTS)/ttr_holdann_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/ttr_holdann_gen2 $(TESTS)/ttr_holdann_gen2.c
	./$(NATIVE_BIN) $(TESTS)/ttr_holdann.sa $(TESTS)/ttr_holdann_native
	$(call assert-out,./$(TESTS)/ttr_holdann_seed,1\n2)
	$(call assert-out,./$(TESTS)/ttr_holdann_gen2,1\n2)
	$(call assert-out,./$(TESTS)/ttr_holdann_native,1\n2)
	@# A scalar and a same-shaped but differently named struct are both errors.
	@for f in ttr_holdann_bad ttr_holdann_wrongstruct; do \
	  if ./$(SEED_MIN_BIN) $(TESTS)/$$f.sa >$(TESTS)/$$f.seed.c 2>$(TESTS)/$$f.seed.msg; then echo "[FAIL] seed-min accepted invalid $$f"; exit 1; fi; \
	  grep -q 'declared struct\|type mismatch' $(TESTS)/$$f.seed.msg || { echo "[FAIL] seed-min struct-hold error is unclear"; cat $(TESTS)/$$f.seed.msg; exit 1; }; \
	  if ./$(NATIVE_BIN) $(TESTS)/$$f.sa $(TESTS)/$$f.native >$(TESTS)/$$f.native.out 2>$(TESTS)/$$f.native.msg; then echo "[FAIL] native accepted invalid $$f"; exit 1; fi; \
	  grep -q 'declared\|two different types' $(TESTS)/$$f.native.msg || { echo "[FAIL] native struct-hold error is unclear"; cat $(TESTS)/$$f.native.msg; exit 1; }; \
	  ./$(GEN2) $(TESTS)/$$f.sa $(TESTS)/$$f.gen2.c >/dev/null 2>$(TESTS)/$$f.gen2.msg; \
	  grep -q '#error sayanox-min:' $(TESTS)/$$f.gen2.c || { echo "[FAIL] gen2 accepted invalid $$f"; exit 1; }; \
	done
	@echo '[OK] struct-typed hold: seed-min, gen2 and native preserve/check the named concrete struct; scalar and wrong-struct initializers refuse'

test-stage2: test-gen2-index-expr
test-for-str: test-gen2-index-expr
test-gen2-gaps: test-gen2-index-expr
native-test: test-gen2-index-expr
native-test: test-for-paren
native-test: test-gen2-index-mod
native-test: test-type-refusals

# ---------------------------------------------------------------------------
# test-gen2-expr-lowering: the two gen2 expression gaps that were still
# recorded as divergences in docs/STATUS.md, now closed in the self-hosted
# compiler source (selfhost/compiler_min.sa).
#
#   * A `give`, a `when`/`while` condition and a parenthesized expression
#     copied a bare `+` into the C, so `give "hi " + n` became
#     `return "hi " + n;` and cc reported "invalid operands to binary + (have
#     'char *' and 'char *')". The expression rewriter now joins two strings
#     through sx_cat -- nesting for a chain, keeping the escapes of a literal,
#     and accepting a call such as concat(p, q) as an operand -- exactly as the
#     value-position parser already did. A `+` with one string side and one
#     numeric side is refused with the same sentence the value parser uses,
#     and `%` with a string operand is refused too; neither becomes C that
#     only fails at cc time.
#   * `len(NAME)` and a nested `NAME[IDX]` inside `[ ]` were refused in a value
#     position and copied verbatim into the C in a condition and in a for
#     bound, where cc reported "array subscript is not an integer". The new
#     helper idx_lower lowers both -- sx_llen/sx_len and sx_lget/sx_idx, chosen
#     by the declaration tables -- in a value, in a chain operand, in a
#     condition, in a for bound and inside a typed function body.
#
# Fixtures selfhost/gen2_str_cat_test.sa (11 values) and
# selfhost/gen2_index_call_test.sa (18 values): seed-min, gen2 and native must
# print identical bytes, and both must match the hand-computed expectation.
#
# Still refused by gen2, each pinned by the error loop below: `%` inside an
# index, a call other than len() inside an index (`xs[pick(xs)]`, which
# seed-min and native do accept -- a documented divergence), a quoted string
# inside an index, unbalanced brackets, a `+` with one string side and `%`
# with a string operand.
# ---------------------------------------------------------------------------
.PHONY: test-gen2-expr-lowering
GSC_WANT := hi bob\nsay "hi" kim\nLR\nxabcy\nabc!\npq/p\n[L-R]\n1\n2\nhi abc\nstr-cat-done
GIC_WANT := 40\n30\n20\n40\n102\n101\n40\n70\n100\n101\n0\n1\n2\n1\n40\n2\n102\nindex-call-done
test-gen2-expr-lowering: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@# ---- a string chain in a give: 11 values, identical on all three ------
	./$(SEED_MIN_BIN) selfhost/gen2_str_cat_test.sa > $(TESTS)/gsc_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gsc_seed $(TESTS)/gsc_seed.c
	./$(GEN2) selfhost/gen2_str_cat_test.sa $(TESTS)/gsc_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gsc_gen2 $(TESTS)/gsc_gen2.c
	$(call assert-out,./$(TESTS)/gsc_seed,$(GSC_WANT))
	$(call assert-out,./$(TESTS)/gsc_gen2,$(GSC_WANT))
	@# the lowering itself, in the generated C
	@grep -q -F 'return sx_cat("hi " , n);' $(TESTS)/gsc_gen2.c || { echo "[FAIL] a give did not join a literal and a name through sx_cat"; exit 1; }
	@grep -q -F 'return sx_cat(sx_cat("x" , n) , "y");' $(TESTS)/gsc_gen2.c || { echo "[FAIL] a three-part string chain in a give was not nested through sx_cat"; exit 1; }
	@grep -q -F 'return sx_cat(n , "!");' $(TESTS)/gsc_gen2.c || { echo "[FAIL] a give with the literal on the right was not lowered"; exit 1; }
	@grep -q -F 'return sx_cat(sx_cat(sx_cat(p, q) , "/") , p);' $(TESTS)/gsc_gen2.c || { echo "[FAIL] a call operand in a give string chain was not lowered"; exit 1; }
	@grep -q -F 'char *j = sx_cat(sx_cat(a, "-"), b);' $(TESTS)/gsc_gen2.c || { echo "[FAIL] the value-position string chain changed"; exit 1; }
	@if grep -n '" + n' $(TESTS)/gsc_gen2.c; then echo "[FAIL] a bare + between two strings reached the generated C"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/gen2_str_cat_test.sa $(TESTS)/gsc_native || exit 1; \
	  ./$(TESTS)/gsc_native > $(TESTS)/gsc_native.out || exit 1; \
	  ./$(TESTS)/gsc_seed > $(TESTS)/gsc_seed.out || exit 1; \
	  cmp $(TESTS)/gsc_seed.out $(TESTS)/gsc_native.out || { echo "[FAIL] native string-chain output differs from seed-min"; exit 1; }; \
	  echo '[OK] native parity for a string chain in a give'; \
	else echo '[SKIP] native string-chain parity: native_aot not built'; fi
	@# ---- len() and a nested index inside [ ]: 18 values, all three ---------
	./$(SEED_MIN_BIN) selfhost/gen2_index_call_test.sa > $(TESTS)/gic_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gic_seed $(TESTS)/gic_seed.c
	./$(GEN2) selfhost/gen2_index_call_test.sa $(TESTS)/gic_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gic_gen2 $(TESTS)/gic_gen2.c
	$(call assert-out,./$(TESTS)/gic_seed,$(GIC_WANT))
	$(call assert-out,./$(TESTS)/gic_gen2,$(GIC_WANT))
	@# the lowering itself: sx_llen/sx_len for len(), sx_lget/sx_idx for a
	@# nested index, in a value, in a condition, in a for bound and in a body
	@grep -q -F 'sx_lget(xs,sx_llen(xs) - 1.0)' $(TESTS)/gic_gen2.c || { echo "[FAIL] len() inside a list index was not lowered"; exit 1; }
	@grep -q -F 'sx_idx(s,sx_len(s) - 1.0)' $(TESTS)/gic_gen2.c || { echo "[FAIL] len() inside a string index was not lowered"; exit 1; }
	@grep -q -F 'sx_lget(xs,sx_lget(ys,0.0))' $(TESTS)/gic_gen2.c || { echo "[FAIL] a nested list index was not lowered"; exit 1; }
	@grep -q -F 'if (sx_lget(xs,sx_llen(xs) - 1.0) > 39.0)' $(TESTS)/gic_gen2.c || { echo "[FAIL] len() inside an index in a condition was not lowered"; exit 1; }
	@grep -q -F 'for (k = 0.0; k < sx_lget(ys,sx_llen(ys) - 1.0)' $(TESTS)/gic_gen2.c || { echo "[FAIL] a nested index in a for bound was not lowered"; exit 1; }
	@grep -q -F 'return sx_lget(v,sx_llen(v) - 1.0);' $(TESTS)/gic_gen2.c || { echo "[FAIL] len() inside an index in a typed body was not lowered"; exit 1; }
	@grep -q -F 'return sx_idx(t,sx_len(t) - 1.0);' $(TESTS)/gic_gen2.c || { echo "[FAIL] a string index in a typed body was not lowered"; exit 1; }
	@if grep -n 'xs\[' $(TESTS)/gic_gen2.c; then echo "[FAIL] an index was copied into the C verbatim"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/gen2_index_call_test.sa $(TESTS)/gic_native || exit 1; \
	  ./$(TESTS)/gic_native > $(TESTS)/gic_native.out || exit 1; \
	  ./$(TESTS)/gic_seed > $(TESTS)/gic_seed.out || exit 1; \
	  cmp $(TESTS)/gic_seed.out $(TESTS)/gic_native.out || { echo "[FAIL] native index-call output differs from seed-min"; exit 1; }; \
	  echo '[OK] native parity for len() and a nested index inside [ ]'; \
	else echo '[SKIP] native index-call parity: native_aot not built'; fi
	@# ---- refusals: a clear diagnostic plus a #error, never invalid C -------
	@printf 'hold xs = [1, 2, 3]\nmake pick(v: list) -> num {\n  give v[0]\n}\nshow xs[pick(xs)]\n' > $(TESTS)/gel_bad_call.sa
	@printf 'hold xs = [1, 2, 3]\nshow xs["a"]\n' > $(TESTS)/gel_bad_quote.sa
	@printf 'hold xs = [1, 2, 3]\nhold ys = [0]\nshow xs[ys[0]\n' > $(TESTS)/gel_bad_unbal.sa
	@printf 'make bad(x: str, v: num) -> str {\n  give "v=" + v\n}\nshow bad("q", 3)\n' > $(TESTS)/gel_bad_mix.sa
	@printf 'make bad2(x: num, s: str) -> num {\n  give x %% s\n}\nshow bad2(4, "ab")\n' > $(TESTS)/gel_bad_pctstr.sa
	@for t in call quote unbal mix pctstr; do \
	  ./$(GEN2) $(TESTS)/gel_bad_$$t.sa $(TESTS)/gel_bad_$$t.c > $(TESTS)/gel_bad_$$t.msg 2>&1; \
	  grep -q '#error sayanox-min:' $(TESTS)/gel_bad_$$t.c || { echo "[FAIL] gel_bad_$$t: the generated C has no #error"; exit 1; }; \
	  grep -q '^min: ' $(TESTS)/gel_bad_$$t.msg || { echo "[FAIL] gel_bad_$$t: no 'min:' diagnostic"; cat $(TESTS)/gel_bad_$$t.msg; exit 1; }; \
	  echo "  refused $$t: $$(grep -m1 '^min: ' $(TESTS)/gel_bad_$$t.msg | cut -c1-92)"; \
	done
	@# seed-min refuses a mixed + and a % on a string; native refuses the %
	@if ./$(SEED_MIN_BIN) $(TESTS)/gel_bad_mix.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted a string + a number in a give"; exit 1; fi
	@if ./$(SEED_MIN_BIN) $(TESTS)/gel_bad_pctstr.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted %% with a string operand"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gel_bad_pctstr.sa $(TESTS)/gel_bad_pctstr_nat >/dev/null 2>&1; then echo "[FAIL] native accepted %% with a string operand"; exit 1; fi; \
	  echo '[OK] seed-min and native refuse the mixed operands too'; \
	fi
	@echo '[OK] gen2 expression lowering: a string chain in a give/condition (11 values) and len()/a nested index inside [ ] in every position (18 values), identical on seed-min, gen2 and native; 5 unsupported forms refused with a clear diagnostic and a #error (% in an index is supported now: test-gen2-index-mod)'
test-stage2: test-gen2-expr-lowering
native-test: test-gen2-expr-lowering

test-parity:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold lib = 7\n' > $(TESTS)/par_lib.sa
	@printf 'use "selfhost/seed_tests/par_lib.sa"\n' > $(TESTS)/par.sa
	@printf 'struct Point {\n  x,\n  y\n}\n' >> $(TESTS)/par.sa
	@printf 'make twice(n) {\n  when n <= 0 {\n    give 0\n  }\n  give n * 2\n}\n' >> $(TESTS)/par.sa
	@printf 'hold p = Point { x: 3, y: 4 }\n' >> $(TESTS)/par.sa
	@printf 'hold xs = [10, 20, 30]\nhold i = 0\n' >> $(TESTS)/par.sa
	@printf 'while i < 3 {\n  show i\n  hold i = i + 1\n}\n' >> $(TESTS)/par.sa
	@printf 'when p.x < p.y {\n  show p.x + p.y\n} else {\n  show 0\n}\n' >> $(TESTS)/par.sa
	@printf 'show lib\nshow 10 %% 3\nshow twice(21)\nshow xs[2]\n' >> $(TESTS)/par.sa
	@printf 'hold xs = push(xs, 40)\nshow len(xs)\nshow concat("a", "b")\n' >> $(TESTS)/par.sa
	./$(SEED_MIN_BIN) $(TESTS)/par.sa > $(TESTS)/par_sm.c
	$(CC) -O2 -o $(TESTS)/par_sm $(TESTS)/par_sm.c
	./$(GEN2) $(TESTS)/par.sa $(TESTS)/par_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/par_g2 $(TESTS)/par_g2.c
	@./$(TESTS)/par_sm > $(TESTS)/par_sm.out; ./$(TESTS)/par_g2 > $(TESTS)/par_g2.out; \
	 cmp $(TESTS)/par_sm.out $(TESTS)/par_g2.out && echo "[OK] seed-min and gen2 agree on the shared dialect"
	@echo "=== TEST-PARITY-OK ==="

test-boot:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	./$(GEN2) $(BOOT_SA) selfhost/boot_from_gen2.c >/dev/null
	$(CC) -O2 -o selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./selfhost/boot_from_gen2 $(TESTS)/ts_re.sa $(TESTS)/ts_re_b.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re_b $(TESTS)/ts_re_b.c
	$(call assert-out,./$(TESTS)/ts_re_b,2)
	@echo "[OK] boot_from_gen2 reassign"

$(SEED_MIN_BIN): $(SEED_MIN_C)
	$(CC) -O2 -o $(SEED_MIN_BIN) $(SEED_MIN_C)
	@echo "[OK] seed-min"

seed-min: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = n + 1\nshow n\n' > $(TESTS)/min_re.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_re.sa > $(TESTS)/min_re.c
	$(CC) -O2 -o $(TESTS)/min_re $(TESTS)/min_re.c
	$(call assert-out,./$(TESTS)/min_re,1)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/min_wh.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_wh.sa > $(TESTS)/min_wh.c
	$(CC) -O2 -o $(TESTS)/min_wh $(TESTS)/min_wh.c
	$(call assert-out,./$(TESTS)/min_wh,0\n1\n2\ndone)
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/min_mod.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_mod.sa > $(TESTS)/min_mod.c
	$(CC) -O2 -o $(TESTS)/min_mod $(TESTS)/min_mod.c
	@grep -q 'sx_mod((double)(a),(double)(3.0))' $(TESTS)/min_mod.c
	$(call assert-out,./$(TESTS)/min_mod,1\n1)
	@printf 'hold z = 99\n' > $(TESTS)/min_other.sa
	@printf 'use "selfhost/seed_tests/min_other.sa"\nshow z\n' > $(TESTS)/min_use.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_use.sa > $(TESTS)/min_use.c
	$(CC) -O2 -o $(TESTS)/min_use $(TESTS)/min_use.c
	$(call assert-out,./$(TESTS)/min_use,99)
	@printf 'use "selfhost/seed_tests/min_missing.sa"\nshow 1\n' > $(TESTS)/min_miss.sa
	@! ./$(SEED_MIN_BIN) $(TESTS)/min_miss.sa > /dev/null 2>&1
	@echo "=== SEED-MIN-OK ==="

test-struct: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'struct Point {\n  x,\n  y\n}\nhold p = Point { 3, 4 }\nshow p.x\nshow p.y\nshow p.x + p.y\n' > $(TESTS)/struct.sa
	./$(SEED_MIN_BIN) $(TESTS)/struct.sa > $(TESTS)/struct.c
	$(CC) -O2 -o $(TESTS)/struct $(TESTS)/struct.c
	$(call assert-out,./$(TESTS)/struct,3\n4\n7)
	@echo "[OK] seed-min structs"
	@echo "=== TEST-STRUCT-OK ==="

test-list: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold xs = [10, 20, 30]\nshow xs[0]\nshow xs[1]\nshow xs[2]\nhold n = len(xs)\nshow n\nhold xs = push(xs, 40)\nshow xs[3]\nshow len(xs)\n' > $(TESTS)/list.sa
	./$(SEED_MIN_BIN) $(TESTS)/list.sa > $(TESTS)/list.c
	$(CC) -O2 -o $(TESTS)/list $(TESTS)/list.c
	$(call assert-out,./$(TESTS)/list,10\n20\n30\n3\n40\n4)
	@echo "[OK] seed-min lists"
	@echo "=== TEST-LIST-OK ==="

test-fn: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'make add(a, b) {\n  give a + b\n}\nmake square(x) {\n  give x * x\n}\nhold r = add(40, 2)\nshow r\nhold s = square(5)\nshow s\n' > $(TESTS)/fn.sa
	./$(SEED_MIN_BIN) $(TESTS)/fn.sa > $(TESTS)/fn.c
	$(CC) -O2 -o $(TESTS)/fn $(TESTS)/fn.c
	$(call assert-out,./$(TESTS)/fn,42\n25)
	@echo "[OK] seed-min make/give"
	@echo "=== TEST-FN-OK ==="

test-fn2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'make add(a, b) {\n  give a + b\n}\nmake fac(n) {\n  when n <= 1 {\n    give 1\n  }\n  give n * fac(n - 1)\n}\nhold r = add(40, 2)\nshow r\nshow fac(5)\nshow add(r, 1)\n' > $(TESTS)/ts_fn2.sa
	./$(GEN2) $(TESTS)/ts_fn2.sa $(TESTS)/ts_fn2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_fn2 $(TESTS)/ts_fn2.c
	$(call assert-out,./$(TESTS)/ts_fn2,42\n120\n43)
	@printf 'make f(n) {\n  when n <= 0 { give 0 }\n  give n * 2\n}\nshow f(3)\n' > $(TESTS)/ts_fn3.sa
	./$(GEN2) $(TESTS)/ts_fn3.sa $(TESTS)/ts_fn3.c >/dev/null
	@grep -q '#error' $(TESTS)/ts_fn3.c
	@echo "[OK] gen2 functions: params, calls in show, recursion (fac 5 = 120), one-line give rejected"

seed-min-gen1: $(SEED_MIN_BIN) restore-compiler
	@echo "[seed-min] compiler_min.sa -> gen1_min.c"
	./$(SEED_MIN_BIN) $(MIN_SA) > $(GEN1_MIN_C)
	@test -s $(GEN1_MIN_C)
	@grep -q 'int main' $(GEN1_MIN_C)
	$(CC) -O2 -o $(GEN1_MIN) $(GEN1_MIN_C)
	@echo "[OK] gen1_min via seed-min"
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/sm_wh.sa
	./$(GEN1_MIN) $(TESTS)/sm_wh.sa $(TESTS)/sm_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/sm_wh $(TESTS)/sm_wh.c
	$(call assert-out,./$(TESTS)/sm_wh,0\n1\n2\ndone)
	@echo "=== SEED-MIN-GEN1-OK ==="

true-selfhost-min: seed-min-gen1
	@echo "[2] gen1_min -> gen2.c"
	./$(GEN1_MIN) $(MIN_SA) $(GEN2_C) >/dev/null
	@test -s $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@$(MAKE) test-reassign test-while test-when test-mod test-struct2 test-list2 test-use test-fn2 test-chain test-condmod test-user test-nest test-prec test-float test-parens test-push-stmt test-full-lang test-generics test-parity test-stage2-demos test-stage2 test-for-str test-gen2-gaps test-stdlib test-pkgs test-registry-sums test-builtin-names test-sxfmt test-sxpkg test-lsp test-lsp-robust test-stdlib-growth test-stdlib-modules test-gen2-index-expr test-gen2-expr-lowering test-doc-claims test-sxpkg-polish test-native-strord test-native-cond test-native-lang test-native-locals test-give-index test-typed-sig test-list-expr test-list-paren test-native-strfn test-native-strgen test-native-listgen test-native-logicarg test-cond-string test-gen2-logic-builtin test-struct-logic test-logic-value test-native-generics test-gc test-seed-gc test-generic-structs test-sxpkg-online-local test-sxpkg-online-optin test-sxpkg-sayanox-logic test-read-bytes test-full-language-expr test-language-deps
	@if cmp -s $(GEN1_MIN_C) $(GEN2_C); then echo "[FAIL] frozen copy"; exit 1; fi
	@$(MAKE) test-boot
	@echo "=== TRUE-SELFHOST-MIN-OK ==="

# This name must never report success merely because the subset bootstraps.
# Passing the readiness probes alone would still not be exhaustive coverage.
true-selfhost-full: true-selfhost-min
	@$(MAKE) gen3
	@$(MAKE) test-full-language-readiness
	@echo '[FAIL] no reviewed exhaustive full-language acceptance specification; refusing a full-language claim'
	@exit 1

true-selfhost: true-selfhost-min
selfhost: true-selfhost

# ---------------------------------------------------------------------------
# all-sayanox: the NEXT PHASE (docs/ALL_SAYANOX_PHASE.md).
#
# Deliberately FAIL-CLOSED. Compiler logic, the formatter, the package tool,
# the language server and the LSP binder are Sayanox programs, and since
# 2026-10-17 no maintained path needs bash, awk, sed or Python
# (`make test-language-deps`). What is still not Sayanox is the small trusted C
# seed, the C native backend and the make/POSIX-sh build driver. This target prints that measured inventory on
# every run, so the claim cannot silently drift and the remaining work cannot
# be forgotten, and then refuses to report success.
#
# Removing a row here (and from docs/ALL_SAYANOX_PHASE.md) is how the phase
# advances. Flip this target only when the inventory is empty or every
# remaining entry is a documented exception in that document.
# ---------------------------------------------------------------------------
.PHONY: all-sayanox
all-sayanox:
	@echo "=== ALL-SAYANOX: next phase, not implemented ==="
	@printf '  %-28s %6s lines  %s\n' seed "$$(wc -l < selfhost/seed/sxc_seed_min.c)" selfhost/seed/sxc_seed_min.c
	@printf '  %-28s %6s files  %s\n' non-anchor-c-or-h "$$(git ls-files '*.c' '*.h' | grep -vc '^selfhost/seed/sxc_seed_min\.c$$' || true)" '.c/.h'
	@printf '  %-28s %6s lines  %s\n' build-driver "$$(wc -l < Makefile)" Makefile
	@printf '  %-28s %6s files  %s\n' tracked-shell-scripts "$$(git ls-files '*.sh' | wc -l)" 'must remain zero'
	@printf '  %-28s %6s files  %s\n' sayanox-source "$$(git ls-files '*.sa' | wc -l)" '.sa'
	@echo "  done: compiler, C-free self-compiling x86-64 ELF64 compiler (tools/sxc_native.sa),"
	@echo "        native x86-64 ELF64 AOT backend (selfhost/native_aot.sa), pure-Sayanox"
	@echo "        seed compiler (selfhost/seed/sxc_seed.sa), four-target machine-code"
	@echo "        backend + user-mode arm64/riscv64 ELF64 emulator (tools/native32.sa +"
	@echo "        tools/sxisaexec.sa), transitive DAG module binder (tools/sxmod_lib.sa +"
	@echo "        tools/sxmod.sa), Sayanox build & compiler test suites (tools/sxbuild.sa +"
	@echo "        tools/sxsuite.sa), Stage-2 parity + IR VM (tools/sxstage2_parity.sa +"
	@echo "        tools/sxirexec.sa), Curve25519 Schnorr-SHA256 package signing (stdlib/pubkey.sa"
	@echo "        + tools/sxpkg.sa), C-free ELF64 LSP server (tools/sayanox_lsp.sa), extended"
	@echo "        5-backend stdlib (map/sort/path/cli/bytes), formatter, seed auditor, and"
	@echo "        diagnostic suites -- zero non-anchor .c/.h files remain in the repository"
	@echo "  plan: docs/ALL_SAYANOX_PHASE.md"
	@echo '[FAIL] not all maintained logic is Sayanox yet; refusing an all-in-Sayanox claim'
	@exit 1

$(SXDIAG_BIN): $(SXDIAG_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXDIAG_SA) $(SXDIAG_BIN)

.PHONY: test-sxdiag
test-sxdiag: $(SXDIAG_BIN) $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	@echo "[ok] sxdiag built from $(SXDIAG_SA) by gen2 and $(CC)"
	@./$(SXDIAG_BIN) inline ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-inline
	@./$(SXDIAG_BIN) postfix ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-postfix
	@./$(SXDIAG_BIN) return ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-return
	@./$(SXDIAG_BIN) name ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-name
	@# ---- the failures are real, not a suite that always prints OK ----
	@if ./$(SXDIAG_BIN) bogus ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-bad >/dev/null 2>&1; then \
	  echo "[FAIL] sxdiag accepted an unknown suite name"; exit 1; fi
	@./$(SXDIAG_BIN) bogus ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-bad 2>&1 >/dev/null | grep -q 'unknown suite'
	@if ./$(SXDIAG_BIN) 2>/dev/null; then echo "[FAIL] sxdiag ran without a suite"; exit 1; fi
	@# a frontend that succeeds on everything must FAIL the suite: this is the
	@# control that keeps the assertions above from being decoration
	@if ./$(SXDIAG_BIN) return /bin/true /bin/true /bin/true $(TESTS)/sxdiag-dead >/dev/null 2>&1; then \
	  echo "[FAIL] sxdiag passed a suite with a frontend that accepts everything"; exit 1; fi
	@if ./$(SXDIAG_BIN) inline /bin/true /bin/true /bin/true $(TESTS)/sxdiag-dead >/dev/null 2>&1; then \
	  echo "[FAIL] sxdiag passed the inline suite with a frontend that accepts everything"; exit 1; fi
	@# ---- the run_command(cmd) builtin itself: status in, stdout inherited ----
	@printf 'show run_command("exit 3")\nhold r = run_command("echo builtin-run-ok > $(TESTS)/sxdiag-run.txt")\nshow r\n' > $(TESTS)/sxdiag_run.sa
	./$(GEN2) $(TESTS)/sxdiag_run.sa $(TESTS)/sxdiag_run.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sxdiag_run $(TESTS)/sxdiag_run.c
	$(call assert-out,./$(TESTS)/sxdiag_run,3\n0)
	@grep -q 'builtin-run-ok' $(TESTS)/sxdiag-run.txt \
	  || { echo "[FAIL] run_command(): the child's stdout and redirection did not happen"; exit 1; }
	@printf 'hold n = run_command("true")\nshow n\n' > $(TESTS)/sxdiag_run_seed.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/sxdiag_run_seed.sa >/dev/null 2>$(TESTS)/sxdiag_run_seed.err; then \
	  echo "[FAIL] seed-min accepted run_command() without implementing it"; exit 1; fi
	@grep -q 'unknown function or builtin' $(TESTS)/sxdiag_run_seed.err \
	  || { echo "[FAIL] seed-min refused run_command() without a clear diagnostic"; cat $(TESTS)/sxdiag_run_seed.err; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/sxdiag_run_seed.sa $(TESTS)/sxdiag_run_native 2>/dev/null; then \
	  echo "[FAIL] native accepted run_command() without implementing it"; exit 1; fi
	@# ---- the getenv(name) builtin: a value in, "" for a name that is unset ----
	@printf 'show getenv("SXDIAG_MARK")\nhold unset = getenv("SXDIAG_NOT_SET")\nshow concat("[", concat(unset, "]"))\nwhen string_eq(getenv("SXDIAG_MODE"), "on") { show "mode-on" }\n' > $(TESTS)/sxdiag_env.sa
	./$(GEN2) $(TESTS)/sxdiag_env.sa $(TESTS)/sxdiag_env.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/sxdiag_env $(TESTS)/sxdiag_env.c
	$(call assert-out,SXDIAG_MARK=marked SXDIAG_MODE=on ./$(TESTS)/sxdiag_env,marked\n[]\nmode-on)
	$(call assert-out,./$(TESTS)/sxdiag_env,\n[])
	@if ./$(SEED_MIN_BIN) $(TESTS)/sxdiag_env.sa >/dev/null 2>$(TESTS)/sxdiag_env_seed.err; then \
	  echo "[FAIL] seed-min accepted getenv() without implementing it"; exit 1; fi
	@grep -q 'unknown function or builtin' $(TESTS)/sxdiag_env_seed.err \
	  || { echo "[FAIL] seed-min refused getenv() without a clear diagnostic"; cat $(TESTS)/sxdiag_env_seed.err; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/sxdiag_env.sa $(TESTS)/sxdiag_env_native 2>/dev/null; then \
	  echo "[FAIL] native accepted getenv() without implementing it"; exit 1; fi
	@echo "[OK] sxdiag: 23 inline, 7 postfix, 14 return-path and 31 name-resolution refusals checked in Sayanox, with an unknown-suite refusal and two accept-everything controls; run_command and getenv refused by seed-min and native"

$(NATIVE_BIN): $(NATIVE_SRC) $(NATIVE_LIBS) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(NATIVE_SRC) $(NATIVE_BIN)
native: $(NATIVE_BIN)
	@echo "=== NATIVE-OK ==="
native-test: $(NATIVE_BIN) $(SEED_MIN_BIN)
	@mkdir -p examples $(TESTS)
	@printf 'hold x = 40\nhold x = x + 2\nshow x\n' > examples/native_hello.sa
	./$(NATIVE_BIN) examples/native_hello.sa $(TESTS)/native_hello
	$(call assert-out,./$(TESTS)/native_hello,42)
	@printf 'hold z = -42\nshow z\n' > $(TESTS)/native_negative.sa
	./$(NATIVE_BIN) $(TESTS)/native_negative.sa $(TESTS)/native_negative
	$(call assert-out,./$(TESTS)/native_negative,-42)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/native_while.sa
	./$(NATIVE_BIN) $(TESTS)/native_while.sa $(TESTS)/native_while
	$(call assert-out,./$(TESTS)/native_while,0\n1\n2\ndone)
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/native_mod.sa
	./$(NATIVE_BIN) $(TESTS)/native_mod.sa $(TESTS)/native_mod
	$(call assert-out,./$(TESTS)/native_mod,1\n1)
	@# the FALSE branch: `else`/`otherwise` body must actually run (it used to
	@# fall through a second conditional jump and silently print nothing)
	@printf 'hold a = 10\nwhen a < 5 { show 1 } else { show 2 }\nwhen a < 5 { show 3 } otherwise { show 4 }\nshow 5\n' > $(TESTS)/native_else.sa
	./$(NATIVE_BIN) $(TESTS)/native_else.sa $(TESTS)/native_else
	$(call assert-out,./$(TESTS)/native_else,2\n4\n5)
	@printf 'hold xs = [1, 2, 3]\nshow xs[0]\nshow len(xs)\n' > $(TESTS)/native_list.sa
	./$(NATIVE_BIN) $(TESTS)/native_list.sa $(TESTS)/native_list
	$(call assert-out,./$(TESTS)/native_list,1\n3)
	@printf 'hold xs = []\npush(xs, 5)\npush(xs, 6)\npush(xs, 7)\npush(xs, 8)\npush(xs, 9)\nshow len(xs)\nshow xs[0]\nshow xs[4]\n' > $(TESTS)/native_push.sa
	./$(NATIVE_BIN) $(TESTS)/native_push.sa $(TESTS)/native_push
	$(call assert-out,./$(TESTS)/native_push,5\n5\n9)
	@printf 'hold xs = [7]\nshow xs[9]\n' > $(TESTS)/native_oob.sa
	./$(NATIVE_BIN) $(TESTS)/native_oob.sa $(TESTS)/native_oob
	@if $(TESTS)/native_oob 2>/dev/null; then \
	  echo "[FAIL] native accepted an out-of-bounds list index"; exit 1; fi
	@$(TESTS)/native_oob 2>&1 >/dev/null | grep -q 'out of range'
	@# one slot per name: names sharing a first letter must not share storage
	@printf 'hold ab = 1\nhold ac = 2\nshow ab\nshow ac\n' > $(TESTS)/native_slot.sa
	./$(NATIVE_BIN) $(TESTS)/native_slot.sa $(TESTS)/native_slot
	$(call assert-out,./$(TESTS)/native_slot,1\n2)
	@# an undeclared name must be a hard error, never a silent 0
	@printf 'hold x = 1\nshow y\n' > $(TESTS)/native_undef.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_undef.sa $(TESTS)/native_undef 2>/dev/null; then \
	  echo "[FAIL] native accepted an undefined variable (silently wrong code)"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_undef.sa $(TESTS)/native_undef 2>&1 | grep -q 'undefined variable'
	@# structs: declaration, literal, field access
	@printf 'struct Point {\n  x\n  y\n}\nhold p = Point { 1, 2 }\nshow p.x\nshow p.y\n' > $(TESTS)/native_struct.sa
	./$(NATIVE_BIN) $(TESTS)/native_struct.sa $(TESTS)/native_struct
	$(call assert-out,./$(TESTS)/native_struct,1\n2)
	@# field access on a non-struct value is a hard error, never a mis-compile
	@printf 'hold a = 1\nshow a.x\n' > $(TESTS)/native_fld.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_fld.sa $(TESTS)/native_fld 2>/dev/null; then \
	  echo "[FAIL] native accepted field access on a number (silently wrong code)"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_fld.sa $(TESTS)/native_fld 2>&1 | grep -q 'cannot access a field'
	@# ------------- nested structs, end to end (seed-min / gen2 / native) ----
	@# same source as `make test-nest` (ts_nest / ts_nest3): the native backend
	@# must agree with seed-min and gen2 on both, field chain and typed copy
	@printf 'struct Point {\n  name,\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: Point { name: "p1", x: 1 }, b: Point { name: "p2", x: 2 } }\nshow l.a.name\nshow l.a.x\nshow l.b.name\nshow l.b.x\nhold m = l.b\nshow m.name\nshow m.x\n' > $(TESTS)/native_nest.sa
	./$(NATIVE_BIN) $(TESTS)/native_nest.sa $(TESTS)/native_nest
	$(call assert-out,./$(TESTS)/native_nest,p1\n1\np2\n2\np2\n2)
	@printf 'struct Point {\n  x,\n  y\n}\nstruct Rect {\n  o,\n  sz\n}\nstruct Scene {\n  r,\n  label\n}\nhold s = Scene { r: Rect { o: Point { 1, 2 }, sz: Point { 3, 4 } }, label: "main" }\nshow s.r.o.x\nshow s.r.o.y\nshow s.r.sz.x\nshow s.label\nhold rr = s.r\nshow rr.sz.y\n' > $(TESTS)/native_nest3.sa
	./$(NATIVE_BIN) $(TESTS)/native_nest3.sa $(TESTS)/native_nest3
	$(call assert-out,./$(TESTS)/native_nest3,1\n2\n3\nmain\n4)
	@# three-way parity: seed-min == gen2 == native on the nested programs
	@test -x $(SEED_MIN_BIN) || (echo "need seed-min (make seed-min)"; exit 1)
	@test -x $(GEN2) || (echo "need gen2 (run make true-selfhost first)"; exit 1)
	./$(SEED_MIN_BIN) $(TESTS)/native_nest3.sa > $(TESTS)/native_nest3_sm.c
	$(CC) -O2 -o $(TESTS)/native_nest3_sm $(TESTS)/native_nest3_sm.c
	$(call assert-out,./$(TESTS)/native_nest3_sm,1\n2\n3\nmain\n4)
	./$(GEN2) $(TESTS)/native_nest3.sa $(TESTS)/native_nest3_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/native_nest3_g2 $(TESTS)/native_nest3_g2.c
	$(call assert-out,./$(TESTS)/native_nest3_g2,1\n2\n3\nmain\n4)
	@echo "[OK] native nested structs: l.a.x chains (2 and 3 levels), typed copy; seed-min and gen2 agree"
	@# Keep the remaining nested-struct refusals clear rather than miscompiled.
	@printf 'struct Line {\n  a\n}\nstruct Point {\n  x\n}\nhold l = Line { a: Point { 1 } }\n' > $(TESTS)/native_nestfwd.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_nestfwd.sa $(TESTS)/native_nestfwd 2>/dev/null; then \
	  echo "[FAIL] native accepted a nested struct declared later"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_nestfwd.sa $(TESTS)/native_nestfwd 2>&1 | grep -q 'declare the nested struct first'
	@# Concrete list fields are list pointers, not inline doubles: exercise
	@# mutation and access here as well as in test-list-struct-fields.
	@printf 'struct Line {\n  a\n}\nhold l = Line { a: [1] }\nhold alias = l.a\npush(alias, 2)\nshow len(l.a)\nshow l.a[1]\n' > $(TESTS)/native_nestlist.sa
	./$(NATIVE_BIN) $(TESTS)/native_nestlist.sa $(TESTS)/native_nestlist
	$(call assert-out,./$(TESTS)/native_nestlist,2\n2)
	@printf 'struct Point {\n  x\n}\nhold q = Point { x: 1 }\nshow q\n' > $(TESTS)/native_showstruct.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_showstruct.sa $(TESTS)/native_showstruct 2>/dev/null; then \
	  echo "[FAIL] native accepted show of a struct"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_showstruct.sa $(TESTS)/native_showstruct 2>&1 | grep -q 'show of a struct'
	@printf 'struct Point {\n  x\n}\nhold p = Point { x: 1 }\nshow p.x.y\n' > $(TESTS)/native_nestchain.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_nestchain.sa $(TESTS)/native_nestchain 2>/dev/null; then \
	  echo "[FAIL] native accepted a chain through a number field"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_nestchain.sa $(TESTS)/native_nestchain 2>&1 | grep -q 'cannot access a field'
	@echo "[OK] native nested boundaries: concrete list field works; later-declared nesting, show of struct and bad chain reject clearly"
	@# doubly nested field copy (same source as test-nest's ts_nestcopy):
	@# all three backends must print 7
	@printf 'struct Point {\n  x\n}\nstruct Mid {\n  p\n}\nstruct Top {\n  q\n}\nhold t = Top { q: Mid { p: Point { x: 7 } } }\nhold p2 = t.q.p\nshow p2.x\n' > $(TESTS)/native_nestcopy.sa
	./$(NATIVE_BIN) $(TESTS)/native_nestcopy.sa $(TESTS)/native_nestcopy
	$(call assert-out,./$(TESTS)/native_nestcopy,7)
	./$(SEED_MIN_BIN) $(TESTS)/native_nestcopy.sa > $(TESTS)/native_nestcopy_sm.c
	$(CC) -O2 -o $(TESTS)/native_nestcopy_sm $(TESTS)/native_nestcopy_sm.c
	$(call assert-out,./$(TESTS)/native_nestcopy_sm,7)
	./$(GEN2) $(TESTS)/native_nestcopy.sa $(TESTS)/native_nestcopy_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/native_nestcopy_g2 $(TESTS)/native_nestcopy_g2.c
	$(call assert-out,./$(TESTS)/native_nestcopy_g2,7)
	@echo "[OK] doubly nested field copy (hold p2 = t.q.p): seed-min == gen2 == native"
	@# ------------- use (module splice): same semantics as seed-min/gen2 ----
	@printf 'hold z = 99\n' > $(TESTS)/nu_other.sa
	@printf 'use "selfhost/seed_tests/nu_other.sa"\nshow z\n' > $(TESTS)/nu_use.sa
	./$(NATIVE_BIN) $(TESTS)/nu_use.sa $(TESTS)/nu_use
	$(call assert-out,./$(TESTS)/nu_use,99)
	@printf 'use "selfhost/seed_tests/nu_other.sa"\nhold y = 1\n' > $(TESTS)/nu_mid.sa
	@printf 'use "selfhost/seed_tests/nu_mid.sa"\nshow z\nshow y\n' > $(TESTS)/nu_top.sa
	./$(NATIVE_BIN) $(TESTS)/nu_top.sa $(TESTS)/nu_top
	$(call assert-out,./$(TESTS)/nu_top,99\n1)
	@# a path relative to the INPUT FILE also resolves (native tries the
	@# input's directory first, then the cwd; seed-min/gen2 try cwd first)
	@printf 'use "nu_other.sa"\nshow z\n' > $(TESTS)/nu_rel.sa
	./$(NATIVE_BIN) $(TESTS)/nu_rel.sa $(TESTS)/nu_rel
	$(call assert-out,./$(TESTS)/nu_rel,99)
	@# missing file and unquoted path are hard errors with stable messages
	@printf 'use "selfhost/seed_tests/nu_missing.sa"\nshow 1\n' > $(TESTS)/nu_miss.sa
	@if ./$(NATIVE_BIN) $(TESTS)/nu_miss.sa $(TESTS)/nu_miss 2>/dev/null; then \
	  echo "[FAIL] native accepted a use of a missing file"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/nu_miss.sa $(TESTS)/nu_miss 2>&1 | grep -q 'cannot open use file'
	@printf 'use other.sa\nshow 1\n' > $(TESTS)/nu_uq.sa
	@if ./$(NATIVE_BIN) $(TESTS)/nu_uq.sa $(TESTS)/nu_uq 2>/dev/null; then \
	  echo "[FAIL] native accepted an unquoted use path"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/nu_uq.sa $(TESTS)/nu_uq 2>&1 | grep -q 'use needs a quoted path'
	@echo "[OK] native use: splice, nested depth 2, input-dir resolution; missing file and unquoted path are clear errors"
	@# ------------- functions: make/give, recursion, calls as values --------
	@printf 'make add(a, b) {\n  give a + b\n}\nmake fac(n) {\n  when n <= 1 {\n    give 1\n  }\n  give n * fac(n - 1)\n}\nmake fib(n) {\n  when n <= 1 {\n    give n\n  } else {\n    give fib(n - 1) + fib(n - 2)\n  }\n}\nshow add(40, 2)\nshow fac(5)\nshow fib(20)\nhold r = add(fac(4), fib(7))\nshow r\n' > $(TESTS)/native_fn.sa
	./$(NATIVE_BIN) $(TESTS)/native_fn.sa $(TESTS)/native_fn
	$(call assert-out,./$(TESTS)/native_fn,42\n120\n6765\n37)
	@# all six parameter registers (the spills of rdi/rdx/rcx used to be
	@# mis-encoded, so params 1/3/4 read garbage), a forward reference,
	@# mutual recursion, a zero-arg call, and a global assigned from a fn
	@printf 'make sum6(a, b, c, d, e, f) {\n  give a + b + c + d + e + f\n}\nmake later(x) {\n  give helper(x) * 2\n}\nmake helper(x) {\n  give x + 1\n}\nmake is_even(n) {\n  when n == 0 {\n    give 1\n  }\n  give is_odd(n - 1)\n}\nmake is_odd(n) {\n  when n == 0 {\n    give 0\n  }\n  give is_even(n - 1)\n}\nmake z() {\n  give 7\n}\nmake bump(dummy) {\n  cnt = cnt + 1\n  give cnt\n}\nhold cnt = 0\nshow sum6(1, 2, 3, 4, 5, 6)\nshow later(4)\nshow is_even(10)\nshow z()\nshow bump(0)\nshow bump(0)\nshow cnt\n' > $(TESTS)/native_fn2.sa
	./$(NATIVE_BIN) $(TESTS)/native_fn2.sa $(TESTS)/native_fn2
	$(call assert-out,./$(TESTS)/native_fn2,21\n10\n1\n7\n1\n2\n2)
	@# calls with builtin args, and string indexing (r_sget used to lose the
	@# index inside its strlen call, so every sx_index/s[i] died with
	@# "string index out of range")
	@printf 'hold s = "abc"\nmake add(a, b) {\n  give a + b\n}\nshow add(len(s), 2)\nshow sx_index(s, 0)\nshow s[2]\nshow add(s[0], sx_index(s, 1))\n' > $(TESTS)/native_fn3.sa
	./$(NATIVE_BIN) $(TESTS)/native_fn3.sa $(TESTS)/native_fn3
	$(call assert-out,./$(TESTS)/native_fn3,5\n97\n99\n195)
	@# postfix operands to the RIGHT of * / % (p.x * p.x, 3 * xs[0]) used to
	@# die with "* is numeric-only" (the right side was parsed as a bare
	@# primary); / and % must also stay left-associative
	@printf 'struct Point {\n  x,\n  y\n}\nhold p = Point { x: 3, y: 4 }\nhold xs = [10, 20]\nshow p.x * p.x\nshow 2 * p.y\nshow 3 * xs[0]\nshow 100 / 5 / 2\nshow 17 %% 5 %% 3\n' > $(TESTS)/native_postmul.sa
	./$(NATIVE_BIN) $(TESTS)/native_postmul.sa $(TESTS)/native_postmul
	$(call assert-out,./$(TESTS)/native_postmul,9\n8\n30\n10\n2)
	./$(SEED_MIN_BIN) $(TESTS)/native_postmul.sa > $(TESTS)/native_postmul_sm.c
	$(CC) -O2 -o $(TESTS)/native_postmul_sm $(TESTS)/native_postmul_sm.c
	$(call assert-out,./$(TESTS)/native_postmul_sm,9\n8\n30\n10\n2)
	./$(GEN2) $(TESTS)/native_postmul.sa $(TESTS)/native_postmul_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/native_postmul_g2 $(TESTS)/native_postmul_g2.c
	$(call assert-out,./$(TESTS)/native_postmul_g2,9\n8\n30\n10\n2)
	@echo "[OK] postfix to the right of * / % (p.x * p.x, 3 * xs[0]); / and % left-associative; seed-min == gen2 == native"
	@# seed-min and gen2 agree with native on the function program
	./$(SEED_MIN_BIN) $(TESTS)/native_fn.sa > $(TESTS)/native_fn_sm.c
	$(CC) -O2 -o $(TESTS)/native_fn_sm $(TESTS)/native_fn_sm.c
	$(call assert-out,./$(TESTS)/native_fn_sm,42\n120\n6765\n37)
	./$(GEN2) $(TESTS)/native_fn.sa $(TESTS)/native_fn_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/native_fn_g2 $(TESTS)/native_fn_g2.c
	$(call assert-out,./$(TESTS)/native_fn_g2,42\n120\n6765\n37)
	@echo "[OK] native functions: recursion (fac/fib), 6 params, forward refs, mutual recursion, zero-arg, global assignment, builtin/string args; seed-min and gen2 agree"
	@# function forms native must reject with clear, stable errors
	@printf 'make f(n) {\n  hold t = n * 2\n  give t\n}\nshow f(3)\n' > $(TESTS)/native_fnhold.sa
	@./$(NATIVE_BIN) $(TESTS)/native_fnhold.sa $(TESTS)/native_fnhold && ./$(TESTS)/native_fnhold | grep -qx 6 || { echo "[FAIL] native hold inside a function did not print 6"; exit 1; }
	@printf 'give 5\n' > $(TESTS)/native_giveout.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_giveout.sa $(TESTS)/native_giveout 2>/dev/null; then \
	  echo "[FAIL] native accepted give outside a function"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_giveout.sa $(TESTS)/native_giveout 2>&1 | grep -q 'give outside a make function'
	@printf 'when 1 == 1 {\n  make g(x) {\n    give x\n  }\n}\n' > $(TESTS)/native_mkin.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_mkin.sa $(TESTS)/native_mkin 2>/dev/null; then \
	  echo "[FAIL] native accepted make inside a block"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_mkin.sa $(TESTS)/native_mkin 2>&1 | grep -q 'make must be at the top level'
	@printf 'make f(a) {\n  give a\n}\nshow f(1, 2)\n' > $(TESTS)/native_fnargs.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_fnargs.sa $(TESTS)/native_fnargs 2>/dev/null; then \
	  echo "[FAIL] native accepted a wrong argument count"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_fnargs.sa $(TESTS)/native_fnargs 2>&1 | grep -q 'takes 1 args, got 2'
	@printf 'make f(a) {\n  give a\n}\nshow f("x")\n' > $(TESTS)/native_fnty.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_fnty.sa $(TESTS)/native_fnty 2>/dev/null; then \
	  echo "[FAIL] native accepted a string argument for a numeric function"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_fnty.sa $(TESTS)/native_fnty 2>&1 | grep -q 'takes numbers'
	@printf 'make f(a) {\n  give "x"\n}\nshow f(1)\n' > $(TESTS)/native_fngive.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_fngive.sa $(TESTS)/native_fngive 2>/dev/null; then \
	  echo "[FAIL] native accepted a non-numeric give"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_fngive.sa $(TESTS)/native_fngive 2>&1 | grep -q 'give must give a number'
	@echo "[OK] native rejects (clearly): give outside make, make inside a block, wrong arg count, non-numeric arg, non-numeric give"
	@$(MAKE) --no-print-directory test-native-num test-native-io test-native-mem test-stdlib test-stage2-demos test-stage2 test-for-str test-seed-gc test-generic-structs test-sxpkg-online-local test-sxpkg-online-optin test-native-emit-split test-native-ir-log test-for-paren test-gen2-index-mod test-type-refusals test-native-ir-portable
	@echo "[OK] native: modulo, else alias, distinct name slots, undefined names, lists, structs, nested structs, use splice, functions"
	@# string ordering on native (hand-computed; gen2/seed-min leg in test-native-strord)
	./$(NATIVE_BIN) selfhost/native_strord_test.sa $(TESTS)/nso_nat_gate
	$(call assert-out,./$(TESTS)/nso_nat_gate,$(NSO_WANT))
	@# the 2026-10-10 stdlib helpers, on native, against the hand-computed values
	./$(NATIVE_BIN) selfhost/stdlib_growth_test.sa $(TESTS)/sg_nat_gate
	$(call assert-out,./$(TESTS)/sg_nat_gate,55\n0\n0\n2\n9\n-7\n4\n4\n0\n1\n24\n1\n1\n0\n8\n16\n5\n1\n3\n0\n1\n0\n0\n1\n0\n3\n4\n4\n1000)
	@echo "[OK] native: stdlib growth helpers (tri, ceil_div, pow_mod, collatz_steps, digit_at, isqrt, ...)"
	@echo "=== NATIVE-TEST-OK ==="

grammar: true-selfhost-min
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  hold n = n + 1\n}\nwhen n == 3 {\n  show "grammar-ok"\n} otherwise {\n  show "grammar-fail"\n}\n' > $(TESTS)/grammar.sa
	./$(GEN2) $(TESTS)/grammar.sa $(TESTS)/grammar.c >/dev/null
	$(CC) -O2 -o $(TESTS)/grammar $(TESTS)/grammar.c
	$(call assert-out,./$(TESTS)/grammar,grammar-ok)
	@echo "=== GRAMMAR-OK ==="

gc-test: $(SXC_NATIVE_BIN) selfhost/rc_runtime_stress.sa
	@mkdir -p $(TESTS)
	./$(SXC_NATIVE_BIN) selfhost/rc_runtime_stress.sa $(TESTS)/rc_runtime_stress
	@# 2005 = the 5 chars of "start" plus the 2000 appends in the stress loop.
	$(call assert-out,./$(TESTS)/rc_runtime_stress,2005\ngc-rc-ok)
	@echo "=== GC-RC-OK ==="

# gen2's mark & sweep collector, from the language side: a concat loop must
# not grow the managed heap without bound, collections must happen, gc() must
# run and the surviving string must stay intact.
test-gc: $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'hold base = gc_live()\nhold s = ""\nhold i = 0\nwhile i < 2000 {\n  s = concat(s, "abc")\n  i = i + 1\n}\nhold got = gc()\nhold after = gc_live()\nwhen after < base + 200000 {\n  show "bounded"\n}\nwhen gc_runs() > 0 {\n  show "ran"\n}\nshow len(s)\nwhen got > 0 {\n  show "reclaimed"\n}\nshow sx_index(s, 0)\n' > $(TESTS)/gc_builtins.sa
	./$(GEN2) $(TESTS)/gc_builtins.sa $(TESTS)/gc_builtins.c
	$(CC) -O2 -o $(TESTS)/gc_builtins $(TESTS)/gc_builtins.c
	$(call assert-out,./$(TESTS)/gc_builtins,bounded\nran\n6000\nreclaimed\n97)
	@echo "[OK] gen2 GC: gc()/gc_live()/gc_runs() keep a concat loop bounded"
	@# native runs the same program: the two collectors must agree on the
	@# language surface, even though the implementations differ (see GC.md)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/gc_builtins.sa $(TESTS)/gc_builtins_nat || exit 1; \
	  __got=$$(./$(TESTS)/gc_builtins_nat); \
	  __want=$$(printf 'bounded\nran\n6000\nreclaimed\n97'); \
	  if [ "$$__got" = "$$__want" ]; then :; else \
	    echo "[FAIL] native gc_builtins output differs"; printf '%s\n' "$$__got"; exit 1; fi; \
	  echo "[OK] native GC: same program, same results as gen2 (native mark & sweep)"; \
	fi

gen3:
	@test -x $(GEN2) || (echo "run true-selfhost first"; exit 1)
	./$(GEN2) $(MIN_SA) $(GEN3_C) >/dev/null
	@test -s $(GEN3_C)
	$(CC) -O2 -o $(GEN3) $(GEN3_C)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/g3_re.sa
	./$(GEN3) $(TESTS)/g3_re.sa $(TESTS)/g3_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_re $(TESTS)/g3_re.c
	$(call assert-out,./$(TESTS)/g3_re,2)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/g3_wh.sa
	./$(GEN3) $(TESTS)/g3_wh.sa $(TESTS)/g3_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wh $(TESTS)/g3_wh.c
	$(call assert-out,./$(TESTS)/g3_wh,0\n1\n2\ndone)
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/g3_wn.sa
	./$(GEN3) $(TESTS)/g3_wn.sa $(TESTS)/g3_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wn $(TESTS)/g3_wn.c
	$(call assert-out,./$(TESTS)/g3_wn,99)
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/g3_mod.sa
	./$(GEN3) $(TESTS)/g3_mod.sa $(TESTS)/g3_mod.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_mod $(TESTS)/g3_mod.c
	$(call assert-out,./$(TESTS)/g3_mod,1\n1)
	@echo "[OK] gen3 modulo + else"
	./$(GEN3) $(MIN_SA) selfhost/gen4.c >/dev/null
	@if cmp -s $(GEN3_C) selfhost/gen4.c; then echo "[OK] byte-identical gen3 == gen4"; \
	else echo "[FAIL] gen3/gen4 differ"; exit 1; fi
	@$(MAKE) --no-print-directory tools/sxsuite
	@CC='$(CC)' SXSUITE_REQUIRE_GEN3=1 ./tools/sxsuite compiler_features
	@CC='$(CC)' SXSUITE_REQUIRE_GEN3=1 ./tools/sxsuite struct_fn
	@CC='$(CC)' SXSUITE_REQUIRE_GEN3=1 ./tools/sxsuite stage2_interp
	@# gen3 exists here, so the broader-language readiness probes can finally
	@# run inside a hard gate instead of only under the fail-closed
	@# true-selfhost-full. They are closure probes, not a language contract.
	@SXSUITE_REQUIRE_GEN3=1 $(MAKE) --no-print-directory test-full-language-readiness
	@echo "=== GEN3-OK ==="

subset: seed-bin
	@printf 'hold x = 42\nshow x\n' > selfhost/_smoke.sa
	./$(SEED_BIN) selfhost/_smoke.sa > selfhost/_smoke.c
	$(CC) -O2 -o selfhost/_smoke selfhost/_smoke.c -lm
	$(call assert-out,./selfhost/_smoke,42)
	@echo "=== SUBSET-SELFHOST-OK ==="

gen1: $(GEN1_MIN)
	@echo "=== GEN1-MIN-OK ==="
gen2: $(GEN2)
	@echo "=== GEN2-OK ==="
test: true-selfhost
	@echo TEST-OK

clean:
	rm -f $(GEN1) $(GEN1_C) $(GEN1_MIN) $(GEN1_MIN_C) $(GEN2) $(GEN2_C) $(GEN3) $(GEN3_C) selfhost/gen4.c
	rm -f $(SEED_MIN_BIN) $(SEED_BIN) $(SXC_NATIVE_BIN) $(NATIVE_BIN) selfhost/boot_from_gen2 selfhost/boot_from_gen2.c $(SXFMT_BIN) $(SXFMT_C) $(SXPKG_BIN) $(SXPKG_C) $(LSP_BIN) $(LSP_C) $(SXDIAG_BIN) $(SXDIAG_C) tools/emit_to_ir tools/emit_to_ir.c tools/sxlink tools/sxencode tools/sxdefs tools/native32 tools/sxmod tools/sxaudit tools/sxinfer tools/sxruntime tools/sxgc tools/sxemit tools/sxbuild tools/sxstage2_parity tools/sxirexec tools/sxpkg_pubkey_test tools/sxsuite tools/sxisaexec tools/sxc_native_test tools/sxisaexec_test tools/sxmod_deep_test tools/lsp_ide_test tools/sxpack tools/sxlsp_probe tools/sxpkg_transfer_test tools/sxnet_test tools/sxarch_aot tools/sxarch_aot_test

# ---------------------------------------------------------------------------
# doctor: check core tools. Expanded feature gates also use POSIX utilities;
# see DEPENDENCY.md. This is not an exhaustive minimal-PATH execution audit.
#
#   required : make, a C99 compiler (cc/clang/gcc), a POSIX shell
#   optional : base64 + gzip -- only for the offline compiler_min.sa fallback
#
# Shell builtins provide printf/test/substitutions. Other feature recipes
# also use awk, sed, cp, rm and other POSIX utilities, never interpreter runtimes.
# ---------------------------------------------------------------------------
doctor:
	@fail=0; \
	echo "Sayanox core toolchain check"; \
	echo "--------------------------------"; \
	printf 'make            '; \
	if command -v make >/dev/null 2>&1; then echo "OK   $$(command -v make)"; \
	else echo "FAIL (required)"; fail=1; fi; \
	printf 'C99 compiler    '; \
	if [ -n "$$(command -v $(CC) 2>/dev/null)" ]; then echo "OK   $$(command -v $(CC))"; \
	else echo "FAIL (required: need cc, clang or gcc)"; fail=1; fi; \
	printf 'POSIX shell     '; \
	if [ -n "$$(command -v sh 2>/dev/null)" ]; then echo "OK   $$(command -v sh)"; \
	else echo "FAIL (required)"; fail=1; fi; \
	printf 'grep            '; \
	if command -v grep >/dev/null 2>&1; then echo "OK   $$(command -v grep)"; \
	else echo "FAIL (required: source assertions)"; fail=1; fi; \
	printf 'cmp             '; \
	if command -v cmp >/dev/null 2>&1; then echo "OK   $$(command -v cmp)"; \
	else echo "FAIL (required: fixed-point checks)"; fail=1; fi; \
	printf 'mkdir           '; \
	if command -v mkdir >/dev/null 2>&1; then echo "OK   $$(command -v mkdir)"; \
	else echo "FAIL (required: test scratch dir)"; fail=1; fi; \
	printf 'base64          '; \
	if command -v base64 >/dev/null 2>&1; then echo "OK   $$(command -v base64) (optional)"; \
	else echo "SKIP (optional: only to restore compiler_min.sa from its blob)"; fi; \
	printf 'gzip            '; \
	if command -v gzip >/dev/null 2>&1; then echo "OK   $$(command -v gzip) (optional)"; \
	else echo "SKIP (optional: only to restore compiler_min.sa from its blob)"; fi; \
	printf 'cat/tr/rm       '; \
	if command -v cat >/dev/null 2>&1 && command -v tr >/dev/null 2>&1 && command -v rm >/dev/null 2>&1; then \
	  echo "OK   $$(command -v cat), $$(command -v tr), $$(command -v rm) (optional)"; \
	else echo "SKIP (optional: only when compiler_min.sa is missing and must be decoded)"; fi; \
	printf 'split/paste     '; \
	if command -v split >/dev/null 2>&1 && command -v paste >/dev/null 2>&1; then \
	  echo "OK   $$(command -v split), $$(command -v paste) (optional)"; \
	else echo "SKIP (optional: pack-compiler chunking and the IR-log checks)"; fi; \
	echo "--------------------------------"; \
	printf 'python          '; command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 \
	  && echo "present, but NOT used anywhere on the bootstrap path" \
	  || echo "absent - fine, not required by bootstrap"; \
	printf 'node/ruby       '; command -v node >/dev/null 2>&1 || command -v ruby >/dev/null 2>&1 \
	  && echo "present, but NOT used anywhere on the bootstrap path" \
	  || echo "absent - fine, not required by bootstrap"; \
	echo "--------------------------------"; \
	if [ $$fail -eq 0 ]; then echo "DOCTOR-OK: core tool set is complete (not an audit of optional test utilities)"; \
	else echo "DOCTOR-FAIL: a required tool is missing"; exit 1; fi


.PHONY: test-stdlib-interpolation
test-stdlib-interpolation: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_interpolation_test.sa > $(TESTS)/interp_seed.c
	$(CC) -O2 -o $(TESTS)/interp_seed $(TESTS)/interp_seed.c
	./$(GEN2) selfhost/stdlib_interpolation_test.sa $(TESTS)/interp_gen2.c
	$(CC) -O2 -o $(TESTS)/interp_gen2 $(TESTS)/interp_gen2.c
	$(call assert-out,./$(TESTS)/interp_seed,2\n10\n4\n-6\n0\n0.25\n1\n0\n0.5\n1\n25\n0.5)
	$(call assert-out,./$(TESTS)/interp_gen2,2\n10\n4\n-6\n0\n0.25\n1\n0\n0.5\n1\n25\n0.5)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_interpolation_test.sa $(TESTS)/interp_native || exit 1; \
	  ./$(TESTS)/interp_native > $(TESTS)/interp_native.out || exit 1; \
	  ./$(TESTS)/interp_seed > $(TESTS)/interp_seed.out || exit 1; \
	  cmp $(TESTS)/interp_native.out $(TESTS)/interp_seed.out || exit 1; \
	  echo '[OK] native interpolation parity'; \
	else echo '[SKIP] native interpolation: native_aot not built'; fi
	@echo "[OK] interpolation helpers: seed-min, gen2 (native when built); endpoints, fractions, extrapolation"
test-stdlib-growth: test-stdlib-interpolation

.PHONY: test-seed-stage2
test-seed-stage2: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_stage2_test.sa > $(TESTS)/seed_s2.c
	$(CC) -O2 -o $(TESTS)/seed_s2 $(TESTS)/seed_s2.c
	./$(GEN2) selfhost/seed_stage2_test.sa $(TESTS)/seed_s2_g2.c
	$(CC) -O2 -o $(TESTS)/seed_s2_g2 $(TESTS)/seed_s2_g2.c
	$(call assert-out,./$(TESTS)/seed_s2,1\n0\n0\n1\n1\n0\n0\n1\n8\n8\n3\n11\n21\n2\n4\na\nand or not true false elif break continue)
	$(call assert-out,./$(TESTS)/seed_s2_g2,1\n0\n0\n1\n1\n0\n0\n1\n8\n8\n3\n11\n21\n2\n4\na\nand or not true false elif break continue)
	@for text in 'break' 'continue' 'show not "x"' 'show 1 and "x"' 'show [] or 1' 'show 1 and'; do \
	  printf '%s\n' "$$text" > $(TESTS)/seed_s2_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/seed_s2_bad.sa > $(TESTS)/seed_s2_bad.c 2> $(TESTS)/seed_s2_bad.err; then echo "[FAIL] seed accepted $$text"; exit 1; fi; \
	done
	@printf 'for c in concat(1, "b") { show c }\n' > $(TESTS)/seed_for_bad.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/seed_for_bad.sa > /dev/null 2> $(TESTS)/seed_for_bad.err; then echo '[FAIL] seed accepted unsupported for'; exit 1; fi
	@grep -q 'seed-min for' $(TESTS)/seed_for_bad.err
	@echo '[OK] seed Stage-2: boolean values/conditions, short circuit, elif, named-source for, break/continue; gen2 parity and clear refusals'
test-stage2: test-seed-stage2
test-for-str: test-seed-stage2

test-stdlib: test-stdlib-interpolation

.PHONY: test-seed-limits
test-seed-limits: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@for text in 'make id<T>(x: num) -> T { give x }' 'make first<A,B>(x: A) -> B { give x }'; do \
	  printf '%s\n' "$$text" > $(TESTS)/seed_generic_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/seed_generic_bad.sa >/dev/null 2>$(TESTS)/seed_generic_bad.err; then echo '[FAIL] seed accepted generics'; exit 1; fi; \
	  grep -q 'seed-min.*\(generic\|type parameter\)' $(TESTS)/seed_generic_bad.err || exit 1; \
	done
	@for text in 'hold xs = [1]\nfor x in xs() { show x }' 'hold xs = [1]\nfor xs in xs { show xs }' 'hold n = 1\nfor x in n { show x }' 'hold n = 1\nhold s = "ab"\nfor n in s { show n }'; do \
	  printf '%b\n' "$$text" > $(TESTS)/seed_for_limit.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/seed_for_limit.sa >/dev/null 2>$(TESTS)/seed_for_limit.err; then echo '[FAIL] seed accepted unsafe iteration'; exit 1; fi; \
	  grep -q 'seed-min for' $(TESTS)/seed_for_limit.err || exit 1; \
	done
	@# `for` over a body-local list inside a legacy untyped make used to be one of
	@# the refusals above. It is implemented now (see test-seed-for-untyped), so the
	@# obsolete refusal is replaced by an exact-output check.
	@printf 'make f() {\n  hold xs = [1, 2]\n  for x in xs {\n    show x\n  }\n  give 0\n}\nhold r = f()\nshow r\n' > $(TESTS)/seed_for_body.sa
	./$(SEED_MIN_BIN) $(TESTS)/seed_for_body.sa > $(TESTS)/seed_for_body.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/seed_for_body $(TESTS)/seed_for_body.c
	$(call assert-out,./$(TESTS)/seed_for_body,1\n2\n0)
	@echo '[OK] seed limits: invalid generic signatures, unsupported for diagnostics, body-local for accepted'
test-generics: test-seed-limits
test-stage2: test-seed-limits

.PHONY: test-pkg-errors
test-pkg-errors: sxpkg
	@mkdir -p $(TESTS)/pkg-errors-empty
	@if SAYANOX_ROOT=$(TESTS)/pkg-errors-empty $(SXPKG_BIN) search math >$(TESTS)/pkg-search.err 2>&1; then echo '[FAIL] search without local index succeeded'; exit 1; fi
	@grep -q 'no local index' $(TESTS)/pkg-search.err
	@# A regular file cannot be used as a project directory.
	@printf 'not a directory\n' > $(TESTS)/pkg-errors-file
	@if SAYANOX_ROOT=$(TESTS)/pkg-errors-file $(SXPKG_BIN) verify >$(TESTS)/pkg-verify.err 2>&1; then echo '[FAIL] verify swallowed project failure'; exit 1; fi
	@grep -q 'could not run verify' $(TESTS)/pkg-verify.err
	@echo '[OK] package errors: search never implicitly syncs; verify propagates execution/project failure'
test-pkgs: test-pkg-errors

.PHONY: test-seed-assignment
test-seed-assignment: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_assignment_test.sa > $(TESTS)/seed_assign.c
	$(CC) -O2 -o $(TESTS)/seed_assign $(TESTS)/seed_assign.c
	./$(GEN2) selfhost/seed_assignment_test.sa $(TESTS)/seed_assign_g2.c
	$(CC) -O2 -o $(TESTS)/seed_assign_g2 $(TESTS)/seed_assign_g2.c
	$(call assert-out,./$(TESTS)/seed_assign,3\nabbb\n3\n9\n10\n3\n4)
	$(call assert-out,./$(TESTS)/seed_assign_g2,3\nabbb\n3\n9\n10\n3\n4)
	@for text in 'missing = 1' 'hold n = 1\nn = "wrong"' 'hold s = "a"\ns = 7' 'hold xs = []\nxs = "wrong"'; do \
	  printf '%b\n' "$$text" > $(TESTS)/seed_assign_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/seed_assign_bad.sa >/dev/null 2>$(TESTS)/seed_assign_bad.err; then echo '[FAIL] seed accepted invalid assignment'; exit 1; fi; \
	  grep -q 'assignment' $(TESTS)/seed_assign_bad.err || exit 1; \
	done
	./$(SEED_MIN_BIN) selfhost/seed_assignment_names_test.sa > $(TESTS)/seed_assign_names.c
	$(CC) -O2 -o $(TESTS)/seed_assign_names $(TESTS)/seed_assign_names.c
	$(call assert-out,./$(TESTS)/seed_assign_names,underscore\nprefix\ntemporary)
	@echo '[OK] seed assignments: numeric/string/list, function locals, type errors, conditional aliases; gen2 parity'
test-stage2: test-seed-assignment

.PHONY: test-seed-hold-types
test-seed-hold-types: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_hold_types_test.sa > $(TESTS)/seed_types.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/seed_types $(TESTS)/seed_types.c
	./$(GEN2) selfhost/seed_hold_types_test.sa $(TESTS)/seed_types_g2.c
	$(CC) -O2 -o $(TESTS)/seed_types_g2 $(TESTS)/seed_types_g2.c
	$(call assert-out,./$(TESTS)/seed_types,1\n4\nhello!\n3\n9\n7\nok\n8\nbranch\n8\n6)
	$(call assert-out,./$(TESTS)/seed_types_g2,1\n4\nhello!\n3\n9\n7\nok\n8\nbranch\n8\n6)
	@for text in 'hold n: num = "x"' 'hold s: str = 1' 'hold xs: list = "x"' 'hold n: num = 1\nhold n = "x"' 'hold n: num = 1\nn = "x"' 'hold s: str = "x"\nhold s: num = 1' 'hold x: unknown = 1' 'make f() { hold x: num = 1\ngive x }'; do \
	  printf '%b\n' "$$text" > $(TESTS)/seed_types_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/seed_types_bad.sa >/dev/null 2>$(TESTS)/seed_types_bad.err; then echo '[FAIL] seed discarded a type annotation'; exit 1; fi; \
	  grep -q 'hold' $(TESTS)/seed_types_bad.err || exit 1; \
	done
	@echo '[OK] seed hold types: num/str/list, checked initializers and reassignments; gen2 parity; unsupported annotations rejected'
test-stage2: test-seed-hold-types

.PHONY: test-lsp-unicode
test-lsp-unicode: $(LSP_BIN) tools/sxlsp_probe
	$(call assert-out,./tools/sxlsp_probe unicode ./$(LSP_BIN),raw UTF-8 and JSON Unicode escapes agree\nUTF-16 advertised\nUTF-16 hover after BMP and supplementary characters\ndiagnostic range does not split surrogate pair\nempty full-text didChange clears document\ndidClose releases document state\nempty change array and unrelated URI preserve document)
	@echo '[OK] LSP Unicode and lifecycle: accented Latin, Bengali, emoji, UTF-16 positions, empty changes and close'
test-lsp: test-lsp-unicode

.PHONY: test-seed-for-literals
SFL_WANT := tick\n2\n3\n7\n99\na\nc\n1\na\n1\na\n2\nb\n1\nb\n2\n2\ntick\n7\ntick\n7\ndone
test-seed-for-literals: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_for_literals_test.sa > $(TESTS)/for_lit_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_lit_seed $(TESTS)/for_lit_seed.c
	./$(GEN2) selfhost/seed_for_literals_test.sa $(TESTS)/for_lit_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_lit_gen2 $(TESTS)/for_lit_gen2.c
	$(call assert-out,./$(TESTS)/for_lit_seed,$(SFL_WANT))
	$(call assert-out,./$(TESTS)/for_lit_gen2,$(SFL_WANT))
	@for text in 'hold c = 1\nfor c in "ab" { show c }' 'hold x = "a"\nfor x in [1] { show x }' 'for x in ["a"] { show x }' 'for x in [[1]] { show x }' 'for c in "a" + "b" { show c }' 'for c in "a" show c' 'hold _sx_iter_src_0 = 1'; do \
	  printf '%b\n' "$$text" > $(TESTS)/for_lit_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/for_lit_bad.sa >/dev/null 2>$(TESTS)/for_lit_bad.err; then echo '[FAIL] seed accepted invalid literal iteration'; exit 1; fi; \
	  test -s $(TESTS)/for_lit_bad.err || exit 1; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_for_literals_test.sa $(TESTS)/for_lit_native || exit 1; \
	  ./$(TESTS)/for_lit_native > $(TESTS)/for_lit_native.out || exit 1; \
	  ./$(TESTS)/for_lit_seed > $(TESTS)/for_lit_seed.out || exit 1; \
	  cmp $(TESTS)/for_lit_seed.out $(TESTS)/for_lit_native.out || exit 1; \
	  echo '[OK] native literal-for parity'; \
	else echo '[SKIP] native literal-for parity: native_aot not built'; fi
	@echo '[OK] seed literal for: string/list, one evaluation per entry, nested/empty loops, break/continue, UTF-8 bytes, errors; gen2 parity'
test-stage2: test-seed-for-literals
test-for-str: test-seed-for-literals

.PHONY: test-seed-for-range
SFR_WANT := 0\n1\n2\n3\n4\n5\n-1\n0\n1\n0.5\n1.5\n1\n2\n3\n0\n2\n3\n4\n0\n2\n10\n12\n5\n6\n7\n97\n98\n2\n3\n0\n2\n4\n6\n0\n1\nrange-done
test-seed-for-range: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_for_range_test.sa > $(TESTS)/for_range_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_range_seed $(TESTS)/for_range_seed.c
	./$(GEN2) selfhost/seed_for_range_test.sa $(TESTS)/for_range_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_range_gen2 $(TESTS)/for_range_gen2.c
	$(call assert-out,./$(TESTS)/for_range_seed,$(SFR_WANT))
	$(call assert-out,./$(TESTS)/for_range_gen2,$(SFR_WANT))
	@for text in 'for i in 0.. { show i }' 'for i in ..3 { show i }' 'for i in 1...3 { show i }' 'for i in 1.2.3..4 { show i }' 'for i in 0..2..3 { show i }' 'for i in 0.."x" { show i }' 'hold s = "a"\nfor i in s..3 { show i }' 'for i in 0..missing { show i }' 'for i in 0..len(1) { show i }' 'for i in 0..len() { show i }' 'hold s = "a"\nfor i in 0..len(s,s) { show i }' 'for i in 0..f() { show i }' 'hold i = []\nfor i in 0..3 { show i }' 'for true in 0..3 { show true }' 'for i in -"x"..3 { show i }' 'for i in 0..([] == []) { show i }' 'hold xs = [1]\nfor i in 0..xs["bad"] { show i }' 'hold n = 2\nfor i in 0..n.missing { show i }' 'show 1..2' 'show 2.' 'show 1.2.3'; do \
	  printf '%b\n' "$$text" > $(TESTS)/for_range_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/for_range_bad.sa >/dev/null 2>$(TESTS)/for_range_bad.err; then echo "[FAIL] seed accepted invalid range: $$text"; exit 1; fi; \
	  test -s $(TESTS)/for_range_bad.err || exit 1; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_for_range_test.sa $(TESTS)/for_range_native || exit 1; \
	  __got=$$(./$(TESTS)/for_range_native) || exit 1; \
	  __want=$$(printf '%b' '$(SFR_WANT)'); \
	  [ "$$__got" = "$$__want" ] || { echo '[FAIL] native range output changed'; printf '%s\n' "$$__got"; exit 1; }; \
	  echo '[OK] native range regression: live upper bound matches seed/gen2'; \
	else echo '[SKIP] native range regression: native_aot not built'; fi
	@echo '[OK] seed numeric ranges: half-open, fractional/negative bounds, empty/nested loops, live end bound, binder mutation, break/continue, len, errors; gen2 parity'
test-stage2: test-seed-for-range

.PHONY: test-seed-for-calls
SFC_WANT := labels\na\nb\nvalues\n4\n6\n100\nx\nA\nchanged\n1\n2\n2\nlabels\na\nlabels\na\nA\n9\nvalues\n0\n3\nfile\n1\nh\ni\ncalls-done
test-seed-for-calls: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_for_calls_test.sa > $(TESTS)/for_calls_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_calls_seed $(TESTS)/for_calls_seed.c
	./$(GEN2) selfhost/seed_for_calls_test.sa $(TESTS)/for_calls_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_calls_gen2 $(TESTS)/for_calls_gen2.c
	$(call assert-out,./$(TESTS)/for_calls_seed,$(SFC_WANT))
	$(call assert-out,./$(TESTS)/for_calls_gen2,$(SFC_WANT))
	./$(SEED_MIN_BIN) selfhost/seed_producer_forward_test.sa > $(TESTS)/producer_forward.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/producer_forward $(TESTS)/producer_forward.c
	$(call assert-out,./$(TESTS)/producer_forward,o\nk\n8\n9)
	@for text in 'for x in missing() { show x }' 'for x in chr("x") { show x }' 'for x in concat(1,"a") { show x }' 'for x in concat("a") { show x }' 'for x in chr(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17) { show x }' 'for x in push("x",1) { show x }' 'for x in push([],"x") { show x }' 'for x in read_file(1) { show x }' 'for x in chr(absent) { show x }' 'make f() -> num { give 2 }\nfor x in f() { show x }' 'make f() -> str { give 2 }' 'make f() -> list { give "x" }' 'make f() -> str { show "no give" }' 'make f(n) -> str { give "x" }' 'make f() -> other { give 1 }' 'make f() -> str { give missing() }' 'make f() -> str { hold s = "x"\nhold s = 2\ngive s }' 'hold global = "x"\nmake f() -> str { give global }' 'make f() -> str { when "bad" { give "x" }\ngive "y" }' 'make f() -> str { give "x" }\nfor x in f(1) { show x }' 'make f() -> str { give "x" }\nmake f() -> str { give "y" }' 'make f() { give "wrong" }\nfor x in chr(f()) { show x }'; do \
	  printf '%b\n' "$$text" > $(TESTS)/for_calls_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/for_calls_bad.sa >/dev/null 2>$(TESTS)/for_calls_bad.err; then echo "[FAIL] seed accepted invalid producer/call: $$text"; exit 1; fi; \
	  grep -q 'seed_min:' $(TESTS)/for_calls_bad.err || exit 1; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_for_calls_test.sa $(TESTS)/for_calls_native || exit 1; \
	  ./$(TESTS)/for_calls_native > $(TESTS)/for_calls_native.out || exit 1; \
	  ./$(TESTS)/for_calls_seed > $(TESTS)/for_calls_seed.out || exit 1; \
	  cmp $(TESTS)/for_calls_seed.out $(TESTS)/for_calls_native.out || exit 1; \
	  echo '[OK] native call-source fixture matches seed/gen2'; \
	else echo '[SKIP] native call-source fixture: native_aot not built'; fi
	@part=x; i=0; while [ $$i -lt 15 ]; do part=$$part$$part; i=$$((i+1)); done; \
	  printf 'for ch in concat("%s","%s") { show ch }\n' "$$part" "$$part" > $(TESTS)/for_calls_large.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/for_calls_large.sa >/dev/null 2>$(TESTS)/for_calls_large.err; then echo '[FAIL] seed accepted oversized lowering'; exit 1; fi
	@grep -q '64 KiB lowering limit' $(TESTS)/for_calls_large.err
	@echo '[OK] seed call-source for: checked builtins and zero-argument producers, capture once, local isolation, empty/nested loops, errors; gen2 parity'
test-stage2: test-seed-for-calls
test-for-str: test-seed-for-calls

# ---------------------------------------------------------------------------
# test-seed-for-untyped: `for` inside a LEGACY UNTYPED make body. Seed-min used
# to refuse every for inside an untyped make ("requires a fully typed
# signature"), while gen2 and native already ran body-local lists/strings,
# literals, ranges and call sources. Seed-min now runs the same forms: every
# body has an isolated scope, so the binder is a C local of that body and
# recursion is safe. A body still cannot capture a top-level hold name -- that
# is a clear diagnostic in seed-min and gen2 instead of the C compiler's
# "undeclared identifier". Fixture: selfhost/seed_for_untyped_test.sa.
# ---------------------------------------------------------------------------
.PHONY: test-seed-for-untyped
SFU_WANT := 6\na\nb\nc\nx\ny\n7\n8\n9\n0\n1\n2\n3\n12\na\nb\nc\nd\n0\n2\n4\n6\n0\nuntyped-for-done
test-seed-for-untyped: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_for_untyped_test.sa > $(TESTS)/for_untyped_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_untyped_seed $(TESTS)/for_untyped_seed.c
	./$(GEN2) selfhost/seed_for_untyped_test.sa $(TESTS)/for_untyped_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_untyped_gen2 $(TESTS)/for_untyped_gen2.c
	$(call assert-out,./$(TESTS)/for_untyped_seed,$(SFU_WANT))
	$(call assert-out,./$(TESTS)/for_untyped_gen2,$(SFU_WANT))
	@for text in 'hold g = [1]\nmake f() {\n  for v in g {\n    show v\n  }\n  give 0\n}' 'hold g = 5\nmake f() {\n  show g\n  give 0\n}' 'make f(a) {\n  for c in a {\n    show c\n  }\n  give 0\n}' 'make f() {\n  for v in missing {\n    show v\n  }\n  give 0\n}' 'make f() {\n  for i in 0.."x" {\n    show i\n  }\n  give 0\n}' 'make f() {\n  hold xs = [1]\n  for xs in xs {\n    show xs\n  }\n  give 0\n}' 'make f() {\n  for c in chr("x") {\n    show c\n  }\n  give 0\n}' 'make f() {\n  hold x = nosuch(1)\n  give x\n}' 'hold a = nosuch()'; do \
	  printf '%b\n' "$$text" > $(TESTS)/for_untyped_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/for_untyped_bad.sa >/dev/null 2>$(TESTS)/for_untyped_bad.err; then echo "[FAIL] seed accepted an invalid untyped-make for: $$text"; exit 1; fi; \
	  grep -q 'seed_min:' $(TESTS)/for_untyped_bad.err || { echo "[FAIL] no diagnostic for $$text"; exit 1; }; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_for_untyped_test.sa $(TESTS)/for_untyped_native || exit 1; \
	  ./$(TESTS)/for_untyped_native > $(TESTS)/for_untyped_native.out || exit 1; \
	  ./$(TESTS)/for_untyped_seed > $(TESTS)/for_untyped_seed.out || exit 1; \
	  cmp $(TESTS)/for_untyped_seed.out $(TESTS)/for_untyped_native.out || { echo "[FAIL] native untyped-make for differs"; exit 1; }; \
	  echo '[OK] native untyped-make for parity'; \
	else echo '[SKIP] native untyped-make for parity: native_aot not built'; fi
	@echo '[OK] seed for inside untyped make: body-local list/string, literals, ranges, call sources, nesting, break/continue, binder reuse, recursion; global capture refused; gen2 parity'
test-stage2: test-seed-for-untyped
test-for-str: test-seed-for-untyped
native-test: test-seed-for-untyped

# ---------------------------------------------------------------------------
# test-seed-for-fields: a struct FIELD (or a nested field chain) that holds a
# string is a for source, captured once per loop entry -- seed-min now matches
# gen2 and native. Two gen2 defects found while writing this gate are fixed by
# the same pass and are covered here:
#   * a string for-source over a field emitted sx_len/sx_idx/sx_chr without
#     setting the "full runtime preamble" flag, so the generated C did not link
#     (implicit declaration of sx_len);
#   * struct typedefs were emitted AFTER the function bodies, so a struct local
#     inside a make body was an "unknown type name" in the generated C.
# A numeric field is accepted as a range bound (for i in p.count..4).
# Fixture: selfhost/seed_for_fields_test.sa.
# ---------------------------------------------------------------------------
.PHONY: test-seed-for-fields
SFF_WANT := a\nb\nx\ny\n7\np\nq\nz\n0\na\nc\n2\n2\nm\nn\n2\n2\n3\nfields-done
test-seed-for-fields: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_for_fields_test.sa > $(TESTS)/for_fields_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_fields_seed $(TESTS)/for_fields_seed.c
	./$(GEN2) selfhost/seed_for_fields_test.sa $(TESTS)/for_fields_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/for_fields_gen2 $(TESTS)/for_fields_gen2.c
	$(call assert-out,./$(TESTS)/for_fields_seed,$(SFF_WANT))
	$(call assert-out,./$(TESTS)/for_fields_gen2,$(SFF_WANT))
	@# the two gen2 defects above must stay fixed: the generated C has to define
	@# every helper it calls, and a struct typedef has to precede the bodies
	@grep -q 'static double sx_len' $(TESTS)/for_fields_gen2.c || { echo "[FAIL] gen2 emitted sx_len() calls without the sx_len definition"; exit 1; }
	@# a struct local inside a make body: the typedef must come first
	@printf 'struct P {\n  x,\n  y\n}\nmake f() {\n  hold p = P { x: 3, y: 4 }\n  show p.x + p.y\n  give 0\n}\nhold r = f()\n' > $(TESTS)/for_fields_struct_fn.sa
	./$(GEN2) $(TESTS)/for_fields_struct_fn.sa $(TESTS)/for_fields_struct_fn.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_fields_struct_fn $(TESTS)/for_fields_struct_fn.c
	$(call assert-out,./$(TESTS)/for_fields_struct_fn,7)
	./$(SEED_MIN_BIN) $(TESTS)/for_fields_struct_fn.sa > $(TESTS)/for_fields_struct_fn_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/for_fields_struct_fn_seed $(TESTS)/for_fields_struct_fn_seed.c
	$(call assert-out,./$(TESTS)/for_fields_struct_fn_seed,7)
	@for text in 'struct P {\n  name\n}\nhold p = P { name: "ab" }\nfor c in p.missing {\n  show c\n}' 'struct P {\n  x\n}\nhold p = P { x: 3 }\nfor c in p.x {\n  show c\n}' 'hold n = 3\nfor c in n.x {\n  show c\n}' 'struct Q {\n  n\n}\nstruct P {\n  q\n}\nhold p = P { q: Q { n: "x" } }\nfor c in p.q {\n  show c\n}' 'struct P {\n  name\n}\nhold p = P { name: "ab" }\nfor c in p.name[0] {\n  show c\n}' 'struct P {\n  name\n}\nhold p = P { name: "ab" }\nfor i in p.name..3 {\n  show i\n}'; do \
	  printf '%b\n' "$$text" > $(TESTS)/for_fields_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/for_fields_bad.sa >/dev/null 2>$(TESTS)/for_fields_bad.err; then echo "[FAIL] seed accepted an invalid field source: $$text"; exit 1; fi; \
	  grep -q 'seed_min:' $(TESTS)/for_fields_bad.err || { echo "[FAIL] no diagnostic for $$text"; exit 1; }; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_for_fields_test.sa $(TESTS)/for_fields_native || exit 1; \
	  ./$(TESTS)/for_fields_native > $(TESTS)/for_fields_native.out || exit 1; \
	  ./$(TESTS)/for_fields_seed > $(TESTS)/for_fields_seed.out || exit 1; \
	  cmp $(TESTS)/for_fields_seed.out $(TESTS)/for_fields_native.out || { echo "[FAIL] native field-source for differs"; exit 1; }; \
	  ./$(NATIVE_BIN) $(TESTS)/for_fields_struct_fn.sa $(TESTS)/for_fields_struct_fn_native || exit 1; \
	  __got=$$(./$(TESTS)/for_fields_struct_fn_native) || exit 1; \
	  [ "$$__got" = "7" ] || { echo "[FAIL] native struct local in a body printed $$__got, want 7"; exit 1; }; \
	  echo '[OK] native field-source for parity'; \
	else echo '[SKIP] native field-source for parity: native_aot not built'; fi
	@echo '[OK] seed for over struct fields: 1/2/3-level chains, empty field, break/continue, UTF-8 bytes, body-local struct, numeric field range bound; gen2 + native parity'
test-stage2: test-seed-for-fields
test-for-str: test-seed-for-fields
native-test: test-seed-for-fields

.PHONY: test-seed-typed-functions
STP_WANT := keep\nkeep!\nkeep\nb\na!\nxyxyxy\n3\n10\nkeep+\nkeep\n3\n4\nz\n+\ntyped-done
STL_WANT := 3\n0\n2\n3\n10\n10\nok!\nglobal\nloops-done
test-seed-typed-functions: $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_typed_params_test.sa > $(TESTS)/typed_params_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/typed_params_seed $(TESTS)/typed_params_seed.c
	./$(GEN2) selfhost/seed_typed_params_test.sa $(TESTS)/typed_params_gen2.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/typed_params_gen2 $(TESTS)/typed_params_gen2.c
	$(call assert-out,./$(TESTS)/typed_params_seed,$(STP_WANT))
	$(call assert-out,./$(TESTS)/typed_params_gen2,$(STP_WANT))
	./$(SEED_MIN_BIN) selfhost/seed_typed_loops_test.sa > $(TESTS)/typed_loops_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/typed_loops_seed $(TESTS)/typed_loops_seed.c
	./$(GEN2) selfhost/seed_typed_loops_test.sa $(TESTS)/typed_loops_gen2.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/typed_loops_gen2 $(TESTS)/typed_loops_gen2.c
	$(call assert-out,./$(TESTS)/typed_loops_seed,$(STL_WANT))
	$(call assert-out,./$(TESTS)/typed_loops_gen2,$(STL_WANT))
	./$(SEED_MIN_BIN) selfhost/seed_typed_scope_test.sa > $(TESTS)/typed_scope_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/typed_scope_seed $(TESTS)/typed_scope_seed.c
	$(call assert-out,./$(TESTS)/typed_scope_seed,9\n11\nforward!\n1)
	@for text in 'make f(a: str) -> str { give a }\nshow f(1)' 'make f(a: str) -> str { give a }\nshow f(concat(1, 2))' 'make f(a: num) -> num { give a }\nshow f(missing)' 'make f(a: str) -> str { give a }\nshow f(unknown())' 'make f(a: list) -> list { give a }\nhold x = f("bad")' 'make f(a: num) -> num { give a }\nshow f()' 'make f(a: num, b) -> num { give a }' 'make f(a, b: str) -> str { give b }' 'make f(a: str) { give a }' 'make f(a: num, a: num) -> num { give a }' 'make f(a: other) -> num { give 1 }' 'make f(a: str) -> str { a = 1\ngive a }' 'make f(a: str) -> str { hold a: num = 1\ngive a }' 'make f() -> num { when true { hold x = 1 }\ngive x }' 'make f() -> num { when true { give 1 } }' 'make f(s: str) -> num { while s { show 1 }\ngive 0 }' 'make f() -> num { hold n: num = "bad"\ngive n }' 'make f() -> num { hold n: num = 1\nhold n: str = "bad"\ngive 0 }'; do \
	  printf '%b\n' "$$text" > $(TESTS)/typed_functions_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/typed_functions_bad.sa >/dev/null 2>$(TESTS)/typed_functions_bad.err; then echo "[FAIL] invalid typed function accepted: $$text"; exit 1; fi; \
	  grep -q 'seed_min:' $(TESTS)/typed_functions_bad.err || exit 1; \
	done
	@echo '[OK] seed typed functions: num/str/list parameters, alias-safe strings, control flow, recursion, scoped locals, annotations and function-local for; exact gen2 parity'
test-typed-sig: test-seed-typed-functions

# Include the new seed regression in both full bootstrap and native gates.
test-stage2: test-seed-typed-functions

.PHONY: test-native-param-reassign
test-native-param-reassign: $(NATIVE_BIN) $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(NATIVE_BIN) selfhost/seed_typed_params_test.sa $(TESTS)/npr_existing
	$(call assert-out,./$(TESTS)/npr_existing,$(STP_WANT))
	./$(SEED_MIN_BIN) selfhost/native_param_reassign_test.sa > $(TESTS)/npr_seed.c
	$(CC) -O2 -o $(TESTS)/npr_seed $(TESTS)/npr_seed.c
	./$(GEN2) selfhost/native_param_reassign_test.sa $(TESTS)/npr_gen2.c
	$(CC) -O2 -o $(TESTS)/npr_gen2 $(TESTS)/npr_gen2.c
	./$(NATIVE_BIN) selfhost/native_param_reassign_test.sa $(TESTS)/npr_native
	$(call assert-out,./$(TESTS)/npr_seed,1\n2\n9\naxxx\na)
	$(call assert-out,./$(TESTS)/npr_gen2,1\n2\n9\naxxx\na)
	$(call assert-out,./$(TESTS)/npr_native,1\n2\n9\naxxx\na)
	./$(NATIVE_BIN) selfhost/native_param_gc_test.sa $(TESTS)/npr_gc
	$(call assert-out,./$(TESTS)/npr_gc,local!\nlocal!!\nglobal\n99\n1\n2\n7)
	@for text in 'make f(s: str) -> str { s = 1\ngive s }\nshow f("a")' 'make f(xs: list) -> list { xs = "bad"\ngive xs }\nhold a = [1]\nhold b = f(a)' 'make f(n: num) -> num { n = "bad"\ngive n }\nshow f(1)'; do \
	  printf '%b\n' "$$text" > $(TESTS)/npr_bad.sa; \
	  if ./$(NATIVE_BIN) $(TESTS)/npr_bad.sa $(TESTS)/npr_bad 2>$(TESTS)/npr_bad.err; then echo '[FAIL] native accepted a parameter kind change'; exit 1; fi; \
	  grep -q 'assignment to parameter' $(TESTS)/npr_bad.err || exit 1; \
	done
	@echo '[OK] native parameter reassignment: num/str/list, aliases, recursion, GC roots, parameter-before-global lookup and kind errors'
test-native-locals: test-native-param-reassign
native-test: test-native-param-reassign

.PHONY: test-native-range-live
test-native-range-live: $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(NATIVE_BIN) selfhost/native_range_live_test.sa $(TESTS)/nrl_native
	$(call assert-out,./$(TESTS)/nrl_native,0\n1\n3\n2\n4\n5\n0\n1\n8)
	@echo '[OK] native-only live range bounds: call side effects, empty range, break and continue'
test-seed-for-range: test-native-range-live

.PHONY: test-native-for-functions
NFF_WANT := $(STL_WANT)\n3\n8\n21
test-native-for-functions: $(NATIVE_BIN) $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/native_for_functions_test.sa > $(TESTS)/nff_seed.c
	$(CC) -O2 -o $(TESTS)/nff_seed $(TESTS)/nff_seed.c
	./$(GEN2) selfhost/native_for_functions_test.sa $(TESTS)/nff_gen2.c
	$(CC) -O2 -o $(TESTS)/nff_gen2 $(TESTS)/nff_gen2.c
	./$(NATIVE_BIN) selfhost/native_for_functions_test.sa $(TESTS)/nff_native
	$(call assert-out,./$(TESTS)/nff_seed,$(NFF_WANT))
	$(call assert-out,./$(TESTS)/nff_gen2,$(NFF_WANT))
	$(call assert-out,./$(TESTS)/nff_native,$(NFF_WANT))
	./$(NATIVE_BIN) selfhost/native_for_gc_test.sa $(TESTS)/nff_gc
	$(call assert-out,./$(TESTS)/nff_gc,30\n1\n1\n99\n7)
	@printf 'make bad(s: str) -> num {\n for s in 0..2 { show s }\n give 0\n}\nshow bad("x")\n' > $(TESTS)/nff_bad.sa
	@if ./$(NATIVE_BIN) $(TESTS)/nff_bad.sa $(TESTS)/nff_bad 2>$(TESTS)/nff_bad.err; then echo '[FAIL] native accepted wrong-kind parameter binder'; exit 1; fi
	@grep -q 'two different types' $(TESTS)/nff_bad.err
	@printf 'make f() -> num {\n hold total = 0\n for v in [1, 2, 3] {\n hold __for0_idx = 999\n total = total + 1\n }\n give total\n}\nshow f()\n' > $(TESTS)/nff_names.sa
	./$(NATIVE_BIN) $(TESTS)/nff_names.sa $(TESTS)/nff_names
	$(call assert-out,./$(TESTS)/nff_names,3)
	@echo '[OK] native function-local for: recursive ranges/lists/strings, nested loops, parameter binder, break/continue; seed/gen2/native parity'
test-native-locals: test-native-for-functions
native-test: test-native-for-functions

.PHONY: test-native-list-alias
NLA_ALIAS_WANT := 100\n100\n100\n99\n101\n700\n1\n101\n101\n46\n46\n88
test-native-list-alias: $(NATIVE_BIN) $(GEN2) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/native_list_alias_test.sa > $(TESTS)/alias_seed.c
	$(CC) -O2 -o $(TESTS)/alias_seed $(TESTS)/alias_seed.c
	./$(GEN2) selfhost/native_list_alias_test.sa $(TESTS)/alias_gen2.c
	$(CC) -O2 -o $(TESTS)/alias_gen2 $(TESTS)/alias_gen2.c
	./$(NATIVE_BIN) selfhost/native_list_alias_test.sa $(TESTS)/alias_native
	$(call assert-out,./$(TESTS)/alias_seed,$(NLA_ALIAS_WANT))
	$(call assert-out,./$(TESTS)/alias_gen2,$(NLA_ALIAS_WANT))
	$(call assert-out,./$(TESTS)/alias_native,$(NLA_ALIAS_WANT))
	./$(NATIVE_BIN) selfhost/native_list_alias_gc_test.sa $(TESTS)/alias_gc
	$(call assert-out,./$(TESTS)/alias_gc,100\n99\nglobal\n100\n123\n[list len=101])
	@echo '[OK] native list growth preserves aliases: parameters, rebinding, multiple growths, length/index/show, explicit GC and reclaimed-block reuse; portable fixture matches seed/gen2'
test-native-locals: test-native-list-alias
native-test: test-native-list-alias

.PHONY: test-seed-generics
SGEN_WANT := 3\nhi\n2\nfirst\nsecond\n2\n8\nnested\n15\n3\n6\no\nk\n4\n5\n6
test-seed-generics: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_generics_test.sa > $(TESTS)/sgen_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgen_seed $(TESTS)/sgen_seed.c
	./$(GEN2) selfhost/seed_generics_test.sa $(TESTS)/sgen_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgen_gen2 $(TESTS)/sgen_gen2.c
	./$(NATIVE_BIN) selfhost/seed_generics_test.sa $(TESTS)/sgen_native
	$(call assert-out,./$(TESTS)/sgen_seed,$(SGEN_WANT))
	$(call assert-out,./$(TESTS)/sgen_gen2,$(SGEN_WANT))
	$(call assert-out,./$(TESTS)/sgen_native,$(SGEN_WANT))
	./$(SEED_MIN_BIN) selfhost/seed_generics_extended_test.sa > $(TESTS)/sgen_extended.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgen_extended $(TESTS)/sgen_extended.c
	$(call assert-out,./$(TESTS)/sgen_extended,3\nhi\n2\nfirst\nsecond\n2\n8\nnested\n15\nxyxyxy\n3\n6\no\nk\n4\n5\n6)
	./$(SEED_MIN_BIN) selfhost/seed_generics_scope_test.sa > $(TESTS)/sgen_scope.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgen_scope $(TESTS)/sgen_scope.c
	$(call assert-out,./$(TESTS)/sgen_scope,7\nT : T }\nkept\n7\nT : T }\n9\n5)
	./$(SEED_MIN_BIN) selfhost/seed_generics_test.sa > $(TESTS)/sgen_again.c
	cmp $(TESTS)/sgen_seed.c $(TESTS)/sgen_again.c
	@test "$$(grep -c '^static .*_sx_gen_0_.*){' $(TESTS)/sgen_seed.c)" = 3
	@! grep -q '^static .*_sx_gen_4_' $(TESTS)/sgen_seed.c
	@for text in 'make f<T>(a: T, b: T) -> T { give a }\nshow f(1,"bad")' 'make f<T>(a: T) -> T { give a }\nshow f()' 'make f<T>(a: T) -> U { give a }' 'make f<T,T>(a: T) -> T { give a }' 'make f<T,U>(a: T) -> U { give a }' 'make f<T>(a: num) -> T { give a }' 'make f<T>(a: T) -> T { give "bad" }\nshow f(1)' 'make f<T>(a: T) -> T { hold value: T = "bad"\ngive a }\nshow f(1)' 'make f<T>(a: T) -> T { give _sx_gen_0_1(a) }\nshow f(1)' 'make f<T>(a: T) -> T { when true { give a } }\nshow f(1)'; do \
	  printf '%b\n' "$$text" > $(TESTS)/sgen_bad.sa; \
	  if ./$(SEED_MIN_BIN) $(TESTS)/sgen_bad.sa >/dev/null 2>$(TESTS)/sgen_bad.err; then echo "[FAIL] invalid generic accepted: $$text"; exit 1; fi; \
	  grep -q 'seed_min:' $(TESTS)/sgen_bad.err || exit 1; \
	done
	@# 512 base-3 argument tuples, generated with shell builtins (no awk).
	@{ \
	  echo "make many<A,B,C,D,E,F>(a:A,b:B,c:C,d:D,e:E,f:F)->A { give a }"; \
	  i=0; \
	  while [ $$i -lt 512 ]; do \
	    n=$$i; line="show many("; j=0; \
	    while [ $$j -lt 6 ]; do \
	      k=$$((n % 3)); n=$$((n / 3)); \
	      case $$k in 0) v=1 ;; 1) v='"s"' ;; 2) v='[]' ;; esac; \
	      if [ $$j -eq 0 ]; then line="$$line$$v"; else line="$$line,$$v"; fi; \
	      j=$$((j + 1)); \
	    done; \
	    echo "$$line)"; \
	    i=$$((i + 1)); \
	  done; \
	} > $(TESTS)/sgen_limit.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/sgen_limit.sa >/dev/null 2>$(TESTS)/sgen_limit.err; then echo '[FAIL] seed exceeded specialization limit'; exit 1; fi
	@grep -q 'function/specialization limit is 512' $(TESTS)/sgen_limit.err
	@echo '[OK] seed generic specialization: num/str/list, multiple type parameters, nested/recursive/forward calls, annotations, aliasing, deduplication, deterministic output and diagnostics'
test-generics: test-seed-generics
native-test: test-seed-generics

.PHONY: test-native-generic-local
test-native-generic-local: $(NATIVE_BIN) $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(NATIVE_BIN) selfhost/seed_typed_loops_test.sa $(TESTS)/ngl_loops
	$(call assert-out,./$(TESTS)/ngl_loops,$(STL_WANT))
	./$(NATIVE_BIN) selfhost/seed_generics_extended_test.sa $(TESTS)/ngl_extended
	$(call assert-out,./$(TESTS)/ngl_extended,3\nhi\n2\nfirst\nsecond\n2\n8\nnested\n15\nxyxyxy\n3\n6\no\nk\n4\n5\n6)
	./$(NATIVE_BIN) selfhost/native_generic_local_test.sa $(TESTS)/ngl_native
	./$(SEED_MIN_BIN) selfhost/native_generic_local_test.sa > $(TESTS)/ngl_seed.c
	$(CC) -O2 -o $(TESTS)/ngl_seed $(TESTS)/ngl_seed.c
	./$(GEN2) selfhost/native_generic_local_test.sa $(TESTS)/ngl_gen2.c
	$(CC) -O2 -o $(TESTS)/ngl_gen2 $(TESTS)/ngl_gen2.c
	$(call assert-out,./$(TESTS)/ngl_native,9\nhello!\n3\nhello)
	$(call assert-out,./$(TESTS)/ngl_seed,9\nhello!\n3\nhello)
	$(call assert-out,./$(TESTS)/ngl_gen2,9\nhello!\n3\nhello)
	@for text in 'hold n: num = "bad"' 'hold xs: list = 3' 'hold s: str = "a"\nhold s: num = 2' 'hold x: other = 1' 'make f() -> num { hold x: num = "bad"\ngive 0 }\nshow f()' 'make f<T>(x:T)->T { hold local:T = "bad"\ngive x }\nshow f(1)' 'make f<T>(x:T)->T { give concat(x,"bad") }\nshow f(1)'; do \
	  printf '%b\n' "$$text" > $(TESTS)/ngl_bad.sa; \
	  if ./$(NATIVE_BIN) $(TESTS)/ngl_bad.sa $(TESTS)/ngl_bad 2>$(TESTS)/ngl_bad.err; then echo "[FAIL] native accepted wrong annotation/generic body: $$text"; exit 1; fi; \
	  grep -q 'native_aot:' $(TESTS)/ngl_bad.err || exit 1; \
	done
	@echo '[OK] native local annotations and demand-driven generic bodies: num/str/list, local T, string-only recursion, no unused numeric base, kind errors'
test-native-locals: test-native-generic-local
native-test: test-native-generic-local

.PHONY: test-gen2-forward
G2F_WANT := forward!\n2\n4\n1\n1\nzero
test-gen2-forward: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_forward_test.sa $(TESTS)/g2f.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -Werror=strict-prototypes -o $(TESTS)/g2f $(TESTS)/g2f.c
	./$(GEN1_MIN) selfhost/gen2_forward_test.sa $(TESTS)/g2f_g1.c
	cmp $(TESTS)/g2f.c $(TESTS)/g2f_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_forward_test.sa > $(TESTS)/g2f_seed.c
	$(CC) -O2 -o $(TESTS)/g2f_seed $(TESTS)/g2f_seed.c
	./$(NATIVE_BIN) selfhost/gen2_forward_test.sa $(TESTS)/g2f_native
	$(call assert-out,./$(TESTS)/g2f,$(G2F_WANT))
	$(call assert-out,./$(TESTS)/g2f_seed,$(G2F_WANT))
	$(call assert-out,./$(TESTS)/g2f_native,$(G2F_WANT))
	@echo '[OK] gen2 typed forward calls: string/list/numeric, mutual recursion, zero arguments; gen1/gen2 C identical and seed/native output parity'
test-typed-sig: test-gen2-forward
native-test: test-gen2-forward

.PHONY: test-gen2-function-scope
G2S_WANT := 12\n13\n11\n7\n8\n18\nglobal
test-gen2-function-scope: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_scope_test.sa $(TESTS)/g2s.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2s $(TESTS)/g2s.c
	./$(GEN1_MIN) selfhost/gen2_scope_test.sa $(TESTS)/g2s_g1.c
	cmp $(TESTS)/g2s.c $(TESTS)/g2s_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_scope_test.sa > $(TESTS)/g2s_seed.c
	$(CC) -O2 -o $(TESTS)/g2s_seed $(TESTS)/g2s_seed.c
	$(call assert-out,./$(TESTS)/g2s,$(G2S_WANT))
	$(call assert-out,./$(TESTS)/g2s_seed,$(G2S_WANT))
	@echo '[OK] gen2 function scope: isolated parameters/locals, sibling blocks with different kinds, elif, nested while/for and outer reassignment; seed output parity'
test-typed-sig: test-gen2-function-scope
native-test: test-gen2-function-scope

.PHONY: test-gen2-boolean-args
G2B_WANT := 1\n0\n1\n2\n1\n1\n0\nyes!\nno\n7\n9\ntrue false true_value\n4\n5
test-gen2-boolean-args: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_boolean_args_test.sa $(TESTS)/g2b.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2b $(TESTS)/g2b.c
	./$(GEN1_MIN) selfhost/gen2_boolean_args_test.sa $(TESTS)/g2b_g1.c
	cmp $(TESTS)/g2b.c $(TESTS)/g2b_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_boolean_args_test.sa > $(TESTS)/g2b_seed.c
	$(CC) -O2 -o $(TESTS)/g2b_seed $(TESTS)/g2b_seed.c
	./$(NATIVE_BIN) selfhost/gen2_boolean_args_test.sa $(TESTS)/g2b_native
	$(call assert-out,./$(TESTS)/g2b,$(G2B_WANT))
	$(call assert-out,./$(TESTS)/g2b_seed,$(G2B_WANT))
	$(call assert-out,./$(TESTS)/g2b_native,$(G2B_WANT))
	@printf 'make number(n: num) -> num {\n give n\n}\nshow number(true == false)\n' > $(TESTS)/g2b_compare.sa
	./$(GEN2) $(TESTS)/g2b_compare.sa $(TESTS)/g2b_compare.c
	$(CC) -O2 -o $(TESTS)/g2b_compare $(TESTS)/g2b_compare.c
	$(call assert-out,./$(TESTS)/g2b_compare,0)
	@echo '[OK] gen2 boolean call arguments: hold/show, nested/parenthesized calls, arithmetic, comparisons; strings, longer identifiers and boolean-named fields preserved'
test-typed-sig: test-gen2-boolean-args
native-test: test-gen2-boolean-args

.PHONY: test-gen2-generic-queue
test-gen2-generic-queue: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/seed_generics_extended_test.sa $(TESTS)/g2g_extended.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2g_extended $(TESTS)/g2g_extended.c
	$(call assert-out,./$(TESTS)/g2g_extended,3\nhi\n2\nfirst\nsecond\n2\n8\nnested\n15\nxyxyxy\n3\n6\no\nk\n4\n5\n6)
	./$(GEN1_MIN) selfhost/seed_generics_extended_test.sa $(TESTS)/g2g_extended_g1.c
	cmp $(TESTS)/g2g_extended.c $(TESTS)/g2g_extended_g1.c
	./$(GEN2) selfhost/gen2_generic_queue_test.sa $(TESTS)/g2g.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2g $(TESTS)/g2g.c
	./$(SEED_MIN_BIN) selfhost/gen2_generic_queue_test.sa > $(TESTS)/g2g_seed.c
	$(CC) -O2 -o $(TESTS)/g2g_seed $(TESTS)/g2g_seed.c
	./$(NATIVE_BIN) selfhost/gen2_generic_queue_test.sa $(TESTS)/g2g_native
	$(call assert-out,./$(TESTS)/g2g,3\ns\n2\n8)
	$(call assert-out,./$(TESTS)/g2g_seed,3\ns\n2\n8)
	$(call assert-out,./$(TESTS)/g2g_native,3\ns\n2\n8)
	@echo '[OK] gen2 generic queue: repeated nested requests, numeric/string/list variants, recursive extended fixture and function/parameter name collisions'
test-generics: test-gen2-generic-queue
native-test: test-gen2-generic-queue

.PHONY: test-gen2-list-return
G2LR_WANT := 0\n3\n3\n3\n4\n6\n0\n9\n0\n4\n0\n11\n12\n8
test-gen2-list-return: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_list_return_test.sa $(TESTS)/g2lr.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2lr $(TESTS)/g2lr.c
	./$(GEN1_MIN) selfhost/gen2_list_return_test.sa $(TESTS)/g2lr_g1.c
	cmp $(TESTS)/g2lr.c $(TESTS)/g2lr_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_list_return_test.sa > $(TESTS)/g2lr_seed.c
	$(CC) -O2 -o $(TESTS)/g2lr_seed $(TESTS)/g2lr_seed.c
	./$(NATIVE_BIN) selfhost/gen2_list_return_test.sa $(TESTS)/g2lr_native
	$(call assert-out,./$(TESTS)/g2lr,$(G2LR_WANT))
	$(call assert-out,./$(TESTS)/g2lr_seed,$(G2LR_WANT))
	$(call assert-out,./$(TESTS)/g2lr_native,$(G2LR_WANT))
	@for text in 'make f() -> num {\n give []\n}\nshow f()' 'make f() -> list {\n give ["bad"]\n}\nhold xs = f()' 'make f() -> list {\n give [[1]]\n}\nhold xs = f()' 'make f() -> list {\n give [1][0]\n}\nhold xs = f()'; do \
	  printf '%b\n' "$$text" > $(TESTS)/g2lr_bad.sa; \
	  ./$(GEN2) $(TESTS)/g2lr_bad.sa $(TESTS)/g2lr_bad.c > $(TESTS)/g2lr_bad.log; \
	  grep -q '^#error' $(TESTS)/g2lr_bad.c || { echo '[FAIL] gen2 accepted an invalid list return'; exit 1; }; \
	done
	@echo '[OK] gen2 list-literal returns: empty/numeric/expression elements, forward/generic functions, branch/loop timing, collision-free temporaries and diagnostics; seed/native parity'
test-typed-sig: test-gen2-list-return
native-test: test-gen2-list-return

.PHONY: test-gen2-list-args
G2LA_WANT := 0\n3\n1\n9\n2\n1\n9\n2\n3\n3\n2\n8\n-9\n0.5\n12\n[1,2] is text
test-gen2-list-args: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_list_args_test.sa $(TESTS)/g2la.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2la $(TESTS)/g2la.c
	./$(GEN1_MIN) selfhost/gen2_list_args_test.sa $(TESTS)/g2la_g1.c
	cmp $(TESTS)/g2la.c $(TESTS)/g2la_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_list_args_test.sa > $(TESTS)/g2la_seed.c
	$(CC) -O2 -o $(TESTS)/g2la_seed $(TESTS)/g2la_seed.c
	./$(NATIVE_BIN) selfhost/gen2_list_args_test.sa $(TESTS)/g2la_native
	$(call assert-out,./$(TESTS)/g2la,$(G2LA_WANT))
	$(call assert-out,./$(TESTS)/g2la_seed,$(G2LA_WANT))
	$(call assert-out,./$(TESTS)/g2la_native,$(G2LA_WANT))
	@printf 'show sx_index([8,9],1)\n' > $(TESTS)/g2la_index.sa
	./$(GEN2) $(TESTS)/g2la_index.sa $(TESTS)/g2la_index.c
	$(CC) -O2 -Werror=incompatible-pointer-types -o $(TESTS)/g2la_index $(TESTS)/g2la_index.c
	$(call assert-out,./$(TESTS)/g2la_index,9)
	@for expr in '["bad"]' '[[1]]' '[1,]' '[1+]' '[1 2]' '[()]' '[(1+2]' '[1)]' '[1.2.3]' '[-]' '[1][0]' '[1]+2'; do \
	  printf 'make size(xs: list) -> num {\n give len(xs)\n}\nshow size(%s)\n' "$$expr" > $(TESTS)/g2la_bad.sa; \
	  ./$(GEN2) $(TESTS)/g2la_bad.sa $(TESTS)/g2la_bad.c > $(TESTS)/g2la_bad.log; \
	  grep -q '^#error.*inline list arguments' $(TESTS)/g2la_bad.c || { echo "[FAIL] invalid/unsupported inline list accepted: $$expr"; exit 1; }; \
	done
	@echo '[OK] gen2 inline numeric list arguments: push/len/user/generic calls, multi-digit counts, fresh loop-condition allocation and diagnostics; shared fixture matches seed/native, direct list index builtin checked separately'
test-typed-sig: test-gen2-list-args
native-test: test-gen2-list-args

.PHONY: test-gen2-gc-roots
test-gen2-gc-roots: $(GEN2)
	@mkdir -p $(TESTS)
	$(CC) -O0 -o $(TESTS)/gen2_o0 $(GEN2_C)
	./$(TESTS)/gen2_o0 selfhost/gen2_list_return_test.sa $(TESTS)/gc_root_return_o0.c
	./$(GEN2) selfhost/gen2_list_return_test.sa $(TESTS)/gc_root_return_o2.c
	cmp $(TESTS)/gc_root_return_o0.c $(TESTS)/gc_root_return_o2.c
	./$(TESTS)/gen2_o0 selfhost/gen2_list_args_test.sa $(TESTS)/gc_root_args_o0.c
	./$(GEN2) selfhost/gen2_list_args_test.sa $(TESTS)/gc_root_args_o2.c
	cmp $(TESTS)/gc_root_args_o0.c $(TESTS)/gc_root_args_o2.c
	./$(GEN2) selfhost/gen2_gc_roots_test.sa $(TESTS)/gc_roots.c
	$(CC) -O0 -o $(TESTS)/gc_roots_o0 $(TESTS)/gc_roots.c
	$(CC) -O2 -o $(TESTS)/gc_roots_o2 $(TESTS)/gc_roots.c
	$(call assert-out,./$(TESTS)/gc_roots_o0,main-root\n3\n5\nfunction-root\n7\n_sx_gc_programx)
	$(call assert-out,./$(TESTS)/gc_roots_o2,main-root\n3\n5\nfunction-root\n7\n_sx_gc_programx)
	@echo '[OK] gen2 GC roots: caller-frame anchor, O0/O2 compiler output parity, 2000 explicit collections, live string/list/function roots and wrapper-name collisions'
test-typed-sig: test-gen2-gc-roots
native-test: test-gen2-gc-roots

.PHONY: test-gen2-list-arithmetic
G2LX_WANT := 7\n9\n2.66667\n17\n2\n5\n2\n6\n-20\n3\n3\n2\n3\n[1 + 2] stays text\n4.5\n7\n1
test-gen2-list-arithmetic: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_list_arithmetic_test.sa $(TESTS)/g2lx.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/g2lx $(TESTS)/g2lx.c
	./$(GEN1_MIN) selfhost/gen2_list_arithmetic_test.sa $(TESTS)/g2lx_g1.c
	cmp $(TESTS)/g2lx.c $(TESTS)/g2lx_g1.c
	./$(SEED_MIN_BIN) selfhost/gen2_list_arithmetic_test.sa > $(TESTS)/g2lx_seed.c
	$(CC) -O2 -o $(TESTS)/g2lx_seed $(TESTS)/g2lx_seed.c
	./$(NATIVE_BIN) selfhost/gen2_list_arithmetic_test.sa $(TESTS)/g2lx_native
	$(call assert-out,./$(TESTS)/g2lx,$(G2LX_WANT))
	$(call assert-out,./$(TESTS)/g2lx_seed,$(G2LX_WANT))
	$(call assert-out,./$(TESTS)/g2lx_native,$(G2LX_WANT))
	$(CC) -O0 -o $(TESTS)/g2lx_o0 $(TESTS)/g2lx.c
	$(call assert-out,./$(TESTS)/g2lx_o0,$(G2LX_WANT))
	@echo '[OK] gen2 inline list arithmetic: precedence, grouping, fractional division, signed operands, generic results, return/condition paths, fresh loop allocations; seed/native parity and O0/O2 programs'
test-typed-sig: test-gen2-list-arithmetic
native-test: test-gen2-list-arithmetic

.PHONY: test-return-paths
RETURN_PATHS_WANT := -1\n0\n1\n9\nyes } give //\nno { when\n1\n0\n2\n3\n8\ngeneric
test-return-paths: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN) $(SXDIAG_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/return_paths_test.sa $(TESTS)/return_paths.c
	./$(GEN1_MIN) selfhost/return_paths_test.sa $(TESTS)/return_paths_g1.c
	cmp $(TESTS)/return_paths.c $(TESTS)/return_paths_g1.c
	$(CC) -O2 -Werror=return-type -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/return_paths $(TESTS)/return_paths.c
	./$(SEED_MIN_BIN) selfhost/return_paths_test.sa > $(TESTS)/return_paths_seed.c
	$(CC) -O2 -Werror=return-type -o $(TESTS)/return_paths_seed $(TESTS)/return_paths_seed.c
	./$(NATIVE_BIN) selfhost/return_paths_test.sa $(TESTS)/return_paths_native
	$(call assert-out,./$(TESTS)/return_paths,$(RETURN_PATHS_WANT))
	$(call assert-out,./$(TESTS)/return_paths_seed,$(RETURN_PATHS_WANT))
	$(call assert-out,./$(TESTS)/return_paths_native,$(RETURN_PATHS_WANT))
	./$(SXDIAG_BIN) return ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-return
	@echo '[OK] return paths: exhaustive/nested branches, elif chains, suffix returns, early returns, num/str/list and generic functions; seed/gen2/native parity'
test-typed-sig: test-return-paths
native-test: test-return-paths

.PHONY: test-name-resolution
NAME_RESOLUTION_WANT := 4\n8\n9\n3\n4\nghost // { and missing() are only text\n5\n3\n4\ngeneric\n1\n2\no\nk
test-name-resolution: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN) $(SXDIAG_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/name_resolution_test.sa $(TESTS)/name_resolution.c
	./$(GEN1_MIN) selfhost/name_resolution_test.sa $(TESTS)/name_resolution_g1.c
	cmp $(TESTS)/name_resolution.c $(TESTS)/name_resolution_g1.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/name_resolution $(TESTS)/name_resolution.c
	./$(SEED_MIN_BIN) selfhost/name_resolution_test.sa > $(TESTS)/name_resolution_seed.c
	$(CC) -O2 -o $(TESTS)/name_resolution_seed $(TESTS)/name_resolution_seed.c
	./$(NATIVE_BIN) selfhost/name_resolution_test.sa $(TESTS)/name_resolution_native
	$(call assert-out,./$(TESTS)/name_resolution,$(NAME_RESOLUTION_WANT))
	$(call assert-out,./$(TESTS)/name_resolution_seed,$(NAME_RESOLUTION_WANT))
	$(call assert-out,./$(TESTS)/name_resolution_native,$(NAME_RESOLUTION_WANT))
	./$(SXDIAG_BIN) name ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-name
	@echo '[OK] name resolution: field labels/selectors, builtin-like bindings, quotes/comments, typed forward calls, generic calls and function scopes; positive seed/gen2/native parity'
test-typed-sig: test-name-resolution
native-test: test-name-resolution

.PHONY: test-inline-expressions
INLINE_EXPRESSIONS_WANT := 8\n9\n9\n4\n7\n2\n1\n0\n2.66667\n10\n4\n2\n11\n12\n3\n99\n5\n1\n1\n8\n4\n5\n4\n-2\n3
INLINE_SEQUENCE_WANT := 1\n2\n3\n3\n22\n2\n77\n0\n1\n2
test-inline-expressions: $(GEN2) $(GEN1_MIN) $(SEED_MIN_BIN) $(NATIVE_BIN) $(SXDIAG_BIN)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/inline_expressions_test.sa $(TESTS)/inline_expr.c
	./$(GEN1_MIN) selfhost/inline_expressions_test.sa $(TESTS)/inline_expr_g1.c
	cmp $(TESTS)/inline_expr.c $(TESTS)/inline_expr_g1.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/inline_expr $(TESTS)/inline_expr.c
	./$(SEED_MIN_BIN) selfhost/inline_expressions_test.sa > $(TESTS)/inline_expr_seed.c
	$(CC) -O2 -o $(TESTS)/inline_expr_seed $(TESTS)/inline_expr_seed.c
	./$(NATIVE_BIN) selfhost/inline_expressions_test.sa $(TESTS)/inline_expr_native
	$(call assert-out,./$(TESTS)/inline_expr,$(INLINE_EXPRESSIONS_WANT))
	$(call assert-out,./$(TESTS)/inline_expr_seed,$(INLINE_EXPRESSIONS_WANT))
	$(call assert-out,./$(TESTS)/inline_expr_native,$(INLINE_EXPRESSIONS_WANT))
	./$(GEN2) selfhost/inline_sequence_test.sa $(TESTS)/inline_seq.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/inline_seq $(TESTS)/inline_seq.c
	$(CC) -O0 -o $(TESTS)/inline_seq_o0 $(TESTS)/inline_seq.c
	./$(NATIVE_BIN) selfhost/inline_sequence_test.sa $(TESTS)/inline_seq_native
	$(call assert-out,./$(TESTS)/inline_seq,$(INLINE_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/inline_seq_o0,$(INLINE_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/inline_seq_native,$(INLINE_SEQUENCE_WANT))
	./$(SXDIAG_BIN) inline ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-inline
	@echo '[OK] typed inline expressions: variables, checked calls/generics, nested list consumers, indexing, modulo/comparisons and lexical kinds; shared fixture matches seed/native'
	@echo '[OK] inline sequencing: gen2 O0/O2 and native agree on left-to-right single evaluation, fresh loop conditions and generated-name collisions (seed checked separately by test-seed-list-sequence)'
test-typed-sig: test-inline-expressions
native-test: test-inline-expressions

.PHONY: test-inline-runtime
test-inline-runtime: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN)
	./$(GEN2) selfhost/inline_runtime_test.sa $(TESTS)/inline_runtime.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/inline_runtime $(TESTS)/inline_runtime.c
	./$(SEED_MIN_BIN) selfhost/inline_runtime_test.sa > $(TESTS)/inline_runtime_seed.c
	$(CC) -O2 -o $(TESTS)/inline_runtime_seed $(TESTS)/inline_runtime_seed.c
	./$(NATIVE_BIN) selfhost/inline_runtime_test.sa $(TESTS)/inline_runtime_native
	$(call assert-out,./$(TESTS)/inline_runtime,1\n2\n98\n2)
	$(call assert-out,./$(TESTS)/inline_runtime_seed,1\n2\n98\n2)
	$(call assert-out,./$(TESTS)/inline_runtime_native,1\n2\n98\n2)
	@echo '[OK] inline-only runtime dependencies: string comparison, concatenation/length, literal indexing and nested numeric-list consumers; seed/gen2/native parity'
test-inline-expressions: test-inline-runtime

.PHONY: test-seed-list-sequence
SEED_LIST_SEQUENCE_WANT := 2\n1\n11\n12\n26\n4\n5\n6\n7\n3\n42
test-seed-list-sequence: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/inline_sequence_test.sa > $(TESTS)/seq_shared_seed.c
	$(CC) -O0 -o $(TESTS)/seq_shared_seed_o0 $(TESTS)/seq_shared_seed.c
	$(CC) -O2 -o $(TESTS)/seq_shared_seed $(TESTS)/seq_shared_seed.c
	$(call assert-out,./$(TESTS)/seq_shared_seed_o0,$(INLINE_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/seq_shared_seed,$(INLINE_SEQUENCE_WANT))
	./$(SEED_MIN_BIN) selfhost/seed_list_sequence_test.sa > $(TESTS)/seq_recursive_seed.c
	$(CC) -O0 -o $(TESTS)/seq_recursive_seed_o0 $(TESTS)/seq_recursive_seed.c
	$(CC) -O2 -o $(TESTS)/seq_recursive_seed $(TESTS)/seq_recursive_seed.c
	./$(GEN2) selfhost/seed_list_sequence_test.sa $(TESTS)/seq_recursive_gen2.c
	$(CC) -O2 -o $(TESTS)/seq_recursive_gen2 $(TESTS)/seq_recursive_gen2.c
	./$(NATIVE_BIN) selfhost/seed_list_sequence_test.sa $(TESTS)/seq_recursive_native
	$(call assert-out,./$(TESTS)/seq_recursive_seed_o0,$(SEED_LIST_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/seq_recursive_seed,$(SEED_LIST_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/seq_recursive_gen2,$(SEED_LIST_SEQUENCE_WANT))
	$(call assert-out,./$(TESTS)/seq_recursive_native,$(SEED_LIST_SEQUENCE_WANT))
	@echo '[OK] seed list sequencing: O0/O2, nested and recursive constructors, mutable-list observations, loop conditions, source-name collisions; shared gen2/native order'
test-typed-sig: test-seed-list-sequence
native-test: test-seed-list-sequence

.PHONY: test-list-postfix
LIST_POSTFIX_WANT := 10\n4\n97\n20\n20\n6\n2\n9\n12\n3\n40\n50\n99\ntyped
test-list-postfix: $(GEN2) $(SEED_MIN_BIN) $(NATIVE_BIN) $(SXDIAG_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/list_postfix_test.sa > $(TESTS)/postfix_seed.c
	./$(GEN2) selfhost/list_postfix_test.sa $(TESTS)/postfix_gen2.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/postfix_seed $(TESTS)/postfix_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/postfix_gen2 $(TESTS)/postfix_gen2.c
	./$(NATIVE_BIN) selfhost/list_postfix_test.sa $(TESTS)/postfix_native
	$(call assert-out,./$(TESTS)/postfix_seed,$(LIST_POSTFIX_WANT))
	$(call assert-out,./$(TESTS)/postfix_gen2,$(LIST_POSTFIX_WANT))
	$(call assert-out,./$(TESTS)/postfix_native,$(LIST_POSTFIX_WANT))
	./$(SXDIAG_BIN) postfix ./$(SEED_MIN_BIN) ./$(GEN2) ./$(NATIVE_BIN) $(TESTS)/sxdiag-postfix
	@echo '[OK] inline nested numeric/string fields, grouped list postfix call arguments, indexed generic returns, expression-kind generic inference: seed/gen2/native parity'
test-typed-sig: test-list-postfix
native-test: test-list-postfix

# Seed-only lexical edge cases plus shared numeric string-read stress.
.PHONY: test-seed-borrow
test-seed-borrow: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) $(SXC_NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_borrow_test.sa > $(TESTS)/borrow.c
	$(CC) -O2 -o $(TESTS)/borrow $(TESTS)/borrow.c
	$(call assert-out,./$(TESTS)/borrow,6\nkeeper\nkeeper\nkeeper!?\nkeeper\nkeeper\nkeeper\nother\nkeeper\na\nb\nb!\nkeeper\nkeeper\nkeeper+\n7)
	@# Reads stay borrowed; potentially writable arguments keep their entry copy.
	@if grep -q -F 'source = sx_sb_from(source)' $(TESTS)/borrow.c; then echo '[FAIL] copied read-only source'; exit 1; fi
	@grep -q -F 'a = sx_sb_from(a)' $(TESTS)/borrow.c
	@grep -q -F 's = sx_sb_from(s)' $(TESTS)/borrow.c
	./$(SEED_MIN_BIN) selfhost/seed_borrow_stress.sa > $(TESTS)/borrow-stress.c
	$(CC) -O2 -o $(TESTS)/borrow-stress $(TESTS)/borrow-stress.c
	$(call assert-out,sh -c 'ulimit -v 131072; ./$(TESTS)/borrow-stress',16481\n16384\n97\n3\n7)
	@echo '[OK] seed read-only borrowing stress fits a 128 MiB address-space cap'
	./$(GEN2) selfhost/seed_borrow_stress.sa $(TESTS)/borrow-stress-g2.c
	$(CC) -O2 -o $(TESTS)/borrow-stress-g2 $(TESTS)/borrow-stress-g2.c
	$(call assert-out,./$(TESTS)/borrow-stress-g2,16481\n16384\n97\n3\n7)
	./$(NATIVE_BIN) selfhost/seed_borrow_stress.sa $(TESTS)/borrow-stress-native
	$(call assert-out,./$(TESTS)/borrow-stress-native,16481\n16384\n97\n3\n7)
	./$(GEN2) selfhost/seed_builder_registry_test.sa $(TESTS)/builder-registry.c >/dev/null
	./$(SXC_NATIVE_BIN) selfhost/seed_builder_registry_test.sa $(TESTS)/builder-registry
	$(call assert-out,./$(TESTS)/builder-registry,registry-ok)
	@echo '[OK] seed borrowing: read-only parameters, writable aliases/branches/binders/returns; 30000 reads of 16 KiB with live list (seed/gen2/native)'
test-stage2: test-seed-borrow
native-test: test-seed-borrow

# ---------------------------------------------------------------------------
# List-valued concrete struct fields are pointer fields, not inline copies.
# Seed-min/native retain their alias and native-GC coverage below. The shared
# legacy fixture now runs on all three backends. Gen2 also has a distinct
# `ftypes` list tag and emits `sx_list *`; its focused fixture separately
# proves direct literals/copies, typed field indexing/assignment,
# list-field conditions and `for v in p.xs`.  Generic Box<list> remains a
# deliberate cross-backend refusal.
# ---------------------------------------------------------------------------
.PHONY: test-list-struct-fields
LSF_WANT := 5\n2\n3\n5\n7\n11\n28\n5
test-list-struct-fields: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) test-gen2-list-struct-fields
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/list_struct_fields_test.sa > $(TESTS)/list_struct_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/list_struct_seed $(TESTS)/list_struct_seed.c
	$(call assert-out,./$(TESTS)/list_struct_seed,$(LSF_WANT))
	./$(GEN2) selfhost/list_struct_fields_test.sa $(TESTS)/list_struct_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/list_struct_gen2 $(TESTS)/list_struct_gen2.c
	$(call assert-out,./$(TESTS)/list_struct_gen2,$(LSF_WANT))
	./$(NATIVE_BIN) selfhost/list_struct_fields_test.sa $(TESTS)/list_struct_native
	$(call assert-out,./$(TESTS)/list_struct_native,$(LSF_WANT))
	./$(NATIVE_BIN) selfhost/list_struct_fields_gc_test.sa $(TESTS)/list_struct_gc
	$(call assert-out,./$(TESTS)/list_struct_gc,gc-ok\n5\n4\n5\n6\n7\n8)
	@# A field's first kind is a contract: it cannot later switch number/list.
	@printf 'struct P { xs }\nhold p = P { xs: [1] }\nhold q = P { xs: 2 }\n' > $(TESTS)/list_struct_conflict.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/list_struct_conflict.sa >$(TESTS)/list_struct_conflict_seed.c 2>$(TESTS)/list_struct_conflict_seed.err; then \
	  echo '[FAIL] seed-min accepted a list/number struct-field conflict'; exit 1; fi
	@grep -q 'earlier literal' $(TESTS)/list_struct_conflict_seed.err || { echo '[FAIL] seed-min list-field conflict was unclear'; cat $(TESTS)/list_struct_conflict_seed.err; exit 1; }
	@if ./$(NATIVE_BIN) $(TESTS)/list_struct_conflict.sa $(TESTS)/list_struct_conflict_native >$(TESTS)/list_struct_conflict_native.out 2>$(TESTS)/list_struct_conflict_native.err; then \
	  echo '[FAIL] native accepted a list/number struct-field conflict'; exit 1; fi
	@grep -q 'two different types' $(TESTS)/list_struct_conflict_native.err || { echo '[FAIL] native list-field conflict was unclear'; cat $(TESTS)/list_struct_conflict_native.err; exit 1; }
	@echo '[OK] list struct fields: shared seed-min/gen2/native alias+iteration output; native GC tracing; focused gen2 layout/literal/copy/index/write/condition coverage'

# Gen2-only detail fixture.  The seed-min parser deliberately does not accept
# direct dotted assignment (`q.xs[0] = ...`), so this target makes no false
# three-way parity claim; seed/native parity remains in test-list-struct-fields
# above.  Every accepted gen2 program is compiled with strict C type warnings.
.PHONY: test-gen2-list-struct-fields
GLSF_WANT := 10\n20\n11\n3\n30\n61\n20\n77\n88\n61
test-gen2-list-struct-fields: $(GEN2)
	@mkdir -p $(TESTS)
	./$(GEN2) selfhost/gen2_list_struct_fields_test.sa $(TESTS)/gen2_list_struct.c >/dev/null
	@if grep -q '#error sayanox-min:' $(TESTS)/gen2_list_struct.c; then \
	  echo '[FAIL] gen2 rejected its concrete list-field fixture'; head -8 $(TESTS)/gen2_list_struct.c; exit 1; fi
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gen2_list_struct $(TESTS)/gen2_list_struct.c
	$(call assert-out,./$(TESTS)/gen2_list_struct,$(GLSF_WANT))
	@grep -q -F 'typedef struct { sx_list *xs; char *label; } Packet;' $(TESTS)/gen2_list_struct.c \
	  || { echo '[FAIL] gen2 did not emit sx_list * for Packet.xs'; exit 1; }
	@grep -q -F 'typedef struct { Packet p; } Envelope;' $(TESTS)/gen2_list_struct.c \
	  || { echo '[FAIL] gen2 lost the nested concrete Packet layout'; exit 1; }
	@grep -q -F 'q.xs = sx_lset(q.xs, 0.0, 11.0);' $(TESTS)/gen2_list_struct.c \
	  || { echo '[FAIL] gen2 did not lower list-field assignment through sx_lset'; exit 1; }
	@grep -q -F 'sx_lget((q).xs,(sx_llen((q).xs) - 1.0))' $(TESTS)/gen2_list_struct.c \
	  || { echo '[FAIL] gen2 did not type/lower list-field indexing with len()'; exit 1; }
	@grep -q -F 'for (double __sx_ix = 0.0; __sx_ix < sx_llen(__sx_fv' $(TESTS)/gen2_list_struct.c \
	  || { echo '[FAIL] gen2 did not lower for v in p.xs as a list loop'; exit 1; }
	@# Kind changes must still stop at a language #error, not silently alter C layout.
	@printf 'struct P { xs }\nhold p = P { xs: [1] }\nhold q = P { xs: 2 }\n' > $(TESTS)/gen2_list_struct_conflict.sa
	./$(GEN2) $(TESTS)/gen2_list_struct_conflict.sa $(TESTS)/gen2_list_struct_conflict.c >$(TESTS)/gen2_list_struct_conflict.msg
	@grep -q -F '#error sayanox-min: struct field is used with two different value kinds' $(TESTS)/gen2_list_struct_conflict.c \
	  || { echo '[FAIL] gen2 accepted a list/number field-kind conflict'; exit 1; }
	@grep -q -F 'two different value kinds' $(TESTS)/gen2_list_struct_conflict.msg \
	  || { echo '[FAIL] gen2 list-field conflict diagnostic was unclear'; cat $(TESTS)/gen2_list_struct_conflict.msg; exit 1; }
	@# Unimplemented direct push and whole-list show stay explicit source errors,
	@# rather than compiling pointer misuse while aliases remain the supported path.
	@printf 'struct P { xs }\nhold p = P { xs: [1] }\npush(p.xs, 2)\n' > $(TESTS)/gen2_list_struct_push_bad.sa
	./$(GEN2) $(TESTS)/gen2_list_struct_push_bad.sa $(TESTS)/gen2_list_struct_push_bad.c >$(TESTS)/gen2_list_struct_push_bad.msg
	@grep -q -F '#error sayanox-min: push statement:' $(TESTS)/gen2_list_struct_push_bad.c \
	  || { echo '[FAIL] gen2 direct push on a list field was not a language refusal'; exit 1; }
	@printf 'struct P { xs }\nhold p = P { xs: [1] }\nshow p.xs\n' > $(TESTS)/gen2_list_struct_show_bad.sa
	./$(GEN2) $(TESTS)/gen2_list_struct_show_bad.sa $(TESTS)/gen2_list_struct_show_bad.c >$(TESTS)/gen2_list_struct_show_bad.msg
	@grep -q -F '#error sayanox-min: show value cannot be a list' $(TESTS)/gen2_list_struct_show_bad.c \
	  || { echo '[FAIL] gen2 whole list-field show was not a language refusal'; exit 1; }
	@printf 'hold xs = [1]\nshow xs\n' > $(TESTS)/gen2_list_direct_show_bad.sa
	./$(GEN2) $(TESTS)/gen2_list_direct_show_bad.sa $(TESTS)/gen2_list_direct_show_bad.c >$(TESTS)/gen2_list_direct_show_bad.msg
	@grep -q -F '#error sayanox-min: show value cannot be a list' $(TESTS)/gen2_list_direct_show_bad.c \
	  || { echo '[FAIL] gen2 direct whole-list show was not a language refusal'; exit 1; }
	@printf 'struct P { xs }\nhold p = P { xs: [1] }\nwhen p.xs {\n  show 1\n}\n' > $(TESTS)/gen2_list_struct_cond_bad.sa
	./$(GEN2) $(TESTS)/gen2_list_struct_cond_bad.sa $(TESTS)/gen2_list_struct_cond_bad.c >$(TESTS)/gen2_list_struct_cond_bad.msg
	@grep -q -F '#error sayanox-min: a list-valued struct field cannot be a condition' $(TESTS)/gen2_list_struct_cond_bad.c \
	  || { echo '[FAIL] gen2 whole list-field condition was not a language refusal'; exit 1; }
	@echo '[OK] gen2 concrete list fields: sx_list pointer layout, literal/copy aliasing, indexed read/write, len-index/condition lowering, nested layout and for p.xs; conflicts and unsupported direct push/show/whole-condition refuse clearly'

test-stage2: test-list-struct-fields
native-test: test-list-struct-fields

# Finite list-alias budget, not a claim that dropped seed lists are reclaimed.
.PHONY: test-seed-list-budget test-seed-sanitize test-seed-bootstrap-budget
test-seed-list-budget: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_list_lifetime_stress.sa > $(TESTS)/seed-list-budget.c
	$(CC) -O2 -o $(TESTS)/seed-list-budget $(TESTS)/seed-list-budget.c
	$(call assert-out,sh -c 'ulimit -v 32768; ./$(TESTS)/seed-list-budget',20001\n7\n0\n19999\n20001)
	@echo '[OK] seed list aliases survive 20000 pushes/returns and reallocations inside 32 MiB (finite workload, no list reclamation claim)'

test-seed-gc: test-seed-list-budget

# ---------------------------------------------------------------------------
# test-seed-collector: the seed collector itself, measured on three backends.
#
# selfhost/seed_gc_drop.sa drops 4,000,000 temporaries that no assignment can
# ever free (the freeing wrapper only sees the variable being reassigned, and
# nothing here is), reads a borrowed read-only parameter in the same loop, and
# holds a 512 KiB string the loop never touches -- reachable only from the
# frame below, so it survives only if the root scan really walks the stack.
# Seed-min, gen2 and native print the same seven lines inside a 64 MiB address
# space. Without a collector that fixture needs ~256 MiB of garbage: the same
# program built by the pre-collector seed died with `sx: out of memory`.
#
# `auto` on line four is the load-bearing one: gc_runs() is already non-zero
# BEFORE the explicit gc(), i.e. all three runtimes collected on their own.
# ---------------------------------------------------------------------------
SGC_DROP_WANT := 524288\n4.88e+08\n1\nauto\n524288\n97\n112
.PHONY: test-seed-collector
test-seed-collector: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/seed_gc_drop.sa > $(TESTS)/sgc_drop_ms.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgc_drop_ms $(TESTS)/sgc_drop_ms.c
	./$(GEN2) selfhost/seed_gc_drop.sa $(TESTS)/sgc_drop_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sgc_drop_g2 $(TESTS)/sgc_drop_g2.c
	@# the anchor, the entry function it sits above, the trigger, the ASan opt-out
	grep -q -F 'sx_gc_init((void*)&sx_gcanchor);' $(TESTS)/sgc_drop_ms.c
	grep -q -F 'static int sx_prog(void){' $(TESTS)/sgc_drop_ms.c
	grep -q -F 'if(sx_gc_bytes+need>sx_gc_thresh) sx_gc_collect();' $(TESTS)/sgc_drop_ms.c
	grep -q -F 'no_sanitize_address' $(TESTS)/sgc_drop_ms.c
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_drop_ms',$(SGC_DROP_WANT))
	$(call assert-out,sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_drop_g2',$(SGC_DROP_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/seed_gc_drop.sa $(TESTS)/sgc_drop_native || exit 1; \
	  sh -c 'ulimit -v 65536; ./$(TESTS)/sgc_drop_native' > $(TESTS)/sgc_drop_native.out || exit 1; \
	  ./$(TESTS)/sgc_drop_ms > $(TESTS)/sgc_drop_ms.out || exit 1; \
	  cmp $(TESTS)/sgc_drop_ms.out $(TESTS)/sgc_drop_native.out \
	    || { echo '[FAIL] native collector output differs from seed-min'; exit 1; }; \
	  echo '[OK] native runs the same fixture with the same output'; \
	else echo '[SKIP] native collector parity: native_aot not built'; fi
	@echo '[OK] seed collector: 4,000,000 dropped temporaries, a borrowed read and an untouched 512 KiB live string inside 64 MiB -- seed-min, gen2 and native print the same seven lines'

test-seed-gc: test-seed-collector

# Explicit opt-in: sanitizer runtime/compiler support is NOT a bootstrap dep.
# LeakSanitizer is disabled because seed locals/temporaries/lists leak by design.
# No address-space limit here: ASan reserves a large virtual shadow mapping.
SANITIZER_FLAGS ?= -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -fno-pie -no-pie
test-seed-sanitize: test-seed-borrow test-seed-list-budget test-seed-collector
	@set -e; for name in borrow borrow-stress seed-list-budget sgc_drop_ms; do \
	  $(CC) $(SANITIZER_FLAGS) -o $(TESTS)/$$name-asan $(TESTS)/$$name.c; \
	  ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 ./$(TESTS)/$$name-asan > $(TESTS)/$$name-asan.out; \
	  ./$(TESTS)/$$name > $(TESTS)/$$name-plain.out; \
	  cmp $(TESTS)/$$name-plain.out $(TESTS)/$$name-asan.out; \
	done
	$(CC) $(SANITIZER_FLAGS) -o $(TESTS)/builder-registry-asan $(TESTS)/builder-registry.c
	$(call assert-out,env ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 UBSAN_OPTIONS=halt_on_error=1 ./$(TESTS)/builder-registry-asan,registry-ok)
	@echo '[OK] seed ASan/UBSan: aliases/returns/recursion, borrowed reads, list realloc/aliases, a collecting 4M-drop churn, 32 registry reuse cycles; leak detection explicitly OFF'

# Run AFTER true-selfhost. Recompile the real compiler under a finite process
# address-space cap and compare with its uncapped gen2 C artifact. The cap was
# 1536 MiB while the seed had no collector. Measured 2026-10-22, the same
# compile peaks at 29,768 KiB RSS and 26 MB of address space with the seed
# collector (1,278,704 KiB before it), so the cap is now 64 MiB -- still a
# budget for THIS input, not a bounded-heap claim for arbitrary programs.
test-seed-bootstrap-budget:
	@test -x $(GEN1_MIN) && test -s $(GEN2_C) || { echo 'run make true-selfhost first'; exit 1; }
	@mkdir -p $(TESTS)
	sh -c 'ulimit -v 65536; exec ./$(GEN1_MIN) $(MIN_SA) $(TESTS)/budget-gen2.c' > $(TESTS)/budget-gen2.out
	cmp $(GEN2_C) $(TESTS)/budget-gen2.c
	@echo '[OK] gen1-min compiled the current compiler inside a 64 MiB address space (1536 MiB before the seed collector); output identical to uncapped gen2 C (finite input budget only)'

# Permanent contract of this bootstrap dialect, not a promise of recursive GC
# layouts. Both public type gates must exercise the same negative matrix.
.PHONY: test-generic-struct-limits
test-generic-struct-limits: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) tools/sxsuite
	CC='$(CC)' ./tools/sxsuite generic_struct_limits

test-generic-structs test-type-refusals: test-generic-struct-limits

# ---------------------------------------------------------------------------
# test-generic-structs-nested: a type argument may be `list` or another
# instantiation (2026-10-22). `Box<Box<num>>` is `Box__Box__n` and its field
# holds a `Box__n`, so this gate also depends on gen2 accepting a struct-typed
# struct field (test-struct-field-struct). The inner instantiation is always
# created first, which is what puts the mangled typedefs in an order C
# accepts; the gate pins all seven of them in both emitted C files, in that
# order, on top of three-way byte-identical output.
#
# Mangling: single letters run together while every argument is primitive
# (`Pair<num, str>` stays `Pair__ns`), '_' separates them as soon as one is
# nested (`Pair<Box<num>, str>` is `Pair__Box__n_s`).
# ---------------------------------------------------------------------------
.PHONY: test-generic-structs-nested
test-generic-structs-nested: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/generic_struct_nested.sa > $(TESTS)/gsn_ms.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gsn_ms $(TESTS)/gsn_ms.c
	./$(GEN2) selfhost/generic_struct_nested.sa $(TESTS)/gsn_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/gsn_g2 $(TESTS)/gsn_g2.c
	$(call assert-out,./$(TESTS)/gsn_ms,7\n41\n7\n3\n4\n7\n7\nouter\n9\nnine\ninner)
	$(call assert-out,./$(TESTS)/gsn_g2,7\n41\n7\n3\n4\n7\n7\nouter\n9\nnine\ninner)
	@# the mangled layouts, and the order a C compiler needs them in
	@for f in $(TESTS)/gsn_ms.c $(TESTS)/gsn_g2.c; do \
	  grep -q -F 'typedef struct { double v; } Box__n;' $$f || { echo "[FAIL] $$f has no Box__n"; exit 1; }; \
	  grep -q -F 'typedef struct { Box__n v; } Box__Box__n;' $$f || { echo "[FAIL] $$f has no Box__Box__n"; exit 1; }; \
	  grep -q -F 'typedef struct { Box__Box__n v; } Box__Box__Box__n;' $$f || { echo "[FAIL] $$f has no Box__Box__Box__n"; exit 1; }; \
	  grep -q -F 'typedef struct { sx_list *v; } Box__l;' $$f || { echo "[FAIL] $$f has no Box__l (list type argument)"; exit 1; }; \
	  grep -q -F 'typedef struct { char *v; } Box__s;' $$f || { echo "[FAIL] $$f has no Box__s"; exit 1; }; \
	  grep -q -F 'typedef struct { Box__n a; char *b; } Pair__Box__n_s;' $$f || { echo "[FAIL] $$f has no Pair__Box__n_s"; exit 1; }; \
	  grep -q -F 'typedef struct { double a; char *b; } Pair__ns;' $$f || { echo "[FAIL] $$f still has to spell Pair<num, str> as Pair__ns"; exit 1; }; \
	  inner=`grep -n -F '} Box__n;' $$f | cut -d: -f1`; \
	  outer=`grep -n -F '} Box__Box__n;' $$f | cut -d: -f1`; \
	  [ $$inner -lt $$outer ] || { echo "[FAIL] $$f declares Box__Box__n before Box__n"; exit 1; }; \
	done
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/generic_struct_nested.sa $(TESTS)/gsn_nat >/dev/null \
	    || { echo "[FAIL] native refused a nested generic instantiation"; exit 1; }; \
	  ./$(TESTS)/gsn_nat > $(TESTS)/gsn_nat.out; \
	  ./$(TESTS)/gsn_ms > $(TESTS)/gsn_ms.out; \
	  cmp $(TESTS)/gsn_ms.out $(TESTS)/gsn_nat.out \
	    || { echo "[FAIL] native output differs from seed-min"; exit 1; }; \
	  echo "[OK] native: the same nested instantiations print the same bytes as seed-min"; \
	else echo "[SKIP] native_aot not built"; fi
	@echo '[OK] nested generic structs: Box<Box<num>>, Box<Box<Box<num>>>, Box<list> and Pair<Box<num>, str> are concrete types on seed-min, gen2 and native, with the inner instantiation declared first'

test-generic-structs test-type-refusals: test-generic-structs-nested

# ---------------------------------------------------------------------------
# test-full-language-expr: the last two broader-language readiness probes
# (docs/FULL_LANGUAGE_SELFHOST.md, selfhost/full_language_tests/README.md).
#
#   * a struct literal field may be a whole checked expression
#     (`Size { bytes: len(text) + 1 }`, `(2 + 3) * 4`, `head + "anox"`)
#   * an index may call a function the program declared with `-> num`
#     (`values[offset()]`, `values[twice(offset()) + 1]`)
#
# seed-min and native already accepted both; gen2 refused them until
# 2026-10-22, which is why `make test-full-language-readiness` counted four
# unmet checks across gen2 and gen3. The fixture is the parity proof -- the
# same eleven lines from all three backends -- and the greps pin the lowered
# gen2 C, because the layout and the call ARE the claim.
#
# Passing these probes is NOT a full-language self-host claim:
# `true-selfhost-full` still fails closed for want of a reviewed language
# specification, and this gate asserts that too.
# ---------------------------------------------------------------------------
FLE_WANT := 4\n20\n2\n4\n7\nsayanox\n9\n11\n13\n11\n11
.PHONY: test-full-language-expr
test-full-language-expr: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/full_language_expr.sa > $(TESTS)/fle_ms.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/fle_ms $(TESTS)/fle_ms.c
	./$(GEN2) selfhost/full_language_expr.sa $(TESTS)/fle_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/fle_g2 $(TESTS)/fle_g2.c
	$(call assert-out,./$(TESTS)/fle_ms,$(FLE_WANT))
	$(call assert-out,./$(TESTS)/fle_g2,$(FLE_WANT))
	@# the lowered gen2 C: the field holds the expression, the index holds the call
	@grep -q -F 'Size one = ((Size){(sx_len(text) + 1.0)});' $(TESTS)/fle_g2.c \
	  || { echo "[FAIL] gen2 no longer lowers a len() field expression"; exit 1; }
	@grep -q -F 'Size two = ((Size){(((2.0 + 3.0)) * 4.0)});' $(TESTS)/fle_g2.c \
	  || { echo "[FAIL] gen2 no longer lowers a parenthesised field expression"; exit 1; }
	@grep -q -F 'Size five = ((Size){(offset() + twice(3.0))});' $(TESTS)/fle_g2.c \
	  || { echo "[FAIL] gen2 no longer lowers declared calls in a field expression"; exit 1; }
	@grep -q -F 'Label tag = ((Label){sx_cat(head,"anox")});' $(TESTS)/fle_g2.c \
	  || { echo "[FAIL] gen2 no longer gives a string expression a string field"; exit 1; }
	@grep -q -F 'sx_lget(values,twice(offset()))' $(TESTS)/fle_g2.c \
	  || { echo "[FAIL] gen2 no longer lowers a call inside an index"; exit 1; }
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/full_language_expr.sa $(TESTS)/fle_nat >/dev/null \
	    || { echo "[FAIL] native refused the expression fixture"; exit 1; }; \
	  ./$(TESTS)/fle_nat > $(TESTS)/fle_nat.out; \
	  ./$(TESTS)/fle_ms > $(TESTS)/fle_ms.out; \
	  cmp $(TESTS)/fle_ms.out $(TESTS)/fle_nat.out \
	    || { echo "[FAIL] native output differs from seed-min"; exit 1; }; \
	  echo "[OK] native: the same expressions and index calls print the same bytes as seed-min"; \
	else echo "[SKIP] native_aot not built"; fi
	@# refusals that must survive: an unknown function and a wrong argument
	@# count in an index are refused by every backend
	@printf 'hold values = [7, 9]\nshow values[nope()]\n' > $(TESTS)/fle_unknown.sa
	@printf 'make two(a: num, b: num) -> num {\n  give a + b\n}\nhold values = [7, 9]\nshow values[two(1)]\n' > $(TESTS)/fle_arity.sa
	@printf 'make tag() -> str {\n  give "a"\n}\nhold values = [7, 9]\nshow values[tag()]\n' > $(TESTS)/fle_strcall.sa
	@for f in fle_unknown fle_arity; do \
	  if ./$(SEED_MIN_BIN) $(TESTS)/$$f.sa > $(TESTS)/$$f.ms.c 2> $(TESTS)/$$f.ms.err; then \
	    echo "[FAIL] seed-min accepted $$f"; exit 1; fi; \
	  ./$(GEN2) $(TESTS)/$$f.sa $(TESTS)/$$f.g2.c > /dev/null 2>&1 || true; \
	  grep -q -F '#error sayanox-min:' $(TESTS)/$$f.g2.c \
	    || { echo "[FAIL] gen2 accepted $$f"; exit 1; }; \
	  if [ -x $(NATIVE_BIN) ]; then \
	    if ./$(NATIVE_BIN) $(TESTS)/$$f.sa $(TESTS)/$$f.nat > $(TESTS)/$$f.nat.err 2>&1; then \
	      echo "[FAIL] native accepted $$f"; exit 1; fi; \
	  fi; \
	done
	@echo '[OK] an index call is checked: an unknown function and a wrong argument count are refused by seed-min, gen2 and native'
	@# a string-returning call as an index: gen2 and native name it; seed-min
	@# does not check it and emits C that will not compile (documented)
	@./$(GEN2) $(TESTS)/fle_strcall.sa $(TESTS)/fle_strcall.g2.c > /dev/null 2>&1 || true
	@grep -q -F '#error sayanox-min:' $(TESTS)/fle_strcall.g2.c \
	  || { echo "[FAIL] gen2 accepted a string-returning call as an index"; exit 1; }
	@./$(SEED_MIN_BIN) $(TESTS)/fle_strcall.sa > $(TESTS)/fle_strcall.ms.c 2>/dev/null || true
	@if $(CC) -O2 -o $(TESTS)/fle_strcall_ms $(TESTS)/fle_strcall.ms.c 2>/dev/null; then \
	  echo "[FAIL] seed-min's string-index C compiled; this divergence is documented as not compiling"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/fle_strcall.sa $(TESTS)/fle_strcall.nat > $(TESTS)/fle_strcall.nat.err 2>&1; then \
	    echo "[FAIL] native accepted a string-returning call as an index"; exit 1; fi; \
	fi
	@echo '[OK] a string-returning call as an index: refused by gen2 and native; seed-min emits C that cannot compile (documented divergence)'
	@# the claim this does NOT make: true-selfhost-full still ends in a
	@# refusal and a non-zero exit, checked statically here because running it
	@# would re-enter the whole bootstrap
	@grep -q -F "refusing a full-language claim" Makefile \
	  || { echo "[FAIL] true-selfhost-full no longer refuses the full-language claim"; exit 1; }
	@grep -A 4 '^true-selfhost-full:' Makefile | grep -q -F 'exit 1' \
	  || { echo "[FAIL] true-selfhost-full no longer fails closed"; exit 1; }
	@echo '[OK] expression fields and index calls: seed-min, gen2 and native agree on eleven lines; full-language self-host is still NOT claimed (true-selfhost-full fails closed)'

.PHONY: test-stdlib-list-search
test-stdlib-list-search: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_list_search_test.sa > $(TESTS)/stdlib_search_seed.c
	./$(GEN2) selfhost/stdlib_list_search_test.sa $(TESTS)/stdlib_search_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stdlib_search_seed $(TESTS)/stdlib_search_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stdlib_search_gen2 $(TESTS)/stdlib_search_gen2.c
	./$(NATIVE_BIN) selfhost/stdlib_list_search_test.sa $(TESTS)/stdlib_search_native
	$(call assert-out,./$(TESTS)/stdlib_search_seed,1\nlist-search-done)
	$(call assert-out,./$(TESTS)/stdlib_search_gen2,1\nlist-search-done)
	$(call assert-out,./$(TESTS)/stdlib_search_native,1\nlist-search-done)
	@echo '[OK] offline list search/merge/rotation: seed-min/gen2/native; empty/singleton/duplicates, linear bound oracle, negative/wrapped shifts, fresh result aliases'

test-stdlib-modules: test-stdlib-list-search
native-test: test-stdlib-list-search

.PHONY: test-sxpkg-transfer-hardening
test-sxpkg-transfer-hardening: sxpkg tools/sxpkg_transfer_test
	./tools/sxpkg_transfer_test

test-sxpkg-online-optin: test-sxpkg-transfer-hardening

.PHONY: test-lsp-workspace
test-lsp-workspace: $(LSP_BIN) $(SXC_NATIVE_BIN) tools/lsp_workspace_test.sa
	@mkdir -p $(TESTS)
	./$(SXC_NATIVE_BIN) tools/lsp_workspace_test.sa $(TESTS)/lsp-workspace-test
	@rm -rf '$(TESTS)/lsp workspace' && mkdir -p '$(TESTS)/lsp workspace'
	./$(TESTS)/lsp-workspace-test '$(CURDIR)/$(LSP_BIN)' '$(CURDIR)/$(TESTS)/lsp workspace'
	@echo '[OK] LSP folder index: framed Sayanox client, unopened files, overlays, refresh, URI/path boundaries and file cap; no interpreter'

test-lsp test-lsp-robust: test-lsp-workspace

.PHONY: test-full-language-readiness
test-full-language-readiness: $(GEN2) tools/sxsuite
	@CC='$(CC)' ./tools/sxsuite full_lang_ready

.PHONY: test-struct-functions
test-struct-functions: $(GEN2) tools/sxsuite
	@CC='$(CC)' ./tools/sxsuite struct_fn

.PHONY: test-string-interpolation
test-string-interpolation: $(GEN2) tools/sxsuite
	@CC='$(CC)' ./tools/sxsuite stage2_interp

# ---------------------------------------------------------------------------
# test-stdlib-crypto: stdlib/crypto.sa -- SHA-256 and HMAC-SHA256 written in
# Sayanox, on seed-min, gen2 and native.
#
# Every expected digest below is a PUBLISHED vector: FIPS 180-4 for the three
# SHA-256 messages, RFC 4231 cases 1-3 for HMAC. The five padding-boundary
# lengths (55, 56, 63, 64, 65) and the byte-list message are cross-checked
# against the host `sha256sum` when one exists, so this gate is not just the
# implementation agreeing with itself. The module uses NO bit_* builtin -- the
# 32-bit operations are arithmetic on doubles -- which is why seed-min and
# native can run it at all.
# ---------------------------------------------------------------------------
CRY_WANT := e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855\nba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\n248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1\n9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318\nb35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a\n7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34\nffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb\n635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0\n26a66b061e8f48f39927c312f25293959729eee95978e2892d49d3512a5cc092\n32\nb0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7\n5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843\n60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54\n00\nff\nab\n3\n255\n0\n0\n1\n0\n0\n00000000\nffffffff\nf0f00000\nffffffff\n80000000\n0000000f\nfffffff0\n00000001\n0000003d\ncrypto-done

.PHONY: test-stdlib-crypto
test-stdlib-crypto: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_crypto_test.sa > $(TESTS)/crypto_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/crypto_seed $(TESTS)/crypto_seed.c
	./$(GEN2) selfhost/stdlib_crypto_test.sa $(TESTS)/crypto_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/crypto_gen2 $(TESTS)/crypto_gen2.c
	$(call assert-out,./$(TESTS)/crypto_seed,$(CRY_WANT))
	$(call assert-out,./$(TESTS)/crypto_gen2,$(CRY_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_crypto_test.sa $(TESTS)/crypto_native || exit 1; \
	  ./$(TESTS)/crypto_native > $(TESTS)/crypto_native.out || exit 1; \
	  ./$(TESTS)/crypto_seed > $(TESTS)/crypto_seed.out || exit 1; \
	  cmp $(TESTS)/crypto_seed.out $(TESTS)/crypto_native.out || { echo '[FAIL] native crypto differs from seed-min'; exit 1; }; \
	  echo '[OK] native crypto parity (SHA-256 + HMAC-SHA256)'; \
	else echo '[SKIP] native crypto parity: native_aot not built'; fi
	@# ---- independent oracle: the host sha256sum, when there is one --------
	@if command -v sha256sum >/dev/null 2>&1; then \
	  printf 'abc' > $(TESTS)/crypto_abc.bin; \
	  printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > $(TESTS)/crypto_55.bin; \
	  printf 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' > $(TESTS)/crypto_56.bin; \
	  __a=$$(sha256sum $(TESTS)/crypto_abc.bin | cut -d' ' -f1); \
	  __b=$$(sha256sum $(TESTS)/crypto_55.bin | cut -d' ' -f1); \
	  __c=$$(sha256sum $(TESTS)/crypto_56.bin | cut -d' ' -f1); \
	  printf 'use "stdlib/crypto.sa"\nshow cx_sha256(read_file("$(TESTS)/crypto_abc.bin"))\nshow cx_sha256(read_file("$(TESTS)/crypto_55.bin"))\nshow cx_sha256(read_file("$(TESTS)/crypto_56.bin"))\n' > $(TESTS)/crypto_oracle.sa; \
	  ./$(GEN2) $(TESTS)/crypto_oracle.sa $(TESTS)/crypto_oracle.c >/dev/null; \
	  $(CC) -O2 -o $(TESTS)/crypto_oracle $(TESTS)/crypto_oracle.c; \
	  printf '%s\n%s\n%s\n' "$$__a" "$$__b" "$$__c" > $(TESTS)/crypto_oracle.want; \
	  ./$(TESTS)/crypto_oracle > $(TESTS)/crypto_oracle.got; \
	  cmp $(TESTS)/crypto_oracle.want $(TESTS)/crypto_oracle.got || { echo '[FAIL] Sayanox SHA-256 disagrees with the host sha256sum'; exit 1; }; \
	  echo '[OK] independent oracle: host sha256sum agrees on 3 messages read from disk'; \
	else echo '[SKIP] independent oracle: no sha256sum on this host'; fi
	@# ---- a changed byte must change the digest (the fixture pins 0/1) -----
	@printf 'use "stdlib/crypto.sa"\nshow cx_eq_hex(cx_sha256("the quick brown fox"), cx_sha256("the quick brown fox"))\nshow cx_eq_hex(cx_sha256("the quick brown fox"), cx_sha256("the quick brown fox."))\nshow cx_eq_hex(cx_hmac("k1", "m"), cx_hmac("k2", "m"))\nshow cx_eq_hex(cx_hmac("k1", "m"), cx_hmac("k1", "m"))\n' > $(TESTS)/crypto_tamper.sa
	./$(SEED_MIN_BIN) $(TESTS)/crypto_tamper.sa > $(TESTS)/crypto_tamper.c
	$(CC) -O2 -o $(TESTS)/crypto_tamper $(TESTS)/crypto_tamper.c
	$(call assert-out,./$(TESTS)/crypto_tamper,1\n0\n0\n1)
	@echo '[OK] stdlib/crypto.sa: SHA-256 (FIPS 180-4 vectors + 5 padding boundaries) and HMAC-SHA256 (RFC 4231 cases 1-3) identical on seed-min, gen2 and native; no bit_* builtin used'

test-stdlib-modules: test-stdlib-crypto
native-test: test-stdlib-crypto

# ---------------------------------------------------------------------------
# test-stdlib-json-deep: stdlib/json_deep.sa -- the NESTED JSON reader and
# validator json_util.sa deliberately is not, on all three backends.
#
# The fixture walks objects inside arrays inside objects by path, decodes
# escapes (including a surrogate pair and a dropped \u0000, printed as hex so
# the gate pins bytes), counts members and elements, and then runs the
# validator over 9 documents it must accept and 15 it must refuse.
# ---------------------------------------------------------------------------
JD_WANT := ada\nalpha\nbeta\n80\n8080\nb\nbottom\nobject\nobject\narray\nobject\nstring\nnumber\ntrue\nfalse\nnull\n\n\n\n1\n2.5\n-3\n1000\n0.125\n1\n0\n0\n1\n0\n2\n4\n5\n0\n0\n0\n3\n-1\nname\ntags\n\nserver\n{"name":"beta","port":8080,"tags":[]}\n["a","b"]\n1e3\n6122625c632f640a650966\n41c3a9e282acf09f9880\nxy\n10\narray\n}\n1\n1\n1\n1\n1\n1\n1\n1\n1\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\njson-deep-done

JD_MIX_WANT := {"k":"v","n":42}\n1\nv\n42\nv\n2

.PHONY: test-stdlib-json-deep
test-stdlib-json-deep: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_json_deep_test.sa > $(TESTS)/jsond_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/jsond_seed $(TESTS)/jsond_seed.c
	./$(GEN2) selfhost/stdlib_json_deep_test.sa $(TESTS)/jsond_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/jsond_gen2 $(TESTS)/jsond_gen2.c
	$(call assert-out,./$(TESTS)/jsond_seed,$(JD_WANT))
	$(call assert-out,./$(TESTS)/jsond_gen2,$(JD_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_json_deep_test.sa $(TESTS)/jsond_native || exit 1; \
	  ./$(TESTS)/jsond_native > $(TESTS)/jsond_native.out || exit 1; \
	  ./$(TESTS)/jsond_seed > $(TESTS)/jsond_seed.out || exit 1; \
	  cmp $(TESTS)/jsond_seed.out $(TESTS)/jsond_native.out || { echo '[FAIL] native json_deep differs from seed-min'; exit 1; }; \
	  echo '[OK] native json_deep parity (nested paths, escapes, validator)'; \
	else echo '[SKIP] native json_deep parity: native_aot not built'; fi
	@# ---- json_util and json_deep agree on the flat subset ----------------
	@printf 'use "stdlib/json_util.sa"\nuse "stdlib/json_deep.sa"\nhold doc = j_obj(concat(concat(j_kv_text("k", "v"), ","), j_kv_number("n", 42)))\nshow doc\nshow jd_valid(doc)\nshow jd_text(doc, "k")\nshow jd_num(doc, "n")\nshow j_get_text(doc, "k")\nshow jd_len(doc, "")\n' > $(TESTS)/jsond_mix.sa
	./$(SEED_MIN_BIN) $(TESTS)/jsond_mix.sa > $(TESTS)/jsond_mix.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/jsond_mix $(TESTS)/jsond_mix.c
	$(call assert-out,./$(TESTS)/jsond_mix,$(JD_MIX_WANT))
	@echo '[OK] stdlib/json_deep.sa: nested paths, escapes/surrogates, member and element counts, and a 23-document validator (8 accepted, 15 refused), identical on seed-min, gen2 and native'

test-stdlib-modules: test-stdlib-json-deep
native-test: test-stdlib-json-deep

# ---------------------------------------------------------------------------
# test-stdlib-json-write: stdlib/json_write.sa -- nested JSON construction,
# functional key update/delete (jw_obj_set / jw_obj_del), minification and
# multi-level pretty-printing, round-tripping through stdlib/json_deep.sa's
# RFC 8259 validator and path reader across seed-min, gen2 and native_aot.
# ---------------------------------------------------------------------------
JW_WANT := 1\n2\nobject\n0\n1\n3.75\n-3.25\nnull\n0\n0\n2\nalpha\ntls\nbeta\n"node"\n8080\n0\n1\n1\nedge\n3.75\n{\n  "a": [],\n  "b": [\n    1\n  ]\n}\njson-write-done

.PHONY: test-stdlib-json-write
test-stdlib-json-write: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_json_write_test.sa > $(TESTS)/jsonw_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/jsonw_seed $(TESTS)/jsonw_seed.c
	./$(GEN2) selfhost/stdlib_json_write_test.sa $(TESTS)/jsonw_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/jsonw_gen2 $(TESTS)/jsonw_gen2.c
	$(call assert-out,./$(TESTS)/jsonw_seed,$(JW_WANT))
	$(call assert-out,./$(TESTS)/jsonw_gen2,$(JW_WANT))
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) selfhost/stdlib_json_write_test.sa $(TESTS)/jsonw_native || exit 1; \
	  ./$(TESTS)/jsonw_native > $(TESTS)/jsonw_native.out || exit 1; \
	  ./$(TESTS)/jsonw_seed > $(TESTS)/jsonw_seed.out || exit 1; \
	  cmp $(TESTS)/jsonw_seed.out $(TESTS)/jsonw_native.out || { echo '[FAIL] native json_write differs from seed-min'; exit 1; }; \
	  echo '[OK] native json_write parity (nested builder, set/del, pretty-printer)'; \
	else echo '[SKIP] native json_write parity: native_aot not built'; fi
	@echo '[OK] stdlib/json_write.sa: nested objects/arrays, jw_obj_set/jw_obj_del, jw_minify and jw_pretty round-trip through json_deep.sa identically on seed-min, gen2 and native'

test-stdlib-modules: test-stdlib-json-write
native-test: test-stdlib-json-write

# ---------------------------------------------------------------------------
# test-sxpkg-crypto: the package tool's cryptographic acceptance test.
#
# Before this gate, a locked package was accepted on `sum=`, a 31-base
# polynomial mod 1000000007. The first block below BREAKS that checksum on
# purpose -- changing one byte by +1 and the next by -31 leaves the sum
# bit-identical -- and shows `sha256=` refusing the same swap. The rest pins
# signing (HMAC-SHA256 over name/version/sha256), the signer id, provenance
# (origin=), and every way a signature can fail: tampered bytes, a tampered
# digest, another key, no key, and SAYANOX_REQUIRE_SIGNED.
#
# The signature is symmetric. `authenticate` says so by needing the same
# secret the signer used; no public-key signature is implemented or claimed.
# ---------------------------------------------------------------------------
.PHONY: test-sxpkg-crypto
test-sxpkg-crypto: sxpkg
	@rm -rf $(TESTS)/sxpkg-crypto && mkdir -p $(TESTS)/sxpkg-crypto
	@# ---- 1. the old checksum collides; the digest does not ---------------
	@printf 'make az(n) {\n  give n\n}\n' > $(TESTS)/sxpkg-crypto/c1.sa
	@printf 'make b[(n) {\n  give n\n}\n' > $(TESTS)/sxpkg-crypto/c2.sa
	@if cmp -s $(TESTS)/sxpkg-crypto/c1.sa $(TESTS)/sxpkg-crypto/c2.sa; then echo '[FAIL] collision fixture is not two different files'; exit 1; fi
	@__s1=$$(./$(SXPKG_BIN) sum $(TESTS)/sxpkg-crypto/c1.sa | cut -d' ' -f3); __s2=$$(./$(SXPKG_BIN) sum $(TESTS)/sxpkg-crypto/c2.sa | cut -d' ' -f3); \
	  __h1=$$(./$(SXPKG_BIN) sha256 $(TESTS)/sxpkg-crypto/c1.sa | cut -d' ' -f3); __h2=$$(./$(SXPKG_BIN) sha256 $(TESTS)/sxpkg-crypto/c2.sa | cut -d' ' -f3); \
	  if [ "$$__s1" != "$$__s2" ]; then echo "[FAIL] the two files were supposed to collide under sum=: $$__s1 vs $$__s2"; exit 1; fi; \
	  if [ "$$__h1" = "$$__h2" ]; then echo '[FAIL] sha256 collided too'; exit 1; fi; \
	  echo '[OK] weak sum= collides on a 2-byte swap; sha256= separates the same two files'
	@# ---- 2. a seeded registry carries sha256= and origin= ----------------
	@mkdir -p $(TESTS)/sxpkg-crypto/proj
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) init > $(TESTS)/sxpkg-crypto/init.out
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) seed > $(TESTS)/sxpkg-crypto/seed.out
	@grep -q '^sha256=[0-9a-f]\{64\}$$' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta || { echo '[FAIL] seed wrote no sha256='; cat $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta; exit 1; }
	@grep -q '^origin=seed:builtin$$' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta || { echo '[FAIL] seed wrote no provenance'; exit 1; }
	@grep -q '^sum=' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta || { echo '[FAIL] the old sum= line was dropped; old registries would stop verifying'; exit 1; }
	@if command -v sha256sum >/dev/null 2>&1; then \
	  __w=$$(sha256sum $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa | cut -d' ' -f1); \
	  __g=$$(grep '^sha256=' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta | cut -d= -f2); \
	  [ "$$__w" = "$$__g" ] || { echo "[FAIL] pkg.meta sha256 $$__g is not the file's digest $$__w"; exit 1; }; \
	  echo '[OK] pkg.meta sha256= equals the host sha256sum of main.sa'; \
	else echo '[SKIP] host sha256sum cross-check'; fi
	@# ---- 3. a sum-preserving swap of main.sa is refused ------------------
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) add math 0.1.0 > /dev/null
	@cp $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa $(TESTS)/sxpkg-crypto/math.orig
	@cp $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta $(TESTS)/sxpkg-crypto/meta.orig
	@# swap_b is the seeded math main.sa with `give` -> `hJve` on one line:
	@# +1 on one byte and -31 on the next, which the 31-base sum cannot see.
	@printf 'make dbl(n) {\n  give n + n\n}\nmake sqr(n) {\n  give n * n\n}\n' > $(TESTS)/sxpkg-crypto/swap_a.sa
	@printf 'make dbl(n) {\n  hJve n + n\n}\nmake sqr(n) {\n  give n * n\n}\n' > $(TESTS)/sxpkg-crypto/swap_b.sa
	@cmp $(TESTS)/sxpkg-crypto/swap_a.sa $(TESTS)/sxpkg-crypto/math.orig || { echo '[FAIL] the swap fixture is not the seeded math main.sa'; exit 1; }
	@__sa=$$(./$(SXPKG_BIN) sum $(TESTS)/sxpkg-crypto/swap_a.sa | cut -d' ' -f3); \
	  __sb=$$(./$(SXPKG_BIN) sum $(TESTS)/sxpkg-crypto/swap_b.sa | cut -d' ' -f3); \
	  [ "$$__sa" = "$$__sb" ] || { echo "[FAIL] the swap fixture does not preserve sum= ($$__sa vs $$__sb)"; exit 1; }
	@cp $(TESTS)/sxpkg-crypto/swap_b.sa $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) verify > $(TESTS)/sxpkg-crypto/verify_swap.out 2>&1; then \
	  echo '[FAIL] verify accepted a main.sa swapped under the same sum='; cat $(TESTS)/sxpkg-crypto/verify_swap.out; exit 1; fi
	@grep -q 'hashes to' $(TESTS)/sxpkg-crypto/verify_swap.out || { echo '[FAIL] the refusal did not name the digest'; cat $(TESTS)/sxpkg-crypto/verify_swap.out; exit 1; }
	@echo '[OK] verify refuses a sum-preserving swap of main.sa, naming the sha256 that did not match'
	@cp $(TESTS)/sxpkg-crypto/math.orig $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa
	@# ---- 4. an unsigned registry verifies exactly as it did before -------
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) verify > $(TESTS)/sxpkg-crypto/verify_plain.out
	@printf 'sxpkg: verified math 0.1.0\nsxpkg: verify ok (1 locked packages)\n' > $(TESTS)/sxpkg-crypto/verify_plain.want
	@cmp $(TESTS)/sxpkg-crypto/verify_plain.want $(TESTS)/sxpkg-crypto/verify_plain.out || { echo '[FAIL] an unsigned registry gained or lost output'; cat $(TESTS)/sxpkg-crypto/verify_plain.out; exit 1; }
	@echo '[OK] unsigned registry: verify output byte-identical to the pre-signature tool'
	@# ---- 5. sign, then authenticate --------------------------------------
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' ./$(SXPKG_BIN) sign math > $(TESTS)/sxpkg-crypto/sign.out
	@grep -q '^sxpkg: signed math 0.1.0$$' $(TESTS)/sxpkg-crypto/sign.out || { echo '[FAIL] sign did not report'; cat $(TESTS)/sxpkg-crypto/sign.out; exit 1; }
	@grep -q '^sig=[0-9a-f]\{64\}$$' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta || { echo '[FAIL] no sig= in pkg.meta'; exit 1; }
	@grep -q '^signer=[0-9a-f]\{16\}$$' $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta || { echo '[FAIL] no signer= in pkg.meta'; exit 1; }
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_ok.out
	@grep -q '^sxpkg: authentic math signer=' $(TESTS)/sxpkg-crypto/auth_ok.out || { echo '[FAIL] a correctly signed package did not authenticate'; cat $(TESTS)/sxpkg-crypto/auth_ok.out; exit 1; }
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' ./$(SXPKG_BIN) verify > $(TESTS)/sxpkg-crypto/verify_signed.out
	@grep -q '^sxpkg: signature ok math$$' $(TESTS)/sxpkg-crypto/verify_signed.out || { echo '[FAIL] verify did not report the good signature'; exit 1; }
	@# the same key file, discovered on disk instead of in the environment
	@mkdir -p $(TESTS)/sxpkg-crypto/proj/.sayanox/keys
	@printf 'test-key-1\n' > $(TESTS)/sxpkg-crypto/proj/.sayanox/keys/default.key
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_file.out
	@grep -q '^sxpkg: authentic math' $(TESTS)/sxpkg-crypto/auth_file.out || { echo '[FAIL] the key file was not used (a trailing newline must not change the key)'; cat $(TESTS)/sxpkg-crypto/auth_file.out; exit 1; }
	@echo '[OK] sign/authenticate: HMAC-SHA256 over name+version+sha256, key from the environment or from .sayanox/keys/default.key'
	@# ---- 6. every way a signature must fail ------------------------------
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='another-key' ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_badkey.out 2>&1; then \
	  echo '[FAIL] another key authenticated the package'; cat $(TESTS)/sxpkg-crypto/auth_badkey.out; exit 1; fi
	@grep -q 'BAD' $(TESTS)/sxpkg-crypto/auth_badkey.out || { echo '[FAIL] the wrong-key refusal is not named BAD'; exit 1; }
	@cp $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta $(TESTS)/sxpkg-crypto/meta.signed
	@cp $(TESTS)/sxpkg-crypto/swap_b.sa $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_tampered.out 2>&1; then \
	  echo '[FAIL] authenticate accepted tampered bytes'; exit 1; fi
	@grep -q 'BAD main.sa does not match the signed sha256' $(TESTS)/sxpkg-crypto/auth_tampered.out || { echo '[FAIL] tampered bytes were not named'; cat $(TESTS)/sxpkg-crypto/auth_tampered.out; exit 1; }
	@cp $(TESTS)/sxpkg-crypto/math.orig $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/main.sa
	@# rewrite sha256= to all zeros with grep + printf: no sed, because
	@# test-language-deps forbids an interpreter in a recipe
	@grep -v '^sha256=' $(TESTS)/sxpkg-crypto/meta.signed > $(TESTS)/sxpkg-crypto/meta.nodigest
	@cp $(TESTS)/sxpkg-crypto/meta.nodigest $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta
	@printf 'sha256=0000000000000000000000000000000000000000000000000000000000000000\n' >> $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_baddigest.out 2>&1; then \
	  echo '[FAIL] authenticate accepted a rewritten sha256='; exit 1; fi
	@cp $(TESTS)/sxpkg-crypto/meta.signed $(TESTS)/sxpkg-crypto/proj/.sayanox/registry/math/pkg.meta
	@rm -f $(TESTS)/sxpkg-crypto/proj/.sayanox/keys/default.key
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_nokey.out
	@grep -q '^sxpkg: NOKEY math' $(TESTS)/sxpkg-crypto/auth_nokey.out || { echo '[FAIL] a signed package with no key here must be reported, not accepted silently'; cat $(TESTS)/sxpkg-crypto/auth_nokey.out; exit 1; }
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_REQUIRE_SIGNED=1 ./$(SXPKG_BIN) authenticate math > $(TESTS)/sxpkg-crypto/auth_require.out 2>&1; then \
	  echo '[FAIL] SAYANOX_REQUIRE_SIGNED accepted an uncheckable package'; exit 1; fi
	@SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj ./$(SXPKG_BIN) add hello 0.1.0 > /dev/null
	@if SAYANOX_ROOT=$(TESTS)/sxpkg-crypto/proj SAYANOX_SIGN_KEY='test-key-1' SAYANOX_REQUIRE_SIGNED=1 ./$(SXPKG_BIN) verify > $(TESTS)/sxpkg-crypto/verify_require.out 2>&1; then \
	  echo '[FAIL] SAYANOX_REQUIRE_SIGNED accepted an unsigned package'; cat $(TESTS)/sxpkg-crypto/verify_require.out; exit 1; fi
	@grep -q '^sxpkg: UNSIGNED hello$$' $(TESTS)/sxpkg-crypto/verify_require.out || { echo '[FAIL] the unsigned package was not named'; exit 1; }
	@echo '[OK] refusals: another key, tampered main.sa, rewritten sha256=, no key, SAYANOX_REQUIRE_SIGNED over an unsigned package (all exit 1)'
	@# ---- 7. provenance survives a publish --------------------------------
	@rm -rf $(TESTS)/sxpkg-crypto/pub && mkdir -p $(TESTS)/sxpkg-crypto/pub
	@printf 'show "published"\n' > $(TESTS)/sxpkg-crypto/pub/main.sa
	@printf 'name = "provpkg"\nversion = "2.0.0"\n' > $(TESTS)/sxpkg-crypto/pub/sx.toml
	@cd $(TESTS)/sxpkg-crypto/pub && SAYANOX_ROOT=. $(CURDIR)/$(SXPKG_BIN) publish > publish.out
	@grep -q '^sha256=[0-9a-f]\{64\}$$' $(TESTS)/sxpkg-crypto/pub/.sayanox/registry/provpkg/pkg.meta || { echo '[FAIL] publish wrote no digest'; cat $(TESTS)/sxpkg-crypto/pub/.sayanox/registry/provpkg/pkg.meta; exit 1; }
	@grep -q '^origin=publish:' $(TESTS)/sxpkg-crypto/pub/.sayanox/registry/provpkg/pkg.meta || { echo '[FAIL] publish recorded no provenance'; exit 1; }
	@echo '[OK] publish records sha256= and origin=; seed records origin=seed:builtin'
	@echo '[OK] sxpkg crypto: SHA-256 acceptance + HMAC-SHA256 keyed signatures + origin provenance (symmetric: no public-key signature is claimed)'

test-sxpkg: test-sxpkg-crypto

# ---------------------------------------------------------------------------
# LSP semantic resolution, folder-wide rename and file watching.
#
# test-lsp-workspace checks WHICH files the server reads; this one checks what
# it understands about the names inside them. The client is Sayanox
# (tools/lsp_semantic_test.sa) and drives real framed sessions:
#
#   * definition resolves the binder -- a parameter or a `hold` in the
#     enclosing body wins over a same-named declaration in another function,
#     and a name no body binds resolves to the top-level declaration, not to
#     the first line in the file that looks like one;
#   * references and rename stay inside the body that binds a local, and never
#     count a word that sits inside a string literal or a comment;
#   * renaming a top-level name edits every indexed file, including files the
#     editor never opened;
#   * workspace/didChangeWatchedFiles is registered with the client when the
#     client offers dynamic registration, re-checks a file the notification
#     names, clears diagnostics on a delete, and leaves open buffers to
#     didChange.
#
# The scratch folder has a space in its name on purpose: every URI in the
# session is percent-encoded, like the folder-index gate.
.PHONY: test-lsp-semantic
test-lsp-semantic: $(LSP_BIN) $(SXC_NATIVE_BIN) tools/lsp_semantic_test.sa
	@mkdir -p $(TESTS)
	./$(SXC_NATIVE_BIN) tools/lsp_semantic_test.sa $(TESTS)/lsp-semantic-test
	@rm -rf '$(TESTS)/lsp semantic' && mkdir -p '$(TESTS)/lsp semantic'
	./$(TESTS)/lsp-semantic-test '$(CURDIR)/$(LSP_BIN)' '$(CURDIR)/$(TESTS)/lsp semantic'
	@echo '[OK] LSP semantic resolution: scope-aware definition/references/rename, folder-wide rename, file watching'

test-lsp test-lsp-robust: test-lsp-semantic

# ---------------------------------------------------------------------------
# test-struct-field-struct: the measured blocker under nested generics.
#
# Roadmap row 5 (`Box<Box<num>>`) is refused on all three backends. Mangling a
# nested instantiation is the easy half; the hard half is what the mangled
# struct would have to contain. This gate pins where that stands TODAY with
# ordinary concrete structs -- no generics in sight:
#
#   struct Inner { v }   struct Outer { b }
#   hold i = Inner { 7 }   hold o = Outer { i }   show o.b.v
#
# seed-min and native accept it and print 7. gen2 refuses it: the field kind
# it infers for `b` is not a struct, so the chain `o.b.v` is rejected at
# compile time with a clear message baked into the emitted C. Until gen2 can
# hold a struct in a struct field, a nested generic instantiation has nothing
# to lower to on that backend, so this gate is the honest statement of why
# row 5 is still open -- and the place to start when it is picked up.
#
# When gen2 learns struct-typed fields: this gate must be rewritten (the
# refusal branch becomes a third `7`), not deleted.
# ---------------------------------------------------------------------------
.PHONY: test-struct-field-struct
test-struct-field-struct: $(SEED_MIN_BIN) $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'struct Inner {\n  v\n}\nstruct Outer {\n  b\n}\nhold i = Inner { 7 }\nhold o = Outer { i }\nshow o.b.v\n' > $(TESTS)/sfs.sa
	./$(SEED_MIN_BIN) $(TESTS)/sfs.sa > $(TESTS)/sfs_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sfs_seed $(TESTS)/sfs_seed.c
	$(call assert-out,./$(TESTS)/sfs_seed,7)
	@# gen2 used to refuse this ("field 'b' of struct 'Outer' is not a struct"),
	@# which is what blocked nested generics there: Box__Box__n needs a field
	@# holding a Box__n. Since 2026-10-22 a struct-typed field may also be
	@# filled from a NAME, not only from a nested literal, and the emitted C is
	@# the ordinary struct copy `((Outer){i})`.
	./$(GEN2) $(TESTS)/sfs.sa $(TESTS)/sfs_gen2.c > $(TESTS)/sfs_gen2.out 2>&1
	@grep -q '#error' $(TESTS)/sfs_gen2.c \
	  && { echo "[FAIL] gen2 refuses a struct-typed struct field again:"; grep '#error' $(TESTS)/sfs_gen2.c; exit 1; } || true
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sfs_gen2 $(TESTS)/sfs_gen2.c
	$(call assert-out,./$(TESTS)/sfs_gen2,7)
	@grep -q -F 'typedef struct { Inner b; } Outer;' $(TESTS)/sfs_gen2.c \
	  || { echo "[FAIL] gen2 no longer lays Outer out with an Inner field"; exit 1; }
	@# the nested LITERAL form has always worked on gen2 and must keep working
	@printf 'struct Inner {\n  v\n}\nstruct Outer {\n  b\n}\nhold o = Outer { Inner { 8 } }\nshow o.b.v\n' > $(TESTS)/sfs_lit.sa
	./$(GEN2) $(TESTS)/sfs_lit.sa $(TESTS)/sfs_lit_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/sfs_lit_gen2 $(TESTS)/sfs_lit_gen2.c
	$(call assert-out,./$(TESTS)/sfs_lit_gen2,8)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/sfs.sa $(TESTS)/sfs_nat >/dev/null \
	    || { echo "[FAIL] native refused a struct-typed struct field"; exit 1; }; \
	  got=`./$(TESTS)/sfs_nat`; \
	  [ "$$got" = "7" ] || { echo "[FAIL] native printed $$got, want 7"; exit 1; }; \
	  echo "[OK] native: a struct field holding a struct reads through the chain"; \
	else echo "[SKIP] native_aot not built"; fi
	@echo '[OK] struct-typed struct fields: seed-min, gen2 and native all read o.b.v, from a name and from a nested literal (this is what unblocked nested generics on gen2)'

test-type-refusals: test-struct-field-struct

# ---------------------------------------------------------------------------
# tools/sxbuild + test-sxbuild: Sayanox build/bootstrap/parity/tool driver.
# ---------------------------------------------------------------------------
SXBUILD_BIN := tools/sxbuild
SXBUILD_SA  := tools/sxbuild.sa

$(SXBUILD_BIN): $(SXBUILD_SA) tools/sxmod_lib.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXBUILD_SA) $(SXBUILD_BIN)

.PHONY: test-sxbuild
test-sxbuild: $(SXBUILD_BIN) $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN)
	@mkdir -p $(TESTS)/sxbuild_gate
	./$(SXBUILD_BIN) doctor >/dev/null
	./$(SXBUILD_BIN) inventory > $(TESTS)/sxbuild_gate/inv.out
	@grep -q 'native_aot.c present: *0' $(TESTS)/sxbuild_gate/inv.out \
	  || { echo "[FAIL] sxbuild inventory did not report native_aot.c present: 0"; exit 1; }
	@grep -q 'non-anchor .c/.h files: *0' $(TESTS)/sxbuild_gate/inv.out \
	  || { echo "[FAIL] sxbuild inventory did not report non-anchor .c/.h files: 0"; exit 1; }
	./$(SXBUILD_BIN) parity selfhost/native_ir_log_test.sa $(TESTS)/sxbuild_gate/parity
	@echo "[OK] sxbuild: doctor, inventory (0 non-anchor C/H files), and 3-backend parity verified C-free"

native-test: test-sxbuild

# ---------------------------------------------------------------------------
# tools/sxstage2_parity + test-native-stage2-parity: Stage-2 struct-typed
# functions and ${id} string interpolation parity + 23 refusals on native_aot.
# ---------------------------------------------------------------------------
SXSTAGE2_BIN := tools/sxstage2_parity
SXSTAGE2_SA  := tools/sxstage2_parity.sa

$(SXSTAGE2_BIN): $(SXSTAGE2_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXSTAGE2_SA) $(SXSTAGE2_BIN)

.PHONY: test-native-stage2-parity
test-native-stage2-parity: $(SXSTAGE2_BIN) $(GEN2) $(NATIVE_BIN)
	./$(SXSTAGE2_BIN) $(TESTS)/stage2_parity

native-test: test-native-stage2-parity

# ---------------------------------------------------------------------------
# tools/sxirexec + test-ir-exec: Portable IR virtual machine and 4-backend
# parity runner (seed-min == gen2 == native_aot == sxirexec, plus ELF-deleted
# compile-and-run execution on Stage-2 struct functions and interpolation).
# ---------------------------------------------------------------------------
SXIREXEC_BIN := tools/sxirexec
SXIREXEC_SA  := tools/sxirexec.sa

$(SXIREXEC_BIN): $(SXIREXEC_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXIREXEC_SA) $(SXIREXEC_BIN)

.PHONY: test-ir-exec
test-ir-exec: $(SXIREXEC_BIN) $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) tools/emit_to_ir
	@mkdir -p $(TESTS)/irexec_gate
	@for f in native_ir_log_test stdlib_growth_test stdlib_crypto_test stdlib_json_write_test; do \
	  ./$(SXIREXEC_BIN) parity selfhost/$$f.sa $(TESTS)/irexec_gate/$$f || exit 1; \
	done
	@for f in selfhost/struct_function_tests/values.sa selfhost/struct_function_tests/gc.sa selfhost/interpolation_tests/values.sa selfhost/interpolation_tests/gc.sa selfhost/generic_struct_nested.sa; do \
	  ./$(NATIVE_BIN) $$f $(TESTS)/irexec_gate/ref.bin && chmod +x $(TESTS)/irexec_gate/ref.bin || exit 1; \
	  ./$(TESTS)/irexec_gate/ref.bin > $(TESTS)/irexec_gate/ref.out || exit 1; \
	  ./$(SXIREXEC_BIN) compile-and-run $$f $(TESTS)/irexec_gate/vm > $(TESTS)/irexec_gate/vm.out || exit 1; \
	  test ! -e $(TESTS)/irexec_gate/vm/prog.elf || { echo "[FAIL] prog.elf was not deleted before IR VM execution"; exit 1; }; \
	  cmp $(TESTS)/irexec_gate/ref.out $(TESTS)/irexec_gate/vm.out || { echo "[FAIL] sxirexec disagreed with native_aot on $$f"; exit 1; }; \
	done
	@echo "[OK] sxirexec: 4-way portable IR VM parity + ELF-deleted Stage-2 execution verified"

native-test: test-ir-exec

# ---------------------------------------------------------------------------
# tools/sxpkg_pubkey_test + test-sxpkg-pubkey: Curve25519 Schnorr-SHA256
# public-key package signatures (pubsig=) and signed registry indices
# (INDEX.sig) verified with .sec deleted.
# ---------------------------------------------------------------------------
SXPKGPUB_BIN := tools/sxpkg_pubkey_test
SXPKGPUB_SA  := tools/sxpkg_pubkey_test.sa

$(SXPKGPUB_BIN): $(SXPKGPUB_SA) $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) $(SXPKGPUB_SA) $(SXPKGPUB_BIN)

.PHONY: test-sxpkg-pubkey
test-sxpkg-pubkey: sxpkg $(SXPKGPUB_BIN) $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) stdlib/pubkey.sa selfhost/stdlib_pubkey_test.sa
	./$(SXPKGPUB_BIN) $(TESTS)/sxpkg_pubkey

test-sxpkg: test-sxpkg-pubkey
native-test: test-sxpkg-pubkey

# ---------------------------------------------------------------------------
# test-lsp-types: LSP static type-level hover (params, locals, generic struct
# field substitution, cross-file call return types) and cross-file workspace /
# use-module definition & signatureHelp over framed JSON-RPC.
# ---------------------------------------------------------------------------
.PHONY: test-lsp-types
test-lsp-types: $(LSP_BIN) $(SXC_NATIVE_BIN) tools/lsp_types_test.sa
	@mkdir -p $(TESTS)
	./$(SXC_NATIVE_BIN) tools/lsp_types_test.sa $(TESTS)/lsp-types-test
	./$(TESTS)/lsp-types-test '$(CURDIR)/$(LSP_BIN)' '$(CURDIR)/$(TESTS)/lsp_types'

test-lsp test-lsp-robust: test-lsp-types

# ---------------------------------------------------------------------------
# test-lsp-ide: LSP module-aware namespace hover/definition/signatureHelp,
# multiline call signatureHelp, lexical block-scoped shadowing, and
# textDocument/prepareRename positive & negative checks.
# ---------------------------------------------------------------------------
tools/lsp_ide_test: tools/lsp_ide_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/lsp_ide_test.sa $@

.PHONY: test-lsp-ide
test-lsp-ide: $(LSP_BIN) tools/lsp_ide_test
	./tools/lsp_ide_test '$(CURDIR)/$(LSP_BIN)' '$(CURDIR)/$(TESTS)/lsp_ide'

test-lsp test-lsp-robust: test-lsp-ide
native-test: test-lsp-ide

# ---------------------------------------------------------------------------
# test-sxc-native: C-free self-compiling x86-64 ELF64 compiler fixed point
# (gen2.elf == gen3.elf), native_aot byte identity, 16-param stack ABI, +=/-=,
# path_real, spawn/child_* IPC, and C-free sayanox_lsp/sxpkg/sxdiag/compiler_min.
# ---------------------------------------------------------------------------
tools/sxc_native_test: tools/sxc_native_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxc_native_test.sa $@

.PHONY: test-sxc-native
test-sxc-native: $(SXC_NATIVE_BIN) $(NATIVE_BIN) $(GEN2) tools/sxc_native_test
	@rm -rf $(TESTS)/sxc_native_gate && mkdir -p $(TESTS)/sxc_native_gate
	./tools/sxc_native_test $(TESTS)/sxc_native_gate

native-test: test-sxc-native

# ---------------------------------------------------------------------------
# test-sxsuite: Pure-Sayanox compiler test driver replacing legacy .sh drivers
# across stage2_interp, struct_fn, generic_struct_limits, full_lang_ready,
# compiler_features, and ir_audit.
# ---------------------------------------------------------------------------
tools/sxsuite: tools/sxsuite.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxsuite.sa $@

.PHONY: test-sxsuite
test-sxsuite: tools/sxsuite $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) tools/emit_to_ir
	./tools/sxsuite all
	@if ./tools/sxsuite bogus >/dev/null 2>&1; then echo "[FAIL] sxsuite accepted unknown suite"; exit 1; fi
	@echo "[OK] sxsuite: 6 compiler suites verified in C-free Sayanox"

native-test: test-sxsuite

# ---------------------------------------------------------------------------
# test-sxisaexec: User-mode AArch64 & RV64IM ELF64 emulator parity for integers,
# strings, byte indexing and bounded concat, heap/bounds controls, FP/syscall
# emulator probes, and negative fault controls (FP/syscalls are not compiler features).
# ---------------------------------------------------------------------------
tools/sxisaexec: tools/sxisaexec.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxisaexec.sa $@

tools/sxisaexec_test: tools/sxisaexec_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxisaexec_test.sa $@

.PHONY: test-sxisaexec
test-sxisaexec: tools/sxisaexec tools/sxisaexec_test $(N32_BIN) $(SXIREXEC_BIN) $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) tools/emit_to_ir
	@rm -rf $(TESTS)/sxisaexec_gate && mkdir -p $(TESTS)/sxisaexec_gate
	./tools/sxisaexec_test $(TESTS)/sxisaexec_gate

native-test: test-sxisaexec

# ---------------------------------------------------------------------------
# test-sxmod-deep: Transitive multi-directory module DAG resolution, singleton
# initialization, cross-module structs, 4-way backend parity, and 6 refusals.
# ---------------------------------------------------------------------------
tools/sxmod_deep_test: tools/sxmod_deep_test.sa $(SXC_NATIVE_BIN)
	./$(SXC_NATIVE_BIN) tools/sxmod_deep_test.sa $@

.PHONY: test-sxmod-deep
test-sxmod-deep: tools/sxmod_deep_test $(SXM_BIN) $(SXC_NATIVE_BIN) $(SXBUILD_BIN) $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN)
	@rm -rf $(TESTS)/sxmod_deep_gate && mkdir -p $(TESTS)/sxmod_deep_gate
	./tools/sxmod_deep_test $(TESTS)/sxmod_deep_gate

native-test: test-sxmod-deep

# ---------------------------------------------------------------------------
# test-stdlib-extended: 5-backend execution parity (seed-min == gen2 ==
# native_aot == sxc_native == sxirexec) across stdlib/map.sa, stdlib/sort.sa,
# stdlib/path.sa, stdlib/cli.sa, and stdlib/bytes.sa.
# ---------------------------------------------------------------------------
.PHONY: test-stdlib-extended
test-stdlib-extended: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) $(SXC_NATIVE_BIN) $(SXIREXEC_BIN) tools/emit_to_ir selfhost/stdlib_extended_test.sa stdlib/map.sa stdlib/sort.sa stdlib/path.sa stdlib/cli.sa stdlib/bytes.sa
	@rm -rf $(TESTS)/stdlib_ext && mkdir -p $(TESTS)/stdlib_ext
	./$(SEED_MIN_BIN) selfhost/stdlib_extended_test.sa > $(TESTS)/stdlib_ext/seed.c
	$(CC) -O2 -o $(TESTS)/stdlib_ext/seed $(TESTS)/stdlib_ext/seed.c -lm
	./$(GEN2) selfhost/stdlib_extended_test.sa $(TESTS)/stdlib_ext/gen2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/stdlib_ext/gen2 $(TESTS)/stdlib_ext/gen2.c
	./$(NATIVE_BIN) selfhost/stdlib_extended_test.sa $(TESTS)/stdlib_ext/nat
	./$(SXC_NATIVE_BIN) selfhost/stdlib_extended_test.sa $(TESTS)/stdlib_ext/sxc
	./$(TESTS)/stdlib_ext/seed > $(TESTS)/stdlib_ext/seed.out
	./$(TESTS)/stdlib_ext/gen2 > $(TESTS)/stdlib_ext/gen2.out
	./$(TESTS)/stdlib_ext/nat > $(TESTS)/stdlib_ext/nat.out
	./$(TESTS)/stdlib_ext/sxc > $(TESTS)/stdlib_ext/sxc.out
	./$(SXIREXEC_BIN) compile-and-run selfhost/stdlib_extended_test.sa $(TESTS)/stdlib_ext/vm > $(TESTS)/stdlib_ext/vm.out
	cmp $(TESTS)/stdlib_ext/seed.out $(TESTS)/stdlib_ext/gen2.out
	cmp $(TESTS)/stdlib_ext/seed.out $(TESTS)/stdlib_ext/nat.out
	cmp $(TESTS)/stdlib_ext/seed.out $(TESTS)/stdlib_ext/sxc.out
	cmp $(TESTS)/stdlib_ext/seed.out $(TESTS)/stdlib_ext/vm.out
	grep -q '^stdlib-extended-ok$$' $(TESTS)/stdlib_ext/seed.out
	@echo "[OK] stdlib extended: 5-way parity (seed-min == gen2 == native_aot == sxc_native == sxirexec) across map, sort, path, cli, and bytes"

test-stdlib-modules: test-stdlib-extended
native-test: test-stdlib-extended

# ---------------------------------------------------------------------------
# test-ci-shape: the CI/CD configuration is a gate, not a convention.
#
# Run 40267460446 is the reason this exists. Gates 3 and 4 downloaded the
# bootstrap artifact into ./gate-binaries, which put gen2.c and gen1_min.c
# (generated C) inside the checkout. `sxbuild inventory` walks the workspace,
# counted them as non-anchor C sources, and `make test-sxbuild` failed on a
# tree that was otherwise perfectly clean. The hand-off now lives in
# RUNNER_TEMP. These checks fail fast in the audit job, before the 30-minute
# gates start, if anyone moves it back or drops a workflow.
# ---------------------------------------------------------------------------
.PHONY: test-ci-shape
test-ci-shape:
	@for f in .github/workflows/ci.yml .github/workflows/full-bootstrap.yml .github/workflows/release.yml; do \
	  test -s "$$f" || { echo "[FAIL] missing CI/CD workflow: $$f"; exit 1; }; \
	done
	@test "$$(grep -cF 'path: $${{ runner.temp }}/gate-binaries' .github/workflows/ci.yml)" = 2 \
	  || { echo "[FAIL] ci.yml: both gate-binaries downloads must use runner.temp, outside the checkout"; exit 1; }
	@test "$$(grep -cF 'RUNNER_TEMP/gate-binaries' .github/workflows/ci.yml)" = 6 \
	  || { echo "[FAIL] ci.yml: both restore steps must find, copy from and remove RUNNER_TEMP/gate-binaries"; exit 1; }
	@test "$$(grep -cF 'test ! -e gate-binaries' .github/workflows/ci.yml)" = 2 \
	  || { echo "[FAIL] ci.yml: both restore steps must prove the checkout has no gate-binaries directory"; exit 1; }
	@test "$$(grep -cF 'path: gate-binaries' .github/workflows/ci.yml)" = 1 \
	  || { echo "[FAIL] ci.yml: only the upload step may use a workspace-relative gate-binaries path"; exit 1; }
	@for f in .github/workflows/ci.yml .github/workflows/full-bootstrap.yml; do \
	  grep -qF 'make test-ci-shape' "$$f" \
	    || { echo "[FAIL] $$f does not run the CI shape gate"; exit 1; }; \
	done
	@for f in .github/workflows/full-bootstrap.yml .github/workflows/release.yml; do \
	  for g in 'run: make doctor' 'run: make true-selfhost' 'run: make gen3' 'run: make native-test'; do \
	    grep -qF "$$g" "$$f" \
	      || { echo "[FAIL] $$f is missing the sequential gate $$g"; exit 1; }; \
	  done; \
	done
	@grep -qF 'contents: write' .github/workflows/release.yml \
	  || { echo "[FAIL] release.yml needs contents: write to publish a release"; exit 1; }
	@grep -qF "github.event_name == 'pull_request'" .github/workflows/ci.yml \
	  || { echo '[FAIL] ci.yml must not cancel a completed main-push verification'; exit 1; }
	@echo '[OK] CI/CD shape: hand-off outside the checkout, both sequential workflows run all four gates, release publishing is permitted'

# ---------------------------------------------------------------------------
# ci: the nightly full-bootstrap chain, as one local command. It deliberately
# shares the four hard gates with .github/workflows/full-bootstrap.yml instead
# of reimplementing them, so a local green run means the same thing as a green
# nightly run. `make test-ci-shape` (part of native-test) pins that sharing.
# ---------------------------------------------------------------------------
.PHONY: ci
ci: doctor
	@echo '=== CI: doctor -> true-selfhost -> gen3 -> native-test ==='
	@$(MAKE) true-selfhost
	@$(MAKE) gen3
	@$(MAKE) native-test
	@echo '=== CI-OK: DOCTOR-OK / TRUE-SELFHOST-MIN-OK / GEN3-OK / NATIVE-TEST-OK ==='

# ---------------------------------------------------------------------------
# stdlib/csv.sa: an RFC 4180-style CSV ROW codec for byte strings.
#
# Parsed rows are PACKED strings ("<len>:<bytes>" per field) because the
# dialect refuses string-valued list elements. csv_parse_row validates and
# parses one record (quoted fields, embedded commas/CR/LF, doubled quotes),
# csv_write_row quotes and escapes, and csv_ok/csv_count/csv_at/csv_push/
# csv_empty/csv_needs_quote/csv_quote/csv_is_valid_row are the public API.
# The fixture's 44 lines are hand-computed; seed-min, gen2 and native_aot must
# print byte-identical stdout, and the module must stand alone next to
# stdlib/str_text.sa without a name collision.
# ---------------------------------------------------------------------------
CSV_WANT := 1\n3\na\nb\nc\n0\n3\n0\nc\n1\n0\n2\n0\n2\na\n1\n2\na,b\nc\n1\na"b\nc\n0\n0\n0\n0\n1\n1\n1\na,b,c\na,,c\n"a,b",c\n"a""b",c\n\n0\n0\n1\nx\n2\na"b\n1\n1\n0123456789abcdef\ncsv-done

.PHONY: test-stdlib-csv
test-stdlib-csv: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) stdlib/csv.sa selfhost/stdlib_csv_test.sa
	@mkdir -p $(TESTS)
	./$(SEED_MIN_BIN) selfhost/stdlib_csv_test.sa > $(TESTS)/csv_seed.c
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/csv_seed $(TESTS)/csv_seed.c
	./$(GEN2) selfhost/stdlib_csv_test.sa $(TESTS)/csv_gen2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/csv_gen2 $(TESTS)/csv_gen2.c
	$(call assert-out,./$(TESTS)/csv_seed,$(CSV_WANT))
	$(call assert-out,./$(TESTS)/csv_gen2,$(CSV_WANT))
	./$(NATIVE_BIN) selfhost/stdlib_csv_test.sa $(TESTS)/csv_native
	@./$(TESTS)/csv_native > $(TESTS)/csv_native.out
	@./$(TESTS)/csv_seed > $(TESTS)/csv_seed.out
	@cmp $(TESTS)/csv_seed.out $(TESTS)/csv_native.out \
	  || { echo '[FAIL] native_aot stdlib/csv.sa output differs from seed-min'; exit 1; }
	@grep -q '^csv-done$$' $(TESTS)/csv_seed.out \
	  || { echo '[FAIL] the CSV fixture did not run to completion'; exit 1; }
	@# the module stands alone, and its csv_ prefix coexists with t_ helpers
	@printf 'use "stdlib/csv.sa"\nshow csv_count(csv_parse_row("x,y"))\nshow csv_is_valid_row("a,b")\nshow csv_is_valid_row(concat(chr(34), "a,b"))\n' > $(TESTS)/csv_alone.sa
	./$(SEED_MIN_BIN) $(TESTS)/csv_alone.sa > $(TESTS)/csv_alone.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/csv_alone $(TESTS)/csv_alone.c
	$(call assert-out,./$(TESTS)/csv_alone,2\n1\n0)
	./$(GEN2) $(TESTS)/csv_alone.sa $(TESTS)/csv_alone_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/csv_alone_g2 $(TESTS)/csv_alone_g2.c
	$(call assert-out,./$(TESTS)/csv_alone_g2,2\n1\n0)
	@printf 'use "stdlib/csv.sa"\nuse "stdlib/str_text.sa"\nshow csv_at(csv_parse_row("p,q"), 1)\nshow t_trim("  hi  ")\n' > $(TESTS)/csv_all.sa
	./$(SEED_MIN_BIN) $(TESTS)/csv_all.sa > $(TESTS)/csv_all.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/csv_all $(TESTS)/csv_all.c
	$(call assert-out,./$(TESTS)/csv_all,q\nhi)
	@echo '[OK] stdlib/csv.sa: 44 hand-computed values on seed-min == gen2 == native_aot; quoted fields, escaped quotes, 3 malformed-row refusals, quoting, round trip and module coexistence'

native-test: test-stdlib-csv
native-test: test-ci-shape

# ---------------------------------------------------------------------------
# test-stdlib-next: three new portable stdlib modules, one gate.
#
#   stdlib/url.sa       percent-encoding/decoding + packed query strings
#   stdlib/datetime.sa  Gregorian calendar arithmetic (JDN, leap years,
#                       weekday, add days, format/parse)
#   stdlib/hash.sa      non-cryptographic checksums: rolling hashes, djb2,
#                       sdbm, Adler-32 and Luhn check digits
#
# Each fixture prints label=value lines. selfhost/stdlib_{url,datetime,hash}.want
# holds EXPECTED output computed independently with host Python standard
# libraries (datetime/calendar, urllib.parse, zlib) and hand-written Luhn /
# rolling-hash oracles -- not by running these Sayanox modules. seed-min, gen2
# and native_aot must all reproduce those bytes exactly. Standalone use of each
# module and coexistence of all four prefixes (csv_/surl_/dt_/sh_) are pinned
# too, so a name collision or a stray dependency breaks the gate.
# ---------------------------------------------------------------------------
NEXT_MODULES := url datetime hash

.PHONY: test-stdlib-next
test-stdlib-next: $(SEED_MIN_BIN) $(GEN2) $(NATIVE_BIN) \
                  stdlib/url.sa stdlib/datetime.sa stdlib/hash.sa \
                  selfhost/stdlib_url_test.sa selfhost/stdlib_url.want \
                  selfhost/stdlib_datetime_test.sa selfhost/stdlib_datetime.want \
                  selfhost/stdlib_hash_test.sa selfhost/stdlib_hash.want
	@mkdir -p $(TESTS)/stdlib_next
	@set -e; for m in $(NEXT_MODULES); do \
	  ./$(SEED_MIN_BIN) selfhost/stdlib_$${m}_test.sa > $(TESTS)/stdlib_next/$${m}_seed.c; \
	  $(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stdlib_next/$${m}_seed $(TESTS)/stdlib_next/$${m}_seed.c; \
	  ./$(GEN2) selfhost/stdlib_$${m}_test.sa $(TESTS)/stdlib_next/$${m}_gen2.c >/dev/null; \
	  $(CC) -O2 -Werror=implicit-function-declaration -Werror=incompatible-pointer-types -o $(TESTS)/stdlib_next/$${m}_gen2 $(TESTS)/stdlib_next/$${m}_gen2.c; \
	  ./$(NATIVE_BIN) selfhost/stdlib_$${m}_test.sa $(TESTS)/stdlib_next/$${m}_native; \
	  ./$(TESTS)/stdlib_next/$${m}_seed > $(TESTS)/stdlib_next/$${m}_seed.out; \
	  ./$(TESTS)/stdlib_next/$${m}_gen2 > $(TESTS)/stdlib_next/$${m}_gen2.out; \
	  ./$(TESTS)/stdlib_next/$${m}_native > $(TESTS)/stdlib_next/$${m}_native.out; \
	  cmp $(TESTS)/stdlib_next/$${m}_seed.out $(TESTS)/stdlib_next/$${m}_gen2.out || { echo "[FAIL] stdlib/$${m}.sa: gen2 differs from seed-min"; exit 1; }; \
	  cmp $(TESTS)/stdlib_next/$${m}_seed.out $(TESTS)/stdlib_next/$${m}_native.out || { echo "[FAIL] stdlib/$${m}.sa: native_aot differs from seed-min"; exit 1; }; \
	  cmp $(TESTS)/stdlib_next/$${m}_seed.out selfhost/stdlib_$${m}.want || { echo "[FAIL] stdlib/$${m}.sa: output differs from the independently computed .want oracle"; exit 1; }; \
	  echo "[OK] stdlib/$${m}.sa: $$(wc -l < selfhost/stdlib_$${m}.want) oracle-pinned values, seed-min == gen2 == native_aot"; \
	done
	@# each module stands alone, and all four prefixes coexist in one program
	@printf 'use "stdlib/url.sa"\nshow surl_encode("a b")\n' > $(TESTS)/stdlib_next/alone_url.sa
	./$(SEED_MIN_BIN) $(TESTS)/stdlib_next/alone_url.sa > $(TESTS)/stdlib_next/alone_url.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_url $(TESTS)/stdlib_next/alone_url.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_url,a%20b)
	./$(GEN2) $(TESTS)/stdlib_next/alone_url.sa $(TESTS)/stdlib_next/alone_url_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_url_g2 $(TESTS)/stdlib_next/alone_url_g2.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_url_g2,a%20b)
	@printf 'use "stdlib/datetime.sa"\nshow dt_format(2024, 2, 29)\n' > $(TESTS)/stdlib_next/alone_dt.sa
	./$(SEED_MIN_BIN) $(TESTS)/stdlib_next/alone_dt.sa > $(TESTS)/stdlib_next/alone_dt.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_dt $(TESTS)/stdlib_next/alone_dt.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_dt,2024-02-29)
	./$(GEN2) $(TESTS)/stdlib_next/alone_dt.sa $(TESTS)/stdlib_next/alone_dt_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_dt_g2 $(TESTS)/stdlib_next/alone_dt_g2.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_dt_g2,2024-02-29)
	@printf 'use "stdlib/hash.sa"\nshow sh_istr(sh_adler32("Wikipedia"))\n' > $(TESTS)/stdlib_next/alone_sh.sa
	./$(SEED_MIN_BIN) $(TESTS)/stdlib_next/alone_sh.sa > $(TESTS)/stdlib_next/alone_sh.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_sh $(TESTS)/stdlib_next/alone_sh.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_sh,300286872)
	./$(GEN2) $(TESTS)/stdlib_next/alone_sh.sa $(TESTS)/stdlib_next/alone_sh_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/alone_sh_g2 $(TESTS)/stdlib_next/alone_sh_g2.c
	$(call assert-out,./$(TESTS)/stdlib_next/alone_sh_g2,300286872)
	@printf 'use "stdlib/csv.sa"\nuse "stdlib/url.sa"\nuse "stdlib/datetime.sa"\nuse "stdlib/hash.sa"\nshow surl_encode("a b")\nshow dt_format(2024, 2, 29)\nshow sh_sum_bytes("ab")\nshow csv_count(csv_parse_row("x,y"))\n' > $(TESTS)/stdlib_next/all.sa
	./$(SEED_MIN_BIN) $(TESTS)/stdlib_next/all.sa > $(TESTS)/stdlib_next/all.c
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/all $(TESTS)/stdlib_next/all.c
	$(call assert-out,./$(TESTS)/stdlib_next/all,a%20b\n2024-02-29\n195\n2)
	./$(GEN2) $(TESTS)/stdlib_next/all.sa $(TESTS)/stdlib_next/all_g2.c >/dev/null
	$(CC) -O2 -Werror=implicit-function-declaration -o $(TESTS)/stdlib_next/all_g2 $(TESTS)/stdlib_next/all_g2.c
	$(call assert-out,./$(TESTS)/stdlib_next/all_g2,a%20b\n2024-02-29\n195\n2)
	@echo '[OK] stdlib-next: url (39) + datetime (43) + hash (24) = 106 oracle-pinned values, 3-backend parity, standalone modules and csv_/surl_/dt_/sh_ coexistence'

native-test: test-stdlib-next
