# 2026-10-19 — brand assets, README header, docs cross-links

On branch `arena/cdeaefb3-sayanox`. Every log in this directory is the actual
command output from this checkout.

## What changed

The repository had no image assets at all. It now has a logo.

| file | what it is |
|---|---|
| `assets/sayanox-logo.svg` | the mark, 512×512 vector master |
| `assets/sayanox-logo.png` | the mark, 1024×1024 raster |
| `assets/sayanox-logo-256.png` | the mark, 256×256 raster — what the README embeds |
| `assets/favicon.svg` | the mark, identical geometry, for a browser tab |
| `assets/sayanox-lockup.svg` | mark + `Sayanox` wordmark, transparent ground |
| `assets/sayanox-lockup.png` | the same lockup on the navy ground |
| `assets/sayanox-banner.svg` / `.png` | 1280×640 social card: mark, wordmark, tagline |
| `assets/README.md` | palette, exact geometry, usage notes |

The mark is a rounded-square badge on an indigo → cyan diagonal gradient,
carrying a geometric **S** built from two 270-degree circular arcs whose
tangents meet eastward at the waist. The S is the boot chain made visible — a
self-hosting compiler has to be folded out of itself, which is what the
`gen3 == gen4` fixed point proves mechanically.

The wordmark is not text in the SVG files: its outlines were extracted from
DejaVu Sans Bold's `glyf` table and baked in as paths, so the lockup renders
identically on a machine with no such font installed.

`README.md` gained a centred header block (logo, title, subtitle, badges) and a
**Logo** section documenting the set. `docs/GITHUB_LANGUAGE.md` gained a
*Repository presentation* section recording that the social-preview card has to
be uploaded by hand in the repository settings, because GitHub does not read it
from the working tree.

| file | before | after |
|---|---:|---:|
| tracked image assets | 0 | 8 (9 files in `assets/`, counting its README) |
| `README.md` | 211 lines | 246 lines |
| `docs/GITHUB_LANGUAGE.md` | 76 lines | 91 lines |
| tracked `.sa` files | 279 | 279 (unchanged) |

## Gates

`make test-doc-claims` and `make test-language-deps` were one `make` invocation
so `gen2` was rebuilt once and both gates ran against the same binaries
(`doc-and-deps-suite.log` is that run in full; `doc-claims.log` and
`language-deps.log` are the two slices). `make doctor`, `make gen3` and
`make all-sayanox` ran afterwards against the same `gen2`.

- `make doctor` — `DOCTOR-OK`, `DOCTOR_EXIT=0` (`doctor.log`)
- `make gen3` — `GEN3_EXIT=0`, ends in `=== GEN3-OK ===` and
  `[OK] byte-identical gen3 == gen4` (`gen3.log`)
- `make test-doc-claims` — `[OK] doc claims: 24 legacy documents carry the
  banner; …` (`doc-claims.log`). This is the gate that matters most for a README
  edit: it fails if `README.md` stops linking `docs/ALL_SAYANOX_PHASE.md`, and it
  still passes.
- `make test-language-deps` — both halves green (`language-deps.log`):
  `[OK] language deps (static): POSIX sh scripts only; no awk/sed in build or
  test recipes` and `[OK] language deps: no bash/awk/sed/python/perl/node/ruby
  invoked by the exercised build, test and LSP paths`.

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose**, `ALL_SAYANOX_EXIT=2`
  (`all-sayanox.log`). The inventory is unchanged by this cut and reads exactly
  as the documents say: seed 2,035 lines, native backend 4,353 lines, Makefile
  4,860 lines, 25 build scripts, 279 `.sa` files.

## Why the generator is not in the repository

The asset generator is a Python program that parses `glyf`/`loca`/`cmap`/
`hmtx`, flattens the two arcs, and rasterises with a hand-rolled PNG writer
(zlib + CRC) plus an even-odd scanline fill for the glyphs. It ran outside the
tree and only its output was committed.

Committing it would have broken `make test-language-deps`, whose whole point is
that no maintained path reaches for an interpreter — and this repository's rule
is that its own tooling is written in Sayanox. The SVG masters are the editable
source of truth instead: the geometry is four numbers (`arc radius 136`,
`vertical squash 0.63`, `stroke width 58`, badge `rx 116`) recorded in
`assets/README.md`, and every raster follows from them.

No SVG rasteriser exists in this environment (ImageMagick's SVG delegate is the
absent `rsvg-convert`, `cairosvg` cannot load `libcairo.so.2`, and there is no
Pillow, numpy, rsvg-convert or inkscape), which is why the renderer was written
rather than delegated.

## Honest limits

- **The wordmark is DejaVu Sans Bold.** It is a good, legible humanist sans and
  it is the only family installed here, but it is not a custom-drawn wordmark.
  A distinctive letterform would be a separate piece of design work; what is
  committed is a well-set wordmark in an existing face.
- **The lockup PNG has an opaque navy ground; the lockup SVG does not.** The
  white wordmark is invisible on a light background, so the SVG is for dark or
  coloured grounds and the PNG is the standalone form. Both are labelled that
  way in `assets/README.md`.
- **The social-preview card is not uploaded.** GitHub reads it from repository
  settings, not from the working tree, so `assets/sayanox-banner.png` is
  prepared and documented but the upload is still a manual step. Recorded in
  `docs/GITHUB_LANGUAGE.md`.
- **The mark was reviewed as a raster, not as a rendered SVG.** No SVG
  rasteriser exists here, so `sayanox-logo.svg` and `sayanox-logo.png` were
  checked as well-formed XML and as a structurally valid PNG respectively, and
  the PNG was inspected visually. The SVG has not been rendered by a real SVG
  engine; its geometry is the same numbers the rasteriser used, but a browser
  render has not been verified.
- **This cut touches no compiler, seed, backend or Makefile source.** `gen3`,
  `true-selfhost`, `native-test` and `doctor` are unaffected by construction;
  `gen3` and `doctor` were re-run anyway so the branch carries a pinned record,
  but `true-selfhost` and `native-test` were not and are not claimed here.
