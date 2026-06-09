# Circular-linear simulation scenarios for the compact paper.

sim_circ_linear <- function(n, scenario, noise_sd = 0.5, seed = NULL) {
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  check_positive_scalar(noise_sd, "noise_sd")
  theta <- stats::runif(n, 0, two_pi())
  eta <- stats::rnorm(n, sd = noise_sd)
  if (scenario == "L0_independent") {
    X <- matrix(stats::rnorm(n), ncol = 1)
  } else if (scenario == "L1_cos") {
    X <- matrix(1 + cos(theta - pi / 4) + eta, ncol = 1)
  } else if (scenario == "L2_cos2") {
    X <- matrix(cos(2 * theta) + eta, ncol = 1)
  } else if (scenario == "L3_multivariate") {
    X <- cbind(cos(theta), sin(theta), cos(2 * theta), sin(2 * theta)) +
      matrix(stats::rnorm(4 * n, sd = noise_sd), ncol = 4)
  } else if (scenario == "L4_local") {
    mu <- ifelse(theta <= pi / 2, 1.5, 0)
    X <- matrix(mu + eta, ncol = 1)
  } else {
    stop("Unknown circular-linear scenario.", call. = FALSE)
  }
  list(theta = theta, X = X, scenario = scenario, noise_sd = noise_sd)
}
