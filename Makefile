# Sayanox bootstrap Makefile — sole entry point
# Preferred: make true-selfhost (11KB seed-min). Optional: true-selfhost-full, native, gen3

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

.PHONY: all subset seed gen1 gen2 test true-selfhost true-selfhost-min true-selfhost-full selfhost \
        native native-test seed-min seed-min-gen1 gen3 clean restore-compiler fix-seed verify-seed \
        seed-bin doctor \
        test-reassign test-while test-when test-mod test-struct2 test-list2 test-use \
        test-boot test-fn test-fn2 test-list test-struct test-parity test-chain test-condmod test-user test-nest test-prec \
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

$(GEN2_C): $(GEN1) restore-compiler
	./$(GEN1) $(MIN_SA) $(GEN2_C)
	@test -s $(GEN2_C)

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

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
	@grep -q '(double)((long)(a)%(long)(3))' $(TESTS)/ts_mod.c
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
	@grep -q '(double)((long)(a' $(TESTS)/ts_cm.c
	@grep -q '%(long)(10)' $(TESTS)/ts_cm.c
	$(CC) -O2 -o $(TESTS)/ts_cm $(TESTS)/ts_cm.c
	$(call assert-out,./$(TESTS)/ts_cm,7\n4\n1\n8\n5\n2\nmod-ok)
	@echo "[OK] gen2 while/when condition % long-cast rewrite"

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
	@echo "[OK] nested structs in seed-min and gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies); clear errors for forward decls, list fields, bad chains, show-of-struct"

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
	@# a parenthesized base is the one known seed/gen2 difference: gen2 reports
	@# it (with #error) instead of emitting broken C like `double b = ;`
	@printf 'hold a = 2\nshow (a + 3) * 4\n' > $(TESTS)/ts_paren.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_paren.sa > $(TESTS)/ts_paren_sm.c
	$(CC) -O2 -o $(TESTS)/ts_paren_sm $(TESTS)/ts_paren_sm.c
	$(call assert-out,./$(TESTS)/ts_paren_sm,20)
	./$(GEN2) $(TESTS)/ts_paren.sa $(TESTS)/ts_paren_g2.c >/dev/null
	@grep -q 'parenthesized base is not supported' $(TESTS)/ts_paren_g2.c
	@if $(CC) -O2 -o $(TESTS)/ts_paren_g2 $(TESTS)/ts_paren_g2.c 2>/dev/null; then \
	  echo "[FAIL] gen2 accepted a parenthesized base"; exit 1; fi
	@echo "[OK] parenthesized base: seed-min runs it, gen2 reports it clearly"

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
	@grep -q '(double)((long)(a)%(long)(3))' $(TESTS)/min_mod.c
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
	@$(MAKE) test-reassign test-while test-when test-mod test-struct2 test-list2 test-use test-fn2 test-chain test-condmod test-user test-nest test-parity
	@if cmp -s $(GEN1_MIN_C) $(GEN2_C); then echo "[FAIL] frozen copy"; exit 1; fi
	@$(MAKE) test-boot
	@echo "=== TRUE-SELFHOST-MIN-OK ==="

true-selfhost-full: $(GEN2)
	@$(MAKE) test-reassign test-while test-when test-boot
	@echo "=== TRUE-FULL-SELFHOST-OK ==="

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
	@echo "[OK] native: modulo, else alias, distinct name slots, undefined names, lists, structs, nested structs"
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

gen1: $(GEN1)
	@echo "=== GEN1-OK ==="
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
	rm -f $(SEED_MIN_BIN) $(NATIVE_BIN) selfhost/boot_from_gen2 selfhost/boot_from_gen2.c

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

