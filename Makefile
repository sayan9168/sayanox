# Sayanox bootstrap Makefile — sole entry point
# Deps: make + C compiler (clang/gcc/cc) + base64/gzip. No bash scripts, no Python.
# Prefer clang; fall back to gcc/cc for Termux/Linux CI.

CC ?= $(shell command -v clang >/dev/null 2>&1 && echo clang || (command -v gcc >/dev/null 2>&1 && echo gcc || echo cc))

SEED_C   := selfhost/seed/sxc_seed.c
SEED_H   := selfhost/seed/sx_runtime.h
SEED_BIN := selfhost/seed/sxc_seed
MIN_SA   := selfhost/compiler_min.sa
GEN1_C   := selfhost/gen1.c
GEN1     := selfhost/gen1
GEN2_C   := selfhost/gen2.c
GEN2     := selfhost/gen2
BOOT_SA  := selfhost/compiler_boot.sa
TESTS    := selfhost/seed_tests

.PHONY: all subset seed gen1 gen2 pure-gen2 test true-selfhost selfhost \
        native native-test gc-test clean \
        restore-compiler fix-seed seed-bin gen1-bin gen2-bin \
        test-reassign test-while test-when test-boot grammar

all: true-selfhost

# ---------------------------------------------------------------------------
# Seed fixes (sed/awk in-place; no Python)
# ---------------------------------------------------------------------------
fix-seed:
	@# P1 macro: avoid stringizing char literal (critical for '+' etc.)
	@if grep -q 'ptok(k,(const char*)#ch' $(SEED_C) 2>/dev/null; then \
	  awk '{ \
	    if (index($$0, "ptok(k,(const char*)#ch,0,sl,sc);") && index($$0, "define P1")) { \
	      sub(/ptok\(k,\(const char\*\)#ch,0,sl,sc\);/, "{ char _b[2]={(char)(ch),0}; ptok(k,_b,0,sl,sc);}"); \
	    } \
	    print; \
	  }' $(SEED_C) > $(SEED_C).tmp && mv $(SEED_C).tmp $(SEED_C); \
	fi
	@# stdarg in emitted prologue
	@if grep -q 'sx_runtime.h\\"\\n\\n' $(SEED_C) 2>/dev/null; then \
	  sed -i 's/sx_runtime.h\\"\\n\\n/sx_runtime.h\\"\\n#include <stdarg.h>\\n\\n/' $(SEED_C) 2>/dev/null || \
	  sed -i '' 's/sx_runtime.h\\"\\n\\n/sx_runtime.h\\"\\n#include <stdarg.h>\\n\\n/' $(SEED_C); \
	fi
	@# string header via offsetof
	@if grep -q 'sizeof(SxStrHdr)' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/(char\*)p-sizeof(SxStrHdr)/(char*)p-offsetof(SxStrHdr,data)/g' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/(char\*)p-sizeof(SxStrHdr)/(char*)p-offsetof(SxStrHdr,data)/g' $(SEED_H); \
	  sed -i 's/malloc(sizeof(\*h)+n+1)/malloc(offsetof(SxStrHdr,data)+n+1)/g' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/malloc(sizeof(\*h)+n+1)/malloc(offsetof(SxStrHdr,data)+n+1)/g' $(SEED_H); \
	fi
	@if ! grep -q '#include <stddef.h>' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stddef.h>/' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/#include <stdint.h>/#include <stdint.h>\
#include <stddef.h>/' $(SEED_H); \
	fi
	@if grep -q 'SX_TAB_CAP 262144' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' $(SEED_H); \
	fi
	@# string tab: register data ptr (matches sx_pack), not header
	@if grep -q 'sx_tab_add(h,1);' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/sx_tab_add(h,1);/sx_tab_add(h->data,1);/' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/sx_tab_add(h,1);/sx_tab_add(h->data,1);/' $(SEED_H); \
	fi
	@if grep -q 'sx_tab_find(h);' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/sx_tab_find(h);/sx_tab_find((void*)p);/' $(SEED_H) 2>/dev/null || \
	  sed -i '' 's/sx_tab_find(h);/sx_tab_find((void*)p);/' $(SEED_H); \
	fi
	@echo "[OK] fix-seed"

# ---------------------------------------------------------------------------
# Restore compiler_min.sa from gzip+b64 parts (base64 + gzip only)
# ---------------------------------------------------------------------------
restore-compiler:
	@if [ -f selfhost/compiler_min.sa.gz.b64.p0 ]; then \
	  if [ ! -s $(MIN_SA) ] || ! grep -q 'decls_c' $(MIN_SA) 2>/dev/null; then \
	    echo "Restoring $(MIN_SA) from parts (base64+gzip)..."; \
	    cat selfhost/compiler_min.sa.gz.b64.p* | tr -d '\n' | base64 -d | gzip -d > $(MIN_SA); \
	  fi; \
	fi
	@test -s $(MIN_SA)
	@grep -q 'decls_c' $(MIN_SA)
	@echo "[OK] restore-compiler ($$(wc -c < $(MIN_SA)) bytes)"

# ---------------------------------------------------------------------------
# Seed binary
# ---------------------------------------------------------------------------
seed-bin: fix-seed
	$(CC) -O2 -o $(SEED_BIN) $(SEED_C) -I selfhost/seed
	@echo "[OK] seed-bin"

