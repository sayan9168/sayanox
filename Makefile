.PHONY: all stage2 sx native test clean

all: stage2 sx

stage2:
	clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
	./selfhost/build_stage2

sx: stage2
	./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
	clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
	clang -O2 -o selfhost/sx selfhost/sx_launcher.c

native:
	python3 -c "from pathlib import Path;d=bytes.fromhex(''.join(p.read_text() for p in sorted(Path('selfhost/native_src').glob('h*.hex'))));Path('selfhost/native_aot.c').write_bytes(d)"
	clang -O2 -o selfhost/native_aot selfhost/native_aot.c

test: native
	./selfhost/native_aot examples/hello.sa /tmp/hello_native
	/tmp/hello_native | grep -q 42

clean:
	rm -f selfhost/stage2 selfhost/build_stage2 selfhost/sx_bin selfhost/sx selfhost/native_aot
