# Lightweight internal checks for the compact directional HSIC implementation.

args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."),
                mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
source(file.path(project_dir, "R", "00_helpers.R"))
source(file.path(project_dir, "R", "01_kernels_hsic.R"))
source(file.path(project_dir, "R", "02_simulate_circular_circular.R"))
source(file.path(project_dir, "R", "03_simulate_circular_linear.R"))

dir.create(file.path(project_dir, "output"), recursive = TRUE, showWarnings = FALSE)
log_file <- file.path(project_dir, "output", "smoke_test_log.txt")

pass <- function(name) {
  cat(sprintf("[PASS] %s\n", name))
}

check <- function(condition, name) {
  if (!isTRUE(condition)) {
    stop(sprintf("[FAIL] %s", name), call. = FALSE)
  }
  pass(name)
}

sink(log_file)
cat("Smoke test log\n")
cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n\n")

tryCatch({
  set.seed(20260606)
  n <- 80L
  theta <- stats::runif(n, 0, two_pi())
  phi_ind <- stats::runif(n, 0, two_pi())
  phi_dep <- wrap_angle(theta + rvonmises_base(n, 0, kappa = 12))

  K <- vm_kernel(theta, kappa = 2)
  L_ind <- vm_kernel(phi_ind, kappa = 2)
  L_dep <- vm_kernel(phi_dep, kappa = 2)

  check(isTRUE(all.equal(K, t(K), tolerance = 1e-12)), "von Mises kernel symmetry")
  check(max(abs(diag(K) - exp(2))) < 1e-12, "von Mises kernel diagonal equals exp(kappa)")

  X <- cbind(cos(theta), sin(theta))
  G <- gaussian_kernel(X, sigma = 1)
  check(isTRUE(all.equal(G, t(G), tolerance = 1e-12)), "Gaussian kernel symmetry")
  check(max(abs(diag(G) - 1)) < 1e-12, "Gaussian kernel diagonal equals one")

  T_ind <- hsic_biased(K, L_ind)
  T_dep <- hsic_biased(K, L_dep)
  check(T_ind >= -1e-12, "HSIC independent toy value is nonnegative up to tolerance")
  check(T_dep >= -1e-12, "HSIC dependent toy value is nonnegative up to tolerance")
  check(T_dep > T_ind, "HSIC identical/dependent toy value exceeds independent toy value")

  single <- perm_hsic_single(K, L_dep, B = 29, seed = 101)
  check(single$p.value >= 0 && single$p.value <= 1, "single-scale p-value is in [0, 1]")
  check(length(single$permutations) == 29L, "single-scale stores permutation statistics")

  grid <- c(0.5, 2, 8)
  K_list <- lapply(grid, function(k) vm_kernel(theta, k))
  L_list <- lapply(grid, function(k) vm_kernel(phi_dep, k))
  names(K_list) <- paste0("theta_", grid)
  names(L_list) <- paste0("phi_", grid)
  multi <- perm_hsic_multiscale(K_list, L_list, B = 29, seed = 202)

  check(multi$p.value >= 0 && multi$p.value <= 1, "multi-scale p-value is in [0, 1]")
  check(nrow(multi$grid) == length(grid)^2, "multi-scale returns full grid information")
  check(nrow(multi$retained_grid) > 0, "multi-scale retains at least one grid point")
  check(length(multi$permutation_maxima) == 29L, "multi-scale returns permutation maxima")
  check(length(multi$all_maxima) == 30L, "multi-scale returns observed plus permutation maxima")
  check(ncol(multi$permutations) == length(grid)^2, "multi-scale returns grid permutation matrix")
  check(length(multi$pooled_mean_grid) == length(grid)^2, "multi-scale returns pooled means")
  check(length(multi$pooled_sd_grid) == length(grid)^2, "multi-scale returns pooled standard deviations")

  constant_list <- list(constant = matrix(1, nrow = 12, ncol = 12))
  constant_multi <- perm_hsic_multiscale(constant_list, constant_list, B = 9, seed = 505)
  check(is.na(constant_multi$p.value), "multi-scale returns undefined p-value when all pooled sd values are near zero")
  check(nrow(constant_multi$retained_grid) == 0L, "multi-scale drops all near-zero sd grid points")

  torus_angles <- cbind(theta, phi_dep)
  TK <- torus_vm_kernel(torus_angles, c(1, 3))
  check(isTRUE(all.equal(TK, t(TK), tolerance = 1e-12)), "torus von Mises kernel symmetry")
  check(max(abs(diag(TK) - exp(4))) < 1e-12, "torus von Mises diagonal equals exp(sum kappa)")

  cl <- sim_circ_linear(n = 60, scenario = "L1_cos", noise_sd = 0.5, seed = 303)
  cl_test <- circ_linear_hsic_test(cl$theta, cl$X, B = 19, seed = 404)
  check(cl_test$p.value >= 0 && cl_test$p.value <= 1, "circular-linear p-value is in [0, 1]")

  cat("\nAll smoke tests passed.\n")
}, error = function(e) {
  cat(conditionMessage(e), "\n")
  sink()
  stop(e)
})

sink()
cat(sprintf("Smoke tests passed. Log written to %s\n", log_file))
