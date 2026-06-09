# Kernels, HSIC statistics and permutation tests.

wrap_angle <- function(theta) {
  check_numeric_vector(theta, "theta")
  theta %% two_pi()
}

circ_dist <- function(theta1, theta2) {
  check_numeric_vector(theta1, "theta1")
  check_numeric_vector(theta2, "theta2")
  delta <- abs(outer(wrap_angle(theta1), wrap_angle(theta2), "-"))
  pmin(delta, two_pi() - delta)
}

vm_kernel <- function(theta, kappa) {
  check_numeric_vector(theta, "theta")
  check_positive_scalar(kappa, "kappa")
  K <- exp(kappa * cos(outer(theta, theta, "-")))
  K <- (K + t(K)) / 2
  attr(K, "kappa") <- kappa
  K
}

torus_vm_kernel <- function(theta_mat, kappa_vec) {
  theta_mat <- check_numeric_matrix(theta_mat, "theta_mat")
  if (!is.numeric(kappa_vec) || length(kappa_vec) != ncol(theta_mat) ||
      any(!is.finite(kappa_vec)) || any(kappa_vec <= 0)) {
    stop("`kappa_vec` must be a positive vector matching the number of torus coordinates.",
         call. = FALSE)
  }
  S <- matrix(0, nrow(theta_mat), nrow(theta_mat))
  for (j in seq_len(ncol(theta_mat))) {
    S <- S + kappa_vec[j] * cos(outer(theta_mat[, j], theta_mat[, j], "-"))
  }
  K <- exp(S)
  K <- (K + t(K)) / 2
  attr(K, "kappa_vec") <- kappa_vec
  K
}

gaussian_kernel <- function(X, sigma) {
  X <- check_numeric_matrix(X, "X")
  check_positive_scalar(sigma, "sigma")
  sq <- outer(rowSums(X^2), rowSums(X^2), "+") - 2 * tcrossprod(X)
  K <- exp(-pmax(sq, 0) / (2 * sigma^2))
  K <- (K + t(K)) / 2
  attr(K, "sigma") <- sigma
  K
}

center_gram <- function(K) {
  K <- check_square_matrix(K, "K")
  n <- nrow(K)
  H <- diag(n) - matrix(1 / n, n, n)
  Kc <- H %*% K %*% H
  (Kc + t(Kc)) / 2
}

hsic_biased <- function(K, L) {
  K <- check_square_matrix(K, "K")
  L <- check_square_matrix(L, "L")
  if (nrow(K) != nrow(L)) {
    stop("`K` and `L` must have the same dimension.", call. = FALSE)
  }
  val <- sum(center_gram(K) * center_gram(L)) / nrow(K)^2
  if (val < 0 && abs(val) <= 1e-12) val <- 0
  if (val < -1e-10) {
    warning("Biased HSIC is negative beyond numerical tolerance.", call. = FALSE)
  }
  val
}

hsic_biased_centered <- function(Kc, Lc) {
  Kc <- check_square_matrix(Kc, "Kc")
  Lc <- check_square_matrix(Lc, "Lc")
  if (nrow(Kc) != nrow(Lc)) {
    stop("`Kc` and `Lc` must have the same dimension.", call. = FALSE)
  }
  val <- sum(Kc * Lc) / nrow(Kc)^2
  if (val < 0 && abs(val) <= 1e-12) val <- 0
  val
}

permute_gram <- function(K, idx) {
  K[idx, idx, drop = FALSE]
}

perm_hsic_single <- function(K, L, B, seed = NULL) {
  K <- check_square_matrix(K, "K")
  L <- check_square_matrix(L, "L")
  if (nrow(K) != nrow(L)) {
    stop("`K` and `L` must have the same dimension.", call. = FALSE)
  }
  B <- check_positive_integer(B, "B")
  n <- nrow(K)
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)

  Kc <- center_gram(K)
  Lc <- center_gram(L)
  observed <- hsic_biased_centered(Kc, Lc)
  permutations <- numeric(B)
  for (b in seq_len(B)) {
    idx <- sample.int(n)
    permutations[b] <- hsic_biased_centered(Kc, permute_gram(Lc, idx))
  }
  p_value <- (1 + sum(permutations >= observed)) / (B + 1)
  list(
    statistic = observed,
    p.value = p_value,
    B = B,
    n = n,
    permutations = permutations
  )
}

select_kappa_fixed <- function(fixed = 1, ...) {
  check_positive_scalar(fixed, "fixed")
  fixed
}

