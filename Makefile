.PHONY: all stage2 selfhost selfhost-fast selfhost-full selfhost-recompile app native sx test clean unified sx-bin

all: unified

unified: native selfhost-full sx-bin
	@echo UNIFIED-OK

sx-bin:
	@test -f selfhost/sx_driver.c && clang -O2 -o selfhost/sx selfhost/sx_driver.c || true

stage2:
	@if [ ! -f selfhost/stage2_template.c ] || [ $$(wc -c < selfhost/stage2_template.c) -lt 1000 ]; then \
	  curl -fsSL "https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c" -o selfhost/stage2_template.c; \
	fi
	@if [ -f selfhost/inject_chr.c ]; then clang -O2 -o selfhost/inject_chr selfhost/inject_chr.c && ./selfhost/inject_chr; fi
	clang -O2 -o selfhost/stage2 selfhost/stage2_template.c

selfhost-full:
	cat selfhost/sxc_full_a.c.txt selfhost/sxc_full_b.c.txt > selfhost/sxc_full.c
	clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
	./selfhost/sxc_full selfhost/sxc_test_in.sa selfhost/sxc_emit.c
	clang -O2 -o selfhost/sxc_run selfhost/sxc_emit.c
	./selfhost/sxc_run | grep -q 42
	./selfhost/sxc_full examples/builtins_demo.sa selfhost/builtins_out.c
	clang -O2 -o selfhost/builtins_run selfhost/builtins_out.c
	./selfhost/builtins_run | grep -q "hello world"
	@echo SELFHOST-FULL-OK

selfhost-fast: selfhost-full
	@echo SELFHOST-FAST-OK

selfhost: selfhost-full
	@echo SELFHOST-OK

selfhost-recompile: selfhost-full
	./selfhost/sxc_full selfhost/sxc_test_in.sa selfhost/re_a.c
	clang -O2 -o selfhost/re_a selfhost/re_a.c
	./selfhost/re_a | grep -q 42
	@echo SELFHOST-RECOMPILE-OK

native:
	@if ls selfhost/native_src/p00.c.part >/dev/null 2>&1; then \
	  cat selfhost/native_src/p[0-9][0-9].c.part > selfhost/native_aot.c; \
	elif ls selfhost/native_src/g00.b64 >/dev/null 2>&1; then \
	  cat selfhost/native_src/g[0-9][0-9].b64 | tr -d '\n' | base64 -d | gunzip > selfhost/native_aot.c; \
	else echo "skip native"; exit 0; fi
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

sx: sx-bin
	@test -n "$(FILE)" || (echo "Usage: make sx FILE=prog.sa"; exit 1)
	./selfhost/sx --backend=$(or $(BACKEND),auto) $(if $(OUT),-o $(OUT),) $(FILE)

test: selfhost-recompile
	@echo TEST-OK

clean:
	rm -f selfhost/stage2 selfhost/sxc selfhost/sxc_full selfhost/sxc_run selfhost/sx selfhost/native_aot selfhost/re_* selfhost/builtins_*
