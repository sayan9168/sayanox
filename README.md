# Sayanox

Original language (`.sa`) by **Sayan Mahata**.

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make stage2
make bootstrap-production
make sx
./selfhost/sx examples/hello.sa --run
```

Native subset (no Stage-2 for user programs after one build):

```sh
make native && make bootstrap-native
```

Drivers are **Sayanox** (`*.sa`) + **Makefile**. Prefer `make` over old shell scripts.

MIT
