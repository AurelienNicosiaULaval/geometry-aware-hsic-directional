args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
source(file.path(project_dir, "R", "00_helpers.R"))
load_compact_sources(project_dir)

set.seed(read_env_int("SEED", 20260606))
R <- read_env_int("SIM_R", 1000)
B <- read_env_int("B_PERM", 999)
n_values <- as.integer(read_env_numvec("N_VALUES", c(50, 100, 200, 500)))
kappa_grid <- read_env_numvec("KAPPA_GRID", c(0.5, 1, 2, 4, 8, 16, 32))
effect_values <- read_env_numvec("KAPPA_NOISE_VALUES", c(0.5, 1, 2, 4, 8))
cores <- parallel_cores(1L)
alpha <- 0.05

dir.create(file.path(project_dir, "output"), showWarnings = FALSE)
dir.create(file.path(project_dir, "tables"), showWarnings = FALSE)

run_circ_methods <- function(theta, phi, B, seed) {
  fixed <- circ_circ_hsic_test(theta, phi, kappa_theta = 2, kappa_phi = 2,
                               B = B, seed = seed + 1L)
  median <- circ_circ_hsic_test(theta, phi, B = B, seed = seed + 2L)
  multi <- circ_circ_hsic_multiscale_test(theta, phi, kappa_grid, kappa_grid,
                                          B = B, seed = seed + 3L)
  trig <- trig_moment_test(theta, phi, B = B, seed = seed + 4L)
  naive <- naive_angle_hsic_test(theta, phi, B = B, seed = seed + 5L)
  data.frame(
    method = c(fixed$method, median$method, multi$method, trig$method, naive$method),
    statistic = c(fixed$statistic, median$statistic, multi$statistic,
                  trig$statistic, naive$statistic),
    p.value = c(fixed$p.value, median$p.value, multi$p.value,
                trig$p.value, naive$p.value)
  )
}

null_scenarios <- c("N1_uniform_uniform", "N2_vonmises_vonmises",
                    "N3_uniform_vonmises", "N4_mixture_mixture")
alt_scenarios <- c("A1_shift", "A2_double_angle", "A3_axial", "A4_multimodal",
                   "A5_local_dependence", "A6_symmetric_nonlinear")

null_tasks <- expand.grid(scenario = null_scenarios, n = n_values,
                          repetition = seq_len(R), stringsAsFactors = FALSE)
alt_tasks <- expand.grid(scenario = alt_scenarios, n = n_values,
                         kappa_noise = effect_values,
                         repetition = seq_len(R), stringsAsFactors = FALSE)

message(sprintf("Circular null tasks: %d | alternative tasks: %d | B=%d | cores=%d",
                nrow(null_tasks), nrow(alt_tasks), B, cores))

null_records <- parallel_lapply(seq_len(nrow(null_tasks)), function(i) {
  task <- null_tasks[i, ]
  seed <- 1000000L + 10000L * match(task$scenario, null_scenarios) +
    100L * task$n + task$repetition
  dat <- sim_null_circ(task$n, task$scenario, seed = seed)
  out <- run_circ_methods(dat$theta, dat$phi, B, seed)
  out$scenario <- task$scenario
  out$n <- task$n
  out$repetition <- task$repetition
  out$kappa_noise <- 0
  out$class <- "null"
  out
}, cores = cores)

alt_records <- parallel_lapply(seq_len(nrow(alt_tasks)), function(i) {
  task <- alt_tasks[i, ]
  seed <- 2000000L + 10000L * match(task$scenario, alt_scenarios) +
    100L * task$n + 10L * round(10 * task$kappa_noise) + task$repetition
  dat <- sim_alt_circ(task$n, task$scenario, task$kappa_noise, seed = seed)
  out <- run_circ_methods(dat$theta, dat$phi, B, seed)
  out$scenario <- task$scenario
  out$n <- task$n
  out$repetition <- task$repetition
  out$kappa_noise <- task$kappa_noise
  out$class <- "alternative"
  out
}, cores = cores)

