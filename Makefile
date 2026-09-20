.PHONY: all selfhost-full selfhost-min selfhost-fast selfhost test clean

all: selfhost-min

selfhost-full:
	cat selfhost/sxc_full_lines/L*.txt > selfhost/sxc_full.c
	clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
	./selfhost/sxc_full selfhost/sxc_test_in.sa selfhost/sxc_emit.c
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 42
	@echo SELFHOST-FULL-OK

selfhost-min: selfhost-full
	./selfhost/sxc_full selfhost/compiler_min.sa selfhost/compiler_min_out.c
	clang -O2 -o selfhost/compiler_min selfhost/compiler_min_out.c
	./selfhost/compiler_min selfhost/mini_in.sa selfhost/mini_out.c
	clang -O2 -o selfhost/mini_run selfhost/mini_out.c
	./selfhost/mini_run | grep -q 42
	@echo SELFHOST-MIN-OK

selfhost-fast: selfhost-min
selfhost: selfhost-min
test: selfhost-min
	@echo TEST-OK

clean:
	rm -f selfhost/sxc_full selfhost/sxc_run selfhost/compiler_min selfhost/mini_run selfhost/*_out.c selfhost/sxc_emit.c
