.PHONY: all stage2 sx native test bootstrap-native selfhost selfhost-fn clean

all: stage2 sx

stage2:
	@if [ ! -f selfhost/stage2_template.c ] || [ $$(wc -c < selfhost/stage2_template.c) -lt 1000 ]; then \
	  curl -fsSL "https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c" -o selfhost/stage2_template.c; \
	fi
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2 || true
	@if [ -f selfhost/inject_chr.c ]; then clang -O2 -o selfhost/inject_chr selfhost/inject_chr.c && ./selfhost/inject_chr; fi
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
	@if [ -f selfhost/sxc.sa.b64 ]; then cat selfhost/sxc.sa.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc.sa; fi
	./selfhost/stage2 selfhost/sxc.sa selfhost/sxc_out.c
	clang -O2 -pthread -o selfhost/sxc selfhost/sxc_out.c
	./selfhost/sxc
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 0
	./selfhost/sxc_run | grep -q 99
	@echo SELFHOST-OK

selfhost-fn: stage2
	@if [ -f selfhost/sxc_fn.sa.b64 ]; then cat selfhost/sxc_fn.sa.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc_fn.sa; fi
	./selfhost/stage2 selfhost/sxc_fn.sa selfhost/sxc_fn_out.c
	clang -O2 -pthread -o selfhost/sxc_fn selfhost/sxc_fn_out.c
	./selfhost/sxc_fn
	clang -O2 -o selfhost/sxc_fn_run selfhost/sxc_fn_emit.c
	./selfhost/sxc_fn_run | grep -q 42
	@echo SELFHOST-FN-OK

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx \
	  selfhost/native_aot selfhost/sxc selfhost/sxc_run selfhost/sxc_fn selfhost/sxc_fn_run selfhost/inject_chr