circ_raw <- do.call(rbind, c(null_records, alt_records))
circ_summary <- summarise_rejections(
  circ_raw,
  c("class", "scenario", "kappa_noise", "n", "method"),
  alpha = alpha
)
circ_summary$B <- B
write_csv(circ_raw, file.path(project_dir, "output", "circular_circular_raw.csv"))
write_csv(circ_summary, file.path(project_dir, "output", "circular_circular_summary.csv"))
write_csv(circ_summary, file.path(project_dir, "tables", "circular_circular_summary.csv"))

cl_scenarios <- c("L0_independent", "L1_cos", "L2_cos2", "L3_multivariate", "L4_local")
noise_values <- read_env_numvec("CL_NOISE_SD_VALUES", c(0.25, 0.5, 1))
cl_tasks <- expand.grid(scenario = cl_scenarios, n = n_values,
                        noise_sd = noise_values, repetition = seq_len(R),
                        stringsAsFactors = FALSE)
message(sprintf("Circular-linear tasks: %d", nrow(cl_tasks)))

cl_records <- parallel_lapply(seq_len(nrow(cl_tasks)), function(i) {
  task <- cl_tasks[i, ]
  seed <- 3000000L + 10000L * match(task$scenario, cl_scenarios) +
    100L * task$n + 10L * round(10 * task$noise_sd) + task$repetition
  dat <- sim_circ_linear(task$n, task$scenario, task$noise_sd, seed = seed)
  hsic <- circ_linear_hsic_test(dat$theta, dat$X, B = B, seed = seed + 1L)
  data.frame(scenario = task$scenario, n = task$n, noise_sd = task$noise_sd,
             repetition = task$repetition, method = hsic$method,
             statistic = hsic$statistic, p.value = hsic$p.value)
}, cores = cores)

cl_raw <- do.call(rbind, cl_records)
cl_summary <- summarise_rejections(cl_raw, c("scenario", "noise_sd", "n", "method"),
                                   alpha = alpha)
cl_summary$B <- B
write_csv(cl_raw, file.path(project_dir, "output", "circular_linear_raw.csv"))
write_csv(cl_summary, file.path(project_dir, "output", "circular_linear_summary.csv"))
write_csv(cl_summary, file.path(project_dir, "tables", "circular_linear_summary.csv"))

kappa_R <- read_env_int("KAPPA_R", min(R, 100L))
kappa_scenarios <- c("A3_axial", "A4_multimodal", "A6_symmetric_nonlinear")
kappa_tasks <- expand.grid(
  scenario = kappa_scenarios,
  n = n_values,
  kappa_theta = kappa_grid,
  kappa_phi = kappa_grid,
  repetition = seq_len(kappa_R),
  stringsAsFactors = FALSE
)
message(sprintf("Kappa sensitivity tasks: %d", nrow(kappa_tasks)))
kappa_records <- parallel_lapply(seq_len(nrow(kappa_tasks)), function(i) {
  task <- kappa_tasks[i, ]
  seed <- 4000000L + 10000L * match(task$scenario, kappa_scenarios) +
    100L * task$n + 10L * round(task$kappa_theta * 10) +
    round(task$kappa_phi * 10) + task$repetition
  dat <- sim_alt_circ(task$n, task$scenario, kappa_noise = 8, seed = seed)
  test <- circ_circ_hsic_test(
    dat$theta, dat$phi,
    kappa_theta = task$kappa_theta,
    kappa_phi = task$kappa_phi,
    B = B,
    seed = seed + 1L
  )
  data.frame(scenario = task$scenario, n = task$n,
             kappa_theta = task$kappa_theta, kappa_phi = task$kappa_phi,
             repetition = task$repetition, method = "HSIC fixed",
             statistic = test$statistic, p.value = test$p.value)
}, cores = cores)
kappa_raw <- do.call(rbind, kappa_records)
kappa_summary <- summarise_rejections(
  kappa_raw,
  c("scenario", "n", "kappa_theta", "kappa_phi", "method"),
  alpha = alpha
)
kappa_summary$B <- B
write_csv(kappa_raw, file.path(project_dir, "output", "kappa_sensitivity_raw.csv"))
write_csv(kappa_summary, file.path(project_dir, "output", "kappa_sensitivity_summary.csv"))
write_csv(kappa_summary, file.path(project_dir, "tables", "kappa_sensitivity_summary.csv"))

message("Simulation outputs written.")
