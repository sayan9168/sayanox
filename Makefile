# Sayanox — supported build targets
.PHONY: all stage2 sx native test bootstrap-cycle clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

native:
	@if [ ! -f selfhost/native_aot.c ] || grep -q 'show <integer>' selfhost/native_aot.c 2>/dev/null; then \
	  if [ -f selfhost/native_aot.c.gz.b64 ] && base64 -d selfhost/native_aot.c.gz.b64 2>/dev/null | gzip -d > selfhost/native_aot.c.tmp 2>/dev/null; then \
	    mv selfhost/native_aot.c.tmp selfhost/native_aot.c; \
	  fi; \
	fi
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

test: sx native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/sx_cli.c selfhost/native_aot
