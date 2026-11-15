# Title with `code` and **bold**

Intro paragraph spans
two source lines and has *emphasis*, _under_, a [link](https://example.com/a?b=1),
a [doc](OTHER.md#frag), a [bad](javascript:alert(1)) and ![alt](img.png).

## Escapes & entities

Raw <b>bold</b> & "quotes" and 'apostrophes' must be escaped.

Inline `a < b & c > d` stays literal; `` ` `` edge; unterminated ` tick.

### Links and images

- [safe](./rel/path.md) and [anchor](#section)
- [unsafe](data:text/html,x) becomes plain label
- ![pic](https://example.com/i.png) and ![no](javascript:x)
- item with a continuation line
  that folds into the same li
  and again

1. first ordered
2. second ordered
   continued here

> quoted **bold** line
> second quoted line
>
> quoted paragraph two

```
fenced <code> & "stuff"
  indented inside fence
```

    indented code block
    second line

| Col A | Col B |
| :--- | ---: |
| `x|y` | plain |
| a | b |

---

###### Six

Text with **bold _and em_ inside** plus a_n_b identifiers.
