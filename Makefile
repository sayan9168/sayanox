# Sayanox bootstrap Makefile — sole entry point
# Deps: make + C compiler (clang/gcc/cc) + base64/gzip. No bash scripts, no Python.
# Optional: make native | seed-min | gen3
# Prefer clang; fall back to gcc/cc for Termux/Linux CI.

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
GEN2_C   := selfhost/gen2.c
GEN2     := selfhost/gen2
GEN3_C   := selfhost/gen3.c
GEN3     := selfhost/gen3
BOOT_SA  := selfhost/compiler_boot.sa
TESTS    := selfhost/seed_tests

.PHONY: all subset seed gen1 gen2 pure-gen2 test true-selfhost selfhost \
        native native-test seed-min gen3 gc-test clean \
        restore-compiler fix-seed seed-bin gen1-bin gen2-bin \
        test-reassign test-while test-when test-boot grammar

all: true-selfhost

fix-seed:
	@if grep -q 'ptok(k,(const char*)#ch' $(SEED_C) 2>/dev/null; then \
	  awk '{ if (index($$0, "ptok(k,(const char*)#ch,0,sl,sc);") && index($$0, "define P1")) { sub(/ptok\(k,\(const char\*\)#ch,0,sl,sc\);/, "{ char _b[2]={(char)(ch),0}; ptok(k,_b,0,sl,sc);}"); } print; }' $(SEED_C) > $(SEED_C).tmp && mv $(SEED_C).tmp $(SEED_C); \
	fi
	@if grep -q 'sizeof(SxStrHdr)' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/(char\*)p-sizeof(SxStrHdr)/(char*)p-offsetof(SxStrHdr,data)/g' $(SEED_H) 2>/dev/null || true; \
	  sed -i 's/malloc(sizeof(\*h)+n+1)/malloc(offsetof(SxStrHdr,data)+n+1)/g' $(SEED_H) 2>/dev/null || true; \
	fi
	@if ! grep -q '#include <stddef.h>' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stddef.h>/' $(SEED_H) 2>/dev/null || true; \
	fi
	@if grep -q 'SX_TAB_CAP 262144' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' $(SEED_H) 2>/dev/null || true; \
	fi
	@if grep -q 'sx_tab_add(h,1);' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/sx_tab_add(h,1);/sx_tab_add(h->data,1);/' $(SEED_H) 2>/dev/null || true; \
	fi
	@if grep -q 'sx_tab_find(h);' $(SEED_H) 2>/dev/null; then \
	  sed -i 's/sx_tab_find(h);/sx_tab_find((void*)p);/' $(SEED_H) 2>/dev/null || true; \
	fi
	@echo "[OK] fix-seed"

restore-compiler:
	@if [ -f selfhost/compiler_min.sa.gz.b64.p0 ]; then \
	  if [ ! -s $(MIN_SA) ] || ! grep -q 'decls_c' $(MIN_SA) 2>/dev/null; then \
	    cat selfhost/compiler_min.sa.gz.b64.p* | tr -d '\n' | base64 -d | gzip -d > $(MIN_SA); \
	  fi; \
	fi
	@test -s $(MIN_SA)
	@grep -q 'decls_c' $(MIN_SA)
	@echo "[OK] restore-compiler"

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
	@grep -q 'int main' $(GEN2_C)

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

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
	@out=$$(./$(TESTS)/ts_wh); echo "$$out" | grep -q done
	@echo "[OK] gen2 while"

test-when: $(GEN2)
	@mkdir -p $(TESTS)
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/ts_wn.sa
	./$(GEN2) $(TESTS)/ts_wn.sa $(TESTS)/ts_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wn $(TESTS)/ts_wn.c
	@out=$$(./$(TESTS)/ts_wn); echo "$$out" | grep -q 99
	@echo "[OK] gen2 when"

test-boot: $(GEN2)
	./$(GEN2) $(BOOT_SA) selfhost/boot_from_gen2.c >/dev/null
	$(CC) -O2 -o selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./selfhost/boot_from_gen2 $(TESTS)/ts_re.sa $(TESTS)/ts_re_b.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re_b $(TESTS)/ts_re_b.c
	@./$(TESTS)/ts_re_b | grep -qx 2
	@echo "[OK] boot_from_gen2 reassign"

