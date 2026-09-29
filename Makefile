.PHONY: all test subset seed gen1 gen2 grammar pure-gen2 native native-test gc-test clean

# The bootstrap chain: subset (seed smoke) -> seed -> gen1 -> gen2 (pure)
all: subset seed gen1 gen2

subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

seed:
	chmod +x selfhost/bootstrap_seed.sh
	./selfhost/bootstrap_seed.sh

# gen1: the C seed compiles selfhost/compiler_min.sa into selfhost/gen1.c
gen1:
	chmod +x selfhost/bootstrap_gen1.sh
	./selfhost/bootstrap_gen1.sh

# gen2: gen1 compiles selfhost/compiler_boot.sa into a pure compiler (boot),
# which compiles pure-min programs, and boot.c == boot2.c (fixed point).
# Nothing is copied; see docs/STATUS.md ("GEN2-PARTIAL") for the exact limits.
gen2:
	chmod +x selfhost/bootstrap_gen2.sh
	./selfhost/bootstrap_gen2.sh

# kept for compatibility: pure-gen2 is the same target as gen2
pure-gen2: gen2

grammar: gen1
	chmod +x selfhost/bootstrap_grammar.sh
	./selfhost/bootstrap_grammar.sh

test: subset seed gen1 gen2 grammar
	@echo TEST-OK

native:
	@if [ -f selfhost/native_aot.c ]; then clang -O2 -o selfhost/native_aot selfhost/native_aot.c; fi

native-test: native
	@if [ -x selfhost/native_aot ] && [ -f examples/native_hello.sa ]; then \
	  ./selfhost/native_aot examples/native_hello.sa selfhost/_nt && ./selfhost/_nt | grep -qx 42; \
	else echo "native skip"; fi

gc-test:
	@if [ -f selfhost/rc_runtime_stress.c ]; then \
	  cc -std=c11 -O2 -o selfhost/_rc selfhost/rc_runtime_stress.c && ./selfhost/_rc | grep -q gc-rc-ok; \
	else echo "rc skip"; fi

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen1.c selfhost/gen2 selfhost/gen2.c
	rm -f selfhost/boot selfhost/boot.c selfhost/boot2 selfhost/boot2.c
	rm -f selfhost/_run selfhost/_out.c selfhost/_smoke selfhost/_smoke.c selfhost/_smoke.sa
	rm -rf selfhost/seed_tests selfhost/gen2_tests
	rm -f selfhost/seed/sxc_seed
