# Final simulation runner for the compact directional HSIC paper.
# The runner is resumable and writes scenario-level raw and summary files.

args <- commandArgs(trailingOnly = TRUE)
run_start <- Sys.time()

parse_cli <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    key_value <- sub("^--", "", arg)
    if (!grepl("=", key_value, fixed = TRUE)) {
      out[[key_value]] <- "true"
    } else {
      key <- sub("=.*$", "", key_value)
      value <- sub("^[^=]*=", "", key_value)
      out[[key]] <- value
    }
  }
  out
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

parse_num_vec <- function(value, default) {
  if (is.null(value) || value == "") return(default)
  out <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (anyNA(out) || any(!is.finite(out))) {
    stop(sprintf("Argument `%s` must be a comma-separated numeric vector.", value),
         call. = FALSE)
  }
  out
}

parse_chr_vec <- function(value, default) {
  if (is.null(value) || value == "") return(default)
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

as_bool <- function(value, default = FALSE) {
  if (is.null(value)) return(default)
  tolower(value) %in% c("1", "true", "yes", "y")
}

scenario_arg <- get_arg("scenario", "all")
n_values <- as.integer(parse_num_vec(get_arg("n", NULL), c(50, 100, 200, 500)))
R_total <- as.integer(get_arg("R", "1000"))
B <- as.integer(get_arg("B", "999"))
seed0 <- as.integer(get_arg("seed", "20260606"))
alpha <- as.numeric(get_arg("alpha", "0.05"))
output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))
method_subset <- parse_chr_vec(get_arg("methods", NULL), "all")
force <- as_bool(get_arg("force", NULL), FALSE)
kappa_grid <- parse_num_vec(get_arg("kappa-grid", NULL), c(0.5, 1, 2, 4, 8, 16, 32))
effect_grid <- parse_num_vec(get_arg("effect-grid", NULL), c(1, 2, 4, 8))
linear_noise_grid <- parse_num_vec(get_arg("linear-noise-grid", NULL), c(0.3, 0.5, 0.7, 1.0))
run_kernel_sensitivity <- as_bool(get_arg("kernel-sensitivity", NULL), FALSE)
run_aggregate <- as_bool(get_arg("aggregate", NULL), TRUE)
aggregate_only <- as_bool(get_arg("aggregate-only", NULL), FALSE)
write_cost <- as_bool(get_arg("write-cost", NULL), TRUE)
skip_scenarios <- as_bool(get_arg("skip-scenarios", NULL), FALSE)
kernel_sensitivity_only <- as_bool(get_arg("kernel-sensitivity-only", NULL), FALSE)

if (kernel_sensitivity_only) {
  skip_scenarios <- TRUE
  run_kernel_sensitivity <- TRUE
}

if (!all(n_values %in% c(50, 100, 200, 500))) {
  warning("`n` includes values outside the planned final grid.", call. = FALSE)
}
R_total <- check_positive_integer(R_total, "R")
B <- check_positive_integer(B, "B")
check_positive_scalar(alpha, "alpha")

null_scenarios <- c(
  "N1_uniform_uniform",
  "N2_vonmises_vonmises",
  "N3_uniform_vonmises",
  "N4_mixture_mixture"
)
alt_scenarios <- c(
  "A1_shift",
  "A2_double_angle",
  "A3_axial",
  "A4_multimodal",
  "A5_local_dependence",
  "A6_symmetric_nonlinear"
)
cl_scenarios <- c(
  "L0_independent",
  "L1_cos",
  "L2_cos2",
  "L3_multivariate",
  "L4_local"
)
all_scenarios <- c(null_scenarios, alt_scenarios, cl_scenarios)

if (identical(scenario_arg, "all")) {
  scenarios <- all_scenarios
} else if (identical(scenario_arg, "null")) {
  scenarios <- null_scenarios
} else if (identical(scenario_arg, "alternative")) {
  scenarios <- alt_scenarios
} else if (identical(scenario_arg, "circular-linear")) {
  scenarios <- cl_scenarios
} else {
  scenarios <- parse_chr_vec(scenario_arg, character())
}
unknown <- setdiff(scenarios, all_scenarios)
if (length(unknown) > 0L) {
  stop(sprintf("Unknown scenario(s): %s", paste(unknown, collapse = ", ")),
       call. = FALSE)
}

raw_dir <- file.path(output_dir, "raw")
summary_dir <- file.path(output_dir, "summary")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

sanitize <- function(x) gsub("[^A-Za-z0-9_.-]+", "_", as.character(x))

