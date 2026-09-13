# Sayanox - one command self-host
.PHONY: all stage2 test selfhost clean

all: stage2

stage2:
	chmod +x selfhost/restore_stage2.sh selfhost/sx
	./selfhost/restore_stage2.sh

test selfhost:
	chmod +x selfhost/bootstrap_selfhost.sh
	./selfhost/bootstrap_selfhost.sh

clean:
	rm -f selfhost/stage2 selfhost/out_* selfhost/cli_* selfhost/stage3 \
	      selfhost/hello_out selfhost/hello_out.c selfhost/*.c \
	      selfhost/compiler_bin selfhost/compiler_out.c 2>/dev/null || true
