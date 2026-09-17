.PHONY: all stage2 sx native test clean

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

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/native_aot
