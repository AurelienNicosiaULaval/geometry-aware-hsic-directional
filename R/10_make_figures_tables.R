# Generate publication-style figures and tables from saved CSV outputs.
# If main simulation outputs are absent, generate diagnostic outputs only.

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

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Package `ggplot2` is required.", call. = FALSE)
}
if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("Package `dplyr` is required.", call. = FALSE)
}
if (!requireNamespace("tidyr", quietly = TRUE)) {
  stop("Package `tidyr` is required.", call. = FALSE)
}

has_final_outputs <- function(project_dir) {
  files <- file.path(project_dir, "output", "final", c(
    "null_summary.csv",
    "power_summary.csv",
    "circular_linear_summary.csv"
  ))
  if (!all(file.exists(files))) return(FALSE)
  summaries <- lapply(files, utils::read.csv, stringsAsFactors = FALSE)
  summaries <- dplyr::bind_rows(summaries)
  if ("R" %in% names(summaries)) summaries$R <- as.numeric(summaries$R)
  if ("B" %in% names(summaries)) summaries$B <- as.numeric(summaries$B)
  if ("completed" %in% names(summaries)) {
    summaries$completed <- tolower(as.character(summaries$completed)) %in%
      c("true", "1", "yes")
  }
  all(c("R", "B", "completed") %in% names(summaries)) &&
    all(summaries$R >= 500 & summaries$B >= 499 & summaries$completed)
}

is_final <- has_final_outputs(project_dir)
mode_name <- if (is_final) "final" else "diagnostic"
base_dir <- file.path(project_dir, "output", mode_name)
fig_dir <- file.path(base_dir, "figures")
tab_dir <- file.path(base_dir, "tables")
data_dir <- file.path(base_dir, "data")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

palette_cb <- c(
  "#0072B2", "#D55E00", "#009E73", "#CC79A7",
  "#E69F00", "#56B4E9", "#000000", "#F0E442"
)

label_status <- ""
caption_prefix <- if (is_final) "" else "Diagnostic figure. "
table_prefix <- if (is_final) "" else "Diagnostic table. "

theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", size = 11),
      axis.title = ggplot2::element_text(size = 10)
    )
}

method_label <- function(x) {
  dplyr::recode(
    x,
    "HSIC fixed" = "HSIC fixed",
    "HSIC median" = "HSIC median",
    "HSIC standardized multi-scale" = "HSIC multi-scale",
    "naive Euclidean-angle HSIC" = "Naive Euclidean HSIC",
    "naive Euclidean-angle HSIC anti-example" = "Naive Euclidean HSIC",
    "trigonometric moment diagnostic" = "Trig. moment diagnostic",
    "first-order trigonometric moment diagnostic" = "Trig. moment diagnostic",
    .default = x
  )
}

scenario_label <- function(x) {
  dplyr::recode(
    x,
    "N1_uniform_uniform" = "Uniform, uniform",
    "N2_vonmises_vonmises" = "von Mises, von Mises",
    "N3_uniform_vonmises" = "Uniform, von Mises",
    "N4_mixture_mixture" = "Mixture, mixture",
    "A1_shift" = "Shift",
    "A2_double_angle" = "Double angle",
    "A3_axial" = "Axial",
    "A4_multimodal" = "Multimodal",
    "A5_local_dependence" = "Local dependence",
    "A6_symmetric_nonlinear" = "Symmetric nonlinear",
    "L0_independent" = "Independent",
    "L1_cos" = "Cosine mean",
    "L2_cos2" = "Second harmonic",
    "L3_multivariate" = "Multivariate",
    "L4_local" = "Local arc",
    .default = x
  )
}

write_table_tex <- function(df, file, caption, label) {
  esc <- function(x) {
    x <- as.character(x)
    x <- gsub("\\\\", "\\\\textbackslash{}", x)
    x <- gsub("_", "\\\\_", x)
    x <- gsub("%", "\\\\%", x)
    x
  }
  aligns <- paste(rep("l", ncol(df)), collapse = "")
  lines <- c(
    "\\begin{table}[!htbp]",
    "\\centering",
    "\\scriptsize",
    sprintf("\\caption{%s}", caption),
    sprintf("\\label{%s}", label),
    sprintf("\\begin{tabular}{%s}", aligns),
    "\\toprule",
    paste(esc(names(df)), collapse = " & "),
    "\\\\",
    "\\midrule"
  )
  body <- apply(df, 1, function(row) paste(esc(row), collapse = " & "))
  lines <- c(lines, paste0(body, "\\\\"), "\\bottomrule", "\\end{tabular}", "\\end{table}")
  writeLines(lines, file)
  invisible(file)
}

