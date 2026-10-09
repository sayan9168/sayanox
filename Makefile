# Sayanox bootstrap Makefile — sole entry point
# Preferred: make true-selfhost (seed-min -> gen1-min -> gen2). Optional: native, gen3; full is not yet implemented

CC ?= $(shell command -v clang >/dev/null 2>&1 && echo clang || (command -v gcc >/dev/null 2>&1 && echo gcc || echo cc))

SEED_C   := selfhost/seed/sxc_seed.c
SEED_H   := selfhost/seed/sx_runtime.h
SEED_BIN := selfhost/seed/sxc_seed
SEED_MIN_C   := selfhost/seed/sxc_seed_min.c
SEED_MIN_BIN := selfhost/seed/sxc_seed_min
NATIVE_SRC := selfhost/native_aot.c
NATIVE_BIN := selfhost/native_aot
MIN_SA   := selfhost/compiler_min.sa
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

.PHONY: all subset seed gen1 gen2 test true-selfhost true-selfhost-min true-selfhost-full selfhost \
        native native-test seed-min seed-min-gen1 gen3 clean restore-compiler fix-seed verify-seed \
        seed-bin doctor tools sxfmt test-sxfmt sxpkg test-sxpkg test-sxpkg-wrapper \
        test-reassign test-while test-when test-mod test-struct2 test-list2 test-use \
        test-boot test-fn test-fn2 test-list test-struct test-parity test-chain test-condmod test-user test-nest test-prec test-float test-parens test-push-stmt test-full-lang test-native-num test-native-io test-native-mem \
        test-for-str test-gen2-gaps test-registry-sums test-stdlib test-pkgs test-stage2-demos test-stage2 \
        pack-compiler

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
assert-out = @__got=$$($(1)); __want=$$(printf '%b' '$(2)'); \
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
#     `ptok(k,(const char*)#ch` in sxc_seed.c. The awk body never ran. (The
#     rewrite was unnecessary anyway: P1 is only instantiated with single-char
#     punctuation literals, so `#ch` already stringizes correctly.)
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
	@test -f $(SEED_C) || { echo "FAIL: missing $(SEED_C)"; exit 1; }
	@test -f $(SEED_H) || { echo "FAIL: missing $(SEED_H)"; exit 1; }
	@grep -q -F 'offsetof(SxStrHdr,data)' $(SEED_H) \
	  || { echo "FAIL: $(SEED_H) is stale: missing offsetof(SxStrHdr,data)"; exit 1; }
	@grep -q -F '#include <stddef.h>' $(SEED_H) \
	  || { echo "FAIL: $(SEED_H) is stale: missing #include <stddef.h>"; exit 1; }
	@grep -q -F 'SX_TAB_CAP 2097152' $(SEED_H) \
	  || { echo "FAIL: $(SEED_H) is stale: SX_TAB_CAP is not 2097152"; exit 1; }
	@grep -q -F 'sx_tab_add(h->data,1);' $(SEED_H) \
	  || { echo "FAIL: $(SEED_H) is stale: missing sx_tab_add(h->data,1);"; exit 1; }
	@grep -q -F 'sx_tab_find((void*)p);' $(SEED_H) \
	  || { echo "FAIL: $(SEED_H) is stale: missing sx_tab_find((void*)p);"; exit 1; }
	@if grep -q -F '(char*)p-sizeof(SxStrHdr)' $(SEED_H); then \
	  echo "FAIL: $(SEED_H) is stale: pre-fix sizeof(SxStrHdr) arithmetic present"; exit 1; fi
	@if grep -q -F 'SX_TAB_CAP 262144' $(SEED_H); then \
	  echo "FAIL: $(SEED_H) is stale: pre-fix SX_TAB_CAP 262144 present"; exit 1; fi
	@echo "[OK] verify-seed (checked-in sources verified; no awk/sed patching)"

fix-seed: verify-seed

pack-compiler:
	@# Regenerate selfhost/compiler_min_gz/*.b64 from selfhost/compiler_min.sa
	./selfhost/pack_compiler_min.sh

