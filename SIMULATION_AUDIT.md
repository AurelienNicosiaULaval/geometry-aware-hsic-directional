# Simulation Audit

Date: 2026-06-09

## Status

The main simulation outputs used in the manuscript are complete for the chosen pre-submission design:

- sample sizes: `n = 50, 100, 200`;
- Monte Carlo repetitions: `R = 500`;
- random permutations: `B = 499`;
- nominal level: `alpha = 0.05`;
- base seed: `20260606`;
- multi-scale grid: `0.5, 1, 2, 4, 8, 16, 32`.

The full larger design `n = 500`, `R = 1000`, `B = 999` was not run. The manuscript now states the actual design and notes only that larger runs are possible with the scripts.

## Main CSV Outputs

- `output/final/null_raw.csv`
- `output/final/null_summary.csv`
- `output/final/power_raw.csv`
- `output/final/power_summary.csv`
- `output/final/circular_linear_raw.csv`
- `output/final/circular_linear_summary.csv`
- `output/final/reduced_sensitivity_raw.csv`
- `output/final/reduced_sensitivity_summary.csv`
- `output/final/torus_demo_raw.csv`
- `output/final/torus_demo_summary.csv`
- `output/final/runtime_benchmark_raw.csv`
- `output/final/runtime_benchmark_summary.csv`
- `output/final/noshiro_summary.csv`
- `output/final/noshiro_kappa_sensitivity.csv`

## Circular-Circular Null Calibration

Null scenarios:

- `N1_uniform_uniform`;
- `N2_vonmises_vonmises`;
- `N3_uniform_vonmises`;
- `N4_mixture_mixture`.

Across all null scenarios and implemented methods, rejection rates range from `0.028` to `0.072`. This is compatible with the nominal level at the Monte Carlo resolution of `R = 500`.

## Circular-Circular Alternatives

Alternative scenarios:

- `A1_shift`;
- `A2_double_angle`;
- `A3_axial`;
- `A4_multimodal`;
- `A5_local_dependence`;
- `A6_symmetric_nonlinear`.

Noise concentration values are `1, 2, 4, 8`. The axial and multimodal alternatives show the clearest scale sensitivity. At `n = 200` and concentration `8`, the standardized multi-scale procedure has rejection rate `1.000` for both axial and multimodal alternatives, while the median heuristic has rejection rates `0.124` and `0.042`.

## Circular-Linear Simulations

Scenarios:

- `L0_independent`;
- `L1_cos`;
- `L2_cos2`;
- `L3_multivariate`;
- `L4_local`.

Linear noise standard deviations are `0.3, 0.5, 0.7, 1.0`. Under `L0_independent`, rejection rates range from `0.042` to `0.062`.

## Reduced Kernel Sensitivity

The reduced sensitivity study is complete for:

- `N1_uniform_uniform`;
- `A3_axial`;
- `A4_multimodal`;
- `A6_symmetric_nonlinear`;
- `n = 100`;
- `R = 500`;
- `B = 499`;
- fixed concentration grid `0.5, 1, 2, 4, 8, 16, 32`.

The old exhaustive fixed-grid sensitivity file is treated as a diagnostic and is not used as a main manuscript figure.

## Torus Demonstration

The torus demonstration is complete for:

- `T0_independent`;
- `T1_coordinate_coupled`;
- `n = 100, 200`;
- `R = 250`;
- `B = 299`.

The independent torus rejection rates are `0.072` and `0.056`; the coordinate-coupled alternative rejection rates are `1.000` at both sample sizes. This is presented as a computational demonstration only.

## Runtime Benchmark

The runtime benchmark uses:

- methods: HSIC fixed, HSIC median, HSIC standardized multi-scale;
- `n = 50, 100, 200`;
- `B = 199`;
- 20 timing repetitions per configuration.

The largest median elapsed time is `4.335` seconds for multi-scale HSIC at `n = 200` on the recorded machine.

The recorded benchmark environment is Darwin 25.5.0 on arm64 with 14 logical cores available. The timing loop is sequential for each test call.

## Remaining Risks

- The simulation design does not include `n = 500`, `R = 1000`, `B = 999`.
- Comparators are diagnostics, not a comprehensive implementation of all recent circular independence tests.
- The torus simulation is a demonstration and not a full toroidal simulation study.
- All conclusions should remain scenario-specific.