select_kappa_median <- function(theta, min_kappa = 0.05, max_kappa = 100, ...) {
  check_numeric_vector(theta, "theta")
  check_positive_scalar(min_kappa, "min_kappa")
  check_positive_scalar(max_kappa, "max_kappa")
  if (min_kappa > max_kappa) {
    stop("`min_kappa` must be no larger than `max_kappa`.", call. = FALSE)
  }
  d <- circ_dist(theta, theta)
  d <- d[upper.tri(d)]
  d <- d[d > 1e-8]
  if (length(d) == 0L) return(1)
  max(min_kappa, min(max_kappa, 1 / stats::median(d)^2))
}

select_kappa <- function(theta, value = "median") {
  if (is.numeric(value)) return(select_kappa_fixed(value))
  if (!identical(value, "median")) {
    stop("Kappa must be numeric or 'median'.", call. = FALSE)
  }
  select_kappa_median(theta)
}

select_sigma <- function(X, value = "median", min_sigma = 0.05) {
  X <- check_numeric_matrix(X, "X")
  if (is.numeric(value)) {
    check_positive_scalar(value, "sigma")
    return(value)
  }
  if (!identical(value, "median")) {
    stop("Sigma must be numeric or 'median'.", call. = FALSE)
  }
  d <- as.numeric(stats::dist(X))
  d <- d[d > 1e-8]
  if (length(d) == 0L) return(1)
  max(min_sigma, stats::median(d))
}

validate_gram_list <- function(K_list, name) {
  if (!is.list(K_list) || length(K_list) == 0L) {
    stop(sprintf("`%s` must be a non-empty list of Gram matrices.", name),
         call. = FALSE)
  }
  K_list <- lapply(seq_along(K_list), function(i) {
    check_square_matrix(K_list[[i]], sprintf("%s[[%d]]", name, i))
  })
  ns <- vapply(K_list, nrow, integer(1))
  if (length(unique(ns)) != 1L) {
    stop(sprintf("All matrices in `%s` must have the same dimension.", name),
         call. = FALSE)
  }
  if (is.null(names(K_list))) names(K_list) <- as.character(seq_along(K_list))
  K_list
}

perm_hsic_multiscale <- function(K_list, L_list, B, seed = NULL) {
  K_list <- validate_gram_list(K_list, "K_list")
  L_list <- validate_gram_list(L_list, "L_list")
  if (nrow(K_list[[1L]]) != nrow(L_list[[1L]])) {
    stop("Matrices in `K_list` and `L_list` must have the same dimension.",
         call. = FALSE)
  }
  B <- check_positive_integer(B, "B")
  n <- nrow(K_list[[1L]])
  Kc_list <- lapply(K_list, center_gram)
  Lc_list <- lapply(L_list, center_gram)
  grid <- expand.grid(
    K_index = seq_along(Kc_list),
    L_index = seq_along(Lc_list),
    stringsAsFactors = FALSE
  )
  grid$K_name <- names(K_list)[grid$K_index]
  grid$L_name <- names(L_list)[grid$L_index]

  observed <- vapply(seq_len(nrow(grid)), function(g) {
    hsic_biased_centered(Kc_list[[grid$K_index[g]]], Lc_list[[grid$L_index[g]]])
  }, numeric(1))

  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  perm_stats <- matrix(NA_real_, nrow = B, ncol = nrow(grid))
  for (b in seq_len(B)) {
    idx <- sample.int(n)
    for (g in seq_len(nrow(grid))) {
      perm_stats[b, g] <- hsic_biased_centered(
        Kc_list[[grid$K_index[g]]],
        permute_gram(Lc_list[[grid$L_index[g]]], idx)
      )
    }
  }

  all_stats <- rbind(observed, perm_stats)
  pooled_mean <- colMeans(all_stats)
  pooled_sd <- apply(all_stats, 2, stats::sd)
  eps_sd <- 1e-12 * max(1, max(pooled_sd, na.rm = TRUE))
  retained <- which(pooled_sd >= eps_sd)
  if (length(retained) == 0L) {
    return(list(
      statistic = NA_real_,
      p.value = NA_real_,
      method = "HSIC standardized multi-scale",
      B = B,
      n = n,
      grid = grid,
      retained_grid = grid[FALSE, ],
      observed_grid = observed,
      pooled_mean_grid = pooled_mean,
      pooled_sd_grid = pooled_sd,
      null_mean_grid = pooled_mean,
      null_sd_grid = pooled_sd,
      standardized_grid = rep(NA_real_, length(observed)),
      permutation_maxima = rep(NA_real_, B),
      all_maxima = rep(NA_real_, B + 1L),
      permutations = perm_stats,
      all_statistics = all_stats,
      sd_threshold = eps_sd
    ))
  }

  obs_z <- rep(NA_real_, length(observed))
  all_z <- matrix(NA_real_, nrow = B + 1L, ncol = nrow(grid))
  all_z[, retained] <- sweep(
    sweep(all_stats[, retained, drop = FALSE], 2, pooled_mean[retained], "-"),
    2, pooled_sd[retained], "/"
  )
  obs_z[retained] <- all_z[1L, retained]
  all_maxima <- apply(all_z[, retained, drop = FALSE], 1, max)
  observed_max <- all_maxima[1L]
  permutation_maxima <- all_maxima[-1L]
  p_value <- mean(all_maxima >= observed_max)

  list(
    statistic = observed_max,
    p.value = p_value,
    method = "HSIC standardized multi-scale",
    B = B,
    n = n,
    grid = grid,
    retained_grid = grid[retained, ],
    observed_grid = observed,
    pooled_mean_grid = pooled_mean,
    pooled_sd_grid = pooled_sd,
    null_mean_grid = pooled_mean,
    null_sd_grid = pooled_sd,
    standardized_grid = obs_z,
    permutation_maxima = permutation_maxima,
    all_maxima = all_maxima,
    permutations = perm_stats,
    all_statistics = all_stats,
    sd_threshold = eps_sd
  )
}

