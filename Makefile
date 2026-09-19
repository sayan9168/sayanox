.PHONY: all stage2 sx native test bootstrap-native selfhost clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2
	clang -O2 -o selfhost/inject_chr selfhost/inject_chr.c
	./selfhost/inject_chr
	clang -O2 -o selfhost/stage2 selfhost/stage2_template.c

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

native:
	@if ls selfhost/native_src/p00.c.part >/dev/null 2>&1; then \
	  cat selfhost/native_src/p[0-9][0-9].c.part > selfhost/native_aot.c; \
	else \
	  cat selfhost/native_src/g[0-9][0-9].b64 | tr -d '\n' | base64 -d | gunzip > selfhost/native_aot.c; \
	fi
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

bootstrap-native: native
	./selfhost/native_aot examples/hello.sa /tmp/nh
	/tmp/nh | grep -q 42
	@echo NATIVE-ONLY OK

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

selfhost: stage2
	./selfhost/stage2 selfhost/sxc.sa selfhost/sxc_out.c
	clang -O2 -pthread -o selfhost/sxc selfhost/sxc_out.c
	./selfhost/sxc
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 10
	./selfhost/sxc_run | grep -q 32
	@echo SELFHOST-OK

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx \
	  selfhost/native_aot selfhost/sxc selfhost/sxc_run selfhost/inject_chr
