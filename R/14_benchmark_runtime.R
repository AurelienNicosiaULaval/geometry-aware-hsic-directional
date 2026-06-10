# Runtime benchmark for the main HSIC strategies.

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

timing_repetitions <- check_positive_integer(as.integer(get_arg("reps", "20")), "reps")
B <- check_positive_integer(as.integer(get_arg("B", "199")), "B")
seed0 <- as.integer(get_arg("seed", "20260606"))
n_values <- as.integer(parse_num_vec(get_arg("n", NULL), c(50, 100, 200)))
kappa_grid <- parse_num_vec(get_arg("kappa-grid", NULL), c(0.5, 1, 2, 4, 8, 16, 32))
output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

time_one <- function(method, n, rep) {
  seed <- seed0 + 9000000L + 1000L * n + 10L * rep + match(method, methods)
  dat <- sim_alt_circ(n, "A1_shift", kappa_noise = 4, seed = seed)
  elapsed <- system.time({
    if (method == "HSIC fixed") {
      test <- circ_circ_hsic_test(dat$theta, dat$phi, 2, 2, B = B, seed = seed + 1L)
    } else if (method == "HSIC median") {
      test <- circ_circ_hsic_test(dat$theta, dat$phi, B = B, seed = seed + 1L)
    } else if (method == "HSIC standardized multi-scale") {
      test <- circ_circ_hsic_multiscale_test(
        dat$theta, dat$phi, kappa_grid, kappa_grid,
        B = B, seed = seed + 1L,
        return_grid = FALSE,
        return_permutations = FALSE
      )
    } else {
      stop("Unknown method.", call. = FALSE)
    }
  })["elapsed"]
  data.frame(
    scenario = "A1_shift",
    n = n,
    B = B,
    method = method,
    timing_repetition = rep,
    elapsed_seconds = as.numeric(elapsed),
    statistic = test$statistic,
    p.value = test$p.value,
    machine = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
    cores_available = parallel::detectCores(logical = TRUE),
    stringsAsFactors = FALSE
  )
}

methods <- c("HSIC fixed", "HSIC median", "HSIC standardized multi-scale")
jobs <- expand.grid(
  method = methods,
  n = n_values,
  timing_repetition = seq_len(timing_repetitions),
  stringsAsFactors = FALSE
)

message(sprintf("Runtime benchmark: jobs=%s B=%s", nrow(jobs), B))
rows <- lapply(seq_len(nrow(jobs)), function(i) {
  time_one(jobs$method[i], jobs$n[i], jobs$timing_repetition[i])
})
raw <- do.call(rbind, rows)
summary <- stats::aggregate(
  elapsed_seconds ~ scenario + n + B + method + machine + cores_available,
  raw,
  function(x) c(median = stats::median(x), iqr = stats::IQR(x),
                min = min(x), max = max(x), reps = length(x))
)
summary <- do.call(data.frame, summary)
names(summary) <- sub("elapsed_seconds[.]", "", names(summary))
names(summary)[names(summary) == "median"] <- "median_seconds"
names(summary)[names(summary) == "iqr"] <- "iqr_seconds"
names(summary)[names(summary) == "min"] <- "min_seconds"
names(summary)[names(summary) == "max"] <- "max_seconds"
names(summary)[names(summary) == "reps"] <- "timing_repetitions"

write_csv(raw, file.path(output_dir, "runtime_benchmark_raw.csv"))
write_csv(summary, file.path(output_dir, "runtime_benchmark_summary.csv"))

message("Runtime benchmark complete.")
