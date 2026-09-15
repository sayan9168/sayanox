# Editor support

Sayanox does not ship a language-server binary in this tree yet.

Use the CLI and formatter:

```bash
./selfhost/sx file.sa --run
./tools/sxfmt.sh file.sa
```

Syntax highlighting can use a generic text grammar for `.sa` until a dedicated LSP is added in Sayanox itself.
