# Final figure and table traceability

Status checked on 2026-06-09. All paths are relative to the repository root.

| Manuscript item | Output file used | Source CSV | Generating script | Status |
|---|---|---|---|---|
| Figure 1 | `output/final/figures/fig1_alternatives.pdf` | `output/final/data/fig1_alternatives_data.csv` | `R/10_make_figures_tables.R` | Present |
| Figure 2 | `output/final/figures/fig2_type1.pdf` | `output/final/data/circular_circular_summary_used.csv`; upstream `output/final/null_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Figure 3 | `output/final/figures/fig3_power.pdf` | `output/final/data/circular_circular_summary_used.csv`; upstream `output/final/power_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Figure 4 | `output/final/figures/fig4_strategy_comparison.pdf` | `output/final/data/circular_circular_summary_used.csv`; upstream `output/final/power_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Figure 5 | `output/final/figures/fig5_kappa_sensitivity.pdf` | `output/final/data/kappa_sensitivity_summary_used.csv`; upstream `output/final/reduced_sensitivity_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/12_run_reduced_sensitivity.R` | Present |
| Figure 6 | `output/final/figures/fig6_circular_linear.pdf` | `output/final/data/circular_linear_summary_used.csv`; upstream `output/final/circular_linear_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Figure 7 | `output/final/figures/fig7_noshiro_torus.pdf` | `output/final/data/fig7_noshiro_angles.csv`; upstream `data/noshiro.csv` | `R/10_make_figures_tables.R`; upstream `R/11_noshiro_final.R` | Present |
| Table 1 | `output/final/tables/table1_type1_summary.tex` | `output/final/tables/table1_type1_summary.csv`; upstream `output/final/null_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Table 2 | `output/final/tables/table2_selected_power.tex` | `output/final/tables/table2_selected_power.csv`; upstream `output/final/power_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Table 3 | `output/final/tables/table3_strategy_comparison.tex` | `output/final/tables/table3_strategy_comparison.csv`; upstream `output/final/power_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/09_final_simulation_runner.R` | Present |
| Table 4, torus demonstration | `output/final/tables/table6_torus_demo.tex` | `output/final/tables/table6_torus_demo.csv`; upstream `output/final/torus_demo_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/13_run_torus_demo.R` | Present. Historical filename differs from manuscript table number. |
| Table 5, runtime benchmark | `output/final/tables/table5_runtime_benchmark.tex` | `output/final/tables/table5_runtime_benchmark.csv`; upstream `output/final/runtime_benchmark_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/14_benchmark_runtime.R` | Present |
| Table 6, Noshiro p-values | `output/final/tables/table4_noshiro_p_values.tex` | `output/final/tables/table4_noshiro_p_values.csv`; upstream `output/final/noshiro_summary.csv` | `R/10_make_figures_tables.R`; upstream `R/11_noshiro_final.R` | Present. Historical filename differs from manuscript table number. |

LaTeX label check from `main.aux`:

- `tab:type1` is Table 1.
- `tab:selected-power` is Table 2.
- `tab:strategy` is Table 3.
- `tab:torus-demo` is Table 4.
- `tab:runtime` is Table 5.
- `tab:noshiro` is Table 6.