combo_file <- function(kind, scenario, n, effect = NA_real_) {
  effect_part <- if (is.na(effect)) "effect_none" else paste0("effect_", sanitize(effect))
  file.path(raw_dir, paste(kind, scenario, paste0("n_", n), effect_part,
                          paste0("B_", B), "raw.csv", sep = "__"))
}

summary_file <- function(kind, scenario, n, effect = NA_real_) {
  effect_part <- if (is.na(effect)) "effect_none" else paste0("effect_", sanitize(effect))
  file.path(summary_dir, paste(kind, scenario, paste0("n_", n), effect_part,
                              paste0("B_", B), "summary.csv", sep = "__"))
}

atomic_write_csv <- function(x, file) {
  tmp <- paste0(file, ".tmp.", Sys.getpid())
  utils::write.csv(x, tmp, row.names = FALSE)
  file.rename(tmp, file)
  invisible(file)
}

safe_read_csv <- function(file) {
  if (!file.exists(file)) return(data.frame())
  info <- file.info(file)
  if (is.na(info$size) || info$size == 0L) return(data.frame())
  out <- tryCatch(
    utils::read.csv(file, stringsAsFactors = FALSE),
    error = function(e) data.frame()
  )
  out
}

wanted <- function(method_name) {
  identical(method_subset, "all") || method_name %in% method_subset
}

run_circ_methods <- function(theta, phi, seed) {
  rows <- list()
  i <- 0L
  make_row <- function(test, retained_grid_points = NA_integer_) {
    data.frame(
      method = test$method,
      statistic = test$statistic,
      p.value = test$p.value,
      retained_grid_points = retained_grid_points
    )
  }
  if (wanted("fixed") || wanted("HSIC fixed")) {
    i <- i + 1L
    test <- circ_circ_hsic_test(theta, phi, 2, 2, B = B, seed = seed + 1L)
    rows[[i]] <- make_row(test)
  }
  if (wanted("median") || wanted("HSIC median")) {
    i <- i + 1L
    test <- circ_circ_hsic_test(theta, phi, B = B, seed = seed + 2L)
    rows[[i]] <- make_row(test)
  }
  if (wanted("multiscale") || wanted("HSIC standardized multi-scale")) {
    i <- i + 1L
    test <- circ_circ_hsic_multiscale_test(
      theta, phi, kappa_grid, kappa_grid, B = B, seed = seed + 3L,
      return_grid = TRUE, return_permutations = FALSE
    )
    rows[[i]] <- make_row(test, nrow(test$retained_grid))
  }
  if (wanted("naive") || wanted("naive Euclidean-angle HSIC")) {
    i <- i + 1L
    test <- naive_angle_hsic_test(theta, phi, B = B, seed = seed + 4L)
    rows[[i]] <- make_row(test)
  }
  if (wanted("trig") || wanted("trigonometric moment diagnostic")) {
    i <- i + 1L
    test <- trig_moment_test(theta, phi, B = B, seed = seed + 5L)
    rows[[i]] <- make_row(test)
  }
  out <- do.call(rbind, rows)
  out
}

run_cl_methods <- function(theta, X, seed) {
  if (!wanted("circular-linear") && !wanted("HSIC circular-linear") &&
      !identical(method_subset, "all")) {
    return(data.frame())
  }
  test <- circ_linear_hsic_test(theta, X, B = B, seed = seed + 1L)
  data.frame(method = test$method, statistic = test$statistic, p.value = test$p.value)
}

run_fixed_grid_sensitivity <- function(theta, phi, grid, B, seed) {
  K_list <- lapply(grid, function(k) center_gram(vm_kernel(theta, k)))
  L_list <- lapply(grid, function(k) center_gram(vm_kernel(phi, k)))
  grid_df <- expand.grid(
    kappa_theta = grid,
    kappa_phi = grid,
    stringsAsFactors = FALSE
  )
  observed <- vapply(seq_len(nrow(grid_df)), function(g) {
    ki <- match(grid_df$kappa_theta[g], grid)
    li <- match(grid_df$kappa_phi[g], grid)
    hsic_biased_centered(K_list[[ki]], L_list[[li]])
  }, numeric(1))
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  perm_stats <- matrix(NA_real_, nrow = B, ncol = nrow(grid_df))
  for (b in seq_len(B)) {
    idx <- sample.int(length(theta))
    for (g in seq_len(nrow(grid_df))) {
      ki <- match(grid_df$kappa_theta[g], grid)
      li <- match(grid_df$kappa_phi[g], grid)
      perm_stats[b, g] <- hsic_biased_centered(K_list[[ki]], permute_gram(L_list[[li]], idx))
    }
  }
  p_values <- vapply(seq_len(nrow(grid_df)), function(g) {
    (1 + sum(perm_stats[, g] >= observed[g])) / (B + 1)
  }, numeric(1))
  data.frame(
    method = "HSIC fixed-grid sensitivity",
    kappa_theta = grid_df$kappa_theta,
    kappa_phi = grid_df$kappa_phi,
    statistic = observed,
    p.value = p_values
  )
}