fig_records <- list()
tab_records <- list()
record_fig <- function(id, file, data_file, status, note) {
  fig_records[[length(fig_records) + 1L]] <<- data.frame(
    item = id, file = file, data_file = data_file, status = status, note = note,
    stringsAsFactors = FALSE
  )
}
record_tab <- function(id, file, data_file, status, note) {
  tab_records[[length(tab_records) + 1L]] <<- data.frame(
    item = id, file = file, data_file = data_file, status = status, note = note,
    stringsAsFactors = FALSE
  )
}

# Figure 1: illustrative alternatives. The plotted data are saved first.
alt_data_file <- file.path(data_dir, "fig1_alternatives_data.csv")
if (!file.exists(alt_data_file) || !is_final) {
  alt_data <- example_alternatives(n = 500, kappa_noise = 8, seed = 20260606)
  write_csv(alt_data, alt_data_file)
}
alt_data <- utils::read.csv(alt_data_file, stringsAsFactors = FALSE)
alt_data$scenario_label <- scenario_label(alt_data$scenario)
p1 <- ggplot2::ggplot(alt_data, ggplot2::aes(theta, phi)) +
  ggplot2::geom_point(alpha = 0.45, size = 0.55, colour = "#0072B2") +
  ggplot2::facet_wrap(~ scenario_label, ncol = 3) +
  ggplot2::coord_equal(xlim = c(0, two_pi()), ylim = c(0, two_pi())) +
  ggplot2::scale_x_continuous(breaks = c(0, pi, two_pi()),
                              labels = c("0", "pi", "2pi")) +
  ggplot2::scale_y_continuous(breaks = c(0, pi, two_pi()),
                              labels = c("0", "pi", "2pi")) +
  ggplot2::labs(
    title = "Circular-circular alternatives",
    x = "First angle", y = "Second angle"
  ) +
  theme_paper()
fig1 <- file.path(fig_dir, "fig1_alternatives.pdf")
ggplot2::ggsave(fig1, p1, width = 7.2, height = 4.8)
record_fig("Figure 1", fig1, alt_data_file, mode_name,
           "Illustrative simulated alternatives saved to CSV before plotting.")

# Simulation summaries.
circ_file <- if (is_final) {
  file.path(project_dir, "output", "final")
} else {
  file.path(project_dir, "output", "circular_circular_summary.csv")
}
if (!is_final && file.exists(circ_file)) {
  circ <- utils::read.csv(circ_file, stringsAsFactors = FALSE)
} else if (is_final && dir.exists(circ_file)) {
  circ <- dplyr::bind_rows(
    utils::read.csv(file.path(circ_file, "null_summary.csv"), stringsAsFactors = FALSE),
    utils::read.csv(file.path(circ_file, "power_summary.csv"), stringsAsFactors = FALSE)
  )
  names(circ)[names(circ) == "effect"] <- "kappa_noise"
  circ$class <- ifelse(circ$kind == "null", "null", "alternative")
} else {
  circ <- data.frame()
}