circ_circ_hsic_test <- function(theta, phi, kappa_theta = "median",
                                kappa_phi = "median", B = 999, seed = NULL,
                                return_permutations = FALSE) {
  assert_same_n(theta, phi)
  k1 <- select_kappa(theta, kappa_theta)
  k2 <- select_kappa(phi, kappa_phi)
  out <- perm_hsic_single(vm_kernel(theta, k1), vm_kernel(phi, k2), B = B, seed = seed)
  out$method <- if (identical(kappa_theta, "median") || identical(kappa_phi, "median")) {
    "HSIC median"
  } else {
    "HSIC fixed"
  }
  out$kappa_theta <- k1
  out$kappa_phi <- k2
  if (!return_permutations) out$permutations <- NULL
  out
}

circ_linear_hsic_test <- function(theta, X, kappa_theta = "median",
                                  sigma = "median", B = 999, seed = NULL,
                                  return_permutations = FALSE) {
  theta <- check_numeric_vector(theta, "theta")
  X <- check_numeric_matrix(X, "X")
  if (length(theta) != nrow(X)) {
    stop("`theta` and `X` must have the same number of observations.",
         call. = FALSE)
  }
  k <- select_kappa(theta, kappa_theta)
  s <- select_sigma(X, sigma)
  out <- perm_hsic_single(vm_kernel(theta, k), gaussian_kernel(X, s), B = B, seed = seed)
  out$method <- "HSIC circular-linear"
  out$kappa_theta <- k
  out$sigma <- s
  if (!return_permutations) out$permutations <- NULL
  out
}

circ_circ_hsic_multiscale_test <- function(theta, phi, grid_theta, grid_phi,
                                           B = 999, seed = NULL,
                                           return_grid = TRUE,
                                           return_permutations = FALSE) {
  assert_same_n(theta, phi)
  grid_theta <- sort(unique(as.numeric(grid_theta)))
  grid_phi <- sort(unique(as.numeric(grid_phi)))
  if (any(!is.finite(grid_theta)) || any(grid_theta <= 0) ||
      any(!is.finite(grid_phi)) || any(grid_phi <= 0)) {
    stop("Grids must contain finite positive concentration values.", call. = FALSE)
  }
  K_list <- lapply(grid_theta, function(k) vm_kernel(theta, k))
  L_list <- lapply(grid_phi, function(k) vm_kernel(phi, k))
  names(K_list) <- paste0("kappa_theta=", grid_theta)
  names(L_list) <- paste0("kappa_phi=", grid_phi)
  out <- perm_hsic_multiscale(K_list, L_list, B = B, seed = seed)
  out$grid_theta <- grid_theta
  out$grid_phi <- grid_phi
  if (!return_grid) {
    out$grid <- NULL
    out$retained_grid <- NULL
    out$observed_grid <- NULL
    out$null_mean_grid <- NULL
    out$null_sd_grid <- NULL
    out$standardized_grid <- NULL
  }
  if (!return_permutations) {
    out$permutations <- NULL
  }
  out
}

comparator_result <- function(method, statistic, p.value, target_null,
                              assumptions, input_type, citation,
                              note = NA_character_, ...) {
  out <- list(
    method = method,
    statistic = statistic,
    p.value = p.value,
    target_null = target_null,
    assumptions = assumptions,
    input_type = input_type,
    citation = citation,
    note = note,
    ...
  )
  class(out) <- c("directional_hsic_comparator", class(out))
  out
}

