.PHONY: all test complete subset subset-existing stage2 sx tools bootstrap-production native bootstrap-native clean

all: subset

stage2:
	@if [ ! -x selfhost/stage2 ]; then clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c; ./selfhost/build_stage2; fi

sx:
	chmod +x selfhost/sx

# Prefer an existing Sayanox compiler. If none exists, bootstrap gen1 once.
subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

# Require an already-built gen1. This is the normal development path.
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

bootstrap-native: native
	./selfhost/native_aot examples/hello.sa selfhost/native_hello

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen1.c selfhost/gen2 selfhost/gen2.c
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/_run selfhost/_out.c selfhost/out2.c
	rm -f selfhost/_field selfhost/_field.c selfhost/_builtin selfhost/_builtin.c
	rm -f selfhost/_index selfhost/_index.c selfhost/_in3 selfhost/_in3.c
	rm -f tools/sxfmt_bin tools/sxfmt.c
