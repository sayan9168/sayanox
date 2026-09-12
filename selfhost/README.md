# Self-host CLI (v0.3.27)

## Compile any `.sa` file

```bash
chmod +x selfhost/sx
./selfhost/sx selfhost/hello.sa --run
./selfhost/sx selfhost/struct_demo.sa -o /tmp/s --run
./selfhost/sx path/to/any.sa -o outname
```

## Errors

Stage-2 prints **line number**, expected token, and got token on parse failure.

## Stage-3

```bash
./selfhost/bootstrap_stage3.sh
```
