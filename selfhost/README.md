# Self-host CLI

## Supported bootstrap

Build Stage-2 with:

```bash
make stage2
```

or:

```bash
./selfhost/restore_stage2.sh
```

Production smoke/bootstrap:

```bash
./selfhost/bootstrap_production.sh
```

Full self-host paths:

```bash
./selfhost/bootstrap_full_selfhost.sh
./selfhost/bootstrap_full_language_selfhost.sh
```

## Compile any `.sa` file

```bash
chmod +x selfhost/sx
./selfhost/sx selfhost/hello.sa --run
./selfhost/sx selfhost/struct_demo.sa -o /tmp/s --run
./selfhost/sx path/to/any.sa -o outname
```

## Errors

Stage-2 reports the line number, expected token, and received token on parse failure.

Numbered `stage*.sh` and `step*.sh` scripts are retired and are not supported CLI entry points.
