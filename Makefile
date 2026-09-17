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
	sed 's/d6h0tAJKGM/d6h4tAJKGM/g' selfhost/native_src/p02.gz.b64 > /tmp/p02_fix.b64
	base64 -d selfhost/native_src/p00.gz.b64 | gzip -d > selfhost/native_aot.c
	base64 -d selfhost/native_src/p01.gz.b64 | gzip -d >> selfhost/native_aot.c
	base64 -d /tmp/p02_fix.b64 | gzip -d >> selfhost/native_aot.c
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

bootstrap-native: native
	./selfhost/native_aot examples/native_hello.sa /tmp/nh && /tmp/nh | grep -q 42
	./selfhost/native_aot examples/native_arith.sa /tmp/na && /tmp/na | grep -q 42
	./selfhost/native_aot examples/native_while.sa /tmp/nw
	./selfhost/native_aot examples/native_list.sa /tmp/nl
	./selfhost/native_aot examples/native_struct.sa /tmp/ns
	@echo NATIVE-ONLY OK

bootstrap-production: stage2
	./selfhost/stage2 selfhost/bootstrap_production.sa selfhost/bootstrap_production_cli.c
	clang -O2 -o selfhost/bootstrap_production_bin selfhost/bootstrap_production_cli.c
	./selfhost/bootstrap_production_bin

tools: stage2
	./selfhost/stage2 tools/sxfmt.sa tools/sxfmt_cli.c
	clang -O2 -o tools/sxfmt_bin tools/sxfmt_cli.c
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/native_aot tools/sxfmt_bin selfhost/bootstrap_production_bin