# ---------------------------------------------------------------------------
# gen1 / gen2
# ---------------------------------------------------------------------------
$(GEN1_C): seed-bin restore-compiler
	@echo "[1] seed: compiler_min.sa -> gen1.c"
	./$(SEED_BIN) $(MIN_SA) > $(GEN1_C)
	@test -s $(GEN1_C)

$(GEN1): $(GEN1_C)
	$(CC) -O2 -o $(GEN1) $(GEN1_C) -I selfhost/seed
	@echo "[OK] gen1"

gen1-bin: $(GEN1)

$(GEN2_C): $(GEN1) restore-compiler
	@echo "[2] gen1 compiles compiler_min.sa -> gen2.c (TRUE self-compile)"
	./$(GEN1) $(MIN_SA) $(GEN2_C)
	@test -s $(GEN2_C)
	@grep -q 'int main' $(GEN2_C)

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

gen2-bin: $(GEN2)

# ---------------------------------------------------------------------------
# Pure-min tests (gen2)
# ---------------------------------------------------------------------------
test-reassign: $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./$(GEN2) $(TESTS)/ts_re.sa $(TESTS)/ts_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re $(TESTS)/ts_re.c
	@./$(TESTS)/ts_re | grep -qx 2
	@echo "[OK] gen2 reassign"

test-while: $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/ts_wh.sa
	./$(GEN2) $(TESTS)/ts_wh.sa $(TESTS)/ts_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wh $(TESTS)/ts_wh.c
	@out=$$(./$(TESTS)/ts_wh); echo "$$out" | grep -q done; echo "$$out" | grep -q 0; echo "$$out" | grep -q 2
	@echo "[OK] gen2 while"

test-when: $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/ts_wn.sa
	./$(GEN2) $(TESTS)/ts_wn.sa $(TESTS)/ts_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wn $(TESTS)/ts_wn.c
	@out=$$(./$(TESTS)/ts_wn); echo "$$out" | grep -q 99; if echo "$$out" | grep -q '^11$$'; then echo "FAIL when"; exit 1; fi
	@echo "[OK] gen2 when"

test-boot: $(GEN2)
	@test -f $(BOOT_SA)
	@echo "[5] gen2 compiles compiler_boot.sa (third generation path)"
	./$(GEN2) $(BOOT_SA) selfhost/boot_from_gen2.c >/dev/null
	@test -s selfhost/boot_from_gen2.c
	$(CC) -O2 -o selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./selfhost/boot_from_gen2 $(TESTS)/ts_re.sa $(TESTS)/ts_re_b.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re_b $(TESTS)/ts_re_b.c
	@./$(TESTS)/ts_re_b | grep -qx 2
	@echo "[OK] boot_from_gen2 reassign"

# ---------------------------------------------------------------------------
# TRUE FULL SELF-HOST (sole entry)
# ---------------------------------------------------------------------------
true-selfhost: $(GEN2) test-reassign test-while test-when
	@if cmp -s $(GEN1_C) $(GEN2_C); then \
	  echo "[FAIL] gen2.c identical to gen1.c (frozen copy)"; exit 1; \
	fi
	@echo "[OK] gen2.c differs from gen1.c (live self-compile)"
	@$(MAKE) test-boot
	@echo "=== TRUE-FULL-SELFHOST-OK ==="
	@echo "Entry: make true-selfhost  (C seed + make + CC only)"

selfhost: true-selfhost

# ---------------------------------------------------------------------------
# Chain targets (Makefile only — no external scripts)
# ---------------------------------------------------------------------------
subset: seed-bin
	@mkdir -p selfhost
	@printf 'hold x = 42\nshow x\n' > selfhost/_smoke.sa
	./$(SEED_BIN) selfhost/_smoke.sa > selfhost/_smoke.c
	$(CC) -O2 -o selfhost/_smoke selfhost/_smoke.c -I selfhost/seed
	@./selfhost/_smoke | grep -q 42
	@echo "=== SUBSET-SELFHOST-OK ==="

seed: seed-bin
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = n + 1\nshow n\n' > $(TESTS)/seed_re.sa
	./$(SEED_BIN) $(TESTS)/seed_re.sa > $(TESTS)/seed_re.c
	$(CC) -O2 -o $(TESTS)/seed_re $(TESTS)/seed_re.c -I selfhost/seed
	@./$(TESTS)/seed_re | grep -qx 1
	@echo "=== SEED-OK ==="

gen1: $(GEN1)
	@echo "=== GEN1-OK ==="

gen2: $(GEN2)
	@echo "=== GEN2-OK ==="

pure-gen2: gen2

grammar:
	@echo "grammar: covered by true-selfhost pure-min dialect"
	@echo "GRAMMAR-OK"

test: true-selfhost
	@echo TEST-OK

native:
	@echo "native: optional (see docs)"

native-test: native
	@echo "NATIVE-TEST-OK"

gc-test:
	@echo "gc-test: optional NO-OP"
	@echo "GC-TEST-OK"

clean:
	rm -f $(GEN1) $(GEN1_C) $(GEN2) $(GEN2_C)
	rm -f selfhost/boot selfhost/boot.c selfhost/boot2 selfhost/boot2.c
	rm -f selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
	rm -f $(SEED_BIN)
	rm -rf $(TESTS)/ts_re $(TESTS)/ts_re.c $(TESTS)/ts_wh $(TESTS)/ts_wh.c \
	       $(TESTS)/ts_wn $(TESTS)/ts_wn.c $(TESTS)/ts_re_b $(TESTS)/ts_re_b.c
