# Sayanox logo

Vector masters plus raster derivatives. Everything here is generated from one
geometry: a rounded-square badge on an indigo -> cyan diagonal gradient,
carrying a geometric **S** built from two 270-degree circular arcs.

The S is the boot chain made visible. A self-hosting compiler has to be folded
out of itself -- the seed emits a compiler, that compiler emits the next one,
and at the fixed point gen3 == gen4 byte for byte. Two arcs whose tangents meet
eastward at the waist are the smallest shape that says "one letterform folded
out of itself" without being a picture of a compiler.

| File | What it is | Use it for |
| --- | --- | --- |
| `sayanox-logo.svg` | The mark, 512x512 vector master | Anything scalable. Edit this one. |
| `sayanox-logo.png` | The mark, 1024x1024 raster | Social cards, print, anywhere a bitmap is required |
| `sayanox-logo-256.png` | The mark, 256x256 raster | README and docs headers (this is what `README.md` embeds) |
| `favicon.svg` | The mark, identical geometry | Browser tab icon; point `<link rel="icon">` here |
| `sayanox-lockup.svg` | Mark + `Sayanox` wordmark, transparent ground | Embedding on a dark or coloured background |
| `sayanox-lockup.png` | The same lockup rasterised on the navy ground | Standalone use where the ground is not controlled |
| `sayanox-banner.svg` | 1280x640 social card: mark, wordmark, tagline | GitHub social preview, link unfurls |
| `sayanox-banner.png` | The same card as a bitmap | Anything that will not take an SVG |

## Palette

| Token | Hex | Where |
| --- | --- | --- |
| Indigo | `#4F46E5` | Gradient start, top-left of the badge |
| Cyan | `#06B6D4` | Gradient end, bottom-right of the badge |
| White | `#FFFFFF` | The S and the wordmark |
| Navy | `#070B1A` | Ground for the lockup PNG and the banner |
| Muted | `#8A93A6` | The banner tagline |

The gradient runs corner to corner in `userSpaceOnUse` coordinates, so it does
not move when the mark is scaled. The wordmark is not text in the SVG files:
its outlines are baked in as paths, so the lockup renders identically on a
machine with no Sayanox font installed.

## Geometry

```
viewBox        0 0 512 512
badge          x=26 y=26 w=460 h=460 rx=116
spine centre   x=256  y=257
arc radius     136
vertical squash 0.63 (applied about the spine centre)
stroke width   58, round cap and join
```

Two arcs of 270 degrees, centres 2R apart on the vertical, swept so that both
arrive at the waist heading east -- that is what makes the waist read as one
continuous stroke instead of two bowls butting together. The squash is what
turns the raw 2:1 arc pair into an S with the proportions a letter wants.

## Regenerating

There is no generator in this repository. The repo's rule is that its own
tooling is written in Sayanox, and a Python asset script would break
`test-language-deps`, so it was run outside the tree and only the results were
committed. The SVG masters are hand-editable: change the numbers in the
`Geometry` block above and the rest follows.
