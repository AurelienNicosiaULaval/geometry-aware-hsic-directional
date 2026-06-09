args <- commandArgs(FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."), mustWork = TRUE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
source(file.path(project_dir, "R", "00_helpers.R"))
load_compact_sources(project_dir)

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Package `ggplot2` is required for Noshiro figures.", call. = FALSE)
}

B <- read_env_int("NOSHIRO_B", read_env_int("B_PERM", 999))
grid <- read_env_numvec("KAPPA_GRID", c(0.5, 1, 2, 4, 8, 16, 32))
seed <- read_env_int("SEED", 20260606)
data_file <- file.path(project_dir, "data", "noshiro.csv")

if (!file.exists(data_file)) {
  message("Noshiro data unavailable. Add data/noshiro.csv before running this analysis.")
  quit(save = "no", status = 0)
}

dat <- utils::read.csv(data_file, stringsAsFactors = FALSE)
cols <- if (all(c("DIRDSC", "DIRMV") %in% names(dat))) {
  c("DIRDSC", "DIRMV")
} else if (all(c("theta1", "theta2") %in% names(dat))) {
  c("theta1", "theta2")
} else {
  stop("Noshiro data must contain DIRDSC/DIRMV or theta1/theta2.", call. = FALSE)
}

theta <- as.numeric(dat[[cols[1]]])
phi <- as.numeric(dat[[cols[2]]])
keep <- stats::complete.cases(theta, phi)
theta <- theta[keep]
phi <- phi[keep]
if (max(abs(theta), abs(phi), na.rm = TRUE) > two_pi() + 1e-8 &&
    max(abs(theta), abs(phi), na.rm = TRUE) <= 360 + 1e-8) {
  theta <- theta * pi / 180
  phi <- phi * pi / 180
}
theta <- wrap_angle(theta)
phi <- wrap_angle(phi)

fixed <- circ_circ_hsic_test(theta, phi, kappa_theta = 2, kappa_phi = 2,
                             B = B, seed = seed + 1L)
median <- circ_circ_hsic_test(theta, phi, B = B, seed = seed + 2L)
multi <- circ_circ_hsic_multiscale_test(theta, phi, grid, grid, B = B,
                                        seed = seed + 3L)
trig <- trig_moment_test(theta, phi, B = B, seed = seed + 4L)
naive <- naive_angle_hsic_test(theta, phi, B = B, seed = seed + 5L)
tab <- data.frame(
  method = c(fixed$method, median$method, multi$method, trig$method, naive$method),
  statistic = c(fixed$statistic, median$statistic, multi$statistic,
                trig$statistic, naive$statistic),
  p.value = c(fixed$p.value, median$p.value, multi$p.value,
              trig$p.value, naive$p.value),
  n = length(theta),
  B = B
)
write_csv(tab, file.path(project_dir, "output", "noshiro_p_values.csv"))
write_csv(tab, file.path(project_dir, "tables", "noshiro_p_values.csv"))

dir.create(file.path(project_dir, "figures"), showWarnings = FALSE)
theme_paper <- ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
p <- ggplot2::ggplot(data.frame(theta, phi), ggplot2::aes(theta, phi)) +
  ggplot2::geom_bin2d(bins = 40) +
  ggplot2::scale_x_continuous(limits = c(0, two_pi())) +
  ggplot2::scale_y_continuous(limits = c(0, two_pi())) +
  ggplot2::labs(x = "direction of steepest descent",
                y = "direction of lateral movement",
                fill = "count") +
  theme_paper
ggplot2::ggsave(file.path(project_dir, "figures", "fig7_noshiro_torus.pdf"),
                p, width = 5.4, height = 4.6)

sens <- list()
idx <- 0L
for (k1 in grid) {
  for (k2 in grid) {
    test <- circ_circ_hsic_test(theta, phi, kappa_theta = k1, kappa_phi = k2,
                                B = B, seed = seed + 100L + idx)
    idx <- idx + 1L
    sens[[idx]] <- data.frame(kappa_theta = k1, kappa_phi = k2,
                              p.value = test$p.value, statistic = test$statistic)
  }
}
sens <- do.call(rbind, sens)
write_csv(sens, file.path(project_dir, "output", "noshiro_kappa_sensitivity.csv"))
p8 <- ggplot2::ggplot(sens, ggplot2::aes(factor(kappa_theta), factor(kappa_phi),
                                         fill = p.value)) +
  ggplot2::geom_tile(colour = "white") +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.3f", p.value)), size = 2.7) +
  ggplot2::labs(x = expression(kappa[theta]), y = expression(kappa[phi]),
                fill = "p-value") +
  theme_paper
ggplot2::ggsave(file.path(project_dir, "figures", "fig8_noshiro_kappa.pdf"),
                p8, width = 5.6, height = 4.8)

message("Noshiro outputs written.")
