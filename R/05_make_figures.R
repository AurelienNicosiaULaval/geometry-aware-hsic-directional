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
  stop("Package `ggplot2` is required for figures.", call. = FALSE)
}

dir.create(file.path(project_dir, "figures"), showWarnings = FALSE)
theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

examples <- example_alternatives()
p1 <- ggplot2::ggplot(examples, ggplot2::aes(theta, phi)) +
  ggplot2::geom_point(alpha = 0.45, size = 0.7) +
  ggplot2::facet_wrap(~ scenario, ncol = 3) +
  ggplot2::scale_x_continuous(limits = c(0, two_pi())) +
  ggplot2::scale_y_continuous(limits = c(0, two_pi())) +
  ggplot2::labs(x = expression(Theta), y = expression(Phi)) +
  theme_paper()
ggplot2::ggsave(file.path(project_dir, "figures", "fig1_alternatives.pdf"),
                p1, width = 7.2, height = 4.6)

circ_file <- file.path(project_dir, "output", "circular_circular_summary.csv")
if (file.exists(circ_file)) {
  circ <- utils::read.csv(circ_file, stringsAsFactors = FALSE)
  p2 <- ggplot2::ggplot(circ[circ$class == "null", ],
                        ggplot2::aes(factor(n), rejection_rate, colour = method,
                                     group = method)) +
    ggplot2::geom_point() + ggplot2::geom_line() +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = pmax(0, rejection_rate - 1.96 * mc_error),
                                        ymax = pmin(1, rejection_rate + 1.96 * mc_error)),
                           width = 0.1) +
    ggplot2::facet_wrap(~ scenario) +
    ggplot2::labs(x = "n", y = "type-I rejection rate") +
    theme_paper()
  ggplot2::ggsave(file.path(project_dir, "figures", "fig2_type1.pdf"),
                  p2, width = 8.0, height = 5.0)

  p3 <- ggplot2::ggplot(circ[circ$class == "alternative", ],
                        ggplot2::aes(kappa_noise, rejection_rate, colour = method)) +
    ggplot2::geom_line() + ggplot2::geom_point(size = 0.8) +
    ggplot2::facet_grid(scenario ~ n) +
    ggplot2::labs(x = expression(rho[epsilon]), y = "power") +
    theme_paper()
  ggplot2::ggsave(file.path(project_dir, "figures", "fig3_power.pdf"),
                  p3, width = 8.5, height = 7.2)

  keep <- circ$method %in% c("HSIC fixed", "HSIC median", "HSIC standardized multi-scale")
  p4 <- ggplot2::ggplot(circ[keep & circ$class == "alternative", ],
                        ggplot2::aes(method, rejection_rate, fill = method)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::facet_grid(scenario ~ n) +
    ggplot2::labs(x = NULL, y = "power") +
    theme_paper() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 30, hjust = 1),
                   legend.position = "none")
  ggplot2::ggsave(file.path(project_dir, "figures", "fig4_strategy_comparison.pdf"),
                  p4, width = 8.5, height = 7.2)
}

cl_file <- file.path(project_dir, "output", "circular_linear_summary.csv")
if (file.exists(cl_file)) {
  cl <- utils::read.csv(cl_file, stringsAsFactors = FALSE)
  p6 <- ggplot2::ggplot(cl, ggplot2::aes(noise_sd, rejection_rate, colour = factor(n))) +
    ggplot2::geom_line() + ggplot2::geom_point() +
    ggplot2::facet_wrap(~ scenario) +
    ggplot2::labs(x = "linear noise sd", y = "rejection rate", colour = "n") +
    theme_paper()
  ggplot2::ggsave(file.path(project_dir, "figures", "fig6_circular_linear.pdf"),
                  p6, width = 7.4, height = 4.8)
}

kappa_file <- file.path(project_dir, "output", "kappa_sensitivity_summary.csv")
if (file.exists(kappa_file)) {
  ks <- utils::read.csv(kappa_file, stringsAsFactors = FALSE)
  p5 <- ggplot2::ggplot(
    ks,
    ggplot2::aes(factor(kappa_theta), factor(kappa_phi), fill = rejection_rate)
  ) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", rejection_rate)),
                       size = 2.3) +
    ggplot2::facet_grid(scenario ~ n) +
    ggplot2::labs(x = expression(kappa[theta]), y = expression(kappa[phi]),
                  fill = "rejection rate") +
    theme_paper()
  ggplot2::ggsave(file.path(project_dir, "figures", "fig5_kappa_sensitivity.pdf"),
                  p5, width = 8.5, height = 5.4)
}

message("Figures written where input files were available.")
