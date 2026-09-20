.PHONY: all test complete clean

all: complete

complete:
	chmod +x selfhost/bootstrap_complete.sh
	./selfhost/bootstrap_complete.sh

test: complete
	@echo TEST-OK

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/_run selfhost/_out.c selfhost/gen1.c selfhost/out2.c
