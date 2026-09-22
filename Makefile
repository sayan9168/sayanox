.PHONY: all test subset pure-gen2 native native-test gc-test clean

all: subset

subset:
	chmod +x selfhost/bootstrap_subset.sh
	./selfhost/bootstrap_subset.sh

pure-gen2: subset
	chmod +x selfhost/bootstrap_pure_gen2.sh
	./selfhost/bootstrap_pure_gen2.sh

test: subset pure-gen2
	@echo TEST-OK

native:
	@if [ -f selfhost/native_aot.c ]; then clang -O2 -o selfhost/native_aot selfhost/native_aot.c; fi

native-test: native
	@if [ -x selfhost/native_aot ] && [ -f examples/native_hello.sa ]; then \
	  ./selfhost/native_aot examples/native_hello.sa selfhost/_native_test && \
	  ./selfhost/_native_test | grep -qx '42' && rm -f selfhost/_native_test; \
	else echo "native skip"; fi

gc-test:
	@if [ -f selfhost/rc_runtime_stress.c ]; then \
	  cc -std=c11 -O2 -o selfhost/_rc selfhost/rc_runtime_stress.c && \
	  ./selfhost/_rc | tee /tmp/rc.out && grep -qx 'gc-rc-ok' /tmp/rc.out; \
	else echo "rc skip"; fi

clean:
	rm -f selfhost/sxc_full selfhost/gen1 selfhost/gen2 selfhost/_run selfhost/_out.c
	rm -f selfhost/gen1_mini selfhost/gen2_mini selfhost/gen1_mini.c selfhost/gen2_mini.c
