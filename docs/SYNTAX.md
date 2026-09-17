# Sayanox Syntax Reference

## Source files

Sayanox programs use the `.sa` extension.

## Bindings

```sa
hold value = 42
hold name = "Sayan"
```

A binding requires `=`.

## Output

```sa
show value
show "text"
show value + 1
```

## Functions

```sa
make square(x) {
  give x * x
}
```

`make` declares a function and `give` returns a value.

## Conditions

```sa
when condition {
  show "yes"
} otherwise {
  show "no"
}
```

## Loops

```sa
while condition {
  show "loop"
}
```

## Operators

Arithmetic:

```text
+  -  *  /
```

Comparisons:

```text
==  !=  <  <=  >  >=
```

Logical operators and additional syntax should follow the parser implementation in `selfhost/parser.sa`; this document intentionally does not claim syntax that the current parser does not implement.

## Strings

String literals use double quotes. Common runtime helpers include:

```text
len
concat
char_at
char_code
char_from_code
contains
starts_with
ends_with
upper
lower
trim
str
```

## Lists

List literals use brackets:

```sa
hold items = [1, 2, 3]
show items[0]
push(items, 4)
```

## Structs

The compiler has an evolving structured-value path. Current self-host codegen contains a concrete `Point { x, y }` demonstration; generic struct lowering remains part of the self-hosting work.

## Files

```sa
hold data = read_file("data.txt")
hold status = write_file("data.txt", data)
```

## Errors

Compiler diagnostics should identify the source location and provide a useful message. The LSP exposes diagnostics for malformed tokens, common keyword typos, missing `=`, empty `show`, and unmatched braces.

## Compatibility rule

The compiler implementation is authoritative. When documentation and implementation disagree, update the documentation only after confirming the intended grammar and adding a regression test.