if (nrow(circ) > 0L) {
  circ$method_label <- method_label(circ$method)
  circ$scenario_label <- scenario_label(circ$scenario)
  circ$kappa_noise <- if ("kappa_noise" %in% names(circ)) circ$kappa_noise else circ$effect
  circ_data_file <- file.path(data_dir, "circular_circular_summary_used.csv")
  write_csv(circ, circ_data_file)

  null_data <- dplyr::filter(circ, class == "null")
  if (nrow(null_data) > 0L) {
    p2 <- ggplot2::ggplot(
      null_data,
      ggplot2::aes(factor(n), rejection_rate, colour = method_label, group = method_label)
    ) +
      ggplot2::geom_hline(yintercept = 0.05, linetype = "dashed", colour = "grey45") +
      ggplot2::geom_errorbar(
        ggplot2::aes(ymin = pmax(0, rejection_rate - 1.96 * mc_error),
                     ymax = pmin(1, rejection_rate + 1.96 * mc_error)),
        width = 0.12, linewidth = 0.35
      ) +
      ggplot2::geom_line(linewidth = 0.45) +
      ggplot2::geom_point(size = 1.6) +
      ggplot2::facet_wrap(~ scenario_label, ncol = 2) +
      ggplot2::scale_colour_manual(values = palette_cb) +
      ggplot2::labs(
        title = "Type-I error under independent circular marginals",
        x = "Sample size", y = "Rejection rate", colour = "Method"
      ) +
      theme_paper()
    fig2 <- file.path(fig_dir, "fig2_type1.pdf")
    ggplot2::ggsave(fig2, p2, width = 7.4, height = 5.2)
    record_fig("Figure 2", fig2, circ_data_file, mode_name,
               "Type-I error with 95 percent Monte Carlo intervals.")

    table1 <- null_data |>
      dplyr::filter(method %in% c("HSIC fixed", "HSIC median",
                                  "HSIC standardized multi-scale")) |>
      dplyr::transmute(
        Scenario = scenario_label,
        n = n,
        Method = method_label,
        `Reject.` = sprintf("%.2f", rejection_rate),
        `MC SE` = sprintf("%.2f", mc_error),
        R = R,
        B = B,
        alpha = "0.05"
      ) |>
      dplyr::arrange(Scenario, n, Method)
    table1_csv <- file.path(tab_dir, "table1_type1_summary.csv")
    table1_tex <- file.path(tab_dir, "table1_type1_summary.tex")
    write_csv(table1, table1_csv)
    write_table_tex(
      table1, table1_tex,
      paste0(table_prefix,
             "Type-I error summary with Monte Carlo standard errors; alpha = 0.05."),
      "tab:type1"
    )
    record_tab("Table 1", table1_tex, table1_csv, mode_name,
               "Type-I error summary.")
  }

  alt_data <- dplyr::filter(circ, class == "alternative")
  if (nrow(alt_data) > 0L) {
    p3 <- ggplot2::ggplot(
      alt_data,
      ggplot2::aes(kappa_noise, rejection_rate, colour = method_label)
    ) +
      ggplot2::geom_line(linewidth = 0.45) +
      ggplot2::geom_point(size = 1.2) +
      ggplot2::facet_grid(scenario_label ~ n) +
      ggplot2::scale_colour_manual(values = palette_cb) +
      ggplot2::labs(
        title = "Power versus circular noise concentration",
        x = "Noise concentration", y = "Rejection rate", colour = "Method"
      ) +
      theme_paper() +
      ggplot2::theme(strip.text.y = ggplot2::element_text(angle = 0))
    fig3 <- file.path(fig_dir, "fig3_power.pdf")
    ggplot2::ggsave(fig3, p3, width = 8.8, height = 7.5)
    record_fig("Figure 3", fig3, circ_data_file, mode_name,
               "Power curves by circular-circular alternative.")

    keep_strategy <- alt_data$method %in% c(
      "HSIC fixed", "HSIC median", "HSIC standardized multi-scale"
    )
    strategy_data <- alt_data[keep_strategy, , drop = FALSE]
    p4 <- ggplot2::ggplot(
      strategy_data,
      ggplot2::aes(factor(kappa_noise), rejection_rate, fill = method_label)
    ) +
      ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.72) +
      ggplot2::facet_grid(scenario_label ~ n) +
      ggplot2::scale_fill_manual(values = palette_cb[1:3]) +
      ggplot2::labs(
        title = "Kernel-parameter strategy comparison",
        x = "Noise concentration", y = "Rejection rate", fill = "Strategy"
      ) +
      theme_paper() +
      ggplot2::theme(strip.text.y = ggplot2::element_text(angle = 0))
    fig4 <- file.path(fig_dir, "fig4_strategy_comparison.pdf")
    ggplot2::ggsave(fig4, p4, width = 8.8, height = 7.5)
    record_fig("Figure 4", fig4, circ_data_file, mode_name,
               "Fixed, median and multi-scale HSIC comparison.")

    selected_effect <- max(alt_data$kappa_noise, na.rm = TRUE)
    table2 <- alt_data |>
      dplyr::filter(kappa_noise == selected_effect,
                    n == max(n),
                    method %in% c("HSIC fixed", "HSIC median",
                                  "HSIC standardized multi-scale")) |>
      dplyr::transmute(
        Scenario = scenario_label,
        n = n,
        Method = method_label,
        `Noise conc.` = kappa_noise,
        `Reject.` = sprintf("%.2f", rejection_rate),
        `MC SE` = sprintf("%.2f", mc_error),
        R = R,
        B = B,
        alpha = "0.05"
      ) |>
      dplyr::arrange(Scenario, n, Method)
    table2_csv <- file.path(tab_dir, "table2_selected_power.csv")
    table2_tex <- file.path(tab_dir, "table2_selected_power.tex")
    write_csv(table2, table2_csv)
    write_table_tex(
      table2, table2_tex,
      paste0(table_prefix,
             "Selected circular-circular rejection rates with Monte Carlo standard errors; alpha = 0.05."),
      "tab:selected-power"
    )
    record_tab("Table 2", table2_tex, table2_csv, mode_name,
               "Selected power values at the largest available noise concentration.")

    table3 <- strategy_data |>
      dplyr::group_by(method_label) |>
      dplyr::summarise(
        `Mean reject.` = mean(rejection_rate),
        `Mean MC SE` = mean(mc_error),
        R = paste(sort(unique(R)), collapse = ","),
        B = paste(sort(unique(B)), collapse = ","),
        .groups = "drop"
      ) |>
      dplyr::transmute(
        Strategy = method_label,
        `Mean reject.` = sprintf("%.2f", `Mean reject.`),
        `Mean MC SE` = sprintf("%.2f", `Mean MC SE`),
        R = R,
        B = B,
        alpha = "0.05"
      )
    table3_csv <- file.path(tab_dir, "table3_strategy_comparison.csv")
    table3_tex <- file.path(tab_dir, "table3_strategy_comparison.tex")
    write_csv(table3, table3_csv)
    write_table_tex(
      table3, table3_tex,
      paste0(table_prefix,
             "Descriptive mean rejection rates for kernel-parameter strategies across the simulated circular-circular design; alpha = 0.05."),
      "tab:strategy"
    )
    record_tab("Table 3", table3_tex, table3_csv, mode_name,
               "Kernel-parameter strategy comparison.")
  }
}

