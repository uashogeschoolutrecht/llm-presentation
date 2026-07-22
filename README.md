# LLM Presentation

This repository contains a Beamer presentation in `presentation/` and a
companion notebook, `my-llm.ipynb`, that builds and trains a small Shakespeare
language model. The notebook is designed to stay open during the talk: the
slides and notebook use the same three-part structure, and the attention slides
point to the relevant notebook line numbers.

## Follow the presentation in the notebook

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

Keep the notebook open beside the presentation and use its linked roadmap to
jump between the same three parts:

| Presentation chapter | Notebook section | Code to inspect |
| --- | --- | --- |
| Tokens | **Tokens** | Character-to-integer encoding and byte-level BPE |
| Vectors and embeddings | **Vectors and embeddings** | Token and position embeddings, tensors, and the output projection |
| Transformers and attention | **Transformers and attention** | Queries, keys, values, causal masking, softmax, value aggregation, and multi-head attention |

Run the cells from top to bottom. In VS Code, line numbers make it easier to
follow the code references printed on slides 20–29. Select a notebook cell,
press `Esc` to enter command mode, and press `Shift+L` to toggle line numbers
for the entire notebook on Windows or macOS.

The notebook downloads the Tiny Shakespeare dataset to `input.txt`, prepares
training and validation batches, trains the small Transformer, and generates
Shakespeare-like text.

The **Tokens** section first introduces a deliberately naive character-level
encoder that maps each distinct character directly to an integer ID. The next
cells define a byte-level Byte Pair Encoding (BPE) tokenizer, train it, and
reassign `encode` and `decode` to use BPE. To train with the character tokenizer
first, skip the BPE activation cell and run the remaining cells; then run the BPE
cell and rerun the downstream model cells to compare the results.

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

The compiled presentation is written to `presentation/main.pdf`. Intermediate
build files are kept in `presentation/build/`.

To remove auxiliary build files while keeping the PDF:

```sh
cd presentation
latexmk -c
```

Raster and PDF graphics belong in `presentation/assets/images/`. SVG source
files belong in `presentation/assets/svg/`; the presentation is configured so
they can be included by basename with `\includesvg`.
