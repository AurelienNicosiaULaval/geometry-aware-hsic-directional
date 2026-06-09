# Final pre-submission Codex report

Date: 2026-06-09

Repository:

`geometry-aware-hsic-directional-public`

Branch used for this pass:

`final-submission-readiness`

Starting commit:

`cc13a5868d28a667aca98092074b11e834ad1816`

## Scope

This was a final submission-readiness pass for the CSDA pre-submission
manuscript and public replication repository. No major simulations were run.
No rejection rates, p-values, benchmark values or table entries were changed.
No final CSV output was deleted.

## Files changed

- `CITATION.cff`
- `README.md`
- `ZENODO_NEXT_STEPS.md`
- `main.tex`
- `geometry_aware_hsic_directional_CSDA_presubmission.pdf`
- `LICENSE`
- `LICENSE-DATA.md`
- `FINAL_FIGURE_TABLE_TRACE.md`
- `FINAL_PRESUBMISSION_CODEX_REPORT.md`
- `SUBMISSION_FILES_CHECKLIST.md`
- `output/smoke_test_log.txt`

## Manuscript source verification

The checked `main.tex` corresponds to the 18-page pre-submission manuscript.
It contains:

- Section 8, `Simulation results`
- the torus-torus demonstration, labelled as Table 4 by LaTeX
- the runtime benchmark, labelled as Table 5 by LaTeX
- an unnumbered `Code and data availability` section
- the GitHub repository URL
- the Zenodo concept DOI and the version-specific Zenodo DOI

The compiled PDF has 18 pages.

## Positive-definiteness proof

Lemma 1 was inspected. The quadratic form uses the Hermitian convention
`c_i\overline{c_j}` and the right-hand side is a squared modulus. No
mathematical change was made.

## Inconsistency checks

The manuscript was searched for:

- `publication-draft`
- `final target`
- `available run`
- `preliminary`
- `placeholder`
- `not final`
- `smoke test`
- `Proposition 2`
- `independent otherwise`
- overstated novelty phrases
- em dash characters

No problematic occurrences remain in manuscript prose. The phrase
`uniformly optimal` appears only in negative wording stating that no uniformly
optimal power claim is made.

The torus-torus demonstration refers to Proposition 1 and the toroidal-block
consequence. Jammalamadaka-Sarma and Fisher-Lee are described as Noshiro
diagnostics, not main simulation comparators.

## License status

A code license was added:

- `LICENSE`: MIT License, 2026, Aurelien Nicosia

Data and generated-output notes were added:

- `LICENSE-DATA.md`

The Noshiro data file is documented as a local CSV export of
`ridgetorus::earthquakes`. The CRAN source package `ridgetorus` version 1.0.3
declares GPL-3 in its `DESCRIPTION`. The repository does not assert an
additional license for third-party source data beyond the source package and
original-data terms.

## DOI status

Verified DOI information:

- Zenodo concept DOI: `10.5281/zenodo.20617102`
- version-specific DOI for `v0.1.3-csda-presubmission`: `10.5281/zenodo.20617128`
- Zenodo record: `https://zenodo.org/records/20617128`

The concept DOI and version-specific DOI were added to the README and manuscript
Code and data availability section. The version DOI was added to
`CITATION.cff`.

## Reproducibility checks

The README now contains commands for:

- compiling the manuscript
- running lightweight smoke tests
- regenerating figures and tables from existing CSV files
- reproducing the Noshiro analysis
- rerunning the main simulation runner, with a warning that it is expensive

Executed in this pass:

```bash
Rscript R/07_smoke_tests.R
latexmk -C main.tex
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

The smoke tests passed and wrote `output/smoke_test_log.txt`.

## LaTeX and citation status

Clean LaTeX compilation completed successfully. Final checks found:

- no undefined citations
- no undefined references
- no missing figure or table files
- no BibTeX warnings
- no LaTeX warnings after the final run
- 18-page PDF output

The string `missing$` appears only in the BibTeX function-call count in
`main.blg`; it is not a missing-file warning.

## Figure and table traceability

`FINAL_FIGURE_TABLE_TRACE.md` was created. It records, for each manuscript
figure and table:

- the output file used by LaTeX
- the source CSV
- the generating script
- whether the file is present

LaTeX label checks show:

- Figures resolve in order 1 to 7.
- Tables resolve in order 1 to 6.
- `tab:torus-demo` is Table 4.
- `tab:runtime` is Table 5.
- `tab:noshiro` is Table 6.

## Remaining manual actions before CSDA submission

- Decide whether to add ORCID metadata to Zenodo and `CITATION.cff`.
- Confirm that the latest archived Zenodo release is the intended submission
  release.
- If the license and traceability files added in this pass should be included
  in the exact archived submission snapshot, create a follow-up GitHub release
  and let Zenodo archive it. The current verified version DOI remains
  `10.5281/zenodo.20617128` for `v0.1.3-csda-presubmission`.
- Decide whether the current medium simulation design is sufficient for CSDA,
  or whether larger runs should be treated as a later robustness extension.
- Decide whether the current comparator set is sufficient, or whether a
  verified full implementation of Garcia-Portugues et al. 2024 is needed.
- Record CPU model and R version for the runtime benchmark if desired by the
  journal or reviewers.

## Final verdict

The repository and manuscript are ready for CSDA pre-submission review with
explicit remaining risks limited to simulation scale, comparator breadth and
optional metadata polish.