permutation_p_value <- function(observed, permutations) {
  (1 + sum(permutations >= observed)) / (length(permutations) + 1)
}

mean_direction <- function(theta) {
  atan2(mean(sin(theta)), mean(cos(theta)))
}

# Comparator: Jammalamadaka-Sarma circular correlation diagnostic.
# Method name: Jammalamadaka-Sarma circular correlation diagnostic.
# Target null hypothesis: no centered sine circular association.
# Assumptions: paired circular observations, exchangeability for permutation p-values.
# Input type: two numeric angle vectors in radians.
# Output: squared circular correlation statistic and permutation p-value.
# Citation: Jammalamadaka and SenGupta (2001).
js_circular_correlation_test <- function(theta, phi, B = 999, seed = NULL) {
  assert_same_n(theta, phi)
  theta <- wrap_angle(theta)
  phi <- wrap_angle(phi)
  B <- check_positive_integer(B, "B")
  theta_bar <- mean_direction(theta)
  phi_bar <- mean_direction(phi)
  s_theta <- sin(theta - theta_bar)
  s_phi <- sin(phi - phi_bar)
  denom <- sqrt(sum(s_theta^2) * sum(s_phi^2))
  stat_signed <- if (denom <= 0) 0 else sum(s_theta * s_phi) / denom
  observed <- stat_signed^2
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  permutations <- numeric(B)
  for (b in seq_len(B)) {
    idx <- sample.int(length(phi))
    perm_signed <- if (denom <= 0) 0 else sum(s_theta * s_phi[idx]) / denom
    permutations[b] <- perm_signed^2
  }
  comparator_result(
    method = "Jammalamadaka-Sarma circular correlation diagnostic",
    statistic = observed,
    p.value = permutation_p_value(observed, permutations),
    target_null = "No centered sine circular association between two circular variables.",
    assumptions = "Paired angular observations in radians; ordinary permutation p-value assumes exchangeability under independence.",
    input_type = "Two numeric angle vectors in radians.",
    citation = "Jammalamadaka and SenGupta (2001), Topics in Circular Statistics.",
    signed_correlation = stat_signed,
    permutations = permutations
  )
}

# Comparator: Fisher-Lee circular correlation diagnostic.
# Method name: Fisher-Lee circular correlation diagnostic.
# Target null hypothesis: no pairwise sine-difference circular association.
# Assumptions: paired circular observations, exchangeability for permutation p-values.
# Input type: two numeric angle vectors in radians.
# Output: squared Fisher-Lee correlation statistic and permutation p-value.
# Citation: Fisher and Lee (1983); Fisher (1993).
fisher_lee_circular_correlation_test <- function(theta, phi, B = 999, seed = NULL) {
  assert_same_n(theta, phi)
  theta <- wrap_angle(theta)
  phi <- wrap_angle(phi)
  B <- check_positive_integer(B, "B")
  upper <- upper.tri(matrix(0, length(theta), length(theta)))
  s_theta <- sin(outer(theta, theta, "-"))[upper]
  fisher_stat <- function(phi_vec) {
    s_phi <- sin(outer(phi_vec, phi_vec, "-"))[upper]
    denom <- sqrt(sum(s_theta^2) * sum(s_phi^2))
    if (denom <= 0) return(c(signed = 0, squared = 0))
    signed <- sum(s_theta * s_phi) / denom
    c(signed = signed, squared = signed^2)
  }
  obs <- fisher_stat(phi)
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  permutations <- numeric(B)
  for (b in seq_len(B)) {
    idx <- sample.int(length(phi))
    permutations[b] <- fisher_stat(phi[idx])["squared"]
  }
  comparator_result(
    method = "Fisher-Lee circular correlation diagnostic",
    statistic = obs["squared"],
    p.value = permutation_p_value(obs["squared"], permutations),
    target_null = "No pairwise sine-difference circular association between two circular variables.",
    assumptions = "Paired angular observations in radians; ordinary permutation p-value assumes exchangeability under independence.",
    input_type = "Two numeric angle vectors in radians.",
    citation = "Fisher and Lee (1983), Biometrika; Fisher (1993), Statistical Analysis of Circular Data.",
    signed_correlation = obs["signed"],
    permutations = permutations
  )
}

