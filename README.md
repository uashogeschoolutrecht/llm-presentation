# LLM Presentation

This repository contains a self-contained Beamer presentation in
`presentation/` and a companion notebook, `my-llm.ipynb`, that builds and
trains a small Shakespeare language model.

## Use the notebook

Set up the Python environment from the repository root:

```sh
# Linux or macOS
./setup.sh
```

```powershell
# Windows PowerShell
.\setup.ps1
```

Then open `my-llm.ipynb` in an editor with Jupyter support and select the
project's `.venv` Python environment as the kernel. Alternatively, start
JupyterLab from the command line without adding it permanently to the project:

```sh
uv run --with jupyterlab jupyter lab my-llm.ipynb
```

Run the cells from top to bottom. The notebook:

- downloads the Tiny Shakespeare dataset to `input.txt`;
- demonstrates two tokenizers: an extremely simple character-level tokenizer
  and a byte-level Byte Pair Encoding (BPE) tokenizer;
- prepares training and validation batches;
- defines and trains a small Transformer language model; and
- generates Shakespeare-like text.

The character-level tokenizer is active by default and maps every distinct
character directly to an integer ID. The BPE tokenizer is the implementation of
the Byte Pair Encoding approach introduced in the presentation: it starts with
individual bytes and repeatedly merges frequently occurring adjacent pairs into
new tokens. To use it for the language model, uncomment the `encode` and
`decode` assignments at the end of the BPE tokenizer cell before running the
remaining cells.

The dataset download requires an internet connection. Model training uses CUDA
when it is available and otherwise runs on the CPU; the default 5,000 training
iterations can take a while on CPU.

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
