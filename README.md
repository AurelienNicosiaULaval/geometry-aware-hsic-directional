# Geometry-aware HSIC independence testing

Replication materials for the manuscript:

`Geometry-aware HSIC independence testing for circular, toroidal and circular-linear data`

Target journal: Computational Statistics & Data Analysis.

## Contents

- `main.tex`: LaTeX manuscript source.
- `references.bib`: bibliography.
- `R/`: R implementation, simulation scripts, figure/table generation scripts and checks.
- `data/`: local data files used in the manuscript.
- `output/final/`: CSV outputs, derived plotting data, figures and tables used in the manuscript.
- `geometry_aware_hsic_directional_CSDA_presubmission.pdf`: compiled manuscript PDF.
- `FINAL_PRESUBMISSION_REPORT.md`: final consistency report.

## Reproduce figures and tables

From the repository root:

```bash
Rscript R/07_smoke_tests.R
Rscript R/10_make_figures_tables.R
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

The current manuscript figures and tables are generated from the CSV files in `output/final/`.

## Reproducibility

Compile the manuscript:

```bash
latexmk -C main.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

Run lightweight implementation checks:

```bash
Rscript R/07_smoke_tests.R
```

Regenerate manuscript figures and tables from existing CSV files:

```bash
Rscript R/10_make_figures_tables.R
```

Reproduce the Noshiro analysis from `data/noshiro.csv`:

```bash
Rscript R/11_noshiro_final.R
```

The full simulation runner is computationally expensive. It is resumable and
writes outputs under `output/final/`.

## Main simulation runner

```bash
Rscript R/09_final_simulation_runner.R \
  --n=50,100,200 \
  --R=500 \
  --B=499 \
  --seed=20260606 \
  --output-dir=output/final
```

Targeted supporting runs used for the current manuscript are:

```bash
MC_CORES=8 Rscript R/12_run_reduced_sensitivity.R
MC_CORES=8 Rscript R/13_run_torus_demo.R
Rscript R/14_benchmark_runtime.R
```

## Data provenance

The Noshiro data used in the manuscript are stored in `data/noshiro.csv`. Provenance notes are in `data/noshiro_source.txt`.

## License

The R code and supporting software scripts are licensed under the MIT License in `LICENSE`. Data and generated-output notes are in `LICENSE-DATA.md`.

## Archive status

This GitHub repository is the working public replication repository. Citation metadata are provided in `CITATION.cff`. The Zenodo concept DOI for the archived replication materials is:

https://doi.org/10.5281/zenodo.20617102