# Comparator: simplified trigonometric moment diagnostic.
# Method name: first-order trigonometric moment diagnostic.
# Target null hypothesis: no first-order association between cosine-sine embeddings.
# Assumptions: paired circular observations, exchangeability for permutation p-values.
# Input type: two numeric angle vectors in radians.
# Output: sum of squared correlations between first-order trigonometric features and
# a permutation p-value.
# Citation: Garcia-Portugues et al. (2024) for trigonometric-moment circular
# independence testing. This implementation is a simplified diagnostic, not the
# full test from that paper.
trig_moment_test <- function(theta, phi, B = 999, seed = NULL) {
  assert_same_n(theta, phi)
  B <- check_positive_integer(B, "B")
  Z <- cbind(cos(theta), sin(theta))
  W <- cbind(cos(phi), sin(phi))
  stat <- sum(stats::cor(Z, W)^2)
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  perm <- replicate(B, sum(stats::cor(Z, W[sample.int(length(phi)), ])^2))
  comparator_result(
    method = "first-order trigonometric moment diagnostic",
    statistic = stat,
    p.value = permutation_p_value(stat, perm),
    target_null = "No first-order trigonometric moment association between two circular variables.",
    assumptions = "Paired angular observations in radians; ordinary permutation p-value assumes exchangeability under independence.",
    input_type = "Two numeric angle vectors in radians.",
    citation = "Garcia-Portugues et al. (2024), Statistica Sinica. Simplified first-order diagnostic only.",
    note = "This is not the full Garcia-Portugues et al. (2024) test.",
    permutations = perm
  )
}

# Comparator: naive Euclidean-angle HSIC anti-example.
# Method name: naive Euclidean-angle HSIC anti-example.
# Target null hypothesis: independence after treating raw angles as Euclidean scalars.
# Assumptions: paired numeric angle observations, exchangeability for permutation p-values.
# Input type: two numeric angle vectors in radians.
# Output: Gaussian-HSIC statistic on raw unwrapped angles and permutation p-value.
# Citation: Gretton et al. (2005, 2008) for HSIC. This is an anti-example
# because it ignores circular periodicity.
naive_angle_hsic_test <- function(theta, phi, B = 999, seed = NULL,
                                  return_permutations = FALSE) {
  assert_same_n(theta, phi)
  out <- perm_hsic_single(
    gaussian_kernel(matrix(theta), select_sigma(matrix(theta))),
    gaussian_kernel(matrix(phi), select_sigma(matrix(phi))),
    B = B,
    seed = seed
  )
  out$method <- "naive Euclidean-angle HSIC anti-example"
  out$target_null <- "Independence after treating raw angles as Euclidean scalars."
  out$assumptions <- "Paired numeric angle observations; ordinary permutation p-value assumes exchangeability under independence."
  out$input_type <- "Two numeric angle vectors in radians, treated as raw real numbers."
  out$citation <- "Gretton et al. (2005, 2008) for HSIC. Used here as an anti-example because it ignores periodicity."
  out$note <- "Not a serious circular-data competitor."
  if (!return_permutations) out$permutations <- NULL
  out
}

comparator_tests_circ_circ <- function(theta, phi, B = 999, seed = NULL,
                                       methods = c("js", "fisher_lee",
                                                   "trig", "naive")) {
  methods <- match.arg(methods, several.ok = TRUE)
  rows <- list()
  seed_at <- function(offset) if (is.null(seed)) NULL else seed + offset
  `%||%` <- function(x, y) if (is.null(x)) y else x
  append_row <- function(test) {
    data.frame(
      method = test$method,
      statistic = test$statistic,
      p.value = test$p.value,
      target_null = test$target_null,
      assumptions = test$assumptions,
      input_type = test$input_type,
      citation = test$citation,
      note = test$note %||% NA_character_,
      stringsAsFactors = FALSE
    )
  }
  if ("js" %in% methods) {
    rows[[length(rows) + 1L]] <- append_row(
      js_circular_correlation_test(theta, phi, B = B, seed = seed_at(1L))
    )
  }
  if ("fisher_lee" %in% methods) {
    rows[[length(rows) + 1L]] <- append_row(
      fisher_lee_circular_correlation_test(theta, phi, B = B, seed = seed_at(2L))
    )
  }
  if ("trig" %in% methods) {
    rows[[length(rows) + 1L]] <- append_row(
      trig_moment_test(theta, phi, B = B, seed = seed_at(3L))
    )
  }
  if ("naive" %in% methods) {
    rows[[length(rows) + 1L]] <- append_row(
      naive_angle_hsic_test(theta, phi, B = B, seed = seed_at(4L))
    )
  }
  do.call(rbind, rows)
}

# Compatibility aliases used by earlier scripts.
circ_kernel_vm <- vm_kernel
torus_kernel_vm <- torus_vm_kernel
center_kernel <- center_gram
permutation_hsic <- perm_hsic_single
