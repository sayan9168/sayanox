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

# Native AOT MVP (Linux x86_64 ELF, no clang for the .sa output binary)
native:
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

bootstrap-cycle:
	bash selfhost/bootstrap_cycle.sh

test: sx native
	./selfhost/sx_bin examples/hello.sa /tmp/sx_hello 1
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/sx_cli.c selfhost/native_aot