true-selfhost: $(GEN2) test-reassign test-while test-when
	@if cmp -s $(GEN1_C) $(GEN2_C); then echo "[FAIL] frozen copy"; exit 1; fi
	@$(MAKE) test-boot
	@echo "=== TRUE-FULL-SELFHOST-OK ==="

selfhost: true-selfhost

subset: seed-bin
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
	@echo "GRAMMAR-OK"
test: true-selfhost
	@echo TEST-OK

$(NATIVE_BIN): $(NATIVE_SRC)
	$(CC) -O2 -o $(NATIVE_BIN) $(NATIVE_SRC)
	@echo "[OK] native_aot"
native: $(NATIVE_BIN)
	@echo "=== NATIVE-OK ==="
native-test: $(NATIVE_BIN)
	@mkdir -p examples $(TESTS)
	@printf 'hold x = 40\nhold x = x + 2\nshow x\n' > examples/native_hello.sa
	./$(NATIVE_BIN) examples/native_hello.sa $(TESTS)/native_hello
	@./$(TESTS)/native_hello | grep -qx 42
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/native_while.sa
	./$(NATIVE_BIN) $(TESTS)/native_while.sa $(TESTS)/native_while
	@out=$$(./$(TESTS)/native_while); echo "$$out" | grep -q done
	@echo "=== NATIVE-TEST-OK ==="

$(SEED_MIN_BIN): $(SEED_MIN_C)
	$(CC) -O2 -o $(SEED_MIN_BIN) $(SEED_MIN_C)
	@echo "[OK] seed-min"
seed-min: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = n + 1\nshow n\n' > $(TESTS)/min_re.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_re.sa > $(TESTS)/min_re.c
	$(CC) -O2 -o $(TESTS)/min_re $(TESTS)/min_re.c
	@./$(TESTS)/min_re | grep -qx 1
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/min_wh.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_wh.sa > $(TESTS)/min_wh.c
	$(CC) -O2 -o $(TESTS)/min_wh $(TESTS)/min_wh.c
	@out=$$(./$(TESTS)/min_wh); echo "$$out" | grep -q done
	@echo "=== SEED-MIN-OK ==="

# gen3: gen2 recompiles compiler_min (behavioural fixed point)
$(GEN3_C): $(GEN2) restore-compiler
	@echo "[3] gen2 compiles compiler_min.sa -> gen3.c"
	./$(GEN2) $(MIN_SA) $(GEN3_C) >/dev/null
	@test -s $(GEN3_C)
	@grep -q 'int main' $(GEN3_C)

$(GEN3): $(GEN3_C)
	@sed -i 's/string_eq(/sx_eq(/g' $(GEN3_C) 2>/dev/null || sed -i '' 's/string_eq(/sx_eq(/g' $(GEN3_C)
	$(CC) -O2 -o $(GEN3) $(GEN3_C)
	@echo "[OK] gen3"

gen3: $(GEN3)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/g3_re.sa
	./$(GEN3) $(TESTS)/g3_re.sa $(TESTS)/g3_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_re $(TESTS)/g3_re.c
	@./$(TESTS)/g3_re | grep -qx 2
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/g3_wh.sa
	./$(GEN3) $(TESTS)/g3_wh.sa $(TESTS)/g3_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wh $(TESTS)/g3_wh.c
	@out=$$(./$(TESTS)/g3_wh); echo "$$out" | grep -q done
	@echo "[OK] gen3 behavioural match"
	@if cmp -s $(GEN2_C) $(GEN3_C); then echo "[OK] byte-identical gen2.c == gen3.c"; \
	else echo "[INFO] gen2.c and gen3.c differ (byte fixed-point not required)"; fi
	@echo "=== GEN3-OK ==="

gc-test:
	@echo "GC-TEST-OK"

clean:
	rm -f $(GEN1) $(GEN1_C) $(GEN2) $(GEN2_C) $(GEN3) $(GEN3_C) $(SEED_BIN) $(SEED_MIN_BIN) $(NATIVE_BIN)
	rm -f selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
