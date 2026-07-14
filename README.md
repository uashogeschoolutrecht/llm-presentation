# LLM Presentation

This repository contains a self-contained Beamer presentation in
`presentation/`. The existing Python starter project is kept separate from the
LaTeX sources.

## Build the presentation

The presentation requires TeX Live with Beamer, `latexmk`, and Inkscape for SVG
conversion.

```sh
cd presentation
latexmk main.tex
```

The compiled presentation is written to `presentation/build/main.pdf`.

To remove auxiliary build files while keeping the PDF:

```sh
cd presentation
latexmk -c
```

Raster and PDF graphics belong in `presentation/assets/images/`. SVG source
files belong in `presentation/assets/svg/`; the presentation is configured so
they can be included by basename with `\includesvg`.
