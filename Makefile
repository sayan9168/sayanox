.PHONY: all test subset pure-gen2 seed native native-test gc-test clean

all: subset seed

subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

seed:
	chmod +x selfhost/bootstrap_seed.sh
	./selfhost/bootstrap_seed.sh

pure-gen2: subset
	@if [ -f selfhost/bootstrap_pure_gen2.sh ]; then \
	  chmod +x selfhost/bootstrap_pure_gen2.sh; \
	  ./selfhost/bootstrap_pure_gen2.sh || echo "pure-gen2 soft-fail"; \
	else echo "skip pure-gen2"; fi

test: subset seed
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
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen2 selfhost/_run selfhost/_out.c
	rm -rf selfhost/seed_tests
	rm -f selfhost/seed/sxc_seed
