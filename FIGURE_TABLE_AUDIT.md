# Figure and Table Audit

Date: 2026-06-09

All manuscript figures and tables are generated from CSV files under `output/final/`. The old partial exhaustive kernel-sensitivity output is not used as a main figure.

## Figures

| Item | Figure file | Source CSV | Status |
|---|---|---|---|
| Figure 1 | `output/final/figures/fig1_alternatives.pdf` | `output/final/data/fig1_alternatives_data.csv` | complete |
| Figure 2 | `output/final/figures/fig2_type1.pdf` | `output/final/data/circular_circular_summary_used.csv` | complete |
| Figure 3 | `output/final/figures/fig3_power.pdf` | `output/final/data/circular_circular_summary_used.csv` | complete |
| Figure 4 | `output/final/figures/fig4_strategy_comparison.pdf` | `output/final/data/circular_circular_summary_used.csv` | complete |
| Figure 5 | `output/final/figures/fig5_kappa_sensitivity.pdf` | `output/final/data/kappa_sensitivity_summary_used.csv` | complete |
| Figure 6 | `output/final/figures/fig6_circular_linear.pdf` | `output/final/data/circular_linear_summary_used.csv` | complete |
| Figure 7 | `output/final/figures/fig7_noshiro_torus.pdf` | `output/final/data/fig7_noshiro_angles.csv` | complete |

Figure 8 is not used in the manuscript because Noshiro grid p-values are all equal to the minimum attainable p-value `0.001`.

## Tables

| Item | Table file | Source CSV | Status |
|---|---|---|---|
| Table 1 | `output/final/tables/table1_type1_summary.tex` | `output/final/tables/table1_type1_summary.csv` | complete |
| Table 2 | `output/final/tables/table2_selected_power.tex` | `output/final/tables/table2_selected_power.csv` | complete |
| Table 3 | `output/final/tables/table3_strategy_comparison.tex` | `output/final/tables/table3_strategy_comparison.csv` | complete |
| Table 4 | `output/final/tables/table6_torus_demo.tex` | `output/final/tables/table6_torus_demo.csv` | complete |
| Table 5 | `output/final/tables/table5_runtime_benchmark.tex` | `output/final/tables/table5_runtime_benchmark.csv` | complete |
| Table 6 | `output/final/tables/table4_noshiro_p_values.tex` | `output/final/tables/table4_noshiro_p_values.csv` | complete |

## Notes

- Captions state the relevant `R`, `B`, and `alpha` values where applicable.
- Table 3 is descriptive and does not claim uniform superiority.
- Table 6 states the minimum attainable add-one p-value for `B = 999`.
