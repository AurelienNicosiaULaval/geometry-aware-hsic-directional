# Reduced kernel-sensitivity study for the CSDA pre-submission manuscript.

args <- commandArgs(trailingOnly = TRUE)

parse_cli <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    key_value <- sub("^--", "", arg)
    if (grepl("=", key_value, fixed = TRUE)) {
      key <- sub("=.*$", "", key_value)
      value <- sub("^[^=]*=", "", key_value)
      out[[key]] <- value
    } else {
      out[[key_value]] <- "true"
    }
  }
  out
}

parse_num_vec <- function(value, default) {
  if (is.null(value) || identical(value, "")) return(default)
  out <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (anyNA(out) || any(!is.finite(out))) {
    stop("Numeric vector arguments must be comma-separated finite values.",
         call. = FALSE)
  }
  out
}

parse_chr_vec <- function(value, default) {
  if (is.null(value) || identical(value, "")) return(default)
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

cli <- parse_cli(args)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."),
                mustWork = TRUE)
} else if (file.exists(file.path(getwd(), "R", "00_helpers.R"))) {
  normalizePath(getwd(), mustWork = TRUE)
} else {
  normalizePath(file.path(getwd(), ".."), mustWork = TRUE)
}
source(file.path(project_dir, "R", "00_helpers.R"))
load_compact_sources(project_dir)

get_arg <- function(name, default = NULL) {
  if (name %in% names(cli)) cli[[name]] else default
}

R_total <- check_positive_integer(as.integer(get_arg("R", "500")), "R")
B <- check_positive_integer(as.integer(get_arg("B", "499")), "B")
alpha <- as.numeric(get_arg("alpha", "0.05"))
seed0 <- as.integer(get_arg("seed", "20260606"))
n_values <- as.integer(parse_num_vec(get_arg("n", NULL), 100))
scenarios <- parse_chr_vec(
  get_arg("scenarios", NULL),
  c("N1_uniform_uniform", "A3_axial", "A4_multimodal", "A6_symmetric_nonlinear")
)
kappa_grid <- parse_num_vec(get_arg("kappa-grid", NULL), c(0.5, 1, 2, 4, 8, 16, 32))
effect <- as.numeric(get_arg("effect", "8"))
output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))
cores <- parallel_cores(default = 1L)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
chunk_dir <- file.path(output_dir, "reduced_sensitivity_chunks")
dir.create(chunk_dir, recursive = TRUE, showWarnings = FALSE)

fixed_grid_p_values <- function(theta, phi, grid, B, seed) {
  Kc_list <- lapply(grid, function(k) center_gram(vm_kernel(theta, k)))
  Lc_list <- lapply(grid, function(k) center_gram(vm_kernel(phi, k)))
  Kflat <- do.call(cbind, lapply(Kc_list, as.vector))
  Lflat <- do.call(cbind, lapply(Lc_list, as.vector))
  n <- length(theta)
  observed_mat <- crossprod(Kflat, Lflat) / n^2
  observed <- as.vector(observed_mat)
  counts <- integer(length(observed))

  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  for (b in seq_len(B)) {
    idx <- sample.int(n)
    Lperm <- do.call(cbind, lapply(Lc_list, function(Lc) as.vector(Lc[idx, idx])))
    stat <- as.vector(crossprod(Kflat, Lperm) / n^2)
    counts <- counts + as.integer(stat >= observed)
  }
  grid_df <- expand.grid(
    kappa_theta = grid,
    kappa_phi = grid,
    stringsAsFactors = FALSE
  )
  data.frame(
    method = "HSIC fixed-grid sensitivity",
    kappa_theta = grid_df$kappa_theta,
    kappa_phi = grid_df$kappa_phi,
    statistic = observed,
    p.value = (1 + counts) / (B + 1),
    stringsAsFactors = FALSE
  )
}

run_repetition <- function(scenario, n, rep) {
  scenario_index <- match(scenario, scenarios)
  seed <- seed0 + 7000000L + 100000L * scenario_index + 1000L * n + rep
  if (scenario == "N1_uniform_uniform") {
    dat <- sim_null_circ(n, scenario, seed = seed)
    kind <- "null"
    effect_value <- 0
  } else {
    dat <- sim_alt_circ(n, scenario, kappa_noise = effect, seed = seed)
    kind <- "alternative"
    effect_value <- effect
  }
  out <- fixed_grid_p_values(dat$theta, dat$phi, kappa_grid, B = B, seed = seed + 1L)
  out$kind <- "reduced_sensitivity"
  out$scenario <- scenario
  out$n <- n
  out$effect <- effect_value
  out$repetition <- rep
  out$B <- B
  out$seed <- seed
  out$class <- kind
  out
}

chunk_file <- function(scenario, n) {
  file.path(chunk_dir, sprintf("%s__n_%s__R_%s__B_%s.csv", scenario, n, R_total, B))
}

for (scenario in scenarios) {
  for (n in n_values) {
    file <- chunk_file(scenario, n)
    if (file.exists(file)) {
      existing <- utils::read.csv(file, stringsAsFactors = FALSE)
      if (length(unique(existing$repetition)) >= R_total) {
        message(sprintf("Skipping completed reduced sensitivity: %s n=%s", scenario, n))
        next
      }
    }
    message(sprintf("Reduced sensitivity: %s n=%s R=%s B=%s", scenario, n, R_total, B))
    rows <- parallel_lapply(
      seq_len(R_total),
      function(rep) run_repetition(scenario, n, rep),
      cores = cores
    )
    rows <- do.call(rbind, rows)
    write_csv(rows, file)
  }
}

chunk_files <- list.files(chunk_dir, pattern = "[.]csv$", full.names = TRUE)
raw <- do.call(rbind, lapply(chunk_files, utils::read.csv, stringsAsFactors = FALSE))
raw$reject <- raw$p.value <= alpha
summary <- summarise_rejections(
  raw,
  c("kind", "scenario", "n", "effect", "kappa_theta", "kappa_phi", "method"),
  alpha = alpha
)
summary$B <- B
summary$alpha <- alpha
summary$target_R <- R_total
summary$completed <- summary$R >= R_total

write_csv(raw, file.path(output_dir, "reduced_sensitivity_raw.csv"))
write_csv(summary, file.path(output_dir, "reduced_sensitivity_summary.csv"))

message("Reduced sensitivity study complete.")