# Figure 5: reduced kappa sensitivity. The older exhaustive sensitivity output is
# intentionally not used as a main figure because it may be partial.
kappa_file <- if (is_final) {
  file.path(project_dir, "output", "final", "reduced_sensitivity_summary.csv")
} else {
  file.path(project_dir, "output", "kappa_sensitivity_summary.csv")
}
if (file.exists(kappa_file)) {
  ks <- utils::read.csv(kappa_file, stringsAsFactors = FALSE)
  if (!"completed" %in% names(ks) || all(tolower(as.character(ks$completed)) %in% c("true", "1", "yes"))) {
    ks$scenario_label <- scenario_label(ks$scenario)
    ks_file <- file.path(data_dir, "kappa_sensitivity_summary_used.csv")
    write_csv(ks, ks_file)
    p5 <- ggplot2::ggplot(
      ks,
      ggplot2::aes(factor(kappa_theta), factor(kappa_phi), fill = rejection_rate)
    ) +
      ggplot2::geom_tile(colour = "white", linewidth = 0.25) +
      ggplot2::facet_wrap(~ scenario_label, ncol = 2) +
      ggplot2::scale_fill_gradientn(
        colours = c("#F7FBFF", "#6BAED6", "#08519C"),
        limits = c(0, 1)
      ) +
      ggplot2::labs(
        title = "Sensitivity to fixed von Mises concentrations",
        x = "First-angle concentration", y = "Second-angle concentration",
        fill = "Rejection rate"
      ) +
      theme_paper()
    fig5 <- file.path(fig_dir, "fig5_kappa_sensitivity.pdf")
    ggplot2::ggsave(fig5, p5, width = 7.4, height = 5.8)
    record_fig("Figure 5", fig5, ks_file, mode_name,
               "Reduced fixed-concentration sensitivity heatmaps.")
  }
}

# Figure 6: circular-linear.
cl_file <- if (is_final) file.path(project_dir, "output", "final", "circular_linear_summary.csv") else
  file.path(project_dir, "output", "circular_linear_summary.csv")
