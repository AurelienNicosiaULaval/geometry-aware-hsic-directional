# Final Noshiro real-data analysis.

args <- commandArgs(trailingOnly = TRUE)

parse_cli <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    key_value <- sub("^--", "", arg)
    key <- sub("=.*$", "", key_value)
    value <- if (grepl("=", key_value, fixed = TRUE)) sub("^[^=]*=", "", key_value) else "true"
    out[[key]] <- value
  }
  out
}

cli <- parse_cli(args)
get_arg <- function(name, default = NULL) if (name %in% names(cli)) cli[[name]] else default
parse_num_vec <- function(value, default) {
  if (is.null(value) || value == "") return(default)
  out <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (anyNA(out) || any(!is.finite(out))) {
    stop(sprintf("Argument value `%s` must be comma-separated numeric values.", value),
         call. = FALSE)
  }
  out
}

file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
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

B <- as.integer(get_arg("B", "999"))
B <- check_positive_integer(B, "B")
seed <- as.integer(get_arg("seed", "20260606"))
grid <- parse_num_vec(get_arg("grid", NULL), c(0.5, 2, 8, 16))
output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))
data_file <- file.path(project_dir, "data", "noshiro.csv")
source_file <- file.path(project_dir, "data", "noshiro_source.txt")

raw_file <- file.path(output_dir, "noshiro_raw.csv")
summary_file <- file.path(output_dir, "noshiro_summary.csv")
fig_dir <- file.path(output_dir, "figures")
tab_dir <- file.path(output_dir, "tables")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(data_file)) {
  stop("Missing data/noshiro.csv.", call. = FALSE)
}

dat <- utils::read.csv(data_file, stringsAsFactors = FALSE)
cols <- if (all(c("DIRDSC", "DIRMV") %in% names(dat))) {
  c("DIRDSC", "DIRMV")
} else if (all(c("theta1", "theta2") %in% names(dat))) {
  c("theta1", "theta2")
} else {
  stop("Noshiro data must contain DIRDSC/DIRMV or theta1/theta2.", call. = FALSE)
}

theta_raw <- as.numeric(dat[[cols[1]]])
phi_raw <- as.numeric(dat[[cols[2]]])
keep <- stats::complete.cases(theta_raw, phi_raw)
theta_raw <- theta_raw[keep]
phi_raw <- phi_raw[keep]
units <- if (max(abs(theta_raw), abs(phi_raw), na.rm = TRUE) > two_pi() + 1e-8 &&
             max(abs(theta_raw), abs(phi_raw), na.rm = TRUE) <= 360 + 1e-8) {
  "degrees converted to radians"
} else {
  "radians"
}
theta <- if (identical(units, "degrees converted to radians")) theta_raw * pi / 180 else theta_raw
phi <- if (identical(units, "degrees converted to radians")) phi_raw * pi / 180 else phi_raw
theta <- wrap_angle(theta)
phi <- wrap_angle(phi)
n <- length(theta)

message(sprintf("Noshiro analysis: n=%d, B=%d, grid=%s", n, B, paste(grid, collapse = ",")))

fixed <- circ_circ_hsic_test(theta, phi, 2, 2, B = B, seed = seed + 1L,
                             return_permutations = TRUE)
median <- circ_circ_hsic_test(theta, phi, B = B, seed = seed + 2L,
                              return_permutations = TRUE)
multi <- circ_circ_hsic_multiscale_test(
  theta, phi, grid, grid, B = B, seed = seed + 3L,
  return_grid = TRUE, return_permutations = TRUE
)
js <- js_circular_correlation_test(theta, phi, B = B, seed = seed + 4L)
fl <- fisher_lee_circular_correlation_test(theta, phi, B = B, seed = seed + 5L)
trig <- trig_moment_test(theta, phi, B = B, seed = seed + 6L)
naive <- naive_angle_hsic_test(theta, phi, B = B, seed = seed + 7L,
                               return_permutations = TRUE)

summary <- data.frame(
  method = c(
    fixed$method,
    median$method,
    multi$method,
    js$method,
    fl$method,
    trig$method,
    naive$method
  ),
  statistic = c(
    fixed$statistic,
    median$statistic,
    multi$statistic,
    js$statistic,
    fl$statistic,
    trig$statistic,
    naive$statistic
  ),
  p.value = c(
    fixed$p.value,
    median$p.value,
    multi$p.value,
    js$p.value,
    fl$p.value,
    trig$p.value,
    naive$p.value
  ),
  n = n,
  B = B,
  min_p = 1 / (B + 1),
  grid = c(NA, NA, paste(grid, collapse = ","), NA, NA, NA, NA),
  role = c(
    "primary",
    "primary",
    "primary",
    "diagnostic comparator",
    "diagnostic comparator",
    "diagnostic comparator",
    "anti-example"
  ),
  stringsAsFactors = FALSE
)

raw_rows <- list()
add_perm_rows <- function(method, observed, permutations, type = "permutation") {
  data.frame(
    method = method,
    statistic_type = c("observed", rep(type, length(permutations))),
    permutation = c(0L, seq_along(permutations)),
    statistic = c(observed, permutations),
    stringsAsFactors = FALSE
  )
}
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(fixed$method, fixed$statistic, fixed$permutations)
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(median$method, median$statistic, median$permutations)
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(multi$method, multi$statistic,
                                                   multi$permutation_maxima,
                                                   "permutation maximum")
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(js$method, js$statistic, js$permutations)
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(fl$method, fl$statistic, fl$permutations)
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(trig$method, trig$statistic, trig$permutations)
raw_rows[[length(raw_rows) + 1L]] <- add_perm_rows(naive$method, naive$statistic, naive$permutations)
raw <- do.call(rbind, raw_rows)
raw$n <- n
raw$B <- B
raw$min_p <- 1 / (B + 1)

