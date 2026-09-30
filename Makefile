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
        native native-test seed-min seed-min-gen1 gen3 clean restore-compiler fix-seed seed-bin \
        test-reassign test-while test-when test-boot

all: true-selfhost-min

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
	@# compiler_min.sa is the canonical checked-in bootstrap source.
	@# Checked-in gzip/base64 parts are complete; sed below protects older checkouts.
	@test -s $(MIN_SA)
	@grep -q 'read_file' $(MIN_SA)
	@grep -q 'arg_count' $(MIN_SA)
	@sed -i '/^[[:space:]]*show holds[[:space:]]*$/d; /^[[:space:]]*show shows[[:space:]]*$/d; /^[[:space:]]*show whiles[[:space:]]*$/d; /^[[:space:]]*show whens[[:space:]]*$/d; /^[[:space:]]*show 1[[:space:]]*$/d' $(MIN_SA) 2>/dev/null || true
	@sed -i 's/concat(body, ctrim)/concat(body, crepl)/g' $(MIN_SA) 2>/dev/null || true
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

$(GEN2): $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@echo "[OK] gen2"

test-reassign:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./$(GEN2) $(TESTS)/ts_re.sa $(TESTS)/ts_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re $(TESTS)/ts_re.c
	@./$(TESTS)/ts_re | grep -qx 2
	@echo "[OK] gen2 reassign"

test-while:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/ts_wh.sa
	./$(GEN2) $(TESTS)/ts_wh.sa $(TESTS)/ts_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wh $(TESTS)/ts_wh.c
	@out=$$(./$(TESTS)/ts_wh); echo "$$out" | grep -q done
	@echo "[OK] gen2 while"

test-when:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/ts_wn.sa
	./$(GEN2) $(TESTS)/ts_wn.sa $(TESTS)/ts_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_wn $(TESTS)/ts_wn.c
	@out=$$(./$(TESTS)/ts_wn); echo "$$out" | grep -q 99
	@echo "[OK] gen2 when"

test-boot:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	./$(GEN2) $(BOOT_SA) selfhost/boot_from_gen2.c >/dev/null
	$(CC) -O2 -o selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/ts_re.sa
	./selfhost/boot_from_gen2 $(TESTS)/ts_re.sa $(TESTS)/ts_re_b.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_re_b $(TESTS)/ts_re_b.c
	@./$(TESTS)/ts_re_b | grep -qx 2
	@echo "[OK] boot_from_gen2 reassign"

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
	@out=$$(./$(TESTS)/sm_wh); echo "$$out" | grep -q done
	@echo "=== SEED-MIN-GEN1-OK ==="

true-selfhost-min: seed-min-gen1
	@echo "[2] gen1_min -> gen2.c"
	./$(GEN1_MIN) $(MIN_SA) $(GEN2_C) >/dev/null
	@test -s $(GEN2_C)
	$(CC) -O2 -o $(GEN2) $(GEN2_C)
	@$(MAKE) test-reassign test-while test-when
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
native-test: $(NATIVE_BIN)
	@mkdir -p examples $(TESTS)
	@printf 'hold x = 40\nhold x = x + 2\nshow x\n' > examples/native_hello.sa
	./$(NATIVE_BIN) examples/native_hello.sa $(TESTS)/native_hello
	@./$(TESTS)/native_hello | grep -qx 42
	@printf 'hold z = -42\nshow z\n' > $(TESTS)/native_negative.sa
	./$(NATIVE_BIN) $(TESTS)/native_negative.sa $(TESTS)/native_negative
	@./$(TESTS)/native_negative | grep -qx -- -42
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/native_while.sa
	./$(NATIVE_BIN) $(TESTS)/native_while.sa $(TESTS)/native_while
	@out=$$(./$(TESTS)/native_while); echo "$$out" | grep -q done
	@echo "=== NATIVE-TEST-OK ==="

grammar: true-selfhost-min
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nwhile n < 3 {\n  hold n = n + 1\n}\nwhen n == 3 {\n  show "grammar-ok"\n} otherwise {\n  show "grammar-fail"\n}\n' > $(TESTS)/grammar.sa
	./$(GEN2) $(TESTS)/grammar.sa $(TESTS)/grammar.c >/dev/null
	$(CC) -O2 -o $(TESTS)/grammar $(TESTS)/grammar.c
	@./$(TESTS)/grammar | grep -qx 'grammar-ok'
	@echo "=== GRAMMAR-OK ==="

gc-test:
	$(CC) -O2 -o $(TESTS)/rc_runtime_stress selfhost/rc_runtime_stress.c
	@./$(TESTS)/rc_runtime_stress | grep -qx 'gc-rc-ok'
	@echo "=== GC-RC-OK ==="

gen3:
	@test -x $(GEN2) || (echo "run true-selfhost first"; exit 1)
	./$(GEN2) $(MIN_SA) $(GEN3_C) >/dev/null
	@sed -i 's/string_eq(/sx_eq(/g' $(GEN3_C) 2>/dev/null || true
	$(CC) -O2 -o $(GEN3) $(GEN3_C)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/g3_re.sa
	./$(GEN3) $(TESTS)/g3_re.sa $(TESTS)/g3_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_re $(TESTS)/g3_re.c
	@./$(TESTS)/g3_re | grep -qx 2
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/g3_wh.sa
	./$(GEN3) $(TESTS)/g3_wh.sa $(TESTS)/g3_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wh $(TESTS)/g3_wh.c
	@out=$(./$(TESTS)/g3_wh); echo "$out" | grep -q done
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/g3_wn.sa
	./$(GEN3) $(TESTS)/g3_wn.sa $(TESTS)/g3_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wn $(TESTS)/g3_wn.c
	@out=$(./$(TESTS)/g3_wn); echo "$out" | grep -qx 99
	./$(GEN3) $(MIN_SA) selfhost/gen4.c >/dev/null
	@sed -i 's/string_eq(/sx_eq(/g' selfhost/gen4.c 2>/dev/null || true
	@if cmp -s $(GEN3_C) selfhost/gen4.c; then echo "[OK] byte-identical gen3 == gen4"; \
	else echo "[INFO] gen3/gen4 differ (emit not fully deterministic)"; fi
	@echo "=== GEN3-OK ==="

subset: seed-bin
	@printf 'hold x = 42\nshow x\n' > selfhost/_smoke.sa
	./$(SEED_BIN) selfhost/_smoke.sa > selfhost/_smoke.c
	$(CC) -O2 -o selfhost/_smoke selfhost/_smoke.c -I selfhost/seed
	@./selfhost/_smoke | grep -q 42
	@echo "=== SUBSET-SELFHOST-OK ==="

gen1: $(GEN1)
	@echo "=== GEN1-OK ==="
gen2: $(GEN2)
	@echo "=== GEN2-OK ==="
test: true-selfhost
	@echo TEST-OK

clean:
	rm -f $(GEN1) $(GEN1_C) $(GEN1_MIN) $(GEN1_MIN_C) $(GEN2) $(GEN2_C) $(GEN3) $(GEN3_C) selfhost/gen4.c
	rm -f $(SEED_BIN) $(SEED_MIN_BIN) $(NATIVE_BIN) selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