summarize_file <- function(raw, file, kind, scenario, n, effect) {
  if (nrow(raw) == 0L) return(invisible(NULL))
  raw$reject <- raw$p.value <= alpha
  group_cols <- c("kind", "scenario", "n", "effect", "method")
  raw$kind <- kind
  raw$scenario <- scenario
  raw$n <- n
  raw$effect <- ifelse(is.na(effect), 0, effect)
  summary <- summarise_rejections(raw, group_cols, alpha = alpha)
  summary$B <- B
  summary$alpha <- alpha
  summary$target_R <- R_total
  summary$completed <- summary$R >= R_total
  atomic_write_csv(summary, file)
  invisible(summary)
}

run_combo <- function(kind, scenario, n, effect = NA_real_) {
  raw_file <- combo_file(kind, scenario, n, effect)
  sum_file <- summary_file(kind, scenario, n, effect)
  existing <- if (file.exists(raw_file) && !force) {
    safe_read_csv(raw_file)
  } else {
    data.frame()
  }
  done_reps <- if (nrow(existing) > 0L) sort(unique(existing$repetition)) else integer()
  todo <- setdiff(seq_len(R_total), done_reps)
  if (length(todo) == 0L) {
    message(sprintf("Skipping completed: %s n=%d effect=%s",
                    scenario, n, ifelse(is.na(effect), "none", effect)))
    summarize_file(existing, sum_file, kind, scenario, n, effect)
    return(invisible(TRUE))
  }

  message(sprintf("Running: %s n=%d effect=%s reps=%d/%d",
                  scenario, n, ifelse(is.na(effect), "none", effect),
                  length(todo), R_total))

  current <- existing
  for (rep in todo) {
    seed <- seed0 + 100000L * match(scenario, all_scenarios) +
      1000L * n + 10L * rep + ifelse(is.na(effect), 0L, as.integer(round(100 * effect)))
    if (kind == "null") {
      dat <- sim_null_circ(n, scenario, seed = seed)
      out <- run_circ_methods(dat$theta, dat$phi, seed)
    } else if (kind == "alternative") {
      dat <- sim_alt_circ(n, scenario, kappa_noise = effect, seed = seed)
      out <- run_circ_methods(dat$theta, dat$phi, seed)
    } else if (kind == "circular_linear") {
      dat <- sim_circ_linear(n, scenario, noise_sd = effect, seed = seed)
      out <- run_cl_methods(dat$theta, dat$X, seed)
    } else {
      stop("Unknown simulation kind.", call. = FALSE)
    }
    if (nrow(out) > 0L) {
      out$kind <- kind
      out$scenario <- scenario
      out$n <- n
      out$effect <- ifelse(is.na(effect), 0, effect)
      out$repetition <- rep
      out$B <- B
      out$seed <- seed
      current <- rbind(current, out)
      atomic_write_csv(current, raw_file)
      summarize_file(current, sum_file, kind, scenario, n, effect)
    }
  }
  invisible(TRUE)
}

