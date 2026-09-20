.PHONY: all stage2 selfhost selfhost-fast selfhost-loop app native sx test clean unified sx-bin

all: unified

unified: native selfhost-fast sx-bin
	@echo UNIFIED-OK

sx-bin:
	clang -O2 -o selfhost/sx selfhost/sx_driver.c

stage2:
	@if [ ! -f selfhost/stage2_template.c ] || [ $$(wc -c < selfhost/stage2_template.c) -lt 1000 ]; then \
	  curl -fsSL "https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c" -o selfhost/stage2_template.c; \
	fi
	@if [ -f selfhost/inject_chr.c ]; then clang -O2 -o selfhost/inject_chr selfhost/inject_chr.c && ./selfhost/inject_chr; fi
	clang -O2 -o selfhost/stage2 selfhost/stage2_template.c

selfhost/sxc.sa.b64:
	@if [ -d selfhost/sxc_sa_parts ]; then \
	  cat selfhost/sxc_sa_parts/p00.txt selfhost/sxc_sa_parts/p01a.txt selfhost/sxc_sa_parts/p01b.txt selfhost/sxc_sa_parts/p02.txt > selfhost/sxc.sa.b64; \
	fi

selfhost: stage2 selfhost/sxc.sa.b64
	@if [ -f selfhost/sxc.sa.b64 ]; then cat selfhost/sxc.sa.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc.sa; fi
	./selfhost/stage2 selfhost/sxc.sa selfhost/sxc_out.c
	clang -O2 -pthread -o selfhost/sxc selfhost/sxc_out.c
	./selfhost/sxc selfhost/sxc_test_in.sa selfhost/sxc_emit.c
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 42
	@echo SELFHOST-OK

selfhost-fast:
	@test -f selfhost/sxc_out_c/p00.b64 || (echo "missing sxc_out_c"; exit 1)
	cat selfhost/sxc_out_c/p*.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/sxc_out.c
	clang -O2 -pthread -o selfhost/sxc selfhost/sxc_out.c
	./selfhost/sxc selfhost/sxc_test_in.sa selfhost/sxc_emit.c
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 42
	@echo SELFHOST-FAST-OK

selfhost-loop: selfhost-fast
	clang -O2 -o selfhost/prove_loop selfhost/prove_loop.c
	./selfhost/prove_loop

native:
	@if ls selfhost/native_src/p00.c.part >/dev/null 2>&1; then \
	  cat selfhost/native_src/p[0-9][0-9].c.part > selfhost/native_aot.c; \
	else \
	  cat selfhost/native_src/g[0-9][0-9].b64 | tr -d '\n' | base64 -d | gunzip > selfhost/native_aot.c; \
	fi
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

sx: sx-bin
	@test -n "$(FILE)" || (echo "Usage: make sx FILE=prog.sa [BACKEND=auto]"; exit 1)
	./selfhost/sx --backend=$(or $(BACKEND),auto) $(if $(OUT),-o $(OUT),) $(FILE)

test: unified selfhost-loop
	./selfhost/sx --backend=native -o /tmp/t_hello examples/hello.sa
	/tmp/t_hello | grep -q 42
	@echo TEST-OK

clean:
	rm -f selfhost/stage2 selfhost/sxc selfhost/sxc_run selfhost/sx selfhost/native_aot selfhost/prove_loop selfhost/loop_*
