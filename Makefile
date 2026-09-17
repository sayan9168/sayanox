# Sayanox — core path without legacy stage scripts
.PHONY: all stage2 sx test bootstrap-cycle clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

# Canonical Step-1 self-host compiler bootstrap cycle.
bootstrap-cycle:
	bash selfhost/bootstrap_cycle.sh

test: sx
	./selfhost/sx_bin examples/hello.sa /tmp/sx_hello 1

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/sx_cli.c