if (file.exists(cl_file)) {
  cl <- utils::read.csv(cl_file, stringsAsFactors = FALSE)
  if ("effect" %in% names(cl) && !"noise_sd" %in% names(cl)) cl$noise_sd <- cl$effect
  cl$scenario_label <- scenario_label(cl$scenario)
  cl_file_used <- file.path(data_dir, "circular_linear_summary_used.csv")
  write_csv(cl, cl_file_used)
  p6 <- ggplot2::ggplot(
    cl,
    ggplot2::aes(noise_sd, rejection_rate, colour = factor(n), group = factor(n))
  ) +
    ggplot2::geom_line(linewidth = 0.45) +
    ggplot2::geom_point(size = 1.4) +
    ggplot2::facet_wrap(~ scenario_label, ncol = 3) +
    ggplot2::scale_colour_manual(values = palette_cb) +
    ggplot2::labs(
      title = "Circular-linear rejection rates",
      x = "Linear noise standard deviation", y = "Rejection rate",
      colour = "Sample size"
    ) +
    theme_paper()
  fig6 <- file.path(fig_dir, "fig6_circular_linear.pdf")
  ggplot2::ggsave(fig6, p6, width = 8.2, height = 4.9)
  record_fig("Figure 6", fig6, cl_file_used, mode_name,
             "Circular-linear rejection rates.")
}

# Figure 7 and Table 4: Noshiro outputs.
noshiro_file <- if (is_final) {
  file.path(project_dir, "output", "final", "noshiro_summary.csv")
} else {
  file.path(project_dir, "output", "noshiro_p_values.csv")
}
noshiro_sens_file <- if (is_final) {
  file.path(project_dir, "output", "final", "noshiro_kappa_sensitivity.csv")
} else {
  file.path(project_dir, "output", "noshiro_kappa_sensitivity.csv")
}
noshiro_data <- file.path(project_dir, "data", "noshiro.csv")
if (file.exists(noshiro_data)) {
  dat <- utils::read.csv(noshiro_data, stringsAsFactors = FALSE)
  cols <- if (all(c("DIRDSC", "DIRMV") %in% names(dat))) {
    c("DIRDSC", "DIRMV")
  } else if (all(c("theta1", "theta2") %in% names(dat))) {
    c("theta1", "theta2")
  } else {
    character()
  }
  if (length(cols) == 2L) {
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
    noshiro_plot_data <- data.frame(theta = wrap_angle(theta), phi = wrap_angle(phi))
    noshiro_plot_csv <- file.path(data_dir, "fig7_noshiro_angles.csv")
    write_csv(noshiro_plot_data, noshiro_plot_csv)
    p7 <- ggplot2::ggplot(noshiro_plot_data, ggplot2::aes(theta, phi)) +
      ggplot2::geom_bin2d(bins = 36) +
      ggplot2::coord_equal(xlim = c(0, two_pi()), ylim = c(0, two_pi())) +
      ggplot2::scale_x_continuous(breaks = c(0, pi, two_pi()),
                                  labels = c("0", "pi", "2pi")) +
      ggplot2::scale_y_continuous(breaks = c(0, pi, two_pi()),
                                  labels = c("0", "pi", "2pi")) +
      ggplot2::scale_fill_gradientn(colours = c("#F7FBFF", "#6BAED6", "#08519C")) +
      ggplot2::labs(
        title = "Noshiro binned torus plot",
        x = "Direction of steepest descent",
        y = "Direction of lateral movement",
        fill = "Count"
      ) +
      theme_paper()
    fig7 <- file.path(fig_dir, "fig7_noshiro_torus.pdf")
    ggplot2::ggsave(fig7, p7, width = 5.4, height = 4.8)
    record_fig("Figure 7", fig7, noshiro_plot_csv, mode_name,
               "Noshiro binned torus plot from local data file.")
  }
}

if (file.exists(noshiro_sens_file)) {
  sens <- utils::read.csv(noshiro_sens_file, stringsAsFactors = FALSE)
  sens_file <- file.path(data_dir, "noshiro_kappa_sensitivity_used.csv")
  write_csv(sens, sens_file)
  p_unique <- if ("p.value" %in% names(sens)) unique(round(sens$p.value, 12)) else numeric()
  all_min <- length(p_unique) == 1L && abs(p_unique - 0.001) < 1e-12
  if (!all_min) {
    p8 <- ggplot2::ggplot(
      sens,
      ggplot2::aes(factor(kappa_theta), factor(kappa_phi), fill = p.value)
    ) +
      ggplot2::geom_tile(colour = "white", linewidth = 0.25) +
      ggplot2::scale_fill_gradientn(colours = c("#08519C", "#6BAED6", "#F7FBFF"),
                                    limits = c(0, 1)) +
      ggplot2::labs(
        title = "Noshiro p-value sensitivity",
        x = "First-angle concentration",
        y = "Second-angle concentration",
        fill = "p-value"
      ) +
      theme_paper()
    fig8 <- file.path(fig_dir, "fig8_noshiro_kappa.pdf")
    ggplot2::ggsave(fig8, p8, width = 5.6, height = 4.8)
    record_fig("Figure 8", fig8, sens_file, mode_name,
               "Noshiro p-value sensitivity over concentration grid.")
  }
}

