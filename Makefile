# Sayanox bootstrap Makefile
# Prefer clang; fall back to gcc/cc for Termux/Linux CI.

CC ?= $(shell command -v clang >/dev/null 2>&1 && echo clang || (command -v gcc >/dev/null 2>&1 && echo gcc || echo cc))

.PHONY: all subset seed gen1 gen2 pure-gen2 test true-selfhost selfhost native native-test gc-test clean

all: subset seed gen1 gen2

subset:
	bash selfhost/bootstrap_subset.sh

seed:
	bash selfhost/bootstrap_seed.sh

gen1:
	bash selfhost/bootstrap_gen1.sh

gen2:
	bash selfhost/bootstrap_gen2.sh

pure-gen2: gen2

test: subset seed gen1 gen2
	@echo TEST-OK

native:
	@echo "native target: see docs"

native-test: native

gc-test:
	@echo "gc-test: optional"

clean:
	rm -f selfhost/gen1 selfhost/gen1.c selfhost/gen2 selfhost/gen2.c
	rm -f selfhost/boot selfhost/boot.c selfhost/boot2 selfhost/boot2.c
	rm -f selfhost/seed/sxc_seed

# True full self-host: gen1 compiles compiler_min.sa → gen2
true-selfhost:
	bash selfhost/bootstrap_true_selfhost.sh

selfhost: true-selfhost
