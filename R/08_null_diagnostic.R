# Diagnostic null simulations for permutation calibration.
# These results are preliminary and must not be used as final manuscript evidence.

args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."),
                mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(project_dir, "R", "00_helpers.R"))
load_compact_sources(project_dir)

dir.create(file.path(project_dir, "output"), recursive = TRUE, showWarnings = FALSE)

set.seed(20260606)
n_values <- c(50L, 100L)
R <- 100L
B <- 199L
alpha <- 0.05
grid <- c(0.5, 2, 8)
scenarios <- c(
  "N1_uniform_uniform",
  "N2_vonmises_vonmises",
  "N3_uniform_vonmises",
  "N4_mixture_mixture"
)
cores <- parallel_cores(default = 1L)

run_methods <- function(theta, phi, B, seed) {
  fixed <- circ_circ_hsic_test(
    theta, phi,
    kappa_theta = 2,
    kappa_phi = 2,
    B = B,
    seed = seed + 1L
  )
  median <- circ_circ_hsic_test(theta, phi, B = B, seed = seed + 2L)
  multi <- circ_circ_hsic_multiscale_test(
    theta, phi,
    grid_theta = grid,
    grid_phi = grid,
    B = B,
    seed = seed + 3L,
    return_grid = TRUE,
    return_permutations = FALSE
  )
  naive <- naive_angle_hsic_test(theta, phi, B = B, seed = seed + 4L)
  trig <- trig_moment_test(theta, phi, B = B, seed = seed + 5L)

  data.frame(
    method = c(
      fixed$method,
      median$method,
      multi$method,
      naive$method,
      trig$method
    ),
    statistic = c(
      fixed$statistic,
      median$statistic,
      multi$statistic,
      naive$statistic,
      trig$statistic
    ),
    p.value = c(
      fixed$p.value,
      median$p.value,
      multi$p.value,
      naive$p.value,
      trig$p.value
    ),
    retained_grid_points = c(NA_integer_, NA_integer_, nrow(multi$retained_grid),
                             NA_integer_, NA_integer_),
    permutation_maxima = c(NA_integer_, NA_integer_,
                           length(multi$permutation_maxima),
                           NA_integer_, NA_integer_)
  )
}

tasks <- expand.grid(
  scenario = scenarios,
  n = n_values,
  repetition = seq_len(R),
  stringsAsFactors = FALSE
)

message(sprintf(
  "Running null diagnostic: %d tasks, R=%d, B=%d, cores=%d",
  nrow(tasks), R, B, cores
))

records <- parallel_lapply(seq_len(nrow(tasks)), function(i) {
  task <- tasks[i, ]
  seed <- 5000000L +
    10000L * match(task$scenario, scenarios) +
    100L * task$n +
    task$repetition
  dat <- sim_null_circ(task$n, task$scenario, seed = seed)
  out <- run_methods(dat$theta, dat$phi, B = B, seed = seed)
  out$scenario <- task$scenario
  out$n <- task$n
  out$repetition <- task$repetition
  out$B <- B
  out$alpha <- alpha
  out
}, cores = cores)

raw <- do.call(rbind, records)
raw$reject <- raw$p.value <= alpha

summary <- summarise_rejections(raw, c("scenario", "n", "method"), alpha = alpha)
summary$B <- B
summary$alpha <- alpha
summary$diagnostic_R <- R
summary$inflation_threshold <- pmax(0.10, alpha + 3 * summary$mc_error)
summary$warning_flag <- summary$rejection_rate > summary$inflation_threshold

write_csv(raw, file.path(project_dir, "output", "null_diagnostic_raw.csv"))
write_csv(summary, file.path(project_dir, "output", "null_diagnostic_summary.csv"))

message("Diagnostic null outputs written.")