run_kernel_sensitivity_block <- function() {
  sensitivity_scenarios <- c("A3_axial", "A4_multimodal", "A6_symmetric_nonlinear")
  sensitivity_n <- n_values
  sensitivity_effect <- 8
  raw_file <- file.path(output_dir, "kernel_sensitivity_raw.csv")
  summary_file <- file.path(output_dir, "kernel_sensitivity_summary.csv")
  existing <- if (file.exists(raw_file) && !force) {
    safe_read_csv(raw_file)
  } else {
    data.frame()
  }
  rows <- existing
  for (scenario in sensitivity_scenarios) {
    for (n in sensitivity_n) {
      done <- if (nrow(rows) > 0L) {
        unique(rows$repetition[rows$scenario == scenario & rows$n == n])
      } else {
        integer()
      }
      todo <- setdiff(seq_len(R_total), done)
      if (length(todo) == 0L) next
      message(sprintf("Kernel sensitivity: %s n=%d reps=%d/%d", scenario, n, length(todo), R_total))
      for (rep in todo) {
        seed <- seed0 + 9000000L + 100000L * match(scenario, sensitivity_scenarios) +
          1000L * n + 10L * rep
        dat <- sim_alt_circ(n, scenario, kappa_noise = sensitivity_effect, seed = seed)
        out <- run_fixed_grid_sensitivity(dat$theta, dat$phi, kappa_grid, B = B, seed = seed + 7L)
        out$kind <- "kernel_sensitivity"
        out$scenario <- scenario
        out$n <- n
        out$effect <- sensitivity_effect
        out$repetition <- rep
        out$B <- B
        out$seed <- seed
        rows <- rbind(rows, out)
        atomic_write_csv(rows, raw_file)
      }
    }
  }
  if (nrow(rows) > 0L) {
    summary <- summarise_rejections(
      rows,
      c("kind", "scenario", "n", "effect", "kappa_theta", "kappa_phi", "method"),
      alpha = alpha
    )
    summary$B <- B
    summary$alpha <- alpha
    summary$target_R <- R_total
    summary$completed <- summary$R >= R_total
    atomic_write_csv(summary, summary_file)
  }
  invisible(TRUE)
}

aggregate_outputs <- function() {
  files <- list.files(raw_dir, pattern = "__raw[.]csv$", full.names = TRUE)
  files <- files[file.info(files)$size > 0L]
  if (length(files) == 0L) return(invisible(FALSE))
  raw_list <- lapply(files, safe_read_csv)
  raw_list <- Filter(function(x) nrow(x) > 0L, raw_list)
  if (length(raw_list) == 0L) return(invisible(FALSE))
  all_cols <- unique(unlist(lapply(raw_list, names)))
  raw_list <- lapply(raw_list, function(x) {
    missing <- setdiff(all_cols, names(x))
    for (col in missing) x[[col]] <- NA
    x[, all_cols, drop = FALSE]
  })
  raw <- do.call(rbind, raw_list)
  raw$reject <- raw$p.value <= alpha
  write_kind <- function(kind_value, raw_name, summary_name) {
    part <- raw[raw$kind == kind_value, , drop = FALSE]
    if (nrow(part) == 0L) return(invisible(NULL))
    atomic_write_csv(part, file.path(output_dir, raw_name))
    summary <- summarise_rejections(part, c("kind", "scenario", "n", "effect", "method"), alpha = alpha)
    summary$B <- B
    summary$alpha <- alpha
    summary$target_R <- R_total
    summary$completed <- summary$R >= R_total
    atomic_write_csv(summary, file.path(output_dir, summary_name))
  }
  write_kind("null", "null_raw.csv", "null_summary.csv")
  write_kind("alternative", "power_raw.csv", "power_summary.csv")
  write_kind("circular_linear", "circular_linear_raw.csv", "circular_linear_summary.csv")
  invisible(TRUE)
}

if (!aggregate_only && !skip_scenarios) {
  for (scenario in scenarios) {
    for (n in n_values) {
      if (scenario %in% null_scenarios) {
        run_combo("null", scenario, n, NA_real_)
      } else if (scenario %in% alt_scenarios) {
        for (effect in effect_grid) {
          run_combo("alternative", scenario, n, effect)
        }
      } else if (scenario %in% cl_scenarios) {
        for (effect in linear_noise_grid) {
          run_combo("circular_linear", scenario, n, effect)
        }
      }
    }
  }
}

if (run_kernel_sensitivity) {
  run_kernel_sensitivity_block()
}

if (run_aggregate || aggregate_only) {
  aggregate_outputs()
}

run_end <- Sys.time()
if (write_cost) {
  cost <- data.frame(
    started_at = format(run_start, "%Y-%m-%d %H:%M:%S %Z"),
    ended_at = format(run_end, "%Y-%m-%d %H:%M:%S %Z"),
    elapsed_seconds = as.numeric(difftime(run_end, run_start, units = "secs")),
    R = R_total,
    B = B,
    n_values = paste(n_values, collapse = ","),
    scenarios = paste(scenarios, collapse = ","),
    kernel_sensitivity = run_kernel_sensitivity,
    aggregate_only = aggregate_only,
    stringsAsFactors = FALSE
  )
  atomic_write_csv(cost, file.path(output_dir, "computational_cost.csv"))
}

message("Final simulation runner finished requested combinations.")
