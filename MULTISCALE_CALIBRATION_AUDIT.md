# Multi-scale Calibration Audit

Date: 2026-06-09

## Implemented Method

The implementation in `R/01_kernels_hsic.R` uses permutation-symmetric pooled standardization.

For each grid point `g`, the code computes:

- `T_0(g)`, the observed statistic;
- `T_b(g)`, `b = 1, ..., B`, the permutation statistics;
- pooled mean over `b = 0, ..., B`;
- pooled standard deviation over `b = 0, ..., B`;
- standardized values for the observed and permuted pairings using the same pooled mean and standard deviation;
- maxima over retained grid points for `b = 0, ..., B`.

The p-value is `mean(M_b >= M_0)` over the observed row and the `B` permuted rows.

## Numerical Stability

Grid points are removed when

`pooled_sd_grid < 1e-12 * max(1, max(pooled_sd_grid))`.

If no grid point remains, the function returns `NA` for the statistic and p-value instead of forcing a result.

## Returned Fields

`perm_hsic_multiscale()` returns:

- `statistic`;
- `p.value`;
- `pooled_mean_grid`;
- `pooled_sd_grid`;
- `standardized_grid`;
- `permutation_maxima`;
- `all_maxima`;
- `retained_grid`;
- `sd_threshold`;
- `all_statistics`.

The old aliases `null_mean_grid` and `null_sd_grid` are retained for compatibility and contain the pooled values.

## Tests

`Rscript R/07_smoke_tests.R` passed. The smoke tests check:

- p-values lie in `[0, 1]`;
- `all_maxima` has length `B + 1`;
- pooled means and pooled standard deviations are returned;
- near-zero pooled standard deviation grid points are removed;
- the all-zero-variation case returns undefined p-values.

## Manuscript Status

Section 7 describes the pooled standardization and states that the procedure calibrates the implemented standardized maximum. It does not claim uniformly optimal power.