if (file.exists(noshiro_file)) {
  np <- utils::read.csv(noshiro_file, stringsAsFactors = FALSE)
  np$method <- method_label(np$method)
  table4 <- np |>
    dplyr::transmute(
      Method = method,
      Statistic = sprintf("%.3f", statistic),
      `p-value` = sprintf("%.3f", p.value),
      n = n,
      B = B
    )
  table4_csv <- file.path(tab_dir, "table4_noshiro_p_values.csv")
  table4_tex <- file.path(tab_dir, "table4_noshiro_p_values.tex")
  write_csv(table4, table4_csv)
  write_table_tex(
    table4, table4_tex,
    paste0(table_prefix,
           "Noshiro Monte Carlo permutation p-values with B = 999; the minimum attainable add-one p-value is 0.001."),
    "tab:noshiro"
  )
  record_tab("Table 4", table4_tex, table4_csv, mode_name,
             "Noshiro p-values.")
}

# Table 5: runtime benchmark.
runtime_file <- file.path(project_dir, "output", "final", "runtime_benchmark_summary.csv")
if (file.exists(runtime_file)) {
  rt <- utils::read.csv(runtime_file, stringsAsFactors = FALSE)
  rt$method_label <- method_label(rt$method)
  table5 <- rt |>
    dplyr::transmute(
      Method = method_label,
      n = n,
      B = B,
      `Median sec.` = sprintf("%.3f", median_seconds),
      `IQR sec.` = sprintf("%.3f", iqr_seconds),
      Reps = timing_repetitions,
      Cores = cores_available
    ) |>
    dplyr::arrange(Method, n)
  table5_csv <- file.path(tab_dir, "table5_runtime_benchmark.csv")
  table5_tex <- file.path(tab_dir, "table5_runtime_benchmark.tex")
  write_csv(table5, table5_csv)
  write_table_tex(
    table5, table5_tex,
    "Runtime benchmark for HSIC strategies. Times are elapsed seconds with B = 199 permutations.",
    "tab:runtime"
  )
  record_tab("Table 5", table5_tex, table5_csv, mode_name,
             "Runtime benchmark summary.")
}

# Table 6: torus demonstration.
torus_file <- file.path(project_dir, "output", "final", "torus_demo_summary.csv")
if (file.exists(torus_file)) {
  tor <- utils::read.csv(torus_file, stringsAsFactors = FALSE)
  table6 <- tor |>
    dplyr::transmute(
      Scenario = scenario,
      n = n,
      Method = method,
      `Reject.` = sprintf("%.2f", rejection_rate),
      `MC SE` = sprintf("%.2f", mc_error),
      R = R,
      B = B,
      alpha = alpha
    ) |>
    dplyr::arrange(Scenario, n, Method)
  table6_csv <- file.path(tab_dir, "table6_torus_demo.csv")
  table6_tex <- file.path(tab_dir, "table6_torus_demo.tex")
  write_csv(table6, table6_csv)
  write_table_tex(
    table6, table6_tex,
    "Small torus-torus demonstration with Monte Carlo standard errors; alpha = 0.05.",
    "tab:torus-demo"
  )
  record_tab("Table 6", table6_tex, table6_csv, mode_name,
             "Torus demonstration summary.")
}

fig_audit <- if (length(fig_records) > 0L) dplyr::bind_rows(fig_records) else data.frame()
tab_audit <- if (length(tab_records) > 0L) dplyr::bind_rows(tab_records) else data.frame()
write_csv(fig_audit, file.path(data_dir, "figure_audit_records.csv"))
write_csv(tab_audit, file.path(data_dir, "table_audit_records.csv"))

message(sprintf("Generated %s figures and tables in %s", mode_name, base_dir))
