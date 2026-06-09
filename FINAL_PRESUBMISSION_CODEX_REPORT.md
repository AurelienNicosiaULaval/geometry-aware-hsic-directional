# Final Pre-submission Codex Report

Date: 2026-06-09

## Scope

This pass was performed only inside:

`paper_compact_hsic_directional_pub_v3/`

No new simulations were run. Figures and tables were regenerated from existing CSV files after a clean LaTeX pass exposed stale derived files.

## Files Changed

- `main.tex`
- `TODO_BEFORE_SUBMISSION.md`
- `FIGURE_TABLE_AUDIT.md`
- `SUBMISSION_CHECKLIST.md`
- `SIMULATION_AUDIT.md`
- `output/final/data/*.csv`
- `output/final/figures/fig1_alternatives.pdf`
- `output/final/figures/fig2_type1.pdf`
- `output/final/figures/fig3_power.pdf`
- `output/final/figures/fig4_strategy_comparison.pdf`
- `output/final/figures/fig5_kappa_sensitivity.pdf`
- `output/final/figures/fig6_circular_linear.pdf`
- `output/final/figures/fig7_noshiro_torus.pdf`
- `output/final/tables/*.csv`
- `output/final/tables/*.tex`
- `geometry_aware_hsic_directional_CSDA_presubmission.pdf`
- `FINAL_PRESUBMISSION_CODEX_REPORT.md`
- `README.md`
- `.gitignore`

No R source file required editing in this pass. The R source files were inspected to verify simulation settings and test settings.

## Changes Made

1. Fixed the torus proposition reference in Section 8.
   - The torus-torus demonstration now refers to Proposition 1 and the toroidal-block HSIC consequence, not Proposition 2.

2. Verified the positive-definiteness proof.
   - `main.tex` already used the Hermitian form `c_i\overline{c_j}`.
   - The right-hand side remains a squared modulus.
   - A rendered PDF page was converted to `output/final/pdf_checks/lemma_page-03.png`, confirming that the conjugation bar displays in the PDF.

3. Clarified the `N4_mixture_mixture` null scenario.
   - The manuscript now states equal mixture weights.
   - The first angle has centers `(0, pi)` and concentrations `(5, 5)`.
   - The second angle has centers `(pi/2, 3*pi/2)` and concentrations `(4, 4)`.
   - These values were read from `R/02_simulate_circular_circular.R`.

4. Clarified alternative `A5_local_dependence`.
   - The manuscript now states that when `Theta > pi`, `Phi` is uniform on `[0, 2*pi)`.
   - This was read from `R/02_simulate_circular_circular.R`.

5. Harmonized comparator wording.
   - Final simulation CSV files do not contain Jammalamadaka-Sarma or Fisher-Lee results.
   - The manuscript now lists them as implemented Noshiro diagnostics, not as main simulation methods.
   - The statement that the trigonometric diagnostic is not the full García-Portugués et al. 2024 test was retained.

6. Documented circular-linear HSIC settings.
   - Figure 6 is now described as using single-scale circular-linear HSIC.
   - The von Mises concentration uses the median circular-distance rule.
   - The Gaussian bandwidth uses the median Euclidean-distance rule.
   - The Euclidean variables are not additionally standardized in the simulation code.

7. Documented the torus-torus demonstration DGP.
   - `X` and `Y` are both in `T^2`.
   - `T0` uses independent uniform torus blocks.
   - `T1` couples the first coordinate through `Y_1 = X_1 + epsilon mod 2*pi`, with `epsilon ~ VM(0,4)`, and leaves the second coordinate independent uniform.
   - The product-kernel concentration vector is `(2,2)` for both blocks.
   - Settings are `n = 100, 200`, `R = 250`, `B = 299`, and `alpha = 0.05`.

8. Improved the runtime benchmark description.
   - The manuscript now states that the benchmark summary records Darwin 25.5.0 on arm64 with 14 logical cores available.
   - The timing loop is sequential for each test call.

9. Added an unnumbered Code and data availability section.
   - The statement now includes the verified public GitHub repository URL.
   - No archive DOI was invented.

10. Regenerated figures and tables from existing CSV files.
   - No simulation values were changed.
   - Derived figure and table files were regenerated with `R/10_make_figures_tables.R`.

## Result Values Touched in Text

The following values were added or clarified in the manuscript, each read from source code or existing CSV files:

- `N4` mixture weights: equal weights, from `rvm_mix()` default in `R/02_simulate_circular_circular.R`.
- `N4` first-angle centers and concentrations: `(0, pi)`, `(5, 5)`, from `R/02_simulate_circular_circular.R`.
- `N4` second-angle centers and concentrations: `(pi/2, 3*pi/2)`, `(4, 4)`, from `R/02_simulate_circular_circular.R`.
- `A5` independent-region distribution: `Phi ~ U(0, 2*pi)` when `Theta > pi`, from `R/02_simulate_circular_circular.R`.
- circular-linear bandwidth and concentration rules: median rules, from `R/01_kernels_hsic.R`.
- circular-linear standardization: no additional standardization, verified from `R/03_simulate_circular_linear.R` and `R/01_kernels_hsic.R`.
- torus demonstration noise concentration: `VM(0,4)`, from `R/13_run_torus_demo.R`.
- torus product kernel concentration vector: `(2,2)`, from `R/13_run_torus_demo.R`.
- torus demonstration settings: `n = 100, 200`, `R = 250`, `B = 299`, `alpha = 0.05`, from `R/13_run_torus_demo.R` and `output/final/torus_demo_summary.csv`.
- benchmark environment: Darwin 25.5.0 arm64 and 14 logical cores, from `output/final/runtime_benchmark_summary.csv`.

No rejection rates, p-values, or simulation conclusions were changed except to clarify their source and scope.

## Checks Performed

- Clean compile with `latexmk -C main.tex` followed by TeX Live `latexmk`.
- Final PDF copied to `geometry_aware_hsic_directional_CSDA_presubmission.pdf`.
- No unresolved citations.
- No unresolved references.
- All cited figures exist.
- All input tables exist.
- Figure labels resolve in numerical order 1 to 7.
- Table labels resolve in numerical order 1 to 6.
- No forbidden manuscript wording found: `publication-draft`, `final target`, `available run`, `preliminary`, `placeholder`, `not final`, `smoke test`.
- No em dash character appears in `main.tex`.
- BibTeX uses 27 entries, and all 27 entries are cited.

## Manual Verification Remaining

- Add a permanent archival DOI for the replication materials before external submission.
- Record the CPU model and R version for the runtime benchmark before external submission.
- Decide whether to run a larger `n = 500`, `R = 1000`, `B = 999` simulation design.
- Decide whether a verified implementation of the full García-Portugués et al. 2024 trigonometric-moment test is needed.
