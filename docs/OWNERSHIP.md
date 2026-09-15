# Ownership guide

```sayanox
hold a = 10          // independent value
hold b = a           // copy of number

hold s = "hi"        // string (arena in C backend)
hold t = concat(s, "!")  // new string in arena

hold xs = [1, 2, 3]  // list owns its buffer
push(xs, 4)          // grows owned buffer
```

**Do not** expect C-level `free` on every temporary; Stage-2 uses **region GC** for strings.

Rust VM: values are owned by the environment map; no manual free.