sensitivity <- multi$grid
sensitivity$kappa_theta <- grid[sensitivity$K_index]
sensitivity$kappa_phi <- grid[sensitivity$L_index]
sensitivity$observed <- multi$observed_grid
sensitivity$null_mean <- multi$null_mean_grid
sensitivity$null_sd <- multi$null_sd_grid
sensitivity$standardized <- multi$standardized_grid
sensitivity$p.value <- vapply(seq_len(nrow(sensitivity)), function(j) {
  (1 + sum(multi$permutations[, j] >= multi$observed_grid[j])) / (B + 1)
}, numeric(1))
sensitivity$retained <- seq_len(nrow(sensitivity)) %in%
  match(paste(multi$retained_grid$K_index, multi$retained_grid$L_index),
        paste(sensitivity$K_index, sensitivity$L_index))
sensitivity$n <- n
sensitivity$B <- B
sensitivity$min_p <- 1 / (B + 1)

write_csv(raw, raw_file)
write_csv(summary, summary_file)
write_csv(sensitivity, file.path(output_dir, "noshiro_kappa_sensitivity.csv"))

plot_data <- data.frame(theta = theta, phi = phi)
write_csv(plot_data, file.path(output_dir, "noshiro_angles.csv"))

theme_paper <- ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                 legend.position = "bottom",
                 strip.text = ggplot2::element_text(face = "bold"),
                 plot.title = ggplot2::element_text(face = "bold", size = 11))

p7 <- ggplot2::ggplot(plot_data, ggplot2::aes(theta, phi)) +
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
  theme_paper
ggplot2::ggsave(file.path(fig_dir, "fig7_noshiro_torus.pdf"), p7,
                width = 5.4, height = 4.8)

p8 <- ggplot2::ggplot(
  sensitivity,
  ggplot2::aes(factor(kappa_theta), factor(kappa_phi), fill = p.value)
) +
  ggplot2::geom_tile(colour = "white", linewidth = 0.25) +
  ggplot2::scale_fill_gradientn(colours = c("#08519C", "#6BAED6", "#F7FBFF"),
                                limits = c(0, 1)) +
  ggplot2::labs(
    title = sprintf("Noshiro p-value sensitivity, B = %d", B),
    x = "First-angle concentration",
    y = "Second-angle concentration",
    fill = "p-value"
  ) +
  theme_paper
ggplot2::ggsave(file.path(fig_dir, "fig8_noshiro_kappa.pdf"), p8,
                width = 5.6, height = 4.8)

method_label <- function(x) {
  dplyr::recode(
    x,
    "HSIC standardized multi-scale" = "HSIC multi-scale",
    "Jammalamadaka-Sarma circular correlation diagnostic" = "Jammalamadaka-Sarma",
    "Fisher-Lee circular correlation diagnostic" = "Fisher-Lee",
    "first-order trigonometric moment diagnostic" = "Trig. moment diagnostic",
    "naive Euclidean-angle HSIC anti-example" = "Naive Euclidean HSIC",
    .default = x
  )
}

table4 <- summary
table4$method <- method_label(table4$method)
table4_out <- data.frame(
  Method = table4$method,
  Role = table4$role,
  Statistic = sprintf("%.4g", table4$statistic),
  `p-value` = sprintf("%.4g", table4$p.value),
  n = table4$n,
  B = table4$B,
  `min p` = sprintf("%.4g", table4$min_p),
  check.names = FALSE
)
write_csv(table4_out, file.path(tab_dir, "table4_noshiro_p_values.csv"))

esc <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("_", "\\\\_", x)
  x <- gsub("%", "\\\\%", x)
  x
}
lines <- c(
  "\\begin{table}[!htbp]",
  "\\centering",
  "\\scriptsize",
  sprintf("\\caption{Noshiro p-values with add-one permutation calibration. The smallest attainable p-value is %.4g because B = %d.}", 1 / (B + 1), B),
  "\\label{tab:noshiro}",
  "\\begin{tabular}{lllllll}",
  "\\toprule",
  paste(esc(names(table4_out)), collapse = " & "),
  "\\\\",
  "\\midrule"
)
body <- apply(table4_out, 1, function(row) paste(esc(row), collapse = " & "))
lines <- c(lines, paste0(body, "\\\\"), "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(lines, file.path(tab_dir, "table4_noshiro_p_values.tex"))

meta <- data.frame(
  data_file = data_file,
  source_file = ifelse(file.exists(source_file), source_file, NA_character_),
  n = n,
  variable_1 = cols[1],
  variable_2 = cols[2],
  units = units,
  theta_min = min(theta),
  theta_max = max(theta),
  phi_min = min(phi),
  phi_max = max(phi),
  B = B,
  min_p = 1 / (B + 1),
  grid = paste(grid, collapse = ","),
  stringsAsFactors = FALSE
)
write_csv(meta, file.path(output_dir, "noshiro_metadata.csv"))

message(sprintf("Noshiro final outputs written to %s", output_dir))
