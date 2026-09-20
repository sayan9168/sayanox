.PHONY: all test complete subset subset-existing clean

all: subset

# Prefer an existing Sayanox compiler. If none exists, subset falls back to

# the C seed once to create gen1.
subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

# Require an already-built gen1. This is the normal development path.
subset-existing:
	if [ ! -x selfhost/gen1 ]; then echo "error: selfhost/gen1 is required; bootstrap it once first" >&2; exit 1; fi
	./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
	clang -O2 -o selfhost/_run selfhost/_out.c
	./selfhost/_run | grep -q 42

# Backward-compatible target name.
complete: subset

test: subset
	@echo TEST-OK

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen1.c selfhost/gen2 selfhost/gen2.c
	rm -f selfhost/_run selfhost/_out.c selfhost/out2.c