# ---------------------------------------------------------------------------
# restore-compiler: guarantee selfhost/compiler_min.sa is present and sane.
#
# Fully offline -- this target never touches the network.
#
# Fast path (the normal case): compiler_min.sa is a checked-in source file, so
# we only verify its markers. This path needs no base64, no gzip, no cat/tr.
#
# Fallback: if the source is absent or corrupt, decode the checked-in
# gzip+base64 blob in selfhost/compiler_min_gz/*.b64. That blob was verified
# byte-identical to the checked-in compiler_min.sa (sha256 aa5ff5ada3b3d91c...,
# 33 parts of 1100 chars; regenerate with `make pack-compiler`), so both paths
# produce the same file. base64, gzip, cat, tr and rm are therefore OPTIONAL
# dependencies, needed only if the plain source goes missing.
# ---------------------------------------------------------------------------
restore-compiler:
	@if test -s $(MIN_SA) \
	   && grep -q 'read_file' $(MIN_SA) \
	   && grep -q 'arg_count' $(MIN_SA) \
	   && grep -q 'sx_eq' $(MIN_SA); then \
	  echo "[OK] restore-compiler (checked-in source verified; no base64/gzip used)"; \
	  exit 0; \
	fi; \
	echo "[restore-compiler] $(MIN_SA) absent or incomplete -> decoding gzip+base64 parts (offline)"; \
	test -f selfhost/compiler_min_gz/00.b64 \
	  || { echo "FAIL: no $(MIN_SA) and no selfhost/compiler_min_gz/00.b64 to restore from"; exit 1; }; \
	# decode to a TEMP file and verify it BEFORE touching $(MIN_SA): a failed \
	# or stale restore must never replace a source file that is already there \
	# (that is how a newer compiler_min.sa gets silently downgraded to an \
	# older blob if `grep` happens to be missing from PATH). \
	cat selfhost/compiler_min_gz/*.b64 | tr -d '\n' | base64 -d | gzip -d > $(MIN_SA).tmp \
	  || { echo "FAIL: could not decode selfhost/compiler_min_gz/*.b64 (need base64 and gzip)"; rm -f $(MIN_SA).tmp; exit 1; }; \
	test -s $(MIN_SA).tmp || { echo "FAIL: decoded $(MIN_SA) is empty"; rm -f $(MIN_SA).tmp; exit 1; }; \
	grep -q 'read_file' $(MIN_SA).tmp && grep -q 'arg_count' $(MIN_SA).tmp && grep -q 'sx_eq' $(MIN_SA).tmp \
	  || { echo "FAIL: restored compiler_min is missing expected markers (existing $(MIN_SA) left untouched)"; rm -f $(MIN_SA).tmp; exit 1; }; \
	cat $(MIN_SA).tmp > $(MIN_SA); rm -f $(MIN_SA).tmp; \
	echo "[OK] restore-compiler (restored offline from gzip+base64 parts; no Python, no network)"

seed-bin: fix-seed
	$(CC) -O2 -o $(SEED_BIN) $(SEED_C) -I selfhost/seed
	@echo "[OK] seed-bin"

$(GEN1_C): seed-bin restore-compiler
	./$(SEED_BIN) $(MIN_SA) > $(GEN1_C)
	@test -s $(GEN1_C)

$(GEN1): $(GEN1_C)
	$(CC) -O2 -o $(GEN1) $(GEN1_C) -I selfhost/seed
	@echo "[OK] gen1"

# The maintained gen2 path is bootstrapped by the small pure-min C seed.
# The older full-seed route is experimental and does not define this target.
$(GEN1_MIN_C): $(SEED_MIN_BIN) restore-compiler
	./$(SEED_MIN_BIN) $(MIN_SA) > $(GEN1_MIN_C)
	@test -s $(GEN1_MIN_C)

$(GEN1_MIN): $(GEN1_MIN_C)
	$(CC) -O2 -o $(GEN1_MIN) $(GEN1_MIN_C)
	@echo "[OK] gen1_min"

$(GEN2_C): $(GEN1_MIN) restore-compiler
	./$(GEN1_MIN) $(MIN_SA) $(GEN2_C)
	@test -s $(GEN2_C)

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

$(SXFMT_BIN): $(GEN2) tools/sxfmt.sa
	./$(GEN2) tools/sxfmt.sa $(SXFMT_C) >/dev/null
	$(CC) -O2 -o $(SXFMT_BIN) $(SXFMT_C)
	@echo "[OK] Sayanox formatter built from tools/sxfmt.sa"

sxfmt: $(SXFMT_BIN)

$(SXPKG_BIN): $(GEN2) tools/sxpkg.sa
	./$(GEN2) tools/sxpkg.sa $(SXPKG_C) >/dev/null
	$(CC) -O2 -o $(SXPKG_BIN) $(SXPKG_C)
	@echo "[OK] Sayanox local package-lock tool built from tools/sxpkg.sa"

sxpkg: $(SXPKG_BIN)
tools: sxfmt sxpkg

# The language server is a normal Sayanox program: gen2 compiles it, cc builds it.
$(LSP_BIN): $(GEN2) tools/sayanox_lsp.sa
	$(GEN2) tools/sayanox_lsp.sa $(LSP_C)
	$(CC) -O2 -o $(LSP_BIN) $(LSP_C)

lsp: $(LSP_BIN)
	@echo "=== LSP-OK ==="

# A full JSON-RPC session against the built server: initialize, didOpen,
# hover, definition, documentSymbol, completion, diagnostic, didChange,
# shutdown, exit.  The probe prints one line per verified fact.
test-lsp: $(LSP_BIN) tools/sayanox-lsp-probe.sh
	@mkdir -p $(TESTS)
	$(call assert-out,sh tools/sayanox-lsp-probe.sh ./$(LSP_BIN) $(TESTS)/lsp-probe,initialize\nserverInfo\ndiag unknown-statement\ndiag unterminated-string\ndiag unbalanced-braces\ndiag unresolved-use\nsymbol function\nsymbol variable\ncompletion builtin\ncompletion literal preserved\nhover builtin\ndefinition\ndiagnostics cleared on change)
	@echo "[OK] Sayanox LSP: live JSON-RPC session, real diagnostics, symbols, completion, hover, definition"

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

test-sxpkg-wrapper: sxpkg tools/sxpkg.sh
	@mkdir -p $(TESTS)/sxpkg-wrapper
	@printf '' > $(TESTS)/sxpkg-wrapper/sx.lock
	@printf '' > $(TESTS)/sxpkg-wrapper/sx.toml
	cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh init >/dev/null
	cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh add local-pkg >/dev/null
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh list,sxpkg: locked packages\nlocal-pkg=0.1.0)
	cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh remove local-pkg >/dev/null
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh list,sxpkg: locked packages\n(none))
	cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh seed >/dev/null
	@printf 'hello=0.1.0\nmath=0.1.0\n' > $(TESTS)/sxpkg-wrapper/index-want
	cmp $(TESTS)/sxpkg-wrapper/index-want $(TESTS)/sxpkg-wrapper/.sayanox/registry/INDEX
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh search math,sxpkg: search math\n  math 0.1.0)
	$(call assert-out,cd $(TESTS)/sxpkg-wrapper && sh ../../../tools/sxpkg.sh info math,name=math\nversion=0.1.0\ndesc=tiny math helpers (dbl, sqr)\nsum=718013937)
	@mkdir -p $(TESTS)/sxpkg-wrapper/project
	@printf '' > $(TESTS)/sxpkg-wrapper/project/sx.lock
	@printf '' > $(TESTS)/sxpkg-wrapper/project/sx.toml
	cd $(TESTS)/sxpkg-wrapper && SAYANOX_ROOT=project sh ../../../tools/sxpkg.sh init >/dev/null
	@printf '# sx.lock\nversion=1\n' > $(TESTS)/sxpkg-wrapper/project/lock-want
	cmp $(TESTS)/sxpkg-wrapper/project/lock-want $(TESTS)/sxpkg-wrapper/project/sx.lock
	cd $(TESTS)/sxpkg-wrapper && SAYANOX_ROOT=project sh ../../../tools/sxpkg.sh add rooted 0.1.0 >/dev/null
	@printf '# sx.lock\nversion=1\nrooted=0.1.0\n' > $(TESTS)/sxpkg-wrapper/project/lock-want
	cmp $(TESTS)/sxpkg-wrapper/project/lock-want $(TESTS)/sxpkg-wrapper/project/sx.lock
	@echo "[OK] sxpkg.sh delegates local commands to Sayanox"


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
	@printf 'hold xs = [5, 6]\nshow xs[len(xs) - 1]\n' > $(TESTS)/ts_li5.sa
	./$(GEN2) $(TESTS)/ts_li5.sa $(TESTS)/ts_li5.c >/dev/null
	@grep -q '#error' $(TESTS)/ts_li5.c
	@echo "[OK] gen2 lists: literal, index, len, push, guards"

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
	@# a list still cannot be a struct field
	@printf 'struct Point {\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: [1], b: Point { 2 } }\n' > $(TESTS)/ts_nestlist.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestlist.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a list in a struct field"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_nestlist.sa $(TESTS)/ts_nestlist_g2.c >/dev/null 2>&1 || true
	@grep -q '#error' $(TESTS)/ts_nestlist_g2.c
	@# chaining through a field with no struct type is a clear error, not bad C
	@printf 'struct Point {\n  x\n}\nstruct Line {\n  a\n}\nhold p = Point { x: 1 }\nhold l = Line { a: p }\nshow l.a.x\n' > $(TESTS)/ts_nestmiss.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestmiss.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a chain through an untyped struct field"; exit 1; fi
	@./$(GEN2) $(TESTS)/ts_nestmiss.sa $(TESTS)/ts_nestmiss_g2.c >/dev/null 2>&1 || true
	@grep -q 'is not a struct' $(TESTS)/ts_nestmiss_g2.c
	@# a struct value cannot be shown
	@printf 'struct Point {\n  x\n}\nhold q = Point { x: 1 }\nshow q\n' > $(TESTS)/ts_nestshow.sa
	@./$(GEN2) $(TESTS)/ts_nestshow.sa $(TESTS)/ts_nestshow_g2.c >/dev/null 2>&1 || true
	@grep -q 'show value cannot be a struct' $(TESTS)/ts_nestshow_g2.c
	@echo "[OK] nested structs in seed-min and gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies incl. doubly nested); clear errors for forward decls, list fields, bad chains, show-of-struct"

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
	@grep -q "builtin 'len' inside a parenthesized expression" $(TESTS)/ts_parenb_g2.c
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
	@if ./$(SEED_MIN_BIN) $(TESTS)/fl_for.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted for/break/continue (gen2-only)"; exit 1; fi
	@printf 'hold xs = [3, 4, 5]\nhold sum = 0\nfor v in xs {\n  hold sum = sum + v\n}\nshow sum\nfor v in xs {\n  when v == 4 {\n    continue\n  }\n  show v\n}\n' > $(TESTS)/fl_list.sa
	./$(GEN2) $(TESTS)/fl_list.sa $(TESTS)/fl_list.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_list $(TESTS)/fl_list.c
	$(call assert-out,./$(TESTS)/fl_list,12\n3\n5)
	@printf 'hold grade = 0\nhold score = 85\nwhen score >= 90 {\n  hold grade = 4\n} elif score >= 80 {\n  hold grade = 3\n} elif score >= 70 {\n  hold grade = 2\n} otherwise {\n  hold grade = 1\n}\nshow grade\nwhen score >= 80 {\n  hold grade = 9\n} elif score >= 70 {\n  hold grade = 8\n}\nshow grade\n' > $(TESTS)/fl_elif.sa
	./$(GEN2) $(TESTS)/fl_elif.sa $(TESTS)/fl_elif.c >/dev/null
	$(CC) -O2 -o $(TESTS)/fl_elif $(TESTS)/fl_elif.c
	$(call assert-out,./$(TESTS)/fl_elif,3\n9)
	@if ./$(SEED_MIN_BIN) $(TESTS)/fl_elif.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted elif (gen2-only)"; exit 1; fi
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
	@# `make NAME<T>` is a full-language feature: the seed cannot read it
	@if ./$(SEED_MIN_BIN) $(TESTS)/tg.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a generic definition"; exit 1; fi
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
	@# native has no generics at all
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/tg_mp.sa $(TESTS)/tg_mp_nat 2>&1 | grep -q 'generics are not in the native subset'; then :; \
	  else echo "[FAIL] native did not reject make NAME<A, B>"; exit 1; fi; \
	fi
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
	@# continue is a full-language (gen2+) statement, still unknown to the seed
	@printf 'hold i = 0\nwhile i < 3 {\n  hold i = i + 1\n  when i == 2 { continue }\n}\nshow i\n' > $(TESTS)/ts_cont.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_cont.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted continue (a gen2-only statement)"; exit 1; fi
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
	  __i=$$(printf '%s\n' "$$__o" | sed -n 1p); \
	  __r=$$(printf '%s\n' "$$__o" | sed -n 2p); \
	  if [ "$$__i" != "200000" ]; then \
	    echo "[FAIL] native churn loop under a 4 MiB cap printed $$__o"; exit 1; fi; \
	  if [ "$$__r" -lt 1 ] 2>/dev/null; then \
	    echo "[FAIL] native churn loop under a 4 MiB cap ran no collection"; exit 1; fi
	@echo "[OK] native collector: 200k allocating iterations (~8 MB) stay inside a 4 MiB cap"
	@# ---- gc() / gc_live() / gc_runs() are real, not no-ops ----
	@printf 'hold i = 0\nwhile i < 5000 {\n  hold t = concat("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "b")\n  hold i = i + 1\n}\nshow gc_runs()\nshow gc()\nshow gc_live()\n' > $(TESTS)/native_mem_gc.sa
	./$(NATIVE_BIN) $(TESTS)/native_mem_gc.sa $(TESTS)/native_mem_gc
	@__o=$$(./$(TESTS)/native_mem_gc); \
	  __r=$$(printf '%s\n' "$$__o" | sed -n 1p); \
	  __c=$$(printf '%s\n' "$$__o" | sed -n 2p); \
	  __l=$$(printf '%s\n' "$$__o" | sed -n 3p); \
	  if [ "$$__r" -lt 1 ] 2>/dev/null; then \
	    echo "[FAIL] native gc_runs() reported $$__r after 5000 allocating iterations"; exit 1; fi; \
	  if [ "$$__c" -lt 1 ] 2>/dev/null; then \
	    echo "[FAIL] native gc() reclaimed $$__c bytes"; exit 1; fi; \
	  if [ "$$__l" -lt 1 ] 2>/dev/null; then \
	    echo "[FAIL] native gc_live() reported $$__l"; exit 1; fi
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
	$(call assert-out,sh -c 'ulimit -v 4096; ./$(TESTS)/native_oom_out 2>/dev/null',before)
	@if sh -c 'ulimit -v 4096; ./$(TESTS)/native_oom_out >/dev/null 2>$(TESTS)/native_oom_out.err'; then \
	  echo "[FAIL] native survived the 4 MiB cap while retaining 8 MiB"; exit 1; fi
	@grep -q 'out of memory' $(TESTS)/native_oom_out.err
	@echo "[OK] native memory: a real free path (churn fits in 4 MiB, reachable values survive, an 8 MiB live set still dies loudly)"

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
# been built (native-test).  Numeric helpers only - string-returning
# functions and list/string parameters are outside the native subset.
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
	@# typed parameters (`make s_len(s: str) -> num`) are a full-language
	@# feature, so seed-min and native must refuse these files loudly rather
	@# than emit a program that calls sx_len() on a double.
	@printf 'use "stdlib/str_util.sa"\nuse "stdlib/list_util.sa"\nuse "stdlib/file_util.sa"\nshow s_len("hello")\nshow s_at("hello", 1)\nshow s_join("ab", "cd")\nshow s_prefix("hello", 3)\nshow s_prefix("hi", 9)\nshow s_suffix("hello", 2)\nshow s_suffix("hi", 9)\nshow s_reverse("hello")\nshow s_repeat("xy", 3)\nshow s_count("banana", 97)\nshow s_contains("banana", 97)\nshow s_contains("banana", 122)\nshow s_eq("ab", "ab")\nshow s_eq("ab", "ac")\nshow s_upper("Hi There 42!")\nshow s_lower("Hi There 42!")\nshow s_starts("hello", "he")\nshow s_starts("hello", "lo")\nshow s_ends("hello", "lo")\nshow s_ends("hello", "he")\nhold xs = [3, 1, 4, 1, 5]\nshow l_len(xs)\nshow l_get(xs, 2)\nshow l_sum(xs)\nshow l_max(xs)\nshow l_min(xs)\nshow l_count(xs, 1)\nshow l_contains(xs, 9)\nhold r = l_reverse(xs)\nshow len(r)\nshow r[0]\nshow r[4]\nhold g = l_range(4)\nshow len(g)\nshow g[3]\nhold p = "$(TESTS)/std_f.txt"\nshow f_write(p, "one\\ntwo\\nthree")\nshow f_read(p)\nshow f_size(p)\nshow f_lines(p)\nshow f_exists(p)\nshow f_exists("$(TESTS)/std_no_such_file")\n' > $(TESTS)/std_sl.sa
	./$(GEN2) $(TESTS)/std_sl.sa $(TESTS)/std_sl.c >/dev/null
	$(CC) -O2 -Wall -o $(TESTS)/std_sl $(TESTS)/std_sl.c 2>$(TESTS)/std_sl.warn
	@if grep -q ' error' $(TESTS)/std_sl.warn; then \
	  echo "[FAIL] stdlib str/list/file module produced C that does not build"; \
	  head -20 $(TESTS)/std_sl.warn; exit 1; fi
	$(call assert-out,./$(TESTS)/std_sl,5\n101\nabcd\nhel\nhi\nlo\nhi\nolleh\nxyxyxy\n3\n1\n0\n1\n0\nHI THERE 42!\nhi there 42!\n1\n0\n1\n0\n5\n4\n14\n5\n1\n2\n0\n5\n5\n3\n4\n3\n1\none\ntwo\nthree\n13\n3\n1\n0)
	@if ./$(SEED_MIN_BIN) $(TESTS)/std_sl.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted the str/list module (it must refuse typed parameters)"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/std_sl.sa $(TESTS)/std_sl_nat >/dev/null 2>&1; then \
	    echo "[FAIL] native accepted the str/list module (it must refuse typed parameters)"; exit 1; fi; \
	fi
	@echo "[OK] stdlib str/list/file modules on gen2 (typed parameters); seed-min and native refuse them with a clear error"

# ---------------------------------------------------------------------------
# test-pkgs: the offline package use-path, with no network at all.
#
#   * `tools/sxpkg.sh init` (mkdir only) plus the Sayanox `sxpkg seed` writes a
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
	cd $(TESTS)/pkgs-proj && sh ../../../tools/sxpkg.sh init >/dev/null
	cd $(TESTS)/pkgs-proj && sh ../../../tools/sxpkg.sh seed >/dev/null
	cd $(TESTS)/pkgs-proj && test -s .sayanox/registry/math/main.sa
	cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) add math 0.1.0 >/dev/null
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) list,sxpkg: locked packages\nmath=0.1.0)
	$(call assert-out,cd $(TESTS)/pkgs-proj && sh ../../../tools/sxpkg.sh search math,sxpkg: search math\n  math 0.1.0)
	@printf 'use ".sayanox/registry/math/main.sa"\nshow dbl(21)\nshow sqr(6)\n' > $(TESTS)/pkgs-proj/use_math.sa
	./$(SEED_MIN_BIN) $(TESTS)/pkgs-proj/use_math.sa > $(TESTS)/pkgs-proj/use_sm.c
	$(CC) -O2 -o $(TESTS)/pkgs-proj/use_sm $(TESTS)/pkgs-proj/use_sm.c
	./$(GEN2) $(TESTS)/pkgs-proj/use_math.sa $(TESTS)/pkgs-proj/use_g2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/pkgs-proj/use_g2 $(TESTS)/pkgs-proj/use_g2.c
	@cd $(TESTS)/pkgs-proj && ./use_sm > use_sm.out && ./use_g2 > use_g2.out && cmp use_sm.out use_g2.out
	$(call assert-out,cd $(TESTS)/pkgs-proj && ./use_g2,42\n36)
	@# offline integrity: the lock is checked against the registry copy (version + pkg.meta sum)
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) verify,sxpkg: verified math 0.1.0\nsxpkg: verify ok (1 locked packages))
	@printf 'make dbl(n) {\n  give n + n + 0\n}\n' > $(TESTS)/pkgs-proj/.sayanox/registry/math/main.sa
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) verify,sxpkg: MISMATCH math: main.sa sums to 115762249 but pkg.meta says 718013937\nsxpkg: verify FAILED (1 problem(s)))
	cd $(TESTS)/pkgs-proj && sh ../../../tools/sxpkg.sh seed >/dev/null
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) verify,sxpkg: verified math 0.1.0\nsxpkg: verify ok (1 locked packages))
	$(call assert-out,cd $(TESTS)/pkgs-proj && ../../../$(SXPKG_BIN) sum .sayanox/registry/math/main.sa,sxpkg: sum 718013937 .sayanox/registry/math/main.sa)
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/pkgs-proj/use_math.sa $(TESTS)/pkgs-proj/use_nat && \
	  cd $(TESTS)/pkgs-proj && ./use_nat > use_nat.out && cmp use_sm.out use_nat.out || exit 1; \
	fi
	@echo "[OK] offline packages: sxpkg seed writes .sayanox/registry (no network), use \".sayanox/registry/math/main.sa\" runs the same on seed-min, gen2 (and native when built)"

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
	@# seed-min is the pure-min dialect: it must refuse every Stage-2 form here
	@if ./$(SEED_MIN_BIN) $(TESTS)/s2.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted the Stage-2 program"; exit 1; fi
	@# native names the forms it does not have instead of miscompiling them
	@if [ -x $(NATIVE_BIN) ]; then \
	  printf 'hold xs = [1, 2]\nfor v in xs {\n  show v\n}\n' > $(TESTS)/s2_for.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_for.sa $(TESTS)/s2_for 2>&1 | grep -q "'for' is a full-language statement" || { echo "[FAIL] native did not name the for statement"; exit 1; }; \
	  printf 'hold a = 1\nhold b = 0\nwhen a == 1 and b == 0 {\n  show 1\n}\n' > $(TESTS)/s2_and.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_and.sa $(TESTS)/s2_and 2>&1 | grep -q "'and' is a full-language word operator" || { echo "[FAIL] native did not name the and operator"; exit 1; }; \
	  printf 'hold a = 1\nwhen not (a == 2) {\n  show 1\n}\n' > $(TESTS)/s2_not.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_not.sa $(TESTS)/s2_not 2>&1 | grep -q "'not' is a full-language word operator" || { echo "[FAIL] native did not name the not operator"; exit 1; }; \
	  printf 'show true\n' > $(TESTS)/s2_true.sa; \
	  ./$(NATIVE_BIN) $(TESTS)/s2_true.sa $(TESTS)/s2_true 2>&1 | grep -q "'true' is a full-language word operator" || { echo "[FAIL] native did not name the true literal"; exit 1; }; \
	  echo "  native names for/and/not/true by name"; \
	else \
	  echo "[stage2] native rejection: skipped (native_aot is not built here)"; \
	fi
	@echo "[OK] Stage-2 language: and/or/not precedence and short-circuit, not binds looser than a comparison, true/false, for over a list variable/literal/call, nested loops, break/continue, elif chains; gen2 == gen1_min, seed-min refuses, native names the forms"

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
	@# seed-min is the pure-min dialect: it must refuse the statement
	@if ./$(SEED_MIN_BIN) $(TESTS)/fs_vowels.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted for c in s (gen2-only statement)"; exit 1; fi
	@# native (when built) names the statement instead of a misleading error
	@if [ -x $(NATIVE_BIN) ]; then \
	  ./$(NATIVE_BIN) $(TESTS)/fs_vowels.sa $(TESTS)/fs_native 2>&1 | grep -q "'for' is a full-language statement"; \
	  if ./$(NATIVE_BIN) $(TESTS)/fs_vowels.sa $(TESTS)/fs_native >/dev/null 2>&1; then \
	    echo "[FAIL] native accepted for c in s"; exit 1; fi; \
	  echo "[stage2] native rejects for/break/continue by name"; \
	else \
	  echo "[stage2] native rejection: skipped (native_aot is not built here)"; \
	fi
	@# generics: gen2 monomorphises one or more type parameters; native has none
	@printf 'make pair<T>(a: T, b: str) -> T {\n  give a\n}\nshow pair(1, "x")\n' > $(TESTS)/fs_pair.sa
	./$(GEN2) $(TESTS)/fs_pair.sa $(TESTS)/fs_pair.c >/dev/null 2>&1 || true
	@grep -q "must be written with type parameters used by every parameter" $(TESTS)/fs_pair.c
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/fs_pair.sa $(TESTS)/fs_pair_nat 2>&1 | grep -q 'generics are not in the native subset'; then :; \
	  else echo "[FAIL] native did not reject make NAME<...>"; exit 1; fi; \
	fi
	@echo "[OK] Stage-2 slice: for c in <string> on gen2 (vowels, break/continue, empty, nested, rebinding, bytes); seed-min and native refuse it by name"

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
	@# a string against a number is an error on seed-min; native refuses ordering by name
	@printf 'hold s = "ab"\nhold n = 3\nwhen s < n {\n  show 1\n}\n' > $(TESTS)/gg_ordmix.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/gg_ordmix.sa >/dev/null 2>&1; then echo "[FAIL] seed-min accepted string < number"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gg_ord.sa $(TESTS)/gg_ordnat >/dev/null 2>&1; then echo "[FAIL] native accepted string ordering"; exit 1; fi; \
	  ./$(NATIVE_BIN) $(TESTS)/gg_ord.sa $(TESTS)/gg_ordnat 2>&1 | grep -q 'not in the native subset'; \
	fi
	@# the chain forms are gen2 only: seed-min and native must refuse them
	@if ./$(SEED_MIN_BIN) $(TESTS)/gg_chain.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted an else-when/else-if chain"; exit 1; fi
	@if [ -x $(NATIVE_BIN) ]; then \
	  if ./$(NATIVE_BIN) $(TESTS)/gg_chain.sa $(TESTS)/gg_nat >/dev/null 2>&1; then \
	    echo "[FAIL] native accepted an else-when/else-if chain"; exit 1; fi; \
	  echo "[gen2-gaps] native rejects the chain forms"; \
	fi
	@echo "[OK] gen2 gaps: len() in a range bound (list and string), string == / != on runtime strings, else when / else if / otherwise when chains (incl. nested) on gen2, % inside builtin-call arguments (sx_mod, same as seed-min); seed-min and native refuse the chains"

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
	@$(MAKE) test-reassign test-while test-when test-mod test-struct2 test-list2 test-use test-fn2 test-chain test-condmod test-user test-nest test-prec test-float test-parens test-push-stmt test-full-lang test-generics test-parity test-stage2-demos test-stage2 test-for-str test-gen2-gaps test-stdlib test-pkgs test-registry-sums test-builtin-names test-sxfmt test-sxpkg test-lsp test-gc
	@if cmp -s $(GEN1_MIN_C) $(GEN2_C); then echo "[FAIL] frozen copy"; exit 1; fi
	@$(MAKE) test-boot
	@echo "=== TRUE-SELFHOST-MIN-OK ==="

# Retain the historical target name without claiming full Stage-2 support.
true-selfhost-full: true-selfhost-min
	@echo "[INFO] full Stage-2 remains unfinished; only the pure-min path is verified"

true-selfhost: true-selfhost-min
selfhost: true-selfhost

$(NATIVE_BIN): $(NATIVE_SRC)
	$(CC) -O2 -o $(NATIVE_BIN) $(NATIVE_SRC)
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
	@# nested-struct forms native must reject with a clear error, not mis-compile
	@printf 'struct Line {\n  a\n}\nstruct Point {\n  x\n}\nhold l = Line { a: Point { 1 } }\n' > $(TESTS)/native_nestfwd.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_nestfwd.sa $(TESTS)/native_nestfwd 2>/dev/null; then \
	  echo "[FAIL] native accepted a nested struct declared later"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_nestfwd.sa $(TESTS)/native_nestfwd 2>&1 | grep -q 'declare the nested struct first'
	@printf 'struct Point {\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: [1], b: Point { 2 } }\n' > $(TESTS)/native_nestlist.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_nestlist.sa $(TESTS)/native_nestlist 2>/dev/null; then \
	  echo "[FAIL] native accepted a list in a struct field"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_nestlist.sa $(TESTS)/native_nestlist 2>&1 | grep -q 'cannot hold a list'
	@printf 'struct Point {\n  x\n}\nhold q = Point { x: 1 }\nshow q\n' > $(TESTS)/native_showstruct.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_showstruct.sa $(TESTS)/native_showstruct 2>/dev/null; then \
	  echo "[FAIL] native accepted show of a struct"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_showstruct.sa $(TESTS)/native_showstruct 2>&1 | grep -q 'show of a struct'
	@printf 'struct Point {\n  x\n}\nhold p = Point { x: 1 }\nshow p.x.y\n' > $(TESTS)/native_nestchain.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_nestchain.sa $(TESTS)/native_nestchain 2>/dev/null; then \
	  echo "[FAIL] native accepted a chain through a number field"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_nestchain.sa $(TESTS)/native_nestchain 2>&1 | grep -q 'cannot access a field'
	@echo "[OK] native rejects (clearly): later-declared nesting, list in struct, show of struct, bad chain"
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
	@if ./$(NATIVE_BIN) $(TESTS)/native_fnhold.sa $(TESTS)/native_fnhold 2>/dev/null; then \
	  echo "[FAIL] native accepted hold inside a function (a local in the data segment breaks recursion)"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_fnhold.sa $(TESTS)/native_fnhold 2>&1 | grep -q 'hold inside make is not in the native subset'
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
	@echo "[OK] native rejects (clearly): hold inside make, give outside make, make inside a block, wrong arg count, non-numeric arg, non-numeric give"
	@$(MAKE) --no-print-directory test-native-num test-native-io test-native-mem test-stdlib test-stage2-demos test-stage2 test-for-str
	@echo "[OK] native: modulo, else alias, distinct name slots, undefined names, lists, structs, nested structs, use splice, functions"
	@echo "=== NATIVE-TEST-OK ==="

grammar: true-selfhost-min
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  hold n = n + 1\n}\nwhen n == 3 {\n  show "grammar-ok"\n} otherwise {\n  show "grammar-fail"\n}\n' > $(TESTS)/grammar.sa
	./$(GEN2) $(TESTS)/grammar.sa $(TESTS)/grammar.c >/dev/null
	$(CC) -O2 -o $(TESTS)/grammar $(TESTS)/grammar.c
	$(call assert-out,./$(TESTS)/grammar,grammar-ok)
	@echo "=== GRAMMAR-OK ==="

gc-test:
	$(CC) -O2 -o $(TESTS)/rc_runtime_stress selfhost/rc_runtime_stress.c
	@# 2005 = the 5 chars of "start" plus the 2000 appends in the stress loop.
	@# The old check was `grep -qx gc-rc-ok`, which passed no matter what size
	@# the concat chain came out as; pinning it makes the length part of the test.
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
	@echo "=== GEN3-OK ==="

subset: seed-bin
	@printf 'hold x = 42\nshow x\n' > selfhost/_smoke.sa
	./$(SEED_BIN) selfhost/_smoke.sa > selfhost/_smoke.c
	$(CC) -O2 -o selfhost/_smoke selfhost/_smoke.c -I selfhost/seed
	$(call assert-out,./selfhost/_smoke,42)
	@echo "=== SUBSET-SELFHOST-OK ==="

gen1: $(GEN1_MIN)
	@echo "=== GEN1-MIN-OK ==="
gen2: $(GEN2)
	@echo "=== GEN2-OK ==="
test: true-selfhost
	@echo TEST-OK

# clean removes only GENERATED files -- $(SEED_BIN) (selfhost/seed/sxc_seed) is
# tracked in git, and `make clean` deleting a tracked file used to leave a
# deleted-but-committed binary in the working tree.  Rebuild it with
# `make seed-bin` (it is a .PHONY target, so it always rebuilds from source).
clean:
	rm -f $(GEN1) $(GEN1_C) $(GEN1_MIN) $(GEN1_MIN_C) $(GEN2) $(GEN2_C) $(GEN3) $(GEN3_C) selfhost/gen4.c
	rm -f $(SEED_MIN_BIN) $(NATIVE_BIN) selfhost/boot_from_gen2 selfhost/boot_from_gen2.c $(SXFMT_BIN) $(SXFMT_C) $(SXPKG_BIN) $(SXPKG_C) $(LSP_BIN) $(LSP_C)

# ---------------------------------------------------------------------------
# doctor: check that the minimal tool set is present. Nothing else is needed to
# bootstrap Sayanox from this repository.
#
#   required : make, a C99 compiler (cc/clang/gcc), a POSIX shell
#   optional : base64 + gzip -- only for the offline compiler_min.sa fallback
#
# Everything else the Makefile uses is provided by the shell itself (printf,
# test, command substitution, parameter expansion).
# ---------------------------------------------------------------------------
doctor:
	@fail=0; \
	echo "Sayanox minimal toolchain check"; \
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
	echo "--------------------------------"; \
	printf 'python          '; command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 \
	  && echo "present, but NOT used anywhere on the bootstrap path" \
	  || echo "absent - fine, nothing needs it"; \
	printf 'node/ruby       '; command -v node >/dev/null 2>&1 || command -v ruby >/dev/null 2>&1 \
	  && echo "present, but NOT used anywhere on the bootstrap path" \
	  || echo "absent - fine, nothing needs it"; \
	echo "--------------------------------"; \
	if [ $$fail -eq 0 ]; then echo "DOCTOR-OK: minimal tool set is complete"; \
	else echo "DOCTOR-FAIL: a required tool is missing"; exit 1; fi

