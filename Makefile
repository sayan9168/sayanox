.PHONY: all test complete subset subset-existing stage2 sx tools bootstrap-production native native-test bootstrap-native gc-test clean

all: subset

stage2:
	@if [ ! -x selfhost/stage2 ]; then clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c; ./selfhost/build_stage2; fi
	@test -x selfhost/stage2

sx:
	chmod +x selfhost/sx

subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

subset-existing:
	if [ ! -x selfhost/gen1 ]; then echo "error: selfhost/gen1 is required; bootstrap it once first" >&2; exit 1; fi
	./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
	clang -O2 -o selfhost/_run selfhost/_out.c
	./selfhost/_run | grep -q 42

complete: subset

test: subset
	@echo TEST-OK

tools: subset
	mkdir -p tools
	./selfhost/gen1 tools/sxfmt.sa tools/sxfmt.c
	clang -O2 -o tools/sxfmt_bin tools/sxfmt.c

bootstrap-production: stage2
	./selfhost/stage2 selfhost/bootstrap_production.sa selfhost/bootstrap_production.c
	clang -O2 -o selfhost/bootstrap_production selfhost/bootstrap_production.c
	./selfhost/bootstrap_production >/dev/null

native:
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

native-test: native
	./selfhost/native_aot examples/native_hello.sa selfhost/_native_test
	./selfhost/_native_test | grep -qx '42'
	rm -f selfhost/_native_test

gc-test:
	@if [ -f selfhost/rc_runtime_stress.c ]; then \
	  cc -std=c11 -O2 -Wall -Wextra -o selfhost/_rc_test selfhost/rc_runtime_stress.c; \
	  ./selfhost/_rc_test | tee selfhost/_gc.out; \
	  grep -qx '2005' selfhost/_gc.out; \
	  grep -qx 'gc-rc-ok' selfhost/_gc.out; \
	  rm -f selfhost/_rc_test selfhost/_gc.out; \
	else \
	  $(MAKE) stage2; \
	  ./selfhost/stage2 examples/gc_rc_loop.sa selfhost/_gc.c; \
	  clang -O2 -o selfhost/_gc selfhost/_gc.c; \
	  ./selfhost/_gc > selfhost/_gc.out; \
	  grep -qx '2005' selfhost/_gc.out; \
	  grep -qx 'gc-rc-ok' selfhost/_gc.out; \
	  rm -f selfhost/_gc selfhost/_gc.c selfhost/_gc.out; \
	fi

bootstrap-native: native
	./selfhost/native_aot examples/hello.sa selfhost/native_hello

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen1.c selfhost/gen2 selfhost/gen2.c
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/_run selfhost/_out.c selfhost/out2.c
	rm -f selfhost/_field selfhost/_field.c selfhost/_builtin selfhost/_builtin.c
	rm -f selfhost/_index selfhost/_index.c selfhost/_in3 selfhost/_in3.c
	rm -f tools/sxfmt_bin tools/sxfmt.c
