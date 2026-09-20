.PHONY: all selfhost-full selfhost-min selfhost test clean

all: selfhost-min

selfhost-full:
	@if [ -d selfhost/sxc_full_b64 ]; then cat selfhost/sxc_full_b64/b*.txt | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc_full.c; fi
	clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
	./selfhost/sxc_full selfhost/mini_in2.sa selfhost/ref_out.c
	clang -O2 -o selfhost/ref_run selfhost/ref_out.c
	./selfhost/ref_run | grep -q 42
	@echo SELFHOST-FULL-OK

selfhost-min: selfhost-full
	@if [ -d selfhost/compiler_min_b64 ]; then cat selfhost/compiler_min_b64/b*.txt | tr -d '\n' | base64 -d | gzip -d > selfhost/compiler_min.sa; fi
	./selfhost/sxc_full selfhost/compiler_min.sa selfhost/compiler_min_out.c
	clang -O2 -o selfhost/compiler_min selfhost/compiler_min_out.c
	./selfhost/compiler_min selfhost/mini_in2.sa selfhost/mini_out2.c
	clang -O2 -o selfhost/mini_run2 selfhost/mini_out2.c
	./selfhost/mini_run2 | grep -q 42
	./selfhost/compiler_min selfhost/mini_field.sa selfhost/mini_out_field.c
	clang -O2 -o selfhost/mini_run_field selfhost/mini_out_field.c
	./selfhost/mini_run_field | grep -q 3
	@echo SELFHOST-MIN-OK

selfhost: selfhost-min
test: selfhost-min
	@echo TEST-OK

clean:
	rm -f selfhost/sxc_full selfhost/compiler_min selfhost/mini_run* selfhost/ref_run selfhost/*_out*.c
