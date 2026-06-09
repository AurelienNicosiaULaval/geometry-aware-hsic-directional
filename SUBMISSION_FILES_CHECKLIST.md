# Submission files checklist

Date: 2026-06-09

## Core manuscript files

| Item | Path | Status |
|---|---|---|
| Manuscript PDF | `geometry_aware_hsic_directional_CSDA_presubmission.pdf` | Present, compiled from clean LaTeX run |
| LaTeX source | `main.tex` | Present |
| Bibliography | `references.bib` | Present |
| Bibliography output | `main.bbl` | Present after clean compile |

## Replication files

| Item | Path | Status |
|---|---|---|
| R scripts | `R/` | Present |
| Noshiro data | `data/noshiro.csv` | Present |
| Noshiro provenance | `data/noshiro_source.txt` | Present |
| Final CSV outputs | `output/final/` | Present |
| Final figures | `output/final/figures/` | Present |
| Final tables | `output/final/tables/` | Present |
| Figure/table trace | `FINAL_FIGURE_TABLE_TRACE.md` | Present |

## Repository metadata

| Item | Path or URL | Status |
|---|---|---|
| README | `README.md` | Present |
| Citation metadata | `CITATION.cff` | Present, includes version DOI |
| Code license | `LICENSE` | Present, MIT |
| Data license notes | `LICENSE-DATA.md` | Present |
| Zenodo concept DOI | `https://doi.org/10.5281/zenodo.20617102` | Verified |
| Zenodo version DOI | `https://doi.org/10.5281/zenodo.20617128` | Verified |
| GitHub release | `https://github.com/AurelienNicosiaULaval/geometry-aware-hsic-directional/releases/tag/v0.1.3-csda-presubmission` | Present |

## Checks

| Check | Status |
|---|---|
| Clean LaTeX compile | Passed |
| Undefined citations | None after final compile |
| Undefined references | None after final compile |
| Missing figures or tables | None detected |
| Smoke tests | Passed |
| Em dash in `main.tex` | None detected |
| Internal draft wording in `main.tex` | None detected |
| Figure numbering | 1 to 7 |
| Table numbering | 1 to 6 |

## Manual items

- Optional: add ORCID metadata.
- Optional: record CPU model and R version for the runtime benchmark.
- Editorial decision: whether to run larger simulations.
- Editorial decision: whether current comparator breadth is sufficient for CSDA.
