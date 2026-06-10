# Circular-circular simulation scenarios for the compact paper.

rvonmises_base <- function(n, mu = 0, kappa = 1) {
  check_positive_scalar(kappa, "kappa")
  if (requireNamespace("circular", quietly = TRUE)) {
    return(as.numeric(circular::rvonmises(n, mu = circular::circular(mu), kappa = kappa)))
  }
  a <- 1 + sqrt(1 + 4 * kappa^2)
  b <- (a - sqrt(2 * a)) / (2 * kappa)
  r <- (1 + b^2) / (2 * b)
  out <- numeric(n)
  i <- 1L
  while (i <= n) {
    u <- stats::runif(3)
    z <- cos(pi * u[1])
    f <- (1 + r * z) / (r + z)
    cval <- kappa * (r - f)
    if (cval * (2 - cval) - u[2] > 0 || log(cval / u[2]) + 1 - cval >= 0) {
      out[i] <- wrap_angle(mu + ifelse(u[3] > 0.5, 1, -1) * acos(f))
      i <- i + 1L
    }
  }
  out
}

rvm_mix <- function(n, mu = c(0, pi), kappa = c(3, 3), prob = NULL) {
  if (is.null(prob)) prob <- rep(1 / length(mu), length(mu))
  comp <- sample(seq_along(mu), n, replace = TRUE, prob = prob)
  out <- numeric(n)
  for (j in seq_along(mu)) {
    idx <- which(comp == j)
    if (length(idx) > 0L) out[idx] <- rvonmises_base(length(idx), mu[j], kappa[j])
  }
  out
}

rmargin <- function(n, kind) {
  switch(
    kind,
    uniform = stats::runif(n, 0, two_pi()),
    vonmises = rvonmises_base(n, mu = pi / 3, kappa = 3),
    mixture = rvm_mix(n, mu = c(0, pi), kappa = c(5, 5)),
    stop("Unknown marginal kind.", call. = FALSE)
  )
}

sim_null_circ <- function(n, scenario, seed = NULL) {
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  if (scenario == "N1_uniform_uniform") {
    theta <- rmargin(n, "uniform"); phi <- rmargin(n, "uniform")
  } else if (scenario == "N2_vonmises_vonmises") {
    theta <- rmargin(n, "vonmises"); phi <- rvonmises_base(n, mu = 2, kappa = 4)
  } else if (scenario == "N3_uniform_vonmises") {
    theta <- rmargin(n, "uniform"); phi <- rmargin(n, "vonmises")
  } else if (scenario == "N4_mixture_mixture") {
    theta <- rmargin(n, "mixture"); phi <- rvm_mix(n, mu = c(pi / 2, 3 * pi / 2), kappa = c(4, 4))
  } else {
    stop("Unknown null scenario.", call. = FALSE)
  }
  data.frame(theta = theta, phi = phi, scenario = scenario, class = "null")
}

sim_alt_circ <- function(n, scenario, kappa_noise = 4, seed = NULL) {
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  theta <- stats::runif(n, 0, two_pi())
  eps <- rvonmises_base(n, 0, kappa_noise)
  if (scenario == "A1_shift") {
    phi <- wrap_angle(theta + eps)
  } else if (scenario == "A2_double_angle") {
    phi <- wrap_angle(2 * theta + eps)
  } else if (scenario == "A3_axial") {
    phi <- wrap_angle(theta + stats::rbinom(n, 1, 0.5) * pi + eps)
  } else if (scenario == "A4_multimodal") {
    phi <- wrap_angle(theta + sample(c(0, 2 * pi / 3, 4 * pi / 3), n, TRUE) + eps)
  } else if (scenario == "A5_local_dependence") {
    phi <- stats::runif(n, 0, two_pi())
    idx <- theta <= pi
    phi[idx] <- wrap_angle(theta[idx] + rvonmises_base(sum(idx), 0, kappa_noise))
  } else if (scenario == "A6_symmetric_nonlinear") {
    phi <- wrap_angle(theta + 0.9 * sin(2 * theta) + eps)
  } else {
    stop("Unknown alternative scenario.", call. = FALSE)
  }
  data.frame(theta = theta, phi = phi, scenario = scenario, class = "alternative",
             kappa_noise = kappa_noise)
}

example_alternatives <- function(n = 400, kappa_noise = 8, seed = 1) {
  scenarios <- c("A1_shift", "A2_double_angle", "A3_axial", "A4_multimodal",
                 "A5_local_dependence", "A6_symmetric_nonlinear")
  out <- lapply(seq_along(scenarios), function(i) {
    sim_alt_circ(n, scenarios[i], kappa_noise, seed + i)
  })
  do.call(rbind, out)
}
