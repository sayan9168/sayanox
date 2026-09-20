.PHONY: all selfhost-full selfhost-min selfhost test clean

all: selfhost-min

selfhost-full:
	cp selfhost/sxc_full.c.txt selfhost/sxc_full.c 2>/dev/null || true
	clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
	./selfhost/sxc_full selfhost/sxc_test_in.sa selfhost/sxc_emit.c
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 42
	./selfhost/sxc_full selfhost/mini_in2.sa selfhost/mini_out2.c
	clang -O2 -o selfhost/mini_run2 selfhost/mini_out2.c
	./selfhost/mini_run2 | grep -q 42
	@echo SELFHOST-FULL-OK

selfhost-min: selfhost-full
	./selfhost/sxc_full selfhost/compiler_min.sa selfhost/compiler_min_out.c
	clang -O2 -o selfhost/compiler_min selfhost/compiler_min_out.c
	./selfhost/compiler_min selfhost/mini_in.sa selfhost/mini_out.c
	clang -O2 -o selfhost/mini_run selfhost/mini_out.c
	./selfhost/mini_run | grep -q 42
	@echo SELFHOST-MIN-OK

selfhost: selfhost-min
test: selfhost-min
	@echo TEST-OK

clean:
	rm -f selfhost/sxc_full selfhost/sxc_run selfhost/compiler_min selfhost/mini_run*
