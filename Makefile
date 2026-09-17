.PHONY: all stage2 sx native test bootstrap-native bootstrap-production tools clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

native:
	cat selfhost/native_src/c*.part > selfhost/native_aot.c
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

bootstrap-native: native
	./selfhost/native_aot examples/native_hello.sa /tmp/nh && /tmp/nh | grep -q 42
	./selfhost/native_aot examples/mod_use.sa /tmp/mu && /tmp/mu | grep -q 99
	@echo NATIVE-ONLY OK

bootstrap-production: stage2
	./selfhost/stage2 selfhost/bootstrap_production.sa selfhost/bootstrap_production_cli.c
	clang -O2 -o selfhost/bootstrap_production_bin selfhost/bootstrap_production_cli.c
	./selfhost/bootstrap_production_bin

tools: stage2
	./selfhost/stage2 tools/sxfmt.sa tools/sxfmt_cli.c
	clang -O2 -o tools/sxfmt_bin tools/sxfmt_cli.c

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/native_aot tools/sxfmt_bin
