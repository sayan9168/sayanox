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
        test-reassign test-while test-when test-mod test-struct2 test-list2 test-use \
        test-boot test-fn test-fn2 test-list test-struct test-parity test-chain test-condmod test-user test-nest \
        pack-compiler

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

pack-compiler:
	@# Regenerate selfhost/compiler_min_gz/*.b64 from selfhost/compiler_min.sa
	./selfhost/pack_compiler_min.sh

restore-compiler:
	@# Pure offline: decode selfhost/compiler_min_gz/*.b64 (gzip+base64). No Python.
	@test -f selfhost/compiler_min_gz/00.b64 || \
	  (echo "FAIL: missing selfhost/compiler_min_gz/00.b64"; exit 1)
	@cat selfhost/compiler_min_gz/*.b64 | tr -d '\n' | base64 -d | gzip -d > $(MIN_SA)
	@test -s $(MIN_SA)
	@grep -q 'read_file' $(MIN_SA)
	@grep -q 'arg_count' $(MIN_SA)
	@grep -q 'sx_eq' $(MIN_SA) || (echo "FAIL: compiler_min missing sx_eq"; exit 1)
	@echo "[OK] restore-compiler ($$(wc -c < $(MIN_SA)) bytes, offline, no Python)"

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

test-mod:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/ts_mod.sa
	./$(GEN2) $(TESTS)/ts_mod.sa $(TESTS)/ts_mod.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_mod $(TESTS)/ts_mod.c
	@grep -q '(double)((long)(a)%(long)(3))' $(TESTS)/ts_mod.c
	@grep -q '} else {' $(TESTS)/ts_mod.c
	@out=$$(./$(TESTS)/ts_mod); test "$$(echo "$$out" | wc -l)" = "2"; \
	 echo "$$out" | sed -n 1p | grep -qx 1; echo "$$out" | sed -n 2p | grep -qx 1
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
	 diff $(TESTS)/ts_user_sm.out $(TESTS)/ts_user_g2.out
	@out=$$(./$(TESTS)/ts_user_g2); \
	 test "$$(echo "$$out" | sed -n 1p)" = "Ada"; test "$$(echo "$$out" | sed -n 2p)" = "36"; \
	 test "$$(echo "$$out" | sed -n 4p)" = "Ada!"; test "$$(echo "$$out" | sed -n 5p)" = "37"; \
	 test "$$(echo "$$out" | sed -n 6p)" = "Bob"; test "$$(echo "$$out" | sed -n 7p)" = "3"
	@printf 'struct User {\n  name,\n  age\n}\nhold a = User { name: "Ada", age: 36 }\nhold b = User { name: 1, age: 2 }\n' > $(TESTS)/ts_userbad.sa
	@./$(GEN2) $(TESTS)/ts_userbad.sa $(TESTS)/ts_userbad.c >/dev/null; grep -q '#error' $(TESTS)/ts_userbad.c
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_userbad.sa > /dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a struct field type mismatch"; exit 1; fi
	@printf 'struct User {\n  name,\n  age\n}\nhold u = User { age: 1, name: "Ada" }\n' > $(TESTS)/ts_order.sa
	@./$(GEN2) $(TESTS)/ts_order.sa $(TESTS)/ts_order.c >/dev/null; grep -q '#error' $(TESTS)/ts_order.c
	@printf 'struct User {\n  name,\n  age\n}\nhold u = User { age: 36, name: "Ada" }\nshow u.name\nshow u.age\n' > $(TESTS)/ts_part.sa
	./$(SEED_MIN_BIN) $(TESTS)/ts_part.sa > $(TESTS)/ts_part_sm.c
	$(CC) -O2 -o $(TESTS)/ts_part_sm $(TESTS)/ts_part_sm.c
	@out=$$(./$(TESTS)/ts_part_sm); test "$$(echo "$$out" | sed -n 1p)" = "Ada"; test "$$(echo "$$out" | sed -n 2p)" = "36"
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
	 diff $(TESTS)/ts_chain_sm.out $(TESTS)/ts_chain_g2.out
	@test "$$(sed -n 1p $(TESTS)/ts_chain_g2.out)" = "ab"
	@test "$$(sed -n 2p $(TESTS)/ts_chain_g2.out)" = "ab!"
	@test "$$(sed -n 3p $(TESTS)/ts_chain_g2.out)" = "6"
	@test "$$(sed -n 4p $(TESTS)/ts_chain_g2.out)" = "5"
	@test "$$(sed -n 5p $(TESTS)/ts_chain_g2.out)" = "7"
	@test "$$(sed -n 6p $(TESTS)/ts_chain_g2.out)" = "5"
	@test "$$(sed -n 7p $(TESTS)/ts_chain_g2.out)" = "3"
	@test "$$(sed -n 8p $(TESTS)/ts_chain_g2.out)" = "7"
	@echo "[OK] gen2 chained + - * / % (and string + name) agree with seed-min"

test-condmod:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold a = 17\nwhile a %% 10 > 0 {\n  show a %% 10\n  hold a = a - 3\n}\nwhen 10 %% 3 == 1 {\n  show "mod-ok"\n}\n' > $(TESTS)/ts_cm.sa
	./$(GEN2) $(TESTS)/ts_cm.sa $(TESTS)/ts_cm.c >/dev/null
	@grep -q '(double)((long)(a' $(TESTS)/ts_cm.c
	@grep -q '%(long)(10)' $(TESTS)/ts_cm.c
	$(CC) -O2 -o $(TESTS)/ts_cm $(TESTS)/ts_cm.c
	@out=$$(./$(TESTS)/ts_cm); test "$$(echo "$$out" | sed -n 1p)" = "7"; \
	 test "$$(echo "$$out" | sed -n 4p)" = "8"; test "$$(echo "$$out" | sed -n 7p)" = "mod-ok"
	@echo "[OK] gen2 while/when condition % long-cast rewrite"

test-struct2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'struct Point {\n  x,\n  y\n}\nstruct Pair {\n  a,\n  b\n}\nhold p = Point { x: 3, y: 4 }\nshow p.x\nshow p.y\nshow p.x + p.y\nhold q = Pair { a: 5, b: 6 }\nshow q.a + q.b\n' > $(TESTS)/ts_st2.sa
	./$(GEN2) $(TESTS)/ts_st2.sa $(TESTS)/ts_st2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_st2 $(TESTS)/ts_st2.c
	@out=$$(./$(TESTS)/ts_st2); \
	 test "$$(echo "$$out" | sed -n 1p)" = "3"; test "$$(echo "$$out" | sed -n 2p)" = "4"; \
	 test "$$(echo "$$out" | sed -n 3p)" = "7"; test "$$(echo "$$out" | sed -n 4p)" = "11"
	@echo "[OK] gen2 structs: named fields, two structs, field expr"

test-list2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'hold xs = [10, 20, 30]\nshow xs[0]\nshow len(xs)\nhold xs = push(xs, 40)\nshow len(xs)\nshow xs[3]\n' > $(TESTS)/ts_li2.sa
	./$(GEN2) $(TESTS)/ts_li2.sa $(TESTS)/ts_li2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li2 $(TESTS)/ts_li2.c
	@out=$$(./$(TESTS)/ts_li2); \
	 test "$$(echo "$$out" | sed -n 1p)" = "10"; test "$$(echo "$$out" | sed -n 2p)" = "3"; \
	 test "$$(echo "$$out" | sed -n 3p)" = "4"; test "$$(echo "$$out" | sed -n 4p)" = "40"
	@printf 'hold xs = [5, 6]\nshow xs[1] + 1\nshow len(xs)\n' > $(TESTS)/ts_li3.sa
	./$(GEN2) $(TESTS)/ts_li3.sa $(TESTS)/ts_li3.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li3 $(TESTS)/ts_li3.c
	@out=$$(./$(TESTS)/ts_li3); test "$$(echo "$$out" | sed -n 1p)" = "7"; test "$$(echo "$$out" | sed -n 2p)" = "2"
	@printf 'hold xs = [5, 6]\nshow len(xs) + 1\nshow 10 %% 3\nhold y = 10 + 2\nshow y\n' > $(TESTS)/ts_li4.sa
	./$(GEN2) $(TESTS)/ts_li4.sa $(TESTS)/ts_li4.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_li4 $(TESTS)/ts_li4.c
	@out=$$(./$(TESTS)/ts_li4); \
	 test "$$(echo "$$out" | sed -n 1p)" = "3"; test "$$(echo "$$out" | sed -n 2p)" = "1"; \
	 test "$$(echo "$$out" | sed -n 3p)" = "12"
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
	@./$(TESTS)/ts_use | grep -qx 99
	@printf 'use "selfhost/seed_tests/ts_other.sa"\nhold y = 1\n' > $(TESTS)/ts_mid.sa
	@printf 'use "selfhost/seed_tests/ts_mid.sa"\nshow z\nshow y\n' > $(TESTS)/ts_top.sa
	./$(GEN2) $(TESTS)/ts_top.sa $(TESTS)/ts_top.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_top $(TESTS)/ts_top.c
	@out=$$(./$(TESTS)/ts_top); test "$$(echo "$$out" | sed -n 1p)" = "99"; test "$$(echo "$$out" | sed -n 2p)" = "1"
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
	./$(SEED_MIN_BIN) $(TESTS)/ts_nest.sa > $(TESTS)/ts_nest_sm.c
	$(CC) -O2 -o $(TESTS)/ts_nest_sm $(TESTS)/ts_nest_sm.c
	@grep -q 'typedef struct { char \*name; double x; } Point;' $(TESTS)/ts_nest_sm.c
	@grep -q 'typedef struct { Point a; Point b; } Line;' $(TESTS)/ts_nest_sm.c
	@out=$$(./$(TESTS)/ts_nest_sm); \
	 test "$$(echo "$$out" | sed -n 1p)" = "p1"; test "$$(echo "$$out" | sed -n 2p)" = "1"; \
	 test "$$(echo "$$out" | sed -n 3p)" = "p2"; test "$$(echo "$$out" | sed -n 4p)" = "2"; \
	 test "$$(echo "$$out" | sed -n 5p)" = "p2"; test "$$(echo "$$out" | sed -n 6p)" = "2"
	@# the self-hosted compiler does not support nested literals yet: it must
	@# say so plainly and emit #error, never silently wrong code
	@./$(GEN2) $(TESTS)/ts_nest.sa $(TESTS)/ts_nest_g2.c >/dev/null
	@grep -q 'nested struct literal values are not supported' $(TESTS)/ts_nest_g2.c
	@# a nested struct must be declared before the struct that nests it
	@printf 'struct Line {\n  a\n}\nstruct Point {\n  x\n}\nhold l = Line { a: Point { 1 } }\n' > $(TESTS)/ts_nestfwd.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestfwd.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a nested struct declared later"; exit 1; fi
	@# a list still cannot be a struct field
	@printf 'struct Point {\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: [1], b: Point { 2 } }\n' > $(TESTS)/ts_nestlist.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestlist.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a list in a struct field"; exit 1; fi
	@# chaining through a field with no struct type is a clear error, not bad C
	@printf 'struct Point {\n  x\n}\nstruct Line {\n  a,\n  b\n}\nhold l = Line { a: Point { 1 } }\nshow l.b.x\n' > $(TESTS)/ts_nestmiss.sa
	@if ./$(SEED_MIN_BIN) $(TESTS)/ts_nestmiss.sa >/dev/null 2>&1; then \
	  echo "[FAIL] seed-min accepted a chain through an untyped struct field"; exit 1; fi
	@echo "[OK] nested structs in seed-min (typed fields, ordered typedefs, .a.x chains); gen2 rejects them explicitly"

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
	 diff $(TESTS)/par_sm.out $(TESTS)/par_g2.out && echo "[OK] seed-min and gen2 agree on the shared dialect"
	@echo "=== TEST-PARITY-OK ==="

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
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/min_mod.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_mod.sa > $(TESTS)/min_mod.c
	$(CC) -O2 -o $(TESTS)/min_mod $(TESTS)/min_mod.c
	@grep -q '(double)((long)(a)%(long)(3))' $(TESTS)/min_mod.c
	@out=$$(./$(TESTS)/min_mod); echo "$$out" | sed -n 1p | grep -qx 1; echo "$$out" | sed -n 2p | grep -qx 1
	@printf 'hold z = 99\n' > $(TESTS)/min_other.sa
	@printf 'use "selfhost/seed_tests/min_other.sa"\nshow z\n' > $(TESTS)/min_use.sa
	./$(SEED_MIN_BIN) $(TESTS)/min_use.sa > $(TESTS)/min_use.c
	$(CC) -O2 -o $(TESTS)/min_use $(TESTS)/min_use.c
	@./$(TESTS)/min_use | grep -qx 99
	@printf 'use "selfhost/seed_tests/min_missing.sa"\nshow 1\n' > $(TESTS)/min_miss.sa
	@! ./$(SEED_MIN_BIN) $(TESTS)/min_miss.sa > /dev/null 2>&1
	@echo "=== SEED-MIN-OK ==="

test-struct: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'struct Point {\n  x,\n  y\n}\nhold p = Point { 3, 4 }\nshow p.x\nshow p.y\nshow p.x + p.y\n' > $(TESTS)/struct.sa
	./$(SEED_MIN_BIN) $(TESTS)/struct.sa > $(TESTS)/struct.c
	$(CC) -O2 -o $(TESTS)/struct $(TESTS)/struct.c
	@out=$$(./$(TESTS)/struct); echo "$$out" | grep -qx 3; echo "$$out" | grep -q 7
	@echo "[OK] seed-min structs"
	@echo "=== TEST-STRUCT-OK ==="

test-list: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'hold xs = [10, 20, 30]\nshow xs[0]\nshow xs[1]\nshow xs[2]\nhold n = len(xs)\nshow n\nhold xs = push(xs, 40)\nshow xs[3]\nshow len(xs)\n' > $(TESTS)/list.sa
	./$(SEED_MIN_BIN) $(TESTS)/list.sa > $(TESTS)/list.c
	$(CC) -O2 -o $(TESTS)/list $(TESTS)/list.c
	@out=$$(./$(TESTS)/list); echo "$$out" | grep -qx 10; echo "$$out" | grep -q 40; echo "$$out" | grep -q 4
	@echo "[OK] seed-min lists"
	@echo "=== TEST-LIST-OK ==="

test-fn: $(SEED_MIN_BIN)
	@mkdir -p $(TESTS)
	@printf 'make add(a, b) {\n  give a + b\n}\nmake square(x) {\n  give x * x\n}\nhold r = add(40, 2)\nshow r\nhold s = square(5)\nshow s\n' > $(TESTS)/fn.sa
	./$(SEED_MIN_BIN) $(TESTS)/fn.sa > $(TESTS)/fn.c
	$(CC) -O2 -o $(TESTS)/fn $(TESTS)/fn.c
	@out=$$(./$(TESTS)/fn); echo "$$out" | grep -qx 42; echo "$$out" | grep -q 25
	@echo "[OK] seed-min make/give"
	@echo "=== TEST-FN-OK ==="

test-fn2:
	@test -x $(GEN2) || (echo "need gen2"; exit 1)
	@mkdir -p $(TESTS)
	@printf 'make add(a, b) {\n  give a + b\n}\nmake fac(n) {\n  when n <= 1 {\n    give 1\n  }\n  give n * fac(n - 1)\n}\nhold r = add(40, 2)\nshow r\nshow fac(5)\nshow add(r, 1)\n' > $(TESTS)/ts_fn2.sa
	./$(GEN2) $(TESTS)/ts_fn2.sa $(TESTS)/ts_fn2.c >/dev/null
	$(CC) -O2 -o $(TESTS)/ts_fn2 $(TESTS)/ts_fn2.c
	@out=$$(./$(TESTS)/ts_fn2); \
	 test "$$(echo "$$out" | sed -n 1p)" = "42"; test "$$(echo "$$out" | sed -n 2p)" = "120"; \
	 test "$$(echo "$$out" | sed -n 3p)" = "43"
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
	@out=$$(./$(TESTS)/sm_wh); echo "$$out" | grep -q done
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
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/native_mod.sa
	./$(NATIVE_BIN) $(TESTS)/native_mod.sa $(TESTS)/native_mod
	@out=$$(./$(TESTS)/native_mod); test "$$(echo "$$out" | sed -n 1p)" = "1"; test "$$(echo "$$out" | sed -n 2p)" = "1"
	@printf 'hold xs = [1, 2, 3]\nshow xs[0]\n' > $(TESTS)/native_unsup.sa
	@if ./$(NATIVE_BIN) $(TESTS)/native_unsup.sa $(TESTS)/native_unsup 2>/dev/null; then \
	  echo "[FAIL] native accepted lists (silently wrong code)"; exit 1; fi
	@./$(NATIVE_BIN) $(TESTS)/native_unsup.sa $(TESTS)/native_unsup 2>&1 | grep -q 'unsupported'
	@echo "[OK] native: modulo, else alias, unsupported constructs rejected"
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
	@test -s $(GEN3_C)
	$(CC) -O2 -o $(GEN3) $(GEN3_C)
	@mkdir -p $(TESTS)
	@printf 'hold n = 0\nhold n = 1\nhold n = 2\nshow n\n' > $(TESTS)/g3_re.sa
	./$(GEN3) $(TESTS)/g3_re.sa $(TESTS)/g3_re.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_re $(TESTS)/g3_re.c
	@./$(TESTS)/g3_re | grep -qx 2
	@printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > $(TESTS)/g3_wh.sa
	./$(GEN3) $(TESTS)/g3_wh.sa $(TESTS)/g3_wh.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wh $(TESTS)/g3_wh.c
	@out=$$(./$(TESTS)/g3_wh); echo "$$out" | grep -q done
	@printf 'hold x = 2\nwhen x == 1 {\n  show 11\n}\nshow 99\n' > $(TESTS)/g3_wn.sa
	./$(GEN3) $(TESTS)/g3_wn.sa $(TESTS)/g3_wn.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_wn $(TESTS)/g3_wn.c
	@out=$$(./$(TESTS)/g3_wn); echo "$$out" | grep -q 99
	@printf 'hold a = 10\nshow a %% 3\nwhen a > 5 { show 1 } else { show 0 }\n' > $(TESTS)/g3_mod.sa
	./$(GEN3) $(TESTS)/g3_mod.sa $(TESTS)/g3_mod.c >/dev/null
	$(CC) -O2 -o $(TESTS)/g3_mod $(TESTS)/g3_mod.c
	@out=$$(./$(TESTS)/g3_mod); test "$$(echo "$$out" | wc -l)" = "2"; \
	 echo "$$out" | sed -n 1p | grep -qx 1; echo "$$out" | sed -n 2p | grep -qx 1
	@echo "[OK] gen3 modulo + else"
	./$(GEN3) $(MIN_SA) selfhost/gen4.c >/dev/null
	@if cmp -s $(GEN3_C) selfhost/gen4.c; then echo "[OK] byte-identical gen3 == gen4"; \
	else echo "[FAIL] gen3/gen4 differ"; exit 1; fi
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
