# Sayanox - one command self-host
.PHONY: all stage2 test selfhost clean examples repl fmt

all: stage2

stage2:
	chmod +x selfhost/restore_stage2.sh selfhost/sx
	./selfhost/restore_stage2.sh

test selfhost:
	chmod +x selfhost/bootstrap_selfhost.sh
	./selfhost/bootstrap_selfhost.sh

examples: stage2
	chmod +x selfhost/sx
	./selfhost/sx examples/hello.sa --run
	./selfhost/sx examples/countdown.sa --run
	./selfhost/sx examples/greet.sa --run

echo-help:
	@echo "make stage2 | test | examples | repl | fmt"

repl:
	chmod +x tools/sxrepl.sh
	./tools/sxrepl.sh

fmt:
	@test -n "$(FILE)" || (echo "usage: make fmt FILE=path.sa"; exit 1)
	chmod +x tools/sxfmt.sh
	./tools/sxfmt.sh $(FILE) --write

clean:
	rm -f selfhost/stage2 selfhost/out_* selfhost/cli_* selfhost/stage3 \
	      selfhost/hello_out selfhost/hello_out.c selfhost/*.c \
	      selfhost/compiler_bin selfhost/compiler_out.c 2>/dev/null || true
