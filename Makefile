.PHONY: all stage2 sx native test bootstrap-native clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

native:
	cat selfhost/native_src/g[0-9][0-9].b64 | tr -d '\n' | base64 -d | gunzip > selfhost/native_aot.c
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

bootstrap-native: native
	./selfhost/native_aot examples/hello.sa /tmp/nh
	/tmp/nh | grep -q 42
	./selfhost/native_aot examples/runtime_concat.sa /tmp/nc
	/tmp/nc | grep -q "hello world"
	@echo NATIVE-ONLY OK

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/native_aot
